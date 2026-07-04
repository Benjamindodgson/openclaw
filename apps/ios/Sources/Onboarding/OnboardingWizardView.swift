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
    @State private var credentialsStore: StoreOf<OnboardingCredentialsFeature> = Store(
        initialState: OnboardingCredentialsFeature.State())
    {
        OnboardingCredentialsFeature()
    }

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var statusStore: StoreOf<OnboardingStatusFeature> = Store(
        initialState: OnboardingStatusFeature.State())
    {
        OnboardingStatusFeature()
    }

    @State private var presentationStore: StoreOf<OnboardingPresentationFeature> = Store(
        initialState: OnboardingPresentationFeature.State())
    {
        OnboardingPresentationFeature()
    }

    @State private var discoveryRestartStore: StoreOf<OnboardingDiscoveryRestartFeature> = Store(
        initialState: OnboardingDiscoveryRestartFeature.State())
    {
        OnboardingDiscoveryRestartFeature()
    }

    @State private var connectionFormStore: StoreOf<OnboardingConnectionFormFeature> = Store(
        initialState: OnboardingConnectionFormFeature.State())
    {
        OnboardingConnectionFormFeature()
    }

    @State private var setupCodeStore: StoreOf<OnboardingSetupCodeFeature> = Store(
        initialState: OnboardingSetupCodeFeature.State())
    {
        OnboardingSetupCodeFeature()
    }

    @State private var photoImportStore: StoreOf<OnboardingQRPhotoImportFeature> = Store(
        initialState: OnboardingQRPhotoImportFeature.State())
    {
        OnboardingQRPhotoImportFeature()
    }

    private static let pairingAutoResumeTicker = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    let allowSkip: Bool
    let onRequestLocalNetworkAccess: (String) -> Void
    let onClose: () -> Void

    init(
        allowSkip: Bool,
        onRequestLocalNetworkAccess: @escaping (String) -> Void,
        onClose: @escaping () -> Void)
    {
        self.allowSkip = allowSkip
        self.onRequestLocalNetworkAccess = onRequestLocalNetworkAccess
        self.onClose = onClose
        let initialStep: OnboardingStep =
            OnboardingStateStore.shouldPresentFirstRunIntro() ? .intro : .welcome
        self._stepStore = State(wrappedValue: Store(initialState: OnboardingStepFeature.State(step: initialStep)) {
            OnboardingStepFeature()
        })
    }

    @MainActor
    private func makeGatewayTrustPromptStore() -> StoreOf<GatewayTrustPromptFeature> {
        Store(initialState: GatewayTrustPromptFeature.State()) {
            GatewayTrustPromptFeature(client: .live(gatewayController: self.gatewayController))
        }
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
            set: { self.credentialsStore.send(.gatewayPasswordChanged(.init(value: $0))) })
    }

    private var gatewayTokenBinding: Binding<String> {
        Binding(
            get: { self.credentialsStore.gatewayToken },
            set: { self.credentialsStore.send(.gatewayTokenChanged(.init(value: $0))) })
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
            set: { self.setupCodeStore.send(.setupCodeChanged(.init(code: $0))) })
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
            set: { self.connectionFormStore.send(.manualHostChanged(.init(host: $0))) })
    }

    private var manualPortTextBinding: Binding<String> {
        Binding(
            get: { self.connectionFormStore.manualPortText },
            set: { self.connectionFormStore.send(.manualPortTextChanged(.init(text: $0))) })
    }

    private var manualTLSBinding: Binding<Bool> {
        Binding(
            get: { self.connectionFormStore.manualTLS },
            set: { self.connectionFormStore.send(.manualTLSChanged(.init(useTLS: $0))) })
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
                            self.handleScannedLink(link)
                        },
                        onSetupCode: { code in
                            self.handleScannedSetupCode(code)
                        },
                        onError: { error in
                            self.statusStore.send(.scannerErrorReceived(.init(message: error)))
                            self.presentationStore.send(.qrScannerErrorReceived(.init(message: error)))
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
                                .disabled(self.photoImportStore.isImporting)
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
            .onChange(of: self.gatewayToken) { _, newValue in
                self.saveGatewayCredentials(token: newValue, password: self.gatewayPassword)
            }
            .onChange(of: self.gatewayPassword) { _, newValue in
                self.saveGatewayCredentials(token: self.gatewayToken, password: newValue)
            }
            .onChange(of: self.appModel.lastGatewayProblem) { _, newValue in
                self.updateConnectionIssue(problem: newValue, statusText: self.appModel.gatewayStatusText)
            }
            .onChange(of: self.appModel.gatewayStatusText) { _, newValue in
                self.updateConnectionIssue(problem: self.appModel.lastGatewayProblem, statusText: newValue)
            }
            .onChange(of: self.appModel.gatewayServerName) { _, newValue in
                guard newValue != nil else { return }
                self.presentationStore.send(.qrScannerDismissed)
                let shouldMarkCompleted = !self.statusStore.didMarkCompleted
                if shouldMarkCompleted, let selectedMode {
                    OnboardingStateStore.markCompleted(mode: selectedMode)
                }
                self.statusStore.send(.gatewayConnected(markedCompleted: shouldMarkCompleted && selectedMode != nil))
                self.stepStore.send(.stepChanged(.success))
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
                self.statusStore.send(.qrScannerOpeningStarted)
                self.presentationStore.send(.qrScannerButtonTapped)
            },
            onManualSetup: {
                self.stepStore.send(.stepChanged(.mode))
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
                self.stepStore.send(.stepChanged(.connect))
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
                    self.stepStore.send(.stepChanged(.mode))
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
                        let hasHost = self.gatewayHasResolvableHost(gateway)

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(gateway.name)
                                if let host = gateway.lanHost ?? gateway.tailnetDns {
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
                                } else if !hasHost {
                                    Text("Resolving…")
                                } else {
                                    Text("Connect")
                                }
                            }
                            .disabled(self.connectingGatewayID != nil || !hasHost)
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
                        self.resumeAfterPairingApproval()
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
                    self.openQRScannerFromOnboarding()
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
        self.setupCodeStore.send(.applyResultHandled)

        switch result {
        case let .appleReviewDemoSetupCode(code):
            self.handleScannedSetupCode(code)

        case let .gatewayLink(link):
            self.statusStore.send(.connectionStarted(.init(
                id: "setup-code",
                message: "Connecting via setup code...",
                statusLine: "Setup code loaded. Connecting to \(link.host):\(link.port)...",
                clearsIssue: false)))
            self.applyGatewayLink(link)
            self.stepStore.send(.stepChanged(.connect))
            await self.connectManual()
        }
    }

    private func handleScannedLink(_ link: GatewayConnectDeepLink) {
        self.setupCodeStore.send(.scannedGatewayLinkReceived(link))
        guard case let .gatewayLink(scannedLink)? = self.setupCodeStore.applyResult else { return }
        self.setupCodeStore.send(.applyResultHandled)
        self.applyGatewayLink(scannedLink)
        self.presentationStore.send(.qrScannerDismissed)
        self.statusStore.send(.connectionStatusUpdated(.init(
            message: "Connecting via QR code...",
            statusLine: "QR loaded. Connecting to \(scannedLink.host):\(scannedLink.port)...")))
        self.stepStore.send(.stepChanged(.connect))
        Task { await self.connectManual() }
    }

    private func applyGatewayLink(_ link: GatewayConnectDeepLink) {
        self.connectionFormStore.send(.gatewayLinkApplied(
            host: link.host,
            port: link.port,
            tls: link.tls))
        let setupAuth = GatewayConnectionController.ManualAuthOverride.setupAuth(from: link)
        if setupAuth.hasBootstrapToken {
            GatewayOnboardingReset.prepareForBootstrapPairing(
                appModel: self.appModel,
                instanceId: GatewaySettingsStore.currentInstanceID())
        }
        self.saveGatewayBootstrapToken(setupAuth.bootstrapToken)
        self.credentialsStore.send(.setupAuthApplied(setupAuth))
        self.saveGatewayCredentials(token: self.gatewayToken, password: self.gatewayPassword)
    }

    private func handleScannedSetupCode(_ code: String) {
        self.setupCodeStore.send(.scannedSetupCodeReceived(code))
        guard let result = self.setupCodeStore.applyResult else { return }
        self.setupCodeStore.send(.applyResultHandled)

        guard case .appleReviewDemoSetupCode = result else { return }
        self.presentationStore.send(.qrScannerDismissed)
        self.statusStore.send(.appleReviewDemoModeEnabled)
        self.connectionFormStore.send(.selectedModeChanged(.homeNetwork))
        self.appModel.enterAppleReviewDemoMode()
    }

    private func handleSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        self.selectedPhoto = nil
        self.photoImportStore.send(.importStarted)
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                self.photoImportStore.send(.imageLoadFailed)
                self.handlePhotoImportResult()
                return
            }
            self.photoImportStore.send(.qrMessageDetected(self.detectQRCode(from: data)))
            self.handlePhotoImportResult()
        }
    }

    private func handlePhotoImportResult() {
        guard let result = self.photoImportStore.result else { return }
        self.photoImportStore.send(.resultHandled)

        switch result {
        case let .gatewayLink(link):
            self.handleScannedLink(link)
        case let .appleReviewSetupCode(code):
            self.handleScannedSetupCode(code)
        case let .failure(message):
            self.presentationStore.send(.qrScannerErrorReceived(.init(message: message)))
        }
    }

    private func openQRScannerFromOnboarding() {
        // Stop active reconnect loops before scanning new credentials.
        self.appModel.disconnectGateway()
        self.statusStore.send(.freshQRScanStarted)
        self.presentationStore.send(.qrScannerButtonTapped)
    }

    private func resumeAfterPairingApproval() {
        // We intentionally stop reconnect churn while unpaired to avoid generating multiple pending requests.
        self.appModel.gatewayAutoReconnectEnabled = true
        self.appModel.gatewayPairingPaused = false
        self.appModel.gatewayPairingRequestId = nil
        // Pairing state is sticky to prevent UI flip-flop during reconnect churn.
        // Once the user explicitly resumes after approving, clear the sticky issue
        // so new status/auth errors can surface instead of being masked as pairing.
        self.statusStore.send(.pairingResumeStarted)
        Task { await self.retryLastAttempt() }
    }

    private func resumeAfterPairingApprovalInBackground() {
        // Keep the pairing issue sticky to avoid visual flicker while we probe for approval.
        self.appModel.gatewayAutoReconnectEnabled = true
        self.appModel.gatewayPairingPaused = false
        self.appModel.gatewayPairingRequestId = nil
        Task { await self.retryLastAttempt(silent: true) }
    }

    private func attemptAutomaticPairingResumeIfNeeded() {
        guard self.scenePhase == .active else { return }
        guard self.step == .auth else { return }
        self.statusStore.send(.automaticPairingResumeRequested(now: Date()))
        guard self.statusStore.shouldResumePairingAutomatically else { return }
        self.resumeAfterPairingApprovalInBackground()
    }

    private func updateConnectionIssue(problem: GatewayConnectionProblem?, statusText: String) {
        let next = GatewayConnectionIssue.detect(problem: problem)
        let fallback = next == .none ? GatewayConnectionIssue.detect(from: statusText) : next

        self.statusStore.send(.connectionIssueDetected(.init(
            issue: fallback,
            requestId: problem?.requestId ?? fallback.requestId,
            pauseReconnect: problem?.pauseReconnect == true,
            message: problem?.message,
            statusText: statusText)))

        if self.statusStore.shouldShowAuthStep {
            self.stepStore.send(.stepChanged(.auth))
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
        OnboardingStateStore.markFirstRunIntroSeen()
        self.requestLocalNetworkAccess(reason: "onboarding_continue")
        self.statusStore.send(.introAdvanced)
        self.stepStore.send(.stepChanged(.welcome))
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
        self.statusStore.send(.navigationBackStarted)
        self.stepStore.send(.backButtonTapped)
    }

    private func initializeState() {
        let initialConnection: (host: String, port: Int, tls: Bool) = if let last = GatewaySettingsStore
            .loadLastGatewayConnection()
        {
            switch last {
            case let .manual(host, port, useTLS, _):
                (host, port, useTLS)
            case .discovered:
                ("openclaw.local", 18789, true)
            }
        } else {
            ("openclaw.local", 18789, true)
        }
        self.connectionFormStore.send(.initialized(
            host: initialConnection.host,
            port: initialConnection.port,
            tls: initialConnection.tls,
            lastMode: OnboardingStateStore.lastMode()))

        let trimmedInstanceId = self.instanceId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedInstanceId.isEmpty {
            self.credentialsStore.send(.credentialsLoaded(
                token: GatewaySettingsStore.loadGatewayToken(instanceId: trimmedInstanceId) ?? "",
                password: GatewaySettingsStore.loadGatewayPassword(instanceId: trimmedInstanceId) ?? ""))
        }

        let hasSavedGateway = GatewaySettingsStore.loadLastGatewayConnection() != nil
        if !hasSavedGateway, !self.credentialsStore.hasGatewayToken, !self.credentialsStore.hasGatewayPassword {
            self.statusStore.send(.noSavedPairingFound)
        }
    }

    private func scheduleDiscoveryRestart() {
        self.discoveryRestartStore.send(.discoveryDomainChanged)
    }

    private func saveGatewayCredentials(token: String, password: String) {
        let trimmedInstanceId = GatewaySettingsStore.currentInstanceID()
        guard !trimmedInstanceId.isEmpty else { return }
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        GatewaySettingsStore.saveGatewayToken(trimmedToken, instanceId: trimmedInstanceId)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        GatewaySettingsStore.saveGatewayPassword(trimmedPassword, instanceId: trimmedInstanceId)
    }

    private func saveGatewayBootstrapToken(_ token: String?) {
        let trimmedInstanceId = GatewaySettingsStore.currentInstanceID()
        guard !trimmedInstanceId.isEmpty else { return }
        let trimmedToken = token?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        GatewaySettingsStore.saveGatewayBootstrapToken(trimmedToken, instanceId: trimmedInstanceId)
    }

    private func connectDiscoveredGateway(_ gateway: GatewayDiscoveryModel.DiscoveredGateway) async {
        self.statusStore.send(.connectionStarted(.init(
            id: gateway.id,
            message: "Connecting to \(gateway.name)…",
            statusLine: "Connecting to \(gateway.name)…",
            clearsIssue: true)))
        defer { self.statusStore.send(.connectionFinished) }
        await self.gatewayController.connect(gateway)
    }

    private func selectMode(_ mode: OnboardingConnectionMode) {
        self.connectionFormStore.send(.modeSelected(mode))
    }

    private func gatewayHasResolvableHost(_ gateway: GatewayDiscoveryModel.DiscoveredGateway) -> Bool {
        let lanHost = gateway.lanHost?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !lanHost.isEmpty { return true }
        let tailnetDns = gateway.tailnetDns?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !tailnetDns.isEmpty
    }

    private func connectManual() async {
        self.connectionFormStore.send(.manualConnectionRequested)
        guard let request = self.connectionFormStore.manualConnectionRequest else { return }
        self.connectionFormStore.send(.manualConnectionRequestHandled)

        self.statusStore.send(.connectionStarted(.init(
            id: "manual",
            message: "Connecting to \(request.host)…",
            statusLine: "Connecting to \(request.host):\(request.port)…",
            clearsIssue: true)))
        defer { self.statusStore.send(.connectionFinished) }
        let authOverride = GatewayConnectionController.ManualAuthOverride.currentManualInput(
            token: self.gatewayToken,
            pendingOverride: self.credentialsStore.pendingManualAuthOverride,
            password: self.gatewayPassword)
        self.credentialsStore.send(.pendingManualAuthOverrideConsumed)
        await self.gatewayController.connectManual(
            host: request.host,
            port: request.port,
            useTLS: request.useTLS,
            authOverride: authOverride)
    }

    private func retryLastAttempt(silent: Bool = false) async {
        let connectionID = silent ? "retry-auto" : "retry"
        // Keep current auth/pairing issue sticky while retrying to avoid Step 3 UI flip-flop.
        if !silent {
            self.statusStore.send(.connectionStarted(.init(
                id: connectionID,
                message: "Retrying…",
                statusLine: "Retrying last connection…",
                clearsIssue: false)))
        } else {
            self.statusStore.send(.connectionActivityStarted(id: connectionID))
        }
        defer { self.statusStore.send(.connectionFinished) }
        await self.gatewayController.connectLastKnown()
    }

    private func gatewayProblemPrimaryActionTitle(_ problem: GatewayConnectionProblem) -> String? {
        GatewayProblemPrimaryAction.title(
            for: problem,
            retryTitle: "Retry connection",
            resetTitle: "Scan QR again")
    }

    private func handleGatewayProblemPrimaryAction(_ problem: GatewayConnectionProblem) async {
        if problem.suggestsOnboardingReset {
            GatewayOnboardingReset.reset(appModel: self.appModel, instanceId: self.instanceId)
            self.credentialsStore.send(.reset)
            self.statusStore.send(.gatewayProblemResetScanStarted)
            self.stepStore.send(.stepChanged(.connect))
            self.presentationStore.send(.qrScannerButtonTapped)
            return
        }
        if problem.canTrustRotatedCertificate {
            self.statusStore.send(.connectionStarted(.init(
                id: "trust-certificate",
                message: "Updating gateway certificate…",
                statusLine: "Updating gateway certificate…",
                clearsIssue: false)))
            defer { self.statusStore.send(.connectionFinished) }
            _ = await self.gatewayController.trustRotatedGatewayCertificate(from: problem)
            return
        }
        if GatewayProblemPrimaryAction.openProtocolMismatchHelpIfNeeded(problem) {
            return
        }
        guard problem.retryable else { return }
        await self.retryLastAttempt()
    }
}
