import ComposableArchitecture
import OpenClawKit
import OpenClawProtocol
import SwiftUI
import UIKit

struct RootTabs: View {
    @Environment(NodeAppModel.self) private var appModel
    @Environment(VoiceWakeManager.self) private var voiceWake
    @Environment(GatewayConnectionController.self) private var gatewayController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.rootTabsUserInterfaceIdiomOverride) private var userInterfaceIdiomOverride
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("screen.preventSleep") private var preventSleep: Bool = true
    @AppStorage("onboarding.requestID") private var onboardingRequestID: Int = 0
    @AppStorage("gateway.onboardingComplete") private var onboardingComplete: Bool = false
    @AppStorage("gateway.hasConnectedOnce") private var hasConnectedOnce: Bool = false
    @AppStorage("gateway.preferredStableID") private var preferredGatewayStableID: String = ""
    @AppStorage("gateway.manual.enabled") private var manualGatewayEnabled: Bool = false
    @AppStorage("gateway.manual.host") private var manualGatewayHost: String = ""
    @AppStorage("onboarding.quickSetupDismissed") private var quickSetupDismissed: Bool = false
    @AppStorage("canvas.debugStatusEnabled") private var canvasDebugStatusEnabled: Bool = false
    @AppStorage(AppAppearancePreference.storageKey) private var appearancePreferenceRaw: String =
        AppAppearancePreference.system.rawValue
    @State private var navigationStore: StoreOf<RootNavigationSelectionFeature> = Store(
        initialState: RootNavigationSelectionFeature.State(
            selectedTab: Self.initialTab,
            selectedSidebarDestination: Self.initialSidebarDestination))
    {
        RootNavigationSelectionFeature()
    }

    @State private var sidebarStore: StoreOf<RootSidebarFeature> = Store(
        initialState: RootSidebarFeature.State(initialVisibility: Self.initialSidebarVisibility))
    {
        RootSidebarFeature()
    }

    @State private var launchStore: StoreOf<RootLaunchFeature> = Store(
        initialState: RootLaunchFeature.State())
    {
        RootLaunchFeature()
    }

    @State private var voiceWakeToastStore: StoreOf<RootVoiceWakeToastFeature> = Store(
        initialState: RootVoiceWakeToastFeature.State())
    {
        RootVoiceWakeToastFeature()
    }

    @State private var presentationStore: StoreOf<RootPresentationFeature> = Store(
        initialState: RootPresentationFeature.State())
    {
        RootPresentationFeature()
    }

    @State private var homeCanvasStore: StoreOf<RootHomeCanvasFeature> = Store(
        initialState: RootHomeCanvasFeature.State())
    {
        RootHomeCanvasFeature()
    }

    private static var initialTab: AppTab {
        Self.initialTab(arguments: ProcessInfo.processInfo.arguments)
    }

    static func initialTab(arguments: [String]) -> AppTab {
        guard let flagIndex = arguments.firstIndex(of: "--openclaw-initial-tab") else {
            return self.fallbackInitialTab(arguments: arguments)
        }
        let valueIndex = arguments.index(after: flagIndex)
        guard arguments.indices.contains(valueIndex) else {
            return Self.fallbackInitialTab(arguments: arguments)
        }

        switch arguments[valueIndex].lowercased() {
        case "control", "overview":
            return .control
        case "chat":
            return .chat
        case "talk", "voice":
            return .talk
        case "agent", "agents":
            return .agent
        case "settings":
            return .settings
        default:
            return Self.fallbackInitialTab(arguments: arguments)
        }
    }

    private static func fallbackInitialTab(arguments: [String]) -> AppTab {
        self.requestedInitialSidebarDestination(arguments: arguments)?.appTab ?? .chat
    }

    private static var initialSidebarDestination: SidebarDestination {
        if let requested = requestedInitialSidebarDestination {
            return requested
        }
        return Self.defaultSidebarDestination(for: initialTab)
    }

    private static var requestedInitialSidebarDestination: SidebarDestination? {
        Self.requestedInitialSidebarDestination(arguments: ProcessInfo.processInfo.arguments)
    }

    static func requestedInitialSidebarDestination(arguments: [String]) -> SidebarDestination? {
        guard let flagIndex = arguments.firstIndex(of: "--openclaw-initial-destination") else {
            return nil
        }
        let valueIndex = arguments.index(after: flagIndex)
        guard arguments.indices.contains(valueIndex) else { return nil }
        let requested = arguments[valueIndex].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return SidebarDestination.allCases.first { $0.rawValue.lowercased() == requested }
    }

    private static var initialSidebarVisibility: Bool? {
        requestedInitialSidebarVisibility(arguments: ProcessInfo.processInfo.arguments)
    }

    private static var initialChatSessionKey: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "--openclaw-chat-session") else {
            return nil
        }
        let valueIndex = arguments.index(after: flagIndex)
        guard arguments.indices.contains(valueIndex) else { return nil }
        let trimmed = arguments[valueIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func shouldUseSidebarTabs(
        idiom: UIUserInterfaceIdiom,
        horizontalSizeClass _: UserInterfaceSizeClass?) -> Bool
    {
        idiom == .pad
    }

    var body: some View {
        self.rootPresentation(
            self.rootLifecycle(
                self.rootOverlays(
                    self.tabContent
                        .tint(OpenClawBrand.accent))))
    }

    @ViewBuilder
    private var tabContent: some View {
        if self.usesSidebarTabs {
            self.sidebarSplitContent
        } else {
            self.phoneTabContent
        }
    }

    private var phoneTabContent: some View {
        TabView(selection: self.selectedTabBinding) {
            ChatProTab(openSettings: { self.selectSidebarDestination(.gateway) })
                .tabItem { Label("Chat", systemImage: "bubble.left.fill") }
                .tag(AppTab.chat)

            TalkProTab(
                openSettings: { self.selectSidebarDestination(.gateway) },
                openVoiceSettings: { self.selectSettingsRoute(.voice) })
                .tabItem {
                    Label(
                        "Talk",
                        systemImage: self.appModel.talkMode.isEnabled ? "waveform.circle.fill" : "waveform.circle")
                }
                .tag(AppTab.talk)

            RootTabsPhoneControlHub(
                groups: Self.phoneControlGroups,
                initialDestination: Self.requestedInitialSidebarDestination,
                openRootDestination: { self.selectSidebarDestination($0) })
                .tabItem { Label("Control", systemImage: "square.grid.2x2") }
                .badge(self.appModel.pendingExecApprovalPrompt == nil ? 0 : 1)
                .tag(AppTab.control)

            NavigationStack {
                AgentProTab(
                    directRoute: .agents,
                    openSettings: { self.selectSidebarDestination(.gateway) })
            }
            .tabItem { Label("Agent", systemImage: "person.2.fill") }
            .tag(AppTab.agent)

            SettingsProTab(
                initialRoute: self.selectedSettingsRoute,
                execApprovalPromptStore: self.makeExecApprovalPromptStore(),
                manualGatewayEndpointStore: self.makeSettingsManualGatewayEndpointStore(),
                gatewayActivityStore: self.makeSettingsGatewayActivityStore(),
                gatewayConnectionStore: self.makeSettingsGatewayConnectionStore(),
                gatewayCredentialsStore: self.makeSettingsGatewayCredentialsStore(),
                gatewaySetupLinkStore: self.makeSettingsGatewaySetupLinkStore(),
                onboardingStateStore: self.makeSettingsOnboardingStateStore(),
                onRouteChange: self.handleSettingsRouteChange)
                .id(self.settingsTabViewID)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .openClawTabBarBehavior()
    }

    private var sidebarSplitContent: some View {
        GeometryReader { proxy in
            let isDrawerLayout = self.shouldUseSidebarDrawer(containerSize: proxy.size)
            let sidebarWidth = self.sidebarWidth(containerWidth: proxy.size.width, isDrawerLayout: isDrawerLayout)
            Group {
                if isDrawerLayout {
                    self.sidebarDrawerContent(sidebarWidth: sidebarWidth)
                } else {
                    self.sidebarNavigationSplitContent(sidebarWidth: sidebarWidth)
                }
            }
            .animation(.easeInOut(duration: 0.22), value: self.isSidebarVisible)
            .onAppear {
                self.updateSidebarLayout(containerSize: proxy.size, force: false)
            }
            .onChange(of: proxy.size) { _, size in
                self.updateSidebarLayout(containerSize: size, force: false)
            }
        }
    }

    private func sidebarNavigationSplitContent(sidebarWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            if self.isSidebarVisible {
                self.sidebarColumn
                    .frame(width: sidebarWidth, alignment: .topLeading)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                    .overlay(alignment: .trailing) {
                        self.sidebarVerticalSeparator
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            self.sidebarDetailNavigationShell
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(OpenClawProBackground())
    }

    private func sidebarDrawerContent(sidebarWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            self.sidebarDetailNavigationShell
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if self.isSidebarVisible {
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: sidebarWidth)
                        .allowsHitTesting(false)
                    Color.black.opacity(0.28)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            self.hideSidebar()
                        }
                }
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(0)

                self.sidebarColumn
                    .frame(width: sidebarWidth, alignment: .topLeading)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                    .overlay(alignment: .trailing) {
                        self.sidebarVerticalSeparator
                    }
                    .shadow(color: .black.opacity(0.26), radius: 18, x: 8, y: 0)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .zIndex(1)
            }
        }
    }

    private var sidebarDetailShell: some View {
        self.sidebarDetail
            .id(self.sidebarDetailShellID)
    }

    private var sidebarColumn: some View {
        VStack(spacing: 0) {
            self.sidebarIdentityHeader
            self.sidebarList
        }
        .safeAreaPadding(.top, 8)
        .safeAreaPadding(.bottom, 8)
        .background(Color(uiColor: .systemBackground))
    }

    private var sidebarIdentityHeader: some View {
        HStack(spacing: 10) {
            OpenClawProMark(size: 30, shadowRadius: 3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("OpenClaw")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(self.sidebarGatewayStatusColor)
                    Text(self.sidebarGatewayStatusTitle)
                        .lineLimit(1)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if self.isSidebarDrawerLayout {
                self.sidebarHideButton
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .bottom) {
            self.sidebarHorizontalSeparator
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("OpenClaw \(self.sidebarGatewayStatusTitle)")
    }

    private var sidebarGatewayStatusTitle: String {
        self.presentationStore.sidebarGatewayStatusTitle
    }

    private var sidebarList: some View {
        List {
            ForEach(Self.sidebarGroups) { group in
                Section(group.title.capitalized) {
                    ForEach(group.destinations) { destination in
                        self.sidebarDestinationButton(destination)
                    }
                }
                .listSectionSeparator(.hidden, edges: .all)
            }
        }
        .listStyle(.sidebar)
        .tint(OpenClawBrand.accent)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemBackground))
    }

    private var sidebarHorizontalSeparator: some View {
        Rectangle()
            .fill(Color(uiColor: .separator))
            .frame(height: 1 / UIScreen.main.scale)
    }

    private var sidebarVerticalSeparator: some View {
        Rectangle()
            .fill(Color(uiColor: .separator))
            .frame(width: 1 / UIScreen.main.scale)
    }

    private var sidebarGatewayStatusColor: Color {
        self.presentationStore.sidebarGatewayStatusColor
    }

    private func sidebarDestinationButton(
        _ destination: SidebarDestination,
        title: String? = nil) -> some View
    {
        Button {
            self.selectSidebarDestination(destination)
        } label: {
            Label(title ?? destination.sidebarTitle, systemImage: destination.systemImage)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .truncationMode(.tail)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(destination == self.selectedSidebarDestination ? OpenClawBrand.accent : .primary)
        .listRowBackground(
            destination == self.selectedSidebarDestination
                ? OpenClawBrand.accent.opacity(0.12)
                : Color.clear)
        .listRowSeparator(.hidden, edges: .all)
    }

    @ViewBuilder
    private var sidebarDetail: some View {
        switch self.selectedSidebarDestination {
        case .chat:
            ChatProTab(
                headerLeadingAction: self.sidebarHeaderLeadingAction,
                headerTitle: "Chat",
                showsAgentBadge: false,
                ownsNavigationStack: false,
                openSettings: { self.selectSidebarDestination(.gateway) })
        case .talk:
            TalkProTab(
                headerLeadingAction: self.sidebarHeaderLeadingAction,
                ownsNavigationStack: false,
                openSettings: { self.selectSidebarDestination(.gateway) },
                openVoiceSettings: { self.selectSettingsRoute(.voice) })
        case .overview:
            self.sidebarOverview
        case .activity:
            IPadActivityScreen(
                headerLeadingAction: self.sidebarHeaderLeadingAction,
                openChat: { self.selectSidebarDestination(.chat) },
                openSettings: { self.selectSidebarDestination(.gateway) },
                store: IPadActivitySessionsStoreFactory.live(appModel: self.appModel))
        case .workboard:
            IPadWorkboardScreen(
                headerLeadingAction: self.sidebarHeaderLeadingAction,
                openChat: { self.selectSidebarDestination(.chat) },
                openSettings: { self.selectSidebarDestination(.gateway) },
                store: IPadWorkboardStoreFactory.live(appModel: self.appModel))
        case .skillWorkshop:
            IPadSkillWorkshopScreen(
                headerLeadingAction: self.sidebarHeaderLeadingAction,
                openSettings: { self.selectSidebarDestination(.gateway) },
                store: IPadSkillWorkshopStoreFactory.live(appModel: self.appModel))
        case .agents:
            AgentProTab(
                directRoute: .agents,
                headerLeadingAction: self.sidebarHeaderLeadingAction,
                headerTitle: "Agents",
                openSettings: { self.selectSidebarDestination(.gateway) })
                .id(self.selectedSidebarDestination.id)
        case .instances:
            AgentProTab(
                directRoute: .instances,
                headerLeadingAction: self.sidebarHeaderLeadingAction,
                headerTitle: "Instances",
                openSettings: { self.selectSidebarDestination(.gateway) })
                .id(self.selectedSidebarDestination.id)
        case .sessions:
            CommandSessionsScreen(
                headerLeadingAction: self.sidebarHeaderLeadingAction,
                openChat: { self.selectSidebarDestination(.chat) },
                store: CommandSessionsStoreFactory.live(appModel: self.appModel))
        case .dreaming:
            AgentProTab(
                directRoute: .dreaming,
                headerLeadingAction: self.sidebarHeaderLeadingAction,
                headerTitle: "Dreaming",
                openSettings: { self.selectSidebarDestination(.gateway) })
                .id(self.selectedSidebarDestination.id)
        case .usage:
            AgentProTab(
                directRoute: .usage,
                headerLeadingAction: self.sidebarHeaderLeadingAction,
                headerTitle: "Usage",
                openSettings: { self.selectSidebarDestination(.gateway) })
                .id(self.selectedSidebarDestination.id)
        case .cron:
            AgentProTab(
                directRoute: .cron,
                headerLeadingAction: self.sidebarHeaderLeadingAction,
                headerTitle: "Cron Jobs",
                openSettings: { self.selectSidebarDestination(.gateway) })
                .id(self.selectedSidebarDestination.id)
        case .docs:
            OpenClawDocsScreen(
                headerLeadingAction: self.sidebarHeaderLeadingAction,
                gatewayAction: { self.selectSidebarDestination(.gateway) })
        case .settings:
            if let selectedSettingsRoute {
                SettingsProTab(
                    directRoute: selectedSettingsRoute,
                    headerLeadingAction: self.sidebarHeaderLeadingAction,
                    ownsNavigationStack: false,
                    navigateToRoute: self.pushSidebarSettingsRoute,
                    execApprovalPromptStore: self.makeExecApprovalPromptStore(),
                    manualGatewayEndpointStore: self.makeSettingsManualGatewayEndpointStore(),
                    gatewayActivityStore: self.makeSettingsGatewayActivityStore(),
                    gatewayConnectionStore: self.makeSettingsGatewayConnectionStore(),
                    gatewayCredentialsStore: self.makeSettingsGatewayCredentialsStore(),
                    gatewaySetupLinkStore: self.makeSettingsGatewaySetupLinkStore(),
                    onboardingStateStore: self.makeSettingsOnboardingStateStore(),
                    onRouteChange: self.handleSettingsRouteChange)
            } else {
                SettingsProTab(
                    headerLeadingAction: self.sidebarHeaderLeadingAction,
                    ownsNavigationStack: false,
                    navigateToRoute: self.pushSidebarSettingsRoute,
                    execApprovalPromptStore: self.makeExecApprovalPromptStore(),
                    manualGatewayEndpointStore: self.makeSettingsManualGatewayEndpointStore(),
                    gatewayActivityStore: self.makeSettingsGatewayActivityStore(),
                    gatewayConnectionStore: self.makeSettingsGatewayConnectionStore(),
                    gatewayCredentialsStore: self.makeSettingsGatewayCredentialsStore(),
                    gatewaySetupLinkStore: self.makeSettingsGatewaySetupLinkStore(),
                    onboardingStateStore: self.makeSettingsOnboardingStateStore(),
                    onRouteChange: self.handleSettingsRouteChange)
            }
        case .gateway:
            SettingsProTab(
                directRoute: self.selectedSettingsRoute ?? self.selectedSidebarDestination.settingsRoute ?? .gateway,
                headerLeadingAction: self.sidebarHeaderLeadingAction,
                ownsNavigationStack: false,
                navigateToRoute: self.pushSidebarSettingsRoute,
                execApprovalPromptStore: self.makeExecApprovalPromptStore(),
                manualGatewayEndpointStore: self.makeSettingsManualGatewayEndpointStore(),
                gatewayActivityStore: self.makeSettingsGatewayActivityStore(),
                gatewayConnectionStore: self.makeSettingsGatewayConnectionStore(),
                gatewayCredentialsStore: self.makeSettingsGatewayCredentialsStore(),
                gatewaySetupLinkStore: self.makeSettingsGatewaySetupLinkStore(),
                onboardingStateStore: self.makeSettingsOnboardingStateStore(),
                onRouteChange: self.handleSettingsRouteChange)
        }
    }

    private var sidebarDetailNavigationShell: some View {
        NavigationStack(path: self.sidebarNavigationPathBinding) {
            self.sidebarDetailShell
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }

    private var usesSidebarTabs: Bool {
        Self.shouldUseSidebarTabs(
            idiom: self.userInterfaceIdiom,
            horizontalSizeClass: self.horizontalSizeClass)
    }

    private var userInterfaceIdiom: UIUserInterfaceIdiom {
        if let userInterfaceIdiomOverride {
            return userInterfaceIdiomOverride
        }
        return UIDevice.current.userInterfaceIdiom
    }

    private var sidebarDetailShellID: String {
        let routeID = self.selectedSettingsRoute.map { "\($0)" } ?? "root"
        return "\(self.selectedSidebarDestination.id):\(routeID):\(self.selectedSettingsRouteRequestID)"
    }

    private var settingsTabViewID: String {
        let routeID = self.selectedSettingsRoute.map { "\($0)" } ?? "settings"
        return "\(routeID):\(self.selectedSettingsRouteRequestID)"
    }

    private var activeExecApprovalPromptSuppressionID: String? {
        self.navigationStore.activeExecApprovalPromptSuppressionID
    }

    private var shouldCollapseSidebarAfterSelection: Bool {
        Self.shouldCollapseSidebarAfterSelection(
            layoutMode: self.isSidebarDrawerLayout ? .drawer : .split)
    }

    private var sidebarHeaderLeadingAction: OpenClawSidebarHeaderAction? {
        guard Self.shouldShowSidebarRevealInDestinationHeader(
            isSidebarVisible: self.isSidebarVisible,
            layoutMode: self.isSidebarDrawerLayout ? .drawer : .split)
        else {
            return nil
        }
        if self.isSidebarVisible {
            return OpenClawSidebarHeaderAction(
                systemName: "sidebar.left",
                accessibilityLabel: "Hide Sidebar",
                accessibilityIdentifier: Self.sidebarHideButtonAccessibilityIdentifier,
                action: { self.hideSidebar() })
        }
        return OpenClawSidebarHeaderAction(
            systemName: "sidebar.left",
            accessibilityLabel: "Show Sidebar",
            accessibilityIdentifier: Self.sidebarShowButtonAccessibilityIdentifier,
            action: { self.showSidebar() })
    }

    private var sidebarHideButton: some View {
        Button {
            self.hideSidebar()
        } label: {
            Image(systemName: self.isSidebarDrawerLayout ? "xmark" : "sidebar.left")
                .font(.system(size: 15, weight: .semibold))
        }
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
        .foregroundStyle(OpenClawBrand.accent)
        .accessibilityLabel("Hide Sidebar")
        .accessibilityIdentifier(Self.sidebarHideButtonAccessibilityIdentifier)
    }

    private func shouldUseSidebarDrawer(containerSize: CGSize) -> Bool {
        Self.sidebarLayoutMode(containerSize: containerSize) == .drawer
    }

    private func sidebarWidth(containerWidth: CGFloat, isDrawerLayout: Bool) -> CGFloat {
        Self.sidebarWidth(containerWidth: containerWidth, isDrawerLayout: isDrawerLayout)
    }

    private func rootOverlays(_ content: some View) -> some View {
        content
            .overlay(alignment: .top) {
                if let gatewayProblem = self.appModel.lastGatewayProblem,
                   self.gatewayStatus != .connected
                {
                    GatewayProblemBanner(
                        problem: gatewayProblem,
                        primaryActionTitle: self.gatewayProblemPrimaryActionTitle(gatewayProblem),
                        onPrimaryAction: {
                            self.handleGatewayProblemPrimaryAction(gatewayProblem)
                        },
                        onShowDetails: {
                            self.presentationStore.send(.gatewayProblemDetailsButtonTapped)
                        })
                        .padding(.horizontal, 12)
                        .safeAreaPadding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .overlay(alignment: .topLeading) {
                if let voiceWakeToastText = self.voiceWakeToastStore.commandText,
                   !voiceWakeToastText.isEmpty
                {
                    VoiceWakeToast(command: voiceWakeToastText)
                        .padding(.leading, 10)
                        .safeAreaPadding(.top, self.appModel.lastGatewayProblem == nil ? 58 : 132)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(
                self.voiceWakeToastAnimation,
                value: self.voiceWakeToastStore.commandText)
            .overlay {
                if self.appModel.cameraFlashNonce != 0 {
                    RootCameraFlashOverlay(nonce: self.appModel.cameraFlashNonce)
                }
            }
            .overlay {
                if self.appModel.screen.isCanvasPresented {
                    self.canvasPresentationOverlay
                        .transition(.opacity)
                        .zIndex(20)
                }
            }
    }

    private var canvasPresentationOverlay: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            ScreenWebView(controller: self.appModel.screen)
                .ignoresSafeArea()
            Button {
                self.appModel.screen.hideCanvas()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.32), radius: 8, y: 2)
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close canvas")
            .safeAreaPadding(.top, 8)
            .padding(.trailing, 12)
        }
    }

    private var voiceWakeToastAnimation: Animation? {
        guard !self.reduceMotion else { return nil }
        return self.voiceWakeToastStore.commandText == nil
            ? .easeOut(duration: 0.25)
            : .spring(response: 0.25, dampingFraction: 0.85)
    }

    private func rootLifecycle(_ content: some View) -> some View {
        self.rootRequestLifecycle(
            self.rootGatewayLifecycle(
                self.rootAppearLifecycle(
                    self.rootVoiceWakeLifecycle(content))))
    }

    private func rootVoiceWakeLifecycle(_ content: some View) -> some View {
        content
            .onChange(of: self.voiceWake.lastTriggeredCommand) { _, newValue in
                guard let newValue else { return }
                self.voiceWakeToastStore.send(.commandTriggered(newValue))
            }
    }

    private func rootAppearLifecycle(_ content: some View) -> some View {
        content
            .onAppear { self.updateIdleTimer() }
            .onAppear { self.updateCanvasState() }
            .onAppear { self.evaluateOnboardingPresentation(force: false) }
            .onAppear { self.maybeAutoOpenSettings() }
            .onAppear { self.maybeOpenSettingsForGatewaySetup() }
            .onAppear { self.maybeShowQuickSetup() }
            .onAppear { self.applyInitialAppearanceIfNeeded() }
            .onAppear { self.applyInitialChatSessionIfNeeded() }
            .onChange(of: self.preventSleep) { _, _ in self.updateIdleTimer() }
            .onChange(of: self.appModel.talkMode.isEnabled) { _, _ in self.updateIdleTimer() }
            .onChange(of: self.scenePhase) { _, newValue in
                self.updateIdleTimer()
                self.updateHomeCanvasState()
                guard newValue == .active else { return }
                self.maybeRequestLocalNetworkAccess(reason: "scene_active")
                Task {
                    await self.appModel.refreshGatewayOverviewIfConnected()
                    await MainActor.run {
                        self.updateHomeCanvasState()
                    }
                }
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
                self.voiceWakeToastStore.send(.disappeared)
            }
    }

    private func rootGatewayLifecycle(_ content: some View) -> some View {
        content
            .onAppear { self.syncSidebarGatewayStatus() }
            .onChange(of: self.gatewayStatus) { _, _ in self.syncSidebarGatewayStatus() }
            .onChange(of: self.canvasDebugStatusEnabled) { _, _ in self.updateCanvasDebugStatus() }
            .onChange(of: self.gatewayController.gateways.count) { _, _ in self.maybeShowQuickSetup() }
            .onChange(of: self.appModel.gatewayServerName) { _, newValue in
                if newValue != nil {
                    self.onboardingComplete = true
                    self.hasConnectedOnce = true
                    OnboardingStateStore.markCompleted(mode: nil)
                }
                self.maybeAutoOpenSettings()
                self.maybeShowQuickSetup()
                self.updateCanvasState()
            }
            .onChange(of: self.appModel.gatewayStatusText) { _, _ in self.updateCanvasState() }
            .onChange(of: self.appModel.gatewayRemoteAddress) { _, _ in self.updateCanvasState() }
            .onChange(of: self.appModel.gatewayDisplayStatusText) { _, _ in self.updateCanvasState() }
            .onChange(of: self.appModel.homeCanvasRevision) { _, _ in self.updateHomeCanvasState() }
            .onChange(of: self.appModel.gatewayAgents.count) { _, _ in self.updateHomeCanvasState() }
            .onChange(of: self.appModel.selectedAgentId) { _, _ in self.updateHomeCanvasState() }
            .onChange(of: self.appModel.gatewayDefaultAgentId) { _, _ in self.updateHomeCanvasState() }
            .onChange(of: self.appModel.activeAgentName) { _, _ in self.updateHomeCanvasState() }
            .onChange(of: self.appModel.connectedGatewayID) { _, _ in
                self.updateCanvasState()
            }
    }

    private func rootRequestLifecycle(_ content: some View) -> some View {
        content
            .onChange(of: self.onboardingRequestID) { _, _ in
                self.evaluateOnboardingPresentation(force: true)
            }
            .onChange(of: self.appModel.openChatRequestID) { _, _ in
                self.selectSidebarDestination(.chat)
            }
            .onChange(of: self.appModel.gatewaySetupRequestID) { _, _ in
                self.maybeOpenSettingsForGatewaySetup()
            }
            .onChange(of: self.appModel.pendingExecApprovalPrompt?.id) { _, newValue in
                self.navigationStore.send(.pendingExecApprovalPromptChanged(newValue))
            }
    }

    private func rootPresentation(_ content: some View) -> some View {
        content
            .sheet(isPresented: self.gatewayProblemDetailsBinding) {
                if let gatewayProblem = self.appModel.lastGatewayProblem {
                    GatewayProblemDetailsSheet(
                        problem: gatewayProblem,
                        primaryActionTitle: self.gatewayProblemPrimaryActionTitle(gatewayProblem),
                        onPrimaryAction: {
                            self.handleGatewayProblemPrimaryAction(gatewayProblem)
                        })
                }
            }
            .sheet(item: self.presentedSheetBinding) { sheet in
                switch sheet {
                case .quickSetup:
                    GatewayQuickSetupSheet(store: self.makeGatewayQuickSetupStore())
                        .environment(self.appModel)
                        .environment(self.gatewayController)
                        .openClawSheetChrome()
                        .preferredColorScheme(self.appearancePreference.colorScheme)
                }
            }
            .fullScreenCover(isPresented: self.onboardingPresentedBinding) {
                OnboardingWizardView(
                    allowSkip: self.presentationStore.onboardingAllowSkip,
                    onRequestLocalNetworkAccess: { reason in
                        self.requestLocalNetworkAccess(reason: reason)
                    },
                    onClose: {
                        self.setOnboardingPresented(false)
                    })
                    .environment(self.appModel)
                    .environment(self.voiceWake)
                    .environment(self.gatewayController)
                    .preferredColorScheme(self.appearancePreference.colorScheme)
            }
            .gatewayTrustPromptAlert(store: self.makeGatewayTrustPromptStore())
            .deepLinkAgentPromptAlert(store: self.makeDeepLinkAgentPromptStore())
            .execApprovalPromptDialog(
                suppressedApprovalID: self.activeExecApprovalPromptSuppressionID,
                store: self.makeExecApprovalPromptStore())
            .notificationPermissionGuidanceDialog(store: self.makeNotificationPermissionGuidanceStore())
    }

    @MainActor
    private func makeGatewayQuickSetupStore() -> StoreOf<GatewayQuickSetupFeature> {
        Store(initialState: GatewayQuickSetupFeature.State()) {
            GatewayQuickSetupFeature()
        } withDependencies: {
            $0.gatewayQuickSetup = .live(gatewayController: self.gatewayController)
        }
    }

    @MainActor
    private func makeGatewayTrustPromptStore() -> StoreOf<GatewayTrustPromptFeature> {
        Store(initialState: GatewayTrustPromptFeature.State()) {
            GatewayTrustPromptFeature(client: .live(gatewayController: self.gatewayController))
        }
    }

    @MainActor
    private func makeSettingsManualGatewayEndpointStore() -> StoreOf<SettingsManualGatewayEndpointFeature> {
        Store(initialState: SettingsManualGatewayEndpointFeature.State()) {
            SettingsManualGatewayEndpointFeature(
                localNetworkAccessClient: .live(gatewayController: self.gatewayController))
        }
    }

    @MainActor
    private func makeSettingsGatewayActivityStore() -> StoreOf<SettingsGatewayActivityFeature> {
        Store(initialState: SettingsGatewayActivityFeature.State()) {
            SettingsGatewayActivityFeature(
                diagnosticsRefreshClient: .live(
                    appModel: self.appModel,
                    gatewayController: self.gatewayController),
                reconnectClient: .live(gatewayController: self.gatewayController))
        }
    }

    @MainActor
    private func makeSettingsGatewayConnectionStore() -> StoreOf<SettingsGatewayConnectionFeature> {
        Store(initialState: SettingsGatewayConnectionFeature.State()) {
            SettingsGatewayConnectionFeature(disconnectClient: .live(appModel: self.appModel))
        }
    }

    @MainActor
    private func makeSettingsGatewayCredentialsStore() -> StoreOf<SettingsGatewayCredentialsFeature> {
        Store(initialState: SettingsGatewayCredentialsFeature.State()) {
            SettingsGatewayCredentialsFeature(
                setupAuthPersistenceClient: .live(appModel: self.appModel))
        }
    }

    @MainActor
    private func makeSettingsOnboardingStateStore() -> StoreOf<SettingsOnboardingStateFeature> {
        Store(initialState: SettingsOnboardingStateFeature.State()) {
            SettingsOnboardingStateFeature(resetClient: .live(appModel: self.appModel))
        }
    }

    @MainActor
    private func makeSettingsGatewaySetupLinkStore() -> StoreOf<SettingsGatewaySetupLinkFeature> {
        Store(initialState: SettingsGatewaySetupLinkFeature.State()) {
            SettingsGatewaySetupLinkFeature(appleReviewDemoClient: .live(appModel: self.appModel))
        }
    }

    @MainActor
    private func makeDeepLinkAgentPromptStore() -> StoreOf<DeepLinkAgentPromptFeature> {
        Store(initialState: DeepLinkAgentPromptFeature.State()) {
            DeepLinkAgentPromptFeature(client: .live(appModel: self.appModel))
        }
    }

    @MainActor
    private func makeExecApprovalPromptStore() -> StoreOf<ExecApprovalPromptFeature> {
        Store(initialState: ExecApprovalPromptFeature.State()) {
            ExecApprovalPromptFeature(client: .live(appModel: self.appModel))
        }
    }

    @MainActor
    private func makeNotificationPermissionGuidanceStore() -> StoreOf<NotificationPermissionGuidanceFeature> {
        Store(initialState: NotificationPermissionGuidanceFeature.State()) {
            NotificationPermissionGuidanceFeature(client: .live(
                appModel: self.appModel,
                openNotifications: { approvalId in
                    self.openNotificationSettings(suppressedApprovalID: approvalId)
                }))
        }
    }

    private var appearancePreference: AppAppearancePreference {
        AppAppearancePreference.launchArgumentPreference
            ?? AppAppearancePreference(rawValue: self.appearancePreferenceRaw)
            ?? .system
    }

    private var gatewayStatus: GatewayDisplayState {
        GatewayStatusBuilder.build(appModel: self.appModel)
    }

    private func syncSidebarGatewayStatus() {
        let status = self.gatewayStatus
        guard self.presentationStore.sidebarGatewayStatus != status else { return }
        self.presentationStore.send(.sidebarGatewayStatusChanged(status))
    }

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled =
            self.scenePhase == .active && (self.preventSleep || self.appModel.talkMode.isEnabled)
    }

    private func updateCanvasState() {
        self.updateHomeCanvasState()
        self.updateCanvasDebugStatus()
    }

    private func updateCanvasDebugStatus() {
        self.appModel.screen.setDebugStatusEnabled(self.canvasDebugStatusEnabled)
        guard self.canvasDebugStatusEnabled else { return }
        let title = self.appModel.gatewayDisplayStatusText.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitle = self.appModel.gatewayServerName ?? self.appModel.gatewayRemoteAddress
        self.appModel.screen.updateDebugStatus(title: title, subtitle: subtitle)
    }

    private func updateHomeCanvasState() {
        self.homeCanvasStore.send(.snapshotChanged(self.makeHomeCanvasSnapshot()))
        guard let payload = self.homeCanvasStore.payload else {
            self.appModel.screen.updateHomeCanvasState(json: nil)
            return
        }
        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8)
        else {
            self.appModel.screen.updateHomeCanvasState(json: nil)
            return
        }
        self.appModel.screen.updateHomeCanvasState(json: json)
    }

    private func makeHomeCanvasSnapshot() -> RootHomeCanvasFeature.Snapshot {
        RootHomeCanvasFeature.Snapshot(
            gatewayStatus: self.gatewayStatus,
            gatewayServerName: self.appModel.gatewayServerName,
            gatewayRemoteAddress: self.appModel.gatewayRemoteAddress,
            selectedAgentID: self.appModel.selectedAgentId,
            gatewayDefaultAgentID: self.appModel.gatewayDefaultAgentId,
            activeAgentName: self.appModel.activeAgentName,
            agents: self.appModel.gatewayAgents.map(RootHomeCanvasFeature.AgentSnapshot.init(agent:)))
    }
}

extension RootTabs {
    private var selectedTab: AppTab {
        self.navigationStore.selectedTab
    }

    private var selectedTabBinding: Binding<AppTab> {
        Binding(
            get: { self.navigationStore.selectedTab },
            set: { self.navigationStore.send(.tabSelected($0)) })
    }

    private var selectedSidebarDestination: SidebarDestination {
        self.navigationStore.selectedSidebarDestination
    }

    private var selectedSettingsRoute: SettingsRoute? {
        self.navigationStore.selectedSettingsRoute
    }

    private var selectedSettingsRouteRequestID: Int {
        self.navigationStore.selectedSettingsRouteRequestID
    }

    private var sidebarNavigationPathBinding: Binding<[SettingsRoute]> {
        Binding(
            get: { self.navigationStore.sidebarNavigationPath },
            set: { self.navigationStore.send(.sidebarNavigationPathChanged($0)) })
    }

    private var isSidebarVisible: Bool {
        self.sidebarStore.isVisible
    }

    private var isSidebarDrawerLayout: Bool {
        self.sidebarStore.layoutMode == .drawer
    }

    private var sidebarOverview: some View {
        CommandCenterTab(
            ownsNavigationStack: false,
            headerTitle: "Overview",
            headerLeadingAction: self.sidebarHeaderLeadingAction,
            showsHeaderMark: false,
            openChat: { self.selectSidebarDestination(.chat) },
            openSettings: { self.selectSidebarDestination(.gateway) },
            openSessions: { self.selectSidebarDestination(.sessions) },
            recentSessionsStore: CommandCenterRecentSessionsStoreFactory.live(appModel: self.appModel))
    }

    private func selectSidebarDestination(_ destination: SidebarDestination) {
        self.navigationStore.send(.sidebarDestinationSelected(destination))
        self.collapseSidebarAfterSelectionIfNeeded()
    }

    private func selectSettingsRoute(_ route: SettingsRoute) {
        self.navigationStore.send(.settingsRouteSelected(route))
        self.collapseSidebarAfterSelectionIfNeeded()
    }

    private func openNotificationSettings(suppressedApprovalID: String) {
        self.navigationStore.send(.notificationPermissionSettingsOpened(suppressedApprovalID: suppressedApprovalID))
        self.collapseSidebarAfterSelectionIfNeeded()
    }

    private func collapseSidebarAfterSelectionIfNeeded() {
        guard self.usesSidebarTabs, self.shouldCollapseSidebarAfterSelection else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            self.setSidebarVisible(false)
        }
    }

    private func pushSidebarSettingsRoute(_ route: SettingsRoute) {
        self.navigationStore.send(.sidebarSettingsRoutePushed(route))
    }

    private func handleSettingsRouteChange(_ route: SettingsRoute?) {
        self.navigationStore.send(.settingsRouteChanged(route))
    }

    private func showSidebar() {
        withAnimation(.easeInOut(duration: 0.22)) {
            _ = self.sidebarStore.send(.showRequested)
        }
    }

    private func hideSidebar() {
        withAnimation(.easeInOut(duration: 0.22)) {
            _ = self.sidebarStore.send(.hideRequested)
        }
    }

    private func updateSidebarLayout(containerSize: CGSize, force: Bool) {
        let layoutMode = Self.sidebarLayoutMode(containerSize: containerSize)
        self.sidebarStore.send(.layoutModeResolved(layoutMode, force: force))
    }

    private func setSidebarVisible(_ isVisible: Bool) {
        self.sidebarStore.send(.visibilityChanged(isVisible))
    }

    private func gatewayProblemPrimaryActionTitle(_ problem: GatewayConnectionProblem) -> String? {
        GatewayProblemPrimaryAction.title(
            for: problem,
            retryTitle: "Retry",
            nonRetryableTitle: "Open Settings")
    }

    private func handleGatewayProblemPrimaryAction(_ problem: GatewayConnectionProblem) {
        if problem.canTrustRotatedCertificate {
            Task { await self.gatewayController.trustRotatedGatewayCertificate(from: problem) }
        } else if GatewayProblemPrimaryAction.openProtocolMismatchHelpIfNeeded(problem) {
            return
        } else if problem.retryable {
            Task { await self.gatewayController.connectLastKnown() }
        } else {
            self.selectSidebarDestination(.gateway)
        }
    }

    private func evaluateOnboardingPresentation(force: Bool) {
        if force {
            self.presentationStore.send(.forceOnboardingRequested)
            return
        }

        self.presentationStore.send(.startupPresentationEvaluationRequested(
            gatewayConnected: self.appModel.gatewayServerName != nil,
            hasConnectedOnce: self.hasConnectedOnce,
            onboardingComplete: self.onboardingComplete,
            hasExistingGatewayConfig: self.hasExistingGatewayConfig(),
            shouldPresentOnLaunch: OnboardingStateStore.shouldPresentOnLaunch(appModel: self.appModel)))
        self.handlePresentationCommand()
    }

    private func hasExistingGatewayConfig() -> Bool {
        if self.appModel.activeGatewayConnectConfig != nil { return true }
        if GatewaySettingsStore.loadLastGatewayConnection() != nil { return true }

        let preferredStableID = self.preferredGatewayStableID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !preferredStableID.isEmpty { return true }

        let manualHost = self.manualGatewayHost.trimmingCharacters(in: .whitespacesAndNewlines)
        return self.manualGatewayEnabled && !manualHost.isEmpty
    }

    private func maybeAutoOpenSettings() {
        self.presentationStore.send(.autoOpenSettingsRequested(
            gatewayConnected: self.appModel.gatewayServerName != nil,
            hasConnectedOnce: self.hasConnectedOnce,
            onboardingComplete: self.onboardingComplete,
            hasExistingGatewayConfig: self.hasExistingGatewayConfig()))
        self.handlePresentationCommand()
    }

    private func maybeOpenSettingsForGatewaySetup() {
        self.presentationStore.send(.gatewaySetupRequestChanged(self.appModel.gatewaySetupRequestID))
        self.handlePresentationCommand()
    }

    private func maybeRequestLocalNetworkAccess(reason: String) {
        self.presentationStore.send(.localNetworkAccessRequested(
            reason: reason,
            sceneActive: self.scenePhase == .active))
        self.handlePresentationCommand()
    }

    private func requestLocalNetworkAccess(reason: String) {
        guard !self.appModel.isAppleReviewDemoModeEnabled else { return }
        self.gatewayController.requestLocalNetworkAccess(reason: reason)
    }

    private func applyInitialChatSessionIfNeeded() {
        self.launchStore.send(.initialChatSessionRequested(Self.initialChatSessionKey))
        self.handleLaunchCommand()
    }

    private func applyInitialAppearanceIfNeeded() {
        self.launchStore.send(.initialAppearanceRequested(AppAppearancePreference.launchArgumentPreference?.rawValue))
        self.handleLaunchCommand()
    }

    private func maybeShowQuickSetup() {
        self.presentationStore.send(.quickSetupSnapshotChanged(
            quickSetupDismissed: self.quickSetupDismissed,
            showOnboarding: self.presentationStore.showOnboarding,
            gatewayConnected: self.appModel.gatewayServerName != nil,
            hasExistingGatewayConfig: self.hasExistingGatewayConfig(),
            discoveredGatewayCount: self.gatewayController.gateways.count))
    }
}

