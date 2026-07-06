import ComposableArchitecture
import CoreGraphics
import Foundation
import SwiftUI

// swiftformat:disable redundantSendable
struct RootLocalNetworkAccessReason: Equatable, Sendable {
    var value: String

    init(rawValue: String) {
        self.value = rawValue
    }

    static let rootAppear = Self(rawValue: "root_appear")
    static let autoOpenSettings = Self(rawValue: "auto_open_settings")
    static let gatewaySetupDeeplink = Self(rawValue: "gateway_setup_deeplink")
    static let sceneActive = Self(rawValue: "scene_active")
    static let onboardingDismissed = Self(rawValue: "onboarding_dismissed")
}

// swiftformat:enable redundantSendable

@Reducer
struct RootPresentationFeature {
    // swiftformat:disable redundantSendable
    enum PresentedSheet: Int, Identifiable, Equatable, Sendable {
        case gatewayProblemDetails
        case quickSetup

        var id: Int {
            self.rawValue
        }
    }

    struct GatewayConnection: Equatable, Sendable {
        var isConnected: Bool

        init(isConnected: Bool = false) {
            self.isConnected = isConnected
        }
    }

    struct GatewayConfigPresence: Equatable, Sendable {
        var hasExistingConfig: Bool

        init(hasExistingConfig: Bool = false) {
            self.hasExistingConfig = hasExistingConfig
        }
    }

    struct StartupSnapshot: Equatable, Sendable {
        var gatewayConnection: GatewayConnection
        var hasConnectedOnce: Bool
        var onboardingComplete: Bool
        var gatewayConfigPresence: GatewayConfigPresence
        var shouldPresentOnLaunch: Bool
    }

    struct StartupSnapshotChange: Equatable, Sendable {
        var snapshot: StartupSnapshot
    }

    struct StartupPresentationEvaluationRequest: Equatable, Sendable {
        var snapshot: StartupSnapshot
    }

    struct AutoOpenSettingsRequest: Equatable, Sendable {
        var snapshot: StartupSnapshot
    }

    struct QuickSetupSnapshot: Equatable, Sendable {
        var quickSetupDismissed: Bool
        var showOnboarding: Bool
        var gatewayConnection: GatewayConnection
        var gatewayConfigPresence: GatewayConfigPresence
        var discoveredGatewayCount: DiscoveredGatewayCount
    }

    struct QuickSetupSnapshotChange: Equatable, Sendable {
        var snapshot: QuickSetupSnapshot
    }

    struct SidebarGatewayStatusChange: Equatable, Sendable {
        var status: GatewayDisplayState
    }

    struct PresentedSheetChange: Equatable, Sendable {
        var sheet: PresentedSheet?
    }

    struct SceneActivity: Equatable, Sendable { var isActive: Bool }
    struct OnboardingPresentation: Equatable, Sendable { var isPresented: Bool }

    struct LocalNetworkAccessRequest: Equatable, Sendable {
        var reason: RootLocalNetworkAccessReason
        var sceneActivity: SceneActivity
    }

    struct LocalNetworkAccessCommand: Equatable, Sendable {
        var reason: RootLocalNetworkAccessReason
    }

    struct OnboardingVisibilityChange: Equatable, Sendable {
        var presentation: OnboardingPresentation
        var sceneActivity: SceneActivity
    }

    struct GatewaySetupRequest: Equatable, Sendable {
        var requestID: GatewaySetupRequestID
    }

    struct GatewaySetupRequestID: Equatable, Sendable {
        var value: Int

        init(value: Int = 0) {
            self.value = value
        }

        var isUnset: Bool {
            self.value == 0
        }
    }

    struct OnboardingEvaluationGate: Equatable, Sendable {
        var didEvaluate: Bool

        init(didEvaluate: Bool = false) {
            self.didEvaluate = didEvaluate
        }

        mutating func markEvaluated() {
            self.didEvaluate = true
        }
    }

    struct AutoOpenSettingsGate: Equatable, Sendable {
        var didOpen: Bool

        init(didOpen: Bool = false) {
            self.didOpen = didOpen
        }

        mutating func markOpened() {
            self.didOpen = true
        }
    }

    struct DiscoveredGatewayCount: Equatable, Sendable {
        var value: Int

        init(value: Int = 0) {
            self.value = value
        }

        var hasDiscoveredGateway: Bool {
            self.value > 0
        }
    }

