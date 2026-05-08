import SwiftUI
import Sparkle

struct UpdatesSection: View {
    private let updater = Updater.controller.updater

    @State private var automaticallyChecks: Bool
    @State private var automaticallyDownloads: Bool

    init() {
        let updater = Updater.controller.updater
        _automaticallyChecks = State(initialValue: updater.automaticallyChecksForUpdates)
        _automaticallyDownloads = State(initialValue: updater.automaticallyDownloadsUpdates)
    }

    var body: some View {
        GroupBox("Updates") {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Automatically check for updates", isOn: $automaticallyChecks)
                    .onChange(of: automaticallyChecks) { _, newValue in
                        updater.automaticallyChecksForUpdates = newValue
                    }

                Toggle("Download updates in the background", isOn: $automaticallyDownloads)
                    .disabled(!automaticallyChecks)
                    .onChange(of: automaticallyDownloads) { _, newValue in
                        updater.automaticallyDownloadsUpdates = newValue
                    }

                HStack(spacing: 10) {
                    Button("Check for updates now") {
                        Updater.controller.checkForUpdates(nil)
                    }
                    if let lastCheck = updater.lastUpdateCheckDate {
                        Text("Last check: \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
