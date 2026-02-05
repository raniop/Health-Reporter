//
//  OnboardingPageViewController.swift
//  Health Reporter
//
//  Container ראשי ל-7 מסכי ה-Onboarding
//

import UIKit
import FirebaseAuth

protocol OnboardingPageDelegate: AnyObject {
    func onboardingDidComplete()
    func onboardingDidRequestNext()
    func onboardingDidRequestNotifications()
    func onboardingDidRequestHealthKit()
    func onboardingDidRequestCarReveal(carName: String, carEmoji: String, healthScore: Int, wikiName: String)
}

final class OnboardingPageViewController: UIViewController {

    // MARK: - Pages

    private lazy var pages: [UIViewController] = [
        WelcomeOnboardingPage(delegate: self),
        NotificationsOnboardingPage(delegate: self),
        HealthKitOnboardingPage(delegate: self),
        CarMetaphorOnboardingPage(delegate: self),
        HealthScoreOnboardingPage(delegate: self),
        AIInsightsOnboardingPage(delegate: self),
        AnalysisLoadingPage(delegate: self)
    ]

    private var currentPageIndex = 0

    // MARK: - UI

    private let containerView = UIView()

    private let pageControl: UIPageControl = {
        let pc = UIPageControl()
        pc.currentPageIndicatorTintColor = AIONDesign.accentPrimary
        pc.pageIndicatorTintColor = AIONDesign.textTertiary
        pc.translatesAutoresizingMaskIntoConstraints = false
        pc.isUserInteractionEnabled = false
        return pc
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        showPage(at: 0, animated: false)

        // בדיקה אם יש שלב שמור (האפליקציה נסגרה באמצע)
        let savedStep = OnboardingManager.getSavedStep()
        if savedStep > 0 && savedStep < pages.count {
            showPage(at: savedStep, animated: false)
        }
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = AIONDesign.background

        // Container for pages
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        // Page control
        pageControl.numberOfPages = pages.count
        view.addSubview(pageControl)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: pageControl.topAnchor, constant: -20),

            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    // MARK: - Navigation

    private func showPage(at index: Int, animated: Bool) {
        guard index >= 0 && index < pages.count else { return }

        let newVC = pages[index]
        let oldVC = children.first

        // Remove old
        oldVC?.willMove(toParent: nil)

        // Add new
        addChild(newVC)
        newVC.view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(newVC.view)

        NSLayoutConstraint.activate([
            newVC.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            newVC.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            newVC.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            newVC.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        if animated {
            let direction: CGFloat = index > currentPageIndex ? 1 : -1
            newVC.view.transform = CGAffineTransform(translationX: view.bounds.width * direction, y: 0)
            newVC.view.alpha = 0

            UIView.animate(withDuration: AIONDesign.animationMedium, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.5, options: [], animations: {
                newVC.view.transform = .identity
                newVC.view.alpha = 1
                oldVC?.view.transform = CGAffineTransform(translationX: -self.view.bounds.width * direction * 0.3, y: 0)
                oldVC?.view.alpha = 0
            }, completion: { _ in
                oldVC?.view.removeFromSuperview()
                oldVC?.removeFromParent()
                newVC.didMove(toParent: self)
            })
        } else {
            oldVC?.view.removeFromSuperview()
            oldVC?.removeFromParent()
            newVC.didMove(toParent: self)
        }

        currentPageIndex = index
        pageControl.currentPage = index

        // שמירת השלב הנוכחי
        OnboardingManager.saveCurrentStep(index)
    }

    private func goToNextPage() {
        let nextIndex = currentPageIndex + 1
        if nextIndex < pages.count {
            showPage(at: nextIndex, animated: true)
        }
    }

    private func completeOnboarding() {
        OnboardingManager.markOnboardingComplete()
        OnboardingCoordinator.shared.reset()

        // מעבר ל-MainTabBarController
        guard let window = view.window else { return }

        let mainVC = MainTabBarController()
        UIView.transition(with: window, duration: 0.4, options: .transitionCrossDissolve, animations: {
            window.rootViewController = mainVC
        }, completion: nil)
    }
}

// MARK: - OnboardingPageDelegate

extension OnboardingPageViewController: OnboardingPageDelegate {

    func onboardingDidComplete() {
        completeOnboarding()
    }

    func onboardingDidRequestNext() {
        goToNextPage()
    }

    func onboardingDidRequestNotifications() {
        // Request notifications and then go to next page
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                print("🔔 [Onboarding] Notifications permission: \(granted)")
                self?.goToNextPage()
            }
        }
    }

    func onboardingDidRequestHealthKit() {
        // Request HealthKit and start background analysis
        HealthKitManager.shared.requestAuthorization { [weak self] success, error in
            DispatchQueue.main.async {
                print("❤️ [Onboarding] HealthKit permission: \(success)")
                OnboardingCoordinator.shared.setHealthKitGranted(success)

                #if DEBUG
                // עבור Test User - מתחילים ניתוח גם אם HealthKit נכשל (יש נתונים מדומים)
                if DebugTestHelper.isTestUser(email: Auth.auth().currentUser?.email) {
                    print("🧪 [Onboarding] Test user - starting analysis regardless of HealthKit permission")
                    OnboardingCoordinator.shared.startBackgroundAnalysis()
                } else if success {
                    // התחל ניתוח ברקע
                    OnboardingCoordinator.shared.startBackgroundAnalysis()
                }
                #else
                if success {
                    // התחל ניתוח ברקע
                    OnboardingCoordinator.shared.startBackgroundAnalysis()
                }
                #endif

                self?.goToNextPage()
            }
        }
    }

    func onboardingDidRequestCarReveal(carName: String, carEmoji: String, healthScore: Int, wikiName: String) {
        // Create and show the car reveal page dynamically
        let carRevealPage = CarRevealOnboardingPage(
            delegate: self,
            carName: carName,
            carEmoji: carEmoji,
            healthScore: healthScore,
            wikiName: wikiName
        )

        // Add to pages array and show
        pages.append(carRevealPage)
        pageControl.numberOfPages = pages.count
        showPage(at: pages.count - 1, animated: true)
    }
}

// MARK: - Import for Notifications

import UserNotifications
