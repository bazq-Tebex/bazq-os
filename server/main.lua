-- ================================
-- SYSTEM INITIALIZATION (SERVER)
-- ================================

-- Core bazq debug wrapper
local function dbg(msg)
    if Config.Debug then
        print(("^4[bazq-%s] ^7%s"):format("os", msg))
    end
end

-- ================================
-- SCRIPT CONFIGURATION & STATE
-- ================================

local jsonFilePath = GetResourcePath(GetCurrentResourceName()) .. "/saved_objects.json"
local osAdminFilePath = GetResourcePath(GetCurrentResourceName()) .. "/osadmin.json"
local savedObjects = {} -- In-memory cache of saved objects
local osAdminData = {} -- In-memory cache of osadmin data
local playerPlacedObjects = {} -- Track per-player placed objects for optional cleanup
local objectStateRevision = 0 -- Authoritative monotonic state revision counter

-- Authoritative ID-based object lookup helpers
local function FindObjectIndexById(id)
    if type(id) ~= "string" or id == "" then return nil end
    for i, obj in ipairs(savedObjects) do
        if type(obj) == "table" and obj.id == id then
            return i
        end
    end
    return nil
end

local function GetObjectById(id)
    local idx = FindObjectIndexById(id)
    if idx then
        return savedObjects[idx], idx
    end
    return nil, nil
end

-- Helper to format JSON (Pretty Print)
local function FormatJson(json_str)
    if not json_str then return "" end
    local formatted = ""
    local indent_level = 0
    local in_string = false
    local escape = false
    
    for i = 1, #json_str do
        local char = string.sub(json_str, i, i)
        
        if not escape and char == '"' then
            in_string = not in_string
        elseif not in_string then
            if char == '{' or char == '[' then
                indent_level = indent_level + 1
                formatted = formatted .. char .. "\n" .. string.rep("  ", indent_level)
                goto continue
            elseif char == '}' or char == ']' then
                indent_level = indent_level - 1
                formatted = formatted .. "\n" .. string.rep("  ", indent_level) .. char
                goto continue
            elseif char == ',' then
                formatted = formatted .. char .. "\n" .. string.rep("  ", indent_level)
                goto continue
            elseif char == ':' then
                formatted = formatted .. ": "
                goto continue
            elseif char == ' ' or char == '\n' or char == '\t' or char == '\r' then
                -- Ignore existing whitespace outside strings
                goto continue
            end
        end
        
        formatted = formatted .. char
        
        if char == '\\' then
            escape = not escape
        else
            escape = false
        end
        
        ::continue::
    end
    
    return formatted
end

-- Save osadmin data to JSON file (formatted for manual editing)
local function SaveOsAdminToFile()
    osAdminData.last_updated = os.date("%Y-%m-%d %H:%M:%S")
    
    -- Create a more readable structure for manual editing
    local readableData = {
        _README = {
            description = "bazq-os User Management Configuration",
            instructions = "Add your first owner manually by editing the users array below",
            role_hierarchy = "owner > admin > mapper > guest",
            permissions = {
                owner = "Full access - can do everything including manage other owners",
                admin = "Can manage users and use spawner (cannot modify owners)",
                mapper = "Can only use object spawner (cannot manage users)"
            },
            identifier_help = "Use 'steam:XXXXXXXXX', 'fivem:XXXXXX', or 'license:XXXXXXXX' format"
        },
        userManagement = {
            settings = osAdminData.userManagement and osAdminData.userManagement.settings or {
                autoPromoteFirstUser = true,
                requireApproval = false
            },
            users = osAdminData.userManagement and osAdminData.userManagement.users or {}
        },
        version = "2.10",
        last_updated = osAdminData.last_updated,
        
        -- Keep legacy admins for backwards compatibility but mark as deprecated
        admins = osAdminData.admins or {},
        _legacy_note = "The 'admins' section is deprecated. Please use 'userManagement.users' instead."
    }
    
    local success, encodedData = pcall(json.encode, readableData)
    if success then
        -- Apply proper JSON formatting
        encodedData = FormatJson(encodedData)
        
        local saveSuccess = SaveResourceFile(GetCurrentResourceName(), "osadmin.json", encodedData, -1)
        if not saveSuccess then
            OPLog("[ObjectPlacer] SERVER ERROR: SaveResourceFile failed to write to osadmin.json")
        else
            OPLog("[ObjectPlacer] SERVER INFO: Successfully saved user management data")
        end
    else
        dbg("SERVER ERROR: Failed to encode osadmin data to JSON. Error: " .. tostring(encodedData))
    end
end

