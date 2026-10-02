-- ================================
-- SYSTEM INITIALIZATION
-- ================================

-- Core bazq debug wrapper
local function dbg(msg)
    if Config.Debug then
        print(("^4[bazq-%s] ^7%s"):format("os", msg))
    end
end

-- Compatibility wrappers for existing code
local function DebugPlacement(msg) dbg(msg) end
local function DebugDeletion(msg) dbg(msg) end
local function DebugLoading(msg) dbg(msg) end
local function DebugMenu(msg) dbg(msg) end
local function DebugUser(msg) dbg(msg) end
local function DebugGeneral(msg) dbg(msg) end
local function DebugEdit(msg) dbg(msg) end
local function DebugFreecam(msg) dbg(msg) end
local function DebugSave(msg) dbg(msg) end
local function DebugCollision(msg) dbg(msg) end
local function DPrint(level, msg) dbg(msg) end
local function DebugLog(level, msg) dbg(msg) end

-- Robust entity deletion with network control request
local function SafeDeleteEntity(entity)
    if not entity or not DoesEntityExist(entity) then return end
    
    -- Request network control for networked entities
    if NetworkGetEntityIsNetworked(entity) then
        local timeout = 0
        NetworkRequestControlOfEntity(entity)
        while not NetworkHasControlOfEntity(entity) and timeout < 50 do
            Wait(10)
            timeout = timeout + 1
        end
    end
    
    -- Ensure it can be deleted
    SetEntityAsMissionEntity(entity, true, true)
    DeleteEntity(entity)
    
    -- Final check
    if DoesEntityExist(entity) then
        -- Last ditch effort: move it far away to clear it from scene if deletion failed
        SetEntityCoords(entity, 0.0, 0.0, -100.0, false, false, false, false)
        DetachEntity(entity, true, true)
    end
end

-- Manual F7 test command will be defined after ToggleMenu function

-- ================================
-- SCRIPT START
-- ================================

local placing = false
local selectedObject = nil
local objectEntity = nil
local editingObjectData = nil
local pathDrawing = false
local spawnedObjects = {}
local lastAppliedRevision = 0
local pendingPlacedEntities = {} -- map of requestId -> objectData
local pendingBatchEntities = {} -- map of requestId -> list of objectData

local function GenerateRequestId(prefix)
    prefix = prefix or "req"
    return string.format("%s_%d_%d", prefix, GetGameTimer(), math.random(1000, 9999))
end

local currentPlacementOptions = {
    snapToGround = true,
    timestamp = "", -- Will be set from JS
    playerName = "Unknown" -- Will be set from osadmin.json displayName
}

-- Global helper for Freecam to check if we are currently building
function IsPlacementActive()
    return placing or editingObjectData ~= nil or pathDrawing == true
end
local manualHeightAdjusted = false
local objectsConfig = {}
local isMenuOpen = false
local isControlsDisabled = false
local isFreecamActive = false
local ToggleFreecam

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

-- Safe load mode flag (set by server on resource start if players are online)
local SAFE_LOAD_MODE = false

-- ================================
-- TARGET SYSTEM INTEGRATION
-- ================================

local function HasSpawnPermissions()
    if not currentUserSettings or not currentUserSettings.role then
        -- Fallback to check if we can open F7 at all (guest has no permissions)
        return false
    end
    local role = currentUserSettings.role
    return role == "owner" or role == "admin" or role == "mapper"
end

local function GetObjectIndexFromEntity(entity)
    for i, obj in ipairs(spawnedObjects) do
        if obj.entity == entity then
            return i
        end
    end
    return nil
end

local function GetObjectByEntity(entity)
    for i, obj in ipairs(spawnedObjects) do
        if obj.entity == entity then
            return obj, i
        end
    end
    return nil, nil
end

local function GetObjectById(id)
    if not id or id == "" then return nil, nil end
    for i, obj in ipairs(spawnedObjects) do
        if obj.id == id then
            return obj, i
        end
    end
    return nil, nil
end

local function GetSpawnedObjectByIdOrIndex(id, index)
    if id and id ~= "" then
        local obj, i = GetObjectById(id)
        if obj then return obj, i end
    end
    if index and spawnedObjects[index] then
        return spawnedObjects[index], index
    end
    return nil, nil
end

local function StartTargetEdit(index)
    if not HasSpawnPermissions() then
        SetNotificationTextEntry("STRING")
        AddTextComponentString("~r~Access Denied~w~\nYou do not have permissions to edit objects.")
        DrawNotification(false, false)
        return
    end
    if placing or editingObjectData then return end
    
    local objData = spawnedObjects[index]
    if objData and objData.entity and DoesEntityExist(objData.entity) then
        ClearAllHighlights()
        
        editingObjectData = {
            id = objData.id,
            entity = objData.entity, originalIndex = index, model = objData.model,
            originalCoords = GetEntityCoords(objData.entity), originalHeading = GetEntityHeading(objData.entity),
            timestamp = objData.timestamp, playerName = objData.playerName
        }
        
        SetEntityAlpha(objData.entity, 180, false)
        SetEntityDrawOutline(objData.entity, true)
        SetEntityDrawOutlineColor(104, 182, 91, 255)
        SetEntityRenderScorched(objData.entity, true)
        
        SetNuiFocus(false, false)
        SendNUIMessage({action = 'close'})
        SendNUIMessage({action = 'editingModeUpdate', message = "EDIT MODE: WASD:Move | Alt/F:Height | Q/E:Rotate (1°) | G:Snap Toggle | X:Toggle 5° Mode | R:Reset Rotation | LMB:Save | RMB:Cancel | Rotation: " .. math.floor(GetEntityHeading(objData.entity)) .. "°", editingActive = true})
        Citizen.CreateThread(KeyboardEditLoop)
    end
end

local function StartTargetDuplicate(index)
    if not HasSpawnPermissions() then
        SetNotificationTextEntry("STRING")
        AddTextComponentString("~r~Access Denied~w~\nYou do not have permissions to duplicate objects.")
        DrawNotification(false, false)
        return
    end
    if editingObjectData or placing then return end
    
    local objData = spawnedObjects[index]
    if objData and objData.model and objData.entity and DoesEntityExist(objData.entity) then
        local originalCoords = GetEntityCoords(objData.entity)
        local originalHeading = GetEntityHeading(objData.entity)
        
        local playerName = currentPlacementOptions.playerName or "Unknown"
        local timestamp = GetRealTimestamp()
        
        local modelHash = GetHashKey(objData.model)
        if IsModelValid(modelHash) then
            RequestModel(modelHash)
            while not HasModelLoaded(modelHash) do
                Citizen.Wait(10)
            end
            
            local newEntity = CreateObject(modelHash, originalCoords.x, originalCoords.y, originalCoords.z, true, true, false)
            if DoesEntityExist(newEntity) then
                SetEntityHeading(newEntity, originalHeading)
                PlaceObjectOnGroundProperly(newEntity)
                FreezeEntityPosition(newEntity, true)
                
                local rot = GetEntityRotation(newEntity, 2)
                local newIndex = #spawnedObjects + 1
                local reqId = GenerateRequestId("dup")
                local newRecord = {
                    id = nil, -- Explicitly nil: duplicated objects MUST receive fresh server-generated IDs
                    entity = newEntity,
                    model = objData.model,
                    coords = GetEntityCoords(newEntity),
                    heading = GetEntityHeading(newEntity),
                    rotation = {x = rot.x, y = rot.y, z = rot.z},
                    playerName = playerName,
                    timestamp = timestamp,
                    originalIndex = newIndex
                }
                spawnedObjects[newIndex] = newRecord
                pendingPlacedEntities[reqId] = newRecord
                
                -- Register target for the new entity
                if typeof(RegisterTargetForEntity) == "function" or _G.RegisterTargetForEntity then
                    RegisterTargetForEntity(newEntity)
                end
                
                TriggerServerEvent("bazq-objectplace:placeObject", {
                    model = objData.model,
                    coords = { x = newRecord.coords.x, y = newRecord.coords.y, z = newRecord.coords.z },
                    heading = newRecord.heading,
                    rotation = newRecord.rotation,
                    playerName = playerName,
                    timestamp = timestamp,
                    requestId = reqId
                })
                
                SendNUIMessage({
                    action = 'updateSpawnedList',
                    data = GetSerializableSpawnedObjects()
                })
                
                SetNuiFocus(false, false)
                SendNUIMessage({action = 'close'})
                isMenuOpen = false
                
                editingObjectData = {
                    id = nil,
                    entity = newEntity, 
                    originalIndex = newIndex, 
                    model = objData.model,
                    originalCoords = GetEntityCoords(newEntity), 
                    originalHeading = GetEntityHeading(newEntity),
                    timestamp = timestamp,
                    playerName = playerName
                }
                
                SetEntityAlpha(newEntity, 180, false)
                SetEntityDrawOutline(newEntity, true)
                SetEntityDrawOutlineColor(104, 182, 91, 255)
                SetEntityRenderScorched(newEntity, true)
                
                SendNUIMessage({action = 'editingModeUpdate', message = "EDIT MODE: WASD:Move | Alt/F:Height | Q/E:Rotate (1°) | G:Snap Toggle | X:Toggle 5° Mode | R:Reset Rotation | LMB:Save | RMB:Cancel | Rotation: " .. math.floor(GetEntityHeading(newEntity)) .. "°", editingActive = true})
                Citizen.CreateThread(KeyboardEditLoop)
            end
            SetModelAsNoLongerNeeded(modelHash)
        end
    end
end

local function StartTargetDelete(index)
    if not HasSpawnPermissions() then
        SetNotificationTextEntry("STRING")
        AddTextComponentString("~r~Access Denied~w~\nYou do not have permissions to delete objects.")
        DrawNotification(false, false)
        return
    end
    if highlightedObjectIndex == index then
        ClearAllHighlights()
    end
    local objData = spawnedObjects[index]
    DeleteSpawnedObject(index, objData and objData.id)
end

local ConvertToGate

function RegisterTargetForEntity(entity)
    if not entity or not DoesEntityExist(entity) then return end
    
    if GetResourceState('ox_target') == 'started' then
        exports.ox_target:addLocalEntity(entity, {
            {
                name = 'bazq_os_edit',
                icon = 'fas fa-edit',
                label = 'Edit Object',
                onSelect = function(data)
                    local idx = GetObjectIndexFromEntity(data.entity)
                    if idx then StartTargetEdit(idx) end
                end
            },
            {
                name = 'bazq_os_duplicate',
                icon = 'fas fa-clone',
                label = 'Duplicate Object',
                onSelect = function(data)
                    local idx = GetObjectIndexFromEntity(data.entity)
                    if idx then StartTargetDuplicate(idx) end
                end
            },
            {
                name = 'bazq_os_converttogate',
                icon = 'fas fa-door-open',
                label = 'Convert to Gate (Kapı Yap)',
                canInteract = function(entity, distance, coords, name, bone)
                    local model = GetEntityModel(entity)
                    local replaceable = {
                        GetHashKey("bazq-sur1"), GetHashKey("bazq-sur2"), GetHashKey("bazq-sur3"), GetHashKey("bazq-sur4"), GetHashKey("bazq-sur5"),
                        GetHashKey("bazq-wall2_wall1"), GetHashKey("bazq-wall2_wall2"), GetHashKey("bazq-wall2_wall3"), GetHashKey("bazq-wall2_wall4"), GetHashKey("bazq-wall2_wall5"),
                        GetHashKey("bazq-wall3_wall1"), GetHashKey("bazq-wall3_wall2"), GetHashKey("bazq-wall3_wall3")
                    }
                    for _, h in ipairs(replaceable) do
                        if model == h then return true end
                    end
                    return false
                end,
                onSelect = function(data)
                    ConvertToGate(data.entity)
                end
            },
            {
                name = 'bazq_os_delete',
                icon = 'fas fa-trash',
                label = 'Delete Object',
                onSelect = function(data)
                    local idx = GetObjectIndexFromEntity(data.entity)
                    if idx then StartTargetDelete(idx) end
                end
            }
        })
    elseif GetResourceState('qb-target') == 'started' then
        exports['qb-target']:AddTargetEntity(entity, {
            options = {
                {
                    type = "client",
                    event = "bazq-os:targetEdit",
                    icon = "fas fa-edit",
                    label = "Edit Object",
                },
                {
                    type = "client",
                    event = "bazq-os:targetDuplicate",
                    icon = "fas fa-clone",
                    label = "Duplicate Object",
                },
                {
                    type = "client",
                    event = "bazq-os:targetConvertToGate",
                    icon = "fas fa-door-open",
                    label = "Convert to Gate (Kapı Yap)",
                    canInteract = function(entity)
                        local model = GetEntityModel(entity)
                        local replaceable = {
                            GetHashKey("bazq-sur1"), GetHashKey("bazq-sur2"), GetHashKey("bazq-sur3"), GetHashKey("bazq-sur4"), GetHashKey("bazq-sur5"),
                            GetHashKey("bazq-wall2_wall1"), GetHashKey("bazq-wall2_wall2"), GetHashKey("bazq-wall2_wall3"), GetHashKey("bazq-wall2_wall4"), GetHashKey("bazq-wall2_wall5"),
                            GetHashKey("bazq-wall3_wall1"), GetHashKey("bazq-wall3_wall2"), GetHashKey("bazq-wall3_wall3")
                        }
                        for _, h in ipairs(replaceable) do
                            if model == h then return true end
                        end
                        return false
                    end
                },
                {
                    type = "client",
                    event = "bazq-os:targetDelete",
                    icon = "fas fa-trash",
                    label = "Delete Object",
                }
            },
            distance = 3.0
        })
    end
end

function UnregisterTargetForEntity(entity)
    if not entity or not DoesEntityExist(entity) then return end
    if GetResourceState('ox_target') == 'started' then
        exports.ox_target:removeLocalEntity(entity)
    elseif GetResourceState('qb-target') == 'started' then
        exports['qb-target']:RemoveTargetEntity(entity)
    end
end

-- Client events for qb-target compat
RegisterNetEvent('bazq-os:targetEdit', function(data)
    local entity = data and data.entity or nil
    if not entity then return end
    local idx = GetObjectIndexFromEntity(entity)
    if idx then StartTargetEdit(idx) end
end)

