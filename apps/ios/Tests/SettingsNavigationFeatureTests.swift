import ComposableArchitecture
import Testing
@testable import OpenClaw

@MainActor
struct SettingsNavigationFeatureTests {
    @Test func `initial route sets path once`() async {
        let store = TestStore(initialState: SettingsNavigationFeature.State()) {
            SettingsNavigationFeature()
        }

        await store.send(.initialRouteRequested(.voice)) {
            $0.navigationPath = [.voice]
        }
        await store.send(.initialRouteRequested(.voice))
    }

    @Test func `missing initial route leaves path unchanged`() async {
        let store = TestStore(initialState: SettingsNavigationFeature.State()) {
            SettingsNavigationFeature()
        }

        await store.send(.initialRouteRequested(nil))
    }

    @Test func `route opened replaces navigation path`() async {
        var initialState = SettingsNavigationFeature.State()
        initialState.navigationPath = [.gateway]
        let store = TestStore(initialState: initialState) {
            SettingsNavigationFeature()
        }

        await store.send(.routeOpened(.notifications)) {
            $0.navigationPath = [.notifications]
        }
    }

    @Test func `swift ui path changes replace reducer path`() async {
        var initialState = SettingsNavigationFeature.State()
        initialState.navigationPath = [.gateway]
        let store = TestStore(initialState: initialState) {
            SettingsNavigationFeature()
        }

        await store.send(.navigationPathChanged([.gateway, .voice])) {
            $0.navigationPath = [.gateway, .voice]
        }
    }

    @Test func `settings presentation opens and dismisses talk issue details`() async {
        let store = TestStore(initialState: SettingsPresentationFeature.State()) {
            SettingsPresentationFeature()
        }

        await store.send(.talkIssueDetailsButtonTapped) {
            $0.showTalkIssueDetails = true
        }
        await store.send(.talkIssueDetailsDismissed) {
            $0.showTalkIssueDetails = false
        }
    }

    @Test func `settings presentation opens and dismisses gateway problem details`() async {
        let store = TestStore(initialState: SettingsPresentationFeature.State()) {
            SettingsPresentationFeature()
        }

        await store.send(.gatewayProblemDetailsButtonTapped) {
            $0.showGatewayProblemDetails = true
        }
        await store.send(.gatewayProblemDetailsDismissed) {
            $0.showGatewayProblemDetails = false
        }
    }
}
