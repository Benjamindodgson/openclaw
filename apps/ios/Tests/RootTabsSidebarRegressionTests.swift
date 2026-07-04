import Foundation
import Testing

struct RootTabsSidebarRegressionTests {
    @Test func `i pad split hidden sidebar uses header reveal instead of reserved rail`() throws {
        let source = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let navigationSource = try String(contentsOf: Self.rootTabsNavigationSourceURL(), encoding: .utf8)
        let splitContent = try Self.extract(
            source,
            from: "private func sidebarNavigationSplitContent(sidebarWidth: CGFloat) -> some View",
            to: "private func sidebarDrawerContent(sidebarWidth: CGFloat) -> some View")

        #expect(splitContent.contains("HStack(spacing: 0)"))
        #expect(splitContent.contains("self.sidebarColumn"))
        #expect(splitContent.contains(".frame(width: sidebarWidth, alignment: .topLeading)"))
        #expect(splitContent.contains(".overlay(alignment: .trailing)"))
        #expect(!splitContent.contains("self.syncSidebarVisibility(from: visibility)"))
        #expect(!source.contains("NavigationSplitViewVisibility"))
        #expect(!source.contains("@State private var splitColumnVisibility: NavigationSplitViewVisibility"))
        #expect(!splitContent.contains("NavigationSplitView"))
        #expect(!splitContent.contains("self.collapsedSidebarRail"))
        #expect(!source.contains("private var collapsedSidebarRail: some View"))
        #expect(!source.contains("Self.sidebarCollapsedRailWidth"))
        #expect(source.contains("shouldShowSidebarRevealInDestinationHeader"))
        #expect(!navigationSource.contains("static let sidebarCollapsedRailWidth"))
        #expect(!navigationSource.contains("static func sidebarSplitColumnVisibility(isSidebarVisible: Bool)"))
        #expect(!navigationSource
            .contains("static func sidebarIsVisible(splitColumnVisibility: NavigationSplitViewVisibility)"))
    }

    @Test func `initial sidebar visibility survives first layout measurement`() throws {
        let source = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let navigationSource = try String(contentsOf: Self.rootTabsNavigationSourceURL(), encoding: .utf8)
        let reducer = try Self.extract(
            navigationSource,
            from: "struct RootSidebarFeature",
            to: "struct RootNavigationSelectionFeature")

        #expect(source.contains("RootSidebarFeature.State(initialVisibility: Self.initialSidebarVisibility)"))
        #expect(reducer.contains("var didResolveLayout: Bool"))
        #expect(reducer.contains("let didResolvePreviousLayout = state.didResolveLayout"))
        #expect(reducer.contains("state.didResolveLayout = true"))
        #expect(reducer.contains("if layoutModeDidChange && didResolvePreviousLayout"))
        #expect(reducer.contains("guard resolution.force || !state.userOverridden else { return .none }"))
    }

    @Test func `drawer dimming layer does not steal sidebar touches`() throws {
        let source = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let drawerContent = try Self.extract(
            source,
            from: "private func sidebarDrawerContent(sidebarWidth: CGFloat) -> some View",
            to: "private var sidebarDetailShell: some View")

        #expect(drawerContent.contains("HStack(spacing: 0)"))
        #expect(drawerContent.contains("Color.clear"))
        #expect(drawerContent.contains(".frame(width: sidebarWidth)"))
        #expect(drawerContent.contains(".allowsHitTesting(false)"))
        #expect(drawerContent.contains("Color.black.opacity(0.28)"))
        #expect(drawerContent.contains(".zIndex(0)"))
        #expect(drawerContent.contains(".zIndex(1)"))
    }

    @Test func `sidebar selection resets embedded settings navigation path`() throws {
        let source = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let navigationSource = try String(contentsOf: Self.rootTabsNavigationSourceURL(), encoding: .utf8)
        let sidebarDetail = try Self.extract(
            source,
            from: "private var sidebarDetail: some View",
            to: "private var sidebarDetailNavigationShell: some View")
        let navigationShell = try Self.extract(
            source,
            from: "private var sidebarDetailNavigationShell: some View",
            to: "private var usesSidebarTabs: Bool")
        let selection = try Self.extract(
            source,
            from: "func selectSidebarDestination(_ destination: SidebarDestination)",
            to: "private func showSidebar()")
        let reducer = try Self.extract(
            navigationSource,
            from: "struct RootNavigationSelectionFeature",
            to: "extension RootTabs")
        let resetRange = try #require(reducer.range(of: "state.sidebarNavigationPath.removeAll()"))
        let destinationRange = try #require(
            reducer.range(of: "state.selectedSidebarDestination = destination"))

        #expect(navigationSource.contains("var sidebarNavigationPath: [SettingsRoute]"))
        #expect(navigationShell.contains("NavigationStack(path: self.sidebarNavigationPathBinding)"))
        #expect(sidebarDetail.contains("case .settings:"))
        #expect(sidebarDetail.contains("ownsNavigationStack: false"))
        #expect(selection.contains("self.navigationStore.send(.sidebarDestinationSelected(destination))"))
        #expect(resetRange.lowerBound < destinationRange.lowerBound)
    }

    @Test func `embedded overview routes view more through owning navigation stack`() throws {
        let rootTabsSource = try String(contentsOf: Self.rootTabsSourceURL(), encoding: .utf8)
        let commandCenterSource = try String(contentsOf: Self.commandCenterSourceURL(), encoding: .utf8)
        let phoneHubSource = try String(contentsOf: Self.phoneHubSourceURL(), encoding: .utf8)
        let sidebarDetail = try Self.extract(
            rootTabsSource,
            from: "private var sidebarDetail: some View",
            to: "private var sidebarDetailNavigationShell: some View")
        let iPadOverview = try Self.extract(
            rootTabsSource,
            from: "private var sidebarOverview: some View",
            to: "func selectSidebarDestination")
        let recentSessions = try Self.extract(
            commandCenterSource,
            from: "private var recentSessions: some View",
            to: "private func cardHeader(")
        let phoneOverview = try Self.extract(phoneHubSource, from: "case .overview:", to: "case .activity:")

        #expect(commandCenterSource.contains("var openSessions: (() -> Void)?"))
        #expect(recentSessions.contains("if let openSessions"))
        #expect(recentSessions.contains("Button(action: openSessions)"))
        #expect(recentSessions.contains("NavigationLink"))
        #expect(sidebarDetail.contains("self.sidebarOverview"))
        #expect(iPadOverview.contains("openSessions: { self.selectSidebarDestination(.sessions) }"))
        #expect(phoneOverview.contains("openSessions: { self.openPhoneDetailDestination(.sessions) }"))
    }

    private static func rootTabsSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/RootTabs.swift")
    }

    private static func rootTabsNavigationSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/RootTabsNavigation.swift")
    }

    private static func commandCenterSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/CommandCenterTab.swift")
    }

    private static func phoneHubSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Design/RootTabsPhoneControlHub.swift")
    }

    private static func extract(_ source: String, from start: String, to end: String) throws -> String {
        let startRange = try #require(source.range(of: start))
        let tail = source[startRange.lowerBound...]
        let endRange = try #require(tail.range(of: end))
        return String(tail[..<endRange.lowerBound])
    }
}
