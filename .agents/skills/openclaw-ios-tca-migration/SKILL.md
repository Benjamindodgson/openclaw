---
name: openclaw-ios-tca-migration
description: Use when planning, reviewing, or coordinating the OpenClaw iOS migration to The Composable Architecture.
---

# OpenClaw iOS TCA Migration

Use this skill for migration planning, issue/PR slicing, review gates, and
coordination of OpenClaw iOS work that moves logic into TCA reducers.

## Read First

- `AGENTS.md`
- `apps/ios/AGENTS.md`
- `apps/ios/project.yml`
- Existing source, tests, callers, and siblings for the touched feature.

## Related Skills

Open the specific global TCA skill that matches the work:

- `tca-reducer` for feature state, actions, reducer bodies, and composition.
- `tca-swiftui-integration` for `StoreOf<Feature>` views and bindings.
- `tca-dependencies` for client design and dependency overrides.
- `tca-effect` for async work, streams, cancellation, and response actions.
- `tca-testing`, `tca-teststore`, and `tca-teststoreof` for reducer proof.
- `tca-navigation` for destination, path, sheet, and alert state.
- `tca-performance` before adding broad observable state or high-frequency effects.
- `tca-swift-concurrency` when touching actors, `Sendable`, or main actor isolation.
- `openclaw-testing` for the cheapest safe OpenClaw validation path.

## Preflight

- Prefer Point-Free's maintained `ComposableArchitecture`, dependency clients,
  and test clocks over custom stores, hand-rolled effect systems, or global
  singletons.
- Confirm the migration slice is small enough to land independently.
- Keep current user-visible behavior unless the task explicitly asks for a
  behavior change.
- Do not reshape stable code only to satisfy the final folder layout.

## Target Layout

Introduce folders only when they carry real files:

- `apps/ios/Sources/App/` for root app composition and store construction.
- `apps/ios/Sources/Features/<Feature>/` for reducer-owned feature state,
  actions, views, and feature-local helpers.
- `apps/ios/Sources/Dependencies/` for small dependency clients and live values.
- `apps/ios/Sources/Domain/` for value types shared by multiple features.
- `apps/ios/Sources/Support/TCA/` for TCA support helpers such as reducer action
  logging.
- `apps/ios/Tests/<Feature>Tests.swift` for Swift Testing `TestStore` proof.

## Migration Order

1. Add shared TCA support only when the first reducer needs it. The first support
   helper should include `.autoLogActions()` for non-root reducers.
2. Move one vertical feature slice at a time: state owner, view entry point,
   side effects, dependency clients, and reducer tests.
3. Convert direct service calls into `@Dependency` clients at the reducer
   boundary. Keep live clients thin and test clients deterministic.
4. Scope navigation and presentation state into the owning feature instead of
   parallel booleans, optional values, or view-local routing state.
5. Delete replaced legacy logic in the same change unless it is a cited shipped
   contract or an explicit follow-up is recorded.

## Validation

- Governance-only changes: `git diff --check`.
- Reducer changes: Swift Testing `TestStore` coverage for key actions,
  dependency responses, and cancellation.
- Project membership changes: edit `apps/ios/project.yml`, regenerate with
  `cd apps/ios && xcodegen generate`, and verify the generated project diff.
- Simulator or UI behavior proof: use `ios-debugger` or XcodeBuildMCP tools,
  not ad hoc shell `xcodebuild`, unless the scoped task explicitly requires a
  fallback.

## Closeout

Report the changed feature, the source files moved or added, the dependency
clients introduced, exact validation commands, and any legacy logic deliberately
left for a later slice.
