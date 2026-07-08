import Combine
import ComposableArchitecture
import CoreImage
import OpenClawKit
import PhotosUI
import SwiftUI
import UIKit

struct OnboardingWizardView: View {
    @Environment(NodeAppModel.self) private var appModel: NodeAppModel
    @Environment(GatewayConnectionController.self) private var gatewayController: GatewayConnectionController
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("node.instanceId") private var instanceId: String = UUID().uuidString
    @AppStorage("gateway.discovery.domain") private var discoveryDomain: String = ""
    @AppStorage("onboarding.developerMode") private var developerModeEnabled: Bool = false
    @State private var stepStore: StoreOf<OnboardingStepFeature>
    @State private var onboardingStateStore: StoreOf<OnboardingStateFeature>
    @State private var credentialsStore: StoreOf<OnboardingCredentialsFeature>

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var statusStore: StoreOf<OnboardingStatusFeature>

    @State private var presentationStore: StoreOf<OnboardingPresentationFeature>

    @State private var gatewayConnectionStore: StoreOf<OnboardingGatewayConnectionFeature>

    @State private var appleReviewDemoStore: StoreOf<OnboardingAppleReviewDemoFeature>

    @State private var pairingResumeStore: StoreOf<OnboardingPairingResumeFeature>

    @State private var gatewayProblemPrimaryActionStore: StoreOf<OnboardingGatewayProblemPrimaryActionFeature>

    @State private var discoveryRestartStore: StoreOf<OnboardingDiscoveryRestartFeature>

    @State private var connectionFormStore: StoreOf<OnboardingConnectionFormFeature>

    @State private var setupCodeStore: StoreOf<OnboardingSetupCodeFeature>

    @State private var photoImportStore: StoreOf<OnboardingQRPhotoImportFeature>

    private static let pairingAutoResumeTicker = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    let allowSkip: Bool
    let onRequestLocalNetworkAccess: (String) -> Void
    let onClose: () -> Void
    private let gatewayTrustPromptStoreFactory: @MainActor (GatewayConnectionController) -> StoreOf<
        GatewayTrustPromptFeature,
    >

