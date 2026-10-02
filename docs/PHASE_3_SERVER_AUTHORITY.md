# Phase 3: Server-Authoritative Object State & Delta Synchronization

## 1. Previous Architecture (The Full-Array Problem)

Prior to Phase 3, bazq-os relied on a client-authoritative, full-array persistence pattern:

1. When any authorized client performed an action (placed an object, adjusted via Gizmo or WASD, duplicated, deleted, converted to gate, renamed, or completed a Path Creator segment), the client collected its entire local `spawnedObjects` array.
2. The client invoked `SaveObjectsToServer()` which fired:
   ```lua
   TriggerServerEvent("bazq-objectplace:saveObjects", fullArray)
   ```
3. The server received `objectsDataFromClient` and performed a blind overwrite:
   ```lua
   savedObjects = validatedObjects
   SaveObjectsToFile()
   ```
4. The server then broadcasted `bazq-objectplace:loadObjects` with the entire database to all connected clients.
5. Every connected client looped through all local entities, deleted all world objects, wiped `spawnedObjects = {}`, and recreated every single prop in the database.

### Severe Consequences of the Legacy Architecture:
- **Blind Overwrite & Race Conditions:** If Client A placed a prop while Client B deleted another, whoever's network packet arrived last completely wiped the other player's changes.
- **Security Vulnerability:** A compromised or malicious client with mapper privileges could truncate or modify arbitrary props in the server's database by simply sending an altered array.
- **Resmon & Visual Spikes:** Deleting and recreating all world props caused visible entity flashing, collision drops, physics pops, and massive CPU/network hitches across the entire server.

---

## 2. New Server-Authoritative Mutation Protocol

In Phase 3, **NO CLIENT MAY REPLACE THE SERVER'S ENTIRE `savedObjects` ARRAY**.

Clients now request granular, intent-based mutations. The server validates each request, mutates its canonical in-memory `savedObjects` array, persists the changes to `saved_objects.json`, advances the authoritative monotonic revision counter, and broadcasts a lightweight delta to all clients.

### Operations:

| Operation | Client Trigger Event | Primary Payload | Server Action | Broadcast Delta Event |
|---|---|---|---|---|
| **CREATE** | `bazq-objectplace:placeObject` | `{ model, coords, heading, rotation, ... [requestId] }` | Generates unique ID, validates, appends to `savedObjects`, saves | `bazq-objectplace:objectCreated` |
| **UPDATE** | `bazq-objectplace:updateObject` | `{ id, changes = { coords, heading, rotation, model, ... }, [requestId] }` | Validates ID, patches allowed fields, enforces immutable ID, saves | `bazq-objectplace:objectUpdated` |
| **DELETE** | `bazq-objectplace:deleteObject` | `{ id = "..." }` | Resolves by persistent ID, removes from `savedObjects`, saves | `bazq-objectplace:objectDeleted` |
| **BATCH CREATE** | `bazq-objectplace:batchPlaceObjects` | `{ objects = { ... }, [requestId] }` | Atomically validates all items (1-200), assigns IDs, persists once | `bazq-objectplace:objectsBatchCreated` |
| **BATCH DELETE** | `bazq-objectplace:deleteObjects` | `{ ids = { "...", "..." } }` | Resolves by persistent IDs, removes matching objects, persists once | `bazq-objectplace:objectsBatchDeleted` |

---

## 3. Server-Side Payload Validation

To prevent moving the trust problem into granular events, `server/main.lua` enforces strict centralized validation:

- **Object ID (`ValidateId`):** Must be a string between 5 and 64 characters, matching alphanumeric, underscore, or dash (`^[a-zA-Z0-9_%-]+$`). On create, client-supplied IDs are ignored; the server generates the authoritative ID using `GenerateUniqueObjectId(knownIds)`. On update/delete, the ID must resolve to an existing object in `savedObjects`.
- **Model Name (`ValidateModel`):** Must be a non-empty string between 1 and 64 characters.
- **Coordinates (`ValidateCoords`):** Must be a table with numeric `x`, `y`, `z`. Values must be finite numbers (rejecting `NaN` and `+/-Inf`) within sane FiveM world bounds (-10,000 to +10,000 for X/Y, -2,000 to +10,000 for Z).
- **Heading & Rotation (`ValidateHeading`, `ValidateRotation`):** Must be finite numbers within -3600.0 to +3600.0 degrees.
- **Metadata Strings (`ValidateMetadataString`):** `interiorModel`, `displayName`, and `name` strings are capped at 64 characters to prevent arbitrary memory inflation.
- **Immutable Identity:** On `updateObject`, attempts to alter `changes.id` are stripped or rejected. The existing record's persistent ID is strictly preserved.
- **Atomic Batch Placement (`ValidateBatch`):** Hard limit of 1 to 200 items. Every single item in the batch is pre-validated before any state mutation. If even a single item has invalid coordinates or model, the **entire batch is rejected atomically**, writing 0 objects to disk.

