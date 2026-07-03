import ComposableArchitecture

@Reducer
struct SettingsNotificationFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var isRequestingAuthorization = false
        var status: SettingsNotificationStatus = .checking

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
    }

    enum Action: Equatable, Sendable {
        case authorizationRequestFinished(SettingsNotificationStatus)
        case authorizationRequestStarted
        case statusChanged(SettingsNotificationStatus)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .authorizationRequestFinished(status):
                state.isRequestingAuthorization = false
                state.status = status
                return .none

            case .authorizationRequestStarted:
                state.isRequestingAuthorization = true
                return .none

            case let .statusChanged(status):
                state.status = status
                return .none
            }
        }
        .autoLogActions()
    }
}
