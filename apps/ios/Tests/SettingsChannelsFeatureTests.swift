import ComposableArchitecture
import Foundation
import OpenClawProtocol
import Testing
@testable import OpenClaw

@MainActor
struct SettingsChannelsFeatureTests {
    @Test func `offline refresh clears channel state`() async {
        var initialState = SettingsChannelsFeature.State()
        initialState.channelEntries = Self.connectedEntries
        initialState.loadingPhase = .inFlight
        initialState.errorText = .init(value: "old error")
        let store = TestStore(initialState: initialState) {
            SettingsChannelsFeature(client: Self.client())
        }

        await store.send(.refreshRequested(.init(
            sceneActivity: .init(isActive: true),
            readAccess: .init(canRead: false),
            force: .init(isForced: false))))
        {
            $0.channelEntries = .init()
            $0.loadingPhase = .idle
            $0.errorText = nil
        }
    }

    @Test func `refresh success stores normalized channel entries`() async {
        let store = TestStore(initialState: SettingsChannelsFeature.State()) {
            SettingsChannelsFeature(client: Self.client(status: { Self.connectedStatus }))
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
            result: .success(Self.connectedEntries))))
        {
            $0.channelEntries = Self.connectedEntries
            $0.loadingPhase = .idle
        }
    }

    @Test func `summary values are derived by reducer state`() {
        var state = SettingsChannelsFeature.State()
        state.channelEntries = Self.connectedEntries

        #expect(state.configuredEntryCount == 1)
        #expect(state.hasActiveEntry)
        #expect(state.headerValue(canRead: true) == "1")
        #expect(state.headerValue(canRead: false) == "Offline")
        #expect(state.summaryValue(canRead: true) == "1/1")
        #expect(state.summaryValue(canRead: false) == "offline")

        state.loadingPhase = .inFlight
        #expect(state.headerValue(canRead: true) == "Loading")
        #expect(state.summaryValue(canRead: true) == "loading")

        state.loadingPhase = .idle
        state.errorText = .init(value: "boom")
        #expect(state.summaryValue(canRead: true) == "error")
    }

    @Test func `soft refresh failure preserves existing entries`() async {
        var initialState = SettingsChannelsFeature.State()
        initialState.channelEntries = Self.connectedEntries
        let store = TestStore(initialState: initialState) {
            SettingsChannelsFeature(client: Self.client(status: { throw TestChannelsFailure.failed }))
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
            result: .failure(.failed(.init(message: .init(value: "boom")))))))
        {
            $0.loadingPhase = .idle
        }
    }

    @Test func `forced refresh failure surfaces error text`() async {
        var initialState = SettingsChannelsFeature.State()
        initialState.channelEntries = Self.connectedEntries
        let store = TestStore(initialState: initialState) {
            SettingsChannelsFeature(client: Self.client(status: { throw TestChannelsFailure.failed }))
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
            result: .failure(.failed(.init(message: .init(value: "boom")))))))
        {
            $0.loadingPhase = .idle
            $0.errorText = .init(value: "boom")
        }
    }

    @Test func `operation success refreshes entries and clears busy state`() async {
        let operation = SettingsChannelOperation(kind: .start, channelID: "telegram", accountID: "main")
        let store = TestStore(initialState: SettingsChannelsFeature.State()) {
            SettingsChannelsFeature(client: Self.client(status: { Self.connectedStatus }))
        }

        await store.send(.operationRequested(.init(
            kind: .start,
            target: .init(channelID: "telegram", accountID: "main"),
            readAccess: .init(canRead: true),
            adminAccess: .init(canAdmin: true))))
        {
            $0.busyOperation = operation
        }
        await store.receive(.operationResponse(.init(result: .success(Self.connectedEntries)))) {
            $0.busyOperation = nil
            $0.channelEntries = Self.connectedEntries
        }
    }

    @Test func `operation failure surfaces error text and clears busy state`() async {
        let operation = SettingsChannelOperation(kind: .start, channelID: "telegram", accountID: "main")
        let store = TestStore(initialState: SettingsChannelsFeature.State()) {
            SettingsChannelsFeature(client: Self.client(
                start: { _ in throw TestChannelsFailure.failed }))
        }

        await store.send(.operationRequested(.init(
            kind: .start,
            target: .init(channelID: "telegram", accountID: "main"),
            readAccess: .init(canRead: true),
            adminAccess: .init(canAdmin: true))))
        {
            $0.busyOperation = operation
        }
        await store.receive(.operationResponse(.init(
            result: .failure(.failed(.init(message: .init(value: "boom")))))))
        {
            $0.busyOperation = nil
            $0.errorText = .init(value: "boom")
        }
    }

    @Test func `operation requires admin scope`() async {
        let store = TestStore(initialState: SettingsChannelsFeature.State()) {
            SettingsChannelsFeature(client: Self.client(status: { Self.connectedStatus }))
        }

        await store.send(.operationRequested(.init(
            kind: .stop,
            target: .init(channelID: "telegram", accountID: "main"),
            readAccess: .init(canRead: true),
            adminAccess: .init(canAdmin: false))))
    }

    private static var connectedEntries: SettingsChannelEntries {
        SettingsChannelsFeature.entries(from: connectedStatus)
    }

    private static let connectedStatus = ChannelsStatusResult(
        ts: 1,
        channelorder: ["telegram"],
        channellabels: ["telegram": AnyCodable("Telegram")],
        channeldetaillabels: ["telegram": AnyCodable("Message routing client")],
        channelsystemimages: ["telegram": AnyCodable("paperplane")],
        channelmeta: nil,
        channels: ["telegram": AnyCodable(["configured": true])],
        channelaccounts: [
            "telegram": AnyCodable([
                [
                    "accountId": "main",
                    "name": "OpenClaw Ops",
                    "configured": true,
                    "enabled": true,
                    "running": true,
                    "connected": true,
                    "linked": true,
                    "healthState": "healthy",
                ],
            ]),
        ],
        channeldefaultaccountid: [:],
        eventloop: nil,
        partial: nil,
        warnings: nil)

    private static func client(
        status: @escaping @Sendable @MainActor () async throws -> ChannelsStatusResult = { Self.connectedStatus },
        start: @escaping @Sendable @MainActor (SettingsChannelOperationTarget) async throws -> Void = {
            _ in
        },
        stop: @escaping @Sendable @MainActor (SettingsChannelOperationTarget) async throws -> Void = {
            _ in
        },
        logout: @escaping @Sendable @MainActor (SettingsChannelOperationTarget) async throws -> Void = {
            _ in
        }) -> SettingsChannelsClient
    {
        SettingsChannelsClient(
            status: status,
            start: start,
            stop: stop,
            logout: logout)
    }
}

private enum TestChannelsFailure: LocalizedError {
    case failed

    var errorDescription: String? {
        "boom"
    }
}
