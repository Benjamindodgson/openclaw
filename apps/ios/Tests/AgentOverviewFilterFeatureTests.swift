import ComposableArchitecture
import Testing
@testable import OpenClaw

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
