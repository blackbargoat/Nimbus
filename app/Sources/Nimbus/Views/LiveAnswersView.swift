import SwiftUI

struct LiveAnswersView: View {
    var model: AppModel
    var session: ClassSession
    var isLive: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Text("Teacher asked").font(Theme.display(22, 700)).foregroundStyle(Theme.ink)
                    if !model.liveAnswersOn {
                        Glyph( "bell.slash.fill").foregroundStyle(Theme.inkSoft)
                            .help("Auto answers are off (Settings). The lightbulb still works.")
                    }
                    Spacer()
                    if isLive {
                        Button { model.helpMeAnswer() } label: {
                            Glyph("lightbulb.max.fill", size: 20).font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white).frame(width: 40, height: 40)
                                .background(PixelShape(step: 2).fill(Theme.sun))
                        }
                        .buttonStyle(.plain)
                        .help("Help me answer")
                        .disabled(model.isAnswering)
                    }
                }

                if session.answers.isEmpty {
                    VStack(spacing: 12) {
                        Glyph("questionmark.bubble.fill", size: 40).font(.system(size: 34)).foregroundStyle(.white)
                        Text("No questions yet").font(Theme.display(16, 700)).foregroundStyle(Theme.ink)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 50)
                }

                ForEach(session.answers.reversed()) { a in
                    Card {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(ClassSession.clock(a.at))
                                .font(Theme.body(11.5, 800).monospacedDigit())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(PixelShape().fill(Theme.skyDeep))
                            Text(a.question)
                                .font(Theme.body(14, 700))
                                .foregroundStyle(Theme.inkSoft)
                                .lineLimit(3)
                        }
                        RichText(a.answer, size: 15)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .scrollFade()
    }
}
