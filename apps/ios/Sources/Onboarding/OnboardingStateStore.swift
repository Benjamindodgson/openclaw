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

struct OnboardingAutomaticPairingResume: Equatable, Sendable { var shouldResume: Bool }

struct OnboardingAuthStepPresentation: Equatable, Sendable { var shouldShow: Bool }

struct OnboardingPairingResumeRequestTime: Equatable, Sendable { var value: Date }

struct OnboardingCompletion: Equatable, Sendable { var isCompleted: Bool }

struct OnboardingFirstRunIntroSeen: Equatable, Sendable { var value: Bool }

struct OnboardingGatewayServerName: Equatable, Sendable { var value: String? }

struct OnboardingHasSavedGatewayConnection: Equatable, Sendable { var value: Bool }

struct OnboardingLaunchPresentation: Equatable, Sendable { var shouldPresent: Bool }

struct OnboardingFirstRunIntroPresentation: Equatable, Sendable { var shouldPresent: Bool }

struct OnboardingGatewayToken: Equatable, Sendable { var value: String }

struct OnboardingGatewayPassword: Equatable, Sendable { var value: String }

struct OnboardingGatewayCurrentInstanceID: Equatable, Sendable {
    var value: String

    var trimmedValue: String? {
        let trimmed = self.value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct OnboardingQRMessage: Equatable, Sendable { var value: String? }

struct OnboardingQRPhotoImportFailureMessage: Equatable, Sendable { var value: String }

struct OnboardingSetupCode: Equatable, Sendable { var value: String }

struct OnboardingSetupCodeStatusMessage: Equatable, Sendable { var value: String? }

struct OnboardingDiscoveryRestartRequestID: Equatable, Sendable { var value: Int }

struct OnboardingManualHost: Equatable, Sendable { var value: String }

struct OnboardingManualPort: Equatable, Sendable { var value: Int }

struct OnboardingManualPortText: Equatable, Sendable { var value: String }

struct OnboardingManualTLS: Equatable, Sendable { var value: Bool }

struct OnboardingScannerErrorMessage: Equatable, Sendable { var value: String }
// swiftformat:enable redundantSendable

@Reducer
struct OnboardingStateFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var completion: OnboardingCompletion
        var firstRunIntroSeenState: OnboardingFirstRunIntroSeen
        var lastMode: OnboardingConnectionMode?
        var savedGatewayConnection: OnboardingHasSavedGatewayConnection
        var gatewayServerNameState: OnboardingGatewayServerName
        var launchPresentation: OnboardingLaunchPresentation
        var firstRunIntroPresentation: OnboardingFirstRunIntroPresentation

        init(
            isCompleted: Bool = false,
            firstRunIntroSeen: Bool = false,
            lastMode: OnboardingConnectionMode? = nil,
            hasSavedGatewayConnection: Bool = false,
            gatewayServerName: String? = nil)
        {
            self.completion = .init(isCompleted: isCompleted)
            self.firstRunIntroSeenState = .init(value: firstRunIntroSeen)
            self.lastMode = lastMode
            self.savedGatewayConnection = .init(value: hasSavedGatewayConnection)
            self.gatewayServerNameState = .init(value: gatewayServerName)
            self.launchPresentation = .init(shouldPresent: false)
            self.firstRunIntroPresentation = .init(shouldPresent: true)
            self.refreshPresentation()
        }

        var gatewayServerName: String? {
            self.gatewayServerNameState.value
        }

        var shouldPresentOnLaunch: Bool {
            self.launchPresentation.shouldPresent
        }

        var shouldPresentFirstRunIntro: Bool {
            self.firstRunIntroPresentation.shouldPresent
        }

        mutating func refreshPresentation() {
            self.launchPresentation = .init(shouldPresent:
                !self.completion.isCompleted &&
                    !self.savedGatewayConnection.value &&
                    self.gatewayServerName == nil)
            self.firstRunIntroPresentation = .init(shouldPresent: !self.firstRunIntroSeenState.value)
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
                state.gatewayServerNameState = snapshot.gatewayServerName
                state.savedGatewayConnection = snapshot.hasSavedGatewayConnection
                state.refreshPresentation()
                return .none

            case let .markCompleted(mark):
                state.completion = .init(isCompleted: true)
                if let mode = mark.mode {
                    state.lastMode = mode
                }
                state.refreshPresentation()
                return .none

            case .markFirstRunIntroSeen:
                state.firstRunIntroSeenState = .init(value: true)
                state.refreshPresentation()
                return .none

            case .reset:
                state.completion = .init(isCompleted: false)
                state.firstRunIntroSeenState = .init(value: false)
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
        var connectMessageState = OnboardingConnectionStatusMessage(value: nil)
        var connectingGatewayIDState: OnboardingConnectionID?
        var completionMark = OnboardingGatewayMarkedCompleted(value: false)
        var issue: GatewayConnectionIssue = .none
        var lastPairingAutoResumeAttemptState: OnboardingPairingResumeRequestTime?
        var pairingRequestIdState = OnboardingConnectionIssueRequestID(value: nil)
        var automaticPairingResume = OnboardingAutomaticPairingResume(shouldResume: false)
        var authStepPresentation = OnboardingAuthStepPresentation(shouldShow: false)
        var statusLineState: OnboardingConnectionStatusLine

        init(statusLine: String = OnboardingStatusFeature.defaultStatusLine) {
            self.statusLineState = .init(value: statusLine)
        }

        var connectMessage: String? {
            self.connectMessageState.value
        }

        var connectingGatewayID: String? {
            self.connectingGatewayIDState?.value
        }

        var pairingRequestId: String? {
            self.pairingRequestIdState.value
        }

        var lastPairingAutoResumeAttemptAt: Date? {
            self.lastPairingAutoResumeAttemptState?.value
        }

        var statusLine: String {
            self.statusLineState.value
        }

        var didMarkCompleted: Bool {
            self.completionMark.value
        }

        var shouldResumePairingAutomatically: Bool {
            self.automaticPairingResume.shouldResume
        }

        var shouldShowAuthStep: Bool {
            self.authStepPresentation.shouldShow
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
                state.automaticPairingResume = .init(shouldResume: false)
                guard state.issue.needsPairing, state.connectingGatewayID == nil else { return .none }
                if let last = state.lastPairingAutoResumeAttemptAt {
                    let elapsedSinceLastAttempt = request.now.value.timeIntervalSince(last)
                    if elapsedSinceLastAttempt < 6 {
                        return .none
                    }
                }
                state.lastPairingAutoResumeAttemptState = request.now
                state.automaticPairingResume = .init(shouldResume: true)
                return .none

            case .appleReviewDemoModeEnabled:
                state.connectingGatewayIDState = nil
                state.connectMessageState = .init(value: "Apple Review demo mode enabled.")
                state.statusLineState = .init(value: "Apple Review demo mode enabled.")
                return .none

            case .connectionFinished:
                state.connectingGatewayIDState = nil
                return .none

            case let .connectionIssueDetected(detection):
                state.issue = Self.stickyIssue(
                    current: state.issue,
                    detected: detection.issue,
                    pairingRequestId: state.pairingRequestId)
                if let requestId = detection.requestId.value, !requestId.isEmpty {
                    state.pairingRequestIdState = .init(value: requestId)
                }
                state.authStepPresentation = .init(shouldShow:
                    state.issue.needsAuthToken
                        || state.issue.needsPairing
                        || detection.pauseReconnect.value)

                if let message = detection.message.value {
                    state.connectMessageState = .init(value: message)
                    state.statusLineState = .init(value: message)
                } else {
                    let trimmedStatus = detection.statusText.value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedStatus.isEmpty {
                        state.connectMessageState = .init(value: trimmedStatus)
                        state.statusLineState = .init(value: trimmedStatus)
                    }
                }
                return .none

            case let .connectionStarted(start):
                state.connectingGatewayIDState = start.id
                if start.clearsIssue.value {
                    state.issue = .none
                    state.authStepPresentation = .init(shouldShow: false)
                }
                state.connectMessageState = .init(value: start.message.value)
                state.statusLineState = start.statusLine
                return .none

            case let .connectionActivityStarted(start):
                state.connectingGatewayIDState = start.id
                return .none

            case let .connectionStatusUpdated(update):
                state.connectMessageState = update.message
                state.statusLineState = update.statusLine
                return .none

            case .freshQRScanStarted:
                state.connectingGatewayIDState = nil
                state.connectMessageState = .init(value: nil)
                state.issue = .none
                state.lastPairingAutoResumeAttemptState = nil
                state.pairingRequestIdState = .init(value: nil)
                state.automaticPairingResume = .init(shouldResume: false)
                state.authStepPresentation = .init(shouldShow: false)
                state.statusLineState = .init(value: "Opening QR scanner…")
                return .none

            case let .gatewayConnected(completion):
                state.statusLineState = .init(value: "Connected.")
                if completion.markedCompleted.value {
                    state.completionMark = completion.markedCompleted
                }
                return .none

            case .gatewayProblemResetScanStarted:
                state.connectingGatewayIDState = nil
                state.connectMessageState = .init(value: nil)
                state.issue = .none
                state.lastPairingAutoResumeAttemptState = nil
                state.pairingRequestIdState = .init(value: nil)
                state.automaticPairingResume = .init(shouldResume: false)
                state.authStepPresentation = .init(shouldShow: false)
                state.statusLineState = .init(value: "Scan a fresh setup QR code from this gateway.")
                return .none

            case .introAdvanced:
                state.statusLineState = .init(value: Self.defaultStatusLine)
                return .none

            case .navigationBackStarted:
                state.connectingGatewayIDState = nil
                state.connectMessageState = .init(value: nil)
                return .none

            case .noSavedPairingFound:
                state.statusLineState = .init(value: Self.noSavedPairingStatusLine)
                return .none

            case .pairingResumeStarted:
                state.issue = .none
                state.automaticPairingResume = .init(shouldResume: false)
                state.authStepPresentation = .init(shouldShow: false)
                state.connectMessageState = .init(value: "Retrying after approval…")
                state.statusLineState = .init(value: "Retrying after approval…")
                return .none

            case .qrScannerOpeningStarted:
                state.statusLineState = .init(value: "Opening QR scanner…")
                return .none

            case let .scannerErrorReceived(error):
                state.statusLineState = .init(value: "Scanner error: \(error.message.value)")
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

struct OnboardingGatewaySetupAuthPersistenceRequest: Equatable {
    let setupAuth: GatewayConnectionController.ManualAuthOverride.SetupAuth
    let instanceId: OnboardingGatewayCurrentInstanceID

    var hasBootstrapToken: Bool {
        self.setupAuth.hasBootstrapToken
    }

    var trimmedInstanceId: String? {
        self.instanceId.trimmedValue
    }
}

struct OnboardingGatewaySetupAuthPersistenceClient {
    var currentInstanceID: @Sendable () -> OnboardingGatewayCurrentInstanceID
    var prepareForBootstrapPairing: @MainActor @Sendable (_ instanceId: OnboardingGatewayCurrentInstanceID) -> Void
    var saveSetupAuth: @MainActor @Sendable (_ request: OnboardingGatewaySetupAuthPersistenceRequest) -> Void

    init(
        currentInstanceID: @escaping @Sendable () -> OnboardingGatewayCurrentInstanceID,
        prepareForBootstrapPairing: @escaping @MainActor @Sendable (
            _ instanceId: OnboardingGatewayCurrentInstanceID) -> Void = { _ in },
        saveSetupAuth: @escaping @MainActor @Sendable (_ request: OnboardingGatewaySetupAuthPersistenceRequest) -> Void)
    {
        self.currentInstanceID = currentInstanceID
        self.prepareForBootstrapPairing = prepareForBootstrapPairing
        self.saveSetupAuth = saveSetupAuth
    }
}

extension OnboardingGatewaySetupAuthPersistenceClient: DependencyKey {
    static let liveValue = OnboardingGatewaySetupAuthPersistenceClient(
        currentInstanceID: {
            .init(value: GatewaySettingsStore.currentInstanceID())
        },
        saveSetupAuth: { request in
            guard let instanceId = request.trimmedInstanceId else { return }

            let bootstrapToken = request.setupAuth.bootstrapToken.trimmingCharacters(in: .whitespacesAndNewlines)
            GatewaySettingsStore.saveGatewayBootstrapToken(bootstrapToken, instanceId: instanceId)
            if request.setupAuth.shouldApplyTokenField {
                let token = request.setupAuth.token.trimmingCharacters(in: .whitespacesAndNewlines)
                GatewaySettingsStore.saveGatewayToken(token, instanceId: instanceId)
            }
            if request.setupAuth.shouldApplyPasswordField {
                let password = request.setupAuth.password.trimmingCharacters(in: .whitespacesAndNewlines)
                GatewaySettingsStore.saveGatewayPassword(password, instanceId: instanceId)
            }
        })

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        OnboardingGatewaySetupAuthPersistenceClient(
            currentInstanceID: {
                .init(value: GatewaySettingsStore.currentInstanceID())
            },
            prepareForBootstrapPairing: { instanceId in
                guard let instanceId = instanceId.trimmedValue else { return }
                GatewayOnboardingReset.prepareForBootstrapPairing(appModel: appModel, instanceId: instanceId)
            },
            saveSetupAuth: self.liveValue.saveSetupAuth)
    }

    static let testValue = OnboardingGatewaySetupAuthPersistenceClient(
        currentInstanceID: { .init(value: "") },
        saveSetupAuth: { _ in })
}

extension DependencyValues {
    var onboardingGatewaySetupAuthPersistence: OnboardingGatewaySetupAuthPersistenceClient {
        get { self[OnboardingGatewaySetupAuthPersistenceClient.self] }
        set { self[OnboardingGatewaySetupAuthPersistenceClient.self] = newValue }
    }
}

@Reducer
struct OnboardingCredentialsFeature {
    private let setupAuthPersistenceClientOverride: OnboardingGatewaySetupAuthPersistenceClient?

    init(setupAuthPersistenceClient: OnboardingGatewaySetupAuthPersistenceClient? = nil) {
        self.setupAuthPersistenceClientOverride = setupAuthPersistenceClient
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var gatewayPasswordState = OnboardingGatewayPassword(value: "")
        var gatewayTokenState = OnboardingGatewayToken(value: "")
        var pendingManualAuthOverride: GatewayConnectionController.ManualAuthOverride?
        var setupAuthPersistenceRequest: OnboardingGatewaySetupAuthPersistenceRequest?

        var gatewayPassword: String {
            self.gatewayPasswordState.value
        }

        var gatewayToken: String {
            self.gatewayTokenState.value
        }

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

        struct GatewayPasswordChange: Equatable, Sendable { var password: OnboardingGatewayPassword }
        struct GatewayTokenChange: Equatable, Sendable { var token: OnboardingGatewayToken }
        struct SetupAuthApplication: Equatable, Sendable {
            var setupAuth: GatewayConnectionController.ManualAuthOverride.SetupAuth
        }

        struct SetupLinkApplication: Equatable, Sendable { var link: GatewayConnectDeepLink }

        case credentialsLoaded(LoadedCredentials)
        case gatewayPasswordChanged(GatewayPasswordChange)
        case gatewayTokenChanged(GatewayTokenChange)
        case pendingManualAuthOverrideConsumed
        case reset
        case setupAuthApplied(SetupAuthApplication)
        case setupAuthPersistenceRequested(OnboardingGatewaySetupAuthPersistenceRequest)
        case setupAuthPersistenceRequestHandled
        case setupLinkApplied(SetupLinkApplication)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.onboardingGatewaySetupAuthPersistence) var dependencySetupAuthPersistenceClient
            let setupAuthPersistenceClient = self.setupAuthPersistenceClientOverride
                ?? dependencySetupAuthPersistenceClient

            switch action {
            case let .credentialsLoaded(credentials):
                state.gatewayTokenState = credentials.token
                state.gatewayPasswordState = credentials.password
                return .none

            case let .gatewayPasswordChanged(change):
                state.gatewayPasswordState = change.password
                return .none

            case let .gatewayTokenChanged(change):
                state.gatewayTokenState = change.token
                return .none

            case .pendingManualAuthOverrideConsumed:
                state.pendingManualAuthOverride = nil
                return .none

            case .reset:
                state.gatewayTokenState = .init(value: "")
                state.gatewayPasswordState = .init(value: "")
                state.pendingManualAuthOverride = nil
                state.setupAuthPersistenceRequest = nil
                return .none

            case let .setupAuthApplied(application):
                Self.applySetupAuth(application.setupAuth, to: &state)
                return .none

            case let .setupAuthPersistenceRequested(request):
                guard request.trimmedInstanceId != nil else { return .none }
                return .run { _ in
                    if request.hasBootstrapToken {
                        await setupAuthPersistenceClient.prepareForBootstrapPairing(request.instanceId)
                    }
                    await setupAuthPersistenceClient.saveSetupAuth(request)
                }

            case .setupAuthPersistenceRequestHandled:
                state.setupAuthPersistenceRequest = nil
                return .none

            case let .setupLinkApplied(application):
                let setupAuth = GatewayConnectionController.ManualAuthOverride.setupAuth(from: application.link)
                Self.applySetupAuth(setupAuth, to: &state)
                state.setupAuthPersistenceRequest = OnboardingGatewaySetupAuthPersistenceRequest(
                    setupAuth: setupAuth,
                    instanceId: setupAuthPersistenceClient.currentInstanceID())
                return .none
            }
        }
        .autoLogActions()
    }

    private static func applySetupAuth(
        _ setupAuth: GatewayConnectionController.ManualAuthOverride.SetupAuth,
        to state: inout State)
    {
        if setupAuth.shouldApplyTokenField {
            state.gatewayTokenState = .init(value: setupAuth.token)
        }
        if setupAuth.shouldApplyPasswordField {
            state.gatewayPasswordState = .init(value: setupAuth.password)
        }
        state.pendingManualAuthOverride = setupAuth.manualAuthOverride
    }
}

@Reducer
struct OnboardingPresentationFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        enum Destination: Equatable, Sendable {
            case gatewayProblemDetails
            case qrScanner
            case scannerError(OnboardingScannerErrorMessage)
        }

