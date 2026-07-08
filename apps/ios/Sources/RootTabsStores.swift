import ComposableArchitecture

extension RootTabs {
    @MainActor
    func makeGatewayQuickSetupStore() -> StoreOf<GatewayQuickSetupFeature> {
        Store(initialState: GatewayQuickSetupFeature.State()) {
            GatewayQuickSetupFeature()
        } withDependencies: {
            $0.gatewayQuickSetup = .live(gatewayController: self.gatewayController)
        }
    }

    @MainActor
    func makeCanvasPresentationStore() -> StoreOf<RootCanvasPresentationFeature> {
        Store(initialState: RootCanvasPresentationFeature.State()) {
            RootCanvasPresentationFeature(client: .live(appModel: self.appModel))
        }
    }

    @MainActor
    func makeCanvasDebugStatusStore() -> StoreOf<RootCanvasDebugStatusFeature> {
        Store(initialState: RootCanvasDebugStatusFeature.State()) {
            RootCanvasDebugStatusFeature(client: .live(appModel: self.appModel))
        }
    }

    @MainActor
    func makeGatewayProblemPrimaryActionStore() -> StoreOf<RootGatewayProblemPrimaryActionFeature> {
        Store(initialState: RootGatewayProblemPrimaryActionFeature.State()) {
            RootGatewayProblemPrimaryActionFeature(
                client: .live(
                    gatewayController: self.gatewayController,
                    openGatewaySettings: { self.selectSidebarDestination(.gateway) }))
        }
    }

    @MainActor
    func makeGatewayOverviewRefreshStore() -> StoreOf<RootGatewayOverviewRefreshFeature> {
        Store(initialState: RootGatewayOverviewRefreshFeature.State()) {
            RootGatewayOverviewRefreshFeature(client: .live(appModel: self.appModel))
        }
    }

    @MainActor
    func makeGatewayTrustPromptStore() -> StoreOf<GatewayTrustPromptFeature> {
        Store(initialState: GatewayTrustPromptFeature.State()) {
            GatewayTrustPromptFeature(client: .live(gatewayController: self.gatewayController))
        }
    }

    @MainActor
    func makePushEnrollmentConsentStore() -> StoreOf<PushEnrollmentConsentFeature> {
        Store(initialState: PushEnrollmentConsentFeature.State()) {
            PushEnrollmentConsentFeature()
        }
    }

    @MainActor
    func makeSettingsApprovalsStore() -> StoreOf<SettingsApprovalsFeature> {
        Store(initialState: SettingsApprovalsFeature.State()) {
            SettingsApprovalsFeature()
        }
    }

    @MainActor
    func makeSettingsAppearanceStore() -> StoreOf<SettingsAppearanceFeature> {
        Store(initialState: SettingsAppearanceFeature.State()) {
            SettingsAppearanceFeature()
        }
    }

    @MainActor
    func makeSettingsDeviceCapabilityStore() -> StoreOf<SettingsDeviceCapabilityFeature> {
        Store(initialState: SettingsDeviceCapabilityFeature.State()) {
            SettingsDeviceCapabilityFeature()
        }
    }

    @MainActor
    func makeSettingsDeviceIdentityStore() -> StoreOf<SettingsDeviceIdentityFeature> {
        Store(initialState: SettingsDeviceIdentityFeature.State()) {
            SettingsDeviceIdentityFeature()
        }
    }

    @MainActor
    func makeSettingsShareInstructionStore() -> StoreOf<SettingsShareInstructionFeature> {
        Store(initialState: SettingsShareInstructionFeature.State()) {
            SettingsShareInstructionFeature()
        }
    }

    @MainActor
    func makeSettingsManualGatewayPortStore() -> StoreOf<SettingsManualGatewayPortFeature> {
        Store(initialState: SettingsManualGatewayPortFeature.State()) {
            SettingsManualGatewayPortFeature()
        }
    }

    @MainActor
    func makeSettingsManualGatewayEndpointStore() -> StoreOf<SettingsManualGatewayEndpointFeature> {
        Store(initialState: SettingsManualGatewayEndpointFeature.State()) {
            SettingsManualGatewayEndpointFeature(
                localNetworkAccessClient: .live(gatewayController: self.gatewayController))
        }
    }