extension RootTabs {
    private func handleLaunchCommand() {
        guard let command = self.launchStore.command else { return }
        self.launchStore.send(.commandHandled)

        switch command {
        case let .applyAppearance(rawValue):
            self.appearancePreferenceRaw = rawValue

        case let .focusChatSession(sessionKey):
            self.appModel.focusChatSession(sessionKey)
        }
    }

    private var onboardingPresentedBinding: Binding<Bool> {
        Binding(
            get: { self.presentationStore.showOnboarding },
            set: { self.setOnboardingPresented($0) })
    }

    private func setOnboardingPresented(_ isPresented: Bool) {
        self.presentationStore.send(.onboardingVisibilityChanged(
            isPresented: isPresented,
            sceneActive: self.scenePhase == .active))
        self.handlePresentationCommand()
    }

    private func handlePresentationCommand() {
        guard let command = self.presentationStore.presentationCommand else { return }
        self.presentationStore.send(.presentationCommandHandled)

        switch command {
        case let .requestLocalNetworkAccess(reason):
            self.requestLocalNetworkAccess(reason: reason)

        case let .openGatewaySettingsAndRequestLocalNetworkAccess(reason):
            self.selectSidebarDestination(.gateway)
            self.requestLocalNetworkAccess(reason: reason)
        }
    }

