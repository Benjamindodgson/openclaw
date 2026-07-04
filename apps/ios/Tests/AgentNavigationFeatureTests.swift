import ComposableArchitecture
import Testing
@testable import OpenClaw

@MainActor
struct AgentNavigationFeatureTests {
    @Test func `swift ui path changes replace reducer path`() async {
        let store = TestStore(initialState: AgentNavigationFeature.State()) {
            AgentNavigationFeature()
        }

        await store.send(.navigationPathChanged(.init(path: [.instances]))) {
            $0.navigationPath = [.instances]
        }
    }

    @Test func `multi level path changes are preserved`() async {
        var initialState = AgentNavigationFeature.State()
        initialState.navigationPath = [.skills]
        let store = TestStore(initialState: initialState) {
            AgentNavigationFeature()
        }

        await store.send(.navigationPathChanged(.init(path: [.skills, .cron]))) {
            $0.navigationPath = [.skills, .cron]
        }
    }
}