    @MainActor
    func makeSettingsDiagnosticsStore() -> StoreOf<SettingsDiagnosticsFeature> {
        Store(initialState: SettingsDiagnosticsFeature.State()) {
            SettingsDiagnosticsFeature()
        }
    }

    @MainActor
    func makeSettingsDebugOptionsStore() -> StoreOf<SettingsDebugOptionsFeature> {
        Store(initialState: SettingsDebugOptionsFeature.State()) {
            SettingsDebugOptionsFeature(
                discoveryDebugLoggingClient: .live(gatewayController: self.gatewayController))
        }
    }

    @MainActor
    func makeSettingsVoiceControlStore() -> StoreOf<SettingsVoiceControlFeature> {
        Store(initialState: SettingsVoiceControlFeature.State()) {
            SettingsVoiceControlFeature(
                voiceControlClient: .live(appModel: self.appModel))
        }
    }

    @MainActor
    func makeSettingsTalkPreferencesStore() -> StoreOf<SettingsTalkPreferencesFeature> {
        Store(initialState: SettingsTalkPreferencesFeature.State()) {
            SettingsTalkPreferencesFeature(
                preferencesClient: .live(appModel: self.appModel))
        }
    }

    @MainActor
    func makeSettingsAgentSelectionStore() -> StoreOf<SettingsAgentSelectionFeature> {
        Store(initialState: SettingsAgentSelectionFeature.State()) {
            SettingsAgentSelectionFeature(
                selectedAgentClient: .live(appModel: self.appModel))
        }
    }

    @MainActor
    func makeSettingsLocationStore() -> StoreOf<SettingsLocationFeature> {
        Store(initialState: SettingsLocationFeature.State()) {
            SettingsLocationFeature(
                gatewayRefreshClient: .live(gatewayController: self.gatewayController))
        }
    }

    @MainActor
    func makeSettingsNotificationStore() -> StoreOf<SettingsNotificationFeature> {
        Store(initialState: SettingsNotificationFeature.State()) {
            SettingsNotificationFeature()
        }
    }

    @MainActor
    func makeSettingsPresentationStore() -> StoreOf<SettingsPresentationFeature> {
        Store(initialState: SettingsPresentationFeature.State()) {
            SettingsPresentationFeature()
        }
    }

    @MainActor
    func makeSettingsGatewayActivityStore() -> StoreOf<SettingsGatewayActivityFeature> {
        Store(initialState: SettingsGatewayActivityFeature.State()) {
            SettingsGatewayActivityFeature(
                diagnosticsRefreshClient: .live(
                    appModel: self.appModel,
                    gatewayController: self.gatewayController),
                problemTrustClient: .live(gatewayController: self.gatewayController),
                reconnectClient: .live(gatewayController: self.gatewayController))
        }
    }

    @MainActor
    func makeSettingsGatewayAutoConnectStore() -> StoreOf<SettingsGatewayAutoConnectFeature> {
        Store(initialState: SettingsGatewayAutoConnectFeature.State()) {
            SettingsGatewayAutoConnectFeature()
        }
    }

    @MainActor
    func makeSettingsGatewayConnectionStore() -> StoreOf<SettingsGatewayConnectionFeature> {
        Store(initialState: SettingsGatewayConnectionFeature.State()) {
            SettingsGatewayConnectionFeature(disconnectClient: .live(appModel: self.appModel))
        }
    }

    @MainActor
    func makeOnboardingStateStore() -> StoreOf<OnboardingStateFeature> {
        Store(initialState: OnboardingStateFeature.State()) {
            OnboardingStateFeature(resetClient: .live(appModel: self.appModel))
        }
    }

    @MainActor
    func makeOnboardingCredentialsStore() -> StoreOf<OnboardingCredentialsFeature> {
        Store(initialState: OnboardingCredentialsFeature.State()) {
            OnboardingCredentialsFeature(setupAuthPersistenceClient: .live(appModel: self.appModel))
        }
    }

