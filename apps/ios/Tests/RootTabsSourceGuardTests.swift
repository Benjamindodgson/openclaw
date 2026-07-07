import Foundation
import Testing

struct RootTabsSourceGuardTests {
    @Test func `hidden sidebar reveal uses destination header without reserved rail`() throws {
        let source = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let componentSource = try String(contentsOf: Self.proComponentsSourceURL(), encoding: .utf8)

        #expect(source.contains("sidebarHeaderLeadingAction"))
        #expect(source.contains("Hide Sidebar"))
        #expect(source.contains("Show Sidebar"))
        #expect(source.contains("shouldShowSidebarRevealInDestinationHeader"))
        #expect(source.contains("layoutMode: self.isSidebarDrawerLayout ? .drawer : .split"))
        #expect(componentSource.contains("OpenClawSidebarHeaderLeadingSlot"))
        #expect(componentSource.contains(".frame(width: 44, height: 44, alignment: .center)"))
        #expect(source.contains(".safeAreaPadding(.top, 8)"))
        #expect(source.contains("Self.sidebarShowButtonAccessibilityIdentifier"))
        #expect(source.contains("Self.sidebarHideButtonAccessibilityIdentifier"))
        #expect(source.contains("accessibilityLabel: \"Hide Sidebar\""))
        #expect(source.contains("accessibilityLabel: \"Show Sidebar\""))
        #expect(source.contains("action: { self.hideSidebar() }"))
        #expect(source.contains("action: { self.showSidebar() }"))
        #expect(!source.contains("private var collapsedSidebarRail: some View"))
        #expect(!source.contains("Self.sidebarCollapsedRailWidth"))
        #expect(source.contains("requestedInitialSidebarVisibility"))
        #expect(!source.contains("@State private var splitColumnVisibility: NavigationSplitViewVisibility"))
        #expect(!source.contains("NavigationSplitView(columnVisibility: self.$splitColumnVisibility)"))
        #expect(source.contains("HStack(spacing: 0)"))
        #expect(!source.contains("self.syncSidebarVisibility(from: visibility)"))
        #expect(!source.contains("shouldReserveSidebarRevealInset"))
        #expect(!source.contains("safeAreaInset(edge: .top"))
        #expect(!source.contains("thinMaterial, in: Circle"))
        #expect(!source.contains("sidebarRevealInset"))
        #expect(source.contains("Color.black.opacity(0.28)"))
        #expect(source.contains(".background(Color(uiColor: .systemBackground))"))
        #expect(!source.contains("sidebarRevealCornerButton"))
        #expect(!source.contains("shouldShowSidebarRevealOverlay"))
        #expect(!source.contains("shouldShowOverviewHeaderSidebarReveal"))
    }

    @Test func `i pad split uses sliding sidebar while portrait keeps drawer overlay`() throws {
        let source = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let splitContent = try Self.extract(
            source,
            from: "private func sidebarNavigationSplitContent(sidebarWidth: CGFloat) -> some View",
            to: "private func sidebarDrawerContent(sidebarWidth: CGFloat) -> some View")
        let drawerContent = try Self.extract(
            source,
            from: "private func sidebarDrawerContent(sidebarWidth: CGFloat) -> some View",
            to: "private var sidebarDetailShell: some View")

        #expect(!source.contains("@State private var splitColumnVisibility: NavigationSplitViewVisibility"))
        #expect(!source.contains("Self.sidebarSplitColumnVisibility(isSidebarVisible:"))
        #expect(!source.contains("self.syncSidebarVisibility(from: visibility)"))
        #expect(splitContent.contains("HStack(spacing: 0)"))
        #expect(splitContent.contains("self.sidebarColumn"))
        #expect(splitContent.contains(".frame(width: sidebarWidth, alignment: .topLeading)"))
        #expect(splitContent.contains(".overlay(alignment: .trailing)"))
        #expect(splitContent.contains("self.sidebarVerticalSeparator"))
        #expect(splitContent.contains("self.sidebarDetailNavigationShell"))
        #expect(!splitContent.contains("NavigationSplitView"))
        #expect(!splitContent.contains("self.collapsedSidebarRail"))
        #expect(!source.contains("Self.sidebarCollapsedRailWidth"))
        #expect(drawerContent.contains("ZStack(alignment: .topLeading)"))
        #expect(drawerContent.contains("Color.black.opacity(0.28)"))
        #expect(drawerContent.contains(".transition(.move(edge: .leading).combined(with: .opacity))"))
        #expect(!drawerContent.contains("NavigationSplitView"))
    }

    @Test func `phone tab bar keeps chat first product order`() throws {
        let source = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let phoneTabContent = try Self.extract(
            source,
            from: "private var phoneTabContent: some View",
            to: "private var sidebarSplitContent: some View")

        let chatRange = try #require(phoneTabContent.range(of: "ChatProTab("))
        let talkRange = try #require(phoneTabContent.range(of: "TalkProTab("))
        let controlRange = try #require(phoneTabContent.range(of: "RootTabsPhoneControlHub("))
        let agentRange = try #require(phoneTabContent.range(of: "AgentProTab("))
        let settingsRange = try #require(phoneTabContent.range(of: "SettingsProTab("))

        #expect(chatRange.lowerBound < talkRange.lowerBound)
        #expect(talkRange.lowerBound < controlRange.lowerBound)
        #expect(controlRange.lowerBound < agentRange.lowerBound)
        #expect(agentRange.lowerBound < settingsRange.lowerBound)
    }

    @Test func `phone control hub initial destination application is typed reducer state`() throws {
        let source = try String(contentsOf: Self.phoneHubSourceURL(), encoding: .utf8)

        #expect(source.contains("struct RootTabsInitialDestinationApplication: Equatable, Sendable"))
        #expect(source.contains(
            "var initialDestinationApplication = RootTabsInitialDestinationApplication(didApply: false)"))
        #expect(source.contains("var didApplyInitialDestination: Bool"))
        #expect(source.contains("self.initialDestinationApplication.didApply"))
        #expect(source.contains("guard !state.initialDestinationApplication.didApply else { return .none }"))
        #expect(source.contains("state.initialDestinationApplication = .init(didApply: true)"))
        #expect(!source.contains("var didApplyInitialDestination = false"))
        #expect(!source.contains("guard !state.didApplyInitialDestination else { return .none }"))
        #expect(!source.contains("state.didApplyInitialDestination = true"))
    }

    @Test func `gateway problem copy feedback is typed reducer state`() throws {
        let source = try String(contentsOf: Self.gatewayProblemSourceURL(), encoding: .utf8)

        #expect(source.contains("struct GatewayProblemCopyFeedbackText: Equatable, Sendable"))
        #expect(source.contains("var copyFeedback: GatewayProblemCopyFeedbackText?"))
        #expect(source.contains("state.copyFeedback = .init(value: \"Copied request ID\")"))
        #expect(source.contains("state.copyFeedback = .init(value: \"Copied command\")"))
        #expect(source.contains("Text(copyFeedback.value)"))
        #expect(!source.contains("var copyFeedback: String?"))
        #expect(!source.contains("state.copyFeedback = \"Copied request ID\""))
        #expect(!source.contains("state.copyFeedback = \"Copied command\""))
    }

    @Test func `gateway display status inputs are typed reducer state`() throws {
        let source = try String(contentsOf: Self.gatewayStatusBuilderSourceURL(), encoding: .utf8)
        let state = try Self.extract(
            source,
            from: "struct State: Equatable, Sendable {",
            to: "enum Action")

        #expect(source.contains("struct GatewayDisplayServerName: Equatable, Sendable"))
        #expect(source.contains("struct GatewayDisplayStatusText: Equatable, Sendable"))
        #expect(state.contains("var gatewayServerName: GatewayDisplayServerName"))
        #expect(state.contains("var gatewayStatusText: GatewayDisplayStatusText"))
        #expect(source.contains("self.gatewayServerName = .init(value: gatewayServerName)"))
        #expect(source.contains("self.gatewayStatusText = .init(value: gatewayStatusText)"))
        #expect(source.contains("gatewayServerName: state.gatewayServerName.value"))
        #expect(source.contains("gatewayStatusText: state.gatewayStatusText.value"))
        #expect(!state.contains("var gatewayServerName: String?"))
        #expect(!state.contains("var gatewayStatusText: String"))
        #expect(!source.contains("gatewayServerName: state.gatewayServerName,"))
        #expect(!source.contains("gatewayStatusText: state.gatewayStatusText)"))
    }

    @Test func `sidebar keeps navigation model destination only`() throws {
        let source = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let navigationSource = try String(contentsOf: Self.rootTabsNavigationSourceURL(), encoding: .utf8)
        let sidebarColumn = try Self.extract(
            source,
            from: "private var sidebarColumn: some View",
            to: "private var sidebarList: some View")

        #expect(source.contains("ForEach(Self.sidebarGroups)"))
        #expect(!source.contains("Section(\"Context\")"))
        #expect(!source.contains("sidebarAgentMenu"))
        #expect(!source.contains("sidebarDeviceMenu"))
        #expect(sidebarColumn.contains("self.sidebarIdentityHeader"))
        #expect(source.contains("private var sidebarIdentityHeader: some View"))
        #expect(source.contains("OpenClawProMark(size: 30"))
        #expect(source.contains("Text(\"OpenClaw\")"))
        #expect(source.contains("private var sidebarGatewayStatusTitle: String"))
        #expect(source.contains("private var sidebarGatewayStatusColor: Color"))
        #expect(!sidebarColumn.contains("activeAgent"))
        #expect(!source.contains("shouldShowSidebarColumnHeader"))
        #expect(!source.contains("private var sidebarColumnHeader: some View"))
        #expect(sidebarColumn.contains(".safeAreaPadding(.top, 8)"))
        #expect(source.contains(".scrollContentBackground(.hidden)"))
        #expect(source.contains(".listStyle(.sidebar)"))
        #expect(source.contains("private var sidebarHorizontalSeparator: some View"))
        #expect(source.contains("private var sidebarVerticalSeparator: some View"))
        #expect(source.contains("1 / UIScreen.main.scale"))
        #expect(!source.contains("geometry.size.height >= Self.sidebarListNonScrollingMinimumHeight"))
        #expect(!source.contains("private var sidebarListContent: some View"))
        #expect(source.contains(".listRowSeparator(.hidden, edges: .all)"))
        #expect(source.contains(".listSectionSeparator(.hidden, edges: .all)"))
        #expect(source.contains("if self.isSidebarDrawerLayout {"))
        #expect(!source.contains("private var sidebarFooter: some View"))
        #expect(!source.contains("LabeledContent(\"Version\""))
        #expect(navigationSource.contains("SidebarGroup(title: \"CHAT\", destinations: [.chat, .talk])"))
        #expect(!navigationSource.contains("title: \"AGENT\""))
        #expect(navigationSource.contains("case settings"))
        #expect(!navigationSource.contains("case settingsChannels"))
        #expect(!navigationSource.contains("case settingsApprovals"))
        #expect(!navigationSource.contains("case settingsPrivacy"))
        #expect(navigationSource.contains("SidebarGroup(\n            title: \"SETTINGS\""))
        #expect(navigationSource.contains("destinations: [.settings]"))
        #expect(!navigationSource.contains("destinations: [.gateway"))
        #expect(!navigationSource.contains("SidebarGroup(title: \"REFERENCE\", destinations: [.settings"))
        #expect(navigationSource.contains("SidebarGroup(title: \"REFERENCE\", destinations: [.docs])"))
    }

    @Test func `sidebar routes use destination headers instead of repeated product branding`() throws {
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let agentOverviewSource = try String(contentsOf: Self.agentProTabOverviewSourceURL(), encoding: .utf8)
        let docsSource = try String(contentsOf: Self.docsSourceURL(), encoding: .utf8)
        let sidebarDetail = try Self.extract(
            rootSource,
            from: "private var sidebarDetail: some View",
            to: "private var sidebarDetailNavigationShell: some View")
        let sidebarOverview = try Self.extract(
            rootSource,
            from: "private var sidebarOverview: some View",
            to: "func selectSidebarDestination")

        #expect(sidebarDetail.contains("headerTitle: \"Chat\""))
        #expect(sidebarDetail.contains("self.sidebarOverview"))
        #expect(sidebarOverview.contains("headerTitle: \"Overview\""))
        #expect(sidebarDetail.contains("headerTitle: \"Agents\""))
        #expect(sidebarDetail.contains("headerTitle: \"Instances\""))
        #expect(!sidebarDetail.contains("headerTitle: \"Nodes\""))
        #expect(sidebarDetail.contains("directRoute: .agents"))
        #expect(sidebarDetail.contains("directRoute: .instances"))
        #expect(sidebarDetail.contains("directRoute: .dreaming"))
        #expect(sidebarDetail.contains("directRoute: .usage"))
        #expect(sidebarDetail.contains("directRoute: .cron"))
        #expect(!sidebarDetail.contains("initialRoute: .nodes"))
        #expect(!sidebarDetail.contains("initialRoute: .usage"))
        #expect(!sidebarDetail.contains("initialRoute: .cron"))
        #expect(sidebarDetail.contains("headerTitle: \"Dreaming\""))
        #expect(sidebarDetail.contains("headerTitle: \"Usage\""))
        #expect(sidebarDetail.contains("headerTitle: \"Cron Jobs\""))
        #expect(!sidebarDetail.contains("headerTitle: \"OpenClaw\""))
        #expect(agentOverviewSource.contains("OpenClawAdaptiveHeaderRow("))
        #expect(agentOverviewSource.contains("title: self.headerTitle"))
        #expect(!agentOverviewSource.contains("Text(\"OpenClaw\")"))
        #expect(docsSource.contains("OpenClawAdaptiveHeaderRow("))
        #expect(docsSource.contains("title: \"Docs\""))
        #expect(!docsSource.contains("Text(\"OpenClaw Docs\")"))
    }

    @Test func `agents direct route keeps single sidebar control`() throws {
        let source = try String(contentsOf: Self.agentProTabSourceURL(), encoding: .utf8)
        let gatewayDataSource = try String(contentsOf: Self.agentProTabGatewayDataSourceURL(), encoding: .utf8)
        let overviewSource = try String(contentsOf: Self.agentProTabOverviewSourceURL(), encoding: .utf8)
        let skillsSource = try String(contentsOf: Self.agentProTabSkillsSourceURL(), encoding: .utf8)
        let cronSource = try String(contentsOf: Self.agentProTabCronSourceURL(), encoding: .utf8)
        let destinationsSource = try String(contentsOf: Self.agentProTabDestinationsSourceURL(), encoding: .utf8)
        let nodesSource = try String(contentsOf: Self.agentProNodesDestinationSourceURL(), encoding: .utf8)
        let dreamingSource = try String(contentsOf: Self.agentProDreamingDestinationSourceURL(), encoding: .utf8)
        let overviewLoadFeature = try Self.extract(
            source,
            from: "@Reducer\nstruct AgentOverviewLoadFeature",
            to: "@Reducer\nstruct AgentNavigationFeature")
        let overviewFilterFeature = try Self.extract(
            source,
            from: "@Reducer\nstruct AgentOverviewFilterFeature",
            to: ".autoLogActions()")
        let clawHubSearchFeature = try Self.extract(
            source,
            from: "@Reducer\nstruct AgentClawHubSearchFeature",
            to: "@Reducer\nstruct AgentOverviewLoadFeature")
        let skillFilterFeature = try Self.extract(
            source,
            from: "@Reducer\nstruct AgentSkillFilterFeature",
            to: "// swiftformat:disable redundantSendable\nstruct AgentClawHubInstallSlug")
        let skillPolicyMutationFeature = try Self.extract(
            source,
            from: "@Reducer\nstruct AgentSkillPolicyMutationFeature",
            to: "// swiftformat:disable redundantSendable\nstruct AgentSkillEditorAPIKeyDraftKey")
        let skillEditorFeature = try Self.extract(
            source,
            from: "@Reducer\nstruct AgentSkillEditorFeature",
            to: "// swiftformat:disable redundantSendable\nstruct AgentCronActionID")
        let cronActionFeature = try Self.extract(
            source,
            from: "@Reducer\nstruct AgentCronActionFeature",
            to: "// swiftformat:disable redundantSendable\nstruct AgentSkillFilterSearchText")

        #expect(!source.contains("ToolbarItem"))
        #expect(source.contains("@Reducer\nstruct AgentSkillPolicyMutationFeature"))
        #expect(source.contains("@Reducer\nstruct AgentSkillEditorFeature"))
        #expect(source.contains("@Reducer\nstruct AgentCronActionFeature"))
        #expect(source.contains("@Reducer\nstruct AgentClawHubSearchFeature"))
        #expect(source.contains("@Reducer\nstruct AgentSkillFilterFeature"))
        #expect(source.contains("@Reducer\nstruct AgentOverviewFilterFeature"))
        #expect(source.contains("enum AgentRoute: Hashable, Sendable"))
        #expect(source.contains("enum AgentSkillStatusFilter: String, CaseIterable, Identifiable, Sendable"))
        #expect(source.contains("enum AgentRosterFilter: String, CaseIterable, Identifiable, Sendable"))
        #expect(source.contains("struct AgentOverviewSearchText: Equatable, Sendable"))
        #expect(source.contains("var text: AgentOverviewSearchText"))
        #expect(source.contains("var rosterFilter: AgentRosterFilter = .all"))
        #expect(source.contains("case rosterFilterChanged(AgentRosterFilter)"))
        #expect(overviewFilterFeature.contains("state.searchText = change.text"))
        #expect(!source.contains("enum AgentRosterFilter: String, CaseIterable, Identifiable {"))
        #expect(!source.contains("AgentProTab.AgentRosterFilter"))
        #expect(source.contains("@Reducer\nstruct AgentOverviewLoadFeature"))
        #expect(source.contains("var navigationPath: [AgentRoute] = []"))
        #expect(source.contains("var path: [AgentRoute]"))
        #expect(!source.contains("enum AgentRoute: Hashable {"))
        #expect(!source.contains("AgentProTab.AgentRoute"))
        #expect(!source.contains("@State var agentRosterFilter"))
        #expect(!source.contains("@State var agentSearchText"))
        #expect(!source.contains("@State var skillFilter: String"))
        #expect(!source.contains("@State var skillStatusFilter"))
        #expect(!source.contains("@State var skillMutationBusyKeys"))
        #expect(!source.contains("@State var skillMutationErrorText"))
        #expect(!source.contains("@State var skillMutationStatusText"))
        #expect(!source.contains("@State var skillConfigBusyKeys"))
        #expect(!source.contains("@State var skillConfigMessages"))
        #expect(!source.contains("@State var skillAPIKeyDrafts"))
        #expect(!source.contains("@State var skillEditorSelection"))
        #expect(!source.contains("@State var cronActionBusyIDs"))
        #expect(!source.contains("@State var cronActionStatusText"))
        #expect(!source.contains("@State var overview: AgentOverviewSnapshot?"))
        #expect(!source.contains("@State var overviewErrorText"))
        #expect(!source.contains("@State var overviewLoading"))
        #expect(source.contains("@State var overviewStore: StoreOf<AgentOverviewLoadFeature>"))
        #expect(source.contains("struct AgentOverviewSearchPresentation: Equatable, Sendable"))
        #expect(source.contains("var searchPresentation = AgentOverviewSearchPresentation(isPresented: false)"))
        #expect(source.contains("var searchPresented: Bool"))
        #expect(source.contains("self.searchPresentation.isPresented"))
        #expect(source.contains("state.searchPresentation.isPresented.toggle()"))
        #expect(source.contains("var overviewLoading: Bool {\n        self.overviewStore.loadingPhase == .inFlight"))
        #expect(source.contains("self.overviewStore.errorText.value"))
        #expect(overviewLoadFeature.contains("struct AgentOverviewErrorText: Equatable, Sendable"))
        #expect(overviewLoadFeature.contains("enum LoadingPhase: Equatable, Sendable"))
        #expect(overviewLoadFeature.contains("var loadingPhase = LoadingPhase.idle"))
        #expect(overviewLoadFeature.contains("struct GatewayConnectionStatus: Equatable, Sendable"))
        #expect(overviewLoadFeature.contains("struct RefreshForce: Equatable, Sendable"))
        #expect(overviewLoadFeature.contains("struct ActiveAgentID: Equatable, Sendable"))
        #expect(overviewLoadFeature.contains("struct AgentOverviewRefreshRequestID: Equatable, Sendable"))
        #expect(overviewLoadFeature.contains("var errorText = AgentOverviewErrorText(value: nil)"))
        #expect(overviewLoadFeature.contains("let id: AgentOverviewRefreshRequestID"))
        #expect(overviewLoadFeature.contains("let activeAgentID: ActiveAgentID"))
        #expect(overviewLoadFeature.contains("var gatewayConnection: GatewayConnectionStatus"))
        #expect(overviewLoadFeature.contains("var force: RefreshForce"))
        #expect(overviewLoadFeature.contains("var activeAgent: ActiveAgentID"))
        #expect(overviewLoadFeature.contains("var requestID: AgentOverviewRefreshRequestID"))
        #expect(overviewLoadFeature.contains("guard request.gatewayConnection.isConnected"))
        #expect(overviewLoadFeature.contains("guard request.force.isForced || state.loadingPhase != .inFlight"))
        #expect(overviewLoadFeature.contains("state.loadingPhase = .inFlight"))
        #expect(overviewLoadFeature.contains("state.loadingPhase = .idle"))
        #expect(overviewLoadFeature.contains("id: .init(value: state.nextRefreshRequestID)"))
        #expect(overviewLoadFeature.contains("activeAgentID: request.activeAgent"))
        #expect(overviewLoadFeature.contains("state.errorText = .init(value: nil)"))
        #expect(overviewLoadFeature.contains(
            "state.errorText = .init(\n                    value: result.snapshot.hasAnyLiveData ? nil : \"Live overview could not load yet.\")"))
        #expect(!overviewLoadFeature.contains("var gatewayConnected: Bool"))
        #expect(!overviewLoadFeature.contains("var activeAgentID: String"))
        #expect(!overviewLoadFeature.contains("let activeAgentID: String"))
        #expect(!overviewLoadFeature.contains("let id: Int"))
        #expect(!overviewLoadFeature.contains("var requestID: Int"))
        #expect(!overviewLoadFeature.contains("var errorText: String?"))
        #expect(!source.contains("var overviewLoading: Bool {\n        self.overviewStore.isLoading"))
        #expect(!overviewLoadFeature.contains("var isLoading = false"))
        #expect(!overviewLoadFeature.contains("state.isLoading = true"))
        #expect(!overviewLoadFeature.contains("state.isLoading = false"))
        #expect(!overviewLoadFeature.contains("guard request.force.isForced || !state.isLoading"))
        #expect(!overviewLoadFeature.contains("state.errorText = nil"))
        #expect(!source.contains("var searchPresented = false"))
        #expect(!source.contains("state.searchPresented.toggle()"))
        #expect(!overviewLoadFeature.contains(
            "state.errorText = result.snapshot.hasAnyLiveData ? nil : \"Live overview could not load yet.\""))
        #expect(source.contains("@State var skillFilterStore: StoreOf<AgentSkillFilterFeature>"))
        #expect(source.contains("@State var skillPolicyMutationStore: StoreOf<AgentSkillPolicyMutationFeature>"))
        #expect(source.contains("@State var skillEditorStore: StoreOf<AgentSkillEditorFeature>"))
        #expect(source.contains("@State var cronActionStore: StoreOf<AgentCronActionFeature>"))
        #expect(source.contains("var statusFilter: AgentSkillStatusFilter = .all"))
        #expect(source.contains("case statusFilterChanged(AgentSkillStatusFilter)"))
        #expect(skillsSource.contains("ForEach(AgentSkillStatusFilter.allCases)"))
        #expect(!source.contains("enum SkillStatusFilter: String, CaseIterable, Identifiable"))
        #expect(!source.contains("AgentProTab.SkillStatusFilter"))
        #expect(source.contains(".sheet(item: self.skillEditorSelectionBinding)"))
        #expect(source.contains("case selectionChanged(SelectionChange)"))
        #expect(source.contains("set: { self.skillEditorStore.send(.selectionChanged(.init(selection: $0))) }"))
        #expect(!source.contains(".sheet(item: self.$skillEditorSelection)"))
        #expect(!source.contains("@State var clawHubQuery"))
        #expect(!source.contains("@State var clawHubResults"))
        #expect(!source.contains("@State var clawHubLoading"))
        #expect(!source.contains("@State var clawHubErrorText"))
        #expect(!source.contains("@State var clawHubInstallSlug"))
        #expect(source.contains("@State var clawHubStore: StoreOf<AgentClawHubSearchFeature>"))
        #expect(gatewayDataSource.contains("self.overviewStore.send(.refreshRequested(.init("))
        #expect(gatewayDataSource.contains("gatewayConnection: .init(isConnected: self.liveGatewayConnected)"))
        #expect(gatewayDataSource.contains("force: .init(isForced: force)"))
        #expect(gatewayDataSource.contains("activeAgent: .init(value: requestedAgentID)"))
        #expect(gatewayDataSource.contains("self.overviewStore.send(.refreshLaunched(.init(requestID: requestID)))"))
        #expect(gatewayDataSource
            .contains("self.overviewStore.send(.refreshFinished(.init(snapshot: snapshot, requestID: requestID)))"))
        #expect(skillsSource.contains("text: self.clawHubQueryBinding"))
        #expect(source.contains("var clawHubQuery: String {\n        self.clawHubStore.query.value"))
        #expect(source.contains("get: { self.clawHubStore.query.value }"))
        #expect(source.contains("var clawHubLoading: Bool {\n        self.clawHubStore.loadingPhase == .inFlight"))
        #expect(source.contains("self.clawHubStore.errorText.value"))
        #expect(source.contains("self.clawHubStore.installingSlug?.value"))
        #expect(source.contains("set: { self.clawHubStore.send(.queryChanged(.init(query: .init(value: $0)))) }"))
        #expect(skillsSource.contains("self.clawHubStore.send(.searchRequested)"))
        #expect(source.contains("case searchFinished(SearchResults)"))
        #expect(skillsSource.contains("self.clawHubStore.send(.searchFinished(.init(results: results)))"))
        #expect(skillsSource.contains("let installSlug = AgentClawHubInstallSlug(value: result.slug)"))
        #expect(skillsSource.contains("self.clawHubStore.send(.installRequested(.init(slug: installSlug)))"))
        #expect(skillsSource.contains("self.clawHubStore.send(.installFinished(.init(slug: installSlug)))"))
        #expect(source.contains("struct AgentClawHubInstallSlug: Equatable, Sendable"))
        #expect(source.contains("struct AgentClawHubErrorText: Equatable, Sendable"))
        #expect(source.contains("struct AgentClawHubInstallFailureMessage: Equatable, Sendable"))
        #expect(source.contains("struct AgentClawHubSearchQuery: Equatable, Sendable"))
        #expect(source.contains("struct AgentClawHubSearchFailureMessage: Equatable, Sendable"))
        #expect(source.contains("var slug: AgentClawHubInstallSlug"))
        #expect(source.contains("var query: AgentClawHubSearchQuery"))
        #expect(source.contains("var message: AgentClawHubInstallFailureMessage"))
        #expect(source.contains("var message: AgentClawHubSearchFailureMessage"))
        #expect(clawHubSearchFeature.contains("var query = AgentClawHubSearchQuery(value: \"\")"))
        #expect(clawHubSearchFeature.contains("enum SearchLoadingPhase: Equatable, Sendable"))
        #expect(clawHubSearchFeature.contains("var loadingPhase = SearchLoadingPhase.idle"))
        #expect(clawHubSearchFeature.contains("var errorText = AgentClawHubErrorText(value: nil)"))
        #expect(clawHubSearchFeature.contains("var installingSlug: AgentClawHubInstallSlug?"))
        #expect(clawHubSearchFeature.contains("state.query = change.query"))
        #expect(clawHubSearchFeature.contains("state.loadingPhase = .inFlight"))
        #expect(clawHubSearchFeature.contains("state.loadingPhase = .idle"))
        #expect(clawHubSearchFeature.contains("state.installingSlug = install.slug"))
        #expect(clawHubSearchFeature.contains("state.installingSlug == install.slug"))
        #expect(clawHubSearchFeature.contains("state.installingSlug == failure.slug"))
        #expect(clawHubSearchFeature.contains("state.errorText = .init(value: failure.message.value)"))
        #expect(skillsSource.contains(
            "self.clawHubStore.send(.searchFailed(.init(message: .init(value: Self.skillMutationMessage(error)))))"))
        #expect(!source.contains(
            "struct InstallSlug: Equatable, Sendable {\n            var slug: String"))
        #expect(!source.contains(
            "struct QueryChange: Equatable, Sendable {\n            var query: String"))
        #expect(!source.contains("var clawHubLoading: Bool {\n        self.clawHubStore.isLoading"))
        #expect(!clawHubSearchFeature.contains("var query = \"\""))
        #expect(!clawHubSearchFeature.contains("var isLoading = false"))
        #expect(!clawHubSearchFeature.contains("state.isLoading = true"))
        #expect(!clawHubSearchFeature.contains("state.isLoading = false"))
        #expect(!clawHubSearchFeature.contains("var errorText: String?"))
        #expect(!clawHubSearchFeature.contains("var installingSlug: String?"))
        #expect(!clawHubSearchFeature.contains("state.installingSlug = install.slug.value"))
        #expect(!clawHubSearchFeature.contains("state.installingSlug == install.slug.value"))
        #expect(!clawHubSearchFeature.contains("state.installingSlug == failure.slug.value"))
        #expect(!clawHubSearchFeature.contains("state.errorText = failure.message.value"))
        #expect(!clawHubSearchFeature.contains("state.query = change.query.value"))
        #expect(!source.contains("struct SearchFailure: Equatable, Sendable {\n            var message: String"))
        #expect(!source.contains(
            "struct InstallFailure: Equatable, Sendable {\n            var slug: String\n            var message: String"))
        #expect(skillsSource.contains("text: self.skillFilterBinding"))
        #expect(source.contains("var skillFilter: String {\n        self.skillFilterStore.searchText.value"))
        #expect(source.contains("get: { self.skillFilterStore.searchText.value }"))
        #expect(source.contains("set: { self.skillFilterStore.send(.searchTextChanged(.init(text: .init(value: $0)))) }"))
        #expect(source.contains("struct AgentSkillFilterSearchText: Equatable, Sendable"))
        #expect(skillFilterFeature.contains("var searchText = AgentSkillFilterSearchText(value: \"\")"))
        #expect(source.contains("var text: AgentSkillFilterSearchText"))
        #expect(skillFilterFeature.contains("state.searchText = change.text"))
        #expect(skillFilterFeature.contains("state.searchText = .init(value: \"\")"))
        #expect(!skillFilterFeature.contains("var searchText = \"\""))
        #expect(!source.contains("self.skillFilterStore.searchText\n"))
        #expect(!source.contains("get: { self.skillFilterStore.searchText }"))
        #expect(!skillFilterFeature.contains("state.searchText = change.text.value"))
        #expect(!source.contains(
            "struct SearchTextChange: Equatable, Sendable {\n            var text: String\n        }\n\n        case clearSearchTapped"))
        #expect(skillsSource.contains("selection: self.skillStatusFilterBinding"))
        #expect(skillsSource.contains("self.skillFilterStore.send(.clearSearchTapped)"))
        #expect(skillsSource.contains("let mutationKey = AgentSkillPolicyMutationKey(value: busyKey)"))
        #expect(skillsSource.contains("self.skillPolicyMutationStore.send(.mutationStarted(.init(key: mutationKey)))"))
        #expect(skillsSource.contains("self.skillPolicyMutationStore.send(.mutationFinished(.init(key: mutationKey)))"))
        #expect(source.contains("struct AgentSkillPolicyMutationKey: Equatable, Hashable, Sendable"))
        #expect(source.contains("struct AgentSkillPolicyMutationErrorText: Equatable, Sendable"))
        #expect(source.contains("struct AgentSkillPolicyMutationFailureMessage: Equatable, Sendable"))
        #expect(source.contains("struct AgentSkillPolicyMutationStatusText: Equatable, Sendable"))
        #expect(source.contains("struct AgentSkillPolicyMutationSuccessMessage: Equatable, Sendable"))
        #expect(source.contains("Set(self.skillPolicyMutationStore.busyKeys.map(\\.value))"))
        #expect(skillPolicyMutationFeature.contains("var busyKeys: Set<AgentSkillPolicyMutationKey> = []"))
        #expect(skillPolicyMutationFeature.contains("var errorText = AgentSkillPolicyMutationErrorText(value: nil)"))
        #expect(skillPolicyMutationFeature.contains("var statusText = AgentSkillPolicyMutationStatusText(value: nil)"))
        #expect(source.contains("var key: AgentSkillPolicyMutationKey"))
        #expect(source.contains("var message: AgentSkillPolicyMutationFailureMessage"))
        #expect(source.contains("var message: AgentSkillPolicyMutationSuccessMessage"))
        #expect(skillPolicyMutationFeature.contains("state.busyKeys.insert(mutation.key)"))
        #expect(skillPolicyMutationFeature.contains("state.busyKeys.remove(mutation.key)"))
        #expect(source.contains("self.skillPolicyMutationStore.errorText.value"))
        #expect(source.contains("self.skillPolicyMutationStore.statusText.value"))
        #expect(skillPolicyMutationFeature.contains("state.statusText = .init(value: result.message.value)"))
        #expect(skillPolicyMutationFeature.contains("state.errorText = .init(value: failure.message.value)"))
        #expect(!skillPolicyMutationFeature.contains("var busyKeys: Set<String>"))
        #expect(!skillPolicyMutationFeature.contains("state.busyKeys.insert(mutation.key.value)"))
        #expect(!skillPolicyMutationFeature.contains("state.busyKeys.remove(mutation.key.value)"))
        #expect(!skillPolicyMutationFeature.contains("var errorText: String?"))
        #expect(!skillPolicyMutationFeature.contains("var statusText: String?"))
        #expect(!skillPolicyMutationFeature.contains("state.statusText = result.message.value"))
        #expect(!skillPolicyMutationFeature.contains("state.errorText = failure.message.value"))
        #expect(!source.contains(
            "struct MutationKey: Equatable, Sendable {\n            var key: String\n        }\n\n        struct MutationFailure: Equatable, Sendable {\n            var message: AgentSkillPolicyMutationFailureMessage"))
        #expect(!source
            .contains("struct MutationFailure: Equatable, Sendable {\n            var message: String"))
        #expect(!source
            .contains("struct MutationSuccess: Equatable, Sendable {\n            var message: String"))
        #expect(skillsSource.contains("self.skillPolicyMutationStore.send(.mutationSucceeded(.init("))
        #expect(skillsSource.contains("self.skillPolicyMutationStore.send(.mutationFailed(.init("))
        #expect(
            skillsSource.contains(
                "self.skillEditorStore.send(.editorOpened(.init(id: .init(value: skill.effectiveSkillKey))))"))
        #expect(source.contains("struct AgentSkillEditorID: Equatable, Sendable"))
        #expect(source.contains("struct AgentSkillEditorSelection: Equatable, Identifiable, Sendable"))
        #expect(source.contains("var id: AgentSkillEditorID"))
        #expect(source.contains("var selection: AgentSkillEditorSelection?"))
        #expect(source.contains("var skillID: AgentSkillEditorID"))
        #expect(source.contains("state.selection = AgentSkillEditorSelection(skillID: editor.id)"))
        #expect(!source.contains("struct SkillEditorSelection: Equatable, Identifiable"))
        #expect(!source.contains("state.selection = AgentProTab.SkillEditorSelection(id: editor.id.value)"))
        #expect(!source.contains(
            "struct EditorID: Equatable, Sendable {\n            var id: String"))
        #expect(skillsSource.contains("self.skillEditorStore.send(.apiKeyDraftChanged(.init("))
        #expect(skillsSource.contains("self.skillEditorStore.send(.apiKeyDraftCleared(.init("))
        #expect(skillsSource.contains("get: { self.skillAPIKeyDrafts[skill.effectiveSkillKey] ?? \"\" }"))
        #expect(skillsSource.contains("let apiKey = self.skillAPIKeyDrafts[skill.effectiveSkillKey] ?? \"\""))
        #expect(skillsSource.contains("key: .init(value: skill.effectiveSkillKey)"))
        #expect(skillsSource.contains("value: .init(value: $0)"))
        #expect(source.contains("struct AgentSkillEditorAPIKeyDraftKey: Equatable, Hashable, Sendable"))
        #expect(source.contains("struct AgentSkillEditorAPIKeyDraftValue: Equatable, Sendable"))
        #expect(source.contains(
            "Dictionary(uniqueKeysWithValues: self.skillEditorStore.apiKeyDrafts.map { ($0.key.value, $0.value.value) })"))
        #expect(skillEditorFeature.contains(
            "var apiKeyDrafts: [AgentSkillEditorAPIKeyDraftKey: AgentSkillEditorAPIKeyDraftValue] = [:]"))
        #expect(source.contains("var key: AgentSkillEditorAPIKeyDraftKey"))
        #expect(source.contains("var value: AgentSkillEditorAPIKeyDraftValue"))
        #expect(skillEditorFeature.contains("state.apiKeyDrafts[draft.key] = draft.value"))
        #expect(skillEditorFeature.contains("state.apiKeyDrafts[draft.key] = nil"))
        #expect(!skillsSource.contains("self.skillEditorStore.apiKeyDrafts[skill.effectiveSkillKey]"))
        #expect(!skillEditorFeature.contains("var apiKeyDrafts: [String: String]"))
        #expect(!skillEditorFeature.contains("state.apiKeyDrafts[draft.key.value] = draft.value.value"))
        #expect(!skillEditorFeature.contains("state.apiKeyDrafts[draft.key.value] = nil"))
        #expect(!source.contains(
            "struct APIKeyDraftChange: Equatable, Sendable {\n            var key: String\n            var value: String"))
        #expect(!source.contains(
            "struct APIKeyDraftKey: Equatable, Sendable {\n            var key: String"))
        #expect(skillsSource.contains("self.skillEditorStore.send(.mutationStarted(.init(key: key)))"))
        #expect(skillsSource.contains("let key = AgentSkillEditorMutationKey(value: skill.effectiveSkillKey)"))
        #expect(source.contains("struct AgentSkillEditorMutationKey: Equatable, Hashable, Sendable"))
        #expect(source.contains("struct AgentSkillEditorMutationSummary: Equatable, Sendable"))
        #expect(source.contains("struct AgentSkillEditorMutationSuccessMessage: Equatable, Sendable"))
        #expect(source.contains("struct AgentSkillEditorMutationFailureMessage: Equatable, Sendable"))
        #expect(source.contains("struct AgentSkillEditorMessageText: Equatable, Sendable"))
        #expect(source.contains("struct AgentSkillEditorMessage: Equatable, Sendable"))
        #expect(source.contains("Set(self.skillEditorStore.busyKeys.map(\\.value))"))
        #expect(source.contains("Dictionary(uniqueKeysWithValues: self.skillEditorStore.messages.map { ($0.key.value, $0.value) })"))
        #expect(source.contains("var busyKeys: Set<AgentSkillEditorMutationKey> = []"))
        #expect(source.contains("var messages: [AgentSkillEditorMutationKey: AgentSkillEditorMessage] = [:]"))
        #expect(source.contains("var key: AgentSkillEditorMutationKey"))
        #expect(source.contains("var message: AgentSkillEditorMutationSuccessMessage"))
        #expect(source.contains("var summary: AgentSkillEditorMutationSummary"))
        #expect(source.contains("var message: AgentSkillEditorMutationFailureMessage"))
        #expect(source.contains("state.busyKeys.insert(mutation.key)"))
        #expect(source.contains("state.messages[mutation.key] = nil"))
        #expect(source.contains("state.messages[result.key]"))
        #expect(source.contains("state.busyKeys.remove(mutation.key)"))
        #expect(source.contains("state.busyKeys.remove(failure.key)"))
        #expect(source.contains("state.messages[failure.key]"))
        #expect(source.contains("text: .init(value: result.summary.message.value)"))
        #expect(source.contains("text: .init(value: failure.message.value)"))
        #expect(skillsSource.contains("Text(message.text.value)"))
        #expect(!source.contains("struct SkillEditorMessage: Equatable"))
        #expect(!source.contains("var messages: [AgentSkillEditorMutationKey: AgentProTab.SkillEditorMessage]"))
        #expect(!source.contains("var messages: [String: AgentProTab.SkillEditorMessage]"))
        #expect(!source.contains("state.busyKeys.insert(mutation.key.value)"))
        #expect(!source.contains("state.messages[mutation.key.value] = nil"))
        #expect(!source.contains("state.messages[result.key.value]"))
        #expect(!source.contains("state.messages[failure.key.value]"))
        #expect(!source.contains("state.busyKeys.remove(failure.key.value)"))
        #expect(!source.contains(
            "struct AgentSkillEditorMutationSummary: Equatable, Sendable {\n    var message: String"))
        #expect(!source.contains(
            "struct MutationFailure: Equatable, Sendable {\n            var key: String\n            var message: AgentSkillEditorMutationFailureMessage"))
        #expect(!source.contains(
            "struct MutationSuccess: Equatable, Sendable {\n            var key: String\n            var summary: AgentSkillEditorMutationSummary"))
        #expect(
            skillsSource.contains(
                "self.skillEditorStore.send(.mutationSucceeded(.init(key: key, summary: summary)))"))
        #expect(!source.contains(
            "struct MutationFailure: Equatable, Sendable {\n            var key: String\n            var message: String"))
        #expect(!skillsSource.contains("action: () async throws -> String"))
        #expect(skillsSource.contains("self.skillEditorStore.send(.mutationFinished(.init(key: key)))"))
        #expect(skillsSource.contains("self.skillEditorStore.send(.mutationFailed(.init("))
        #expect(cronSource.contains("let actionID = AgentCronActionID(value: job.id)"))
        #expect(cronSource.contains("self.cronActionStore.send(.actionStarted(.init(id: actionID)))"))
        #expect(source.contains("struct AgentCronActionID: Equatable, Hashable, Sendable"))
        #expect(source.contains("struct AgentCronActionFailureMessage: Equatable, Sendable"))
        #expect(source.contains("struct AgentCronActionStatusText: Equatable, Sendable"))
        #expect(source.contains("struct AgentCronActionSuccessMessage: Equatable, Sendable"))
        #expect(source.contains("Set(self.cronActionStore.busyIDs.map(\\.value))"))
        #expect(cronActionFeature.contains("var busyIDs: Set<AgentCronActionID> = []"))
        #expect(cronActionFeature.contains("var statusText = AgentCronActionStatusText(value: nil)"))
        #expect(source.contains("var id: AgentCronActionID"))
        #expect(source.contains("var message: AgentCronActionFailureMessage"))
        #expect(source.contains("var message: AgentCronActionSuccessMessage"))
        #expect(source.contains("self.cronActionStore.statusText.value"))
        #expect(cronActionFeature.contains("state.busyIDs.insert(action.id)"))
        #expect(cronActionFeature.contains("state.busyIDs.remove(action.id)"))
        #expect(cronActionFeature.contains("state.busyIDs.remove(failure.id)"))
        #expect(cronActionFeature.contains("state.statusText = .init(value: result.message.value)"))
        #expect(cronActionFeature.contains("state.statusText = .init(value: failure.message.value)"))
        #expect(!cronActionFeature.contains("var busyIDs: Set<String>"))
        #expect(!cronActionFeature.contains("state.busyIDs.insert(action.id.value)"))
        #expect(!cronActionFeature.contains("state.busyIDs.remove(action.id.value)"))
        #expect(!cronActionFeature.contains("state.busyIDs.remove(failure.id.value)"))
        #expect(!cronActionFeature.contains("var statusText: String?"))
        #expect(!cronActionFeature.contains("state.statusText = result.message.value"))
        #expect(!cronActionFeature.contains("state.statusText = failure.message.value"))
        #expect(cronSource.contains("self.cronActionStore.send(.actionSucceeded(.init(message: .init(value: success)))"))
        #expect(!source.contains("struct ActionSuccess: Equatable, Sendable {\n            var message: String"))
        #expect(!source.contains(
            "struct ActionID: Equatable, Sendable {\n            var id: String"))
        #expect(!source.contains(
            "struct ActionFailure: Equatable, Sendable {\n            var id: String\n            var message: String"))
        #expect(cronSource.contains("self.cronActionStore.send(.actionFinished(.init(id: actionID)))"))
        #expect(cronSource.contains("self.cronActionStore.send(.actionFailed(.init("))
        #expect(overviewSource.contains("selection: self.agentRosterFilterBinding"))
        #expect(overviewSource.contains("text: self.agentSearchTextBinding"))
        #expect(overviewSource.contains("private var agentSearchText: String"))
        #expect(overviewSource.contains("self.filterStore.searchText.value"))
        #expect(overviewSource.contains("let query = self.agentSearchText.trimmingCharacters"))
        #expect(overviewSource.contains("set: { self.filterStore.send(.searchTextChanged(.init(text: .init(value: $0)))) }"))
        #expect(overviewSource.contains("self.filterStore.send(.clearFiltersTapped)"))
        #expect(overviewFilterFeature.contains("var searchText = AgentOverviewSearchText(value: \"\")"))
        #expect(overviewFilterFeature.contains("self.searchText.value.trimmingCharacters"))
        #expect(overviewFilterFeature.contains("state.searchText = change.text"))
        #expect(overviewFilterFeature.contains("state.searchText = .init(value: \"\")"))
        #expect(!overviewSource.contains("get: { self.filterStore.searchText }"))
        #expect(!overviewSource.contains("self.filterStore.searchText.trimmingCharacters"))
        #expect(!overviewFilterFeature.contains("var searchText = \"\""))
        #expect(!overviewFilterFeature.contains("state.searchText = change.text.value"))
        #expect(!source.contains(
            "struct SearchTextChange: Equatable, Sendable {\n            var text: String\n        }\n\n        case clearFiltersTapped"))
        #expect(source.contains("NavigationStack(path: self.navigationPathBinding)"))
        #expect(source.contains("case navigationPathChanged(NavigationPathChange)"))
        #expect(source.contains("set: { self.navigationStore.send(.navigationPathChanged(.init(path: $0))) }"))
        #expect(source
            .contains("route == .agents || self.directHeaderLeadingAction(for: route) != nil ? .hidden : .visible"))
        #expect(destinationsSource.contains(".toolbar(.hidden, for: .navigationBar)"))
        #expect(destinationsSource.contains("self.directHeaderLeadingAction(for: .instances)"))
        #expect(destinationsSource.contains("self.directHeaderLeadingAction(for: .dreaming)"))
        #expect(destinationsSource.contains("AgentDreamingDestinationStoreFactory.live("))
        #expect(dreamingSource.contains("@Reducer\nstruct AgentDreamingDestinationFeature"))
        #expect(dreamingSource.contains("await self.store.send(.dreamActionTapped("))
        #expect(dreamingSource.contains("self.store.send(.dreamDiaryDaySelected(.init(dayID: .init(value: day.id))))"))
        #expect(destinationsSource.contains("self.directHeader(\n                        for: .usage"))
        #expect(destinationsSource.contains("self.directHeader(\n                        for: .cron"))
        #expect(destinationsSource.contains("self.directRoute == route ? self.headerLeadingAction : nil"))
        #expect(nodesSource.contains("OpenClawSidebarHeaderLeadingSlot(action: headerLeadingAction)"))
        #expect(dreamingSource.contains("OpenClawSidebarHeaderLeadingSlot(action: headerLeadingAction)"))
    }

    @Test func `agent dreaming maintenance response action is typed`() throws {
        let source = try String(contentsOf: Self.agentProDreamingDestinationSourceURL(), encoding: .utf8)
        let feature = try Self.extract(
            source,
            from: "@Reducer\nstruct AgentDreamingDestinationFeature",
            to: "extension AgentDreamingMaintenanceError")

        #expect(feature.contains("struct DreamActionResponse: Equatable, Sendable"))
        #expect(source.contains("struct DreamActionSummary: Equatable, Sendable"))
        #expect(source.contains("var run: @Sendable @MainActor"))
        #expect(source.contains("async throws -> DreamActionSummary"))
        #expect(source.contains("static func summary(action: AgentDreamAction, data: Data) -> DreamActionSummary"))
        #expect(source.contains("struct AgentDreamingMaintenanceFailureMessage: Equatable, Sendable"))
        #expect(source.contains("struct AgentDreamingMaintenanceStatusText: Equatable, Sendable"))
        #expect(source.contains("struct AgentDreamDiaryDayID: Equatable, Sendable"))
        #expect(feature.contains("var selectedDreamDiaryDayID: AgentDreamDiaryDayID?"))
        #expect(feature.contains("var statusText = AgentDreamingMaintenanceStatusText(value: nil)"))
        #expect(feature.contains("var dayID: AgentDreamDiaryDayID"))
        #expect(feature.contains("struct GatewayConnectionStatus: Equatable, Sendable { var isConnected: Bool }"))
        #expect(feature.contains("var gatewayConnection: GatewayConnectionStatus"))
        #expect(feature.contains("guard tap.gatewayConnection.isConnected"))
        #expect(source.contains("gatewayConnection: .init(isConnected: self.gatewayConnected)"))
        #expect(feature.contains("state.selectedDreamDiaryDayID = selection.dayID"))
        #expect(source.contains("selectedDreamDiaryDayID.value"))
        #expect(source.contains("if let dreamActionStatusText = self.store.statusText.value"))
        #expect(source.contains(
            "struct Failure: Equatable, Sendable { var message: AgentDreamingMaintenanceFailureMessage }"))
        #expect(feature.contains("case dreamActionResponse(DreamActionResponse)"))
        #expect(feature.contains("var result: Result<DreamActionSummary, AgentDreamingMaintenanceError>"))
        #expect(feature.contains("await send(.dreamActionResponse(.init(result: .success(summary))))"))
        #expect(feature.contains("state.statusText = .init(value: summary.summary)"))
        #expect(feature.contains("state.statusText = .init(value: error.message)"))
        #expect(feature.contains(
            "result: .failure(.failed(.init(message: .init(value: error.localizedDescription))))"))
        #expect(feature.contains("switch response.result"))
        #expect(!feature.contains("Result<String, AgentDreamingMaintenanceError>"))
        #expect(!source.contains("async throws -> String"))
        #expect(source.contains("case failed(Failure)"))
        #expect(source.contains("failure.message.value"))
        #expect(!feature.contains("var selectedDreamDiaryDayID: String?"))
        #expect(!feature.contains("var statusText: String?"))
        #expect(!feature.contains("state.statusText = summary.summary"))
        #expect(!source.contains("if let dreamActionStatusText = self.store.statusText {"))
        #expect(!feature.contains("var dayID: String"))
        #expect(!feature.contains("var gatewayConnected: Bool"))
        #expect(!feature.contains("guard tap.gatewayConnected"))
        #expect(!source.contains("struct Failure: Equatable, Sendable { var message: String }"))
        #expect(!source.contains("case failed(String)"))
    }

    @Test func `iOS 26 chrome uses native glass while content cards stay quiet`() throws {
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let componentsSource = try String(contentsOf: Self.proComponentsSourceURL(), encoding: .utf8)
        let cardSurface = try Self.extract(
            componentsSource,
            from: "private struct ProPanelSurfaceModifier: ViewModifier",
            to: "struct ProIconBadge: View")

        #expect(rootSource.contains(".openClawTabBarBehavior()"))
        #expect(componentsSource.contains("content.tabBarMinimizeBehavior(.onScrollDown)"))
        #expect(componentsSource.contains(".buttonStyle(.glassProminent)"))
        #expect(componentsSource.contains(".buttonStyle(.glass)"))
        #expect(componentsSource.contains("GlassEffectContainer(spacing: 8)"))
        #expect(componentsSource.contains("if #available(iOS 26.0, *)"))
        #expect(componentsSource.contains(".buttonStyle(.borderedProminent)"))
        #expect(componentsSource.contains(".buttonStyle(.bordered)"))
        #expect(componentsSource.contains("struct OpenClawNoticeBanner: View"))
        #expect(!cardSurface.contains("glassEffect"))
    }

    @Test func `professional layout avoids nested pills and card stacks`() throws {
        let componentsSource = try String(contentsOf: Self.proComponentsSourceURL(), encoding: .utf8)
        let agentSource = try String(contentsOf: Self.agentProTabOverviewSourceURL(), encoding: .utf8)
        let talkSource = try String(contentsOf: Self.talkProTabSourceURL(), encoding: .utf8)
        let settingsSource = try String(contentsOf: Self.settingsProTabSectionsSourceURL(), encoding: .utf8)
        let overviewSource = try String(contentsOf: Self.commandCenterSourceURL(), encoding: .utf8)
        let overviewRowsSource = try String(contentsOf: Self.commandCenterSupportSourceURL(), encoding: .utf8)
        let gatewayStatus = try Self.extract(
            componentsSource,
            from: "struct OpenClawGatewayCompactPill: View",
            to: "struct ProMetricTile: View")
        let agentFilters = try Self.extract(
            agentSource,
            from: "var agentFilters: some View",
            to: "var agentFiltersActive: Bool")
        let agentRow = try Self.extract(
            agentSource,
            from: "func agentRow(_ agent: AgentSummary) -> some View",
            to: "func headerIconButton(")
        let settingsList = try Self.extract(
            settingsSource,
            from: "var settingsListSection: some View",
            to: "func settingsListRow(")
        let settingsRow = try Self.extract(
            settingsSource,
            from: "func settingsListRow(",
            to: "func destination(for route:")

        #expect(gatewayStatus.contains("HStack(spacing: 6)"))
        #expect(!gatewayStatus.contains("ProCapsule("))
        #expect(!gatewayStatus.contains("Capsule()"))
        #expect(agentFilters.contains("Picker(\"Agent status\""))
        #expect(agentFilters.contains(".pickerStyle(.segmented)"))
        #expect(!agentFilters.contains(".openClawGlassButton("))
        #expect(!agentRow.contains("agentMetric"))
        #expect(!agentRow.contains("chevron.right"))
        #expect(agentRow.contains("Image(systemName: \"checkmark\")"))
        #expect(agentRow.contains("agentAccessibilityLabel"))
        #expect(!talkSource.contains("conversationCard"))
        #expect(!talkSource.contains("voiceModeCard"))
        #expect(!talkSource.contains("statusChip"))
        #expect(!settingsList.contains("ProSectionHeader(title: \"OpenClaw\""))
        #expect(settingsList.contains("ProSectionHeader(title: \"Device\""))
        #expect(settingsList.matches(of: /ProCard\(padding: 0/).count == 2)
        #expect(settingsRow.contains(".contentShape(Rectangle())"))
        #expect(!overviewSource.contains("ProCapsule("))
        #expect(overviewSource.contains("value: self.gatewayStore.presentation.connectionText"))
        #expect(overviewSource.contains("switch self.gatewayDisplayState"))
        #expect(overviewSource.contains("case .connecting:"))
        #expect(overviewSource.contains("case .error:"))
        #expect(!overviewRowsSource.contains("private var rowFill"))
        #expect(overviewRowsSource.matches(of: /.contentShape\(Rectangle\(\)\)/).count >= 2)
    }

    @Test func `talk speakerphone persistence is reducer effect owned`() throws {
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let sessionKeySource = try String(contentsOf: Self.sessionKeySourceURL(), encoding: .utf8)
        let talkSource = try String(contentsOf: Self.talkProTabSourceURL(), encoding: .utf8)
        let speakerphoneBinding = try Self.extract(
            talkSource,
            from: "private var talkSpeakerphoneBinding: Binding<Bool>",
            to: "private func handlePrimaryAction()")
        let talkActionFunctions = try Self.extract(
            talkSource,
            from: "private func alignPersistedTalkState()",
            to: "private var permissionPromptBinding: Binding<Bool>")

        #expect(sessionKeySource.contains("struct ChatSessionKey: Equatable, Sendable"))
        #expect(talkSource.contains("var startTalk: @MainActor @Sendable (ChatSessionKey?) -> Void"))
        #expect(talkSource.contains("struct TalkProTabClient: Sendable"))
        #expect(talkSource.contains("var talkProTab: TalkProTabClient"))
        #expect(talkSource.contains("@Dependency(\\.talkProTab)"))
        #expect(talkSource.contains("struct GatewayConnectionStatus: Equatable, Sendable"))
        #expect(talkSource.contains("struct GatewayConnectionChange: Equatable, Sendable"))
        #expect(talkSource.contains("struct GatewayConnectionChange: Equatable, Sendable { var status: GatewayConnectionStatus }"))
        #expect(talkSource.contains("struct SpeakerphoneEnabled: Equatable, Sendable"))
        #expect(talkSource.contains("struct SpeakerphoneEnabledChange: Equatable, Sendable"))
        #expect(talkSource.contains("struct SpeakerphoneEnabledChange: Equatable, Sendable { var enabled: SpeakerphoneEnabled }"))
        #expect(talkSource.contains("struct StartTalkRequest: Equatable, Sendable"))
        #expect(talkSource.contains("struct StartTalkRequest: Equatable, Sendable { var sessionKey: ChatSessionKey? }"))
        #expect(talkSource.contains("struct TalkEnabled: Equatable, Sendable"))
        #expect(talkSource.contains("struct TalkEnabledChange: Equatable, Sendable"))
        #expect(talkSource.contains("struct TalkEnabledChange: Equatable, Sendable { var enabled: TalkEnabled }"))
        #expect(talkSource.contains("struct TalkProGatewayConnectionState: Equatable, Sendable"))
        #expect(talkSource.contains("struct TalkProSpeakerphoneState: Equatable, Sendable"))
        #expect(talkSource.contains("struct TalkProEnabledState: Equatable, Sendable"))
        #expect(talkSource.contains("enum Destination: Equatable, Sendable"))
        #expect(talkSource.contains("var destination: Destination?"))
        #expect(talkSource.contains("var gatewayConnectionState = TalkProGatewayConnectionState(isConnected: false)"))
        #expect(talkSource.contains(
            "var speakerphoneState = TalkProSpeakerphoneState(isEnabled: TalkDefaults.speakerphoneEnabledByDefault)"))
        #expect(talkSource.contains("var talkEnabledState = TalkProEnabledState(isEnabled: false)"))
        #expect(talkSource.contains("var gatewayConnected: Bool"))
        #expect(talkSource.contains("self.gatewayConnectionState.isConnected"))
        #expect(talkSource.contains("var speakerphoneEnabled: Bool"))
        #expect(talkSource.contains("self.speakerphoneState.isEnabled"))
        #expect(talkSource.contains("var talkEnabled: Bool"))
        #expect(talkSource.contains("self.talkEnabledState.isEnabled"))
        #expect(talkSource.contains("state.destination = .permissionPrompt"))
        #expect(talkSource.contains("state.destination = .talkIssueDetails"))
        #expect(talkSource.contains("case gatewayConnectionChanged(GatewayConnectionChange)"))
        #expect(talkSource.contains("case speakerphoneEnabledChanged(SpeakerphoneEnabledChange)"))
        #expect(talkSource.contains("case startTalkRequested(StartTalkRequest)"))
        #expect(talkSource.contains("case talkEnabledChanged(TalkEnabledChange)"))
        #expect(talkSource.contains("state.gatewayConnectionState = .init(isConnected: change.status.isConnected)"))
        #expect(talkSource.contains("state.speakerphoneState = .init(isEnabled: change.enabled.isEnabled)"))
        #expect(talkSource.contains("state.talkEnabledState = .init(isEnabled: true)"))
        #expect(talkSource.contains("state.talkEnabledState = .init(isEnabled: change.enabled.isEnabled)"))
        #expect(talkSource.contains("await client.setSpeakerphoneEnabled(change.enabled.isEnabled)"))
        #expect(talkSource.contains("await client.startTalk(request.sessionKey)"))
        #expect(!talkSource.contains("let sessionKey = ChatSessionKey(rawValue: request.sessionKey)"))
        #expect(talkSource.contains("await client.setTalkEnabled(change.enabled.isEnabled)"))
        #expect(rootSource.contains("store: self.makeTalkProTabStore()"))
        #expect(storesSource.contains("func makeTalkProTabStore()"))
        #expect(storesSource.contains("TalkProTabFeature(client: .live(appModel: self.appModel))"))
        #expect(talkSource.contains("self.store.send(.gatewayConnectionChanged(.init(status: .init(isConnected: connected))))"))
        #expect(speakerphoneBinding.contains("self.talkSpeakerphoneEnabled = enabled"))
        #expect(speakerphoneBinding.contains(
            "self.store.send(.speakerphoneEnabledChanged(.init(enabled: .init(isEnabled: enabled))))"))
        #expect(!speakerphoneBinding.contains("self.appModel.setTalkSpeakerphoneEnabled"))
        #expect(talkActionFunctions.contains(
            "self.store.send(.talkEnabledChanged(.init(enabled: .init(isEnabled: self.talkEnabled))))"))
        #expect(talkActionFunctions
            .contains("self.store.send(.startTalkRequested(.init(sessionKey: ChatSessionKey(rawValue: self.appModel.chatSessionKey))))"))
        #expect(talkActionFunctions.contains(
            "self.store.send(.talkEnabledChanged(.init(enabled: .init(isEnabled: false))))"))
        #expect(!talkActionFunctions.contains("self.appModel.setTalkEnabled"))
        #expect(!talkSource.contains("var showPermissionPrompt = false"))
        #expect(!talkSource.contains("var showTalkIssueDetails = false"))
        #expect(!talkSource.contains("var gatewayConnected = false"))
        #expect(!talkSource.contains("var speakerphoneEnabled = TalkDefaults.speakerphoneEnabledByDefault"))
        #expect(!talkSource.contains("var talkEnabled = false"))
        #expect(!talkSource.contains("state.gatewayConnected = change.status.isConnected"))
        #expect(!talkSource.contains("state.speakerphoneEnabled = change.enabled.isEnabled"))
        #expect(!talkSource.contains("state.talkEnabled = true"))
        #expect(!talkSource.contains("state.talkEnabled = change.enabled.isEnabled"))
    }

    @Test func `agent row selection is reducer effect owned`() throws {
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let agentModelsSource = try String(contentsOf: Self.agentProModelsSourceURL(), encoding: .utf8)
        let agentSource = try String(contentsOf: Self.agentProTabSourceURL(), encoding: .utf8)
        let agentOverviewSource = try String(contentsOf: Self.agentProTabOverviewSourceURL(), encoding: .utf8)
        let phoneControlHubSource = try String(contentsOf: Self.phoneHubSourceURL(), encoding: .utf8)

        #expect(agentModelsSource.contains("struct SelectedAgentID: Equatable, Sendable"))
        #expect(agentModelsSource.contains("var normalized: SelectedAgentID?"))
        #expect(agentSource.contains("var setSelectedAgentId: @MainActor @Sendable (SelectedAgentID) -> Void"))
        #expect(agentSource.contains("struct AgentSelectionClient: Sendable"))
        #expect(agentSource.contains("var agentSelection: AgentSelectionClient"))
        #expect(agentSource.contains("struct AgentSelectionFeature"))
        #expect(agentSource.contains("struct AgentSelection: Equatable, Sendable"))
        #expect(agentSource.contains("var agentId: SelectedAgentID"))
        #expect(agentSource.contains("case agentSelected(AgentSelection)"))
        #expect(!agentSource.contains("var agentId: String"))
        #expect(agentSource.contains("await selectionClient.setSelectedAgentId(selection.agentId)"))
        #expect(
            agentOverviewSource.contains(
                "self.selectionStore.send(.agentSelected(.init(agentId: .init(value: agent.id))))"))
        #expect(!agentOverviewSource.contains("self.appModel.setSelectedAgentId(agent.id)"))
        #expect(storesSource.contains("func makeAgentSelectionStore()"))
        #expect(storesSource.contains("AgentSelectionFeature(selectionClient: .live(appModel: self.appModel))"))
        #expect(rootSource.matches(of: /selectionStore: self\.makeAgentSelectionStore\(\)/).count >= 5)
        #expect(phoneControlHubSource.contains("private func makeAgentSelectionStore()"))
        #expect(phoneControlHubSource.matches(of: /selectionStore: self\.makeAgentSelectionStore\(\)/).count >= 4)
    }

    @Test func `chat talk toggle is reducer effect owned`() throws {
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let sessionKeySource = try String(contentsOf: Self.sessionKeySourceURL(), encoding: .utf8)
        let chatSource = try String(contentsOf: Self.chatProTabSourceURL(), encoding: .utf8)

        #expect(sessionKeySource.contains("struct ChatSessionKey: Equatable, Sendable"))
        #expect(chatSource.contains("var focusChatSession: @MainActor @Sendable (ChatSessionKey?) -> Void"))
        #expect(chatSource.contains("struct ChatTalkControlClient: Sendable"))
        #expect(chatSource.contains("var chatTalkControl: ChatTalkControlClient"))
        #expect(chatSource.contains("struct ChatTalkControlFeature"))
        #expect(chatSource.contains("struct ToggleRequest: Equatable, Sendable"))
        #expect(chatSource.contains("struct TalkEnabled: Equatable, Sendable"))
        #expect(chatSource.contains("var sessionKey: ChatSessionKey?"))
        #expect(chatSource.contains("var talkEnabled: TalkEnabled"))
        #expect(chatSource.contains("case toggleRequested(ToggleRequest)"))
        #expect(chatSource.contains("await client.focusChatSession(request.sessionKey)"))
        #expect(chatSource.contains("await client.setTalkEnabled(!request.talkEnabled.isEnabled)"))
        #expect(chatSource.contains("self.talkControlStore.send(.toggleRequested(.init("))
        #expect(chatSource.contains("sessionKey: ChatSessionKey(rawValue: sessionKey)"))
        #expect(chatSource.contains("talkEnabled: .init(isEnabled: self.appModel.talkMode.isEnabled)"))
        #expect(!chatSource.contains("let sessionKey = ChatSessionKey(rawValue: request.sessionKey)"))
        #expect(!chatSource.contains("isTalkEnabled: self.appModel.talkMode.isEnabled"))
        #expect(!chatSource.contains("self.appModel.setTalkEnabled(!self.appModel.talkMode.isEnabled)"))
        #expect(storesSource.contains("func makeChatTalkControlStore()"))
        #expect(storesSource.contains("ChatTalkControlFeature(client: .live(appModel: self.appModel))"))
        #expect(rootSource.matches(of: /talkControlStore: self\.makeChatTalkControlStore\(\)/).count == 2)
    }

    @Test func `root gateway problem primary action is reducer effect owned`() throws {
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let featureSource = try String(contentsOf: Self.rootGatewayProblemPrimaryActionSourceURL(), encoding: .utf8)
        let actionFunction = try Self.extract(
            rootSource,
            from: "private func handleGatewayProblemPrimaryAction(_ problem: GatewayConnectionProblem) async",
            to: "private func evaluateOnboardingPresentation")

        #expect(featureSource.contains("struct RootGatewayProblemPrimaryActionClient"))
        #expect(featureSource.contains("var rootGatewayProblemPrimaryAction: RootGatewayProblemPrimaryActionClient"))
        #expect(featureSource.contains("@Reducer\nstruct RootGatewayProblemPrimaryActionFeature"))
        #expect(featureSource.contains("static func title(for problem: GatewayConnectionProblem) -> String?"))
        #expect(featureSource.contains("GatewayProblemPrimaryAction.title("))
        #expect(featureSource.contains("nonRetryableTitle: \"Open Settings\""))
        #expect(featureSource.contains("struct PrimaryActionRequest: Equatable, Sendable"))
        #expect(featureSource.contains("case primaryActionTapped(PrimaryActionRequest)"))
        #expect(featureSource.contains("@Dependency(\\.rootGatewayProblemPrimaryAction)"))
        #expect(featureSource.contains("await client.trustRotatedCertificate(problem)"))
        #expect(featureSource.contains("await client.openProtocolMismatchHelpIfNeeded(problem)"))
        #expect(featureSource.contains("await client.connectLastKnown()"))
        #expect(featureSource.contains("await client.openGatewaySettings()"))
        #expect(storesSource.contains("func makeGatewayProblemPrimaryActionStore()"))
        #expect(rootSource.contains("Task { await self.handleGatewayProblemPrimaryAction(gatewayProblem) }"))
        #expect(rootSource.contains("RootGatewayProblemPrimaryActionFeature.title(for: problem)"))
        #expect(!rootSource.contains("GatewayProblemPrimaryAction.title("))
        #expect(actionFunction.contains(".send(.primaryActionTapped(.init(problem: problem)))"))
        #expect(!actionFunction.contains("self.gatewayController.trustRotatedGatewayCertificate"))
        #expect(!actionFunction.contains("self.gatewayController.connectLastKnown"))
        #expect(!actionFunction.contains("self.selectSidebarDestination(.gateway)"))
    }

    @Test func `root gateway overview scene refresh is reducer effect owned`() throws {
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let featureSource = try String(contentsOf: Self.rootGatewayOverviewRefreshSourceURL(), encoding: .utf8)
        let refreshFunction = try Self.extract(
            rootSource,
            from: "private func refreshGatewayOverviewAfterSceneActivation() async",
            to: "private func rootAppearLifecycle")

        #expect(featureSource.contains("struct RootGatewayOverviewRefreshClient"))
        #expect(featureSource.contains("var rootGatewayOverviewRefresh: RootGatewayOverviewRefreshClient"))
        #expect(featureSource.contains("@Reducer\nstruct RootGatewayOverviewRefreshFeature"))
        #expect(featureSource.contains("case sceneActiveRefreshRequested"))
        #expect(featureSource.contains("@Dependency(\\.rootGatewayOverviewRefresh)"))
        #expect(featureSource.contains("await client.refreshGatewayOverviewIfConnected()"))
        #expect(storesSource.contains("func makeGatewayOverviewRefreshStore()"))
        #expect(rootSource.contains("Task { await self.refreshGatewayOverviewAfterSceneActivation() }"))
        #expect(refreshFunction.contains(".send(.sceneActiveRefreshRequested)"))
        #expect(refreshFunction.contains("self.updateHomeCanvasState()"))
        #expect(!refreshFunction.contains("await self.appModel.refreshGatewayOverviewIfConnected()"))
    }

    @Test func `root canvas close action is reducer effect owned`() throws {
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let featureSource = try String(contentsOf: Self.rootCanvasPresentationSourceURL(), encoding: .utf8)
        let closeFunction = try Self.extract(
            rootSource,
            from: "private func closeCanvasPresentation() async",
            to: "private var voiceWakeToastAnimation")

        #expect(featureSource.contains("struct RootCanvasPresentationClient"))
        #expect(featureSource.contains("var rootCanvasPresentation: RootCanvasPresentationClient"))
        #expect(featureSource.contains("@Reducer\nstruct RootCanvasPresentationFeature"))
        #expect(featureSource.contains("case closeButtonTapped"))
        #expect(featureSource.contains("@Dependency(\\.rootCanvasPresentation)"))
        #expect(featureSource.contains("await client.hideCanvas()"))
        #expect(storesSource.contains("func makeCanvasPresentationStore()"))
        #expect(rootSource.contains("Task { await self.closeCanvasPresentation() }"))
        #expect(closeFunction.contains(".send(.closeButtonTapped)"))
        #expect(!closeFunction.contains("self.appModel.screen.hideCanvas()"))
        #expect(!rootSource.contains("Button {\n                self.appModel.screen.hideCanvas()"))
    }

    @Test func `root canvas debug status is reducer effect owned`() throws {
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let featureSource = try String(contentsOf: Self.rootCanvasDebugStatusSourceURL(), encoding: .utf8)
        let updateFunction = try Self.extract(
            rootSource,
            from: "private func updateCanvasDebugStatus()",
            to: "private func applyCanvasDebugStatus() async")
        let applyFunction = try Self.extract(
            rootSource,
            from: "private func applyCanvasDebugStatus() async",
            to: "private func makeCanvasDebugStatusSnapshot()")

        #expect(featureSource.contains("struct RootCanvasDebugStatusClient"))
        #expect(featureSource.contains("struct Update: Equatable, Sendable"))
        #expect(featureSource.contains("var rootCanvasDebugStatus: RootCanvasDebugStatusClient"))
        #expect(featureSource.contains("@Reducer\nstruct RootCanvasDebugStatusFeature"))
        #expect(featureSource.contains("extension RootCanvasDebugStatusFeature.Snapshot"))
        #expect(featureSource.contains("struct DebugStatusEnabled: Equatable, Sendable"))
        #expect(featureSource.contains("var enabled: DebugStatusEnabled"))
        #expect(featureSource.contains(
            "init(appModel: NodeAppModel, enabled: RootCanvasDebugStatusFeature.DebugStatusEnabled)"))
        #expect(featureSource.contains("gatewayDisplayStatusText: appModel.gatewayDisplayStatusText"))
        #expect(featureSource.contains("case snapshotChanged(Snapshot)"))
        #expect(featureSource.contains("await client.setDebugStatusEnabled(snapshot.enabled.isEnabled)"))
        #expect(featureSource.contains("guard snapshot.enabled.isEnabled else { return }"))
        #expect(featureSource.contains("await client.updateDebugStatus(.init(title: title, subtitle: subtitle))"))
        #expect(!featureSource.contains("struct Snapshot: Equatable, Sendable {\n        var isEnabled: Bool"))
        #expect(!featureSource.contains("await client.setDebugStatusEnabled(snapshot.isEnabled)"))
        #expect(storesSource.contains("func makeCanvasDebugStatusStore()"))
        #expect(storesSource.contains("RootCanvasDebugStatusFeature(client: .live(appModel: self.appModel))"))
        #expect(rootSource.contains(".send(.snapshotChanged(self.makeCanvasDebugStatusSnapshot()))"))
        #expect(rootSource.contains("RootCanvasDebugStatusFeature.Snapshot(\n            appModel: self.appModel"))
        #expect(rootSource.contains("enabled: .init(isEnabled: self.canvasDebugStatusEnabled)"))
        #expect(!rootSource.contains("gatewayDisplayStatusText: self.appModel.gatewayDisplayStatusText"))
        #expect(updateFunction.contains("Task { await self.applyCanvasDebugStatus() }"))
        #expect(!updateFunction.contains("self.appModel.screen.setDebugStatusEnabled"))
        #expect(!updateFunction.contains("self.appModel.screen.updateDebugStatus"))
        #expect(applyFunction.contains(".send(.snapshotChanged(self.makeCanvasDebugStatusSnapshot()))"))
    }

    @Test func `root idle timer is reducer effect owned`() throws {
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let featureSource = try String(contentsOf: Self.rootIdleTimerSourceURL(), encoding: .utf8)
        let lifecycle = try Self.extract(
            rootSource,
            from: "private func rootAppearLifecycle",
            to: "private func rootGatewayLifecycle")
        let updateFunction = try Self.extract(
            rootSource,
            from: "private func updateIdleTimer()",
            to: "private func makeIdleTimerSnapshot()")

        #expect(featureSource.contains("struct RootIdleTimerClient"))
        #expect(featureSource.contains("var rootIdleTimer: RootIdleTimerClient"))
        #expect(featureSource.contains("@Reducer\nstruct RootIdleTimerFeature"))
        #expect(featureSource.contains("extension RootIdleTimerFeature.Snapshot"))
        #expect(featureSource.contains("struct SceneActivity: Equatable, Sendable"))
        #expect(featureSource.contains("struct PreventSleepPreference: Equatable, Sendable"))
        #expect(featureSource.contains("struct TalkModeEnabled: Equatable, Sendable"))
        #expect(featureSource.contains("var sceneActivity: SceneActivity"))
        #expect(featureSource.contains("var preventSleep: PreventSleepPreference"))
        #expect(featureSource.contains("var talkMode: TalkModeEnabled"))
        #expect(featureSource.contains(
            "preventSleep: RootIdleTimerFeature.PreventSleepPreference"))
        #expect(featureSource.contains("talkMode: RootIdleTimerFeature.TalkModeEnabled"))
        #expect(featureSource.contains("sceneActivity: .init(isActive: scenePhase == .active)"))
        #expect(featureSource.contains("case snapshotChanged(Snapshot)"))
        #expect(featureSource.contains("case disappeared"))
        #expect(featureSource.contains("snapshot.sceneActivity.isActive"))
        #expect(featureSource.contains("snapshot.preventSleep.isEnabled || snapshot.talkMode.isEnabled"))
        #expect(featureSource.contains("try Task.checkCancellation()"))
        #expect(featureSource.contains("await client.setIdleTimerDisabled(isDisabled)"))
        #expect(featureSource.contains("return .cancel(id: CancelID.idleTimer)"))
        #expect(featureSource.contains(".cancellable(id: CancelID.idleTimer, cancelInFlight: true)"))
        #expect(!featureSource.contains("struct Snapshot: Equatable, Sendable {\n        var isSceneActive: Bool"))
        #expect(!featureSource.contains("var talkModeEnabled: Bool"))
        #expect(rootSource.contains("@State private var idleTimerStore: StoreOf<RootIdleTimerFeature>"))
        #expect(rootSource.contains("RootIdleTimerFeature(client: .live)"))
        #expect(!rootSource.contains("Task { await self.applyIdleTimerSnapshot() }"))
        #expect(updateFunction.contains("self.idleTimerStore.send(.snapshotChanged(self.makeIdleTimerSnapshot()))"))
        #expect(rootSource.contains("RootIdleTimerFeature.Snapshot(\n            scenePhase: self.scenePhase"))
        #expect(rootSource.contains("preventSleep: .init(isEnabled: self.preventSleep)"))
        #expect(rootSource.contains("talkMode: .init(isEnabled: self.appModel.talkMode.isEnabled)"))
        #expect(!rootSource.contains("isSceneActive: self.scenePhase == .active"))
        #expect(!rootSource.contains("talkModeEnabled: self.appModel.talkMode.isEnabled"))
        #expect(!updateFunction.contains("UIApplication.shared.isIdleTimerDisabled"))
        #expect(lifecycle.contains(
            "self.idleTimerStore.send(.disappeared)\n                UIApplication.shared.isIdleTimerDisabled = false"))
        #expect(lifecycle.contains("UIApplication.shared.isIdleTimerDisabled = false"))
        #expect(rootSource.components(separatedBy: "UIApplication.shared.isIdleTimerDisabled").count == 2)
    }

    @Test func `root launch toast and camera flash reducers live outside root tabs`() throws {
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let launchSource = try String(contentsOf: Self.rootLaunchSourceURL(), encoding: .utf8)
        let voiceWakeToastSource = try String(contentsOf: Self.rootVoiceWakeToastSourceURL(), encoding: .utf8)
        let cameraFlashSource = try String(contentsOf: Self.rootCameraFlashOverlaySourceURL(), encoding: .utf8)

        #expect(launchSource.contains("@Reducer\nstruct RootLaunchFeature"))
        #expect(launchSource.contains("struct InitialAppearanceRequest: Equatable, Sendable"))
        #expect(launchSource.contains("var preference: AppAppearancePreference?"))
        #expect(launchSource.contains("case initialAppearanceRequested(InitialAppearanceRequest)"))
        #expect(rootSource.contains("RootLaunchFeature.InitialAppearanceRequest("))
        #expect(rootSource.contains("preference: AppAppearancePreference.launchArgumentPreference"))
        #expect(launchSource.contains("struct InitialChatSessionRequest: Equatable, Sendable"))
        #expect(launchSource.contains("case initialChatSessionRequested(InitialChatSessionRequest)"))
        #expect(rootSource.contains("RootLaunchFeature.InitialChatSessionRequest("))
        #expect(launchSource.contains("enum OneShotPhase: Equatable, Sendable"))
        #expect(launchSource.contains("var initialAppearancePhase = OneShotPhase.pending"))
        #expect(launchSource.contains("var initialChatSessionPhase = OneShotPhase.pending"))
        #expect(launchSource.contains("state.initialAppearancePhase = .applied"))
        #expect(launchSource.contains("state.initialChatSessionPhase = .applied"))
        #expect(launchSource.contains("struct ApplyAppearanceCommand: Equatable, Sendable"))
        #expect(launchSource.contains("var preference: AppAppearancePreference"))
        #expect(launchSource.contains("case applyAppearance(ApplyAppearanceCommand)"))
        #expect(rootSource.contains("self.appearancePreferenceRaw = command.preference.rawValue"))
        #expect(launchSource.contains("struct FocusChatSessionCommand: Equatable, Sendable"))
        #expect(launchSource.contains("case focusChatSession(FocusChatSessionCommand)"))
        #expect(voiceWakeToastSource.contains("@Reducer\nstruct RootVoiceWakeToastFeature"))
        #expect(voiceWakeToastSource.contains("struct CommandText: Equatable, Sendable"))
        #expect(voiceWakeToastSource.contains("struct CommandTrigger: Equatable, Sendable"))
        #expect(voiceWakeToastSource.contains("var commandText: CommandText?"))
        #expect(voiceWakeToastSource.contains("case commandTriggered(CommandTrigger)"))
        #expect(rootSource.contains("RootVoiceWakeToastFeature.CommandTrigger(rawValue: newValue)"))
        #expect(voiceWakeToastSource.contains("struct RootVoiceWakeToastSleepClient"))
        #expect(voiceWakeToastSource.contains("var rootVoiceWakeToastSleep: RootVoiceWakeToastSleepClient"))
        #expect(cameraFlashSource.contains("struct RootCameraFlashOverlay: View"))
        #expect(cameraFlashSource.contains("@Reducer\nstruct RootCameraFlashOverlayFeature"))
        #expect(cameraFlashSource.contains("struct RootCameraFlashOverlaySleepClient"))
        #expect(cameraFlashSource.contains("var rootCameraFlashOverlaySleep: RootCameraFlashOverlaySleepClient"))
        #expect(rootSource.contains("@State private var launchStore: StoreOf<RootLaunchFeature>"))
        #expect(rootSource.contains("@State private var voiceWakeToastStore: StoreOf<RootVoiceWakeToastFeature>"))
        #expect(rootSource.contains("RootCameraFlashOverlay(nonce: self.appModel.cameraFlashNonce)"))
        #expect(!rootSource.contains("@Reducer\n"))
        #expect(!rootSource.contains("struct RootLaunchFeature"))
        #expect(!rootSource.contains("struct RootVoiceWakeToastFeature"))
        #expect(!rootSource.contains("struct RootCameraFlashOverlayFeature"))
        #expect(!rootSource.contains("struct RootVoiceWakeToastSleepClient"))
        #expect(!rootSource.contains("struct RootCameraFlashOverlaySleepClient"))
        #expect(!launchSource.contains("var didApplyInitialAppearance = false"))
        #expect(!launchSource.contains("var didApplyInitialChatSession = false"))
    }

    @Test func `root tca store factories live outside root tabs`() throws {
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)

        #expect(storesSource.contains("extension RootTabs"))
        #expect(storesSource.contains("func makeGatewayQuickSetupStore()"))
        #expect(storesSource.contains("func makeSettingsGatewayActivityStore()"))
        #expect(storesSource.contains("func makeNotificationPermissionGuidanceStore()"))
        #expect(storesSource.contains("withDependencies"))
        #expect(storesSource.contains("openNotifications: { approvalId in"))
        #expect(rootSource.contains("GatewayQuickSetupSheet(store: self.makeGatewayQuickSetupStore())"))
        #expect(rootSource.contains("store: self.makeTalkProTabStore()"))
        #expect(rootSource.contains("execApprovalPromptStore: self.makeExecApprovalPromptStore()"))
        #expect(!rootSource.contains("func makeGatewayQuickSetupStore()"))
        #expect(!rootSource.contains("func makeSettingsGatewayActivityStore()"))
        #expect(!rootSource.contains("func makeNotificationPermissionGuidanceStore()"))
        #expect(!rootSource.contains("withDependencies"))
    }

    @Test func `gateway quick setup response action is typed`() throws {
        let quickSetupSource = try String(contentsOf: Self.gatewayQuickSetupSourceURL(), encoding: .utf8)

        #expect(quickSetupSource.contains("struct GatewayQuickSetupConnectFailureMessage: Equatable, Sendable"))
        #expect(quickSetupSource.contains("struct GatewayQuickSetupConnectFailure: Equatable, Sendable"))
        #expect(quickSetupSource.contains("var message: GatewayQuickSetupConnectFailureMessage"))
        #expect(quickSetupSource.contains("var connect: @Sendable @MainActor"))
        #expect(quickSetupSource.contains("-> GatewayQuickSetupConnectFailure?"))
        #expect(quickSetupSource.contains("struct ConnectResponse: Equatable, Sendable"))
        #expect(quickSetupSource.contains("var failure: GatewayQuickSetupConnectFailure?"))
        #expect(quickSetupSource.contains("case connectResponse(ConnectResponse)"))
        #expect(quickSetupSource.contains("enum ConnectPhase: Equatable, Sendable"))
        #expect(quickSetupSource.contains("case failed(GatewayQuickSetupConnectFailureMessage)"))
        #expect(quickSetupSource.contains("var connectPhase = ConnectPhase.idle"))
        #expect(quickSetupSource.contains("state.connectPhase = response.failure.map { .failed($0.message) } ?? .idle"))
        #expect(quickSetupSource.contains("state.connectPhase = .inFlight"))
        #expect(quickSetupSource.contains("let result = await gatewayController.connectWithDiagnostics(candidate)"))
        #expect(quickSetupSource.contains("return result.failure.map { .init(message: .init(value: $0.message)) }"))
        #expect(quickSetupSource.contains("let failure = await client.connect(candidate)"))
        #expect(quickSetupSource.contains("await send(.connectResponse(.init(failure: failure)))"))
        #expect(!quickSetupSource.contains("async -> String?"))
        #expect(!quickSetupSource.contains("struct GatewayQuickSetupConnectFailure: Equatable {\n    var message: String"))
        #expect(!quickSetupSource.contains("struct ConnectFailure:"))
        #expect(!quickSetupSource.contains("struct ConnectResponse: Equatable, Sendable { var error: String? }"))
        #expect(!quickSetupSource.contains("var connecting = false"))
        #expect(!quickSetupSource.contains("var connectError: String?\n"))
        #expect(!quickSetupSource.contains("state.connectError = response.failure?.message.value"))
    }

    @Test func `gateway quick setup connect action is typed`() throws {
        let quickSetupSource = try String(contentsOf: Self.gatewayQuickSetupSourceURL(), encoding: .utf8)

        #expect(quickSetupSource.contains("struct ConnectRequest: Equatable, Sendable"))
        #expect(quickSetupSource.contains("case connectButtonTapped(ConnectRequest)"))
        #expect(quickSetupSource.contains("request.candidate"))
        #expect(quickSetupSource.contains("self.store.send(.connectButtonTapped(.init(candidate: candidate)))"))
    }

    @Test func `gateway quick setup problem primary action is typed`() throws {
        let quickSetupSource = try String(contentsOf: Self.gatewayQuickSetupSourceURL(), encoding: .utf8)

        #expect(quickSetupSource.contains("enum Destination: Equatable, Sendable"))
        #expect(quickSetupSource.contains("var destination: Destination?"))
        #expect(quickSetupSource.contains("state.destination = .gatewayProblemDetails"))
        #expect(quickSetupSource.contains("struct GatewayProblemPrimaryAction: Equatable, Sendable"))
        #expect(quickSetupSource.contains("case gatewayProblemPrimaryActionTapped(GatewayProblemPrimaryAction)"))
        #expect(quickSetupSource.contains("action.problem.canTrustRotatedCertificate"))
        #expect(quickSetupSource.contains("let candidate = action.candidate"))
        #expect(quickSetupSource.contains("self.store.send(.gatewayProblemPrimaryActionTapped(.init("))
        #expect(!quickSetupSource.contains("var showGatewayProblemDetails = false"))
    }

    @Test func `voice wake trigger word change action is typed`() throws {
        let source = try String(contentsOf: Self.voiceWakeWordsSettingsSourceURL(), encoding: .utf8)

        #expect(source.contains("struct TriggerWordChange: Equatable, Sendable"))
        #expect(source.contains("case triggerWordChanged(TriggerWordChange)"))
        #expect(source.contains("state.triggerWords[change.index] = change.value"))
        #expect(source.contains(
            "self.store.send(.triggerWordChanged(.init(index: index, value: newValue)))"))
    }

    @Test func `voice wake focus change action is typed`() throws {
        let source = try String(contentsOf: Self.voiceWakeWordsSettingsSourceURL(), encoding: .utf8)

        #expect(source.contains("struct FocusedTriggerIndexChange: Equatable, Sendable"))
        #expect(source.contains("case focusedTriggerIndexChanged(FocusedTriggerIndexChange)"))
        #expect(source.contains("state.focusedTriggerIndex = change.index"))
        #expect(source.contains("self.store.send(.focusedTriggerIndexChanged(.init(index: newValue)))"))
    }

    @Test func `voice wake word removal action is typed`() throws {
        let source = try String(contentsOf: Self.voiceWakeWordsSettingsSourceURL(), encoding: .utf8)

        #expect(source.contains("struct WordRemoval: Equatable, Sendable"))
        #expect(source.contains("case removeWords(WordRemoval)"))
        #expect(source.contains("state.triggerWords.remove(atOffsets: removal.offsets)"))
        #expect(source.contains("self.store.send(.removeWords(.init(offsets: offsets)))"))
    }

    @Test func `privacy permission request completion action is typed`() throws {
        let source = try String(contentsOf: Self.privacyAccessSectionSourceURL(), encoding: .utf8)

        #expect(source.contains("struct PermissionRequestCompletion: Equatable, Sendable"))
        #expect(source.contains("case permissionRequestFinished(PermissionRequestCompletion)"))
        #expect(source.contains("state.apply(completion.snapshot)"))
        #expect(source.contains("state.applyGranted(completion.permission)"))
        #expect(source.contains("await send(.permissionRequestFinished(.init("))
    }

    @Test func `privacy snapshot load action is typed`() throws {
        let source = try String(contentsOf: Self.privacyAccessSectionSourceURL(), encoding: .utf8)

        #expect(source.contains("struct SnapshotLoad: Equatable, Sendable"))
        #expect(source.contains("case snapshotLoaded(SnapshotLoad)"))
        #expect(source.contains("state.apply(load.snapshot)"))
        #expect(source.contains("await send(.snapshotLoaded(.init(snapshot: client.snapshot())))"))
    }

    @Test func `routed headers use shared adaptive layout`() throws {
        let componentsSource = try String(contentsOf: Self.proComponentsSourceURL(), encoding: .utf8)
        let featureChromeSource = try String(contentsOf: Self.iPadSidebarScreenChromeSourceURL(), encoding: .utf8)
        let docsSource = try String(contentsOf: Self.docsSourceURL(), encoding: .utf8)
        let overviewSource = try String(contentsOf: Self.commandCenterSourceURL(), encoding: .utf8)
        let chatSource = try String(contentsOf: Self.chatProTabSourceURL(), encoding: .utf8)
        let agentOverviewSource = try String(contentsOf: Self.agentProTabOverviewSourceURL(), encoding: .utf8)
        let settingsSource = try String(contentsOf: Self.settingsProTabSectionsSourceURL(), encoding: .utf8)

        #expect(componentsSource.contains("struct OpenClawAdaptiveHeaderRow<Leading: View, Accessory: View>: View"))
        #expect(componentsSource.contains("ViewThatFits(in: .horizontal)"))
        #expect(componentsSource.contains("private var stackedLayout: some View"))
        #expect(componentsSource.contains(".layoutPriority(1)"))
        #expect(componentsSource.contains(".fixedSize(horizontal: true, vertical: false)"))
        #expect(featureChromeSource.contains("OpenClawAdaptiveHeaderRow("))
        #expect(docsSource.contains("OpenClawAdaptiveHeaderRow("))
        #expect(overviewSource.contains("OpenClawAdaptiveHeaderRow("))
        #expect(chatSource.contains("OpenClawAdaptiveHeaderRow("))
        #expect(agentOverviewSource.contains("OpenClawAdaptiveHeaderRow("))
        #expect(settingsSource.contains("OpenClawAdaptiveHeaderRow("))
    }

    @Test func `phone hub keeps docs as destination only`() throws {
        let source = try String(contentsOf: Self.phoneHubSourceURL(), encoding: .utf8)

        #expect(source.contains("case .docs:"))
        #expect(source.contains("OpenClawDocsScreen("))
        #expect(source.contains("headerLeadingAction: self.phoneDetailBackAction"))
        #expect(source.contains("gatewayAction: { self.openPhoneRootDestination(.gateway) }"))
        #expect(!source.contains("Label(\"Docs\", systemImage: \"book\")"))
        #expect(!source.contains("https://docs.openclaw.ai"))
    }

    @Test func `root shell preview matrix covers phone and I pad states`() throws {
        let source = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)

        #expect(source.contains("#Preview(\n    \"Shell iPhone portrait\""))
        #expect(source.contains("#Preview(\n    \"Shell iPhone landscape\""))
        #expect(source.contains("#Preview(\n    \"Shell iPhone connected\""))
        #expect(source.contains("#Preview(\n    \"Shell iPhone gateway error\""))
        #expect(source.contains("#Preview(\n    \"Shell iPad portrait drawer\""))
        #expect(source.contains("#Preview(\n    \"Shell iPad landscape split\""))
        #expect(source.contains("#Preview(\n    \"Shell iPad connecting\""))
        #expect(source.contains("#Preview(\n    \"Shell iPad gateway error\""))
    }

    @Test func `shared chat preview matrix covers connection states`() throws {
        let source = try String(contentsOf: Self.sharedChatPreviewSourceURL(), encoding: .utf8)

        #expect(source.contains("#Preview(\"Chat connected\")"))
        #expect(source.contains("#Preview(\"Chat empty\")"))
        #expect(source.contains("#Preview(\"Chat loading\")"))
        #expect(source.contains("#Preview(\"Chat gateway error\")"))
        #expect(source.contains("enum Scenario"))
        #expect(source.contains("case connected"))
        #expect(source.contains("case empty"))
        #expect(source.contains("case loading"))
        #expect(source.contains("case error"))
        #expect(source.contains("Gateway not connected. Check Tailscale and retry."))
    }

    @Test func `phone hub keeps content above floating tab bar`() throws {
        let source = try String(contentsOf: Self.phoneHubSourceURL(), encoding: .utf8)

        #expect(source.contains(".safeAreaPadding(.bottom, self.bottomScrollInset)"))
        #expect(!source.contains(".padding(.bottom, self.bottomScrollInset)"))
        #expect(!source.contains("bottomViewportInset"))
        #expect(!source.contains("bottomTabBarClearance"))
    }

    @Test func `phone hub header stays task first`() throws {
        let source = try String(contentsOf: Self.phoneHubSourceURL(), encoding: .utf8)

        #expect(source.contains("private var headerCard: some View"))
        #expect(source.contains(".accessibilityLabel(\"Gateway \\(presentation.gatewayStateText)\")"))
        #expect(!source.contains("private var gatewayActionRow: some View"))
        #expect(!source.contains("ProValuePill(value: self.gatewayStateText"))
        #expect(!source.contains("destination.subtitle"))
        #expect(source.contains("self.openPhoneRootDestination(.gateway)"))
        #expect(source.contains("private var phoneDetailBackAction: OpenClawSidebarHeaderAction"))
        #expect(source.contains("accessibilityLabel: \"Back to Control\""))
        #expect(source.contains("accessibilityIdentifier: \"OpenClawPhoneDetailBackButton\""))
        #expect(source.contains(".navigationBarBackButtonHidden(true)"))
        #expect(source.contains(".toolbar(.hidden, for: .navigationBar)"))
        #expect(source.matches(of: /headerLeadingAction: self\.phoneDetailBackAction/).count == 10)
        #expect(!source.contains("directRoute: .agents"))
        #expect(!source.contains("ToolbarItem(placement: .topBarTrailing)"))
        #expect(!source.contains("Image(systemName: \"gearshape\")"))
        #expect(!source.contains("self.metric(label:"))
        #expect(!source.contains("private func metric(label:"))
    }

    @Test func `phone hub clears detail path before root tab handoff`() throws {
        let source = try String(contentsOf: Self.phoneHubSourceURL(), encoding: .utf8)
        let handoff = try Self.extract(
            source,
            from: "private func openPhoneRootDestination(_ destination: RootTabs.SidebarDestination)",
            to: "private func opensRootTab(_ destination: RootTabs.SidebarDestination)")
        let clearRange = try #require(handoff.range(of: "self.store.send(.rootDestinationTapped(destination))"))
        let openRange = try #require(handoff.range(of: "self.openRootDestination(destination)"))

        #expect(source.contains("NavigationStack(path: self.navigationPathBinding)"))
        #expect(source.contains("enum InitialDestinationAppearance: Equatable, Sendable"))
        #expect(source.contains("case detail(RootTabs.SidebarDestination)"))
        #expect(source.contains("case rootTab(RootTabs.SidebarDestination)"))
        #expect(!source.contains("var opensRootTab: Bool"))
        #expect(source.contains("case navigationPathChanged(NavigationPathChange)"))
        #expect(source.contains("set: { self.store.send(.navigationPathChanged(.init(path: $0))) }"))
        #expect(!source.contains("self.openRootDestination(.gateway)"))
        #expect(source.contains("self.openPhoneRootDestination(.gateway)"))
        #expect(clearRange.lowerBound < openRange.lowerBound)
    }

    @Test func `workboard uses real gateway methods`() throws {
        let source = try Self.iPadWorkboardSource()

        #expect(source.contains("workboard.cards.list"))
        #expect(source.contains("workboard.cards.create"))
        #expect(source.contains("workboard.cards.move"))
        #expect(source.contains("workboard.cards.archive"))
        #expect(source.contains("workboard.cards.dispatch"))
        #expect(source.contains(".padding(.bottom, 12)"))
        #expect(!source.contains("Workboard gateway contract unavailable"))
        #expect(!source.contains("supportsGatewayContract"))
        #expect(!source.contains("Compact mobile queue control"))
        #expect(!source.contains("Multi-column queue control"))
    }

    @Test func `workboard create action surfaces unavailable reasons`() throws {
        let source = try Self.iPadWorkboardSource()
        let createFunction = try Self.extract(
            source,
            from: "private func createCard() async",
            to: "private func move(_ card: IPadWorkboardCard, to status: String) async")

        #expect(source.contains("struct IPadWorkboardClient"))
        #expect(source.contains("@Reducer\nstruct IPadWorkboardFeature"))
        #expect(source.contains("enum IPadWorkboardStoreFactory"))
        #expect(source.contains("struct IPadWorkboardFailureMessage: Equatable, Sendable"))
        #expect(source.contains("var errorText: IPadWorkboardFailureMessage?"))
        #expect(source.contains("state.errorText = .init(value: error.message)"))
        #expect(source.contains("state.errorText = .init(value: message)"))
        #expect(source.contains("Text(errorText.value)"))
        #expect(!source.contains("var errorText: String?"))
        #expect(source.contains(
            "struct Failure: Equatable, Sendable { var message: IPadWorkboardFailureMessage }"))
        #expect(source.contains("case failed(Failure)"))
        #expect(source.contains("private static func failure(for error: Error) -> IPadWorkboardError"))
        #expect(source.contains(".failed(.init(message: .init(value: self.message(for: error))))"))
        #expect(source.contains("failure.message.value"))
        #expect(source.contains("result: .failure(Self.failure(for: error))"))
        #expect(!source.contains("struct Failure: Equatable, Sendable { var message: String }"))
        #expect(!source.contains("case failed(String)"))
        #expect(!source.contains("@State private var selectedStatus"))
        #expect(source.contains("struct IPadWorkboardSelectedStatus: Equatable, Sendable"))
        #expect(source.contains("var selectedStatus = IPadWorkboardSelectedStatus(value: \"active\")"))
        #expect(source.contains("self.selectedStatus.value == \"active\""))
        #expect(source.contains("selectedStatus: self.selectedStatus.value"))
        #expect(source.contains("state.selectedStatus = .init(value: \"active\")"))
        #expect(!source.contains("var selectedStatus = \"active\""))
        #expect(!source.contains("@State private var selectedBoardID"))
        #expect(!source.contains("@State private var query"))
        #expect(source.contains("var query = IPadWorkboardQuery(value: \"\")"))
        #expect(source.contains("query: self.query.value"))
        #expect(source.contains("state.query = change.query"))
        #expect(source.contains("state.query = .init(value: \"\")"))
        #expect(source.contains("get: { self.store.query.value }"))
        #expect(source.contains("if !self.store.query.value.isEmpty"))
        #expect(!source.contains("var query = \"\""))
        #expect(source.contains("var draftTitle = IPadWorkboardDraftTitle(value: \"\")"))
        #expect(source.contains("var draftNotes = IPadWorkboardDraftNotes(value: \"\")"))
        #expect(source.contains("self.draftTitle.value.trimmingCharacters(in: .whitespacesAndNewlines)"))
        #expect(source.contains("notes: state.draftNotes.value.trimmingCharacters(in: .whitespacesAndNewlines)"))
        #expect(source.contains("get: { self.store.draftTitle.value }"))
        #expect(source.contains("get: { self.store.draftNotes.value }"))
        #expect(!source.contains("var draftTitle = \"\""))
        #expect(!source.contains("var draftNotes = \"\""))
        #expect(!source.contains("@State private var presentedSheet"))
        #expect(!source.contains("@State private var cards"))
        #expect(!source.contains("@State private var statuses"))
        #expect(source.contains("struct IPadWorkboardStatus: Equatable, Sendable"))
        #expect(source.contains("var statuses: [IPadWorkboardStatus] = IPadWorkboardDefaults.statuses.map"))
        #expect(source.contains("var statusValues: [String]"))
        #expect(source.contains("self.store.statusValues"))
        #expect(!source.contains("var statuses: [String] = IPadWorkboardDefaults.statuses"))
        #expect(!source.contains("self.store.statuses"))
        #expect(!source.contains("@State private var isLoading"))
        #expect(source.contains("struct IPadWorkboardSelectedBoardID: Equatable, Sendable"))
        #expect(source.contains("var selectedBoardID = IPadWorkboardSelectedBoardID(value: \"\")"))
        #expect(source.contains("self.selectedBoardID.value.isEmpty"))
        #expect(source.contains("IPadWorkboardScreen.normalizedScopeID(self.selectedBoardID.value)"))
        #expect(source.contains("state.selectedBoardID = .init(value: IPadWorkboardScreen.normalizedScopeID(change.boardID.value))"))
        #expect(source.contains("self.store.selectedBoardID.value.isEmpty ? \"all\" : self.store.selectedBoardID.value"))
        #expect(!source.contains("var selectedBoardID = \"\""))
        #expect(source.contains("struct IPadWorkboardKnownBoardID: Equatable, Sendable"))
        #expect(source.contains("var knownBoardIDs: [IPadWorkboardKnownBoardID] = []"))
        #expect(source.contains("var knownBoardIDValues: [String]"))
        #expect(source.contains("knownBoardIDs: self.knownBoardIDValues"))
        #expect(!source.contains("var knownBoardIDs: [String] = []"))
        #expect(!source.contains("@State private var busyCardID"))
        #expect(source.contains("struct IPadWorkboardActiveRefreshBoardID: Equatable, Sendable"))
        #expect(source.contains("case inFlight(boardID: IPadWorkboardActiveRefreshBoardID?)"))
        #expect(source.contains("func matchesActiveBoardID(_ boardID: IPadWorkboardActiveRefreshBoardID?) -> Bool"))
        #expect(source.contains("state.refreshPhase = .inFlight("))
        #expect(source.contains("boardID: boardScope.boardID.map { .init(value: $0.value) })"))
        #expect(source.contains("let activeRefreshBoardID = response.boardScope.boardID"))
        #expect(source.contains("state.refreshPhase.matchesActiveBoardID(activeRefreshBoardID)"))
        #expect(source.contains(".map { IPadWorkboardActiveRefreshBoardID(value: $0.value) }"))
        #expect(!source.contains("var activeRefreshBoardID: IPadWorkboardActiveRefreshBoardID?"))
        #expect(!source.contains("state.activeRefreshBoardID"))
        #expect(!source.contains("var activeRefreshBoardID: String?"))
        #expect(source.contains("struct IPadWorkboardBusyCardID: Equatable, Sendable"))
        #expect(source.contains("var busyCardID: IPadWorkboardBusyCardID?"))
        #expect(source.contains("state.busyCardID = .init(value: request.card.id)"))
        #expect(source.contains("self.store.busyCardID?.value == card.id"))
        #expect(!source.contains("var busyCardID: String?"))
        #expect(source.contains("private var createUnavailableMessage: String?"))
        #expect(source.contains("Enter a title to create a card."))
        #expect(source.contains("Card creation is already in progress."))
        #expect(source.contains("private func newCardButton(expands: Bool) -> some View"))
        #expect(source.contains("private func beginCreateCard()"))
        #expect(source.contains("self.store.send(.beginCreateCardTapped)"))
        #expect(source.contains("self.newCardButton(expands: false)"))
        #expect(source.contains("self.newCardButton(expands: true)"))
        #expect(source.contains("Label(\"New Card\", systemImage: \"plus\")"))
        #expect(source.contains(".accessibilityHint(\"Opens card title and notes entry\")"))
        #expect(source.contains(".accessibilityHint(self.createUnavailableMessage ?? \"Creates a workboard card\")"))
        #expect(source.contains("await self.createCard()"))
        #expect(source.contains("enum CardCreationPhase: Equatable, Sendable"))
        #expect(source.contains("var cardCreationPhase = CardCreationPhase.idle"))
        #expect(source.contains("state.cardCreationPhase = .inFlight"))
        #expect(source.contains("state.cardCreationPhase = .idle"))
        #expect(source.contains(".disabled(self.store.cardCreationPhase == .inFlight)"))
        #expect(source.contains("self.store.cardCreationPhase == .inFlight ? \"Creating...\" : \"Create\""))
        #expect(!source.contains("struct IPadWorkboardCardCreationInFlight: Equatable, Sendable"))
        #expect(!source.contains("var isCreatingCard = IPadWorkboardCardCreationInFlight(value: false)"))
        #expect(!source.contains("var isCreatingCard = false"))
        #expect(!source.contains(".disabled(self.store.isCreatingCard)"))
        #expect(!source.contains("Button(\"Create\")"))
        #expect(!source.contains("TextField(\"New card\""))
        #expect(!source.contains(".disabled(!self.canWrite || self.draftTitle"))
        #expect(createFunction.contains("readAccess: .init(canRead: self.canRead)"))
        #expect(createFunction.contains("writeAccess: .init(canWrite: self.canWrite)"))
        #expect(source.contains("struct SceneActivity: Equatable, Sendable"))
        #expect(source.contains("struct GatewayReadAccess: Equatable, Sendable"))
        #expect(source.contains("struct GatewayWriteAccess: Equatable, Sendable"))
        #expect(source.contains("struct RefreshForce: Equatable, Sendable"))
        #expect(source.contains("struct CreateRequest: Equatable, Sendable"))
        #expect(source.contains("var readAccess: GatewayReadAccess"))
        #expect(source.contains("var writeAccess: GatewayWriteAccess"))
        #expect(source.contains("struct CreateResponse: Equatable, Sendable"))
        #expect(source.contains("case createRequested(CreateRequest)"))
        #expect(source.contains("case createResponse(CreateResponse)"))
        #expect(source.contains("struct BoardScopesResponse: Equatable, Sendable"))
        #expect(source.contains("var force: RefreshForce"))
        #expect(source.contains("case boardScopesResponse(BoardScopesResponse)"))
        #expect(source.contains("struct BoardScopeChange: Equatable, Sendable"))
        #expect(source.contains("case boardScopeChanged(BoardScopeChange)"))
        #expect(source.contains("struct IPadWorkboardBoardScopeSelection: Equatable, Sendable"))
        #expect(source.contains("var boardID: IPadWorkboardBoardScopeSelection"))
        #expect(source.contains("IPadWorkboardScreen.normalizedScopeID(change.boardID.value)"))
        #expect(source.contains("self.store.send(.boardScopeChanged(.init(boardID: .init(value: \"\"))))"))
        #expect(source.contains("self.store.send(.boardScopeChanged(.init(boardID: .init(value: boardID))))"))
        #expect(!source.contains("struct BoardScopeChange: Equatable, Sendable {\n            var boardID: String"))
        #expect(source.contains("struct ArchiveRequest: Equatable, Sendable"))
        #expect(source.contains("struct ArchiveResponse: Equatable, Sendable"))
        #expect(source.contains("case archiveRequested(ArchiveRequest)"))
        #expect(source.contains("case archiveResponse(ArchiveResponse)"))
        #expect(source.contains("self.store.send(.archiveRequested(.init("))
        #expect(source.contains("struct DispatchRequest: Equatable, Sendable"))
        #expect(source.contains("struct DispatchResponse: Equatable, Sendable"))
        #expect(source.contains("case dispatchRequested(DispatchRequest)"))
        #expect(source.contains("case dispatchResponse(DispatchResponse)"))
        #expect(source.contains("self.store.send(.dispatchRequested(.init(writeAccess: .init(canWrite: self.canWrite))"))
        #expect(source.contains("guard request.writeAccess.canWrite"))
        #expect(source.contains("request.readAccess.canRead"))
        #expect(source.contains("enum DispatchPhase: Equatable, Sendable"))
        #expect(source.contains("var dispatchPhase = DispatchPhase.idle"))
        #expect(source.contains("enum RefreshPhase: Equatable, Sendable"))
        #expect(source.contains("var refreshPhase = RefreshPhase.idle"))
        #expect(source.contains("self.refreshPhase.isInFlight || self.dispatchPhase == .inFlight"))
        #expect(source.contains("state.refreshPhase = .inFlight("))
        #expect(source.contains("state.refreshPhase = .idle"))
        #expect(!source.contains("struct IPadWorkboardRefreshInFlight: Equatable, Sendable"))
        #expect(!source.contains("var isRefreshing = IPadWorkboardRefreshInFlight(value: false)"))
        #expect(!source.contains("var isRefreshing = false"))
        #expect(!source.contains("state.isRefreshing = true"))
        #expect(!source.contains("state.isRefreshing = false"))
        #expect(source.contains("state.dispatchPhase = .inFlight"))
        #expect(source.contains("state.dispatchPhase = .idle"))
        #expect(!source.contains("struct IPadWorkboardDispatchInFlight: Equatable, Sendable"))
        #expect(!source.contains("var isDispatching = IPadWorkboardDispatchInFlight(value: false)"))
        #expect(!source.contains("var isDispatching = false"))
        #expect(!source.contains("state.isDispatching = true"))
        #expect(!source.contains("state.isDispatching = false"))
        #expect(source.contains("struct DraftNotesChange: Equatable, Sendable"))
        #expect(source.contains("struct DraftTitleChange: Equatable, Sendable"))
        #expect(source.contains("case draftNotesChanged(DraftNotesChange)"))
        #expect(source.contains("case draftTitleChanged(DraftTitleChange)"))
        #expect(source.contains("struct IPadWorkboardDraftNotes: Equatable, Sendable"))
        #expect(source.contains("struct IPadWorkboardDraftTitle: Equatable, Sendable"))
        #expect(source.contains("struct IPadWorkboardDispatchSummaryText: Equatable, Sendable"))
        #expect(source.contains("var dispatchSummaryText: IPadWorkboardDispatchSummaryText?"))
        #expect(source.contains("state.dispatchSummaryText = .init(value: snapshot.summary.summaryText)"))
        #expect(source.contains("Text(dispatchSummaryText.value)"))
        #expect(!source.contains("var dispatchSummaryText: String?"))
        #expect(source.contains("var notes: IPadWorkboardDraftNotes"))
        #expect(source.contains("var title: IPadWorkboardDraftTitle"))
        #expect(source.contains("state.draftNotes = change.notes"))
        #expect(source.contains("state.draftTitle = change.title"))
        #expect(source.contains("self.store.send(.draftNotesChanged(.init(notes: .init(value: $0))))"))
        #expect(source.contains("self.store.send(.draftTitleChanged(.init(title: .init(value: $0))))"))
        #expect(!source.contains("struct DraftNotesChange: Equatable, Sendable {\n            var notes: String"))
        #expect(!source.contains("struct DraftTitleChange: Equatable, Sendable {\n            var title: String"))
        #expect(source.contains("struct MoveRequest: Equatable, Sendable"))
        #expect(source.contains("struct MoveResponse: Equatable, Sendable"))
        #expect(source.contains("struct IPadWorkboardMoveStatus: Equatable, Sendable"))
        #expect(source.contains("var status: IPadWorkboardMoveStatus"))
        #expect(source.contains("status: request.status.value"))
        #expect(source.contains("state.nextPosition(for: request.status.value"))
        #expect(source.contains("case moveRequested(MoveRequest)"))
        #expect(source.contains("case moveResponse(MoveResponse)"))
        #expect(source.contains("status: .init(value: status)"))
        #expect(!source.contains("struct MoveRequest: Equatable, Sendable {\n            var card: IPadWorkboardCard\n            var status: String"))
        #expect(source.contains("struct QueryChange: Equatable, Sendable"))
        #expect(source.contains("case queryChanged(QueryChange)"))
        #expect(source.contains("struct IPadWorkboardQuery: Equatable, Sendable"))
        #expect(source.contains("var query: IPadWorkboardQuery"))
        #expect(source.contains("state.query = change.query"))
        #expect(source.contains("self.store.send(.queryChanged(.init(query: .init(value: $0))))"))
        #expect(!source.contains("struct QueryChange: Equatable, Sendable {\n            var query: String"))
        #expect(source.contains("struct RefreshRequest: Equatable, Sendable"))
        #expect(source.contains("struct RefreshResponse: Equatable, Sendable"))
        #expect(source.contains("var sceneActivity: SceneActivity"))
        #expect(source.contains("guard request.sceneActivity.isActive else"))
        #expect(source.contains("guard request.readAccess.canRead else"))
        #expect(source.contains("response.force.isForced"))
        #expect(source.contains("force: .init(isForced: force)"))
        #expect(source.contains("case refreshRequested(RefreshRequest)"))
        #expect(source.contains("case refreshResponse(RefreshResponse)"))
        #expect(source.contains("await self.store.send(.refreshRequested(.init("))
        #expect(source.contains("struct StatusChange: Equatable, Sendable"))
        #expect(source.contains("case statusChanged(StatusChange)"))
        #expect(source.contains("struct IPadWorkboardStatusFilter: Equatable, Sendable"))
        #expect(source.contains("var status: IPadWorkboardStatusFilter"))
        #expect(source.contains("state.selectedStatus = .init(value: change.status.value)"))
        #expect(source.contains("self.store.selectedStatus.value == status"))
        #expect(source.contains("get: { self.store.selectedStatus.value }"))
        #expect(source.contains("self.store.send(.statusChanged(.init(status: .init(value: $0))))"))
        #expect(source.contains("self.store.send(.statusChanged(.init(status: .init(value: \"active\"))))"))
        #expect(source.contains("self.store.send(.statusChanged(.init(status: .init(value: status))))"))
        #expect(!source.contains("struct CreateRequest: Equatable, Sendable {\n            var canRead: Bool"))
        #expect(!source.contains("struct ArchiveRequest: Equatable, Sendable {\n            var card: IPadWorkboardCard\n            var canWrite: Bool"))
        #expect(!source.contains("struct DispatchRequest: Equatable, Sendable {\n            var canWrite: Bool"))
        #expect(!source.contains("struct MoveRequest: Equatable, Sendable {\n            var card: IPadWorkboardCard\n            var status: IPadWorkboardMoveStatus\n            var canWrite: Bool"))
        #expect(!source.contains("struct RefreshRequest: Equatable, Sendable {\n            var sceneActive: Bool"))
        #expect(!source.contains("struct RefreshResponse: Equatable, Sendable {\n            var boardScope: IPadWorkboardBoardScope\n            var force: Bool"))
        #expect(!source.contains("request.canWrite"))
        #expect(!source.contains("request.canRead"))
        #expect(!source.contains("request.sceneActive"))
        #expect(!source.contains("if response.force || state.cards.isEmpty"))
        #expect(!source.contains("struct StatusChange: Equatable, Sendable {\n            var status: String"))
    }

    @Test func `task scope controls send real gateway params`() throws {
        let source = try Self.iPadTaskFeatureScreensSource()
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let phoneSource = try String(contentsOf: Self.phoneHubSourceURL(), encoding: .utf8)

        #expect(source.contains("private var boardScopeMenu: some View"))
        #expect(source.contains("method: \"workboard.boards.list\""))
        #expect(source.contains("struct IPadWorkboardBoardScopeID: Equatable, Sendable"))
        #expect(source.contains("struct IPadWorkboardBoardScope: Equatable, Sendable"))
        #expect(source.contains("var boardID: IPadWorkboardBoardScopeID?"))
        #expect(source.contains("let boardScope = IPadWorkboardBoardScope(boardID: state.selectedBoardParam)"))
        #expect(source.contains("IPadWorkboardListParams(boardId: boardScope.boardID?.value)"))
        #expect(source.contains("boardId: state.selectedBoardParam?.value"))
        #expect(!source.contains("var boardID: String?"))
        #expect(source
            .matches(
                of: /method: "workboard\.cards\.dispatch"[\s\S]*?IPadWorkboardListParams\(boardId: boardScope\.boardID\?\.value\)/)
            .count == 1)
        #expect(rootSource.contains("store: IPadWorkboardStoreFactory.live(appModel: self.appModel)"))
        #expect(phoneSource.contains("store: IPadWorkboardStoreFactory.live(appModel: self.appModel)"))
        #expect(source.contains("private var agentScopeMenu: some View"))
        #expect(source.contains("struct IPadSkillWorkshopAgentScopeParam: Equatable, Sendable"))
        #expect(source.contains("IPadSkillProposalListParams(agentId: agentScope.agentID)"))
        #expect(source.contains("agentId: agentScope.agentID"))
        #expect(!source
            .contains(
                "params: EmptyParams(),\n                timeoutSeconds: 20)\n            let response = try JSONDecoder().decode(IPadSkillProposalManifest.self"))
    }

    @Test func `compact task rows keep phone native actions`() throws {
        let source = try Self.iPadTaskFeatureScreensSource()
        let compactControls = try Self.extract(
            source,
            from: "private var compactQueueControls: some View",
            to: "private var compactRefreshButton: some View")

        #expect(source.contains("struct IPadWorkboardQueueRow"))
        #expect(source.contains("private var actionMenuItems: some View"))
        #expect(source.components(separatedBy: ".contextMenu {").count - 1 >= 2)
        #expect(source.components(separatedBy: ".swipeActions(edge: .leading").count - 1 >= 2)
        #expect(source.components(separatedBy: ".swipeActions(edge: .trailing").count - 1 >= 2)
        #expect(source.contains("var presentedProposalRoute: IPadSkillProposalSheetRoute?"))
        #expect(source.contains(".sheet(item: self.presentedProposalRouteBinding)"))
        #expect(source.contains("private func selectProposal("))
        #expect(!source.contains("proposalSheetPresented"))
        #expect(source.contains("struct CardSheetPresentation: Equatable, Sendable"))
        #expect(source.contains("case cardSheetPresented(CardSheetPresentation)"))
        #expect(source.contains("self.store.send(.cardSheetPresented(.init(card: card)))"))
        #expect(!source.contains("Label(\"Gateway\", systemImage: \"network\")"))
        #expect(!source.contains("Button(\"Gateway\")"))
        #expect(!source.contains("actionTitle: self.canRead ? nil : \"Gateway\""))
        #expect(!source.contains("Workboard offline"))
        #expect(!source.contains("Workshop offline"))
        #expect(!source.contains("Connect gateway to"))
        #expect(source.contains("private var compactRefreshButton: some View"))
        #expect(source.contains("private var compactBoardScopeMenu: some View"))
        #expect(source.contains("Color(uiColor: .secondarySystemGroupedBackground)"))
        #expect(source.contains(".allowsHitTesting(false)"))
        #expect(compactControls.contains("self.compactRefreshButton"))
        #expect(compactControls.contains("self.compactBoardScopeMenu"))
        #expect(!compactControls.contains("Self.workboardSubtitle("))
        #expect(!compactControls.contains("Label(\"Refresh\""))
        #expect(compactControls.contains("Label(\"Dispatch\""))
    }

    @Test func `skill workshop uses kanban lanes on wide I pad`() throws {
        let source = try String(contentsOf: Self.iPadSkillWorkshopScreenSourceURL(), encoding: .utf8)
        let previewSource = try String(contentsOf: Self.iPadSidebarFeaturePreviewsSourceURL(), encoding: .utf8)
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let phoneSource = try String(contentsOf: Self.phoneHubSourceURL(), encoding: .utf8)
        let content = try Self.extract(
            source,
            from: "private var proposalContent: some View",
            to: "private var proposalBoard: some View")
        let board = try Self.extract(
            source,
            from: "private var proposalBoard: some View",
            to: "private var proposalList: some View")

        #expect(content.contains("if self.isCompactWidth"))
        #expect(content.contains("self.proposalList"))
        #expect(content.contains("self.proposalBoard"))
        #expect(!content.contains("self.proposalDetail"))
        #expect(board.contains("ScrollView(.horizontal)"))
        #expect(board.contains("IPadSkillProposalKanbanColumn("))
        #expect(source.contains("private struct IPadSkillProposalKanbanCard"))
        #expect(source.contains("@Reducer\nstruct IPadSkillWorkshopFeature"))
        #expect(source.contains("struct IPadSkillWorkshopFailureMessage: Equatable, Sendable"))
        #expect(source.contains("var errorText: IPadSkillWorkshopFailureMessage?"))
        #expect(source.contains("state.errorText = .init(value: error.message)"))
        #expect(source.contains("Text(errorText.value)"))
        #expect(!source.contains("var errorText: String?"))
        #expect(!source.contains("state.errorText = error.message"))
        #expect(!source.contains("Text(errorText)"))
        #expect(source.contains("struct IPadSkillWorkshopNoticeMessage: Equatable, Sendable"))
        #expect(source.contains("var noticeText: IPadSkillWorkshopNoticeMessage?"))
        #expect(source.contains("state.noticeText = .init("))
        #expect(source.contains("Text(noticeText.value)"))
        #expect(!source.contains("var noticeText: String?"))
        #expect(!source.contains("Text(noticeText)"))
        #expect(source.contains("enum IPadSkillWorkshopLoadingPhase: Equatable, Sendable"))
        #expect(source.contains("case idle"))
        #expect(source.contains("case inFlight"))
        #expect(source.contains("var loadingPhase = IPadSkillWorkshopLoadingPhase.idle"))
        #expect(source.contains("guard state.loadingPhase != .inFlight else { return .none }"))
        #expect(source.contains("state.loadingPhase = .inFlight"))
        #expect(source.contains("state.loadingPhase = .idle"))
        #expect(source.contains(".disabled(self.store.loadingPhase == .inFlight)"))
        #expect(source.contains("if self.store.loadingPhase == .inFlight"))
        #expect(!source.contains("struct IPadSkillWorkshopLoadingInFlight: Equatable, Sendable"))
        #expect(!source.contains("var isLoading = IPadSkillWorkshopLoadingInFlight(value: false)"))
        #expect(!source.contains("var isLoading = false"))
        #expect(!source.contains("state.isLoading = true"))
        #expect(!source.contains("state.isLoading = false"))
        #expect(!source.contains("state.isLoading = .init(value: true)"))
        #expect(!source.contains("state.isLoading = .init(value: false)"))
        #expect(!source.contains("guard !state.isLoading.value else"))
        #expect(!source.contains("guard !state.isLoading else"))
        #expect(!source.contains(".disabled(self.store.isLoading.value)"))
        #expect(!source.contains(".disabled(self.store.isLoading)"))
        #expect(!source.contains("if self.store.isLoading.value"))
        #expect(!source.contains("if self.store.isLoading {"))
        #expect(source.contains(
            "struct Failure: Equatable, Sendable { var message: IPadSkillWorkshopFailureMessage }"))
        #expect(source.contains("case failed(Failure)"))
        #expect(source.contains("private static func failure(for error: Error) -> IPadSkillWorkshopError"))
        #expect(source.contains("message: .init(value: \"Proposal unavailable.\")"))
        #expect(source.contains(".failed(.init(message: .init(value: self.message(for: error))))"))
        #expect(source.contains("failure.message.value"))
        #expect(source.contains("result: .failure(Self.failure(for: error))"))
        #expect(!source.contains("struct Failure: Equatable, Sendable { var message: String }"))
        #expect(!source.contains("case failed(String)"))
        #expect(!source.contains("@State private var proposals"))
        #expect(!source.contains("@State private var selectedProposalID"))
        #expect(source.contains("var selectedProposalID: IPadSkillWorkshopProposalID?"))
        #expect(source.contains("current: self.selectedProposalID?.value"))
        #expect(source.contains("let nextProposalID = nextID.map { IPadSkillWorkshopProposalID(value: $0) }"))
        #expect(source.contains("state.selectedProposalID = request.proposalID"))
        #expect(source.contains("proposalID: proposalID,"))
        #expect(source.contains("selectedProposalID: self.store.selectedProposalID?.value"))
        #expect(source.contains("isSelected: proposal.id == self.store.selectedProposalID?.value"))
        #expect(!source.contains("var selectedProposalID: String?"))
        #expect(!source.contains("current: self.selectedProposalID,"))
        #expect(!source.contains("state.selectedProposalID = request.proposalID.value"))
        #expect(!source.contains("selectedProposalID: self.store.selectedProposalID,"))
        #expect(source.contains("var inspectingProposalID: IPadSkillWorkshopProposalID?"))
        #expect(source.contains("state.inspectingProposalID = request.proposalID"))
        #expect(source.contains("inspectingProposalID: self.store.inspectingProposalID?.value"))
        #expect(source.contains("isBusy: self.store.inspectingProposalID?.value == proposal.id"))
        #expect(source.contains("if self.store.inspectingProposalID?.value == proposal.id"))
        #expect(!source.contains("var inspectingProposalID: String?"))
        #expect(!source.contains("state.inspectingProposalID = request.proposalID.value"))
        #expect(!source.contains("inspectingProposalID: self.store.inspectingProposalID,"))
        #expect(!source.contains("self.store.inspectingProposalID == proposal.id"))
        #expect(source.contains("struct IPadSkillWorkshopSelectedAgentScopeID: Equatable, Sendable"))
        #expect(source.contains("var selectedAgentScopeID = IPadSkillWorkshopSelectedAgentScopeID(value: \"\")"))
        #expect(source.contains("self.selectedAgentScopeID.value"))
        #expect(source.contains("var agentID: IPadSkillWorkshopSelectedAgentScopeID"))
        #expect(source.contains("IPadSkillWorkshopScreen.normalizedScopeID(change.agentID.value)"))
        #expect(source.contains("self.store.selectedAgentScopeID.value.isEmpty"))
        #expect(source.contains("Self.normalizedScopeID(self.store.selectedAgentScopeID.value)"))
        #expect(!source.contains("var selectedAgentScopeID = \"\""))
        #expect(!source.contains("struct AgentScopeChange: Equatable, Sendable {\n            var agentID: String"))
        #expect(!source.contains("@State private var statusFilter"))
        #expect(source.contains("struct IPadSkillWorkshopStatusFilter: Equatable, Sendable"))
        #expect(source.contains("var statusFilter = IPadSkillWorkshopStatusFilter(value: \"pending\")"))
        #expect(source.contains("proposalStatusFilterLabel(self.statusFilter.value)"))
        #expect(source.contains("statusFilter: self.statusFilter.value"))
        #expect(source.contains("filter: self.statusFilter.value"))
        #expect(source.contains("var filter: IPadSkillWorkshopStatusFilter"))
        #expect(source.contains("state.statusFilter = change.filter"))
        #expect(source.contains("get: { self.store.statusFilter.value }"))
        #expect(!source.contains("var statusFilter = \"pending\""))
        #expect(!source.contains("var filter: String"))
        #expect(!source.contains("get: { self.store.statusFilter }"))
        #expect(!source.contains("@State private var query"))
        #expect(source.contains("struct IPadSkillWorkshopQuery: Equatable, Sendable"))
        #expect(source.contains("var query = IPadSkillWorkshopQuery(value: \"\")"))
        #expect(source.contains("query: self.query.value"))
        #expect(source.contains("var query: IPadSkillWorkshopQuery"))
        #expect(source.contains("state.query = change.query"))
        #expect(source.contains("state.query = .init(value: \"\")"))
        #expect(source.contains("get: { self.store.query.value }"))
        #expect(source.contains("if !self.store.query.value.isEmpty"))
        #expect(!source.contains("var query = \"\""))
        #expect(!source.contains("state.query = \"\""))
        #expect(!source.contains("struct QueryChange: Equatable, Sendable {\n            var query: String"))
        #expect(source.contains("struct AgentScopeChange: Equatable, Sendable"))
        #expect(source.contains("struct InspectRequest: Equatable, Sendable"))
        #expect(source.contains("struct InspectResponse: Equatable, Sendable"))
        #expect(source.contains("struct RefreshRequest: Equatable, Sendable"))
        #expect(source.contains("struct RefreshResponse: Equatable, Sendable"))
        #expect(source.contains("struct ProposalMutationRequest: Equatable, Sendable"))
        #expect(source.contains("struct ProposalMutationSuccess: Equatable, Sendable"))
        #expect(source.contains("struct ProposalMutationResponse: Equatable, Sendable"))
        #expect(source.contains("var result: Result<ProposalMutationSuccess, IPadSkillWorkshopError>"))
        #expect(source.contains("result: .success(.init())"))
        #expect(!source.contains("Result<Bool, IPadSkillWorkshopError>"))
        #expect(source.contains("struct ProposalSelectionRequest: Equatable, Sendable"))
        #expect(source.contains("struct SceneActivity: Equatable, Sendable"))
        #expect(source.contains("struct GatewayReadAccess: Equatable, Sendable"))
        #expect(source.contains("struct GatewayWriteAccess: Equatable, Sendable"))
        #expect(source.contains("struct OperatorAdminAccess: Equatable, Sendable"))
        #expect(source.contains("struct RefreshForce: Equatable, Sendable"))
        #expect(source.contains("struct InspectionForce: Equatable, Sendable"))
        #expect(source.contains("enum ProposalSheetOpening: Equatable, Sendable"))
        #expect(source.contains("case inline"))
        #expect(source.contains("case sheet"))
        #expect(source.contains("var readAccess: GatewayReadAccess"))
        #expect(source.contains("var force: InspectionForce"))
        #expect(source.contains("var sceneActivity: SceneActivity"))
        #expect(source.contains("var writeAccess: GatewayWriteAccess"))
        #expect(source.contains("var adminAccess: OperatorAdminAccess"))
        #expect(source.contains("var opening: ProposalSheetOpening"))
        #expect(source.contains("var forceInspect: InspectionForce"))
        #expect(source.contains("var force: RefreshForce"))
        #expect(source.contains("guard request.sceneActivity.isActive else"))
        #expect(source.contains("guard request.readAccess.canRead else"))
        #expect(source.contains("request.writeAccess.canWrite"))
        #expect(source.contains("request.adminAccess.hasOperatorAdminScope"))
        #expect(source.contains("request.opening == .sheet"))
        #expect(source.contains("response.force.isForced"))
        #expect(source.contains("opening: self.isCompactWidth ? .sheet : .inline"))
        #expect(source.contains("readAccess: .init(canRead: self.canRead)"))
        #expect(source.contains("writeAccess: .init(canWrite: self.canWrite)"))
        #expect(source.contains("adminAccess: .init(hasOperatorAdminScope: self.appModel.hasOperatorAdminScope)"))
        #expect(source.contains("sceneActivity: .init(isActive: self.scenePhase == .active)"))
        #expect(source.contains("force: .init(isForced: force)"))
        #expect(!source.contains(
            "struct InspectRequest: Equatable, Sendable {\n            var proposalID: IPadSkillWorkshopProposalID\n            var canRead: Bool"))
        #expect(!source.contains(
            "struct ProposalMutationRequest: Equatable, Sendable {\n            var kind: IPadSkillProposalAction.Kind\n            var proposalID: IPadSkillWorkshopProposalID\n            var sceneActive: Bool"))
        #expect(!source.contains(
            "struct ProposalMutationResponse: Equatable, Sendable {\n            var kind: IPadSkillProposalAction.Kind\n            var sceneActive: Bool"))
        #expect(!source.contains(
            "struct ProposalSelectionRequest: Equatable, Sendable {\n            var proposalID: IPadSkillWorkshopProposalID\n            var opensSheet: Bool"))
        #expect(!source.contains("struct ProposalSheetOpening: Equatable, Sendable { var opensSheet: Bool }"))
        #expect(!source.contains("var opensSheet: ProposalSheetOpening"))
        #expect(!source.contains("request.opensSheet.opensSheet"))
        #expect(!source.contains("opensSheet: .init(opensSheet: opensSheet)"))
        #expect(!source.contains(
            "struct RefreshRequest: Equatable, Sendable {\n            var sceneActive: Bool"))
        #expect(!source.contains(
            "struct RefreshResponse: Equatable, Sendable {\n            var force: Bool"))
        #expect(!source.contains("request.canRead"))
        #expect(!source.contains("request.canWrite"))
        #expect(!source.contains("request.sceneActive"))
        #expect(!source.contains("if request.opensSheet {"))
        #expect(!source.contains("if response.force || state.proposals.isEmpty"))
        #expect(source.contains("struct QueryChange: Equatable, Sendable"))
        #expect(source.contains("struct StatusFilterChange: Equatable, Sendable"))
        #expect(source.contains("case agentScopeChanged(AgentScopeChange)"))
        #expect(source.contains("case inspectRequested(InspectRequest)"))
        #expect(source.contains("case inspectResponse(InspectResponse)"))
        #expect(source.contains("case refreshRequested(RefreshRequest)"))
        #expect(source.contains("case refreshResponse(RefreshResponse)"))
        #expect(source.contains("case proposalMutationRequested(ProposalMutationRequest)"))
        #expect(source.contains("case proposalMutationResponse(ProposalMutationResponse)"))
        #expect(source.contains("case proposalSelected(ProposalSelectionRequest)"))
        #expect(source.contains("case queryChanged(QueryChange)"))
        #expect(source.contains("case statusFilterChanged(StatusFilterChange)"))
        #expect(source.contains("self.store.send(.agentScopeChanged(.init(agentID: .init(value: \"\"))))"))
        #expect(source.contains("self.store.send(.agentScopeChanged(.init(agentID: .init(value: option.id))))"))
        #expect(source.contains("self.store.send(.queryChanged(.init(query: .init(value: $0))))"))
        #expect(source.contains("self.store.send(.statusFilterChanged(.init(filter: .init(value: $0))))"))
        #expect(source.contains("await self.store.send(.proposalSelected(.init("))
        #expect(source.contains("await self.store.send(.inspectRequested(.init("))
        #expect(source.contains("await self.store.send(.refreshRequested(.init("))
        #expect(source.contains("await self.store.send(.proposalMutationRequested(.init("))
        #expect(source.contains("static let defaultProposalStatusBoardLanes"))
        #expect(source.contains("private func proposals(forLaneStatus status: String)"))
        #expect(rootSource.contains("store: IPadSkillWorkshopStoreFactory.live(appModel: self.appModel)"))
        #expect(phoneSource.contains("store: IPadSkillWorkshopStoreFactory.live(appModel: self.appModel)"))
        #expect(previewSource.contains("#Preview(\n    \"Skill Workshop iPad kanban lanes\""))
        #expect(previewSource.contains("private struct IPadSkillWorkshopKanbanPreview"))
        #expect(previewSource.contains("IPadSkillProposalKanbanColumn("))
        #expect(previewSource.contains("status: \"needs-review\""))
        #expect(previewSource.contains("status: \"manual_QA\""))
    }

    @Test func `compact task rows have populated phone previews`() throws {
        let source = try String(contentsOf: Self.iPadSidebarFeaturePreviewsSourceURL(), encoding: .utf8)

        #expect(source.contains("#Preview(\"Workboard phone queue rows\")"))
        #expect(source.contains("#Preview(\"Skill Workshop phone queue rows\")"))
        #expect(source.contains("private struct IPadWorkboardCompactRowsPreview"))
        #expect(source.contains("private struct IPadSkillWorkshopCompactRowsPreview"))
        #expect(source.contains("IPadWorkboardPreviewFixtures.cards"))
        #expect(source.contains("IPadSkillWorkshopPreviewFixtures.proposals"))
    }

    @Test func `task screen preview matrices cover primary states`() throws {
        let source = try String(contentsOf: Self.iPadSidebarFeaturePreviewsSourceURL(), encoding: .utf8)

        #expect(source.contains("#Preview(\"Workboard states\")"))
        #expect(source.contains("private struct IPadWorkboardStatesPreview"))
        #expect(source.contains("self.previewHeader(\"Connected\")"))
        #expect(source.contains("self.previewHeader(\"Empty\")"))
        #expect(source.contains("self.previewHeader(\"Loading\")"))
        #expect(source.contains("self.previewHeader(\"Error\")"))
        #expect(source.contains("title: \"Loading cards\""))
        #expect(source.contains("title: \"Cards unavailable\""))
        #expect(source.contains("IPadWorkboardKanbanColumn("))

        #expect(source.contains("#Preview(\"Skill Workshop states\")"))
        #expect(source.contains("private struct IPadSkillWorkshopStatesPreview"))
        #expect(source.contains("self.previewHeader(\"Offline / Error\")"))
        #expect(source.contains("title: \"No proposals\""))
        #expect(source.contains("title: \"Workshop offline\""))
        #expect(source.contains("title: \"Proposal unavailable\""))
        #expect(source.contains("#Preview(\n    \"Skill Workshop iPad kanban lanes\""))
        #expect(source.contains("private struct IPadSkillWorkshopKanbanPreview"))
        #expect(source.contains("\"needs-review\""))
        #expect(source.contains("\"manual_QA\""))
    }

    @Test func `activity preview matrix covers connection states`() throws {
        let source = try String(contentsOf: Self.iPadSidebarFeaturePreviewsSourceURL(), encoding: .utf8)

        #expect(source.contains("#Preview(\"Activity states\")"))
        #expect(source.contains("private struct IPadActivityStatesPreview"))
        #expect(source.contains("self.previewHeader(\"Connected\")"))
        #expect(source.contains("self.previewHeader(\"Loading\")"))
        #expect(source.contains("self.previewHeader(\"Empty\")"))
        #expect(source.contains("self.previewHeader(\"Error\")"))
        #expect(source.contains("title: \"Sessions unavailable\""))
        #expect(source.contains("title: \"No recent sessions\""))
        #expect(source.contains("title: \"Loading sessions\""))
    }

    @Test func `activity sessions refresh response action is typed`() throws {
        let source = try String(contentsOf: Self.iPadActivityScreenSourceURL(), encoding: .utf8)
        let feature = try Self.extract(
            source,
            from: "@Reducer\nstruct IPadActivitySessionsFeature",
            to: "enum IPadActivitySessionsStoreFactory")

        #expect(source.contains("struct IPadActivitySessionsFailureMessage: Equatable, Sendable"))
        #expect(source.contains("enum IPadActivitySessionsLoadingPhase: Equatable, Sendable"))
        #expect(source.contains("case idle"))
        #expect(source.contains("case inFlight"))
        #expect(source.contains("struct IPadActivitySceneActive: Equatable, Sendable"))
        #expect(source.contains("struct IPadActivitySessionsAvailable: Equatable, Sendable"))
        #expect(feature.contains("var loadingPhase = IPadActivitySessionsLoadingPhase.idle"))
        #expect(feature.contains("var loadErrorText: IPadActivitySessionsFailureMessage?"))
        #expect(feature.contains("state.loadingPhase = .inFlight"))
        #expect(feature.contains("state.loadingPhase = .idle"))
        #expect(feature.contains("state.loadErrorText = .init(value: \"Try again after the gateway reconnects.\")"))
        #expect(source.contains("value: self.store.loadingPhase == .inFlight ? \"Loading\" : nil"))
        #expect(source.contains("if self.store.loadingPhase == .inFlight, self.store.sessions.isEmpty"))
        #expect(source.contains("detail: loadErrorText.value"))
        #expect(feature.contains("struct RefreshResponse: Equatable, Sendable"))
        #expect(feature.contains("struct SceneActivity: Equatable, Sendable"))
        #expect(feature.contains("struct SessionsAvailability: Equatable, Sendable"))
        #expect(feature.contains("var isActive: IPadActivitySceneActive"))
        #expect(feature.contains("var isAvailable: IPadActivitySessionsAvailable"))
        #expect(feature.contains("var sceneActivity: SceneActivity"))
        #expect(feature.contains("var sessionsAvailability: SessionsAvailability"))
        #expect(feature.contains("guard request.sceneActivity.isActive.value"))
        #expect(feature.contains("guard request.sessionsAvailability.isAvailable.value"))
        #expect(source.contains("sceneActivity: .init(isActive: .init(value: self.scenePhase == .active))"))
        #expect(source.contains("sessionsAvailability: .init(isAvailable: .init(value: self.sessionsAvailable))"))
        #expect(feature.contains("case refreshResponse(RefreshResponse)"))
        #expect(feature.contains("await send(.refreshResponse(.init(result: .success(sessions))))"))
        #expect(feature.contains("switch response.result"))
        #expect(!feature.contains("var isLoading = false"))
        #expect(!source.contains("struct IPadActivitySessionsLoadingInFlight: Equatable, Sendable"))
        #expect(!feature.contains("var isLoading = IPadActivitySessionsLoadingInFlight(value: false)"))
        #expect(!feature.contains("state.isLoading = true"))
        #expect(!feature.contains("state.isLoading = false"))
        #expect(!feature.contains("state.isLoading = .init(value: true)"))
        #expect(!feature.contains("state.isLoading = .init(value: false)"))
        #expect(!source.contains("value: self.store.isLoading.value ? \"Loading\" : nil"))
        #expect(!source.contains("if self.store.isLoading.value, self.store.sessions.isEmpty"))
        #expect(!source.contains("if self.store.isLoading, self.store.sessions.isEmpty"))
        #expect(!feature.contains("var loadErrorText: String?"))
        #expect(!feature.contains("state.loadErrorText = \"Try again after the gateway reconnects.\""))
        #expect(!source.contains("detail: loadErrorText,"))
        #expect(!feature.contains("var sceneActive: Bool"))
        #expect(!feature.contains("var sessionsAvailable: Bool"))
        #expect(!feature.contains("var isActive: Bool"))
        #expect(!feature.contains("var isAvailable: Bool"))
        #expect(!feature.contains("guard request.sceneActivity.isActive else"))
        #expect(!feature.contains("guard request.sessionsAvailability.isAvailable else"))
        #expect(!source.contains("sceneActivity: .init(isActive: self.scenePhase == .active)"))
        #expect(!source.contains("sessionsAvailability: .init(isAvailable: self.sessionsAvailable)"))
    }

    @Test func `command sessions refresh response action is typed`() throws {
        let source = try String(contentsOf: Self.commandSessionsFeatureSourceURL(), encoding: .utf8)
        let commandCenterSource = try String(contentsOf: Self.commandCenterSourceURL(), encoding: .utf8)
        let feature = try Self.extract(
            source,
            from: "@Reducer\nstruct CommandSessionsFeature",
            to: "enum CommandSessionsStoreFactory")

        #expect(source.contains("struct CommandSessionsFailureMessage: Equatable, Sendable"))
        #expect(source.contains("enum CommandSessionsLoadingPhase: Equatable, Sendable"))
        #expect(source.contains("case idle"))
        #expect(source.contains("case inFlight"))
        #expect(source.contains("struct CommandSessionsAvailable: Equatable, Sendable"))
        #expect(feature.contains("var loadingPhase = CommandSessionsLoadingPhase.idle"))
        #expect(feature.contains("var loadErrorText: CommandSessionsFailureMessage?"))
        #expect(feature.contains("state.loadingPhase = .inFlight"))
        #expect(feature.contains("state.loadingPhase = .idle"))
        #expect(feature.contains("state.loadErrorText = .init(value: \"Try again after the gateway reconnects.\")"))
        #expect(commandCenterSource.contains("if self.store.loadingPhase == .inFlight"))
        #expect(commandCenterSource.contains("if self.store.loadingPhase == .inFlight, self.store.sessions.isEmpty"))
        #expect(commandCenterSource.contains("detail: loadErrorText.value"))
        #expect(feature.contains("struct RefreshResponse: Equatable, Sendable"))
        #expect(feature.contains("struct SessionsAvailability: Equatable, Sendable"))
        #expect(feature.contains("var isAvailable: CommandSessionsAvailable"))
        #expect(feature.contains("var sessionsAvailability: SessionsAvailability"))
        #expect(feature.contains("guard request.sessionsAvailability.isAvailable.value"))
        #expect(commandCenterSource.contains(
            "sessionsAvailability: .init(isAvailable: .init(value: self.appModel.isCommandSessionListAvailable))"))
        #expect(feature.contains("case refreshResponse(RefreshResponse)"))
        #expect(feature.contains("await send(.refreshResponse(.init(result: .success(sessions))))"))
        #expect(feature.contains("switch response.result"))
        #expect(!feature.contains("var isLoading = false"))
        #expect(!source.contains("struct CommandSessionsLoadingInFlight: Equatable, Sendable"))
        #expect(!feature.contains("var isLoading = CommandSessionsLoadingInFlight(value: false)"))
        #expect(!feature.contains("state.isLoading = true"))
        #expect(!feature.contains("state.isLoading = false"))
        #expect(!feature.contains("state.isLoading = .init(value: true)"))
        #expect(!feature.contains("state.isLoading = .init(value: false)"))
        #expect(!commandCenterSource.contains("if self.store.isLoading {"))
        #expect(!commandCenterSource.contains("if self.store.isLoading, self.store.sessions.isEmpty"))
        #expect(!commandCenterSource.contains("if self.store.isLoading.value"))
        #expect(!commandCenterSource.contains("if self.store.isLoading.value, self.store.sessions.isEmpty"))
        #expect(!feature.contains("var loadErrorText: String?"))
        #expect(!feature.contains("state.loadErrorText = \"Try again after the gateway reconnects.\""))
        #expect(!commandCenterSource.contains("detail: loadErrorText)"))
        #expect(!feature.contains("var isAvailable: Bool"))
        #expect(!feature.contains("guard request.sessionsAvailability.isAvailable else"))
        #expect(!feature.contains("var sessionsAvailable: Bool"))
        #expect(!commandCenterSource.contains(
            "sessionsAvailability: .init(isAvailable: self.appModel.isCommandSessionListAvailable)"))
    }

    @Test func `command center recent sessions refresh response action is typed`() throws {
        let source = try String(contentsOf: Self.commandSessionsFeatureSourceURL(), encoding: .utf8)
        let commandCenterSource = try String(contentsOf: Self.commandCenterSourceURL(), encoding: .utf8)
        let feature = try Self.extract(
            source,
            from: "@Reducer\nstruct CommandCenterRecentSessionsFeature",
            to: "private static func snapshot")

        #expect(feature.contains("struct RefreshResponse: Equatable, Sendable"))
        #expect(feature.contains("struct SceneActivity: Equatable, Sendable"))
        #expect(feature.contains("struct SessionsAvailability: Equatable, Sendable"))
        #expect(source.contains("struct CommandSceneActive: Equatable, Sendable"))
        #expect(source.contains("struct CommandSessionReferenceKey: Equatable, Sendable"))
        #expect(source.contains("struct CommandSessionsAvailable: Equatable, Sendable"))
        #expect(feature.contains("struct SessionReference: Equatable, Sendable"))
        #expect(feature.contains("var isActive: CommandSceneActive"))
        #expect(feature.contains("var isAvailable: CommandSessionsAvailable"))
        #expect(feature.contains("var key: CommandSessionReferenceKey"))
        #expect(feature.contains("var sceneActivity: SceneActivity"))
        #expect(feature.contains("var sessionsAvailability: SessionsAvailability"))
        #expect(feature.contains("var currentSession: SessionReference"))
        #expect(feature.contains("var defaultSession: SessionReference"))
        #expect(feature.contains("guard request.sceneActivity.isActive.value"))
        #expect(feature.contains("guard request.sessionsAvailability.isAvailable.value"))
        #expect(feature.contains("currentSessionKey: request.currentSession.key.value"))
        #expect(feature.contains("defaultSessionKey: request.defaultSession.key.value"))
        #expect(commandCenterSource.contains("sceneActivity: .init(isActive: .init(value: self.scenePhase == .active))"))
        #expect(commandCenterSource.contains(
            "sessionsAvailability: .init(isAvailable: .init(value: self.sessionListAvailable))"))
        #expect(commandCenterSource.contains("currentSession: .init(key: .init(value: self.appModel.chatSessionKey))"))
        #expect(commandCenterSource.contains(
            "defaultSession: .init(key: .init(value: self.appModel.defaultChatSessionKey))"))
        #expect(feature.contains("case refreshResponse(RefreshResponse)"))
        #expect(feature.contains("await send(.refreshResponse(.init(result: .success(snapshot))))"))
        #expect(feature.contains("switch response.result"))
        #expect(!feature.contains("var sceneActive: Bool"))
        #expect(!feature.contains("var sessionsAvailable: Bool"))
        #expect(!feature.contains("var isActive: Bool"))
        #expect(!feature.contains("guard request.sceneActivity.isActive else"))
        #expect(!feature.contains("var isAvailable: Bool"))
        #expect(!feature.contains("guard request.sessionsAvailability.isAvailable else"))
        #expect(!feature.contains("var key: String"))
        #expect(!feature.contains("var currentSessionKey: String"))
        #expect(!feature.contains("var defaultSessionKey: String"))
        #expect(!commandCenterSource.contains("sceneActivity: .init(isActive: self.scenePhase == .active)"))
        #expect(!commandCenterSource.contains("sessionsAvailability: .init(isAvailable: self.sessionListAvailable)"))
        #expect(!commandCenterSource.contains("currentSession: .init(key: self.appModel.chatSessionKey)"))
        #expect(!commandCenterSource.contains("defaultSession: .init(key: self.appModel.defaultChatSessionKey)"))
    }

    @Test func `command center chat routes use typed payload`() throws {
        let source = try String(contentsOf: Self.commandCenterSourceURL(), encoding: .utf8)
        let activitySource = try String(contentsOf: Self.iPadActivityScreenSourceURL(), encoding: .utf8)
        let previewsSource = try String(contentsOf: Self.iPadSidebarFeaturePreviewsSourceURL(), encoding: .utf8)

        #expect(source.contains("struct ChatRoute: Equatable"))
        #expect(source.contains("case chat(ChatRoute)"))
        #expect(source.contains("static let defaultSession = Self(sessionKey: nil)"))
        #expect(source.contains("static func recentSession(_ sessionKey: String) -> Self"))
        #expect(source.contains("self.open(.chat(.defaultSession))"))
        #expect(source.contains("route: .chat(.recentSession(session.key))"))
        #expect(source.contains("self.appModel.openChat(sessionKey: route.sessionKey)"))
        #expect(!source.contains("case chat(String?)"))
        #expect(!source.contains(".chat(nil)"))
        #expect(!source.contains(".chat(session.key)"))
        #expect(activitySource.contains("self.appModel.openChat(sessionKey: route.sessionKey)"))
        #expect(!activitySource.contains("case let .chat(sessionKey)"))
        #expect(previewsSource.contains("route: .chat(.recentSession(\"main\"))"))
        #expect(!previewsSource.contains("route: .chat(\""))
    }

    @Test func `routed feature screens reuse shared pro components`() throws {
        let source = try Self.iPadTaskFeatureScreensSource()
        let componentsSource = try String(contentsOf: Self.proComponentsSourceURL(), encoding: .utf8)
        let channelsSource = try String(contentsOf: Self.channelsSourceURL(), encoding: .utf8)

        #expect(source.contains("ProMetricGrid(metrics: self.metrics)"))
        #expect(source.contains("ProPanelHeader("))
        #expect(source.contains("ProStatusRow("))
        #expect(!source.contains("private struct ProMetricGrid"))
        #expect(!source.contains("private struct ProMetric"))
        #expect(!source.contains("private struct ProPanelHeader"))
        #expect(!source.contains("private struct ProStatusRow"))
        #expect(!channelsSource.contains("private struct SettingsChannelPanelHeader"))
        #expect(!channelsSource.contains("private struct SettingsChannelInfoRow"))
        #expect(componentsSource.contains("struct ProMetricGrid"))
        #expect(componentsSource.contains("struct ProPanelHeader"))
        #expect(componentsSource.contains("struct ProStatusRow"))
    }

    @Test func `activity screen stays split from task feature screens`() throws {
        let taskSource = try Self.iPadTaskFeatureScreensSource()
        let activitySource = try String(contentsOf: Self.iPadActivityScreenSourceURL(), encoding: .utf8)
        let appModelSource = try String(contentsOf: Self.nodeAppModelSourceURL(), encoding: .utf8)
        let projectSource = try String(contentsOf: Self.xcodeProjectSourceURL(), encoding: .utf8)

        #expect(activitySource.contains("struct IPadActivityScreen: View"))
        #expect(activitySource.contains("appModel.makeChatTransport()"))
        #expect(appModelSource.contains("return IOSGatewayChatTransport(gateway: self.operatorSession)"))
        #expect(activitySource.contains("IPadSidebarScreenChrome("))
        #expect(!taskSource.contains("struct IPadActivityScreen"))
        #expect(!taskSource.contains("import OpenClawChatUI"))
        #expect(projectSource.contains("IPadActivityScreen.swift in Sources"))
    }

    @Test func `routed feature chrome stays split from task feature screens`() throws {
        let taskSource = try Self.iPadTaskFeatureScreensSource()
        let chromeSource = try String(contentsOf: Self.iPadSidebarScreenChromeSourceURL(), encoding: .utf8)
        let projectSource = try String(contentsOf: Self.xcodeProjectSourceURL(), encoding: .utf8)

        #expect(chromeSource.contains("struct IPadSidebarScreenChrome<Content: View>: View"))
        #expect(chromeSource.contains("OpenClawSidebarHeaderLeadingSlot(action: headerLeadingAction)"))
        #expect(chromeSource.contains("OpenClawGatewayCompactPill()"))
        #expect(!taskSource.contains("struct IPadSidebarScreenChrome"))
        #expect(projectSource.contains("IPadSidebarScreenChrome.swift in Sources"))
    }

    @Test func `routed feature chrome keeps gateway pill actionable`() throws {
        let chromeSource = try String(contentsOf: Self.iPadSidebarScreenChromeSourceURL(), encoding: .utf8)
        let featureSource = try Self.iPadTaskFeatureScreensSource()
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)

        #expect(chromeSource.contains("let gatewayAction: (() -> Void)?"))
        #expect(chromeSource.contains("private var gatewayPill: some View"))
        #expect(chromeSource.contains("Button(action: gatewayAction)"))
        #expect(chromeSource.contains(".buttonBorderShape(.capsule)"))
        #expect(chromeSource.contains(".openClawGlassButton()"))
        #expect(chromeSource.contains(".accessibilityHint(\"Opens Settings / Gateway\")"))
        #expect(featureSource.matches(of: /gatewayAction: self\.openSettings/).count == 2)
        #expect(rootSource.contains("IPadActivityScreen("))
        #expect(rootSource
            .matches(of: /IPadActivityScreen\([\s\S]*?openSettings: \{ self\.selectSidebarDestination\(\.gateway\) \}/)
            .count == 1)
    }

    @Test func `routed gateway pills open gateway settings`() throws {
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let navigationSource = try String(contentsOf: Self.rootTabsNavigationSourceURL(), encoding: .utf8)
        let agentSource = try String(contentsOf: Self.agentProTabSourceURL(), encoding: .utf8)
        let agentOverviewSource = try String(contentsOf: Self.agentProTabOverviewSourceURL(), encoding: .utf8)
        let overviewSource = try String(contentsOf: Self.commandCenterSourceURL(), encoding: .utf8)
        let chatSource = try String(contentsOf: Self.chatProTabSourceURL(), encoding: .utf8)
        let docsSource = try String(contentsOf: Self.docsSourceURL(), encoding: .utf8)
        let settingsTabSource = try Self.settingsProTabCombinedSource()
        let settingsSource = try String(contentsOf: Self.settingsProTabSectionsSourceURL(), encoding: .utf8)
        let notificationGuidanceSource = try String(
            contentsOf: Self.notificationPermissionGuidanceDialogSourceURL(),
            encoding: .utf8)
        let sidebarFeature = try Self.extract(
            navigationSource,
            from: "struct RootSidebarFeature",
            to: "@Reducer\nstruct RootNavigationSelectionFeature")
        let sidebarState = try Self.extract(
            sidebarFeature,
            from: "struct State: Equatable, Sendable {",
            to: "enum Action")

        #expect(rootSource.matches(of: /openSettings: \{ self\.selectSidebarDestination\(\.gateway\) \}/).count >= 2)
        #expect(rootSource.matches(of: /openVoiceSettings: \{ self\.selectSettingsRoute\(\.voice\) \}/).count == 2)
        #expect(rootSource.matches(of: /gatewayAction: \{ self\.selectSidebarDestination\(\.gateway\) \}/).count == 1)
        #expect(!rootSource.contains("showGatewayActions"))
        #expect(!rootSource.contains("gatewayActionsDialog"))
        #expect(overviewSource.contains("Button(action: self.openSettings)"))
        #expect(overviewSource.contains(".accessibilityHint(\"Opens gateway settings\")"))
        #expect(agentSource.contains("let openSettings: (() -> Void)?"))
        #expect(agentOverviewSource.contains("OpenClawGatewayCompactPill()"))
        #expect(agentOverviewSource.contains("Button(action: openSettings)"))
        #expect(rootSource
            .matches(of: /AgentProTab\([\s\S]*?openSettings: \{ self\.selectSidebarDestination\(\.gateway\) \}/)
            .count >= 3)
        #expect(chatSource.contains("let openSettings: (() -> Void)?"))
        #expect(chatSource.contains("private var connectionPillButton: some View"))
        #expect(chatSource.contains(".buttonBorderShape(.capsule)"))
        #expect(chatSource.contains(".openClawGlassButton()"))
        #expect(docsSource.contains("let gatewayAction: (() -> Void)?"))
        #expect(docsSource.contains(".buttonBorderShape(.capsule)"))
        #expect(docsSource.contains(".openClawGlassButton()"))
        #expect(settingsSource.contains("NavigationLink(value: SettingsRoute.gateway)"))
        #expect(rootSource.contains("case .settings:"))
        #expect(rootSource
            .matches(
                of: /case \.settings:[\s\S]*?SettingsProTab\([\s\S]*?headerLeadingAction: self\.sidebarHeaderLeadingAction,[\s\S]*?ownsNavigationStack: false[\s\S]*?onRouteChange: self\.handleSettingsRouteChange/)
            .count >= 1)
        #expect(rootSource
            .contains(
                "directRoute: self.selectedSettingsRoute ?? self.selectedSidebarDestination.settingsRoute ?? .gateway"))
        #expect(rootSource.contains("ownsNavigationStack: false"))
        #expect(navigationSource.contains("var sidebarNavigationPath: [SettingsRoute]"))
        #expect(navigationSource.contains("state.sidebarNavigationPath.removeAll()"))
        #expect(rootSource.contains("private var sidebarNavigationPathBinding: Binding<[SettingsRoute]>"))
        #expect(rootSource.contains("NavigationStack(path: self.sidebarNavigationPathBinding)"))
        #expect(navigationSource.contains("struct SidebarNavigationPathChange: Equatable, Sendable"))
        #expect(navigationSource.contains("case sidebarNavigationPathChanged(SidebarNavigationPathChange)"))
        #expect(rootSource.contains(".sidebarNavigationPathChanged("))
        #expect(rootSource.contains("RootNavigationSelectionFeature.SidebarNavigationPathChange(path: $0)"))
        #expect(!rootSource.contains("@State private var presentedSheet"))
        #expect(navigationSource.contains("enum PresentedSheet"))
        #expect(navigationSource.contains("case gatewayProblemDetails"))
        #expect(navigationSource.contains("case quickSetup"))
        #expect(navigationSource.contains("var presentedSheet: PresentedSheet?"))
        #expect(navigationSource.contains("var showGatewayProblemDetails: Bool"))
        #expect(navigationSource.contains("self.presentedSheet == .gatewayProblemDetails"))
        #expect(navigationSource.contains("state.presentedSheet = .gatewayProblemDetails"))
        #expect(rootSource.contains(".sheet(item: self.presentedSheetBinding)"))
        #expect(rootSource.contains("case .gatewayProblemDetails:"))
        #expect(rootSource.contains("GatewayProblemDetailsSheet("))
        #expect(rootSource
            .contains("private var presentedSheetBinding: Binding<RootPresentationFeature.PresentedSheet?>"))
        #expect(navigationSource.contains("struct PresentedSheetChange: Equatable, Sendable"))
        #expect(navigationSource.contains("case presentedSheetChanged(PresentedSheetChange)"))
        #expect(rootSource.contains(".presentedSheetChanged("))
        #expect(rootSource.contains("RootPresentationFeature.PresentedSheetChange(sheet: $0)"))
        #expect(!navigationSource.contains("var showGatewayProblemDetails: Bool\n        var sidebarGatewayStatus"))
        #expect(!rootSource.contains("private var gatewayProblemDetailsBinding: Binding<Bool>"))
        #expect(!rootSource.contains(".sheet(isPresented: self.gatewayProblemDetailsBinding)"))
        #expect(navigationSource.contains("struct SidebarGatewayStatusChange: Equatable, Sendable"))
        #expect(navigationSource.contains("case sidebarGatewayStatusChanged(SidebarGatewayStatusChange)"))
        #expect(rootSource.contains(".sidebarGatewayStatusChanged("))
        #expect(rootSource.contains("RootPresentationFeature.SidebarGatewayStatusChange(status: status)"))
        #expect(navigationSource.contains("static func hasExistingGatewayConfig("))
        #expect(navigationSource.contains("GatewaySettingsStore.loadLastGatewayConnection()"))
        #expect(navigationSource.contains("manualGatewayEnabled && !manualHost.isEmpty"))
        #expect(rootSource.contains("RootPresentationFeature.hasExistingGatewayConfig("))
        #expect(!rootSource.contains("GatewaySettingsStore.loadLastGatewayConnection()"))
        #expect(!rootSource.contains("let preferredStableID = self.preferredGatewayStableID"))
        #expect(navigationSource.contains("struct StartupSnapshot: Equatable, Sendable"))
        #expect(navigationSource.contains("struct StartupSnapshotChange: Equatable, Sendable"))
        #expect(navigationSource.contains("case startupSnapshotChanged(StartupSnapshotChange)"))
        #expect(navigationSource.contains(
            "struct StartupPresentationEvaluationRequest: Equatable, Sendable"))
        #expect(navigationSource.contains(
            "case startupPresentationEvaluationRequested(StartupPresentationEvaluationRequest)"))
        #expect(navigationSource.contains("struct AutoOpenSettingsRequest: Equatable, Sendable"))
        #expect(navigationSource.contains("case autoOpenSettingsRequested(AutoOpenSettingsRequest)"))
        #expect(navigationSource.contains("struct OnboardingEvaluationGate: Equatable, Sendable"))
        #expect(navigationSource.contains("struct AutoOpenSettingsGate: Equatable, Sendable"))
        #expect(navigationSource.contains("var onboardingEvaluationGate: OnboardingEvaluationGate"))
        #expect(navigationSource.contains("var autoOpenSettingsGate: AutoOpenSettingsGate"))
        #expect(navigationSource.contains("state.onboardingEvaluationGate.markEvaluated()"))
        #expect(navigationSource.contains("state.autoOpenSettingsGate.markOpened()"))
        #expect(navigationSource.contains("struct GatewayConnection: Equatable, Sendable"))
        #expect(navigationSource.contains("var gatewayConnection: GatewayConnection"))
        #expect(navigationSource.contains("if snapshot.gatewayConnection.isConnected"))
        #expect(navigationSource.contains("guard !snapshot.gatewayConnection.isConnected"))
        #expect(rootSource.contains("gatewayConnection: .init(isConnected: self.appModel.gatewayServerName != nil)"))
        #expect(navigationSource.contains("struct GatewayConfigPresence: Equatable, Sendable"))
        #expect(navigationSource.contains("var gatewayConfigPresence: GatewayConfigPresence"))
        #expect(navigationSource.contains("if !snapshot.gatewayConfigPresence.hasExistingConfig"))
        #expect(navigationSource.contains("guard !snapshot.gatewayConfigPresence.hasExistingConfig"))
        #expect(rootSource.contains("gatewayConfigPresence: .init(hasExistingConfig: self.hasExistingGatewayConfig())"))
        #expect(navigationSource.contains("struct ConnectionHistory: Equatable, Sendable"))
        #expect(navigationSource.contains("var connectionHistory: ConnectionHistory"))
        #expect(navigationSource.contains("!snapshot.connectionHistory.hasConnectedOnce"))
        #expect(rootSource.contains("connectionHistory: .init(hasConnectedOnce: self.hasConnectedOnce)"))
        #expect(navigationSource.contains("struct OnboardingCompletion: Equatable, Sendable"))
        #expect(navigationSource.contains("var onboardingCompletion: OnboardingCompletion"))
        #expect(navigationSource.contains("!snapshot.onboardingCompletion.isComplete"))
        #expect(rootSource.contains("onboardingCompletion: .init(isComplete: self.onboardingComplete)"))
        #expect(navigationSource.contains("struct LaunchOnboardingPresentation: Equatable, Sendable"))
        #expect(navigationSource.contains("var launchOnboardingPresentation: LaunchOnboardingPresentation"))
        #expect(navigationSource.contains("snapshot.launchOnboardingPresentation.shouldPresent"))
        #expect(rootSource.contains("launchOnboardingPresentation: .init(shouldPresent: shouldPresentOnLaunch)"))
        #expect(navigationSource.contains("struct QuickSetupDismissal: Equatable, Sendable"))
        #expect(navigationSource.contains("var quickSetupDismissal: QuickSetupDismissal"))
        #expect(navigationSource.contains("guard !snapshot.quickSetupDismissal.isDismissed"))
        #expect(rootSource.contains("quickSetupDismissal: .init(isDismissed: self.quickSetupDismissed)"))
        #expect(navigationSource.contains("var onboardingPresentation: OnboardingPresentation"))
        #expect(navigationSource.contains("guard !snapshot.onboardingPresentation.isPresented"))
        #expect(rootSource.contains("onboardingPresentation: self.presentationStore.onboardingPresentation"))
        #expect(!navigationSource.contains("var gatewayConnected: Bool"))
        #expect(!navigationSource.contains("var hasExistingGatewayConfig: Bool"))
        #expect(!navigationSource.contains("var onboardingComplete: Bool"))
        #expect(!navigationSource.contains("var shouldPresentOnLaunch: Bool"))
        #expect(!navigationSource.contains("var quickSetupDismissed: Bool"))
        #expect(!navigationSource.contains("var showOnboarding: Bool"))
        #expect(!navigationSource.contains("if snapshot.gatewayConnected"))
        #expect(!navigationSource.contains("guard !snapshot.gatewayConnected"))
        #expect(!navigationSource.contains("if !snapshot.hasExistingGatewayConfig"))
        #expect(!navigationSource.contains("guard !snapshot.hasExistingGatewayConfig"))
        #expect(!navigationSource.contains("!snapshot.hasConnectedOnce"))
        #expect(!navigationSource.contains("!snapshot.onboardingComplete"))
        #expect(!navigationSource.contains("snapshot.shouldPresentOnLaunch"))
        #expect(!navigationSource.contains("snapshot.quickSetupDismissed"))
        #expect(!navigationSource.contains("snapshot.showOnboarding"))
        #expect(!navigationSource.contains("var didEvaluateOnboarding: Bool"))
        #expect(!navigationSource.contains("var didAutoOpenSettings: Bool"))
        #expect(!navigationSource.contains("state.didEvaluateOnboarding = true"))
        #expect(!navigationSource.contains("state.didAutoOpenSettings = true"))
        #expect(rootSource.contains("private func makeStartupSnapshot("))
        #expect(rootSource.contains("RootPresentationFeature.StartupPresentationEvaluationRequest("))
        #expect(rootSource.contains("RootPresentationFeature.AutoOpenSettingsRequest(snapshot: startupSnapshot)"))
        #expect(navigationSource.contains("struct QuickSetupSnapshot: Equatable, Sendable"))
        #expect(navigationSource.contains("struct QuickSetupSnapshotChange: Equatable, Sendable"))
        #expect(navigationSource.contains("struct QuickSetupPresentationDecision: Equatable, Sendable"))
        #expect(navigationSource.contains("struct DiscoveredGatewayCount: Equatable, Sendable"))
        #expect(navigationSource.contains("var quickSetupPresentationDecision: QuickSetupPresentationDecision"))
        #expect(navigationSource.contains("var discoveredGatewayCount: DiscoveredGatewayCount"))
        #expect(navigationSource.contains("state.quickSetupPresentationDecision.shouldPresent"))
        #expect(navigationSource.contains("return snapshot.discoveredGatewayCount.hasDiscoveredGateway"))
        #expect(rootSource.contains("discoveredGatewayCount: .init(value: self.gatewayController.gateways.count)"))
        #expect(!navigationSource.contains("var shouldPresentQuickSetup: Bool"))
        #expect(!navigationSource.contains("state.shouldPresentQuickSetup"))
        #expect(!navigationSource.contains("var discoveredGatewayCount: Int"))
        #expect(!navigationSource.contains("return snapshot.discoveredGatewayCount > 0"))
        #expect(navigationSource.contains("case quickSetupSnapshotChanged(QuickSetupSnapshotChange)"))
        #expect(navigationSource.contains("snapshot: RootPresentationFeature.QuickSetupSnapshot"))
        #expect(rootSource.contains(".quickSetupSnapshotChanged("))
        #expect(rootSource.contains("RootPresentationFeature.QuickSetupSnapshotChange("))
        #expect(navigationSource.contains("struct GatewaySetupRequest: Equatable, Sendable"))
        #expect(navigationSource.contains("struct GatewaySetupRequestID: Equatable, Sendable"))
        #expect(navigationSource.contains("var requestID: GatewaySetupRequestID"))
        #expect(navigationSource.contains("var handledGatewaySetupRequestID: GatewaySetupRequestID"))
        #expect(navigationSource.contains("guard !request.requestID.isUnset"))
        #expect(!navigationSource.contains("var handledGatewaySetupRequestID: Int"))
        #expect(!navigationSource.contains("var requestID: Int"))
        #expect(!navigationSource.contains("guard request.requestID != 0"))
        #expect(navigationSource.contains("case gatewaySetupRequestChanged(GatewaySetupRequest)"))
        #expect(rootSource.contains(".gatewaySetupRequestChanged(RootPresentationFeature.GatewaySetupRequest("))
        #expect(rootSource.contains("requestID: .init(value: self.appModel.gatewaySetupRequestID)"))
        #expect(navigationSource.contains("struct RootLocalNetworkAccessReason: Equatable, Sendable"))
        #expect(navigationSource.contains("struct LocalNetworkAccessRequest: Equatable, Sendable"))
        #expect(navigationSource.contains("var reason: RootLocalNetworkAccessReason"))
        #expect(navigationSource.contains("case localNetworkAccessRequested(LocalNetworkAccessRequest)"))
        #expect(rootSource.contains(".localNetworkAccessRequested(RootPresentationFeature.LocalNetworkAccessRequest("))
        #expect(navigationSource.contains("struct LocalNetworkAccessCommand: Equatable, Sendable"))
        #expect(navigationSource.contains("case requestLocalNetworkAccess(LocalNetworkAccessCommand)"))
        #expect(navigationSource.contains(
            "case openGatewaySettingsAndRequestLocalNetworkAccess(LocalNetworkAccessCommand)"))
        #expect(navigationSource.contains("struct OnboardingVisibilityChange: Equatable, Sendable"))
        #expect(navigationSource.contains("case onboardingVisibilityChanged(OnboardingVisibilityChange)"))
        #expect(rootSource.contains(".onboardingVisibilityChanged(RootPresentationFeature.OnboardingVisibilityChange("))
        #expect(navigationSource.contains("struct SceneActivity: Equatable, Sendable"))
        #expect(navigationSource.contains("struct OnboardingPresentation: Equatable, Sendable"))
        #expect(navigationSource.contains("struct OnboardingSkipAvailability: Equatable, Sendable"))
        #expect(navigationSource.contains("var sceneActivity: SceneActivity"))
        #expect(navigationSource.contains("var presentation: OnboardingPresentation"))
        #expect(navigationSource.contains("var onboardingSkipAvailability: OnboardingSkipAvailability"))
        #expect(rootSource.contains("allowSkip: self.presentationStore.onboardingSkipAvailability.allowsSkip"))
        #expect(navigationSource.contains("guard request.sceneActivity.isActive else"))
        #expect(navigationSource.contains("state.onboardingPresentation = change.presentation"))
        #expect(rootSource.contains("self.presentationStore.onboardingPresentation.isPresented"))
        #expect(navigationSource.contains("!change.presentation.isPresented"))
        #expect(navigationSource.contains("change.sceneActivity.isActive"))
        #expect(rootSource.contains("sceneActivity: .init(isActive: self.scenePhase == .active)"))
        #expect(rootSource.contains("presentation: .init(isPresented: isPresented)"))
        #expect(!navigationSource.contains(
            "struct LocalNetworkAccessRequest: Equatable, Sendable {\n        var reason: RootLocalNetworkAccessReason\n        var sceneActive: Bool"))
        #expect(!navigationSource.contains(
            "struct OnboardingVisibilityChange: Equatable, Sendable {\n        var isPresented: Bool\n        var sceneActive: Bool"))
        #expect(!navigationSource.contains("var onboardingAllowSkip: Bool"))
        #expect(!rootSource.contains("allowSkip: self.presentationStore.onboardingAllowSkip"))
        #expect(!navigationSource.contains("guard request.sceneActive else"))
        #expect(!navigationSource.contains("state.showOnboarding = change.isPresented"))
        #expect(!navigationSource.contains("state.showOnboarding = change.presentation.isPresented"))
        #expect(!navigationSource.contains("guard wasPresented, !change.isPresented else"))
        #expect(rootSource.matches(of: /SettingsProTab\(\s*initialRoute: self\.selectedSettingsRoute,/).count == 1)
        #expect(rootSource.contains(".id(self.settingsTabViewID)"))
        #expect(navigationSource.contains("struct LayoutModeResolution: Equatable, Sendable"))
        #expect(navigationSource.contains("case layoutModeResolved(LayoutModeResolution)"))
        #expect(rootSource.contains(".layoutModeResolved(RootSidebarFeature.LayoutModeResolution("))
        #expect(navigationSource.contains("struct VisibilityChange: Equatable, Sendable"))
        #expect(navigationSource.contains("case visibilityChanged(VisibilityChange)"))
        #expect(rootSource.contains(".visibilityChanged(RootSidebarFeature.VisibilityChange("))
        #expect(navigationSource.contains("struct LayoutResolutionForce: Equatable, Sendable"))
        #expect(navigationSource.contains("struct SidebarVisibility: Equatable, Sendable"))
        #expect(navigationSource.contains("struct SidebarUserOverride: Equatable, Sendable"))
        #expect(navigationSource.contains("struct LayoutResolutionState: Equatable, Sendable"))
        #expect(sidebarState.contains("var visibility: SidebarVisibility"))
        #expect(sidebarState.contains("var userOverride: SidebarUserOverride"))
        #expect(sidebarState.contains("var layoutResolution: LayoutResolutionState"))
        #expect(navigationSource.contains("var force: LayoutResolutionForce"))
        #expect(navigationSource.contains("var visibility: SidebarVisibility"))
        #expect(navigationSource.contains("guard resolution.force.isForced || !state.userOverride.value"))
        #expect(navigationSource.contains("state.visibility = change.visibility"))
        #expect(rootSource.contains("self.sidebarStore.visibility.isVisible"))
        #expect(rootSource.contains("force: .init(isForced: force)"))
        #expect(rootSource.contains("visibility: .init(isVisible: isVisible)"))
        #expect(!navigationSource.contains(
            "struct LayoutModeResolution: Equatable, Sendable {\n        var layoutMode: RootTabs.SidebarLayoutMode\n        var force: Bool"))
        #expect(!navigationSource.contains(
            "struct VisibilityChange: Equatable, Sendable {\n        var isVisible: Bool"))
        #expect(!sidebarState.contains("var isVisible: Bool"))
        #expect(!sidebarState.contains("var userOverridden: Bool"))
        #expect(!sidebarState.contains("var didResolveLayout: Bool"))
        #expect(!navigationSource.contains("guard resolution.force || !state.userOverridden"))
        #expect(!navigationSource.contains("state.isVisible = change.isVisible"))
        #expect(!navigationSource.contains("state.isVisible = change.visibility.isVisible"))
        #expect(!rootSource.contains("self.sidebarStore.isVisible"))
        #expect(rootSource.contains("@State private var navigationStore: StoreOf<RootNavigationSelectionFeature>"))
        #expect(navigationSource.contains("struct RootNavigationSelectionFeature"))
        #expect(navigationSource.contains("struct SettingsRouteRequestID: Equatable, Sendable"))
        #expect(navigationSource.contains("struct ExecApprovalPromptSuppressionID: Equatable, Sendable"))
        #expect(navigationSource.contains("var selectedSettingsRouteRequestID: SettingsRouteRequestID"))
        #expect(navigationSource.contains(
            "var notificationSettingsPromptSuppression: ExecApprovalPromptSuppressionID?"))
        #expect(navigationSource.contains("state.selectedSettingsRouteRequestID.bump()"))
        #expect(rootSource.contains("self.navigationStore.selectedSettingsRouteRequestID.value"))
        #expect(!navigationSource.contains("var selectedSettingsRouteRequestID: Int"))
        #expect(!navigationSource.contains("var suppressedExecApprovalPromptIDForNotificationSettings: String?"))
        #expect(!navigationSource.contains("state.selectedSettingsRouteRequestID &+= 1"))
        #expect(navigationSource.contains("struct TabSelection: Equatable, Sendable"))
        #expect(navigationSource.contains("case tabSelected(TabSelection)"))
        #expect(rootSource.contains(".tabSelected("))
        #expect(rootSource.contains("RootNavigationSelectionFeature.TabSelection(tab: $0)"))
        #expect(navigationSource.contains("struct SidebarDestinationSelection: Equatable, Sendable"))
        #expect(navigationSource.contains("case sidebarDestinationSelected(SidebarDestinationSelection)"))
        #expect(rootSource.contains(".sidebarDestinationSelected("))
        #expect(rootSource.contains("RootNavigationSelectionFeature.SidebarDestinationSelection("))
        #expect(rootSource.contains("destination: destination"))
        #expect(navigationSource.contains("struct SettingsRouteSelection: Equatable, Sendable"))
        #expect(navigationSource.contains("case settingsRouteSelected(SettingsRouteSelection)"))
        #expect(rootSource.contains(".settingsRouteSelected("))
        #expect(rootSource.contains("RootNavigationSelectionFeature.SettingsRouteSelection(route: route)"))
        #expect(rootSource.contains("private var activeExecApprovalPromptSuppressionID: String?"))
        #expect(rootSource.contains("self.navigationStore.activeExecApprovalPromptSuppressionID"))
        #expect(rootSource.contains("suppressedApprovalID: self.activeExecApprovalPromptSuppressionID"))
        #expect(navigationSource.contains("struct NotificationPermissionSettingsRequest: Equatable, Sendable"))
        #expect(navigationSource.contains("var suppressedApprovalID: ExecApprovalPromptSuppressionID"))
        #expect(navigationSource.contains(
            "case notificationPermissionSettingsOpened(NotificationPermissionSettingsRequest)"))
        #expect(rootSource
            .contains("""
            .notificationPermissionSettingsOpened(
                        RootNavigationSelectionFeature.NotificationPermissionSettingsRequest(
            """))
        #expect(navigationSource.contains("struct PendingExecApprovalPromptChange: Equatable, Sendable"))
        #expect(navigationSource.contains("var promptID: ExecApprovalPromptSuppressionID?"))
        #expect(navigationSource.contains("case pendingExecApprovalPromptChanged(PendingExecApprovalPromptChange)"))
        #expect(rootSource.contains(".pendingExecApprovalPromptChanged("))
        #expect(rootSource.contains(
            "RootNavigationSelectionFeature.ExecApprovalPromptSuppressionID(value: $0)"))
        #expect(navigationSource.contains("if destination.settingsRoute != .notifications"))
        #expect(navigationSource.contains("if route != .notifications"))
        #expect(navigationSource.contains("if route == nil"))
        #expect(navigationSource.contains("state.selectedSettingsRoute = nil"))
        #expect(navigationSource.contains("state.selectedSidebarDestination = .settings"))
        #expect(rootSource.contains("func openNotificationSettings(suppressedApprovalID: String)"))
        #expect(storesSource.contains("self.openNotificationSettings(suppressedApprovalID: approvalId)"))
        #expect(navigationSource.contains("struct SettingsRouteChange: Equatable, Sendable"))
        #expect(navigationSource.contains("case settingsRouteChanged(SettingsRouteChange)"))
        #expect(rootSource.contains(".settingsRouteChanged("))
        #expect(rootSource.contains("RootNavigationSelectionFeature.SettingsRouteChange(route: route)"))
        #expect(navigationSource.contains("struct SidebarSettingsRoutePush: Equatable, Sendable"))
        #expect(navigationSource.contains("case sidebarSettingsRoutePushed(SidebarSettingsRoutePush)"))
        #expect(rootSource.contains(".sidebarSettingsRoutePushed("))
        #expect(rootSource.contains("RootNavigationSelectionFeature.SidebarSettingsRoutePush(route: route)"))
        #expect(rootSource.contains("onRouteChange: self.handleSettingsRouteChange"))
        #expect(rootSource.contains("navigateToRoute: self.pushSidebarSettingsRoute"))
        #expect(rootSource.contains("private func pushSidebarSettingsRoute(_ route: SettingsRoute)"))
        #expect(settingsTabSource.contains("let navigateToRoute: ((SettingsRoute) -> Void)?"))
        #expect(settingsTabSource.contains("navigateToRoute(.notifications)"))
        #expect(settingsTabSource.contains("NavigationStack(path: self.navigationPathBinding)"))
        #expect(settingsTabSource.contains("struct InitialRouteRequest: Equatable, Sendable"))
        #expect(settingsTabSource.contains("struct NavigationPathChange: Equatable, Sendable"))
        #expect(settingsTabSource.contains("struct RouteOpenRequest: Equatable, Sendable"))
        #expect(settingsTabSource.contains("case initialRouteRequested(InitialRouteRequest)"))
        #expect(settingsTabSource.contains("case navigationPathChanged(NavigationPathChange)"))
        #expect(settingsTabSource.contains("case routeOpened(RouteOpenRequest)"))
        #expect(settingsTabSource.contains(
            "set: { self.navigationStore.send(.navigationPathChanged(.init(path: $0))) }"))
        #expect(settingsTabSource.contains("self.navigationStore.send(.routeOpened(.init(route: .notifications)))"))
        #expect(settingsTabSource.contains(
            "self.navigationStore.send(.initialRouteRequested(.init(route: self.initialRoute)))"))
        #expect(rootSource.contains("private func handleSettingsRouteChange(_ route: SettingsRoute?)"))
        #expect(settingsTabSource.contains("let onRouteChange: ((SettingsRoute?) -> Void)?"))
        #expect(settingsTabSource.contains("self.onRouteChange?(self.navigationStore.navigationPath.last)"))
        #expect(notificationGuidanceSource.contains("onSuppressFuture"))
        #expect(notificationGuidanceSource.contains("suppressFuture: true"))
        #expect(notificationGuidanceSource.contains("Text(\"Don't show again\")"))
        #expect(rootSource.contains("private func selectSettingsRoute(_ route: SettingsRoute)"))
        #expect(settingsSource.contains("title: \"Channels\""))
        #expect(settingsSource.contains("route: .channels"))
        #expect(docsSource.contains(".accessibilityHint(\"Opens Settings / Gateway\")"))
    }

    @Test func `push enrollment stays behind notification disclosure flow`() throws {
        let appSource = try String(contentsOf: Self.openClawAppSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let modelSource = try String(contentsOf: Self.nodeAppModelSourceURL(), encoding: .utf8)
        let pushConsentSource = try String(contentsOf: Self.pushEnrollmentConsentSourceURL(), encoding: .utf8)
        let notificationSource = try String(contentsOf: Self.settingsNotificationFeatureSourceURL(), encoding: .utf8)
        let pushConsentState = try Self.extract(
            pushConsentSource,
            from: "struct State: Equatable, Sendable {",
            to: "enum Action")

        #expect(appSource.contains("PushEnrollmentConsent.disclosureAccepted"))
        #expect(appSource.contains("await Self.isNotificationAuthorizationAllowed()"))
        #expect(pushConsentSource.contains("struct PushEnrollmentDisclosureAccepted: Equatable, Sendable"))
        #expect(pushConsentState.contains("var disclosureAccepted: PushEnrollmentDisclosureAccepted"))
        #expect(pushConsentSource.contains("state.disclosureAccepted = .init(value: consent.disclosureAccepted())"))
        #expect(pushConsentSource.contains("state.disclosureAccepted = .init(value: true)"))
        #expect(pushConsentSource.contains("state.disclosureAccepted = .init(value: false)"))
        #expect(actionsSource.contains("self.pushEnrollmentConsentStore.send(.acceptDisclosure)"))
        #expect(actionsSource.contains("self.pushEnrollmentConsentStore.disclosureAccepted.value"))
        #expect(actionsSource.contains("self.registerForRemoteNotificationsIfEnrollmentReady()"))
        #expect(actionsSource.contains("self.notificationStore.send(.remoteRegistrationRequested(.init("))
        #expect(actionsSource.contains("UIApplication.shared.registerForRemoteNotifications()") == false)
        #expect(actionsSource.contains("guard self.notificationStore.status.allowsNotifications") == false)
        #expect(notificationSource.contains("struct SettingsNotificationRegistrationClient"))
        #expect(notificationSource.contains("struct RemoteRegistrationRequest: Equatable, Sendable"))
        #expect(notificationSource.contains("struct RemoteRegistrationDisclosureAccepted: Equatable, Sendable"))
        #expect(notificationSource.contains("var disclosureAccepted: RemoteRegistrationDisclosureAccepted"))
        #expect(notificationSource.contains("guard request.disclosureAccepted.value"))
        #expect(notificationSource.contains("case remoteRegistrationRequested(RemoteRegistrationRequest)"))
        #expect(notificationSource.contains("await registrationClient.registerForRemoteNotifications()"))
        #expect(!pushConsentState.contains("var disclosureAccepted: Bool"))
        #expect(!pushConsentSource.contains("state.disclosureAccepted = true"))
        #expect(!pushConsentSource.contains("state.disclosureAccepted = false"))
        #expect(!actionsSource.contains("value: self.pushEnrollmentConsentStore.disclosureAccepted)"))
        #expect(modelSource.contains("PushEnrollmentConsent.disclosureAccepted"))
        #expect(modelSource.contains("notifications_not_authorized"))
        #expect(modelSource.contains("enrollment_disclosure_not_accepted"))
    }

    @Test func `settings approvals sync action is typed`() throws {
        let settingsSource = try Self.settingsProTabCombinedSource()
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let approvalsFeature = try Self.extract(
            settingsSource,
            from: "struct SettingsApprovalsFeature",
            to: "@Reducer\nstruct SettingsGatewayCredentialsFeature")
        let approvalsSync = try Self.extract(
            approvalsFeature,
            from: "struct ApprovalsSync",
            to: "case approvalsSynced")

        #expect(settingsSource.contains(
            "struct SettingsApprovalsDemoModeEnabled: Equatable, Sendable { var value: Bool }"))
        #expect(settingsSource.contains(
            "struct SettingsApprovalsGatewayConnected: Equatable, Sendable { var value: Bool }"))
        #expect(settingsSource.contains(
            "struct SettingsApprovalsNotificationsNeedAttention: Equatable, Sendable { var value: Bool }"))
        #expect(settingsSource.contains(
            "struct SettingsApprovalsHasPendingApproval: Equatable, Sendable { var value: Bool }"))
        #expect(settingsSource.contains(
            "struct SettingsApprovalsPendingCommandPreview: Equatable, Sendable { var value: String? }"))
        #expect(settingsSource.contains(
            "struct SettingsApprovalsActiveAgentName: Equatable, Sendable { var value: String }"))
        #expect(settingsSource.contains(
            "struct SettingsApprovalsResolvingPendingApproval: Equatable, Sendable { var value: Bool }"))
        #expect(settingsSource.contains(
            "struct SettingsApprovalsPendingApprovalAllowsAllowAlways: Equatable, Sendable { var value: Bool }"))
        #expect(settingsSource.contains("struct ApprovalsSync: Equatable, Sendable"))
        #expect(approvalsFeature.contains(
            "var activeAgentName = Action.SettingsApprovalsActiveAgentName(value: \"Default Agent\")"))
        #expect(approvalsFeature.contains(
            "var gatewayConnected = Action.SettingsApprovalsGatewayConnected(value: false)"))
        #expect(approvalsFeature.contains(
            "var hasPendingApproval = Action.SettingsApprovalsHasPendingApproval(value: false)"))
        #expect(approvalsFeature.contains(
            "var isAppleReviewDemoModeEnabled = Action.SettingsApprovalsDemoModeEnabled(value: false)"))
        #expect(approvalsFeature.contains(
            "var isResolvingPendingApproval = Action.SettingsApprovalsResolvingPendingApproval(value: false)"))
        #expect(approvalsFeature.contains(
            "var notificationsNeedAttention = Action.SettingsApprovalsNotificationsNeedAttention(value: false)"))
        #expect(approvalsFeature.contains(
            "var pendingApprovalAllowsAllowAlways = Action.SettingsApprovalsPendingApprovalAllowsAllowAlways(value: false)"))
        #expect(approvalsFeature.contains(
            "var pendingCommandPreview = Action.SettingsApprovalsPendingCommandPreview(value: nil)"))
        #expect(approvalsSync.contains("var isAppleReviewDemoModeEnabled: SettingsApprovalsDemoModeEnabled"))
        #expect(approvalsSync.contains("var gatewayConnected: SettingsApprovalsGatewayConnected"))
        #expect(approvalsSync.contains(
            "var notificationsNeedAttention: SettingsApprovalsNotificationsNeedAttention"))
        #expect(approvalsSync.contains("var hasPendingApproval: SettingsApprovalsHasPendingApproval"))
        #expect(approvalsSync.contains("var pendingCommandPreview: SettingsApprovalsPendingCommandPreview"))
        #expect(approvalsSync.contains("var activeAgentName: SettingsApprovalsActiveAgentName"))
        #expect(approvalsSync.contains(
            "var isResolvingPendingApproval: SettingsApprovalsResolvingPendingApproval"))
        #expect(approvalsSync.contains(
            "var pendingApprovalAllowsAllowAlways: SettingsApprovalsPendingApprovalAllowsAllowAlways"))
        #expect(approvalsFeature.contains(
            "state.isAppleReviewDemoModeEnabled = sync.isAppleReviewDemoModeEnabled"))
        #expect(approvalsFeature.contains("state.gatewayConnected = sync.gatewayConnected"))
        #expect(approvalsFeature.contains(
            "state.notificationsNeedAttention = sync.notificationsNeedAttention"))
        #expect(approvalsFeature.contains("state.hasPendingApproval = sync.hasPendingApproval"))
        #expect(approvalsFeature.contains("state.pendingCommandPreview = sync.pendingCommandPreview"))
        #expect(approvalsFeature.contains("state.activeAgentName = sync.activeAgentName"))
        #expect(approvalsFeature.contains(
            "state.isResolvingPendingApproval = sync.isResolvingPendingApproval"))
        #expect(approvalsFeature.contains(
            "state.pendingApprovalAllowsAllowAlways = sync.pendingApprovalAllowsAllowAlways"))
        #expect(settingsSource.contains("case approvalsSynced(ApprovalsSync)"))
        #expect(actionsSource.contains("self.approvalsStore.send(.approvalsSynced(.init("))
        #expect(actionsSource.contains(
            "isAppleReviewDemoModeEnabled: .init(value: self.appModel.isAppleReviewDemoModeEnabled)"))
        #expect(actionsSource.contains("gatewayConnected: .init(value: self.gatewayConnected)"))
        #expect(actionsSource.contains(
            "notificationsNeedAttention: .init(value: self.notificationStore.needsAttention)"))
        #expect(actionsSource.contains("hasPendingApproval: .init(value: pendingApproval != nil)"))
        #expect(actionsSource.contains(
            "pendingCommandPreview: .init(value: pendingApproval?.commandPreview)"))
        #expect(actionsSource.contains("activeAgentName: .init(value: self.appModel.activeAgentName)"))
        #expect(actionsSource.contains(
            "isResolvingPendingApproval: .init(value: self.appModel.pendingExecApprovalPromptResolving)"))
        #expect(actionsSource.contains(
            "pendingApprovalAllowsAllowAlways: .init(value: pendingApproval?.allowsAllowAlways ?? false)"))
        #expect(actionsSource.contains("self.approvalsStore.notificationsNeedAttention.value"))
        #expect(!approvalsFeature.contains("var isAppleReviewDemoModeEnabled: Bool"))
        #expect(!approvalsSync.contains("var gatewayConnected: Bool"))
        #expect(!approvalsSync.contains("var notificationsNeedAttention: Bool"))
        #expect(!approvalsSync.contains("var hasPendingApproval: Bool"))
        #expect(!approvalsSync.contains("var pendingCommandPreview: String?"))
        #expect(!approvalsSync.contains("var activeAgentName: String"))
        #expect(!approvalsSync.contains("var isResolvingPendingApproval: Bool"))
        #expect(!approvalsSync.contains("var pendingApprovalAllowsAllowAlways: Bool"))
        #expect(!approvalsFeature.contains("var activeAgentName = \"Default Agent\""))
        #expect(!approvalsFeature.contains("var gatewayConnected = false"))
        #expect(!approvalsFeature.contains("var hasPendingApproval = false"))
        #expect(!approvalsFeature.contains("var isAppleReviewDemoModeEnabled = false"))
        #expect(!approvalsFeature.contains("var isResolvingPendingApproval = false"))
        #expect(!approvalsFeature.contains("var notificationsNeedAttention = false"))
        #expect(!approvalsFeature.contains("var pendingApprovalAllowsAllowAlways = false"))
        #expect(!approvalsFeature.contains("var pendingCommandPreview: String?"))
        #expect(!approvalsFeature.contains(
            "state.isAppleReviewDemoModeEnabled = sync.isAppleReviewDemoModeEnabled.value"))
        #expect(!approvalsFeature.contains("state.gatewayConnected = sync.gatewayConnected.value"))
        #expect(!approvalsFeature.contains(
            "state.notificationsNeedAttention = sync.notificationsNeedAttention.value"))
        #expect(!approvalsFeature.contains("state.hasPendingApproval = sync.hasPendingApproval.value"))
        #expect(!approvalsFeature.contains("state.pendingCommandPreview = sync.pendingCommandPreview.value"))
        #expect(!approvalsFeature.contains("state.activeAgentName = sync.activeAgentName.value"))
        #expect(!approvalsFeature.contains(
            "state.isResolvingPendingApproval = sync.isResolvingPendingApproval.value"))
        #expect(!approvalsFeature.contains(
            "state.pendingApprovalAllowsAllowAlways = sync.pendingApprovalAllowsAllowAlways.value"))
        #expect(!actionsSource.contains("self.approvalsStore.notificationsNeedAttention\n"))
    }

    @Test func `gateway settings keeps pairing trust diagnostics and tailscale actions`() throws {
        let settingsSource = try Self.settingsProTabCombinedSource()
        let activitySource = try String(contentsOf: Self.settingsGatewayActivityFeatureSourceURL(), encoding: .utf8)
        let gatewaySetupFeaturesSource = try String(
            contentsOf: Self.settingsGatewaySetupFeaturesSourceURL(),
            encoding: .utf8)
        let sectionsSource = try String(contentsOf: Self.settingsProTabSectionsSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let supportSource = try String(contentsOf: Self.settingsProTabSupportSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let trustSource = try String(contentsOf: Self.gatewayTrustPromptAlertSourceURL(), encoding: .utf8)
        let controllerSource = try String(contentsOf: Self.gatewayConnectionControllerSourceURL(), encoding: .utf8)
        let reconnectFunction = try Self.extract(
            actionsSource,
            from: "func reconnectGateway() async",
            to: "@MainActor\n    func runDiagnostics() async")
        let problemReconnectFunction = try Self.extract(
            actionsSource,
            from: "func retryGatewayConnectionFromProblem() async",
            to: "func gatewayProblemPrimaryActionTitle")
        let gatewayProblemPrimaryActionFunction = try Self.extract(
            actionsSource,
            from: "func handleGatewayProblemPrimaryAction(_ problem: GatewayConnectionProblem) async",
            to: "func handleLocationModeRequest")

        #expect(sectionsSource.contains("var gatewayDestination: some View"))
        #expect(sectionsSource.contains("self.gatewayActions"))
        #expect(sectionsSource.contains("self.manualGatewayCard"))
        #expect(sectionsSource.contains("self.gatewaySetupCard"))
        #expect(sectionsSource.contains("self.discoveredGatewaysCard"))
        #expect(sectionsSource.contains("self.gatewayAdvancedCard"))
        #expect(sectionsSource.contains("title: \"Reconnect\""))
        #expect(sectionsSource.contains("Task { await self.reconnectGateway() }"))
        #expect(sectionsSource.contains("title: \"Diagnose\""))
        #expect(sectionsSource.contains("Task { await self.runDiagnostics() }"))
        #expect(sectionsSource.contains("title: \"Scan QR\""))
        #expect(sectionsSource.contains("Task { await self.openGatewayQRScanner() }"))
        #expect(sectionsSource.contains("title: \"Connect\""))
        #expect(sectionsSource.contains("Task { await self.applySetupCodeAndConnect() }"))
        #expect(sectionsSource.contains("Task { await self.connect(gateway) }"))
        #expect(sectionsSource.contains("tailnetWarningText"))
        #expect(sectionsSource.contains("GatewayProblemBanner("))
        #expect(sectionsSource.contains("Task { await self.handleGatewayProblemPrimaryAction(problem) }"))

        #expect(supportSource.contains("struct SettingsGatewayReconnectClient"))
        #expect(supportSource.contains("var settingsGatewayReconnect: SettingsGatewayReconnectClient"))
        #expect(supportSource.contains("struct SettingsGatewayProblemTrustClient"))
        #expect(supportSource.contains("var settingsGatewayProblemTrust: SettingsGatewayProblemTrustClient"))
        #expect(activitySource.contains(
            "struct SettingsGatewayActivityDemoModeEnabled: Equatable, Sendable { var value: Bool }"))
        #expect(activitySource.contains("enum ReconnectPhase: Equatable, Sendable"))
        #expect(activitySource.contains("var reconnectPhase = ReconnectPhase.idle"))
        #expect(activitySource.contains("struct ReconnectRequest: Equatable, Sendable"))
        #expect(activitySource.contains(
            "var isAppleReviewDemoModeEnabled: SettingsGatewayActivityDemoModeEnabled"))
        #expect(activitySource.contains("struct RotatedCertificateTrustRequest: Equatable, Sendable"))
        #expect(activitySource.contains("case reconnectRequested(ReconnectRequest)"))
        #expect(activitySource.contains("case rotatedCertificateTrustRequested(RotatedCertificateTrustRequest)"))
        #expect(activitySource.contains("@Dependency(\\.settingsGatewayReconnect)"))
        #expect(activitySource.contains("@Dependency(\\.settingsGatewayProblemTrust)"))
        #expect(activitySource.contains("await reconnectClient.reconnect()"))
        #expect(activitySource.contains("await send(.reconnectFinished)"))
        #expect(activitySource.contains("!request.isAppleReviewDemoModeEnabled.value"))
        #expect(activitySource.contains("state.reconnectPhase != .inFlight"))
        #expect(activitySource.contains("state.reconnectPhase = .inFlight"))
        #expect(activitySource.contains("state.reconnectPhase = .idle"))
        #expect(activitySource.contains("await problemTrustClient.trustRotatedCertificate(request.problem)"))
        #expect(reconnectFunction.contains("self.gatewayActivityStore"))
        #expect(reconnectFunction.contains("let isAppleReviewDemoModeEnabled = self.appModel.isAppleReviewDemoModeEnabled"))
        #expect(reconnectFunction.contains(
            "isAppleReviewDemoModeEnabled: .init(value: isAppleReviewDemoModeEnabled)"))
        #expect(gatewayProblemPrimaryActionFunction.contains("self.gatewayActivityStore"))
        #expect(gatewayProblemPrimaryActionFunction.contains(
            ".send(.rotatedCertificateTrustRequested(.init(problem: problem)))"))
        #expect(!gatewayProblemPrimaryActionFunction
            .contains("self.gatewayController.trustRotatedGatewayCertificate(from: problem)"))
        #expect(storesSource.contains("reconnectClient: .live(gatewayController: self.gatewayController)"))
        #expect(storesSource.contains("problemTrustClient: .live(gatewayController: self.gatewayController)"))
        #expect(!reconnectFunction.contains("await self.gatewayController.connectLastKnown()"))
        #expect(problemReconnectFunction.contains("await self.connectManual()"))
        #expect(problemReconnectFunction.contains("self.gatewayActivityStore"))
        #expect(problemReconnectFunction.contains(".send(.reconnectRequested(.init("))
        #expect(problemReconnectFunction
            .contains("isAppleReviewDemoModeEnabled: .init(value: self.appModel.isAppleReviewDemoModeEnabled)"))
        #expect(!problemReconnectFunction.contains("await self.gatewayController.connectLastKnown()"))
        #expect(actionsSource.contains("self.gatewayActivityStore"))
        #expect(actionsSource.contains("self.manualGatewayEndpointStore.send(.localNetworkAccessRequested("))
        #expect(!activitySource.contains("struct GatewayReconnectInFlight: Equatable, Sendable"))
        #expect(!activitySource.contains("var isReconnectingGateway = Action.GatewayReconnectInFlight(value: false)"))
        #expect(!activitySource.contains("var isReconnectingGateway = false"))
        #expect(!activitySource.contains(
            "guard !request.isAppleReviewDemoModeEnabled.value, !state.isReconnectingGateway else { return .none }"))
        #expect(!activitySource.contains("!state.isReconnectingGateway.value"))
        #expect(!activitySource.contains("state.isReconnectingGateway = .init(value: true)"))
        #expect(!activitySource.contains("state.isReconnectingGateway = .init(value: false)"))
        #expect(!activitySource.contains("state.isReconnectingGateway = true"))
        #expect(!activitySource.contains("state.isReconnectingGateway = false"))
        #expect(gatewaySetupFeaturesSource
            .contains("state.preflightResult = .requestLocalNetworkAccess(.init(reason: .settingsPreflight))"))
        #expect(controllerSource.contains("await self.tcpReachabilityProbe("))
        #expect(controllerSource.contains("Check Tailscale or LAN."))
        #expect(gatewaySetupFeaturesSource.contains("Tailscale is off on this device. Turn it on, then try again."))
        #expect(gatewaySetupFeaturesSource.contains("Run /pair approve in your OpenClaw chat"))
        #expect(actionsSource.contains("await self.resetOnboarding()"))
        #expect(actionsSource.contains("GatewayProblemPrimaryAction.openProtocolMismatchHelpIfNeeded(problem)"))
        #expect(actionsSource.contains("await self.retryGatewayConnectionFromProblem()"))

        #expect(settingsSource.contains("GatewayProblemDetailsSheet("))
        #expect(settingsSource.contains("QRScannerView("))
        #expect(trustSource.contains("Trust this gateway?"))
        #expect(trustSource.contains("Trust and connect"))
        #expect(controllerSource.contains("acceptPendingTrustPrompt()"))
        #expect(controllerSource.contains("trustRotatedGatewayCertificate(from problem: GatewayConnectionProblem)"))
    }

    @Test func `local network access is requested from visible gateway flows`() throws {
        let appSource = try String(contentsOf: Self.openClawAppSourceURL(), encoding: .utf8)
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let navigationSource = try String(contentsOf: Self.rootTabsNavigationSourceURL(), encoding: .utf8)
        let onboardingSource = try String(contentsOf: Self.onboardingWizardSourceURL(), encoding: .utf8)
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let gatewaySetupFeaturesSource = try String(
            contentsOf: Self.settingsGatewaySetupFeaturesSourceURL(),
            encoding: .utf8)
        let controllerSource = try String(contentsOf: Self.gatewayConnectionControllerSourceURL(), encoding: .utf8)

        #expect(appSource.contains("deferDiscoveryUntilLocalNetworkRequest: true"))
        #expect(controllerSource.contains("func requestLocalNetworkAccess(reason: String)"))
        #expect(controllerSource.contains("guard self.localNetworkAccessRequested else"))
        #expect(controllerSource.contains("self.requestLocalNetworkAccess(reason: \"connect_manual\")"))
        #expect(controllerSource.contains("self.requestLocalNetworkAccess(reason: \"connect_discovered_gateway\")"))
        #expect(controllerSource.contains("self.requestLocalNetworkAccess(reason: \"connect_last_known\")"))

        #expect(rootSource.contains("self.maybeRequestLocalNetworkAccess(reason: .sceneActive)"))
        #expect(rootSource.contains("self.requestLocalNetworkAccess(reason: .init(rawValue: reason))"))
        #expect(rootSource.contains("self.makeSettingsManualGatewayEndpointStore()"))
        #expect(storesSource.contains("SettingsManualGatewayEndpointFeature("))
        #expect(storesSource.contains("localNetworkAccessClient: .live(gatewayController: self.gatewayController))"))
        #expect(rootSource.contains("self.handlePresentationCommand()"))
        #expect(rootSource.contains("self.presentationStore.send(.localNetworkAccessRequested("))
        #expect(rootSource.contains("self.presentationStore.send(.onboardingVisibilityChanged("))
        #expect(navigationSource.contains("reason: .rootAppear"))
        #expect(navigationSource.contains("reason: .gatewaySetupDeeplink"))
        #expect(navigationSource.contains("guard state.onboardingEvaluationGate.didEvaluate else { return .none }"))
        #expect(navigationSource.contains("reason: .onboardingDismissed"))
        #expect(rootSource.contains("onRequestLocalNetworkAccess: { reason in"))

        #expect(onboardingSource.contains("self.requestLocalNetworkAccess(reason: \"onboarding_continue\")"))
        #expect(onboardingSource.contains("self.requestLocalNetworkAccessIfPastIntro(reason: \"onboarding_appear\")"))
        #expect(!onboardingSource.contains("@State private var pendingManualAuthOverride"))
        #expect(!onboardingSource.contains("discoveryRestartTask"))
        #expect(onboardingSource.contains("@State private var discoveryRestartStore"))
        #expect(onboardingSource.contains("self.discoveryRestartStore.send(.disappeared)"))
        #expect(onboardingSource.contains("self.discoveryRestartStore.send(.discoveryDomainChanged)"))
        #expect(onboardingSource.contains("self.discoveryRestartStore.restartRequestID"))
        #expect(onboardingSource.contains("self.credentialsStore.send(.setupAuthApplied(.init(setupAuth: setupAuth)))"))
        #expect(onboardingSource.contains("pendingOverride: self.credentialsStore.pendingManualAuthOverride"))
        #expect(onboardingSource.contains("self.credentialsStore.send(.pendingManualAuthOverrideConsumed)"))
        #expect(onboardingSource.contains("@State private var photoImportStore"))
        #expect(onboardingSource.contains("self.photoImportStore.send(.importStarted)"))
        #expect(onboardingSource
            .contains("self.photoImportStore.send(.qrMessageDetected(.init(message: .init(value: self.detectQRCode(from: data)))))"))
        #expect(onboardingSource.contains("self.handlePhotoImportResult()"))
        #expect(!onboardingSource.contains("GatewayConnectDeepLink.fromSetupInput(message)"))
        #expect(onboardingStateSource
            .contains("var pendingManualAuthOverride: GatewayConnectionController.ManualAuthOverride?"))
        #expect(onboardingStateSource.contains("case setupAuthApplied(SetupAuthApplication)"))
        #expect(onboardingStateSource.contains("struct OnboardingDiscoveryRestartFeature"))
        #expect(onboardingStateSource.contains("struct OnboardingQRPhotoImportFeature"))
        #expect(onboardingStateSource.contains("struct OnboardingQRMessage: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct OnboardingQRPhotoImportFailureMessage: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("enum ImportPhase: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("var importPhase = ImportPhase.idle"))
        #expect(onboardingStateSource.contains("state.importPhase = .inFlight"))
        #expect(onboardingStateSource.contains("state.importPhase = .idle"))
        #expect(onboardingSource.contains(".disabled(self.photoImportStore.importPhase == .inFlight)"))
        #expect(onboardingStateSource.contains("struct QRMessageDetection: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct QRMessageDetection: Equatable, Sendable { var message: OnboardingQRMessage }"))
        #expect(onboardingStateSource.contains("struct AppleReviewSetupCode: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct AppleReviewSetupCode: Equatable, Sendable { var code: OnboardingSetupCode }"))
        #expect(onboardingStateSource.contains("struct Failure: Equatable, Sendable"))
        #expect(onboardingStateSource
            .contains("struct Failure: Equatable, Sendable { var message: OnboardingQRPhotoImportFailureMessage }"))
        #expect(onboardingStateSource.contains("case qrMessageDetected(QRMessageDetection)"))
        #expect(onboardingStateSource.contains("case appleReviewSetupCode(AppleReviewSetupCode)"))
        #expect(onboardingStateSource.contains("case failure(Failure)"))
        #expect(onboardingStateSource.contains("Self.importResult(message: detection.message.value)"))
        #expect(onboardingStateSource.contains(".appleReviewSetupCode(.init(code: .init(value: message)))"))
        #expect(onboardingStateSource.contains(".failure(.init(message: Self.invalidQRCodeMessage))"))
        #expect(onboardingSource.contains(".qrScannerErrorReceived(.init(message: .init(value: failure.message.value)))"))
        #expect(!onboardingStateSource.contains("struct QRMessageDetection: Equatable, Sendable { var message: String? }"))
        #expect(!onboardingStateSource.contains("struct AppleReviewSetupCode: Equatable, Sendable { var code: String }"))
        #expect(!onboardingStateSource.contains("struct Failure: Equatable, Sendable { var message: String }"))
        #expect(!onboardingStateSource.contains("var isImporting = false"))
        #expect(!onboardingStateSource.contains("state.isImporting = true"))
        #expect(!onboardingStateSource.contains("state.isImporting = false"))
        #expect(!onboardingSource.contains(".disabled(self.photoImportStore.isImporting)"))
        #expect(!onboardingStateSource.contains("case appleReviewSetupCode(String)"))
        #expect(!onboardingStateSource.contains("case failure(String)"))
        #expect(!onboardingSource.contains(".qrScannerErrorReceived(.init(message: .init(value: failure.message)))"))
        #expect(onboardingStateSource.contains(".cancellable(id: CancelID.restart, cancelInFlight: true)"))
        #expect(actionsSource.contains("self.manualGatewayEndpointStore.send(.localNetworkAccessRequested("))
        #expect(gatewaySetupFeaturesSource
            .contains("state.preflightResult = .requestLocalNetworkAccess(.init(reason: .settingsPreflight))"))
    }

    @Test func `gateway settings preview matrix covers primary states`() throws {
        let supportSource = try String(contentsOf: Self.settingsProTabSupportSourceURL(), encoding: .utf8)

        #expect(supportSource.contains("#Preview(\"Gateway settings states\")"))
        #expect(supportSource.contains("private struct SettingsGatewayStatesPreview"))
        #expect(supportSource.contains("self.stateSection(\"Connected\")"))
        #expect(supportSource.contains("self.stateSection(\"Loading\")"))
        #expect(supportSource.contains("self.stateSection(\"Empty\")"))
        #expect(supportSource.contains("self.stateSection(\"Error\")"))
        #expect(supportSource.contains("GatewayProblemBanner("))
        #expect(supportSource.contains("kind: .pairingRequired"))
        #expect(supportSource.contains("Run /pair approve in your OpenClaw chat"))
        #expect(supportSource.contains("Tailscale is off on this device. Turn it on, then try again."))
        #expect(supportSource.contains("self.previewButton(\"Scan QR\""))
        #expect(supportSource.contains("self.previewButton(\"Connect\""))
        #expect(supportSource.contains("self.previewButton(\"Reconnect\""))
        #expect(supportSource.contains("self.previewButton(\"Diagnose\""))
    }

    @Test func `native chat uses gateway transport`() throws {
        let chatSource = try String(contentsOf: Self.chatProTabSourceURL(), encoding: .utf8)
        let channelsSource = try String(contentsOf: Self.channelsSourceURL(), encoding: .utf8)
        let settingsSectionsSource = try String(contentsOf: Self.settingsProTabSectionsSourceURL(), encoding: .utf8)
        let appModelSource = try String(contentsOf: Self.nodeAppModelSourceURL(), encoding: .utf8)

        #expect(chatSource.matches(of: /self\.appModel\.makeChatTransport\(\)/).count == 2)
        #expect(chatSource.contains("@Reducer\nstruct ChatViewModelLifecycleFeature"))
        #expect(chatSource
            .contains("@State private var viewModelLifecycleStore: StoreOf<ChatViewModelLifecycleFeature>"))
        #expect(!chatSource.contains("@State private var viewModelTransportModeID"))
        #expect(chatSource.contains("struct ChatTransportModeID: Equatable, Sendable"))
        #expect(chatSource.contains("struct TransportModeRecord: Equatable, Sendable"))
        #expect(chatSource.contains(
            "struct TransportModeRecord: Equatable, Sendable { var transportModeID: ChatTransportModeID }"))
        #expect(chatSource.contains("case transportModeRecorded(TransportModeRecord)"))
        #expect(chatSource.contains("var transportMode = ChatTransportModeID(value: \"\")"))
        #expect(chatSource.contains("var transportModeID: String"))
        #expect(chatSource.contains("self.transportMode.value"))
        #expect(chatSource.contains("state.transportMode = record.transportModeID"))
        #expect(chatSource.contains("self.viewModelLifecycleStore.send(.transportModeRecorded(.init("))
        #expect(chatSource.contains("transportModeID: .init(value: transportModeID))))"))
        #expect(!chatSource.contains("var transportModeID = \"\""))
        #expect(!chatSource.contains("state.transportModeID = record.transportModeID.value"))
        #expect(!chatSource.contains(
            "struct TransportModeRecord: Equatable, Sendable { var transportModeID: String }"))
        #expect(!chatSource.contains("state.transportModeID = record.transportModeID\n"))
        #expect(appModelSource.contains("return IOSGatewayChatTransport(gateway: self.operatorSession)"))
        #expect(settingsSectionsSource.contains("Connected services and message routing"))
        #expect(settingsSectionsSource.contains("SettingsChannelsStoreFactory.live(appModel: self.appModel)"))
        #expect(channelsSource.contains("@Reducer\nstruct SettingsChannelsFeature"))
        #expect(channelsSource.contains("struct SettingsChannelsFailureMessage: Equatable, Sendable"))
        #expect(channelsSource.contains("enum SettingsChannelsLoadingPhase: Equatable, Sendable"))
        #expect(channelsSource.contains("case idle"))
        #expect(channelsSource.contains("case inFlight"))
        #expect(channelsSource.contains(
            "struct Failure: Equatable, Sendable { var message: SettingsChannelsFailureMessage }"))
        #expect(channelsSource.contains("var loadingPhase = SettingsChannelsLoadingPhase.idle"))
        #expect(channelsSource.contains("guard state.loadingPhase != .inFlight else { return .none }"))
        #expect(channelsSource.contains("state.loadingPhase = .inFlight"))
        #expect(channelsSource.contains("state.loadingPhase = .idle"))
        #expect(channelsSource.contains("var errorText: SettingsChannelsFailureMessage?"))
        #expect(channelsSource.contains("case let .failure(.failed(failure)):"))
        #expect(channelsSource.contains("state.errorText = failure.message"))
        #expect(channelsSource.contains(
            "actionIcon: self.store.loadingPhase == .inFlight ? \"hourglass\" : \"arrow.clockwise\""))
        #expect(channelsSource.contains("isActionDisabled: self.store.loadingPhase == .inFlight"))
        #expect(channelsSource.contains("if self.store.loadingPhase == .inFlight, self.store.entries.isEmpty"))
        #expect(channelsSource.contains("if self.store.loadingPhase == .inFlight { return \"Loading\" }"))
        #expect(channelsSource.contains("if self.store.loadingPhase == .inFlight { return \"loading\" }"))
        #expect(channelsSource.contains("detail: errorText.value"))
        #expect(channelsSource.contains("return errorText.value"))
        #expect(channelsSource.contains("struct RefreshRequest: Equatable, Sendable"))
        #expect(channelsSource.contains("struct RefreshResponse: Equatable, Sendable"))
        #expect(channelsSource.contains("struct OperationRequest: Equatable, Sendable"))
        #expect(channelsSource.contains("struct OperationResponse: Equatable, Sendable"))
        #expect(channelsSource.contains("struct SceneActivity: Equatable, Sendable"))
        #expect(channelsSource.contains("struct GatewayReadAccess: Equatable, Sendable"))
        #expect(channelsSource.contains("struct OperatorAdminAccess: Equatable, Sendable"))
        #expect(channelsSource.contains("struct RefreshForce: Equatable, Sendable"))
        #expect(channelsSource.contains("var sceneActivity: SceneActivity"))
        #expect(channelsSource.contains("var readAccess: GatewayReadAccess"))
        #expect(channelsSource.contains("var force: RefreshForce"))
        #expect(channelsSource.contains("var adminAccess: OperatorAdminAccess"))
        #expect(channelsSource.contains("case refreshRequested(RefreshRequest)"))
        #expect(channelsSource.contains("case refreshResponse(RefreshResponse)"))
        #expect(channelsSource.contains("case operationRequested(OperationRequest)"))
        #expect(channelsSource.contains("case operationResponse(OperationResponse)"))
        #expect(channelsSource.contains("case failed(Failure)"))
        #expect(channelsSource.contains("guard request.sceneActivity.isActive"))
        #expect(channelsSource.contains("guard request.readAccess.canRead"))
        #expect(channelsSource.contains("if response.force.isForced || state.entries.isEmpty"))
        #expect(channelsSource.contains("canRead: request.readAccess.canRead"))
        #expect(channelsSource.contains("hasOperatorAdminScope: request.adminAccess.canAdmin"))
        #expect(channelsSource
            .contains("await send(.operationResponse(.init(result: .success(Self.entries(from: snapshot)))))"))
        #expect(channelsSource.contains("result: .failure(Self.failure(for: error))"))
        #expect(channelsSource.contains(
            ".failed(.init(message: .init(value: self.message(for: error))))"))
        #expect(channelsSource.contains("case let .operationResponse(response):"))
        #expect(channelsSource.contains("var message: String"))
        #expect(channelsSource.contains("failure.message.value"))
        #expect(!channelsSource.contains("struct Failure: Equatable, Sendable { var message: String }"))
        #expect(!channelsSource.contains("var isLoading = false"))
        #expect(!channelsSource.contains("struct SettingsChannelsLoadingInFlight: Equatable, Sendable"))
        #expect(!channelsSource.contains("var isLoading = SettingsChannelsLoadingInFlight(value: false)"))
        #expect(!channelsSource.contains("guard !state.isLoading else { return .none }"))
        #expect(!channelsSource.contains("guard !state.isLoading.value else { return .none }"))
        #expect(!channelsSource.contains("state.isLoading = true"))
        #expect(!channelsSource.contains("state.isLoading = false"))
        #expect(!channelsSource.contains("state.isLoading = .init(value: true)"))
        #expect(!channelsSource.contains("state.isLoading = .init(value: false)"))
        #expect(!channelsSource.contains("actionIcon: self.store.isLoading ?"))
        #expect(!channelsSource.contains("actionIcon: self.store.isLoading.value ?"))
        #expect(!channelsSource.contains("isActionDisabled: self.store.isLoading,"))
        #expect(!channelsSource.contains("isActionDisabled: self.store.isLoading.value"))
        #expect(!channelsSource.contains("if self.store.isLoading { return \"Loading\" }"))
        #expect(!channelsSource.contains("if self.store.isLoading.value { return \"Loading\" }"))
        #expect(!channelsSource.contains("if self.store.isLoading.value { return \"loading\" }"))
        #expect(!channelsSource.contains("var errorText: String?"))
        #expect(!channelsSource.contains("detail: errorText,"))
        #expect(!channelsSource.contains("return errorText\n"))
        #expect(!channelsSource.contains("case failed(String)"))
        #expect(channelsSource.contains("await self.store.send(.refreshRequested(.init("))
        #expect(channelsSource.contains("await self.store.send(.operationRequested(.init("))
        #expect(channelsSource.contains("sceneActivity: .init(isActive: self.scenePhase == .active)"))
        #expect(channelsSource.contains("readAccess: .init(canRead: self.canRead)"))
        #expect(channelsSource.contains("force: .init(isForced: force)"))
        #expect(channelsSource.contains("adminAccess: .init(canAdmin: self.canAdmin)"))
        #expect(!channelsSource.contains("sceneActive: self.scenePhase == .active"))
        #expect(channelsSource.contains("\"clickclack\": SettingsChannelFallbackMetadata"))
        #expect(channelsSource.contains("label: \"ClickClack\""))
        #expect(channelsSource.contains("Self-hosted chat bot routing."))
    }

    @Test func `settings setup code apply result is reducer owned`() throws {
        let setupLinkFeatureSource = try String(contentsOf: Self.settingsGatewaySetupLinkFeatureSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let supportSource = try String(contentsOf: Self.settingsProTabSupportSourceURL(), encoding: .utf8)
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let applyFunction = try Self.extract(
            actionsSource,
            from: "func applySetupCode() async -> Bool",
            to: "func applyGatewayLink")

        #expect(supportSource.contains("struct SettingsAppleReviewDemoClient"))
        #expect(supportSource.contains("var enter: @MainActor @Sendable () -> Void"))
        #expect(supportSource.contains("var settingsAppleReviewDemo: SettingsAppleReviewDemoClient"))
        #expect(setupLinkFeatureSource.contains("private let appleReviewDemoClientOverride: SettingsAppleReviewDemoClient?"))
        #expect(setupLinkFeatureSource.contains("@Dependency(\\.settingsAppleReviewDemo)"))
        #expect(setupLinkFeatureSource.contains("await appleReviewDemoClient.enter()"))
        #expect(setupLinkFeatureSource.contains("enum ApplyResult: Equatable, Sendable"))
        #expect(setupLinkFeatureSource.contains("struct AppleReviewDemo: Equatable, Sendable"))
        #expect(setupLinkFeatureSource
            .contains("struct SettingsGatewaySetupAppleReviewDemoStatusText: Equatable, Sendable"))
        #expect(setupLinkFeatureSource
            .contains("var statusText: SettingsGatewaySetupAppleReviewDemoStatusText"))
        #expect(setupLinkFeatureSource.contains("struct SettingsGatewaySetupLinkFailureMessage: Equatable, Sendable"))
        #expect(setupLinkFeatureSource.contains("struct Failure: Equatable, Sendable"))
        #expect(setupLinkFeatureSource.contains(
            "struct Failure: Equatable, Sendable { var message: SettingsGatewaySetupLinkFailureMessage }"))
        #expect(setupLinkFeatureSource.contains("case appleReviewDemo(AppleReviewDemo)"))
        #expect(setupLinkFeatureSource.contains("case failure(Failure)"))
        #expect(setupLinkFeatureSource.contains("case applyRequested"))
        #expect(setupLinkFeatureSource
            .contains("state.applyResult = .appleReviewDemo(.init(statusText: Self.appleReviewDemoStatusText))"))
        #expect(setupLinkFeatureSource.contains(
            "state.applyResult = .failure(.init(message: Self.emptySetupCodeFailureMessage))"))
        #expect(setupLinkFeatureSource.contains(
            "state.applyResult = .failure(.init(message: Self.invalidSetupCodeFailureMessage))"))
        #expect(setupLinkFeatureSource.contains("state.applyResult = .gatewayLink(link)"))
        #expect(actionsSource.contains("await self.gatewaySetupLinkStore.send(.applyRequested).finish()"))
        #expect(actionsSource.contains("self.gatewaySetupLinkStore.send(.applyResultHandled)"))
        #expect(actionsSource.contains("case let .appleReviewDemo(demo):"))
        #expect(actionsSource.contains(
            "self.gatewaySetupStatusStore.send(.statusChanged(.init(statusText: .init(value: demo.statusText.value)))"))
        #expect(applyFunction.contains(
            "self.gatewaySetupStatusStore.send(.statusChanged(.init(statusText: .init(value: failure.message.value)))"))
        #expect(!setupLinkFeatureSource.contains("var statusText: String"))
        #expect(!actionsSource.contains(
            "self.gatewaySetupStatusStore.send(.statusChanged(.init(statusText: .init(value: demo.statusText)))"))
        #expect(!setupLinkFeatureSource.contains("struct Failure: Equatable, Sendable { var message: String }"))
        #expect(!setupLinkFeatureSource.contains("case failure(String)"))
        #expect(!applyFunction.contains(
            "self.gatewaySetupStatusStore.send(.statusChanged(.init(statusText: .init(value: failure.message)))"))
        #expect(rootSource.contains("gatewaySetupLinkStore: self.makeSettingsGatewaySetupLinkStore()"))
        #expect(storesSource.contains(
            "SettingsGatewaySetupLinkFeature(appleReviewDemoClient: .live(appModel: self.appModel))"))
        #expect(!actionsSource.contains("GatewayConnectDeepLink.fromSetupInput(raw)"))
        #expect(!actionsSource.contains("AppleReviewDemoMode.isSetupCode(raw)"))
        #expect(!applyFunction.contains("self.appModel.enterAppleReviewDemoMode()"))
        #expect(!actionsSource.contains("let stagedLink = self.stagedGatewaySetupLink"))
        #expect(!actionsSource.contains("\"Apple Review demo mode enabled.\""))
    }

    @Test func `settings setup link staging status is reducer owned`() throws {
        let setupLinkFeatureSource = try String(contentsOf: Self.settingsGatewaySetupLinkFeatureSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let stagingFunction = try Self.extract(
            actionsSource,
            from: "func applyPendingGatewaySetupLinkIfNeeded()",
            to: "@discardableResult")

        #expect(setupLinkFeatureSource
            .contains("struct SettingsGatewaySetupLinkStatusText: Equatable, Sendable { var value: String }"))
        #expect(setupLinkFeatureSource.contains("var setupLinkStatusText: SettingsGatewaySetupLinkStatusText?"))
        #expect(setupLinkFeatureSource.contains("struct SetupLinkStage: Equatable, Sendable"))
        #expect(setupLinkFeatureSource.contains("case setupLinkStaged(SetupLinkStage)"))
        #expect(setupLinkFeatureSource.contains("case setupLinkStatusHandled"))
        #expect(setupLinkFeatureSource
            .contains("state.setupLinkStatusText = .init(value: Self.setupLinkLoadedStatusText(link))"))
        #expect(setupLinkFeatureSource.contains("Setup link loaded for \\(link.host):\\(link.port)"))
        #expect(actionsSource.contains("self.gatewaySetupLinkStore.send(.setupLinkStaged(.init(link: link)))"))
        #expect(actionsSource.contains("self.gatewaySetupLinkStore.setupLinkStatusText"))
        #expect(stagingFunction.contains("statusText.value"))
        #expect(actionsSource.contains("self.gatewaySetupLinkStore.send(.setupLinkStatusHandled)"))
        #expect(!setupLinkFeatureSource.contains("var setupLinkStatusText: String?"))
        #expect(!stagingFunction.contains("value: statusText))"))
        #expect(!stagingFunction.contains("let security = link.tls"))
        #expect(!stagingFunction.contains("Setup link loaded for \\(link.host):\\(link.port)"))
    }

    @Test func `settings setup connection status is reducer owned`() throws {
        let gatewaySetupFeaturesSource = try String(
            contentsOf: Self.settingsGatewaySetupFeaturesSourceURL(),
            encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let applyFunction = try Self.extract(
            actionsSource,
            from: "func applySetupCodeAndConnect() async",
            to: "func applyPendingGatewaySetupLinkIfNeeded()")

        #expect(gatewaySetupFeaturesSource.contains("case setupConnectionStarted"))
        #expect(gatewaySetupFeaturesSource
            .contains("private static let setupConnectionStartedStatusText = \"Setup code applied. Connecting...\""))
        #expect(applyFunction.contains("self.gatewaySetupStatusStore.send(.setupConnectionStarted)"))
        #expect(!applyFunction.contains("Setup code applied. Connecting..."))
    }

    @Test func `settings qr scanner opening status is reducer owned`() throws {
        let gatewaySetupFeaturesSource = try String(
            contentsOf: Self.settingsGatewaySetupFeaturesSourceURL(),
            encoding: .utf8)
        let gatewayConnectionSource = try String(
            contentsOf: Self.settingsGatewayConnectionFeatureSourceURL(),
            encoding: .utf8)
        let supportSource = try String(contentsOf: Self.settingsProTabSupportSourceURL(), encoding: .utf8)
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let openScannerFunction = try Self.extract(
            actionsSource,
            from: "func openGatewayQRScanner() async",
            to: "func handleScannedGatewayLink")

        #expect(supportSource.contains("struct SettingsGatewayDisconnectClient"))
        #expect(supportSource.contains("var settingsGatewayDisconnect: SettingsGatewayDisconnectClient"))
        #expect(gatewayConnectionSource.contains("case disconnectRequested"))
        #expect(gatewayConnectionSource.contains("@Dependency(\\.settingsGatewayDisconnect)"))
        #expect(gatewayConnectionSource.contains("await disconnectClient.disconnect()"))
        #expect(openScannerFunction.contains("await self.gatewayConnectionStore.send(.disconnectRequested).finish()"))
        #expect(gatewaySetupFeaturesSource.contains("case qrScannerOpeningStarted"))
        #expect(gatewaySetupFeaturesSource
            .contains("private static let qrScannerOpeningStartedStatusText = \"Opening QR scanner...\""))
        #expect(openScannerFunction.contains("self.gatewaySetupStatusStore.send(.qrScannerOpeningStarted)"))
        #expect(rootSource.contains("gatewayConnectionStore: self.makeSettingsGatewayConnectionStore()"))
        #expect(storesSource.contains("SettingsGatewayConnectionFeature(disconnectClient: .live(appModel: self.appModel))"))
        #expect(!openScannerFunction.contains("self.appModel.disconnectGateway()"))
        #expect(!openScannerFunction.contains("Opening QR scanner..."))
    }

    @Test func `settings qr scanner error status is reducer owned`() throws {
        let gatewaySetupFeaturesSource = try String(
            contentsOf: Self.settingsGatewaySetupFeaturesSourceURL(),
            encoding: .utf8)
        let settingsSource = try Self.settingsProTabCombinedSource()
        let supportSource = try String(contentsOf: Self.settingsProTabSupportSourceURL(), encoding: .utf8)
        let qrScannerSheet = try Self.extract(
            settingsSource,
            from: ".sheet(isPresented: self.qrScannerBinding)",
            to: ".sheet(isPresented: self.notificationRelayDisclosureBinding)")
        let setupStatusFeature = try Self.extract(
            gatewaySetupFeaturesSource,
            from: "@Reducer\nstruct SettingsGatewaySetupStatusFeature",
            to: "@Reducer\nstruct SettingsManualGatewayEndpointFeature")

        #expect(gatewaySetupFeaturesSource.contains("struct GatewayStatusSync: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct QRScannerError: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct SettingsGatewaySetupProblemMessage: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct SettingsGatewayStatusText: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct SettingsGatewaySetupStatusText: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct SettingsGatewaySetupScannerErrorMessage: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct SetupStatusChange: Equatable, Sendable"))
        #expect(setupStatusFeature
            .contains("var gatewayProblemMessage = SettingsGatewaySetupProblemMessage(value: nil)"))
        #expect(setupStatusFeature.contains("var gatewayStatusText = SettingsGatewayStatusText(value: \"\")"))
        #expect(setupStatusFeature.contains("var statusText = SettingsGatewaySetupStatusText(value: nil)"))
        #expect(gatewaySetupFeaturesSource.contains("var problemMessage: SettingsGatewaySetupProblemMessage"))
        #expect(gatewaySetupFeaturesSource.contains("var gatewayStatusText: SettingsGatewayStatusText"))
        #expect(gatewaySetupFeaturesSource.contains("var message: SettingsGatewaySetupScannerErrorMessage"))
        #expect(gatewaySetupFeaturesSource.contains("var statusText: SettingsGatewaySetupStatusText"))
        #expect(setupStatusFeature.contains("problemMessage: self.gatewayProblemMessage.value"))
        #expect(setupStatusFeature.contains("setupStatusText: self.statusText.value"))
        #expect(setupStatusFeature.contains("gatewayStatusText: self.gatewayStatusText.value"))
        #expect(setupStatusFeature.contains("state.gatewayProblemMessage = sync.problemMessage"))
        #expect(setupStatusFeature.contains("state.gatewayStatusText = sync.gatewayStatusText"))
        #expect(setupStatusFeature
            .contains("state.statusText = .init(value: Self.qrScannerErrorStatusText(error.message.value))"))
        #expect(setupStatusFeature.contains("state.statusText = change.statusText"))
        #expect(gatewaySetupFeaturesSource.contains("case gatewayStatusSynced(GatewayStatusSync)"))
        #expect(gatewaySetupFeaturesSource.contains("case qrScannerErrorReceived(QRScannerError)"))
        #expect(gatewaySetupFeaturesSource.contains("case statusChanged(SetupStatusChange)"))
        #expect(gatewaySetupFeaturesSource.contains("private static func qrScannerErrorStatusText(_ error: String)"))
        #expect(settingsSource.contains("self.gatewaySetupStatusStore.statusText.value"))
        #expect(!setupStatusFeature.contains("var gatewayProblemMessage: String?"))
        #expect(!setupStatusFeature.contains("var gatewayStatusText = \"\""))
        #expect(!setupStatusFeature.contains("var statusText: String?"))
        #expect(!setupStatusFeature.contains("state.statusText = change.statusText.value"))
        #expect(settingsSource.contains("struct QRScannerError: Equatable, Sendable"))
        #expect(supportSource.contains("struct SettingsPresentationScannerErrorMessage: Equatable, Sendable"))
        #expect(settingsSource.contains("enum Destination: Equatable, Sendable"))
        #expect(settingsSource.contains("case scannerError(SettingsPresentationScannerErrorMessage)"))
        #expect(settingsSource.contains("var destination: Destination?"))
        #expect(settingsSource.contains("var message: SettingsPresentationScannerErrorMessage"))
        #expect(settingsSource.contains("case qrScannerErrorReceived(QRScannerError)"))
        #expect(settingsSource.contains("state.destination = .scannerError(error.message)"))
        #expect(qrScannerSheet.contains(
            "self.presentationStore.send(.qrScannerErrorReceived(.init(message: .init(value: error))))"))
        #expect(qrScannerSheet.contains("message: .init(value: error)"))
        #expect(!settingsSource.contains("struct QRScannerError: Equatable, Sendable { var message: String }"))
        #expect(!settingsSource.contains("state.scannerError = error.message.value"))
        #expect(!settingsSource.contains("state.scannerError = error.message\n"))
        #expect(!settingsSource.contains("var scannerError: String?\n"))
        #expect(!settingsSource.contains("var showGatewayProblemDetails = false"))
        #expect(!settingsSource.contains("var showNotificationRelayDisclosure = false"))
        #expect(!settingsSource.contains("var showQRScanner = false"))
        #expect(!settingsSource.contains("var showResetOnboardingAlert = false"))
        #expect(!settingsSource.contains("var showTalkIssueDetails = false"))
        #expect(!qrScannerSheet.contains("Scanner error: \\(error)"))
    }

    @Test func `onboarding qr scanner errors are reducer owned`() throws {
        let onboardingSource = try String(contentsOf: Self.onboardingWizardSourceURL(), encoding: .utf8)
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)

        #expect(onboardingStateSource.contains("struct ScannerError: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct QRScannerError: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct OnboardingScannerErrorMessage: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("var message: OnboardingScannerErrorMessage"))
        #expect(onboardingStateSource.contains("case scannerError(OnboardingScannerErrorMessage)"))
        #expect(onboardingStateSource.contains("case scannerErrorReceived(ScannerError)"))
        #expect(onboardingStateSource.contains("case qrScannerErrorReceived(QRScannerError)"))
        #expect(onboardingStateSource.contains("state.statusLine = \"Scanner error: \\(error.message.value)\""))
        #expect(onboardingStateSource.contains("state.destination = .scannerError(error.message)"))
        #expect(onboardingSource.contains(
            "self.statusStore.send(.scannerErrorReceived(.init(message: .init(value: error))))"))
        #expect(onboardingSource.contains(
            "self.presentationStore.send(.qrScannerErrorReceived(.init(message: .init(value: error))))"))
        #expect(onboardingSource.contains(
            "self.presentationStore.send(.qrScannerErrorReceived(.init(message: .init(value: failure.message.value))))"))
        #expect(!onboardingStateSource.contains("state.scannerError = error.message.value"))
        #expect(!onboardingStateSource.contains("var scannerError: String?\n"))
        #expect(!onboardingStateSource.contains("var showGatewayProblemDetails = false"))
        #expect(!onboardingStateSource.contains("var showQRScanner = false"))
        #expect(!onboardingStateSource.contains("struct ScannerError: Equatable, Sendable { var message: String }"))
        #expect(!onboardingStateSource.contains("struct QRScannerError: Equatable, Sendable { var message: String }"))
        #expect(!onboardingSource.contains(
            "self.presentationStore.send(.qrScannerErrorReceived(.init(message: .init(value: failure.message))))"))
    }

    @Test func `onboarding gateway snapshot action is typed`() throws {
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)
        let onboardingStateBlock = try Self.extract(
            onboardingStateSource,
            from: "@ObservableState\n    struct State: Equatable, Sendable",
            to: "        init(")
        let gatewaySnapshotChange = try Self.extract(
            onboardingStateSource,
            from: "struct GatewaySnapshotChange",
            to: "struct CompletionMark")

        #expect(onboardingStateSource.contains("struct OnboardingGatewayServerName: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct OnboardingHasSavedGatewayConnection: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct GatewaySnapshotChange: Equatable, Sendable"))
        #expect(gatewaySnapshotChange.contains("var gatewayServerName: OnboardingGatewayServerName"))
        #expect(gatewaySnapshotChange.contains("var hasSavedGatewayConnection: OnboardingHasSavedGatewayConnection"))
        #expect(onboardingStateSource.contains("case gatewaySnapshotChanged(GatewaySnapshotChange)"))
        #expect(onboardingStateSource.contains("state.gatewayServerName = snapshot.gatewayServerName.value"))
        #expect(onboardingStateSource.contains("state.savedGatewayConnection = snapshot.hasSavedGatewayConnection"))
        #expect(onboardingStateSource.contains("var savedGatewayConnection: OnboardingHasSavedGatewayConnection"))
        #expect(!gatewaySnapshotChange.contains("var gatewayServerName: String?"))
        #expect(!gatewaySnapshotChange.contains("var hasSavedGatewayConnection: Bool"))
        #expect(!onboardingStateBlock.contains("var hasSavedGatewayConnection: Bool"))
    }

    @Test func `onboarding completion mark action is typed`() throws {
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)

        #expect(onboardingStateSource.contains("struct CompletionMark: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("case markCompleted(CompletionMark)"))
        #expect(onboardingStateSource.contains("if let mode = mark.mode"))
    }

    @Test func `onboarding reducer stores presentation flags as typed state`() throws {
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)
        let onboardingStateBlock = try Self.extract(
            onboardingStateSource,
            from: "@ObservableState\n    struct State: Equatable, Sendable",
            to: "        init(")

        #expect(onboardingStateSource.contains("struct OnboardingCompletion: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct OnboardingFirstRunIntroSeen: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct OnboardingLaunchPresentation: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct OnboardingFirstRunIntroPresentation: Equatable, Sendable"))
        #expect(onboardingStateBlock.contains("var completion: OnboardingCompletion"))
        #expect(onboardingStateBlock.contains("var firstRunIntroSeenState: OnboardingFirstRunIntroSeen"))
        #expect(onboardingStateBlock.contains("var launchPresentation: OnboardingLaunchPresentation"))
        #expect(onboardingStateBlock.contains("var firstRunIntroPresentation: OnboardingFirstRunIntroPresentation"))
        #expect(onboardingStateSource.contains("state.completion = .init(isCompleted: true)"))
        #expect(onboardingStateSource.contains("state.firstRunIntroSeenState = .init(value: true)"))
        #expect(!onboardingStateBlock.contains("var isCompleted: Bool"))
        #expect(!onboardingStateBlock.contains("var firstRunIntroSeen: Bool"))
        #expect(!onboardingStateBlock.contains("var shouldPresentOnLaunch: Bool"))
        #expect(!onboardingStateBlock.contains("var shouldPresentFirstRunIntro: Bool"))
    }

    @Test func `onboarding gateway connected action is typed`() throws {
        let onboardingSource = try String(contentsOf: Self.onboardingWizardSourceURL(), encoding: .utf8)
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)
        let gatewayConnectionCompletion = try Self.extract(
            onboardingStateSource,
            from: "struct GatewayConnectionCompletion",
            to: "struct ConnectionIssueDetection")

        #expect(onboardingStateSource.contains("struct OnboardingGatewayMarkedCompleted: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct GatewayConnectionCompletion: Equatable, Sendable"))
        #expect(gatewayConnectionCompletion.contains("var markedCompleted: OnboardingGatewayMarkedCompleted"))
        #expect(onboardingStateSource.contains("case gatewayConnected(GatewayConnectionCompletion)"))
        #expect(onboardingStateSource.contains("if completion.markedCompleted.value"))
        #expect(onboardingStateSource.contains("state.completionMark = completion.markedCompleted"))
        #expect(onboardingSource.contains("self.statusStore.send(.gatewayConnected(.init("))
        #expect(onboardingSource.contains("markedCompleted: .init(value: shouldMarkCompleted && selectedMode != nil)"))
        #expect(!gatewayConnectionCompletion.contains("var markedCompleted: Bool"))
        #expect(!onboardingStateSource.contains("state.didMarkCompleted = true"))
    }

    @Test func `onboarding automatic pairing resume action is typed`() throws {
        let onboardingSource = try String(contentsOf: Self.onboardingWizardSourceURL(), encoding: .utf8)
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)
        let automaticPairingResumeRequest = try Self.extract(
            onboardingStateSource,
            from: "struct AutomaticPairingResumeRequest",
            to: "struct ConnectionStart")

        #expect(onboardingStateSource.contains("struct OnboardingPairingResumeRequestTime: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct OnboardingAutomaticPairingResume: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct AutomaticPairingResumeRequest: Equatable, Sendable"))
        #expect(automaticPairingResumeRequest.contains("var now: OnboardingPairingResumeRequestTime"))
        #expect(onboardingStateSource.contains("case automaticPairingResumeRequested(AutomaticPairingResumeRequest)"))
        #expect(onboardingStateSource.contains("request.now.value.timeIntervalSince(last)"))
        #expect(onboardingStateSource.contains("state.lastPairingAutoResumeAttemptAt = request.now.value"))
        #expect(onboardingStateSource.contains("state.automaticPairingResume = .init(shouldResume: true)"))
        #expect(onboardingSource.contains(
            "self.statusStore.send(.automaticPairingResumeRequested(.init(now: .init(value: Date()))))"))
        #expect(!automaticPairingResumeRequest.contains("var now: Date"))
        #expect(!onboardingStateSource.contains("state.shouldResumePairingAutomatically = true"))
    }

    @Test func `onboarding status reducer stores flow flags as typed state`() throws {
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)
        let statusFeatureSource = try Self.extract(
            onboardingStateSource,
            from: "@Reducer\nstruct OnboardingStatusFeature",
            to: "    enum Action: Equatable, Sendable")
        let statusStateBlock = try Self.extract(
            statusFeatureSource,
            from: "@ObservableState\n    struct State: Equatable, Sendable",
            to: "        init(statusLine:")

        #expect(onboardingStateSource.contains("struct OnboardingAuthStepPresentation: Equatable, Sendable"))
        #expect(statusStateBlock.contains("var completionMark = OnboardingGatewayMarkedCompleted(value: false)"))
        #expect(statusStateBlock.contains("var automaticPairingResume = OnboardingAutomaticPairingResume(shouldResume: false)"))
        #expect(statusStateBlock.contains("var authStepPresentation = OnboardingAuthStepPresentation(shouldShow: false)"))
        #expect(onboardingStateSource.contains("state.authStepPresentation = .init(shouldShow:"))
        #expect(!statusStateBlock.contains("var didMarkCompleted = false"))
        #expect(!statusStateBlock.contains("var shouldResumePairingAutomatically = false"))
        #expect(!statusStateBlock.contains("var shouldShowAuthStep = false"))
        #expect(!onboardingStateSource.contains("state.shouldShowAuthStep = false"))
    }

    @Test func `onboarding step changes are typed`() throws {
        let onboardingSource = try String(contentsOf: Self.onboardingWizardSourceURL(), encoding: .utf8)
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)

        #expect(onboardingStateSource.contains("struct StepChange: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("case stepChanged(StepChange)"))
        #expect(onboardingStateSource.contains("state.step = change.step"))
        #expect(onboardingSource.contains("self.stepStore.send(.stepChanged(.init(step:"))
        #expect(!onboardingSource.contains("self.stepStore.send(.stepChanged(.connect))"))
    }

    @Test func `scanner setup code results are reducer owned`() throws {
        let setupLinkFeatureSource = try String(contentsOf: Self.settingsGatewaySetupLinkFeatureSourceURL(), encoding: .utf8)
        let settingsActionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let supportSource = try String(contentsOf: Self.settingsProTabSupportSourceURL(), encoding: .utf8)
        let onboardingSource = try String(contentsOf: Self.onboardingWizardSourceURL(), encoding: .utf8)
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)

        #expect(setupLinkFeatureSource.contains("struct ScannedSetupCode: Equatable, Sendable"))
        #expect(supportSource.contains("struct SettingsGatewaySetupCode: Equatable, Sendable { var value: String }"))
        #expect(setupLinkFeatureSource.contains("struct SetupCodeChange: Equatable, Sendable"))
        #expect(setupLinkFeatureSource.contains("var setupCode = SettingsGatewaySetupCode(value: \"\")"))
        #expect(setupLinkFeatureSource.contains("var code: SettingsGatewaySetupCode"))
        #expect(setupLinkFeatureSource.contains("var setupCode: SettingsGatewaySetupCode"))
        #expect(setupLinkFeatureSource.contains("struct SetupCodeSync: Equatable, Sendable"))
        #expect(setupLinkFeatureSource.contains("case scannedSetupCodeReceived(ScannedSetupCode)"))
        #expect(setupLinkFeatureSource.contains("case setupCodeChanged(SetupCodeChange)"))
        #expect(setupLinkFeatureSource.contains("case setupCodeSynced(SetupCodeSync)"))
        #expect(setupLinkFeatureSource.contains("AppleReviewDemoMode.isSetupCode(scan.code.value)"))
        #expect(setupLinkFeatureSource.contains("let setupCode = change.setupCode"))
        #expect(setupLinkFeatureSource.contains("let setupCode = sync.setupCode"))
        #expect(setupLinkFeatureSource.contains("state.setupCode = setupCode"))
        #expect(setupLinkFeatureSource.contains("setupCode.value.trimmingCharacters(in: .whitespacesAndNewlines)"))
        #expect(setupLinkFeatureSource
            .contains("state.applyResult = .appleReviewDemo(.init(statusText: Self.appleReviewDemoStatusText))"))
        #expect(settingsActionsSource.contains(
            "self.gatewaySetupLinkStore.send(.scannedSetupCodeReceived(.init(code: .init(value: code))))"))
        #expect(settingsActionsSource.contains(
            "self.gatewaySetupLinkStore.send(.setupCodeSynced(.init(setupCode: .init(value: self.storedSetupCode))))"))
        #expect(settingsActionsSource.contains(
            "self.gatewaySetupLinkStore.send(.setupCodeChanged(.init(setupCode: .init(value: setupCode))))"))
        #expect(settingsActionsSource.contains("self.gatewaySetupLinkStore.setupCode.value"))
        #expect(!setupLinkFeatureSource.contains("var setupCode = \"\""))
        #expect(!setupLinkFeatureSource.contains("let setupCode = change.setupCode.value"))
        #expect(!setupLinkFeatureSource.contains("let setupCode = sync.setupCode.value"))
        #expect(!setupLinkFeatureSource.contains("state.setupCode = setupCode.value"))
        #expect(!setupLinkFeatureSource.contains("struct ScannedSetupCode: Equatable, Sendable { var code: String }"))
        #expect(!setupLinkFeatureSource.contains("struct SetupCodeSync: Equatable, Sendable { var setupCode: String }"))
        #expect(!setupLinkFeatureSource.contains("struct SetupCodeChange: Equatable, Sendable { var setupCode: String }"))
        #expect(!settingsActionsSource.contains(".scannedSetupCodeReceived(.init(code: code))"))
        #expect(!settingsActionsSource.contains(".setupCodeSynced(.init(setupCode: self.storedSetupCode))"))
        #expect(!settingsActionsSource.contains(".setupCodeChanged(.init(setupCode: setupCode))"))
        #expect(settingsActionsSource.contains("guard case let .appleReviewDemo(demo)?"))
        #expect(onboardingStateSource.contains("struct ScannedSetupCode: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("case scannedSetupCodeReceived(ScannedSetupCode)"))
        #expect(onboardingStateSource.contains("AppleReviewDemoMode.isSetupCode(scan.code.value)"))
        #expect(onboardingSource.contains("self.setupCodeStore.send(.scannedSetupCodeReceived(.init(code: .init(value: code))))"))
        #expect(!onboardingStateSource.contains("struct ScannedSetupCode: Equatable, Sendable { var code: String }"))
        #expect(!onboardingSource.contains("self.setupCodeStore.send(.scannedSetupCodeReceived(.init(code: code)))"))
        #expect(!settingsActionsSource.contains("AppleReviewDemoMode.isSetupCode(code)"))
        #expect(!settingsActionsSource.contains("self.appModel.enterAppleReviewDemoMode()"))
        #expect(!settingsActionsSource.contains("\"Apple Review demo mode enabled.\""))
        #expect(!onboardingSource.contains("AppleReviewDemoMode.isSetupCode(code)"))
    }

    @Test func `scanner gateway link results are reducer owned`() throws {
        let setupLinkFeatureSource = try String(contentsOf: Self.settingsGatewaySetupLinkFeatureSourceURL(), encoding: .utf8)
        let settingsActionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let onboardingSource = try String(contentsOf: Self.onboardingWizardSourceURL(), encoding: .utf8)
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)
        let handleFunction = try Self.extract(
            settingsActionsSource,
            from: "func handleScannedGatewayLink(_ link: GatewayConnectDeepLink)",
            to: "func handleScannedSetupCode")

        #expect(setupLinkFeatureSource.contains("struct ScannedGatewayLink: Equatable, Sendable"))
        #expect(setupLinkFeatureSource.contains("case scannedGatewayLinkReceived(ScannedGatewayLink)"))
        #expect(setupLinkFeatureSource
            .contains("struct SettingsScannedGatewayLinkStatusText: Equatable, Sendable { var value: String }"))
        #expect(setupLinkFeatureSource.contains(
            "var scannedGatewayLinkStatusText: SettingsScannedGatewayLinkStatusText?"))
        #expect(setupLinkFeatureSource.contains("case scannedGatewayLinkStatusHandled"))
        #expect(setupLinkFeatureSource.contains(
            "state.scannedGatewayLinkStatusText = .init(value: Self.scannedGatewayLinkStatusText(link))"))
        #expect(setupLinkFeatureSource.contains("state.applyResult = .gatewayLink(link)"))
        #expect(settingsActionsSource.contains(
            "self.gatewaySetupLinkStore.send(.scannedGatewayLinkReceived(.init(link: link)))"))
        #expect(settingsActionsSource.contains("self.gatewaySetupLinkStore.scannedGatewayLinkStatusText"))
        #expect(handleFunction.contains("statusText.value"))
        #expect(settingsActionsSource.contains("self.gatewaySetupLinkStore.send(.scannedGatewayLinkStatusHandled)"))
        #expect(onboardingStateSource.contains("struct ScannedGatewayLink: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("case scannedGatewayLinkReceived(ScannedGatewayLink)"))
        #expect(onboardingStateSource.contains("state.applyResult = .gatewayLink(scan.link)"))
        #expect(onboardingSource.contains("self.setupCodeStore.send(.scannedGatewayLinkReceived(.init(link: link)))"))
        #expect(!setupLinkFeatureSource.contains("var scannedGatewayLinkStatusText: String?"))
        #expect(!handleFunction.contains("value: statusText))"))
        #expect(!handleFunction.contains("QR loaded. Connecting to"))
        #expect(!settingsActionsSource.contains("""
        self.presentationStore.send(.qrScannerDismissed)
                self.updateSetupCode("")
                self.applyGatewayLink(link)
        """))
        #expect(!onboardingSource
            .contains(
                "private func handleScannedLink(_ link: GatewayConnectDeepLink) {\n        self.applyGatewayLink(link)"))
    }

    @Test func `settings manual connection result is reducer owned`() throws {
        let gatewaySetupFeaturesSource = try String(
            contentsOf: Self.settingsGatewaySetupFeaturesSourceURL(),
            encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let setupLinkApplication = try Self.extract(
            gatewaySetupFeaturesSource,
            from: "struct SetupLinkApplication",
            to: "struct ManualConnectionAttempt")
        let connectManualFunction = try Self.extract(
            actionsSource,
            from: "func connectManual() async",
            to: "func preflightGateway")

        #expect(gatewaySetupFeaturesSource.contains("enum ManualConnectionResult: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct Failure: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("case failure(Failure)"))
        #expect(gatewaySetupFeaturesSource.contains("struct EndpointSync: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct ManualGatewayEnabled: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains(
            "var manualGatewayEnabled = Action.ManualGatewayEnabled(value: false)"))
        #expect(gatewaySetupFeaturesSource.contains("var enabled: ManualGatewayEnabled"))
        #expect(gatewaySetupFeaturesSource.contains("struct ManualGatewayHost: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains(
            "var manualGatewayHost = Action.ManualGatewayHost(value: \"\")"))
        #expect(gatewaySetupFeaturesSource.contains("var host: ManualGatewayHost"))
        #expect(gatewaySetupFeaturesSource.contains(
            "var manualGatewayTLS = Action.ManualGatewayTLS(value: true)"))
        #expect(gatewaySetupFeaturesSource.contains("var useTLS: ManualGatewayTLS"))
        #expect(gatewaySetupFeaturesSource.contains("state.manualGatewayEnabled = sync.enabled"))
        #expect(gatewaySetupFeaturesSource.contains("state.manualGatewayHost = sync.host"))
        #expect(gatewaySetupFeaturesSource.contains("state.manualGatewayTLS = sync.useTLS"))
        #expect(gatewaySetupFeaturesSource.contains("struct ManualGatewayEnabledChange: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct ManualGatewayHostDraft: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("var draft: ManualGatewayHostDraft"))
        #expect(gatewaySetupFeaturesSource.contains("struct ManualGatewayHostChange: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct ManualGatewayTLS: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("var tls: ManualGatewayTLS"))
        #expect(gatewaySetupFeaturesSource.contains("struct ManualGatewayTLSChange: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct SetupLinkApplication: Equatable, Sendable"))
        #expect(setupLinkApplication.contains("var host: ManualGatewayHost"))
        #expect(setupLinkApplication.contains("var useTLS: ManualGatewayTLS"))
        #expect(gatewaySetupFeaturesSource.contains("state.manualGatewayHost = application.host"))
        #expect(gatewaySetupFeaturesSource.contains("state.manualGatewayTLS = application.useTLS"))
        #expect(gatewaySetupFeaturesSource.contains("struct ManualConnectionHost: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct ManualConnectionResolvedPort: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct ManualConnectionTLS: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("var host: ManualConnectionHost"))
        #expect(gatewaySetupFeaturesSource.contains("var port: ManualConnectionResolvedPort"))
        #expect(gatewaySetupFeaturesSource.contains("var useTLS: ManualConnectionTLS"))
        #expect(gatewaySetupFeaturesSource.contains("struct ManualConnectionPort: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct ManualConnectionPortValidity: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct ManualConnectionAttempt: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("var port: ManualConnectionPort"))
        #expect(gatewaySetupFeaturesSource.contains("var isPortValid: ManualConnectionPortValidity"))
        #expect(gatewaySetupFeaturesSource.contains("guard request.isPortValid.value else"))
        #expect(gatewaySetupFeaturesSource.contains("struct SettingsManualConnectionFailureMessage: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains(
            "struct Failure: Equatable, Sendable { var message: SettingsManualConnectionFailureMessage }"))
        #expect(gatewaySetupFeaturesSource.contains("struct ManualGatewayTailnetIPv4Availability: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct GatewayPreflightRequest: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("var hasTailnetIPv4: ManualGatewayTailnetIPv4Availability"))
        #expect(gatewaySetupFeaturesSource.contains("let trimmed = request.host.value.trimmingCharacters"))
        #expect(gatewaySetupFeaturesSource.contains("!request.hasTailnetIPv4.value"))
        #expect(gatewaySetupFeaturesSource.contains("struct SettingsLocalNetworkAccessReason: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("static let settingsPreflight = Self(value: \"settings_preflight\")"))
        #expect(gatewaySetupFeaturesSource.contains("struct LocalNetworkAccessRequest: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("var reason: SettingsLocalNetworkAccessReason"))
        #expect(gatewaySetupFeaturesSource.contains("case endpointSynced(EndpointSync)"))
        #expect(gatewaySetupFeaturesSource.contains(
            "case manualGatewayEnabledChanged(ManualGatewayEnabledChange)"))
        #expect(gatewaySetupFeaturesSource.contains("case manualGatewayHostChanged(ManualGatewayHostChange)"))
        #expect(gatewaySetupFeaturesSource.contains("case manualGatewayTLSChanged(ManualGatewayTLSChange)"))
        #expect(gatewaySetupFeaturesSource.contains("case setupLinkApplied(SetupLinkApplication)"))
        #expect(gatewaySetupFeaturesSource.contains("case manualConnectionRequested(ManualConnectionAttempt)"))
        #expect(gatewaySetupFeaturesSource.contains(
            "state.manualConnectionResult = .failure(.init(message: Self.hostRequiredFailureMessage))"))
        #expect(gatewaySetupFeaturesSource.contains(
            "state.manualConnectionResult = .failure(.init(message: Self.invalidPortFailureMessage))"))
        #expect(gatewaySetupFeaturesSource.contains("state.manualConnectionResult = .request(ManualConnectionRequest("))
        #expect(gatewaySetupFeaturesSource.contains("host: .init(value: host)"))
        #expect(gatewaySetupFeaturesSource.contains("port: .init(value: request.port.value)"))
        #expect(gatewaySetupFeaturesSource.contains(
            "useTLS: .init(value: state.manualGatewayTLS.value)"))
        #expect(actionsSource.contains("self.manualGatewayEndpointStore.manualGatewayEnabled.value"))
        #expect(actionsSource.contains("self.manualGatewayEndpointStore.manualGatewayHost.value"))
        #expect(actionsSource.contains("self.manualGatewayEndpointStore.manualGatewayTLS.value"))
        #expect(actionsSource.contains("self.manualGatewayEndpointStore.send(.endpointSynced(.init("))
        #expect(actionsSource.contains("enabled: .init(value: self.storedManualGatewayEnabled)"))
        #expect(actionsSource.contains("host: .init(value: self.storedManualGatewayHost)"))
        #expect(actionsSource.contains("useTLS: .init(value: self.storedManualGatewayTLS)"))
        #expect(actionsSource.contains(
            "self.manualGatewayEndpointStore.send(.manualGatewayEnabledChanged(.init("))
        #expect(actionsSource.contains("enabled: .init(value: enabled)"))
        #expect(actionsSource.contains(
            "self.manualGatewayEndpointStore.send(.manualGatewayHostChanged(.init("))
        #expect(actionsSource.contains("draft: .init(value: host)"))
        #expect(actionsSource.contains(
            "self.manualGatewayEndpointStore.send(.manualGatewayTLSChanged(.init("))
        #expect(actionsSource.contains("tls: .init(value: tls)"))
        #expect(actionsSource.contains("self.manualGatewayEndpointStore.send(.setupLinkApplied(.init("))
        #expect(actionsSource.contains("host: .init(value: host)"))
        #expect(actionsSource.contains("useTLS: .init(value: tls)"))
        #expect(actionsSource.contains("self.manualGatewayEndpointStore.send(.manualConnectionRequested(.init("))
        #expect(actionsSource.contains("port: .init(value: self.manualGatewayPortStore.manualGatewayPort)"))
        #expect(actionsSource.contains("isPortValid: .init(value: self.manualPortIsValid)"))
        #expect(actionsSource.contains("self.manualGatewayEndpointStore.send(.manualConnectionResultHandled)"))
        #expect(actionsSource.contains("host: request.host.value"))
        #expect(actionsSource.contains("port: request.port.value"))
        #expect(actionsSource.contains("useTLS: request.useTLS.value"))
        #expect(connectManualFunction.contains(
            "self.gatewaySetupStatusStore.send(.statusChanged(.init(statusText: .init(value: failure.message.value)))"))
        #expect(!gatewaySetupFeaturesSource.contains("case failure(String)"))
        #expect(!gatewaySetupFeaturesSource.contains("struct Failure: Equatable, Sendable { var message: String }"))
        #expect(!connectManualFunction.contains(
            "self.gatewaySetupStatusStore.send(.statusChanged(.init(statusText: .init(value: failure.message)))"))
        #expect(!gatewaySetupFeaturesSource.contains("var host: String\n        var port: Int\n        var useTLS: Bool"))
        #expect(!gatewaySetupFeaturesSource.contains("var manualGatewayEnabled = false"))
        #expect(!gatewaySetupFeaturesSource.contains("var manualGatewayHost = \"\""))
        #expect(!gatewaySetupFeaturesSource.contains("var manualGatewayTLS = true"))
        #expect(!gatewaySetupFeaturesSource.contains("state.manualGatewayEnabled = change.isEnabled"))
        #expect(!gatewaySetupFeaturesSource.contains("state.manualGatewayHost = change.host"))
        #expect(!gatewaySetupFeaturesSource.contains("state.manualGatewayTLS = change.useTLS"))
        #expect(!gatewaySetupFeaturesSource.contains("state.manualGatewayEnabled = sync.enabled.value"))
        #expect(!gatewaySetupFeaturesSource.contains("state.manualGatewayHost = sync.host.value"))
        #expect(!gatewaySetupFeaturesSource.contains("state.manualGatewayTLS = sync.useTLS.value"))
        #expect(!gatewaySetupFeaturesSource.contains("state.manualGatewayHost = application.host.value"))
        #expect(!gatewaySetupFeaturesSource.contains("state.manualGatewayTLS = application.useTLS.value"))
        #expect(!gatewaySetupFeaturesSource.contains("useTLS: .init(value: state.manualGatewayTLS)"))
        #expect(!gatewaySetupFeaturesSource.contains("useTLS: state.manualGatewayTLS"))
        #expect(!gatewaySetupFeaturesSource.contains("guard request.isPortValid else"))
        #expect(!gatewaySetupFeaturesSource.contains("port: request.port,"))
        #expect(!actionsSource.contains("host: request.host,\n                port: request.port,"))
        #expect(!actionsSource.contains("useTLS: request.useTLS,"))
        #expect(!gatewaySetupFeaturesSource.contains("let trimmed = request.host.trimmingCharacters"))
        #expect(!gatewaySetupFeaturesSource.contains("!request.hasTailnetIPv4 {"))
        #expect(!actionsSource.contains("manualGatewayEnabledChanged(.init(isEnabled:"))
        #expect(!actionsSource.contains("manualGatewayHostChanged(.init(host:"))
        #expect(!actionsSource.contains("manualGatewayTLSChanged(.init(useTLS:"))
        #expect(!actionsSource.contains("guard !host.isEmpty else"))
        #expect(!actionsSource.contains("guard self.manualPortIsValid else"))
    }

    @Test func `settings manual port resolution status is reducer owned`() throws {
        let settingsSource = try Self.settingsProTabCombinedSource()
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let supportSource = try String(contentsOf: Self.settingsProTabSupportSourceURL(), encoding: .utf8)
        let applyFunction = try Self.extract(
            actionsSource,
            from: "func applySetupCodeAndConnect() async",
            to: "func applyPendingGatewaySetupLinkIfNeeded()")
        let scannedConnectFunction = try Self.extract(
            actionsSource,
            from: "func connectAfterScannedGatewayLink() async",
            to: "func connectManual()")
        let resolveManualPortFunction = try Self.extract(
            actionsSource,
            from: "func resolveManualPortForConnection(host: String) -> Bool",
            to: "func connectManual() async")
        let manualPortFeature = try Self.extract(
            settingsSource,
            from: "struct SettingsManualGatewayPortFeature",
            to: "struct SettingsGatewayAutoConnectFeature")

        #expect(settingsSource.contains("enum ManualGatewayPortResolutionResult: Equatable, Sendable"))
        #expect(manualPortFeature.contains("case failure(Failure)"))
        #expect(manualPortFeature.contains(
            "struct ManualGatewayPortResolutionFailureMessage: Equatable, Sendable { var value: String }"))
        #expect(manualPortFeature.contains("var message: ManualGatewayPortResolutionFailureMessage"))
        #expect(manualPortFeature.contains("static let invalidPortFailureMessage"))
        #expect(manualPortFeature.contains("value: \"Failed: invalid port\""))
        #expect(settingsSource.contains("struct ManualGatewayPortResolutionHost: Equatable, Sendable"))
        #expect(settingsSource.contains("struct ManualGatewayPortResolutionTLS: Equatable, Sendable"))
        #expect(settingsSource.contains("struct ManualGatewayPortResolutionRequest: Equatable, Sendable"))
        #expect(settingsSource.contains("var host: ManualGatewayPortResolutionHost"))
        #expect(settingsSource.contains("var useTLS: ManualGatewayPortResolutionTLS"))
        #expect(supportSource.contains("struct SettingsManualGatewayPort: Equatable, Sendable { var value: Int }"))
        #expect(manualPortFeature.contains(
            "struct ManualGatewayPortSync: Equatable, Sendable { var port: SettingsManualGatewayPort }"))
        #expect(supportSource.contains("struct SettingsManualGatewayPortText: Equatable, Sendable { var value: String }"))
        #expect(settingsSource.contains("struct ManualGatewayPortTextChange: Equatable, Sendable"))
        #expect(settingsSource.contains("var text: SettingsManualGatewayPortText"))
        #expect(settingsSource.contains(
            "case manualGatewayPortResolutionRequested(ManualGatewayPortResolutionRequest)"))
        #expect(settingsSource.contains("case manualGatewayPortSynced(ManualGatewayPortSync)"))
        #expect(settingsSource.contains("case manualGatewayPortTextChanged(ManualGatewayPortTextChange)"))
        #expect(settingsSource.contains(
            "state.resolvedManualPort(host: request.host.value, useTLS: request.useTLS.value)"))
        #expect(manualPortFeature.contains("var manualGatewayPortValue = SettingsManualGatewayPort(value: 18789)"))
        #expect(manualPortFeature.contains(
            "var manualGatewayPortTextValue = SettingsManualGatewayPortText(value: \"18789\")"))
        #expect(manualPortFeature.contains("var manualGatewayPort: Int"))
        #expect(manualPortFeature.contains("var manualGatewayPortText: String"))
        #expect(manualPortFeature.contains("self.manualGatewayPortValue.value"))
        #expect(manualPortFeature.contains("self.manualGatewayPortTextValue.value"))
        #expect(manualPortFeature.contains("let port = sync.port.value"))
        #expect(manualPortFeature.contains("state.manualGatewayPortValue = sync.port"))
        #expect(manualPortFeature.contains(
            "state.manualGatewayPortTextValue = .init(value: port > 0 ? String(port) : \"\")"))
        #expect(settingsSource.contains("let filtered = change.text.value.filter(\\.isNumber)"))
        #expect(manualPortFeature.contains("state.manualGatewayPortTextValue = .init(value: filtered)"))
        #expect(manualPortFeature.contains("state.manualGatewayPortValue = .init(value: Int(filtered) ?? 0)"))
        #expect(settingsSource.contains(
            "state.manualGatewayPortResolutionResult = .failure(.init(message: Self.invalidPortFailureMessage))"))
        #expect(actionsSource.contains("self.manualGatewayPortStore.send(.manualGatewayPortResolutionRequested(.init("))
        #expect(resolveManualPortFunction.contains("host: .init(value: host)"))
        #expect(resolveManualPortFunction.contains("useTLS: .init(value: self.manualGatewayTLS)"))
        #expect(actionsSource.contains("self.manualGatewayPortStore.send(.manualGatewayPortSynced(.init("))
        #expect(actionsSource.contains("port: .init(value: self.storedManualGatewayPort)"))
        #expect(actionsSource.contains(".manualGatewayPortSynced(.init(port: .init(value: link.port)))"))
        #expect(actionsSource.contains(
            "self.manualGatewayPortStore.send(.manualGatewayPortTextChanged(.init(text: .init(value: $0))))"))
        #expect(!settingsSource.contains("var host: String\n            var useTLS: Bool"))
        #expect(!settingsSource.contains("state.resolvedManualPort(host: request.host, useTLS: request.useTLS)"))
        #expect(!resolveManualPortFunction.contains("host: host,\n            useTLS: self.manualGatewayTLS"))
        #expect(!manualPortFeature.contains("var manualGatewayPort = 18789"))
        #expect(!manualPortFeature.contains("var manualGatewayPortText = \"18789\""))
        #expect(!manualPortFeature.contains("state.manualGatewayPort = port"))
        #expect(!manualPortFeature.contains("state.manualGatewayPortText = port > 0 ? String(port) : \"\""))
        #expect(!manualPortFeature.contains("state.manualGatewayPortText = filtered"))
        #expect(!manualPortFeature.contains("state.manualGatewayPort = Int(filtered) ?? 0"))
        #expect(!manualPortFeature.contains("struct ManualGatewayPortSync: Equatable, Sendable { var port: Int }"))
        #expect(!settingsSource.contains("struct ManualGatewayPortTextChange: Equatable, Sendable { var text: String }"))
        #expect(!actionsSource.contains(".manualGatewayPortSynced(.init(port: self.storedManualGatewayPort))"))
        #expect(!actionsSource.contains(".manualGatewayPortSynced(.init(port: link.port))"))
        #expect(!actionsSource.contains(".manualGatewayPortTextChanged(.init(text: $0))"))
        #expect(actionsSource.contains("self.manualGatewayPortStore.send(.manualGatewayPortResolutionResultHandled)"))
        #expect(resolveManualPortFunction.contains(
            "self.gatewaySetupStatusStore.send(.statusChanged(.init(statusText: .init(value: failure.message.value)))"))
        #expect(applyFunction.contains("self.resolveManualPortForConnection(host: host)"))
        #expect(scannedConnectFunction.contains("self.resolveManualPortForConnection(host: host)"))
        #expect(!manualPortFeature.contains("struct Failure: Equatable, Sendable { var message: String }"))
        #expect(!manualPortFeature.contains("case failure(String)"))
        #expect(!actionsSource.contains("func resolvedManualPort(host: String)"))
        #expect(!resolveManualPortFunction.contains("failure.message)))"))
        #expect(!applyFunction.contains("Failed: invalid port"))
        #expect(!scannedConnectFunction.contains("Failed: invalid port"))
    }

    @Test func `settings gateway auto connect toggle is reducer typed`() throws {
        let settingsSource = try Self.settingsProTabCombinedSource()
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let autoConnectFeature = try Self.extract(
            settingsSource,
            from: "struct SettingsGatewayAutoConnectFeature",
            to: "struct SettingsOnboardingStateFeature")

        #expect(autoConnectFeature.contains("struct GatewayAutoConnectEnabled: Equatable, Sendable"))
        #expect(autoConnectFeature.contains("struct EnabledChange: Equatable, Sendable"))
        #expect(autoConnectFeature.contains("var enabled: GatewayAutoConnectEnabled"))
        #expect(autoConnectFeature.contains("struct EnabledSync: Equatable, Sendable { var enabled: GatewayAutoConnectEnabled }"))
        #expect(autoConnectFeature.contains("var enabled = Action.GatewayAutoConnectEnabled(value: false)"))
        #expect(autoConnectFeature.contains("var isEnabled: Bool"))
        #expect(autoConnectFeature.contains("self.enabled.value"))
        #expect(autoConnectFeature.contains("state.enabled = change.enabled"))
        #expect(autoConnectFeature.contains("state.enabled = sync.enabled"))
        #expect(actionsSource.contains("self.gatewayAutoConnectStore.send(.enabledChanged(.init("))
        #expect(actionsSource.contains("enabled: .init(value: enabled)"))
        #expect(actionsSource.contains("self.gatewayAutoConnectStore.send(.enabledSynced(.init("))
        #expect(actionsSource.contains("enabled: .init(value: self.storedGatewayAutoConnect)"))
        #expect(settingsSource.contains(
            "self.gatewayAutoConnectStore.send(.enabledSynced(.init(enabled: .init(value: newValue))))"))
        #expect(!autoConnectFeature.contains("var isEnabled = false"))
        #expect(!autoConnectFeature.contains("state.isEnabled = change.enabled.value"))
        #expect(!autoConnectFeature.contains("state.isEnabled = sync.enabled.value"))
        #expect(!autoConnectFeature.contains("struct EnabledChange: Equatable, Sendable { var isEnabled: Bool }"))
        #expect(!autoConnectFeature.contains("struct EnabledSync: Equatable, Sendable { var isEnabled: Bool }"))
        #expect(!autoConnectFeature.contains("state.isEnabled = change.isEnabled"))
        #expect(!autoConnectFeature.contains("state.isEnabled = sync.isEnabled"))
        #expect(!actionsSource.contains("enabledChanged(.init(isEnabled:"))
        #expect(!settingsSource.contains("enabledSynced(.init(isEnabled:"))
    }

    @Test func `settings gateway preflight decision is reducer owned`() throws {
        let gatewaySetupFeaturesSource = try String(
            contentsOf: Self.settingsGatewaySetupFeaturesSourceURL(),
            encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let preflightFunction = try Self.extract(
            actionsSource,
            from: "func preflightGateway(host: String) async -> Bool",
            to: "func resetOnboarding() async")

        #expect(gatewaySetupFeaturesSource.contains("enum GatewayPreflightResult: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct Blocked: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct LocalNetworkAccess: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource
            .contains("struct GatewayPreflightStatusText: Equatable, Sendable { var value: String? }"))
        #expect(gatewaySetupFeaturesSource.contains("var statusText: GatewayPreflightStatusText"))
        #expect(gatewaySetupFeaturesSource.contains("struct ManualGatewayTailnetIPv4Availability: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("var host: ManualGatewayHost"))
        #expect(gatewaySetupFeaturesSource.contains("var hasTailnetIPv4: ManualGatewayTailnetIPv4Availability"))
        #expect(gatewaySetupFeaturesSource.contains("let trimmed = request.host.value.trimmingCharacters"))
        #expect(gatewaySetupFeaturesSource.contains("!request.hasTailnetIPv4.value"))
        #expect(gatewaySetupFeaturesSource
            .contains("state.preflightResult = .blocked(.init(statusText: .init(value: nil)))"))
        #expect(gatewaySetupFeaturesSource.contains("case preflightRequested(GatewayPreflightRequest)"))
        #expect(gatewaySetupFeaturesSource.contains("struct SettingsLocalNetworkAccessClient"))
        #expect(gatewaySetupFeaturesSource.contains(
            "requestLocalNetworkAccess: @MainActor @Sendable (_ reason: SettingsLocalNetworkAccessReason)"))
        #expect(gatewaySetupFeaturesSource.contains("case localNetworkAccessRequested(LocalNetworkAccessRequest)"))
        #expect(gatewaySetupFeaturesSource.contains("@Dependency(\\.settingsLocalNetworkAccess)"))
        #expect(gatewaySetupFeaturesSource.contains(
            "await localNetworkAccessClient.requestLocalNetworkAccess(request.reason)"))
        #expect(gatewaySetupFeaturesSource
            .contains("state.preflightResult = .requestLocalNetworkAccess(.init(reason: .settingsPreflight))"))
        #expect(actionsSource.contains("self.manualGatewayEndpointStore.send(.preflightRequested(.init("))
        #expect(preflightFunction.contains("host: .init(value: host)"))
        #expect(preflightFunction.contains("hasTailnetIPv4: .init(value: Self.hasTailnetIPv4())"))
        #expect(preflightFunction.contains("if let statusText = blocked.statusText.value"))
        #expect(actionsSource.contains("self.manualGatewayEndpointStore.send(.preflightResultHandled)"))
        #expect(actionsSource.contains("self.manualGatewayEndpointStore.send(.localNetworkAccessRequested(.init("))
        #expect(!gatewaySetupFeaturesSource.contains("var statusText: String?"))
        #expect(!preflightFunction.contains("if let statusText = blocked.statusText {"))
        #expect(!actionsSource.contains("self.gatewayController.requestLocalNetworkAccess(reason: reason)"))
        #expect(!preflightFunction.contains("SettingsManualGatewayEndpointFeature.State.isTailnetHostOrIP"))
        #expect(!preflightFunction.contains("\"Tailscale is off on this device. Turn it on, then try again.\""))
        #expect(!preflightFunction.contains("hasTailnetIPv4: Self.hasTailnetIPv4()"))
        #expect(!preflightFunction.contains("requestLocalNetworkAccess(reason: \"settings_preflight\")"))
    }

    @Test func `settings setup auth derivation is reducer owned`() throws {
        let settingsSource = try Self.settingsProTabCombinedSource()
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let supportSource = try String(contentsOf: Self.settingsProTabSupportSourceURL(), encoding: .utf8)
        let applyGatewayLinkFunction = try Self.extract(
            actionsSource,
            from: "func applyGatewayLink(_ link: GatewayConnectDeepLink) async",
            to: "func openGatewayQRScanner()")

        #expect(supportSource.contains("struct SettingsGatewaySetupAuthPersistenceRequest: Equatable"))
        #expect(settingsSource.contains("var setupAuthPersistenceRequest: SettingsGatewaySetupAuthPersistenceRequest?"))
        #expect(settingsSource.contains("struct SetupAuthApplication: Equatable, Sendable"))
        #expect(settingsSource.contains("struct SetupLinkApplication: Equatable, Sendable"))
        #expect(settingsSource.contains("case setupAuthApplied(SetupAuthApplication)"))
        #expect(settingsSource.contains("case setupLinkApplied(SetupLinkApplication)"))
        #expect(settingsSource.contains("case setupAuthPersistenceRequested(SettingsGatewaySetupAuthPersistenceRequest)"))
        #expect(settingsSource.contains("case setupAuthPersistenceRequestHandled"))
        #expect(settingsSource.contains("@Dependency(\\.settingsGatewaySetupAuthPersistence)"))
        #expect(settingsSource
            .contains("let setupAuth = GatewayConnectionController.ManualAuthOverride." +
                "setupAuth(from: application.link)"))
        #expect(settingsSource.contains("guard request.trimmedInstanceId != nil else { return .none }"))
        #expect(settingsSource.contains("setupAuthPersistenceClient.currentInstanceID()"))
        #expect(!settingsSource.contains("setupAuthPersistenceClient.currentInstanceID().value"))
        #expect(settingsSource.contains("await setupAuthPersistenceClient.prepareForBootstrapPairing(request.instanceId)"))
        #expect(settingsSource.contains("await setupAuthPersistenceClient.saveSetupAuth(request)"))
        #expect(supportSource.contains("let instanceId: SettingsGatewayCurrentInstanceID"))
        #expect(supportSource.contains("var trimmedInstanceId: String?"))
        #expect(supportSource.contains("struct SettingsGatewaySetupAuthPersistenceClient"))
        #expect(supportSource.contains("struct SettingsGatewayCurrentInstanceID: Equatable, Sendable"))
        #expect(supportSource.contains(
            "var currentInstanceID: @Sendable () -> SettingsGatewayCurrentInstanceID"))
        #expect(supportSource.contains(
            "var prepareForBootstrapPairing: @MainActor @Sendable (_ instanceId: SettingsGatewayCurrentInstanceID) -> Void"))
        #expect(supportSource.contains("prepareForBootstrapPairing"))
        #expect(supportSource
            .contains("GatewayOnboardingReset.prepareForBootstrapPairing(appModel: appModel, instanceId: instanceId)"))
        #expect(supportSource.contains("GatewaySettingsStore.currentInstanceID()"))
        #expect(supportSource.contains("GatewaySettingsStore.saveGatewayBootstrapToken("))
        #expect(supportSource.contains("GatewaySettingsStore.saveGatewayToken("))
        #expect(supportSource.contains("GatewaySettingsStore.saveGatewayPassword("))
        #expect(rootSource.contains("self.makeSettingsGatewayCredentialsStore()"))
        #expect(storesSource.contains("setupAuthPersistenceClient: .live(appModel: self.appModel)"))
        #expect(actionsSource.contains("guard await self.applySetupCode() else { return }"))
        #expect(actionsSource.contains("await self.applyGatewayLink(link)"))
        #expect(actionsSource.contains("await self.applyGatewayLink(scannedLink)"))
        #expect(actionsSource.contains("self.gatewayCredentialsStore.send(.setupLinkApplied(.init(link: link)))"))
        #expect(actionsSource
            .contains("await self.gatewayCredentialsStore.send(.setupAuthPersistenceRequested(request)).finish()"))
        #expect(actionsSource.contains("self.gatewayCredentialsStore.send(.setupAuthPersistenceRequestHandled)"))
        #expect(!applyGatewayLinkFunction
            .contains("GatewayConnectionController.ManualAuthOverride.setupAuth(from: link)"))
        #expect(!applyGatewayLinkFunction.contains(".setupAuthApplied(setupAuth)"))
        #expect(!applyGatewayLinkFunction.contains("GatewayOnboardingReset.prepareForBootstrapPairing"))
        #expect(!applyGatewayLinkFunction.contains("GatewaySettingsStore.currentInstanceID"))
        #expect(!applyGatewayLinkFunction.contains("GatewaySettingsStore.saveGatewayBootstrapToken"))
        #expect(!applyGatewayLinkFunction.contains("GatewaySettingsStore.saveGatewayToken"))
        #expect(!applyGatewayLinkFunction.contains("GatewaySettingsStore.saveGatewayPassword"))
    }

    @Test func `settings manual credential persistence is reducer effect owned`() throws {
        let settingsSource = try Self.settingsProTabCombinedSource()
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let supportSource = try String(contentsOf: Self.settingsProTabSupportSourceURL(), encoding: .utf8)
        let updateCredentialsFunction = try Self.extract(
            actionsSource,
            from: "func updateGatewayToken(_ value: String)",
            to: "var manualPortIsValid")

        #expect(supportSource.contains("struct SettingsGatewayCredentialsPersistenceClient"))
        #expect(supportSource.contains("struct SettingsGatewayCredentialValue: Equatable, Sendable"))
        #expect(supportSource.contains("struct SettingsGatewayCredentialDraft: Equatable, Sendable"))
        #expect(supportSource.contains("_ value: SettingsGatewayCredentialValue"))
        #expect(settingsSource.contains("struct ManualCredentialChange: Equatable, Sendable"))
        #expect(settingsSource.contains("var draft: SettingsGatewayCredentialDraft"))
        #expect(settingsSource.contains("struct ManualCredentialPersistenceRequest: Equatable, Sendable"))
        #expect(settingsSource.contains("var value: SettingsGatewayCredentialValue"))
        #expect(settingsSource.contains("case gatewayTokenChanged(ManualCredentialChange)"))
        #expect(settingsSource.contains("case gatewayPasswordChanged(ManualCredentialChange)"))
        #expect(settingsSource.contains("case gatewayTokenPersistenceRequested(ManualCredentialPersistenceRequest)"))
        #expect(settingsSource.contains("case gatewayPasswordPersistenceRequested(ManualCredentialPersistenceRequest)"))
        #expect(settingsSource.contains("await persistenceClient.saveGatewayToken("))
        #expect(settingsSource.contains("await persistenceClient.saveGatewayPassword("))
        #expect(settingsSource.contains("var gatewayTokenDraft = SettingsGatewayCredentialDraft(value: \"\")"))
        #expect(settingsSource.contains("var gatewayPasswordDraft = SettingsGatewayCredentialDraft(value: \"\")"))
        #expect(settingsSource.contains("var gatewayToken: String"))
        #expect(settingsSource.contains("var gatewayPassword: String"))
        #expect(settingsSource.contains("self.gatewayTokenDraft.value"))
        #expect(settingsSource.contains("self.gatewayPasswordDraft.value"))
        #expect(settingsSource.contains("state.gatewayTokenDraft = change.draft"))
        #expect(settingsSource.contains("state.gatewayPasswordDraft = change.draft"))
        #expect(settingsSource.contains("manualCredentialPersistenceRequest("))
        #expect(actionsSource.contains("self.gatewayCredentialsStore.send(.gatewayTokenPersistenceRequested(.init("))
        #expect(actionsSource.contains("self.gatewayCredentialsStore.send(.gatewayPasswordPersistenceRequested(.init("))
        #expect(updateCredentialsFunction.contains("draft: .init(value: value)"))
        #expect(updateCredentialsFunction.contains("value: .init(rawValue: value)"))
        #expect(!settingsSource.contains("var gatewayToken = \"\""))
        #expect(!settingsSource.contains("var gatewayPassword = \"\""))
        #expect(!settingsSource.contains("state.gatewayToken = change.draft.value"))
        #expect(!settingsSource.contains("state.gatewayPassword = change.draft.value"))
        #expect(actionsSource.contains("func persistGatewayToken") == false)
        #expect(actionsSource.contains("func persistGatewayPassword") == false)
        #expect(updateCredentialsFunction.contains("GatewaySettingsStore.saveGatewayToken") == false)
        #expect(updateCredentialsFunction.contains("GatewaySettingsStore.saveGatewayPassword") == false)
    }

    @Test func `settings discovered gateway persistence is reducer effect owned`() throws {
        let connectionSource = try String(contentsOf: Self.settingsGatewayConnectionFeatureSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let supportSource = try String(contentsOf: Self.settingsProTabSupportSourceURL(), encoding: .utf8)
        let connectFunction = try Self.extract(
            actionsSource,
            from: "func connect(_ gateway: GatewayDiscoveryModel.DiscoveredGateway) async",
            to: "func applySetupCodeAndConnect() async")

        #expect(supportSource.contains("struct SettingsDiscoveredGatewayPersistenceClient"))
        #expect(supportSource.contains("struct SettingsGatewayStableID: Equatable, Sendable"))
        #expect(supportSource.contains(
            "var saveSelectedGatewayStableID: @MainActor @Sendable (_ stableID: SettingsGatewayStableID) -> Void"))
        #expect(supportSource.contains("GatewaySettingsStore.savePreferredGatewayStableID(stableID)"))
        #expect(supportSource.contains("GatewaySettingsStore.saveLastDiscoveredGatewayStableID(stableID)"))
        #expect(connectionSource.contains("struct GatewayConnectionID: Equatable, Sendable"))
        #expect(connectionSource.contains("var connectingGatewayID: GatewayConnectionID?"))
        #expect(connectionSource.contains("struct ConnectionStart: Equatable, Sendable"))
        #expect(connectionSource.contains("var gatewayID: GatewayConnectionID"))
        #expect(connectionSource.contains("state.connectingGatewayID = start.gatewayID"))
        #expect(connectionSource.contains("struct DiscoveredGatewayConnectionFailureMessage: Equatable, Sendable"))
        #expect(connectionSource.contains("enum DiscoveredGatewayConnectionResult: Equatable, Sendable"))
        #expect(connectionSource.contains(
            "struct Failure: Equatable, Sendable { var message: DiscoveredGatewayConnectionFailureMessage }"))
        #expect(connectionSource.contains(
            "var discoveredGatewayConnectionResult: DiscoveredGatewayConnectionResult?"))
        #expect(connectionSource.contains(
            "case discoveredGatewayConnectionResultReceived(DiscoveredGatewayConnectionResult)"))
        #expect(connectionSource.contains("case discoveredGatewayConnectionResultHandled"))
        #expect(connectionSource.contains("state.discoveredGatewayConnectionResult = result"))
        #expect(connectionSource.contains("state.discoveredGatewayConnectionResult = nil"))
        #expect(connectionSource.contains("struct DiscoveredGatewayPersistenceRequest: Equatable, Sendable"))
        #expect(connectionSource.contains("var stableID: SettingsGatewayStableID"))
        #expect(connectionSource.contains("case discoveredGatewayPersistenceRequested(DiscoveredGatewayPersistenceRequest)"))
        #expect(connectionSource.contains("@Dependency(\\.settingsDiscoveredGatewayPersistence)"))
        #expect(connectionSource.contains("guard request.stableID.trimmedValue != nil else { return .none }"))
        #expect(connectionSource.contains("await persistenceClient.saveSelectedGatewayStableID(request.stableID)"))
        #expect(actionsSource.contains("self.gatewayConnectionStore.send(.connectionStarted(.init(gatewayID:"))
        #expect(actionsSource.contains("gatewayID: .init(value: gateway.id)"))
        #expect(actionsSource.contains("gatewayID: .init(value: \"manual\")"))
        #expect(actionsSource.contains("self.gatewayConnectionStore.send(.discoveredGatewayPersistenceRequested(.init("))
        #expect(connectFunction.contains("stableID: .init(value: gateway.stableID)"))
        #expect(connectFunction.contains(
            "self.gatewayConnectionStore.send(.discoveredGatewayConnectionResultReceived(.failure(.init("))
        #expect(connectFunction.contains("message: .init(value: failure.message)"))
        #expect(connectFunction.contains(
            "self.gatewayConnectionStore.send(.discoveredGatewayConnectionResultReceived(.connected))"))
        #expect(connectFunction.contains("self.gatewayConnectionStore.discoveredGatewayConnectionResult"))
        #expect(connectFunction.contains("self.gatewayConnectionStore.send(.discoveredGatewayConnectionResultHandled)"))
        #expect(connectFunction.contains("case let .failure(failure):"))
        #expect(connectFunction.contains(
            "self.gatewaySetupStatusStore.send(.statusChanged(.init(statusText: .init(value: failure.message.value)))"))
        #expect(!connectionSource.contains("var gatewayID: String"))
        #expect(!connectionSource.contains("var connectingGatewayID: String?"))
        #expect(!connectionSource.contains("struct Failure: Equatable, Sendable { var message: String }"))
        #expect(!connectionSource.contains("state.connectingGatewayID = start.gatewayID.value"))
        #expect(!actionsSource.contains("gatewayID: gateway.id"))
        #expect(!actionsSource.contains("gatewayID: \"manual\""))
        #expect(!connectFunction.contains(
            "self.gatewaySetupStatusStore.send(.statusChanged(.init(statusText: .init(value: failure.message)))"))
        #expect(connectFunction.contains("GatewaySettingsStore.savePreferredGatewayStableID") == false)
        #expect(connectFunction.contains("GatewaySettingsStore.saveLastDiscoveredGatewayStableID") == false)
    }

    @Test func `settings gateway connection status sync action is typed`() throws {
        let connectionSource = try String(contentsOf: Self.settingsGatewayConnectionFeatureSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let syncGatewayConnectionFunction = try Self.extract(
            actionsSource,
            from: "func syncGatewayConnectionStatusState()",
            to: "func connect(_ gateway: GatewayDiscoveryModel.DiscoveredGateway) async")

        #expect(connectionSource.contains("struct GatewayAppleReviewDemoModeEnabled: Equatable, Sendable"))
        #expect(connectionSource.contains("struct GatewayConnectionStatusConnected: Equatable, Sendable"))
        #expect(connectionSource.contains("struct GatewayDisplayStatusText: Equatable, Sendable"))
        #expect(connectionSource.contains("struct GatewayAgentCount: Equatable, Sendable"))
        #expect(connectionSource.contains("struct GatewayRemoteAddress: Equatable, Sendable"))
        #expect(connectionSource.contains("struct GatewayServerName: Equatable, Sendable"))
        #expect(connectionSource.contains("struct GatewayStatusSync: Equatable, Sendable"))
        #expect(connectionSource.contains("var gatewayAgentCount = Action.GatewayAgentCount(value: 0)"))
        #expect(connectionSource.contains("var gatewayDisplayStatusText = GatewayDisplayStatusText(value: \"Offline\")"))
        #expect(connectionSource.contains("var gatewayRemoteAddress = GatewayRemoteAddress(value: nil)"))
        #expect(connectionSource.contains("var gatewayServerName = GatewayServerName(value: nil)"))
        #expect(connectionSource.contains(
            "var gatewayStatusConnected = Action.GatewayConnectionStatusConnected(value: false)"))
        #expect(connectionSource.contains(
            "var isAppleReviewDemoModeEnabled = Action.GatewayAppleReviewDemoModeEnabled(value: false)"))
        #expect(connectionSource.contains("var isAppleReviewDemoModeEnabled: GatewayAppleReviewDemoModeEnabled"))
        #expect(connectionSource.contains("var gatewayStatusConnected: GatewayConnectionStatusConnected"))
        #expect(connectionSource.contains("var gatewayDisplayStatusText: GatewayDisplayStatusText"))
        #expect(connectionSource.contains("var gatewayAgentCount: GatewayAgentCount"))
        #expect(connectionSource.contains("var gatewayRemoteAddress: GatewayRemoteAddress"))
        #expect(connectionSource.contains("var gatewayServerName: GatewayServerName"))
        #expect(connectionSource.contains(
            "state.isAppleReviewDemoModeEnabled = sync.isAppleReviewDemoModeEnabled"))
        #expect(connectionSource.contains("state.gatewayStatusConnected = sync.gatewayStatusConnected"))
        #expect(connectionSource.contains("state.gatewayDisplayStatusText = sync.gatewayDisplayStatusText"))
        #expect(connectionSource.contains("state.gatewayAgentCount = sync.gatewayAgentCount"))
        #expect(connectionSource.contains("state.gatewayRemoteAddress = sync.gatewayRemoteAddress"))
        #expect(connectionSource.contains("state.gatewayServerName = sync.gatewayServerName"))
        #expect(connectionSource.contains("case gatewayStatusSynced(GatewayStatusSync)"))
        #expect(syncGatewayConnectionFunction.contains("self.gatewayConnectionStore.send(.gatewayStatusSynced(.init("))
        #expect(syncGatewayConnectionFunction.contains(
            "isAppleReviewDemoModeEnabled: .init(value: self.appModel.isAppleReviewDemoModeEnabled)"))
        #expect(syncGatewayConnectionFunction.contains(
            "gatewayStatusConnected: .init(value: GatewayStatusBuilder.build(appModel: self.appModel) == .connected)"))
        #expect(syncGatewayConnectionFunction.contains(
            "gatewayDisplayStatusText: .init(value: self.appModel.gatewayDisplayStatusText)"))
        #expect(syncGatewayConnectionFunction.contains("gatewayAgentCount: .init(value: self.appModel.gatewayAgents.count)"))
        #expect(syncGatewayConnectionFunction.contains(
            "gatewayRemoteAddress: .init(value: self.appModel.gatewayRemoteAddress)"))
        #expect(syncGatewayConnectionFunction.contains("gatewayServerName: .init(value: self.appModel.gatewayServerName)"))
        #expect(!connectionSource.contains("case gatewayStatusSynced(\n            isAppleReviewDemoModeEnabled: Bool"))
        #expect(!connectionSource.contains(
            "var isAppleReviewDemoModeEnabled: Bool\n            var gatewayStatusConnected: Bool"))
        #expect(!connectionSource.contains("var gatewayAgentCount = 0"))
        #expect(!connectionSource.contains("var gatewayDisplayStatusText = \"Offline\""))
        #expect(!connectionSource.contains("var gatewayStatusConnected = false"))
        #expect(!connectionSource.contains("var isAppleReviewDemoModeEnabled = false"))
        #expect(!connectionSource.contains("var gatewayDisplayStatusText: String"))
        #expect(!connectionSource.contains("var gatewayAgentCount: Int"))
        #expect(!connectionSource.contains("var gatewayRemoteAddress: String?"))
        #expect(!connectionSource.contains("var gatewayServerName: String?"))
        #expect(!connectionSource.contains(
            "var gatewayRemoteAddress: String?\n            var gatewayServerName: String?"))
        #expect(!connectionSource.contains(
            "state.isAppleReviewDemoModeEnabled = sync.isAppleReviewDemoModeEnabled.value"))
        #expect(!connectionSource.contains("state.gatewayStatusConnected = sync.gatewayStatusConnected.value"))
        #expect(!connectionSource.contains("state.gatewayDisplayStatusText = sync.gatewayDisplayStatusText.value"))
        #expect(!connectionSource.contains("state.gatewayAgentCount = sync.gatewayAgentCount.value"))
        #expect(!connectionSource.contains("state.gatewayRemoteAddress = sync.gatewayRemoteAddress.value"))
        #expect(!connectionSource.contains("state.gatewayServerName = sync.gatewayServerName.value"))
        #expect(!syncGatewayConnectionFunction.contains(
            "isAppleReviewDemoModeEnabled: self.appModel.isAppleReviewDemoModeEnabled"))
        #expect(!syncGatewayConnectionFunction.contains(
            "gatewayStatusConnected: GatewayStatusBuilder.build(appModel: self.appModel) == .connected"))
        #expect(!syncGatewayConnectionFunction.contains("gatewayDisplayStatusText: self.appModel.gatewayDisplayStatusText"))
        #expect(!syncGatewayConnectionFunction.contains("gatewayAgentCount: self.appModel.gatewayAgents.count"))
        #expect(!syncGatewayConnectionFunction.contains("gatewayRemoteAddress: self.appModel.gatewayRemoteAddress"))
        #expect(!syncGatewayConnectionFunction.contains("gatewayServerName: self.appModel.gatewayServerName"))
    }

    @Test func `settings share instruction persistence is reducer owned`() throws {
        let settingsSource = try Self.settingsProTabCombinedSource()
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let supportSource = try String(contentsOf: Self.settingsProTabSupportSourceURL(), encoding: .utf8)
        let syncSettingsFunction = try Self.extract(
            actionsSource,
            from: "func syncSettingsState()",
            to: "func syncVoiceControlState()")

        #expect(supportSource.contains("struct SettingsShareInstructionPersistenceClient"))
        #expect(supportSource.contains("struct SettingsDefaultShareInstruction: Equatable, Sendable"))
        #expect(supportSource.contains(
            "var loadDefaultInstruction: @Sendable () -> SettingsDefaultShareInstruction"))
        #expect(supportSource.contains(
            "var saveDefaultInstruction: @MainActor @Sendable (_ instruction: SettingsDefaultShareInstruction) -> Void"))
        #expect(supportSource.contains("ShareToAgentSettings.loadDefaultInstruction()"))
        #expect(supportSource.contains("ShareToAgentSettings.saveDefaultInstruction(instruction.value)"))
        #expect(settingsSource.contains("@Dependency(\\.settingsShareInstructionPersistence)"))
        #expect(settingsSource.contains("struct DefaultShareInstructionChange: Equatable, Sendable"))
        #expect(settingsSource.contains("var instruction: SettingsDefaultShareInstruction"))
        #expect(!settingsSource.contains("struct DefaultShareInstructionPersistenceRequest: Equatable, Sendable"))
        #expect(settingsSource.contains("case defaultShareInstructionLoadRequested"))
        #expect(settingsSource.contains(
            "case defaultShareInstructionPersistenceRequested(SettingsDefaultShareInstruction)"))
        #expect(settingsSource.contains("var defaultShareInstructionValue = SettingsDefaultShareInstruction(value: \"\")"))
        #expect(settingsSource.contains("var defaultShareInstruction: String"))
        #expect(settingsSource.contains("self.defaultShareInstructionValue.value"))
        #expect(settingsSource.contains("state.defaultShareInstructionValue = change.instruction"))
        #expect(settingsSource.contains("state.defaultShareInstructionValue = persistenceClient.loadDefaultInstruction()"))
        #expect(settingsSource.contains("await persistenceClient.saveDefaultInstruction(instruction)"))
        #expect(settingsSource.contains(".defaultShareInstructionChanged(.init("))
        #expect(settingsSource.contains("instruction: .init(value: $0)"))
        #expect(!settingsSource.contains(".defaultShareInstructionChanged(.init(value: $0))"))
        #expect(!settingsSource.contains("var defaultShareInstruction = \"\""))
        #expect(!settingsSource.contains("state.defaultShareInstruction = change.instruction.value"))
        #expect(!settingsSource.contains("state.defaultShareInstruction = persistenceClient.loadDefaultInstruction().value"))
        #expect(actionsSource.contains("self.shareInstructionStore.send(.defaultShareInstructionLoadRequested)"))
        #expect(syncSettingsFunction.contains("ShareToAgentSettings.loadDefaultInstruction") == false)
        #expect(settingsSource.contains("ShareToAgentSettings.saveDefaultInstruction") == false)
        #expect(settingsSource.contains("defaultShareInstructionLoaded(") == false)
    }

    @Test func `settings credential loading is reducer owned`() throws {
        let settingsSource = try Self.settingsProTabCombinedSource()
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let supportSource = try String(contentsOf: Self.settingsProTabSupportSourceURL(), encoding: .utf8)
        let syncSettingsFunction = try Self.extract(
            actionsSource,
            from: "func syncSettingsState()",
            to: "func syncVoiceControlState()")

        #expect(supportSource.contains("GatewaySettingsStore.loadGatewayToken(instanceId: instanceId)"))
        #expect(supportSource.contains("GatewaySettingsStore.loadGatewayPassword(instanceId: instanceId)"))
        #expect(supportSource.contains("struct SettingsGatewayStoredCredentials: Equatable, Sendable"))
        #expect(supportSource.contains(
            "var loadCredentials: @Sendable (_ instanceId: SettingsGatewayCurrentInstanceID)"))
        #expect(settingsSource.contains(
            "struct CredentialsLoadRequest: Equatable, Sendable"))
        #expect(settingsSource.contains("var instanceId: SettingsGatewayCurrentInstanceID"))
        #expect(settingsSource.contains("case credentialsLoadRequested(CredentialsLoadRequest)"))
        #expect(settingsSource.contains("case credentialsLoaded(SettingsGatewayStoredCredentials)"))
        #expect(settingsSource.contains("guard request.instanceId.trimmedValue != nil else { return .none }"))
        #expect(settingsSource.contains("persistenceClient.loadCredentials(request.instanceId)"))
        #expect(!settingsSource.contains("persistenceClient.loadCredentials(trimmedInstanceId)"))
        #expect(!settingsSource.contains("persistenceClient.loadGatewayToken(trimmedInstanceId)"))
        #expect(!settingsSource.contains("persistenceClient.loadGatewayPassword(trimmedInstanceId)"))
        #expect(!settingsSource.contains("trimmedInstanceId(_ instanceId: String) -> String?"))
        #expect(actionsSource.contains("self.gatewayCredentialsStore.send(.credentialsLoadRequested(.init("))
        #expect(syncSettingsFunction.contains("GatewaySettingsStore.loadGatewayToken") == false)
        #expect(syncSettingsFunction.contains("GatewaySettingsStore.loadGatewayPassword") == false)
        #expect(syncSettingsFunction.contains("credentialsLoaded(") == false)
    }

    @Test func `onboarding setup code apply result is reducer owned`() throws {
        let onboardingSource = try String(contentsOf: Self.onboardingWizardSourceURL(), encoding: .utf8)
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)
        let loadedCredentials = try Self.extract(
            onboardingStateSource,
            from: "struct LoadedCredentials",
            to: "struct GatewayPasswordChange")
        let gatewayPasswordChange = try Self.extract(
            onboardingStateSource,
            from: "struct GatewayPasswordChange",
            to: "struct GatewayTokenChange")
        let gatewayTokenChange = try Self.extract(
            onboardingStateSource,
            from: "struct GatewayTokenChange",
            to: "struct SetupAuthApplication")
        let setupCodeChange = try Self.extract(
            onboardingStateSource,
            from: "struct SetupCodeChange",
            to: "case appleReviewDemoCodeAccepted")
        let appleReviewDemoSetupCode = try Self.extract(
            onboardingStateSource,
            from: "struct AppleReviewDemoSetupCode",
            to: "case appleReviewDemoSetupCode")

        #expect(onboardingStateSource.contains("struct OnboardingSetupCode: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct OnboardingGatewayToken: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct OnboardingGatewayPassword: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct GatewayPasswordChange: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct GatewayTokenChange: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct LoadedCredentials: Equatable, Sendable"))
        #expect(loadedCredentials.contains("var token: OnboardingGatewayToken"))
        #expect(loadedCredentials.contains("var password: OnboardingGatewayPassword"))
        #expect(gatewayPasswordChange.contains("var password: OnboardingGatewayPassword"))
        #expect(gatewayTokenChange.contains("var token: OnboardingGatewayToken"))
        #expect(onboardingStateSource.contains("struct SetupAuthApplication: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct SetupCodeChange: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct ScannedSetupCode: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("var setupCodeState = OnboardingSetupCode(value: \"\")"))
        #expect(onboardingStateSource.contains("var setupCode: String {\n            self.setupCodeState.value"))
        #expect(setupCodeChange.contains("var code: OnboardingSetupCode"))
        #expect(appleReviewDemoSetupCode.contains("var code: OnboardingSetupCode"))
        #expect(onboardingStateSource.contains("struct ScannedGatewayLink: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("case credentialsLoaded(LoadedCredentials)"))
        #expect(onboardingStateSource.contains("case gatewayTokenChanged(GatewayTokenChange)"))
        #expect(onboardingStateSource.contains("case gatewayPasswordChanged(GatewayPasswordChange)"))
        #expect(onboardingStateSource.contains("case setupAuthApplied(SetupAuthApplication)"))
        #expect(onboardingStateSource.contains("case setupCodeChanged(SetupCodeChange)"))
        #expect(onboardingStateSource.contains("case scannedSetupCodeReceived(ScannedSetupCode)"))
        #expect(onboardingStateSource.contains("case scannedGatewayLinkReceived(ScannedGatewayLink)"))
        #expect(onboardingStateSource.contains("struct AppleReviewDemoSetupCode: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("state.gatewayToken = credentials.token.value"))
        #expect(onboardingStateSource.contains("state.gatewayPassword = credentials.password.value"))
        #expect(onboardingStateSource.contains("state.gatewayToken = change.token.value"))
        #expect(onboardingStateSource.contains("state.gatewayPassword = change.password.value"))
        #expect(onboardingStateSource.contains("state.gatewayToken = application.setupAuth.token"))
        #expect(onboardingSource.contains("self.credentialsStore.send(.credentialsLoaded(.init("))
        #expect(onboardingSource.contains("token: .init(value: GatewaySettingsStore.loadGatewayToken"))
        #expect(onboardingSource.contains("password: .init(value: GatewaySettingsStore.loadGatewayPassword"))
        #expect(onboardingSource.contains("self.credentialsStore.send(.setupAuthApplied(.init(setupAuth: setupAuth)))"))
        #expect(onboardingSource.contains("self.credentialsStore.send(.gatewayTokenChanged(.init(token: .init(value: $0))))"))
        #expect(onboardingSource.contains("self.credentialsStore.send(.gatewayPasswordChanged(.init(password: .init(value: $0))))"))
        #expect(onboardingSource.contains("self.setupCodeStore.send(.setupCodeChanged(.init(code: .init(value: $0))))"))
        #expect(onboardingSource.contains("get: { self.setupCodeStore.setupCode }"))
        #expect(onboardingStateSource.contains("enum ApplyResult: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("case appleReviewDemoSetupCode(AppleReviewDemoSetupCode)"))
        #expect(onboardingStateSource.contains("case applyRequested"))
        #expect(onboardingStateSource.contains("state.setupCodeState = change.code"))
        #expect(onboardingStateSource.contains("state.setupCodeState = .init(value: \"\")"))
        #expect(onboardingStateSource.contains("state.applyResult = .appleReviewDemoSetupCode(.init(code: .init(value: raw)))"))
        #expect(onboardingStateSource.contains("state.applyResult = .gatewayLink(link)"))
        #expect(onboardingSource.contains("self.setupCodeStore.send(.applyRequested)"))
        #expect(onboardingSource.contains("self.setupCodeStore.send(.applyResultHandled)"))
        #expect(!onboardingStateSource.contains("case appleReviewDemoSetupCode(String)"))
        #expect(!setupCodeChange.contains("var code: String"))
        #expect(!appleReviewDemoSetupCode.contains("var code: String"))
        #expect(!loadedCredentials.contains("var token: String"))
        #expect(!loadedCredentials.contains("var password: String"))
        #expect(!gatewayTokenChange.contains("var token: String"))
        #expect(!gatewayPasswordChange.contains("var password: String"))
        #expect(!onboardingSource.contains("self.credentialsStore.send(.gatewayTokenChanged(.init(value: $0)))"))
        #expect(!onboardingSource.contains("self.credentialsStore.send(.gatewayPasswordChanged(.init(value: $0)))"))
        #expect(!onboardingStateSource.contains("var setupCode = \"\""))
        #expect(!onboardingStateSource.contains("state.setupCode = \"\""))
        #expect(!onboardingStateSource.contains("state.setupCode = change.code.value"))
        #expect(!onboardingSource.contains("let raw = self.setupCodeStore.trimmedSetupCode"))
        #expect(!onboardingSource.contains("GatewayConnectDeepLink.fromSetupInput(raw)"))
        #expect(!onboardingSource.contains("AppleReviewDemoMode.isSetupCode(raw)"))
    }

    @Test func `onboarding manual connection request is reducer owned`() throws {
        let onboardingSource = try String(contentsOf: Self.onboardingWizardSourceURL(), encoding: .utf8)
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)
        let manualConnectionRequest = try Self.extract(
            onboardingStateSource,
            from: "struct ManualConnectionRequest",
            to: "enum Action")
        let manualHostChange = try Self.extract(
            onboardingStateSource,
            from: "struct ManualHostChange",
            to: "struct ManualPortTextChange")
        let manualPortTextChange = try Self.extract(
            onboardingStateSource,
            from: "struct ManualPortTextChange",
            to: "struct ManualTLSChange")
        let manualTLSChange = try Self.extract(
            onboardingStateSource,
            from: "struct ManualTLSChange",
            to: "struct ModeSelection")
        let gatewayLinkApplication = try Self.extract(
            onboardingStateSource,
            from: "struct GatewayLinkApplication",
            to: "struct Initialization")
        let initialization = try Self.extract(
            onboardingStateSource,
            from: "struct Initialization",
            to: "case developerModeDisabled")

        #expect(onboardingStateSource.contains("struct OnboardingManualHost: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct OnboardingManualPort: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct OnboardingManualPortText: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct OnboardingManualTLS: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("var manualHostState = OnboardingManualHost(value: \"\")"))
        #expect(onboardingStateSource.contains("var manualPortState = OnboardingManualPort(value: 18789)"))
        #expect(onboardingStateSource.contains("var manualPortTextState = OnboardingManualPortText(value: \"18789\")"))
        #expect(onboardingStateSource.contains("var manualHost: String {\n            self.manualHostState.value"))
        #expect(onboardingStateSource.contains("var manualPort: Int {\n            self.manualPortState.value"))
        #expect(onboardingStateSource.contains("var manualPortText: String {\n            self.manualPortTextState.value"))
        #expect(onboardingStateSource.contains("var manualTLSState = OnboardingManualTLS(value: true)"))
        #expect(onboardingStateSource.contains("var manualTLS: Bool {\n            self.manualTLSState.value"))
        #expect(onboardingStateSource.contains("struct Initialization: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct GatewayLinkApplication: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("case initialized(Initialization)"))
        #expect(onboardingStateSource.contains("case gatewayLinkApplied(GatewayLinkApplication)"))
        #expect(initialization.contains("var host: OnboardingManualHost"))
        #expect(initialization.contains("var port: OnboardingManualPort"))
        #expect(initialization.contains("var tls: OnboardingManualTLS"))
        #expect(gatewayLinkApplication.contains("var host: OnboardingManualHost"))
        #expect(gatewayLinkApplication.contains("var port: OnboardingManualPort"))
        #expect(gatewayLinkApplication.contains("var tls: OnboardingManualTLS"))
        #expect(onboardingStateSource.contains("state.manualHostState = initialization.host"))
        #expect(onboardingStateSource.contains("state.manualPortState = initialization.port"))
        #expect(onboardingStateSource.contains("state.manualHostState = application.host"))
        #expect(onboardingStateSource.contains("state.manualPortState = application.port"))
        #expect(onboardingStateSource.contains("state.manualTLSState = initialization.tls"))
        #expect(onboardingStateSource.contains("state.manualTLSState = application.tls"))
        #expect(onboardingStateSource.contains("state.manualTLSState = change.useTLS"))
        #expect(onboardingSource.contains("self.connectionFormStore.send(.initialized(.init("))
        #expect(onboardingSource.contains("self.connectionFormStore.send(.gatewayLinkApplied(.init("))
        #expect(onboardingStateSource.contains("struct ManualConnectionRequest: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct ManualHostChange: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct ManualPortTextChange: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct ManualTLSChange: Equatable, Sendable"))
        #expect(manualConnectionRequest.contains("var host: OnboardingManualHost"))
        #expect(manualConnectionRequest.contains("var port: OnboardingManualPort"))
        #expect(manualConnectionRequest.contains("var useTLS: OnboardingManualTLS"))
        #expect(manualHostChange.contains("var host: OnboardingManualHost"))
        #expect(manualPortTextChange.contains("var text: OnboardingManualPortText"))
        #expect(manualTLSChange.contains("var useTLS: OnboardingManualTLS"))
        #expect(onboardingStateSource.contains("struct ModeSelection: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct SelectedModeChange: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("case manualConnectionRequested"))
        #expect(onboardingStateSource.contains("case manualHostChanged(ManualHostChange)"))
        #expect(onboardingStateSource.contains("case manualPortTextChanged(ManualPortTextChange)"))
        #expect(onboardingStateSource.contains("case manualTLSChanged(ManualTLSChange)"))
        #expect(onboardingStateSource.contains("case modeSelected(ModeSelection)"))
        #expect(onboardingStateSource.contains("case selectedModeChanged(SelectedModeChange)"))
        #expect(onboardingStateSource.contains("state.selectedMode = selection.mode"))
        #expect(onboardingStateSource.contains("state.selectedMode = change.mode"))
        #expect(onboardingStateSource.contains("state.manualConnectionRequest = ManualConnectionRequest("))
        #expect(onboardingStateSource.contains("host: .init(value: host)"))
        #expect(onboardingStateSource.contains("port: state.manualPortState"))
        #expect(onboardingStateSource.contains("useTLS: .init(value: state.manualTLS)"))
        #expect(onboardingSource.contains("self.connectionFormStore.send(.manualConnectionRequested)"))
        #expect(onboardingSource.contains("self.connectionFormStore.send(.manualConnectionRequestHandled)"))
        #expect(onboardingSource.contains("self.connectionFormStore.send(.modeSelected(.init(mode: mode)))"))
        #expect(onboardingSource.contains("self.connectionFormStore.send(.selectedModeChanged(.init(mode:"))
        #expect(onboardingSource.contains("self.connectionFormStore.send(.manualHostChanged(.init(host: .init(value: $0))))"))
        #expect(onboardingSource.contains("self.connectionFormStore.send(.manualPortTextChanged(.init(text: .init(value: $0))))"))
        #expect(onboardingSource.contains("self.connectionFormStore.send(.manualTLSChanged(.init(useTLS: .init(value: $0))))"))
        #expect(onboardingSource.contains("get: { self.connectionFormStore.manualTLS }"))
        #expect(onboardingSource.contains("host: request.host.value"))
        #expect(onboardingSource.contains("port: request.port.value"))
        #expect(onboardingSource.contains("useTLS: request.useTLS.value"))
        #expect(!onboardingStateSource.contains("var manualHost = \"\""))
        #expect(!onboardingStateSource.contains("var manualPort = 18789"))
        #expect(!onboardingStateSource.contains("var manualPortText = \"18789\""))
        #expect(!onboardingStateSource.contains("self.manualHost = \"openclaw.local\""))
        #expect(!onboardingStateSource.contains("self.manualHost = \"localhost\""))
        #expect(!onboardingStateSource.contains("self.manualHost = \"\""))
        #expect(!onboardingStateSource.contains("self.manualPort = 18789"))
        #expect(!onboardingStateSource.contains("self.manualPortText ="))
        #expect(!onboardingStateSource.contains("state.manualHost = initialization.host.value"))
        #expect(!onboardingStateSource.contains("state.manualHost = application.host.value"))
        #expect(!onboardingStateSource.contains("state.manualHost = \"localhost\""))
        #expect(!onboardingStateSource.contains("state.manualHost = change.host.value"))
        #expect(!onboardingStateSource.contains("state.manualPort = initialization.port.value"))
        #expect(!onboardingStateSource.contains("state.manualPort = application.port.value"))
        #expect(!onboardingStateSource.contains("state.manualPort = 0"))
        #expect(!onboardingStateSource.contains("state.manualPort = min(parsed, 65535)"))
        #expect(!onboardingStateSource.contains("state.manualPortText = \"\""))
        #expect(!onboardingStateSource.contains("var manualTLS = true"))
        #expect(!onboardingStateSource.contains("self.manualTLS = true"))
        #expect(!onboardingStateSource.contains("self.manualTLS = false"))
        #expect(!onboardingStateSource.contains("state.manualTLS ="))
        #expect(!manualConnectionRequest.contains("var host: String"))
        #expect(!manualConnectionRequest.contains("var port: Int"))
        #expect(!manualConnectionRequest.contains("var useTLS: Bool"))
        #expect(!manualHostChange.contains("var host: String"))
        #expect(!manualPortTextChange.contains("var text: String"))
        #expect(!manualTLSChange.contains("var useTLS: Bool"))
        #expect(!onboardingSource.contains("self.connectionFormStore.send(.manualHostChanged(.init(host: $0)))"))
        #expect(!onboardingSource.contains("self.connectionFormStore.send(.manualPortTextChanged(.init(text: $0)))"))
        #expect(!onboardingSource.contains("self.connectionFormStore.send(.manualTLSChanged(.init(useTLS: $0)))"))
        #expect(!onboardingSource.contains("let host = self.connectionFormStore.normalizedManualHost"))
        #expect(!onboardingSource.contains("guard !host.isEmpty, self.manualPort > 0, self.manualPort <= 65535"))
    }

    @Test func `onboarding connection start action is typed`() throws {
        let onboardingSource = try String(contentsOf: Self.onboardingWizardSourceURL(), encoding: .utf8)
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)
        let connectionStart = try Self.extract(
            onboardingStateSource,
            from: "struct ConnectionStart",
            to: "struct ConnectionStatusUpdate")
        let connectionActivityStart = try Self.extract(
            onboardingStateSource,
            from: "struct ConnectionActivityStart",
            to: "struct ScannerError")

        #expect(onboardingStateSource.contains("struct OnboardingConnectionID: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct OnboardingConnectionMessage: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct OnboardingConnectionStatusLine: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct OnboardingConnectionClearsIssue: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct ConnectionStart: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct ConnectionActivityStart: Equatable, Sendable"))
        #expect(connectionStart.contains("var id: OnboardingConnectionID"))
        #expect(connectionStart.contains("var message: OnboardingConnectionMessage"))
        #expect(connectionStart.contains("var statusLine: OnboardingConnectionStatusLine"))
        #expect(connectionStart.contains("var clearsIssue: OnboardingConnectionClearsIssue"))
        #expect(connectionActivityStart.contains("var id: OnboardingConnectionID"))
        #expect(onboardingStateSource.contains("case connectionStarted(ConnectionStart)"))
        #expect(onboardingStateSource.contains("case connectionActivityStarted(ConnectionActivityStart)"))
        #expect(onboardingStateSource.contains("state.connectingGatewayID = start.id.value"))
        #expect(onboardingStateSource.contains("state.connectMessage = start.message.value"))
        #expect(onboardingStateSource.contains("state.statusLine = start.statusLine.value"))
        #expect(onboardingStateSource.contains("if start.clearsIssue.value"))
        #expect(onboardingSource.contains("self.statusStore.send(.connectionStarted(.init("))
        #expect(onboardingSource.contains("id: .init(value: connectionID)"))
        #expect(!connectionStart.contains("var id: String"))
        #expect(!connectionStart.contains("var message: String\n"))
        #expect(!connectionStart.contains("var statusLine: String\n"))
        #expect(!connectionStart.contains("var clearsIssue: Bool"))
        #expect(!connectionActivityStart.contains("var id: String"))
        #expect(!onboardingSource.contains("self.statusStore.send(.connectionActivityStarted(.init(id: connectionID)))"))
    }

    @Test func `onboarding connection status action is typed`() throws {
        let onboardingSource = try String(contentsOf: Self.onboardingWizardSourceURL(), encoding: .utf8)
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)
        let connectionStatusUpdate = try Self.extract(
            onboardingStateSource,
            from: "struct ConnectionStatusUpdate",
            to: "struct GatewayConnectionCompletion")

        #expect(onboardingStateSource.contains("struct OnboardingConnectionStatusMessage: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct OnboardingConnectionStatusLine: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct ConnectionStatusUpdate: Equatable, Sendable"))
        #expect(connectionStatusUpdate.contains("var message: OnboardingConnectionStatusMessage"))
        #expect(connectionStatusUpdate.contains("var statusLine: OnboardingConnectionStatusLine"))
        #expect(onboardingStateSource.contains("case connectionStatusUpdated(ConnectionStatusUpdate)"))
        #expect(onboardingStateSource.contains("state.connectMessage = update.message.value"))
        #expect(onboardingStateSource.contains("state.statusLine = update.statusLine.value"))
        #expect(onboardingSource.contains("self.statusStore.send(.connectionStatusUpdated(.init("))
        #expect(onboardingSource.contains("message: .init(value: \"Connecting via QR code...\")"))
        #expect(onboardingSource.contains("statusLine: .init(value: \"QR loaded. Connecting to \\(scannedLink.host):"))
        #expect(!connectionStatusUpdate.contains("var message: String?"))
        #expect(!connectionStatusUpdate.contains("var statusLine: String\n"))
    }

    @Test func `onboarding connection issue action is typed`() throws {
        let onboardingSource = try String(contentsOf: Self.onboardingWizardSourceURL(), encoding: .utf8)
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)
        let connectionIssueDetection = try Self.extract(
            onboardingStateSource,
            from: "struct ConnectionIssueDetection",
            to: "struct ConnectionActivityStart")

        #expect(onboardingStateSource.contains("struct OnboardingConnectionIssueMessage: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct OnboardingConnectionIssueRequestID: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct OnboardingConnectionIssueStatusText: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct OnboardingConnectionPauseReconnect: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct ConnectionIssueDetection: Equatable, Sendable"))
        #expect(connectionIssueDetection.contains("var requestId: OnboardingConnectionIssueRequestID"))
        #expect(connectionIssueDetection.contains("var pauseReconnect: OnboardingConnectionPauseReconnect"))
        #expect(connectionIssueDetection.contains("var message: OnboardingConnectionIssueMessage"))
        #expect(connectionIssueDetection.contains("var statusText: OnboardingConnectionIssueStatusText"))
        #expect(onboardingStateSource.contains("case connectionIssueDetected(ConnectionIssueDetection)"))
        #expect(onboardingStateSource.contains("detected: detection.issue"))
        #expect(onboardingStateSource.contains("detection.pauseReconnect.value"))
        #expect(onboardingStateSource.contains("detection.statusText.value.trimmingCharacters"))
        #expect(onboardingSource.contains("self.statusStore.send(.connectionIssueDetected(.init("))
        #expect(onboardingSource.contains("requestId: .init(value: problem?.requestId ?? fallback.requestId)"))
        #expect(onboardingSource.contains("pauseReconnect: .init(value: problem?.pauseReconnect == true)"))
        #expect(onboardingSource.contains("message: .init(value: problem?.message)"))
        #expect(onboardingSource.contains("statusText: .init(value: statusText)"))
        #expect(!connectionIssueDetection.contains("var requestId: String?"))
        #expect(!connectionIssueDetection.contains("var pauseReconnect: Bool"))
        #expect(!connectionIssueDetection.contains("var message: String?"))
        #expect(!connectionIssueDetection.contains("var statusText: String"))
    }

    @Test func `settings onboarding reset is reducer effect owned`() throws {
        let settingsSource = try Self.settingsProTabCombinedSource()
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let supportSource = try String(contentsOf: Self.settingsProTabSupportSourceURL(), encoding: .utf8)
        let resetFunction = try Self.extract(
            actionsSource,
            from: "func resetOnboarding() async",
            to: "func retryGatewayConnectionFromProblem()")

        #expect(supportSource.contains("struct SettingsOnboardingRequestID: Equatable, Sendable { var value: Int }"))
        #expect(settingsSource.contains("struct OnboardingRequestIDChange: Equatable, Sendable"))
        #expect(settingsSource.contains("var requestID: SettingsOnboardingRequestID"))
        #expect(settingsSource.contains(
            "struct OnboardingResetRequest: Equatable, Sendable { var instanceId: SettingsGatewayCurrentInstanceID }"))
        #expect(settingsSource.contains("struct SettingsOnboardingHasConnectedOnce: Equatable, Sendable"))
        #expect(settingsSource.contains("struct SettingsOnboardingComplete: Equatable, Sendable"))
        #expect(settingsSource.contains("struct OnboardingStateSync: Equatable, Sendable"))
        #expect(settingsSource.contains("var hasConnectedOnce: SettingsOnboardingHasConnectedOnce"))
        #expect(settingsSource.contains("var onboardingComplete: SettingsOnboardingComplete"))
        #expect(settingsSource.contains("var onboardingRequestID: SettingsOnboardingRequestID"))
        #expect(settingsSource.contains("var hasConnectedOnceState = Action.SettingsOnboardingHasConnectedOnce(value: false)"))
        #expect(settingsSource.contains("var onboardingCompletion = Action.SettingsOnboardingComplete(value: false)"))
        #expect(settingsSource.contains("var requestID = SettingsOnboardingRequestID(value: 0)"))
        #expect(settingsSource.contains("var hasConnectedOnce: Bool"))
        #expect(settingsSource.contains("var onboardingComplete: Bool"))
        #expect(settingsSource.contains("var onboardingRequestID: Int"))
        #expect(settingsSource.contains("self.hasConnectedOnceState.value"))
        #expect(settingsSource.contains("self.onboardingCompletion.value"))
        #expect(settingsSource.contains("self.requestID.value"))
        #expect(settingsSource.contains("case onboardingRequestIDChanged(OnboardingRequestIDChange)"))
        #expect(settingsSource.contains("case onboardingResetRequested(OnboardingResetRequest)"))
        #expect(settingsSource.contains("case onboardingStateSynced(OnboardingStateSync)"))
        #expect(settingsSource.contains("@Dependency(\\.settingsOnboardingReset)"))
        #expect(settingsSource.contains("state.requestID = change.requestID"))
        #expect(settingsSource.contains("state.hasConnectedOnceState = sync.hasConnectedOnce"))
        #expect(settingsSource.contains("state.onboardingCompletion = sync.onboardingComplete"))
        #expect(settingsSource.contains("state.requestID = sync.onboardingRequestID"))
        #expect(settingsSource.contains("state.requestID = .init(value: state.requestID.value + 1)"))
        #expect(settingsSource.contains("await resetClient.reset(request.instanceId)"))
        #expect(!settingsSource.contains("struct OnboardingRequestIDChange: Equatable, Sendable { var requestID: Int }"))
        #expect(!settingsSource.contains("var hasConnectedOnce = false"))
        #expect(!settingsSource.contains("var onboardingComplete = false"))
        #expect(!settingsSource.contains("var onboardingRequestID = 0"))
        #expect(!settingsSource.contains("var hasConnectedOnce: Bool\n            var onboardingComplete: Bool"))
        #expect(!settingsSource.contains("state.hasConnectedOnce = false"))
        #expect(!settingsSource.contains("state.onboardingComplete = false"))
        #expect(!settingsSource.contains("state.onboardingRequestID += 1"))
        #expect(!settingsSource.contains("state.onboardingRequestID = change.requestID.value"))
        #expect(!settingsSource.contains("state.hasConnectedOnce = sync.hasConnectedOnce.value"))
        #expect(!settingsSource.contains("state.onboardingComplete = sync.onboardingComplete.value"))
        #expect(!settingsSource.contains("state.onboardingRequestID = sync.onboardingRequestID.value"))
        #expect(!settingsSource.contains("state.hasConnectedOnce = sync.hasConnectedOnce\n"))
        #expect(!settingsSource.contains("state.onboardingRequestID = sync.onboardingRequestID\n"))
        #expect(actionsSource.contains("hasConnectedOnce: .init(value: self.storedHasConnectedOnce)"))
        #expect(actionsSource.contains("onboardingComplete: .init(value: self.storedOnboardingComplete)"))
        #expect(actionsSource.contains("onboardingRequestID: .init(value: self.storedOnboardingRequestID)"))
        #expect(supportSource.contains("struct SettingsOnboardingResetClient"))
        #expect(supportSource.contains(
            "var reset: @MainActor @Sendable (_ instanceId: SettingsGatewayCurrentInstanceID) -> Void"))
        #expect(supportSource.contains("GatewayOnboardingReset.reset(appModel: appModel, instanceId: instanceId.value)"))
        #expect(rootSource.contains("self.makeSettingsOnboardingStateStore()"))
        #expect(storesSource.contains("SettingsOnboardingStateFeature(resetClient: .live(appModel: self.appModel))"))
        #expect(resetFunction.contains(".send(.onboardingResetRequested(.init("))
        #expect(resetFunction.contains("instanceId: .init(value: self.instanceId)"))
        #expect(actionsSource.contains(".finish()"))
        #expect(actionsSource.contains("self.syncStoredOnboardingResetState()"))
        #expect(settingsSource.contains("Task { await self.resetOnboarding() }"))
        #expect(actionsSource.contains("await self.resetOnboarding()"))
        #expect(!resetFunction.contains("GatewayOnboardingReset.reset"))
        #expect(!actionsSource.contains("self.onboardingStateStore.send(.onboardingRequestAdvanced)"))
        #expect(!actionsSource.contains("self.onboardingStateStore.send(.completionStateReset)"))
        #expect(!actionsSource.contains("self.storedOnboardingRequestID += 1"))
        #expect(!actionsSource.contains("self.onboardingStateStore.send(.onboardingRequestIDChanged("))
    }

    @Test func `settings talk toggle apple review decision is reducer owned`() throws {
        let settingsSource = try Self.settingsProTabCombinedSource()
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let voiceControlFeature = try Self.extract(
            settingsSource,
            from: "struct SettingsVoiceControlFeature",
            to: "struct SettingsProTab: View")
        let oldTalkToggleGuard = "func updateTalkEnabled(_ enabled: Bool) {\n"
            + "        guard !self.appModel.isAppleReviewDemoModeEnabled else"

        #expect(settingsSource.contains("struct TalkEnabledChangeRequest: Equatable, Sendable"))
        #expect(settingsSource.contains("case talkEnabledChangeRequested(TalkEnabledChangeRequest)"))
        #expect(settingsSource.contains(
            "struct SettingsVoiceControlDemoModeEnabled: Equatable, Sendable { var value: Bool }"))
        #expect(settingsSource.contains(
            "var isAppleReviewDemoModeEnabled: SettingsVoiceControlDemoModeEnabled"))
        #expect(settingsSource.contains("let requested = request.enabled"))
        #expect(settingsSource.contains("let talkEnabled ="))
        #expect(settingsSource.contains("if request.isAppleReviewDemoModeEnabled.value"))
        #expect(settingsSource.contains("Action.SettingsTalkEnabled(isEnabled: false)"))
        #expect(settingsSource.contains("state.talkEnabled = talkEnabled"))
        #expect(settingsSource.contains("await voiceControlClient.setTalkEnabled(talkEnabled.isEnabled)"))
        #expect(actionsSource.contains("self.voiceControlStore.send(.talkEnabledChangeRequested(.init("))
        #expect(actionsSource.contains("enabled: .init(isEnabled: enabled)"))
        #expect(actionsSource.contains(
            "isAppleReviewDemoModeEnabled: .init(value: self.appModel.isAppleReviewDemoModeEnabled)"))
        #expect(actionsSource.contains("self.storedTalkEnabled = self.voiceControlStore.talkEnabled.isEnabled"))
        #expect(!settingsSource.contains("request.isAppleReviewDemoModeEnabled ? false : request.enabled"))
        #expect(!voiceControlFeature.contains("var isAppleReviewDemoModeEnabled: Bool"))
        #expect(actionsSource.contains(oldTalkToggleGuard) == false)
    }

    @Test func `settings appearance preference picker change is typed`() throws {
        let settingsSource = try Self.settingsProTabCombinedSource()
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let supportSource = try String(contentsOf: Self.settingsProTabSupportSourceURL(), encoding: .utf8)

        #expect(settingsSource.contains("struct SettingsAppearanceFeature"))
        #expect(settingsSource
            .contains("struct AppearancePreferenceChange: Equatable, Sendable { var preference: AppAppearancePreference }"))
        #expect(supportSource.contains(
            "struct SettingsAppearancePreferenceRawValue: Equatable, Sendable { var value: String }"))
        #expect(settingsSource.contains(
            "struct AppearancePreferenceSync: Equatable, Sendable { var rawValue: SettingsAppearancePreferenceRawValue }"))
        #expect(settingsSource.contains("var appearancePreferenceValue = SettingsAppearancePreferenceRawValue("))
        #expect(settingsSource.contains("value: AppAppearancePreference.system.rawValue)"))
        #expect(settingsSource.contains("var appearancePreferenceRaw: String"))
        #expect(settingsSource.contains("self.appearancePreferenceValue.value"))
        #expect(settingsSource.contains("state.appearancePreferenceValue = .init(value: change.preference.rawValue)"))
        #expect(settingsSource.contains("state.appearancePreferenceValue = sync.rawValue"))
        #expect(actionsSource.contains("guard let preference = AppAppearancePreference(rawValue: rawValue) else { return }"))
        #expect(actionsSource.contains("self.appearanceStore.send(.appearancePreferenceChanged(.init(preference: preference)))"))
        #expect(actionsSource.contains("rawValue: .init(value: self.storedAppearancePreferenceRaw)"))
        #expect(settingsSource.contains(
            "self.appearanceStore.send(.appearancePreferenceSynced(.init(rawValue: .init(value: newValue))))"))
        #expect(actionsSource.contains("self.storedAppearancePreferenceRaw = preference.rawValue"))
        #expect(!settingsSource.contains("var appearancePreferenceRaw = AppAppearancePreference.system.rawValue"))
        #expect(!settingsSource.contains("state.appearancePreferenceRaw = change.preference.rawValue"))
        #expect(!settingsSource.contains("state.appearancePreferenceRaw = sync.rawValue.value"))
        #expect(!settingsSource.contains("struct AppearancePreferenceSync: Equatable, Sendable { var rawValue: String }"))
        #expect(!actionsSource.contains(
            "self.appearanceStore.send(.appearancePreferenceSynced(.init(rawValue: self.storedAppearancePreferenceRaw)))"))
    }

    @Test func `settings device display name change is typed`() throws {
        let settingsSource = try Self.settingsProTabCombinedSource()
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let supportSource = try String(contentsOf: Self.settingsProTabSupportSourceURL(), encoding: .utf8)

        #expect(supportSource.contains("struct SettingsGatewayCurrentInstanceID: Equatable, Sendable"))
        #expect(supportSource.contains("struct SettingsDeviceDisplayName: Equatable, Sendable { var value: String }"))
        #expect(settingsSource.contains("struct DisplayNameChange: Equatable, Sendable"))
        #expect(settingsSource.contains("var displayName: SettingsDeviceDisplayName"))
        #expect(settingsSource.contains("var deviceDisplayName = SettingsDeviceDisplayName(value: \"iOS Node\")"))
        #expect(settingsSource.contains("var currentInstanceID = SettingsGatewayCurrentInstanceID(value: \"\")"))
        #expect(settingsSource.contains("var displayName: String"))
        #expect(settingsSource.contains("var instanceId: String"))
        #expect(settingsSource.contains("self.deviceDisplayName.value"))
        #expect(settingsSource.contains("self.currentInstanceID.value"))
        #expect(settingsSource.contains("state.deviceDisplayName = change.displayName"))
        #expect(settingsSource.contains("struct DisplayNameSync: Equatable, Sendable"))
        #expect(settingsSource.contains("var displayName: SettingsDeviceDisplayName"))
        #expect(settingsSource.contains("struct InstanceIDSync: Equatable, Sendable"))
        #expect(settingsSource.contains("var instanceId: SettingsGatewayCurrentInstanceID"))
        #expect(settingsSource.contains("state.deviceDisplayName = sync.displayName"))
        #expect(settingsSource.contains("state.currentInstanceID = sync.instanceId"))
        #expect(actionsSource.contains(
            "self.deviceIdentityStore.send(.displayNameChanged(.init(displayName: .init(value: displayName))))"))
        #expect(actionsSource.contains(
            "self.deviceIdentityStore.send(.displayNameSynced(.init(displayName: .init(value: self.storedDisplayName))))"))
        #expect(actionsSource.contains(
            "self.deviceIdentityStore.send(.instanceIdSynced(.init(instanceId: .init(value: self.storedInstanceId))))"))
        #expect(settingsSource.contains(
            "self.deviceIdentityStore.send(.displayNameSynced(.init(displayName: .init(value: newValue))))"))
        #expect(settingsSource.contains(
            "self.deviceIdentityStore.send(.instanceIdSynced(.init(instanceId: .init(value: newValue))))"))
        #expect(!settingsSource.contains("struct DisplayNameChange: Equatable, Sendable { var displayName: String }"))
        #expect(!settingsSource.contains("struct DisplayNameSync: Equatable, Sendable { var displayName: String }"))
        #expect(!settingsSource.contains("struct InstanceIDSync: Equatable, Sendable { var instanceId: String }"))
        #expect(!settingsSource.contains("var displayName = \"iOS Node\""))
        #expect(!settingsSource.contains("var instanceId = \"\""))
        #expect(!settingsSource.contains("state.displayName = change.displayName.value"))
        #expect(!settingsSource.contains("state.displayName = sync.displayName.value"))
        #expect(!settingsSource.contains("state.instanceId = sync.instanceId.value"))
        #expect(!actionsSource.contains(".displayNameChanged(.init(displayName: displayName))"))
        #expect(!settingsSource.contains(".displayNameSynced(.init(displayName: newValue))"))
        #expect(!settingsSource.contains(".instanceIdSynced(.init(instanceId: newValue))"))
    }

    @Test func `settings voice control persistence is reducer effect owned`() throws {
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let settingsSource = try Self.settingsProTabCombinedSource()
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let updateTalkFunction = try Self.extract(
            actionsSource,
            from: "func updateTalkEnabled(_ enabled: Bool)",
            to: "func updateVoiceWakeEnabled(_ enabled: Bool)")
        let updateVoiceWakeFunction = try Self.extract(
            actionsSource,
            from: "func updateVoiceWakeEnabled(_ enabled: Bool)",
            to: "var appearancePreferenceBinding")

        #expect(settingsSource.contains("struct SettingsVoiceControlClient: Sendable"))
        #expect(settingsSource.contains("var settingsVoiceControl: SettingsVoiceControlClient"))
        #expect(settingsSource.contains("struct SettingsTalkEnabled: Equatable, Sendable"))
        #expect(settingsSource.contains(
            "struct SettingsVoiceControlDemoModeEnabled: Equatable, Sendable { var value: Bool }"))
        #expect(settingsSource.contains("struct TalkEnabledChange: Equatable, Sendable"))
        #expect(settingsSource.contains("var enabled: SettingsTalkEnabled"))
        #expect(settingsSource.contains("var isAppleReviewDemoModeEnabled: SettingsVoiceControlDemoModeEnabled"))
        #expect(settingsSource.contains("struct VoiceControlSync: Equatable, Sendable"))
        #expect(settingsSource.contains("struct SettingsVoiceWakeEnabled: Equatable, Sendable"))
        #expect(settingsSource.contains("struct SettingsVoiceWakeStatusText: Equatable, Sendable"))
        #expect(settingsSource.contains("var talkEnabled = Action.SettingsTalkEnabled(isEnabled: false)"))
        #expect(settingsSource.contains("var voiceWakeEnabled = Action.SettingsVoiceWakeEnabled(isEnabled: false)"))
        #expect(settingsSource.contains("var voiceWakeStatusText = Action.SettingsVoiceWakeStatusText(value: \"Off\")"))
        #expect(settingsSource.contains("var talkEnabled: SettingsTalkEnabled"))
        #expect(settingsSource.contains("var voiceWakeEnabled: SettingsVoiceWakeEnabled"))
        #expect(settingsSource.contains("var voiceWakeStatusText: SettingsVoiceWakeStatusText"))
        #expect(settingsSource.contains("state.talkEnabled = sync.talkEnabled"))
        #expect(settingsSource.contains("state.voiceWakeEnabled = sync.voiceWakeEnabled"))
        #expect(settingsSource.contains("state.voiceWakeStatusText = sync.voiceWakeStatusText"))
        #expect(settingsSource.contains("struct VoiceWakeEnabledChange: Equatable, Sendable"))
        #expect(settingsSource.contains("var enabled: SettingsVoiceWakeEnabled"))
        #expect(settingsSource.contains("case controlsSynced(VoiceControlSync)"))
        #expect(settingsSource.contains("case talkEnabledChanged(TalkEnabledChange)"))
        #expect(settingsSource.contains("case voiceWakeEnabledChanged(VoiceWakeEnabledChange)"))
        #expect(settingsSource.contains("@Dependency(\\.settingsVoiceControl)"))
        #expect(settingsSource.contains("await voiceControlClient.setTalkEnabled(talkEnabled.isEnabled)"))
        #expect(settingsSource.contains("await voiceControlClient.setVoiceWakeEnabled(enabled.isEnabled)"))
        #expect(rootSource.contains("voiceControlStore: self.makeSettingsVoiceControlStore()"))
        #expect(storesSource.contains("func makeSettingsVoiceControlStore()"))
        #expect(storesSource.contains("voiceControlClient: .live(appModel: self.appModel)"))
        #expect(actionsSource.contains("talkEnabled: .init(isEnabled: self.storedTalkEnabled)"))
        #expect(actionsSource.contains("voiceWakeEnabled: .init(isEnabled: self.storedVoiceWakeEnabled)"))
        #expect(actionsSource.contains("voiceWakeStatusText: .init(value: self.appModel.voiceWake.statusText)"))
        #expect(updateTalkFunction.contains("self.voiceControlStore.send(.talkEnabledChangeRequested(.init("))
        #expect(updateTalkFunction.contains("enabled: .init(isEnabled: enabled)"))
        #expect(updateTalkFunction.contains(
            "isAppleReviewDemoModeEnabled: .init(value: self.appModel.isAppleReviewDemoModeEnabled)"))
        #expect(updateTalkFunction.contains("self.storedTalkEnabled = self.voiceControlStore.talkEnabled.isEnabled"))
        #expect(actionsSource.contains("self.voiceControlStore.talkEnabled.isEnabled"))
        #expect(actionsSource.contains("self.voiceControlStore.voiceWakeEnabled.isEnabled"))
        #expect(actionsSource.contains("self.voiceControlStore.voiceWakeStatusText.value"))
        #expect(!updateTalkFunction.contains("self.appModel.setTalkEnabled"))
        #expect(updateVoiceWakeFunction.contains("enabled: .init(isEnabled: enabled)"))
        #expect(updateVoiceWakeFunction.contains("self.storedVoiceWakeEnabled = enabled"))
        #expect(!updateVoiceWakeFunction.contains("self.appModel.setVoiceWakeEnabled"))
        #expect(!settingsSource.contains("var talkEnabled = false"))
        #expect(!settingsSource.contains("var voiceWakeEnabled = false"))
        #expect(!settingsSource.contains("var voiceWakeStatusText = \"Off\""))
        #expect(!settingsSource.contains("state.talkEnabled = sync.talkEnabled.isEnabled"))
        #expect(!settingsSource.contains("state.voiceWakeEnabled = sync.voiceWakeEnabled.isEnabled"))
        #expect(!settingsSource.contains("state.voiceWakeStatusText = sync.voiceWakeStatusText.value"))
        #expect(!settingsSource.contains("state.talkEnabled = change.enabled.isEnabled"))
        #expect(!settingsSource.contains("state.voiceWakeEnabled = enabled.isEnabled"))
        #expect(!settingsSource.contains("var talkEnabled: Bool\n            var voiceWakeEnabled: Bool"))
        #expect(!settingsSource.contains("setVoiceWakeEnabled(change.enabled)"))
        #expect(!actionsSource.contains("voiceWakeEnabledChanged(.init(enabled: enabled))"))
    }

    @Test func `settings talk preference persistence is reducer effect owned`() throws {
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let settingsSource = try Self.settingsProTabCombinedSource()
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let preferencesSource = try String(contentsOf: Self.settingsTalkPreferencesFeatureSourceURL(), encoding: .utf8)
        let updateProviderFunction = try Self.extract(
            actionsSource,
            from: "func updateTalkProviderSelection(_ rawValue: String)",
            to: "func updateTalkRealtimeVoiceSelection(_ rawValue: String)")
        let updateRealtimeVoiceFunction = try Self.extract(
            actionsSource,
            from: "func updateTalkRealtimeVoiceSelection(_ rawValue: String)",
            to: "func updateTalkSpeechLocale(_ speechLocale: String)")
        let updateBackgroundFunction = try Self.extract(
            actionsSource,
            from: "func updateTalkBackgroundEnabled(_ enabled: Bool)",
            to: "func updateTalkButtonEnabled(_ enabled: Bool)")
        let updateButtonFunction = try Self.extract(
            actionsSource,
            from: "func updateTalkButtonEnabled(_ enabled: Bool)",
            to: "func updateTalkSpeakerphoneEnabled(_ enabled: Bool)")
        let updateSpeakerphoneFunction = try Self.extract(
            actionsSource,
            from: "func updateTalkSpeakerphoneEnabled(_ enabled: Bool)",
            to: "var talkApiKeyStatus")

        #expect(preferencesSource.contains("struct SettingsTalkPreferencesClient: Sendable"))
        #expect(preferencesSource.contains("setProviderSelection: @MainActor @Sendable (TalkModeProviderSelection) -> Void"))
        #expect(preferencesSource.contains("struct SettingsTalkRealtimeVoiceSelection: Equatable, Sendable"))
        #expect(preferencesSource
            .contains("setRealtimeVoiceSelection: @MainActor @Sendable (SettingsTalkRealtimeVoiceSelection) -> Void"))
        #expect(preferencesSource.contains("var settingsTalkPreferences: SettingsTalkPreferencesClient"))
        #expect(preferencesSource.contains("@Dependency(\\.settingsTalkPreferences)"))
        #expect(preferencesSource.contains("struct ProviderSelectionChange: Equatable, Sendable"))
        #expect(preferencesSource.contains("var selection: TalkModeProviderSelection"))
        #expect(preferencesSource.contains("struct RealtimeVoiceSelectionChange: Equatable, Sendable"))
        #expect(preferencesSource.contains("var voice: SettingsTalkRealtimeVoiceSelection"))
        #expect(preferencesSource.contains("struct SettingsTalkSpeechLocale: Equatable, Sendable"))
        #expect(preferencesSource.contains("var locale: SettingsTalkSpeechLocale"))
        #expect(preferencesSource.contains("struct SettingsTalkBackgroundEnabled: Equatable, Sendable"))
        #expect(preferencesSource.contains("struct SettingsTalkButtonEnabled: Equatable, Sendable"))
        #expect(preferencesSource.contains("struct SettingsTalkSpeakerphoneEnabled: Equatable, Sendable"))
        #expect(preferencesSource.contains("struct SettingsGatewayTalkConfigLoaded: Equatable, Sendable"))
        #expect(preferencesSource.contains("struct SettingsGatewayTalkApiKeyConfigured: Equatable, Sendable"))
        #expect(preferencesSource.contains("struct SettingsGatewayTalkUsesRealtime: Equatable, Sendable"))
        #expect(preferencesSource
            .contains("struct SettingsGatewayTalkAppleReviewDemoModeEnabled: Equatable, Sendable"))
        #expect(preferencesSource.contains("struct SettingsGatewayTalkTransportLabel: Equatable, Sendable"))
        #expect(preferencesSource.contains("struct SettingsGatewayTalkActiveModeTitle: Equatable, Sendable"))
        #expect(preferencesSource.contains("struct SettingsGatewayTalkActiveModeSubtitle: Equatable, Sendable"))
        #expect(preferencesSource.contains("struct SettingsGatewayTalkLastIssueText: Equatable, Sendable"))
        #expect(preferencesSource
            .contains("setSpeakerphoneEnabled: @MainActor @Sendable (SettingsTalkSpeakerphoneEnabled) -> Void"))
        #expect(preferencesSource.contains("struct TalkBackgroundEnabledChange: Equatable, Sendable"))
        #expect(preferencesSource.contains("var enabled: SettingsTalkBackgroundEnabled"))
        #expect(preferencesSource.contains("struct TalkButtonEnabledChange: Equatable, Sendable"))
        #expect(preferencesSource.contains("var enabled: SettingsTalkButtonEnabled"))
        #expect(preferencesSource.contains("struct TalkSpeakerphoneEnabledChange: Equatable, Sendable"))
        #expect(preferencesSource.contains("var enabled: SettingsTalkSpeakerphoneEnabled"))
        #expect(preferencesSource.contains("struct GatewayTalkConfigSync: Equatable, Sendable"))
        #expect(preferencesSource.contains("var configLoaded: SettingsGatewayTalkConfigLoaded"))
        #expect(preferencesSource.contains("var apiKeyConfigured: SettingsGatewayTalkApiKeyConfigured"))
        #expect(preferencesSource.contains("var usesRealtime: SettingsGatewayTalkUsesRealtime"))
        #expect(preferencesSource.contains("var gatewayTalkConfigLoaded = SettingsGatewayTalkConfigLoaded(value: false)"))
        #expect(preferencesSource
            .contains("var gatewayTalkApiKeyConfigured = SettingsGatewayTalkApiKeyConfigured(value: false)"))
        #expect(preferencesSource.contains("var gatewayTalkUsesRealtime = SettingsGatewayTalkUsesRealtime(value: false)"))
        #expect(preferencesSource.contains("state.gatewayTalkConfigLoaded = sync.configLoaded"))
        #expect(preferencesSource.contains("state.gatewayTalkApiKeyConfigured = sync.apiKeyConfigured"))
        #expect(preferencesSource.contains("state.gatewayTalkUsesRealtime = sync.usesRealtime"))
        #expect(!preferencesSource.contains("var gatewayTalkConfigLoaded = false"))
        #expect(!preferencesSource.contains("var gatewayTalkApiKeyConfigured = false"))
        #expect(!preferencesSource.contains("var gatewayTalkUsesRealtime = false"))
        #expect(!preferencesSource.contains("state.gatewayTalkConfigLoaded = sync.configLoaded.value"))
        #expect(!preferencesSource.contains("state.gatewayTalkApiKeyConfigured = sync.apiKeyConfigured.value"))
        #expect(!preferencesSource.contains("state.gatewayTalkUsesRealtime = sync.usesRealtime.value"))
        #expect(preferencesSource.contains("struct GatewayTalkDisplayContextSync: Equatable, Sendable"))
        #expect(preferencesSource
            .contains("var isAppleReviewDemoModeEnabled: SettingsGatewayTalkAppleReviewDemoModeEnabled"))
        #expect(preferencesSource.contains("var transportLabel: SettingsGatewayTalkTransportLabel"))
        #expect(preferencesSource
            .contains("var isAppleReviewDemoModeEnabled = SettingsGatewayTalkAppleReviewDemoModeEnabled(value: false)"))
        #expect(preferencesSource
            .contains("state.isAppleReviewDemoModeEnabled = sync.isAppleReviewDemoModeEnabled"))
        #expect(!preferencesSource.contains("var isAppleReviewDemoModeEnabled = false"))
        #expect(!preferencesSource
            .contains("state.isAppleReviewDemoModeEnabled = sync.isAppleReviewDemoModeEnabled.value"))
        #expect(preferencesSource
            .contains("var gatewayTalkTransportLabel = SettingsGatewayTalkTransportLabel(value: \"Not loaded\")"))
        #expect(preferencesSource.contains("state.gatewayTalkTransportLabel = sync.transportLabel"))
        #expect(preferencesSource.contains("struct GatewayTalkRuntimeSync: Equatable, Sendable"))
        #expect(preferencesSource.contains("var activeModeTitle: SettingsGatewayTalkActiveModeTitle"))
        #expect(preferencesSource.contains("var activeModeSubtitle: SettingsGatewayTalkActiveModeSubtitle"))
        #expect(preferencesSource.contains("var lastIssueText: SettingsGatewayTalkLastIssueText"))
        #expect(preferencesSource
            .contains("var gatewayTalkActiveModeTitle = SettingsGatewayTalkActiveModeTitle(value: \"Not active\")"))
        #expect(preferencesSource
            .contains("var gatewayTalkActiveModeSubtitle = SettingsGatewayTalkActiveModeSubtitle(value: nil)"))
        #expect(preferencesSource
            .contains("var gatewayTalkLastIssueText = SettingsGatewayTalkLastIssueText(value: nil)"))
        #expect(preferencesSource.contains("state.gatewayTalkActiveModeTitle = sync.activeModeTitle"))
        #expect(preferencesSource.contains("state.gatewayTalkActiveModeSubtitle = sync.activeModeSubtitle"))
        #expect(preferencesSource.contains("state.gatewayTalkLastIssueText = sync.lastIssueText"))
        #expect(!preferencesSource.contains("var gatewayTalkTransportLabel = \"Not loaded\""))
        #expect(!preferencesSource.contains("var gatewayTalkActiveModeTitle = \"Not active\""))
        #expect(!preferencesSource.contains("var gatewayTalkActiveModeSubtitle: String?"))
        #expect(!preferencesSource.contains("var gatewayTalkLastIssueText: String?"))
        #expect(!preferencesSource.contains("state.gatewayTalkTransportLabel = sync.transportLabel.value"))
        #expect(!preferencesSource.contains("state.gatewayTalkActiveModeTitle = sync.activeModeTitle.value"))
        #expect(!preferencesSource.contains("state.gatewayTalkActiveModeSubtitle = sync.activeModeSubtitle.value"))
        #expect(!preferencesSource.contains("state.gatewayTalkLastIssueText = sync.lastIssueText.value"))
        #expect(preferencesSource.contains("struct PreferencesSync: Equatable, Sendable"))
        #expect(preferencesSource.contains("var providerSelection = TalkModeProviderSelection.gatewayDefault"))
        #expect(preferencesSource.contains("var providerSelection: TalkModeProviderSelection"))
        #expect(preferencesSource.contains("var realtimeVoiceSelection: SettingsTalkRealtimeVoiceSelection"))
        #expect(preferencesSource.contains("var speechLocale: SettingsTalkSpeechLocale"))
        #expect(preferencesSource.contains("var talkButtonEnabled: SettingsTalkButtonEnabled"))
        #expect(preferencesSource.contains("var talkBackgroundEnabled: SettingsTalkBackgroundEnabled"))
        #expect(preferencesSource.contains("var talkSpeakerphoneEnabled: SettingsTalkSpeakerphoneEnabled"))
        #expect(preferencesSource.contains("var talkButtonEnabled = SettingsTalkButtonEnabled(isEnabled: true)"))
        #expect(preferencesSource.contains("var talkBackgroundEnabled = SettingsTalkBackgroundEnabled(isEnabled: false)"))
        #expect(preferencesSource.contains("var talkSpeakerphoneEnabled = SettingsTalkSpeakerphoneEnabled("))
        #expect(preferencesSource.contains("state.talkButtonEnabled = sync.talkButtonEnabled"))
        #expect(preferencesSource.contains("state.talkBackgroundEnabled = sync.talkBackgroundEnabled"))
        #expect(preferencesSource.contains("state.talkSpeakerphoneEnabled = sync.talkSpeakerphoneEnabled"))
        #expect(preferencesSource.contains("state.talkButtonEnabled = change.enabled"))
        #expect(preferencesSource.contains("state.talkBackgroundEnabled = change.enabled"))
        #expect(preferencesSource.contains("state.talkSpeakerphoneEnabled = enabled"))
        #expect(actionsSource.contains("self.talkPreferencesStore.talkButtonEnabled.isEnabled"))
        #expect(actionsSource.contains("self.talkPreferencesStore.talkBackgroundEnabled.isEnabled"))
        #expect(actionsSource.contains("self.talkPreferencesStore.talkSpeakerphoneEnabled.isEnabled"))
        #expect(!preferencesSource.contains("var talkButtonEnabled = true"))
        #expect(!preferencesSource.contains("var talkBackgroundEnabled = false"))
        #expect(!preferencesSource.contains("var talkSpeakerphoneEnabled = TalkDefaults.speakerphoneEnabledByDefault"))
        #expect(!preferencesSource.contains("state.talkButtonEnabled = sync.talkButtonEnabled.isEnabled"))
        #expect(!preferencesSource.contains("state.talkBackgroundEnabled = sync.talkBackgroundEnabled.isEnabled"))
        #expect(!preferencesSource.contains("state.talkSpeakerphoneEnabled = sync.talkSpeakerphoneEnabled.isEnabled"))
        #expect(preferencesSource.contains("state.providerSelection = sync.providerSelection"))
        #expect(preferencesSource.contains("state.providerSelection = selection"))
        #expect(actionsSource.contains("self.talkPreferencesStore.providerSelection.rawValue"))
        #expect(!preferencesSource.contains("var providerSelectionRaw = TalkModeProviderSelection.gatewayDefault.rawValue"))
        #expect(!preferencesSource.contains("state.providerSelectionRaw = sync.providerSelection.rawValue"))
        #expect(!preferencesSource.contains("state.providerSelectionRaw = selection.rawValue"))
        #expect(!actionsSource.contains("self.talkPreferencesStore.providerSelectionRaw"))
        #expect(!preferencesSource.contains("TalkModeProviderSelection.resolved(self.providerSelectionRaw)"))
        #expect(!preferencesSource.contains("providerSelectionRaw: String"))
        #expect(preferencesSource.contains("var realtimeVoiceSelection = SettingsTalkRealtimeVoiceSelection(rawValue: nil)"))
        #expect(preferencesSource.contains("var speechLocale = SettingsTalkSpeechLocale(value: TalkSpeechLocale.automaticID)"))
        #expect(preferencesSource.contains("state.realtimeVoiceSelection = sync.realtimeVoiceSelection"))
        #expect(preferencesSource.contains("state.speechLocale = sync.speechLocale"))
        #expect(preferencesSource.contains("state.realtimeVoiceSelection = voice"))
        #expect(preferencesSource.contains("state.speechLocale = change.locale"))
        #expect(actionsSource.contains("self.talkPreferencesStore.realtimeVoiceSelection.value"))
        #expect(actionsSource.contains("self.talkPreferencesStore.speechLocale.value"))
        #expect(!preferencesSource.contains("var realtimeVoiceSelectionRaw = \"\""))
        #expect(!preferencesSource.contains("var speechLocale = TalkSpeechLocale.automaticID"))
        #expect(!preferencesSource.contains("state.realtimeVoiceSelectionRaw = sync.realtimeVoiceSelection.value"))
        #expect(!preferencesSource.contains("state.speechLocale = sync.speechLocale.value"))
        #expect(!preferencesSource.contains("state.realtimeVoiceSelectionRaw = voice.value"))
        #expect(!preferencesSource.contains("state.speechLocale = change.locale.value"))
        #expect(!actionsSource.contains("self.talkPreferencesStore.realtimeVoiceSelectionRaw"))
        #expect(!actionsSource.contains("get: { self.talkPreferencesStore.speechLocale }"))
        #expect(preferencesSource.contains("case gatewayTalkConfigSynced(GatewayTalkConfigSync)"))
        #expect(preferencesSource.contains("case gatewayTalkDisplayContextSynced(GatewayTalkDisplayContextSync)"))
        #expect(preferencesSource.contains("case gatewayTalkRuntimeSynced(GatewayTalkRuntimeSync)"))
        #expect(preferencesSource.contains("case preferencesSynced(PreferencesSync)"))
        #expect(preferencesSource.contains("await preferencesClient.setProviderSelection(selection)"))
        #expect(preferencesSource.contains("await preferencesClient.setRealtimeVoiceSelection(voice)"))
        #expect(preferencesSource.contains("await preferencesClient.setSpeakerphoneEnabled(enabled)"))
        #expect(settingsSource.contains("@State var talkPreferencesStore: StoreOf<SettingsTalkPreferencesFeature>"))
        #expect(rootSource.contains("talkPreferencesStore: self.makeSettingsTalkPreferencesStore()"))
        #expect(storesSource.contains("func makeSettingsTalkPreferencesStore()"))
        #expect(storesSource.contains("preferencesClient: .live(appModel: self.appModel)"))
        #expect(updateProviderFunction.contains("let selection = TalkModeProviderSelection.resolved(rawValue)"))
        #expect(updateProviderFunction
            .contains("self.talkPreferencesStore.send(.providerSelectionChanged(.init(selection: selection)))"))
        #expect(updateProviderFunction.contains("self.storedTalkProviderSelectionRaw = selection.rawValue"))
        #expect(!updateProviderFunction.contains("self.appModel.setTalkProviderSelection"))
        #expect(updateRealtimeVoiceFunction.contains("let voice = SettingsTalkRealtimeVoiceSelection(rawValue: rawValue)"))
        #expect(updateRealtimeVoiceFunction
            .contains("self.talkPreferencesStore.send(.realtimeVoiceSelectionChanged(.init(voice: voice)))"))
        #expect(updateRealtimeVoiceFunction.contains("self.storedTalkRealtimeVoiceSelectionRaw = voice.value"))
        #expect(!updateRealtimeVoiceFunction.contains("self.appModel.setTalkRealtimeVoiceSelection"))
        #expect(actionsSource.contains("locale: SettingsTalkSpeechLocale(value: speechLocale)"))
        #expect(updateBackgroundFunction.contains("enabled: .init(isEnabled: enabled)"))
        #expect(updateBackgroundFunction.contains("self.storedTalkBackgroundEnabled = enabled"))
        #expect(updateButtonFunction.contains("enabled: .init(isEnabled: enabled)"))
        #expect(updateButtonFunction.contains("self.storedTalkButtonEnabled = enabled"))
        #expect(updateSpeakerphoneFunction.contains("let speakerphone = SettingsTalkSpeakerphoneEnabled(isEnabled: enabled)"))
        #expect(updateSpeakerphoneFunction
            .contains("self.talkPreferencesStore.send(.talkSpeakerphoneEnabledChanged(.init(enabled: speakerphone)))"))
        #expect(updateSpeakerphoneFunction.contains("self.storedTalkSpeakerphoneEnabled = speakerphone.isEnabled"))
        #expect(!updateSpeakerphoneFunction.contains("self.appModel.setTalkSpeakerphoneEnabled"))
        #expect(actionsSource.contains("self.talkPreferencesStore.send(.preferencesSynced(.init("))
        #expect(actionsSource.contains(
            "providerSelection: TalkModeProviderSelection.resolved(self.storedTalkProviderSelectionRaw)"))
        #expect(actionsSource.contains("realtimeVoiceSelection: .init(rawValue: self.storedTalkRealtimeVoiceSelectionRaw)"))
        #expect(actionsSource.contains("speechLocale: .init(value: self.storedTalkSpeechLocale)"))
        #expect(actionsSource.contains("talkButtonEnabled: .init(isEnabled: self.storedTalkButtonEnabled)"))
        #expect(actionsSource.contains("self.talkPreferencesStore.send(.gatewayTalkConfigSynced(.init("))
        #expect(actionsSource.contains("self.talkPreferencesStore.send(.gatewayTalkDisplayContextSynced(.init("))
        #expect(actionsSource.contains("self.talkPreferencesStore.send(.gatewayTalkRuntimeSynced(.init("))
        #expect(!preferencesSource.contains("state.talkBackgroundEnabled = change.isEnabled"))
        #expect(!preferencesSource.contains("state.talkButtonEnabled = change.isEnabled"))
        #expect(!actionsSource.contains("talkBackgroundEnabledChanged(.init(isEnabled:"))
        #expect(!actionsSource.contains("talkButtonEnabledChanged(.init(isEnabled:"))
        #expect(!preferencesSource.contains("case gatewayTalkConfigSynced(\n            configLoaded: Bool"))
    }

    @Test func `settings notification action decision is reducer owned`() throws {
        let notificationSource = try String(contentsOf: Self.settingsNotificationFeatureSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)

        #expect(notificationSource.contains("enum ActionRequest: Equatable, Sendable"))
        #expect(notificationSource.contains("struct RelayConfigSync: Equatable, Sendable"))
        #expect(notificationSource.contains("enum AuthorizationRequestPhase: Equatable, Sendable"))
        #expect(notificationSource.contains("case idle"))
        #expect(notificationSource.contains("case inFlight"))
        #expect(notificationSource.contains("struct HostedRelayEnabled: Equatable, Sendable"))
        #expect(notificationSource.contains("struct HostedRelayHost: Equatable, Sendable"))
        #expect(notificationSource.contains("var authorizationRequestPhase = AuthorizationRequestPhase.idle"))
        #expect(notificationSource.contains("var usesOpenClawHostedRelay = Action.HostedRelayEnabled(value: false)"))
        #expect(notificationSource.contains("var usesOpenClawHostedRelay: HostedRelayEnabled"))
        #expect(notificationSource.contains("var hostedRelayHost: HostedRelayHost"))
        #expect(notificationSource.contains("private static let defaultHostedRelayHost = \"ios-push-relay.openclaw.ai\""))
        #expect(notificationSource.contains(
            "var hostedRelayHost = HostedRelayHost(value: SettingsNotificationFeature.defaultHostedRelayHost)"))
        #expect(notificationSource.contains("var hostedRelayHostText: String"))
        #expect(notificationSource.contains("state.hostedRelayHost = .init(value: sync.hostedRelayHost.value ?? Self.defaultHostedRelayHost)"))
        #expect(notificationSource.contains("\\(self.hostedRelayHostText)"))
        #expect(!notificationSource.contains("var hostedRelayHost = \"ios-push-relay.openclaw.ai\""))
        #expect(!notificationSource.contains(
            "state.hostedRelayHost = sync.hostedRelayHost.value ?? \"ios-push-relay.openclaw.ai\""))
        #expect(notificationSource.contains("case actionButtonTapped"))
        #expect(notificationSource.contains("case actionRequestHandled"))
        #expect(notificationSource.contains("state.actionRequest = .openSettings"))
        #expect(notificationSource
            .contains(
                "state.actionRequest = state.usesOpenClawHostedRelay.value ? .showRelayDisclosure : .requestAuthorization"))
        #expect(notificationSource.contains(
            "guard state.status == .notSet, state.authorizationRequestPhase != .inFlight else { return .none }"))
        #expect(notificationSource.contains("state.usesOpenClawHostedRelay = sync.usesOpenClawHostedRelay"))
        #expect(!notificationSource.contains("struct AuthorizationRequestInFlight: Equatable, Sendable"))
        #expect(!notificationSource.contains(
            "var isRequestingAuthorization = Action.AuthorizationRequestInFlight(value: false)"))
        #expect(!notificationSource.contains("var isRequestingAuthorization = false"))
        #expect(!notificationSource.contains("var usesOpenClawHostedRelay = false"))
        #expect(!notificationSource.contains(
            "guard state.status == .notSet, !state.isRequestingAuthorization.value else { return .none }"))
        #expect(!notificationSource.contains("guard state.status == .notSet, !state.isRequestingAuthorization else"))
        #expect(!notificationSource.contains("state.usesOpenClawHostedRelay = sync.usesOpenClawHostedRelay.value"))
        #expect(notificationSource.contains("case notificationSettingsOpenRequested"))
        #expect(notificationSource.contains("await registrationClient.openNotificationSettings()"))
        #expect(actionsSource.contains("self.notificationStore.send(.actionButtonTapped)"))
        #expect(actionsSource.contains("self.notificationStore.send(.actionRequestHandled)"))
        #expect(actionsSource.contains("self.notificationStore.send(.notificationSettingsOpenRequested)"))
        #expect(actionsSource.contains("switch request"))
        #expect(actionsSource.contains("func openNotificationSettings") == false)
        #expect(actionsSource.contains("UIApplication.openNotificationSettingsURLString") == false)
        #expect(!actionsSource.contains("if self.notificationStore.status.shouldOpenNotificationSettings"))
        #expect(!actionsSource.contains("guard self.notificationStore.status == .notSet else"))
        #expect(!actionsSource.contains("if PushBuildConfig.current.usesOpenClawHostedRelay"))
    }

    @Test func `settings notification authorization request is reducer effect owned`() throws {
        let notificationSource = try String(contentsOf: Self.settingsNotificationFeatureSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let sectionsSource = try String(contentsOf: Self.settingsProTabSectionsSourceURL(), encoding: .utf8)
        let settingsSource = try Self.settingsProTabCombinedSource()
        let requestFunction = try Self.extract(
            actionsSource,
            from: "func requestNotificationAuthorizationFromSettings()",
            to: "func handleNotificationAuthorizationResult")

        #expect(notificationSource.contains("struct SettingsNotificationAuthorizationClient"))
        #expect(notificationSource.contains("struct SettingsNotificationAuthorizationGranted: Equatable, Sendable"))
        #expect(notificationSource.contains("let granted: SettingsNotificationAuthorizationGranted"))
        #expect(notificationSource.contains("enum AuthorizationRequestPhase: Equatable, Sendable"))
        #expect(notificationSource.contains("var authorizationRequestPhase = AuthorizationRequestPhase.idle"))
        #expect(notificationSource.contains("case authorizationRequestRequested"))
        #expect(notificationSource
            .contains("case authorizationRequestFinished(SettingsNotificationAuthorizationResult)"))
        #expect(notificationSource.contains("await authorizationClient.requestAuthorization()"))
        #expect(notificationSource.contains("return .run { send in"))
        #expect(notificationSource.contains("guard state.authorizationRequestPhase != .inFlight else { return .none }"))
        #expect(notificationSource.contains("state.authorizationRequestPhase = .inFlight"))
        #expect(notificationSource.contains("state.authorizationRequestPhase = .idle"))
        #expect(requestFunction.contains("guard self.notificationStore.authorizationRequestPhase != .inFlight else { return }"))
        #expect(sectionsSource.contains("|| self.notificationStore.authorizationRequestPhase == .inFlight"))
        #expect(actionsSource.contains("self.notificationStore.send(.authorizationRequestRequested)"))
        #expect(actionsSource.contains("self.notificationStore.send(.authorizationRequestResultHandled)"))
        #expect(settingsSource
            .contains("self.handleNotificationAuthorizationResult(result)"))
        #expect(actionsSource.contains("guard result.granted.value else { return }"))
        #expect(requestFunction.contains("UNUserNotificationCenter.current().requestAuthorization") == false)
        #expect(requestFunction.contains("let granted = await") == false)
        #expect(requestFunction.contains("Task {") == false)
        #expect(!notificationSource.contains("struct AuthorizationRequestInFlight: Equatable, Sendable"))
        #expect(!notificationSource.contains(
            "var isRequestingAuthorization = Action.AuthorizationRequestInFlight(value: false)"))
        #expect(!notificationSource.contains("let granted: Bool"))
        #expect(!actionsSource.contains("guard result.granted else { return }"))
        #expect(!notificationSource.contains("guard !state.isRequestingAuthorization.value else { return .none }"))
        #expect(!notificationSource.contains("guard !state.isRequestingAuthorization else { return .none }"))
        #expect(!notificationSource.contains("state.isRequestingAuthorization = .init(value: true)"))
        #expect(!notificationSource.contains("state.isRequestingAuthorization = .init(value: false)"))
        #expect(!notificationSource.contains("state.isRequestingAuthorization = true"))
        #expect(!notificationSource.contains("state.isRequestingAuthorization = false"))
        #expect(!requestFunction.contains("guard !self.notificationStore.isRequestingAuthorization.value else { return }"))
        #expect(!requestFunction.contains("guard !self.notificationStore.isRequestingAuthorization else { return }"))
        #expect(!sectionsSource.contains("|| self.notificationStore.isRequestingAuthorization.value"))
        #expect(!sectionsSource.contains("|| self.notificationStore.isRequestingAuthorization)"))
    }

    @Test func `settings notification status refresh is reducer effect owned`() throws {
        let notificationSource = try String(contentsOf: Self.settingsNotificationFeatureSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let settingsSource = try Self.settingsProTabCombinedSource()
        let refreshFunction = try Self.extract(
            actionsSource,
            from: "func refreshNotificationSettings()",
            to: "func handleNotificationAction")
        let resultFunction = try Self.extract(
            actionsSource,
            from: "func handleNotificationStatusRefreshResult",
            to: "@MainActor\n    func registerForRemoteNotificationsIfEnrollmentReady")

        #expect(notificationSource.contains("var fetchStatus: @Sendable () async -> SettingsNotificationStatus"))
        #expect(notificationSource.contains("case statusRefreshRequested"))
        #expect(notificationSource.contains("case statusRefreshFinished(SettingsNotificationStatus)"))
        #expect(notificationSource.contains("await authorizationClient.fetchStatus()"))
        #expect(notificationSource.contains("return .run { send in"))
        #expect(settingsSource.contains(".onChange(of: self.notificationStore.statusRefreshResult)"))
        #expect(actionsSource.contains("self.notificationStore.send(.statusRefreshRequested)"))
        #expect(actionsSource.contains("self.notificationStore.send(.statusRefreshResultHandled)"))
        #expect(actionsSource.contains("await self.notificationStore.send(.statusRefreshRequested).finish()"))
        #expect(refreshFunction.contains("UNUserNotificationCenter.current().getNotificationSettings") == false)
        #expect(refreshFunction.contains("Task {") == false)
        #expect(resultFunction.contains("UNUserNotificationCenter") == false)
    }

    @Test func `settings diagnostics completion is reducer owned`() throws {
        let diagnosticsSource = try String(contentsOf: Self.settingsDiagnosticsFeatureSourceURL(), encoding: .utf8)
        let activitySource = try String(contentsOf: Self.settingsGatewayActivityFeatureSourceURL(), encoding: .utf8)
        let supportSource = try String(contentsOf: Self.settingsProTabSupportSourceURL(), encoding: .utf8)
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let runDiagnosticsFunction = try Self.extract(
            actionsSource,
            from: "func runDiagnostics()",
            to: "func syncSettingsState()")

        #expect(diagnosticsSource.contains("struct DiagnosticsContextSync: Equatable, Sendable"))
        #expect(diagnosticsSource.contains("struct DiagnosticsCompletionRequest: Equatable, Sendable"))
        #expect(diagnosticsSource.contains("struct AppleReviewDemoModeEnabled: Equatable, Sendable"))
        #expect(diagnosticsSource.contains("struct DiagnosticsGatewayConnected: Equatable, Sendable"))
        #expect(diagnosticsSource.contains("struct DiscoveredGatewayCount: Equatable, Sendable"))
        #expect(diagnosticsSource.contains("struct DiscoveryStatusText: Equatable, Sendable"))
        #expect(diagnosticsSource.contains("struct DiagnosticsIssueCount: Equatable, Sendable"))
        #expect(diagnosticsSource.contains("struct ScreenRecordActive: Equatable, Sendable"))
        #expect(diagnosticsSource.contains("struct TalkConfigLoaded: Equatable, Sendable"))
        #expect(diagnosticsSource.contains("struct NotificationsAllowed: Equatable, Sendable"))
        #expect(diagnosticsSource.contains("struct LastRunText: Equatable, Sendable"))
        #expect(diagnosticsSource.contains("var discoveryStatusText = DiscoveryStatusText(value: \"Discovery idle\")"))
        #expect(diagnosticsSource.contains("var lastRunText = LastRunText(value: \"Not run\")"))
        #expect(diagnosticsSource.contains("var issueCount: DiagnosticsIssueCount?"))
        #expect(diagnosticsSource.contains("issueCount.value == 0"))
        #expect(diagnosticsSource.contains("\\(issueCount.value)"))
        #expect(diagnosticsSource
            .contains("var discoveredGatewayCount = Action.DiscoveredGatewayCount(value: 0)"))
        #expect(diagnosticsSource
            .contains("var gatewayConnected = Action.DiagnosticsGatewayConnected(value: false)"))
        #expect(diagnosticsSource.contains(
            "var isAppleReviewDemoModeEnabled = Action.AppleReviewDemoModeEnabled(value: false)"))
        #expect(diagnosticsSource.contains(
            "var screenRecordActive = Action.ScreenRecordActive(value: false)"))
        #expect(diagnosticsSource.contains("var gatewayConnected: DiagnosticsGatewayConnected"))
        #expect(diagnosticsSource.contains("var discoveredGatewayCount: DiscoveredGatewayCount"))
        #expect(diagnosticsSource.contains("var discoveryStatusText: DiscoveryStatusText"))
        #expect(diagnosticsSource.contains("var lastRunText: LastRunText"))
        #expect(diagnosticsSource.contains(
            "state.isAppleReviewDemoModeEnabled = sync.isAppleReviewDemoModeEnabled"))
        #expect(diagnosticsSource.contains("state.gatewayConnected = sync.gatewayConnected"))
        #expect(diagnosticsSource.contains("state.discoveredGatewayCount = sync.discoveredGatewayCount"))
        #expect(diagnosticsSource.contains("state.discoveryStatusText = sync.discoveryStatusText"))
        #expect(diagnosticsSource.contains("state.screenRecordActive = sync.screenRecordActive"))
        #expect(diagnosticsSource.contains("state.lastRunText = request.lastRunText"))
        #expect(diagnosticsSource.contains("state.issueCount = .init(value: SettingsDiagnostics.issueCount("))
        #expect(actionsSource.contains("self.diagnosticsStore.lastRunText.value"))
        #expect(actionsSource.contains("self.diagnosticsStore.discoveryStatusText.value"))
        #expect(diagnosticsSource.contains("case diagnosticsContextSynced(DiagnosticsContextSync)"))
        #expect(diagnosticsSource.contains("case diagnosticsCompletionRequested(DiagnosticsCompletionRequest)"))
        #expect(!diagnosticsSource.contains("var discoveredGatewayCount = 0"))
        #expect(!diagnosticsSource.contains("var discoveryStatusText = \"Discovery idle\""))
        #expect(!diagnosticsSource.contains("var gatewayConnected = false"))
        #expect(!diagnosticsSource.contains("var isAppleReviewDemoModeEnabled = false"))
        #expect(!diagnosticsSource.contains("var lastRunText = \"Not run\""))
        #expect(!diagnosticsSource.contains("var screenRecordActive = false"))
        #expect(!diagnosticsSource.contains("var issueCount: Int?"))
        #expect(!diagnosticsSource.contains("return issueCount == 0"))
        #expect(!diagnosticsSource.contains("\"\\(issueCount)\""))
        #expect(!diagnosticsSource.contains(
            "state.isAppleReviewDemoModeEnabled = sync.isAppleReviewDemoModeEnabled.value"))
        #expect(!diagnosticsSource.contains("state.gatewayConnected = sync.gatewayConnected.value"))
        #expect(!diagnosticsSource.contains("state.discoveredGatewayCount = sync.discoveredGatewayCount.value"))
        #expect(!diagnosticsSource.contains("state.discoveryStatusText = sync.discoveryStatusText.value"))
        #expect(!diagnosticsSource.contains("state.screenRecordActive = sync.screenRecordActive.value"))
        #expect(!diagnosticsSource.contains("state.lastRunText = request.lastRunText.value"))
        #expect(!diagnosticsSource.contains("state.issueCount = SettingsDiagnostics.issueCount("))
        #expect(!actionsSource.contains("detail: self.diagnosticsStore.lastRunText,"))
        #expect(!actionsSource.contains("detail: self.diagnosticsStore.discoveryStatusText,"))
        #expect(supportSource.contains("struct SettingsGatewayDiagnosticsRefreshClient"))
        #expect(supportSource.contains("var settingsGatewayDiagnosticsRefresh: SettingsGatewayDiagnosticsRefreshClient"))
        #expect(activitySource.contains("enum RefreshPhase: Equatable, Sendable"))
        #expect(activitySource.contains("var refreshPhase = RefreshPhase.idle"))
        #expect(activitySource.contains("struct DiagnosticsRefreshRequest: Equatable, Sendable"))
        #expect(activitySource.contains(
            "var isAppleReviewDemoModeEnabled: SettingsGatewayActivityDemoModeEnabled"))
        #expect(activitySource.contains("case diagnosticsRefreshRequested(DiagnosticsRefreshRequest)"))
        #expect(activitySource.contains("@Dependency(\\.settingsGatewayDiagnosticsRefresh)"))
        #expect(activitySource.contains("await diagnosticsRefreshClient.refreshGateway()"))
        #expect(activitySource.contains("await send(.refreshFinished)"))
        #expect(activitySource.contains("guard state.refreshPhase != .inFlight else { return .none }"))
        #expect(activitySource.contains("state.refreshPhase = .inFlight"))
        #expect(activitySource.contains("state.refreshPhase = .idle"))
        #expect(activitySource.contains("if !request.isAppleReviewDemoModeEnabled.value"))
        #expect(runDiagnosticsFunction.contains("self.gatewayActivityStore"))
        #expect(runDiagnosticsFunction
            .contains("let isAppleReviewDemoModeEnabled = self.appModel.isAppleReviewDemoModeEnabled"))
        #expect(runDiagnosticsFunction.contains(".send(.diagnosticsRefreshRequested(.init("))
        #expect(runDiagnosticsFunction.contains(
            "isAppleReviewDemoModeEnabled: .init(value: isAppleReviewDemoModeEnabled)"))
        #expect(runDiagnosticsFunction.contains("guard self.gatewayActivityStore.refreshPhase != .inFlight else"))
        #expect(actionsSource.contains("self.diagnosticsStore.send(.diagnosticsCompletionRequested(.init("))
        #expect(actionsSource.contains("self.diagnosticsStore.send(.diagnosticsContextSynced(.init("))
        #expect(!diagnosticsSource.contains("case diagnosticsCompletionRequested(\n            gatewayConnected: Bool"))
        #expect(!diagnosticsSource.contains("case diagnosticsContextSynced(\n" +
            "            isAppleReviewDemoModeEnabled: Bool"))
        #expect(!activitySource.contains(
            "struct DiagnosticsRefreshRequest: Equatable, Sendable { var isAppleReviewDemoModeEnabled: Bool }"))
        #expect(!activitySource.contains(
            "struct ReconnectRequest: Equatable, Sendable { var isAppleReviewDemoModeEnabled: Bool }"))
        #expect(!activitySource.contains("struct GatewayRefreshInFlight: Equatable, Sendable"))
        #expect(!activitySource.contains("var isRefreshingGateway = Action.GatewayRefreshInFlight(value: false)"))
        #expect(!activitySource.contains("var isRefreshingGateway = false"))
        #expect(!activitySource.contains("guard !state.isRefreshingGateway else { return .none }"))
        #expect(!activitySource.contains("guard !state.isRefreshingGateway.value else { return .none }"))
        #expect(!activitySource.contains("state.isRefreshingGateway = .init(value: true)"))
        #expect(!activitySource.contains("state.isRefreshingGateway = .init(value: false)"))
        #expect(!activitySource.contains("state.isRefreshingGateway = true"))
        #expect(!activitySource.contains("state.isRefreshingGateway = false"))
        #expect(!runDiagnosticsFunction.contains("guard !self.gatewayActivityStore.isRefreshingGateway.value else"))
        #expect(!runDiagnosticsFunction.contains("guard !self.gatewayActivityStore.isRefreshingGateway else"))
        #expect(runDiagnosticsFunction.contains("await self.notificationStore.send(.statusRefreshRequested).finish()"))
        #expect(runDiagnosticsFunction.contains("self.handleNotificationStatusRefreshResult"))
        #expect(rootSource.contains("gatewayActivityStore: self.makeSettingsGatewayActivityStore()"))
        #expect(storesSource.contains("SettingsGatewayActivityFeature("))
        #expect(storesSource.contains("diagnosticsRefreshClient: .live("))
        #expect(!runDiagnosticsFunction.contains("self.gatewayController.refreshActiveGatewayRegistrationFromSettings()"))
        #expect(!runDiagnosticsFunction.contains("self.gatewayController.restartDiscovery()"))
        #expect(!runDiagnosticsFunction.contains("await self.appModel.refreshGatewayOverviewIfConnected()"))
        #expect(runDiagnosticsFunction.contains("UNUserNotificationCenter.current().notificationSettings()") == false)
        #expect(actionsSource.contains("func applyNotificationStatus") == false)
        #expect(runDiagnosticsFunction.contains("SettingsDiagnostics.issueCount(") == false)
        #expect(actionsSource.contains(".diagnosticsCompleted(") == false)
    }

    @Test func `settings location mode request decision is reducer owned`() throws {
        let locationSource = try String(contentsOf: Self.settingsLocationFeatureSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let settingsSource = try Self.settingsProTabCombinedSource()
        let requestFunction = try Self.extract(
            actionsSource,
            from: "func handleLocationModeRequest",
            to: "func handleLocationModeApplyResult")

        #expect(locationSource.contains("struct LocationModeRequest: Equatable, Sendable"))
        #expect(locationSource.contains("struct LocationModeRawValue: Equatable, Sendable"))
        #expect(locationSource.contains("var locationModeRaw = LocationModeRawValue(rawValue: OpenClawLocationMode.off.rawValue)"))
        #expect(locationSource.contains(
            "var previousLocationModeRaw = LocationModeRawValue(rawValue: OpenClawLocationMode.off.rawValue)"))
        #expect(locationSource.contains("self.locationModeRaw.mode ?? .off"))
        #expect(locationSource.contains("let previousValue: LocationModeRawValue"))
        #expect(locationSource.contains("var value: LocationModeRawValue"))
        #expect(locationSource.contains("struct LocationModeChange: Equatable, Sendable"))
        #expect(locationSource.contains("var mode: OpenClawLocationMode"))
        #expect(locationSource.contains("struct LocationModeChangeRequest: Equatable, Sendable"))
        #expect(locationSource.contains("case locationModeChanged(LocationModeChange)"))
        #expect(locationSource.contains("case locationModeChangeRequested(LocationModeChangeRequest)"))
        #expect(actionsSource.contains("guard let mode = OpenClawLocationMode(rawValue: rawValue) else { return }"))
        #expect(actionsSource.contains("self.locationStore.send(.locationModeChanged(.init(mode: mode)))"))
        #expect(locationSource.contains("guard let mode = request.value.mode else"))
        #expect(locationSource.contains("state.locationModeRequest = LocationModeRequest("))
        #expect(settingsSource.contains("self.locationStore.send(.locationModeChangeRequested(.init(rawValue: newValue)))"))
        #expect(settingsSource.contains("self.handleLocationModeRequest(self.locationStore.locationModeRequest)"))
        #expect(actionsSource.contains("self.locationStore.send(.locationModeApplyRequested(request))"))
        #expect(actionsSource.contains("self.locationStore.locationModeRaw.rawValue"))
        #expect(requestFunction.contains("OpenClawLocationMode(rawValue:") == false)
        #expect(requestFunction.contains("previousLocationModeRaw") == false)
        #expect(!locationSource.contains("var locationModeRaw = OpenClawLocationMode.off.rawValue"))
        #expect(!locationSource.contains("var previousLocationModeRaw = OpenClawLocationMode.off.rawValue"))
        #expect(!locationSource.contains("OpenClawLocationMode(rawValue: self.locationModeRaw)"))
        #expect(!actionsSource.contains("get: { self.locationStore.locationModeRaw }"))
    }

    @Test func `settings device capability toggle actions are typed`() throws {
        let deviceCapabilitySource = try String(
            contentsOf: Self.settingsDeviceCapabilityFeatureSourceURL(),
            encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let settingsSource = try Self.settingsProTabCombinedSource()

        #expect(deviceCapabilitySource.contains("struct CameraEnabled: Equatable, Sendable"))
        #expect(deviceCapabilitySource.contains("struct CameraEnabledChange: Equatable, Sendable"))
        #expect(deviceCapabilitySource.contains("var enabled: CameraEnabled"))
        #expect(deviceCapabilitySource.contains("var cameraEnabled = CameraEnabled(value: true)"))
        #expect(deviceCapabilitySource.contains("var cameraEnabled: CameraEnabled"))
        #expect(deviceCapabilitySource.contains("struct PreventSleepEnabled: Equatable, Sendable"))
        #expect(deviceCapabilitySource.contains("struct PreventSleepChange: Equatable, Sendable"))
        #expect(deviceCapabilitySource.contains("var enabled: PreventSleepEnabled"))
        #expect(deviceCapabilitySource.contains("var preventSleep = PreventSleepEnabled(value: true)"))
        #expect(deviceCapabilitySource.contains("var preventSleep: PreventSleepEnabled"))
        #expect(deviceCapabilitySource.contains("struct LocationModeRawValue: Equatable, Sendable"))
        #expect(deviceCapabilitySource.contains("var locationModeRaw = LocationModeRawValue(rawValue:"))
        #expect(deviceCapabilitySource.contains("self.locationModeRaw.rawValue != OpenClawLocationMode.off.rawValue"))
        #expect(deviceCapabilitySource.contains("var locationMode: SettingsDeviceCapabilityLocationMode"))
        #expect(deviceCapabilitySource.contains("state.cameraEnabled = change.enabled"))
        #expect(deviceCapabilitySource.contains("state.preventSleep = change.enabled"))
        #expect(deviceCapabilitySource.contains("state.cameraEnabled = sync.cameraEnabled"))
        #expect(deviceCapabilitySource.contains("state.preventSleep = sync.preventSleep"))
        #expect(deviceCapabilitySource.contains("state.locationModeRaw = .init(rawValue: sync.locationMode.rawValue)"))
        #expect(actionsSource.contains("self.deviceCapabilityStore.cameraEnabled.value"))
        #expect(actionsSource.contains("self.deviceCapabilityStore.preventSleep.value"))
        #expect(!deviceCapabilitySource.contains("var cameraEnabled = true"))
        #expect(!deviceCapabilitySource.contains("var locationModeRaw = OpenClawLocationMode.off.rawValue"))
        #expect(!deviceCapabilitySource.contains("var preventSleep = true"))
        #expect(!deviceCapabilitySource.contains("self.locationModeRaw != OpenClawLocationMode.off.rawValue"))
        #expect(!deviceCapabilitySource.contains("state.cameraEnabled = change.enabled.value"))
        #expect(!deviceCapabilitySource.contains("state.preventSleep = change.enabled.value"))
        #expect(!deviceCapabilitySource.contains("state.cameraEnabled = sync.cameraEnabled.value"))
        #expect(!deviceCapabilitySource.contains("state.preventSleep = sync.preventSleep.value"))
        #expect(!deviceCapabilitySource.contains("state.locationModeRaw = sync.locationMode.rawValue"))
        #expect(actionsSource.contains(
            "SettingsDeviceCapabilityFeature.CameraEnabledChange(enabled: .init(value: enabled))"))
        #expect(actionsSource.contains(
            "SettingsDeviceCapabilityFeature.PreventSleepChange(enabled: .init(value: enabled))"))
        #expect(actionsSource.contains("cameraEnabled: .init(value: self.storedCameraEnabled)"))
        #expect(actionsSource.contains("preventSleep: .init(value: self.storedPreventSleep)"))
        #expect(actionsSource.contains("locationMode: .init(rawValue: self.storedLocationModeRaw)"))
        #expect(settingsSource.contains("self.deviceCapabilityStore.send(.cameraEnabledChanged(.init("))
        #expect(settingsSource.contains("self.deviceCapabilityStore.send(.preventSleepChanged(.init("))
        #expect(settingsSource.contains("enabled: .init(value: newValue)"))
        #expect(!deviceCapabilitySource.contains("var isEnabled: Bool"))
        #expect(!deviceCapabilitySource.contains("state.cameraEnabled = change.isEnabled"))
        #expect(!deviceCapabilitySource.contains("state.preventSleep = change.isEnabled"))
        #expect(!actionsSource.contains("SettingsDeviceCapabilityFeature.CameraEnabledChange(isEnabled:"))
        #expect(!actionsSource.contains("SettingsDeviceCapabilityFeature.PreventSleepChange(isEnabled:"))
        #expect(!settingsSource.contains("cameraEnabledChanged(.init(isEnabled:"))
        #expect(!settingsSource.contains("preventSleepChanged(.init(isEnabled:"))
    }

    @Test func `settings device capability location mode action is typed`() throws {
        let deviceCapabilitySource = try String(
            contentsOf: Self.settingsDeviceCapabilityFeatureSourceURL(),
            encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let settingsSource = try Self.settingsProTabCombinedSource()
        let persistedSyncSend =
            "self.deviceCapabilityStore.send(.locationModeChanged(.init(mode: .init(rawValue: newValue))))"

        #expect(deviceCapabilitySource.contains("enum SettingsDeviceCapabilityLocationMode: Equatable"))
        #expect(deviceCapabilitySource.contains("case known(OpenClawLocationMode)"))
        #expect(deviceCapabilitySource.contains("case unknown(String)"))
        #expect(deviceCapabilitySource.contains("var mode: SettingsDeviceCapabilityLocationMode"))
        #expect(deviceCapabilitySource.contains("state.locationModeRaw = .init(rawValue: change.mode.rawValue)"))
        #expect(!deviceCapabilitySource.contains("state.locationModeRaw = change.mode.rawValue"))
        #expect(actionsSource.contains("SettingsDeviceCapabilityFeature.LocationModeChange(mode: .init(mode: mode))"))
        #expect(settingsSource.contains(persistedSyncSend))
    }

    @Test func `settings location apply request is reducer effect owned`() throws {
        let locationSource = try String(contentsOf: Self.settingsLocationFeatureSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let settingsSource = try Self.settingsProTabCombinedSource()
        let sectionsSource = try String(contentsOf: Self.settingsProTabSectionsSourceURL(), encoding: .utf8)
        let requestFunction = try Self.extract(
            actionsSource,
            from: "func handleLocationModeRequest",
            to: "func handleLocationModeApplyResult")
        let resultFunction = try Self.extract(
            actionsSource,
            from: "func handleLocationModeApplyResult",
            to: "func refreshNotificationSettings")

        #expect(locationSource.contains("struct SettingsLocationPermissionClient: Sendable"))
        #expect(locationSource.contains("struct SettingsLocationGatewayRefreshClient: Sendable"))
        #expect(locationSource.contains("var settingsLocationGatewayRefresh: SettingsLocationGatewayRefreshClient"))
        #expect(locationSource.contains("@Dependency(\\.settingsLocationGatewayRefresh)"))
        #expect(locationSource.contains("case locationModeApplyRequested(LocationModeRequest)"))
        #expect(locationSource.contains("case locationModeApplyFinished(LocationModeApplyResult)"))
        #expect(locationSource.contains("struct Applied: Equatable, Sendable"))
        #expect(locationSource.contains("struct Denied: Equatable, Sendable"))
        #expect(locationSource.contains("case applied(Applied)"))
        #expect(locationSource.contains("case denied(Denied)"))
        #expect(locationSource.contains("enum LocationModeChangePhase: Equatable, Sendable"))
        #expect(locationSource.contains("case idle"))
        #expect(locationSource.contains("case inFlight"))
        #expect(locationSource.contains("var locationModeChangePhase = LocationModeChangePhase.idle"))
        #expect(locationSource.contains("guard state.locationModeChangePhase != .inFlight else { return .none }"))
        #expect(locationSource.contains("state.locationModeChangePhase = .inFlight"))
        #expect(locationSource.contains("state.locationModeChangePhase = .idle"))
        #expect(locationSource.contains("state.locationModeRaw = applied.value"))
        #expect(locationSource.contains("state.previousLocationModeRaw = applied.value"))
        #expect(locationSource.contains("state.locationModeRaw = denied.previousValue"))
        #expect(locationSource.contains("state.previousLocationModeRaw = denied.previousValue"))
        #expect(locationSource.contains("state.locationModeRaw = request.value"))
        #expect(locationSource.contains("state.previousLocationModeRaw = request.value"))
        #expect(locationSource.contains("state.locationModeRaw = .init(rawValue: change.mode.rawValue)"))
        #expect(locationSource.contains("let rawValue = request.value"))
        #expect(locationSource.contains("guard rawValue != state.previousLocationModeRaw else { return .none }"))
        #expect(locationSource.contains("previousValue: state.previousLocationModeRaw"))
        #expect(locationSource.contains("state.locationModeRaw = sync.value"))
        #expect(locationSource.contains("state.previousLocationModeRaw = sync.value"))
        #expect(locationSource.contains("struct SettingsLocationStatusText: Equatable, Sendable { var value: String? }"))
        #expect(locationSource.contains("var statusText = SettingsLocationStatusText(value: nil)"))
        #expect(locationSource.contains("state.statusText = .init(value: Self.locationPermissionDeniedStatusText)"))
        #expect(locationSource.contains("state.statusText = .init(value: nil)"))
        #expect(locationSource.contains(
            "private static let locationPermissionDeniedStatusText = \"Location permission was not granted.\""))
        #expect(locationSource.contains("await permissionClient.requestPermission(request.mode)"))
        #expect(locationSource.contains("await gatewayRefreshClient.refreshGatewayRegistration()"))
        #expect(locationSource.contains("return .run { send in"))
        #expect(sectionsSource.contains("self.locationStore.locationModeChangePhase == .inFlight"))
        #expect(sectionsSource.contains("if let locationStatusText = self.locationStore.statusText.value"))
        #expect(settingsSource.contains(".onChange(of: self.locationStore.locationModeApplyResult)"))
        #expect(rootSource.contains("locationStore: self.makeSettingsLocationStore()"))
        #expect(storesSource.contains("func makeSettingsLocationStore()"))
        #expect(storesSource.contains("gatewayRefreshClient: .live(gatewayController: self.gatewayController)"))
        #expect(actionsSource.contains("self.locationStore.send(.locationModeApplyResultHandled)"))
        #expect(actionsSource.contains("if case let .denied(denied) = result"))
        #expect(actionsSource.contains("self.storedLocationModeRaw = denied.previousValue.rawValue"))
        #expect(requestFunction.contains("Task {") == false)
        #expect(requestFunction.contains("requestLocationPermissions") == false)
        #expect(resultFunction.contains("requestLocationPermissions") == false)
        #expect(!locationSource.contains("var statusText: String?"))
        #expect(!locationSource.contains("struct LocationModeChangeInFlight: Equatable, Sendable"))
        #expect(!locationSource.contains("var isChangingLocationMode = LocationModeChangeInFlight(value: false)"))
        #expect(!locationSource.contains("var isChangingLocationMode = false"))
        #expect(!locationSource.contains("state.isChangingLocationMode = true"))
        #expect(!locationSource.contains("state.isChangingLocationMode = false"))
        #expect(!locationSource.contains("state.isChangingLocationMode = .init(value: true)"))
        #expect(!locationSource.contains("state.isChangingLocationMode = .init(value: false)"))
        #expect(!locationSource.contains("guard !state.isChangingLocationMode.value else { return .none }"))
        #expect(!locationSource.contains("guard !state.isChangingLocationMode else { return .none }"))
        #expect(!locationSource.contains("state.locationModeRaw = applied.value.rawValue"))
        #expect(!locationSource.contains("state.previousLocationModeRaw = applied.value.rawValue"))
        #expect(!locationSource.contains("state.locationModeRaw = denied.previousValue.rawValue"))
        #expect(!locationSource.contains("state.previousLocationModeRaw = denied.previousValue.rawValue"))
        #expect(!locationSource.contains("state.locationModeRaw = request.value.rawValue"))
        #expect(!locationSource.contains("state.previousLocationModeRaw = request.value.rawValue"))
        #expect(!locationSource.contains("previousValue: .init(rawValue: state.previousLocationModeRaw)"))
        #expect(!locationSource.contains("state.locationModeRaw = sync.value.rawValue"))
        #expect(!locationSource.contains("state.previousLocationModeRaw = sync.value.rawValue"))
        #expect(!locationSource.contains("state.statusText = \"Location permission was not granted.\""))
        #expect(!locationSource.contains("state.statusText = nil"))
        #expect(!sectionsSource.contains("self.locationStore.isChangingLocationMode.value"))
        #expect(!sectionsSource.contains("self.locationStore.isChangingLocationMode)"))
        #expect(!sectionsSource.contains("if let locationStatusText = self.locationStore.statusText {"))
        #expect(!resultFunction.contains("self.gatewayController.refreshActiveGatewayRegistrationFromSettings()"))
        #expect(actionsSource.contains("func applyLocationMode") == false)
    }

    @Test func `settings discovery debug logging is reducer effect owned`() throws {
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let settingsSource = try Self.settingsProTabCombinedSource()
        let updateFunction = try Self.extract(
            actionsSource,
            from: "func updateDiscoveryDebugLogsEnabled",
            to: "func updateCanvasDebugStatusEnabled")
        let storedDebugChange = try Self.extract(
            settingsSource,
            from: ".onChange(of: self.storedDiscoveryDebugLogsEnabled)",
            to: ".onChange(of: self.storedCanvasDebugStatusEnabled)")

        #expect(settingsSource.contains("struct SettingsDiscoveryDebugLoggingClient: Sendable"))
        #expect(settingsSource.contains("var settingsDiscoveryDebugLogging: SettingsDiscoveryDebugLoggingClient"))
        #expect(settingsSource.contains("struct DebugOptionsSync: Equatable, Sendable"))
        #expect(settingsSource.contains("struct SettingsDebugOptionEnabled: Equatable, Sendable"))
        #expect(settingsSource.contains("var discoveryDebugLogsEnabled: SettingsDebugOptionEnabled"))
        #expect(settingsSource.contains("var canvasDebugStatusEnabled: SettingsDebugOptionEnabled"))
        #expect(settingsSource.contains("var discoveryDebugLogs = Action.SettingsDebugOptionEnabled(isEnabled: false)"))
        #expect(settingsSource.contains("var canvasDebugStatus = Action.SettingsDebugOptionEnabled(isEnabled: false)"))
        #expect(settingsSource.contains("var discoveryDebugLogsEnabled: Bool"))
        #expect(settingsSource.contains("var canvasDebugStatusEnabled: Bool"))
        #expect(settingsSource.contains("self.discoveryDebugLogs.isEnabled"))
        #expect(settingsSource.contains("self.canvasDebugStatus.isEnabled"))
        #expect(settingsSource.contains("state.discoveryDebugLogs = sync.discoveryDebugLogsEnabled"))
        #expect(settingsSource.contains("state.canvasDebugStatus = sync.canvasDebugStatusEnabled"))
        #expect(settingsSource.contains("state.discoveryDebugLogs = enabled"))
        #expect(settingsSource.contains("state.canvasDebugStatus = change.enabled"))
        #expect(settingsSource.contains("struct DebugOptionToggleChange: Equatable, Sendable"))
        #expect(settingsSource.contains("var enabled: SettingsDebugOptionEnabled"))
        #expect(settingsSource.contains("case discoveryDebugLogsChanged(DebugOptionToggleChange)"))
        #expect(settingsSource.contains("case canvasDebugStatusChanged(DebugOptionToggleChange)"))
        #expect(settingsSource.contains("@Dependency(\\.settingsDiscoveryDebugLogging)"))
        #expect(settingsSource.contains(
            "await discoveryDebugLoggingClient.setDiscoveryDebugLoggingEnabled(enabled.isEnabled)"))
        #expect(rootSource.contains("debugOptionsStore: self.makeSettingsDebugOptionsStore()"))
        #expect(storesSource.contains("func makeSettingsDebugOptionsStore()"))
        #expect(storesSource.contains("discoveryDebugLoggingClient: .live(gatewayController: self.gatewayController)"))
        #expect(actionsSource.contains(
            "discoveryDebugLogsEnabled: .init(isEnabled: self.storedDiscoveryDebugLogsEnabled)"))
        #expect(actionsSource.contains(
            "canvasDebugStatusEnabled: .init(isEnabled: self.storedCanvasDebugStatusEnabled)"))
        #expect(updateFunction.contains("enabled: .init(isEnabled: enabled)"))
        #expect(!updateFunction.contains("self.gatewayController.setDiscoveryDebugLoggingEnabled(enabled)"))
        #expect(storedDebugChange.contains("enabled: .init(isEnabled: newValue)"))
        #expect(!storedDebugChange.contains("self.gatewayController.setDiscoveryDebugLoggingEnabled(newValue)"))
        #expect(!settingsSource.contains("var canvasDebugStatusEnabled = false"))
        #expect(!settingsSource.contains("var discoveryDebugLogsEnabled = false"))
        #expect(!settingsSource.contains("state.discoveryDebugLogsEnabled = sync.discoveryDebugLogsEnabled.isEnabled"))
        #expect(!settingsSource.contains("state.canvasDebugStatusEnabled = sync.canvasDebugStatusEnabled.isEnabled"))
        #expect(!settingsSource.contains("state.discoveryDebugLogsEnabled = enabled.isEnabled"))
        #expect(!settingsSource.contains("state.canvasDebugStatusEnabled = change.enabled.isEnabled"))
        #expect(!settingsSource.contains("state.canvasDebugStatusEnabled = change.enabled\n"))
        #expect(!settingsSource.contains("state.discoveryDebugLogsEnabled = change.enabled\n"))
        #expect(!actionsSource.contains("discoveryDebugLogsChanged(.init(enabled: enabled))"))
        #expect(!actionsSource.contains("canvasDebugStatusChanged(.init(enabled: enabled))"))
        #expect(!settingsSource.contains(
            "struct DebugOptionsSync: Equatable, Sendable {\n            var discoveryDebugLogsEnabled: Bool"))
        #expect(!settingsSource.contains(
            "struct DebugOptionsSync: Equatable, Sendable {\n            var discoveryDebugLogsEnabled: Bool\n" +
                "            var canvasDebugStatusEnabled: Bool"))
        #expect(!settingsSource.contains("discoveryDebugLogsChanged(.init(enabled: newValue))"))
        #expect(!settingsSource.contains("canvasDebugStatusChanged(.init(enabled: newValue))"))
    }

    @Test func `settings agent selection persistence is reducer effect owned`() throws {
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let agentModelsSource = try String(contentsOf: Self.agentProModelsSourceURL(), encoding: .utf8)
        let settingsSource = try Self.settingsProTabCombinedSource()
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let agentSelectionBinding = try Self.extract(
            settingsSource,
            from: "var agentSelectionBinding: Binding<String>",
            to: "private var gatewayProblemDetailsBinding")
        let externalAgentSync = try Self.extract(
            settingsSource,
            from: ".onChange(of: self.appModel.selectedAgentId ?? \"\")",
            to: ".onChange(of: self.storedSetupCode)")

        #expect(agentModelsSource.contains("struct SelectedAgentID: Equatable, Sendable"))
        #expect(agentModelsSource.contains("var normalized: SelectedAgentID?"))
        #expect(settingsSource.contains("struct SettingsSelectedAgentClient: Sendable"))
        #expect(settingsSource.contains(
            "var setSelectedAgentId: @MainActor @Sendable (SelectedAgentID?) -> Void"))
        #expect(settingsSource.contains("var settingsSelectedAgent: SettingsSelectedAgentClient"))
        #expect(settingsSource.contains("struct PickerSelectionChange: Equatable, Sendable"))
        #expect(settingsSource.contains("var selection: SelectedAgentID"))
        #expect(settingsSource.contains(
            "struct SelectedAgentSync: Equatable, Sendable { var selectedAgent: SelectedAgentID? }"))
        #expect(settingsSource.contains("case pickerSelectionChanged(PickerSelectionChange)"))
        #expect(settingsSource.contains("case selectedAgentSynced(SelectedAgentSync)"))
        #expect(settingsSource.contains("@Dependency(\\.settingsSelectedAgent)"))
        #expect(settingsSource.contains("var selectedAgent = SelectedAgentID(value: \"\")"))
        #expect(settingsSource.contains("var selectedAgentPickerId: String"))
        #expect(settingsSource.contains("self.selectedAgent.value"))
        #expect(settingsSource.contains("state.selectedAgent = change.selection"))
        #expect(settingsSource.contains("let selectedAgentId = change.selection.normalized"))
        #expect(settingsSource.contains("await selectedAgentClient.setSelectedAgentId(selectedAgentId)"))
        #expect(settingsSource.contains("state.selectedAgent = sync.selectedAgent ?? .init(value: \"\")"))
        #expect(settingsSource.contains("appModel.setSelectedAgentId(selectedAgentId?.value)"))
        #expect(rootSource.contains("agentSelectionStore: self.makeSettingsAgentSelectionStore()"))
        #expect(storesSource.contains("func makeSettingsAgentSelectionStore()"))
        #expect(storesSource.contains("selectedAgentClient: .live(appModel: self.appModel)"))
        #expect(agentSelectionBinding.contains(".pickerSelectionChanged(.init(selection: .init(value: $0)))"))
        #expect(!settingsSource.contains("var selectedAgentPickerId = \"\""))
        #expect(!settingsSource.contains("state.selectedAgentPickerId = change.selection.value"))
        #expect(!settingsSource.contains("state.selectedAgentPickerId = sync.selectedAgent?.value ?? \"\""))
        #expect(!settingsSource.contains("selectedAgentId: String?"))
        #expect(!settingsSource.contains("trimmed.isEmpty ? nil : trimmed"))
        #expect(actionsSource.contains("let selectedAgent = self.appModel.selectedAgentId.map { SelectedAgentID(value: $0) }"))
        #expect(actionsSource.contains(".selectedAgentSynced(.init(selectedAgent: selectedAgent))"))
        #expect(externalAgentSync.contains("let selectedAgent = newValue.isEmpty ? nil : SelectedAgentID(value: newValue)"))
        #expect(externalAgentSync.contains(".selectedAgentSynced(.init(selectedAgent: selectedAgent))"))
        #expect(!settingsSource.contains(".selectedAgentSynced(.init(selectedAgentId:"))
        #expect(!externalAgentSync.contains(".pickerSelectionChanged"))
    }

    @Test func `home canvas payload state is reducer owned`() throws {
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let featureSource = try String(contentsOf: Self.rootHomeCanvasSourceURL(), encoding: .utf8)

        #expect(featureSource.contains("@Reducer\nstruct RootHomeCanvasFeature"))
        #expect(featureSource.contains("struct Snapshot: Equatable, Sendable"))
        #expect(featureSource.contains("struct RootHomeCanvasPayloadJSON: Equatable, Sendable"))
        #expect(featureSource.contains("var payloadJSON = RootHomeCanvasPayloadJSON(value: nil)"))
        #expect(featureSource.contains("state.payloadJSON = .init(value: Self.payloadJSON(payload))"))
        #expect(featureSource.contains("static func payloadJSON(_ payload: Payload?) -> String?"))
        #expect(featureSource.contains("encoder.outputFormatting = [.sortedKeys]"))
        #expect(featureSource.contains("encoder.encode(payload)"))
        #expect(featureSource.contains("static func payload(snapshot: Snapshot) -> Payload"))
        #expect(featureSource.contains("extension RootHomeCanvasFeature.Snapshot"))
        #expect(featureSource.contains("init(appModel: NodeAppModel, gatewayStatus: GatewayDisplayState)"))
        #expect(featureSource.contains("appModel.gatewayAgents.map(RootHomeCanvasFeature.AgentSnapshot.init(agent:))"))
        #expect(featureSource.contains("extension RootHomeCanvasFeature.AgentSnapshot"))
        #expect(rootSource.contains("@State private var homeCanvasStore: StoreOf<RootHomeCanvasFeature>"))
        #expect(rootSource.contains("self.homeCanvasStore.send(.snapshotChanged(self.makeHomeCanvasSnapshot()))"))
        #expect(rootSource.contains("self.appModel.screen.updateHomeCanvasState(json: self.homeCanvasStore.payloadJSON.value)"))
        #expect(rootSource.contains("RootHomeCanvasFeature.Snapshot(appModel: self.appModel, gatewayStatus: self.gatewayStatus)"))
        #expect(!featureSource.contains("var payloadJSON: String?"))
        #expect(!featureSource.contains("state.payloadJSON = Self.payloadJSON(payload)"))
        #expect(!rootSource.contains("updateHomeCanvasState(json: self.homeCanvasStore.payloadJSON)"))
        #expect(!rootSource.contains("appModel.gatewayAgents.map(RootHomeCanvasFeature.AgentSnapshot.init(agent:))"))
        #expect(!rootSource.contains("JSONEncoder"))
        #expect(!rootSource.contains("@Reducer\nstruct RootHomeCanvasFeature"))
        #expect(!rootSource.contains("private func makeHomeCanvasPayload() -> RootTabsHomeCanvasPayload"))
        #expect(!rootSource.contains("private func homeCanvasAgents(activeAgentID: String)"))
        #expect(!rootSource.contains("private func homeCanvasBadge(for agent: AgentSummary)"))
        #expect(!rootSource.contains("private struct RootTabsHomeCanvasPayload"))
        #expect(!rootSource.contains("private struct RootTabsHomeCanvasAgentCard"))
    }

    private static func rootTabsSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/RootTabs.swift")
    }

    private static func rootTabsStoresSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/RootTabsStores.swift")
    }

    private static func rootGatewayProblemPrimaryActionSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/RootGatewayProblemPrimaryActionFeature.swift")
    }

    private static func rootGatewayOverviewRefreshSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/RootGatewayOverviewRefreshFeature.swift")
    }

    private static func rootCanvasPresentationSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/RootCanvasPresentationFeature.swift")
    }

    private static func rootCanvasDebugStatusSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/RootCanvasDebugStatusFeature.swift")
    }

    private static func rootIdleTimerSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/RootIdleTimerFeature.swift")
    }

    private static func rootHomeCanvasSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/RootHomeCanvasFeature.swift")
    }

    private static func rootLaunchSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/RootLaunchFeature.swift")
    }

    private static func rootVoiceWakeToastSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/RootVoiceWakeToastFeature.swift")
    }

    private static func rootCameraFlashOverlaySourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/RootCameraFlashOverlayFeature.swift")
    }

    private static func nodeAppModelSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Model/NodeAppModel.swift")
    }

    private static func sessionKeySourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/SessionKey.swift")
    }

    private static func phoneHubSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/RootTabsPhoneControlHub.swift")
    }

    private static func proComponentsSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/OpenClawProComponents.swift")
    }

    private static func commandCenterSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/CommandCenterTab.swift")
    }

    private static func commandSessionsFeatureSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/CommandSessionsFeature.swift")
    }

    private static func commandCenterSupportSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/CommandCenterSupport.swift")
    }

    private static func agentProTabSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/AgentProTab.swift")
    }

    private static func agentProModelsSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/AgentProModels.swift")
    }

    private static func agentProTabOverviewSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/AgentProTab+Overview.swift")
    }

    private static func agentProTabGatewayDataSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/AgentProTab+GatewayData.swift")
    }

    private static func agentProTabSkillsSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/AgentProTab+Skills.swift")
    }

    private static func agentProTabCronSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/AgentProTab+Cron.swift")
    }

    private static func agentProTabDestinationsSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/AgentProTab+Destinations.swift")
    }

    private static func agentProNodesDestinationSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/AgentProNodesDestination.swift")
    }

    private static func agentProDreamingDestinationSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/AgentProDreamingDestination.swift")
    }

    private static func rootTabsNavigationSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/RootTabsNavigation.swift")
    }

    private static func iPadSidebarFeatureScreensSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/IPadSidebarFeatureScreens.swift")
    }

    private static func iPadTaskFeatureScreensSource() throws -> String {
        try [
            self.iPadWorkboardScreenSourceURL(),
            self.iPadWorkboardFeatureSourceURL(),
            self.iPadSkillWorkshopScreenSourceURL(),
            self.iPadSidebarFeatureScreensSourceURL(),
        ]
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")
    }

    private static func iPadWorkboardSource() throws -> String {
        try [
            self.iPadWorkboardScreenSourceURL(),
            self.iPadWorkboardFeatureSourceURL(),
        ]
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")
    }

    private static func iPadWorkboardScreenSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/IPadWorkboardScreen.swift")
    }

    private static func iPadWorkboardFeatureSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/IPadWorkboardFeature.swift")
    }

    private static func iPadSkillWorkshopScreenSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/IPadSkillWorkshopScreen.swift")
    }

    private static func iPadSidebarFeaturePreviewsSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/IPadSidebarFeaturePreviews.swift")
    }

    private static func iPadActivityScreenSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/IPadActivityScreen.swift")
    }

    private static func iPadSidebarScreenChromeSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/IPadSidebarScreenChrome.swift")
    }

    private static func chatProTabSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/ChatProTab.swift")
    }

    private static func talkProTabSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/TalkProTab.swift")
    }

    private static func docsSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/OpenClawDocsScreen.swift")
    }

    private static func settingsProTabSectionsSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/SettingsProTabSections.swift")
    }

    private static func settingsProTabSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/SettingsProTab.swift")
    }

    private static func settingsProTabFeaturesSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/SettingsProTabFeatures.swift")
    }

    private static func settingsProTabCombinedSource() throws -> String {
        let featuresSource = try String(contentsOf: Self.settingsProTabFeaturesSourceURL(), encoding: .utf8)
        let tabSource = try String(contentsOf: Self.settingsProTabSourceURL(), encoding: .utf8)
        return featuresSource + "\n" + tabSource
    }

    private static func settingsGatewayActivityFeatureSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/SettingsGatewayActivityFeature.swift")
    }

    private static func settingsNotificationFeatureSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/SettingsNotificationFeature.swift")
    }

    private static func settingsGatewayConnectionFeatureSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/SettingsGatewayConnectionFeature.swift")
    }

    private static func settingsGatewaySetupLinkFeatureSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/SettingsGatewaySetupLinkFeature.swift")
    }

    private static func settingsDiagnosticsFeatureSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/SettingsDiagnosticsFeature.swift")
    }

    private static func settingsLocationFeatureSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/SettingsLocationFeature.swift")
    }

    private static func settingsDeviceCapabilityFeatureSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/SettingsDeviceCapabilityFeature.swift")
    }

    private static func settingsTalkPreferencesFeatureSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/SettingsTalkPreferencesFeature.swift")
    }

    private static func voiceWakeWordsSettingsSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Settings/VoiceWakeWordsSettingsView.swift")
    }

    private static func privacyAccessSectionSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Settings/PrivacyAccessSectionView.swift")
    }

    private static func settingsGatewaySetupFeaturesSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/SettingsGatewaySetupFeatures.swift")
    }

    private static func onboardingWizardSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Onboarding/OnboardingWizardView.swift")
    }

    private static func onboardingStateStoreSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Onboarding/OnboardingStateStore.swift")
    }

    private static func openClawAppSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/OpenClawApp.swift")
    }

    private static func notificationPermissionGuidanceDialogSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Gateway/NotificationPermissionGuidanceDialog.swift")
    }

    private static func pushEnrollmentConsentSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Push/PushEnrollmentConsent.swift")
    }

    private static func settingsProTabActionsSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/SettingsProTabActions.swift")
    }

    private static func settingsProTabSupportSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/SettingsProTabSupport.swift")
    }

    private static func gatewayTrustPromptAlertSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Gateway/GatewayTrustPromptAlert.swift")
    }

    private static func gatewayQuickSetupSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Gateway/GatewayQuickSetupSheet.swift")
    }

    private static func gatewayProblemSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Gateway/GatewayProblemView.swift")
    }

    private static func gatewayStatusBuilderSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Status/GatewayStatusBuilder.swift")
    }

    private static func gatewayConnectionControllerSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Gateway/GatewayConnectionController.swift")
    }

    private static func channelsSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/SettingsChannelsDestination.swift")
    }

    private static func sharedChatPreviewSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("shared/OpenClawKit/Sources/OpenClawChatUI/ChatView+Previews.swift")
    }

    private static func xcodeProjectSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("OpenClaw.xcodeproj/project.pbxproj")
    }

    private static func extract(_ source: String, from start: String, to end: String) throws -> String {
        let startRange = try #require(source.range(of: start))
        let tail = source[startRange.lowerBound...]
        let endRange = try #require(tail.range(of: end))
        return String(tail[..<endRange.lowerBound])
    }
}
