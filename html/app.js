// ============================================================================
// BAZQ-OS OBJECT SPAWNER - Enhanced UI System with User Management
// ============================================================================

// Debug Mode - Set to true only for development
const DEBUG_MODE = false;

// Custom debug logger
function debugLog(...args) {
  if (DEBUG_MODE) {
    console.log(...args);
  }
}

// TestZone UI Handler - Defined at top to ensure availability
function handleTestZoneUI(data) {
  const testZoneUI = document.getElementById('testzoneControlsUI');
  if (!testZoneUI) {
    if (DEBUG_MODE) console.warn('TestZone Controls UI element not found');
    return;
  }

  if (data.show) {
    // Show UI with animation
    testZoneUI.classList.remove('hidden');
    debugLog('TestZone Controls UI shown');

    // Add a subtle pulse effect when first shown
    setTimeout(() => {
      testZoneUI.style.animation = 'pulse 0.5s ease-in-out';
    }, 400);

  } else {
    // Hide UI with animation
    testZoneUI.classList.add('fade-out');
    setTimeout(() => {
      testZoneUI.classList.add('hidden');
      testZoneUI.classList.remove('fade-out');
      testZoneUI.style.animation = '';
    }, 300);
    debugLog('TestZone Controls UI hidden');
  }
}

// Helper function for model-specific icons
function getModelIcon(itemModel) {
  // If it's a bazq item, try to show its actual image
  if (itemModel.startsWith('bazq-')) {
    const imagePath = `images/${itemModel}.png`;
    // Check if image exists by trying to create an img element
    const img = new Image();
    img.src = imagePath;

    // Return image HTML if bazq item
    return `<img src="${imagePath}" alt="${itemModel}" class="item-image" onerror="this.style.display='none'; this.nextSibling.style.display='inline';" />
            <span class="fallback-icon" style="display:none;">${getBazqFallbackIcon(itemModel)}</span>`;
  }

  // Fallback to emoji for non-bazq items
  if (itemModel.includes("tent")) return "⛺";
  else if (itemModel.includes("wall") || itemModel.includes("sur")) return "🧱";
  else if (itemModel.includes("gate")) return "🚪";
  else if (itemModel.includes("kule") || itemModel.includes("tower")) return "🗼";
  else if (itemModel.includes("sign")) return "🪧";
  else if (itemModel.includes("pole")) return "📍";
  else if (itemModel.includes("fence")) return "🚧";
  else if (itemModel.includes("decal")) return "🎨";
  else if (itemModel.includes("crashed") || itemModel.includes("plane") || itemModel.includes("helicopter")) return "🚁";
  return "📦";
}

function getBazqFallbackIcon(itemModel) {
  // Fallback emoji for bazq items when image fails to load
  if (itemModel.includes("tent")) return "⛺";
  else if (itemModel.includes("wall") || itemModel.includes("sur")) return "🧱";
  else if (itemModel.includes("gate") || itemModel.includes("kapi")) return "🚪";
  else if (itemModel.includes("kule")) return "🗼";
  else if (itemModel.includes("sign")) return "🪧";
  else if (itemModel.includes("pole")) return "📍";
  else if (itemModel.includes("fence")) return "🚧";
  else if (itemModel.includes("decal")) return "🎨";
  else if (itemModel.includes("crashed") || itemModel.includes("plane")) return "🚁";
  return "📦";
}

// Global logging function accessible to all components
function addLogEntry(message, type = 'info') {
  if (DEBUG_MODE) {
    console.log(`[${type.toUpperCase()}] ${message}`);
  }

  const logContent = document.getElementById('logContent');
  if (logContent) {
    const now = new Date();
    const timeString = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

    const logEntry = document.createElement('div');
    logEntry.className = `log-entry ${type}`;

    const timeSpan = document.createElement('span');
    timeSpan.className = 'log-time';
    timeSpan.textContent = timeString;

    const messageSpan = document.createElement('span');
    messageSpan.className = 'log-message';
    messageSpan.textContent = message;

    logEntry.appendChild(timeSpan);
    logEntry.appendChild(messageSpan);

    logContent.appendChild(logEntry);

    // Auto-scroll to bottom
    logContent.scrollTop = logContent.scrollHeight;

    // Keep only last 50 entries
    while (logContent.children.length > 50) {
      logContent.removeChild(logContent.firstChild);
    }
  }
}

// Global User Management System
let userManagementData = {
  users: [],
  currentUserRole: 'guest',
  currentUserIdentifier: ''
};

// User Management Functions
function initializeUserManagement() {
  const addUserBtn = document.getElementById('addUserBtn');
  const newUserIdentifier = document.getElementById('newUserIdentifier');
  const newUserName = document.getElementById('newUserName');
  const newUserRole = document.getElementById('newUserRole');
  const userSearchBar = document.getElementById('userSearchBar');
  const userClearSearchBtn = document.getElementById('userClearSearchBtn');
  const exportUsersBtn = document.getElementById('exportUsersBtn');
  const clearAllMappersBtn = document.getElementById('clearAllMappersBtn');
  const refreshUserListBtn = document.getElementById('refreshUserListBtn');

  const getOnlinePlayersBtn = document.getElementById('getOnlinePlayersBtn');
  const closeOnlinePlayersBtn = document.getElementById('closeOnlinePlayersBtn');

  if (addUserBtn) {
    addUserBtn.addEventListener('click', handleAddUser);
  }

  if (getOnlinePlayersBtn) {
    getOnlinePlayersBtn.addEventListener('click', requestOnlinePlayers);
  }

  if (closeOnlinePlayersBtn) {
    closeOnlinePlayersBtn.addEventListener('click', () => {
      document.getElementById('onlinePlayersDialog').style.display = 'none';
      document.body.classList.remove('modal-open');
    });
  }

  if (newUserIdentifier) {
    newUserIdentifier.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') handleAddUser();
    });
  }

  if (newUserName) {
    newUserName.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') handleAddUser();
    });
  }

  if (userSearchBar) {
    userSearchBar.addEventListener('input', handleUserSearch);
  }

  if (userClearSearchBtn) {
    userClearSearchBtn.addEventListener('click', clearUserSearch);
  }

  if (exportUsersBtn) {
    exportUsersBtn.addEventListener('click', exportUsers);
  }

  if (clearAllMappersBtn) {
    clearAllMappersBtn.addEventListener('click', clearAllMappers);
  }

  if (refreshUserListBtn) {
    refreshUserListBtn.addEventListener('click', refreshUserList);
  }

  // Load initial user data
  requestUserList();

  // Add window message listener for server responses
  window.addEventListener('message', function (event) {
    if (event.data.action === 'userListResponse') {
      handleUserListResponse(event.data);
    } else if (event.data.action === 'userActionResponse') {
      handleUserActionResponse(event.data);
    } else if (event.data.action === 'showTestZoneUI') {
      handleTestZoneUI(event.data);
    } else if (event.data.action === 'onlinePlayersResponse') {
      handleOnlinePlayersResponse(event.data);
    }
  });
}

function requestOnlinePlayers() {
  const dialog = document.getElementById('onlinePlayersDialog');
  const list = document.getElementById('onlinePlayersList');
  
  if (dialog && list) {
    list.innerHTML = '<div style="text-align:center; color:#94a3b8; padding: 20px;">Loading players...</div>';
    dialog.style.display = 'flex';
    document.body.classList.add('modal-open');
    
    fetch('https://bazq-os/getOnlinePlayers', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({})
    }).catch(error => {
      console.error('Error fetching online players:', error);
      list.innerHTML = '<div style="text-align:center; color:#ef4444; padding: 20px;">Failed to fetch players.</div>';
    });
  }
}

function handleOnlinePlayersResponse(data) {
  const list = document.getElementById('onlinePlayersList');
  if (!list) return;

  if (data.players && data.players.length > 0) {
    list.innerHTML = '';
    data.players.sort((a, b) => a.distance - b.distance);
    
    data.players.forEach(player => {
      const distanceText = player.distance >= 0 ? `${Math.round(player.distance)}m away` : 'Unknown distance';
      const item = document.createElement('div');
      item.style.cssText = 'display: flex; justify-content: space-between; align-items: center; padding: 10px; background: #1f2937; border-radius: 6px; cursor: pointer; border: 1px solid #374151;';
      item.onmouseover = () => item.style.borderColor = '#3b82f6';
      item.onmouseout = () => item.style.borderColor = '#374151';
      
      item.innerHTML = `
        <div style="display: flex; flex-direction: column;">
          <span style="color: #f1f5f9; font-weight: 500;">${escapeHtml(player.name)} <span style="color: #64748b; font-size: 12px;">(ID: ${player.id})</span></span>
          <span style="color: #94a3b8; font-size: 12px; font-family: monospace;">${escapeHtml(player.identifier)}</span>
        </div>
        <div style="color: #3b82f6; font-size: 12px; font-weight: 500;">
          ${distanceText}
        </div>
      `;
      
      item.addEventListener('click', () => {
        const idInput = document.getElementById('newUserIdentifier');
        const nameInput = document.getElementById('newUserName');
        if (idInput) idInput.value = player.identifier;
        if (nameInput) nameInput.value = player.name;
        
        document.getElementById('onlinePlayersDialog').style.display = 'none';
        document.body.classList.remove('modal-open');
        addLogEntry(`Selected player ${player.name} (${player.identifier})`, 'info');
      });
      
      list.appendChild(item);
    });
  } else {
    list.innerHTML = '<div style="text-align:center; color:#94a3b8; padding: 20px;">No other players found nearby/online.</div>';
  }
}

function handleAddUser() {
  const identifierInput = document.getElementById('newUserIdentifier');
  const nameInput = document.getElementById('newUserName');
  const roleSelect = document.getElementById('newUserRole');

  const identifier = identifierInput?.value.trim();
  const displayName = nameInput?.value.trim();
  const role = roleSelect?.value;

  if (!identifier || !displayName) {
    addLogEntry('Please fill in all required fields', 'error');
    return;
  }

  if (!isValidIdentifier(identifier)) {
    addLogEntry('Invalid identifier format. Use steam:hex, license:hex, or fivem:alphanumeric', 'error');
    return;
  }

  if (userManagementData.users.find(u => u.identifier === identifier)) {
    addLogEntry('User with this identifier already exists', 'error');
    return;
  }

  const userData = {
    identifier: identifier,
    displayName: displayName,
    role: role,
    addedBy: userManagementData.currentUserIdentifier,
    dateAdded: new Date().toISOString()
  };

  addLogEntry(`Adding user: ${displayName} as ${role}`, 'info');

  fetch('https://bazq-os/addUser', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(userData)
  }).then(response => {
    // Clear form on successful request
    identifierInput.value = '';
    nameInput.value = '';
    roleSelect.value = 'mapper';
    // Response will come via window message
    return { status: 'callback_sent' };
  }).catch(error => {
    console.error('Error sending add user request:', error);
    addLogEntry('Failed to send add user request: ' + error.message, 'error');
  });
}

function isValidIdentifier(identifier) {
  const steamPattern = /^steam:[0-9a-fA-F]{15,17}$/; // Steam IDs are typically 15-17 hex characters
  const licensePattern = /^license:[0-9a-fA-F]{40}$/;  // License is 40 hex characters
  const fivemPattern = /^fivem:[a-zA-Z0-9_-]+$/;       // FiveM allows alphanumeric + underscore/dash
  return steamPattern.test(identifier) || licensePattern.test(identifier) || fivemPattern.test(identifier);
}

function handleUserSearch() {
  const searchTerm = document.getElementById('userSearchBar')?.value.toLowerCase() || '';
  renderUserList(searchTerm);
}

function clearUserSearch() {
  const searchBar = document.getElementById('userSearchBar');
  if (searchBar) {
    searchBar.value = '';
    renderUserList();
  }
}

function requestUserList() {
  fetch('https://bazq-os/getUserList', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({})
  }).then(response => {
    // NUI callbacks don't return meaningful JSON, they just trigger server events
    // The actual response comes via window message event
    return { status: 'callback_sent' };
  }).catch(error => {
    console.error('Error sending getUserList request:', error);
    addLogEntry('Failed to request user list: ' + error.message, 'error');
  });
}

function handleUserListResponse(data) {
  if (data.success) {
    userManagementData.users = data.users || [];
    userManagementData.currentUserRole = data.currentUserRole || 'guest';
    userManagementData.currentUserIdentifier = data.currentUserIdentifier;
    renderUserList();
    updateUserStats();
    updateUserManagementPermissions();
    addLogEntry('User list loaded successfully', 'success');
  } else {
    addLogEntry('Failed to load user list', 'error');
  }
}

function handleUserActionResponse(data) {
  if (data.success) {
    addLogEntry(data.message || 'Action completed successfully', 'success');
    // Refresh user list after successful action
    requestUserList();
  } else {
    addLogEntry(data.message || 'Action failed', 'error');
  }
}


function renderUserList(searchFilter = '') {
  const userListContent = document.getElementById('userListContent');
  if (!userListContent) return;

  const filteredUsers = userManagementData.users.filter(user => {
    if (!searchFilter) return true;
    return user.displayName.toLowerCase().includes(searchFilter) ||
      user.identifier.toLowerCase().includes(searchFilter) ||
      user.role.toLowerCase().includes(searchFilter);
  });

  if (filteredUsers.length === 0) {
    userListContent.innerHTML = '<div class="no-users-message">No users found</div>';
    return;
  }

  userListContent.innerHTML = '';

  filteredUsers.forEach(user => {
    const userItem = document.createElement('div');
    userItem.className = 'user-item';

    userItem.innerHTML = `
      <div class="user-info">
        <div class="user-name" title="${escapeHtml(user.displayName)}">${escapeHtml(user.displayName)}</div>
        <div class="user-identifier" title="${escapeHtml(user.identifier)}">${escapeHtml(user.identifier)}</div>
      </div>
      <div class="user-actions">
        <span class="user-role ${user.role}">${getRoleIcon(user.role)} ${user.role.toUpperCase()}</span>
        ${canModifyUser(user) ? `
          <button class="edit-user-btn" data-user-id="${user.identifier}" title="Edit User Details">
            <i class="fas fa-edit"></i>
          </button>
          <select class="role-select" data-user-id="${user.identifier}">
            <option value="mapper" ${user.role === 'mapper' ? 'selected' : ''}>🗺️ Mapper</option>
            <option value="admin" ${user.role === 'admin' ? 'selected' : ''}>⚙️ Admin</option>
            ${userManagementData.currentUserRole === 'owner' ? `<option value="owner" ${user.role === 'owner' ? 'selected' : ''}>👑 Owner</option>` : ''}
          </select>
          <button class="delete-user-btn" data-user-id="${user.identifier}" title="Delete User">
            <i class="fas fa-trash-alt"></i>
          </button>
        ` : ''}
      </div>
    `;

    userListContent.appendChild(userItem);
  });

  attachUserActionListeners();
}

function attachUserActionListeners() {
  const roleSelects = document.querySelectorAll('.role-select[data-user-id]');
  const deleteButtons = document.querySelectorAll('.delete-user-btn[data-user-id]');
  const editButtons = document.querySelectorAll('.edit-user-btn[data-user-id]');

  roleSelects.forEach(select => {
    select.addEventListener('change', (e) => {
      const userId = e.target.getAttribute('data-user-id');
      const newRole = e.target.value;
      updateUserRole(userId, newRole);
    });
  });

  deleteButtons.forEach(button => {
    button.addEventListener('click', (e) => {
      const userId = e.target.closest('button').getAttribute('data-user-id');
      deleteUser(userId);
    });
  });

  editButtons.forEach(button => {
    button.addEventListener('click', (e) => {
      const userId = e.target.closest('button').getAttribute('data-user-id');
      editUser(userId);
    });
  });
}

function editUser(identifier) {
  const user = userManagementData.users.find(u => u.identifier === identifier);
  if (!user) {
    addLogEntry('User not found', 'error');
    return;
  }

  showEditUserModal(user);
}

