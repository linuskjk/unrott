import SwiftUI
import Combine
import FamilyControls
import DeviceActivity
import ManagedSettings
import AVFoundation
import Vision
import CoreGraphics

@available(iOS 17.0, *)
struct ContentView: View {
    @StateObject private var appStateManager: AppStateManager
    @StateObject private var screenTimeManager: ScreenTimeManager
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let stateManager = AppStateManager()
        _appStateManager = StateObject(wrappedValue: stateManager)
        _screenTimeManager = StateObject(wrappedValue: ScreenTimeManager(appStateManager: stateManager))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView {
                SetupView()
                    .tabItem {
                        Label("Setup", systemImage: "slider.horizontal.3")
                    }

                DashboardView()
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.bar.fill")
                    }

                PushUpWorkoutView()
                    .tabItem {
                        Label("Push-Ups", systemImage: "figure.strengthtraining.traditional")
                    }
            }
            .tint(Theme.tint)
            .environmentObject(appStateManager)
            .environmentObject(screenTimeManager)
            .task {
                await screenTimeManager.requestAuthorizationIfNeeded()
                appStateManager.refreshFromStore()
                screenTimeManager.syncMonitoring(with: appStateManager.state)
            }
            .onReceive(appStateManager.$state.dropFirst()) { state in
                screenTimeManager.syncMonitoring(with: state)
            }
            // Korrigierte Version für maximale Kompatibilität:
            .onChange(of: scenePhase) { newPhase in
                switch newPhase {
                case .active:
                    appStateManager.refreshFromStore()
                    screenTimeManager.refreshAuthorizationStatus()
                    screenTimeManager.syncMonitoring(with: appStateManager.state)
                case .background:
                    screenTimeManager.syncMonitoring(with: appStateManager.state)
                default:
                    break
                }
            }


            Text("UNROTT LIVE")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(.white)
                .background(Theme.primaryGradient)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                )
                .padding(.top, 8)
                .padding(.trailing, 12)
                .allowsHitTesting(false)
        }
    }
}

private enum AppConstants {
    static let appGroupIdentifier = "group.com.linuskjk.unrott"
    static let storageKey = "unrott-app-state"
    static let monitorName = DeviceActivityName("com.linuskjk.unrott.monitor")
    static let limitReachedEventName = DeviceActivityEvent.Name("com.linuskjk.unrott.limit-reached")
    static let managedSettingsStoreName = ManagedSettingsStore.Name("com.linuskjk.unrott.shield-store")
    static let reportContext = DeviceActivityReport.Context("com.linuskjk.unrott.usage-context")
}

private enum Theme {
    static let tint = Color(red: 0.03, green: 0.47, blue: 0.67)
    static let success = Color(red: 0.07, green: 0.61, blue: 0.33)
    static let warning = Color(red: 0.89, green: 0.57, blue: 0.13)
    static let danger = Color(red: 0.84, green: 0.29, blue: 0.24)
    static let cardRadius: CGFloat = 24
    static let border = Color.white.opacity(0.5)
    static let shadow = Color.black.opacity(0.08)

