-- ================================
-- DEBUG SYSTEM CONFIGURATION
-- ================================
-- Initialize debug config variable
local debugConfig = nil

-- Debug function - only prints when debug is enabled
local function DebugPrint(level, message)
    if debugConfig and debugConfig.enabled and debugConfig.levels[level] then
        local prefix = debugConfig.format.prefix .. "-" .. level
        if debugConfig.format.use_timestamps then
            -- Client-side safe timestamp using game timer
            local gameTime = GetGameTimer()
            local seconds = math.floor(gameTime / 1000) % 86400  -- 24 hours in seconds
            local hours = math.floor(seconds / 3600)
            local minutes = math.floor((seconds % 3600) / 60)
            local secs = seconds % 60
            local time = string.format("%02d:%02d:%02d", hours, minutes, secs)
            prefix = "[" .. time .. "] " .. prefix
        end
        print(prefix .. " " .. message)
    end
end

-- Main debug log function (alias for DebugPrint)
local function DebugLog(level, message)
    DebugPrint(level, message)
end

-- Debug-controlled print function
local function DPrint(level, message)
    if debugConfig and debugConfig.enabled and debugConfig.levels and debugConfig.levels[level] then
        print("[" .. level .. "] " .. message)
    end
end

-- Load debug configuration from external file (or use defaults)
local function LoadDebugConfig()
    -- Minimal initial loading - no prints until debugConfig is ready
    local success, config = pcall(function()
        return LoadResourceFile(GetCurrentResourceName(), "debug_config.lua")
    end)
    
    if success and config then
        -- Fix: Don't add "return" if config already starts with "return"
        local loadString = config
        if not string.match(config, "^%s*return%s") then
            loadString = "return " .. config
        end
        local loadFunc, err = load(loadString)
        
        if loadFunc then
            local result, conf = pcall(loadFunc)
            
            if result and conf then
                debugConfig = conf
                -- Now we can use debug-controlled prints
                DPrint("LOADING", "✅ Config loaded successfully!")
                DPrint("LOADING", "testZone enabled: " .. tostring(conf.testZone and conf.testZone.enabled))
                DPrint("LOADING", "testZone center: " .. tostring(conf.testZone and conf.testZone.center and "EXISTS" or "NIL"))
                
                DebugLog("GENERAL", "Debug config loaded from debug_config.lua")
                if conf.userManagement then
                    DebugLog("USER", string.format("Client UserManagement config - AutoPromote: %s", tostring(conf.userManagement.autoPromoteFirstUser)))
                end
                if conf.testZone then
                    DebugLog("GENERAL", "TestZone config loaded on client")
                end
                return
            else
                DPrint("LOADING", "❌ Config execution failed: " .. tostring(conf))
            end
        else
            DPrint("LOADING", "❌ Load failed: " .. tostring(err))
        end
    end
    
    -- Fallback config - no debug prints for default load
    
    -- Fallback to default config if file not found or invalid
    debugConfig = {
        enabled = true,
        levels = {
            PLACEMENT = true,
            DELETION = true,
            LOADING = true,
            MENU = true,
            USER = true,
            GENERAL = true,
            EDIT = true,
            FREECAM = false,
            SAVE = true,
            COLLISION = false
        },
        format = {
            use_timestamps = false,
            use_colors = false,
            prefix = "[OP-DEBUG]"
        },
        testZone = { enabled = false },
        userManagement = { autoPromoteFirstUser = false, requireApproval = false }
    }
    DebugLog("GENERAL", "Using default debug config (debug_config.lua not found)")
end

-- Initialize debug config
LoadDebugConfig()

-- Quick debug functions for different levels
local function DebugPlacement(msg) DebugPrint("PLACEMENT", msg) end
local function DebugDeletion(msg) DebugPrint("DELETION", msg) end
local function DebugLoading(msg) DebugPrint("LOADING", msg) end
local function DebugMenu(msg) DebugPrint("MENU", msg) end
local function DebugUser(msg) DebugPrint("USER", msg) end
local function DebugGeneral(msg) DebugPrint("GENERAL", msg) end
local function DebugEdit(msg) DebugPrint("EDIT", msg) end
local function DebugFreecam(msg) DebugPrint("FREECAM", msg) end
local function DebugSave(msg) DebugPrint("SAVE", msg) end
local function DebugCollision(msg) DebugPrint("COLLISION", msg) end

-- Command to reload debug config without restarting resource
RegisterCommand('reloaddebug', function()
    -- Use the working LoadDebugConfig from TestZone section
    local configFile = LoadResourceFile(GetCurrentResourceName(), "debug_config.lua")
    if configFile then
        local chunk, err = load(configFile)
        if chunk then
            local success, config = pcall(chunk)
            if success and config then
                debugConfig = config
                DebugLog("CONFIG", "✅ Config reloaded successfully using TestZone method!")
                DebugLog("CONFIG", "testZone.enabled: " .. tostring(config.testZone and config.testZone.enabled))
                DebugLog("CONFIG", "testZone.center: " .. tostring(config.testZone and config.testZone.center and "EXISTS" or "NIL"))
                if config.testZone and config.testZone.center then
                    DebugLog("CONFIG", "testZone.center: " .. config.testZone.center.x .. ", " .. config.testZone.center.y .. ", " .. config.testZone.center.z)
                end
            else
                DebugLog("CONFIG", "❌ Config execution failed: " .. tostring(config))
            end
        else
            DebugLog("CONFIG", "❌ Load failed: " .. tostring(err))
        end
    else
        DebugLog("CONFIG", "❌ File not found!")
    end
    
    DebugLog("GENERAL", "Debug configuration reloaded!")
end, false)

--[[ TESTZONE DEBUG COMMAND COMMENTED OUT - NOT NEEDED
-- Manual TestZone check command for debugging
RegisterCommand('testzone', function()
    DPrint("TESTZONE", "🧪 TESTZONE DEBUG START:")
    DPrint("TESTZONE", "debugConfig exists: " .. tostring(debugConfig ~= nil))
    
    if debugConfig then
        DPrint("TESTZONE", "debugConfig.testZone exists: " .. tostring(debugConfig.testZone ~= nil))
        if debugConfig.testZone then
            DPrint("TESTZONE", "testZone.enabled: " .. tostring(debugConfig.testZone.enabled))
            DPrint("TESTZONE", "testZone.center exists: " .. tostring(debugConfig.testZone.center ~= nil))
            DPrint("TESTZONE", "testZone.radius: " .. tostring(debugConfig.testZone.radius))
            DPrint("TESTZONE", "testZone.forceTestMode: " .. tostring(debugConfig.testZone.forceTestMode))
            
            if debugConfig.testZone.center then
                local playerPed = PlayerPedId()
                local playerPos = GetEntityCoords(playerPed)
                local center = debugConfig.testZone.center
                local radius = debugConfig.testZone.radius
                
                local distance = #(vector3(playerPos.x, playerPos.y, playerPos.z) - vector3(center.x, center.y, center.z))
                
                DPrint("TESTZONE", "Player pos: " .. playerPos.x .. ", " .. playerPos.y .. ", " .. playerPos.z)
                DPrint("TESTZONE", "TestZone center: " .. center.x .. ", " .. center.y .. ", " .. center.z)
                DPrint("TESTZONE", "Distance: " .. distance .. "m (radius: " .. radius .. "m)")
                DPrint("TESTZONE", "In zone: " .. (distance <= radius and "YES" or "NO"))
                
                -- Always show chat message for user feedback
                TriggerEvent('chat:addMessage', {
                    color = { 255, 255, 0 },
                    multiline = true,
                    args = { "[DEBUG]", string.format("Distance: %.1fm | In zone: %s", distance, distance <= radius and "YES" or "NO") }
                })
            else
                DPrint("TESTZONE", "❌ testZone.center is NIL!")
                TriggerEvent('chat:addMessage', {
                    color = { 255, 0, 0 },
                    multiline = true,
                    args = { "[ERROR]", "TestZone center is NIL! Config not loaded properly." }
                })
            end
        else
            DPrint("TESTZONE", "❌ debugConfig.testZone is NIL!")
        end
    else
        DPrint("TESTZONE", "❌ debugConfig is NIL!")
    end
end, false)
--]]

-- Manual config test command
RegisterCommand('configtest', function()
    DPrint("LOADING", "🧪 MANUAL CONFIG TEST:")
    DPrint("LOADING", "Current resource name: " .. GetCurrentResourceName())
    
    local file = LoadResourceFile(GetCurrentResourceName(), "debug_config.lua")
    DPrint("LOADING", "LoadResourceFile result: " .. tostring(file ~= nil))
    
    -- Always show basic result in chat
    local success = file ~= nil
    TriggerEvent('chat:addMessage', {
        color = success and { 0, 255, 0 } or { 255, 0, 0 },
        multiline = true,
        args = { "[CONFIG-TEST]", success and "✅ Config file found" or "❌ Config file NOT found" }
    })
    
    if file then
        DPrint("LOADING", "File length: " .. string.len(file))
        DPrint("LOADING", "File preview: " .. string.sub(file, 1, 200))
        
        -- Try to load it
        local chunk, err = load(file)
        DPrint("LOADING", "Load success: " .. tostring(chunk ~= nil))
        if err then DPrint("LOADING", "Load error: " .. err) end
        
        if chunk then
            local execSuccess, result = pcall(chunk)
            DPrint("LOADING", "Execution success: " .. tostring(execSuccess))
            if execSuccess then
                DPrint("LOADING", "Result type: " .. type(result))
                if result and result.testZone then
                    DPrint("LOADING", "testZone found in result!")
                    DPrint("LOADING", "testZone.enabled: " .. tostring(result.testZone.enabled))
                    if result.testZone.center then
                        DPrint("LOADING", "testZone.center: " .. result.testZone.center.x .. ", " .. result.testZone.center.y .. ", " .. result.testZone.center.z)
                    end
                    
                    TriggerEvent('chat:addMessage', {
                        color = { 0, 255, 0 },
                        multiline = true,
                        args = { "[CONFIG-TEST]", "✅ Config loaded and TestZone found!" }
                    })
                end
            else
                DPrint("LOADING", "Execution error: " .. tostring(result))
            end
        end
    end
end, false)

-- Manual F7 test command will be defined after ToggleMenu function

-- ================================
-- SCRIPT START
-- ================================

local placing = false
local selectedObject = nil
local objectEntity = nil
local editingObjectData = nil
local manualHeightAdjusted = false
local objectsConfig = {}
local isMenuOpen = false
local isControlsDisabled = false
local isFreecamActive = false

-- Real timestamp cache and function
local lastTimestampUpdate = 0
local cachedTimestamp = 0
local timestampOffset = 0

function GetRealTimestamp()
    -- For now, use a simple approach that gets real time from server
    -- We'll request timestamp from server when needed
    local currentGameTimer = GetGameTimer()
    
    -- Update timestamp from server every 10 minutes (600000 ms) or on first call
    if cachedTimestamp == 0 or (currentGameTimer - lastTimestampUpdate) > 600000 then
        -- Request real timestamp from server
        TriggerServerEvent('bazq-os:requestTimestamp')
        
        -- Wait briefly for server response
        local waitStart = GetGameTimer()
        while cachedTimestamp == 0 and (GetGameTimer() - waitStart) < 1000 do
            Citizen.Wait(10)
        end
        
        -- If still no response, use fallback
        if cachedTimestamp == 0 then
            if timestampOffset ~= 0 then
                cachedTimestamp = math.floor((currentGameTimer / 1000) + timestampOffset)
            else
                -- Use current game timer as last resort with a realistic epoch offset
                cachedTimestamp = math.floor(currentGameTimer / 1000) + 1672531200 -- Jan 1, 2023 offset
            end
            DebugLog("TIMESTAMP", "Server timestamp request failed, using fallback: " .. cachedTimestamp)
        end
    else
        -- Use cached timestamp with offset
        cachedTimestamp = math.floor((currentGameTimer / 1000) + timestampOffset)
    end
    
    return cachedTimestamp
end

-- Handle timestamp response from server
RegisterNetEvent('bazq-os:timestampResponse')
AddEventHandler('bazq-os:timestampResponse', function(data)
    if data then
        if type(data) == "number" then
            -- Backward compatibility - old format
            cachedTimestamp = data
            timestampOffset = cachedTimestamp - (GetGameTimer() / 1000)
            lastTimestampUpdate = GetGameTimer()
            DebugLog("TIMESTAMP", "Received timestamp from server: " .. cachedTimestamp)
        elseif type(data) == "table" and data.timestamp then
            -- New format with timezone info
            cachedTimestamp = data.timestamp
            timestampOffset = cachedTimestamp - (GetGameTimer() / 1000)
            lastTimestampUpdate = GetGameTimer()
            DebugLog("TIMESTAMP", "Received timestamp from server: " .. cachedTimestamp .. " (timezone: " .. (data.timezone or "unknown") .. ", offset: " .. timestampOffset .. ")")
        end
    end
end)

local isMenuLoading = false -- Prevent multiple F7 presses

-- Track currently highlighted object for selection
local highlightedObjectIndex = nil

-- Store current user settings for placement
local currentUserSettings = {}

-- Clean up highlights on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        ClearAllHighlights()
    end
end)

-- Safe load mode flag (set by server on resource start if players are online)
local SAFE_LOAD_MODE = false

RegisterNetEvent("bazq-objectplace:setSafeLoadMode")
AddEventHandler("bazq-objectplace:setSafeLoadMode", function(state)
    SAFE_LOAD_MODE = state and true or false
    DebugLog("LOADING", "SafeLoadMode set to " .. tostring(SAFE_LOAD_MODE))
end)

local currentPlacementOptions = {
    snapToGround = true,
    timestamp = "", -- Will be set from JS
    playerName = "Unknown" -- Will be set from osadmin.json displayName
}
-- Master object lists by package
local packageObjects = {
    tents_package = {
        "bazq-tent1a", "bazq-tent1b", "bazq-tent1c", "bazq-tent2a", "bazq-tent2b", "bazq-tent2c"
    },
    wall_pack_1 = {
        "bazq-kule1", "bazq-kule2", "bazq-sur_kapi", "bazq-sur_mkapi", "bazq-sur1", "bazq-sur2", "bazq-sur3", "bazq-sur4", "bazq-sur5"
    },
    wall_pack_2 = {
        "bazq-wall2_gate1", "bazq-wall2_gate2", "bazq-wall2_gate3", "bazq-wall2_gate4", "bazq-wall2_pole",
        "bazq-wall2_sign11", "bazq-wall2_sign12", "bazq-wall2_sign21", "bazq-wall2_sign22", "bazq-wall2_sign31", "bazq-wall2_sign32",
        "bazq-wall2_wall1", "bazq-wall2_wall2", "bazq-wall2_wall3", "bazq-wall2_wall4", "bazq-wall2_wall5",
        "bazq-wall2_walldecal1", "bazq-wall2_walldecal2", "bazq-wall2_walldecal3", "bazq-wall2_walldecal4", "bazq-wall2_walldecal5",
        "bazq-wall2_walldecal6", "bazq-wall2_walldecal7", "bazq-wall2_walldecal8", "bazq-wall2_walldecal9", "bazq-wall2_walldecal10",
        "bazq-wall2_wallfence"
    },
    crashed_air = {
        "bazq-crashedbw", "bazq-crashedsn_front", "bazq-crashedsn_rear", "bazq-crashedplane"
    },
    subscriber = {
        -- Subscriber gets all packages
        "bazq-tent1a", "bazq-tent1b", "bazq-tent1c", "bazq-tent2a", "bazq-tent2b", "bazq-tent2c",
        "bazq-kule1", "bazq-kule2", "bazq-sur_kapi", "bazq-sur_mkapi", "bazq-sur1", "bazq-sur2", "bazq-sur3", "bazq-sur4", "bazq-sur5",
        "bazq-wall2_gate1", "bazq-wall2_gate2", "bazq-wall2_gate3", "bazq-wall2_gate4", "bazq-wall2_pole",
        "bazq-wall2_sign11", "bazq-wall2_sign12", "bazq-wall2_sign21", "bazq-wall2_sign22", "bazq-wall2_sign31", "bazq-wall2_sign32",
        "bazq-wall2_wall1", "bazq-wall2_wall2", "bazq-wall2_wall3", "bazq-wall2_wall4", "bazq-wall2_wall5",
        "bazq-wall2_walldecal1", "bazq-wall2_walldecal2", "bazq-wall2_walldecal3", "bazq-wall2_walldecal4", "bazq-wall2_walldecal5",
        "bazq-wall2_walldecal6", "bazq-wall2_walldecal7", "bazq-wall2_walldecal8", "bazq-wall2_walldecal9", "bazq-wall2_walldecal10",
        "bazq-wall2_wallfence", "bazq-crashedbw", "bazq-crashedsn_front", "bazq-crashedsn_rear", "bazq-crashedplane"
    }
}

-- Load objects configuration from JSON
function LoadObjectsConfig()
    local configFile = LoadResourceFile(GetCurrentResourceName(), "objects_config.json")
    if configFile then
        local success, config = pcall(json.decode, configFile)
        if success and config then
            objectsConfig = config
            DebugLog("LOADING", "Loaded objects configuration with " .. (config.packages and CountTableKeys(config.packages) or 0) .. " packages")
            return true
        else
            DebugLog("GENERAL", "ERROR: Failed to parse objects_config.json")
        end
    else
        DebugLog("GENERAL", "ERROR: Could not load objects_config.json")
    end
    return false
end

-- Vanilla objects loading removed - replaced with manual spawner

-- Helper function to count table keys
function CountTableKeys(t)
    local count = 0
    for k, v in pairs(t) do
        count = count + 1
    end
    return count
end

