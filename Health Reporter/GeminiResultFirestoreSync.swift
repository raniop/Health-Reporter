//
//  GeminiResultFirestoreSync.swift
//  Health Reporter
//
//  Fetches a server-generated Gemini result from Firestore.
//  The Cloud Function `runGeminiAnalysis` (5:30 AM daily) writes results to
//  users/{uid}/geminiResults/latest. This service reads that result on app open
//  so the user doesn't have to wait for on-device analysis.
//
//  Includes a 2.5-second timeout — if Firestore doesn't respond in time,
//  the app falls through to the on-device Gemini path.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Server Result Model

struct ServerGeminiResult {
    let rawResponse: String
    let generatedAt: Date
    let language: String
}

// MARK: - Firestore Reader

enum GeminiResultFirestoreSync {

    private static let subcollection = "geminiResults"
    private static let docId = "latest"

    /// Fetches today's server-generated Gemini result from Firestore.
    ///
    /// Returns `nil` (via completion) if:
    /// - No logged-in user
    /// - No document exists
    /// - Document is not from today
    /// - Language doesn't match current app language
    /// - Firestore fetch exceeds the timeout
    ///
    /// - Parameters:
    ///   - timeout: Maximum seconds to wait for Firestore (default 2.5s)
    ///   - completion: Called on main thread with the result or nil
    static func fetchTodayResult(
        timeout: TimeInterval = 2.5,
        completion: @escaping (ServerGeminiResult?) -> Void
    ) {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            print("📥 [ResultSync] No logged-in user — skipping Firestore check")
            DispatchQueue.main.async { completion(nil) }
            return
        }

        let db = Firestore.firestore()
        let doc = db.collection("users").document(uid)
            .collection(subcollection).document(docId)

        // Thread-safe one-shot guard (ensures completion fires exactly once)
        var done = false
        let lock = NSLock()

        func completeOnce(_ result: ServerGeminiResult?) {
            lock.lock()
            guard !done else { lock.unlock(); return }
            done = true
            lock.unlock()
            DispatchQueue.main.async { completion(result) }
        }

        // Firestore fetch
        doc.getDocument { snap, err in
            if let err = err {
                print("📥 [ResultSync] Firestore error: \(err.localizedDescription)")
                completeOnce(nil)
                return
            }

            guard let data = snap?.data(),
                  let rawResponse = data["rawResponse"] as? String, !rawResponse.isEmpty,
                  let generatedAt = (data["generatedAt"] as? Timestamp)?.dateValue()
            else {
                print("📥 [ResultSync] No server result found")
                completeOnce(nil)
                return
            }

            // Must be from today
            guard Calendar.current.isDateInToday(generatedAt) else {
                print("📥 [ResultSync] Server result is stale (from \(generatedAt))")
                completeOnce(nil)
                return
            }

            // Language must match current app language
            let serverLang = data["language"] as? String ?? "en"
            let currentLang = LocalizationManager.shared.currentLanguage == .hebrew ? "he" : "en"
            guard serverLang == currentLang else {
                print("📥 [ResultSync] Language mismatch: server=\(serverLang), app=\(currentLang)")
                completeOnce(nil)
                return
            }

            let result = ServerGeminiResult(
                rawResponse: rawResponse,
                generatedAt: generatedAt,
                language: serverLang
            )
            print("📥 [ResultSync] ✅ Server result found (generated \(generatedAt), lang=\(serverLang))")
            completeOnce(result)
        }

        // Timeout guard — don't let the app wait forever
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout) {
            lock.lock()
            let wasDone = done
            lock.unlock()

            if !wasDone {
                print("📥 [ResultSync] ⏰ Firestore fetch timed out after \(timeout)s")
                completeOnce(nil)
            }
        }
    }
}
