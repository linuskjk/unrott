import SwiftUI

struct AppBackgroundView: View {
    var body: some View {
        ZStack {
            // Nutzt die neue Farbe aus deinem korrigierten AppTheme
            AppTheme.backgroundColor
                .ignoresSafeArea()
            
            // Ein dezenter Lichteffekt oben links
            Circle()
                .fill(AppTheme.tint.opacity(0.05))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: -150, y: -250)
        }
    }
}
