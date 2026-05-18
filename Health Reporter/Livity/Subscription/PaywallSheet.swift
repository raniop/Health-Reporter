//
//  PaywallSheet.swift
//  Health Reporter
//
//  AION Pro paywall: monthly / yearly tiers, restore, T&Cs links.
//

import SwiftUI
import StoreKit

struct PaywallSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = SubscriptionManager.shared
    @State private var selectedPeriod: Period = .yearly
    @State private var isPurchasing = false

    enum Period { case monthly, yearly }

    private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private let privacyURL = URL(string: "https://healthreporter.app/privacy")!

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                featureList
                plansSection
                purchaseButton
                restoreAndLegal
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(LivityTheme.background.ignoresSafeArea())
        .overlay(alignment: .topTrailing) { closeButton }
        .task { await store.loadProducts() }
        .alert("Purchase failed", isPresented: Binding(
            get: { store.purchaseError != nil },
            set: { if !$0 { store.purchaseError = nil } }
        )) {
            Button("OK") { store.purchaseError = nil }
        } message: {
            Text(store.purchaseError ?? "")
        }
        .onChange(of: store.isPro) { _, newValue in
            if newValue { dismiss() }
        }
    }

    // MARK: - Subviews

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(LivityTheme.textSecondary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(LivityTheme.chipFill))
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
        .padding(.trailing, 16)
    }

    private var header: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(LivityTheme.infoTint.opacity(0.7))
                .frame(width: 96, height: 96)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(LivityTheme.info)
                )
                .padding(.top, 28)

            Text("AION Pro")
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(LivityTheme.textPrimary)

            Text("Unlock personalised AI analysis, unlimited insights, and advanced features.")
                .font(.system(size: 16))
                .foregroundStyle(LivityTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            featureRow(icon: "sparkles", title: "AI daily analysis", subtitle: "Personalised insights on your sleep, recovery, and training")
            featureRow(icon: "waveform.path.ecg", title: "Advanced metrics", subtitle: "Body Battery, Strain, Recovery, and more")
            featureRow(icon: "chart.line.uptrend.xyaxis", title: "Unlimited history", subtitle: "Full trends and deep dives across weeks and months")
            featureRow(icon: "bell.badge.fill", title: "Smart reminders", subtitle: "Morning briefings and bedtime nudges tailored to you")
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18).fill(LivityTheme.cardFill))
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(LivityTheme.info)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LivityTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(LivityTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var plansSection: some View {
        VStack(spacing: 10) {
            if store.isLoadingProducts && store.products.isEmpty {
                ProgressView().padding(.vertical, 20)
            } else {
                if let yearly = store.yearlyProduct {
                    planRow(product: yearly, period: .yearly, badge: "BEST VALUE")
                }
                if let monthly = store.monthlyProduct {
                    planRow(product: monthly, period: .monthly, badge: nil)
                }
                if store.products.isEmpty && !store.isLoadingProducts {
                    Text("Subscription options unavailable right now.")
                        .font(.system(size: 13))
                        .foregroundStyle(LivityTheme.textSecondary)
                        .padding(.vertical, 12)
                }
            }
        }
    }

    private func planRow(product: Product, period: Period, badge: String?) -> some View {
        let isSelected = selectedPeriod == period
        let priceText = product.displayPrice
        let cadence = product.aionPeriodUnit
        let savings = savingsText(for: period)

        return Button {
            selectedPeriod = period
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .strokeBorder(isSelected ? LivityTheme.info : LivityTheme.textTertiary, lineWidth: 2)
                    .background(
                        Circle()
                            .fill(isSelected ? LivityTheme.info : Color.clear)
                            .padding(4)
                    )
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(period == .yearly ? "Yearly" : "Monthly")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(LivityTheme.textPrimary)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(LivityTheme.good))
                        }
                    }
                    if let savings {
                        Text(savings)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(LivityTheme.good)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(priceText)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(LivityTheme.textPrimary)
                    Text("per \(cadence)")
                        .font(.system(size: 12))
                        .foregroundStyle(LivityTheme.textSecondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? LivityTheme.infoTint.opacity(0.5) : LivityTheme.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? LivityTheme.info : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var purchaseButton: some View {
        Button {
            Task { await triggerPurchase() }
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text(buttonTitle)
                        .font(.system(size: 17, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Capsule().fill(LivityTheme.info))
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing || selectedProduct == nil)
        .opacity((isPurchasing || selectedProduct == nil) ? 0.7 : 1)
    }

    private var restoreAndLegal: some View {
        VStack(spacing: 12) {
            Button("Restore Purchases") {
                Task {
                    isPurchasing = true
                    await store.restore()
                    isPurchasing = false
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(LivityTheme.textSecondary)

            HStack(spacing: 18) {
                Link("Terms of Use", destination: termsURL)
                    .font(.system(size: 12))
                    .foregroundStyle(LivityTheme.textTertiary)
                Link("Privacy Policy", destination: privacyURL)
                    .font(.system(size: 12))
                    .foregroundStyle(LivityTheme.textTertiary)
            }

            Text("Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period. Manage in Settings.")
                .font(.system(size: 11))
                .foregroundStyle(LivityTheme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    // MARK: - Helpers

    private var selectedProduct: Product? {
        switch selectedPeriod {
        case .monthly: return store.monthlyProduct
        case .yearly: return store.yearlyProduct
        }
    }

    private var buttonTitle: String {
        guard let product = selectedProduct else { return "Continue" }
        return "Continue for \(product.displayPrice)"
    }

    private func savingsText(for period: Period) -> String? {
        guard period == .yearly,
              let monthly = store.monthlyProduct,
              let yearly = store.yearlyProduct else { return nil }
        let monthlyAnnual = monthly.price * 12
        guard monthlyAnnual > 0 else { return nil }
        let saved = monthlyAnnual - yearly.price
        guard saved > 0 else { return nil }
        let percent = Int((NSDecimalNumber(decimal: saved).doubleValue / NSDecimalNumber(decimal: monthlyAnnual).doubleValue) * 100)
        return "Save \(percent)% vs. monthly"
    }

    private func triggerPurchase() async {
        guard let product = selectedProduct else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        let success = await store.purchase(product)
        if success { dismiss() }
    }
}