    @ObservableState
    struct State: Equatable, Sendable {
        var gatewayConnection: GatewayConnection
        var hasConnectedOnce: Bool
        var onboardingComplete: Bool
        var gatewayConfigPresence: GatewayConfigPresence
        var shouldPresentOnLaunch: Bool
        var quickSetupDismissed: Bool
        var showOnboarding: Bool
        var onboardingAllowSkip: Bool
        var presentedSheet: PresentedSheet?
        var discoveredGatewayCount: DiscoveredGatewayCount
        var onboardingEvaluationGate: OnboardingEvaluationGate
        var autoOpenSettingsGate: AutoOpenSettingsGate
        var handledGatewaySetupRequestID: GatewaySetupRequestID
        var sidebarGatewayStatus: GatewayDisplayState
        var startupRoute: RootTabs.StartupPresentationRoute
        var shouldPresentQuickSetup: Bool
        var presentationCommand: PresentationCommand?

        init(
            gatewayConnection: GatewayConnection = .init(),
            hasConnectedOnce: Bool = false,
            onboardingComplete: Bool = false,
            gatewayConfigPresence: GatewayConfigPresence = .init(),
            shouldPresentOnLaunch: Bool = false,
            quickSetupDismissed: Bool = false,
            showOnboarding: Bool = false,
            onboardingAllowSkip: Bool = true,
            presentedSheet: PresentedSheet? = nil,
            discoveredGatewayCount: DiscoveredGatewayCount = .init())
        {
            self.gatewayConnection = gatewayConnection
            self.hasConnectedOnce = hasConnectedOnce
            self.onboardingComplete = onboardingComplete
            self.gatewayConfigPresence = gatewayConfigPresence
            self.shouldPresentOnLaunch = shouldPresentOnLaunch
            self.quickSetupDismissed = quickSetupDismissed
            self.showOnboarding = showOnboarding
            self.onboardingAllowSkip = onboardingAllowSkip
            self.presentedSheet = presentedSheet
            self.discoveredGatewayCount = discoveredGatewayCount
            self.onboardingEvaluationGate = .init()
            self.autoOpenSettingsGate = .init()
            self.handledGatewaySetupRequestID = .init()
            self.sidebarGatewayStatus = .disconnected
            self.startupRoute = .none
            self.shouldPresentQuickSetup = false
            self.presentationCommand = nil
            self.refreshPresentation()
        }

        var showGatewayProblemDetails: Bool {
            self.presentedSheet == .gatewayProblemDetails
        }

        var sidebarGatewayStatusTitle: String {
            switch self.sidebarGatewayStatus {
            case .connected:
                "Online"
            case .connecting:
                "Connecting"
            case .error:
                "Needs attention"
            case .disconnected:
                "Offline"
            }
        }

        var sidebarGatewayStatusColor: Color {
            switch self.sidebarGatewayStatus {
            case .connected:
                OpenClawBrand.ok
            case .connecting:
                OpenClawBrand.accent
            case .error:
                OpenClawBrand.warn
            case .disconnected:
                .secondary
            }
        }

        mutating func refreshPresentation() {
            self.startupRoute = Self.startupRoute(
                snapshot: RootPresentationFeature.StartupSnapshot(
                    gatewayConnection: self.gatewayConnection,
                    hasConnectedOnce: self.hasConnectedOnce,
                    onboardingComplete: self.onboardingComplete,
                    gatewayConfigPresence: self.gatewayConfigPresence,
                    shouldPresentOnLaunch: self.shouldPresentOnLaunch))
            self.shouldPresentQuickSetup = Self.shouldPresentQuickSetup(
                snapshot: RootPresentationFeature.QuickSetupSnapshot(
                    quickSetupDismissed: self.quickSetupDismissed,
                    showOnboarding: self.showOnboarding,
                    gatewayConnection: self.gatewayConnection,
                    gatewayConfigPresence: self.gatewayConfigPresence,
                    discoveredGatewayCount: self.discoveredGatewayCount),
                hasPresentedSheet: self.presentedSheet != nil)
        }

        mutating func apply(startupSnapshot snapshot: RootPresentationFeature.StartupSnapshot) {
            self.gatewayConnection = snapshot.gatewayConnection
            self.hasConnectedOnce = snapshot.hasConnectedOnce
            self.onboardingComplete = snapshot.onboardingComplete
            self.gatewayConfigPresence = snapshot.gatewayConfigPresence
            self.shouldPresentOnLaunch = snapshot.shouldPresentOnLaunch
            self.refreshPresentation()
        }

