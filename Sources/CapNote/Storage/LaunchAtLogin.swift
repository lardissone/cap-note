import Foundation
import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp` for "launch at login".
///
/// This API requires a real `.app` bundle: in a development build run
/// straight from `swift run` it typically reports `.notFound` and the
/// register call fails. Once the project is shipped as a signed `.app`
/// the same code works without changes.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    static func enable() throws {
        try SMAppService.mainApp.register()
    }

    static func disable() throws {
        try SMAppService.mainApp.unregister()
    }
}
