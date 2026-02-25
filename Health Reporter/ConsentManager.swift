//
//  ConsentManager.swift
//  Health Reporter
//
//  Manages user consent for:
//  1. AI Analysis — sending health data to Google Gemini AI
//  2. Leaderboard — appearing on the global leaderboard
//
//  Consent is stored locally (UserDefaults) for instant access and also
//  synced to Firestore for server-side awareness.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

enum ConsentManager {

    // MARK: - Keys

    private static let aiConsentKey = "user_ai_analysis_consent"
    private static let leaderboardConsentKey = "user_leaderboard_consent"

    // MARK: - AI Analysis Consent

    /// Whether the user has explicitly agreed to send health data to Google Gemini AI.
    /// Existing users (pre-consent-flow) default to opted-in since they were
    /// already using AI analysis before the consent screen was added.
    static var hasAIConsent: Bool {
        get {
            guard hasCompletedConsentFlow else { return true }
            return UserDefaults.standard.bool(forKey: aiConsentKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: aiConsentKey)
            syncToFirestore()
        }
    }

    // MARK: - Leaderboard Consent

    /// Whether the user has opted in to the global leaderboard.
    /// Existing users (pre-consent-flow) default to opted-in.
    static var hasLeaderboardConsent: Bool {
        get {
            guard hasCompletedConsentFlow else { return true }
            return UserDefaults.standard.bool(forKey: leaderboardConsentKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: leaderboardConsentKey)
            LeaderboardFirestoreSync.setLeaderboardOptIn(newValue) { _ in }
            syncToFirestore()
        }
    }

    // MARK: - Helpers

    /// Returns true if the user has completed the consent flow (regardless of choices).
    static var hasCompletedConsentFlow: Bool {
        // AI consent key being present (even if false) means the user went through the flow.
        // We use a separate key to distinguish "never asked" from "asked and declined".
        UserDefaults.standard.object(forKey: aiConsentKey) != nil
    }

    /// Saves consent state to Firestore (fire-and-forget).
    private static func syncToFirestore() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        db.collection("users").document(uid).updateData([
            "aiAnalysisConsent": hasAIConsent,
            "leaderboardOptIn": hasLeaderboardConsent
        ]) { error in
            if let error = error {
                print("[Consent] Firestore sync failed: \(error.localizedDescription)")
            }
        }
    }

    /// Resets all consent (for account deletion / logout).
    static func reset() {
        UserDefaults.standard.removeObject(forKey: aiConsentKey)
        UserDefaults.standard.removeObject(forKey: leaderboardConsentKey)
    }
}
