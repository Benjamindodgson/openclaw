import ComposableArchitecture
import OpenClawKit
import SwiftUI
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

    @Test func `settings navigation route metadata covers headers`() {
        let cases: [(SettingsRoute, String, String)] = [
            (.gateway, "Gateway", "Pairing, diagnostics, and Tailscale checks."),
            (.approvals, "Approvals", "Review pending agent actions."),
            (.permissions, "Permissions", "Control device capabilities."),
            (.channels, "Channels", "Message routing and external clients."),
            (.voice, "Voice & Talk", "Talk mode and wake phrase settings."),
            (.diagnostics, "Diagnostics", "Run local health checks."),
            (.privacy, "Privacy", "Data and device privacy controls."),
            (.notifications, "Notifications", "Alert permissions and delivery."),
            (.about, "About", "Version and support details."),
        ]

        for (route, title, subtitle) in cases {
            #expect(SettingsNavigationFeature.State.title(for: route) == title)
            #expect(SettingsNavigationFeature.State.subtitle(for: route) == subtitle)
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

    @Test func `settings approvals sync context`() async {
        let store = TestStore(initialState: SettingsApprovalsFeature.State()) {
            SettingsApprovalsFeature()
        }

        await store.send(.approvalsSynced(
            isAppleReviewDemoModeEnabled: true,
            gatewayConnected: true,
            notificationsNeedAttention: true,
            hasPendingApproval: true,
            pendingCommandPreview: "git status",
            activeAgentName: "Joshtimus Prime",
            isResolvingPendingApproval: true,
            pendingApprovalAllowsAllowAlways: true))
        {
            $0.isAppleReviewDemoModeEnabled = true
            $0.gatewayConnected = true
            $0.notificationsNeedAttention = true
            $0.hasPendingApproval = true
            $0.pendingCommandPreview = "git status"
            $0.activeAgentName = "Joshtimus Prime"
            $0.isResolvingPendingApproval = true
            $0.pendingApprovalAllowsAllowAlways = true
        }
    }

    @Test func `settings approvals summarize empty states`() {
        var state = SettingsApprovalsFeature.State()

        #expect(state.approvalBadgeValue == nil)
        #expect(state.approvalsDetail == "No approvals waiting")
        #expect(state.approvalEmptyDetail == "Connect to the gateway.")
        #expect(state.destinationDetail == "No gateway actions are waiting for review.")
        #expect(state.destinationValue == "clear")
        #expect(state.approvalItems.isEmpty)

        state.gatewayConnected = true
        #expect(state.approvalEmptyDetail == "Gateway requests will appear here.")

        state.notificationsNeedAttention = true
        #expect(state.approvalsDetail == "Notifications off")
        #expect(state.approvalEmptyDetail == "Foreground approvals still appear while OpenClaw is connected.")
        #expect(state.destinationDetail == "Out-of-app approval alerts need notification permission.")
        #expect(state.destinationValue == "Alerts Off")

        state.isAppleReviewDemoModeEnabled = true
        #expect(state.approvalEmptyDetail == "Live gateway requests are disabled in demo mode.")
    }

    @Test func `settings approvals summarize pending request`() {
        var state = SettingsApprovalsFeature.State()
        state.hasPendingApproval = true
        state.pendingCommandPreview = "git status"
        state.activeAgentName = "Joshtimus Prime"

        #expect(state.approvalBadgeValue == "1")
        #expect(state.approvalsDetail == "1 request waiting")
        #expect(state.destinationDetail == "Review the pending gateway action.")
        #expect(state.destinationValue == "1 waiting")

        var items = state.approvalItems
        #expect(items.count == 2)
        #expect(items[0].title == "git status")
        #expect(items[0].detail == "Agent: Joshtimus Prime")
        #expect(items[0].priority == "High")
        #expect(items[1].title == "One-time approval")
        #expect(items[1].priority == "Review")

        state.isResolvingPendingApproval = true
        state.pendingApprovalAllowsAllowAlways = true
        state.notificationsNeedAttention = true

        #expect(state.approvalsDetail == "1 waiting, notifications off")
        items = state.approvalItems
        #expect(items[0].priority == "Resolving")
        #expect(items[1].title == "Permission can be saved")
        #expect(items[1].priority == "Medium")
    }

    @Test func `settings diagnostics completion computes issue count`() async {
        let store = TestStore(initialState: SettingsDiagnosticsFeature.State()) {
            SettingsDiagnosticsFeature()
        }

        await store.send(.diagnosticsCompletionRequested(
            gatewayConnected: false,
            discoveredGatewayCount: 0,
            talkConfigLoaded: false,
            notificationsAllowed: false,
            lastRunText: "4:20 PM"))
        {
            $0.issueCount = 3
            $0.lastRunText = "4:20 PM"
        }
        await store.send(.diagnosticsCompletionRequested(
            gatewayConnected: true,
            discoveredGatewayCount: 1,
            talkConfigLoaded: true,
            notificationsAllowed: true,
            lastRunText: "4:22 PM"))
        {
            $0.issueCount = 0
            $0.lastRunText = "4:22 PM"
        }
    }

    @Test func `settings diagnostics sync context`() async {
        let store = TestStore(initialState: SettingsDiagnosticsFeature.State()) {
            SettingsDiagnosticsFeature()
        }

        await store.send(.diagnosticsContextSynced(
            isAppleReviewDemoModeEnabled: false,
            gatewayConnected: true,
            discoveredGatewayCount: 2,
            discoveryStatusText: "2 gateways found",
            screenRecordActive: true))
        {
            $0.gatewayConnected = true
            $0.discoveredGatewayCount = 2
            $0.discoveryStatusText = "2 gateways found"
            $0.screenRecordActive = true
        }
        await store.send(.diagnosticsContextSynced(
            isAppleReviewDemoModeEnabled: true,
            gatewayConnected: false,
            discoveredGatewayCount: 0,
            discoveryStatusText: "Discovery paused",
            screenRecordActive: false))
        {
            $0.isAppleReviewDemoModeEnabled = true
            $0.gatewayConnected = false
            $0.discoveredGatewayCount = 0
            $0.discoveryStatusText = "Discovery paused"
            $0.screenRecordActive = false
        }
    }

    @Test func `settings diagnostics summarize run state`() {
        var state = SettingsDiagnosticsFeature.State()

        #expect(state.detailText == "System checks")
        #expect(state.runValue == "pending")
        #expect(state.runColor == .secondary)

        state.issueCount = 0
        #expect(state.runValue == "pass")
        #expect(state.runColor == OpenClawBrand.ok)

        state.issueCount = 3
        #expect(state.runValue == "3")
        #expect(state.runColor == OpenClawBrand.warn)
    }

    @Test func `settings diagnostics summarize health state`() {
        var state = SettingsDiagnosticsFeature.State()

        #expect(state.healthValue == "check")
        #expect(state.healthColor == OpenClawBrand.warn)

        state.discoveredGatewayCount = 1
        #expect(state.healthValue == "partial")
        #expect(state.healthColor == OpenClawBrand.warn)

        state.gatewayConnected = true
        #expect(state.healthValue == "ready")
        #expect(state.healthColor == OpenClawBrand.ok)

        state.isAppleReviewDemoModeEnabled = true
        state.gatewayConnected = false
        #expect(state.healthValue == "demo")
        #expect(state.healthColor == OpenClawBrand.ok)
    }

    @Test func `settings diagnostics summarize discovery state`() {
        var state = SettingsDiagnosticsFeature.State()

        #expect(state.discoveryValue == "0")
        #expect(state.discoveryColor == .secondary)
        #expect(state.hasDiscoveredGateway == false)

        state.discoveredGatewayCount = 2
        state.discoveryStatusText = "2 gateways found"
        #expect(state.discoveryValue == "2")
        #expect(state.discoveryColor == OpenClawBrand.accent)
        #expect(state.hasDiscoveredGateway)
        #expect(state.discoveryStatusText == "2 gateways found")
    }

    @Test func `settings diagnostics summarize screen capture state`() {
        var state = SettingsDiagnosticsFeature.State()

        #expect(state.screenCaptureValue == "idle")
        #expect(state.screenCaptureColor == .secondary)

        state.screenRecordActive = true
        #expect(state.screenCaptureValue == "live")
        #expect(state.screenCaptureColor == OpenClawBrand.ok)
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

    @Test func `settings device identity syncs persisted values`() async {
        let store = TestStore(initialState: SettingsDeviceIdentityFeature.State()) {
            SettingsDeviceIdentityFeature()
        }

        await store.send(.displayNameSynced("Kitchen iPad")) {
            $0.displayName = "Kitchen iPad"
        }
        await store.send(.instanceIdSynced("ios-node-123")) {
            $0.instanceId = "ios-node-123"
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

    @Test func `settings gateway connection syncs status summary`() async {
        let store = TestStore(initialState: SettingsGatewayConnectionFeature.State()) {
            SettingsGatewayConnectionFeature()
        }

        await store.send(.gatewayStatusSynced(
            isAppleReviewDemoModeEnabled: false,
            gatewayStatusConnected: false,
            gatewayDisplayStatusText: "Pairing required",
            gatewayAgentCount: 0,
            gatewayRemoteAddress: nil,
            gatewayServerName: nil))
        {
            $0.gatewayDisplayStatusText = "Pairing required"
        }
        await store.send(.gatewayStatusSynced(
            isAppleReviewDemoModeEnabled: false,
            gatewayStatusConnected: true,
            gatewayDisplayStatusText: "Connected",
            gatewayAgentCount: 2,
            gatewayRemoteAddress: "100.64.1.2:18789",
            gatewayServerName: "openclaw-gateway"))
        {
            $0.gatewayDisplayStatusText = "Connected"
            $0.gatewayStatusConnected = true
            $0.gatewayAgentCount = 2
            $0.gatewayRemoteAddress = "100.64.1.2:18789"
            $0.gatewayServerName = "openclaw-gateway"
        }
        await store.send(.gatewayStatusSynced(
            isAppleReviewDemoModeEnabled: true,
            gatewayStatusConnected: false,
            gatewayDisplayStatusText: "Offline",
            gatewayAgentCount: 3,
            gatewayRemoteAddress: nil,
            gatewayServerName: nil))
        {
            $0.isAppleReviewDemoModeEnabled = true
            $0.gatewayStatusConnected = false
            $0.gatewayDisplayStatusText = "Offline"
            $0.gatewayAgentCount = 3
            $0.gatewayRemoteAddress = nil
            $0.gatewayServerName = nil
        }
    }

    @Test func `settings gateway connection resolves status summary`() {
        #expect(SettingsGatewayConnectionFeature.State().gatewayStatusDetail == "Offline")
        #expect(SettingsGatewayConnectionFeature.State().gatewayStatusValue == "offline")
        #expect(SettingsGatewayConnectionFeature.State().gatewayStatusColor == .secondary)
        #expect(SettingsGatewayConnectionFeature.State().gatewaySummaryDetail == "Offline • 0 agents")
        #expect(SettingsGatewayConnectionFeature.State().gatewayDiagnosticConnected == false)
        #expect(SettingsGatewayConnectionFeature.State().gatewayAddress == "Waiting for gateway")
        #expect(SettingsGatewayConnectionFeature.State().gatewayServer == "OpenClaw Gateway")

        var connectedState = SettingsGatewayConnectionFeature.State()
        connectedState.gatewayStatusConnected = true
        connectedState.gatewayAgentCount = 1
        connectedState.gatewayRemoteAddress = "100.64.1.2:18789"
        connectedState.gatewayServerName = "openclaw-gateway"
        #expect(connectedState.gatewayStatusDetail == "Connected")
        #expect(connectedState.gatewayStatusValue == "online")
        #expect(connectedState.gatewayStatusColor == OpenClawBrand.ok)
        #expect(connectedState.gatewaySummaryDetail == "Connected • 1 agent")
        #expect(connectedState.gatewayDiagnosticConnected)
        #expect(connectedState.gatewayAddress == "100.64.1.2:18789")
        #expect(connectedState.gatewayServer == "openclaw-gateway")

        var demoState = SettingsGatewayConnectionFeature.State()
        demoState.isAppleReviewDemoModeEnabled = true
        demoState.gatewayStatusConnected = true
        demoState.gatewayAgentCount = 3
        #expect(demoState.gatewayStatusDetail == "Apple Review demo mode")
        #expect(demoState.gatewayStatusValue == "demo")
        #expect(demoState.gatewayStatusColor == OpenClawBrand.accent)
        #expect(demoState.gatewaySummaryDetail == "Apple Review demo mode • 3 agents")
        #expect(demoState.gatewayDiagnosticConnected)
    }

    @Test func `settings gateway connection formats discovered gateway detail lines`() {
        #expect(SettingsGatewayConnectionFeature.State.discoveredGatewayDetailLines(
            lanHost: nil,
            tailnetDNS: nil,
            gatewayPort: nil,
            canvasPort: nil,
            debugID: "gateway-debug") == ["gateway-debug"])

        #expect(SettingsGatewayConnectionFeature.State.discoveredGatewayDetailLines(
            lanHost: "192.168.1.20",
            tailnetDNS: "openclaw-gateway.tailnet.ts.net",
            gatewayPort: 18789,
            canvasPort: 18790,
            debugID: "gateway-debug") == [
                "LAN: 192.168.1.20",
                "Tailnet: openclaw-gateway.tailnet.ts.net",
                "Ports: gateway 18789 / canvas 18790",
            ])

        #expect(SettingsGatewayConnectionFeature.State.discoveredGatewayDetailLines(
            lanHost: nil,
            tailnetDNS: nil,
            gatewayPort: 18789,
            canvasPort: nil,
            debugID: "gateway-debug") == ["Ports: gateway 18789 / canvas -"])
    }

    @Test func `settings gateway setup status records messages`() async {
        let store = TestStore(initialState: SettingsGatewaySetupStatusFeature.State()) {
            SettingsGatewaySetupStatusFeature()
        }

        await store.send(.statusChanged("Failed: host required")) {
            $0.statusText = "Failed: host required"
        }
    }

    @Test func `settings gateway setup status records setup connection start`() async {
        let store = TestStore(initialState: SettingsGatewaySetupStatusFeature.State()) {
            SettingsGatewaySetupStatusFeature()
        }

        await store.send(.setupConnectionStarted) {
            $0.statusText = "Setup code applied. Connecting..."
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

    @Test func `settings gateway setup status syncs gateway context`() async {
        let store = TestStore(initialState: SettingsGatewaySetupStatusFeature.State()) {
            SettingsGatewaySetupStatusFeature()
        }

        await store.send(.gatewayStatusSynced(
            problemMessage: "Pairing required",
            gatewayStatusText: "Offline"))
        {
            $0.gatewayProblemMessage = "Pairing required"
            $0.gatewayStatusText = "Offline"
        }
    }

    @Test func `settings gateway setup status resolves display line`() {
        #expect(SettingsGatewaySetupStatusFeature.setupStatusLine(
            problemMessage: "Reset required",
            setupStatusText: "Setup code applied. Connecting...",
            gatewayStatusText: "Connected") == "Reset required")
        #expect(SettingsGatewaySetupStatusFeature.setupStatusLine(
            problemMessage: nil,
            setupStatusText: "Setup code applied. Connecting...",
            gatewayStatusText: "Connected") == "Connected")
        #expect(SettingsGatewaySetupStatusFeature.setupStatusLine(
            problemMessage: nil,
            setupStatusText: nil,
            gatewayStatusText: "Pairing required") ==
            "Pairing required. Run /pair approve in your OpenClaw chat, then connect again.")
        #expect(SettingsGatewaySetupStatusFeature.setupStatusLine(
            problemMessage: nil,
            setupStatusText: "Request timed out",
            gatewayStatusText: "Offline") ==
            "Connection timed out. Make sure Tailscale is connected, then try again.")
        #expect(SettingsGatewaySetupStatusFeature.setupStatusLine(
            problemMessage: nil,
            setupStatusText: nil,
            gatewayStatusText: "Offline") == nil)
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
            $0.setupLinkStatusText =
                "Setup link loaded for gateway.example.com:443 (TLS). Tap Connect to apply."
            $0.stagedGatewaySetupLink = link
        }

        await store.send(.setupLinkStatusHandled) {
            $0.setupLinkStatusText = nil
        }
    }

    @Test func `settings gateway setup link staging clears setup code`() async {
        let link = GatewayConnectDeepLink(
            host: "gateway.example.com",
            port: 443,
            tls: false,
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
            $0.setupLinkStatusText =
                "Setup link loaded for gateway.example.com:443 (plain). Tap Connect to apply."
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

    @Test func `settings gateway setup link resolves apply availability`() {
        let link = GatewayConnectDeepLink(
            host: "gateway.example.com",
            port: 443,
            tls: true,
            bootstrapToken: nil,
            token: nil,
            password: nil)
        var state = SettingsGatewaySetupLinkFeature.State()

        #expect(!state.canApplyGatewaySetup)
        state.setupCode = "  setup-code  "
        #expect(state.canApplyGatewaySetup)
        state.setupCode = "   "
        #expect(!state.canApplyGatewaySetup)
        state.stagedGatewaySetupLink = link
        #expect(state.canApplyGatewaySetup)
    }

    @Test func `settings gateway setup link apply classifies raw setup input`() async {
        let link = GatewayConnectDeepLink(
            host: "gateway.example.com",
            port: 443,
            tls: true,
            bootstrapToken: nil,
            token: nil,
            password: nil)
        var initialState = SettingsGatewaySetupLinkFeature.State()
        initialState.setupCode = "  wss://gateway.example.com:443  "
        let store = TestStore(initialState: initialState) {
            SettingsGatewaySetupLinkFeature()
        }

        await store.send(.applyRequested) {
            $0.applyResult = .gatewayLink(link)
        }

        await store.send(.applyResultHandled) {
            $0.applyResult = nil
        }
    }

    @Test func `settings gateway setup link apply consumes staged link`() async {
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

        await store.send(.applyRequested) {
            $0.applyResult = .gatewayLink(link)
            $0.stagedGatewaySetupLink = nil
        }
    }

    @Test func `settings gateway setup link apply reports invalid inputs`() async {
        let store = TestStore(initialState: SettingsGatewaySetupLinkFeature.State()) {
            SettingsGatewaySetupLinkFeature()
        }

        await store.send(.applyRequested) {
            $0.applyResult = .failure("Paste a setup code to continue.")
        }

        await store.send(.applyResultHandled) {
            $0.applyResult = nil
        }

        await store.send(.setupCodeChanged("not a setup code")) {
            $0.setupCode = "not a setup code"
        }

        await store.send(.applyRequested) {
            $0.applyResult = .failure("Setup code not recognized or uses an insecure ws:// gateway URL.")
        }
    }

    @Test func `settings gateway setup link apply handles apple review demo code`() async {
        var initialState = SettingsGatewaySetupLinkFeature.State()
        initialState.setupCode = "  APPLE-REVIEW-DEMO  "
        let store = TestStore(initialState: initialState) {
            SettingsGatewaySetupLinkFeature()
        }

        await store.send(.applyRequested) {
            $0.applyResult = .appleReviewDemo(statusText: "Apple Review demo mode enabled.")
            $0.setupCode = ""
        }
    }

    @Test func `settings gateway setup link classifies scanned apple review setup codes`() async {
        let link = GatewayConnectDeepLink(
            host: "gateway.example.com",
            port: 443,
            tls: true,
            bootstrapToken: nil,
            token: nil,
            password: nil)
        var initialState = SettingsGatewaySetupLinkFeature.State()
        initialState.setupCode = "stale code"
        initialState.stagedGatewaySetupLink = link
        let store = TestStore(initialState: initialState) {
            SettingsGatewaySetupLinkFeature()
        }

        await store.send(.scannedSetupCodeReceived("not a demo code"))

        await store.send(.scannedSetupCodeReceived("  APPLE-REVIEW-DEMO  ")) {
            $0.applyResult = .appleReviewDemo(statusText: "Apple Review demo mode enabled.")
            $0.setupCode = ""
            $0.stagedGatewaySetupLink = nil
        }

        await store.send(.applyResultHandled) {
            $0.applyResult = nil
        }
    }

    @Test func `settings gateway setup link classifies scanned gateway links`() async {
        let scannedLink = GatewayConnectDeepLink(
            host: "gateway.example.com",
            port: 443,
            tls: true,
            bootstrapToken: nil,
            token: nil,
            password: nil)
        let stagedLink = GatewayConnectDeepLink(
            host: "staged.example.com",
            port: 18789,
            tls: false,
            bootstrapToken: nil,
            token: nil,
            password: nil)
        var initialState = SettingsGatewaySetupLinkFeature.State()
        initialState.setupCode = "stale code"
        initialState.stagedGatewaySetupLink = stagedLink
        let store = TestStore(initialState: initialState) {
            SettingsGatewaySetupLinkFeature()
        }

        await store.send(.scannedGatewayLinkReceived(scannedLink)) {
            $0.applyResult = .gatewayLink(scannedLink)
            $0.scannedGatewayLinkStatusText = "QR loaded. Connecting to gateway.example.com:443..."
            $0.setupCode = ""
            $0.stagedGatewaySetupLink = nil
        }

        await store.send(.applyResultHandled) {
            $0.applyResult = nil
        }

        await store.send(.scannedGatewayLinkStatusHandled) {
            $0.scannedGatewayLinkStatusText = nil
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

    @Test func `settings gateway credentials derive setup auth from link`() async {
        let link = GatewayConnectDeepLink(
            host: "gateway.example.com",
            port: 443,
            tls: true,
            bootstrapToken: "bootstrap-6",
            token: "token-6",
            password: "password-6")
        let setupAuth = GatewayConnectionController.ManualAuthOverride.setupAuth(from: link)
        let store = TestStore(initialState: SettingsGatewayCredentialsFeature.State()) {
            SettingsGatewayCredentialsFeature()
        }

        await store.send(.setupLinkApplied(link)) {
            $0.gatewayToken = "token-6"
            $0.gatewayPassword = "password-6"
            $0.pendingManualAuthOverride = GatewayConnectionController.ManualAuthOverride.explicit(
                token: "token-6",
                bootstrapToken: "bootstrap-6",
                password: "password-6")
            $0.setupAuthPersistenceRequest = setupAuth
        }

        await store.send(.setupAuthPersistenceRequestHandled) {
            $0.setupAuthPersistenceRequest = nil
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

    @Test func `settings location applies off mode without permission client`() async {
        let probe = SettingsLocationPermissionProbe(granted: false)
        var initialState = SettingsLocationFeature.State()
        initialState.previousLocationModeRaw = OpenClawLocationMode.whileUsing.rawValue
        let store = TestStore(initialState: initialState) {
            SettingsLocationFeature(permissionClient: probe.client)
        }
        let request = SettingsLocationFeature.LocationModeRequest(
            mode: .off,
            previousRawValue: OpenClawLocationMode.whileUsing.rawValue,
            rawValue: OpenClawLocationMode.off.rawValue)

        await store.send(.locationModeApplyRequested(request)) {
            $0.locationModeApplyResult = .applied(rawValue: OpenClawLocationMode.off.rawValue)
            $0.locationModeRaw = OpenClawLocationMode.off.rawValue
            $0.previousLocationModeRaw = OpenClawLocationMode.off.rawValue
        }
        await store.send(.locationModeApplyResultHandled) {
            $0.locationModeApplyResult = nil
        }

        #expect(probe.requestCount == 0)
    }

    @Test func `settings location requests permissions through client`() async {
        let probe = SettingsLocationPermissionProbe(granted: true)
        var initialState = SettingsLocationFeature.State()
        initialState.locationModeApplyResult = .denied(previousRawValue: OpenClawLocationMode.off.rawValue)
        initialState.locationModeRequest = SettingsLocationFeature.LocationModeRequest(
            mode: .always,
            previousRawValue: OpenClawLocationMode.off.rawValue,
            rawValue: OpenClawLocationMode.always.rawValue)
        initialState.statusText = "Location permission was not granted."
        let store = TestStore(initialState: initialState) {
            SettingsLocationFeature(permissionClient: probe.client)
        }
        let request = SettingsLocationFeature.LocationModeRequest(
            mode: .always,
            previousRawValue: OpenClawLocationMode.off.rawValue,
            rawValue: OpenClawLocationMode.always.rawValue)

        await store.send(.locationModeApplyRequested(request)) {
            $0.isChangingLocationMode = true
            $0.locationModeApplyResult = nil
            $0.locationModeRequest = nil
            $0.statusText = nil
        }
        await store.receive(.locationModeApplyFinished(.applied(rawValue: OpenClawLocationMode.always.rawValue))) {
            $0.isChangingLocationMode = false
            $0.locationModeApplyResult = .applied(rawValue: OpenClawLocationMode.always.rawValue)
            $0.locationModeRaw = OpenClawLocationMode.always.rawValue
            $0.previousLocationModeRaw = OpenClawLocationMode.always.rawValue
        }
        await store.send(.locationModeApplyResultHandled) {
            $0.locationModeApplyResult = nil
        }
        await store.finish()

        #expect(probe.requestCount == 1)
        #expect(probe.requestedModes == [.always])
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

    @Test func `settings location creates mode change requests`() async {
        let store = TestStore(initialState: SettingsLocationFeature.State()) {
            SettingsLocationFeature()
        }

        await store.send(.locationModeChangeRequested(OpenClawLocationMode.always.rawValue)) {
            $0.locationModeRaw = OpenClawLocationMode.always.rawValue
            $0.locationModeRequest = SettingsLocationFeature.LocationModeRequest(
                mode: .always,
                previousRawValue: OpenClawLocationMode.off.rawValue,
                rawValue: OpenClawLocationMode.always.rawValue)
        }
    }

    @Test func `settings location ignores duplicate in flight and invalid mode change requests`() async {
        var duplicateState = SettingsLocationFeature.State()
        duplicateState.locationModeRaw = OpenClawLocationMode.always.rawValue
        duplicateState.previousLocationModeRaw = OpenClawLocationMode.always.rawValue
        let duplicateStore = TestStore(initialState: duplicateState) {
            SettingsLocationFeature()
        }

        await duplicateStore.send(.locationModeChangeRequested(OpenClawLocationMode.always.rawValue))

        var changingState = SettingsLocationFeature.State()
        changingState.isChangingLocationMode = true
        let changingStore = TestStore(initialState: changingState) {
            SettingsLocationFeature()
        }

        await changingStore.send(.locationModeChangeRequested(OpenClawLocationMode.whileUsing.rawValue)) {
            $0.locationModeRaw = OpenClawLocationMode.whileUsing.rawValue
        }

        let invalidStore = TestStore(initialState: SettingsLocationFeature.State()) {
            SettingsLocationFeature()
        }

        await invalidStore.send(.locationModeChangeRequested("invalid-location-mode")) {
            $0.locationModeRaw = "invalid-location-mode"
        }
    }

    @Test func `settings location summarizes privacy detail`() {
        var state = SettingsLocationFeature.State()

        #expect(state.locationLabel == "Off")
        #expect(state.privacyDetail == "Location off")
        #expect(state.locationColor == .secondary)

        state.locationModeRaw = OpenClawLocationMode.whileUsing.rawValue
        #expect(state.locationLabel == "While Using")
        #expect(state.privacyDetail == "Location While Using")
        #expect(state.locationColor == OpenClawBrand.accent)

        state.locationModeRaw = OpenClawLocationMode.always.rawValue
        #expect(state.locationLabel == "Always")
        #expect(state.privacyDetail == "Location Always")
        #expect(state.locationColor == OpenClawBrand.accent)

        state.locationModeRaw = "unexpected"
        #expect(state.locationLabel == "Off")
        #expect(state.privacyDetail == "Location off")
        #expect(state.locationColor == .secondary)
    }

    @Test func `settings location records permission denial`() async {
        let probe = SettingsLocationPermissionProbe(granted: false)
        var initialState = SettingsLocationFeature.State()
        initialState.locationModeRaw = OpenClawLocationMode.always.rawValue
        initialState.previousLocationModeRaw = OpenClawLocationMode.whileUsing.rawValue
        let store = TestStore(initialState: initialState) {
            SettingsLocationFeature(permissionClient: probe.client)
        }
        let request = SettingsLocationFeature.LocationModeRequest(
            mode: .always,
            previousRawValue: OpenClawLocationMode.off.rawValue,
            rawValue: OpenClawLocationMode.always.rawValue)

        await store.send(.locationModeApplyRequested(request)) {
            $0.isChangingLocationMode = true
        }
        await store.receive(.locationModeApplyFinished(.denied(previousRawValue: OpenClawLocationMode.off.rawValue))) {
            $0.isChangingLocationMode = false
            $0.locationModeApplyResult = .denied(previousRawValue: OpenClawLocationMode.off.rawValue)
            $0.locationModeRaw = OpenClawLocationMode.off.rawValue
            $0.previousLocationModeRaw = OpenClawLocationMode.off.rawValue
            $0.statusText = "Location permission was not granted."
        }
        await store.finish()

        #expect(probe.requestCount == 1)
        #expect(probe.requestedModes == [.always])
    }

    @Test func `settings notifications record permission status`() async {
        let store = TestStore(initialState: SettingsNotificationFeature.State()) {
            SettingsNotificationFeature()
        }

        await store.send(.statusChanged(.notSet)) {
            $0.status = .notSet
        }
    }

    @Test func `settings notifications summarize permission status`() {
        var state = SettingsNotificationFeature.State()

        #expect(state.statusText == "Checking")
        #expect(state.actionText == "Checking")
        #expect(state.statusDetail == "Checking iOS notification permission.")
        #expect(state.statusColor == .secondary)
        #expect(state.needsAttention == false)

        state.status = .allowed
        #expect(state.statusText == "Enabled")
        #expect(state.actionText == "Manage in iOS Settings")
        #expect(state.statusDetail == "OpenClaw can show approval prompts and event alerts when the app is not active.")
        #expect(state.statusColor == OpenClawBrand.ok)
        #expect(state.needsAttention == false)

        state.status = .notAllowed
        #expect(state.statusText == "Denied")
        #expect(state.actionText == "Open iOS Settings")
        #expect(state.statusDetail == "Notifications have been denied. Enable them in iOS Settings.")
        #expect(state.statusColor == OpenClawBrand.warn)
        #expect(state.needsAttention == true)

        state.status = .notSet
        #expect(state.statusText == "Not Enabled")
        #expect(state.actionText == "Enable Notifications")
        #expect(state.statusDetail ==
            "Enable notifications to receive approval prompts and event alerts outside the app.")
        #expect(state.statusColor == .secondary)
        #expect(state.needsAttention == true)

        state.status = .unknown
        #expect(state.statusText == "Unknown")
        #expect(state.actionText == "Open iOS Settings")
        #expect(state.statusDetail == "OpenClaw cannot determine the current notification permission state.")
        #expect(state.statusColor == OpenClawBrand.warn)
        #expect(state.needsAttention == true)
    }

    @Test func `settings notifications refresh status through client`() async {
        let probe = SettingsNotificationAuthorizationProbe(
            result: SettingsNotificationAuthorizationResult(granted: false, status: .notAllowed),
            status: .allowed)
        let store = TestStore(initialState: SettingsNotificationFeature.State()) {
            SettingsNotificationFeature(authorizationClient: probe.client)
        }

        await store.send(.statusRefreshRequested)
        await store.receive(.statusRefreshFinished(.allowed)) {
            $0.status = .allowed
            $0.statusRefreshResult = .allowed
        }
        await store.send(.statusRefreshResultHandled) {
            $0.statusRefreshResult = nil
        }
        await store.finish()

        #expect(probe.fetchStatusCount == 1)
        #expect(probe.requestCount == 0)
    }

    @Test func `settings notifications request authorization through client`() async {
        let result = SettingsNotificationAuthorizationResult(granted: true, status: .allowed)
        let probe = SettingsNotificationAuthorizationProbe(result: result)
        var initialState = SettingsNotificationFeature.State()
        initialState.actionRequest = .requestAuthorization
        initialState.authorizationRequestResult = SettingsNotificationAuthorizationResult(
            granted: false,
            status: .notAllowed)
        let store = TestStore(initialState: initialState) {
            SettingsNotificationFeature(authorizationClient: probe.client)
        }

        await store.send(.authorizationRequestRequested) {
            $0.actionRequest = nil
            $0.authorizationRequestResult = nil
            $0.isRequestingAuthorization = true
        }
        await store.receive(.authorizationRequestFinished(result)) {
            $0.authorizationRequestResult = result
            $0.isRequestingAuthorization = false
            $0.status = .allowed
        }
        await store.send(.authorizationRequestResultHandled) {
            $0.authorizationRequestResult = nil
        }
        await store.finish()

        #expect(probe.requestCount == 1)
    }

    @Test func `settings notifications ignore duplicate authorization requests`() async {
        let probe = SettingsNotificationAuthorizationProbe(result: SettingsNotificationAuthorizationResult(
            granted: true,
            status: .allowed))
        var initialState = SettingsNotificationFeature.State()
        initialState.status = .notSet
        initialState.isRequestingAuthorization = true
        let store = TestStore(initialState: initialState) {
            SettingsNotificationFeature(authorizationClient: probe.client)
        }

        await store.send(.authorizationRequestRequested)
        await store.finish()

        #expect(probe.requestCount == 0)
    }

    @Test func `settings notifications action button opens ios settings for managed statuses`() async {
        var initialState = SettingsNotificationFeature.State()
        initialState.status = .allowed
        let store = TestStore(initialState: initialState) {
            SettingsNotificationFeature()
        }

        await store.send(.actionButtonTapped) {
            $0.actionRequest = .openSettings
        }
        await store.send(.actionRequestHandled) {
            $0.actionRequest = nil
        }
    }

    @Test func `settings notifications action button requests relay disclosure when hosted relay is active`() async {
        var initialState = SettingsNotificationFeature.State()
        initialState.status = .notSet
        initialState.usesOpenClawHostedRelay = true
        let store = TestStore(initialState: initialState) {
            SettingsNotificationFeature()
        }

        await store.send(.actionButtonTapped) {
            $0.actionRequest = .showRelayDisclosure
        }
    }

    @Test func `settings notifications action button requests authorization without hosted relay`() async {
        var initialState = SettingsNotificationFeature.State()
        initialState.status = .notSet
        let store = TestStore(initialState: initialState) {
            SettingsNotificationFeature()
        }

        await store.send(.actionButtonTapped) {
            $0.actionRequest = .requestAuthorization
        }
    }

    @Test func `settings notifications action button ignores checking and in flight authorization`() async {
        let checkingStore = TestStore(initialState: SettingsNotificationFeature.State()) {
            SettingsNotificationFeature()
        }

        await checkingStore.send(.actionButtonTapped)

        var requestingState = SettingsNotificationFeature.State()
        requestingState.status = .notSet
        requestingState.isRequestingAuthorization = true
        let requestingStore = TestStore(initialState: requestingState) {
            SettingsNotificationFeature()
        }

        await requestingStore.send(.actionButtonTapped)
    }

    @Test func `settings notifications sync relay config`() async {
        let store = TestStore(initialState: SettingsNotificationFeature.State()) {
            SettingsNotificationFeature()
        }

        await store.send(.relayConfigSynced(
            usesOpenClawHostedRelay: true,
            hostedRelayHost: "relay.example.com"))
        {
            $0.usesOpenClawHostedRelay = true
            $0.hostedRelayHost = "relay.example.com"
        }
        await store.send(.relayConfigSynced(
            usesOpenClawHostedRelay: false,
            hostedRelayHost: nil))
        {
            $0.usesOpenClawHostedRelay = false
            $0.hostedRelayHost = "ios-push-relay.openclaw.ai"
        }
    }

    @Test func `settings notifications summarize relay config`() {
        var state = SettingsNotificationFeature.State()

        #expect(state.relayDetail == "This build is not configured to use OpenClaw's hosted push relay.")
        #expect(state.relayDisclosureMessage ==
            "Enabling this sends delivery data through OpenClaw's hosted push relay.")

        state.usesOpenClawHostedRelay = true
        state.hostedRelayHost = "ios-push-relay-sandbox.openclaw.ai"

        #expect(state.relayDetail ==
            """
            This build uses OpenClaw's hosted push relay at ios-push-relay-sandbox.openclaw.ai for notification \
            delivery data.
            """)
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

    @Test func `settings manual gateway port reports resolution results`() async {
        var initialState = SettingsManualGatewayPortFeature.State()
        initialState.manualGatewayPort = 65_536
        initialState.manualGatewayPortText = "65536"
        let store = TestStore(initialState: initialState) {
            SettingsManualGatewayPortFeature()
        }

        await store.send(.manualGatewayPortResolutionRequested(host: "gateway.example.com", useTLS: true)) {
            $0.manualGatewayPortResolutionResult = .failure("Failed: invalid port")
        }

        await store.send(.manualGatewayPortResolutionResultHandled) {
            $0.manualGatewayPortResolutionResult = nil
        }

        await store.send(.manualGatewayPortSynced(0)) {
            $0.manualGatewayPort = 0
            $0.manualGatewayPortText = ""
        }

        await store.send(.manualGatewayPortResolutionRequested(host: "device.sample.ts.net", useTLS: true)) {
            $0.manualGatewayPortResolutionResult = .resolved
        }
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

    @Test func `settings manual gateway endpoint validates manual connection requests`() async {
        let store = TestStore(initialState: SettingsManualGatewayEndpointFeature.State()) {
            SettingsManualGatewayEndpointFeature()
        }

        await store.send(.manualConnectionRequested(port: 18789, isPortValid: true)) {
            $0.manualConnectionResult = .failure("Failed: host required")
        }

        await store.send(.manualConnectionResultHandled) {
            $0.manualConnectionResult = nil
        }

        await store.send(.manualGatewayHostChanged("  gateway.example.com  ")) {
            $0.manualGatewayHost = "  gateway.example.com  "
        }

        await store.send(.manualConnectionRequested(port: 18789, isPortValid: false)) {
            $0.manualConnectionResult = .failure("Failed: invalid port")
        }

        await store.send(.manualConnectionResultHandled) {
            $0.manualConnectionResult = nil
        }

        await store.send(.manualGatewayTLSChanged(false)) {
            $0.manualGatewayTLS = false
        }

        await store.send(.manualConnectionRequested(port: 18789, isPortValid: true)) {
            $0.manualConnectionResult = .request(SettingsManualGatewayEndpointFeature.ManualConnectionRequest(
                host: "gateway.example.com",
                port: 18789,
                useTLS: false))
        }
    }

    @Test func `settings manual gateway endpoint resolves preflight decisions`() async {
        let store = TestStore(initialState: SettingsManualGatewayEndpointFeature.State()) {
            SettingsManualGatewayEndpointFeature()
        }

        await store.send(.preflightRequested(host: "   ", hasTailnetIPv4: true)) {
            $0.preflightResult = .blocked(statusText: nil)
        }

        await store.send(.preflightResultHandled) {
            $0.preflightResult = nil
        }

        await store.send(.preflightRequested(host: "device.sample.ts.net", hasTailnetIPv4: false)) {
            $0.preflightResult = .blocked(
                statusText: "Tailscale is off on this device. Turn it on, then try again.")
        }

        await store.send(.preflightResultHandled) {
            $0.preflightResult = nil
        }

        await store.send(.preflightRequested(host: " gateway.example.com ", hasTailnetIPv4: false)) {
            $0.preflightResult = .requestLocalNetworkAccess(reason: "settings_preflight")
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

    @Test func `settings manual gateway endpoint resolves tailnet warnings`() {
        var state = SettingsManualGatewayEndpointFeature.State()

        state.manualGatewayHost = "gateway.example.com"
        #expect(state.tailnetWarningText(hasTailnetIPv4: false) == nil)

        state.manualGatewayHost = "device.sample.ts.net"
        #expect(state.tailnetWarningText(hasTailnetIPv4: false) ==
            "This gateway is on your tailnet. Turn on Tailscale on this device, then tap Connect.")
        #expect(state.tailnetWarningText(hasTailnetIPv4: true) == nil)

        state.manualGatewayHost = "100.64.1.2"
        #expect(SettingsManualGatewayEndpointFeature.State.isTailnetHostOrIP(state.manualGatewayHost))
        #expect(state.tailnetWarningText(hasTailnetIPv4: false) != nil)

        state.manualGatewayHost = "192.168.1.10"
        #expect(!SettingsManualGatewayEndpointFeature.State.isTailnetHostOrIP(state.manualGatewayHost))
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

    @Test func `settings onboarding state syncs persisted values`() async {
        let store = TestStore(initialState: SettingsOnboardingStateFeature.State()) {
            SettingsOnboardingStateFeature()
        }

        await store.send(.onboardingStateSynced(
            hasConnectedOnce: true,
            onboardingComplete: true,
            onboardingRequestID: 4))
        {
            $0.hasConnectedOnce = true
            $0.onboardingComplete = true
            $0.onboardingRequestID = 4
        }
    }

    @Test func `settings onboarding state resets completion flags`() async {
        var initialState = SettingsOnboardingStateFeature.State()
        initialState.hasConnectedOnce = true
        initialState.onboardingComplete = true
        initialState.onboardingRequestID = 4
        let store = TestStore(initialState: initialState) {
            SettingsOnboardingStateFeature()
        }

        await store.send(.completionStateReset) {
            $0.hasConnectedOnce = false
            $0.onboardingComplete = false
        }
    }

    @Test func `settings onboarding state records request id changes`() async {
        let store = TestStore(initialState: SettingsOnboardingStateFeature.State()) {
            SettingsOnboardingStateFeature()
        }

        await store.send(.onboardingRequestIDChanged(5)) {
            $0.onboardingRequestID = 5
        }
    }

    @Test func `settings onboarding state advances request id`() async {
        var initialState = SettingsOnboardingStateFeature.State()
        initialState.onboardingRequestID = 4
        let store = TestStore(initialState: initialState) {
            SettingsOnboardingStateFeature()
        }

        await store.send(.onboardingRequestAdvanced) {
            $0.onboardingRequestID = 5
        }
    }

    @Test func `settings device capabilities sync persisted values`() async {
        let store = TestStore(initialState: SettingsDeviceCapabilityFeature.State()) {
            SettingsDeviceCapabilityFeature()
        }

        await store.send(.capabilitiesSynced(
            cameraEnabled: false,
            preventSleep: true,
            locationModeRaw: OpenClawLocationMode.always.rawValue))
        {
            $0.cameraEnabled = false
            $0.preventSleep = true
            $0.locationModeRaw = OpenClawLocationMode.always.rawValue
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
        await store.send(.locationModeChanged(OpenClawLocationMode.always.rawValue)) {
            $0.locationModeRaw = OpenClawLocationMode.always.rawValue
        }
    }

    @Test func `settings device capabilities count enabled permissions`() async {
        var state = SettingsDeviceCapabilityFeature.State()
        #expect(state.enabledCount == 2)
        #expect(state.permissionsDetail == "2 enabled")

        state.locationModeRaw = OpenClawLocationMode.always.rawValue
        #expect(state.enabledCount == 3)
        #expect(state.permissionsDetail == "3 enabled")

        state.cameraEnabled = false
        #expect(state.enabledCount == 2)
        #expect(state.permissionsDetail == "2 enabled")

        state.preventSleep = false
        #expect(state.enabledCount == 1)
        #expect(state.permissionsDetail == "1 enabled")
    }

    @Test func `settings voice controls sync persisted values`() async {
        let store = TestStore(initialState: SettingsVoiceControlFeature.State()) {
            SettingsVoiceControlFeature()
        }

        await store.send(.controlsSynced(
            talkEnabled: true,
            voiceWakeEnabled: true,
            voiceWakeStatusText: "Listening"))
        {
            $0.talkEnabled = true
            $0.voiceWakeEnabled = true
            $0.voiceWakeStatusText = "Listening"
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

    @Test func `settings voice controls resolve requested talk changes`() async {
        let store = TestStore(initialState: SettingsVoiceControlFeature.State()) {
            SettingsVoiceControlFeature()
        }

        await store.send(.talkEnabledChangeRequested(
            enabled: true,
            isAppleReviewDemoModeEnabled: false))
        {
            $0.talkEnabled = true
        }

        await store.send(.talkEnabledChangeRequested(
            enabled: true,
            isAppleReviewDemoModeEnabled: true))
        {
            $0.talkEnabled = false
        }
    }

    @Test func `settings voice controls summarize active modes`() {
        var state = SettingsVoiceControlFeature.State()
        #expect(state.detailText == "Off")
        #expect(state.detailColor == .secondary)
        #expect(state.voiceWakeValue == "off")
        #expect(state.voiceWakeColor == .secondary)

        state.voiceWakeEnabled = true
        #expect(state.detailText == "Wake on")
        #expect(state.detailColor == OpenClawBrand.accent)
        #expect(state.voiceWakeValue == "on")
        #expect(state.voiceWakeColor == OpenClawBrand.ok)

        state.talkEnabled = true
        #expect(state.detailText == "Talk + Wake")
        #expect(state.detailColor == OpenClawBrand.accent)

        state.voiceWakeEnabled = false
        #expect(state.detailText == "Talk on")
        #expect(state.detailColor == OpenClawBrand.accent)
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

    @Test func `settings talk preferences sync gateway config status`() async {
        let store = TestStore(initialState: SettingsTalkPreferencesFeature.State()) {
            SettingsTalkPreferencesFeature()
        }

        await store.send(.gatewayTalkConfigSynced(
            configLoaded: true,
            apiKeyConfigured: false,
            usesRealtime: true))
        {
            $0.gatewayTalkConfigLoaded = true
            $0.gatewayTalkApiKeyConfigured = false
            $0.gatewayTalkUsesRealtime = true
        }
        await store.send(.gatewayTalkConfigSynced(
            configLoaded: true,
            apiKeyConfigured: true,
            usesRealtime: false))
        {
            $0.gatewayTalkConfigLoaded = true
            $0.gatewayTalkApiKeyConfigured = true
            $0.gatewayTalkUsesRealtime = false
        }
        await store.send(.gatewayTalkDisplayContextSynced(
            isAppleReviewDemoModeEnabled: true,
            transportLabel: "Gateway Relay"))
        {
            $0.isAppleReviewDemoModeEnabled = true
            $0.gatewayTalkTransportLabel = "Gateway Relay"
        }
    }

    @Test func `settings talk preferences sync gateway runtime details`() async {
        let store = TestStore(initialState: SettingsTalkPreferencesFeature.State()) {
            SettingsTalkPreferencesFeature()
        }

        await store.send(.gatewayTalkRuntimeSynced(
            activeModeTitle: "Ready",
            activeModeSubtitle: "Listening starts from this phone",
            lastIssueText: "Fallback active"))
        {
            $0.gatewayTalkActiveModeTitle = "Ready"
            $0.gatewayTalkActiveModeSubtitle = "Listening starts from this phone"
            $0.gatewayTalkLastIssueText = "Fallback active"
        }
    }

    @Test func `settings talk preferences summarize api key status`() {
        var state = SettingsTalkPreferencesFeature.State()

        #expect(state.talkApiKeyStatus == "Not loaded")
        state.gatewayTalkConfigLoaded = true
        #expect(state.talkApiKeyStatus == "Not configured")
        state.gatewayTalkApiKeyConfigured = true
        #expect(state.talkApiKeyStatus == "Configured")
        #expect(SettingsTalkPreferencesFeature.State.talkApiKeyStatus(
            configLoaded: true,
            apiKeyConfigured: false) == "Not configured")
    }

    @Test func `settings talk preferences summarize gateway config status`() {
        var state = SettingsTalkPreferencesFeature.State()

        #expect(state.gatewayDiagnosticTalkConfigLoaded == false)
        #expect(state.gatewayTalkConfigDetail == "Not loaded")
        #expect(state.gatewayTalkConfigValue == "missing")
        #expect(state.gatewayTalkConfigColor == .secondary)

        state.gatewayTalkConfigLoaded = true
        state.gatewayTalkTransportLabel = "Gateway Relay"
        #expect(state.gatewayDiagnosticTalkConfigLoaded)
        #expect(state.gatewayTalkConfigDetail == "Gateway Relay")
        #expect(state.gatewayTalkConfigValue == "loaded")
        #expect(state.gatewayTalkConfigColor == OpenClawBrand.ok)

        state.isAppleReviewDemoModeEnabled = true
        state.gatewayTalkConfigLoaded = false
        #expect(state.gatewayDiagnosticTalkConfigLoaded)
        #expect(state.gatewayTalkConfigDetail == "Demo mode only")
        #expect(state.gatewayTalkConfigValue == "demo")
        #expect(state.gatewayTalkConfigColor == .secondary)
    }

    @Test func `settings talk preferences summarize gateway runtime details`() {
        var state = SettingsTalkPreferencesFeature.State()

        #expect(state.gatewayTalkActiveVoiceDetail == "Not active")
        #expect(state.gatewayTalkLastIssueDetail == nil)

        state.gatewayTalkActiveModeTitle = " Ready "
        #expect(state.gatewayTalkActiveVoiceDetail == "Ready")

        state.gatewayTalkActiveModeSubtitle = " Listening starts from this phone "
        #expect(state.gatewayTalkActiveVoiceDetail == "Ready • Listening starts from this phone")

        state.gatewayTalkActiveModeTitle = "   "
        #expect(state.gatewayTalkActiveVoiceDetail == "Not active")

        state.gatewayTalkLastIssueText = "  Fallback active  "
        #expect(state.gatewayTalkLastIssueDetail == "Fallback active")
        state.gatewayTalkLastIssueText = "  "
        #expect(state.gatewayTalkLastIssueDetail == nil)
    }

    @Test func `settings talk preferences show realtime picker for local or gateway realtime`() {
        var state = SettingsTalkPreferencesFeature.State()

        #expect(state.shouldShowRealtimeVoicePicker == false)
        state.gatewayTalkUsesRealtime = true
        #expect(state.shouldShowRealtimeVoicePicker == true)

        state.gatewayTalkUsesRealtime = false
        state.providerSelectionRaw = TalkModeProviderSelection.openAIRealtime.rawValue
        #expect(state.shouldShowRealtimeVoicePicker == true)
        #expect(SettingsTalkPreferencesFeature.State.shouldShowRealtimeVoicePicker(
            providerSelectionRaw: TalkModeProviderSelection.openAIRealtime.rawValue,
            gatewayTalkUsesRealtime: false) == true)
    }
}

private final class SettingsNotificationAuthorizationProbe: @unchecked Sendable {
    var fetchStatusCount = 0
    var requestCount = 0
    var result: SettingsNotificationAuthorizationResult
    var status: SettingsNotificationStatus

    init(
        result: SettingsNotificationAuthorizationResult,
        status: SettingsNotificationStatus = .unknown)
    {
        self.result = result
        self.status = status
    }

    var client: SettingsNotificationAuthorizationClient {
        SettingsNotificationAuthorizationClient(
            fetchStatus: {
                self.fetchStatusCount += 1
                return self.status
            },
            requestAuthorization: {
                self.requestCount += 1
                return self.result
            })
    }
}

private final class SettingsLocationPermissionProbe: @unchecked Sendable {
    var requestCount = 0
    var requestedModes: [OpenClawLocationMode] = []
    var granted: Bool

    init(granted: Bool) {
        self.granted = granted
    }

    var client: SettingsLocationPermissionClient {
        SettingsLocationPermissionClient(
            requestPermission: { mode in
                self.requestCount += 1
                self.requestedModes.append(mode)
                return self.granted
            })
    }
}
