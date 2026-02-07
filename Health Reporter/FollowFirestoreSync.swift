//
//  FollowFirestoreSync.swift
//  Health Reporter
//
//  Managing followers and follow requests in Firestore.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

enum FollowFirestoreSync {

    private static let db = Firestore.firestore()
    private static let usersCollection = "users"
    private static let followingSubcollection = "following"
    private static let followersSubcollection = "followers"
    private static let followRequestsCollection = "followRequests"

    // MARK: - Follow User

    /// Follow a user. If their privacy is "open", follow directly.
    /// If "approval", create a follow request.
    static func followUser(targetUid: String, completion: ((Error?) -> Void)? = nil) {
        guard let currentUser = Auth.auth().currentUser,
              let currentUid = currentUser.uid as String?,
              !currentUid.isEmpty else {
            completion?(NSError(domain: "FollowFirestoreSync", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "No user logged in"]))
            return
        }

        // Don't follow self
        guard targetUid != currentUid else {
            completion?(NSError(domain: "FollowFirestoreSync", code: -2,
                                userInfo: [NSLocalizedDescriptionKey: "Cannot follow yourself"]))
            return
        }

        // Check target's follow privacy setting
        db.collection(usersCollection).document(targetUid).getDocument { snapshot, error in
            if let error = error {
                DispatchQueue.main.async { completion?(error) }
                return
            }

            let data = snapshot?.data()
            let privacyStr = data?["followPrivacy"] as? String ?? FollowPrivacy.open.rawValue
            let privacy = FollowPrivacy(rawValue: privacyStr) ?? .open

            // Extract target user's profile for storing in following subcollection
            let targetDisplayName = data?["displayName"] as? String
            let targetPhotoURL = data?["photoURL"] as? String

            if privacy == .open {
                // Direct follow — add to both subcollections and increment counts
                performDirectFollow(currentUser: currentUser, currentUid: currentUid,
                                    targetUid: targetUid,
                                    targetDisplayName: targetDisplayName,
                                    targetPhotoURL: targetPhotoURL,
                                    completion: completion)
            } else {
                // Requires approval — create a follow request
                createFollowRequest(currentUser: currentUser, currentUid: currentUid,
                                    targetUid: targetUid, completion: completion)
            }
        }
    }

    private static func performDirectFollow(currentUser: User, currentUid: String,
                                             targetUid: String,
                                             targetDisplayName: String? = nil,
                                             targetPhotoURL: String? = nil,
                                             completion: ((Error?) -> Void)?) {
        let displayName = currentUser.displayName ?? "Unknown User"
        let photoURL = currentUser.photoURL?.absoluteString
        let batch = db.batch()

        // Add target to my following subcollection
        let myFollowingRef = db.collection(usersCollection).document(currentUid)
            .collection(followingSubcollection).document(targetUid)
        batch.setData([
            "uid": targetUid,
            "displayName": targetDisplayName ?? "Unknown User",
            "photoURL": targetPhotoURL as Any,
            "followedAt": FieldValue.serverTimestamp()
        ], forDocument: myFollowingRef)

        // Add me to target's followers subcollection
        let theirFollowerRef = db.collection(usersCollection).document(targetUid)
            .collection(followersSubcollection).document(currentUid)
        batch.setData([
            "uid": currentUid,
            "displayName": displayName,
            "photoURL": photoURL as Any,
            "followedAt": FieldValue.serverTimestamp(),
            "source": "direct"
        ], forDocument: theirFollowerRef)

        // Increment my followingCount
        let myUserRef = db.collection(usersCollection).document(currentUid)
        batch.updateData([
            "followingCount": FieldValue.increment(Int64(1))
        ], forDocument: myUserRef)

        // Increment target's followersCount
        let theirUserRef = db.collection(usersCollection).document(targetUid)
        batch.updateData([
            "followersCount": FieldValue.increment(Int64(1))
        ], forDocument: theirUserRef)

        batch.commit { error in
            DispatchQueue.main.async { completion?(error) }
        }
    }

    private static func createFollowRequest(currentUser: User, currentUid: String,
                                             targetUid: String, completion: ((Error?) -> Void)?) {
        let displayName = currentUser.displayName ?? "Unknown User"
        let photoURL = currentUser.photoURL?.absoluteString

        let requestData: [String: Any] = [
            "fromUid": currentUid,
            "fromDisplayName": displayName,
            "fromPhotoURL": photoURL as Any,
            "toUid": targetUid,
            "status": FollowRequestStatus.pending.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        db.collection(followRequestsCollection).addDocument(data: requestData) { error in
            DispatchQueue.main.async { completion?(error) }
        }
    }

    // MARK: - Accept Follow Request

    static func acceptFollowRequest(requestId: String, completion: ((Error?) -> Void)? = nil) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            completion?(NSError(domain: "FollowFirestoreSync", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "No user logged in"]))
            return
        }

        let requestRef = db.collection(followRequestsCollection).document(requestId)

        // First get the request data
        requestRef.getDocument { snapshot, error in
            guard let data = snapshot?.data(),
                  let fromUid = data["fromUid"] as? String,
                  let fromDisplayName = data["fromDisplayName"] as? String,
                  let toUid = data["toUid"] as? String else {
                DispatchQueue.main.async {
                    completion?(error ?? NSError(domain: "FollowFirestoreSync", code: -3,
                                                 userInfo: [NSLocalizedDescriptionKey: "Request not found"]))
                }
                return
            }

            let fromPhotoURL = data["fromPhotoURL"] as? String
            let batch = db.batch()

            // Update request status
            batch.updateData([
                "status": FollowRequestStatus.accepted.rawValue,
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: requestRef)

            // Add requester to target's (current user's) followers subcollection
            let followerRef = db.collection(usersCollection).document(toUid)
                .collection(followersSubcollection).document(fromUid)
            batch.setData([
                "uid": fromUid,
                "displayName": fromDisplayName,
                "photoURL": fromPhotoURL as Any,
                "followedAt": FieldValue.serverTimestamp(),
                "source": "request"
            ], forDocument: followerRef)

            // Add target (current user) to requester's following subcollection
            fetchCurrentUserProfile { myName, myPhoto in
                let followingRef = db.collection(usersCollection).document(fromUid)
                    .collection(followingSubcollection).document(toUid)
                batch.setData([
                    "uid": toUid,
                    "displayName": myName ?? "Unknown User",
                    "photoURL": myPhoto as Any,
                    "followedAt": FieldValue.serverTimestamp()
                ], forDocument: followingRef)

                // Increment target's (current user's) followersCount
                let myUserRef = db.collection(usersCollection).document(toUid)
                batch.updateData([
                    "followersCount": FieldValue.increment(Int64(1))
                ], forDocument: myUserRef)

                // Increment requester's followingCount
                let theirUserRef = db.collection(usersCollection).document(fromUid)
                batch.updateData([
                    "followingCount": FieldValue.increment(Int64(1))
                ], forDocument: theirUserRef)

                batch.commit { error in
                    DispatchQueue.main.async { completion?(error) }
                }
            }
        }
    }

    // MARK: - Decline Follow Request

    static func declineFollowRequest(requestId: String, completion: ((Error?) -> Void)? = nil) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            completion?(NSError(domain: "FollowFirestoreSync", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "No user logged in"]))
            return
        }

        db.collection(followRequestsCollection).document(requestId).updateData([
            "status": FollowRequestStatus.declined.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ]) { error in
            DispatchQueue.main.async { completion?(error) }
        }
    }

    // MARK: - Cancel Follow Request (withdraw sent request)

    static func cancelFollowRequest(requestId: String, completion: ((Error?) -> Void)? = nil) {
        db.collection(followRequestsCollection).document(requestId).delete { error in
            DispatchQueue.main.async { completion?(error) }
        }
    }

    // MARK: - Unfollow User

    static func unfollowUser(targetUid: String, completion: ((Error?) -> Void)? = nil) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            completion?(NSError(domain: "FollowFirestoreSync", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "No user logged in"]))
            return
        }

        // Check if the follow document actually exists before decrementing counters
        let myFollowingRef = db.collection(usersCollection).document(currentUid)
            .collection(followingSubcollection).document(targetUid)

        myFollowingRef.getDocument { snapshot, error in
            guard snapshot?.exists == true else {
                // Document doesn't exist — nothing to unfollow, fix counters
                recalculateCounts(for: currentUid)
                DispatchQueue.main.async { completion?(nil) }
                return
            }

            let batch = db.batch()

            // Remove target from my following
            batch.deleteDocument(myFollowingRef)

            // Remove me from target's followers
            let theirFollowerRef = db.collection(usersCollection).document(targetUid)
                .collection(followersSubcollection).document(currentUid)
            batch.deleteDocument(theirFollowerRef)

            // Decrement my followingCount
            let myUserRef = db.collection(usersCollection).document(currentUid)
            batch.updateData([
                "followingCount": FieldValue.increment(Int64(-1))
            ], forDocument: myUserRef)

            // Decrement target's followersCount
            let theirUserRef = db.collection(usersCollection).document(targetUid)
            batch.updateData([
                "followersCount": FieldValue.increment(Int64(-1))
            ], forDocument: theirUserRef)

            batch.commit { error in
                DispatchQueue.main.async { completion?(error) }
            }
        }
    }

    // MARK: - Remove Follower

    static func removeFollower(followerUid: String, completion: ((Error?) -> Void)? = nil) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            completion?(NSError(domain: "FollowFirestoreSync", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "No user logged in"]))
            return
        }

        // Check if the follower document actually exists before decrementing counters
        let myFollowerRef = db.collection(usersCollection).document(currentUid)
            .collection(followersSubcollection).document(followerUid)

        myFollowerRef.getDocument { snapshot, error in
            guard snapshot?.exists == true else {
                // Document doesn't exist — nothing to remove, fix counters
                recalculateCounts(for: currentUid)
                DispatchQueue.main.async { completion?(nil) }
                return
            }

            let batch = db.batch()

            // Remove follower from my followers
            batch.deleteDocument(myFollowerRef)

            // Remove me from follower's following
            let theirFollowingRef = db.collection(usersCollection).document(followerUid)
                .collection(followingSubcollection).document(currentUid)
            batch.deleteDocument(theirFollowingRef)

            // Decrement my followersCount
            let myUserRef = db.collection(usersCollection).document(currentUid)
            batch.updateData([
                "followersCount": FieldValue.increment(Int64(-1))
            ], forDocument: myUserRef)

            // Decrement follower's followingCount
            let theirUserRef = db.collection(usersCollection).document(followerUid)
            batch.updateData([
                "followingCount": FieldValue.increment(Int64(-1))
            ], forDocument: theirUserRef)

            batch.commit { error in
                DispatchQueue.main.async { completion?(error) }
            }
        }
    }

    // MARK: - Fetch Following

    static func fetchFollowing(for uid: String? = nil, completion: @escaping ([FollowRelation]) -> Void) {
        let targetUid = uid ?? Auth.auth().currentUser?.uid
        guard let targetUid = targetUid, !targetUid.isEmpty else {
            DispatchQueue.main.async { completion([]) }
            return
        }

        db.collection(usersCollection).document(targetUid)
            .collection(followingSubcollection)
            .order(by: "followedAt", descending: true)
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }

                var relations: [FollowRelation] = docs.compactMap { doc in
                    let data = doc.data()
                    let uid = data["uid"] as? String ?? doc.documentID
                    let displayName = data["displayName"] as? String ?? "Unknown User"
                    let followedAt = (data["followedAt"] as? Timestamp)?.dateValue() ?? Date()

                    return FollowRelation(
                        uid: uid,
                        displayName: displayName,
                        photoURL: data["photoURL"] as? String,
                        followedAt: followedAt
                    )
                }

                // Enrich with scores from publicScores
                let uids = relations.map { $0.uid }
                fetchScoresForUsers(uids: uids) { scoresMap in
                    for i in relations.indices {
                        if let scoreData = scoresMap[relations[i].uid] {
                            relations[i].carTierIndex = scoreData.tierIndex
                            relations[i].carTierName = scoreData.tierName
                            relations[i].healthScore = scoreData.score
                            relations[i].lastUpdated = scoreData.lastUpdated
                            // Use photoURL from publicScores as fallback
                            if relations[i].photoURL == nil || relations[i].photoURL?.isEmpty == true {
                                relations[i].photoURL = scoreData.photoURL
                            }
                        } else {
                            relations[i].healthScore = 0
                        }
                    }
                    DispatchQueue.main.async { completion(relations) }
                }
            }
    }

    // MARK: - Fetch Followers

    static func fetchFollowers(for uid: String? = nil, completion: @escaping ([FollowRelation]) -> Void) {
        let targetUid = uid ?? Auth.auth().currentUser?.uid
        guard let targetUid = targetUid, !targetUid.isEmpty else {
            DispatchQueue.main.async { completion([]) }
            return
        }

        db.collection(usersCollection).document(targetUid)
            .collection(followersSubcollection)
            .order(by: "followedAt", descending: true)
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }

                var relations: [FollowRelation] = docs.compactMap { doc in
                    let data = doc.data()
                    let uid = data["uid"] as? String ?? doc.documentID
                    let displayName = data["displayName"] as? String ?? "Unknown User"
                    let followedAt = (data["followedAt"] as? Timestamp)?.dateValue() ?? Date()

                    return FollowRelation(
                        uid: uid,
                        displayName: displayName,
                        photoURL: data["photoURL"] as? String,
                        followedAt: followedAt
                    )
                }

                // Enrich with scores from publicScores
                let uids = relations.map { $0.uid }
                fetchScoresForUsers(uids: uids) { scoresMap in
                    for i in relations.indices {
                        if let scoreData = scoresMap[relations[i].uid] {
                            relations[i].carTierIndex = scoreData.tierIndex
                            relations[i].carTierName = scoreData.tierName
                            relations[i].healthScore = scoreData.score
                            if relations[i].photoURL == nil || relations[i].photoURL?.isEmpty == true {
                                relations[i].photoURL = scoreData.photoURL
                            }
                        } else {
                            relations[i].healthScore = 0
                        }
                    }
                    DispatchQueue.main.async { completion(relations) }
                }
            }
    }

    // MARK: - Fetch Followers Count

    static func fetchFollowersCount(for uid: String, completion: @escaping (Int) -> Void) {
        guard !uid.isEmpty else {
            DispatchQueue.main.async { completion(0) }
            return
        }

        // Count from actual subcollection for accuracy, then sync the cached counter
        db.collection(usersCollection).document(uid)
            .collection(followersSubcollection).getDocuments { snapshot, _ in
                let actual = snapshot?.documents.count ?? 0
                // Sync the cached counter field
                db.collection(usersCollection).document(uid).updateData([
                    "followersCount": actual
                ])
                DispatchQueue.main.async { completion(actual) }
            }
    }

    // MARK: - Fetch Following Count

    static func fetchFollowingCount(for uid: String, completion: @escaping (Int) -> Void) {
        guard !uid.isEmpty else {
            DispatchQueue.main.async { completion(0) }
            return
        }

        // Count from actual subcollection for accuracy, then sync the cached counter
        db.collection(usersCollection).document(uid)
            .collection(followingSubcollection).getDocuments { snapshot, _ in
                let actual = snapshot?.documents.count ?? 0
                // Sync the cached counter field
                db.collection(usersCollection).document(uid).updateData([
                    "followingCount": actual
                ])
                DispatchQueue.main.async { completion(actual) }
            }
    }

    // MARK: - Fetch Pending Follow Requests (incoming)

    static func fetchPendingFollowRequests(completion: @escaping ([FollowRequest]) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            DispatchQueue.main.async { completion([]) }
            return
        }

        db.collection(followRequestsCollection)
            .whereField("toUid", isEqualTo: currentUid)
            .whereField("status", isEqualTo: FollowRequestStatus.pending.rawValue)
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }

                var requests: [FollowRequest] = docs.compactMap { doc in
                    let data = doc.data()
                    guard let fromUid = data["fromUid"] as? String,
                          let fromDisplayName = data["fromDisplayName"] as? String,
                          let toUid = data["toUid"] as? String,
                          let statusStr = data["status"] as? String,
                          let status = FollowRequestStatus(rawValue: statusStr) else { return nil }

                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()

                    return FollowRequest(
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

                // Sort locally to avoid requiring a composite index
                requests.sort { $0.createdAt > $1.createdAt }

                DispatchQueue.main.async { completion(requests) }
            }
    }

    // MARK: - Fetch Pending Follow Requests Count (for badge)

    static func fetchPendingFollowRequestsCount(completion: @escaping (Int) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            DispatchQueue.main.async { completion(0) }
            return
        }

        db.collection(followRequestsCollection)
            .whereField("toUid", isEqualTo: currentUid)
            .whereField("status", isEqualTo: FollowRequestStatus.pending.rawValue)
            .getDocuments { snapshot, _ in
                let count = snapshot?.documents.count ?? 0
                DispatchQueue.main.async { completion(count) }
            }
    }

    // MARK: - Fetch Sent Follow Requests (outgoing)

    static func fetchSentFollowRequests(completion: @escaping ([FollowRequest]) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            DispatchQueue.main.async { completion([]) }
            return
        }

        db.collection(followRequestsCollection)
            .whereField("fromUid", isEqualTo: currentUid)
            .whereField("status", isEqualTo: FollowRequestStatus.pending.rawValue)
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }

                let requests: [FollowRequest] = docs.compactMap { doc in
                    let data = doc.data()
                    guard let fromUid = data["fromUid"] as? String,
                          let toUid = data["toUid"] as? String,
                          let statusStr = data["status"] as? String,
                          let status = FollowRequestStatus(rawValue: statusStr) else { return nil }

                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

                    return FollowRequest(
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

    // MARK: - Follow Privacy

    static func getFollowPrivacy(completion: @escaping (FollowPrivacy) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            DispatchQueue.main.async { completion(.open) }
            return
        }

        db.collection(usersCollection).document(currentUid).getDocument { snapshot, _ in
            let privacyStr = snapshot?.data()?["followPrivacy"] as? String ?? FollowPrivacy.open.rawValue
            let privacy = FollowPrivacy(rawValue: privacyStr) ?? .open
            DispatchQueue.main.async { completion(privacy) }
        }
    }

    static func setFollowPrivacy(_ privacy: FollowPrivacy, completion: ((Error?) -> Void)? = nil) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            completion?(NSError(domain: "FollowFirestoreSync", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "No user logged in"]))
            return
        }

        db.collection(usersCollection).document(currentUid).setData([
            "followPrivacy": privacy.rawValue
        ], merge: true) { error in
            DispatchQueue.main.async { completion?(error) }
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
            let displayName = data["displayName"] as? String ?? "Unknown User"

            return UserSearchResult(
                uid: doc.documentID,
                displayName: displayName,
                photoURL: data["photoURL"] as? String
            )
        }
    }

    // MARK: - Helpers

    /// Recalculate followersCount and followingCount from actual subcollection documents.
    /// Fixes counters that went negative due to double-deletions.
    static func recalculateCounts(for uid: String) {
        let userRef = db.collection(usersCollection).document(uid)

        // Count actual followers
        userRef.collection(followersSubcollection).getDocuments { snapshot, _ in
            let actualFollowers = snapshot?.documents.count ?? 0
            userRef.updateData(["followersCount": actualFollowers])
        }

        // Count actual following
        userRef.collection(followingSubcollection).getDocuments { snapshot, _ in
            let actualFollowing = snapshot?.documents.count ?? 0
            userRef.updateData(["followingCount": actualFollowing])
        }
    }

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

        // Check following list (people I follow)
        group.enter()
        fetchFollowing { following in
            let followingUids = Set(following.map { $0.uid })
            for i in 0..<enrichedResults.count {
                if followingUids.contains(enrichedResults[i].uid) {
                    enrichedResults[i].isFollowing = true
                }
            }
            group.leave()
        }

        // Check followers list (people who follow me)
        group.enter()
        fetchFollowers { followers in
            let followerUids = Set(followers.map { $0.uid })
            for i in 0..<enrichedResults.count {
                if followerUids.contains(enrichedResults[i].uid) {
                    enrichedResults[i].isFollowedBy = true
                }
            }
            group.leave()
        }

        // Check sent follow requests
        group.enter()
        fetchSentFollowRequests { requests in
            let sentToUids = Set(requests.map { $0.toUid })
            for i in 0..<enrichedResults.count {
                if sentToUids.contains(enrichedResults[i].uid) {
                    enrichedResults[i].hasPendingRequest = true
                    enrichedResults[i].requestSentByMe = true
                }
            }
            group.leave()
        }

        // Check incoming follow requests
        group.enter()
        fetchPendingFollowRequests { requests in
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

    private static func fetchScoresForUsers(uids: [String], completion: @escaping ([String: (score: Int, tierIndex: Int, tierName: String, photoURL: String?, lastUpdated: Date?)]) -> Void) {
        guard !uids.isEmpty else {
            completion([:])
            return
        }

        // Firestore 'in' queries limited to 10 items
        let chunkedUids = stride(from: 0, to: uids.count, by: 10).map {
            Array(uids[$0..<min($0 + 10, uids.count)])
        }

        var scoresMap: [String: (score: Int, tierIndex: Int, tierName: String, photoURL: String?, lastUpdated: Date?)] = [:]
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
                            let lastUpdated = (data["lastUpdated"] as? Timestamp)?.dateValue()
                            scoresMap[doc.documentID] = (score, tierIndex, tierName, photoURL, lastUpdated)
                        }
                    }
                    group.leave()
                }
        }

        group.notify(queue: .main) {
            completion(scoresMap)
        }
    }
}
