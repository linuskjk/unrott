import SwiftUI

struct SectionCard<Content: View>: View {
    let title: String
    var icon: String
    @ViewBuilder var content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.tint)
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
            }

            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .strokeBorder(AppTheme.border, lineWidth: 1)
        )
        .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)
        .fontDesign(.rounded)
    }
}
