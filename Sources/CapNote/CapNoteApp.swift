import SwiftUI
import KeyboardShortcuts

@main
struct CapNoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("CapNote", systemImage: "note.text") {
            Button("New Note") {
                NotePanelController.shared.showPanel(initialFace: .input)
            }
            .keyboardShortcut("n")

            Button("Settings…") {
                NotePanelController.shared.showPanel(initialFace: .settings)
            }
            .keyboardShortcut(",")

            Divider()

            Button("Check for Updates…") {
                Updater.controller.checkForUpdates(nil)
            }

            Divider()

            Button("Quit CapNote") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        KeyboardShortcuts.onKeyDown(for: .openQuickNote) {
            Task { @MainActor in
                NotePanelController.shared.togglePanel(initialFace: .input)
            }
        }
    }
}
