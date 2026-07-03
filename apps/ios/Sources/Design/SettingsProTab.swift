import ComposableArchitecture
import OpenClawKit
import SwiftUI

@Reducer
struct SettingsNavigationFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var navigationPath: [SettingsRoute] = []
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
struct SettingsDiagnosticsFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var issueCount: Int?
        var lastRunText = "Not run"
    }

    enum Action: Equatable, Sendable {
        case diagnosticsCompleted(issueCount: Int, lastRunText: String)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .diagnosticsCompleted(issueCount, lastRunText):
                state.issueCount = issueCount
                state.lastRunText = lastRunText
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
struct SettingsLocationFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var isChangingLocationMode = false
        var previousLocationModeRaw = OpenClawLocationMode.off.rawValue
        var statusText: String?
    }

    enum Action: Equatable, Sendable {
        case locationChangeFinished
        case locationChangeStarted
        case locationModeApplied(String)
        case locationPermissionDenied(previousRawValue: String)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .locationChangeFinished:
                state.isChangingLocationMode = false
                return .none

            case .locationChangeStarted:
                state.isChangingLocationMode = true
                state.statusText = nil
                return .none

            case let .locationModeApplied(rawValue):
                state.previousLocationModeRaw = rawValue
                return .none

            case let .locationPermissionDenied(previousRawValue):
                state.previousLocationModeRaw = previousRawValue
                state.statusText = "Location permission was not granted."
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct SettingsNotificationFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var isRequestingAuthorization = false
        var status: SettingsNotificationStatus = .checking
    }

    enum Action: Equatable, Sendable {
        case authorizationRequestFinished(SettingsNotificationStatus)
        case authorizationRequestStarted
        case statusChanged(SettingsNotificationStatus)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .authorizationRequestFinished(status):
                state.isRequestingAuthorization = false
                state.status = status
                return .none

            case .authorizationRequestStarted:
                state.isRequestingAuthorization = true
                return .none

            case let .statusChanged(status):
                state.status = status
                return .none
            }
        }
        .autoLogActions()
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

struct SettingsProTab: View {
    @Environment(NodeAppModel.self) var appModel
    @Environment(VoiceWakeManager.self) var voiceWake
    @Environment(GatewayConnectionController.self) var gatewayController
    @Environment(\.scenePhase) var scenePhase
    @AppStorage(AppAppearancePreference.storageKey) var appearancePreferenceRaw: String =
        AppAppearancePreference.system.rawValue
    @AppStorage("node.displayName") var displayName: String = "iOS Node"
    @AppStorage("node.instanceId") var instanceId: String = UUID().uuidString
    @AppStorage("camera.enabled") var cameraEnabled: Bool = true
    @AppStorage("location.enabledMode") var locationModeRaw: String = OpenClawLocationMode.off.rawValue
    @AppStorage("screen.preventSleep") var preventSleep: Bool = true
    @AppStorage("talk.enabled") var talkEnabled: Bool = false
    @AppStorage(TalkModeProviderSelection.storageKey) var talkProviderSelectionRaw: String =
        TalkModeProviderSelection.gatewayDefault.rawValue
    @AppStorage(TalkModeRealtimeVoiceSelection.storageKey) var talkRealtimeVoiceSelectionRaw: String = ""
    @AppStorage(TalkSpeechLocale.storageKey) var talkSpeechLocale: String = TalkSpeechLocale.automaticID
    @AppStorage("talk.button.enabled") var talkButtonEnabled: Bool = true
    @AppStorage("talk.background.enabled") var talkBackgroundEnabled: Bool = false
    @AppStorage(TalkDefaults.speakerphoneEnabledKey) var talkSpeakerphoneEnabled: Bool =
        TalkDefaults.speakerphoneEnabledByDefault
    @AppStorage(VoiceWakePreferences.enabledKey) var voiceWakeEnabled: Bool = false
    @AppStorage("gateway.autoconnect") var gatewayAutoConnect: Bool = false
    @AppStorage("gateway.manual.enabled") var manualGatewayEnabled: Bool = false
    @AppStorage("gateway.manual.host") var manualGatewayHost: String = ""
    @AppStorage("gateway.manual.port") var manualGatewayPort: Int = 18789
    @AppStorage("gateway.manual.tls") var manualGatewayTLS: Bool = true
    @AppStorage("gateway.discovery.debugLogs") var discoveryDebugLogsEnabled: Bool = false
    @AppStorage("canvas.debugStatusEnabled") var canvasDebugStatusEnabled: Bool = false
    @AppStorage("gateway.setupCode") var setupCode: String = ""
    @AppStorage("gateway.onboardingComplete") var onboardingComplete: Bool = false
    @AppStorage("gateway.hasConnectedOnce") var hasConnectedOnce: Bool = false
    @AppStorage("onboarding.requestID") var onboardingRequestID: Int = 0
    @State var connectingGatewayID: String?
    @State var gatewayToken = ""
    @State var gatewayPassword = ""
    @State var manualGatewayPortText = ""
    @State var setupStatusText: String?
    @State var stagedGatewaySetupLink: GatewayConnectDeepLink?
    @State var pendingManualAuthOverride: GatewayConnectionController.ManualAuthOverride?
    @State var defaultShareInstruction = ""
    @State var suppressCredentialPersist = false
    @State var pushEnrollmentConsentStore = Store(initialState: PushEnrollmentConsentFeature.State()) {
        PushEnrollmentConsentFeature()
    }

    @State var execApprovalPromptStore: StoreOf<ExecApprovalPromptFeature>

    @State var agentSelectionStore: StoreOf<SettingsAgentSelectionFeature> = Store(
        initialState: SettingsAgentSelectionFeature.State())
    {
        SettingsAgentSelectionFeature()
    }

    @State var diagnosticsStore: StoreOf<SettingsDiagnosticsFeature> = Store(
        initialState: SettingsDiagnosticsFeature.State())
    {
        SettingsDiagnosticsFeature()
    }

    @State var gatewayActivityStore: StoreOf<SettingsGatewayActivityFeature> = Store(
        initialState: SettingsGatewayActivityFeature.State())
    {
        SettingsGatewayActivityFeature()
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
        AppAppearancePreference(rawValue: self.appearancePreferenceRaw) ?? .system
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
        content
            .task {
                self.locationStore.send(.locationModeApplied(self.locationModeRaw))
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
            .onChange(of: self.locationModeRaw) { _, newValue in
                self.handleLocationModeChange(newValue)
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
            .onChange(of: self.gatewayToken) { _, newValue in
                self.persistGatewayToken(newValue)
            }
            .onChange(of: self.gatewayPassword) { _, newValue in
                self.persistGatewayPassword(newValue)
            }
            .onChange(of: self.setupCode) { _, newValue in
                if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.stagedGatewaySetupLink = nil
                }
            }
            .onChange(of: self.defaultShareInstruction) { _, newValue in
                ShareToAgentSettings.saveDefaultInstruction(newValue)
            }
            .onChange(of: self.appModel.gatewaySetupRequestID) { _, _ in
                self.applyPendingGatewaySetupLinkIfNeeded()
            }
            .onChange(of: self.navigationStore.navigationPath) { _, _ in
                self.notifyRouteChange()
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
                            self.setupStatusText = "Scanner error: \(error)"
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
