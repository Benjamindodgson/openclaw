import ComposableArchitecture
import Foundation
import Testing
@testable import OpenClaw

@MainActor
struct IPadSkillWorkshopFeatureTests {
    @Test func `offline refresh clears proposal state`() async {
        var initialState = IPadSkillWorkshopFeature.State()
        initialState.proposals = [Self.proposal(id: "pending-1", status: "pending")]
        initialState.isLoading = true
        initialState.inspectingProposalID = "pending-1"
        initialState.errorText = "old error"
        let store = TestStore(initialState: initialState) {
            IPadSkillWorkshopFeature(client: Self.client())
        }

        await store.send(.refreshRequested(.init(sceneActive: true, canRead: false, force: false))) {
            $0.proposals = []
            $0.isLoading = false
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

        await store.send(.refreshRequested(.init(sceneActive: true, canRead: true, force: false))) {
            $0.isLoading = true
        }
        await store.receive(.refreshResponse(.init(force: false, result: .success(manifest)))) {
            $0.isLoading = false
            $0.proposals = [IPadSkillProposal(entry: entry, previous: nil)]
            $0.selectedProposalID = "pending-1"
            $0.inspectingProposalID = "pending-1"
        }
        await store.receive(.inspectResponse(.init(
            proposalID: "pending-1",
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
        initialState.selectedProposalID = "applied-1"
        let store = TestStore(initialState: initialState) {
            IPadSkillWorkshopFeature(client: Self.client())
        }

        await store.send(.agentScopeChanged(.init(agentID: " agent-1 "))) {
            $0.selectedAgentScopeID = "agent-1"
        }
        await store.send(.statusFilterChanged(.init(filter: "pending"))) {
            $0.statusFilter = "pending"
            $0.selectedProposalID = "pending-1"
        }
        await store.send(.queryChanged(.init(query: "missing"))) {
            $0.query = "missing"
            $0.selectedProposalID = nil
        }
        await store.send(.clearQueryTapped) {
            $0.query = ""
            $0.selectedProposalID = "pending-1"
        }
    }

    @Test func `apply success clears busy state and refreshes proposals`() async {
        let before = Self.entry(id: "pending-1", status: "pending")
        let after = Self.entry(id: "pending-1", status: "applied")
        let refreshedManifest = IPadSkillProposalManifest(proposals: [after])
        var initialState = IPadSkillWorkshopFeature.State()
        initialState.proposals = [IPadSkillProposal(entry: before, previous: nil)]
        initialState.selectedProposalID = "pending-1"
        let store = TestStore(initialState: initialState) {
            IPadSkillWorkshopFeature(client: Self.client(
                list: { _ in refreshedManifest },
                run: { _, _, _ in }))
        }

        await store.send(.proposalMutationRequested(.init(
            kind: .apply,
            proposalID: "pending-1",
            sceneActive: true,
            canRead: true,
            canWrite: true,
            hasOperatorAdminScope: true)))
        {
            $0.busyAction = IPadSkillProposalAction(kind: .apply, proposalID: "pending-1")
        }
        await store.receive(.proposalMutationResponse(.init(
            kind: .apply,
            sceneActive: true,
            canRead: true,
            result: .success(.init()))))
        {
            $0.busyAction = nil
            $0.noticeText = "Proposal applied."
        }
        await store.receive(.refreshRequested(.init(sceneActive: true, canRead: true, force: true))) {
            $0.isLoading = true
        }
        await store.receive(.refreshResponse(.init(force: true, result: .success(refreshedManifest)))) {
            $0.isLoading = false
            $0.proposals = [IPadSkillProposal(entry: after, previous: IPadSkillProposal(entry: before, previous: nil))]
            $0.selectedProposalID = nil
        }
    }

    private static func client(
        list: @escaping @Sendable @MainActor (_ agentID: String?) async throws -> IPadSkillProposalManifest = { _ in
            IPadSkillProposalManifest(proposals: [])
        },
        inspect: @escaping @Sendable @MainActor (_ agentID: String?, _ proposalID: String)
        async throws -> IPadSkillProposalInspectResponse = { _, proposalID in
            Self.inspectResponse(id: proposalID, status: "pending", content: "")
        },
        run: @escaping @Sendable @MainActor (
            _ action: IPadSkillProposalAction.Kind,
            _ agentID: String?,
            _ proposalID: String)
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
