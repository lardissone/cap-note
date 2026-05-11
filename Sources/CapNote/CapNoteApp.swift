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

        Task { @MainActor in
            await preloadSpaces()
        }
    }

    /// Loads the user's spaces in the background on launch so the in-note space
    /// switcher can show right away when more than one is available.
    @MainActor
    private func preloadSpaces() async {
        let settings = AppSettings.shared
        guard let token = settings.apiToken, !token.isEmpty else { return }

        let client = CapacitiesClient(token: token)
        guard let spaces = try? await client.listSpaces() else { return }

        AppState.shared.spaces = spaces
        settings.selectedSpaceId = SpaceSelection.resolve(
            spaces: spaces,
            current: settings.selectedSpaceId
        )
    }
}
