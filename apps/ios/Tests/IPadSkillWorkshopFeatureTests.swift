import ComposableArchitecture
import Foundation
import Testing
@testable import OpenClaw

@MainActor
struct IPadSkillWorkshopFeatureTests {
    @Test func `offline refresh clears proposal state`() async {
        var initialState = IPadSkillWorkshopFeature.State()
        initialState.proposals = [Self.proposal(id: "pending-1", status: "pending")]
        initialState.isLoading = .init(value: true)
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
            $0.proposals = []
            $0.isLoading = .init(value: false)
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
            $0.isLoading = .init(value: true)
        }
        await store.receive(.refreshResponse(.init(
            force: .init(isForced: false),
            result: .success(manifest))))
        {
            $0.isLoading = .init(value: false)
            $0.proposals = [IPadSkillProposal(entry: entry, previous: nil)]
            $0.selectedProposalID = .init(value: "pending-1")
            $0.inspectingProposalID = .init(value: "pending-1")
        }
        await store.receive(.inspectResponse(.init(
            proposalID: .init(value: "pending-1"),
            result: .success(inspect))))
        {
            $0.inspectingProposalID = nil
            $0.proposals = [IPadSkillProposal(
                inspect: inspect,
                previous: IPadSkillProposal(entry: entry, previous: nil))]
        }
    }

    @Test func `filter and query changes keep selection inside visible proposals`() async {
        var initialState = IPadSkillWorkshopFeature.State()
        initialState.proposals = [
            Self.proposal(id: "applied-1", status: "applied", title: "Applied Proposal"),
            Self.proposal(id: "pending-1", status: "pending", title: "Pending Proposal"),
        ]
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

    @Test func `apply success clears busy state and refreshes proposals`() async {
        let before = Self.entry(id: "pending-1", status: "pending")
        let after = Self.entry(id: "pending-1", status: "applied")
        let refreshedManifest = IPadSkillProposalManifest(proposals: [after])
        var initialState = IPadSkillWorkshopFeature.State()
        initialState.proposals = [IPadSkillProposal(entry: before, previous: nil)]
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
            $0.isLoading = .init(value: true)
        }
        await store.receive(.refreshResponse(.init(
            force: .init(isForced: true),
            result: .success(refreshedManifest))))
        {
            $0.isLoading = .init(value: false)
            $0.proposals = [IPadSkillProposal(entry: after, previous: IPadSkillProposal(entry: before, previous: nil))]
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
            $0.isLoading = .init(value: true)
        }
        await store.receive(.refreshResponse(.init(
            force: .init(isForced: true),
            result: .failure(.failed(.init(message: .init(value: "skill boom")))))))
        {
            $0.isLoading = .init(value: false)
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
