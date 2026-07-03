import ComposableArchitecture
import OpenClawKit
import SwiftUI

@Reducer
struct SettingsNavigationFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var navigationPath: [SettingsRoute] = []

        static func title(for route: SettingsRoute) -> String {
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

        static func subtitle(for route: SettingsRoute) -> String {
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
    }

    enum Action: Equatable, Sendable {
        case initialRouteRequested(SettingsRoute?)
        case navigationPathChanged([SettingsRoute])
        case routeOpened(SettingsRoute)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .initialRouteRequested(route):
                guard let route else { return .none }
                guard state.navigationPath != [route] else { return .none }
                state.navigationPath = [route]
                return .none

            case let .navigationPathChanged(navigationPath):
                state.navigationPath = navigationPath
                return .none

            case let .routeOpened(route):
                state.navigationPath = [route]
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct SettingsPresentationFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var scannerError: String?
        var showGatewayProblemDetails = false
        var showNotificationRelayDisclosure = false
        var showQRScanner = false
        var showResetOnboardingAlert = false
        var showTalkIssueDetails = false
    }

    enum Action: Equatable, Sendable {
        case gatewayProblemDetailsButtonTapped
        case gatewayProblemDetailsDismissed
        case notificationRelayDisclosureRequested
        case notificationRelayDisclosureDismissed
        case qrScannerButtonTapped
        case qrScannerDismissed
        case qrScannerErrorDismissed
        case qrScannerErrorReceived(String)
        case resetOnboardingButtonTapped
        case resetOnboardingAlertDismissed
        case talkIssueDetailsButtonTapped
        case talkIssueDetailsDismissed
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .gatewayProblemDetailsButtonTapped:
                state.showGatewayProblemDetails = true
                return .none

            case .gatewayProblemDetailsDismissed:
                state.showGatewayProblemDetails = false
                return .none

            case .notificationRelayDisclosureRequested:
                state.showNotificationRelayDisclosure = true
                return .none

            case .notificationRelayDisclosureDismissed:
                state.showNotificationRelayDisclosure = false
                return .none

            case .qrScannerButtonTapped:
                state.showQRScanner = true
                return .none

            case .qrScannerDismissed:
                state.showQRScanner = false
                return .none

            case .qrScannerErrorDismissed:
                state.scannerError = nil
                return .none

            case let .qrScannerErrorReceived(error):
                state.showQRScanner = false
                state.scannerError = error
                return .none

            case .resetOnboardingButtonTapped:
                state.showResetOnboardingAlert = true
                return .none

            case .resetOnboardingAlertDismissed:
                state.showResetOnboardingAlert = false
                return .none

            case .talkIssueDetailsButtonTapped:
                state.showTalkIssueDetails = true
                return .none

            case .talkIssueDetailsDismissed:
                state.showTalkIssueDetails = false
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct SettingsApprovalsFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var activeAgentName = "Default Agent"
        var gatewayConnected = false
        var hasPendingApproval = false
        var isAppleReviewDemoModeEnabled = false
        var isResolvingPendingApproval = false
        var notificationsNeedAttention = false
        var pendingApprovalAllowsAllowAlways = false
        var pendingCommandPreview: String?

        var approvalBadgeValue: String? {
            self.hasPendingApproval ? "1" : nil
        }

        var approvalEmptyDetail: String {
            if self.isAppleReviewDemoModeEnabled {
                return "Live gateway requests are disabled in demo mode."
            }
            if self.notificationsNeedAttention {
                return "Foreground approvals still appear while OpenClaw is connected."
            }
            return self.gatewayConnected ? "Gateway requests will appear here." : "Connect to the gateway."
        }

        var approvalsDetail: String {
            if self.notificationsNeedAttention {
                return self.hasPendingApproval ? "1 waiting, notifications off" : "Notifications off"
            }
            return self.hasPendingApproval ? "1 request waiting" : "No approvals waiting"
        }

        var destinationDetail: String {
            if self.notificationsNeedAttention {
                return "Out-of-app approval alerts need notification permission."
            }
            return self.hasPendingApproval
                ? "Review the pending gateway action."
                : "No gateway actions are waiting for review."
        }

        var destinationValue: String {
            if self.notificationsNeedAttention { return "Alerts Off" }
            return self.hasPendingApproval ? "1 waiting" : "clear"
        }

        var destinationColor: Color {
            if self.notificationsNeedAttention { return OpenClawBrand.warn }
            return self.hasPendingApproval ? OpenClawBrand.warn : OpenClawBrand.ok
        }

        var listColor: Color {
            self.hasPendingApproval ? OpenClawBrand.warn : .secondary
        }

        var approvalItems: [SettingsApprovalItem] {
            guard self.hasPendingApproval else { return [] }
            return [
                SettingsApprovalItem(
                    id: "pending-real",
                    icon: "terminal.fill",
                    title: self.pendingCommandPreview ?? "Review gateway action",
                    detail: "Agent: \(self.activeAgentName)",
                    priority: self.isResolvingPendingApproval ? "Resolving" : "High",
                    color: OpenClawBrand.danger),
                SettingsApprovalItem(
                    id: "pending-context",
                    icon: "doc.text.fill",
                    title: self.pendingApprovalAllowsAllowAlways ? "Permission can be saved" : "One-time approval",
                    detail: "Gateway request",
                    priority: self.pendingApprovalAllowsAllowAlways ? "Medium" : "Review",
                    color: OpenClawBrand.warn),
            ]
        }
    }

    enum Action: Equatable, Sendable {
        case approvalsSynced(
            isAppleReviewDemoModeEnabled: Bool,
            gatewayConnected: Bool,
            notificationsNeedAttention: Bool,
            hasPendingApproval: Bool,
            pendingCommandPreview: String?,
            activeAgentName: String,
            isResolvingPendingApproval: Bool,
            pendingApprovalAllowsAllowAlways: Bool)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .approvalsSynced(
                isAppleReviewDemoModeEnabled,
                gatewayConnected,
                notificationsNeedAttention,
                hasPendingApproval,
                pendingCommandPreview,
                activeAgentName,
                isResolvingPendingApproval,
                pendingApprovalAllowsAllowAlways):
                state.isAppleReviewDemoModeEnabled = isAppleReviewDemoModeEnabled
                state.gatewayConnected = gatewayConnected
                state.notificationsNeedAttention = notificationsNeedAttention
                state.hasPendingApproval = hasPendingApproval
                state.pendingCommandPreview = pendingCommandPreview
                state.activeAgentName = activeAgentName
                state.isResolvingPendingApproval = isResolvingPendingApproval
                state.pendingApprovalAllowsAllowAlways = pendingApprovalAllowsAllowAlways
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct SettingsGatewayActivityFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var isReconnectingGateway = false
        var isRefreshingGateway = false
    }

    enum Action: Equatable, Sendable {
        case reconnectFinished
        case reconnectStarted
        case refreshFinished
        case refreshStarted
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .reconnectFinished:
                state.isReconnectingGateway = false
                return .none

            case .reconnectStarted:
                state.isReconnectingGateway = true
                return .none

            case .refreshFinished:
                state.isRefreshingGateway = false
                return .none

            case .refreshStarted:
                state.isRefreshingGateway = true
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct SettingsGatewaySetupLinkFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var applyResult: ApplyResult?
        var scannedGatewayLinkStatusText: String?
        var setupCode = ""
        var setupLinkStatusText: String?
        var stagedGatewaySetupLink: GatewayConnectDeepLink?

        var canApplyGatewaySetup: Bool {
            !self.setupCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || self.stagedGatewaySetupLink != nil
        }
    }

    enum ApplyResult: Equatable, Sendable {
        case appleReviewDemo(statusText: String)
        case failure(String)
        case gatewayLink(GatewayConnectDeepLink)
    }

    enum Action: Equatable, Sendable {
        case applyRequested
        case applyResultHandled
        case scannedGatewayLinkReceived(GatewayConnectDeepLink)
        case scannedGatewayLinkStatusHandled
        case scannedSetupCodeReceived(String)
        case setupCodeChanged(String)
        case setupCodeSynced(String)
        case setupLinkStaged(GatewayConnectDeepLink?)
        case setupLinkStatusHandled
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .applyRequested:
                let raw = state.setupCode.trimmingCharacters(in: .whitespacesAndNewlines)
                let stagedLink = state.stagedGatewaySetupLink
                guard !raw.isEmpty || stagedLink != nil else {
                    state.applyResult = .failure("Paste a setup code to continue.")
                    return .none
                }

                if AppleReviewDemoMode.isSetupCode(raw) {
                    state.setupCode = ""
                    state.stagedGatewaySetupLink = nil
                    state.applyResult = .appleReviewDemo(statusText: Self.appleReviewDemoStatusText)
                    return .none
                }

                guard let link = raw.isEmpty ? stagedLink : GatewayConnectDeepLink.fromSetupInput(raw) else {
                    state.applyResult = .failure("Setup code not recognized or uses an insecure ws:// gateway URL.")
                    return .none
                }
                state.stagedGatewaySetupLink = nil
                state.applyResult = .gatewayLink(link)
                return .none

            case .applyResultHandled:
                state.applyResult = nil
                return .none

            case let .scannedGatewayLinkReceived(link):
                state.applyResult = nil
                state.setupCode = ""
                state.stagedGatewaySetupLink = nil
                state.scannedGatewayLinkStatusText = Self.scannedGatewayLinkStatusText(link)
                state.applyResult = .gatewayLink(link)
                return .none

            case .scannedGatewayLinkStatusHandled:
                state.scannedGatewayLinkStatusText = nil
                return .none

            case let .scannedSetupCodeReceived(code):
                state.applyResult = nil
                guard AppleReviewDemoMode.isSetupCode(code) else {
                    return .none
                }
                state.setupCode = ""
                state.stagedGatewaySetupLink = nil
                state.applyResult = .appleReviewDemo(statusText: Self.appleReviewDemoStatusText)
                return .none

            case let .setupCodeChanged(setupCode):
                state.setupCode = setupCode
                if !setupCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    state.stagedGatewaySetupLink = nil
                }
                return .none

            case let .setupCodeSynced(setupCode):
                state.setupCode = setupCode
                if !setupCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    state.stagedGatewaySetupLink = nil
                }
                return .none

            case let .setupLinkStaged(link):
                state.stagedGatewaySetupLink = link
                if let link {
                    state.setupCode = ""
                    state.setupLinkStatusText = Self.setupLinkLoadedStatusText(link)
                } else {
                    state.setupLinkStatusText = nil
                }
                return .none

            case .setupLinkStatusHandled:
                state.setupLinkStatusText = nil
                return .none
            }
        }
        .autoLogActions()
    }

    private static func setupLinkLoadedStatusText(_ link: GatewayConnectDeepLink) -> String {
        let security = link.tls ? "TLS" : "plain"
        return "Setup link loaded for \(link.host):\(link.port) (\(security)). Tap Connect to apply."
    }

    private static func scannedGatewayLinkStatusText(_ link: GatewayConnectDeepLink) -> String {
        "QR loaded. Connecting to \(link.host):\(link.port)..."
    }

    private static let appleReviewDemoStatusText = "Apple Review demo mode enabled."
}

