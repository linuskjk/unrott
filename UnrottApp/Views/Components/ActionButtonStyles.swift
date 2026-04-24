import SwiftUI

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .padding(.vertical, 13)
            .padding(.horizontal, 14)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.primaryGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.26), lineWidth: 1)
            )
            .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .padding(.vertical, 13)
            .padding(.horizontal, 14)
            .foregroundStyle(AppTheme.tint)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
            )
            .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
