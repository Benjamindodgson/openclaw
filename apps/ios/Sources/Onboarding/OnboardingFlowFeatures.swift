import ComposableArchitecture
import Foundation
import OpenClawKit

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
        struct QRScannerError: Equatable, Sendable {
            var message: OnboardingScannerErrorMessage

            var statusError: OnboardingStatusFeature.Action.ScannerError {
                .init(message: self.message)
            }
        }

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
    private let restartClientOverride: OnboardingDiscoveryRestartClient?
    private let sleepOverride: OnboardingDiscoveryRestartSleepClient?

    private enum CancelID {
        case restart
    }

    init(
        sleeper: OnboardingDiscoveryRestartSleepClient? = nil,
        restartClient: OnboardingDiscoveryRestartClient? = nil)
    {
        self.sleepOverride = sleeper
        self.restartClientOverride = restartClient
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
        case restartRequested
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.onboardingDiscoveryRestart) var dependencyRestartClient
            @Dependency(\.onboardingDiscoveryRestartSleep) var dependencySleeper
            let restartClient = self.restartClientOverride ?? dependencyRestartClient
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
                return .run { [restartClient] _ in
                    await restartClient.restart()
                }

            case .restartRequested:
                return .run { [restartClient] _ in
                    await restartClient.restart()
                }

            case .disappeared:
                return .cancel(id: CancelID.restart)
            }
        }
        .autoLogActions()
    }
}

struct OnboardingDiscoveryRestartClient {
    var restart: @MainActor @Sendable () -> Void
}

struct OnboardingDiscoveryRestartSleepClient {
    var sleep: @Sendable () async throws -> Void
}

extension OnboardingDiscoveryRestartClient: DependencyKey {
    static let liveValue = OnboardingDiscoveryRestartClient(restart: {})
    static let testValue = OnboardingDiscoveryRestartClient(restart: {})

    @MainActor
    static func live(gatewayController: GatewayConnectionController) -> Self {
        OnboardingDiscoveryRestartClient(restart: {
            gatewayController.restartDiscovery()
        })
    }
}

extension OnboardingDiscoveryRestartSleepClient: DependencyKey {
    static let liveValue = OnboardingDiscoveryRestartSleepClient(sleep: {
        try await Task.sleep(nanoseconds: 350_000_000)
    })

    static let testValue = OnboardingDiscoveryRestartSleepClient(sleep: {})
}

extension DependencyValues {
    var onboardingDiscoveryRestart: OnboardingDiscoveryRestartClient {
        get { self[OnboardingDiscoveryRestartClient.self] }
        set { self[OnboardingDiscoveryRestartClient.self] = newValue }
    }

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
    struct State: Equatable, Sendable {
        struct DiscoveredGatewayRowPresentation: Equatable, Sendable {
            var displayHost: OnboardingDiscoveredGatewayHost
            var canConnect: Bool
        }

        var discoveredGatewayConnectionStatusAction: OnboardingStatusFeature.Action?

        static func discoveredGatewayRowPresentation(
            lanHost: OnboardingDiscoveredGatewayHost,
            tailnetDNS: OnboardingDiscoveredGatewayHost)
            -> DiscoveredGatewayRowPresentation
        {
            let displayHost = lanHost.trimmedValue ?? tailnetDNS.trimmedValue
            return .init(
                displayHost: .init(value: displayHost),
                canConnect: displayHost != nil)
        }
    }

    enum Action: Equatable, Sendable {
        struct DiscoveredGatewayConnectionRequest: Equatable, Sendable {
            var id: OnboardingConnectionID
            var name: OnboardingDiscoveredGatewayName
        }

        case disconnectRequested
        case discoveredGatewayConnectionRequested(DiscoveredGatewayConnectionRequest)
        case discoveredGatewayConnectionStatusHandled
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.onboardingGatewayDisconnect) var dependencyDisconnectClient
            let disconnectClient = self.disconnectClientOverride ?? dependencyDisconnectClient

