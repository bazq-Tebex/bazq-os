-- ================================
-- BAZQ-OS CONFIGURATION
-- ================================

Config = {}

-- ⚙️ General Settings
Config.Debug = false            -- Developer mode for console logs
Config.Locale = 'en'              -- 'tr' for Turkish, 'en' for English

-- 🏗️ Framework Settings
Config.Framework = 'auto'       -- 'auto' attempts to detect qb-core, esx, qbox, ox_core

-- 🏢 TestZone Settings
-- Allow everyone to use F7 within a zone and optionally auto-cleanup
Config.TestZone = {
    enabled = false,
    center = { x = -2665.58, y = -1474.36, z = 24.9 },
    radius = 150.0,
    cleanupOnDisconnect = false,
    forceTestMode = false,
    
    -- Additional features (only active when enabled)
    autoOpenMenu = false,
    autoCloseMenu = false,
    showControlsUI = false,
    specialControls = {
        enabled = false,
        quickSpawn = 121, -- INSERT
        quickDelete = 177, -- CTRL+DELETE
        quickEdit = 38, -- E
        helpKey = 47 -- G
    }
}

-- 👥 User Management Settings
Config.UserManagement = {
    autoPromoteFirstUser = true, -- Auto-promote the first user joining to 'owner'
    requireApproval = false
}

-- 🔌 Keybindings
Config.Keys = {
    OpenMenu = 'F7',
    Freecam = 'F6'
}

