import ComposableArchitecture
import Foundation
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

        await store.send(.gatewaySnapshotChanged(gatewayServerName: "gateway", hasSavedGatewayConnection: false)) {
            $0.gatewayServerName = "gateway"
            $0.shouldPresentOnLaunch = false
        }

        await store.send(.gatewaySnapshotChanged(gatewayServerName: nil, hasSavedGatewayConnection: true)) {
            $0.gatewayServerName = nil
            $0.hasSavedGatewayConnection = true
        }

        await store.send(.gatewaySnapshotChanged(gatewayServerName: nil, hasSavedGatewayConnection: false)) {
            $0.hasSavedGatewayConnection = false
            $0.shouldPresentOnLaunch = true
        }

        await store.send(.markCompleted(.remoteDomain)) {
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

        await store.send(.qrScannerErrorReceived("Camera unavailable")) {
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

    @Test @MainActor func `step reducer navigates wizard steps`() async {
        let store = TestStore(initialState: OnboardingStepFeature.State(step: .intro)) {
            OnboardingStepFeature()
        }

        #expect(store.state.isFullScreenStep)

        await store.send(.stepChanged(.mode)) {
            $0.step = .mode
        }

        #expect(!store.state.isFullScreenStep)

        await store.send(.backButtonTapped) {
            $0.step = .welcome
        }

        await store.send(.stepChanged(.connect)) {
            $0.step = .connect
        }

        await store.send(.backButtonTapped) {
            $0.step = .mode
        }

        await store.send(.stepChanged(.success)) {
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

        await store.send(.scannerErrorReceived("Camera unavailable")) {
            $0.statusLine = "Scanner error: Camera unavailable"
        }

        await store.send(.connectionStarted(
            id: "manual",
            message: "Connecting to gateway…",
            statusLine: "Connecting to gateway:18789…",
            clearsIssue: true))
        {
            $0.connectingGatewayID = "manual"
            $0.connectMessage = "Connecting to gateway…"
            $0.statusLine = "Connecting to gateway:18789…"
        }

        await store.send(.connectionActivityStarted(id: "retry-auto")) {
            $0.connectingGatewayID = "retry-auto"
        }

        await store.send(.connectionFinished) {
            $0.connectingGatewayID = nil
        }

        await store.send(.gatewayConnected(markedCompleted: true)) {
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

        await store.send(.connectionIssueDetected(
            issue: .pairingRequired(requestId: "pair-1"),
            requestId: "pair-1",
            pauseReconnect: false,
            message: "Pairing required",
            statusText: ""))
        {
            $0.connectMessage = "Pairing required"
            $0.issue = .pairingRequired(requestId: "pair-1")
            $0.pairingRequestId = "pair-1"
            $0.shouldShowAuthStep = true
            $0.statusLine = "Pairing required"
        }

        await store.send(.connectionIssueDetected(
            issue: .none,
            requestId: nil,
            pauseReconnect: false,
            message: nil,
            statusText: "Connecting"))
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

        await store.send(.connectionIssueDetected(
            issue: .unauthorized,
            requestId: nil,
            pauseReconnect: false,
            message: nil,
            statusText: "Unauthorized"))
        {
            $0.connectMessage = "Unauthorized"
            $0.issue = .unauthorized
            $0.shouldShowAuthStep = true
            $0.statusLine = "Unauthorized"
        }

        await store.send(.connectionIssueDetected(
            issue: .none,
            requestId: nil,
            pauseReconnect: false,
            message: nil,
            statusText: "Offline"))
        {
            $0.connectMessage = "Offline"
            $0.statusLine = "Offline"
        }

        #expect(store.state.issue == .unauthorized)
        #expect(store.state.shouldShowAuthStep)
    }

    @Test @MainActor func `credentials reducer owns gateway token and password`() async {
        let store = TestStore(initialState: OnboardingCredentialsFeature.State()) {
            OnboardingCredentialsFeature()
        }

        #expect(!store.state.hasGatewayToken)
        #expect(!store.state.hasGatewayPassword)

        await store.send(.credentialsLoaded(token: " token-1 ", password: " password-1 ")) {
            $0.gatewayToken = " token-1 "
            $0.gatewayPassword = " password-1 "
        }

        #expect(store.state.hasGatewayToken)
        #expect(store.state.hasGatewayPassword)

        await store.send(.gatewayTokenChanged("token-2")) {
            $0.gatewayToken = "token-2"
        }

        await store.send(.gatewayPasswordChanged("   ")) {
            $0.gatewayPassword = "   "
        }

        #expect(!store.state.hasGatewayPassword)

        await store.send(.reset) {
            $0.gatewayToken = ""
            $0.gatewayPassword = ""
        }

        #expect(!store.state.hasGatewayToken)
        #expect(!store.state.hasGatewayPassword)
    }

    @Test @MainActor func `setup code reducer owns setup text and status`() async {
        let store = TestStore(initialState: OnboardingSetupCodeFeature.State()) {
            OnboardingSetupCodeFeature()
        }

        await store.send(.setupCodeChanged("  oc_setup_123  ")) {
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

        await store.send(.setupCodeChanged("  ")) {
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

    @Test @MainActor func `connection form reducer normalizes ports and mode defaults`() async {
        let store = TestStore(initialState: OnboardingConnectionFormFeature.State()) {
            OnboardingConnectionFormFeature()
        }

        await store.send(.initialized(
            host: "openclaw.local",
            port: 18789,
            tls: true,
            lastMode: .developerLocal))
        {
            $0.selectedMode = .developerLocal
            $0.manualHost = "localhost"
            $0.manualTLS = false
        }

        await store.send(.manualPortTextChanged("65abc536")) {
            $0.manualPort = 65535
            $0.manualPortText = "65535"
        }

        await store.send(.manualPortTextChanged("0")) {
            $0.manualPort = 0
            $0.manualPortText = ""
        }

        #expect(!store.state.canConnectManual)

        await store.send(.modeSelected(.remoteDomain)) {
            $0.selectedMode = .remoteDomain
            $0.manualHost = ""
            $0.manualPort = 18789
            $0.manualPortText = "18789"
            $0.manualTLS = true
        }

        await store.send(.manualHostChanged("gateway.example.com")) {
            $0.manualHost = "gateway.example.com"
        }

        #expect(store.state.canConnectManual)

        await store.send(.gatewayLinkApplied(host: "studio.local", port: 19000, tls: false)) {
            $0.manualHost = "studio.local"
            $0.manualPort = 19000
            $0.manualPortText = "19000"
            $0.manualTLS = false
        }

        await store.send(.developerModeDisabled)

        await store.send(.selectedModeChanged(.developerLocal)) {
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
}
