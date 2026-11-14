local config <const> = require 'config'
local officer <const> = require 'client.officer'
local core <const> = exports.cobalt_core

---@type integer[]
local blips <const> = {}

---@param station table
local function openGarage(station)
    local options <const> = {}

    for _, model in ipairs(station.garage.vehicles) do
        options[#options + 1] = {
            title = locale(('station.vehicle.%s'):format(model)),
            icon = 'car',
            onSelect = function() TriggerServerEvent('cobalt_police:spawnVehicle', station.id, model) end,
        }
    end

    local id <const> = ('cobalt_police_garage_%s'):format(station.id)

    core:RegisterContext({ id = id, title = locale('station.garage'), options = options })
    core:ShowContext(id)
end

---@param coords vector3
---@param name string
---@param option table
local function zone(coords, name, option)
    option.name = name
    option.distance = 2.0

    exports.ox_target:addSphereZone({ coords = coords, radius = 1.2, name = name, options = { option } })
end

for _, station in ipairs(config.stations) do
    local blip <const> = AddBlipForCoord(station.coords.x, station.coords.y, station.coords.z)

    SetBlipSprite(blip, station.blip.sprite)
    SetBlipColour(blip, station.blip.colour)
    SetBlipScale(blip, station.blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(locale(('station.blip.%s'):format(station.id)))
    EndTextCommandSetBlipName(blip)
    blips[#blips + 1] = blip

    if station.armory then
        zone(station.armory.coords, ('cobalt_police:%s:armory'):format(station.id), {
            label = locale(('station.armory.%s'):format(station.armory.id)),
            icon = 'fas fa-gun',
            canInteract = officer.isPolice,
            onSelect = function() TriggerServerEvent('cobalt_police:openArmory', station.id) end,
        })
    end

    if station.locker then
        zone(station.locker, ('cobalt_police:%s:locker'):format(station.id), {
            label = locale('station.locker'),
            icon = 'fas fa-box-archive',
            canInteract = officer.isPolice,
            onSelect = function() TriggerServerEvent('cobalt_police:openLocker', station.id) end,
        })
    end

    if station.wardrobe then
        zone(station.wardrobe, ('cobalt_police:%s:wardrobe'):format(station.id), {
            label = locale('station.wardrobe'),
            icon = 'fas fa-shirt',
            canInteract = officer.isPolice,
            onSelect = function() TriggerEvent('qb-clothing:client:openMenu') end,
        })
    end

    if station.bossMenu then
        zone(station.bossMenu, ('cobalt_police:%s:boss'):format(station.id), {
            label = locale('station.management'),
            icon = 'fas fa-user-tie',
            canInteract = function() return officer.isPolice() and officer.isBoss() end,
            onSelect = function() TriggerServerEvent('cobalt_police:openBossMenu', station.id) end,
        })
    end

    if station.garage then
        zone(station.garage.coords, ('cobalt_police:%s:garage'):format(station.id), {
            label = locale('station.garage'),
            icon = 'fas fa-car-side',
            canInteract = function() return officer.isPolice() and officer.onDuty() end,
            onSelect = function() openGarage(station) end,
        })
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for _, blip in ipairs(blips) do
        RemoveBlip(blip)
    end
end)