RegisterNetEvent('bazq-os:targetDuplicate', function(data)
    local entity = data and data.entity or nil
    if not entity then return end
    local idx = GetObjectIndexFromEntity(entity)
    if idx then StartTargetDuplicate(idx) end
end)

RegisterNetEvent('bazq-os:targetDelete', function(data)
    local entity = data and data.entity or nil
    if not entity then return end
    local idx = GetObjectIndexFromEntity(entity)
    if idx then StartTargetDelete(idx) end
end)

RegisterNetEvent("bazq-objectplace:setSafeLoadMode")
AddEventHandler("bazq-objectplace:setSafeLoadMode", function(state)
    SAFE_LOAD_MODE = state and true or false
    DebugLog("LOADING", "SafeLoadMode set to " .. tostring(SAFE_LOAD_MODE))
end)

ConvertToGate = function(entity)
    local idx = GetObjectIndexFromEntity(entity)
    if not idx then return end
    
    local objData = spawnedObjects[idx]
    if not objData then return end
    
    local originalId = objData.id
    local model = objData.model
    local coords = objData.coords
    local heading = objData.heading
    
    local isSurWall = false
    local isWall2 = false
    local isWall3 = false
    
    for i = 1, 5 do
        if model == "bazq-sur" .. i then isSurWall = true end
        if model == "bazq-wall2_wall" .. i then isWall2 = true end
    end
    for i = 1, 3 do
        if model == "bazq-wall3_wall" .. i then isWall3 = true end
    end
    
    if not isSurWall and not isWall2 and not isWall3 then
        SendNUIMessage({action = 'log', message = 'Convert to Gate: Targeted object is not a replaceable wall.', type = 'error'})
        return
    end
    
    local targetGateModel = nil
    if isSurWall then
        targetGateModel = "bazq-sur_kapi"
    elseif isWall2 then
        targetGateModel = "bazq-wall2_gate1"
    elseif isWall3 then
        targetGateModel = "bazq-wall3_gateframe"
    end
    
    if not targetGateModel then return end
    
    local gateHash = GetHashKey(targetGateModel)
    RequestModel(gateHash)
    local startTime = GetGameTimer()
    while not HasModelLoaded(gateHash) do
        if GetGameTimer() - startTime > 3000 then break end
        Citizen.Wait(10)
    end
    
    if not HasModelLoaded(gateHash) then
        SendNUIMessage({action = 'log', message = 'Failed to load gate model.', type = 'error'})
        return
    end
    
    -- Delete targeted wall first
    UnregisterTargetForEntity(entity)
    SafeDeleteEntity(entity)
    table.remove(spawnedObjects, idx)
    
    local spawnCoords = vector3(coords.x, coords.y, coords.z)
    if isSurWall then
        local foundNeighbourIdx = nil
        local neighbourEntity = nil
        for i, otherObj in ipairs(spawnedObjects) do
            if otherObj.model and otherObj.model:match("bazq%-sur%d+") then
                local dist = #(vector3(otherObj.coords.x, otherObj.coords.y, otherObj.coords.z) - spawnCoords)
                if dist > 0.5 and dist <= 11.0 then
                    foundNeighbourIdx = i
                    neighbourEntity = otherObj.entity
                    break
                end
            end
        end
        
        if foundNeighbourIdx and neighbourEntity then
            local nCoords = spawnedObjects[foundNeighbourIdx].coords
            spawnCoords = vector3(
                (coords.x + nCoords.x) / 2.0,
                (coords.y + nCoords.y) / 2.0,
                (coords.z + nCoords.z) / 2.0
            )
            UnregisterTargetForEntity(neighbourEntity)
            SafeDeleteEntity(neighbourEntity)
            table.remove(spawnedObjects, foundNeighbourIdx)
        else
            SendNUIMessage({action = 'log', message = 'Gate placed. Delete the adjacent wall manually to prevent overlap.', type = 'warning'})
        end
    end
    
    local gateObj = CreateObject(gateHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, true, true, false)
    if DoesEntityExist(gateObj) then
        SetEntityAsMissionEntity(gateObj, true, true)
        FreezeEntityPosition(gateObj, true)
        SetEntityCollision(gateObj, true, true)
        SetEntityHeading(gateObj, heading)
        
        local isDualDoors = false
        local interiorEnt = nil
        local interiorModelVal = nil
        
        if targetGateModel == "bazq-sur_kapi" then
            local doorHash = GetHashKey("bazq-sur_mkapi")
            RequestModel(doorHash)
            local doorStartTime = GetGameTimer()
            while not HasModelLoaded(doorHash) do
                if GetGameTimer() - doorStartTime > 3000 then break end
                Citizen.Wait(10)
            end
            
            if HasModelLoaded(doorHash) then
                local headingRad = math.rad(heading)
                local forwardX = -math.sin(headingRad)
                local forwardY = math.cos(headingRad)
                
                local door1Coords = vector3(
                    spawnCoords.x + (5.37824 * forwardX),
                    spawnCoords.y + (5.37824 * forwardY),
                    spawnCoords.z
                )
                local door1Entity = CreateObject(doorHash, door1Coords.x, door1Coords.y, door1Coords.z, true, true, false)
                if DoesEntityExist(door1Entity) then
                    SetEntityHeading(door1Entity, heading + 90.0)
                    SetEntityAsMissionEntity(door1Entity, true, true)
                    SetEntityDynamic(door1Entity, true)
                    SetEntityCollision(door1Entity, true, true)
                end
                
                local door2Coords = vector3(
                    spawnCoords.x - (5.37824 * forwardX),
                    spawnCoords.y - (5.37824 * forwardY),
                    spawnCoords.z
                )
                local door2Entity = CreateObject(doorHash, door2Coords.x, door2Coords.y, door2Coords.z, true, true, false)
                if DoesEntityExist(door2Entity) then
                    SetEntityHeading(door2Entity, heading - 90.0)
                    SetEntityAsMissionEntity(door2Entity, true, true)
                    SetEntityDynamic(door2Entity, true)
                    SetEntityCollision(door2Entity, true, true)
                end
                
                if DoesEntityExist(door1Entity) and DoesEntityExist(door2Entity) then
                    interiorEnt = { door1Entity, door2Entity }
                    interiorModelVal = "bazq-sur_mkapi"
                    isDualDoors = true
                end
            end
        end
        
        local rot = GetEntityRotation(gateObj, 2)
        local newIndex = #spawnedObjects + 1
        spawnedObjects[newIndex] = {
            id = originalId, -- Preserves logical placed object identity across gate transformation
            entity = gateObj,
            model = targetGateModel,
            coords = GetEntityCoords(gateObj),
            heading = GetEntityHeading(gateObj),
            rotation = {x = rot.x, y = rot.y, z = rot.z},
            playerName = currentPlacementOptions.playerName or "Unknown",
            timestamp = GetRealTimestamp(),
            originalIndex = newIndex,
            hasDualDoors = isDualDoors,
            interiorEntity = interiorEnt,
            interiorModel = interiorModelVal
        }
        RegisterTargetForEntity(gateObj)
        
        if originalId then
            TriggerServerEvent("bazq-objectplace:updateObject", {
                id = originalId,
                changes = {
                    model = targetGateModel,
                    coords = { x = spawnCoords.x, y = spawnCoords.y, z = spawnCoords.z },
                    heading = gateHeading,
                    rotation = { x = rot.x, y = rot.y, z = rot.z },
                    interiorModel = interiorModelVal,
                    hasDualDoors = isDualDoors
                }
            })
        end
        SendNUIMessage({action = "updateSpawnedList", data = GetSerializableSpawnedObjects()})
        SendNUIMessage({action = 'log', message = 'Wall successfully converted to Gate!', type = 'success'})
    end
    
    SetModelAsNoLongerNeeded(gateHash)
end

RegisterNetEvent("bazq-os:targetConvertToGate", function(data)
    local entity = data.entity
    if entity and DoesEntityExist(entity) then
        ConvertToGate(entity)
    end
end)

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

-- Clean up highlights and spawned entities on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        ClearAllHighlights()
        if inFocus then
            SetNuiFocus(false, false)
        end
        
        -- Prevent ghost entities remaining in the world bridging between restarts 
        if spawnedObjects then
            for _, objData in ipairs(spawnedObjects) do
                if objData.entity and DoesEntityExist(objData.entity) then
                    SetEntityAsMissionEntity(objData.entity, true, true)
                    DeleteEntity(objData.entity)
                end
                if objData.interiorEntity then
                    if type(objData.interiorEntity) == "table" then
                        for _, interiorEnt in ipairs(objData.interiorEntity) do
                            if DoesEntityExist(interiorEnt) then 
                                SetEntityAsMissionEntity(interiorEnt, true, true)
                                DeleteEntity(interiorEnt) 
                            end
                        end
                    elseif DoesEntityExist(objData.interiorEntity) then
                        SetEntityAsMissionEntity(objData.interiorEntity, true, true)
                        DeleteEntity(objData.interiorEntity)
                    end
                end
            end
        end
    end
end)

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

-- Helper function to find ALL nearby wall objects (sorted by distance)
function FindAllNearbyWalls(coords, maxDistance)
    maxDistance = maxDistance or 3.0
    local walls = {}
    
    for i, objData in ipairs(spawnedObjects) do
        if objData.entity and DoesEntityExist(objData.entity) and objData.model then
            -- Check if it's a wall object (from either wall package)
            if objData.model:match("bazq%-sur%d+") or objData.model:match("bazq%-wall2_wall%d+") then
                local wallCoords = GetEntityCoords(objData.entity)
                local distance = #(coords - wallCoords)
                if distance <= maxDistance then
                    table.insert(walls, {
                        data = objData,
                        index = i,
                        distance = distance,
                        entity = objData.entity
                    })
                end
            end
        end
    end
    
    -- Sort by distance (closest first)
    table.sort(walls, function(a, b) return a.distance < b.distance end)
    
    return walls
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
            
            local rot = objData.rotation
            if not rot and objData.entity and DoesEntityExist(objData.entity) then
                local r = GetEntityRotation(objData.entity, 2)
                rot = { x = r.x, y = r.y, z = r.z }
            end
            
            local pkg = GetObjectPackageName(objData.model)
            table.insert(list, {
                id = objData.id,
                model = objData.model,
                originalIndex = i,
                timestamp = objData.timestamp or "",
                playerName = objData.playerName or "Unknown",
                displayName = objData.displayName or GetObjectDisplayName(objData.model),
                coords = coords,
                heading = objData.heading or (objData.entity and DoesEntityExist(objData.entity) and GetEntityHeading(objData.entity)) or 0.0,
                rotation = rot,
                packageName = pkg,
                hasDualDoors = objData.hasDualDoors == true,
                interiorModel = objData.interiorModel
            })
        end
    end
    return list
end

local function OpenNUIMenu()
    SendNUIMessage({
        action = 'open',
        objects = objectList,
        spawnedObjectsForList = GetSerializableSpawnedObjects(),
        userSettings = currentUserSettings,
        pathConfig = Config.PathCreator
    })
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

-- Track currently highlighted object for selection
local highlightedObjectIndex = nil
local activeWallHighlightEntity = nil -- Track wall highlight for placement snapping

function ClearAllHighlights()
    if highlightedObjectIndex then
        UnhighlightObject(highlightedObjectIndex)
        highlightedObjectIndex = nil
    end
    -- Also clear any wall Snap highlights
    if activeWallHighlightEntity then
        if DoesEntityExist(activeWallHighlightEntity) then
            ResetEntityAlpha(activeWallHighlightEntity)
            SetEntityDrawOutline(activeWallHighlightEntity, false)
        end
        activeWallHighlightEntity = nil
    end
end

RegisterNUICallback('selectObject', function(data, cb)
    if editingObjectData then
        SendNUIMessage({action = 'showError', message = "Finish keyboard editing first (Enter/Esc)."})
        cb({status = 'error'}); return
    end
    
    -- Handle object selection for highlighting (data.id or data.index)
    if data.id or data.index then
        local obj, index = GetSpawnedObjectByIdOrIndex(data.id, tonumber(data.index))
        if obj and index then
            -- Clear previous highlight
            ClearAllHighlights()
            
            -- Highlight new object
            if HighlightObject(index) then
                highlightedObjectIndex = index
                DebugLog("GENERAL", "Selected object " .. tostring(obj.id or index) .. " (" .. (obj.model or "unknown") .. ") for highlighting")
                cb({status = 'ok', message = 'Object selected and highlighted'})
            else
                cb({status = 'error', message = 'Failed to highlight object'})
            end
        else
            cb({status = 'error', message = 'Invalid object identifier'})
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
    ClearAllHighlights()
    DebugLog("MENU", "🔍 ESC PRESSED - IsNuiFocused: " .. tostring(IsNuiFocused()) .. " isMenuOpen: " .. tostring(isMenuOpen))
    if IsNuiFocused() then
        DebugLog("MENU", "❌ ESC: Closing menu via ESC key")
        SetNuiFocus(false, false)
        SendNUIMessage({action = 'close'})
        isMenuOpen = false  -- Reset menu state
        isMenuLoading = false  -- Reset loading state
        -- Clear highlights when closing menu
        ClearAllHighlights()
        if placing then
            CancelPlacing(false)
        end
        DebugLog("MENU", "Menu closed via Escape - isMenuOpen:" .. tostring(isMenuOpen) .. " isMenuLoading:" .. tostring(isMenuLoading))
    elseif editingObjectData then
        CancelKeyboardEdit(true)
    end
    cb('ok')
end)

RegisterNUICallback('cancelPlacement', function(_, cb)
    CancelPlacing(false)
    cb('ok')
end)

RegisterNUICallback('deleteObject', function(data, cb)
    local obj, index = GetSpawnedObjectByIdOrIndex(data.id, tonumber(data.index))
    if obj and index then
        -- Clear highlight if this is the highlighted object
        if highlightedObjectIndex == index then
            ClearAllHighlights()
        end
        DeleteSpawnedObject(index, obj.id)
        cb({status = 'ok'})
    else
        cb({status = 'error', message = 'Invalid identifier for deletion.'})
    end
end)

