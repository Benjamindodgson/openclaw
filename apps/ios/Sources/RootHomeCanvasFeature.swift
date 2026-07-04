import ComposableArchitecture
import Foundation
import OpenClawKit
import OpenClawProtocol

@Reducer
struct RootHomeCanvasFeature {
    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var payload: Payload?
    }

    struct Snapshot: Equatable, Sendable {
        var gatewayStatus: GatewayDisplayState
        var gatewayServerName: String?
        var gatewayRemoteAddress: String?
        var selectedAgentID: String?
        var gatewayDefaultAgentID: String?
        var activeAgentName: String
        var agents: [AgentSnapshot]
    }

    struct AgentSnapshot: Equatable, Sendable {
        var id: String
        var name: String?
        var emoji: String?
    }

    struct Payload: Codable, Equatable, Sendable {
        var gatewayState: String
        var eyebrow: String
        var title: String
        var subtitle: String
        var gatewayLabel: String
        var activeAgentName: String
        var activeAgentBadge: String
        var activeAgentCaption: String
        var agentCount: Int
        var agents: [AgentCard]
        var footer: String
    }

    struct AgentCard: Codable, Equatable, Sendable {
        var id: String
        var name: String
        var badge: String
        var caption: String
        var isActive: Bool
    }

    enum Action: Equatable, Sendable {
        case snapshotChanged(Snapshot)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .snapshotChanged(snapshot):
                state.payload = Self.payload(snapshot: snapshot)
                return .none
            }
        }
        .autoLogActions()
    }

    static func payload(snapshot: Snapshot) -> Payload {
        let gatewayName = self.normalized(snapshot.gatewayServerName)
        let gatewayAddress = self.normalized(snapshot.gatewayRemoteAddress)
        let gatewayLabel = gatewayName ?? gatewayAddress ?? "Gateway"
        let activeAgentID = self.activeAgentID(snapshot: snapshot)
        let agents = self.agentCards(snapshot: snapshot, activeAgentID: activeAgentID)

        switch snapshot.gatewayStatus {
        case .connected:
            return Payload(
                gatewayState: "connected",
                eyebrow: "\(gatewayLabel) online",
                title: "Command center",
                subtitle:
                "Use Chat for code work, Talk for realtime voice, and gateway tools for approved device actions.",
                gatewayLabel: gatewayLabel,
                activeAgentName: snapshot.activeAgentName,
                activeAgentBadge: agents.first(where: { $0.isActive })?.badge ?? "OC",
                activeAgentCaption: "Routes chat and talk",
                agentCount: agents.count,
                agents: Array(agents.prefix(6)),
                footer: "OpenClaw only runs phone-side capabilities while the app is connected and permitted.")

        case .connecting:
            return Payload(
                gatewayState: "connecting",
                eyebrow: "Gateway handshake",
                title: "Reconnecting",
                subtitle:
                "Restoring the local node session, agent list, voice config, and device capability state.",
                gatewayLabel: gatewayLabel,
                activeAgentName: snapshot.activeAgentName,
                activeAgentBadge: "OC",
                activeAgentCaption: "Session in progress",
                agentCount: agents.count,
                agents: Array(agents.prefix(4)),
                footer: "If the gateway is reachable, the local node should recover without re-pairing.")

        case .error, .disconnected:
            return Payload(
                gatewayState: snapshot.gatewayStatus == .error ? "error" : "offline",
                eyebrow: snapshot.gatewayStatus == .error ? "Gateway needs attention" : "OpenClaw iOS",
                title: "Pair a gateway",
                subtitle:
                "Connect this phone as a local node for chat, realtime voice, share intake, and approved device tools.",
                gatewayLabel: gatewayLabel,
                activeAgentName: "Main",
                activeAgentBadge: "OC",
                activeAgentCaption: "Connect to load your agents",
                agentCount: agents.count,
                agents: Array(agents.prefix(4)),
                footer:
                "Use Settings to scan a pairing QR code or paste a setup code from your OpenClaw gateway.")
        }
    }

    private static func activeAgentID(snapshot: Snapshot) -> String {
        let selected = self.normalized(snapshot.selectedAgentID) ?? ""
        if !selected.isEmpty {
            return selected
        }
        return self.defaultAgentID(snapshot: snapshot)
    }

    private static func defaultAgentID(snapshot: Snapshot) -> String {
        self.normalized(snapshot.gatewayDefaultAgentID) ?? ""
    }

    private static func agentCards(snapshot: Snapshot, activeAgentID: String) -> [AgentCard] {
        let defaultAgentID = self.defaultAgentID(snapshot: snapshot)
        let cards = snapshot.agents.map { agent -> AgentCard in
            let isActive = !activeAgentID.isEmpty && agent.id == activeAgentID
            let isDefault = !defaultAgentID.isEmpty && agent.id == defaultAgentID
            return AgentCard(
                id: agent.id,
                name: self.agentName(agent),
                badge: self.agentBadge(agent),
                caption: isActive ? "Routed on this phone" : (isDefault ? "Gateway default" : "Available"),
                isActive: isActive)
        }

        return cards.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive {
                return lhs.isActive
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private static func agentName(_ agent: AgentSnapshot) -> String {
        self.normalized(agent.name) ?? agent.id
    }

    private static func agentBadge(_ agent: AgentSnapshot) -> String {
        if let normalizedEmoji = normalized(agent.emoji) {
            return normalizedEmoji
        }
        let words = self.agentName(agent)
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" })
            .prefix(2)
        let initials = words.compactMap(\.first).map(String.init).joined()
        if !initials.isEmpty {
            return initials.uppercased()
        }
        return "OC"
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension RootHomeCanvasFeature.AgentSnapshot {
    init(agent: AgentSummary) {
        self.init(
            id: agent.id,
            name: agent.name,
            emoji: agent.identity?["emoji"]?.value as? String)
    }
}
