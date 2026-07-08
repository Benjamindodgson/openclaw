import ComposableArchitecture
import Foundation
import Testing
@testable import OpenClaw

@MainActor
struct IPadSkillWorkshopFeatureTests {
    @Test func `offline refresh clears proposal state`() async {
        var initialState = IPadSkillWorkshopFeature.State()
        initialState.proposalEntries = .init(values: [Self.proposal(id: "pending-1", status: "pending")])
        initialState.loadingPhase = .inFlight
        initialState.inspectingProposalID = .init(value: "pending-1")
        initialState.errorText = .init(value: "old error")
        let store = TestStore(initialState: initialState) {
            IPadSkillWorkshopFeature(client: Self.client())
        }

        await store.send(.refreshRequested(.init(
            sceneActivity: .init(isActive: true),
            readAccess: .init(canRead: false),
            force: .init(isForced: false))))
        {
            $0.proposalEntries = .init()
            $0.loadingPhase = .idle
            $0.inspectingProposalID = nil
            $0.errorText = nil
        }
    }

    @Test func `refresh success stores proposals and inspects selected proposal`() async {
        let entry = Self.entry(id: "pending-1", status: "pending")
        let inspect = Self.inspectResponse(id: "pending-1", status: "pending", content: "inspected body")
        let manifest = IPadSkillProposalManifest(proposals: [entry])
        let store = TestStore(initialState: IPadSkillWorkshopFeature.State()) {
            IPadSkillWorkshopFeature(client: Self.client(
                list: { _ in manifest },
                inspect: { _, _ in inspect }))
        }

        await store.send(.refreshRequested(.init(
            sceneActivity: .init(isActive: true),
            readAccess: .init(canRead: true),
            force: .init(isForced: false))))
        {
            $0.loadingPhase = .inFlight
        }
        await store.receive(.refreshResponse(.init(
            force: .init(isForced: false),
            result: .success(manifest))))
        {
            $0.loadingPhase = .idle
            $0.proposalEntries = .init(values: [IPadSkillProposal(entry: entry, previous: nil)])
            $0.selectedProposalID = .init(value: "pending-1")
            $0.inspectingProposalID = .init(value: "pending-1")
        }
        await store.receive(.inspectResponse(.init(
            proposalID: .init(value: "pending-1"),
            result: .success(inspect))))
        {
            $0.inspectingProposalID = nil
            $0.proposalEntries = .init(values: [IPadSkillProposal(
                inspect: inspect,
                previous: IPadSkillProposal(entry: entry, previous: nil))])
        }
    }

    @Test func `filter and query changes keep selection inside visible proposals`() async {
        var initialState = IPadSkillWorkshopFeature.State()
        initialState.proposalEntries = .init(values: [
            Self.proposal(id: "applied-1", status: "applied", title: "Applied Proposal"),
            Self.proposal(id: "pending-1", status: "pending", title: "Pending Proposal"),
        ])
        initialState.selectedProposalID = .init(value: "applied-1")
        let store = TestStore(initialState: initialState) {
            IPadSkillWorkshopFeature(client: Self.client())
        }

        await store.send(.agentScopeChanged(.init(agentID: .init(value: " agent-1 ")))) {
            $0.selectedAgentScopeID = .init(value: "agent-1")
        }
        await store.send(.statusFilterChanged(.init(filter: .init(value: "pending")))) {
            $0.statusFilter = .init(value: "pending")
            $0.selectedProposalID = .init(value: "pending-1")
        }
        await store.send(.queryChanged(.init(query: .init(value: "missing")))) {
            $0.query = .init(value: "missing")
            $0.selectedProposalID = nil
        }
        await store.send(.clearQueryTapped) {
            $0.query = .init(value: "")
            $0.selectedProposalID = .init(value: "pending-1")
        }
    }

