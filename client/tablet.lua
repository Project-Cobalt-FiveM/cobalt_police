local config <const> = require 'config'
local playerProps <const> = require 'client.playerprops'

local ANIM <const> = config.mdt.tablet

local Tablet <const> = {}

function Tablet.hold()
    lib.playAnim(cache.ped, ANIM.dict, ANIM.clip, 3.0, 3.0, -1, ANIM.flag)
end

function Tablet.put()
    StopAnimTask(cache.ped, ANIM.dict, ANIM.clip, 1.0)
end

playerProps.track('mdtTablet', function()
    local prop <const> = ANIM.prop

    return { model = prop.model, bone = prop.bone, offset = prop.offset, rotation = prop.rotation, rotationOrder = 2 }
end)

return Tablet
