import CodexBarMacroSupport
import Foundation

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum MakoraProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .makora,
            metadata: ProviderMetadata(
                id: .makora,
                displayName: "Makora",
                sessionLabel: "Credits",
                weeklyLabel: "Credits",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "Prepaid credit balance from the Makora account API",
                toggleTitle: "Show Makora credits",
                cliName: "makora",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                browserCookieOrder: nil,
                dashboardURL: "https://app.makora.com/credits",
                statusPageURL: "https://status.makora.com"),
            branding: ProviderBranding(
                iconStyle: .makora,
                iconResourceName: "ProviderIcon-makora",
                color: ProviderColor(red: 25 / 255, green: 25 / 255, blue: 197 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Makora per-day cost history is not available via API." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .api],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [MakoraAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "makora",
                aliases: ["makora-ai"],
                versionDetector: nil))
    }
}

struct MakoraAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "makora.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        Self.resolveToken(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let apiToken = Self.resolveToken(environment: context.env) else {
            throw MakoraUsageError.missingCredentials
        }
        let usage = try await MakoraUsageFetcher.fetchUsage(apiToken: apiToken)
        return self.makeResult(
            usage: usage.toUsageSnapshot(),
            sourceLabel: "api")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveToken(environment: [String: String]) -> String? {
        ProviderTokenResolver.makoraToken(environment: environment)
    }
}
