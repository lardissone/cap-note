import SwiftUI
import KeyboardShortcuts

struct GeneralSection: View {
    @Bindable var settings: AppSettings

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
            }
            .padding(.vertical, 6)
        }
    }
}
