//
//  AnalysisFirestoreSync.swift
//  Health Reporter
//
//  סנכרון נתוני ניתוח AION ל-Firestore – זמין מכל מכשיר לפי משתמש מחובר.
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

    /// שומר נתוני ניתוח ל-Firestore. קורא רק כאשר יש משתמש מחובר.
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

    /// טוען נתוני ניתוח מ-Firestore. מחזיר nil אם אין משתמש או אין נתונים.
    /// ייתכן שהנתונים ישנים (>24h) – ה־caller יחליט אם להשתמש.
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

    /// האם הנתונים עדיין "תקפים" לשימוש כקאש (פחות מ-24h).
    static func isValidCache(date: Date) -> Bool {
        Date().timeIntervalSince(date) < maxAgeSeconds
    }
    
    /// מנקה את כל הנתונים השמורים ב-Firestore (אם יש משתמש מחובר)
    static func clear() {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        let db = Firestore.firestore()
        let doc = db.collection(collection).document(uid)
        doc.updateData([
            fieldInsights: FieldValue.delete(),
            fieldRecommendations: FieldValue.delete(),
            fieldLastAnalysisDate: FieldValue.delete(),
        ]) { _ in }
        print("=== FIRESTORE ANALYSIS DATA CLEARED ===")
    }
}
