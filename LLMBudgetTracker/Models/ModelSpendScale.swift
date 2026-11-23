import Foundation

enum ModelSpendScale {
    /// Bar length of `spend` relative to the largest spend, clamped to 0...1.
    static func fraction(of spend: Double, max largest: Double) -> Double {
        guard largest > 0, spend.isFinite, largest.isFinite else { return 0 }
        return min(1, Swift.max(0, spend / largest))
    }
}
