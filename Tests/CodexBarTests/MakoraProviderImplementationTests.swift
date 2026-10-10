import CodexBarCore
import Foundation
import SwiftUI
import Testing
@testable import CodexBar

@MainActor
struct MakoraProviderImplementationTests {
    @Test
    func `availability uses makora environment token`() throws {
        let settings = try Self.makeSettings(suite: "MakoraProviderImplementationTests-env")
        let implementation = MakoraProviderImplementation()

        let context = ProviderAvailabilityContext(
            provider: .makora,
            settings: settings,
            environment: [MakoraSettingsReader.apiTokenEnvironmentKeys[0]: "env-token"])

        #expect(implementation.isAvailable(context: context))
    }

    @Test
    func `availability uses stored makora token`() throws {
        let settings = try Self.makeSettings(suite: "MakoraProviderImplementationTests-settings")
        settings.makoraAPIToken = "stored-token"
        let implementation = MakoraProviderImplementation()

        let context = ProviderAvailabilityContext(provider: .makora, settings: settings, environment: [:])

        #expect(implementation.isAvailable(context: context))
    }

    @Test
    func `availability rejects missing makora token`() throws {
        let settings = try Self.makeSettings(suite: "MakoraProviderImplementationTests-missing")
        settings.makoraAPIToken = "   "
        let implementation = MakoraProviderImplementation()

        let context = ProviderAvailabilityContext(
            provider: .makora,
            settings: settings,
            environment: ["MAKORA_USER_FILE": "/nonexistent/makora-user"])

        #expect(!implementation.isAvailable(context: context))
    }

    @Test
    func `descriptor exposes makora credits metadata`() throws {
        let descriptor = try #require(ProviderDescriptorRegistry.descriptor(for: .makora))

        #expect(descriptor.metadata.displayName == "Makora")
        #expect(descriptor.metadata.sessionLabel == "Credits")
        #expect(descriptor.metadata.dashboardURL == "https://app.makora.com/credits")
        #expect(descriptor.metadata.statusPageURL == "https://status.makora.com")
        #expect(descriptor.branding.iconResourceName == "ProviderIcon-makora")
        #expect(descriptor.fetchPlan.sourceModes == [.auto, .api])
    }

    @Test
    func `settings field uses the makora api token binding`() throws {
        let settings = try Self.makeSettings(suite: "MakoraProviderImplementationTests-fields")
        let implementation = MakoraProviderImplementation()
        let context = ProviderSettingsContext(
            provider: .makora,
            settings: settings,
            store: UsageStore(
                fetcher: UsageFetcher(environment: [:]),
                browserDetection: BrowserDetection(cacheTTL: 0),
                settings: settings),
            boolBinding: { keyPath in
                Binding(
                    get: { settings[keyPath: keyPath] },
                    set: { settings[keyPath: keyPath] = $0 })
            },
            stringBinding: { keyPath in
                Binding(
                    get: { settings[keyPath: keyPath] },
                    set: { settings[keyPath: keyPath] = $0 })
            },
            statusText: { _ in nil },
            setStatusText: { _, _ in },
            lastAppActiveRunAt: { _ in nil },
            setLastAppActiveRunAt: { _, _ in },
            requestConfirmation: { _ in },
            runLoginFlow: {})

        let fields = implementation.settingsFields(context: context)

        let field = try #require(fields.first)
        #expect(field.id == "makora-api-token")
        #expect(field.kind == .secure)
        field.binding.wrappedValue = "typed-token"
        #expect(settings.makoraAPIToken == "typed-token")
    }

    private static func makeSettings(suite: String) throws -> SettingsStore {
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return SettingsStore(
            userDefaults: defaults,
            configStore: testConfigStore(suiteName: suite),
            zaiTokenStore: NoopZaiTokenStore(),
            syntheticTokenStore: NoopSyntheticTokenStore())
    }
}