-- ============================================
-- AUTHORITATIVE SERVER-SIDE OBJECT ID GENERATOR
-- ============================================
local function GenerateRandomToken(len)
    local chars = "0123456789abcdef"
    local t = {}
    for i = 1, len do
        local r = math.random(1, #chars)
        t[i] = string.sub(chars, r, r)
    end
    return table.concat(t)
end

local function GenerateObjectId()
    -- Format: obj_<timestamp_hex>_<random_16_hex> (opaque, collision-resistant token)
    return string.format("obj_%08x_%s", os.time(), GenerateRandomToken(16))
end

local function GenerateUniqueObjectId(knownIds)
    local newId = GenerateObjectId()
    local attempts = 0
    while knownIds and knownIds[newId] and attempts < 100 do
        newId = GenerateObjectId()
        attempts = attempts + 1
    end
    return newId
end

-- Save objects to JSON file (returns success boolean and optional error message)
local function SaveObjectsToFile()
    DebugSave("SaveObjectsToFile() called with " .. #savedObjects .. " objects")
    
    -- Log first few objects for debugging
    if #savedObjects > 0 then
        for i = 1, math.min(3, #savedObjects) do
            local obj = savedObjects[i]
            DebugSave(string.format("Object %d: ID=%s, Model=%s at %.2f,%.2f,%.2f", 
                i, obj.id or "nil", obj.model or "nil", 
                obj.coords and obj.coords.x or 0, 
                obj.coords and obj.coords.y or 0, 
                obj.coords and obj.coords.z or 0))
        end
    end
    
    local success, encodedObjects = pcall(json.encode, savedObjects)
    if not success then
        local err = "Failed to encode objects to JSON: " .. tostring(encodedObjects)
        OPLog("[ObjectPlacer] SERVER ERROR: " .. err)
        return false, err
    end

    -- Apply formatting
    encodedObjects = FormatJson(encodedObjects)
    DebugSave("JSON encoding successful. Length: " .. string.len(encodedObjects))
    
    local saveSuccess = SaveResourceFile(GetCurrentResourceName(), "saved_objects.json", encodedObjects, -1)
    if not saveSuccess then
        local err = "SaveResourceFile failed to write to saved_objects.json"
        OPLog("[ObjectPlacer] SERVER ERROR: " .. err)
        OPLog("[ObjectPlacer] SERVER ERROR: Resource path: " .. GetResourcePath(GetCurrentResourceName()))
        return false, err
    end

    OPLog("[ObjectPlacer] SERVER SUCCESS: Saved " .. #savedObjects .. " objects to saved_objects.json")
    return true
end

-- Backward-compatible persistent ID migration
local function MigrateObjectIds()
    if type(savedObjects) ~= "table" then return end
    
    local knownIds = {}
    local migratedCount = 0
    local repairedCount = 0
    local totalCount = #savedObjects
    
    -- Pass 1: Index existing valid IDs
    for _, obj in ipairs(savedObjects) do
        if type(obj) == "table" and type(obj.id) == "string" and obj.id ~= "" then
            if not knownIds[obj.id] then
                knownIds[obj.id] = true
            end
        end
    end
    
    -- Pass 2: Repair duplicate IDs and assign missing IDs
    local seenInPass = {}
    for i, obj in ipairs(savedObjects) do
        if type(obj) == "table" then
            if type(obj.id) == "string" and obj.id ~= "" then
                if seenInPass[obj.id] then
                    local oldId = obj.id
                    local newId = GenerateUniqueObjectId(knownIds)
                    obj.id = newId
                    knownIds[newId] = true
                    seenInPass[newId] = true
                    repairedCount = repairedCount + 1
                    dbg(string.format("Duplicate object ID '%s' at index %d repaired to '%s'", oldId, i, newId))
                else
                    seenInPass[obj.id] = true
                end
            else
                local newId = GenerateUniqueObjectId(knownIds)
                obj.id = newId
                knownIds[newId] = true
                seenInPass[newId] = true
                migratedCount = migratedCount + 1
            end
        end
    end
    
    print(string.format("^4[bazq-os] ^7Object ID migration: %d existing, %d migrated, %d duplicate IDs repaired.", 
        totalCount, migratedCount, repairedCount))
    
    -- Persist immediately if any IDs were added or repaired
    if migratedCount > 0 or repairedCount > 0 then
        SaveObjectsToFile()
    end
end

-- Load objects from JSON file (on server start)
local function LoadObjectsFromFile()
    local fileContent = LoadResourceFile(GetCurrentResourceName(), "saved_objects.json")
    if fileContent and fileContent ~= "" then
        local success, decodedObjects = pcall(json.decode, fileContent)
        if success and type(decodedObjects) == "table" then
            savedObjects = decodedObjects
            -- Perform Phase 2 persistent ID migration
            MigrateObjectIds()
        else
            OPLog("[ObjectPlacer] SERVER ERROR: Failed to decode saved_objects.json or it's not a table. Content: " .. tostring(fileContent))
            savedObjects = {}
        end
    else
        OPLog("[ObjectPlacer] SERVER INFO: saved_objects.json not found or empty. Starting with no saved objects.")
        savedObjects = {}
    end
end

-- Load osadmin data from JSON file (supports both old and new formats)
local function LoadOsAdminFromFile()
    local fileContent = LoadResourceFile(GetCurrentResourceName(), "osadmin.json")
    if fileContent and fileContent ~= "" then
        local success, decodedData = pcall(json.decode, fileContent)
        if success and type(decodedData) == "table" then
            -- Check if this is the new readable format
            if decodedData.userManagement then
                OPLog("[ObjectPlacer] SERVER INFO: Loading new format osadmin.json")
                osAdminData = {
                    userManagement = decodedData.userManagement,
                    admins = decodedData.admins or {}, -- Keep legacy for compatibility
                    settings = decodedData.settings or {},
                    version = decodedData.version or "2.2.0",
                    last_updated = decodedData.last_updated
                }
            else
                -- Old format - migrate to new structure
                OPLog("[ObjectPlacer] SERVER INFO: Migrating old format osadmin.json to new structure")
                osAdminData = decodedData
                if not osAdminData.userManagement then
                    osAdminData.userManagement = {
                        users = {},
                        settings = {
                            autoPromoteFirstUser = Config.UserManagement.autoPromoteFirstUser or false,
                            requireApproval = Config.UserManagement.requireApproval or false
                        }
                    }
                    DebugPrint("USER", string.format("UserManagement initialized from config - AutoPromote: %s", tostring(Config.UserManagement.autoPromoteFirstUser)))
                end
            end
        else
            OPLog("[ObjectPlacer] SERVER ERROR: Failed to decode osadmin.json or it's not a table.")
            
            osAdminData = {
                userManagement = {
                    users = {},
                    settings = {
                        autoPromoteFirstUser = Config.UserManagement.autoPromoteFirstUser or false,
                        requireApproval = Config.UserManagement.requireApproval or false
                    }
                },
                admins = {},
                settings = {},
                version = "2.2.0",
                last_updated = os.date("%Y-%m-%d %H:%M:%S")
            }
            DebugPrint("USER", string.format("UserManagement created from config - AutoPromote: %s", tostring(Config.UserManagement.autoPromoteFirstUser)))
        end
    else
        OPLog("[ObjectPlacer] SERVER INFO: osadmin.json not found. Creating default structure with example owner.")
        
        osAdminData = {
            userManagement = {
                users = {},
                settings = {
                    autoPromoteFirstUser = Config.UserManagement.autoPromoteFirstUser or false,
                    requireApproval = Config.UserManagement.requireApproval or false
                }
            },
            admins = {},
            settings = {},
            version = "2.10",
            last_updated = os.date("%Y-%m-%d %H:%M:%S")
        }
        DebugPrint("USER", string.format("New osadmin.json created from config - AutoPromote: %s", tostring(Config.UserManagement.autoPromoteFirstUser)))
        -- Save the default structure immediately
        SaveOsAdminToFile()
    end
end

local function IsInTestZone(coords)
    if not Config.TestZone.enabled then return false end
    if not coords then return false end
    local dx = coords.x - (Config.TestZone.center.x or 0.0)
    local dy = coords.y - (Config.TestZone.center.y or 0.0)
    local dz = coords.z - (Config.TestZone.center.z or 0.0)
    local distSq = dx*dx + dy*dy + dz*dz
    return distSq <= (Config.TestZone.radius or 0.0)^2
end

local function TrackPlayerObjects(src, objects)
    if not Config.TestZone.enabled or not Config.TestZone.cleanupOnDisconnect then return end
    if type(objects) ~= "table" then return end
    playerPlacedObjects[src] = {}
    for _, obj in ipairs(objects) do
        table.insert(playerPlacedObjects[src], obj)
    end
end

-- ================================
-- TESTZONE AUTO-CLEANUP SYSTEM
-- ================================

-- Enhanced player disconnect handler for TestZone cleanup
AddEventHandler('playerDropped', function(reason)
    local src = source
    local playerName = GetPlayerName(src)
    
    dbg(string.format("Player %s disconnected (reason: %s)", playerName, reason))
    
    -- TestZone auto-cleanup
    if Config.TestZone.enabled and Config.TestZone.cleanupOnDisconnect and playerPlacedObjects[src] then
        local objectsToDelete = playerPlacedObjects[src]
        local deletedCount = 0
        
        dbg(string.format("🧹 TestZone cleanup: Removing %d objects from %s", #objectsToDelete, playerName))
        
        -- Remove objects from savedObjects by persistent ID (with coordinate fallback)
        local deletedIds = {}
        for i = #savedObjects, 1, -1 do
            local obj = savedObjects[i]
            for _, playerObj in ipairs(objectsToDelete) do
                local matched = false
                if obj.id and playerObj.id and obj.id == playerObj.id then
                    matched = true
                elseif obj.coords and playerObj.coords and 
                   math.abs(obj.coords.x - playerObj.coords.x) < 0.1 and
                   math.abs(obj.coords.y - playerObj.coords.y) < 0.1 and
                   math.abs(obj.coords.z - playerObj.coords.z) < 0.1 then
                    matched = true
                end
                
                if matched then
                    if obj.id then
                        table.insert(deletedIds, obj.id)
                    end
                    table.remove(savedObjects, i)
                    deletedCount = deletedCount + 1
                    break
                end
            end
        end
        
        -- Save updated objects to file and broadcast delta delete (no global reload!)
        if deletedCount > 0 then
            local saveOk, saveErr = SaveObjectsToFile()
            if saveOk then
                objectStateRevision = objectStateRevision + 1
                dbg(string.format("🧹 TestZone cleanup complete: Deleted %d/%d objects from %s (Revision %d)", 
                    deletedCount, #objectsToDelete, playerName, objectStateRevision))
                
                -- Broadcast delta delete to all clients instead of full reload
                TriggerClientEvent('bazq-objectplace:objectsBatchDeleted', -1, {
                    revision = objectStateRevision,
                    ids = deletedIds
                })
            else
                dbg("TestZone cleanup persistence failed: " .. tostring(saveErr))
            end
        end
    end
    
    -- Clear player tracking unconditionally to prevent memory leaks
    if playerPlacedObjects[src] then
        playerPlacedObjects[src] = nil
    end
end)



-- When a new player joins, send them the authoritative snapshot of saved objects
AddEventHandler('playerJoining', function(source)
    -- Small delay to ensure client is ready
    Citizen.SetTimeout(5000, function()
        if GetPlayerName(source) then -- Check if player is still connected
            TriggerClientEvent("bazq-objectplace:loadObjects", source, {
                revision = objectStateRevision,
                objects = savedObjects
            })
            OPLog("[ObjectPlacer] SERVER: Sent " .. #savedObjects .. " saved objects to new player: " .. GetPlayerName(source) .. " (Revision: " .. objectStateRevision .. ")")
        end
    end)
end)

-- Advanced User Management System
local userManagementData = {
    users = {},
    roles = {"owner", "admin", "mapper"},
    permissions = {
        owner = {"spawn", "delete", "edit", "save", "user_management", "all_actions"}, -- Can do everything
        admin = {"spawn", "delete", "edit", "save", "user_management"}, -- Can manage users (except owners)
        mapper = {"spawn", "delete", "edit", "save"} -- Can use spawner but NOT manage users
    }
}

-- Initialize default users if none exist
local function InitializeDefaultUsers()
    if not osAdminData.userManagement then
        -- Get default values from config
        local configAutoPromote = Config.UserManagement and Config.UserManagement.autoPromoteFirstUser or false
        local configRequireApproval = Config.UserManagement and Config.UserManagement.requireApproval or false
        
        osAdminData.userManagement = {
            users = {},
            settings = {
                autoPromoteFirstUser = configAutoPromote,
                requireApproval = configRequireApproval
            }
        }
        DebugPrint("USER", string.format("InitializeDefaultUsers - AutoPromote from config: %s", tostring(configAutoPromote)))
        SaveOsAdminToFile()
    end
    
    userManagementData.users = osAdminData.userManagement.users or {}
end

-- Get player identifier (checks all identifiers against registered users first, then fallbacks to steam/fivem/license)
local function GetPlayerPrimaryIdentifier(src)
    local identifiers = GetPlayerIdentifiers(src)
    
    -- First, check if ANY of the player's identifiers match a registered user in osadmin.json
    if userManagementData and userManagementData.users then
        for _, identifier in ipairs(identifiers) do
            for _, user in pairs(userManagementData.users) do
                if user.identifier == identifier then
                    return identifier -- Return the exact identifier that is registered
                end
            end
        end
    end
    
    -- Fallbacks for non-registered users (to display in UI or default auto-promotion)
    -- Check for steam identifier first (highest priority)
    for _, identifier in ipairs(identifiers) do
        if string.sub(identifier, 1, 6) == "steam:" then
            return identifier
        end
    end
    
    -- Check for fivem identifier second
    for _, identifier in ipairs(identifiers) do
        if string.sub(identifier, 1, string.len("fivem:")) == "fivem:" then
            return identifier
        end
    end
    
    -- Check for license identifier last (fallback)
    for _, identifier in ipairs(identifiers) do
        if string.sub(identifier, 1, 8) == "license:" then
            return identifier
        end
    end
    
    return identifiers[1] or nil
end

-- Get user role by identifier
local function GetUserRole(identifier)
    if not identifier then return "guest" end
    
    for _, user in pairs(userManagementData.users) do
        if user.identifier == identifier then
            return user.role
        end
    end
    
    local userCount = 0
    if type(userManagementData.users) == "table" then
        for _ in pairs(userManagementData.users) do
            userCount = userCount + 1
        end
    end

    -- Auto-promote first user to owner if setting is enabled AND no users exist
    if osAdminData.userManagement.settings.autoPromoteFirstUser and userCount == 0 then
        local playerName = "First User"
        for _, playerId in ipairs(GetPlayers()) do
            if GetPlayerPrimaryIdentifier(tonumber(playerId)) == identifier then
                playerName = GetPlayerName(tonumber(playerId)) or "First User"
                break
            end
        end

        local newUser = {
            identifier = identifier,
            displayName = playerName,
            role = "owner",
            addedBy = "system",
            dateAdded = os.date("%Y-%m-%d %H:%M:%S")
        }
        
        if type(userManagementData.users) ~= "table" then
            userManagementData.users = {}
        end
        table.insert(userManagementData.users, newUser)
        osAdminData.userManagement.users = userManagementData.users
        SaveOsAdminToFile()
        
        DebugLog("USER", "Auto-promoted first user to owner: " .. identifier)
        return "owner"
    end
    
    -- 🧪 TESTZONE DEBUG: Force guest role if autoPromoteFirstUser is disabled
    if not osAdminData.userManagement.settings.autoPromoteFirstUser then
        DebugPrint("USER", string.format("AutoPromote disabled - User %s will be guest", identifier))
    end
    
    return "guest"
end

-- Legacy admin check function (kept for compatibility)
local function IsPlayerAdmin(src)
    local identifier = GetPlayerPrimaryIdentifier(src)
    local role = GetUserRole(identifier)
    
    -- Check new user management system first - all roles (owner, admin, mapper) can access object spawner
    if role == "owner" or role == "admin" or role == "mapper" then
        return true
    end
    
    -- Fallback to ACE permissions
    if IsPlayerAceAllowed(src, "command") or
       IsPlayerAceAllowed(src, "admin") or
       IsPlayerAceAllowed(src, "bazq.admin") or
       IsPlayerAceAllowed(src, "objectplacer.admin") then
        return true
    end
    
    return false
end

-- Check if player has permission
local function HasPermission(src, permission)
    local identifier = GetPlayerPrimaryIdentifier(src)
    local role = GetUserRole(identifier)
    
    -- Check if role has the specific permission
    if userManagementData.permissions[role] then
        for _, perm in ipairs(userManagementData.permissions[role]) do
            if perm == permission or perm == "all_actions" then
                return true
            end
        end
    end
    
    -- Legacy admin check for backwards compatibility
    if permission == "admin" then
        return IsPlayerAdmin(src)
    end
    
    return false
end

-- ================================
-- TESTZONE F7 PERMISSION HANDLER
-- ================================

-- Handle F7 permission check from client
RegisterNetEvent('bazq-objectplace:checkF7Permission')
AddEventHandler('bazq-objectplace:checkF7Permission', function()
    local src = source
    local identifier = GetPlayerPrimaryIdentifier(src)
    local role = GetUserRole(identifier)
    
    -- Check if player has server-side permissions
    local hasPermission = (role and (role == "admin" or role == "owner" or role == "mapper"))
    
    DebugPrint("USER", string.format("F7 permission check for %s (role: %s) - %s", 
        GetPlayerName(src), role or "none", hasPermission and "GRANTED" or "DENIED"))
    
    -- Send response back to client
    TriggerClientEvent('bazq-objectplace:f7PermissionResponse', src, hasPermission)
end)

-- Event: Client checks F6 freecam permission (separate from F7 to avoid menu opening)
RegisterNetEvent("bazq-objectplace:checkF6Permission")
AddEventHandler("bazq-objectplace:checkF6Permission", function()
    local src = source
    local playerName = GetPlayerName(src) or "Unknown"
    local identifier = GetPlayerPrimaryIdentifier(src)
    local role = GetUserRole(identifier)
    
    -- Owner lock check
    local lockActive = (osAdminData.settings and osAdminData.settings.lockNonOwners == true)
    if lockActive and role ~= "owner" then
        OPLog("[ObjectPlacer] SERVER: F6 freecam access DENIED to " .. playerName .. " - Spawner currently locked by Owner")
        TriggerClientEvent("bazq-objectplace:f6PermissionResponse", src, false)
        return
    end
    
    -- Check if player has freecam permissions (same logic as F7 but simpler response)
    local hasPermission = false
    
    -- Test zone override: allow any user within the configured zone
    local inZone = false
    if Config.TestZone and Config.TestZone.enabled then
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then
            local coords = GetEntityCoords(ped)
            inZone = IsInTestZone({ x = coords.x, y = coords.y, z = coords.z })
        end
    end
    
    -- Grant permission if user has role OR is in test zone
    if role ~= "guest" or inZone then
        hasPermission = true
        local reason = inZone and "TestZone" or role
        OPLog("[ObjectPlacer] SERVER: F6 freecam access GRANTED to " .. playerName .. " (Reason: " .. reason .. ")")
    else
        OPLog("[ObjectPlacer] SERVER: F6 freecam access DENIED to " .. playerName .. " - No permissions found (Role: guest)")
    end
    
    DebugPrint("USER", string.format("F6 freecam permission check for %s (role: %s) - %s", 
        GetPlayerName(src), role or "none", hasPermission and "GRANTED" or "DENIED"))
    
    -- Send simple boolean response back to client (no menu opening)
    TriggerClientEvent('bazq-objectplace:f6PermissionResponse', src, hasPermission)
end)

-- User Management Event Handlers
RegisterNetEvent("bazq-objectplace:getUserList")
AddEventHandler("bazq-objectplace:getUserList", function()
    local src = source
    local identifier = GetPlayerPrimaryIdentifier(src)
    local role = GetUserRole(identifier)
    
    if not HasPermission(src, "user_management") then
        DebugLog("USER", "Access denied to " .. GetPlayerName(src) .. " - insufficient permissions")
        return
    end
    
    TriggerClientEvent("bazq-objectplace:userListResponse", src, {
        success = true,
        users = userManagementData.users,
        currentUserRole = role,
        currentUserIdentifier = identifier
    })
end)

RegisterNetEvent("bazq-objectplace:getOnlinePlayers")
AddEventHandler("bazq-objectplace:getOnlinePlayers", function()
    local src = source
    if not HasPermission(src, "user_management") then
        return
    end
    
    local playersInfo = {}
    local srcPed = GetPlayerPed(src)
    local srcCoords = GetEntityCoords(srcPed)
    
    for _, playerIdStr in ipairs(GetPlayers()) do
        local playerId = tonumber(playerIdStr)
        if playerId ~= src then
            local pPed = GetPlayerPed(playerId)
            local pCoords = GetEntityCoords(pPed)
            local dist = -1.0
            if srcCoords and pCoords then
                -- calculate 3d distance
                local dx = srcCoords.x - pCoords.x
                local dy = srcCoords.y - pCoords.y
                local dz = srcCoords.z - pCoords.z
                dist = math.sqrt(dx*dx + dy*dy + dz*dz)
            end
            
            table.insert(playersInfo, {
                id = playerId,
                name = GetPlayerName(playerId),
                identifier = GetPlayerPrimaryIdentifier(playerId) or ("unknown:".. playerId),
                distance = dist
            })
        end
    end
    
    TriggerClientEvent("bazq-objectplace:onlinePlayersResponse", src, playersInfo)
end)

RegisterNetEvent("bazq-objectplace:addUser")
AddEventHandler("bazq-objectplace:addUser", function(userData)
    local src = source
    local adminIdentifier = GetPlayerPrimaryIdentifier(src)
    local adminRole = GetUserRole(adminIdentifier)
    
    if not HasPermission(src, "user_management") then
        TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
            success = false,
            message = "Access denied - insufficient permissions"
        })
        return
    end
    
    -- Validate input
    if not userData.identifier or not userData.displayName or not userData.role then
        TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
            success = false,
            message = "Missing required fields"
        })
        return
    end
    
    -- Check if user already exists
    for _, user in pairs(userManagementData.users) do
        if user.identifier == userData.identifier then
            TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
                success = false,
                message = "User with this identifier already exists"
            })
            return
        end
    end
    
    -- Check role permissions (only owners can create owners)
    if userData.role == "owner" and adminRole ~= "owner" then
        TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
            success = false,
            message = "Only owners can create other owners"
        })
        return
    end
    
    -- Add the user
    local newUser = {
        identifier = userData.identifier,
        displayName = userData.displayName,
        role = userData.role,
        addedBy = adminIdentifier,
        dateAdded = os.date("%Y-%m-%d %H:%M:%S")
    }
    
    table.insert(userManagementData.users, newUser)
    osAdminData.userManagement.users = userManagementData.users
    SaveOsAdminToFile()
    
    DebugLog("USER", "User added: " .. userData.displayName .. " (" .. userData.identifier .. ") as " .. userData.role .. " by " .. GetPlayerName(src))
    
    TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
        success = true,
        message = "User added successfully"
    })
