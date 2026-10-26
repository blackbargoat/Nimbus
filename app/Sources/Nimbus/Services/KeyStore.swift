import Foundation

/// Keeps the Claude API key in a private file only this Mac user can read.
/// (Not the Keychain: ad-hoc signed apps get a Keychain prompt after every update.)
enum KeyStore {
    enum Name: String { case claude = "claude-key", google = "google-key" }

    private static func url(_ name: Name) -> URL {
        SessionStore.folder.deletingLastPathComponent().appendingPathComponent(name.rawValue)
    }

    static func load(_ name: Name) -> String {
        let url = url(name)
        return
(try? String(contentsOf: url, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static func save(_ key: String, as name: Name) {
        let url = url(name)
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try? FileManager.default.removeItem(at: url)
            return
        }
        FileManager.default.createFile(atPath: url.path, contents: Data(trimmed.utf8),
                                       attributes: [.posixPermissions: 0o600])
    }
}
