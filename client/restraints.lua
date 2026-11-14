local config <const> = require 'config'
local playerProps <const> = require 'client.playerprops'
local core <const> = exports.cobalt_core

local resisting = false

---@type integer?
local handsWatch

---@param ped integer
---@param anim { dict: string, clip: string }
---@param flag? integer
---@param duration? integer
local function play(ped, anim, flag, duration)
    lib.requestAnimDict(anim.dict)
    TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, duration or -1, flag or 49, 0, false, false, false)
    RemoveAnimDict(anim.dict)
end

local DRIVER_SEAT <const> = -1

local DRIVING_CONTROLS <const> = { 59, 63, 64, 71, 72 }

local function cuffedLoop()
    local playerId <const> = cache.playerId
    local anim <const> = config.anims.cuffed
    local nextCheck = 0

    SetEnableHandcuffs(cache.ped, true)
    SetPedCanPlayGestureAnims(cache.ped, false)
    SetPedPathCanUseLadders(cache.ped, false)
    exports.ox_target:disableTargeting(true)
    play(cache.ped, anim)

    while LocalPlayer.state.cuffed do
        for _, control in ipairs(config.disabledControls) do
            DisableControlAction(0, control, true)
        end

        if cache.seat == DRIVER_SEAT then
            for _, control in ipairs(DRIVING_CONTROLS) do
                DisableControlAction(0, control, true)
            end
        end

        DisablePlayerFiring(playerId, true)

        if GetGameTimer() > nextCheck then
            nextCheck = GetGameTimer() + 500

            local onOwnFeet <const> = not LocalPlayer.state.escortedBy and not LocalPlayer.state.isDead

            if onOwnFeet and not IsEntityPlayingAnim(cache.ped, anim.dict, anim.clip, 3) then
                play(cache.ped, anim)
            end
        end

        Wait(0)
    end

    ClearPedSecondaryTask(cache.ped)
    SetEnableHandcuffs(cache.ped, false)
    SetPedCanPlayGestureAnims(cache.ped, true)
    SetPedPathCanUseLadders(cache.ped, true)
    exports.ox_target:disableTargeting(false)
end

playerProps.track('cuffed', function(cuffType)
    local cuff <const> = config.cuffTypes[cuffType]

    if not cuff then return end

    local attach <const> = config.anims.prop

    return { model = cuff.prop, bone = attach.bone, offset = attach.offset, rotation = attach.rotation, rotationOrder = 1 }
end)

AddStateBagChangeHandler('cuffed', ('player:%s'):format(cache.serverId), function(_, _, value)
    if value and not LocalPlayer.state.cuffed then
        SetTimeout(0, cuffedLoop)
    end
end)

---@param escorter integer
local function escortedLoop(escorter)
    local player <const> = GetPlayerFromServerId(escorter)
    local escorterPed <const> = player ~= -1 and GetPlayerPed(player) or 0

    if escorterPed == 0 then return end

    local attach <const> = config.escort

    AttachEntityToEntity(
        cache.ped,
        escorterPed,
        GetPedBoneIndex(escorterPed, attach.bone),
        attach.offset.x,
        attach.offset.y,
        attach.offset.z,
        0.0,
        0.0,
        0.0,
        false,
        false,
        true,
        true,
        2,
        true
    )

    local current

    while LocalPlayer.state.escortedBy == escorter and DoesEntityExist(escorterPed) do
        local moving <const> = GetEntitySpeed(escorterPed) > 0.5
        local anim <const> = moving and (IsPedRunning(escorterPed) or IsPedSprinting(escorterPed)) and config.anims.run
            or moving and config.anims.walk
            or config.anims.cuffed

        if anim ~= current then
            play(cache.ped, anim)
            current = anim
        end

        Wait(250)
    end

    if IsEntityAttached(cache.ped) then
        DetachEntity(cache.ped, true, false)
    end
end

AddStateBagChangeHandler('escortedBy', ('player:%s'):format(cache.serverId), function(_, _, value)
    if value then
        SetTimeout(0, function() escortedLoop(value) end)
    end
end)

RegisterNetEvent('cobalt_police:pairedCuff', function(cuffer, difficulty)
    local player <const> = GetPlayerFromServerId(cuffer)
    local cufferPed <const> = player ~= -1 and GetPlayerPed(player) or 0

    if cufferPed == 0 then return end

    if difficulty and not resisting then
        resisting = true

        CreateThread(function()
            if core:SkillCheck(difficulty) then
                if lib.callback.await('cobalt_police:resist', false, cuffer) then
                    ClearPedTasks(cache.ped)

                    if IsEntityAttached(cache.ped) then
                        DetachEntity(cache.ped, true, false)
                    end
                else
                    core:Notify({ description = locale('restraints.grip_kept'), type = 'error' })
                end
            end

            resisting = false
        end)
    end

    local paired <const> = config.anims.paired

    AttachEntityToEntity(
        cache.ped,
        cufferPed,
        GetPedBoneIndex(cufferPed, paired.bone),
        paired.offset.x,
        paired.offset.y,
        paired.offset.z,
        paired.rotation.x,
        paired.rotation.y,
        paired.rotation.z,
        false,
        false,
        false,
        false,
        20,
        false
    )
    play(cache.ped, paired, 33, paired.duration)

    SetTimeout(paired.duration, function()
        if IsEntityAttached(cache.ped) and not LocalPlayer.state.escortedBy then
            DetachEntity(cache.ped, true, false)
        end
    end)
end)