end)

RegisterNetEvent("bazq-objectplace:updateUserRole")
AddEventHandler("bazq-objectplace:updateUserRole", function(data)
    local src = source
    local adminIdentifier = GetPlayerPrimaryIdentifier(src)
    local adminRole = GetUserRole(adminIdentifier)
    
    if not HasPermission(src, "user_management") then
        TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
            success = false,
            message = "Access denied - insufficient permissions"
        })
        return
    end
    
    -- Find the user
    local targetUser = nil
    local targetIndex = nil
    
    for i, user in ipairs(userManagementData.users) do
        if user.identifier == data.identifier then
            targetUser = user
            targetIndex = i
            break
        end
    end
    
    if not targetUser then
        TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
            success = false,
            message = "User not found"
        })
        return
    end
    
    -- Check permission hierarchy for role updates
    -- Prevent self-role changes that could cause lockout
    if targetUser.identifier == adminIdentifier then
        TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
            success = false,
            message = "Cannot modify your own role"
        })
        return
    end
    
    -- Owners can modify anyone (except themselves)
    if adminRole == "owner" then
        -- Allow owners to change any role
    elseif adminRole == "admin" then
        -- Admins can only modify mappers
        if targetUser.role ~= "mapper" then
            TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
                success = false,
                message = "Admins can only modify mappers"
            })
            return
        end
    else
        -- Mappers cannot modify anyone
        TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
            success = false,
            message = "Insufficient permissions to modify users"
        })
        return
    end
    
    -- Only owners can create owners
    if data.newRole == "owner" and adminRole ~= "owner" then
        TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
            success = false,
            message = "Only owners can promote users to owner"
        })
        return
    end
    
    -- Update the role
    local oldRole = targetUser.role
    userManagementData.users[targetIndex].role = data.newRole
    userManagementData.users[targetIndex].lastModified = os.date("%Y-%m-%d %H:%M:%S")
    userManagementData.users[targetIndex].lastModifiedBy = adminIdentifier
    
    osAdminData.userManagement.users = userManagementData.users
    SaveOsAdminToFile()
    
    DebugLog("USER", "Role updated: " .. targetUser.displayName .. " from " .. oldRole .. " to " .. data.newRole .. " by " .. GetPlayerName(src))
    
    TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
        success = true,
        message = "User role updated successfully"
    })
