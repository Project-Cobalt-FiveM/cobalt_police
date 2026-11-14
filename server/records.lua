---@class PoliceCharge
---@field id integer
---@field category string
---@field code string
---@field title string
---@field description string
---@field class PoliceChargeClass
---@field months integer
---@field fine integer
---@field points integer
---@field stackable integer|boolean 1 or true when the charge can be filed more than once

local Records <const> = {}

local CHARGE_COLUMNS <const> = 'id, category, code, title, description, class, months, fine, points, stackable = 1 AS stackable'

---@return PoliceCharge[]
function Records.charges()
    return MySQL.query.await(
        ('SELECT %s FROM police_charges ORDER BY category, title LIMIT 1000'):format(CHARGE_COLUMNS)
    ) or {}
end

---@param ids integer[]
---@return table<integer, PoliceCharge>
function Records.chargesById(ids)
    local out <const> = {}

    if #ids == 0 then
        return out
    end

    local rows <const> = MySQL.query.await(
        ('SELECT %s FROM police_charges WHERE id IN (?) ORDER BY id'):format(CHARGE_COLUMNS),
        { ids }
    )

    for _, row in ipairs(rows or {}) do
        out[row.id] = row
    end

    return out
end

---@param citizenid string
---@return PoliceConviction[]
function Records.convictions(citizenid)
    return MySQL.query.await([[
        SELECT id, title, code, class, counts, months, fine, points, incident_id AS incidentId, UNIX_TIMESTAMP(created_at) AS createdAt
        FROM police_convictions WHERE citizenid = ? ORDER BY created_at DESC, id DESC LIMIT 500
    ]], { citizenid }) or {}
end

---@param citizenid string
---@param entries PoliceRecordEntry[]
---@param sentencedBy? string
---@return boolean
function Records.add(citizenid, entries, sentencedBy)
    if type(citizenid) ~= 'string' or type(entries) ~= 'table' or #entries == 0 then return false end

    local rows <const> = {}

    for i, entry in ipairs(entries) do
        rows[i] = {
            citizenid,
            entry.chargeId,
            entry.title:sub(1, 255),
            tostring(entry.code or ''):sub(1, 50),
            entry.class or 'misdemeanor',
            math.max(1, math.floor(tonumber(entry.counts) or 1)),
            math.max(0, math.floor(tonumber(entry.months) or 0)),
            math.max(0, math.floor(tonumber(entry.fine) or 0)),
            math.max(0, math.floor(tonumber(entry.points) or 0)),
            entry.incidentId,
            sentencedBy,
        }
    end

    MySQL.prepare.await([[
        INSERT INTO police_convictions (citizenid, charge_id, title, code, class, counts, months, fine, points, incident_id, sentenced_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], rows)

    return true
end

return Records
