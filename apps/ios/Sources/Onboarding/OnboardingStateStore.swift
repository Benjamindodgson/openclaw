import ComposableArchitecture
import Foundation
import OpenClawKit

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

// swiftformat:disable redundantSendable
struct OnboardingConnectionID: Equatable, Sendable { var value: String }

struct OnboardingConnectionMessage: Equatable, Sendable { var value: String }

struct OnboardingConnectionStatusLine: Equatable, Sendable { var value: String }

struct OnboardingConnectionStatusMessage: Equatable, Sendable { var value: String? }

struct OnboardingConnectionIssueMessage: Equatable, Sendable { var value: String? }

struct OnboardingConnectionIssueRequestID: Equatable, Sendable { var value: String? }

struct OnboardingConnectionIssueStatusText: Equatable, Sendable { var value: String }

struct OnboardingConnectionPauseReconnect: Equatable, Sendable { var value: Bool }

struct OnboardingConnectionClearsIssue: Equatable, Sendable { var value: Bool }

struct OnboardingGatewayMarkedCompleted: Equatable, Sendable { var value: Bool }

struct OnboardingPairingResumeRequestTime: Equatable, Sendable { var value: Date }

struct OnboardingGatewayServerName: Equatable, Sendable { var value: String? }

struct OnboardingHasSavedGatewayConnection: Equatable, Sendable { var value: Bool }

struct OnboardingGatewayToken: Equatable, Sendable { var value: String }

struct OnboardingGatewayPassword: Equatable, Sendable { var value: String }

struct OnboardingQRMessage: Equatable, Sendable { var value: String? }

