//
//  OnboardingManager.swift
//  Health Reporter
//
//  Manages Onboarding state - checks if should display and saves completion status
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

enum OnboardingManager {

    // MARK: - Keys

    private static let keyOnboardingCompleted = "AION.Onboarding.Completed"
    private static let keyOnboardingCompletedDate = "AION.Onboarding.CompletedDate"
    private static let keyOnboardingVersion = "AION.Onboarding.Version"
    private static let keyCurrentStep = "AION.Onboarding.CurrentStep"

    /// Current onboarding version - increment to re-show to all users
    static let currentOnboardingVersion = 1

    // MARK: - Public API

    /// Checks if onboarding should be shown to the user
    /// - Parameters:
    ///   - isSignUp: Whether the user is signing up (not logging in)
    ///   - additionalUserInfo: Additional info from Firebase (to check isNewUser in OAuth)
    /// - Returns: true if onboarding should be shown
    static func shouldShowOnboarding(isSignUp: Bool, additionalUserInfo: AdditionalUserInfo?) -> Bool {
        // If already completed onboarding in current version on this device - don't show
        if hasCompletedOnboarding() {
            return false
        }

        // Device has no local onboarding completion record.
        // This means either a new user or an existing user on a new device.
        // In both cases we need to show onboarding so the user grants
        // HealthKit / notification permissions on this device.
        return true
    }

    /// Checks if the user has already completed onboarding
    static func hasCompletedOnboarding() -> Bool {
        let completed = UserDefaults.standard.bool(forKey: keyOnboardingCompleted)
        let version = UserDefaults.standard.integer(forKey: keyOnboardingVersion)
        return completed && version >= currentOnboardingVersion
    }

    /// Marks the onboarding as completed
    static func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: keyOnboardingCompleted)
        UserDefaults.standard.set(Date(), forKey: keyOnboardingCompletedDate)
        UserDefaults.standard.set(currentOnboardingVersion, forKey: keyOnboardingVersion)

        // Also save to Firestore for cross-device sync
        saveToFirestore()

        // Clear current step
        clearCurrentStep()
    }

    // MARK: - Step Tracking (in case the app closes mid-onboarding)

    /// Saves the current onboarding step
    static func saveCurrentStep(_ step: Int) {
        UserDefaults.standard.set(step, forKey: keyCurrentStep)
    }

    /// Returns the last saved step (or 0 if none)
    static func getSavedStep() -> Int {
        return UserDefaults.standard.integer(forKey: keyCurrentStep)
    }

    /// Clears the saved step
    static func clearCurrentStep() {
        UserDefaults.standard.removeObject(forKey: keyCurrentStep)
    }

    // MARK: - Firestore Restore (for reinstall recovery)

    /// Checks Firestore for onboarding completion status.
    /// Used when UserDefaults is cleared (app reinstall) but Firebase Auth survives (Keychain).
    /// Has a 3-second timeout to avoid blocking if offline.
    static func checkFirestoreCompletion(completion: @escaping (Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }

        let db = Firestore.firestore()
        let doc = db.collection("users").document(uid)

        // Timeout after 3 seconds — if Firestore is unreachable, assume onboarding needed
        var didComplete = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            guard !didComplete else { return }
            didComplete = true
            print("⏰ [Onboarding] Firestore check timed out — assuming onboarding needed")
            completion(false)
        }

        doc.getDocument { snap, err in
            guard !didComplete else { return }
            didComplete = true

            if let data = snap?.data(),
               let completed = data["onboardingCompleted"] as? Bool,
               completed {
                // Existing user on new device — restore locally
                print("✅ [Onboarding] Restored from Firestore — onboarding already completed")
                markOnboardingComplete()
                completion(true)
            } else {
                print("ℹ️ [Onboarding] Firestore says onboarding not completed")
                completion(false)
            }
        }
    }

    // MARK: - Reset (for testing)

    /// Resets the Onboarding state (for testing)
    static func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: keyOnboardingCompleted)
        UserDefaults.standard.removeObject(forKey: keyOnboardingCompletedDate)
        UserDefaults.standard.removeObject(forKey: keyOnboardingVersion)
        UserDefaults.standard.removeObject(forKey: keyCurrentStep)
    }

    // MARK: - Private

    private static func saveToFirestore() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        db.collection("users").document(uid).setData([
            "onboardingCompleted": true,
            "onboardingCompletedDate": FieldValue.serverTimestamp(),
            "onboardingVersion": currentOnboardingVersion
        ], merge: true) { error in
            if let error = error {
                print("⚠️ [Onboarding] Failed to save to Firestore: \(error.localizedDescription)")
            } else {
                print("✅ [Onboarding] Saved completion to Firestore")
            }
        }
    }
}
