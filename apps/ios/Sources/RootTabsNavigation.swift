import ComposableArchitecture
import CoreGraphics
import Foundation
import SwiftUI

@Reducer
struct RootPresentationFeature {
    // swiftformat:disable redundantSendable
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
        var hasPresentedSheet: Bool
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
            hasPresentedSheet: Bool = false,
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
            self.hasPresentedSheet = hasPresentedSheet
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
                gatewayConnected: self.gatewayConnected,
                hasConnectedOnce: self.hasConnectedOnce,
                onboardingComplete: self.onboardingComplete,
                hasExistingGatewayConfig: self.hasExistingGatewayConfig,
                shouldPresentOnLaunch: self.shouldPresentOnLaunch)
            self.shouldPresentQuickSetup = Self.shouldPresentQuickSetup(
                quickSetupDismissed: self.quickSetupDismissed,
                showOnboarding: self.showOnboarding,
                hasPresentedSheet: self.hasPresentedSheet,
                gatewayConnected: self.gatewayConnected,
                hasExistingGatewayConfig: self.hasExistingGatewayConfig,
                discoveredGatewayCount: self.discoveredGatewayCount)
        }

        static func startupRoute(
            gatewayConnected: Bool,
            hasConnectedOnce: Bool,
            onboardingComplete: Bool,
            hasExistingGatewayConfig: Bool,
            shouldPresentOnLaunch: Bool)
            -> RootTabs.StartupPresentationRoute
        {
            if gatewayConnected {
                return .none
            }
            if shouldPresentOnLaunch || !hasConnectedOnce || !onboardingComplete {
                return .onboarding
            }
            if !hasExistingGatewayConfig {
                return .settings
            }
            return .none
        }

        static func shouldPresentQuickSetup(
            quickSetupDismissed: Bool,
            showOnboarding: Bool,
            hasPresentedSheet: Bool,
            gatewayConnected: Bool,
            hasExistingGatewayConfig: Bool,
            discoveredGatewayCount: Int)
            -> Bool
        {
            guard !quickSetupDismissed else { return false }
            guard !showOnboarding else { return false }
            guard !hasPresentedSheet else { return false }
            guard !gatewayConnected else { return false }
            guard !hasExistingGatewayConfig else { return false }
            return discoveredGatewayCount > 0
        }
    }

    enum PresentationCommand: Equatable, Sendable {
        case requestLocalNetworkAccess(reason: String)
        case openGatewaySettingsAndRequestLocalNetworkAccess(reason: String, dismissPresentedSheet: Bool)
    }

    enum Action: Equatable, Sendable {
        case refreshPresentation
        case sidebarGatewayStatusChanged(GatewayDisplayState)
        case startupSnapshotChanged(
            gatewayConnected: Bool,
            hasConnectedOnce: Bool,
            onboardingComplete: Bool,
            hasExistingGatewayConfig: Bool,
            shouldPresentOnLaunch: Bool)
        case quickSetupSnapshotChanged(
            quickSetupDismissed: Bool,
            showOnboarding: Bool,
            hasPresentedSheet: Bool,
            gatewayConnected: Bool,
            hasExistingGatewayConfig: Bool,
            discoveredGatewayCount: Int)
        case startupPresentationEvaluationRequested(
            gatewayConnected: Bool,
            hasConnectedOnce: Bool,
            onboardingComplete: Bool,
            hasExistingGatewayConfig: Bool,
            shouldPresentOnLaunch: Bool)
        case forceOnboardingRequested
        case autoOpenSettingsRequested(
            gatewayConnected: Bool,
            hasConnectedOnce: Bool,
            onboardingComplete: Bool,
            hasExistingGatewayConfig: Bool)
        case gatewaySetupRequestChanged(Int)
        case localNetworkAccessRequested(reason: String, sceneActive: Bool)
        case onboardingVisibilityChanged(isPresented: Bool, sceneActive: Bool)
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

            case let .startupSnapshotChanged(
                gatewayConnected,
                hasConnectedOnce,
                onboardingComplete,
                hasExistingGatewayConfig,
                shouldPresentOnLaunch):
                state.gatewayConnected = gatewayConnected
                state.hasConnectedOnce = hasConnectedOnce
                state.onboardingComplete = onboardingComplete
                state.hasExistingGatewayConfig = hasExistingGatewayConfig
                state.shouldPresentOnLaunch = shouldPresentOnLaunch
                state.refreshPresentation()
                return .none

            case let .quickSetupSnapshotChanged(
                quickSetupDismissed,
                showOnboarding,
                hasPresentedSheet,
                gatewayConnected,
                hasExistingGatewayConfig,
                discoveredGatewayCount):
                state.quickSetupDismissed = quickSetupDismissed
                state.showOnboarding = showOnboarding
                state.hasPresentedSheet = hasPresentedSheet
                state.gatewayConnected = gatewayConnected
                state.hasExistingGatewayConfig = hasExistingGatewayConfig
                state.discoveredGatewayCount = discoveredGatewayCount
                state.refreshPresentation()
                return .none

            case let .startupPresentationEvaluationRequested(
                gatewayConnected,
                hasConnectedOnce,
                onboardingComplete,
                hasExistingGatewayConfig,
                shouldPresentOnLaunch):
                guard !state.didEvaluateOnboarding else { return .none }
                state.didEvaluateOnboarding = true
                state.gatewayConnected = gatewayConnected
                state.hasConnectedOnce = hasConnectedOnce
                state.onboardingComplete = onboardingComplete
                state.hasExistingGatewayConfig = hasExistingGatewayConfig
                state.shouldPresentOnLaunch = shouldPresentOnLaunch
                state.refreshPresentation()

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
                        reason: "root_appear",
                        dismissPresentedSheet: false)
                }
                return .none

            case .forceOnboardingRequested:
                state.onboardingAllowSkip = true
                state.showOnboarding = true
                state.refreshPresentation()
                return .none

            case let .autoOpenSettingsRequested(
                gatewayConnected,
                hasConnectedOnce,
                onboardingComplete,
                hasExistingGatewayConfig):
                guard !state.didAutoOpenSettings else { return .none }
                guard !state.showOnboarding else { return .none }
                state.gatewayConnected = gatewayConnected
                state.hasConnectedOnce = hasConnectedOnce
                state.onboardingComplete = onboardingComplete
                state.hasExistingGatewayConfig = hasExistingGatewayConfig
                state.shouldPresentOnLaunch = false
                state.refreshPresentation()
                let route = Self.State.startupRoute(
                    gatewayConnected: gatewayConnected,
                    hasConnectedOnce: hasConnectedOnce,
                    onboardingComplete: onboardingComplete,
                    hasExistingGatewayConfig: hasExistingGatewayConfig,
                    shouldPresentOnLaunch: false)
                guard route == .settings else { return .none }
                state.didAutoOpenSettings = true
                state.presentationCommand = .openGatewaySettingsAndRequestLocalNetworkAccess(
                    reason: "auto_open_settings",
                    dismissPresentedSheet: false)
                return .none

            case let .gatewaySetupRequestChanged(requestID):
                guard requestID != 0, requestID != state.handledGatewaySetupRequestID else { return .none }
                state.handledGatewaySetupRequestID = requestID
                state.showOnboarding = false
                state.didAutoOpenSettings = true
                state.refreshPresentation()
                state.presentationCommand = .openGatewaySettingsAndRequestLocalNetworkAccess(
                    reason: "gateway_setup_deeplink",
                    dismissPresentedSheet: true)
                return .none

            case let .localNetworkAccessRequested(reason, sceneActive):
                guard state.didEvaluateOnboarding else { return .none }
                guard sceneActive else { return .none }
                guard !state.showOnboarding else { return .none }
                state.presentationCommand = .requestLocalNetworkAccess(reason: reason)
                return .none

            case let .onboardingVisibilityChanged(isPresented, sceneActive):
                let wasPresented = state.showOnboarding
                state.showOnboarding = isPresented
                state.refreshPresentation()
                guard wasPresented, !isPresented else { return .none }
                guard state.didEvaluateOnboarding, sceneActive else { return .none }
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
        gatewayConnected: Bool,
        hasConnectedOnce: Bool,
        onboardingComplete: Bool,
        hasExistingGatewayConfig: Bool,
        shouldPresentOnLaunch: Bool) -> StartupPresentationRoute
    {
        RootPresentationFeature.State.startupRoute(
            gatewayConnected: gatewayConnected,
            hasConnectedOnce: hasConnectedOnce,
            onboardingComplete: onboardingComplete,
            hasExistingGatewayConfig: hasExistingGatewayConfig,
            shouldPresentOnLaunch: shouldPresentOnLaunch)
    }

    static func shouldPresentQuickSetup(
        quickSetupDismissed: Bool,
        showOnboarding: Bool,
        hasPresentedSheet: Bool,
        gatewayConnected: Bool,
        hasExistingGatewayConfig: Bool,
        discoveredGatewayCount: Int) -> Bool
    {
        RootPresentationFeature.State.shouldPresentQuickSetup(
            quickSetupDismissed: quickSetupDismissed,
            showOnboarding: showOnboarding,
            hasPresentedSheet: hasPresentedSheet,
            gatewayConnected: gatewayConnected,
            hasExistingGatewayConfig: hasExistingGatewayConfig,
            discoveredGatewayCount: discoveredGatewayCount)
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