struct OnboardingScannerErrorMessage: Equatable, Sendable { var value: String }
// swiftformat:enable redundantSendable

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
        struct GatewaySnapshotChange: Equatable, Sendable {
            var gatewayServerName: OnboardingGatewayServerName
            var hasSavedGatewayConnection: OnboardingHasSavedGatewayConnection
        }

        struct CompletionMark: Equatable, Sendable { var mode: OnboardingConnectionMode? }

        case refreshPresentation
        case gatewaySnapshotChanged(GatewaySnapshotChange)
        case markCompleted(CompletionMark)
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

            case let .gatewaySnapshotChanged(snapshot):
                state.gatewayServerName = snapshot.gatewayServerName.value
                state.hasSavedGatewayConnection = snapshot.hasSavedGatewayConnection.value
                state.refreshPresentation()
                return .none

            case let .markCompleted(mark):
                state.isCompleted = true
                if let mode = mark.mode {
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
        struct StepChange: Equatable, Sendable { var step: OnboardingStep }

        case backButtonTapped
        case stepChanged(StepChange)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .backButtonTapped:
                guard state.step.canGoBack, let previous = state.step.previous else { return .none }
                state.step = previous
                return .none

            case let .stepChanged(change):
                state.step = change.step
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
        struct AutomaticPairingResumeRequest: Equatable, Sendable { var now: OnboardingPairingResumeRequestTime }

        struct ConnectionStart: Equatable, Sendable {
            var id: OnboardingConnectionID
            var message: OnboardingConnectionMessage
            var statusLine: OnboardingConnectionStatusLine
            var clearsIssue: OnboardingConnectionClearsIssue
        }

        struct ConnectionStatusUpdate: Equatable, Sendable {
            var message: OnboardingConnectionStatusMessage
            var statusLine: OnboardingConnectionStatusLine
        }

        struct GatewayConnectionCompletion: Equatable, Sendable {
            var markedCompleted: OnboardingGatewayMarkedCompleted
        }

        struct ConnectionIssueDetection: Equatable, Sendable {
            var issue: GatewayConnectionIssue
            var requestId: OnboardingConnectionIssueRequestID
            var pauseReconnect: OnboardingConnectionPauseReconnect
            var message: OnboardingConnectionIssueMessage
            var statusText: OnboardingConnectionIssueStatusText
        }

        struct ConnectionActivityStart: Equatable, Sendable { var id: OnboardingConnectionID }
        struct ScannerError: Equatable, Sendable { var message: OnboardingScannerErrorMessage }

        case automaticPairingResumeRequested(AutomaticPairingResumeRequest)
        case appleReviewDemoModeEnabled
        case connectionFinished
        case connectionIssueDetected(ConnectionIssueDetection)
        case connectionStarted(ConnectionStart)
        case connectionActivityStarted(ConnectionActivityStart)
        case connectionStatusUpdated(ConnectionStatusUpdate)
        case freshQRScanStarted
        case gatewayConnected(GatewayConnectionCompletion)
        case gatewayProblemResetScanStarted
        case introAdvanced
        case navigationBackStarted
        case noSavedPairingFound
        case pairingResumeStarted
        case qrScannerOpeningStarted
        case scannerErrorReceived(ScannerError)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .automaticPairingResumeRequested(request):
                state.shouldResumePairingAutomatically = false
                guard state.issue.needsPairing, state.connectingGatewayID == nil else { return .none }
                if let last = state.lastPairingAutoResumeAttemptAt {
                    let elapsedSinceLastAttempt = request.now.value.timeIntervalSince(last)
                    if elapsedSinceLastAttempt < 6 {
                        return .none
                    }
                }
                state.lastPairingAutoResumeAttemptAt = request.now.value
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

            case let .connectionIssueDetected(detection):
                state.issue = Self.stickyIssue(
                    current: state.issue,
                    detected: detection.issue,
                    pairingRequestId: state.pairingRequestId)
                if let requestId = detection.requestId.value, !requestId.isEmpty {
                    state.pairingRequestId = requestId
                }
                state.shouldShowAuthStep = state.issue.needsAuthToken
                    || state.issue.needsPairing
                    || detection.pauseReconnect.value

                if let message = detection.message.value {
                    state.connectMessage = message
                    state.statusLine = message
                } else {
                    let trimmedStatus = detection.statusText.value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedStatus.isEmpty {
                        state.connectMessage = trimmedStatus
                        state.statusLine = trimmedStatus
                    }
                }
                return .none

            case let .connectionStarted(start):
                state.connectingGatewayID = start.id.value
                if start.clearsIssue.value {
                    state.issue = .none
                    state.shouldShowAuthStep = false
                }
                state.connectMessage = start.message.value
                state.statusLine = start.statusLine.value
                return .none

            case let .connectionActivityStarted(start):
                state.connectingGatewayID = start.id.value
                return .none

            case let .connectionStatusUpdated(update):
                state.connectMessage = update.message.value
                state.statusLine = update.statusLine.value
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

            case let .gatewayConnected(completion):
                state.statusLine = "Connected."
                if completion.markedCompleted.value {
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
                state.statusLine = "Scanner error: \(error.message.value)"
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
        struct LoadedCredentials: Equatable, Sendable {
            var token: OnboardingGatewayToken
            var password: OnboardingGatewayPassword
        }

        struct ManualCredentialChange: Equatable, Sendable { var value: String }
        struct SetupAuthApplication: Equatable, Sendable {
            var setupAuth: GatewayConnectionController.ManualAuthOverride.SetupAuth
        }

        case credentialsLoaded(LoadedCredentials)
        case gatewayPasswordChanged(ManualCredentialChange)
        case gatewayTokenChanged(ManualCredentialChange)
        case pendingManualAuthOverrideConsumed
        case reset
        case setupAuthApplied(SetupAuthApplication)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .credentialsLoaded(credentials):
                state.gatewayToken = credentials.token.value
                state.gatewayPassword = credentials.password.value
                return .none

            case let .gatewayPasswordChanged(change):
                state.gatewayPassword = change.value
                return .none

            case let .gatewayTokenChanged(change):
                state.gatewayToken = change.value
                return .none

            case .pendingManualAuthOverrideConsumed:
                state.pendingManualAuthOverride = nil
                return .none

            case .reset:
                state.gatewayToken = ""
                state.gatewayPassword = ""
                state.pendingManualAuthOverride = nil
                return .none

            case let .setupAuthApplied(application):
                if application.setupAuth.shouldApplyTokenField {
                    state.gatewayToken = application.setupAuth.token
                }
                if application.setupAuth.shouldApplyPasswordField {
                    state.gatewayPassword = application.setupAuth.password
                }
                state.pendingManualAuthOverride = application.setupAuth.manualAuthOverride
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
        struct QRScannerError: Equatable, Sendable { var message: OnboardingScannerErrorMessage }

        case gatewayProblemDetailsButtonTapped
        case gatewayProblemDetailsDismissed
        case qrScannerButtonTapped
        case qrScannerDismissed
        case qrScannerErrorDismissed
        case qrScannerErrorReceived(QRScannerError)
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
                state.scannerError = error.message.value
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct OnboardingDiscoveryRestartFeature {
    private let sleepOverride: OnboardingDiscoveryRestartSleepClient?

    private enum CancelID {
        case restart
    }

    init(sleeper: OnboardingDiscoveryRestartSleepClient? = nil) {
        self.sleepOverride = sleeper
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var restartRequestID = 0
    }

    enum Action: Equatable, Sendable {
        case disappeared
        case discoveryDomainChanged
        case restartDelayElapsed
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.onboardingDiscoveryRestartSleep) var dependencySleeper
            let sleeper = self.sleepOverride ?? dependencySleeper

            switch action {
            case .discoveryDomainChanged:
                return .run { send in
                    try await sleeper.sleep()
                    await send(.restartDelayElapsed)
                }
                .cancellable(id: CancelID.restart, cancelInFlight: true)

            case .restartDelayElapsed:
                state.restartRequestID &+= 1
                return .none

            case .disappeared:
                return .cancel(id: CancelID.restart)
            }
        }
        .autoLogActions()
    }
}

