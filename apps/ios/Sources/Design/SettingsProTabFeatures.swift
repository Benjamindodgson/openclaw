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
        var activeAgentName = Action.SettingsApprovalsActiveAgentName(value: "Default Agent")
        var gatewayConnected = Action.SettingsApprovalsGatewayConnected(value: false)
        var hasPendingApproval = Action.SettingsApprovalsHasPendingApproval(value: false)
        var isAppleReviewDemoModeEnabled = Action.SettingsApprovalsDemoModeEnabled(value: false)
        var isResolvingPendingApproval = Action.SettingsApprovalsResolvingPendingApproval(value: false)
        var notificationsNeedAttention = Action.SettingsApprovalsNotificationsNeedAttention(value: false)
        var pendingApprovalAllowsAllowAlways = Action.SettingsApprovalsPendingApprovalAllowsAllowAlways(value: false)
        var pendingCommandPreview = Action.SettingsApprovalsPendingCommandPreview(value: nil)

        var approvalBadgeValue: String? {
            self.hasPendingApproval.value ? "1" : nil
        }

        var approvalEmptyDetail: String {
            if self.isAppleReviewDemoModeEnabled.value {
                return "Live gateway requests are disabled in demo mode."
            }
            if self.notificationsNeedAttention.value {
                return "Foreground approvals still appear while OpenClaw is connected."
            }
            return self.gatewayConnected.value ? "Gateway requests will appear here." : "Connect to the gateway."
        }

        var approvalsDetail: String {
            if self.notificationsNeedAttention.value {
                return self.hasPendingApproval.value ? "1 waiting, notifications off" : "Notifications off"
            }
            return self.hasPendingApproval.value ? "1 request waiting" : "No approvals waiting"
        }

        var destinationDetail: String {
            if self.notificationsNeedAttention.value {
                return "Out-of-app approval alerts need notification permission."
            }
            return self.hasPendingApproval.value
                ? "Review the pending gateway action."
                : "No gateway actions are waiting for review."
        }

        var destinationValue: String {
            if self.notificationsNeedAttention.value { return "Alerts Off" }
            return self.hasPendingApproval.value ? "1 waiting" : "clear"
        }

        var destinationColor: Color {
            if self.notificationsNeedAttention.value { return OpenClawBrand.warn }
            return self.hasPendingApproval.value ? OpenClawBrand.warn : OpenClawBrand.ok
        }

        var listColor: Color {
            self.hasPendingApproval.value ? OpenClawBrand.warn : .secondary
        }

        var approvalItems: [SettingsApprovalItem] {
            guard self.hasPendingApproval.value else { return [] }
            return [
                SettingsApprovalItem(
                    id: "pending-real",
                    icon: "terminal.fill",
                    title: self.pendingCommandPreview.value ?? "Review gateway action",
                    detail: "Agent: \(self.activeAgentName.value)",
                    priority: self.isResolvingPendingApproval.value ? "Resolving" : "High",
                    color: OpenClawBrand.danger),
                SettingsApprovalItem(
                    id: "pending-context",
                    icon: "doc.text.fill",
                    title: self.pendingApprovalAllowsAllowAlways.value
                        ? "Permission can be saved"
                        : "One-time approval",
                    detail: "Gateway request",
                    priority: self.pendingApprovalAllowsAllowAlways.value
                        ? "Medium"
                        : "Review",
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
                state.isAppleReviewDemoModeEnabled = sync.isAppleReviewDemoModeEnabled
                state.gatewayConnected = sync.gatewayConnected
                state.notificationsNeedAttention = sync.notificationsNeedAttention
                state.hasPendingApproval = sync.hasPendingApproval
                state.pendingCommandPreview = sync.pendingCommandPreview
                state.activeAgentName = sync.activeAgentName
                state.isResolvingPendingApproval = sync.isResolvingPendingApproval
                state.pendingApprovalAllowsAllowAlways = sync.pendingApprovalAllowsAllowAlways
                return .none
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
        var talkEnabled = Action.SettingsTalkEnabled(isEnabled: false)
        var voiceWakeEnabled = Action.SettingsVoiceWakeEnabled(isEnabled: false)
        var voiceWakeStatusText = Action.SettingsVoiceWakeStatusText(value: "Off")

        var detailText: String {
            if self.talkEnabled.isEnabled, self.voiceWakeEnabled.isEnabled { return "Talk + Wake" }
            if self.talkEnabled.isEnabled { return "Talk on" }
            if self.voiceWakeEnabled.isEnabled { return "Wake on" }
            return "Off"
        }

        var detailColor: Color {
            self.talkEnabled.isEnabled || self.voiceWakeEnabled.isEnabled ? OpenClawBrand.accent : .secondary
        }

        var voiceWakeValue: String {
            self.voiceWakeEnabled.isEnabled ? "on" : "off"
        }

        var voiceWakeColor: Color {
            self.voiceWakeEnabled.isEnabled ? OpenClawBrand.ok : .secondary
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
                state.talkEnabled = sync.talkEnabled
                state.voiceWakeEnabled = sync.voiceWakeEnabled
                state.voiceWakeStatusText = sync.voiceWakeStatusText
                return .none

            case .talkDisabledForAppleReview:
                state.talkEnabled = .init(isEnabled: false)
                return .none

            case let .talkEnabledChanged(change):
                state.talkEnabled = change.enabled
                return .none

            case let .talkEnabledChangeRequested(request):
                let requested = request.enabled
                let talkEnabled =
                    if request.isAppleReviewDemoModeEnabled.value {
                        Action.SettingsTalkEnabled(isEnabled: false)
                    } else {
                        requested
                    }
                state.talkEnabled = talkEnabled
                return .run { _ in
                    await voiceControlClient.setTalkEnabled(talkEnabled.isEnabled)
                }

            case let .voiceWakeEnabledChanged(change):
                let enabled = change.enabled
                state.voiceWakeEnabled = enabled
                return .run { _ in
                    await voiceControlClient.setVoiceWakeEnabled(enabled.isEnabled)
                }
            }
        }
        .autoLogActions()
    }
}
