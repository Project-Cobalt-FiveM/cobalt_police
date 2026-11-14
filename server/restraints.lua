local config <const> = require 'config'
local officers <const> = require 'server.officers'
local log <const> = require 'server.log'

---@class PendingCuff
---@field target integer
---@field type PoliceCuffType
---@field canResist boolean
---@field resisted? boolean set once the target's resist attempt is rolled
---@field expires integer
---@field startedAt integer

local Restraints <const> = {}

---@type table<integer, PendingCuff>
local pending <const> = {}

---@type table<integer, integer>
local escorts <const> = {}

---@type table<integer, integer>
local breakoutAt <const> = {}

local MIN_STAGE_MS <const> = 600

local MIN_CUFF_MS <const> = config.anims.paired.duration - 250

---@type table<integer, { at: integer, stages: integer }>
local breakoutPending <const> = {}

---@type table<integer, { target: integer, at: integer, stages: integer }>
local lockpicks <const> = {}

---@param chance number 0 to 1
---@return boolean
local function roll(chance)
    return math.random() < chance
end

---@param startedAt integer game time the skill check began
---@param stages integer
---@return boolean
local function skillCheckTook(startedAt, stages)
    return GetGameTimer() - startedAt >= stages * MIN_STAGE_MS
end

---@param remover integer
---@param target integer
---@return boolean
local function lockpickDone(remover, target)
    local pick <const> = lockpicks[remover]

    lockpicks[remover] = nil

    if not pick or pick.target ~= target or not skillCheckTook(pick.at, pick.stages) then return false end

    return roll(config.cuffTypes.cuffs.lockpick.chance)
end

---@type number?
local escortInterval

---@param source integer
---@return PoliceCuffState?
function Restraints.state(source)
    local stored <const> = officers.player(source)?.PlayerData.metadata.cuffed

    if not stored?.type then return end

    return { type = stored.type, by = stored.by or 'unknown' }
end

---@param source integer
---@return PoliceCuffType?
function Restraints.cuffType(source)
    return Player(source).state.cuffed
end

---@param source integer
---@return boolean
local function incapacitated(source)
    return Restraints.cuffType(source) ~= nil or escorts[source] ~= nil or Player(source).state.isDead == true
end

---@param source integer
---@param state? PoliceCuffState
local function write(source, state)
    Player(source).state:set('cuffed', state?.type, true)

    local player <const> = officers.player(source)

    if player then
        player.Functions.SetMetaData('cuffed', state)
        player.Functions.SetMetaData('ishandcuffed', state ~= nil)
    end

    if state then
        Player(source).state:set('handsUp', false, true)
    end
end

local CUFF_SOUND_RANGE <const> = 25.0

---@param target integer
local function playCuffSound(target)
    for _, player in ipairs(lib.getNearbyPlayers(GetEntityCoords(GetPlayerPed(target)), CUFF_SOUND_RANGE)) do
        TriggerClientEvent('cobalt_police:cuffSound', player.id, target)
    end
end

---@param target integer
---@param escorter integer?
local function setEscort(target, escorter)
    escorts[target] = escorter
    Player(target).state:set('escortedBy', escorter, true)

    if next(escorts) and not escortInterval then
        escortInterval = SetInterval(function()
            for t, e in pairs(escorts) do
                if not officers.near(t, e, config.escort.maxDistance) then
                    setEscort(t, nil)
                end
            end
        end, 1000)
    elseif not next(escorts) and escortInterval then
        ClearInterval(escortInterval)
        escortInterval = nil
    end
end

---@param target integer
---@param cuffType? PoliceCuffType
---@param by? string
---@return boolean
function Restraints.force(target, cuffType, by)
    if not officers.citizenid(target) or Restraints.cuffType(target) then return false end

    write(target, { type = cuffType or 'cuffs', by = by or 'system' })

    return true
end

---@param target integer
---@return boolean
function Restraints.release(target)
    if not Restraints.cuffType(target) then return false end

    if escorts[target] then
        setEscort(target, nil)
    end

    write(target, nil)

    return true
end

---@param officer integer
---@param target integer
---@param cuffType PoliceCuffType
---@return boolean ok
---@return string? err
function Restraints.begin(officer, target, cuffType)
    local cuff <const> = config.cuffTypes[cuffType]

    if not cuff then
        return false, 'invalid_type'
    end

    if officer == target or not officers.citizenid(target) then
        return false, 'invalid_target'
    end

    if incapacitated(officer) then
        return false, 'incapacitated'
    end

    if cuffType == 'cuffs' and not officers.isLeo(officer) then
        return false, 'not_police'
    end

    if Restraints.cuffType(target) then
        return false, 'already_cuffed'
    end

    if not officers.near(officer, target, config.cuffRange) then
        return false, 'too_far'
    end

    if not exports.cobalt_inventory:HasItem(officer, cuff.item, 1) then
        return false, 'missing_item'
    end

    local compliant <const> = Player(target).state.handsUp == true

    if cuffType == 'zipties' and not compliant then
        return false, 'not_compliant'
    end

    local entry <const> = {
        target = target,
        type = cuffType,
        canResist = not compliant,
        expires = os.time() + 10,
        startedAt = GetGameTimer(),
    }
    pending[officer] = entry

    TriggerClientEvent('cobalt_police:pairedCuff', target, officer, not compliant and cuff.breakout or nil)

    return true
