import Foundation

/// Resolves the Makora API token from the process environment or the CLI credential store.
///
/// Makora account/credit tooling authenticates with a bearer token. The token is either
/// supplied through the environment or read from the credential file written by the
/// `makora login` CLI (`~/.makora/user`, a small YAML document holding `token`/`user`).
public enum MakoraSettingsReader {
    public static let apiTokenEnvironmentKeys = ["MAKORA_API_TOKEN", "MAKORA_TOKEN", "MAKORA_API_KEY"]

    /// Path to the credential file written by `makora login`. Honors `MAKORA_USER_FILE`.
    public static func credentialFileURL(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> URL?
    {
        if let override = self.cleaned(environment["MAKORA_USER_FILE"]) {
            return URL(fileURLWithPath: (override as NSString).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".makora/user")
    }

    public static func apiToken(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        credentialFileURL: URL? = nil) -> String?
    {
        for key in self.apiTokenEnvironmentKeys {
            if let value = self.cleaned(environment[key]) {
                return value
            }
        }
        return self.tokenFromCredentialFile(at: credentialFileURL ?? self.credentialFileURL(environment: environment))
    }

    /// Reads `token` out of the YAML credential file without depending on a YAML parser.
    ///
    /// The file is a flat `key: value` document, so a scalar scan is sufficient and avoids
    /// pulling in a dependency for a single field.
    public static func tokenFromCredentialFile(at url: URL?) -> String? {
        guard let url,
              let contents = try? String(contentsOf: url, encoding: .utf8)
        else {
            return nil
        }

        for rawLine in contents.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.hasPrefix("#"), let separator = line.firstIndex(of: ":") else { continue }
            guard line[line.startIndex..<separator].trimmingCharacters(in: .whitespaces) == "token" else {
                continue
            }
            let rawValue = String(line[line.index(after: separator)...])
            return self.cleaned(rawValue)
        }
        return nil
    }

    static func cleaned(_ raw: String?) -> String? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
            (value.hasPrefix("'") && value.hasSuffix("'"))
        {
            value = String(value.dropFirst().dropLast())
        }
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
