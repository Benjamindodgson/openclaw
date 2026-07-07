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

        await store.send(.dreamDiaryDaySelected(.init(dayID: .init(value: "2026-07-03")))) {
            $0.selectedDreamDiaryDayID = .init(value: "2026-07-03")
        }
    }

    @Test func `dreaming phases are derived by reducer state`() {
        let state = AgentDreamingDestinationFeature.State()
        let rows = state.dreamingPhases(from: [
            "rem": .init(enabled: true, cron: "0 2 * * *", managedCronPresent: true, nextRunAtMs: 1),
            "unknown": .init(enabled: true, cron: nil, managedCronPresent: true, nextRunAtMs: nil),
            "light": .init(enabled: false, cron: nil, managedCronPresent: false, nextRunAtMs: nil),
        ])

        #expect(rows.map(\.id) == ["light", "rem"])
        #expect(rows.map(\.title) == ["Light", "Rem"])
        #expect(rows.first?.status.enabled == false)
        #expect(rows.last?.status.managedCronPresent == true)
    }

    @Test func `selected dream diary day is derived by reducer state`() {
        let days = [
            DreamDiaryDay(id: "2026-07-01", title: "July 1, 2026", body: "First", entryCount: 1, hasDatedEntry: true),
            DreamDiaryDay(id: "2026-07-02", title: "July 2, 2026", body: "Second", entryCount: 2, hasDatedEntry: true),
        ]
        var state = AgentDreamingDestinationFeature.State()

        #expect(state.selectedDreamDiaryDay(from: days) == days[1])

        state.selectedDreamDiaryDayID = .init(value: "2026-07-01")
        #expect(state.selectedDreamDiaryDay(from: days) == days[0])

        state.selectedDreamDiaryDayID = .init(value: "missing")
        #expect(state.selectedDreamDiaryDay(from: days) == days[1])
        #expect(state.selectedDreamDiaryDay(from: []) == nil)
    }

    @Test func `dreaming entry labels are derived by reducer state`() {
        let state = AgentDreamingDestinationFeature.State()
        let entry = DreamingEntryLite(
            key: "memory",
            path: "/agent/memory/DREAMS.md",
            startLine: 42,
            endLine: 45,
            snippet: "remember this",
            recallCount: 3,
            dailyCount: 1,
            groundedCount: 2,
            totalSignalCount: 5,
            lightHits: 1,
            remHits: 2,
            phaseHitCount: 3,
            promotedAt: "today",
            lastRecalledAt: "yesterday")

        #expect(state.dreamingEntryTitle(entry) == "DREAMS.md:42")
        #expect(state.dreamingEntryDetail(entry) == "promoted today • recalled yesterday • 3 recalls • 2 grounded")
    }

    @Test func `dreaming phase labels are derived by reducer state`() {
        let state = AgentDreamingDestinationFeature.State()

        #expect(state
            .dreamingPhaseState(.init(enabled: false, cron: nil, managedCronPresent: true, nextRunAtMs: nil)) == "off")
        #expect(state
            .dreamingPhaseState(.init(enabled: true, cron: nil, managedCronPresent: true, nextRunAtMs: nil)) ==
            "scheduled")
        #expect(state
            .dreamingPhaseState(.init(enabled: true, cron: nil, managedCronPresent: false, nextRunAtMs: nil)) ==
            "setup")
    }

    @Test func `maintenance action is ignored while gateway is disconnected`() async {
        let store = TestStore(initialState: AgentDreamingDestinationFeature.State()) {
            AgentDreamingDestinationFeature(client: Self.client())
        }

        await store.send(.dreamActionTapped(.init(
            action: .backfill,
            gatewayConnection: .init(isConnected: false))))
    }

    @Test func `maintenance action stores success summary`() async {
        let store = TestStore(initialState: AgentDreamingDestinationFeature.State()) {
            AgentDreamingDestinationFeature(client: Self.client(run: { action in
                .init(summary: "\(action.title) complete.")
            }))
        }

        await store.send(.dreamActionTapped(.init(
            action: .repair,
            gatewayConnection: .init(isConnected: true))))
        {
            $0.busyAction = .repair
            $0.statusText = .init(value: nil)
        }
        await store.receive(.dreamActionResponse(.init(result: .success(.init(summary: "Repair complete."))))) {
            $0.busyAction = nil
            $0.statusText = .init(value: "Repair complete.")
        }
    }

    @Test func `maintenance action stores failure summary`() async {
        let failure = AgentDreamingMaintenanceError.failed(.init(
            message: .init(value: "dream failed")))
        let store = TestStore(initialState: AgentDreamingDestinationFeature.State()) {
            AgentDreamingDestinationFeature(client: Self.client(run: { _ in throw DreamingFailure.failed }))
        }

        await store.send(.dreamActionTapped(.init(
            action: .dedupe,
            gatewayConnection: .init(isConnected: true))))
        {
            $0.busyAction = .dedupe
            $0.statusText = .init(value: nil)
        }
        await store.receive(.dreamActionResponse(.init(result: .failure(failure)))) {
            $0.busyAction = nil
            $0.statusText = .init(value: "dream failed")
        }
    }

    @Test func `maintenance summary reports changed counts`() throws {
        let data = try #require(
            #"{"written":2,"replaced":1,"removedEntries":3,"changed":true}"#.data(using: .utf8))

        #expect(
            AgentDreamingMaintenanceClient.summary(action: .backfill, data: data) ==
                .init(summary: "Backfill: 2 written, 1 replaced, 3 removed, artifacts repaired."))
    }

    private static func client(
        run: @escaping @Sendable @MainActor (_ action: AgentDreamAction) async throws -> DreamActionSummary = {
            .init(summary: "\($0.title) complete.")
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