end)

RegisterNetEvent("bazq-objectplace:updateUser")
AddEventHandler("bazq-objectplace:updateUser", function(originalIdentifier, newDisplayName, newIdentifier, newRole)
    local src = source
    local adminIdentifier = GetPlayerPrimaryIdentifier(src)
    local adminRole = GetUserRole(adminIdentifier)
    
    -- Check permissions
    if not adminRole or (adminRole ~= "admin" and adminRole ~= "owner") then
        DebugLog("USER", "Update denied - " .. GetPlayerName(src) .. " (role: " .. (adminRole or "none") .. ") attempted to update user " .. originalIdentifier)
        TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
            success = false,
            message = "Access denied. Admin or Owner role required."
        })
        return
    end
    
    -- Validate inputs
    if not originalIdentifier or not newDisplayName or not newIdentifier or not newRole then
        TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
            success = false,
            message = "Missing required fields"
        })
        return
    end
    
    -- Load current users
    local users = userManagementData.users
    if not users then
        TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
            success = false,
            message = "Failed to load user database"
        })
        return
    end
    
    -- Find the user to update
    local userIndex = nil
    for i, user in ipairs(users) do
        if user.identifier == originalIdentifier then
            userIndex = i
            break
        end
    end
    
    if not userIndex then
        TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
            success = false,
            message = "User not found"
        })
        return
    end
    
    local currentUser = users[userIndex]
    
    -- Check if admin can modify this user's role
    if newRole ~= currentUser.role then
        local function CanModify(aRole, tRole)
            if aRole == "owner" then return true end
            if aRole == "admin" and tRole == "mapper" then return true end
            return false
        end

        if not CanModify(adminRole, currentUser.role) or not CanModify(adminRole, newRole) then
            TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
                success = false,
                message = "You cannot modify this user's role or assign the requested role"
            })
            return
        end
    end
    
    -- Check if new identifier already exists (if changed)
    if newIdentifier ~= originalIdentifier then
        for _, user in ipairs(users) do
            if user.identifier == newIdentifier then
                TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
                    success = false,
                    message = "A user with this identifier already exists"
                })
                return
            end
        end
    end
    
    -- Update the user
    users[userIndex].identifier = newIdentifier
    users[userIndex].displayName = newDisplayName
    users[userIndex].role = newRole
    users[userIndex].lastModified = os.date("%Y-%m-%d %H:%M:%S")
    users[userIndex].lastModifiedBy = adminIdentifier
    
    -- Save to file
    osAdminData.userManagement.users = users
    SaveOsAdminToFile()
    local success = true
    if success then
        DebugLog("USER", "User updated: " .. originalIdentifier .. " → " .. newDisplayName .. " (" .. newIdentifier .. ", " .. newRole .. ") by " .. GetPlayerName(src))
        
        -- Broadcast updated user list to all admins
        for _, playerId in ipairs(GetPlayers()) do
            local playerIdentifier = GetPlayerPrimaryIdentifier(tonumber(playerId))
            local playerRole = GetUserRole(playerIdentifier)
            if playerRole and (playerRole == "admin" or playerRole == "owner") then
                TriggerClientEvent("bazq-objectplace:userListResponse", tonumber(playerId), {
                    success = true,
                    users = users,
                    currentUserRole = playerRole
                })
            end
        end
        
        TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
            success = true,
            message = "User updated successfully"
        })
    else
        TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
            success = false,
            message = "Failed to save user database"
        })
    end
end)

RegisterNetEvent("bazq-objectplace:deleteUser")
AddEventHandler("bazq-objectplace:deleteUser", function(data)
    local src = source
    local adminIdentifier = GetPlayerPrimaryIdentifier(src)
    local adminRole = GetUserRole(adminIdentifier)
    
    if not HasPermission(src, "user_management") then
        TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
            success = false,
            message = "Access denied - insufficient permissions"
        })
        return
    end
    
    -- Find the user
    local targetUser = nil
    local targetIndex = nil
    
    for i, user in ipairs(userManagementData.users) do
        if user.identifier == data.identifier then
            targetUser = user
            targetIndex = i
            break
        end
    end
    
    if not targetUser then
        TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
            success = false,
            message = "User not found"
        })
        return
    end
    
    -- Check permission hierarchy for deletion
    -- Prevent self-deletion to avoid lockout
    if targetUser.identifier == adminIdentifier then
        TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
            success = false,
            message = "Cannot delete yourself - this would cause lockout"
        })
        return
    end
    
    -- Owners can delete anyone (except themselves)
    if adminRole == "owner" then
        -- Allow owners to delete any user
    elseif adminRole == "admin" then
        -- Admins can only delete mappers
        if targetUser.role ~= "mapper" then
            TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
                success = false,
                message = "Admins can only delete mappers"
            })
            return
        end
    else
        -- Mappers cannot delete anyone
        TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
            success = false,
            message = "Insufficient permissions to delete users"
        })
        return
    end
    
    -- Remove the user
    local deletedUser = table.remove(userManagementData.users, targetIndex)
    osAdminData.userManagement.users = userManagementData.users
    SaveOsAdminToFile()
    
    DebugLog("USER", "User deleted: " .. deletedUser.displayName .. " (" .. deletedUser.identifier .. ") by " .. GetPlayerName(src))
    
    TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
        success = true,
        message = "User deleted successfully"
    })
end)

RegisterNetEvent("bazq-objectplace:clearAllMappers")
AddEventHandler("bazq-objectplace:clearAllMappers", function()
    local src = source
    
    if not HasPermission(src, "user_management") then
        TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
            success = false,
            message = "Access denied - insufficient permissions"
        })
        return
    end
    
    -- Remove all mappers
    local mappersRemoved = 0
    for i = #userManagementData.users, 1, -1 do
        if userManagementData.users[i].role == "mapper" then
            table.remove(userManagementData.users, i)
            mappersRemoved = mappersRemoved + 1
        end
    end
    
    osAdminData.userManagement.users = userManagementData.users
    SaveOsAdminToFile()
    
    DebugLog("USER", "Cleared " .. mappersRemoved .. " mapper(s) by " .. GetPlayerName(src))
    
    TriggerClientEvent("bazq-objectplace:userActionResponse", src, {
        success = true,
        message = "Cleared " .. mappersRemoved .. " mapper(s)"
    })
