import ComposableArchitecture
import Testing
@testable import OpenClaw

@MainActor
struct GatewayDiscoveryDebugLogFeatureTests {
    @Test func `copy button copies formatted discovery log`() async {
        let probe = GatewayDiscoveryDebugLogClipboardProbe()
        let store = TestStore(initialState: GatewayDiscoveryDebugLogFeature.State()) {
            GatewayDiscoveryDebugLogFeature(clipboard: probe.client)
        }

        await store.send(.copyButtonTapped("2026-07-02T20:00:00.000Z found gateway"))
        await store.finish()

        #expect(probe.copiedText == "2026-07-02T20:00:00.000Z found gateway")
    }
}

private final class GatewayDiscoveryDebugLogClipboardProbe: @unchecked Sendable {
    var copiedText: String?

    var client: GatewayDiscoveryDebugLogClipboardClient {
        GatewayDiscoveryDebugLogClipboardClient(copy: { text in
            self.copiedText = text
        })
    }
}