        var destination: Destination?

        var scannerError: String? {
            guard case let .scannerError(message) = self.destination else { return nil }
            return message.value
        }

        var showGatewayProblemDetails: Bool {
            self.destination == .gatewayProblemDetails
        }

        var showQRScanner: Bool {
            self.destination == .qrScanner
        }
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
                state.destination = .gatewayProblemDetails
                return .none

            case .gatewayProblemDetailsDismissed:
                if state.destination == .gatewayProblemDetails {
                    state.destination = nil
                }
                return .none

            case .qrScannerButtonTapped:
                state.destination = .qrScanner
                return .none

            case .qrScannerDismissed:
                if state.destination == .qrScanner {
                    state.destination = nil
                }
                return .none

            case .qrScannerErrorDismissed:
                if case .scannerError = state.destination {
                    state.destination = nil
                }
                return .none

            case let .qrScannerErrorReceived(error):
                state.destination = .scannerError(error.message)
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
        var restartRequestIDState = OnboardingDiscoveryRestartRequestID(value: 0)

        var restartRequestID: Int {
            self.restartRequestIDState.value
        }
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
                state.restartRequestIDState = .init(value: state.restartRequestID &+ 1)
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

struct OnboardingGatewayDisconnectClient {
    var disconnect: @MainActor @Sendable () -> Void
}

extension OnboardingGatewayDisconnectClient: DependencyKey {
    static let liveValue = OnboardingGatewayDisconnectClient(disconnect: {})
    static let testValue = OnboardingGatewayDisconnectClient(disconnect: {})

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        OnboardingGatewayDisconnectClient(disconnect: {
            appModel.disconnectGateway()
        })
    }
}

