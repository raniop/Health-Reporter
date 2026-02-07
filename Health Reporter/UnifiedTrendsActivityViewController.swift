//
//  UnifiedTrendsActivityViewController.swift
//  Health Reporter
//
//  Combined activity + trends screen with Segment Control switching.
//

import UIKit

final class UnifiedTrendsActivityViewController: UIViewController {

    // MARK: - Constants

    private let lastSegmentKey = "UnifiedTrendsActivityLastSegment"

    // MARK: - UI Elements

    private let segmentedControl: UISegmentedControl = {
        let items = [
            "unified.summary".localized,
            "unified.activity".localized,
            "unified.trends".localized
        ]
        let sc = UISegmentedControl(items: items)
        sc.selectedSegmentIndex = 0
        sc.selectedSegmentTintColor = AIONDesign.surfaceElevated
        sc.setTitleTextAttributes([.foregroundColor: AIONDesign.textPrimary], for: .selected)
        sc.setTitleTextAttributes([.foregroundColor: AIONDesign.textTertiary], for: .normal)
        sc.backgroundColor = AIONDesign.surface
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()

    private let containerView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - Children (lazy)

    /// Summary screen (the old main dashboard) – first category in Performance
    private lazy var summaryVC: HealthDashboardViewController = {
        let vc = HealthDashboardViewController()
        return vc
    }()

    private lazy var activityVC: ActivityViewController = {
        let vc = ActivityViewController()
        return vc
    }()

    private lazy var trendsVC: TrendsViewController = {
        let vc = TrendsViewController()
        return vc
    }()

    // MARK: - State

    private var currentSegment: Int = 0

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "unified.title".localized
        view.backgroundColor = AIONDesign.background
        view.semanticContentAttribute = LocalizationManager.shared.semanticContentAttribute
        setupUI()
        restoreLastSegment()
        setupInitialChild()

        // Listen for background color changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(backgroundColorDidChange),
            name: .backgroundColorChanged,
            object: nil
        )

        // Analytics: Log screen view
        AnalyticsService.shared.logScreenView(.trends)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func backgroundColorDidChange() {
        view.backgroundColor = AIONDesign.background
        segmentedControl.backgroundColor = AIONDesign.surface
        segmentedControl.selectedSegmentTintColor = AIONDesign.surfaceElevated
        navigationController?.navigationBar.barStyle = AIONDesign.navBarStyle
        navigationController?.navigationBar.barTintColor = AIONDesign.background
        navigationController?.navigationBar.backgroundColor = AIONDesign.background
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: AIONDesign.textPrimary]
    }

    // MARK: - Setup

    private func setupUI() {
        view.addSubview(segmentedControl)
        view.addSubview(containerView)

        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AIONDesign.spacing),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AIONDesign.spacing),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AIONDesign.spacing),
            segmentedControl.heightAnchor.constraint(equalToConstant: 36),

            containerView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: AIONDesign.spacing),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func restoreLastSegment() {
        let saved = UserDefaults.standard.integer(forKey: lastSegmentKey)
        currentSegment = (saved >= 0 && saved <= 2) ? saved : 0
        segmentedControl.selectedSegmentIndex = currentSegment
    }

    private func saveLastSegment() {
        UserDefaults.standard.set(currentSegment, forKey: lastSegmentKey)
    }

    private func setupInitialChild() {
        let vc = childVC(for: currentSegment)
        switchToChild(vc, animated: false)
    }

    private func childVC(for segmentIndex: Int) -> UIViewController {
        switch segmentIndex {
        case 0: return summaryVC
        case 1: return activityVC
        default: return trendsVC
        }
    }

    /// The embedded dashboard (summary) – for use from InsightsTabViewController
    var healthDashboardViewController: HealthDashboardViewController? {
        summaryVC
    }

    /// Run analysis for the insights page (delegates to the embedded HealthDashboardViewController)
    func runAnalysisForInsights(forceAnalysis: Bool = false) {
        summaryVC.runAnalysisForInsights(forceAnalysis: forceAnalysis)
    }

    // MARK: - Child VC Switching

    @objc private func segmentChanged() {
        currentSegment = segmentedControl.selectedSegmentIndex
        let vc = childVC(for: currentSegment)
        switchToChild(vc, animated: true)
        saveLastSegment()
    }

    private func switchToChild(_ newVC: UIViewController, animated: Bool) {
        let oldVC = children.first

        // Remove old VC
        oldVC?.willMove(toParent: nil)

        // Add new VC
        addChild(newVC)

        // Setup new view
        newVC.view.frame = containerView.bounds
        newVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        newVC.view.alpha = animated ? 0 : 1

        containerView.addSubview(newVC.view)

        // Animate transition
        UIView.animate(withDuration: animated ? 0.25 : 0) {
            newVC.view.alpha = 1
            oldVC?.view.alpha = 0
        } completion: { _ in
            oldVC?.view.removeFromSuperview()
            oldVC?.removeFromParent()
            newVC.didMove(toParent: self)
        }
    }
}
