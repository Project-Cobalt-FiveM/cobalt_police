local config <const> = require 'config'
local officers <const> = require 'server.officers'

---@alias PolicePermission 'createIncident'|'editIncident'|'deleteIncident'|'editProfile'|'manageWarrants'|'manageBolos'|'postBulletins'|'managePenalCode'|'manageTags'|'manageRanks'|'manageCertificates'|'manageTemplates'|'deleteEvidence'|'administrator'

local PERMISSIONS <const> = {
    'createIncident', 'editIncident', 'deleteIncident', 'editProfile', 'manageWarrants', 'manageBolos',
    'postBulletins', 'managePenalCode', 'manageTags', 'manageRanks', 'manageCertificates', 'manageTemplates',
    'deleteEvidence', 'administrator',
}

local POLICE_PAGES <const> = {
    'dashboard', 'dispatch', 'citizens', 'vehicles', 'weapons', 'properties', 'incidents', 'warrants', 'bolos',
    'evidence', 'penalcode', 'roster',
}

local Access <const> = { permissionKeys = PERMISSIONS }

---@type table
local settings

---@param base table
---@param over table
---@return table
local function merge(base, over)
    local out <const> = table.clone(base)

    for key, value in pairs(over) do
        if type(value) == 'table' and type(out[key]) == 'table' then
            out[key] = merge(out[key], value)
        elseif out[key] ~= nil and type(value) == type(out[key]) then
            out[key] = value
        end
    end

    return out
end

---@return table
function Access.settings()
    if not settings then
        local stored <const> = MySQL.scalar.await('SELECT data FROM police_settings WHERE id = 1')
        settings = merge(config.defaultSettings, stored and json.decode(stored) or {})
    end

    return settings
end

---@param data table
function Access.saveSettings(data)
    settings = merge(config.defaultSettings, data)

    MySQL.update.await(
        'INSERT INTO police_settings (id, data) VALUES (1, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)',
        { json.encode(settings) }
    )

    GlobalState.policeSettings = settings
end

---@param value boolean
---@return table<PolicePermission, boolean>
local function filled(value)
    local out <const> = {}

    for _, key in ipairs(PERMISSIONS) do
        out[key] = value
    end

    return out
end

---@type table<string, table<PolicePermission, boolean>>
local rankCache <const> = {}

---@param department string
---@param grade integer
---@return string
local function rankKey(department, grade)
    return ('%s:%d'):format(department, grade)
end

---@param stored table
---@return table<PolicePermission, boolean>
local function rankShape(stored)
    local out <const> = filled(false)

    for key, value in pairs(stored) do
        if out[key] ~= nil then
            out[key] = value == true
        end
    end

    return out
end

---@param department string
---@param grade integer
---@return table<PolicePermission, boolean>
function Access.rankPermissions(department, grade)
    local key <const> = rankKey(department, grade)

    if rankCache[key] then return rankCache[key] end

    local stored <const> = MySQL.scalar.await(
        'SELECT permissions FROM police_ranks WHERE department = ? AND grade = ?',
        { department, grade }
    )

    rankCache[key] = rankCache[key] or rankShape(stored and json.decode(stored) or {})

    return rankCache[key]
end

---@param department string
---@param grade integer
---@param permissions table<PolicePermission, boolean>
function Access.saveRankPermissions(department, grade, permissions)
    MySQL.insert.await([[
        INSERT INTO police_ranks (department, grade, permissions) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE permissions = VALUES(permissions)
    ]], { department, grade, json.encode(permissions) })

    rankCache[rankKey(department, grade)] = rankShape(permissions)
end

---@param source integer
---@return table<PolicePermission, boolean>
function Access.permissions(source)
    local job <const> = officers.job(source)

    if not job or not officers.isLeo(source) then
        return filled(false)
    end

    if job.isBoss then
        return filled(true)
    end

    local out <const> = Access.rankPermissions(job.name, job.grade)

    if out.administrator then
        return filled(true)
    end

    return out
end

---@param source integer
---@param permission PolicePermission
---@return boolean
function Access.can(source, permission)
    local permissions <const> = Access.permissions(source)

    return permissions.administrator or permissions[permission] == true
end

---@param source integer
---@return boolean
function Access.canOpen(source)
    if officers.isLeo(source) then
        return true
    end

    return officers.isEms(source) and Access.settings().records.emsAccess
end

---@param permissions table<PolicePermission, boolean>
---@return boolean
local function canManage(permissions)
    if permissions.administrator or permissions.manageRanks or permissions.manageTags then
        return true
    end

    return permissions.manageCertificates or permissions.manageTemplates or permissions.managePenalCode
end

---@param source integer
---@return string[]
function Access.pages(source)
    if not officers.isLeo(source) then
        return Access.canOpen(source) and config.emsPages or {}
    end

    local pages <const> = table.clone(POLICE_PAGES)

    if canManage(Access.permissions(source)) then
        pages[#pages + 1] = 'management'
    end

    return pages
end

CreateThread(function()
    GlobalState.policeSettings = Access.settings()
end)

return Access
