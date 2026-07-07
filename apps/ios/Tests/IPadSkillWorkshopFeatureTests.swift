import ComposableArchitecture
import Foundation
import Testing
@testable import OpenClaw

@MainActor
struct IPadSkillWorkshopFeatureTests {
    @Test func `offline refresh clears proposal state`() async {
        var initialState = IPadSkillWorkshopFeature.State()
        initialState.proposalEntries = .init(values: [Self.proposal(id: "pending-1", status: "pending")])
        initialState.loadingPhase = .inFlight
        initialState.inspectingProposalID = .init(value: "pending-1")
        initialState.errorText = .init(value: "old error")
        let store = TestStore(initialState: initialState) {
            IPadSkillWorkshopFeature(client: Self.client())
        }

        await store.send(.refreshRequested(.init(
            sceneActivity: .init(isActive: true),
            readAccess: .init(canRead: false),
            force: .init(isForced: false))))
        {
            $0.proposalEntries = .init()
            $0.loadingPhase = .idle
            $0.inspectingProposalID = nil
            $0.errorText = nil
        }
    }

    @Test func `refresh success stores proposals and inspects selected proposal`() async {
        let entry = Self.entry(id: "pending-1", status: "pending")
        let inspect = Self.inspectResponse(id: "pending-1", status: "pending", content: "inspected body")
        let manifest = IPadSkillProposalManifest(proposals: [entry])
        let store = TestStore(initialState: IPadSkillWorkshopFeature.State()) {
            IPadSkillWorkshopFeature(client: Self.client(
                list: { _ in manifest },
                inspect: { _, _ in inspect }))
        }

        await store.send(.refreshRequested(.init(
            sceneActivity: .init(isActive: true),
            readAccess: .init(canRead: true),
            force: .init(isForced: false))))
        {
            $0.loadingPhase = .inFlight
        }
        await store.receive(.refreshResponse(.init(
            force: .init(isForced: false),
            result: .success(manifest))))
        {
            $0.loadingPhase = .idle
            $0.proposalEntries = .init(values: [IPadSkillProposal(entry: entry, previous: nil)])
            $0.selectedProposalID = .init(value: "pending-1")
            $0.inspectingProposalID = .init(value: "pending-1")
        }
        await store.receive(.inspectResponse(.init(
            proposalID: .init(value: "pending-1"),
            result: .success(inspect))))
        {
            $0.inspectingProposalID = nil
            $0.proposalEntries = .init(values: [IPadSkillProposal(
                inspect: inspect,
                previous: IPadSkillProposal(entry: entry, previous: nil))])
        }
    }

    @Test func `filter and query changes keep selection inside visible proposals`() async {
        var initialState = IPadSkillWorkshopFeature.State()
        initialState.proposalEntries = .init(values: [
            Self.proposal(id: "applied-1", status: "applied", title: "Applied Proposal"),
            Self.proposal(id: "pending-1", status: "pending", title: "Pending Proposal"),
        ])
        initialState.selectedProposalID = .init(value: "applied-1")
        let store = TestStore(initialState: initialState) {
            IPadSkillWorkshopFeature(client: Self.client())
        }

        await store.send(.agentScopeChanged(.init(agentID: .init(value: " agent-1 ")))) {
            $0.selectedAgentScopeID = .init(value: "agent-1")
        }
        await store.send(.statusFilterChanged(.init(filter: .init(value: "pending")))) {
            $0.statusFilter = .init(value: "pending")
            $0.selectedProposalID = .init(value: "pending-1")
        }
        await store.send(.queryChanged(.init(query: .init(value: "missing")))) {
            $0.query = .init(value: "missing")
            $0.selectedProposalID = nil
        }
        await store.send(.clearQueryTapped) {
            $0.query = .init(value: "")
            $0.selectedProposalID = .init(value: "pending-1")
        }
    }

