import ComposableArchitecture
import Foundation
import OpenClawKit
import SwiftUI
import Testing
import UIKit
@testable import OpenClaw

@MainActor
struct RootTabsPresentationTests {
    @Test func `quick setup does not present when gateway already configured`() {
        let shouldPresent = RootTabs.shouldPresentQuickSetup(
            snapshot: RootPresentationFeature.QuickSetupSnapshot(
                quickSetupDismissed: false,
                showOnboarding: false,
                gatewayConnected: false,
                hasExistingGatewayConfig: true,
                discoveredGatewayCount: 1),
            hasPresentedSheet: false)

        #expect(!shouldPresent)
    }

    @Test func `quick setup presents for fresh install with discovered gateway`() {
        let shouldPresent = RootTabs.shouldPresentQuickSetup(
            snapshot: RootPresentationFeature.QuickSetupSnapshot(
                quickSetupDismissed: false,
                showOnboarding: false,
                gatewayConnected: false,
                hasExistingGatewayConfig: false,
                discoveredGatewayCount: 1),
            hasPresentedSheet: false)

        #expect(shouldPresent)
    }

    @Test func `quick setup does not present when already connected`() {
        let shouldPresent = RootTabs.shouldPresentQuickSetup(
            snapshot: RootPresentationFeature.QuickSetupSnapshot(
                quickSetupDismissed: false,
                showOnboarding: false,
                gatewayConnected: true,
                hasExistingGatewayConfig: false,
                discoveredGatewayCount: 1),
            hasPresentedSheet: false)

        #expect(!shouldPresent)
    }

