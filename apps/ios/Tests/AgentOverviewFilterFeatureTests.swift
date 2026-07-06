import ComposableArchitecture
import Foundation
import Testing
@testable import OpenClaw

@MainActor
struct AgentSelectionFeatureTests {
    @Test func `agent selection persists through client`() async {
        let probe = AgentSelectionProbe()
        let store = TestStore(initialState: AgentSelectionFeature.State()) {
            AgentSelectionFeature(selectionClient: probe.client)
        }

        await store.send(.agentSelected(.init(agentId: .init(value: "agent-1"))))
        await store.finish()

        #expect(probe.selectedAgentIds == ["agent-1"])
    }
}

private final class AgentSelectionProbe: @unchecked Sendable {
    var selectedAgentIds: [String] = []

    var client: AgentSelectionClient {
        AgentSelectionClient(setSelectedAgentId: { agentId in
            self.selectedAgentIds.append(agentId.value)
        })
    }
}

@MainActor
struct AgentSkillPolicyMutationFeatureTests {
    @Test func `mutation start records busy key and clears messages`() async {
        var initialState = AgentSkillPolicyMutationFeature.State()
        initialState.errorText = "Old error."
        initialState.statusText = "Old status."
        let store = TestStore(initialState: initialState) {
            AgentSkillPolicyMutationFeature()
        }

        await store.send(.mutationStarted(.init(key: .init(value: "skill-a")))) {
            $0.busyKeys = ["skill-a"]
            $0.errorText = nil
            $0.statusText = nil
        }
    }

    @Test func `mutation success stores status while busy key remains active`() async {
        var initialState = AgentSkillPolicyMutationFeature.State()
        initialState.busyKeys = ["skill-a"]
        let store = TestStore(initialState: initialState) {
            AgentSkillPolicyMutationFeature()
        }

        await store.send(.mutationSucceeded(.init(message: .init(value: "Skill policy saved.")))) {
            $0.statusText = "Skill policy saved."
        }
    }

    @Test func `mutation failure stores error while busy key remains active`() async {
        var initialState = AgentSkillPolicyMutationFeature.State()
        initialState.busyKeys = ["skill-a"]
        let store = TestStore(initialState: initialState) {
            AgentSkillPolicyMutationFeature()
        }

        await store.send(.mutationFailed(.init(message: .init(value: "Skill policy failed.")))) {
            $0.errorText = "Skill policy failed."
        }
    }

    @Test func `mutation finish clears busy key`() async {
        var initialState = AgentSkillPolicyMutationFeature.State()
        initialState.busyKeys = ["skill-a", "skill-b"]
        let store = TestStore(initialState: initialState) {
            AgentSkillPolicyMutationFeature()
        }

        await store.send(.mutationFinished(.init(key: .init(value: "skill-a")))) {
            $0.busyKeys = ["skill-b"]
        }
    }
}

@MainActor
struct AgentSkillEditorFeatureTests {
    @Test func `editor selection opens changes and dismisses`() async {
        let store = TestStore(initialState: AgentSkillEditorFeature.State()) {
            AgentSkillEditorFeature()
        }

        await store.send(.editorOpened(.init(id: .init(value: "skill-a")))) {
            $0.selection = AgentProTab.SkillEditorSelection(id: "skill-a")
        }
        await store.send(.selectionChanged(.init(selection: AgentProTab.SkillEditorSelection(id: "skill-b")))) {
            $0.selection = AgentProTab.SkillEditorSelection(id: "skill-b")
        }
        await store.send(.editorDismissed) {
            $0.selection = nil
        }
    }

    @Test func `api key draft changes and clears`() async {
        let store = TestStore(initialState: AgentSkillEditorFeature.State()) {
            AgentSkillEditorFeature()
        }

        await store.send(.apiKeyDraftChanged(.init(
            key: .init(value: "skill-a"),
            value: .init(value: "sk-test"))))
        {
            $0.apiKeyDrafts = ["skill-a": "sk-test"]
        }
        await store.send(.apiKeyDraftCleared(.init(key: .init(value: "skill-a")))) {
            $0.apiKeyDrafts = [:]
        }
    }