        static func startupRoute(
            snapshot: RootPresentationFeature.StartupSnapshot)
            -> RootTabs.StartupPresentationRoute
        {
            if snapshot.gatewayConnection.isConnected {
                return .none
            }
            if snapshot.shouldPresentOnLaunch || !snapshot.hasConnectedOnce || !snapshot.onboardingComplete {
                return .onboarding
            }
            if !snapshot.gatewayConfigPresence.hasExistingConfig {
                return .settings
            }
            return .none
        }

        static func shouldPresentQuickSetup(
            snapshot: RootPresentationFeature.QuickSetupSnapshot,
            hasPresentedSheet: Bool)
            -> Bool
        {
            guard !snapshot.quickSetupDismissed else { return false }
            guard !snapshot.showOnboarding else { return false }
            guard !hasPresentedSheet else { return false }
            guard !snapshot.gatewayConnection.isConnected else { return false }
            guard !snapshot.gatewayConfigPresence.hasExistingConfig else { return false }
            return snapshot.discoveredGatewayCount.hasDiscoveredGateway
        }
    }

    enum PresentationCommand: Equatable, Sendable {
        case requestLocalNetworkAccess(LocalNetworkAccessCommand)
        case openGatewaySettingsAndRequestLocalNetworkAccess(LocalNetworkAccessCommand)
    }

    @MainActor
    static func hasExistingGatewayConfig(
        appModel: NodeAppModel,
        preferredGatewayStableID: String,
        manualGatewayEnabled: Bool,
        manualGatewayHost: String)
        -> Bool
    {
        if appModel.activeGatewayConnectConfig != nil { return true }
        if GatewaySettingsStore.loadLastGatewayConnection() != nil { return true }

        let preferredStableID = preferredGatewayStableID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !preferredStableID.isEmpty { return true }

        let manualHost = manualGatewayHost.trimmingCharacters(in: .whitespacesAndNewlines)
        return manualGatewayEnabled && !manualHost.isEmpty
    }

    enum Action: Equatable, Sendable {
        case refreshPresentation
        case sidebarGatewayStatusChanged(SidebarGatewayStatusChange)
        case startupSnapshotChanged(StartupSnapshotChange)
        case quickSetupSnapshotChanged(QuickSetupSnapshotChange)
        case presentedSheetChanged(PresentedSheetChange)
        case startupPresentationEvaluationRequested(StartupPresentationEvaluationRequest)
        case forceOnboardingRequested
        case autoOpenSettingsRequested(AutoOpenSettingsRequest)
        case gatewaySetupRequestChanged(GatewaySetupRequest)
        case localNetworkAccessRequested(LocalNetworkAccessRequest)
        case onboardingVisibilityChanged(OnboardingVisibilityChange)
        case presentationCommandHandled
        case gatewayProblemDetailsButtonTapped
        case gatewayProblemDetailsDismissed
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .refreshPresentation:
                state.refreshPresentation()
                return .none

            case let .sidebarGatewayStatusChanged(change):
                state.sidebarGatewayStatus = change.status
                return .none

            case let .startupSnapshotChanged(change):
                state.apply(startupSnapshot: change.snapshot)
                return .none

            case let .quickSetupSnapshotChanged(change):
                let snapshot = change.snapshot
                state.quickSetupDismissed = snapshot.quickSetupDismissed
                state.showOnboarding = snapshot.showOnboarding
                state.gatewayConnection = snapshot.gatewayConnection
                state.gatewayConfigPresence = snapshot.gatewayConfigPresence
                state.discoveredGatewayCount = snapshot.discoveredGatewayCount
                state.refreshPresentation()
                if state.shouldPresentQuickSetup {
                    state.presentedSheet = .quickSetup
                    state.refreshPresentation()
                }
                return .none

            case let .presentedSheetChanged(change):
                state.presentedSheet = change.sheet
                state.refreshPresentation()
                return .none

            case let .startupPresentationEvaluationRequested(request):
                guard !state.onboardingEvaluationGate.didEvaluate else { return .none }
                state.onboardingEvaluationGate.markEvaluated()
                state.apply(startupSnapshot: request.snapshot)

