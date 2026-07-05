import ComposableArchitecture
import SwiftUI

// swiftformat:disable redundantSendable
struct NotificationPermissionGuidanceApprovalID: Equatable, Sendable {
    var value: String
}

// swiftformat:enable redundantSendable

struct NotificationPermissionGuidanceClient {
    var dismissNotificationPermissionGuidancePrompt: @Sendable @MainActor (Bool) async -> Void
    var openNotifications: @Sendable @MainActor (NotificationPermissionGuidanceApprovalID) async -> Void
}

extension NotificationPermissionGuidanceClient: DependencyKey {
    static let liveValue = NotificationPermissionGuidanceClient(
        dismissNotificationPermissionGuidancePrompt: { _ in },
        openNotifications: { _ in })

    static let testValue = NotificationPermissionGuidanceClient(
        dismissNotificationPermissionGuidancePrompt: { _ in },
        openNotifications: { _ in })

    @MainActor
    static func live(
        appModel: NodeAppModel,
        openNotifications: @escaping @Sendable @MainActor (String) -> Void)
        -> Self
    {
        NotificationPermissionGuidanceClient(
            dismissNotificationPermissionGuidancePrompt: { suppressFuture in
                appModel.dismissNotificationPermissionGuidancePrompt(suppressFuture: suppressFuture)
            },
            openNotifications: { approvalID in
                openNotifications(approvalID.value)
            })
    }
}

extension DependencyValues {
    var notificationPermissionGuidance: NotificationPermissionGuidanceClient {
        get { self[NotificationPermissionGuidanceClient.self] }
        set { self[NotificationPermissionGuidanceClient.self] = newValue }
    }
}

@Reducer
struct NotificationPermissionGuidanceFeature {
    private let clientOverride: NotificationPermissionGuidanceClient?

    init(client: NotificationPermissionGuidanceClient? = nil) {
        self.clientOverride = client
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {}

    enum Action: Equatable, Sendable {
        struct OpenNotificationsRequest: Equatable, Sendable {
            var approvalID: NotificationPermissionGuidanceApprovalID
        }

        case dontShowAgainButtonTapped
        case notNowButtonTapped
        case openNotificationsButtonTapped(OpenNotificationsRequest)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            @Dependency(\.notificationPermissionGuidance) var dependencyClient
            let client = self.clientOverride ?? dependencyClient

            switch action {
            case .dontShowAgainButtonTapped:
                return self.dismiss(suppressFuture: true, client: client)

            case .notNowButtonTapped:
                return self.dismiss(suppressFuture: false, client: client)

            case let .openNotificationsButtonTapped(request):
                return .run { _ in
                    await client.dismissNotificationPermissionGuidancePrompt(false)
                    await client.openNotifications(request.approvalID)
                }
            }
        }
        .autoLogActions()
    }

    private func dismiss(
        suppressFuture: Bool,
        client: NotificationPermissionGuidanceClient)
        -> Effect<Action>
    {
        .run { _ in
            await client.dismissNotificationPermissionGuidancePrompt(suppressFuture)
        }
    }
}

private struct NotificationPermissionGuidanceDialogModifier: ViewModifier {
    @Environment(NodeAppModel.self) private var appModel: NodeAppModel
    @State private var store: StoreOf<NotificationPermissionGuidanceFeature>

    init(
        store: StoreOf<NotificationPermissionGuidanceFeature> = Store(
            initialState: NotificationPermissionGuidanceFeature.State())
        {
            NotificationPermissionGuidanceFeature()
        })
    {
        self._store = State(wrappedValue: store)
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if let prompt = self.appModel.pendingNotificationPermissionGuidancePrompt {
                    ZStack {
                        Color.black.opacity(0.38)
                            .ignoresSafeArea()

                        NotificationPermissionGuidanceCard(
                            onOpenNotifications: {
                                self.store.send(.openNotificationsButtonTapped(.init(
                                    approvalID: .init(value: prompt.approvalId))))
                            },
                            onDismiss: {
                                self.store.send(.notNowButtonTapped)
                            },
                            onSuppressFuture: {
                                self.store.send(.dontShowAgainButtonTapped)
                            })
                            .padding(.horizontal, 20)
                            .frame(maxWidth: 460)
                            .transition(.scale(scale: 0.98).combined(with: .opacity))
                    }
                    .zIndex(2)
                    .id(prompt.id)
                }
            }
            .animation(
                .easeInOut(duration: 0.18),
                value: self.appModel.pendingNotificationPermissionGuidancePrompt?.id)
    }
}

private struct NotificationPermissionGuidanceCard: View {
    let onOpenNotifications: () -> Void
    let onDismiss: () -> Void
    let onSuppressFuture: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Notifications are off")
                    .font(.headline)
                Text(
                    """
                    Exec approvals can only be reviewed while OpenClaw is open and connected.

                    Enable Notifications to receive approval notifications while OpenClaw is not open.
                    """)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                Button {
                    self.onOpenNotifications()
                } label: {
                    Text("Open Notifications Settings")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(role: .cancel) {
                    self.onDismiss()
                } label: {
                    Text("Not Now")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    self.onSuppressFuture()
                } label: {
                    Text("Don't show again")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
        .padding(18)
        .proPanelSurface(tint: OpenClawBrand.warn, radius: 20, isProminent: true)
    }
}

extension View {
    func notificationPermissionGuidanceDialog(
        store: StoreOf<NotificationPermissionGuidanceFeature> = Store(
            initialState: NotificationPermissionGuidanceFeature.State())
        {
            NotificationPermissionGuidanceFeature()
        }) -> some View
    {
        self.modifier(NotificationPermissionGuidanceDialogModifier(store: store))
    }
}