    private var presentedSheetBinding: Binding<RootPresentationFeature.PresentedSheet?> {
        Binding(
            get: { self.presentationStore.presentedSheet },
            set: { self.presentationStore.send(.presentedSheetChanged($0)) })
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
}

@Reducer
struct RootHomeCanvasFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var payload: Payload?
    }

    struct Snapshot: Equatable, Sendable {
        var gatewayStatus: GatewayDisplayState
        var gatewayServerName: String?
        var gatewayRemoteAddress: String?
        var selectedAgentID: String?
        var gatewayDefaultAgentID: String?
        var activeAgentName: String
        var agents: [AgentSnapshot]
    }

    struct AgentSnapshot: Equatable, Sendable {
        var id: String
        var name: String?
        var emoji: String?
    }

    struct Payload: Codable, Equatable, Sendable {
        var gatewayState: String
        var eyebrow: String
        var title: String
        var subtitle: String
        var gatewayLabel: String
        var activeAgentName: String
        var activeAgentBadge: String
        var activeAgentCaption: String
        var agentCount: Int
        var agents: [AgentCard]
        var footer: String
    }

    struct AgentCard: Codable, Equatable, Sendable {
        var id: String
        var name: String
        var badge: String
        var caption: String
        var isActive: Bool
    }

    enum Action: Equatable, Sendable {
        case snapshotChanged(Snapshot)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .snapshotChanged(snapshot):
                state.payload = Self.payload(snapshot: snapshot)
                return .none
            }
        }
        .autoLogActions()
    }

    static func payload(snapshot: Snapshot) -> Payload {
        let gatewayName = self.normalized(snapshot.gatewayServerName)
        let gatewayAddress = self.normalized(snapshot.gatewayRemoteAddress)
        let gatewayLabel = gatewayName ?? gatewayAddress ?? "Gateway"
        let activeAgentID = self.activeAgentID(snapshot: snapshot)
        let agents = self.agentCards(snapshot: snapshot, activeAgentID: activeAgentID)

        switch snapshot.gatewayStatus {
        case .connected:
            return Payload(
                gatewayState: "connected",
                eyebrow: "\(gatewayLabel) online",
                title: "Command center",
                subtitle:
                "Use Chat for code work, Talk for realtime voice, and gateway tools for approved device actions.",
                gatewayLabel: gatewayLabel,
                activeAgentName: snapshot.activeAgentName,
                activeAgentBadge: agents.first(where: { $0.isActive })?.badge ?? "OC",
                activeAgentCaption: "Routes chat and talk",
                agentCount: agents.count,
                agents: Array(agents.prefix(6)),
                footer: "OpenClaw only runs phone-side capabilities while the app is connected and permitted.")

        case .connecting:
            return Payload(
                gatewayState: "connecting",
                eyebrow: "Gateway handshake",
                title: "Reconnecting",
                subtitle:
                "Restoring the local node session, agent list, voice config, and device capability state.",
                gatewayLabel: gatewayLabel,
                activeAgentName: snapshot.activeAgentName,
                activeAgentBadge: "OC",
                activeAgentCaption: "Session in progress",
                agentCount: agents.count,
                agents: Array(agents.prefix(4)),
                footer: "If the gateway is reachable, the local node should recover without re-pairing.")

        case .error, .disconnected:
            return Payload(
                gatewayState: snapshot.gatewayStatus == .error ? "error" : "offline",
                eyebrow: snapshot.gatewayStatus == .error ? "Gateway needs attention" : "OpenClaw iOS",
                title: "Pair a gateway",
                subtitle:
                "Connect this phone as a local node for chat, realtime voice, share intake, and approved device tools.",
                gatewayLabel: gatewayLabel,
                activeAgentName: "Main",
                activeAgentBadge: "OC",
                activeAgentCaption: "Connect to load your agents",
                agentCount: agents.count,
                agents: Array(agents.prefix(4)),
                footer:
                "Use Settings to scan a pairing QR code or paste a setup code from your OpenClaw gateway.")
        }
    }

    private static func activeAgentID(snapshot: Snapshot) -> String {
        let selected = self.normalized(snapshot.selectedAgentID) ?? ""
        if !selected.isEmpty {
            return selected
        }
        return self.defaultAgentID(snapshot: snapshot)
    }

    private static func defaultAgentID(snapshot: Snapshot) -> String {
        self.normalized(snapshot.gatewayDefaultAgentID) ?? ""
    }

    private static func agentCards(snapshot: Snapshot, activeAgentID: String) -> [AgentCard] {
        let defaultAgentID = self.defaultAgentID(snapshot: snapshot)
        let cards = snapshot.agents.map { agent -> AgentCard in
            let isActive = !activeAgentID.isEmpty && agent.id == activeAgentID
            let isDefault = !defaultAgentID.isEmpty && agent.id == defaultAgentID
            return AgentCard(
                id: agent.id,
                name: self.agentName(agent),
                badge: self.agentBadge(agent),
                caption: isActive ? "Routed on this phone" : (isDefault ? "Gateway default" : "Available"),
                isActive: isActive)
        }

        return cards.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive {
                return lhs.isActive
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private static func agentName(_ agent: AgentSnapshot) -> String {
        self.normalized(agent.name) ?? agent.id
    }

    private static func agentBadge(_ agent: AgentSnapshot) -> String {
        if let normalizedEmoji = normalized(agent.emoji) {
            return normalizedEmoji
        }
        let words = self.agentName(agent)
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" })
            .prefix(2)
        let initials = words.compactMap(\.first).map(String.init).joined()
        if !initials.isEmpty {
            return initials.uppercased()
        }
        return "OC"
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension RootHomeCanvasFeature.AgentSnapshot {
    init(agent: AgentSummary) {
        self.init(
            id: agent.id,
            name: agent.name,
            emoji: agent.identity?["emoji"]?.value as? String)
    }
}

@Reducer
struct RootLaunchFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var didApplyInitialAppearance = false
        var didApplyInitialChatSession = false
        var command: Command?
    }

    enum Command: Equatable, Sendable {
        case applyAppearance(rawValue: String)
        case focusChatSession(String?)
    }

    enum Action: Equatable, Sendable {
        case initialAppearanceRequested(String?)
        case initialChatSessionRequested(String?)
        case commandHandled
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .initialAppearanceRequested(rawValue):
                guard !state.didApplyInitialAppearance else { return .none }
                state.didApplyInitialAppearance = true
                guard let rawValue else { return .none }
                state.command = .applyAppearance(rawValue: rawValue)
                return .none

            case let .initialChatSessionRequested(sessionKey):
                guard !state.didApplyInitialChatSession else { return .none }
                state.didApplyInitialChatSession = true
                state.command = .focusChatSession(sessionKey)
                return .none

            case .commandHandled:
                state.command = nil
                return .none
            }
        }
        .autoLogActions()
    }
}

