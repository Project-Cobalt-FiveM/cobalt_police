local config <const> = require 'config'
local officers <const> = require 'server.officers'
local access <const> = require 'server.access'

---@alias DispatchJob 'leo'|'ems'
---@alias UnitStatus 'available'|'busy'|'enroute'|'onscene'

---@class DispatchResponder
---@field citizenid string
---@field name string
---@field callsign string

---@class DispatchCall
---@field id integer
---@field code string
---@field title string
---@field description string
---@field location string
---@field plate string?
---@field coords vector3?
---@field priority 1|2|3
---@field jobs DispatchJob[]
---@field blip string
---@field caller { name: string, number: string }?
---@field raisedBy string?
---@field responders DispatchResponder[]
---@field notes DispatchNote[]
---@field status 'open'|'closed'
---@field createdAt integer

---@class DispatchNote
---@field author string
---@field text string
---@field time integer

---@alias DispatchChange
---| { change: 'responders', responders: DispatchResponder[] }
---| { change: 'note', note: DispatchNote, dropOldest: boolean }
---| { change: 'status', status: 'open'|'closed' }

---@class DispatchInput
---@field code? string
---@field title string
---@field description? string
---@field location? string
---@field coords? vector3
---@field priority? 1|2|3
---@field jobs? DispatchJob[]
---@field blip? string
---@field plate? string
---@field caller? { name: string, number: string }
---@field raisedBy? string

local Dispatch <const> = {}

---@type DispatchCall[]
local calls <const> = {}

local nextId = 1

---@type table<string, integer>
local cooldowns <const> = {}

---@param source integer
---@param key string
---@param seconds integer
---@return boolean
local function cooled(source, key, seconds)
    local id <const> = ('%s:%s'):format(source, key)

    if (cooldowns[id] or 0) > os.time() then return false end

    cooldowns[id] = os.time() + seconds

    return true
end

---@param call DispatchCall
---@return integer[]
local function recipients(call)
    return officers.byJobTypes(call.jobs, access.settings().dispatch.onDutyOnly)
end

---@param call DispatchCall
---@param event string
---@param payload any
local function push(call, event, payload)
    for _, source in ipairs(recipients(call)) do
        TriggerClientEvent(event, source, payload)
    end
end

---@param call DispatchCall
---@param change DispatchChange
local function update(call, change)
    local payload <const> = change --[[@as table]]

    payload.id = call.id
    payload.jobs = call.jobs

    push(call, 'cobalt_police:callUpdated', payload)
end

---@param id integer
---@return DispatchCall?
function Dispatch.get(id)
    for _, call in ipairs(calls) do
        if call.id == id then
            return call
        end
    end
end

---@param call DispatchCall
---@param isLeo boolean
---@param isEms boolean
---@return boolean
local function shownTo(call, isLeo, isEms)
    return (isLeo and lib.table.contains(call.jobs, 'leo')) or (isEms and lib.table.contains(call.jobs, 'ems'))
end

---@param source integer
---@param call DispatchCall
---@return boolean
function Dispatch.canSee(source, call)
    return shownTo(call, officers.isLeo(source), officers.isEms(source))
end

