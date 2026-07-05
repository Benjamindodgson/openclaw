import ComposableArchitecture
import OpenClawKit
import SwiftUI

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
        let isAppleReviewDemoModeEnabled = self.appModel.isAppleReviewDemoModeEnabled
        await self.gatewayActivityStore
            .send(.reconnectRequested(.init(isAppleReviewDemoModeEnabled: isAppleReviewDemoModeEnabled)))
            .finish()
    }

    @MainActor
    func runDiagnostics() async {
        guard !self.gatewayActivityStore.isRefreshingGateway else { return }
        let isAppleReviewDemoModeEnabled = self.appModel.isAppleReviewDemoModeEnabled
        await self.gatewayActivityStore
            .send(.diagnosticsRefreshRequested(.init(isAppleReviewDemoModeEnabled: isAppleReviewDemoModeEnabled)))
            .finish()
        self.syncGatewayConnectionStatusState()
        self.syncDiagnosticsContextState()
        await self.notificationStore.send(.statusRefreshRequested).finish()
        self.handleNotificationStatusRefreshResult(self.notificationStore.statusRefreshResult)

        self.diagnosticsStore.send(.diagnosticsCompletionRequested(.init(
            gatewayConnected: self.gatewayDiagnosticConnected,
            discoveredGatewayCount: self.gatewayController.gateways.count,
            talkConfigLoaded: self.gatewayDiagnosticTalkConfigLoaded,
            notificationsAllowed: self.notificationStore.status == .allowed,
            lastRunText: SettingsDiagnostics.timestamp(Date()))))
    }

    func syncSettingsState() {
        self.pushEnrollmentConsentStore.send(.refresh)
        self.appearanceStore.send(.appearancePreferenceSynced(.init(rawValue: self.storedAppearancePreferenceRaw)))
        self.deviceIdentityStore.send(.displayNameSynced(.init(displayName: self.storedDisplayName)))
        self.deviceIdentityStore.send(.instanceIdSynced(.init(instanceId: self.storedInstanceId)))
        self.debugOptionsStore.send(.debugOptionsSynced(.init(
            discoveryDebugLogsEnabled: self.storedDiscoveryDebugLogsEnabled,
            canvasDebugStatusEnabled: self.storedCanvasDebugStatusEnabled)))
        self.syncGatewaySetupStatusContext()
        self.syncGatewayConnectionStatusState()
        self.syncDiagnosticsContextState()
        self.gatewaySetupLinkStore.send(.setupCodeSynced(.init(setupCode: self.storedSetupCode)))
        self.syncOnboardingState()
        self.deviceCapabilityStore.send(.capabilitiesSynced(
            SettingsDeviceCapabilityFeature.CapabilitiesSync(
                cameraEnabled: self.storedCameraEnabled,
                preventSleep: self.storedPreventSleep,
                locationModeRaw: self.storedLocationModeRaw)))
        self.syncVoiceControlState()
        self.syncTalkPreferencesState()
        self.syncTalkRuntimeState()
        self.locationStore.send(.locationModeSynced(.init(rawValue: self.storedLocationModeRaw)))
        self.syncNotificationRelayState()
        self.gatewayAutoConnectStore.send(.enabledSynced(.init(isEnabled: self.storedGatewayAutoConnect)))
        self.manualGatewayEndpointStore.send(.endpointSynced(.init(
            enabled: self.storedManualGatewayEnabled,
            host: self.storedManualGatewayHost,
            useTLS: self.storedManualGatewayTLS)))
        self.manualGatewayPortStore.send(.manualGatewayPortSynced(.init(port: self.storedManualGatewayPort)))
        self.agentSelectionStore.send(.selectedAgentSynced(.init(selectedAgentId: self.appModel.selectedAgentId)))
        self.shareInstructionStore.send(.defaultShareInstructionLoadRequested)
        self.gatewayCredentialsStore.send(.credentialsLoadRequested(.init(
            instanceId: .init(value: self.instanceId))))
    }

    func syncVoiceControlState() {
        self.voiceControlStore.send(.controlsSynced(.init(
            talkEnabled: self.storedTalkEnabled,
            voiceWakeEnabled: self.storedVoiceWakeEnabled,
            voiceWakeStatusText: self.appModel.voiceWake.statusText)))
    }

    func syncTalkPreferencesState() {
        self.talkPreferencesStore.send(.preferencesSynced(.init(
            providerSelectionRaw: self.storedTalkProviderSelectionRaw,
            realtimeVoiceSelectionRaw: self.storedTalkRealtimeVoiceSelectionRaw,
            speechLocale: self.storedTalkSpeechLocale,
            talkButtonEnabled: self.storedTalkButtonEnabled,
            talkBackgroundEnabled: self.storedTalkBackgroundEnabled,
            talkSpeakerphoneEnabled: self.storedTalkSpeakerphoneEnabled)))
    }

    func syncTalkRuntimeState() {
        self.talkPreferencesStore.send(.gatewayTalkConfigSynced(.init(
            configLoaded: self.appModel.talkMode.gatewayTalkConfigLoaded,
            apiKeyConfigured: self.appModel.talkMode.gatewayTalkApiKeyConfigured,
            usesRealtime: self.appModel.talkMode.gatewayTalkUsesRealtime)))
        self.talkPreferencesStore.send(.gatewayTalkDisplayContextSynced(.init(
            isAppleReviewDemoModeEnabled: self.appModel.isAppleReviewDemoModeEnabled,
            transportLabel: self.appModel.talkMode.gatewayTalkTransportLabel)))
        self.talkPreferencesStore.send(.gatewayTalkRuntimeSynced(.init(
            activeModeTitle: self.appModel.talkMode.gatewayTalkActiveModeTitle,
            activeModeSubtitle: self.appModel.talkMode.gatewayTalkActiveModeSubtitle,
            lastIssueText: self.appModel.talkMode.gatewayTalkLastIssueText)))
    }

    func syncDiagnosticsContextState() {
        self.diagnosticsStore.send(.diagnosticsContextSynced(.init(
            isAppleReviewDemoModeEnabled: self.appModel.isAppleReviewDemoModeEnabled,
            gatewayConnected: self.gatewayConnected,
            discoveredGatewayCount: self.gatewayController.gateways.count,
            discoveryStatusText: self.gatewayController.discoveryStatusText,
            screenRecordActive: self.appModel.screenRecordActive)))
    }

    func syncApprovalState() {
        let pendingApproval = self.appModel.pendingExecApprovalPrompt
        self.approvalsStore.send(.approvalsSynced(.init(
            isAppleReviewDemoModeEnabled: self.appModel.isAppleReviewDemoModeEnabled,
            gatewayConnected: self.gatewayConnected,
            notificationsNeedAttention: self.notificationStore.needsAttention,
            hasPendingApproval: pendingApproval != nil,
            pendingCommandPreview: pendingApproval?.commandPreview,
            activeAgentName: self.appModel.activeAgentName,
            isResolvingPendingApproval: self.appModel.pendingExecApprovalPromptResolving,
            pendingApprovalAllowsAllowAlways: pendingApproval?.allowsAllowAlways ?? false)))
    }

    func syncNotificationRelayState() {
        let config = PushBuildConfig.current
        let host = config.relayBaseURL.flatMap {
            URLComponents(url: $0, resolvingAgainstBaseURL: false)?.host
        }
        self.notificationStore.send(.relayConfigSynced(.init(
            usesOpenClawHostedRelay: config.usesOpenClawHostedRelay,
            hostedRelayHost: host)))
    }

    func syncOnboardingState() {
        self.onboardingStateStore.send(.onboardingStateSynced(.init(
            hasConnectedOnce: self.storedHasConnectedOnce,
            onboardingComplete: self.storedOnboardingComplete,
            onboardingRequestID: self.storedOnboardingRequestID)))
    }

    func syncGatewaySetupStatusContext() {
        self.gatewaySetupStatusStore.send(.gatewayStatusSynced(.init(
            problemMessage: self.appModel.lastGatewayProblem?.message,
            gatewayStatusText: self.appModel.gatewayStatusText)))
    }

    func syncGatewayConnectionStatusState() {
        self.gatewayConnectionStore.send(.gatewayStatusSynced(.init(
            isAppleReviewDemoModeEnabled: self.appModel.isAppleReviewDemoModeEnabled,
            gatewayStatusConnected: GatewayStatusBuilder.build(appModel: self.appModel) == .connected,
            gatewayDisplayStatusText: self.appModel.gatewayDisplayStatusText,
            gatewayAgentCount: self.appModel.gatewayAgents.count,
            gatewayRemoteAddress: self.appModel.gatewayRemoteAddress,
            gatewayServerName: self.appModel.gatewayServerName)))
        self.syncApprovalState()
    }

    func connect(_ gateway: GatewayDiscoveryModel.DiscoveredGateway) async {
        self.gatewayConnectionStore.send(.connectionStarted(.init(gatewayID: gateway.id)))
        defer { self.gatewayConnectionStore.send(.connectionFinished) }
        self.updateManualGatewayEnabled(false)
        self.gatewayConnectionStore.send(.discoveredGatewayPersistenceRequested(.init(
            stableID: .init(value: gateway.stableID))))
        let result = await self.gatewayController.connectWithDiagnostics(gateway)
        if let failure = result.failure {
            self.gatewaySetupStatusStore.send(.statusChanged(.init(statusText: failure.message)))
        }
    }

    func applySetupCodeAndConnect() async {
        self.gatewaySetupStatusStore.send(.statusChanged(.init(statusText: nil)))
        guard await self.applySetupCode() else { return }
        let host = self.manualGatewayHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard self.resolveManualPortForConnection(host: host) else { return }
        guard await self.preflightGateway(host: host) else { return }
        self.gatewaySetupStatusStore.send(.setupConnectionStarted)
        await self.connectManual()
    }

    func applyPendingGatewaySetupLinkIfNeeded() {
        guard let link = self.appModel.consumePendingGatewaySetupLink() else { return }
        self.updateSetupCode("")
        self.gatewaySetupStatusStore.send(.statusChanged(.init(statusText: nil)))
        self.gatewaySetupLinkStore.send(.setupLinkStaged(.init(link: link)))
        if let statusText = self.gatewaySetupLinkStore.setupLinkStatusText {
            self.gatewaySetupStatusStore.send(.statusChanged(.init(statusText: statusText)))
            self.gatewaySetupLinkStore.send(.setupLinkStatusHandled)
        }
    }

    @discardableResult
    func applySetupCode() async -> Bool {
        await self.gatewaySetupLinkStore.send(.applyRequested).finish()
        guard let result = self.gatewaySetupLinkStore.applyResult else { return false }
        self.gatewaySetupLinkStore.send(.applyResultHandled)

        switch result {
        case let .appleReviewDemo(demo):
            self.updateSetupCode("")
            self.gatewaySetupStatusStore.send(.statusChanged(.init(statusText: demo.statusText)))
            return false

        case let .failure(failure):
            self.gatewaySetupStatusStore.send(.statusChanged(.init(statusText: failure.message)))
            return false

        case let .gatewayLink(link):
            await self.applyGatewayLink(link)
            return true
        }
    }

    func applyGatewayLink(_ link: GatewayConnectDeepLink) async {
        self.applyManualGatewaySetupLink(host: link.host, tls: link.tls)
        self.manualGatewayPortStore.send(.manualGatewayPortSynced(.init(port: link.port)))
        self.gatewayCredentialsStore.send(.setupLinkApplied(.init(link: link)))
        guard let request = self.gatewayCredentialsStore.setupAuthPersistenceRequest else { return }
        defer { self.gatewayCredentialsStore.send(.setupAuthPersistenceRequestHandled) }

        await self.gatewayCredentialsStore.send(.setupAuthPersistenceRequested(request)).finish()
    }

    func openGatewayQRScanner() async {
        await self.gatewayConnectionStore.send(.disconnectRequested).finish()
        self.gatewaySetupStatusStore.send(.qrScannerOpeningStarted)
        self.presentationStore.send(.qrScannerButtonTapped)
    }

    func handleScannedGatewayLink(_ link: GatewayConnectDeepLink) {
        self.gatewaySetupLinkStore.send(.scannedGatewayLinkReceived(.init(link: link)))
        guard case let .gatewayLink(scannedLink)? = self.gatewaySetupLinkStore.applyResult else { return }
        self.gatewaySetupLinkStore.send(.applyResultHandled)
        self.presentationStore.send(.qrScannerDismissed)
        self.updateSetupCode("")
        if let statusText = self.gatewaySetupLinkStore.scannedGatewayLinkStatusText {
            self.gatewaySetupStatusStore.send(.statusChanged(.init(statusText: statusText)))
            self.gatewaySetupLinkStore.send(.scannedGatewayLinkStatusHandled)
        }
        Task {
            await self.applyGatewayLink(scannedLink)
            await self.connectAfterScannedGatewayLink()
        }
    }

    func handleScannedSetupCode(_ code: String) {
        self.gatewaySetupLinkStore.send(.scannedSetupCodeReceived(.init(code: code)))
        guard case let .appleReviewDemo(demo)? = self.gatewaySetupLinkStore.applyResult else { return }
        self.gatewaySetupLinkStore.send(.applyResultHandled)
        self.presentationStore.send(.qrScannerDismissed)
        self.updateSetupCode("")
        self.gatewaySetupStatusStore.send(.statusChanged(.init(statusText: demo.statusText)))
    }

    func connectAfterScannedGatewayLink() async {
        let host = self.manualGatewayHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard self.resolveManualPortForConnection(host: host) else { return }
        guard await self.preflightGateway(host: host) else { return }
        await self.connectManual()
    }

    func resolveManualPortForConnection(host: String) -> Bool {
        self.manualGatewayPortStore.send(.manualGatewayPortResolutionRequested(.init(
            host: host,
            useTLS: self.manualGatewayTLS)))
        guard let result = self.manualGatewayPortStore.manualGatewayPortResolutionResult else { return false }
        self.manualGatewayPortStore.send(.manualGatewayPortResolutionResultHandled)

        switch result {
        case let .failure(failure):
            self.gatewaySetupStatusStore.send(.statusChanged(.init(statusText: failure.message)))
            return false

        case .resolved:
            return true
        }
    }

    func connectManual() async {
        self.manualGatewayEndpointStore.send(.manualConnectionRequested(.init(
            port: self.manualGatewayPortStore.manualGatewayPort,
            isPortValid: self.manualPortIsValid)))
        guard let result = self.manualGatewayEndpointStore.manualConnectionResult else { return }
        self.manualGatewayEndpointStore.send(.manualConnectionResultHandled)

        switch result {
        case let .failure(failure):
            self.gatewaySetupStatusStore.send(.statusChanged(.init(statusText: failure.message)))

        case let .request(request):
            self.gatewayConnectionStore.send(.connectionStarted(.init(gatewayID: "manual")))
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
        self.manualGatewayEndpointStore.send(.preflightRequested(.init(
            host: host,
            hasTailnetIPv4: Self.hasTailnetIPv4())))
        guard let result = self.manualGatewayEndpointStore.preflightResult else { return false }
        self.manualGatewayEndpointStore.send(.preflightResultHandled)

        switch result {
        case let .blocked(blocked):
            if let statusText = blocked.statusText {
                self.gatewaySetupStatusStore.send(.statusChanged(.init(statusText: statusText)))
            }
            return false

        case let .requestLocalNetworkAccess(request):
            self.manualGatewayEndpointStore.send(.localNetworkAccessRequested(.init(reason: request.reason)))
            return true
        }
    }

    func resetOnboarding() async {
        self.gatewayConnectionStore.send(.connectionFinished)
        self.gatewaySetupStatusStore.send(.statusChanged(.init(statusText: nil)))
        self.updateSetupCode("")
        self.disableGatewayAutoConnectForOnboardingReset()
        self.gatewayCredentialsStore.send(.credentialsClearedForOnboardingReset)
        await self.onboardingStateStore
            .send(.onboardingResetRequested(.init(
                instanceId: .init(value: self.instanceId))))
            .finish()
        self.syncStoredOnboardingResetState()
        self.clearManualGatewayEndpointForOnboardingReset()
    }

    func retryGatewayConnectionFromProblem() async {
        if self.manualGatewayEnabled || self.connectingGatewayID == "manual" {
            await self.connectManual()
        } else {
            await self.gatewayActivityStore
                .send(.reconnectRequested(.init(
                    isAppleReviewDemoModeEnabled: self.appModel.isAppleReviewDemoModeEnabled)))
                .finish()
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
            await self.resetOnboarding()
            return
        }
        if problem.canTrustRotatedCertificate {
            await self.gatewayActivityStore
                .send(.rotatedCertificateTrustRequested(.init(problem: problem)))
                .finish()
            return
        }
        if GatewayProblemPrimaryAction.openProtocolMismatchHelpIfNeeded(problem) {
            return
        }
        guard problem.retryable else { return }
        await self.retryGatewayConnectionFromProblem()
    }

    func handleLocationModeRequest(_ request: SettingsLocationFeature.LocationModeRequest?) {
        guard let request else { return }
        self.locationStore.send(.locationModeApplyRequested(request))
    }

    func handleLocationModeApplyResult(_ result: SettingsLocationFeature.LocationModeApplyResult?) {
        guard let result else { return }
        self.locationStore.send(.locationModeApplyResultHandled)
        if case let .denied(denied) = result {
            self.storedLocationModeRaw = denied.previousRawValue
        }
    }

    func refreshNotificationSettings() {
        self.notificationStore.send(.statusRefreshRequested)
    }

    func handleNotificationAction() {
        self.notificationStore.send(.actionButtonTapped)
        guard let request = self.notificationStore.actionRequest else { return }
        self.notificationStore.send(.actionRequestHandled)

        switch request {
        case .openSettings:
            self.notificationStore.send(.notificationSettingsOpenRequested)

        case .requestAuthorization:
            self.requestNotificationAuthorizationFromSettings()

        case .showRelayDisclosure:
            self.presentationStore.send(.notificationRelayDisclosureRequested)
        }
    }

    func requestNotificationAuthorizationFromSettings() {
        guard !self.notificationStore.isRequestingAuthorization else { return }
        self.pushEnrollmentConsentStore.send(.acceptDisclosure)
        self.notificationStore.send(.authorizationRequestRequested)
    }

    func handleNotificationAuthorizationResult(_ result: SettingsNotificationAuthorizationResult?) {
        guard let result else { return }
        self.notificationStore.send(.authorizationRequestResultHandled)
        self.syncApprovalState()
        guard result.granted else { return }
        self.registerForRemoteNotificationsIfEnrollmentReady()
    }

    func handleNotificationStatusRefreshResult(_ status: SettingsNotificationStatus?) {
        guard status != nil else { return }
        self.notificationStore.send(.statusRefreshResultHandled)
        self.syncApprovalState()
        self.registerForRemoteNotificationsIfEnrollmentReady()
    }

    @MainActor
    func registerForRemoteNotificationsIfEnrollmentReady() {
        self.notificationStore.send(.remoteRegistrationRequested(.init(
            disclosureAccepted: self.pushEnrollmentConsentStore.disclosureAccepted)))
    }

    var manualPortBinding: Binding<String> {
        Binding(
            get: { self.manualGatewayPortStore.manualGatewayPortText },
            set: { self.manualGatewayPortStore.send(.manualGatewayPortTextChanged(.init(text: $0))) })
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
        self.deviceCapabilityStore.send(.cameraEnabledChanged(
            SettingsDeviceCapabilityFeature.CameraEnabledChange(isEnabled: enabled)))
        self.storedCameraEnabled = enabled
    }

    func updatePreventSleep(_ enabled: Bool) {
        self.deviceCapabilityStore.send(.preventSleepChanged(
            SettingsDeviceCapabilityFeature.PreventSleepChange(isEnabled: enabled)))
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
        self.voiceControlStore.send(.talkEnabledChangeRequested(.init(
            enabled: enabled,
            isAppleReviewDemoModeEnabled: self.appModel.isAppleReviewDemoModeEnabled)))
        self.storedTalkEnabled = self.voiceControlStore.talkEnabled
    }

    func updateVoiceWakeEnabled(_ enabled: Bool) {
        self.voiceControlStore.send(.voiceWakeEnabledChanged(.init(enabled: enabled)))
        self.storedVoiceWakeEnabled = enabled
    }

    var appearancePreferenceBinding: Binding<String> {
        Binding(
            get: { self.appearanceStore.appearancePreferenceRaw },
            set: { self.updateAppearancePreferenceRaw($0) })
    }

    func updateAppearancePreferenceRaw(_ rawValue: String) {
        guard let preference = AppAppearancePreference(rawValue: rawValue) else { return }
        self.appearanceStore.send(.appearancePreferenceChanged(.init(preference: preference)))
        self.storedAppearancePreferenceRaw = preference.rawValue
    }

    var displayNameBinding: Binding<String> {
        Binding(
            get: { self.deviceIdentityStore.displayName },
            set: { self.updateDisplayName($0) })
    }

    func updateDisplayName(_ displayName: String) {
        self.deviceIdentityStore.send(.displayNameChanged(.init(displayName: displayName)))
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
        self.debugOptionsStore.send(.discoveryDebugLogsChanged(.init(enabled: enabled)))
        self.storedDiscoveryDebugLogsEnabled = enabled
    }

    func updateCanvasDebugStatusEnabled(_ enabled: Bool) {
        self.debugOptionsStore.send(.canvasDebugStatusChanged(.init(enabled: enabled)))
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
        guard let mode = OpenClawLocationMode(rawValue: rawValue) else { return }
        self.locationStore.send(.locationModeChanged(.init(mode: mode)))
        self.deviceCapabilityStore.send(.locationModeChanged(
            SettingsDeviceCapabilityFeature.LocationModeChange(mode: .init(mode: mode))))
        self.storedLocationModeRaw = mode.rawValue
    }

    func updateGatewayAutoConnect(_ enabled: Bool) {
        self.gatewayAutoConnectStore.send(.enabledChanged(.init(isEnabled: enabled)))
        self.storedGatewayAutoConnect = enabled
    }

    func disableGatewayAutoConnectForOnboardingReset() {
        self.gatewayAutoConnectStore.send(.disabledForOnboardingReset)
        self.storedGatewayAutoConnect = false
    }

    func syncStoredOnboardingResetState() {
        self.storedOnboardingComplete = self.onboardingStateStore.onboardingComplete
        self.storedHasConnectedOnce = self.onboardingStateStore.hasConnectedOnce
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
        self.manualGatewayEndpointStore.send(.manualGatewayEnabledChanged(.init(isEnabled: enabled)))
        self.storedManualGatewayEnabled = enabled
    }

    func updateManualGatewayHost(_ host: String) {
        self.manualGatewayEndpointStore.send(.manualGatewayHostChanged(.init(
            draft: .init(value: host))))
        self.storedManualGatewayHost = host
    }

    func updateManualGatewayTLS(_ tls: Bool) {
        self.manualGatewayEndpointStore.send(.manualGatewayTLSChanged(.init(useTLS: tls)))
        self.storedManualGatewayTLS = tls
    }

    func applyManualGatewaySetupLink(host: String, tls: Bool) {
        self.manualGatewayEndpointStore.send(.setupLinkApplied(.init(host: host, useTLS: tls)))
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
        self.gatewayCredentialsStore.send(.gatewayTokenChanged(.init(
            draft: .init(value: value))))
        self.gatewayCredentialsStore.send(.gatewayTokenPersistenceRequested(.init(
            value: .init(rawValue: value),
            instanceId: .init(value: self.instanceId))))
    }

    func updateGatewayPassword(_ value: String) {
        self.gatewayCredentialsStore.send(.gatewayPasswordChanged(.init(
            draft: .init(value: value))))
        self.gatewayCredentialsStore.send(.gatewayPasswordPersistenceRequested(.init(
            value: .init(rawValue: value),
            instanceId: .init(value: self.instanceId))))
    }

    var manualPortIsValid: Bool {
        self.manualGatewayPortStore.isManualPortValid
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
        self.gatewaySetupLinkStore.send(.setupCodeChanged(.init(setupCode: setupCode)))
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
        let selection = TalkModeProviderSelection.resolved(rawValue)
        self.talkPreferencesStore.send(.providerSelectionChanged(.init(selection: selection)))
        self.storedTalkProviderSelectionRaw = selection.rawValue
    }

    func updateTalkRealtimeVoiceSelection(_ rawValue: String) {
        let voice = SettingsTalkRealtimeVoiceSelection(rawValue: rawValue)
        self.talkPreferencesStore.send(.realtimeVoiceSelectionChanged(.init(voice: voice)))
        self.storedTalkRealtimeVoiceSelectionRaw = voice.value
    }

    func updateTalkSpeechLocale(_ speechLocale: String) {
        self.talkPreferencesStore.send(.speechLocaleChanged(.init(
            locale: SettingsTalkSpeechLocale(value: speechLocale))))
        self.storedTalkSpeechLocale = speechLocale
    }

    func updateTalkBackgroundEnabled(_ enabled: Bool) {
        self.talkPreferencesStore.send(.talkBackgroundEnabledChanged(.init(isEnabled: enabled)))
        self.storedTalkBackgroundEnabled = enabled
    }

    func updateTalkButtonEnabled(_ enabled: Bool) {
        self.talkPreferencesStore.send(.talkButtonEnabledChanged(.init(isEnabled: enabled)))
        self.storedTalkButtonEnabled = enabled
    }

    func updateTalkSpeakerphoneEnabled(_ enabled: Bool) {
        let speakerphone = SettingsTalkSpeakerphoneEnabled(isEnabled: enabled)
        self.talkPreferencesStore.send(.talkSpeakerphoneEnabledChanged(.init(enabled: speakerphone)))
        self.storedTalkSpeakerphoneEnabled = speakerphone.isEnabled
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
