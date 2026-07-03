import Foundation
import OpenClawKit
import OpenClawProtocol

enum AgentProValueReader {
    static func intValue(_ value: AnyCodable?) -> Int? {
        switch value?.value {
        case let int as Int: int
        case let double as Double where double.isFinite: Int(double)
        case let string as String: Int(string)
        default: nil
        }
    }

    static func doubleValue(_ value: AnyCodable?) -> Double? {
        switch value?.value {
        case let double as Double where double.isFinite: double
        case let int as Int: Double(int)
        case let string as String: Double(string)
        default: nil
        }
    }
}

struct AgentOverviewSnapshot: Equatable {
    let skills: SkillStatusReportLite?
    let presence: [PresenceEntry]
    let cronStatus: CronStatusLite?
    let cronJobs: [CronJob]
    let dreaming: DreamingStatusLite?
    let dreamDiary: DreamDiaryLite?
    let usage: CostUsageSummaryLite?
    let activeAgentId: String
    let agentSkillFilter: [String]?
    let loadedAt: Date

    var hasAnyLiveData: Bool {
        self.skills != nil
            || !self.presence.isEmpty
            || self.cronStatus != nil
            || !self.cronJobs.isEmpty
            || self.dreaming != nil
            || self.dreamDiary != nil
            || self.usage != nil
    }

    static func == (lhs: AgentOverviewSnapshot, rhs: AgentOverviewSnapshot) -> Bool {
        lhs.skills == rhs.skills
            && agentOverviewPresenceEntriesEqual(lhs.presence, rhs.presence)
            && lhs.cronStatus == rhs.cronStatus
            && agentOverviewCronJobsEqual(lhs.cronJobs, rhs.cronJobs)
            && lhs.dreaming == rhs.dreaming
            && lhs.dreamDiary == rhs.dreamDiary
            && lhs.usage == rhs.usage
            && lhs.activeAgentId == rhs.activeAgentId
            && lhs.agentSkillFilter == rhs.agentSkillFilter
            && lhs.loadedAt == rhs.loadedAt
    }
}

private func agentOverviewPresenceEntriesEqual(_ lhs: [PresenceEntry], _ rhs: [PresenceEntry]) -> Bool {
    guard lhs.count == rhs.count else { return false }
    return zip(lhs, rhs).allSatisfy { lhs, rhs in
        lhs.host == rhs.host
            && lhs.ip == rhs.ip
            && lhs.version == rhs.version
            && lhs.platform == rhs.platform
            && lhs.devicefamily == rhs.devicefamily
            && lhs.modelidentifier == rhs.modelidentifier
            && lhs.mode == rhs.mode
            && lhs.lastinputseconds == rhs.lastinputseconds
            && lhs.reason == rhs.reason
            && lhs.tags == rhs.tags
            && lhs.text == rhs.text
            && lhs.ts == rhs.ts
            && lhs.deviceid == rhs.deviceid
            && lhs.roles == rhs.roles
            && lhs.scopes == rhs.scopes
            && lhs.instanceid == rhs.instanceid
    }
}

private func agentOverviewCronJobsEqual(_ lhs: [CronJob], _ rhs: [CronJob]) -> Bool {
    guard lhs.count == rhs.count else { return false }
    return zip(lhs, rhs).allSatisfy { lhs, rhs in
        lhs.id == rhs.id
            && lhs.agentid == rhs.agentid
            && lhs.sessionkey == rhs.sessionkey
            && lhs.name == rhs.name
            && lhs.description == rhs.description
            && lhs.enabled == rhs.enabled
            && lhs.deleteafterrun == rhs.deleteafterrun
            && lhs.createdatms == rhs.createdatms
            && lhs.updatedatms == rhs.updatedatms
            && lhs.schedule == rhs.schedule
            && lhs.sessiontarget == rhs.sessiontarget
            && lhs.wakemode == rhs.wakemode
            && lhs.payload == rhs.payload
            && lhs.delivery == rhs.delivery
            && lhs.failurealert == rhs.failurealert
            && lhs.state == rhs.state
    }
}

