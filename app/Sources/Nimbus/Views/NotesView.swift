import SwiftUI

struct NotesView: View {
    var model: AppModel
    var session: ClassSession

    var body: some View {
        ScrollView {
            if let notes = session.notes {
                content(notes)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
            } else {
                empty
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func content(_ n: ClassNotes) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let updated = session.notesUpdatedAt {
                HStack(spacing: 6) {
                    if model.isUpdatingNotes { ProgressView().controlSize(.mini) }
                    Text(model.isUpdatingNotes ? "Updating notes" : "Updated \(updated.formatted(.relative(presentation: .named)))")
                    if session.lines.count > session.notesLineCount && !model.isUpdatingNotes {
                        Text("· \(session.lines.count - session.notesLineCount) new lines since then")
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSoft)
            }

            GlassCard(tint: Theme.sky) {
                CardTitle(symbol: "sparkles", text: "Big picture")
                if !n.topic.isEmpty {
                    Text(n.topic).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(Theme.ink)
                }
                Text(n.summary).font(.system(size: 15)).foregroundStyle(Theme.ink).textSelection(.enabled)
            }

            if !n.homework.isEmpty {
                GlassCard(tint: Theme.sun) {
                    CardTitle(symbol: "calendar.badge.exclamationmark", text: "Homework and due dates",
                              color: Color(red: 0.75, green: 0.42, blue: 0.0))
                    bullets(n.homework, symbol: "checkmark.circle")
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 16, alignment: .top)],
                      alignment: .leading, spacing: 16) {
                ForEach(n.sections, id: \.self) { section in
                    GlassCard {
                        Text(section.heading)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        bullets(section.bullets, symbol: "circle.fill", small: true)
                    }
                }
            }

            if !n.plainWords.isEmpty {
                GlassCard(tint: Theme.sky) {
                    CardTitle(symbol: "lightbulb", text: "In plain words")
                    Text(n.plainWords).font(.system(size: 15)).foregroundStyle(Theme.ink).textSelection(.enabled)
                }
            }

            if !n.keyTerms.isEmpty {
                GlassCard {
                    CardTitle(symbol: "character.book.closed", text: "Key terms")
                    ForEach(n.keyTerms, id: \.self) { term in
                        (Text(term.term).bold().foregroundStyle(Theme.skyDeep) + Text("  \(term.meaning)").foregroundStyle(Theme.ink))
                            .font(.system(size: 14))
                            .textSelection(.enabled)
                    }
                }
            }

            if !n.reviewQuestions.isEmpty {
                GlassCard {
                    CardTitle(symbol: "questionmark.bubble", text: "Quiz yourself")
                    bullets(n.reviewQuestions, symbol: "arrow.right")
                }
            }
        }
    }

    private func bullets(_ items: [String], symbol: String, small: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Image(systemName: symbol)
                        .font(.system(size: small ? 5 : 11, weight: .bold))
                        .foregroundStyle(Theme.sky)
                        .frame(width: 12)
                    Text(item)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.ink)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 14) {
            CloudMascot(mood: model.mood, level: model.level).frame(width: 130, height: 94)
            Text(session.lines.isEmpty ? "No notes yet" : "Ready when you are")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text(session.lines.isEmpty
                 ? "Press Listen and I'll start writing notes a few minutes into class."
                 : "I've heard \(session.wordCount) words so far. Notes update every \(Int(model.autoNotesMinutes)) minutes, or press Update notes.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 70)
    }
}
