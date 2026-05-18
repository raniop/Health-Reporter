//
//  LivityHosting.swift
//  Health Reporter
//
//  UIHostingController wrappers so SwiftUI Livity screens can be hosted by the UIKit tab bar.
//

import SwiftUI
import UIKit

/// Shared delegate that refuses the swipe-back gesture. UITabBarController tabs
/// are rooted at these hosts, so there is nothing to pop — left/right drags
/// should never start.
private final class BlockPopGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = BlockPopGestureDelegate()
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool { false }
}

final class LivityOverviewHostingController: UIHostingController<LivityOverviewScreen> {
    init() {
        super.init(rootView: LivityOverviewScreen())
    }
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: LivityOverviewScreen())
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(LivityTheme.background)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        // Root of a tab — block the edge-pan so the whole screen can't slide sideways.
        if let pop = navigationController?.interactivePopGestureRecognizer {
            pop.isEnabled = false
            pop.delegate = BlockPopGestureDelegate.shared
        }
    }
}

final class LivityGoalsHostingController: UIHostingController<LivityGoalsScreen> {
    init() {
        super.init(rootView: LivityGoalsScreen())
    }
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: LivityGoalsScreen())
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(LivityTheme.background)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        if let pop = navigationController?.interactivePopGestureRecognizer {
            pop.isEnabled = false
            pop.delegate = BlockPopGestureDelegate.shared
        }
    }
}

final class LivityProfileHostingController: UIHostingController<LivityProfileScreen> {
    init() {
        super.init(rootView: LivityProfileScreen())
    }
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: LivityProfileScreen())
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(LivityTheme.background)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        if let pop = navigationController?.interactivePopGestureRecognizer {
            pop.isEnabled = false
            pop.delegate = BlockPopGestureDelegate.shared
        }
    }
}