    init(
        allowSkip: Bool,
        onRequestLocalNetworkAccess: @escaping (String) -> Void,
        onClose: @escaping () -> Void,
        stepStore: StoreOf<OnboardingStepFeature>? = nil,
        stepStoreFactory: () -> StoreOf<OnboardingStepFeature> = {
            Store(
                initialState: OnboardingStepFeature.State(
                    step: OnboardingStateStore.shouldPresentFirstRunIntro() ? .intro : .welcome))
            {
                OnboardingStepFeature()
            }
        },
        onboardingStateStore: StoreOf<OnboardingStateFeature>? = nil,
        onboardingStateStoreFactory: () -> StoreOf<OnboardingStateFeature> = {
            Store(initialState: OnboardingStateFeature.State()) {
                OnboardingStateFeature()
            }
        },
        credentialsStore: StoreOf<OnboardingCredentialsFeature>? = nil,
        credentialsStoreFactory: () -> StoreOf<OnboardingCredentialsFeature> = {
            Store(initialState: OnboardingCredentialsFeature.State()) {
                OnboardingCredentialsFeature()
            }
        },
        statusStore: StoreOf<OnboardingStatusFeature>? = nil,
        statusStoreFactory: () -> StoreOf<OnboardingStatusFeature> = {
            Store(initialState: OnboardingStatusFeature.State()) {
                OnboardingStatusFeature()
            }
        },
        presentationStore: StoreOf<OnboardingPresentationFeature>? = nil,
        presentationStoreFactory: () -> StoreOf<OnboardingPresentationFeature> = {
            Store(initialState: OnboardingPresentationFeature.State()) {
                OnboardingPresentationFeature()
            }
        },
        gatewayConnectionStore: StoreOf<OnboardingGatewayConnectionFeature>? = nil,
        gatewayConnectionStoreFactory: () -> StoreOf<OnboardingGatewayConnectionFeature> = {
            Store(initialState: OnboardingGatewayConnectionFeature.State()) {
                OnboardingGatewayConnectionFeature()
            }
        },
        appleReviewDemoStore: StoreOf<OnboardingAppleReviewDemoFeature>? = nil,
        appleReviewDemoStoreFactory: () -> StoreOf<OnboardingAppleReviewDemoFeature> = {
            Store(initialState: OnboardingAppleReviewDemoFeature.State()) {
                OnboardingAppleReviewDemoFeature()
            }
        },
        pairingResumeStore: StoreOf<OnboardingPairingResumeFeature>? = nil,
        pairingResumeStoreFactory: () -> StoreOf<OnboardingPairingResumeFeature> = {
            Store(initialState: OnboardingPairingResumeFeature.State()) {
                OnboardingPairingResumeFeature()
            }
        },
        gatewayProblemPrimaryActionStore: StoreOf<OnboardingGatewayProblemPrimaryActionFeature>? = nil,
        gatewayProblemPrimaryActionStoreFactory: () -> StoreOf<OnboardingGatewayProblemPrimaryActionFeature> = {
            Store(initialState: OnboardingGatewayProblemPrimaryActionFeature.State()) {
                OnboardingGatewayProblemPrimaryActionFeature()
            }
        },
        discoveryRestartStore: StoreOf<OnboardingDiscoveryRestartFeature>? = nil,
        discoveryRestartStoreFactory: () -> StoreOf<OnboardingDiscoveryRestartFeature> = {
            Store(initialState: OnboardingDiscoveryRestartFeature.State()) {
                OnboardingDiscoveryRestartFeature()
            }
        },
        connectionFormStore: StoreOf<OnboardingConnectionFormFeature>? = nil,
        connectionFormStoreFactory: () -> StoreOf<OnboardingConnectionFormFeature> = {
            Store(initialState: OnboardingConnectionFormFeature.State()) {
                OnboardingConnectionFormFeature()
            }
        },
        setupCodeStore: StoreOf<OnboardingSetupCodeFeature>? = nil,
        setupCodeStoreFactory: () -> StoreOf<OnboardingSetupCodeFeature> = {
            Store(initialState: OnboardingSetupCodeFeature.State()) {
                OnboardingSetupCodeFeature()
            }
        },
        photoImportStore: StoreOf<OnboardingQRPhotoImportFeature>? = nil,
        photoImportStoreFactory: () -> StoreOf<OnboardingQRPhotoImportFeature> = {
            Store(initialState: OnboardingQRPhotoImportFeature.State()) {
                OnboardingQRPhotoImportFeature()
            }
        },
        gatewayTrustPromptStoreFactory: @escaping @MainActor (GatewayConnectionController) -> StoreOf<
            GatewayTrustPromptFeature,
        > = { gatewayController in
            Store(initialState: GatewayTrustPromptFeature.State()) {
                GatewayTrustPromptFeature(client: .live(gatewayController: gatewayController))
            }
        })
    {
        self.allowSkip = allowSkip
        self.onRequestLocalNetworkAccess = onRequestLocalNetworkAccess
        self.onClose = onClose
        self.gatewayTrustPromptStoreFactory = gatewayTrustPromptStoreFactory
        let resolvedStepStore = stepStore ?? stepStoreFactory()
        let resolvedOnboardingStateStore = onboardingStateStore ?? onboardingStateStoreFactory()
        let resolvedCredentialsStore = credentialsStore ?? credentialsStoreFactory()
        let resolvedStatusStore = statusStore ?? statusStoreFactory()
        let resolvedPresentationStore = presentationStore ?? presentationStoreFactory()
        let resolvedGatewayConnectionStore = gatewayConnectionStore ?? gatewayConnectionStoreFactory()
        let resolvedAppleReviewDemoStore = appleReviewDemoStore ?? appleReviewDemoStoreFactory()
        let resolvedPairingResumeStore = pairingResumeStore ?? pairingResumeStoreFactory()
        let resolvedGatewayProblemPrimaryActionStore =
            gatewayProblemPrimaryActionStore ?? gatewayProblemPrimaryActionStoreFactory()
        let resolvedDiscoveryRestartStore = discoveryRestartStore ?? discoveryRestartStoreFactory()
        let resolvedConnectionFormStore = connectionFormStore ?? connectionFormStoreFactory()
        let resolvedSetupCodeStore = setupCodeStore ?? setupCodeStoreFactory()
        let resolvedPhotoImportStore = photoImportStore ?? photoImportStoreFactory()
        self._stepStore = State(wrappedValue: resolvedStepStore)
        self._onboardingStateStore = State(wrappedValue: resolvedOnboardingStateStore)
        self._credentialsStore = State(wrappedValue: resolvedCredentialsStore)
        self._statusStore = State(wrappedValue: resolvedStatusStore)
        self._presentationStore = State(wrappedValue: resolvedPresentationStore)
        self._gatewayConnectionStore = State(wrappedValue: resolvedGatewayConnectionStore)
        self._appleReviewDemoStore = State(wrappedValue: resolvedAppleReviewDemoStore)
        self._pairingResumeStore = State(wrappedValue: resolvedPairingResumeStore)
        self._gatewayProblemPrimaryActionStore = State(wrappedValue: resolvedGatewayProblemPrimaryActionStore)
        self._discoveryRestartStore = State(wrappedValue: resolvedDiscoveryRestartStore)
        self._connectionFormStore = State(wrappedValue: resolvedConnectionFormStore)
        self._setupCodeStore = State(wrappedValue: resolvedSetupCodeStore)
        self._photoImportStore = State(wrappedValue: resolvedPhotoImportStore)
    }

    @MainActor
    private func makeGatewayTrustPromptStore() -> StoreOf<GatewayTrustPromptFeature> {
        self.gatewayTrustPromptStoreFactory(self.gatewayController)
    }

