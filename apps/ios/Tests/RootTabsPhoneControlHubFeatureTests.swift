import ComposableArchitecture
import SwiftUI
import Testing
@testable import OpenClaw

@MainActor
struct RootTabsPhoneControlHubFeatureTests {
    @Test func `detail destination appends to navigation path`() async {
        let store = TestStore(initialState: RootTabsPhoneControlHubFeature.State()) {
            RootTabsPhoneControlHubFeature()
        }

        await store.send(.detailDestinationTapped(.sessions)) {
            $0.navigationPathState = .init(destinations: [.sessions])
        }
    }

    @Test func `root destination clears detail path`() async {
        var initialState = RootTabsPhoneControlHubFeature.State()
        initialState.navigationPathState = .init(destinations: [.overview, .sessions])
        let store = TestStore(initialState: initialState) {
            RootTabsPhoneControlHubFeature()
        }

        await store.send(.rootDestinationTapped(.gateway)) {
            $0.navigationPathState = .init(destinations: [])
        }
    }

    @Test func `back action pops the last detail destination`() async {
        var initialState = RootTabsPhoneControlHubFeature.State()
        initialState.navigationPathState = .init(destinations: [.overview, .sessions])
        let store = TestStore(initialState: initialState) {
            RootTabsPhoneControlHubFeature()
        }

        await store.send(.detailBackTapped) {
            $0.navigationPathState = .init(destinations: [.overview])
        }
    }

    @Test func `initial detail destination is applied once`() async {
        let store = TestStore(initialState: RootTabsPhoneControlHubFeature.State()) {
            RootTabsPhoneControlHubFeature()
        }

        await store.send(.initialDestinationAppeared(.detail(.sessions))) {
            $0.initialDestinationApplication = .init(didApply: true)
            $0.navigationPathState = .init(destinations: [.sessions])
        }
        await store.send(.initialDestinationAppeared(.detail(.docs)))
    }

    @Test func `initial root destination only marks initial application`() async {
        var initialState = RootTabsPhoneControlHubFeature.State()
        initialState.navigationPathState = .init(destinations: [.sessions])
        let store = TestStore(initialState: initialState) {
            RootTabsPhoneControlHubFeature()
        }

        await store.send(.initialDestinationAppeared(.rootTab(.gateway))) {
            $0.initialDestinationApplication = .init(didApply: true)
            $0.navigationPathState = .init(destinations: [])
        }
    }

    @Test func `swift ui path changes replace reducer path`() async {
        var initialState = RootTabsPhoneControlHubFeature.State()
        initialState.navigationPathState = .init(destinations: [.overview])
        let store = TestStore(initialState: initialState) {
            RootTabsPhoneControlHubFeature()
        }

        await store.send(.navigationPathChanged(.init(path: .init(destinations: [.overview, .sessions])))) {
            $0.navigationPathState = .init(destinations: [.overview, .sessions])
        }
    }

    @Test func `presentation refresh updates reducer-owned header state`() async {
        let presentation = Self.presentation(
            gatewayDisplayState: .connected,
            gatewayServerName: "  Studio Gateway  ",
            selectedAgentId: "sidekick",
            gatewayAgents: [
                RootTabsPhoneControlHubAgent(id: "sidekick", name: "  Sidekick  "),
            ])
        let store = TestStore(initialState: RootTabsPhoneControlHubFeature.State()) {
            RootTabsPhoneControlHubFeature()
        }

        await store.send(.presentationChanged(.init(presentation: presentation))) {
            $0.presentation = presentation
        }

        #expect(store.state.presentation.activeAgentTitle == "Sidekick (sidekick)")
        #expect(store.state.presentation.gatewayDisplayLabel == "Studio Gateway")
        #expect(store.state.presentation.gatewayStateText == "Online")
        #expect(store.state.presentation.gatewayStateColor == OpenClawBrand.ok)
    }

    @Test func `header presentation trims app model inputs and owns gateway fallbacks`() {
        let remoteFallback = Self.presentation(
            gatewayDisplayState: .connecting,
            gatewayServerName: "   ",
            gatewayRemoteAddress: "  mac.local:4455  ",
            selectedAgentId: nil,
            gatewayDefaultAgentId: "main",
            gatewayAgents: [
                RootTabsPhoneControlHubAgent(id: "main", name: nil),
            ],
            activeAgentName: "   ")
        let statusFallback = Self.presentation(
            gatewayDisplayState: .error,
            gatewayServerName: nil,
            gatewayRemoteAddress: "   ",
            gatewayDisplayStatusText: "Pairing required",
            selectedAgentId: "missing",
            gatewayDefaultAgentId: nil,
            gatewayAgents: [],
            activeAgentName: "  Control Agent  ")
        let offline = Self.presentation(gatewayDisplayState: .disconnected)

        #expect(remoteFallback.activeAgentTitle == "main")
        #expect(remoteFallback.gatewayDisplayLabel == "mac.local:4455")
        #expect(remoteFallback.gatewayStateText == "Connecting")
        #expect(remoteFallback.gatewayStateColor == OpenClawBrand.accent)
        #expect(statusFallback.activeAgentTitle == "Control Agent")
        #expect(statusFallback.gatewayDisplayLabel == "Pairing required")
        #expect(statusFallback.gatewayStateText == "Attention")
        #expect(statusFallback.gatewayStateColor == OpenClawBrand.warn)
        #expect(offline.activeAgentTitle == "Default Agent")
        #expect(offline.gatewayDisplayLabel == "Offline")
        #expect(offline.gatewayStateText == "Offline")
        #expect(offline.gatewayStateColor == .secondary)
    }

    private static func presentation(
        gatewayDisplayState: GatewayDisplayState = .connected,
        gatewayServerName: String? = nil,
        gatewayRemoteAddress: String? = nil,
        gatewayDisplayStatusText: String = "Offline",
        selectedAgentId: String? = nil,
        gatewayDefaultAgentId: String? = nil,
        gatewayAgents: [RootTabsPhoneControlHubAgent] = [],
        activeAgentName: String = "Default Agent") -> RootTabsPhoneControlHubPresentationState
    {
        RootTabsPhoneControlHubPresentationState(
            gatewayDisplayState: gatewayDisplayState,
            gatewayServerName: gatewayServerName,
            gatewayRemoteAddress: gatewayRemoteAddress,
            gatewayDisplayStatusText: gatewayDisplayStatusText,
            selectedAgentId: selectedAgentId,
            gatewayDefaultAgentId: gatewayDefaultAgentId,
            gatewayAgents: gatewayAgents,
            activeAgentName: activeAgentName)
    }
}
