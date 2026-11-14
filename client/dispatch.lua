local config <const> = require 'config'
local officer <const> = require 'client.officer'
local mdt <const> = require 'client.mdt'
local core <const> = exports.cobalt_core

---@type table<integer, integer[]>
local blips <const> = {}

---@type table?
local latest

local respondKey

---@param id integer
local function removeBlips(id)
    for _, blip in ipairs(blips[id] or {}) do
        RemoveBlip(blip)
    end

    blips[id] = nil
end

---@param call table
local function addBlip(call)
    local style <const> = config.dispatch.blips[call.blip] or config.dispatch.blips.default
    local coords = call.coords

    if style.offset then
        local angle <const> = math.random() * 2 * math.pi
        local distance <const> = config.dispatch.offsetRadius * math.sqrt(math.random())

        coords = vec3(coords.x + math.cos(angle) * distance, coords.y + math.sin(angle) * distance, coords.z)
    end

    local blip <const> = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite(blip, style.sprite)
    SetBlipColour(blip, style.colour)
    SetBlipScale(blip, style.scale)
    SetBlipFlashes(blip, style.flash == true)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('%s %s'):format(call.code, call.title))
    EndTextCommandSetBlipName(blip)

    local list <const> = { blip }

    if style.radius then
        local radius <const> = AddBlipForRadius(coords.x, coords.y, coords.z, style.radius)

        SetBlipColour(radius, style.colour)
        SetBlipAlpha(radius, 128)
        list[2] = radius
    end

    blips[call.id] = list
    PlaySoundFrontend(-1, style.sound, style.soundSet, true)
    SetTimeout(config.dispatch.blipMinutes * 60000, function() removeBlips(call.id) end)
end

RegisterNetEvent('cobalt_police:callAdded', function(call)
    if call.coords and call.location == '' then
        call.location = officer.location(call.coords)
    end

    if mdt.isOpen then
        mdt.send('callAdded', call)
    end

    if call.coords then
        addBlip(call)
    end

    if officer.isEms() and not officer.isPolice() and GetResourceState('cobalt_ambulancejob') == 'started' then return end

    local seconds <const> = (GlobalState.policeSettings or config.defaultSettings).dispatch.popupSeconds
    local distance <const> = call.coords and #(GetEntityCoords(cache.ped) - call.coords) or 0

    latest = call
    respondKey:disable(false)
    mdt.send('alert', {
        call = call,
        distance = distance,
        seconds = seconds,
        respondKey = respondKey.currentKey,
    })

    SetTimeout(seconds * 1000, function()
        if latest?.id ~= call.id then return end

        latest = nil
        respondKey:disable(true)
        mdt.send('alertClear', { id = call.id })
    end)
end)

RegisterNetEvent('cobalt_police:callUpdated', function(change)
    if mdt.isOpen then
        mdt.send('callUpdated', change)
    end

    if change.status == 'closed' then
        removeBlips(change.id)
    end
end)

---@param id integer
RegisterNetEvent('cobalt_police:callRemoved', function(id)
    removeBlips(id)

    if mdt.isOpen then
        mdt.send('callRemoved', { id = id })
    end
end)

respondKey = lib.addKeybind({
    name = 'cobalt_police_respond',
    description = locale('dispatch.keybind_respond'),
    defaultKey = config.dispatch.respondKey,
    disabled = true,
    onPressed = function()
        local call <const> = latest

        if not call or mdt.isOpen then return end

        latest = nil
        respondKey:disable(true)
        mdt.send('alertClear', { id = call.id })

        local result <const> = lib.callback.await('cobalt_police:mdt', false, 'respondCall', { id = call.id })

        if not result?.ok then
            return core:Notify({ description = result?.error or locale('dispatch.respond_failed'), type = 'error' })
        end

        core:Notify({ description = locale('dispatch.responding', call.title), type = 'success' })
    end,
})

local ALERT_INTERVAL_MS <const> = 10000

