import SwiftUI

struct AccountSection: View {
    @Bindable var state: AppState
    @Bindable var settings: AppSettings

    @State private var tokenInput: String = ""
    @State private var isLoading = false
    @State private var statusMessage: String?
    @State private var statusIsError = false

    var body: some View {
        GroupBox("Capacities account") {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("API token")
                        .font(.callout)
                    SecureField("Paste your Capacities API token", text: $tokenInput)
                        .textFieldStyle(.roundedBorder)
                }

                HStack(spacing: 10) {
                    Button {
                        Task { await testAndLoadSpaces() }
                    } label: {
                        if isLoading {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("Loading…")
                            }
                        } else {
                            Text("Test & Load spaces")
                        }
                    }
                    .disabled(tokenInput.isEmpty || isLoading)

                    if let statusMessage {
                        Label(statusMessage, systemImage: statusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.callout)
                            .foregroundStyle(statusIsError ? .red : .green)
                            .lineLimit(2)
                    }
                }

                if !state.spaces.isEmpty {
                    Picker("Space", selection: spaceBinding) {
                        ForEach(state.spaces) { space in
                            Text(space.title).tag(Optional(space.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            tokenInput = settings.apiToken ?? ""
        }
    }

    private var spaceBinding: Binding<String?> {
        Binding(
            get: { settings.selectedSpaceId },
            set: { settings.selectedSpaceId = $0 }
        )
    }

    private func testAndLoadSpaces() async {
        statusMessage = nil
        do {
            try settings.setApiToken(tokenInput)
        } catch {
            statusMessage = "Could not save token: \(error.localizedDescription)"
            statusIsError = true
            return
        }

        isLoading = true
        defer { isLoading = false }

        let client = CapacitiesClient(token: tokenInput)
        do {
            let spaces = try await client.listSpaces()
            state.spaces = spaces
            statusMessage = "Connected — \(spaces.count) space(s) loaded"
            statusIsError = false

            if let selected = settings.selectedSpaceId,
               !spaces.contains(where: { $0.id == selected }) {
                settings.selectedSpaceId = spaces.first?.id
            } else if settings.selectedSpaceId == nil {
                settings.selectedSpaceId = spaces.first?.id
            }
        } catch let error as CapacitiesError {
            statusMessage = error.errorDescription
            statusIsError = true
        } catch {
            statusMessage = error.localizedDescription
            statusIsError = true
        }
    }
}