@Reducer
struct RootVoiceWakeToastFeature {
    private let sleepOverride: RootVoiceWakeToastSleepClient?

    private enum CancelID {
        case dismiss
    }

    init(sleeper: RootVoiceWakeToastSleepClient? = nil) {
        self.sleepOverride = sleeper
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var commandText: String?
    }

    enum Action: Equatable, Sendable {
        case commandTriggered(String)
        case dismissDelayElapsed
        case disappeared
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.rootVoiceWakeToastSleep) var dependencySleeper
            let sleeper = self.sleepOverride ?? dependencySleeper

            switch action {
            case let .commandTriggered(command):
                let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return .none }
                state.commandText = trimmed
                return .run { send in
                    try await sleeper.sleep()
                    await send(.dismissDelayElapsed)
                }
                .cancellable(id: CancelID.dismiss, cancelInFlight: true)

            case .dismissDelayElapsed:
                state.commandText = nil
                return .none

            case .disappeared:
                return .cancel(id: CancelID.dismiss)
            }
        }
        .autoLogActions()
    }
}

struct RootVoiceWakeToastSleepClient {
    var sleep: @Sendable () async throws -> Void
}

extension RootVoiceWakeToastSleepClient: DependencyKey {
    static let liveValue = RootVoiceWakeToastSleepClient(sleep: {
        try await Task.sleep(nanoseconds: 2_300_000_000)
    })

