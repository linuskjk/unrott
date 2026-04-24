import SwiftUI

struct StatCardView: View {
    let title: String
    let value: String
    let color: Color
    var icon: String = "circle.fill"
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Circle()
                    .fill(color.opacity(0.25))
                    .frame(width: 12, height: 12)
            }

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(alignment: .topLeading) {
            Capsule()
                .fill(color.opacity(0.55))
                .frame(width: 44, height: 6)
                .padding(.top, 8)
                .padding(.leading, 12)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(AppTheme.border, lineWidth: 1)
        )
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 5)
        .fontDesign(.rounded)
    }
}
