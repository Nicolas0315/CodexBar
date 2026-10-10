import CodexBarCore
import Foundation
import Testing

/// The fetch pipeline has no transport seam, so network behaviour is covered hermetically in
/// `MakoraUsageFetcherTests` via an injected `ProviderHTTPTransport`. These tests cover the
/// descriptor wiring and credential gating only.
@Suite(.serialized)
struct MakoraProviderFetchTests {
    @Test
    func `descriptor resolves a single api token strategy`() async {
        let descriptor = ProviderDescriptorRegistry.descriptor(for: .makora)
        let strategies = await descriptor.fetchPlan.pipeline.resolveStrategies(Self.context(env: [:]))

        #expect(strategies.count == 1)
        #expect(strategies.first?.id == "makora.api")
        #expect(strategies.first?.kind == .apiToken)
    }

    @Test
    func `descriptor strategy is available when a token is present`() async throws {
        let strategy = try await Self.strategy(env: ["MAKORA_API_TOKEN": "token"])

        #expect(await strategy.isAvailable(Self.context(env: ["MAKORA_API_TOKEN": "token"])))
    }

    @Test
    func `descriptor strategy is unavailable without a token`() async throws {
        let env = ["MAKORA_USER_FILE": "/nonexistent/makora-user"]
        let strategy = try await Self.strategy(env: env)

        #expect(await !strategy.isAvailable(Self.context(env: env)))
    }

    @Test
    func `descriptor strategy reports missing credentials without a token`() async throws {
        let env = ["MAKORA_USER_FILE": "/nonexistent/makora-user"]
        let strategy = try await Self.strategy(env: env)

        await #expect(throws: MakoraUsageError.missingCredentials) {
            _ = try await strategy.fetch(Self.context(env: env))
        }
    }

    private static func strategy(env: [String: String]) async throws -> any ProviderFetchStrategy {
        let descriptor = ProviderDescriptorRegistry.descriptor(for: .makora)
        let strategies = await descriptor.fetchPlan.pipeline.resolveStrategies(Self.context(env: env))
        return try #require(strategies.first)
    }

    private static func context(env: [String: String]) -> ProviderFetchContext {
        ProviderFetchContext(
            runtime: .cli,
            sourceMode: .api,
            includeCredits: false,
            webTimeout: 1,
            webDebugDumpHTML: false,
            verbose: false,
            env: env,
            settings: nil,
            fetcher: UsageFetcher(environment: env),
            claudeFetcher: StubClaudeFetcher(),
            browserDetection: BrowserDetection(cacheTTL: 0))
    }
}

private struct StubClaudeFetcher: ClaudeUsageFetching {
    func loadLatestUsage(model _: String) async throws -> ClaudeUsageSnapshot {
        throw ClaudeUsageError.parseFailed("stub")
    }

    func debugRawProbe(model _: String) async -> String {
        "stub"
    }

    func detectVersion() -> String? {
        nil
    }
}
