local config <const> = require 'config'
local officers <const> = require 'server.officers'
local restraints <const> = require 'server.restraints'
local log <const> = require 'server.log'
local Cobalt <const> = exports.cobalt_core:GetCoreObject()

---@class Inmate
---@field id integer
---@field citizenid string
---@field months integer
---@field releaseAt integer
---@field confiscationId string?
---@field timer integer?

---@class SentenceRow
---@field id integer
---@field months integer
---@field remaining integer
---@field confiscation_id string?

local Jail <const> = {}

---@type table<integer, Inmate>
local inmates <const> = {}

---@type table<integer, integer>
local taskReadyAt <const> = {}

local SAVE_REMAINING <const> = "UPDATE police_sentences SET remaining = ? WHERE id = ? AND status = 'active'"

local INVENTORY_LOAD_TIMEOUT <const> = 10000

---@param inmate Inmate
local function cancelRelease(inmate)
    if inmate.timer then
        ClearTimeout(inmate.timer)
    end
end

---@param source integer
---@param inmate Inmate
local function schedule(source, inmate)
    local id <const> = inmate.id

    cancelRelease(inmate)

    inmate.timer = SetTimeout(math.max(inmate.releaseAt - os.time(), 0) * 1000 + 500, function()
        local current <const> = inmates[source]

        if current?.id == id and os.time() >= current.releaseAt then
            Jail.release(source, 'served')
        end
    end)
end

---@param source integer
---@param row SentenceRow
---@param citizenid string
local function start(source, row, citizenid)
    local inmate <const> = {
        id = row.id,
        citizenid = citizenid,
        months = row.months,
        releaseAt = os.time() + row.remaining,
        confiscationId = row.confiscation_id,
    }

    inmates[source] = inmate
    restraints.release(source)
    Player(source).state:set('jailed', row.remaining, true)
    TriggerClientEvent('cobalt_police:enterJail', source, config.jail.spawn)
    schedule(source, inmate)
end

---@param source integer
local function persist(source)
    local inmate <const> = inmates[source]

    if not inmate then return end

    cancelRelease(inmate)
    inmates[source] = nil

    MySQL.update.await(SAVE_REMAINING, { math.max(inmate.releaseAt - os.time(), 0), inmate.id })
end

