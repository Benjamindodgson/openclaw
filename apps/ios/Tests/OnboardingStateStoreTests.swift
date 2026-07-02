import ComposableArchitecture
import Foundation
import Testing
@testable import OpenClaw

@Suite(.serialized) struct OnboardingStateStoreTests {
    @Test @MainActor func `should present when fresh and disconnected`() {
        let testDefaults = self.makeDefaults()
        let defaults = testDefaults.defaults
        defer { self.reset(testDefaults) }

        let appModel = NodeAppModel()
        appModel.gatewayServerName = nil
        #expect(OnboardingStateStore.shouldPresentOnLaunch(
            appModel: appModel,
            defaults: defaults,
            hasSavedGatewayConnection: false))
    }

    @Test @MainActor func `does not present when connected`() {
        let testDefaults = self.makeDefaults()
        let defaults = testDefaults.defaults
        defer { self.reset(testDefaults) }

        let appModel = NodeAppModel()
        appModel.gatewayServerName = "gateway"
        #expect(!OnboardingStateStore.shouldPresentOnLaunch(
            appModel: appModel,
            defaults: defaults,
            hasSavedGatewayConnection: false))
    }

    @Test @MainActor func `does not present for saved gateway before reconnect completes`() {
        let testDefaults = self.makeDefaults()
        let defaults = testDefaults.defaults
        defer { self.reset(testDefaults) }

        let appModel = NodeAppModel()
        appModel.gatewayServerName = nil
        #expect(!OnboardingStateStore.shouldPresentOnLaunch(
            appModel: appModel,
            defaults: defaults,
            hasSavedGatewayConnection: true))
    }

    @Test @MainActor func `mark completed persists mode`() {
        let testDefaults = self.makeDefaults()
        let defaults = testDefaults.defaults
        defer { self.reset(testDefaults) }

        let appModel = NodeAppModel()
        appModel.gatewayServerName = nil

        OnboardingStateStore.markCompleted(mode: .remoteDomain, defaults: defaults)
        #expect(OnboardingStateStore.lastMode(defaults: defaults) == .remoteDomain)
        #expect(!OnboardingStateStore.shouldPresentOnLaunch(
            appModel: appModel,
            defaults: defaults,
            hasSavedGatewayConnection: false))
    }

    @Test func `first run intro defaults to visible then persists`() {
        let testDefaults = self.makeDefaults()
        let defaults = testDefaults.defaults
        defer { self.reset(testDefaults) }

        #expect(OnboardingStateStore.shouldPresentFirstRunIntro(defaults: defaults))

        OnboardingStateStore.markFirstRunIntroSeen(defaults: defaults)
        #expect(!OnboardingStateStore.shouldPresentFirstRunIntro(defaults: defaults))
    }

    @Test @MainActor func `reset clears completion and intro seen`() {
        let testDefaults = self.makeDefaults()
        let defaults = testDefaults.defaults
        defer { self.reset(testDefaults) }

        OnboardingStateStore.markCompleted(mode: .homeNetwork, defaults: defaults)
        OnboardingStateStore.markFirstRunIntroSeen(defaults: defaults)

        OnboardingStateStore.reset(defaults: defaults)

        let appModel = NodeAppModel()
        appModel.gatewayServerName = nil

        #expect(OnboardingStateStore.shouldPresentOnLaunch(
            appModel: appModel,
            defaults: defaults,
            hasSavedGatewayConnection: false))
        #expect(OnboardingStateStore.shouldPresentFirstRunIntro(defaults: defaults))
        #expect(OnboardingStateStore.lastMode(defaults: defaults) == .homeNetwork)
    }

    @Test @MainActor func `reducer updates presentation state`() async {
        let store = TestStore(initialState: OnboardingStateFeature.State(
            isCompleted: false,
            firstRunIntroSeen: false,
            hasSavedGatewayConnection: false,
            gatewayServerName: nil))
        {
            OnboardingStateFeature()
        }

        await store.send(.gatewaySnapshotChanged(gatewayServerName: "gateway", hasSavedGatewayConnection: false)) {
            $0.gatewayServerName = "gateway"
            $0.shouldPresentOnLaunch = false
        }

        await store.send(.gatewaySnapshotChanged(gatewayServerName: nil, hasSavedGatewayConnection: true)) {
            $0.gatewayServerName = nil
            $0.hasSavedGatewayConnection = true
        }

        await store.send(.gatewaySnapshotChanged(gatewayServerName: nil, hasSavedGatewayConnection: false)) {
            $0.hasSavedGatewayConnection = false
            $0.shouldPresentOnLaunch = true
        }

        await store.send(.markCompleted(.remoteDomain)) {
            $0.isCompleted = true
            $0.lastMode = .remoteDomain
            $0.shouldPresentOnLaunch = false
        }

        await store.send(.reset) {
            $0.isCompleted = false
            $0.firstRunIntroSeen = false
            $0.shouldPresentOnLaunch = true
        }

        await store.send(.markFirstRunIntroSeen) {
            $0.firstRunIntroSeen = true
            $0.shouldPresentFirstRunIntro = false
        }
    }

    private struct TestDefaults {
        var suiteName: String
        var defaults: UserDefaults
    }

    private func makeDefaults() -> TestDefaults {
        let suiteName = "OnboardingStateStoreTests.\(UUID().uuidString)"
        return TestDefaults(
            suiteName: suiteName,
            defaults: UserDefaults(suiteName: suiteName) ?? .standard)
    }

    private func reset(_ defaults: TestDefaults) {
        defaults.defaults.removePersistentDomain(forName: defaults.suiteName)
    }
}
