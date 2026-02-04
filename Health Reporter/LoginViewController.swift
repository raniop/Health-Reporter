//
//  LoginViewController.swift
//  Health Reporter
//
//  מסך התחברות: אימייל/סיסמה או התחברות עם Google. RTL, עיצוב AION.
//

import UIKit
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit

final class LoginViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let logoImageView = UIImageView()
    private let logoLabel = UILabel()
    private let subLabel = UILabel()
    private let nameField = UITextField()
    private let emailField = UITextField()
    private let passwordField = UITextField()
    private let signInButton = UIButton(type: .system)
    private let dividerView = UIView()
    private let googleButton = UIButton(type: .system)
    private let appleButton = ASAuthorizationAppleIDButton(type: .signIn, style: .white)
    private let signUpHint = UILabel()
    private let loadingOverlay = UIView()
    private let loadingSpinner = UIActivityIndicatorView(style: .large)
    private let loadingLabel = UILabel()
    private var isSignUp = false
    private var currentNonce: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        setupUI()
        setupLoadingOverlay()

        // Analytics: Log screen view
        AnalyticsService.shared.logScreenView(.login)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        updateGoogleButtonBorder()
    }

    private func updateGoogleButtonBorder() {
        googleButton.layer.borderColor = AIONDesign.separator.cgColor
    }

    private func setupUI() {
        let semantic = LocalizationManager.shared.semanticContentAttribute

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .onDrag
        scrollView.semanticContentAttribute = semantic
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = AIONDesign.spacingLarge
        stack.alignment = .fill
        stack.semanticContentAttribute = semantic
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        logoImageView.image = UIImage(named: "AIONLogoClear")
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false

        logoLabel.text = "AION"
        logoLabel.font = .systemFont(ofSize: 32, weight: .bold)
        logoLabel.textColor = AIONDesign.textPrimary
        logoLabel.textAlignment = .center

        subLabel.text = "login.title".localized
        subLabel.font = .systemFont(ofSize: 17, weight: .regular)
        subLabel.textColor = AIONDesign.textSecondary
        subLabel.textAlignment = .center

        styleField(nameField, placeholder: "login.fullName".localized)
        nameField.autocapitalizationType = .words
        nameField.isHidden = true
        styleField(emailField, placeholder: "login.email".localized)
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
        styleField(passwordField, placeholder: "login.password".localized)
        passwordField.isSecureTextEntry = true

        signInButton.setTitle("login.signIn".localized, for: .normal)
        signInButton.titleLabel?.font = AIONDesign.headlineFont()
        signInButton.backgroundColor = AIONDesign.accentPrimary
        signInButton.setTitleColor(.white, for: .normal)
        signInButton.layer.cornerRadius = AIONDesign.cornerRadius
        signInButton.translatesAutoresizingMaskIntoConstraints = false
        signInButton.addTarget(self, action: #selector(signInTapped), for: .touchUpInside)
        signInButton.heightAnchor.constraint(equalToConstant: 52).isActive = true

        dividerView.backgroundColor = AIONDesign.separator
        dividerView.translatesAutoresizingMaskIntoConstraints = false
        dividerView.heightAnchor.constraint(equalToConstant: 1).isActive = true

        googleButton.setTitle("  " + "login.signInWithGoogle".localized, for: .normal)
        googleButton.setImage(UIImage(systemName: "globe"), for: .normal)
        googleButton.titleLabel?.font = AIONDesign.headlineFont()
        googleButton.tintColor = AIONDesign.textPrimary
        googleButton.backgroundColor = AIONDesign.surface
        googleButton.layer.cornerRadius = AIONDesign.cornerRadius
        googleButton.layer.borderWidth = 1
        updateGoogleButtonBorder()
        googleButton.translatesAutoresizingMaskIntoConstraints = false
        googleButton.addTarget(self, action: #selector(googleTapped), for: .touchUpInside)
        googleButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        googleButton.semanticContentAttribute = semantic

        appleButton.translatesAutoresizingMaskIntoConstraints = false
        appleButton.layer.cornerRadius = AIONDesign.cornerRadius
        appleButton.clipsToBounds = true
        appleButton.addTarget(self, action: #selector(appleTapped), for: .touchUpInside)
        appleButton.heightAnchor.constraint(equalToConstant: 52).isActive = true

        signUpHint.text = "login.noAccount".localized
        signUpHint.font = .systemFont(ofSize: 15, weight: .regular)
        signUpHint.textColor = AIONDesign.accentSecondary
        signUpHint.textAlignment = .center
        signUpHint.isUserInteractionEnabled = true
        signUpHint.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggleSignUp)))

        let header = UIStackView(arrangedSubviews: [logoImageView, logoLabel, subLabel])
        header.axis = .vertical
        header.spacing = 8
        header.alignment = .center

        logoImageView.widthAnchor.constraint(equalToConstant: 100).isActive = true
        logoImageView.heightAnchor.constraint(equalToConstant: 100).isActive = true

        let textAlign = LocalizationManager.shared.textAlignment

        let sectionEmail = UILabel()
        sectionEmail.text = "login.enterDetails".localized
        sectionEmail.font = .systemFont(ofSize: 15, weight: .semibold)
        sectionEmail.textColor = AIONDesign.textSecondary
        sectionEmail.textAlignment = textAlign

        let sectionGoogle = UILabel()
        sectionGoogle.text = "login.orSignInWithGoogle".localized
        sectionGoogle.font = .systemFont(ofSize: 15, weight: .semibold)
        sectionGoogle.textColor = AIONDesign.textSecondary
        sectionGoogle.textAlignment = textAlign

        let sectionApple = UILabel()
        sectionApple.text = "login.orSignInWithApple".localized
        sectionApple.font = .systemFont(ofSize: 15, weight: .semibold)
        sectionApple.textColor = AIONDesign.textSecondary
        sectionApple.textAlignment = textAlign

        stack.addArrangedSubview(header)
        stack.setCustomSpacing(32, after: header)
        stack.addArrangedSubview(sectionEmail)
        stack.addArrangedSubview(nameField)
        stack.addArrangedSubview(emailField)
        stack.addArrangedSubview(passwordField)
        stack.addArrangedSubview(signInButton)
        stack.addArrangedSubview(dividerView)
        stack.addArrangedSubview(sectionGoogle)
        stack.addArrangedSubview(googleButton)
        stack.addArrangedSubview(sectionApple)
        stack.addArrangedSubview(appleButton)
        stack.addArrangedSubview(signUpHint)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 0),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -48),
            nameField.heightAnchor.constraint(equalToConstant: 50),
            emailField.heightAnchor.constraint(equalToConstant: 50),
            passwordField.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    private func styleField(_ field: UITextField, placeholder: String) {
        field.placeholder = placeholder
        field.font = .systemFont(ofSize: 16, weight: .regular)
        field.textColor = AIONDesign.textPrimary
        field.backgroundColor = AIONDesign.surface
        field.layer.cornerRadius = AIONDesign.cornerRadius
        field.borderStyle = .none
        field.translatesAutoresizingMaskIntoConstraints = false
        field.textAlignment = LocalizationManager.shared.textAlignment
        field.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        let pad: CGFloat = 16
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: pad, height: 1))
        field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: pad, height: 1))
        field.leftViewMode = .always
        field.rightViewMode = .always
    }

    @objc private func toggleSignUp() {
        isSignUp.toggle()
        signInButton.setTitle(isSignUp ? "login.signUp".localized : "login.signIn".localized, for: .normal)
        signUpHint.text = isSignUp ? "login.hasAccount".localized : "login.noAccount".localized
        nameField.isHidden = !isSignUp
        UIView.animate(withDuration: 0.25) {
            self.stack.layoutIfNeeded()
        }
    }

    @objc private func signInTapped() {
        view.endEditing(true)
        guard let email = emailField.text?.trimmingCharacters(in: .whitespaces), !email.isEmpty,
              let password = passwordField.text, !password.isEmpty else {
            showAlert(title: "missingDetails".localized, message: "login.enterEmailPassword".localized)
            return
        }
        if isSignUp {
            guard let name = nameField.text?.trimmingCharacters(in: .whitespaces), !name.isEmpty else {
                showAlert(title: "missingDetails".localized, message: "login.enterFullName".localized)
                return
            }
        }
        signInButton.isEnabled = false
        if isSignUp {
            Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, err in
                guard let self = self else { return }
                if let e = err {
                    self.signInButton.isEnabled = true
                    self.showAlert(title: "error".localized, message: (e as NSError).localizedDescription)
                    return
                }
                let displayName = self.nameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
                let changeRequest = result?.user.createProfileChangeRequest()
                changeRequest?.displayName = displayName
                changeRequest?.commitChanges { _ in
                    // שמירת השם גם ב-Firestore לצורך חיפוש
                    if !displayName.isEmpty {
                        ProfileFirestoreSync.saveDisplayName(displayName)
                    }
                    self.proceedToApp()
                }
            }
        } else {
            Auth.auth().signIn(withEmail: email, password: password) { [weak self] _, err in
                self?.handleEmailAuth(error: err)
            }
        }
    }

    private func handleEmailAuth(error: Error?) {
        signInButton.isEnabled = true
        if let e = error {
            let msg = (e as NSError).localizedDescription
            showAlert(title: "error".localized, message: msg)
            return
        }
        proceedToApp()
    }

    @objc private func googleTapped() {
        view.endEditing(true)
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            showAlert(title: "error".localized, message: "login.googleClientIdError".localized)
            return
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        googleButton.isEnabled = false
        GIDSignIn.sharedInstance.signIn(withPresenting: self) { [weak self] result, err in
            self?.googleButton.isEnabled = true
            guard err == nil,
                  let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                if let e = err { self?.showAlert(title: "error".localized, message: (e as NSError).localizedDescription) }
                return
            }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            Auth.auth().signIn(with: credential) { [weak self] authResult, err in
                if let e = err {
                    self?.showAlert(title: "error".localized, message: (e as NSError).localizedDescription)
                    return
                }
                // Analytics: Log Google login
                if let userId = Auth.auth().currentUser?.uid {
                    AnalyticsService.shared.setUserId(userId)
                    AnalyticsService.shared.logLogin(method: "google")
                }
                self?.proceedToApp(authResult: authResult)
            }
        }
    }

    private func proceedToApp(authResult: AuthDataResult? = nil) {
        showLoading()
        // סנכרון שם המשתמש ל-Firestore (לצורך חיפוש)
        syncUserDisplayNameToFirestore()

        // Analytics: Log successful login/signup and set user ID
        if let userId = Auth.auth().currentUser?.uid {
            AnalyticsService.shared.setUserId(userId)
            if isSignUp {
                AnalyticsService.shared.logSignUp(method: "email")
            } else {
                AnalyticsService.shared.logLogin(method: "email")
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self,
                  let scene = self.view.window?.windowScene,
                  let sd = scene.delegate as? SceneDelegate else { return }

            // בדיקה אם להציג Onboarding
            let additionalUserInfo = authResult?.additionalUserInfo
            if OnboardingManager.shouldShowOnboarding(isSignUp: self.isSignUp, additionalUserInfo: additionalUserInfo) {
                // משתמש חדש - הצג Onboarding
                let onboardingVC = OnboardingPageViewController()
                sd.window?.rootViewController = onboardingVC
            } else {
                // משתמש קיים - ישר לאפליקציה
                sd.window?.rootViewController = MainTabBarController()
            }
            UIView.transition(with: sd.window!, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
        }
    }

    /// מסנכרן את שם המשתמש מ-Firebase Auth ל-Firestore (כדי שניתן יהיה לחפש אותו).
    private func syncUserDisplayNameToFirestore() {
        guard let displayName = Auth.auth().currentUser?.displayName, !displayName.isEmpty else { return }
        ProfileFirestoreSync.saveDisplayName(displayName)
    }

    private func showAlert(title: String, message: String) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "ok".localized, style: .default))
        present(ac, animated: true)
    }

    // MARK: - Loading Overlay

    private func setupLoadingOverlay() {
        loadingOverlay.backgroundColor = AIONDesign.background.withAlphaComponent(0.95)
        loadingOverlay.isHidden = true
        loadingOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingOverlay)

        loadingSpinner.color = AIONDesign.accentPrimary
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.addSubview(loadingSpinner)

        loadingLabel.text = "login.connecting".localized
        loadingLabel.font = .systemFont(ofSize: 17, weight: .medium)
        loadingLabel.textColor = AIONDesign.textPrimary
        loadingLabel.textAlignment = .center
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.addSubview(loadingLabel)

        NSLayoutConstraint.activate([
            loadingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            loadingSpinner.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: loadingOverlay.centerYAnchor, constant: -20),
            loadingLabel.topAnchor.constraint(equalTo: loadingSpinner.bottomAnchor, constant: 16),
            loadingLabel.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
        ])
    }

    private func showLoading() {
        loadingOverlay.isHidden = false
        loadingSpinner.startAnimating()
    }

    private func hideLoading() {
        loadingOverlay.isHidden = true
        loadingSpinner.stopAnimating()
    }

    // MARK: - Apple Sign-In

    @objc private func appleTapped() {
        let nonce = randomNonceString()
        currentNonce = nonce
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension LoginViewController: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            showAlert(title: "error".localized, message: "login.appleError".localized)
            return
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            if let e = error {
                self?.showAlert(title: "error".localized, message: (e as NSError).localizedDescription)
                return
            }
            // Analytics: Log Apple login
            if let userId = Auth.auth().currentUser?.uid {
                AnalyticsService.shared.setUserId(userId)
                AnalyticsService.shared.logLogin(method: "apple")
            }
            self?.proceedToApp(authResult: authResult)
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if (error as NSError).code == ASAuthorizationError.canceled.rawValue { return }
        showAlert(title: "error".localized, message: (error as NSError).localizedDescription)
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension LoginViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return view.window!
    }
}