    private var isFullScreenStep: Bool {
        self.stepStore.isFullScreenStep
    }

    private var step: OnboardingStep {
        self.stepStore.step
    }

    private var connectMessage: String? {
        self.statusStore.connectMessage
    }

    private var connectingGatewayID: String? {
        self.statusStore.connectingGatewayID
    }

    private var issue: GatewayConnectionIssue {
        self.statusStore.issue
    }

    private var statusLine: String {
        self.statusStore.statusLine
    }

    private var gatewayPassword: String {
        self.credentialsStore.gatewayPassword
    }

    private var gatewayToken: String {
        self.credentialsStore.gatewayToken
    }

    private var gatewayPasswordBinding: Binding<String> {
        Binding(
            get: { self.credentialsStore.gatewayPassword },
            set: { self.updateGatewayPassword($0) })
    }

    private var gatewayTokenBinding: Binding<String> {
        Binding(
            get: { self.credentialsStore.gatewayToken },
            set: { self.updateGatewayToken($0) })
    }

    private var currentProblem: GatewayConnectionProblem? {
        self.appModel.lastGatewayProblem
    }

    private var qrScannerPresentation: Binding<Bool> {
        Binding(
            get: { self.presentationStore.showQRScanner },
            set: { isPresented in
                if isPresented {
                    self.presentationStore.send(.qrScannerButtonTapped)
                } else {
                    self.presentationStore.send(.qrScannerDismissed)
                }
            })
    }

    private var gatewayProblemDetailsPresentation: Binding<Bool> {
        Binding(
            get: { self.presentationStore.showGatewayProblemDetails },
            set: { isPresented in
                if isPresented {
                    self.presentationStore.send(.gatewayProblemDetailsButtonTapped)
                } else {
                    self.presentationStore.send(.gatewayProblemDetailsDismissed)
                }
            })
    }

    private var setupCodeBinding: Binding<String> {
        Binding(
            get: { self.setupCodeStore.setupCode },
            set: { self.setupCodeStore.send(.setupCodeChanged(.init(code: .init(value: $0)))) })
    }

    private var selectedMode: OnboardingConnectionMode? {
        self.connectionFormStore.selectedMode
    }

    private var manualPort: Int {
        self.connectionFormStore.manualPort
    }

    private var manualTLS: Bool {
        self.connectionFormStore.manualTLS
    }

    private var manualHostBinding: Binding<String> {
        Binding(
            get: { self.connectionFormStore.manualHost },
            set: { self.connectionFormStore.send(.manualHostChanged(.init(host: .init(value: $0)))) })
    }

    private var manualPortTextBinding: Binding<String> {
        Binding(
            get: { self.connectionFormStore.manualPortText },
            set: { self.connectionFormStore.send(.manualPortTextChanged(.init(text: .init(value: $0)))) })
    }

    private var manualTLSBinding: Binding<Bool> {
        Binding(
            get: { self.connectionFormStore.manualTLS },
            set: { self.connectionFormStore.send(.manualTLSChanged(.init(useTLS: .init(value: $0)))) })
    }

