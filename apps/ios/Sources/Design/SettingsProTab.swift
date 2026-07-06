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
        struct InitialRouteRequest: Equatable, Sendable { var route: SettingsRoute? }

        struct NavigationPathChange: Equatable, Sendable { var path: [SettingsRoute] }

        struct RouteOpenRequest: Equatable, Sendable { var route: SettingsRoute }

        case initialRouteRequested(InitialRouteRequest)
        case navigationPathChanged(NavigationPathChange)
        case routeOpened(RouteOpenRequest)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .initialRouteRequested(request):
                guard let route = request.route else { return .none }
                guard state.navigationPath != [route] else { return .none }
                state.navigationPath = [route]
                return .none

            case let .navigationPathChanged(change):
                state.navigationPath = change.path
                return .none

            case let .routeOpened(request):
                state.navigationPath = [request.route]
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
        struct QRScannerError: Equatable, Sendable { var message: SettingsPresentationScannerErrorMessage }

        case gatewayProblemDetailsButtonTapped
        case gatewayProblemDetailsDismissed
        case notificationRelayDisclosureRequested
        case notificationRelayDisclosureDismissed
        case qrScannerButtonTapped
        case qrScannerDismissed
        case qrScannerErrorDismissed
        case qrScannerErrorReceived(QRScannerError)
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
                state.scannerError = error.message.value
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
        struct SettingsApprovalsDemoModeEnabled: Equatable, Sendable { var value: Bool }
        struct SettingsApprovalsGatewayConnected: Equatable, Sendable { var value: Bool }
        struct SettingsApprovalsNotificationsNeedAttention: Equatable, Sendable { var value: Bool }
        struct SettingsApprovalsHasPendingApproval: Equatable, Sendable { var value: Bool }
        struct SettingsApprovalsPendingCommandPreview: Equatable, Sendable { var value: String? }
        struct SettingsApprovalsActiveAgentName: Equatable, Sendable { var value: String }
        struct SettingsApprovalsResolvingPendingApproval: Equatable, Sendable { var value: Bool }
        struct SettingsApprovalsPendingApprovalAllowsAllowAlways: Equatable, Sendable { var value: Bool }

        struct ApprovalsSync: Equatable, Sendable {
            var isAppleReviewDemoModeEnabled: SettingsApprovalsDemoModeEnabled
            var gatewayConnected: SettingsApprovalsGatewayConnected
            var notificationsNeedAttention: SettingsApprovalsNotificationsNeedAttention
            var hasPendingApproval: SettingsApprovalsHasPendingApproval
            var pendingCommandPreview: SettingsApprovalsPendingCommandPreview
            var activeAgentName: SettingsApprovalsActiveAgentName
            var isResolvingPendingApproval: SettingsApprovalsResolvingPendingApproval
            var pendingApprovalAllowsAllowAlways: SettingsApprovalsPendingApprovalAllowsAllowAlways
        }

        case approvalsSynced(ApprovalsSync)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .approvalsSynced(sync):
                state.isAppleReviewDemoModeEnabled = sync.isAppleReviewDemoModeEnabled.value
                state.gatewayConnected = sync.gatewayConnected.value
                state.notificationsNeedAttention = sync.notificationsNeedAttention.value
                state.hasPendingApproval = sync.hasPendingApproval.value
                state.pendingCommandPreview = sync.pendingCommandPreview.value
                state.activeAgentName = sync.activeAgentName.value
                state.isResolvingPendingApproval = sync.isResolvingPendingApproval.value
                state.pendingApprovalAllowsAllowAlways = sync.pendingApprovalAllowsAllowAlways.value
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct SettingsGatewayActivityFeature {
    private let diagnosticsRefreshClientOverride: SettingsGatewayDiagnosticsRefreshClient?
    private let problemTrustClientOverride: SettingsGatewayProblemTrustClient?
    private let reconnectClientOverride: SettingsGatewayReconnectClient?

    init(
        diagnosticsRefreshClient: SettingsGatewayDiagnosticsRefreshClient? = nil,
        problemTrustClient: SettingsGatewayProblemTrustClient? = nil,
        reconnectClient: SettingsGatewayReconnectClient? = nil)
    {
        self.diagnosticsRefreshClientOverride = diagnosticsRefreshClient
        self.problemTrustClientOverride = problemTrustClient
        self.reconnectClientOverride = reconnectClient
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var isReconnectingGateway = false
        var isRefreshingGateway = false
    }

    enum Action: Equatable, Sendable {
        struct SettingsGatewayActivityDemoModeEnabled: Equatable, Sendable { var value: Bool }

        struct DiagnosticsRefreshRequest: Equatable, Sendable {
            var isAppleReviewDemoModeEnabled: SettingsGatewayActivityDemoModeEnabled
        }

        struct ReconnectRequest: Equatable, Sendable {
            var isAppleReviewDemoModeEnabled: SettingsGatewayActivityDemoModeEnabled
        }

        struct RotatedCertificateTrustRequest: Equatable, Sendable { var problem: GatewayConnectionProblem }

        case diagnosticsRefreshRequested(DiagnosticsRefreshRequest)
        case reconnectFinished
        case reconnectRequested(ReconnectRequest)
        case reconnectStarted
        case refreshFinished
        case refreshStarted
        case rotatedCertificateTrustRequested(RotatedCertificateTrustRequest)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.settingsGatewayDiagnosticsRefresh) var dependencyDiagnosticsRefreshClient
            @Dependency(\.settingsGatewayProblemTrust) var dependencyProblemTrustClient
            @Dependency(\.settingsGatewayReconnect) var dependencyReconnectClient
            let diagnosticsRefreshClient = self.diagnosticsRefreshClientOverride ?? dependencyDiagnosticsRefreshClient
            let problemTrustClient = self.problemTrustClientOverride ?? dependencyProblemTrustClient
            let reconnectClient = self.reconnectClientOverride ?? dependencyReconnectClient

            switch action {
            case let .diagnosticsRefreshRequested(request):
                guard !state.isRefreshingGateway else { return .none }
                state.isRefreshingGateway = true
                return .run { send in
                    if !request.isAppleReviewDemoModeEnabled.value {
                        await diagnosticsRefreshClient.refreshGateway()
                    }
                    await send(.refreshFinished)
                }

            case .reconnectFinished:
                state.isReconnectingGateway = false
                return .none

            case let .reconnectRequested(request):
                guard !request.isAppleReviewDemoModeEnabled.value, !state.isReconnectingGateway else { return .none }
                state.isReconnectingGateway = true
                return .run { send in
                    await reconnectClient.reconnect()
                    await send(.reconnectFinished)
                }

            case .reconnectStarted:
                state.isReconnectingGateway = true
                return .none

            case .refreshFinished:
                state.isRefreshingGateway = false
                return .none

            case .refreshStarted:
                state.isRefreshingGateway = true
                return .none

            case let .rotatedCertificateTrustRequested(request):
                return .run { _ in
                    _ = await problemTrustClient.trustRotatedCertificate(request.problem)
                }
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct SettingsGatewayCredentialsFeature {
    private let persistenceClientOverride: SettingsGatewayCredentialsPersistenceClient?
    private let setupAuthPersistenceClientOverride: SettingsGatewaySetupAuthPersistenceClient?

    init(
        persistenceClient: SettingsGatewayCredentialsPersistenceClient? = nil,
        setupAuthPersistenceClient: SettingsGatewaySetupAuthPersistenceClient? = nil)
    {
        self.persistenceClientOverride = persistenceClient
        self.setupAuthPersistenceClientOverride = setupAuthPersistenceClient
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var gatewayToken = ""
        var gatewayPassword = ""
        var pendingManualAuthOverride: GatewayConnectionController.ManualAuthOverride?
        var setupAuthPersistenceRequest: SettingsGatewaySetupAuthPersistenceRequest?
    }

    enum Action: Equatable, Sendable {
        struct CredentialsLoadRequest: Equatable, Sendable {
            var instanceId: SettingsGatewayCurrentInstanceID
        }

        struct ManualCredentialChange: Equatable, Sendable {
            var draft: SettingsGatewayCredentialDraft
        }

        struct ManualCredentialPersistenceRequest: Equatable, Sendable {
            var value: SettingsGatewayCredentialValue
            var instanceId: SettingsGatewayCurrentInstanceID
        }

        struct SetupAuthApplication: Equatable, Sendable {
            var setupAuth: GatewayConnectionController.ManualAuthOverride.SetupAuth
        }

        struct SetupLinkApplication: Equatable, Sendable { var link: GatewayConnectDeepLink }

        case credentialsClearedForOnboardingReset
        case credentialsLoadRequested(CredentialsLoadRequest)
        case credentialsLoaded(SettingsGatewayStoredCredentials)
        case gatewayPasswordChanged(ManualCredentialChange)
        case gatewayPasswordPersistenceRequested(ManualCredentialPersistenceRequest)
        case gatewayTokenChanged(ManualCredentialChange)
        case gatewayTokenPersistenceRequested(ManualCredentialPersistenceRequest)
        case pendingManualAuthOverrideConsumed
        case setupAuthApplied(SetupAuthApplication)
        case setupAuthPersistenceRequested(SettingsGatewaySetupAuthPersistenceRequest)
        case setupAuthPersistenceRequestHandled
        case setupLinkApplied(SetupLinkApplication)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.settingsGatewayCredentialsPersistence) var dependencyPersistenceClient
            @Dependency(\.settingsGatewaySetupAuthPersistence) var dependencySetupAuthPersistenceClient
            let persistenceClient = self.persistenceClientOverride ?? dependencyPersistenceClient
            let setupAuthPersistenceClient = self.setupAuthPersistenceClientOverride
                ?? dependencySetupAuthPersistenceClient

            switch action {
            case .credentialsClearedForOnboardingReset:
                state.gatewayToken = ""
                state.gatewayPassword = ""
                state.pendingManualAuthOverride = nil
                return .none

            case let .credentialsLoadRequested(request):
                guard request.instanceId.trimmedValue != nil else { return .none }
                let credentials = persistenceClient.loadCredentials(request.instanceId)
                state.gatewayToken = credentials.token
                state.gatewayPassword = credentials.password
                return .none

            case let .credentialsLoaded(credentials):
                state.gatewayToken = credentials.token
                state.gatewayPassword = credentials.password
                return .none

            case let .gatewayPasswordChanged(change):
                state.gatewayPassword = change.draft.value
                return .none

            case let .gatewayPasswordPersistenceRequested(persistence):
                guard let request = Self.manualCredentialPersistenceRequest(
                    value: persistence.value,
                    instanceId: persistence.instanceId)
                else { return .none }
                return .run { _ in
                    await persistenceClient.saveGatewayPassword(request.value, request.instanceId)
                }

            case let .gatewayTokenChanged(change):
                state.gatewayToken = change.draft.value
                return .none

            case let .gatewayTokenPersistenceRequested(persistence):
                guard let request = Self.manualCredentialPersistenceRequest(
                    value: persistence.value,
                    instanceId: persistence.instanceId)
                else { return .none }
                return .run { _ in
                    await persistenceClient.saveGatewayToken(request.value, request.instanceId)
                }

            case .pendingManualAuthOverrideConsumed:
                state.pendingManualAuthOverride = nil
                return .none

            case let .setupAuthApplied(application):
                Self.applySetupAuth(application.setupAuth, to: &state)
                return .none

            case let .setupAuthPersistenceRequested(request):
                guard request.trimmedInstanceId != nil else { return .none }
                return .run { _ in
                    if request.hasBootstrapToken {
                        await setupAuthPersistenceClient.prepareForBootstrapPairing(request.instanceId)
                    }
                    await setupAuthPersistenceClient.saveSetupAuth(request)
                }

            case .setupAuthPersistenceRequestHandled:
                state.setupAuthPersistenceRequest = nil
                return .none

            case let .setupLinkApplied(application):
                let setupAuth = GatewayConnectionController.ManualAuthOverride.setupAuth(from: application.link)
                Self.applySetupAuth(setupAuth, to: &state)
                state.setupAuthPersistenceRequest = SettingsGatewaySetupAuthPersistenceRequest(
                    setupAuth: setupAuth,
                    instanceId: setupAuthPersistenceClient.currentInstanceID())
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
        value: SettingsGatewayCredentialValue,
        instanceId: SettingsGatewayCurrentInstanceID)
        -> (value: SettingsGatewayCredentialValue, instanceId: SettingsGatewayCurrentInstanceID)?
    {
        guard instanceId.trimmedValue != nil else { return nil }
        return (
            value,
            instanceId)
    }
}

// swiftformat:disable redundantSendable
struct SettingsSelectedAgentClient: Sendable {
    var setSelectedAgentId: @MainActor @Sendable (SelectedAgentID?) -> Void
}

// swiftformat:enable redundantSendable

extension SettingsSelectedAgentClient: DependencyKey {
    static let liveValue = SettingsSelectedAgentClient(setSelectedAgentId: { _ in })
    static let testValue = SettingsSelectedAgentClient(setSelectedAgentId: { _ in })

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        SettingsSelectedAgentClient(setSelectedAgentId: { selectedAgentId in
            appModel.setSelectedAgentId(selectedAgentId?.value)
        })
    }
}

extension DependencyValues {
    var settingsSelectedAgent: SettingsSelectedAgentClient {
        get { self[SettingsSelectedAgentClient.self] }
        set { self[SettingsSelectedAgentClient.self] = newValue }
    }
}

@Reducer
struct SettingsAgentSelectionFeature {
    private let selectedAgentClientOverride: SettingsSelectedAgentClient?

    init(selectedAgentClient: SettingsSelectedAgentClient? = nil) {
        self.selectedAgentClientOverride = selectedAgentClient
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var selectedAgentPickerId = ""
    }

    enum Action: Equatable, Sendable {
        struct PickerSelectionChange: Equatable, Sendable { var selection: SelectedAgentID }

        struct SelectedAgentSync: Equatable, Sendable { var selectedAgent: SelectedAgentID? }

        case pickerSelectionChanged(PickerSelectionChange)
        case selectedAgentSynced(SelectedAgentSync)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.settingsSelectedAgent) var dependencySelectedAgentClient
            let selectedAgentClient = self.selectedAgentClientOverride ?? dependencySelectedAgentClient

            switch action {
            case let .pickerSelectionChanged(change):
                state.selectedAgentPickerId = change.selection.value
                let selectedAgentId = change.selection.normalized
                return .run { _ in
                    await selectedAgentClient.setSelectedAgentId(selectedAgentId)
                }

            case let .selectedAgentSynced(sync):
                state.selectedAgentPickerId = sync.selectedAgent?.value ?? ""
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct SettingsShareInstructionFeature {
    private let persistenceClientOverride: SettingsShareInstructionPersistenceClient?

    init(persistenceClient: SettingsShareInstructionPersistenceClient? = nil) {
        self.persistenceClientOverride = persistenceClient
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var defaultShareInstruction = ""
    }

    enum Action: Equatable, Sendable {
        struct DefaultShareInstructionChange: Equatable, Sendable {
            var instruction: SettingsDefaultShareInstruction
        }

        case defaultShareInstructionChanged(DefaultShareInstructionChange)
        case defaultShareInstructionLoadRequested
        case defaultShareInstructionPersistenceRequested(SettingsDefaultShareInstruction)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.settingsShareInstructionPersistence) var dependencyPersistenceClient
            let persistenceClient = self.persistenceClientOverride ?? dependencyPersistenceClient

            switch action {
            case let .defaultShareInstructionChanged(change):
                state.defaultShareInstruction = change.instruction.value
                return .none

            case .defaultShareInstructionLoadRequested:
                state.defaultShareInstruction = persistenceClient.loadDefaultInstruction().value
                return .none

            case let .defaultShareInstructionPersistenceRequested(instruction):
                return .run { _ in
                    await persistenceClient.saveDefaultInstruction(instruction)
                }
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

    struct ManualGatewayPortResolutionFailureMessage: Equatable, Sendable { var value: String }

    enum ManualGatewayPortResolutionResult: Equatable, Sendable {
        struct Failure: Equatable, Sendable { var message: ManualGatewayPortResolutionFailureMessage }

        case failure(Failure)
        case resolved
    }

    enum Action: Equatable, Sendable {
        struct ManualGatewayPortResolutionHost: Equatable, Sendable { var value: String }
        struct ManualGatewayPortResolutionTLS: Equatable, Sendable { var value: Bool }
        struct ManualGatewayPortResolutionRequest: Equatable, Sendable {
            var host: ManualGatewayPortResolutionHost
            var useTLS: ManualGatewayPortResolutionTLS
        }

        struct ManualGatewayPortSync: Equatable, Sendable { var port: SettingsManualGatewayPort }
        struct ManualGatewayPortTextChange: Equatable, Sendable { var text: SettingsManualGatewayPortText }

        case manualGatewayPortResolutionRequested(ManualGatewayPortResolutionRequest)
        case manualGatewayPortResolutionResultHandled
        case manualGatewayPortSynced(ManualGatewayPortSync)
        case manualGatewayPortTextChanged(ManualGatewayPortTextChange)
    }

    // swiftformat:enable redundantSendable

    static let invalidPortFailureMessage = ManualGatewayPortResolutionFailureMessage(
        value: "Failed: invalid port")

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .manualGatewayPortResolutionRequested(request):
                state.manualGatewayPortResolutionResult = nil
                guard state.resolvedManualPort(host: request.host.value, useTLS: request.useTLS.value) != nil else {
                    state.manualGatewayPortResolutionResult = .failure(.init(message: Self.invalidPortFailureMessage))
                    return .none
                }
                state.manualGatewayPortResolutionResult = .resolved
                return .none

            case .manualGatewayPortResolutionResultHandled:
                state.manualGatewayPortResolutionResult = nil
                return .none

            case let .manualGatewayPortSynced(sync):
                let port = sync.port.value
                state.manualGatewayPort = port
                state.manualGatewayPortText = port > 0 ? String(port) : ""
                return .none

            case let .manualGatewayPortTextChanged(change):
                let filtered = change.text.value.filter(\.isNumber)
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
        struct GatewayAutoConnectEnabled: Equatable, Sendable { var value: Bool }
        struct EnabledChange: Equatable, Sendable { var enabled: GatewayAutoConnectEnabled }
        struct EnabledSync: Equatable, Sendable { var enabled: GatewayAutoConnectEnabled }

        case disabledForOnboardingReset
        case enabledChanged(EnabledChange)
        case enabledSynced(EnabledSync)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .disabledForOnboardingReset:
                state.isEnabled = false
                return .none

            case let .enabledChanged(change):
                state.isEnabled = change.enabled.value
                return .none

            case let .enabledSynced(sync):
                state.isEnabled = sync.enabled.value
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct SettingsOnboardingStateFeature {
    private let resetClientOverride: SettingsOnboardingResetClient?

    init(resetClient: SettingsOnboardingResetClient? = nil) {
        self.resetClientOverride = resetClient
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var hasConnectedOnce = false
        var onboardingComplete = false
        var onboardingRequestID = 0
    }

    enum Action: Equatable, Sendable {
        struct OnboardingRequestIDChange: Equatable, Sendable { var requestID: SettingsOnboardingRequestID }

        struct OnboardingResetRequest: Equatable, Sendable { var instanceId: SettingsGatewayCurrentInstanceID }

        struct SettingsOnboardingHasConnectedOnce: Equatable, Sendable { var value: Bool }
        struct SettingsOnboardingComplete: Equatable, Sendable { var value: Bool }

        struct OnboardingStateSync: Equatable, Sendable {
            var hasConnectedOnce: SettingsOnboardingHasConnectedOnce
            var onboardingComplete: SettingsOnboardingComplete
            var onboardingRequestID: SettingsOnboardingRequestID
        }

        case onboardingRequestIDChanged(OnboardingRequestIDChange)
        case onboardingResetRequested(OnboardingResetRequest)
        case onboardingStateSynced(OnboardingStateSync)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.settingsOnboardingReset) var dependencyResetClient
            let resetClient = self.resetClientOverride ?? dependencyResetClient

            switch action {
            case let .onboardingRequestIDChanged(change):
                state.onboardingRequestID = change.requestID.value
                return .none

            case let .onboardingResetRequested(request):
                state.hasConnectedOnce = false
                state.onboardingComplete = false
                state.onboardingRequestID += 1
                return .run { _ in
                    await resetClient.reset(request.instanceId)
                }

            case let .onboardingStateSynced(sync):
                state.hasConnectedOnce = sync.hasConnectedOnce.value
                state.onboardingComplete = sync.onboardingComplete.value
                state.onboardingRequestID = sync.onboardingRequestID.value
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
        struct AppearancePreferenceChange: Equatable, Sendable { var preference: AppAppearancePreference }

        struct AppearancePreferenceSync: Equatable, Sendable { var rawValue: SettingsAppearancePreferenceRawValue }

        case appearancePreferenceChanged(AppearancePreferenceChange)
        case appearancePreferenceSynced(AppearancePreferenceSync)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .appearancePreferenceChanged(change):
                state.appearancePreferenceRaw = change.preference.rawValue
                return .none

            case let .appearancePreferenceSynced(sync):
                state.appearancePreferenceRaw = sync.rawValue.value
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
        struct DisplayNameChange: Equatable, Sendable { var displayName: SettingsDeviceDisplayName }

        struct DisplayNameSync: Equatable, Sendable { var displayName: SettingsDeviceDisplayName }

        struct InstanceIDSync: Equatable, Sendable { var instanceId: SettingsGatewayCurrentInstanceID }

        case displayNameChanged(DisplayNameChange)
        case displayNameSynced(DisplayNameSync)
        case instanceIdSynced(InstanceIDSync)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .displayNameChanged(change):
                state.displayName = change.displayName.value
                return .none

            case let .displayNameSynced(sync):
                state.displayName = sync.displayName.value
                return .none

            case let .instanceIdSynced(sync):
                state.instanceId = sync.instanceId.value
                return .none
            }
        }
        .autoLogActions()
    }
}

// swiftformat:disable redundantSendable
struct SettingsDiscoveryDebugLoggingClient: Sendable {
    var setDiscoveryDebugLoggingEnabled: @MainActor @Sendable (Bool) -> Void
}

// swiftformat:enable redundantSendable

extension SettingsDiscoveryDebugLoggingClient: DependencyKey {
    static let liveValue = SettingsDiscoveryDebugLoggingClient(
        setDiscoveryDebugLoggingEnabled: { _ in })
    static let testValue = SettingsDiscoveryDebugLoggingClient(
        setDiscoveryDebugLoggingEnabled: { _ in })

    @MainActor
    static func live(gatewayController: GatewayConnectionController) -> Self {
        SettingsDiscoveryDebugLoggingClient(setDiscoveryDebugLoggingEnabled: { enabled in
            gatewayController.setDiscoveryDebugLoggingEnabled(enabled)
        })
    }
}

extension DependencyValues {
    var settingsDiscoveryDebugLogging: SettingsDiscoveryDebugLoggingClient {
        get { self[SettingsDiscoveryDebugLoggingClient.self] }
        set { self[SettingsDiscoveryDebugLoggingClient.self] = newValue }
    }
}

@Reducer
struct SettingsDebugOptionsFeature {
    private let discoveryDebugLoggingClientOverride: SettingsDiscoveryDebugLoggingClient?

    init(discoveryDebugLoggingClient: SettingsDiscoveryDebugLoggingClient? = nil) {
        self.discoveryDebugLoggingClientOverride = discoveryDebugLoggingClient
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var canvasDebugStatusEnabled = false
        var discoveryDebugLogsEnabled = false
    }

    enum Action: Equatable, Sendable {
        struct DebugOptionsSync: Equatable, Sendable {
            var discoveryDebugLogsEnabled: SettingsDebugOptionEnabled
            var canvasDebugStatusEnabled: SettingsDebugOptionEnabled
        }

        struct SettingsDebugOptionEnabled: Equatable, Sendable { var isEnabled: Bool }
        struct DebugOptionToggleChange: Equatable, Sendable { var enabled: SettingsDebugOptionEnabled }

        case canvasDebugStatusChanged(DebugOptionToggleChange)
        case debugOptionsSynced(DebugOptionsSync)
        case discoveryDebugLogsChanged(DebugOptionToggleChange)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.settingsDiscoveryDebugLogging) var dependencyDiscoveryDebugLoggingClient
            let discoveryDebugLoggingClient = self.discoveryDebugLoggingClientOverride
                ?? dependencyDiscoveryDebugLoggingClient

            switch action {
            case let .canvasDebugStatusChanged(change):
                state.canvasDebugStatusEnabled = change.enabled.isEnabled
                return .none

            case let .debugOptionsSynced(sync):
                state.discoveryDebugLogsEnabled = sync.discoveryDebugLogsEnabled.isEnabled
                state.canvasDebugStatusEnabled = sync.canvasDebugStatusEnabled.isEnabled
                return .none

            case let .discoveryDebugLogsChanged(change):
                let enabled = change.enabled
                state.discoveryDebugLogsEnabled = enabled.isEnabled
                return .run { _ in
                    await discoveryDebugLoggingClient.setDiscoveryDebugLoggingEnabled(enabled.isEnabled)
                }
            }
        }
        .autoLogActions()
    }
}

// swiftformat:disable redundantSendable
struct SettingsVoiceControlClient: Sendable {
    var setTalkEnabled: @MainActor @Sendable (Bool) -> Void
    var setVoiceWakeEnabled: @MainActor @Sendable (Bool) -> Void
}

// swiftformat:enable redundantSendable

extension SettingsVoiceControlClient: DependencyKey {
    static let liveValue = SettingsVoiceControlClient(
        setTalkEnabled: { _ in },
        setVoiceWakeEnabled: { _ in })
    static let testValue = SettingsVoiceControlClient(
        setTalkEnabled: { _ in },
        setVoiceWakeEnabled: { _ in })

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        SettingsVoiceControlClient(
            setTalkEnabled: { enabled in
                appModel.setTalkEnabled(enabled)
            },
            setVoiceWakeEnabled: { enabled in
                appModel.setVoiceWakeEnabled(enabled)
            })
    }
}

