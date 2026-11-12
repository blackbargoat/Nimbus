import Foundation

/// One finished line of speech from the class.
struct TranscriptLine: Codable, Identifiable, Hashable {
    var id = UUID()
    var text: String
    /// Seconds since the recording started.
    var at: TimeInterval
}

/// How the student wants notes written. Picked in the Notes tab.
enum NoteStyle: String, Codable, CaseIterable, Identifiable {
    case visual, bullets, short
    var id: String { rawValue }
    var label: String {
        switch self {
        case .visual: "Visual"
        case .bullets: "Bullet points"
        case .short: "Short"
        }
    }
    var symbol: String {
        switch self {
        case .visual: "point.3.connected.trianglepath.dotted"
        case .bullets: "list.bullet"
        case .short: "text.alignleft"
        }
    }
    var blurb: String {
        switch self {
        case .visual: "Chains, tables, and timelines so you can see how ideas connect."
        case .bullets: "Full bullet notes, one idea per line, with every example."
        case .short: "Just the stuff you need, in a few quick lines."
        }
    }
}

/// One block of notes. "kind" says how to draw it:
/// bullets (a list), flow (steps or cause and effect, A -> B -> C),
/// timeline (dated events), or compare (a small table).
struct NoteSection: Codable, Hashable {
    var heading: String
    var kind: String = "bullets"
    var bullets: [String] = []
    var steps: [String] = []
    var columns: [String] = []
    var rows: [[String]] = []

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        heading = try c.decodeIfPresent(String.self, forKey: .heading) ?? ""
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "bullets"
        bullets = try c.decodeIfPresent([String].self, forKey: .bullets) ?? []
        steps = try c.decodeIfPresent([String].self, forKey: .steps) ?? []
        columns = try c.decodeIfPresent([String].self, forKey: .columns) ?? []
        rows = try c.decodeIfPresent([[String]].self, forKey: .rows) ?? []
        // Fall back to a plain list when a visual block came back empty.
        if kind == "flow" || kind == "timeline", steps.isEmpty { kind = "bullets" }
        if kind == "compare", columns.isEmpty || rows.isEmpty { kind = "bullets" }
    }
}

struct KeyTerm: Codable, Hashable {
    var term: String
    var meaning: String
}

/// What Claude writes for a class. Field names match the backend's JSON schema.
struct ClassNotes: Codable, Hashable {
    var topic: String
    var summary: String
    var sections: [NoteSection]
    var keyTerms: [KeyTerm]
    var plainWords: String
    var homework: [String]
    var reviewQuestions: [String]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        topic = try c.decodeIfPresent(String.self, forKey: .topic) ?? ""
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        sections = try c.decodeIfPresent([NoteSection].self, forKey: .sections) ?? []
        keyTerms = try c.decodeIfPresent([KeyTerm].self, forKey: .keyTerms) ?? []
        plainWords = try c.decodeIfPresent(String.self, forKey: .plainWords) ?? ""
        homework = try c.decodeIfPresent([String].self, forKey: .homework) ?? []
        reviewQuestions = try c.decodeIfPresent([String].self, forKey: .reviewQuestions) ?? []
    }
}

struct ChatMessage: Codable, Identifiable, Hashable {
    enum Role: String, Codable { case user, assistant }
    var id = UUID()
    var role: Role
    var text: String
}

/// An answer Nimbus wrote when the teacher asked the class a question.
struct LiveAnswer: Codable, Identifiable, Hashable {
    var id = UUID()
    var question: String
    var answer: String = ""
    /// Seconds into the class when the question was asked.
    var at: TimeInterval
    var isDone = false
}

