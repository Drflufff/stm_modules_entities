Star_Trek = Star_Trek or {}

local Access = Star_Trek.InterfacePanelAccess or {}
Star_Trek.InterfacePanelAccess = Access

local configCache

local function safeInclude(path)
    local ok, result = pcall(include, path)
    if ok then
        return result
    end
end

function Access:GetConfig()
    if configCache then
        return configCache
    end

    local data = safeInclude("star_trek/interface_panel_access_config.lua")
    if istable(data) then
        configCache = data
    else
        configCache = {
            defaultLocked = true,
            codes = {},
            interfaceLocks = {},
            maxCodeLength = 12,
        }
    end

    configCache.maxCodeLength = tonumber(configCache.maxCodeLength) or 12
    return configCache
end

function Access:IsEnabled(logType)
    logType = tostring(logType or "")
    local cfg = self:GetConfig()
    if istable(cfg.interfaceLocks) and cfg.interfaceLocks[logType] ~= nil then
        return cfg.interfaceLocks[logType] ~= false
    end
    return cfg.defaultLocked ~= false
end

function Access:DefaultLocked(logType)
    logType = tostring(logType or "")
    local cfg = self:GetConfig()
    if istable(cfg.interfaceLocks) and cfg.interfaceLocks[logType] ~= nil then
        return cfg.interfaceLocks[logType] ~= false
    end
    return cfg.defaultLocked ~= false
end

function Access:Validate(code)
    local cfg = self:GetConfig()
    local normalized = string.upper(string.Trim(tostring(code or "")))
    if normalized == "" then
        return
    end

    local matches = cfg.codes or {}
    for roleId, entry in pairs(matches) do
        local stored = entry.code or entry.Code
        if isstring(stored) then
            if string.upper(stored) == normalized then
                return roleId, entry
            end
        end
    end
end

function Access:GetRoleLabel(roleId, entry)
    if istable(entry) then
        if isstring(entry.label) and entry.label ~= "" then
            return entry.label
        end
        if isstring(entry.Label) and entry.Label ~= "" then
            return entry.Label
        end
    end

    if isstring(roleId) and roleId ~= "" then
        return string.upper(roleId)
    end

    return "AUTHORIZED"
end

function Access:GetMaxCodeLength()
    local cfg = self:GetConfig()
    return cfg.maxCodeLength or 12
end

function Access:GetKeyLayout()
    -- Layout is six columns of alphanumeric keys; adjust if codes require more characters.
    if Access._KeyLayout then
        return Access._KeyLayout
    end

    local rows = {
        {"1", "2", "3", "4", "5", "6"},
        {"7", "8", "9", "0", "A", "B"},
        {"C", "D", "E", "F", "G", "H"},
        {"I", "J", "K", "L", "M", "N"},
        {"O", "P", "Q", "R", "S", "T"},
        {"U", "V", "W", "X", "Y", "Z"},
    }

    Access._KeyLayout = rows
    return rows
end

return Access
