import ComposableArchitecture
import OpenClawKit

@Reducer
struct SettingsLocationFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var isChangingLocationMode = false
        var locationModeRaw = OpenClawLocationMode.off.rawValue
        var previousLocationModeRaw = OpenClawLocationMode.off.rawValue
        var statusText: String?

        var locationLabel: String {
            switch self.locationMode {
            case .off: "Off"
            case .whileUsing: "While Using"
            case .always: "Always"
            }
        }

        var privacyDetail: String {
            self.locationMode == .off ? "Location off" : "Location \(self.locationLabel)"
        }

        private var locationMode: OpenClawLocationMode {
            OpenClawLocationMode(rawValue: self.locationModeRaw) ?? .off
        }
    }

    enum Action: Equatable, Sendable {
        case locationChangeFinished
        case locationChangeStarted
        case locationModeChanged(String)
        case locationModeApplied(String)
        case locationModeSynced(String)
        case locationPermissionDenied(previousRawValue: String)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .locationChangeFinished:
                state.isChangingLocationMode = false
                return .none

            case .locationChangeStarted:
                state.isChangingLocationMode = true
                state.statusText = nil
                return .none

            case let .locationModeChanged(rawValue):
                state.locationModeRaw = rawValue
                return .none

            case let .locationModeApplied(rawValue):
                state.locationModeRaw = rawValue
                state.previousLocationModeRaw = rawValue
                return .none

            case let .locationModeSynced(rawValue):
                guard !state.isChangingLocationMode else { return .none }
                state.locationModeRaw = rawValue
                state.previousLocationModeRaw = rawValue
                return .none

            case let .locationPermissionDenied(previousRawValue):
                state.locationModeRaw = previousRawValue
                state.previousLocationModeRaw = previousRawValue
                state.statusText = "Location permission was not granted."
                return .none
            }
        }
        .autoLogActions()
    }
}
