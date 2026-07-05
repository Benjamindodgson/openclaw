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

        #expect(!source.contains("ToolbarItem"))
        #expect(source.contains("@Reducer\nstruct AgentSkillPolicyMutationFeature"))
        #expect(source.contains("@Reducer\nstruct AgentSkillEditorFeature"))
        #expect(source.contains("@Reducer\nstruct AgentCronActionFeature"))
        #expect(source.contains("@Reducer\nstruct AgentClawHubSearchFeature"))
        #expect(source.contains("@Reducer\nstruct AgentSkillFilterFeature"))
        #expect(source.contains("@Reducer\nstruct AgentOverviewFilterFeature"))
        #expect(source.contains("@Reducer\nstruct AgentOverviewLoadFeature"))
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
        #expect(source.contains("@State var skillFilterStore: StoreOf<AgentSkillFilterFeature>"))
        #expect(source.contains("@State var skillPolicyMutationStore: StoreOf<AgentSkillPolicyMutationFeature>"))
        #expect(source.contains("@State var skillEditorStore: StoreOf<AgentSkillEditorFeature>"))
        #expect(source.contains("@State var cronActionStore: StoreOf<AgentCronActionFeature>"))
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
        #expect(gatewayDataSource.contains("self.overviewStore.send(.refreshLaunched(.init(requestID: requestID)))"))
        #expect(gatewayDataSource
            .contains("self.overviewStore.send(.refreshFinished(.init(snapshot: snapshot, requestID: requestID)))"))
        #expect(skillsSource.contains("text: self.clawHubQueryBinding"))
        #expect(skillsSource.contains("self.clawHubStore.send(.searchRequested)"))
        #expect(source.contains("case searchFinished(SearchResults)"))
        #expect(skillsSource.contains("self.clawHubStore.send(.searchFinished(.init(results: results)))"))
        #expect(skillsSource.contains("self.clawHubStore.send(.installRequested(.init(slug: result.slug)))"))
        #expect(skillsSource.contains("text: self.skillFilterBinding"))
        #expect(skillsSource.contains("selection: self.skillStatusFilterBinding"))
        #expect(skillsSource.contains("self.skillFilterStore.send(.clearSearchTapped)"))
        #expect(skillsSource.contains("self.skillPolicyMutationStore.send(.mutationStarted(.init(key: busyKey)))"))
        #expect(skillsSource.contains("self.skillPolicyMutationStore.send(.mutationFinished(.init(key: busyKey)))"))
        #expect(skillsSource.contains("self.skillPolicyMutationStore.send(.mutationSucceeded(.init("))
        #expect(skillsSource.contains("self.skillPolicyMutationStore.send(.mutationFailed(.init("))
        #expect(skillsSource.contains("self.skillEditorStore.send(.editorOpened(.init(id: skill.effectiveSkillKey)))"))
        #expect(skillsSource.contains("self.skillEditorStore.send(.apiKeyDraftChanged(.init("))
        #expect(skillsSource.contains("self.skillEditorStore.send(.apiKeyDraftCleared(.init("))
        #expect(skillsSource.contains("self.skillEditorStore.send(.mutationStarted(.init(key: key)))"))
        #expect(
            skillsSource.contains(
                "self.skillEditorStore.send(.mutationSucceeded(.init(key: key, message: message)))"))
        #expect(skillsSource.contains("self.skillEditorStore.send(.mutationFinished(.init(key: key)))"))
        #expect(skillsSource.contains("self.skillEditorStore.send(.mutationFailed(.init("))
        #expect(cronSource.contains("self.cronActionStore.send(.actionStarted(.init(id: job.id)))"))
        #expect(cronSource.contains("self.cronActionStore.send(.actionSucceeded(.init(message: success)))"))
        #expect(cronSource.contains("self.cronActionStore.send(.actionFinished(.init(id: job.id)))"))
        #expect(cronSource.contains("self.cronActionStore.send(.actionFailed(.init("))
        #expect(overviewSource.contains("selection: self.agentRosterFilterBinding"))
        #expect(overviewSource.contains("text: self.agentSearchTextBinding"))
        #expect(overviewSource.contains("self.filterStore.send(.clearFiltersTapped)"))
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
        #expect(dreamingSource.contains("self.store.send(.dreamDiaryDaySelected(.init(dayID: day.id)))"))
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
        #expect(source.contains("struct Failure: Equatable, Sendable { var message: String }"))
        #expect(feature.contains("case dreamActionResponse(DreamActionResponse)"))
        #expect(feature.contains("var result: Result<DreamActionSummary, AgentDreamingMaintenanceError>"))
        #expect(feature.contains("await send(.dreamActionResponse(.init(result: .success(summary))))"))
        #expect(feature.contains("state.statusText = summary.summary"))
        #expect(feature.contains("result: .failure(.failed(.init(message: error.localizedDescription)))"))
        #expect(feature.contains("switch response.result"))
        #expect(!feature.contains("Result<String, AgentDreamingMaintenanceError>"))
        #expect(!source.contains("async throws -> String"))
        #expect(source.contains("case failed(Failure)"))
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
        let talkSource = try String(contentsOf: Self.talkProTabSourceURL(), encoding: .utf8)
        let speakerphoneBinding = try Self.extract(
            talkSource,
            from: "private var talkSpeakerphoneBinding: Binding<Bool>",
            to: "private func handlePrimaryAction()")
        let talkActionFunctions = try Self.extract(
            talkSource,
            from: "private func alignPersistedTalkState()",
            to: "private var permissionPromptBinding: Binding<Bool>")

        #expect(talkSource.contains("struct TalkProTabClient: Sendable"))
        #expect(talkSource.contains("var talkProTab: TalkProTabClient"))
        #expect(talkSource.contains("@Dependency(\\.talkProTab)"))
        #expect(talkSource.contains("struct GatewayConnectionChange: Equatable, Sendable"))
        #expect(talkSource.contains("struct SpeakerphoneEnabledChange: Equatable, Sendable"))
        #expect(talkSource.contains("struct StartTalkRequest: Equatable, Sendable"))
        #expect(talkSource.contains("struct TalkEnabledChange: Equatable, Sendable"))
        #expect(talkSource.contains("case gatewayConnectionChanged(GatewayConnectionChange)"))
        #expect(talkSource.contains("case speakerphoneEnabledChanged(SpeakerphoneEnabledChange)"))
        #expect(talkSource.contains("case startTalkRequested(StartTalkRequest)"))
        #expect(talkSource.contains("case talkEnabledChanged(TalkEnabledChange)"))
        #expect(talkSource.contains("await client.setSpeakerphoneEnabled(change.enabled)"))
        #expect(talkSource.contains("await client.startTalk(request.sessionKey)"))
        #expect(talkSource.contains("await client.setTalkEnabled(change.enabled)"))
        #expect(rootSource.contains("store: self.makeTalkProTabStore()"))
        #expect(storesSource.contains("func makeTalkProTabStore()"))
        #expect(storesSource.contains("TalkProTabFeature(client: .live(appModel: self.appModel))"))
        #expect(speakerphoneBinding.contains("self.talkSpeakerphoneEnabled = enabled"))
        #expect(speakerphoneBinding.contains("self.store.send(.speakerphoneEnabledChanged(.init(enabled: enabled)))"))
        #expect(!speakerphoneBinding.contains("self.appModel.setTalkSpeakerphoneEnabled"))
        #expect(talkActionFunctions.contains("self.store.send(.talkEnabledChanged(.init(enabled: self.talkEnabled)))"))
        #expect(talkActionFunctions
            .contains("self.store.send(.startTalkRequested(.init(sessionKey: self.appModel.chatSessionKey)))"))
        #expect(talkActionFunctions.contains("self.store.send(.talkEnabledChanged(.init(enabled: false)))"))
        #expect(!talkActionFunctions.contains("self.appModel.setTalkEnabled"))
    }

    @Test func `agent row selection is reducer effect owned`() throws {
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let agentSource = try String(contentsOf: Self.agentProTabSourceURL(), encoding: .utf8)
        let agentOverviewSource = try String(contentsOf: Self.agentProTabOverviewSourceURL(), encoding: .utf8)
        let phoneControlHubSource = try String(contentsOf: Self.phoneHubSourceURL(), encoding: .utf8)

        #expect(agentSource.contains("struct AgentSelectionClient: Sendable"))
        #expect(agentSource.contains("var agentSelection: AgentSelectionClient"))
        #expect(agentSource.contains("struct AgentSelectionFeature"))
        #expect(agentSource.contains("struct AgentSelection: Equatable, Sendable"))
        #expect(agentSource.contains("case agentSelected(AgentSelection)"))
        #expect(agentSource.contains("await selectionClient.setSelectedAgentId(selection.agentId)"))
        #expect(agentOverviewSource.contains("self.selectionStore.send(.agentSelected(.init(agentId: agent.id)))"))
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
        let chatSource = try String(contentsOf: Self.chatProTabSourceURL(), encoding: .utf8)

        #expect(chatSource.contains("struct ChatTalkControlClient: Sendable"))
        #expect(chatSource.contains("var chatTalkControl: ChatTalkControlClient"))
        #expect(chatSource.contains("struct ChatTalkControlFeature"))
        #expect(chatSource.contains("struct ToggleRequest: Equatable, Sendable"))
        #expect(chatSource.contains("case toggleRequested(ToggleRequest)"))
        #expect(chatSource.contains("await client.focusChatSession(request.sessionKey)"))
        #expect(chatSource.contains("await client.setTalkEnabled(!request.isTalkEnabled)"))
        #expect(chatSource.contains("self.talkControlStore.send(.toggleRequested(.init("))
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
        #expect(featureSource.contains("var rootCanvasDebugStatus: RootCanvasDebugStatusClient"))
        #expect(featureSource.contains("@Reducer\nstruct RootCanvasDebugStatusFeature"))
        #expect(featureSource.contains("extension RootCanvasDebugStatusFeature.Snapshot"))
        #expect(featureSource.contains("init(appModel: NodeAppModel, isEnabled: Bool)"))
        #expect(featureSource.contains("gatewayDisplayStatusText: appModel.gatewayDisplayStatusText"))
        #expect(featureSource.contains("case snapshotChanged(Snapshot)"))
        #expect(featureSource.contains("await client.setDebugStatusEnabled(snapshot.isEnabled)"))
        #expect(featureSource.contains("await client.updateDebugStatus(title, subtitle)"))
        #expect(storesSource.contains("func makeCanvasDebugStatusStore()"))
        #expect(storesSource.contains("RootCanvasDebugStatusFeature(client: .live(appModel: self.appModel))"))
        #expect(rootSource.contains(".send(.snapshotChanged(self.makeCanvasDebugStatusSnapshot()))"))
        #expect(rootSource.contains("RootCanvasDebugStatusFeature.Snapshot(\n            appModel: self.appModel"))
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
        #expect(featureSource.contains("init(scenePhase: ScenePhase, preventSleep: Bool, talkModeEnabled: Bool)"))
        #expect(featureSource.contains("isSceneActive: scenePhase == .active"))
        #expect(featureSource.contains("case snapshotChanged(Snapshot)"))
        #expect(featureSource.contains("case disappeared"))
        #expect(featureSource.contains("try Task.checkCancellation()"))
        #expect(featureSource.contains("await client.setIdleTimerDisabled(isDisabled)"))
        #expect(featureSource.contains("return .cancel(id: CancelID.idleTimer)"))
        #expect(featureSource.contains(".cancellable(id: CancelID.idleTimer, cancelInFlight: true)"))
        #expect(rootSource.contains("@State private var idleTimerStore: StoreOf<RootIdleTimerFeature>"))
        #expect(rootSource.contains("RootIdleTimerFeature(client: .live)"))
        #expect(!rootSource.contains("Task { await self.applyIdleTimerSnapshot() }"))
        #expect(updateFunction.contains("self.idleTimerStore.send(.snapshotChanged(self.makeIdleTimerSnapshot()))"))
        #expect(rootSource.contains("RootIdleTimerFeature.Snapshot(\n            scenePhase: self.scenePhase"))
        #expect(!rootSource.contains("isSceneActive: self.scenePhase == .active"))
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
        #expect(launchSource.contains("case initialAppearanceRequested(InitialAppearanceRequest)"))
        #expect(rootSource.contains("RootLaunchFeature.InitialAppearanceRequest("))
        #expect(launchSource.contains("struct InitialChatSessionRequest: Equatable, Sendable"))
        #expect(launchSource.contains("case initialChatSessionRequested(InitialChatSessionRequest)"))
        #expect(rootSource.contains("RootLaunchFeature.InitialChatSessionRequest("))
        #expect(launchSource.contains("struct ApplyAppearanceCommand: Equatable, Sendable"))
        #expect(launchSource.contains("case applyAppearance(ApplyAppearanceCommand)"))
        #expect(launchSource.contains("struct FocusChatSessionCommand: Equatable, Sendable"))
        #expect(launchSource.contains("case focusChatSession(FocusChatSessionCommand)"))
        #expect(voiceWakeToastSource.contains("@Reducer\nstruct RootVoiceWakeToastFeature"))
        #expect(voiceWakeToastSource.contains("struct CommandTrigger: Equatable, Sendable"))
        #expect(voiceWakeToastSource.contains("case commandTriggered(CommandTrigger)"))
        #expect(rootSource.contains("RootVoiceWakeToastFeature.CommandTrigger(command: newValue)"))
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

        #expect(quickSetupSource.contains("struct GatewayQuickSetupConnectFailure: Equatable"))
        #expect(quickSetupSource.contains("var connect: @Sendable @MainActor"))
        #expect(quickSetupSource.contains("-> GatewayQuickSetupConnectFailure?"))
        #expect(quickSetupSource.contains("struct ConnectResponse: Equatable, Sendable"))
        #expect(quickSetupSource.contains("var failure: GatewayQuickSetupConnectFailure?"))
        #expect(quickSetupSource.contains("case connectResponse(ConnectResponse)"))
        #expect(quickSetupSource.contains("state.connectError = response.failure?.message"))
        #expect(quickSetupSource.contains("return error.map(GatewayQuickSetupConnectFailure.init(message:))"))
        #expect(quickSetupSource.contains("let failure = await client.connect(candidate)"))
        #expect(quickSetupSource.contains("await send(.connectResponse(.init(failure: failure)))"))
        #expect(!quickSetupSource.contains("async -> String?"))
        #expect(!quickSetupSource.contains("struct ConnectFailure:"))
        #expect(!quickSetupSource.contains("struct ConnectResponse: Equatable, Sendable { var error: String? }"))
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

        #expect(quickSetupSource.contains("struct GatewayProblemPrimaryAction: Equatable, Sendable"))
        #expect(quickSetupSource.contains("case gatewayProblemPrimaryActionTapped(GatewayProblemPrimaryAction)"))
        #expect(quickSetupSource.contains("action.problem.canTrustRotatedCertificate"))
        #expect(quickSetupSource.contains("let candidate = action.candidate"))
        #expect(quickSetupSource.contains("self.store.send(.gatewayProblemPrimaryActionTapped(.init("))
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
        #expect(source.contains("struct Failure: Equatable, Sendable { var message: String }"))
        #expect(source.contains("case failed(Failure)"))
        #expect(source.contains("private static func failure(for error: Error) -> IPadWorkboardError"))
        #expect(source.contains("result: .failure(Self.failure(for: error))"))
        #expect(!source.contains("case failed(String)"))
        #expect(!source.contains("@State private var selectedStatus"))
        #expect(!source.contains("@State private var selectedBoardID"))
        #expect(!source.contains("@State private var query"))
        #expect(!source.contains("@State private var presentedSheet"))
        #expect(!source.contains("@State private var cards"))
        #expect(!source.contains("@State private var statuses"))
        #expect(!source.contains("@State private var isLoading"))
        #expect(!source.contains("@State private var busyCardID"))
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
        #expect(source.contains(".disabled(self.store.isCreatingCard)"))
        #expect(!source.contains("Button(\"Create\")"))
        #expect(!source.contains("TextField(\"New card\""))
        #expect(!source.contains(".disabled(!self.canWrite || self.draftTitle"))
        #expect(createFunction
            .contains("self.store.send(.createRequested(.init(canRead: self.canRead, canWrite: self.canWrite))"))
        #expect(source.contains("struct CreateRequest: Equatable, Sendable"))
        #expect(source.contains("struct CreateResponse: Equatable, Sendable"))
        #expect(source.contains("case createRequested(CreateRequest)"))
        #expect(source.contains("case createResponse(CreateResponse)"))
        #expect(source.contains("struct BoardScopesResponse: Equatable, Sendable"))
        #expect(source.contains("case boardScopesResponse(BoardScopesResponse)"))
        #expect(source.contains("struct BoardScopeChange: Equatable, Sendable"))
        #expect(source.contains("case boardScopeChanged(BoardScopeChange)"))
        #expect(source.contains("struct ArchiveRequest: Equatable, Sendable"))
        #expect(source.contains("struct ArchiveResponse: Equatable, Sendable"))
        #expect(source.contains("case archiveRequested(ArchiveRequest)"))
        #expect(source.contains("case archiveResponse(ArchiveResponse)"))
        #expect(source.contains("self.store.send(.archiveRequested(.init(card: card, canWrite: self.canWrite))"))
        #expect(source.contains("struct DispatchRequest: Equatable, Sendable"))
        #expect(source.contains("struct DispatchResponse: Equatable, Sendable"))
        #expect(source.contains("case dispatchRequested(DispatchRequest)"))
        #expect(source.contains("case dispatchResponse(DispatchResponse)"))
        #expect(source.contains("self.store.send(.dispatchRequested(.init(canWrite: self.canWrite))"))
        #expect(source.contains("struct DraftNotesChange: Equatable, Sendable"))
        #expect(source.contains("struct DraftTitleChange: Equatable, Sendable"))
        #expect(source.contains("case draftNotesChanged(DraftNotesChange)"))
        #expect(source.contains("case draftTitleChanged(DraftTitleChange)"))
        #expect(source.contains("self.store.send(.draftNotesChanged(.init(notes: $0)))"))
        #expect(source.contains("self.store.send(.draftTitleChanged(.init(title: $0)))"))
        #expect(source.contains("struct MoveRequest: Equatable, Sendable"))
        #expect(source.contains("struct MoveResponse: Equatable, Sendable"))
        #expect(source.contains("case moveRequested(MoveRequest)"))
        #expect(source.contains("case moveResponse(MoveResponse)"))
        #expect(source.contains("self.store.send(.moveRequested(.init(card: card, status: status"))
        #expect(source.contains("struct QueryChange: Equatable, Sendable"))
        #expect(source.contains("case queryChanged(QueryChange)"))
        #expect(source.contains("self.store.send(.queryChanged(.init(query: $0)))"))
        #expect(source.contains("struct RefreshRequest: Equatable, Sendable"))
        #expect(source.contains("struct RefreshResponse: Equatable, Sendable"))
        #expect(source.contains("case refreshRequested(RefreshRequest)"))
        #expect(source.contains("case refreshResponse(RefreshResponse)"))
        #expect(source.contains("await self.store.send(.refreshRequested(.init("))
        #expect(source.contains("struct StatusChange: Equatable, Sendable"))
        #expect(source.contains("case statusChanged(StatusChange)"))
        #expect(source.contains("self.store.send(.statusChanged(.init(status: $0)))"))
    }

    @Test func `task scope controls send real gateway params`() throws {
        let source = try Self.iPadTaskFeatureScreensSource()
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let phoneSource = try String(contentsOf: Self.phoneHubSourceURL(), encoding: .utf8)

        #expect(source.contains("private var boardScopeMenu: some View"))
        #expect(source.contains("method: \"workboard.boards.list\""))
        #expect(source.contains("let boardID = state.selectedBoardParam"))
        #expect(source.contains("IPadWorkboardListParams(boardId: boardID)"))
        #expect(source.contains("boardId: state.selectedBoardParam"))
        #expect(source
            .matches(
                of: /method: "workboard\.cards\.dispatch"[\s\S]*?IPadWorkboardListParams\(boardId: boardID\)/)
            .count == 1)
        #expect(rootSource.contains("store: IPadWorkboardStoreFactory.live(appModel: self.appModel)"))
        #expect(phoneSource.contains("store: IPadWorkboardStoreFactory.live(appModel: self.appModel)"))
        #expect(source.contains("private var agentScopeMenu: some View"))
        #expect(source.contains("IPadSkillProposalListParams(agentId: agentID)"))
        #expect(source.contains("agentId: agentID"))
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
        #expect(source.contains("struct Failure: Equatable, Sendable { var message: String }"))
        #expect(source.contains("case failed(Failure)"))
        #expect(source.contains("private static func failure(for error: Error) -> IPadSkillWorkshopError"))
        #expect(source.contains("result: .failure(Self.failure(for: error))"))
        #expect(!source.contains("case failed(String)"))
        #expect(!source.contains("@State private var proposals"))
        #expect(!source.contains("@State private var selectedProposalID"))
        #expect(!source.contains("@State private var statusFilter"))
        #expect(!source.contains("@State private var query"))
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
        #expect(source.contains("self.store.send(.agentScopeChanged(.init(agentID: \"\")))"))
        #expect(source.contains("self.store.send(.agentScopeChanged(.init(agentID: option.id)))"))
        #expect(source.contains("self.store.send(.queryChanged(.init(query: $0)))"))
        #expect(source.contains("self.store.send(.statusFilterChanged(.init(filter: $0)))"))
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

        #expect(source.contains("struct RefreshResponse: Equatable, Sendable"))
        #expect(source.contains("case refreshResponse(RefreshResponse)"))
        #expect(source.contains("await send(.refreshResponse(.init(result: .success(sessions))))"))
        #expect(source.contains("switch response.result"))
    }

    @Test func `command sessions refresh response action is typed`() throws {
        let source = try String(contentsOf: Self.commandSessionsFeatureSourceURL(), encoding: .utf8)
        let feature = try Self.extract(
            source,
            from: "@Reducer\nstruct CommandSessionsFeature",
            to: "enum CommandSessionsStoreFactory")

        #expect(feature.contains("struct RefreshResponse: Equatable, Sendable"))
        #expect(feature.contains("case refreshResponse(RefreshResponse)"))
        #expect(feature.contains("await send(.refreshResponse(.init(result: .success(sessions))))"))
        #expect(feature.contains("switch response.result"))
    }

    @Test func `command center recent sessions refresh response action is typed`() throws {
        let source = try String(contentsOf: Self.commandSessionsFeatureSourceURL(), encoding: .utf8)
        let feature = try Self.extract(
            source,
            from: "@Reducer\nstruct CommandCenterRecentSessionsFeature",
            to: "private static func snapshot")

        #expect(feature.contains("struct RefreshResponse: Equatable, Sendable"))
        #expect(feature.contains("case refreshResponse(RefreshResponse)"))
        #expect(feature.contains("await send(.refreshResponse(.init(result: .success(snapshot))))"))
        #expect(feature.contains("switch response.result"))
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
        let settingsTabSource = try String(contentsOf: Self.settingsProTabSourceURL(), encoding: .utf8)
        let settingsSource = try String(contentsOf: Self.settingsProTabSectionsSourceURL(), encoding: .utf8)
        let notificationGuidanceSource = try String(
            contentsOf: Self.notificationPermissionGuidanceDialogSourceURL(),
            encoding: .utf8)

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
        #expect(navigationSource.contains("var presentedSheet: PresentedSheet?"))
        #expect(rootSource.contains(".sheet(item: self.presentedSheetBinding)"))
        #expect(rootSource
            .contains("private var presentedSheetBinding: Binding<RootPresentationFeature.PresentedSheet?>"))
        #expect(navigationSource.contains("struct PresentedSheetChange: Equatable, Sendable"))
        #expect(navigationSource.contains("case presentedSheetChanged(PresentedSheetChange)"))
        #expect(rootSource.contains(".presentedSheetChanged("))
        #expect(rootSource.contains("RootPresentationFeature.PresentedSheetChange(sheet: $0)"))
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
        #expect(rootSource.contains("private func makeStartupSnapshot("))
        #expect(rootSource.contains("RootPresentationFeature.StartupPresentationEvaluationRequest("))
        #expect(rootSource.contains("RootPresentationFeature.AutoOpenSettingsRequest(snapshot: startupSnapshot)"))
        #expect(navigationSource.contains("struct QuickSetupSnapshot: Equatable, Sendable"))
        #expect(navigationSource.contains("struct QuickSetupSnapshotChange: Equatable, Sendable"))
        #expect(navigationSource.contains("case quickSetupSnapshotChanged(QuickSetupSnapshotChange)"))
        #expect(navigationSource.contains("snapshot: RootPresentationFeature.QuickSetupSnapshot"))
        #expect(rootSource.contains(".quickSetupSnapshotChanged("))
        #expect(rootSource.contains("RootPresentationFeature.QuickSetupSnapshotChange("))
        #expect(navigationSource.contains("struct GatewaySetupRequest: Equatable, Sendable"))
        #expect(navigationSource.contains("case gatewaySetupRequestChanged(GatewaySetupRequest)"))
        #expect(rootSource.contains(".gatewaySetupRequestChanged(RootPresentationFeature.GatewaySetupRequest("))
        #expect(navigationSource.contains("struct LocalNetworkAccessRequest: Equatable, Sendable"))
        #expect(navigationSource.contains("case localNetworkAccessRequested(LocalNetworkAccessRequest)"))
        #expect(rootSource.contains(".localNetworkAccessRequested(RootPresentationFeature.LocalNetworkAccessRequest("))
        #expect(navigationSource.contains("struct LocalNetworkAccessCommand: Equatable, Sendable"))
        #expect(navigationSource.contains("case requestLocalNetworkAccess(LocalNetworkAccessCommand)"))
        #expect(navigationSource.contains(
            "case openGatewaySettingsAndRequestLocalNetworkAccess(LocalNetworkAccessCommand)"))
        #expect(navigationSource.contains("struct OnboardingVisibilityChange: Equatable, Sendable"))
        #expect(navigationSource.contains("case onboardingVisibilityChanged(OnboardingVisibilityChange)"))
        #expect(rootSource.contains(".onboardingVisibilityChanged(RootPresentationFeature.OnboardingVisibilityChange("))
        #expect(rootSource.matches(of: /SettingsProTab\(\s*initialRoute: self\.selectedSettingsRoute,/).count == 1)
        #expect(rootSource.contains(".id(self.settingsTabViewID)"))
        #expect(navigationSource.contains("struct LayoutModeResolution: Equatable, Sendable"))
        #expect(navigationSource.contains("case layoutModeResolved(LayoutModeResolution)"))
        #expect(rootSource.contains(".layoutModeResolved(RootSidebarFeature.LayoutModeResolution("))
        #expect(navigationSource.contains("struct VisibilityChange: Equatable, Sendable"))
        #expect(navigationSource.contains("case visibilityChanged(VisibilityChange)"))
        #expect(rootSource.contains(".visibilityChanged(RootSidebarFeature.VisibilityChange("))
        #expect(rootSource.contains("@State private var navigationStore: StoreOf<RootNavigationSelectionFeature>"))
        #expect(navigationSource.contains("struct RootNavigationSelectionFeature"))
        #expect(navigationSource.contains("state.selectedSettingsRouteRequestID &+= 1"))
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
        #expect(navigationSource.contains(
            "case notificationPermissionSettingsOpened(NotificationPermissionSettingsRequest)"))
        #expect(rootSource
            .contains("""
            .notificationPermissionSettingsOpened(
                        RootNavigationSelectionFeature.NotificationPermissionSettingsRequest(
            """))
        #expect(navigationSource.contains("struct PendingExecApprovalPromptChange: Equatable, Sendable"))
        #expect(navigationSource.contains("case pendingExecApprovalPromptChanged(PendingExecApprovalPromptChange)"))
        #expect(rootSource.contains(".pendingExecApprovalPromptChanged("))
        #expect(rootSource.contains(
            "RootNavigationSelectionFeature.PendingExecApprovalPromptChange(promptID: newValue)"))
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
        let notificationSource = try String(contentsOf: Self.settingsNotificationFeatureSourceURL(), encoding: .utf8)

        #expect(appSource.contains("PushEnrollmentConsent.disclosureAccepted"))
        #expect(appSource.contains("await Self.isNotificationAuthorizationAllowed()"))
        #expect(actionsSource.contains("self.pushEnrollmentConsentStore.send(.acceptDisclosure)"))
        #expect(actionsSource.contains("self.pushEnrollmentConsentStore.disclosureAccepted"))
        #expect(actionsSource.contains("self.registerForRemoteNotificationsIfEnrollmentReady()"))
        #expect(actionsSource.contains("self.notificationStore.send(.remoteRegistrationRequested(.init("))
        #expect(actionsSource.contains("UIApplication.shared.registerForRemoteNotifications()") == false)
        #expect(actionsSource.contains("guard self.notificationStore.status.allowsNotifications") == false)
        #expect(notificationSource.contains("struct SettingsNotificationRegistrationClient"))
        #expect(notificationSource.contains("struct RemoteRegistrationRequest: Equatable, Sendable"))
        #expect(notificationSource.contains("case remoteRegistrationRequested(RemoteRegistrationRequest)"))
        #expect(notificationSource.contains("await registrationClient.registerForRemoteNotifications()"))
        #expect(modelSource.contains("PushEnrollmentConsent.disclosureAccepted"))
        #expect(modelSource.contains("notifications_not_authorized"))
        #expect(modelSource.contains("enrollment_disclosure_not_accepted"))
    }

    @Test func `settings approvals sync action is typed`() throws {
        let settingsSource = try String(contentsOf: Self.settingsProTabSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)

        #expect(settingsSource.contains("struct ApprovalsSync: Equatable, Sendable"))
        #expect(settingsSource.contains("case approvalsSynced(ApprovalsSync)"))
        #expect(actionsSource.contains("self.approvalsStore.send(.approvalsSynced(.init("))
        #expect(!settingsSource.contains("case approvalsSynced(\n            isAppleReviewDemoModeEnabled: Bool"))
    }

    @Test func `gateway settings keeps pairing trust diagnostics and tailscale actions`() throws {
        let settingsSource = try String(contentsOf: Self.settingsProTabSourceURL(), encoding: .utf8)
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
        #expect(settingsSource.contains("struct ReconnectRequest: Equatable, Sendable"))
        #expect(settingsSource.contains("struct RotatedCertificateTrustRequest: Equatable, Sendable"))
        #expect(settingsSource.contains("case reconnectRequested(ReconnectRequest)"))
        #expect(settingsSource.contains("case rotatedCertificateTrustRequested(RotatedCertificateTrustRequest)"))
        #expect(settingsSource.contains("@Dependency(\\.settingsGatewayReconnect)"))
        #expect(settingsSource.contains("@Dependency(\\.settingsGatewayProblemTrust)"))
        #expect(settingsSource.contains("await reconnectClient.reconnect()"))
        #expect(settingsSource.contains("await send(.reconnectFinished)"))
        #expect(settingsSource.contains("await problemTrustClient.trustRotatedCertificate(request.problem)"))
        #expect(reconnectFunction.contains("self.gatewayActivityStore"))
        #expect(reconnectFunction.contains("let isAppleReviewDemoModeEnabled = self.appModel.isAppleReviewDemoModeEnabled"))
        #expect(reconnectFunction.contains(
            ".send(.reconnectRequested(.init(isAppleReviewDemoModeEnabled: isAppleReviewDemoModeEnabled)))"))
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
            .contains("isAppleReviewDemoModeEnabled: self.appModel.isAppleReviewDemoModeEnabled"))
        #expect(!problemReconnectFunction.contains("await self.gatewayController.connectLastKnown()"))
        #expect(actionsSource.contains("self.gatewayActivityStore"))
        #expect(actionsSource.contains("self.manualGatewayEndpointStore.send(.localNetworkAccessRequested("))
        #expect(gatewaySetupFeaturesSource
            .contains("state.preflightResult = .requestLocalNetworkAccess(.init(reason: \"settings_preflight\"))"))
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

        #expect(rootSource.contains("self.maybeRequestLocalNetworkAccess(reason: \"scene_active\")"))
        #expect(rootSource.contains("self.requestLocalNetworkAccess(reason: reason)"))
        #expect(rootSource.contains("self.makeSettingsManualGatewayEndpointStore()"))
        #expect(storesSource.contains("SettingsManualGatewayEndpointFeature("))
        #expect(storesSource.contains("localNetworkAccessClient: .live(gatewayController: self.gatewayController))"))
        #expect(rootSource.contains("self.handlePresentationCommand()"))
        #expect(rootSource.contains("self.presentationStore.send(.localNetworkAccessRequested("))
        #expect(rootSource.contains("self.presentationStore.send(.onboardingVisibilityChanged("))
        #expect(navigationSource.contains("reason: \"root_appear\""))
        #expect(navigationSource.contains("reason: \"gateway_setup_deeplink\""))
        #expect(navigationSource.contains("guard state.didEvaluateOnboarding else { return .none }"))
        #expect(navigationSource.contains("reason: \"onboarding_dismissed\""))
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
            .contains("self.photoImportStore.send(.qrMessageDetected(.init(message: self.detectQRCode(from: data))))"))
        #expect(onboardingSource.contains("self.handlePhotoImportResult()"))
        #expect(!onboardingSource.contains("GatewayConnectDeepLink.fromSetupInput(message)"))
        #expect(onboardingStateSource
            .contains("var pendingManualAuthOverride: GatewayConnectionController.ManualAuthOverride?"))
        #expect(onboardingStateSource.contains("case setupAuthApplied(SetupAuthApplication)"))
        #expect(onboardingStateSource.contains("struct OnboardingDiscoveryRestartFeature"))
        #expect(onboardingStateSource.contains("struct OnboardingQRPhotoImportFeature"))
        #expect(onboardingStateSource.contains("struct QRMessageDetection: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct AppleReviewSetupCode: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct Failure: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("case qrMessageDetected(QRMessageDetection)"))
        #expect(onboardingStateSource.contains("case appleReviewSetupCode(AppleReviewSetupCode)"))
        #expect(onboardingStateSource.contains("case failure(Failure)"))
        #expect(onboardingStateSource.contains("Self.importResult(message: detection.message)"))
        #expect(onboardingStateSource.contains(".appleReviewSetupCode(.init(code: message))"))
        #expect(onboardingStateSource.contains(".failure(.init(message: Self.invalidQRCodeMessage))"))
        #expect(!onboardingStateSource.contains("case appleReviewSetupCode(String)"))
        #expect(!onboardingStateSource.contains("case failure(String)"))
        #expect(onboardingStateSource.contains(".cancellable(id: CancelID.restart, cancelInFlight: true)"))
        #expect(actionsSource.contains("self.manualGatewayEndpointStore.send(.localNetworkAccessRequested("))
        #expect(gatewaySetupFeaturesSource
            .contains("state.preflightResult = .requestLocalNetworkAccess(.init(reason: \"settings_preflight\"))"))
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
        #expect(chatSource.contains("struct TransportModeRecord: Equatable, Sendable"))
        #expect(chatSource.contains("case transportModeRecorded(TransportModeRecord)"))
        #expect(chatSource
            .contains("self.viewModelLifecycleStore.send(.transportModeRecorded(.init(" +
                "transportModeID: transportModeID)))"))
        #expect(appModelSource.contains("return IOSGatewayChatTransport(gateway: self.operatorSession)"))
        #expect(settingsSectionsSource.contains("Connected services and message routing"))
        #expect(settingsSectionsSource.contains("SettingsChannelsStoreFactory.live(appModel: self.appModel)"))
        #expect(channelsSource.contains("@Reducer\nstruct SettingsChannelsFeature"))
        #expect(channelsSource.contains("struct Failure: Equatable, Sendable { var message: String }"))
        #expect(channelsSource.contains("struct RefreshRequest: Equatable, Sendable"))
        #expect(channelsSource.contains("struct RefreshResponse: Equatable, Sendable"))
        #expect(channelsSource.contains("struct OperationRequest: Equatable, Sendable"))
        #expect(channelsSource.contains("struct OperationResponse: Equatable, Sendable"))
        #expect(channelsSource.contains("case refreshRequested(RefreshRequest)"))
        #expect(channelsSource.contains("case refreshResponse(RefreshResponse)"))
        #expect(channelsSource.contains("case operationRequested(OperationRequest)"))
        #expect(channelsSource.contains("case operationResponse(OperationResponse)"))
        #expect(channelsSource.contains("case failed(Failure)"))
        #expect(channelsSource
            .contains("await send(.operationResponse(.init(result: .success(Self.entries(from: snapshot)))))"))
        #expect(channelsSource.contains("result: .failure(.failed(.init(message: Self.message(for: error))))"))
        #expect(channelsSource.contains("case let .operationResponse(response):"))
        #expect(!channelsSource.contains("case failed(String)"))
        #expect(channelsSource.contains("await self.store.send(.refreshRequested(.init("))
        #expect(channelsSource.contains("await self.store.send(.operationRequested(.init("))
        #expect(channelsSource.contains("\"clickclack\": SettingsChannelFallbackMetadata"))
        #expect(channelsSource.contains("label: \"ClickClack\""))
        #expect(channelsSource.contains("Self-hosted chat bot routing."))
    }

    @Test func `settings setup code apply result is reducer owned`() throws {
        let settingsSource = try String(contentsOf: Self.settingsProTabSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let supportSource = try String(contentsOf: Self.settingsProTabSupportSourceURL(), encoding: .utf8)
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let applyFunction = try Self.extract(
            actionsSource,
            from: "func applySetupCode() async -> Bool",
            to: "func applyGatewayLink")
        let setupLinkFeature = try Self.extract(
            settingsSource,
            from: "struct SettingsGatewaySetupLinkFeature",
            to: "struct SettingsGatewayCredentialsFeature")

        #expect(supportSource.contains("struct SettingsAppleReviewDemoClient"))
        #expect(supportSource.contains("var enter: @MainActor @Sendable () -> Void"))
        #expect(supportSource.contains("var settingsAppleReviewDemo: SettingsAppleReviewDemoClient"))
        #expect(settingsSource.contains("private let appleReviewDemoClientOverride: SettingsAppleReviewDemoClient?"))
        #expect(settingsSource.contains("@Dependency(\\.settingsAppleReviewDemo)"))
        #expect(settingsSource.contains("await appleReviewDemoClient.enter()"))
        #expect(settingsSource.contains("enum ApplyResult: Equatable, Sendable"))
        #expect(settingsSource.contains("struct AppleReviewDemo: Equatable, Sendable"))
        #expect(setupLinkFeature.contains("struct Failure: Equatable, Sendable"))
        #expect(settingsSource.contains("case appleReviewDemo(AppleReviewDemo)"))
        #expect(setupLinkFeature.contains("case failure(Failure)"))
        #expect(settingsSource.contains("case applyRequested"))
        #expect(settingsSource
            .contains("state.applyResult = .appleReviewDemo(.init(statusText: Self.appleReviewDemoStatusText))"))
        #expect(setupLinkFeature.contains("state.applyResult = .failure(.init(message:"))
        #expect(settingsSource.contains("state.applyResult = .gatewayLink(link)"))
        #expect(actionsSource.contains("await self.gatewaySetupLinkStore.send(.applyRequested).finish()"))
        #expect(actionsSource.contains("self.gatewaySetupLinkStore.send(.applyResultHandled)"))
        #expect(actionsSource.contains("case let .appleReviewDemo(demo):"))
        #expect(actionsSource.contains(
            "self.gatewaySetupStatusStore.send(.statusChanged(.init(statusText: demo.statusText))"))
        #expect(applyFunction.contains(
            "self.gatewaySetupStatusStore.send(.statusChanged(.init(statusText: failure.message)))"))
        #expect(!setupLinkFeature.contains("case failure(String)"))
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
        let settingsSource = try String(contentsOf: Self.settingsProTabSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let stagingFunction = try Self.extract(
            actionsSource,
            from: "func applyPendingGatewaySetupLinkIfNeeded()",
            to: "@discardableResult")

        #expect(settingsSource.contains("var setupLinkStatusText: String?"))
        #expect(settingsSource.contains("struct SetupLinkStage: Equatable, Sendable"))
        #expect(settingsSource.contains("case setupLinkStaged(SetupLinkStage)"))
        #expect(settingsSource.contains("case setupLinkStatusHandled"))
        #expect(settingsSource.contains("Self.setupLinkLoadedStatusText(link)"))
        #expect(settingsSource.contains("Setup link loaded for \\(link.host):\\(link.port)"))
        #expect(actionsSource.contains("self.gatewaySetupLinkStore.send(.setupLinkStaged(.init(link: link)))"))
        #expect(actionsSource.contains("self.gatewaySetupLinkStore.setupLinkStatusText"))
        #expect(actionsSource.contains("self.gatewaySetupLinkStore.send(.setupLinkStatusHandled)"))
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
        let settingsSource = try String(contentsOf: Self.settingsProTabSourceURL(), encoding: .utf8)
        let qrScannerSheet = try Self.extract(
            settingsSource,
            from: ".sheet(isPresented: self.qrScannerBinding)",
            to: ".sheet(isPresented: self.notificationRelayDisclosureBinding)")

        #expect(gatewaySetupFeaturesSource.contains("struct GatewayStatusSync: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct QRScannerError: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct SetupStatusChange: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("case gatewayStatusSynced(GatewayStatusSync)"))
        #expect(gatewaySetupFeaturesSource.contains("case qrScannerErrorReceived(QRScannerError)"))
        #expect(gatewaySetupFeaturesSource.contains("case statusChanged(SetupStatusChange)"))
        #expect(gatewaySetupFeaturesSource.contains("private static func qrScannerErrorStatusText(_ error: String)"))
        #expect(settingsSource.contains("struct QRScannerError: Equatable, Sendable"))
        #expect(settingsSource.contains("case qrScannerErrorReceived(QRScannerError)"))
        #expect(settingsSource.contains("state.scannerError = error.message"))
        #expect(qrScannerSheet.contains("self.presentationStore.send(.qrScannerErrorReceived(.init(message: error)))"))
        #expect(qrScannerSheet.contains("self.gatewaySetupStatusStore.send(.qrScannerErrorReceived(.init("))
        #expect(!qrScannerSheet.contains("Scanner error: \\(error)"))
    }

    @Test func `onboarding qr scanner errors are reducer owned`() throws {
        let onboardingSource = try String(contentsOf: Self.onboardingWizardSourceURL(), encoding: .utf8)
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)

        #expect(onboardingStateSource.contains("struct ScannerError: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct QRScannerError: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("case scannerErrorReceived(ScannerError)"))
        #expect(onboardingStateSource.contains("case qrScannerErrorReceived(QRScannerError)"))
        #expect(onboardingStateSource.contains("state.statusLine = \"Scanner error: \\(error.message)\""))
        #expect(onboardingStateSource.contains("state.scannerError = error.message"))
        #expect(onboardingSource.contains("self.statusStore.send(.scannerErrorReceived(.init(message: error)))"))
        #expect(onboardingSource.contains("self.presentationStore.send(.qrScannerErrorReceived(.init(message: error)))"))
        #expect(onboardingSource.contains("self.presentationStore.send(.qrScannerErrorReceived(.init(message: failure.message)))"))
    }

    @Test func `onboarding gateway snapshot action is typed`() throws {
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)

        #expect(onboardingStateSource.contains("struct GatewaySnapshotChange: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("case gatewaySnapshotChanged(GatewaySnapshotChange)"))
        #expect(onboardingStateSource.contains("state.gatewayServerName = snapshot.gatewayServerName"))
        #expect(onboardingStateSource.contains("state.hasSavedGatewayConnection = snapshot.hasSavedGatewayConnection"))
    }

    @Test func `onboarding completion mark action is typed`() throws {
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)

        #expect(onboardingStateSource.contains("struct CompletionMark: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("case markCompleted(CompletionMark)"))
        #expect(onboardingStateSource.contains("if let mode = mark.mode"))
    }

    @Test func `onboarding gateway connected action is typed`() throws {
        let onboardingSource = try String(contentsOf: Self.onboardingWizardSourceURL(), encoding: .utf8)
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)

        #expect(onboardingStateSource.contains("struct GatewayConnectionCompletion: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("case gatewayConnected(GatewayConnectionCompletion)"))
        #expect(onboardingStateSource.contains("if completion.markedCompleted"))
        #expect(onboardingSource.contains("self.statusStore.send(.gatewayConnected(.init("))
        #expect(onboardingSource.contains("markedCompleted: shouldMarkCompleted && selectedMode != nil"))
    }

    @Test func `onboarding automatic pairing resume action is typed`() throws {
        let onboardingSource = try String(contentsOf: Self.onboardingWizardSourceURL(), encoding: .utf8)
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)

        #expect(onboardingStateSource.contains("struct AutomaticPairingResumeRequest: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("case automaticPairingResumeRequested(AutomaticPairingResumeRequest)"))
        #expect(onboardingStateSource.contains("request.now.timeIntervalSince(last)"))
        #expect(onboardingStateSource.contains("state.lastPairingAutoResumeAttemptAt = request.now"))
        #expect(onboardingSource.contains(
            "self.statusStore.send(.automaticPairingResumeRequested(.init(now: Date())))"))
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
        let settingsSource = try String(contentsOf: Self.settingsProTabSourceURL(), encoding: .utf8)
        let settingsActionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let onboardingSource = try String(contentsOf: Self.onboardingWizardSourceURL(), encoding: .utf8)
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)

        #expect(settingsSource.contains("struct ScannedSetupCode: Equatable, Sendable"))
        #expect(settingsSource.contains("struct SetupCodeChange: Equatable, Sendable"))
        #expect(settingsSource.contains("struct SetupCodeSync: Equatable, Sendable"))
        #expect(settingsSource.contains("case scannedSetupCodeReceived(ScannedSetupCode)"))
        #expect(settingsSource.contains("case setupCodeChanged(SetupCodeChange)"))
        #expect(settingsSource.contains("case setupCodeSynced(SetupCodeSync)"))
        #expect(settingsSource
            .contains("state.applyResult = .appleReviewDemo(.init(statusText: Self.appleReviewDemoStatusText))"))
        #expect(settingsActionsSource.contains(
            "self.gatewaySetupLinkStore.send(.scannedSetupCodeReceived(.init(code: code)))"))
        #expect(settingsActionsSource.contains("guard case let .appleReviewDemo(demo)?"))
        #expect(onboardingStateSource.contains("struct ScannedSetupCode: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("case scannedSetupCodeReceived(ScannedSetupCode)"))
        #expect(onboardingStateSource.contains("AppleReviewDemoMode.isSetupCode(scan.code)"))
        #expect(onboardingSource.contains("self.setupCodeStore.send(.scannedSetupCodeReceived(.init(code: code)))"))
        #expect(!settingsActionsSource.contains("AppleReviewDemoMode.isSetupCode(code)"))
        #expect(!settingsActionsSource.contains("self.appModel.enterAppleReviewDemoMode()"))
        #expect(!settingsActionsSource.contains("\"Apple Review demo mode enabled.\""))
        #expect(!onboardingSource.contains("AppleReviewDemoMode.isSetupCode(code)"))
    }

    @Test func `scanner gateway link results are reducer owned`() throws {
        let settingsSource = try String(contentsOf: Self.settingsProTabSourceURL(), encoding: .utf8)
        let settingsActionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let onboardingSource = try String(contentsOf: Self.onboardingWizardSourceURL(), encoding: .utf8)
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)
        let handleFunction = try Self.extract(
            settingsActionsSource,
            from: "func handleScannedGatewayLink(_ link: GatewayConnectDeepLink)",
            to: "func handleScannedSetupCode")

        #expect(settingsSource.contains("struct ScannedGatewayLink: Equatable, Sendable"))
        #expect(settingsSource.contains("case scannedGatewayLinkReceived(ScannedGatewayLink)"))
        #expect(settingsSource.contains("var scannedGatewayLinkStatusText: String?"))
        #expect(settingsSource.contains("case scannedGatewayLinkStatusHandled"))
        #expect(settingsSource.contains("Self.scannedGatewayLinkStatusText(link)"))
        #expect(settingsSource.contains("state.applyResult = .gatewayLink(link)"))
        #expect(settingsActionsSource.contains(
            "self.gatewaySetupLinkStore.send(.scannedGatewayLinkReceived(.init(link: link)))"))
        #expect(settingsActionsSource.contains("self.gatewaySetupLinkStore.scannedGatewayLinkStatusText"))
        #expect(settingsActionsSource.contains("self.gatewaySetupLinkStore.send(.scannedGatewayLinkStatusHandled)"))
        #expect(onboardingStateSource.contains("struct ScannedGatewayLink: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("case scannedGatewayLinkReceived(ScannedGatewayLink)"))
        #expect(onboardingStateSource.contains("state.applyResult = .gatewayLink(scan.link)"))
        #expect(onboardingSource.contains("self.setupCodeStore.send(.scannedGatewayLinkReceived(.init(link: link)))"))
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

        #expect(gatewaySetupFeaturesSource.contains("enum ManualConnectionResult: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct Failure: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("case failure(Failure)"))
        #expect(gatewaySetupFeaturesSource.contains("struct EndpointSync: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct ManualGatewayEnabledChange: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct ManualGatewayHostChange: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct ManualGatewayTLSChange: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct SetupLinkApplication: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct ManualConnectionAttempt: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct GatewayPreflightRequest: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("struct LocalNetworkAccessRequest: Equatable, Sendable"))
        #expect(gatewaySetupFeaturesSource.contains("case endpointSynced(EndpointSync)"))
        #expect(gatewaySetupFeaturesSource.contains(
            "case manualGatewayEnabledChanged(ManualGatewayEnabledChange)"))
        #expect(gatewaySetupFeaturesSource.contains("case manualGatewayHostChanged(ManualGatewayHostChange)"))
        #expect(gatewaySetupFeaturesSource.contains("case manualGatewayTLSChanged(ManualGatewayTLSChange)"))
        #expect(gatewaySetupFeaturesSource.contains("case setupLinkApplied(SetupLinkApplication)"))
        #expect(gatewaySetupFeaturesSource.contains("case manualConnectionRequested(ManualConnectionAttempt)"))
        #expect(gatewaySetupFeaturesSource.contains("state.manualConnectionResult = .failure(.init(message:"))
        #expect(gatewaySetupFeaturesSource.contains("state.manualConnectionResult = .request(ManualConnectionRequest("))
        #expect(actionsSource.contains("self.manualGatewayEndpointStore.send(.endpointSynced(.init("))
        #expect(actionsSource.contains(
            "self.manualGatewayEndpointStore.send(.manualGatewayEnabledChanged(.init(isEnabled:"))
        #expect(actionsSource.contains(
            "self.manualGatewayEndpointStore.send(.manualGatewayHostChanged(.init(host:"))
        #expect(actionsSource.contains(
            "self.manualGatewayEndpointStore.send(.manualGatewayTLSChanged(.init(useTLS:"))
        #expect(actionsSource.contains("self.manualGatewayEndpointStore.send(.setupLinkApplied(.init("))
        #expect(actionsSource.contains("self.manualGatewayEndpointStore.send(.manualConnectionRequested(.init("))
        #expect(actionsSource.contains("self.manualGatewayEndpointStore.send(.manualConnectionResultHandled)"))
        #expect(actionsSource.contains("self.gatewaySetupStatusStore.send(.statusChanged(.init(statusText: failure.message)))"))
        #expect(!gatewaySetupFeaturesSource.contains("case failure(String)"))
        #expect(!actionsSource.contains("guard !host.isEmpty else"))
        #expect(!actionsSource.contains("guard self.manualPortIsValid else"))
    }

    @Test func `settings manual port resolution status is reducer owned`() throws {
        let settingsSource = try String(contentsOf: Self.settingsProTabSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
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
        #expect(settingsSource.contains("struct ManualGatewayPortResolutionRequest: Equatable, Sendable"))
        #expect(settingsSource.contains("struct ManualGatewayPortSync: Equatable, Sendable"))
        #expect(settingsSource.contains("struct ManualGatewayPortTextChange: Equatable, Sendable"))
        #expect(settingsSource.contains(
            "case manualGatewayPortResolutionRequested(ManualGatewayPortResolutionRequest)"))
        #expect(settingsSource.contains("case manualGatewayPortSynced(ManualGatewayPortSync)"))
        #expect(settingsSource.contains("case manualGatewayPortTextChanged(ManualGatewayPortTextChange)"))
        #expect(settingsSource.contains("state.manualGatewayPortResolutionResult = .failure(.init(message:"))
        #expect(actionsSource.contains("self.manualGatewayPortStore.send(.manualGatewayPortResolutionRequested(.init("))
        #expect(actionsSource.contains("self.manualGatewayPortStore.send(.manualGatewayPortSynced(.init(port:"))
        #expect(actionsSource.contains(
            "self.manualGatewayPortStore.send(.manualGatewayPortTextChanged(.init(text: $0))"))
        #expect(actionsSource.contains("self.manualGatewayPortStore.send(.manualGatewayPortResolutionResultHandled)"))
        #expect(resolveManualPortFunction.contains(
            "self.gatewaySetupStatusStore.send(.statusChanged(.init(statusText: failure.message)))"))
        #expect(applyFunction.contains("self.resolveManualPortForConnection(host: host)"))
        #expect(scannedConnectFunction.contains("self.resolveManualPortForConnection(host: host)"))
        #expect(!manualPortFeature.contains("case failure(String)"))
        #expect(!actionsSource.contains("func resolvedManualPort(host: String)"))
        #expect(!applyFunction.contains("Failed: invalid port"))
        #expect(!scannedConnectFunction.contains("Failed: invalid port"))
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
        #expect(gatewaySetupFeaturesSource.contains("case preflightRequested(GatewayPreflightRequest)"))
        #expect(gatewaySetupFeaturesSource.contains("struct SettingsLocalNetworkAccessClient"))
        #expect(gatewaySetupFeaturesSource.contains("case localNetworkAccessRequested(LocalNetworkAccessRequest)"))
        #expect(gatewaySetupFeaturesSource.contains("@Dependency(\\.settingsLocalNetworkAccess)"))
        #expect(gatewaySetupFeaturesSource.contains(
            "await localNetworkAccessClient.requestLocalNetworkAccess(request.reason)"))
        #expect(gatewaySetupFeaturesSource
            .contains("state.preflightResult = .requestLocalNetworkAccess(.init(reason: \"settings_preflight\"))"))
        #expect(actionsSource.contains("self.manualGatewayEndpointStore.send(.preflightRequested(.init("))
        #expect(actionsSource.contains("self.manualGatewayEndpointStore.send(.preflightResultHandled)"))
        #expect(actionsSource.contains("self.manualGatewayEndpointStore.send(.localNetworkAccessRequested(.init("))
        #expect(!actionsSource.contains("self.gatewayController.requestLocalNetworkAccess(reason: reason)"))
        #expect(!preflightFunction.contains("SettingsManualGatewayEndpointFeature.State.isTailnetHostOrIP"))
        #expect(!preflightFunction.contains("\"Tailscale is off on this device. Turn it on, then try again.\""))
        #expect(!preflightFunction.contains("requestLocalNetworkAccess(reason: \"settings_preflight\")"))
    }

    @Test func `settings setup auth derivation is reducer owned`() throws {
        let settingsSource = try String(contentsOf: Self.settingsProTabSourceURL(), encoding: .utf8)
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
        #expect(settingsSource.contains("setupAuthPersistenceClient.currentInstanceID()"))
        #expect(settingsSource.contains("await setupAuthPersistenceClient.prepareForBootstrapPairing(request.instanceId)"))
        #expect(settingsSource.contains("await setupAuthPersistenceClient.saveSetupAuth(request)"))
        #expect(supportSource.contains("struct SettingsGatewaySetupAuthPersistenceClient"))
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
        let settingsSource = try String(contentsOf: Self.settingsProTabSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let supportSource = try String(contentsOf: Self.settingsProTabSupportSourceURL(), encoding: .utf8)
        let updateCredentialsFunction = try Self.extract(
            actionsSource,
            from: "func updateGatewayToken(_ value: String)",
            to: "var manualPortIsValid")

        #expect(supportSource.contains("struct SettingsGatewayCredentialsPersistenceClient"))
        #expect(settingsSource.contains("struct ManualCredentialChange: Equatable, Sendable"))
        #expect(settingsSource.contains("struct ManualCredentialPersistenceRequest: Equatable, Sendable"))
        #expect(settingsSource.contains("case gatewayTokenChanged(ManualCredentialChange)"))
        #expect(settingsSource.contains("case gatewayPasswordChanged(ManualCredentialChange)"))
        #expect(settingsSource.contains("case gatewayTokenPersistenceRequested(ManualCredentialPersistenceRequest)"))
        #expect(settingsSource.contains("case gatewayPasswordPersistenceRequested(ManualCredentialPersistenceRequest)"))
        #expect(settingsSource.contains("await persistenceClient.saveGatewayToken("))
        #expect(settingsSource.contains("await persistenceClient.saveGatewayPassword("))
        #expect(settingsSource.contains("manualCredentialPersistenceRequest("))
        #expect(actionsSource.contains("self.gatewayCredentialsStore.send(.gatewayTokenPersistenceRequested(.init("))
        #expect(actionsSource.contains("self.gatewayCredentialsStore.send(.gatewayPasswordPersistenceRequested(.init("))
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
        #expect(supportSource.contains("GatewaySettingsStore.savePreferredGatewayStableID(stableID)"))
        #expect(supportSource.contains("GatewaySettingsStore.saveLastDiscoveredGatewayStableID(stableID)"))
        #expect(connectionSource.contains("struct ConnectionStart: Equatable, Sendable"))
        #expect(connectionSource.contains("struct DiscoveredGatewayPersistenceRequest: Equatable, Sendable"))
        #expect(connectionSource.contains("case discoveredGatewayPersistenceRequested(DiscoveredGatewayPersistenceRequest)"))
        #expect(connectionSource.contains("@Dependency(\\.settingsDiscoveredGatewayPersistence)"))
        #expect(connectionSource.contains("await persistenceClient.saveSelectedGatewayStableID(trimmedStableID)"))
        #expect(actionsSource.contains("self.gatewayConnectionStore.send(.connectionStarted(.init(gatewayID:"))
        #expect(actionsSource.contains("self.gatewayConnectionStore.send(.discoveredGatewayPersistenceRequested(.init("))
        #expect(connectFunction.contains("GatewaySettingsStore.savePreferredGatewayStableID") == false)
        #expect(connectFunction.contains("GatewaySettingsStore.saveLastDiscoveredGatewayStableID") == false)
    }

    @Test func `settings gateway connection status sync action is typed`() throws {
        let connectionSource = try String(contentsOf: Self.settingsGatewayConnectionFeatureSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)

        #expect(connectionSource.contains("struct GatewayStatusSync: Equatable, Sendable"))
        #expect(connectionSource.contains("case gatewayStatusSynced(GatewayStatusSync)"))
        #expect(actionsSource.contains("self.gatewayConnectionStore.send(.gatewayStatusSynced(.init("))
        #expect(!connectionSource.contains("case gatewayStatusSynced(\n            isAppleReviewDemoModeEnabled: Bool"))
    }

    @Test func `settings share instruction persistence is reducer owned`() throws {
        let settingsSource = try String(contentsOf: Self.settingsProTabSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let supportSource = try String(contentsOf: Self.settingsProTabSupportSourceURL(), encoding: .utf8)
        let syncSettingsFunction = try Self.extract(
            actionsSource,
            from: "func syncSettingsState()",
            to: "func syncVoiceControlState()")

        #expect(supportSource.contains("struct SettingsShareInstructionPersistenceClient"))
        #expect(supportSource.contains("ShareToAgentSettings.loadDefaultInstruction()"))
        #expect(supportSource.contains("ShareToAgentSettings.saveDefaultInstruction(value)"))
        #expect(settingsSource.contains("@Dependency(\\.settingsShareInstructionPersistence)"))
        #expect(settingsSource.contains("struct DefaultShareInstructionChange: Equatable, Sendable"))
        #expect(settingsSource.contains("struct DefaultShareInstructionPersistenceRequest: Equatable, Sendable"))
        #expect(settingsSource.contains("case defaultShareInstructionLoadRequested"))
        #expect(settingsSource.contains(
            "case defaultShareInstructionPersistenceRequested(DefaultShareInstructionPersistenceRequest)"))
        #expect(settingsSource.contains("persistenceClient.loadDefaultInstruction()"))
        #expect(settingsSource.contains("await persistenceClient.saveDefaultInstruction(request.value)"))
        #expect(actionsSource.contains("self.shareInstructionStore.send(.defaultShareInstructionLoadRequested)"))
        #expect(syncSettingsFunction.contains("ShareToAgentSettings.loadDefaultInstruction") == false)
        #expect(settingsSource.contains("ShareToAgentSettings.saveDefaultInstruction") == false)
        #expect(settingsSource.contains("defaultShareInstructionLoaded(") == false)
    }

    @Test func `settings credential loading is reducer owned`() throws {
        let settingsSource = try String(contentsOf: Self.settingsProTabSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let supportSource = try String(contentsOf: Self.settingsProTabSupportSourceURL(), encoding: .utf8)
        let syncSettingsFunction = try Self.extract(
            actionsSource,
            from: "func syncSettingsState()",
            to: "func syncVoiceControlState()")

        #expect(supportSource.contains("GatewaySettingsStore.loadGatewayToken(instanceId: instanceId)"))
        #expect(supportSource.contains("GatewaySettingsStore.loadGatewayPassword(instanceId: instanceId)"))
        #expect(settingsSource.contains("struct CredentialsLoadRequest: Equatable, Sendable"))
        #expect(settingsSource.contains("struct LoadedCredentials: Equatable, Sendable"))
        #expect(settingsSource.contains("case credentialsLoadRequested(CredentialsLoadRequest)"))
        #expect(settingsSource.contains("case credentialsLoaded(LoadedCredentials)"))
        #expect(settingsSource.contains("persistenceClient.loadGatewayToken(trimmedInstanceId)"))
        #expect(settingsSource.contains("persistenceClient.loadGatewayPassword(trimmedInstanceId)"))
        #expect(settingsSource.contains("trimmedInstanceId(_ instanceId: String) -> String?"))
        #expect(actionsSource.contains("self.gatewayCredentialsStore.send(.credentialsLoadRequested(.init("))
        #expect(syncSettingsFunction.contains("GatewaySettingsStore.loadGatewayToken") == false)
        #expect(syncSettingsFunction.contains("GatewaySettingsStore.loadGatewayPassword") == false)
        #expect(syncSettingsFunction.contains("credentialsLoaded(") == false)
    }

    @Test func `onboarding setup code apply result is reducer owned`() throws {
        let onboardingSource = try String(contentsOf: Self.onboardingWizardSourceURL(), encoding: .utf8)
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)

        #expect(onboardingStateSource.contains("struct ManualCredentialChange: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct LoadedCredentials: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct SetupAuthApplication: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct SetupCodeChange: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct ScannedSetupCode: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct ScannedGatewayLink: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("case credentialsLoaded(LoadedCredentials)"))
        #expect(onboardingStateSource.contains("case gatewayTokenChanged(ManualCredentialChange)"))
        #expect(onboardingStateSource.contains("case gatewayPasswordChanged(ManualCredentialChange)"))
        #expect(onboardingStateSource.contains("case setupAuthApplied(SetupAuthApplication)"))
        #expect(onboardingStateSource.contains("case setupCodeChanged(SetupCodeChange)"))
        #expect(onboardingStateSource.contains("case scannedSetupCodeReceived(ScannedSetupCode)"))
        #expect(onboardingStateSource.contains("case scannedGatewayLinkReceived(ScannedGatewayLink)"))
        #expect(onboardingStateSource.contains("struct AppleReviewDemoSetupCode: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("state.gatewayToken = credentials.token"))
        #expect(onboardingStateSource.contains("state.gatewayToken = application.setupAuth.token"))
        #expect(onboardingSource.contains("self.credentialsStore.send(.credentialsLoaded(.init("))
        #expect(onboardingSource.contains("self.credentialsStore.send(.setupAuthApplied(.init(setupAuth: setupAuth)))"))
        #expect(onboardingSource.contains("self.credentialsStore.send(.gatewayTokenChanged(.init(value: $0)))"))
        #expect(onboardingSource.contains("self.credentialsStore.send(.gatewayPasswordChanged(.init(value: $0)))"))
        #expect(onboardingSource.contains("self.setupCodeStore.send(.setupCodeChanged(.init(code: $0)))"))
        #expect(onboardingStateSource.contains("enum ApplyResult: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("case appleReviewDemoSetupCode(AppleReviewDemoSetupCode)"))
        #expect(onboardingStateSource.contains("case applyRequested"))
        #expect(onboardingStateSource.contains("state.applyResult = .appleReviewDemoSetupCode(.init(code: raw))"))
        #expect(onboardingStateSource.contains("state.applyResult = .gatewayLink(link)"))
        #expect(onboardingSource.contains("self.setupCodeStore.send(.applyRequested)"))
        #expect(onboardingSource.contains("self.setupCodeStore.send(.applyResultHandled)"))
        #expect(!onboardingStateSource.contains("case appleReviewDemoSetupCode(String)"))
        #expect(!onboardingSource.contains("let raw = self.setupCodeStore.trimmedSetupCode"))
        #expect(!onboardingSource.contains("GatewayConnectDeepLink.fromSetupInput(raw)"))
        #expect(!onboardingSource.contains("AppleReviewDemoMode.isSetupCode(raw)"))
    }

    @Test func `onboarding manual connection request is reducer owned`() throws {
        let onboardingSource = try String(contentsOf: Self.onboardingWizardSourceURL(), encoding: .utf8)
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)

        #expect(onboardingStateSource.contains("struct Initialization: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct GatewayLinkApplication: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("case initialized(Initialization)"))
        #expect(onboardingStateSource.contains("case gatewayLinkApplied(GatewayLinkApplication)"))
        #expect(onboardingStateSource.contains("state.manualHost = initialization.host"))
        #expect(onboardingStateSource.contains("state.manualHost = application.host"))
        #expect(onboardingSource.contains("self.connectionFormStore.send(.initialized(.init("))
        #expect(onboardingSource.contains("self.connectionFormStore.send(.gatewayLinkApplied(.init("))
        #expect(onboardingStateSource.contains("struct ManualConnectionRequest: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct ManualHostChange: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct ManualPortTextChange: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct ManualTLSChange: Equatable, Sendable"))
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
        #expect(onboardingSource.contains("self.connectionFormStore.send(.manualConnectionRequested)"))
        #expect(onboardingSource.contains("self.connectionFormStore.send(.manualConnectionRequestHandled)"))
        #expect(onboardingSource.contains("self.connectionFormStore.send(.modeSelected(.init(mode: mode)))"))
        #expect(onboardingSource.contains("self.connectionFormStore.send(.selectedModeChanged(.init(mode:"))
        #expect(onboardingSource.contains("self.connectionFormStore.send(.manualHostChanged(.init(host: $0)))"))
        #expect(onboardingSource.contains("self.connectionFormStore.send(.manualPortTextChanged(.init(text: $0)))"))
        #expect(onboardingSource.contains("self.connectionFormStore.send(.manualTLSChanged(.init(useTLS: $0)))"))
        #expect(!onboardingSource.contains("let host = self.connectionFormStore.normalizedManualHost"))
        #expect(!onboardingSource.contains("guard !host.isEmpty, self.manualPort > 0, self.manualPort <= 65535"))
    }

    @Test func `onboarding connection start action is typed`() throws {
        let onboardingSource = try String(contentsOf: Self.onboardingWizardSourceURL(), encoding: .utf8)
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)

        #expect(onboardingStateSource.contains("struct ConnectionStart: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("struct ConnectionActivityStart: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("case connectionStarted(ConnectionStart)"))
        #expect(onboardingStateSource.contains("case connectionActivityStarted(ConnectionActivityStart)"))
        #expect(onboardingStateSource.contains("state.connectingGatewayID = start.id"))
        #expect(onboardingStateSource.contains("if start.clearsIssue"))
        #expect(onboardingSource.contains("self.statusStore.send(.connectionStarted(.init("))
        #expect(onboardingSource.contains("self.statusStore.send(.connectionActivityStarted(.init(id: connectionID)))"))
    }

    @Test func `onboarding connection status action is typed`() throws {
        let onboardingSource = try String(contentsOf: Self.onboardingWizardSourceURL(), encoding: .utf8)
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)

        #expect(onboardingStateSource.contains("struct ConnectionStatusUpdate: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("case connectionStatusUpdated(ConnectionStatusUpdate)"))
        #expect(onboardingStateSource.contains("state.connectMessage = update.message"))
        #expect(onboardingStateSource.contains("state.statusLine = update.statusLine"))
        #expect(onboardingSource.contains("self.statusStore.send(.connectionStatusUpdated(.init("))
    }

    @Test func `onboarding connection issue action is typed`() throws {
        let onboardingSource = try String(contentsOf: Self.onboardingWizardSourceURL(), encoding: .utf8)
        let onboardingStateSource = try String(contentsOf: Self.onboardingStateStoreSourceURL(), encoding: .utf8)

        #expect(onboardingStateSource.contains("struct ConnectionIssueDetection: Equatable, Sendable"))
        #expect(onboardingStateSource.contains("case connectionIssueDetected(ConnectionIssueDetection)"))
        #expect(onboardingStateSource.contains("detected: detection.issue"))
        #expect(onboardingStateSource.contains("detection.pauseReconnect"))
        #expect(onboardingStateSource.contains("detection.statusText.trimmingCharacters"))
        #expect(onboardingSource.contains("self.statusStore.send(.connectionIssueDetected(.init("))
    }

    @Test func `settings onboarding reset is reducer effect owned`() throws {
        let settingsSource = try String(contentsOf: Self.settingsProTabSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let supportSource = try String(contentsOf: Self.settingsProTabSupportSourceURL(), encoding: .utf8)
        let resetFunction = try Self.extract(
            actionsSource,
            from: "func resetOnboarding() async",
            to: "func retryGatewayConnectionFromProblem()")

        #expect(settingsSource.contains("struct OnboardingRequestIDChange: Equatable, Sendable"))
        #expect(settingsSource.contains("struct OnboardingResetRequest: Equatable, Sendable"))
        #expect(settingsSource.contains("struct OnboardingStateSync: Equatable, Sendable"))
        #expect(settingsSource.contains("case onboardingRequestIDChanged(OnboardingRequestIDChange)"))
        #expect(settingsSource.contains("case onboardingResetRequested(OnboardingResetRequest)"))
        #expect(settingsSource.contains("case onboardingStateSynced(OnboardingStateSync)"))
        #expect(settingsSource.contains("@Dependency(\\.settingsOnboardingReset)"))
        #expect(settingsSource.contains("state.onboardingRequestID += 1"))
        #expect(settingsSource.contains("await resetClient.reset(request.instanceId)"))
        #expect(supportSource.contains("struct SettingsOnboardingResetClient"))
        #expect(supportSource.contains("GatewayOnboardingReset.reset(appModel: appModel, instanceId: instanceId)"))
        #expect(rootSource.contains("self.makeSettingsOnboardingStateStore()"))
        #expect(storesSource.contains("SettingsOnboardingStateFeature(resetClient: .live(appModel: self.appModel))"))
        #expect(actionsSource.contains(".send(.onboardingResetRequested(.init(instanceId: self.instanceId)))"))
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
        let settingsSource = try String(contentsOf: Self.settingsProTabSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let oldTalkToggleGuard = "func updateTalkEnabled(_ enabled: Bool) {\n"
            + "        guard !self.appModel.isAppleReviewDemoModeEnabled else"

        #expect(settingsSource.contains("struct TalkEnabledChangeRequest: Equatable, Sendable"))
        #expect(settingsSource.contains("case talkEnabledChangeRequested(TalkEnabledChangeRequest)"))
        #expect(settingsSource
            .contains("let talkEnabled = request.isAppleReviewDemoModeEnabled ? false : request.enabled"))
        #expect(settingsSource.contains("state.talkEnabled = talkEnabled"))
        #expect(actionsSource.contains("self.voiceControlStore.send(.talkEnabledChangeRequested(.init("))
        #expect(actionsSource.contains("self.storedTalkEnabled = self.voiceControlStore.talkEnabled"))
        #expect(actionsSource.contains(oldTalkToggleGuard) == false)
    }

    @Test func `settings voice control persistence is reducer effect owned`() throws {
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let settingsSource = try String(contentsOf: Self.settingsProTabSourceURL(), encoding: .utf8)
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
        #expect(settingsSource.contains("struct TalkEnabledChange: Equatable, Sendable"))
        #expect(settingsSource.contains("struct VoiceControlSync: Equatable, Sendable"))
        #expect(settingsSource.contains("struct VoiceWakeEnabledChange: Equatable, Sendable"))
        #expect(settingsSource.contains("case controlsSynced(VoiceControlSync)"))
        #expect(settingsSource.contains("case talkEnabledChanged(TalkEnabledChange)"))
        #expect(settingsSource.contains("case voiceWakeEnabledChanged(VoiceWakeEnabledChange)"))
        #expect(settingsSource.contains("@Dependency(\\.settingsVoiceControl)"))
        #expect(settingsSource.contains("await voiceControlClient.setTalkEnabled(talkEnabled)"))
        #expect(settingsSource.contains("await voiceControlClient.setVoiceWakeEnabled(change.enabled)"))
        #expect(rootSource.contains("voiceControlStore: self.makeSettingsVoiceControlStore()"))
        #expect(storesSource.contains("func makeSettingsVoiceControlStore()"))
        #expect(storesSource.contains("voiceControlClient: .live(appModel: self.appModel)"))
        #expect(updateTalkFunction.contains("self.voiceControlStore.send(.talkEnabledChangeRequested(.init("))
        #expect(updateTalkFunction.contains("self.storedTalkEnabled = self.voiceControlStore.talkEnabled"))
        #expect(!updateTalkFunction.contains("self.appModel.setTalkEnabled"))
        #expect(updateVoiceWakeFunction.contains(
            "self.voiceControlStore.send(.voiceWakeEnabledChanged(.init(enabled: enabled)))"))
        #expect(updateVoiceWakeFunction.contains("self.storedVoiceWakeEnabled = enabled"))
        #expect(!updateVoiceWakeFunction.contains("self.appModel.setVoiceWakeEnabled"))
    }

    @Test func `settings talk preference persistence is reducer effect owned`() throws {
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let settingsSource = try String(contentsOf: Self.settingsProTabSourceURL(), encoding: .utf8)
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
        let updateSpeakerphoneFunction = try Self.extract(
            actionsSource,
            from: "func updateTalkSpeakerphoneEnabled(_ enabled: Bool)",
            to: "var talkApiKeyStatus")

        #expect(preferencesSource.contains("struct SettingsTalkPreferencesClient: Sendable"))
        #expect(preferencesSource.contains("var settingsTalkPreferences: SettingsTalkPreferencesClient"))
        #expect(preferencesSource.contains("@Dependency(\\.settingsTalkPreferences)"))
        #expect(preferencesSource.contains("struct ProviderSelectionChange: Equatable, Sendable"))
        #expect(preferencesSource.contains("struct RealtimeVoiceSelectionChange: Equatable, Sendable"))
        #expect(preferencesSource.contains("struct TalkSpeakerphoneEnabledChange: Equatable, Sendable"))
        #expect(preferencesSource.contains("struct GatewayTalkConfigSync: Equatable, Sendable"))
        #expect(preferencesSource.contains("struct GatewayTalkDisplayContextSync: Equatable, Sendable"))
        #expect(preferencesSource.contains("struct GatewayTalkRuntimeSync: Equatable, Sendable"))
        #expect(preferencesSource.contains("struct PreferencesSync: Equatable, Sendable"))
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
        #expect(updateProviderFunction
            .contains("self.talkPreferencesStore.send(.providerSelectionChanged(.init(rawValue: rawValue)))"))
        #expect(updateProviderFunction.contains("self.storedTalkProviderSelectionRaw = selection.rawValue"))
        #expect(!updateProviderFunction.contains("self.appModel.setTalkProviderSelection"))
        #expect(updateRealtimeVoiceFunction
            .contains("self.talkPreferencesStore.send(.realtimeVoiceSelectionChanged(.init(rawValue: rawValue)))"))
        #expect(updateRealtimeVoiceFunction.contains("self.storedTalkRealtimeVoiceSelectionRaw = voice"))
        #expect(!updateRealtimeVoiceFunction.contains("self.appModel.setTalkRealtimeVoiceSelection"))
        #expect(updateSpeakerphoneFunction
            .contains("self.talkPreferencesStore.send(.talkSpeakerphoneEnabledChanged(.init(isEnabled: enabled)))"))
        #expect(updateSpeakerphoneFunction.contains("self.storedTalkSpeakerphoneEnabled = enabled"))
        #expect(!updateSpeakerphoneFunction.contains("self.appModel.setTalkSpeakerphoneEnabled"))
        #expect(actionsSource.contains("self.talkPreferencesStore.send(.preferencesSynced(.init("))
        #expect(actionsSource.contains("self.talkPreferencesStore.send(.gatewayTalkConfigSynced(.init("))
        #expect(actionsSource.contains("self.talkPreferencesStore.send(.gatewayTalkDisplayContextSynced(.init("))
        #expect(actionsSource.contains("self.talkPreferencesStore.send(.gatewayTalkRuntimeSynced(.init("))
        #expect(!preferencesSource.contains("case preferencesSynced(\n            providerSelectionRaw: String"))
        #expect(!preferencesSource.contains("case gatewayTalkConfigSynced(\n            configLoaded: Bool"))
    }

    @Test func `settings notification action decision is reducer owned`() throws {
        let notificationSource = try String(contentsOf: Self.settingsNotificationFeatureSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)

        #expect(notificationSource.contains("enum ActionRequest: Equatable, Sendable"))
        #expect(notificationSource.contains("struct RelayConfigSync: Equatable, Sendable"))
        #expect(notificationSource.contains("case actionButtonTapped"))
        #expect(notificationSource.contains("case actionRequestHandled"))
        #expect(notificationSource.contains("state.actionRequest = .openSettings"))
        #expect(notificationSource
            .contains(
                "state.actionRequest = state.usesOpenClawHostedRelay ? .showRelayDisclosure : .requestAuthorization"))
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
        let settingsSource = try String(contentsOf: Self.settingsProTabSourceURL(), encoding: .utf8)
        let requestFunction = try Self.extract(
            actionsSource,
            from: "func requestNotificationAuthorizationFromSettings()",
            to: "func handleNotificationAuthorizationResult")

        #expect(notificationSource.contains("struct SettingsNotificationAuthorizationClient"))
        #expect(notificationSource.contains("case authorizationRequestRequested"))
        #expect(notificationSource
            .contains("case authorizationRequestFinished(SettingsNotificationAuthorizationResult)"))
        #expect(notificationSource.contains("await authorizationClient.requestAuthorization()"))
        #expect(notificationSource.contains("return .run { send in"))
        #expect(actionsSource.contains("self.notificationStore.send(.authorizationRequestRequested)"))
        #expect(actionsSource.contains("self.notificationStore.send(.authorizationRequestResultHandled)"))
        #expect(settingsSource
            .contains("self.handleNotificationAuthorizationResult(result)"))
        #expect(requestFunction.contains("UNUserNotificationCenter.current().requestAuthorization") == false)
        #expect(requestFunction.contains("let granted = await") == false)
        #expect(requestFunction.contains("Task {") == false)
    }

    @Test func `settings notification status refresh is reducer effect owned`() throws {
        let notificationSource = try String(contentsOf: Self.settingsNotificationFeatureSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let settingsSource = try String(contentsOf: Self.settingsProTabSourceURL(), encoding: .utf8)
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
        let settingsSource = try String(contentsOf: Self.settingsProTabSourceURL(), encoding: .utf8)
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
        #expect(diagnosticsSource.contains("case diagnosticsContextSynced(DiagnosticsContextSync)"))
        #expect(diagnosticsSource.contains("case diagnosticsCompletionRequested(DiagnosticsCompletionRequest)"))
        #expect(supportSource.contains("struct SettingsGatewayDiagnosticsRefreshClient"))
        #expect(supportSource.contains("var settingsGatewayDiagnosticsRefresh: SettingsGatewayDiagnosticsRefreshClient"))
        #expect(settingsSource.contains("struct DiagnosticsRefreshRequest: Equatable, Sendable"))
        #expect(settingsSource.contains("case diagnosticsRefreshRequested(DiagnosticsRefreshRequest)"))
        #expect(settingsSource.contains("@Dependency(\\.settingsGatewayDiagnosticsRefresh)"))
        #expect(settingsSource.contains("await diagnosticsRefreshClient.refreshGateway()"))
        #expect(settingsSource.contains("await send(.refreshFinished)"))
        #expect(diagnosticsSource.contains("state.issueCount = SettingsDiagnostics.issueCount("))
        #expect(runDiagnosticsFunction.contains("self.gatewayActivityStore"))
        #expect(runDiagnosticsFunction
            .contains("let isAppleReviewDemoModeEnabled = self.appModel.isAppleReviewDemoModeEnabled"))
        #expect(runDiagnosticsFunction
            .contains(".send(.diagnosticsRefreshRequested(.init(" +
                "isAppleReviewDemoModeEnabled: isAppleReviewDemoModeEnabled)))"))
        #expect(actionsSource.contains("self.diagnosticsStore.send(.diagnosticsCompletionRequested(.init("))
        #expect(actionsSource.contains("self.diagnosticsStore.send(.diagnosticsContextSynced(.init("))
        #expect(!diagnosticsSource.contains("case diagnosticsCompletionRequested(\n            gatewayConnected: Bool"))
        #expect(!diagnosticsSource.contains("case diagnosticsContextSynced(\n" +
            "            isAppleReviewDemoModeEnabled: Bool"))
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
        let settingsSource = try String(contentsOf: Self.settingsProTabSourceURL(), encoding: .utf8)
        let requestFunction = try Self.extract(
            actionsSource,
            from: "func handleLocationModeRequest",
            to: "func handleLocationModeApplyResult")

        #expect(locationSource.contains("struct LocationModeRequest: Equatable, Sendable"))
        #expect(locationSource.contains("struct LocationModeChangeRequest: Equatable, Sendable"))
        #expect(locationSource.contains("case locationModeChangeRequested(LocationModeChangeRequest)"))
        #expect(locationSource.contains("guard let mode = OpenClawLocationMode(rawValue: rawValue) else"))
        #expect(locationSource.contains("state.locationModeRequest = LocationModeRequest("))
        #expect(settingsSource.contains("self.locationStore.send(.locationModeChangeRequested(.init(rawValue: newValue)))"))
        #expect(settingsSource.contains("self.handleLocationModeRequest(self.locationStore.locationModeRequest)"))
        #expect(actionsSource.contains("self.locationStore.send(.locationModeApplyRequested(request))"))
        #expect(requestFunction.contains("OpenClawLocationMode(rawValue:") == false)
        #expect(requestFunction.contains("previousLocationModeRaw") == false)
    }

    @Test func `settings location apply request is reducer effect owned`() throws {
        let locationSource = try String(contentsOf: Self.settingsLocationFeatureSourceURL(), encoding: .utf8)
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let settingsSource = try String(contentsOf: Self.settingsProTabSourceURL(), encoding: .utf8)
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
        #expect(locationSource.contains("await permissionClient.requestPermission(request.mode)"))
        #expect(locationSource.contains("await gatewayRefreshClient.refreshGatewayRegistration()"))
        #expect(locationSource.contains("return .run { send in"))
        #expect(settingsSource.contains(".onChange(of: self.locationStore.locationModeApplyResult)"))
        #expect(rootSource.contains("locationStore: self.makeSettingsLocationStore()"))
        #expect(storesSource.contains("func makeSettingsLocationStore()"))
        #expect(storesSource.contains("gatewayRefreshClient: .live(gatewayController: self.gatewayController)"))
        #expect(actionsSource.contains("self.locationStore.send(.locationModeApplyResultHandled)"))
        #expect(actionsSource.contains("if case let .denied(denied) = result"))
        #expect(actionsSource.contains("self.storedLocationModeRaw = denied.previousRawValue"))
        #expect(requestFunction.contains("Task {") == false)
        #expect(requestFunction.contains("requestLocationPermissions") == false)
        #expect(resultFunction.contains("requestLocationPermissions") == false)
        #expect(!resultFunction.contains("self.gatewayController.refreshActiveGatewayRegistrationFromSettings()"))
        #expect(actionsSource.contains("func applyLocationMode") == false)
    }

    @Test func `settings discovery debug logging is reducer effect owned`() throws {
        let actionsSource = try String(contentsOf: Self.settingsProTabActionsSourceURL(), encoding: .utf8)
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let settingsSource = try String(contentsOf: Self.settingsProTabSourceURL(), encoding: .utf8)
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
        #expect(settingsSource.contains("struct DebugOptionToggleChange: Equatable, Sendable"))
        #expect(settingsSource.contains("case discoveryDebugLogsChanged(DebugOptionToggleChange)"))
        #expect(settingsSource.contains("case canvasDebugStatusChanged(DebugOptionToggleChange)"))
        #expect(settingsSource.contains("@Dependency(\\.settingsDiscoveryDebugLogging)"))
        #expect(settingsSource.contains(
            "await discoveryDebugLoggingClient.setDiscoveryDebugLoggingEnabled(change.enabled)"))
        #expect(rootSource.contains("debugOptionsStore: self.makeSettingsDebugOptionsStore()"))
        #expect(storesSource.contains("func makeSettingsDebugOptionsStore()"))
        #expect(storesSource.contains("discoveryDebugLoggingClient: .live(gatewayController: self.gatewayController)"))
        #expect(updateFunction.contains(
            "self.debugOptionsStore.send(.discoveryDebugLogsChanged(.init(enabled: enabled)))"))
        #expect(!updateFunction.contains("self.gatewayController.setDiscoveryDebugLoggingEnabled(enabled)"))
        #expect(storedDebugChange.contains(
            "self.debugOptionsStore.send(.discoveryDebugLogsChanged(.init(enabled: newValue)))"))
        #expect(!storedDebugChange.contains("self.gatewayController.setDiscoveryDebugLoggingEnabled(newValue)"))
    }

    @Test func `settings agent selection persistence is reducer effect owned`() throws {
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let storesSource = try String(contentsOf: Self.rootTabsStoresSourceURL(), encoding: .utf8)
        let settingsSource = try String(contentsOf: Self.settingsProTabSourceURL(), encoding: .utf8)
        let agentSelectionBinding = try Self.extract(
            settingsSource,
            from: "var agentSelectionBinding: Binding<String>",
            to: "private var gatewayProblemDetailsBinding")
        let externalAgentSync = try Self.extract(
            settingsSource,
            from: ".onChange(of: self.appModel.selectedAgentId ?? \"\")",
            to: ".onChange(of: self.storedSetupCode)")

        #expect(settingsSource.contains("struct SettingsSelectedAgentClient: Sendable"))
        #expect(settingsSource.contains("var settingsSelectedAgent: SettingsSelectedAgentClient"))
        #expect(settingsSource.contains("struct PickerSelectionChange: Equatable, Sendable"))
        #expect(settingsSource.contains("struct SelectedAgentSync: Equatable, Sendable"))
        #expect(settingsSource.contains("case pickerSelectionChanged(PickerSelectionChange)"))
        #expect(settingsSource.contains("case selectedAgentSynced(SelectedAgentSync)"))
        #expect(settingsSource.contains("@Dependency(\\.settingsSelectedAgent)"))
        #expect(settingsSource.contains("await selectedAgentClient.setSelectedAgentId(selectedAgentId)"))
        #expect(rootSource.contains("agentSelectionStore: self.makeSettingsAgentSelectionStore()"))
        #expect(storesSource.contains("func makeSettingsAgentSelectionStore()"))
        #expect(storesSource.contains("selectedAgentClient: .live(appModel: self.appModel)"))
        #expect(agentSelectionBinding.contains(".pickerSelectionChanged(.init(selectedAgentPickerId: $0))"))
        #expect(!settingsSource.contains("self.appModel.setSelectedAgentId(trimmed.isEmpty ? nil : trimmed)"))
        #expect(externalAgentSync.contains(".selectedAgentSynced(.init(selectedAgentId: newValue))"))
        #expect(!externalAgentSync.contains(".pickerSelectionChanged"))
    }

    @Test func `home canvas payload state is reducer owned`() throws {
        let rootSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let featureSource = try String(contentsOf: Self.rootHomeCanvasSourceURL(), encoding: .utf8)

        #expect(featureSource.contains("@Reducer\nstruct RootHomeCanvasFeature"))
        #expect(featureSource.contains("struct Snapshot: Equatable, Sendable"))
        #expect(featureSource.contains("var payloadJSON: String?"))
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
        #expect(rootSource.contains("self.appModel.screen.updateHomeCanvasState(json: self.homeCanvasStore.payloadJSON)"))
        #expect(rootSource.contains("RootHomeCanvasFeature.Snapshot(appModel: self.appModel, gatewayStatus: self.gatewayStatus)"))
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
