//
//  GeminiPayloadSync.swift
//  Health Reporter
//
//  Uploads the fully-constructed Gemini prompt to Firestore so a server-side
//  Cloud Function can run the analysis at 5:30 AM — before the user wakes up.
//
//  This is a fire-and-forget upload: it never blocks the on-device Gemini flow.
//  The Cloud Function reads the prompt, sends it to Gemini, and stores the result
//  in users/{uid}/geminiResults/latest for the app to consume on next launch.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

enum GeminiPayloadSync {

    // MARK: - Firestore Paths

    private static let subcollection = "geminiPayloads"
    private static let docId = "latest"

    // MARK: - Upload

    /// Uploads the full Gemini prompt + system instruction to Firestore.
    /// Called from GeminiService after the prompt is constructed (fire-and-forget).
    static func uploadPayload(
        prompt: String,
        systemInstruction: String,
        language: String,
        dataSourceDate: String,
        completion: ((Error?) -> Void)? = nil
    ) {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            print("📤 [PayloadSync] No logged-in user — skipping upload")
            completion?(nil)
            return
        }

        let db = Firestore.firestore()
        let doc = db.collection("users").document(uid)
            .collection(subcollection).document(docId)

        let data: [String: Any] = [
            "prompt": prompt,
            "systemInstruction": systemInstruction,
            "uploadedAt": FieldValue.serverTimestamp(),
            "promptVersion": 1,
            "language": language,
            "dataSourceDate": dataSourceDate,
            "status": "pending",
            "processedAt": NSNull(),
            "error": NSNull()
        ]

        doc.setData(data) { error in
            if let error = error {
                print("📤 [PayloadSync] ❌ Upload failed: \(error.localizedDescription)")
            } else {
                print("📤 [PayloadSync] ✅ Prompt uploaded (\(prompt.count) chars, lang=\(language), date=\(dataSourceDate))")
            }
            completion?(error)
        }
    }
}