                switch state.startupRoute {
                case .none:
                    state.presentationCommand = .requestLocalNetworkAccess(
                        LocalNetworkAccessCommand(reason: .rootAppear))
                case .onboarding:
                    state.onboardingAllowSkip = true
                    state.showOnboarding = true
                    state.refreshPresentation()
                case .settings:
                    state.autoOpenSettingsGate.markOpened()
                    state.presentationCommand = .openGatewaySettingsAndRequestLocalNetworkAccess(
                        LocalNetworkAccessCommand(reason: .rootAppear))
                }
                return .none

            case .forceOnboardingRequested:
                state.onboardingAllowSkip = true
                state.showOnboarding = true
                state.refreshPresentation()
                return .none

            case let .autoOpenSettingsRequested(request):
                guard !state.autoOpenSettingsGate.didOpen else { return .none }
                guard !state.showOnboarding else { return .none }
                state.apply(startupSnapshot: request.snapshot)
                guard state.startupRoute == .settings else { return .none }
                state.autoOpenSettingsGate.markOpened()
                state.presentationCommand = .openGatewaySettingsAndRequestLocalNetworkAccess(
                    LocalNetworkAccessCommand(reason: .autoOpenSettings))
                return .none

            case let .gatewaySetupRequestChanged(request):
                guard !request.requestID.isUnset,
                      request.requestID != state.handledGatewaySetupRequestID
                else { return .none }
                state.handledGatewaySetupRequestID = request.requestID
                state.showOnboarding = false
                state.autoOpenSettingsGate.markOpened()
                state.presentedSheet = nil
                state.refreshPresentation()
                state.presentationCommand = .openGatewaySettingsAndRequestLocalNetworkAccess(
                    LocalNetworkAccessCommand(reason: .gatewaySetupDeeplink))
                return .none

            case let .localNetworkAccessRequested(request):
                guard state.onboardingEvaluationGate.didEvaluate else { return .none }
                guard request.sceneActivity.isActive else { return .none }
                guard !state.showOnboarding else { return .none }
                state.presentationCommand = .requestLocalNetworkAccess(
                    LocalNetworkAccessCommand(reason: request.reason))
                return .none

            case let .onboardingVisibilityChanged(change):
                let wasPresented = state.showOnboarding
                state.showOnboarding = change.presentation.isPresented
                state.refreshPresentation()
                guard wasPresented, !change.presentation.isPresented else { return .none }
                guard state.onboardingEvaluationGate.didEvaluate, change.sceneActivity.isActive else { return .none }
                state.presentationCommand = .requestLocalNetworkAccess(
                    LocalNetworkAccessCommand(reason: .onboardingDismissed))
                return .none

            case .presentationCommandHandled:
                state.presentationCommand = nil
                return .none

            case .gatewayProblemDetailsButtonTapped:
                state.presentedSheet = .gatewayProblemDetails
                state.refreshPresentation()
                return .none