extension DependencyValues {
    var onboardingGatewayDisconnect: OnboardingGatewayDisconnectClient {
        get { self[OnboardingGatewayDisconnectClient.self] }
        set { self[OnboardingGatewayDisconnectClient.self] = newValue }
    }
}

@Reducer
struct OnboardingGatewayConnectionFeature {
    private let disconnectClientOverride: OnboardingGatewayDisconnectClient?

    init(disconnectClient: OnboardingGatewayDisconnectClient? = nil) {
        self.disconnectClientOverride = disconnectClient
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {}

    enum Action: Equatable, Sendable {
        case disconnectRequested
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            @Dependency(\.onboardingGatewayDisconnect) var dependencyDisconnectClient
            let disconnectClient = self.disconnectClientOverride ?? dependencyDisconnectClient

            switch action {
            case .disconnectRequested:
                return .run { [disconnectClient] _ in
                    await disconnectClient.disconnect()
                }
            }
        }
        .autoLogActions()
    }
}

struct OnboardingAppleReviewDemoClient {
    var enter: @MainActor @Sendable () -> Void
}

extension OnboardingAppleReviewDemoClient: DependencyKey {
    static let liveValue = OnboardingAppleReviewDemoClient(enter: {})
    static let testValue = OnboardingAppleReviewDemoClient(enter: {})

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        OnboardingAppleReviewDemoClient(enter: {
            appModel.enterAppleReviewDemoMode()
        })
    }
}

