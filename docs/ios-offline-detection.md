# iOS Offline Detection

The iOS app uses a single global `NetworkMonitor` to decide whether the UI should show the "Offline" badge and disable actions that require a live server connection.

Relevant files:

- `hauptgang-ios/Hauptgang/Services/NetworkMonitor.swift`
- `hauptgang-ios/Hauptgang/Utilities/Constants.swift`
- `hauptgang-ios/Hauptgang/App/HauptgangApp.swift`
- `hauptgang-ios/Hauptgang/Views/ContentView.swift`
- `hauptgang-ios/Hauptgang/Views/OfflineToast.swift`
- `hauptgang-ios/Hauptgang/Views/RecipesView.swift`
- `hauptgang-ios/Hauptgang/Views/ShoppingListView.swift`
- `hauptgang-ios/Hauptgang/Views/MealPlanView.swift`
- `hauptgang-ios/Hauptgang/Views/MealPlanDayCard.swift`
- `hauptgang-ios/HauptgangTests/Services/NetworkMonitorTests.swift`

## Architecture

`NetworkMonitor` is a `@MainActor`, `@Observable` singleton exposed as `NetworkMonitor.shared`.

It combines two signals:

- `NWPathMonitor` reports whether iOS currently sees a usable network path.
- A backend health check performs a `GET` request to `Constants.API.healthCheckURL`, which resolves to `/up` on the app host.

The monitor owns a single `isOffline` flag. Views read that flag from the SwiftUI environment instead of maintaining their own per-screen offline state.

## Health Check Behavior

Each `/up` probe builds a fresh ephemeral `URLSession` configured to avoid cached reachability decisions and stale reachability state from a session created while offline:

- `URLSessionConfiguration.ephemeral`
- `requestCachePolicy = .reloadIgnoringLocalCacheData`
- `urlCache = nil`
- `waitsForConnectivity = false`
- `timeoutIntervalForRequest = 5`
- `timeoutIntervalForResource = 5`

Any non-2xx response marks the app offline. A 2xx response marks it online.

## State Transitions

The monitor updates `isOffline` from three entry points:

- Initial startup: `NetworkMonitor` starts `NWPathMonitor` and immediately evaluates the current path.
- Path changes: `NWPathMonitor` calls back whenever the network path changes.
- Explicit probes: the app can request a fresh `/up` check on foreground or pull-to-refresh.

The transition rules are:

- If the path becomes unsatisfied, the app is marked offline immediately.
- If the path becomes satisfied, the monitor schedules a `/up` probe before marking the app back online.
- If a manual or foreground probe returns 2xx, the app is marked online.
- If a manual or foreground probe fails or returns non-2xx, the app stays offline.

## Recovery Loop

When the app becomes offline after a real path update or a failed `/up` request, `NetworkMonitor` starts a recovery task.

That task:

- Re-runs the `/up` probe while `isOffline == true`
- Sleeps for 3 seconds between attempts
- Stops as soon as a probe returns 2xx
- Stops when a newer manual probe cancels it

This lets the badge clear without requiring the user to restart the app or manually trigger another screen transition.

## SwiftUI Wiring

`HauptgangApp` injects the singleton once with:

```swift
.environment(NetworkMonitor.shared)
```

Views then read it with:

```swift
@Environment(NetworkMonitor.self) private var networkMonitor
```

Current consumers:

- `RecipesView` shows the offline toast and probes before pull-to-refresh.
- `ShoppingListView` shows the offline toast and probes before pull-to-refresh.
- `MealPlanView` shows the offline toast and probes before pull-to-refresh.
- `MealPlanDayCard` disables actions that should not run while offline.

`ContentView` also calls `NetworkMonitor.shared.appDidBecomeActive()` when the scene phase returns to `.active`, so the app re-checks reachability after foregrounding.

## UI Pattern

Offline UI now follows one shared pattern:

- Read `networkMonitor.isOffline` from the environment.
- Show the shared `offlineToast(isOffline:)` modifier where appropriate.
- For user-driven refresh, call `await networkMonitor.refreshStatus()` before the feature's own refresh work.
- Do not add a second `isOffline` flag to a feature view model unless the state is feature-specific rather than app-wide connectivity.

## Testing

`NetworkMonitorTests` covers the intended monitor behavior with a mock path monitor and mock URL protocol:

- Manual refresh clears offline when `/up` succeeds.
- Manual refresh can clear offline even if the current path is still unsatisfied.
- A satisfied path transition triggers a `/up` probe and can clear offline.
- The recovery loop can clear offline after a later successful probe.
- Failed health checks keep the app offline.

## When Changing This System

If you change offline detection behavior:

- Keep `NetworkMonitor` as the single source of truth for app-wide connectivity UI.
- Add or update tests in `HauptgangTests/Services/NetworkMonitorTests.swift`.
- If you add a new pull-to-refresh surface, call `networkMonitor.refreshStatus()` there as well.
- Keep `/up` resolution in `Constants.API.healthCheckURL` so the host and environment stay consistent with the rest of the app.
