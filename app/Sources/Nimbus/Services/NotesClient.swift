import Foundation

/// Talks to the Nimbus backend, which runs Claude and keeps the API key off this Mac.
struct NotesClient {
    enum Failure: LocalizedError {
        case server(String)
        case badURL

        var errorDescription: String? {
            switch self {
            case .server(let message): message
            case .badURL: "The server address in Settings isn't a valid link."
            }
        }
    }

    var baseURL: String

    func notes(for session: ClassSession) async throws -> ClassNotes {
        struct Body: Encodable { let title: String; let transcript: [String] }
        return try await post("api/notes", Body(title: session.title, transcript: session.transcriptChunks()))
    }

    func ask(_ question: String, in session: ClassSession) async throws -> String {
        struct Turn: Encodable { let role: String; let text: String }
        struct Body: Encodable {
            let title: String
            let transcript: [String]
            let history: [Turn]
            let question: String
        }
        struct Reply: Decodable { let answer: String }
        let body = Body(
            title: session.title,
            transcript: session.transcriptChunks(),
            history: session.chat.suffix(12).map { Turn(role: $0.role.rawValue, text: $0.text) },
            question: question
        )
        let reply: Reply = try await post("api/ask", body)
        return reply.answer
    }

    /// Streams a short answer to a question the teacher just asked.
    func answer(_ question: String, in session: ClassSession) -> AsyncThrowingStream<String, Error> {
        struct Body: Encodable {
            let title: String
            let transcript: [String]
            let question: String
            let context: String?
        }
        let body = Body(title: session.title, transcript: session.recentLines(), question: question,
                        context: session.notes?.summary)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try makeRequest("api/answer", body)
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    guard (200..<300).contains(status) else {
                        var data = Data()
                        for try await b in bytes { data.append(b) }
                        throw failure(status: status, data: data)
                    }
                    var pending = Data()
                    for try await byte in bytes {
                        pending.append(byte)
                        // Only emit complete UTF-8 characters.
                        if let text = String(data: pending, encoding: .utf8) {
                            continuation.yield(text)
                            pending.removeAll(keepingCapacity: true)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func makeRequest<B: Encodable>(_ path: String, _ body: B) throws -> URLRequest {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = URL(string: trimmed.hasSuffix("/") ? trimmed : trimmed + "/"),
              let url = URL(string: path, relativeTo: base)
        else { throw Failure.badURL }
        var request = URLRequest(url: url, timeoutInterval: 90)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Nimbus-Mac/1", forHTTPHeaderField: "X-Nimbus-Client")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func failure(status: Int, data: Data) -> Failure {
        let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
        return .server(message ?? (status == 429
            ? "Too many requests right now. Try again in a minute."
            : "The notes server had a problem (code \(status))."))
    }

    private func post<B: Encodable, R: Decodable>(_ path: String, _ body: B) async throws -> R {
        let request = try makeRequest(path, body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw failure(status: status, data: data) }
        return try JSONDecoder().decode(R.self, from: data)
    }
}

private struct ErrorBody: Decodable { let error: String }