---@type table<string, integer>
local alertedAt <const> = {}

---@param kind string
---@param description? string
---@param plate? string
local function alert(kind, description, plate)
    local now <const> = GetGameTimer()

    if alertedAt[kind] and now - alertedAt[kind] < ALERT_INTERVAL_MS then return end

    alertedAt[kind] = now

    TriggerServerEvent('cobalt_police:alert', kind, {
        location = officer.location(GetEntityCoords(cache.ped)),
        description = description or '',
        plate = plate,
    })
end

lib.addKeybind({
    name = 'cobalt_police_panic',
    description = locale('dispatch.keybind_panic'),
    defaultKey = config.dispatch.panicKey,
    onPressed = function()
        if officer.isResponder() then
            alert('panic')
        end
    end,
})

---@param setting string
---@return boolean
local function enabled(setting)
    local settings <const> = GlobalState.policeSettings or config.defaultSettings

    return settings.dispatch.autoAlerts[setting] == true
end

---@param ped integer
---@param witnesses? integer[]
---@return boolean
local function isMeWitnessed(ped, witnesses)
    return ped == cache.ped and (not witnesses or #witnesses > 0)
end

---@param zones { coords: vector3, radius: number }[]
---@return boolean
local function inside(zones)
    local coords <const> = GetEntityCoords(cache.ped)

    for _, zone in ipairs(zones) do
        if #(coords - zone.coords) <= zone.radius then
            return true
        end
    end

    return false
end

---@param vehicle integer
---@return string description
---@return string plate
local function describeVehicle(vehicle)
    local name <const> = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)))
    local plate <const> = GetVehicleNumberPlateText(vehicle):gsub('^%s+', ''):gsub('%s+$', '')

    return locale('dispatch.vehicle', name, plate), plate
end

AddEventHandler('CEventGunShot', function(witnesses, ped)
    if not enabled('shooting') or not isMeWitnessed(ped, witnesses) or officer.isPolice() then return end

    if IsPedCurrentWeaponSilenced(cache.ped) then return end

    if lib.table.contains(config.dispatch.silentWeapons, cache.weapon) then return end

    if inside(config.dispatch.quietZones) then return end

    if inside(config.dispatch.huntingZones) then
        return alert('hunting')
    end

    if cache.vehicle then
        return alert('vehicleShooting', describeVehicle(cache.vehicle))
    end

    alert('shooting')
end)

AddEventHandler('CEventShockingSeenMeleeAction', function(witnesses, ped)
    if enabled('fight') and isMeWitnessed(ped, witnesses) and IsPedInMeleeCombat(ped) then
        alert('fight')
    end
end)

AddEventHandler('CEventPedJackingMyVehicle', function(_, ped)
    if enabled('vehicleTheft') and ped == cache.ped then
        alert('carjacking', describeVehicle(GetVehiclePedIsUsing(ped)))
    end
end)

AddEventHandler('CEventShockingCarAlarm', function(_, ped)
    if enabled('vehicleTheft') and ped == cache.ped and cache.vehicle then
        alert('vehicleTheft', describeVehicle(cache.vehicle))
    end
end)

AddEventHandler('CEventExplosionHeard', function(witnesses, ped)
    if enabled('explosion') and isMeWitnessed(ped, witnesses) then
        alert('explosion')
    end
end)

AddEventHandler('CEventShockingMadDriverExtreme', function(_, ped)
    if not enabled('speeding') or ped ~= cache.ped then return end

    if not cache.vehicle or cache.seat ~= -1 or officer.isPolice() then return end

    if GetEntitySpeed(cache.vehicle) * 3.6 < 110 then return end

    alert('speeding', describeVehicle(cache.vehicle))
end)

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end

    if args[1] ~= cache.ped or args[6] ~= 1 or not enabled('playerDown') then return end

    alert(officer.isResponder() and 'officerDown' or 'personDown')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for id in pairs(blips) do
        removeBlips(id)
    end
end)