---@param target integer
---@param months integer
---@param reason? string
---@param by? string
---@param incidentId? integer
---@return integer? sentenceId
function Jail.jail(target, months, reason, by, incidentId)
    months = math.floor(tonumber(months) or 0)

    local citizenid <const> = officers.citizenid(target)

    if months <= 0 or not citizenid or inmates[target] then return end

    local confiscationId <const> = config.jail.confiscate and exports.cobalt_inventory:Confiscate(target, 'jail') or nil
    local remaining <const> = months * config.jail.secondsPerMonth

    local id <const> = MySQL.insert.await([[
        INSERT INTO police_sentences (citizenid, months, remaining, reason, incident_id, confiscation_id, sentenced_by)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { citizenid, months, remaining, tostring(reason or ''):sub(1, 255), incidentId, confiscationId, by })

    if not id then
        if confiscationId then
            exports.cobalt_inventory:Restore(citizenid, confiscationId)
        end

        return
    end

    start(target, { id = id, months = months, remaining = remaining, confiscation_id = confiscationId }, citizenid)

    log('jail', by, citizenid, { months = months, reason = reason })
    officers.notify(target, locale('jail.sentenced', months), 'error')

    return id
end

---@param target integer
---@param months integer
---@return boolean extended false when the player isn't serving a sentence
function Jail.extend(target, months)
    local inmate <const> = inmates[target]

    if not inmate or months <= 0 then return false end

    inmate.months += months
    inmate.releaseAt += months * config.jail.secondsPerMonth

    local remaining <const> = math.max(inmate.releaseAt - os.time(), 0)

    MySQL.update.await('UPDATE police_sentences SET months = months + ?, remaining = ? WHERE id = ?', {
        months,
        remaining,
        inmate.id,
    })

    Player(target).state:set('jailed', remaining, true)
    schedule(target, inmate)
    officers.notify(target, locale('jail.extended', months), 'error')

    return true
end

---@param citizenid string
---@param months integer
---@param reason? string
---@param by? string
---@param incidentId? integer
---@return integer?
function Jail.queue(citizenid, months, reason, by, incidentId)
    months = math.floor(tonumber(months) or 0)

    if months <= 0 then return end

    return MySQL.insert.await([[
        INSERT INTO police_sentences (citizenid, months, remaining, reason, incident_id, sentenced_by)
        SELECT citizenid, ?, ?, ?, ?, ? FROM players WHERE citizenid = ?
    ]], {
        months,
        months * config.jail.secondsPerMonth,
        tostring(reason or ''):sub(1, 255),
        incidentId,
        by,
        citizenid,
    })
end

---@param target integer
---@param reason? 'served'|'released'
---@param by? string
---@return boolean
function Jail.release(target, reason, by)
    local inmate <const> = inmates[target]

    if not inmate then return false end

    cancelRelease(inmate)
    inmates[target] = nil
    taskReadyAt[target] = nil

    MySQL.update.await("UPDATE police_sentences SET status = ?, remaining = 0, ended_at = NOW() WHERE id = ?", {
        reason == 'served' and 'served' or 'released',
        inmate.id,
    })

    if inmate.confiscationId then
        exports.cobalt_inventory:Restore(inmate.citizenid, inmate.confiscationId)
    end

    Player(target).state:set('jailed', nil, true)
    TriggerClientEvent('cobalt_police:leaveJail', target, config.jail.release)
    log('release', by, inmate.citizenid, { reason = reason })
    officers.notify(target, locale('jail.released'), 'success')

    return true
end

---@param target integer
---@return integer seconds
function Jail.remaining(target)
    local inmate <const> = inmates[target]

    return inmate and math.max(inmate.releaseAt - os.time(), 0) or 0
end

---@param citizenid string
---@return { months: integer, remaining: integer, releaseAt: integer }?
function Jail.byCitizen(citizenid)
    local source <const> = officers.sourceOf(citizenid)
    local inmate <const> = source and inmates[source]

    if inmate then
        return { months = inmate.months, remaining = Jail.remaining(source), releaseAt = inmate.releaseAt }
    end

    local row <const> = MySQL.single.await(
        "SELECT months, remaining FROM police_sentences WHERE citizenid = ? AND status = 'active' ORDER BY id DESC LIMIT 1",
        { citizenid }
    )

    return row and { months = row.months, remaining = row.remaining, releaseAt = os.time() + row.remaining }
end

---@param target integer
---@param seconds integer
---@return boolean
function Jail.reduce(target, seconds)
    local inmate <const> = inmates[target]

    if not inmate or seconds <= 0 then return false end

    inmate.releaseAt -= seconds
    Player(target).state:set('jailed', math.max(inmate.releaseAt - os.time(), 0), true)
    schedule(target, inmate)

    return true
end

lib.callback.register('cobalt_police:jailTask', function(source, index)
    local task <const> = config.jail.jobs[index]

    if not task or not inmates[source] then return false end

    if (taskReadyAt[source] or 0) > os.time() then return false end

    if not officers.nearCoords(source, task.coords, 5.0) then return false end

    taskReadyAt[source] = os.time() + task.seconds

    return task.seconds
end)

RegisterNetEvent('cobalt_police:jailTaskDone', function(index)
    local source <const> = source
    local task <const> = config.jail.jobs[index]
    local readyAt <const> = taskReadyAt[source]

    if not task or not inmates[source] or not readyAt or readyAt > os.time() + 1 then return end

    if not officers.nearCoords(source, task.coords, 5.0) then return end

    taskReadyAt[source] = nil
    Jail.reduce(source, config.jail.jobReduction)
end)

---@param source integer
---@param sentenceId integer
---@return string? confiscationId
local function confiscateQueued(source, sentenceId)
    local loaded <const> = pcall(lib.waitFor, function()
        return Player(source).state.inventoryLoaded
    end, nil, INVENTORY_LOAD_TIMEOUT)

    if not loaded then return end

    local id <const> = exports.cobalt_inventory:Confiscate(source, 'jail')

    if id then
        MySQL.update.await('UPDATE police_sentences SET confiscation_id = ? WHERE id = ?', { id, sentenceId })
    end

    return id
end

---@param player table
local function restore(player)
    local source <const> = player.PlayerData.source
    local citizenid <const> = player.PlayerData.citizenid
    local row <const> = MySQL.single.await(
        "SELECT id, months, remaining, confiscation_id FROM police_sentences WHERE citizenid = ? AND status = 'active' ORDER BY id DESC LIMIT 1",
        { citizenid }
    )

    if not row then return end

    if row.remaining <= 0 then
        inmates[source] = {
            id = row.id,
            citizenid = citizenid,
            months = row.months,
            releaseAt = os.time(),
            confiscationId = row.confiscation_id,
        }

        return Jail.release(source, 'served')
    end

    if config.jail.confiscate and not row.confiscation_id then
        row.confiscation_id = confiscateQueued(source, row.id)

        if officers.citizenid(source) ~= citizenid then return end
    end

    start(source, row, citizenid)
end

AddEventHandler('cobalt_core:Server:PlayerLoaded', restore)

AddEventHandler('cobalt_core:Server:OnPlayerUnload', function(source)
    if Player(source).state.jailed ~= nil then
        Player(source).state:set('jailed', nil, true)
    end

    taskReadyAt[source] = nil
    persist(source)
end)

AddEventHandler('playerDropped', function()
    local source <const> = source

    persist(source)
    taskReadyAt[source] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    local now <const> = os.time()
    local rows <const> = {}

    for _, inmate in pairs(inmates) do
        rows[#rows + 1] = { math.max(inmate.releaseAt - now, 0), inmate.id }
    end

    if #rows > 0 then
        MySQL.prepare(SAVE_REMAINING, rows)
    end
end)

CreateThread(function()
    for _, source in ipairs(Cobalt.Functions.GetPlayers()) do
        local player <const> = Cobalt.Functions.GetPlayer(source)

        if player then
            restore(player)
        end
    end
end)

return Jail