    @Test func `mutation start records busy key and clears stale message`() async {
        var initialState = AgentSkillEditorFeature.State()
        initialState.messages = [
            "skill-a": AgentProTab.SkillEditorMessage(kind: .error, text: "Old error."),
        ]
        let store = TestStore(initialState: initialState) {
            AgentSkillEditorFeature()
        }

        await store.send(.mutationStarted(.init(key: .init(value: "skill-a")))) {
            $0.busyKeys = ["skill-a"]
            $0.messages = [:]
        }
    }

    @Test func `mutation success stores message while busy key remains active`() async {
        var initialState = AgentSkillEditorFeature.State()
        initialState.busyKeys = ["skill-a"]
        let store = TestStore(initialState: initialState) {
            AgentSkillEditorFeature()
        }

        await store.send(.mutationSucceeded(.init(
            key: .init(value: "skill-a"),
            summary: .init(message: .init(value: "Skill enabled.")))))
        {
            $0.messages = [
                "skill-a": AgentProTab.SkillEditorMessage(kind: .success, text: "Skill enabled."),
            ]
        }
    }

    @Test func `mutation finish clears busy key`() async {
        var initialState = AgentSkillEditorFeature.State()
        initialState.busyKeys = ["skill-a", "skill-b"]
        initialState.messages = [
            "skill-a": AgentProTab.SkillEditorMessage(kind: .success, text: "Skill enabled."),
        ]
        let store = TestStore(initialState: initialState) {
            AgentSkillEditorFeature()
        }

        await store.send(.mutationFinished(.init(key: .init(value: "skill-a")))) {
            $0.busyKeys = ["skill-b"]
        }
    }

    @Test func `mutation failure clears busy key and stores error`() async {
        var initialState = AgentSkillEditorFeature.State()
        initialState.busyKeys = ["skill-a"]
        let store = TestStore(initialState: initialState) {
            AgentSkillEditorFeature()
        }

        await store.send(.mutationFailed(.init(
            key: .init(value: "skill-a"),
            message: .init(value: "Skill failed."))))
        {
            $0.busyKeys = []
            $0.messages = [
                "skill-a": AgentProTab.SkillEditorMessage(kind: .error, text: "Skill failed."),
            ]
        }
    }
}

@MainActor
struct AgentCronActionFeatureTests {
    @Test func `action start records busy id and clears status`() async {
        var initialState = AgentCronActionFeature.State()
        initialState.statusText = "Queued old job."
        let store = TestStore(initialState: initialState) {
            AgentCronActionFeature()
        }

        await store.send(.actionStarted(.init(id: "job-1"))) {
            $0.busyIDs = ["job-1"]
            $0.statusText = nil
        }
    }

    @Test func `action success stores status while busy id remains active`() async {
        var initialState = AgentCronActionFeature.State()
        initialState.busyIDs = ["job-1", "job-2"]
        let store = TestStore(initialState: initialState) {
            AgentCronActionFeature()
        }

        await store.send(.actionSucceeded(.init(message: .init(value: "Queued job.")))) {
            $0.busyIDs = ["job-1", "job-2"]
            $0.statusText = "Queued job."
        }
    }

    @Test func `action finish clears busy id`() async {
        var initialState = AgentCronActionFeature.State()
        initialState.busyIDs = ["job-1", "job-2"]
        initialState.statusText = "Queued job."
        let store = TestStore(initialState: initialState) {
            AgentCronActionFeature()
        }

        await store.send(.actionFinished(.init(id: "job-1"))) {
            $0.busyIDs = ["job-2"]
        }
    }

    @Test func `action failure clears busy id and stores error`() async {
        var initialState = AgentCronActionFeature.State()
        initialState.busyIDs = ["job-1"]
        let store = TestStore(initialState: initialState) {
            AgentCronActionFeature()
        }

        await store.send(.actionFailed(.init(id: "job-1", message: .init(value: "Cron failed.")))) {
            $0.busyIDs = []
            $0.statusText = "Cron failed."
        }
    }
}

@MainActor
struct AgentSkillFilterFeatureTests {
    @Test func `search text changes update state`() async {
        let store = TestStore(initialState: AgentSkillFilterFeature.State()) {
            AgentSkillFilterFeature()
        }

        await store.send(.searchTextChanged(.init(text: .init(value: "gateway")))) {
            $0.searchText = "gateway"
        }
    }

