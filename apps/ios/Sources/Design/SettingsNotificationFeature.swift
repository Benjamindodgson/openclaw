import ComposableArchitecture
import SwiftUI
import UserNotifications

struct SettingsNotificationAuthorizationClient {
    var fetchStatus: @Sendable () async -> SettingsNotificationStatus
    var requestAuthorization: @Sendable () async -> SettingsNotificationAuthorizationResult
}

struct SettingsNotificationAuthorizationResult: Equatable {
    let granted: Bool
    let status: SettingsNotificationStatus
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
}

@Reducer
struct SettingsNotificationFeature {
    private let authorizationClientOverride: SettingsNotificationAuthorizationClient?

    init(authorizationClient: SettingsNotificationAuthorizationClient? = nil) {
        self.authorizationClientOverride = authorizationClient
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
        case actionButtonTapped
        case actionRequestHandled
        case authorizationRequestFinished(SettingsNotificationAuthorizationResult)
        case authorizationRequestRequested
        case authorizationRequestResultHandled
        case relayConfigSynced(usesOpenClawHostedRelay: Bool, hostedRelayHost: String?)
        case statusRefreshFinished(SettingsNotificationStatus)
        case statusRefreshRequested
        case statusRefreshResultHandled
        case statusChanged(SettingsNotificationStatus)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.settingsNotificationAuthorization) var dependencyAuthorizationClient
            let authorizationClient = self.authorizationClientOverride ?? dependencyAuthorizationClient

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

            case let .relayConfigSynced(usesOpenClawHostedRelay, hostedRelayHost):
                state.usesOpenClawHostedRelay = usesOpenClawHostedRelay
                state.hostedRelayHost = hostedRelayHost ?? "ios-push-relay.openclaw.ai"
                return .none

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
