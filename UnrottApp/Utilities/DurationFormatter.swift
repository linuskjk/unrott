import Foundation

enum DurationFormatter {
    static func minutesString(_ minutes: Int) -> String {
        let clamped = max(0, minutes)
        if clamped == 1 {
            return "1 min"
        }
        return "\(clamped) mins"
    }
}
