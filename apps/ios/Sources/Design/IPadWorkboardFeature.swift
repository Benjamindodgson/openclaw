import ComposableArchitecture
import Foundation
import OpenClawKit

struct IPadWorkboardClient {
    var listCards: @Sendable @MainActor (_ boardID: String?) async throws -> IPadWorkboardCardsResponse
    var listBoards: @Sendable @MainActor () async throws -> [IPadWorkboardBoardSummary]
    var create: @Sendable @MainActor (IPadWorkboardCreateParams) async throws -> IPadWorkboardCard
    var move: @Sendable @MainActor (IPadWorkboardMoveParams) async throws -> IPadWorkboardCard
    var archive: @Sendable @MainActor (IPadWorkboardArchiveParams) async throws -> IPadWorkboardCard
    var dispatch: @Sendable @MainActor (_ boardID: String?) async throws -> IPadWorkboardDispatchSummary
}

extension IPadWorkboardClient: DependencyKey {
    static let liveValue = IPadWorkboardClient.unavailable
    static let testValue = IPadWorkboardClient.unavailable

    private static let unavailable = IPadWorkboardClient(
        listCards: { _ in throw IPadWorkboardError.failed("Workboard gateway unavailable.") },
        listBoards: { throw IPadWorkboardError.failed("Workboard gateway unavailable.") },
        create: { _ in throw IPadWorkboardError.failed("Workboard gateway unavailable.") },
        move: { _ in throw IPadWorkboardError.failed("Workboard gateway unavailable.") },
        archive: { _ in throw IPadWorkboardError.failed("Workboard gateway unavailable.") },
        dispatch: { _ in throw IPadWorkboardError.failed("Workboard gateway unavailable.") })

    @MainActor
    static func live(appModel: NodeAppModel) -> Self {
        IPadWorkboardClient(
            listCards: { boardID in
                let data = try await Self.request(
                    appModel: appModel,
                    method: "workboard.cards.list",
                    params: IPadWorkboardListParams(boardId: boardID),
                    timeoutSeconds: 20)
                return try JSONDecoder().decode(IPadWorkboardCardsResponse.self, from: data)
            },
            listBoards: {
                let data = try await Self.request(
                    appModel: appModel,
                    method: "workboard.boards.list",
                    params: EmptyParams(),
                    timeoutSeconds: 20)
                return try JSONDecoder().decode(IPadWorkboardBoardsResponse.self, from: data).boards
            },
            create: { params in
                let data = try await Self.request(
                    appModel: appModel,
                    method: "workboard.cards.create",
                    params: params,
                    timeoutSeconds: 20)
                return try Self.decodeCardResponse(data)
            },
            move: { params in
                let data = try await Self.request(
                    appModel: appModel,
                    method: "workboard.cards.move",
                    params: params,
                    timeoutSeconds: 20)
                return try Self.decodeCardResponse(data)
            },
            archive: { params in
                let data = try await Self.request(
                    appModel: appModel,
                    method: "workboard.cards.archive",
                    params: params,
                    timeoutSeconds: 20)
                return try Self.decodeCardResponse(data)
            },
            dispatch: { boardID in
                let data = try await Self.request(
                    appModel: appModel,
                    method: "workboard.cards.dispatch",
                    params: IPadWorkboardListParams(boardId: boardID),
                    timeoutSeconds: 45)
                return try JSONDecoder().decode(IPadWorkboardDispatchSummary.self, from: data)
            })
    }

    @MainActor
    private static func request(
        appModel: NodeAppModel,
        method: String,
        params: some Encodable,
        timeoutSeconds: Int) async throws -> Data
    {
        guard appModel.isOperatorGatewayConnected else { throw IPadSidebarGatewayError.offline }
        let data = try JSONEncoder().encode(params)
        guard let json = String(data: data, encoding: .utf8) else {
            throw IPadSidebarGatewayError.invalidPayload
        }
        return try await appModel.operatorSession.request(
            method: method,
            paramsJSON: json,
            timeoutSeconds: timeoutSeconds)
    }

    private static func decodeCardResponse(_ data: Data) throws -> IPadWorkboardCard {
        try JSONDecoder().decode(IPadWorkboardCardResponse.self, from: data).card
    }
}

extension DependencyValues {
    var iPadWorkboard: IPadWorkboardClient {
        get { self[IPadWorkboardClient.self] }
        set { self[IPadWorkboardClient.self] = newValue }
    }
}

