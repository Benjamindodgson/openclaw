import ComposableArchitecture
import Testing
@testable import OpenClaw

@MainActor
struct AgentNavigationFeatureTests {
    @Test func `swift ui path changes replace reducer path`() async {
        let store = TestStore(initialState: AgentNavigationFeature.State()) {
            AgentNavigationFeature()
        }

        await store.send(.navigationPathChanged(.init(path: .init(routes: [.instances])))) {
            $0.navigationPathState = .init(routes: [.instances])
        }
    }

    @Test func `multi level path changes are preserved`() async {
        var initialState = AgentNavigationFeature.State()
        initialState.navigationPathState = .init(routes: [.skills])
        let store = TestStore(initialState: initialState) {
            AgentNavigationFeature()
        }

        await store.send(.navigationPathChanged(.init(path: .init(routes: [.skills, .cron])))) {
            $0.navigationPathState = .init(routes: [.skills, .cron])
        }
    }
}
