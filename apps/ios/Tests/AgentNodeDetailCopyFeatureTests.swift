import ComposableArchitecture
import Testing
@testable import OpenClaw

@MainActor
struct AgentNodeDetailCopyFeatureTests {
    @Test func `copy button copies node detail value`() async {
        let probe = AgentNodeClipboardProbe()
        let store = TestStore(initialState: AgentNodeDetailCopyFeature.State()) {
            AgentNodeDetailCopyFeature(clipboard: probe.client)
        }

        await store.send(.copyButtonTapped("node-instance-1"))
        await store.finish()

        #expect(probe.copiedText == "node-instance-1")
    }
}

private final class AgentNodeClipboardProbe: @unchecked Sendable {
    var copiedText: String?

    var client: AgentNodeClipboardClient {
        AgentNodeClipboardClient(copy: { text in
            self.copiedText = text
        })
    }
}
