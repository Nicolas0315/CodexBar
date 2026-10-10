import AppKit
import CodexBarCore
import CodexBarMacroSupport
import Foundation

@ProviderImplementationRegistration
struct MakoraProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .makora

    @MainActor
    func presentation(context _: ProviderPresentationContext) -> ProviderPresentation {
        ProviderPresentation { _ in "api" }
    }

    @MainActor
    func observeSettings(_ settings: SettingsStore) {
        _ = settings.makoraAPIToken
    }

    @MainActor
    func isAvailable(context: ProviderAvailabilityContext) -> Bool {
        if MakoraSettingsReader.apiToken(environment: context.environment) != nil {
            return true
        }
        return !context.settings.makoraAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "makora-api-token",
                title: "API token",
                subtitle: "Account token used for the credit balance. Stored in ~/.codexbar/config.json. "
                    + "You can also provide MAKORA_API_TOKEN, or run `makora login` to reuse ~/.makora/user.",
                kind: .secure,
                placeholder: "makora token",
                binding: context.stringBinding(\.makoraAPIToken),
                actions: [
                    ProviderSettingsActionDescriptor(
                        id: "makora-open-credits",
                        title: "Open Makora credits",
                        style: .link,
                        isVisible: nil,
                        perform: {
                            if let url = URL(string: "https://app.makora.com/credits") {
                                NSWorkspace.shared.open(url)
                            }
                        }),
                    ProviderSettingsActionDescriptor(
                        id: "makora-open-tokens",
                        title: "Create a token",
                        style: .link,
                        isVisible: nil,
                        perform: {
                            if let url = URL(string: "https://generate.makora.com/tokens") {
                                NSWorkspace.shared.open(url)
                            }
                        }),
                ],
                isVisible: nil,
                onActivate: nil),
        ]
    }
}
