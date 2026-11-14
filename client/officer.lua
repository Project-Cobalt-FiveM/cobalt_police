local config <const> = require 'config'

local management <const> = exports.cobalt_management

local Officer <const> = {}

---@param job? { name: string, type: string }
---@return boolean
function Officer.isPoliceJob(job)
    return job ~= nil and (job.type == 'leo' or config.departments[job.name] ~= nil)
end

---@param job? { name: string, type: string }
---@return boolean
function Officer.isEmsJob(job)
    return job ~= nil and (job.type == 'ems' or config.emsJobs[job.name] == true)
end

---@return boolean
function Officer.isPolice()
    return Officer.isPoliceJob(management:GetJob())
end

---@return boolean
function Officer.isEms()
    return Officer.isEmsJob(management:GetJob())
end

---@return boolean
function Officer.onDuty()
    return management:GetDuty()
end

---@return boolean
function Officer.isBoss()
    return management:GetJob()?.isboss == true
end

---@return boolean
function Officer.isResponder()
    return (Officer.isPolice() or Officer.isEms()) and Officer.onDuty()
end

---@param coords vector3
---@return string
function Officer.location(coords)
    local street <const>, crossing <const> = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local zone <const> = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
    local name = GetStreetNameFromHashKey(street)

    if crossing ~= 0 then
        name = locale('location.crossing', name, GetStreetNameFromHashKey(crossing))
    end

    return zone ~= 'NULL' and ('%s, %s'):format(name, zone) or name
end

return Officer
