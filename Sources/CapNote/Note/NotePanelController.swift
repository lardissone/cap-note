import AppKit
import SwiftUI

enum CardFace {
    case input
    case settings
}

@MainActor
final class NotePanelController {
    static let shared = NotePanelController()

    private var panel: NotePanel?
    private var lastInputSize: NSSize?
    private var currentPanelFace: CardFace = .input

    private let defaultInputSize = NSSize(width: 480, height: 360)
    private let settingsSize = NSSize(width: 520, height: 540)

    func showPanel(initialFace: CardFace) {
        AppState.shared.face = initialFace
        if AppState.shared.sendStatus == .sent {
            AppState.shared.sendStatus = .idle
        }

        let panel = panel ?? makePanel(initialFace: initialFace)
        self.panel = panel

        setPanelSizeForFace(initialFace, animated: false)
        positionPanel(panel)

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func togglePanel(initialFace: CardFace) {
        if let panel, panel.isVisible {
            hidePanel()
        } else {
            showPanel(initialFace: initialFace)
        }
    }

    func hidePanel() {
        panel?.close()
    }

    func setPanelSizeForFace(_ face: CardFace, animated: Bool) {
        guard let panel else { return }

        if face == .settings && currentPanelFace != .settings {
            lastInputSize = panel.frame.size
        }

        let target: NSSize
        switch face {
        case .input:
            target = lastInputSize ?? defaultInputSize
        case .settings:
            target = settingsSize
        }

        let currentFrame = panel.frame
        let newFrame = NSRect(
            x: currentFrame.minX,
            y: currentFrame.maxY - target.height,
            width: target.width,
            height: target.height
        )

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.4
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                ctx.allowsImplicitAnimation = true
                panel.animator().setFrame(newFrame, display: true)
            }
        } else {
            panel.setFrame(newFrame, display: true)
        }

        currentPanelFace = face
    }

    private func makePanel(initialFace: CardFace) -> NotePanel {
        let initialSize = (initialFace == .settings) ? settingsSize : defaultInputSize
        let panel = NotePanel(contentRect: NSRect(origin: .zero, size: initialSize))

        let card = NoteCardView(
            state: AppState.shared,
            settings: AppSettings.shared,
            onSubmit: { [weak self] in self?.submit() },
            onClose: { [weak self] in self?.hidePanel() }
        )
        panel.contentView = NSHostingView(rootView: card)
        return panel
    }

    private func positionPanel(_ panel: NotePanel) {
        switch AppSettings.shared.windowPosition {
        case .centered:
            panel.center()
        case .atCursor:
            positionAtCursor(panel)
        }
    }

    private func positionAtCursor(_ panel: NotePanel) {
        let cursor = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(cursor) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let bounds = screen?.visibleFrame else {
            panel.center()
            return
        }

        let size = panel.frame.size
        var origin = NSPoint(
            x: cursor.x - size.width / 2,
            y: cursor.y - size.height / 2
        )
        origin.x = max(bounds.minX, min(origin.x, bounds.maxX - size.width))
        origin.y = max(bounds.minY, min(origin.y, bounds.maxY - size.height))
        panel.setFrameOrigin(origin)
    }

    private func submit() {
        let state = AppState.shared
        let settings = AppSettings.shared

        guard state.sendStatus != .sending else { return }

        let trimmed = state.noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let token = settings.apiToken, !token.isEmpty else {
            showConfigError("Configure your API token first", state: state)
            return
        }
        guard let spaceId = settings.selectedSpaceId, !spaceId.isEmpty else {
            showConfigError("Select a space first", state: state)
            return
        }

        let payload = PayloadBuilder.buildDailyNoteRequest(
            text: state.noteText,
            spaceId: spaceId,
            useSeparator: settings.useSeparator,
            separatorString: settings.separatorString,
            includeTimestamp: settings.includeTimestamp
        )

        state.sendStatus = .sending

        Task { @MainActor in
            let client = CapacitiesClient(token: token)
            do {
                try await client.saveToDailyNote(payload)
                state.sendStatus = .sent
                try? await Task.sleep(nanoseconds: 600_000_000)
                state.noteText = ""
                state.sendStatus = .idle
                self.hidePanel()
            } catch let error as CapacitiesError {
                state.sendStatus = .error(error.errorDescription ?? "Send failed")
            } catch {
                state.sendStatus = .error(error.localizedDescription)
            }
        }
    }

    private func showConfigError(_ message: String, state: AppState) {
        state.sendStatus = .error(message)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            state.face = .settings
            state.sendStatus = .idle
        }
    }
}
