import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                CloudMascot(mood: .idle, level: 0).frame(width: 56, height: 40)
                Text("Settings").font(.system(size: 22, weight: .bold, design: .rounded))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Update notes every \(Int(model.autoNotesMinutes)) minutes while listening")
                    .font(.system(size: 13, weight: .semibold))
                Slider(value: $model.autoNotesMinutes, in: 2...15, step: 1)
            }

            Toggle(isOn: $model.liveAnswersOn) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Live answers").font(.system(size: 13, weight: .semibold))
                    Text("When your teacher asks the class a question, pop up a short answer you can use.")
                        .font(.system(size: 12)).foregroundStyle(Theme.inkSoft)
                }
            }
            .toggleStyle(.switch)

            VStack(alignment: .leading, spacing: 6) {
                Text("Notes server").font(.system(size: 13, weight: .semibold))
                TextField(AppModel.defaultServer, text: $model.serverURL)
                    .textFieldStyle(.roundedBorder)
                Button("Use default") { model.serverURL = AppModel.defaultServer }
                    .buttonStyle(.link)
            }

            GlassCard(tint: Theme.sky) {
                CardTitle(symbol: "lock.shield", text: "Privacy")
                Text("Audio never leaves your Mac. Nimbus turns speech into text on this computer, and only the text goes to the notes server when it writes notes or answers a question. Your classes are saved in your Library folder.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink)
                Text("Ask your teacher before recording a class.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }

            HStack {
                Button("Show saved classes") { NSWorkspace.shared.open(SessionStore.folder) }
                    .buttonStyle(.glass)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(26)
        .frame(width: 460)
    }
}
