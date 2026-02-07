//
//  AnalysisFirestoreSync.swift
//  Health Reporter
//
//  Sync AION analysis data to Firestore – available from any device per logged-in user.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

enum AnalysisFirestoreSync {

    private static let collection = "users"
    private static let fieldInsights = "insights"
    private static let fieldRecommendations = "recommendations"
    private static let fieldLastAnalysisDate = "lastAnalysisDate"
    private static let maxAgeSeconds: TimeInterval = 24 * 3600

    /// Save analysis data to Firestore. Only called when a user is logged in.
    static func saveIfLoggedIn(insights: String, recommendations: String) {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        let db = Firestore.firestore()
        let doc = db.collection(collection).document(uid)
        let now = Timestamp(date: Date())
        doc.setData([
            fieldInsights: insights,
            fieldRecommendations: recommendations,
            fieldLastAnalysisDate: now,
        ], merge: true) { _ in }
    }

    /// Load analysis data from Firestore. Returns nil if no user or no data.
    /// Data may be stale (>24h) – the caller decides whether to use it.
    static func fetch(
        timeout: TimeInterval = 2.5,
        completion: @escaping ((insights: String, recommendations: String, date: Date)?) -> Void
    ) {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        let db = Firestore.firestore()
        let doc = db.collection(collection).document(uid)
        var done = false
        let lock = NSLock()

        doc.getDocument { snap, err in
            lock.lock()
            defer { lock.unlock() }
            guard !done else { return }
            done = true

            guard err == nil,
                  let data = snap?.data(),
                  let ins = data[fieldInsights] as? String, !ins.isEmpty,
                  let rec = data[fieldRecommendations] as? String else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let date: Date
            if let ts = data[fieldLastAnalysisDate] as? Timestamp {
                date = ts.dateValue()
            } else {
                date = Date()
            }
            DispatchQueue.main.async { completion((ins, rec, date)) }
        }

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout) {
            lock.lock()
            guard !done else { lock.unlock(); return }
            done = true
            lock.unlock()
            DispatchQueue.main.async { completion(nil) }
        }
    }

    /// Whether the data is still "valid" for use as cache (less than 24h).
    static func isValidCache(date: Date) -> Bool {
        Date().timeIntervalSince(date) < maxAgeSeconds
    }
    
    /// Clear all saved data in Firestore (if a user is logged in)
    static func clear() {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        let db = Firestore.firestore()
        let doc = db.collection(collection).document(uid)
        doc.updateData([
            fieldInsights: FieldValue.delete(),
            fieldRecommendations: FieldValue.delete(),
            fieldLastAnalysisDate: FieldValue.delete(),
        ]) { _ in }
    }
}
