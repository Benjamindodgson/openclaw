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
        let progressProbe = OnboardingProgressPersistenceProbe()
        let store = TestStore(initialState: OnboardingStateFeature.State(
            isCompleted: false,
            firstRunIntroSeen: false,
            hasSavedGatewayConnection: false,
            gatewayServerName: nil))
        {
            OnboardingStateFeature(progressPersistenceClient: progressProbe.client)
        }

        await store.send(.gatewaySnapshotChanged(.init(
            gatewayServerName: .init(value: "gateway"),
            hasSavedGatewayConnection: .init(value: false))))
        {
            $0.gatewayServerNameState = .init(value: "gateway")
            $0.launchPresentation = .init(shouldPresent: false)
        }

        #expect(store.state.gatewayServerName == "gateway")

        await store.send(.gatewaySnapshotChanged(.init(
            gatewayServerName: .init(value: nil),
            hasSavedGatewayConnection: .init(value: true))))
        {
            $0.gatewayServerNameState = .init(value: nil)
            $0.savedGatewayConnection = .init(value: true)
        }

        #expect(store.state.gatewayServerName == nil)

        await store.send(.gatewaySnapshotChanged(.init(
            gatewayServerName: .init(value: nil),
            hasSavedGatewayConnection: .init(value: false))))
        {
            $0.savedGatewayConnection = .init(value: false)
            $0.launchPresentation = .init(shouldPresent: true)
        }

        await store.send(.markCompleted(.init(mode: .remoteDomain))) {
            $0.completion = .init(isCompleted: true)
            $0.lastMode = .remoteDomain
            $0.launchPresentation = .init(shouldPresent: false)
        }

        await store.send(.reset) {
            $0.completion = .init(isCompleted: false)
            $0.firstRunIntroSeenState = .init(value: false)
            $0.launchPresentation = .init(shouldPresent: true)
        }

        await store.send(.markFirstRunIntroSeen) {
            $0.firstRunIntroSeenState = .init(value: true)
            $0.firstRunIntroPresentation = .init(shouldPresent: false)
        }
        await store.finish()

        #expect(progressProbe.completedModes == [.remoteDomain])
        #expect(progressProbe.firstRunIntroSeenCount == 1)
    }

    @Test @MainActor func `onboarding state reducer resets through client`() async {
        let resetProbe = OnboardingResetProbe()
        let store = TestStore(initialState: OnboardingStateFeature.State(
            isCompleted: true,
            firstRunIntroSeen: true,
            hasSavedGatewayConnection: false,
            gatewayServerName: nil))
        {
            OnboardingStateFeature(resetClient: resetProbe.client)
        }

        await store.send(.onboardingResetRequested(.init(
            instanceId: .init(value: " instance-reset "))))
        {
            $0.completion = .init(isCompleted: false)
            $0.firstRunIntroSeenState = .init(value: false)
            $0.launchPresentation = .init(shouldPresent: true)
            $0.firstRunIntroPresentation = .init(shouldPresent: true)
        }
        await store.finish()

        #expect(resetProbe.resetInstanceIds == [.init(value: " instance-reset ")])
    }

    @Test @MainActor func `presentation reducer owns scanner and problem detail state`() async {
        let store = TestStore(initialState: OnboardingPresentationFeature.State()) {
            OnboardingPresentationFeature()
        }
        let scannerError = OnboardingPresentationFeature.Action.QRScannerError(
            message: .init(value: "Camera unavailable"))

        await store.send(.qrScannerButtonTapped) {
            $0.destination = .qrScanner
        }

        #expect(scannerError.statusError == .init(message: .init(value: "Camera unavailable")))

        await store.send(.qrScannerErrorReceived(scannerError)) {
            $0.destination = .scannerError(.init(value: "Camera unavailable"))
        }
        await store.send(.qrScannerDismissed)

        await store.send(.qrScannerErrorDismissed) {
            $0.destination = nil
        }

        await store.send(.gatewayProblemDetailsButtonTapped) {
            $0.destination = .gatewayProblemDetails
        }

        await store.send(.gatewayProblemDetailsDismissed) {
            $0.destination = nil
        }
    }

    @Test @MainActor func `gateway connection reducer delegates disconnect through client`() async {
        let probe = OnboardingGatewayDisconnectProbe()
        let store = TestStore(initialState: OnboardingGatewayConnectionFeature.State()) {
            OnboardingGatewayConnectionFeature(disconnectClient: probe.client)
        }

        await store.send(.disconnectRequested)
        await store.finish()

        #expect(probe.disconnectCount == 1)
    }

    @Test @MainActor func `apple review demo reducer delegates enable through client`() async {
        let probe = OnboardingAppleReviewDemoProbe()
        let store = TestStore(initialState: OnboardingAppleReviewDemoFeature.State()) {
            OnboardingAppleReviewDemoFeature(appleReviewDemoClient: probe.client)
        }

        await store.send(.enableRequested)
        await store.finish()

        #expect(probe.enterCount == 1)
    }

    @Test @MainActor func `pairing resume reducer delegates resume through client`() async {
        let probe = OnboardingPairingResumeProbe()
        let store = TestStore(initialState: OnboardingPairingResumeFeature.State()) {
            OnboardingPairingResumeFeature(resumeClient: probe.client)
        }

        await store.send(.resumeRequested)
        await store.finish()

        #expect(probe.resumeCount == 1)
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
            $0.importPhase = .inFlight
        }

        await store.send(.qrMessageDetected(.init(message: .init(value: "wss://gateway.example.com:443")))) {
            $0.importPhase = .idle
            $0.result = .gatewayLink(link)
        }

        await store.send(.resultHandled) {
            $0.result = nil
        }

        await store.send(.importStarted) {
            $0.importPhase = .inFlight
        }

        await store.send(.qrMessageDetected(.init(message: .init(value: "  APPLE-REVIEW-DEMO  ")))) {
            $0.importPhase = .idle
            $0.result = .appleReviewSetupCode(.init(code: .init(value: "  APPLE-REVIEW-DEMO  ")))
        }
    }

    @Test @MainActor func `photo import reducer reports load and invalid QR failures`() async {
        let store = TestStore(initialState: OnboardingQRPhotoImportFeature.State()) {
            OnboardingQRPhotoImportFeature()
        }

        await store.send(.importStarted) {
            $0.importPhase = .inFlight
        }

        await store.send(.imageLoadFailed) {
            $0.importPhase = .idle
            $0.result = .failure(.init(
                message: OnboardingQRPhotoImportFeature.imageLoadFailureMessage,
                presentationError: .init(message: .init(
                    value: OnboardingQRPhotoImportFeature.imageLoadFailureMessage.value))))
        }

        await store.send(.resultHandled) {
            $0.result = nil
        }

        await store.send(.importStarted) {
            $0.importPhase = .inFlight
        }

        await store.send(.qrMessageDetected(.init(message: .init(value: nil)))) {
            $0.importPhase = .idle
            $0.result = .failure(.init(
                message: OnboardingQRPhotoImportFeature.invalidQRCodeMessage,
                presentationError: .init(message: .init(
                    value: OnboardingQRPhotoImportFeature.invalidQRCodeMessage.value))))
        }

        await store.send(.importStarted) {
            $0.importPhase = .inFlight
            $0.result = nil
        }

        await store.send(.qrMessageDetected(.init(message: .init(value: "not a setup code")))) {
            $0.importPhase = .idle
            $0.result = .failure(.init(
                message: OnboardingQRPhotoImportFeature.invalidQRCodeMessage,
                presentationError: .init(message: .init(
                    value: OnboardingQRPhotoImportFeature.invalidQRCodeMessage.value))))
        }
    }

    @Test @MainActor func `discovery restart reducer schedules restart request`() async {
        let store = TestStore(initialState: OnboardingDiscoveryRestartFeature.State()) {
            OnboardingDiscoveryRestartFeature()
        }

        await store.send(.discoveryDomainChanged)

        await store.receive(.restartDelayElapsed) {
            $0.restartRequestIDState = .init(value: 1)
        }

        #expect(store.state.restartRequestID == 1)
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
            $0.statusLineState = .init(value: "Opening QR scanner…")
        }

        await store.send(.scannerErrorReceived(.init(message: .init(value: "Camera unavailable")))) {
            $0.statusLineState = .init(value: "Scanner error: Camera unavailable")
        }

        await store.send(.connectionStarted(.init(
            id: .init(value: "manual"),
            message: .init(value: "Connecting to gateway…"),
            statusLine: .init(value: "Connecting to gateway:18789…"),
            clearsIssue: .init(value: true))))
        {
            $0.connectingGatewayIDState = .init(value: "manual")
            $0.connectMessageState = .init(value: "Connecting to gateway…")
            $0.statusLineState = .init(value: "Connecting to gateway:18789…")
        }

        #expect(store.state.connectMessage == "Connecting to gateway…")
        #expect(store.state.connectingGatewayID == "manual")
        #expect(store.state.statusLine == "Connecting to gateway:18789…")

        await store.send(.connectionStatusUpdated(.init(
            message: .init(value: "Connecting via QR code..."),
            statusLine: .init(value: "QR loaded. Connecting to gateway.local:18789..."))))
        {
            $0.connectMessageState = .init(value: "Connecting via QR code...")
            $0.statusLineState = .init(value: "QR loaded. Connecting to gateway.local:18789...")
        }

        await store.send(.connectionActivityStarted(.init(id: .init(value: "retry-auto")))) {
            $0.connectingGatewayIDState = .init(value: "retry-auto")
        }

        await store.send(.connectionFinished) {
            $0.connectingGatewayIDState = nil
        }

        #expect(store.state.connectingGatewayID == nil)

        await store.send(.gatewayConnected(.init(markedCompleted: .init(value: true)))) {
            $0.completionMark = .init(value: true)
            $0.statusLineState = .init(value: "Connected.")
        }

        await store.send(.freshQRScanStarted) {
            $0.connectMessageState = .init(value: nil)
            $0.issue = .none
            $0.pairingRequestIdState = .init(value: nil)
            $0.authStepPresentation = .init(shouldShow: false)
            $0.statusLineState = .init(value: "Opening QR scanner…")
        }

        await store.send(.noSavedPairingFound) {
            $0.statusLineState = .init(value: OnboardingStatusFeature.noSavedPairingStatusLine)
        }
    }

    @Test @MainActor func `status reducer derives gateway connection completion request`() async {
        let store = TestStore(initialState: OnboardingStatusFeature.State()) {
            OnboardingStatusFeature()
        }

        await store.send(.gatewayConnectionSucceeded(.init(selectedMode: .homeNetwork))) {
            $0.gatewayConnectionCompletionRequest = .init(mode: .homeNetwork)
            $0.completionMark = .init(value: true)
            $0.statusLineState = .init(value: "Connected.")
        }

        await store.send(.gatewayConnectionSuccessHandled) {
            $0.gatewayConnectionCompletionRequest = nil
        }

        await store.send(.gatewayConnectionSucceeded(.init(selectedMode: .remoteDomain)))
        #expect(store.state.gatewayConnectionCompletionRequest == nil)
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
            $0.connectMessageState = .init(value: "Pairing required")
            $0.issue = .pairingRequired(requestId: "pair-1")
            $0.pairingRequestIdState = .init(value: "pair-1")
            $0.authStepPresentation = .init(shouldShow: true)
            $0.statusLineState = .init(value: "Pairing required")
        }

        #expect(store.state.connectMessage == "Pairing required")
        #expect(store.state.pairingRequestId == "pair-1")

        await store.send(.connectionIssueDetected(.init(
            issue: .none,
            requestId: .init(value: nil),
            pauseReconnect: .init(value: false),
            message: .init(value: nil),
            statusText: .init(value: "Connecting"))))
        {
            $0.connectMessageState = .init(value: "Connecting")
            $0.statusLineState = .init(value: "Connecting")
        }

        #expect(store.state.issue == .pairingRequired(requestId: "pair-1"))
        #expect(store.state.shouldShowAuthStep)

        await store.send(.pairingResumeStarted) {
            $0.connectMessageState = .init(value: "Retrying after approval…")
            $0.issue = .none
            $0.authStepPresentation = .init(shouldShow: false)
            $0.statusLineState = .init(value: "Retrying after approval…")
        }

        await store.send(.connectionIssueDetected(.init(
            issue: .unauthorized,
            requestId: .init(value: nil),
            pauseReconnect: .init(value: false),
            message: .init(value: nil),
            statusText: .init(value: "Unauthorized"))))
        {
            $0.connectMessageState = .init(value: "Unauthorized")
            $0.issue = .unauthorized
            $0.authStepPresentation = .init(shouldShow: true)
            $0.statusLineState = .init(value: "Unauthorized")
        }

        await store.send(.connectionIssueDetected(.init(
            issue: .none,
            requestId: .init(value: nil),
            pauseReconnect: .init(value: false),
            message: .init(value: nil),
            statusText: .init(value: "Offline"))))
        {
            $0.connectMessageState = .init(value: "Offline")
            $0.statusLineState = .init(value: "Offline")
        }

        #expect(store.state.issue == .unauthorized)
        #expect(store.state.shouldShowAuthStep)
    }

    @Test @MainActor func `status reducer detects connection issues from problem updates`() async {
        let store = TestStore(initialState: OnboardingStatusFeature.State()) {
            OnboardingStatusFeature()
        }
        let problem = GatewayConnectionProblem(
            kind: .pairingRequired,
            owner: .gateway,
            title: "Pairing required",
            message: "Approve this device",
            requestId: "pair-2",
            retryable: true,
            pauseReconnect: true)

        await store.send(.connectionProblemUpdated(.init(
            problem: problem,
            statusText: .init(value: "Connecting"))))
        {
            $0.connectMessageState = .init(value: "Approve this device")
            $0.issue = .pairingRequired(requestId: "pair-2")
            $0.pairingRequestIdState = .init(value: "pair-2")
            $0.authStepPresentation = .init(shouldShow: true)
            $0.statusLineState = .init(value: "Approve this device")
        }

        await store.send(.pairingResumeStarted) {
            $0.connectMessageState = .init(value: "Retrying after approval…")
            $0.issue = .none
            $0.automaticPairingResume = .init(shouldResume: false)
            $0.authStepPresentation = .init(shouldShow: false)
            $0.statusLineState = .init(value: "Retrying after approval…")
        }

        await store.send(.connectionProblemUpdated(.init(
            problem: nil,
            statusText: .init(value: "pairing required (requestId: fallback-1)"))))
        {
            $0.connectMessageState = .init(value: "pairing required (requestId: fallback-1)")
            $0.issue = .pairingRequired(requestId: "fallback-1")
            $0.pairingRequestIdState = .init(value: "fallback-1")
            $0.authStepPresentation = .init(shouldShow: true)
            $0.statusLineState = .init(value: "pairing required (requestId: fallback-1)")
        }
    }

    @Test @MainActor func `status reducer throttles automatic pairing resume attempts`() async {
        let firstAttempt = Date(timeIntervalSince1970: 100)
        let dateProbe = OnboardingDateProbe(firstAttempt)
        let store = TestStore(initialState: OnboardingStatusFeature.State()) {
            OnboardingStatusFeature(clock: dateProbe.client)
        }

        await store.send(.automaticPairingResumeRequested)
        #expect(!store.state.shouldResumePairingAutomatically)

        await store.send(.connectionIssueDetected(.init(
            issue: .pairingRequired(requestId: "pair-1"),
            requestId: .init(value: "pair-1"),
            pauseReconnect: .init(value: false),
            message: .init(value: "Pairing required"),
            statusText: .init(value: ""))))
        {
            $0.connectMessageState = .init(value: "Pairing required")
            $0.issue = .pairingRequired(requestId: "pair-1")
            $0.pairingRequestIdState = .init(value: "pair-1")
            $0.authStepPresentation = .init(shouldShow: true)
            $0.statusLineState = .init(value: "Pairing required")
        }

        await store.send(.automaticPairingResumeRequested) {
            $0.lastPairingAutoResumeAttemptState = .init(value: firstAttempt)
            $0.automaticPairingResume = .init(shouldResume: true)
        }

        #expect(store.state.lastPairingAutoResumeAttemptAt == firstAttempt)

        let throttledAttempt = firstAttempt.addingTimeInterval(3)
        dateProbe.now = throttledAttempt
        await store.send(.automaticPairingResumeRequested) {
            $0.automaticPairingResume = .init(shouldResume: false)
        }

        let laterAttempt = firstAttempt.addingTimeInterval(7)
        dateProbe.now = laterAttempt
        await store.send(.automaticPairingResumeRequested) {
            $0.lastPairingAutoResumeAttemptState = .init(value: laterAttempt)
            $0.automaticPairingResume = .init(shouldResume: true)
        }

        await store.send(.connectionActivityStarted(.init(id: .init(value: "retry-auto")))) {
            $0.connectingGatewayIDState = .init(value: "retry-auto")
        }

        let blockedAttempt = laterAttempt.addingTimeInterval(7)
        dateProbe.now = blockedAttempt
        await store.send(.automaticPairingResumeRequested) {
            $0.automaticPairingResume = .init(shouldResume: false)
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
            $0.gatewayTokenState = .init(value: " token-1 ")
            $0.gatewayPasswordState = .init(value: " password-1 ")
        }

        #expect(store.state.gatewayToken == " token-1 ")
        #expect(store.state.gatewayPassword == " password-1 ")
        #expect(store.state.hasGatewayToken)
        #expect(store.state.hasGatewayPassword)

        await store.send(.gatewayTokenChanged(.init(token: .init(value: "token-2")))) {
            $0.gatewayTokenState = .init(value: "token-2")
        }

        await store.send(.gatewayPasswordChanged(.init(password: .init(value: "   ")))) {
            $0.gatewayPasswordState = .init(value: "   ")
        }

        #expect(store.state.gatewayToken == "token-2")
        #expect(store.state.gatewayPassword == "   ")
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
            $0.gatewayTokenState = .init(value: "token-3")
            $0.gatewayPasswordState = .init(value: "password-3")
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
            $0.gatewayTokenState = .init(value: "")
            $0.gatewayPasswordState = .init(value: "")
            $0.pendingManualAuthOverride = nil
        }

        #expect(store.state.gatewayToken.isEmpty)
        #expect(store.state.gatewayPassword.isEmpty)
        #expect(!store.state.hasGatewayToken)
        #expect(!store.state.hasGatewayPassword)
    }

    @Test @MainActor func `credentials reducer derives setup auth persistence request from gateway link`() async {
        let probe = OnboardingGatewaySetupAuthPersistenceProbe()
        probe.currentInstanceID = .init(value: " instance-1 ")
        let link = GatewayConnectDeepLink(
            host: "gateway.example.com",
            port: 443,
            tls: true,
            bootstrapToken: "bootstrap-1",
            token: "token-3",
            password: "password-3")
        let setupAuth = GatewayConnectionController.ManualAuthOverride.setupAuth(from: link)
        let request = OnboardingGatewaySetupAuthPersistenceRequest(
            setupAuth: setupAuth,
            instanceId: .init(value: " instance-1 "))
        let store = TestStore(initialState: OnboardingCredentialsFeature.State()) {
            OnboardingCredentialsFeature(setupAuthPersistenceClient: probe.client)
        }

        await store.send(.setupLinkApplied(.init(link: link))) {
            $0.gatewayTokenState = .init(value: "token-3")
            $0.gatewayPasswordState = .init(value: "password-3")
            $0.pendingManualAuthOverride = GatewayConnectionController.ManualAuthOverride.explicit(
                token: "token-3",
                bootstrapToken: "bootstrap-1",
                password: "password-3")
        }
        await store.receive(.setupAuthPersistenceRequested(request))
        await store.finish()

        #expect(probe.preparedInstanceIDs == [.init(value: " instance-1 ")])
        #expect(probe.savedRequests == [request])
    }

    @Test @MainActor func `credentials reducer loads saved manual values through client`() async {
        let probe = OnboardingGatewayCredentialsPersistenceProbe()
        probe.gatewayTokens["instance-1"] = "token-1"
        probe.gatewayPasswords["instance-1"] = "password-1"
        let store = TestStore(initialState: OnboardingCredentialsFeature.State()) {
            OnboardingCredentialsFeature(credentialsPersistenceClient: probe.client)
        }

        await store.send(.credentialsLoadRequested(.init(
            instanceId: .init(value: " instance-1 "))))
        {
            $0.gatewayTokenState = .init(value: "token-1")
            $0.gatewayPasswordState = .init(value: "password-1")
        }

        await store.send(.credentialsLoadRequested(.init(
            instanceId: .init(value: " "))))

        #expect(probe.loadedInstanceIds == ["instance-1"])
    }

    @Test @MainActor func `credentials reducer persists manual values through client`() async {
        let probe = OnboardingGatewayCredentialsPersistenceProbe()
        let store = TestStore(initialState: OnboardingCredentialsFeature.State()) {
            OnboardingCredentialsFeature(credentialsPersistenceClient: probe.client)
        }

        await store.send(.gatewayTokenPersistenceRequested(.init(
            value: .init(rawValue: " token-2 "),
            instanceId: .init(value: " instance-1 "))))
        await store.send(.gatewayPasswordPersistenceRequested(.init(
            value: .init(rawValue: " password-2 "),
            instanceId: .init(value: " instance-1 "))))
        await store.finish()

        #expect(probe.savedTokens == ["instance-1:token-2"])
        #expect(probe.savedPasswords == ["instance-1:password-2"])
    }

    @Test @MainActor func `credentials reducer persists manual input changes through client`() async {
        let probe = OnboardingGatewayCredentialsPersistenceProbe()
        let store = TestStore(initialState: OnboardingCredentialsFeature.State()) {
            OnboardingCredentialsFeature(credentialsPersistenceClient: probe.client)
        }

        await store.send(.gatewayTokenInputChanged(.init(
            value: .init(value: " token-3 "),
            instanceId: .init(value: " instance-1 "))))
        {
            $0.gatewayTokenState = .init(value: " token-3 ")
        }
        await store.receive(.gatewayTokenPersistenceRequested(.init(
            value: .init(rawValue: " token-3 "),
            instanceId: .init(value: " instance-1 "))))
        await store.send(.gatewayPasswordInputChanged(.init(
            value: .init(value: " password-3 "),
            instanceId: .init(value: " instance-1 "))))
        {
            $0.gatewayPasswordState = .init(value: " password-3 ")
        }
        await store.receive(.gatewayPasswordPersistenceRequested(.init(
            value: .init(rawValue: " password-3 "),
            instanceId: .init(value: " instance-1 "))))
        await store.finish()

        #expect(probe.savedTokens == ["instance-1:token-3"])
        #expect(probe.savedPasswords == ["instance-1:password-3"])
    }

    @Test @MainActor func `credentials reducer skips manual persistence without instance id`() async {
        let probe = OnboardingGatewayCredentialsPersistenceProbe()
        let store = TestStore(initialState: OnboardingCredentialsFeature.State()) {
            OnboardingCredentialsFeature(credentialsPersistenceClient: probe.client)
        }

        await store.send(.gatewayTokenPersistenceRequested(.init(
            value: .init(rawValue: "token-2"),
            instanceId: .init(value: " "))))
        await store.send(.gatewayPasswordPersistenceRequested(.init(
            value: .init(rawValue: "password-2"),
            instanceId: .init(value: " "))))
        await store.finish()

        #expect(probe.savedTokens.isEmpty)
        #expect(probe.savedPasswords.isEmpty)
    }

    @Test @MainActor func `credentials reducer persists setup auth through client`() async {
        let probe = OnboardingGatewaySetupAuthPersistenceProbe()
        let link = GatewayConnectDeepLink(
            host: "gateway.example.com",
            port: 443,
            tls: true,
            bootstrapToken: "bootstrap-1",
            token: "token-3",
            password: "password-3")
        let setupAuth = GatewayConnectionController.ManualAuthOverride.setupAuth(from: link)
        let request = OnboardingGatewaySetupAuthPersistenceRequest(
            setupAuth: setupAuth,
            instanceId: .init(value: " instance-1 "))
        let store = TestStore(initialState: OnboardingCredentialsFeature.State()) {
            OnboardingCredentialsFeature(setupAuthPersistenceClient: probe.client)
        }

        await store.send(.setupAuthPersistenceRequested(request))
        await store.finish()

        #expect(probe.preparedInstanceIDs == [.init(value: " instance-1 ")])
        #expect(probe.savedRequests == [request])
    }

    @Test @MainActor func `setup code reducer owns setup text and status`() async {
        let store = TestStore(initialState: OnboardingSetupCodeFeature.State()) {
            OnboardingSetupCodeFeature()
        }

        await store.send(.setupCodeChanged(.init(code: .init(value: "  oc_setup_123  ")))) {
            $0.setupCodeState = .init(value: "  oc_setup_123  ")
        }

        #expect(store.state.setupCode == "  oc_setup_123  ")
        #expect(store.state.trimmedSetupCode == "oc_setup_123")
        #expect(store.state.canApply)

        await store.send(.applyStarted)

        await store.send(.invalidSetupCodeSubmitted) {
            $0.statusState = .init(value: "Setup code not recognized or uses an insecure ws:// gateway URL.")
        }

        #expect(store.state.status == "Setup code not recognized or uses an insecure ws:// gateway URL.")

        await store.send(.statusCleared) {
            $0.statusState = .init(value: nil)
        }

        await store.send(.setupCodeAccepted) {
            $0.setupCodeState = .init(value: "")
            $0.statusState = .init(value: "Setup code applied. Connecting...")
        }

        await store.send(.setupCodeChanged(.init(code: .init(value: "  ")))) {
            $0.setupCodeState = .init(value: "  ")
        }

        #expect(!store.state.canApply)

        await store.send(.emptyCodeSubmitted) {
            $0.statusState = .init(value: "Paste a setup code to continue.")
        }

        await store.send(.appleReviewDemoCodeAccepted) {
            $0.setupCodeState = .init(value: "")
            $0.statusState = .init(value: "Apple Review demo mode enabled.")
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
        initialState.setupCodeState = .init(value: "  wss://gateway.example.com:443  ")
        let store = TestStore(initialState: initialState) {
            OnboardingSetupCodeFeature()
        }

        await store.send(.applyRequested) {
            $0.applyResult = .gatewayLink(link)
            $0.gatewayLinkConnectionStart = .init(
                id: .init(value: "setup-code"),
                message: .init(value: "Connecting via setup code..."),
                statusLine: .init(value: "Setup code loaded. Connecting to gateway.example.com:443..."),
                clearsIssue: .init(value: false))
            $0.setupCodeState = .init(value: "")
            $0.statusState = .init(value: "Setup code applied. Connecting...")
        }

        await store.send(.applyResultHandled) {
            $0.applyResult = nil
            $0.gatewayLinkConnectionStart = nil
        }
    }

    @Test @MainActor func `setup code reducer reports failed apply requests`() async {
        let store = TestStore(initialState: OnboardingSetupCodeFeature.State()) {
            OnboardingSetupCodeFeature()
        }

        await store.send(.applyRequested) {
            $0.statusState = .init(value: "Paste a setup code to continue.")
        }

        await store.send(.setupCodeChanged(.init(code: .init(value: "not a setup code")))) {
            $0.setupCodeState = .init(value: "not a setup code")
        }

        await store.send(.applyRequested) {
            $0.statusState = .init(value: "Setup code not recognized or uses an insecure ws:// gateway URL.")
        }
    }

    @Test @MainActor func `setup code reducer classifies apple review apply requests`() async {
        var initialState = OnboardingSetupCodeFeature.State()
        initialState.setupCodeState = .init(value: "  APPLE-REVIEW-DEMO  ")
        let store = TestStore(initialState: initialState) {
            OnboardingSetupCodeFeature()
        }

        await store.send(.applyRequested) {
            $0.applyResult = .appleReviewDemoSetupCode(.init(
                code: .init(value: "APPLE-REVIEW-DEMO"),
                activation: Self.appleReviewDemoActivation()))
            $0.setupCodeState = .init(value: "")
            $0.statusState = .init(value: "Apple Review demo mode enabled.")
        }
    }

    @Test @MainActor func `setup code reducer classifies scanned apple review setup codes`() async {
        var initialState = OnboardingSetupCodeFeature.State()
        initialState.setupCodeState = .init(value: "stale code")
        let store = TestStore(initialState: initialState) {
            OnboardingSetupCodeFeature()
        }

        await store.send(.scannedSetupCodeReceived(.init(code: .init(value: "not a demo code"))))

        await store.send(.scannedSetupCodeReceived(.init(code: .init(value: "  APPLE-REVIEW-DEMO  ")))) {
            $0.applyResult = .appleReviewDemoSetupCode(.init(
                code: .init(value: "APPLE-REVIEW-DEMO"),
                activation: Self.appleReviewDemoActivation()))
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
        initialState.setupCodeState = .init(value: "stale code")
        initialState.statusState = .init(value: "stale status")
        let store = TestStore(initialState: initialState) {
            OnboardingSetupCodeFeature()
        }

        await store.send(.scannedGatewayLinkReceived(.init(link: link))) {
            $0.applyResult = .gatewayLink(link)
            $0.scannedGatewayLinkConnectionStatusUpdate = .init(
                message: .init(value: "Connecting via QR code..."),
                statusLine: .init(value: "QR loaded. Connecting to gateway.example.com:443..."))
            $0.statusState = .init(value: nil)
        }

        await store.send(.applyResultHandled) {
            $0.applyResult = nil
            $0.scannedGatewayLinkConnectionStatusUpdate = nil
        }
    }

    private static func appleReviewDemoActivation() -> OnboardingSetupCodeFeature.AppleReviewDemoActivation {
        .init(
            appleReviewDemoAction: .enableRequested,
            presentationAction: .qrScannerDismissed,
            statusAction: .appleReviewDemoModeEnabled,
            connectionFormAction: .selectedModeChanged(.init(mode: .homeNetwork)))
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

    private final class OnboardingResetProbe: @unchecked Sendable {
        var resetInstanceIds: [OnboardingGatewayCurrentInstanceID] = []

        var client: OnboardingResetClient {
            OnboardingResetClient(reset: { instanceId in
                self.resetInstanceIds.append(instanceId)
            })
        }
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

    private final class OnboardingGatewayDisconnectProbe: @unchecked Sendable {
        var disconnectCount = 0

        var client: OnboardingGatewayDisconnectClient {
            OnboardingGatewayDisconnectClient(disconnect: {
                self.disconnectCount += 1
            })
        }
    }

    private final class OnboardingAppleReviewDemoProbe: @unchecked Sendable {
        var enterCount = 0

        var client: OnboardingAppleReviewDemoClient {
            OnboardingAppleReviewDemoClient(enter: {
                self.enterCount += 1
            })
        }
    }

    private final class OnboardingPairingResumeProbe: @unchecked Sendable {
        var resumeCount = 0

        var client: OnboardingPairingResumeClient {
            OnboardingPairingResumeClient(resume: {
                self.resumeCount += 1
            })
        }
    }

    private final class OnboardingDateProbe: @unchecked Sendable {
        var now: Date

        var client: OnboardingPairingResumeClockClient {
            OnboardingPairingResumeClockClient(now: {
                .init(value: self.now)
            })
        }

        init(_ now: Date) {
            self.now = now
        }
    }

    private final class OnboardingGatewayCredentialsPersistenceProbe: @unchecked Sendable {
        var gatewayPasswords: [String: String] = [:]
        var gatewayTokens: [String: String] = [:]
        var loadedInstanceIds: [String] = []
        var savedPasswords: [String] = []
        var savedTokens: [String] = []

        var client: OnboardingGatewayCredentialsPersistenceClient {
            OnboardingGatewayCredentialsPersistenceClient(
                loadCredentials: { instanceId in
                    let instanceId = instanceId.trimmedValue ?? ""
                    self.loadedInstanceIds.append(instanceId)
                    return .init(
                        token: self.gatewayTokens[instanceId] ?? "",
                        password: self.gatewayPasswords[instanceId] ?? "")
                },
                saveGatewayPassword: { value, instanceId in
                    guard let instanceId = instanceId.trimmedValue else { return }
                    self.savedPasswords.append("\(instanceId):\(value.value)")
                },
                saveGatewayToken: { value, instanceId in
                    guard let instanceId = instanceId.trimmedValue else { return }
                    self.savedTokens.append("\(instanceId):\(value.value)")
                })
        }
    }

    private final class OnboardingGatewaySetupAuthPersistenceProbe: @unchecked Sendable {
        var currentInstanceID = OnboardingGatewayCurrentInstanceID(value: "instance-1")
        var preparedInstanceIDs: [OnboardingGatewayCurrentInstanceID] = []
        var savedRequests: [OnboardingGatewaySetupAuthPersistenceRequest] = []

        var client: OnboardingGatewaySetupAuthPersistenceClient {
            OnboardingGatewaySetupAuthPersistenceClient(
                currentInstanceID: {
                    self.currentInstanceID
                },
                prepareForBootstrapPairing: { instanceId in
                    self.preparedInstanceIDs.append(instanceId)
                },
                saveSetupAuth: { request in
                    self.savedRequests.append(request)
                })
        }
    }
}

extension OnboardingStateStoreTests {
    @Test @MainActor func `connection form reducer normalizes ports and mode defaults`() async {
        let store = TestStore(initialState: OnboardingConnectionFormFeature.State()) {
            OnboardingConnectionFormFeature()
        }

        await store.send(.initialized(.init(
            host: .init(value: "openclaw.local"),
            port: .init(value: 18789),
            tls: .init(value: true),
            lastMode: .developerLocal)))
        {
            $0.selectedMode = .developerLocal
            $0.manualHostState = .init(value: "localhost")
            $0.manualTLSState = .init(value: false)
        }

        await store.send(.manualPortTextChanged(.init(text: .init(value: "65abc536")))) {
            $0.manualPortState = .init(value: 65535)
            $0.manualPortTextState = .init(value: "65535")
        }

        await store.send(.manualPortTextChanged(.init(text: .init(value: "0")))) {
            $0.manualPortState = .init(value: 0)
            $0.manualPortTextState = .init(value: "")
        }

        #expect(!store.state.canConnectManual)

        await store.send(.manualConnectionRequested)

        await store.send(.modeSelected(.init(mode: .remoteDomain))) {
            $0.selectedMode = .remoteDomain
            $0.manualHostState = .init(value: "")
            $0.manualPortState = .init(value: 18789)
            $0.manualPortTextState = .init(value: "18789")
            $0.manualTLSState = .init(value: true)
        }

        await store.send(.manualHostChanged(.init(host: .init(value: "gateway.example.com")))) {
            $0.manualHostState = .init(value: "gateway.example.com")
        }

        #expect(store.state.manualHost == "gateway.example.com")

        await store.send(.manualTLSChanged(.init(useTLS: .init(value: false)))) {
            $0.manualTLSState = .init(value: false)
        }

        #expect(!store.state.manualTLS)

        #expect(store.state.canConnectManual)

        await store.send(.gatewayLinkApplied(.init(
            host: .init(value: "studio.local"),
            port: .init(value: 19000),
            tls: .init(value: false))))
        {
            $0.manualHostState = .init(value: "studio.local")
            $0.manualPortState = .init(value: 19000)
            $0.manualPortTextState = .init(value: "19000")
            $0.manualTLSState = .init(value: false)
        }

        await store.send(.manualConnectionRequested) {
            $0.manualConnectionRequest = OnboardingConnectionFormFeature.ManualConnectionRequest(
                host: .init(value: "studio.local"),
                port: .init(value: 19000),
                useTLS: .init(value: false),
                connectionStart: .init(
                    id: .init(value: "manual"),
                    message: .init(value: "Connecting to studio.local…"),
                    statusLine: .init(value: "Connecting to studio.local:19000…"),
                    clearsIssue: .init(value: true)))
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

    @Test @MainActor func `connection form reducer loads saved connection defaults`() async {
        let defaultsProbe = OnboardingConnectionFormDefaultsProbe()
        defaultsProbe.defaults = .init(
            host: .init(value: "saved.example.com"),
            port: .init(value: 443),
            tls: .init(value: true),
            lastMode: .remoteDomain,
            hasSavedGatewayConnection: .init(value: true))
        let store = TestStore(initialState: OnboardingConnectionFormFeature.State()) {
            OnboardingConnectionFormFeature(defaultsClient: defaultsProbe.client)
        }

        await store.send(.initialConnectionLoadRequested) {
            $0.manualHostState = .init(value: "saved.example.com")
            $0.manualPortState = .init(value: 443)
            $0.manualPortTextState = .init(value: "443")
            $0.manualTLSState = .init(value: true)
            $0.selectedMode = .remoteDomain
            $0.savedGatewayConnection = .init(value: true)
        }

        #expect(defaultsProbe.loadCount == 1)
    }
}

private final class OnboardingProgressPersistenceProbe: @unchecked Sendable {
    var completedModes: [OnboardingConnectionMode?] = []
    var firstRunIntroSeenCount = 0

    var client: OnboardingProgressPersistenceClient {
        OnboardingProgressPersistenceClient(
            markCompleted: { mode in
                self.completedModes.append(mode)
            },
            markFirstRunIntroSeen: {
                self.firstRunIntroSeenCount += 1
            })
    }
}

private final class OnboardingConnectionFormDefaultsProbe: @unchecked Sendable {
    var defaults = OnboardingConnectionFormDefaults(
        host: .init(value: "openclaw.local"),
        port: .init(value: 18789),
        tls: .init(value: true),
        lastMode: nil,
        hasSavedGatewayConnection: .init(value: false))
    var loadCount = 0

    var client: OnboardingConnectionFormDefaultsClient {
        OnboardingConnectionFormDefaultsClient(loadDefaults: {
            self.loadCount += 1
            return self.defaults
        })
    }
}
