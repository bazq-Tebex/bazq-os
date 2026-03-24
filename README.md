# 🏗️ bazq Object Spawner

Professional object spawning and building system for FiveM servers. Place, edit, and manage objects with advanced tools, built-in user management, and developer-friendly configurations.

![Version](https://img.shields.io/badge/version-2.3.1-green.svg)
![Platform](https://img.shields.io/badge/platform-FiveM-blue.svg)

---

## 👤 User Guide

Welcome to the `bazq-os` User Guide! This section covers everything you need to know to spawn, edit, and manage objects in-game.

### ⚡ Quick Start

#### 🔐 Getting Access

Contact your server admin for permissions. You need the **Owner**, **Admin**, or **Mapper** role to use the spawner UI.

#### 🎮 Basic Controls

- **F7** - Open/close the main spawner menu
- **ESC** - Close menu or cancel current action
- **Left Click** - Place selected object
- **Q / E** - Rotate object temporarily before placing
- **F6** - Toggle freecam (noclip) for easier building

### 🎛️ Main Features

#### 📦 Object Library

- **Categorized Objects**: Browse neatly sorted categories (Tents, walls, towers, gates, signs, aircraft).
- **Search Function**: Find objects quickly by typing their name.
- **Package System**: Distinct object packs loaded automatically.

#### ⚙️ Manual Spawner

- **Any GTA V Prop**: Spawn anything by typing its exact model name (Examples: `prop_chair_01a`, `adder`).
- **Recent Props**: Quick access to your recently used custom models.

#### 🏗️ Building & Editing Tools

- **Real-Time Editing**: Move, rotate, and adjust objects that you've already placed down.
- **Ground Snapping**: Auto-align objects to the ground level (`G` key).
- **Precision Rotation**: Snap rotation to 1° or 5° steps during edit mode.
- **Teleport to Object**: Instantly jump to any placed object via the "Placed" tab.

### 🎮 Detailed Controls

#### Object Placement Mode

- **Mouse**: Aim exactly where to place the object.
- **Left Click**: Confirm placement and drop the object.
- **Q / E**: Rotate left/right.
- **Mouse Wheel**: Adjust height manually offset.
- **G**: Toggle ground snapping.

#### Keyboard Edit Mode

Once you select an object to edit from the UI, you enter Keyboard Edit Mode:

- **W, A, S, D**: Move object horizontally along the ground.
- **Alt / F**: Move object Up / Down vertically.
- **Q / E**: Rotate object.
- **X**: Toggle precise rotation snap (1° or 5° steps).
- **R**: Reset rotation back to 0°.
- **Left Click**: Save changes.
- **Right Click**: Cancel edit and revert to original position.

#### Freecam Mode (F6)

Provides a detached camera to build intricate structures easily:

- **W, A, S, D**: Move camera.
- **Space / Ctrl**: Move straight up / down.
- **Shift**: Move faster (sprint speed).
- **Mouse**: Look around.

### 📋 Roles & Permissions

- 👑 **Owner**: Full access. Can add, remove, and modify the roles of other users. Can manage all objects.
- ⚙️ **Admin**: Full spawner access. Can manage Mappers, but cannot manage Owners.
- 🗺️ **Mapper**: Can spawn and edit objects. Cannot manage users.

---

## 💻 Developer Guide (Open Source Documentation)

Welcome to the `bazq-os` Developer Guide! This script is completely Open Source, meaning you have full freedom to modify, expand, and tailor the codebase to your server's exact needs. This documentation provides deep insights into the architecture and where to make your custom edits.

### 🏗️ Architecture Overview

The script is split into three main operational layers:

1. **NUI (JavaScript/HTML/CSS)**: Handles the interface, library search, placed object lists, and user configurations heavily styled in `html/`.
2. **Client Scope (`client/main.lua`)**: Processes physical entity creation, keyboard manipulation loops, raycasting, camera logic, and rendering 3D bounding boxes.
3. **Server Scope (`server/main.lua`)**: Functions as the central database ledger. It retains `osadmin.json` parsing and broadcasts `saved_objects.json` datasets dynamically to sync all clients globally.

---

### 🔧 Code Editing & Customization

#### 🖥️ 1. NUI Customization (`html/` folder)

The UI relies on standard HTML/JS, bundled logically in `html/app.js` and `html/style.css`.

- **Adding New Features**: If you want to add a new tool (e.g., a color picker for objects), edit `index.html` to add your UI component, then hook an event listener in `app.js` using `fetch("https://bazq-os/myCustomCallback", ...)`
- **Object Data Flow**: The JS receives arrays containing `{model, coords, heading, timestamp, playerName}` dynamically from Lua. Do not mutate the `timestamp` or `playerName` properties natively inside JS; treat them strictly as identifiers!
- **Date Grouping Logic**: Handled heavily in `app.js` (`getDateGroup()`). It natively protects against large timestamp desyncs.

#### 🎮 2. Client-Side Logic (`client/main.lua`)

This is where the physical heavy lifting occurs within GTA V.

- **The Core Raycast Engine**: Object placement relies on a native screen-to-world raycast. If you want to change how objects ignore collision layers (like ignoring vehicles), review the raycast `flags` variable inside the placement loop.
- **`KeyboardEditLoop()`**: This function is triggered when a user enters "Edit Mode". If you want to script custom "Grid Snapping" increments or support gamepads, add your input detection here using `IsDisabledControlPressed()`.
- **Entity State**: Objects placed by `bazq-os` are stored dynamically in the local `spawnedObjects` array. They are intentionally spawned as mission entities (`SetEntityAsMissionEntity`) so they persist locally until manually deleted.

#### 📡 3. Server-Side Logic (`server/main.lua`)

This file intercepts all save requests, manages file IO, and handles the permission hierarchies.

- **Overriding Save Logic (`bazq-objectplace:saveObjects`)**: By default, this script saves to a local `saved_objects.json`. If you want to sync this to an SQL Database (like MySQL or PostgreSQL), you can intercept this event handler, iterate over `objectsDataFromClient`, and fire your `MySQL.insert` queries natively.
- **Modifying the Admin System**: The script builds a dictionary tree mapping identifiers into `"owner"`, `"admin"`, or `"mapper"`. You can integrate your server's exact role hierarchy by modifying the `Framework:IsAdmin()` wrappers natively.

---

### ⚙️ Configuration Files

The codebase is built dynamically to support translations and zero-code adjustments easily.

#### 1. Core System (`shared/config.lua`)

- `Config.Debug`: Toggle `true/false` to enable deeply structured developer console messages (`dbg()`).
- `Config.Framework`: Set to `"esx"`, `"qb"`, `"qbox"`, `"ox"`, or `"auto"`.
- `Config.UserManagement`: Controls role hierarchies like `autoPromoteFirstUser` or `requireApproval`.

#### 2. Localization (`shared/locales.lua`)

All notifications and permissions text are drawn from here via the `L('key')` helper instead of being hardcoded into the business logic.

#### 3. Object Library Array (`objects_config.json`)

The source of truth for the UI's Library tab. Add completely custom map props here directly so they appear perfectly categorized in the menu.

---

### 🐍 Python Extensions (`json2ymap.py`)

`bazq-os` places objects dynamically at runtime, but developers may want to bake structures permanently into their map (`stream/` folder) as a compiled `.ymap` file for zero performance overhead.

- We've included a standalone `json2ymap.py` script equipped with a `tkinter` GUI.
- **Architecture Flow**: The script reads `saved_objects.json`, computes quaternion rotations internally using native mathematical bindings, and spits out standard XML nodes matching CodeWalker's raw YMAP specifications.
- **Customizing It**: You can open `json2ymap.py` and modify the default LOD distance (`lodDist`), the extents computations, or adjust how bounding spheres are calculated iteratively.

### 🛠️ Developer Debugging Ecosystem

We strictly adhere to maintaining a clean server console.

- **Do not use raw `print()` statements**. Instead, natively load our `dbg(msg)` helper function which executes comprehensively across the client and server threads. 
- Wrapping test endpoints inside `dbg()` guarantees output only flags inside terminal when your `Config.Debug` boolean is explicitly declared true.

#### Useful Diagnostic Endpoints

- `/checkfocus`: Forces a check of the menu NUI focus state locally if NUI is stuck.
- `/testf7` / `/testf6`: Manual boolean tests triggering permission wrapper callbacks on the backend to verify SQL/JSON hierarchy reads securely.

---

**💬 Join the Discord Developer Community**: [https://discord.gg/YrnHuHrK3A](https://discord.gg/YrnHuHrK3A)  
**🛒 View the bazq Ecosystem**: [bazq.tebex.io](https://bazq.tebex.io)
