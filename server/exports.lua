local restraints <const> = require 'server.restraints'
local dispatch <const> = require 'server.dispatch'

exports('IsCuffed', function(source) return restraints.cuffType(source) ~= nil end)
exports('Cuff', restraints.force)
exports('Uncuff', restraints.release)

exports('SendDispatch', dispatch.send)
exports('GetCalls', dispatch.visible)
exports('GetCall', dispatch.get)
exports('RespondToCall', dispatch.respond)
exports('AssignToCall', dispatch.assign)
exports('LeaveCall', dispatch.leave)
exports('AddCallNote', dispatch.note)
exports('CloseCall', dispatch.close)

exports('OpenMdt', function(source, page, citizenid)
    TriggerClientEvent('cobalt_police:openMdt', source, page, citizenid)
end)
