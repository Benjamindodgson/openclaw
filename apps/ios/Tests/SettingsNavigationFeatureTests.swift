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

    @Test func `settings appearance syncs persisted preference`() async {
        let store = TestStore(initialState: SettingsAppearanceFeature.State()) {
            SettingsAppearanceFeature()
        }

        await store.send(.appearancePreferenceSynced(AppAppearancePreference.dark.rawValue)) {
            $0.appearancePreferenceRaw = AppAppearancePreference.dark.rawValue
        }
    }

    @Test func `settings appearance records picker changes`() async {
        let store = TestStore(initialState: SettingsAppearanceFeature.State()) {
            SettingsAppearanceFeature()
        }

        await store.send(.appearancePreferenceChanged(AppAppearancePreference.light.rawValue)) {
            $0.appearancePreferenceRaw = AppAppearancePreference.light.rawValue
        }
    }

    @Test func `settings appearance falls back to system for invalid stored values`() {
        var state = SettingsAppearanceFeature.State()
        state.appearancePreferenceRaw = "sepia"

        #expect(state.appearancePreference == .system)
    }

    @Test func `settings device identity syncs persisted display name`() async {
        let store = TestStore(initialState: SettingsDeviceIdentityFeature.State()) {
            SettingsDeviceIdentityFeature()
        }

        await store.send(.displayNameSynced("Kitchen iPad")) {
            $0.displayName = "Kitchen iPad"
        }
    }

    @Test func `settings device identity records display name changes`() async {
        let store = TestStore(initialState: SettingsDeviceIdentityFeature.State()) {
            SettingsDeviceIdentityFeature()
        }

        await store.send(.displayNameChanged("Field Node")) {
            $0.displayName = "Field Node"
        }
    }

    @Test func `settings debug options sync persisted values`() async {
        let store = TestStore(initialState: SettingsDebugOptionsFeature.State()) {
            SettingsDebugOptionsFeature()
        }

        await store.send(.debugOptionsSynced(
            discoveryDebugLogsEnabled: true,
            canvasDebugStatusEnabled: true))
        {
            $0.discoveryDebugLogsEnabled = true
            $0.canvasDebugStatusEnabled = true
        }
    }

    @Test func `settings debug options record toggle changes`() async {
        let store = TestStore(initialState: SettingsDebugOptionsFeature.State()) {
            SettingsDebugOptionsFeature()
        }

        await store.send(.discoveryDebugLogsChanged(true)) {
            $0.discoveryDebugLogsEnabled = true
        }
        await store.send(.canvasDebugStatusChanged(true)) {
            $0.canvasDebugStatusEnabled = true
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

    @Test func `settings gateway connection tracks discovered gateway lifecycle`() async {
        let store = TestStore(initialState: SettingsGatewayConnectionFeature.State()) {
            SettingsGatewayConnectionFeature()
        }

        await store.send(.connectionStarted("gateway-1")) {
            $0.connectingGatewayID = "gateway-1"
        }
        await store.send(.connectionFinished) {
            $0.connectingGatewayID = nil
        }
    }

    @Test func `settings gateway connection tracks manual lifecycle`() async {
        let store = TestStore(initialState: SettingsGatewayConnectionFeature.State()) {
            SettingsGatewayConnectionFeature()
        }

        await store.send(.connectionStarted("manual")) {
            $0.connectingGatewayID = "manual"
        }
        await store.send(.connectionFinished) {
            $0.connectingGatewayID = nil
        }
    }

    @Test func `settings gateway setup status records messages`() async {
        let store = TestStore(initialState: SettingsGatewaySetupStatusFeature.State()) {
            SettingsGatewaySetupStatusFeature()
        }

        await store.send(.statusChanged("Failed: host required")) {
            $0.statusText = "Failed: host required"
        }
    }

    @Test func `settings gateway setup status clears messages`() async {
        var initialState = SettingsGatewaySetupStatusFeature.State()
        initialState.statusText = "Setup code applied. Connecting..."
        let store = TestStore(initialState: initialState) {
            SettingsGatewaySetupStatusFeature()
        }

        await store.send(.statusChanged(nil)) {
            $0.statusText = nil
        }
    }

    @Test func `settings gateway setup link stages pending links`() async {
        let link = GatewayConnectDeepLink(
            host: "gateway.example.com",
            port: 443,
            tls: true,
            bootstrapToken: "bootstrap",
            token: nil,
            password: nil)
        let store = TestStore(initialState: SettingsGatewaySetupLinkFeature.State()) {
            SettingsGatewaySetupLinkFeature()
        }

        await store.send(.setupLinkStaged(link)) {
            $0.stagedGatewaySetupLink = link
        }
    }

    @Test func `settings gateway setup link staging clears setup code`() async {
        let link = GatewayConnectDeepLink(
            host: "gateway.example.com",
            port: 443,
            tls: true,
            bootstrapToken: nil,
            token: nil,
            password: nil)
        var initialState = SettingsGatewaySetupLinkFeature.State()
        initialState.setupCode = "previous-code"
        let store = TestStore(initialState: initialState) {
            SettingsGatewaySetupLinkFeature()
        }

        await store.send(.setupLinkStaged(link)) {
            $0.setupCode = ""
            $0.stagedGatewaySetupLink = link
        }
    }

    @Test func `settings gateway setup link clears when setup code is pasted`() async {
        let link = GatewayConnectDeepLink(
            host: "gateway.example.com",
            port: 443,
            tls: true,
            bootstrapToken: nil,
            token: nil,
            password: nil)
        var initialState = SettingsGatewaySetupLinkFeature.State()
        initialState.stagedGatewaySetupLink = link
        let store = TestStore(initialState: initialState) {
            SettingsGatewaySetupLinkFeature()
        }

        await store.send(.setupCodeChanged("setup-code")) {
            $0.setupCode = "setup-code"
            $0.stagedGatewaySetupLink = nil
        }
    }

    @Test func `settings gateway setup link syncs persisted setup code`() async {
        let store = TestStore(initialState: SettingsGatewaySetupLinkFeature.State()) {
            SettingsGatewaySetupLinkFeature()
        }

        await store.send(.setupCodeSynced("persisted-code")) {
            $0.setupCode = "persisted-code"
        }
    }

    @Test func `settings gateway credentials load persisted values`() async {
        let store = TestStore(initialState: SettingsGatewayCredentialsFeature.State()) {
            SettingsGatewayCredentialsFeature()
        }

        await store.send(.credentialsLoaded(token: "token-1", password: "password-1")) {
            $0.gatewayToken = "token-1"
            $0.gatewayPassword = "password-1"
        }
    }

    @Test func `settings gateway credentials record field changes`() async {
        let store = TestStore(initialState: SettingsGatewayCredentialsFeature.State()) {
            SettingsGatewayCredentialsFeature()
        }

        await store.send(.gatewayTokenChanged("token-2")) {
            $0.gatewayToken = "token-2"
        }
        await store.send(.gatewayPasswordChanged("password-2")) {
            $0.gatewayPassword = "password-2"
        }
    }

    @Test func `settings gateway credentials apply setup auth`() async {
        let link = GatewayConnectDeepLink(
            host: "gateway.example.com",
            port: 443,
            tls: true,
            bootstrapToken: "bootstrap-1",
            token: "token-3",
            password: "password-3")
        let setupAuth = GatewayConnectionController.ManualAuthOverride.setupAuth(from: link)
        let store = TestStore(initialState: SettingsGatewayCredentialsFeature.State()) {
            SettingsGatewayCredentialsFeature()
        }

        await store.send(.setupAuthApplied(setupAuth)) {
            $0.gatewayToken = "token-3"
            $0.gatewayPassword = "password-3"
            $0.pendingManualAuthOverride = GatewayConnectionController.ManualAuthOverride.explicit(
                token: "token-3",
                bootstrapToken: "bootstrap-1",
                password: "password-3")
        }
    }

    @Test func `settings gateway credentials clear reset state`() async {
        var initialState = SettingsGatewayCredentialsFeature.State()
        initialState.gatewayToken = "token-4"
        initialState.gatewayPassword = "password-4"
        initialState.pendingManualAuthOverride = GatewayConnectionController.ManualAuthOverride.explicit(
            token: "token-4",
            bootstrapToken: "bootstrap-4",
            password: "password-4")
        let store = TestStore(initialState: initialState) {
            SettingsGatewayCredentialsFeature()
        }

        await store.send(.credentialsClearedForOnboardingReset) {
            $0.gatewayToken = ""
            $0.gatewayPassword = ""
            $0.pendingManualAuthOverride = nil
        }
    }

    @Test func `settings gateway credentials clear consumed pending override`() async {
        var initialState = SettingsGatewayCredentialsFeature.State()
        initialState.pendingManualAuthOverride = GatewayConnectionController.ManualAuthOverride.explicit(
            token: "token-5",
            bootstrapToken: "bootstrap-5",
            password: "password-5")
        let store = TestStore(initialState: initialState) {
            SettingsGatewayCredentialsFeature()
        }

        await store.send(.pendingManualAuthOverrideConsumed) {
            $0.pendingManualAuthOverride = nil
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
            $0.locationModeRaw = OpenClawLocationMode.always.rawValue
            $0.previousLocationModeRaw = OpenClawLocationMode.always.rawValue
        }
    }

    @Test func `settings location syncs persisted mode`() async {
        let store = TestStore(initialState: SettingsLocationFeature.State()) {
            SettingsLocationFeature()
        }

        await store.send(.locationModeSynced(OpenClawLocationMode.whileUsing.rawValue)) {
            $0.locationModeRaw = OpenClawLocationMode.whileUsing.rawValue
            $0.previousLocationModeRaw = OpenClawLocationMode.whileUsing.rawValue
        }
    }

    @Test func `settings location ignores persisted sync while changing mode`() async {
        var initialState = SettingsLocationFeature.State()
        initialState.isChangingLocationMode = true
        initialState.locationModeRaw = OpenClawLocationMode.always.rawValue
        initialState.previousLocationModeRaw = OpenClawLocationMode.whileUsing.rawValue
        let store = TestStore(initialState: initialState) {
            SettingsLocationFeature()
        }

        await store.send(.locationModeSynced(OpenClawLocationMode.off.rawValue))
    }

    @Test func `settings location records picker changes`() async {
        let store = TestStore(initialState: SettingsLocationFeature.State()) {
            SettingsLocationFeature()
        }

        await store.send(.locationModeChanged(OpenClawLocationMode.always.rawValue)) {
            $0.locationModeRaw = OpenClawLocationMode.always.rawValue
        }
    }

    @Test func `settings location records permission denial`() async {
        var initialState = SettingsLocationFeature.State()
        initialState.locationModeRaw = OpenClawLocationMode.always.rawValue
        initialState.previousLocationModeRaw = OpenClawLocationMode.whileUsing.rawValue
        let store = TestStore(initialState: initialState) {
            SettingsLocationFeature()
        }

        await store.send(.locationPermissionDenied(previousRawValue: OpenClawLocationMode.off.rawValue)) {
            $0.locationModeRaw = OpenClawLocationMode.off.rawValue
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

    @Test func `settings manual gateway endpoint syncs persisted values`() async {
        let store = TestStore(initialState: SettingsManualGatewayEndpointFeature.State()) {
            SettingsManualGatewayEndpointFeature()
        }

        await store.send(.endpointSynced(
            enabled: true,
            host: "gateway.example.com",
            tls: false))
        {
            $0.manualGatewayEnabled = true
            $0.manualGatewayHost = "gateway.example.com"
            $0.manualGatewayTLS = false
        }
    }

    @Test func `settings manual gateway endpoint records field changes`() async {
        let store = TestStore(initialState: SettingsManualGatewayEndpointFeature.State()) {
            SettingsManualGatewayEndpointFeature()
        }

        await store.send(.manualGatewayEnabledChanged(true)) {
            $0.manualGatewayEnabled = true
        }
        await store.send(.manualGatewayHostChanged("manual.example.com")) {
            $0.manualGatewayHost = "manual.example.com"
        }
        await store.send(.manualGatewayTLSChanged(false)) {
            $0.manualGatewayTLS = false
        }
    }

    @Test func `settings manual gateway endpoint applies setup link host and tls`() async {
        let store = TestStore(initialState: SettingsManualGatewayEndpointFeature.State()) {
            SettingsManualGatewayEndpointFeature()
        }

        await store.send(.setupLinkApplied(host: "link.example.com", tls: true)) {
            $0.manualGatewayHost = "link.example.com"
            $0.manualGatewayTLS = true
        }
    }

    @Test func `settings manual gateway endpoint reset clears enabled and host only`() async {
        var initialState = SettingsManualGatewayEndpointFeature.State()
        initialState.manualGatewayEnabled = true
        initialState.manualGatewayHost = "manual.example.com"
        initialState.manualGatewayTLS = false
        let store = TestStore(initialState: initialState) {
            SettingsManualGatewayEndpointFeature()
        }

        await store.send(.endpointClearedForOnboardingReset) {
            $0.manualGatewayEnabled = false
            $0.manualGatewayHost = ""
        }
    }

    @Test func `settings gateway auto connect syncs persisted value`() async {
        let store = TestStore(initialState: SettingsGatewayAutoConnectFeature.State()) {
            SettingsGatewayAutoConnectFeature()
        }

        await store.send(.enabledSynced(true)) {
            $0.isEnabled = true
        }
    }

    @Test func `settings gateway auto connect records toggle changes`() async {
        let store = TestStore(initialState: SettingsGatewayAutoConnectFeature.State()) {
            SettingsGatewayAutoConnectFeature()
        }

        await store.send(.enabledChanged(true)) {
            $0.isEnabled = true
        }
        await store.send(.enabledChanged(false)) {
            $0.isEnabled = false
        }
    }

    @Test func `settings gateway auto connect disables on onboarding reset`() async {
        var initialState = SettingsGatewayAutoConnectFeature.State()
        initialState.isEnabled = true
        let store = TestStore(initialState: initialState) {
            SettingsGatewayAutoConnectFeature()
        }

        await store.send(.disabledForOnboardingReset) {
            $0.isEnabled = false
        }
    }

    @Test func `settings device capabilities sync persisted values`() async {
        let store = TestStore(initialState: SettingsDeviceCapabilityFeature.State()) {
            SettingsDeviceCapabilityFeature()
        }

        await store.send(.capabilitiesSynced(cameraEnabled: false, preventSleep: true)) {
            $0.cameraEnabled = false
            $0.preventSleep = true
        }
    }

    @Test func `settings device capabilities record field changes`() async {
        let store = TestStore(initialState: SettingsDeviceCapabilityFeature.State()) {
            SettingsDeviceCapabilityFeature()
        }

        await store.send(.cameraEnabledChanged(false)) {
            $0.cameraEnabled = false
        }
        await store.send(.preventSleepChanged(false)) {
            $0.preventSleep = false
        }
    }

    @Test func `settings device capabilities count enabled permissions`() async {
        var state = SettingsDeviceCapabilityFeature.State()
        #expect(state.enabledCount == 2)

        state.cameraEnabled = false
        #expect(state.enabledCount == 1)

        state.preventSleep = false
        #expect(state.enabledCount == 0)
    }

    @Test func `settings voice controls sync persisted values`() async {
        let store = TestStore(initialState: SettingsVoiceControlFeature.State()) {
            SettingsVoiceControlFeature()
        }

        await store.send(.controlsSynced(talkEnabled: true, voiceWakeEnabled: true)) {
            $0.talkEnabled = true
            $0.voiceWakeEnabled = true
        }
    }

    @Test func `settings voice controls record field changes`() async {
        let store = TestStore(initialState: SettingsVoiceControlFeature.State()) {
            SettingsVoiceControlFeature()
        }

        await store.send(.talkEnabledChanged(true)) {
            $0.talkEnabled = true
        }
        await store.send(.voiceWakeEnabledChanged(true)) {
            $0.voiceWakeEnabled = true
        }
    }

    @Test func `settings voice controls disable talk for apple review`() async {
        var initialState = SettingsVoiceControlFeature.State()
        initialState.talkEnabled = true
        initialState.voiceWakeEnabled = true
        let store = TestStore(initialState: initialState) {
            SettingsVoiceControlFeature()
        }

        await store.send(.talkDisabledForAppleReview) {
            $0.talkEnabled = false
        }
    }

    @Test func `settings voice controls summarize active modes`() {
        var state = SettingsVoiceControlFeature.State()
        #expect(state.detailText == "Off")

        state.voiceWakeEnabled = true
        #expect(state.detailText == "Wake on")

        state.talkEnabled = true
        #expect(state.detailText == "Talk + Wake")

        state.voiceWakeEnabled = false
        #expect(state.detailText == "Talk on")
    }

    @Test func `settings talk preferences sync persisted values`() async {
        let store = TestStore(initialState: SettingsTalkPreferencesFeature.State()) {
            SettingsTalkPreferencesFeature()
        }

        await store.send(.preferencesSynced(
            providerSelectionRaw: TalkModeProviderSelection.openAIRealtime.rawValue,
            realtimeVoiceSelectionRaw: " Cedar ",
            speechLocale: "en-US",
            talkButtonEnabled: false,
            talkBackgroundEnabled: true,
            talkSpeakerphoneEnabled: false))
        {
            $0.providerSelectionRaw = TalkModeProviderSelection.openAIRealtime.rawValue
            $0.realtimeVoiceSelectionRaw = "cedar"
            $0.speechLocale = "en-US"
            $0.talkButtonEnabled = false
            $0.talkBackgroundEnabled = true
            $0.talkSpeakerphoneEnabled = false
        }
    }

    @Test func `settings talk preferences normalize picker values`() async {
        var initialState = SettingsTalkPreferencesFeature.State()
        initialState.providerSelectionRaw = TalkModeProviderSelection.openAIRealtime.rawValue
        initialState.realtimeVoiceSelectionRaw = "cedar"
        let store = TestStore(initialState: initialState) {
            SettingsTalkPreferencesFeature()
        }

        await store.send(.providerSelectionChanged("unknown")) {
            $0.providerSelectionRaw = TalkModeProviderSelection.gatewayDefault.rawValue
        }
        await store.send(.realtimeVoiceSelectionChanged("unknown")) {
            $0.realtimeVoiceSelectionRaw = ""
        }
        await store.send(.realtimeVoiceSelectionChanged(" Cedar ")) {
            $0.realtimeVoiceSelectionRaw = "cedar"
        }
    }

    @Test func `settings talk preferences record field changes`() async {
        let store = TestStore(initialState: SettingsTalkPreferencesFeature.State()) {
            SettingsTalkPreferencesFeature()
        }

        await store.send(.speechLocaleChanged("en-US")) {
            $0.speechLocale = "en-US"
        }
        await store.send(.talkBackgroundEnabledChanged(true)) {
            $0.talkBackgroundEnabled = true
        }
        await store.send(.talkButtonEnabledChanged(false)) {
            $0.talkButtonEnabled = false
        }
        await store.send(.talkSpeakerphoneEnabledChanged(false)) {
            $0.talkSpeakerphoneEnabled = false
        }
    }

    @Test func `settings talk preferences show realtime picker for local or gateway realtime`() {
        var state = SettingsTalkPreferencesFeature.State()

        #expect(state.shouldShowRealtimeVoicePicker(gatewayTalkUsesRealtime: false) == false)
        #expect(state.shouldShowRealtimeVoicePicker(gatewayTalkUsesRealtime: true) == true)

        state.providerSelectionRaw = TalkModeProviderSelection.openAIRealtime.rawValue
        #expect(state.shouldShowRealtimeVoicePicker(gatewayTalkUsesRealtime: false) == true)
    }
}
