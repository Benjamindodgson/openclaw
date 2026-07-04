import ComposableArchitecture
import CoreGraphics
import Foundation
import SwiftUI

@Reducer
struct RootPresentationFeature {
    // swiftformat:disable redundantSendable
    enum PresentedSheet: Int, Identifiable, Equatable, Sendable {
        case quickSetup

        var id: Int {
            self.rawValue
        }
    }

    struct StartupSnapshot: Equatable, Sendable {
        var gatewayConnected: Bool
        var hasConnectedOnce: Bool
        var onboardingComplete: Bool
        var hasExistingGatewayConfig: Bool
        var shouldPresentOnLaunch: Bool
    }

    struct QuickSetupSnapshot: Equatable, Sendable {
        var quickSetupDismissed: Bool
        var showOnboarding: Bool
        var gatewayConnected: Bool
        var hasExistingGatewayConfig: Bool
        var discoveredGatewayCount: Int
    }

    struct LocalNetworkAccessRequest: Equatable, Sendable {
        var reason: String
        var sceneActive: Bool
    }

    struct OnboardingVisibilityChange: Equatable, Sendable {
        var isPresented: Bool
        var sceneActive: Bool
    }

    struct GatewaySetupRequest: Equatable, Sendable {
        var requestID: Int
    }

    @ObservableState
    struct State: Equatable, Sendable {
        var gatewayConnected: Bool
        var hasConnectedOnce: Bool
        var onboardingComplete: Bool
        var hasExistingGatewayConfig: Bool
        var shouldPresentOnLaunch: Bool
        var quickSetupDismissed: Bool
        var showOnboarding: Bool
        var onboardingAllowSkip: Bool
        var presentedSheet: PresentedSheet?
        var discoveredGatewayCount: Int
        var didEvaluateOnboarding: Bool
        var didAutoOpenSettings: Bool
        var handledGatewaySetupRequestID: Int
        var showGatewayProblemDetails: Bool
        var sidebarGatewayStatus: GatewayDisplayState
        var startupRoute: RootTabs.StartupPresentationRoute
        var shouldPresentQuickSetup: Bool
        var presentationCommand: PresentationCommand?