    var body: some View {
        NavigationStack {
            Group {
                switch self.step {
                case .intro:
                    self.introStep
                case .welcome:
                    self.welcomeStep
                case .success:
                    self.successStep
                default:
                    Form {
                        switch self.step {
                        case .mode:
                            self.modeStep
                        case .connect:
                            self.connectStep
                        case .auth:
                            self.authStep
                        default:
                            EmptyView()
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .navigationTitle(self.isFullScreenStep ? "" : self.step.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !self.isFullScreenStep {
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 2) {
                            Text(self.step.title)
                                .font(.headline)
                            Text(self.step.manualProgressTitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if self.step.canGoBack {
                        Button {
                            self.navigateBack()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                    } else if self.allowSkip {
                        Button("Close") {
                            self.onClose()
                        }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil,
                            from: nil,
                            for: nil)
                    }
                }
            }
        }
        .gatewayTrustPromptAlert(store: self.makeGatewayTrustPromptStore())
        .alert("QR Scanner Unavailable", isPresented: Binding(
            get: { self.presentationStore.scannerError != nil },
            set: { if !$0 { self.presentationStore.send(.qrScannerErrorDismissed) } }))
        {
            Button("OK", role: .cancel) {}
        } message: {
            Text(self.presentationStore.scannerError ?? "")
        }
        .sheet(isPresented: self.qrScannerPresentation) {
                NavigationStack {
                    QRScannerView(
                        onGatewayLink: { link in
                            Task { @MainActor in await self.handleScannedLink(link) }
                        },
                        onSetupCode: { code in
                            Task { @MainActor in await self.handleScannedSetupCode(code) }
                        },
                        onError: { error in
                            let scannerError = OnboardingPresentationFeature.Action.QRScannerError(
                                message: .init(value: error))
                            self.statusStore.send(.scannerErrorReceived(scannerError.statusError))
                            self.presentationStore.send(.qrScannerErrorReceived(scannerError))
                        },
                        onDismiss: {
                            self.presentationStore.send(.qrScannerDismissed)
                        })
                        .ignoresSafeArea()
                        .navigationTitle("Scan QR Code")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Cancel") { self.presentationStore.send(.qrScannerDismissed) }
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                PhotosPicker(selection: self.$selectedPhoto, matching: .images) {
                                    Label("Photos", systemImage: "photo")
                                }
                                .disabled(self.photoImportStore.importPhase == .inFlight)
                            }
                        }
                }
                .onChange(of: self.selectedPhoto) { _, newValue in
                    self.handleSelectedPhoto(newValue)
                }
            }
            .sheet(isPresented: self.gatewayProblemDetailsPresentation) {
                if let currentProblem = self.currentProblem {
                    GatewayProblemDetailsSheet(
                        problem: currentProblem,
                        primaryActionTitle: self.gatewayProblemPrimaryActionTitle(currentProblem),
                        onPrimaryAction: {
                            Task { await self.handleGatewayProblemPrimaryAction(currentProblem) }
                        })
                }
            }
            .onAppear {
                self.initializeState()
                self.requestLocalNetworkAccessIfPastIntro(reason: "onboarding_appear")
            }
            .onDisappear {
                self.discoveryRestartStore.send(.disappeared)
            }
            .onChange(of: self.discoveryDomain) { _, _ in
                self.scheduleDiscoveryRestart()
            }
            .onChange(of: self.discoveryRestartStore.restartRequestID) { _, _ in
                self.gatewayController.restartDiscovery()
            }
            .onChange(of: self.appModel.lastGatewayProblem) { _, newValue in
                self.updateConnectionIssue(problem: newValue, statusText: self.appModel.gatewayStatusText)
            }
            .onChange(of: self.appModel.gatewayStatusText) { _, newValue in
                self.updateConnectionIssue(problem: self.appModel.lastGatewayProblem, statusText: newValue)
            }
            .onChange(of: self.appModel.gatewayServerName) { _, newValue in
                guard newValue != nil else { return }
                let transitionRequest = OnboardingStatusFeature
                    .gatewayConnectionSuccessTransitionRequest(selectedMode: self.selectedMode)
                self.presentationStore.send(transitionRequest.presentationAction)
                self.statusStore.send(transitionRequest.statusAction)
                if let completionRequest = self.statusStore.gatewayConnectionCompletionRequest {
                    self.onboardingStateStore.send(.markCompleted(completionRequest))
                }
                self.statusStore.send(transitionRequest.handledStatusAction)
                self.stepStore.send(transitionRequest.stepAction)
            }
            .onChange(of: self.scenePhase) { _, newValue in
                guard newValue == .active else { return }
                self.attemptAutomaticPairingResumeIfNeeded()
            }
            .onReceive(Self.pairingAutoResumeTicker) { _ in
                self.attemptAutomaticPairingResumeIfNeeded()
            }
    }

    private var introStep: some View {
        OnboardingIntroStep(onContinue: self.advanceFromIntro)
    }

    private var welcomeStep: some View {
        OnboardingWelcomeStep(
            statusLine: self.statusLine,
            onScanQRCode: {
                self.openQRScanner(OnboardingStatusFeature.qrScannerOpeningRequest)
            },
            onManualSetup: {
                self.stepStore.send(.stepChanged(.init(step: .mode)))
            })
    }

    @ViewBuilder
    private var modeStep: some View {
        self.setupCodeSection

        Section("Connection Mode") {
            OnboardingModeRow(
                title: OnboardingConnectionMode.homeNetwork.title,
                subtitle: "LAN or Tailscale host",
                selected: self.selectedMode == .homeNetwork)
            {
                self.selectMode(.homeNetwork)
            }

            OnboardingModeRow(
                title: OnboardingConnectionMode.remoteDomain.title,
                subtitle: "VPS with domain",
                selected: self.selectedMode == .remoteDomain)
            {
                self.selectMode(.remoteDomain)
            }

            self.developerModeToggleRow

            if self.developerModeEnabled {
                OnboardingModeRow(
                    title: OnboardingConnectionMode.developerLocal.title,
                    subtitle: "For local iOS app development",
                    selected: self.selectedMode == .developerLocal)
                {
                    self.selectMode(.developerLocal)
                }
            }
        }

        Section {
            Button("Continue") {
                self.stepStore.send(.stepChanged(.init(step: .connect)))
            }
            .disabled(self.selectedMode == nil)
        }
    }

    private var developerModeToggleRow: some View {
        self.onboardingButtonToggle(
            "Developer mode",
            isOn: Binding(
                get: { self.developerModeEnabled },
                set: { enabled in
                    self.developerModeEnabled = enabled
                    if !enabled {
                        self.connectionFormStore.send(.developerModeDisabled)
                    }
                }))
    }

    private func onboardingButtonToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        // Onboarding Form switch rows need full-width taps; native Toggle only hits the switch edge on iOS 26.
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack {
                Text(title)
                Spacer(minLength: 8)
                self.onboardingSwitchIndicator(isOn: isOn.wrappedValue)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isOn.wrappedValue ? "On" : "Off")
    }

    private func onboardingSwitchIndicator(isOn: Bool) -> some View {
        Capsule()
            .fill(isOn ? OpenClawBrand.accent : Color.secondary.opacity(0.35))
            .frame(width: 52, height: 32)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 28, height: 28)
                    .padding(2)
                    .shadow(color: Color.black.opacity(0.14), radius: 1, x: 0, y: 1)
            }
    }

