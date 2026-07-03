import ComposableArchitecture
import OpenClawKit
import Testing
@testable import OpenClaw

@MainActor
struct SettingsNavigationFeatureTests {
    @Test func `initial route sets path once`() async {
        let store = TestStore(initialState: SettingsNavigationFeature.State()) {
            SettingsNavigationFeature()
        }

        await store.send(.initialRouteRequested(.voice)) {
            $0.navigationPath = [.voice]
        }
        await store.send(.initialRouteRequested(.voice))
    }

    @Test func `missing initial route leaves path unchanged`() async {
        let store = TestStore(initialState: SettingsNavigationFeature.State()) {
            SettingsNavigationFeature()
        }

        await store.send(.initialRouteRequested(nil))
    }

    @Test func `route opened replaces navigation path`() async {
        var initialState = SettingsNavigationFeature.State()
        initialState.navigationPath = [.gateway]
        let store = TestStore(initialState: initialState) {
            SettingsNavigationFeature()
        }

        await store.send(.routeOpened(.notifications)) {
            $0.navigationPath = [.notifications]
        }
    }

    @Test func `swift ui path changes replace reducer path`() async {
        var initialState = SettingsNavigationFeature.State()
        initialState.navigationPath = [.gateway]
        let store = TestStore(initialState: initialState) {
            SettingsNavigationFeature()
        }

        await store.send(.navigationPathChanged([.gateway, .voice])) {
            $0.navigationPath = [.gateway, .voice]
        }
    }

    @Test func `settings presentation opens and dismisses talk issue details`() async {
        let store = TestStore(initialState: SettingsPresentationFeature.State()) {
            SettingsPresentationFeature()
        }

        await store.send(.talkIssueDetailsButtonTapped) {
            $0.showTalkIssueDetails = true
        }
        await store.send(.talkIssueDetailsDismissed) {
            $0.showTalkIssueDetails = false
        }
    }

    @Test func `settings presentation opens and dismisses gateway problem details`() async {
        let store = TestStore(initialState: SettingsPresentationFeature.State()) {
            SettingsPresentationFeature()
        }

        await store.send(.gatewayProblemDetailsButtonTapped) {
            $0.showGatewayProblemDetails = true
        }
        await store.send(.gatewayProblemDetailsDismissed) {
            $0.showGatewayProblemDetails = false
        }
    }

    @Test func `settings presentation opens and dismisses reset onboarding alert`() async {
        let store = TestStore(initialState: SettingsPresentationFeature.State()) {
            SettingsPresentationFeature()
        }

        await store.send(.resetOnboardingButtonTapped) {
            $0.showResetOnboardingAlert = true
        }
        await store.send(.resetOnboardingAlertDismissed) {
            $0.showResetOnboardingAlert = false
        }
    }

    @Test func `settings presentation opens and dismisses notification relay disclosure`() async {
        let store = TestStore(initialState: SettingsPresentationFeature.State()) {
            SettingsPresentationFeature()
        }

        await store.send(.notificationRelayDisclosureRequested) {
            $0.showNotificationRelayDisclosure = true
        }
        await store.send(.notificationRelayDisclosureDismissed) {
            $0.showNotificationRelayDisclosure = false
        }
    }

    @Test func `settings presentation opens and dismisses QR scanner`() async {
        let store = TestStore(initialState: SettingsPresentationFeature.State()) {
            SettingsPresentationFeature()
        }

        await store.send(.qrScannerButtonTapped) {
            $0.showQRScanner = true
        }
        await store.send(.qrScannerDismissed) {
            $0.showQRScanner = false
        }
    }

    @Test func `settings presentation records and dismisses QR scanner error`() async {
        var initialState = SettingsPresentationFeature.State()
        initialState.showQRScanner = true
        let store = TestStore(initialState: initialState) {
            SettingsPresentationFeature()
        }

        await store.send(.qrScannerErrorReceived("Camera unavailable")) {
            $0.showQRScanner = false
            $0.scannerError = "Camera unavailable"
        }
        await store.send(.qrScannerErrorDismissed) {
            $0.scannerError = nil
        }
    }

    @Test func `settings diagnostics completion records last run summary`() async {
        let store = TestStore(initialState: SettingsDiagnosticsFeature.State()) {
            SettingsDiagnosticsFeature()
        }

        await store.send(.diagnosticsCompleted(issueCount: 2, lastRunText: "4:20 PM")) {
            $0.issueCount = 2
            $0.lastRunText = "4:20 PM"
        }
    }

    @Test func `settings gateway activity tracks reconnect lifecycle`() async {
        let store = TestStore(initialState: SettingsGatewayActivityFeature.State()) {
            SettingsGatewayActivityFeature()
        }

        await store.send(.reconnectStarted) {
            $0.isReconnectingGateway = true
        }
        await store.send(.reconnectFinished) {
            $0.isReconnectingGateway = false
        }
    }

    @Test func `settings gateway activity tracks refresh lifecycle`() async {
        let store = TestStore(initialState: SettingsGatewayActivityFeature.State()) {
            SettingsGatewayActivityFeature()
        }

        await store.send(.refreshStarted) {
            $0.isRefreshingGateway = true
        }
        await store.send(.refreshFinished) {
            $0.isRefreshingGateway = false
        }
    }

