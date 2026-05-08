import SwiftUI

struct NoteInputView: View {
    @Bindable var state: AppState
    let onSubmit: () -> Void
    let onSettingsTap: () -> Void

    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                if state.noteText.isEmpty {
                    Text("Quick note...")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $state.noteText)
                    .font(.title3)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .focused($editorFocused)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.thinMaterial)
        }
        .onAppear {
            editorFocused = true
        }
        .onChange(of: state.face) { _, newFace in
            if newFace == .input {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    editorFocused = true
                }
            }
        }
        .onKeyPress(.return, phases: .down) { press in
            if press.modifiers.contains(.command) {
                onSubmit()
                return .handled
            }
            return .ignored
        }
    }

    @ViewBuilder
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
