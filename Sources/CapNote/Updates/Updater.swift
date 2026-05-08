import Sparkle

/// Singleton wrapper around Sparkle's `SPUStandardUpdaterController`.
///
/// The controller drives the update check loop and exposes the underlying
/// `SPUUpdater` for finer-grained settings access (e.g. auto-check toggle,
/// manual `checkForUpdates(_:)`).
///
/// For the framework to actually fetch an appcast, the bundled `Info.plist`
/// must contain `SUFeedURL` and `SUPublicEDKey`. In a bare `swift run`
/// development build those keys are missing, so update checks will fail
/// gracefully — the wiring is the same once we ship a signed `.app`.
@MainActor
enum Updater {
    static let controller: SPUStandardUpdaterController = {
        SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }()
}