// Confirmation Dialog System
function showConfirmDialog(title, message, details, onConfirm, onCancel) {
  const overlay = document.getElementById('confirmDialog');
  const titleEl = document.getElementById('confirmDialogTitle');
  const messageEl = document.getElementById('confirmDialogMessage');
  const detailsEl = document.getElementById('confirmDialogDetails');
  const confirmBtn = document.getElementById('confirmDialogConfirm');
  const cancelBtn = document.getElementById('confirmDialogCancel');

  if (!overlay || !titleEl || !messageEl || !detailsEl || !confirmBtn || !cancelBtn) {
    console.error("Confirm dialog elements not found");
    return;
  }

  titleEl.textContent = title;
  messageEl.textContent = message;
  detailsEl.innerHTML = details || '';

  // Remove old event listeners by replacing elements
  const newConfirmBtn = confirmBtn.cloneNode(true);
  const newCancelBtn = cancelBtn.cloneNode(true);
  confirmBtn.parentNode.replaceChild(newConfirmBtn, confirmBtn);
  cancelBtn.parentNode.replaceChild(newCancelBtn, cancelBtn);

  // Style confirm button based on action type
  if (title.includes('🗑️') || title.toLowerCase().includes('delete')) {
    newConfirmBtn.style.background = '#ef4444';
    newConfirmBtn.innerHTML = '<i class="fas fa-trash"></i> Delete All';
  } else if (title.includes('🏷️') || title.toLowerCase().includes('rename')) {
    newConfirmBtn.style.background = '#3b82f6';
    newConfirmBtn.innerHTML = '<i class="fas fa-save"></i> Save Name';
  } else if (title.includes('✏️') || title.toLowerCase().includes('edit')) {
    newConfirmBtn.style.background = '#f59e0b';
    newConfirmBtn.innerHTML = '<i class="fas fa-save"></i> Update User';
  } else {
    newConfirmBtn.style.background = '#22c55e';
    newConfirmBtn.innerHTML = '<i class="fas fa-check"></i> Confirm';
  }

  // Add new event listeners
  newConfirmBtn.addEventListener('click', () => {
    hideConfirmDialog();
    if (onConfirm) onConfirm();
  });

  newCancelBtn.addEventListener('click', () => {
    hideConfirmDialog();
    if (onCancel) onCancel();
  });

  // Show dialog
  overlay.style.display = 'flex';
  document.body.classList.add('modal-open');
}

function hideConfirmDialog() {
  const overlay = document.getElementById('confirmDialog');
  if (overlay) {
    overlay.style.display = 'none';
    document.body.classList.remove('modal-open');
  }
}

function showEditUserModal(user) {
  const title = '✏️ Edit User';
  const message = `Update user details for ${user.displayName}:`;
  const details = `
    <div style="margin-top: 16px;">
      <div style="margin-bottom: 12px;">
        <strong>Current User:</strong> <span style="color: #22c55e;">${escapeHtml(user.displayName)}</span>
      </div>
      <div style="margin-bottom: 12px;">
        <label style="display: block; margin-bottom: 4px; color: #e2e8f0; font-weight: 500;">Display Name:</label>
        <input type="text" id="editUserDisplayName" 
               style="width: 100%; padding: 8px 12px; border: 2px solid #374151; border-radius: 6px; 
                      background: #1f2937; color: #f1f5f9; font-size: 14px;"
               value="${escapeHtml(user.displayName)}" placeholder="Enter display name..." maxlength="30">
      </div>
      <div style="margin-bottom: 12px;">
        <label style="display: block; margin-bottom: 4px; color: #e2e8f0; font-weight: 500;">User Identifier:</label>
        <input type="text" id="editUserIdentifier" 
               style="width: 100%; padding: 8px 12px; border: 2px solid #374151; border-radius: 6px; 
                      background: #1f2937; color: #f1f5f9; font-size: 14px;"
               value="${escapeHtml(user.identifier)}" placeholder="Steam/License/FiveM ID..." maxlength="100">
      </div>
      <div style="margin-bottom: 12px;">
        <label style="display: block; margin-bottom: 4px; color: #e2e8f0; font-weight: 500;">Role:</label>
        <select id="editUserRole" 
                style="width: 100%; padding: 8px 12px; border: 2px solid #374151; border-radius: 6px; 
                       background: #1f2937; color: #f1f5f9; font-size: 14px;">
          <option value="mapper" ${user.role === 'mapper' ? 'selected' : ''}>🗺️ Mapper</option>
          <option value="admin" ${user.role === 'admin' ? 'selected' : ''}>⚙️ Admin</option>
          ${userManagementData.currentUserRole === 'owner' ? `<option value="owner" ${user.role === 'owner' ? 'selected' : ''}>👑 Owner</option>` : ''}
        </select>
      </div>
      <div style="color: #94a3b8; font-size: 12px;">
        💡 Tip: Be careful when changing identifiers as it affects user authentication
      </div>
    </div>
  `;

  showConfirmDialog(
    title,
    message,
    details,
    () => executeUserEdit(user), // onConfirm
    () => { } // onCancel (do nothing)
  );

  // Focus the display name field after modal opens
  setTimeout(() => {
    const input = document.getElementById('editUserDisplayName');
    if (input) {
      input.focus();
      input.select();
    }
  }, 100);
}

function executeUserEdit(originalUser) {
  const displayNameInput = document.getElementById('editUserDisplayName');
  const identifierInput = document.getElementById('editUserIdentifier');
  const roleSelect = document.getElementById('editUserRole');

  const newDisplayName = displayNameInput ? displayNameInput.value.trim() : '';
  const newIdentifier = identifierInput ? identifierInput.value.trim() : '';
  const newRole = roleSelect ? roleSelect.value : '';

  // Validation
  if (!newDisplayName) {
    addLogEntry('Display name cannot be empty', 'error');
    return;
  }

  if (!newIdentifier) {
    addLogEntry('User identifier cannot be empty', 'error');
    return;
  }

  if (!newRole) {
    addLogEntry('Please select a role', 'error');
    return;
  }

  // Check if anything actually changed
  if (newDisplayName === originalUser.displayName &&
    newIdentifier === originalUser.identifier &&
    newRole === originalUser.role) {
    addLogEntry('No changes made to user', 'info');
    return;
  }

  // Check if new identifier already exists (if changed)
  if (newIdentifier !== originalUser.identifier) {
    const existingUser = userManagementData.users.find(u => u.identifier === newIdentifier);
    if (existingUser) {
      addLogEntry('A user with this identifier already exists', 'error');
      return;
    }
  }

  addLogEntry(`Updating user: ${originalUser.displayName} → ${newDisplayName}`, 'info');

  // Send update request to client
  fetch('https://bazq-os/updateUser', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      originalIdentifier: originalUser.identifier,
      newDisplayName: newDisplayName,
      newIdentifier: newIdentifier,
      newRole: newRole
    })
  }).then(response => response.json()).then(result => {
    if (result.success) {
      addLogEntry(`✅ User updated successfully`, 'success');

      // Update local cache
      const userIndex = userManagementData.users.findIndex(u => u.identifier === originalUser.identifier);
      if (userIndex !== -1) {
        userManagementData.users[userIndex] = {
          ...userManagementData.users[userIndex],
          displayName: newDisplayName,
          identifier: newIdentifier,
          role: newRole
        };
      }

      // Refresh the user list
      renderUserList();
      updateUserStats();
    } else {
      addLogEntry(`Failed to update user: ${result.message || 'Unknown error'}`, 'error');
    }
  }).catch(error => {
    console.error("Error updating user:", error);
    addLogEntry(`Failed to update user: ${error.message}`, 'error');
  });
}

function updateUserRole(identifier, newRole) {
  const user = userManagementData.users.find(u => u.identifier === identifier);
  if (!user) return;

  if (!canModifyUser(user)) {
    addLogEntry('You do not have permission to modify this user', 'error');
    return;
  }

  addLogEntry(`Updating ${user.displayName} role to ${newRole}`, 'info');

  fetch('https://bazq-os/updateUserRole', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      identifier: identifier,
      newRole: newRole
    })
  }).then(response => {
    // Response will come via window message
    return { status: 'callback_sent' };
  }).catch(error => {
    console.error('Error sending update user role request:', error);
    addLogEntry('Failed to send update user role request: ' + error.message, 'error');
  });
}

function deleteUser(identifier) {
  const user = userManagementData.users.find(u => u.identifier === identifier);
  if (!user) return;

  if (!canModifyUser(user)) {
    addLogEntry('You do not have permission to delete this user', 'error');
    return;
  }

  // Use custom confirm dialog instead of native confirm
  showConfirmDialog(
    'Delete User',
    `Are you sure you want to delete user "${user.displayName}"?`,
    'This action cannot be undone and will permanently remove the user from the system.',
    () => {
      // On confirm - execute deletion
      addLogEntry(`Deleting user: ${user.displayName}`, 'info');

      fetch('https://bazq-os/deleteUser', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          identifier: identifier
        })
      }).then(response => {
        // Response will come via window message
        return { status: 'callback_sent' };
      }).catch(error => {
        console.error('Error sending delete user request:', error);
        addLogEntry('Failed to send delete user request: ' + error.message, 'error');
      });
    },
    () => {
      // On cancel - just log
      addLogEntry('User deletion cancelled', 'info');
    }
  );
}

function canModifyUser(targetUser) {
  const currentRole = userManagementData.currentUserRole;
  const targetRole = targetUser.role;

  // Prevent self-deletion to avoid lockout
  if (targetUser.identifier === userManagementData.currentUserIdentifier) {
    return false;
  }

  // Owners can delete/modify anyone (except themselves)
  if (currentRole === 'owner') {
    return true;
  }

  // Admins can only delete/modify mappers
  if (currentRole === 'admin') {
    return targetRole === 'mapper';
  }

  // Mappers cannot delete/modify anyone
  return false;
}

function updateUserStats() {
  const ownerCount = document.getElementById('ownerCount');
  const adminCount = document.getElementById('adminCount');
  const mapperCount = document.getElementById('mapperCount');

  const stats = userManagementData.users.reduce((acc, user) => {
    acc[user.role] = (acc[user.role] || 0) + 1;
    return acc;
  }, {});

  if (ownerCount) ownerCount.textContent = stats.owner || 0;
  if (adminCount) adminCount.textContent = stats.admin || 0;
  if (mapperCount) mapperCount.textContent = stats.mapper || 0;
}

function updateUserManagementPermissions() {
  const userManagementElements = document.querySelectorAll('#usersView input, #usersView select, #usersView button:not(.clear-search-btn)');
  const navUsersBtn = document.getElementById('navUsersBtn');

  const hasPermission = ['owner', 'admin'].includes(userManagementData.currentUserRole);

  // Always show navigation button - users should be able to see they don't have permission
  if (navUsersBtn) {
    navUsersBtn.style.display = 'flex';
  }

  // Enable/disable form elements based on permission
  userManagementElements.forEach(element => {
    element.disabled = !hasPermission;
    if (!hasPermission) {
      element.style.opacity = '0.5';
      element.style.cursor = 'not-allowed';
    } else {
      element.style.opacity = '1';
      element.style.cursor = 'pointer';
    }
  });

  // Show permission message if user doesn't have access
  if (!hasPermission) {
    const userListContent = document.getElementById('userListContent');
    if (userListContent && userManagementData.currentUserRole !== 'guest') {
      userListContent.innerHTML = `
        <div class="no-users-message">
          <i class="fas fa-lock"></i>
          <p>Access Denied</p>
          <p>You need Owner or Admin permissions to manage users.</p>
          <p>Your current role: <span class="user-role ${userManagementData.currentUserRole}">${getRoleIcon(userManagementData.currentUserRole)} ${userManagementData.currentUserRole.toUpperCase()}</span></p>
        </div>
      `;
    }
  }
}

function exportUsers() {
  const dataStr = JSON.stringify(userManagementData.users, null, 2);
  const dataUri = 'data:application/json;charset=utf-8,' + encodeURIComponent(dataStr);

  const exportFileDefaultName = `bazq-os-users-${new Date().toISOString().split('T')[0]}.json`;

  const linkElement = document.createElement('a');
  linkElement.setAttribute('href', dataUri);
  linkElement.setAttribute('download', exportFileDefaultName);
  linkElement.click();

  addLogEntry(`Exported ${userManagementData.users.length} users`, 'success');
}

function clearAllMappers() {
  const mapperCount = userManagementData.users.filter(u => u.role === 'mapper').length;

  if (mapperCount === 0) {
    addLogEntry('No mappers to clear', 'info');
    return;
  }

  // Use custom confirm dialog instead of native confirm
  showConfirmDialog(
    'Clear All Mappers',
    `Are you sure you want to remove all ${mapperCount} mapper(s)?`,
    'This action cannot be undone and will permanently remove all mapper users from the system.',
    () => {
      // On confirm - execute clearing
      addLogEntry(`Clearing all mappers (${mapperCount} users)...`, 'info');

      fetch('https://bazq-os/clearAllMappers', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
      }).then(response => {
        // Response will come via window message
        return { status: 'callback_sent' };
      }).catch(error => {
        console.error('Error sending clear mappers request:', error);
        addLogEntry('Failed to send clear mappers request: ' + error.message, 'error');
      });
    },
    () => {
      // On cancel - just log
      addLogEntry('Clear all mappers cancelled', 'info');
    }
  );
}

function refreshUserList() {
  addLogEntry('Refreshing user list...', 'info');
  requestUserList();
}

function getRoleIcon(role) {
  const icons = {
    'owner': '👑',
    'admin': '⚙️',
    'mapper': '🗺️'
  };
  return icons[role] || '👤';
}

