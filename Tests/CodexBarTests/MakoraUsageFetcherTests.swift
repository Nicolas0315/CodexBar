import Foundation
import Testing
@testable import CodexBarCore

@Suite(.serialized)
struct MakoraUsageFetcherTests {
    @Test
    func `credits URL points at the account API`() {
        #expect(MakoraUsageFetcher.creditsStatusURL.absoluteString == "https://app.makora.com/api/v1/credits/status")
        #expect(MakoraUsageFetcher.apiBaseURL.absoluteString == "https://app.makora.com/api/v1")
    }

    @Test
    func `credits status parses balance and payment flags`() throws {
        let json = """
        {"balance":42.5,"currency":"Credits","has_payment_method":true,"has_default_payment_method":false}
        """

        let status = try MakoraUsageFetcher._parseCreditsStatusForTesting(Data(json.utf8))

        #expect(status.balance == Decimal(string: "42.5"))
        #expect(status.currency == "Credits")
        #expect(status.hasPaymentMethod)
        #expect(!status.hasDefaultPaymentMethod)
    }

    @Test
    func `credits status tolerates omitted optional fields`() throws {
        let status = try MakoraUsageFetcher._parseCreditsStatusForTesting(Data(#"{"balance":7}"#.utf8))

        #expect(status.balance == Decimal(7))
        #expect(status.currency == nil)
        #expect(!status.hasPaymentMethod)
        #expect(!status.hasDefaultPaymentMethod)
    }

    @Test
    func `credits status rejects malformed payload`() {
        #expect(throws: MakoraUsageError.self) {
            try MakoraUsageFetcher._parseCreditsStatusForTesting(Data("not json".utf8))
        }
    }

    @Test
    func `usage snapshot maps balance to remaining credit window`() throws {
        let balance = try #require(Decimal(string: "42.5"))
        let snapshot = MakoraUsageSnapshot(
            status: MakoraCreditsStatus(balance: balance, currency: "Credits"),
            accountEmail: "user@example.com",
            updatedAt: Date(timeIntervalSince1970: 1_777_800_000))

        let usage = snapshot.toUsageSnapshot()

        #expect(usage.primary?.usedPercent == 0)
        #expect(usage.primary?.windowMinutes == nil)
        #expect(usage.primary?.resetDescription == "42.50 Credits")
        #expect(usage.secondary == nil)
        #expect(usage.identity?.providerID == .makora)
        #expect(usage.identity?.accountEmail == "user@example.com")
        #expect(usage.identity?.loginMethod == "API token")
    }

    @Test
    func `usage snapshot marks exhausted balance as fully used`() {
        let snapshot = MakoraUsageSnapshot(status: MakoraCreditsStatus(balance: Decimal(0)))

        #expect(snapshot.toUsageSnapshot().primary?.usedPercent == 100)
    }

    @Test
    func `balance formatting floors to cents and falls back to dollars`() {
        #expect(MakoraUsageSnapshot.formatBalance(9.9999, currency: "Credits") == "9.99 Credits")
        #expect(MakoraUsageSnapshot.formatBalance(12, currency: nil) == "$12.00")
        #expect(MakoraUsageSnapshot.formatBalance(12, currency: "   ") == "$12.00")
        #expect(MakoraUsageSnapshot.formatBalance(-5, currency: "Credits") == "0.00 Credits")
    }

    @Test
    func `balance formatting never underreports two-decimal amounts`() throws {
        let twoThirty = try #require(Decimal(string: "2.30"))
        let oneFifteen = try #require(Decimal(string: "1.15"))
        let eightTwenty = try #require(Decimal(string: "8.20"))
        let twentyNine = try #require(Decimal(string: "0.29"))

        // Binary Double flooring turned these into 2.29 / 1.14 / 8.19.
        #expect(MakoraUsageSnapshot.formatBalance(twoThirty, currency: "Credits") == "2.30 Credits")
        #expect(MakoraUsageSnapshot.formatBalance(oneFifteen, currency: "Credits") == "1.15 Credits")
        #expect(MakoraUsageSnapshot.formatBalance(eightTwenty, currency: nil) == "$8.20")
        #expect(MakoraUsageSnapshot.formatBalance(twentyNine, currency: nil) == "$0.29")
    }

    @Test
    func `balance formatting still discards true sub-cent value`() throws {
        let tiny = try #require(Decimal(string: "0.004"))
        let large = try #require(Decimal(string: "1234.56"))

        let subCent = try #require(Decimal(string: "9.999"))
        #expect(MakoraUsageSnapshot.formatBalance(subCent, currency: "Credits") == "9.99 Credits")
        #expect(MakoraUsageSnapshot.formatBalance(tiny, currency: nil) == "$0.00")
        #expect(MakoraUsageSnapshot.formatBalance(large, currency: nil) == "$1234.56")
    }

    @Test
    func `credits status requires a balance field`() {
        // A successful-but-incomplete payload must not render as a real $0.00 balance.
        #expect(throws: MakoraUsageError.self) {
            try MakoraUsageFetcher._parseCreditsStatusForTesting(Data(#"{"currency":"Credits"}"#.utf8))
        }
    }

    @Test
    func `only the known not-found payload maps to unknown account`() {
        #expect(MakoraUsageFetcher.isUnknownAccountPayload(Data(#"{"detail":"User not found"}"#.utf8)))
        #expect(MakoraUsageFetcher.isUnknownAccountPayload(Data(#"{"detail":"USER NOT FOUND"}"#.utf8)))
        #expect(!MakoraUsageFetcher.isUnknownAccountPayload(Data(#"{"detail":"Not Found"}"#.utf8)))
        #expect(!MakoraUsageFetcher.isUnknownAccountPayload(Data("<!doctype html>".utf8)))
    }

    @Test
    func `a route-level 404 is reported as a generic API error`() async {
        let transport = ProviderHTTPTransportStub { request in
            (Data(#"{"detail":"Not Found"}"#.utf8), HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: "HTTP/1.1",
                headerFields: nil)!)
        }

        await #expect(throws: MakoraUsageError.apiError(404)) {
            try await MakoraUsageFetcher.fetchUsage(apiToken: "token", session: transport)
        }
    }

    @Test
    func `fetch sends bearer token to the credits endpoint`() async throws {
        let transport = ProviderHTTPTransportStub { request in
            let body = request.url?.path.contains("credits/status") == true
                ? Data(#"{"balance":3.5}"#.utf8)
                : Data(#"{"email":"user@example.com"}"#.utf8)
            return (body, Self.okResponse(for: request))
        }

        let snapshot = try await MakoraUsageFetcher.fetchUsage(apiToken: "  token-abc  ", session: transport)

        #expect(snapshot.status.balance == Decimal(string: "3.5"))
        #expect(snapshot.accountEmail == "user@example.com")
        let requests = await transport.requests()
        // Balance is required; account identity is a best-effort follow-up.
        #expect(requests.count == 2)
        #expect(requests[0].url?.absoluteString == "https://app.makora.com/api/v1/credits/status")
        #expect(requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer token-abc")
    }

    @Test
    func `fetch still reports balance when the identity probe fails`() async throws {
        let transport = ProviderHTTPTransportStub { request in
            if request.url?.path.contains("credits/status") == true {
                return (Data(#"{"balance":8}"#.utf8), Self.okResponse(for: request))
            }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: "HTTP/1.1",
                headerFields: nil)!
            return (Data(), response)
        }

        let snapshot = try await MakoraUsageFetcher.fetchUsage(apiToken: "token", session: transport)

        #expect(snapshot.status.balance == Decimal(8))
        #expect(snapshot.accountEmail == nil)
    }

    @Test
    func `fetch surfaces unknown account for a 404 response`() async {
        let transport = ProviderHTTPTransportStub { request in
            (Data(#"{"detail":"User not found"}"#.utf8), HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: "HTTP/1.1",
                headerFields: nil)!)
        }

        await #expect(throws: MakoraUsageError.unknownAccount) {
            try await MakoraUsageFetcher.fetchUsage(apiToken: "token", session: transport)
        }
    }

    @Test
    func `fetch rejects a blank token before hitting the network`() async {
        let transport = ProviderHTTPTransportStub { request in
            (Data(), Self.okResponse(for: request))
        }

        await #expect(throws: MakoraUsageError.missingCredentials) {
            try await MakoraUsageFetcher.fetchUsage(apiToken: "   ", session: transport)
        }
        let count = await transport.requests().count
        #expect(count == 0)
    }

    private static func okResponse(for request: URLRequest) -> URLResponse {
        HTTPURLResponse(
            url: request.url ?? URL(string: "https://app.makora.com")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"])!
    }
}