    static let appGradient = LinearGradient(
        colors: [
            Color(red: 0.92, green: 0.97, blue: 1.0),
            Color(red: 0.9, green: 0.95, blue: 0.98),
            Color(red: 0.97, green: 0.96, blue: 0.9)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let primaryGradient = LinearGradient(
        colors: [
            Color(red: 0.02, green: 0.4, blue: 0.6),
            Color(red: 0.04, green: 0.58, blue: 0.78)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private enum DurationFormatter {
    static func minutesString(_ minutes: Int) -> String {
        let clamped = max(0, minutes)
        return clamped == 1 ? "1 min" : "\(clamped) mins"
    }
}

private extension Date {
    static var dayIdentifier: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

private struct AppState: Codable {
    var dailyLimitMinutes: Int
    var earnedMinutesToday: Int
    var totalUsedMinutesToday: Int
    var isBlocked: Bool
    var selection: FamilyActivitySelection
    var lastResetDayIdentifier: String
    var updatedAt: Date

    init(
        dailyLimitMinutes: Int = 30,
        earnedMinutesToday: Int = 0,
        totalUsedMinutesToday: Int = 0,
        isBlocked: Bool = false,
        selection: FamilyActivitySelection = FamilyActivitySelection(),
        lastResetDayIdentifier: String = Date.dayIdentifier,
        updatedAt: Date = Date()
    ) {
        self.dailyLimitMinutes = max(1, dailyLimitMinutes)
        self.earnedMinutesToday = max(0, earnedMinutesToday)
        self.totalUsedMinutesToday = max(0, totalUsedMinutesToday)
        self.isBlocked = isBlocked
        self.selection = selection
        self.lastResetDayIdentifier = lastResetDayIdentifier
        self.updatedAt = updatedAt
        clamp()
    }

    var totalAllowanceMinutes: Int {
        max(1, dailyLimitMinutes + earnedMinutesToday)
    }

    var remainingMinutes: Int {
        max(0, totalAllowanceMinutes - totalUsedMinutesToday)
    }

    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty
    }

    mutating func resetForNewDayIfNeeded() {
        let today = Date.dayIdentifier
        guard lastResetDayIdentifier != today else {
            clamp()
            return
        }

        earnedMinutesToday = 0
        totalUsedMinutesToday = 0
        isBlocked = false
        lastResetDayIdentifier = today
        updatedAt = Date()
        clamp()
    }

    mutating func clamp() {
        dailyLimitMinutes = max(1, dailyLimitMinutes)
        earnedMinutesToday = max(0, earnedMinutesToday)
        totalUsedMinutesToday = max(0, totalUsedMinutesToday)
        if remainingMinutes > 0 && totalUsedMinutesToday < totalAllowanceMinutes {
            isBlocked = false
        }
    }
}

private final class StateStore {
    static let shared = StateStore()

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()

    private init() {
        defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
    }

    func loadState() -> AppState {
        lock.lock()
        defer { lock.unlock() }

        let decoded: AppState
        if let data = defaults.data(forKey: AppConstants.storageKey),
           let state = try? decoder.decode(AppState.self, from: data) {
            decoded = state
        } else {
            decoded = AppState()
        }

        var mutable = decoded
        mutable.resetForNewDayIfNeeded()
        persistLocked(mutable)
        return mutable
    }

    @discardableResult
    func update(_ mutate: (inout AppState) -> Void) -> AppState {
        lock.lock()
        defer { lock.unlock() }

        var state: AppState
        if let data = defaults.data(forKey: AppConstants.storageKey),
           let decoded = try? decoder.decode(AppState.self, from: data) {
            state = decoded
        } else {
            state = AppState()
        }

        state.resetForNewDayIfNeeded()
        mutate(&state)
        state.clamp()
        state.updatedAt = Date()
        persistLocked(state)
        return state
    }

    private func persistLocked(_ state: AppState) {
        guard let encoded = try? encoder.encode(state) else {
            return
        }
        defaults.set(encoded, forKey: AppConstants.storageKey)
    }
}

@MainActor
private final class AppStateManager: ObservableObject {
    @Published private(set) var state: AppState

    private let store: StateStore

    init(store: StateStore = .shared) {
        self.store = store
        self.state = store.loadState()
    }

    func refreshFromStore() {
        state = store.loadState()
    }

    func setSelection(_ selection: FamilyActivitySelection) {
        state = store.update { mutable in
            mutable.selection = selection
            mutable.isBlocked = mutable.remainingMinutes <= 0
        }
    }

    func setDailyLimitMinutes(_ minutes: Int) {
        state = store.update { mutable in
            mutable.dailyLimitMinutes = max(1, minutes)
            mutable.isBlocked = mutable.remainingMinutes <= 0
        }
    }

    func addEarnedMinutes(_ minutes: Int) {
        guard minutes > 0 else {
            return
        }
        state = store.update { mutable in
            mutable.earnedMinutesToday += minutes
            mutable.isBlocked = false
        }
    }

    func setBlocked(_ blocked: Bool) {
        state = store.update { mutable in
            mutable.isBlocked = blocked
        }
    }
}

@MainActor
private final class ScreenTimeManager: ObservableObject {
    @Published private(set) var authorizationStatus: AuthorizationStatus
    @Published var isAuthorizing = false
    @Published var lastErrorMessage: String?

    private let activityCenter = DeviceActivityCenter()
    private let managedStore = ManagedSettingsStore(named: AppConstants.managedSettingsStoreName)
    private let calendar = Calendar.current

    init(appStateManager _: AppStateManager) {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    func requestAuthorizationIfNeeded() async {
        refreshAuthorizationStatus()
        guard authorizationStatus != .approved else {
            return
        }

        isAuthorizing = true
        defer { isAuthorizing = false }

        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refreshAuthorizationStatus()
            lastErrorMessage = nil
        } catch {
            refreshAuthorizationStatus()
            lastErrorMessage = "Authorization failed: \(error.localizedDescription)"
        }
    }

func syncMonitoring(with state: AppState) {
    refreshAuthorizationStatus()

    guard authorizationStatus == .approved else {
        stopMonitoringAndClearShield()
        return
    }

    guard state.hasSelection else {
        stopMonitoringAndClearShield()
        return
    }

    let schedule = DeviceActivitySchedule(
        intervalStart: DateComponents(hour: 0, minute: 0),
        intervalEnd: DateComponents(hour: 23, minute: 59),
        repeats: true,
        warningTime: DateComponents(minute: 1)
    )

    let thresholdMinutes = max(1, state.totalAllowanceMinutes)
    
    // Fix: DeviceActivityEvent ab iOS 17.4 vs. ältere Versionen
    let event: DeviceActivityEvent
    if #available(iOS 17.4, *) {
        event = DeviceActivityEvent(
            applications: state.selection.applicationTokens,
            categories: state.selection.categoryTokens,
            webDomains: state.selection.webDomainTokens,
            threshold: DateComponents(minute: thresholdMinutes),
            includesPastActivity: true
        )
    } else {
        // Fallback für iOS 17.0 - 17.3
        event = DeviceActivityEvent(
            applications: state.selection.applicationTokens,
            categories: state.selection.categoryTokens,
            webDomains: state.selection.webDomainTokens,
            threshold: DateComponents(minute: thresholdMinutes)
        )
    }

    do {
        activityCenter.stopMonitoring([AppConstants.monitorName])
        try activityCenter.startMonitoring(
            AppConstants.monitorName,
            during: schedule,
            events: [AppConstants.limitReachedEventName: event]
        )
        lastErrorMessage = nil
    } catch {
        lastErrorMessage = "Monitoring failed: \(error.localizedDescription)"
    }

    if state.isBlocked || state.remainingMinutes <= 0 {
        applyShield(for: state.selection)
    } else {
        clearShield()
    }
}


    func unblockAfterReward(using state: AppState) {
        clearShield()
        syncMonitoring(with: state)
    }

    func stopMonitoringAndClearShield() {
        activityCenter.stopMonitoring([AppConstants.monitorName])
        clearShield()
    }

    func reportFilter(for selection: FamilyActivitySelection) -> DeviceActivityFilter {
        let interval = DateInterval(start: calendar.startOfDay(for: Date()), end: Date())

        return DeviceActivityFilter(
            segment: .daily(during: interval),
            users: .all,
            devices: .all,
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens
        )
    }

    private func applyShield(for selection: FamilyActivitySelection) {
        managedStore.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        managedStore.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens

        if selection.categoryTokens.isEmpty {
            managedStore.shield.applicationCategories = nil
            managedStore.shield.webDomainCategories = nil
            return
        }

        managedStore.shield.applicationCategories = .specific(
            selection.categoryTokens,
            except: Set<ApplicationToken>()
        )
        managedStore.shield.webDomainCategories = .specific(
            selection.categoryTokens,
            except: Set<WebDomainToken>()
        )
    }

    private func clearShield() {
        managedStore.shield.applications = nil
        managedStore.shield.applicationCategories = nil
        managedStore.shield.webDomains = nil
        managedStore.shield.webDomainCategories = nil
    }
}

private struct AppBackgroundView: View {
    var body: some View {
        Theme.appGradient
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

private struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
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
                    .foregroundStyle(Theme.tint)
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
            }

            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
        .shadow(color: Theme.shadow, radius: 10, x: 0, y: 6)
        .fontDesign(.rounded)
    }
}

private struct StatCardView: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    let subtitle: String?

    init(title: String, value: String, color: Color, icon: String = "circle.fill", subtitle: String? = nil) {
        self.title = title
        self.value = value
        self.color = color
        self.icon = icon
        self.subtitle = subtitle
    }

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
                .strokeBorder(Theme.border, lineWidth: 1)
        )
        .shadow(color: Theme.shadow, radius: 8, x: 0, y: 5)
        .fontDesign(.rounded)
    }
}