    @ViewBuilder
    private var connectStep: some View {
        if let selectedMode {
            Section {
                LabeledContent("Mode", value: selectedMode.title)
                LabeledContent("Discovery", value: self.gatewayController.discoveryStatusText)
                LabeledContent("Status", value: self.appModel.gatewayDisplayStatusText)
                LabeledContent("Progress", value: self.statusLine)
            } header: {
                Text("Status")
            } footer: {
                if let connectMessage {
                    Text(connectMessage)
                }
            }

            switch selectedMode {
            case .homeNetwork:
                self.homeNetworkConnectSection
            case .remoteDomain:
                self.remoteDomainConnectSection
            case .developerLocal:
                self.developerConnectSection
            }
        } else {
            Section {
                Text("Choose a mode first.")
                Button("Back to Mode Selection") {
                    self.stepStore.send(.stepChanged(.init(step: .mode)))
                }
            }
        }
    }

    private var homeNetworkConnectSection: some View {
        Group {
            Section("Discovered Gateways") {
                if self.gatewayController.gateways.isEmpty {
                    Text("No gateways found yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(self.gatewayController.gateways) { gateway in
                        let presentation = self.discoveredGatewayRowPresentation(gateway)

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(gateway.name)
                                if let host = presentation.displayHost.value {
                                    Text(host)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                Task { await self.connectDiscoveredGateway(gateway) }
                            } label: {
                                if self.connectingGatewayID == gateway.id {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                } else if !presentation.canConnect {
                                    Text("Resolving…")
                                } else {
                                    Text("Connect")
                                }
                            }
                            .disabled(self.connectingGatewayID != nil || !presentation.canConnect)
                        }
                    }
                }

                Button("Restart Discovery") {
                    self.gatewayController.restartDiscovery()
                }
                .disabled(self.connectingGatewayID != nil)
            }

            self.manualConnectionFieldsSection(title: "Manual Fallback")
        }
    }

    private var remoteDomainConnectSection: some View {
        self.manualConnectionFieldsSection(title: "Domain Settings")
    }

    private var developerConnectSection: some View {
        Section {
            TextField("Host", text: self.manualHostBinding)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Port", text: self.manualPortTextBinding)
                .keyboardType(.numberPad)
            self.onboardingButtonToggle("Use TLS", isOn: self.manualTLSBinding)
            self.manualConnectButton
        } header: {
            Text("Developer Local")
        } footer: {
            Text("Default host is localhost. Use your Mac LAN IP if simulator networking requires it.")
        }
    }

    private var authStep: some View {
        Group {
            Section("Authentication") {
                SecureField("Gateway Auth Token", text: self.gatewayTokenBinding)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Gateway Password", text: self.gatewayPasswordBinding)

                if let problem = self.currentProblem {
                    GatewayProblemBanner(
                        problem: problem,
                        primaryActionTitle: self.gatewayProblemPrimaryActionTitle(problem),
                        onPrimaryAction: {
                            Task { await self.handleGatewayProblemPrimaryAction(problem) }
                        },
                        onShowDetails: {
                            self.presentationStore.send(.gatewayProblemDetailsButtonTapped)
                        })
                } else if self.issue.needsAuthToken {
                    Text("Gateway rejected credentials. Scan a fresh QR code or update token/password.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Auth token looks valid.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if self.issue.needsPairing {
                Section {
                    Button {
                        Task { @MainActor in await self.resumeAfterPairingApproval() }
                    } label: {
                        Label("Resume After Approval", systemImage: "arrow.clockwise")
                    }
                    .disabled(self.connectingGatewayID != nil)
                } header: {
                    Text("Pairing Approval")
                } footer: {
                    let requestLine: String = {
                        if let id = self.currentProblem?.requestId ?? self.issue.requestId, !id.isEmpty {
                            return "Request ID: \(id)"
                        }
                        return "Request ID: check `openclaw devices list`."
                    }()
                    let commandLine = self.currentProblem?.actionCommand ?? "openclaw devices approve <requestId>"
                    Text(
                        "Approve this device on the gateway.\n"
                            + "1) `\(commandLine)`\n"
                            + "2) `/pair approve` in your OpenClaw chat\n"
                            + "\(requestLine)\n"
                            + "OpenClaw will also retry automatically when you return to this app.")
                }
            }

            Section {
                Button {
                    Task { @MainActor in await self.openQRScannerFromOnboarding() }
                } label: {
                    Label("Scan QR Code Again", systemImage: "qrcode.viewfinder")
                }
                .disabled(self.connectingGatewayID != nil)

                Button {
                    Task { await self.retryLastAttempt() }
                } label: {
                    if self.connectingGatewayID == "retry" {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("Retry Connection")
                    }
                }
                .disabled(self.connectingGatewayID != nil)
            }
        }
    }

    private var successStep: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(OpenClawBrand.ok)
                .padding(.bottom, 20)

            Text("Connected")
                .font(.largeTitle.weight(.bold))
                .padding(.bottom, 8)

            let server = self.appModel.gatewayServerName ?? "gateway"
            Text(server)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            if let addr = self.appModel.gatewayRemoteAddress {
                Text(addr)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                self.onClose()
            } label: {
                Text("Open OpenClaw")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
}

extension OnboardingWizardView {
    private var setupCodeSection: some View {
        Section {
            TextField("Paste setup code", text: self.setupCodeBinding)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit {
                    Task { await self.applySetupCodeAndConnect() }
                }

            Button {
                Task { await self.applySetupCodeAndConnect() }
            } label: {
                if self.connectingGatewayID == "setup-code" {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(.circular)
                        Text("Applying...")
                    }
                } else {
                    Text("Apply Setup Code")
                }
            }
            .disabled(
                !self.setupCodeStore.canApply
                    || self.connectingGatewayID != nil)

            if let setupCodeStatus = self.setupCodeStore.status, !setupCodeStatus.isEmpty {
                Text(setupCodeStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Setup Code")
        } footer: {
            Text("Use this if you received a setup code instead of a QR code.")
        }
    }

    private func manualConnectionFieldsSection(title: String) -> some View {
        Section(title) {
            TextField("Host", text: self.manualHostBinding)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Port", text: self.manualPortTextBinding)
                .keyboardType(.numberPad)
            self.onboardingButtonToggle("Use TLS", isOn: self.manualTLSBinding)
            TextField("Discovery Domain (optional)", text: self.$discoveryDomain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if self.selectedMode == .remoteDomain {
                SecureField("Gateway Auth Token", text: self.gatewayTokenBinding)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Gateway Password", text: self.gatewayPasswordBinding)
            }
            self.manualConnectButton
        }
    }

    private var manualConnectButton: some View {
        Button {
            Task { await self.connectManual() }
        } label: {
            if self.connectingGatewayID == "manual" {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("Connecting…")
                }
            } else {
                Text("Connect")
            }
        }
        .disabled(!self.connectionFormStore.canConnectManual || self.connectingGatewayID != nil)
    }

    private func applySetupCodeAndConnect() async {
        self.setupCodeStore.send(.applyRequested)
        guard let result = self.setupCodeStore.applyResult else { return }
        let gatewayLinkTransitionRequest = self.setupCodeStore.gatewayLinkTransitionRequest
        self.setupCodeStore.send(.applyResultHandled)

        switch result {
        case let .appleReviewDemoSetupCode(setupCode):
            await self.applyAppleReviewDemoActivation(setupCode.activation)

        case let .gatewayLink(link):
            guard let transitionRequest = gatewayLinkTransitionRequest else { return }
            self.statusStore.send(transitionRequest.statusAction)
            await self.applyGatewayLink(link)
            self.stepStore.send(transitionRequest.stepAction)
            await self.connectManual()
        }
    }

    private func handleScannedLink(_ link: GatewayConnectDeepLink) async {
        self.setupCodeStore.send(.scannedGatewayLinkReceived(.init(link: link)))
        guard case let .gatewayLink(scannedLink)? = self.setupCodeStore.applyResult else { return }
        guard let transitionRequest = self.setupCodeStore.scannedGatewayLinkTransitionRequest else { return }
        self.setupCodeStore.send(.applyResultHandled)
        await self.applyGatewayLink(scannedLink)
        self.presentationStore.send(transitionRequest.presentationAction)
        self.statusStore.send(transitionRequest.statusAction)
        self.stepStore.send(transitionRequest.stepAction)
        Task { await self.connectManual() }
    }

    private func applyGatewayLink(_ link: GatewayConnectDeepLink) async {
        self.connectionFormStore.send(.gatewayLinkApplied(.init(
            host: .init(value: link.host),
            port: .init(value: link.port),
            tls: .init(value: link.tls))))
        await self.credentialsStore.send(.setupLinkApplied(.init(link: link))).finish()
    }

    private func handleScannedSetupCode(_ code: String) async {
        self.setupCodeStore.send(.scannedSetupCodeReceived(.init(code: .init(value: code))))
        guard let result = self.setupCodeStore.applyResult else { return }
        self.setupCodeStore.send(.applyResultHandled)

        guard case let .appleReviewDemoSetupCode(setupCode) = result else { return }
        await self.applyAppleReviewDemoActivation(setupCode.activation)
    }

    private func applyAppleReviewDemoActivation(
        _ activation: OnboardingSetupCodeFeature.AppleReviewDemoActivation) async
    {
        await self.appleReviewDemoStore.send(activation.appleReviewDemoAction).finish()
        self.presentationStore.send(activation.presentationAction)
        self.statusStore.send(activation.statusAction)
        self.connectionFormStore.send(activation.connectionFormAction)
    }

    private func handleSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        self.selectedPhoto = nil
        self.photoImportStore.send(.importStarted)
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                self.photoImportStore.send(.imageLoadFailed)
                await self.handlePhotoImportResult()
                return
            }
            self.photoImportStore.send(.qrMessageDetected(.init(message: .init(value: self.detectQRCode(from: data)))))
            await self.handlePhotoImportResult()
        }
    }

    private func handlePhotoImportResult() async {
        guard let result = self.photoImportStore.result else { return }
        self.photoImportStore.send(.resultHandled)

        switch result {
        case let .gatewayLink(link):
            await self.handleScannedLink(link)
        case let .appleReviewSetupCode(setupCode):
            await self.handleScannedSetupCode(setupCode.code.value)
        case let .failure(failure):
            self.presentationStore.send(.qrScannerErrorReceived(failure.presentationError))
        }
    }

    private func openQRScannerFromOnboarding() async {
        // Stop active reconnect loops before scanning new credentials.
        await self.gatewayConnectionStore.send(.disconnectRequested).finish()
        self.openQRScanner(OnboardingStatusFeature.freshQRScannerOpeningRequest)
    }

    private func openQRScanner(_ request: OnboardingStatusFeature.QRScannerOpeningRequest) {
        self.statusStore.send(request.statusAction)
        self.presentationStore.send(request.presentationAction)
    }

    private func resumeAfterPairingApproval() async {
        // We intentionally stop reconnect churn while unpaired to avoid generating multiple pending requests.
        await self.pairingResumeStore.send(.resumeRequested).finish()
        // Pairing state is sticky to prevent UI flip-flop during reconnect churn.
        // Once the user explicitly resumes after approving, clear the sticky issue
        // so new status/auth errors can surface instead of being masked as pairing.
        self.statusStore.send(.pairingResumeStarted)
        await self.retryLastAttempt()
    }

    private func resumeAfterPairingApprovalInBackground() async {
        // Keep the pairing issue sticky to avoid visual flicker while we probe for approval.
        await self.pairingResumeStore.send(.resumeRequested).finish()
        await self.retryLastAttempt(silent: true)
    }

    private func attemptAutomaticPairingResumeIfNeeded() {
        guard self.scenePhase == .active else { return }
        guard self.step == .auth else { return }
        self.statusStore.send(.automaticPairingResumeRequested)
        guard self.statusStore.shouldResumePairingAutomatically else { return }
        Task { @MainActor in await self.resumeAfterPairingApprovalInBackground() }
    }

    private func updateConnectionIssue(problem: GatewayConnectionProblem?, statusText: String) {
        self.statusStore.send(.connectionProblemUpdated(.init(
            problem: problem,
            statusText: .init(value: statusText))))

        if let request = self.statusStore.authStepNavigationRequest {
            self.stepStore.send(request.stepAction)
            self.statusStore.send(.authStepNavigationHandled)
        }
    }

    private func detectQRCode(from data: Data) -> String? {
        guard let ciImage = CIImage(data: data) else { return nil }
        let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let features = detector?.features(in: ciImage) ?? []
        for feature in features {
            if let qr = feature as? CIQRCodeFeature, let message = qr.messageString {
                return message
            }
        }
        return nil
    }

    private func advanceFromIntro() {
        self.applyIntroAdvanceRequest(OnboardingStatusFeature.introAdvanceRequest)
    }

    private func applyIntroAdvanceRequest(_ request: OnboardingStatusFeature.IntroAdvanceRequest) {
        self.onboardingStateStore.send(request.stateAction)
        self.requestLocalNetworkAccess(reason: request.localNetworkReason.value)
        self.statusStore.send(request.statusAction)
        self.stepStore.send(request.stepAction)
    }

    private func requestLocalNetworkAccessIfPastIntro(reason: String) {
        guard self.step != .intro else { return }
        self.requestLocalNetworkAccess(reason: reason)
    }

    private func requestLocalNetworkAccess(reason: String) {
        self.onRequestLocalNetworkAccess(reason)
    }

    private func navigateBack() {
        guard self.step.canGoBack else { return }
        self.applyNavigationBackRequest(OnboardingStatusFeature.navigationBackRequest)
    }

    private func applyNavigationBackRequest(_ request: OnboardingStatusFeature.NavigationBackRequest) {
        self.statusStore.send(request.statusAction)
        self.stepStore.send(request.stepAction)
    }

    private func initializeState() {
        self.connectionFormStore.send(.initialConnectionLoadRequested)
        self.credentialsStore.send(.credentialsLoadRequested(.init(
            instanceId: .init(value: self.instanceId))))

        self.statusStore.send(.initializationStatusEvaluated(.init(
            hasSavedGatewayConnection: .init(value: self.connectionFormStore.hasSavedGatewayConnection),
            hasGatewayToken: .init(value: self.credentialsStore.hasGatewayToken),
            hasGatewayPassword: .init(value: self.credentialsStore.hasGatewayPassword))))
    }

    private func scheduleDiscoveryRestart() {
        self.discoveryRestartStore.send(.discoveryDomainChanged)
    }

    private func updateGatewayToken(_ value: String) {
        self.credentialsStore.send(.gatewayTokenInputChanged(.init(
            value: .init(value: value),
            instanceId: .init(value: self.instanceId))))
    }

    private func updateGatewayPassword(_ value: String) {
        self.credentialsStore.send(.gatewayPasswordInputChanged(.init(
            value: .init(value: value),
            instanceId: .init(value: self.instanceId))))
    }

    private func connectDiscoveredGateway(_ gateway: GatewayDiscoveryModel.DiscoveredGateway) async {
        self.gatewayConnectionStore.send(.discoveredGatewayConnectionRequested(.init(
            id: .init(value: gateway.id),
            name: .init(value: gateway.name))))
        guard let statusAction = self.gatewayConnectionStore.discoveredGatewayConnectionStatusAction else { return }
        self.gatewayConnectionStore.send(.discoveredGatewayConnectionStatusHandled)
        self.statusStore.send(statusAction)
        defer { self.statusStore.send(.connectionFinished) }
        await self.gatewayController.connect(gateway)
    }

    private func selectMode(_ mode: OnboardingConnectionMode) {
        self.connectionFormStore.send(.modeSelected(.init(mode: mode)))
    }

    private func discoveredGatewayRowPresentation(
        _ gateway: GatewayDiscoveryModel.DiscoveredGateway)
        -> OnboardingGatewayConnectionFeature.State.DiscoveredGatewayRowPresentation
    {
        OnboardingGatewayConnectionFeature.State.discoveredGatewayRowPresentation(
            lanHost: .init(value: gateway.lanHost),
            tailnetDNS: .init(value: gateway.tailnetDns))
    }

    private func connectManual() async {
        self.connectionFormStore.send(.manualConnectionRequested)
        guard let request = self.connectionFormStore.manualConnectionRequest else { return }
        self.connectionFormStore.send(.manualConnectionRequestHandled)

        self.statusStore.send(request.statusAction)
        defer { self.statusStore.send(.connectionFinished) }
        let authOverride = GatewayConnectionController.ManualAuthOverride.currentManualInput(
            token: self.gatewayToken,
            pendingOverride: self.credentialsStore.pendingManualAuthOverride,
            password: self.gatewayPassword)
        self.credentialsStore.send(.pendingManualAuthOverrideConsumed)
        await self.gatewayController.connectManual(
            host: request.host.value,
            port: request.port.value,
            useTLS: request.useTLS.value,
            authOverride: authOverride)
    }

    private func retryLastAttempt(silent: Bool = false) async {
        // Keep current auth/pairing issue sticky while retrying to avoid Step 3 UI flip-flop.
        self.statusStore.send(.retryConnectionStarted(.init(silent: .init(value: silent))))
        defer { self.statusStore.send(.connectionFinished) }
        await self.gatewayController.connectLastKnown()
    }

    private func gatewayProblemPrimaryActionTitle(_ problem: GatewayConnectionProblem) -> String? {
        OnboardingGatewayProblemPrimaryActionFeature.title(for: problem)
    }

    private func handleGatewayProblemPrimaryAction(_ problem: GatewayConnectionProblem) async {
        self.gatewayProblemPrimaryActionStore.send(.primaryActionTapped(.init(problem: problem)))
        guard let decision = self.gatewayProblemPrimaryActionStore.primaryActionDecision else { return }
        self.gatewayProblemPrimaryActionStore.send(.primaryActionDecisionHandled)

        switch decision {
        case let .resetAndScan(request):
            await self.onboardingStateStore
                .send(.onboardingResetRequested(.init(
                    instanceId: .init(value: self.instanceId))))
                .finish()
            self.credentialsStore.send(request.credentialsAction)
            self.statusStore.send(request.statusAction)
            self.stepStore.send(request.stepAction)
            self.presentationStore.send(request.presentationAction)
            return

        case let .trustRotatedCertificate(request):
            self.statusStore.send(.connectionStarted(request.connectionStart))
            defer { self.statusStore.send(.connectionFinished) }
            _ = await self.gatewayController.trustRotatedGatewayCertificate(from: request.problem)
            return

        case let .openProtocolMismatchHelp(problem):
            _ = GatewayProblemPrimaryAction.openProtocolMismatchHelpIfNeeded(problem)
            return

        case .retryConnection:
            await self.retryLastAttempt()
        }
    }
}
