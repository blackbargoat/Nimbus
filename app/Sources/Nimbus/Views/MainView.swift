import SwiftUI

struct MainView: View {
    @Bindable var model: AppModel
    @State private var showSettings = false
    @State private var showBrain = false

    var body: some View {
        NavigationSplitView {
            Sidebar(model: model)
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } detail: {
            ZStack {
                Theme.backdrop.ignoresSafeArea()
                if let session = model.selected {
                    SessionDetail(model: model, session: session)
                        .id(session.id)
                } else {
                    EmptyHome(model: model)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showBrain = true } label: { Label("Brain", systemImage: "brain.head.profile") }
                    .help("Nimbus Brain: teach Nimbus how you take notes")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
                    .help("Settings")
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView(model: model) }
        .sheet(isPresented: $showBrain) { BrainView(model: model) }
        .tint(Theme.skyDeep)
    }
}

private struct Sidebar: View {
    @Bindable var model: AppModel

    var body: some View {
        List(selection: $model.selectedID) {
            Section("Your classes") {
                ForEach(model.sessions) { s in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            if model.recordingSessionID == s.id {
                                Circle().fill(Color(red: 1, green: 0.36, blue: 0.42)).frame(width: 7, height: 7)
                            }
                            Text(s.notes?.topic.isEmpty == false ? s.notes!.topic : s.title)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                        }
                        Text(s.createdAt.formatted(date: .abbreviated, time: .shortened)
                             + "  ·  " + ClassSession.clock(s.duration))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .padding(.vertical, 3)
                    .tag(s.id)
                    .contextMenu {
                        Button("Delete class", role: .destructive) { model.delete(s.id) }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                model.newSession()
            } label: {
                Label("New class", systemImage: "plus")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glass)
            .padding(12)
        }
    }
}

private struct EmptyHome: View {
    var model: AppModel

    var body: some View {
        VStack(spacing: 18) {
            CloudMascot(mood: .idle, level: 0).frame(width: 170, height: 122)
            Text("Hi, I'm Nimbus")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("Press Listen when class starts. I'll write down what your teacher says,\nturn it into bullet notes, and explain anything that didn't click.")
                .multilineTextAlignment(.center)
                .font(.system(size: 15))
                .foregroundStyle(Theme.inkSoft)
            Button {
                model.newSession()
                model.toggleRecording()
            } label: {
                Label("Start listening", systemImage: "mic.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.ink)
            .controlSize(.large)
        }
        .padding(40)
    }
}
