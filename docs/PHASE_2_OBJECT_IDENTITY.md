# Phase 2: Persistent Object Identity

## 1. Previous Identity Model

Prior to Phase 2, `bazq-os` lacked an immutable persistent object identity:
- **Array Index Coupling:** Objects in `saved_objects.json` and client runtime tables were identified solely by their current array index (`1..N`). Any operation altering table order (such as `table.remove` during deletion, or prepending/sorting) shifted all downstream indexes, causing operations like Edit, Delete, Duplicate, and Teleport to target wrong entities or corrupt data.
- **Fuzzy Coordinate / Metadata Matching:** TestZone disconnect cleanup, target lookups, and keyboard edit loops fell back to comparing approximate 3D coordinates (`math.abs(a - b) < 0.1`) or matching transient fields (`timestamp` + `playerName`). If two identical props were placed close together or by the same player in the same second, fuzzy matching misidentified the target object.
- **Entity Handle Ephemerality:** FiveM entity handles (`ent`) are runtime-only integers assigned by the game engine that do not survive across resource restarts or streaming ranges.

---

## 2. New Identity Model

Phase 2 establishes persistent, immutable object identity across the entire lifecycle:
```lua
{
    id = "obj_66fe8a1b_f9a8b7c6d5e4a3b2",
    model = "bazq-wall1",
    coords = { x = -2050.25, y = 3240.10, z = 32.50 },
    heading = 180.0,
    rotation = { x = 0.0, y = 0.0, z = 180.0 },
    playerName = "bazq",
    timestamp = "1727914523",
    -- Existing optional metadata preserved intact
}
```

Key characteristics:
1. **Server-Authoritative:** The server generates all IDs. Clients never invent authoritative IDs.
2. **Persistence:** The `id` is saved directly to `saved_objects.json` and survives resource/server restarts.
3. **Immutability:** An object's `id` never changes during edits, rotations, coordinate modifications, or adjacent deletions.
4. **Order Independence:** The `id` is completely decoupled from array indices.
5. **Transformed Objects (Convert to Gate):** Transforming an object preserves the original object's logical `id`.
6. **Duplicated Objects:** Duplicating an object assigns a fresh, unique `id` (`source.id ~= duplicate.id`).

---

## 3. ID Generation

The server implements a collision-safe, dependency-free token generator in `server/main.lua`:
- `GenerateObjectId()` produces an opaque string formatted as `obj_<timestamp_hex>_<16_hex_chars>`.
- `GenerateUniqueObjectId(knownIds)` tests generated IDs against the known namespace of persisted IDs and retries if a collision occurs.

```lua
local function GenerateRandomToken(length)
    local chars = "0123456789abcdef"
    local token = {}
    for i = 1, (length or 16) do
        local rand = math.random(1, #chars)
        token[#token + 1] = chars:sub(rand, rand)
    end
    return table.concat(token)
end

local function GenerateObjectId()
    local timestampHex = string.format("%x", os.time())
    local randomPart = GenerateRandomToken(16)
    return string.format("obj_%s_%s", timestampHex, randomPart)
end
```

---

## 4. Migration & Idempotency

When `saved_objects.json` is loaded on resource start:
1. **Existing Valid IDs:** Preserved without change.
2. **Legacy Objects Without IDs:** Assigned unique server-generated IDs.
3. **Corrupt / Duplicate IDs:** First occurrence preserved; subsequent duplicate IDs repaired and logged.
4. **Immediate Persistence:** If any object was migrated or repaired, `SaveObjectsToFile()` writes the updated state immediately.
5. **Idempotency:** A second load or server restart yields `0 migrated, 0 repaired`.

Console log format:
```text
[bazq-os] Object ID migration: 127 existing, 18 migrated, 0 duplicate IDs repaired.
[bazq-os] Object ID migration: 145 existing, 0 migrated, 0 duplicate IDs repaired.
```

---

## 5. Client & NUI Mapping

The system strictly distinguishes three distinct concepts:
- **Persistent Object ID (`id`):** Authoritative identity across persistence, synchronization, and target lookups.
- **Entity Handle (`entity`):** Transient GTA V game engine handle.
- **Array Index (`index` / `originalIndex`):** Presentation/display order for NUI grid and compact lists.