---

## 4. Delta Synchronization Protocol

Routine mutations no longer trigger full-world reload. Instead, clients listen for granular delta events:

### `bazq-objectplace:objectCreated`
- **Payload:** `{ revision = N, object = authoritativeRecord, requestId = "..." }`
- **Placing Client:** Matches `requestId` in `pendingPlacedEntities`, assigns authoritative persistent ID to the local entity/record, registers target, and updates NUI without respawning.
- **Other Clients:** Calls `SpawnPersistentObject(authoritativeRecord)` to create and track only the new entity.

### `bazq-objectplace:objectUpdated`
- **Payload:** `{ revision = N, object = authoritativeRecord, requestId = "..." }`
- **Clients:** Locates local object by `object.id`.
  - If the model changed (e.g., wall converted to gate), safely deletes the previous entity and spawns the new gate entity.
  - If only coordinates, heading, or rotation changed, updates the existing entity in-place using native setters (`SetEntityCoords`, `SetEntityHeading`, `SetEntityRotation`), completely avoiding entity flicker.

### `bazq-objectplace:objectDeleted`
- **Payload:** `{ revision = N, id = targetId, requestId = "..." }`
- **Clients:** Locates local object by `id`, unregisters target, safely deletes entity and any associated interior/door entities, and removes the entry from `spawnedObjects`.

### `bazq-objectplace:objectsBatchCreated`
- **Payload:** `{ revision = N, objects = { ... }, requestId = "..." }`
- **Placing Client:** Correlates with `pendingBatchEntities[requestId]`, assigns authoritative persistent IDs to locally placed props.
- **Other Clients:** Calls `SpawnPersistentObject` for each object in the batch.

### `bazq-objectplace:objectsBatchDeleted`
- **Payload:** `{ revision = N, ids = { ... } }`
- **Clients:** Deletes only the specified entity IDs from the game world and local cache. Used by NUI multi-selection delete and TestZone disconnect cleanup.

---

## 5. State Revision Counter & Resync Model

To ensure clients stay synchronized without falling back to full-world reloads on every action:

1. The server maintains a monotonic integer:
   ```lua
   local objectStateRevision = 0
   ```
2. Every successful logical server mutation advances `objectStateRevision` by exactly 1:
   - Single prop placement: `+1`
   - Single prop update: `+1`
   - Single prop delete: `+1`
   - Batch placement of 50 wall segments: `+1`
   - TestZone cleanup of 12 props: `+1`
3. Every delta payload and initial snapshot includes `revision = objectStateRevision`.
4. Connected clients track `lastAppliedRevision`.
5. When a client receives a delta:
   - If `lastAppliedRevision == 0`: client adopts `delta.revision`.
   - If `delta.revision == lastAppliedRevision + 1`: client applies the delta and updates `lastAppliedRevision`.
   - If `delta.revision > lastAppliedRevision + 1`: **Revision gap detected!** The client missed one or more packets. The client triggers:
     ```lua
     TriggerServerEvent("bazq-objectplace:requestFullSnapshot")
     ```
   - The server replies with `{ revision = objectStateRevision, objects = savedObjects }`. The client then updates its local world state to match the authoritative snapshot.

---

## 6. Client Reconciliation & Optimism

To ensure responsive builder UX without introducing duplicate or flickering props:
- When a user places or duplicates a prop, the client generates an ephemeral, local correlation token:
  ```lua
  local reqId = GenerateRequestId("place") -- e.g. "place_1845920_4821"
  ```
- The local preview entity is stored in `pendingPlacedEntities[reqId]`.
- The `reqId` is transmitted with the server request.
- When `objectCreated` returns echoing `reqId`:
  - The client matches the pending entity, attaches the server's authoritative `id = delta.object.id`, and updates NUI.
  - **No duplicate entity is spawned.**
- If the server rejects the request (`mutationFailed`):
  - The client catches `mutationFailed`, deletes the pending preview entity with `SafeDeleteEntity`, removes it from local tracking, and displays an error notification.

---

## 7. Persistence Failure & Rollback Semantics

`SaveObjectsToFile()` was upgraded to return `boolean, errorMsg`:
- In-memory modifications (`table.insert`, `table.remove`, or property mutations) are staged first.
- `SaveObjectsToFile()` writes and verifies the JSON file on disk.
- **If persistence succeeds:**
  - `objectStateRevision` is incremented.
  - Delta event is broadcast to clients.
- **If persistence fails (e.g. disk full, write lock):**
  - Staged in-memory modifications are immediately rolled back (inserted objects removed, deleted objects re-inserted, updated fields reverted to snapshot).
  - Revision is NOT advanced.
  - No delta is broadcast.
  - `bazq-objectplace:mutationFailed` is sent to the requesting client.

---

