local config <const> = require 'config'
local officer <const> = require 'client.officer'
local core <const> = exports.cobalt_core

---@class TapeChain
---@field id integer
---@field type string
---@field from vector3
---@field to vector3

---@type table<integer, integer[]>
local chains <const> = {}

---@type table<integer, integer>
local zones <const> = {}

---@type table<integer, CPoint>
local points <const> = {}

local ZONE_WIDTH <const> = 1.5
local ZONE_HEIGHT <const> = 2.0

---@param tape TapeChain
local function spawn(tape)
    if chains[tape.id] then return end

    local model <const> = config.tape.types[tape.type]
    local length <const> = #(tape.to.xy - tape.from.xy)

    if not model or length < 0.5 then return end

    lib.requestModel(model)

    if chains[tape.id] or not points[tape.id]?.inside then
        return SetModelAsNoLongerNeeded(model)
    end

    local count <const> = math.min(math.floor(length / config.tape.segmentLength + 0.5), 60)
    local heading <const> = math.deg(math.atan(-(tape.to.x - tape.from.x), tape.to.y - tape.from.y))
    local props <const> = {}

    local first <const> = CreateObject(model, tape.from.x, tape.from.y, tape.from.z, false, false, false)
    SetEntityCollision(first, false, false)
    SetEntityRotation(first, 0.0, 0.0, heading - 90.0, 1, true)
    FreezeEntityPosition(first, true)
    props[1] = first

    for i = 2, count do
        local segment <const> = CreateObject(model, tape.from.x, tape.from.y, tape.from.z, false, false, false)

        SetEntityCollision(segment, false, false)
        AttachEntityToEntity(
            segment,
            props[i - 1],
            0,
            0.0,
            config.tape.segmentLength,
            0.0,
            0.0,
            0.0,
            0.0,
            false,
            false,
            false,
            false,
            0,
            true
        )

        props[i] = segment
    end

    SetModelAsNoLongerNeeded(model)
    chains[tape.id] = props
    zones[tape.id] = exports.ox_target:addBoxZone({
        coords = (tape.from + tape.to) / 2,
        size = vec3(ZONE_WIDTH, length, ZONE_HEIGHT),
        rotation = heading,
        options = {
            {
                name = 'cobalt_police:removeTape',
                label = locale('tape.take_down'),
                icon = 'fas fa-scissors',
                distance = 2.0,
                canInteract = officer.isResponder,
                onSelect = function() TriggerServerEvent('cobalt_police:removeTape', tape.id) end,
            },
        },
    })
end

---@param id integer
local function despawn(id)
    for _, prop in ipairs(chains[id] or {}) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end

    if zones[id] then
        exports.ox_target:removeZone(zones[id], true)
    end

    chains[id], zones[id] = nil, nil
end

---@param tape TapeChain
local function track(tape)
    if points[tape.id] then return end

    points[tape.id] = lib.points.new({
        coords = (tape.from + tape.to) / 2,
        distance = config.tape.drawDistance,
        onEnter = function() CreateThread(function() spawn(tape) end) end,
        onExit = function() despawn(tape.id) end,
    })
end

---@param id integer
local function untrack(id)
    local point <const> = points[id]

    if point then
        point:remove()
        points[id] = nil
    end

    despawn(id)
end

local KEY_CANCEL <const> = 177

---@param label string
---@param helpText string
---@param maxDistance number meters
---@param color integer[] r, g, b, a
---@return vector3?
local function pickPoint(label, helpText, maxDistance, color)
    AddTextEntry(label, helpText)

    while true do
        if LocalPlayer.state.isDead or LocalPlayer.state.cuffed then return end

        local hit <const>, _, coords <const> = lib.raycast.fromCamera(511, 4, maxDistance)

        DisableControlAction(0, 24, true)

        if hit and coords then
            DisplayHelpTextThisFrame(label, false)
            DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.4, 0.4, 0.4,
                color[1], color[2], color[3], color[4], false, false, 2, false)

            if IsDisabledControlJustPressed(0, 24) then return coords end
        end

        if IsControlJustPressed(0, KEY_CANCEL) then return end

        Wait(0)
    end
end

local TAPE_MARKER <const> = { 34, 197, 94, 200 }

---@param tapeType string
local function place(tapeType)
    local from <const> = pickPoint('cobalt_police_tape', locale('tape.start_help'), config.tape.range, TAPE_MARKER)

    if not from then return end

    local to <const> = pickPoint('cobalt_police_tape', locale('tape.end_help'), config.tape.range, TAPE_MARKER)

    if not to then return end

    TriggerServerEvent('cobalt_police:placeTape', tapeType, from, to)
end

RegisterNetEvent('cobalt_police:pickTape', function()
    local options <const> = {}

    for key in pairs(config.tape.types) do
        options[#options + 1] = {
            title = locale(('tape.type.%s'):format(key)),
            icon = 'tape',
            onSelect = function() place(key) end,
        }
    end

    core:RegisterContext({ id = 'cobalt_police_tape', title = locale('tape.place'), options = options })
    core:ShowContext('cobalt_police_tape')
end)

RegisterNetEvent('cobalt_police:tapePlaced', track)
RegisterNetEvent('cobalt_police:tapeRemoved', untrack)

local function load()
    for _, tape in pairs(lib.callback.await('cobalt_police:getTapes', false) or {}) do
        track(tape)
    end
end

AddStateBagChangeHandler('LoggedIn', ('player:%s'):format(cache.serverId), function(_, _, loggedIn)
    if loggedIn then
        CreateThread(load)
    end
end)

if LocalPlayer.state.LoggedIn then
    CreateThread(load)
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for id in pairs(chains) do
        despawn(id)
    end
end)
