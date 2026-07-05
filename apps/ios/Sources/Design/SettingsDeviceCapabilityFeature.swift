import ComposableArchitecture
import OpenClawKit

enum SettingsDeviceCapabilityLocationMode: Equatable {
    case known(OpenClawLocationMode)
    case unknown(String)

    init(mode: OpenClawLocationMode) {
        self = .known(mode)
    }

    init(rawValue: String) {
        if let mode = OpenClawLocationMode(rawValue: rawValue) {
            self = .known(mode)
        } else {
            self = .unknown(rawValue)
        }
    }

    var rawValue: String {
        switch self {
        case let .known(mode):
            mode.rawValue

        case let .unknown(rawValue):
            rawValue
        }
    }
}

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
        var mode: SettingsDeviceCapabilityLocationMode
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
                state.locationModeRaw = change.mode.rawValue
                return .none

            case let .preventSleepChanged(change):
                state.preventSleep = change.isEnabled
                return .none
            }
        }
        .autoLogActions()
    }
}
