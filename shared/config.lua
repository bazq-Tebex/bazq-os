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
