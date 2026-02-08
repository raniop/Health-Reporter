//
//  AIONMemoryManager.swift
//  Health Reporter
//
//  Manages AION persistent memory – Firestore sync + local UserDefaults cache.
//  Follows the same pattern as AnalysisFirestoreSync.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

enum AIONMemoryManager {

    // MARK: - Keys & Paths

    private static let cacheKey = "AION.Memory"
    private static let collection = "users"
    private static let subcollection = "aionMemory"
    private static let documentId = "current"

    // MARK: - Load (Firestore)

    /// Loads memory from Firestore. Returns nil if no user or no data.
    static func load(completion: @escaping (AIONMemory?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            DispatchQueue.main.async { completion(loadFromCache()) }
            return
        }

        let db = Firestore.firestore()
        let doc = db.collection(collection).document(uid)
            .collection(subcollection).document(documentId)

        doc.getDocument { snap, err in
            guard err == nil,
                  let data = snap?.data(),
                  let jsonData = try? JSONSerialization.data(withJSONObject: data)
            else {
                DispatchQueue.main.async { completion(loadFromCache()) }
                return
            }
            // Decode on main queue to avoid Swift 6 concurrency warning
            DispatchQueue.main.async {
                guard let memory = try? JSONDecoder.firestoreDecoder().decode(AIONMemory.self, from: jsonData) else {
                    completion(loadFromCache())
                    return
                }
                saveToCache(memory)
                completion(memory)
            }
        }
    }

    // MARK: - Save (Firestore + Cache)

    /// Saves memory to Firestore (if logged in) and local cache.
    static func save(_ memory: AIONMemory, completion: ((Error?) -> Void)? = nil) {
        saveToCache(memory)

        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            completion?(nil)
            return
        }

        guard let data = try? JSONEncoder.firestoreEncoder().encode(memory),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            completion?(nil)
            return
        }

        let db = Firestore.firestore()
        let doc = db.collection(collection).document(uid)
            .collection(subcollection).document(documentId)

        doc.setData(dict, merge: false) { error in
            if let error = error {
                print("🧠 [AION Memory] Firestore save FAILED: \(error.localizedDescription)")
            } else {
                print("🧠 [AION Memory] Firestore save OK → users/\(uid)/aionMemory/current")
            }
            completion?(error)
        }
    }

    // MARK: - Local Cache

    /// Fast synchronous read from UserDefaults (used during prompt building).
    static func loadFromCache() -> AIONMemory? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(AIONMemory.self, from: data)
    }

    /// Saves to UserDefaults for fast access.
    static func saveToCache(_ memory: AIONMemory) {
        guard let data = try? JSONEncoder().encode(memory) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    // MARK: - Initial Memory

    /// Creates a fresh, empty memory for first-time users.
    static func createInitialMemory() -> AIONMemory {
        let profile = AIONUserProfile(
            displayName: Auth.auth().currentUser?.displayName,
            dataSource: nil,
            typicalSleepHours: nil,
            baselineHRV: nil,
            baselineRHR: nil,
            vo2maxRange: nil,
            fitnessLevel: nil,
            knownConditions: [],
            currentCarModel: nil,
            carHistoryBrief: nil
        )

        let insights = AIONLongitudinalInsights(
            sleepTrend: nil,
            recoveryPattern: nil,
            trainingPattern: nil,
            keyStrengths: [],
            persistentWeaknesses: [],
            supplementHistory: nil,
            notableEvents: []
        )

        return AIONMemory(
            userProfile: profile,
            longitudinalInsights: insights,
            recentAnalyses: [],
            interactionCount: 0,
            firstAnalysisDate: Date(),
            lastUpdatedDate: Date()
        )
    }

    // MARK: - Clear (logout / account deletion)

    static func clear() {
        UserDefaults.standard.removeObject(forKey: cacheKey)

        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        let db = Firestore.firestore()
        db.collection(collection).document(uid)
            .collection(subcollection).document(documentId)
            .delete { _ in }
    }
}

// MARK: - JSON Coding Helpers for Firestore Timestamps

private extension JSONEncoder {
    /// Encoder that converts Date to ISO8601 strings (Firestore-friendly).
    static func firestoreEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    /// Decoder that reads ISO8601 date strings.
    static func firestoreDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
