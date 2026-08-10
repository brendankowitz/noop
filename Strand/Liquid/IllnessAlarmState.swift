import Foundation
import StrandAnalytics

// MARK: - Illness alarm state (bknoop fork)
//
// A narrow, dedicated `ObservableObject` — same shared-singleton shape as `NoopMotionState.shared`,
// which `LiquidTodayView` already observes directly — so the Today hero can react to the illness
// ladder's Major rung WITHOUT subscribing to the whole `AppModel` (that publishes on the ~1Hz HR
// tick; LiquidTodayView deliberately avoids `@EnvironmentObject var model: AppModel` for exactly this
// reason — see the `ble` property's comment in LiquidTodayView.swift). Only republishes when the
// major/not-major boundary actually crosses, not on every AppModel update.
@MainActor
final class IllnessAlarmState: ObservableObject {
    static let shared = IllnessAlarmState()
    private init() {}

    /// True for the ladder's Major rung (raised / already-unwell) — the mockup's "alarm sky" trigger.
    @Published private(set) var isMajor = false

    /// Call from wherever `AppModel.illnessSignal` is assigned (including when set to nil).
    func update(from result: IllnessSignalEngine.Result?) {
        let major = result.map { $0.level == .raised || $0.level == .alreadyUnwell } ?? false
        if major != isMajor { isMajor = major }
    }
}
