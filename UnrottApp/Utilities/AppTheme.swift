import SwiftUI

enum AppTheme {
    // Kräftigere, modernere Farben
    static let tint = Color(red: 0.11, green: 0.51, blue: 0.73) // Etwas lebendiger
    static let success = Color(red: 0.20, green: 0.72, blue: 0.50)
    static let warning = Color(red: 1.0, green: 0.65, blue: 0.0)
    static let danger = Color(red: 0.92, green: 0.34, blue: 0.34)

    static let cardRadius: CGFloat = 22

    // Kontrast-Verbesserung: Dunklere Borders für bessere Sichtbarkeit
    static let border = Color.primary.opacity(0.1)
    static let shadow = Color.black.opacity(0.05)

    // NEU: Ein professioneller Hintergrund (leichtes Grau/Blau statt hartem Weiß)
    static let backgroundColor = Color(uiColor: .systemGroupedBackground)

    // Überarbeiteter Hintergrund-Gradient (dezenter und edler)
    static let appGradient = LinearGradient(
        colors: [
            Color(red: 0.95, green: 0.97, blue: 1.0),
            Color(red: 0.98, green: 0.98, blue: 0.98)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let primaryGradient = LinearGradient(
        colors: [tint, tint.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
