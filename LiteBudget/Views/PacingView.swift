import SwiftUI

struct PacingView: View {
    let pacing: PacingInfo

    var body: some View {
        GroupBox {
            VStack(spacing: 8) {
                StatRow(label: "Expected by today", value: String(format: "$%.2f", pacing.expectedUse))
                StatRow(label: "Spent so far", value: String(format: "$%.2f", pacing.spend))
                StatRow(label: "Projected by reset", value: String(format: "$%.2f", pacing.predictedTotal))
                pacingBadge
            }
        } label: {
            HStack(spacing: 4) {
                Label("Pacing", systemImage: "gauge.medium")
                    .font(.caption.weight(.semibold))
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .help("Expected by today assumes your budget is used evenly across the full budget cycle.")
            }
        }
    }

    private var pacingBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: pacing.status.icon)
            Text(badgeText)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(badgeColor)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(badgeColor.opacity(0.1))
        )
    }

    private var badgeColor: Color {
        switch pacing.status {
        case .underPace: return .green
        case .onTrack: return .secondary
        case .nearLimit: return .yellow
        case .overPace: return .red
        case .unknown: return .secondary
        }
    }

    private var badgeText: String {
        switch pacing.status {
        case .underPace:
            let delta = pacing.expectedUse - pacing.spend
            return String(format: "You are $%.2f under pace. At this rate, you will finish around $%.2f.", delta, pacing.predictedTotal)
        case .onTrack:
            return String(format: "You are on track. At this rate, you will finish around $%.2f.", pacing.predictedTotal)
        case .nearLimit:
            return String(format: "You are near your budget limit. At this rate, you will finish around $%.2f.", pacing.predictedTotal)
        case .overPace:
            let delta = pacing.predictedTotal - pacing.maxBudget
            return String(format: "You are over pace by $%.2f. At this rate, you will finish around $%.2f.", delta, pacing.predictedTotal)
        case .unknown:
            return "Pacing status is unavailable right now."
        }
    }
}