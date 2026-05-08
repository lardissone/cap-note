import AppKit
import SwiftUI

struct NoteInputView: View {
    @Bindable var state: AppState
    let onSubmit: () -> Void
    let onSettingsTap: () -> Void

    private static let editorPadding = EdgeInsets(top: 14, leading: 14, bottom: 8, trailing: 14)
    private static let editorFont = NSFont.systemFont(ofSize: NSFont.systemFontSize + 2)

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                PlainTextEditor(
                    text: $state.noteText,
                    font: Self.editorFont,
                    focusTrigger: state.focusEditorTrigger,
                    onSubmit: onSubmit,
                    onEscape: { handleEscape() },
                    onToggleSettings: { state.face = .settings }
                )
                .padding(Self.editorPadding)

                if state.noteText.isEmpty {
                    Text("Quick note...")
                        .font(.system(size: NSFont.systemFontSize + 2))
                        .foregroundStyle(.secondary)
                        .padding(Self.editorPadding)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
        }
    }

    private var footer: some View {
        HStack {
            statusLabel
            Spacer(minLength: 8)
            Button(action: onSettingsTap) {
                Image(systemName: "gearshape")
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Settings (⌘,)")
        }
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }

    private func handleEscape() {
        if state.face == .settings {
            state.face = .input
        } else {
            NotePanelController.shared.hidePanel()
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch state.sendStatus {
        case .idle:
            HStack(spacing: 4) {
                Image(systemName: "command")
                Text("Enter to send")
            }
            .foregroundStyle(.secondary)
        case .sending:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Sending…")
            }
            .foregroundStyle(.secondary)
        case .sent:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text("Sent")
            }
            .foregroundStyle(.green)
        case .error(let message):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(message)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .foregroundStyle(.red)
        }
    }
}
