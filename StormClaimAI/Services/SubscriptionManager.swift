import Foundation
import StoreKit

@MainActor
final class SubscriptionManager: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published var plan: SubscriptionPlan = .free
    @Published var isActive = false
    @Published var renewsAt: Date?
    @Published var isLoading = false
    @Published var purchasingProductID: String?
    @Published var errorMessage: String?

    let mockMode: Bool

    private let productIDs: [String: SubscriptionPlan] = [
        "stormclaim.pro.monthly": .pro,
        "stormclaim.pro.yearly": .pro,
        "stormclaim.business.monthly": .business
    ]

    init(mockMode: Bool = false) {
        self.mockMode = mockMode
    }

    func loadProducts() async {
        guard !mockMode else { return }
        errorMessage = nil

        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: Array(productIDs.keys))
            await updateEntitlements()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchase(_ product: Product) async {
        guard !mockMode else { return }
        errorMessage = nil
        purchasingProductID = product.id
        defer { purchasingProductID = nil }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(.verified(let transaction)):
                plan = productIDs[transaction.productID] ?? .free
                isActive = plan != .free
                renewsAt = transaction.expirationDate
                await transaction.finish()
            case .success(.unverified):
                errorMessage = "The App Store transaction could not be verified."
            case .pending:
                errorMessage = "The purchase is pending approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        guard !mockMode else { return }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updateEntitlements()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateEntitlements() async {
        guard !mockMode else { return }

        var bestPlan: SubscriptionPlan = .free
        var bestRenewal: Date?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  let entitlementPlan = productIDs[transaction.productID] else {
                continue
            }

            if entitlementPlan == .business || bestPlan == .free {
                bestPlan = entitlementPlan
                bestRenewal = transaction.expirationDate
            }
        }

        plan = bestPlan
        isActive = bestPlan != .free
        renewsAt = bestRenewal
    }

    func products(for plan: SubscriptionPlan) -> [Product] {
        products
            .filter { productIDs[$0.id] == plan }
            .sorted { first, second in
                productSortRank(first.id) < productSortRank(second.id)
            }
    }

    func mockUpgrade(to newPlan: SubscriptionPlan) {
        plan = newPlan
        isActive = newPlan != .free
        renewsAt = Calendar.current.date(byAdding: .month, value: 1, to: .now)
    }

    func caseLimitDescription() -> String {
        switch plan {
        case .free: "2 cases per month"
        case .pro, .business: "Unlimited cases"
        }
    }

    func scanLimitDescription() -> String {
        switch plan {
        case .free: "10 AI photo scans per month"
        case .pro: "250 photo scans per month"
        case .business: "Unlimited reports and team workflow placeholder"
        }
    }

    func canCreateCase(existingCases: [StormCase]) -> Bool {
        guard plan == .free else { return true }
        return monthlyCaseCount(existingCases) < 2
    }

    func monthlyCaseCount(_ cases: [StormCase]) -> Int {
        cases.filter { Calendar.current.isDate($0.createdAt, equalTo: .now, toGranularity: .month) }.count
    }

    func remainingScanAllowance(from findings: [DamageFinding]) -> Int? {
        guard plan == .free else { return nil }

        let scannedPhotoIDs = Set(
            findings
                .filter { Calendar.current.isDate($0.createdAt, equalTo: .now, toGranularity: .month) }
                .map(\.photoId)
        )

        return max(0, 10 - scannedPhotoIDs.count)
    }

    private func productSortRank(_ productID: String) -> Int {
        switch productID {
        case "stormclaim.pro.monthly": 0
        case "stormclaim.pro.yearly": 1
        case "stormclaim.business.monthly": 2
        default: 99
        }
    }
}
