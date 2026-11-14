local config <const> = require 'config'
local officers <const> = require 'server.officers'
local Cobalt <const> = exports.cobalt_core:GetCoreObject()
local inventory <const> = exports.cobalt_inventory

local LOCKER_STASH <const> = 'police_locker'

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

CreateThread(function()
    for _, station in ipairs(config.stations) do
        local armory <const> = station.armory

        if armory then
            inventory:CreateStash(armory.id, {
                invType = 'big_storage',
                label = locale(('station.armory.%s'):format(armory.id)),
            })
        end
    end

    inventory:CreateStash(LOCKER_STASH, { invType = 'small_storage', label = locale('station.locker'), personal = true })
end)

---@param armory table
local function restock(armory)
    local now <const> = os.time()

    if now - (restockedAt[armory.id] or 0) < armory.refillCooldown then return end

    local short, added = false, false

    for _, item in ipairs(armory.items) do
        local missing <const> = item.amount - inventory:GetItemCount(nil, item.name, armory.id)

        if missing > 0 then
            short = true
            added = inventory:AddItem(nil, item.name, missing, nil, armory.id, 'armory_restock') or added
        end
    end

    if added or not short then
        restockedAt[armory.id] = now
    end
end

RegisterNetEvent('cobalt_police:openArmory', function(stationId)
    local source <const> = source
    local station <const> = findStation(stationId)
    local armory <const> = station?.armory

    if not armory or not atPoint(source, armory.coords) then return end

    if officers.job(source).grade < armory.minGrade then
        return officers.notify(source, locale('station.armory_rank'), 'error')
    end

    if not inventory:OpenStash(source, armory.id) then return end

    restock(armory)
end)

RegisterNetEvent('cobalt_police:openLocker', function(stationId)
    local source <const> = source
    local station <const> = findStation(stationId)

    if not station?.locker or not atPoint(source, station.locker) then return end

    inventory:OpenStash(source, LOCKER_STASH)
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
