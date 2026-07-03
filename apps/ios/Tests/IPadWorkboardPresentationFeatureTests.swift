import ComposableArchitecture
import Testing
@testable import OpenClaw

@MainActor
struct IPadWorkboardPresentationFeatureTests {
    @Test func `begin create clears drafts and presents create sheet`() async {
        var initialState = IPadWorkboardPresentationFeature.State()
        initialState.draftTitle = "Old"
        initialState.draftNotes = "Old notes"
        initialState.errorText = "old error"
        let store = TestStore(initialState: initialState) {
            IPadWorkboardPresentationFeature()
        }

        await store.send(.beginCreateCardTapped) {
            $0.draftTitle = ""
            $0.draftNotes = ""
            $0.errorText = nil
            $0.presentedSheet = .create
        }
    }

    @Test func `draft and query controls update reducer state`() async {
        let store = TestStore(initialState: IPadWorkboardPresentationFeature.State()) {
            IPadWorkboardPresentationFeature()
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

    @Test func `status validation returns unknown status to active`() async {
        var initialState = IPadWorkboardPresentationFeature.State()
        initialState.selectedStatus = "missing"
        let store = TestStore(initialState: initialState) {
            IPadWorkboardPresentationFeature()
        }

        await store.send(.statusValidated(["todo", "ready"])) {
            $0.selectedStatus = "active"
        }
    }

    @Test func `create lifecycle clears sheet on success and keeps error on failure`() async {
        var initialState = IPadWorkboardPresentationFeature.State()
        initialState.presentedSheet = .create
        initialState.draftTitle = "Card"
        let store = TestStore(initialState: initialState) {
            IPadWorkboardPresentationFeature()
        }

        await store.send(.createStarted) {
            $0.isCreatingCard = true
            $0.errorText = nil
        }
        await store.send(.createFailed("boom")) {
            $0.isCreatingCard = false
            $0.errorText = "boom"
        }
        await store.send(.createStarted) {
            $0.isCreatingCard = true
            $0.errorText = nil
        }
        await store.send(.createSucceeded) {
            $0.isCreatingCard = false
            $0.draftTitle = ""
            $0.draftNotes = ""
            $0.presentedSheet = nil
        }
    }

    @Test func `create unavailable message matches gateway and draft state`() {
        var state = IPadWorkboardPresentationFeature.State()
        #expect(state.createUnavailableMessage(canRead: true, canWrite: true) == "Enter a title to create a card.")

        state.draftTitle = "Card"
        #expect(state.createUnavailableMessage(canRead: false, canWrite: false) ==
            "Connect from Settings to create, move, and dispatch cards.")

        state.isCreatingCard = true
        #expect(state
            .createUnavailableMessage(canRead: true, canWrite: true) == "Card creation is already in progress.")
    }
}
