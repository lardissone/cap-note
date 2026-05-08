import SwiftUI
import KeyboardShortcuts

struct GeneralSection: View {
    @Bindable var settings: AppSettings

    @State private var launchAtLoginEnabled: Bool = LaunchAtLogin.isEnabled
    @State private var launchAtLoginError: String?

    var body: some View {
        GroupBox("General") {
            VStack(alignment: .leading, spacing: 14) {
                LabeledContent("Global shortcut") {
                    KeyboardShortcuts.Recorder(for: .openQuickNote)
                }

                Picker("Window position", selection: $settings.windowPosition) {
                    ForEach(WindowPosition.allCases) { position in
                        Text(position.localizedTitle).tag(position)
                    }
                }
                .pickerStyle(.menu)

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Launch at login", isOn: $launchAtLoginEnabled)
                        .onChange(of: launchAtLoginEnabled) { _, newValue in
                            applyLaunchAtLogin(newValue)
                        }
                    if let launchAtLoginError {
                        Text(launchAtLoginError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            launchAtLoginEnabled = LaunchAtLogin.isEnabled
        }
    }

    private func applyLaunchAtLogin(_ newValue: Bool) {
        do {
            if newValue {
                try LaunchAtLogin.enable()
            } else {
                try LaunchAtLogin.disable()
            }
            launchAtLoginError = nil
            launchAtLoginEnabled = LaunchAtLogin.isEnabled
        } catch {
            launchAtLoginError = error.localizedDescription
            launchAtLoginEnabled = LaunchAtLogin.isEnabled
        }
    }
}
