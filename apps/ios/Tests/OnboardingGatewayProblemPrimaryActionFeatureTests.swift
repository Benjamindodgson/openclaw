import ComposableArchitecture
import OpenClawKit
import Testing
@testable import OpenClaw

@Suite(.serialized) struct OnboardingGatewayProblemPrimaryActionFeatureTests {
    @Test @MainActor func `primary action reducer maps onboarding decisions`() async {
        let store = TestStore(initialState: OnboardingGatewayProblemPrimaryActionFeature.State()) {
            OnboardingGatewayProblemPrimaryActionFeature()
        }

        await store.send(.primaryActionTapped(.init(problem: Self.resetProblem()))) {
            $0.primaryActionDecision = .resetAndScan
        }
        await store.send(.primaryActionDecisionHandled) {
            $0.primaryActionDecision = nil
        }

        let rotatedCertificateProblem = Self.rotatedCertificateProblem()
        await store.send(.primaryActionTapped(.init(problem: rotatedCertificateProblem))) {
            $0.primaryActionDecision = .trustRotatedCertificate(rotatedCertificateProblem)
        }
        await store.send(.primaryActionDecisionHandled) {
            $0.primaryActionDecision = nil
        }

        let protocolMismatchProblem = Self.protocolMismatchProblem()
        await store.send(.primaryActionTapped(.init(problem: protocolMismatchProblem))) {
            $0.primaryActionDecision = .openProtocolMismatchHelp(protocolMismatchProblem)
        }
        await store.send(.primaryActionDecisionHandled) {
            $0.primaryActionDecision = nil
        }

        await store.send(.primaryActionTapped(.init(problem: Self.retryableProblem()))) {
            $0.primaryActionDecision = .retryConnection
        }
        await store.send(.primaryActionDecisionHandled) {
            $0.primaryActionDecision = nil
        }

        await store.send(.primaryActionTapped(.init(problem: Self.noActionProblem())))
    }

    @Test func `primary action title uses onboarding labels`() {
        #expect(OnboardingGatewayProblemPrimaryActionFeature.title(for: Self.resetProblem()) == "Scan QR again")
        #expect(
            OnboardingGatewayProblemPrimaryActionFeature.title(for: Self.rotatedCertificateProblem())
                == "Trust certificate")
        #expect(OnboardingGatewayProblemPrimaryActionFeature.title(for: Self.protocolMismatchProblem()) == "Update app")
        #expect(OnboardingGatewayProblemPrimaryActionFeature.title(for: Self.retryableProblem()) == "Try again")
        #expect(OnboardingGatewayProblemPrimaryActionFeature.title(for: Self.noActionProblem()) == nil)
    }

    private static func resetProblem() -> GatewayConnectionProblem {
        GatewayConnectionProblem(
            kind: .gatewayAuthTokenMismatch,
            owner: .gateway,
            title: "Gateway setup required",
            message: "Open settings to review gateway configuration.",
            retryable: false,
            pauseReconnect: true)
    }

    private static func rotatedCertificateProblem() -> GatewayConnectionProblem {
        GatewayConnectionProblem(
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
    }

    private static func protocolMismatchProblem() -> GatewayConnectionProblem {
        GatewayConnectionProblem(
            kind: .protocolMismatch,
            owner: .iphone,
            title: "App update required",
            message: "This app is older than the gateway.",
            actionLabel: "Update app",
            retryable: false,
            pauseReconnect: true)
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

    private static func noActionProblem() -> GatewayConnectionProblem {
        GatewayConnectionProblem(
            kind: .unknown,
            owner: .gateway,
            title: "Gateway rejected credentials",
            message: "Scan a fresh QR code or update token/password.",
            retryable: false,
            pauseReconnect: false)
    }
}