### Client Helpers:
- `GetObjectById(id)`: Returns the object and current runtime index by persistent ID.
- `GetObjectByEntity(entity)`: Returns the object and current runtime index by entity handle.
- `GetSpawnedObjectByIdOrIndex(id, index)`: Resolves an object by ID first, falling back to index.

### NUI Interaction:
Action callbacks and grid buttons now carry both `id` and `index`:
```json
{
  "id": "obj_66fe8a1b_f9a8b7c6d5e4a3b2",
  "index": 4
}
```
All client NUI handlers (`selectObject`, `editObject`, `editSpawnedObject`, `duplicateObject`, `deleteObject`, `deleteObjects`, `renameObject`, `teleportToObject`) resolve the target by persistent `id` first.

---

## 6. Compatibility Layer During Legacy saveObjects

Phase 3 will introduce granular server-authoritative CRUD, but Phase 2 protects IDs within the existing `saveObjects` full-array flow:
- `GetSerializableSpawnedObjects()` includes `id = objData.id`.
- `SaveObjectsToServer()` serializes `id = objData.id`.
- When the server receives `saveObjects`:
  - Existing valid IDs that have not collided are accepted and preserved.
  - New objects (manual placement, duplication, path creation) without IDs receive server-generated authoritative IDs.
  - The server emits `bazq-objectplace:syncObjectIds` back to the saving client with the canonical list of IDs.
  - The client matches incoming IDs to `spawnedObjects[i].id` and refreshes NUI.

---

## 7. Remaining Phase 3 Architectural Risks

> [!WARNING]
> While Phase 2 successfully establishes persistent identity across the codebase, **`saveObjects` remains a client-authoritative full-array persistence mechanism**.
> 
> A client sending a malformed or compromised array back to the server still overwrites the entire persistence file. Phase 3 will replace this mechanism with server-authoritative granular events (`placeObject`, `updateObject`, `deleteObject`, `batchPlaceObjects`) and delta synchronization.

---

## 8. Validation Results

Tested against 5 static migration test fixtures:

| Fixture | Scenario | Expected | Result |
| :--- | :--- | :--- | :--- |
| **Legacy Fixture** | 3 objects without IDs | 3 unique IDs assigned, 0 repaired | **PASSED** (3 migrated, 0 repaired) |
| **Restart Fixture** | Re-run migration on migrated state | 0 IDs changed, 0 new IDs assigned | **PASSED** (0 migrated, 0 repaired) |
| **Mixed Fixture** | 2 objects with IDs, 2 without IDs | 2 preserved, 2 assigned | **PASSED** (2 preserved, 2 migrated) |
| **Duplicate Fixture** | 2 objects sharing same ID | 1st preserved, 2nd repaired | **PASSED** (1st preserved, 1 repaired) |
| **Duplication Semantics** | Client duplicates an object | `source.id ~= duplicate.id` | **PASSED** (fresh server ID assigned) |

---

## 9. Runtime Checklist (FiveM Manual Verification)

1. [ ] Create a backup of `saved_objects.json`.
2. [ ] Start / restart `bazq-os` on the FiveM server.
3. [ ] Check server console: confirm migration summary line appears (e.g. `Object ID migration: X existing, Y migrated, 0 repaired`).
4. [ ] Restart `bazq-os` a second time: confirm console outputs `0 migrated, 0 duplicate IDs repaired`.
5. [ ] Connect in-game and press `F7` to open menu.
6. [ ] Confirm legacy objects appear in the Placed Objects tab with model icons and display names.
7. [ ] Select and edit an existing object using Gizmo / WASD. Save changes.
8. [ ] Restart resource and verify the edited object persisted with its original ID.
9. [ ] Delete an object from the middle of the list. Confirm only that specific object disappears and remaining objects retain correct identity.
10. [ ] Duplicate an object via target menu or NUI.
11. [ ] Check server logs / `saved_objects.json` to confirm the duplicate received a brand new unique ID distinct from the source.
12. [ ] Target a wall prop and use `Convert to Gate (Kapı Yap)`.
13. [ ] Verify gate spawns and preserves the original wall's persistent ID.
14. [ ] Draw a path using Path Creator and place multiple props.
15. [ ] Restart resource and confirm all Path Creator props persisted with server-assigned IDs.
16. [ ] Test TestZone cleanup upon disconnect (if enabled in `config.lua`).
17. [ ] Check server console and client `F8` console for errors or warnings.
