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
                    detail: self.gatewayController.discoveryStatusText,
                    value: "\(self.gatewayController.gateways.count)",
                    color: self.gatewayController.gateways.isEmpty ? .secondary : OpenClawBrand.accent)
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
                    color: self.notificationStore.status.color)
                Divider().padding(.leading, 60)
                self.diagnosticCheckRow(
                    icon: "rectangle.on.rectangle",
                    title: "Screen Capture",
                    detail: "Live foreground capture state",
                    value: self.appModel.screenRecordActive ? "live" : "idle",
                    color: self.appModel.screenRecordActive ? OpenClawBrand.ok : .secondary)
                Divider().padding(.leading, 60)
                self.diagnosticCheckRow(
                    icon: "mic",
                    title: "Voice Wake",
                    detail: self.appModel.voiceWake.statusText,
                    value: self.voiceWakeEnabled ? "on" : "off",
                    color: self.voiceWakeEnabled ? OpenClawBrand.ok : .secondary)
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
        self.debugOptionsStore.send(.debugOptionsSynced(
            discoveryDebugLogsEnabled: self.storedDiscoveryDebugLogsEnabled,
            canvasDebugStatusEnabled: self.storedCanvasDebugStatusEnabled))
        self.deviceCapabilityStore.send(.capabilitiesSynced(
            cameraEnabled: self.storedCameraEnabled,
            preventSleep: self.storedPreventSleep))
        self.locationStore.send(.locationModeSynced(self.storedLocationModeRaw))
        self.gatewayAutoConnectStore.send(.enabledSynced(self.storedGatewayAutoConnect))
        self.manualGatewayEndpointStore.send(.endpointSynced(
            enabled: self.storedManualGatewayEnabled,
            host: self.storedManualGatewayHost,
            tls: self.storedManualGatewayTLS))
        self.manualGatewayPortStore.send(.manualGatewayPortSynced(self.manualGatewayPort))
        self.agentSelectionStore.send(.selectedAgentSynced(self.appModel.selectedAgentId))
        self.shareInstructionStore.send(
            .defaultShareInstructionLoaded(ShareToAgentSettings.loadDefaultInstruction()))
        let trimmedInstanceId = self.instanceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInstanceId.isEmpty else { return }
        self.gatewayCredentialsStore.send(.credentialsLoaded(
            token: GatewaySettingsStore.loadGatewayToken(instanceId: trimmedInstanceId) ?? "",
            password: GatewaySettingsStore.loadGatewayPassword(instanceId: trimmedInstanceId) ?? ""))
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
        self.setupCode = ""
        self.gatewaySetupStatusStore.send(.statusChanged(nil))
        self.gatewaySetupLinkStore.send(.setupLinkStaged(link))
        let security = link.tls ? "TLS" : "plain"
        self.gatewaySetupStatusStore.send(
            .statusChanged("Setup link loaded for \(link.host):\(link.port) (\(security)). Tap Connect to apply."))
    }

    @discardableResult
    func applySetupCode() -> Bool {
        let raw = self.setupCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let stagedLink = self.stagedGatewaySetupLink
        guard !raw.isEmpty || stagedLink != nil else {
            self.gatewaySetupStatusStore.send(.statusChanged("Paste a setup code to continue."))
            return false
        }

        if AppleReviewDemoMode.isSetupCode(raw) {
            self.gatewaySetupLinkStore.send(.setupLinkStaged(nil))
            self.setupCode = ""
            self.gatewaySetupStatusStore.send(.statusChanged("Apple Review demo mode enabled."))
            self.appModel.enterAppleReviewDemoMode()
            return false
        }

        guard let link = raw.isEmpty ? stagedLink : GatewayConnectDeepLink.fromSetupInput(raw) else {
            self.gatewaySetupStatusStore.send(
                .statusChanged("Setup code not recognized or uses an insecure ws:// gateway URL."))
            return false
        }
        self.gatewaySetupLinkStore.send(.setupLinkStaged(nil))
        self.applyGatewayLink(link)
        return true
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
        self.presentationStore.send(.qrScannerDismissed)
        self.setupCode = ""
        self.applyGatewayLink(link)
        self.gatewaySetupStatusStore.send(.statusChanged("QR loaded. Connecting to \(link.host):\(link.port)..."))
        Task { await self.connectAfterScannedGatewayLink() }
    }

    func handleScannedSetupCode(_ code: String) {
        guard AppleReviewDemoMode.isSetupCode(code) else { return }
        self.presentationStore.send(.qrScannerDismissed)
        self.setupCode = ""
        self.gatewaySetupLinkStore.send(.setupLinkStaged(nil))
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
        let host = self.manualGatewayHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else {
            self.gatewaySetupStatusStore.send(.statusChanged("Failed: host required"))
            return
        }
        guard self.manualPortIsValid else {
            self.gatewaySetupStatusStore.send(.statusChanged("Failed: invalid port"))
            return
        }
        self.gatewayConnectionStore.send(.connectionStarted("manual"))
        self.updateManualGatewayEnabled(true)
        defer { self.gatewayConnectionStore.send(.connectionFinished) }
        let authOverride = GatewayConnectionController.ManualAuthOverride.currentManualInput(
            token: self.gatewayCredentialsStore.gatewayToken,
            pendingOverride: self.gatewayCredentialsStore.pendingManualAuthOverride,
            password: self.gatewayCredentialsStore.gatewayPassword)
        self.gatewayCredentialsStore.send(.pendingManualAuthOverrideConsumed)
        await self.gatewayController.connectManual(
            host: host,
            port: self.manualGatewayPortStore.manualGatewayPort,
            useTLS: self.manualGatewayTLS,
            authOverride: authOverride)
    }

    func preflightGateway(host: String) async -> Bool {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if Self.isTailnetHostOrIP(trimmed), !Self.hasTailnetIPv4() {
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
        self.setupCode = ""
        self.disableGatewayAutoConnectForOnboardingReset()
        self.gatewayCredentialsStore.send(.credentialsClearedForOnboardingReset)
        GatewayOnboardingReset.reset(appModel: self.appModel, instanceId: self.instanceId)
        self.onboardingComplete = false
        self.hasConnectedOnce = false
        self.clearManualGatewayEndpointForOnboardingReset()
        self.onboardingRequestID += 1
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

    func title(for route: SettingsRoute) -> String {
        switch route {
        case .gateway: "Gateway"
        case .approvals: "Approvals"
        case .permissions: "Permissions"
        case .channels: "Channels"
        case .voice: "Voice & Talk"
        case .diagnostics: "Diagnostics"
        case .privacy: "Privacy"
        case .notifications: "Notifications"
        case .about: "About"
        }
    }

    func subtitle(for route: SettingsRoute) -> String {
        switch route {
        case .gateway: "Pairing, diagnostics, and Tailscale checks."
        case .approvals: "Review pending agent actions."
        case .permissions: "Control device capabilities."
        case .channels: "Message routing and external clients."
        case .voice: "Talk mode and wake phrase settings."
        case .diagnostics: "Run local health checks."
        case .privacy: "Data and device privacy controls."
        case .notifications: "Alert permissions and delivery."
        case .about: "Version and support details."
        }
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
        if let problem = self.appModel.lastGatewayProblem {
            return problem.message
        }
        let trimmedSetup = self.setupStatusText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let gatewayStatus = self.appModel.gatewayStatusText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let friendly = self.friendlyGatewayMessage(from: gatewayStatus) { return friendly }
        if let friendly = self.friendlyGatewayMessage(from: trimmedSetup) { return friendly }
        if self.isTransientSetupStatus(trimmedSetup),
           !gatewayStatus.isEmpty,
           gatewayStatus != "Offline"
        {
            return gatewayStatus
        }
        if !trimmedSetup.isEmpty { return trimmedSetup }
        if gatewayStatus.isEmpty || gatewayStatus == "Offline" { return nil }
        return gatewayStatus
    }

    var canApplyGatewaySetup: Bool {
        !self.setupCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || self.stagedGatewaySetupLink != nil
    }

    var tailnetWarningText: String? {
        let host = self.manualGatewayHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, Self.isTailnetHostOrIP(host), !Self.hasTailnetIPv4() else { return nil }
        return "This gateway is on your tailnet. Turn on Tailscale on this device, then tap Connect."
    }

    func friendlyGatewayMessage(from raw: String) -> String? {
        let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.contains("pairing required") {
            return "Pairing required. Run /pair approve in your OpenClaw chat, then connect again."
        }
        if lower.contains("device nonce required") || lower.contains("device nonce mismatch") {
            return "Secure handshake failed. Check Tailscale, then connect again."
        }
        if lower.contains("tls fingerprint verification timed out")
            || lower.contains("no tls endpoint detected")
        {
            return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if lower.contains("timed out") {
            return "Connection timed out. Make sure Tailscale is connected, then try again."
        }
        if lower.contains("unauthorized role") {
            return "Connected, but some controls are restricted for nodes. This is expected."
        }
        return nil
    }

    func isTransientSetupStatus(_ raw: String) -> Bool {
        let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lower == "setup code applied. connecting..."
            || lower.hasPrefix("qr loaded. connecting to ")
            || lower == "checking gateway reachability..."
    }

    var shouldShowRealtimeVoicePicker: Bool {
        let providerSelection = TalkModeProviderSelection.resolved(self.talkProviderSelectionRaw)
        return providerSelection == .openAIRealtime || self.appModel.talkMode.gatewayTalkUsesRealtime
    }

    var talkProviderSelectionBinding: Binding<String> {
        Binding(
            get: { self.talkProviderSelectionRaw },
            set: { newValue in
                let selection = TalkModeProviderSelection.resolved(newValue)
                self.talkProviderSelectionRaw = selection.rawValue
                self.appModel.setTalkProviderSelection(selection.rawValue)
            })
    }

    var talkRealtimeVoiceSelectionBinding: Binding<String> {
        Binding(
            get: { self.talkRealtimeVoiceSelectionRaw },
            set: { newValue in
                let voice = TalkModeRealtimeVoiceSelection.resolvedOverride(newValue) ?? ""
                self.talkRealtimeVoiceSelectionRaw = voice
                self.appModel.setTalkRealtimeVoiceSelection(voice)
            })
    }

    var talkSpeakerphoneBinding: Binding<Bool> {
        Binding(
            get: { self.talkSpeakerphoneEnabled },
            set: { newValue in
                self.talkSpeakerphoneEnabled = newValue
                self.appModel.setTalkSpeakerphoneEnabled(newValue)
            })
    }

    var talkApiKeyStatus: String {
        guard self.appModel.talkMode.gatewayTalkConfigLoaded else { return "Not loaded" }
        return self.appModel.talkMode.gatewayTalkApiKeyConfigured ? "Configured" : "Not configured"
    }

    var gatewayTalkActiveVoiceDetail: String {
        let title = self.appModel.talkMode.gatewayTalkActiveModeTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitle = (self.appModel.talkMode.gatewayTalkActiveModeSubtitle ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { return "Not active" }
        if subtitle.isEmpty { return title }
        return "\(title) • \(subtitle)"
    }

    var gatewayTalkLastIssueDetail: String? {
        let detail = (self.appModel.talkMode.gatewayTalkLastIssueText ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return detail.isEmpty ? nil : detail
    }

    func gatewayDetailLines(_ gateway: GatewayDiscoveryModel.DiscoveredGateway) -> [String] {
        var lines: [String] = []
        if let lanHost = gateway.lanHost { lines.append("LAN: \(lanHost)") }
        if let tailnet = gateway.tailnetDns { lines.append("Tailnet: \(tailnet)") }
        let gw = gateway.gatewayPort.map(String.init)
        let canvas = gateway.canvasPort.map(String.init)
        if gw != nil || canvas != nil {
            lines.append("Ports: gateway \(gw ?? "-") / canvas \(canvas ?? "-")")
        }
        return lines.isEmpty ? [gateway.debugID] : lines
    }

    var gatewayConnected: Bool {
        !self.appModel.isAppleReviewDemoModeEnabled &&
            GatewayStatusBuilder.build(appModel: self.appModel) == .connected
    }

    var gatewayStatusDetail: String {
        if self.appModel.isAppleReviewDemoModeEnabled { return "Apple Review demo mode" }
        return self.gatewayConnected ? "Connected" : self.appModel.gatewayDisplayStatusText
    }

    var gatewayStatusValue: String {
        if self.appModel.isAppleReviewDemoModeEnabled { return "demo" }
        return self.gatewayConnected ? "online" : "offline"
    }

    var gatewayStatusColor: Color {
        if self.appModel.isAppleReviewDemoModeEnabled { return OpenClawBrand.accent }
        return self.gatewayConnected ? OpenClawBrand.ok : .secondary
    }

    var gatewayDiagnosticConnected: Bool {
        self.appModel.isAppleReviewDemoModeEnabled || self.gatewayConnected
    }

    var gatewayDiagnosticTalkConfigLoaded: Bool {
        self.appModel.isAppleReviewDemoModeEnabled || self.appModel.talkMode.gatewayTalkConfigLoaded
    }

    var approvalEmptyDetail: String {
        if self.appModel.isAppleReviewDemoModeEnabled {
            return "Live gateway requests are disabled in demo mode."
        }
        if self.notificationsNeedAttention {
            return "Foreground approvals still appear while OpenClaw is connected."
        }
        return self.gatewayConnected ? "Gateway requests will appear here." : "Connect to the gateway."
    }

    var gatewayTalkConfigDetail: String {
        if self.appModel.isAppleReviewDemoModeEnabled { return "Demo mode only" }
        return self.appModel.talkMode.gatewayTalkTransportLabel
    }

    var gatewayTalkConfigValue: String {
        if self.appModel.isAppleReviewDemoModeEnabled { return "demo" }
        return self.appModel.talkMode.gatewayTalkConfigLoaded ? "loaded" : "missing"
    }

    var gatewayTalkConfigColor: Color {
        if self.appModel.isAppleReviewDemoModeEnabled { return .secondary }
        return self.appModel.talkMode.gatewayTalkConfigLoaded ? OpenClawBrand.ok : .secondary
    }

    var gatewayAddress: String {
        self.appModel.gatewayRemoteAddress ?? "Waiting for gateway"
    }

    var gatewayServer: String {
        self.appModel.gatewayServerName ?? "OpenClaw Gateway"
    }

    var permissionsDetail: String {
        var enabled = self.deviceCapabilityStore.enabledCount
        if self.locationModeRaw != OpenClawLocationMode.off.rawValue { enabled += 1 }
        return "\(enabled) enabled"
    }

    var pendingApproval: NodeAppModel.ExecApprovalPrompt? {
        self.appModel.pendingExecApprovalPrompt
    }

    var approvalsDetail: String {
        if self.notificationsNeedAttention {
            return self.pendingApproval == nil ? "Notifications off" : "1 waiting, notifications off"
        }
        return self.pendingApproval == nil ? "No approvals waiting" : "1 request waiting"
    }

    var notificationsNeedAttention: Bool {
        switch self.notificationStore.status {
        case .allowed, .checking:
            false
        case .notAllowed, .notSet, .unknown:
            true
        }
    }

    var approvalItems: [SettingsApprovalItem] {
        guard let pendingApproval else { return [] }
        return [
            SettingsApprovalItem(
                id: "pending-real",
                icon: "terminal.fill",
                title: pendingApproval.commandPreview ?? "Review gateway action",
                detail: "Agent: \(self.appModel.activeAgentName)",
                priority: self.appModel.pendingExecApprovalPromptResolving ? "Resolving" : "High",
                color: OpenClawBrand.danger),
            SettingsApprovalItem(
                id: "pending-context",
                icon: "doc.text.fill",
                title: pendingApproval.allowsAllowAlways ? "Permission can be saved" : "One-time approval",
                detail: "Gateway request",
                priority: pendingApproval.allowsAllowAlways ? "Medium" : "Review",
                color: OpenClawBrand.warn),
        ]
    }

    var voiceDetail: String {
        if self.talkEnabled, self.voiceWakeEnabled { return "Talk + Wake" }
        if self.talkEnabled { return "Talk on" }
        if self.voiceWakeEnabled { return "Wake on" }
        return "Off"
    }

    var diagnosticsDetail: String {
        "System checks"
    }

    var diagnosticsHealthValue: String {
        if self.appModel.isAppleReviewDemoModeEnabled { return "demo" }
        if self.gatewayConnected { return "ready" }
        if self.gatewayController.gateways.isEmpty { return "check" }
        return "partial"
    }

    var diagnosticsRunValue: String {
        guard let diagnosticsIssueCount = self.diagnosticsStore.issueCount else { return "pending" }
        return diagnosticsIssueCount == 0 ? "pass" : "\(diagnosticsIssueCount)"
    }

    var diagnosticsRunColor: Color {
        guard let diagnosticsIssueCount = self.diagnosticsStore.issueCount else { return .secondary }
        return diagnosticsIssueCount == 0 ? OpenClawBrand.ok : OpenClawBrand.warn
    }

    var privacyDetail: String {
        let location = OpenClawLocationMode(rawValue: self.locationModeRaw) ?? .off
        return location == .off ? "Location off" : "Location \(self.locationLabel)"
    }

    var locationLabel: String {
        switch OpenClawLocationMode(rawValue: self.locationModeRaw) ?? .off {
        case .off: "Off"
        case .whileUsing: "While Using"
        case .always: "Always"
        }
    }

    var notificationStatusText: String {
        self.notificationStore.status.text
    }

    var notificationActionText: String {
        self.notificationStore.status.actionTitle
    }

    var notificationStatusDetail: String {
        switch self.notificationStore.status {
        case .checking:
            "Checking iOS notification permission."
        case .allowed:
            "OpenClaw can show approval prompts and event alerts when the app is not active."
        case .notAllowed:
            "Notifications have been denied. Enable them in iOS Settings."
        case .notSet:
            "Enable notifications to receive approval prompts and event alerts outside the app."
        case .unknown:
            "OpenClaw cannot determine the current notification permission state."
        }
    }

    var notificationRelayDetail: String {
        if PushBuildConfig.current.usesOpenClawHostedRelay {
            let host = PushBuildConfig.current.relayBaseURL.flatMap {
                URLComponents(url: $0, resolvingAgainstBaseURL: false)?.host
            } ?? "ios-push-relay.openclaw.ai"
            return """
            This build uses OpenClaw's hosted push relay at \(host) for notification \
            delivery data.
            """
        }
        return "This build is not configured to use OpenClaw's hosted push relay."
    }

    var notificationRelayDisclosureMessage: String {
        "Enabling this sends delivery data through OpenClaw's hosted push relay."
    }
}