// swiftformat:disable redundantSendable
enum IPadWorkboardError: Error, Equatable, Sendable {
    case failed(String)

    var message: String {
        switch self {
        case let .failed(message):
            message
        }
    }
}

struct IPadWorkboardDispatchSnapshot: Equatable, Sendable {
    let summary: IPadWorkboardDispatchSummary
    let cardsResponse: IPadWorkboardCardsResponse
}

// swiftformat:enable redundantSendable

@Reducer
struct IPadWorkboardFeature {
    private let clientOverride: IPadWorkboardClient?

    init(client: IPadWorkboardClient? = nil) {
        self.clientOverride = client
    }

    private enum CancelID {
        case refresh
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var cards: [IPadWorkboardCard] = []
        var statuses: [String] = IPadWorkboardDefaults.statuses
        var knownBoardIDs: [String] = []
        var isRefreshing = false
        var isDispatching = false
        var activeRefreshBoardID: String?
        var busyCardID: String?
        var dispatchSummaryText: String?
        var selectedStatus = "active"
        var selectedBoardID = ""
        var query = ""
        var draftTitle = ""
        var draftNotes = ""
        var isCreatingCard = false
        var errorText: String?
        var presentedSheet: IPadWorkboardSheet?

        var boardScopeLabel: String {
            self.selectedBoardID.isEmpty ? "All boards" : IPadWorkboardScreen.boardScopeLabel(for: self.selectedBoardID)
        }

        var isLoading: Bool {
            self.isRefreshing || self.isDispatching
        }

        var selectedBoardParam: String? {
            let selected = IPadWorkboardScreen.normalizedScopeID(self.selectedBoardID)
            return selected.isEmpty ? nil : selected
        }

        var trimmedDraftTitle: String {
            self.draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        func createUnavailableMessage(canRead: Bool, canWrite: Bool) -> String? {
            Self.createUnavailableMessage(
                isCreatingCard: self.isCreatingCard,
                trimmedDraftTitle: self.trimmedDraftTitle,
                canRead: canRead,
                canWrite: canWrite)
        }

        var boardScopeOptions: [String] {
            IPadWorkboardScreen.boardScopeOptions(
                knownBoardIDs: self.knownBoardIDs,
                cardBoardIDs: self.cards.map { IPadWorkboardScreen.boardID(for: $0) })
        }

        var visibleKanbanStatuses: [String] {
            if self.selectedStatus == "active" {
                return self.statuses.filter { $0 != "done" }
            }
            if self.statuses.contains(self.selectedStatus) {
                return [self.selectedStatus]
            }
            return self.statuses
        }

        var compactStatuses: [String] {
            let preferred = ["todo", "ready", "running", "review", "blocked", "scheduled", "done"]
            let known = preferred.filter { self.statuses.contains($0) }
            let custom = self.statuses.filter { !preferred.contains($0) }
            return known + custom
        }

        var filteredCards: [IPadWorkboardCard] {
            Self.filteredCards(
                cards: self.cards,
                selectedStatus: self.selectedStatus,
                query: self.query)
        }

        func cards(forKanbanStatus status: String) -> [IPadWorkboardCard] {
            Self.cardsForKanbanStatus(
                cards: self.cards,
                status: status,
                selectedStatus: self.selectedStatus,
                query: self.query)
        }

        mutating func applyCardsResponse(_ response: IPadWorkboardCardsResponse) {
            self.cards = response.cards.sorted { $0.position < $1.position }
            self.statuses = Self.normalizedStatuses(response.statuses)
            self.rememberBoardIDs(from: response.cards)
            self.validateSelectedStatus()
        }

        mutating func applyBoardScopes(_ boards: [IPadWorkboardBoardSummary]) {
            let discovered = boards.map(\.id)
            self.knownBoardIDs = IPadWorkboardScreen.boardScopeOptions(
                knownBoardIDs: self.knownBoardIDs,
                cardBoardIDs: discovered)
        }

        mutating func replace(_ card: IPadWorkboardCard) {
            self.cards.removeAll { $0.id == card.id }
            self.cards.append(card)
            self.cards.sort { $0.position < $1.position }
            self.rememberBoardIDs(from: [card])
        }

        func nextPosition(for status: String, excluding cardID: String? = nil) -> Double {
            let maxPosition = self.cards
                .filter { $0.status == status && $0.id != cardID }
                .map(\.position)
                .max() ?? 0
            return maxPosition + 1000
        }

        static func createUnavailableMessage(
            isCreatingCard: Bool,
            trimmedDraftTitle: String,
            canRead: Bool,
            canWrite: Bool) -> String?
        {
            if isCreatingCard {
                return "Card creation is already in progress."
            }
            if !canWrite {
                return IPadWorkboardScreen.compactWriteUnavailableMessage(canRead: canRead)
            }
            if trimmedDraftTitle.isEmpty {
                return "Enter a title to create a card."
            }
            return nil
        }

        static func cardsForKanbanStatus(
            cards: [IPadWorkboardCard],
            status: String,
            selectedStatus: String,
            query: String) -> [IPadWorkboardCard]
        {
            cards
                .filter { card in
                    card.status == status && (selectedStatus != "active" || card.metadata?.archivedAt == nil)
                }
                .filter { Self.matchesQuery(card: $0, query: query) }
                .sorted { $0.position < $1.position }
        }

        static func filteredCards(
            cards: [IPadWorkboardCard],
            selectedStatus: String,
            query: String) -> [IPadWorkboardCard]
        {
            cards
                .filter { card in
                    if selectedStatus == "active" {
                        return card.metadata?.archivedAt == nil && card.status != "done"
                    }
                    return card.status == selectedStatus
                }
                .filter { Self.matchesQuery(card: $0, query: query) }
                .sorted { left, right in
                    if left.status != right.status {
                        return IPadWorkboardDefaults.rank(left.status) < IPadWorkboardDefaults.rank(right.status)
                    }
                    return left.position < right.position
                }
        }

        private static func matchesQuery(card: IPadWorkboardCard, query: String) -> Bool {
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !trimmedQuery.isEmpty else { return true }
            return [
                card.title,
                card.notes,
                card.agentId,
                card.sessionKey,
                card.labels.joined(separator: " "),
            ]
                .compactMap(\.self)
                .joined(separator: " ")
                .lowercased()
                .contains(trimmedQuery)
        }

        private mutating func rememberBoardIDs(from cards: [IPadWorkboardCard]) {
            let discovered = cards.map { IPadWorkboardScreen.boardID(for: $0) }
            self.knownBoardIDs = Array(Set(self.knownBoardIDs + discovered)).sorted()
        }

        private mutating func validateSelectedStatus() {
            if !self.statuses.contains(self.selectedStatus), self.selectedStatus != "active" {
                self.selectedStatus = "active"
            }
        }

        private static func normalizedStatuses(_ statuses: [String]?) -> [String] {
            let normalized = (statuses ?? [])
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return normalized.isEmpty ? IPadWorkboardDefaults.statuses : normalized
        }
    }

