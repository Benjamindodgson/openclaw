import ComposableArchitecture
import Testing
@testable import OpenClaw

@MainActor
struct NotificationPermissionGuidanceFeatureTests {
    @Test func `open notifications dismisses prompt before routing to settings`() async {
        let probe = NotificationPermissionGuidanceProbe()
        let store = TestStore(initialState: NotificationPermissionGuidanceFeature.State()) {
            NotificationPermissionGuidanceFeature(client: probe.client)
        }

        await store.send(.openNotificationsButtonTapped(.init(approvalID: "approval-1")))
        await store.finish()

        #expect(probe.events == [
            .dismiss(suppressFuture: false),
            .openNotifications("approval-1"),
        ])
    }

    @Test func `not now dismisses prompt without suppressing future guidance`() async {
        let probe = NotificationPermissionGuidanceProbe()
        let store = TestStore(initialState: NotificationPermissionGuidanceFeature.State()) {
            NotificationPermissionGuidanceFeature(client: probe.client)
        }

        await store.send(.notNowButtonTapped)
        await store.finish()

        #expect(probe.events == [.dismiss(suppressFuture: false)])
    }

    @Test func `dont show again dismisses prompt and suppresses future guidance`() async {
        let probe = NotificationPermissionGuidanceProbe()
        let store = TestStore(initialState: NotificationPermissionGuidanceFeature.State()) {
            NotificationPermissionGuidanceFeature(client: probe.client)
        }

        await store.send(.dontShowAgainButtonTapped)
        await store.finish()

        #expect(probe.events == [.dismiss(suppressFuture: true)])
    }
}

private enum NotificationPermissionGuidanceProbeEvent: Equatable {
    case dismiss(suppressFuture: Bool)
    case openNotifications(String)
}

private final class NotificationPermissionGuidanceProbe: @unchecked Sendable {
    var events: [NotificationPermissionGuidanceProbeEvent] = []

    var client: NotificationPermissionGuidanceClient {
        NotificationPermissionGuidanceClient(
            dismissNotificationPermissionGuidancePrompt: { suppressFuture in
                self.events.append(.dismiss(suppressFuture: suppressFuture))
            },
            openNotifications: { approvalID in
                self.events.append(.openNotifications(approvalID))
            })
    }
}
