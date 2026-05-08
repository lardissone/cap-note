import SwiftUI

struct SettingsView: View {
    @Bindable var state: AppState
    @Bindable var settings: AppSettings
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(spacing: 16) {
                GeneralSection(settings: settings)
                NoteFormattingSection(settings: settings)
                AccountSection(state: state, settings: settings)
            }
            .padding(20)
            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .imageScale(.medium)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Back to note (Esc)")

            Spacer()

            Text("Settings")
                .font(.headline)

            Spacer()

            // Symmetric spacer to keep the title centered.
            Color.clear.frame(width: 16, height: 16)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }
}
