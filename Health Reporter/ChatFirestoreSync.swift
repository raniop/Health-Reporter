//
//  ChatFirestoreSync.swift
//  Health Reporter
//
//  Firestore service for 1-on-1 chat: conversations, messages, read receipts, unread counts.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

enum ChatFirestoreSync {

    private static let db = Firestore.firestore()
    private static let chatsCollection = "chats"
    private static let messagesSubcollection = "messages"
    private static let usersCollection = "users"

    // MARK: - Mutual Follow Check

    /// Returns true if both users follow each other (required for chat).
    static func checkMutualFollow(with otherUid: String, completion: @escaping (Bool) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            DispatchQueue.main.async { completion(false) }
            return
        }

        let group = DispatchGroup()
        var iFollow = false
        var theyFollowMe = false

        // Check if I follow them
        group.enter()
        db.collection(usersCollection).document(currentUid)
            .collection("following").document(otherUid)
            .getDocument { snapshot, _ in
                iFollow = snapshot?.exists == true
                group.leave()
            }

        // Check if they follow me
        group.enter()
        db.collection(usersCollection).document(currentUid)
            .collection("followers").document(otherUid)
            .getDocument { snapshot, _ in
                theyFollowMe = snapshot?.exists == true
                group.leave()
            }

        group.notify(queue: .main) {
            completion(iFollow && theyFollowMe)
        }
    }

    // MARK: - Get or Create Conversation

    static func getOrCreateConversation(with otherUid: String,
                                         completion: @escaping (ChatConversation?, Error?) -> Void) {
        guard let currentUser = Auth.auth().currentUser,
              let currentUid = currentUser.uid as String?,
              !currentUid.isEmpty else {
            print("💬 [Chat] getOrCreateConversation FAILED — no user logged in")
            completion(nil, NSError(domain: "ChatFirestoreSync", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "No user logged in"]))
            return
        }
        print("💬 [Chat] getOrCreateConversation — currentUid=\(currentUid), otherUid=\(otherUid)")

        let chatId = ChatHelper.chatId(uid1: currentUid, uid2: otherUid)
        let chatRef = db.collection(chatsCollection).document(chatId)

        // Fetch profile for the other user, then create-or-get the chat
        fetchUserProfile(uid: otherUid) { otherName, otherPhoto in
            let myName = currentUser.displayName ?? "Unknown User"
            let myPhoto = currentUser.photoURL?.absoluteString

            let participants = [currentUid, otherUid].sorted()
            let profilesData: [String: Any] = [
                currentUid: [
                    "displayName": myName,
                    "photoURL": myPhoto as Any
                ],
                otherUid: [
                    "displayName": otherName ?? "Unknown User",
                    "photoURL": otherPhoto as Any
                ]
            ]

            let chatData: [String: Any] = [
                "participants": participants,
                "participantProfiles": profilesData,
                "createdAt": FieldValue.serverTimestamp(),
                "lastMessageTimestamp": FieldValue.serverTimestamp(),
                "unreadCount_\(currentUid)": 0,
                "unreadCount_\(otherUid)": 0
            ]

            // Use setData with merge to create if not exists, or leave existing data intact
            chatRef.setData(chatData, merge: true) { error in
                if let error = error {
                    DispatchQueue.main.async { completion(nil, error) }
                    return
                }

                // Now read the document back (guaranteed to exist)
                chatRef.getDocument { snapshot, error in
                    if let error = error {
                        DispatchQueue.main.async { completion(nil, error) }
                        return
                    }

                    if let data = snapshot?.data() {
                        let conversation = parseConversation(id: chatId, data: data, currentUid: currentUid)
                        DispatchQueue.main.async { completion(conversation, nil) }
                    } else {
                        let profiles: [String: ChatUserProfile] = [
                            currentUid: ChatUserProfile(displayName: myName, photoURL: myPhoto),
                            otherUid: ChatUserProfile(displayName: otherName ?? "Unknown User", photoURL: otherPhoto)
                        ]
                        let conversation = ChatConversation(
                            id: chatId,
                            participants: participants,
                            participantProfiles: profiles,
                            lastMessage: nil,
                            lastMessageTimestamp: Date(),
                            createdAt: Date(),
                            unreadCount: 0
                        )
                        DispatchQueue.main.async { completion(conversation, nil) }
                    }
                }
            }
        }
    }

    // MARK: - Listen to Conversations (Chat List)

    @discardableResult
    static func listenToConversations(completion: @escaping ([ChatConversation]) -> Void) -> ListenerRegistration? {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            DispatchQueue.main.async { completion([]) }
            return nil
        }

        return db.collection(chatsCollection)
            .whereField("participants", arrayContains: currentUid)
            .order(by: "lastMessageTimestamp", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }

                let conversations: [ChatConversation] = docs.compactMap { doc in
                    parseConversation(id: doc.documentID, data: doc.data(), currentUid: currentUid)
                }

                DispatchQueue.main.async { completion(conversations) }
            }
    }

    // MARK: - Listen to Messages

    @discardableResult
    static func listenToMessages(chatId: String, limit: Int = 50,
                                  completion: @escaping ([ChatMessage]) -> Void) -> ListenerRegistration? {
        print("💬 [Chat] listenToMessages — chatId=\(chatId), limit=\(limit)")
        return db.collection(chatsCollection).document(chatId)
            .collection(messagesSubcollection)
            .order(by: "timestamp", descending: false)
            .limit(toLast: limit)
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }

                let messages: [ChatMessage] = docs.compactMap { doc in
                    let data = doc.data()
                    guard let senderUid = data["senderUid"] as? String,
                          let text = data["text"] as? String else { return nil }

                    let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    let type = data["type"] as? String ?? "text"
                    let statusStr = data["status"] as? String ?? "sent"
                    let status = ChatMessageStatus(rawValue: statusStr) ?? .sent

                    return ChatMessage(
                        id: doc.documentID,
                        senderUid: senderUid,
                        text: text,
                        timestamp: timestamp,
                        type: type,
                        status: status
                    )
                }

                DispatchQueue.main.async { completion(messages) }
            }
    }

    // MARK: - Load Earlier Messages (Pagination)

    static func loadEarlierMessages(chatId: String, before: Date, limit: Int = 30,
                                     completion: @escaping ([ChatMessage]) -> Void) {
        db.collection(chatsCollection).document(chatId)
            .collection(messagesSubcollection)
            .order(by: "timestamp", descending: true)
            .whereField("timestamp", isLessThan: Timestamp(date: before))
            .limit(to: limit)
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }

                let messages: [ChatMessage] = docs.compactMap { doc in
                    let data = doc.data()
                    guard let senderUid = data["senderUid"] as? String,
                          let text = data["text"] as? String else { return nil }

                    let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    let type = data["type"] as? String ?? "text"
                    let statusStr = data["status"] as? String ?? "sent"
                    let status = ChatMessageStatus(rawValue: statusStr) ?? .sent

                    return ChatMessage(
                        id: doc.documentID,
                        senderUid: senderUid,
                        text: text,
                        timestamp: timestamp,
                        type: type,
                        status: status
                    )
                }.reversed()

                DispatchQueue.main.async { completion(Array(messages)) }
            }
    }

    // MARK: - Send Message

    static func sendMessage(chatId: String, text: String, otherUid: String,
                             completion: ((Error?) -> Void)? = nil) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            print("💬 [Chat] sendMessage FAILED — no user logged in")
            completion?(NSError(domain: "ChatFirestoreSync", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "No user logged in"]))
            return
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            print("💬 [Chat] sendMessage SKIPPED — empty text")
            completion?(nil)
            return
        }

        print("💬 [Chat] sendMessage START — chatId=\(chatId), to=\(otherUid), text=\(trimmed.prefix(30))...")

        let batch = db.batch()

        // 1. Add message document
        let messageRef = db.collection(chatsCollection).document(chatId)
            .collection(messagesSubcollection).document()
        print("💬 [Chat] sendMessage — messageRef=\(messageRef.path)")
        batch.setData([
            "senderUid": currentUid,
            "text": trimmed,
            "timestamp": FieldValue.serverTimestamp(),
            "type": "text",
            "status": ChatMessageStatus.sent.rawValue
        ], forDocument: messageRef)

        // 2. Update chat document: lastMessage, lastMessageTimestamp, increment other user's unread
        let chatRef = db.collection(chatsCollection).document(chatId)
        batch.updateData([
            "lastMessage": [
                "text": trimmed,
                "senderUid": currentUid,
                "timestamp": FieldValue.serverTimestamp(),
                "type": "text"
            ],
            "lastMessageTimestamp": FieldValue.serverTimestamp(),
            "unreadCount_\(otherUid)": FieldValue.increment(Int64(1))
        ], forDocument: chatRef)

        batch.commit { error in
            if let error = error {
                print("💬 [Chat] sendMessage FAILED — \(error.localizedDescription)")
            } else {
                print("💬 [Chat] sendMessage SUCCESS ✅ — message written to Firestore (Cloud Function should trigger notification)")
                // Sending a reply means we've read their messages — mark as seen
                markConversationAsSeen(chatId: chatId, otherUid: otherUid)
            }
            DispatchQueue.main.async { completion?(error) }
        }
    }

    // MARK: - Mark Conversation as Seen

    static func markConversationAsSeen(chatId: String, otherUid: String) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            print("💬 [Chat] markConversationAsSeen SKIPPED — no user logged in")
            return
        }
        print("💬 [Chat] markConversationAsSeen — chatId=\(chatId), currentUid=\(currentUid)")

        let chatRef = db.collection(chatsCollection).document(chatId)

        // First verify the document exists before trying to update
        chatRef.getDocument { snapshot, _ in
            guard snapshot?.exists == true else {
                print("💬 [Chat] markConversationAsSeen — chat doc doesn't exist, skipping")
                return
            }

            // Reset my unread count to 0
            chatRef.updateData([
                "unreadCount_\(currentUid)": 0
            ]) { error in
                if let error = error {
                    print("💬 [Chat] markConversationAsSeen — failed to reset unread: \(error.localizedDescription)")
                } else {
                    print("💬 [Chat] markConversationAsSeen — unread count reset to 0 ✅")
                }
            }

            // Update all unread messages from the other user to "seen"
            // Uses only orderBy(timestamp) to avoid needing a composite index
            chatRef.collection(messagesSubcollection)
                .order(by: "timestamp", descending: true)
                .limit(to: 20)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("💬 [Chat] markConversationAsSeen — query error: \(error.localizedDescription)")
                        return
                    }
                    guard let docs = snapshot?.documents else {
                        print("💬 [Chat] markConversationAsSeen — no messages found")
                        return
                    }

                    print("💬 [Chat] markConversationAsSeen — checking \(docs.count) recent messages")
                    var updatedCount = 0
                    for doc in docs {
                        let data = doc.data()
                        let senderUid = data["senderUid"] as? String
                        let status = data["status"] as? String

                        // Only update messages from the other user that aren't already "seen"
                        guard senderUid == otherUid,
                              status != ChatMessageStatus.seen.rawValue else { continue }

                        doc.reference.updateData(["status": ChatMessageStatus.seen.rawValue])
                        updatedCount += 1
                    }
                    print("💬 [Chat] markConversationAsSeen — updated \(updatedCount) messages to 'seen' ✅")
                }
        }
    }

    // MARK: - Total Unread Count (for badge)

    static func fetchTotalUnreadCount(completion: @escaping (Int) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            DispatchQueue.main.async { completion(0) }
            return
        }

        db.collection(chatsCollection)
            .whereField("participants", arrayContains: currentUid)
            .getDocuments { snapshot, _ in
                var total = 0
                for doc in snapshot?.documents ?? [] {
                    let unread = doc.data()["unreadCount_\(currentUid)"] as? Int ?? 0
                    total += unread
                }
                DispatchQueue.main.async { completion(total) }
            }
    }

    /// Real-time listener for total unread count (for badge updates)
    @discardableResult
    static func listenToTotalUnreadCount(completion: @escaping (Int) -> Void) -> ListenerRegistration? {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            DispatchQueue.main.async { completion(0) }
            return nil
        }

        return db.collection(chatsCollection)
            .whereField("participants", arrayContains: currentUid)
            .addSnapshotListener { snapshot, _ in
                var total = 0
                for doc in snapshot?.documents ?? [] {
                    let unread = doc.data()["unreadCount_\(currentUid)"] as? Int ?? 0
                    total += unread
                }
                DispatchQueue.main.async { completion(total) }
            }
    }

    // MARK: - Parsing Helpers

    private static func parseConversation(id: String, data: [String: Any], currentUid: String) -> ChatConversation? {
        guard let participants = data["participants"] as? [String] else { return nil }

        // Parse participant profiles
        var profiles: [String: ChatUserProfile] = [:]
        if let profilesData = data["participantProfiles"] as? [String: [String: Any]] {
            for (uid, profileData) in profilesData {
                let name = profileData["displayName"] as? String ?? "Unknown User"
                let photo = profileData["photoURL"] as? String
                profiles[uid] = ChatUserProfile(displayName: name, photoURL: photo)
            }
        }

        // Parse last message
        var lastMessage: ChatLastMessage?
        if let msgData = data["lastMessage"] as? [String: Any],
           let text = msgData["text"] as? String,
           let senderUid = msgData["senderUid"] as? String {
            let timestamp = (msgData["timestamp"] as? Timestamp)?.dateValue() ?? Date()
            let type = msgData["type"] as? String ?? "text"
            lastMessage = ChatLastMessage(text: text, senderUid: senderUid, timestamp: timestamp, type: type)
        }

        let lastMessageTimestamp = (data["lastMessageTimestamp"] as? Timestamp)?.dateValue()
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let unreadCount = data["unreadCount_\(currentUid)"] as? Int ?? 0

        return ChatConversation(
            id: id,
            participants: participants,
            participantProfiles: profiles,
            lastMessage: lastMessage,
            lastMessageTimestamp: lastMessageTimestamp,
            createdAt: createdAt,
            unreadCount: unreadCount
        )
    }

    private static func fetchUserProfile(uid: String, completion: @escaping (String?, String?) -> Void) {
        db.collection(usersCollection).document(uid).getDocument { snapshot, _ in
            let data = snapshot?.data()
            let name = data?["displayName"] as? String
            let photo = data?["photoURL"] as? String
            completion(name, photo)
        }
    }
}
