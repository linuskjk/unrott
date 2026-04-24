import SwiftUI
import DeviceActivity

struct DashboardView: View {
    @EnvironmentObject private var appStateManager: AppStateManager
    @EnvironmentObject private var screenTimeManager: ScreenTimeManager

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var state: SharedAppState {
        appStateManager.state
    }

    private var usageProgress: Double {
        guard state.totalAllowanceMinutes > 0 else {
            return 0
        }
        let raw = Double(state.totalUsedMinutesToday) / Double(state.totalAllowanceMinutes)
        return min(1, max(0, raw))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HeroHeaderView(
                        title: "Daily Focus Dashboard",
                        subtitle: state.isBlocked ? "Your shared limit is consumed. Earn minutes to unlock." : "You still have time available in your shared pool.",
                        systemImage: "chart.pie.fill",
                        badgeText: state.isBlocked ? "Blocked" : "Open"
                    )

                    SectionCard(title: "Usage Meter", icon: "gauge.with.dots.needle.bottom.0percent") {
                        HStack(spacing: 16) {
                            UsageRingView(
                                progress: usageProgress,
                                title: "\(state.remainingMinutes)m",
                                subtitle: "remaining",
                                tint: state.isBlocked ? AppTheme.danger : AppTheme.tint
                            )

                            VStack(alignment: .leading, spacing: 8) {
                                Text(state.isBlocked ? "Limit reached" : "Within limit")
                                    .font(.headline)
                                    .foregroundStyle(state.isBlocked ? AppTheme.danger : AppTheme.success)

                                Text("\(DurationFormatter.minutesString(state.totalUsedMinutesToday)) used of \(DurationFormatter.minutesString(state.totalAllowanceMinutes))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                ProgressView(value: usageProgress)
                                    .tint(state.isBlocked ? AppTheme.danger : AppTheme.tint)
                            }
                        }
                    }

                    SectionCard(title: "Today", icon: "clock.badge") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(state.isBlocked ? "Blocked" : "Available")
                                    .font(.headline)
                                    .foregroundStyle(state.isBlocked ? .red : .green)
                                Spacer()
                                Text("\(Int(usageProgress * 100))% used")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            ProgressView(value: usageProgress)
                                .tint(state.isBlocked ? .red : .blue)

                            Text("\(DurationFormatter.minutesString(state.totalUsedMinutesToday)) of \(DurationFormatter.minutesString(state.totalAllowanceMinutes))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        StatCardView(
                            title: "Used Today",
                            value: DurationFormatter.minutesString(state.totalUsedMinutesToday),
                            color: .orange,
                            icon: "hourglass"
                        )

                        StatCardView(
                            title: "Remaining",
                            value: DurationFormatter.minutesString(state.remainingMinutes),
                            color: state.remainingMinutes > 0 ? .green : .red,
                            icon: "gauge.with.needle"
                        )

                        StatCardView(
                            title: "Base Limit",
                            value: DurationFormatter.minutesString(state.dailyLimitMinutes),
                            color: .blue,
                            icon: "timer"
                        )

                        StatCardView(
                            title: "Earned Today",
                            value: DurationFormatter.minutesString(state.earnedMinutesToday),
                            color: .mint,
                            icon: "figure.strengthtraining.traditional"
                        )
                    }

                    SectionCard(title: "Monitor Health", icon: "waveform.path.ecg") {
                        if !state.hasSelection {
                            Label("Select apps on the Setup tab to enable shared-limit blocking.", systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        }

                        if let error = screenTimeManager.lastErrorMessage {
                            Label(error, systemImage: "xmark.octagon.fill")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        Text("Usage sync refreshes when this screen appears. You can also refresh manually.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button {
                            appStateManager.refreshFromStore()
                            screenTimeManager.syncMonitoring(with: appStateManager.state)
                        } label: {
                            Label("Refresh Usage", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)

                if state.hasSelection && screenTimeManager.authorizationStatus == .approved {
                    DeviceActivityReport(
                        SharedConstants.reportContext,
                        filter: screenTimeManager.reportFilter(for: state.selection)
                    )
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .accessibilityHidden(true)
                }
            }
            .scrollIndicators(.hidden)
            .background(AppBackgroundView())
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                appStateManager.refreshFromStore()
            }
        }
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        let appStateManager = AppStateManager()
        let screenTimeManager = ScreenTimeManager(appStateManager: appStateManager)

        DashboardView()
            .environmentObject(appStateManager)
            .environmentObject(screenTimeManager)
    }
}