struct SettingsGatewayCredentialsPersistenceClient {
    var saveGatewayPassword: @MainActor @Sendable (_ value: String, _ instanceId: String) -> Void
    var saveGatewayToken: @MainActor @Sendable (_ value: String, _ instanceId: String) -> Void
}

extension SettingsGatewayCredentialsPersistenceClient: DependencyKey {
    static let liveValue = SettingsGatewayCredentialsPersistenceClient(
        saveGatewayPassword: { value, instanceId in
            GatewaySettingsStore.saveGatewayPassword(value, instanceId: instanceId)
        },
        saveGatewayToken: { value, instanceId in
            GatewaySettingsStore.saveGatewayToken(value, instanceId: instanceId)
        })

    static let testValue = SettingsGatewayCredentialsPersistenceClient(
        saveGatewayPassword: { _, _ in },
        saveGatewayToken: { _, _ in })
}

extension DependencyValues {
    var settingsGatewayCredentialsPersistence: SettingsGatewayCredentialsPersistenceClient {
        get { self[SettingsGatewayCredentialsPersistenceClient.self] }
        set { self[SettingsGatewayCredentialsPersistenceClient.self] = newValue }
    }
}

@Reducer
struct SettingsGatewayCredentialsFeature {
    private let persistenceClientOverride: SettingsGatewayCredentialsPersistenceClient?

    init(persistenceClient: SettingsGatewayCredentialsPersistenceClient? = nil) {
        self.persistenceClientOverride = persistenceClient
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var gatewayToken = ""
        var gatewayPassword = ""
        var pendingManualAuthOverride: GatewayConnectionController.ManualAuthOverride?
        var setupAuthPersistenceRequest: GatewayConnectionController.ManualAuthOverride.SetupAuth?
    }

