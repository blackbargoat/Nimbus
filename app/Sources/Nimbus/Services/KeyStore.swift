import Foundation

/// Keeps the Claude API key in a private file only this Mac user can read.
/// (Not the Keychain: ad-hoc signed apps get a Keychain prompt after every update.)
enum KeyStore {
    private static let url = SessionStore.folder.deletingLastPathComponent().appendingPathComponent("claude-key")

    static func load() -> String {
        (try? String(contentsOf: url, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static func save(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try? FileManager.default.removeItem(at: url)
            return
        }
        FileManager.default.createFile(atPath: url.path, contents: Data(trimmed.utf8),
                                       attributes: [.posixPermissions: 0o600])
    }
}
