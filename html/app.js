// ============================================================================
// BAZQ-OS OBJECT SPAWNER - Enhanced UI System with User Management
// ============================================================================

// TestZone UI Handler - Defined at top to ensure availability
function handleTestZoneUI(data) {
  const testZoneUI = document.getElementById('testzoneControlsUI');
  if (!testZoneUI) {
    console.warn('TestZone Controls UI element not found');
    return;
  }
  
  if (data.show) {
    // Show UI with animation
    testZoneUI.classList.remove('hidden');
    console.log('TestZone Controls UI shown');
    
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
    console.log('TestZone Controls UI hidden');
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
  console.log(`[${type.toUpperCase()}] ${message}`);
  
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

  if (addUserBtn) {
    addUserBtn.addEventListener('click', handleAddUser);
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
  window.addEventListener('message', function(event) {
    if (event.data.action === 'userListResponse') {
      handleUserListResponse(event.data);
    } else if (event.data.action === 'userActionResponse') {
      handleUserActionResponse(event.data);
    } else if (event.data.action === 'showTestZoneUI') {
      handleTestZoneUI(event.data);
    }
  });
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
    () => {} // onCancel (do nothing)
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
  const dataUri = 'data:application/json;charset=utf-8,'+ encodeURIComponent(dataStr);
  
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
  return text.replace(/[&<>"']/g, function(m) { return map[m]; });
}

// Main application code
window.addEventListener("DOMContentLoaded", () => {
  const uiContainer = document.querySelector(".ui-container");
  
  // Navigation buttons and View Panels
  const navLibraryBtn = document.getElementById("navLibraryBtn");
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
  const manualSpawnerView = document.getElementById("manualSpawnerView");
  const placedObjectsView = document.getElementById("placedObjectsView");
  const settingsView = document.getElementById("settingsView");
  const usersView = document.getElementById("usersView");
  const navButtons = [navLibraryBtn, navManualBtn, navPlacedBtn, navSettingsBtn, navUsersBtn];
  const viewPanels = [libraryView, manualSpawnerView, placedObjectsView, settingsView, usersView];

  // Object library variables
  let allMasterItems = [];
  let allObjects = [];
  let localSpawnedObjectsCache = [];
  let filteredSpawnedObjectsCache = [];

  // Add variable to track selected object
  let selectedObjectIndex = null;

  // Filter state management
  let currentFilter = 'all';

  function switchView(targetView) {
    navButtons.forEach(btn => btn?.classList.remove("active-nav"));
    viewPanels.forEach(panel => panel?.classList.remove("active-view"));

    if (targetView === libraryView) navLibraryBtn?.classList.add("active-nav");
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
    console.log("Populating object list with", objects.length, "objects");
    addLogEntry(`Loading ${objects.length} objects into library...`, 'info');
    
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
        console.log("Applied search filter, now showing", objects.length, "objects");
      }
    }
    
    const objectListContainer = document.querySelector('.object-list');
    if (!objectListContainer) {
      console.error("Object list container not found!");
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
      imgElement.onerror = function() {
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
    console.log("Spawning object:", model);
    addLogEntry(`Spawning: ${model}`, 'info');
    
    fetch('https://bazq-os/selectObject', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: model,
        options: getPlacementOptions()
      })
    }).then(response => {
      console.log("Spawn request sent for:", model);
    }).catch(error => {
      console.error("Error spawning object:", error);
      addLogEntry(`Failed to spawn ${model}: ${error.message}`, 'error');
    });
  }
  
  function populateSpawnedObjectsList(spawnedObjects) {
    console.log("Updating spawned objects list with", spawnedObjects.length, "objects");
    addLogEntry(`Loading ${spawnedObjects.length} placed objects...`, 'info');
    
    // Update caches if this is a fresh data load
    if (spawnedObjects !== filteredSpawnedObjectsCache) {
      localSpawnedObjectsCache = [...spawnedObjects];
      filteredSpawnedObjectsCache = [...spawnedObjects];
    }
    
    const placedObjectsList = document.getElementById('placedObjectsList');
    if (!placedObjectsList) {
      console.error("Placed objects list container not found!");
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
          <button class="grid-action-btn rename-btn" data-index="${obj.originalIndex}" title="Rename">
            <i class="fas fa-tag"></i>
          </button>
          <button class="grid-action-btn edit-btn" data-index="${obj.originalIndex}" title="Edit">
            <i class="fas fa-edit"></i>
          </button>
          <button class="grid-action-btn duplicate-btn" data-index="${obj.originalIndex}" title="Duplicate">
            <i class="fas fa-copy"></i>
          </button>
          <button class="grid-action-btn delete-btn" data-index="${obj.originalIndex}" title="Delete">
            <i class="fas fa-trash"></i>
          </button>
        </div>
      `;
      
      // Add click handler for object selection
      objectItem.addEventListener('click', (e) => {
        if (!e.target.closest('.grid-object-actions')) {
          selectObject(obj.originalIndex);
        }
      });
      
      // Add action button event listeners
      const renameBtn = objectItem.querySelector('.rename-btn');
      const editBtn = objectItem.querySelector('.edit-btn');
      const duplicateBtn = objectItem.querySelector('.duplicate-btn');
      const deleteBtn = objectItem.querySelector('.delete-btn');
      
      if (renameBtn) {
        renameBtn.addEventListener('click', (e) => {
          e.stopPropagation();
          renamePlacedObject(e.target.closest('.rename-btn').dataset.index);
        });
      }
      
      if (editBtn) {
        editBtn.addEventListener('click', (e) => {
          e.stopPropagation();
          editPlacedObject(e.target.closest('.edit-btn').dataset.index);
        });
      }
      
      if (duplicateBtn) {
        duplicateBtn.addEventListener('click', (e) => {
          e.stopPropagation();
          duplicatePlacedObject(e.target.closest('.duplicate-btn').dataset.index);
        });
      }
      
      if (deleteBtn) {
        deleteBtn.addEventListener('click', (e) => {
          e.stopPropagation();
          deletePlacedObject(e.target.closest('.delete-btn').dataset.index);
        });
      }
      
      objectsGrid.appendChild(objectItem);
    });
    
    placedObjectsList.appendChild(objectsGrid);
  }

  // Select object function
  function selectObject(index) {
    if (!index) return;
    
    // Send NUI callback to server
    fetch('https://bazq-os/selectObject', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ index: parseInt(index) })
    }).then(() => {
      addLogEntry(`Selected object at index ${index}`, 'info');
    }).catch(error => {
      console.error("Error selecting object:", error);
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
  
  function editPlacedObject(index) {
    addLogEntry(`Editing object at index ${index}`, 'info');
    fetch('https://bazq-os/editSpawnedObject', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ index: parseInt(index) })
    }).catch(error => {
      console.error("Error editing object:", error);
      addLogEntry(`Failed to edit object: ${error.message}`, 'error');
    });
  }
  
  function duplicatePlacedObject(index) {
    addLogEntry(`Duplicating object at index ${index}`, 'info');
    fetch('https://bazq-os/duplicateObject', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        index: parseInt(index),
        options: getPlacementOptions()
      })
    }).catch(error => {
      console.error("Error duplicating object:", error);
      addLogEntry(`Failed to duplicate object: ${error.message}`, 'error');
    });
  }
  
  function deletePlacedObject(index) {
    showConfirmDialog(
      'Delete Object',
      'Are you sure you want to delete this object?',
      'This action cannot be undone.',
      () => {
        addLogEntry(`Deleting object at index ${index}`, 'info');
        fetch('https://bazq-os/deleteObject', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ index: parseInt(index) })
        }).catch(error => {
          console.error("Error deleting object:", error);
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
    console.log("Updating user settings display", userSettings);
    
    // Update package checkboxes based on user settings
    if (userSettings && userSettings.packages) {
      console.log("Updating checkboxes for packages:", userSettings.packages);
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
      console.log("Set keepMenuOpen to:", keepMenuOpen);
    }
  }
  
  // Package selection system
  function initializePackageSelection() {
    const packageCheckboxes = document.querySelectorAll('.package-checkbox');
    
    packageCheckboxes.forEach(checkbox => {
      checkbox.addEventListener('change', handlePackageChange);
    });
    
    // Save settings button
    const saveSettingsBtn = document.getElementById('saveSettingsBtn');
    if (saveSettingsBtn) {
      saveSettingsBtn.addEventListener('click', savePackageSettings);
    }
  }
  
  function handlePackageChange() {
    const selectedPackages = getSelectedPackages();
    console.log("Package selection changed:", selectedPackages);
    
    // Update object list immediately
    updateObjectListFromPackages(selectedPackages);
    
    addLogEntry(`Package selection updated: ${selectedPackages.length} packages selected`, 'info');
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
    const checkboxMap = {
      'wall_pack_1': 'wallPack1',
      'wall_pack_2': 'wallPack2',
      'tents_package': 'tentsPack',
      'crashed_air': 'crashedAirPack',
      'subscriber': 'subscriberPack'
    };
    
    // Clear all checkboxes first
    Object.values(checkboxMap).forEach(checkboxId => {
      const checkbox = document.getElementById(checkboxId);
      if (checkbox) {
        checkbox.checked = false;
      }
    });
    
    // Check boxes for user's packages
    userPackages.forEach(packageName => {
      const checkboxId = checkboxMap[packageName];
      if (checkboxId) {
        const checkbox = document.getElementById(checkboxId);
        if (checkbox) {
          checkbox.checked = true;
        }
      }
    });
  }
  
  function updateObjectListFromPackages(packages) {
    // Send package selection to client to update object list
    fetch('https://bazq-os/updatePackageFilter', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ packages: packages })
    }).then(response => {
      console.log("Package filter update sent:", packages);
    }).catch(error => {
      console.error("Error updating package filter:", error);
      addLogEntry(`Failed to update package filter: ${error.message}`, 'error');
    });
  }
  
  function savePackageSettings() {
    const selectedPackages = getSelectedPackages();
    const keepMenuOpen = document.getElementById('keepMenuOpenAfterPlace')?.checked || false;
    
    console.log("Saving settings:", { packages: selectedPackages, keepMenuOpen });
    
    // Save to localStorage for immediate use
    localStorage.setItem('bazq_keepMenuOpen', keepMenuOpen.toString());
    
    // Send to server to save
    fetch('https://bazq-os/saveUserSettings', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        packages: selectedPackages,
        keepMenuOpen: keepMenuOpen
      })
    }).then(response => {
      addLogEntry(`Settings saved: ${selectedPackages.length} packages, menu behavior: ${keepMenuOpen ? 'stay open' : 'auto-close'}`, 'success');
    }).catch(error => {
      console.error("Error saving settings:", error);
      addLogEntry(`Failed to save settings: ${error.message}`, 'error');
    });
  }

  // Initialize package selection handlers
  initializePackageSelection();
  
  // Initialize filter buttons
  initializeFilterButtons();
  
  // Initialize expand view functionality for placed objects
  initializeExpandView();

  // Initialize grouping controls
  function initGroupingControls(){
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
        console.log("Received open message:", data);
        
        // Populate objects list
        if (data.objects && Array.isArray(data.objects)) {
          console.log("Populating object list with", data.objects.length, "objects:", data.objects);
          populateObjectList(data.objects, true); // Store as allObjects for search
          // Clear search bar when loading new objects
          if (searchBar) searchBar.value = "";
        } else {
          console.log("No objects or invalid objects array:", data.objects);
        }
        
        // Update spawned objects list
        if (data.spawnedObjectsForList && Array.isArray(data.spawnedObjectsForList)) {
          console.log("Initial spawned objects:", data.spawnedObjectsForList);
          populateSpawnedObjectsList(data.spawnedObjectsForList);
        } else {
          console.log("No spawned objects or invalid format:", data.spawnedObjectsForList);
        }
        
        // Update user settings if provided
        if (data.userSettings) {
          console.log("User settings:", data.userSettings);
          updateUserSettingsDisplay(data.userSettings);
        }
        
        // Show UI
        showUI();
        
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
      
      case "log":
        addLogEntry(data.message, data.type || 'info');
        break;
      case "updateObjectList":
        if (data.objects && Array.isArray(data.objects)) {
          console.log("Updating object list from package selection:", data.objects);
          populateObjectList(data.objects, true); // Store as allObjects for search
          // Clear search bar when updating objects
          if (searchBar) searchBar.value = "";
        }
        break;
      case "updateSpawnedList":
        if (data.data && Array.isArray(data.data)) {
          console.log("Updating spawned objects list:", data.data);
          populateSpawnedObjectsList(data.data);
        }
        break;
      
      case "checkKeepMenuOpen":
        // Check localStorage and trigger menu reopen if enabled
        const keepMenuOpenSetting = localStorage.getItem('bazq_keepMenuOpen') === 'true';
        console.log('CheckKeepMenuOpen: localStorage setting is', keepMenuOpenSetting);
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
        
        console.log("Freecam state updated:", isActive);
        addLogEntry(`Freecam ${isActive ? 'enabled' : 'disabled'}`, 'info');
        break;
    }
  });

  function selectObject(index) {
    // Remove previous selection
    const previousSelected = document.querySelector('.compact-object-item.selected');
    if (previousSelected) {
      previousSelected.classList.remove('selected');
    }
    
    // Update selected index
    selectedObjectIndex = index;
    
    // Add selection to new item
    const newSelected = document.querySelector(`[data-index="${index}"]`);
    if (newSelected) {
      newSelected.classList.add('selected');
    }
    
    // Send NUI callback to server
    fetch('https://bazq-os/selectObject', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ index: parseInt(index) })
    }).then(() => {
      addLogEntry(`Selected object at index ${index}`, 'info');
    }).catch(error => {
      console.error("Error selecting object:", error);
      addLogEntry(`Failed to select object: ${error.message}`, 'error');
    });
  }

  // Rename placed object function
  function renamePlacedObject(index) {
    const currentName = filteredSpawnedObjectsCache[index]?.displayName || 
                       filteredSpawnedObjectsCache[index]?.model || 'Unknown';
    
    showRenameModal(index, currentName);
  }
  
  function showRenameModal(index, currentName) {
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
      () => executeRename(index, currentName), // onConfirm
      () => {} // onCancel (do nothing)
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
            executeRename(index, currentName);
          }
        });
      }
    }, 100);
  }
  
  function executeRename(index, originalName) {
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
      body: JSON.stringify({ index: parseInt(index), newName: newName })
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
      console.error("Error renaming object:", error);
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
            date = new Date(numTimestamp > 1000000000 ? numTimestamp * 1000 : numTimestamp);
          } else {
            date = new Date(timestamp);
          }
        }
      } else if (typeof timestamp === 'number') {
        // Handle timestamp as number - convert Unix timestamp (seconds) to milliseconds
        date = new Date(timestamp > 1000000000 ? timestamp * 1000 : timestamp);
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
        <button class="grid-action-btn rename-btn" data-index="${obj.originalIndex}" title="Rename">
          <i class="fas fa-tag"></i>
        </button>
        <button class="grid-action-btn edit-btn" data-index="${obj.originalIndex}" title="Edit">
          <i class="fas fa-edit"></i>
        </button>
        <button class="grid-action-btn duplicate-btn" data-index="${obj.originalIndex}" title="Duplicate">
          <i class="fas fa-copy"></i>
        </button>
        <button class="grid-action-btn delete-btn" data-index="${obj.originalIndex}" title="Delete">
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
        selectObject(obj.originalIndex);
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
        renamePlacedObject(obj.originalIndex);
      });
    }
    
    if (editBtn) {
      editBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        editPlacedObject(obj.originalIndex);
      });
    }
    
    if (duplicateBtn) {
      duplicateBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        duplicatePlacedObject(obj.originalIndex);
      });
    }
    
    if (deleteBtn) {
      deleteBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        deletePlacedObject(obj.originalIndex);
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
      () => {} // onCancel (do nothing)
    );
  }
  
  function executeGroupDelete(objects, groupTitle) {
    if (!objects || !groupTitle) return;
    
    // Show progress
    addLogEntry(`Deleting ${objects.length} objects from group "${groupTitle}"...`, 'info');
    
    // Delete all objects in the group
    let deletedCount = 0;
    const deletePromises = objects.map(obj => {
      return fetch('https://bazq-os/deleteObject', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ index: parseInt(obj.originalIndex) })
      }).then(() => {
        deletedCount++;
      }).catch(error => {
        console.error(`Failed to delete object ${obj.originalIndex}:`, error);
      });
    });
    
    Promise.all(deletePromises).then(() => {
      addLogEntry(`✅ Deleted ${deletedCount}/${objects.length} objects from group "${groupTitle}"`, 'success');
      
      // Remove deleted objects from local cache
      const deletedIndices = objects.map(obj => parseInt(obj.originalIndex));
      if (localSpawnedObjectsCache) {
        localSpawnedObjectsCache = localSpawnedObjectsCache.filter(obj => 
          !deletedIndices.includes(parseInt(obj.originalIndex))
        );
      }
      if (filteredSpawnedObjectsCache) {
        filteredSpawnedObjectsCache = filteredSpawnedObjectsCache.filter(obj => 
          !deletedIndices.includes(parseInt(obj.originalIndex))
        );
      }
      
      // Refresh the view with updated cache
      setTimeout(() => {
        applyMultiLevelGrouping();
      }, 100);
    });
  }

}); // End of DOMContentLoaded 