extension DependencyValues {
    var onboardingAppleReviewDemo: OnboardingAppleReviewDemoClient {
        get { self[OnboardingAppleReviewDemoClient.self] }
        set { self[OnboardingAppleReviewDemoClient.self] = newValue }
    }
}

@Reducer
struct OnboardingAppleReviewDemoFeature {
    private let appleReviewDemoClientOverride: OnboardingAppleReviewDemoClient?

    init(appleReviewDemoClient: OnboardingAppleReviewDemoClient? = nil) {
        self.appleReviewDemoClientOverride = appleReviewDemoClient
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {}

    enum Action: Equatable, Sendable {
        case enableRequested
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            @Dependency(\.onboardingAppleReviewDemo) var dependencyAppleReviewDemoClient
            let appleReviewDemoClient = self.appleReviewDemoClientOverride ?? dependencyAppleReviewDemoClient

            switch action {
            case .enableRequested:
                return .run { [appleReviewDemoClient] _ in
                    await appleReviewDemoClient.enter()
                }
            }
        }
        .autoLogActions()
    }
}

struct OnboardingPairingResumeClient {
    var resume: @MainActor @Sendable () -> Void
}

extension OnboardingPairingResumeClient: DependencyKey {
    static let liveValue = OnboardingPairingResumeClient(resume: {})
    static let testValue = OnboardingPairingResumeClient(resume: {})

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        OnboardingPairingResumeClient(resume: {
            appModel.gatewayAutoReconnectEnabled = true
            appModel.gatewayPairingPaused = false
            appModel.gatewayPairingRequestId = nil
        })
    }
}

