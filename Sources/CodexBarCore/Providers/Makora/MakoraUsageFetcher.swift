import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum MakoraUsageError: LocalizedError, Sendable, Equatable {
    case missingCredentials
    case unauthorized
    case unknownAccount
    case networkError(String)
    case apiError(Int)
    case parseFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingCredentials:
            "Missing Makora API token."
        case .unauthorized:
            "Makora rejected the API token. Create a new one at https://generate.makora.com/tokens."
        case .unknownAccount:
            "Makora does not recognize this API token's account. Create a fresh token at https://generate.makora.com/tokens."
        case let .networkError(message):
            "Makora network error: \(message)"
        case let .apiError(statusCode):
            "Makora API error: HTTP \(statusCode)"
        case let .parseFailed(message):
            "Failed to parse Makora response: \(message)"
        }
    }
}

public enum MakoraUsageFetcher {
    /// Account/credit API host. The dashboard (app.makora.com) serves `/api/v1/credits/*`;
    /// the separate `be.prod.makora.com` deployment does not mount the credits router.
    public static let apiBaseURL = URL(string: "https://app.makora.com/api/v1")!
    public static let creditsStatusURL = URL(string: "https://app.makora.com/api/v1/credits/status")!
    public static let currentUserURL = URL(string: "https://app.makora.com/api/v1/auth/me")!
    private static let timeoutSeconds: TimeInterval = 15

    public static func fetchUsage(
        apiToken: String,
        session transport: any ProviderHTTPTransport = ProviderHTTPClient.shared) async throws -> MakoraUsageSnapshot
    {
        let trimmed = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MakoraUsageError.missingCredentials
        }

        let status = try await self.fetchCreditsStatus(apiToken: trimmed, session: transport)
        // Account identity is a best-effort extra; the balance is the required payload.
        let email = try? await self.fetchAccountEmail(apiToken: trimmed, session: transport)

        return MakoraUsageSnapshot(
            status: status,
            accountEmail: email,
            updatedAt: Date())
    }

    static func fetchCreditsStatus(
        apiToken: String,
        session transport: any ProviderHTTPTransport) async throws -> MakoraCreditsStatus
    {
        let data = try await self.get(url: self.creditsStatusURL, apiToken: apiToken, session: transport)
        do {
            return try JSONDecoder().decode(MakoraCreditsStatus.self, from: data)
        } catch {
            throw MakoraUsageError.parseFailed(error.localizedDescription)
        }
    }

    static func fetchAccountEmail(
        apiToken: String,
        session transport: any ProviderHTTPTransport) async throws -> String?
    {
        let data = try await self.get(url: self.currentUserURL, apiToken: apiToken, session: transport)
        struct CurrentUser: Decodable {
            let email: String?
        }
        return try? JSONDecoder().decode(CurrentUser.self, from: data).email
    }

    static func _parseCreditsStatusForTesting(_ data: Data) throws -> MakoraCreditsStatus {
        do {
            return try JSONDecoder().decode(MakoraCreditsStatus.self, from: data)
        } catch {
            throw MakoraUsageError.parseFailed(error.localizedDescription)
        }
    }

    private static func get(
        url: URL,
        apiToken: String,
        session transport: any ProviderHTTPTransport) async throws -> Data
    {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = Self.timeoutSeconds
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let response: (Data, URLResponse)
        do {
            response = try await transport.data(for: request)
        } catch {
            throw MakoraUsageError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response.1 as? HTTPURLResponse else {
            throw MakoraUsageError.networkError("Unexpected non-HTTP response")
        }

        switch httpResponse.statusCode {
        case 200:
            return response.0
        case 401, 403:
            throw MakoraUsageError.unauthorized
        case 404:
            // Makora answers an unknown bearer token with "User not found" instead of 401.
            throw MakoraUsageError.unknownAccount
        default:
            throw MakoraUsageError.apiError(httpResponse.statusCode)
        }
    }
}
