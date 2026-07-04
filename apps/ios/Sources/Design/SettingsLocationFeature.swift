import ComposableArchitecture
import CoreLocation
import OpenClawKit
import SwiftUI

// swiftformat:disable redundantSendable
struct SettingsLocationPermissionClient: Sendable {
    var requestPermission: @MainActor @Sendable (OpenClawLocationMode) async -> Bool
}

struct SettingsLocationGatewayRefreshClient: Sendable {
    var refreshGatewayRegistration: @MainActor @Sendable () -> Void
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

extension SettingsLocationGatewayRefreshClient: DependencyKey {
    static let liveValue = SettingsLocationGatewayRefreshClient(refreshGatewayRegistration: {})
    static let testValue = SettingsLocationGatewayRefreshClient(refreshGatewayRegistration: {})

    @MainActor
    static func live(gatewayController: GatewayConnectionController) -> Self {
        SettingsLocationGatewayRefreshClient(refreshGatewayRegistration: {
            gatewayController.refreshActiveGatewayRegistrationFromSettings()
        })
    }
}

extension DependencyValues {
    var settingsLocationPermission: SettingsLocationPermissionClient {
        get { self[SettingsLocationPermissionClient.self] }
        set { self[SettingsLocationPermissionClient.self] = newValue }
    }

    var settingsLocationGatewayRefresh: SettingsLocationGatewayRefreshClient {
        get { self[SettingsLocationGatewayRefreshClient.self] }
        set { self[SettingsLocationGatewayRefreshClient.self] = newValue }
    }
}

@Reducer
struct SettingsLocationFeature {
    private let gatewayRefreshClientOverride: SettingsLocationGatewayRefreshClient?
    private let permissionClientOverride: SettingsLocationPermissionClient?

    init(
        gatewayRefreshClient: SettingsLocationGatewayRefreshClient? = nil,
        permissionClient: SettingsLocationPermissionClient? = nil)
    {
        self.gatewayRefreshClientOverride = gatewayRefreshClient
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

    struct LocationModeChange: Equatable, Sendable {
        var rawValue: String
    }

    struct LocationModeChangeRequest: Equatable, Sendable {
        var rawValue: String
    }

    struct LocationModeSync: Equatable, Sendable {
        var rawValue: String
    }

    enum LocationModeApplyResult: Equatable, Sendable {
        struct Applied: Equatable, Sendable {
            var rawValue: String
        }

        struct Denied: Equatable, Sendable {
            var previousRawValue: String
        }

        case applied(Applied)
        case denied(Denied)
    }

    enum Action: Equatable, Sendable {
        case locationModeApplyFinished(LocationModeApplyResult)
        case locationModeApplyRequested(LocationModeRequest)
        case locationModeApplyResultHandled
        case locationModeChanged(LocationModeChange)
        case locationModeChangeRequested(LocationModeChangeRequest)
        case locationModeSynced(LocationModeSync)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.settingsLocationGatewayRefresh) var dependencyGatewayRefreshClient
            @Dependency(\.settingsLocationPermission) var dependencyPermissionClient
            let gatewayRefreshClient = self.gatewayRefreshClientOverride ?? dependencyGatewayRefreshClient
            let permissionClient = self.permissionClientOverride ?? dependencyPermissionClient

            switch action {
            case let .locationModeApplyFinished(result):
                state.isChangingLocationMode = false
                state.locationModeRequest = nil
                state.locationModeApplyResult = result
                switch result {
                case let .applied(applied):
                    state.locationModeRaw = applied.rawValue
                    state.previousLocationModeRaw = applied.rawValue
                    return .run { _ in
                        await gatewayRefreshClient.refreshGatewayRegistration()
                    }

                case let .denied(denied):
                    state.locationModeRaw = denied.previousRawValue
                    state.previousLocationModeRaw = denied.previousRawValue
                    state.statusText = "Location permission was not granted."
                    return .none
                }

            case let .locationModeApplyRequested(request):
                state.locationModeRequest = nil
                guard !state.isChangingLocationMode else { return .none }
                state.isChangingLocationMode = true
                state.locationModeApplyResult = nil
                state.statusText = nil

                guard request.mode != .off else {
                    state.isChangingLocationMode = false
                    state.locationModeApplyResult = .applied(.init(rawValue: request.rawValue))
                    state.locationModeRaw = request.rawValue
                    state.previousLocationModeRaw = request.rawValue
                    return .run { _ in
                        await gatewayRefreshClient.refreshGatewayRegistration()
                    }
                }

                return .run { send in
                    let granted = await permissionClient.requestPermission(request.mode)
                    let result: LocationModeApplyResult = granted
                        ? .applied(.init(rawValue: request.rawValue))
                        : .denied(.init(previousRawValue: request.previousRawValue))
                    await send(.locationModeApplyFinished(result))
                }

            case .locationModeApplyResultHandled:
                state.locationModeApplyResult = nil
                return .none

            case let .locationModeChanged(change):
                state.locationModeRaw = change.rawValue
                return .none

            case let .locationModeChangeRequested(request):
                let rawValue = request.rawValue
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

            case let .locationModeSynced(sync):
                guard !state.isChangingLocationMode else { return .none }
                state.locationModeRequest = nil
                state.locationModeApplyResult = nil
                state.locationModeRaw = sync.rawValue
                state.previousLocationModeRaw = sync.rawValue
                return .none
            }
        }
        .autoLogActions()
    }
}