extension DependencyValues {
    var onboardingPairingResume: OnboardingPairingResumeClient {
        get { self[OnboardingPairingResumeClient.self] }
        set { self[OnboardingPairingResumeClient.self] = newValue }
    }
}

@Reducer
struct OnboardingPairingResumeFeature {
    private let resumeClientOverride: OnboardingPairingResumeClient?

    init(resumeClient: OnboardingPairingResumeClient? = nil) {
        self.resumeClientOverride = resumeClient
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {}

    enum Action: Equatable, Sendable {
        case resumeRequested
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            @Dependency(\.onboardingPairingResume) var dependencyResumeClient
            let resumeClient = self.resumeClientOverride ?? dependencyResumeClient

            switch action {
            case .resumeRequested:
                return .run { [resumeClient] _ in
                    await resumeClient.resume()
                }
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct OnboardingQRPhotoImportFeature {
    static let imageLoadFailureMessage = OnboardingQRPhotoImportFailureMessage(
        value: "Could not load the selected image.")
    static let invalidQRCodeMessage = OnboardingQRPhotoImportFailureMessage(
        value: "No valid QR code found in the selected image.")

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        enum ImportPhase: Equatable, Sendable {
            case idle
            case inFlight
        }

        var importPhase = ImportPhase.idle
        var result: ImportResult?
    }

    enum ImportResult: Equatable, Sendable {
        struct AppleReviewSetupCode: Equatable, Sendable { var code: OnboardingSetupCode }
        struct Failure: Equatable, Sendable { var message: OnboardingQRPhotoImportFailureMessage }

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
                state.importPhase = .idle
                state.result = .failure(.init(message: Self.imageLoadFailureMessage))
                return .none

            case .importStarted:
                state.importPhase = .inFlight
                state.result = nil
                return .none

            case let .qrMessageDetected(detection):
                state.importPhase = .idle
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
            return .appleReviewSetupCode(.init(code: .init(value: message)))
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
        var setupCodeState = OnboardingSetupCode(value: "")
        var statusState = OnboardingSetupCodeStatusMessage(value: nil)

        var setupCode: String {
            self.setupCodeState.value
        }

        var status: String? {
            self.statusState.value
        }

        var trimmedSetupCode: String {
            self.setupCode.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var canApply: Bool {
            !self.trimmedSetupCode.isEmpty
        }
    }

    enum ApplyResult: Equatable, Sendable {
        struct AppleReviewDemoSetupCode: Equatable, Sendable { var code: OnboardingSetupCode }

        case appleReviewDemoSetupCode(AppleReviewDemoSetupCode)
        case gatewayLink(GatewayConnectDeepLink)
    }

    enum Action: Equatable, Sendable {
        struct ScannedGatewayLink: Equatable, Sendable { var link: GatewayConnectDeepLink }
        struct ScannedSetupCode: Equatable, Sendable { var code: OnboardingSetupCode }
        struct SetupCodeChange: Equatable, Sendable { var code: OnboardingSetupCode }

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
                state.setupCodeState = .init(value: "")
                state.statusState = .init(value: "Apple Review demo mode enabled.")
                return .none

            case .applyRequested:
                state.applyResult = nil
                state.statusState = .init(value: nil)
                let raw = state.trimmedSetupCode
                guard !raw.isEmpty else {
                    state.statusState = .init(value: "Paste a setup code to continue.")
                    return .none
                }

                if AppleReviewDemoMode.isSetupCode(raw) {
                    state.setupCodeState = .init(value: "")
                    state.statusState = .init(value: "Apple Review demo mode enabled.")
                    state.applyResult = .appleReviewDemoSetupCode(.init(code: .init(value: raw)))
                    return .none
                }

                guard let link = GatewayConnectDeepLink.fromSetupInput(raw) else {
                    state.statusState = .init(value: "Setup code not recognized or uses an insecure ws:// gateway URL.")
                    return .none
                }
                state.setupCodeState = .init(value: "")
                state.statusState = .init(value: "Setup code applied. Connecting...")
                state.applyResult = .gatewayLink(link)
                return .none

            case .applyResultHandled:
                state.applyResult = nil
                return .none

            case .applyStarted:
                state.applyResult = nil
                state.statusState = .init(value: nil)
                return .none

            case .emptyCodeSubmitted:
                state.applyResult = nil
                state.statusState = .init(value: "Paste a setup code to continue.")
                return .none

            case .invalidSetupCodeSubmitted:
                state.applyResult = nil
                state.statusState = .init(value: "Setup code not recognized or uses an insecure ws:// gateway URL.")
                return .none

            case let .scannedGatewayLinkReceived(scan):
                state.applyResult = nil
                state.statusState = .init(value: nil)
                state.applyResult = .gatewayLink(scan.link)
                return .none

            case let .scannedSetupCodeReceived(scan):
                state.applyResult = nil
                guard AppleReviewDemoMode.isSetupCode(scan.code.value) else {
                    return .none
                }
                state.applyResult = .appleReviewDemoSetupCode(.init(
                    code: .init(value: scan.code.value.trimmingCharacters(in: .whitespacesAndNewlines))))
                return .none

            case .setupCodeAccepted:
                state.applyResult = nil
                state.setupCodeState = .init(value: "")
                state.statusState = .init(value: "Setup code applied. Connecting...")
                return .none

            case let .setupCodeChanged(change):
                state.setupCodeState = change.code
                return .none

            case .statusCleared:
                state.statusState = .init(value: nil)
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
        var manualHostState = OnboardingManualHost(value: "")
        var manualPortState = OnboardingManualPort(value: 18789)
        var manualPortTextState = OnboardingManualPortText(value: "18789")
        var manualTLSState = OnboardingManualTLS(value: true)

        var manualHost: String {
            self.manualHostState.value
        }

        var manualPort: Int {
            self.manualPortState.value
        }

        var manualPortText: String {
            self.manualPortTextState.value
        }

        var normalizedManualHost: String {
            self.manualHost.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var manualTLS: Bool {
            self.manualTLSState.value
        }

        var canConnectManual: Bool {
            !self.normalizedManualHost.isEmpty && self.manualPort > 0 && self.manualPort <= 65535
        }

        mutating func syncManualPortText() {
            self.manualPortTextState = .init(value: self.manualPort > 0 ? String(self.manualPort) : "")
        }

        mutating func applyModeDefaults(_ mode: OnboardingConnectionMode) {
            let host = self.normalizedManualHost.lowercased()
            let hostIsDefaultLike = host.isEmpty || host == "openclaw.local" || host == "localhost"

            switch mode {
            case .homeNetwork:
                if hostIsDefaultLike { self.manualHostState = .init(value: "openclaw.local") }
                self.manualTLSState = .init(value: true)
            case .remoteDomain:
                if host == "openclaw.local" || host == "localhost" { self.manualHostState = .init(value: "") }
                self.manualTLSState = .init(value: true)
            case .developerLocal:
                if hostIsDefaultLike { self.manualHostState = .init(value: "localhost") }
                self.manualTLSState = .init(value: false)
            }

            if self.manualPort <= 0 || self.manualPort > 65535 {
                self.manualPortState = .init(value: 18789)
            }
            self.syncManualPortText()
        }
    }

    struct ManualConnectionRequest: Equatable, Sendable {
        var host: OnboardingManualHost
        var port: OnboardingManualPort
        var useTLS: OnboardingManualTLS
    }

    enum Action: Equatable, Sendable {
        struct ManualHostChange: Equatable, Sendable { var host: OnboardingManualHost }
        struct ManualPortTextChange: Equatable, Sendable { var text: OnboardingManualPortText }
        struct ManualTLSChange: Equatable, Sendable { var useTLS: OnboardingManualTLS }
        struct ModeSelection: Equatable, Sendable { var mode: OnboardingConnectionMode }
        struct SelectedModeChange: Equatable, Sendable { var mode: OnboardingConnectionMode? }
        struct GatewayLinkApplication: Equatable, Sendable {
            var host: OnboardingManualHost
            var port: OnboardingManualPort
            var tls: OnboardingManualTLS
        }

        struct Initialization: Equatable, Sendable {
            var host: OnboardingManualHost
            var port: OnboardingManualPort
            var tls: OnboardingManualTLS
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
                state.manualHostState = application.host
                state.manualPortState = application.port
                state.syncManualPortText()
                state.manualTLSState = application.tls
                if state.selectedMode == nil {
                    state.selectedMode = application.tls.value ? .remoteDomain : .homeNetwork
                }
                return .none

            case let .initialized(initialization):
                if state.normalizedManualHost.isEmpty {
                    state.manualHostState = initialization.host
                    state.manualPortState = initialization.port
                    state.manualTLSState = initialization.tls
                }
                state.syncManualPortText()
                if state.selectedMode == nil {
                    state.selectedMode = initialization.lastMode
                }
                if state.selectedMode == .developerLocal, state.manualHost == "openclaw.local" {
                    state.manualHostState = .init(value: "localhost")
                    state.manualTLSState = .init(value: false)
                }
                return .none

            case .manualConnectionRequested:
                state.manualConnectionRequest = nil
                let host = state.normalizedManualHost
                guard !host.isEmpty, state.manualPort > 0, state.manualPort <= 65535 else {
                    return .none
                }
                state.manualConnectionRequest = ManualConnectionRequest(
                    host: .init(value: host),
                    port: state.manualPortState,
                    useTLS: .init(value: state.manualTLS))
                return .none

            case .manualConnectionRequestHandled:
                state.manualConnectionRequest = nil
                return .none

            case let .manualHostChanged(change):
                state.manualHostState = change.host
                return .none

            case let .manualPortTextChanged(change):
                let digits = change.text.value.filter(\.isNumber)
                guard let parsed = Int(digits), parsed > 0 else {
                    state.manualPortState = .init(value: 0)
                    state.manualPortTextState = .init(value: "")
                    return .none
                }
                state.manualPortState = .init(value: min(parsed, 65535))
                state.syncManualPortText()
                return .none

            case let .manualTLSChanged(change):
                state.manualTLSState = change.useTLS
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
