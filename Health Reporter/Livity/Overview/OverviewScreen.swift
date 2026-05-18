//
//  OverviewScreen.swift
//  Health Reporter
//
//  Livity-style Overview tab: calendar header + stack of metric cards.
//

import SwiftUI
import Combine
import UIKit

final class LivityOverviewViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var displayMonth: Date = Date()
    @Published var metrics: LivityDailyMetrics = .empty
    @Published var isLoading: Bool = false
    @Published var hasSleepDataTonight: Bool = false
    @Published var showDatePicker: Bool = false
    @Published var unreadNotifications: Int = 0

    private var notificationObservers: [NSObjectProtocol] = []

    init() {
        // Seed from the splash-warmed cache so the very first render shows real
        // numbers, not empty placeholder cards.
        if let cached = LivityMetricsService.shared.cachedMetrics(for: selectedDate) {
            self.metrics = cached
            self.hasSleepDataTonight = (cached.sleepTotalMinutes ?? 0) > 0
        }
        // Refresh the badge whenever a new notification is saved to Firestore, or when the
        // app returns from background — push notifications that fire while the app is
        // suspended only surface here after the user foregrounds us.
        let center = NotificationCenter.default
        notificationObservers.append(center.addObserver(
            forName: NSNotification.Name("NotificationItemSaved"),
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.refreshNotificationBadge()
        })
        notificationObservers.append(center.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.refreshNotificationBadge()
            // Also re-persist today's bedtime so the bell picks up any push we missed.
            BedtimeNotificationManager.shared.persistCurrentBedtimeToFirestore()
        })
    }

    deinit {
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func refresh() {
        // Show cached values immediately so the user never sees "—" while we
        // re-fetch in the background. Splash pre-warms today's data, and date
        // changes will reuse a cache entry if the user revisits a recent date.
        let cached = LivityMetricsService.shared.cachedMetrics(for: selectedDate)
        if let cached {
            self.metrics = cached
            self.hasSleepDataTonight = (cached.sleepTotalMinutes ?? 0) > 0
        }
        // Only show the loading stripe if the user would otherwise see empty cards.
        // When the cache already covers this date, refresh silently in the background
        // — surfacing a spinner over data that's already on-screen looks like the app
        // is stuck.
        isLoading = (cached == nil)
        LivityMetricsService.shared.fetchDaily(for: selectedDate) { [weak self] metrics in
            guard let self else { return }
            self.metrics = metrics
            self.hasSleepDataTonight = (metrics.sleepTotalMinutes ?? 0) > 0
            self.isLoading = false
        }
        // Make sure today's Gemini bedtime is in the bell, then refresh the badge.
        BedtimeNotificationManager.shared.persistCurrentBedtimeToFirestore()
        refreshNotificationBadge()
    }

    func refreshNotificationBadge() {
        FriendsFirestoreSync.fetchUnreadNotificationsCount { [weak self] count in
            DispatchQueue.main.async { self?.unreadNotifications = count }
        }
    }
}

// MARK: - Notifications presenter (bridges SwiftUI → UIKit NotificationsCenterVC)

enum LivityNotificationsPresenter {
    static func present() {
        guard let root = topViewController() else { return }
        let vc = NotificationsCenterViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet
        root.present(nav, animated: true)
    }

    private static func topViewController(_ base: UIViewController? = nil) -> UIViewController? {
        let root = base ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?.rootViewController
        if let nav = root as? UINavigationController { return topViewController(nav.visibleViewController) }
        if let tab = root as? UITabBarController { return topViewController(tab.selectedViewController) }
        if let presented = root?.presentedViewController { return topViewController(presented) }
        return root
    }
}

// MARK: - Which detail is currently open

extension Notification.Name {
    /// Posted by a detail screen when the user taps its date pill — the
    /// Overview screen catches this and opens its calendar picker so the user
    /// can actually pick a different day.
    static let livityRequestDatePicker = Notification.Name("LivityRequestDatePicker")
}

