import SwiftUI

struct HeroHeaderView: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var badgeText: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.2))
                )

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))

                if let badgeText {
                    Text(badgeText)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                        .foregroundStyle(.white)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .fill(AppTheme.primaryGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: AppTheme.shadow, radius: 12, x: 0, y: 8)
    }
}
