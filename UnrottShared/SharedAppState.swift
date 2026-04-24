import Foundation
import FamilyControls

struct SharedAppState: Codable {
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