    static let testValue = RootVoiceWakeToastSleepClient(sleep: {})
}

extension DependencyValues {
    var rootVoiceWakeToastSleep: RootVoiceWakeToastSleepClient {
        get { self[RootVoiceWakeToastSleepClient.self] }
        set { self[RootVoiceWakeToastSleepClient.self] = newValue }
    }
}

private struct RootCameraFlashOverlay: View {
    var nonce: Int

    @State private var store: StoreOf<RootCameraFlashOverlayFeature>

    init(
        nonce: Int,
        store: StoreOf<RootCameraFlashOverlayFeature> = Store(
            initialState: RootCameraFlashOverlayFeature.State())
        {
            RootCameraFlashOverlayFeature()
        })
    {
        self.nonce = nonce
        self._store = SwiftUI.State(wrappedValue: store)
    }

    var body: some View {
        Color.white
            .opacity(self.store.opacity)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .animation(
                self.store.opacity > 0 ? .easeOut(duration: 0.08) : .easeOut(duration: 0.32),
                value: self.store.opacity)
            .onChange(of: self.nonce) { _, _ in
                self.store.send(.nonceChanged)
            }
            .onDisappear {
                self.store.send(.disappeared)
            }
    }
}

@Reducer
struct RootCameraFlashOverlayFeature {
    private let sleepOverride: RootCameraFlashOverlaySleepClient?