struct OnboardingDiscoveryRestartSleepClient {
    var sleep: @Sendable () async throws -> Void
}

extension OnboardingDiscoveryRestartSleepClient: DependencyKey {
    static let liveValue = OnboardingDiscoveryRestartSleepClient(sleep: {
        try await Task.sleep(nanoseconds: 350_000_000)
    })

    static let testValue = OnboardingDiscoveryRestartSleepClient(sleep: {})
}

extension DependencyValues {
    var onboardingDiscoveryRestartSleep: OnboardingDiscoveryRestartSleepClient {
        get { self[OnboardingDiscoveryRestartSleepClient.self] }
        set { self[OnboardingDiscoveryRestartSleepClient.self] = newValue }
    }
}

@Reducer
struct OnboardingQRPhotoImportFeature {
    static let imageLoadFailureMessage = "Could not load the selected image."
    static let invalidQRCodeMessage = "No valid QR code found in the selected image."

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var isImporting = false
        var result: ImportResult?
    }

    enum ImportResult: Equatable, Sendable {
        struct AppleReviewSetupCode: Equatable, Sendable { var code: String }
        struct Failure: Equatable, Sendable { var message: String }

        case appleReviewSetupCode(AppleReviewSetupCode)
        case failure(Failure)
        case gatewayLink(GatewayConnectDeepLink)
    }

    enum Action: Equatable, Sendable {
        struct QRMessageDetection: Equatable, Sendable { var message: OnboardingQRMessage }

        case imageLoadFailed
        case importStarted
        case qrMessageDetected(QRMessageDetection)
        case resultHandled
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .imageLoadFailed:
                state.isImporting = false
                state.result = .failure(.init(message: Self.imageLoadFailureMessage))
                return .none

            case .importStarted:
                state.isImporting = true
                state.result = nil
                return .none

            case let .qrMessageDetected(detection):
                state.isImporting = false
                state.result = Self.importResult(message: detection.message.value)
                return .none

            case .resultHandled:
                state.result = nil
                return .none
            }
        }
        .autoLogActions()
    }

    private static func importResult(message: String?) -> ImportResult {
        guard let message else {
            return .failure(.init(message: self.invalidQRCodeMessage))
        }
        if let link = GatewayConnectDeepLink.fromSetupInput(message) {
            return .gatewayLink(link)
        }
        if AppleReviewDemoMode.isSetupCode(message) {
            return .appleReviewSetupCode(.init(code: message))
        }
        return .failure(.init(message: Self.invalidQRCodeMessage))
    }
}