    @MainActor
    func makeOnboardingGatewayConnectionStore() -> StoreOf<OnboardingGatewayConnectionFeature> {
        Store(initialState: OnboardingGatewayConnectionFeature.State()) {
            OnboardingGatewayConnectionFeature(disconnectClient: .live(appModel: self.appModel))
        }
    }

    @MainActor
    func makeOnboardingAppleReviewDemoStore() -> StoreOf<OnboardingAppleReviewDemoFeature> {
        Store(initialState: OnboardingAppleReviewDemoFeature.State()) {
            OnboardingAppleReviewDemoFeature(appleReviewDemoClient: .live(appModel: self.appModel))
        }
    }

    @MainActor
    func makeOnboardingPairingResumeStore() -> StoreOf<OnboardingPairingResumeFeature> {
        Store(initialState: OnboardingPairingResumeFeature.State()) {
            OnboardingPairingResumeFeature(resumeClient: .live(appModel: self.appModel))
        }
    }

    @MainActor
    func makeSettingsGatewaySetupStatusStore() -> StoreOf<SettingsGatewaySetupStatusFeature> {
        Store(initialState: SettingsGatewaySetupStatusFeature.State()) {
            SettingsGatewaySetupStatusFeature()
        }
    }

    @MainActor
    func makeSettingsGatewayCredentialsStore() -> StoreOf<SettingsGatewayCredentialsFeature> {
        Store(initialState: SettingsGatewayCredentialsFeature.State()) {
            SettingsGatewayCredentialsFeature(
                setupAuthPersistenceClient: .live(appModel: self.appModel))
        }
    }

    @MainActor
    func makeSettingsOnboardingStateStore() -> StoreOf<SettingsOnboardingStateFeature> {
        Store(initialState: SettingsOnboardingStateFeature.State()) {
            SettingsOnboardingStateFeature(resetClient: .live(appModel: self.appModel))
        }
    }

    @MainActor
    func makeSettingsGatewaySetupLinkStore() -> StoreOf<SettingsGatewaySetupLinkFeature> {
        Store(initialState: SettingsGatewaySetupLinkFeature.State()) {
            SettingsGatewaySetupLinkFeature(appleReviewDemoClient: .live(appModel: self.appModel))
        }
    }

    @MainActor
    func makeDeepLinkAgentPromptStore() -> StoreOf<DeepLinkAgentPromptFeature> {
        Store(initialState: DeepLinkAgentPromptFeature.State()) {
            DeepLinkAgentPromptFeature(client: .live(appModel: self.appModel))
        }
    }

    @MainActor
    func makeTalkProTabStore() -> StoreOf<TalkProTabFeature> {
        Store(initialState: TalkProTabFeature.State()) {
            TalkProTabFeature(client: .live(appModel: self.appModel))
        }
    }

    @MainActor
    func makeChatTalkControlStore() -> StoreOf<ChatTalkControlFeature> {
        Store(initialState: ChatTalkControlFeature.State()) {
            ChatTalkControlFeature(client: .live(appModel: self.appModel))
        }
    }

    @MainActor
    func makeAgentSelectionStore() -> StoreOf<AgentSelectionFeature> {
        Store(initialState: AgentSelectionFeature.State()) {
            AgentSelectionFeature(selectionClient: .live(appModel: self.appModel))
        }
    }

    @MainActor
    func makeExecApprovalPromptStore() -> StoreOf<ExecApprovalPromptFeature> {
        Store(initialState: ExecApprovalPromptFeature.State()) {
            ExecApprovalPromptFeature(client: .live(appModel: self.appModel))
        }
    }

    @MainActor
    func makeNotificationPermissionGuidanceStore() -> StoreOf<NotificationPermissionGuidanceFeature> {
        Store(initialState: NotificationPermissionGuidanceFeature.State()) {
            NotificationPermissionGuidanceFeature(client: .live(
                appModel: self.appModel,
                openNotifications: { approvalId in
                    self.openNotificationSettings(suppressedApprovalID: approvalId)
                }))
        }
    }
}
