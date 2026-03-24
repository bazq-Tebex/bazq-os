Locales = {}

Locales['en'] = {
    ['access_denied'] = "Access denied - insufficient permissions",
    ['missing_fields'] = "Missing required fields",
    ['user_exists'] = "User with this identifier already exists",
    ['only_owners_create'] = "Only owners can create other owners",
    ['user_added_success'] = "User added successfully",
    ['user_not_found'] = "User not found",
    ['cannot_modify_self'] = "Cannot modify your own role",
    ['admins_only_mappers'] = "Admins can only modify mappers",
    ['only_owners_promote'] = "Only owners can promote users to owner",
    ['role_updated_success'] = "User role updated successfully",
    ['cannot_delete_self'] = "Cannot delete yourself - this would cause lockout",
    ['user_deleted_success'] = "User deleted successfully",
    ['cleared_mappers'] = "Cleared %s mapper(s)",
    ['no_permission_os'] = "You do not have permission to use bazq-os",
    ['notify_contact_admin'] = "Contact an administrator to get access. Your identifier: %s"
}

Locales['tr'] = {
    ['access_denied'] = "Erişim reddedildi - yetkiniz yetersiz",
    ['missing_fields'] = "Gerekli alanlar eksik",
    ['user_exists'] = "Bu kimliğe sahip bir kullanıcı zaten var",
    ['only_owners_create'] = "Sadece 'Owner'lar başka 'Owner' oluşturabilir",
    ['user_added_success'] = "Kullanıcı başarıyla eklendi",
    ['user_not_found'] = "Kullanıcı bulunamadı",
    ['cannot_modify_self'] = "Kendi rolünüzü değiştiremezsiniz",
    ['admins_only_mappers'] = "Adminler sadece mapperları değiştirebilir",
    ['only_owners_promote'] = "Sadece 'Owner'lar başka 'Owner' yapabilir",
    ['role_updated_success'] = "Kullanıcı rolü başarıyla güncellendi",
    ['cannot_delete_self'] = "Kendinizi silemezsiniz - bu erişiminizi engeller",
    ['user_deleted_success'] = "Kullanıcı başarıyla silindi",
    ['cleared_mappers'] = "%s mapper temizlendi",
    ['no_permission_os'] = "bazq-os kullanmak için izniniz yok",
    ['notify_contact_admin'] = "Erişim için bir yönetici ile iletişime geçin. ID'niz: %s"
}

function L(key, ...)
    local locale = Config.Locale or 'en'
    if not Locales[locale] then locale = 'en' end
    
    local str = Locales[locale][key]
    if not str then
        str = Locales['en'][key] -- fallback to english
        if not str then
            return "Translation Missing: [" .. key .. "]"
        end
    end
    
    if select('#', ...) > 0 then
        return string.format(str, ...)
    end
    return str
end
