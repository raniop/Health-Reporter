//
//  OnboardingManager.swift
//  Health Reporter
//
//  מנהל מצב ה-Onboarding - בודק אם להציג ושומר סטטוס סיום
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

    /// גרסת ה-onboarding הנוכחית - הגדל כדי להציג מחדש לכל המשתמשים
    static let currentOnboardingVersion = 1

    // MARK: - Public API

    /// בודק אם צריך להציג onboarding למשתמש
    /// - Parameters:
    ///   - isSignUp: האם המשתמש עושה הרשמה (לא התחברות)
    ///   - additionalUserInfo: מידע נוסף מ-Firebase (לבדיקת isNewUser ב-OAuth)
    /// - Returns: true אם צריך להציג onboarding
    static func shouldShowOnboarding(isSignUp: Bool, additionalUserInfo: AdditionalUserInfo?) -> Bool {
        // אם כבר השלים onboarding בגרסה הנוכחית - לא מציגים
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

        // Case 3: Returning user logging in - לא מציגים
        return false
    }

    /// בודק אם המשתמש כבר סיים onboarding
    static func hasCompletedOnboarding() -> Bool {
        let completed = UserDefaults.standard.bool(forKey: keyOnboardingCompleted)
        let version = UserDefaults.standard.integer(forKey: keyOnboardingVersion)
        return completed && version >= currentOnboardingVersion
    }

    /// מסמן שה-onboarding הושלם
    static func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: keyOnboardingCompleted)
        UserDefaults.standard.set(Date(), forKey: keyOnboardingCompletedDate)
        UserDefaults.standard.set(currentOnboardingVersion, forKey: keyOnboardingVersion)

        // גם שומר ב-Firestore לסנכרון בין מכשירים
        saveToFirestore()

        // מנקה את השלב הנוכחי
        clearCurrentStep()
    }

    // MARK: - Step Tracking (למקרה שהאפליקציה נסגרת באמצע)

    /// שומר את השלב הנוכחי ב-Onboarding
    static func saveCurrentStep(_ step: Int) {
        UserDefaults.standard.set(step, forKey: keyCurrentStep)
    }

    /// מחזיר את השלב האחרון שנשמר (או 0 אם אין)
    static func getSavedStep() -> Int {
        return UserDefaults.standard.integer(forKey: keyCurrentStep)
    }

    /// מנקה את השלב השמור
    static func clearCurrentStep() {
        UserDefaults.standard.removeObject(forKey: keyCurrentStep)
    }

    // MARK: - Reset (for testing)

    /// מאפס את מצב ה-Onboarding (לצורך בדיקות)
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
