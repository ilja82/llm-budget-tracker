import SwiftUI

struct UpdateNoticeView: View {
    let update: AvailableUpdate
    @Environment(UpdateViewModel.self) private var updateViewModel
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text("Version \(update.version) is available")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("You have \(update.currentVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                step(1, command: "brew update")
                step(2, command: "brew upgrade --cask llm-budget-tracker")
                step(3, text: "Quit the app.")
                step(4, text: "Start it again.")
            }
            HStack(spacing: 8) {
                Button {
                    updateViewModel.copyCommands()
                    copied = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(2))
                        copied = false
                    }
                } label: {
                    Label(copied ? "Copied" : "Copy Commands", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .controlSize(.small)
                .accessibilityHint("Copies the two brew commands to the clipboard")
                Spacer()
                Button("Dismiss") {
                    updateViewModel.dismiss()
                }
                .controlSize(.small)
                .accessibilityHint("Hides this notice until a newer version is released")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08))
        .accessibilityElement(children: .contain)
    }

    private func step(_ number: Int, command: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(number).")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Run in Terminal:")
                .font(.caption)
            Text(command)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }

    private func step(_ number: Int, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(number).")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
        }
    }
}
