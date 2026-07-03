import ComposableArchitecture
import OpenClawKit

@Reducer
struct SettingsDeviceCapabilityFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var cameraEnabled = true
        var locationModeRaw = OpenClawLocationMode.off.rawValue
        var preventSleep = true

        var enabledCount: Int {
            var count = 0
            if self.cameraEnabled { count += 1 }
            if self.preventSleep { count += 1 }
            if self.locationModeRaw != OpenClawLocationMode.off.rawValue { count += 1 }
            return count
        }

        var permissionsDetail: String {
            "\(self.enabledCount) enabled"
        }
    }

    enum Action: Equatable, Sendable {
        case cameraEnabledChanged(Bool)
        case capabilitiesSynced(cameraEnabled: Bool, preventSleep: Bool, locationModeRaw: String)
        case locationModeChanged(String)
        case preventSleepChanged(Bool)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .cameraEnabledChanged(enabled):
                state.cameraEnabled = enabled
                return .none

            case let .capabilitiesSynced(cameraEnabled, preventSleep, locationModeRaw):
                state.cameraEnabled = cameraEnabled
                state.preventSleep = preventSleep
                state.locationModeRaw = locationModeRaw
                return .none

            case let .locationModeChanged(rawValue):
                state.locationModeRaw = rawValue
                return .none

            case let .preventSleepChanged(enabled):
                state.preventSleep = enabled
                return .none
            }
        }
        .autoLogActions()
    }
}
