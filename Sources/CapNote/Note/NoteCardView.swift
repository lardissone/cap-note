import SwiftUI

struct NoteCardView: View {
    @Bindable var state: AppState
    let settings: AppSettings
    let onSubmit: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            FlipFace(visible: state.face == .input, mirrored: false) {
                NoteInputView(
                    state: state,
                    onSubmit: onSubmit,
                    onSettingsTap: { state.face = .settings }
                )
            }
            FlipFace(visible: state.face == .settings, mirrored: true) {
                SettingsView(
                    state: state,
                    settings: settings,
                    onBack: { state.face = .input }
                )
            }
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.85), value: state.face)
        .onChange(of: state.face) { _, newFace in
            NotePanelController.shared.setPanelSizeForFace(newFace, animated: true)
        }
        .onKeyPress(.escape) {
            if state.face == .settings {
                state.face = .input
            } else {
                onClose()
            }
            return .handled
        }
        .onKeyPress(",", phases: .down) { press in
            if press.modifiers.contains(.command) {
                state.face = (state.face == .input) ? .settings : .input
                return .handled
            }
            return .ignored
        }
    }
}

private struct FlipFace<Content: View>: View {
    let visible: Bool
    let mirrored: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .opacity(visible ? 1 : 0)
            .rotation3DEffect(
                .degrees(visible ? 0 : (mirrored ? 180 : -180)),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
    }
}
