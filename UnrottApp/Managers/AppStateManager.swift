import Foundation
import Combine
import FamilyControls

@MainActor
final class AppStateManager: ObservableObject {
    @Published private(set) var state: SharedAppState

    private let store: SharedStore

    init(store: SharedStore = .shared) {
        self.store = store
        self.state = store.loadState()
    }

    func refreshFromStore() {
        state = store.loadState()
    }

    func setSelection(_ selection: FamilyActivitySelection) {
        state = store.update { mutable in
            mutable.selection = selection
            mutable.totalUsedMinutesToday = max(0, mutable.totalUsedMinutesToday)
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

    func updateTotalUsedMinutes(_ minutes: Int) {
        state = store.update { mutable in
            mutable.totalUsedMinutesToday = max(0, minutes)
            mutable.isBlocked = mutable.remainingMinutes <= 0
        }
    }
}
