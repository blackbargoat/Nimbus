import Foundation

/// One finished line of speech from the class.
struct TranscriptLine: Codable, Identifiable, Hashable {
    var id = UUID()
    var text: String
    /// Seconds since the recording started.
    var at: TimeInterval
}

struct NoteSection: Codable, Hashable {
    var heading: String
    var bullets: [String]
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

    /// Notes as Markdown, for copying into Google Docs or a notebook.
    func markdown() -> String {
        var out = "# \(notes?.topic.isEmpty == false ? notes!.topic : title)\n\n"
        out += createdAt.formatted(date: .long, time: .shortened) + "\n\n"
        guard let n = notes else { return out + "_No notes yet._\n" }
        out += "## Summary\n\(n.summary)\n\n"
        for s in n.sections {
            out += "## \(s.heading)\n" + s.bullets.map { "- \($0)" }.joined(separator: "\n") + "\n\n"
        }
        if !n.keyTerms.isEmpty {
            out += "## Key terms\n" + n.keyTerms.map { "- **\($0.term):** \($0.meaning)" }.joined(separator: "\n") + "\n\n"
        }
        if !n.plainWords.isEmpty { out += "## In plain words\n\(n.plainWords)\n\n" }
        if !n.homework.isEmpty {
            out += "## Homework and due dates\n" + n.homework.map { "- \($0)" }.joined(separator: "\n") + "\n\n"
        }
        if !n.reviewQuestions.isEmpty {
            out += "## Quiz yourself\n" + n.reviewQuestions.map { "- \($0)" }.joined(separator: "\n") + "\n"
        }
        return out
    }
}