    enum Action: Equatable, Sendable {
        case credentialsClearedForOnboardingReset
        case credentialsLoaded(token: String, password: String)
        case gatewayPasswordChanged(String)
        case gatewayPasswordPersistenceRequested(value: String, instanceId: String)
        case gatewayTokenChanged(String)
        case gatewayTokenPersistenceRequested(value: String, instanceId: String)
        case pendingManualAuthOverrideConsumed
        case setupAuthApplied(GatewayConnectionController.ManualAuthOverride.SetupAuth)
        case setupAuthPersistenceRequestHandled
        case setupLinkApplied(GatewayConnectDeepLink)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.settingsGatewayCredentialsPersistence) var dependencyPersistenceClient
            let persistenceClient = self.persistenceClientOverride ?? dependencyPersistenceClient

            switch action {
            case .credentialsClearedForOnboardingReset:
                state.gatewayToken = ""
                state.gatewayPassword = ""
                state.pendingManualAuthOverride = nil
                return .none

            case let .credentialsLoaded(token, password):
                state.gatewayToken = token
                state.gatewayPassword = password
                return .none

            case let .gatewayPasswordChanged(password):
                state.gatewayPassword = password
                return .none

            case let .gatewayPasswordPersistenceRequested(value, instanceId):
                guard let request = Self.manualCredentialPersistenceRequest(value: value, instanceId: instanceId)
                else { return .none }
                return .run { _ in
                    await persistenceClient.saveGatewayPassword(request.value, request.instanceId)
                }

            case let .gatewayTokenChanged(token):
                state.gatewayToken = token
                return .none

            case let .gatewayTokenPersistenceRequested(value, instanceId):
                guard let request = Self.manualCredentialPersistenceRequest(value: value, instanceId: instanceId)
                else { return .none }
                return .run { _ in
                    await persistenceClient.saveGatewayToken(request.value, request.instanceId)
                }

            case .pendingManualAuthOverrideConsumed:
                state.pendingManualAuthOverride = nil
                return .none

            case let .setupAuthApplied(setupAuth):
                Self.applySetupAuth(setupAuth, to: &state)
                return .none

            case .setupAuthPersistenceRequestHandled:
                state.setupAuthPersistenceRequest = nil
                return .none

            case let .setupLinkApplied(link):
                let setupAuth = GatewayConnectionController.ManualAuthOverride.setupAuth(from: link)
                Self.applySetupAuth(setupAuth, to: &state)
                state.setupAuthPersistenceRequest = setupAuth
                return .none
            }
        }
        .autoLogActions()
    }

    private static func applySetupAuth(
        _ setupAuth: GatewayConnectionController.ManualAuthOverride.SetupAuth,
        to state: inout State)
    {
        if setupAuth.shouldApplyTokenField {
            state.gatewayToken = setupAuth.token
        }
        if setupAuth.shouldApplyPasswordField {
            state.gatewayPassword = setupAuth.password
        }
        state.pendingManualAuthOverride = setupAuth.manualAuthOverride
    }

    private static func manualCredentialPersistenceRequest(
        value: String,
        instanceId: String)
        -> (value: String, instanceId: String)?
    {
        let trimmedInstanceId = instanceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInstanceId.isEmpty else { return nil }
        return (
            value.trimmingCharacters(in: .whitespacesAndNewlines),
            trimmedInstanceId)
    }
}

