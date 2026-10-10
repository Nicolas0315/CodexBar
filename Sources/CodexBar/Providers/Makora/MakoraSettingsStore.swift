import CodexBarCore
import Foundation

extension SettingsStore {
    var makoraAPIToken: String {
        get { self.configSnapshot.providerConfig(for: .makora)?.sanitizedAPIKey ?? "" }
        set {
            self.updateProviderConfig(provider: .makora) { entry in
                entry.apiKey = self.normalizedConfigValue(newValue)
            }
            self.logSecretUpdate(provider: .makora, field: "apiKey", value: newValue)
        }
    }
}
