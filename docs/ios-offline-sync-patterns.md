# iOS Offline Sync Patterns

## Full Sync vs Partial Sync

The local SwiftData store syncs with the server in two different contexts:

1. **Full sync** (pull-to-refresh / initial load): The server response contains *all* items. Local items not in the response can safely be pruned — they were deleted server-side.

2. **Partial sync** (push pending creates/updates): The server response contains only the items that were just created or updated. Local items missing from this response are **not** deleted — they simply weren't part of this request.

### The Bug This Prevents

If a `saveItems` method unconditionally deletes local synced items not present in the response, then every partial sync (e.g., after creating a single item) will wipe all previously-synced items. The user sees only the most recently added items until the next full refresh.

### Pattern

Repository methods that reconcile server responses with local state should accept a flag (e.g., `pruneOrphans`) to distinguish full syncs from partial syncs:

```swift
func saveItems(_ items: [ShoppingListItemResponse], pruneOrphans: Bool) throws {
    if pruneOrphans {
        // Only during full sync: remove local items absent from server
        let serverClientIds = Set(items.map(\.clientId))
        for local in localItems where local.syncState == .synced && !serverClientIds.contains(local.clientId) {
            modelContext.delete(local)
        }
    }
    // Upsert logic for all items...
}
```

- `refresh()` calls `saveItems(apiItems, pruneOrphans: true)` — complete server state
- `syncPendingChanges()` calls `saveItems(created, pruneOrphans: false)` — partial response
