-- ================================
-- BAZQ-OS DEBUG CONFIGURATION
-- ================================
-- This file controls debug output for the bazq-os object spawner
-- Edit these values to enable/disable debug messages
--
-- 🎛️ QUICK SETUP:
-- • Set 'enabled = false' to disable ALL debug output
-- • Set individual levels to false to disable specific debug types
-- • Useful for production servers to reduce console spam
--
-- 📋 DEBUG LEVELS:
-- • SERVER: Server startup, file operations, general server messages
-- • CONFIG: Configuration loading and parsing messages  
-- • USER: User management, permissions, role changes
-- • LOADING: Object loading from files, server requests
-- • SAVE: Object saving operations and file writes
-- • MENU/GENERAL: UI operations, menu state changes
-- • FREECAM: Freecam toggle operations (can be spammy)
-- • PLACEMENT/DELETION: Object spawn/delete operations
-- • EDIT: Object editing and modification operations

return {
    -- Master debug switch - set to false to disable ALL debug output
    enabled = false,
    
    -- Individual debug categories - you can turn specific types on/off
    levels = {
        PLACEMENT = false,     -- Object placement and positioning debug
        DELETION = false,      -- Object deletion and cleanup debug  
        LOADING = false,       -- Object loading from server debug
        MENU = false,          -- Menu state and UI debug (ENABLED for TestZone debugging)
        USER = false,          -- User management and permissions debug
        GENERAL = false,       -- General script operations debug
        EDIT = false,          -- Edit mode and keyboard controls debug
        FREECAM = false,      -- Freecam toggle debug (can be spammy)
        SAVE = false,          -- Save operations debug
        COLLISION = false,     -- Collision and physics debug (very spammy)
        TIMESTAMP = false,     -- Timestamp handling debug
        TESTZONE = false,    -- TestZone distance checks (DISABLED - too spammy)
        SERVER = false,       -- Server-side operations and startup messages
        CONFIG = false        -- Configuration loading and parsing messages
    },
    
    -- Debug message format settings
    format = {
        use_timestamps = true,  -- Add timestamps to debug messages
        use_colors = true,      -- Use colored output (if supported)
        prefix = "[OP-DEBUG]"    -- Prefix for all debug messages
    },

    -- Test zone configuration: allow everyone to use F7 within a zone and
    -- optionally auto-cleanup their placed props on disconnect (server-side)
    testZone = {
        enabled = false, -- Set to true to enable test zone functionality
        center = { x = -2665.58, y = -1474.36, z = 24.9 }, -- Test zone center coordinates
        radius = 150.0, -- Test zone radius in meters
        cleanupOnDisconnect = false, -- Auto-cleanup placed objects when player disconnects
        forceTestMode = false, -- Force test mode regardless of admin permissions
        
        -- Additional test zone features (only active when enabled = true)
        autoOpenMenu = false, -- Auto-open menu when entering test zone
        autoCloseMenu = false, -- Auto-close menu when leaving test zone  
        showControlsUI = false, -- Show controls UI in test zone
        specialControls = {
            enabled = false, -- Enable special controls in test zone
            quickSpawn = 121, -- INSERT key - quick spawn
            quickDelete = 177, -- CTRL+DELETE - quick delete
            quickEdit = 38, -- E key - quick edit
            helpKey = 47 -- G key - help menu
        }
    },

    -- User management settings
    userManagement = {
        autoPromoteFirstUser = true, -- Set to true to auto-promote first user to owner
        requireApproval = false
    }
}

--[[
🚀 PRODUCTION SERVER EXAMPLE:
For a clean production server with minimal console output, use:

return {
    enabled = false,  -- Disable all debug output
    levels = {},      -- All levels disabled
    format = {
        use_timestamps = false,
        use_colors = false,
        prefix = "[bazq-os]"
    },
    testZone = { enabled = false },
    userManagement = {
        autoPromoteFirstUser = false,  -- Manually add admins via osadmin.json
        requireApproval = false
    }
}
--]] 