    @Test func `proposal lanes are filtered by reducer state`() {
        var state = IPadSkillWorkshopFeature.State()
        state.proposalEntries = .init(values: [
            Self.proposal(id: "pending-match", status: "pending", title: "Gateway proposal"),
            Self.proposal(id: "pending-other", status: "pending", title: "Other proposal"),
            Self.proposal(id: "applied-match", status: "applied", title: "Gateway applied"),
            Self.proposal(id: "stale-match", status: "stale", title: "Gateway stale"),
        ])
        state.query = .init(value: "gateway")

        #expect(state.filteredProposals.map(\.id) == ["pending-match"])
        #expect(state.filteredProposalCount == 1)
        #expect(state.pendingProposalCount == 2)
        #expect(state.appliedProposalCount == 1)
        #expect(state.heldProposalCount == 1)
        #expect(state.visibleProposalLaneStatuses == ["pending"])
        #expect(state.proposals(forLaneStatus: "pending").map(\.id) == ["pending-match"])
        #expect(state.proposals(forLaneStatus: "applied").map(\.id) == ["applied-match"])
        #expect(state.proposal(withID: "pending-match")?.id == "pending-match")
        #expect(state.proposal(withID: "missing") == nil)

        state.statusFilter = .init(value: "all")
        #expect(state.filteredProposals.map(\.id) == ["pending-match", "applied-match", "stale-match"])
        #expect(state.filteredProposalCount == 3)
        #expect(state.visibleProposalLaneStatuses == ["pending", "quarantined", "stale", "applied", "rejected"])
    }

    @Test func `proposal selection opening controls sheet presentation`() async {
        let store = TestStore(initialState: IPadSkillWorkshopFeature.State()) {
            IPadSkillWorkshopFeature(client: Self.client())
        }

        await store.send(.proposalSelected(.init(
            proposalID: .init(value: "pending-1"),
            opening: .inline,
            readAccess: .init(canRead: false),
            forceInspect: .init(isForced: false))))
        {
            $0.selectedProposalID = .init(value: "pending-1")
        }

        await store.send(.proposalSelected(.init(
            proposalID: .init(value: "pending-2"),
            opening: .sheet,
            readAccess: .init(canRead: false),
            forceInspect: .init(isForced: false))))
        {
            $0.selectedProposalID = .init(value: "pending-2")
            $0.presentedProposalRoute = IPadSkillProposalSheetRoute(proposalID: "pending-2")
        }

        await store.send(.proposalSheetDismissed) {
            $0.presentedProposalRoute = nil
        }
    }

    @Test func `apply success clears busy state and refreshes proposals`() async {
        let before = Self.entry(id: "pending-1", status: "pending")
        let after = Self.entry(id: "pending-1", status: "applied")
        let refreshedManifest = IPadSkillProposalManifest(proposals: [after])
        var initialState = IPadSkillWorkshopFeature.State()
        initialState.proposalEntries = .init(values: [IPadSkillProposal(entry: before, previous: nil)])
        initialState.selectedProposalID = .init(value: "pending-1")
        let store = TestStore(initialState: initialState) {
            IPadSkillWorkshopFeature(client: Self.client(
                list: { _ in refreshedManifest },
                run: { _, _, _ in }))
        }

        await store.send(.proposalMutationRequested(.init(
            kind: .apply,
            proposalID: .init(value: "pending-1"),
            sceneActivity: .init(isActive: true),
            readAccess: .init(canRead: true),
            writeAccess: .init(canWrite: true),
            adminAccess: .init(hasOperatorAdminScope: true))))
        {
            $0.busyAction = IPadSkillProposalAction(kind: .apply, proposalID: "pending-1")
        }
        await store.receive(.proposalMutationResponse(.init(
            kind: .apply,
            sceneActivity: .init(isActive: true),
            readAccess: .init(canRead: true),
            result: .success(.init()))))
        {
            $0.busyAction = nil
            $0.noticeText = .init(value: "Proposal applied.")
        }
        await store.receive(.refreshRequested(.init(
            sceneActivity: .init(isActive: true),
            readAccess: .init(canRead: true),
            force: .init(isForced: true))))
        {
            $0.loadingPhase = .inFlight
        }
        await store.receive(.refreshResponse(.init(
            force: .init(isForced: true),
            result: .success(refreshedManifest))))
        {
            $0.loadingPhase = .idle
            $0.proposalEntries = .init(values: [IPadSkillProposal(
                entry: after,
                previous: IPadSkillProposal(entry: before, previous: nil))])
            $0.selectedProposalID = nil
        }
    }

