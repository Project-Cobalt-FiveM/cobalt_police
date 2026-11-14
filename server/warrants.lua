---@alias WarrantStatus 'active'|'served'|'cancelled'|'expired'

---@class WarrantCounts
---@field active integer
---@field served integer
---@field expired integer
---@field cancelled integer
---@field ending integer active warrants that end within the warning window

local Warrants <const> = {}

local STATUSES <const> = { 'active', 'served', 'cancelled', 'expired' }

local WARRANT_SELECT <const> = [[
    SELECT w.id, w.citizenid, p.fullname AS name,
        w.type, w.title, w.description, w.status, w.issued_by AS issuedBy, w.incident_id AS incidentId,
        UNIX_TIMESTAMP(w.expires_at) AS expiresAt, UNIX_TIMESTAMP(w.created_at) AS createdAt
    FROM police_warrants w JOIN players p ON p.citizenid = w.citizenid
]]

local BOLO_SELECT <const> = [[
    SELECT id, type, department, title, description, citizenid, plate, person_name AS personName, last_seen AS lastSeen, status,
        issued_by AS issuedBy, UNIX_TIMESTAMP(created_at) AS createdAt
    FROM police_bolos
]]

local COUNTS <const> = [[
    SELECT
        COUNT(CASE WHEN status = 'active' THEN 1 END) AS active,
        COUNT(CASE WHEN status = 'served' THEN 1 END) AS served,
        COUNT(CASE WHEN status = 'expired' THEN 1 END) AS expired,
        COUNT(CASE WHEN status = 'cancelled' THEN 1 END) AS cancelled,
        COUNT(CASE WHEN status = 'active' AND expires_at <= NOW() + INTERVAL ? HOUR THEN 1 END) AS ending
    FROM police_warrants
]]

---@param value any
---@return boolean
function Warrants.isStatus(value)
    return lib.table.contains(STATUSES, value)
end

---@param status WarrantStatus
---@return PoliceWarrant[]
function Warrants.list(status)
    return MySQL.query.await(
        WARRANT_SELECT .. ' WHERE w.status = ? ORDER BY w.created_at DESC LIMIT 200',
        { status }
    ) or {}
end

---@param warnHours integer
---@return WarrantCounts
function Warrants.counts(warnHours)
    return MySQL.single.await(COUNTS, { warnHours })
end

---@param citizenid string
---@param activeOnly? boolean
---@return PoliceWarrant[]
function Warrants.forCitizen(citizenid, activeOnly)
    local filter <const> = activeOnly and " AND w.status = 'active'" or ''

    return MySQL.query.await(
        WARRANT_SELECT .. ' WHERE w.citizenid = ?' .. filter .. ' ORDER BY w.created_at DESC LIMIT 100',
        { citizenid }
    ) or {}
end

---@param data { citizenid: string, type?: PoliceWarrantType, title: string, description?: string, expiresInDays?: integer, incidentId?: integer }
---@param issuedBy string
---@return integer?
function Warrants.create(data, issuedBy)
    if type(data?.citizenid) ~= 'string' or type(data.title) ~= 'string' or data.title == '' then return end

    local warrantType = data.type

    if warrantType ~= 'search' and warrantType ~= 'bench' then
        warrantType = 'arrest'
    end

    local days <const> = math.floor(tonumber(data.expiresInDays) or 0)
    local id <const> = MySQL.insert.await([[
        INSERT INTO police_warrants (citizenid, type, title, description, issued_by, expires_at, incident_id)
        SELECT citizenid, ?, ?, ?, ?, IF(? > 0, NOW() + INTERVAL ? DAY, NULL), (SELECT id FROM police_cases WHERE id = ?)
        FROM players WHERE citizenid = ?
    ]], {
        warrantType,
        data.title:sub(1, 255),
        tostring(data.description or ''),
        issuedBy,
        days,
        days,
        tonumber(data.incidentId),
        data.citizenid,
    })

    return id ~= 0 and id or nil
end

---@param id integer
---@param days integer
---@return boolean
function Warrants.extend(id, days)
    days = math.floor(tonumber(days) or 0)

    if days <= 0 then return false end

    return MySQL.update.await([[
        UPDATE police_warrants SET expires_at = GREATEST(expires_at, NOW()) + INTERVAL ? DAY,
            status = IF(status = 'expired', 'active', status)
        WHERE id = ? AND status IN ('active', 'expired') AND expires_at IS NOT NULL
    ]], { days, id }) == 1
end

---@param id integer
---@param status WarrantStatus
---@return boolean
function Warrants.setStatus(id, status)
    if not Warrants.isStatus(status) then return false end

    return MySQL.update.await('UPDATE police_warrants SET status = ? WHERE id = ?', { status, id }) == 1
end

---@param citizenid string
function Warrants.serveAll(citizenid)
    MySQL.update.await(
        "UPDATE police_warrants SET status = 'served' WHERE citizenid = ? AND status = 'active' AND type = 'arrest'",
        { citizenid }
    )
end

---@param status 'active'|'cancelled'|'all'
---@return PoliceBolo[]
function Warrants.bolos(status)
    if status == 'all' then
        return MySQL.query.await(BOLO_SELECT .. ' ORDER BY created_at DESC LIMIT 200') or {}
    end

    return MySQL.query.await(BOLO_SELECT .. ' WHERE status = ? ORDER BY created_at DESC LIMIT 200', { status }) or {}
end

---@param filter { plate?: string, citizenid?: string }
---@return PoliceBolo[]
function Warrants.activeBolos(filter)
    return MySQL.query.await(BOLO_SELECT .. [[
        WHERE status = 'active' AND (? IS NULL OR plate = ?) AND (? IS NULL OR citizenid = ?)
        ORDER BY created_at DESC LIMIT 100
    ]], { filter.plate, filter.plate, filter.citizenid, filter.citizenid }) or {}
end

---@param data table
---@param issuedBy string
---@param department? string
---@return integer?
function Warrants.createBolo(data, issuedBy, department)
    if type(data?.title) ~= 'string' or data.title == '' then return end

    local plate <const> = type(data.plate) == 'string' and data.plate ~= '' and data.plate:upper():sub(1, 16) or nil

    return MySQL.insert.await([[
        INSERT INTO police_bolos (type, department, title, description, citizenid, plate, person_name, last_seen, issued_by)
        VALUES (?, ?, ?, ?, (SELECT citizenid FROM players WHERE citizenid = ?), ?, ?, ?, ?)
    ]], {
        data.type == 'vehicle' and 'vehicle' or 'person',
        department or 'police',
        data.title:sub(1, 255),
        tostring(data.description or ''),
        data.citizenid,
        plate,
        tostring(data.personName or ''):sub(1, 100),
        tostring(data.lastSeen or ''):sub(1, 255),
        issuedBy,
    })
end

---@param id integer
---@param status 'active'|'cancelled'
---@return boolean
function Warrants.setBoloStatus(id, status)
    if status ~= 'active' and status ~= 'cancelled' then return false end

    return MySQL.update.await('UPDATE police_bolos SET status = ? WHERE id = ?', { status, id }) == 1
end

lib.cron.new('*/15 * * * *', function()
    MySQL.update.await(
        "UPDATE police_warrants SET status = 'expired' WHERE status = 'active' AND expires_at IS NOT NULL AND expires_at <= NOW()"
    )
end)

return Warrants
