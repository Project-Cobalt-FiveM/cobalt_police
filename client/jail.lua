local config <const> = require 'config'
local core <const> = exports.cobalt_core

---@type CZone?
local fence

---@type integer?
local ticker

local deadline = 0

---@param coords vector4
local function teleport(coords)
    DoScreenFadeOut(300)
    Wait(300)
    SetEntityCoords(cache.ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(cache.ped, coords.w)
    Wait(500)
    DoScreenFadeIn(300)
end

local function showTime()
    local seconds <const> = math.max(math.ceil((deadline - GetGameTimer()) / 1000), 0)

    core:ShowTextUI(locale('jail.time_left', seconds // 60, seconds % 60), { position = 'right-center' })
end

local function stop()
    if not ticker then return end

    ClearInterval(ticker)

    if fence then
        fence:remove()
    end

    fence, ticker = nil, nil
    core:HideTextUI()
end

local function start()
    stop()

    fence = lib.zones.sphere({
        coords = config.jail.zone.coords,
        radius = config.jail.zone.radius,
        onExit = function()
            if LocalPlayer.state.jailed then
                teleport(config.jail.spawn)
            end
        end,
    })

    ticker = SetInterval(showTime, 1000)
    showTime()
end

RegisterNetEvent('cobalt_police:enterJail', function(spawn)
    teleport(spawn)
    start()
end)

RegisterNetEvent('cobalt_police:leaveJail', function(release)
    stop()
    teleport(release)
end)

for index, task in ipairs(config.jail.jobs) do
    local label <const> = locale(('jail.task.%s'):format(task.id))

    exports.ox_target:addSphereZone({
        coords = task.coords,
        radius = 1.5,
        name = ('cobalt_police:jail_task_%s'):format(index),
        options = {
            {
                name = ('cobalt_police:jail_task_%s'):format(index),
                label = label,
                icon = 'fas fa-broom',
                distance = 2.0,
                canInteract = function() return LocalPlayer.state.jailed ~= nil end,
                onSelect = function()
                    local seconds <const> = lib.callback.await('cobalt_police:jailTask', false, index)

                    if not seconds then
                        return core:Notify({ description = locale('jail.take_break'), type = 'error' })
                    end

                    local finished <const> = core:Progressbar({
                        label = label,
                        duration = seconds * 1000,
                        anim = { scenario = 'WORLD_HUMAN_JANITOR' },
                        disable = { move = true, combat = true },
                    })

                    if finished then
                        TriggerServerEvent('cobalt_police:jailTaskDone', index)
                        core:Notify({ description = locale('jail.time_off'), type = 'success' })
                    end
                end,
            },
        },
    })
end

AddStateBagChangeHandler('jailed', ('player:%s'):format(cache.serverId), function(_, _, remaining)
    if remaining then
        deadline = GetGameTimer() + remaining * 1000
    else
        stop()
    end
end)

RegisterNetEvent('cobalt_core:Client:OnPlayerUnload', stop)

if LocalPlayer.state.jailed then
    deadline = GetGameTimer() + LocalPlayer.state.jailed * 1000
    start()
end

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then
        stop()
    end
end)
