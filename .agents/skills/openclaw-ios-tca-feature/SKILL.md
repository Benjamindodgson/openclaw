---
name: openclaw-ios-tca-feature
description: Use when implementing or reviewing one OpenClaw iOS feature migration into TCA.
---

# OpenClaw iOS TCA Feature

Use this skill for one feature-sized migration from SwiftUI-owned state,
controllers, services, or observable objects into a TCA reducer.

## Slice Definition

Before editing, identify:

- User workflow or screen being migrated.
- Current state owner and entry view.
- Side effects, live services, timers, notifications, or streams.
- Existing tests and sibling behavior that share the same invariant.
- New target files under `apps/ios/Sources/Features/`,
  `apps/ios/Sources/Dependencies/`, `apps/ios/Sources/Domain/`, or
  `apps/ios/Sources/Support/TCA/`.

## Reducer Rules

- Use `@Reducer`.
- Use `@ObservableState`.
- `State` conforms to `Equatable` and `Sendable`.
- Actions are a closed enum and separate user actions, internal responses, and
  delegate outputs when that makes ownership clearer.
- Reducers mutate state synchronously and return effects for work.
- Long-lived effects have explicit cancellation IDs and owner-scoped teardown.
- Once available, apply `.autoLogActions()` to non-root reducers. Logs must name
  `Feature.action` and must not include payload values.

## Dependency Rules

- Use small `@Dependency` clients instead of direct service construction inside
  reducers.
- Put live clients in `apps/ios/Sources/Dependencies/` unless an existing owner
  boundary is narrower.
- Override every live dependency in reducer tests.
- Do not let tests hit the gateway, network, keychain, notification center,
  clocks, camera, microphone, location, contacts, reminders, calendars, or file
  system unless the test is explicitly an integration test.

## SwiftUI Rules

- Views hold `StoreOf<Feature>` directly.
- Do not add `WithViewStore` or `ViewStore`.
- Views render state and send actions; reducers own decisions and mutations.
- Use `@Bindable` only for binding state that is owned by the reducer.
- Keep previews colocated with the production view when preview changes are in
  scope.

## Testing Rules

- New reducer tests use Swift Testing and `TestStore`.
- Name tests after the feature, for example `GatewayFeatureTests`.
- Cover key user actions, effect responses, dependency failures, and
  cancellation when applicable.
- Prefer exhaustive assertions. If exhaustivity is reduced, state why the
  skipped state is outside the test's purpose.
- Existing XCTest files may remain, but do not add new XCTest-only reducer proof.

## Project Rules

- Source membership is owned by `apps/ios/project.yml`.
- Regenerate the Xcode project after adding source files to new folders.
- Do not hand-edit generated project membership.

## Review Checklist

- The reducer owns the migrated logic and the view no longer duplicates it.
- Dependency clients are small, value-typed, and test-overridable.
- Navigation and presentation state are modeled in reducer state.
- The old code path is deleted or explicitly justified as a shipped contract.
- Validation matches the touched surface.