    @Test func `forced refresh failure surfaces error text`() async {
        let store = TestStore(initialState: IPadSkillWorkshopFeature.State()) {
            IPadSkillWorkshopFeature(client: Self.client(
                list: { _ in throw TestSkillWorkshopFailure.failed }))
        }

        await store.send(.refreshRequested(.init(
            sceneActivity: .init(isActive: true),
            readAccess: .init(canRead: true),
            force: .init(isForced: true))))
        {
            $0.loadingPhase = .inFlight
        }
        await store.receive(.refreshResponse(.init(
            force: .init(isForced: true),
            result: .failure(.failed(.init(message: .init(value: "skill boom")))))))
        {
            $0.loadingPhase = .idle
            $0.errorText = .init(value: "skill boom")
        }
    }

    @Test func `proposal mutation failure clears busy state and surfaces error text`() async {
        let operation = IPadSkillProposalAction(kind: .reject, proposalID: "pending-1")
        let store = TestStore(initialState: IPadSkillWorkshopFeature.State()) {
            IPadSkillWorkshopFeature(client: Self.client(
                run: { _, _, _ in throw TestSkillWorkshopFailure.failed }))
        }

        await store.send(.proposalMutationRequested(.init(
            kind: .reject,
            proposalID: .init(value: "pending-1"),
            sceneActivity: .init(isActive: true),
            readAccess: .init(canRead: true),
            writeAccess: .init(canWrite: true),
            adminAccess: .init(hasOperatorAdminScope: true))))
        {
            $0.busyAction = operation
        }
        await store.receive(.proposalMutationResponse(.init(
            kind: .reject,
            sceneActivity: .init(isActive: true),
            readAccess: .init(canRead: true),
            result: .failure(.failed(.init(message: .init(value: "skill boom")))))))
        {
            $0.busyAction = nil
            $0.errorText = .init(value: "skill boom")
        }
    }

    private static func client(
        list: @escaping @Sendable @MainActor (IPadSkillWorkshopAgentScopeParam) async throws
            -> IPadSkillProposalManifest = { _ in
                IPadSkillProposalManifest(proposals: [])
            },
        inspect: @escaping @Sendable @MainActor (IPadSkillWorkshopAgentScopeParam, IPadSkillWorkshopProposalID)
        async throws -> IPadSkillProposalInspectResponse = { _, proposalID in
            Self.inspectResponse(id: proposalID.value, status: "pending", content: "")
        },
        run: @escaping @Sendable @MainActor (
            _ action: IPadSkillProposalAction.Kind,
            IPadSkillWorkshopAgentScopeParam,
            IPadSkillWorkshopProposalID)
        async throws -> Void = { _, _, _ in })
        -> IPadSkillWorkshopClient
    {
        IPadSkillWorkshopClient(list: list, inspect: inspect, run: run)
    }

    private static func proposal(
        id: String,
        status: String,
        title: String = "Proposal") -> IPadSkillProposal
    {
        IPadSkillProposal(entry: self.entry(id: id, status: status, title: title), previous: nil)
    }

    private static func entry(
        id: String,
        status: String,
        title: String = "Proposal") -> IPadSkillProposalManifestEntry
    {
        IPadSkillProposalManifestEntry(
            id: id,
            kind: "skill",
            status: status,
            title: title,
            description: "\(title) description",
            skillName: "sample-skill",
            skillKey: "sample-skill",
            createdAt: "2026-07-01T00:00:00Z",
            updatedAt: status == "applied" ? "2026-07-01T00:10:00Z" : "2026-07-01T00:00:00Z",
            scanState: "clean")
    }

    private static func inspectResponse(
        id: String,
        status: String,
        content: String) -> IPadSkillProposalInspectResponse
    {
        IPadSkillProposalInspectResponse(
            record: IPadSkillProposalRecord(
                id: id,
                kind: "skill",
                status: status,
                title: "Proposal",
                description: "Proposal description",
                createdAt: "2026-07-01T00:00:00Z",
                updatedAt: status == "applied" ? "2026-07-01T00:10:00Z" : "2026-07-01T00:00:00Z",
                target: IPadSkillProposalTarget(
                    skillName: "sample-skill",
                    skillKey: "sample-skill")),
            content: content,
            supportFiles: [])
    }
}

private enum TestSkillWorkshopFailure: LocalizedError {
    case failed

    var errorDescription: String? {
        "skill boom"
    }
}