private enum OverviewDetail: Identifiable {
    case bodyBattery, stress, energy, strain, sleep, recovery, daylight, carTier, aiAnalysis

    var id: Int {
        switch self {
        case .bodyBattery: return 1
        case .stress: return 2
        case .energy: return 3
        case .strain: return 4
        case .sleep: return 5
        case .recovery: return 6
        case .daylight: return 7
        case .carTier: return 8
        case .aiAnalysis: return 9
        }
    }
}

/// The reorderable cards on the Overview screen. The AI Analysis card and the
/// Daylight + Car Tier pair are pinned (top and bottom respectively); everything
/// else moves around based on the current chronobiology phase.
private enum OverviewCardKind: Hashable {
    case bodyBattery, stress, energy, strain, sleep, recovery
}

private extension BodyPhaseKind {
    /// Cards ordered from most to least relevant for this phase. The first one
    /// gets the "featured" visual treatment (full size + soft glow); the rest
    /// shrink slightly so the focus card actually stands out.
    var overviewCardOrder: [OverviewCardKind] {
        switch self {
        case .earlyMorning:
            return [.sleep, .recovery, .bodyBattery, .stress, .energy, .strain]
        case .morningPeak:
            return [.bodyBattery, .strain, .recovery, .stress, .energy, .sleep]
        case .midday:
            return [.energy, .strain, .bodyBattery, .stress, .recovery, .sleep]
        case .afternoonDip:
            return [.stress, .bodyBattery, .strain, .energy, .recovery, .sleep]
        case .evening:
            return [.energy, .strain, .recovery, .stress, .bodyBattery, .sleep]
        case .earlyNight:
            return [.recovery, .sleep, .bodyBattery, .energy, .strain, .stress]
        case .circadianNadir:
            return [.sleep, .recovery, .bodyBattery, .stress, .strain, .energy]
        }
    }
}

private extension View {
    /// Visual prominence for the featured card: stays at full scale with a soft
    /// info-tinted shadow, while non-featured cards shrink and dim slightly so
    /// the focus is unambiguous.
    @ViewBuilder
    func livityFeatured(_ isFeatured: Bool) -> some View {
        self
            .scaleEffect(isFeatured ? 1.0 : 0.96, anchor: .center)
            .opacity(isFeatured ? 1.0 : 0.88)
            .shadow(color: isFeatured ? LivityTheme.info.opacity(0.22) : .clear,
                    radius: isFeatured ? 14 : 0,
                    y: isFeatured ? 6 : 0)
    }
}

struct LivityOverviewScreen: View {
    @StateObject private var vm = LivityOverviewViewModel()
    @StateObject private var subscription = SubscriptionManager.shared
    @State private var showAIEnable = false
    @State private var showPaywall = false
    @State private var showActivityStatus = false
    @State private var openDetail: OverviewDetail?
    /// Interactive horizontal offset while the user is swiping between days.
    /// Day offset from today (0 = today, -1 = yesterday, ...). Drives the TabView page selection.
    @State private var dayOffset: Int = 0
    private let daysBack: Int = 60

    private var todayStart: Date { Calendar.current.startOfDay(for: Date()) }

