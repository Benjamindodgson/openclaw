import ComposableArchitecture
import OpenClawKit
import SwiftUI
import UIKit
import UserNotifications

extension SettingsProTab {
    func detailStatusCard(
        icon: String,
        title: String,
        detail: String,
        value: String,
        color: Color) -> some View
    {
        ProCard(radius: SettingsLayout.cardRadius) {
            HStack(spacing: 12) {
                ProIconBadge(systemName: icon, color: color)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                ProValuePill(value: value, color: color)
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    var diagnosticChecksCard: some View {
        ProCard(padding: 0, radius: SettingsLayout.cardRadius) {
            VStack(spacing: 0) {
                self.diagnosticCheckRow(
                    icon: "stethoscope",
                    title: "Last Run",
                    detail: self.diagnosticsStore.lastRunText,
                    value: self.diagnosticsRunValue,
                    color: self.diagnosticsRunColor)
                Divider().padding(.leading, 60)
                self.diagnosticCheckRow(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "Gateway Link",
                    detail: self.gatewayStatusDetail,
                    value: self.gatewayStatusValue,
                    color: self.gatewayStatusColor)
                Divider().padding(.leading, 60)
                self.diagnosticCheckRow(
                    icon: "dot.radiowaves.left.and.right",
                    title: "Discovery",
                    detail: self.diagnosticsStore.discoveryStatusText,
                    value: self.diagnosticsStore.discoveryValue,
                    color: self.diagnosticsStore.discoveryColor)
                Divider().padding(.leading, 60)
                self.diagnosticCheckRow(
                    icon: "waveform",
                    title: "Talk Config",
                    detail: self.gatewayTalkConfigDetail,
                    value: self.gatewayTalkConfigValue,
                    color: self.gatewayTalkConfigColor)
                Divider().padding(.leading, 60)
                self.diagnosticCheckRow(
                    icon: "bell",
                    title: "Notifications",
                    detail: "Approval and event alert channel",
                    value: self.notificationStatusText,
                    color: self.notificationStatusColor)
                Divider().padding(.leading, 60)
                self.diagnosticCheckRow(
                    icon: "rectangle.on.rectangle",
                    title: "Screen Capture",
                    detail: "Live foreground capture state",
                    value: self.diagnosticsStore.screenCaptureValue,
                    color: self.diagnosticsStore.screenCaptureColor)
                Divider().padding(.leading, 60)
                self.diagnosticCheckRow(
                    icon: "mic",
                    title: "Voice Wake",
                    detail: self.voiceControlStore.voiceWakeStatusText,
                    value: self.voiceControlStore.voiceWakeValue,
                    color: self.voiceControlStore.voiceWakeColor)
            }
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    func diagnosticCheckRow(
        icon: String,
        title: String,
        detail: String,
        value: String,
        color: Color) -> some View
    {
        HStack(spacing: 12) {
            ProIconBadge(systemName: icon, color: color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            ProValuePill(value: value, color: color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    func detailListCard(@ViewBuilder content: () -> some View) -> some View {
        ProCard(padding: 0, radius: SettingsLayout.cardRadius) {
            VStack(spacing: 0, content: content)
        }
        .padding(.horizontal, OpenClawProMetric.pagePadding)
    }

    func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
    }

    func reconnectGateway() async {
        guard !self.appModel.isAppleReviewDemoModeEnabled else { return }
        guard !self.gatewayActivityStore.isReconnectingGateway else { return }
        self.gatewayActivityStore.send(.reconnectStarted)
        defer { self.gatewayActivityStore.send(.reconnectFinished) }
        await self.gatewayController.connectLastKnown()
    }

    @MainActor
    func runDiagnostics() async {
        guard !self.gatewayActivityStore.isRefreshingGateway else { return }
        self.gatewayActivityStore.send(.refreshStarted)
        defer { self.gatewayActivityStore.send(.refreshFinished) }

        if !self.appModel.isAppleReviewDemoModeEnabled {
            self.gatewayController.refreshActiveGatewayRegistrationFromSettings()
            self.gatewayController.restartDiscovery()
            await self.appModel.refreshGatewayOverviewIfConnected()
        }
        self.syncGatewayConnectionStatusState()
        self.syncDiagnosticsContextState()
        let notificationSettings = await UNUserNotificationCenter.current().notificationSettings()
        self.applyNotificationStatus(notificationSettings.authorizationStatus)
        self.registerForRemoteNotificationsIfEnrollmentReady()

        let issueCount = SettingsDiagnostics.issueCount(
            gatewayConnected: self.gatewayDiagnosticConnected,
            discoveredGatewayCount: self.gatewayController.gateways.count,
            talkConfigLoaded: self.gatewayDiagnosticTalkConfigLoaded,
            notificationsAllowed: self.notificationStore.status == .allowed)
        self.diagnosticsStore.send(.diagnosticsCompleted(
            issueCount: issueCount,
            lastRunText: SettingsDiagnostics.timestamp(Date())))
    }

    func syncSettingsState() {
        self.pushEnrollmentConsentStore.send(.refresh)
        self.appearanceStore.send(.appearancePreferenceSynced(self.storedAppearancePreferenceRaw))
        self.deviceIdentityStore.send(.displayNameSynced(self.storedDisplayName))
        self.deviceIdentityStore.send(.instanceIdSynced(self.storedInstanceId))
        self.debugOptionsStore.send(.debugOptionsSynced(
            discoveryDebugLogsEnabled: self.storedDiscoveryDebugLogsEnabled,
            canvasDebugStatusEnabled: self.storedCanvasDebugStatusEnabled))
        self.syncGatewaySetupStatusContext()
        self.syncGatewayConnectionStatusState()
        self.syncDiagnosticsContextState()
        self.gatewaySetupLinkStore.send(.setupCodeSynced(self.storedSetupCode))
        self.syncOnboardingState()
        self.deviceCapabilityStore.send(.capabilitiesSynced(
            cameraEnabled: self.storedCameraEnabled,
            preventSleep: self.storedPreventSleep,
            locationModeRaw: self.storedLocationModeRaw))
        self.syncVoiceControlState()
        self.syncTalkPreferencesState()
        self.syncTalkRuntimeState()
        self.locationStore.send(.locationModeSynced(self.storedLocationModeRaw))
        self.syncNotificationRelayState()
        self.gatewayAutoConnectStore.send(.enabledSynced(self.storedGatewayAutoConnect))
        self.manualGatewayEndpointStore.send(.endpointSynced(
            enabled: self.storedManualGatewayEnabled,
            host: self.storedManualGatewayHost,
            tls: self.storedManualGatewayTLS))
        self.manualGatewayPortStore.send(.manualGatewayPortSynced(self.storedManualGatewayPort))
        self.agentSelectionStore.send(.selectedAgentSynced(self.appModel.selectedAgentId))
        self.shareInstructionStore.send(
            .defaultShareInstructionLoaded(ShareToAgentSettings.loadDefaultInstruction()))
        let trimmedInstanceId = self.instanceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInstanceId.isEmpty else { return }
        self.gatewayCredentialsStore.send(.credentialsLoaded(
            token: GatewaySettingsStore.loadGatewayToken(instanceId: trimmedInstanceId) ?? "",
            password: GatewaySettingsStore.loadGatewayPassword(instanceId: trimmedInstanceId) ?? ""))
    }

    func syncVoiceControlState() {
        self.voiceControlStore.send(.controlsSynced(
            talkEnabled: self.storedTalkEnabled,
            voiceWakeEnabled: self.storedVoiceWakeEnabled,
            voiceWakeStatusText: self.appModel.voiceWake.statusText))
    }

    func syncTalkPreferencesState() {
        self.talkPreferencesStore.send(.preferencesSynced(
            providerSelectionRaw: self.storedTalkProviderSelectionRaw,
            realtimeVoiceSelectionRaw: self.storedTalkRealtimeVoiceSelectionRaw,
            speechLocale: self.storedTalkSpeechLocale,
            talkButtonEnabled: self.storedTalkButtonEnabled,
            talkBackgroundEnabled: self.storedTalkBackgroundEnabled,
            talkSpeakerphoneEnabled: self.storedTalkSpeakerphoneEnabled))
    }

    func syncTalkRuntimeState() {
        self.talkPreferencesStore.send(.gatewayTalkConfigSynced(
            configLoaded: self.appModel.talkMode.gatewayTalkConfigLoaded,
            apiKeyConfigured: self.appModel.talkMode.gatewayTalkApiKeyConfigured,
            usesRealtime: self.appModel.talkMode.gatewayTalkUsesRealtime))
        self.talkPreferencesStore.send(.gatewayTalkDisplayContextSynced(
            isAppleReviewDemoModeEnabled: self.appModel.isAppleReviewDemoModeEnabled,
            transportLabel: self.appModel.talkMode.gatewayTalkTransportLabel))
        self.talkPreferencesStore.send(.gatewayTalkRuntimeSynced(
            activeModeTitle: self.appModel.talkMode.gatewayTalkActiveModeTitle,
            activeModeSubtitle: self.appModel.talkMode.gatewayTalkActiveModeSubtitle,
            lastIssueText: self.appModel.talkMode.gatewayTalkLastIssueText))
    }

    func syncDiagnosticsContextState() {
        self.diagnosticsStore.send(.diagnosticsContextSynced(
            isAppleReviewDemoModeEnabled: self.appModel.isAppleReviewDemoModeEnabled,
            gatewayConnected: self.gatewayConnected,
            discoveredGatewayCount: self.gatewayController.gateways.count,
            discoveryStatusText: self.gatewayController.discoveryStatusText,
            screenRecordActive: self.appModel.screenRecordActive))
    }

    func syncApprovalState() {
        let pendingApproval = self.appModel.pendingExecApprovalPrompt
        self.approvalsStore.send(.approvalsSynced(
            isAppleReviewDemoModeEnabled: self.appModel.isAppleReviewDemoModeEnabled,
            gatewayConnected: self.gatewayConnected,
            notificationsNeedAttention: self.notificationStore.needsAttention,
            hasPendingApproval: pendingApproval != nil,
            pendingCommandPreview: pendingApproval?.commandPreview,
            activeAgentName: self.appModel.activeAgentName,
            isResolvingPendingApproval: self.appModel.pendingExecApprovalPromptResolving,
            pendingApprovalAllowsAllowAlways: pendingApproval?.allowsAllowAlways ?? false))
    }

    func syncNotificationRelayState() {
        let config = PushBuildConfig.current
        let host = config.relayBaseURL.flatMap {
            URLComponents(url: $0, resolvingAgainstBaseURL: false)?.host
        }
        self.notificationStore.send(.relayConfigSynced(
            usesOpenClawHostedRelay: config.usesOpenClawHostedRelay,
            hostedRelayHost: host))
    }

    func syncOnboardingState() {
        self.onboardingStateStore.send(.onboardingStateSynced(
            hasConnectedOnce: self.storedHasConnectedOnce,
            onboardingComplete: self.storedOnboardingComplete,
            onboardingRequestID: self.storedOnboardingRequestID))
    }

    func syncGatewaySetupStatusContext() {
        self.gatewaySetupStatusStore.send(.gatewayStatusSynced(
            problemMessage: self.appModel.lastGatewayProblem?.message,
            gatewayStatusText: self.appModel.gatewayStatusText))
    }

    func syncGatewayConnectionStatusState() {
        self.gatewayConnectionStore.send(.gatewayStatusSynced(
            isAppleReviewDemoModeEnabled: self.appModel.isAppleReviewDemoModeEnabled,
            gatewayStatusConnected: GatewayStatusBuilder.build(appModel: self.appModel) == .connected,
            gatewayDisplayStatusText: self.appModel.gatewayDisplayStatusText,
            gatewayAgentCount: self.appModel.gatewayAgents.count,
            gatewayRemoteAddress: self.appModel.gatewayRemoteAddress,
            gatewayServerName: self.appModel.gatewayServerName))
        self.syncApprovalState()
    }

    func connect(_ gateway: GatewayDiscoveryModel.DiscoveredGateway) async {
        self.gatewayConnectionStore.send(.connectionStarted(gateway.id))
        defer { self.gatewayConnectionStore.send(.connectionFinished) }
        self.updateManualGatewayEnabled(false)
        GatewaySettingsStore.savePreferredGatewayStableID(gateway.stableID)
        GatewaySettingsStore.saveLastDiscoveredGatewayStableID(gateway.stableID)
        if let err = await self.gatewayController.connectWithDiagnostics(gateway) {
            self.gatewaySetupStatusStore.send(.statusChanged(err))
        }
    }

    func applySetupCodeAndConnect() async {
        self.gatewaySetupStatusStore.send(.statusChanged(nil))
        guard self.applySetupCode() else { return }
        let host = self.manualGatewayHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard self.resolvedManualPort(host: host) != nil else {
            self.gatewaySetupStatusStore.send(.statusChanged("Failed: invalid port"))
            return
        }
        guard await self.preflightGateway(host: host) else { return }
        self.gatewaySetupStatusStore.send(.statusChanged("Setup code applied. Connecting..."))
        await self.connectManual()
    }

    func applyPendingGatewaySetupLinkIfNeeded() {
        guard let link = self.appModel.consumePendingGatewaySetupLink() else { return }
        self.updateSetupCode("")
        self.gatewaySetupStatusStore.send(.statusChanged(nil))
        self.gatewaySetupLinkStore.send(.setupLinkStaged(link))
        let security = link.tls ? "TLS" : "plain"
        self.gatewaySetupStatusStore.send(
            .statusChanged("Setup link loaded for \(link.host):\(link.port) (\(security)). Tap Connect to apply."))
    }

    @discardableResult
    func applySetupCode() -> Bool {
        self.gatewaySetupLinkStore.send(.applyRequested)
        guard let result = self.gatewaySetupLinkStore.applyResult else { return false }
        self.gatewaySetupLinkStore.send(.applyResultHandled)

        switch result {
        case .appleReviewDemo:
            self.updateSetupCode("")
            self.gatewaySetupStatusStore.send(.statusChanged("Apple Review demo mode enabled."))
            self.appModel.enterAppleReviewDemoMode()
            return false

        case let .failure(message):
            self.gatewaySetupStatusStore.send(.statusChanged(message))
            return false

        case let .gatewayLink(link):
            self.applyGatewayLink(link)
            return true
        }
    }

    func applyGatewayLink(_ link: GatewayConnectDeepLink) {
        self.applyManualGatewaySetupLink(host: link.host, tls: link.tls)
        self.manualGatewayPortStore.send(.manualGatewayPortSynced(link.port))
        let instanceId = GatewaySettingsStore.currentInstanceID()
        let setupAuth = GatewayConnectionController.ManualAuthOverride.setupAuth(from: link)
        if setupAuth.hasBootstrapToken {
            GatewayOnboardingReset.prepareForBootstrapPairing(appModel: self.appModel, instanceId: instanceId)
        }
        if !instanceId.isEmpty {
            GatewaySettingsStore.saveGatewayBootstrapToken(setupAuth.bootstrapToken, instanceId: instanceId)
        }
        if setupAuth.shouldApplyTokenField {
            if !instanceId.isEmpty {
                GatewaySettingsStore.saveGatewayToken(setupAuth.token, instanceId: instanceId)
            }
        }
        if setupAuth.shouldApplyPasswordField {
            if !instanceId.isEmpty {
                GatewaySettingsStore.saveGatewayPassword(setupAuth.password, instanceId: instanceId)
            }
        }
        self.gatewayCredentialsStore.send(.setupAuthApplied(setupAuth))
    }

    func openGatewayQRScanner() {
        self.appModel.disconnectGateway()
        self.gatewayConnectionStore.send(.connectionFinished)
        self.gatewaySetupStatusStore.send(.statusChanged("Opening QR scanner..."))
        self.presentationStore.send(.qrScannerButtonTapped)
    }

    func handleScannedGatewayLink(_ link: GatewayConnectDeepLink) {
        self.gatewaySetupLinkStore.send(.scannedGatewayLinkReceived(link))
        guard case let .gatewayLink(scannedLink)? = self.gatewaySetupLinkStore.applyResult else { return }
        self.gatewaySetupLinkStore.send(.applyResultHandled)
        self.presentationStore.send(.qrScannerDismissed)
        self.updateSetupCode("")
        self.applyGatewayLink(scannedLink)
        self.gatewaySetupStatusStore
            .send(.statusChanged("QR loaded. Connecting to \(scannedLink.host):\(scannedLink.port)..."))
        Task { await self.connectAfterScannedGatewayLink() }
    }

    func handleScannedSetupCode(_ code: String) {
        self.gatewaySetupLinkStore.send(.scannedSetupCodeReceived(code))
        guard self.gatewaySetupLinkStore.applyResult == .appleReviewDemo else { return }
        self.gatewaySetupLinkStore.send(.applyResultHandled)
        self.presentationStore.send(.qrScannerDismissed)
        self.updateSetupCode("")
        self.gatewaySetupStatusStore.send(.statusChanged("Apple Review demo mode enabled."))
        self.appModel.enterAppleReviewDemoMode()
    }

    func connectAfterScannedGatewayLink() async {
        let host = self.manualGatewayHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard self.resolvedManualPort(host: host) != nil else {
            self.gatewaySetupStatusStore.send(.statusChanged("Failed: invalid port"))
            return
        }
        guard await self.preflightGateway(host: host) else { return }
        await self.connectManual()
    }

    func connectManual() async {
        self.manualGatewayEndpointStore.send(.manualConnectionRequested(
            port: self.manualGatewayPortStore.manualGatewayPort,
            isPortValid: self.manualPortIsValid))
        guard let result = self.manualGatewayEndpointStore.manualConnectionResult else { return }
        self.manualGatewayEndpointStore.send(.manualConnectionResultHandled)

        switch result {
        case let .failure(message):
            self.gatewaySetupStatusStore.send(.statusChanged(message))

        case let .request(request):
            self.gatewayConnectionStore.send(.connectionStarted("manual"))
            self.updateManualGatewayEnabled(true)
            defer { self.gatewayConnectionStore.send(.connectionFinished) }
            let authOverride = GatewayConnectionController.ManualAuthOverride.currentManualInput(
                token: self.gatewayCredentialsStore.gatewayToken,
                pendingOverride: self.gatewayCredentialsStore.pendingManualAuthOverride,
                password: self.gatewayCredentialsStore.gatewayPassword)
            self.gatewayCredentialsStore.send(.pendingManualAuthOverrideConsumed)
            await self.gatewayController.connectManual(
                host: request.host,
                port: request.port,
                useTLS: request.useTLS,
                authOverride: authOverride)
        }
    }

    func preflightGateway(host: String) async -> Bool {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if SettingsManualGatewayEndpointFeature.State.isTailnetHostOrIP(trimmed), !Self.hasTailnetIPv4() {
            self.gatewaySetupStatusStore.send(
                .statusChanged("Tailscale is off on this device. Turn it on, then try again."))
            return false
        }
        self.gatewayController.requestLocalNetworkAccess(reason: "settings_preflight")
        return true
    }

    func resetOnboarding() {
        self.gatewayConnectionStore.send(.connectionFinished)
        self.gatewaySetupStatusStore.send(.statusChanged(nil))
        self.updateSetupCode("")
        self.disableGatewayAutoConnectForOnboardingReset()
        self.gatewayCredentialsStore.send(.credentialsClearedForOnboardingReset)
        GatewayOnboardingReset.reset(appModel: self.appModel, instanceId: self.instanceId)
        self.resetOnboardingCompletionState()
        self.clearManualGatewayEndpointForOnboardingReset()
        self.advanceOnboardingRequestID()
    }

    func retryGatewayConnectionFromProblem() async {
        if self.manualGatewayEnabled || self.connectingGatewayID == "manual" {
            await self.connectManual()
        } else {
            await self.gatewayController.connectLastKnown()
        }
    }

    func gatewayProblemPrimaryActionTitle(_ problem: GatewayConnectionProblem) -> String? {
        GatewayProblemPrimaryAction.title(
            for: problem,
            retryTitle: "Retry connection",
            resetTitle: "Reset onboarding")
    }

    func handleGatewayProblemPrimaryAction(_ problem: GatewayConnectionProblem) async {
        if problem.suggestsOnboardingReset {
            self.resetOnboarding()
            return
        }
        if problem.canTrustRotatedCertificate {
            _ = await self.gatewayController.trustRotatedGatewayCertificate(from: problem)
            return
        }
        if GatewayProblemPrimaryAction.openProtocolMismatchHelpIfNeeded(problem) {
            return
        }
        guard problem.retryable else { return }
        await self.retryGatewayConnectionFromProblem()
    }

    func handleLocationModeChange(_ newValue: String) {
        guard !self.locationStore.isChangingLocationMode else { return }
        guard newValue != self.locationStore.previousLocationModeRaw else { return }
        guard let mode = OpenClawLocationMode(rawValue: newValue) else { return }
        let previous = self.locationStore.previousLocationModeRaw
        Task {
            await self.applyLocationMode(mode, rawValue: newValue, previous: previous)
        }
    }

    @MainActor
    func applyLocationMode(
        _ mode: OpenClawLocationMode,
        rawValue: String,
        previous: String) async
    {
        self.locationStore.send(.locationChangeStarted)
        defer { self.locationStore.send(.locationChangeFinished) }

        if mode == .off {
            self.locationStore.send(.locationModeApplied(rawValue))
            self.gatewayController.refreshActiveGatewayRegistrationFromSettings()
            return
        }

        let granted = await self.appModel.requestLocationPermissions(mode: mode)
        if granted {
            self.locationStore.send(.locationModeApplied(rawValue))
            self.gatewayController.refreshActiveGatewayRegistrationFromSettings()
        } else {
            self.storedLocationModeRaw = previous
            self.locationStore.send(.locationPermissionDenied(previousRawValue: previous))
        }
    }

    func refreshNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = settings.authorizationStatus
            Task { @MainActor in
                self.applyNotificationStatus(status)
                self.registerForRemoteNotificationsIfEnrollmentReady()
            }
        }
    }

    func handleNotificationAction() {
        if self.notificationStore.status.shouldOpenNotificationSettings {
            self.openNotificationSettings()
            return
        }
        guard self.notificationStore.status == .notSet else { return }

        if PushBuildConfig.current.usesOpenClawHostedRelay {
            self.presentationStore.send(.notificationRelayDisclosureRequested)
            return
        }
        self.requestNotificationAuthorizationFromSettings()
    }

    func requestNotificationAuthorizationFromSettings() {
        guard !self.notificationStore.isRequestingAuthorization else { return }
        self.pushEnrollmentConsentStore.send(.acceptDisclosure)
        self.notificationStore.send(.authorizationRequestStarted)
        Task {
            let granted = await (try? UNUserNotificationCenter.current().requestAuthorization(options: [
                .alert,
                .badge,
                .sound,
            ])) ?? false
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run {
                self.notificationStore.send(.authorizationRequestFinished(
                    SettingsNotificationStatus(settings.authorizationStatus)))
                self.syncApprovalState()
                guard granted else { return }
                self.registerForRemoteNotificationsIfEnrollmentReady()
            }
        }
    }

    @MainActor
    func registerForRemoteNotificationsIfEnrollmentReady() {
        guard self.pushEnrollmentConsentStore.disclosureAccepted else { return }
        guard self.notificationStore.status.allowsNotifications else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    @MainActor
    func applyNotificationStatus(_ status: UNAuthorizationStatus) {
        self.notificationStore.send(.statusChanged(SettingsNotificationStatus(status)))
        self.syncApprovalState()
    }

    func persistGatewayToken(_ value: String) {
        let instanceId = self.instanceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instanceId.isEmpty else { return }
        GatewaySettingsStore.saveGatewayToken(
            value.trimmingCharacters(in: .whitespacesAndNewlines),
            instanceId: instanceId)
    }

    func persistGatewayPassword(_ value: String) {
        let instanceId = self.instanceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instanceId.isEmpty else { return }
        GatewaySettingsStore.saveGatewayPassword(
            value.trimmingCharacters(in: .whitespacesAndNewlines),
            instanceId: instanceId)
    }

    func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    var manualPortBinding: Binding<String> {
        Binding(
            get: { self.manualGatewayPortStore.manualGatewayPortText },
            set: { self.manualGatewayPortStore.send(.manualGatewayPortTextChanged($0)) })
    }

    var gatewayAutoConnectBinding: Binding<Bool> {
        Binding(
            get: { self.gatewayAutoConnectStore.isEnabled },
            set: { self.updateGatewayAutoConnect($0) })
    }

    var cameraEnabled: Bool {
        self.deviceCapabilityStore.cameraEnabled
    }

    var preventSleep: Bool {
        self.deviceCapabilityStore.preventSleep
    }

    var talkEnabled: Bool {
        self.voiceControlStore.talkEnabled
    }

    var voiceWakeEnabled: Bool {
        self.voiceControlStore.voiceWakeEnabled
    }

    var cameraEnabledBinding: Binding<Bool> {
        Binding(
            get: { self.deviceCapabilityStore.cameraEnabled },
            set: { self.updateCameraEnabled($0) })
    }

    var preventSleepBinding: Binding<Bool> {
        Binding(
            get: { self.deviceCapabilityStore.preventSleep },
            set: { self.updatePreventSleep($0) })
    }

    func updateCameraEnabled(_ enabled: Bool) {
        self.deviceCapabilityStore.send(.cameraEnabledChanged(enabled))
        self.storedCameraEnabled = enabled
    }

    func updatePreventSleep(_ enabled: Bool) {
        self.deviceCapabilityStore.send(.preventSleepChanged(enabled))
        self.storedPreventSleep = enabled
    }

    var talkEnabledBinding: Binding<Bool> {
        Binding(
            get: { self.voiceControlStore.talkEnabled },
            set: { self.updateTalkEnabled($0) })
    }

    var voiceWakeEnabledBinding: Binding<Bool> {
        Binding(
            get: { self.voiceControlStore.voiceWakeEnabled },
            set: { self.updateVoiceWakeEnabled($0) })
    }

    func updateTalkEnabled(_ enabled: Bool) {
        self.voiceControlStore.send(.talkEnabledChangeRequested(
            enabled: enabled,
            isAppleReviewDemoModeEnabled: self.appModel.isAppleReviewDemoModeEnabled))
        self.storedTalkEnabled = self.voiceControlStore.talkEnabled
        self.appModel.setTalkEnabled(self.voiceControlStore.talkEnabled)
    }

    func updateVoiceWakeEnabled(_ enabled: Bool) {
        self.voiceControlStore.send(.voiceWakeEnabledChanged(enabled))
        self.storedVoiceWakeEnabled = enabled
        self.appModel.setVoiceWakeEnabled(enabled)
    }

    var appearancePreferenceBinding: Binding<String> {
        Binding(
            get: { self.appearanceStore.appearancePreferenceRaw },
            set: { self.updateAppearancePreferenceRaw($0) })
    }

    func updateAppearancePreferenceRaw(_ rawValue: String) {
        self.appearanceStore.send(.appearancePreferenceChanged(rawValue))
        self.storedAppearancePreferenceRaw = rawValue
    }

    var displayNameBinding: Binding<String> {
        Binding(
            get: { self.deviceIdentityStore.displayName },
            set: { self.updateDisplayName($0) })
    }

    func updateDisplayName(_ displayName: String) {
        self.deviceIdentityStore.send(.displayNameChanged(displayName))
        self.storedDisplayName = displayName
    }

    var instanceId: String {
        self.deviceIdentityStore.instanceId
    }

    var discoveryDebugLogsBinding: Binding<Bool> {
        Binding(
            get: { self.debugOptionsStore.discoveryDebugLogsEnabled },
            set: { self.updateDiscoveryDebugLogsEnabled($0) })
    }

    var canvasDebugStatusBinding: Binding<Bool> {
        Binding(
            get: { self.debugOptionsStore.canvasDebugStatusEnabled },
            set: { self.updateCanvasDebugStatusEnabled($0) })
    }

    func updateDiscoveryDebugLogsEnabled(_ enabled: Bool) {
        self.debugOptionsStore.send(.discoveryDebugLogsChanged(enabled))
        self.storedDiscoveryDebugLogsEnabled = enabled
        self.gatewayController.setDiscoveryDebugLoggingEnabled(enabled)
    }

    func updateCanvasDebugStatusEnabled(_ enabled: Bool) {
        self.debugOptionsStore.send(.canvasDebugStatusChanged(enabled))
        self.storedCanvasDebugStatusEnabled = enabled
    }

    var locationModeRaw: String {
        self.locationStore.locationModeRaw
    }

    var locationModeBinding: Binding<String> {
        Binding(
            get: { self.locationStore.locationModeRaw },
            set: { self.updateLocationModeRaw($0) })
    }

    func updateLocationModeRaw(_ rawValue: String) {
        self.locationStore.send(.locationModeChanged(rawValue))
        self.deviceCapabilityStore.send(.locationModeChanged(rawValue))
        self.storedLocationModeRaw = rawValue
    }

    func updateGatewayAutoConnect(_ enabled: Bool) {
        self.gatewayAutoConnectStore.send(.enabledChanged(enabled))
        self.storedGatewayAutoConnect = enabled
    }

    func disableGatewayAutoConnectForOnboardingReset() {
        self.gatewayAutoConnectStore.send(.disabledForOnboardingReset)
        self.storedGatewayAutoConnect = false
    }

    func resetOnboardingCompletionState() {
        self.onboardingStateStore.send(.completionStateReset)
        self.storedOnboardingComplete = false
        self.storedHasConnectedOnce = false
    }

    func advanceOnboardingRequestID() {
        self.onboardingStateStore.send(.onboardingRequestAdvanced)
        self.storedOnboardingRequestID = self.onboardingStateStore.onboardingRequestID
    }

    var manualGatewayEnabled: Bool {
        self.manualGatewayEndpointStore.manualGatewayEnabled
    }

    var manualGatewayHost: String {
        self.manualGatewayEndpointStore.manualGatewayHost
    }

    var manualGatewayTLS: Bool {
        self.manualGatewayEndpointStore.manualGatewayTLS
    }

    var manualGatewayEnabledBinding: Binding<Bool> {
        Binding(
            get: { self.manualGatewayEndpointStore.manualGatewayEnabled },
            set: { self.updateManualGatewayEnabled($0) })
    }

    var manualGatewayHostBinding: Binding<String> {
        Binding(
            get: { self.manualGatewayEndpointStore.manualGatewayHost },
            set: { self.updateManualGatewayHost($0) })
    }

    var manualGatewayTLSBinding: Binding<Bool> {
        Binding(
            get: { self.manualGatewayEndpointStore.manualGatewayTLS },
            set: { self.updateManualGatewayTLS($0) })
    }

    func updateManualGatewayEnabled(_ enabled: Bool) {
        self.manualGatewayEndpointStore.send(.manualGatewayEnabledChanged(enabled))
        self.storedManualGatewayEnabled = enabled
    }

    func updateManualGatewayHost(_ host: String) {
        self.manualGatewayEndpointStore.send(.manualGatewayHostChanged(host))
        self.storedManualGatewayHost = host
    }

    func updateManualGatewayTLS(_ tls: Bool) {
        self.manualGatewayEndpointStore.send(.manualGatewayTLSChanged(tls))
        self.storedManualGatewayTLS = tls
    }

    func applyManualGatewaySetupLink(host: String, tls: Bool) {
        self.manualGatewayEndpointStore.send(.setupLinkApplied(host: host, tls: tls))
        self.storedManualGatewayHost = host
        self.storedManualGatewayTLS = tls
    }

    func clearManualGatewayEndpointForOnboardingReset() {
        self.manualGatewayEndpointStore.send(.endpointClearedForOnboardingReset)
        self.storedManualGatewayEnabled = false
        self.storedManualGatewayHost = ""
    }

    var gatewayTokenBinding: Binding<String> {
        Binding(
            get: { self.gatewayCredentialsStore.gatewayToken },
            set: { self.updateGatewayToken($0) })
    }

    var gatewayPasswordBinding: Binding<String> {
        Binding(
            get: { self.gatewayCredentialsStore.gatewayPassword },
            set: { self.updateGatewayPassword($0) })
    }

    func updateGatewayToken(_ value: String) {
        self.gatewayCredentialsStore.send(.gatewayTokenChanged(value))
        self.persistGatewayToken(value)
    }

    func updateGatewayPassword(_ value: String) {
        self.gatewayCredentialsStore.send(.gatewayPasswordChanged(value))
        self.persistGatewayPassword(value)
    }

    var manualPortIsValid: Bool {
        self.manualGatewayPortStore.isManualPortValid
    }

    func resolvedManualPort(host: String) -> Int? {
        SettingsManualGatewayPortFeature.State.resolvedManualPort(
            manualGatewayPort: self.manualGatewayPortStore.manualGatewayPort,
            host: host,
            useTLS: self.manualGatewayTLS)
    }

    var setupStatusLine: String? {
        self.gatewaySetupStatusStore.setupStatusLine
    }

    var setupCode: String {
        self.gatewaySetupLinkStore.setupCode
    }

    var setupCodeBinding: Binding<String> {
        Binding(
            get: { self.gatewaySetupLinkStore.setupCode },
            set: { self.updateSetupCode($0) })
    }

    func updateSetupCode(_ setupCode: String) {
        self.gatewaySetupLinkStore.send(.setupCodeChanged(setupCode))
        self.storedSetupCode = setupCode
    }

    var canApplyGatewaySetup: Bool {
        self.gatewaySetupLinkStore.canApplyGatewaySetup
    }

    var tailnetWarningText: String? {
        SettingsManualGatewayEndpointFeature.State.tailnetWarningText(
            host: self.manualGatewayHost,
            hasTailnetIPv4: Self.hasTailnetIPv4())
    }

    var shouldShowRealtimeVoicePicker: Bool {
        self.talkPreferencesStore.shouldShowRealtimeVoicePicker
    }

    var talkProviderSelectionBinding: Binding<String> {
        Binding(
            get: { self.talkPreferencesStore.providerSelectionRaw },
            set: { self.updateTalkProviderSelection($0) })
    }

    var talkRealtimeVoiceSelectionBinding: Binding<String> {
        Binding(
            get: { self.talkPreferencesStore.realtimeVoiceSelectionRaw },
            set: { self.updateTalkRealtimeVoiceSelection($0) })
    }

    var talkSpeechLocaleBinding: Binding<String> {
        Binding(
            get: { self.talkPreferencesStore.speechLocale },
            set: { self.updateTalkSpeechLocale($0) })
    }

    var talkBackgroundEnabledBinding: Binding<Bool> {
        Binding(
            get: { self.talkPreferencesStore.talkBackgroundEnabled },
            set: { self.updateTalkBackgroundEnabled($0) })
    }

    var talkButtonEnabledBinding: Binding<Bool> {
        Binding(
            get: { self.talkPreferencesStore.talkButtonEnabled },
            set: { self.updateTalkButtonEnabled($0) })
    }

    var talkSpeakerphoneBinding: Binding<Bool> {
        Binding(
            get: { self.talkPreferencesStore.talkSpeakerphoneEnabled },
            set: { self.updateTalkSpeakerphoneEnabled($0) })
    }

    func updateTalkProviderSelection(_ rawValue: String) {
        self.talkPreferencesStore.send(.providerSelectionChanged(rawValue))
        let selection = TalkModeProviderSelection.resolved(rawValue)
        self.storedTalkProviderSelectionRaw = selection.rawValue
        self.appModel.setTalkProviderSelection(selection.rawValue)
    }

    func updateTalkRealtimeVoiceSelection(_ rawValue: String) {
        self.talkPreferencesStore.send(.realtimeVoiceSelectionChanged(rawValue))
        let voice = TalkModeRealtimeVoiceSelection.resolvedOverride(rawValue) ?? ""
        self.storedTalkRealtimeVoiceSelectionRaw = voice
        self.appModel.setTalkRealtimeVoiceSelection(voice)
    }

    func updateTalkSpeechLocale(_ speechLocale: String) {
        self.talkPreferencesStore.send(.speechLocaleChanged(speechLocale))
        self.storedTalkSpeechLocale = speechLocale
    }

    func updateTalkBackgroundEnabled(_ enabled: Bool) {
        self.talkPreferencesStore.send(.talkBackgroundEnabledChanged(enabled))
        self.storedTalkBackgroundEnabled = enabled
    }

    func updateTalkButtonEnabled(_ enabled: Bool) {
        self.talkPreferencesStore.send(.talkButtonEnabledChanged(enabled))
        self.storedTalkButtonEnabled = enabled
    }

    func updateTalkSpeakerphoneEnabled(_ enabled: Bool) {
        self.talkPreferencesStore.send(.talkSpeakerphoneEnabledChanged(enabled))
        self.storedTalkSpeakerphoneEnabled = enabled
        self.appModel.setTalkSpeakerphoneEnabled(enabled)
    }

    var talkApiKeyStatus: String {
        self.talkPreferencesStore.talkApiKeyStatus
    }

    var gatewayTalkActiveVoiceDetail: String {
        self.talkPreferencesStore.gatewayTalkActiveVoiceDetail
    }

    var gatewayTalkLastIssueDetail: String? {
        self.talkPreferencesStore.gatewayTalkLastIssueDetail
    }

    var gatewayConnected: Bool {
        self.gatewayConnectionStore.gatewayConnected
    }

    var gatewayStatusDetail: String {
        self.gatewayConnectionStore.gatewayStatusDetail
    }

    var gatewayStatusValue: String {
        self.gatewayConnectionStore.gatewayStatusValue
    }

    var gatewayStatusColor: Color {
        self.gatewayConnectionStore.gatewayStatusColor
    }

    var gatewayDiagnosticConnected: Bool {
        self.gatewayConnectionStore.gatewayDiagnosticConnected
    }

    var gatewaySummaryDetail: String {
        self.gatewayConnectionStore.gatewaySummaryDetail
    }

    var gatewayDiagnosticTalkConfigLoaded: Bool {
        self.talkPreferencesStore.gatewayDiagnosticTalkConfigLoaded
    }

    var approvalEmptyDetail: String {
        self.approvalsStore.approvalEmptyDetail
    }

    var gatewayTalkConfigDetail: String {
        self.talkPreferencesStore.gatewayTalkConfigDetail
    }

    var gatewayTalkConfigValue: String {
        self.talkPreferencesStore.gatewayTalkConfigValue
    }

    var gatewayTalkConfigColor: Color {
        self.talkPreferencesStore.gatewayTalkConfigColor
    }

    var gatewayAddress: String {
        self.gatewayConnectionStore.gatewayAddress
    }

    var gatewayServer: String {
        self.gatewayConnectionStore.gatewayServer
    }

    var permissionsDetail: String {
        self.deviceCapabilityStore.permissionsDetail
    }

    var pendingApproval: NodeAppModel.ExecApprovalPrompt? {
        self.appModel.pendingExecApprovalPrompt
    }

    var approvalsDetail: String {
        self.approvalsStore.approvalsDetail
    }

    var notificationsNeedAttention: Bool {
        self.approvalsStore.notificationsNeedAttention
    }

    var approvalItems: [SettingsApprovalItem] {
        self.approvalsStore.approvalItems
    }

    var voiceDetail: String {
        self.voiceControlStore.detailText
    }

    var diagnosticsDetail: String {
        self.diagnosticsStore.detailText
    }

    var diagnosticsHealthValue: String {
        self.diagnosticsStore.healthValue
    }

    var diagnosticsHealthColor: Color {
        self.diagnosticsStore.healthColor
    }

    var diagnosticsRunValue: String {
        self.diagnosticsStore.runValue
    }

    var diagnosticsRunColor: Color {
        self.diagnosticsStore.runColor
    }

    var privacyDetail: String {
        self.locationStore.privacyDetail
    }

    var locationLabel: String {
        self.locationStore.locationLabel
    }

    var locationColor: Color {
        self.locationStore.locationColor
    }

    var notificationStatusText: String {
        self.notificationStore.statusText
    }

    var notificationStatusColor: Color {
        self.notificationStore.statusColor
    }

    var notificationActionText: String {
        self.notificationStore.actionText
    }

    var notificationStatusDetail: String {
        self.notificationStore.statusDetail
    }

    var notificationRelayDetail: String {
        self.notificationStore.relayDetail
    }

    var notificationRelayDisclosureMessage: String {
        self.notificationStore.relayDisclosureMessage
    }
}
