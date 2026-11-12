import SwiftUI

struct NotesView: View {
    var model: AppModel
    var session: ClassSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let notes = session.notes {
                    content(notes)
                } else {
                    empty
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .scrollFade()
        .scrollContentBackground(.hidden)
    }

    private func content(_ n: ClassNotes) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Card {
                if let updated = session.notesUpdatedAt {
                    HStack(spacing: 6) {
                        if model.isUpdatingNotes { ProgressView().controlSize(.mini) }
                        Glyph( "clock.arrow.circlepath")
                        Text(updated.formatted(.relative(presentation: .named)))
                    }
                    .font(Theme.body(11.5, 700)).foregroundStyle(Theme.inkSoft)
                }
                Text(n.topic.isEmpty ? session.title : n.topic)
                    .font(Theme.display(24, 700))
                    .foregroundStyle(Theme.ink)
                if !n.summary.isEmpty {
                    Text(n.summary).font(Theme.body(15.5, 500)).foregroundStyle(Theme.ink).lineSpacing(3)
                        .textSelection(.enabled)
                }
            }

            if !n.homework.isEmpty {
                Card(fill: Color(red: 1, green: 0.965, blue: 0.9)) {
                    HStack(spacing: 8) {
                        Glyph( "calendar.badge.exclamationmark").foregroundStyle(Theme.sunInk)
                        Text("Due").font(Theme.display(16, 700)).foregroundStyle(Theme.sunInk)
                    }
                    ForEach(Array(n.homework.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .firstTextBaseline, spacing: 9) {
                            Glyph( "square").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.sunInk)
                            Text(item).font(Theme.body(14.5, 600)).foregroundStyle(Theme.ink).textSelection(.enabled)
                        }
                    }
                }
            }

            // In the order the teacher taught it, each block full width so nothing sits alone.
            ForEach(Array(n.sections.enumerated()), id: \.offset) { _, section in
                SectionCard(section: section)
            }

            if !n.keyTerms.isEmpty {
                Card {
                    heading("character.book.closed.fill", "Words to know")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10, alignment: .top)],
                              alignment: .leading, spacing: 10) {
                        ForEach(n.keyTerms, id: \.self) { term in
                            TermChip(term: term)
                        }
                    }
                }
            }

            if !n.plainWords.isEmpty {
                Card(fill: Theme.skyMist) {
                    heading("lightbulb.fill", "In plain words")
                    Text(n.plainWords).font(Theme.body(15, 500)).foregroundStyle(Theme.ink).lineSpacing(3)
                        .textSelection(.enabled)
                }
            }

            if !n.reviewQuestions.isEmpty {
                Card {
                    heading("questionmark.circle.fill", "Quiz yourself")
                    ForEach(Array(n.reviewQuestions.enumerated()), id: \.offset) { i, q in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(i + 1)").font(Theme.display(13, 700)).foregroundStyle(.white)
                                .frame(width: 22, height: 22).background(PixelShape(step: 2).fill(Theme.skyDeep))
                            Text(q).font(Theme.body(14.5, 600)).foregroundStyle(Theme.ink).textSelection(.enabled)
                        }
                    }
                }
            }
        }
    }

    private func heading(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Glyph( symbol).foregroundStyle(Theme.skyDeep)
            Text(text).font(Theme.display(16, 700)).foregroundStyle(Theme.ink)
        }
    }

    private var empty: some View {
        VStack(spacing: 34) {
            CloudMascot(mood: model.mood, level: model.level).frame(width: 200, height: 160)
            HStack(spacing: 8) {
                Glyph( session.lines.isEmpty ? "mic.fill" : "text.word.spacing")
                Text(session.lines.isEmpty ? "Press the mic" : "\(session.wordCount) words heard")
            }
            .font(Theme.display(17, 700))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 16).frame(height: 38)
            .raised(PixelShape())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

/// One block of notes, drawn the way its kind asks for.
private struct SectionCard: View {
    var section: NoteSection

    var body: some View {
        Card {
            HStack(spacing: 8) {
                Glyph( symbol).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.skyDeep)
                Text(section.heading).font(Theme.display(17, 700)).foregroundStyle(Theme.ink)
            }
            switch section.kind {
            case "flow": flow
            case "timeline": timeline
            case "compare": compare
            default: EmptyView()
            }
            if !section.bullets.isEmpty { bullets }
        }
    }

    private var symbol: String {
        switch section.kind {
        case "flow": "arrow.triangle.branch"
        case "timeline": "calendar"
        case "compare": "tablecells"
        default: "circle.fill"
        }
    }

    private var bullets: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(section.bullets.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    PixelShape(step: 2).fill(Theme.sky).frame(width: 6, height: 6).offset(y: -2)
                    Text(item).font(Theme.body(14.5, 500)).foregroundStyle(Theme.ink)
                        .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// A -> B -> C as chips that wrap onto new lines.
    private var flow: some View {
        FlowLayout(spacing: 6) {
            ForEach(Array(section.steps.enumerated()), id: \.offset) { i, step in
                HStack(spacing: 6) {
                    Text(step).font(Theme.body(14, 700)).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(PixelShape().fill(Theme.skyMist))
                        .overlay(PixelShape().strokeBorder(Theme.sky.opacity(0.35)))
                    if i < section.steps.count - 1 {
                        Glyph( "arrow.right").font(.system(size: 12, weight: .heavy)).foregroundStyle(Theme.skyDeep)
                    }
                }
            }
        }
    }

    /// Dated events down a line.
    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(section.steps.enumerated()), id: \.offset) { i, step in
                let parts = step.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        PixelShape(step: 2).fill(Theme.skyDeep).frame(width: 10, height: 10).padding(.top, 5)
                        if i < section.steps.count - 1 {
                            Rectangle().fill(Theme.sky.opacity(0.35)).frame(width: 2).frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        if parts.count == 2 {
                            Text(parts[0]).font(Theme.display(13, 700)).foregroundStyle(Theme.skyDeep)
                            Text(parts[1]).font(Theme.body(14.5, 600)).foregroundStyle(Theme.ink)
                        } else {
                            Text(step).font(Theme.body(14.5, 600)).foregroundStyle(Theme.ink)
                        }
                    }
                    .textSelection(.enabled)
                    .padding(.bottom, 12)
                }
            }
        }
    }

    /// A small side-by-side table.
    private var compare: some View {
        Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                ForEach(Array(section.columns.enumerated()), id: \.offset) { _, c in
                    Text(c).font(Theme.display(14, 700)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Theme.skyDeep)
                }
            }
            ForEach(Array(section.rows.enumerated()), id: \.offset) { r, row in
                GridRow {
                    ForEach(0..<section.columns.count, id: \.self) { c in
                        Text(c < row.count ? row[c] : "")
                            .font(Theme.body(14, c == 0 ? 700 : 500))
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(r.isMultiple(of: 2) ? Color.white : Theme.skyMist.opacity(0.6))
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .clipShape(PixelShape())
        .overlay(PixelShape().strokeBorder(Theme.line))
    }
}

/// A vocab word and what it means.
private struct TermChip: View {
    var term: KeyTerm

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(term.term).font(Theme.body(13.5, 800)).foregroundStyle(Theme.skyDeep)
            Text(term.meaning).font(Theme.body(13, 500)).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(PixelShape().fill(Theme.skyMist.opacity(0.7)))
        .textSelection(.enabled)
    }
}

/// Visual, bullets, or short. Picking one rewrites the notes in that style.
struct NoteStylePicker: View {
    var model: AppModel
    @Namespace private var slide
    @State private var hover: NoteStyle?
    @State private var taps = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(NoteStyle.allCases) { style in
                let on = model.noteStyle == style
                Button {
                    taps += 1
                    withAnimation(.spring(duration: 0.35, bounce: 0.3)) { model.setNoteStyle(style) }
                } label: {
                    HStack(spacing: 6) {
                        Glyph(style.symbol, size: 16)
                            .glyphMotion(.hop, hovering: hover == style, taps: on ? taps : 0)
                        if on { Text(style.label).font(Theme.display(14, 500)).fixedSize() }
                    }
                    .foregroundStyle(on ? .white : Theme.ink)
                    .padding(.horizontal, on ? 12 : 10).frame(height: 32)
                    .background {
                        if on { PixelShape(radius: 9).fill(Theme.skyDeep).matchedGeometryEffect(id: "style", in: slide) }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hover = $0 ? style : (hover == style ? nil : hover) }
                .help(style.label + ": " + style.blurb)
            }
        }
        .padding(4)
        .raised(PixelShape(), lift: 0.7)
    }
}