    @Test func `proposal lanes are filtered by reducer state`() {
        var state = IPadSkillWorkshopFeature.State()
        let statusFilterOptions = [
            IPadSkillWorkshopStatusFilterOption(id: "pending", title: "Pending"),
            IPadSkillWorkshopStatusFilterOption(id: "held", title: "Held"),
            IPadSkillWorkshopStatusFilterOption(id: "applied", title: "Applied"),
            IPadSkillWorkshopStatusFilterOption(id: "rejected", title: "Rejected"),
            IPadSkillWorkshopStatusFilterOption(id: "all", title: "All"),
        ]
        state.proposalEntries = .init(values: [
            Self.proposal(id: "pending-match", status: "pending", title: "Gateway proposal"),
            Self.proposal(id: "pending-other", status: "pending", title: "Other proposal"),
            Self.proposal(id: "applied-match", status: "applied", title: "Gateway applied"),
            Self.proposal(id: "stale-match", status: "stale", title: "Gateway stale"),
        ])
        state.query = .init(value: "gateway")

        #expect(state.statusFilterLabel == "Pending")
        #expect(state.statusFilterControlPresentation == .init(
            selectedFilter: "pending",
            selectedLabel: "Pending",
            options: statusFilterOptions))
        #expect(state.filteredProposals.map(\.id) == ["pending-match"])
        #expect(state.filteredProposalCount == 1)
        #expect(state.queueSummaryPresentation == .init(
            proposalCount: 1,
            statusLabel: "Pending"))
        #expect(state.pendingProposalCount == 2)
        #expect(state.appliedProposalCount == 1)
        #expect(state.heldProposalCount == 1)
        #expect(state.metricPresentations == [
            IPadSkillWorkshopMetricPresentation(
                id: .pending,
                icon: "clock",
                title: "Pending",
                value: "2"),
            IPadSkillWorkshopMetricPresentation(
                id: .applied,
                icon: "checkmark.circle",
                title: "Applied",
                value: "1"),
            IPadSkillWorkshopMetricPresentation(
                id: .held,
                icon: "shield",
                title: "Held",
                value: "1"),
        ])
        #expect(state.visibleProposalLaneStatuses == ["pending"])
        #expect(state.proposals(forLaneStatus: "pending").map(\.id) == ["pending-match"])
        #expect(state.proposals(forLaneStatus: "applied").map(\.id) == ["applied-match"])
        #expect(state.proposal(withID: "pending-match")?.id == "pending-match")
        #expect(state.proposal(withID: "missing") == nil)
        #expect(state.proposalListPresentation.proposals.map(\.id) == ["pending-match"])
        #expect(state.proposalListPresentation.proposals.map(\.showsProposalActions) == [true])
        #expect(state.proposalBoardPresentation.lanes.map(\.id) == ["pending"])
        #expect(state.proposalBoardPresentation.lanes.map(\.title) == ["Pending"])
        #expect(state.proposalBoardPresentation.lanes.map(\.value) == ["1"])
        #expect(state.proposalBoardPresentation.lanes.first?.proposals.map(\.id) ?? [] == ["pending-match"])
        #expect(state.proposalDetailPresentation(forID: "pending-match")?.proposal.id == "pending-match")
        #expect(state.proposalDetailPresentation(forID: "missing") == nil)

        state.statusFilter = .init(value: "all")
        #expect(state.statusFilterLabel == "All")
        #expect(state.statusFilterControlPresentation == .init(
            selectedFilter: "all",
            selectedLabel: "All",
            options: statusFilterOptions))
        #expect(state.filteredProposals.map(\.id) == ["pending-match", "applied-match", "stale-match"])
        #expect(state.filteredProposalCount == 3)
        #expect(state.queueSummaryPresentation == .init(
            proposalCount: 3,
            statusLabel: "All"))
        #expect(state.visibleProposalLaneStatuses == ["pending", "quarantined", "stale", "applied", "rejected"])
        #expect(state.proposalListPresentation.proposals.map(\.id) == [
            "pending-match",
            "applied-match",
            "stale-match",
        ])
        #expect(state.proposalBoardPresentation.lanes.map(\.id) == [
            "pending",
            "quarantined",
            "stale",
            "applied",
            "rejected",
        ])
        let boardLanes = state.proposalBoardPresentation.lanes
        #expect(boardLanes.map(\.value) == ["1", "0", "1", "1", "0"])
        #expect(boardLanes[0].proposals.map(\.id) == ["pending-match"])
        #expect(boardLanes[1].proposals.map(\.id) == [])
        #expect(boardLanes[1].emptyPresentation == .init(
            icon: "hammer",
            title: "No quarantined proposals",
            detail: "Matching proposals appear here after gateway refresh.",
            value: "empty"))
        #expect(boardLanes[2].proposals.map(\.id) == ["stale-match"])
        #expect(boardLanes[3].proposals.map(\.id) == ["applied-match"])
        #expect(boardLanes[4].proposals.map(\.id) == [])
    }

    @Test func `proposal action visibility follows reducer state`() {
        let state = IPadSkillWorkshopFeature.State()
        let pendingProposal = Self.proposal(id: "pending-1", status: "pending")
        let rejectedProposal = Self.proposal(id: "rejected-1", status: "rejected")

        #expect(IPadSkillWorkshopFeature.State.shouldShowProposalActions(status: "pending"))
        #expect(!IPadSkillWorkshopFeature.State.shouldShowProposalActions(status: "applied"))
        #expect(!IPadSkillWorkshopFeature.State.shouldShowProposalActions(status: "stale"))
        #expect(state.shouldShowProposalActions(for: pendingProposal))
        #expect(!state.shouldShowProposalActions(for: rejectedProposal))
        #expect(state.proposalCardPresentation(for: pendingProposal).showsProposalActions)
        #expect(!state.proposalCardPresentation(for: rejectedProposal).showsProposalActions)
    }

    @Test func `proposal action controls require mutation access and idle state`() {
        var state = IPadSkillWorkshopFeature.State()
        let writableAdmin = IPadSkillWorkshopFeature.State.gatewayAccess(
            isOperatorGatewayConnected: true,
            isAppleReviewDemoModeEnabled: false,
            hasOperatorAdminScope: true)
        let writableNonAdmin = IPadSkillWorkshopFeature.State.gatewayAccess(
            isOperatorGatewayConnected: true,
            isAppleReviewDemoModeEnabled: false,
            hasOperatorAdminScope: false)
        let reviewModeAdmin = IPadSkillWorkshopFeature.State.gatewayAccess(
            isOperatorGatewayConnected: true,
            isAppleReviewDemoModeEnabled: true,
            hasOperatorAdminScope: true)
        let applyButton = IPadSkillWorkshopProposalActionButtonPresentation(
            title: "Apply",
            iconSystemName: "checkmark.circle")
        let rejectButton = IPadSkillWorkshopProposalActionButtonPresentation(
            title: "Reject",
            iconSystemName: "xmark.circle")

        #expect(state.shouldEnableProposalActionControls(gatewayAccess: writableAdmin))
        #expect(state.proposalActionControlsPresentation(gatewayAccess: writableAdmin) == .init(
            applyButton: applyButton,
            rejectButton: rejectButton,
            canApplyMutations: true,
            canRunActions: true,
            adminScopeNotice: nil))
        #expect(state.screenPresentation(
            gatewayAccess: writableAdmin,
            sceneIsActive: true).proposalActionControlsPresentation == .init(
            applyButton: applyButton,
            rejectButton: rejectButton,
            canApplyMutations: true,
            canRunActions: true,
            adminScopeNotice: nil))
        #expect(!state.shouldEnableProposalActionControls(gatewayAccess: writableNonAdmin))
        #expect(state.proposalActionControlsPresentation(gatewayAccess: writableNonAdmin) == .init(
            applyButton: applyButton,
            rejectButton: rejectButton,
            canApplyMutations: false,
            canRunActions: false,
            adminScopeNotice: .init(
                iconSystemName: "lock.shield",
                text: "Admin scope required.")))
        #expect(!state.shouldEnableProposalActionControls(gatewayAccess: reviewModeAdmin))
        #expect(state.proposalActionControlsPresentation(gatewayAccess: reviewModeAdmin) == .init(
            applyButton: applyButton,
            rejectButton: rejectButton,
            canApplyMutations: false,
            canRunActions: false,
            adminScopeNotice: .init(
                iconSystemName: "lock.shield",
                text: "Admin scope required.")))

        state.busyAction = IPadSkillProposalAction(kind: .apply, proposalID: "pending-1")
        #expect(!state.shouldEnableProposalActionControls(gatewayAccess: writableAdmin))
        #expect(state.proposalActionControlsPresentation(gatewayAccess: writableAdmin) == .init(
            applyButton: applyButton,
            rejectButton: rejectButton,
            canApplyMutations: true,
            canRunActions: false,
            adminScopeNotice: nil))
        #expect(state.screenPresentation(
            gatewayAccess: writableAdmin,
            sceneIsActive: true).proposalActionControlsPresentation == .init(
            applyButton: applyButton,
            rejectButton: rejectButton,
            canApplyMutations: true,
            canRunActions: false,
            adminScopeNotice: nil))
    }

    @Test func `proposal inspection presentation follows selected and inspecting state`() {
        var state = IPadSkillWorkshopFeature.State()
        let selectedProposal = Self.proposal(id: "pending-1", status: "pending")
        let inspectingProposal = Self.proposal(id: "pending-2", status: "pending")

        #expect(state.proposalInspectionControlsPresentation == .init(
            title: "Inspect",
            iconSystemName: "doc.text.magnifyingglass",
            canInspect: true))
        #expect(state.screenPresentation(
            gatewayAccess: .init(canRead: true, canWrite: true, hasOperatorAdminScope: true),
            sceneIsActive: true).proposalInspectionControlsPresentation == .init(
            title: "Inspect",
            iconSystemName: "doc.text.magnifyingglass",
            canInspect: true))
        #expect(state.proposalCardPresentation(for: selectedProposal) == .init(
            proposal: selectedProposal,
            isSelected: false,
            isInspecting: false,
            showsProposalActions: true))

        state.selectedProposalID = .init(value: selectedProposal.id)
        state.inspectingProposalID = .init(value: inspectingProposal.id)

        #expect(state.proposalInspectionControlsPresentation == .init(
            title: "Inspect",
            iconSystemName: "doc.text.magnifyingglass",
            canInspect: false))
        #expect(state.screenPresentation(
            gatewayAccess: .init(canRead: true, canWrite: true, hasOperatorAdminScope: true),
            sceneIsActive: true).proposalInspectionControlsPresentation == .init(
            title: "Inspect",
            iconSystemName: "doc.text.magnifyingglass",
            canInspect: false))
        #expect(state.proposalCardPresentation(for: selectedProposal) == .init(
            proposal: selectedProposal,
            isSelected: true,
            isInspecting: false,
            showsProposalActions: true))
        #expect(state.proposalCardPresentation(for: inspectingProposal) == .init(
            proposal: inspectingProposal,
            isSelected: false,
            isInspecting: true,
            showsProposalActions: true))
    }

    @Test func `presented proposal presentation follows sheet route state`() {
        var state = IPadSkillWorkshopFeature.State()
        var pendingProposal = Self.proposal(id: "pending-1", status: "pending")
        state.proposalEntries = .init(values: [pendingProposal])

        #expect(state.presentedProposalPresentation == nil)

        state.presentedProposalRoute = IPadSkillProposalSheetRoute(proposalID: "pending-1")
        #expect(state.presentedProposalPresentation?.card == .init(
            proposal: pendingProposal,
            isSelected: false,
            isInspecting: false,
            showsProposalActions: true))
        #expect(state.presentedProposalPresentation?.bodyText == nil)
        #expect(state.presentedProposalPresentation?.emptyBodyText == "Select refresh to load the proposal body.")
        #expect(state.presentedProposalPresentation?.supportFiles == [])
        #expect(state.presentedProposalPresentation?.showsSupportFiles == false)

        pendingProposal.content = "inspected body"
        pendingProposal.supportFiles = [
            IPadSkillProposalSupportFile(path: "skills/sample/SKILL.md", content: nil),
        ]
        state.proposalEntries = .init(values: [pendingProposal])
        state.selectedProposalID = .init(value: "pending-1")
        state.inspectingProposalID = .init(value: "pending-1")
        #expect(state.presentedProposalPresentation?.card == .init(
            proposal: pendingProposal,
            isSelected: true,
            isInspecting: true,
            showsProposalActions: true))
        #expect(state.presentedProposalPresentation?.bodyText == "inspected body")
        #expect(state.presentedProposalPresentation?.supportFiles == pendingProposal.supportFiles)
        #expect(state.presentedProposalPresentation?.showsSupportFiles == true)

        state.presentedProposalRoute = IPadSkillProposalSheetRoute(proposalID: "missing")
        #expect(state.presentedProposalPresentation == nil)
    }

    @Test func `agent scope snapshot updates reducer presentation state`() async {
        #expect(IPadSkillWorkshopFeature.State().agentScopeMenuPresentation == .init(
            title: "Agent",
            selectedLabel: "Default Agent",
            selectorIconSystemName: "chevron.up.chevron.down",
            accessibilityLabel: "Skill Workshop agent scope",
            options: [
                IPadSkillWorkshopAgentScopeOption(id: "", title: "Default agent"),
            ],
            isEnabled: false))

        let snapshot = IPadSkillWorkshopFeature.Action.AgentScopeSnapshot(
            gatewayDefaultAgentID: .init(value: " main "),
            gatewayAgents: .init(values: [
                .init(id: " main ", name: " Main Agent "),
                .init(id: "agent-b", name: " Beta "),
                .init(id: "agent-a", name: " "),
            ]),
            activeAgentName: .init(value: "Active Agent"))
        let store = TestStore(initialState: IPadSkillWorkshopFeature.State()) {
            IPadSkillWorkshopFeature(client: Self.client())
        }

        await store.send(.agentScopeSnapshotChanged(snapshot)) {
            $0.gatewayDefaultAgentID = .init(value: " main ")
            $0.gatewayAgentEntries = .init(values: [
                .init(id: " main ", name: " Main Agent "),
                .init(id: "agent-b", name: " Beta "),
                .init(id: "agent-a", name: " "),
            ])
            $0.activeAgentName = .init(value: "Active Agent")
        }

        var state = IPadSkillWorkshopFeature.State()
        state.gatewayDefaultAgentID = snapshot.gatewayDefaultAgentID
        state.gatewayAgentEntries = snapshot.gatewayAgents
        state.activeAgentName = snapshot.activeAgentName

        #expect(state.defaultAgentScopeLabel == "Main Agent")
        #expect(state.agentScopeLabel == "Main Agent")
        #expect(state.agentScopeOptions == [
            IPadSkillWorkshopAgentScopeOption(id: "agent-a", title: "agent-a"),
            IPadSkillWorkshopAgentScopeOption(id: "agent-b", title: "Beta"),
        ])
        #expect(state.agentScopeMenuPresentation == .init(
            title: "Agent",
            selectedLabel: "Main Agent",
            selectorIconSystemName: "chevron.up.chevron.down",
            accessibilityLabel: "Skill Workshop agent scope",
            options: [
                IPadSkillWorkshopAgentScopeOption(id: "", title: "Default agent"),
                IPadSkillWorkshopAgentScopeOption(id: "agent-a", title: "agent-a"),
                IPadSkillWorkshopAgentScopeOption(id: "agent-b", title: "Beta"),
            ],
            isEnabled: true))

        await store.send(.agentScopeChanged(.init(agentID: .init(value: "agent-b")))) {
            $0.selectedAgentScopeID = .init(value: "agent-b")
        }
        state.selectedAgentScopeID = .init(value: "agent-b")
        #expect(state.agentScopeMenuPresentation.selectedLabel == "Beta")

        await store.send(.agentScopeChanged(.init(agentID: .init(value: "missing")))) {
            $0.selectedAgentScopeID = .init(value: "missing")
        }
        state.selectedAgentScopeID = .init(value: "missing")
        #expect(state.agentScopeMenuPresentation.selectedLabel == "missing")
    }

    @Test func `refresh task identifier is reducer state`() {
        var state = IPadSkillWorkshopFeature.State()
        let connectedAccess = IPadSkillWorkshopFeature.State.gatewayAccess(
            isOperatorGatewayConnected: true,
            isAppleReviewDemoModeEnabled: false,
            hasOperatorAdminScope: true)
        let offlineAccess = IPadSkillWorkshopFeature.State.gatewayAccess(
            isOperatorGatewayConnected: false,
            isAppleReviewDemoModeEnabled: false,
            hasOperatorAdminScope: false)

        #expect(state.refreshTaskID(gatewayAccess: connectedAccess, sceneIsActive: true) == "connected:active:default")
        #expect(state.refreshTaskID(gatewayAccess: offlineAccess, sceneIsActive: false) == "offline:inactive:default")

        state.selectedAgentScopeID = .init(value: "agent-b")
        #expect(state
            .refreshTaskID(gatewayAccess: connectedAccess, sceneIsActive: false) == "connected:inactive:agent-b")
        #expect(state.screenPresentation(
            gatewayAccess: connectedAccess,
            sceneIsActive: false).refreshTaskID == "connected:inactive:agent-b")
    }

    @Test func `refresh control state follows loading phase`() {
        var state = IPadSkillWorkshopFeature.State()

        #expect(!state.isRefreshInFlight)
        #expect(state.refreshControlPresentation == .init(
            title: "Refresh",
            iconSystemName: "arrow.clockwise",
            isDisabled: false,
            showsProgress: false))

        state.loadingPhase = .inFlight
        #expect(state.isRefreshInFlight)
        #expect(state.refreshControlPresentation == .init(
            title: "Refresh",
            iconSystemName: "arrow.clockwise",
            isDisabled: true,
            showsProgress: true))
    }

    @Test func `query field presentation follows reducer state`() {
        var state = IPadSkillWorkshopFeature.State()

        #expect(state.queryFieldPresentation == .init(
            text: "",
            placeholder: "Search proposals",
            iconSystemName: "magnifyingglass",
            clearButtonSystemName: "xmark.circle.fill",
            showsClearButton: false))

        state.query = .init(value: "gateway")
        #expect(state.queryFieldPresentation == .init(
            text: "gateway",
            placeholder: "Search proposals",
            iconSystemName: "magnifyingglass",
            clearButtonSystemName: "xmark.circle.fill",
            showsClearButton: true))
    }

    @Test func `feedback messages follow reducer notice and error state`() {
        var state = IPadSkillWorkshopFeature.State()

        #expect(state.feedbackMessages.isEmpty)

        state.noticeText = .init(value: "Proposal applied.")
        state.errorText = .init(value: "Refresh failed.")

        #expect(state.feedbackMessages == [
            IPadSkillWorkshopFeedbackPresentation(tone: .notice, text: "Proposal applied."),
            IPadSkillWorkshopFeedbackPresentation(tone: .error, text: "Refresh failed."),
        ])
    }

    @Test func `empty proposal presentation follows gateway read access`() {
        let state = IPadSkillWorkshopFeature.State()
        let connectedAccess = IPadSkillWorkshopFeature.State.gatewayAccess(
            isOperatorGatewayConnected: true,
            isAppleReviewDemoModeEnabled: false,
            hasOperatorAdminScope: false)
        let offlineAccess = IPadSkillWorkshopFeature.State.gatewayAccess(
            isOperatorGatewayConnected: false,
            isAppleReviewDemoModeEnabled: false,
            hasOperatorAdminScope: false)

        #expect(state.emptyProposalPresentation(gatewayAccess: connectedAccess) == .init(
            icon: "hammer",
            title: "No proposals",
            detail: "New proposals will appear here when agents draft skills.",
            value: "empty"))
        #expect(state.screenPresentation(
            gatewayAccess: connectedAccess,
            sceneIsActive: true).emptyProposalPresentation == .init(
            icon: "hammer",
            title: "No proposals",
            detail: "New proposals will appear here when agents draft skills.",
            value: "empty"))
        #expect(state.emptyProposalPresentation(gatewayAccess: offlineAccess) == .init(
            icon: "wifi.slash",
            title: "No proposals loaded",
            detail: "Connect from Settings to load Skill Workshop proposals.",
            value: nil))
        #expect(state.screenPresentation(
            gatewayAccess: offlineAccess,
            sceneIsActive: true).emptyProposalPresentation == .init(
            icon: "wifi.slash",
            title: "No proposals loaded",
            detail: "Connect from Settings to load Skill Workshop proposals.",
            value: nil))
    }

    @Test func `proposal selection opening controls sheet presentation`() async {
        let store = TestStore(initialState: IPadSkillWorkshopFeature.State()) {
            IPadSkillWorkshopFeature(client: Self.client())
        }

        await store.send(.proposalSelected(.init(
            proposalID: .init(value: "pending-1"),
            opening: .inline,
            readAccess: .init(canRead: false),
            forceInspect: .init(isForced: false))))
        {
            $0.selectedProposalID = .init(value: "pending-1")
        }

        await store.send(.proposalSelected(.init(
            proposalID: .init(value: "pending-2"),
            opening: .sheet,
            readAccess: .init(canRead: false),
            forceInspect: .init(isForced: false))))
        {
            $0.selectedProposalID = .init(value: "pending-2")
            $0.presentedProposalRoute = IPadSkillProposalSheetRoute(proposalID: "pending-2")
        }

        await store.send(.proposalSheetDismissed) {
            $0.presentedProposalRoute = nil
        }
    }

    @Test func `apply success clears busy state and refreshes proposals`() async {
        let before = Self.entry(id: "pending-1", status: "pending")
        let after = Self.entry(id: "pending-1", status: "applied")
        let refreshedManifest = IPadSkillProposalManifest(proposals: [after])
        var initialState = IPadSkillWorkshopFeature.State()
        initialState.proposalEntries = .init(values: [IPadSkillProposal(entry: before, previous: nil)])
        initialState.selectedProposalID = .init(value: "pending-1")
        let store = TestStore(initialState: initialState) {
            IPadSkillWorkshopFeature(client: Self.client(
                list: { _ in refreshedManifest },
                run: { _, _, _ in }))
        }

        await store.send(.proposalMutationRequested(.init(
            kind: .apply,
            proposalID: .init(value: "pending-1"),
            sceneActivity: .init(isActive: true),
            readAccess: .init(canRead: true),
            writeAccess: .init(canWrite: true),
            adminAccess: .init(hasOperatorAdminScope: true))))
        {
            $0.busyAction = IPadSkillProposalAction(kind: .apply, proposalID: "pending-1")
        }
        await store.receive(.proposalMutationResponse(.init(
            kind: .apply,
            sceneActivity: .init(isActive: true),
            readAccess: .init(canRead: true),
            result: .success(.init()))))
        {
            $0.busyAction = nil
            $0.noticeText = .init(value: "Proposal applied.")
        }
        await store.receive(.refreshRequested(.init(
            sceneActivity: .init(isActive: true),
            readAccess: .init(canRead: true),
            force: .init(isForced: true))))
        {
            $0.loadingPhase = .inFlight
        }
        await store.receive(.refreshResponse(.init(
            force: .init(isForced: true),
            result: .success(refreshedManifest))))
        {
            $0.loadingPhase = .idle
            $0.proposalEntries = .init(values: [IPadSkillProposal(
                entry: after,
                previous: IPadSkillProposal(entry: before, previous: nil))])
            $0.selectedProposalID = nil
        }
    }

    @Test func `forced refresh failure surfaces error text`() async {
        let store = TestStore(initialState: IPadSkillWorkshopFeature.State()) {
            IPadSkillWorkshopFeature(client: Self.client(
                list: { _ in throw TestSkillWorkshopFailure.failed }))
        }

        await store.send(.refreshRequested(.init(
            sceneActivity: .init(isActive: true),
            readAccess: .init(canRead: true),
            force: .init(isForced: true))))
        {
            $0.loadingPhase = .inFlight
        }
        await store.receive(.refreshResponse(.init(
            force: .init(isForced: true),
            result: .failure(.failed(.init(message: .init(value: "skill boom")))))))
        {
            $0.loadingPhase = .idle
            $0.errorText = .init(value: "skill boom")
        }
    }

    @Test func `proposal mutation failure clears busy state and surfaces error text`() async {
        let operation = IPadSkillProposalAction(kind: .reject, proposalID: "pending-1")
        let store = TestStore(initialState: IPadSkillWorkshopFeature.State()) {
            IPadSkillWorkshopFeature(client: Self.client(
                run: { _, _, _ in throw TestSkillWorkshopFailure.failed }))
        }

        await store.send(.proposalMutationRequested(.init(
            kind: .reject,
            proposalID: .init(value: "pending-1"),
            sceneActivity: .init(isActive: true),
            readAccess: .init(canRead: true),
            writeAccess: .init(canWrite: true),
            adminAccess: .init(hasOperatorAdminScope: true))))
        {
            $0.busyAction = operation
        }
        await store.receive(.proposalMutationResponse(.init(
            kind: .reject,
            sceneActivity: .init(isActive: true),
            readAccess: .init(canRead: true),
            result: .failure(.failed(.init(message: .init(value: "skill boom")))))))
        {
            $0.busyAction = nil
            $0.errorText = .init(value: "skill boom")
        }
    }

    @Test func `proposal mutation request is ignored while busy`() async {
        let operation = IPadSkillProposalAction(kind: .apply, proposalID: "pending-1")
        var initialState = IPadSkillWorkshopFeature.State()
        initialState.busyAction = operation
        let store = TestStore(initialState: initialState) {
            IPadSkillWorkshopFeature(client: Self.client())
        }

        await store.send(.proposalMutationRequested(.init(
            kind: .reject,
            proposalID: .init(value: "pending-2"),
            sceneActivity: .init(isActive: true),
            readAccess: .init(canRead: true),
            writeAccess: .init(canWrite: true),
            adminAccess: .init(hasOperatorAdminScope: true))))
    }

    private static func client(
        list: @escaping @Sendable @MainActor (IPadSkillWorkshopAgentScopeParam) async throws
            -> IPadSkillProposalManifest = { _ in
                IPadSkillProposalManifest(proposals: [])
            },
        inspect: @escaping @Sendable @MainActor (IPadSkillWorkshopAgentScopeParam, IPadSkillWorkshopProposalID)
        async throws -> IPadSkillProposalInspectResponse = { _, proposalID in
            Self.inspectResponse(id: proposalID.value, status: "pending", content: "")
        },
        run: @escaping @Sendable @MainActor (
            _ action: IPadSkillProposalAction.Kind,
            IPadSkillWorkshopAgentScopeParam,
            IPadSkillWorkshopProposalID)
        async throws -> Void = { _, _, _ in })
        -> IPadSkillWorkshopClient
    {
        IPadSkillWorkshopClient(list: list, inspect: inspect, run: run)
    }

    private static func proposal(
        id: String,
        status: String,
        title: String = "Proposal") -> IPadSkillProposal
    {
        IPadSkillProposal(entry: self.entry(id: id, status: status, title: title), previous: nil)
    }

    private static func entry(
        id: String,
        status: String,
        title: String = "Proposal") -> IPadSkillProposalManifestEntry
    {
        IPadSkillProposalManifestEntry(
            id: id,
            kind: "skill",
            status: status,
            title: title,
            description: "\(title) description",
            skillName: "sample-skill",
            skillKey: "sample-skill",
            createdAt: "2026-07-01T00:00:00Z",
            updatedAt: status == "applied" ? "2026-07-01T00:10:00Z" : "2026-07-01T00:00:00Z",
            scanState: "clean")
    }

    private static func inspectResponse(
        id: String,
        status: String,
        content: String) -> IPadSkillProposalInspectResponse
    {
        IPadSkillProposalInspectResponse(
            record: IPadSkillProposalRecord(
                id: id,
                kind: "skill",
                status: status,
                title: "Proposal",
                description: "Proposal description",
                createdAt: "2026-07-01T00:00:00Z",
                updatedAt: status == "applied" ? "2026-07-01T00:10:00Z" : "2026-07-01T00:00:00Z",
                target: IPadSkillProposalTarget(
                    skillName: "sample-skill",
                    skillKey: "sample-skill")),
            content: content,
            supportFiles: [])
    }
}

private enum TestSkillWorkshopFailure: LocalizedError {
    case failed

    var errorDescription: String? {
        "skill boom"
    }
}