@Reducer
struct SettingsAgentSelectionFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var selectedAgentPickerId = ""
    }

    enum Action: Equatable, Sendable {
        case pickerSelectionChanged(String)
        case selectedAgentSynced(String?)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .pickerSelectionChanged(selectedAgentPickerId):
                state.selectedAgentPickerId = selectedAgentPickerId
                return .none

            case let .selectedAgentSynced(selectedAgentId):
                state.selectedAgentPickerId = selectedAgentId ?? ""
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct SettingsShareInstructionFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var defaultShareInstruction = ""
    }

    enum Action: Equatable, Sendable {
        case defaultShareInstructionChanged(String)
        case defaultShareInstructionLoaded(String)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .defaultShareInstructionChanged(instruction):
                state.defaultShareInstruction = instruction
                return .none

            case let .defaultShareInstructionLoaded(instruction):
                state.defaultShareInstruction = instruction
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct SettingsManualGatewayPortFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var manualGatewayPortResolutionResult: ManualGatewayPortResolutionResult?
        var manualGatewayPort = 18789
        var manualGatewayPortText = "18789"

        var isManualPortValid: Bool {
            if self.manualGatewayPortText.isEmpty { return true }
            return self.manualGatewayPort >= 1 && self.manualGatewayPort <= 65535
        }

        func resolvedManualPort(host: String, useTLS: Bool) -> Int? {
            Self.resolvedManualPort(
                manualGatewayPort: self.manualGatewayPort,
                host: host,
                useTLS: useTLS)
        }

        static func resolvedManualPort(manualGatewayPort: Int, host: String, useTLS: Bool) -> Int? {
            if manualGatewayPort > 0 {
                return manualGatewayPort <= 65535 ? manualGatewayPort : nil
            }
            let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            if useTLS, trimmed.lowercased().hasSuffix(".ts.net") {
                return 443
            }
            return 18789
        }
    }

    enum ManualGatewayPortResolutionResult: Equatable, Sendable {
        case failure(String)
        case resolved
    }

    enum Action: Equatable, Sendable {
        case manualGatewayPortResolutionRequested(host: String, useTLS: Bool)
        case manualGatewayPortResolutionResultHandled
        case manualGatewayPortSynced(Int)
        case manualGatewayPortTextChanged(String)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .manualGatewayPortResolutionRequested(host, useTLS):
                state.manualGatewayPortResolutionResult = nil
                guard state.resolvedManualPort(host: host, useTLS: useTLS) != nil else {
                    state.manualGatewayPortResolutionResult = .failure("Failed: invalid port")
                    return .none
                }
                state.manualGatewayPortResolutionResult = .resolved
                return .none

            case .manualGatewayPortResolutionResultHandled:
                state.manualGatewayPortResolutionResult = nil
                return .none

            case let .manualGatewayPortSynced(port):
                state.manualGatewayPort = port
                state.manualGatewayPortText = port > 0 ? String(port) : ""
                return .none

            case let .manualGatewayPortTextChanged(text):
                let filtered = text.filter(\.isNumber)
                state.manualGatewayPortText = filtered
                state.manualGatewayPort = Int(filtered) ?? 0
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct SettingsGatewayAutoConnectFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var isEnabled = false
    }

    enum Action: Equatable, Sendable {
        case disabledForOnboardingReset
        case enabledChanged(Bool)
        case enabledSynced(Bool)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .disabledForOnboardingReset:
                state.isEnabled = false
                return .none

            case let .enabledChanged(enabled):
                state.isEnabled = enabled
                return .none

            case let .enabledSynced(enabled):
                state.isEnabled = enabled
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct SettingsOnboardingStateFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var hasConnectedOnce = false
        var onboardingComplete = false
        var onboardingRequestID = 0
    }

    enum Action: Equatable, Sendable {
        case completionStateReset
        case onboardingRequestAdvanced
        case onboardingRequestIDChanged(Int)
        case onboardingStateSynced(
            hasConnectedOnce: Bool,
            onboardingComplete: Bool,
            onboardingRequestID: Int)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .completionStateReset:
                state.hasConnectedOnce = false
                state.onboardingComplete = false
                return .none

            case .onboardingRequestAdvanced:
                state.onboardingRequestID += 1
                return .none

            case let .onboardingRequestIDChanged(requestID):
                state.onboardingRequestID = requestID
                return .none

            case let .onboardingStateSynced(hasConnectedOnce, onboardingComplete, onboardingRequestID):
                state.hasConnectedOnce = hasConnectedOnce
                state.onboardingComplete = onboardingComplete
                state.onboardingRequestID = onboardingRequestID
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct SettingsAppearanceFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var appearancePreferenceRaw = AppAppearancePreference.system.rawValue

        var appearancePreference: AppAppearancePreference {
            AppAppearancePreference(rawValue: self.appearancePreferenceRaw) ?? .system
        }
    }

    enum Action: Equatable, Sendable {
        case appearancePreferenceChanged(String)
        case appearancePreferenceSynced(String)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .appearancePreferenceChanged(rawValue):
                state.appearancePreferenceRaw = rawValue
                return .none

            case let .appearancePreferenceSynced(rawValue):
                state.appearancePreferenceRaw = rawValue
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct SettingsDeviceIdentityFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var displayName = "iOS Node"
        var instanceId = ""
    }

    enum Action: Equatable, Sendable {
        case displayNameChanged(String)
        case displayNameSynced(String)
        case instanceIdSynced(String)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .displayNameChanged(displayName):
                state.displayName = displayName
                return .none

            case let .displayNameSynced(displayName):
                state.displayName = displayName
                return .none

            case let .instanceIdSynced(instanceId):
                state.instanceId = instanceId
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct SettingsDebugOptionsFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var canvasDebugStatusEnabled = false
        var discoveryDebugLogsEnabled = false
    }

    enum Action: Equatable, Sendable {
        case canvasDebugStatusChanged(Bool)
        case debugOptionsSynced(discoveryDebugLogsEnabled: Bool, canvasDebugStatusEnabled: Bool)
        case discoveryDebugLogsChanged(Bool)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .canvasDebugStatusChanged(enabled):
                state.canvasDebugStatusEnabled = enabled
                return .none

            case let .debugOptionsSynced(discoveryDebugLogsEnabled, canvasDebugStatusEnabled):
                state.discoveryDebugLogsEnabled = discoveryDebugLogsEnabled
                state.canvasDebugStatusEnabled = canvasDebugStatusEnabled
                return .none

            case let .discoveryDebugLogsChanged(enabled):
                state.discoveryDebugLogsEnabled = enabled
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct SettingsVoiceControlFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var talkEnabled = false
        var voiceWakeEnabled = false
        var voiceWakeStatusText = "Off"

        var detailText: String {
            if self.talkEnabled, self.voiceWakeEnabled { return "Talk + Wake" }
            if self.talkEnabled { return "Talk on" }
            if self.voiceWakeEnabled { return "Wake on" }
            return "Off"
        }

        var detailColor: Color {
            self.talkEnabled || self.voiceWakeEnabled ? OpenClawBrand.accent : .secondary
        }

        var voiceWakeValue: String {
            self.voiceWakeEnabled ? "on" : "off"
        }

        var voiceWakeColor: Color {
            self.voiceWakeEnabled ? OpenClawBrand.ok : .secondary
        }
    }

    enum Action: Equatable, Sendable {
        case controlsSynced(
            talkEnabled: Bool,
            voiceWakeEnabled: Bool,
            voiceWakeStatusText: String)
        case talkDisabledForAppleReview
        case talkEnabledChanged(Bool)
        case talkEnabledChangeRequested(enabled: Bool, isAppleReviewDemoModeEnabled: Bool)
        case voiceWakeEnabledChanged(Bool)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .controlsSynced(talkEnabled, voiceWakeEnabled, voiceWakeStatusText):
                state.talkEnabled = talkEnabled
                state.voiceWakeEnabled = voiceWakeEnabled
                state.voiceWakeStatusText = voiceWakeStatusText
                return .none

            case .talkDisabledForAppleReview:
                state.talkEnabled = false
                return .none

            case let .talkEnabledChanged(enabled):
                state.talkEnabled = enabled
                return .none

            case let .talkEnabledChangeRequested(enabled, isAppleReviewDemoModeEnabled):
                state.talkEnabled = isAppleReviewDemoModeEnabled ? false : enabled
                return .none

            case let .voiceWakeEnabledChanged(enabled):
                state.voiceWakeEnabled = enabled
                return .none
            }
        }
        .autoLogActions()
    }
}

