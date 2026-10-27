import Foundation

/// brain.md: what Nimbus knows about the student. They can edit it, import files
/// into it, and Nimbus adds a line after every class so it keeps learning.
enum Brain {
    static let url = SessionStore.folder.deletingLastPathComponent().appendingPathComponent("brain.md")

    static let starter = """
    # Nimbus Brain

    Nimbus reads this before every note, answer, and question. Edit anything. Nimbus adds to "What Nimbus learned" after each class.

    ## About me
    - High school student (IB Diploma, grade 11)
    - Classes: Global Politics HL (Mr. Smith), Lang and Lit HL, Spanish 3, Chemistry

    ## How to write my notes
    - Write like a real high school student, not a teacher or a textbook
    - Short bullets, one idea each. Fragments are fine
    - Simple everyday words. If there's a fancy term, keep it but explain it simply
    - Use the teacher's own examples, dates, and names
    - "=" for definitions and "->" for cause and effect are fine
    - No long paragraphs and no essay voice
    - Put anything due or on a test at the top

    ## Names and words to spell right
    - Mr. Smith (Global Politics)
    - Joseph Nye, hard power, soft power, smart power
    - Westphalian sovereignty, supranational, IGO, NGO, TNC

    ## Class materials

    ## What Nimbus learned
    """

    static func load() -> String {
        if let text = try? String(contentsOf: url, encoding: .utf8) { return text }
        save(starter)
        return starter
    }

    static func save(_ text: String) {
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Adds a file (syllabus, old notes, notebook export) under "Class materials".
    static func importFile(_ file: URL) throws -> String {
        let text = try String(contentsOf: file, encoding: .utf8)
        let block = "\n### From \(file.deletingPathExtension().lastPathComponent)\n" + String(text.prefix(12_000)) + "\n"
        return insert(block, under: "## Class materials", in: load())
    }

    /// After a class: one line so future notes know what came before.
    static func learn(from session: ClassSession) {
        guard let n = session.notes else { return }
        let date = session.createdAt.formatted(.dateTime.month(.abbreviated).day())
        let terms = n.keyTerms.prefix(6).map(\.term).joined(separator: ", ")
        var line = "- \(date), \(session.title): \(n.topic)"
        if !terms.isEmpty { line += ". Terms: \(terms)" }
        if !n.homework.isEmpty { line += ". Due: \(n.homework.joined(separator: "; "))" }
        var brain = load()
        guard !brain.contains(line) else { return }
        // New words from class go on the spelling list so future notes get them right.
        let known = brain.lowercased()
        let newTerms = n.keyTerms.map(\.term).filter { !known.contains($0.lowercased()) }
        if !newTerms.isEmpty {
            let block = newTerms.map { "- \($0)\n" }.joined()
            brain = insert(block, under: "## Names and words to spell right", in: brain)
        }
        if !brain.contains("## What Nimbus learned") { brain += "\n\n## What Nimbus learned\n" }
        brain = brain.trimmingCharacters(in: .whitespacesAndNewlines) + "\n" + line + "\n"
        save(brain)
    }

    /// Builds a brain from onboarding answers.
    static func make(grade: String, classes: [String], styles: [String], sample: String) -> String {
        var out = "# Nimbus Brain\n\nNimbus reads this before every note, answer, and question. Edit anything. Nimbus adds to it after each class.\n\n## About me\n"
        if !grade.isEmpty { out += "- \(grade)\n" }
        if !classes.isEmpty { out += "- Classes: \(classes.joined(separator: ", "))\n" }
        out += "\n## How to write my notes\n- Write like a real high school student, not a teacher or a textbook\n"
        out += styles.map { "- \($0)\n" }.joined()
        out += "- Put anything due or on a test at the top\n"
        out += "\n## Names and words to spell right\n"
        let trimmed = sample.trimmingCharacters(in: .whitespacesAndNewlines)
        out += "\n## Class materials\n"
        if !trimmed.isEmpty {
            out += "\n### Example of how I write notes (copy this style)\n" + String(trimmed.prefix(6000)) + "\n"
        }
        out += "\n## What Nimbus learned\n"
        return out
    }

    private static func insert(_ block: String, under heading: String, in brain: String) -> String {
        guard let range = brain.range(of: heading) else { return brain + "\n\n" + heading + "\n" + block }
        // Put it at the end of that section, before the next "## " heading.
        let after = brain[range.upperBound...]
        if let next = after.range(of: "\n## ") {
            var out = brain
            out.insert(contentsOf: block, at: next.lowerBound)
            return out
        }
        return brain + block
    }
}
