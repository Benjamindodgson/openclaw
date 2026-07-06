import ComposableArchitecture
import SwiftUI
import UIKit
import UserNotifications

struct SettingsNotificationAuthorizationClient {
    var fetchStatus: @Sendable () async -> SettingsNotificationStatus
    var requestAuthorization: @Sendable () async -> SettingsNotificationAuthorizationResult
}

// swiftformat:disable redundantSendable

struct SettingsNotificationAuthorizationGranted: Equatable, Sendable {
    let value: Bool
}

struct SettingsNotificationAuthorizationResult: Equatable, Sendable {
    let granted: SettingsNotificationAuthorizationGranted
    let status: SettingsNotificationStatus
}

struct SettingsNotificationRegistrationClient {
    var openNotificationSettings: @MainActor @Sendable () -> Void
    var registerForRemoteNotifications: @MainActor @Sendable () -> Void
}

extension SettingsNotificationRegistrationClient: DependencyKey {
    static let liveValue = SettingsNotificationRegistrationClient(
        openNotificationSettings: {
            guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
            UIApplication.shared.open(url)
        },
        registerForRemoteNotifications: {
            UIApplication.shared.registerForRemoteNotifications()
        })

    static let testValue = SettingsNotificationRegistrationClient(
        openNotificationSettings: {},
        registerForRemoteNotifications: {})
}

extension SettingsNotificationAuthorizationClient: DependencyKey {
    static let liveValue = SettingsNotificationAuthorizationClient(
        fetchStatus: {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            return SettingsNotificationStatus(settings.authorizationStatus)
        },
        requestAuthorization: {
            let granted = await (try? UNUserNotificationCenter.current().requestAuthorization(options: [
                .alert,
                .badge,
                .sound,
            ])) ?? false
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            return SettingsNotificationAuthorizationResult(
                granted: .init(value: granted),
                status: SettingsNotificationStatus(settings.authorizationStatus))
        })

    static let testValue = SettingsNotificationAuthorizationClient(
        fetchStatus: {
            .unknown
        },
        requestAuthorization: {
            SettingsNotificationAuthorizationResult(granted: .init(value: false), status: .unknown)
        })
}

extension DependencyValues {
    var settingsNotificationAuthorization: SettingsNotificationAuthorizationClient {
        get { self[SettingsNotificationAuthorizationClient.self] }
        set { self[SettingsNotificationAuthorizationClient.self] = newValue }
    }

    var settingsNotificationRegistration: SettingsNotificationRegistrationClient {
        get { self[SettingsNotificationRegistrationClient.self] }
        set { self[SettingsNotificationRegistrationClient.self] = newValue }
    }
}

@Reducer
struct SettingsNotificationFeature {
    private static let defaultHostedRelayHost = "ios-push-relay.openclaw.ai"

    private let authorizationClientOverride: SettingsNotificationAuthorizationClient?
    private let registrationClientOverride: SettingsNotificationRegistrationClient?

    init(
        authorizationClient: SettingsNotificationAuthorizationClient? = nil,
        registrationClient: SettingsNotificationRegistrationClient? = nil)
    {
        self.authorizationClientOverride = authorizationClient
        self.registrationClientOverride = registrationClient
    }

    struct HostedRelayHost: Equatable, Sendable { var value: String? }

    @ObservableState
    struct State: Equatable, Sendable {
        enum AuthorizationRequestPhase: Equatable, Sendable {
            case idle
            case inFlight
        }

        var hostedRelayHost = HostedRelayHost(value: SettingsNotificationFeature.defaultHostedRelayHost)
        var actionRequest: ActionRequest?
        var authorizationRequestResult: SettingsNotificationAuthorizationResult?
        var authorizationRequestPhase = AuthorizationRequestPhase.idle
        var status: SettingsNotificationStatus = .checking
        var statusRefreshResult: SettingsNotificationStatus?
        var usesOpenClawHostedRelay = Action.HostedRelayEnabled(value: false)

        var actionText: String {
            self.status.actionTitle
        }

        var needsAttention: Bool {
            switch self.status {
            case .allowed, .checking:
                false
            case .notAllowed, .notSet, .unknown:
                true
            }
        }

        var statusDetail: String {
            switch self.status {
            case .checking:
                "Checking iOS notification permission."
            case .allowed:
                "OpenClaw can show approval prompts and event alerts when the app is not active."
            case .notAllowed:
                "Notifications have been denied. Enable them in iOS Settings."
            case .notSet:
                "Enable notifications to receive approval prompts and event alerts outside the app."
            case .unknown:
                "OpenClaw cannot determine the current notification permission state."
            }
        }