end)

-- ============================================
-- AUTHORITATIVE SERVER PAYLOAD VALIDATION
-- ============================================

local function ValidateId(id)
    return type(id) == "string" and string.len(id) >= 5 and string.len(id) <= 64 and string.match(id, "^[a-zA-Z0-9_%-]+$") ~= nil
end

local function ValidateModel(model)
    return type(model) == "string" and string.len(model) >= 1 and string.len(model) <= 64
end

local function ValidateFiniteNumber(n, minVal, maxVal)
    if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then
        return false
    end
    if minVal and n < minVal then return false end
    if maxVal and n > maxVal then return false end
    return true
end

local function ValidateCoords(coords)
    if type(coords) ~= "table" then return false end
    local x = tonumber(coords.x)
    local y = tonumber(coords.y)
    local z = tonumber(coords.z)
    if not (ValidateFiniteNumber(x, -10000.0, 10000.0) and
            ValidateFiniteNumber(y, -10000.0, 10000.0) and
            ValidateFiniteNumber(z, -2000.0, 10000.0)) then
        return false
    end
    return true
end

local function ValidateHeading(h)
    return ValidateFiniteNumber(tonumber(h), -3600.0, 3600.0)
end

local function ValidateRotation(rot)
    if rot == nil then return true end
    if type(rot) ~= "table" then return false end
    local rx = tonumber(rot.x)
    local ry = tonumber(rot.y)
    local rz = tonumber(rot.z)
    return ValidateFiniteNumber(rx, -3600.0, 3600.0) and
           ValidateFiniteNumber(ry, -3600.0, 3600.0) and
           ValidateFiniteNumber(rz, -3600.0, 3600.0)
end

local function ValidateMetadataString(s, maxLen)
    if s == nil then return true end
    maxLen = maxLen or 64
    return type(s) == "string" and string.len(s) <= maxLen
end

-- ============================================
-- AUTHORITATIVE GRANULAR MUTATION HANDLERS
-- ============================================

-- CREATE: placeObject
RegisterNetEvent("bazq-objectplace:placeObject")
AddEventHandler("bazq-objectplace:placeObject", function(payload)
    local src = source
    local playerName = GetPlayerName(src) or "Unknown"
    
    if not (HasPermission(src, "save") or HasPermission(src, "spawn")) then
        OPLog("[ObjectPlacer] SERVER: placeObject denied to " .. playerName .. " - insufficient permissions")
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "placeObject",
            reason = "Insufficient permissions to place objects",
            requestId = type(payload) == "table" and payload.requestId or nil
        })
        return
    end
    
    if type(payload) ~= "table" then
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "placeObject",
            reason = "Malformed payload: table expected"
        })
        return
    end
    
    if not ValidateModel(payload.model) then
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "placeObject",
            reason = "Invalid or empty prop model name",
            requestId = payload.requestId
        })
        return
    end
    
    if not ValidateCoords(payload.coords) then
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "placeObject",
            reason = "Invalid coordinates (out of bounds or NaN/Inf)",
            requestId = payload.requestId
        })
        return
    end
    
    local headingVal = 0.0
    if payload.heading ~= nil then
        if not ValidateHeading(payload.heading) then
            TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
                action = "placeObject",
                reason = "Invalid heading value",
                requestId = payload.requestId
            })
            return
        end
        headingVal = tonumber(payload.heading)
    end
    
    if payload.rotation ~= nil and not ValidateRotation(payload.rotation) then
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "placeObject",
            reason = "Invalid rotation table",
            requestId = payload.requestId
        })
        return
    end
    
    if not ValidateMetadataString(payload.interiorModel, 64) or
       not ValidateMetadataString(payload.displayName, 64) or
       not ValidateMetadataString(payload.name, 64) then
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "placeObject",
            reason = "Metadata string exceeds maximum length",
            requestId = payload.requestId
        })
        return
    end
    
    -- Generate server-authoritative unique ID
    local knownIds = {}
    for _, existing in ipairs(savedObjects) do
        if type(existing) == "table" and type(existing.id) == "string" and existing.id ~= "" then
            knownIds[existing.id] = true
        end
    end
    local authoritativeId = GenerateUniqueObjectId(knownIds)
    
    local rotVal = nil
    if payload.rotation then
        rotVal = {
            x = tonumber(payload.rotation.x) or 0.0,
            y = tonumber(payload.rotation.y) or 0.0,
            z = tonumber(payload.rotation.z) or 0.0
        }
    end
    
    local newRecord = {
        id = authoritativeId,
        model = payload.model,
        coords = {
            x = tonumber(payload.coords.x),
            y = tonumber(payload.coords.y),
            z = tonumber(payload.coords.z)
        },
        heading = headingVal,
        rotation = rotVal,
        interiorModel = payload.interiorModel,
        hasDualDoors = payload.hasDualDoors and true or nil,
        displayName = payload.displayName or payload.name,
        playerName = playerName,
        timestamp = os.date("%Y-%m-%d %H:%M:%S")
    }
    
    table.insert(savedObjects, newRecord)
    
    local saveOk, saveErr = SaveObjectsToFile()
    if saveOk then
        objectStateRevision = objectStateRevision + 1
        if Config.TestZone.enabled then
            TrackPlayerObjects(src, { newRecord })
        end
        TriggerClientEvent("bazq-objectplace:objectCreated", -1, {
            revision = objectStateRevision,
            object = newRecord,
            requestId = payload.requestId
        })
        dbg(string.format("placeObject success: ID=%s, Model=%s by %s (Revision %d)", authoritativeId, newRecord.model, playerName, objectStateRevision))
    else
        table.remove(savedObjects, #savedObjects)
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "placeObject",
            reason = "Persistence error: " .. tostring(saveErr),
            requestId = payload.requestId
        })
    end
end)

-- UPDATE: updateObject
RegisterNetEvent("bazq-objectplace:updateObject")
AddEventHandler("bazq-objectplace:updateObject", function(payload)
    local src = source
    local playerName = GetPlayerName(src) or "Unknown"
    
    if not (HasPermission(src, "save") or HasPermission(src, "edit")) then
        OPLog("[ObjectPlacer] SERVER: updateObject denied to " .. playerName .. " - insufficient permissions")
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "updateObject",
            reason = "Insufficient permissions to edit objects",
            requestId = type(payload) == "table" and payload.requestId or nil
        })
        return
    end
    
    if type(payload) ~= "table" or not ValidateId(payload.id) then
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "updateObject",
            reason = "Invalid or missing object ID",
            requestId = type(payload) == "table" and payload.requestId or nil
        })
        return
    end
    
    if type(payload.changes) ~= "table" then
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "updateObject",
            reason = "Missing changes table",
            requestId = payload.requestId
        })
        return
    end
    
    local existingObj, idx = GetObjectById(payload.id)
    if not existingObj then
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "updateObject",
            reason = "Object not found with ID: " .. tostring(payload.id),
            requestId = payload.requestId
        })
        return
    end
    
    local changes = payload.changes
    
    -- Validate allowed fields in changes
    if changes.coords ~= nil and not ValidateCoords(changes.coords) then
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "updateObject",
            reason = "Invalid coordinates in changes",
            requestId = payload.requestId
        })
        return
    end
    
    if changes.heading ~= nil and not ValidateHeading(changes.heading) then
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "updateObject",
            reason = "Invalid heading in changes",
            requestId = payload.requestId
        })
        return
    end
    
    if changes.rotation ~= nil and not ValidateRotation(changes.rotation) then
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "updateObject",
            reason = "Invalid rotation in changes",
            requestId = payload.requestId
        })
        return
    end
    
    if changes.model ~= nil and not ValidateModel(changes.model) then
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "updateObject",
            reason = "Invalid model name in changes",
            requestId = payload.requestId
        })
        return
    end
    
    if not ValidateMetadataString(changes.interiorModel, 64) or
       not ValidateMetadataString(changes.displayName, 64) or
       not ValidateMetadataString(changes.name, 64) then
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "updateObject",
            reason = "Metadata string exceeds maximum length in changes",
            requestId = payload.requestId
        })
        return
    end
    
    -- Preserve previous snapshot for atomic rollback
    local previousSnapshot = {}
    for k, v in pairs(existingObj) do
        previousSnapshot[k] = v
    end
    
    -- Apply allowed field mutations (ID remains strictly immutable!)
    if changes.coords ~= nil then
        existingObj.coords = {
            x = tonumber(changes.coords.x),
            y = tonumber(changes.coords.y),
            z = tonumber(changes.coords.z)
        }
    end
    
    if changes.heading ~= nil then
        existingObj.heading = tonumber(changes.heading)
    end
    
    if changes.rotation ~= nil then
        existingObj.rotation = {
            x = tonumber(changes.rotation.x) or 0.0,
            y = tonumber(changes.rotation.y) or 0.0,
            z = tonumber(changes.rotation.z) or 0.0
        }
    end
    
    if changes.model ~= nil then
        existingObj.model = changes.model
    end
    
    if changes.interiorModel ~= nil then
        existingObj.interiorModel = changes.interiorModel
    end
    
    if changes.hasDualDoors ~= nil then
        existingObj.hasDualDoors = changes.hasDualDoors and true or nil
    end
    
    if changes.displayName ~= nil then
        existingObj.displayName = changes.displayName
    elseif changes.name ~= nil then
        existingObj.displayName = changes.name
    end
    
    -- Ensure ID is identical to previous
    existingObj.id = previousSnapshot.id
    
    local saveOk, saveErr = SaveObjectsToFile()
    if saveOk then
        objectStateRevision = objectStateRevision + 1
        TriggerClientEvent("bazq-objectplace:objectUpdated", -1, {
            revision = objectStateRevision,
            object = existingObj,
            requestId = payload.requestId
        })
        dbg(string.format("updateObject success: ID=%s by %s (Revision %d)", existingObj.id, playerName, objectStateRevision))
    else
        -- Rollback in-memory state
        savedObjects[idx] = previousSnapshot
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "updateObject",
            reason = "Persistence error: " .. tostring(saveErr),
            requestId = payload.requestId
        })
    end
