import SwiftUI

struct PacingView: View {
    let pacing: PacingInfo

    var body: some View {
        GroupBox {
            VStack(spacing: 10) {
                PacingComparisonBar(pacing: pacing)
                interpretationBadge
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

    private var interpretationBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: pacing.status.icon)
                .font(.caption.weight(.semibold))
            Text(interpretationText)
                .font(.caption)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .foregroundStyle(badgeColor)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(badgeColor.opacity(0.1))
        )
    }

    private var badgeColor: Color {
        switch pacing.status {
        case .underPace: return .green
        case .onTrack: return .secondary
        case .nearLimit: return .orange
        case .overPace: return .red
        case .unknown: return .secondary
        }
    }

    private var interpretationText: String {
        switch pacing.status {
        case .underPace:
            let delta = pacing.expectedUse - pacing.spend
            return String(format: "You are $%.2f under pace. Projected total: $%.2f.", delta, pacing.predictedTotal)
        case .onTrack:
            return String(format: "You are on track. Projected total: $%.2f.", pacing.predictedTotal)
        case .nearLimit:
            return String(format: "Near budget limit. Projected total: $%.2f.", pacing.predictedTotal)
        case .overPace:
            let delta = pacing.predictedTotal - pacing.maxBudget
            return String(format: "Projected $%.2f over budget.", delta)
        case .unknown:
            return "Pacing status unavailable."
        }
    }
}

// MARK: - Pacing Comparison Bar

struct PacingComparisonBar: View {
    let pacing: PacingInfo

    private var scale: Double {
        max(pacing.maxBudget, pacing.predictedTotal) * 1.08
    }

    var body: some View {
        VStack(spacing: 6) {
            Canvas { context, size in
                let w = size.width
                let barH: CGFloat = 12
                let barY: CGFloat = (size.height - barH) / 2

                func xPos(_ value: Double) -> CGFloat {
                    guard scale > 0 else { return 0 }
                    return CGFloat(min(value / scale, 1.0)) * w
                }

                // Track
                let trackRect = CGRect(x: 0, y: barY, width: w, height: barH)
                context.fill(
                    Path(roundedRect: trackRect, cornerRadius: 5),
                    with: .color(.secondary.opacity(0.15))
                )

                // Spend fill
                let spendW = max(6, xPos(pacing.spend))
                let spendRect = CGRect(x: 0, y: barY, width: spendW, height: barH)
                context.fill(
                    Path(roundedRect: spendRect, cornerRadius: 5),
                    with: .color(spendBarColor)
                )

                // Budget cap marker — shown when projected exceeds budget
                if pacing.predictedTotal > pacing.maxBudget * 1.02 {
                    let mx = xPos(pacing.maxBudget)
                    var capPath = Path()
                    capPath.move(to: CGPoint(x: mx, y: barY - 4))
                    capPath.addLine(to: CGPoint(x: mx, y: barY + barH + 4))
                    context.stroke(capPath, with: .color(.red.opacity(0.7)), lineWidth: 2)
                }

                // Expected-by-today marker
                let ex = xPos(pacing.expectedUse)
                var markerPath = Path()
                markerPath.move(to: CGPoint(x: ex, y: barY - 4))
                markerPath.addLine(to: CGPoint(x: ex, y: barY + barH + 4))
                context.stroke(markerPath, with: .color(.primary.opacity(0.45)), lineWidth: 1.5)
            }
            .frame(height: 20)

            // Legend row
            HStack(spacing: 10) {
                legendFill(color: spendBarColor, label: String(format: "Spent $%.2f", pacing.spend))
                legendLine(label: String(format: "Expected $%.2f", pacing.expectedUse))
                Spacer()
                Text(String(format: "Proj. $%.2f", pacing.predictedTotal))
                    .font(.system(size: 9))
                    .foregroundStyle(projectedColor)
            }
        }
    }

    private var spendBarColor: Color {
        switch pacing.status {
        case .underPace: return .green
        case .onTrack: return Color.accentColor
        case .nearLimit: return .orange
        case .overPace: return .red
        case .unknown: return .secondary
        }
    }

    private var projectedColor: Color {
        pacing.predictedTotal > pacing.maxBudget ? .red : .secondary
    }

    private func legendFill(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 6)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }

    private func legendLine(label: String) -> some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(Color.primary.opacity(0.45))
                .frame(width: 10, height: 1.5)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    let pacing = PacingInfo(
        spend: 45.50,
        maxBudget: 100.0,
        daysRemaining: 12,
        totalDays: 30,
        daysPassed: 18,
        expectedUse: 60.0,
        predictedTotal: 75.83
    )
    return PacingView(pacing: pacing)
        .padding()
        .frame(width: 320)
}