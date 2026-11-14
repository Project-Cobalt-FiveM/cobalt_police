local config <const> = require 'config'
local officers <const> = require 'server.officers'
local Cobalt <const> = exports.cobalt_core:GetCoreObject()
local inventory <const> = exports.cobalt_inventory

---@type table<string, integer>
local restockedAt <const> = {}

---@param id string
---@return table?
local function findStation(id)
    for _, station in ipairs(config.stations) do
        if station.id == id then
            return station
        end
    end
end

---@param source integer
---@param coords vector3
---@return boolean
local function atPoint(source, coords)
    return officers.isLeo(source) and officers.nearCoords(source, coords, 3.0)
end

---@param stashId string
local function restock(stashId)
    local armory <const> = config.armories[stashId]

    if not armory then return end

    local now <const> = os.time()

    if now - (restockedAt[stashId] or 0) < armory.refillCooldown then return end

    local short, added = false, false

    for _, item in ipairs(armory.items) do
        local missing <const> = item.amount - inventory:GetItemCount(nil, item.name, stashId)

        if missing > 0 then
            short = true
            added = inventory:AddItem(nil, item.name, missing, nil, stashId, 'armory_restock') or added
        end
    end

    if added or not short then
        restockedAt[stashId] = now
    end
end

AddEventHandler('cobalt_inventory:server:openedInventory', function(_, invName)
    restock(invName)
end)

RegisterNetEvent('cobalt_police:openBossMenu', function(stationId)
    local source <const> = source
    local station <const> = findStation(stationId)

    if not station?.bossMenu or not atPoint(source, station.bossMenu) then return end

    local job <const> = officers.job(source)

    if not job?.isBoss then return end

    exports.cobalt_management:OpenMenu(source, 'job')
end)

---@type table<integer, integer> officer source to the station vehicle they last took out
local stationVehicles <const> = {}

---@param vehicle integer
---@param ignore? integer player whose own seat doesn't count
---@return boolean
local function occupied(vehicle, ignore)
    for _, playerId in ipairs(GetPlayers()) do
        local inside <const> = GetVehiclePedIsIn(GetPlayerPed(playerId), false) == vehicle

        if inside and tonumber(playerId) ~= ignore then return true end
    end

    return false
end

AddEventHandler('playerDropped', function()
    local source <const> = source
    local vehicle <const> = stationVehicles[source]

    if vehicle and DoesEntityExist(vehicle) and not occupied(vehicle, source) then DeleteEntity(vehicle) end

    stationVehicles[source] = nil
end)

RegisterNetEvent('cobalt_police:spawnVehicle', function(stationId, model)
    local source <const> = source
    local station <const> = findStation(stationId)
    local garage <const> = station?.garage

    if not garage or not officers.isOnDuty(source) then return end

    if not officers.nearCoords(source, garage.coords, 5.0) then return end

    if not lib.table.contains(garage.vehicles, model) then return end

    local previous <const> = stationVehicles[source]

    if previous and DoesEntityExist(previous) and not occupied(previous) then DeleteEntity(previous) end

    local vehicle <const> = Cobalt.Functions.SpawnVehicle(source, model, garage.spawn, true)

    stationVehicles[source] = vehicle

    if vehicle then exports.cobalt_vehiclekeys:GiveKey(source, GetVehicleNumberPlateText(vehicle), vehicle) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for _, vehicle in pairs(stationVehicles) do
        if DoesEntityExist(vehicle) and not occupied(vehicle) then DeleteEntity(vehicle) end
    end
end)