struct ClassSession: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var createdAt = Date()
    var duration: TimeInterval = 0
    var lines: [TranscriptLine] = []
    var notes: ClassNotes?
    var notesStyle: NoteStyle?
    var notesUpdatedAt: Date?
    /// How many transcript lines the current notes cover.
    var notesLineCount = 0
    var chat: [ChatMessage] = []
    var answers: [LiveAnswer] = []

    init(title: String) { self.title = title }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        duration = try c.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 0
        lines = try c.decodeIfPresent([TranscriptLine].self, forKey: .lines) ?? []
        notes = try c.decodeIfPresent(ClassNotes.self, forKey: .notes)
        notesStyle = try c.decodeIfPresent(NoteStyle.self, forKey: .notesStyle)
        notesUpdatedAt = try c.decodeIfPresent(Date.self, forKey: .notesUpdatedAt)
        notesLineCount = try c.decodeIfPresent(Int.self, forKey: .notesLineCount) ?? 0
        chat = try c.decodeIfPresent([ChatMessage].self, forKey: .chat) ?? []
        answers = try c.decodeIfPresent([LiveAnswer].self, forKey: .answers) ?? []
    }

    /// The last few minutes of class, for answering a question quickly.
    func recentLines(seconds: TimeInterval = 240) -> [String] {
        guard let last = lines.last?.at else { return [] }
        return lines.filter { $0.at >= last - seconds }.map { "[\(Self.clock($0.at))] \($0.text)" }
    }

    var wordCount: Int {
        lines.reduce(0) { $0 + $1.text.split(separator: " ").count }
    }

    /// The transcript split into stable blocks. Earlier blocks never change once
    /// full, which lets the backend reuse its prompt cache as class goes on.
    func transcriptChunks(linesPerChunk: Int = 40) -> [String] {
        stride(from: 0, to: lines.count, by: linesPerChunk).map { start in
            lines[start..<min(start + linesPerChunk, lines.count)]
                .map { "[\(Self.clock($0.at))] \($0.text)" }
                .joined(separator: "\n")
        }
    }

    static func clock(_ t: TimeInterval) -> String {
        let s = Int(t)
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
    }

    var displayTitle: String { notes?.topic.isEmpty == false ? notes!.topic : title }

    /// Notes as plain text with real bullets, for apps that don't take formatting.
    func plainText() -> String {
        var out = displayTitle + "\n" + createdAt.formatted(date: .long, time: .shortened) + "\n\n"
        guard let n = notes else { return out + "No notes yet.\n" }
        func list(_ title: String, _ items: [String]) {
            guard !items.isEmpty else { return }
            out += title + "\n" + items.map { "\u{2022} \($0)" }.joined(separator: "\n") + "\n\n"
        }
        list("Due", n.homework)
        if !n.summary.isEmpty { out += n.summary + "\n\n" }
        for s in n.sections {
            out += s.heading + "\n"
            switch s.kind {
            case "flow": out += s.steps.joined(separator: " \u{2192} ") + "\n"
            case "timeline": out += s.steps.map { "\u{2022} \($0)" }.joined(separator: "\n") + "\n"
            case "compare":
                out += s.columns.joined(separator: " | ") + "\n"
                out += s.rows.map { $0.joined(separator: " | ") }.joined(separator: "\n") + "\n"
            default: break
            }
            if !s.bullets.isEmpty { out += s.bullets.map { "\u{2022} \($0)" }.joined(separator: "\n") + "\n" }
            out += "\n"
        }
        list("Key terms", n.keyTerms.map { "\($0.term): \($0.meaning)" })
        if !n.plainWords.isEmpty { out += "In plain words\n\(n.plainWords)\n\n" }
        list("Quiz yourself", n.reviewQuestions)
        return out
    }

    /// Notes as simple HTML: real headings, bullets, and tables when pasted
    /// into Google Docs, Word, Pages, or Notion.
    func html() -> String {
        func e(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
        }
        func ul(_ items: [String]) -> String {
            items.isEmpty ? "" : "<ul>" + items.map { "<li>\(e($0))</li>" }.joined() + "</ul>"
        }
        var out = "<meta charset=\"utf-8\"><h1>\(e(displayTitle))</h1><p><i>\(e(createdAt.formatted(date: .long, time: .shortened)))</i></p>"
        guard let n = notes else { return out + "<p>No notes yet.</p>" }
        if !n.homework.isEmpty { out += "<h3>Due</h3>" + ul(n.homework) }
        if !n.summary.isEmpty { out += "<p>\(e(n.summary))</p>" }
        for s in n.sections {
            out += "<h2>\(e(s.heading))</h2>"
            switch s.kind {
            case "flow": out += "<p>" + s.steps.map(e).joined(separator: " &rarr; ") + "</p>"
            case "timeline": out += ul(s.steps)
            case "compare":
                out += "<table border=\"1\" cellpadding=\"6\" style=\"border-collapse:collapse\"><tr>"
                    + s.columns.map { "<th>\(e($0))</th>" }.joined() + "</tr>"
                    + s.rows.map { "<tr>" + $0.map { "<td>\(e($0))</td>" }.joined() + "</tr>" }.joined() + "</table>"
            default: break
            }
            out += ul(s.bullets)
        }
        if !n.keyTerms.isEmpty {
            out += "<h2>Key terms</h2><ul>" + n.keyTerms.map { "<li><b>\(e($0.term))</b>: \(e($0.meaning))</li>" }.joined() + "</ul>"
        }
        if !n.plainWords.isEmpty { out += "<h2>In plain words</h2><p>\(e(n.plainWords))</p>" }
        if !n.reviewQuestions.isEmpty { out += "<h2>Quiz yourself</h2>" + ul(n.reviewQuestions) }
        return out
    }
}