## 8. Legacy Event Removal & Deprecation

- All client calls to `SaveObjectsToServer()` across all 11 mutation sites in `client/main.lua` have been removed and replaced with granular triggers.
- `SaveObjectsToServer()` in `client/main.lua` has been reduced to a deprecation warning stub.
- In `server/main.lua`, `bazq-objectplace:saveObjects` has been converted into a security rejection handler:
  ```lua
  RegisterNetEvent("bazq-objectplace:saveObjects", function()
      OPLog("SECURITY ALERT: Client attempted deprecated full-array saveObjects! Rejected.")
      TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
          action = "saveObjects",
          reason = "Client-authoritative full-array saveObjects is permanently deprecated and disabled."
      })
  end)
  ```
- **Active Codebase Search Verification:**
  - `0` client calls triggering `saveObjects`.
  - `0` server assignments replacing `savedObjects` with client data.

---

## 9. Remaining Compatibility Fallbacks

1. **Snapshot Loader:** `bazq-objectplace:loadObjects` remains available solely for initial player connection (`playerJoining`), resource start (`onResourceStart`), and revision gap resync (`requestFullSnapshot`).
2. **Legacy Coordinate Matching:** TestZone disconnect cleanup maintains coordinate fallback matching (`math.abs(coords.x - playerObj.coords.x) < 0.1`) strictly to accommodate any un-migrated props that might lack an ID in corrupt legacy data.
3. **Legacy syncObjectIds Listener:** Retained as a no-op handler on client to prevent network event errors if any external debug event fires it.

---

## 10. Static Simulation Test Results

Simulation tests were executed against the Phase 3 protocol implementation:

| Test Case | Description | Result |
|---|---|---|
| **Create** | Valid create accepted, server assigns unique ID, revision advances +1 | **PASSED** |
| **Invalid create** | Malformed coords (NaN) rejected, server state and revision unchanged | **PASSED** |
| **Update** | Existing ID updated, coordinates modified, revision advances +1 | **PASSED** |
| **Unknown update** | Non-existent ID rejected with error, revision unchanged | **PASSED** |
| **ID mutation attempt** | Attempt to alter `id` via `changes.id` ignored; persistent ID preserved | **PASSED** |
| **Delete** | Exact ID removed from server state, revision advances +1 | **PASSED** |
| **Unknown delete** | Deletion of non-existent ID rejected, revision unchanged | **PASSED** |
| **Batch** | Path Creator batch persists multiple props in 1 logical mutation, revision +1 | **PASSED** |
| **Invalid batch** | Atomic rejection when 1 item is invalid; 0 partial props saved, revision unchanged | **PASSED** |
| **Duplicate** | Duplicate creates new server record with distinct ID (`source.id != dup.id`) | **PASSED** |
| **Revision mismatch** | Client detects revision gap (1 -> 10) and triggers full snapshot resync | **PASSED** |

---

## 11. Runtime Verification Checklist

1. [ ] Backup `saved_objects.json`.
2. [ ] Restart resource (`ensure bazq-os`).
3. [ ] Connect Client A and Client B.
4. [ ] Verify both clients receive initial authoritative snapshot (`loadObjects`) with identical revision.
5. [ ] Client A places a single prop (Manual placement).
6. [ ] Verify Client A's preview prop transitions seamlessly to persistent state without flickering.
7. [ ] Verify Client B receives `objectCreated` and spawns only that prop. Verify existing props do NOT reload or flash.
8. [ ] Client A edits prop position with Gizmo or keyboard edit.
9. [ ] Verify Client B receives `objectUpdated` and sees the prop move smoothly in-place.
10. [ ] Client B deletes the prop.
11. [ ] Verify Client A receives `objectDeleted` and the prop is removed without global world reload.
12. [ ] Duplicate a prop via Target or NUI. Verify new prop has a distinct ID in `saved_objects.json`.
13. [ ] Rename a prop in NUI. Verify `objectUpdated` updates displayName on server and client without recreating the prop.
14. [ ] Convert a wall segment to Gate. Verify `objectUpdated` preserves the original persistent ID.
15. [ ] Use Path Creator to draw a wall line (10+ segments). Verify `batchPlaceObjects` saves once, advances revision by +1, and Client B spawns all segments without wiping unrelated objects.
16. [ ] Enable TestZone disconnect cleanup. Disconnect a test player and verify only their props are removed via `objectsBatchDeleted`.
17. [ ] Restart server/resource. Verify `saved_objects.json` loads cleanly with all persistent IDs intact.

---

## 12. Remaining Future Work

- **Pen Tool / Path Creator Generation Refactor:** Layout generation, segment alignment, curve math, and deterministic preview remain scheduled for a later phase. Phase 3 only updated the persistence and synchronization layer of Path Creator (`batchPlaceObjects`).
- **NUI Redesign & Packaging System:** Out-of-scope for Phase 3.
