import SwiftUI

struct NoteFormattingSection: View {
    @Bindable var settings: AppSettings

    var body: some View {
        GroupBox("Note formatting") {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Use separator before each note", isOn: $settings.useSeparator)

                LabeledContent("Separator") {
                    TextField("---\\n\\n", text: separatorBinding)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!settings.useSeparator)
                        .opacity(settings.useSeparator ? 1 : 0.5)
                        .frame(maxWidth: 200)
                }

                Text("Use \\n for newline, \\t for tab.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Divider()

                Toggle("Include timestamp in daily note", isOn: $settings.includeTimestamp)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var separatorBinding: Binding<String> {
        Binding(
            get: { settings.separatorString.encodingEscapes() },
            set: { settings.separatorString = $0.decodingEscapes() }
        )
    }
}

private extension String {
    /// Converts real control characters into their printable escape sequences for display.
    func encodingEscapes() -> String {
        replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    /// Converts printable escape sequences back into real control characters for storage.
    func decodingEscapes() -> String {
        replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\t", with: "\t")
    }
}
