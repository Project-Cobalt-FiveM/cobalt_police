local config <const> = require 'config'
local officer <const> = require 'client.officer'
local restraints <const> = require 'client.restraints'
local mdt <const> = require 'client.mdt'
local inventory <const> = exports.cobalt_inventory

---@param entity integer
---@return integer?
local function serverIdOf(entity)
    local player <const> = NetworkGetPlayerIndexFromPed(entity)

    return player ~= -1 and GetPlayerServerId(player) or nil
end

---@param entity integer
---@return table
local function stateOf(entity)
    local serverId <const> = serverIdOf(entity)

    return serverId and Player(serverId).state or {}
end

exports.ox_target:addGlobalPlayer({
    {
        name = 'cobalt_police:cuff',
        label = locale('target.cuff'),
        icon = 'fas fa-handcuffs',
        distance = 2.0,
        canInteract = function(entity)
            if not officer.isPolice() or stateOf(entity).cuffed then return false end

            return inventory:HasItem(config.cuffTypes.cuffs.item, 1)
        end,
        onSelect = function(data) restraints.cuff(serverIdOf(data.entity), 'cuffs') end,
    },
    {
        name = 'cobalt_police:ziptie',
        label = locale('target.tie_hands'),
        icon = 'fas fa-link',
        distance = 2.0,
        canInteract = function(entity)
            local state <const> = stateOf(entity)

            if officer.isPolice() or not state.handsUp or state.cuffed then return false end

            return inventory:HasItem(config.cuffTypes.zipties.item, 1)
        end,
        onSelect = function(data) restraints.cuff(serverIdOf(data.entity), 'zipties') end,
    },
    {
        name = 'cobalt_police:uncuff',
        label = locale('target.remove_cuffs'),
        icon = 'fas fa-key',
        distance = 2.0,
        canInteract = function(entity) return officer.isPolice() and stateOf(entity).cuffed ~= nil end,
        onSelect = function(data) restraints.uncuff(serverIdOf(data.entity), locale('restraints.removing_cuffs'), 3000) end,
    },
    {
        name = 'cobalt_police:cut',
        label = locale('target.cut_zipties'),
        icon = 'fas fa-scissors',
        distance = 2.0,
        canInteract = function(entity)
            if officer.isPolice() or stateOf(entity).cuffed ~= 'zipties' then return false end

            return inventory:HasItem(config.cuffTypes.zipties.cutter, 1)
        end,
        onSelect = function(data) restraints.uncuff(serverIdOf(data.entity), locale('restraints.cutting_zipties'), 2500) end,
    },
    {
        name = 'cobalt_police:lockpick',
        label = locale('target.pick_cuffs'),
        icon = 'fas fa-key',
        distance = 2.0,
        canInteract = function(entity)
            if officer.isPolice() or stateOf(entity).cuffed ~= 'cuffs' then return false end

            return inventory:HasItem(config.cuffTypes.cuffs.lockpick.item, 1)
        end,
        onSelect = function(data) restraints.lockpick(serverIdOf(data.entity)) end,
    },
    {
        name = 'cobalt_police:escort',
        label = locale('target.escort'),
        icon = 'fas fa-person-walking',
        distance = 2.0,
        canInteract = function(entity)
            local state <const> = stateOf(entity)

            return state.cuffed ~= nil and not state.escortedBy and not cache.vehicle
        end,
        onSelect = function(data) TriggerServerEvent('cobalt_police:escort', serverIdOf(data.entity), true) end,
    },
    {
        name = 'cobalt_police:release',
        label = locale('target.let_go'),
        icon = 'fas fa-person-walking-arrow-right',
        distance = 3.0,
        canInteract = function(entity) return stateOf(entity).escortedBy == cache.serverId end,
        onSelect = function(data) TriggerServerEvent('cobalt_police:escort', serverIdOf(data.entity), false) end,
    },
    {
        name = 'cobalt_police:search',
        label = locale('target.search'),
        icon = 'fas fa-magnifying-glass',
        distance = 2.0,
        canInteract = function(entity) return officer.isPolice() and stateOf(entity).cuffed ~= nil end,
        onSelect = function(data) TriggerServerEvent('cobalt_police:search', serverIdOf(data.entity)) end,
    },
    {
        name = 'cobalt_police:profile',
        label = locale('target.look_up'),
        icon = 'fas fa-id-card',
        distance = 2.0,
        canInteract = function(entity) return officer.isPolice() and stateOf(entity)['cobalt:citizenid'] ~= nil end,
        onSelect = function(data) mdt.open('citizens', stateOf(data.entity)['cobalt:citizenid']) end,
    },
})

---@return integer?
local function escortedByMe()
    for _, player in ipairs(GetActivePlayers()) do
        local serverId <const> = GetPlayerServerId(player)

        if serverId ~= cache.serverId and Player(serverId).state.escortedBy == cache.serverId then
            return serverId
        end
    end
end

---@param vehicle integer
---@param seat integer
---@return integer?
local function cuffedInSeat(vehicle, seat)
    local ped <const> = GetPedInVehicleSeat(vehicle, seat)

    if ped == 0 or ped == cache.ped then return end

    local serverId <const> = serverIdOf(ped)

    return serverId and Player(serverId).state.cuffed and serverId or nil
end

local DRIVER_SEAT <const> = -1

local DOORS <const> = {
    { seat = DRIVER_SEAT, side = 'dside_f', name = 'driver' },
    { seat = 0, side = 'pside_f', name = 'passenger' },
    { seat = 1, side = 'dside_r', name = 'rear_left' },
    { seat = 2, side = 'pside_r', name = 'rear_right' },
}

local doorOptions <const> = {}

for _, door in ipairs(DOORS) do
    local seatName <const> = locale(('target.seat.%s'):format(door.name))

    if door.seat ~= DRIVER_SEAT then
        doorOptions[#doorOptions + 1] = {
            name = ('cobalt_police:seat_%s'):format(door.side),
            label = locale('target.put_in', seatName),
            icon = 'fas fa-car',
            distance = 2.5,
            bones = { 'door_' .. door.side, 'seat_' .. door.side },
            canInteract = function(entity)
                return GetPedInVehicleSeat(entity, door.seat) == 0 and escortedByMe() ~= nil
            end,
            onSelect = function(data)
                local target <const> = escortedByMe()

                if not target then return end

                TriggerServerEvent('cobalt_police:seat', target, NetworkGetNetworkIdFromEntity(data.entity), door.seat)
            end,
        }
    end

    doorOptions[#doorOptions + 1] = {
        name = ('cobalt_police:unseat_%s'):format(door.side),
        label = locale('target.take_out', seatName),
        icon = 'fas fa-person-walking-arrow-right',
        distance = 2.5,
        bones = { 'door_' .. door.side, 'seat_' .. door.side },
        canInteract = function(entity) return cuffedInSeat(entity, door.seat) ~= nil end,
        onSelect = function(data)
            local target <const> = cuffedInSeat(data.entity, door.seat)

            if target then
                TriggerServerEvent('cobalt_police:unseat', target)
            end
        end,
    }
end

exports.ox_target:addGlobalVehicle(doorOptions)

