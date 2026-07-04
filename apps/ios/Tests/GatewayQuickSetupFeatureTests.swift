import ComposableArchitecture
import Foundation
import Network
import OpenClawKit
import Testing
@testable import OpenClaw

@MainActor
struct GatewayQuickSetupFeatureTests {
    @Test func `connect button tracks progress and stores error`() async {
        let probe = GatewayQuickSetupProbe()
        let candidate = Self.discoveredGateway(stableID: "shown-gateway")
        probe.nextConnectError = "Failed to resolve the discovered gateway endpoint."
        var initialState = GatewayQuickSetupFeature.State()
        initialState.connectError = "Previous error"
        let store = TestStore(initialState: initialState) {
            GatewayQuickSetupFeature(client: probe.client)
        }

        await store.send(.connectButtonTapped(.init(candidate: candidate))) {
            $0.connectError = nil
            $0.connecting = true
        }
        await store.receive(.connectResponse(.init(
            error: "Failed to resolve the discovered gateway endpoint.")))
        {
            $0.connecting = false
            $0.connectError = "Failed to resolve the discovered gateway endpoint."
        }
        await store.finish()

        #expect(probe.connectedGateways.map(\.stableID) == ["shown-gateway"])
    }

    @Test func `details actions update sheet presentation`() async {
        let store = TestStore(initialState: GatewayQuickSetupFeature.State()) {
            GatewayQuickSetupFeature()
        }

        await store.send(.gatewayProblemDetailsButtonTapped) {
            $0.showGatewayProblemDetails = true
        }
        await store.send(.gatewayProblemDetailsDismissed) {
            $0.showGatewayProblemDetails = false
        }
    }

    @Test func `retryable gateway problem connects when a candidate exists`() async {
        let probe = GatewayQuickSetupProbe()
        let candidate = Self.discoveredGateway(stableID: "retry-gateway")
        let problem = Self.retryableProblem()
        let store = TestStore(initialState: GatewayQuickSetupFeature.State()) {
            GatewayQuickSetupFeature(client: probe.client)
        }

        await store.send(.gatewayProblemPrimaryActionTapped(.init(problem: problem, candidate: candidate))) {
            $0.connecting = true
        }
        await store.receive(.connectResponse(.init(error: nil))) {
            $0.connecting = false
        }
        await store.finish()

        #expect(probe.connectedGateways.map(\.stableID) == ["retry-gateway"])
    }

    @Test func `retryable gateway problem does not connect without a candidate`() async {
        let probe = GatewayQuickSetupProbe()
        let store = TestStore(initialState: GatewayQuickSetupFeature.State()) {
            GatewayQuickSetupFeature(client: probe.client)
        }

        await store.send(.gatewayProblemPrimaryActionTapped(.init(problem: Self.retryableProblem(), candidate: nil)))
        await store.finish()

        #expect(probe.connectedGateways.isEmpty)
    }

    @Test func `protocol mismatch opens help instead of connecting`() async {
        let probe = GatewayQuickSetupProbe()
        let problem = GatewayConnectionProblem(
            kind: .protocolMismatch,
            owner: .iphone,
            title: "App update required",
            message: "This app is older than the gateway.",
            actionLabel: "Update app",
            docsURL: URL(string: "https://docs.openclaw.ai/gateway/protocol")!,
            retryable: false,
            pauseReconnect: true)
        let store = TestStore(initialState: GatewayQuickSetupFeature.State()) {
            GatewayQuickSetupFeature(client: probe.client)
        }

        await store.send(.gatewayProblemPrimaryActionTapped(.init(
            problem: problem,
            candidate: Self.discoveredGateway(stableID: "ignored-gateway"))))
        await store.finish()

        #expect(probe.connectedGateways.isEmpty)
        #expect(probe.openedProblems == [problem])
    }

    @Test func `rotated certificate problem trusts certificate instead of connecting`() async {
        let probe = GatewayQuickSetupProbe()
        let problem = GatewayConnectionProblem(
            kind: .tlsPinMismatch,
            owner: .iphone,
            title: "Gateway certificate changed",
            message: "The gateway certificate fingerprint changed.",
            retryable: false,
            pauseReconnect: true,
            tlsStoreKey: "gateway-1",
            tlsExpectedFingerprint: "old",
            tlsObservedFingerprint: "new",
            tlsSystemTrustOk: true)
        let store = TestStore(initialState: GatewayQuickSetupFeature.State()) {
            GatewayQuickSetupFeature(client: probe.client)
        }

        await store.send(.gatewayProblemPrimaryActionTapped(.init(
            problem: problem,
            candidate: Self.discoveredGateway(stableID: "ignored-gateway"))))
        await store.finish()

        #expect(probe.connectedGateways.isEmpty)
        #expect(probe.trustedProblems == [problem])
    }

    private static func retryableProblem() -> GatewayConnectionProblem {
        GatewayConnectionProblem(
            kind: .timeout,
            owner: .network,
            title: "Connection timed out",
            message: "Check the gateway network path.",
            actionLabel: "Try again",
            retryable: true,
            pauseReconnect: false)
    }

    private static func discoveredGateway(stableID: String) -> GatewayDiscoveryModel.DiscoveredGateway {
        GatewayDiscoveryModel.DiscoveredGateway(
            name: "Test",
            endpoint: .service(name: "Test", type: "_openclaw-gw._tcp", domain: "local.", interface: nil),
            stableID: stableID,
            debugID: "debug",
            lanHost: nil,
            tailnetDns: nil,
            gatewayPort: nil,
            canvasPort: nil,
            tlsEnabled: true,
            tlsFingerprintSha256: nil,
            cliPath: nil)
    }
}

private final class GatewayQuickSetupProbe: @unchecked Sendable {
    var nextConnectError: String?
    var connectedGateways: [GatewayDiscoveryModel.DiscoveredGateway] = []
    var openedProblems: [GatewayConnectionProblem] = []
    var trustedProblems: [GatewayConnectionProblem] = []

    var client: GatewayQuickSetupClient {
        GatewayQuickSetupClient(
            connect: { gateway in
                self.connectedGateways.append(gateway)
                return self.nextConnectError
            },
            trustRotatedGatewayCertificate: { problem in
                self.trustedProblems.append(problem)
                return true
            },
            openProtocolMismatchHelpIfNeeded: { problem in
                self.openedProblems.append(problem)
                return true
            })
    }
}