    private enum CancelID {
        case flash
    }

    init(sleeper: RootCameraFlashOverlaySleepClient? = nil) {
        self.sleepOverride = sleeper
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var opacity: Double = 0
    }

    enum Action: Equatable, Sendable {
        case nonceChanged
        case fadeOutDelayElapsed
        case disappeared
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.rootCameraFlashOverlaySleep) var dependencySleeper
            let sleeper = self.sleepOverride ?? dependencySleeper

            switch action {
            case .nonceChanged:
                state.opacity = 0.85
                return .run { send in
                    try await sleeper.sleep()
                    await send(.fadeOutDelayElapsed)
                }
                .cancellable(id: CancelID.flash, cancelInFlight: true)

            case .fadeOutDelayElapsed:
                state.opacity = 0
                return .none

            case .disappeared:
                return .cancel(id: CancelID.flash)
            }
        }
        .autoLogActions()
    }
}

struct RootCameraFlashOverlaySleepClient {
    var sleep: @Sendable () async throws -> Void
}

extension RootCameraFlashOverlaySleepClient: DependencyKey {
    static let liveValue = RootCameraFlashOverlaySleepClient(sleep: {
        try await Task.sleep(nanoseconds: 110_000_000)
    })

    static let testValue = RootCameraFlashOverlaySleepClient(sleep: {})
}

