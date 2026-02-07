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
        // If already completed onboarding in current version - don't show
        if hasCompletedOnboarding() {
            return false
        }

        // Case 1: Email signup - isSignUp is true
        if isSignUp {
            return true
        }

        // Case 2: OAuth (Google/Apple) - check isNewUser
        if let additional = additionalUserInfo, additional.isNewUser {
            return true
        }

        // Case 3: Returning user logging in - don't show
        return false
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