            switch action {
            case .disconnectRequested:
                return .run { [disconnectClient] _ in
                    await disconnectClient.disconnect()
                }

            case let .discoveredGatewayConnectionRequested(request):
                state.discoveredGatewayConnectionStatusAction = .connectionStarted(.init(
                    id: request.id,
                    message: .init(value: "Connecting to \(request.name.value)…"),
                    statusLine: .init(value: "Connecting to \(request.name.value)…"),
                    clearsIssue: .init(value: true)))
                return .none

            case .discoveredGatewayConnectionStatusHandled:
                state.discoveredGatewayConnectionStatusAction = nil
                return .none
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
struct OnboardingGatewayProblemPrimaryActionFeature {
    private let trustClientOverride: OnboardingGatewayProblemTrustClient?

    init(trustClient: OnboardingGatewayProblemTrustClient? = nil) {
        self.trustClientOverride = trustClient
    }

    static func title(for problem: GatewayConnectionProblem) -> String? {
        GatewayProblemPrimaryAction.title(
            for: problem,
            retryTitle: "Retry connection",
            resetTitle: "Scan QR again")
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var primaryActionDecision: PrimaryActionDecision?
    }

    struct CertificateTrustRequest: Equatable, Sendable {
        var problem: GatewayConnectionProblem
        var statusAction: OnboardingStatusFeature.Action
    }

    struct ResetAndScanRequest: Equatable, Sendable {
        var credentialsAction: OnboardingCredentialsFeature.Action
        var statusAction: OnboardingStatusFeature.Action
        var stepAction: OnboardingStepFeature.Action
        var presentationAction: OnboardingPresentationFeature.Action
    }

    enum PrimaryActionDecision: Equatable, Sendable {
        case openProtocolMismatchHelp(GatewayConnectionProblem)
        case resetAndScan(ResetAndScanRequest)
        case retryConnection
        case trustRotatedCertificate(CertificateTrustRequest)
    }

    enum Action: Equatable, Sendable {
        struct PrimaryActionRequest: Equatable, Sendable {
            var problem: GatewayConnectionProblem
        }

        case primaryActionDecisionHandled
        case primaryActionTapped(PrimaryActionRequest)
        case rotatedCertificateTrustRequested(CertificateTrustRequest)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.onboardingGatewayProblemTrust) var dependencyTrustClient
            let trustClient = self.trustClientOverride ?? dependencyTrustClient

            switch action {
            case .primaryActionDecisionHandled:
                state.primaryActionDecision = nil
                return .none

            case let .primaryActionTapped(request):
                let problem = request.problem
                state.primaryActionDecision = Self.primaryActionDecision(for: problem)
                return .none

            case let .rotatedCertificateTrustRequested(request):
                return .run { [trustClient] _ in
                    _ = await trustClient.trustRotatedCertificate(request.problem)
                }
            }
        }
        .autoLogActions()
    }

    private static func primaryActionDecision(for problem: GatewayConnectionProblem) -> PrimaryActionDecision? {
        if problem.suggestsOnboardingReset {
            return .resetAndScan(self.resetAndScanRequest())
        }
        if problem.canTrustRotatedCertificate {
            return .trustRotatedCertificate(self.certificateTrustRequest(for: problem))
        }
        if problem.kind == .protocolMismatch {
            return .openProtocolMismatchHelp(problem)
        }
        if problem.retryable {
            return .retryConnection
        }
        return nil
    }

    private static func resetAndScanRequest() -> ResetAndScanRequest {
        .init(
            credentialsAction: .reset,
            statusAction: .gatewayProblemResetScanStarted,
            stepAction: .stepChanged(.init(step: .connect)),
            presentationAction: .qrScannerButtonTapped)
    }

    private static func certificateTrustRequest(
        for problem: GatewayConnectionProblem)
        -> CertificateTrustRequest
    {
        CertificateTrustRequest(
            problem: problem,
            statusAction: .connectionStarted(.init(
                id: .init(value: "trust-certificate"),
                message: .init(value: "Updating gateway certificate…"),
                statusLine: .init(value: "Updating gateway certificate…"),
                clearsIssue: .init(value: false))))
    }
}

struct OnboardingGatewayProblemTrustClient {
    var trustRotatedCertificate: @MainActor @Sendable (GatewayConnectionProblem) async -> Bool
}

extension OnboardingGatewayProblemTrustClient: DependencyKey {
    static let liveValue = OnboardingGatewayProblemTrustClient(trustRotatedCertificate: { _ in false })
    static let testValue = OnboardingGatewayProblemTrustClient(trustRotatedCertificate: { _ in false })

    @MainActor
    static func live(gatewayController: GatewayConnectionController) -> Self {
        OnboardingGatewayProblemTrustClient(trustRotatedCertificate: { problem in
            await gatewayController.trustRotatedGatewayCertificate(from: problem)
        })
    }
}

extension DependencyValues {
    var onboardingGatewayProblemTrust: OnboardingGatewayProblemTrustClient {
        get { self[OnboardingGatewayProblemTrustClient.self] }
        set { self[OnboardingGatewayProblemTrustClient.self] = newValue }
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
        struct Failure: Equatable, Sendable {
            var message: OnboardingQRPhotoImportFailureMessage
            var presentationError: OnboardingPresentationFeature.Action.QRScannerError
        }

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
                state.result = Self.failureResult(message: Self.imageLoadFailureMessage)
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
            return self.failureResult(message: self.invalidQRCodeMessage)
        }
        if let link = GatewayConnectDeepLink.fromSetupInput(message) {
            return .gatewayLink(link)
        }
        if AppleReviewDemoMode.isSetupCode(message) {
            return .appleReviewSetupCode(.init(code: .init(value: message)))
        }
        return self.failureResult(message: self.invalidQRCodeMessage)
    }

    private static func failureResult(message: OnboardingQRPhotoImportFailureMessage) -> ImportResult {
        .failure(.init(
            message: message,
            presentationError: .init(message: .init(value: message.value))))
    }
}
