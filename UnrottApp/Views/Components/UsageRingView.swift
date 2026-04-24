import SwiftUI

struct UsageRingView: View {
    let progress: Double
    let title: String
    let subtitle: String
    var tint: Color = AppTheme.tint

    private var clampedProgress: Double {
        min(1, max(0, progress))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.35), lineWidth: 11)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: 11, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 3) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .multilineTextAlignment(.center)
        }
        .frame(width: 120, height: 120)
    }
}
