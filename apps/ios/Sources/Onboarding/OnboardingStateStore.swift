import ComposableArchitecture
import Foundation

enum OnboardingStep: Int, CaseIterable {
    case intro
    case welcome
    case mode
    case connect
    case auth
    case success

    var previous: Self? {
        Self(rawValue: self.rawValue - 1)
    }

    /// Progress label for the manual setup flow (mode -> connect -> auth -> success).
    var manualProgressTitle: String {
        let manualSteps: [OnboardingStep] = [.mode, .connect, .auth, .success]
        guard let idx = manualSteps.firstIndex(of: self) else { return "" }
        return "Step \(idx + 1) of \(manualSteps.count)"
    }

    var title: String {
        switch self {
        case .intro: "Welcome"
        case .welcome: "Connect Gateway"
        case .mode: "Connection Mode"
        case .connect: "Connect"
        case .auth: "Authentication"
        case .success: "Connected"
        }
    }

    var canGoBack: Bool {
        self != .intro && self != .welcome && self != .success
    }
}

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
struct OnboardingStepFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var step: OnboardingStep

        init(step: OnboardingStep = .welcome) {
            self.step = step
        }

        var isFullScreenStep: Bool {
            self.step == .intro || self.step == .welcome || self.step == .success
        }
    }

    enum Action: Equatable, Sendable {
        case backButtonTapped
        case stepChanged(OnboardingStep)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .backButtonTapped:
                guard state.step.canGoBack, let previous = state.step.previous else { return .none }
                state.step = previous
                return .none

            case let .stepChanged(step):
                state.step = step
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct OnboardingStatusFeature {
    static let defaultStatusLine = "In your OpenClaw chat, run /pair qr, then scan the code here."
    static let noSavedPairingStatusLine =
        "No saved pairing found. In your OpenClaw chat, run /pair qr, then scan the code here."

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var connectMessage: String?
        var connectingGatewayID: String?
        var didMarkCompleted = false
        var issue: GatewayConnectionIssue = .none
        var lastPairingAutoResumeAttemptAt: Date?
        var pairingRequestId: String?
        var shouldResumePairingAutomatically = false
        var shouldShowAuthStep = false
        var statusLine: String

        init(statusLine: String = OnboardingStatusFeature.defaultStatusLine) {
            self.statusLine = statusLine
        }
    }

    enum Action: Equatable, Sendable {
        case automaticPairingResumeRequested(now: Date)
        case appleReviewDemoModeEnabled
        case connectionFinished
        case connectionIssueDetected(
            issue: GatewayConnectionIssue,
            requestId: String?,
            pauseReconnect: Bool,
            message: String?,
            statusText: String)
        case connectionStarted(id: String, message: String, statusLine: String, clearsIssue: Bool)
        case connectionActivityStarted(id: String)
        case connectionStatusUpdated(message: String?, statusLine: String)
        case freshQRScanStarted
        case gatewayConnected(markedCompleted: Bool)
        case gatewayProblemResetScanStarted
        case introAdvanced
        case navigationBackStarted
        case noSavedPairingFound
        case pairingResumeStarted
        case qrScannerOpeningStarted
        case scannerErrorReceived(String)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .automaticPairingResumeRequested(now):
                state.shouldResumePairingAutomatically = false
                guard state.issue.needsPairing, state.connectingGatewayID == nil else { return .none }
                if let last = state.lastPairingAutoResumeAttemptAt, now.timeIntervalSince(last) < 6 {
                    return .none
                }
                state.lastPairingAutoResumeAttemptAt = now
                state.shouldResumePairingAutomatically = true
                return .none

            case .appleReviewDemoModeEnabled:
                state.connectingGatewayID = nil
                state.connectMessage = "Apple Review demo mode enabled."
                state.statusLine = "Apple Review demo mode enabled."
                return .none

            case .connectionFinished:
                state.connectingGatewayID = nil
                return .none

            case let .connectionIssueDetected(issue, requestId, pauseReconnect, message, statusText):
                state.issue = Self.stickyIssue(
                    current: state.issue,
                    detected: issue,
                    pairingRequestId: state.pairingRequestId)
                if let requestId, !requestId.isEmpty {
                    state.pairingRequestId = requestId
                }
                state.shouldShowAuthStep = state.issue.needsAuthToken || state.issue.needsPairing || pauseReconnect

                if let message {
                    state.connectMessage = message
                    state.statusLine = message
                } else {
                    let trimmedStatus = statusText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedStatus.isEmpty {
                        state.connectMessage = trimmedStatus
                        state.statusLine = trimmedStatus
                    }
                }
                return .none

            case let .connectionStarted(id, message, statusLine, clearsIssue):
                state.connectingGatewayID = id
                if clearsIssue {
                    state.issue = .none
                    state.shouldShowAuthStep = false
                }
                state.connectMessage = message
                state.statusLine = statusLine
                return .none

            case let .connectionActivityStarted(id):
                state.connectingGatewayID = id
                return .none

            case let .connectionStatusUpdated(message, statusLine):
                state.connectMessage = message
                state.statusLine = statusLine
                return .none

            case .freshQRScanStarted:
                state.connectingGatewayID = nil
                state.connectMessage = nil
                state.issue = .none
                state.lastPairingAutoResumeAttemptAt = nil
                state.pairingRequestId = nil
                state.shouldResumePairingAutomatically = false
                state.shouldShowAuthStep = false
                state.statusLine = "Opening QR scanner…"
                return .none

            case let .gatewayConnected(markedCompleted):
                state.statusLine = "Connected."
                if markedCompleted {
                    state.didMarkCompleted = true
                }
                return .none

            case .gatewayProblemResetScanStarted:
                state.connectingGatewayID = nil
                state.connectMessage = nil
                state.issue = .none
                state.lastPairingAutoResumeAttemptAt = nil
                state.pairingRequestId = nil
                state.shouldResumePairingAutomatically = false
                state.shouldShowAuthStep = false
                state.statusLine = "Scan a fresh setup QR code from this gateway."
                return .none

            case .introAdvanced:
                state.statusLine = Self.defaultStatusLine
                return .none

            case .navigationBackStarted:
                state.connectingGatewayID = nil
                state.connectMessage = nil
                return .none

            case .noSavedPairingFound:
                state.statusLine = Self.noSavedPairingStatusLine
                return .none

            case .pairingResumeStarted:
                state.issue = .none
                state.shouldResumePairingAutomatically = false
                state.shouldShowAuthStep = false
                state.connectMessage = "Retrying after approval…"
                state.statusLine = "Retrying after approval…"
                return .none

            case .qrScannerOpeningStarted:
                state.statusLine = "Opening QR scanner…"
                return .none

            case let .scannerErrorReceived(error):
                state.statusLine = "Scanner error: \(error)"
                return .none
            }
        }
        .autoLogActions()
    }

    private static func stickyIssue(
        current: GatewayConnectionIssue,
        detected: GatewayConnectionIssue,
        pairingRequestId: String?)
        -> GatewayConnectionIssue
    {
        if current.needsPairing, detected.needsPairing {
            let mergedRequestId = detected.requestId ?? current.requestId ?? pairingRequestId
            return .pairingRequired(requestId: mergedRequestId)
        }
        if current.needsPairing, !detected.needsPairing {
            return current
        }
        if current.needsAuthToken, !detected.needsAuthToken, !detected.needsPairing {
            return current
        }
        return detected
    }
}

