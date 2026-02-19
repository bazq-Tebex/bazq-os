# 🏗️ *bazq* Object Spawner

Professional object spawning and building system for FiveM servers. Place, edit, and manage objects with advanced tools and user management.

![Version](https://img.shields.io/badge/version-2.3.1-green.svg)
![Platform](https://img.shields.io/badge/platform-FiveM-blue.svg)

## 🔗 Support & Store

- **💬 Discord Support**: [https://discord.gg/YrnHuHrK3A](https://discord.gg/YrnHuHrK3A)
- **🛒 Tebex Store**: [bazq.tebex.io](https://bazq.tebex.io) for more premium scripts

---

## ⚡ Quick Start

### 🔐 Getting Access

Contact your server admin for permissions. You need **Owner**, **Admin**, or **Mapper** role to use the spawner.

### 🎮 Basic Controls

- **F7** - Open/close spawner menu
- **F6** - Toggle freecam (noclip)
- **ESC** - Close menu
- **Left Click** - Place selected object
- **Q/E** - Rotate object before placing

---

## 🎛️ Main Features

### 📦 Object Library

- **Categorized Objects** - Tents, walls, towers, gates, signs, aircraft
- **Search Function** - Find objects quickly by name
- **Package System** - Enable/disable object packs

### ⚙️ Manual Spawner

- **Any GTA V Prop** - Spawn by typing model name
- **Examples**: `prop_chair_01a`, `adder`, `prop_container_01a`
- **Recent Props** - Quick access to recently used models

### 🏗️ Building Tools

- **Teleport to Object** - Instantly jump to any placed object
- **Real-Time Editing** - Move and rotate placed objects
- **Ground Snapping** - Auto-align objects to ground
- **Precision Controls** - Fine-tune positioning with keyboard
- **Freecam Mode** - Build from any angle with extended camera

### 🛠️ Advanced Tools

- **JSON to YMAP** - Included Python converter with GUI `json2ymap`
- **Performance Safety** - Auto-alert for high object counts (>500)
- **Stability System** - Strict Z-locking preventing object drift

### 👥 User Management

- **Role System** - Owner > Admin > Mapper hierarchy
- **Permission Control** - Granular access management
- **User Dashboard** - Add/remove/edit user permissions

---

## 🎮 Detailed Controls

### Menu Navigation

- **F7** - Toggle main menu
- **Tab Navigation** - Switch between Library/Manual/Placed/Settings/Users
- **Search** - Type to find objects instantly

### Object Placement

- **Mouse** - Aim where to place object
- **Left Click** - Confirm placement
- **Q/E** - Rotate left/right
- **Mouse Wheel** - Adjust height
- **G** - Toggle ground snapping

### Edit Mode

- **WASD** - Move object horizontally
- **R/F** - Move up/down
- **Q/E** - Rotate
- **X** - Toggle precise rotation
- **Enter** - Save changes
- **ESC** - Cancel editing

### Freecam Mode

- **F6** - Toggle freecam on/off
- **WASD** - Move camera
- **Space/Ctrl** - Move up/down
- **Shift** - Move faster
- **Mouse** - Look around

---

## 🔧 Server Setup (Admins)

### 1. Installation

1. Extract to `resources/[your-folder]/bazq-os`
2. Add `ensure bazq-os` to server.cfg
3. Add `setr game_enableDynamicDoorCreation true` to server.cfg
4. Restart server

### 2. Admin Setup

Edit `osadmin.json` and add yourself:

```json
{
  "userManagement": {
    "users": [{
      "identifier": "steam:YOUR_STEAM_ID",
      "displayName": "Your Name",
      "role": "owner"
    }]
  }
}
```

### 3. Configuration

- **Debug Output**: Edit `debug_config.lua` - set `enabled = false` for production
- **Object Packages**: Configure available objects in `objects_config.json`
- **User Management**: Use in-game F7 menu or edit `osadmin.json`

---

## 🆘 Troubleshooting

### Common Issues

**❌ "Access Denied" when pressing F7**

- Contact your server admin for permissions
- Check if you have Owner/Admin/Mapper role

**❌ F6 freecam not working**

- Requires admin permissions
- Check server console for permission errors

**❌ Objects not saving**

- Check server write permissions
- Verify `saved_objects.json` is writable

**❌ Menu not opening**

- Try restarting the resource: `restart bazq-os`
- Check server console for errors

### Debug Commands

- `/checkfocus` - Check menu focus status
- `/testf7` - Test F7 permissions
- `/testf6` - Test F6 permissions

---

## 📋 Roles & Permissions

### 👑 Owner

- **Full Access** - Everything including user management
- **User Control** - Add/remove/modify all users
- **Settings** - Configure all aspects of the system

### ⚙️ Admin  

- **Building Tools** - Full spawner access
- **User Management** - Manage mappers (not owners)
- **System Control** - Time/weather controls

### 🗺️ Mapper

- **Building Only** - Object spawning and editing
- **No User Management** - Cannot add/remove users
- **Basic Tools** - All building features available

---

## 📞 Support

Need help? Join our Discord community:

- **💬 Discord**: [https://discord.gg/YrnHuHrK3A](https://discord.gg/YrnHuHrK3A)
- **🛒 More Scripts**: [bazq.tebex.io](https://bazq.tebex.io)

*Thank you for choosing bazq Object Spawner! 🚀*
