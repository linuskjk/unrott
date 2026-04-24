import SwiftUI

struct PushUpWorkoutView: View {
    @EnvironmentObject private var appStateManager: AppStateManager
    @EnvironmentObject private var screenTimeManager: ScreenTimeManager
    
    @StateObject private var detector = PushUpDetector()
    @State private var claimedMinutes = 0
    
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

                    SectionCard(title: "Training Status", icon: "figure.strengthtraining.traditional") {
                        HStack {
                            Label(detector.isRunning ? "Kamera Aktiv" : "Kamera Aus", 
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

                    // KAMERA-BEREICH MIT AUTOMATISCHEM SKELETT
                    Group {
                        if detector.permissionDenied {
                            permissionDeniedView
                        } else {
                            ZStack {
                                CameraPreviewView(session: detector.session)
                                    .frame(height: 320)
                                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                
                                // Das Skelett wird jetzt immer gezeichnet, wenn die Kamera läuft
                                if detector.isRunning {
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
                                        .shadow(color: .black.opacity(0.5), radius: 2)
                                    }
                                }
                            }
                            .frame(height: 320)
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .strokeBorder(AppTheme.border, lineWidth: 1)
                            )
                            .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)
                        }
                    }

                    HStack(spacing: 12) {
                        StatCardView(
                            title: "Push-Ups",
                            value: "\(detector.pushUpCount)",
                            color: .blue,
                            icon: "flame.fill",
                            subtitle: "Gesamt heute"
                        )
                        StatCardView(
                            title: "Verdient",
                            value: "\(detector.earnedMinutes)m",
                            color: .mint,
                            icon: "clock.badge.checkmark",
                            subtitle: "Bonuszeit"
                        )
                    }

                    HStack(spacing: 12) {
                        Button(detector.isRunning ? "Stop" : "Start") {
                            if detector.isRunning {
                                detector.stop()
                            } else {
                                detector.start()
                            }
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

                    Text("Erarbeitete Zeit wird sofort dem Pool hinzugefügt.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(AppBackgroundView())
            .navigationTitle("Push-Up Training")
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                detector.stop()
            }
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 10) {
            Image(systemName: "camera.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Kamera-Zugriff verweigert")
                .font(.headline)
            Text("Bitte in den Einstellungen erlauben.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
        .background(RoundedRectangle(cornerRadius: 22).fill(.ultraThinMaterial))
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
