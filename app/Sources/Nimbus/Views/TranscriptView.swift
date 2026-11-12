import SwiftUI

struct TranscriptView: View {
    var model: AppModel
    var session: ClassSession
    var isLive: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if session.lines.isEmpty && !isLive {
                        Text("Nothing recorded yet.")
                            .font(Theme.body(14))
                            .foregroundStyle(Theme.inkSoft)
                            .padding(.top, 40)
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(session.lines) { line in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(ClassSession.clock(line.at))
                                .font(Theme.body(11, 750).monospacedDigit())
                                .foregroundStyle(Theme.sky)
                                .frame(width: 44, alignment: .trailing)
                            Text(line.text)
                                .font(Theme.body(14))
                                .foregroundStyle(Theme.ink)
                                .textSelection(.enabled)
                        }
                    }
                    if isLive {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Glyph( "waveform")
                                .foregroundStyle(Theme.skyDeep)
                                .symbolEffect(.variableColor.iterative, isActive: true)
                                .frame(width: 44, alignment: .trailing)
                            Text(model.partial.isEmpty ? "Listening..." : model.partial)
                                .font(Theme.body(14).italic())
                                .foregroundStyle(Theme.skyDeep)
                        }
                        .id("live")
                    }
                }
                .padding(20)
                .raised(PixelShape())
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
            .scrollFade()
            .onChange(of: session.lines.count) {
                if isLive { withAnimation { proxy.scrollTo("live", anchor: .bottom) } }
            }
        }
    }
}