end)

-- DELETE: deleteObject
RegisterNetEvent("bazq-objectplace:deleteObject")
AddEventHandler("bazq-objectplace:deleteObject", function(payload)
    local src = source
    local playerName = GetPlayerName(src) or "Unknown"
    
    if not (HasPermission(src, "save") or HasPermission(src, "delete")) then
        OPLog("[ObjectPlacer] SERVER: deleteObject denied to " .. playerName .. " - insufficient permissions")
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "deleteObject",
            reason = "Insufficient permissions to delete objects",
            requestId = type(payload) == "table" and payload.requestId or nil
        })
        return
    end
    
    local targetId = type(payload) == "table" and payload.id or payload
    if not ValidateId(targetId) then
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "deleteObject",
            reason = "Invalid object ID",
            requestId = type(payload) == "table" and payload.requestId or nil
        })
        return
    end
    
    local existingObj, idx = GetObjectById(targetId)
    if not existingObj then
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "deleteObject",
            reason = "Object not found with ID: " .. tostring(targetId),
            requestId = type(payload) == "table" and payload.requestId or nil
        })
        return
    end
    
    table.remove(savedObjects, idx)
    
    local saveOk, saveErr = SaveObjectsToFile()
    if saveOk then
        objectStateRevision = objectStateRevision + 1
        TriggerClientEvent("bazq-objectplace:objectDeleted", -1, {
            revision = objectStateRevision,
            id = targetId,
            requestId = type(payload) == "table" and payload.requestId or nil
        })
        dbg(string.format("deleteObject success: ID=%s by %s (Revision %d)", targetId, playerName, objectStateRevision))
    else
        -- Rollback in-memory removal
        table.insert(savedObjects, idx, existingObj)
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "deleteObject",
            reason = "Persistence error: " .. tostring(saveErr),
            requestId = type(payload) == "table" and payload.requestId or nil
        })
    end
end)

-- BATCH CREATE: batchPlaceObjects
RegisterNetEvent("bazq-objectplace:batchPlaceObjects")
AddEventHandler("bazq-objectplace:batchPlaceObjects", function(payload)
    local src = source
    local playerName = GetPlayerName(src) or "Unknown"
    
    if not (HasPermission(src, "save") or HasPermission(src, "spawn")) then
        OPLog("[ObjectPlacer] SERVER: batchPlaceObjects denied to " .. playerName .. " - insufficient permissions")
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "batchPlaceObjects",
            reason = "Insufficient permissions for batch placement",
            requestId = type(payload) == "table" and payload.requestId or nil
        })
        return
    end
    
    if type(payload) ~= "table" then
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "batchPlaceObjects",
            reason = "Malformed payload: table expected"
        })
        return
    end
    
    local items = payload.objects or payload
    if type(items) ~= "table" or #items == 0 or #items > 200 then
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "batchPlaceObjects",
            reason = "Batch size must be between 1 and 200 items",
            requestId = payload.requestId
        })
        return
    end
    
    -- Atomic validation: If any item is invalid, reject the entire batch!
    for i, item in ipairs(items) do
        if type(item) ~= "table" or not ValidateModel(item.model) or not ValidateCoords(item.coords) then
            TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
                action = "batchPlaceObjects",
                reason = string.format("Batch item %d is invalid: atomic rejection", i),
                requestId = payload.requestId
            })
            return
        end
        if item.heading ~= nil and not ValidateHeading(item.heading) then
            TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
                action = "batchPlaceObjects",
                reason = string.format("Batch item %d has invalid heading: atomic rejection", i),
                requestId = payload.requestId
            })
            return
        end
        if item.rotation ~= nil and not ValidateRotation(item.rotation) then
            TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
                action = "batchPlaceObjects",
                reason = string.format("Batch item %d has invalid rotation: atomic rejection", i),
                requestId = payload.requestId
            })
            return
        end
    end
    
    local knownIds = {}
    for _, existing in ipairs(savedObjects) do
        if type(existing) == "table" and type(existing.id) == "string" and existing.id ~= "" then
            knownIds[existing.id] = true
        end
    end
    
    local startIndex = #savedObjects + 1
    local createdBatch = {}
    local timeStr = os.date("%Y-%m-%d %H:%M:%S")
    
    for _, item in ipairs(items) do
        local authoritativeId = GenerateUniqueObjectId(knownIds)
        knownIds[authoritativeId] = true
        
        local rotVal = nil
        if item.rotation then
            rotVal = {
                x = tonumber(item.rotation.x) or 0.0,
                y = tonumber(item.rotation.y) or 0.0,
                z = tonumber(item.rotation.z) or 0.0
            }
        end
        
        local newRecord = {
            id = authoritativeId,
            model = item.model,
            coords = {
                x = tonumber(item.coords.x),
                y = tonumber(item.coords.y),
                z = tonumber(item.coords.z)
            },
            heading = tonumber(item.heading) or 0.0,
            rotation = rotVal,
            interiorModel = item.interiorModel,
            hasDualDoors = item.hasDualDoors and true or nil,
            displayName = item.displayName or item.name,
            playerName = playerName,
            timestamp = timeStr
        }
        table.insert(savedObjects, newRecord)
        table.insert(createdBatch, newRecord)
    end
    
    local saveOk, saveErr = SaveObjectsToFile()
    if saveOk then
        objectStateRevision = objectStateRevision + 1
        if Config.TestZone.enabled then
            TrackPlayerObjects(src, createdBatch)
        end
        TriggerClientEvent("bazq-objectplace:objectsBatchCreated", -1, {
            revision = objectStateRevision,
            objects = createdBatch,
            requestId = payload.requestId
        })
        dbg(string.format("batchPlaceObjects success: %d objects created by %s (Revision %d)", #createdBatch, playerName, objectStateRevision))
    else
        -- Rollback in-memory insertions
        for i = #savedObjects, startIndex, -1 do
            table.remove(savedObjects, i)
        end
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "batchPlaceObjects",
            reason = "Persistence error: " .. tostring(saveErr),
            requestId = payload.requestId
        })
    end
end)

-- BATCH DELETE: deleteObjects
RegisterNetEvent("bazq-objectplace:deleteObjects")
AddEventHandler("bazq-objectplace:deleteObjects", function(payload)
    local src = source
    local playerName = GetPlayerName(src) or "Unknown"
    
    if not (HasPermission(src, "save") or HasPermission(src, "delete")) then
        OPLog("[ObjectPlacer] SERVER: deleteObjects denied to " .. playerName .. " - insufficient permissions")
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "deleteObjects",
            reason = "Insufficient permissions to delete objects",
            requestId = type(payload) == "table" and payload.requestId or nil
        })
        return
    end
    
    local ids = type(payload) == "table" and (payload.ids or payload) or {}
    if type(ids) ~= "table" or #ids == 0 or #ids > 500 then
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "deleteObjects",
            reason = "Invalid batch delete list (must be 1-500 IDs)",
            requestId = type(payload) == "table" and payload.requestId or nil
        })
        return
    end
    
    local idSet = {}
    for _, id in ipairs(ids) do
        if ValidateId(id) then idSet[id] = true end
    end
    
    local removedItems = {}
    local deletedIds = {}
    
    for i = #savedObjects, 1, -1 do
        local obj = savedObjects[i]
        if obj and obj.id and idSet[obj.id] then
            table.insert(removedItems, { index = i, obj = obj })
            table.insert(deletedIds, obj.id)
            table.remove(savedObjects, i)
        end
    end
    
    if #deletedIds == 0 then
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "deleteObjects",
            reason = "None of the specified IDs were found",
            requestId = type(payload) == "table" and payload.requestId or nil
        })
        return
    end
    
    local saveOk, saveErr = SaveObjectsToFile()
    if saveOk then
        objectStateRevision = objectStateRevision + 1
        TriggerClientEvent("bazq-objectplace:objectsBatchDeleted", -1, {
            revision = objectStateRevision,
            ids = deletedIds,
            requestId = type(payload) == "table" and payload.requestId or nil
        })
        dbg(string.format("deleteObjects success: %d objects deleted by %s (Revision %d)", #deletedIds, playerName, objectStateRevision))
    else
        -- Rollback in-memory removals (re-insert in ascending order)
        table.sort(removedItems, function(a, b) return a.index < b.index end)
        for _, item in ipairs(removedItems) do
            table.insert(savedObjects, item.index, item.obj)
        end
        TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
            action = "deleteObjects",
            reason = "Persistence error: " .. tostring(saveErr),
            requestId = type(payload) == "table" and payload.requestId or nil
        })
    end
