//
//  SubscriptionManager.swift
//  Health Reporter
//
//  StoreKit 2 subscription manager for AION Pro.
//  Exposes product list, purchase state, and an `isPro` flag the UI can read.
//

import Foundation
import StoreKit
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    enum ProductID: String, CaseIterable {
        case monthly = "com.healthreporter.aion.pro.monthly"
        case yearly = "com.healthreporter.aion.pro.yearly"
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoadingProducts: Bool = false
    @Published var purchaseError: String?

    var isPro: Bool { !purchasedProductIDs.isEmpty }

    var monthlyProduct: Product? { products.first { $0.id == ProductID.monthly.rawValue } }
    var yearlyProduct: Product? { products.first { $0.id == ProductID.yearly.rawValue } }

    private var updatesTask: Task<Void, Never>?

    private static let cachedEntitlementsKey = "aion.pro.cachedEntitlements"

    private init() {
        // Seed from cached entitlements synchronously so subscribers don't see the
        // free-tier paywall flash on launch while StoreKit's async refresh runs.
        if let cached = UserDefaults.standard.array(forKey: Self.cachedEntitlementsKey) as? [String] {
            purchasedProductIDs = Set(cached)
        }

        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await loadProducts() }
        Task { await refreshEntitlements() }
    }

    deinit { updatesTask?.cancel() }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let ids = ProductID.allCases.map(\.rawValue)
            let loaded = try await Product.products(for: ids)
            products = loaded.sorted { lhs, rhs in
                Self.periodRank(lhs) < Self.periodRank(rhs)
            }
        } catch {
            purchaseError = "Couldn't load subscription options. Check your connection and try again."
        }
    }

    func purchase(_ product: Product) async -> Bool {
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                return true
            case .userCancelled:
                return false
            case .pending:
                purchaseError = "Your purchase is pending approval."
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseError = error.localizedDescription
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        var active: Set<String> = []
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               ProductID(rawValue: transaction.productID) != nil,
               transaction.revocationDate == nil,
               !(transaction.isUpgraded) {
                active.insert(transaction.productID)
            }
        }
        purchasedProductIDs = active
        UserDefaults.standard.set(Array(active), forKey: Self.cachedEntitlementsKey)
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await transaction.finish()
        await refreshEntitlements()
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified(_, let error): throw error
        }
    }

    private static func periodRank(_ product: Product) -> Int {
        guard let unit = product.subscription?.subscriptionPeriod.unit else { return 99 }
        switch unit {
        case .day: return 0
        case .week: return 1
        case .month: return 2
        case .year: return 3
        @unknown default: return 99
        }
    }
}

extension Product {
    /// "month" / "year" string for the UI.
    var aionPeriodUnit: String {
        guard let unit = subscription?.subscriptionPeriod.unit else { return "" }
        switch unit {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        @unknown default: return ""
        }
    }
}
