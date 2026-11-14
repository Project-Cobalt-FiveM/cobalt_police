---@class PlayerPropSpec
---@field model integer
---@field bone integer
---@field offset vector3
---@field rotation vector3
---@field rotationOrder integer

local PlayerProps <const> = {}

local JOIN_TIMEOUT_MS <const> = 5000

---@param serverId integer
---@return integer
local function pedOf(serverId)
    local player <const> = GetPlayerFromServerId(serverId)

    return player ~= -1 and GetPlayerPed(player) or 0
end

---@param key string
---@param build fun(value: any): PlayerPropSpec?
function PlayerProps.track(key, build)
    ---@type table<integer, integer>
    local props <const> = {}

    ---@param serverId integer
    local function remove(serverId)
        local prop <const> = props[serverId]

        props[serverId] = nil

        if prop and DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end

    ---@param serverId integer
    local function sync(serverId)
        remove(serverId)

        local value <const> = Player(serverId).state[key]
        local spec <const> = value and build(value)

        if not spec or pedOf(serverId) == 0 then return end

        lib.requestModel(spec.model)

        local ped <const> = pedOf(serverId)

        if ped == 0 or props[serverId] or Player(serverId).state[key] ~= value then
            return SetModelAsNoLongerNeeded(spec.model)
        end

        local prop <const> = CreateObject(spec.model, 0.0, 0.0, 0.0, false, false, false)

        SetModelAsNoLongerNeeded(spec.model)
        AttachEntityToEntity(
            prop,
            ped,
            GetPedBoneIndex(ped, spec.bone),
            spec.offset.x,
            spec.offset.y,
            spec.offset.z,
            spec.rotation.x,
            spec.rotation.y,
            spec.rotation.z,
            true,
            true,
            false,
            true,
            spec.rotationOrder,
            true
        )

        props[serverId] = prop
    end

    AddStateBagChangeHandler(key, nil, function(bagName)
        local serverId <const> = tonumber(bagName:match('^player:(%d+)$'))

        if serverId then
            CreateThread(function() sync(serverId) end)
        end
    end)

    RegisterNetEvent('onPlayerJoining', function(serverId)
        CreateThread(function()
            local streamed <const> = pcall(lib.waitFor, function()
                if pedOf(serverId) ~= 0 then return true end
            end, nil, JOIN_TIMEOUT_MS)

            if streamed then
                sync(serverId)
            end
        end)
    end)

    RegisterNetEvent('onPlayerDropped', function(serverId)
        remove(serverId)
    end)

    AddEventHandler('onResourceStop', function(resource)
        if resource ~= cache.resource then return end

        for serverId in pairs(props) do
            remove(serverId)
        end
    end)

    CreateThread(function()
        for _, player in ipairs(GetActivePlayers()) do
            sync(GetPlayerServerId(player))
        end
    end)
end

return PlayerProps