    @Test func `startup presentation opens onboarding for fresh install`() {
        #expect(
            RootTabs.startupPresentationRoute(
                snapshot: Self.startupSnapshot(
                    gatewayConnected: false,
                    hasConnectedOnce: false,
                    onboardingComplete: false,
                    hasExistingGatewayConfig: false)) == .onboarding)
    }

    @Test func `startup presentation opens settings when onboarding complete without config`() {
        #expect(
            RootTabs.startupPresentationRoute(
                snapshot: Self.startupSnapshot(
                    gatewayConnected: false,
                    hasConnectedOnce: true,
                    onboardingComplete: true,
                    hasExistingGatewayConfig: false)) == .settings)
    }

    @Test func `startup presentation does not interrupt connected gateway`() {
        #expect(
            RootTabs.startupPresentationRoute(
                snapshot: Self.startupSnapshot(
                    gatewayConnected: true,
                    hasConnectedOnce: false,
                    onboardingComplete: false,
                    hasExistingGatewayConfig: false,
                    shouldPresentOnLaunch: true)) == .none)
    }

    @Test func `reducer updates startup presentation route`() async {
        let store = TestStore(initialState: RootPresentationFeature.State(
            gatewayConnected: true,
            hasConnectedOnce: true,
            onboardingComplete: true,
            hasExistingGatewayConfig: true,
            shouldPresentOnLaunch: false))
        {
            RootPresentationFeature()
        }

        await store.send(.startupSnapshotChanged(Self.startupSnapshotChange(
            gatewayConnected: false,
            hasConnectedOnce: false,
            onboardingComplete: false,
            hasExistingGatewayConfig: false)))
        {
            $0.gatewayConnected = false
            $0.hasConnectedOnce = false
            $0.onboardingComplete = false
            $0.hasExistingGatewayConfig = false
            $0.startupRoute = .onboarding
        }

        await store.send(.startupSnapshotChanged(Self.startupSnapshotChange(
            gatewayConnected: false,
            hasConnectedOnce: true,
            onboardingComplete: true,
            hasExistingGatewayConfig: false)))
        {
            $0.hasConnectedOnce = true
            $0.onboardingComplete = true
            $0.startupRoute = .settings
        }

        await store.send(.startupSnapshotChanged(Self.startupSnapshotChange(
            gatewayConnected: false,
            hasConnectedOnce: true,
            onboardingComplete: true,
            hasExistingGatewayConfig: true)))
        {
            $0.hasExistingGatewayConfig = true
            $0.startupRoute = .none
        }
    }

    @Test func `reducer opens onboarding on first startup presentation evaluation`() async {
        let store = TestStore(initialState: RootPresentationFeature.State()) {
            RootPresentationFeature()
        }

        await store.send(.startupPresentationEvaluationRequested(Self.startupPresentationEvaluationRequest(
            gatewayConnected: false,
            hasConnectedOnce: false,
            onboardingComplete: false,
            hasExistingGatewayConfig: false)))
        {
            $0.didEvaluateOnboarding = true
            $0.showOnboarding = true
            $0.startupRoute = .onboarding
        }

        await store.send(.startupPresentationEvaluationRequested(Self.startupPresentationEvaluationRequest(
            gatewayConnected: false,
            hasConnectedOnce: true,
            onboardingComplete: true,
            hasExistingGatewayConfig: false)))
    }

    @Test func `reducer opens settings when startup evaluation needs gateway config`() async {
        let store = TestStore(initialState: RootPresentationFeature.State()) {
            RootPresentationFeature()
        }

        await store.send(.startupPresentationEvaluationRequested(Self.startupPresentationEvaluationRequest(
            gatewayConnected: false,
            hasConnectedOnce: true,
            onboardingComplete: true,
            hasExistingGatewayConfig: false)))
        {
            $0.hasConnectedOnce = true
            $0.onboardingComplete = true
            $0.didEvaluateOnboarding = true
            $0.didAutoOpenSettings = true
            $0.startupRoute = .settings
            $0.presentationCommand = .openGatewaySettingsAndRequestLocalNetworkAccess(
                reason: "root_appear")
        }

        await store.send(.presentationCommandHandled) {
            $0.presentationCommand = nil
        }
    }

    @Test func `reducer auto opens settings once after onboarding is complete without config`() async {
        let store = TestStore(initialState: RootPresentationFeature.State()) {
            RootPresentationFeature()
        }

        await store.send(.autoOpenSettingsRequested(Self.autoOpenSettingsRequest(
            gatewayConnected: false,
            hasConnectedOnce: true,
            onboardingComplete: true,
            hasExistingGatewayConfig: false)))
        {
            $0.hasConnectedOnce = true
            $0.onboardingComplete = true
            $0.startupRoute = .settings
            $0.didAutoOpenSettings = true
            $0.presentationCommand = .openGatewaySettingsAndRequestLocalNetworkAccess(
                reason: "auto_open_settings")
        }

        await store.send(.autoOpenSettingsRequested(Self.autoOpenSettingsRequest(
            gatewayConnected: false,
            hasConnectedOnce: true,
            onboardingComplete: true,
            hasExistingGatewayConfig: false)))
    }

    @Test func `reducer handles gateway setup request once`() async {
        let store = TestStore(initialState: RootPresentationFeature.State(
            showOnboarding: true,
            presentedSheet: .quickSetup))
        {
            RootPresentationFeature()
        }

        await store.send(.gatewaySetupRequestChanged(Self.gatewaySetupRequest(requestID: 42))) {
            $0.showOnboarding = false
            $0.didAutoOpenSettings = true
            $0.handledGatewaySetupRequestID = 42
            $0.presentedSheet = nil
            $0.presentationCommand = .openGatewaySettingsAndRequestLocalNetworkAccess(
                reason: "gateway_setup_deeplink")
        }

        await store.send(.gatewaySetupRequestChanged(Self.gatewaySetupRequest(requestID: 42)))
    }

    @Test func `gateway overview refresh reducer refreshes connected gateway overview`() async {
        let probe = RootGatewayOverviewRefreshProbe()
        let store = TestStore(initialState: RootGatewayOverviewRefreshFeature.State()) {
            RootGatewayOverviewRefreshFeature(client: probe.client)
        }

        await store.send(.sceneActiveRefreshRequested)
        await store.finish()

        #expect(probe.refreshCount == 1)
    }

    @Test func `canvas presentation reducer hides canvas through client`() async {
        let probe = RootCanvasPresentationProbe()
        let store = TestStore(initialState: RootCanvasPresentationFeature.State()) {
            RootCanvasPresentationFeature(client: probe.client)
        }

        await store.send(.closeButtonTapped)
        await store.finish()

        #expect(probe.hideCount == 1)
    }

    @Test func `canvas debug status reducer syncs enabled state and labels through client`() async {
        let probe = RootCanvasDebugStatusProbe()
        let store = TestStore(initialState: RootCanvasDebugStatusFeature.State()) {
            RootCanvasDebugStatusFeature(client: probe.client)
        }

        await store.send(.snapshotChanged(RootCanvasDebugStatusFeature.Snapshot(
            isEnabled: false,
            gatewayDisplayStatusText: "  Offline  ",
            gatewayServerName: "Gateway",
            gatewayRemoteAddress: "100.64.0.2")))
        await store.finish()

        #expect(probe.enabledValues == [false])
        #expect(probe.titles.isEmpty)
        #expect(probe.subtitles.isEmpty)

        await store.send(.snapshotChanged(RootCanvasDebugStatusFeature.Snapshot(
            isEnabled: true,
            gatewayDisplayStatusText: "  Online  ",
            gatewayServerName: "Gateway",
            gatewayRemoteAddress: "100.64.0.2")))
        await store.finish()

        #expect(probe.enabledValues == [false, true])
        #expect(probe.titles == ["Online"])
        #expect(probe.subtitles == ["Gateway"])
    }

    @Test func `idle timer reducer syncs lifecycle state through client`() async {
        let probe = RootIdleTimerProbe()
        let store = TestStore(initialState: RootIdleTimerFeature.State()) {
            RootIdleTimerFeature(client: probe.client)
        }

        await store.send(.snapshotChanged(RootIdleTimerFeature.Snapshot(
            isSceneActive: true,
            preventSleep: false,
            talkModeEnabled: false)))
        await store.finish()

        await store.send(.snapshotChanged(RootIdleTimerFeature.Snapshot(
            isSceneActive: true,
            preventSleep: true,
            talkModeEnabled: false)))
        await store.finish()

        await store.send(.snapshotChanged(RootIdleTimerFeature.Snapshot(
            isSceneActive: false,
            preventSleep: true,
            talkModeEnabled: true)))
        await store.finish()

        await store.send(.disappeared)
        await store.finish()

        #expect(probe.disabledValues == [false, true, false])
    }

    @Test func `gateway problem reducer trusts rotated certificate instead of retrying`() async {
        let probe = RootGatewayProblemPrimaryActionProbe()
        let problem = Self.rotatedCertificateProblem()
        let store = TestStore(initialState: RootGatewayProblemPrimaryActionFeature.State()) {
            RootGatewayProblemPrimaryActionFeature(client: probe.client)
        }

        await store.send(.primaryActionTapped(problem))
        await store.finish()

        #expect(probe.trustedProblems == [problem])
        #expect(probe.reconnectCount == 0)
        #expect(probe.openSettingsCount == 0)
    }

    @Test func `gateway problem reducer opens protocol mismatch help instead of retrying`() async {
        let probe = RootGatewayProblemPrimaryActionProbe()
        let problem = Self.protocolMismatchProblem()
        let store = TestStore(initialState: RootGatewayProblemPrimaryActionFeature.State()) {
            RootGatewayProblemPrimaryActionFeature(client: probe.client)
        }

        await store.send(.primaryActionTapped(problem))
        await store.finish()

        #expect(probe.openedProblems == [problem])
        #expect(probe.reconnectCount == 0)
        #expect(probe.openSettingsCount == 0)
    }

    @Test func `gateway problem reducer reconnects retryable problems`() async {
        let probe = RootGatewayProblemPrimaryActionProbe()
        let store = TestStore(initialState: RootGatewayProblemPrimaryActionFeature.State()) {
            RootGatewayProblemPrimaryActionFeature(client: probe.client)
        }

        await store.send(.primaryActionTapped(Self.retryableGatewayProblem()))
        await store.finish()

        #expect(probe.reconnectCount == 1)
        #expect(probe.openSettingsCount == 0)
    }

    @Test func `gateway problem reducer opens settings for non retryable problems`() async {
        let probe = RootGatewayProblemPrimaryActionProbe()
        let store = TestStore(initialState: RootGatewayProblemPrimaryActionFeature.State()) {
            RootGatewayProblemPrimaryActionFeature(client: probe.client)
        }

        await store.send(.primaryActionTapped(Self.nonRetryableGatewayProblem()))
        await store.finish()

        #expect(probe.openSettingsCount == 1)
        #expect(probe.reconnectCount == 0)
    }

    @Test func `reducer gates local network access until evaluated active and onboarding hidden`() async {
        let store = TestStore(initialState: RootPresentationFeature.State(showOnboarding: true)) {
            RootPresentationFeature()
        }

        await store.send(.localNetworkAccessRequested(Self.localNetworkAccessRequest(
            reason: "scene_active",
            sceneActive: true)))

        await store.send(.onboardingVisibilityChanged(Self.onboardingVisibilityChange(
            isPresented: false,
            sceneActive: true))) {
            $0.showOnboarding = false
        }

        await store.send(.startupPresentationEvaluationRequested(Self.startupPresentationEvaluationRequest(
            gatewayConnected: true,
            hasConnectedOnce: true,
            onboardingComplete: true,
            hasExistingGatewayConfig: true)))
        {
            $0.gatewayConnected = true
            $0.hasConnectedOnce = true
            $0.onboardingComplete = true
            $0.hasExistingGatewayConfig = true
            $0.didEvaluateOnboarding = true
            $0.startupRoute = .none
            $0.presentationCommand = .requestLocalNetworkAccess(reason: "root_appear")
        }

        await store.send(.presentationCommandHandled) {
            $0.presentationCommand = nil
        }

        await store.send(.localNetworkAccessRequested(Self.localNetworkAccessRequest(
            reason: "scene_active",
            sceneActive: false)))

        await store.send(.localNetworkAccessRequested(Self.localNetworkAccessRequest(
            reason: "scene_active",
            sceneActive: true))) {
            $0.presentationCommand = .requestLocalNetworkAccess(reason: "scene_active")
        }
    }

    @Test func `reducer presents and dismisses gateway problem details`() async {
        let store = TestStore(initialState: RootPresentationFeature.State()) {
            RootPresentationFeature()
        }

        await store.send(.gatewayProblemDetailsButtonTapped) {
            $0.showGatewayProblemDetails = true
        }
        await store.send(.gatewayProblemDetailsDismissed) {
            $0.showGatewayProblemDetails = false
        }
    }

    @Test func `reducer owns sidebar gateway status presentation`() async {
        let store = TestStore(initialState: RootPresentationFeature.State()) {
            RootPresentationFeature()
        }

        await store.send(.sidebarGatewayStatusChanged(Self.sidebarGatewayStatusChange(.connected))) {
            $0.sidebarGatewayStatus = .connected
        }
        #expect(store.state.sidebarGatewayStatusTitle == "Online")
        #expect(store.state.sidebarGatewayStatusColor == OpenClawBrand.ok)

        await store.send(.sidebarGatewayStatusChanged(Self.sidebarGatewayStatusChange(.error))) {
            $0.sidebarGatewayStatus = .error
        }
        #expect(store.state.sidebarGatewayStatusTitle == "Needs attention")
        #expect(store.state.sidebarGatewayStatusColor == OpenClawBrand.warn)

        await store.send(.sidebarGatewayStatusChanged(Self.sidebarGatewayStatusChange(.disconnected))) {
            $0.sidebarGatewayStatus = .disconnected
        }
        #expect(store.state.sidebarGatewayStatusTitle == "Offline")
        #expect(store.state.sidebarGatewayStatusColor == .secondary)
    }

    @Test func `home canvas reducer builds connected payload with active agent first`() async throws {
        let snapshot = RootHomeCanvasFeature.Snapshot(
            gatewayStatus: .connected,
            gatewayServerName: "  Local Gateway  ",
            gatewayRemoteAddress: "100.64.0.2",
            selectedAgentID: "gamma",
            gatewayDefaultAgentID: "alpha",
            activeAgentName: "Gamma Agent",
            agents: [
                RootHomeCanvasFeature.AgentSnapshot(id: "beta", name: "Beta Agent", emoji: nil),
                RootHomeCanvasFeature.AgentSnapshot(id: "gamma", name: "Gamma Agent", emoji: nil),
                RootHomeCanvasFeature.AgentSnapshot(id: "alpha", name: "Alpha-Agent", emoji: nil),
            ])
        let expectedPayload = RootHomeCanvasFeature.Payload(
            gatewayState: "connected",
            eyebrow: "Local Gateway online",
            title: "Command center",
            subtitle:
            "Use Chat for code work, Talk for realtime voice, and gateway tools for approved device actions.",
            gatewayLabel: "Local Gateway",
            activeAgentName: "Gamma Agent",
            activeAgentBadge: "GA",
            activeAgentCaption: "Routes chat and talk",
            agentCount: 3,
            agents: [
                RootHomeCanvasFeature.AgentCard(
                    id: "gamma",
                    name: "Gamma Agent",
                    badge: "GA",
                    caption: "Routed on this phone",
                    isActive: true),
                RootHomeCanvasFeature.AgentCard(
                    id: "alpha",
                    name: "Alpha-Agent",
                    badge: "AA",
                    caption: "Gateway default",
                    isActive: false),
                RootHomeCanvasFeature.AgentCard(
                    id: "beta",
                    name: "Beta Agent",
                    badge: "BA",
                    caption: "Available",
                    isActive: false),
            ],
            footer: "OpenClaw only runs phone-side capabilities while the app is connected and permitted.")
        let store = TestStore(initialState: RootHomeCanvasFeature.State()) {
            RootHomeCanvasFeature()
        }

        await store.send(.snapshotChanged(snapshot)) {
            $0.payload = expectedPayload
            $0.payloadJSON = RootHomeCanvasFeature.payloadJSON(expectedPayload)
        }
        let payloadJSON = try #require(store.state.payloadJSON)
        let decodedPayload = try JSONDecoder().decode(
            RootHomeCanvasFeature.Payload.self,
            from: Data(payloadJSON.utf8))
        #expect(decodedPayload == expectedPayload)
    }

    @Test func `home canvas reducer builds error payload with fallback active agent copy`() async throws {
        let snapshot = RootHomeCanvasFeature.Snapshot(
            gatewayStatus: .error,
            gatewayServerName: "   ",
            gatewayRemoteAddress: "  node.local  ",
            selectedAgentID: nil,
            gatewayDefaultAgentID: "main",
            activeAgentName: "Ignored Agent",
            agents: [
                RootHomeCanvasFeature.AgentSnapshot(id: "main", name: "  Main  ", emoji: " M "),
            ])
        let expectedPayload = RootHomeCanvasFeature.Payload(
            gatewayState: "error",
            eyebrow: "Gateway needs attention",
            title: "Pair a gateway",
            subtitle:
            "Connect this phone as a local node for chat, realtime voice, share intake, and approved device tools.",
            gatewayLabel: "node.local",
            activeAgentName: "Main",
            activeAgentBadge: "OC",
            activeAgentCaption: "Connect to load your agents",
            agentCount: 1,
            agents: [
                RootHomeCanvasFeature.AgentCard(
                    id: "main",
                    name: "Main",
                    badge: "M",
                    caption: "Routed on this phone",
                    isActive: true),
            ],
            footer:
            "Use Settings to scan a pairing QR code or paste a setup code from your OpenClaw gateway.")
        let store = TestStore(initialState: RootHomeCanvasFeature.State()) {
            RootHomeCanvasFeature()
        }

        await store.send(.snapshotChanged(snapshot)) {
            $0.payload = expectedPayload
            $0.payloadJSON = RootHomeCanvasFeature.payloadJSON(expectedPayload)
        }
        let payloadJSON = try #require(store.state.payloadJSON)
        let decodedPayload = try JSONDecoder().decode(
            RootHomeCanvasFeature.Payload.self,
            from: Data(payloadJSON.utf8))
        #expect(decodedPayload == expectedPayload)
    }

    @Test func `launch reducer applies initial appearance once`() async {
        let store = TestStore(initialState: RootLaunchFeature.State()) {
            RootLaunchFeature()
        }

        await store.send(.initialAppearanceRequested(AppAppearancePreference.dark.rawValue)) {
            $0.didApplyInitialAppearance = true
            $0.command = .applyAppearance(rawValue: AppAppearancePreference.dark.rawValue)
        }

        await store.send(.commandHandled) {
            $0.command = nil
        }

        await store.send(.initialAppearanceRequested(AppAppearancePreference.light.rawValue))
    }

    @Test func `launch reducer marks appearance applied without launch argument`() async {
        let store = TestStore(initialState: RootLaunchFeature.State()) {
            RootLaunchFeature()
        }

        await store.send(.initialAppearanceRequested(nil)) {
            $0.didApplyInitialAppearance = true
        }
    }

    @Test func `launch reducer focuses initial chat session once`() async {
        let store = TestStore(initialState: RootLaunchFeature.State()) {
            RootLaunchFeature()
        }

        await store.send(.initialChatSessionRequested("session-1")) {
            $0.didApplyInitialChatSession = true
            $0.command = .focusChatSession("session-1")
        }

        await store.send(.commandHandled) {
            $0.command = nil
        }

        await store.send(.initialChatSessionRequested("session-2"))
    }

    @Test func `voice wake toast reducer shows trimmed command and dismisses after delay`() async {
        let store = TestStore(initialState: RootVoiceWakeToastFeature.State()) {
            RootVoiceWakeToastFeature(sleeper: RootVoiceWakeToastSleepClient(sleep: {}))
        }

        await store.send(.commandTriggered("  openclaw do this  ")) {
            $0.commandText = "openclaw do this"
        }
        await store.receive(.dismissDelayElapsed) {
            $0.commandText = nil
        }
    }

    @Test func `voice wake toast reducer ignores empty commands`() async {
        let store = TestStore(initialState: RootVoiceWakeToastFeature.State()) {
            RootVoiceWakeToastFeature(sleeper: RootVoiceWakeToastSleepClient(sleep: {}))
        }

        await store.send(.commandTriggered("   "))
        await store.finish()
    }

    @Test func `voice wake toast reducer cancels dismiss on disappear`() async {
        let probe = RootVoiceWakeToastSleepProbe()
        let store = TestStore(initialState: RootVoiceWakeToastFeature.State()) {
            RootVoiceWakeToastFeature(sleeper: probe.client)
        }

        await store.send(.commandTriggered("openclaw do this")) {
            $0.commandText = "openclaw do this"
        }
        await store.send(.disappeared)

        await store.finish()
        #expect(probe.wasCancelled)
    }

    @Test func `camera flash overlay reducer fades out after delay`() async {
        let store = TestStore(initialState: RootCameraFlashOverlayFeature.State()) {
            RootCameraFlashOverlayFeature(sleeper: RootCameraFlashOverlaySleepClient(sleep: {}))
        }

        await store.send(.nonceChanged) {
            $0.opacity = 0.85
        }
        await store.receive(.fadeOutDelayElapsed) {
            $0.opacity = 0
        }
    }

    @Test func `camera flash overlay reducer cancels fade out on disappear`() async {
        let probe = RootCameraFlashOverlaySleepProbe()
        let store = TestStore(initialState: RootCameraFlashOverlayFeature.State()) {
            RootCameraFlashOverlayFeature(sleeper: probe.client)
        }

        await store.send(.nonceChanged) {
            $0.opacity = 0.85
        }
        await store.send(.disappeared)

        await store.finish()
        #expect(probe.wasCancelled)
    }

    private final class RootVoiceWakeToastSleepProbe: @unchecked Sendable {
        var wasCancelled = false
        private var continuation: CheckedContinuation<Void, Error>?

        var client: RootVoiceWakeToastSleepClient {
            RootVoiceWakeToastSleepClient(sleep: {
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

    private final class RootCameraFlashOverlaySleepProbe: @unchecked Sendable {
        var wasCancelled = false
        private var continuation: CheckedContinuation<Void, Error>?

        var client: RootCameraFlashOverlaySleepClient {
            RootCameraFlashOverlaySleepClient(sleep: {
                try await withTaskCancellationHandler {
                    try await withCheckedThrowingContinuation { continuation in
                        self.continuation = continuation
                    }
                } onCancel: {
                    self.wasCancelled = true
                    self.continuation?.resume(throwing: CancellationError())
                }
            })
        }
    }

    @Test func `reducer updates quick setup presentation`() async {
        let store = TestStore(initialState: RootPresentationFeature.State(
            quickSetupDismissed: false,
            showOnboarding: false,
            discoveredGatewayCount: 0))
        {
            RootPresentationFeature()
        }

        await store.send(.quickSetupSnapshotChanged(Self.quickSetupSnapshotChange(
            quickSetupDismissed: false,
            showOnboarding: false,
            gatewayConnected: false,
            hasExistingGatewayConfig: false,
            discoveredGatewayCount: 1)))
        {
            $0.discoveredGatewayCount = 1
            $0.presentedSheet = .quickSetup
        }

        await store.send(.presentedSheetChanged(Self.presentedSheetChange(nil))) {
            $0.presentedSheet = nil
            $0.shouldPresentQuickSetup = true
        }

        await store.send(.quickSetupSnapshotChanged(Self.quickSetupSnapshotChange(
            quickSetupDismissed: false,
            showOnboarding: true,
            gatewayConnected: false,
            hasExistingGatewayConfig: false,
            discoveredGatewayCount: 1)))
        {
            $0.showOnboarding = true
            $0.shouldPresentQuickSetup = false
        }
    }

    @Test func `sidebar tabs enabled for I pad regular width`() {
        #expect(
            RootTabs.shouldUseSidebarTabs(
                idiom: .pad,
                horizontalSizeClass: .regular))
    }

    @Test func `sidebar tabs enabled for I pad compact width`() {
        #expect(
            RootTabs.shouldUseSidebarTabs(
                idiom: .pad,
                horizontalSizeClass: .compact))
    }

    @Test func `sidebar tabs disabled for I phone`() {
        #expect(
            !RootTabs.shouldUseSidebarTabs(
                idiom: .phone,
                horizontalSizeClass: .regular))
    }

    @Test func `sidebar groups match adaptive navigation model`() {
        let groups = RootTabs.sidebarGroups
        let destinationIDs = RootTabs.SidebarDestination.allCases.map(\.rawValue)

        #expect(groups.map(\.title) == ["CHAT", "CONTROL", "SETTINGS", "REFERENCE"])
        #expect(groups[0].destinations.map(\.rawValue) == ["chat", "talk"])
        #expect(groups[1].destinations == [
            .overview,
            .activity,
            .agents,
            .workboard,
            .skillWorkshop,
            .instances,
            .sessions,
            .dreaming,
            .usage,
            .cron,
        ])
        #expect(groups[2].destinations == [.settings])
        #expect(groups[3].destinations == [.docs])
        #expect(destinationIDs == [
            "chat",
            "talk",
            "overview",
            "activity",
            "agents",
            "workboard",
            "skillWorkshop",
            "instances",
            "sessions",
            "dreaming",
            "usage",
            "cron",
            "docs",
            "settings",
            "gateway",
        ])
        #expect(!destinationIDs.contains("agent"))
        #expect(!RootTabs.sidebarGroups.flatMap(\.destinations).contains(.gateway))
    }

    @Test func `phone control groups avoid duplicating the agent tab`() {
        let groups = RootTabs.phoneControlGroups
        let destinations = groups.flatMap(\.destinations)

        #expect(groups.map(\.title) == ["CHAT", "CONTROL", "SETTINGS", "REFERENCE"])
        #expect(!destinations.contains(.agents))
        #expect(RootTabs.sidebarGroups.flatMap(\.destinations).contains(.agents))
        #expect(destinations.contains(.dreaming))
        #expect(destinations.contains(.instances))
    }

    @Test func `sidebar uses compact labels for long routes`() {
        #expect(RootTabs.SidebarDestination.settings.title == "Settings")
        #expect(RootTabs.SidebarDestination.gateway.title == "Settings / Gateway")
        #expect(RootTabs.SidebarDestination.gateway.sidebarTitle == "Connection")
    }

    @Test func `phone hub uses root tabs only for native chat agent and gateway`() {
        #expect(RootTabs.shouldOpenRootTabFromPhoneHub(.chat))
        #expect(RootTabs.shouldOpenRootTabFromPhoneHub(.talk))
        #expect(RootTabs.shouldOpenRootTabFromPhoneHub(.agents))
        #expect(RootTabs.shouldOpenRootTabFromPhoneHub(.gateway))
        #expect(RootTabs.shouldOpenRootTabFromPhoneHub(.settings))

        for destination in RootTabs.SidebarDestination.allCases
            where destination != .chat && destination != .talk && destination != .agents && destination != .gateway &&
            destination != .settings
        {
            #expect(!RootTabs.shouldOpenRootTabFromPhoneHub(destination))
        }
    }

    @Test func `app launch defaults to chat tab`() {
        #expect(RootTabs.initialTab(arguments: ["OpenClaw"]) == .chat)
        #expect(RootTabs.initialTab(arguments: ["OpenClaw", "--openclaw-initial-tab"]) == .chat)
        #expect(RootTabs.initialTab(arguments: ["OpenClaw", "--openclaw-initial-tab", "unknown"]) == .chat)
    }

    @Test func `app launch uses requested destination before chat fallback`() {
        #expect(RootTabs.initialTab(arguments: ["OpenClaw", "--openclaw-initial-destination", "overview"]) == .control)
        #expect(RootTabs.initialTab(arguments: ["OpenClaw", "--openclaw-initial-destination", "chat"]) == .chat)
        #expect(RootTabs.initialTab(arguments: ["OpenClaw", "--openclaw-initial-destination", "agents"]) == .agent)
        #expect(RootTabs.initialTab(arguments: ["OpenClaw", "--openclaw-initial-destination", "gateway"]) == .settings)
        #expect(
            RootTabs.initialTab(arguments: [
                "OpenClaw",
                "--openclaw-initial-tab",
                "unknown",
                "--openclaw-initial-destination",
                "activity",
            ]) == .control)
    }

    @Test func `app launch respects explicit initial tab override`() {
        #expect(RootTabs.initialTab(arguments: ["OpenClaw", "--openclaw-initial-tab", "control"]) == .control)
        #expect(RootTabs.initialTab(arguments: ["OpenClaw", "--openclaw-initial-tab", "overview"]) == .control)
        #expect(RootTabs.initialTab(arguments: ["OpenClaw", "--openclaw-initial-tab", "chat"]) == .chat)
        #expect(RootTabs.initialTab(arguments: ["OpenClaw", "--openclaw-initial-tab", "voice"]) == .talk)
        #expect(RootTabs.initialTab(arguments: ["OpenClaw", "--openclaw-initial-tab", "agents"]) == .agent)
        #expect(RootTabs.initialTab(arguments: ["OpenClaw", "--openclaw-initial-tab", "settings"]) == .settings)
    }

    @Test func `legacy initial tabs map to matching sidebar destinations`() {
        #expect(RootTabs.defaultSidebarDestination(for: .control) == .overview)
        #expect(RootTabs.defaultSidebarDestination(for: .chat) == .chat)
        #expect(RootTabs.defaultSidebarDestination(for: .talk) == .talk)
        #expect(RootTabs.defaultSidebarDestination(for: .agent) == .agents)
        #expect(RootTabs.defaultSidebarDestination(for: .settings) == .settings)
    }

    @Test func `navigation reducer selects sidebar destinations`() async {
        let store = TestStore(initialState: RootNavigationSelectionFeature.State(
            selectedTab: .chat,
            selectedSidebarDestination: .chat))
        {
            RootNavigationSelectionFeature()
        }

        await store.send(.sidebarNavigationPathChanged(Self.sidebarNavigationPathChange([.voice]))) {
            $0.sidebarNavigationPath = [.voice]
        }

        await store.send(.sidebarDestinationSelected(Self.sidebarDestinationSelection(.gateway))) {
            $0.sidebarNavigationPath = []
            $0.selectedTab = .settings
            $0.selectedSidebarDestination = .gateway
            $0.selectedSettingsRoute = .gateway
        }

        await store.send(.tabSelected(Self.tabSelection(.talk))) {
            $0.selectedTab = .talk
        }
    }

    @Test func `navigation reducer selects settings routes and bumps request id`() async {
        let store = TestStore(initialState: RootNavigationSelectionFeature.State(
            selectedTab: .chat,
            selectedSidebarDestination: .chat))
        {
            RootNavigationSelectionFeature()
        }

        await store.send(.sidebarNavigationPathChanged(Self.sidebarNavigationPathChange([.privacy]))) {
            $0.sidebarNavigationPath = [.privacy]
        }

        await store.send(.settingsRouteSelected(Self.settingsRouteSelection(.voice))) {
            $0.sidebarNavigationPath = []
            $0.selectedTab = .settings
            $0.selectedSidebarDestination = .settings
            $0.selectedSettingsRoute = .voice
            $0.selectedSettingsRouteRequestID = 1
        }

        await store.send(.settingsRouteSelected(Self.settingsRouteSelection(.gateway))) {
            $0.selectedSettingsRoute = .gateway
            $0.selectedSettingsRouteRequestID = 2
        }
    }

    @Test func `navigation reducer tracks notification suppression only for notification route`() async {
        let store = TestStore(initialState: RootNavigationSelectionFeature.State(
            selectedTab: .chat,
            selectedSidebarDestination: .chat))
        {
            RootNavigationSelectionFeature()
        }

        await store.send(.notificationPermissionSettingsOpened(
            Self.notificationPermissionSettingsRequest(suppressedApprovalID: "approval-1")))
        {
            $0.selectedTab = .settings
            $0.selectedSidebarDestination = .settings
            $0.selectedSettingsRoute = .notifications
            $0.selectedSettingsRouteRequestID = 1
            $0.suppressedExecApprovalPromptIDForNotificationSettings = "approval-1"
        }
        #expect(store.state.sidebarNavigationPath.isEmpty)
        #expect(store.state.activeExecApprovalPromptSuppressionID == "approval-1")

        await store.send(.pendingExecApprovalPromptChanged(
            Self.pendingExecApprovalPromptChange(promptID: "approval-1")))
        #expect(store.state.activeExecApprovalPromptSuppressionID == "approval-1")

        await store.send(.pendingExecApprovalPromptChanged(
            Self.pendingExecApprovalPromptChange(promptID: "approval-2")))
        {
            $0.suppressedExecApprovalPromptIDForNotificationSettings = nil
        }
        #expect(store.state.activeExecApprovalPromptSuppressionID == nil)
    }

    @Test func `navigation reducer handles embedded settings route changes`() async {
        let store = TestStore(initialState: RootNavigationSelectionFeature.State(
            selectedTab: .settings,
            selectedSidebarDestination: .gateway))
        {
            RootNavigationSelectionFeature()
        }

        await store.send(.settingsRouteSelected(Self.settingsRouteSelection(.voice))) {
            $0.selectedSidebarDestination = .settings
            $0.selectedSettingsRoute = .voice
            $0.selectedSettingsRouteRequestID = 1
        }

        await store.send(.sidebarSettingsRoutePushed(Self.sidebarSettingsRoutePush(.privacy))) {
            $0.sidebarNavigationPath = [.privacy]
        }

        await store.send(.settingsRouteChanged(Self.settingsRouteChange(.notifications)))

        await store.send(.settingsRouteChanged(Self.settingsRouteChange(nil))) {
            $0.selectedSettingsRoute = nil
            $0.selectedSidebarDestination = .settings
        }
    }

    @Test func `skill workshop mutations require admin scope`() {
        #expect(IPadSkillWorkshopScreen.shouldEnableProposalMutation(canWrite: true, hasOperatorAdminScope: true))
        #expect(!IPadSkillWorkshopScreen.shouldEnableProposalMutation(canWrite: true, hasOperatorAdminScope: false))
        #expect(!IPadSkillWorkshopScreen.shouldEnableProposalMutation(canWrite: false, hasOperatorAdminScope: true))
    }

    @Test func `skill workshop held filter includes quarantined and stale`() {
        #expect(IPadSkillWorkshopScreen.proposalStatusFilters.contains("held"))
        #expect(IPadSkillWorkshopScreen.proposalStatusMatchesFilter(status: "quarantined", filter: "held"))
        #expect(IPadSkillWorkshopScreen.proposalStatusMatchesFilter(status: "stale", filter: "held"))
        #expect(!IPadSkillWorkshopScreen.proposalStatusMatchesFilter(status: "pending", filter: "held"))
    }

    @Test func `skill workshop board lanes match status filter`() {
        #expect(
            IPadSkillWorkshopScreen.proposalStatusBoardLanes(
                filter: "pending",
                proposalStatuses: ["pending", "applied"]) == ["pending"])
        #expect(
            IPadSkillWorkshopScreen.proposalStatusBoardLanes(
                filter: "held",
                proposalStatuses: ["quarantined", "stale"]) == ["quarantined", "stale"])
        #expect(
            IPadSkillWorkshopScreen.proposalStatusBoardLanes(
                filter: "all",
                proposalStatuses: ["pending", "needs-review"]) == [
                "pending",
                "quarantined",
                "stale",
                "applied",
                "rejected",
                "needs-review",
            ])
        #expect(IPadSkillWorkshopScreen.proposalLaneLabel("quarantined") == "Quarantined")
        #expect(IPadSkillWorkshopScreen.proposalLaneLabel("pending") == "Pending")
        #expect(IPadSkillWorkshopScreen.proposalLaneLabel("needs-review") == "Needs Review")
        #expect(IPadSkillWorkshopScreen.proposalLaneLabel("manual_QA") == "Manual QA")
    }

    @Test func `skill workshop selection stays inside active filter`() {
        let proposals = [
            (id: "applied-1", status: "applied"),
            (id: "pending-1", status: "pending"),
            (id: "held-1", status: "quarantined"),
        ]

        #expect(
            IPadSkillWorkshopScreen.nextSelectedProposalID(
                current: "applied-1",
                proposals: proposals,
                filter: "pending") == "pending-1")
        #expect(
            IPadSkillWorkshopScreen.nextSelectedProposalID(
                current: "held-1",
                proposals: proposals,
                filter: "held") == "held-1")
        #expect(
            IPadSkillWorkshopScreen.nextSelectedProposalID(
                current: "pending-1",
                visibleProposalIDs: ["held-1"]) == "held-1")
        #expect(
            IPadSkillWorkshopScreen.nextSelectedProposalID(
                current: "pending-1",
                visibleProposalIDs: []) == nil)
    }

    @Test func `workboard board scope labels stay compact`() {
        #expect(IPadWorkboardScreen.normalizedScopeID("  planning ") == "planning")
        #expect(IPadWorkboardScreen.boardScopeLabel(for: "") == "All boards")
        #expect(IPadWorkboardScreen.boardScopeLabel(for: "planning") == "planning")
        #expect(IPadWorkboardScreen.boardScopeOptions(
            knownBoardIDs: ["default", " empty-board ", ""],
            cardBoardIDs: ["planning", "default"]) == ["default", "empty-board", "planning"])
        #expect(IPadWorkboardScreen
            .workboardSubtitle(boardScopeLabel: "All boards", selectedStatus: "active") == "All boards / Active")
        #expect(IPadWorkboardScreen
            .workboardSubtitle(boardScopeLabel: "planning", selectedStatus: "running") == "planning / Running")
    }

    @Test func `workboard compact unavailable copy explains real capability state`() {
        #expect(IPadWorkboardScreen
            .compactWriteUnavailableMessage(canRead: false) ==
            "Connect from Settings to create, move, and dispatch cards.")
        #expect(IPadWorkboardScreen.compactWriteUnavailableMessage(canRead: true) == "Read-only gateway.")
    }

    @Test func `skill workshop agent scope normalizes gateway ids`() {
        #expect(IPadSkillWorkshopScreen.normalizedScopeID("  aiden ") == "aiden")
        #expect(IPadSkillWorkshopScreen.normalizedScopeID(nil) == "")
    }

    @Test func `channel lifecycle controls require admin scope`() {
        #expect(SettingsChannelsDestination.shouldEnableChannelOperation(canRead: true, hasOperatorAdminScope: true))
        #expect(!SettingsChannelsDestination.shouldEnableChannelOperation(canRead: true, hasOperatorAdminScope: false))
        #expect(!SettingsChannelsDestination.shouldEnableChannelOperation(canRead: false, hasOperatorAdminScope: true))
    }

    @Test func `click clack stays in channels integration metadata`() {
        #expect(SettingsChannelsDestination.fallbackLabel("clickclack") == "ClickClack")
        #expect(SettingsChannelsDestination.fallbackDetail("clickclack") == "Self-hosted chat bot routing.")
        #expect(SettingsChannelsDestination.fallbackSystemImage("clickclack") == "bubble.left.and.bubble.right")
    }

    @Test func `i pad overview can suppress standalone header branding`() {
        #expect(CommandCenterTab.shouldShowHeaderMark(hasLeadingAction: false, showsHeaderMark: true))
        #expect(!CommandCenterTab.shouldShowHeaderMark(hasLeadingAction: true, showsHeaderMark: true))
        #expect(!CommandCenterTab.shouldShowHeaderMark(hasLeadingAction: false, showsHeaderMark: false))
    }

    @Test func `command center can use parent navigation stack for embedded routes`() {
        let standalone = CommandCenterTab(openChat: {}, openSettings: {})
        let embedded = CommandCenterTab(
            ownsNavigationStack: false,
            openChat: {},
            openSettings: {})
        let shellRouted = CommandCenterTab(
            ownsNavigationStack: false,
            openChat: {},
            openSettings: {},
            openSessions: {})

        #expect(standalone.ownsNavigationStack)
        #expect(standalone.openSessions == nil)
        #expect(!embedded.ownsNavigationStack)
        #expect(embedded.openSessions == nil)
        #expect(shellRouted.openSessions != nil)
    }

    @Test func `chat sidebar destination can use route header instead of agent branding`() {
        let standalone = ChatProTab()
        let routed = ChatProTab(
            headerTitle: "Chat",
            headerSubtitle: "Agent conversation",
            showsAgentBadge: false,
            ownsNavigationStack: false,
            openSettings: {})

        #expect(standalone.showsAgentBadge)
        #expect(standalone.ownsNavigationStack)
        #expect(standalone.headerTitle == nil)
        #expect(standalone.openSettings == nil)
        #expect(routed.headerTitle == "Chat")
        #expect(routed.headerSubtitle == "Agent conversation")
        #expect(!routed.showsAgentBadge)
        #expect(!routed.ownsNavigationStack)
        #expect(routed.openSettings != nil)
        #expect(ChatProPresentationState.defaultHeaderTitle(
            showsAgentBadge: true,
            agentDisplayName: "OpenClaw") == "OpenClaw")
        #expect(ChatProPresentationState.defaultHeaderTitle(
            showsAgentBadge: false,
            agentDisplayName: "OpenClaw") == "Chat")
    }

    @Test func `agent routes can open gateway settings from header pill`() {
        let standalone = AgentProTab()
        let routed = AgentProTab(
            directRoute: .instances,
            headerTitle: "Instances",
            openSettings: {})

        #expect(standalone.headerTitle == "Agents")
        #expect(standalone.directRoute == nil)
        #expect(standalone.openSettings == nil)
        #expect(AgentProTab(directRoute: .agents).directRoute == .agents)
        #expect(routed.directRoute == .instances)
        #expect(routed.headerTitle == "Instances")
        #expect(routed.openSettings != nil)
    }

    @Test func `workboard dispatch summary reports started and failures`() throws {
        let payload = Data(
            """
            {
              "count": 2,
              "started": [{}],
              "startFailures": [{}],
              "promoted": [],
              "reclaimed": [],
              "blocked": [],
              "orchestrated": []
            }
            """.utf8)
        let summary = try JSONDecoder().decode(IPadWorkboardDispatchSummary.self, from: payload)

        #expect(summary.summaryText == "2 dispatched: 1 started, 1 failed.")
    }

    @Test func `talk sidebar destination can receive reveal action`() {
        let action = OpenClawSidebarHeaderAction(
            systemName: "sidebar.left",
            accessibilityLabel: "Show Sidebar",
            action: {})
        let routed = TalkProTab(headerLeadingAction: action, openSettings: {})
        let embedded = TalkProTab(
            headerLeadingAction: action,
            ownsNavigationStack: false,
            openSettings: {})

        #expect(routed.headerLeadingAction?.systemName == "sidebar.left")
        #expect(routed.headerLeadingAction?.accessibilityLabel == "Show Sidebar")
        #expect(routed.ownsNavigationStack)
        #expect(!embedded.ownsNavigationStack)
    }

    @Test func `settings can use parent navigation stack for sidebar routes`() {
        let standalone = SettingsProTab()
        let embedded = SettingsProTab(ownsNavigationStack: false)

        #expect(standalone.ownsNavigationStack)
        #expect(!embedded.ownsNavigationStack)
    }

    @Test func `i pad portrait uses hidden drawer sidebar`() {
        let mode = RootTabs.sidebarLayoutMode(containerSize: CGSize(width: 1024, height: 1366))

        #expect(mode == .drawer)
        #expect(!RootTabs.preferredSidebarVisibility(layoutMode: mode))
    }

    @Test func `i pad wide landscape uses visible split sidebar`() {
        let mode = RootTabs.sidebarLayoutMode(containerSize: CGSize(width: 1366, height: 1024))

        #expect(mode == .split)
        #expect(RootTabs.preferredSidebarVisibility(layoutMode: mode))
    }

    @Test func `i pad split sidebar width stays usable`() {
        let width = RootTabs.sidebarWidth(containerWidth: 1366, isDrawerLayout: false)

        #expect(width >= RootTabs.sidebarSplitIdealWidth)
        #expect(width <= RootTabs.sidebarSplitMaximumWidth)
    }

    @Test func `i pad collapsed split sidebar uses header reveal without reserved rail`() {
        #expect(
            RootTabs.shouldShowSidebarRevealInDestinationHeader(
                isSidebarVisible: false,
                layoutMode: .split))
        #expect(
            RootTabs.shouldShowSidebarRevealInDestinationHeader(
                isSidebarVisible: true,
                layoutMode: .split))
        #expect(
            RootTabs.shouldShowSidebarRevealInDestinationHeader(
                isSidebarVisible: false,
                layoutMode: .drawer))
        #expect(
            !RootTabs.shouldShowSidebarRevealInDestinationHeader(
                isSidebarVisible: true,
                layoutMode: .drawer))
    }

    @Test func `initial sidebar visibility parses launch argument`() {
        #expect(
            RootTabs.requestedInitialSidebarVisibility(arguments: [
                "OpenClaw",
                "--openclaw-sidebar-visibility",
                "hidden",
            ]) == false)
        #expect(
            RootTabs.requestedInitialSidebarVisibility(arguments: [
                "OpenClaw",
                "--openclaw-sidebar-visibility",
                "visible",
            ]) == true)
        #expect(
            RootTabs.requestedInitialSidebarVisibility(arguments: [
                "OpenClaw",
                "--openclaw-sidebar-visibility",
                "unknown",
            ]) == nil)
    }

    @Test func `sidebar controls have stable accessibility identifiers`() {
        #expect(RootTabs.sidebarShowButtonAccessibilityIdentifier == "RootTabs.Sidebar.Show")
        #expect(RootTabs.sidebarHideButtonAccessibilityIdentifier == "RootTabs.Sidebar.Hide")
    }

    @Test func `sidebar reducer uses initial visibility as user override`() async {
        let store = TestStore(initialState: RootSidebarFeature.State(initialVisibility: true)) {
            RootSidebarFeature()
        }

        await store.send(.layoutModeResolved(Self.sidebarLayoutModeResolution(.drawer, force: false))) {
            $0.layoutMode = .drawer
            $0.didResolveLayout = true
        }
    }

    @Test func `sidebar reducer applies preferred visibility when not overridden`() async {
        let store = TestStore(initialState: RootSidebarFeature.State()) {
            RootSidebarFeature()
        }

        await store.send(.layoutModeResolved(Self.sidebarLayoutModeResolution(.split, force: false))) {
            $0.didResolveLayout = true
            $0.isVisible = true
        }

        await store.send(.layoutModeResolved(Self.sidebarLayoutModeResolution(.drawer, force: false))) {
            $0.layoutMode = .drawer
            $0.userOverridden = false
            $0.isVisible = false
        }
    }

    @Test func `sidebar reducer preserves user override until layout mode changes`() async {
        let store = TestStore(initialState: RootSidebarFeature.State()) {
            RootSidebarFeature()
        }

        await store.send(.layoutModeResolved(Self.sidebarLayoutModeResolution(.drawer, force: false))) {
            $0.layoutMode = .drawer
            $0.didResolveLayout = true
        }

        await store.send(.showRequested) {
            $0.userOverridden = true
            $0.isVisible = true
        }

        await store.send(.layoutModeResolved(Self.sidebarLayoutModeResolution(.drawer, force: false)))

        await store.send(.layoutModeResolved(Self.sidebarLayoutModeResolution(.split, force: false))) {
            $0.userOverridden = false
            $0.layoutMode = .split
        }
    }

    @Test func `sidebar reducer selection collapse does not mark user override`() async {
        let store = TestStore(initialState: RootSidebarFeature.State(initialVisibility: true)) {
            RootSidebarFeature()
        }

        await store.send(.visibilityChanged(Self.sidebarVisibilityChange(isVisible: false))) {
            $0.isVisible = false
        }
        #expect(store.state.userOverridden)

        await store.send(.hideRequested)
    }

    @Test func `i pad drawer sidebar width stays inside screen`() {
        let width = RootTabs.sidebarWidth(containerWidth: 744, isDrawerLayout: true)

        #expect(width >= 280)
        #expect(width <= RootTabs.sidebarDrawerMaximumWidth)
    }

    @Test func `narrow landscape keeps drawer sidebar`() {
        let mode = RootTabs.sidebarLayoutMode(containerSize: CGSize(width: 900, height: 600))

        #expect(mode == .drawer)
        #expect(!RootTabs.preferredSidebarVisibility(layoutMode: mode))
    }

    @Test func `drawer selection collapses sidebar but split selection does not`() {
        #expect(RootTabs.shouldCollapseSidebarAfterSelection(layoutMode: .drawer))
        #expect(!RootTabs.shouldCollapseSidebarAfterSelection(layoutMode: .split))
    }

    @Test func `hidden sidebar shows reveal control`() {
        #expect(RootTabs.shouldShowSidebarRevealControl(isSidebarVisible: false))
    }

    @Test func `sidebar reveal controls hide when sidebar is visible`() {
        #expect(!RootTabs.shouldShowSidebarRevealControl(isSidebarVisible: true))
    }

    @Test func `i pad split prefers integrated visible sidebar`() {
        #expect(RootTabs.preferredSidebarVisibility(layoutMode: .split))
        #expect(!RootTabs.shouldCollapseSidebarAfterSelection(layoutMode: .split))
        #expect(!RootTabs.preferredSidebarVisibility(layoutMode: .drawer))
        #expect(RootTabs.shouldCollapseSidebarAfterSelection(layoutMode: .drawer))
    }

    @Test func `destination headers own hidden sidebar reveal control`() {
        #expect(
            RootTabs.shouldShowSidebarRevealInDestinationHeader(
                isSidebarVisible: false,
                layoutMode: .drawer))
        #expect(
            RootTabs.shouldShowSidebarRevealInDestinationHeader(
                isSidebarVisible: false,
                layoutMode: .split))
        #expect(
            !RootTabs.shouldShowSidebarRevealInDestinationHeader(
                isSidebarVisible: true,
                layoutMode: .drawer))
        #expect(
            RootTabs.shouldShowSidebarRevealInDestinationHeader(
                isSidebarVisible: true,
                layoutMode: .split))
    }

    @Test func `workboard and skill workshop use compact task flow on phone sizes`() {
        #expect(
            IPadWorkboardScreen.usesCompactTaskFlow(
                horizontalSizeClass: .compact,
                verticalSizeClass: .regular))
        #expect(
            IPadSkillWorkshopScreen.usesCompactTaskFlow(
                horizontalSizeClass: .compact,
                verticalSizeClass: .regular))
        #expect(
            IPadWorkboardScreen.usesCompactTaskFlow(
                horizontalSizeClass: .regular,
                verticalSizeClass: .compact))
        #expect(
            IPadSkillWorkshopScreen.usesCompactTaskFlow(
                horizontalSizeClass: .regular,
                verticalSizeClass: .compact))
    }

    @Test func `workboard and skill workshop keep regular task flow on wide I pad sizes`() {
        #expect(
            !IPadWorkboardScreen.usesCompactTaskFlow(
                horizontalSizeClass: .regular,
                verticalSizeClass: .regular))
        #expect(
            !IPadSkillWorkshopScreen.usesCompactTaskFlow(
                horizontalSizeClass: .regular,
                verticalSizeClass: .regular))
    }

    @Test func `phone hub leaves room for floating tab bar`() {
        #expect(RootTabsPhoneControlHub.bottomScrollInset(verticalSizeClass: .regular) == 112)
        #expect(RootTabsPhoneControlHub.bottomScrollInset(verticalSizeClass: .compact) == 72)
    }

    private static func rotatedCertificateProblem() -> GatewayConnectionProblem {
        GatewayConnectionProblem(
            kind: .tlsPinMismatch,
            owner: .iphone,
            title: "Gateway certificate changed",
            message: "The gateway certificate fingerprint changed.",
            retryable: false,
            pauseReconnect: true,
            tlsStoreKey: "gateway-1",
            tlsExpectedFingerprint: "old",
            tlsObservedFingerprint: "new",
            tlsSystemTrustOk: true)
    }

    private static func protocolMismatchProblem() -> GatewayConnectionProblem {
        GatewayConnectionProblem(
            kind: .protocolMismatch,
            owner: .iphone,
            title: "App update required",
            message: "This app is older than the gateway.",
            actionLabel: "Update app",
            retryable: false,
            pauseReconnect: true)
    }

    private static func retryableGatewayProblem() -> GatewayConnectionProblem {
        GatewayConnectionProblem(
            kind: .timeout,
            owner: .network,
            title: "Connection timed out",
            message: "Check the gateway network path.",
            actionLabel: "Try again",
            retryable: true,
            pauseReconnect: false)
    }

    private static func nonRetryableGatewayProblem() -> GatewayConnectionProblem {
        GatewayConnectionProblem(
            kind: .pairingRequired,
            owner: .gateway,
            title: "Gateway setup required",
            message: "Open settings to review gateway configuration.",
            retryable: false,
            pauseReconnect: true)
    }

    private static func startupSnapshot(
        gatewayConnected: Bool,
        hasConnectedOnce: Bool,
        onboardingComplete: Bool,
        hasExistingGatewayConfig: Bool,
        shouldPresentOnLaunch: Bool = false)
        -> RootPresentationFeature.StartupSnapshot
    {
        RootPresentationFeature.StartupSnapshot(
            gatewayConnected: gatewayConnected,
            hasConnectedOnce: hasConnectedOnce,
            onboardingComplete: onboardingComplete,
            hasExistingGatewayConfig: hasExistingGatewayConfig,
            shouldPresentOnLaunch: shouldPresentOnLaunch)
    }

    private static func startupSnapshotChange(
        gatewayConnected: Bool,
        hasConnectedOnce: Bool,
        onboardingComplete: Bool,
        hasExistingGatewayConfig: Bool,
        shouldPresentOnLaunch: Bool = false)
        -> RootPresentationFeature.StartupSnapshotChange
    {
        RootPresentationFeature.StartupSnapshotChange(snapshot: Self.startupSnapshot(
            gatewayConnected: gatewayConnected,
            hasConnectedOnce: hasConnectedOnce,
            onboardingComplete: onboardingComplete,
            hasExistingGatewayConfig: hasExistingGatewayConfig,
            shouldPresentOnLaunch: shouldPresentOnLaunch))
    }

    private static func startupPresentationEvaluationRequest(
        gatewayConnected: Bool,
        hasConnectedOnce: Bool,
        onboardingComplete: Bool,
        hasExistingGatewayConfig: Bool,
        shouldPresentOnLaunch: Bool = false)
        -> RootPresentationFeature.StartupPresentationEvaluationRequest
    {
        RootPresentationFeature.StartupPresentationEvaluationRequest(snapshot: Self.startupSnapshot(
            gatewayConnected: gatewayConnected,
            hasConnectedOnce: hasConnectedOnce,
            onboardingComplete: onboardingComplete,
            hasExistingGatewayConfig: hasExistingGatewayConfig,
            shouldPresentOnLaunch: shouldPresentOnLaunch))
    }

    private static func autoOpenSettingsRequest(
        gatewayConnected: Bool,
        hasConnectedOnce: Bool,
        onboardingComplete: Bool,
        hasExistingGatewayConfig: Bool,
        shouldPresentOnLaunch: Bool = false)
        -> RootPresentationFeature.AutoOpenSettingsRequest
    {
        RootPresentationFeature.AutoOpenSettingsRequest(snapshot: Self.startupSnapshot(
            gatewayConnected: gatewayConnected,
            hasConnectedOnce: hasConnectedOnce,
            onboardingComplete: onboardingComplete,
            hasExistingGatewayConfig: hasExistingGatewayConfig,
            shouldPresentOnLaunch: shouldPresentOnLaunch))
    }

    private static func quickSetupSnapshotChange(
        quickSetupDismissed: Bool,
        showOnboarding: Bool,
        gatewayConnected: Bool,
        hasExistingGatewayConfig: Bool,
        discoveredGatewayCount: Int)
        -> RootPresentationFeature.QuickSetupSnapshotChange
    {
        RootPresentationFeature.QuickSetupSnapshotChange(snapshot: RootPresentationFeature.QuickSetupSnapshot(
            quickSetupDismissed: quickSetupDismissed,
            showOnboarding: showOnboarding,
            gatewayConnected: gatewayConnected,
            hasExistingGatewayConfig: hasExistingGatewayConfig,
            discoveredGatewayCount: discoveredGatewayCount))
    }

    private static func localNetworkAccessRequest(
        reason: String,
        sceneActive: Bool)
        -> RootPresentationFeature.LocalNetworkAccessRequest
    {
        RootPresentationFeature.LocalNetworkAccessRequest(
            reason: reason,
            sceneActive: sceneActive)
    }

    private static func gatewaySetupRequest(requestID: Int) -> RootPresentationFeature.GatewaySetupRequest {
        RootPresentationFeature.GatewaySetupRequest(requestID: requestID)
    }

    private static func sidebarGatewayStatusChange(
        _ status: GatewayDisplayState)
        -> RootPresentationFeature.SidebarGatewayStatusChange
    {
        RootPresentationFeature.SidebarGatewayStatusChange(status: status)
    }

    private static func presentedSheetChange(
        _ sheet: RootPresentationFeature.PresentedSheet?)
        -> RootPresentationFeature.PresentedSheetChange
    {
        RootPresentationFeature.PresentedSheetChange(sheet: sheet)
    }

    private static func sidebarLayoutModeResolution(
        _ layoutMode: RootTabs.SidebarLayoutMode,
        force: Bool)
        -> RootSidebarFeature.LayoutModeResolution
    {
        RootSidebarFeature.LayoutModeResolution(
            layoutMode: layoutMode,
            force: force)
    }

    private static func sidebarVisibilityChange(isVisible: Bool) -> RootSidebarFeature.VisibilityChange {
        RootSidebarFeature.VisibilityChange(isVisible: isVisible)
    }

    private static func tabSelection(_ tab: RootTabs.AppTab) -> RootNavigationSelectionFeature.TabSelection {
        RootNavigationSelectionFeature.TabSelection(tab: tab)
    }

    private static func sidebarDestinationSelection(
        _ destination: RootTabs.SidebarDestination)
        -> RootNavigationSelectionFeature.SidebarDestinationSelection
    {
        RootNavigationSelectionFeature.SidebarDestinationSelection(destination: destination)
    }

    private static func settingsRouteSelection(
        _ route: SettingsRoute)
        -> RootNavigationSelectionFeature.SettingsRouteSelection
    {
        RootNavigationSelectionFeature.SettingsRouteSelection(route: route)
    }

    private static func notificationPermissionSettingsRequest(
        suppressedApprovalID: String)
        -> RootNavigationSelectionFeature.NotificationPermissionSettingsRequest
    {
        RootNavigationSelectionFeature.NotificationPermissionSettingsRequest(
            suppressedApprovalID: suppressedApprovalID)
    }

    private static func pendingExecApprovalPromptChange(
        promptID: String?)
        -> RootNavigationSelectionFeature.PendingExecApprovalPromptChange
    {
        RootNavigationSelectionFeature.PendingExecApprovalPromptChange(promptID: promptID)
    }

    private static func sidebarNavigationPathChange(
        _ path: [SettingsRoute])
        -> RootNavigationSelectionFeature.SidebarNavigationPathChange
    {
        RootNavigationSelectionFeature.SidebarNavigationPathChange(path: path)
    }

    private static func sidebarSettingsRoutePush(
        _ route: SettingsRoute)
        -> RootNavigationSelectionFeature.SidebarSettingsRoutePush
    {
        RootNavigationSelectionFeature.SidebarSettingsRoutePush(route: route)
    }

    private static func settingsRouteChange(
        _ route: SettingsRoute?)
        -> RootNavigationSelectionFeature.SettingsRouteChange
    {
        RootNavigationSelectionFeature.SettingsRouteChange(route: route)
    }

    private static func onboardingVisibilityChange(
        isPresented: Bool,
        sceneActive: Bool)
        -> RootPresentationFeature.OnboardingVisibilityChange
    {
        RootPresentationFeature.OnboardingVisibilityChange(
            isPresented: isPresented,
            sceneActive: sceneActive)
    }
}

