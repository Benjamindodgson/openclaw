import ComposableArchitecture
import Testing
@testable import OpenClaw

@MainActor
struct IPadWorkboardFeatureTests {
    @Test func `begin create clears drafts and presents create sheet`() async {
        var initialState = IPadWorkboardFeature.State()
        initialState.draftTitle = "Old"
        initialState.draftNotes = "Old notes"
        initialState.errorText = "old error"
        let store = TestStore(initialState: initialState) {
            IPadWorkboardFeature()
        }

        await store.send(.beginCreateCardTapped) {
            $0.draftTitle = ""
            $0.draftNotes = ""
            $0.errorText = nil
            $0.presentedSheet = .create
        }
    }

    @Test func `draft and query controls update reducer state`() async {
        let store = TestStore(initialState: IPadWorkboardFeature.State()) {
            IPadWorkboardFeature()
        }

        await store.send(.draftTitleChanged("  Ship TCA  ")) {
            $0.draftTitle = "  Ship TCA  "
        }
        await store.send(.draftNotesChanged("notes")) {
            $0.draftNotes = "notes"
        }
        await store.send(.queryChanged("gateway")) {
            $0.query = "gateway"
        }
        await store.send(.clearQueryTapped) {
            $0.query = ""
        }
    }

    @Test func `create unavailable message matches gateway and draft state`() {
        var state = IPadWorkboardFeature.State()
        #expect(state.createUnavailableMessage(canRead: true, canWrite: true) == "Enter a title to create a card.")

        state.draftTitle = "Card"
        #expect(state.createUnavailableMessage(canRead: false, canWrite: false) ==
            "Connect from Settings to create, move, and dispatch cards.")

