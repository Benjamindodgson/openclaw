import ComposableArchitecture
import Foundation
import OpenClawKit

struct IPadSkillWorkshopClient {
    var list: @Sendable @MainActor (IPadSkillWorkshopAgentScopeParam) async throws -> IPadSkillProposalManifest
    var inspect: @Sendable @MainActor (IPadSkillWorkshopAgentScopeParam, IPadSkillWorkshopProposalID) async throws
        -> IPadSkillProposalInspectResponse
    var run: @Sendable @MainActor (
        _ action: IPadSkillProposalAction.Kind,
        IPadSkillWorkshopAgentScopeParam,
        IPadSkillWorkshopProposalID)
    async throws -> Void
}

private struct IPadSkillProposalListParams: Encodable {
    let agentId: String?
}

private struct IPadSkillProposalInspectParams: Encodable {
    let agentId: String?
    let proposalId: String
}

extension IPadSkillWorkshopClient: DependencyKey {
    static let liveValue = IPadSkillWorkshopClient(
        list: { _ in IPadSkillProposalManifest(proposals: []) },
        inspect: { _, _ in throw IPadSkillWorkshopError.failed(.init(message: .init(value: "Proposal unavailable."))) },
        run: { _, _, _ in })

    static let testValue = IPadSkillWorkshopClient(
        list: { _ in IPadSkillProposalManifest(proposals: []) },
        inspect: { _, _ in throw IPadSkillWorkshopError.failed(.init(message: .init(value: "Proposal unavailable."))) },
        run: { _, _, _ in })

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        IPadSkillWorkshopClient(
            list: { agentScope in
                let data = try await Self.request(
                    appModel: appModel,
                    method: "skills.proposals.list",
                    params: IPadSkillProposalListParams(agentId: agentScope.agentID),
                    timeoutSeconds: 20)
                return try JSONDecoder().decode(IPadSkillProposalManifest.self, from: data)
            },
            inspect: { agentScope, proposalID in
                let data = try await Self.request(
                    appModel: appModel,
                    method: "skills.proposals.inspect",
                    params: IPadSkillProposalInspectParams(
                        agentId: agentScope.agentID,
                        proposalId: proposalID.value),
                    timeoutSeconds: 20)
                return try JSONDecoder().decode(IPadSkillProposalInspectResponse.self, from: data)
            },
            run: { action, agentScope, proposalID in
                let method = action == .apply ? "skills.proposals.apply" : "skills.proposals.reject"
                _ = try await Self.request(
                    appModel: appModel,
                    method: method,
                    params: IPadSkillProposalInspectParams(
                        agentId: agentScope.agentID,
                        proposalId: proposalID.value),
                    timeoutSeconds: 30)
            })
    }

    @MainActor
    private static func request(
        appModel: NodeAppModel,
        method: String,
        params: some Encodable,
        timeoutSeconds: Int) async throws -> Data
    {
        let data = try JSONEncoder().encode(params)
        guard let json = String(data: data, encoding: .utf8) else {
            throw IPadSidebarGatewayError.invalidPayload
        }
        return try await appModel.operatorSession.request(
            method: method,
            paramsJSON: json,
            timeoutSeconds: timeoutSeconds)
    }
}

extension DependencyValues {
    var iPadSkillWorkshop: IPadSkillWorkshopClient {
        get { self[IPadSkillWorkshopClient.self] }
        set { self[IPadSkillWorkshopClient.self] = newValue }
    }
}
