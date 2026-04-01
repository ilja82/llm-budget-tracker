import SwiftUI

struct PacingView: View {
    let pacing: PacingInfo

    var body: some View {
        GroupBox {
            VStack(spacing: 8) {
                StatRow(label: "Expected Use", value: String(format: "$%.2f", pacing.expectedUse))
                StatRow(label: "Actual Use", value: String(format: "$%.2f", pacing.spend))
                StatRow(label: "Predicted Total", value: String(format: "$%.2f", pacing.predictedTotal))
                pacingBadge
            }
        } label: {
            Label("Pacing", systemImage: "gauge.medium")
                .font(.caption.weight(.semibold))
        }
    }

    private var pacingBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: pacing.isOverPacing ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            Text(badgeText)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(pacing.isOverPacing ? .red : .green)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill((pacing.isOverPacing ? Color.red : Color.green).opacity(0.1))
        )
    }

    private var badgeText: String {
        let delta = abs(pacing.pacingDelta)
        if pacing.isOverPacing {
            return String(format: "Over-pacing by $%.2f — consider slowing down", delta)
        } else {
            return String(format: "Under-pacing by $%.2f — you have room to spend more", delta)
        }
    }
}