end)

-- DEPRECATED: Legacy full-array saveObjects event
-- Phase 3 permanently rejects client-authoritative full-array replacement
RegisterNetEvent("bazq-objectplace:saveObjects")
AddEventHandler("bazq-objectplace:saveObjects", function(objectsDataFromClient)
    local src = source
    local playerName = GetPlayerName(src) or "UnknownSource"
    
    OPLog(string.format("[ObjectPlacer] SECURITY ALERT: Client '%s' (src %s) attempted to trigger deprecated full-array 'bazq-objectplace:saveObjects'! Call rejected.", playerName, tostring(src)))
    TriggerClientEvent("bazq-objectplace:mutationFailed", src, {
        action = "saveObjects",
        reason = "Client-authoritative full-array saveObjects is permanently deprecated and disabled in Phase 3. Use granular mutation events."
    })
end)

-- INITIAL / RECOVERY SNAPSHOT: requestObjects & requestFullSnapshot
RegisterNetEvent("bazq-objectplace:requestObjects")
AddEventHandler("bazq-objectplace:requestObjects", function()
    local src = source
    local playerName = GetPlayerName(src) or "Unknown"
    
    local identifier = GetPlayerPrimaryIdentifier(src)
    local role = GetUserRole(identifier)
    
    DebugLoading("Object request from " .. playerName .. " (Role: " .. role .. ", Identifier: " .. tostring(identifier) .. ")")
    DebugLoading("Currently have " .. #savedObjects .. " saved objects to send (Revision " .. objectStateRevision .. ")")
    
    TriggerClientEvent("bazq-objectplace:loadObjects", src, {
        revision = objectStateRevision,
        objects = savedObjects
    })
    DebugLoading("Sent " .. #savedObjects .. " objects to " .. playerName .. " (Role: " .. role .. ")")
end)

RegisterNetEvent("bazq-objectplace:requestFullSnapshot")
AddEventHandler("bazq-objectplace:requestFullSnapshot", function()
    local src = source
    local playerName = GetPlayerName(src) or "Unknown"
    DebugLoading("Full snapshot requested by " .. playerName .. " (src " .. tostring(src) .. ")")
    TriggerClientEvent("bazq-objectplace:loadObjects", src, {
        revision = objectStateRevision,
        objects = savedObjects
    })
end)

-- Get user settings by license (legacy system)
local function GetUserSettings(playerLicense)
    if not osAdminData.admins then return nil end
    
    for _, admin in ipairs(osAdminData.admins) do
        if admin.license == playerLicense then
            return {
                username = admin.username or admin.fivem_name,
                packages = admin.packages or {}
            }
        end
    end
    return nil
end

-- Get user settings based on new user management system
local function GetUserSettingsNew(src)
    local identifier = GetPlayerPrimaryIdentifier(src)
    local playerName = GetPlayerName(src)
    local role = GetUserRole(identifier)
    
    -- Default settings - start with basic package
    local userSettings = {
        username = playerName,
        packages = {"wall_pack_1"}, -- Default: basic wall pack only
        role = role,
        lockNonOwners = (osAdminData.settings and osAdminData.settings.lockNonOwners == true)
    }
    
    -- Check if user exists in new system to get display name
    for _, user in pairs(userManagementData.users) do
        if user.identifier == identifier then
            userSettings.username = user.displayName
            break
        end
    end
    
    return userSettings
end

-- Save user settings by license
local function SaveUserSettings(playerLicense, playerName, username, packages)
    if not osAdminData.admins then osAdminData.admins = {} end
    
    -- Find existing admin or create new one
    local adminIndex = nil
    for i, admin in ipairs(osAdminData.admins) do
        if admin.license == playerLicense then
            adminIndex = i
            break
        end
    end
    
    if adminIndex then
        -- Update existing admin
        osAdminData.admins[adminIndex].username = username
        osAdminData.admins[adminIndex].packages = packages
        osAdminData.admins[adminIndex].fivem_name = playerName
    else
        -- Create new admin entry
        table.insert(osAdminData.admins, {
            username = username,
            license = playerLicense,
            fivem_name = playerName,
            packages = packages,
            permissions = {"spawn", "edit", "delete"},
            added_date = os.date("%Y-%m-%d"),
            notes = "Auto-created user"
        })
    end
    
    SaveOsAdminToFile()
end

-- IsPlayerAdmin function moved up to be available for all functions

-- Event: Client checks admin permission (F7 key access)
RegisterNetEvent("bazq-objectplace:checkAdminPermission")
AddEventHandler("bazq-objectplace:checkAdminPermission", function()
    local src = source
    local playerName = GetPlayerName(src) or "Unknown"
    local identifier = GetPlayerPrimaryIdentifier(src)
    local role = GetUserRole(identifier)
    
    -- Owner lock check
    local lockActive = (osAdminData.settings and osAdminData.settings.lockNonOwners == true)
    if lockActive and role ~= "owner" then
        OPLog("[ObjectPlacer] SERVER: Access DENIED to " .. playerName .. " - Spawner currently locked by Owner")
        TriggerClientEvent("bazq-objectplace:accessDenied", src, {
            error = "ACCESS_DENIED",
            message = "The Object Spawner is currently locked by the owner.",
            details = "Contact the server owner for access."
        })
        return
    end
    
    OPLog("[ObjectPlacer] SERVER: F7 access attempt by " .. playerName .. " (Identifier: " .. tostring(identifier) .. ", Role: " .. role .. ")")

    -- Test zone override: allow any user within the configured zone
    local inZone = false
    if Config.TestZone and Config.TestZone.enabled then
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then
            local coords = GetEntityCoords(ped)
            inZone = IsInTestZone({ x = coords.x, y = coords.y, z = coords.z })
        end
    end

    -- Check if user has ANY role (mapper, admin, or owner) OR is in test zone
    if role ~= "guest" or inZone then
        local reason = inZone and "TestZone" or role
        OPLog("[ObjectPlacer] SERVER: Access GRANTED to " .. playerName .. " (Reason: " .. reason .. ")")
        
        -- Get user settings for the authorized user
        local userSettings = GetUserSettingsNew(src)
        -- If test zone access, keep packages default but mark role as mapper for UI/controls expectations
        if inZone and role == "guest" then
            userSettings.role = "mapper"
        end
        
        -- Check legacy system for saved package preferences
        local playerLicense = nil
        for i = 0, GetNumPlayerIdentifiers(src) - 1 do
            local licenseId = GetPlayerIdentifier(src, i)
            if string.find(licenseId, "license:") then
                playerLicense = licenseId
                break
            end
        end
        
        if playerLicense then
            local legacySettings = GetUserSettings(playerLicense)
            if legacySettings and legacySettings.packages and #legacySettings.packages > 0 then
                -- Use legacy package selection if available
                userSettings.packages = legacySettings.packages
                if legacySettings.username and legacySettings.username ~= "" then
                    userSettings.username = legacySettings.username
                end
            end
        end
        
        OPLog("[ObjectPlacer] SERVER: Sending " .. #userSettings.packages .. " packages to " .. playerName)
        TriggerClientEvent("bazq-objectplace:receiveUserSettings", src, userSettings)
    else
        -- Access denied - user has no permissions
        OPLog("[ObjectPlacer] SERVER: Access DENIED to " .. playerName .. " - No permissions found (Role: guest)")
        TriggerClientEvent("bazq-objectplace:accessDenied", src, {
            error = "ACCESS_DENIED",
            message = "You do not have permission to use bazq-os",
            details = "Contact an administrator to get access. Your identifier: " .. tostring(identifier)
        })
    end
end)

-- Event: Client requests user settings (legacy support)
RegisterNetEvent("bazq-objectplace:requestUserSettings")
AddEventHandler("bazq-objectplace:requestUserSettings", function()
    local src = source
    local playerName = GetPlayerName(src)
    
    -- Check admin permission first
    if not IsPlayerAdmin(src) then
        OPLog("[ObjectPlacer] SERVER: Access denied to " .. playerName .. " - not an admin")
        TriggerClientEvent("bazq-objectplace:accessDenied", src)
        return
    end
    
    local playerLicense = nil
    
    -- Get player license
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local identifier = GetPlayerIdentifier(src, i)
        if string.find(identifier, "license:") then
            playerLicense = identifier
            break
        end
    end
    
    if playerLicense then
        local userSettings = GetUserSettings(playerLicense)
        -- If no username is set, use the player's FiveM name
        if not userSettings then
            userSettings = {
                username = playerName,
                packages = {}
            }
        elseif not userSettings.username or userSettings.username == "" then
            userSettings.username = playerName
        end
        TriggerClientEvent("bazq-objectplace:receiveUserSettings", src, userSettings)
    else
        OPLog("[ObjectPlacer] SERVER WARNING: Could not get license for admin " .. playerName)
        -- Send default settings with FiveM name
        TriggerClientEvent("bazq-objectplace:receiveUserSettings", src, {
            username = playerName,
            packages = {}
        })
    end
end)

-- Event: Client saves user settings
RegisterNetEvent("bazq-objectplace:saveUserSettings")
AddEventHandler("bazq-objectplace:saveUserSettings", function(usernameOrPackages, packages)
    local src = source
    local playerName = GetPlayerName(src)
    
    -- Check admin permission
    if not IsPlayerAdmin(src) then
        OPLog("[ObjectPlacer] SERVER: Settings save denied to " .. playerName .. " - not an admin")
        return
    end
    
    local playerLicense = nil
    
    -- Get player license
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local identifier = GetPlayerIdentifier(src, i)
        if string.find(identifier, "license:") then
            playerLicense = identifier
            break
        end
    end
    
    -- Handle both old format (username, packages) and new format (packages only)
    local finalPackages = {}
    local finalUsername = playerName
    
    if type(usernameOrPackages) == "table" then
        -- New format: first parameter is packages array
        finalPackages = usernameOrPackages
        DebugSave("Saving package settings for " .. playerName .. ": " .. table.concat(finalPackages, ", "))
    elseif type(usernameOrPackages) == "string" and packages then
        -- Old format: first parameter is username, second is packages
        finalUsername = usernameOrPackages
        finalPackages = packages
        DebugSave("Saving full settings for " .. playerName .. " (username: " .. finalUsername .. ")")
    else
        OPLog("[ObjectPlacer] SERVER WARNING: Invalid settings data from " .. playerName)
        return
    end
    
    if playerLicense then
        -- Get existing settings or create new ones
        local existingSettings = GetUserSettings(playerLicense) or {}
        existingSettings.username = finalUsername
        existingSettings.packages = finalPackages
        
        SaveUserSettings(playerLicense, playerName, finalUsername, finalPackages)
        OPLog("[ObjectPlacer] SERVER: Saved settings for " .. playerName)
    else
        OPLog("[ObjectPlacer] SERVER WARNING: Could not get license for " .. playerName)
    end
end)

-- Get resource version info
local function GetResourceInfo()
    local resourceName = GetCurrentResourceName()
    local resourceMetadata = {}
    
    -- Get version from manifest
    local version = GetResourceMetadata(resourceName, 'version', 0) or "Unknown"
    local name = GetResourceMetadata(resourceName, 'name', 0) or resourceName
    local author = GetResourceMetadata(resourceName, 'author', 0) or "Unknown"
    local description = GetResourceMetadata(resourceName, 'description', 0) or ""
    
    return {
        name = name,
        version = version,
        author = author,
        description = description,
        resourceName = resourceName
    }
end

-- Event: Client requests resource info
RegisterNetEvent("bazq-objectplace:requestResourceInfo")
AddEventHandler("bazq-objectplace:requestResourceInfo", function()
    local src = source
    local resourceInfo = GetResourceInfo()
    TriggerClientEvent("bazq-objectplace:receiveResourceInfo", src, resourceInfo)
end)



-- Vanilla objects import removed - replaced with manual spawner

-- On resource start: load objects from file and send to all clients
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        LoadObjectsFromFile()
        LoadOsAdminFromFile()
        InitializeDefaultUsers()
        
        OPLog("[ObjectPlacer] SERVER: Loaded " .. tostring(#savedObjects) .. " objects from file.")
        OPLog("[ObjectPlacer] SERVER: User Management initialized with " .. #userManagementData.users .. " users.")

        -- If there are already players online, this is likely a resource restart during server uptime.
        local safeLoadMode = (#GetPlayers() > 0)
        
        -- Notify clients about safe load mode before sending objects
        for _, player in ipairs(GetPlayers()) do
            TriggerClientEvent("bazq-objectplace:setSafeLoadMode", player, safeLoadMode)
        end
        
        -- Send authoritative snapshot to all currently connected clients
        for _, player in ipairs(GetPlayers()) do
            TriggerClientEvent("bazq-objectplace:loadObjects", player, {
                revision = objectStateRevision,
                objects = savedObjects
            })
        end
    end
end)

-- Detect server timezone on resource start
local serverTimezone = "UTC"
local timezoneOffset = 0

function DetectServerTimezone()
    -- Get local time and UTC time to calculate offset
    local utcTime = os.time(os.date("!*t"))
    local localTime = os.time()
    local offsetSeconds = localTime - utcTime
    local offsetHours = math.floor(offsetSeconds / 3600)
    
    timezoneOffset = offsetHours
    
    -- Check if DST is active by comparing current offset with January offset
    local janDate = {year = 2024, month = 1, day = 15, hour = 12, min = 0, sec = 0}
    local janUtc = os.time(os.date("!*t", os.time(janDate)))
    local janLocal = os.time(janDate)
    local janOffset = math.floor((janLocal - janUtc) / 3600)
    
    local isDST = (offsetHours ~= janOffset)
    
    -- Common timezone mappings based on offset
    local timezoneMap = {
        [-12] = "Pacific/Baker_Island",
        [-11] = "Pacific/Midway",
        [-10] = "Pacific/Honolulu",
        [-9] = "America/Anchorage",
        [-8] = "America/Los_Angeles",
        [-7] = "America/Denver",
        [-6] = "America/Chicago",
        [-5] = "America/New_York",
        [-4] = "America/Caracas",
        [-3] = "America/Sao_Paulo",
        [-2] = "Atlantic/South_Georgia",
        [-1] = "Atlantic/Azores",
        [0] = "UTC",
        [1] = "Europe/London",
        [2] = "Europe/Berlin",
        [3] = "Europe/Istanbul",
        [4] = "Asia/Dubai",
        [5] = "Asia/Karachi",
        [6] = "Asia/Dhaka",
        [7] = "Asia/Bangkok",
        [8] = "Asia/Shanghai",
        [9] = "Asia/Tokyo",
        [10] = "Australia/Sydney",
        [11] = "Pacific/Norfolk",
        [12] = "Pacific/Auckland"
    }
    
    serverTimezone = timezoneMap[offsetHours] or ("UTC" .. (offsetHours >= 0 and "+" or "") .. offsetHours)
    
    DebugLog("SERVER", "Server timezone detected: " .. serverTimezone .. " (UTC" .. (offsetHours >= 0 and "+" or "") .. offsetHours .. ")" .. (isDST and " [DST Active]" or " [Standard Time]"))
end

-- Detect timezone on resource start
Citizen.CreateThread(function()
    Citizen.Wait(1000) -- Wait a bit for server to be ready
    DetectServerTimezone()
end)

-- Handle timestamp requests from client
RegisterNetEvent('bazq-os:requestTimestamp')
AddEventHandler('bazq-os:requestTimestamp', function()
    local src = source
    
    -- Get real Unix timestamp using Lua's os.time (server's local time)
    local realTimestamp = os.time()
    
    -- Check current DST status
    local currentUtc = os.time(os.date("!*t"))
    local currentLocal = os.time()
    local currentOffset = math.floor((currentLocal - currentUtc) / 3600)
    
    local janDate = {year = os.date("%Y"), month = 1, day = 15, hour = 12, min = 0, sec = 0}
    local janUtc = os.time(os.date("!*t", os.time(janDate)))
    local janLocal = os.time(janDate)
    local janOffset = math.floor((janLocal - janUtc) / 3600)
    local isDST = (currentOffset ~= janOffset)
    
    -- Send back to client with timezone info
    TriggerClientEvent('bazq-os:timestampResponse', src, {
        timestamp = realTimestamp,
        timezone = serverTimezone,
        offset = currentOffset,
        isDST = isDST
    })
end)

-- Event: Owner toggles the server spawner lock
RegisterNetEvent("bazq-objectplace:saveLockState")
AddEventHandler("bazq-objectplace:saveLockState", function(locked)
    local src = source
    local identifier = GetPlayerPrimaryIdentifier(src)
    local role = GetUserRole(identifier)
    
    if role ~= "owner" then
        dbg("Lock change denied to " .. GetPlayerName(src) .. " - not an owner")
        return
    end
    
    if not osAdminData.settings then
        osAdminData.settings = {}
    end
    
    osAdminData.settings.lockNonOwners = (locked == true)
    SaveOsAdminToFile()
    dbg("Server lock status set to " .. tostring(locked == true) .. " by owner " .. GetPlayerName(src))
    
    -- Sync updated state to all connected players
    TriggerClientEvent("bazq-objectplace:receiveLockState", -1, locked == true)
end)
