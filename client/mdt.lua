local config <const> = require 'config'
local officer <const> = require 'client.officer'
local core <const> = exports.cobalt_core
local tablet <const> = require 'client.tablet'

local REQUESTS <const> = {
    'setStatus', 'getDashboard', 'getCounts', 'search', 'postBulletin', 'pinBulletin', 'deleteBulletin',
    'searchCitizens', 'getCitizen', 'saveCitizen', 'addCitizenTag', 'removeCitizenTag', 'grantLicence', 'revokeLicence',
    'getLicences',
    'searchVehicles', 'getVehicle', 'searchWeapons', 'searchProperties',
    'getIncidents', 'getIncident', 'saveIncident', 'fileIncident', 'deleteIncident',
    'getWarrants', 'createWarrant', 'setWarrantStatus', 'getBolos', 'createBolo', 'setBoloStatus',
    'getEvidence', 'addEvidence', 'deleteEvidence', 'getCharges', 'saveCharge', 'deleteCharge',
    'getCalls', 'respondCall', 'leaveCall', 'waypointCall', 'addCallNote', 'closeCall',
    'getUnits', 'createUnit', 'joinUnit', 'leaveUnit', 'deleteUnit', 'setUnitStatus',
    'getRoster', 'grantCertificate', 'revokeCertificate',
    'getRanks', 'saveRank', 'getTags', 'saveTag', 'deleteTag',
    'getCertificates', 'saveCertificate', 'deleteCertificate', 'getTemplates', 'saveTemplate', 'deleteTemplate',
    'getSettings', 'saveSettings', 'setVehicleStolen', 'waypointProperty', 'extendWarrant', 'assignCall', 'saveOfficer',
}

local Mdt <const> = { isOpen = false }

---@param page? string
---@param citizenid? string
function Mdt.open(page, citizenid)
    if Mdt.isOpen or LocalPlayer.state.cuffed or LocalPlayer.state.jailed or LocalPlayer.state.isDead then return end

    if not officer.isPolice() and not officer.isEms() then
        return core:Notify({ description = locale('mdt.no_access'), type = 'error' })
    end

    if not officer.onDuty() then
        return core:Notify({ description = locale('mdt.clock_in'), type = 'error' })
    end

    local session <const> = lib.callback.await('cobalt_police:openMdt', false)

    if not session then
        return core:Notify({ description = locale('mdt.no_access'), type = 'error' })
    end

    session.page = page
    session.citizenid = citizenid

    Mdt.isOpen = true
    tablet.hold()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = session })
end

function Mdt.close()
    if not Mdt.isOpen then return end

    Mdt.isOpen = false
    tablet.put()
    TriggerServerEvent('cobalt_police:mdtClosed')
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

---@param action string
---@param data any
function Mdt.send(action, data)
    SendNUIMessage({ action = action, data = data })
end

for _, name in ipairs(REQUESTS) do
    RegisterNUICallback(name, function(data, cb)
        cb(lib.callback.await('cobalt_police:mdt', false, name, data) or false)
    end)
end

RegisterNUICallback('boot', function(_, cb)
    local strings <const> = {}

    for key, value in pairs(lib.getLocales()) do
        if key:sub(1, 3) == 'ui.' then
            strings[key] = value
        end
    end

    cb({ locales = strings })
end)

RegisterNUICallback('close', function(_, cb)
    Mdt.close()
    cb({ ok = true })
end)

RegisterNUICallback('getLocation', function(_, cb)
    local coords <const> = GetEntityCoords(cache.ped)

    cb({ location = officer.location(coords), coords = { x = coords.x, y = coords.y, z = coords.z } })
end)

RegisterNetEvent('cobalt_police:openMdt', Mdt.open)

RegisterNetEvent('cobalt_police:unitsUpdated', function(units)
    if Mdt.isOpen then
        Mdt.send('unitsUpdated', units)
    end
end)

RegisterNetEvent('cobalt_police:waypoint', function(coords)
    SetNewWaypoint(coords.x, coords.y)
end)

RegisterCommand(config.mdt.command, function()
    if officer.isPolice() then return Mdt.open() end

    if officer.isEms() and GetResourceState('cobalt_ambulancejob') == 'started' then
        return TriggerEvent('cobalt_ambulancejob:client:openMdt')
    end

    core:Notify({ description = locale('mdt.police_and_ems_only'), type = 'error' })
end, false)

RegisterNetEvent('cobalt_management:membershipChanged', function(job)
    if not Mdt.isOpen then return end

    if not job?.onduty or not (officer.isPoliceJob(job) or officer.isEmsJob(job)) then
        Mdt.close()
    end
end)

---@param value any
local function closeWhenRestrained(_, _, value)
    if value then Mdt.close() end
end

AddStateBagChangeHandler('isDead', ('player:%s'):format(cache.serverId), closeWhenRestrained)
AddStateBagChangeHandler('cuffed', ('player:%s'):format(cache.serverId), closeWhenRestrained)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource and Mdt.isOpen then
        SetNuiFocus(false, false)
        tablet.put()
    end
end)

return Mdt
