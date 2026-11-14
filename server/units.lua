local officers <const> = require 'server.officers'

---@class PoliceUnit
---@field id integer
---@field callsign string
---@field department string
---@field status UnitStatus
---@field members DispatchResponder[]

local Units <const> = {}

local STATUSES <const> = { available = true, busy = true, enroute = true, onscene = true }

---@type PoliceUnit[] sorted by callsign
local units <const> = {}

---@type table<integer, string> member source to citizenid
local memberIds <const> = {}

local lastId = 0

---@return PoliceUnit[]
function Units.list()
    return units
end

---@param id integer
---@return PoliceUnit?
function Units.get(id)
    for _, unit in ipairs(units) do
        if unit.id == id then
            return unit
        end
    end
end

---@param citizenid string
---@return PoliceUnit?
---@return integer? index the member's place in the unit
local function find(citizenid)
    for _, unit in ipairs(units) do
        for i, member in ipairs(unit.members) do
            if member.citizenid == citizenid then
                return unit, i
            end
        end
    end
end

---@param citizenid string
---@return { id: integer, callsign: string, status: UnitStatus }?
function Units.of(citizenid)
    local unit <const> = find(citizenid)

    if not unit then return end

    return { id = unit.id, callsign = unit.callsign, status = unit.status }
end

local function push()
    for _, source in ipairs(officers.byJobTypes({ 'leo', 'ems' }, true)) do
        if Player(source).state.mdtTablet then
            TriggerClientEvent('cobalt_police:unitsUpdated', source, units)
        end
    end
end

---@param unit PoliceUnit
local function drop(unit)
    for i, entry in ipairs(units) do
        if entry == unit then
            table.remove(units, i)

            return
        end
    end
end

---@param source integer
---@return boolean removed
local function detach(source)
    local citizenid <const> = memberIds[source]

    if not citizenid then return false end

    memberIds[source] = nil

    local unit <const>, index <const> = find(citizenid)

    if not unit or not index then return false end

    table.remove(unit.members, index)

    if #unit.members == 0 then drop(unit) end

    return true
end

---@param a PoliceUnit
---@param b PoliceUnit
---@return boolean
local function byCallsign(a, b)
    return a.callsign < b.callsign
end

---@param callsign string
---@param department string
---@param founder integer source of the officer who creates the unit and joins it
---@return integer? id
function Units.create(callsign, department, founder)
    if type(callsign) ~= 'string' or callsign == '' or not officers.citizenid(founder) then return end

    local name <const> = callsign:upper():sub(1, 32)

    for _, unit in ipairs(units) do
        if unit.callsign == name then return end
    end

    lastId += 1

    local id <const> = lastId

    units[#units + 1] = { id = id, callsign = name, department = department, status = 'available', members = {} }
    table.sort(units, byCallsign)

    Units.join(founder, id)

    return id
end

---@param source integer
---@param id integer
---@return boolean
function Units.join(source, id)
    local unit <const> = Units.get(id)
    local citizenid <const> = officers.citizenid(source)

    if not unit or not citizenid then return false end
    if find(citizenid) == unit then return true end

    detach(source)

    unit.members[#unit.members + 1] = {
        citizenid = citizenid,
        name = officers.name(source),
        callsign = officers.callsign(source),
    }
    memberIds[source] = citizenid

    push()

    return true
end

---@param source integer
function Units.leave(source)
    if detach(source) then push() end
end

---@param id integer
---@param status UnitStatus
---@return boolean
function Units.setStatus(id, status)
    if not STATUSES[status] then return false end

    local unit <const> = Units.get(id)

    if not unit then return false end

    if unit.status ~= status then
        unit.status = status
        push()
    end

    return true
end

---@param citizenid string
---@param callsign string
function Units.setCallsign(citizenid, callsign)
    local unit <const>, index <const> = find(citizenid)

    if not unit or not index then return end

    unit.members[index].callsign = callsign
    push()
end

AddEventHandler('playerDropped', function()
    Units.leave(source)
end)

AddEventHandler('cobalt_core:Server:OnPlayerUnload', Units.leave)

AddEventHandler('cobalt_management:membershipChanged', function(source)
    if memberIds[source] and not officers.isResponder(source) then
        Units.leave(source)
    end
end)

return Units
