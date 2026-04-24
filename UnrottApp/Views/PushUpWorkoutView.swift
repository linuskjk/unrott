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
        guard count > 0 else {
            return 0
        }

        let remainder = count % 5
        if remainder == 0 {
            return 1
        }

        return Double(remainder) / 5.0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HeroHeaderView(
                        title: "Push-Up Unlock",
                        subtitle: "Every clean set adds extra shared time across all selected apps.",
                        systemImage: "figure.strengthtraining.traditional",
                        badgeText: "Claimable +\(claimableMinutes)m"
                    )

                    SectionCard(title: "Unlock With Push-Ups", icon: "figure.strengthtraining.traditional") {
                        Text("Every 5 valid push-ups gives +1 minute of shared app time.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack {
                            Label(detector.isRunning ? "Camera On" : "Camera Off", systemImage: detector.isRunning ? "video.fill" : "video.slash.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(detector.isRunning ? .green : .orange)
                            Spacer()
                            Text("Angle: \(Int(detector.smoothedElbowAngle))°")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: progressToNextMinute)
                                .tint(AppTheme.tint)

                            Text(repsToNextMinute == 0 ? "Minute ready to claim." : "\(repsToNextMinute) reps to next minute")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Group {
                        if detector.permissionDenied {
                            permissionDeniedView
                        } else {
                            CameraPreviewView(session: detector.session)
                                .frame(height: 320)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
                            subtitle: repsToNextMinute == 0 ? "Ready to claim" : "\(repsToNextMinute) reps to next minute"
                        )
                        StatCardView(
                            title: "Earned",
                            value: DurationFormatter.minutesString(detector.earnedMinutes),
                            color: .mint,
                            icon: "clock.badge.checkmark",
                            subtitle: "Claimable now: \(DurationFormatter.minutesString(claimableMinutes))"
                        )
                    }

                    HStack(spacing: 12) {
                        Button(detector.isRunning ? "Stop Camera" : "Start Camera") {
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
                        Label("Claim +\(claimableMinutes) min", systemImage: "gift.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(claimableMinutes == 0)

                    Text("Claimed time is added to the global pool and immediately unblocks protected apps.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(AppBackgroundView())
            .navigationTitle("Push-Up Unlock")
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                detector.stop()
            }
            .onChange(of: detector.earnedMinutes) { _, newValue in
                if claimedMinutes > newValue {
                    claimedMinutes = newValue
                }
            }
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 10) {
            Image(systemName: "camera.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Camera access is denied.")
                .font(.headline)
            Text("Enable camera permission in Settings to count push-ups.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .strokeBorder(AppTheme.border, lineWidth: 1)
        )
        .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)
    }

    private func claimEarnedTime() {
        let delta = claimableMinutes
        guard delta > 0 else {
            return
        }

        appStateManager.addEarnedMinutes(delta)
        appStateManager.setBlocked(false)
        claimedMinutes += delta

        let newState = appStateManager.state
        screenTimeManager.unblockAfterReward(using: newState)
    }
}

struct PushUpWorkoutView_Previews: PreviewProvider {
    static var previews: some View {
        let appStateManager = AppStateManager()
        let screenTimeManager = ScreenTimeManager(appStateManager: appStateManager)

        PushUpWorkoutView()
            .environmentObject(appStateManager)
            .environmentObject(screenTimeManager)
    }
}
