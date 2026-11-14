local config <const> = require 'config'
local officers <const> = require 'server.officers'
local log <const> = require 'server.log'

---@type table<string, true>
local clamped <const> = {}

---@param vehicle integer
---@return string
local function plateOf(vehicle)
    return ((GetVehicleNumberPlateText(vehicle) or ''):gsub('%s+', ''))
end

---@param source integer
---@param netId integer
---@return integer?
local function reachableVehicle(source, netId)
    if type(netId) ~= 'number' or not officers.isOnDuty(source) then return end

    local vehicle <const> = NetworkGetEntityFromNetworkId(netId)

    if vehicle == 0 or GetEntityType(vehicle) ~= 2 then return end

    if not officers.nearCoords(source, GetEntityCoords(vehicle), config.clamp.range) then return end

    return vehicle
end

RegisterNetEvent('cobalt_police:clamp', function(netId)
    local source <const> = source
    local vehicle <const> = reachableVehicle(source, netId)

    if not vehicle or Entity(vehicle).state.clamped then return end

    local plate <const> = plateOf(vehicle)

    if not exports.cobalt_core:GetVehicleOwnerByPlate(plate) then
        return officers.notify(source, locale('clamp.not_registered'), 'error')
    end

    if not exports.cobalt_inventory:RemoveItem(source, config.clamp.item, 1) then
        return officers.notify(source, locale('clamp.need_kit'), 'error')
    end

    local citizenid <const> = officers.citizenid(source)

    MySQL.insert.await('INSERT IGNORE INTO police_clamps (plate, placed_by) VALUES (?, ?)', { plate, citizenid })
    clamped[plate] = true
    Entity(vehicle).state:set('clamped', true, true)

    log('clamp', citizenid, nil, { plate = plate })
    officers.notify(source, locale('clamp.fitted', plate), 'success')
end)

RegisterNetEvent('cobalt_police:unclamp', function(netId)
    local source <const> = source
    local vehicle <const> = reachableVehicle(source, netId)

    if not vehicle or not Entity(vehicle).state.clamped then return end

    local plate <const> = plateOf(vehicle)

    MySQL.update.await('DELETE FROM police_clamps WHERE plate = ?', { plate })
    clamped[plate] = nil
    Entity(vehicle).state:set('clamped', nil, true)

    if config.clamp.refund and exports.cobalt_inventory:CanCarry(source, config.clamp.item, 1) then
        exports.cobalt_inventory:AddItem(source, config.clamp.item, 1)
    end

    log('unclamp', officers.citizenid(source), nil, { plate = plate })
    officers.notify(source, locale('clamp.removed', plate), 'success')
end)

AddEventHandler('entityCreated', function(entity)
    if not next(clamped) or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then return end

    if clamped[plateOf(entity)] then
        Entity(entity).state:set('clamped', true, true)
    end
end)

CreateThread(function()
    for _, row in ipairs(MySQL.query.await('SELECT plate FROM police_clamps ORDER BY plate') or {}) do
        clamped[row.plate] = true
    end
end)

---@param plate string
---@return boolean
local function isClamped(plate)
    return clamped[(plate or ''):gsub('%s+', '')] == true
end

return { isClamped = isClamped }