struct SkillStatusReportLite: Decodable, Equatable {
    let workspaceDir: String?
    let managedSkillsDir: String?
    let agentId: String?
    let agentSkillFilter: [String]?
    let skills: [SkillStatusEntryLite]

    var totalCount: Int {
        self.skills.count
    }

    var enabledCount: Int {
        self.skills.count {
            $0.isEnabled
        }
    }

    var blockedCount: Int {
        self.skills.count {
            $0.blockedByAllowlist == true || $0.blockedByAgentFilter == true
        }
    }

    var missingRequirementCount: Int {
        self.skills.count {
            $0.hasMissingRequirements
        }
    }
}

struct SkillStatusEntryLite: Decodable, Equatable {
    let name: String
    let description: String?
    let source: String?
    let filePath: String?
    let skillKey: String?
    let primaryEnv: String?
    let emoji: String?
    let homepage: String?
    let disabled: Bool?
    let blockedByAllowlist: Bool?
    let blockedByAgentFilter: Bool?
    let missing: SkillStatusMissingLite?
    let install: [SkillInstallOptionLite]?

    var displayName: String {
        if let emoji, !emoji.isEmpty {
            return "\(emoji) \(self.name)"
        }
        return self.name
    }

    var effectiveSkillKey: String {
        let trimmed = (self.skillKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? self.name : trimmed
    }

    var isGloballyEnabled: Bool {
        self.disabled != true
    }

    var isEnabled: Bool {
        self.disabled != true
            && self.blockedByAllowlist != true
            && self.blockedByAgentFilter != true
    }

    var hasMissingRequirements: Bool {
        guard let missing else { return false }
        return !missing.bins.isEmpty
            || !missing.env.isEmpty
            || !missing.config.isEmpty
            || !missing.os.isEmpty
    }

    var missingSummary: String? {
        guard let missing else { return nil }
        let values = [
            missing.bins,
            missing.env,
            missing.config,
            missing.os,
        ].flatMap(\.self)
        return values.isEmpty ? nil : values.prefix(3).joined(separator: ", ")
    }

    var installSummary: String? {
        guard let option = self.install?.first else { return nil }
        return option.label
    }

    var missingBins: [String] {
        self.missing?.bins ?? []
    }

    var homepageURL: URL? {
        guard let homepage else { return nil }
        return URL(string: homepage)
    }
}

struct SkillInstallOptionLite: Decodable, Equatable {
    let id: String?
    let kind: String?
    let label: String
    let bins: [String]?
}

struct SkillUpdateParams: Encodable {
    let skillKey: String
    var enabled: Bool?
    var apiKey: String?
}

struct SkillInstallParams: Encodable {
    let name: String
    let installId: String
    let timeoutMs: Int
}

struct SkillInstallResultLite: Decodable {
    let message: String?
}

struct ClawHubSearchParams: Encodable {
    let query: String?
    let limit: Int
}

struct ClawHubSearchResponseLite: Decodable {
    let results: [ClawHubSearchResultLite]
}

struct ClawHubSearchResultLite: Decodable, Equatable {
    let slug: String
    let displayName: String
    let summary: String?
    let version: String?
}

struct ClawHubInstallParams: Encodable {
    let source = "clawhub"
    let slug: String
}

struct CronRunParams: Encodable {
    let id: String
    let mode: String
}

struct CronUpdatePatch: Encodable {
    let enabled: Bool
}

struct CronUpdateParams: Encodable {
    let id: String
    let patch: CronUpdatePatch
}

struct SkillStatusMissingLite: Decodable, Equatable {
    let bins: [String]
    let env: [String]
    let config: [String]
    let os: [String]
}

struct CronStatusLite: Decodable, Equatable {
    let enabled: Bool
    let jobs: Int
    let nextwakeatms: Int?