@Reducer
struct OnboardingSetupCodeFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var applyResult: ApplyResult?
        var setupCode = ""
        var status: String?

        var trimmedSetupCode: String {
            self.setupCode.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var canApply: Bool {
            !self.trimmedSetupCode.isEmpty
        }
    }

    enum ApplyResult: Equatable, Sendable {
        struct AppleReviewDemoSetupCode: Equatable, Sendable { var code: String }

        case appleReviewDemoSetupCode(AppleReviewDemoSetupCode)
        case gatewayLink(GatewayConnectDeepLink)
    }

    enum Action: Equatable, Sendable {
        struct ScannedGatewayLink: Equatable, Sendable { var link: GatewayConnectDeepLink }
        struct ScannedSetupCode: Equatable, Sendable { var code: String }
        struct SetupCodeChange: Equatable, Sendable { var code: String }

        case appleReviewDemoCodeAccepted
        case applyRequested
        case applyResultHandled
        case applyStarted
        case emptyCodeSubmitted
        case invalidSetupCodeSubmitted
        case scannedGatewayLinkReceived(ScannedGatewayLink)
        case scannedSetupCodeReceived(ScannedSetupCode)
        case setupCodeAccepted
        case setupCodeChanged(SetupCodeChange)
        case statusCleared
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appleReviewDemoCodeAccepted:
                state.applyResult = nil
                state.setupCode = ""
                state.status = "Apple Review demo mode enabled."
                return .none

            case .applyRequested:
                state.applyResult = nil
                state.status = nil
                let raw = state.trimmedSetupCode
                guard !raw.isEmpty else {
                    state.status = "Paste a setup code to continue."
                    return .none
                }

                if AppleReviewDemoMode.isSetupCode(raw) {
                    state.setupCode = ""
                    state.status = "Apple Review demo mode enabled."
                    state.applyResult = .appleReviewDemoSetupCode(.init(code: raw))
                    return .none
                }

                guard let link = GatewayConnectDeepLink.fromSetupInput(raw) else {
                    state.status = "Setup code not recognized or uses an insecure ws:// gateway URL."
                    return .none
                }
                state.setupCode = ""
                state.status = "Setup code applied. Connecting..."
                state.applyResult = .gatewayLink(link)
                return .none

            case .applyResultHandled:
                state.applyResult = nil
                return .none

            case .applyStarted:
                state.applyResult = nil
                state.status = nil
                return .none

            case .emptyCodeSubmitted:
                state.applyResult = nil
                state.status = "Paste a setup code to continue."
                return .none

            case .invalidSetupCodeSubmitted:
                state.applyResult = nil
                state.status = "Setup code not recognized or uses an insecure ws:// gateway URL."
                return .none

            case let .scannedGatewayLinkReceived(scan):
                state.applyResult = nil
                state.status = nil
                state.applyResult = .gatewayLink(scan.link)
                return .none

            case let .scannedSetupCodeReceived(scan):
                state.applyResult = nil
                guard AppleReviewDemoMode.isSetupCode(scan.code) else {
                    return .none
                }
                state.applyResult = .appleReviewDemoSetupCode(.init(
                    code: scan.code.trimmingCharacters(in: .whitespacesAndNewlines)))
                return .none

            case .setupCodeAccepted:
                state.applyResult = nil
                state.setupCode = ""
                state.status = "Setup code applied. Connecting..."
                return .none

            case let .setupCodeChanged(change):
                state.setupCode = change.code
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
        var manualConnectionRequest: ManualConnectionRequest?
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

    struct ManualConnectionRequest: Equatable, Sendable {
        var host: String
        var port: Int
        var useTLS: Bool
    }

    enum Action: Equatable, Sendable {
        struct ManualHostChange: Equatable, Sendable { var host: String }
        struct ManualPortTextChange: Equatable, Sendable { var text: String }
        struct ManualTLSChange: Equatable, Sendable { var useTLS: Bool }
        struct ModeSelection: Equatable, Sendable { var mode: OnboardingConnectionMode }
        struct SelectedModeChange: Equatable, Sendable { var mode: OnboardingConnectionMode? }
        struct GatewayLinkApplication: Equatable, Sendable {
            var host: String
            var port: Int
            var tls: Bool
        }

        struct Initialization: Equatable, Sendable {
            var host: String
            var port: Int
            var tls: Bool
            var lastMode: OnboardingConnectionMode?
        }

        case developerModeDisabled
        case gatewayLinkApplied(GatewayLinkApplication)
        case initialized(Initialization)
        case manualConnectionRequested
        case manualConnectionRequestHandled
        case manualHostChanged(ManualHostChange)
        case manualPortTextChanged(ManualPortTextChange)
        case manualTLSChanged(ManualTLSChange)
        case modeSelected(ModeSelection)
        case selectedModeChanged(SelectedModeChange)
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

            case let .gatewayLinkApplied(application):
                state.manualHost = application.host
                state.manualPort = application.port
                state.syncManualPortText()
                state.manualTLS = application.tls
                if state.selectedMode == nil {
                    state.selectedMode = application.tls ? .remoteDomain : .homeNetwork
                }
                return .none

            case let .initialized(initialization):
                if state.normalizedManualHost.isEmpty {
                    state.manualHost = initialization.host
                    state.manualPort = initialization.port
                    state.manualTLS = initialization.tls
                }
                state.syncManualPortText()
                if state.selectedMode == nil {
                    state.selectedMode = initialization.lastMode
                }
                if state.selectedMode == .developerLocal, state.manualHost == "openclaw.local" {
                    state.manualHost = "localhost"
                    state.manualTLS = false
                }
                return .none

            case .manualConnectionRequested:
                state.manualConnectionRequest = nil
                let host = state.normalizedManualHost
                guard !host.isEmpty, state.manualPort > 0, state.manualPort <= 65535 else {
                    return .none
                }
                state.manualConnectionRequest = ManualConnectionRequest(
                    host: host,
                    port: state.manualPort,
                    useTLS: state.manualTLS)
                return .none

            case .manualConnectionRequestHandled:
                state.manualConnectionRequest = nil
                return .none

            case let .manualHostChanged(change):
                state.manualHost = change.host
                return .none

            case let .manualPortTextChanged(change):
                let digits = change.text.filter(\.isNumber)
                guard let parsed = Int(digits), parsed > 0 else {
                    state.manualPort = 0
                    state.manualPortText = ""
                    return .none
                }
                state.manualPort = min(parsed, 65535)
                state.syncManualPortText()
                return .none

            case let .manualTLSChanged(change):
                state.manualTLS = change.useTLS
                return .none

            case let .modeSelected(selection):
                state.selectedMode = selection.mode
                state.applyModeDefaults(selection.mode)
                return .none

            case let .selectedModeChanged(change):
                state.selectedMode = change.mode
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
