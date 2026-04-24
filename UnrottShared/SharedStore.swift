import Foundation

final class SharedStore {
    static let shared = SharedStore()

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()

    private init() {
        defaults = UserDefaults(suiteName: SharedConstants.appGroupIdentifier) ?? .standard
    }

    func loadState() -> SharedAppState {
        lock.lock()
        defer { lock.unlock() }

        let decoded: SharedAppState
        if let data = defaults.data(forKey: SharedConstants.stateStorageKey),
           let state = try? decoder.decode(SharedAppState.self, from: data) {
            decoded = state
        } else {
            decoded = SharedAppState()
        }

        var mutable = decoded
        mutable.resetForNewDayIfNeeded()
        persistLocked(mutable)
        return mutable
    }

    @discardableResult
    func saveState(_ state: SharedAppState) -> SharedAppState {
        lock.lock()
        defer { lock.unlock() }

        var mutable = state
        mutable.resetForNewDayIfNeeded()
        mutable.updatedAt = Date()
        persistLocked(mutable)
        return mutable
    }

    @discardableResult
    func update(_ mutate: (inout SharedAppState) -> Void) -> SharedAppState {
        lock.lock()
        defer { lock.unlock() }

        var state: SharedAppState
        if let data = defaults.data(forKey: SharedConstants.stateStorageKey),
           let decoded = try? decoder.decode(SharedAppState.self, from: data) {
            state = decoded
        } else {
            state = SharedAppState()
        }

        state.resetForNewDayIfNeeded()
        mutate(&state)
        state.clamp()
        state.updatedAt = Date()
        persistLocked(state)
        return state
    }

    private func persistLocked(_ state: SharedAppState) {
        guard let encoded = try? encoder.encode(state) else {
            return
        }
        defaults.set(encoded, forKey: SharedConstants.stateStorageKey)
    }
}
