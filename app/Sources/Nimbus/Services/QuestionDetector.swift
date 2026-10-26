import Foundation

/// Guesses whether a line from class is the teacher asking the class something.
/// The backend double-checks and skips anything that isn't a real question.
enum QuestionDetector {
    private static let fillers = [
        "right?", "okay?", "ok?", "yeah?", "yes?", "alright?", "all right?", "you know?",
        "any questions?", "make sense?", "does that make sense?", "got it?", "everyone ready?",
        "can you hear me?", "is that clear?", "everybody good?", "you guys good?",
    ]

    private static let cues = [
        "what do you think", "who can tell me", "can anyone", "can someone", "does anyone know",
        "does anybody know", "why do you think", "how would you", "what would you", "who knows",
        "who wants to", "anyone want to", "what is the difference", "what's the difference",
        "explain why", "how do we know", "what does this mean", "what does that mean",
        "give me an example", "who remembers", "what happens if", "what happens when",
    ]

    static func isQuestion(_ line: String) -> Bool {
        let text = line.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let words = text.split(separator: " ").count
        guard words >= 4 else { return false }
        if words <= 7, fillers.contains(where: { text.hasSuffix($0) }) { return false }
        if text.hasSuffix("?") { return true }
        return cues.contains { text.contains($0) }
    }
}
