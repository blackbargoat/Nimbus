import SwiftUI

struct AskView: View {
    var model: AppModel
    var session: ClassSession
    @State private var draft = ""

    private let starters = [
        "Explain it like I'm new",
        "What's on the test?",
        "Real-world example",
        "What did I just miss?",
    ]

    var body: some View {
        VStack(spacing: 12) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if session.chat.isEmpty { intro }
                        ForEach(session.chat) { bubble($0) }
                        if model.isAsking {
                            HStack(alignment: .bottom, spacing: 8) {
                                MascotBadge(mood: .thinking, size: 60)
                                Spacer()
                            }
                            .id("thinking")
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 8)
                }
                .scrollFade()
                .onChange(of: session.chat.count) {
                    withAnimation { proxy.scrollTo(session.chat.last?.id, anchor: .bottom) }
                }
            }

            HStack(spacing: 10) {
                TextField("Ask anything about this class...", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(Theme.body(14))
                    .lineLimit(1...4)
                    .onSubmit(send)
                Button(action: send) {
                    Glyph( "arrow.up").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 32, height: 32).background(PixelShape(step: 2).fill(Theme.ink))
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || model.isAsking)
            }
            .padding(.leading, 16).padding(.trailing, 6).padding(.vertical, 6)
            .raised(PixelShape())
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
        }
    }

    private var intro: some View {
        Card {
            HStack(spacing: 10) {
                MascotBadge(mood: .idle, size: 72)
                Text("Ask about class").font(Theme.display(22, 700)).foregroundStyle(Theme.ink)
            }
            FlowRow(starters) { text in
                Button(text) { draft = text; send() }
                    .buttonStyle(Pill())
                    .disabled(session.lines.isEmpty)
            }
        }
        .padding(.top, 6)
    }

    private func bubble(_ m: ChatMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if m.role == .user { Spacer(minLength: 80) }
            if m.role == .assistant {
                // Nimbus answers with a face: happy when he could help, worried when he couldn't.
                MascotBadge(mood: m.text.hasPrefix("I couldn't") ? .oops : .done, size: 60)
            }
            Group {
                if m.role == .user {
                    Text(m.text).font(Theme.body(14.5, 650)).foregroundStyle(.white)
                } else {
                    RichText(m.text, size: 14.5)
                }
            }
                .textSelection(.enabled)
                .padding(.horizontal, 15).padding(.vertical, 11)
                .background {
                    if m.role == .user {
                        PixelShape()
                            .fill(LinearGradient(colors: [Theme.skyDeep.mix(with: .white, by: 0.12), Theme.skyDeep],
                                                 startPoint: .top, endPoint: .bottom))
                            .shadow(color: Theme.skyDeep.opacity(0.35), radius: 10, y: 5)
                    } else {
                        Color.clear.raised(PixelShape(), lift: 0.6)
                    }
                }
            if m.role == .assistant { Spacer(minLength: 80) }
        }
        .id(m.id)
    }

    private func send() {
        let q = draft
        draft = ""
        Task { await model.ask(q) }
    }
}

/// Lays out chips left to right, wrapping onto new lines.
struct FlowRow<Item: Hashable, Cell: View>: View {
    var items: [Item]
    var cell: (Item) -> Cell
    init(_ items: [Item], @ViewBuilder cell: @escaping (Item) -> Cell) {
        self.items = items
        self.cell = cell
    }

    var body: some View {
        FlowLayout(spacing: 8) { ForEach(items, id: \.self) { cell($0) } }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 600
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width, x > 0 { x = 0; y += row + spacing; row = 0 }
            x += s.width + spacing
            row = max(row, s.height)
        }
        return CGSize(width: width, height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += row + spacing; row = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            row = max(row, s.height)
        }
    }
}