    enum CodingKeys: String, CodingKey {
        case enabled
        case jobs
        case nextwakeatms = "nextWakeAtMs"
    }
}

struct CronJobsListLite: Decodable {
    let jobs: [CronJob]
    let total: Int?
}

struct DreamingStatusEnvelope: Decodable {
    let dreaming: DreamingStatusLite?
}

struct DreamingStatusLite: Decodable, Equatable {
    let enabled: Bool
    let shortTermCount: Int?
    let totalSignalCount: Int?
    let promotedToday: Int?
    let storeError: String?
    let shortTermEntries: [DreamingEntryLite]?
    let signalEntries: [DreamingEntryLite]?
    let promotedEntries: [DreamingEntryLite]?
    let phases: [String: DreamingPhaseStatusLite]?

    var nextRunAtMs: Int? {
        self.phases?.values
            .compactMap(\.nextRunAtMs)
            .min()
    }
}

struct DreamingEntryLite: Decodable, Equatable, Identifiable {
    let key: String
    let path: String
    let startLine: Int
    let endLine: Int
    let snippet: String
    let recallCount: Int
    let dailyCount: Int
    let groundedCount: Int
    let totalSignalCount: Int
    let lightHits: Int
    let remHits: Int
    let phaseHitCount: Int
    let promotedAt: String?
    let lastRecalledAt: String?

    var id: String {
        "\(self.key):\(self.path):\(self.startLine):\(self.endLine)"
    }
}

struct DreamDiaryLite: Decodable, Equatable {
    let agentId: String
    let found: Bool
    let path: String
    let content: String?
    let updatedAtMs: Int?
}

struct DreamingPhaseStatusLite: Decodable, Equatable {
    let enabled: Bool?
    let cron: String?
    let managedCronPresent: Bool?
    let nextRunAtMs: Int?
}

struct DreamingPhaseRow: Identifiable {
    let id: String
    let title: String
    let status: DreamingPhaseStatusLite
}

struct ConfigSnapshotLite: Decodable {
    let hash: String?
    let config: ConfigRootLite?

    func agentConfig(id: String) -> AgentConfigLite? {
        self.config?.agents?.list?.first { $0.id == id }
    }

    func effectiveSkillFilter(agentId: String) -> [String]? {
        if let agentSkills = self.agentConfig(id: agentId)?.skills {
            return agentSkills
        }
        return self.config?.agents?.defaults?.skills
    }
}

struct ConfigRootLite: Decodable {
    let agents: AgentsConfigLite?
}

struct AgentsConfigLite: Decodable {
    let defaults: AgentDefaultsConfigLite?
    let list: [AgentConfigLite]?
}

struct AgentDefaultsConfigLite: Decodable {
    let skills: [String]?
}

struct AgentConfigLite: Decodable {
    let id: String
    let skills: [String]?
}

struct ConfigPatchParams: Encodable {
    let raw: String
    let baseHash: String
    let replacePaths: [String]?

    init(raw: String, baseHash: String, replacePaths: [String]? = nil) {
        self.raw = raw
        self.baseHash = baseHash
        self.replacePaths = replacePaths
    }
}

enum SkillMutationError: LocalizedError {
    case liveGatewayUnavailable
    case missingConfigHash
    case invalidPatchPayload

    var errorDescription: String? {
        switch self {
        case .liveGatewayUnavailable:
            "Connect a live gateway to edit agent skills."
        case .missingConfigHash:
            "Config hash missing; refresh and retry."
        case .invalidPatchPayload:
            "Could not encode the skill config update."
        }
    }
}

struct CostUsageSummaryLite: Decodable, Equatable {
    let updatedAt: Int?
    let days: Int?
    let daily: [CostUsageDailyEntryLite]?
    let totals: [String: AnyCodable]?
    let cacheStatus: [String: AnyCodable]?

    var totalCost: Double? {
        AgentProValueReader.doubleValue(self.totals?["totalCost"])
    }

    var totalTokens: Int? {
        AgentProValueReader.intValue(self.totals?["totalTokens"])
    }
}

struct CostUsageDailyEntryLite: Decodable, Equatable {
    let date: String
    let totalTokens: Int?
    let totalCost: Double?
}
