import SwiftUI

struct AppBackgroundView: View {
    var body: some View {
        AppTheme.appGradient
        .overlay(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 80, style: .continuous)
                .fill(Color.white.opacity(0.2))
                .frame(width: 270, height: 220)
                .rotationEffect(.degrees(18))
                .offset(x: 80, y: -96)
        }
        .overlay(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 100, style: .continuous)
                .fill(Color.white.opacity(0.2))
                .frame(width: 260, height: 220)
                .rotationEffect(.degrees(-21))
                .offset(x: -95, y: 80)
        }
        .ignoresSafeArea()
    }
}