struct SettingsProTab: View {
    @Environment(NodeAppModel.self) var appModel
    @Environment(VoiceWakeManager.self) var voiceWake
    @Environment(GatewayConnectionController.self) var gatewayController
    @Environment(\.scenePhase) var scenePhase
    @AppStorage(AppAppearancePreference.storageKey) var storedAppearancePreferenceRaw: String =
        AppAppearancePreference.system.rawValue
    @AppStorage("node.displayName") var storedDisplayName: String = "iOS Node"
    @AppStorage("node.instanceId") var storedInstanceId: String = UUID().uuidString
    @AppStorage("camera.enabled") var storedCameraEnabled: Bool = true
    @AppStorage("location.enabledMode") var storedLocationModeRaw: String = OpenClawLocationMode.off.rawValue
    @AppStorage("screen.preventSleep") var storedPreventSleep: Bool = true
    @AppStorage("talk.enabled") var storedTalkEnabled: Bool = false
    @AppStorage(TalkModeProviderSelection.storageKey) var storedTalkProviderSelectionRaw: String =
        TalkModeProviderSelection.gatewayDefault.rawValue
    @AppStorage(TalkModeRealtimeVoiceSelection.storageKey) var storedTalkRealtimeVoiceSelectionRaw: String = ""
    @AppStorage(TalkSpeechLocale.storageKey) var storedTalkSpeechLocale: String = TalkSpeechLocale.automaticID
    @AppStorage("talk.button.enabled") var storedTalkButtonEnabled: Bool = true
    @AppStorage("talk.background.enabled") var storedTalkBackgroundEnabled: Bool = false
    @AppStorage(TalkDefaults.speakerphoneEnabledKey) var storedTalkSpeakerphoneEnabled: Bool =
        TalkDefaults.speakerphoneEnabledByDefault
    @AppStorage(VoiceWakePreferences.enabledKey) var storedVoiceWakeEnabled: Bool = false
    @AppStorage("gateway.autoconnect") var storedGatewayAutoConnect: Bool = false
    @AppStorage("gateway.manual.enabled") var storedManualGatewayEnabled: Bool = false
    @AppStorage("gateway.manual.host") var storedManualGatewayHost: String = ""
    @AppStorage("gateway.manual.port") var storedManualGatewayPort: Int = 18789
    @AppStorage("gateway.manual.tls") var storedManualGatewayTLS: Bool = true
    @AppStorage("gateway.discovery.debugLogs") var storedDiscoveryDebugLogsEnabled: Bool = false
    @AppStorage("canvas.debugStatusEnabled") var storedCanvasDebugStatusEnabled: Bool = false
    @AppStorage("gateway.setupCode") var storedSetupCode: String = ""
    @AppStorage("gateway.onboardingComplete") var storedOnboardingComplete: Bool = false
    @AppStorage("gateway.hasConnectedOnce") var storedHasConnectedOnce: Bool = false
    @AppStorage("onboarding.requestID") var storedOnboardingRequestID: Int = 0
    @State var pushEnrollmentConsentStore = Store(initialState: PushEnrollmentConsentFeature.State()) {
        PushEnrollmentConsentFeature()
    }

    @State var execApprovalPromptStore: StoreOf<ExecApprovalPromptFeature>

    @State var approvalsStore: StoreOf<SettingsApprovalsFeature> = Store(
        initialState: SettingsApprovalsFeature.State())
    {
        SettingsApprovalsFeature()
    }

    @State var agentSelectionStore: StoreOf<SettingsAgentSelectionFeature> = Store(
        initialState: SettingsAgentSelectionFeature.State())
    {
        SettingsAgentSelectionFeature()
    }

    @State var shareInstructionStore: StoreOf<SettingsShareInstructionFeature> = Store(
        initialState: SettingsShareInstructionFeature.State())
    {
        SettingsShareInstructionFeature()
    }

    @State var manualGatewayPortStore: StoreOf<SettingsManualGatewayPortFeature> = Store(
        initialState: SettingsManualGatewayPortFeature.State())
    {
        SettingsManualGatewayPortFeature()
    }

    @State var manualGatewayEndpointStore: StoreOf<SettingsManualGatewayEndpointFeature> = Store(
        initialState: SettingsManualGatewayEndpointFeature.State())
    {
        SettingsManualGatewayEndpointFeature()
    }

    @State var diagnosticsStore: StoreOf<SettingsDiagnosticsFeature> = Store(
        initialState: SettingsDiagnosticsFeature.State())
    {
        SettingsDiagnosticsFeature()
    }

    @State var appearanceStore: StoreOf<SettingsAppearanceFeature> = Store(
        initialState: SettingsAppearanceFeature.State())
    {
        SettingsAppearanceFeature()
    }

    @State var deviceCapabilityStore: StoreOf<SettingsDeviceCapabilityFeature> = Store(
        initialState: SettingsDeviceCapabilityFeature.State())
    {
        SettingsDeviceCapabilityFeature()
    }

    @State var deviceIdentityStore: StoreOf<SettingsDeviceIdentityFeature> = Store(
        initialState: SettingsDeviceIdentityFeature.State())
    {
        SettingsDeviceIdentityFeature()
    }

    @State var debugOptionsStore: StoreOf<SettingsDebugOptionsFeature> = Store(
        initialState: SettingsDebugOptionsFeature.State())
    {
        SettingsDebugOptionsFeature()
    }

    @State var voiceControlStore: StoreOf<SettingsVoiceControlFeature> = Store(
        initialState: SettingsVoiceControlFeature.State())
    {
        SettingsVoiceControlFeature()
    }

    @State var talkPreferencesStore: StoreOf<SettingsTalkPreferencesFeature> = Store(
        initialState: SettingsTalkPreferencesFeature.State())
    {
        SettingsTalkPreferencesFeature()
    }

    @State var gatewayActivityStore: StoreOf<SettingsGatewayActivityFeature> = Store(
        initialState: SettingsGatewayActivityFeature.State())
    {
        SettingsGatewayActivityFeature()
    }

    @State var gatewayAutoConnectStore: StoreOf<SettingsGatewayAutoConnectFeature> = Store(
        initialState: SettingsGatewayAutoConnectFeature.State())
    {
        SettingsGatewayAutoConnectFeature()
    }

    @State var onboardingStateStore: StoreOf<SettingsOnboardingStateFeature> = Store(
        initialState: SettingsOnboardingStateFeature.State())
    {
        SettingsOnboardingStateFeature()
    }

    @State var gatewayConnectionStore: StoreOf<SettingsGatewayConnectionFeature> = Store(
        initialState: SettingsGatewayConnectionFeature.State())
    {
        SettingsGatewayConnectionFeature()
    }

    @State var gatewaySetupStatusStore: StoreOf<SettingsGatewaySetupStatusFeature> = Store(
        initialState: SettingsGatewaySetupStatusFeature.State())
    {
        SettingsGatewaySetupStatusFeature()
    }

    @State var gatewaySetupLinkStore: StoreOf<SettingsGatewaySetupLinkFeature> = Store(
        initialState: SettingsGatewaySetupLinkFeature.State())
    {
        SettingsGatewaySetupLinkFeature()
    }

    @State var gatewayCredentialsStore: StoreOf<SettingsGatewayCredentialsFeature> = Store(
        initialState: SettingsGatewayCredentialsFeature.State())
    {
        SettingsGatewayCredentialsFeature()
    }

