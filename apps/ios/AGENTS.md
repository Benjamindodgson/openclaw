# AGENTS.MD

Scope: `apps/ios/**`. Root `AGENTS.md` still applies.

## TCA Direction

- TCA is the app-logic migration target for the iOS app.
- New app logic belongs in `@Reducer` features. Keep SwiftUI views rendering state and sending actions.
- Feature state uses `@ObservableState` and conforms to `Equatable` and `Sendable`.
- SwiftUI views hold `StoreOf<Feature>` directly. Do not add `WithViewStore` or `ViewStore`.
- Async work goes through small `@Dependency` clients and returns `Effect.run`.
- Long-lived effects need explicit cancellation IDs and owner-scoped cancellation.
- After the helper exists under `apps/ios/Sources/Support/TCA/`, non-root reducers use `.autoLogActions()`.

## Incremental Layout

- Migrate incrementally. Do not reshuffle stable code only to match the target folders.
- Intended folders:
  - `apps/ios/Sources/App/` for app composition and root reducer wiring.
  - `apps/ios/Sources/Features/` for reducer-owned feature logic.
  - `apps/ios/Sources/Dependencies/` for dependency clients and live/test values.
  - `apps/ios/Sources/Domain/` for value models and domain types.
  - `apps/ios/Sources/Support/TCA/` for TCA support helpers.

## Tests

- New reducer tests use Swift Testing plus `TestStore`.
- Existing UI tests may remain XCTest in `apps/ios/UITests/`.
- Override dependencies in reducer tests; do not depend on live gateway, network, timers, or device services.

## Project

- iOS project membership and config are owned by `apps/ios/project.yml`.
- Regenerate with `cd apps/ios && xcodegen generate` after project membership or config changes.
- Do not hand-edit generated Xcode project membership.

## Validation

- Docs/governance-only changes: `git diff --check`.
- If touching reducer code, add or update scoped Swift Testing `TestStore` proof.
- If touching project membership/config, regenerate from `apps/ios/project.yml` and verify the generated project diff.