extension DependencyValues {
    var settingsVoiceControl: SettingsVoiceControlClient {
        get { self[SettingsVoiceControlClient.self] }
        set { self[SettingsVoiceControlClient.self] = newValue }
    }
}

@Reducer
struct SettingsVoiceControlFeature {
    private let voiceControlClientOverride: SettingsVoiceControlClient?

    init(voiceControlClient: SettingsVoiceControlClient? = nil) {
        self.voiceControlClientOverride = voiceControlClient
    }

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
        struct SettingsTalkEnabled: Equatable, Sendable { var isEnabled: Bool }
        struct SettingsVoiceControlDemoModeEnabled: Equatable, Sendable { var value: Bool }
        struct SettingsVoiceWakeEnabled: Equatable, Sendable { var isEnabled: Bool }
        struct SettingsVoiceWakeStatusText: Equatable, Sendable { var value: String }
        struct TalkEnabledChange: Equatable, Sendable { var enabled: SettingsTalkEnabled }

        struct TalkEnabledChangeRequest: Equatable, Sendable {
            var enabled: SettingsTalkEnabled
            var isAppleReviewDemoModeEnabled: SettingsVoiceControlDemoModeEnabled
        }

        struct VoiceControlSync: Equatable, Sendable {
            var talkEnabled: SettingsTalkEnabled
            var voiceWakeEnabled: SettingsVoiceWakeEnabled
            var voiceWakeStatusText: SettingsVoiceWakeStatusText
        }