            case .gatewayProblemDetailsDismissed:
                if state.presentedSheet == .gatewayProblemDetails {
                    state.presentedSheet = nil
                    state.refreshPresentation()
                }
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct RootSidebarFeature {
    // swiftformat:disable redundantSendable
    struct LayoutResolutionForce: Equatable, Sendable { var isForced: Bool }
    struct SidebarVisibility: Equatable, Sendable { var isVisible: Bool }
    struct SidebarUserOverride: Equatable, Sendable { var value: Bool }
    struct LayoutResolutionState: Equatable, Sendable { var didResolve: Bool }

    struct LayoutModeResolution: Equatable, Sendable {
        var layoutMode: RootTabs.SidebarLayoutMode
        var force: LayoutResolutionForce
    }

    struct VisibilityChange: Equatable, Sendable {
        var visibility: SidebarVisibility
    }

    @ObservableState
    struct State: Equatable, Sendable {
        var visibility: SidebarVisibility
        var userOverride: SidebarUserOverride
        var layoutMode: RootTabs.SidebarLayoutMode
        var layoutResolution: LayoutResolutionState

        init(initialVisibility: Bool? = nil) {
            self.visibility = .init(isVisible: initialVisibility ?? false)
            self.userOverride = .init(value: initialVisibility != nil)
            self.layoutMode = .split
            self.layoutResolution = .init(didResolve: false)
        }

        static func preferredVisibility(layoutMode: RootTabs.SidebarLayoutMode) -> Bool {
            layoutMode == .split
        }
    }

    enum Action: Equatable, Sendable {
        case layoutModeResolved(LayoutModeResolution)
        case showRequested
        case hideRequested
        case visibilityChanged(VisibilityChange)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .layoutModeResolved(resolution):
                let previousLayoutMode = state.layoutMode
                let didResolvePreviousLayout = state.layoutResolution.didResolve
                let layoutMode = resolution.layoutMode
                let layoutModeDidChange = layoutMode != previousLayoutMode
                state.layoutResolution = .init(didResolve: true)
                state.layoutMode = layoutMode
                if layoutModeDidChange && didResolvePreviousLayout {
                    state.userOverride = .init(value: false)
                }
                guard resolution.force.isForced || !state.userOverride.value else { return .none }
                state.visibility = .init(isVisible: State.preferredVisibility(layoutMode: layoutMode))
                return .none

            case .showRequested:
                state.userOverride = .init(value: true)
                state.visibility = .init(isVisible: true)
                return .none

            case .hideRequested:
                state.userOverride = .init(value: true)
                state.visibility = .init(isVisible: false)
                return .none

            case let .visibilityChanged(change):
                state.visibility = change.visibility
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct RootNavigationSelectionFeature {
    // swiftformat:disable redundantSendable
    struct TabSelection: Equatable, Sendable {
        var tab: RootTabs.AppTab
    }

    struct SidebarDestinationSelection: Equatable, Sendable {
        var destination: RootTabs.SidebarDestination
    }

    struct SettingsRouteSelection: Equatable, Sendable {
        var route: SettingsRoute
    }

    struct NotificationPermissionSettingsRequest: Equatable, Sendable {
        var suppressedApprovalID: ExecApprovalPromptSuppressionID
    }

    struct PendingExecApprovalPromptChange: Equatable, Sendable {
        var promptID: ExecApprovalPromptSuppressionID?
    }

    struct SidebarNavigationPathChange: Equatable, Sendable {
        var path: [SettingsRoute]
    }

    struct SidebarSettingsRoutePush: Equatable, Sendable {
        var route: SettingsRoute
    }

    struct SettingsRouteChange: Equatable, Sendable {
        var route: SettingsRoute?
    }

    struct SettingsRouteRequestID: Equatable, Sendable {
        var value: Int

        init(value: Int = 0) {
            self.value = value
        }

        mutating func bump() {
            self.value &+= 1
        }
    }

    struct ExecApprovalPromptSuppressionID: Equatable, Sendable {
        var value: String
    }

    @ObservableState
    struct State: Equatable, Sendable {
        var selectedTab: RootTabs.AppTab
        var selectedSidebarDestination: RootTabs.SidebarDestination
        var selectedSettingsRoute: SettingsRoute?
        var selectedSettingsRouteRequestID: SettingsRouteRequestID
        var sidebarNavigationPath: [SettingsRoute]
        var notificationSettingsPromptSuppression: ExecApprovalPromptSuppressionID?

        init(
            selectedTab: RootTabs.AppTab,
            selectedSidebarDestination: RootTabs.SidebarDestination)
        {
            self.selectedTab = selectedTab
            self.selectedSidebarDestination = selectedSidebarDestination
            self.selectedSettingsRoute = selectedSidebarDestination.settingsRoute
            self.selectedSettingsRouteRequestID = .init()
            self.sidebarNavigationPath = []
            self.notificationSettingsPromptSuppression = nil
        }

        var activeExecApprovalPromptSuppressionID: String? {
            guard self.selectedTab == .settings, self.selectedSettingsRoute == .notifications else { return nil }
            return self.notificationSettingsPromptSuppression?.value
        }
    }

    enum Action: Equatable, Sendable {
        case tabSelected(TabSelection)
        case sidebarDestinationSelected(SidebarDestinationSelection)
        case settingsRouteSelected(SettingsRouteSelection)
        case sidebarNavigationPathChanged(SidebarNavigationPathChange)
        case sidebarSettingsRoutePushed(SidebarSettingsRoutePush)
        case settingsRouteChanged(SettingsRouteChange)
        case notificationPermissionSettingsOpened(NotificationPermissionSettingsRequest)
        case pendingExecApprovalPromptChanged(PendingExecApprovalPromptChange)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .tabSelected(selection):
                state.selectedTab = selection.tab
                return .none

            case let .sidebarDestinationSelected(selection):
                let destination = selection.destination
                state.sidebarNavigationPath.removeAll()
                if destination.settingsRoute != .notifications {
                    state.notificationSettingsPromptSuppression = nil
                }
                state.selectedSidebarDestination = destination
                state.selectedSettingsRoute = destination.settingsRoute
                state.selectedTab = destination.appTab
                return .none

            case let .settingsRouteSelected(selection):
                self.selectSettingsRoute(selection.route, state: &state)
                return .none

            case let .sidebarNavigationPathChanged(change):
                state.sidebarNavigationPath = change.path
                return .none

            case let .sidebarSettingsRoutePushed(push):
                state.sidebarNavigationPath = [push.route]
                self.handleSettingsRouteChange(push.route, state: &state)
                return .none

            case let .settingsRouteChanged(change):
                self.handleSettingsRouteChange(change.route, state: &state)
                return .none

            case let .notificationPermissionSettingsOpened(request):
                state.notificationSettingsPromptSuppression = request.suppressedApprovalID
                self.selectSettingsRoute(.notifications, state: &state)
                return .none

            case let .pendingExecApprovalPromptChanged(change):
                if change.promptID != state.notificationSettingsPromptSuppression {
                    state.notificationSettingsPromptSuppression = nil
                }
                return .none
            }
        }
        .autoLogActions()
    }

    private func selectSettingsRoute(
        _ route: SettingsRoute,
        state: inout State)
    {
        state.sidebarNavigationPath.removeAll()
        if route != .notifications {
            state.notificationSettingsPromptSuppression = nil
        }
        state.selectedSettingsRoute = route
        state.selectedSettingsRouteRequestID.bump()
        state.selectedSidebarDestination = .settings
        state.selectedTab = .settings
    }

    private func handleSettingsRouteChange(
        _ route: SettingsRoute?,
        state: inout State)
    {
        guard route != .notifications else { return }
        if route == nil {
            state.selectedSettingsRoute = nil
            if state.selectedTab == .settings {
                state.selectedSidebarDestination = .settings
            }
        }
        state.notificationSettingsPromptSuppression = nil
    }
}

extension RootTabs {
    private static var sidebarPersistentWidthThreshold: CGFloat {
        980
    }