private struct HeroHeaderView: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let badgeText: String?

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
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(Theme.primaryGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: Theme.shadow, radius: 12, x: 0, y: 8)
    }
}

private struct UsageRingView: View {
    let progress: Double
    let title: String
    let subtitle: String
    let tint: Color

    init(progress: Double, title: String, subtitle: String, tint: Color = Theme.tint) {
        self.progress = min(1, max(0, progress))
        self.title = title
        self.subtitle = subtitle
        self.tint = tint
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.35), lineWidth: 11)

            Circle()
                .trim(from: 0, to: progress)
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

private struct SetupView: View {
    @EnvironmentObject private var appStateManager: AppStateManager
    @EnvironmentObject private var screenTimeManager: ScreenTimeManager
    @State private var isPickerPresented = false

    private var setupProgress: Double {
        var completed = 0
        if screenTimeManager.authorizationStatus == .approved {
            completed += 1
        }
        if appStateManager.state.hasSelection {
            completed += 1
        }
        if appStateManager.state.dailyLimitMinutes > 0 {
            completed += 1
        }
        return Double(completed) / 3.0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HeroHeaderView(
                        title: "Set Your Daily Guardrails",
                        subtitle: "Choose protected apps, then lock in one shared limit for all of them.",
                        systemImage: "shield.checkered",
                        badgeText: "Setup \(Int(setupProgress * 100))%"
                    )

                    SectionCard(title: "Authorization", icon: "lock.shield") {
                        HStack {
                            Label("Status", systemImage: "checkmark.shield")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(authorizationText)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(screenTimeManager.authorizationStatus == .approved ? Theme.success : Theme.warning)
                        }

                        Button {
                            Task {
                                await screenTimeManager.requestAuthorizationIfNeeded()
                            }
                        } label: {
                            if screenTimeManager.isAuthorizing {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Label("Request Screen Time Access", systemImage: "hand.tap.fill")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(screenTimeManager.authorizationStatus == .approved || screenTimeManager.isAuthorizing)
                    }

                    SectionCard(title: "Shared Daily Limit", icon: "timer") {
                        HStack {
                            Text("Current")
                                .font(.subheadline)
                            Spacer()
                            Text(DurationFormatter.minutesString(appStateManager.state.dailyLimitMinutes))
                                .font(.headline)
                        }

                        Stepper(value: dailyLimitBinding, in: 1...300, step: 1) {
                            Text("Adjust limit")
                                .font(.subheadline)
                        }

                        Text("All selected apps use this one combined pool.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    SectionCard(title: "Protected Apps", icon: "app.badge") {
                        Button {
                            isPickerPresented = true
                        } label: {
                            Label("Choose Apps", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Text(selectionSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if !appStateManager.state.hasSelection {
                            Label("Pick at least one app to activate blocking.", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)

                if appStateManager.state.hasSelection && screenTimeManager.authorizationStatus == .approved {
                    DeviceActivityReport(
                        AppConstants.reportContext,
                        filter: screenTimeManager.reportFilter(for: appStateManager.state.selection)
                    )
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .accessibilityHidden(true)
                }

            }
            .scrollIndicators(.hidden)
            .background(AppBackgroundView())
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isPickerPresented) {
                NavigationStack {
                    FamilyActivityPicker(selection: selectionBinding)
                        .navigationTitle("Select Apps")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    isPickerPresented = false
                                }
                            }
                        }
                }
            }
        }
    }

    private var selectionBinding: Binding<FamilyActivitySelection> {
        Binding(
            get: { appStateManager.state.selection },
            set: { appStateManager.setSelection($0) }
        )
    }

    private var dailyLimitBinding: Binding<Int> {
        Binding(
            get: { appStateManager.state.dailyLimitMinutes },
            set: { appStateManager.setDailyLimitMinutes($0) }
        )
    }

    private var selectionSummary: String {
        let apps = appStateManager.state.selection.applicationTokens.count
        let categories = appStateManager.state.selection.categoryTokens.count
        let domains = appStateManager.state.selection.webDomainTokens.count
        return "Selected: \(apps) apps, \(categories) categories, \(domains) domains"
    }

    private var authorizationText: String {
        switch screenTimeManager.authorizationStatus {
        case .approved:
            return "Approved"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not Determined"
        @unknown default:
            return "Unknown"
        }
    }
}

private struct DashboardView: View {
    @EnvironmentObject private var appStateManager: AppStateManager
    @EnvironmentObject private var screenTimeManager: ScreenTimeManager

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var state: AppState {
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
                                tint: state.isBlocked ? Theme.danger : Theme.tint
                            )

                            VStack(alignment: .leading, spacing: 8) {
                                Text(state.isBlocked ? "Limit reached" : "Within limit")
                                    .font(.headline)
                                    .foregroundStyle(state.isBlocked ? Theme.danger : Theme.success)

                                Text("\(DurationFormatter.minutesString(state.totalUsedMinutesToday)) used of \(DurationFormatter.minutesString(state.totalAllowanceMinutes))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                ProgressView(value: usageProgress)
                                    .tint(state.isBlocked ? Theme.danger : Theme.tint)
                            }
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
                            color: state.remainingMinutes > 0 ? Theme.success : Theme.danger,
                            icon: "gauge.with.needle"
                        )

                        StatCardView(
                            title: "Base Limit",
                            value: DurationFormatter.minutesString(state.dailyLimitMinutes),
                            color: Theme.tint,
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
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
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

@available(iOS 17.0, *) // <-- Diese Zeile hinzufügen!
private struct PushUpWorkoutView: View {
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
                                .foregroundStyle(detector.isRunning ? Theme.success : Theme.warning)
                            Spacer()
                            Text("Angle: \(Int(detector.smoothedElbowAngle))°")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: progressToNextMinute)
                                .tint(Theme.tint)

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
                                        .strokeBorder(Theme.border, lineWidth: 1)
                                )
                                .shadow(color: Theme.shadow, radius: 10, x: 0, y: 6)
                        }
                    }

