# *bazq*-os Debug System

## Overview
The bazq-os object spawner includes a comprehensive debug system to help with development and troubleshooting. Debug messages can be easily enabled/disabled without restarting the resource.

## Quick Start

### 🔧 Disable All Debug Output
1. Open `debug_config.lua`
2. Set `enabled = false`
3. Run `/reloaddebug` in-game or restart the resource

### 🎯 Enable Specific Debug Categories
1. Open `debug_config.lua`
2. Set `enabled = true`
3. Enable only the categories you need:
   ```lua
   levels = {
       PLACEMENT = true,     -- Only show placement debug
       DELETION = false,     -- Hide deletion debug
       LOADING = false,      -- Hide loading debug
       MENU = false,         -- Hide menu debug
       USER = false,         -- Hide user debug
       GENERAL = false,      -- Hide general debug
       EDIT = false,         -- Hide edit mode debug
       FREECAM = false,      -- Hide freecam debug
       SAVE = false,         -- Hide save debug
       COLLISION = false     -- Hide collision debug
   }
   ```
4. Run `/reloaddebug` in-game

## Debug Categories

| Category | Description | When to Enable |
|----------|-------------|----------------|
| **PLACEMENT** | Object spawning, positioning, rotation | Issues with object placement |
| **DELETION** | Object removal, cleanup, door deletion | Objects not deleting properly |
| **LOADING** | Loading objects from server, model loading | Objects not appearing on restart |
| **MENU** | Menu state, UI opening/closing | Menu not working properly |
| **USER** | User management, permissions, roles | Permission or user issues |
| **GENERAL** | General script operations | General troubleshooting |
| **EDIT** | Edit mode, keyboard controls | Edit mode not working |
| **FREECAM** | Freecam toggle operations | Freecam issues |
| **SAVE** | Save operations to server | Objects not saving |
| **COLLISION** | Physics and collision debug | Physics issues (very spammy) |

## Debug Commands

### `/reloaddebug`
Reloads the debug configuration without restarting the resource. Use this after editing `debug_config.lua`.

## Configuration Options

### Master Switch
```lua
enabled = true  -- Set to false to disable ALL debug output
```

### Message Formatting
```lua
format = {
    use_timestamps = false,  -- Add timestamps: [12:34:56] [OP-DEBUG]-LEVEL message
    use_colors = false,      -- Reserved for future color support
    prefix = "[OP-DEBUG]"    -- Change the debug prefix
}
```

## Common Debug Scenarios

### 🚪 Gate Doors Not Deleting
Enable: `DELETION = true`
Look for: Door entity existence checks, dual door processing

### 📦 Objects Not Spawning
Enable: `PLACEMENT = true, LOADING = true`
Look for: Model loading timeouts, invalid models

### 🎮 Menu Issues
Enable: `MENU = true, USER = true`
Look for: Menu state changes, permission checks

### 💾 Objects Not Saving
Enable: `SAVE = true, LOADING = true`
Look for: Save operations, server communication

### 🔧 Edit Mode Problems
Enable: `EDIT = true, PLACEMENT = true`
Look for: Edit state changes, keyboard input

## File Locations

- **Debug Config**: `debug_config.lua` (in resource root)
- **Debug System**: Built into `client/main.lua`

## Performance Notes

- Debug output has minimal performance impact when disabled
- `COLLISION` and `FREECAM` categories can be very spammy
- For production servers, set `enabled = false`

## Example Configurations

### 🔍 Development Mode (Everything On)
```lua
return {
    enabled = true,
    levels = {
        PLACEMENT = true,
        DELETION = true,
        LOADING = true,
        MENU = true,
        USER = true,
        GENERAL = true,
        EDIT = true,
        FREECAM = true,
        SAVE = true,
        COLLISION = true
    }
}
```

### 🏭 Production Mode (Everything Off)
```lua
return {
    enabled = false,
    levels = {
        -- All will be ignored when enabled = false
    }
}
```

### 🔧 Troubleshooting Mode (Essential Only)
```lua
return {
    enabled = true,
    levels = {
        PLACEMENT = true,
        DELETION = true,
        LOADING = true,
        MENU = false,
        USER = false,
        GENERAL = false,
        EDIT = false,
        FREECAM = false,
        SAVE = true,
        COLLISION = false
    }
}
```

## Tips

1. **Start Minimal**: Enable only the category you're debugging
2. **Use `/reloaddebug`**: No need to restart the resource
3. **Check Console**: Use F8 console to view debug messages
4. **Production Ready**: Always disable debug on live servers
5. **Report Issues**: Include relevant debug output when reporting bugs

## 📞 Support

- **💬 Discord Support**: [https://discord.gg/YrnHuHrK3A](https://discord.gg/YrnHuHrK3A)
- **🛒 Store**: [bazq.tebex.io](https://bazq.tebex.io) for more premium scripts
- **🐛 Bug Reports**: Use our Discord #bug-reports channel with debug output

*Join our Discord community for technical support and updates!* 