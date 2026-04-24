import SwiftUI

struct PushUpWorkoutView: View {
    @EnvironmentObject private var appStateManager: AppStateManager
    @EnvironmentObject private var screenTimeManager: ScreenTimeManager
    
    @StateObject private var detector = PushUpDetector()
    @State private var claimedMinutes = 0
    @State private var showSkeleton = true // Kästchen für die Linien-Visualisierung
    
    private var claimableMinutes: Int {
        max(0, detector.earnedMinutes - claimedMinutes)
    }

    private var repsToNextMinute: Int {
        let remainder = detector.pushUpCount % 5
        return remainder == 0 ? 0 : 5 - remainder
    }

    private var progressToNextMinute: Double {
        let count = detector.pushUpCount
        guard count > 0 else { return 0 }
        let remainder = count % 5
        return remainder == 0 ? 1.0 : Double(remainder) / 5.0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HeroHeaderView(
                        title: "Push-Up Unlock",
                        subtitle: "Jeder saubere Satz schaltet Zeit für deine Apps frei.",
                        systemImage: "figure.strengthtraining.traditional",
                        badgeText: "Verfügbar +\(claimableMinutes)m"
                    )

                    SectionCard(title: "Training", icon: "figure.strengthtraining.traditional") {
                        HStack {
                            Label(detector.isRunning ? "Kamera An" : "Kamera Aus", 
                                  systemImage: detector.isRunning ? "video.fill" : "video.slash.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(detector.isRunning ? .green : .orange)
                            Spacer()
                            Text("Winkel: \(Int(detector.smoothedElbowAngle))°")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: progressToNextMinute)
                                .tint(AppTheme.tint)
                            Text(repsToNextMinute == 0 ? "Minute bereit zum Einlösen." : "Noch \(repsToNextMinute) Wiederholungen")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // KAMERA-BEREICH MIT SKELETT-OVERLAY
                    VStack(spacing: 10) {
                        if detector.permissionDenied {
                            permissionDeniedView
                        } else {
                            ZStack {
                                CameraPreviewView(session: detector.session)
                                    .frame(height: 320)
                                    .clipShape(RoundedRectangle(cornerRadius: 22))
                                
                                // Skelett zeichnen, wenn aktiv
                                if showSkeleton && detector.isRunning {
                                    GeometryReader { geo in
                                        Path { path in
                                            for line in detector.skeletonLines {
                                                let start = CGPoint(
                                                    x: line.start.x * geo.size.width,
                                                    y: (1 - line.start.y) * geo.size.height
                                                )
                                                let end = CGPoint(
                                                    x: line.end.x * geo.size.width,
                                                    y: (1 - line.end.y) * geo.size.height
                                                )
                                                path.move(to: start)
                                                path.addLine(to: end)
                                            }
                                        }
                                        .stroke(Color.green, lineWidth: 3)
                                        .shadow(radius: 2)
                                    }
                                }
                            }
                            .frame(height: 320)
                            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(AppTheme.border, lineWidth: 1))
                            .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)
                        }

                        // Das Kästchen (Toggle)
                        Toggle(isOn: $showSkeleton) {
                            Label("Linien anzeigen", systemImage: "figure.arms.open")
                                .font(.caption.weight(.bold))
                        }
                        .toggleStyle(SwitchToggleStyle(tint: AppTheme.tint))
                        .padding(.horizontal, 4)
                    }

                    HStack(spacing: 12) {
                        StatCardView(
                            title: "Push-Ups",
                            value: "\(detector.pushUpCount)",
                            color: .blue,
                            icon: "flame.fill"
                        )
                        StatCardView(
                            title: "Verdient",
                            value: "\(detector.earnedMinutes)m",
                            color: .mint,
                            icon: "clock.badge.checkmark"
                        )
                    }

                    HStack(spacing: 12) {
                        Button(detector.isRunning ? "Stop" : "Start") {
                            detector.isRunning ? detector.stop() : detector.start()
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                        .frame(maxWidth: .infinity)

                        Button("Reset") {
                            detector.resetCounters()
                            claimedMinutes = 0
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                        .frame(maxWidth: .infinity)
                    }

                    Button {
                        claimEarnedTime()
                    } label: {
                        Label("Jetzt +\(claimableMinutes) Min einlösen", systemImage: "gift.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(claimableMinutes == 0)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(AppBackgroundView())
            .navigationTitle("Workout")
            .onDisappear { detector.stop() }
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 10) {
            Image(systemName: "camera.fill").font(.largeTitle).foregroundStyle(.orange)
            Text("Kein Kamerazugriff").font(.headline)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private func claimEarnedTime() {
        let delta = claimableMinutes
        guard delta > 0 else { return }
        appStateManager.addEarnedMinutes(delta)
        appStateManager.setBlocked(false)
        claimedMinutes += delta
        screenTimeManager.unblockAfterReward(using: appStateManager.state)
    }
}
