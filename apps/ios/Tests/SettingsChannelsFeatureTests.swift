import ComposableArchitecture
import Foundation
import OpenClawProtocol
import Testing
@testable import OpenClaw

@MainActor
struct SettingsChannelsFeatureTests {
    @Test func `offline refresh clears channel state`() async {
        var initialState = SettingsChannelsFeature.State()
        initialState.entries = Self.connectedEntries
        initialState.isLoading = true
        initialState.errorText = "old error"
        let store = TestStore(initialState: initialState) {
            SettingsChannelsFeature(client: Self.client())
        }

        await store.send(.refreshRequested(.init(sceneActive: true, canRead: false, force: false))) {
            $0.entries = []
            $0.isLoading = false
            $0.errorText = nil
        }
    }

    @Test func `refresh success stores normalized channel entries`() async {
        let store = TestStore(initialState: SettingsChannelsFeature.State()) {
            SettingsChannelsFeature(client: Self.client(status: { Self.connectedStatus }))
        }

        await store.send(.refreshRequested(.init(sceneActive: true, canRead: true, force: false))) {
            $0.isLoading = true
        }
        await store.receive(.refreshResponse(.init(force: false, result: .success(Self.connectedEntries)))) {
            $0.entries = Self.connectedEntries
            $0.isLoading = false
        }
    }

    @Test func `soft refresh failure preserves existing entries`() async {
        var initialState = SettingsChannelsFeature.State()
        initialState.entries = Self.connectedEntries
        let store = TestStore(initialState: initialState) {
            SettingsChannelsFeature(client: Self.client(status: { throw TestChannelsFailure.failed }))
        }

        await store.send(.refreshRequested(.init(sceneActive: true, canRead: true, force: false))) {
            $0.isLoading = true
        }
        await store.receive(.refreshResponse(.init(force: false, result: .failure(.failed("boom"))))) {
            $0.isLoading = false
        }
    }

    @Test func `forced refresh failure surfaces error text`() async {
        var initialState = SettingsChannelsFeature.State()
        initialState.entries = Self.connectedEntries
        let store = TestStore(initialState: initialState) {
            SettingsChannelsFeature(client: Self.client(status: { throw TestChannelsFailure.failed }))
        }

        await store.send(.refreshRequested(.init(sceneActive: true, canRead: true, force: true))) {
            $0.isLoading = true
        }
        await store.receive(.refreshResponse(.init(force: true, result: .failure(.failed("boom"))))) {
            $0.isLoading = false
            $0.errorText = "boom"
        }
    }

    @Test func `operation success refreshes entries and clears busy state`() async {
        let operation = SettingsChannelOperation(kind: .start, channelID: "telegram", accountID: "main")
        let store = TestStore(initialState: SettingsChannelsFeature.State()) {
            SettingsChannelsFeature(client: Self.client(status: { Self.connectedStatus }))
        }

        await store.send(.operationRequested(.init(
            kind: .start,
            channelID: "telegram",
            accountID: "main",
            canRead: true,
            canAdmin: true)))
        {
            $0.busyOperation = operation
        }
        await store.receive(.operationResponse(.success(Self.connectedEntries))) {
            $0.busyOperation = nil
            $0.entries = Self.connectedEntries
        }
    }

    @Test func `operation requires admin scope`() async {
        let store = TestStore(initialState: SettingsChannelsFeature.State()) {
            SettingsChannelsFeature(client: Self.client(status: { Self.connectedStatus }))
        }

        await store.send(.operationRequested(.init(
            kind: .stop,
            channelID: "telegram",
            accountID: "main",
            canRead: true,
            canAdmin: false)))
    }

    private static var connectedEntries: [SettingsChannelEntry] {
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
        start: @escaping @Sendable @MainActor (_ channelID: String, _ accountID: String?) async throws -> Void = {
            _, _ in
        },
        stop: @escaping @Sendable @MainActor (_ channelID: String, _ accountID: String?) async throws -> Void = {
            _, _ in
        },
        logout: @escaping @Sendable @MainActor (_ channelID: String, _ accountID: String?) async throws -> Void = {
            _, _ in
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
