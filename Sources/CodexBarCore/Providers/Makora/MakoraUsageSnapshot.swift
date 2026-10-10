import Foundation

/// Credit balance reported by `GET /api/v1/credits/status`.
public struct MakoraCreditsStatus: Decodable, Sendable, Equatable {
    /// Prepaid balance. Kept as `Decimal` so two-decimal amounts are not distorted by
    /// binary floating point (for example `2.30` must not render as `2.29`).
    public let balance: Decimal
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
        balance: Decimal,
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
        // `balance` is required by CreditsStatusOut; a payload without it is a parse
        // failure rather than a silently exhausted `$0.00` balance.
        self.balance = try container.decode(Decimal.self, forKey: .balance)
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
            // present vs. exhausted credits. The amount itself is carried as the window's
            // detail text; `resetDescription` is deliberately left nil so renderers do not
            // label a non-expiring balance as a reset.
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
    ///
    /// Rounds down to whole cents using decimal arithmetic so sub-cent value is discarded
    /// without the error that binary `Double` flooring introduces.
    static func formatBalance(_ value: Decimal, currency: String?) -> String {
        var rounded = Decimal()
        var input = max(0, value)
        NSDecimalRound(&rounded, &input, 2, .down)

        let amount = NSDecimalNumber(decimal: rounded).stringValue
        let normalized = Self.normalizedAmount(rounded, fallback: amount)
        guard let currency = currency?.trimmingCharacters(in: .whitespacesAndNewlines), !currency.isEmpty else {
            return "$\(normalized)"
        }
        return "\(normalized) \(currency)"
    }

    /// Renders a decimal with exactly two fractional digits (`42.5` → `42.50`).
    private static func normalizedAmount(_ value: Decimal, fallback: String) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? fallback
    }
}
