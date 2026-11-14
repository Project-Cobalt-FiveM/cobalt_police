local config <const> = require 'config'
local officers <const> = require 'server.officers'
local records <const> = require 'server.records'
local jail <const> = require 'server.jail'
local warrants <const> = require 'server.warrants'
local log <const> = require 'server.log'
local licences <const> = require 'server.licences'
local Cobalt <const> = exports.cobalt_core:GetCoreObject()

---@class CasePerson
---@field citizenid string?
---@field name string

---@class CaseSuspect : CasePerson
---@field charges { chargeId: integer, counts: integer }[]

---@class PoliceCase
---@field id integer?
---@field kind 'incident'|'report'
---@field status 'draft'|'filed'
---@field title string
---@field location string
---@field coords { x: number, y: number, z: number }?
---@field occurredAt integer
---@field narrative string
---@field officers CasePerson[]
---@field suspects CaseSuspect[]
---@field witnesses CasePerson[]
---@field evidence { id: integer }[]
---@field author string
---@field authorCid string?
---@field updatedAt integer

---@class SentenceResult
---@field citizenid string?
---@field name string
---@field months integer
---@field fine integer
---@field points integer
---@field jailed boolean
---@field suspended string[]

local Cases <const> = {}

local MAX_PEOPLE <const> = 50

local MAX_CHARGES <const> = 50

local MAX_COUNTS <const> = 99

local PEOPLE_INSERT <const> = 'INSERT INTO police_case_people (incident_id, role, citizenid, name, charges) VALUES '

local PERSON_VALUES <const> = "(?, ?, (SELECT citizenid FROM players WHERE citizenid = NULLIF(?, '')), ?, NULLIF(?, ''))"

local SUMMARY_SELECT <const> = [[
    SELECT c.id, c.kind, c.status, c.title, c.location, c.author, c.author_cid AS authorCid, UNIX_TIMESTAMP(c.occurred_at) AS occurredAt,
        (SELECT COUNT(*) FROM police_case_people p WHERE p.incident_id = c.id AND p.role = 'suspect') AS suspects
    FROM police_cases c
]]

---@param query string
---@param kind 'incident'|'report'|'all'
---@param limit? integer defaults to 100
---@return table[]
function Cases.list(query, kind, limit)
    local pattern <const> = ('%%%s%%'):format(tostring(query or ''):gsub('[\\%%_]', '\\%0'))

    return MySQL.query.await(SUMMARY_SELECT .. [[
        WHERE (? = 'all' OR c.kind = ?)
            AND (c.title LIKE ? OR c.location LIKE ? OR c.id = ?
                OR c.id IN (SELECT incident_id FROM police_case_people WHERE name LIKE ?))
        ORDER BY c.occurred_at DESC, c.id DESC LIMIT ?
    ]], { kind, kind, pattern, pattern, tonumber(query) or 0, pattern, limit or 100 }) or {}
end

---@param limit integer
---@return table[]
function Cases.recent(limit)
    return MySQL.query.await(
        SUMMARY_SELECT .. " WHERE c.status = 'filed' ORDER BY c.occurred_at DESC, c.id DESC LIMIT ?",
        { limit }
    ) or {}
end

---@param citizenid string
---@return table[]
function Cases.forCitizen(citizenid)
    return MySQL.query.await(SUMMARY_SELECT .. [[
        WHERE c.id IN (SELECT incident_id FROM police_case_people WHERE citizenid = ?)
        ORDER BY c.occurred_at DESC LIMIT 50
    ]], { citizenid }) or {}
end