extension DependencyValues {
    var rootCameraFlashOverlaySleep: RootCameraFlashOverlaySleepClient {
        get { self[RootCameraFlashOverlaySleepClient.self] }
        set { self[RootCameraFlashOverlaySleepClient.self] = newValue }
    }
}

extension EnvironmentValues {
    @Entry var rootTabsUserInterfaceIdiomOverride: UIUserInterfaceIdiom?
}

#if DEBUG
#Preview(
    "Shell iPhone portrait",
    traits: .fixedLayout(width: 393, height: 852),
    .portrait)
{
    RootTabsPreviewHost(idiom: .phone)
}

#Preview(
    "Shell iPhone connected",
    traits: .fixedLayout(width: 393, height: 852),
    .portrait)
{
    RootTabsPreviewHost(idiom: .phone, gatewayState: .connected)
}

#Preview(
    "Shell iPhone gateway error",
    traits: .fixedLayout(width: 393, height: 852),
    .portrait)
{
    RootTabsPreviewHost(idiom: .phone, gatewayState: .error)
}

#Preview(
    "Shell iPhone landscape",
    traits: .fixedLayout(width: 852, height: 393),
    .landscapeLeft)
{
    RootTabsPreviewHost(idiom: .phone)
        .environment(\.horizontalSizeClass, .regular)
        .environment(\.verticalSizeClass, .compact)
}

