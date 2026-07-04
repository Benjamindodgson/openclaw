import ComposableArchitecture
import Foundation
import Testing
@testable import OpenClaw

@MainActor
struct AgentDreamingDestinationFeatureTests {
    @Test func `dream diary selection updates reducer state`() async {
        let store = TestStore(initialState: AgentDreamingDestinationFeature.State()) {
            AgentDreamingDestinationFeature(client: Self.client())
        }

        await store.send(.dreamDiaryDaySelected(.init(dayID: "2026-07-03"))) {
            $0.selectedDreamDiaryDayID = "2026-07-03"
        }
    }

    @Test func `maintenance action is ignored while gateway is disconnected`() async {
        let store = TestStore(initialState: AgentDreamingDestinationFeature.State()) {
            AgentDreamingDestinationFeature(client: Self.client())
        }

        await store.send(.dreamActionTapped(.init(action: .backfill, gatewayConnected: false)))
    }

    @Test func `maintenance action stores success summary`() async {
        let store = TestStore(initialState: AgentDreamingDestinationFeature.State()) {
            AgentDreamingDestinationFeature(client: Self.client(run: { action in "\(action.title) complete." }))
        }

        await store.send(.dreamActionTapped(.init(action: .repair, gatewayConnected: true))) {
            $0.busyAction = .repair
            $0.statusText = nil
        }
        await store.receive(.dreamActionResponse(.success("Repair complete."))) {
            $0.busyAction = nil
            $0.statusText = "Repair complete."
        }
    }

    @Test func `maintenance action stores failure summary`() async {
        let store = TestStore(initialState: AgentDreamingDestinationFeature.State()) {
            AgentDreamingDestinationFeature(client: Self.client(run: { _ in throw DreamingFailure.failed }))
        }

        await store.send(.dreamActionTapped(.init(action: .dedupe, gatewayConnected: true))) {
            $0.busyAction = .dedupe
            $0.statusText = nil
        }
        await store.receive(.dreamActionResponse(.failure(.failed("dream failed")))) {
            $0.busyAction = nil
            $0.statusText = "dream failed"
        }
    }

    @Test func `maintenance summary reports changed counts`() throws {
        let data = try #require(
            #"{"written":2,"replaced":1,"removedEntries":3,"changed":true}"#.data(using: .utf8))

        #expect(
            AgentDreamingMaintenanceClient.summary(action: .backfill, data: data) ==
                "Backfill: 2 written, 1 replaced, 3 removed, artifacts repaired.")
    }

    private static func client(
        run: @escaping @Sendable @MainActor (_ action: AgentDreamAction) async throws -> String = {
            "\($0.title) complete."
        }) -> AgentDreamingMaintenanceClient
    {
        AgentDreamingMaintenanceClient(run: run)
    }
}

private enum DreamingFailure: LocalizedError {
    case failed

    var errorDescription: String? {
        "dream failed"
    }
}
