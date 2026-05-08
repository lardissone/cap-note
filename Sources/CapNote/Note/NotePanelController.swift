import AppKit
import SwiftUI

enum CardFace {
    case input
    case settings
}

@MainActor
final class NotePanelController: NSObject {
    static let shared = NotePanelController()

    private var panel: NotePanel?
    private var lastInputSize: NSSize?
    private var currentPanelFace: CardFace = .input

    private let defaultInputSize = NSSize(width: 480, height: 360)
    private let inputMinSize = NSSize(width: 300, height: 200)
    private let settingsSize = NSSize(width: 520, height: 540)
    private let unboundedMaxSize = NSSize(
        width: CGFloat.greatestFiniteMagnitude,
        height: CGFloat.greatestFiniteMagnitude
    )

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

        if initialFace == .input {
            triggerEditorFocus()
        }
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
            panel.minSize = inputMinSize
            panel.maxSize = unboundedMaxSize
            panel.styleMask.insert(.resizable)
        case .settings:
            target = settingsSize
            // Loosen constraints so we can animate to the target frame even
            // when shrinking from a larger user-resized input window.
            panel.minSize = NSSize(width: 1, height: 1)
            panel.maxSize = unboundedMaxSize
        }

        let currentFrame = panel.frame
        let newFrame = NSRect(
            x: currentFrame.minX,
            y: currentFrame.maxY - target.height,
            width: target.width,
            height: target.height
        )

        if animated && currentFrame.size != target {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.4
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                ctx.allowsImplicitAnimation = true
                panel.animator().setFrame(newFrame, display: true)
            }, completionHandler: {
                Task { @MainActor in
                    self.lockSettingsSizeIfNeeded(face: face, panel: panel)
                }
            })
        } else {
            panel.setFrame(newFrame, display: true)
            lockSettingsSizeIfNeeded(face: face, panel: panel)
        }

        currentPanelFace = face
    }

    private func lockSettingsSizeIfNeeded(face: CardFace, panel: NotePanel) {
        guard face == .settings else { return }
        panel.styleMask.remove(.resizable)
        panel.minSize = settingsSize
        panel.maxSize = settingsSize
    }

    func triggerEditorFocus() {
        // Tiny delay so the panel becomes key before SwiftUI applies focus.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            AppState.shared.focusEditorTrigger &+= 1
        }
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
        let hosting = NSHostingView(rootView: card)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting

        panel.delegate = self
        return panel
    }

    private func positionPanel(_ panel: NotePanel) {
        switch AppSettings.shared.windowPosition {
        case .centered:
            panel.center()
        case .atCursor:
            positionAtCursor(panel)
        case .lastUsed:
            if let origin = AppSettings.shared.savedWindowOrigin {
                panel.setFrameOrigin(clampOriginToVisibleScreen(origin, size: panel.frame.size))
            } else {
                panel.center()
            }
        }
    }

    private func positionAtCursor(_ panel: NotePanel) {
        let cursor = NSEvent.mouseLocation
        let size = panel.frame.size
        let origin = NSPoint(
            x: cursor.x - size.width / 2,
            y: cursor.y - size.height / 2
        )
        panel.setFrameOrigin(clampOriginToVisibleScreen(origin, size: size))
    }

    private func clampOriginToVisibleScreen(_ origin: NSPoint, size: NSSize) -> NSPoint {
        let center = NSPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
        let screen = NSScreen.screens.first(where: { $0.frame.contains(center) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let bounds = screen?.visibleFrame else { return origin }

        var clamped = origin
        clamped.x = max(bounds.minX, min(clamped.x, bounds.maxX - size.width))
        clamped.y = max(bounds.minY, min(clamped.y, bounds.maxY - size.height))
        return clamped
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

extension NotePanelController: NSWindowDelegate {
    nonisolated func windowDidMove(_ notification: Notification) {
        Task { @MainActor in
            self.persistCurrentOrigin()
        }
    }

    nonisolated func windowDidResize(_ notification: Notification) {
        Task { @MainActor in
            self.persistCurrentOrigin()
        }
    }

    @MainActor
    private func persistCurrentOrigin() {
        guard let panel else { return }
        AppSettings.shared.savedWindowOrigin = panel.frame.origin
    }
}
