import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

@MainActor
struct MakoraMenuDescriptorTests {
    @Test
    func `menu shows the balance as plain detail without a resets prefix`() throws {
        let suite = "MakoraMenuDescriptorTests-menu"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let settings = SettingsStore(
            userDefaults: defaults,
            configStore: testConfigStore(suiteName: suite),
            zaiTokenStore: NoopZaiTokenStore(),
            syntheticTokenStore: NoopSyntheticTokenStore())
        settings.statusChecksEnabled = false

        let store = UsageStore(
            fetcher: UsageFetcher(environment: [:]),
            browserDetection: BrowserDetection(cacheTTL: 0),
            settings: settings)
        let balance = try #require(Decimal(string: "42.5"))
        let snapshot = MakoraUsageSnapshot(
            status: MakoraCreditsStatus(balance: balance, currency: "Credits"),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000))
        store._setSnapshotForTesting(snapshot.toUsageSnapshot(), provider: .makora)

        let lines = Self.menuLines(provider: .makora, store: store, settings: settings)

        #expect(lines.contains("Makora"))
        #expect(lines.contains("42.50 Credits"))
        // Makora credits do not expire on a schedule, so the balance must never be
        // labelled as a reset.
        #expect(!lines.contains { $0.localizedCaseInsensitiveContains("Resets") })
    }

    @Test
    func `menu keeps two-decimal balances intact`() throws {
        let suite = "MakoraMenuDescriptorTests-cents"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let settings = SettingsStore(
            userDefaults: defaults,
            configStore: testConfigStore(suiteName: suite),
            zaiTokenStore: NoopZaiTokenStore(),
            syntheticTokenStore: NoopSyntheticTokenStore())
        settings.statusChecksEnabled = false

        let store = UsageStore(
            fetcher: UsageFetcher(environment: [:]),
            browserDetection: BrowserDetection(cacheTTL: 0),
            settings: settings)
        let balance = try #require(Decimal(string: "2.30"))
        let snapshot = MakoraUsageSnapshot(
            status: MakoraCreditsStatus(balance: balance, currency: "Credits"),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000))
        store._setSnapshotForTesting(snapshot.toUsageSnapshot(), provider: .makora)

        let lines = Self.menuLines(provider: .makora, store: store, settings: settings)

        #expect(lines.contains("2.30 Credits"))
    }

    private static func menuLines(
        provider: UsageProvider,
        store: UsageStore,
        settings: SettingsStore) -> [String]
    {
        let descriptor = MenuDescriptor.build(
            provider: provider,
            store: store,
            settings: settings,
            account: AccountInfo(email: nil, plan: nil),
            updateReady: false,
            includeContextualActions: false)
        return descriptor.sections
            .flatMap(\.entries)
            .compactMap { entry -> String? in
                guard case let .text(text, _) = entry else { return nil }
                return text
            }
    }
}