        struct VoiceWakeEnabledChange: Equatable, Sendable { var enabled: SettingsVoiceWakeEnabled }

        case controlsSynced(VoiceControlSync)
        case talkDisabledForAppleReview
        case talkEnabledChanged(TalkEnabledChange)
        case talkEnabledChangeRequested(TalkEnabledChangeRequest)
        case voiceWakeEnabledChanged(VoiceWakeEnabledChange)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.settingsVoiceControl) var dependencyVoiceControlClient
            let voiceControlClient = self.voiceControlClientOverride ?? dependencyVoiceControlClient

            switch action {
            case let .controlsSynced(sync):
                state.talkEnabled = sync.talkEnabled.isEnabled
                state.voiceWakeEnabled = sync.voiceWakeEnabled.isEnabled
                state.voiceWakeStatusText = sync.voiceWakeStatusText.value
                return .none

            case .talkDisabledForAppleReview:
                state.talkEnabled = false
                return .none

            case let .talkEnabledChanged(change):
                state.talkEnabled = change.enabled.isEnabled
                return .none

            case let .talkEnabledChangeRequested(request):
                let requested = request.enabled
                let talkEnabled = request.isAppleReviewDemoModeEnabled.value ? false : requested.isEnabled
                state.talkEnabled = talkEnabled
                return .run { _ in
                    await voiceControlClient.setTalkEnabled(talkEnabled)
                }

            case let .voiceWakeEnabledChanged(change):
                let enabled = change.enabled
                state.voiceWakeEnabled = enabled.isEnabled
                return .run { _ in
                    await voiceControlClient.setVoiceWakeEnabled(enabled.isEnabled)
                }
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

    @State var agentSelectionStore: StoreOf<SettingsAgentSelectionFeature>

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

    @State var voiceControlStore: StoreOf<SettingsVoiceControlFeature>

    @State var talkPreferencesStore: StoreOf<SettingsTalkPreferencesFeature>

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
        debugOptionsStore: StoreOf<SettingsDebugOptionsFeature> = Store(
            initialState: SettingsDebugOptionsFeature.State())
        {
            SettingsDebugOptionsFeature()
        },
        voiceControlStore: StoreOf<SettingsVoiceControlFeature> = Store(
            initialState: SettingsVoiceControlFeature.State())
        {
            SettingsVoiceControlFeature()
        },
        talkPreferencesStore: StoreOf<SettingsTalkPreferencesFeature> = Store(
            initialState: SettingsTalkPreferencesFeature.State())
        {
            SettingsTalkPreferencesFeature()
        },
        agentSelectionStore: StoreOf<SettingsAgentSelectionFeature> = Store(
            initialState: SettingsAgentSelectionFeature.State())
        {
            SettingsAgentSelectionFeature()
        },
        manualGatewayEndpointStore: StoreOf<SettingsManualGatewayEndpointFeature> = Store(
            initialState: SettingsManualGatewayEndpointFeature.State())
        {
            SettingsManualGatewayEndpointFeature()
        },
        gatewayActivityStore: StoreOf<SettingsGatewayActivityFeature> = Store(
            initialState: SettingsGatewayActivityFeature.State())
        {
            SettingsGatewayActivityFeature()
        },
        gatewayConnectionStore: StoreOf<SettingsGatewayConnectionFeature> = Store(
            initialState: SettingsGatewayConnectionFeature.State())
        {
            SettingsGatewayConnectionFeature()
        },
        gatewayCredentialsStore: StoreOf<SettingsGatewayCredentialsFeature> = Store(
            initialState: SettingsGatewayCredentialsFeature.State())
        {
            SettingsGatewayCredentialsFeature()
        },
        gatewaySetupLinkStore: StoreOf<SettingsGatewaySetupLinkFeature> = Store(
            initialState: SettingsGatewaySetupLinkFeature.State())
        {
            SettingsGatewaySetupLinkFeature()
        },
        locationStore: StoreOf<SettingsLocationFeature> = Store(
            initialState: SettingsLocationFeature.State())
        {
            SettingsLocationFeature()
        },
        onboardingStateStore: StoreOf<SettingsOnboardingStateFeature> = Store(
            initialState: SettingsOnboardingStateFeature.State())
        {
            SettingsOnboardingStateFeature()
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
        self._debugOptionsStore = State(wrappedValue: debugOptionsStore)
        self._voiceControlStore = State(wrappedValue: voiceControlStore)
        self._talkPreferencesStore = State(wrappedValue: talkPreferencesStore)
        self._agentSelectionStore = State(wrappedValue: agentSelectionStore)
        self._manualGatewayEndpointStore = State(wrappedValue: manualGatewayEndpointStore)
        self._gatewayActivityStore = State(wrappedValue: gatewayActivityStore)
        self._gatewayConnectionStore = State(wrappedValue: gatewayConnectionStore)
        self._gatewayCredentialsStore = State(wrappedValue: gatewayCredentialsStore)
        self._gatewaySetupLinkStore = State(wrappedValue: gatewaySetupLinkStore)
        self._locationStore = State(wrappedValue: locationStore)
        self._onboardingStateStore = State(wrappedValue: onboardingStateStore)
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
            set: { self.navigationStore.send(.navigationPathChanged(.init(path: $0))) })
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
                self.runInitialSettingsLifecycle()
            }
            .onChange(of: self.scenePhase) { _, phase in
                if phase == .active {
                    self.refreshActiveSettingsLifecycle()
                }
            }
            .onChange(of: self.storedAppearancePreferenceRaw) { _, newValue in
                self.appearanceStore.send(.appearancePreferenceSynced(.init(rawValue: .init(value: newValue))))
            }
            .onChange(of: self.storedDisplayName) { _, newValue in
                self.deviceIdentityStore.send(.displayNameSynced(.init(displayName: .init(value: newValue))))
            }
            .onChange(of: self.storedInstanceId) { _, newValue in
                self.deviceIdentityStore.send(.instanceIdSynced(.init(instanceId: .init(value: newValue))))
            }
            .onChange(of: self.storedDiscoveryDebugLogsEnabled) { _, newValue in
                self.debugOptionsStore.send(.discoveryDebugLogsChanged(.init(
                    enabled: .init(isEnabled: newValue))))
            }
            .onChange(of: self.storedCanvasDebugStatusEnabled) { _, newValue in
                self.debugOptionsStore.send(.canvasDebugStatusChanged(.init(
                    enabled: .init(isEnabled: newValue))))
            }
            .onChange(of: self.storedLocationModeRaw) { _, newValue in
                self.locationStore.send(.locationModeChangeRequested(.init(rawValue: newValue)))
                self.deviceCapabilityStore.send(.locationModeChanged(.init(mode: .init(rawValue: newValue))))
                self.handleLocationModeRequest(self.locationStore.locationModeRequest)
            }
            .onChange(of: self.locationStore.locationModeApplyResult) { _, result in
                self.handleLocationModeApplyResult(result)
            }
            .onChange(of: self.manualGatewayPortStore.manualGatewayPort) { _, newValue in
                self.storedManualGatewayPort = newValue
            }
            .onChange(of: self.appModel.selectedAgentId ?? "") { _, newValue in
                if newValue != self.agentSelectionStore.selectedAgentPickerId {
                    let selectedAgent = newValue.isEmpty ? nil : SelectedAgentID(value: newValue)
                    self.agentSelectionStore.send(.selectedAgentSynced(.init(selectedAgent: selectedAgent)))
                }
            }
            .onChange(of: self.storedSetupCode) { _, newValue in
                self.gatewaySetupLinkStore.send(.setupCodeSynced(.init(setupCode: .init(value: newValue))))
            }
            .onChange(of: self.storedCameraEnabled) { _, newValue in
                self.deviceCapabilityStore.send(.cameraEnabledChanged(.init(
                    enabled: .init(value: newValue))))
            }
            .onChange(of: self.storedPreventSleep) { _, newValue in
                self.deviceCapabilityStore.send(.preventSleepChanged(.init(
                    enabled: .init(value: newValue))))
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
                self.gatewayAutoConnectStore.send(.enabledSynced(.init(enabled: .init(value: newValue))))
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
                self.shareInstructionStore.send(.defaultShareInstructionPersistenceRequested(.init(value: newValue)))
            }
            .onChange(of: self.appModel.gatewaySetupRequestID) { _, _ in
                self.applyPendingGatewaySetupLinkIfNeeded()
            }
            .onChange(of: self.navigationStore.navigationPath) { _, _ in
                self.notifyRouteChange()
            }
    }

    private func runInitialSettingsLifecycle() {
        self.syncSettingsState()
        self.refreshNotificationSettings()
        self.applyPendingGatewaySetupLinkIfNeeded()
        self.applyInitialRouteIfNeeded()
        self.notifyRouteChange()
    }

    private func refreshActiveSettingsLifecycle() {
        self.syncSettingsState()
        self.refreshNotificationSettings()
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
                            self.presentationStore.send(.qrScannerErrorReceived(.init(message: .init(value: error))))
                            self.gatewaySetupStatusStore.send(.qrScannerErrorReceived(.init(
                                message: .init(value: error))))
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
                    Task { await self.resetOnboarding() }
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
        self.navigationStore.send(.routeOpened(.init(route: .notifications)))
    }

    private func applyInitialRouteIfNeeded() {
        guard self.directRoute == nil else { return }
        self.navigationStore.send(.initialRouteRequested(.init(route: self.initialRoute)))
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
            set: {
                self.shareInstructionStore.send(.defaultShareInstructionChanged(.init(
                    instruction: .init(value: $0))))
            })
    }

    var agentSelectionBinding: Binding<String> {
        Binding(
            get: { self.agentSelectionStore.selectedAgentPickerId },
            set: { self.agentSelectionStore.send(.pickerSelectionChanged(.init(selection: .init(value: $0)))) })
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