-- Function to get objects based on user packages
function GetUserObjects(userPackages)
    local userObjects = {}
    local addedObjects = {} -- To prevent duplicates
    
    DebugLog("USER", "GetUserObjects called with packages: " .. tostring(userPackages and json.encode(userPackages) or "NIL"))
    DebugLog("USER", "objectsConfig.packages exists: " .. tostring(objectsConfig.packages ~= nil))
    DebugLog("USER", "Package count received: " .. tostring(userPackages and #userPackages or 0))
    
    if objectsConfig.packages then
        local availablePackages = {}
        for packageName, _ in pairs(objectsConfig.packages) do
            table.insert(availablePackages, packageName)
        end
        DebugLog("USER", "Available packages in config: " .. json.encode(availablePackages))
    end
    
    -- Try new config system first
    if objectsConfig.packages and userPackages and type(userPackages) == "table" then
        DebugLog("USER", "Using config system for packages: " .. table.concat(userPackages, ", "))
        local availablePackages = {}
        for packageName, _ in pairs(objectsConfig.packages) do
            table.insert(availablePackages, packageName)
        end
        DebugLog("USER", "Available config packages: " .. tostring(json.encode(availablePackages)))
        
        -- Check if user has subscriber package - if so, give them ALL packages
        local hasSubscriber = false
        for _, packageName in ipairs(userPackages) do
            if packageName == "subscriber" then
                hasSubscriber = true
                break
            end
        end
        
        local packagesToProcess = userPackages
        if hasSubscriber then
            -- Subscriber gets all packages
            packagesToProcess = {}
            for packageName, _ in pairs(objectsConfig.packages) do
                table.insert(packagesToProcess, packageName)
            end
            DebugLog("USER", "Subscriber detected - enabling all packages: " .. table.concat(packagesToProcess, ", "))
        end
        
        for _, packageName in ipairs(packagesToProcess) do
            local package = objectsConfig.packages[packageName]
            if package and package.objects then
                DebugLog("USER", "Found package " .. packageName .. " with " .. #package.objects .. " objects")
                for _, objConfig in ipairs(package.objects) do
                    if objConfig.prop and not addedObjects[objConfig.prop] then
                        table.insert(userObjects, objConfig.prop)
                        addedObjects[objConfig.prop] = true
                    end
                end
            else
                DebugLog("USER", "Package " .. packageName .. " not found in config")
            end
        end
        
        -- If we got objects from config, return them
        if #userObjects > 0 then
            DebugLog("USER", "Returning " .. #userObjects .. " objects from config system")
            DebugLog("USER", "First few objects: " .. json.encode({userObjects[1], userObjects[2], userObjects[3]}))
            return userObjects
        else
            DebugLog("USER", "No objects found in config system, falling back")
        end
    else
        DebugLog("USER", "Config system not available, using fallback")
        DebugLog("USER", "objectsConfig.packages nil: " .. tostring(objectsConfig.packages == nil))
        DebugLog("USER", "userPackages nil or not table: " .. tostring(userPackages == nil or type(userPackages) ~= "table"))
    end
    
    -- Fallback to old hardcoded system
    if userPackages and type(userPackages) == "table" then
        for _, package in ipairs(userPackages) do
            if packageObjects[package] then
                for _, obj in ipairs(packageObjects[package]) do
                    if not addedObjects[obj] then
                        table.insert(userObjects, obj)
                        addedObjects[obj] = true
                    end
                end
            end
        end
    end
    
    return userObjects
end

local objectList = {} -- Will be populated based on user packages
local spawnedObjects = {}

-- Helper function to find nearby wall objects
function FindNearbyWall(coords, maxDistance)
    maxDistance = maxDistance or 2.0
    for i, objData in ipairs(spawnedObjects) do
        if objData.entity and DoesEntityExist(objData.entity) and objData.model then
            -- Check if it's a wall object (from either wall package)
            if objData.model:match("bazq%-sur%d+") or objData.model:match("bazq%-wall2_wall%d+") then
                local wallCoords = GetEntityCoords(objData.entity)
                local distance = #(coords - wallCoords)
                if distance <= maxDistance then
                    return objData, i
                end
            end
        end
    end
    return nil, nil
end

-- Helper function to check if object requires wall attachment
function RequiresWallAttachment(modelName)
    return modelName:match("bazq%-wall2_walldecal%d+") or modelName == "bazq-wall2_wallfence"
end

-- Helper function to get object display name from config
local function GetObjectDisplayName(modelName)
    if objectsConfig.packages then
        for packageName, package in pairs(objectsConfig.packages) do
            if package.objects then
                for _, objConfig in ipairs(package.objects) do
                    if objConfig.prop == modelName and objConfig.name then
                        return objConfig.name
                    end
                end
            end
        end
    end
    -- Fallback: clean up model name for display
    return modelName:gsub("bazq%-", ""):gsub("_", " "):gsub("(%a)([%a%d]*)", function(first, rest)
        return first:upper() .. rest
    end)
end

-- Helper to get package name of a model from objects_config
local function GetObjectPackageName(modelName)
    if objectsConfig.packages then
        for packageName, package in pairs(objectsConfig.packages) do
            if package.objects then
                for _, objConfig in ipairs(package.objects) do
                    if objConfig.prop == modelName then
                        return packageName
                    end
                end
            end
        end
    end
    return nil
end

function GetSerializableSpawnedObjects()
    local list = {}
    for i, objData in ipairs(spawnedObjects) do
        if objData.model then
            local coords = nil
            if objData.entity and DoesEntityExist(objData.entity) then
                local c = GetEntityCoords(objData.entity)
                coords = { x = c.x, y = c.y, z = c.z }
            end
            local pkg = GetObjectPackageName(objData.model)
            table.insert(list, {
                model = objData.model,
                originalIndex = i,
                timestamp = objData.timestamp or "",
                playerName = objData.playerName or "Unknown",
                displayName = objData.displayName or GetObjectDisplayName(objData.model),
                coords = coords,
                packageName = pkg,
                hasDualDoors = objData.hasDualDoors == true
            })
        end
    end
    return list
end

-- Object selection highlighting functions
function HighlightObject(index)
    if index and spawnedObjects[index] and spawnedObjects[index].entity then
        local entity = spawnedObjects[index].entity
        if DoesEntityExist(entity) then
            -- Apply blue glowing outline for selection
            SetEntityAlpha(entity, 200, false)
            SetEntityDrawOutline(entity, true)
            SetEntityDrawOutlineColor(91, 155, 255, 255) -- Blue outline for selection
            return true
        end
    end
    return false
end

function UnhighlightObject(index)
    if index and spawnedObjects[index] and spawnedObjects[index].entity then
        local entity = spawnedObjects[index].entity
        if DoesEntityExist(entity) then
            -- Remove highlight effects
            ResetEntityAlpha(entity)
            SetEntityDrawOutline(entity, false)
            return true
        end
    end
    return false
end

function ClearAllHighlights()
    if highlightedObjectIndex then
        UnhighlightObject(highlightedObjectIndex)
        highlightedObjectIndex = nil
    end
end

RegisterNUICallback('selectObject', function(data, cb)
    if editingObjectData then
        SendNUIMessage({action = 'showError', message = "Finish keyboard editing first (Enter/Esc)."})
        cb({status = 'error'}); return
    end
    
    -- Handle object selection for highlighting (data.index)
    if data.index then
        local index = tonumber(data.index)
        if index and spawnedObjects[index] then
            -- Clear previous highlight
            ClearAllHighlights()
            
            -- Highlight new object
            if HighlightObject(index) then
                highlightedObjectIndex = index
                DebugLog("GENERAL", "Selected object " .. index .. " (" .. (spawnedObjects[index].model or "unknown") .. ") for highlighting")
                cb({status = 'ok', message = 'Object selected and highlighted'})
            else
                cb({status = 'error', message = 'Failed to highlight object'})
            end
        else
            cb({status = 'error', message = 'Invalid object index'})
        end
        return
    end
    
    -- Handle object spawning (data.model)
    if data.model then
        if data.options then
            currentPlacementOptions.snapToGround = data.options.snapToGround
            currentPlacementOptions.timestamp = data.options.timestamp or ""
            -- Don't override playerName from JavaScript - keep osadmin.json displayName
            -- Handle the placeDoors option from JavaScript dialog
            if data.options.placeDoors ~= nil then
                currentPlacementOptions.includeDoors = data.options.placeDoors
            end
        end
        StartPlacingObject(data.model)
    end
    cb('ok')
end)

-- Handle gate dialog response
RegisterNUICallback('gateDialogResponse', function(data, cb)
    if data.model and data.model == "bazq-sur_kapi" then
        if data.options then
            currentPlacementOptions.snapToGround = data.options.snapToGround
            currentPlacementOptions.timestamp = data.options.timestamp or ""
            -- Don't override playerName from JavaScript - keep osadmin.json displayName
        end
        
        -- Store the user's choice about doors
        currentPlacementOptions.includeDoors = data.includeDoors or false
        
        StartPlacingObject(data.model)
    end
    cb('ok')
end)

-- Vanilla object callback removed - replaced with manual spawner

RegisterNUICallback('escapePressed', function(data, cb)
    DebugLog("MENU", "🔍 ESC PRESSED - IsNuiFocused: " .. tostring(IsNuiFocused()) .. " isMenuOpen: " .. tostring(isMenuOpen))
    if IsNuiFocused() then
        DebugLog("MENU", "❌ ESC: Closing menu via ESC key")
        SetNuiFocus(false, false)
        SendNUIMessage({action = 'close'})
        isMenuOpen = false  -- Reset menu state
        isMenuLoading = false  -- Reset loading state
        -- Clear highlights when closing menu
        ClearAllHighlights()
        DebugLog("MENU", "Menu closed via Escape - isMenuOpen:" .. tostring(isMenuOpen) .. " isMenuLoading:" .. tostring(isMenuLoading))
    elseif editingObjectData then 
        CancelKeyboardEdit(true) 
    end
    cb('ok')
end)

RegisterNUICallback('cancelPlacement', function(_, cb)
    CancelPlacing()
    SetNuiFocus(false, false)
    SendNUIMessage({action = 'close'})
    isMenuOpen = false  -- Reset menu state
    isMenuLoading = false  -- Reset loading state
    cb('ok')
end)

RegisterNUICallback('deleteObject', function(data, cb)
    local index = tonumber(data.index)
    if index and spawnedObjects[index] then
        -- Clear highlight if this is the highlighted object
        if highlightedObjectIndex == index then
            ClearAllHighlights()
        end
        DeleteSpawnedObject(index)
        cb({status = 'ok'})
    else
        cb({status = 'error', message = 'Invalid index for deletion.'})
    end
end)

RegisterNUICallback('duplicateObject', function(data, cb)
    if editingObjectData then
        SendNUIMessage({action = 'showError', message = "Finish keyboard editing first (Enter/Esc)."})
        cb({status = 'error'}); return
    end
    local index = tonumber(data.index)
    if index and spawnedObjects[index] then
        local objData = spawnedObjects[index]
        if objData and objData.model and objData.entity and DoesEntityExist(objData.entity) then
            -- Get the original object's position and rotation
            local originalCoords = GetEntityCoords(objData.entity)
            local originalHeading = GetEntityHeading(objData.entity)
            
            -- Create exact duplicate at same exact position
            local newCoords = originalCoords
            
            -- Get current player name and timestamp (from osadmin.json displayName)
            local playerName = currentPlacementOptions.playerName
            -- Use real timestamp instead of just game time
            local timestamp = GetRealTimestamp() -- Real Unix timestamp from web
            
            -- Create the duplicate object
            local modelHash = GetHashKey(objData.model)
            if IsModelValid(modelHash) then
                RequestModel(modelHash)
                while not HasModelLoaded(modelHash) do
                    Citizen.Wait(10)
                end
                
                local newEntity = CreateObject(modelHash, newCoords.x, newCoords.y, newCoords.z, true, true, false)
                if DoesEntityExist(newEntity) then
                    SetEntityHeading(newEntity, originalHeading)
                    PlaceObjectOnGroundProperly(newEntity)
                    FreezeEntityPosition(newEntity, true)
                    
                    -- Add to spawned objects list
                    local newIndex = #spawnedObjects + 1
                    spawnedObjects[newIndex] = {
                        entity = newEntity,
                        model = objData.model,
                        coords = GetEntityCoords(newEntity),
                        heading = GetEntityHeading(newEntity),
                        playerName = playerName,
                        timestamp = timestamp,
                        originalIndex = newIndex
                    }
                    
                    -- Save to server (align with server handler)
                    TriggerServerEvent("bazq-objectplace:saveObjects", GetSerializableSpawnedObjects())
                    
                    -- Update UI
                    SendNUIMessage({
                        action = 'updateSpawnedList',
                        data = GetSerializableSpawnedObjects()
                    })
                    
                    -- Close UI and enter edit mode with the new duplicated object
                    SetNuiFocus(false, false)
                    SendNUIMessage({action = 'close'})
                    isMenuOpen = false
                    
                    editingObjectData = {
                        entity = newEntity, 
                        originalIndex = newIndex, 
                        model = objData.model,
                        originalCoords = GetEntityCoords(newEntity), 
                        originalHeading = GetEntityHeading(newEntity),
                        timestamp = timestamp
                    }
                    
                    -- Apply green glowing wireframe effect for edit mode
                    SetEntityAlpha(newEntity, 180, false)
                    SetEntityDrawOutline(newEntity, true)
                    SetEntityDrawOutlineColor(104, 182, 91, 255) -- Green outline
                    SetEntityRenderScorched(newEntity, true)
                    
                    -- Start edit mode controls
                    SendNUIMessage({action = 'editingModeUpdate', message = "EDIT MODE: WASD:Move | Alt/F:Height | Q/E:Rotate (1°) | G:Snap Toggle | X:Toggle 5° Mode | R:Reset Rotation | LMB:Save | RMB:Cancel | Rotation: " .. math.floor(GetEntityHeading(newEntity)) .. "°", editingActive = true})
                    Citizen.CreateThread(KeyboardEditLoop)
                    
                    cb({status = 'ok', message = 'Object duplicated - now in edit mode'})
                else
                    cb({status = 'error', message = 'Failed to create duplicate object'})
                end
                
                SetModelAsNoLongerNeeded(modelHash)
            else
                cb({status = 'error', message = 'Invalid model for duplication'})
            end
        else
            cb({status = 'error', message = 'Object data or entity missing.'})
        end
    else
        cb({status = 'error', message = 'Invalid index for duplication.'})
    end
end)

-- Add backwards compatibility for editObject callback
RegisterNUICallback('editObject', function(data, cb)
    -- Redirect to editSpawnedObject for backwards compatibility
    if editingObjectData then
        SendNUIMessage({action = 'showError', message = "Finish keyboard editing first (Enter/Esc)."})
        cb({status = 'error'}); return
    end
    local index = tonumber(data.index)
    if index and spawnedObjects[index] then
        local objData = spawnedObjects[index]
        if objData and objData.entity and DoesEntityExist(objData.entity) then
            -- Clear any selection highlighting before starting edit
            ClearAllHighlights()
            
            editingObjectData = {
                entity = objData.entity, originalIndex = index, model = objData.model,
                originalCoords = GetEntityCoords(objData.entity), originalHeading = GetEntityHeading(objData.entity),
                timestamp = objData.timestamp
            }
            
            -- Apply green glowing wireframe effect immediately when starting edit
            SetEntityAlpha(objData.entity, 180, false)
            SetEntityDrawOutline(objData.entity, true)
            SetEntityDrawOutlineColor(104, 182, 91, 255) -- Green outline
            SetEntityRenderScorched(objData.entity, true)
            
            SetNuiFocus(false, false); SendNUIMessage({action = 'close'})
            SendNUIMessage({action = 'editingModeUpdate', message = "EDIT MODE: WASD:Move | Alt/F:Height | Q/E:Rotate (1°) | G:Snap Toggle | X:Toggle 5° Mode | R:Reset Rotation | LMB:Save | RMB:Cancel | Rotation: " .. math.floor(GetEntityHeading(objData.entity)) .. "°", editingActive = true})
            Citizen.CreateThread(KeyboardEditLoop)
            cb({status = 'ok'})
        else 
            cb({status = 'error', message = 'Object entity missing.'}) 
        end
    else 
        cb({status = 'error', message = 'Invalid index for editing.'}) 
    end
end)

RegisterNUICallback('toggleFreecam', function(data, cb)
    if data.state then
        -- Enable freecam and close menu
        SetFreecamActive(true)
        isFreecamActive = true
        SetNuiFocus(false, false)
        SendNUIMessage({action = 'close'})
        isMenuOpen = false  -- Reset menu state
        isMenuLoading = false  -- Reset loading state
        
        -- Update UI freecam state first
        SendNUIMessage({action = 'updateFreecamState', isActive = true})
        
        -- Show notification
        SendNUIMessage({action = 'objectSpawned', message = "Freecam enabled! F6 to disable or click indicator."})
        
        DebugLog("FREECAM", "Freecam enabled via UI")
    else
        -- Disable freecam
        SetFreecamActive(false)
        isFreecamActive = false
        
        -- Update UI freecam state first
        SendNUIMessage({action = 'updateFreecamState', isActive = false})
        
        -- Show notification
        SendNUIMessage({action = 'objectSpawned', message = "Freecam disabled."})
        
        DebugLog("FREECAM", "Freecam disabled via UI")
    end
    cb('ok')
end)

RegisterNUICallback('reopenMenu', function(data, cb)
    -- Reopen the menu when freecam is disabled
    if not isFreecamActive then
        -- Check TestZone access first
        if debugConfig and debugConfig.testZone and debugConfig.testZone.enabled and IsPlayerInTestZone() then
            DebugLog("MENU", "Reopening menu via TestZone access")
            TriggerEvent("bazq-objectplace:adminCheckResponse", {hasAccess = true, message = "TestZone access granted"})
        else
            TriggerServerEvent("bazq-objectplace:checkAdminPermission")
        end
    end
    cb('ok')
end)

-- Close menu callback for when UI closes via other methods
RegisterNUICallback('closeMenu', function(data, cb)
    DebugLog("MENU", "🔍 CLOSE MENU CALLBACK - IsNuiFocused: " .. tostring(IsNuiFocused()) .. " isMenuOpen: " .. tostring(isMenuOpen))
    DebugLog("MENU", "❌ CLOSE: Closing menu via closeMenu callback")
    SetNuiFocus(false, false)
    SendNUIMessage({action = 'close'})
    isMenuOpen = false  -- Reset menu state
    isMenuLoading = false  -- Reset loading state
    -- Clear highlights when closing menu
    ClearAllHighlights()
    DebugLog("MENU", "Menu closed via closeMenu callback - isMenuOpen:" .. tostring(isMenuOpen) .. " isMenuLoading:" .. tostring(isMenuLoading))
    cb('ok')
end)

-- Import vanilla objects callback removed

RegisterNUICallback('cleanZone', function(_, cb)
    cb(1)
    local playerId = PlayerPedId()
    local playerCoords = GetEntityCoords(playerId)
    
    local cleanRadius = 1000.0  -- Increased radius per request
    
    -- Clear area of debris, vehicles, NPCs etc. (but NOT our placed props)
    ClearAreaOfEverything(playerCoords.x, playerCoords.y, playerCoords.z, cleanRadius, false, false, false, false)
    
    -- Send success message to UI
    SendNUIMessage({
        action = 'objectSpawned',
        message = 'Area cleaned! Cleared ' .. cleanRadius .. 'm radius of debris/vehicles/NPCs.'
    })
    
    DebugLog("GENERAL", "Clean Zone: Cleared debris/vehicles/NPCs in " .. cleanRadius .. "m radius around " .. playerCoords.x .. ", " .. playerCoords.y .. ", " .. playerCoords.z)
end)

-- Time and Weather Controls
local Client = {
    freezeTime = false,
    freezeWeather = false
}

local Utils = {
    setClock = function(hour)
        NetworkOverrideClockTime(hour, 0, 0)
    end,
    setWeather = function(weather)
        SetWeatherTypeNowPersist(weather)
        SetWeatherTypeNow(weather)
    end
}

RegisterNUICallback('setDay', function(_, cb)
    cb(1)
    Utils.setClock(12)
    Utils.setWeather('extrasunny')
    SendNUIMessage({
        action = 'objectSpawned',
        message = 'Set to sunny day (12:00 PM)'
    })
end)

RegisterNUICallback('freezeTime', function(data, cb)
    cb(1)
    Client.freezeTime = data.state or false
    local status = Client.freezeTime and "FROZEN" or "UNFROZEN"
    SendNUIMessage({
        action = 'objectSpawned',
        message = 'Time ' .. status
    })
end)

RegisterNUICallback('freezeWeather', function(data, cb)
    cb(1)
    Client.freezeWeather = data.state or false
    local status = Client.freezeWeather and "FROZEN" or "UNFROZEN"
    SendNUIMessage({
        action = 'objectSpawned',
        message = 'Weather ' .. status
    })
end)

-- Time and Weather freeze thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if Client.freezeTime then
            NetworkOverrideClockTime(12, 0, 0)
        end
        if Client.freezeWeather then
            SetWeatherTypeNowPersist('extrasunny')
        end
    end
end)

RegisterNUICallback('spawnCustomProp', function(data, cb)
    if editingObjectData then 
        SendNUIMessage({action = 'showError', message = "Finish keyboard editing first (Enter/Esc)."})
        cb({status = 'error'}); return
    end
    if data.propName and type(data.propName) == "string" and string.len(data.propName) > 0 then
        local propName = data.propName
        local modelHash = GetHashKey(propName)
        if IsModelInCdimage(modelHash) and IsModelValid(modelHash) then
            if data.options then
                currentPlacementOptions.snapToGround = data.options.snapToGround
                currentPlacementOptions.timestamp = data.options.timestamp or ""
                -- Don't override playerName from JavaScript - keep osadmin.json displayName
            end
            StartPlacingObject(propName)
            cb({status = 'ok', message = 'Attempting to spawn: ' .. propName})
        else
            cb({status = 'error', message = "Error: Prop '" .. propName .. "' is invalid or not found."})
            SendNUIMessage({action = 'showError', message = "Error: Prop '" .. propName .. "' is invalid or not found."})
        end
    else
        cb({status = 'error', message = 'Invalid prop name provided.'})
        SendNUIMessage({action = 'showError', message = "Error: Invalid prop name."})
    end
end)

RegisterNUICallback('editSpawnedObject', function(data, cb)
    if placing then
        SendNUIMessage({action = 'showError', message = "Finish current placement before editing."})
        cb({status = 'error'}); return
    end
    if editingObjectData then
        SendNUIMessage({action = 'showError', message = "Already editing. Press Enter/Esc."})
        cb({status = 'error'}); return
    end
    local index = tonumber(data.index)
    if index and spawnedObjects[index] then
        local objData = spawnedObjects[index]
        if objData and objData.entity and DoesEntityExist(objData.entity) then
            -- Clear any selection highlighting before starting edit
            ClearAllHighlights()
            
            editingObjectData = {
                entity = objData.entity, originalIndex = index, model = objData.model,
                originalCoords = GetEntityCoords(objData.entity), originalHeading = GetEntityHeading(objData.entity),
                timestamp = objData.timestamp
            }
            
            -- Apply green glowing wireframe effect immediately when starting edit
            SetEntityAlpha(objData.entity, 180, false)
            SetEntityDrawOutline(objData.entity, true)
            SetEntityDrawOutlineColor(104, 182, 91, 255) -- Green outline
            SetEntityRenderScorched(objData.entity, true)
            
            SetNuiFocus(false, false); SendNUIMessage({action = 'close'})
            SendNUIMessage({action = 'editingModeUpdate', message = "EDIT MODE: WASD:Move | Alt/F:Height | Q/E:Rotate (1°) | G:Snap Toggle | X:Toggle 5° Mode | R:Reset Rotation | LMB:Save | RMB:Cancel | Rotation: " .. math.floor(GetEntityHeading(objData.entity)) .. "°", editingActive = true})
            Citizen.CreateThread(KeyboardEditLoop)
            cb({status = 'ok'})
        else cb({status = 'error', message = 'Object entity missing.'}) end
    else cb({status = 'error', message = 'Invalid index for editing.'}) end
end)

local menuOpenKey = 168 -- F7 Key
local freecamKey = 167 -- F6 Key

local function ToggleMenu()
    DebugMenu("ToggleMenu called - isMenuOpen: " .. tostring(isMenuOpen) .. ", isMenuLoading: " .. tostring(isMenuLoading) .. ", IsNuiFocused: " .. tostring(IsNuiFocused()))
    
    -- Clean up any stuck NUI focus
    if IsNuiFocused() and not isMenuOpen then
        DebugMenu("Cleaning up stuck NUI focus in ToggleMenu")
        SetNuiFocus(false, false)
    end
    
    if IsNuiFocused() or isMenuOpen then
        -- Close menu
        DebugMenu("Closing menu...")
        SetNuiFocus(false, false)
        SendNUIMessage({action = 'close'})
        isMenuOpen = false
        isMenuLoading = false
        DebugMenu("Menu closed - isMenuOpen: " .. tostring(isMenuOpen) .. ", isMenuLoading: " .. tostring(isMenuLoading))
    elseif editingObjectData then
        DebugLog("EDIT", "In editing mode, showing editing message")
        SendNUIMessage({action = 'editingModeUpdate', message = "Keyboard Edit Active. Enter:Save, Esc:Cancel.", editingActive = true})
    elseif not placing and not isMenuLoading then
        -- Only allow menu opening when freecam is not active and not already loading
        if not isFreecamActive then
            -- Direct server admin check - no complex client-side logic
            DebugLog("MENU", "ToggleMenu called - requesting admin permission")
            isMenuLoading = true
            TriggerServerEvent("bazq-objectplace:checkAdminPermission")
        else
            DebugLog("MENU", "Cannot open menu - freecam is active")
        end
    else
        DebugLog("MENU", "Cannot open menu - placing:" .. tostring(placing) .. " isMenuLoading:" .. tostring(isMenuLoading))
    end
end

-- Manual F7 test command for debugging (defined after ToggleMenu)
RegisterCommand('testf7', function()
    DPrint("MENU", "🧪 TESTING F7 - Direct server admin check...")
    
    -- Clean up any stuck NUI focus
    if IsNuiFocused() then
        DPrint("MENU", "Cleaning up stuck NUI focus from test")
        SetNuiFocus(false, false)
    end
    
    -- Test direct server admin check (same as F7)
    DPrint("MENU", "Triggering server admin permission check")
    isMenuLoading = true
    TriggerServerEvent("bazq-objectplace:checkAdminPermission")
    
    TriggerEvent('chat:addMessage', {
        color = { 255, 255, 0 },
        args = { "[F7-TEST]", "🧪 Testing F7 admin check - wait for server response..." }
    })
end, false)

-- Debug command to check NUI focus status
RegisterCommand('checkfocus', function()
    local focusStatus = IsNuiFocused()
    local menuStatus = isMenuOpen
    local loadingStatus = isMenuLoading
    
    TriggerEvent('chat:addMessage', {
        color = { 255, 255, 0 },
        multiline = true,
        args = { "[FOCUS-DEBUG]", 
            string.format("NUI Focus: %s\nMenu Open: %s\nMenu Loading: %s", 
                focusStatus and "✅ YES" or "❌ NO",
                menuStatus and "✅ YES" or "❌ NO", 
                loadingStatus and "⏳ YES" or "❌ NO"
            )
        }
    })
    
    DebugLog("MENU", string.format("Focus Debug - NUI: %s, Menu: %s, Loading: %s", 
        tostring(focusStatus), tostring(menuStatus), tostring(loadingStatus)))
end, false)

-- Manual F6 test command for debugging
RegisterCommand('testf6', function()
    DPrint("FREECAM", "🧪 TESTING F6 PERMISSION...")
    
    -- Test the permission function
    local canUse = CanUseF6Freecam()
    DPrint("FREECAM", "F6 permission result: " .. tostring(canUse))
    
    -- Show result in chat
    TriggerEvent('chat:addMessage', {
        color = canUse and { 0, 255, 0 } or { 255, 0, 0 },
        multiline = true,
        args = { "[F6-TEST]", canUse and "✅ F6 access granted" or "❌ F6 access denied" }
    })
    
    -- If permission granted, try to enable freecam
    if canUse then
        DPrint("FREECAM", "Attempting to enable freecam...")
        if not isFreecamActive then
            ToggleFreecam()
        else
            DPrint("FREECAM", "Freecam already active")
        end
    end
end, false)

-- Debug command to show current config status
RegisterCommand('testconfig', function()
    if debugConfig and debugConfig.testZone then
        local enabled = debugConfig.testZone.enabled
        local inZone = IsPlayerInTestZone()
        
        TriggerEvent('chat:addMessage', {
            color = { 255, 255, 0 },
            multiline = true,
            args = { "[CONFIG-DEBUG]", 
                string.format("TestZone Enabled: %s\nIn Zone: %s\nLogic: %s", 
                    tostring(enabled),
                    tostring(inZone),
                    enabled and "Zone Check" or "Admin Check"
                )
            }
        })
    else
        TriggerEvent('chat:addMessage', {
            color = { 255, 165, 0 },
            args = { "[CONFIG-DEBUG]", "No debug config found!" }
        })
    end
end, false)

-- F6 (Freecam) permission check - SIMPLIFIED ADMIN ONLY
local f6PermissionResponse = nil

function CanUseF6Freecam()
    DebugLog("FREECAM", "🔍 CanUseF6Freecam called - checking admin permissions...")
    
    -- Direct admin check - no TestZone logic - use separate variable for F6
    f6PermissionResponse = nil
    TriggerServerEvent('bazq-objectplace:checkF6Permission')
    
    -- Wait for server response
    local timeout = GetGameTimer() + 2000
    while f6PermissionResponse == nil and GetGameTimer() < timeout do
        Wait(50)
    end
    
    DebugLog("FREECAM", "F6 permission response received: " .. tostring(f6PermissionResponse))
    
    if f6PermissionResponse == true then
        DebugLog("FREECAM", "✅ F6 access GRANTED - Admin permissions")
        TriggerEvent('chat:addMessage', {
            color = { 34, 197, 94 },
            args = { "[bazq-os]", "✅ Admin freecam access granted!" }
        })
        return true
    else
        DebugLog("FREECAM", "❌ F6 access DENIED - No admin permissions")
        TriggerEvent('chat:addMessage', {
            color = { 239, 68, 68 },
            args = { "[bazq-os]", "🔒 Freecam access denied! Admin permissions required." }
        })
        return false
    end
end

local function ToggleFreecam()
    -- This function now assumes permission check is done externally
    -- It simply toggles the freecam state
    
    if not isFreecamActive then
        -- Enable freecam
        SetFreecamActive(true)
        isFreecamActive = true
        
        -- Update UI freecam state first
        SendNUIMessage({action = 'updateFreecamState', isActive = true})
        
        -- Show temporary notification message
        SendNUIMessage({action = 'objectSpawned', message = "Freecam enabled! F6 to disable or click indicator."})
        
        DebugLog("FREECAM", "Freecam enabled")
    else
        -- Disable freecam completely (no permission check needed for disabling)
        SetFreecamActive(false)
        isFreecamActive = false
        
        -- Update UI freecam state first
        SendNUIMessage({action = 'updateFreecamState', isActive = false})
        
        -- Show temporary notification message
        SendNUIMessage({action = 'objectSpawned', message = "Freecam disabled."})
        
        DebugLog("FREECAM", "Freecam disabled")
    end
end

-- NUI Focus Protection Thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- Check every second
        
        -- If menu should be open but focus is lost, restore it
        if isMenuOpen and not IsNuiFocused() and not editingObjectData and not placing then
            DebugLog("MENU", "🔧 FOCUS MONITOR: Menu open but focus lost - restoring")
            SetNuiFocus(true, true)
        end
    end
end)

-- Key bindings for F7 (menu), F6 (freecam), and H (clear selection)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        -- F7 key now handled by RegisterCommand('bazq_f7') with proper permission check
        -- if IsControlJustReleased(0, menuOpenKey) or IsDisabledControlJustReleased(0, menuOpenKey) then
        --     ToggleMenu()
        -- F6 key now handled by RegisterCommand('bazq_f6') with proper permission check
        -- if IsControlJustReleased(0, freecamKey) or IsDisabledControlJustReleased(0, freecamKey) then
        --     ToggleFreecam()
        if IsControlJustReleased(0, 74) and not isMenuOpen and not placing and not editingObjectData then -- H key
            if highlightedObjectIndex then
                ClearAllHighlights()
                -- Show temporary notification
                local wasUIVisible = isMenuOpen
                if not wasUIVisible then
                    SendNUIMessage({action = 'show'})
                end
                SendNUIMessage({action = 'objectSpawned', message = "Selection cleared."})
                if not wasUIVisible then
                    Citizen.SetTimeout(1500, function()
                        SendNUIMessage({action = 'hide'})
                    end)
                end
            end
        end
    end
end)

function DrawTxt(text, x,y,s,r,g,b,a,fnt,jst,shd,otl) SetTextFont(fnt or 0);SetTextProportional(0);SetTextScale(s,s);SetTextColour(r,g,b,a);if shd then SetTextDropShadow(2,2,0,0,0)end;if otl then SetTextOutline()end;if jst=="CENTER"then SetTextCentre(true)elseif jst=="RIGHT"then SetTextWrap(0.0,x);SetTextRightJustify(true)end;SetTextEntry("STRING");AddTextComponentString(text);DrawText(x,y) end

function StartPlacingObject(modelName)
    if placing or editingObjectData then CancelPlacing(); if editingObjectData then CancelKeyboardEdit(false) end end
    -- Clear any selection highlighting when starting placement
    ClearAllHighlights()
    placing = true; selectedObject = modelName; manualHeightAdjusted = false
    DebugPlacement("PLACEMENT STARTED - placing set to TRUE for model: " .. modelName)
    local currentRotation = 0.0
    local rotationSnapMode = false -- false = 1° rotation, true = 5° rotation
    SendNUIMessage({action = 'close'}); SetNuiFocus(false, false)
    isMenuOpen = false  -- Reset menu state when starting placement
    SendNUIMessage({action = 'editingModeUpdate', message = "LMB: Place | RMB/ESC: Cancel | Q/E: Rotate (1°) | Mouse Wheel: Height | G: Ground Snap | X: Toggle 5° Mode | R: Reset Rotation | Rotation: 0°", editingActive = true})

    local modelHash = GetHashKey(modelName)
    
    -- Check if model exists first
    if not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
        DebugLog("PLACEMENT", "ERROR: Model " .. modelName .. " is not valid or not found in game files")
        SendNUIMessage({action='showError', message="Model '" .. modelName .. "' not found in game files!"})
        CancelPlacing()
        SetNuiFocus(true,true)
        SendNUIMessage({action='open',objects=objectList,spawnedObjectsForList=GetSerializableSpawnedObjects()})
        SendNUIMessage({action = 'editingModeUpdate', editingActive = false})
        return
    end
    
    -- Show loading message
    SendNUIMessage({action='showLoadingMessage', message="Loading model: " .. modelName .. "..."})
    
    RequestModel(modelHash)
    local sT=GetGameTimer()
    local tO=7000
    while not HasModelLoaded(modelHash) do
        if GetGameTimer()-sT > tO then
            DebugLog("PLACEMENT", "Timeout: "..modelName)
            SendNUIMessage({action='showError',message="Timeout loading model: " .. modelName})
            SendNUIMessage({action='hideLoadingMessage'})
            CancelPlacing()
            SetNuiFocus(true,true)
            SendNUIMessage({action='open',objects=objectList,spawnedObjectsForList=GetSerializableSpawnedObjects()})
            SendNUIMessage({action = 'editingModeUpdate', editingActive = false})
            return
        end
        Citizen.Wait(50)
    end
    -- Hide loading message
    SendNUIMessage({action='hideLoadingMessage'})
    
    -- Add small delay and double-check model is loaded
    Citizen.Wait(100)
    if not HasModelLoaded(modelHash) then
        DebugLog("PLACEMENT", "Model not loaded after wait, requesting again")
        RequestModel(modelHash)
        local retryStart = GetGameTimer()
        while not HasModelLoaded(modelHash) and (GetGameTimer() - retryStart) < 3000 do
            Citizen.Wait(50)
        end
    end
    
    DebugLog("PLACEMENT", "About to create object, model loaded: " .. tostring(HasModelLoaded(modelHash)))
    -- Use extended range when freecam is active
    local spawnDistance = isFreecamActive and 10.0 or 2.5
    objectEntity = CreateObject(modelHash,GetOffsetFromEntityInWorldCoords(PlayerPedId(),0.0,spawnDistance,-0.5),true,true,false)
    if not DoesEntityExist(objectEntity) then
        DebugLog("PLACEMENT", "CreateFail: "..modelName)
        DebugLog("PLACEMENT", "Model hash: " .. tostring(modelHash))
        DebugLog("PLACEMENT", "Model valid: " .. tostring(IsModelValid(modelHash)))
        DebugLog("PLACEMENT", "Model in cdimage: " .. tostring(IsModelInCdimage(modelHash)))
        DebugLog("PLACEMENT", "Object entity: " .. tostring(objectEntity))
        SendNUIMessage({action='showError',message="CreateFail: "..modelName})
        CancelPlacing()
        SetNuiFocus(true,true)
        SendNUIMessage({action='open',objects=objectList,spawnedObjectsForList=GetSerializableSpawnedObjects()})
        SendNUIMessage({action = 'editingModeUpdate', editingActive = false})
        return
    end
    -- Apply green glowing wireframe effect for placement
    SetEntityCollision(objectEntity,false,false)
    SetEntityAlpha(objectEntity,180,false)
    SetEntityProofs(objectEntity, false, false, false, false, false, false, false, false)
    
    -- Set green color tint
    SetEntityRenderScorched(objectEntity, true)
    SetEntityDrawOutline(objectEntity, true)
    SetEntityDrawOutlineColor(104, 182, 91, 255) -- Green outline
    
    Citizen.CreateThread(function()
        local debugCounter = 0
        while placing and objectEntity and DoesEntityExist(objectEntity) do Citizen.Wait(0)
            debugCounter = debugCounter + 1
            
            -- DEBUG: Print every 60 frames (about once per second) + test if controls are working
            if debugCounter % 60 == 1 then
                local playerPed = PlayerPedId()
                local canShoot = not DisablePlayerFiring(PlayerId(), false) -- Test if can shoot
                DisablePlayerFiring(PlayerId(), true) -- Re-disable immediately
                
                DebugLog("PLACEMENT", "PLACEMENT ACTIVE (frame " .. debugCounter .. ") - placing=" .. tostring(placing) .. ", canShoot=" .. tostring(canShoot))
                DebugLog("PLACEMENT", "Current weapon: " .. GetSelectedPedWeapon(playerPed))
            end
            
            -- CRITICAL: Force disable ALL combat controls during placement - MULTIPLE GROUPS
            -- Group 0 (Main controls)
            DisableControlAction(0, 24, true)   -- INPUT_ATTACK (Left Click/Fire) - CRITICAL
            DisableControlAction(0, 25, true)   -- INPUT_AIM (Right Click/Aim) - CRITICAL
            DisableControlAction(0, 68, true)   -- INPUT_AIM_DOWN_SIGHT (Aim Down Sight)
            DisableControlAction(0, 140, true)  -- INPUT_MELEE_ATTACK_LIGHT (R key)
            DisableControlAction(0, 141, true)  -- INPUT_MELEE_ATTACK_HEAVY (O key)
            DisableControlAction(0, 142, true)  -- INPUT_MELEE_ATTACK_ALTERNATE (Left Alt)
            DisableControlAction(0, 37, true)   -- INPUT_SELECT_WEAPON (Tab - Weapon Wheel)
            DisableControlAction(0, 47, true)   -- INPUT_WEAPON_WHEEL_UD (Weapon Wheel)
            DisableControlAction(0, 91, true)   -- INPUT_VEH_DUCK (Duck/Cover/Grenades)
            DisableControlAction(0, 182, true)  -- INPUT_CELLPHONE_OPTION (Grenade throw)
            
            -- Group 1 (Secondary controls - some mods use this)
            DisableControlAction(1, 24, true)   -- INPUT_ATTACK
            DisableControlAction(1, 25, true)   -- INPUT_AIM
            DisableControlAction(1, 140, true)  -- INPUT_MELEE_ATTACK_LIGHT
            DisableControlAction(1, 141, true)  -- INPUT_MELEE_ATTACK_HEAVY
            
            -- Group 2 (Third group - comprehensive coverage)
            DisableControlAction(2, 24, true)   -- INPUT_ATTACK
            DisableControlAction(2, 25, true)   -- INPUT_AIM
            
            -- AGGRESSIVE APPROACH: Disable ped from shooting using natives
            local playerPed = PlayerPedId()
            SetPedCanSwitchWeapon(playerPed, false)  -- Prevent weapon switching
            DisablePlayerFiring(PlayerId(), true)   -- Disable firing completely
            SetPlayerCanDoDriveBy(PlayerId(), false) -- Disable drive-by shooting
            
            -- Block weapon damage
            SetEntityProofs(playerPed, false, true, false, false, false, false, false, false)  -- Bullet proof
            
            -- Disable cover system during placement
            DisableControlAction(0, 44, true) -- INPUT_COVER (Q key)
            
            -- Advanced XYZ arrows for placement mode too!
            local oC=GetEntityCoords(objectEntity);local rV,fV,uV=GetEntityMatrix(objectEntity)
            DrawAdvancedXYZArrows(objectEntity, oC, rV, fV, uV)
            
            -- Get current rotation for display
            currentRotation = GetEntityHeading(objectEntity)
            
            -- Special handling for wall attachment objects
            if RequiresWallAttachment(selectedObject) then
                local nearbyWall, wallIndex = FindNearbyWall(GetEntityCoords(objectEntity), 3.0)
                if nearbyWall then
                    -- Snap to wall position and rotation
                    local wallCoords = GetEntityCoords(nearbyWall.entity)
                    local wallHeading = GetEntityHeading(nearbyWall.entity)
                    SetEntityCoords(objectEntity, wallCoords.x, wallCoords.y, wallCoords.z)
                    SetEntityHeading(objectEntity, wallHeading)
                    -- Brighter green when attached to wall
                    SetEntityAlpha(objectEntity, 220, false)
                    SetEntityDrawOutlineColor(104, 255, 91, 255) -- Brighter green outline
                else
                    -- No wall nearby, make it red and transparent
                    SetEntityAlpha(objectEntity, 120, false)
                    SetEntityDrawOutlineColor(255, 91, 91, 255) -- Red outline for invalid placement
                    local cH,hC=RaycastFromCamera()
                    if cH then
                        SetEntityCoords(objectEntity,hC.x,hC.y,hC.z)
                    else
                        -- Use freecam position when active, otherwise player position
                        if IsFreecamActive() then
                            local freecamPos = GetFreecamPosition()
                            local freecamRot = GetFreecamRotation()
                            local forwardX = -math.sin(math.rad(freecamRot.z))
                            local forwardY = math.cos(math.rad(freecamRot.z))
                            local spawnPos = vector3(
                                freecamPos.x + (forwardX * 5.0),
                                freecamPos.y + (forwardY * 5.0),
                                freecamPos.z
                            )
                            SetEntityCoords(objectEntity, spawnPos.x, spawnPos.y, spawnPos.z)
                        else
                            SetEntityCoords(objectEntity,GetOffsetFromEntityInWorldCoords(PlayerPedId(),0.0,3.0,-0.5))
                        end
                    end
                end
            else
                -- Normal placement for non-wall-attachment objects
                local cH,hC=RaycastFromCamera()
                if cH then
                    local currentCoords = GetEntityCoords(objectEntity)
                    
                    if manualHeightAdjusted and not currentPlacementOptions.snapToGround then
                        -- Keep current height, only update X/Y
                        SetEntityCoords(objectEntity, hC.x, hC.y, currentCoords.z)
                    else
                        -- Normal raycast positioning
                        SetEntityCoords(objectEntity, hC.x, hC.y, hC.z)
                        if currentPlacementOptions.snapToGround then
                            AlignObjectToGround(objectEntity)
                        end
                    end
                else
                    -- Use freecam position when active, otherwise player position
                    if IsFreecamActive() then
                        local freecamPos = GetFreecamPosition()
                        local freecamRot = GetFreecamRotation()
                        local forwardX = -math.sin(math.rad(freecamRot.z))
                        local forwardY = math.cos(math.rad(freecamRot.z))
                        local spawnPos = vector3(
                            freecamPos.x + (forwardX * 5.0),
                            freecamPos.y + (forwardY * 5.0),
                            freecamPos.z
                        )
                        SetEntityCoords(objectEntity, spawnPos.x, spawnPos.y, spawnPos.z)
                    else
                        SetEntityCoords(objectEntity,GetOffsetFromEntityInWorldCoords(PlayerPedId(),0.0,3.0,-0.5))
                    end
                end
            end
            
            if IsDisabledControlJustReleased(0,24)then ConfirmPlacement()end;if IsDisabledControlJustReleased(0,25)or IsDisabledControlJustReleased(0,322)then CancelPlacing()end
            
            -- Toggle rotation snap mode with X key
            if IsDisabledControlJustReleased(0, 73) then -- X key
                rotationSnapMode = not rotationSnapMode
                local modeText = rotationSnapMode and "5°" or "1°"
                SendNUIMessage({action = 'editingModeUpdate', message = "LMB: Place | RMB/ESC: Cancel | Q/E: Rotate (" .. modeText .. ") | Mouse Wheel: Height | G: Ground Snap | X: Toggle 5° Mode | R: Reset Rotation | Rotation: " .. math.floor(currentRotation) .. "°", editingActive = true})
            end
            
            -- Rotation controls with dynamic step size
            local rS = rotationSnapMode and 5.0 or 1.0
            if IsDisabledControlPressed(0,44) then
                SetEntityHeading(objectEntity, GetEntityHeading(objectEntity) + rS)
                currentRotation = GetEntityHeading(objectEntity)
            end
            if IsDisabledControlPressed(0,38) then
                SetEntityHeading(objectEntity, GetEntityHeading(objectEntity) - rS)
                currentRotation = GetEntityHeading(objectEntity)
            end
            
            -- Reset rotation with R key
            if IsDisabledControlJustReleased(0, 45) then -- R key
                SetEntityHeading(objectEntity, 0.0)
                currentRotation = 0.0
                local modeText = rotationSnapMode and "5°" or "1°"
                SendNUIMessage({action = 'editingModeUpdate', message = "LMB: Place | RMB/ESC: Cancel | Q/E: Rotate (" .. modeText .. ") | Mouse Wheel: Height | G: Ground Snap | X: Toggle 5° Mode | R: Reset Rotation | Rotation: 0°", editingActive = true})
            end
            
            -- Update rotation display when manually rotating
            if IsDisabledControlPressed(0,44) or IsDisabledControlPressed(0,38) then
                local modeText = rotationSnapMode and "5°" or "1°"
                SendNUIMessage({action = 'editingModeUpdate', message = "LMB: Place | RMB/ESC: Cancel | Q/E: Rotate (" .. modeText .. ") | Mouse Wheel: Height | G: Ground Snap | X: Toggle 5° Mode | R: Reset Rotation | Rotation: " .. math.floor(currentRotation) .. "°", editingActive = true})
            end
            
            -- Height adjustment with mouse wheel
            local currentCoords = GetEntityCoords(objectEntity)
            if IsDisabledControlJustReleased(0, 241) then -- Mouse wheel up
                SetEntityCoords(objectEntity, currentCoords.x, currentCoords.y, currentCoords.z + 0.1, false, false, false, true)
                manualHeightAdjusted = true
            elseif IsDisabledControlJustReleased(0, 242) then -- Mouse wheel down
                SetEntityCoords(objectEntity, currentCoords.x, currentCoords.y, currentCoords.z - 0.1, false, false, false, true)
                manualHeightAdjusted = true
            end
            
            -- Toggle snap to ground with G key
            if IsDisabledControlJustReleased(0, 47) then -- G key
                currentPlacementOptions.snapToGround = not currentPlacementOptions.snapToGround
                manualHeightAdjusted = false -- Reset height adjustment flag when toggling
                local status = currentPlacementOptions.snapToGround and "ON" or "OFF"
                SendNUIMessage({action = 'objectSpawned', message = "Ground Snap: " .. status})
                -- print("[OP] Ground snap toggled: " .. status)
            end
        end
    end)
end

function CancelPlacing()
    placing=false
    DebugLog("PLACEMENT", "PLACEMENT CANCELLED - placing set to FALSE, re-enabling combat")
    
    -- Re-enable combat capabilities
    local playerPed = PlayerPedId()
    SetPedCanSwitchWeapon(playerPed, true)   -- Re-enable weapon switching
    DisablePlayerFiring(PlayerId(), false)  -- Re-enable firing
    SetPlayerCanDoDriveBy(PlayerId(), true)  -- Re-enable drive-by shooting
    SetEntityProofs(playerPed, false, false, false, false, false, false, false, false)  -- Remove bullet proof
    if objectEntity and DoesEntityExist(objectEntity) then
        -- Clean up visual effects before deleting
        ResetEntityAlpha(objectEntity)
        SetEntityDrawOutline(objectEntity, false)
        SetEntityRenderScorched(objectEntity, false)
        DeleteEntity(objectEntity)
    end
    objectEntity=nil;selectedObject=nil
    SendNUIMessage({action = 'editingModeUpdate', editingActive = false})
    
    -- Auto-return to menu after placement cancellation
    Citizen.SetTimeout(300, function()
        if not placing and not editingObjectData then
            SetNuiFocus(true, true)
            isMenuOpen = true  -- Set menu as open
            SendNUIMessage({
                action = 'open',
                objects = objectList,
                spawnedObjectsForList = GetSerializableSpawnedObjects(),
                userSettings = currentUserSettings
            })
        end
    end)
end

function ConfirmPlacement()
    if placing and objectEntity and DoesEntityExist(objectEntity) then
        placing=false
        DebugLog("PLACEMENT", "PLACEMENT CONFIRMED - placing set to FALSE, re-enabling combat")
        
        -- Re-enable combat capabilities
        local playerPed = PlayerPedId()
        SetPedCanSwitchWeapon(playerPed, true)   -- Re-enable weapon switching
        DisablePlayerFiring(PlayerId(), false)  -- Re-enable firing
        SetPlayerCanDoDriveBy(PlayerId(), true)  -- Re-enable drive-by shooting
        SetEntityProofs(playerPed, false, false, false, false, false, false, false, false)  -- Remove bullet proof
        
        NetworkRequestControlOfEntity(objectEntity);local att=0
        while not NetworkHasControlOfEntity(objectEntity)and att<50 do Citizen.Wait(10);att=att+1 end
        if NetworkHasControlOfEntity(objectEntity)then
            SetEntityAsMissionEntity(objectEntity,true,true)
            SetEntityDynamic(objectEntity,false)
            SetEntityCollision(objectEntity,true,true)
            -- Remove all visual effects
            ResetEntityAlpha(objectEntity)
            SetEntityDrawOutline(objectEntity, false)
            SetEntityRenderScorched(objectEntity, false)
        else
            DebugLog("GENERAL", "Warn: No net control.")
            SetEntityDynamic(objectEntity,false)
            SetEntityCollision(objectEntity,true,true)
            -- Remove all visual effects
            ResetEntityAlpha(objectEntity)
            SetEntityDrawOutline(objectEntity, false)
            SetEntityRenderScorched(objectEntity, false)
        end
        Citizen.Wait(0)
        
        local mainCoords = GetEntityCoords(objectEntity)
        local mainHeading = GetEntityHeading(objectEntity)
        local interiorEntity = nil
        
        -- Handle tower objects - spawn ladder automatically
        if selectedObject == "bazq-kule1" or selectedObject == "bazq-kule2" then
            DebugLog("PLACEMENT", "Placing tower ladder for " .. selectedObject)
            
            -- Spawn ladder automatically at the same location
            local ladderHash = GetHashKey("bazq-kule_ladder")
            RequestModel(ladderHash)
            local startTime = GetGameTimer()
            while not HasModelLoaded(ladderHash) do
                if GetGameTimer() - startTime > 5000 then
                    DebugLog("PLACEMENT", "Timeout loading ladder model for " .. selectedObject)
                    break
                end
                Citizen.Wait(50)
            end
            
            if HasModelLoaded(ladderHash) then
                -- Spawn ladder at same position as tower
                interiorEntity = CreateObject(ladderHash, mainCoords.x, mainCoords.y, mainCoords.z, true, true, false)
                if DoesEntityExist(interiorEntity) then
                    SetEntityHeading(interiorEntity, mainHeading)
                    SetEntityAsMissionEntity(interiorEntity, true, true)
                    SetEntityDynamic(interiorEntity, false)
                    SetEntityCollision(interiorEntity, true, true)
                    DebugLog("PLACEMENT", "Created ladder for " .. selectedObject)
                end
            end
        end
        
        -- Handle wall objects that need fence
        if selectedObject:match("bazq%-sur[1-5]") then
            DebugLog("PLACEMENT", "Placing fence for " .. selectedObject)
            
            -- Spawn fence automatically at the same location
            local fenceHash = GetHashKey("bazq-surfence")
            RequestModel(fenceHash)
            local startTime = GetGameTimer()
            while not HasModelLoaded(fenceHash) do
                if GetGameTimer() - startTime > 5000 then
                    DebugLog("PLACEMENT", "Timeout loading fence model for " .. selectedObject)
                    break
                end
                Citizen.Wait(50)
            end
            
            if HasModelLoaded(fenceHash) then
                -- Spawn fence at same position as wall with Z offset
                interiorEntity = CreateObject(fenceHash, mainCoords.x, mainCoords.y, mainCoords.z + 5, true, true, false)
                if DoesEntityExist(interiorEntity) then
                    SetEntityHeading(interiorEntity, mainHeading)
                    SetEntityAsMissionEntity(interiorEntity, true, true)
                    SetEntityDynamic(interiorEntity, false)
                    SetEntityCollision(interiorEntity, true, true)
                    DebugLog("PLACEMENT", "Created fence for " .. selectedObject)
                end
            end
        end
        
        -- Handle gate object that needs doors (automatically create doors for gate frames)
        if selectedObject == "bazq-sur_kapi" then
            DebugLog("PLACEMENT", "Automatically placing doors for gate frame " .. selectedObject)
            
            -- Spawn 2 doors with Y offset
            local doorHash = GetHashKey("bazq-sur_mkapi")
            RequestModel(doorHash)
            local startTime = GetGameTimer()
            while not HasModelLoaded(doorHash) do
                if GetGameTimer() - startTime > 5000 then
                    DebugLog("PLACEMENT", "Timeout loading door model for " .. selectedObject)
                    break
                end
                Citizen.Wait(50)
            end
            
            if HasModelLoaded(doorHash) then
                -- Calculate forward direction based on heading
                local headingRad = math.rad(mainHeading)
                local forwardX = -math.sin(headingRad)
                local forwardY = math.cos(headingRad)
                
                -- Spawn first door with positive Y offset and +90 degree rotation
                local door1Coords = vector3(
                    mainCoords.x + (5.37824 * forwardX),
                    mainCoords.y + (5.37824 * forwardY),
                    mainCoords.z
                )
                local door1Entity = CreateObject(doorHash, door1Coords.x, door1Coords.y, door1Coords.z, true, true, false)
                if DoesEntityExist(door1Entity) then
                    SetEntityHeading(door1Entity, mainHeading + 90.0)
                    SetEntityAsMissionEntity(door1Entity, true, true)
                    SetEntityDynamic(door1Entity, true) -- Enable door physics
                    SetEntityCollision(door1Entity, true, true)
                    DebugLog("PLACEMENT", "Created first door for " .. selectedObject .. " with +90° rotation")
                end
                
                -- Spawn second door with negative Y offset and -90 degree rotation
                local door2Coords = vector3(
                    mainCoords.x - (5.37824 * forwardX),
                    mainCoords.y - (5.37824 * forwardY),
                    mainCoords.z
                )
                local door2Entity = CreateObject(doorHash, door2Coords.x, door2Coords.y, door2Coords.z, true, true, false)
                if DoesEntityExist(door2Entity) then
                    SetEntityHeading(door2Entity, mainHeading - 90.0)
                    SetEntityAsMissionEntity(door2Entity, true, true)
                    SetEntityDynamic(door2Entity, true) -- Enable door physics
                    SetEntityCollision(door2Entity, true, true)
                    DebugLog("PLACEMENT", "Created second door for " .. selectedObject .. " with -90° rotation")
                end
                
                -- Store both doors as a table instead of just the first one
                if DoesEntityExist(door1Entity) and DoesEntityExist(door2Entity) then
                    interiorEntity = {door1Entity, door2Entity}  -- Store both doors
                elseif DoesEntityExist(door1Entity) then
                    interiorEntity = door1Entity  -- Fallback to single door
                end
            end
        end
        
        -- Handle sign objects that need signpole (using new config system)
        if selectedObject:match("bazq%-wall2_sign%d+") then
            -- Check if object has additional_objects in config
            local objectConfig = nil
            if objectsConfig.packages then
                for _, package in pairs(objectsConfig.packages) do
                    if package.objects then
                        for _, obj in ipairs(package.objects) do
                            if obj.prop == selectedObject then
                                objectConfig = obj
                                break
                            end
                        end
                    end
                    if objectConfig then break end
                end
            end
            
            if objectConfig and objectConfig.additional_objects then
                for _, additionalObj in ipairs(objectConfig.additional_objects) do
                    local additionalModel = GetHashKey(additionalObj.prop)
                    RequestModel(additionalModel)
                    local startTime = GetGameTimer()
                    while not HasModelLoaded(additionalModel) do
                        if GetGameTimer() - startTime > 5000 then
                            DebugLog("PLACEMENT", "Timeout loading additional model " .. additionalObj.prop .. " for " .. selectedObject)
                            break
                        end
                        Citizen.Wait(50)
                    end
                    
                    if HasModelLoaded(additionalModel) then
                        local offset = additionalObj.offset or {x = 0, y = 0, z = 0}
                        local headingOffset = additionalObj.heading_offset or 0
                        
                        -- Calculate offset relative to sign's heading (forward direction)
                        local headingRad = math.rad(mainHeading)
                        local forwardX = -math.sin(headingRad)
                        local forwardY = math.cos(headingRad)
                        
                        local spawnCoords = vector3(
                            mainCoords.x + (offset.x * math.cos(headingRad)) + (offset.y * forwardX),
                            mainCoords.y + (offset.x * math.sin(headingRad)) + (offset.y * forwardY),
                            mainCoords.z + offset.z
                        )
                        
                        interiorEntity = CreateObject(additionalModel, spawnCoords.x, spawnCoords.y, spawnCoords.z, true, true, false)
                        if DoesEntityExist(interiorEntity) then
                            SetEntityHeading(interiorEntity, mainHeading + headingOffset)
                            SetEntityAsMissionEntity(interiorEntity, true, true)
                            SetEntityDynamic(interiorEntity, false)
                            SetEntityCollision(interiorEntity, true, true)
                            -- print("[OP] Created " .. additionalObj.prop .. " for " .. selectedObject .. " with heading offset " .. headingOffset)
                        end
                    end
                end
            else
                -- Fallback to old system
                local signpoleModel = GetHashKey("bazq-wall2_signpole")
                RequestModel(signpoleModel)
                local startTime = GetGameTimer()
                while not HasModelLoaded(signpoleModel) do
                    if GetGameTimer() - startTime > 5000 then
                        DebugLog("PLACEMENT", "Timeout loading signpole model for " .. selectedObject)
                        break
                    end
                    Citizen.Wait(50)
                end
                
                if HasModelLoaded(signpoleModel) then
                    -- Apply 3cm offset forward from the sign using proper heading calculation
                    local headingRad = math.rad(mainHeading)
                    local forwardX = -math.sin(headingRad)
                    local forwardY = math.cos(headingRad)
                    local offsetCoords = vector3(
                        mainCoords.x + (0.03 * forwardX),
                        mainCoords.y + (0.03 * forwardY),
                        mainCoords.z
                    )
                    
                    interiorEntity = CreateObject(signpoleModel, offsetCoords.x, offsetCoords.y, offsetCoords.z, true, true, false)
                    if DoesEntityExist(interiorEntity) then
                        SetEntityHeading(interiorEntity, mainHeading) -- No rotation offset
                        SetEntityAsMissionEntity(interiorEntity, true, true)
                        SetEntityDynamic(interiorEntity, false)
                        SetEntityCollision(interiorEntity, true, true)
                        -- print("[OP] Created signpole for " .. selectedObject .. " (fallback with 3cm offset)")
                    end
                end
            end
        end
        
        -- Handle door physics for gates and mkapi (make them dynamic)
        if selectedObject == "bazq-sur_mkapi" or selectedObject:match("bazq%-wall2_gate%d+") then
            SetEntityDynamic(objectEntity, true)
            -- print("[OP] Enabled door physics for " .. selectedObject)
        else
            -- Ensure all other objects are static
            SetEntityDynamic(objectEntity, false)
        end
        
        -- Handle wall attachment objects (decals and fence)
        if RequiresWallAttachment(selectedObject) then
            local nearbyWall, wallIndex = FindNearbyWall(mainCoords, 3.0)
            if not nearbyWall then
                -- No wall found, cancel placement
                DeleteEntity(objectEntity)
                if interiorEntity then
                    if type(interiorEntity) == "table" then
                        -- Handle dual doors
                        for _, doorEntity in ipairs(interiorEntity) do
                            if DoesEntityExist(doorEntity) then
                                DeleteEntity(doorEntity)
                            end
                        end
                    elseif DoesEntityExist(interiorEntity) then
                        DeleteEntity(interiorEntity)
                    end
                end
                SendNUIMessage({action = 'showError', message = "Wall decals/fence must be placed near a wall!"})
                placing = false
                DebugLog("PLACEMENT", "PLACEMENT FAILED (wall attachment) - placing set to FALSE, re-enabling combat")
                
                -- Re-enable combat capabilities
                local playerPed = PlayerPedId()
                SetPedCanSwitchWeapon(playerPed, true)   -- Re-enable weapon switching
                DisablePlayerFiring(PlayerId(), false)  -- Re-enable firing
                SetPlayerCanDoDriveBy(PlayerId(), true)  -- Re-enable drive-by shooting
                SetEntityProofs(playerPed, false, false, false, false, false, false, false, false)  -- Remove bullet proof
                
                objectEntity = nil
                selectedObject = nil
                SendNUIMessage({action = 'editingModeUpdate', editingActive = false})
                return
            else
                -- Snap to wall position and rotation
                local wallCoords = GetEntityCoords(nearbyWall.entity)
                local wallHeading = GetEntityHeading(nearbyWall.entity)
                SetEntityCoords(objectEntity, wallCoords.x, wallCoords.y, wallCoords.z, false, false, false, true)
                SetEntityHeading(objectEntity, wallHeading)
                mainCoords = wallCoords
                mainHeading = wallHeading
                DebugLog("PLACEMENT", "Attached " .. selectedObject .. " to wall at index " .. wallIndex)
            end
        end
        
        -- Store the main object
        local objectData = {
            entity=objectEntity,
            model=selectedObject,
            coords=mainCoords,
            heading=mainHeading,
            timestamp=GetRealTimestamp(), -- Real Unix timestamp from web
            playerName=currentPlacementOptions.playerName or "Unknown"
        }
        
        -- Store interior info if it exists
        if interiorEntity then
            if interiorEntity == "collision_requested" then
                objectData.interiorModel = "bazq-kule_int-col"
                objectData.hasCollision = true
                DebugLog("PLACEMENT", "Stored collision info for " .. selectedObject)
            else
                -- Handle multiple doors (stored as table) vs single interior entity
                if type(interiorEntity) == "table" then
                    -- Multiple doors case (gate doors)
                    objectData.interiorEntity = interiorEntity
                    objectData.interiorModel = "bazq-sur_mkapi"
                    objectData.hasDualDoors = true  -- Flag to indicate dual doors
                    DebugLog("PLACEMENT", "Stored dual gate door entities for " .. selectedObject)
                else
                    -- Single interior entity case
                    objectData.interiorEntity = interiorEntity
                    if selectedObject:match("bazq%-wall2_sign%d+") then
                        objectData.interiorModel = "bazq-wall2_signpole"
                    elseif selectedObject == "bazq-kule1" or selectedObject == "bazq-kule2" then
                        objectData.interiorModel = "bazq-kule_ladder"
                        DebugLog("PLACEMENT", "Stored tower ladder entity for " .. selectedObject)
                    elseif selectedObject:match("bazq%-sur[1-5]") then
                        objectData.interiorModel = "bazq-surfence"
                        DebugLog("PLACEMENT", "Stored wall fence entity for " .. selectedObject)
                    elseif selectedObject == "bazq-sur_kapi" then
                        objectData.interiorModel = "bazq-sur_mkapi"
                        DebugLog("PLACEMENT", "Stored single gate door entity for " .. selectedObject)
                    end
                end
            end
        end
        
        table.insert(spawnedObjects, objectData)
        SaveObjectsToServer();SendNUIMessage({action="updateSpawnedList",data=GetSerializableSpawnedObjects()})
        
        
        objectEntity=nil;selectedObject=nil
        SendNUIMessage({action = 'editingModeUpdate', editingActive = false})
        
        -- Auto-return to menu after placement (if setting enabled)
        Citizen.SetTimeout(300, function()
            if not placing and not editingObjectData then
                -- Check if user wants menu to stay open after placement
                local keepMenuOpen = false
                if currentUserSettings and currentUserSettings.keepMenuOpen then
                    keepMenuOpen = currentUserSettings.keepMenuOpen
                end
                
                -- Fallback: check NUI localStorage via callback
                if not keepMenuOpen then
                    -- Send a quick request to check localStorage
                    SendNUIMessage({
                        action = 'checkKeepMenuOpen'
                    })
                end
                
                DebugLog("PLACEMENT", "Keep menu open check - currentUserSettings: " .. tostring(currentUserSettings and "exists" or "nil"))
                if currentUserSettings then
                    DebugLog("PLACEMENT", "keepMenuOpen setting: " .. tostring(currentUserSettings.keepMenuOpen))
                end
                DebugLog("PLACEMENT", "Final keepMenuOpen decision: " .. tostring(keepMenuOpen))
                
                if keepMenuOpen then
                    SetNuiFocus(true, true)
                    isMenuOpen = true  -- Set menu as open
                    SendNUIMessage({
                        action = 'open',
                        objects = objectList,
                        spawnedObjectsForList = GetSerializableSpawnedObjects(),
                        userSettings = currentUserSettings
                    })
                end
            end
        end)
    end
end

function KeyboardEditLoop()
    if not editingObjectData or not editingObjectData.entity or not DoesEntityExist(editingObjectData.entity) then editingObjectData=nil; return end
    local ent = editingObjectData.entity
    SetEntityCollision(ent, false, false)
    FreezeEntityPosition(PlayerPedId(), true) -- Freeze player ped
    
    -- Apply green glowing wireframe effect for editing
    SetEntityAlpha(ent, 180, false)
    SetEntityDrawOutline(ent, true)
    SetEntityDrawOutlineColor(104, 182, 91, 255) -- Green outline
    SetEntityRenderScorched(ent, true)

    local nudgeSpeed, rotationSpeed = 0.02, 1.0
    local currentRotation = GetEntityHeading(ent)
    local rotationSnapMode = false -- false = 1° rotation, true = 5° rotation

    while editingObjectData and editingObjectData.entity == ent and DoesEntityExist(ent) do
        Citizen.Wait(0)
        
        -- Disable cover system during editing so Q key works for rotation
        DisableControlAction(0, 44, true) -- INPUT_COVER (Q key)
        
        local currentCoords, currentHeading = GetEntityCoords(ent), GetEntityHeading(ent)
        local rightVec, fwdVec, upVec = GetEntityMatrix(ent)
        currentRotation = currentHeading
        
        -- Enhanced XYZ arrows for edit mode - much better than placement mode!
        DrawAdvancedXYZArrows(ent, currentCoords, rightVec, fwdVec, upVec)
        
        -- Keyboard movement controls (using disabled controls to avoid conflicts)
        if IsDisabledControlPressed(0, 32) then SetEntityCoords(ent, currentCoords + fwdVec * nudgeSpeed, false, false, false, true) end -- W
        if IsDisabledControlPressed(0, 33) then SetEntityCoords(ent, currentCoords - fwdVec * nudgeSpeed, false, false, false, true) end -- S
        if IsDisabledControlPressed(0, 30) then SetEntityCoords(ent, currentCoords - rightVec * nudgeSpeed, false, false, false, true) end -- A
        if IsDisabledControlPressed(0, 31) then SetEntityCoords(ent, currentCoords + rightVec * nudgeSpeed, false, false, false, true) end -- D
        
        -- Height controls (Alt/F)
        if IsDisabledControlPressed(0, 19) then SetEntityCoords(ent, currentCoords + upVec * nudgeSpeed, false, false, false, true) end    -- Alt key - Up
        if IsDisabledControlPressed(0, 23) then SetEntityCoords(ent, currentCoords - upVec * nudgeSpeed, false, false, false, true) end    -- F key - Down
        
        -- Save with LMB, Cancel with RMB
        if IsDisabledControlJustReleased(0, 24) then ApplyKeyboardEdit(); break end -- LMB
        if IsDisabledControlJustReleased(0, 25) then CancelKeyboardEdit(true); break end -- RMB
        
        -- Toggle rotation snap mode with X key
        if IsDisabledControlJustReleased(0, 73) then -- X key
            rotationSnapMode = not rotationSnapMode
            local modeText = rotationSnapMode and "5°" or "1°"
            SendNUIMessage({action = 'editingModeUpdate', message = "EDIT MODE: WASD:Move | Alt/F:Height | Q/E:Rotate (" .. modeText .. ") | G:Snap Toggle | X:Toggle 5° Mode | R:Reset Rotation | LMB:Save | RMB:Cancel | Rotation: " .. math.floor(currentRotation) .. "°", editingActive = true})
        end
        
        -- Rotation controls (Q/E) with dynamic step size
        local dynamicRotationSpeed = rotationSnapMode and 5.0 or 1.0
        if IsDisabledControlPressed(0, 44) then
            SetEntityHeading(ent, currentHeading + dynamicRotationSpeed)
            currentRotation = GetEntityHeading(ent)
        end -- Q key - Rotate left
        if IsDisabledControlPressed(0, 38) then
            SetEntityHeading(ent, currentHeading - dynamicRotationSpeed)
            currentRotation = GetEntityHeading(ent)
        end -- E key - Rotate right
        
        -- Reset rotation with R key
        if IsDisabledControlJustReleased(0, 45) then -- R key
            SetEntityHeading(ent, 0.0)
            currentRotation = 0.0
            local modeText = rotationSnapMode and "5°" or "1°"
            SendNUIMessage({action = 'editingModeUpdate', message = "EDIT MODE: WASD:Move | Alt/F:Height | Q/E:Rotate (" .. modeText .. ") | G:Snap Toggle | X:Toggle 5° Mode | R:Reset Rotation | LMB:Save | RMB:Cancel | Rotation: 0°", editingActive = true})
        end
        
        -- Update rotation display when manually rotating
        if IsDisabledControlPressed(0,44) or IsDisabledControlPressed(0,38) then
            local modeText = rotationSnapMode and "5°" or "1°"
            SendNUIMessage({action = 'editingModeUpdate', message = "EDIT MODE: WASD:Move | Alt/F:Height | Q/E:Rotate (" .. modeText .. ") | G:Snap Toggle | X:Toggle 5° Mode | R:Reset Rotation | LMB:Save | RMB:Cancel | Rotation: " .. math.floor(currentRotation) .. "°", editingActive = true})
        end
        
        -- Snap to ground toggle with G key in edit mode
        if IsControlJustReleased(0, 47) then -- G key
            currentPlacementOptions.snapToGround = not currentPlacementOptions.snapToGround
            local status = currentPlacementOptions.snapToGround and "ON" or "OFF"
            SendNUIMessage({action = 'objectSpawned', message = "Ground Snap: " .. status})
            -- print("[OP] Edit mode ground snap toggled: " .. status)
            
            -- Apply snap immediately if enabled
            if currentPlacementOptions.snapToGround then
                AlignObjectToGround(ent)
            end
        end
        
        -- Old Enter/Esc controls removed - now using LMB/RMB above
    end
    
    FreezeEntityPosition(PlayerPedId(), false) -- Unfreeze player ped
    if DoesEntityExist(ent) then
        SetEntityCollision(ent, true, true)
        -- Restore normal appearance
        ResetEntityAlpha(ent)
        SetEntityDrawOutline(ent, false)
        SetEntityRenderScorched(ent, false)
    end
end

function ApplyKeyboardEdit()
    FreezeEntityPosition(PlayerPedId(), false) -- Ensure player is unfrozen
    if editingObjectData and editingObjectData.entity and DoesEntityExist(editingObjectData.entity) then
        local ent = editingObjectData.entity
        local newCoords = GetEntityCoords(ent)
        local newHeading = GetEntityHeading(ent)
        

        
        -- Restore object to normal state
        SetEntityCollision(ent, true, true)
        SetEntityDynamic(ent, true)
        ResetEntityAlpha(ent)
        SetEntityDrawOutline(ent, false)
        SetEntityRenderScorched(ent, false)
        
        -- Update main object data
        spawnedObjects[editingObjectData.originalIndex].coords = newCoords
        spawnedObjects[editingObjectData.originalIndex].heading = newHeading
        
        -- Update interior entity if it exists
        local objData = spawnedObjects[editingObjectData.originalIndex]
        if objData.interiorEntity then
            if type(objData.interiorEntity) == "table" then
                -- Handle dual doors
                if objData.hasDualDoors then
                    local headingRad = math.rad(newHeading)
                    local forwardX = -math.sin(headingRad)
                    local forwardY = math.cos(headingRad)
                    
                    -- Update first door (positive Y offset, +90 rotation)
                    if DoesEntityExist(objData.interiorEntity[1]) then
                        local door1Coords = vector3(
                            newCoords.x + (5.37824 * forwardX),
                            newCoords.y + (5.37824 * forwardY),
                            newCoords.z
                        )
                        SetEntityCoords(objData.interiorEntity[1], door1Coords.x, door1Coords.y, door1Coords.z, false, false, false, true)
                        SetEntityHeading(objData.interiorEntity[1], newHeading + 90.0)
                    end
                    
                    -- Update second door (negative Y offset, -90 rotation)
                    if DoesEntityExist(objData.interiorEntity[2]) then
                        local door2Coords = vector3(
                            newCoords.x - (5.37824 * forwardX),
                            newCoords.y - (5.37824 * forwardY),
                            newCoords.z
                        )
                        SetEntityCoords(objData.interiorEntity[2], door2Coords.x, door2Coords.y, door2Coords.z, false, false, false, true)
                        SetEntityHeading(objData.interiorEntity[2], newHeading - 90.0)
                    end
                end
            elseif DoesEntityExist(objData.interiorEntity) then
                -- Check if this is a sign with signpole that needs proper offset calculation
                if editingObjectData.model:match("bazq%-wall2_sign%d+") then
                    -- Calculate proper offset for signpole based on new heading
                    local headingRad = math.rad(newHeading)
                    local forwardX = -math.sin(headingRad)
                    local forwardY = math.cos(headingRad)
                    local offsetCoords = vector3(
                        newCoords.x + (0.03 * forwardX),
                        newCoords.y + (0.03 * forwardY),
                        newCoords.z
                    )
                    SetEntityCoords(objData.interiorEntity, offsetCoords.x, offsetCoords.y, offsetCoords.z, false, false, false, true)
                else
                    -- For other interior entities (like tower interiors), use same position
                    SetEntityCoords(objData.interiorEntity, newCoords.x, newCoords.y, newCoords.z, false, false, false, true)
                end
                SetEntityHeading(objData.interiorEntity, newHeading)
            end
            -- print("[OP] Updated interior entity position for " .. editingObjectData.model)
        elseif objData.hasCollision then
            -- For collision, request at new position
            RequestCollisionAtCoord(newCoords.x, newCoords.y, newCoords.z)
            -- print("[OP] Updated collision position for " .. editingObjectData.model)
        end
        
        SaveObjectsToServer()
        SendNUIMessage({action = "updateSpawnedList", data = GetSerializableSpawnedObjects()})
        SendNUIMessage({action = 'editingModeUpdate', message = "Object position updated.", isError = false, editingActive = false})
        -- print("[OP] Edit saved: " .. editingObjectData.model)
        
        -- Auto-return to menu after editing
        Citizen.SetTimeout(300, function()
            if not placing and not editingObjectData then
                SetNuiFocus(true, true)
                isMenuOpen = true  -- Set menu as open
                SendNUIMessage({
                    action = 'open',
                    objects = objectList,
                    spawnedObjectsForList = GetSerializableSpawnedObjects(),
                    userSettings = currentUserSettings
                })
            end
        end)
    end
    editingObjectData = nil
end

function CancelKeyboardEdit(revert)
    FreezeEntityPosition(PlayerPedId(), false) -- Ensure player is unfrozen
    if editingObjectData and editingObjectData.entity and DoesEntityExist(editingObjectData.entity) then
        if revert then
            SetEntityCoords(editingObjectData.entity, editingObjectData.originalCoords.x, editingObjectData.originalCoords.y, editingObjectData.originalCoords.z)
            SetEntityHeading(editingObjectData.entity, editingObjectData.originalHeading)
            
            -- Revert interior entity if it exists
            local objData = spawnedObjects[editingObjectData.originalIndex]
            if objData and objData.interiorEntity then
                if type(objData.interiorEntity) == "table" then
                    -- Handle dual doors
                    if objData.hasDualDoors then
                        local headingRad = math.rad(editingObjectData.originalHeading)
                        local forwardX = -math.sin(headingRad)
                        local forwardY = math.cos(headingRad)
                        
                        -- Revert first door (positive Y offset, +90 rotation)
                        if DoesEntityExist(objData.interiorEntity[1]) then
                            local door1Coords = vector3(
                                editingObjectData.originalCoords.x + (5.37824 * forwardX),
                                editingObjectData.originalCoords.y + (5.37824 * forwardY),
                                editingObjectData.originalCoords.z
                            )
                            SetEntityCoords(objData.interiorEntity[1], door1Coords.x, door1Coords.y, door1Coords.z, false, false, false, true)
                            SetEntityHeading(objData.interiorEntity[1], editingObjectData.originalHeading + 90.0)
                        end
                        
                        -- Revert second door (negative Y offset, -90 rotation)
                        if DoesEntityExist(objData.interiorEntity[2]) then
                            local door2Coords = vector3(
                                editingObjectData.originalCoords.x - (5.37824 * forwardX),
                                editingObjectData.originalCoords.y - (5.37824 * forwardY),
                                editingObjectData.originalCoords.z
                            )
                            SetEntityCoords(objData.interiorEntity[2], door2Coords.x, door2Coords.y, door2Coords.z, false, false, false, true)
                            SetEntityHeading(objData.interiorEntity[2], editingObjectData.originalHeading - 90.0)
                        end
                    end
                elseif DoesEntityExist(objData.interiorEntity) then
                    -- Check if this is a sign with signpole that needs proper offset calculation
                    if editingObjectData.model:match("bazq%-wall2_sign%d+") then
                        -- Calculate proper offset for signpole based on original heading
                        local headingRad = math.rad(editingObjectData.originalHeading)
                        local forwardX = -math.sin(headingRad)
                        local forwardY = math.cos(headingRad)
                        local offsetCoords = vector3(
                            editingObjectData.originalCoords.x + (0.03 * forwardX),
                            editingObjectData.originalCoords.y + (0.03 * forwardY),
                            editingObjectData.originalCoords.z
                        )
                        SetEntityCoords(objData.interiorEntity, offsetCoords.x, offsetCoords.y, offsetCoords.z, false, false, false, true)
                    else
                        -- For other interior entities (like tower interiors), use same position
                        SetEntityCoords(objData.interiorEntity, editingObjectData.originalCoords.x, editingObjectData.originalCoords.y, editingObjectData.originalCoords.z, false, false, false, true)
                    end
                    SetEntityHeading(objData.interiorEntity, editingObjectData.originalHeading)
                end
                -- print("[OP] Reverted interior entity position for " .. editingObjectData.model)
            elseif objData and objData.hasCollision then
                -- For collision, request at original position
                RequestCollisionAtCoord(editingObjectData.originalCoords.x, editingObjectData.originalCoords.y, editingObjectData.originalCoords.z)
                -- print("[OP] Reverted collision position for " .. editingObjectData.model)
            end
        end
        -- Restore object to normal state
        SetEntityCollision(editingObjectData.entity, true, true)
        ResetEntityAlpha(editingObjectData.entity)
        SetEntityDrawOutline(editingObjectData.entity, false)
        SetEntityRenderScorched(editingObjectData.entity, false)
        SendNUIMessage({action = 'editingModeUpdate', message = "Object edit cancelled.", isError = false, editingActive = false})
        DebugLog("EDIT", "Edit cancelled: " .. editingObjectData.model)
    end
    editingObjectData = nil
end

function CleanupAssociatedDoors(parentObjData)
    if not parentObjData or not parentObjData.coords then
        DebugDeletion("CleanupAssociatedDoors: Invalid parent object data")
        return
    end
    
    local parentPos = parentObjData.coords
    local searchRadius = 10.0 -- Search within 10 meters
    local doorsToDelete = {}
    
    DebugDeletion("Searching for doors near position: " .. parentPos.x .. ", " .. parentPos.y .. ", " .. parentPos.z)
    
    -- Find all door objects within radius
    for i, objData in pairs(spawnedObjects) do
        if objData and objData.coords and objData.entity and DoesEntityExist(objData.entity) then
            -- Check if this is a door/gate object (not the parent itself)
            if i ~= parentObjData.index and objData.model and (
                string.find(objData.model, "door") or 
                string.find(objData.model, "gate") or
                objData.model == "bazq-sur_kapi" or 
                objData.model == "bazq-sur_mkapi"
            ) then
                local distance = #(vector3(parentPos.x, parentPos.y, parentPos.z) - vector3(objData.coords.x, objData.coords.y, objData.coords.z))
                
                if distance <= searchRadius then
                    DebugDeletion("Found associated door: " .. objData.model .. " at distance " .. distance .. "m")
                    table.insert(doorsToDelete, i)
                end
            end
        end
    end
    
    -- Delete found doors
    for _, doorIndex in ipairs(doorsToDelete) do
        DebugDeletion("Deleting associated door at index: " .. doorIndex)
        local doorData = spawnedObjects[doorIndex]
        
        if doorData and doorData.entity and DoesEntityExist(doorData.entity) then
            DeleteEntity(doorData.entity)
            DebugDeletion("Deleted door entity: " .. (doorData.model or "unknown"))
        end
        
        -- Delete interior entity if exists
        if doorData.interiorEntity then
            if type(doorData.interiorEntity) == "table" then
                for i, doorEntity in ipairs(doorData.interiorEntity) do
                    if DoesEntityExist(doorEntity) then
                        DeleteEntity(doorEntity)
                        DebugDeletion("Deleted door interior entity " .. i)
                    end
                end
            elseif DoesEntityExist(doorData.interiorEntity) then
                DeleteEntity(doorData.interiorEntity)
                DebugDeletion("Deleted door interior entity")
            end
        end
        
        -- Remove from spawned objects array
        spawnedObjects[doorIndex] = nil
    end
    
    -- Compact the array to remove nil entries
    local compactedObjects = {}
    for i, objData in pairs(spawnedObjects) do
        if objData then
            table.insert(compactedObjects, objData)
        end
    end
    spawnedObjects = compactedObjects
    
    if #doorsToDelete > 0 then
        DebugDeletion("Cleanup complete. Deleted " .. #doorsToDelete .. " associated doors")
        -- Update server and UI
        SaveObjectsToServer()
        SendNUIMessage({action="updateSpawnedList", data=GetSerializableSpawnedObjects()})
    else
        DebugDeletion("No associated doors found to delete")
    end
end

function DeleteSpawnedObject(index)
    local objData=spawnedObjects[index]
    if objData then
        DebugDeletion("Deleting object at index " .. index .. ", model: " .. (objData.model or "unknown"))
        DebugDeletion("hasDualDoors: " .. tostring(objData.hasDualDoors))
        DebugDeletion("interiorEntity type: " .. type(objData.interiorEntity))
        
        -- Special handling for surkapi models (bazq-sur_kapi, bazq-sur_mkapi)
        -- Delete associated doors when the wall gate/door is deleted
        if objData.model == "bazq-sur_kapi" or objData.model == "bazq-sur_mkapi" then
            DebugDeletion("Surkapi detected: " .. objData.model .. ", cleaning up associated doors")
            -- Add current index to objData for CleanupAssociatedDoors function
            objData.index = index
            CleanupAssociatedDoors(objData)
        end
        
        -- Delete main entity
        if objData.entity and DoesEntityExist(objData.entity) then
            DeleteEntity(objData.entity)
            DebugDeletion("Deleted main entity for " .. (objData.model or "unknown"))
        end
        
        -- Delete interior entity if it exists (only for actual entities, not collision)
        if objData.interiorEntity then
            if type(objData.interiorEntity) == "table" then
                -- Handle dual doors
                DebugDeletion("Processing dual doors, count: " .. #objData.interiorEntity)
                for i, doorEntity in ipairs(objData.interiorEntity) do
                    DebugDeletion("Checking door " .. i .. ", entity: " .. tostring(doorEntity) .. ", exists: " .. tostring(DoesEntityExist(doorEntity)))
                    if DoesEntityExist(doorEntity) then
                        DeleteEntity(doorEntity)
                        DebugDeletion("Deleted door entity " .. i)
                    else
                        DebugDeletion("WARNING: Door entity " .. i .. " does not exist!")
                    end
                end
                DebugLog("DELETION", "Deleted dual door entities for " .. (objData.model or "unknown"))
            elseif DoesEntityExist(objData.interiorEntity) then
                DeleteEntity(objData.interiorEntity)
                DebugLog("DELETION", "Deleted interior entity for " .. (objData.model or "unknown"))
            else
                DebugDeletion("WARNING: Interior entity does not exist for " .. (objData.model or "unknown"))
            end
        else
            DebugDeletion("No interior entity to delete")
        end
        
        -- Note: Collision is automatically managed by the game
        table.remove(spawnedObjects,index)
        SaveObjectsToServer()
        SendNUIMessage({action="updateSpawnedList",data=GetSerializableSpawnedObjects()})
        DebugDeletion("Deletion complete")
    else
        DebugDeletion("ERROR: No object data found at index " .. index)
    end
end

function AlignObjectToGround(obj)local p=GetEntityCoords(obj);local _,gZ=GetGroundZFor_3dCoord(p.x,p.y,p.z+2.0,false);if gZ then SetEntityCoords(obj,p.x,p.y,gZ,0,0,0,1)end end
function RaycastFromCamera()local cC,cR=GetGameplayCamCoord(),GetGameplayCamRot(2);local d=RotationToDirection(cR);local dest=cC+d*25.0;local r=StartShapeTestRay(cC.x,cC.y,cC.z,dest.x,dest.y,dest.z,-1,PlayerPedId(),7);local _,h,hC=GetShapeTestResult(r);return h==1,hC end
function RaycastFromCameraWithEntity()
    local cC = GetGameplayCamCoord()
    local cR = GetGameplayCamRot(2)
    local d = RotationToDirection(cR)
    local dest = cC + d * 25.0
    local r = StartShapeTestRay(cC.x, cC.y, cC.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 7)
    
    -- Wait for raycast to complete
    local attempts = 0
    while attempts < 10 do
        local result, hit, coords, normal, entity = GetShapeTestResult(r)
        if result ~= 1 then
            Citizen.Wait(0)
            attempts = attempts + 1
        else
            return hit == 1, coords, entity
        end
    end
    
    -- Fallback if raycast fails
    return false, nil, nil
end
function RotationToDirection(rot)local z,x=math.rad(rot.z),math.rad(rot.x);local cX=math.cos(x);return vector3(-math.sin(z)*cX,math.cos(z)*cX,math.sin(x))end

-- Advanced XYZ arrows for edit mode - much better than placement mode!
function DrawAdvancedXYZArrows(entity, coords, rightVec, fwdVec, upVec)
    local arrowLength = 1.2
    local arrowHeadSize = 0.15
    local lineThickness = 0.02
    
    -- X-Axis (Right) - Red Arrow
    local xEnd = coords + rightVec * arrowLength
    DrawLine(coords.x, coords.y, coords.z, xEnd.x, xEnd.y, xEnd.z, 255, 50, 50, 255)
    
    -- X-Axis arrow head (3 lines forming arrow tip)
    local xArrowTip1 = xEnd - rightVec * arrowHeadSize + fwdVec * arrowHeadSize * 0.5
    local xArrowTip2 = xEnd - rightVec * arrowHeadSize - fwdVec * arrowHeadSize * 0.5
    local xArrowTip3 = xEnd - rightVec * arrowHeadSize + upVec * arrowHeadSize * 0.5
    DrawLine(xEnd.x, xEnd.y, xEnd.z, xArrowTip1.x, xArrowTip1.y, xArrowTip1.z, 255, 50, 50, 255)
    DrawLine(xEnd.x, xEnd.y, xEnd.z, xArrowTip2.x, xArrowTip2.y, xArrowTip2.z, 255, 50, 50, 255)
    DrawLine(xEnd.x, xEnd.y, xEnd.z, xArrowTip3.x, xArrowTip3.y, xArrowTip3.z, 255, 50, 50, 255)
    
    -- Y-Axis (Forward) - Green Arrow
    local yEnd = coords + fwdVec * arrowLength
    DrawLine(coords.x, coords.y, coords.z, yEnd.x, yEnd.y, yEnd.z, 50, 255, 50, 255)
    
    -- Y-Axis arrow head
    local yArrowTip1 = yEnd - fwdVec * arrowHeadSize + rightVec * arrowHeadSize * 0.5
    local yArrowTip2 = yEnd - fwdVec * arrowHeadSize - rightVec * arrowHeadSize * 0.5
    local yArrowTip3 = yEnd - fwdVec * arrowHeadSize + upVec * arrowHeadSize * 0.5
    DrawLine(yEnd.x, yEnd.y, yEnd.z, yArrowTip1.x, yArrowTip1.y, yArrowTip1.z, 50, 255, 50, 255)
    DrawLine(yEnd.x, yEnd.y, yEnd.z, yArrowTip2.x, yArrowTip2.y, yArrowTip2.z, 50, 255, 50, 255)
    DrawLine(yEnd.x, yEnd.y, yEnd.z, yArrowTip3.x, yArrowTip3.y, yArrowTip3.z, 50, 255, 50, 255)
    
    -- Z-Axis (Up) - Blue Arrow
    local zEnd = coords + upVec * arrowLength
    DrawLine(coords.x, coords.y, coords.z, zEnd.x, zEnd.y, zEnd.z, 50, 50, 255, 255)
    
    -- Z-Axis arrow head
    local zArrowTip1 = zEnd - upVec * arrowHeadSize + rightVec * arrowHeadSize * 0.5
    local zArrowTip2 = zEnd - upVec * arrowHeadSize - rightVec * arrowHeadSize * 0.5
    local zArrowTip3 = zEnd - upVec * arrowHeadSize + fwdVec * arrowHeadSize * 0.5
    DrawLine(zEnd.x, zEnd.y, zEnd.z, zArrowTip1.x, zArrowTip1.y, zArrowTip1.z, 50, 50, 255, 255)
    DrawLine(zEnd.x, zEnd.y, zEnd.z, zArrowTip2.x, zArrowTip2.y, zArrowTip2.z, 50, 50, 255, 255)
    DrawLine(zEnd.x, zEnd.y, zEnd.z, zArrowTip3.x, zArrowTip3.y, zArrowTip3.z, 50, 50, 255, 255)
    
    -- Add axis labels using 3D text
    DrawText3D(xEnd.x + 0.1, xEnd.y, xEnd.z, "X", 255, 50, 50, 0.3)
    DrawText3D(yEnd.x, yEnd.y + 0.1, yEnd.z, "Y", 50, 255, 50, 0.3)
    DrawText3D(zEnd.x, zEnd.y, zEnd.z + 0.1, "Z", 50, 50, 255, 0.3)
    
    -- Draw coordinate grid around object for better spatial awareness
    DrawEditModeGrid(coords, rightVec, fwdVec, upVec)
end

-- Helper function to draw 3D text
function DrawText3D(x, y, z, text, r, g, b, scale)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(scale or 0.35, scale or 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(r, g, b, 255)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

-- Draw a subtle grid around the object for better spatial reference
function DrawEditModeGrid(coords, rightVec, fwdVec, upVec)
    local gridSize = 2.0
    local gridSpacing = 0.5
    local gridAlpha = 80
    
    -- Draw ground grid (XY plane)
    for i = -gridSize, gridSize, gridSpacing do
        for j = -gridSize, gridSize, gridSpacing do
            local gridPoint = coords + rightVec * i + fwdVec * j
            local groundZ = coords.z - 0.1 -- Slightly below object
            
            -- Draw small cross at each grid point
            local crossSize = 0.05
            DrawLine(
                gridPoint.x - crossSize, gridPoint.y, groundZ,
                gridPoint.x + crossSize, gridPoint.y, groundZ,
                100, 100, 100, gridAlpha
            )
            DrawLine(
                gridPoint.x, gridPoint.y - crossSize, groundZ,
                gridPoint.x, gridPoint.y + crossSize, groundZ,
                100, 100, 100, gridAlpha
            )
        end
    end
    
    -- Draw vertical reference lines
    local verticalHeight = 1.5
    DrawLine(
        coords.x + gridSize, coords.y, coords.z,
        coords.x + gridSize, coords.y, coords.z + verticalHeight,
        150, 150, 150, gridAlpha
    )
    DrawLine(
        coords.x - gridSize, coords.y, coords.z,
        coords.x - gridSize, coords.y, coords.z + verticalHeight,
        150, 150, 150, gridAlpha
    )
    DrawLine(
        coords.x, coords.y + gridSize, coords.z,
        coords.x, coords.y + gridSize, coords.z + verticalHeight,
        150, 150, 150, gridAlpha
    )
    DrawLine(
        coords.x, coords.y - gridSize, coords.z,
        coords.x, coords.y - gridSize, coords.z + verticalHeight,
        150, 150, 150, gridAlpha
    )
end

function SaveObjectsToServer()
    local toSave={}
    DebugLog("SAVE", "Preparing to save " .. #spawnedObjects .. " objects.")
    for i,objData in ipairs(spawnedObjects)do
        if objData.model and objData.coords and objData.heading~=nil then
            -- Skip door entities - they should only exist as interior entities, never as standalone objects
            if objData.model == "bazq-sur_mkapi" then
                DebugLog("SAVE", "Skipping door entity " .. objData.model .. " - doors should not be saved as standalone objects")
                goto continue
            end
            DebugLog("SAVE", string.format("Item %d: Model=%s, X=%.2f, Y=%.2f, Z=%.2f, H=%.2f, TS=%s, Player=%s",
                i, objData.model, objData.coords.x, objData.coords.y, objData.coords.z, objData.heading, objData.timestamp or "N/A", objData.playerName or "Unknown"))
            local saveData = {
                model=objData.model,
                coords=objData.coords,
                heading=objData.heading,
                timestamp=objData.timestamp or "",
                playerName=objData.playerName or "Unknown"
            }
            -- Include interior model info if it exists
            if objData.interiorModel then
                saveData.interiorModel = objData.interiorModel
            end
            -- Include dual doors flag if it exists
            if objData.hasDualDoors then
                saveData.hasDualDoors = objData.hasDualDoors
            end
            table.insert(toSave, saveData)
        else
            DebugLog("SAVE", "Item " .. i .. " is missing data. Model: " .. tostring(objData.model))
        end
        ::continue::
    end
    DebugLog("SAVE", "Triggering server event with " .. #toSave .. " objects.")
    TriggerServerEvent("bazq-objectplace:saveObjects",toSave)
end
-- Commands removed - only F7 key access for admins

RegisterNetEvent("bazq-objectplace:loadObjects")
AddEventHandler("bazq-objectplace:loadObjects", function(objectsData)
    -- Clear existing objects
    for _, oD in ipairs(spawnedObjects) do 
        if oD.entity and DoesEntityExist(oD.entity) then 
            DeleteEntity(oD.entity) 
        end 
    end
    spawnedObjects = {}
    
    if type(objectsData) ~= "table" then 
        DebugLog("LOADING", "Loaded objects data is not a table.") 
        return 
    end
    
    DebugLog("LOADING", "Received " .. #objectsData .. " objects from server to load.")
    
    for i, objSD in ipairs(objectsData) do 
        if not objSD.model or not objSD.coords or objSD.coords.x == nil then
            DebugLog("LOADING", "Skipping invalid object data at index " .. i)
        else
            local mH = GetHashKey(objSD.model)
            local ent = 0
            -- Safe load mode: only if exact same model exists exactly at coordinate, skip spawn
            if SAFE_LOAD_MODE then
                local existing = GetClosestObjectOfType(objSD.coords.x, objSD.coords.y, objSD.coords.z, 0.6, mH, false, true, true)
                if existing ~= 0 and DoesEntityExist(existing) then
                    DebugLog("LOADING", "SafeLoad: Detected existing entity for " .. objSD.model .. ", skipping spawn")
                    ent = existing
                end
            end
            if ent == 0 then
                RequestModel(mH); local sT = GetGameTimer()
                while not HasModelLoaded(mH) do if GetGameTimer()-sT>5000 then DebugLog("LOADING", "Timeout load "..objSD.model); break end; Citizen.Wait(50) end
                if HasModelLoaded(mH) then ent = CreateObject(mH, objSD.coords.x, objSD.coords.y, objSD.coords.z, 0, 0, 0) end
            end
            if ent ~= 0 and DoesEntityExist(ent) then
                SetEntityAsMissionEntity(ent,1,1);SetEntityDynamic(ent,0);SetEntityCollision(ent,1,1);SetEntityHeading(ent,objSD.heading or 0.0)
                    
                    local objectData = {
                        entity=ent,
                        model=objSD.model,
                        coords=objSD.coords,
                        heading=objSD.heading,
                        timestamp=objSD.timestamp or "",
                        playerName=objSD.playerName or "Unknown"
                    }
                    
                    -- Handle interior objects (simplified, balanced blocks)
                    DebugLog("LOADING", "Model=" .. objSD.model .. ", InteriorModel=" .. tostring(objSD.interiorModel) .. ", HasDualDoors=" .. tostring(objSD.hasDualDoors))
                    if objSD.interiorModel then
                        if objSD.interiorModel == "bazq-kule_int-col" then
                            DebugLog("COLLISION", "Loading collision for " .. objSD.model)
                            RequestCollisionAtCoord(objSD.coords.x, objSD.coords.y, objSD.coords.z)
                            objectData.interiorModel = objSD.interiorModel
                            objectData.hasCollision = true
                            DebugLog("COLLISION", "Collision requested for " .. objSD.model)
                        else
                            local interiorHash = GetHashKey(objSD.interiorModel)
                            RequestModel(interiorHash)
                            local startTime = GetGameTimer()
                            while not HasModelLoaded(interiorHash) do
                                if GetGameTimer() - startTime > 3000 then break end
                                Citizen.Wait(50)
                            end
                            local zCoord = objSD.coords.z
                            if objSD.interiorModel == "bazq-surfence" then zCoord = zCoord + 5 end
                            local interiorEnt = GetClosestObjectOfType(objSD.coords.x, objSD.coords.y, zCoord, 0.6, interiorHash, false, true, true)
                            if interiorEnt == 0 then
                                interiorEnt = CreateObject(interiorHash, objSD.coords.x, objSD.coords.y, zCoord, 0, 0, 0)
                            end
                            if DoesEntityExist(interiorEnt) then
                                SetEntityHeading(interiorEnt, objSD.heading or 0.0)
                                SetEntityAsMissionEntity(interiorEnt, 1, 1)
                                SetEntityDynamic(interiorEnt, 0)
                                SetEntityCollision(interiorEnt, 1, 1)
                                objectData.interiorEntity = interiorEnt
                                objectData.interiorModel = objSD.interiorModel

                                -- Special handling for gate doors (mkapi): ensure dual doors exist and are tracked
                                if objSD.interiorModel == "bazq-sur_mkapi" then
                                    local doorHash = interiorHash
                                    local headingRad = math.rad(objSD.heading or 0.0)
                                    local forwardX = -math.sin(headingRad)
                                    local forwardY = math.cos(headingRad)

                                    -- First door position (+Y)
                                    local door1X = objSD.coords.x + (5.37824 * forwardX)
                                    local door1Y = objSD.coords.y + (5.37824 * forwardY)
                                    local door1Z = objSD.coords.z
                                    local door1 = GetClosestObjectOfType(door1X, door1Y, door1Z, 0.6, doorHash, false, true, true)
                                    if door1 == 0 then
                                        door1 = interiorEnt
                                        SetEntityCoords(door1, door1X, door1Y, door1Z, false, false, false, true)
                                    end
                                    if DoesEntityExist(door1) then
                                        SetEntityHeading(door1, (objSD.heading or 0.0) + 90.0)
                                    end

                                    -- Second door position (-Y)
                                    local door2X = objSD.coords.x - (5.37824 * forwardX)
                                    local door2Y = objSD.coords.y - (5.37824 * forwardY)
                                    local door2Z = objSD.coords.z
                                    local door2 = GetClosestObjectOfType(door2X, door2Y, door2Z, 0.6, doorHash, false, true, true)
                                    if door2 == 0 then
                                        door2 = CreateObject(interiorHash, door2X, door2Y, door2Z, 0, 0, 0)
                                    end
                                    if DoesEntityExist(door2) then
                                        SetEntityHeading(door2, (objSD.heading or 0.0) - 90.0)
                                        SetEntityAsMissionEntity(door2, 1, 1)
                                        SetEntityDynamic(door2, 1)
                                        SetEntityCollision(door2, 1, 1)
                                    end

                                    -- Track both doors for proper deletion
                                    if DoesEntityExist(door1) and DoesEntityExist(door2) then
                                        objectData.interiorEntity = { door1, door2 }
                                        objectData.hasDualDoors = true
                                    end
                                end
                            end
                        end
                    end
                    
                    -- Ensure non-door objects are static
                    if not (objSD.model == "bazq-sur_mkapi" or (objSD.model and string.match(objSD.model, "bazq%-wall2_gate%d+"))) then
                        SetEntityDynamic(ent, false)
                    end
                    
                    table.insert(spawnedObjects, objectData)
                else
                    DebugLog("LOADING", "CreateFail "..objSD.model)
                end
            end
        end
    
    -- Update UI after loading
    SendNUIMessage({action="updateSpawnedList",data=GetSerializableSpawnedObjects()})
    DebugLog("LOADING", "Finished loading. Spawned objects count: "..#spawnedObjects)
end)
-- Commands removed - only F7 key access for admins

-- Auto-load objects when client starts
AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        -- Small delay to ensure everything is initialized
        Citizen.SetTimeout(2000, function()
            DebugLog("LOADING", "Client started, requesting saved objects from server...")
            TriggerServerEvent("bazq-objectplace:requestObjects")
        end)
    end
end)

-- Handle settings save from NUI
RegisterNUICallback('saveSettings', function(data, cb)
    if data.username and data.packages then
        TriggerServerEvent("bazq-objectplace:saveUserSettings", data.username, data.packages)
        cb({status = 'ok'})
    else
        cb({status = 'error', message = 'Invalid settings data'})
    end
end)

-- Handle real-time package filter updates
RegisterNUICallback('updatePackageFilter', function(data, cb)
    if data.packages then
        -- Ensure config is loaded before getting objects
        if not objectsConfig.packages then
            LoadObjectsConfig()
        end
        
        -- Update object list immediately
        objectList = GetUserObjects(data.packages)
        DebugLog("USER", "Real-time update: " .. #objectList .. " objects for packages: " .. table.concat(data.packages, ", "))
        
        -- Send updated object list back to NUI
        SendNUIMessage({
            action = 'updateObjectList',
            objects = objectList
        })
        
        cb({status = 'ok'})
    else
        cb({status = 'error', message = 'Invalid package data'})
    end
end)

RegisterNUICallback('reopenMenu', function(data, cb)
    DebugLog("PLACEMENT", "Reopen menu requested from NUI localStorage check")
    
    if not placing and not editingObjectData and not isMenuOpen then
        SetNuiFocus(true, true)
        isMenuOpen = true
        SendNUIMessage({
            action = 'open',
            objects = objectList,
            spawnedObjectsForList = GetSerializableSpawnedObjects(),
            userSettings = currentUserSettings
        })
        DebugLog("PLACEMENT", "Menu reopened successfully")
    end
    
    cb({status = 'ok'})
end)

RegisterNUICallback('updateUser', function(data, cb)
    DebugLog("USER", "Update user request: " .. tostring(data.originalIdentifier) .. " → " .. tostring(data.newDisplayName))
    
    if not data.originalIdentifier or not data.newDisplayName or not data.newIdentifier or not data.newRole then
        cb({success = false, message = "Missing required fields"})
        return
    end
    
    -- Send to server for processing
    TriggerServerEvent("bazq-objectplace:updateUser", data.originalIdentifier, data.newDisplayName, data.newIdentifier, data.newRole)
    
    -- For now, assume success - server should handle validation
    cb({success = true})
end)

RegisterNUICallback('saveUserSettings', function(data, cb)
    if data.packages then
        DebugLog("SAVE", "Saving user settings - packages: " .. table.concat(data.packages, ", ") .. ", keepMenuOpen: " .. tostring(data.keepMenuOpen))
        
        -- Update current user settings immediately for this session
        if not currentUserSettings then
            currentUserSettings = {}
        end
        currentUserSettings.packages = data.packages
        if data.keepMenuOpen ~= nil then
            currentUserSettings.keepMenuOpen = data.keepMenuOpen
        end
        
        -- Send to server to save (for now just packages, server-side update needed for keepMenuOpen)
        TriggerServerEvent("bazq-objectplace:saveUserSettings", data.packages)
        
        cb({status = 'ok'})
    else
        cb({status = 'error', message = 'Invalid package data'})
    end
end)

        -- Receive user settings from server and open menu
RegisterNetEvent("bazq-objectplace:receiveUserSettings")
AddEventHandler("bazq-objectplace:receiveUserSettings", function(userSettings)
    DebugMenu("Received user settings, opening menu...")
    DebugMenu("Current state - isMenuOpen: " .. tostring(isMenuOpen) .. ", isMenuLoading: " .. tostring(isMenuLoading) .. ", IsNuiFocused: " .. tostring(IsNuiFocused()))
    
    currentUserSettings = userSettings
    isMenuLoading = false -- Reset loading state
    isMenuOpen = true -- Set menu as open
    
    -- Update player name from osadmin.json displayName
    if userSettings and userSettings.username then
        currentPlacementOptions.playerName = userSettings.username
        DebugUser("Player name set to: " .. userSettings.username)
    end
    
    -- Ensure config is loaded before getting objects
    if not objectsConfig.packages then
        DebugLog("LOADING", "Config not loaded yet, loading now...")
        LoadObjectsConfig()
    end
    
    -- Update object list based on user packages
    if userSettings and userSettings.packages then
        DebugLog("USER", "userSettings.packages = " .. tostring(json.encode(userSettings.packages)))
        objectList = GetUserObjects(userSettings.packages)
        DebugLog("USER", "Loaded " .. #objectList .. " objects for user packages: " .. table.concat(userSettings.packages, ", "))
        DebugLog("USER", "First 10 objects: " .. table.concat({table.unpack(objectList, 1, math.min(10, #objectList))}, ", "))
        DebugLog("USER", "Config packages available: " .. tostring(objectsConfig.packages and CountTableKeys(objectsConfig.packages) or "NIL"))
    else
        -- No packages, only show dummy props
        objectList = GetUserObjects({})
        DebugLog("USER", "No packages found, showing only dummy props")
        DebugLog("USER", "userSettings = " .. tostring(userSettings and json.encode(userSettings) or "NIL"))
    end
    
    -- Open menu properly with focus protection
    DebugLog("MENU", "Setting NUI focus and menu state...")
    SetNuiFocus(true, true)
    isMenuOpen = true
    
    -- Send UI data and wait for ready callback
    SendNUIMessage({
        action = 'open',
        objects = objectList,
        spawnedObjectsForList = GetSerializableSpawnedObjects(),
        userSettings = userSettings
    })
    DebugLog("MENU", "Sent open message to UI with " .. #objectList .. " objects")
    DebugLog("MENU", "Menu should now be open - isMenuOpen:" .. tostring(isMenuOpen) .. " IsNuiFocused:" .. tostring(IsNuiFocused()))
    
    -- FOCUS PROTECTION: Ensure focus stays active after UI loads
    Citizen.SetTimeout(100, function()
        if isMenuOpen and not IsNuiFocused() then
            DebugLog("MENU", "🔧 FOCUS PROTECTION: Restoring lost NUI focus")
            SetNuiFocus(true, true)
        end
    end)
    
    -- Additional protection after a longer delay
    Citizen.SetTimeout(500, function()
        if isMenuOpen and not IsNuiFocused() then
            DebugLog("MENU", "🔧 FOCUS PROTECTION: Restoring lost NUI focus (delayed)")
            SetNuiFocus(true, true)
        end
    end)
end)

-- Handle access denied from server
RegisterNetEvent("bazq-objectplace:accessDenied")
AddEventHandler("bazq-objectplace:accessDenied", function(errorData)
    DebugLog("MENU", "Access denied received - resetting isMenuLoading")
    isMenuLoading = false -- Reset loading state
    
    -- Clean up any stuck NUI focus
    if IsNuiFocused() then
        DebugLog("MENU", "Cleaning up stuck NUI focus from access denied")
        SetNuiFocus(false, false)
    end
    
    -- Show detailed error message to player
    if errorData and errorData.message then
        DebugLog("USER", "Access denied: " .. errorData.message)
        if errorData.details then
            DebugLog("USER", "Details: " .. errorData.details)
        end
        
        -- Show notification with improved message
        SetNotificationTextEntry("STRING")
        AddTextComponentString("~r~Access Denied~w~\n" .. errorData.message)
        DrawNotification(false, false)
        
        -- Show identifier for manual admin setup
        if errorData.details then
            Citizen.SetTimeout(3000, function()
                SetNotificationTextEntry("STRING")
                AddTextComponentString("~o~Setup Info:~w~\n" .. errorData.details)
                DrawNotification(false, false)
            end)
        end
    else
        -- Fallback error message
        SetNotificationTextEntry("STRING")
        AddTextComponentString("~r~Access Denied~w~\nYou need mapper, admin, or owner permissions!")
        DrawNotification(false, false)
        DebugLog("USER", "Access denied - insufficient permissions")
    end
end)

-- Image-based preview system - much simpler and more effective
-- Images should be placed in html/images/ folder with format: {modelname}.png
-- Example: html/images/bazq-tent1a.png

-- Handle cleanup request from NUI
RegisterNUICallback("cleanupPreviews", function(data, cb)
    TriggerEvent("bazq-objectplace:cleanupPreviews")
    cb("ok")
end)

-- Request resource info on client start
Citizen.CreateThread(function()
    Citizen.Wait(1000) -- Wait for everything to initialize
    
    -- Load objects configuration
    LoadObjectsConfig()
    
    TriggerServerEvent("bazq-objectplace:requestResourceInfo")
end)

-- Disable controls when menu is open or during object placement/editing
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        -- Check if controls should be disabled (removed isFreecamActive to allow key detection)
        local shouldDisable = isMenuOpen or placing or editingObjectData ~= nil
        
        if shouldDisable then
            -- Disable primary combat controls
            DisableControlAction(0, 24, true)   -- INPUT_ATTACK (Left Click/Fire)
            DisableControlAction(0, 25, true)   -- INPUT_AIM (Right Click/Aim)
            DisableControlAction(0, 68, true)   -- INPUT_AIM_DOWN_SIGHT (Aim Down Sight)
            DisableControlAction(0, 91, true)   -- INPUT_VEH_DUCK (Duck/Cover/Grenades)
            
            -- Disable weapon wheel and switching
            DisableControlAction(0, 37, true)   -- INPUT_SELECT_WEAPON (Tab - Weapon Wheel)
            DisableControlAction(0, 47, true)   -- INPUT_WEAPON_WHEEL_UD (Weapon Wheel Up/Down)
            DisableControlAction(0, 48, true)   -- INPUT_WEAPON_WHEEL_LR (Weapon Wheel Left/Right)
            DisableControlAction(0, 15, true)   -- INPUT_WEAPON_WHEEL_NEXT (Mouse Wheel Up)
            DisableControlAction(0, 14, true)   -- INPUT_WEAPON_WHEEL_PREV (Mouse Wheel Down)
            
            -- Disable all weapon selection slots
            DisableControlAction(0, 157, true)  -- INPUT_SELECT_WEAPON_1 (1 key)
            DisableControlAction(0, 158, true)  -- INPUT_SELECT_WEAPON_2 (2 key)
            DisableControlAction(0, 159, true)  -- INPUT_SELECT_WEAPON_SMG (3 key)
            DisableControlAction(0, 160, true)  -- INPUT_SELECT_WEAPON_UNARMED (4 key)
            DisableControlAction(0, 161, true)  -- INPUT_SELECT_WEAPON_RIFLE (5 key)
            DisableControlAction(0, 162, true)  -- INPUT_SELECT_WEAPON_SNIPER (6 key)
            DisableControlAction(0, 163, true)  -- INPUT_SELECT_WEAPON_HEAVY (7 key)
            DisableControlAction(0, 164, true)  -- INPUT_SELECT_WEAPON_HANDGUN (8 key)
            DisableControlAction(0, 165, true)  -- INPUT_SELECT_WEAPON_SHOTGUN (9 key)
            DisableControlAction(0, 166, true)  -- INPUT_SELECT_WEAPON_SPECIAL (0 key)
            
            -- Disable melee combat
            DisableControlAction(0, 140, true)  -- INPUT_MELEE_ATTACK_LIGHT (R key)
            DisableControlAction(0, 141, true)  -- INPUT_MELEE_ATTACK_HEAVY (O key)
            DisableControlAction(0, 142, true)  -- INPUT_MELEE_ATTACK_ALTERNATE (Left Alt)
            DisableControlAction(0, 143, true)  -- INPUT_MELEE_BLOCK (Space)
            DisableControlAction(0, 263, true)  -- INPUT_MELEE_ATTACK1 (Light Attack)
            DisableControlAction(0, 264, true)  -- INPUT_MELEE_ATTACK2 (Heavy Attack)
            
            -- Disable vehicle combat
            DisableControlAction(0, 69, true)   -- INPUT_VEH_ATTACK (Vehicle Attack)
            DisableControlAction(0, 70, true)   -- INPUT_VEH_ATTACK2 (Vehicle Attack 2)
            DisableControlAction(0, 92, true)   -- INPUT_VEH_PASSENGER_ATTACK (Passenger Attack)
            
            -- Disable throwing weapons and grenades
            DisableControlAction(0, 182, true)  -- INPUT_CELLPHONE_OPTION (Grenade throw)
            DisableControlAction(0, 199, true)  -- INPUT_PAUSE_MENU (P key - can be used for some weapons)
            DisableControlAction(0, 200, true)  -- INPUT_INTERACTION_MENU (M key)
            
            -- Disable additional combat-related controls
            DisableControlAction(0, 59, true)   -- INPUT_VEH_MOVE_LR (A/D in vehicle - sometimes used for combat)
            DisableControlAction(0, 60, true)   -- INPUT_VEH_MOVE_UD (W/S in vehicle - sometimes used for combat)
            
            -- Update control disabled state
            if not isControlsDisabled then
                isControlsDisabled = true
                DebugLog("GENERAL", "Combat controls disabled - Menu: " .. tostring(isMenuOpen) .. ", Placing: " .. tostring(placing) .. ", Editing: " .. tostring(editingObjectData ~= nil))
            end
        else
            -- Re-enable controls
            if isControlsDisabled then
                isControlsDisabled = false
                DebugLog("GENERAL", "Combat controls enabled")
            end
        end
    end
end)

-- Receive resource info from server
RegisterNetEvent("bazq-objectplace:receiveResourceInfo")
AddEventHandler("bazq-objectplace:receiveResourceInfo", function(resourceInfo)
    -- Send resource info to NUI
    SendNUIMessage({
        action = 'updateResourceInfo',
        resourceInfo = resourceInfo
    })
end)



-- User Management Events
RegisterNetEvent("bazq-objectplace:userListResponse")
AddEventHandler("bazq-objectplace:userListResponse", function(data)
    SendNUIMessage({
        action = 'userListResponse',
        success = data.success,
        users = data.users,
        currentUserRole = data.currentUserRole,
        currentUserIdentifier = data.currentUserIdentifier
    })
end)

RegisterNetEvent("bazq-objectplace:userActionResponse")
AddEventHandler("bazq-objectplace:userActionResponse", function(data)
    SendNUIMessage({
        action = 'userActionResponse',
        success = data.success,
        message = data.message
    })
end)

-- User Management NUI Callbacks
RegisterNUICallback('getUserList', function(data, cb)
    TriggerServerEvent("bazq-objectplace:getUserList")
    cb({status = 'ok'})
end)

RegisterNUICallback('addUser', function(data, cb)
    TriggerServerEvent("bazq-objectplace:addUser", data)
    cb({status = 'ok'})
end)

RegisterNUICallback('updateUserRole', function(data, cb)
    TriggerServerEvent("bazq-objectplace:updateUserRole", data)
    cb({status = 'ok'})
end)

RegisterNUICallback('deleteUser', function(data, cb)
    TriggerServerEvent("bazq-objectplace:deleteUser", data)
    cb({status = 'ok'})
end)

RegisterNUICallback('clearAllMappers', function(data, cb)
    TriggerServerEvent("bazq-objectplace:clearAllMappers")
    cb({status = 'ok'})
end)

-- NUI Ready callback - called when UI is fully loaded and ready
RegisterNUICallback('uiReady', function(data, cb)
    SetNuiFocus(true, true)
    isMenuOpen = true
    DebugLog("MENU", "UI confirmed ready, focus set")
    cb({status = 'ok'})
end)

-- Handle object renaming from UI
RegisterNUICallback('renameObject', function(data, cb)
    local index = data.index
    local newName = data.newName
    
    if index and spawnedObjects[index] and newName and newName ~= "" then
        -- Update the display name
        spawnedObjects[index].displayName = newName
        
        -- Save to server
        SaveObjectsToServer()
        
        -- Update UI list
        SendNUIMessage({action="updateSpawnedList", data=GetSerializableSpawnedObjects()})
        
        DebugLog("USER", "Renamed object at index " .. index .. " to: " .. newName)
        cb({status = 'ok'})
    else
        cb({status = 'error', message = 'Invalid rename data'})
    end
end)

-- Handle player position request for proximity grouping
RegisterNUICallback('getPlayerPosition', function(data, cb)
    local playerPed = PlayerPedId()
    local pos = GetEntityCoords(playerPed)
    
    cb({
        x = pos.x,
        y = pos.y,
        z = pos.z
    })
end)

-- ================================
-- TESTZONE SYSTEM IMPLEMENTATION
-- ================================

-- Debug and Test Zone Configuration
-- debugConfig already declared at top of file - don't redeclare!
local isInTestZone = false
local testZoneCheckInterval = 5000 -- Check every 5 seconds

-- Load debug configuration
function LoadDebugConfig()
    local configFile = LoadResourceFile(GetCurrentResourceName(), "debug_config.lua")
    if configFile then
        local chunk, err = load(configFile)
        if chunk then
            local success, config = pcall(chunk)
            if success and config then
                debugConfig = config
                DebugLog("GENERAL", "Debug config loaded - TestZone: " .. (config.testZone.enabled and "ENABLED" or "DISABLED"))
                if config.testZone.enabled then
                    DebugLog("GENERAL", string.format("TestZone center: %.1f, %.1f, %.1f (radius: %.1fm)", 
                        config.testZone.center.x, config.testZone.center.y, config.testZone.center.z, config.testZone.radius))
                end
                if config.userManagement then
                    DebugLog("USER", string.format("TestZone UserManagement config - AutoPromote: %s", tostring(config.userManagement.autoPromoteFirstUser)))
                end
                return true
            else
                DebugLog("GENERAL", "ERROR: Failed to execute debug config: " .. tostring(config))
            end
        else
            DebugLog("GENERAL", "ERROR: Failed to load debug config: " .. tostring(err))
        end
    else
        DebugLog("GENERAL", "WARNING: debug_config.lua not found, using defaults")
    end
    
    -- Default config
    debugConfig = {
        enabled = false,
        testZone = { enabled = false },
        userManagement = { autoPromoteFirstUser = false, requireApproval = false }
    }
    return false
end

-- Check if player is in test zone
function IsPlayerInTestZone()
    if not debugConfig or not debugConfig.testZone or not debugConfig.testZone.enabled then
        DebugLog("GENERAL", "TestZone not enabled or config missing")
        return false
    end
    
    if not debugConfig.testZone.center then
        DebugLog("GENERAL", "TestZone center coordinates missing!")
        return false
    end
    
    local playerPed = PlayerPedId()
    local playerPos = GetEntityCoords(playerPed)
    local center = debugConfig.testZone.center
    local radius = debugConfig.testZone.radius or 100.0
    
    local distance = #(vector3(playerPos.x, playerPos.y, playerPos.z) - vector3(center.x, center.y, center.z))
    
    -- Only log if specific debug level is enabled
    if debugConfig and debugConfig.levels and debugConfig.levels.TESTZONE then
        DebugLog("GENERAL", string.format("TestZone check - Distance: %.1fm, Radius: %.1fm, InZone: %s", 
            distance, radius, distance <= radius and "YES" or "NO"))
    end
    
    return distance <= radius
end

-- TestZone monitoring thread - ENABLED for auto menu control
CreateThread(function()
    LoadDebugConfig()
    
    -- Wait a bit for config to load properly
    Wait(2000)
    
    if not debugConfig or not debugConfig.testZone or not debugConfig.testZone.enabled then
        DebugLog("GENERAL", "TestZone disabled, monitoring thread stopped")
        return
    end
    
    local wasInZone = false
    
    while true do
        Wait(testZoneCheckInterval)
        
        local currentlyInZone = IsPlayerInTestZone()
        
        -- Zone entry/exit handling
        if currentlyInZone and not wasInZone then
            DebugLog("GENERAL", "🟢 ENTERED TestZone - Special features activated!")
            TriggerEvent('chat:addMessage', {
                color = { 34, 197, 94 },
                multiline = true,
                args = { "[TestZone]", "🟢 TestZone girişi! Özel kontroller aktif." }
            })
            
            -- Show TestZone Controls UI instead of auto-opening menu
            if debugConfig.testZone.showControlsUI then
                DebugLog("MENU", "Showing TestZone controls UI")
                SendNUIMessage({
                    action = 'showTestZoneUI',
                    show = true
                })
            end
            
        elseif not currentlyInZone and wasInZone then
            DebugLog("GENERAL", "🔴 EXITED TestZone - Special features deactivated")
            TriggerEvent('chat:addMessage', {
                color = { 239, 68, 68 },
                multiline = true,
                args = { "[TestZone]", "🔴 TestZone çıkışı! Özel kontroller deaktif." }
            })
            
            -- Hide TestZone Controls UI
            if debugConfig.testZone.showControlsUI then
                DebugLog("MENU", "Hiding TestZone controls UI")
                SendNUIMessage({
                    action = 'showTestZoneUI',
                    show = false
                })
            end
        end
        
        wasInZone = currentlyInZone
    end
end)

-- TestZone Special Controls Thread
CreateThread(function()
    while true do
        Wait(0) -- Check every frame for responsive controls
        
        -- Only run special controls if we're in TestZone and it's enabled
        if debugConfig and debugConfig.testZone and debugConfig.testZone.enabled and 
           debugConfig.testZone.specialControls and debugConfig.testZone.specialControls.enabled and
           IsPlayerInTestZone() then
           
            local controls = debugConfig.testZone.specialControls
            
            -- Quick Spawn (INSERT key)
            if IsControlJustPressed(0, controls.quickSpawn or 121) then
                if not isMenuOpen then
                    DebugLog("MENU", "TestZone Quick Spawn - Opening menu")
                    ToggleMenu()
                end
                TriggerEvent('chat:addMessage', {
                    color = { 0, 191, 255 },
                    args = { "[TestZone]", "INSERT - Hızlı spawn menüsü" }
                })
            end
            
            -- Quick Delete (DELETE key)
            if IsControlJustPressed(0, controls.quickDelete or 177) then
                TriggerEvent('chat:addMessage', {
                    color = { 255, 100, 100 },
                    args = { "[TestZone]", "DELETE - Hızlı silme (yakındaki objeler)" }
                })
                
                -- Find and delete nearest object
                local playerPed = PlayerPedId()
                local playerPos = GetEntityCoords(playerPed)
                local nearestObjectIndex = nil
                local nearestDistance = 5.0 -- 5 meter range
                
                for i, obj in pairs(spawnedObjects) do
                    if obj and obj.entity and DoesEntityExist(obj.entity) then
                        local objPos = GetEntityCoords(obj.entity)
                        local distance = #(playerPos - objPos)
                        if distance < nearestDistance then
                            nearestDistance = distance
                            nearestObjectIndex = i
                        end
                    end
                end
                
                if nearestObjectIndex then
                    DeleteSpawnedObject(nearestObjectIndex)
                    TriggerEvent('chat:addMessage', {
                        color = { 255, 255, 0 },
                        args = { "[TestZone]", "Obje silindi! Mesafe: " .. string.format("%.1f", nearestDistance) .. "m" }
                    })
                else
                    TriggerEvent('chat:addMessage', {
                        color = { 255, 165, 0 },
                        args = { "[TestZone]", "5m yakınında silinecek obje bulunamadı" }
                    })
                end
            end
            
            -- Quick Edit (E key)
            if IsControlJustPressed(0, controls.quickEdit or 38) then
                -- Check if currently placing an object
                if placing then
                    TriggerEvent('chat:addMessage', {
                        color = { 239, 68, 68 },
                        args = { "[TestZone]", "❌ Finish placement first before editing!" }
                    })
                    return
                end
                
                -- Check if already editing
                if editingObjectData then
                    TriggerEvent('chat:addMessage', {
                        color = { 239, 68, 68 },
                        args = { "[TestZone]", "❌ Already editing an object!" }
                    })
                    return
                end
                
                TriggerEvent('chat:addMessage', {
                    color = { 147, 51, 234 },
                    args = { "[TestZone]", "E - Hızlı düzenleme modu" }
                })
                
                -- Find nearest object and enter edit mode
                local playerPed = PlayerPedId()
                local playerPos = GetEntityCoords(playerPed)
                local nearestObjectIndex = nil
                local nearestDistance = 3.0 -- 3 meter range for editing
                
                for i, obj in pairs(spawnedObjects) do
                    if obj and obj.entity and DoesEntityExist(obj.entity) then
                        local objPos = GetEntityCoords(obj.entity)
                        local distance = #(playerPos - objPos)
                        if distance < nearestDistance then
                            nearestDistance = distance
                            nearestObjectIndex = i
                        end
                    end
                end
                
                if nearestObjectIndex then
                    -- Start edit mode like in the original code
                    local objData = spawnedObjects[nearestObjectIndex]
                    editingObjectData = {
                        entity = objData.entity, 
                        originalIndex = nearestObjectIndex, 
                        model = objData.model,
                        originalCoords = GetEntityCoords(objData.entity), 
                        originalHeading = GetEntityHeading(objData.entity),
                        timestamp = objData.timestamp
                    }
                    
                    -- Apply green glowing wireframe effect immediately when starting edit
                    SetEntityAlpha(objData.entity, 180, false)
                    SetEntityDrawOutline(objData.entity, true)
                    SetEntityDrawOutlineColor(104, 182, 91, 255) -- Green outline
                    SetEntityRenderScorched(objData.entity, true)
                    
                    SendNUIMessage({action = 'editingModeUpdate', message = "EDIT MODE: WASD:Move | Alt/F:Height | Q/E:Rotate (1°) | G:Snap Toggle | X:Toggle 5° Mode | R:Reset Rotation | LMB:Save | RMB:Cancel | Rotation: " .. math.floor(GetEntityHeading(objData.entity)) .. "°", editingActive = true})
                    Citizen.CreateThread(KeyboardEditLoop)
                    
                    TriggerEvent('chat:addMessage', {
                        color = { 255, 255, 0 },
                        args = { "[TestZone]", "Düzenleme başlatıldı! Mesafe: " .. string.format("%.1f", nearestDistance) .. "m" }
                    })
                else
                    TriggerEvent('chat:addMessage', {
                        color = { 255, 165, 0 },
                        args = { "[TestZone]", "3m yakınında düzenlenecek obje bulunamadı" }
                    })
                end
            end
            
            -- Help Key (G key)
            if IsControlJustPressed(0, controls.helpKey or 47) then
                TriggerEvent('chat:addMessage', {
                    color = { 34, 197, 94 },
                    multiline = true,
                    args = { "[TestZone Yardım]", 
                        "🎮 Özel Kontroller:\n" ..
                        "INSERT - Hızlı spawn menüsü\n" ..
                        "DELETE - Yakındaki objeyi sil\n" ..
                        "E - Yakındaki objeyi düzenle\n" ..
                        "G - Bu yardım menüsü\n" ..
                        "F7 - Ana menü"
                    }
                })
            end
        else
            -- If not in TestZone, wait longer to save performance
            Wait(1000)
        end
    end
end)

-- F7 Permission response from server
local serverPermissionResponse = nil

RegisterNetEvent('bazq-objectplace:f7PermissionResponse')
AddEventHandler('bazq-objectplace:f7PermissionResponse', function(hasPermission)
    serverPermissionResponse = hasPermission
    DebugLog("GENERAL", "Server F7 permission response: " .. tostring(hasPermission))
    
    -- If permission granted, open menu directly
    if hasPermission and isMenuLoading then
        DebugLog("MENU", "Server permission granted - opening menu")
        isMenuLoading = false
        isMenuOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({action = 'open'})
    elseif not hasPermission then
        DebugLog("MENU", "Server permission denied")
        isMenuLoading = false
        TriggerEvent('chat:addMessage', {
            color = { 239, 68, 68 },
            args = { "[bazq-os]", "🔒 Access denied! You need admin permissions to use F7." }
        })
    end
end)

-- F6 Permission response from server (separate from F7 to avoid menu opening)
RegisterNetEvent('bazq-objectplace:f6PermissionResponse')
AddEventHandler('bazq-objectplace:f6PermissionResponse', function(hasPermission)
    f6PermissionResponse = hasPermission  -- Use separate F6 variable
    DebugLog("FREECAM", "Server F6 permission response: " .. tostring(hasPermission))
    -- F6 doesn't open menu - just sets permission flag for CanUseF6Freecam()
end)

-- Enhanced F7 permission check with new logic
-- REMOVED CanUseF7Menu - No longer needed with simplified F7 process
-- F7 now directly uses server admin check without complex client-side logic

-- Register F7 key command - SIMPLIFIED NORMAL ADMIN PROCESS
RegisterCommand('bazq_f7', function()
    -- Clean up any stuck NUI focus first
    if IsNuiFocused() then
        DebugLog("MENU", "Cleaning up stuck NUI focus at start of F7 command")
        SetNuiFocus(false, false)
    end
    
    -- Check if menu is already open - close it
    if IsNuiFocused() or isMenuOpen then
        DebugLog("MENU", "Closing menu...")
        SetNuiFocus(false, false)
        SendNUIMessage({action = 'close'})
        isMenuOpen = false
        isMenuLoading = false
        return
    end
    
    -- Prevent multiple menu opening attempts
    if isMenuLoading then
        DebugLog("MENU", "Menu already loading, ignoring F7 press")
        return
    end
    
    -- NORMAL ADMIN PROCESS ONLY - No TestZone logic here
    DebugLog("MENU", "F7 pressed - requesting admin permission from server")
    isMenuLoading = true
    TriggerServerEvent("bazq-objectplace:checkAdminPermission")
end, false)

-- Bind F7 key to command
RegisterKeyMapping('bazq_f7', 'Open bazq Object Spawner Menu', 'keyboard', 'F7')

--[[ TESTZONE SYSTEM COMMENTED OUT - NOT NEEDED
-- SEPARATE TESTZONE TRIGGER SYSTEM
RegisterCommand('bazq_testzone_f7', function()
    DebugLog("TESTZONE", "🏢 TestZone F7 triggered")
    
    -- Clean up any stuck NUI focus first
    if IsNuiFocused() then
        DebugLog("TESTZONE", "Cleaning up stuck NUI focus")
        SetNuiFocus(false, false)
    end
    
    -- Check if menu is already open - close it
    if IsNuiFocused() or isMenuOpen then
        DebugLog("TESTZONE", "Closing TestZone menu...")
        SetNuiFocus(false, false)
        SendNUIMessage({action = 'close'})
        isMenuOpen = false
        isMenuLoading = false
        return
    end
    
    -- Prevent multiple menu opening attempts
    if isMenuLoading then
        DebugLog("TESTZONE", "TestZone menu already loading")
        return
    end
    
    -- Check if player is in TestZone
    if not (debugConfig and debugConfig.testZone and debugConfig.testZone.enabled) then
        TriggerEvent('chat:addMessage', {
            color = { 239, 68, 68 },
            args = { "[bazq-os]", "🔒 TestZone is not enabled!" }
        })
        return
    end
    
    local inZone = IsPlayerInTestZone()
    if not inZone then
        TriggerEvent('chat:addMessage', {
            color = { 239, 68, 68 },
            args = { "[bazq-os]", "🔒 You must be in the TestZone to use this command!" }
        })
        return
    end
    
    -- Open TestZone menu directly
    DebugLog("TESTZONE", "Opening TestZone menu directly")
    isMenuLoading = true
    
    -- Create TestZone user settings
    local testZoneUserSettings = {
        role = "mapper",
        packages = {"wall_pack_1"}, -- Default packages for TestZone
        username = "TestZone User"
    }
    
    -- Trigger menu opening directly
    TriggerEvent("bazq-objectplace:receiveUserSettings", testZoneUserSettings)
    
    TriggerEvent('chat:addMessage', {
        color = { 34, 197, 94 },
        args = { "[bazq-os]", "✅ TestZone menu opened!" }
    })
end, false)

-- Bind TestZone F7 to a different key combination (Ctrl+F7)
RegisterKeyMapping('bazq_testzone_f7', 'Open bazq TestZone Menu', 'keyboard', 'LCONTROL+F7')
--]]

-- Register F6 key command
RegisterCommand('bazq_f6', function()
    -- Add debug logging to see what's happening
    DebugLog("FREECAM", "🔍 F6 key pressed - starting freecam toggle process")
    
    -- Check if freecam is already active (can disable without permission check)
    if isFreecamActive then
        DebugLog("FREECAM", "Freecam is active - disabling without permission check")
        ToggleFreecam()
        return
    end
    
    -- For enabling freecam, check permissions first
    DebugLog("FREECAM", "Freecam is inactive - checking permissions before enabling")
    local canUse = CanUseF6Freecam()
    DebugLog("FREECAM", "Permission check result: " .. tostring(canUse))
    
    if canUse then
        DebugLog("FREECAM", "✅ Permission granted - enabling freecam")
        ToggleFreecam()
    else
        DebugLog("FREECAM", "❌ Permission denied - cannot enable freecam")
        TriggerEvent('chat:addMessage', {
            color = { 239, 68, 68 },
            args = { "[bazq-os]", "🔒 F6 Freecam access denied! Check your permissions." }
        })
    end
end, false)

-- Bind F6 key to command
RegisterKeyMapping('bazq_f6', 'Toggle bazq Freecam (Noclip)', 'keyboard', 'F6')

-- Debug F6 command
RegisterCommand('debugf6', function()
    DebugLog("FREECAM", "========== F6 DEBUG ==========")
    DebugLog("FREECAM", "debugConfig exists: " .. tostring(debugConfig ~= nil))
    DebugLog("FREECAM", "debugConfig memory address: " .. tostring(debugConfig))
    DebugLog("FREECAM", "debugConfig.testZone address: " .. tostring(debugConfig and debugConfig.testZone))
    if debugConfig and debugConfig.testZone then
        DebugLog("FREECAM", "testZone.enabled: " .. tostring(debugConfig.testZone.enabled))
        if debugConfig.testZone.enabled then
            DebugLog("FREECAM", "🟢 TestZone IS ENABLED - should grant global F6 access")
        else
            DebugLog("FREECAM", "🔴 TestZone IS DISABLED - will check admin permissions")
        end
    else
        DebugLog("FREECAM", "❌ No testZone config found")
    end
    DebugLog("FREECAM", "Calling CanUseF6Freecam()...")
    local result = CanUseF6Freecam()
    DebugLog("FREECAM", "CanUseF6Freecam() result: " .. tostring(result))
    DebugLog("FREECAM", "========== END F6 DEBUG ==========")
end, false)

--- Enhanced debug command to trace F7 issue  
RegisterCommand('debugf7', function()
    DebugLog("MENU", "========== ENHANCED F7 DEBUG ==========")
    
    -- Check debug config loading
    DebugLog("MENU", "1. debugConfig exists: " .. tostring(debugConfig ~= nil))
    if debugConfig then
        DebugLog("MENU", "2. debugConfig.testZone exists: " .. tostring(debugConfig.testZone ~= nil))
        if debugConfig.testZone then
            DebugLog("MENU", "3. testZone.enabled: " .. tostring(debugConfig.testZone.enabled))
            DebugLog("MENU", "4. testZone.center exists: " .. tostring(debugConfig.testZone.center ~= nil))
            if debugConfig.testZone.center then
                local center = debugConfig.testZone.center
                DebugLog("MENU", string.format("5. Center: x=%.2f, y=%.2f, z=%.2f", center.x, center.y, center.z))
                DebugLog("MENU", "6. testZone.radius: " .. tostring(debugConfig.testZone.radius))
                
                -- Check player position and distance
                local playerPed = PlayerPedId()
                local playerPos = GetEntityCoords(playerPed)
                DebugLog("MENU", string.format("7. Player: x=%.2f, y=%.2f, z=%.2f", playerPos.x, playerPos.y, playerPos.z))
                
                local distance = #(vector3(playerPos.x, playerPos.y, playerPos.z) - vector3(center.x, center.y, center.z))
                DebugLog("MENU", string.format("8. Distance to center: %.2f meters", distance))
                DebugLog("MENU", string.format("9. Required radius: %.2f meters", debugConfig.testZone.radius))
                DebugLog("MENU", string.format("10. In zone calculation: %s", tostring(distance <= debugConfig.testZone.radius)))
            end
        end
    end
    
    -- Test zone check function
    local inZone = IsPlayerInTestZone()
    DebugLog("MENU", "11. IsPlayerInTestZone() result: " .. tostring(inZone))
    
    DebugLog("MENU", "========== END F7 DEBUG ==========")
end, false)
