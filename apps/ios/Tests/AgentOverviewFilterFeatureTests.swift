import ComposableArchitecture
import Foundation
import Testing
@testable import OpenClaw

@MainActor
struct AgentClawHubSearchFeatureTests {
    @Test func `query changes update search text`() async {
        let store = TestStore(initialState: AgentClawHubSearchFeature.State()) {
            AgentClawHubSearchFeature()
        }

        await store.send(.queryChanged("memory")) {
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
        await store.send(.searchFinished([result])) {
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

        await store.send(.searchFailed("Search failed.")) {
            $0.errorText = "Search failed."
            $0.isLoading = false
        }
    }

    @Test func `install lifecycle owns busy slug`() async {
        let store = TestStore(initialState: AgentClawHubSearchFeature.State()) {
            AgentClawHubSearchFeature()
        }

        await store.send(.installRequested(slug: "memory-plus")) {
            $0.installingSlug = "memory-plus"
        }
        await store.send(.installFinished(slug: "memory-plus")) {
            $0.installingSlug = nil
        }
    }

    @Test func `install failure clears matching slug and records error`() async {
        var initialState = AgentClawHubSearchFeature.State()
        initialState.installingSlug = "memory-plus"
        let store = TestStore(initialState: initialState) {
            AgentClawHubSearchFeature()
        }

        await store.send(.installFailed(slug: "memory-plus", message: "Install failed.")) {
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

        await store.send(.refreshRequested(gatewayConnected: true, force: false, activeAgentID: "mobile")) {
            $0.isLoading = true
            $0.nextRefreshRequestID = 1
            $0.refreshRequest = AgentOverviewLoadFeature.RefreshRequest(id: 1, activeAgentID: "mobile")
        }
        await store.send(.refreshLaunched(requestID: 1)) {
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

        await store.send(.refreshRequested(gatewayConnected: false, force: false, activeAgentID: "mobile")) {
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

        await store.send(.refreshRequested(gatewayConnected: true, force: false, activeAgentID: "mobile"))
    }

    @Test func `finished refresh stores snapshot and clears empty live data warning`() async {
        var initialState = AgentOverviewLoadFeature.State()
        initialState.isLoading = true
        let snapshot = Self.snapshot(hasLiveData: true)
        let store = TestStore(initialState: initialState) {
            AgentOverviewLoadFeature()
        }

        await store.send(.refreshFinished(snapshot, requestID: 1)) {
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

        await store.send(.refreshFinished(snapshot, requestID: 1)) {
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
        await store.send(.searchTextChanged("main")) {
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
