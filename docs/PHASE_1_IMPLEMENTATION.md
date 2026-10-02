# Phase 1 Implementation: Foundation Fixes

This document details the implementation of **Phase 1** fixes for `bazq-os`, addressing lexical scoping traps and configuration fragmentation identified in [BAZQ_OS_SOURCE_AUDIT.md](file:///d:/bazq/basez/txData/Qbox_4AEC51.base/resources/[bazq]/bazq-os/docs/BAZQ_OS_SOURCE_AUDIT.md).

---

## Changes Made

### 1. LUA-01 — Server Lexical Scope / Initialization Ordering
* **Original Issue:** In `server/main.lua`, event handlers registered early in execution (specifically `playerDropped` and `playerJoining`) referenced local variables (`savedObjects`, `osAdminData`, `playerPlacedObjects`) and helper functions (`SaveObjectsToFile`, `SaveOsAdminToFile`, `IsPlayerAdmin`) before their declarations. In Lua, any identifier referenced before a `local` declaration compiles into an upvalue/global lookup (`_G`), causing runtime `nil` indexing and unhandled errors when players disconnected or joined.
* **Exact Fix:**
  1. Reorganized `server/main.lua` header to declare all persistent state and persistence filepaths at the top:
     - `jsonFilePath`, `osAdminFilePath`
     - `savedObjects`, `osAdminData`, `playerPlacedObjects`
  2. Moved core JSON and file persistence routines (`FormatJson`, `SaveOsAdminToFile`, `SaveObjectsToFile`, `LoadObjectsFromFile`, `LoadOsAdminFromFile`) immediately beneath state declaration, prior to any event registrations or connection hooks.
  3. Hoisted `IsPlayerAdmin` before `HasPermission` so `HasPermission` closes over the local function rather than a global.
  4. Executed `LoadObjectsFromFile()` and `LoadOsAdminFromFile()` synchronously during initial file execution, before registering `playerDropped` and `playerJoining`.
  5. Replaced obsolete reference to `debugConfig.userManagement` in `InitializeDefaultUsers` with `Config.UserManagement`.
* **Files Changed:** [server/main.lua](file:///d:/bazq/basez/txData/Qbox_4AEC51.base/resources/[bazq]/bazq-os/server/main.lua)
* **Why the Fix is Safe:** The underlying data schemas, network event names, and JSON persistence logic were not altered. Persistent storage is simply guaranteed to be loaded and local identifiers are bound in lexical scope before any callback can execute.

---

### 2. LUA-02 — Client `currentPlacementOptions` Lexical Scope
* **Original Issue:** In `client/main.lua`, `currentPlacementOptions` was declared as a `local` variable around line 611, but was referenced much earlier in functions such as `StartTargetDuplicate` (line 217) and `ConvertToGate` (line 587). At compile time, those early functions bound to `_G.currentPlacementOptions` (which evaluated to `nil`), causing silent failures or fallback to `"Unknown"` player name during duplication.
* **Exact Fix:**
  1. Hoisted the single authoritative `local currentPlacementOptions` declaration to line 64 of `client/main.lua` (adjacent to `spawnedObjects`).
  2. Removed the redundant duplicate `local currentPlacementOptions` declaration at line 611.
  3. Verified that exactly one declaration exists in the client codebase and that all 15+ call sites access this shared local table.
* **Files Changed:** [client/main.lua](file:///d:/bazq/basez/txData/Qbox_4AEC51.base/resources/[bazq]/bazq-os/client/main.lua)
* **Why the Fix is Safe:** Default keys (`snapToGround = true`, `timestamp = ""`, `playerName = "Unknown"`) remain identical. No variable shadowing or duplicate state instances exist.

---

### 3. CFG-01 — Obsolete `debug_config.lua` / TestZone Configuration Split
* **Original Issue:** `client/main.lua` attempted to load an unversioned `debug_config.lua` from disk using `LoadResourceFile`. Because this file did not exist in the repository, the loader failed and initialized a fallback table with `testZone.enabled = false`. As a result, client-side TestZone monitoring threads, commands, and permission bypasses remained disabled, even when `shared/config.lua` had `Config.TestZone.enabled = true`.
* **Exact Fix:**
  1. Removed `LoadDebugConfig()` and its fallback initialization block from `client/main.lua`.
  2. Migrated `IsPlayerInTestZone()` to consume `Config.TestZone` directly (checking `enabled`, `center`, `radius`, and `Config.Debug`).
  3. Migrated the TestZone monitoring thread and the Special Controls thread to consume `Config.TestZone` (`showControlsUI`, `specialControls`).
  4. Migrated NUI callback `reopenMenu` and debug commands (`testconfig`, `debugf6`, `debugf7`, `bazq_testzone_f7`) to read `Config.TestZone`.
  5. Verified 0 remaining occurrences of `debugConfig` and `debug_config.lua` across the entire resource.
* **Files Changed:** [client/main.lua](file:///d:/bazq/basez/txData/Qbox_4AEC51.base/resources/[bazq]/bazq-os/client/main.lua)
* **Why the Fix is Safe:** Both client and server now share the single canonical configuration in `shared/config.lua` (`Config.TestZone`). No fields were invented. Where the legacy loader referenced `debugConfig.levels.TESTZONE`, it was cleanly mapped to standard `Config.Debug`.

---

## Additional Lexical-Scope Findings

During our focused static AST/token scan across runtime Lua scripts, two additional scope traps matching the same AI pattern were discovered in `client/main.lua`. Per project guidelines, these were not modified in Phase 1 and are reported here for scheduling:

1. **`ConvertToGate` Target Callback:**
   - **Declared:** Line ~433 (`local function ConvertToGate(entity)`)
   - **Referenced earlier:** Line ~338 inside `RegisterTargetForEntity`:
     ```lua
     onSelect = function(data)
         ConvertToGate(data.entity)
     end
     ```
   - **Impact:** When `RegisterTargetForEntity` is compiled, `ConvertToGate` resolves to `_G.ConvertToGate` (which is `nil`), rather than the local function defined further down. A forward declaration (`local ConvertToGate`) or hoisting is required.

2. **`ToggleFreecam` in NUI Callback & Test Command:**
   - **Declared:** Line ~1667 (`local function ToggleFreecam()`)
   - **Referenced earlier:** Line ~1297 (`RegisterNUICallback('toggleFreecam', ...)`) and Line ~1600 (`RegisterCommand('testf6', ...)`).
   - **Impact:** The NUI callback `toggleFreecam` and command `testf6` attempt to call `_G.ToggleFreecam()` which is `nil`. Keymapping `bazq_f6` at line ~4932 is defined *after* line 1667 and works, but UI toggles may fail. A forward declaration (`local ToggleFreecam`) or hoisting is required.

---

## Static Validation

The following automated and static checks were executed:

1. **`currentPlacementOptions` Scan:**
   - Query: `Select-String -Path "client\main.lua" -Pattern "local currentPlacementOptions"`
   - Result: Exactly 1 local declaration found at line 64. 0 duplicates, 0 shadow declarations.
2. **`debugConfig` & `debug_config.lua` Scan:**
   - Query: `Select-String -Path "client\*.lua", "server\*.lua", "shared\*.lua", "fxmanifest.lua" -Pattern "debugConfig|debug_config"`
   - Result: 0 occurrences remaining across all Lua source files.
3. **`Config.TestZone` Integration:**
   - Both client and server now consume `Config.TestZone` identically with standard null checks (`if Config.TestZone and Config.TestZone.enabled then`).
4. **Server Initialization Order:**
   - Persistence state (`savedObjects`, `osAdminData`, `playerPlacedObjects`) and persistence helper functions (`SaveObjectsToFile`, `SaveOsAdminToFile`) are declared and loaded before `playerDropped` and `playerJoining` handlers.
5. **Syntax & File Integrity:**
   - All modified Lua files (`server/main.lua`, `client/main.lua`) parse cleanly without unclosed strings, unbalanced blocks, or syntax errors.

---

## Runtime Validation Checklist

The following manual test steps must be conducted in FiveM:

- [ ] 1. Restart `bazq-os` on the server (`ensure bazq-os` or `restart bazq-os`).
- [ ] 2. Verify server console output: confirm `LoadObjectsFromFile` and `LoadOsAdminFromFile` report loaded counts without nil index errors.
- [ ] 3. Join the server and verify no F8 console startup errors.
- [ ] 4. Press **F7** to open the Object Spawner menu normally.
- [ ] 5. Spawn a normal object (e.g. from `wall_pack_1`) and confirm placement.
- [ ] 6. Target the placed object and select **Edit**; adjust coordinates and confirm saving.
- [ ] 7. Target the placed object and select **Duplicate**; verify options and placement succeed without error.
- [ ] 8. Target a wall and test **Convert to Gate** if applicable.
- [ ] 9. Temporarily set `Config.TestZone.enabled = true` in `shared/config.lua` and restart the resource.
- [ ] 10. Walk/fly into the configured TestZone coordinates; observe green chat notification and UI indicator.
- [ ] 11. Place an object while inside TestZone as a non-admin player. Disconnect and verify server logs indicate TestZone cleanup if `cleanupOnDisconnect` is enabled.
- [ ] 12. Revert `Config.TestZone.enabled = false` after testing.
- [ ] 13. Inspect client F8 console and server console to ensure 0 errors were generated.