                    HStack(spacing: 12) {
                        StatCardView(
                            title: "Push-Ups",
                            value: "\(detector.pushUpCount)",
                            color: Theme.tint,
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
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)

                        Button("Reset") {
                            detector.resetCounters()
                            claimedMinutes = 0
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }

                    Button {
                        claimEarnedTime()
                    } label: {
                        Label("Claim +\(claimableMinutes) min", systemImage: "gift.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
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
            .onChange(of: detector.earnedMinutes) { newValue in
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
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
        .shadow(color: Theme.shadow, radius: 10, x: 0, y: 6)
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

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected AVCaptureVideoPreviewLayer")
        }
        return layer
    }
}

private final class PushUpDetector: NSObject, ObservableObject {
    @Published private(set) var pushUpCount = 0
    @Published private(set) var earnedMinutes = 0
    @Published private(set) var permissionDenied = false
    @Published private(set) var isRunning = false
    @Published private(set) var smoothedElbowAngle: Double = 180

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.linuskjk.unrott.camera-session")
    private let visionQueue = DispatchQueue(label: "com.linuskjk.unrott.vision-queue")
    private let videoOutput = AVCaptureVideoDataOutput()

    private var isConfigured = false

    private enum RepPhase {
        case up
        case down
    }

    private var repPhase: RepPhase = .up
    private var downStartDate: Date?
    private var lastRepDate = Date.distantPast
    private var angleWindow: [Double] = []

    private let maxWindowSize = 6
    private let downAngleThreshold = 100.0
    private let upAngleThreshold = 155.0
    private let minDownHold: TimeInterval = 0.15
    private let minRepInterval: TimeInterval = 0.5
    private let confidenceThreshold: VNConfidence = 0.35

    func start() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            permissionDenied = false
            prepareAndStartSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.permissionDenied = !granted
                }
                if granted {
                    self.prepareAndStartSession()
                }
            }
        case .denied, .restricted:
            permissionDenied = true
        @unknown default:
            permissionDenied = true
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }

    func resetCounters() {
        DispatchQueue.main.async {
            self.pushUpCount = 0
            self.earnedMinutes = 0
            self.smoothedElbowAngle = 180
        }

        visionQueue.async { [weak self] in
            guard let self else { return }
            self.repPhase = .up
            self.downStartDate = nil
            self.lastRepDate = Date.distantPast
            self.angleWindow.removeAll()
        }
    }

    private func prepareAndStartSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if !self.isConfigured {
                self.configureSession()
            }

            guard self.isConfigured else {
                DispatchQueue.main.async {
                    self.permissionDenied = true
                }
                return
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }

            DispatchQueue.main.async {
                self.isRunning = true
            }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .high
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)

        guard let camera else {
            isConfigured = false
            return
        }

        guard let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input) else {
            isConfigured = false
            return
        }
        session.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: visionQueue)
        guard session.canAddOutput(videoOutput) else {
            isConfigured = false
            return
        }
        session.addOutput(videoOutput)
        videoOutput.connection(with: .video)?.videoOrientation = .portrait
        isConfigured = true
    }

    private func analyze(sampleBuffer: CMSampleBuffer) {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([request])
            guard let observation = request.results?.first,
                  let elbowAngle = computeElbowAngle(from: observation) else {
                return
            }

            processSmoothedAngle(elbowAngle)
        } catch {
            return
        }
    }

    private func computeElbowAngle(from observation: VNHumanBodyPoseObservation) -> Double? {
        guard let points = try? observation.recognizedPoints(.all) else {
            return nil
        }

        var armAngles: [Double] = []

        if let leftShoulder = point(.leftShoulder, from: points),
           let leftElbow = point(.leftElbow, from: points),
           let leftWrist = point(.leftWrist, from: points),
           let angle = angleDegrees(a: leftShoulder, b: leftElbow, c: leftWrist) {
            armAngles.append(angle)
        }

        if let rightShoulder = point(.rightShoulder, from: points),
           let rightElbow = point(.rightElbow, from: points),
           let rightWrist = point(.rightWrist, from: points),
           let angle = angleDegrees(a: rightShoulder, b: rightElbow, c: rightWrist) {
            armAngles.append(angle)
        }

        guard !armAngles.isEmpty else {
            return nil
        }

        return armAngles.reduce(0, +) / Double(armAngles.count)
    }

    private func point(
        _ joint: VNHumanBodyPoseObservation.JointName,
        from recognizedPoints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]
    ) -> CGPoint? {
        guard let candidate = recognizedPoints[joint], candidate.confidence >= confidenceThreshold else {
            return nil
        }

        return CGPoint(x: candidate.x, y: candidate.y)
    }

    private func angleDegrees(a: CGPoint, b: CGPoint, c: CGPoint) -> Double? {
        let v1 = CGVector(dx: a.x - b.x, dy: a.y - b.y)
        let v2 = CGVector(dx: c.x - b.x, dy: c.y - b.y)

        let v1Length = sqrt(v1.dx * v1.dx + v1.dy * v1.dy)
        let v2Length = sqrt(v2.dx * v2.dx + v2.dy * v2.dy)

        guard v1Length > 0.001, v2Length > 0.001 else {
            return nil
        }

        let dotProduct = (v1.dx * v2.dx) + (v1.dy * v2.dy)
        let cosine = max(-1.0, min(1.0, dotProduct / (v1Length * v2Length)))
        
        // Fix: Explizit Double.pi verwenden, um Mehrdeutigkeit zu vermeiden
        return acos(cosine) * 180.0 / Double.pi
    }

    private func processSmoothedAngle(_ angle: Double) {
        angleWindow.append(angle)
        if angleWindow.count > maxWindowSize {
            angleWindow.removeFirst()
        }

        let smoothAngle = angleWindow.reduce(0, +) / Double(angleWindow.count)
        DispatchQueue.main.async {
            self.smoothedElbowAngle = smoothAngle
        }

        let now = Date()

        switch repPhase {
        case .up:
            if smoothAngle <= downAngleThreshold {
                repPhase = .down
                downStartDate = now
            }
        case .down:
            guard smoothAngle >= upAngleThreshold else {
                return
            }

            let holdDuration = now.timeIntervalSince(downStartDate ?? now)
            let repDuration = now.timeIntervalSince(lastRepDate)

            repPhase = .up
            downStartDate = nil

            guard holdDuration >= minDownHold, repDuration >= minRepInterval else {
                return
            }

            lastRepDate = now
            DispatchQueue.main.async {
                self.pushUpCount += 1
                self.earnedMinutes = self.pushUpCount / 5
            }
        }
    }
}

extension PushUpDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        analyze(sampleBuffer: sampleBuffer)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