end

---@param officer integer
---@return boolean ok
---@return string? err
function Restraints.finish(officer)
    local entry <const> = pending[officer]
    pending[officer] = nil

    if not entry or entry.expires < os.time() then
        return false, 'expired'
    end

    if incapacitated(officer) then
        return false, 'incapacitated'
    end

    if GetGameTimer() - entry.startedAt < MIN_CUFF_MS then
        return false, 'too_fast'
    end

    if entry.resisted then
        return false, 'resisted'
    end

    if Restraints.cuffType(entry.target) then
        return false, 'already_cuffed'
    end

    if not officers.near(officer, entry.target, config.cuffRange) then
        return false, 'too_far'
    end

    local cuff <const> = config.cuffTypes[entry.type]

    if cuff.consume and not exports.cobalt_inventory:RemoveItem(officer, cuff.item, 1) then
        return false, 'missing_item'
    end

    local by <const> = officers.citizenid(officer) or 'unknown'

    write(entry.target, { type = entry.type, by = by })
    playCuffSound(entry.target)
    log('cuff', by, officers.citizenid(entry.target), { type = entry.type }, officer, entry.target)

    return true
end

---@param remover integer
---@param target integer
---@return boolean ok
---@return string? err
function Restraints.remove(remover, target)
    local state <const> = Restraints.state(target)

    if not state then
        return false, 'not_cuffed'
    end

    if remover == target then
        return false, 'invalid_target'
    end

    if incapacitated(remover) then
        return false, 'incapacitated'
    end

    if not officers.near(remover, target, config.cuffRange) then
        return false, 'too_far'
    end

    local cuff <const> = config.cuffTypes[state.type]
    local removerCid <const> = officers.citizenid(remover)
    local isLeo <const> = officers.isLeo(remover)
    local picking <const> = not isLeo and state.type == 'cuffs' and cuff.lockpick ~= nil and lockpicks[remover] ~= nil
    local picked <const> = picking and lockpickDone(remover, target)
    local allowed <const> = isLeo
        or (state.type == 'zipties' and (removerCid == state.by or exports.cobalt_inventory:HasItem(remover, cuff.cutter, 1)))
        or (picked and exports.cobalt_inventory:RemoveItem(remover, cuff.lockpick.item, 1))

    if not allowed then
        return false, picking and 'lock_held' or 'not_allowed'
    end

    Restraints.release(target)
    playCuffSound(target)
    log('uncuff', removerCid, officers.citizenid(target), { type = state.type, police = isLeo }, remover, target)

    return true
end

---@param officer integer
---@param target integer
---@return boolean
function Restraints.escort(officer, target)
    if officer == target or escorts[target] or incapacitated(officer) then return false end

    if not Restraints.cuffType(target) then return false end

    if not officers.near(officer, target, config.cuffRange) then return false end

    setEscort(target, officer)

    return true
end

---@param officer integer
---@param target integer
---@return boolean
function Restraints.stopEscort(officer, target)
    if escorts[target] ~= officer then return false end

    setEscort(target, nil)

    return true
end

---@param officer integer
---@param target integer
---@param netId integer
---@param seat integer
---@return boolean
function Restraints.seat(officer, target, netId, seat)
    if seat < 0 or escorts[target] ~= officer or incapacitated(officer) then return false end

    local vehicle <const> = NetworkGetEntityFromNetworkId(netId)

    if vehicle == 0 or GetEntityType(vehicle) ~= 2 then return false end

    local distance <const> = #(GetEntityCoords(GetPlayerPed(officer)) - GetEntityCoords(vehicle))

    if distance > config.escort.vehicleRange then return false end

    setEscort(target, nil)
    TriggerClientEvent('cobalt_police:enterVehicle', target, netId, seat)

    return true
end

---@param officer integer
---@param target integer
---@return boolean
function Restraints.unseat(officer, target)
    if incapacitated(officer) or not Restraints.cuffType(target) then return false end

    if not officers.near(officer, target, config.escort.vehicleRange) then return false end

    TriggerClientEvent('cobalt_police:leaveVehicle', target)

    return true
end

---@param officer integer
---@param target integer
---@return boolean
function Restraints.search(officer, target)
    if not officers.isLeo(officer) or incapacitated(officer) or not Restraints.cuffType(target) then return false end

    if not officers.near(officer, target, config.cuffRange) then return false end

    exports.cobalt_inventory:SearchPlayer(officer, target, { mode = 'remove' })
    log('search', officers.citizenid(officer), officers.citizenid(target), nil, officer, target)

    return true
end

lib.callback.register('cobalt_police:startCuff', function(source, target, cuffType)
    if type(target) ~= 'number' or type(cuffType) ~= 'string' then return false end

    return Restraints.begin(source, target, cuffType)
end)