RegisterNUICallback('deleteObjects', function(data, cb)
    local indices = data.indices
    local ids = data.ids
    
    local validIndices = {}
    local seenIndices = {}
    
    -- If persistent IDs are provided, resolve indexes by ID first
    if type(ids) == 'table' and #ids > 0 then
        for _, id in ipairs(ids) do
            if type(id) == 'string' and id ~= '' then
                local _, idx = GetObjectById(id)
                if idx and not seenIndices[idx] then
                    seenIndices[idx] = true
                    table.insert(validIndices, idx)
                end
            end
        end
    end
    
    -- Fallback/supplement with provided indices
    if type(indices) == 'table' and #indices > 0 then
        for _, idx in ipairs(indices) do
            local n = tonumber(idx)
            if n and spawnedObjects[n] and not seenIndices[n] then
                seenIndices[n] = true
                table.insert(validIndices, n)
            end
        end
    end

    if #validIndices == 0 then
        cb({status = 'error', message = 'No valid objects for deletion.'})
        return
    end

    -- Sort valid indices in descending order to avoid index shifting problems
    table.sort(validIndices, function(a, b) return a > b end)

    local idsToDelete = {}
    for _, index in ipairs(validIndices) do
        local objData = spawnedObjects[index]
        if objData and objData.id then
            table.insert(idsToDelete, objData.id)
        end
    end

    local deletedCount = 0
    for _, index in ipairs(validIndices) do
        local objData = spawnedObjects[index]
        if objData then
            if highlightedObjectIndex == index then
                ClearAllHighlights()
            end

            -- Clean up targets and entities
            if objData.model == "bazq-sur_kapi" or objData.model == "bazq-sur_mkapi" then
                objData.index = index
                CleanupAssociatedDoors(objData)
            end

            if objData.entity and DoesEntityExist(objData.entity) then
                UnregisterTargetForEntity(objData.entity)
                SafeDeleteEntity(objData.entity)
            end

            if objData.interiorEntity then
                if type(objData.interiorEntity) == "table" then
                    for _, doorEntity in ipairs(objData.interiorEntity) do
                        if DoesEntityExist(doorEntity) then
                            SafeDeleteEntity(doorEntity)
                        end
                    end
                elseif DoesEntityExist(objData.interiorEntity) then
                    SafeDeleteEntity(objData.interiorEntity)
                end
            end

            table.remove(spawnedObjects, index)
            deletedCount = deletedCount + 1
        end
    end

    if #idsToDelete > 0 then
        TriggerServerEvent("bazq-objectplace:deleteObjects", { ids = idsToDelete })
        SendNUIMessage({action = "updateSpawnedList", data = GetSerializableSpawnedObjects()})
    end

    cb({status = 'ok', deletedCount = deletedCount})
end)

RegisterNUICallback('duplicateObject', function(data, cb)
    if editingObjectData then
        SendNUIMessage({action = 'showError', message = "Finish keyboard editing first (Enter/Esc)."})
        cb({status = 'error'}); return
    end
    local objData, index = GetSpawnedObjectByIdOrIndex(data.id, tonumber(data.index))
    if objData and index then
        if objData.model and objData.entity and DoesEntityExist(objData.entity) then
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
                    
                    local rot = GetEntityRotation(newEntity, 2)
                    local newIndex = #spawnedObjects + 1
                    local reqId = GenerateRequestId("dup")
                    local newRecord = {
                        id = nil, -- Must be nil so server assigns a fresh authoritative ID
                        entity = newEntity,
                        model = objData.model,
                        coords = GetEntityCoords(newEntity),
                        heading = GetEntityHeading(newEntity),
                        rotation = {x = rot.x, y = rot.y, z = rot.z},
                        playerName = playerName,
                        timestamp = timestamp,
                        originalIndex = newIndex
                    }
                    spawnedObjects[newIndex] = newRecord
                    pendingPlacedEntities[reqId] = newRecord
                    
                    -- Register target for the new entity
                    RegisterTargetForEntity(newEntity)
                    
                    -- Send server-authoritative placeObject request
                    TriggerServerEvent("bazq-objectplace:placeObject", {
                        model = objData.model,
                        coords = { x = newRecord.coords.x, y = newRecord.coords.y, z = newRecord.coords.z },
                        heading = newRecord.heading,
                        rotation = newRecord.rotation,
                        playerName = playerName,
                        timestamp = timestamp,
                        requestId = reqId
                    })
                    
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
                        id = nil,
                        entity = newEntity, 
                        originalIndex = newIndex, 
                        model = objData.model,
                        originalCoords = GetEntityCoords(newEntity), 
                        originalHeading = GetEntityHeading(newEntity),
                        timestamp = timestamp,
                        playerName = playerName
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
        cb({status = 'error', message = 'Invalid identifier for duplication.'})
    end
end)

