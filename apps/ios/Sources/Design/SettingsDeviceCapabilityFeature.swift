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
        var cameraEnabled = CameraEnabled(value: true)
        var locationModeRaw = LocationModeRawValue(rawValue: OpenClawLocationMode.off.rawValue)
        var preventSleep = PreventSleepEnabled(value: true)

        var enabledCount: Int {
            var count = 0
            if self.cameraEnabled.value { count += 1 }
            if self.preventSleep.value { count += 1 }
            if self.locationModeRaw.rawValue != OpenClawLocationMode.off.rawValue { count += 1 }
            return count
        }

        var permissionsDetail: String {
            "\(self.enabledCount) enabled"
        }
    }

    struct CameraEnabled: Equatable, Sendable { var value: Bool }
    struct CameraEnabledChange: Equatable, Sendable { var enabled: CameraEnabled }

    struct CapabilitiesSync: Equatable, Sendable {
        var cameraEnabled: CameraEnabled
        var preventSleep: PreventSleepEnabled
        var locationMode: SettingsDeviceCapabilityLocationMode
    }

    struct LocationModeChange: Equatable, Sendable {
        var mode: SettingsDeviceCapabilityLocationMode
    }

    struct LocationModeRawValue: Equatable, Sendable { var rawValue: String }

    struct PreventSleepEnabled: Equatable, Sendable { var value: Bool }
    struct PreventSleepChange: Equatable, Sendable { var enabled: PreventSleepEnabled }

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
                state.cameraEnabled = change.enabled
                return .none

            case let .capabilitiesSynced(sync):
                state.cameraEnabled = sync.cameraEnabled
                state.preventSleep = sync.preventSleep
                state.locationModeRaw = .init(rawValue: sync.locationMode.rawValue)
                return .none

            case let .locationModeChanged(change):
                state.locationModeRaw = .init(rawValue: change.mode.rawValue)
                return .none

            case let .preventSleepChanged(change):
                state.preventSleep = change.enabled
                return .none
            }
        }
        .autoLogActions()
    }
}