RegisterNetEvent('cobalt_police:cuffSound', function(target)
    local player <const> = GetPlayerFromServerId(target)

    if player == -1 then return end

    local coords <const> = GetEntityCoords(GetPlayerPed(player))

    PlaySoundFromCoord(-1, 'PIN_BUTTON', coords.x, coords.y, coords.z, 'ATM_SOUNDS', false, 25, false)
end)

RegisterNetEvent('cobalt_police:enterVehicle', function(netId, seat)
    local vehicle <const> = NetworkGetEntityFromNetworkId(netId)

    if vehicle == 0 then return end

    if IsEntityAttached(cache.ped) then
        DetachEntity(cache.ped, true, false)
    end

    if not IsVehicleSeatFree(vehicle, seat) then
        seat = IsVehicleSeatFree(vehicle, 1) and 1 or 2
    end

    SetPedIntoVehicle(cache.ped, vehicle, seat)
end)

RegisterNetEvent('cobalt_police:leaveVehicle', function()
    if cache.vehicle then
        TaskLeaveVehicle(cache.ped, cache.vehicle, 256)
    end
end)

---@param target integer
---@param cuffType 'cuffs'|'zipties'
local function cuff(target, cuffType)
    if not lib.callback.await('cobalt_police:startCuff', false, target, cuffType) then
        return core:Notify({ description = locale('restraints.cannot_restrain'), type = 'error' })
    end

    local finished <const> = core:Progressbar({
        label = locale(cuffType == 'zipties' and 'restraints.tying' or 'restraints.cuffing'),
        duration = config.anims.paired.duration,
        canCancel = false,
        anim = { dict = config.anims.cuffer.dict, clip = config.anims.cuffer.clip, flag = 49 },
        disable = { move = true, combat = true },
    })

    if finished then
        TriggerServerEvent('cobalt_police:finishCuff')
    end
end

---@param target integer
---@param label string
---@param duration integer
local function uncuff(target, label, duration)
    local finished <const> = core:Progressbar({
        label = label,
        duration = duration,
        anim = { dict = config.anims.uncuff.dict, clip = config.anims.uncuff.clip, flag = 49 },
        disable = { move = true, combat = true },
    })

    if finished then
        TriggerServerEvent('cobalt_police:uncuff', target)
    end
end

---@param target integer
local function lockpick(target)
    local difficulty <const> = lib.callback.await('cobalt_police:startLockpick', false, target)

    if not difficulty then
        return core:Notify({ description = locale('restraints.cannot_pick'), type = 'error' })
    end

    if not core:SkillCheck(difficulty) then
        return core:Notify({ description = locale('restraints.failure.lock_held'), type = 'error' })
    end

    TriggerServerEvent('cobalt_police:uncuff', target)
end

local function lowerHands()
    TriggerServerEvent('cobalt_police:handsUp', false)
end

local function watchHands()
    if handsWatch then return end

    local anim <const> = config.anims.handsUp

    handsWatch = SetInterval(function()
        if LocalPlayer.state.handsUp and IsEntityPlayingAnim(cache.ped, anim.dict, anim.clip, 3) then return end

        ClearInterval(handsWatch --[[@as integer]])
        handsWatch = nil

        if LocalPlayer.state.handsUp then
            lowerHands()
        end
    end, 500)
end

lib.addKeybind({
    name = 'cobalt_police_handsup',
    description = locale('restraints.keybind_hands_up'),
    defaultKey = 'X',
    onPressed = function()
        if LocalPlayer.state.cuffed or cache.vehicle or LocalPlayer.state.jailed then return end

        if LocalPlayer.state.isDead or core:progressActive() then return end

        local raised <const> = not LocalPlayer.state.handsUp

        TriggerServerEvent('cobalt_police:handsUp', raised)

        if raised then
            play(cache.ped, config.anims.handsUp)
        else
            ClearPedSecondaryTask(cache.ped)
        end
    end,
})

AddStateBagChangeHandler('handsUp', ('player:%s'):format(cache.serverId), function(_, _, up)
    if up then
        watchHands()
    end
end)

AddStateBagChangeHandler('isDead', ('player:%s'):format(cache.serverId), function(_, _, dead)
    if dead and LocalPlayer.state.handsUp then
        lowerHands()
    end
end)

lib.onCache('vehicle', function(vehicle)
    if vehicle and LocalPlayer.state.handsUp then
        StopAnimTask(cache.ped, config.anims.handsUp.dict, config.anims.handsUp.clip, 1.0)
        lowerHands()
    end
end)

lib.addKeybind({
    name = 'cobalt_police_breakout',
    description = locale('restraints.keybind_break_free'),
    defaultKey = 'H',
    onPressed = function()
        if not LocalPlayer.state.cuffed or resisting then return end

        local difficulty <const>, err <const> = lib.callback.await('cobalt_police:startBreakout', false)

        if not difficulty then
            return core:Notify({
                description = locale(err == 'cooldown' and 'restraints.catch_breath' or 'restraints.cannot_break_free'),
                type = 'error',
            })
        end

        resisting = true
        local passed <const> = core:SkillCheck(difficulty) == true
        local freed <const> = lib.callback.await('cobalt_police:breakout', false, passed)
        resisting = false

        core:Notify({
            description = locale(freed and 'restraints.broke_free' or 'restraints.still_restrained'),
            type = freed and 'success' or 'error',
        })
    end,
})

CreateThread(function()
    if LocalPlayer.state.cuffed then
        cuffedLoop()
    end
end)

if LocalPlayer.state.handsUp then
    watchHands()
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    if LocalPlayer.state.escortedBy and IsEntityAttached(cache.ped) then DetachEntity(cache.ped, true, false) end

    if LocalPlayer.state.cuffed then exports.ox_target:disableTargeting(false) end
end)

return { cuff = cuff, uncuff = uncuff, lockpick = lockpick }