    @State var locationStore: StoreOf<SettingsLocationFeature> = Store(
        initialState: SettingsLocationFeature.State())
    {
        SettingsLocationFeature()
    }

    @State var notificationStore: StoreOf<SettingsNotificationFeature> = Store(
        initialState: SettingsNotificationFeature.State())
    {
        SettingsNotificationFeature()
    }

    @State var presentationStore: StoreOf<SettingsPresentationFeature> = Store(
        initialState: SettingsPresentationFeature.State())
    {
        SettingsPresentationFeature()
    }

    @State private var navigationStore: StoreOf<SettingsNavigationFeature>
    let initialRoute: SettingsRoute?
    let directRoute: SettingsRoute?
    let headerLeadingAction: OpenClawSidebarHeaderAction?
    let ownsNavigationStack: Bool
    let navigateToRoute: ((SettingsRoute) -> Void)?
    let onRouteChange: ((SettingsRoute?) -> Void)?

    init(
        initialRoute: SettingsRoute? = nil,
        directRoute: SettingsRoute? = nil,
        headerLeadingAction: OpenClawSidebarHeaderAction? = nil,
        ownsNavigationStack: Bool = true,
        navigateToRoute: ((SettingsRoute) -> Void)? = nil,
        execApprovalPromptStore: StoreOf<ExecApprovalPromptFeature> = Store(
            initialState: ExecApprovalPromptFeature.State())
        {
            ExecApprovalPromptFeature()
        },
        navigationStore: StoreOf<SettingsNavigationFeature> = Store(
            initialState: SettingsNavigationFeature.State())
        {
            SettingsNavigationFeature()
        },
        onRouteChange: ((SettingsRoute?) -> Void)? = nil)
    {
        self.initialRoute = initialRoute
        self.directRoute = directRoute
        self.headerLeadingAction = headerLeadingAction
        self.ownsNavigationStack = ownsNavigationStack
        self.navigateToRoute = navigateToRoute
        self._execApprovalPromptStore = State(wrappedValue: execApprovalPromptStore)
        self._navigationStore = State(wrappedValue: navigationStore)
        self.onRouteChange = onRouteChange
    }

    var body: some View {
        self.settingsModalPresentation(
            self.settingsLifecycle(
                self.settingsContent))
    }

    var appearancePreference: AppAppearancePreference {
        self.appearanceStore.appearancePreference
    }

    @ViewBuilder
    private var settingsContent: some View {
        if let directRoute {
            self.destination(for: directRoute)
        } else {
            if self.ownsNavigationStack {
                self.settingsNavigationStack
            } else {
                self.settingsNavigationContent
            }
        }
    }

    private var settingsNavigationStack: some View {
        NavigationStack(path: self.navigationPathBinding) {
            self.settingsNavigationContent
        }
    }

    private var navigationPathBinding: Binding<[SettingsRoute]> {
        Binding(
            get: { self.navigationStore.navigationPath },
            set: { self.navigationStore.send(.navigationPathChanged($0)) })
    }

    private var settingsNavigationContent: some View {
        ZStack {
            OpenClawProBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    self.settingsHeader
                    self.appearanceSection
                    self.gatewaySection
                    self.settingsListSection
                }
                .padding(.top, 18)
                .padding(.bottom, 18)
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(for: SettingsRoute.self) { route in
            self.destination(for: route)
        }
    }

    private func settingsLifecycle(_ content: some View) -> some View {
        self.settingsTalkRuntimeLifecycle(
            self.settingsGatewaySetupStatusLifecycle(
                self.settingsApprovalLifecycle(
                    self.settingsBaseLifecycle(content))))
    }

    private func settingsBaseLifecycle(_ content: some View) -> some View {
        content
            .task {
                self.syncSettingsState()
                self.refreshNotificationSettings()
                self.applyPendingGatewaySetupLinkIfNeeded()
                self.applyInitialRouteIfNeeded()
                self.notifyRouteChange()
            }
            .onChange(of: self.scenePhase) { _, phase in
                if phase == .active {
                    self.syncSettingsState()
                    self.refreshNotificationSettings()
                }
            }
            .onChange(of: self.storedAppearancePreferenceRaw) { _, newValue in
                self.appearanceStore.send(.appearancePreferenceSynced(newValue))
            }
            .onChange(of: self.storedDisplayName) { _, newValue in
                self.deviceIdentityStore.send(.displayNameSynced(newValue))
            }
            .onChange(of: self.storedInstanceId) { _, newValue in
                self.deviceIdentityStore.send(.instanceIdSynced(newValue))
            }
            .onChange(of: self.storedDiscoveryDebugLogsEnabled) { _, newValue in
                self.debugOptionsStore.send(.discoveryDebugLogsChanged(newValue))
                self.gatewayController.setDiscoveryDebugLoggingEnabled(newValue)
            }
            .onChange(of: self.storedCanvasDebugStatusEnabled) { _, newValue in
                self.debugOptionsStore.send(.canvasDebugStatusChanged(newValue))
            }
            .onChange(of: self.storedLocationModeRaw) { _, newValue in
                self.locationStore.send(.locationModeChangeRequested(newValue))
                self.deviceCapabilityStore.send(.locationModeChanged(newValue))
                self.handleLocationModeRequest(self.locationStore.locationModeRequest)
            }
            .onChange(of: self.locationStore.locationModeApplyResult) { _, result in
                self.handleLocationModeApplyResult(result)
            }
            .onChange(of: self.manualGatewayPortStore.manualGatewayPort) { _, newValue in
                self.storedManualGatewayPort = newValue
            }
            .onChange(of: self.agentSelectionStore.selectedAgentPickerId) { _, newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                self.appModel.setSelectedAgentId(trimmed.isEmpty ? nil : trimmed)
            }
            .onChange(of: self.appModel.selectedAgentId ?? "") { _, newValue in
                if newValue != self.agentSelectionStore.selectedAgentPickerId {
                    self.agentSelectionStore.send(.selectedAgentSynced(newValue))
                }
            }
            .onChange(of: self.storedSetupCode) { _, newValue in
                self.gatewaySetupLinkStore.send(.setupCodeSynced(newValue))
            }
            .onChange(of: self.storedCameraEnabled) { _, newValue in
                self.deviceCapabilityStore.send(.cameraEnabledChanged(newValue))
            }
            .onChange(of: self.storedPreventSleep) { _, newValue in
                self.deviceCapabilityStore.send(.preventSleepChanged(newValue))
            }
            .onChange(of: self.storedTalkEnabled) { _, _ in
                self.syncVoiceControlState()
            }
            .onChange(of: self.storedVoiceWakeEnabled) { _, _ in
                self.syncVoiceControlState()
            }
            .onChange(of: self.appModel.voiceWake.statusText) { _, _ in
                self.syncVoiceControlState()
            }
            .onChange(of: self.storedTalkProviderSelectionRaw) { _, _ in
                self.syncTalkPreferencesState()
            }
            .onChange(of: self.storedTalkRealtimeVoiceSelectionRaw) { _, _ in
                self.syncTalkPreferencesState()
            }
            .onChange(of: self.storedTalkSpeechLocale) { _, _ in
                self.syncTalkPreferencesState()
            }
            .onChange(of: self.storedTalkButtonEnabled) { _, _ in
                self.syncTalkPreferencesState()
            }
            .onChange(of: self.storedTalkBackgroundEnabled) { _, _ in
                self.syncTalkPreferencesState()
            }
            .onChange(of: self.storedTalkSpeakerphoneEnabled) { _, _ in
                self.syncTalkPreferencesState()
            }
            .onChange(of: self.storedGatewayAutoConnect) { _, newValue in
                self.gatewayAutoConnectStore.send(.enabledSynced(newValue))
            }
            .onChange(of: self.storedOnboardingComplete) { _, _ in
                self.syncOnboardingState()
            }
            .onChange(of: self.storedHasConnectedOnce) { _, _ in
                self.syncOnboardingState()
            }
            .onChange(of: self.storedOnboardingRequestID) { _, _ in
                self.syncOnboardingState()
            }
            .onChange(of: self.shareInstructionStore.defaultShareInstruction) { _, newValue in
                ShareToAgentSettings.saveDefaultInstruction(newValue)
            }
            .onChange(of: self.appModel.gatewaySetupRequestID) { _, _ in
                self.applyPendingGatewaySetupLinkIfNeeded()
            }
            .onChange(of: self.navigationStore.navigationPath) { _, _ in
                self.notifyRouteChange()
            }
    }

