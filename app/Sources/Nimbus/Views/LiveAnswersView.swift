import SwiftUI

struct LiveAnswersView: View {
    var model: AppModel
    var session: ClassSession
    var isLive: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Questions your teacher asked")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        Text(model.liveAnswersOn
                             ? "I listen for questions and pop up a short answer by the cloud. Missed one? Press the lightbulb."
                             : "Live answers are off. Turn them on in Settings, or press the lightbulb when you need help.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Spacer()
                    if isLive {
                        Button { model.helpMeAnswer() } label: {
                            Label("Help me answer", systemImage: "lightbulb.max.fill")
                        }
                        .buttonStyle(.glassProminent)
                        .tint(Theme.ink)
                        .disabled(model.isAnswering)
                    }
                }

                if session.answers.isEmpty {
                    GlassCard {
                        Text("No questions yet. When your teacher asks something like \u{201C}Why do you think that happened?\u{201D} the answer shows up here.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.ink)
                    }
                }

                ForEach(session.answers.reversed()) { a in
                    GlassCard {
                        HStack {
                            Text(ClassSession.clock(a.at))
                                .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(Theme.skyDeep)
                            Text("\u{201C}\(a.question)\u{201D}")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.inkSoft)
                                .lineLimit(3)
                        }
                        Text(LocalizedStringKey(a.answer))
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.ink)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
    }
}
