//
//  FriendsFirestoreSync.swift
//  Health Reporter
//
//  Managing friends and friend requests in Firestore.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging

enum FriendsFirestoreSync {

    private static let db = Firestore.firestore()
    private static let usersCollection = "users"
    private static let friendsSubcollection = "friends"
    private static let friendRequestsCollection = "friendRequests"

    // MARK: - Send Friend Request

    static func sendFriendRequest(toUid: String, completion: ((Error?) -> Void)? = nil) {
        guard let currentUser = Auth.auth().currentUser,
              let currentUid = currentUser.uid as String?,
              !currentUid.isEmpty else {
            completion?(NSError(domain: "FriendsFirestoreSync", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "sync.noUserLoggedIn".localized]))
            return
        }

        // Don't send request to self
        guard toUid != currentUid else {
            completion?(NSError(domain: "FriendsFirestoreSync", code: -2,
                                userInfo: [NSLocalizedDescriptionKey: "Cannot send friend request to yourself"]))
            return
        }

        // Get current user's display name and photo
        let displayName = currentUser.displayName ?? "social.unknownUser".localized
        let photoURL = currentUser.photoURL?.absoluteString

        let requestData: [String: Any] = [
            "fromUid": currentUid,
            "fromDisplayName": displayName,
            "fromPhotoURL": photoURL as Any,
            "toUid": toUid,
            "status": FriendRequestStatus.pending.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        db.collection(friendRequestsCollection).addDocument(data: requestData) { error in
            DispatchQueue.main.async { completion?(error) }
        }
    }

    // MARK: - Accept Friend Request