    private func settingsApprovalLifecycle(_ content: some View) -> some View {
        content
            .onChange(of: self.notificationStore.needsAttention) { _, _ in
                self.syncApprovalState()
            }
            .onChange(of: self.notificationStore.authorizationRequestResult) { _, result in
                self.handleNotificationAuthorizationResult(result)
            }
            .onChange(of: self.notificationStore.statusRefreshResult) { _, status in
                self.handleNotificationStatusRefreshResult(status)
            }
            .onChange(of: self.appModel.pendingExecApprovalPrompt?.id) { _, _ in
                self.syncApprovalState()
            }
            .onChange(of: self.appModel.pendingExecApprovalPrompt?.commandPreview) { _, _ in
                self.syncApprovalState()
            }
            .onChange(of: self.appModel.pendingExecApprovalPrompt?.allowsAllowAlways) { _, _ in
                self.syncApprovalState()
            }
            .onChange(of: self.appModel.pendingExecApprovalPromptResolving) { _, _ in
                self.syncApprovalState()
            }
            .onChange(of: self.appModel.activeAgentName) { _, _ in
                self.syncApprovalState()
            }
    }

    private func settingsGatewaySetupStatusLifecycle(_ content: some View) -> some View {
        content
            .onChange(of: self.appModel.lastGatewayProblem?.message) { _, _ in
                self.syncGatewaySetupStatusContext()
                self.syncGatewayConnectionStatusState()
                self.syncDiagnosticsContextState()
            }
            .onChange(of: self.appModel.lastGatewayProblem?.statusText) { _, _ in
                self.syncGatewayConnectionStatusState()
                self.syncDiagnosticsContextState()
            }
            .onChange(of: self.appModel.lastGatewayProblem?.pauseReconnect) { _, _ in
                self.syncGatewayConnectionStatusState()
                self.syncDiagnosticsContextState()
            }
            .onChange(of: self.appModel.gatewayStatusText) { _, _ in
                self.syncGatewaySetupStatusContext()
                self.syncGatewayConnectionStatusState()
                self.syncDiagnosticsContextState()
            }
            .onChange(of: self.appModel.gatewayServerName) { _, _ in
                self.syncGatewayConnectionStatusState()
                self.syncDiagnosticsContextState()
            }
            .onChange(of: self.appModel.gatewayRemoteAddress) { _, _ in
                self.syncGatewayConnectionStatusState()
            }
            .onChange(of: self.appModel.isAppleReviewDemoModeEnabled) { _, _ in
                self.syncGatewayConnectionStatusState()
                self.syncDiagnosticsContextState()
            }
            .onChange(of: self.appModel.gatewayAgents.count) { _, _ in
                self.syncGatewayConnectionStatusState()
            }
            .onChange(of: self.gatewayController.gateways.count) { _, _ in
                self.syncDiagnosticsContextState()
            }
            .onChange(of: self.gatewayController.discoveryStatusText) { _, _ in
                self.syncDiagnosticsContextState()
            }
            .onChange(of: self.appModel.screenRecordActive) { _, _ in
                self.syncDiagnosticsContextState()
            }
    }

    private func settingsTalkRuntimeLifecycle(_ content: some View) -> some View {
        content
            .onChange(of: self.appModel.talkMode.gatewayTalkConfigLoaded) { _, _ in
                self.syncTalkRuntimeState()
            }
            .onChange(of: self.appModel.talkMode.gatewayTalkApiKeyConfigured) { _, _ in
                self.syncTalkRuntimeState()
            }
            .onChange(of: self.appModel.talkMode.gatewayTalkUsesRealtime) { _, _ in
                self.syncTalkRuntimeState()
            }
            .onChange(of: self.appModel.talkMode.gatewayTalkTransportLabel) { _, _ in
                self.syncTalkRuntimeState()
            }
            .onChange(of: self.appModel.isAppleReviewDemoModeEnabled) { _, _ in
                self.syncTalkRuntimeState()
            }
            .onChange(of: self.appModel.talkMode.gatewayTalkActiveModeTitle) { _, _ in
                self.syncTalkRuntimeState()
            }
            .onChange(of: self.appModel.talkMode.gatewayTalkActiveModeSubtitle) { _, _ in
                self.syncTalkRuntimeState()
            }
            .onChange(of: self.appModel.talkMode.gatewayTalkLastIssueText) { _, _ in
                self.syncTalkRuntimeState()
            }
    }

