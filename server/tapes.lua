local config <const> = require 'config'
local officers <const> = require 'server.officers'

---@class Tape
---@field id integer
---@field type string
---@field from vector3
---@field to vector3

---@type table<integer, Tape>
local tapes <const> = {}

local lastId = 0

---@param source integer
---@return boolean
local function canTape(source)
    return officers.isResponder(source)
end

---@param value any
---@return vector3?
local function toVector(value)
    if type(value) ~= 'table' and type(value) ~= 'vector3' then return end

    local x <const>, y <const>, z <const> = tonumber(value.x), tonumber(value.y), tonumber(value.z)

    if not x or not y or not z then return end

    return vec3(x, y, z)
end

---@return integer
local function standing()
    local count = 0

    for _ in pairs(tapes) do
        count += 1
    end

    return count
end

---@param id integer
local function remove(id)
    if not tapes[id] then return end

    tapes[id] = nil

    TriggerClientEvent('cobalt_police:tapeRemoved', -1, id)
end

RegisterNetEvent('cobalt_police:placeTape', function(tapeType, rawFrom, rawTo)
    local source <const> = source
    local from <const>, to <const> = toVector(rawFrom), toVector(rawTo)

    if not config.tape.types[tapeType] or not from or not to or not canTape(source) then return end

    if #(from.xy - to.xy) > config.tape.maxLength then
        return officers.notify(source, locale('tape.too_long'), 'error')
    end

    if not officers.nearCoords(source, from, config.tape.range) then return end

    if not officers.nearCoords(source, to, config.tape.range) then return end

    if standing() >= config.tape.maxActive then
        return officers.notify(source, locale('tape.too_many'), 'error')
    end

    if not exports.cobalt_inventory:RemoveItem(source, config.tape.item, 1) then
        return officers.notify(source, locale('tape.need_kit'), 'error')
    end

    lastId += 1

    local id <const> = lastId

    tapes[id] = { id = id, type = tapeType, from = from, to = to }

    TriggerClientEvent('cobalt_police:tapePlaced', -1, tapes[id])
    SetTimeout(config.tape.lifetime * 60000, function() remove(id) end)
end)

RegisterNetEvent('cobalt_police:removeTape', function(id)
    local source <const> = source
    local tape <const> = tapes[id]

    if not tape or not canTape(source) then return end

    if not officers.nearCoords(source, (tape.from + tape.to) / 2, config.tape.range) then return end

    remove(id)
end)

lib.callback.register('cobalt_police:getTapes', function()
    return tapes
end)

exports('UseTape', function(event, _, inventory)
    if event == 'usedItem' and canTape(inventory.source) then
        TriggerClientEvent('cobalt_police:pickTape', inventory.source)
    end
end)
