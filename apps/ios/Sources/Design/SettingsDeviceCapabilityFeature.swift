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

    struct CameraEnabledChange: Equatable, Sendable {
        var isEnabled: Bool
    }

    struct CapabilitiesSync: Equatable, Sendable {
        var cameraEnabled: Bool
        var preventSleep: Bool
        var locationModeRaw: String
    }

    struct LocationModeChange: Equatable, Sendable {
        var rawValue: String
    }

    struct PreventSleepChange: Equatable, Sendable {
        var isEnabled: Bool
    }

    enum Action: Equatable, Sendable {
        case cameraEnabledChanged(CameraEnabledChange)
        case capabilitiesSynced(CapabilitiesSync)
        case locationModeChanged(LocationModeChange)
        case preventSleepChanged(PreventSleepChange)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .cameraEnabledChanged(change):
                state.cameraEnabled = change.isEnabled
                return .none

            case let .capabilitiesSynced(sync):
                state.cameraEnabled = sync.cameraEnabled
                state.preventSleep = sync.preventSleep
                state.locationModeRaw = sync.locationModeRaw
                return .none

            case let .locationModeChanged(change):
                state.locationModeRaw = change.rawValue
                return .none

            case let .preventSleepChanged(change):
                state.preventSleep = change.isEnabled
                return .none
            }
        }
        .autoLogActions()
    }
}