    @Test func `status filter changes update state`() async {
        let store = TestStore(initialState: AgentSkillFilterFeature.State()) {
            AgentSkillFilterFeature()
        }

        await store.send(.statusFilterChanged(.setup)) {
            $0.statusFilter = .setup
        }
    }

    @Test func `clear search leaves selected status filter alone`() async {
        var initialState = AgentSkillFilterFeature.State()
        initialState.searchText = "memory"
        initialState.statusFilter = .blocked
        let store = TestStore(initialState: initialState) {
            AgentSkillFilterFeature()
        }

        await store.send(.clearSearchTapped) {
            $0.searchText = ""
        }
    }
}

@MainActor
struct AgentClawHubSearchFeatureTests {
    @Test func `query changes update search text`() async {
        let store = TestStore(initialState: AgentClawHubSearchFeature.State()) {
            AgentClawHubSearchFeature()
        }

        await store.send(.queryChanged(.init(query: .init(value: "memory")))) {
            $0.query = "memory"
        }
    }

    @Test func `search lifecycle stores results`() async {
        let result = Self.result(slug: "memory-plus")
        let store = TestStore(initialState: AgentClawHubSearchFeature.State()) {
            AgentClawHubSearchFeature()
        }

        await store.send(.searchRequested) {
            $0.isLoading = true
        }
        await store.send(.searchFinished(.init(results: [result]))) {
            $0.results = [result]
            $0.isLoading = false
        }
    }

    @Test func `search failure keeps existing results and stores error`() async {
        var initialState = AgentClawHubSearchFeature.State()
        initialState.results = [Self.result(slug: "existing")]
        initialState.isLoading = true
        let store = TestStore(initialState: initialState) {
            AgentClawHubSearchFeature()
        }

        await store.send(.searchFailed(.init(message: .init(value: "Search failed.")))) {
            $0.errorText = "Search failed."
            $0.isLoading = false
        }
    }

    @Test func `install lifecycle owns busy slug`() async {
        let store = TestStore(initialState: AgentClawHubSearchFeature.State()) {
            AgentClawHubSearchFeature()
        }

        await store.send(.installRequested(.init(slug: .init(value: "memory-plus")))) {
            $0.installingSlug = "memory-plus"
        }
        await store.send(.installFinished(.init(slug: .init(value: "memory-plus")))) {
            $0.installingSlug = nil
        }
    }

    @Test func `install failure clears matching slug and records error`() async {
        var initialState = AgentClawHubSearchFeature.State()
        initialState.installingSlug = "memory-plus"
        let store = TestStore(initialState: initialState) {
            AgentClawHubSearchFeature()
        }

        await store.send(.installFailed(.init(
            slug: .init(value: "memory-plus"),
            message: .init(value: "Install failed."))))
        {
            $0.errorText = "Install failed."
            $0.installingSlug = nil
        }
    }

    private static func result(slug: String) -> ClawHubSearchResultLite {
        ClawHubSearchResultLite(
            slug: slug,
            displayName: "Memory Plus",
            summary: "Adds memory tools",
            version: "1.0.0")
    }
}

@MainActor
struct AgentOverviewLoadFeatureTests {
    @Test func `connected refresh starts one shot load request`() async {
        let store = TestStore(initialState: AgentOverviewLoadFeature.State()) {
            AgentOverviewLoadFeature()
        }

        await store.send(.refreshRequested(.init(
            gatewayConnection: .init(isConnected: true),
            force: .init(isForced: false),
            activeAgent: .init(value: "mobile"))))
        {
            $0.isLoading = true
            $0.nextRefreshRequestID = 1
            $0.refreshRequest = AgentOverviewLoadFeature.RefreshRequest(id: 1, activeAgentID: "mobile")
        }
        await store.send(.refreshLaunched(.init(requestID: 1))) {
            $0.refreshRequest = nil
        }
    }