-- Add backwards compatibility for editObject callback
RegisterNUICallback('editObject', function(data, cb)
    -- Redirect to editSpawnedObject for backwards compatibility
    if editingObjectData then
        SendNUIMessage({action = 'showError', message = "Finish keyboard editing first (Enter/Esc)."})
        cb({status = 'error'}); return
    end
    local objData, index = GetSpawnedObjectByIdOrIndex(data.id, tonumber(data.index))
    if objData and index then
        if objData and objData.entity and DoesEntityExist(objData.entity) then
            -- Clear any selection highlighting before starting edit
            ClearAllHighlights()
            
            editingObjectData = {
                id = objData.id,
                entity = objData.entity, originalIndex = index, model = objData.model,
                originalCoords = GetEntityCoords(objData.entity), originalHeading = GetEntityHeading(objData.entity),
                timestamp = objData.timestamp, playerName = objData.playerName
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
        cb({status = 'error', message = 'Invalid identifier for editing.'}) 
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
        if Config.TestZone and Config.TestZone.enabled and IsPlayerInTestZone() then
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
    SetNuiFocusKeepInput(false)
    SendNUIMessage({action = 'close'})
    SendNUIMessage({action = 'editingModeUpdate', editingActive = false})
    isMenuOpen = false  -- Reset menu state
    isMenuLoading = false  -- Reset loading state
    -- Clear highlights when closing menu
    ClearAllHighlights()
    if placing then
        CancelPlacing(false)
    end
    if editingObjectData then
        CancelKeyboardEdit(false)
    end
    if exports['bazq-os'] then
        pcall(function() exports['bazq-os']:StopGizmo() end)
    end
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
        if Client.freezeTime or Client.freezeWeather then
            if Client.freezeTime then
                NetworkOverrideClockTime(12, 0, 0)
            end
            if Client.freezeWeather then
                SetWeatherTypeNowPersist('extrasunny')
            end
            Citizen.Wait(1000) -- Check/sync every second when active
        else
            Citizen.Wait(5000) -- Sleep for 5 seconds when not active
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
    local objData, index = GetSpawnedObjectByIdOrIndex(data.id, tonumber(data.index))
    if objData and index then
        if objData and objData.entity and DoesEntityExist(objData.entity) then
            -- Clear any selection highlighting before starting edit
            ClearAllHighlights()
            
            editingObjectData = {
                id = objData.id,
                entity = objData.entity, originalIndex = index, model = objData.model,
                originalCoords = GetEntityCoords(objData.entity), originalHeading = GetEntityHeading(objData.entity),
                timestamp = objData.timestamp, playerName = objData.playerName
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
    else cb({status = 'error', message = 'Invalid identifier for editing.'}) end
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
        -- Direct server admin check - no complex client-side logic
        DebugLog("MENU", "ToggleMenu called - requesting admin permission")
        isMenuLoading = true
        TriggerServerEvent("bazq-objectplace:checkAdminPermission")
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
    if Config.TestZone then
        local enabled = Config.TestZone.enabled
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
            args = { "[CONFIG-DEBUG]", "No Config.TestZone found!" }
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

ToggleFreecam = function()
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
-- Register selection clear command and bind H key
RegisterCommand('bazq_clear_selection', function()
    if not isMenuOpen and not placing and not editingObjectData and not pathDrawing then
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
end, false)
RegisterKeyMapping('bazq_clear_selection', 'Clear Object Selection', 'keyboard', 'H')

function DrawTxt(text, x,y,s,r,g,b,a,fnt,jst,shd,otl) SetTextFont(fnt or 0);SetTextProportional(0);SetTextScale(s,s);SetTextColour(r,g,b,a);if shd then SetTextDropShadow(2,2,0,0,0)end;if otl then SetTextOutline()end;if jst=="CENTER"then SetTextCentre(true)elseif jst=="RIGHT"then SetTextWrap(0.0,x);SetTextRightJustify(true)end;SetTextEntry("STRING");AddTextComponentString(text);DrawText(x,y) end

function StartPlacingObject(modelName)
    if placing or editingObjectData then CancelPlacing(); if editingObjectData then CancelKeyboardEdit(false) end end
    -- Clear any selection highlighting when starting placement
    ClearAllHighlights()
    placing = true; selectedObject = modelName; manualHeightAdjusted = false
    wallSelectionIndex = 1 -- Reset wall cycling index
    hasShownWallHelp = false -- Reset help flag
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
    
    -- Set green color tint (Commented out to prevent rendering/invisibility bugs)
    -- SetEntityRenderScorched(objectEntity, true)
    -- SetEntityDrawOutline(objectEntity, true)
    -- SetEntityDrawOutlineColor(104, 182, 91, 255) -- Green outline
    
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
                local cH,hC=RaycastFromCamera()
                -- Use camera raycast hit as the stable reference point for wall sorting
                local nearbyWalls = FindAllNearbyWalls(cH and hC or GetEntityCoords(objectEntity), 3.0)
                -- DebugLog("PLACEMENT", "Found " .. #nearbyWalls .. " nearby walls")
                
                -- Check for TAB key to cycle through walls
                if IsDisabledControlJustReleased(0, 37) then -- TAB key
                    DebugLog("PLACEMENT", "TAB pressed! Cycling walls. Current: " .. wallSelectionIndex .. ", Total: " .. #nearbyWalls)
                    wallSelectionIndex = wallSelectionIndex + 1
                    -- Visual feedback for cycling
                    SendNUIMessage({action = 'objectSpawned', message = "Cycled to next wall"})
                end
                
                if #nearbyWalls > 0 then
                    -- Wrap index around if it exceeds count
                    if wallSelectionIndex > #nearbyWalls then wallSelectionIndex = 1 end
                    
                    local selectedWall = nearbyWalls[wallSelectionIndex]
                    local nearbyWallEntity = selectedWall.entity
                    
                    -- Highlight the selected wall (Gold/Orange for target)
                    local nearbyWallEntity = selectedWall.entity
                    
                    -- Only update if changed
                    if activeWallHighlightEntity ~= nearbyWallEntity then
                        -- Clear previous wall highlight if different
                        if activeWallHighlightEntity and DoesEntityExist(activeWallHighlightEntity) then
                            ResetEntityAlpha(activeWallHighlightEntity)
                            SetEntityDrawOutline(activeWallHighlightEntity, false)
                        end
                        
                        -- Set new highlight
                        activeWallHighlightEntity = nearbyWallEntity
                        SetEntityAlpha(activeWallHighlightEntity, 200, false)
                        SetEntityDrawOutline(activeWallHighlightEntity, true)
                        SetEntityDrawOutlineColor(255, 165, 0, 255) -- Orange/Gold outline for target
                    end
                    
                    -- Snap to wall position and rotation
                    local wallCoords = GetEntityCoords(nearbyWallEntity)
                    local wallHeading = GetEntityHeading(nearbyWallEntity)
                    SetEntityCoords(objectEntity, wallCoords.x, wallCoords.y, wallCoords.z)
                    SetEntityHeading(objectEntity, wallHeading)
                    
                    -- Brighter green when attached to wall
                    SetEntityAlpha(objectEntity, 220, false)
                    SetEntityDrawOutlineColor(104, 255, 91, 255) -- Brighter green outline
                    
                    -- Update help text to include TAB
                    if not hasShownWallHelp then
                        SendNUIMessage({action = 'editingModeUpdate', message = "LMB: Place | RMB/ESC: Cancel | TAB: Cycle Wall ("..wallSelectionIndex.."/"..#nearbyWalls..") | Q/E: Rotate | Mouse Wheel: Height", editingActive = true})
                        hasShownWallHelp = true
                    end
                else
                    -- No wall nearby, make it red and transparent
                    wallSelectionIndex = 1 -- Reset index
                    
                    -- Clear any stuck wall highlight
                    if activeWallHighlightEntity then
                        if DoesEntityExist(activeWallHighlightEntity) then
                            ResetEntityAlpha(activeWallHighlightEntity)
                            SetEntityDrawOutline(activeWallHighlightEntity, false)
                        end
                        activeWallHighlightEntity = nil
                    end
                    
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

function CancelPlacing(shouldReopenMenu)
    if shouldReopenMenu == nil then shouldReopenMenu = true end

    local tempEntityExists = objectEntity and DoesEntityExist(objectEntity)

    placing=false
    DebugLog("PLACEMENT", "PLACEMENT CANCELLED - placing set to FALSE, re-enabling combat")

    -- Re-enable combat capabilities
    local playerPed = PlayerPedId()
    SetPedCanSwitchWeapon(playerPed, true)   -- Re-enable weapon switching
    DisablePlayerFiring(PlayerId(), false)  -- Re-enable firing
    SetPlayerCanDoDriveBy(PlayerId(), true)  -- Re-enable drive-by shooting
    SetEntityProofs(playerPed, false, false, false, false, false, false, false, false)  -- Remove bullet proof
    if tempEntityExists then
        -- Clean up visual effects before deleting
        ResetEntityAlpha(objectEntity)
        SetEntityDrawOutline(objectEntity, false)
        SetEntityRenderScorched(objectEntity, false)
        ClearAllHighlights() -- Fix: Ensure wall highlights are cleared on cancel
        DeleteEntity(objectEntity)
    end

    objectEntity=nil;selectedObject=nil
    manualHeightAdjusted = false
    SendNUIMessage({action = 'editingModeUpdate', editingActive = false})
    if exports['bazq-os'] then
        pcall(function() exports['bazq-os']:StopGizmo() end)
    end

    -- Always reset UI state so controls don't remain blocked
    SetNuiFocus(false, false)
    isMenuOpen = false
    isMenuLoading = false

    if not shouldReopenMenu then
        SendNUIMessage({action = 'close'})
        return
    end

    -- If there was no placement session active, do not reopen the menu
    if not tempEntityExists and not editingObjectData then
        return
    end

    -- Auto-return to menu after placement cancellation
    Citizen.SetTimeout(300, function()
        if not placing and not editingObjectData then
            OpenNUIMenu()
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
            ClearAllHighlights() -- Fix: Ensure wall highlights are cleared
        else
            DebugLog("GENERAL", "Warn: No net control.")
            SetEntityDynamic(objectEntity,false)
            SetEntityCollision(objectEntity,true,true)
            -- Remove all visual effects
            ResetEntityAlpha(objectEntity)
            SetEntityDrawOutline(objectEntity, false)
            SetEntityRenderScorched(objectEntity, false)
            ClearAllHighlights() -- Fix: Ensure wall highlights are cleared
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
        
        local rot = GetEntityRotation(objectEntity, 2)
        -- Store the main object
        local objectData = {
            entity=objectEntity,
            model=selectedObject,
            coords=mainCoords,
            heading=mainHeading,
            rotation={x = rot.x, y = rot.y, z = rot.z},
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
        RegisterTargetForEntity(objectData.entity)
        local reqId = GenerateRequestId("place")
        pendingPlacedEntities[reqId] = objectData
        TriggerServerEvent("bazq-objectplace:placeObject", {
            model = objectData.model,
            coords = { x = objectData.coords.x, y = objectData.coords.y, z = objectData.coords.z },
            heading = objectData.heading,
            rotation = objectData.rotation,
            interiorModel = objectData.interiorModel,
            hasDualDoors = objectData.hasDualDoors,
            playerName = objectData.playerName,
            timestamp = objectData.timestamp,
            requestId = reqId
        })
        SendNUIMessage({action="updateSpawnedList", data=GetSerializableSpawnedObjects()})
        
        -- Stop gizmo immediately when placement completes
        if exports['bazq-os'] then
            pcall(function() exports['bazq-os']:StopGizmo() end)
        end
        
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
                    OpenNUIMenu()
                end
            end
        end)
    end
end

function KeyboardEditLoop()
    if not editingObjectData or not editingObjectData.entity or not DoesEntityExist(editingObjectData.entity) then editingObjectData=nil; return end
    local ent = editingObjectData.entity
    SetEntityCollision(ent, false, false)
    
    -- Freeze player ped completely during editing
    local playerPed = PlayerPedId()
    FreezeEntityPosition(playerPed, true)

    -- Start 3D Gizmo
    if exports['bazq-os'] then
        pcall(function() exports['bazq-os']:StartGizmo(ent, "bazq_edit_" .. tostring(ent)) end)
    end

    -- Apply green glowing wireframe effect for editing
    SetEntityAlpha(ent, 180, false)
    SetEntityDrawOutline(ent, true)
    SetEntityDrawOutlineColor(104, 182, 91, 255) -- Green outline
    SetEntityRenderScorched(ent, true)

    local nudgeSpeed = 0.02
    local currentRotation = GetEntityHeading(ent)
    local rotationSnapMode = false -- false = 1° rotation, true = 5° rotation

    SendNUIMessage({
        action = 'editingModeUpdate',
        message = "EDIT MODE: WASD:Move | Alt/F:Height | Q/E:Rotate (1°) | G:Snap Toggle | X:Toggle 5° Mode | R:Reset Rotation | LMB/ENTER:Save | RMB/ESC:Cancel | Rotation: " .. math.floor(currentRotation) .. "°",
        editingActive = true
    })

    while editingObjectData and editingObjectData.entity == ent and DoesEntityExist(ent) do
        Citizen.Wait(0)
        
        -- Disable cover system during editing so Q key works for rotation
        DisableControlAction(0, 44, true) -- INPUT_COVER (Q key)
        DisableControlAction(0, 24, true) -- INPUT_ATTACK
        DisableControlAction(0, 25, true) -- INPUT_AIM

        local currentCoords, currentHeading = GetEntityCoords(ent), GetEntityHeading(ent)
        local rightVec, fwdVec, upVec = GetEntityMatrix(ent)
        currentRotation = currentHeading

        -- Draw 3D Gizmo & Spatial Grid
        DrawAdvancedXYZArrows(ent, currentCoords, rightVec, fwdVec, upVec)

        -- Movement controls
        if IsDisabledControlPressed(0, 32) then SetEntityCoords(ent, currentCoords + fwdVec * nudgeSpeed, false, false, false, true) end -- W
        if IsDisabledControlPressed(0, 33) then SetEntityCoords(ent, currentCoords - fwdVec * nudgeSpeed, false, false, false, true) end -- S
        if IsDisabledControlPressed(0, 30) then SetEntityCoords(ent, currentCoords - rightVec * nudgeSpeed, false, false, false, true) end -- A
        if IsDisabledControlPressed(0, 31) then SetEntityCoords(ent, currentCoords + rightVec * nudgeSpeed, false, false, false, true) end -- D
        
        -- Height controls (Alt/F)
        if IsDisabledControlPressed(0, 19) then SetEntityCoords(ent, currentCoords + upVec * nudgeSpeed, false, false, false, true) end    -- Alt key - Up
        if IsDisabledControlPressed(0, 23) then SetEntityCoords(ent, currentCoords - upVec * nudgeSpeed, false, false, false, true) end    -- F key - Down

        -- Toggle rotation snap mode with X key
        if IsDisabledControlJustReleased(0, 73) then -- X key
            rotationSnapMode = not rotationSnapMode
            local modeText = rotationSnapMode and "5°" or "1°"
            SendNUIMessage({action = 'editingModeUpdate', message = "EDIT MODE: WASD:Move | Alt/F:Height | Q/E:Rotate (" .. modeText .. ") | G:Snap Toggle | X:Toggle 5° Mode | R:Reset Rotation | LMB/ENTER:Save | RMB/ESC:Cancel | Rotation: " .. math.floor(currentRotation) .. "°", editingActive = true})
        end
        
        -- Rotation controls (Q/E)
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
            SendNUIMessage({action = 'editingModeUpdate', message = "EDIT MODE: WASD:Move | Alt/F:Height | Q/E:Rotate (" .. modeText .. ") | G:Snap Toggle | X:Toggle 5° Mode | R:Reset Rotation | LMB/ENTER:Save | RMB/ESC:Cancel | Rotation: 0°", editingActive = true})
        end

        -- Snap to ground toggle with G key
        if IsControlJustReleased(0, 47) then -- G key
            currentPlacementOptions.snapToGround = not currentPlacementOptions.snapToGround
            local status = currentPlacementOptions.snapToGround and "ON" or "OFF"
            SendNUIMessage({action = 'objectSpawned', message = "Ground Snap: " .. status})
            if currentPlacementOptions.snapToGround then
                AlignObjectToGround(ent)
            end
        end

        -- Save with LMB or ENTER
        if IsDisabledControlJustReleased(0, 24) or IsDisabledControlJustReleased(0, 191) or IsControlJustReleased(0, 191) or IsDisabledControlJustReleased(0, 201) or IsControlJustReleased(0, 201) then
            ApplyKeyboardEdit()
            break
        end

        -- Cancel with RMB or ESC
        if IsDisabledControlJustReleased(0, 25) or IsDisabledControlJustReleased(0, 322) or IsControlJustReleased(0, 322) or IsDisabledControlJustReleased(0, 200) or IsControlJustReleased(0, 200) then
            CancelKeyboardEdit(true)
            break
        end
    end

    -- Stop interactive gizmo when loop finishes
    if exports['bazq-os'] then
        pcall(function() exports['bazq-os']:StopGizmo() end)
    end

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    FreezeEntityPosition(PlayerPedId(), false) -- Unfreeze player ped
    SendNUIMessage({action = 'editingModeUpdate', editingActive = false})

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
        
        -- Identity resolution: match by persistent ID first, falling back to originalIndex/fuzzy match
        local targetIndex = nil
        local objData = nil
        
        if editingObjectData.id and editingObjectData.id ~= "" then
            objData, targetIndex = GetObjectById(editingObjectData.id)
        end
        
        if not objData then
            targetIndex = editingObjectData.originalIndex
            objData = spawnedObjects[targetIndex]
            
            if not objData or (editingObjectData.id and objData.id ~= editingObjectData.id) or objData.timestamp ~= editingObjectData.timestamp or objData.playerName ~= editingObjectData.playerName then
                for i, obj in ipairs(spawnedObjects) do
                    if (editingObjectData.id and obj.id == editingObjectData.id) or (obj.timestamp == editingObjectData.timestamp and obj.playerName == editingObjectData.playerName and obj.model == editingObjectData.model) then
                        targetIndex = i
                        objData = obj
                        break
                    end
                end
            end
        end

        if not objData then
            SendNUIMessage({action = 'showError', message = "Object was displaced or deleted from the server while editing! Data desync."})
            CancelKeyboardEdit(true)
            return
        end
        
        -- Update main object data
        spawnedObjects[targetIndex].coords = newCoords
        spawnedObjects[targetIndex].heading = newHeading
        local rot = GetEntityRotation(ent, 2)
        spawnedObjects[targetIndex].rotation = {x = rot.x, y = rot.y, z = rot.z}
        
        -- Update interior entity if it exists
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
                elseif objData.interiorModel == "bazq-surfence" then
                    -- Fix: Removed +5.0 offset for Edit. Matches Load logic.
                    SetEntityCoords(objData.interiorEntity, newCoords.x, newCoords.y, newCoords.z, false, false, false, false)
                    SetEntityHeading(objData.interiorEntity, newHeading)
                else
                    -- For other interior entities (like tower interiors), use same position
                    SetEntityCoords(objData.interiorEntity, newCoords.x, newCoords.y, newCoords.z, false, false, false, false)
                end
                if objData.interiorModel ~= "bazq-surfence" then -- Already set above
                    SetEntityHeading(objData.interiorEntity, newHeading)
                end
            end
            -- print("[OP] Updated interior entity position for " .. editingObjectData.model)
        elseif objData.hasCollision then
            -- For collision, request at new position
            RequestCollisionAtCoord(newCoords.x, newCoords.y, newCoords.z)
            -- print("[OP] Updated collision position for " .. editingObjectData.model)
        end
        
        if objData and objData.id then
            TriggerServerEvent("bazq-objectplace:updateObject", {
                id = objData.id,
                changes = {
                    coords = { x = newCoords.x, y = newCoords.y, z = newCoords.z },
                    heading = newHeading,
                    rotation = { x = rot.x, y = rot.y, z = rot.z }
                }
            })
        end
        SendNUIMessage({action = "updateSpawnedList", data = GetSerializableSpawnedObjects()})
        SendNUIMessage({action = 'editingModeUpdate', message = "Object position updated.", isError = false, editingActive = false})
        -- print("[OP] Edit saved: " .. editingObjectData.model)
        
        -- Auto-return to menu after editing
        Citizen.SetTimeout(300, function()
            if not placing and not editingObjectData then
                OpenNUIMenu()
            end
        end)
    end
    if exports['bazq-os'] then
        pcall(function() exports['bazq-os']:StopGizmo() end)
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
                    elseif objData.interiorModel == "bazq-surfence" then
                        -- Fix: Removed +5.0 offset for Cancel Edit. Matches Load logic.
                        SetEntityCoords(objData.interiorEntity, editingObjectData.originalCoords.x, editingObjectData.originalCoords.y, editingObjectData.originalCoords.z, false, false, false, false)
                    else
                        -- For other interior entities (like tower interiors), use same position
                        SetEntityCoords(objData.interiorEntity, editingObjectData.originalCoords.x, editingObjectData.originalCoords.y, editingObjectData.originalCoords.z, false, false, false, false)
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
    if exports['bazq-os'] then
        pcall(function() exports['bazq-os']:StopGizmo() end)
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
    local deletedDoorIds = {}
    for _, doorIndex in ipairs(doorsToDelete) do
        DebugDeletion("Deleting associated door at index: " .. doorIndex)
        local doorData = spawnedObjects[doorIndex]
        if doorData and doorData.id then
            table.insert(deletedDoorIds, doorData.id)
        end
        
        if doorData and doorData.entity and DoesEntityExist(doorData.entity) then
            UnregisterTargetForEntity(doorData.entity)
            SafeDeleteEntity(doorData.entity)
            DebugDeletion("Deleted door entity: " .. (doorData.model or "unknown"))
        end
        
        -- Delete interior entity if exists
        if doorData.interiorEntity then
            if type(doorData.interiorEntity) == "table" then
                for i, doorEntity in ipairs(doorData.interiorEntity) do
                    if DoesEntityExist(doorEntity) then
                        SafeDeleteEntity(doorEntity)
                        DebugDeletion("Deleted door interior entity " .. i)
                    end
                end
            elseif DoesEntityExist(doorData.interiorEntity) then
                SafeDeleteEntity(doorData.interiorEntity)
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
        -- Update server via granular batch delete
        if #deletedDoorIds > 0 then
            TriggerServerEvent("bazq-objectplace:deleteObjects", { ids = deletedDoorIds })
        end
        SendNUIMessage({action="updateSpawnedList", data=GetSerializableSpawnedObjects()})
    else
        DebugDeletion("No associated doors found to delete")
    end
end

function DeleteSpawnedObject(identifier, fallbackId)
    local index = nil
    local objData = nil
    
    if type(identifier) == "string" and identifier ~= "" then
        objData, index = GetObjectById(identifier)
    elseif fallbackId and type(fallbackId) == "string" and fallbackId ~= "" then
        objData, index = GetObjectById(fallbackId)
    end
    
    if not objData and type(identifier) == "number" then
        index = identifier
        objData = spawnedObjects[index]
    end

    if objData and index then
        DebugDeletion("Deleting object " .. tostring(objData.id or "no-id") .. " at index " .. index .. ", model: " .. (objData.model or "unknown"))
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
            UnregisterTargetForEntity(objData.entity)
            SafeDeleteEntity(objData.entity)
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
                        SafeDeleteEntity(doorEntity)
                        DebugDeletion("Deleted door entity " .. i)
                    else
                        DebugDeletion("WARNING: Door entity " .. i .. " does not exist!")
                    end
                end
                DebugLog("DELETION", "Deleted dual door entities for " .. (objData.model or "unknown"))
            elseif DoesEntityExist(objData.interiorEntity) then
                SafeDeleteEntity(objData.interiorEntity)
                DebugLog("DELETION", "Deleted interior entity for " .. (objData.model or "unknown"))
            else
                DebugDeletion("WARNING: Interior entity does not exist for " .. (objData.model or "unknown"))
            end
        else
            DebugDeletion("No interior entity to delete")
        end
        
        -- Note: Collision is automatically managed by the game
        table.remove(spawnedObjects,index)
        if objData and objData.id then
            TriggerServerEvent("bazq-objectplace:deleteObject", { id = objData.id })
        end
        SendNUIMessage({action="updateSpawnedList",data=GetSerializableSpawnedObjects()})
        DebugDeletion("Deletion complete")
    else
        DebugDeletion("ERROR: No object data found for identifier " .. tostring(identifier or fallbackId))
    end
end

function AlignObjectToGround(obj)local p=GetEntityCoords(obj);local _,gZ=GetGroundZFor_3dCoord(p.x,p.y,p.z+2.0,false);if gZ then SetEntityCoords(obj,p.x,p.y,gZ,0,0,0,1)end end
function RaycastFromCamera()
    local cC, cR
    if IsFreecamActive() then
        cC = GetFreecamPosition()
        cR = GetFreecamRotation()
    else
        cC = GetGameplayCamCoord()
        cR = GetGameplayCamRot(2)
    end
    local d = RotationToDirection(cR)
    local distance = IsFreecamActive() and 2000.0 or 25.0
    local dest = cC + d * distance
    local r = StartShapeTestRay(cC.x, cC.y, cC.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 7)
    local _, h, hC = GetShapeTestResult(r)
    return h == 1, hC 
end

function RaycastFromCameraWithEntity()
    local cC, cR
    if IsFreecamActive() then
        cC = GetFreecamPosition()
        cR = GetFreecamRotation()
    else
        cC = GetGameplayCamCoord()
        cR = GetGameplayCamRot(2)
    end
    local d = RotationToDirection(cR)
    local distance = IsFreecamActive() and 2000.0 or 25.0
    local dest = cC + d * distance
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

-- Interactive Native DrawGizmo (0xEB2EDCA2) Entegrasyonu
RegisterNetEvent('bazq-os:client:onGizmoTransformUpdate', function(entity, x, y, z, heading)
    if editingObjectData and editingObjectData.entity == entity then
        SendNUIMessage({
            action = 'editingModeUpdate',
            message = string.format("EDIT MODE: Gizmo active | Pos: %.2f, %.2f, %.2f | Rot: %d° | LMB:Save | RMB:Cancel", x, y, z, math.floor(heading)),
            editingActive = true
        })
    end
end)

-- Advanced XYZ arrows & native gizmo for edit/placement mode
function DrawAdvancedXYZArrows(entity, coords, rightVec, fwdVec, upVec)
    if entity and DoesEntityExist(entity) then
        pcall(function()
            if exports['bazq-os'] and not exports['bazq-os']:IsGizmoActive() then
                exports['bazq-os']:StartGizmo(entity, "bazq_gizmo_" .. tostring(entity))
            end
        end)
    end

    -- Subtle grid around object for spatial reference
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
    -- DEPRECATED in Phase 3: Client-authoritative full-array replacement is permanently disabled.
    DebugLog("SAVE", "DEPRECATION WARNING: SaveObjectsToServer() was called but is disabled in Phase 3. Mutations must use granular server events.")
end
-- Commands removed - only F7 key access for admins

-- Helper to spawn and track a persistent object descriptor
local function SpawnPersistentObject(objSD)
    if not objSD or not objSD.model or not objSD.coords or objSD.coords.x == nil then
        DebugLog("LOADING", "Skipping invalid object data in SpawnPersistentObject")
        return nil
    end
    
    -- Check if already tracked by persistent ID
    if objSD.id and objSD.id ~= "" then
        for _, existing in ipairs(spawnedObjects) do
            if existing.id == objSD.id then
                return existing
            end
        end
    end
    
    local mH = GetHashKey(objSD.model)
    local ent = 0
    if SAFE_LOAD_MODE then
        local existing = GetClosestObjectOfType(objSD.coords.x, objSD.coords.y, objSD.coords.z, 0.6, mH, false, true, true)
        if existing ~= 0 and DoesEntityExist(existing) then
            DebugLog("LOADING", "SafeLoad: Detected existing entity for " .. objSD.model .. ", skipping spawn")
            ent = existing
        end
    end
    
    if ent == 0 then
        RequestModel(mH)
        local sT = GetGameTimer()
        while not HasModelLoaded(mH) do
            if GetGameTimer() - sT > 5000 then
                DebugLog("LOADING", "Timeout load " .. tostring(objSD.model))
                break
            end
            Citizen.Wait(50)
        end
        if HasModelLoaded(mH) then
            ent = CreateObject(mH, objSD.coords.x, objSD.coords.y, objSD.coords.z, 0, 0, 0)
        end
    end
    
    if ent ~= 0 and DoesEntityExist(ent) then
        SetEntityAsMissionEntity(ent, 1, 1)
        SetEntityDynamic(ent, 0)
        
        SetEntityCollision(ent, false, false)
        SetEntityCoords(ent, objSD.coords.x, objSD.coords.y, objSD.coords.z, false, false, false, false)
        if objSD.rotation then
            SetEntityRotation(ent, objSD.rotation.x, objSD.rotation.y, objSD.rotation.z, 2, true)
        else
            SetEntityHeading(ent, objSD.heading or 0.0)
        end
        FreezeEntityPosition(ent, true)
        if objSD.hasCollision ~= false then
            SetEntityCollision(ent, true, true)
        end
        SetEntityCoords(ent, objSD.coords.x, objSD.coords.y, objSD.coords.z, false, false, false, false)
        
        local lockedCoords = vector3(objSD.coords.x, objSD.coords.y, objSD.coords.z)
        local objectData = {
            id = objSD.id,
            entity = ent,
            model = objSD.model,
            coords = lockedCoords,
            heading = objSD.heading,
            rotation = objSD.rotation,
            displayName = objSD.displayName or objSD.name,
            timestamp = objSD.timestamp or "",
            playerName = objSD.playerName or "Unknown"
        }
        
        if objSD.interiorModel then
            if objSD.interiorModel == "bazq-kule_int-col" then
                RequestCollisionAtCoord(objSD.coords.x, objSD.coords.y, objSD.coords.z)
                objectData.interiorModel = objSD.interiorModel
                objectData.hasCollision = true
            else
                local interiorHash = GetHashKey(objSD.interiorModel)
                RequestModel(interiorHash)
                local startTime = GetGameTimer()
                while not HasModelLoaded(interiorHash) do
                    if GetGameTimer() - startTime > 3000 then break end
                    Citizen.Wait(50)
                end
                local zCoord = objSD.coords.z
                if objSD.interiorModel == "bazq-surfence" then zCoord = zCoord + 5.0 end
                
                local spawnCoords = vector3(objSD.coords.x, objSD.coords.y, zCoord)
                local spawnHeading = objSD.heading or 0.0
                
                if objSD.interiorModel == "bazq-wall2_signpole" then
                    local headingRad = math.rad(spawnHeading)
                    local forwardX = -math.sin(headingRad)
                    local forwardY = math.cos(headingRad)
                    spawnCoords = vector3(
                        objSD.coords.x + (0.03 * forwardX),
                        objSD.coords.y + (0.03 * forwardY),
                        objSD.coords.z
                    )
                end
                
                local interiorEnt = GetClosestObjectOfType(spawnCoords.x, spawnCoords.y, spawnCoords.z, 0.6, interiorHash, false, true, true)
                if interiorEnt == 0 then
                    interiorEnt = CreateObject(interiorHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0, 0, 0)
                end
                if DoesEntityExist(interiorEnt) then
                    SetEntityHeading(interiorEnt, spawnHeading)
                    SetEntityAsMissionEntity(interiorEnt, 1, 1)
                    SetEntityDynamic(interiorEnt, 0)
                    SetEntityCollision(interiorEnt, false, false)
                    SetEntityCoords(interiorEnt, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, false)
                    FreezeEntityPosition(interiorEnt, true)
                    SetEntityCollision(interiorEnt, true, true)
                    SetEntityCoords(interiorEnt, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, false)
                    
                    objectData.interiorEntity = interiorEnt
                    objectData.interiorModel = objSD.interiorModel
                    
                    if objSD.interiorModel == "bazq-sur_mkapi" then
                        local doorHash = interiorHash
                        local headingRad = math.rad(objSD.heading or 0.0)
                        local forwardX = -math.sin(headingRad)
                        local forwardY = math.cos(headingRad)
                        
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
                        
                        if DoesEntityExist(door1) and DoesEntityExist(door2) then
                            objectData.interiorEntity = { door1, door2 }
                            objectData.hasDualDoors = true
                        end
                    end
                end
            end
        end
        
        if not (objSD.model == "bazq-sur_mkapi" or (objSD.model and string.match(objSD.model, "bazq%-wall2_gate%d+"))) then
            SetEntityDynamic(ent, false)
        end
        
        table.insert(spawnedObjects, objectData)
        RegisterTargetForEntity(ent)
        return objectData
    else
        DebugLog("LOADING", "CreateFail " .. tostring(objSD.model))
        return nil
    end
end

-- Revision gap detection and recovery
local function CheckAndHandleRevisionMismatch(serverRevision)
    if type(serverRevision) ~= "number" then return false end
    if lastAppliedRevision == 0 then
        lastAppliedRevision = serverRevision
        return false
    end
    if serverRevision == lastAppliedRevision + 1 then
        lastAppliedRevision = serverRevision
        return false
    end
    if serverRevision > lastAppliedRevision + 1 then
        DebugLog("LOADING", string.format("Revision gap detected! Local: %d, Server: %d. Requesting full resync snapshot.", lastAppliedRevision, serverRevision))
        TriggerServerEvent("bazq-objectplace:requestFullSnapshot")
        return true
    end
    -- serverRevision <= lastAppliedRevision: already applied or stale, ignore
    return true
end

-- Initial snapshot / recovery resync loader
RegisterNetEvent("bazq-objectplace:loadObjects")
AddEventHandler("bazq-objectplace:loadObjects", function(data)
    local objectsData = data
    if type(data) == "table" and data.revision and data.objects then
        lastAppliedRevision = data.revision
        objectsData = data.objects
        DebugLoading(string.format("Loaded authoritative snapshot: Revision %d with %d objects", lastAppliedRevision, #objectsData))
    end
    
    -- Clear existing objects
    for _, oD in ipairs(spawnedObjects) do 
        if oD.entity and DoesEntityExist(oD.entity) then 
            SafeDeleteEntity(oD.entity) 
        end 
        if oD.interiorEntity then
            if type(oD.interiorEntity) == "table" then
                for _, interiorEnt in ipairs(oD.interiorEntity) do
                    if DoesEntityExist(interiorEnt) then SafeDeleteEntity(interiorEnt) end
                end
            elseif DoesEntityExist(oD.interiorEntity) then
                SafeDeleteEntity(oD.interiorEntity)
            end
        end
    end
    spawnedObjects = {}
    
    if type(objectsData) ~= "table" then 
        DebugLog("LOADING", "Loaded objects data is not a table.") 
        return 
    end
    
    DebugLog("LOADING", "Received " .. #objectsData .. " objects from server to load.")
    
    for _, objSD in ipairs(objectsData) do 
        SpawnPersistentObject(objSD)
    end
    
    -- Update UI after loading
    SendNUIMessage({action="updateSpawnedList", data=GetSerializableSpawnedObjects()})
    DebugLog("LOADING", "Finished loading snapshot. Spawned objects count: " .. #spawnedObjects)
end)

-- DELTA HANDLERS: objectCreated, objectUpdated, objectDeleted, objectsBatchCreated, objectsBatchDeleted, mutationFailed

RegisterNetEvent("bazq-objectplace:objectCreated", function(delta)
    if type(delta) ~= "table" or not delta.object then return end
    if CheckAndHandleRevisionMismatch(delta.revision) then return end
    
    local reqId = delta.requestId
    local newObj = delta.object
    
    -- Check if this was our pending placement
    if reqId and pendingPlacedEntities[reqId] then
        local pending = pendingPlacedEntities[reqId]
        pendingPlacedEntities[reqId] = nil
        pending.id = newObj.id
        
        -- If user is currently editing this entity, update editing data
        if editingObjectData and editingObjectData.entity == pending.entity then
            editingObjectData.id = newObj.id
        end
        
        SendNUIMessage({action="updateSpawnedList", data=GetSerializableSpawnedObjects()})
        return
    end
    
    -- Other clients: spawn persistent entity
    SpawnPersistentObject(newObj)
    SendNUIMessage({action="updateSpawnedList", data=GetSerializableSpawnedObjects()})
end)

RegisterNetEvent("bazq-objectplace:objectUpdated", function(delta)
    if type(delta) ~= "table" or not delta.object then return end
    if CheckAndHandleRevisionMismatch(delta.revision) then return end
    
    local updated = delta.object
    local objData, idx = GetObjectById(updated.id)
    if objData and idx then
        -- If model changed, delete and recreate
        if updated.model and updated.model ~= objData.model then
            if objData.entity and DoesEntityExist(objData.entity) then
                UnregisterTargetForEntity(objData.entity)
                SafeDeleteEntity(objData.entity)
            end
            if objData.interiorEntity then
                if type(objData.interiorEntity) == "table" then
                    for _, ent in ipairs(objData.interiorEntity) do
                        if DoesEntityExist(ent) then SafeDeleteEntity(ent) end
                    end
                elseif DoesEntityExist(objData.interiorEntity) then
                    SafeDeleteEntity(objData.interiorEntity)
                end
            end
            table.remove(spawnedObjects, idx)
            SpawnPersistentObject(updated)
        else
            -- In-place update
            if updated.coords then
                objData.coords = vector3(updated.coords.x, updated.coords.y, updated.coords.z)
            end
            if updated.heading ~= nil then
                objData.heading = updated.heading
            end
            if updated.rotation then
                objData.rotation = updated.rotation
            end
            if updated.displayName then
                objData.displayName = updated.displayName
            end
            
            if objData.entity and DoesEntityExist(objData.entity) then
                SetEntityCoords(objData.entity, objData.coords.x, objData.coords.y, objData.coords.z, false, false, false, false)
                if objData.rotation then
                    SetEntityRotation(objData.entity, objData.rotation.x, objData.rotation.y, objData.rotation.z, 2, true)
                else
                    SetEntityHeading(objData.entity, objData.heading or 0.0)
                end
                FreezeEntityPosition(objData.entity, true)
            end
        end
        SendNUIMessage({action="updateSpawnedList", data=GetSerializableSpawnedObjects()})
    else
        -- Object was not tracked locally, spawn it
        SpawnPersistentObject(updated)
        SendNUIMessage({action="updateSpawnedList", data=GetSerializableSpawnedObjects()})
    end
end)

RegisterNetEvent("bazq-objectplace:objectDeleted", function(delta)
    if type(delta) ~= "table" or not delta.id then return end
    if CheckAndHandleRevisionMismatch(delta.revision) then return end
    
    local objData, idx = GetObjectById(delta.id)
    if objData and idx then
        if objData.entity and DoesEntityExist(objData.entity) then
            UnregisterTargetForEntity(objData.entity)
            SafeDeleteEntity(objData.entity)
        end
        if objData.interiorEntity then
            if type(objData.interiorEntity) == "table" then
                for _, ent in ipairs(objData.interiorEntity) do
                    if DoesEntityExist(ent) then SafeDeleteEntity(ent) end
                end
            elseif DoesEntityExist(objData.interiorEntity) then
                SafeDeleteEntity(objData.interiorEntity)
            end
        end
        table.remove(spawnedObjects, idx)
        SendNUIMessage({action="updateSpawnedList", data=GetSerializableSpawnedObjects()})
    end
end)

RegisterNetEvent("bazq-objectplace:objectsBatchCreated", function(delta)
    if type(delta) ~= "table" or not delta.objects then return end
    if CheckAndHandleRevisionMismatch(delta.revision) then return end
    
    local reqId = delta.requestId
    if reqId and pendingBatchEntities[reqId] then
        local pendingList = pendingBatchEntities[reqId]
        pendingBatchEntities[reqId] = nil
        for i, authoritativeObj in ipairs(delta.objects) do
            if pendingList[i] then
                pendingList[i].id = authoritativeObj.id
            end
        end
        SendNUIMessage({action="updateSpawnedList", data=GetSerializableSpawnedObjects()})
        return
    end
    
    for _, obj in ipairs(delta.objects) do
        SpawnPersistentObject(obj)
    end
    SendNUIMessage({action="updateSpawnedList", data=GetSerializableSpawnedObjects()})
end)

RegisterNetEvent("bazq-objectplace:objectsBatchDeleted", function(delta)
    if type(delta) ~= "table" or not delta.ids then return end
    if CheckAndHandleRevisionMismatch(delta.revision) then return end
    
    local idSet = {}
    for _, id in ipairs(delta.ids) do idSet[id] = true end
    
    for i = #spawnedObjects, 1, -1 do
        local objData = spawnedObjects[i]
        if objData and objData.id and idSet[objData.id] then
            if objData.entity and DoesEntityExist(objData.entity) then
                UnregisterTargetForEntity(objData.entity)
                SafeDeleteEntity(objData.entity)
            end
            if objData.interiorEntity then
                if type(objData.interiorEntity) == "table" then
                    for _, ent in ipairs(objData.interiorEntity) do
                        if DoesEntityExist(ent) then SafeDeleteEntity(ent) end
                    end
                elseif DoesEntityExist(objData.interiorEntity) then
                    SafeDeleteEntity(objData.interiorEntity)
                end
            end
            table.remove(spawnedObjects, i)
        end
    end
    SendNUIMessage({action="updateSpawnedList", data=GetSerializableSpawnedObjects()})
end)

RegisterNetEvent("bazq-objectplace:mutationFailed", function(data)
    local actionName = data and data.action or "mutation"
    local reasonMsg = data and data.reason or "Unknown error"
    DebugLog("SAVE", string.format("Server rejected %s: %s", actionName, reasonMsg))
    SendNUIMessage({
        action = 'showError',
        message = string.format("Operation failed (%s): %s", actionName, reasonMsg)
    })
    
    local reqId = data and data.requestId
    if reqId then
        if pendingPlacedEntities[reqId] then
            local pending = pendingPlacedEntities[reqId]
            if pending.entity and DoesEntityExist(pending.entity) then
                SafeDeleteEntity(pending.entity)
            end
            if pending.interiorEntity then
                if type(pending.interiorEntity) == "table" then
                    for _, ent in ipairs(pending.interiorEntity) do
                        if DoesEntityExist(ent) then SafeDeleteEntity(ent) end
                    end
                elseif DoesEntityExist(pending.interiorEntity) then
                    SafeDeleteEntity(pending.interiorEntity)
                end
            end
            for i = #spawnedObjects, 1, -1 do
                if spawnedObjects[i].entity == pending.entity then
                    table.remove(spawnedObjects, i)
                    break
                end
            end
            pendingPlacedEntities[reqId] = nil
        end
        if pendingBatchEntities[reqId] then
            local pendingList = pendingBatchEntities[reqId]
            for _, item in ipairs(pendingList) do
                if item.entity and DoesEntityExist(item.entity) then
                    SafeDeleteEntity(item.entity)
                end
                for i = #spawnedObjects, 1, -1 do
                    if spawnedObjects[i].entity == item.entity then
                        table.remove(spawnedObjects, i)
                        break
                    end
                end
            end
            pendingBatchEntities[reqId] = nil
        end
        SendNUIMessage({action="updateSpawnedList", data=GetSerializableSpawnedObjects()})
    end
end)

-- Receive authoritative IDs from server after legacy save (kept for compatibility)
RegisterNetEvent("bazq-objectplace:syncObjectIds")
AddEventHandler("bazq-objectplace:syncObjectIds", function(idList)
    DebugLog("SAVE", "Received legacy syncObjectIds (ignored in Phase 3)")
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
    
    if not placing and not editingObjectData and not isMenuOpen and not pathDrawing then
        SetNuiFocus(true, true)
        isMenuOpen = true
        OpenNUIMenu()
        DebugLog("PLACEMENT", "Menu reopened successfully")
    end
    
    cb({status = 'ok'})
end)

RegisterNUICallback('saveLockState', function(data, cb)
    TriggerServerEvent('bazq-objectplace:saveLockState', data.locked)
    cb('ok')
end)

RegisterNetEvent("bazq-objectplace:receiveLockState")
AddEventHandler("bazq-objectplace:receiveLockState", function(locked)
    if currentUserSettings then
        currentUserSettings.lockNonOwners = locked
    end
    SendNUIMessage({
        action = "updateLockState",
        locked = locked
    })
end)

local function AlignEntityToNormal(entity, normal, heading)
    local headingRad = math.rad(heading)
    local forward = vector3(math.sin(headingRad), math.cos(headingRad), 0.0)
    local right = vector3(math.cos(headingRad), -math.sin(headingRad), 0.0)
    
    local dotF = forward.x * normal.x + forward.y * normal.y + forward.z * normal.z
    local dotR = right.x * normal.x + right.y * normal.y + right.z * normal.z
    
    local projForward = forward - normal * dotF
    local projRight = right - normal * dotR
    
    local lenF = math.sqrt(projForward.x^2 + projForward.y^2 + projForward.z^2)
    if lenF > 0.001 then projForward = projForward / lenF end
    
    local lenR = math.sqrt(projRight.x^2 + projRight.y^2 + projRight.z^2)
    if lenR > 0.001 then projRight = projRight / lenR end
    
    local pitch = math.deg(math.asin(projForward.z))
    local roll = -math.deg(math.asin(projRight.z))
    
    SetEntityRotation(entity, pitch, roll, heading, 2, true)
end

local function BuildPathProps(pointA, pointB, selectedItem, isPackage, customWidth, options, mode, randomizerProps, spawnTower, prevDir, customPackageProps)
    local dist = #(pointB - pointA)
    if dist < 0.1 then return false, 0.0 end
    
    local pathStartIndex = #spawnedObjects + 1
    local dir = (pointB - pointA) / dist
    local startDist = 0.0
    
    local cornerModel = "bazq-kule1"
    local cornerOffset = 2.7
    
    local pkgConf = Config.PathCreator.packages[selectedItem]
    if isPackage and pkgConf and type(pkgConf) == "table" then
        if pkgConf.cornerModel then cornerModel = pkgConf.cornerModel end
        if pkgConf.cornerOffset then cornerOffset = pkgConf.cornerOffset end
    end
    
    -- Corner tower placement at the start of this segment (junction pivot)
    if spawnTower then
        local towerHash = GetHashKey(cornerModel)
        RequestModel(towerHash)
        local startTime = GetGameTimer()
        while not HasModelLoaded(towerHash) do
            if GetGameTimer() - startTime > 3000 then break end
            Citizen.Wait(10)
        end
        
        if HasModelLoaded(towerHash) then
            local towerZ = pointA.z
            if options.snapToGround then
                local hitVal, gZ = GetGroundZFor_3dCoord(pointA.x, pointA.y, pointA.z + 10.0, false)
                if hitVal then towerZ = gZ end
            end
            
            local towerHeading = math.deg(math.atan2(dir.x, dir.y))
            local towerObj = CreateObject(towerHash, pointA.x, pointA.y, towerZ, true, true, false)
            if DoesEntityExist(towerObj) then
                SetEntityAsMissionEntity(towerObj, true, true)
                FreezeEntityPosition(towerObj, true)
                SetEntityCollision(towerObj, true, true)
                SetEntityHeading(towerObj, towerHeading)
                
                local rot = GetEntityRotation(towerObj, 2)
                local newIndex = #spawnedObjects + 1
                spawnedObjects[newIndex] = {
                    entity = towerObj,
                    model = cornerModel,
                    coords = GetEntityCoords(towerObj),
                    heading = GetEntityHeading(towerObj),
                    rotation = {x = rot.x, y = rot.y, z = rot.z},
                    playerName = currentPlacementOptions.playerName or "Unknown",
                    timestamp = GetRealTimestamp(),
                    originalIndex = newIndex
                }
                RegisterTargetForEntity(towerObj)
            end
        end
        
        -- Start wall placement offset by tower radius
        startDist = cornerOffset
    end
    
    local tempDist = startDist
    local propsToSpawn = {}
    local packageProps = {}
    
    if mode == "single" then
        if isPackage then
            local pkgData = Config.PathCreator.packages[selectedItem]
            if type(pkgData) == "table" and pkgData.props then
                packageProps = pkgData.props
            else
                packageProps = packageObjects[selectedItem] or {}
            end
            if #packageProps == 0 then
                table.insert(packageProps, selectedItem)
            end
        end
    end
    
    local spawnedCount = 0
    local safetyCounter = 0
    
    while tempDist + 0.1 < dist and safetyCounter < 200 do
        safetyCounter = safetyCounter + 1
        
        local propName = ""
        local propWidth = customWidth
        
        if mode == "multi" then
            local randVal = math.random(1, 100)
            local selectedProp = nil
            local currentSum = 0
            for _, p in ipairs(randomizerProps) do
                currentSum = currentSum + (tonumber(p.weight) or 0)
                if randVal <= currentSum then
                    selectedProp = p
                    break
                end
            end
            if not selectedProp and #randomizerProps > 0 then
                selectedProp = randomizerProps[1]
            end
            propName = selectedProp and selectedProp.model or ""
            propWidth = selectedProp and tonumber(selectedProp.width) or customWidth
        elseif isPackage then
            local pkgConf = Config.PathCreator.packages[selectedItem]
            local selectedProp = nil
            
            -- Try UI-provided custom weights first
            if customPackageProps and #customPackageProps > 0 then
                local totalWeight = 0
                for _, p in ipairs(customPackageProps) do
                    totalWeight = totalWeight + (tonumber(p.weight) or 0)
                end
                if totalWeight > 0 then
                    local randVal = math.random(1, totalWeight)
                    local currentSum = 0
                    for _, p in ipairs(customPackageProps) do
                        currentSum = currentSum + (tonumber(p.weight) or 0)
                        if randVal <= currentSum then
                            selectedProp = p.model
                            break
                        end
                    end
                end
            end
            
            -- Fallback to config weights or list if customPackageProps is not provided or empty
            if not selectedProp and pkgConf and pkgConf.props then
                if type(pkgConf.props[1]) == "table" then
                    local totalWeight = 0
                    for _, p in ipairs(pkgConf.props) do
                        totalWeight = totalWeight + (p.weight or 0)
                    end
                    local randVal = math.random(1, totalWeight)
                    local currentSum = 0
                    for _, p in ipairs(pkgConf.props) do
                        currentSum = currentSum + (p.weight or 0)
                        if randVal <= currentSum then
                            selectedProp = p.model
                            break
                        end
                    end
                else
                    selectedProp = pkgConf.props[math.random(1, #pkgConf.props)]
                end
            end
            propName = selectedProp or selectedItem
            propWidth = Config.PathCreator.props[propName] or (pkgConf and type(pkgConf) == "table" and pkgConf.width) or customWidth
        else
            propName = selectedItem
            propWidth = Config.PathCreator.props[selectedItem] or customWidth
        end
        
        -- Prevent spawning past pointB
        if tempDist + propWidth > dist then
            break
        end
        
        local centerPos = pointA + dir * (tempDist + propWidth / 2)
        local spawnZ = centerPos.z
        local groundNormal = vector3(0.0, 0.0, 1.0)
        
        if options.snapToGround then
            local ray = StartShapeTestRay(centerPos.x, centerPos.y, centerPos.z + 10.0, centerPos.x, centerPos.y, centerPos.z - 10.0, 1, 0, 7)
            local _, hit, hitCoords, normal, _ = GetShapeTestResult(ray)
            if hit == 1 then
                spawnZ = hitCoords.z
                groundNormal = normal
            else
                local success, gZ = GetGroundZFor_3dCoord(centerPos.x, centerPos.y, centerPos.z + 10.0, false)
                if success then
                    spawnZ = gZ
                end
            end
        end
        
        -- Determine heading offset (Y-oriented props are oriented along heading vector, i.e., 0.0 deg offset)
        local propHeadingOffset = 90.0
        if propName:match("bazq%-sur%d+") then
            propHeadingOffset = 0.0
        end
        local pkgConf = Config.PathCreator.packages[selectedItem]
        if isPackage and pkgConf and type(pkgConf) == "table" and pkgConf.headingOffset ~= nil then
            propHeadingOffset = pkgConf.headingOffset
        end
        
        local pathHeading = math.deg(math.atan2(dir.x, dir.y))
        local baseHeading = pathHeading + propHeadingOffset
        if options.randomRotation then
            baseHeading = baseHeading + math.random(0, 360)
        end
        
        local modelHash = GetHashKey(propName)
        if IsModelInCdimage(modelHash) and IsModelValid(modelHash) then
            RequestModel(modelHash)
            local startTime = GetGameTimer()
            while not HasModelLoaded(modelHash) do
                if GetGameTimer() - startTime > 3000 then break end
                Citizen.Wait(10)
            end
            if HasModelLoaded(modelHash) then
                local obj = CreateObject(modelHash, centerPos.x, centerPos.y, spawnZ, true, true, false)
                if DoesEntityExist(obj) then
                    SetEntityAsMissionEntity(obj, true, true)
                    FreezeEntityPosition(obj, true)
                    SetEntityCollision(obj, true, true)
                    
                    if options.alignToGround then
                        AlignEntityToNormal(obj, groundNormal, baseHeading)
                    else
                        SetEntityHeading(obj, baseHeading)
                    end
                    
                    -- Spawn double doors if it is a gate frame (bazq-sur_kapi)
                    local isDualDoors = false
                    local interiorEnt = nil
                    local interiorModelVal = nil
                    
                    if propName == "bazq-sur_kapi" then
                        local doorHash = GetHashKey("bazq-sur_mkapi")
                        RequestModel(doorHash)
                        local doorStartTime = GetGameTimer()
                        while not HasModelLoaded(doorHash) do
                            if GetGameTimer() - doorStartTime > 3000 then break end
                            Citizen.Wait(10)
                        end
                        
                        if HasModelLoaded(doorHash) then
                            -- Calculate forward direction based on baseHeading
                            local headingRad = math.rad(baseHeading)
                            local forwardX = -math.sin(headingRad)
                            local forwardY = math.cos(headingRad)
                            
                            -- Spawn first door with positive Y offset (+90 degree rotation)
                            local door1Coords = vector3(
                                centerPos.x + (5.37824 * forwardX),
                                centerPos.y + (5.37824 * forwardY),
                                spawnZ
                            )
                            local door1Entity = CreateObject(doorHash, door1Coords.x, door1Coords.y, door1Coords.z, true, true, false)
                            if DoesEntityExist(door1Entity) then
                                SetEntityHeading(door1Entity, baseHeading + 90.0)
                                SetEntityAsMissionEntity(door1Entity, true, true)
                                SetEntityDynamic(door1Entity, true)
                                SetEntityCollision(door1Entity, true, true)
                                if options.alignToGround then
                                    AlignEntityToNormal(door1Entity, groundNormal, baseHeading + 90.0)
                                end
                            end
                            
                            -- Spawn second door with negative Y offset (-90 degree rotation)
                            local door2Coords = vector3(
                                centerPos.x - (5.37824 * forwardX),
                                centerPos.y - (5.37824 * forwardY),
                                spawnZ
                            )
                            local door2Entity = CreateObject(doorHash, door2Coords.x, door2Coords.y, door2Coords.z, true, true, false)
                            if DoesEntityExist(door2Entity) then
                                SetEntityHeading(door2Entity, baseHeading - 90.0)
                                SetEntityAsMissionEntity(door2Entity, true, true)
                                SetEntityDynamic(door2Entity, true)
                                SetEntityCollision(door2Entity, true, true)
                                if options.alignToGround then
                                    AlignEntityToNormal(door2Entity, groundNormal, baseHeading - 90.0)
                                end
                            end
                            
                            if DoesEntityExist(door1Entity) and DoesEntityExist(door2Entity) then
                                interiorEnt = { door1Entity, door2Entity }
                                interiorModelVal = "bazq-sur_mkapi"
                                isDualDoors = true
                            end
                        end
                    end
                    
                    local rot = GetEntityRotation(obj, 2)
                    local newIndex = #spawnedObjects + 1
                    spawnedObjects[newIndex] = {
                        entity = obj,
                        model = propName,
                        coords = GetEntityCoords(obj),
                        heading = GetEntityHeading(obj),
                        rotation = {x = rot.x, y = rot.y, z = rot.z},
                        playerName = currentPlacementOptions.playerName or "Unknown",
                        timestamp = GetRealTimestamp(),
                        originalIndex = newIndex,
                        hasDualDoors = isDualDoors,
                        interiorEntity = interiorEnt,
                        interiorModel = interiorModelVal
                    }
                    
                    RegisterTargetForEntity(obj)
                    spawnedCount = spawnedCount + 1
                    
                    -- Spawn random decal on top of the wall if it's a concrete wall segment, enabled, and chance rolls success
                    if propName:match("^bazq%-wall2_wall%d+") and options.enableDecals and options.activeDecals and #options.activeDecals > 0 then
                        local roll = math.random(1, 100)
                        local chance = tonumber(options.decalFrequency) or 20
                        if roll <= chance then
                            local decalModel = options.activeDecals[math.random(1, #options.activeDecals)]
                            local decalHash = GetHashKey(decalModel)
                            if IsModelInCdimage(decalHash) and IsModelValid(decalHash) then
                                RequestModel(decalHash)
                                local decalStartTime = GetGameTimer()
                                while not HasModelLoaded(decalHash) do
                                    if GetGameTimer() - decalStartTime > 1000 then break end
                                    Citizen.Wait(10)
                                end
                                
                                if HasModelLoaded(decalHash) then
                                    local decalObj = CreateObject(decalHash, centerPos.x, centerPos.y, spawnZ, true, true, false)
                                    if DoesEntityExist(decalObj) then
                                        SetEntityAsMissionEntity(decalObj, true, true)
                                        FreezeEntityPosition(decalObj, true)
                                        SetEntityCollision(decalObj, true, true)
                                        
                                        if options.alignToGround then
                                            AlignEntityToNormal(decalObj, groundNormal, baseHeading)
                                        else
                                            SetEntityHeading(decalObj, baseHeading)
                                        end
                                        
                                        local dRot = GetEntityRotation(decalObj, 2)
                                        local dIndex = #spawnedObjects + 1
                                        spawnedObjects[dIndex] = {
                                            entity = decalObj,
                                            model = decalModel,
                                            coords = GetEntityCoords(decalObj),
                                            heading = GetEntityHeading(decalObj),
                                            rotation = {x = dRot.x, y = dRot.y, z = dRot.z},
                                            playerName = currentPlacementOptions.playerName or "Unknown",
                                            timestamp = GetRealTimestamp(),
                                            originalIndex = dIndex
                                        }
                                        RegisterTargetForEntity(decalObj)
                                    end
                                end
                            end
                        end
                    end
                end
                SetModelAsNoLongerNeeded(modelHash)
            end
        end
        
        -- Apply the user-defined overlap margin (converted from cm to meters) to prevent visible gaps between consecutive walls
        local overlapVal = 1.5
        if options and options.overlapMargin ~= nil then
            overlapVal = tonumber(options.overlapMargin) or 1.5
        end
        local overlapMargin = overlapVal / 100.0
        tempDist = tempDist + propWidth - overlapMargin
    end
    
    if spawnedCount > 0 or spawnTower then
        local batchReqId = GenerateRequestId("path")
        local newBatch = {}
        local newBatchEntities = {}
        for idx = pathStartIndex, #spawnedObjects do
            local item = spawnedObjects[idx]
            if item then
                table.insert(newBatchEntities, item)
                table.insert(newBatch, {
                    model = item.model,
                    coords = { x = item.coords.x, y = item.coords.y, z = item.coords.z },
                    heading = item.heading,
                    rotation = item.rotation,
                    interiorModel = item.interiorModel,
                    hasDualDoors = item.hasDualDoors,
                    playerName = item.playerName,
                    timestamp = item.timestamp
                })
            end
        end
        
        pendingBatchEntities[batchReqId] = newBatchEntities
        TriggerServerEvent("bazq-objectplace:batchPlaceObjects", {
            objects = newBatch,
            requestId = batchReqId
        })
        
        SendNUIMessage({
            action = 'updateSpawnedList',
            data = GetSerializableSpawnedObjects()
        })
        SendNUIMessage({
            action = 'log',
            message = 'Path Creator: Successfully placed ' .. (spawnedCount + (spawnTower and 1 or 0)) .. ' objects.',
            type = 'success'
        })
        return true, tempDist
    else
        SendNUIMessage({
            action = 'log',
            message = 'Path Creator: No objects placed (path too short or invalid models).',
            type = 'warning'
        })
        return false, 0.0
    end
end

local activePathOptions = nil

local function StartPathDrawingLoop(selectedItem, isPackage, customWidth, options, mode, randomizerProps, customPackageProps)
    local pointA = nil
    local pointB = nil
    local prevDir = nil
    local hasDrawingFocus = false
    local lastHit = false
    local lastHitCoords = vector3(0.0, 0.0, 0.0)
    activePathOptions = options
    
    SendNUIMessage({
        action = 'log',
        message = 'Entered Path Creator. Left Click: Set Point A/B. Right Click/ESC: Exit.',
        type = 'info'
    })
    
    SendNUIMessage({
        action = 'editingModeUpdate',
        message = "PATH DRAWING: Aim & Left Click to set Point A. Right Click/ESC: Exit.",
        editingActive = true
    })
    
    local playerPed = PlayerPedId()
    SetPedCanSwitchWeapon(playerPed, false)
    DisablePlayerFiring(PlayerId(), true)
    
    -- Wait 500ms to prevent NUI click propagation into the placement loop
    Citizen.Wait(500)
    
    while pathDrawing do
        Citizen.Wait(0)
        
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 322, true)
        DisableControlAction(0, 200, true)
        DisableControlAction(0, 19, true) -- Prevent Character Wheel (Left ALT)
        DisableControlAction(0, 73, true) -- Prevent Duck/Look Behind (X Key)
        
        -- Hold Left ALT (Control 19) to show mouse and change settings in UI
        local isAltPressed = IsDisabledControlPressed(0, 19)
        if isAltPressed then
            if not hasDrawingFocus then
                hasDrawingFocus = true
                SetNuiFocus(true, true)
            end
        else
            if hasDrawingFocus then
                hasDrawingFocus = false
                SetNuiFocus(false, false)
            end
        end
        
        -- Press X (Control 73) to toggle Axis Snapping (90° Snap) in-game
        if IsDisabledControlJustReleased(0, 73) then
            options.axisLock = not options.axisLock
            SendNUIMessage({
                action = 'updateAxisLockCheckbox',
                state = options.axisLock
            })
        end
        
        local hit, hitCoords = false, nil
        if not hasDrawingFocus then
            local rHit, rCoords = RaycastFromCamera()
            if rHit then
                hit = true
                hitCoords = rCoords
                lastHit = true
                lastHitCoords = rCoords
            end
        else
            hit = lastHit
            hitCoords = lastHitCoords
        end
        
        if hit and pointA and options.axisLock then
            local rawDir = hitCoords - pointA
            local dist = #(rawDir)
            if dist > 0.1 then
                local angleCursor = math.atan2(-rawDir.x, rawDir.y)
                local snappedAngle = 0.0
                if prevDir then
                    local anglePrev = math.atan2(-prevDir.x, prevDir.y)
                    local relativeAngle = angleCursor - anglePrev
                    
                    while relativeAngle > math.pi do relativeAngle = relativeAngle - 2 * math.pi end
                    while relativeAngle < -math.pi do relativeAngle = relativeAngle + 2 * math.pi end
                    
                    local snappedRelative = math.floor((relativeAngle + math.rad(45)) / math.rad(90)) * math.rad(90)
                    snappedAngle = anglePrev + snappedRelative
                else
                    snappedAngle = math.floor((angleCursor + math.rad(45)) / math.rad(90)) * math.rad(90)
                end
                local snappedDir = vector3(-math.sin(snappedAngle), math.cos(snappedAngle), 0.0)
                hitCoords = pointA + snappedDir * dist
            end
        end
        
        -- Render cyan snapping grid on the terrain
        if options.axisLock and pointA then
            local spacing = customWidth or 1.0
            if isPackage then
                local pkgData = Config.PathCreator.packages[selectedItem]
                spacing = (pkgData and type(pkgData) == "table" and pkgData.width) or 1.0
            else
                spacing = Config.PathCreator.props[selectedItem] or customWidth or 1.0
            end
            
            local gridHeading = 0.0
            if prevDir then
                gridHeading = math.atan2(-prevDir.x, prevDir.y)
            end
            
            local rightDir = vector3(-math.sin(gridHeading + math.rad(90)), math.cos(gridHeading + math.rad(90)), 0.0)
            local fwdDir = vector3(-math.sin(gridHeading), math.cos(gridHeading), 0.0)
            
            for i = -10, 10 do
                local offsetR = rightDir * (i * spacing)
                local startP = pointA + offsetR - fwdDir * (10 * spacing)
                local endP = pointA + offsetR + fwdDir * (10 * spacing)
                
                local success1, z1 = GetGroundZFor_3dCoord(startP.x, startP.y, pointA.z + 10.0, false)
                local success2, z2 = GetGroundZFor_3dCoord(endP.x, endP.y, pointA.z + 10.0, false)
                local drawZ1 = success1 and z1 or startP.z
                local drawZ2 = success2 and z2 or endP.z
                
                DrawLine(startP.x, startP.y, drawZ1 + 0.1, endP.x, endP.y, drawZ2 + 0.1, 0, 180, 255, 60)
                
                local offsetF = fwdDir * (i * spacing)
                local startP2 = pointA + offsetF - rightDir * (10 * spacing)
                local endP2 = pointA + offsetF + rightDir * (10 * spacing)
                
                local success1_2, z1_2 = GetGroundZFor_3dCoord(startP2.x, startP2.y, pointA.z + 10.0, false)
                local success2_2, z2_2 = GetGroundZFor_3dCoord(endP2.x, endP2.y, pointA.z + 10.0, false)
                local drawZ1_2 = success1_2 and z1_2 or startP2.z
                local drawZ2_2 = success2_2 and z2_2 or endP2.z
                
                DrawLine(startP2.x, startP2.y, drawZ1_2 + 0.1, endP2.x, endP2.y, drawZ2_2 + 0.1, 0, 180, 255, 60)
            end
        end
        
        if pointA then
            DrawMarker(28, pointA.x, pointA.y, pointA.z + 0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 255, 120, 0, 200, false, true, 2, nil, nil, false)
            
            if hit then
                DrawLine(pointA.x, pointA.y, pointA.z + 0.1, hitCoords.x, hitCoords.y, hitCoords.z + 0.1, 0, 255, 0, 255)
                DrawMarker(28, hitCoords.x, hitCoords.y, hitCoords.z + 0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 0, 255, 0, 200, false, true, 2, nil, nil, false)
                
                local dist = #(hitCoords - pointA)
                local dir = (hitCoords - pointA) / dist
                local tempDist = 0.0
                
                local pathHeading = math.deg(math.atan2(dir.x, dir.y))
                
                local segmentIndex = 1
                while tempDist < dist do
                    local width = customWidth
                    
                    if mode == "multi" then
                        local seed = math.floor(pointA.x * 100) + math.floor(pointA.y * 100) + segmentIndex * 17
                        local randVal = (math.abs(seed) % 100) + 1
                        local selectedProp = nil
                        local currentSum = 0
                        for _, p in ipairs(randomizerProps) do
                            currentSum = currentSum + (tonumber(p.weight) or 0)
                            if randVal <= currentSum then
                                selectedProp = p
                                break
                            end
                        end
                        if not selectedProp and #randomizerProps > 0 then
                            selectedProp = randomizerProps[1]
                        end
                        width = selectedProp and tonumber(selectedProp.width) or customWidth
                    elseif isPackage then
                        local pkgData = Config.PathCreator.packages[selectedItem]
                        width = (type(pkgData) == "table" and pkgData.width) or pkgData or 1.0
                    else
                        width = Config.PathCreator.props[selectedItem] or customWidth
                    end
                    
                    if tempDist + width > dist then
                        break
                    end
                    
                    local centerPos = pointA + dir * (tempDist + width / 2)
                    local spawnZ = centerPos.z
                    
                    if options.snapToGround then
                        local hitVal, gZ = GetGroundZFor_3dCoord(centerPos.x, centerPos.y, centerPos.z + 10.0, false)
                        if hitVal then
                            spawnZ = gZ
                        end
                    end
                    
                    DrawMarker(1, centerPos.x, centerPos.y, spawnZ, 0.0, 0.0, 0.0, 0.0, 0.0, pathHeading, width, 0.2, 0.5, 0, 255, 0, 80, false, true, 2, nil, nil, false)
                    
                    tempDist = tempDist + width
                    segmentIndex = segmentIndex + 1
                    if segmentIndex > 100 then break end
                end
            end
        else
            if hit then
                DrawMarker(28, hitCoords.x, hitCoords.y, hitCoords.z + 0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 0, 120, 255, 200, false, true, 2, nil, nil, false)
            end
        end
        
        if IsDisabledControlJustReleased(0, 24) and hit and not hasDrawingFocus then
            if not pointA then
                pointA = hitCoords
                SendNUIMessage({
                    action = 'editingModeUpdate',
                    message = "PATH DRAWING: Point A set. Left Click to set Point B and build walls.",
                    editingActive = true
                })
            else
                pointB = hitCoords
                local dist = #(pointB - pointA)
                if dist >= 0.1 then
                    local dir = (pointB - pointA) / dist
                    
                    -- Check if corner tower is needed (angle change close to options.cornerAngle)
                    local spawnTower = false
                    if options.cornerTowers and prevDir then
                        local dot = prevDir.x * dir.x + prevDir.y * dir.y + prevDir.z * dir.z
                        dot = math.max(-1.0, math.min(1.0, dot))
                        local angleChange = math.abs(math.deg(math.acos(dot)))
                        
                        local targetAngle = tonumber(options.cornerAngle) or 90.0
                        if math.abs(angleChange - targetAngle) <= 30.0 then
                            spawnTower = true
                        end
                    end
                    
                    local success, actualPlacedDist = BuildPathProps(pointA, pointB, selectedItem, isPackage, customWidth, options, mode, randomizerProps, spawnTower, prevDir, customPackageProps)
                    if success then
                        prevDir = dir
                        pointA = pointA + dir * actualPlacedDist
                        pointB = nil
                    else
                        pointB = nil
                    end
                else
                    pointB = nil
                end
            end
        end
        
        if (IsDisabledControlJustReleased(0, 25) or IsDisabledControlJustReleased(0, 322) or IsDisabledControlJustReleased(0, 200)) and not hasDrawingFocus then
            pathDrawing = false
            break
        end
    end
    
    pathDrawing = false
    activePathOptions = nil
    SetPedCanSwitchWeapon(playerPed, true)
    DisablePlayerFiring(PlayerId(), false)
    
    SendNUIMessage({action = 'editingModeUpdate', editingActive = false})
    SendNUIMessage({action = 'exitDrawingMode'})
    
    SetNuiFocus(true, true)
    isMenuOpen = true
    OpenNUIMenu()
end

RegisterNUICallback('updateDrawingOptions', function(data, cb)
    if pathDrawing and activePathOptions then
        for k, v in pairs(data) do
            activePathOptions[k] = v
        end
    end
    cb('ok')
end)

RegisterNUICallback('startPathDrawing', function(data, cb)
    if placing or editingObjectData then
        SendNUIMessage({action = 'showError', message = "Finish placement/editing before drawing paths."})
        cb({status = 'error'}); return
    end
    
    local model = data.model
    local customWidth = tonumber(data.width) or 1.0
    local options = data.options or {}
    local mode = data.mode or "single"
    local randomizerProps = data.randomizerProps or {}
    local customPackageProps = data.customPackageProps or {}
    
    local isPackage = false
    if mode == "single" then
        if model == "bazq-wall3" then
            model = "wall3"
        end
        if Config.PathCreator.packages[model] then
            isPackage = true
        end
    end
    
    pathDrawing = true
    SendNUIMessage({action = 'enterDrawingMode'})
    SetNuiFocus(false, false)
    isMenuOpen = false
    
    Citizen.CreateThread(function()
        StartPathDrawingLoop(model, isPackage, customWidth, options, mode, randomizerProps, customPackageProps)
    end)
    
    cb('ok')
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
    OpenNUIMenu()
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

-- Disable controls when menu is open or during object placement/editing/path drawing
Citizen.CreateThread(function()
    while true do
        local shouldDisable = isMenuOpen or placing or editingObjectData ~= nil or pathDrawing == true
        
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
                DebugLog("GENERAL", "Combat controls disabled - Menu: " .. tostring(isMenuOpen) .. ", Placing: " .. tostring(placing) .. ", Editing: " .. tostring(editingObjectData ~= nil) .. ", Path: " .. tostring(pathDrawing))
            end
            Citizen.Wait(0)
        else
            -- Re-enable controls
            if isControlsDisabled then
                isControlsDisabled = false
                DebugLog("GENERAL", "Combat controls enabled")
            end
            Citizen.Wait(500) -- Sleep for 500ms when not active to save CPU cycles
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

RegisterNetEvent("bazq-objectplace:onlinePlayersResponse")
AddEventHandler("bazq-objectplace:onlinePlayersResponse", function(players)
    SendNUIMessage({
        action = 'onlinePlayersResponse',
        players = players
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

RegisterNUICallback('getOnlinePlayers', function(data, cb)
    TriggerServerEvent("bazq-objectplace:getOnlinePlayers")
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
    local obj, index = GetSpawnedObjectByIdOrIndex(data.id, tonumber(data.index))
    local newName = data.newName
    
    if obj and index and newName and newName ~= "" then
        spawnedObjects[index].displayName = newName
        if obj.id then
            TriggerServerEvent("bazq-objectplace:updateObject", {
                id = obj.id,
                changes = { displayName = newName }
            })
        end
        SendNUIMessage({action="updateSpawnedList", data=GetSerializableSpawnedObjects()})
        DebugLog("USER", "Renamed object " .. tostring(obj.id or index) .. " to: " .. newName)
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

local isInTestZone = false
local testZoneCheckInterval = 5000 -- Check every 5 seconds

-- Check if player is in test zone
function IsPlayerInTestZone()
    if not Config.TestZone or not Config.TestZone.enabled then
        DebugLog("GENERAL", "TestZone not enabled or config missing")
        return false
    end
    
    if not Config.TestZone.center then
        DebugLog("GENERAL", "TestZone center coordinates missing!")
        return false
    end
    
    local playerPed = PlayerPedId()
    local playerPos = GetEntityCoords(playerPed)
    local center = Config.TestZone.center
    local radius = Config.TestZone.radius or 100.0
    
    local distance = #(vector3(playerPos.x, playerPos.y, playerPos.z) - vector3(center.x, center.y, center.z))
    
    -- Only log if debug is enabled
    if Config.Debug then
        DebugLog("GENERAL", string.format("TestZone check - Distance: %.1fm, Radius: %.1fm, InZone: %s", 
            distance, radius, distance <= radius and "YES" or "NO"))
    end
    
    return distance <= radius
end

-- TestZone monitoring thread - ENABLED for auto menu control
CreateThread(function()
    -- Wait a bit for resource initialization
    Wait(2000)
    
    if not Config.TestZone or not Config.TestZone.enabled then
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
            if Config.TestZone.showControlsUI then
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
            if Config.TestZone.showControlsUI then
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
        if Config.TestZone and Config.TestZone.enabled and 
           Config.TestZone.specialControls and Config.TestZone.specialControls.enabled and
           IsPlayerInTestZone() then
           
            local controls = Config.TestZone.specialControls
            
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
                    local objToDelete = spawnedObjects[nearestObjectIndex]
                    DeleteSpawnedObject(nearestObjectIndex, objToDelete and objToDelete.id)
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
                        id = objData.id,
                        entity = objData.entity, 
                        originalIndex = nearestObjectIndex, 
                        model = objData.model,
                        originalCoords = GetEntityCoords(objData.entity), 
                        originalHeading = GetEntityHeading(objData.entity),
                        timestamp = objData.timestamp,
                        playerName = objData.playerName
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
    if not (Config.TestZone and Config.TestZone.enabled) then
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
    DebugLog("FREECAM", "Config.TestZone exists: " .. tostring(Config.TestZone ~= nil))
    if Config.TestZone then
        DebugLog("FREECAM", "Config.TestZone.enabled: " .. tostring(Config.TestZone.enabled))
        if Config.TestZone.enabled then
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
    
    -- Check config
    DebugLog("MENU", "1. Config.TestZone exists: " .. tostring(Config.TestZone ~= nil))
    if Config.TestZone then
        DebugLog("MENU", "2. Config.TestZone.enabled: " .. tostring(Config.TestZone.enabled))
        DebugLog("MENU", "3. Config.TestZone.center exists: " .. tostring(Config.TestZone.center ~= nil))
        if Config.TestZone.center then
            local center = Config.TestZone.center
            DebugLog("MENU", string.format("4. Center: x=%.2f, y=%.2f, z=%.2f", center.x, center.y, center.z))
            DebugLog("MENU", "5. Config.TestZone.radius: " .. tostring(Config.TestZone.radius))
            
            -- Check player position and distance
            local playerPed = PlayerPedId()
            local playerPos = GetEntityCoords(playerPed)
            DebugLog("MENU", string.format("6. Player: x=%.2f, y=%.2f, z=%.2f", playerPos.x, playerPos.y, playerPos.z))
            
            local distance = #(vector3(playerPos.x, playerPos.y, playerPos.z) - vector3(center.x, center.y, center.z))
            local radius = Config.TestZone.radius or 100.0
            DebugLog("MENU", string.format("7. Distance to center: %.2f meters", distance))
            DebugLog("MENU", string.format("8. Required radius: %.2f meters", radius))
            DebugLog("MENU", string.format("9. In zone calculation: %s", tostring(distance <= radius)))
        end
    end
    
    -- Test zone check function
    local inZone = IsPlayerInTestZone()
    DebugLog("MENU", "10. IsPlayerInTestZone() result: " .. tostring(inZone))
    
    DebugLog("MENU", "========== END F7 DEBUG ==========")
end, false)

RegisterNUICallback('teleportToObject', function(data, cb)
    local objData, index = GetSpawnedObjectByIdOrIndex(data.id, tonumber(data.index))
    if not objData or not index then
        DebugLog("NUI", "Teleport failed: Invalid object " .. tostring(data.id or data.index))
        cb('error')
        return
    end

    local targetEntity = objData.entity
    local targetCoords = objData.coords

    -- If entity doesn't exist but we have coords, spawn/teleport there
    if not (targetEntity and DoesEntityExist(targetEntity)) then
        DebugLog("NUI", "Target entity invalid, teleporting to coords")
        if targetCoords then
             SetEntityCoords(PlayerPedId(), targetCoords.x, targetCoords.y, targetCoords.z + 2.0, false, false, false, true)
             cb('ok')
        else
             cb('error')
        end
        return
    end

    -- Teleport to entity
    local entCoords = GetEntityCoords(targetEntity)
    SetEntityCoords(PlayerPedId(), entCoords.x, entCoords.y, entCoords.z + 10.0, false, false, false, true)
    
    -- Highlight
    SetEntityDrawOutline(targetEntity, true)
    SetEntityDrawOutlineColor(255, 255, 0, 255) -- Yellow highlight
    
    -- Clear highlight after 8 seconds
    Citizen.SetTimeout(8000, function()
        if DoesEntityExist(targetEntity) then
            SetEntityDrawOutline(targetEntity, false)
        end
    end)
    
    DebugLog("NUI", "Teleported to object: " .. tostring(objData.id or index))
    cb('ok')
end)

RegisterCommand('testwarning', function()
    -- Ensure UI is visible for the test
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'show' }) 
    
    -- Send the test warning trigger
    SendNUIMessage({
        action = 'testPerformanceWarning',
        count = 1600 -- Arbitrary number above 500
    })
    
    DebugLog("TEST", "Triggered performance warning test")
end, false)