    static func acceptFriendRequest(requestId: String, completion: ((Error?) -> Void)? = nil) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            completion?(NSError(domain: "FriendsFirestoreSync", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "sync.noUserLoggedIn".localized]))
            return
        }

        let requestRef = db.collection(friendRequestsCollection).document(requestId)

        // First get the request data
        requestRef.getDocument { snapshot, error in
            guard let data = snapshot?.data(),
                  let fromUid = data["fromUid"] as? String,
                  let fromDisplayName = data["fromDisplayName"] as? String else {
                DispatchQueue.main.async {
                    completion?(error ?? NSError(domain: "FriendsFirestoreSync", code: -3,
                                                 userInfo: [NSLocalizedDescriptionKey: "Request not found"]))
                }
                return
            }

            let fromPhotoURL = data["fromPhotoURL"] as? String
            let batch = db.batch()

            // Update request status
            batch.updateData([
                "status": FriendRequestStatus.accepted.rawValue,
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: requestRef)

            // Add friend to current user's friends subcollection
            let myFriendRef = db.collection(usersCollection).document(currentUid)
                .collection(friendsSubcollection).document(fromUid)
            batch.setData([
                "friendUid": fromUid,
                "displayName": fromDisplayName,
                "photoURL": fromPhotoURL as Any,
                "addedAt": FieldValue.serverTimestamp()
            ], forDocument: myFriendRef)

            // Add current user to sender's friends subcollection
            fetchCurrentUserProfile { myName, myPhoto in
                let theirFriendRef = db.collection(usersCollection).document(fromUid)
                    .collection(friendsSubcollection).document(currentUid)
                batch.setData([
                    "friendUid": currentUid,
                    "displayName": myName ?? "social.unknownUser".localized,
                    "photoURL": myPhoto as Any,
                    "addedAt": FieldValue.serverTimestamp()
                ], forDocument: theirFriendRef)

                batch.commit { error in
                    DispatchQueue.main.async { completion?(error) }
                }
            }
        }
    }

    // MARK: - Decline Friend Request

    static func declineFriendRequest(requestId: String, completion: ((Error?) -> Void)? = nil) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            completion?(NSError(domain: "FriendsFirestoreSync", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "sync.noUserLoggedIn".localized]))
            return
        }

        db.collection(friendRequestsCollection).document(requestId).updateData([
            "status": FriendRequestStatus.declined.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ]) { error in
            DispatchQueue.main.async { completion?(error) }
        }
    }

    // MARK: - Remove Friend

    static func removeFriend(friendUid: String, completion: ((Error?) -> Void)? = nil) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            completion?(NSError(domain: "FriendsFirestoreSync", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "sync.noUserLoggedIn".localized]))
            return
        }

        let batch = db.batch()

        // Remove from my friends
        let myFriendRef = db.collection(usersCollection).document(currentUid)
            .collection(friendsSubcollection).document(friendUid)
        batch.deleteDocument(myFriendRef)

        // Remove me from their friends
        let theirFriendRef = db.collection(usersCollection).document(friendUid)
            .collection(friendsSubcollection).document(currentUid)
        batch.deleteDocument(theirFriendRef)

        batch.commit { error in
            DispatchQueue.main.async { completion?(error) }
        }
    }

    // MARK: - Fetch Friends

    static func fetchFriends(completion: @escaping ([Friend]) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            DispatchQueue.main.async { completion([]) }
            return
        }

        db.collection(usersCollection).document(currentUid)
            .collection(friendsSubcollection)
            .order(by: "addedAt", descending: true)
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }

                var friends: [Friend] = docs.compactMap { doc in
                    let data = doc.data()
                    guard let uid = data["friendUid"] as? String,
                          let displayName = data["displayName"] as? String else { return nil }

                    let addedAt = (data["addedAt"] as? Timestamp)?.dateValue() ?? Date()

                    return Friend(
                        uid: uid,
                        displayName: displayName,
                        photoURL: data["photoURL"] as? String,
                        followedAt: addedAt
                    )
                }

                // Enrich friends with carTier data from publicScores
                let friendUids = friends.map { $0.uid }
                fetchScoresForUsers(uids: friendUids) { scoresMap in
                    for i in friends.indices {
                        if let scoreData = scoresMap[friends[i].uid] {
                            friends[i].carTierIndex = scoreData.tierIndex
                            friends[i].carTierName = scoreData.tierName
                            friends[i].healthScore = scoreData.score
                            // Use photoURL from publicScores as fallback if not in friends collection
                            if friends[i].photoURL == nil || friends[i].photoURL?.isEmpty == true {
                                friends[i].photoURL = scoreData.photoURL
                            }
                        } else {
                            // Default score of 0 for users without publicScores data
                            friends[i].healthScore = 0
                        }
                    }
                    DispatchQueue.main.async { completion(friends) }
                }
            }
    }

    // MARK: - Fetch Pending Requests (incoming)

    static func fetchPendingRequests(completion: @escaping ([FriendRequest]) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            DispatchQueue.main.async { completion([]) }
            return
        }

        db.collection(friendRequestsCollection)
            .whereField("toUid", isEqualTo: currentUid)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }

                let requests: [FriendRequest] = docs.compactMap { doc in
                    let data = doc.data()
                    guard let fromUid = data["fromUid"] as? String,
                          let fromDisplayName = data["fromDisplayName"] as? String,
                          let toUid = data["toUid"] as? String,
                          let statusStr = data["status"] as? String,
                          let status = FriendRequestStatus(rawValue: statusStr) else { return nil }

                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()

                    return FriendRequest(
                        id: doc.documentID,
                        fromUid: fromUid,
                        fromDisplayName: fromDisplayName,
                        fromPhotoURL: data["fromPhotoURL"] as? String,
                        toUid: toUid,
                        status: status,
                        createdAt: createdAt,
                        updatedAt: updatedAt
                    )
                }

                DispatchQueue.main.async { completion(requests) }
            }
    }

    // MARK: - Fetch Sent Requests (outgoing)

    static func fetchSentRequests(completion: @escaping ([FriendRequest]) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            DispatchQueue.main.async { completion([]) }
            return
        }

        db.collection(friendRequestsCollection)
            .whereField("fromUid", isEqualTo: currentUid)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }

                let requests: [FriendRequest] = docs.compactMap { doc in
                    let data = doc.data()
                    guard let fromUid = data["fromUid"] as? String,
                          let toUid = data["toUid"] as? String,
                          let statusStr = data["status"] as? String,
                          let status = FriendRequestStatus(rawValue: statusStr) else { return nil }

                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

                    return FriendRequest(
                        id: doc.documentID,
                        fromUid: fromUid,
                        fromDisplayName: data["fromDisplayName"] as? String ?? "",
                        fromPhotoURL: data["fromPhotoURL"] as? String,
                        toUid: toUid,
                        status: status,
                        createdAt: createdAt,
                        updatedAt: nil
                    )
                }

                DispatchQueue.main.async { completion(requests) }
            }
    }

    // MARK: - Search Users

    static func searchUsers(query: String, limit: Int = 20, completion: @escaping ([UserSearchResult]) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            DispatchQueue.main.async { completion([]) }
            return
        }

        let queryLower = query.lowercased()
        let queryEnd = queryLower + "\u{f8ff}"

        // First try search by displayNameLower (optimized index)
        db.collection(usersCollection)
            .whereField("displayNameLower", isGreaterThanOrEqualTo: queryLower)
            .whereField("displayNameLower", isLessThan: queryEnd)
            .limit(to: limit)
            .getDocuments { snapshot, error in
                let docs = snapshot?.documents ?? []

                // If we found results with displayNameLower, use them
                if !docs.isEmpty {
                    let results = parseSearchResults(docs: docs, currentUid: currentUid)
                    enrichSearchResults(results, currentUid: currentUid) { enrichedResults in
                        DispatchQueue.main.async { completion(enrichedResults) }
                    }
                    return
                }

                // Fallback: search by displayName (for users without displayNameLower)
                db.collection(usersCollection)
                    .whereField("displayName", isGreaterThanOrEqualTo: query)
                    .whereField("displayName", isLessThan: query + "\u{f8ff}")
                    .limit(to: limit)
                    .getDocuments { snapshot2, error2 in
                        let docs2 = snapshot2?.documents ?? []
                        let results = parseSearchResults(docs: docs2, currentUid: currentUid)
                        enrichSearchResults(results, currentUid: currentUid) { enrichedResults in
                            DispatchQueue.main.async { completion(enrichedResults) }
                        }
                    }
            }
    }

    private static func parseSearchResults(docs: [QueryDocumentSnapshot], currentUid: String) -> [UserSearchResult] {
        return docs.compactMap { doc in
            // Don't include current user
            guard doc.documentID != currentUid else { return nil }

            let data = doc.data()
            let displayName = data["displayName"] as? String ?? "social.unknownUser".localized

            return UserSearchResult(
                uid: doc.documentID,
                displayName: displayName,
                photoURL: data["photoURL"] as? String
            )
        }
    }

    // MARK: - Helpers

    private static func fetchCurrentUserProfile(completion: @escaping (String?, String?) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(nil, nil)
            return
        }

        db.collection(usersCollection).document(currentUid).getDocument { snapshot, _ in
            let data = snapshot?.data()
            let name = data?["displayName"] as? String ?? Auth.auth().currentUser?.displayName
            let photo = data?["photoURL"] as? String ?? Auth.auth().currentUser?.photoURL?.absoluteString
            completion(name, photo)
        }
    }

    private static func enrichSearchResults(_ results: [UserSearchResult], currentUid: String,
                                            completion: @escaping ([UserSearchResult]) -> Void) {
        guard !results.isEmpty else {
            completion(results)
            return
        }

        let group = DispatchGroup()
        var enrichedResults = results

        // Check friends
        group.enter()
        fetchFriends { friends in
            let friendUids = Set(friends.map { $0.uid })
            for i in 0..<enrichedResults.count {
                if friendUids.contains(enrichedResults[i].uid) {
                    enrichedResults[i].isFriend = true
                }
            }
            group.leave()
        }

        // Check sent requests
        group.enter()
        fetchSentRequests { requests in
            let sentToUids = Set(requests.map { $0.toUid })
            for i in 0..<enrichedResults.count {
                if sentToUids.contains(enrichedResults[i].uid) {
                    enrichedResults[i].hasPendingRequest = true
                    enrichedResults[i].requestSentByMe = true
                }
            }
            group.leave()
        }

        // Check incoming requests
        group.enter()
        fetchPendingRequests { requests in
            let fromUids = Set(requests.map { $0.fromUid })
            for i in 0..<enrichedResults.count {
                if fromUids.contains(enrichedResults[i].uid) {
                    enrichedResults[i].hasPendingRequest = true
                    enrichedResults[i].requestSentByMe = false
                }
            }
            group.leave()
        }

        // Fetch health scores and photo from publicScores
        group.enter()
        let uids = results.map { $0.uid }
        fetchScoresForUsers(uids: uids) { scoresMap in
            for i in 0..<enrichedResults.count {
                if let scoreData = scoresMap[enrichedResults[i].uid] {
                    enrichedResults[i].healthScore = scoreData.score
                    enrichedResults[i].carTierIndex = scoreData.tierIndex
                    enrichedResults[i].carTierName = scoreData.tierName
                    // Use photoURL from publicScores as fallback if not in users collection
                    if enrichedResults[i].photoURL == nil || enrichedResults[i].photoURL?.isEmpty == true {
                        enrichedResults[i].photoURL = scoreData.photoURL
                    }
                }
            }
            group.leave()
        }

        group.notify(queue: .main) {
            completion(enrichedResults)
        }
    }

    private static func fetchScoresForUsers(uids: [String], completion: @escaping ([String: (score: Int, tierIndex: Int, tierName: String, photoURL: String?)]) -> Void) {
        guard !uids.isEmpty else {
            completion([:])
            return
        }

        // Firestore 'in' queries limited to 10 items
        let chunkedUids = stride(from: 0, to: uids.count, by: 10).map {
            Array(uids[$0..<min($0 + 10, uids.count)])
        }

        var scoresMap: [String: (score: Int, tierIndex: Int, tierName: String, photoURL: String?)] = [:]
        let group = DispatchGroup()

        for chunk in chunkedUids {
            group.enter()
            db.collection("publicScores")
                .whereField("__name__", in: chunk)
                .getDocuments { snapshot, _ in
                    for doc in snapshot?.documents ?? [] {
                        let data = doc.data()
                        if let score = data["healthScore"] as? Int,
                           let tierIndex = data["carTierIndex"] as? Int,
                           let tierName = data["carTierName"] as? String {
                            let photoURL = data["photoURL"] as? String
                            scoresMap[doc.documentID] = (score, tierIndex, tierName, photoURL)
                            print("🚗 [FriendsFirestoreSync] Fetched car for \(doc.documentID): \(tierName)")
                        }
                    }
                    group.leave()
                }
        }

        group.notify(queue: .main) {
            completion(scoresMap)
        }
    }

    // MARK: - Pending Requests Count (for badge)

    static func fetchPendingRequestsCount(completion: @escaping (Int) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            DispatchQueue.main.async { completion(0) }
            return
        }

        db.collection(friendRequestsCollection)
            .whereField("toUid", isEqualTo: currentUid)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .getDocuments { snapshot, _ in
                let count = snapshot?.documents.count ?? 0
                DispatchQueue.main.async { completion(count) }
            }
    }

    // MARK: - FCM Token Management

    /// Fetches the current FCM token and saves it to Firestore.
    /// Call this after the APNS token is available and user is logged in.
    /// Retries once after 5s if the APNS token isn't ready yet (code 505).
    static func refreshAndSaveFCMToken(retryCount: Int = 0) {
        let uid = Auth.auth().currentUser?.uid
        print("[FCM] refreshAndSaveFCMToken called (retry=\(retryCount)). Logged in: \(uid != nil), uid suffix: \(uid.map { String($0.suffix(4)) } ?? "none")")

        // Check if APNS token is available before requesting FCM token
        if Messaging.messaging().apnsToken == nil {
            print("[FCM] ⚠️ APNS token not yet available")
            if retryCount < 2 {
                let delay = Double(retryCount + 1) * 5.0
                print("[FCM] Will retry in \(Int(delay))s...")
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    refreshAndSaveFCMToken(retryCount: retryCount + 1)
                }
            } else {
                print("[FCM] ❌ APNS token still not available after retries - giving up. Token will be saved when didReceiveRegistrationToken fires.")
            }
            return
        }

        Messaging.messaging().token { token, error in
            if let error = error {
                let code = (error as NSError).code
                print("[FCM] ❌ Failed to fetch token: \(error.localizedDescription) (code: \(code))")
                // Code 505 = no APNS token. Retry once.
                if code == 505, retryCount < 2 {
                    let delay = Double(retryCount + 1) * 5.0
                    print("[FCM] Will retry in \(Int(delay))s...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        refreshAndSaveFCMToken(retryCount: retryCount + 1)
                    }
                }
                return
            }
            guard let token = token, !token.isEmpty else {
                print("[FCM] ❌ Token is nil or empty - Firebase did not return a token")
                return
            }
            print("[FCM] ✅ Token received, length: \(token.count), prefix: \(String(token.prefix(20)))...")
            saveFCMToken(token) { err in
                if let err = err {
                    print("[FCM] ❌ Save to Firestore FAILED: \(err.localizedDescription)")
                } else {
                    print("[FCM] ✅ Token saved to Firestore successfully")
                }
            }
        }
    }

    /// Saves the FCM token to Firestore for push notifications
    static func saveFCMToken(_ token: String, completion: ((Error?) -> Void)? = nil) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            print("[FCM] ❌ saveFCMToken SKIP: no user logged in - token will NOT be saved to Firestore")
            completion?(NSError(domain: "FriendsFirestoreSync", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "sync.noUserLoggedIn".localized]))
            return
        }

        print("[FCM] Saving token to Firestore for uid ...\(String(currentUid.suffix(4)))")
        let lang = LocalizationManager.shared.currentLanguage.rawValue
        db.collection(usersCollection).document(currentUid).setData([
            "fcmToken": token,
            "fcmTokenUpdatedAt": FieldValue.serverTimestamp(),
            "language": lang
        ], merge: true) { error in
            if let error = error {
                print("[FCM] ❌ Firestore setData error: \(error.localizedDescription)")
            }
            DispatchQueue.main.async { completion?(error) }
        }
    }

    /// Removes the FCM token from Firestore (call on logout)
    static func removeFCMToken(completion: ((Error?) -> Void)? = nil) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            completion?(nil) // No error if not logged in
            return
        }

        db.collection(usersCollection).document(currentUid).updateData([
            "fcmToken": FieldValue.delete(),
            "fcmTokenUpdatedAt": FieldValue.delete()
        ]) { error in
            DispatchQueue.main.async { completion?(error) }
        }
    }

    // MARK: - Notifications Center

    /// Fetches notification history for the current user
    static func fetchNotifications(limit: Int = 50, completion: @escaping ([NotificationItem]) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            completion([])
            return
        }

        db.collection(usersCollection).document(uid)
            .collection("notifications")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("[Notifications] Fetch error: \(error.localizedDescription)")
                    completion([])
                    return
                }

                let items: [NotificationItem] = snapshot?.documents.compactMap { doc in
                    let d = doc.data()
                    guard let typeStr = d["type"] as? String,
                          let type = NotificationType(rawValue: typeStr),
                          let title = d["title"] as? String,
                          let body = d["body"] as? String else { return nil }

                    let createdAt = (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    let read = d["read"] as? Bool ?? false
                    let data = d["data"] as? [String: Any] ?? [:]

                    return NotificationItem(
                        id: doc.documentID,
                        type: type,
                        title: title,
                        body: body,
                        data: data,
                        read: read,
                        createdAt: createdAt
                    )
                } ?? []

                DispatchQueue.main.async { completion(items) }
            }
    }

    /// Marks a single notification as read
    static func markNotificationAsRead(_ notificationId: String) {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        db.collection(usersCollection).document(uid)
            .collection("notifications").document(notificationId)
            .updateData(["read": true])
    }

    /// Marks all notifications as read
    static func markAllNotificationsAsRead() {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        let ref = db.collection(usersCollection).document(uid).collection("notifications")
        ref.whereField("read", isEqualTo: false).getDocuments { snapshot, _ in
            guard let docs = snapshot?.documents else { return }
            let batch = db.batch()
            for doc in docs {
                batch.updateData(["read": true], forDocument: doc.reference)
            }
            batch.commit()
        }
    }

    /// Returns the count of unread notifications
    static func fetchUnreadNotificationsCount(completion: @escaping (Int) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            completion(0)
            return
        }
        db.collection(usersCollection).document(uid)
            .collection("notifications")
            .whereField("read", isEqualTo: false)
            .getDocuments { snapshot, _ in
                DispatchQueue.main.async { completion(snapshot?.documents.count ?? 0) }
            }
    }

    // MARK: - Save Notification Item

    /// Saves a notification item to the user's notifications collection in Firestore
    static func saveNotificationItem(
        type: String,
        title: String,
        body: String,
        data: [String: Any] = [:],
        completion: ((Error?) -> Void)? = nil
    ) {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            completion?(NSError(domain: "FriendsFirestoreSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"]))
            return
        }

        let docData: [String: Any] = [
            "type": type,
            "title": title,
            "body": body,
            "data": data,
            "read": false,
            "createdAt": FieldValue.serverTimestamp()
        ]

        db.collection(usersCollection).document(uid)
            .collection("notifications")
            .addDocument(data: docData) { error in
                if let error = error {
                    print("[Notifications] Failed to save notification: \(error.localizedDescription)")
                }
                completion?(error)
            }
    }

    // MARK: - Morning Notification Settings

    /// Saves morning notification settings to Firestore for Cloud Function scheduling
    static func saveMorningNotificationSettings(
        enabled: Bool,
        hour: Int,
        minute: Int,
        completion: ((Error?) -> Void)? = nil
    ) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            completion?(NSError(domain: "FriendsFirestoreSync", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "sync.noUserLoggedIn".localized]))
            return
        }

        let settings: [String: Any] = [
            "morningNotification": [
                "enabled": enabled,
                "hour": hour,
                "minute": minute,
                "updatedAt": FieldValue.serverTimestamp()
            ]
        ]

        db.collection(usersCollection).document(currentUid).setData(settings, merge: true) { error in
            if let error = error {
                print("🔔 [Firestore] Failed to save morning notification settings: \(error)")
            } else {
                print("🔔 [Firestore] Morning notification settings saved - enabled: \(enabled), time: \(hour):\(minute)")
            }
            DispatchQueue.main.async { completion?(error) }
        }
    }

    // MARK: - Bedtime Notification Settings

    /// Saves bedtime notification settings to Firestore for Cloud Function scheduling
    static func saveBedtimeNotificationSettings(
        enabled: Bool,
        hour: Int,
        minute: Int,
        completion: ((Error?) -> Void)? = nil
    ) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            completion?(NSError(domain: "FriendsFirestoreSync", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "sync.noUserLoggedIn".localized]))
            return
        }

        let settings: [String: Any] = [
            "bedtimeNotification": [
                "enabled": enabled,
                "hour": hour,
                "minute": minute,
                "updatedAt": FieldValue.serverTimestamp()
            ]
        ]

        db.collection(usersCollection).document(currentUid).setData(settings, merge: true) { error in
            if let error = error {
                print("🌙 [Firestore] Failed to save bedtime notification settings: \(error)")
            } else {
                print("🌙 [Firestore] Bedtime notification settings saved - enabled: \(enabled), time: \(hour):\(minute)")
            }
            DispatchQueue.main.async { completion?(error) }
        }
    }
}
