import DeviceActivity
import SwiftUI
import FamilyControls
import Foundation

extension DeviceActivityReport.Context {
    static let totalActivity = Self("com.linuskjk.unrott.usage-context")
}

struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity

    let content: (String) -> TotalActivityView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll

        var totalActivityDuration: TimeInterval = 0
        for await deviceData in data {
            for await segment in deviceData.activitySegments {
                totalActivityDuration += segment.totalActivityDuration
            }
        }

        let usedMinutes = max(0, Int((totalActivityDuration / 60.0).rounded(.down)))
        _ = ReportStore.shared.update { state in
            state.totalUsedMinutesToday = usedMinutes
            state.isBlocked = state.remainingMinutes <= 0
        }

        return formatter.string(from: totalActivityDuration) ?? "No activity data"
    }
}

private enum ReportConstants {
    static let appGroupIdentifier = "group.com.linuskjk.unrott"
    static let storageKey = "unrott-app-state"
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

private struct ReportState: Codable {
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
    }
}

private final class ReportStore {
    static let shared = ReportStore()

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()

    private init() {
        defaults = UserDefaults(suiteName: ReportConstants.appGroupIdentifier) ?? .standard
    }

    @discardableResult
    func update(_ mutate: (inout ReportState) -> Void) -> ReportState {
        lock.lock()
        defer { lock.unlock() }

        var state: ReportState
        if let data = defaults.data(forKey: ReportConstants.storageKey),
           let decoded = try? decoder.decode(ReportState.self, from: data) {
            state = decoded
        } else {
            state = ReportState()
        }

        state.resetForNewDayIfNeeded()
        mutate(&state)
        state.clamp()
        state.updatedAt = Date()

        if let encoded = try? encoder.encode(state) {
            defaults.set(encoded, forKey: ReportConstants.storageKey)
        }
        return state
    }
}