    enum Action: Equatable, Sendable {
        struct ArchiveRequest: Equatable, Sendable {
            var card: IPadWorkboardCard
            var canWrite: Bool
        }

        struct ArchiveResponse: Equatable, Sendable {
            var result: Result<IPadWorkboardCard, IPadWorkboardError>
        }

        case archiveRequested(ArchiveRequest)
        case archiveResponse(ArchiveResponse)
        case beginCreateCardTapped

        struct BoardScopesResponse: Equatable, Sendable {
            var force: Bool
            var result: Result<[IPadWorkboardBoardSummary], IPadWorkboardError>
        }

        case boardScopesResponse(BoardScopesResponse)

        struct BoardScopeChange: Equatable, Sendable {
            var boardID: String
        }

        case boardScopeChanged(BoardScopeChange)

        struct CardSheetPresentation: Equatable, Sendable {
            var card: IPadWorkboardCard
        }

        case cardSheetPresented(CardSheetPresentation)
        case clearQueryTapped

        struct CreateRequest: Equatable, Sendable {
            var canRead: Bool
            var canWrite: Bool
        }

        struct CreateResponse: Equatable, Sendable {
            var result: Result<IPadWorkboardCard, IPadWorkboardError>
        }

        case createRequested(CreateRequest)
        case createResponse(CreateResponse)

        struct DispatchRequest: Equatable, Sendable {
            var canWrite: Bool
        }

        struct DispatchResponse: Equatable, Sendable {
            var boardID: String?
            var result: Result<IPadWorkboardDispatchSnapshot, IPadWorkboardError>
        }

        case dispatchRequested(DispatchRequest)
        case dispatchResponse(DispatchResponse)

        struct DraftNotesChange: Equatable, Sendable {
            var notes: String
        }

        case draftNotesChanged(DraftNotesChange)

        struct DraftTitleChange: Equatable, Sendable {
            var title: String
        }

        case draftTitleChanged(DraftTitleChange)