        init(
            gatewayConnected: Bool = false,
            hasConnectedOnce: Bool = false,
            onboardingComplete: Bool = false,
            hasExistingGatewayConfig: Bool = false,
            shouldPresentOnLaunch: Bool = false,
            quickSetupDismissed: Bool = false,
            showOnboarding: Bool = false,
            onboardingAllowSkip: Bool = true,
            presentedSheet: PresentedSheet? = nil,
            discoveredGatewayCount: Int = 0)
        {
            self.gatewayConnected = gatewayConnected
            self.hasConnectedOnce = hasConnectedOnce
            self.onboardingComplete = onboardingComplete
            self.hasExistingGatewayConfig = hasExistingGatewayConfig
            self.shouldPresentOnLaunch = shouldPresentOnLaunch
            self.quickSetupDismissed = quickSetupDismissed
            self.showOnboarding = showOnboarding
            self.onboardingAllowSkip = onboardingAllowSkip
            self.presentedSheet = presentedSheet
            self.discoveredGatewayCount = discoveredGatewayCount
            self.didEvaluateOnboarding = false
            self.didAutoOpenSettings = false
            self.handledGatewaySetupRequestID = 0
            self.showGatewayProblemDetails = false
            self.sidebarGatewayStatus = .disconnected
            self.startupRoute = .none
            self.shouldPresentQuickSetup = false
            self.presentationCommand = nil
            self.refreshPresentation()
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
                    gatewayConnected: self.gatewayConnected,
                    hasConnectedOnce: self.hasConnectedOnce,
                    onboardingComplete: self.onboardingComplete,
                    hasExistingGatewayConfig: self.hasExistingGatewayConfig,
                    shouldPresentOnLaunch: self.shouldPresentOnLaunch))
            self.shouldPresentQuickSetup = Self.shouldPresentQuickSetup(
                snapshot: RootPresentationFeature.QuickSetupSnapshot(
                    quickSetupDismissed: self.quickSetupDismissed,
                    showOnboarding: self.showOnboarding,
                    gatewayConnected: self.gatewayConnected,
                    hasExistingGatewayConfig: self.hasExistingGatewayConfig,
                    discoveredGatewayCount: self.discoveredGatewayCount),
                hasPresentedSheet: self.presentedSheet != nil)
        }

        mutating func apply(startupSnapshot snapshot: RootPresentationFeature.StartupSnapshot) {
            self.gatewayConnected = snapshot.gatewayConnected
            self.hasConnectedOnce = snapshot.hasConnectedOnce
            self.onboardingComplete = snapshot.onboardingComplete
            self.hasExistingGatewayConfig = snapshot.hasExistingGatewayConfig
            self.shouldPresentOnLaunch = snapshot.shouldPresentOnLaunch
            self.refreshPresentation()
        }

        static func startupRoute(
            snapshot: RootPresentationFeature.StartupSnapshot)
            -> RootTabs.StartupPresentationRoute
        {
            if snapshot.gatewayConnected {
                return .none
            }
            if snapshot.shouldPresentOnLaunch || !snapshot.hasConnectedOnce || !snapshot.onboardingComplete {
                return .onboarding
            }
            if !snapshot.hasExistingGatewayConfig {
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
            guard !snapshot.gatewayConnected else { return false }
            guard !snapshot.hasExistingGatewayConfig else { return false }
            return snapshot.discoveredGatewayCount > 0
        }
    }

    enum PresentationCommand: Equatable, Sendable {
        case requestLocalNetworkAccess(reason: String)
        case openGatewaySettingsAndRequestLocalNetworkAccess(reason: String)
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
        case sidebarGatewayStatusChanged(GatewayDisplayState)
        case startupSnapshotChanged(StartupSnapshot)
        case quickSetupSnapshotChanged(QuickSetupSnapshot)
        case presentedSheetChanged(PresentedSheet?)
        case startupPresentationEvaluationRequested(StartupSnapshot)
        case forceOnboardingRequested
        case autoOpenSettingsRequested(StartupSnapshot)
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

            case let .sidebarGatewayStatusChanged(status):
                state.sidebarGatewayStatus = status
                return .none

            case let .startupSnapshotChanged(snapshot):
                state.apply(startupSnapshot: snapshot)
                return .none

            case let .quickSetupSnapshotChanged(snapshot):
                state.quickSetupDismissed = snapshot.quickSetupDismissed
                state.showOnboarding = snapshot.showOnboarding
                state.gatewayConnected = snapshot.gatewayConnected
                state.hasExistingGatewayConfig = snapshot.hasExistingGatewayConfig
                state.discoveredGatewayCount = snapshot.discoveredGatewayCount
                state.refreshPresentation()
                if state.shouldPresentQuickSetup {
                    state.presentedSheet = .quickSetup
                    state.refreshPresentation()
                }
                return .none

            case let .presentedSheetChanged(sheet):
                state.presentedSheet = sheet
                state.refreshPresentation()
                return .none

            case let .startupPresentationEvaluationRequested(snapshot):
                guard !state.didEvaluateOnboarding else { return .none }
                state.didEvaluateOnboarding = true
                state.apply(startupSnapshot: snapshot)

                switch state.startupRoute {
                case .none:
                    state.presentationCommand = .requestLocalNetworkAccess(reason: "root_appear")
                case .onboarding:
                    state.onboardingAllowSkip = true
                    state.showOnboarding = true
                    state.refreshPresentation()
                case .settings:
                    state.didAutoOpenSettings = true
                    state.presentationCommand = .openGatewaySettingsAndRequestLocalNetworkAccess(
                        reason: "root_appear")
                }
                return .none

            case .forceOnboardingRequested:
                state.onboardingAllowSkip = true
                state.showOnboarding = true
                state.refreshPresentation()
                return .none

            case let .autoOpenSettingsRequested(snapshot):
                guard !state.didAutoOpenSettings else { return .none }
                guard !state.showOnboarding else { return .none }
                state.apply(startupSnapshot: snapshot)
                guard state.startupRoute == .settings else { return .none }
                state.didAutoOpenSettings = true
                state.presentationCommand = .openGatewaySettingsAndRequestLocalNetworkAccess(
                    reason: "auto_open_settings")
                return .none

            case let .gatewaySetupRequestChanged(request):
                guard request.requestID != 0,
                      request.requestID != state.handledGatewaySetupRequestID
                else { return .none }
                state.handledGatewaySetupRequestID = request.requestID
                state.showOnboarding = false
                state.didAutoOpenSettings = true
                state.presentedSheet = nil
                state.refreshPresentation()
                state.presentationCommand = .openGatewaySettingsAndRequestLocalNetworkAccess(
                    reason: "gateway_setup_deeplink")
                return .none

            case let .localNetworkAccessRequested(request):
                guard state.didEvaluateOnboarding else { return .none }
                guard request.sceneActive else { return .none }
                guard !state.showOnboarding else { return .none }
                state.presentationCommand = .requestLocalNetworkAccess(reason: request.reason)
                return .none

            case let .onboardingVisibilityChanged(change):
                let wasPresented = state.showOnboarding
                state.showOnboarding = change.isPresented
                state.refreshPresentation()
                guard wasPresented, !change.isPresented else { return .none }
                guard state.didEvaluateOnboarding, change.sceneActive else { return .none }
                state.presentationCommand = .requestLocalNetworkAccess(reason: "onboarding_dismissed")
                return .none

            case .presentationCommandHandled:
                state.presentationCommand = nil
                return .none

            case .gatewayProblemDetailsButtonTapped:
                state.showGatewayProblemDetails = true
                return .none

            case .gatewayProblemDetailsDismissed:
                state.showGatewayProblemDetails = false
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct RootSidebarFeature {
    // swiftformat:disable redundantSendable
    struct LayoutModeResolution: Equatable, Sendable {
        var layoutMode: RootTabs.SidebarLayoutMode
        var force: Bool
    }

    struct VisibilityChange: Equatable, Sendable {
        var isVisible: Bool
    }

    @ObservableState
    struct State: Equatable, Sendable {
        var isVisible: Bool
        var userOverridden: Bool
        var layoutMode: RootTabs.SidebarLayoutMode
        var didResolveLayout: Bool

        init(initialVisibility: Bool? = nil) {
            self.isVisible = initialVisibility ?? false
            self.userOverridden = initialVisibility != nil
            self.layoutMode = .split
            self.didResolveLayout = false
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
                let didResolvePreviousLayout = state.didResolveLayout
                let layoutMode = resolution.layoutMode
                let layoutModeDidChange = layoutMode != previousLayoutMode
                state.didResolveLayout = true
                state.layoutMode = layoutMode
                if layoutModeDidChange && didResolvePreviousLayout {
                    state.userOverridden = false
                }
                guard resolution.force || !state.userOverridden else { return .none }
                state.isVisible = State.preferredVisibility(layoutMode: layoutMode)
                return .none

            case .showRequested:
                state.userOverridden = true
                state.isVisible = true
                return .none

            case .hideRequested:
                state.userOverridden = true
                state.isVisible = false
                return .none

            case let .visibilityChanged(change):
                state.isVisible = change.isVisible
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
        var suppressedApprovalID: String
    }

    struct PendingExecApprovalPromptChange: Equatable, Sendable {
        var promptID: String?
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

    @ObservableState
    struct State: Equatable, Sendable {
        var selectedTab: RootTabs.AppTab
        var selectedSidebarDestination: RootTabs.SidebarDestination
        var selectedSettingsRoute: SettingsRoute?
        var selectedSettingsRouteRequestID: Int
        var sidebarNavigationPath: [SettingsRoute]
        var suppressedExecApprovalPromptIDForNotificationSettings: String?

        init(
            selectedTab: RootTabs.AppTab,
            selectedSidebarDestination: RootTabs.SidebarDestination)
        {
            self.selectedTab = selectedTab
            self.selectedSidebarDestination = selectedSidebarDestination
            self.selectedSettingsRoute = selectedSidebarDestination.settingsRoute
            self.selectedSettingsRouteRequestID = 0
            self.sidebarNavigationPath = []
            self.suppressedExecApprovalPromptIDForNotificationSettings = nil
        }

        var activeExecApprovalPromptSuppressionID: String? {
            guard self.selectedTab == .settings, self.selectedSettingsRoute == .notifications else { return nil }
            return self.suppressedExecApprovalPromptIDForNotificationSettings
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
                    state.suppressedExecApprovalPromptIDForNotificationSettings = nil
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
                state.suppressedExecApprovalPromptIDForNotificationSettings = request.suppressedApprovalID
                self.selectSettingsRoute(.notifications, state: &state)
                return .none

            case let .pendingExecApprovalPromptChanged(change):
                if change.promptID != state.suppressedExecApprovalPromptIDForNotificationSettings {
                    state.suppressedExecApprovalPromptIDForNotificationSettings = nil
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
            state.suppressedExecApprovalPromptIDForNotificationSettings = nil
        }
        state.selectedSettingsRoute = route
        state.selectedSettingsRouteRequestID &+= 1
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
        state.suppressedExecApprovalPromptIDForNotificationSettings = nil
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
