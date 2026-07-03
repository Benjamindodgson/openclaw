import ComposableArchitecture
import Foundation

enum OnboardingConnectionMode: String, CaseIterable {
    case homeNetwork = "home_network"
    case remoteDomain = "remote_domain"
    case developerLocal = "developer_local"

    var title: String {
        switch self {
        case .homeNetwork:
            "Home Network"
        case .remoteDomain:
            "Remote Domain"
        case .developerLocal:
            "Same Machine (Dev)"
        }
    }
}

@Reducer
struct OnboardingStateFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var isCompleted: Bool
        var firstRunIntroSeen: Bool
        var lastMode: OnboardingConnectionMode?
        var hasSavedGatewayConnection: Bool
        var gatewayServerName: String?
        var shouldPresentOnLaunch: Bool
        var shouldPresentFirstRunIntro: Bool

        init(
            isCompleted: Bool = false,
            firstRunIntroSeen: Bool = false,
            lastMode: OnboardingConnectionMode? = nil,
            hasSavedGatewayConnection: Bool = false,
            gatewayServerName: String? = nil)
        {
            self.isCompleted = isCompleted
            self.firstRunIntroSeen = firstRunIntroSeen
            self.lastMode = lastMode
            self.hasSavedGatewayConnection = hasSavedGatewayConnection
            self.gatewayServerName = gatewayServerName
            self.shouldPresentOnLaunch = false
            self.shouldPresentFirstRunIntro = true
            self.refreshPresentation()
        }

        mutating func refreshPresentation() {
            self.shouldPresentOnLaunch =
                !self.isCompleted &&
                !self.hasSavedGatewayConnection &&
                self.gatewayServerName == nil
            self.shouldPresentFirstRunIntro = !self.firstRunIntroSeen
        }
    }

    enum Action: Equatable, Sendable {
        case refreshPresentation
        case gatewaySnapshotChanged(gatewayServerName: String?, hasSavedGatewayConnection: Bool)
        case markCompleted(OnboardingConnectionMode?)
        case markFirstRunIntroSeen
        case reset
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .refreshPresentation:
                state.refreshPresentation()
                return .none

            case let .gatewaySnapshotChanged(gatewayServerName, hasSavedGatewayConnection):
                state.gatewayServerName = gatewayServerName
                state.hasSavedGatewayConnection = hasSavedGatewayConnection
                state.refreshPresentation()
                return .none

            case let .markCompleted(mode):
                state.isCompleted = true
                if let mode {
                    state.lastMode = mode
                }
                state.refreshPresentation()
                return .none

            case .markFirstRunIntroSeen:
                state.firstRunIntroSeen = true
                state.refreshPresentation()
                return .none

            case .reset:
                state.isCompleted = false
                state.firstRunIntroSeen = false
                state.refreshPresentation()
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct OnboardingPresentationFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var scannerError: String?
        var showGatewayProblemDetails = false
        var showQRScanner = false
    }

    enum Action: Equatable, Sendable {
        case gatewayProblemDetailsButtonTapped
        case gatewayProblemDetailsDismissed
        case qrScannerButtonTapped
        case qrScannerDismissed
        case qrScannerErrorDismissed
        case qrScannerErrorReceived(String)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .gatewayProblemDetailsButtonTapped:
                state.showGatewayProblemDetails = true
                return .none

            case .gatewayProblemDetailsDismissed:
                state.showGatewayProblemDetails = false
                return .none

            case .qrScannerButtonTapped:
                state.showQRScanner = true
                return .none

            case .qrScannerDismissed:
                state.showQRScanner = false
                return .none

            case .qrScannerErrorDismissed:
                state.scannerError = nil
                return .none

            case let .qrScannerErrorReceived(error):
                state.showQRScanner = false
                state.scannerError = error
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct OnboardingSetupCodeFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var setupCode = ""
        var status: String?

        var trimmedSetupCode: String {
            self.setupCode.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var canApply: Bool {
            !self.trimmedSetupCode.isEmpty
        }
    }

    enum Action: Equatable, Sendable {
        case appleReviewDemoCodeAccepted
        case applyStarted
        case emptyCodeSubmitted
        case invalidSetupCodeSubmitted
        case setupCodeAccepted
        case setupCodeChanged(String)
        case statusCleared
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appleReviewDemoCodeAccepted:
                state.setupCode = ""
                state.status = "Apple Review demo mode enabled."
                return .none

            case .applyStarted:
                state.status = nil
                return .none

            case .emptyCodeSubmitted:
                state.status = "Paste a setup code to continue."
                return .none

            case .invalidSetupCodeSubmitted:
                state.status = "Setup code not recognized or uses an insecure ws:// gateway URL."
                return .none

            case .setupCodeAccepted:
                state.setupCode = ""
                state.status = "Setup code applied. Connecting..."
                return .none

            case let .setupCodeChanged(setupCode):
                state.setupCode = setupCode
                return .none

            case .statusCleared:
                state.status = nil
                return .none
            }
        }
        .autoLogActions()
    }
}

enum OnboardingStateStore {
    private static let completedDefaultsKey = "onboarding.completed"
    private static let firstRunIntroSeenDefaultsKey = "onboarding.first_run_intro_seen"
    private static let lastModeDefaultsKey = "onboarding.last_mode"
    private static let lastSuccessTimeDefaultsKey = "onboarding.last_success_time"

    @MainActor
    static func shouldPresentOnLaunch(
        appModel: NodeAppModel,
        defaults: UserDefaults = .standard,
        hasSavedGatewayConnection: Bool? = nil)
        -> Bool
    {
        let hasSavedGatewayConnection =
            hasSavedGatewayConnection ?? (GatewaySettingsStore.loadLastGatewayConnection() != nil)
        return Self.featureState(
            defaults: defaults,
            gatewayServerName: appModel.gatewayServerName,
            hasSavedGatewayConnection: hasSavedGatewayConnection)
            .shouldPresentOnLaunch
    }

    static func markCompleted(mode: OnboardingConnectionMode? = nil, defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: self.completedDefaultsKey)
        if let mode {
            defaults.set(mode.rawValue, forKey: self.lastModeDefaultsKey)
        }
        defaults.set(Int(Date().timeIntervalSince1970), forKey: Self.lastSuccessTimeDefaultsKey)
    }

    static func shouldPresentFirstRunIntro(defaults: UserDefaults = .standard) -> Bool {
        self.featureState(defaults: defaults).shouldPresentFirstRunIntro
    }

    static func markFirstRunIntroSeen(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: self.firstRunIntroSeenDefaultsKey)
    }

    static func reset(defaults: UserDefaults = .standard) {
        defaults.set(false, forKey: self.completedDefaultsKey)
        defaults.set(false, forKey: self.firstRunIntroSeenDefaultsKey)
    }

    static func lastMode(defaults: UserDefaults = .standard) -> OnboardingConnectionMode? {
        let raw = defaults.string(forKey: Self.lastModeDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return nil }
        return OnboardingConnectionMode(rawValue: raw)
    }

    private static func featureState(
        defaults: UserDefaults,
        gatewayServerName: String? = nil,
        hasSavedGatewayConnection: Bool = false)
        -> OnboardingStateFeature.State
    {
        OnboardingStateFeature.State(
            isCompleted: defaults.bool(forKey: self.completedDefaultsKey),
            firstRunIntroSeen: defaults.bool(forKey: self.firstRunIntroSeenDefaultsKey),
            lastMode: self.lastMode(defaults: defaults),
            hasSavedGatewayConnection: hasSavedGatewayConnection,
            gatewayServerName: gatewayServerName)
    }
}
