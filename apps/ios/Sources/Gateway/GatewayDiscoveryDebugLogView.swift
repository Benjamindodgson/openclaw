import ComposableArchitecture
import SwiftUI
import UIKit

// swiftformat:disable redundantSendable
struct GatewayDiscoveryDebugLogClipboardText: Equatable, Sendable {
    var value: String
}

// swiftformat:enable redundantSendable

struct GatewayDiscoveryDebugLogClipboardClient {
    var copy: @Sendable (GatewayDiscoveryDebugLogClipboardText) async -> Void
}

extension GatewayDiscoveryDebugLogClipboardClient: DependencyKey {
    static let liveValue = GatewayDiscoveryDebugLogClipboardClient(copy: { text in
        await MainActor.run {
            UIPasteboard.general.string = text.value
        }
    })

    static let testValue = GatewayDiscoveryDebugLogClipboardClient(copy: { _ in })
}

extension DependencyValues {
    var gatewayDiscoveryDebugLogClipboard: GatewayDiscoveryDebugLogClipboardClient {
        get { self[GatewayDiscoveryDebugLogClipboardClient.self] }
        set { self[GatewayDiscoveryDebugLogClipboardClient.self] = newValue }
    }
}

@Reducer
struct GatewayDiscoveryDebugLogFeature {
    private let clipboardOverride: GatewayDiscoveryDebugLogClipboardClient?

    init(clipboard: GatewayDiscoveryDebugLogClipboardClient? = nil) {
        self.clipboardOverride = clipboard
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {}

    enum Action: Equatable, Sendable {
        struct CopyRequest: Equatable, Sendable {
            var log: GatewayDiscoveryDebugLogClipboardText
        }

        case copyButtonTapped(CopyRequest)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            @Dependency(\.gatewayDiscoveryDebugLogClipboard) var dependencyClipboard
            let clipboard = self.clipboardOverride ?? dependencyClipboard

            switch action {
            case let .copyButtonTapped(request):
                return .run { _ in
                    await clipboard.copy(request.log)
                }
            }
        }
        .autoLogActions()
    }
}

struct GatewayDiscoveryDebugLogView: View {
    @Environment(GatewayConnectionController.self) private var gatewayController
    @AppStorage("gateway.discovery.debugLogs") private var debugLogsEnabled: Bool = false
    @State private var store: StoreOf<GatewayDiscoveryDebugLogFeature>

    init(store: StoreOf<GatewayDiscoveryDebugLogFeature> = Store(
        initialState: GatewayDiscoveryDebugLogFeature.State())
    {
        GatewayDiscoveryDebugLogFeature()
    }) {
        self._store = SwiftUI.State(wrappedValue: store)
    }

    var body: some View {
        List {
            if !self.debugLogsEnabled {
                Text("Enable “Discovery Debug Logs” to start collecting events.")
                    .foregroundStyle(.secondary)
            }

            if self.gatewayController.discoveryDebugLog.isEmpty {
                Text("No log entries yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(self.gatewayController.discoveryDebugLog) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.formatTime(entry.ts))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(entry.message)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Discovery Logs")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Copy") {
                    self.store.send(.copyButtonTapped(.init(log: .init(value: self.formattedLog()))))
                }
                .disabled(self.gatewayController.discoveryDebugLog.isEmpty)
            }
        }
    }

    private func formattedLog() -> String {
        self.gatewayController.discoveryDebugLog
            .map { "\(Self.formatISO($0.ts)) \($0.message)" }
            .joined(separator: "\n")
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func formatTime(_ date: Date) -> String {
        self.timeFormatter.string(from: date)
    }

    private static func formatISO(_ date: Date) -> String {
        self.isoFormatter.string(from: date)
    }
}
