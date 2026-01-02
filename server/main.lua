-- ================================
-- DEBUG SYSTEM CONFIGURATION (SERVER)
-- ================================
-- Load debug configuration
-- Debug system configuration
local debugConfig = nil

-- Debug function - only prints when debug is enabled (unified)
local function DebugLog(level, message)
    if debugConfig and debugConfig.enabled and debugConfig.levels[level] then
        local prefix = debugConfig.format.prefix .. "-" .. level
        if debugConfig.format.use_timestamps then
            local time = os.date("%H:%M:%S")
            prefix = "[" .. time .. "] " .. prefix
        end
        print(prefix .. " " .. message)
    end
end

-- Alias for backwards compatibility within file
local function DebugPrint(level, message)
    DebugLog(level, message)
end

local function LoadDebugConfig()
    -- Minimal initial loading
    local configFile = LoadResourceFile(GetCurrentResourceName(), "debug_config.lua")
    if configFile then
        local conf = nil
        
        -- Try load as-is
        local loadFunc, err = load(configFile)
        if loadFunc then
            local ok, result = pcall(loadFunc)
            if ok and result then
                conf = result
            end
        end
        
        -- Try existing "return" fallback
        if not conf then
            local loadFunc2, err2 = load("return " .. configFile)
            if loadFunc2 then
                local ok, result = pcall(loadFunc2)
                if ok and result then
                    conf = result
                end
            end
        end
        
        if conf then
            debugConfig = conf
            DebugLog("CONFIG", "Debug config loaded successfully")
            if conf.userManagement then
                DebugLog("USER", "UserManagement config loaded")
            end
            return true
        end
    end
    
    -- Fallback to default SILENT config
    debugConfig = {
        enabled = false,
        levels = {
            USER = true,
            SAVE = true,
            LOADING = true,
            GENERAL = true,
            SERVER = true
        },
        format = {
            use_timestamps = false,
            prefix = "[OP-SERVER-DEBUG]"
        },
        userManagement = { autoPromoteFirstUser = false, requireApproval = false }
    }
    print("[bazq-os] [WARN] debug_config.lua not found/failed - defaulting to SILENT mode.")
    return false
end

-- Debug config already loaded above

-- Additional debug logs using DebugPrint now that it's available
if debugConfig and debugConfig.userManagement then
    DebugPrint("USER", string.format("🧪 CONFIG LOADED - AutoPromote: %s, RequireApproval: %s", 
        tostring(debugConfig.userManagement.autoPromoteFirstUser),
        tostring(debugConfig.userManagement.requireApproval)))
end
if debugConfig and debugConfig.testZone then
    DebugPrint("GENERAL", string.format("🏢 TESTZONE CONFIG - Enabled: %s", tostring(debugConfig.testZone.enabled)))
end

-- ================================
-- TEST ZONE CONFIG
-- ================================
-- Load test zone config from debug_config.lua on server side as well
local testZone = {
    enabled = false,
    center = { x = 0.0, y = 0.0, z = 0.0 },
    radius = 100.0,
    cleanupOnDisconnect = true
}

do
    local success, config = pcall(function()
        return LoadResourceFile(GetCurrentResourceName(), "debug_config.lua")
    end)
    if success and config then
        local loadFunc = load("return " .. config:gsub("^return ", ""))
        if loadFunc then
            local ok, conf = pcall(loadFunc)
            if ok and conf and conf.testZone then
                testZone = conf.testZone
                OPLog("[ObjectPlacer] SERVER: testZone config loaded (enabled=" .. tostring(testZone.enabled) .. ")")
            end
        end
    end
    -- Convar override: bazq-testzone=true|false
    local function GetConvarBool(name, default)
        local dv = default and "true" or "false"
        local v = GetConvar(name, dv)
        v = (v or ""):lower()
        return v == "true" or v == "1" or v == "yes" or v == "on"
    end
    local conEnabled = GetConvarBool('bazq-testzone', testZone.enabled)
    if conEnabled ~= testZone.enabled then
        testZone.enabled = conEnabled
        OPLog("[ObjectPlacer] SERVER: testZone enabled overridden by convar bazq-testzone=" .. tostring(conEnabled))
    end
end

local function IsInTestZone(coords)
    if not testZone.enabled then return false end
    if not coords then return false end
    local dx = coords.x - (testZone.center.x or 0.0)
    local dy = coords.y - (testZone.center.y or 0.0)
    local dz = coords.z - (testZone.center.z or 0.0)
    local distSq = dx*dx + dy*dy + dz*dz
    return distSq <= (testZone.radius or 0.0)^2
