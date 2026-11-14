local config <const> = require 'config'
local officer <const> = require 'client.officer'
local core <const> = exports.cobalt_core

local STALE_CHECK_MS <const> = 5000
local STREAM_TIMEOUT_MS <const> = 5000

---@type table<integer, integer>
local props <const> = {}

---@type integer?
local staleCheck

---@param vehicle integer
local function detach(vehicle)
    local prop <const> = props[vehicle]

    if prop and DoesEntityExist(prop) then
        DeleteEntity(prop)
    end

    props[vehicle] = nil

    if staleCheck and not next(props) then
        ClearInterval(staleCheck)
        staleCheck = nil
    end
end

local function dropStale()
    for vehicle, prop in pairs(props) do
        if not DoesEntityExist(vehicle) or GetEntityAttachedTo(prop) ~= vehicle then
            detach(vehicle)
        end
    end
end

---@param vehicle integer
local function attach(vehicle)
    dropStale()

    if props[vehicle] or not DoesEntityExist(vehicle) then return end

    local prop <const> = config.clamp.prop
    local bone <const> = GetEntityBoneIndexByName(vehicle, prop.bone)

    if bone == -1 then return end

    lib.requestModel(prop.model)

    if props[vehicle] or not DoesEntityExist(vehicle) then
        return SetModelAsNoLongerNeeded(prop.model)
    end

    local entity <const> = CreateObject(prop.model, 0.0, 0.0, 0.0, false, false, false)

    SetModelAsNoLongerNeeded(prop.model)
    AttachEntityToEntity(
        entity,
        vehicle,
        bone,
        prop.offset.x,
        prop.offset.y,
        prop.offset.z,
        prop.rotation.x,
        prop.rotation.y,
        prop.rotation.z,
        true,
        true,
        false,
        false,
        2,
        true
    )

    props[vehicle] = entity
    staleCheck = staleCheck or SetInterval(dropStale, STALE_CHECK_MS)
end

---@param bagName string
local function attachWhenStreamed(bagName)
    local found <const>, vehicle <const> = pcall(lib.waitFor, function()
        local entity <const> = GetEntityFromStateBagName(bagName)

        if entity ~= 0 then return entity end
    end, nil, STREAM_TIMEOUT_MS)

    if found and Entity(vehicle).state.clamped then
        attach(vehicle)
    end
end

---@param vehicle integer
local function holdEngine(vehicle)
    CreateThread(function()
        while cache.vehicle == vehicle and Entity(vehicle).state.clamped do
            if GetIsVehicleEngineRunning(vehicle) then
                SetVehicleEngineOn(vehicle, false, true, true)
            end

            Wait(250)
        end

        SetVehicleUndriveable(vehicle, false)
    end)

    SetVehicleUndriveable(vehicle, true)
end

AddStateBagChangeHandler('clamped', nil, function(bagName, _, value)
    local vehicle <const> = GetEntityFromStateBagName(bagName)

    if vehicle == 0 then
        if value then
            CreateThread(function() attachWhenStreamed(bagName) end)
        end

        return
    end

    if value then
        attach(vehicle)

        if cache.vehicle == vehicle then
            holdEngine(vehicle)
        end
    else
        detach(vehicle)
    end
end)

lib.onCache('vehicle', function(vehicle)
    if vehicle and Entity(vehicle).state.clamped then
        attach(vehicle)
        holdEngine(vehicle)
    end
end)

---@param label string
---@param duration integer
---@return boolean
local function work(label, duration)
    return core:Progressbar({
        label = label,
        duration = duration,
        anim = { dict = 'mini@repair', clip = 'fixing_a_player', flag = 49 },
        disable = { move = true, combat = true },
    })
end

exports.ox_target:addGlobalVehicle({
    {
        name = 'cobalt_police:clamp',
        label = locale('clamp.fit'),
        icon = 'fas fa-toolbox',
        distance = 2.5,
        bones = { 'wheel_lf' },
        canInteract = function(entity)
            return officer.isPolice() and officer.onDuty() and not Entity(entity).state.clamped
                and exports.cobalt_inventory:HasItem(config.clamp.item, 1)
        end,
        onSelect = function(data)
            if work(locale('clamp.fitting'), config.clamp.placeMs) then
                TriggerServerEvent('cobalt_police:clamp', NetworkGetNetworkIdFromEntity(data.entity))
            end
        end,
    },
    {
        name = 'cobalt_police:unclamp',
        label = locale('clamp.remove'),
        icon = 'fas fa-wrench',
        distance = 2.5,
        bones = { 'wheel_lf' },
        canInteract = function(entity)
            return officer.isPolice() and officer.onDuty() and Entity(entity).state.clamped == true
        end,
        onSelect = function(data)
            if work(locale('clamp.removing'), config.clamp.removeMs) then
                TriggerServerEvent('cobalt_police:unclamp', NetworkGetNetworkIdFromEntity(data.entity))
            end
        end,
    },
})

CreateThread(function()
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if Entity(vehicle).state.clamped then
            attach(vehicle)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for vehicle in pairs(props) do
        detach(vehicle)
    end
end)
