import ComposableArchitecture
import SwiftUI
import UIKit

struct TalkRuntimeIssueClipboardClient {
    var copy: @Sendable (String) async -> Void
}

extension TalkRuntimeIssueClipboardClient: DependencyKey {
    static let liveValue = TalkRuntimeIssueClipboardClient(copy: { text in
        await MainActor.run {
            UIPasteboard.general.string = text
        }
    })

    static let testValue = TalkRuntimeIssueClipboardClient(copy: { _ in })
}

extension DependencyValues {
    var talkRuntimeIssueClipboard: TalkRuntimeIssueClipboardClient {
        get { self[TalkRuntimeIssueClipboardClient.self] }
        set { self[TalkRuntimeIssueClipboardClient.self] = newValue }
    }
}

@Reducer
struct TalkRuntimeIssueDetailsFeature {
    private let clipboardOverride: TalkRuntimeIssueClipboardClient?

    init(clipboard: TalkRuntimeIssueClipboardClient? = nil) {
        self.clipboardOverride = clipboard
    }

    // swiftformat:disable redundantSendable
    @ObservableState
    struct State: Equatable, Sendable {
        var copyFeedback: String?
    }

    enum Action: Equatable, Sendable {
        case copyDiagnosticsButtonTapped(String)
    }

    // swiftformat:enable redundantSendable

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            @Dependency(\.talkRuntimeIssueClipboard) var dependencyClipboard
            let clipboard = self.clipboardOverride ?? dependencyClipboard

            switch action {
            case let .copyDiagnosticsButtonTapped(details):
                state.copyFeedback = "Copied diagnostics"
                return .run { _ in
                    await clipboard.copy(details)
                }
            }
        }
        .autoLogActions()
    }
}

struct TalkRuntimeIssueBanner: View {
    let issue: TalkRuntimeIssue
    var onOpenSettings: (() -> Void)?
    var onShowDetails: (() -> Void)?

    var body: some View {
        OpenClawNoticeBanner(
            icon: self.iconName,
            title: self.issue.fallbackBannerTitle,
            message: self.issue.fallbackBannerMessage,
            ownerLabel: self.issue.fallbackBannerOwnerLabel,
            tint: self.tint,
            detail: .accent(self.issue.displayMessage),
            primaryActionTitle: "Open Settings",
            onPrimaryAction: self.onOpenSettings,
            secondaryActionTitle: "Details",
            onSecondaryAction: self.onShowDetails)
    }

    private var iconName: String {
        "exclamationmark.triangle.fill"
    }

    private var tint: Color {
        .orange
    }
}

struct TalkRuntimeIssueDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let issue: TalkRuntimeIssue
    var onOpenSettings: (() -> Void)?
    @State private var store: StoreOf<TalkRuntimeIssueDetailsFeature>

    init(
        issue: TalkRuntimeIssue,
        onOpenSettings: (() -> Void)? = nil,
        store: StoreOf<TalkRuntimeIssueDetailsFeature> = Store(
            initialState: TalkRuntimeIssueDetailsFeature.State())
        {
            TalkRuntimeIssueDetailsFeature()
        })
    {
        self.issue = issue
        self.onOpenSettings = onOpenSettings
        self._store = SwiftUI.State(wrappedValue: store)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(self.issue.fallbackBannerTitle)
                            .font(.title3.weight(.semibold))
                        Text(self.issue.fallbackBannerMessage)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Text(self.issue.displayMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                Section("Technical details") {
                    Text(verbatim: self.issue.technicalDetails)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Button("Copy diagnostics") {
                        self.store.send(.copyDiagnosticsButtonTapped(self.issue.technicalDetails))
                    }
                }

                if let copyFeedback = self.store.copyFeedback {
                    Section {
                        Text(copyFeedback)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Talk fallback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let onOpenSettings {
                        Button("Open Settings") {
                            self.dismiss()
                            onOpenSettings()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        self.dismiss()
                    }
                }
            }
        }
    }
}