end

-- ================================
-- TESTZONE F7 PERMISSION SYSTEM  
-- ================================
-- (Will be registered after GetPlayerPrimaryIdentifier function is defined)

-- ================================
-- TESTZONE AUTO-CLEANUP SYSTEM
-- ================================

-- Enhanced player disconnect handler for TestZone cleanup
AddEventHandler('playerDropped', function(reason)
    local src = source
    local playerName = GetPlayerName(src)
    
    DebugPrint("GENERAL", string.format("Player %s disconnected (reason: %s)", playerName, reason))
    
    -- TestZone auto-cleanup
    if testZone.enabled and testZone.cleanupOnDisconnect and playerPlacedObjects[src] then
        local objectsToDelete = playerPlacedObjects[src]
        local deletedCount = 0
        
        DebugPrint("GENERAL", string.format("🧹 TestZone cleanup: Removing %d objects from %s", #objectsToDelete, playerName))
        
        -- Remove objects from savedObjects
        for i = #savedObjects, 1, -1 do
            local obj = savedObjects[i]
            for _, playerObj in ipairs(objectsToDelete) do
                if obj.coords and playerObj.coords and 
                   math.abs(obj.coords.x - playerObj.coords.x) < 0.1 and
                   math.abs(obj.coords.y - playerObj.coords.y) < 0.1 and
                   math.abs(obj.coords.z - playerObj.coords.z) < 0.1 then
                    table.remove(savedObjects, i)
                    deletedCount = deletedCount + 1
                    break
                end
            end
        end
        
        -- Save updated objects to file
        if deletedCount > 0 then
            SaveObjectsToFile()
            DebugPrint("GENERAL", string.format("🧹 TestZone cleanup complete: Deleted %d/%d objects from %s", 
                deletedCount, #objectsToDelete, playerName))
            
            -- Notify all clients to update their lists
            TriggerClientEvent('bazq-objectplace:objectsUpdated', -1, savedObjects)
        end
        
        -- Clear player tracking
        playerPlacedObjects[src] = nil
    end
end)

-- Track per-player placed objects for optional cleanup
local playerPlacedObjects = {}

local function TrackPlayerObjects(src, objects)
    if not testZone.enabled or not testZone.cleanupOnDisconnect then return end
    if type(objects) ~= "table" then return end
    playerPlacedObjects[src] = {}
    for _, obj in ipairs(objects) do
        table.insert(playerPlacedObjects[src], obj)
    end
end


local function DebugUser(msg) DebugPrint("USER", msg) end
local function DebugSave(msg) DebugPrint("SAVE", msg) end
local function DebugLoading(msg) DebugPrint("LOADING", msg) end
local function DebugGeneral(msg) DebugPrint("GENERAL", msg) end
local function OPLog(message)
    -- Remove old prefix if present and log as SERVER level
    local cleanMsg = message:gsub("%[ObjectPlacer%] SERVER[:%s]*", "")
    cleanMsg = cleanMsg:gsub("%[ObjectPlacer%] ", "")
    DebugLog("SERVER", cleanMsg)
end

-- Initialize debug config
LoadDebugConfig()

-- ================================
-- SCRIPT CONFIGURATION
-- ================================

local jsonFilePath = GetResourcePath(GetCurrentResourceName()) .. "/saved_objects.json"
local osAdminFilePath = GetResourcePath(GetCurrentResourceName()) .. "/osadmin.json"
local savedObjects = {} -- In-memory cache of saved objects
local osAdminData = {} -- In-memory cache of osadmin data



-- Load objects from JSON file (on server start)
local function LoadObjectsFromFile()
    local fileContent = LoadResourceFile(GetCurrentResourceName(), "saved_objects.json")
    if fileContent and fileContent ~= "" then
        local success, decodedObjects = pcall(json.decode, fileContent)
        if success and type(decodedObjects) == "table" then
            savedObjects = decodedObjects
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
                    -- Get default values from debug config
                    local configAutoPromote = false
                    local configRequireApproval = false
                    if debugConfig and debugConfig.userManagement then
                        configAutoPromote = debugConfig.userManagement.autoPromoteFirstUser or false
                        configRequireApproval = debugConfig.userManagement.requireApproval or false
                    end
                    
                    osAdminData.userManagement = {
                        users = {},
                        settings = {
                            autoPromoteFirstUser = configAutoPromote,
                            requireApproval = configRequireApproval
                        }
                    }
                    DebugPrint("USER", string.format("UserManagement initialized from config - AutoPromote: %s", tostring(configAutoPromote)))
                end
            end
        else
            OPLog("[ObjectPlacer] SERVER ERROR: Failed to decode osadmin.json or it's not a table.")
            -- Get default values from debug config
            local configAutoPromote = false
            local configRequireApproval = false
            if debugConfig and debugConfig.userManagement then
                configAutoPromote = debugConfig.userManagement.autoPromoteFirstUser or false
                configRequireApproval = debugConfig.userManagement.requireApproval or false
            end
            
            osAdminData = {
                userManagement = {
                    users = {},
                    settings = {
                        autoPromoteFirstUser = configAutoPromote,
                        requireApproval = configRequireApproval
                    }
                },
                admins = {},
                settings = {},
                version = "2.2.0",
                last_updated = os.date("%Y-%m-%d %H:%M:%S")
            }
            DebugPrint("USER", string.format("UserManagement created from config - AutoPromote: %s", tostring(configAutoPromote)))
        end
    else
        OPLog("[ObjectPlacer] SERVER INFO: osadmin.json not found. Creating default structure with example owner.")
        -- Get default values from debug config
        local configAutoPromote = false
        local configRequireApproval = false
        if debugConfig and debugConfig.userManagement then
            configAutoPromote = debugConfig.userManagement.autoPromoteFirstUser or false
            configRequireApproval = debugConfig.userManagement.requireApproval or false
        end
        
        osAdminData = {
            userManagement = {
                users = {
                    -- Example owner entry for manual editing
                    -- {
                    --     identifier = "steam:YOUR_STEAM_ID_HERE",
                    --     displayName = "Your Name",
                    --     role = "owner",
                    --     addedBy = "system",
                    --     dateAdded = os.date("%Y-%m-%d %H:%M:%S")
                    -- }
                },
                settings = {
                    autoPromoteFirstUser = configAutoPromote,
                    requireApproval = configRequireApproval
                }
            },
            admins = {},
            settings = {},
            version = "2.10",
            last_updated = os.date("%Y-%m-%d %H:%M:%S")
        }
        DebugPrint("USER", string.format("New osadmin.json created from config - AutoPromote: %s", tostring(configAutoPromote)))
        -- Save the default structure immediately
        SaveOsAdminToFile()
    end
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
        -- Make JSON more readable by adding some formatting
        encodedData = encodedData:gsub(",", ",\n    ")
        encodedData = encodedData:gsub("{", "{\n    ")
        encodedData = encodedData:gsub("}", "\n}")
        
        local saveSuccess = SaveResourceFile(GetCurrentResourceName(), "osadmin.json", encodedData, -1)
        if not saveSuccess then
            OPLog("[ObjectPlacer] SERVER ERROR: SaveResourceFile failed to write to osadmin.json")
        else
            OPLog("[ObjectPlacer] SERVER INFO: Successfully saved user management data")
        end
    else
        print("[ObjectPlacer] SERVER ERROR: Failed to encode osadmin data to JSON. Error: " .. tostring(encodedData))
    end
end

-- Save objects to JSON file
local function SaveObjectsToFile()
    DebugSave("SaveObjectsToFile() called with " .. #savedObjects .. " objects")
    
    -- Log first few objects for debugging
    if #savedObjects > 0 then
        for i = 1, math.min(3, #savedObjects) do
            local obj = savedObjects[i]
            DebugSave(string.format("Object %d: %s at %.2f,%.2f,%.2f", 
                i, obj.model or "nil", 
                obj.coords and obj.coords.x or 0, 
                obj.coords and obj.coords.y or 0, 
                obj.coords and obj.coords.z or 0))
        end
    end
    
    local success, encodedObjects = pcall(json.encode, savedObjects)
    if success then
        DebugSave("JSON encoding successful. Length: " .. string.len(encodedObjects))
        DebugSave("JSON preview (first 200 chars): " .. string.sub(encodedObjects or "", 1, 200))
        
        local saveSuccess = SaveResourceFile(GetCurrentResourceName(), "saved_objects.json", encodedObjects, -1)
        if not saveSuccess then
            OPLog("[ObjectPlacer] SERVER ERROR: SaveResourceFile failed to write to saved_objects.json")
            OPLog("[ObjectPlacer] SERVER ERROR: Resource path: " .. GetResourcePath(GetCurrentResourceName()))
        else
            OPLog("[ObjectPlacer] SERVER SUCCESS: Saved " .. #savedObjects .. " objects to saved_objects.json")
            
            -- Verify the save by reading it back
            local verification = LoadResourceFile(GetCurrentResourceName(), "saved_objects.json")
            if verification then
                DebugSave("File verification: " .. string.len(verification) .. " characters written")
            else
                DebugSave("File verification FAILED - could not read back saved file")
            end
        end
    else
        OPLog("[ObjectPlacer] SERVER ERROR: Failed to encode objects to JSON. Error: " .. tostring(encodedObjects))
    end
end



-- When a new player joins, send them the current list of saved objects
AddEventHandler('playerJoining', function(source)
    -- Small delay to ensure client is ready
    Citizen.SetTimeout(5000, function()
        if GetPlayerName(source) then -- Check if player is still connected
            TriggerClientEvent("bazq-objectplace:loadObjects", source, savedObjects)
            OPLog("[ObjectPlacer] SERVER: Sent " .. #savedObjects .. " saved objects to new player: " .. GetPlayerName(source))
        end
    end)
end)

-- Cleanup player-placed objects on disconnect when test zone cleanup is enabled
AddEventHandler('playerDropped', function(reason)
    local src = source
    if not testZone.enabled or not testZone.cleanupOnDisconnect then return end
    local playerName = GetPlayerName(src) or ("src:" .. tostring(src))
    if playerPlacedObjects[src] and #playerPlacedObjects[src] > 0 then
        -- Remove objects that belong to this player from savedObjects
        local toRemove = {}
        for i = #savedObjects, 1, -1 do
            local sobj = savedObjects[i]
            -- We can only guess ownership with playerName/timestamp since entities don't have owner ids persisted
            for _, pobj in ipairs(playerPlacedObjects[src]) do
                if sobj.model == pobj.model and sobj.timestamp == pobj.timestamp and sobj.playerName == pobj.playerName then
                    table.insert(toRemove, i)
                    break
                end
            end
        end
        -- Remove by indices
        for _, idx in ipairs(toRemove) do
            table.remove(savedObjects, idx)
        end
        SaveObjectsToFile()
        OPLog("[ObjectPlacer] SERVER: Cleaned up " .. tostring(#toRemove) .. " objects for disconnected player " .. playerName .. " (test zone)")

        -- Broadcast updated list
        for _, player in ipairs(GetPlayers()) do
            TriggerClientEvent("bazq-objectplace:loadObjects", player, savedObjects)
        end
    end
    playerPlacedObjects[src] = nil
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
        -- Get default values from debug config
        local configAutoPromote = false
        local configRequireApproval = false
        if debugConfig and debugConfig.userManagement then
            configAutoPromote = debugConfig.userManagement.autoPromoteFirstUser or false
            configRequireApproval = debugConfig.userManagement.requireApproval or false
        end
        
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

-- Get player identifier (prioritize steam, then fivem, fallback to license)
local function GetPlayerPrimaryIdentifier(src)
    local identifiers = GetPlayerIdentifiers(src)
    
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
    
    return nil
end

-- Get user role by identifier
local function GetUserRole(identifier)
    if not identifier then return "guest" end
    
    for _, user in pairs(userManagementData.users) do
        if user.identifier == identifier then
            return user.role
        end
    end
    
    -- Auto-promote first user to owner if setting is enabled AND no users exist
    if osAdminData.userManagement.settings.autoPromoteFirstUser and 
       #userManagementData.users == 0 then
        local playerName = "First User"
        local newUser = {
            identifier = identifier,
            displayName = playerName,
            role = "owner",
            addedBy = "system",
            dateAdded = os.date("%Y-%m-%d %H:%M:%S")
        }
        
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
    local playerName = GetPlayerName(src)
    local identifier = GetPlayerPrimaryIdentifier(src)
    local role = GetUserRole(identifier)
    
    -- Check if player has freecam permissions (same logic as F7 but simpler response)
    local hasPermission = false
    
    -- Test zone override: allow any user within the configured zone
    local inZone = false
    if testZone and testZone.enabled then
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
    local users = LoadUsersFromFile()
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
        if not CanUserModifyRole(adminRole, currentUser.role) or not CanUserModifyRole(adminRole, newRole) then
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
    users[userIndex] = {
        identifier = newIdentifier,
        displayName = newDisplayName,
        role = newRole
    }
    
    -- Save to file
    local success = SaveUsersToFile(users)
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

-- Event: Client requests to save objects
RegisterNetEvent("bazq-objectplace:saveObjects")
AddEventHandler("bazq-objectplace:saveObjects", function(objectsDataFromClient)
    local src = source
    local playerName = GetPlayerName(src) or "UnknownSource"
    
    -- Check save permission
    if not HasPermission(src, "save") then
        OPLog("[ObjectPlacer] SERVER: Save denied to " .. playerName .. " - insufficient permissions")
        return
    end
    
    DebugSave("SAVE EVENT TRIGGERED by " .. playerName)
    DebugSave("Type of received data: " .. type(objectsDataFromClient))
    
    if type(objectsDataFromClient) == "table" then
        DebugSave("Received table with " .. #objectsDataFromClient .. " items from " .. playerName)
        
        -- For detailed inspection of the first item if it exists
        if #objectsDataFromClient > 0 and type(objectsDataFromClient[1]) == "table" then
            local firstItem = objectsDataFromClient[1]
            DebugSave("First item details:")
            DebugSave("  - Model: " .. tostring(firstItem.model))
            DebugSave("  - Coords: " .. tostring(firstItem.coords and string.format("%.2f, %.2f, %.2f", firstItem.coords.x, firstItem.coords.y, firstItem.coords.z)))
            DebugSave("  - Heading: " .. tostring(firstItem.heading))
            DebugSave("  - Timestamp: " .. tostring(firstItem.timestamp))
            DebugSave("  - Player: " .. tostring(firstItem.playerName))
        end

        -- Update savedObjects and save to file
        savedObjects = objectsDataFromClient
        -- Track for disconnect cleanup in test zone flow (only objects belonging to this player)
        local mine = {}
        for _, obj in ipairs(objectsDataFromClient) do
            if obj.playerName == playerName then
                table.insert(mine, obj)
            end
        end
        TrackPlayerObjects(src, mine)
        DebugSave("Updated savedObjects array, now calling SaveObjectsToFile()")
        SaveObjectsToFile()
        
        OPLog("[ObjectPlacer] SERVER: Successfully processed save request for " .. #objectsDataFromClient .. " objects from " .. playerName)
        
        -- Broadcast updated list to all other clients for real-time sync
        for _, player in ipairs(GetPlayers()) do
            if tonumber(player) ~= src then -- Don't send to the player who just saved
                TriggerClientEvent("bazq-objectplace:loadObjects", player, savedObjects)
            end
        end
        DebugSave("Broadcasted updated object list to all other clients")
        
    else
        OPLog("[ObjectPlacer] SERVER ERROR: Received invalid object data type (" .. type(objectsDataFromClient) .. ") for saving from " .. playerName)
    end
end)

-- Event: Client requests the list of saved objects
RegisterNetEvent("bazq-objectplace:requestObjects")
AddEventHandler("bazq-objectplace:requestObjects", function()
    local src = source
    local playerName = GetPlayerName(src)
    
    -- Check if user has any permissions (mappers and above can view objects)
    local identifier = GetPlayerPrimaryIdentifier(src)
    local role = GetUserRole(identifier)
    
    DebugLoading("Object request from " .. playerName .. " (Role: " .. role .. ", Identifier: " .. tostring(identifier) .. ")")
    DebugLoading("Currently have " .. #savedObjects .. " saved objects to send")
    
    -- ALLOW ALL USERS to load existing objects (viewing doesn't require permissions)
    -- Only restrict spawning/editing/deleting, not viewing placed objects
    TriggerClientEvent("bazq-objectplace:loadObjects", src, savedObjects)
    DebugLoading("Sent " .. #savedObjects .. " objects to " .. playerName .. " (Role: " .. role .. ")")
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
        role = role
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
    local playerName = GetPlayerName(src)
    local identifier = GetPlayerPrimaryIdentifier(src)
    local role = GetUserRole(identifier)
    
    OPLog("[ObjectPlacer] SERVER: F7 access attempt by " .. playerName .. " (Identifier: " .. tostring(identifier) .. ", Role: " .. role .. ")")

    -- Test zone override: allow any user within the configured zone
    local inZone = false
    if testZone and testZone.enabled then
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
        
        -- Send to all currently connected clients
        for _, player in ipairs(GetPlayers()) do
            TriggerClientEvent("bazq-objectplace:loadObjects", player, savedObjects)
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
