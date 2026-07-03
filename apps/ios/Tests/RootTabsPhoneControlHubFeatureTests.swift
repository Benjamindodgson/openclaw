import ComposableArchitecture
import Testing
@testable import OpenClaw

@MainActor
struct RootTabsPhoneControlHubFeatureTests {
    @Test func `detail destination appends to navigation path`() async {
        let store = TestStore(initialState: RootTabsPhoneControlHubFeature.State()) {
            RootTabsPhoneControlHubFeature()
        }

        await store.send(.detailDestinationTapped(.sessions)) {
            $0.navigationPath = [.sessions]
        }
    }

    @Test func `root destination clears detail path`() async {
        var initialState = RootTabsPhoneControlHubFeature.State()
        initialState.navigationPath = [.overview, .sessions]
        let store = TestStore(initialState: initialState) {
            RootTabsPhoneControlHubFeature()
        }

        await store.send(.rootDestinationTapped(.gateway)) {
            $0.navigationPath = []
        }
    }

    @Test func `back action pops the last detail destination`() async {
        var initialState = RootTabsPhoneControlHubFeature.State()
        initialState.navigationPath = [.overview, .sessions]
        let store = TestStore(initialState: initialState) {
            RootTabsPhoneControlHubFeature()
        }

        await store.send(.detailBackTapped) {
            $0.navigationPath = [.overview]
        }
    }

    @Test func `initial detail destination is applied once`() async {
        let store = TestStore(initialState: RootTabsPhoneControlHubFeature.State()) {
            RootTabsPhoneControlHubFeature()
        }

        await store.send(.initialDestinationAppeared(destination: .sessions, opensRootTab: false)) {
            $0.didApplyInitialDestination = true
            $0.navigationPath = [.sessions]
        }
        await store.send(.initialDestinationAppeared(destination: .docs, opensRootTab: false))
    }

    @Test func `initial root destination only marks initial application`() async {
        var initialState = RootTabsPhoneControlHubFeature.State()
        initialState.navigationPath = [.sessions]
        let store = TestStore(initialState: initialState) {
            RootTabsPhoneControlHubFeature()
        }

        await store.send(.initialDestinationAppeared(destination: .gateway, opensRootTab: true)) {
            $0.didApplyInitialDestination = true
            $0.navigationPath = []
        }
    }

    @Test func `swift ui path changes replace reducer path`() async {
        var initialState = RootTabsPhoneControlHubFeature.State()
        initialState.navigationPath = [.overview]
        let store = TestStore(initialState: initialState) {
            RootTabsPhoneControlHubFeature()
        }

        await store.send(.navigationPathChanged([.overview, .sessions])) {
            $0.navigationPath = [.overview, .sessions]
        }
    }
}