        state.isCreatingCard = true
        #expect(state
            .createUnavailableMessage(canRead: true, canWrite: true) == "Card creation is already in progress.")
    }

    @Test func `refresh loads cards and board scopes through client`() async {
        let card = Self.card(id: "card-1", status: "todo", position: 20, boardID: "planning")
        let response = IPadWorkboardCardsResponse(cards: [card], statuses: ["todo", "done"])
        let boards = [IPadWorkboardBoardSummary(id: "ops"), IPadWorkboardBoardSummary(id: "planning")]
        var client = Self.failingClient()
        client.listCards = { boardID in
            #expect(boardID == "planning")
            return response
        }
        client.listBoards = { boards }
        var initialState = IPadWorkboardFeature.State()
        initialState.selectedStatus = "missing"
        let store = TestStore(initialState: initialState) {
            IPadWorkboardFeature(client: client)
        }

        await store.send(.boardScopeChanged(" planning ")) {
            $0.selectedBoardID = "planning"
        }
        await store.send(.refreshRequested(sceneActive: true, canRead: true, force: false)) {
            $0.isRefreshing = true
            $0.activeRefreshBoardID = "planning"
            $0.errorText = nil
            $0.selectedStatus = "active"
        }
        await store.receive(.refreshResponse(boardID: "planning", force: false, .success(response))) {
            $0.isRefreshing = false
            $0.activeRefreshBoardID = nil
            $0.cards = [card]
            $0.statuses = ["todo", "done"]
            $0.knownBoardIDs = ["planning"]
        }
        await store.receive(.boardScopesResponse(force: false, .success(boards))) {
            $0.knownBoardIDs = ["ops", "planning"]
        }
    }

    @Test func `stale refresh responses are ignored after board changes`() async {
        let currentCard = Self.card(id: "current", status: "todo", position: 10, boardID: "current")
        let staleCard = Self.card(id: "stale", status: "done", position: 20, boardID: "old")
        var initialState = IPadWorkboardFeature.State()
        initialState.selectedBoardID = "current"
        initialState.activeRefreshBoardID = "old"
        initialState.cards = [currentCard]
        initialState.isRefreshing = true
        let store = TestStore(initialState: initialState) {
            IPadWorkboardFeature(client: Self.failingClient())
        }

        await store.send(.refreshResponse(
            boardID: "old",
            force: true,
            .success(IPadWorkboardCardsResponse(cards: [staleCard], statuses: ["done"]))))
        {
            $0.isRefreshing = false
            $0.activeRefreshBoardID = nil
        }
    }

    @Test func `create request sends trimmed params and inserts returned card`() async {
        let existing = Self.card(id: "existing", status: "ready", position: 1000, boardID: "planning")
        let created = Self.card(id: "created", status: "ready", position: 2000, boardID: "planning")
        var client = Self.failingClient()
        client.create = { params in
            #expect(params.title == "New card")
            #expect(params.notes == "notes")
            #expect(params.status == "ready")
            #expect(params.position == 2000)
            #expect(params.boardId == "planning")
            return created
        }
        var initialState = IPadWorkboardFeature.State()
        initialState.cards = [existing]
        initialState.statuses = ["todo", "ready"]
        initialState.selectedStatus = "ready"
        initialState.selectedBoardID = "planning"
        initialState.presentedSheet = .create
        initialState.draftTitle = "  New card  "
        initialState.draftNotes = " notes "
        let store = TestStore(initialState: initialState) {
            IPadWorkboardFeature(client: client)
        }

        await store.send(.createRequested(canRead: true, canWrite: true)) {
            $0.isCreatingCard = true
            $0.errorText = nil
        }
        await store.receive(.createResponse(.success(created))) {
            $0.isCreatingCard = false
            $0.draftTitle = ""
            $0.draftNotes = ""
            $0.presentedSheet = nil
            $0.cards = [existing, created]
            $0.knownBoardIDs = ["planning"]
        }
    }

    @Test func `move and archive requests keep one busy card and replace returned card`() async {
        let card = Self.card(id: "card-1", status: "todo", position: 100)
        let moved = Self.card(id: "card-1", status: "running", position: 1000)
        let archived = Self.card(id: "card-1", status: "running", position: 1000, archivedAt: 100)
        var client = Self.failingClient()
        client.move = { params in
            #expect(params.id == "card-1")
            #expect(params.status == "running")
            #expect(params.position == 1000)
            return moved
        }
        client.archive = { params in
            #expect(params.id == "card-1")
            #expect(params.archived)
            return archived
        }
        var initialState = IPadWorkboardFeature.State()
        initialState.cards = [card]
        let store = TestStore(initialState: initialState) {
            IPadWorkboardFeature(client: client)
        }

        await store.send(.moveRequested(card, status: "running", canWrite: true)) {
            $0.busyCardID = "card-1"
            $0.errorText = nil
        }
        await store.receive(.moveResponse(.success(moved))) {
            $0.busyCardID = nil
            $0.cards = [moved]
            $0.knownBoardIDs = ["default"]
        }
        await store.send(.archiveRequested(moved, canWrite: true)) {
            $0.busyCardID = "card-1"
            $0.errorText = nil
        }
        await store.receive(.archiveResponse(.success(archived))) {
            $0.busyCardID = nil
            $0.cards = [archived]
            $0.knownBoardIDs = ["default"]
        }
    }

    @Test func `dispatch returns summary and refreshed cards`() async {
        let refreshed = Self.card(id: "running", status: "running", position: 50)
        let response = IPadWorkboardCardsResponse(cards: [refreshed], statuses: ["running"])
        let summary = IPadWorkboardDispatchSummary(startedCount: 1, dispatchCount: 1)
        var client = Self.failingClient()
        client.dispatch = { boardID in
            #expect(boardID == nil)
            return summary
        }
        client.listCards = { boardID in
            #expect(boardID == nil)
            return response
        }
        let store = TestStore(initialState: IPadWorkboardFeature.State()) {
            IPadWorkboardFeature(client: client)
        }

        await store.send(.dispatchRequested(canWrite: true)) {
            $0.isDispatching = true
            $0.errorText = nil
            $0.dispatchSummaryText = nil
        }
        await store.receive(.dispatchResponse(boardID: nil, .success(IPadWorkboardDispatchSnapshot(
            summary: summary,
            cardsResponse: response))))
        {
            $0.isDispatching = false
            $0.dispatchSummaryText = "1 dispatched: 1 started."
            $0.cards = [refreshed]
            $0.statuses = ["running"]
            $0.knownBoardIDs = ["default"]
        }
    }

    @Test func `refresh completion does not clear dispatch busy state`() async {
        let refreshed = Self.card(id: "card", status: "todo", position: 10)
        let response = IPadWorkboardCardsResponse(cards: [refreshed], statuses: ["todo"])
        var initialState = IPadWorkboardFeature.State()
        initialState.isRefreshing = true
        initialState.isDispatching = true
        var client = Self.failingClient()
        client.listBoards = { [] }
        let store = TestStore(initialState: initialState) {
            IPadWorkboardFeature(client: client)
        }

        await store.send(.refreshResponse(boardID: nil, force: true, .success(response))) {
            $0.isRefreshing = false
            $0.activeRefreshBoardID = nil
            $0.cards = [refreshed]
            $0.statuses = ["todo"]
            $0.knownBoardIDs = ["default"]
        }
        await store.receive(.boardScopesResponse(force: true, .success([])))
    }

    private static func failingClient() -> IPadWorkboardClient {
        IPadWorkboardClient(
            listCards: { _ in throw IPadWorkboardError.failed("unexpected listCards") },
            listBoards: { throw IPadWorkboardError.failed("unexpected listBoards") },
            create: { _ in throw IPadWorkboardError.failed("unexpected create") },
            move: { _ in throw IPadWorkboardError.failed("unexpected move") },
            archive: { _ in throw IPadWorkboardError.failed("unexpected archive") },
            dispatch: { _ in throw IPadWorkboardError.failed("unexpected dispatch") })
    }

    private static func card(
        id: String,
        title: String = "Card",
        status: String,
        position: Double,
        boardID: String? = nil,
        archivedAt: Double? = nil) -> IPadWorkboardCard
    {
        IPadWorkboardCard(
            id: id,
            title: title,
            notes: nil,
            status: status,
            priority: nil,
            labels: [],
            agentId: nil,
            sessionKey: nil,
            position: position,
            updatedAt: nil,
            metadata: IPadWorkboardMetadata(
                archivedAt: archivedAt,
                automation: IPadWorkboardAutomationMetadata(boardId: boardID)))
    }
}