#Preview(
    "Shell iPad portrait drawer",
    traits: .fixedLayout(width: 1024, height: 1366),
    .portrait)
{
    RootTabsPreviewHost(idiom: .pad)
}

#Preview(
    "Shell iPad landscape split",
    traits: .fixedLayout(width: 1366, height: 1024),
    .landscapeLeft)
{
    RootTabsPreviewHost(idiom: .pad, gatewayState: .connected)
}

#Preview(
    "Shell iPad connecting",
    traits: .fixedLayout(width: 1366, height: 1024),
    .landscapeLeft)
{
    RootTabsPreviewHost(idiom: .pad, gatewayState: .connecting)
}

#Preview(
    "Shell iPad gateway error",
    traits: .fixedLayout(width: 1366, height: 1024),
    .landscapeLeft)
{
    RootTabsPreviewHost(idiom: .pad, gatewayState: .error)
}

private struct RootTabsPreviewHost: View {
    @State private var appModel: NodeAppModel
    @State private var gatewayController: GatewayConnectionController
    private let idiom: UIUserInterfaceIdiom

    init(idiom: UIUserInterfaceIdiom, gatewayState: RootTabsPreviewGatewayState = .offline) {
        let appModel = NodeAppModel()
        gatewayState.apply(to: appModel)
        self.idiom = idiom
        _appModel = State(initialValue: appModel)
        _gatewayController = State(
            initialValue: GatewayConnectionController(appModel: appModel, startDiscovery: false))
    }

    var body: some View {
        RootTabs()
            .environment(self.appModel)
            .environment(self.appModel.voiceWake)
            .environment(self.gatewayController)
            .environment(\.rootTabsUserInterfaceIdiomOverride, self.idiom)
    }
}

private enum RootTabsPreviewGatewayState {
    case offline
    case connecting
    case connected
    case error

    @MainActor
    func apply(to appModel: NodeAppModel) {
        switch self {
        case .offline:
            break
        case .connecting:
            appModel.gatewayStatusText = "Connecting..."
        case .connected:
            appModel.enterAppleReviewDemoMode()
        case .error:
            appModel.gatewayStatusText = "Gateway error: connection refused"
        }
    }
}

#endif
