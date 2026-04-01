import Foundation

// MARK: - Pacing Status

enum PacingStatus {
    case underPace
    case onTrack
    case nearLimit
    case overPace
    case unknown

    var label: String {
        switch self {
        case .underPace: return "Under pace"
        case .onTrack: return "On track"
        case .nearLimit: return "Near limit"
        case .overPace: return "Over pace"
        case .unknown: return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .underPace: return "checkmark.circle.fill"
        case .onTrack: return "minus.circle.fill"
        case .nearLimit: return "exclamationmark.triangle.fill"
        case .overPace: return "exclamationmark.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Pacing Info

/// Computed pacing information derived from BudgetInfo
struct PacingInfo {
    let spend: Double
    let maxBudget: Double
    let daysRemaining: Int
    let totalDays: Int
    let daysPassed: Int
    let expectedUse: Double
    let predictedTotal: Double

    var percentageUsed: Double {
        guard maxBudget > 0 else { return 0 }
        return min(1.0, spend / maxBudget)
    }

    var isOverPacing: Bool {
        spend > expectedUse
    }

    /// Positive = over budget pace; negative = under
    var pacingDelta: Double {
        spend - expectedUse
    }

    var remainingBudget: Double {
        max(maxBudget - spend, 0)
    }

    var safeDailySpend: Double {
        let days = max(daysRemaining, 1)
        return remainingBudget / Double(days)
    }

    /// Deterministic pacing status based on projected total vs budget
    var status: PacingStatus {
        guard maxBudget > 0 else { return .unknown }
        let ratio = predictedTotal / maxBudget
        if ratio <= 0.95 { return .underPace }
        if ratio <= 1.05 { return .onTrack }
        if ratio <= 1.10 { return .nearLimit }
        return .overPace
    }
}