    static let sidebarSplitIdealWidth: CGFloat = 316
    static let sidebarSplitMaximumWidth: CGFloat = 340
    static let sidebarDrawerMaximumWidth: CGFloat = 340
    static let sidebarShowButtonAccessibilityIdentifier = "RootTabs.Sidebar.Show"
    static let sidebarHideButtonAccessibilityIdentifier = "RootTabs.Sidebar.Hide"

    enum AppTab: Hashable {
        case control
        case chat
        case talk
        case agent
        case settings
    }

    enum SidebarDestination: String, CaseIterable, Hashable, Identifiable {
        case chat
        case talk
        case overview
        case activity
        case agents
        case workboard
        case skillWorkshop
        case instances
        case sessions
        case dreaming
        case usage
        case cron
        case docs
        case settings
        case gateway

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .chat: "Chat"
            case .talk: "Talk"
            case .overview: "Overview"
            case .activity: "Activity"
            case .agents: "Agents"
            case .workboard: "Workboard"
            case .skillWorkshop: "Skill Workshop"
            case .instances: "Instances"
            case .sessions: "Sessions"
            case .dreaming: "Dreaming"
            case .usage: "Usage"
            case .cron: "Cron Jobs"
            case .docs: "Docs"
            case .settings: "Settings"
            case .gateway: "Settings / Gateway"
            }
        }

        var sidebarTitle: String {
            switch self {
            case .gateway: "Connection"
            default: self.title
            }
        }

        var systemImage: String {
            switch self {
            case .chat: "bubble.left"
            case .talk: "waveform.circle"
            case .overview: "chart.bar"
            case .activity: "waveform.path.ecg"
            case .agents: "person.2"
            case .workboard: "folder"
            case .skillWorkshop: "hammer"
            case .instances: "dot.radiowaves.left.and.right"
            case .sessions: "doc.text"
            case .dreaming: "moon.stars"
            case .usage: "chart.bar.xaxis"
            case .cron: "timer"
            case .docs: "book"
            case .settings: "gearshape"
            case .gateway: "gearshape"
            }
        }

        var appTab: AppTab {
            switch self {
            case .chat:
                .chat
            case .talk:
                .talk
            case .agents:
                .agent
            case .settings, .gateway:
                .settings
            case .overview, .activity, .workboard, .skillWorkshop, .instances, .sessions, .dreaming,
                 .usage,
                 .cron, .docs:
                .control
            }
        }