---@param source integer
---@return DispatchCall[]
function Dispatch.visible(source)
    local out <const> = {}
    local isLeo <const>, isEms <const> = officers.isLeo(source), officers.isEms(source)

    for _, call in ipairs(calls) do
        if shownTo(call, isLeo, isEms) then
            out[#out + 1] = call
        end
    end

    return out
end

---@param data DispatchInput
---@return integer? id
function Dispatch.send(data)
    if type(data) ~= 'table' or type(data.title) ~= 'string' then return end

    local coords <const> = data.coords and vec3(data.coords.x, data.coords.y, data.coords.z) or nil
    local jobs <const> = {}

    for _, job in ipairs(type(data.jobs) == 'table' and data.jobs or {}) do
        if job == 'leo' or job == 'ems' then
            jobs[#jobs + 1] = job
        end
    end

    if #jobs == 0 then
        jobs[1] = 'leo'
    end
    local call <const> = {
        id = nextId,
        code = tostring(data.code or '10-80'):sub(1, 16),
        title = data.title:sub(1, 120),
        description = tostring(data.description or ''):sub(1, 500),
        location = tostring(data.location or ''):sub(1, 160),
        plate = type(data.plate) == 'string' and data.plate:sub(1, 16) or nil,
        coords = coords,
        priority = math.max(1, math.min(3, math.floor(tonumber(data.priority) or 2))) --[[@as 1|2|3]],
        jobs = jobs,
        blip = config.dispatch.blips[data.blip] and data.blip or 'default',
        caller = data.caller,
        raisedBy = data.raisedBy,
        responders = {},
        notes = {},
        status = 'open',
        createdAt = os.time(),
    }

    nextId += 1
    table.insert(calls, 1, call)

    local dropped <const> = #calls > config.dispatch.maxCalls and table.remove(calls)

    if dropped then
        for _, source in ipairs(recipients(dropped)) do
            TriggerClientEvent('cobalt_police:callRemoved', source, dropped.id)
        end
    end

    push(call, 'cobalt_police:callAdded', call)
    TriggerEvent('cobalt_police:dispatchSent', call)

    return call.id
end

---@param source integer
---@param id integer
---@return boolean
function Dispatch.respond(source, id)
    local call <const> = Dispatch.get(id)

    if not call or call.status ~= 'open' then return false end

    local citizenid <const> = officers.citizenid(source)

    for _, responder in ipairs(call.responders) do
        if responder.citizenid == citizenid then
            return true
        end
    end

    call.responders[#call.responders + 1] = {
        citizenid = citizenid,
        name = officers.name(source),
        callsign = officers.callsign(source),
    }

    update(call, { change = 'responders', responders = call.responders })
    TriggerEvent('cobalt_police:callResponded', source, call.id)

    return true
end

---@param id integer
---@param members DispatchResponder[]
---@return boolean
function Dispatch.assign(id, members)
    local call <const> = Dispatch.get(id)

    if not call or call.status ~= 'open' or #members == 0 then return false end

    local present <const> = {}

    for _, responder in ipairs(call.responders) do
        present[responder.citizenid] = true
    end

    for _, member in ipairs(members) do
        if not present[member.citizenid] then
            call.responders[#call.responders + 1] = member
        end
    end

    update(call, { change = 'responders', responders = call.responders })

    return true
end

---@param source integer
---@param id integer
---@return boolean
function Dispatch.leave(source, id)
    local call <const> = Dispatch.get(id)

    if not call then return false end

    local citizenid <const> = officers.citizenid(source)

    for i, responder in ipairs(call.responders) do
        if responder.citizenid == citizenid then
            table.remove(call.responders, i)
            update(call, { change = 'responders', responders = call.responders })

            return true
        end
    end

    return false
end

---@param source integer
---@param id integer
---@param text string
---@param typed? boolean a note the responder wrote, held to the note cooldown
---@return boolean
function Dispatch.note(source, id, text, typed)
    local call <const> = Dispatch.get(id)

    if not call or type(text) ~= 'string' or text == '' then return false end

    if typed and not cooled(source, 'note', config.dispatch.noteCooldown) then return false end

    local note <const> = { author = officers.name(source), text = text:sub(1, 300), time = os.time() }
    local dropOldest <const> = #call.notes >= config.dispatch.maxNotes

    if dropOldest then
        table.remove(call.notes, 1)
    end

    call.notes[#call.notes + 1] = note
    update(call, { change = 'note', note = note, dropOldest = dropOldest })

    return true
end

---@param id integer
---@return boolean
function Dispatch.close(id)
    local call <const> = Dispatch.get(id)

    if not call or call.status == 'closed' then return false end

    call.status = 'closed'
    update(call, { change = 'status', status = call.status })

    return true
end

---@class AlertKind
---@field code string
---@field blip string
---@field priority 1|2|3
---@field jobs DispatchJob[]
---@field setting? string
---@field responderOnly? boolean
---@field named? boolean

---@type table<string, AlertKind>
local ALERTS <const> = {
    shooting = {
        code = '10-71',
        blip = 'shooting',
        priority = 2,
        jobs = { 'leo' },
        setting = 'shooting',
    },
    vehicleShooting = {
        code = '10-71',
        blip = 'shooting',
        priority = 2,
        jobs = { 'leo' },
        setting = 'shooting',
    },
    hunting = {
        code = '10-13',
        blip = 'shooting',
        priority = 3,
        jobs = { 'leo' },
        setting = 'shooting',
    },
    fight = {
        code = '10-10',
        blip = 'default',
        priority = 3,
        jobs = { 'leo' },
        setting = 'fight',
    },
    vehicleTheft = {
        code = '10-60',
        blip = 'vehicle',
        priority = 2,
        jobs = { 'leo' },
        setting = 'vehicleTheft',
    },
    carjacking = {
        code = '10-60',
        blip = 'vehicle',
        priority = 2,
        jobs = { 'leo' },
        setting = 'vehicleTheft',
    },
    speeding = {
        code = '10-11',
        blip = 'vehicle',
        priority = 3,
        jobs = { 'leo' },
        setting = 'speeding',
    },
    explosion = {
        code = '10-80',
        blip = 'explosion',
        priority = 2,
        jobs = { 'leo', 'ems' },
        setting = 'explosion',
    },
    personDown = {
        code = '10-52',
        blip = 'medical',
        priority = 1,
        jobs = { 'ems' },
        setting = 'playerDown',
    },
    officerDown = {
        code = '10-13',
        blip = 'panic',
        priority = 1,
        jobs = { 'leo', 'ems' },
        setting = 'playerDown',
        responderOnly = true,
        named = true,
    },
    panic = {
        code = '10-99',
        blip = 'panic',
        priority = 1,
        jobs = { 'leo', 'ems' },
        responderOnly = true,
        named = true,
    },
}

RegisterNetEvent('cobalt_police:alert', function(kind, info)
    local source <const> = source
    local alert <const> = ALERTS[kind]

    if not alert or type(info) ~= 'table' then return end

    if alert.setting and not access.settings().dispatch.autoAlerts[alert.setting] then return end

    if alert.responderOnly and not officers.isResponder(source) then return end

    if not cooled(source, kind, alert.responderOnly and 10 or 20) then return end

    local ped <const> = GetPlayerPed(source)
    local raisedBy <const> = alert.named
        and ('%s, %s'):format(officers.name(source), officers.callsign(source)):gsub(', $', '')
        or nil

    Dispatch.send({
        code = alert.code,
        title = locale(('dispatch.alert.%s'):format(kind)),
        description = type(info.description) == 'string' and info.description or '',
        plate = info.plate,
        location = type(info.location) == 'string' and info.location or '',
        coords = GetEntityCoords(ped),
        priority = alert.priority,
        jobs = alert.jobs,
        blip = alert.blip,
        raisedBy = raisedBy,
    })
end)

---@param source integer
---@return string number the caller's npwd number, or '' when npwd is stopped or hasn't loaded them
local function phoneNumber(source)
    if GetResourceState('npwd') ~= 'started' then return '' end

    local ok <const>, number <const> = pcall(exports.npwd.getPhoneNumber, exports.npwd, source)

    return ok and number or ''
end

---@param source integer
---@param message string
---@param service? '911'|'311'
local function emergencyCall(source, message, service)
    if type(message) ~= 'string' or message == '' then return end

    local settings <const> = access.settings()

    if settings.dispatch.phoneRequired and not exports.cobalt_inventory:HasItem(source, 'phone', 1) then
        return officers.notify(source, locale('dispatch.need_phone'), 'error')
    end

    if not cooled(source, 'call', 60) then
        return officers.notify(source, locale('dispatch.call_cooldown'), 'error')
    end

    service = service == '311' and '311' or '911'

    Dispatch.send({
        code = service,
        title = message:sub(1, 80),
        description = message,
        coords = GetEntityCoords(GetPlayerPed(source)),
        priority = 2,
        jobs = service == '311' and { 'ems' } or { 'leo' },
        blip = 'call',
        caller = { name = officers.name(source), number = phoneNumber(source) },
    })

    officers.notify(source, locale('dispatch.call_sent'), 'success')
end

AddEventHandler('cobalt_police:emergencyCall', emergencyCall)

AddEventHandler('cobalt_police:medicalCall', function(source, message)
    emergencyCall(source, message, '311')
end)

AddEventHandler('playerDropped', function()
    local prefix <const> = ('%s:'):format(source)

    for key in pairs(cooldowns) do
        if key:sub(1, #prefix) == prefix then
            cooldowns[key] = nil
        end
    end
end)

return Dispatch