lib.callback.register('cobalt_police:startLockpick', function(source, target)
    local lock <const> = config.cuffTypes.cuffs.lockpick

    if type(target) ~= 'number' or target == source or not lock then return false end
    if Restraints.cuffType(target) ~= 'cuffs' then return false end
    if incapacitated(source) or not officers.near(source, target, config.cuffRange) then return false end
    if not exports.cobalt_inventory:HasItem(source, lock.item, 1) then return false end

    lockpicks[source] = { target = target, at = GetGameTimer(), stages = #lock.difficulty }

    return lock.difficulty
end)

lib.callback.register('cobalt_police:startBreakout', function(source)
    local cuffType <const> = Restraints.cuffType(source)

    if not cuffType then return false end

    if (breakoutAt[source] or 0) > os.time() then
        return false, 'cooldown'
    end

    breakoutAt[source] = os.time() + config.breakoutCooldown
    breakoutPending[source] = { at = GetGameTimer(), stages = #config.cuffTypes[cuffType].breakout }

    return config.cuffTypes[cuffType].breakout
end)

---@type table<string, true>
local UNCUFF_NOTICES <const> = { not_allowed = true, lock_held = true }

---@param err string
---@return string
local function failure(err)
    return locale(('restraints.failure.%s'):format(err))
end

RegisterNetEvent('cobalt_police:finishCuff', function()
    local source <const> = source
    local ok <const>, err <const> = Restraints.finish(source)

    if not ok then
        officers.notify(source, failure(err --[[@as string]]), 'error')
    end
end)

lib.callback.register('cobalt_police:resist', function(source, cuffer)
    local entry <const> = pending[cuffer]

    if not entry or entry.target ~= source or not entry.canResist or entry.resisted ~= nil then return false end

    local cuff <const> = config.cuffTypes[entry.type]

    if not skillCheckTook(entry.startedAt, #cuff.breakout) then return false end

    entry.resisted = roll(cuff.escapeChance)

    return entry.resisted
end)

RegisterNetEvent('cobalt_police:uncuff', function(target)
    local source <const> = source

    if type(target) ~= 'number' then return end

    local ok <const>, err <const> = Restraints.remove(source, target)

    if not ok and UNCUFF_NOTICES[err] then
        officers.notify(source, failure(err --[[@as string]]), 'error')
    end
end)

lib.callback.register('cobalt_police:breakout', function(source, passed)
    local started <const> = breakoutPending[source]

    breakoutPending[source] = nil

    if not started or passed ~= true or not skillCheckTook(started.at, started.stages) then return false end

    local cuffType <const> = Restraints.cuffType(source)

    if not cuffType or not roll(config.cuffTypes[cuffType].escapeChance) then return false end

    Restraints.release(source)
    log('breakout', nil, officers.citizenid(source), { type = cuffType }, source)

    return true
end)

RegisterNetEvent('cobalt_police:handsUp', function(raised)
    local source <const> = source
    local raisedNow <const> = raised == true
    local state <const> = Player(source).state

    if (state.handsUp == true) == raisedNow or state.cuffed then return end

    state:set('handsUp', raisedNow, true)
end)

RegisterNetEvent('cobalt_police:escort', function(target, start)
    local source <const> = source

    if type(target) ~= 'number' then return end

    if start then
        Restraints.escort(source, target)
    else
        Restraints.stopEscort(source, target)
    end
end)

RegisterNetEvent('cobalt_police:seat', function(target, netId, seat)
    local source <const> = source

    if type(target) ~= 'number' or type(netId) ~= 'number' or type(seat) ~= 'number' then return end

    Restraints.seat(source, target, netId, seat)
end)

RegisterNetEvent('cobalt_police:unseat', function(target)
    local source <const> = source

    if type(target) ~= 'number' then return end

    Restraints.unseat(source, target)
end)

RegisterNetEvent('cobalt_police:search', function(target)
    local source <const> = source

    if type(target) ~= 'number' then return end

    Restraints.search(source, target)
end)

AddEventHandler('cobalt_core:Server:PlayerLoaded', function(player)
    local stored <const> = player.PlayerData.metadata.cuffed

    if not stored?.type then return end

    Player(player.PlayerData.source).state:set('cuffed', stored.type, true)
end)

---@param source integer
local function releaseEscorts(source)
    for target, escorter in pairs(escorts) do
        if target == source or escorter == source then
            setEscort(target, nil)
        end
    end
end

AddEventHandler('cobalt_core:Server:OnPlayerUnload', function(source)
    releaseEscorts(source)
    Player(source).state:set('cuffed', nil, true)

    if Player(source).state.handsUp then
        Player(source).state:set('handsUp', false, true)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for target in pairs(escorts) do Player(target).state:set('escortedBy', nil, true) end
end)

AddEventHandler('playerDropped', function()
    local source <const> = source

    pending[source] = nil
    breakoutAt[source] = nil
    breakoutPending[source] = nil
    lockpicks[source] = nil

    releaseEscorts(source)
end)

return Restraints