    private func settingsModalPresentation(_ content: some View) -> some View {
        content
            .sheet(isPresented: self.gatewayProblemDetailsBinding) {
                if let gatewayProblem = self.appModel.lastGatewayProblem {
                    GatewayProblemDetailsSheet(
                        problem: gatewayProblem,
                        primaryActionTitle: self.gatewayProblemPrimaryActionTitle(gatewayProblem),
                        onPrimaryAction: {
                            Task { await self.handleGatewayProblemPrimaryAction(gatewayProblem) }
                        })
                }
            }
            .sheet(isPresented: self.talkIssueDetailsBinding) {
                if let issue = self.appModel.talkMode.gatewayTalkCurrentFallbackIssue {
                    TalkRuntimeIssueDetailsSheet(issue: issue)
                }
            }
            .sheet(isPresented: self.qrScannerBinding) {
                NavigationStack {
                    QRScannerView(
                        onGatewayLink: { link in
                            self.handleScannedGatewayLink(link)
                        },
                        onSetupCode: { code in
                            self.handleScannedSetupCode(code)
                        },
                        onError: { error in
                            self.presentationStore.send(.qrScannerErrorReceived(error))
                            self.gatewaySetupStatusStore.send(.qrScannerErrorReceived(error))
                        },
                        onDismiss: {
                            self.presentationStore.send(.qrScannerDismissed)
                        })
                        .ignoresSafeArea()
                        .navigationTitle("Scan QR Code")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Cancel") { self.presentationStore.send(.qrScannerDismissed) }
                            }
                        }
                }
            }
            .sheet(isPresented: self.notificationRelayDisclosureBinding) {
                HostedPushRelayDisclosureSheet(
                    message: self.notificationRelayDisclosureMessage,
                    onContinue: self.requestNotificationAuthorizationFromSettings)
            }
            .alert("Reset Onboarding?", isPresented: self.resetOnboardingAlertBinding) {
                Button("Reset", role: .destructive) {
                    self.resetOnboarding()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This disconnects, clears saved gateway credentials, and reopens onboarding.")
            }
            .alert(
                "QR Scanner Unavailable",
                isPresented: self.qrScannerErrorBinding)
            {
                Button("OK", role: .cancel) {}
            } message: {
                Text(self.presentationStore.scannerError ?? "")
            }
    }

    func openNotificationsRouteFromApprovals() {
        guard self.directRoute == nil else { return }
        if !self.ownsNavigationStack, let navigateToRoute {
            navigateToRoute(.notifications)
            return
        }
        self.navigationStore.send(.routeOpened(.notifications))
    }

    private func applyInitialRouteIfNeeded() {
        guard self.directRoute == nil else { return }
        self.navigationStore.send(.initialRouteRequested(self.initialRoute))
    }

    private func notifyRouteChange() {
        if let directRoute {
            self.onRouteChange?(directRoute)
            return
        }
        self.onRouteChange?(self.navigationStore.navigationPath.last)
    }
}

extension SettingsProTab {
    var connectingGatewayID: String? {
        self.gatewayConnectionStore.connectingGatewayID
    }

    var setupStatusText: String? {
        self.gatewaySetupStatusStore.statusText
    }

    var stagedGatewaySetupLink: GatewayConnectDeepLink? {
        self.gatewaySetupLinkStore.stagedGatewaySetupLink
    }

    var defaultShareInstructionBinding: Binding<String> {
        Binding(
            get: { self.shareInstructionStore.defaultShareInstruction },
            set: { self.shareInstructionStore.send(.defaultShareInstructionChanged($0)) })
    }

    var agentSelectionBinding: Binding<String> {
        Binding(
            get: { self.agentSelectionStore.selectedAgentPickerId },
            set: { self.agentSelectionStore.send(.pickerSelectionChanged($0)) })
    }

    private var gatewayProblemDetailsBinding: Binding<Bool> {
        Binding(
            get: { self.presentationStore.showGatewayProblemDetails },
            set: { isPresented in
                if isPresented {
                    self.presentationStore.send(.gatewayProblemDetailsButtonTapped)
                } else {
                    self.presentationStore.send(.gatewayProblemDetailsDismissed)
                }
            })
    }

    private var talkIssueDetailsBinding: Binding<Bool> {
        Binding(
            get: { self.presentationStore.showTalkIssueDetails },
            set: { isPresented in
                if isPresented {
                    self.presentationStore.send(.talkIssueDetailsButtonTapped)
                } else {
                    self.presentationStore.send(.talkIssueDetailsDismissed)
                }
            })
    }

    private var resetOnboardingAlertBinding: Binding<Bool> {
        Binding(
            get: { self.presentationStore.showResetOnboardingAlert },
            set: { isPresented in
                if isPresented {
                    self.presentationStore.send(.resetOnboardingButtonTapped)
                } else {
                    self.presentationStore.send(.resetOnboardingAlertDismissed)
                }
            })
    }

    private var notificationRelayDisclosureBinding: Binding<Bool> {
        Binding(
            get: { self.presentationStore.showNotificationRelayDisclosure },
            set: { isPresented in
                if isPresented {
                    self.presentationStore.send(.notificationRelayDisclosureRequested)
                } else {
                    self.presentationStore.send(.notificationRelayDisclosureDismissed)
                }
            })
    }

    private var qrScannerBinding: Binding<Bool> {
        Binding(
            get: { self.presentationStore.showQRScanner },
            set: { isPresented in
                if isPresented {
                    self.presentationStore.send(.qrScannerButtonTapped)
                } else {
                    self.presentationStore.send(.qrScannerDismissed)
                }
            })
    }

    private var qrScannerErrorBinding: Binding<Bool> {
        Binding(
            get: { self.presentationStore.scannerError != nil },
            set: { isPresented in
                if !isPresented {
                    self.presentationStore.send(.qrScannerErrorDismissed)
                }
            })
    }
}

struct HostedPushRelayDisclosureSheet: View {
    @Environment(\.dismiss) private var dismiss
    let message: String
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: "network")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color(uiColor: .systemBlue))
                    Text("Enable OpenClaw Hosted Push Relay?")
                        .font(.title3.weight(.semibold))
                    Text(self.message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(spacing: 10) {
                Button {
                    self.dismiss()
                    self.onContinue()
                } label: {
                    Text("Continue").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button("Not Now", role: .cancel) {
                    self.dismiss()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
        }
        .tint(Color(uiColor: .systemBlue))
        .padding(24)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