        var statusText: String {
            self.status.text
        }

        var statusColor: Color {
            self.status.color
        }

        var hostedRelayHostText: String {
            self.hostedRelayHost.value ?? SettingsNotificationFeature.defaultHostedRelayHost
        }

        var relayDetail: String {
            if self.usesOpenClawHostedRelay.value {
                return """
                This build uses OpenClaw's hosted push relay at \(self.hostedRelayHostText) for notification \
                delivery data.
                """
            }
            return "This build is not configured to use OpenClaw's hosted push relay."
        }

        var relayDisclosureMessage: String {
            "Enabling this sends delivery data through OpenClaw's hosted push relay."
        }
    }

    enum ActionRequest: Equatable, Sendable {
        case openSettings
        case requestAuthorization
        case showRelayDisclosure
    }

    enum Action: Equatable, Sendable {
        struct HostedRelayEnabled: Equatable, Sendable { var value: Bool }
        struct RemoteRegistrationDisclosureAccepted: Equatable, Sendable { var value: Bool }

        struct RelayConfigSync: Equatable, Sendable {
            var usesOpenClawHostedRelay: HostedRelayEnabled
            var hostedRelayHost: HostedRelayHost
        }

        struct RemoteRegistrationRequest: Equatable, Sendable {
            var disclosureAccepted: RemoteRegistrationDisclosureAccepted
        }

        case actionButtonTapped
        case actionRequestHandled
        case authorizationRequestFinished(SettingsNotificationAuthorizationResult)
        case authorizationRequestRequested
        case authorizationRequestResultHandled
        case notificationSettingsOpenRequested
        case relayConfigSynced(RelayConfigSync)
        case remoteRegistrationRequested(RemoteRegistrationRequest)
        case statusRefreshFinished(SettingsNotificationStatus)
        case statusRefreshRequested
        case statusRefreshResultHandled
        case statusChanged(SettingsNotificationStatus)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.settingsNotificationAuthorization) var dependencyAuthorizationClient
            @Dependency(\.settingsNotificationRegistration) var dependencyRegistrationClient
            let authorizationClient = self.authorizationClientOverride ?? dependencyAuthorizationClient
            let registrationClient = self.registrationClientOverride ?? dependencyRegistrationClient

            switch action {
            case .actionButtonTapped:
                state.actionRequest = nil
                if state.status.shouldOpenNotificationSettings {
                    state.actionRequest = .openSettings
                    return .none
                }
                guard state.status == .notSet, state.authorizationRequestPhase != .inFlight else { return .none }
                state.actionRequest = state.usesOpenClawHostedRelay.value ? .showRelayDisclosure : .requestAuthorization
                return .none

            case .actionRequestHandled:
                state.actionRequest = nil
                return .none

            case let .authorizationRequestFinished(result):
                state.authorizationRequestResult = result
                state.authorizationRequestPhase = .idle
                state.status = result.status
                return .none

            case .authorizationRequestRequested:
                guard state.authorizationRequestPhase != .inFlight else { return .none }
                state.actionRequest = nil
                state.authorizationRequestResult = nil
                state.authorizationRequestPhase = .inFlight
                return .run { send in
                    let result = await authorizationClient.requestAuthorization()
                    await send(.authorizationRequestFinished(result))
                }

            case .authorizationRequestResultHandled:
                state.authorizationRequestResult = nil
                return .none

            case .notificationSettingsOpenRequested:
                return .run { _ in
                    await registrationClient.openNotificationSettings()
                }

            case let .relayConfigSynced(sync):
                state.usesOpenClawHostedRelay = sync.usesOpenClawHostedRelay
                state.hostedRelayHost = .init(value: sync.hostedRelayHost.value ?? Self.defaultHostedRelayHost)
                return .none

            case let .remoteRegistrationRequested(request):
                guard request.disclosureAccepted.value, state.status.allowsNotifications else { return .none }
                return .run { _ in
                    await registrationClient.registerForRemoteNotifications()
                }

            case let .statusRefreshFinished(status):
                state.status = status
                state.statusRefreshResult = status
                return .none

            case .statusRefreshRequested:
                return .run { send in
                    let status = await authorizationClient.fetchStatus()
                    await send(.statusRefreshFinished(status))
                }

            case .statusRefreshResultHandled:
                state.statusRefreshResult = nil
                return .none

            case let .statusChanged(status):
                state.status = status
                return .none
            }
        }
        .autoLogActions()
    }
}
