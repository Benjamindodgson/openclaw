import ComposableArchitecture
import SwiftUI
import UIKit
import UserNotifications

struct SettingsNotificationAuthorizationClient {
    var fetchStatus: @Sendable () async -> SettingsNotificationStatus
    var requestAuthorization: @Sendable () async -> SettingsNotificationAuthorizationResult
}

struct SettingsNotificationAuthorizationResult: Equatable {
    let granted: Bool
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
                granted: granted,
                status: SettingsNotificationStatus(settings.authorizationStatus))
        })

    static let testValue = SettingsNotificationAuthorizationClient(
        fetchStatus: {
            .unknown
        },
        requestAuthorization: {
            SettingsNotificationAuthorizationResult(granted: false, status: .unknown)
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
    private let authorizationClientOverride: SettingsNotificationAuthorizationClient?
    private let registrationClientOverride: SettingsNotificationRegistrationClient?

    init(
        authorizationClient: SettingsNotificationAuthorizationClient? = nil,
        registrationClient: SettingsNotificationRegistrationClient? = nil)
    {
        self.authorizationClientOverride = authorizationClient
        self.registrationClientOverride = registrationClient
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var hostedRelayHost = "ios-push-relay.openclaw.ai"
        var actionRequest: ActionRequest?
        var authorizationRequestResult: SettingsNotificationAuthorizationResult?
        var isRequestingAuthorization = false
        var status: SettingsNotificationStatus = .checking
        var statusRefreshResult: SettingsNotificationStatus?
        var usesOpenClawHostedRelay = false

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

        var relayDetail: String {
            if self.usesOpenClawHostedRelay {
                return """
                This build uses OpenClaw's hosted push relay at \(self.hostedRelayHost) for notification \
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
        struct HostedRelayHost: Equatable, Sendable { var value: String? }
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
                guard state.status == .notSet, !state.isRequestingAuthorization else { return .none }
                state.actionRequest = state.usesOpenClawHostedRelay ? .showRelayDisclosure : .requestAuthorization
                return .none

            case .actionRequestHandled:
                state.actionRequest = nil
                return .none

            case let .authorizationRequestFinished(result):
                state.authorizationRequestResult = result
                state.isRequestingAuthorization = false
                state.status = result.status
                return .none

            case .authorizationRequestRequested:
                guard !state.isRequestingAuthorization else { return .none }
                state.actionRequest = nil
                state.authorizationRequestResult = nil
                state.isRequestingAuthorization = true
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
                state.usesOpenClawHostedRelay = sync.usesOpenClawHostedRelay.value
                state.hostedRelayHost = sync.hostedRelayHost.value ?? "ios-push-relay.openclaw.ai"
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