        var settingsRoute: SettingsRoute? {
            switch self {
            case .gateway:
                .gateway
            case .chat, .talk, .overview, .activity, .agents, .workboard, .skillWorkshop, .instances, .sessions,
                 .dreaming,
                 .usage, .cron, .settings, .docs:
                nil
            }
        }
    }

    enum SidebarLayoutMode: Equatable {
        case drawer
        case split
    }

    static func sidebarLayoutMode(containerSize: CGSize) -> SidebarLayoutMode {
        containerSize.width < self.sidebarPersistentWidthThreshold || containerSize.height > containerSize.width
            ? .drawer
            : .split
    }

    static func preferredSidebarVisibility(layoutMode: SidebarLayoutMode) -> Bool {
        layoutMode == .split
    }

    static func shouldCollapseSidebarAfterSelection(layoutMode: SidebarLayoutMode) -> Bool {
        layoutMode == .drawer
    }

    static func sidebarWidth(containerWidth: CGFloat, isDrawerLayout: Bool) -> CGFloat {
        if isDrawerLayout {
            return min(self.sidebarDrawerMaximumWidth, max(280, containerWidth * 0.86))
        }
        return min(self.sidebarSplitMaximumWidth, max(self.sidebarSplitIdealWidth, containerWidth * 0.25))
    }

    static func shouldShowSidebarRevealControl(isSidebarVisible: Bool) -> Bool {
        !isSidebarVisible
    }

    static func shouldShowSidebarRevealInDestinationHeader(
        isSidebarVisible: Bool,
        layoutMode: SidebarLayoutMode) -> Bool
    {
        switch layoutMode {
        case .split:
            true
        case .drawer:
            self.shouldShowSidebarRevealControl(isSidebarVisible: isSidebarVisible)
        }
    }

    static func requestedInitialSidebarVisibility(arguments: [String]) -> Bool? {
        guard let flagIndex = arguments.firstIndex(of: "--openclaw-sidebar-visibility") else {
            return nil
        }
        let valueIndex = arguments.index(after: flagIndex)
        guard arguments.indices.contains(valueIndex) else { return nil }

        switch arguments[valueIndex].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "visible", "show", "shown", "open", "true", "1":
            return true
        case "hidden", "hide", "closed", "false", "0":
            return false
        default:
            return nil
        }
    }

    static func shouldOpenRootTabFromPhoneHub(_ destination: SidebarDestination) -> Bool {
        switch destination {
        case .chat, .talk, .agents, .gateway, .settings:
            true
        case .overview, .activity, .workboard, .skillWorkshop, .instances, .sessions, .dreaming,
             .usage,
             .cron, .docs:
            false
        }
    }

    static func defaultSidebarDestination(for tab: AppTab) -> SidebarDestination {
        switch tab {
        case .control:
            .overview
        case .chat:
            .chat
        case .talk:
            .talk
        case .agent:
            .agents
        case .settings:
            .settings
        }
    }

    enum StartupPresentationRoute: Equatable {
        case none
        case onboarding
        case settings
    }

    static func startupPresentationRoute(
        snapshot: RootPresentationFeature.StartupSnapshot) -> StartupPresentationRoute
    {
        RootPresentationFeature.State.startupRoute(
            snapshot: snapshot)
    }

    static func shouldPresentQuickSetup(
        snapshot: RootPresentationFeature.QuickSetupSnapshot,
        hasPresentedSheet: Bool) -> Bool
    {
        RootPresentationFeature.State.shouldPresentQuickSetup(
            snapshot: snapshot,
            hasPresentedSheet: hasPresentedSheet)
    }

    struct SidebarGroup: Identifiable {
        let title: String
        let destinations: [SidebarDestination]

        var id: String {
            self.title
        }
    }

    static let sidebarGroups: [SidebarGroup] = [
        SidebarGroup(title: "CHAT", destinations: [.chat, .talk]),
        SidebarGroup(
            title: "CONTROL",
            destinations: [
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
            ]),
        SidebarGroup(
            title: "SETTINGS",
            destinations: [.settings]),
        SidebarGroup(title: "REFERENCE", destinations: [.docs]),
    ]

    static var phoneControlGroups: [SidebarGroup] {
        self.sidebarGroups
            .map { group in
                SidebarGroup(
                    title: group.title,
                    destinations: group.destinations.filter { $0 != .agents })
            }
            .filter { !$0.destinations.isEmpty }
    }
}
