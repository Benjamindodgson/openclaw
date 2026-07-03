import ComposableArchitecture
import CoreLocation
import OpenClawKit
import SwiftUI

// swiftformat:disable redundantSendable
struct SettingsLocationPermissionClient: Sendable {
    var requestPermission: @MainActor @Sendable (OpenClawLocationMode) async -> Bool
}

// swiftformat:enable redundantSendable

extension SettingsLocationPermissionClient: DependencyKey {
    static let liveValue = SettingsLocationPermissionClient(
        requestPermission: { mode in
            guard mode != .off else { return true }
            let status = await LocationService().ensureAuthorization(mode: mode)
            switch status {
            case .authorizedAlways:
                return true
            case .authorizedWhenInUse:
                return mode != .always
            default:
                return false
            }
        })

    static let testValue = SettingsLocationPermissionClient(
        requestPermission: { mode in
            mode == .off
        })
}

extension DependencyValues {
    var settingsLocationPermission: SettingsLocationPermissionClient {
        get { self[SettingsLocationPermissionClient.self] }
        set { self[SettingsLocationPermissionClient.self] = newValue }
    }
}

@Reducer
struct SettingsLocationFeature {
    private let permissionClientOverride: SettingsLocationPermissionClient?

    init(permissionClient: SettingsLocationPermissionClient? = nil) {
        self.permissionClientOverride = permissionClient
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var isChangingLocationMode = false
        var locationModeApplyResult: LocationModeApplyResult?
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

    enum LocationModeApplyResult: Equatable, Sendable {
        case applied(rawValue: String)
        case denied(previousRawValue: String)
    }

    enum Action: Equatable, Sendable {
        case locationModeApplyFinished(LocationModeApplyResult)
        case locationModeApplyRequested(LocationModeRequest)
        case locationModeApplyResultHandled
        case locationModeChanged(String)
        case locationModeChangeRequested(String)
        case locationModeSynced(String)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.settingsLocationPermission) var dependencyPermissionClient
            let permissionClient = self.permissionClientOverride ?? dependencyPermissionClient

            switch action {
            case let .locationModeApplyFinished(result):
                state.isChangingLocationMode = false
                state.locationModeRequest = nil
                state.locationModeApplyResult = result
                switch result {
                case let .applied(rawValue):
                    state.locationModeRaw = rawValue
                    state.previousLocationModeRaw = rawValue

                case let .denied(previousRawValue):
                    state.locationModeRaw = previousRawValue
                    state.previousLocationModeRaw = previousRawValue
                    state.statusText = "Location permission was not granted."
                }
                return .none

            case let .locationModeApplyRequested(request):
                state.locationModeRequest = nil
                guard !state.isChangingLocationMode else { return .none }
                state.isChangingLocationMode = true
                state.locationModeApplyResult = nil
                state.statusText = nil

                guard request.mode != .off else {
                    state.isChangingLocationMode = false
                    state.locationModeApplyResult = .applied(rawValue: request.rawValue)
                    state.locationModeRaw = request.rawValue
                    state.previousLocationModeRaw = request.rawValue
                    return .none
                }

                return .run { send in
                    let granted = await permissionClient.requestPermission(request.mode)
                    let result: LocationModeApplyResult = granted
                        ? .applied(rawValue: request.rawValue)
                        : .denied(previousRawValue: request.previousRawValue)
                    await send(.locationModeApplyFinished(result))
                }

            case .locationModeApplyResultHandled:
                state.locationModeApplyResult = nil
                return .none

            case let .locationModeChanged(rawValue):
                state.locationModeRaw = rawValue
                return .none

            case let .locationModeChangeRequested(rawValue):
                state.locationModeRaw = rawValue
                state.locationModeRequest = nil
                state.locationModeApplyResult = nil
                guard !state.isChangingLocationMode else { return .none }
                guard rawValue != state.previousLocationModeRaw else { return .none }
                guard let mode = OpenClawLocationMode(rawValue: rawValue) else { return .none }
                state.locationModeRequest = LocationModeRequest(
                    mode: mode,
                    previousRawValue: state.previousLocationModeRaw,
                    rawValue: rawValue)
                return .none

            case let .locationModeSynced(rawValue):
                guard !state.isChangingLocationMode else { return .none }
                state.locationModeRequest = nil
                state.locationModeApplyResult = nil
                state.locationModeRaw = rawValue
                state.previousLocationModeRaw = rawValue
                return .none
            }
        }
        .autoLogActions()
    }
}
