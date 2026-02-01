//
//  LeaderboardFirestoreSync.swift
//  Health Reporter
//
//  סנכרון ציונים ושליפת לידרבורד מ-Firestore.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

enum LeaderboardFirestoreSync {

    private static let db = Firestore.firestore()
    private static let usersCollection = "users"
    private static let publicScoresCollection = "publicScores"
    private static let friendsSubcollection = "friends"

    // MARK: - Privacy Settings

    /// קבלת הגדרת פרטיות - האם המשתמש מופיע בלידרבורד הגלובלי
    static func getLeaderboardOptIn(completion: @escaping (Bool) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            DispatchQueue.main.async { completion(false) }
            return
        }

        db.collection(usersCollection).document(currentUid).getDocument { snapshot, _ in
            let optIn = snapshot?.data()?["leaderboardOptIn"] as? Bool ?? false
            DispatchQueue.main.async { completion(optIn) }
        }
    }

    /// עדכון הגדרת פרטיות
    static func setLeaderboardOptIn(_ optIn: Bool, completion: ((Error?) -> Void)? = nil) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            completion?(NSError(domain: "LeaderboardFirestoreSync", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "sync.noUserLoggedIn".localized]))
            return
        }

        let batch = db.batch()

        // Update user document
        let userRef = db.collection(usersCollection).document(currentUid)
        batch.setData(["leaderboardOptIn": optIn], forDocument: userRef, merge: true)

        // Update publicScores document
        let publicRef = db.collection(publicScoresCollection).document(currentUid)
        batch.setData(["isPublic": optIn], forDocument: publicRef, merge: true)

        batch.commit { error in
            DispatchQueue.main.async { completion?(error) }
        }
    }

    // MARK: - Score Syncing

    /// סנכרון ציון ללידרבורד - נקרא אחרי חישוב ציון חדש
    /// - Parameters:
    ///   - score: ציון הבריאות
    ///   - tier: ה-tier מהמערך הקבוע (לצורך tierIndex ו-tierLabel)
    ///   - geminiCarName: שם הרכב האמיתי מ-Gemini (אופציונלי)
    static func syncScore(score: Int, tier: CarTier, geminiCarName: String? = nil, completion: ((Error?) -> Void)? = nil) {
        guard let currentUser = Auth.auth().currentUser,
              let currentUid = currentUser.uid as String?,
              !currentUid.isEmpty else {
            completion?(nil) // Silent fail if not logged in
            return
        }

        // Get user profile data
        db.collection(usersCollection).document(currentUid).getDocument { snapshot, _ in
            let userData = snapshot?.data()
            let displayName = userData?["displayName"] as? String ?? currentUser.displayName ?? "social.unknownUser".localized
            let photoURL = userData?["photoURL"] as? String ?? currentUser.photoURL?.absoluteString
            let optIn = userData?["leaderboardOptIn"] as? Bool ?? false

            // Build scoreData - only include carTierName if we have a geminiCarName
            var scoreData: [String: Any] = [
                "uid": currentUid,
                "displayName": displayName,
                "displayNameLower": displayName.lowercased(), // For search
                "photoURL": photoURL as Any,
                "healthScore": score,
                "carTierIndex": tier.tierIndex,
                "carTierLabel": tier.tierLabel,
                "lastUpdated": FieldValue.serverTimestamp(),
                "isPublic": optIn
            ]

            // Only update carTierName if we have a real name from Gemini
            // This prevents overwriting the existing car name with default tier name
            if let carName = geminiCarName {
                scoreData["carTierName"] = carName
            }

            let batch = db.batch()

            // Update user document with score and profile data (for search)
            let userRef = db.collection(usersCollection).document(currentUid)
            var userUpdateData: [String: Any] = [
                "healthScore": score,
                "carTierIndex": tier.tierIndex,
                "lastScoreUpdate": FieldValue.serverTimestamp(),
                "displayName": displayName,
                "displayNameLower": displayName.lowercased() // Ensure search field exists
            ]
            // Also sync photoURL to users collection for search results
            if let photo = photoURL {
                userUpdateData["photoURL"] = photo
            }
            batch.setData(userUpdateData, forDocument: userRef, merge: true)

            // Update publicScores collection
            let publicRef = db.collection(publicScoresCollection).document(currentUid)
            batch.setData(scoreData, forDocument: publicRef, merge: true)

            batch.commit { error in
                DispatchQueue.main.async { completion?(error) }
            }
        }
    }

    // MARK: - Fetch Global Leaderboard

    static func fetchGlobalLeaderboard(limit: Int = 50, completion: @escaping ([LeaderboardEntry]) -> Void) {
        let currentUid = Auth.auth().currentUser?.uid

        db.collection(publicScoresCollection)
            .whereField("isPublic", isEqualTo: true)
            .order(by: "healthScore", descending: true)
            .limit(to: limit)
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }

                var entries: [LeaderboardEntry] = docs.enumerated().compactMap { index, doc in
                    guard var entry = parseLeaderboardEntry(from: doc) else { return nil }
                    entry.rank = index + 1
                    entry.isCurrentUser = (doc.documentID == currentUid)
                    return entry
                }

                DispatchQueue.main.async { completion(entries) }
            }
    }

    // MARK: - Fetch Friends Leaderboard

    static func fetchFriendsLeaderboard(completion: @escaping ([LeaderboardEntry]) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            DispatchQueue.main.async { completion([]) }
            return
        }

        // First get friends list
        FriendsFirestoreSync.fetchFriends { friends in
            guard !friends.isEmpty else {
                // Return only current user if no friends
                fetchCurrentUserEntry { entry in
                    if var e = entry {
                        e.rank = 1
                        e.isCurrentUser = true
                        completion([e])
                    } else {
                        completion([])
                    }
                }
                return
            }

            // Get friend UIDs + current user
            var uids = friends.map { $0.uid }
            uids.append(currentUid)

            // Firestore 'in' query limited to 30 items
            let chunks = uids.chunked(into: 30)
            var allEntries: [LeaderboardEntry] = []
            let group = DispatchGroup()

            for chunk in chunks {
                group.enter()
                db.collection(publicScoresCollection)
                    .whereField("uid", in: chunk)
                    .getDocuments { snapshot, _ in
                        if let docs = snapshot?.documents {
                            let entries = docs.compactMap { parseLeaderboardEntry(from: $0) }
                            allEntries.append(contentsOf: entries)
                        }
                        group.leave()
                    }
            }

            group.notify(queue: .main) {
                // Sort by score descending and assign ranks
                var sorted = allEntries.sorted { $0.healthScore > $1.healthScore }
                for i in 0..<sorted.count {
                    sorted[i].rank = i + 1
                    sorted[i].isCurrentUser = (sorted[i].uid == currentUid)
                }
                completion(sorted)
            }
        }
    }

    // MARK: - Fetch User Rank

    static func fetchUserRank(completion: @escaping (Int?) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        // Get user's score first
        db.collection(publicScoresCollection).document(currentUid).getDocument { snapshot, _ in
            guard let data = snapshot?.data(),
                  let userScore = data["healthScore"] as? Int,
                  data["isPublic"] as? Bool == true else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // Count users with higher scores
            db.collection(publicScoresCollection)
                .whereField("isPublic", isEqualTo: true)
                .whereField("healthScore", isGreaterThan: userScore)
                .getDocuments { snapshot, _ in
                    let higherCount = snapshot?.documents.count ?? 0
                    DispatchQueue.main.async { completion(higherCount + 1) }
                }
        }
    }

    // MARK: - Helpers

    private static func parseLeaderboardEntry(from doc: DocumentSnapshot) -> LeaderboardEntry? {
        guard let data = doc.data(),
              let uid = data["uid"] as? String,
              let displayName = data["displayName"] as? String,
              let healthScore = data["healthScore"] as? Int,
              let carTierIndex = data["carTierIndex"] as? Int,
              let carTierName = data["carTierName"] as? String else {
            return nil
        }

        let lastUpdated = (data["lastUpdated"] as? Timestamp)?.dateValue() ?? Date()
        let isPublic = data["isPublic"] as? Bool ?? false
        let carTierLabel = data["carTierLabel"] as? String ?? CarTierEngine.tiers[safe: carTierIndex]?.tierLabel ?? ""

        return LeaderboardEntry(
            uid: uid,
            displayName: displayName,
            photoURL: data["photoURL"] as? String,
            healthScore: healthScore,
            carTierIndex: carTierIndex,
            carTierName: carTierName,
            carTierLabel: carTierLabel,
            lastUpdated: lastUpdated,
            isPublic: isPublic
        )
    }

    private static func fetchCurrentUserEntry(completion: @escaping (LeaderboardEntry?) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid, !currentUid.isEmpty else {
            completion(nil)
            return
        }

        db.collection(publicScoresCollection).document(currentUid).getDocument { snapshot, _ in
            guard let doc = snapshot, doc.exists else {
                completion(nil)
                return
            }
            completion(parseLeaderboardEntry(from: doc))
        }
    }
}

// MARK: - Array Extension

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }

    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
