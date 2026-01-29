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

final class LoginViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let logoLabel = UILabel()
    private let subLabel = UILabel()
    private let emailField = UITextField()
    private let passwordField = UITextField()
    private let signInButton = UIButton(type: .system)
    private let dividerLeft = UIView()
    private let dividerRight = UIView()
    private let dividerLabel = UILabel()
    private let googleButton = UIButton(type: .system)
    private let signUpHint = UILabel()
    private var isSignUp = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = .forceRightToLeft
        setupUI()
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
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .onDrag
        scrollView.semanticContentAttribute = .forceRightToLeft
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = AIONDesign.spacingLarge
        stack.alignment = .fill
        stack.semanticContentAttribute = .forceRightToLeft
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        logoLabel.text = "AION"
        logoLabel.font = .systemFont(ofSize: 36, weight: .bold)
        logoLabel.textColor = AIONDesign.textPrimary
        logoLabel.textAlignment = .center
        subLabel.text = "התחבר כדי להמשיך"
        subLabel.font = .systemFont(ofSize: 17, weight: .regular)
        subLabel.textColor = AIONDesign.textSecondary
        subLabel.textAlignment = .center

        styleField(emailField, placeholder: "אימייל")
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
        styleField(passwordField, placeholder: "סיסמה")
        passwordField.isSecureTextEntry = true

        signInButton.setTitle("התחבר", for: .normal)
        signInButton.titleLabel?.font = AIONDesign.headlineFont()
        signInButton.backgroundColor = AIONDesign.accentPrimary
        signInButton.setTitleColor(.white, for: .normal)
        signInButton.layer.cornerRadius = AIONDesign.cornerRadius
        signInButton.translatesAutoresizingMaskIntoConstraints = false
        signInButton.addTarget(self, action: #selector(signInTapped), for: .touchUpInside)
        signInButton.heightAnchor.constraint(equalToConstant: 52).isActive = true

        [dividerLeft, dividerRight].forEach { d in
            d.backgroundColor = AIONDesign.separator
            d.translatesAutoresizingMaskIntoConstraints = false
            d.heightAnchor.constraint(equalToConstant: 1).isActive = true
        }
        dividerLabel.text = "או"
        dividerLabel.font = .systemFont(ofSize: 15, weight: .medium)
        dividerLabel.textColor = AIONDesign.textTertiary
        dividerLabel.textAlignment = .center
        dividerLabel.backgroundColor = AIONDesign.background

        googleButton.setTitle("  התחבר עם Google", for: .normal)
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
        googleButton.semanticContentAttribute = .forceRightToLeft

        signUpHint.text = "אין לך חשבון? הירשם"
        signUpHint.font = .systemFont(ofSize: 15, weight: .regular)
        signUpHint.textColor = AIONDesign.accentSecondary
        signUpHint.textAlignment = .center
        signUpHint.isUserInteractionEnabled = true
        signUpHint.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggleSignUp)))

        let header = UIStackView(arrangedSubviews: [logoLabel, subLabel])
        header.axis = .vertical
        header.spacing = 8
        header.alignment = .center

        let sectionEmail = UILabel()
        sectionEmail.text = "הכנס פרטים"
        sectionEmail.font = .systemFont(ofSize: 15, weight: .semibold)
        sectionEmail.textColor = AIONDesign.textSecondary
        sectionEmail.textAlignment = .right

        let sectionGoogle = UILabel()
        sectionGoogle.text = "או התחבר עם Google"
        sectionGoogle.font = .systemFont(ofSize: 15, weight: .semibold)
        sectionGoogle.textColor = AIONDesign.textSecondary
        sectionGoogle.textAlignment = .right

        let divRow = UIStackView()
        divRow.axis = .horizontal
        divRow.alignment = .center
        divRow.spacing = 12
        divRow.addArrangedSubview(dividerLeft)
        divRow.addArrangedSubview(dividerLabel)
        divRow.addArrangedSubview(dividerRight)
        dividerLeft.setContentHuggingPriority(.defaultLow, for: .horizontal)
        dividerRight.setContentHuggingPriority(.defaultLow, for: .horizontal)
        dividerLabel.setContentHuggingPriority(.required, for: .horizontal)

        stack.addArrangedSubview(header)
        stack.setCustomSpacing(32, after: header)
        stack.addArrangedSubview(sectionEmail)
        stack.addArrangedSubview(emailField)
        stack.addArrangedSubview(passwordField)
        stack.addArrangedSubview(signInButton)
        stack.addArrangedSubview(divRow)
        stack.addArrangedSubview(sectionGoogle)
        stack.addArrangedSubview(googleButton)
        stack.addArrangedSubview(signUpHint)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 48),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -48),
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
        field.textAlignment = .right
        field.semanticContentAttribute = .forceRightToLeft
        let pad: CGFloat = 16
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: pad, height: 1))
        field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: pad, height: 1))
        field.leftViewMode = .always
        field.rightViewMode = .always
    }

    @objc private func toggleSignUp() {
        isSignUp.toggle()
        signInButton.setTitle(isSignUp ? "הירשם" : "התחבר", for: .normal)
        signUpHint.text = isSignUp ? "יש לך חשבון? התחבר" : "אין לך חשבון? הירשם"
    }

    @objc private func signInTapped() {
        view.endEditing(true)
        guard let email = emailField.text?.trimmingCharacters(in: .whitespaces), !email.isEmpty,
              let password = passwordField.text, !password.isEmpty else {
            showAlert(title: "חסרים פרטים", message: "נא להזין אימייל וסיסמה.")
            return
        }
        signInButton.isEnabled = false
        if isSignUp {
            Auth.auth().createUser(withEmail: email, password: password) { [weak self] _, err in
                self?.handleEmailAuth(error: err)
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
            showAlert(title: "שגיאה", message: msg)
            return
        }
        proceedToApp()
    }

    @objc private func googleTapped() {
        view.endEditing(true)
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            showAlert(title: "שגיאה", message: "לא נמצא Client ID ל-Google. ודא ש-GoogleService-Info.plist מעודכן.")
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
                if let e = err { self?.showAlert(title: "שגיאה", message: (e as NSError).localizedDescription) }
                return
            }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            Auth.auth().signIn(with: credential) { _, err in
                if let e = err {
                    self?.showAlert(title: "שגיאה", message: (e as NSError).localizedDescription)
                    return
                }
                self?.proceedToApp()
            }
        }
    }

    private func proceedToApp() {
        guard let scene = view.window?.windowScene,
              let sd = scene.delegate as? SceneDelegate else { return }
        sd.window?.rootViewController = MainTabBarController()
        UIView.transition(with: sd.window!, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
    }

    private func showAlert(title: String, message: String) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "אישור", style: .default))
        present(ac, animated: true)
    }
}
