import Foundation

/// Calls the Claude API straight from the Mac with the student's own API key.
/// Same prompts as the web backend in web/netlify/functions.
struct ClaudeDirect {
    var apiKey: String
    var brain: String

    static let model = "claude-opus-5-5"
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    private static let notesSchema: [String: Any] = {
        func strings() -> [String: Any] { ["type": "array", "items": ["type": "string"]] }
        func object(_ props: [String: Any]) -> [String: Any] {
            ["type": "object", "additionalProperties": false, "required": Array(props.keys).sorted(), "properties": props]
        }
        return object([
            "topic": ["type": "string"],
            "summary": ["type": "string"],
            "sections": ["type": "array", "items": object([
                "heading": ["type": "string"],
                "kind": ["type": "string", "enum": ["bullets", "flow", "timeline", "compare"]],
                "bullets": strings(), "steps": strings(), "columns": strings(),
                "rows": ["type": "array", "items": strings()],
            ])],
            "keyTerms": ["type": "array", "items": object(["term": ["type": "string"], "meaning": ["type": "string"]])],
            "plainWords": ["type": "string"],
            "homework": strings(),
            "reviewQuestions": strings(),
        ])
    }()

    // MARK: Calls

    func notes(for session: ClassSession, style: NoteStyle) async throws -> ClassNotes {
        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 16000,
            "fallbacks": "default",
            "cache_control": ["type": "ephemeral"],
            "output_config": ["effort": "low", "format": ["type": "json_schema", "schema": Self.notesSchema]],
            "system": Prompts.system(Prompts.notes, brain: brain, last: Prompts.style(style)),
            "messages": [["role": "user",
                          "content": Self.transcriptBlocks(session) + [["type": "text", "text": "Write the notes for this class."]]]],
        ]
        let text = try await send(body)
        guard let data = text.data(using: .utf8) else { throw NotesClient.Failure.server("Claude sent back empty notes.") }
        return try JSONDecoder().decode(ClassNotes.self, from: data)
    }

    func ask(_ question: String, in session: ClassSession) async throws -> String {
        // The transcript sits in the first turn so it stays cached across follow-ups.
        var messages: [[String: Any]] = [
            ["role": "user", "content": Self.transcriptBlocks(session) + [["type": "text", "text": "That's my class so far. I have some questions."]]],
            ["role": "assistant", "content": "Got it. What do you want to know?"],
        ]
        var lastRole = "assistant"
        // The app has already added this question to the chat, so leave that copy out.
        let earlier = session.chat.last?.role == .user ? session.chat.dropLast() : session.chat[...]
        for turn in earlier.suffix(12) where turn.role.rawValue != lastRole {
            messages.append(["role": turn.role.rawValue, "content": turn.text])
            lastRole = turn.role.rawValue
        }
        if lastRole == "user" { messages.removeLast() }
        messages.append(["role": "user", "content": question])

        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 4000,
            "fallbacks": "default",
            "cache_control": ["type": "ephemeral"],
            "output_config": ["effort": "low"],
            "system": Prompts.system(Prompts.ask, brain: brain),
            "messages": messages,
        ]
        return try await send(body).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func answer(_ question: String, in session: ClassSession, help: Bool) -> AsyncThrowingStream<String, Error> {
        var prompt = "Class: \(session.title)\n"
        if let summary = session.notes?.summary { prompt += "What the class is about so far: \(summary)\n" }
        prompt += "<recent_transcript>\n\(String(session.recentLines().joined(separator: "\n").suffix(12_000)))\n</recent_transcript>\n\n"
        prompt += help ? "Last thing I heard: \"\(question)\"" : "The teacher just asked: \"\(question)\""
        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 2000,
            "stream": true,
            "fallbacks": "default",
            "output_config": ["effort": "low"],
            "system": Prompts.system(help ? Prompts.help : Prompts.answer, brain: brain),
            "messages": [["role": "user", "content": prompt]],
        ]
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: try request(body))
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    guard status == 200 else {
                        var data = Data()
                        for try await b in bytes { data.append(b) }
                        throw Self.failure(status: status, data: data)
                    }
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:"),
                              let data = line.dropFirst(5).trimmingCharacters(in: .whitespaces).data(using: .utf8),
                              let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                        else { continue }
                        switch event["type"] as? String {
                        case "content_block_delta":
                            if let delta = event["delta"] as? [String: Any], delta["type"] as? String == "text_delta",
                               let text = delta["text"] as? String {
                                continuation.yield(text)
                            }
                        case "message_delta":
                            if let delta = event["delta"] as? [String: Any], delta["stop_reason"] as? String == "refusal" {
                                continuation.yield("SKIP")
                            }
                        case "error":
                            let message = (event["error"] as? [String: Any])?["message"] as? String
                            throw NotesClient.Failure.server(message ?? "Claude stopped partway through.")
                        default:
                            break
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

    // MARK: Plumbing

    /// The transcript as content blocks. Earlier chunks never change, so the prompt
    /// cache keeps hitting as class goes on.
    private static func transcriptBlocks(_ session: ClassSession) -> [[String: Any]] {
        let chunks = session.transcriptChunks()
        let head = "Class: \(session.title)\n<transcript>\n"
        guard !chunks.isEmpty else { return [["type": "text", "text": head + "(nothing recorded yet)\n</transcript>"]] }
        return chunks.enumerated().map { i, chunk in
            ["type": "text", "text": (i == 0 ? head : "") + chunk + (i == chunks.count - 1 ? "\n</transcript>" : "")]
        }
    }

    private func request(_ body: [String: Any]) throws -> URLRequest {
        var r = URLRequest(url: Self.endpoint, timeoutInterval: 120)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "content-type")
        r.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        r.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        // Lets the API retry a declined request on the right fallback model.
        r.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        r.httpBody = try JSONSerialization.data(withJSONObject: body)
        return r
    }

    /// Sends a request and returns the text of the reply.
    private func send(_ body: [String: Any]) async throws -> String {
        let (data, response) = try await URLSession.shared.data(for: try request(body))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw Self.failure(status: status, data: data) }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NotesClient.Failure.server("Claude sent back something unreadable.")
        }
        switch json["stop_reason"] as? String {
        case "refusal": throw NotesClient.Failure.server("Claude couldn't help with that one.")
        case "max_tokens": throw NotesClient.Failure.server("The reply got too long. Try again.")
        default: break
        }
        let blocks = json["content"] as? [[String: Any]] ?? []
        return blocks.filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }.joined()
    }

    private static func failure(status: Int, data: Data) -> NotesClient.Failure {
        let apiMessage = ((try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? [String: Any])?["message"] as? String
        switch status {
        case 401: return .server("Your Claude API key isn't working. Check it in Settings.")
        case 402, 403: return .server(apiMessage ?? "Your Claude account can't make this request. Check your billing at console.anthropic.com.")
        case 429: return .server("Too many requests right now. Try again in a minute.")
        case 529: return .server("Claude is busy right now. Try again in a minute.")
        default: return .server(apiMessage ?? "Claude had a problem (code \(status)).")
        }
    }
}
