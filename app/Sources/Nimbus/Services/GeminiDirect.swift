import Foundation

/// Google Gemini with the student's own Google AI Studio key
/// (same API and models as BlackBarAI).
struct GeminiDirect {
    var apiKey: String
    var brain: String

    static let models = ["gemini-3.6-flash", "gemini-flash-latest", "gemini-3.5-flash"]
    private static let base = "https://generativelanguage.googleapis.com/v1beta/models/"

    private static let notesSchema: [String: Any] = {
        let strings: [String: Any] = ["type": "ARRAY", "items": ["type": "STRING"]]
        func object(_ props: [String: Any], order: [String]) -> [String: Any] {
            ["type": "OBJECT", "properties": props, "required": order, "propertyOrdering": order]
        }
        return object([
            "topic": ["type": "STRING"],
            "summary": ["type": "STRING"],
            "sections": ["type": "ARRAY", "items": object([
                "heading": ["type": "STRING"],
                "kind": ["type": "STRING", "enum": ["bullets", "flow", "timeline", "compare"]],
                "bullets": strings, "steps": strings, "columns": strings,
                "rows": ["type": "ARRAY", "items": strings],
            ], order: ["heading", "kind", "bullets", "steps", "columns", "rows"])],
            "keyTerms": ["type": "ARRAY", "items": object(["term": ["type": "STRING"], "meaning": ["type": "STRING"]],
                                                          order: ["term", "meaning"])],
            "plainWords": ["type": "STRING"],
            "homework": strings,
            "reviewQuestions": strings,
        ], order: ["topic", "summary", "sections", "keyTerms", "plainWords", "homework", "reviewQuestions"])
    }()

    func notes(for session: ClassSession, style: NoteStyle) async throws -> ClassNotes {
        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": Prompts.system(Prompts.notes, brain: brain, last: Prompts.style(style))]]],
            "contents": [["role": "user", "parts": [["text": Self.transcript(session) + "\n\nWrite the notes for this class."]]]],
            "generationConfig": ["responseMimeType": "application/json", "responseSchema": Self.notesSchema],
        ]
        let text = try await generate(body)
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^```(json)?", with: "", options: .regularExpression)
            .replacingOccurrences(of: "```$", with: "", options: .regularExpression)
        guard let data = cleaned.data(using: .utf8), let notes = try? JSONDecoder().decode(ClassNotes.self, from: data) else {
            throw NotesClient.Failure.server("Gemini's notes came back in a weird format. Try Update notes again.")
        }
        return notes
    }

    func ask(_ question: String, in session: ClassSession) async throws -> String {
        var contents: [[String: Any]] = [
            ["role": "user", "parts": [["text": Self.transcript(session) + "\n\nThat's my class so far. I have some questions."]]],
            ["role": "model", "parts": [["text": "Got it. What do you want to know?"]]],
        ]
        var lastRole = "model"
        let earlier = session.chat.last?.role == .user ? session.chat.dropLast() : session.chat[...]
        for turn in earlier.suffix(12) {
            let role = turn.role == .user ? "user" : "model"
            guard role != lastRole else { continue }
            contents.append(["role": role, "parts": [["text": turn.text]]])
            lastRole = role
        }
        if lastRole == "user" { contents.removeLast() }
        contents.append(["role": "user", "parts": [["text": question]]])
        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": Prompts.system(Prompts.ask, brain: brain)]]],
            "contents": contents,
        ]
        return try await generate(body).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func answer(_ question: String, in session: ClassSession, help: Bool) -> AsyncThrowingStream<String, Error> {
        var prompt = "Class: \(session.title)\n"
        if let summary = session.notes?.summary { prompt += "What the class is about so far: \(summary)\n" }
        prompt += "<recent_transcript>\n\(String(session.recentLines().joined(separator: "\n").suffix(12_000)))\n</recent_transcript>\n\n"
        prompt += help ? "Last thing I heard: \"\(question)\"" : "The teacher just asked: \"\(question)\""
        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": Prompts.system(help ? Prompts.help : Prompts.answer, brain: brain)]]],
            "contents": [["role": "user", "parts": [["text": prompt]]]],
        ]
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let bytes = try await open(body, stream: true)
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:"),
                              let data = line.dropFirst(5).trimmingCharacters(in: .whitespaces).data(using: .utf8),
                              let chunk = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                        else { continue }
                        if let error = chunk["error"] as? [String: Any] {
                            throw NotesClient.Failure.server(error["message"] as? String ?? "Gemini stopped partway through.")
                        }
                        if (chunk["promptFeedback"] as? [String: Any])?["blockReason"] != nil {
                            continuation.yield("SKIP")
                        }
                        let text = Self.text(in: chunk)
                        if !text.isEmpty { continuation.yield(text) }
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

    private static func transcript(_ session: ClassSession) -> String {
        "Class: \(session.title)\n<transcript>\n" + session.transcriptChunks().joined(separator: "\n") + "\n</transcript>"
    }

    private static func text(in response: [String: Any]) -> String {
        let candidate = (response["candidates"] as? [[String: Any]])?.first
        let parts = (candidate?["content"] as? [String: Any])?["parts"] as? [[String: Any]] ?? []
        return parts.filter { $0["thought"] as? Bool != true }.compactMap { $0["text"] as? String }.joined()
    }

    private func generate(_ body: [String: Any]) async throws -> String {
        let bytes = try await open(body, stream: false)
        var data = Data()
        for try await b in bytes { data.append(b) }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NotesClient.Failure.server("Gemini sent back something unreadable.")
        }
        if (json["promptFeedback"] as? [String: Any])?["blockReason"] != nil {
            throw NotesClient.Failure.server("Gemini wouldn't answer that one.")
        }
        let text = Self.text(in: json)
        guard !text.isEmpty else { throw NotesClient.Failure.server("Gemini sent back an empty answer. Try again.") }
        return text
    }

    /// Moves down the model list while Google says a model is busy, out of quota, or missing.
    private func open(_ body: [String: Any], stream: Bool) async throws -> URLSession.AsyncBytes {
        let payload = try JSONSerialization.data(withJSONObject: body)
        var lastError: Error = NotesClient.Failure.server("Gemini is unavailable right now.")
        for (attempt, model) in Self.models.enumerated() {
            if attempt > 0 { try await Task.sleep(for: .milliseconds(400)) }
            let path = stream ? "\(model):streamGenerateContent?alt=sse" : "\(model):generateContent"
            var request = URLRequest(url: URL(string: Self.base + path)!, timeoutInterval: 120)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
            request.httpBody = payload

            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 200 { return bytes }
            var data = Data()
            for try await b in bytes { data.append(b) }
            let message = ((try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? [String: Any])?["message"] as? String
            lastError = Self.failure(status: status, message: message)
            guard status == 404 || status == 429 || status >= 500 else { throw lastError }
        }
        throw lastError
    }

    private static func failure(status: Int, message: String?) -> NotesClient.Failure {
        switch status {
        case 400 where message?.localizedCaseInsensitiveContains("api key") == true, 401, 403:
            return .server("Your Google API key isn't working. Check it in Settings.")
        case 429:
            return .server("Gemini's free limit is used up for now. Try again later, or switch to Claude in Settings.")
        default:
            return .server(message ?? "Gemini had a problem (code \(status)).")
        }
    }
}
