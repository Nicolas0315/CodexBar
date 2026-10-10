import Foundation

/// Credit balance reported by `GET /api/v1/credits/status`.
public struct MakoraCreditsStatus: Decodable, Sendable, Equatable {
    public let balance: Double
    public let currency: String?
    public let hasPaymentMethod: Bool
    public let hasDefaultPaymentMethod: Bool

    enum CodingKeys: String, CodingKey {
        case balance
        case currency
        case hasPaymentMethod = "has_payment_method"
        case hasDefaultPaymentMethod = "has_default_payment_method"
    }

    public init(
        balance: Double,
        currency: String? = nil,
        hasPaymentMethod: Bool = false,
        hasDefaultPaymentMethod: Bool = false)
    {
        self.balance = balance
        self.currency = currency
        self.hasPaymentMethod = hasPaymentMethod
        self.hasDefaultPaymentMethod = hasDefaultPaymentMethod
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.balance = try container.decodeIfPresent(Double.self, forKey: .balance) ?? 0
        self.currency = try container.decodeIfPresent(String.self, forKey: .currency)
        self.hasPaymentMethod = try container.decodeIfPresent(Bool.self, forKey: .hasPaymentMethod) ?? false
        self.hasDefaultPaymentMethod = try container
            .decodeIfPresent(Bool.self, forKey: .hasDefaultPaymentMethod) ?? false
    }
}

public struct MakoraUsageSnapshot: Sendable {
    public let status: MakoraCreditsStatus
    public let accountEmail: String?
    public let updatedAt: Date

    public init(
        status: MakoraCreditsStatus,
        accountEmail: String? = nil,
        updatedAt: Date = Date())
    {
        self.status = status
        self.accountEmail = accountEmail
        self.updatedAt = updatedAt
    }

    public func toUsageSnapshot() -> UsageSnapshot {
        let balanceText = Self.formatBalance(self.status.balance, currency: self.status.currency)
        let window = RateWindow(
            // Makora reports a prepaid balance with no spend cap, so the bar only signals
            // present vs. exhausted credits — the balance itself lives in the detail line.
            usedPercent: self.status.balance > 0 ? 0 : 100,
            windowMinutes: nil,
            resetsAt: nil,
            resetDescription: balanceText)

        return UsageSnapshot(
            primary: window,
            secondary: nil,
            providerCost: nil,
            updatedAt: self.updatedAt,
            identity: ProviderIdentitySnapshot(
                providerID: .makora,
                accountEmail: self.accountEmail,
                accountOrganization: nil,
                loginMethod: "API token"))
    }

    /// Formats a credit balance. Makora reports `currency` as `"Credits"` where 1 credit = $1.
    static func formatBalance(_ value: Double, currency: String?) -> String {
        let clamped = max(0, value)
        let cents = floor(clamped * 100) / 100
        guard let currency = currency?.trimmingCharacters(in: .whitespacesAndNewlines), !currency.isEmpty else {
            return String(format: "$%.2f", cents)
        }
        return "\(String(format: "%.2f", cents)) \(currency)"
    }
}
