import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Edit brain.md: who you are, how you like notes, and what Nimbus has learned.
struct BrainView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                CloudMascot(mood: .done, level: 0).frame(width: 56, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nimbus Brain").font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Teach me how you take notes. I read this every time, and I add to it after each class.")
                        .font(.system(size: 12)).foregroundStyle(Theme.inkSoft)
                }
                Spacer()
            }

            TextEditor(text: $draft)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.85)))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.sky.opacity(0.35)))

            if let note {
                Text(note).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.skyDeep)
            }

            HStack {
                Button { importFile() } label: { Label("Teach from a file", systemImage: "square.and.arrow.down") }
                    .buttonStyle(.glass)
                    .help("Add a .md or .txt file, like your notebook, a syllabus, or old notes")
                Button { NSWorkspace.shared.activateFileViewerSelecting([Brain.url]) } label: {
                    Label("Show brain.md", systemImage: "folder")
                }
                .buttonStyle(.glass)
                Button("Reset") { draft = Brain.starter }
                    .buttonStyle(.glass)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.glass)
                Button("Save") {
                    model.brain = draft
                    dismiss()
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.ink)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 720, height: 600)
        .onAppear { draft = model.brain }
    }

    private func importFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText, .plainText, .text]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        var added = 0
        for url in panel.urls {
            Brain.save(draft)
            if let updated = try? Brain.importFile(url) {
                draft = updated
                added += 1
            }
        }
        note = added > 0 ? "Learned from \(added) file\(added == 1 ? "" : "s"). Press Save to keep it." : "I couldn't read that file. Try a .md or .txt file."
    }
}
