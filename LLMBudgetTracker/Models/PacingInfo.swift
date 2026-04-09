import AppKit
import Foundation
import SwiftUI

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
        case .onTrack: return "On pace"
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

// MARK: - PacingStatus + Color

extension PacingStatus {
    var color: Color {
        switch self {
        case .underPace, .onTrack: return .green
        case .nearLimit:           return .orange
        case .overPace:            return .red
        case .unknown:             return Color(nsColor: .systemGray)
        }
    }

    var nsColor: NSColor {
        switch self {
        case .underPace, .onTrack: return .systemGreen
        case .nearLimit:           return .systemOrange
        case .overPace:            return .systemRed
        case .unknown:             return .systemGray
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

    var isOverBudget: Bool {
        predictedTotal > maxBudget * Thresholds.overBudgetMin
    }

    // MARK: - Pacing Thresholds

    private enum Thresholds {
        static let underPaceMax: Double  = 0.85
        static let onTrackMax: Double    = 0.95
        static let nearLimitMax: Double  = 1.05
        static let overBudgetMin: Double = 1.02
    }

    /// Estimated date when budget will be exhausted if current pace continues
    var projectedBudgetExhaustDate: Date? {
        guard isOverBudget, daysPassed > 0 else { return nil }
        let dailyRate = spend / Double(daysPassed)
        guard dailyRate > 0 else { return nil }
        let daysUntilExhausted = max(0, maxBudget - spend) / dailyRate
        return Calendar.current.date(byAdding: .day, value: max(0, Int(ceil(daysUntilExhausted))), to: Date())
    }

    /// Deterministic pacing status based on projected total vs budget
    var status: PacingStatus {
        guard maxBudget > 0 else { return .unknown }
        let ratio = predictedTotal / maxBudget
        if ratio <= Thresholds.underPaceMax  { return .underPace }
        if ratio <= Thresholds.onTrackMax    { return .onTrack }
        if ratio <= Thresholds.nearLimitMax  { return .nearLimit }
        return .overPace
    }
}
