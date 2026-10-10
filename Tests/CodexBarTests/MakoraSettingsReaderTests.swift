import Foundation
import Testing
@testable import CodexBarCore

@Suite(.serialized)
struct MakoraSettingsReaderTests {
    @Test
    func `environment token wins over the credential file`() throws {
        let file = try Self.makeCredentialFile(contents: "token: file-token\nuser: a@b.c\n")

        let token = MakoraSettingsReader.apiToken(
            environment: ["MAKORA_API_TOKEN": " env-token "],
            credentialFileURL: file)

        #expect(token == "env-token")
    }

    @Test
    func `credential file token is read when the environment is empty`() throws {
        let file = try Self.makeCredentialFile(contents: "token: file-token\nuser: a@b.c\n")

        let token = MakoraSettingsReader.apiToken(environment: [:], credentialFileURL: file)

        #expect(token == "file-token")
    }

    @Test
    func `quoted credential file token is unquoted`() throws {
        let file = try Self.makeCredentialFile(contents: "token: \"quoted-token\"\n")

        #expect(MakoraSettingsReader.tokenFromCredentialFile(at: file) == "quoted-token")
    }

    @Test
    func `credential file without a token yields nil`() throws {
        let file = try Self.makeCredentialFile(contents: "user: a@b.c\nroles: []\n")

        #expect(MakoraSettingsReader.tokenFromCredentialFile(at: file) == nil)
    }

    @Test
    func `missing credential file yields nil`() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("makora-missing-\(UUID().uuidString)/user")

        #expect(MakoraSettingsReader.tokenFromCredentialFile(at: url) == nil)
    }

    @Test
    func `credential file path honors the makora user file override`() {
        let url = MakoraSettingsReader.credentialFileURL(environment: ["MAKORA_USER_FILE": "~/custom/makora-user"])

        #expect(url?.path.hasSuffix("/custom/makora-user") == true)
        #expect(url?.path.hasPrefix("~") == false)
    }

    @Test
    func `token resolver prefers the environment token`() {
        let resolution = ProviderTokenResolver.makoraResolution(environment: ["MAKORA_API_TOKEN": "resolved-token"])

        #expect(resolution?.token == "resolved-token")
    }

    private static func makeCredentialFile(contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("makora-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("user")
        try contents.write(to: file, atomically: true, encoding: .utf8)
        return file
    }
}
