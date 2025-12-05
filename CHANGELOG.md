# *bazq*-os Changelog

## Version 2.2.0 - January 2025 🧪

### 🏪 TestZone System - Internal Showcase Feature
- **bazq Showcase Server**: TestZone designed exclusively for bazq's internal Tebex showcase server
- **Customer Demo Environment**: Allows potential customers to preview bazq props on your server
- **Internal Use Only**: Feature not intended for customer servers - disabled by default
- **Zone-Based Demo Access**: F7 menu and F6 freecam available to visitors within showcase area
- **Showcase Controls**: Special controls for demonstrating prop features to potential buyers
- **Auto-Cleanup**: Keeps showcase environment clean between customer visits
- **Showcase UI**: Displays available demo controls for visitors

### 🔧 Permission Logic Overhaul
- **Internal Showcase Mode**: TestZone overrides admin permissions only on bazq's demo server
- **Customer Server Mode**: `testZone.enabled = false` (default) - normal admin-only operation
- **Transparent to Customers**: TestZone functionality hidden and unused on customer servers
- **Debug Commands**: Internal tools for managing showcase server functionality

### 🐛 Critical Bug Fixes
- **Fixed Variable Shadowing**: Resolved duplicate `debugConfig` declarations causing permission failures
- **Fixed Mode Conflicts**: Prevented unwanted placement→edit mode switches via E key
- **Fixed Key Bindings**: Replaced problematic key threads with proper `RegisterCommand` system
- **Fixed Server Events**: Corrected F6 calling wrong server permission events

### 🎨 UI Enhancements
- **TestZone Controls UI**: Animated display showing available special controls
- **Visual Feedback**: Clear chat messages for permission grants/denials
- **Error Prevention**: Proper state checking prevents mode conflicts during placement

### 🛠️ Technical Improvements
- **Unified Event System**: Both F6/F7 now use consistent server permission checking
- **Enhanced Debugging**: Comprehensive debug output for permission troubleshooting
- **Code Cleanup**: Removed duplicate logic and improved function organization
- **Future-Proof Architecture**: Extensible TestZone system for additional features

### 📋 Multi-Visitor Demo Support
- **Concurrent Visitors**: Multiple potential customers can preview props simultaneously on showcase server
- **Individual Tracking**: Each visitor gets separate identification for demo management
- **Isolated Previews**: No conflicts between different visitors' demo objects
- **Fresh Demo Environment**: Auto-cleanup ensures clean showcase for each new visitor session

---

## Version 2.1.0 - December 2024 ✨

### 🎨 Grid & UI Enhancements
- **Grid Time Display**: Full date & time format (DD/MM/YYYY HH:MM) in placed objects grid
- **Smart Layout**: Time badge positioned above user name for better readability
- **Enhanced Styling**: Monospace font, centered text, better visual hierarchy
- **Responsive Design**: Auto-scaling font sizes for compact/expanded modes

### ✏️ User Management Features
- **User Edit System**: Comprehensive modal for editing user details
- **Edit Capabilities**: Display name, identifier, and role modification
- **Smart Validation**: Duplicate identifier detection, empty field validation
- **Instant Updates**: Real-time sync across all admin users
- **Professional UI**: Orange-themed edit buttons with intuitive design

### 🚪 Smart Object Management
- **Automatic Door Cleanup**: Surkapi deletion automatically removes associated doors
- **Proximity Detection**: 10m radius search for related door objects
- **Entity Management**: Proper cleanup of main + interior + dual door entities
- **Server Synchronization**: Automatic save and UI refresh after cleanup

### 🛠️ Technical Improvements
- **Function Organization**: Fixed showConfirmDialog dependency issues
- **Timestamp Handling**: Robust parsing for various timestamp formats
- **Debug Logging**: Enhanced console output for troubleshooting
- **CSS Optimization**: Improved grid layout and responsive behavior

### 🐛 Bug Fixes
- Fixed user edit modal JavaScript errors
- Resolved grid time display visibility issues
- Corrected timestamp formatting inconsistencies
- Fixed layout ordering in grid items

---

## Version 2.0.0 - July 2025 🎉

### 🚀 Major Features
- **3-Tier User Management System**: Complete Owner > Admin > Mapper hierarchy
- **Advanced Debug System**: Configurable debug output with categories and easy on/off controls
- **Customer-Ready Package**: Professional documentation and clean configuration files
- **Enhanced Security**: F7-level access control and anti-lockout protection

### 🛠️ Improvements
- **Professional Documentation**: Comprehensive README files with support information
- **Clean Configuration**: Customer-ready JSON files with clear setup instructions
- **Debug Categories**: PLACEMENT, DELETION, MENU, USER, LOADING, GENERAL, EDIT, FREECAM, SAVE, COLLISION
- **Support Integration**: Discord and Tebex store information throughout documentation

### 🐛 Bug Fixes
- Fixed door deletion issues with dual door systems
- Resolved menu state management problems
- Fixed object highlighting and selection issues
- Corrected permission hierarchy enforcement

### 🔧 Technical Changes
- Added `/reloaddebug` command for runtime debug configuration
- Implemented comprehensive logging system
- Enhanced error handling and user feedback
- Optimized file structure for customer distribution

### 📞 Support & Community
- **Discord**: https://discord.gg/YrnHuHrK3A
- **Store**: [bazq.tebex.io](https://bazq.tebex.io)

---

## Version 1.9.0 - June 2025

### 🎨 UI Overhaul
- Complete interface redesign with modern styling
- Enhanced object browser with category filtering
- Improved user management interface
- Added expandable views and better navigation

### 🎥 Freecam System
- Advanced freecam controls for precision building
- 4x extended building range
- Professional camera movement system
- Perfect for complex structures

### 📱 Manual Spawner
- Access to complete GTA V prop library
- Recent props memory system
- Enhanced search and spawn capabilities
- Unlimited object possibilities

### ✨ Object System
- Smart object placement with ground snapping
- Advanced object editing with keyboard controls
- Object duplication and management
- Enhanced selection and highlighting

---

## Version 1.5.0 - Earlier 2025

### 📦 Package System
- Organized object packages (Wall Pack 1, Wall Pack 2, Tents)
- Category-based object organization
- Package-specific permissions
- Enhanced object library structure

### 👥 User Management Foundation
- Basic admin controls
- User permission system
- Role-based access control
- Foundation for advanced user management

---

## Version 1.0.0 - Initial Release

### 🏗️ Core Features
- Basic object spawning system
- Simple placement controls
- File-based object storage
- Basic user interface

### 🎯 Essential Functions
- Object placement and rotation
- Save/load functionality
- Basic permission system
- Simple object management

---

*For technical support and updates, join our Discord community at https://discord.gg/YrnHuHrK3A* 