    @Test func `disconnected refresh clears stale overview state`() async {
        var initialState = AgentOverviewLoadFeature.State()
        initialState.overview = Self.snapshot(hasLiveData: true)
        initialState.errorText = "old warning"
        initialState.isLoading = true
        initialState.refreshRequest = AgentOverviewLoadFeature.RefreshRequest(id: 1, activeAgentID: "mobile")
        let store = TestStore(initialState: initialState) {
            AgentOverviewLoadFeature()
        }

        await store.send(.refreshRequested(.init(
            gatewayConnection: .init(isConnected: false),
            force: .init(isForced: false),
            activeAgent: .init(value: "mobile"))))
        {
            $0.overview = nil
            $0.errorText = nil
            $0.isLoading = false
            $0.refreshRequest = nil
        }
    }

    @Test func `non forced refresh coalesces while loading`() async {
        var initialState = AgentOverviewLoadFeature.State()
        initialState.isLoading = true
        let store = TestStore(initialState: initialState) {
            AgentOverviewLoadFeature()
        }

        await store.send(.refreshRequested(.init(
            gatewayConnection: .init(isConnected: true),
            force: .init(isForced: false),
            activeAgent: .init(value: "mobile"))))
    }

    @Test func `finished refresh stores snapshot and clears empty live data warning`() async {
        var initialState = AgentOverviewLoadFeature.State()
        initialState.isLoading = true
        let snapshot = Self.snapshot(hasLiveData: true)
        let store = TestStore(initialState: initialState) {
            AgentOverviewLoadFeature()
        }

        await store.send(.refreshFinished(.init(snapshot: snapshot, requestID: 1))) {
            $0.overview = snapshot
            $0.isLoading = false
        }
    }

    @Test func `empty live data snapshot keeps warning`() async {
        var initialState = AgentOverviewLoadFeature.State()
        initialState.isLoading = true
        let snapshot = Self.snapshot(hasLiveData: false)
        let store = TestStore(initialState: initialState) {
            AgentOverviewLoadFeature()
        }

        await store.send(.refreshFinished(.init(snapshot: snapshot, requestID: 1))) {
            $0.overview = snapshot
            $0.errorText = "Live overview could not load yet."
            $0.isLoading = false
        }
    }

    private static func snapshot(hasLiveData: Bool) -> AgentOverviewSnapshot {
        AgentOverviewSnapshot(
            skills: nil,
            presence: [],
            cronStatus: nil,
            cronJobs: [],
            dreaming: nil,
            dreamDiary: hasLiveData
                ? DreamDiaryLite(
                    agentId: "mobile",
                    found: true,
                    path: "/tmp/dream.md",
                    content: nil,
                    updatedAtMs: 1)
                : nil,
            usage: nil,
            activeAgentId: "mobile",
            agentSkillFilter: nil,
            loadedAt: Date(timeIntervalSince1970: 1_700_000_000))
    }
}

@MainActor
struct AgentOverviewFilterFeatureTests {
    @Test func `search button toggles search field`() async {
        let store = TestStore(initialState: AgentOverviewFilterFeature.State()) {
            AgentOverviewFilterFeature()
        }

        await store.send(.searchButtonTapped) {
            $0.searchPresented = true
        }
        await store.send(.searchButtonTapped) {
            $0.searchPresented = false
        }
    }

    @Test func `filter and search text changes update state`() async {
        let store = TestStore(initialState: AgentOverviewFilterFeature.State()) {
            AgentOverviewFilterFeature()
        }

        await store.send(.rosterFilterChanged(.online)) {
            $0.rosterFilter = .online
        }
        await store.send(.searchTextChanged(.init(text: "main"))) {
            $0.searchText = "main"
        }
    }

    @Test func `clear filters resets roster filter and search text`() async {
        var initialState = AgentOverviewFilterFeature.State()
        initialState.rosterFilter = .ready
        initialState.searchText = "worker"
        let store = TestStore(initialState: initialState) {
            AgentOverviewFilterFeature()
        }

        await store.send(.clearFiltersTapped) {
            $0.rosterFilter = .all
            $0.searchText = ""
        }
    }

    @Test func `active filters reflect trimmed search and non default roster`() {
        var state = AgentOverviewFilterFeature.State()
        #expect(!state.hasActiveFilters)

        state.searchText = "  main  "
        #expect(state.hasActiveFilters)

        state.searchText = "   "
        state.rosterFilter = .online
        #expect(state.hasActiveFilters)
    }
}
