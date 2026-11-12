import Foundation

/// Guesses whether a line from class is the teacher asking the class something.
/// The AI double-checks and skips anything that isn't a real question, so this
/// leans toward catching too many rather than missing one.
enum QuestionDetector {
    private static let fillers = [
        "right", "okay", "ok", "yeah", "yes", "alright", "all right", "you know", "any questions",
        "make sense", "does that make sense", "got it", "everyone ready", "can you hear me", "is that clear",
        "everybody good", "you guys good", "are we good", "ready",
    ]

    private static let cues = [
        "what do you think", "who can tell me", "can anyone", "can anybody", "can someone", "does anyone know",
        "does anybody know", "why do you think", "how would you", "what would you", "who knows", "who wants to",
        "anyone want to", "what is the difference", "what's the difference", "explain why", "how do we know",
        "what does this mean", "what does that mean", "give me an example", "who remembers", "what happens if",
        "what happens when", "can you think of", "raise your hand", "turn to your partner", "talk to your partner",
        "turn and talk", "discuss with", "what would happen", "why would", "how come", "what's an example",
        "who has an idea", "any ideas", "what do we call", "what is it called", "what's it called", "let's hear",
        "tell me why", "tell me what", "i want you to think", "think about why", "what did you get",
    ]

    /// Words a spoken question often starts with when the "?" got lost in transcription.
    private static let openers = [
        "what", "why", "who", "can", "could", "would", "should", "do", "does", "did", "is", "are", "was", "were",
    ]

    /// The question inside a line, if it has one. A finished line can hold
    /// several sentences, so each one is checked.
    static func question(in line: String) -> String? {
        let sentences = line.split(omittingEmptySubsequences: true, whereSeparator: { ".!?".contains($0) })
        // Keep the "?" so we can tell which sentences were questions.
        var out: [(String, Bool)] = []
        var rest = Substring(line)
        for s in sentences {
            guard let r = rest.range(of: s) else { continue }
            let after = rest[r.upperBound...].first
            out.append((String(s).trimmingCharacters(in: .whitespaces), after == "?"))
            rest = rest[r.upperBound...]
        }
        for (sentence, asked) in out.reversed() where isQuestion(sentence, asked: asked) {
            return sentence + (asked ? "?" : "")
        }
        return nil
    }

    static func isQuestion(_ line: String) -> Bool { question(in: line) != nil }

    private static func isQuestion(_ sentence: String, asked: Bool) -> Bool {
        let text = sentence.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        let words = text.split(separator: " ")
        guard words.count >= 4 else { return false }
        if words.count <= 7, fillers.contains(where: { text.hasSuffix($0) }) { return false }
        if asked { return true }
        if cues.contains(where: { text.contains($0) }) { return true }
        return words.count >= 5 && openers.contains(String(words[0]))
    }
}
