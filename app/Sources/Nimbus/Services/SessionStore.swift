import Foundation

/// Saves each class as its own JSON file in ~/Library/Application Support/Nimbus/sessions.
enum SessionStore {
    static let folder: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        // NIMBUS_HOME points a demo copy at its own folder, away from the real classes.
        let home = ProcessInfo.processInfo.environment["NIMBUS_HOME"].map { URL(fileURLWithPath: $0) }
            ?? base.appendingPathComponent("Nimbus", isDirectory: true)
        let dir = home.appendingPathComponent("sessions", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func loadAll() -> [ClassSession] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? decoder.decode(ClassSession.self, from: Data(contentsOf: $0)) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    static func save(_ session: ClassSession) {
        guard let data = try? encoder.encode(session) else { return }
        try? data.write(to: url(for: session.id), options: .atomic)
    }

    static func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: url(for: id))
    }

    private static func url(for id: UUID) -> URL {
        folder.appendingPathComponent("\(id.uuidString).json")
    }
}