private final class RootCanvasPresentationProbe: @unchecked Sendable {
    var hideCount = 0

    var client: RootCanvasPresentationClient {
        RootCanvasPresentationClient(hideCanvas: {
            self.hideCount += 1
        })
    }
}

private final class RootCanvasDebugStatusProbe: @unchecked Sendable {
    var enabledValues: [Bool] = []
    var titles: [String?] = []
    var subtitles: [String?] = []

    var client: RootCanvasDebugStatusClient {
        RootCanvasDebugStatusClient(
            setDebugStatusEnabled: { enabled in
                self.enabledValues.append(enabled)
            },
            updateDebugStatus: { title, subtitle in
                self.titles.append(title)
                self.subtitles.append(subtitle)
            })
    }
}

private final class RootIdleTimerProbe: @unchecked Sendable {
    var disabledValues: [Bool] = []

    var client: RootIdleTimerClient {
        RootIdleTimerClient(setIdleTimerDisabled: { disabled in
            self.disabledValues.append(disabled)
        })
    }
}

private final class RootGatewayOverviewRefreshProbe: @unchecked Sendable {
    var refreshCount = 0

    var client: RootGatewayOverviewRefreshClient {
        RootGatewayOverviewRefreshClient(refreshGatewayOverviewIfConnected: {
            self.refreshCount += 1
        })
    }
}

private final class RootGatewayProblemPrimaryActionProbe: @unchecked Sendable {
    var openedProblems: [GatewayConnectionProblem] = []
    var openSettingsCount = 0
    var reconnectCount = 0
    var trustedProblems: [GatewayConnectionProblem] = []

    var client: RootGatewayProblemPrimaryActionClient {
        RootGatewayProblemPrimaryActionClient(
            connectLastKnown: {
                self.reconnectCount += 1
            },
            openGatewaySettings: {
                self.openSettingsCount += 1
            },
            openProtocolMismatchHelpIfNeeded: { problem in
                self.openedProblems.append(problem)
                return true
            },
            trustRotatedCertificate: { problem in
                self.trustedProblems.append(problem)
                return true
            })
    }
}