-- 🏗️ Pen Tool / Blueprint Editor Settings (Package Metadata & Dimensions)
Config.PenTool = {
    packages = {
        ["wall_pack_1"] = {
            id = "wall_pack_1",
            name = "Structures / Stone Walls",
            width = 10.0,
            headingOffset = 0.0, -- Align along Y
            cornerModel = "bazq-kule1",
            cornerOffset = 2.7,
            cornerLadder = "bazq-kule_ladder",
            props = {
                { model = "bazq-sur1", length = 10.0, weight = 40, damage = 1 },
                { model = "bazq-sur2", length = 10.0, weight = 15, damage = 2 },
                { model = "bazq-sur3", length = 10.0, weight = 15, damage = 3 },
                { model = "bazq-sur4", length = 10.0, weight = 15, damage = 4 },
                { model = "bazq-sur5", length = 10.0, weight = 15, damage = 5 }
            },
            gateAssembly = {
                frameModel = "bazq-sur_kapi",
                length = 20.0,
                headingOffset = 0.0,
                doorModel = "bazq-sur_mkapi",
                doors = {
                    door1 = { forwardOffset = 5.37824, headingOffset = 90.0 },
                    door2 = { forwardOffset = -5.37824, headingOffset = -90.0 }
                }
            },
            attachments = {
                fence = {
                    model = "bazq-surfence",
                    zOffset = 5.0,
                    headingOffset = 0.0,
                    optional = true
                }
            }
        },
        ["wall_pack_2"] = {
            id = "wall_pack_2",
            name = "Concrete Quarantine Walls",
            width = 2.0,
            headingOffset = 90.0,
            cornerModel = "bazq-wall2_pole",
            cornerOffset = 0.25,
            props = {
                { model = "bazq-wall2_wall1", length = 2.0, weight = 40, damage = 1 },
                { model = "bazq-wall2_wall2", length = 2.0, weight = 15, damage = 2 },
                { model = "bazq-wall2_wall3", length = 2.0, weight = 15, damage = 3 },
                { model = "bazq-wall2_wall4", length = 2.0, weight = 15, damage = 4 },
                { model = "bazq-wall2_wall5", length = 2.0, weight = 15, damage = 5 }
            },
            gateAssembly = {
                models = { "bazq-wall2_gate1", "bazq-wall2_gate2", "bazq-wall2_gate3", "bazq-wall2_gate4" },
                defaultModel = "bazq-wall2_gate1",
                length = 6.0,
                headingOffset = 90.0,
                poles = {
                    model = "bazq-wall2_pole",
                    -- Local offsets relative to gate center:
                    -- tangentOffset: distance along wall line (±3.0m to endpoints)
                    -- normalOffset: perpendicular front/back offset to clear animated gate swing (RUNTIME/MANUAL OFFSET REQUIRED for non-zero clearance)
                    leftPole = { tangentOffset = -3.0, normalOffset = 0.0, zOffset = 0.0, headingOffset = 0.0 },
                    rightPole = { tangentOffset = 3.0, normalOffset = 0.0, zOffset = 0.0, headingOffset = 0.0 }
                }
            },
            attachments = {
                fence = {
                    model = "bazq-wall2_wallfence",
                    zOffset = 0.0,
                    headingOffset = 0.0,
                    optional = true
                },
                decals = {
                    models = {
                        "bazq-wall2_walldecal1", "bazq-wall2_walldecal2", "bazq-wall2_walldecal3",
                        "bazq-wall2_walldecal4", "bazq-wall2_walldecal5", "bazq-wall2_walldecal6",
                        "bazq-wall2_walldecal7", "bazq-wall2_walldecal8", "bazq-wall2_walldecal9",
                        "bazq-wall2_walldecal10"
                    },
                    zOffset = 0.0,
                    headingOffset = 0.0,
                    optional = true,
                    defaultChance = 20
                }
            }
        },
        ["wall3"] = {
            id = "wall3",
            name = "Wood Palisade / Panels",
            width = 1.0, -- Average/fallback width for wood walls
            headingOffset = 90.0,
            props = {
                { model = "bazq-wall3_log1", length = 0.30, weight = 10, name = "Log 1" },
                { model = "bazq-wall3_log2", length = 0.37, weight = 10, name = "Log 2" },
                { model = "bazq-wall3_log3", length = 0.40, weight = 10, name = "Log 3" },
                { model = "bazq-wall3_log4", length = 0.46, weight = 10, name = "Log 4" },
                { model = "bazq-wall3_log5", length = 0.50, weight = 10, name = "Log 5" },
                { model = "bazq-wall3_wall1", length = 1.98, weight = 15, name = "Panel 1" },
                { model = "bazq-wall3_wall2", length = 1.95, weight = 15, name = "Panel 2" },
                { model = "bazq-wall3_wall3", length = 2.01, weight = 20, name = "Panel 3" }
            },
            gateAssembly = {
                frameModel = "bazq-wall3_gateframe",
                gateModel = "bazq-wall3_gate",
                length = 2.01,
                headingOffset = 90.0
            }
        }
    },
    props = {
        ["bazq-wall1"] = 7.0,
        ["bazq-wall2"] = 2.0,
        ["bazq-wall3"] = 0.35,
        -- wood wall paketi (wall3) tekil prop genişlikleri
        ["bazq-wall3_log1"] = 0.30,
        ["bazq-wall3_log2"] = 0.37,
        ["bazq-wall3_log3"] = 0.40,
        ["bazq-wall3_log4"] = 0.46,
        ["bazq-wall3_log5"] = 0.50,
        ["bazq-wall3_wall1"] = 1.98,
        ["bazq-wall3_wall2"] = 1.95,
        ["bazq-wall3_wall3"] = 2.01,
        ["bazq-wall3_gateframe"] = 2.01,
        ["bazq-wall3_gate"] = 2.01,
        -- sur1 - sur5 placeholders
        ["bazq-sur1"] = 10.0,
        ["bazq-sur2"] = 10.0,
        ["bazq-sur3"] = 10.0,
        ["bazq-sur4"] = 10.0,
        ["bazq-sur5"] = 10.0,
        ["bazq-sur_kapi"] = 20.0,
        ["bazq-wall2_gate1"] = 6.0,
        ["bazq-wall2_gate2"] = 6.0,
        ["bazq-wall2_gate3"] = 6.0,
        ["bazq-wall2_gate4"] = 6.0
    }
}

-- Server authoritative max batch placement limit
Config.MaxBatchSize = 300

-- Backward compatibility alias
Config.PathCreator = Config.PenTool