---@param id integer
---@return PoliceCase?
function Cases.get(id)
    local row <const> = MySQL.single.await([[
        SELECT id, kind, status, title, location, coords, narrative, author, author_cid AS authorCid,
            UNIX_TIMESTAMP(occurred_at) AS occurredAt, UNIX_TIMESTAMP(updated_at) AS updatedAt
        FROM police_cases WHERE id = ?
    ]], { id })

    if not row then return end

    row.coords = row.coords and json.decode(row.coords) or nil
    row.officers, row.suspects, row.witnesses = {}, {}, {}

    local people <const> = MySQL.query.await(
        'SELECT role, citizenid, name, charges FROM police_case_people WHERE incident_id = ? ORDER BY id',
        { id }
    )

    for _, person in ipairs(people or {}) do
        local entry <const> = { citizenid = person.citizenid, name = person.name }

        if person.role == 'suspect' then
            entry.charges = person.charges and json.decode(person.charges) or {}
            row.suspects[#row.suspects + 1] = entry
        else
            local list <const> = person.role == 'officer' and row.officers or row.witnesses
            list[#list + 1] = entry
        end
    end

    row.evidence = MySQL.query.await([[
        SELECT id, CONCAT(IF(type = 'forensic', 'FS-', 'EV-'), LPAD(id, 4, '0')) AS code, title
        FROM police_evidence WHERE incident_id = ? ORDER BY id
    ]], { id }) or {}

    return row
end

---@param list any
---@param withCharges? boolean
---@return table[]
local function people(list, withCharges)
    local out <const> = {}

    if type(list) ~= 'table' then
        return out
    end

    for _, person in ipairs(list) do
        if #out >= MAX_PEOPLE then
            break
        end

        if type(person) ~= 'table' then
            goto continue
        end

        local entry <const> = {
            citizenid = type(person.citizenid) == 'string' and person.citizenid ~= '' and person.citizenid or nil,
            name = tostring(person.name or locale('mdt.unknown_person')):sub(1, 100),
        }

        if withCharges then
            entry.charges = {}

            local byId <const> = {}

            for _, charge in ipairs(type(person.charges) == 'table' and person.charges or {}) do
                local chargeId <const> = type(charge) == 'table' and tonumber(charge.chargeId)
                local counts <const> = type(charge) == 'table' and math.floor(tonumber(charge.counts) or 1) or 0

                if chargeId and counts > 0 then
                    local listed <const> = byId[chargeId]

                    if listed then
                        listed.counts = math.min(listed.counts + counts, MAX_COUNTS)
                    elseif #entry.charges < MAX_CHARGES then
                        byId[chargeId] = { chargeId = chargeId, counts = math.min(counts, MAX_COUNTS) }
                        entry.charges[#entry.charges + 1] = byId[chargeId]
                    end
                end
            end
        end

        out[#out + 1] = entry

        ::continue::
    end

    return out
end

---@param source integer
---@param data table
---@param status 'draft'|'filed'
---@return integer? id
---@return string? err
function Cases.save(source, data, status)
    if type(data) ~= 'table' or type(data.title) ~= 'string' or data.title == '' then
        return nil, locale('mdt.error.incident_title')
    end

    local id = tonumber(data.id)

    if id and MySQL.scalar.await("SELECT status FROM police_cases WHERE id = ?", { id }) == 'filed' then
        return nil, locale('mdt.error.incident_locked')
    end

    local kind <const> = data.kind == 'report' and 'report' or 'incident'
    local fields <const> = {
        kind,
        status,
        data.title:sub(1, 255),
        tostring(data.location or ''):sub(1, 255),
        type(data.coords) == 'table' and json.encode({
            x = tonumber(data.coords.x),
            y = tonumber(data.coords.y),
            z = tonumber(data.coords.z),
        }) or nil,
        tostring(data.narrative or ''),
        math.floor(tonumber(data.occurredAt) or os.time()),
    }

    local groups <const> = {
        { 'officer', people(data.officers) },
        { 'suspect', kind == 'incident' and people(data.suspects, true) or {} },
        { 'witness', people(data.witnesses) },
    }
    local rows <const> = {}

    for _, group in ipairs(groups) do
        for _, person in ipairs(group[2]) do
            rows[#rows + 1] = {
                group[1],
                person.citizenid or '',
                person.name,
                person.charges and json.encode(person.charges) or '',
            }
        end
    end

    local evidenceIds <const> = {}

    for _, item in ipairs(type(data.evidence) == 'table' and data.evidence or {}) do
        if tonumber(item.id) then
            evidenceIds[#evidenceIds + 1] = tonumber(item.id)
        end
    end

    local ok <const> = MySQL.startTransaction(function(query)
        if id then
            local updated <const> = query([[
                UPDATE police_cases SET kind = ?, status = ?, title = ?, location = ?, coords = ?, narrative = ?, occurred_at = FROM_UNIXTIME(?)
                WHERE id = ? AND status = 'draft'
            ]], { fields[1], fields[2], fields[3], fields[4], fields[5], fields[6], fields[7], id })

            if updated.affectedRows == 0 then
                return false
            end

            query('DELETE FROM police_case_people WHERE incident_id = ?', { id })
            query('UPDATE police_evidence SET incident_id = NULL WHERE incident_id = ?', { id })
        else
            id = query([[
                INSERT INTO police_cases (kind, status, title, location, coords, narrative, occurred_at, author, author_cid)
                VALUES (?, ?, ?, ?, ?, ?, FROM_UNIXTIME(?), ?, ?)
            ]], {
                fields[1],
                fields[2],
                fields[3],
                fields[4],
                fields[5],
                fields[6],
                fields[7],
                officers.name(source),
                officers.citizenid(source),
            }).insertId
        end

        if #rows > 0 then
            local values <const> = {}

            for _, row in ipairs(rows) do
                values[#values + 1] = id
                table.move(row, 1, 4, #values + 1, values)
            end

            query(PEOPLE_INSERT .. PERSON_VALUES:rep(#rows, ', '), values)
        end

        if #evidenceIds > 0 then
            query(
                'UPDATE police_evidence SET incident_id = ? WHERE id IN (?) AND (incident_id IS NULL OR incident_id = ?)',
                { id, evidenceIds, id }
            )
        end

        return true
    end)

    if not ok then
        return nil, locale('mdt.error.incident_not_saved')
    end

    return id
end

---@param citizenid string
---@param amount integer
---@return boolean paid
local function fine(citizenid, amount)
    if amount <= 0 then return true end

    local player <const> = Cobalt.Functions.GetPlayerByCitizenId(citizenid)
        or Cobalt.Functions.GetOfflinePlayerByCitizenId(citizenid)

    return player ~= nil and player.Functions.RemoveMoney('bank', amount, 'police-fine') == true
end

---@param source integer
---@param id integer
---@param suspect CaseSuspect
---@param charges table<integer, PoliceCharge>
---@param title string
---@return SentenceResult
local function sentence(source, id, suspect, charges, title)
    local result <const> = {
        citizenid = suspect.citizenid,
        name = suspect.name,
        months = 0,
        fine = 0,
        points = 0,
        jailed = false,
        suspended = {},
    }
    local entries <const> = {}

    for _, item in ipairs(suspect.charges or {}) do
        local charge <const> = charges[item.chargeId]

        if charge then
            local stackable <const> = charge.stackable == 1 or charge.stackable == true
            local counts <const> = stackable and item.counts or 1

            result.months += charge.months * counts
            result.fine += charge.fine * counts
            result.points += charge.points * counts
            entries[#entries + 1] = {
                chargeId = charge.id,
                title = charge.title,
                code = charge.code,
                class = charge.class,
                counts = counts,
                months = charge.months * counts,
                fine = charge.fine * counts,
                points = charge.points * counts,
                incidentId = id,
            }
        end
    end

    local citizenid <const> = suspect.citizenid

    if not citizenid or #entries == 0 then
        return result
    end

    local by <const> = officers.citizenid(source)

    records.add(citizenid, entries, by)
    if not fine(citizenid, result.fine) then
        officers.notify(source, locale('mdt.fine_unpaid', suspect.name or citizenid, result.fine), 'error')
    end
    result.suspended = licences.addPoints(citizenid, result.points)

    if result.months > 0 then
        local target <const> = officers.sourceOf(citizenid)

        if target then
            result.jailed = jail.extend(target, result.months) or jail.jail(target, result.months, title, by, id) ~= nil
        else
            jail.queue(citizenid, result.months, title, by, id)
        end

        warrants.serveAll(citizenid)
    end

    log('sentence', by, citizenid, {
        incident = id,
        months = result.months,
        fine = result.fine,
        points = result.points,
    })

    return result
end

---@param source integer
---@param data table
---@return integer? id
---@return SentenceResult[]|string results
function Cases.file(source, data)
    local id <const>, err <const> = Cases.save(source, data, 'filed')

    if not id then
        return nil, err or locale('mdt.error.incident_not_filed')
    end

    local filed <const> = Cases.get(id) --[[@as PoliceCase]]
    local chargeIds <const> = {}

    for _, suspect in ipairs(filed.suspects) do
        for _, item in ipairs(suspect.charges) do
            chargeIds[#chargeIds + 1] = item.chargeId
        end
    end

    local charges <const> = records.chargesById(chargeIds)
    local results <const> = {}

    for _, suspect in ipairs(filed.suspects) do
        results[#results + 1] = sentence(source, id, suspect, charges, filed.title)
    end

    return id, results
end

---@param id integer
---@return boolean
function Cases.delete(id)
    return MySQL.update.await('DELETE FROM police_cases WHERE id = ?', { id }) == 1
end

return Cases
