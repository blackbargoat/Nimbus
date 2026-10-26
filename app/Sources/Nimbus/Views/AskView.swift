import SwiftUI

struct AskView: View {
    var model: AppModel
    var session: ClassSession
    @State private var draft = ""

    private let starters = [
        "Explain the main idea like I'm new to this",
        "What's most likely to be on the test?",
        "Give me a real-world example",
        "What did I miss in the last 5 minutes?",
    ]

    var body: some View {
        VStack(spacing: 12) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if session.chat.isEmpty { intro }
                        ForEach(session.chat) { bubble($0) }
                        if model.isAsking {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text("Thinking about your class...").font(.system(size: 13)).foregroundStyle(Theme.inkSoft)
                            }
                            .id("thinking")
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 8)
                }
                .onChange(of: session.chat.count) {
                    withAnimation { proxy.scrollTo(session.chat.last?.id, anchor: .bottom) }
                }
            }

            HStack(spacing: 10) {
                TextField("Ask anything about this class...", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .lineLimit(1...4)
                    .onSubmit(send)
                Button(action: send) {
                    Image(systemName: "arrow.up").font(.system(size: 13, weight: .bold)).frame(width: 24, height: 24)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || model.isAsking)
            }
            .padding(.leading, 16).padding(.trailing, 6).padding(.vertical, 6)
            .glassEffect(.regular.tint(.white.opacity(0.5)), in: .capsule)
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Confused about something? Ask me.")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("I answer using what your teacher actually said in this class.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft)
            FlowRow(starters) { text in
                Button(text) { draft = text; send() }
                    .buttonStyle(.glass)
                    .disabled(session.lines.isEmpty)
            }
        }
        .padding(.top, 20)
    }

    private func bubble(_ m: ChatMessage) -> some View {
        HStack {
            if m.role == .user { Spacer(minLength: 80) }
            Text(LocalizedStringKey(m.text))
                .font(.system(size: 14))
                .foregroundStyle(m.role == .user ? .white : Theme.ink)
                .textSelection(.enabled)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background {
                    if m.role == .user {
                        RoundedRectangle(cornerRadius: 18).fill(Theme.skyDeep.gradient)
                    }
                }
                .glassEffect(m.role == .user ? .identity : .regular.tint(.white.opacity(0.45)),
                             in: .rect(cornerRadius: 18))
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
