local config <const> = require 'config'
local officers <const> = require 'server.officers'
local log <const> = require 'server.log'

local core <const> = exports.cobalt_core
local rules <const> = config.licences

---@alias PoliceLicenceStatus 'valid'|'none'|'revoked'|'suspended'

---@class PoliceLicence
---@field key string
---@field label string
---@field status PoliceLicenceStatus
---@field points integer
---@field pointsLimit integer?

local Licences <const> = {}

---@param key string
---@return string?
local function labelOf(key)
    local info <const> = core:GetLicenseTypes()[key]

    return info and info.label:lower()
end

---@param source integer?
---@param action 'grant'|'revoke'
---@param citizenid string
---@param key string
---@param reason? string
local function record(source, action, citizenid, key, reason)
    local officer <const> = source and officers.citizenid(source)

    local detail <const> = { action = action, key = key, reason = reason }

    log('licence', officer, citizenid, detail, source, officers.sourceOf(citizenid))
end

---@param source integer
---@return boolean
function Licences.canManage(source)
    local job <const> = officers.isOnDuty(source) and officers.job(source)

    return job and (job.isBoss or job.grade >= rules.grantGrade) or false
end

---@param entry LicenseRecord
---@return PoliceLicenceStatus
local function statusOf(entry)
    if entry.held then return 'valid' end
    if not entry.revokedAt then return 'none' end

    return entry.pointsLimit and entry.points >= entry.pointsLimit and 'suspended' or 'revoked'
end

---@param citizenid string
---@param records? table<string, table> the citizen's records when the caller already has them
---@return PoliceLicence[]
function Licences.list(citizenid, records)
    records = records or core:GetLicenseRecords(citizenid) or {}

    local out <const> = {}

    for key, info in pairs(core:GetLicenseTypes()) do
        local entry <const> = records[key] or { held = false, points = 0 }

        out[#out + 1] = {
            key = key,
            label = info.label,
            status = statusOf(entry),
            points = entry.points,
            pointsLimit = info.pointsLimit,
        }
    end

    table.sort(out, function(a, b) return a.label < b.label end)

    return out
end

---@param source integer the officer
---@param citizenid string
---@param key string
---@return boolean ok
---@return string? reason
function Licences.grant(source, citizenid, key)
    if not Licences.canManage(source) then return false, locale('licences.cannot_grant') end

    local label <const> = labelOf(key)

    if not label then return false, locale('licences.unknown') end

    local issuer <const> = officers.departmentText(officers.job(source).name, 'label') or locale('licences.issuer')

    if not core:GrantLicense(citizenid, key, issuer) then
        return false, locale('licences.already_held', label)
    end

    record(source, 'grant', citizenid, key)

    local target <const> = officers.sourceOf(citizenid)

    if target then officers.notify(target, locale('licences.granted_you', label), 'success') end

    return true
end

---@param source integer the officer
---@param citizenid string
---@param key string
---@param reason? string
---@return boolean ok
---@return string? reason
function Licences.revoke(source, citizenid, key, reason)
    if not Licences.canManage(source) then return false, locale('licences.cannot_revoke') end

    local label <const> = labelOf(key)

    if not label then return false, locale('licences.unknown') end
    if not core:RevokeLicense(citizenid, key) then return false, locale('licences.not_held', label) end

    record(source, 'revoke', citizenid, key, reason)

    return true
end

---@param citizenid string
---@param amount integer
---@return string[] suspended
function Licences.addPoints(citizenid, amount)
    local key <const> = rules.pointsKey
    local _, revoked <const> = core:AddLicensePoints(citizenid, key, amount)

    if not revoked then return {} end

    record(nil, 'revoke', citizenid, key, 'Points limit reached')

    return { key }
end

lib.addCommand('grantlicense', {
    help = locale('licences.command.help'),
    params = {
        { name = 'id', type = 'playerId', help = locale('licences.command.id') },
        { name = 'licence', type = 'string', help = locale('licences.command.licence') },
    },
}, function(source, args)
    if not officers.isOnDuty(source) then return officers.notify(source, locale('licences.off_duty'), 'error') end

    local citizenid <const> = officers.citizenid(args.id)

    if not citizenid then return officers.notify(source, locale('licences.player_missing'), 'error') end

    local key <const> = args.licence:lower()
    local ok <const>, reason <const> = Licences.grant(source, citizenid, key)

    if not ok then return officers.notify(source, reason --[[@as string]], 'error') end

    officers.notify(source, locale('licences.granted', labelOf(key)), 'success')
end)

return Licences
