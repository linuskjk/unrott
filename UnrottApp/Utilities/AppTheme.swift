import SwiftUI

enum AppTheme {
    static let tint = Color(red: 0.03, green: 0.47, blue: 0.67)
    static let success = Color(red: 0.07, green: 0.61, blue: 0.33)
    static let warning = Color(red: 0.89, green: 0.57, blue: 0.13)
    static let danger = Color(red: 0.84, green: 0.29, blue: 0.24)

    static let cardRadius: CGFloat = 24

    static let border = Color.white.opacity(0.5)
    static let shadow = Color.black.opacity(0.08)

    static let appGradient = LinearGradient(
        colors: [
            Color(red: 0.92, green: 0.97, blue: 1.0),
            Color(red: 0.9, green: 0.95, blue: 0.98),
            Color(red: 0.97, green: 0.96, blue: 0.9)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let primaryGradient = LinearGradient(
        colors: [
            Color(red: 0.02, green: 0.4, blue: 0.6),
            Color(red: 0.04, green: 0.58, blue: 0.78)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
