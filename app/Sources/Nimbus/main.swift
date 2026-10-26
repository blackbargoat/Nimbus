import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var cloud: CloudPanel?
    private var bubble: AnswerPanel?
    private let model = AppModel.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Nimbus is a bright, sky-colored app; keep it light even in Dark Mode.
        NSApp.appearance = NSAppearance(named: .aqua)
        buildMenu()
        let panel = CloudPanel(model: model) { [weak self] in self?.showMain() }
        panel.orderFrontRegardless()
        cloud = panel
        bubble = AnswerPanel(model: model)
        watchBubble()
        showMain()
    }

    /// Shows the answer bubble whenever there's a live answer, and hides it after.
    private func watchBubble() {
        withObservationTracking {
            _ = model.liveAnswer?.id
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.syncBubble()
                self?.watchBubble()
            }
        }
    }

    private func syncBubble() {
        guard let bubble, let cloud else { return }
        if model.liveAnswer != nil {
            if !bubble.isVisible { bubble.place(near: cloud.frame) }
            bubble.orderFrontRegardless()
        } else {
            // Let the closing animation play before the window goes away.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self, self.model.liveAnswer == nil else { return }
                self.bubble?.orderOut(nil)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMain()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model.isRecording else { return .terminateNow }
        Task {
            await model.stopRecording()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    @objc func showMain() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 740),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.title = "Nimbus"
            w.titlebarAppearsTransparent = true
            w.minSize = NSSize(width: 820, height: 560)
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: MainView(model: model))
            w.setFrameAutosaveName("NimbusMain")
            if !w.setFrameUsingName("NimbusMain") { w.center() }
            window = w
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func newClass() { model.newSession(); showMain() }
    @objc private func toggleListening() { model.toggleRecording() }
    @objc private func updateNotes() { Task { await model.updateNotes() } }
    @objc private func copyNotes() { model.copyNotes() }
    @objc private func helpAnswer() { model.helpMeAnswer() }

    private func buildMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let app = NSMenu()
        app.addItem(withTitle: "About Nimbus", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "Hide Nimbus", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(withTitle: "Quit Nimbus", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = app
        main.addItem(appItem)

        let fileItem = NSMenuItem()
        let file = NSMenu(title: "Class")
        file.addItem(item("New Class", #selector(newClass), "n"))
        file.addItem(item("Start or Stop Listening", #selector(toggleListening), "r"))
        file.addItem(item("Help Me Answer", #selector(helpAnswer), "j"))
        file.addItem(item("Update Notes", #selector(updateNotes), "u"))
        file.addItem(item("Copy Notes", #selector(copyNotes), "C"))
        file.addItem(.separator())
        file.addItem(item("Show Nimbus", #selector(showMain), "0"))
        file.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileItem.submenu = file
        main.addItem(fileItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        NSApp.mainMenu = main
    }

    private func item(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
}
