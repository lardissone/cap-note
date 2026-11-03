import AppKit

/// Personal API tokens saved by earlier versions only worked with the Capacities API that was
/// retired. Finds one, removes it, and asks the user to connect through OAuth instead.
enum CredentialsMigration {
    static let legacyAccount = "default"

    /// Returns true when a legacy token was found and removed.
    static func removeLegacyToken(from secrets: SecretStore) throws -> Bool {
        guard try secrets.read(account: legacyAccount) != nil else { return false }
        try secrets.delete(account: legacyAccount)
        return true
    }

    @MainActor
    static func runIfNeeded(settings: AppSettings) {
        var removalFailure: String?
        do {
            guard try removeLegacyToken(from: Keychain.legacyToken) else { return }
            settings.selectedSpaceId = nil
        } catch {
            NSLog("CapNote: could not remove legacy API token: \(error)")
            removalFailure = error.localizedDescription
        }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Reconnect your Capacities account"
        alert.informativeText = """
        Capacities retired the API version CapNote used until now, and API tokens pasted \
        into CapNote no longer work with it.

        Open settings and click "Connect to Capacities" to sign in and choose the space \
        your notes should go to. You can connect more than one space.
        """
        if let removalFailure {
            alert.informativeText += """


            CapNote couldn't remove the old token from the Keychain (\(removalFailure)). \
            You can delete the "io.capacities.cap-note.api-token" item in Keychain Access.
            """
        }
        alert.addButton(withTitle: "Open Settings")
        alert.runModal()

        NotePanelController.shared.showPanel(initialFace: .settings)
    }
}
