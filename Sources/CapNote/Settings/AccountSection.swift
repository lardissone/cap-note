import SwiftUI

struct AccountSection: View {
    @Bindable var state: AppState
    @Bindable var settings: AppSettings

    @State private var isConnecting = false
    @State private var statusMessage: String?
    @State private var statusIsError = false

    var body: some View {
        GroupBox("Capacities account") {
            VStack(alignment: .leading, spacing: 12) {
                if state.spaces.isEmpty {
                    Text("Connect a Capacities space to send notes to its daily note.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(state.spaces) { space in
                        HStack {
                            Text(space.title)
                            Spacer()
                            Button("Disconnect") {
                                Task { await disconnect(space) }
                            }
                            .disabled(isConnecting)
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        Task { await connect() }
                    } label: {
                        if isConnecting {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("Waiting for Capacities…")
                            }
                        } else {
                            Text(state.spaces.isEmpty ? "Connect to Capacities" : "Add space")
                        }
                    }
                    .disabled(isConnecting)

                    if let statusMessage {
                        Label(statusMessage, systemImage: statusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.callout)
                            .foregroundStyle(statusIsError ? .red : .green)
                            .lineLimit(2)
                    }
                }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func connect() async {
        statusMessage = nil
        isConnecting = true
        defer { isConnecting = false }

        do {
            let callbackScheme = OAuthConfig.capacities.callbackScheme
            let space = try await ConnectionStore.shared.connect { url in
                try await AuthorizationSession.shared.authorize(url: url, callbackScheme: callbackScheme)
            }
            settings.selectedSpaceId = space.id
            try await state.reloadSpaces(settings: settings)
            show("Connected to \(space.title)", isError: false)
        } catch ConnectionError.cancelled {
            return
        } catch {
            show(error.localizedDescription, isError: true)
        }
    }

    private func disconnect(_ space: Space) async {
        statusMessage = nil
        do {
            try await ConnectionStore.shared.disconnect(spaceId: space.id)
            try await state.reloadSpaces(settings: settings)
            show("Disconnected \(space.title)", isError: false)
        } catch {
            try? await state.reloadSpaces(settings: settings)
            show(error.localizedDescription, isError: true)
        }
    }

    private func show(_ message: String, isError: Bool) {
        statusMessage = message
        statusIsError = isError
    }
}