function escapeHtml(text) {
  const map = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#039;'
  };
  return text.replace(/[&<>"']/g, function (m) { return map[m]; });
}

// Main application code
window.addEventListener("DOMContentLoaded", () => {
  const uiContainer = document.querySelector(".ui-container");
  let gPathConfig = { packages: {}, props: {} };
  let randomizerProps = [];

  // Navigation buttons and View Panels
  const navLibraryBtn = document.getElementById("navLibraryBtn");
  const navPathBtn = document.getElementById("navPathBtn");
  const navManualBtn = document.getElementById("navManualBtn");
  const navPlacedBtn = document.getElementById("navPlacedBtn");
  const navSettingsBtn = document.getElementById("navSettingsBtn");
  const navUsersBtn = document.getElementById("navUsersBtn");

  const setDayBtn = document.getElementById("setDayBtn");
  const freezeTimeBtn = document.getElementById("freezeTimeBtn");
  const freezeWeatherBtn = document.getElementById("freezeWeatherBtn");
  const freecamBtn = document.getElementById("freecamBtn");
  const cleanZoneBtn = document.getElementById("cleanZoneBtn");
  const libraryView = document.getElementById("libraryView");
  const pathCreatorView = document.getElementById("pathCreatorView");
  const manualSpawnerView = document.getElementById("manualSpawnerView");
  const placedObjectsView = document.getElementById("placedObjectsView");
  const settingsView = document.getElementById("settingsView");
  const usersView = document.getElementById("usersView");
  const navButtons = [navLibraryBtn, navPathBtn, navManualBtn, navPlacedBtn, navSettingsBtn, navUsersBtn];
  const viewPanels = [libraryView, pathCreatorView, manualSpawnerView, placedObjectsView, settingsView, usersView];

  // Object library variables
  let allMasterItems = [];
  let allObjects = [];
  let localSpawnedObjectsCache = [];
  let filteredSpawnedObjectsCache = [];

  // Add variable to track selected object
  let selectedObjectIndex = null;

  // Filter state management
  let currentFilter = 'all';

  // --- NEW SETTINGS LOGIC (Inserted) ---
  const blueThemeCheckbox = document.getElementById("blueThemeCheckbox");
  const lowPerformanceCheckbox = document.getElementById("lowPerformanceCheckbox");
  const disableLibraryCheckbox = document.getElementById("disableLibraryCheckbox");

  function loadSavedSettings() {
    debugLog("Loading saved settings...");
    // Load Blue Theme
    const blueTheme = localStorage.getItem("bazq-os-blueTheme") === "true";
    if (blueTheme) {
      document.body.classList.add("theme-blue");
      if (blueThemeCheckbox) blueThemeCheckbox.checked = true;
    }

    // Load Low Performance
    const lowPerf = localStorage.getItem("bazq-os-lowPerformance") === "true";
    if (lowPerf) {
      document.body.classList.add("low-effects");
      if (lowPerformanceCheckbox) lowPerformanceCheckbox.checked = true;
    }

    // Load Disable Library
    const disableLib = localStorage.getItem("bazq-os-disableLibrary") === "true";
    if (disableLib) {
      document.body.classList.add("hide-library");
      if (disableLibraryCheckbox) disableLibraryCheckbox.checked = true;

      // Logic to switch view will be handled in showUI or similar if needed, 
      // or we just trust the user not to be on the hidden tab initially.
    }
  }

  // Helper to safely add listener
  function addSafeListener(element, event, handler) {
    if (element) {
      element.addEventListener(event, handler);
    } else {
      if (DEBUG_MODE) console.warn(`Element for setting not found (ID may be wrong)`);
    }
  }

  addSafeListener(blueThemeCheckbox, "change", (e) => {
    if (e.target.checked) {
      document.body.classList.add("theme-blue");
      localStorage.setItem("bazq-os-blueTheme", "true");
    } else {
      document.body.classList.remove("theme-blue");
      localStorage.setItem("bazq-os-blueTheme", "false");
    }
    addLogEntry(`Theme changed: ${e.target.checked ? "Blue" : "Default"}`, 'info');
  });

  addSafeListener(lowPerformanceCheckbox, "change", (e) => {
    if (e.target.checked) {
      document.body.classList.add("low-effects");
      localStorage.setItem("bazq-os-lowPerformance", "true");
    } else {
      document.body.classList.remove("low-effects");
      localStorage.setItem("bazq-os-lowPerformance", "false");
    }
    addLogEntry(`Performance mode: ${e.target.checked ? "Low Effects" : "Normal"}`, 'info');
  });

  addSafeListener(disableLibraryCheckbox, "change", (e) => {
    if (e.target.checked) {
      document.body.classList.add("hide-library");
      localStorage.setItem("bazq-os-disableLibrary", "true");
      // If currently on library view, switch to placed objects
      const libraryView = document.getElementById("libraryView");
      const navPlacedBtn = document.getElementById("navPlacedBtn");
      if (libraryView && libraryView.classList.contains("active-view")) {
        if (navPlacedBtn) navPlacedBtn.click();
      }
    } else {
      document.body.classList.remove("hide-library");
      localStorage.setItem("bazq-os-disableLibrary", "false");
    }
    addLogEntry(`Library visibility: ${e.target.checked ? "Hidden" : "Visible"}`, 'info');
  });

  // Auto-save for Keep Menu Open setting
  const keepMenuOpenCheckbox = document.getElementById('keepMenuOpenAfterPlace');
  addSafeListener(keepMenuOpenCheckbox, 'change', (e) => {
    const keepOpen = e.target.checked;
    localStorage.setItem('bazq_keepMenuOpen', keepOpen.toString());

    // Also sync with server
    fetch('https://bazq-os/saveUserSettings', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        keepMenuOpen: keepOpen
      })
    }).catch(error => { if (DEBUG_MODE) console.error("Error saving keepMenuOpen:", error); });

    addLogEntry(`Menu behavior: ${keepOpen ? "Stay Open" : "Auto-close"}`, 'info');
  });

  // Call load immediately
  loadSavedSettings();
  // -------------------------------------



  function switchView(targetView) {
    navButtons.forEach(btn => btn?.classList.remove("active-nav"));
    viewPanels.forEach(panel => panel?.classList.remove("active-view"));

    if (targetView === libraryView) navLibraryBtn?.classList.add("active-nav");
    else if (targetView === pathCreatorView) navPathBtn?.classList.add("active-nav");
    else if (targetView === manualSpawnerView) navManualBtn?.classList.add("active-nav");
    else if (targetView === placedObjectsView) navPlacedBtn?.classList.add("active-nav");
    else if (targetView === settingsView) navSettingsBtn?.classList.add("active-nav");
    else if (targetView === usersView) navUsersBtn?.classList.add("active-nav");

    if (targetView) targetView.classList.add("active-view");
  }

  function filterObjects(searchTerm = '', category = 'all') {
    let filteredObjects = allObjects;

    // Apply category filter first
    if (category !== 'all') {
      filteredObjects = filteredObjects.filter(objectModel => {
        return matchesCategory(objectModel, category);
      });
    }

    // Apply search filter if provided
    if (searchTerm && searchTerm.trim()) {
      const term = searchTerm.toLowerCase();
      filteredObjects = filteredObjects.filter(objectModel => {
        const displayName = objectModel.replace(/^bazq-/, '').replace(/_/g, ' ').toLowerCase();
        return objectModel.toLowerCase().includes(term) || displayName.includes(term);
      });
    }

    return filteredObjects;
  }

  function matchesCategory(objectModel, category) {
    const model = objectModel.toLowerCase();

    switch (category) {
      case 'tents':
        return model.includes('tent');
      case 'walls':
        return model.includes('wall') || model.includes('sur') && !model.includes('gate') && !model.includes('kapi');
      case 'towers':
        return model.includes('kule') || model.includes('tower');
      case 'gates':
        return model.includes('gate') || model.includes('kapi');
      case 'signs':
        return model.includes('sign');
      case 'decals':
        return model.includes('decal');
      case 'fences':
        return model.includes('fence');
      case 'poles':
        return model.includes('pole');
      case 'aircraft':
        return model.includes('crashed') || model.includes('plane') || model.includes('helicopter');
      default:
        return true;
    }
  }

  function handleObjectSearch() {
    const searchTerm = searchBar?.value || '';
    const filteredObjects = filterObjects(searchTerm, currentFilter);
    populateObjectList(filteredObjects);
    addLogEntry(`Search: "${searchTerm}" in ${currentFilter} - ${filteredObjects.length} results`, 'info');
  }

  function handleFilterClick(filterType) {
    // Update filter state
    currentFilter = filterType;

    // Update filter button styles
    document.querySelectorAll('.filter-btn').forEach(btn => {
      btn.classList.remove('active-filter');
    });

    const activeBtn = document.getElementById(`filter${filterType.charAt(0).toUpperCase() + filterType.slice(1)}`);
    if (activeBtn) {
      activeBtn.classList.add('active-filter');
    }

    // Apply the filter
    const searchTerm = searchBar?.value || '';
    const filteredObjects = filterObjects(searchTerm, filterType);
    populateObjectList(filteredObjects);

    const categoryName = filterType === 'all' ? 'All Objects' : filterType.charAt(0).toUpperCase() + filterType.slice(1);
    addLogEntry(`Filter: ${categoryName} - ${filteredObjects.length} objects`, 'info');
  }

  // Initialize filter button event listeners
  function initializeFilterButtons() {
    const filterButtons = [
      { id: 'filterAll', type: 'all' },
      { id: 'filterTents', type: 'tents' },
      { id: 'filterWalls', type: 'walls' },
      { id: 'filterTowers', type: 'towers' },
      { id: 'filterGates', type: 'gates' },
      { id: 'filterSigns', type: 'signs' },
      { id: 'filterDecals', type: 'decals' },
      { id: 'filterFences', type: 'fences' },
      { id: 'filterPoles', type: 'poles' },
      { id: 'filterAircraft', type: 'aircraft' }
    ];

    filterButtons.forEach(({ id, type }) => {
      const button = document.getElementById(id);
      if (button) {
        button.addEventListener('click', () => handleFilterClick(type));
      }
    });
  }

  // Search functionality
  const searchBar = document.getElementById('searchBar');
  const placedSearchBar = document.getElementById('placedSearchBar');

  if (searchBar) {
    searchBar.addEventListener('input', handleObjectSearch);
  }

  if (placedSearchBar) {
    placedSearchBar.addEventListener('input', (e) => {
      // This will be handled by the existing placed objects search functionality
      // For now, just log it
      const searchTerm = e.target.value;
      addLogEntry(`Searching placed objects: "${searchTerm}"`, 'info');
    });
  }

  // Navigation event listeners
  navLibraryBtn?.addEventListener("click", () => switchView(libraryView));
  navPathBtn?.addEventListener("click", () => switchView(pathCreatorView));
  navManualBtn?.addEventListener("click", () => switchView(manualSpawnerView));
  navPlacedBtn?.addEventListener("click", () => switchView(placedObjectsView));
  navSettingsBtn?.addEventListener("click", () => switchView(settingsView));

  if (navUsersBtn) {
    navUsersBtn.addEventListener("click", () => {
      switchView(usersView);
      // Initialize user management when view is opened
      if (typeof initializeUserManagement === 'function') {
        initializeUserManagement();
      }
    });
  }

  // Owner Lock Event Listener
  const lockNonOwnersCheckbox = document.getElementById("lockNonOwnersCheckbox");
  if (lockNonOwnersCheckbox) {
    lockNonOwnersCheckbox.addEventListener("change", (e) => {
      const locked = e.target.checked;
      fetch("https://bazq-os/saveLockState", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ locked: locked })
      }).catch(err => { if (DEBUG_MODE) console.error("Error saving lock state:", err); });
      addLogEntry(`Spawner lock: ${locked ? "Enabled" : "Disabled"}`, "info");
    });
  }

  // Path Creator UI event listeners
  const pathPropSelect = document.getElementById("pathPropSelect");
  const pathCustomModelGroup = document.getElementById("pathCustomModelGroup");
  const startPathDrawingBtn = document.getElementById("startPathDrawingBtn");

  // --- PACKAGE WEIGHT CUSTOMIZER ---
  const defaultPackages = {
    "wall_pack_1": [
      { model: "bazq-sur1", weight: 40, width: 10.0 },
      { model: "bazq-sur2", weight: 15, width: 10.0 },
      { model: "bazq-sur3", weight: 15, width: 10.0 },
      { model: "bazq-sur4", weight: 15, width: 10.0 },
      { model: "bazq-sur5", weight: 15, width: 10.0 }
    ],
    "wall_pack_2": [
      { model: "bazq-wall2_wall1", weight: 40, width: 2.0 },
      { model: "bazq-wall2_wall2", weight: 15, width: 2.0 },
      { model: "bazq-wall2_wall3", weight: 15, width: 2.0 },
      { model: "bazq-wall2_wall4", weight: 15, width: 2.0 },
      { model: "bazq-wall2_wall5", weight: 15, width: 2.0 }
    ],
    "wall3": [
      { model: "bazq-wall3_log1", weight: 10, width: 0.30 },
      { model: "bazq-wall3_log2", weight: 10, width: 0.37 },
      { model: "bazq-wall3_log3", weight: 10, width: 0.40 },
      { model: "bazq-wall3_log4", weight: 10, width: 0.46 },
      { model: "bazq-wall3_log5", weight: 10, width: 0.50 },
      { model: "bazq-wall3_wall1", weight: 15, width: 1.98 },
      { model: "bazq-wall3_wall2", weight: 15, width: 1.95 },
      { model: "bazq-wall3_wall3", weight: 20, width: 2.01 }
    ]
  };

  const packageWeightsGroup = document.getElementById("packageWeightsGroup");
  
  // Live sync path configuration options with client script during drawing mode
  function sendUpdatedOptions() {
    const snapToGround = document.getElementById("pathSnapToGround")?.checked;
    const alignToGround = document.getElementById("pathAlignToGround")?.checked;
    const randomRotation = document.getElementById("pathRandomRotation")?.checked;
    const cornerTowers = document.getElementById("pathCornerTowers")?.checked;
    const cornerAngle = parseFloat(document.getElementById("pathCornerAngle")?.value || "90.0");
    const enableDecals = document.getElementById("pathEnableDecals")?.checked;
    const decalFrequency = parseInt(document.getElementById("pathDecalFrequency")?.value || "20");
    const axisLock = document.getElementById("pathAxisLock")?.checked;
    const overlapMargin = parseFloat(document.getElementById("pathOverlapMargin")?.value ?? "0.02");
    
    const activeDecals = [];
    document.querySelectorAll(".decal-badge.active").forEach(btn => {
      const decalId = btn.getAttribute("data-decal");
      activeDecals.push(`bazq-wall2_walldecal${decalId}`);
    });

    fetch("https://bazq-os/updateDrawingOptions", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        snapToGround: !!snapToGround,
        alignToGround: !!alignToGround,
        randomRotation: !!randomRotation,
        cornerTowers: !!cornerTowers,
        cornerAngle: cornerAngle,
        enableDecals: !!enableDecals,
        decalFrequency: decalFrequency,
        activeDecals: activeDecals,
        axisLock: !!axisLock,
        overlapMargin: isNaN(overlapMargin) ? 0.02 : Math.max(0, overlapMargin)
      })
    }).catch(err => {
      // Ignore network errors when not drawing
    });
  }

  // Bind change/input event listeners for real-time synchronization
  setTimeout(() => {
    ["pathSnapToGround", "pathAlignToGround", "pathRandomRotation", "pathCornerTowers", "pathCornerAngle", "pathEnableDecals", "pathDecalFrequency", "pathAxisLock", "pathOverlapMargin"].forEach(id => {
      const el = document.getElementById(id);
      if (el) {
        el.addEventListener("change", sendUpdatedOptions);
        el.addEventListener("input", sendUpdatedOptions);
      }
    });

    // Bind click listeners to decal badges to sync their state
    document.querySelectorAll(".decal-badge").forEach(btn => {
      btn.addEventListener("click", () => {
        setTimeout(sendUpdatedOptions, 10);
      });
    });
  }, 100);

  const packageWeightsInputs = document.getElementById("packageWeightsInputs");
  const packageWeightsTotal = document.getElementById("packageWeightsTotal");
  const packageWeightsStatus = document.getElementById("packageWeightsStatus");
  const packageWeightsTotalBanner = document.getElementById("packageWeightsTotalBanner");

  let currentPackageProps = [];

  function updatePackageWeightsUI(selectedValue) {
    if (!packageWeightsGroup || !packageWeightsInputs) return;

    let pkgKey = selectedValue;
    if (selectedValue === "bazq-wall3") {
      pkgKey = "wall3";
    }

    if (defaultPackages[pkgKey]) {
      packageWeightsGroup.style.display = "block";
      currentPackageProps = JSON.parse(JSON.stringify(defaultPackages[pkgKey])); // Deep copy
      renderPackageWeights();
    } else {
      packageWeightsGroup.style.display = "none";
      currentPackageProps = [];
    }
  }

  function renderPackageWeights() {
    packageWeightsInputs.innerHTML = "";
    currentPackageProps.forEach((prop, index) => {
      const itemDiv = document.createElement("div");
      itemDiv.style.cssText = "display: flex; justify-content: space-between; align-items: center; gap: 10px; margin-bottom: 6px;";

      const label = document.createElement("label");
      label.textContent = prop.model.replace("bazq-", "");
      label.style.cssText = "font-size: 13px; color: #ccc; flex: 1.5; text-overflow: ellipsis; overflow: hidden; white-space: nowrap; margin-bottom: 0;";

      const input = document.createElement("input");
      input.type = "number";
      input.value = prop.weight;
      input.min = "0";
      input.max = "100";
      input.style.cssText = "width: 55px; background: rgba(5, 25, 3, 0.6); border: 1px solid rgba(var(--primary-rgb), 0.8); color: white; border-radius: 4px; padding: 4px; text-align: center; font-size: 12px;";

      input.addEventListener("input", (e) => {
        let val = parseInt(e.target.value) || 0;
        if (val < 0) val = 0;
        if (val > 100) val = 100;
        prop.weight = val;
        recalculatePackageTotal();
      });

      itemDiv.appendChild(label);
      itemDiv.appendChild(input);
      packageWeightsInputs.appendChild(itemDiv);
    });

    recalculatePackageTotal();
  }

  function recalculatePackageTotal() {
    if (!packageWeightsTotal || !packageWeightsStatus || !packageWeightsTotalBanner) return;
    let total = 0;
    currentPackageProps.forEach(prop => total += prop.weight);
    packageWeightsTotal.textContent = total;

    if (total === 100) {
      packageWeightsTotalBanner.style.color = "#22c55e"; // green
      packageWeightsStatus.textContent = "Valid";
      packageWeightsStatus.style.color = "#22c55e";
    } else {
      packageWeightsTotalBanner.style.color = "#ef4444"; // red
      packageWeightsStatus.textContent = "Must equal 100%";
      packageWeightsStatus.style.color = "#ef4444";
    }
  }

  function updateDecalsVisibility(selectedValue) {
    const pathDecalsGroup = document.getElementById("pathDecalsGroup");
    if (!pathDecalsGroup) return;
    const isConcrete = (selectedValue === "wall_pack_2" || selectedValue.startsWith("bazq-wall2_wall"));
    pathDecalsGroup.style.display = isConcrete ? "block" : "none";
  }

  if (pathPropSelect && pathCustomModelGroup) {
    pathPropSelect.addEventListener("change", (e) => {
      if (e.target.value === "custom") {
        pathCustomModelGroup.style.display = "block";
      } else {
        pathCustomModelGroup.style.display = "none";
      }
      updatePackageWeightsUI(e.target.value);
      updateDecalsVisibility(e.target.value);
    });
    // Call initially to hide/show on load
    updateDecalsVisibility(pathPropSelect.value);
  }

  // --- NEW RANDOMIZER LOGIC ---
  const pathModeRadios = document.querySelectorAll('input[name="pathMode"]');
  const pathSingleGroup = document.getElementById("pathSingleGroup");
  const pathMultiGroup = document.getElementById("pathMultiGroup");
  const addMultiPropBtn = document.getElementById("addMultiPropBtn");
  const multiPropModel = document.getElementById("multiPropModel");
  const multiPropDensity = document.getElementById("multiPropDensity");
  const multiPropWidth = document.getElementById("multiPropWidth");

  function renderMultiPropList() {
    const listContainer = document.getElementById("multiPropList");
    if (!listContainer) return;
    
    if (randomizerProps.length === 0) {
      listContainer.innerHTML = '<div style="text-align:center; color:#94a3b8; padding: 10px; font-size:12px;">No props added yet</div>';
      updateWeightBanner();
      return;
    }
    
    listContainer.innerHTML = "";
    randomizerProps.forEach((prop, index) => {
      const row = document.createElement("div");
      row.style.cssText = "display: flex; justify-content: space-between; align-items: center; padding: 6px 10px; margin-bottom: 4px; background: rgba(255, 255, 255, 0.05); border-radius: 6px; border: 1px solid rgba(255, 255, 255, 0.08); font-size: 13px;";
      row.innerHTML = `
        <div style="display: flex; flex-direction: column; gap: 2px; flex: 1;">
          <span style="color: #fff; font-weight: 500; font-family: monospace;">${escapeHtml(prop.model)}</span>
          <span style="color: #94a3b8; font-size: 11px;">Width: ${prop.width}m | Weight: ${prop.weight}%</span>
        </div>
        <button class="remove-prop-btn" data-index="${index}" style="background: none; border: none; color: #ef4444; cursor: pointer; padding: 4px 8px; font-size: 13px;"><i class="fas fa-trash-alt"></i></button>
      `;
      listContainer.appendChild(row);
    });
    
    listContainer.querySelectorAll(".remove-prop-btn").forEach(btn => {
      btn.addEventListener("click", (e) => {
        const idx = parseInt(e.currentTarget.getAttribute("data-index"));
        randomizerProps.splice(idx, 1);
        renderMultiPropList();
      });
    });
    
    updateWeightBanner();
  }

  function updateWeightBanner() {
    const totalWeightEl = document.getElementById("multiPropTotalWeight");
    const statusEl = document.getElementById("multiPropWeightStatus");
    const totalBanner = document.getElementById("multiPropTotalBanner");
    
    let totalWeight = 0;
    randomizerProps.forEach(p => {
      totalWeight += p.weight;
    });
    
    if (totalWeightEl) totalWeightEl.textContent = totalWeight;
    
    const pathMode = document.querySelector('input[name="pathMode"]:checked')?.value || "single";
    
    if (pathMode === "multi") {
      if (totalWeight === 100) {
        if (statusEl) {
          statusEl.textContent = "Ready";
          statusEl.style.color = "#22c55e";
        }
        if (totalBanner) totalBanner.style.color = "#22c55e";
        if (startPathDrawingBtn) startPathDrawingBtn.disabled = false;
      } else {
        if (statusEl) {
          statusEl.textContent = "Must equal 100%";
          statusEl.style.color = "#ef4444";
        }
        if (totalBanner) totalBanner.style.color = "#ef4444";
        if (startPathDrawingBtn) startPathDrawingBtn.disabled = true;
      }
    } else {
      if (startPathDrawingBtn) startPathDrawingBtn.disabled = false;
    }
  }

  if (pathModeRadios) {
    pathModeRadios.forEach(radio => {
      radio.addEventListener("change", (e) => {
        const mode = e.target.value;
        if (mode === "single") {
          if (pathSingleGroup) pathSingleGroup.style.display = "block";
          if (pathMultiGroup) pathMultiGroup.style.display = "none";
          updateWeightBanner();
        } else {
          if (pathSingleGroup) pathSingleGroup.style.display = "none";
          if (pathMultiGroup) pathMultiGroup.style.display = "block";
          updateWeightBanner();
        }
      });
    });
  }

  if (multiPropModel && multiPropWidth) {
    multiPropModel.addEventListener("input", (e) => {
      const val = e.target.value.trim().toLowerCase();
      if (gPathConfig && gPathConfig.props) {
        let matchedWidth = null;
        for (const [propName, width] of Object.entries(gPathConfig.props)) {
          if (propName.toLowerCase() === val) {
            matchedWidth = width;
            break;
          }
        }
        if (matchedWidth !== null) {
          multiPropWidth.value = matchedWidth;
        }
      }
    });
  }

  if (addMultiPropBtn) {
    addMultiPropBtn.addEventListener("click", () => {
      const model = multiPropModel ? multiPropModel.value.trim() : "";
      const weight = multiPropDensity ? parseInt(multiPropDensity.value) : 0;
      const width = multiPropWidth ? parseFloat(multiPropWidth.value) : 0;
      
      if (!model) {
        addLogEntry("Please enter a model name", "error");
        return;
      }
      if (isNaN(weight) || weight <= 0 || weight > 100) {
        addLogEntry("Weight must be between 1 and 100", "error");
        return;
      }
      if (isNaN(width) || width <= 0) {
        addLogEntry("Width must be greater than 0", "error");
        return;
      }
      
      let currentWeight = 0;
      randomizerProps.forEach(p => currentWeight += p.weight);
      if (currentWeight + weight > 100) {
        addLogEntry(`Adding this prop would exceed 100% total weight (current: ${currentWeight}%, requested: ${weight}%)`, "error");
        return;
      }
      
      randomizerProps.push({
        model: model,
        weight: weight,
        width: width
      });
      
      if (multiPropModel) multiPropModel.value = "";
      if (multiPropDensity) multiPropDensity.value = "";
      if (multiPropWidth) multiPropWidth.value = "";
      
      renderMultiPropList();
      addLogEntry(`Added ${model} to randomizer (${weight}%, ${width}m)`, "info");
    });
  }

  // Decal Badge Toggles
  document.querySelectorAll(".decal-badge").forEach(btn => {
    btn.addEventListener("click", () => {
      btn.classList.toggle("active");
    });
  });

  if (startPathDrawingBtn) {
    startPathDrawingBtn.addEventListener("click", () => {
      const pathMode = document.querySelector('input[name="pathMode"]:checked')?.value || "single";
      const snapToGround = document.getElementById("pathSnapToGround")?.checked;
      const alignToGround = document.getElementById("pathAlignToGround")?.checked;
      const randomRotation = document.getElementById("pathRandomRotation")?.checked;
      const cornerTowers = document.getElementById("pathCornerTowers")?.checked;
      const cornerAngle = parseFloat(document.getElementById("pathCornerAngle")?.value || "90.0");
      const enableDecals = document.getElementById("pathEnableDecals")?.checked;
      const decalFrequency = parseInt(document.getElementById("pathDecalFrequency")?.value || "20");
      const axisLock = document.getElementById("pathAxisLock")?.checked;
      const overlapMarginRaw = parseFloat(document.getElementById("pathOverlapMargin")?.value ?? "0.02");
      const overlapMargin = isNaN(overlapMarginRaw) ? 0.02 : Math.max(0, overlapMarginRaw);
      
      const activeDecals = [];
      document.querySelectorAll(".decal-badge.active").forEach(btn => {
        const decalId = btn.getAttribute("data-decal");
        activeDecals.push(`bazq-wall2_walldecal${decalId}`);
      });
      
      if (pathMode === "single") {
        let model = pathPropSelect ? pathPropSelect.value : "";
        let width = 1.0;
        let customPackageProps = [];
        
        let pkgKey = model;
        if (model === "bazq-wall3") pkgKey = "wall3";
        
        if (defaultPackages[pkgKey]) {
          let total = 0;
          currentPackageProps.forEach(p => total += p.weight);
          if (total !== 100) {
            addLogEntry("Total package weight must equal exactly 100% to draw", "error");
            return;
          }
          customPackageProps = currentPackageProps;
        }
        
        if (model === "custom") {
          const customModelInput = document.getElementById("pathCustomModelInput");
          const customModelWidth = document.getElementById("pathCustomModelWidth");
          
          model = customModelInput ? customModelInput.value.trim() : "";
          width = customModelWidth ? parseFloat(customModelWidth.value) : 1.0;
          
          if (!model) {
            addLogEntry("Please enter a custom model name", "error");
            return;
          }
          if (isNaN(width) || width <= 0) {
            addLogEntry("Please enter a valid width", "error");
            return;
          }
        }
        
        addLogEntry(`Starting path drawing: ${model} (width: ${width}m)`, "info");
        
        hideUI();
        fetch("https://bazq-os/startPathDrawing", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            mode: "single",
            model: model,
            width: width,
            customPackageProps: customPackageProps,
            options: {
              snapToGround: !!snapToGround,
              alignToGround: !!alignToGround,
              randomRotation: !!randomRotation,
              cornerTowers: !!cornerTowers,
              cornerAngle: cornerAngle,
              enableDecals: !!enableDecals,
              decalFrequency: decalFrequency,
              activeDecals: activeDecals,
              axisLock: !!axisLock,
              overlapMargin: overlapMargin
            }
          })
        });
      } else {
        let totalWeight = 0;
        randomizerProps.forEach(p => totalWeight += p.weight);
        if (totalWeight !== 100) {
          addLogEntry("Total weight must equal exactly 100% to draw", "error");
          return;
        }
        
        addLogEntry(`Starting path drawing with randomizer (${randomizerProps.length} props)`, "info");
        
        hideUI();
        fetch("https://bazq-os/startPathDrawing", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            mode: "multi",
            randomizerProps: randomizerProps,
            options: {
              snapToGround: !!snapToGround,
              alignToGround: !!alignToGround,
              randomRotation: !!randomRotation,
              cornerTowers: !!cornerTowers,
              cornerAngle: cornerAngle,
              enableDecals: !!enableDecals,
              decalFrequency: decalFrequency,
              activeDecals: activeDecals,
              axisLock: !!axisLock,
              overlapMargin: overlapMargin
            }
          })
        });
      }
    });
  }

  // 📐 BLUEPRINT EDITOR STATE & HANDLERS
  let currentBlueprintData = null;
  let currentBlueprintSegments = [];
  let selectedBlueprintIndex = 1;
  let availableReplacements = [];

  function updateBlueprintUI(data) {
    currentBlueprintData = data;
    currentBlueprintSegments = data.segments || [];
    selectedBlueprintIndex = data.selectedIndex || 1;
    availableReplacements = data.replacements || [];

    const group = document.getElementById("blueprintControlsGroup");
    if (group) group.style.display = "block";

    const badge = document.getElementById("blueprintStatsBadge");
    if (badge && data.stats) badge.textContent = `${data.stats.totalSegments} Segments`;

    const placed = document.getElementById("blueprintPlacedDist");
    if (placed && data.stats) placed.textContent = data.stats.placedDist;

    const remainder = document.getElementById("blueprintRemainderDist");
    if (remainder && data.stats) remainder.textContent = data.stats.remainder;

    const total = document.getElementById("blueprintTotalDist");
    if (total && data.stats) total.textContent = data.stats.totalDist;

    // Reset Confirm button state
    const confirmBtn = document.getElementById("blueprintConfirmBtn");
    if (confirmBtn) {
      confirmBtn.disabled = false;
      confirmBtn.textContent = "Confirm & Build (Enter)";
    }

    // Populate replacement dropdown
    const replaceSelect = document.getElementById("blueprintReplaceSelect");
    if (replaceSelect && availableReplacements.length > 0) {
      replaceSelect.innerHTML = "";
      availableReplacements.forEach(r => {
        const opt = document.createElement("option");
        opt.value = r.model;
        opt.textContent = r.name;
        replaceSelect.appendChild(opt);
      });
    }

    renderSelectedBlueprintSegment(selectedBlueprintIndex);
  }

  function renderSelectedBlueprintSegment(index) {
    selectedBlueprintIndex = index;
    const seg = currentBlueprintSegments.find(s => s.index === index);
    const indexSpan = document.getElementById("blueprintCurrentSegIndex");
    if (indexSpan) indexSpan.textContent = `#${index}`;

    if (!seg) return;

    const nameSpan = document.getElementById("blueprintSegModelName");
    if (nameSpan) {
      nameSpan.textContent = seg.isDeleted ? "[GAP / DELETED]" : seg.model;
    }

    const rangeSpan = document.getElementById("blueprintSegDistRange");
    if (rangeSpan) rangeSpan.textContent = `${seg.startDist} - ${seg.endDist}`;

    const statusSpan = document.getElementById("blueprintSegStatus");
    if (statusSpan) {
      if (seg.isDeleted) {
        statusSpan.textContent = "Deleted (Gap)";
        statusSpan.style.color = "#ef4444";
      } else if (seg.isOverride) {
        statusSpan.textContent = seg.isGate ? "Gate Assembly (Locked)" : "Manual Override (Locked)";
        statusSpan.style.color = "#fbbf24";
      } else {
        statusSpan.textContent = "Procedural";
        statusSpan.style.color = "#22c55e";
      }
    }

    const replaceSelect = document.getElementById("blueprintReplaceSelect");
    if (replaceSelect && !seg.isDeleted) {
      replaceSelect.value = seg.model;
    }
  }

  const blueprintRandomizeBtn = document.getElementById("blueprintRandomizeBtn");
  if (blueprintRandomizeBtn) {
    blueprintRandomizeBtn.addEventListener("click", () => {
      fetch("https://bazq-os/blueprintAction", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "randomize" })
      });
    });
  }

  const blueprintPrevSegBtn = document.getElementById("blueprintPrevSegBtn");
  if (blueprintPrevSegBtn) {
    blueprintPrevSegBtn.addEventListener("click", () => {
      if (currentBlueprintSegments.length === 0) return;
      let newIdx = selectedBlueprintIndex - 1;
      if (newIdx < 1) newIdx = currentBlueprintSegments.length;
      fetch("https://bazq-os/blueprintAction", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "selectSegment", index: newIdx })
      });
      renderSelectedBlueprintSegment(newIdx);
    });
  }

  const blueprintNextSegBtn = document.getElementById("blueprintNextSegBtn");
  if (blueprintNextSegBtn) {
    blueprintNextSegBtn.addEventListener("click", () => {
      if (currentBlueprintSegments.length === 0) return;
      let newIdx = selectedBlueprintIndex + 1;
      if (newIdx > currentBlueprintSegments.length) newIdx = 1;
      fetch("https://bazq-os/blueprintAction", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "selectSegment", index: newIdx })
      });
      renderSelectedBlueprintSegment(newIdx);
    });
  }

  const blueprintReplaceSelect = document.getElementById("blueprintReplaceSelect");
  if (blueprintReplaceSelect) {
    blueprintReplaceSelect.addEventListener("change", (e) => {
      fetch("https://bazq-os/blueprintAction", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "replaceSegment", index: selectedBlueprintIndex, model: e.target.value })
      });
    });
  }

  const blueprintFlipSegBtn = document.getElementById("blueprintFlipSegBtn");
  if (blueprintFlipSegBtn) {
    blueprintFlipSegBtn.addEventListener("click", () => {
      fetch("https://bazq-os/blueprintAction", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "flipSegment", index: selectedBlueprintIndex })
      });
    });
  }

  const blueprintDeleteSegBtn = document.getElementById("blueprintDeleteSegBtn");
  if (blueprintDeleteSegBtn) {
    blueprintDeleteSegBtn.addEventListener("click", () => {
      fetch("https://bazq-os/blueprintAction", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "deleteSegment", index: selectedBlueprintIndex })
      });
    });
  }

  const blueprintUnlockSegBtn = document.getElementById("blueprintUnlockSegBtn");
  if (blueprintUnlockSegBtn) {
    blueprintUnlockSegBtn.addEventListener("click", () => {
      fetch("https://bazq-os/blueprintAction", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "unlockSegment", index: selectedBlueprintIndex })
      });
    });
  }

  const blueprintConfirmBtn = document.getElementById("blueprintConfirmBtn");
  if (blueprintConfirmBtn) {
    blueprintConfirmBtn.addEventListener("click", () => {
      blueprintConfirmBtn.disabled = true;
      blueprintConfirmBtn.textContent = "Persisting...";
      fetch("https://bazq-os/blueprintAction", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "confirm" })
      });
    });
  }

  const blueprintCancelBtn = document.getElementById("blueprintCancelBtn");
  if (blueprintCancelBtn) {
    blueprintCancelBtn.addEventListener("click", () => {
      fetch("https://bazq-os/blueprintAction", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "cancel" })
      });
    });
  }

  // Basic library functionality
  function getPlacementOptions() {
    const now = new Date();
    const timeString = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    return {
      snapToGround: true,
      timestamp: timeString,
      playerName: "FromGame" // This will be overridden by the actual player name from Lua
    };
  }

  // Manual spawner functionality
  const manualPropInput = document.getElementById("manualPropInput");
  const spawnManualPropBtn = document.getElementById("spawnManualPropBtn");

  if (spawnManualPropBtn) {
    spawnManualPropBtn.addEventListener("click", () => {
      const propName = manualPropInput?.value.trim();
      if (propName) {
        addLogEntry(`Spawning manual prop: ${propName}`, 'info');
        const options = getPlacementOptions();
        fetch(`https://bazq-os/selectObject`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ model: propName, options: options }),
        });
      } else {
        addLogEntry('Please enter a prop name', 'error');
      }
    });
  }

  if (manualPropInput) {
    manualPropInput.addEventListener("keypress", (e) => {
      if (e.key === "Enter") {
        spawnManualPropBtn?.click();
      }
    });
  }

  // Initialize the app
  addLogEntry("Object spawner ready", 'info');

  // Load initial data from server
  fetch(`https://bazq-os/ready`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({}),
  });

  // UI visibility control
  let isUIVisible = false;

  function showUI() {
    if (uiContainer) {
      uiContainer.classList.add('visible');
      isUIVisible = true;
      document.body.classList.add('ui-visible');
    }
  }

  function hideUI() {
    if (uiContainer) {
      uiContainer.classList.remove('visible');
      isUIVisible = false;
      document.body.classList.remove('ui-visible');
    }
  }

  function toggleUI() {
    if (isUIVisible) {
      hideUI();
    } else {
      showUI();
    }
  }

  // Check initial UI state based on CSS classes
  function checkInitialUIState() {
    if (uiContainer) {
      isUIVisible = uiContainer.classList.contains('visible');
    }
  }

  // Close button functionality
  const closeUiBtn = document.getElementById("closeUiBtn");
  if (closeUiBtn) {
    closeUiBtn.addEventListener("click", () => {
      hideUI();
      fetch(`https://bazq-os/escapePressed`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({}),
      });
    });
  }

  // Keyboard event handlers
  document.addEventListener("keydown", (event) => {
    // ESC key to close menu
    if (event.key === "Escape" && isUIVisible) {
      event.preventDefault();
      hideUI();
      fetch(`https://bazq-os/escapePressed`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({}),
      });
      return;
    }

    // F6 key for freecam
    if (event.key === "F6") {
      event.preventDefault();
      if (freecamBtn) {
        freecamBtn.click();
      }
      return;
    }
  });

  // Action button event listeners

  if (setDayBtn) {
    setDayBtn.addEventListener("click", () => {
      addLogEntry("Setting sunny day...", 'info');
      fetch(`https://bazq-os/setDay`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({}),
      });
    });
  }

  if (cleanZoneBtn) {
    cleanZoneBtn.addEventListener("click", () => {
      addLogEntry("Cleaning zone (1000m radius)...", 'info');
      fetch(`https://bazq-os/cleanZone`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({}),
      });
    });
  }

  // Toggle buttons
  let timeIsFrozen = false;
  let weatherIsFrozen = false;
  let freecamIsActive = false;

  if (freezeTimeBtn) {
    freezeTimeBtn.addEventListener("click", () => {
      timeIsFrozen = !timeIsFrozen;
      const status = timeIsFrozen ? "Freezing" : "Unfreezing";
      addLogEntry(`${status} time...`, 'info');

      if (timeIsFrozen) {
        freezeTimeBtn.classList.add("active-toggle");
      } else {
        freezeTimeBtn.classList.remove("active-toggle");
      }

      fetch(`https://bazq-os/freezeTime`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ state: timeIsFrozen }),
      });
    });
  }

  if (freezeWeatherBtn) {
    freezeWeatherBtn.addEventListener("click", () => {
      weatherIsFrozen = !weatherIsFrozen;
      const status = weatherIsFrozen ? "Freezing" : "Unfreezing";
      addLogEntry(`${status} weather...`, 'info');

      if (weatherIsFrozen) {
        freezeWeatherBtn.classList.add("active-toggle");
      } else {
        freezeWeatherBtn.classList.remove("active-toggle");
      }

      fetch(`https://bazq-os/freezeWeather`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ state: weatherIsFrozen }),
      });
    });
  }

  if (freecamBtn) {
    freecamBtn.addEventListener("click", () => {
      freecamIsActive = !freecamIsActive;
      const status = freecamIsActive ? "Enabling" : "Disabling";
      addLogEntry(`${status} freecam...`, 'info');

      if (freecamIsActive) {
        freecamBtn.classList.add("active-toggle");
      } else {
        freecamBtn.classList.remove("active-toggle");
      }

      // Update freecam indicator visibility
      const freecamIndicator = document.getElementById("freecamIndicator");
      if (freecamIndicator) {
        if (freecamIsActive) {
          freecamIndicator.classList.add("visible");
        } else {
          freecamIndicator.classList.remove("visible");
        }
      }

      fetch(`https://bazq-os/toggleFreecam`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ state: freecamIsActive }),
      });

      // Close menu when freecam is enabled
      if (freecamIsActive) {
        hideUI();
        fetch(`https://bazq-os/escapePressed`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({}),
        });
      }
    });
  }

  // Freecam indicator button
  const freecamIndicatorBtn = document.getElementById("freecamIndicatorBtn");
  if (freecamIndicatorBtn) {
    freecamIndicatorBtn.addEventListener("click", () => {
      if (freecamBtn) {
        freecamBtn.click();
      }
    });
  }

  // Log clear button
  const clearLogBtn = document.getElementById("clearLogBtn");
  if (clearLogBtn) {
    clearLogBtn.addEventListener("click", () => {
      const logContent = document.getElementById("logContent");
      if (logContent) {
        logContent.innerHTML = '<div class="log-entry info"><span class="log-time">12:00</span><span class="log-message">Log cleared</span></div>';
      }
    });
  }

  // Help section collapsible functionality
  const helpHeader = document.getElementById("helpHeader");
  const helpContent = document.getElementById("helpContent");
  if (helpHeader && helpContent) {
    helpHeader.addEventListener("click", () => {
      const isExpanded = helpContent.classList.contains("expanded");
      const expandIcon = helpHeader.querySelector(".expand-icon");

      if (isExpanded) {
        helpContent.classList.remove("expanded");
        if (expandIcon) {
          expandIcon.style.transform = "rotate(-90deg)";
        }
        addLogEntry("Help section collapsed", 'info');
      } else {
        helpContent.classList.add("expanded");
        if (expandIcon) {
          expandIcon.style.transform = "rotate(0deg)";
        }
        addLogEntry("Help section expanded", 'info');
      }
    });
  }

  // Settings save button - removed duplicate, handled in initializePackageSelection

  // Helper functions for UI updates
  function populateObjectList(objects, storeAsAllObjects = false) {
    const uniqueObjects = Array.from(new Set(objects || []));
    const duplicateCount = (objects?.length || 0) - uniqueObjects.length;

    debugLog("Populating object list with", uniqueObjects.length, "unique objects");
    if (duplicateCount > 0) {
      addLogEntry(`Removed ${duplicateCount} duplicate objects from library data`, 'warning');
    }
    addLogEntry(`Loading ${uniqueObjects.length} objects into library...`, 'info');

    objects = uniqueObjects;

    // Store objects for search functionality if this is the initial load
    if (storeAsAllObjects) {
      allObjects = [...objects];
      // When loading new objects, reset filter to 'all' and apply it
      currentFilter = 'all';
      document.querySelectorAll('.filter-btn').forEach(btn => {
        btn.classList.remove('active-filter');
      });
      const allBtn = document.getElementById('filterAll');
      if (allBtn) {
        allBtn.classList.add('active-filter');
      }
      // Apply current search if any
      const searchTerm = searchBar?.value || '';
      if (searchTerm.trim()) {
        objects = filterObjects(searchTerm, currentFilter);
        debugLog("Applied search filter, now showing", objects.length, "objects");
      }
    }

    const objectListContainer = document.querySelector('.object-list');
    if (!objectListContainer) {
      if (DEBUG_MODE) console.error("Object list container not found!");
      return;
    }

    // Clear existing objects
    objectListContainer.innerHTML = '';

    if (!objects || objects.length === 0) {
      const noObjectsMessage = storeAsAllObjects ?
        'No objects available. Check your packages in Settings.' :
        `No objects match the current ${currentFilter === 'all' ? 'search' : 'filter'}. Try a different ${currentFilter === 'all' ? 'search term' : 'category'}.`;
      objectListContainer.innerHTML = `<div class="no-objects">${noObjectsMessage}</div>`;
      return;
    }

    // Create object items using existing CSS structure
    objects.forEach(objectModel => {
      const objectButton = document.createElement('button');
      objectButton.dataset.model = objectModel;

      const displayName = objectModel.replace(/^bazq-/, '').replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());

      // Create image element with fallback
      const imgElement = document.createElement('img');
      imgElement.src = `images/${objectModel}.png`;
      imgElement.alt = displayName;
      imgElement.className = 'object-preview-image';

      // Handle image load error
      imgElement.onerror = function () {
        this.style.display = 'none';
        // Create a text fallback
        const fallback = document.createElement('div');
        fallback.style.cssText = 'width: 42px; height: 42px; display: flex; align-items: center; justify-content: center; background: rgba(34, 197, 94, 0.2); border-radius: 8px; font-size: 20px; margin-bottom: 6px;';
        fallback.textContent = getModelIcon(objectModel);
        this.parentNode.insertBefore(fallback, this);
      };

      const spanElement = document.createElement('span');
      spanElement.textContent = displayName;

      objectButton.appendChild(imgElement);
      objectButton.appendChild(spanElement);

      // Add click event for spawning
      objectButton.addEventListener('click', (e) => {
        e.preventDefault();
        const model = e.currentTarget.dataset.model;
        spawnObject(model);
      });

      objectListContainer.appendChild(objectButton);
    });

    addLogEntry(`Library loaded with ${objects.length} objects`, 'success');
  }

  function spawnObject(model) {
    debugLog("Spawning object:", model);
    addLogEntry(`Spawning: ${model}`, 'info');

    fetch('https://bazq-os/selectObject', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: model,
        options: getPlacementOptions()
      })
    }).then(response => {
      debugLog("Spawn request sent for:", model);
    }).catch(error => {
      if (DEBUG_MODE) console.error("Error spawning object:", error);
      addLogEntry(`Failed to spawn ${model}: ${error.message}`, 'error');
    });
  }

  function populateSpawnedObjectsList(spawnedObjects) {
    debugLog("Updating spawned objects list with", spawnedObjects.length, "objects");
    addLogEntry(`Loading ${spawnedObjects.length} placed objects...`, 'info');

    // Update caches if this is a fresh data load
    if (spawnedObjects !== filteredSpawnedObjectsCache) {
      localSpawnedObjectsCache = [...spawnedObjects];
      filteredSpawnedObjectsCache = [...spawnedObjects];
    }

    // Performance Warning Check
    const warningEl = document.getElementById('performanceWarning');
    const warningText = document.getElementById('performanceWarningText');
    const warningThreshold = 500;

    if (spawnedObjects.length > warningThreshold) {
      if (warningEl) {
        warningEl.classList.remove('hidden');
        if (warningText) warningText.textContent = `Warning: High object count (${spawnedObjects.length} > ${warningThreshold}). Performance may degrade. Please convert to YMAP.`;
      }
    } else {
      if (warningEl) warningEl.classList.add('hidden');
    }

    const placedObjectsList = document.getElementById('placedObjectsList');
    if (!placedObjectsList) {
      if (DEBUG_MODE) console.error("Placed objects list container not found!");
      return;
    }

    // Clear existing objects
    placedObjectsList.innerHTML = '';

    if (!spawnedObjects || spawnedObjects.length === 0) {
      placedObjectsList.innerHTML = '<div class="no-objects">No objects have been placed yet.</div>';
      return;
    }

    // Grid layout for objects
    const objectsGrid = document.createElement('div');
    objectsGrid.className = 'objects-grid';

    spawnedObjects.forEach((obj, index) => {
      const objectItem = document.createElement('div');
      objectItem.className = 'object-grid-item';
      objectItem.dataset.index = obj.originalIndex;
      objectItem.dataset.id = obj.id || '';

      const icon = getModelIcon(obj.model);
      const displayName = obj.displayName || obj.model.replace(/^bazq-/, '').replace(/_/g, ' ');
      const shortName = displayName.length > 12 ? displayName.substring(0, 12) + '...' : displayName;

      objectItem.innerHTML = `
        <div class="grid-object-icon">${icon}</div>
        <div class="grid-object-info">
          <div class="grid-object-name" title="${displayName}">${shortName}</div>
          <div class="grid-object-meta">
            <span class="grid-object-player" title="Placed by ${obj.playerName || 'Unknown'}">${obj.playerName || 'Unknown'}</span>
            <span class="grid-object-time" title="Placed at ${obj.timestamp || 'Unknown'}">${obj.timestamp ? new Date(obj.timestamp > 1000000000000 ? obj.timestamp : obj.timestamp * 1000).toLocaleDateString('tr-TR') + ' ' + new Date(obj.timestamp > 1000000000000 ? obj.timestamp : obj.timestamp * 1000).toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' }) : '--/--/---- --:--'}</span>
          </div>
        </div>
        <div class="grid-object-actions">
          <button class="grid-action-btn teleport-btn" data-index="${obj.originalIndex}" data-id="${obj.id || ''}" title="Teleport to Object">
            <i class="fas fa-location-arrow"></i>
          </button>
          <button class="grid-action-btn rename-btn" data-index="${obj.originalIndex}" data-id="${obj.id || ''}" title="Rename">
            <i class="fas fa-tag"></i>
          </button>
          <button class="grid-action-btn edit-btn" data-index="${obj.originalIndex}" data-id="${obj.id || ''}" title="Edit">
            <i class="fas fa-edit"></i>
          </button>
          <button class="grid-action-btn duplicate-btn" data-index="${obj.originalIndex}" data-id="${obj.id || ''}" title="Duplicate">
            <i class="fas fa-copy"></i>
          </button>
          <button class="grid-action-btn delete-btn" data-index="${obj.originalIndex}" data-id="${obj.id || ''}" title="Delete">
            <i class="fas fa-trash"></i>
          </button>
        </div>
      `;

      // Add click handler for object selection
      objectItem.addEventListener('click', (e) => {
        if (!e.target.closest('.grid-object-actions')) {
          selectObject(obj.originalIndex, obj.id);
        }
      });

      // Add action button event listeners
      const teleportBtn = objectItem.querySelector('.teleport-btn');
      const renameBtn = objectItem.querySelector('.rename-btn');
      const editBtn = objectItem.querySelector('.edit-btn');
      const duplicateBtn = objectItem.querySelector('.duplicate-btn');
      const deleteBtn = objectItem.querySelector('.delete-btn');

      if (teleportBtn) {
        teleportBtn.addEventListener('click', (e) => {
          e.stopPropagation();
          const btn = e.target.closest('.teleport-btn');
          teleportToObject(btn.dataset.index, btn.dataset.id);
        });
      }

      if (renameBtn) {
        renameBtn.addEventListener('click', (e) => {
          e.stopPropagation();
          const btn = e.target.closest('.rename-btn');
          renamePlacedObject(btn.dataset.index, btn.dataset.id);
        });
      }

      if (editBtn) {
        editBtn.addEventListener('click', (e) => {
          e.stopPropagation();
          const btn = e.target.closest('.edit-btn');
          editPlacedObject(btn.dataset.index, btn.dataset.id);
        });
      }

      if (duplicateBtn) {
        duplicateBtn.addEventListener('click', (e) => {
          e.stopPropagation();
          const btn = e.target.closest('.duplicate-btn');
          duplicatePlacedObject(btn.dataset.index, btn.dataset.id);
        });
      }

      if (deleteBtn) {
        deleteBtn.addEventListener('click', (e) => {
          e.stopPropagation();
          const btn = e.target.closest('.delete-btn');
          deletePlacedObject(btn.dataset.index, btn.dataset.id);
        });
      }

      objectsGrid.appendChild(objectItem);
    });

    placedObjectsList.appendChild(objectsGrid);
  }

  // Select object function
  function selectObject(index, id) {
    if (!index && !id) return;

    // Send NUI callback to server
    fetch('https://bazq-os/selectObject', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ index: parseInt(index), id: id || undefined })
    }).then(() => {
      addLogEntry(`Selected object ${id || ('index ' + index)}`, 'info');
    }).catch(error => {
      if (DEBUG_MODE) console.error("Error selecting object:", error);
      addLogEntry(`Failed to select object: ${error.message}`, 'error');
    });
  }

  function getObjectBaseType(model) {
    if (model.includes('tent')) return 'Tents';
    if (model.includes('wall') || model.includes('sur')) return 'Walls';
    if (model.includes('gate') || model.includes('kapi')) return 'Gates';
    if (model.includes('kule') || model.includes('tower')) return 'Towers';
    if (model.includes('sign')) return 'Signs';
    if (model.includes('pole')) return 'Poles';
    if (model.includes('fence')) return 'Fences';
    if (model.includes('decal')) return 'Decals';
    if (model.includes('crashed') || model.includes('plane') || model.includes('helicopter')) return 'Aircraft';
    return 'Other';
  }

  function editPlacedObject(index, id) {
    addLogEntry(`Editing object ${id || ('index ' + index)}`, 'info');
    fetch('https://bazq-os/editSpawnedObject', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ index: parseInt(index), id: id || undefined })
    }).catch(error => {
      if (DEBUG_MODE) console.error("Error editing object:", error);
      addLogEntry(`Failed to edit object: ${error.message}`, 'error');
    });
  }

  function teleportToObject(index, id) {
    addLogEntry(`Teleporting to object ${id || ('index ' + index)}`, 'info');
    fetch('https://bazq-os/teleportToObject', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ index: parseInt(index), id: id || undefined })
    }).catch(error => {
      if (DEBUG_MODE) console.error("Error teleporting to object:", error);
      addLogEntry(`Failed to teleport: ${error.message}`, 'error');
    });
  }

  function duplicatePlacedObject(index, id) {
    addLogEntry(`Duplicating object ${id || ('index ' + index)}`, 'info');
    fetch('https://bazq-os/duplicateObject', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        index: parseInt(index),
        id: id || undefined,
        options: getPlacementOptions()
      })
    }).catch(error => {
      if (DEBUG_MODE) console.error("Error duplicating object:", error);
      addLogEntry(`Failed to duplicate object: ${error.message}`, 'error');
    });
  }

  function deletePlacedObject(index, id) {
    showConfirmDialog(
      'Delete Object',
      'Are you sure you want to delete this object?',
      'This action cannot be undone.',
      () => {
        addLogEntry(`Deleting object ${id || ('index ' + index)}`, 'info');
        fetch('https://bazq-os/deleteObject', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ index: parseInt(index), id: id || undefined })
        }).catch(error => {
          if (DEBUG_MODE) console.error("Error deleting object:", error);
          addLogEntry(`Failed to delete object: ${error.message}`, 'error');
        });
      }
    );
  }

  // Confirmation Dialog System
  function showConfirmDialog(title, message, details, onConfirm, onCancel) {
    const overlay = document.getElementById('confirmDialog');
    const titleEl = document.getElementById('confirmDialogTitle');
    const messageEl = document.getElementById('confirmDialogMessage');
    const detailsEl = document.getElementById('confirmDialogDetails');
    const confirmBtn = document.getElementById('confirmDialogConfirm');
    const cancelBtn = document.getElementById('confirmDialogCancel');

    titleEl.innerHTML = title; // Use innerHTML to support emojis
    messageEl.textContent = message;

    if (details) {
      detailsEl.innerHTML = `<i class="fas fa-exclamation-triangle"></i>${details}`;
      detailsEl.style.display = 'block';
    } else {
      detailsEl.style.display = 'none';
    }

    // Remove previous event listeners
    const newConfirmBtn = confirmBtn.cloneNode(true);
    const newCancelBtn = cancelBtn.cloneNode(true);
    confirmBtn.parentNode.replaceChild(newConfirmBtn, confirmBtn);
    cancelBtn.parentNode.replaceChild(newCancelBtn, cancelBtn);

    // Style confirm button based on action type
    if (title.includes('🗑️') || title.toLowerCase().includes('delete')) {
      newConfirmBtn.style.background = '#ef4444';
      newConfirmBtn.innerHTML = '<i class="fas fa-trash"></i> Delete All';
    } else if (title.includes('🏷️') || title.toLowerCase().includes('rename')) {
      newConfirmBtn.style.background = '#3b82f6';
      newConfirmBtn.innerHTML = '<i class="fas fa-save"></i> Save Name';
    } else if (title.includes('✏️') || title.toLowerCase().includes('edit')) {
      newConfirmBtn.style.background = '#f59e0b';
      newConfirmBtn.innerHTML = '<i class="fas fa-save"></i> Update User';
    } else {
      newConfirmBtn.style.background = '#22c55e';
      newConfirmBtn.innerHTML = '<i class="fas fa-check"></i> Confirm';
    }

    // Add new event listeners
    newConfirmBtn.addEventListener('click', () => {
      hideConfirmDialog();
      if (onConfirm) onConfirm();
    });

    newCancelBtn.addEventListener('click', () => {
      hideConfirmDialog();
      if (onCancel) onCancel();
    });

    // Show dialog
    overlay.style.display = 'flex';
    document.body.classList.add('modal-open');
  }

  function updateUserSettingsDisplay(userSettings) {
    debugLog("Updating user settings display", userSettings);

    // Update package checkboxes based on user settings
    if (userSettings && userSettings.packages) {
      debugLog("Updating checkboxes for packages:", userSettings.packages);
      updatePackageCheckboxes(userSettings.packages);
    }

    // Update behavior settings
    const keepMenuOpenCheckbox = document.getElementById('keepMenuOpenAfterPlace');
    if (keepMenuOpenCheckbox) {
      // Load from server settings first, then localStorage as fallback
      let keepMenuOpen = false;
      if (userSettings && typeof userSettings.keepMenuOpen === 'boolean') {
        keepMenuOpen = userSettings.keepMenuOpen;
      } else {
        // Fallback to localStorage
        const saved = localStorage.getItem('bazq_keepMenuOpen');
        keepMenuOpen = saved === 'true';
      }
      keepMenuOpenCheckbox.checked = keepMenuOpen;
      debugLog("Set keepMenuOpen to:", keepMenuOpen);
    }

    // Owner Lock Setting (Only visible/controllable for Owner)
    const ownerLockSetting = document.getElementById('ownerLockSetting');
    const lockNonOwnersCheckbox = document.getElementById('lockNonOwnersCheckbox');
    if (userSettings && userSettings.role === 'owner') {
      if (ownerLockSetting) ownerLockSetting.style.display = 'block';
      if (lockNonOwnersCheckbox) {
        lockNonOwnersCheckbox.checked = !!userSettings.lockNonOwners;
      }
    } else {
      if (ownerLockSetting) ownerLockSetting.style.display = 'none';
    }
  }

  // Package selection system
  // Package selection system (Re-implemented with Auto-Save)
  function initializePackageSelection() {
    const packageCheckboxes = document.querySelectorAll('.package-checkbox');
    packageCheckboxes.forEach(checkbox => {
      checkbox.addEventListener('change', handlePackageChange);
    });
  }

  function handlePackageChange() {
    const selectedPackages = getSelectedPackages();
    debugLog("Package selection changed:", selectedPackages);

    // 1. Update object list immediately
    updateObjectListFromPackages(selectedPackages);

    // 2. Auto-save settings
    savePackageSettingsAuto();

    addLogEntry(`Package updated: ${selectedPackages.length} active`, 'info');
  }

  function getSelectedPackages() {
    const packages = [];
    const checkboxMap = {
      'wallPack1': 'wall_pack_1',
      'wallPack2': 'wall_pack_2',
      'tentsPack': 'tents_package',
      'crashedAirPack': 'crashed_air',
      'subscriberPack': 'subscriber'
    };

    Object.keys(checkboxMap).forEach(checkboxId => {
      const checkbox = document.getElementById(checkboxId);
      if (checkbox && checkbox.checked) {
        packages.push(checkboxMap[checkboxId]);
      }
    });
    return packages;
  }

  function updatePackageCheckboxes(userPackages) {
    if (!userPackages) return;
    const checkboxMap = {
      'wall_pack_1': 'wallPack1',
      'wall_pack_2': 'wallPack2',
      'tents_package': 'tentsPack',
      'crashed_air': 'crashedAirPack',
      'subscriber': 'subscriberPack'
    };

    // Clear checks
    Object.values(checkboxMap).forEach(id => {
      const cb = document.getElementById(id);
      if (cb) cb.checked = false;
    });

    // Set checks
    userPackages.forEach(pkg => {
      const id = checkboxMap[pkg];
      if (id) {
        const cb = document.getElementById(id);
        if (cb) cb.checked = true;
      }
    });
  }

  function updateObjectListFromPackages(packages) {
    fetch('https://bazq-os/updatePackageFilter', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ packages: packages })
    }).catch(err => { if (DEBUG_MODE) console.error("Error updating filter:", err); });
  }

  function savePackageSettingsAuto() {
    const selectedPackages = getSelectedPackages();
    // We only need to save the packages here as keepMenuOpen is handled separately now
    fetch('https://bazq-os/saveUserSettings', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ packages: selectedPackages }) // Only sending packages updates
    }).catch(err => { if (DEBUG_MODE) console.error("Auto-save error:", err); });
  }

  // Initialize package selection handlers
  initializePackageSelection();

  // Initialize filter buttons
  initializeFilterButtons();

  // Initialize expand view functionality for placed objects
  initializeExpandView();

  // Initialize grouping controls
  function initGroupingControls() {
    const groupSelect = document.getElementById('groupModeSelect');
    const proxInput = document.getElementById('proximityMetersInput');
    const proxUnit = document.querySelector('.proximity-unit');
    if (!groupSelect) return;
    // set initial
    const currentMode = window.localStorage.getItem('bazq_group_mode') || 'name';
    groupSelect.value = currentMode;
    const currentProx = parseInt(window.localStorage.getItem('bazq_group_proximity') || '50', 10);
    if (proxInput) proxInput.value = currentProx;
    const toggleProx = (show) => {
      if (!proxInput || !proxUnit) return;
      proxInput.style.display = show ? 'inline-block' : 'none';
      proxUnit.style.display = show ? 'inline-block' : 'none';
    };
    toggleProx(currentMode === 'proximity');

    groupSelect.addEventListener('change', () => {
      const mode = groupSelect.value;
      window.localStorage.setItem('bazq_group_mode', mode);
      toggleProx(mode === 'proximity');
      // re-render from cache if we have it
      if (typeof populateSpawnedObjectsList === 'function' && Array.isArray(filteredSpawnedObjectsCache) && filteredSpawnedObjectsCache.length >= 0) {
        populateSpawnedObjectsList(filteredSpawnedObjectsCache);
      }
    });

    if (proxInput) {
      proxInput.addEventListener('change', () => {
        const v = parseInt(proxInput.value || '50', 10);
        const clamped = isNaN(v) ? 50 : Math.max(5, Math.min(1000, v));
        window.localStorage.setItem('bazq_group_proximity', String(clamped));
        proxInput.value = clamped;
        if (window.localStorage.getItem('bazq_group_mode') === 'proximity') {
          populateSpawnedObjectsList(filteredSpawnedObjectsCache || []);
        }
      });
    }
  }

  // Check and set proper initial UI state
  checkInitialUIState();

  // If UI is not supposed to be visible initially, hide it
  if (!isUIVisible) {
    hideUI();
  }

  function initializeExpandView() {
    const expandBtn = document.getElementById('expandPlacedViewBtn');
    const uiContainer = document.querySelector('.ui-container');

    if (expandBtn && uiContainer) {
      let isExpanded = false;

      expandBtn.addEventListener('click', () => {
        isExpanded = !isExpanded;

        if (isExpanded) {
          // Expand the UI
          uiContainer.classList.add('expanded');
          expandBtn.classList.add('expanded');
          expandBtn.innerHTML = '<i class="fas fa-compress-arrows-alt"></i>';
          expandBtn.title = 'Collapse view to normal size';
          addLogEntry('Placed objects view expanded for better visibility', 'info');
        } else {
          // Collapse the UI
          uiContainer.classList.remove('expanded');
          expandBtn.classList.remove('expanded');
          expandBtn.innerHTML = '<i class="fas fa-expand-arrows-alt"></i>';
          expandBtn.title = 'Expand view for better visibility';
          addLogEntry('Placed objects view collapsed to normal size', 'info');
        }
      });

      // Reset expansion when switching away from placed objects view
      const navButtons = document.querySelectorAll('.nav-button');
      const placedNavBtn = document.getElementById('navPlacedBtn');

      navButtons.forEach(btn => {
        if (btn !== placedNavBtn) {
          btn.addEventListener('click', () => {
            if (isExpanded) {
              isExpanded = false;
              uiContainer.classList.remove('expanded');
              expandBtn.classList.remove('expanded');
              expandBtn.innerHTML = '<i class="fas fa-expand-arrows-alt"></i>';
              expandBtn.title = 'Expand view for better visibility';
            }
          });
        }
      });
    }
  }

  // NUI Message handlers (for communication with Lua)
  window.addEventListener("message", (event) => {
    const data = event.data;

    switch (data.action) {
      case "open":
        debugLog("Received open message:", data);

        if (data.pathConfig) {
          gPathConfig = data.pathConfig;
        }

        // Populate objects list
        if (data.objects && Array.isArray(data.objects)) {
          debugLog("Populating object list with", data.objects.length, "objects:", data.objects);
          populateObjectList(data.objects, true); // Store as allObjects for search
          // Clear search bar when loading new objects
          if (searchBar) searchBar.value = "";
        } else {
          debugLog("No objects or invalid objects array:", data.objects);
        }

        // Update spawned objects list
        if (data.spawnedObjectsForList && Array.isArray(data.spawnedObjectsForList)) {
          debugLog("Initial spawned objects:", data.spawnedObjectsForList);
          populateSpawnedObjectsList(data.spawnedObjectsForList);
        } else {
          debugLog("No spawned objects or invalid format:", data.spawnedObjectsForList);
        }

        // Update user settings if provided
        if (data.userSettings) {
          debugLog("User settings:", data.userSettings);
          updateUserSettingsDisplay(data.userSettings);
        }

        // Show UI
        showUI();
        
        if (pathPropSelect) {
          updatePackageWeightsUI(pathPropSelect.value);
        }

        // Notify client that UI is ready for focus
        setTimeout(() => {
          fetch('https://bazq-os/uiReady', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
          });
        }, 50);
        break;
      case "close":
        hideUI();
        break;
      case "show":
        showUI();
        break;
      case "hide":
        hideUI();
        break;
      case "toggle":
        toggleUI();
        break;
      case "enterDrawingMode":
        document.body.classList.add("drawing-mode");
        break;
      case "exitDrawingMode":
        document.body.classList.remove("drawing-mode");
        const bpControls = document.getElementById("blueprintControlsGroup");
        if (bpControls) bpControls.style.display = "none";
        break;
      case "blueprintGenerated":
        updateBlueprintUI(data);
        break;
      case "selectBlueprintSegment":
        renderSelectedBlueprintSegment(data.index || 1);
        break;
      case "updateAxisLockCheckbox":
        const axisLockCheckbox = document.getElementById("pathAxisLock");
        if (axisLockCheckbox) {
          axisLockCheckbox.checked = !!data.state;
        }
        break;

      case "log":
        addLogEntry(data.message, data.type || 'info');
        break;
      case "updateObjectList":
        if (data.objects && Array.isArray(data.objects)) {
          debugLog("Updating object list from package selection:", data.objects);
          populateObjectList(data.objects, true); // Store as allObjects for search
          // Clear search bar when updating objects
          if (searchBar) searchBar.value = "";
        }
        break;
      case "updateSpawnedList":
        if (data.data && Array.isArray(data.data)) {
          debugLog("Updating spawned objects list:", data.data);
          populateSpawnedObjectsList(data.data);
        }
        break;

      case "checkKeepMenuOpen":
        // Check localStorage and trigger menu reopen if enabled
        const keepMenuOpenSetting = localStorage.getItem('bazq_keepMenuOpen') === 'true';
        debugLog('CheckKeepMenuOpen: localStorage setting is', keepMenuOpenSetting);
        if (keepMenuOpenSetting) {
          // Request to reopen menu
          setTimeout(() => {
            fetch('https://bazq-os/reopenMenu', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({})
            });
          }, 100);
        }
        break;

      case "testPerformanceWarning":
        const testCount = data.count || 2500;
        const testThreshold = 500;
        const testWarningEl = document.getElementById('performanceWarning');
        const testWarningText = document.getElementById('performanceWarningText');

        if (testWarningEl) {
          testWarningEl.classList.remove('hidden');
          if (testWarningText) {
            testWarningText.textContent = `TEST WARNING: High object count (${testCount} > ${testThreshold}). Performance may degrade. Please convert to YMAP.`;
          }
        }
        addLogEntry("Tested performance warning display", "info");
        break;

      case "updateFreecamState":
        const freecamBtn = document.getElementById('freecamBtn');
        const freecamIndicator = document.getElementById('freecamIndicator');
        const isActive = data.isActive;

        if (freecamBtn) {
          if (isActive) {
            freecamBtn.classList.add("active-toggle");
          } else {
            freecamBtn.classList.remove("active-toggle");
          }
        }

        if (freecamIndicator) {
          if (isActive) {
            freecamIndicator.classList.add("visible");
          } else {
            freecamIndicator.classList.remove("visible");
          }
        }

        debugLog("Freecam state updated:", isActive);
        addLogEntry(`Freecam ${isActive ? 'enabled' : 'disabled'}`, 'info');
        break;
      case "updateLockState":
        const lockCb = document.getElementById("lockNonOwnersCheckbox");
        if (lockCb) {
          lockCb.checked = !!data.locked;
        }
        break;
    }
  });

  function selectObject(index, id) {
    // Remove previous selection
    const previousSelected = document.querySelector('.compact-object-item.selected');
    if (previousSelected) {
      previousSelected.classList.remove('selected');
    }

    // Update selected index
    selectedObjectIndex = index;

    // Add selection to new item
    const newSelected = (id && document.querySelector(`[data-id="${id}"]`)) || document.querySelector(`[data-index="${index}"]`);
    if (newSelected) {
      newSelected.classList.add('selected');
    }

    // Send NUI callback to server
    fetch('https://bazq-os/selectObject', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ index: parseInt(index), id: id || undefined })
    }).then(() => {
      addLogEntry(`Selected object ${id || ('index ' + index)}`, 'info');
    }).catch(error => {
      if (DEBUG_MODE) console.error("Error selecting object:", error);
      addLogEntry(`Failed to select object: ${error.message}`, 'error');
    });
  }

  // Rename placed object function
  function renamePlacedObject(index, id) {
    const currentName = filteredSpawnedObjectsCache[index]?.displayName ||
      filteredSpawnedObjectsCache[index]?.model || 'Unknown';

    showRenameModal(index, id, currentName);
  }

  function showRenameModal(index, id, currentName) {
    const title = '🏷️ Rename Object';
    const message = `Enter a new name for this object:`;
    const details = `
      <div style="margin-top: 16px;">
        <div style="margin-bottom: 12px;">
          <strong>Current name:</strong> <span style="color: #22c55e;">${currentName}</span>
        </div>
        <div style="margin-bottom: 12px;">
          <input type="text" id="renameInput" 
                 style="width: 100%; padding: 8px 12px; border: 2px solid #374151; border-radius: 6px; 
                        background: #1f2937; color: #f1f5f9; font-size: 14px;"
                 value="${currentName}" placeholder="Enter new name..." maxlength="50">
        </div>
        <div style="color: #94a3b8; font-size: 12px;">
          💡 Tip: Use descriptive names to easily identify your objects
        </div>
      </div>
    `;

    showConfirmDialog(
      title,
      message,
      details,
      () => executeRename(index, id, currentName), // onConfirm
      () => { } // onCancel (do nothing)
    );

    // Focus and select the input field after modal opens
    setTimeout(() => {
      const input = document.getElementById('renameInput');
      if (input) {
        input.focus();
        input.select();

        // Allow Enter key to confirm
        input.addEventListener('keypress', (e) => {
          if (e.key === 'Enter') {
            executeRename(index, id, currentName);
          }
        });
      }
    }, 100);
  }

  function executeRename(index, id, originalName) {
    const input = document.getElementById('renameInput');
    const newName = input ? input.value.trim() : '';

    if (!newName || newName === originalName) {
      addLogEntry('No changes made to object name', 'info');
      return;
    }

    if (newName.length < 1) {
      addLogEntry('Object name cannot be empty', 'error');
      return;
    }

    // Send rename request to server
    fetch('https://bazq-os/renameObject', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ index: parseInt(index), id: id || undefined, newName: newName })
    }).then(response => {
      if (response.ok) {
        // Update local cache
        if (filteredSpawnedObjectsCache[index]) {
          filteredSpawnedObjectsCache[index].displayName = newName;
        }
        if (localSpawnedObjectsCache[index]) {
          localSpawnedObjectsCache[index].displayName = newName;
        }

        // Refresh the list
        setTimeout(() => {
          applyMultiLevelGrouping();
        }, 100);

        addLogEntry(`✅ Renamed object to "${newName}"`, 'success');
      } else {
        addLogEntry(`Failed to rename object`, 'error');
      }
    }).catch(error => {
      if (DEBUG_MODE) console.error("Error renaming object:", error);
      addLogEntry(`Failed to rename object: ${error.message}`, 'error');
    });
  }


  // Add placed objects filter functionality
  /* 
  // OLD FILTER SYSTEM - COMMENTED OUT SINCE GROUPING SYSTEM IS MORE POWERFUL
  // KEEPING FOR FUTURE REFERENCE/USE
  
  function initPlacedObjectsFilters() {
    const filterButtons = [
      { id: 'placedFilterAll', type: 'all' },
      { id: 'placedFilterBazq', type: 'bazq' },
      { id: 'placedFilterVanilla', type: 'vanilla' },
      { id: 'placedFilterWalls', type: 'walls' },
      { id: 'placedFilterTowers', type: 'towers' },
      { id: 'placedFilterGates', type: 'gates' },
      { id: 'placedFilterTents', type: 'tents' },
      { id: 'placedFilterAircraft', type: 'aircraft' },
      { id: 'placedFilterProps', type: 'props' }
    ];

    filterButtons.forEach(filter => {
      const button = document.getElementById(filter.id);
      if (button) {
        button.addEventListener('click', () => {
          // Remove active class from all filter buttons
          filterButtons.forEach(f => {
            const btn = document.getElementById(f.id);
            if (btn) btn.classList.remove('active-filter');
          });
          
          // Add active class to clicked button
          button.classList.add('active-filter');
          
          // Apply filter
          applyPlacedObjectsFilter(filter.type);
        });
      }
    });
  }

  function applyPlacedObjectsFilter(filterType) {
    if (!localSpawnedObjectsCache || localSpawnedObjectsCache.length === 0) {
      return;
    }

    let filtered = localSpawnedObjectsCache;

    switch (filterType) {
      case 'bazq':
        filtered = localSpawnedObjectsCache.filter(obj => 
          obj.model && obj.model.startsWith('bazq-')
        );
        break;
      case 'vanilla':
        filtered = localSpawnedObjectsCache.filter(obj => 
          obj.model && !obj.model.startsWith('bazq-')
        );
        break;
      case 'walls':
        filtered = localSpawnedObjectsCache.filter(obj => 
          obj.model && (obj.model.includes('wall') || obj.model.includes('sur'))
        );
        break;
      case 'towers':
        filtered = localSpawnedObjectsCache.filter(obj => 
          obj.model && (obj.model.includes('tower') || obj.model.includes('kule'))
        );
        break;
      case 'gates':
        filtered = localSpawnedObjectsCache.filter(obj => 
          obj.model && (obj.model.includes('gate') || obj.model.includes('kapi'))
        );
        break;
      case 'tents':
        filtered = localSpawnedObjectsCache.filter(obj => 
          obj.model && obj.model.includes('tent')
        );
        break;
      case 'aircraft':
        filtered = localSpawnedObjectsCache.filter(obj => 
          obj.model && (obj.model.includes('crashed') || obj.model.includes('plane') || obj.model.includes('helicopter'))
        );
        break;
      case 'props':
        filtered = localSpawnedObjectsCache.filter(obj => 
          obj.model && !obj.model.startsWith('bazq-') && 
          !obj.model.includes('wall') && !obj.model.includes('sur') &&
          !obj.model.includes('tower') && !obj.model.includes('kule') &&
          !obj.model.includes('gate') && !obj.model.includes('kapi') &&
          !obj.model.includes('tent') && !obj.model.includes('crashed') &&
          !obj.model.includes('plane') && !obj.model.includes('helicopter')
        );
        break;
      case 'all':
      default:
        filtered = localSpawnedObjectsCache;
        break;
    }

    filteredSpawnedObjectsCache = filtered;
    populateSpawnedObjectsList(filtered);
    
    addLogEntry(`Filtered to ${filtered.length} objects (${filterType})`, 'info');
  }
  
  // END OF OLD FILTER SYSTEM
  */

  // Initialize filters - COMMENTED OUT since grouping system is more powerful
  // initPlacedObjectsFilters();

  // Initialize grouping controls
  initGroupingControls();

  function initGroupingControls() {
    const primaryGroupSelect = document.getElementById('primaryGroupSelect');
    const secondaryGroupSelect = document.getElementById('secondaryGroupSelect');

    if (primaryGroupSelect) {
      primaryGroupSelect.addEventListener('change', () => {
        applyMultiLevelGrouping();
      });
    }

    if (secondaryGroupSelect) {
      secondaryGroupSelect.addEventListener('change', () => {
        applyMultiLevelGrouping();
      });
    }
  }

  function applyMultiLevelGrouping() {
    const primaryGroupSelect = document.getElementById('primaryGroupSelect');
    const secondaryGroupSelect = document.getElementById('secondaryGroupSelect');

    const primaryMode = primaryGroupSelect ? primaryGroupSelect.value : 'none';
    const secondaryMode = secondaryGroupSelect ? secondaryGroupSelect.value : 'none';

    const currentObjects = filteredSpawnedObjectsCache || [];
    if (currentObjects.length === 0) return;

    if (primaryMode === 'none') {
      populateSpawnedObjectsList(currentObjects);
      return;
    }

    if (secondaryMode === 'none' || secondaryMode === primaryMode) {
      // Single level grouping
      applyGrouping(primaryMode, currentObjects);
    } else {
      // Multi-level grouping
      applyNestedGrouping(primaryMode, secondaryMode, currentObjects);
    }
  }

  function applyGrouping(mode, objects) {
    switch (mode) {
      case 'player':
        renderGroupedByPlayer(objects);
        break;
      case 'type':
        renderGroupedByType(objects);
        break;
      case 'date':
        renderGroupedByDate(objects);
        break;
      case 'proximity':
        renderGroupedByProximity(objects);
        break;
      case 'none':
      default:
        populateSpawnedObjectsList(objects);
        break;
    }
  }

  function applyNestedGrouping(primaryMode, secondaryMode, objects) {
    const placedObjectsList = document.getElementById('placedObjectsList');
    if (!placedObjectsList) return;

    placedObjectsList.innerHTML = '';

    // First level grouping
    const primaryGroups = groupObjectsBy(objects, primaryMode);

    // Render each primary group with secondary grouping
    Object.keys(primaryGroups).sort().forEach(primaryKey => {
      const primaryGroup = primaryGroups[primaryKey];
      const primaryLabel = getGroupLabel(primaryMode, primaryKey, primaryGroup.length);

      // Create primary group container
      const primaryContainer = document.createElement('div');
      primaryContainer.className = 'primary-group-container';

      // Create primary group header
      const primaryHeader = document.createElement('div');
      primaryHeader.className = 'primary-group-header';
      primaryHeader.innerHTML = `
        <span>${primaryLabel}</span>
        <div style="display: flex; align-items: center; gap: 8px;">
          <span class="group-count">${primaryGroup.length}</span>
          <button class="primary-group-delete-btn" title="Delete all objects in this group">
            <i class="fas fa-trash"></i>
          </button>
          <span class="expand-icon">▼</span>
        </div>
      `;

      // Create primary group content
      const primaryContent = document.createElement('div');
      primaryContent.className = 'primary-group-content';

      // Apply secondary grouping to this primary group
      const secondaryGroups = groupObjectsBy(primaryGroup, secondaryMode);

      Object.keys(secondaryGroups).sort().forEach(secondaryKey => {
        const secondaryGroup = secondaryGroups[secondaryKey];
        const secondaryLabel = getGroupLabel(secondaryMode, secondaryKey, secondaryGroup.length);

        renderGroup(secondaryLabel, secondaryGroup, `${primaryKey}-${secondaryKey}`, primaryContent);
      });

      // Add collapse/expand functionality for primary group
      let isPrimaryCollapsed = false;
      primaryHeader.addEventListener('click', (e) => {
        // Don't expand/collapse if clicking delete button
        if (e.target.closest('.primary-group-delete-btn')) return;

        isPrimaryCollapsed = !isPrimaryCollapsed;
        primaryContent.classList.toggle('collapsed', isPrimaryCollapsed);
        primaryHeader.classList.toggle('collapsed', isPrimaryCollapsed);
      });

      // Add primary group delete functionality
      const primaryDeleteBtn = primaryHeader.querySelector('.primary-group-delete-btn');
      if (primaryDeleteBtn) {
        primaryDeleteBtn.addEventListener('click', (e) => {
          e.stopPropagation();
          deleteGroup(primaryGroup, primaryLabel);
        });
      }

      primaryContainer.appendChild(primaryHeader);
      primaryContainer.appendChild(primaryContent);
      placedObjectsList.appendChild(primaryContainer);
    });

    addLogEntry(`Grouped ${objects.length} objects by ${primaryMode} → ${secondaryMode}`, 'info');
  }

  function groupObjectsBy(objects, mode) {
    const groups = {};

    objects.forEach(obj => {
      let key;

      switch (mode) {
        case 'player':
          key = obj.playerName || 'Unknown';
          break;
        case 'type':
          key = getObjectType(obj.model);
          break;
        case 'date':
          key = getDateGroup(obj.timestamp);
          break;
        case 'proximity':
          // For proximity in nested grouping, we'll use a simpler approach
          key = 'Proximity Group';
          break;
        default:
          key = 'Other';
      }

      if (!groups[key]) {
        groups[key] = [];
      }
      groups[key].push(obj);
    });

    return groups;
  }

  function getGroupLabel(mode, key, count) {
    switch (mode) {
      case 'player':
        return `👤 ${key}`;
      case 'type':
        return `🏷️ ${key}`;
      case 'date':
        return `📅 ${key}`;
      case 'proximity':
        return `📍 ${key}`;
      default:
        return key;
    }
  }

  function getDateGroup(timestamp) {
    if (!timestamp) {
      console.log('Date Group Debug: No timestamp provided');
      return 'Unknown Date';
    }

    console.log('Date Group Debug: Processing timestamp:', timestamp, typeof timestamp);

    try {
      let date;

      // Handle different timestamp formats
      if (typeof timestamp === 'string') {
        // Try parsing as ISO string first
        if (timestamp.includes('T') || timestamp.includes('-')) {
          date = new Date(timestamp);
        } else if (timestamp.includes(':') && timestamp.length <= 5) {
          // Old format: "HH:MM" - use today's date with this time
          const now = new Date();
          const [hours, minutes] = timestamp.split(':').map(num => parseInt(num, 10));
          date = new Date(now.getFullYear(), now.getMonth(), now.getDate(), hours || 0, minutes || 0);
        } else {
          // Try parsing as timestamp number in string
          const numTimestamp = parseInt(timestamp);
          if (!isNaN(numTimestamp)) {
            // If it's a small number, it might be seconds; if large, milliseconds
            date = new Date(numTimestamp > 1000000000000 ? numTimestamp : numTimestamp * 1000);
          } else {
            date = new Date(timestamp);
          }
        }
      } else if (typeof timestamp === 'number') {
        // Handle timestamp as number - convert Unix timestamp (seconds) to milliseconds
        date = new Date(timestamp > 1000000000000 ? timestamp : timestamp * 1000);
      } else {
        return 'Unknown Date';
      }

      // Check if date is valid
      if (isNaN(date.getTime())) {
        console.warn('Date Group Debug: Invalid timestamp:', timestamp);
        return 'Unknown Date';
      }

      const now = new Date();
      const diffTime = now - date;
      const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));

      console.log('Date Group Debug: Parsed date:', date.toString());
      console.log('Date Group Debug: Current time:', now.toString());
      console.log('Date Group Debug: Difference in days:', diffDays);

      // Handle future dates
      if (diffDays < 0) {
        console.log('Date Group Debug: Future date detected');
        return 'Future';
      }

      if (diffDays === 0) {
        console.log('Date Group Debug: Today detected');
        return 'Today';
      }
      if (diffDays === 1) {
        console.log('Date Group Debug: Yesterday detected');
        return 'Yesterday';
      }
      if (diffDays <= 7) {
        console.log('Date Group Debug: This Week detected');
        return 'This Week';
      }
      if (diffDays <= 30) {
        console.log('Date Group Debug: This Month detected');
        return 'This Month';
      }
      if (diffDays <= 90) {
        console.log('Date Group Debug: Last 3 Months detected');
        return 'Last 3 Months';
      }

      // For older dates, return month and year
      try {
        return date.toLocaleDateString('en-US', { year: 'numeric', month: 'long' });
      } catch (error) {
        return date.getFullYear().toString();
      }
    } catch (error) {
      console.warn('Error parsing timestamp:', timestamp, error);
      return 'Unknown Date';
    }
  }

  function renderGroupedByPlayer(objects) {
    const placedObjectsList = document.getElementById('placedObjectsList');
    if (!placedObjectsList) return;

    placedObjectsList.innerHTML = '';

    // Group by player
    const playerGroups = {};
    objects.forEach(obj => {
      const playerName = obj.playerName || 'Unknown';
      if (!playerGroups[playerName]) {
        playerGroups[playerName] = [];
      }
      playerGroups[playerName].push(obj);
    });

    // Render groups
    Object.keys(playerGroups).sort().forEach(playerName => {
      const group = playerGroups[playerName];
      renderGroup(`👤 ${playerName}`, group, `player-${playerName.replace(/[^a-zA-Z0-9]/g, '')}`);
    });
  }

  function renderGroupedByType(objects) {
    const placedObjectsList = document.getElementById('placedObjectsList');
    if (!placedObjectsList) return;

    placedObjectsList.innerHTML = '';

    // Group by type
    const typeGroups = {};
    objects.forEach(obj => {
      const type = getObjectType(obj.model);
      if (!typeGroups[type]) {
        typeGroups[type] = [];
      }
      typeGroups[type].push(obj);
    });

    // Render groups
    Object.keys(typeGroups).sort().forEach(type => {
      const group = typeGroups[type];
      renderGroup(`🏷️ ${type}`, group, `type-${type.replace(/[^a-zA-Z0-9]/g, '')}`);
    });
  }

  function renderGroupedByDate(objects) {
    const placedObjectsList = document.getElementById('placedObjectsList');
    if (!placedObjectsList) return;

    placedObjectsList.innerHTML = '';

    // Debug: Check timestamp formats
    console.log('Date grouping - sample timestamps:', objects.slice(0, 3).map(obj => ({
      model: obj.model,
      timestamp: obj.timestamp,
      timestampType: typeof obj.timestamp
    })));

    // Group by date
    const dateGroups = {};
    objects.forEach(obj => {
      const dateKey = getDateGroup(obj.timestamp);
      if (!dateGroups[dateKey]) {
        dateGroups[dateKey] = [];
      }
      dateGroups[dateKey].push(obj);
    });

    // Sort date groups by recency
    const sortedDateKeys = Object.keys(dateGroups).sort((a, b) => {
      const order = ['Future', 'Today', 'Yesterday', 'This Week', 'This Month', 'Last 3 Months'];
      const aIndex = order.indexOf(a);
      const bIndex = order.indexOf(b);

      // Handle special categories first
      if (a === 'Unknown Date') return 1;
      if (b === 'Unknown Date') return -1;

      if (aIndex !== -1 && bIndex !== -1) return aIndex - bIndex;
      if (aIndex !== -1) return -1;
      if (bIndex !== -1) return 1;

      // For month/year groups, sort by parsing the month name
      try {
        // Try to parse as "Month Year" format
        const aDate = new Date(a + ' 1');
        const bDate = new Date(b + ' 1');

        if (!isNaN(aDate.getTime()) && !isNaN(bDate.getTime())) {
          return bDate - aDate; // Most recent first
        }
      } catch (error) {
        // Fallback to alphabetical
      }

      return a.localeCompare(b);
    });

    // Render groups
    sortedDateKeys.forEach(dateKey => {
      const group = dateGroups[dateKey];
      renderGroup(`📅 ${dateKey}`, group, `date-${dateKey.replace(/[^a-zA-Z0-9]/g, '')}`);
    });
  }

  function renderGroupedByProximity(objects) {
    const placedObjectsList = document.getElementById('placedObjectsList');
    if (!placedObjectsList) return;

    const maxDistance = 50; // Fixed 50m proximity distance

    placedObjectsList.innerHTML = '';

    // Filter objects that have valid coordinates
    const objectsWithCoords = objects.filter(obj => {
      if (!obj.coords || typeof obj.coords.x !== 'number' || typeof obj.coords.y !== 'number' || typeof obj.coords.z !== 'number') {
        console.warn('Object missing valid coordinates:', obj);
        return false;
      }
      return true;
    });

    if (objectsWithCoords.length === 0) {
      placedObjectsList.innerHTML = '<div class="no-objects">No objects with valid coordinates found for proximity grouping.</div>';
      addLogEntry("No objects with coordinates found for proximity grouping", 'warning');
      return;
    }

    console.log(`Found ${objectsWithCoords.length} objects for proximity grouping`);

    // Simple proximity clustering: group objects that are close to each other
    const groups = [];
    const used = new Set();

    objectsWithCoords.forEach((obj, index) => {
      if (used.has(index)) return;

      const group = [obj];
      used.add(index);

      // Find all objects within maxDistance of this object
      objectsWithCoords.forEach((other, otherIndex) => {
        if (used.has(otherIndex) || index === otherIndex) return;

        const distance = calculateDistance(obj.coords, other.coords);
        if (distance <= maxDistance) {
          group.push(other);
          used.add(otherIndex);
        }
      });

      // Continue expanding the group by checking if any new objects are close to existing group members
      let expandedGroup = true;
      while (expandedGroup) {
        expandedGroup = false;

        objectsWithCoords.forEach((candidate, candidateIndex) => {
          if (used.has(candidateIndex)) return;

          // Check if candidate is close to any object in the current group
          for (let groupObj of group) {
            const distance = calculateDistance(groupObj.coords, candidate.coords);
            if (distance <= maxDistance) {
              group.push(candidate);
              used.add(candidateIndex);
              expandedGroup = true;
              break;
            }
          }
        });
      }

      groups.push(group);
    });

    // Sort groups by size (largest first)
    groups.sort((a, b) => b.length - a.length);

    // Render groups
    groups.forEach((group, index) => {
      const label = group.length === 1
        ? `📍 Isolated Object`
        : `📍 Cluster ${index + 1} (${group.length} objects within ${maxDistance}m)`;
      renderGroup(label, group, `proximity-${index}`);
    });

    addLogEntry(`Grouped ${objectsWithCoords.length} objects into ${groups.length} proximity clusters (${maxDistance}m range)`, 'info');
  }

  function renderGroup(title, objects, groupId, container = null) {
    const targetContainer = container || document.getElementById('placedObjectsList');
    if (!targetContainer) return;

    // Create group container
    const groupContainer = document.createElement('div');
    groupContainer.className = 'group-container';

    // Create group header
    const groupHeader = document.createElement('div');
    groupHeader.className = 'group-header';
    groupHeader.innerHTML = `
      <span>${title}</span>
      <div style="display: flex; align-items: center; gap: 8px;">
        <span class="group-count">${objects.length}</span>
        <button class="group-delete-btn" title="Delete all objects in this group">
          <i class="fas fa-trash"></i>
        </button>
        <span class="expand-icon">▼</span>
      </div>
    `;

    // Create group content
    const groupContent = document.createElement('div');
    groupContent.className = 'group-content';

    // Create objects grid for this group
    const objectsGrid = document.createElement('div');
    objectsGrid.className = 'objects-grid';

    objects.forEach(obj => {
      const objectItem = createObjectGridItem(obj);
      objectsGrid.appendChild(objectItem);
    });

    groupContent.appendChild(objectsGrid);

    // Add collapse/expand functionality
    let isCollapsed = false;
    groupHeader.addEventListener('click', (e) => {
      // Don't expand/collapse if clicking delete button
      if (e.target.closest('.group-delete-btn')) return;

      isCollapsed = !isCollapsed;
      groupContent.classList.toggle('collapsed', isCollapsed);
      groupHeader.classList.toggle('collapsed', isCollapsed);
    });

    // Add group delete functionality
    const deleteBtn = groupHeader.querySelector('.group-delete-btn');
    if (deleteBtn) {
      deleteBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        deleteGroup(objects, title);
      });
    }

    groupContainer.appendChild(groupHeader);
    groupContainer.appendChild(groupContent);
    targetContainer.appendChild(groupContainer);
  }

  function createObjectGridItem(obj) {
    const objectItem = document.createElement('div');
    objectItem.className = 'object-grid-item';
    objectItem.dataset.index = obj.originalIndex;

    const icon = getModelIcon(obj.model);
    const displayName = obj.displayName || obj.model.replace(/^bazq-/, '').replace(/_/g, ' ');
    const shortName = displayName.length > 12 ? displayName.substring(0, 12) + '...' : displayName;

    // Format timestamp for display (date + time)
    let timeDisplay = '';

    if (obj.timestamp) {
      try {
        let date;
        if (typeof obj.timestamp === 'string') {
          if (obj.timestamp.includes(':') && obj.timestamp.length <= 5) {
            // Old HH:MM format - just show time
            timeDisplay = obj.timestamp;
          } else if (obj.timestamp.includes('T') || obj.timestamp.includes('-')) {
            // ISO format
            date = new Date(obj.timestamp);
            timeDisplay = date.toLocaleDateString('tr-TR', {
              day: '2-digit',
              month: '2-digit',
              year: 'numeric'
            }) + ' ' + date.toLocaleTimeString('tr-TR', {
              hour: '2-digit',
              minute: '2-digit'
            });
          } else {
            // Numeric string
            const numTimestamp = parseInt(obj.timestamp);
            if (!isNaN(numTimestamp)) {
              date = new Date(numTimestamp > 1000000000000 ? numTimestamp : numTimestamp * 1000);
              timeDisplay = date.toLocaleDateString('tr-TR', {
                day: '2-digit',
                month: '2-digit',
                year: 'numeric'
              }) + ' ' + date.toLocaleTimeString('tr-TR', {
                hour: '2-digit',
                minute: '2-digit'
              });
            }
          }
        } else if (typeof obj.timestamp === 'number') {
          if (obj.timestamp === 0) {
            timeDisplay = '--/--/---- --:--';
          } else {
            date = new Date(obj.timestamp > 1000000000000 ? obj.timestamp : obj.timestamp * 1000);
            timeDisplay = date.toLocaleDateString('tr-TR', {
              day: '2-digit',
              month: '2-digit',
              year: 'numeric'
            }) + ' ' + date.toLocaleTimeString('tr-TR', {
              hour: '2-digit',
              minute: '2-digit'
            });
          }
        }

        if (!timeDisplay && date && !isNaN(date.getTime())) {
          timeDisplay = date.toLocaleDateString('tr-TR', {
            day: '2-digit',
            month: '2-digit',
            year: 'numeric'
          }) + ' ' + date.toLocaleTimeString('tr-TR', {
            hour: '2-digit',
            minute: '2-digit'
          });
        }
      } catch (error) {
        console.warn('Error formatting timestamp for display:', obj.timestamp, error);
        timeDisplay = '--/--/---- --:--';
      }
    }

    if (!timeDisplay) timeDisplay = '--/--/---- --:--';


    objectItem.dataset.id = obj.id || '';
    objectItem.innerHTML = `
      <div class="grid-object-icon">${icon}</div>
      <div class="grid-object-info">
        <div class="grid-object-name" title="${displayName}">${shortName}</div>
        <div class="grid-object-meta">
          <span class="grid-object-player" title="Placed by ${obj.playerName || 'Unknown'}">${obj.playerName || 'Unknown'}</span>
          <span class="grid-object-time" title="Placed at ${timeDisplay}">${timeDisplay}</span>
        </div>
      </div>
      <div class="grid-object-actions">
        <button class="grid-action-btn rename-btn" data-index="${obj.originalIndex}" data-id="${obj.id || ''}" title="Rename">
          <i class="fas fa-tag"></i>
        </button>
        <button class="grid-action-btn edit-btn" data-index="${obj.originalIndex}" data-id="${obj.id || ''}" title="Edit">
          <i class="fas fa-edit"></i>
        </button>
        <button class="grid-action-btn duplicate-btn" data-index="${obj.originalIndex}" data-id="${obj.id || ''}" title="Duplicate">
          <i class="fas fa-copy"></i>
        </button>
        <button class="grid-action-btn delete-btn" data-index="${obj.originalIndex}" data-id="${obj.id || ''}" title="Delete">
          <i class="fas fa-trash"></i>
        </button>
      </div>
    `;

    // Add event listeners
    addObjectItemEventListeners(objectItem, obj);

    return objectItem;
  }

  function addObjectItemEventListeners(objectItem, obj) {
    // Click handler for object selection
    objectItem.addEventListener('click', (e) => {
      if (!e.target.closest('.grid-object-actions')) {
        selectObject(obj.originalIndex, obj.id);
      }
    });

    // Action button event listeners
    const renameBtn = objectItem.querySelector('.rename-btn');
    const editBtn = objectItem.querySelector('.edit-btn');
    const duplicateBtn = objectItem.querySelector('.duplicate-btn');
    const deleteBtn = objectItem.querySelector('.delete-btn');

    if (renameBtn) {
      renameBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        renamePlacedObject(obj.originalIndex, obj.id);
      });
    }

    if (editBtn) {
      editBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        editPlacedObject(obj.originalIndex, obj.id);
      });
    }

    if (duplicateBtn) {
      duplicateBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        duplicatePlacedObject(obj.originalIndex, obj.id);
      });
    }

    if (deleteBtn) {
      deleteBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        deletePlacedObject(obj.originalIndex, obj.id);
      });
    }
  }

  function getObjectType(model) {
    if (model.startsWith('bazq-')) {
      if (model.includes('tent')) return 'Tents';
      if (model.includes('wall') || model.includes('sur')) return 'Walls';
      if (model.includes('kule')) return 'Towers';
      if (model.includes('gate') || model.includes('kapi')) return 'Gates';
      if (model.includes('sign')) return 'Signs';
      if (model.includes('pole')) return 'Poles';
      if (model.includes('fence')) return 'Fences';
      if (model.includes('decal')) return 'Decals';
      if (model.includes('crashed') || model.includes('plane')) return 'Aircraft';
      return 'bazq Items';
    }

    // Vanilla items
    if (model.includes('tent')) return 'Tents';
    if (model.includes('wall')) return 'Walls';
    if (model.includes('tower')) return 'Towers';
    if (model.includes('gate')) return 'Gates';
    if (model.includes('sign')) return 'Signs';
    if (model.includes('pole')) return 'Poles';
    if (model.includes('fence')) return 'Fences';
    if (model.includes('decal')) return 'Decals';
    if (model.includes('plane') || model.includes('helicopter')) return 'Aircraft';
    return 'Props';
  }

  function calculateDistance(pos1, pos2) {
    const dx = pos1.x - pos2.x;
    const dy = pos1.y - pos2.y;
    const dz = pos1.z - pos2.z;
    return Math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  function deleteGroup(objects, groupTitle) {
    if (!objects || objects.length === 0) return;

    // Show delete group confirmation modal
    showDeleteGroupModal(objects, groupTitle);
  }

  function showDeleteGroupModal(objects, groupTitle) {
    const objectNames = objects.map(obj => obj.displayName || obj.model).slice(0, 3);
    const displayNames = objectNames.length > 3
      ? `${objectNames.join(', ')} and ${objects.length - 3} more`
      : objectNames.join(', ');

    const title = '🗑️ Delete Group';
    const message = `Are you sure you want to delete all objects in "${groupTitle}"?`;
    const details = `
      <div style="margin-top: 16px;">
        <div style="font-weight: 600; color: #f59e0b; margin-bottom: 12px;">
          ⚠️ This action cannot be undone!
        </div>
        <div style="margin-bottom: 8px;">
          <strong>Objects to delete:</strong> <span style="color: #ef4444;">${objects.length}</span>
        </div>
        <div style="color: #9ca3af; font-size: 12px;">
          <strong>Preview:</strong> ${displayNames}
        </div>
      </div>
    `;

    showConfirmDialog(
      title,
      message,
      details,
      () => executeGroupDelete(objects, groupTitle), // onConfirm
      () => { } // onCancel (do nothing)
    );
  }

  function executeGroupDelete(objects, groupTitle) {
    if (!objects || !groupTitle) return;

    // Show progress
    addLogEntry(`Deleting ${objects.length} objects from group "${groupTitle}"...`, 'info');

    const indices = objects.map(obj => parseInt(obj.originalIndex));
    const ids = objects.map(obj => obj.id).filter(id => id && id.length > 0);

    fetch('https://bazq-os/deleteObjects', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ indices: indices, ids: ids })
    })
      .then(response => response.json())
      .then(data => {
        if (data.status === 'ok') {
          const deletedCount = data.deletedCount || indices.length;
          addLogEntry(`✅ Deleted ${deletedCount}/${objects.length} objects from group "${groupTitle}"`, 'success');

          // Remove deleted objects from local cache
          if (localSpawnedObjectsCache) {
            localSpawnedObjectsCache = localSpawnedObjectsCache.filter(obj =>
              !indices.includes(parseInt(obj.originalIndex))
            );
          }
          if (filteredSpawnedObjectsCache) {
            filteredSpawnedObjectsCache = filteredSpawnedObjectsCache.filter(obj =>
              !indices.includes(parseInt(obj.originalIndex))
            );
          }

          // Refresh the view with updated cache
          setTimeout(() => {
            applyMultiLevelGrouping();
          }, 100);
        } else {
          addLogEntry(`❌ Failed to delete group: ${data.message || 'Unknown error'}`, 'error');
        }
      })
      .catch(error => {
        console.error('Failed to delete group:', error);
        addLogEntry(`❌ Failed to delete group due to network error`, 'error');
      });
  }

}); // End of DOMContentLoaded 