        struct MoveRequest: Equatable, Sendable {
            var card: IPadWorkboardCard
            var status: String
            var canWrite: Bool
        }

        struct MoveResponse: Equatable, Sendable {
            var result: Result<IPadWorkboardCard, IPadWorkboardError>
        }

        case moveRequested(MoveRequest)
        case moveResponse(MoveResponse)
        case queryChanged(String)

        struct RefreshRequest: Equatable, Sendable {
            var sceneActive: Bool
            var canRead: Bool
            var force: Bool
        }

        struct RefreshResponse: Equatable, Sendable {
            var boardID: String?
            var force: Bool
            var result: Result<IPadWorkboardCardsResponse, IPadWorkboardError>
        }

        case refreshRequested(RefreshRequest)
        case refreshResponse(RefreshResponse)
        case sheetDismissed
        case statusChanged(String)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.iPadWorkboard) var dependencyClient
            let client = self.clientOverride ?? dependencyClient

            switch action {
            case let .archiveRequested(request):
                guard request.canWrite, state.busyCardID == nil else { return .none }
                state.busyCardID = request.card.id
                state.errorText = nil
                let params = IPadWorkboardArchiveParams(
                    id: request.card.id,
                    archived: request.card.metadata?.archivedAt == nil)
                return .run { send in
                    do {
                        let card = try await client.archive(params)
                        await send(.archiveResponse(.init(result: .success(card))))
                    } catch {
                        await send(.archiveResponse(.init(result: .failure(.failed(Self.message(for: error))))))
                    }
                }

            case let .archiveResponse(response):
                switch response.result {
                case let .success(card):
                    state.busyCardID = nil
                    state.replace(card)
                    return .none

                case let .failure(error):
                    state.busyCardID = nil
                    state.errorText = error.message
                    return .none
                }

            case .beginCreateCardTapped:
                state.draftTitle = ""
                state.draftNotes = ""
                state.errorText = nil
                state.presentedSheet = .create
                return .none

            case let .boardScopesResponse(response):
                switch response.result {
                case let .success(boards):
                    state.applyBoardScopes(boards)
                    return .none

                case let .failure(error):
                    if response.force, state.knownBoardIDs.isEmpty {
                        state.errorText = error.message
                    }
                    return .none
                }

            case let .boardScopeChanged(change):
                state.selectedBoardID = IPadWorkboardScreen.normalizedScopeID(change.boardID)
                return .none

            case let .cardSheetPresented(presentation):
                state.presentedSheet = .card(presentation.card)
                return .none

            case .clearQueryTapped:
                state.query = ""
                return .none

            case let .createRequested(request):
                if let message = state.createUnavailableMessage(canRead: request.canRead, canWrite: request.canWrite) {
                    state.errorText = message
                    return .none
                }

                state.isCreatingCard = true
                state.errorText = nil
                let status = state.statuses.contains(state.selectedStatus) ? state.selectedStatus : "todo"
                let params = IPadWorkboardCreateParams(
                    title: state.trimmedDraftTitle,
                    notes: state.draftNotes.trimmingCharacters(in: .whitespacesAndNewlines),
                    status: status,
                    priority: "normal",
                    labels: [],
                    agentId: "",
                    sessionKey: nil,
                    position: state.nextPosition(for: status),
                    boardId: state.selectedBoardParam)
                return .run { send in
                    do {
                        let card = try await client.create(params)
                        await send(.createResponse(.init(result: .success(card))))
                    } catch {
                        await send(.createResponse(.init(result: .failure(.failed(Self.message(for: error))))))
                    }
                }

            case let .createResponse(response):
                switch response.result {
                case let .success(card):
                    state.isCreatingCard = false
                    state.draftTitle = ""
                    state.draftNotes = ""
                    state.presentedSheet = nil
                    state.replace(card)
                    return .none

                case let .failure(error):
                    state.isCreatingCard = false
                    state.errorText = error.message
                    return .none
                }

            case let .dispatchRequested(request):
                guard request.canWrite, !state.isLoading else { return .none }
                state.isDispatching = true
                state.errorText = nil
                state.dispatchSummaryText = nil
                let boardID = state.selectedBoardParam
                return .run { send in
                    do {
                        let summary = try await client.dispatch(boardID)
                        let cardsResponse = try await client.listCards(boardID)
                        await send(.dispatchResponse(.init(
                            boardID: boardID,
                            result: .success(IPadWorkboardDispatchSnapshot(
                                summary: summary,
                                cardsResponse: cardsResponse)))))
                    } catch {
                        await send(.dispatchResponse(.init(
                            boardID: boardID,
                            result: .failure(.failed(Self.message(for: error))))))
                    }
                }

            case let .dispatchResponse(response):
                state.isDispatching = false
                guard state.selectedBoardParam == response.boardID else { return .none }
                switch response.result {
                case let .success(snapshot):
                    state.dispatchSummaryText = snapshot.summary.summaryText
                    state.applyCardsResponse(snapshot.cardsResponse)
                    return .none

                case let .failure(error):
                    state.errorText = error.message
                    return .none
                }

            case let .draftNotesChanged(change):
                state.draftNotes = change.notes
                return .none

            case let .draftTitleChanged(change):
                state.draftTitle = change.title
                return .none

            case let .moveRequested(request):
                guard request.canWrite, state.busyCardID == nil else { return .none }
                state.busyCardID = request.card.id
                state.errorText = nil
                let params = IPadWorkboardMoveParams(
                    id: request.card.id,
                    status: request.status,
                    position: state.nextPosition(for: request.status, excluding: request.card.id))
                return .run { send in
                    do {
                        let card = try await client.move(params)
                        await send(.moveResponse(.init(result: .success(card))))
                    } catch {
                        await send(.moveResponse(.init(result: .failure(.failed(Self.message(for: error))))))
                    }
                }

            case let .moveResponse(response):
                switch response.result {
                case let .success(card):
                    state.busyCardID = nil
                    state.replace(card)
                    return .none

                case let .failure(error):
                    state.busyCardID = nil
                    state.errorText = error.message
                    return .none
                }

            case let .queryChanged(query):
                state.query = query
                return .none

            case let .refreshRequested(request):
                guard request.sceneActive else {
                    state.isRefreshing = false
                    state.activeRefreshBoardID = nil
                    return .cancel(id: CancelID.refresh)
                }
                guard request.canRead else {
                    state.cards = []
                    state.errorText = nil
                    state.isRefreshing = false
                    state.activeRefreshBoardID = nil
                    return .cancel(id: CancelID.refresh)
                }

                state.isRefreshing = true
                let boardID = state.selectedBoardParam
                state.activeRefreshBoardID = boardID
                state.errorText = nil
                if !state.statuses.contains(state.selectedStatus), state.selectedStatus != "active" {
                    state.selectedStatus = "active"
                }
                return .run { send in
                    do {
                        let response = try await client.listCards(boardID)
                        await send(.refreshResponse(.init(
                            boardID: boardID,
                            force: request.force,
                            result: .success(response))))
                    } catch {
                        await send(.refreshResponse(.init(
                            boardID: boardID,
                            force: request.force,
                            result: .failure(.failed(Self.message(for: error))))))
                    }
                }
                .cancellable(id: CancelID.refresh, cancelInFlight: true)

            case let .refreshResponse(response):
                guard state.activeRefreshBoardID == response.boardID else { return .none }
                state.isRefreshing = false
                state.activeRefreshBoardID = nil
                guard state.selectedBoardParam == response.boardID else { return .none }
                switch response.result {
                case let .success(cardsResponse):
                    state.applyCardsResponse(cardsResponse)
                    return .run { send in
                        do {
                            let boards = try await client.listBoards()
                            await send(.boardScopesResponse(.init(force: response.force, result: .success(boards))))
                        } catch {
                            await send(.boardScopesResponse(.init(
                                force: response.force,
                                result: .failure(.failed(Self.message(for: error))))))
                        }
                    }

                case let .failure(error):
                    if response.force || state.cards.isEmpty {
                        state.errorText = error.message
                    }
                    return .none
                }

            case .sheetDismissed:
                state.presentedSheet = nil
                return .none

            case let .statusChanged(status):
                state.selectedStatus = status
                return .none
            }
        }
        .autoLogActions()
    }

    private static func message(for error: Error) -> String {
        if let workboardError = error as? IPadWorkboardError {
            return workboardError.message
        }
        if let gatewayError = error as? IPadSidebarGatewayError {
            return gatewayError.message
        }
        return error.localizedDescription
    }
}

enum IPadWorkboardStoreFactory {
    @MainActor
    static func live(appModel: NodeAppModel) -> StoreOf<IPadWorkboardFeature> {
        Store(initialState: IPadWorkboardFeature.State()) {
            IPadWorkboardFeature(client: .live(appModel: appModel))
        }
    }
}
