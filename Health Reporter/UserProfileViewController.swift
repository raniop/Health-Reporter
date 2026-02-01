//
//  UserProfileViewController.swift
//  Health Reporter
//
//  תצוגת פרופיל של משתמש אחר - עיצוב מודרני WOW
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

final class UserProfileViewController: UIViewController {

    // MARK: - Properties

    private let userUid: String
    private var userData: (displayName: String, photoURL: String?, healthScore: Int, carTierIndex: Int, carTierName: String)?
    private var friendshipStatus: FriendshipStatus = .unknown

    private enum FriendshipStatus {
        case unknown
        case notFriends
        case friends
        case requestSentByMe
        case requestSentToMe(requestId: String)
    }

    // MARK: - UI Elements

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)

    // Header with gradient background
    private let headerView = UIView()
    private let headerGradient = CAGradientLayer()
    private let topGradientView = UIView()
    private let topGradientLayer = CAGradientLayer()

    // Avatar with animated ring
    private let avatarContainer = UIView()
    private let avatarRingView = AvatarRingView(size: 120)
    private let onlineIndicator = PulsingStatusIndicator(size: 20)

    // Name and info
    private let nameLabel = UILabel()
    private let usernameLabel = UILabel()

    // Stats cards
    private let statsContainer = UIStackView()
    private let healthScoreCard = ProfileStatCard()
    private let carTierCard = ProfileStatCard()

    // Action buttons
    private let primaryButton = GradientButton()
    private let secondaryButton = UIButton(type: .system)
    private let buttonStack = UIStackView()

    // Bio/About section (placeholder for future)
    private let aboutCard = GlassMorphismView()
    private let aboutTitleLabel = UILabel()
    private let aboutTextLabel = UILabel()

    // MARK: - Init

    init(userUid: String) {
        self.userUid = userUid
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute

        setupNavigationBar()
        setupUI()
        loadUserData()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        topGradientLayer.frame = topGradientView.bounds
    }

    // MARK: - Navigation Bar

    private func setupNavigationBar() {
        title = ""
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.isTranslucent = true

        // Custom back button
        let backButton = UIButton(type: .system)
        backButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)), for: .normal)
        backButton.tintColor = AIONDesign.textPrimary
        backButton.backgroundColor = AIONDesign.surface.withAlphaComponent(0.8)
        backButton.layer.cornerRadius = 20
        backButton.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backButton)
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    // MARK: - Setup UI

    private func setupUI() {
        // Top gradient that covers safe area (stays fixed, behind scroll content)
        topGradientView.translatesAutoresizingMaskIntoConstraints = false
        topGradientView.isUserInteractionEnabled = false
        view.addSubview(topGradientView)

        topGradientLayer.colors = [
            AIONDesign.accentPrimary.withAlphaComponent(0.4).cgColor,
            AIONDesign.accentSecondary.withAlphaComponent(0.25).cgColor,
            AIONDesign.background.cgColor
        ]
        topGradientLayer.locations = [0, 0.4, 1]
        topGradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        topGradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        topGradientView.layer.insertSublayer(topGradientLayer, at: 0)

        // Loading indicator
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.color = AIONDesign.accentPrimary
        view.addSubview(loadingIndicator)

        // Scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.isHidden = true
        scrollView.backgroundColor = .clear
        view.addSubview(scrollView)

        // Content view
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .clear
        scrollView.addSubview(contentView)

        setupHeader()
        setupAvatar()
        setupNameSection()
        setupStatsCards()
        setupAboutSection()
        setupActionButtons()

        // Constraints
        NSLayoutConstraint.activate([
            // Top gradient covers safe area and extends down
            topGradientView.topAnchor.constraint(equalTo: view.topAnchor),
            topGradientView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topGradientView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topGradientView.heightAnchor.constraint(equalToConstant: 280),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    private func setupHeader() {
        // Header is now handled by topGradientView which stays fixed at top
        // This method is kept for organizational purposes
    }

    private func setupAvatar() {
        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(avatarContainer)

        avatarRingView.translatesAutoresizingMaskIntoConstraints = false
        avatarRingView.ringColors = [AIONDesign.accentPrimary, AIONDesign.accentSecondary, AIONDesign.accentSuccess]
        avatarRingView.ringWidth = 4
        avatarRingView.isAnimated = true
        avatarContainer.addSubview(avatarRingView)

        // Online indicator
        onlineIndicator.translatesAutoresizingMaskIntoConstraints = false
        onlineIndicator.isOnline = true
        onlineIndicator.statusColor = AIONDesign.accentSuccess
        avatarContainer.addSubview(onlineIndicator)

        // Shadow effect
        avatarContainer.layer.shadowColor = AIONDesign.accentPrimary.cgColor
        avatarContainer.layer.shadowOffset = .zero
        avatarContainer.layer.shadowRadius = 20
        avatarContainer.layer.shadowOpacity = 0.3

        NSLayoutConstraint.activate([
            avatarContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            avatarContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 120),
            avatarContainer.widthAnchor.constraint(equalToConstant: 130),
            avatarContainer.heightAnchor.constraint(equalToConstant: 130),

            avatarRingView.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatarRingView.centerYAnchor.constraint(equalTo: avatarContainer.centerYAnchor),
            avatarRingView.widthAnchor.constraint(equalToConstant: 120),
            avatarRingView.heightAnchor.constraint(equalToConstant: 120),

            onlineIndicator.trailingAnchor.constraint(equalTo: avatarRingView.trailingAnchor, constant: -8),
            onlineIndicator.bottomAnchor.constraint(equalTo: avatarRingView.bottomAnchor, constant: -8),
            onlineIndicator.widthAnchor.constraint(equalToConstant: 20),
            onlineIndicator.heightAnchor.constraint(equalToConstant: 20),
        ])
    }

    private func setupNameSection() {
        nameLabel.font = .systemFont(ofSize: 28, weight: .bold)
        nameLabel.textColor = AIONDesign.textPrimary
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        usernameLabel.font = .systemFont(ofSize: 16, weight: .medium)
        usernameLabel.textColor = AIONDesign.textSecondary
        usernameLabel.textAlignment = .center
        usernameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(usernameLabel)

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: avatarContainer.bottomAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            usernameLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            usernameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            usernameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
        ])
    }

    private func setupStatsCards() {
        statsContainer.axis = .horizontal
        statsContainer.distribution = .fillEqually
        statsContainer.spacing = 12
        statsContainer.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        statsContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statsContainer)

        healthScoreCard.translatesAutoresizingMaskIntoConstraints = false
        carTierCard.translatesAutoresizingMaskIntoConstraints = false

        statsContainer.addArrangedSubview(healthScoreCard)
        statsContainer.addArrangedSubview(carTierCard)

        NSLayoutConstraint.activate([
            statsContainer.topAnchor.constraint(equalTo: usernameLabel.bottomAnchor, constant: 24),
            statsContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            statsContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            statsContainer.heightAnchor.constraint(equalToConstant: 100),
        ])
    }

    private func setupAboutSection() {
        aboutCard.translatesAutoresizingMaskIntoConstraints = false
        aboutCard.cornerRadius = AIONDesign.cornerRadiusLarge
        aboutCard.glassTintColor = AIONDesign.accentSecondary
        aboutCard.borderColors = [AIONDesign.accentPrimary.withAlphaComponent(0.3), AIONDesign.accentSecondary.withAlphaComponent(0.3)]
        aboutCard.clipsToBounds = true // Ensure content doesn't overflow
        contentView.addSubview(aboutCard)

        aboutTitleLabel.text = "social.about".localized
        aboutTitleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        aboutTitleLabel.textColor = AIONDesign.textPrimary
        aboutTitleLabel.textAlignment = LocalizationManager.shared.textAlignment
        aboutTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        aboutCard.addSubview(aboutTitleLabel)

        aboutTextLabel.text = "social.activeUser".localized
        aboutTextLabel.font = .systemFont(ofSize: 14, weight: .regular)
        aboutTextLabel.textColor = AIONDesign.textSecondary
        aboutTextLabel.textAlignment = LocalizationManager.shared.textAlignment
        aboutTextLabel.numberOfLines = 0
        aboutTextLabel.translatesAutoresizingMaskIntoConstraints = false
        aboutCard.addSubview(aboutTextLabel)

        NSLayoutConstraint.activate([
            aboutCard.topAnchor.constraint(equalTo: statsContainer.bottomAnchor, constant: 20),
            aboutCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            aboutCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            aboutTitleLabel.topAnchor.constraint(equalTo: aboutCard.topAnchor, constant: 16),
            aboutTitleLabel.leadingAnchor.constraint(equalTo: aboutCard.leadingAnchor, constant: 16),
            aboutTitleLabel.trailingAnchor.constraint(equalTo: aboutCard.trailingAnchor, constant: -16),

            aboutTextLabel.topAnchor.constraint(equalTo: aboutTitleLabel.bottomAnchor, constant: 8),
            aboutTextLabel.leadingAnchor.constraint(equalTo: aboutCard.leadingAnchor, constant: 16),
            aboutTextLabel.trailingAnchor.constraint(equalTo: aboutCard.trailingAnchor, constant: -16),
            aboutTextLabel.bottomAnchor.constraint(equalTo: aboutCard.bottomAnchor, constant: -16),
        ])
    }

    private func setupActionButtons() {
        buttonStack.axis = .vertical
        buttonStack.spacing = 12
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(buttonStack)

        primaryButton.translatesAutoresizingMaskIntoConstraints = false
        primaryButton.setTitle("social.sendRequest".localized, for: .normal)
        primaryButton.addTarget(self, action: #selector(primaryButtonTapped), for: .touchUpInside)

        secondaryButton.translatesAutoresizingMaskIntoConstraints = false
        secondaryButton.setTitle("social.decline".localized, for: .normal)
        secondaryButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        secondaryButton.setTitleColor(AIONDesign.textSecondary, for: .normal)
        secondaryButton.backgroundColor = AIONDesign.surface
        secondaryButton.layer.cornerRadius = AIONDesign.cornerRadius
        secondaryButton.layer.borderWidth = 1
        secondaryButton.layer.borderColor = AIONDesign.separator.cgColor
        secondaryButton.isHidden = true
        secondaryButton.addTarget(self, action: #selector(secondaryButtonTapped), for: .touchUpInside)

        buttonStack.addArrangedSubview(primaryButton)
        buttonStack.addArrangedSubview(secondaryButton)

        NSLayoutConstraint.activate([
            buttonStack.topAnchor.constraint(equalTo: aboutCard.bottomAnchor, constant: 24),
            buttonStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),

            primaryButton.heightAnchor.constraint(equalToConstant: 54),
            secondaryButton.heightAnchor.constraint(equalToConstant: 54),
        ])
    }

    // MARK: - Load Data

    private func loadUserData() {
        loadingIndicator.startAnimating()

        let db = Firestore.firestore()

        // Fetch from publicScores
        db.collection("publicScores").document(userUid).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }

            if let data = snapshot?.data(),
               let displayName = data["displayName"] as? String,
               let healthScore = data["healthScore"] as? Int,
               let carTierIndex = data["carTierIndex"] as? Int,
               let carTierName = data["carTierName"] as? String {

                self.userData = (
                    displayName: displayName,
                    photoURL: data["photoURL"] as? String,
                    healthScore: healthScore,
                    carTierIndex: carTierIndex,
                    carTierName: carTierName
                )
            }

            // Check friendship status
            self.checkFriendshipStatus {
                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimating()
                    self.scrollView.isHidden = false
                    self.updateUI()
                    self.animateEntrance()
                }
            }
        }
    }

    private func checkFriendshipStatus(completion: @escaping () -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            friendshipStatus = .unknown
            completion()
            return
        }

        let db = Firestore.firestore()

        // Check if already friends
        db.collection("users").document(currentUid)
            .collection("friends").document(userUid)
            .getDocument { [weak self] snapshot, _ in
                guard let self = self else { return }

                if snapshot?.exists == true {
                    self.friendshipStatus = .friends
                    completion()
                    return
                }

                // Check for pending requests
                self.checkPendingRequests(currentUid: currentUid, completion: completion)
            }
    }

    private func checkPendingRequests(currentUid: String, completion: @escaping () -> Void) {
        let db = Firestore.firestore()

        // Check if I sent a request to them
        db.collection("friendRequests")
            .whereField("fromUid", isEqualTo: currentUid)
            .whereField("toUid", isEqualTo: userUid)
            .whereField("status", isEqualTo: "pending")
            .getDocuments { [weak self] snapshot, _ in
                guard let self = self else { return }

                if snapshot?.documents.first != nil {
                    self.friendshipStatus = .requestSentByMe
                    completion()
                    return
                }

                // Check if they sent a request to me
                db.collection("friendRequests")
                    .whereField("fromUid", isEqualTo: self.userUid)
                    .whereField("toUid", isEqualTo: currentUid)
                    .whereField("status", isEqualTo: "pending")
                    .getDocuments { [weak self] snapshot, _ in
                        guard let self = self else { return }

                        if let doc = snapshot?.documents.first {
                            self.friendshipStatus = .requestSentToMe(requestId: doc.documentID)
                        } else {
                            self.friendshipStatus = .notFriends
                        }
                        completion()
                    }
            }
    }

    // MARK: - Update UI

    private func updateUI() {
        guard let data = userData else {
            nameLabel.text = "social.unknownUser".localized
            aboutCard.isHidden = true
            statsContainer.isHidden = true
            primaryButton.isHidden = true
            return
        }

        // Name
        nameLabel.text = data.displayName

        // Set navigation title to user's name
        title = data.displayName

        // Avatar
        avatarRingView.loadImage(from: data.photoURL)

        // Car tier info
        let tier = CarTierEngine.tiers[safe: data.carTierIndex]
        usernameLabel.text = "\(tier?.emoji ?? "") \(data.carTierName)"

        // Update ring colors based on tier
        if let tier = tier {
            avatarRingView.ringColors = [tier.color, tier.color.withAlphaComponent(0.6), AIONDesign.accentSecondary]
        }

        // Stats cards
        healthScoreCard.configure(
            icon: "heart.fill",
            iconColor: AIONDesign.accentDanger,
            value: "\(data.healthScore)",
            label: "social.healthScore".localized
        )

        carTierCard.configure(
            icon: "car.fill",
            iconColor: tier?.color ?? AIONDesign.accentPrimary,
            value: tier?.emoji ?? "🚗",
            label: data.carTierName
        )

        // About text based on score
        updateAboutText(healthScore: data.healthScore, carTierName: data.carTierName)

        // Update buttons based on friendship status
        updateActionButtons()
    }

    private func updateAboutText(healthScore: Int, carTierName: String) {
        var text = ""
        if healthScore >= 80 {
            text = "social.aboutExcellent".localized
        } else if healthScore >= 60 {
            text = "social.aboutGood".localized
        } else if healthScore >= 40 {
            text = "social.aboutProgress".localized
        } else {
            text = "social.aboutStarting".localized
        }
        aboutTextLabel.text = text
    }

    private func updateActionButtons() {
        switch friendshipStatus {
        case .unknown:
            primaryButton.isHidden = true
            secondaryButton.isHidden = true

        case .notFriends:
            primaryButton.isHidden = false
            primaryButton.setTitle("social.sendFriendRequest".localized, for: .normal)
            primaryButton.gradientColors = [AIONDesign.accentPrimary, AIONDesign.accentSecondary]
            primaryButton.isEnabled = true
            secondaryButton.isHidden = true

        case .friends:
            primaryButton.isHidden = false
            primaryButton.setTitle("social.removeFriend".localized, for: .normal)
            primaryButton.gradientColors = [AIONDesign.accentDanger, AIONDesign.accentDanger.withAlphaComponent(0.8)]
            primaryButton.isEnabled = true
            secondaryButton.isHidden = true

        case .requestSentByMe:
            primaryButton.isHidden = false
            primaryButton.setTitle("social.requestSent".localized, for: .normal)
            primaryButton.gradientColors = [AIONDesign.textTertiary, AIONDesign.textTertiary.withAlphaComponent(0.8)]
            primaryButton.isEnabled = false
            secondaryButton.isHidden = true

        case .requestSentToMe:
            primaryButton.isHidden = false
            primaryButton.setTitle("social.acceptRequest".localized, for: .normal)
            primaryButton.gradientColors = [AIONDesign.accentSuccess, AIONDesign.accentSecondary]
            primaryButton.isEnabled = true

            secondaryButton.isHidden = false
            secondaryButton.setTitle("social.declineRequest".localized, for: .normal)
            secondaryButton.setTitleColor(AIONDesign.accentDanger, for: .normal)
            secondaryButton.layer.borderColor = AIONDesign.accentDanger.cgColor
        }
    }

    // MARK: - Animations

    private func animateEntrance() {
        // Prepare elements
        avatarContainer.alpha = 0
        avatarContainer.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        nameLabel.alpha = 0
        nameLabel.transform = CGAffineTransform(translationX: 0, y: 20)
        usernameLabel.alpha = 0
        statsContainer.alpha = 0
        statsContainer.transform = CGAffineTransform(translationX: 0, y: 30)
        aboutCard.alpha = 0
        buttonStack.alpha = 0
        buttonStack.transform = CGAffineTransform(translationX: 0, y: 30)

        // Animate avatar
        UIView.animate(
            withDuration: 0.6,
            delay: 0,
            usingSpringWithDamping: 0.6,
            initialSpringVelocity: 0.5
        ) {
            self.avatarContainer.alpha = 1
            self.avatarContainer.transform = .identity
        }

        // Animate name
        UIView.animate(
            withDuration: 0.5,
            delay: 0.15,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.5
        ) {
            self.nameLabel.alpha = 1
            self.nameLabel.transform = .identity
        }

        // Animate username
        UIView.animate(withDuration: 0.4, delay: 0.25) {
            self.usernameLabel.alpha = 1
        }

        // Animate stats
        UIView.animate(
            withDuration: 0.5,
            delay: 0.3,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.5
        ) {
            self.statsContainer.alpha = 1
            self.statsContainer.transform = .identity
        }

        // Animate about
        UIView.animate(withDuration: 0.4, delay: 0.4) {
            self.aboutCard.alpha = 1
        }

        // Animate buttons
        UIView.animate(
            withDuration: 0.5,
            delay: 0.5,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.5
        ) {
            self.buttonStack.alpha = 1
            self.buttonStack.transform = .identity
        }
    }

    // MARK: - Actions

    @objc private func primaryButtonTapped() {
        primaryButton.springAnimation { [weak self] in
            self?.handlePrimaryAction()
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func handlePrimaryAction() {
        switch friendshipStatus {
        case .notFriends:
            sendFriendRequest()

        case .friends:
            confirmRemoveFriend()

        case .requestSentToMe(let requestId):
            acceptFriendRequest(requestId: requestId)

        default:
            break
        }
    }

    @objc private func secondaryButtonTapped() {
        secondaryButton.springAnimation(scale: 0.95)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        if case .requestSentToMe(let requestId) = friendshipStatus {
            declineFriendRequest(requestId: requestId)
        }
    }

    private func sendFriendRequest() {
        setLoading(true)

        FriendsFirestoreSync.sendFriendRequest(toUid: userUid) { [weak self] error in
            self?.setLoading(false)

            if let error = error {
                self?.showError(error.localizedDescription)
            } else {
                self?.friendshipStatus = .requestSentByMe
                self?.updateActionButtons()
                self?.showSuccessFeedback()
            }
        }
    }

    private func confirmRemoveFriend() {
        let alert = UIAlertController(
            title: "social.removeFriend".localized,
            message: String(format: "social.removeFriendConfirm".localized, userData?.displayName ?? ""),
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "general.cancel".localized, style: .cancel))
        alert.addAction(UIAlertAction(title: "social.remove".localized, style: .destructive) { [weak self] _ in
            self?.removeFriend()
        })

        present(alert, animated: true)
    }

    private func removeFriend() {
        setLoading(true)

        FriendsFirestoreSync.removeFriend(friendUid: userUid) { [weak self] error in
            self?.setLoading(false)

            if let error = error {
                self?.showError(error.localizedDescription)
            } else {
                self?.friendshipStatus = .notFriends
                self?.updateActionButtons()
            }
        }
    }

    private func acceptFriendRequest(requestId: String) {
        setLoading(true)

        FriendsFirestoreSync.acceptFriendRequest(requestId: requestId) { [weak self] error in
            self?.setLoading(false)

            if let error = error {
                self?.showError(error.localizedDescription)
            } else {
                self?.friendshipStatus = .friends
                self?.updateActionButtons()
                self?.showSuccessFeedback()
                self?.notifyTabBarToUpdateBadge()
            }
        }
    }

    private func declineFriendRequest(requestId: String) {
        setLoading(true)

        FriendsFirestoreSync.declineFriendRequest(requestId: requestId) { [weak self] error in
            self?.setLoading(false)

            if let error = error {
                self?.showError(error.localizedDescription)
            } else {
                self?.friendshipStatus = .notFriends
                self?.updateActionButtons()
                self?.notifyTabBarToUpdateBadge()
            }
        }
    }

    // MARK: - Helpers

    private func setLoading(_ loading: Bool) {
        primaryButton.isEnabled = !loading
        secondaryButton.isEnabled = !loading
        primaryButton.alpha = loading ? 0.6 : 1.0
        secondaryButton.alpha = loading ? 0.6 : 1.0
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "general.error".localized, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "general.ok".localized, style: .default))
        present(alert, animated: true)
    }

    private func showSuccessFeedback() {
        // Haptic
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Pulse animation on avatar
        avatarContainer.pulseAnimation(scale: 1.1, duration: 0.2)
    }

    private func notifyTabBarToUpdateBadge() {
        if let tabBar = tabBarController as? MainTabBarController {
            tabBar.updateSocialTabBadge()
        }
    }
}

// MARK: - ProfileStatCard

private final class ProfileStatCard: GlassMorphismView {

    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = AIONDesign.textPrimary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = AIONDesign.textSecondary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        cornerRadius = AIONDesign.cornerRadiusLarge
        glassTintColor = AIONDesign.accentPrimary

        addSubview(iconView)
        addSubview(valueLabel)
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            valueLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            titleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12),
        ])
    }

    func configure(icon: String, iconColor: UIColor, value: String, label: String) {
        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = iconColor
        valueLabel.text = value
        titleLabel.text = label
    }
}

// MARK: - Array Safe Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