    private func date(forOffset offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: todayStart) ?? todayStart
    }

    var body: some View {
        ZStack {
            LivityTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                LivityOverviewHeader(
                    selectedDate: $vm.selectedDate,
                    showDatePicker: $vm.showDatePicker,
                    onAITap: { handleAITap() },
                    onActivityStatusTap: { showActivityStatus = true },
                    onNotificationsTap: { LivityNotificationsPresenter.present() },
                    notificationBadge: vm.unreadNotifications
                )

                // Slim progress strip — appears under the header whenever the
                // view-model is fetching new metrics (date change, swipe, etc).
                LoadingStripe(visible: vm.isLoading)

                // Instagram-style horizontal paging between days. Native page animation — no custom drag logic.
                TabView(selection: $dayOffset) {
                    ForEach((-daysBack)...0, id: \.self) { offset in
                        dayPage
                            .tag(offset)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: dayOffset) { _, newOffset in
                    let newDate = date(forOffset: newOffset)
                    if !Calendar.current.isDate(newDate, inSameDayAs: vm.selectedDate) {
                        vm.selectedDate = newDate
                        vm.refresh()
                    }
                }
                .onChange(of: vm.selectedDate) { _, newDate in
                    let delta = Calendar.current.dateComponents([.day], from: todayStart, to: Calendar.current.startOfDay(for: newDate)).day ?? 0
                    if delta != dayOffset {
                        dayOffset = max(-daysBack, min(0, delta))
                    }
                }
            }
        }
        .sheet(isPresented: $showAIEnable) { LivityAIEnableSheet() }
        .sheet(isPresented: $showPaywall) { PaywallSheet() }
        .sheet(isPresented: $showActivityStatus) { LivityActivityStatusSheet() }
        .fullScreenCover(item: $openDetail) { detail in
            detailView(for: detail)
        }
        .onAppear {
            LivityMetricsService.shared.ensureDaylightAuthorization()
            vm.refresh()
            // Clean up generic bedtime entries from Firestore — runs once per app appear
            // and is idempotent on the server side.
            FriendsFirestoreSync.deleteGenericBedtimeNotifications(
                placeholders: AppDelegate.bedtimePlaceholderStrings
            ) { _ in }
        }
        .onReceive(NotificationCenter.default.publisher(for: .livityRequestDatePicker)) { _ in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                vm.showDatePicker = true
            }
        }
    }

    private var dayPage: some View {
        ScrollView {
            VStack(spacing: LivityTheme.cardSpacing) {
                if vm.showDatePicker {
                    LivityCalendarPicker(
                        selectedDate: $vm.selectedDate,
                        displayMonth: $vm.displayMonth
                    ) { _ in
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                            vm.showDatePicker = false
                        }
                        vm.refresh()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if !vm.hasSleepDataTonight {
                    LivitySleepBanner()
                        .padding(.horizontal, LivityTheme.horizontalPadding)
                }

                LivityAIAnalysisCard(isPro: subscription.isPro, metrics: vm.metrics) { handleAITap() }
                    .padding(.horizontal, LivityTheme.horizontalPadding)

                let order = vm.metrics.bodyBatteryPhase?.kind.overviewCardOrder
                    ?? [.bodyBattery, .stress, .energy, .strain, .sleep, .recovery]
                ForEach(Array(order.enumerated()), id: \.element) { index, kind in
                    cardView(for: kind)
                        .livityFeatured(index == 0)
                        .padding(.horizontal, LivityTheme.horizontalPadding)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity
                        ))
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: order)

                // Time in Daylight (left) + Your Car tier (right) — two squares side-by-side.
                HStack(spacing: LivityTheme.cardSpacing) {
                    LivityDaylightCard(
                        minutes: vm.metrics.daylightMinutes,
                        percentVsGoal: vm.metrics.daylightPercentVsGoal,
                        history: vm.metrics.daylightHistory
                    ) { openDetail = .daylight }
                        .frame(maxWidth: .infinity)
                    LivityCarTierCard(
                        score: GeminiResultStore.loadCarScore() ?? GeminiResultStore.loadHealthScore(),
                        carModel: GeminiResultStore.loadCarName(),
                        carWikiName: GeminiResultStore.loadCarWikiName() ?? GeminiResultStore.loadCarName()
                    ) { openDetail = .carTier }
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, LivityTheme.horizontalPadding)

                Color.clear.frame(height: 90) // tab bar spacing
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func cardView(for kind: OverviewCardKind) -> some View {
        switch kind {
        case .bodyBattery:
            LivityBodyBatteryCard(
                percent: vm.metrics.bodyBattery,
                phase: vm.metrics.bodyBatteryPhase
            ) { openDetail = .bodyBattery }
        case .stress:
            LivityStressCard(
                value: vm.metrics.stressNow,
                average: vm.metrics.stressAverage,
                peak: vm.metrics.stressPeak,
                low: vm.metrics.stressLow
            ) { openDetail = .stress }
        case .energy:
            LivityEnergyBalanceCard(
                isLogged: vm.metrics.energyLogged,
                caloriesConsumed: vm.metrics.caloriesConsumed,
                caloriesBurned: vm.metrics.caloriesBurned
            ) { openDetail = .energy }
        case .strain:
            LivityStrainCard(
                percent: vm.metrics.strainPercent,
                bucket: vm.metrics.strainBucket,
                totalEnergyKcal: vm.metrics.totalEnergyKcal,
                activeEnergyKcal: vm.metrics.activeEnergyKcal,
                steps: vm.metrics.steps
            ) { openDetail = .strain }
        case .sleep:
            LivitySleepCard(
                score: vm.metrics.sleepScore,
                bucket: vm.metrics.sleepBucket,
                deep: vm.metrics.sleepDeepMinutes,
                rem: vm.metrics.sleepREMMinutes,
                awake: vm.metrics.sleepAwakeMinutes,
                total: vm.metrics.sleepTotalMinutes
            ) { openDetail = .sleep }
        case .recovery:
            LivityRecoveryCard(
                score: vm.metrics.recoveryScore,
                bucket: vm.metrics.recoveryBucket,
                hrv: vm.metrics.hrv,
                rhr: vm.metrics.restingHR,
                respiratoryRate: vm.metrics.respiratoryRate,
                spo2: vm.metrics.spo2,
                wristTempF: vm.metrics.wristTempFahrenheit
            ) { openDetail = .recovery }
        }
    }

    @ViewBuilder
    private func detailView(for detail: OverviewDetail) -> some View {
        switch detail {
        case .bodyBattery:
            LivityBodyBatteryDetail(metrics: vm.metrics) { openDetail = nil }
        case .stress:
            LivityStrainDetail(metrics: vm.metrics, isStressVariant: true) { openDetail = nil }
        case .energy:
            LivityNutritionDetail(metrics: vm.metrics) { openDetail = nil }
        case .strain:
            LivityStrainDetail(metrics: vm.metrics, isStressVariant: false) { openDetail = nil }
        case .sleep:
            LivitySleepDetail(metrics: vm.metrics) { openDetail = nil }
        case .recovery:
            LivityRecoveryDetail(metrics: vm.metrics) { openDetail = nil }
        case .daylight:
            LivityDaylightDetailSheet(metrics: vm.metrics) { openDetail = nil }
        case .carTier:
            LivityCarTierDetailSheet(metrics: vm.metrics) { openDetail = nil }
        case .aiAnalysis:
            LivityAIAnalysisDetailSheet { openDetail = nil }
        }
    }

    private func handleAITap() {
        guard subscription.isPro else {
            showPaywall = true
            return
        }
        if GeminiResultStore.load() != nil {
            openDetail = .aiAnalysis
        } else {
            showAIEnable = true
        }
    }
}

/// 2pt indeterminate progress bar that fades in/out so the user can see when a
/// background fetch is happening (e.g. after picking a different date).
private struct LoadingStripe: View {
    let visible: Bool
    @State private var animating = false

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(LivityTheme.separator.opacity(0.25))
                .frame(height: 2)
            GeometryReader { geo in
                Capsule()
                    .fill(LivityTheme.info)
                    .frame(width: geo.size.width * 0.35, height: 2)
                    .offset(x: animating ? geo.size.width * 0.65 : -geo.size.width * 0.35)
                    .animation(.linear(duration: 1.1).repeatForever(autoreverses: false), value: animating)
            }
            .frame(height: 2)
        }
        .opacity(visible ? 1 : 0)
        .animation(.easeInOut(duration: 0.18), value: visible)
        .onAppear { animating = true }
    }
}
