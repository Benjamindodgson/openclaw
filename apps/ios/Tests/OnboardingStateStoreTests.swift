import ComposableArchitecture
import Foundation
import OpenClawKit
import Testing
@testable import OpenClaw

@Suite(.serialized) struct OnboardingStateStoreTests {
    @Test @MainActor func `should present when fresh and disconnected`() {
        let testDefaults = self.makeDefaults()
        let defaults = testDefaults.defaults
        defer { self.reset(testDefaults) }

        let appModel = NodeAppModel()
        appModel.gatewayServerName = nil
        #expect(OnboardingStateStore.shouldPresentOnLaunch(
            appModel: appModel,
            defaults: defaults,
            hasSavedGatewayConnection: false))
    }

    @Test @MainActor func `does not present when connected`() {
        let testDefaults = self.makeDefaults()
        let defaults = testDefaults.defaults
        defer { self.reset(testDefaults) }

        let appModel = NodeAppModel()
        appModel.gatewayServerName = "gateway"
        #expect(!OnboardingStateStore.shouldPresentOnLaunch(
            appModel: appModel,
            defaults: defaults,
            hasSavedGatewayConnection: false))
    }

    @Test @MainActor func `does not present for saved gateway before reconnect completes`() {
        let testDefaults = self.makeDefaults()
        let defaults = testDefaults.defaults
        defer { self.reset(testDefaults) }

        let appModel = NodeAppModel()
        appModel.gatewayServerName = nil
        #expect(!OnboardingStateStore.shouldPresentOnLaunch(
            appModel: appModel,
            defaults: defaults,
            hasSavedGatewayConnection: true))
    }

    @Test @MainActor func `mark completed persists mode`() {
        let testDefaults = self.makeDefaults()
        let defaults = testDefaults.defaults
        defer { self.reset(testDefaults) }

        let appModel = NodeAppModel()
        appModel.gatewayServerName = nil

        OnboardingStateStore.markCompleted(mode: .remoteDomain, defaults: defaults)
        #expect(OnboardingStateStore.lastMode(defaults: defaults) == .remoteDomain)
        #expect(!OnboardingStateStore.shouldPresentOnLaunch(
            appModel: appModel,
            defaults: defaults,
            hasSavedGatewayConnection: false))
    }

    @Test func `first run intro defaults to visible then persists`() {
        let testDefaults = self.makeDefaults()
        let defaults = testDefaults.defaults
        defer { self.reset(testDefaults) }

        #expect(OnboardingStateStore.shouldPresentFirstRunIntro(defaults: defaults))

        OnboardingStateStore.markFirstRunIntroSeen(defaults: defaults)
        #expect(!OnboardingStateStore.shouldPresentFirstRunIntro(defaults: defaults))
    }

    @Test @MainActor func `reset clears completion and intro seen`() {
        let testDefaults = self.makeDefaults()
        let defaults = testDefaults.defaults
        defer { self.reset(testDefaults) }

        OnboardingStateStore.markCompleted(mode: .homeNetwork, defaults: defaults)
        OnboardingStateStore.markFirstRunIntroSeen(defaults: defaults)

        OnboardingStateStore.reset(defaults: defaults)

        let appModel = NodeAppModel()
        appModel.gatewayServerName = nil

        #expect(OnboardingStateStore.shouldPresentOnLaunch(
            appModel: appModel,
            defaults: defaults,
            hasSavedGatewayConnection: false))
        #expect(OnboardingStateStore.shouldPresentFirstRunIntro(defaults: defaults))
        #expect(OnboardingStateStore.lastMode(defaults: defaults) == .homeNetwork)
    }

    @Test @MainActor func `reducer updates presentation state`() async {
        let store = TestStore(initialState: OnboardingStateFeature.State(
            isCompleted: false,
            firstRunIntroSeen: false,
            hasSavedGatewayConnection: false,
            gatewayServerName: nil))
        {
            OnboardingStateFeature()
        }

        await store.send(.gatewaySnapshotChanged(.init(
            gatewayServerName: .init(value: "gateway"),
            hasSavedGatewayConnection: .init(value: false))))
        {
            $0.gatewayServerName = "gateway"
            $0.shouldPresentOnLaunch = false
        }

        await store.send(.gatewaySnapshotChanged(.init(
            gatewayServerName: .init(value: nil),
            hasSavedGatewayConnection: .init(value: true))))
        {
            $0.gatewayServerName = nil
            $0.hasSavedGatewayConnection = true
        }

        await store.send(.gatewaySnapshotChanged(.init(
            gatewayServerName: .init(value: nil),
            hasSavedGatewayConnection: .init(value: false))))
        {
            $0.hasSavedGatewayConnection = false
            $0.shouldPresentOnLaunch = true
        }

        await store.send(.markCompleted(.init(mode: .remoteDomain))) {
            $0.isCompleted = true
            $0.lastMode = .remoteDomain
            $0.shouldPresentOnLaunch = false
        }

        await store.send(.reset) {
            $0.isCompleted = false
            $0.firstRunIntroSeen = false
            $0.shouldPresentOnLaunch = true
        }

        await store.send(.markFirstRunIntroSeen) {
            $0.firstRunIntroSeen = true
            $0.shouldPresentFirstRunIntro = false
        }
    }

    @Test @MainActor func `presentation reducer owns scanner and problem detail state`() async {
        let store = TestStore(initialState: OnboardingPresentationFeature.State()) {
            OnboardingPresentationFeature()
        }

        await store.send(.qrScannerButtonTapped) {
            $0.showQRScanner = true
        }

        await store.send(.qrScannerErrorReceived(.init(message: .init(value: "Camera unavailable")))) {
            $0.scannerError = "Camera unavailable"
            $0.showQRScanner = false
        }

        await store.send(.qrScannerErrorDismissed) {
            $0.scannerError = nil
        }

        await store.send(.gatewayProblemDetailsButtonTapped) {
            $0.showGatewayProblemDetails = true
        }

        await store.send(.gatewayProblemDetailsDismissed) {
            $0.showGatewayProblemDetails = false
        }
    }

    @Test @MainActor func `photo import reducer classifies gateway and demo QR messages`() async {
        let link = GatewayConnectDeepLink(
            host: "gateway.example.com",
            port: 443,
            tls: true,
            bootstrapToken: nil,
            token: nil,
            password: nil)
        let store = TestStore(initialState: OnboardingQRPhotoImportFeature.State()) {
            OnboardingQRPhotoImportFeature()
        }

        await store.send(.importStarted) {
            $0.isImporting = true
        }

        await store.send(.qrMessageDetected(.init(message: .init(value: "wss://gateway.example.com:443")))) {
            $0.isImporting = false
            $0.result = .gatewayLink(link)
        }

        await store.send(.resultHandled) {
            $0.result = nil
        }

        await store.send(.importStarted) {
            $0.isImporting = true
        }

        await store.send(.qrMessageDetected(.init(message: .init(value: "  APPLE-REVIEW-DEMO  ")))) {
            $0.isImporting = false
            $0.result = .appleReviewSetupCode(.init(code: "  APPLE-REVIEW-DEMO  "))
        }
    }

    @Test @MainActor func `photo import reducer reports load and invalid QR failures`() async {
        let store = TestStore(initialState: OnboardingQRPhotoImportFeature.State()) {
            OnboardingQRPhotoImportFeature()
        }

        await store.send(.importStarted) {
            $0.isImporting = true
        }

        await store.send(.imageLoadFailed) {
            $0.isImporting = false
            $0.result = .failure(.init(message: OnboardingQRPhotoImportFeature.imageLoadFailureMessage))
        }

        await store.send(.resultHandled) {
            $0.result = nil
        }

        await store.send(.importStarted) {
            $0.isImporting = true
        }

        await store.send(.qrMessageDetected(.init(message: .init(value: nil)))) {
            $0.isImporting = false
            $0.result = .failure(.init(message: OnboardingQRPhotoImportFeature.invalidQRCodeMessage))
        }

        await store.send(.importStarted) {
            $0.isImporting = true
            $0.result = nil
        }

        await store.send(.qrMessageDetected(.init(message: .init(value: "not a setup code")))) {
            $0.isImporting = false
            $0.result = .failure(.init(message: OnboardingQRPhotoImportFeature.invalidQRCodeMessage))
        }
    }

    @Test @MainActor func `discovery restart reducer schedules restart request`() async {
        let store = TestStore(initialState: OnboardingDiscoveryRestartFeature.State()) {
            OnboardingDiscoveryRestartFeature()
        }

        await store.send(.discoveryDomainChanged)

        await store.receive(.restartDelayElapsed) {
            $0.restartRequestID = 1
        }
    }

    @Test @MainActor func `discovery restart reducer cancels pending restart on disappear`() async {
        let probe = OnboardingDiscoveryRestartSleepProbe()
        let store = TestStore(initialState: OnboardingDiscoveryRestartFeature.State()) {
            OnboardingDiscoveryRestartFeature(sleeper: probe.client)
        }

        await store.send(.discoveryDomainChanged)
        await store.send(.disappeared)

        await store.finish()
        #expect(probe.wasCancelled)
    }

    @Test @MainActor func `step reducer navigates wizard steps`() async {
        let store = TestStore(initialState: OnboardingStepFeature.State(step: .intro)) {
            OnboardingStepFeature()
        }

        #expect(store.state.isFullScreenStep)

        await store.send(.stepChanged(.init(step: .mode))) {
            $0.step = .mode
        }

        #expect(!store.state.isFullScreenStep)

        await store.send(.backButtonTapped) {
            $0.step = .welcome
        }

        await store.send(.stepChanged(.init(step: .connect))) {
            $0.step = .connect
        }

        await store.send(.backButtonTapped) {
            $0.step = .mode
        }

        await store.send(.stepChanged(.init(step: .success))) {
            $0.step = .success
        }

        await store.send(.backButtonTapped)
        #expect(store.state.step == .success)
    }

    @Test @MainActor func `status reducer owns progress and active connection state`() async {
        let store = TestStore(initialState: OnboardingStatusFeature.State()) {
            OnboardingStatusFeature()
        }

        #expect(store.state.statusLine == OnboardingStatusFeature.defaultStatusLine)

        await store.send(.qrScannerOpeningStarted) {
            $0.statusLine = "Opening QR scanner…"
        }

        await store.send(.scannerErrorReceived(.init(message: .init(value: "Camera unavailable")))) {
            $0.statusLine = "Scanner error: Camera unavailable"
        }

        await store.send(.connectionStarted(.init(
            id: .init(value: "manual"),
            message: .init(value: "Connecting to gateway…"),
            statusLine: .init(value: "Connecting to gateway:18789…"),
            clearsIssue: .init(value: true))))
        {
            $0.connectingGatewayID = "manual"
            $0.connectMessage = "Connecting to gateway…"
            $0.statusLine = "Connecting to gateway:18789…"
        }

        await store.send(.connectionStatusUpdated(.init(
            message: .init(value: "Connecting via QR code..."),
            statusLine: .init(value: "QR loaded. Connecting to gateway.local:18789..."))))
        {
            $0.connectMessage = "Connecting via QR code..."
            $0.statusLine = "QR loaded. Connecting to gateway.local:18789..."
        }

        await store.send(.connectionActivityStarted(.init(id: .init(value: "retry-auto")))) {
            $0.connectingGatewayID = "retry-auto"
        }

        await store.send(.connectionFinished) {
            $0.connectingGatewayID = nil
        }

        await store.send(.gatewayConnected(.init(markedCompleted: .init(value: true)))) {
            $0.didMarkCompleted = true
            $0.statusLine = "Connected."
        }

        await store.send(.freshQRScanStarted) {
            $0.connectMessage = nil
            $0.issue = .none
            $0.pairingRequestId = nil
            $0.shouldShowAuthStep = false
            $0.statusLine = "Opening QR scanner…"
        }

        await store.send(.noSavedPairingFound) {
            $0.statusLine = OnboardingStatusFeature.noSavedPairingStatusLine
        }
    }

    @Test @MainActor func `status reducer preserves sticky pairing and auth issues`() async {
        let store = TestStore(initialState: OnboardingStatusFeature.State()) {
            OnboardingStatusFeature()
        }

        await store.send(.connectionIssueDetected(.init(
            issue: .pairingRequired(requestId: "pair-1"),
            requestId: .init(value: "pair-1"),
            pauseReconnect: .init(value: false),
            message: .init(value: "Pairing required"),
            statusText: .init(value: ""))))
        {
            $0.connectMessage = "Pairing required"
            $0.issue = .pairingRequired(requestId: "pair-1")
            $0.pairingRequestId = "pair-1"
            $0.shouldShowAuthStep = true
            $0.statusLine = "Pairing required"
        }

        await store.send(.connectionIssueDetected(.init(
            issue: .none,
            requestId: .init(value: nil),
            pauseReconnect: .init(value: false),
            message: .init(value: nil),
            statusText: .init(value: "Connecting"))))
        {
            $0.connectMessage = "Connecting"
            $0.statusLine = "Connecting"
        }

        #expect(store.state.issue == .pairingRequired(requestId: "pair-1"))
        #expect(store.state.shouldShowAuthStep)

        await store.send(.pairingResumeStarted) {
            $0.connectMessage = "Retrying after approval…"
            $0.issue = .none
            $0.shouldShowAuthStep = false
            $0.statusLine = "Retrying after approval…"
        }

        await store.send(.connectionIssueDetected(.init(
            issue: .unauthorized,
            requestId: .init(value: nil),
            pauseReconnect: .init(value: false),
            message: .init(value: nil),
            statusText: .init(value: "Unauthorized"))))
        {
            $0.connectMessage = "Unauthorized"
            $0.issue = .unauthorized
            $0.shouldShowAuthStep = true
            $0.statusLine = "Unauthorized"
        }

        await store.send(.connectionIssueDetected(.init(
            issue: .none,
            requestId: .init(value: nil),
            pauseReconnect: .init(value: false),
            message: .init(value: nil),
            statusText: .init(value: "Offline"))))
        {
            $0.connectMessage = "Offline"
            $0.statusLine = "Offline"
        }

        #expect(store.state.issue == .unauthorized)
        #expect(store.state.shouldShowAuthStep)
    }

    @Test @MainActor func `status reducer throttles automatic pairing resume attempts`() async {
        let store = TestStore(initialState: OnboardingStatusFeature.State()) {
            OnboardingStatusFeature()
        }
        let firstAttempt = Date(timeIntervalSince1970: 100)

        await store.send(.automaticPairingResumeRequested(.init(now: .init(value: firstAttempt))))
        #expect(!store.state.shouldResumePairingAutomatically)

        await store.send(.connectionIssueDetected(.init(
            issue: .pairingRequired(requestId: "pair-1"),
            requestId: .init(value: "pair-1"),
            pauseReconnect: .init(value: false),
            message: .init(value: "Pairing required"),
            statusText: .init(value: ""))))
        {
            $0.connectMessage = "Pairing required"
            $0.issue = .pairingRequired(requestId: "pair-1")
            $0.pairingRequestId = "pair-1"
            $0.shouldShowAuthStep = true
            $0.statusLine = "Pairing required"
        }

        await store.send(.automaticPairingResumeRequested(.init(now: .init(value: firstAttempt)))) {
            $0.lastPairingAutoResumeAttemptAt = firstAttempt
            $0.shouldResumePairingAutomatically = true
        }

        let throttledAttempt = firstAttempt.addingTimeInterval(3)
        await store.send(.automaticPairingResumeRequested(.init(now: .init(value: throttledAttempt)))) {
            $0.shouldResumePairingAutomatically = false
        }

        let laterAttempt = firstAttempt.addingTimeInterval(7)
        await store.send(.automaticPairingResumeRequested(.init(now: .init(value: laterAttempt)))) {
            $0.lastPairingAutoResumeAttemptAt = laterAttempt
            $0.shouldResumePairingAutomatically = true
        }

        await store.send(.connectionActivityStarted(.init(id: .init(value: "retry-auto")))) {
            $0.connectingGatewayID = "retry-auto"
        }

        let blockedAttempt = laterAttempt.addingTimeInterval(7)
        await store.send(.automaticPairingResumeRequested(.init(now: .init(value: blockedAttempt)))) {
            $0.shouldResumePairingAutomatically = false
        }
    }

    @Test @MainActor func `credentials reducer owns gateway token and password`() async {
        let store = TestStore(initialState: OnboardingCredentialsFeature.State()) {
            OnboardingCredentialsFeature()
        }

        #expect(!store.state.hasGatewayToken)
        #expect(!store.state.hasGatewayPassword)

        await store.send(.credentialsLoaded(.init(
            token: .init(value: " token-1 "),
            password: .init(value: " password-1 "))))
        {
            $0.gatewayToken = " token-1 "
            $0.gatewayPassword = " password-1 "
        }

        #expect(store.state.hasGatewayToken)
        #expect(store.state.hasGatewayPassword)

        await store.send(.gatewayTokenChanged(.init(value: "token-2"))) {
            $0.gatewayToken = "token-2"
        }

        await store.send(.gatewayPasswordChanged(.init(value: "   "))) {
            $0.gatewayPassword = "   "
        }

        #expect(!store.state.hasGatewayPassword)

        let link = GatewayConnectDeepLink(
            host: "gateway.example.com",
            port: 443,
            tls: true,
            bootstrapToken: "bootstrap-1",
            token: "token-3",
            password: "password-3")
        let setupAuth = GatewayConnectionController.ManualAuthOverride.setupAuth(from: link)

        await store.send(.setupAuthApplied(.init(setupAuth: setupAuth))) {
            $0.gatewayToken = "token-3"
            $0.gatewayPassword = "password-3"
            $0.pendingManualAuthOverride = GatewayConnectionController.ManualAuthOverride.explicit(
                token: "token-3",
                bootstrapToken: "bootstrap-1",
                password: "password-3")
        }

        await store.send(.pendingManualAuthOverrideConsumed) {
            $0.pendingManualAuthOverride = nil
        }

        await store.send(.setupAuthApplied(.init(setupAuth: setupAuth))) {
            $0.pendingManualAuthOverride = GatewayConnectionController.ManualAuthOverride.explicit(
                token: "token-3",
                bootstrapToken: "bootstrap-1",
                password: "password-3")
        }

        await store.send(.reset) {
            $0.gatewayToken = ""
            $0.gatewayPassword = ""
            $0.pendingManualAuthOverride = nil
        }

        #expect(!store.state.hasGatewayToken)
        #expect(!store.state.hasGatewayPassword)
    }

    @Test @MainActor func `setup code reducer owns setup text and status`() async {
        let store = TestStore(initialState: OnboardingSetupCodeFeature.State()) {
            OnboardingSetupCodeFeature()
        }

        await store.send(.setupCodeChanged(.init(code: "  oc_setup_123  "))) {
            $0.setupCode = "  oc_setup_123  "
        }

        #expect(store.state.trimmedSetupCode == "oc_setup_123")
        #expect(store.state.canApply)

        await store.send(.applyStarted)

        await store.send(.invalidSetupCodeSubmitted) {
            $0.status = "Setup code not recognized or uses an insecure ws:// gateway URL."
        }

        await store.send(.statusCleared) {
            $0.status = nil
        }

        await store.send(.setupCodeAccepted) {
            $0.setupCode = ""
            $0.status = "Setup code applied. Connecting..."
        }

        await store.send(.setupCodeChanged(.init(code: "  "))) {
            $0.setupCode = "  "
        }

        #expect(!store.state.canApply)

        await store.send(.emptyCodeSubmitted) {
            $0.status = "Paste a setup code to continue."
        }

        await store.send(.appleReviewDemoCodeAccepted) {
            $0.setupCode = ""
            $0.status = "Apple Review demo mode enabled."
        }
    }

    @Test @MainActor func `setup code reducer classifies gateway apply requests`() async {
        let link = GatewayConnectDeepLink(
            host: "gateway.example.com",
            port: 443,
            tls: true,
            bootstrapToken: nil,
            token: nil,
            password: nil)
        var initialState = OnboardingSetupCodeFeature.State()
        initialState.setupCode = "  wss://gateway.example.com:443  "
        let store = TestStore(initialState: initialState) {
            OnboardingSetupCodeFeature()
        }

        await store.send(.applyRequested) {
            $0.applyResult = .gatewayLink(link)
            $0.setupCode = ""
            $0.status = "Setup code applied. Connecting..."
        }

        await store.send(.applyResultHandled) {
            $0.applyResult = nil
        }
    }

    @Test @MainActor func `setup code reducer reports failed apply requests`() async {
        let store = TestStore(initialState: OnboardingSetupCodeFeature.State()) {
            OnboardingSetupCodeFeature()
        }

        await store.send(.applyRequested) {
            $0.status = "Paste a setup code to continue."
        }

        await store.send(.setupCodeChanged(.init(code: "not a setup code"))) {
            $0.setupCode = "not a setup code"
        }

        await store.send(.applyRequested) {
            $0.status = "Setup code not recognized or uses an insecure ws:// gateway URL."
        }
    }

    @Test @MainActor func `setup code reducer classifies apple review apply requests`() async {
        var initialState = OnboardingSetupCodeFeature.State()
        initialState.setupCode = "  APPLE-REVIEW-DEMO  "
        let store = TestStore(initialState: initialState) {
            OnboardingSetupCodeFeature()
        }

        await store.send(.applyRequested) {
            $0.applyResult = .appleReviewDemoSetupCode(.init(code: "APPLE-REVIEW-DEMO"))
            $0.setupCode = ""
            $0.status = "Apple Review demo mode enabled."
        }
    }

    @Test @MainActor func `setup code reducer classifies scanned apple review setup codes`() async {
        var initialState = OnboardingSetupCodeFeature.State()
        initialState.setupCode = "stale code"
        let store = TestStore(initialState: initialState) {
            OnboardingSetupCodeFeature()
        }

        await store.send(.scannedSetupCodeReceived(.init(code: "not a demo code")))

        await store.send(.scannedSetupCodeReceived(.init(code: "  APPLE-REVIEW-DEMO  "))) {
            $0.applyResult = .appleReviewDemoSetupCode(.init(code: "APPLE-REVIEW-DEMO"))
        }

        await store.send(.applyResultHandled) {
            $0.applyResult = nil
        }
    }

    @Test @MainActor func `setup code reducer classifies scanned gateway links`() async {
        let link = GatewayConnectDeepLink(
            host: "gateway.example.com",
            port: 443,
            tls: true,
            bootstrapToken: nil,
            token: nil,
            password: nil)
        var initialState = OnboardingSetupCodeFeature.State()
        initialState.setupCode = "stale code"
        initialState.status = "stale status"
        let store = TestStore(initialState: initialState) {
            OnboardingSetupCodeFeature()
        }

        await store.send(.scannedGatewayLinkReceived(.init(link: link))) {
            $0.applyResult = .gatewayLink(link)
            $0.status = nil
        }

        await store.send(.applyResultHandled) {
            $0.applyResult = nil
        }
    }

    @Test @MainActor func `connection form reducer normalizes ports and mode defaults`() async {
        let store = TestStore(initialState: OnboardingConnectionFormFeature.State()) {
            OnboardingConnectionFormFeature()
        }

        await store.send(.initialized(.init(
            host: "openclaw.local",
            port: 18789,
            tls: true,
            lastMode: .developerLocal)))
        {
            $0.selectedMode = .developerLocal
            $0.manualHost = "localhost"
            $0.manualTLS = false
        }

        await store.send(.manualPortTextChanged(.init(text: "65abc536"))) {
            $0.manualPort = 65535
            $0.manualPortText = "65535"
        }

        await store.send(.manualPortTextChanged(.init(text: "0"))) {
            $0.manualPort = 0
            $0.manualPortText = ""
        }

        #expect(!store.state.canConnectManual)

        await store.send(.manualConnectionRequested)

        await store.send(.modeSelected(.init(mode: .remoteDomain))) {
            $0.selectedMode = .remoteDomain
            $0.manualHost = ""
            $0.manualPort = 18789
            $0.manualPortText = "18789"
            $0.manualTLS = true
        }

        await store.send(.manualHostChanged(.init(host: "gateway.example.com"))) {
            $0.manualHost = "gateway.example.com"
        }

        await store.send(.manualTLSChanged(.init(useTLS: false))) {
            $0.manualTLS = false
        }

        #expect(store.state.canConnectManual)

        await store.send(.gatewayLinkApplied(.init(host: "studio.local", port: 19000, tls: false))) {
            $0.manualHost = "studio.local"
            $0.manualPort = 19000
            $0.manualPortText = "19000"
            $0.manualTLS = false
        }

        await store.send(.manualConnectionRequested) {
            $0.manualConnectionRequest = OnboardingConnectionFormFeature.ManualConnectionRequest(
                host: "studio.local",
                port: 19000,
                useTLS: false)
        }

        await store.send(.manualConnectionRequestHandled) {
            $0.manualConnectionRequest = nil
        }

        await store.send(.developerModeDisabled)

        await store.send(.selectedModeChanged(.init(mode: .developerLocal))) {
            $0.selectedMode = .developerLocal
        }

        await store.send(.developerModeDisabled) {
            $0.selectedMode = nil
        }
    }

    private struct TestDefaults {
        var suiteName: String
        var defaults: UserDefaults
    }

    private func makeDefaults() -> TestDefaults {
        let suiteName = "OnboardingStateStoreTests.\(UUID().uuidString)"
        return TestDefaults(
            suiteName: suiteName,
            defaults: UserDefaults(suiteName: suiteName) ?? .standard)
    }

    private func reset(_ defaults: TestDefaults) {
        defaults.defaults.removePersistentDomain(forName: defaults.suiteName)
    }

    private final class OnboardingDiscoveryRestartSleepProbe: @unchecked Sendable {
        var wasCancelled = false
        private var continuation: CheckedContinuation<Void, Error>?

        var client: OnboardingDiscoveryRestartSleepClient {
            OnboardingDiscoveryRestartSleepClient(sleep: {
                try await withTaskCancellationHandler {
                    try await withCheckedThrowingContinuation { continuation in
                        self.continuation = continuation
                    }
                } onCancel: {
                    self.wasCancelled = true
                    self.continuation?.resume(throwing: CancellationError())
                    self.continuation = nil
                }
            })
        }
    }
}