@Reducer
struct OnboardingCredentialsFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var gatewayPassword = ""
        var gatewayToken = ""
        var pendingManualAuthOverride: GatewayConnectionController.ManualAuthOverride?

        var hasGatewayPassword: Bool {
            !self.gatewayPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        var hasGatewayToken: Bool {
            !self.gatewayToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    enum Action: Equatable, Sendable {
        case credentialsLoaded(token: String, password: String)
        case gatewayPasswordChanged(String)
        case gatewayTokenChanged(String)
        case pendingManualAuthOverrideConsumed
        case reset
        case setupAuthApplied(GatewayConnectionController.ManualAuthOverride.SetupAuth)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .credentialsLoaded(token, password):
                state.gatewayToken = token
                state.gatewayPassword = password
                return .none

            case let .gatewayPasswordChanged(password):
                state.gatewayPassword = password
                return .none

            case let .gatewayTokenChanged(token):
                state.gatewayToken = token
                return .none

            case .pendingManualAuthOverrideConsumed:
                state.pendingManualAuthOverride = nil
                return .none

            case .reset:
                state.gatewayToken = ""
                state.gatewayPassword = ""
                state.pendingManualAuthOverride = nil
                return .none

            case let .setupAuthApplied(setupAuth):
                if setupAuth.shouldApplyTokenField {
                    state.gatewayToken = setupAuth.token
                }
                if setupAuth.shouldApplyPasswordField {
                    state.gatewayPassword = setupAuth.password
                }
                state.pendingManualAuthOverride = setupAuth.manualAuthOverride
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

@Reducer
struct OnboardingConnectionFormFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var selectedMode: OnboardingConnectionMode?
        var manualHost = ""
        var manualPort = 18789
        var manualPortText = "18789"
        var manualTLS = true

        var normalizedManualHost: String {
            self.manualHost.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var canConnectManual: Bool {
            !self.normalizedManualHost.isEmpty && self.manualPort > 0 && self.manualPort <= 65535
        }

        mutating func syncManualPortText() {
            self.manualPortText = self.manualPort > 0 ? String(self.manualPort) : ""
        }

        mutating func applyModeDefaults(_ mode: OnboardingConnectionMode) {
            let host = self.normalizedManualHost.lowercased()
            let hostIsDefaultLike = host.isEmpty || host == "openclaw.local" || host == "localhost"

            switch mode {
            case .homeNetwork:
                if hostIsDefaultLike { self.manualHost = "openclaw.local" }
                self.manualTLS = true
            case .remoteDomain:
                if host == "openclaw.local" || host == "localhost" { self.manualHost = "" }
                self.manualTLS = true
            case .developerLocal:
                if hostIsDefaultLike { self.manualHost = "localhost" }
                self.manualTLS = false
            }

            if self.manualPort <= 0 || self.manualPort > 65535 {
                self.manualPort = 18789
            }
            self.syncManualPortText()
        }
    }

    enum Action: Equatable, Sendable {
        case developerModeDisabled
        case gatewayLinkApplied(host: String, port: Int, tls: Bool)
        case initialized(host: String, port: Int, tls: Bool, lastMode: OnboardingConnectionMode?)
        case manualHostChanged(String)
        case manualPortTextChanged(String)
        case manualTLSChanged(Bool)
        case modeSelected(OnboardingConnectionMode)
        case selectedModeChanged(OnboardingConnectionMode?)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .developerModeDisabled:
                if state.selectedMode == .developerLocal {
                    state.selectedMode = nil
                }
                return .none

            case let .gatewayLinkApplied(host, port, tls):
                state.manualHost = host
                state.manualPort = port
                state.syncManualPortText()
                state.manualTLS = tls
                if state.selectedMode == nil {
                    state.selectedMode = tls ? .remoteDomain : .homeNetwork
                }
                return .none

            case let .initialized(host, port, tls, lastMode):
                if state.normalizedManualHost.isEmpty {
                    state.manualHost = host
                    state.manualPort = port
                    state.manualTLS = tls
                }
                state.syncManualPortText()
                if state.selectedMode == nil {
                    state.selectedMode = lastMode
                }
                if state.selectedMode == .developerLocal, state.manualHost == "openclaw.local" {
                    state.manualHost = "localhost"
                    state.manualTLS = false
                }
                return .none

            case let .manualHostChanged(host):
                state.manualHost = host
                return .none

            case let .manualPortTextChanged(portText):
                let digits = portText.filter(\.isNumber)
                guard let parsed = Int(digits), parsed > 0 else {
                    state.manualPort = 0
                    state.manualPortText = ""
                    return .none
                }
                state.manualPort = min(parsed, 65535)
                state.syncManualPortText()
                return .none

            case let .manualTLSChanged(tls):
                state.manualTLS = tls
                return .none

            case let .modeSelected(mode):
                state.selectedMode = mode
                state.applyModeDefaults(mode)
                return .none

            case let .selectedModeChanged(mode):
                state.selectedMode = mode
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
