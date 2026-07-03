import ComposableArchitecture
import OpenClawKit
import SwiftUI

@Reducer
struct SettingsLocationFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var isChangingLocationMode = false
        var locationModeRequest: LocationModeRequest?
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

        var locationColor: Color {
            self.locationMode == .off ? .secondary : OpenClawBrand.accent
        }

        private var locationMode: OpenClawLocationMode {
            OpenClawLocationMode(rawValue: self.locationModeRaw) ?? .off
        }
    }

    struct LocationModeRequest: Equatable, Sendable {
        let mode: OpenClawLocationMode
        let previousRawValue: String
        let rawValue: String
    }

    enum Action: Equatable, Sendable {
        case locationChangeFinished
        case locationChangeStarted
        case locationModeChanged(String)
        case locationModeChangeRequested(String)
        case locationModeApplied(String)
        case locationModeRequestHandled
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
                state.locationModeRequest = nil
                state.statusText = nil
                return .none

            case let .locationModeChanged(rawValue):
                state.locationModeRaw = rawValue
                return .none

            case let .locationModeChangeRequested(rawValue):
                state.locationModeRaw = rawValue
                state.locationModeRequest = nil
                guard !state.isChangingLocationMode else { return .none }
                guard rawValue != state.previousLocationModeRaw else { return .none }
                guard let mode = OpenClawLocationMode(rawValue: rawValue) else { return .none }
                state.locationModeRequest = LocationModeRequest(
                    mode: mode,
                    previousRawValue: state.previousLocationModeRaw,
                    rawValue: rawValue)
                return .none

            case let .locationModeApplied(rawValue):
                state.locationModeRequest = nil
                state.locationModeRaw = rawValue
                state.previousLocationModeRaw = rawValue
                return .none

            case .locationModeRequestHandled:
                state.locationModeRequest = nil
                return .none

            case let .locationModeSynced(rawValue):
                guard !state.isChangingLocationMode else { return .none }
                state.locationModeRequest = nil
                state.locationModeRaw = rawValue
                state.previousLocationModeRaw = rawValue
                return .none

            case let .locationPermissionDenied(previousRawValue):
                state.locationModeRequest = nil
                state.locationModeRaw = previousRawValue
                state.previousLocationModeRaw = previousRawValue
                state.statusText = "Location permission was not granted."
                return .none
            }
        }
        .autoLogActions()
    }
}