    @Test func `settings location tracks change lifecycle`() async {
        var initialState = SettingsLocationFeature.State()
        initialState.statusText = "Location permission was not granted."
        let store = TestStore(initialState: initialState) {
            SettingsLocationFeature()
        }

        await store.send(.locationChangeStarted) {
            $0.isChangingLocationMode = true
            $0.statusText = nil
        }
        await store.send(.locationChangeFinished) {
            $0.isChangingLocationMode = false
        }
    }

    @Test func `settings location records applied mode`() async {
        let store = TestStore(initialState: SettingsLocationFeature.State()) {
            SettingsLocationFeature()
        }

        await store.send(.locationModeApplied(OpenClawLocationMode.always.rawValue)) {
            $0.previousLocationModeRaw = OpenClawLocationMode.always.rawValue
        }
    }

    @Test func `settings location records permission denial`() async {
        var initialState = SettingsLocationFeature.State()
        initialState.previousLocationModeRaw = OpenClawLocationMode.whileUsing.rawValue
        let store = TestStore(initialState: initialState) {
            SettingsLocationFeature()
        }

        await store.send(.locationPermissionDenied(previousRawValue: OpenClawLocationMode.off.rawValue)) {
            $0.previousLocationModeRaw = OpenClawLocationMode.off.rawValue
            $0.statusText = "Location permission was not granted."
        }
    }

    @Test func `settings notifications record permission status`() async {
        let store = TestStore(initialState: SettingsNotificationFeature.State()) {
            SettingsNotificationFeature()
        }

        await store.send(.statusChanged(.notSet)) {
            $0.status = .notSet
        }
    }

    @Test func `settings notifications track authorization request lifecycle`() async {
        let store = TestStore(initialState: SettingsNotificationFeature.State()) {
            SettingsNotificationFeature()
        }

        await store.send(.authorizationRequestStarted) {
            $0.isRequestingAuthorization = true
        }
        await store.send(.authorizationRequestFinished(.allowed)) {
            $0.isRequestingAuthorization = false
            $0.status = .allowed
        }
    }

    @Test func `settings agent selection records picker changes`() async {
        let store = TestStore(initialState: SettingsAgentSelectionFeature.State()) {
            SettingsAgentSelectionFeature()
        }

        await store.send(.pickerSelectionChanged("agent-1")) {
            $0.selectedAgentPickerId = "agent-1"
        }
    }

    @Test func `settings agent selection syncs external agent selection`() async {
        var initialState = SettingsAgentSelectionFeature.State()
        initialState.selectedAgentPickerId = "agent-1"
        let store = TestStore(initialState: initialState) {
            SettingsAgentSelectionFeature()
        }

        await store.send(.selectedAgentSynced("agent-2")) {
            $0.selectedAgentPickerId = "agent-2"
        }
        await store.send(.selectedAgentSynced(nil)) {
            $0.selectedAgentPickerId = ""
        }
    }

    @Test func `settings share instruction records text changes`() async {
        let store = TestStore(initialState: SettingsShareInstructionFeature.State()) {
            SettingsShareInstructionFeature()
        }

        await store.send(.defaultShareInstructionChanged("Summarize this for my agent.")) {
            $0.defaultShareInstruction = "Summarize this for my agent."
        }
    }

    @Test func `settings share instruction loads persisted value`() async {
        var initialState = SettingsShareInstructionFeature.State()
        initialState.defaultShareInstruction = "Previous value"
        let store = TestStore(initialState: initialState) {
            SettingsShareInstructionFeature()
        }

        await store.send(.defaultShareInstructionLoaded("Use the research agent.")) {
            $0.defaultShareInstruction = "Use the research agent."
        }
    }

    @Test func `settings manual gateway port filters text changes`() async {
        let store = TestStore(initialState: SettingsManualGatewayPortFeature.State()) {
            SettingsManualGatewayPortFeature()
        }

        await store.send(.manualGatewayPortTextChanged("44a3")) {
            $0.manualGatewayPortText = "443"
            $0.manualGatewayPort = 443
        }
        await store.send(.manualGatewayPortTextChanged("")) {
            $0.manualGatewayPortText = ""
            $0.manualGatewayPort = 0
        }
    }

    @Test func `settings manual gateway port syncs external values`() async {
        let store = TestStore(initialState: SettingsManualGatewayPortFeature.State()) {
            SettingsManualGatewayPortFeature()
        }

        await store.send(.manualGatewayPortSynced(443)) {
            $0.manualGatewayPortText = "443"
            $0.manualGatewayPort = 443
        }
        await store.send(.manualGatewayPortSynced(0)) {
            $0.manualGatewayPortText = ""
            $0.manualGatewayPort = 0
        }
    }

    @Test func `settings manual gateway port validates and resolves defaults`() {
        var state = SettingsManualGatewayPortFeature.State()
        state.manualGatewayPort = 65_536
        state.manualGatewayPortText = "65536"

        #expect(!state.isManualPortValid)
        #expect(state.resolvedManualPort(host: "gateway.example.com", useTLS: true) == nil)

        state.manualGatewayPort = 0
        state.manualGatewayPortText = ""

        #expect(state.isManualPortValid)
        #expect(state.resolvedManualPort(host: "", useTLS: true) == nil)
        #expect(state.resolvedManualPort(host: "gateway.example.com", useTLS: true) == 18789)
        #expect(state.resolvedManualPort(host: "device.sample.ts.net", useTLS: true) == 443)
        #expect(state.resolvedManualPort(host: "device.sample.ts.net", useTLS: false) == 18789)
    }
}
