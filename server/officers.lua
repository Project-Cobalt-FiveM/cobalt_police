local config <const> = require 'config'
local Cobalt <const> = exports.cobalt_core:GetCoreObject()

---@class PoliceJob
---@field name string
---@field label string
---@field type string
---@field grade integer
---@field gradeName string
---@field onDuty boolean
---@field isBoss boolean

local Officers <const> = {}

---@param source integer
---@return PoliceJob?
function Officers.job(source)
    local job <const> = exports.cobalt_management:GetJob(source)

    if not job then return end

    return {
        name = job.name,
        label = job.label,
        type = job.type,
        grade = job.grade.level,
        gradeName = job.grade.name,
        onDuty = job.onduty == true,
        isBoss = job.isboss == true,
    }
end

---@param name string job name
---@param field 'label'|'subtitle'
---@return string? text departments.<name>.<field> from locales/en.json, nil when the department has none
function Officers.departmentText(name, field)
    return lib.getLocales()[('departments.%s.%s'):format(name, field)]
end

---@param job? PoliceJob
---@return boolean
local function leo(job)
    return job ~= nil and (job.type == 'leo' or config.departments[job.name] ~= nil)
end

---@param job? PoliceJob
---@return boolean
local function ems(job)
    return job ~= nil and (job.type == 'ems' or config.emsJobs[job.name] == true)
end

---@param source integer
---@return boolean
function Officers.isLeo(source)
    return leo(Officers.job(source))
end

---@param source integer
---@return boolean
function Officers.isEms(source)
    return ems(Officers.job(source))
end

---@param source integer
---@return boolean
function Officers.isOnDuty(source)
    local job <const> = Officers.job(source)

    return leo(job) and job.onDuty
end

---@param source integer
---@return boolean
function Officers.isResponder(source)
    local job <const> = Officers.job(source)

    return (leo(job) or ems(job)) and job.onDuty
end

---@param names table<string, unknown> job names as keys
---@param jobType 'leo' | 'ems'
---@param onDutyOnly boolean
---@param into integer[]
---@param seen table<integer, true>
local function collect(names, jobType, onDutyOnly, into, seen)
    local core <const> = exports.cobalt_core
    local found <const> = { (core:GetPlayersByJob(jobType, onDutyOnly)) }

    for name in pairs(names) do found[#found + 1] = core:GetPlayersByJob(name, onDutyOnly) end

    for _, sources in ipairs(found) do
        for _, id in ipairs(sources) do
            if not seen[id] then
                seen[id] = true
                into[#into + 1] = id
            end
        end
    end
end

---@param jobs ('leo'|'ems')[]
---@param onDutyOnly boolean
---@return integer[]
function Officers.byJobTypes(jobs, onDutyOnly)
    local list <const> = {}
    local seen <const> = {}

    if lib.table.contains(jobs, 'leo') then collect(config.departments, 'leo', onDutyOnly, list, seen) end
    if lib.table.contains(jobs, 'ems') then collect(config.emsJobs, 'ems', onDutyOnly, list, seen) end

    return list
end

---@param source integer
---@return table?
function Officers.player(source)
    return Cobalt.Functions.GetPlayer(source)
end

---@param source integer
---@return string?
function Officers.citizenid(source)
    return Player(source).state['cobalt:citizenid']
end

---@param source integer
---@return string
function Officers.name(source)
    return exports.cobalt_core:GetName(source) or locale('mdt.unknown_person')
end

---@param source integer
---@return string
function Officers.callsign(source)
    local player <const> = Officers.player(source)
    local callsign <const> = player?.PlayerData.metadata.callsign

    return (callsign and callsign ~= 'NO CALLSIGN') and callsign or ''
end

---@param citizenid string
---@return integer?
function Officers.sourceOf(citizenid)
    local player <const> = Cobalt.Functions.GetPlayerByCitizenId(citizenid, true)

    return player?.PlayerData.source
end

---@param a integer
---@param b integer
---@param range number
---@return boolean
function Officers.near(a, b, range)
    local pedA <const>, pedB <const> = GetPlayerPed(a), GetPlayerPed(b)

    if pedA == 0 or pedB == 0 then return false end

    return #(GetEntityCoords(pedA) - GetEntityCoords(pedB)) <= range
end

---@param source integer
---@param coords vector3
---@param range number
---@return boolean
function Officers.nearCoords(source, coords, range)
    local ped <const> = GetPlayerPed(source)

    return ped ~= 0 and #(GetEntityCoords(ped) - coords) <= range
end

---@param source integer
---@param description string
---@param kind? 'success'|'error'|'inform'|'warning'
function Officers.notify(source, description, kind)
    Cobalt.Functions.Notify(source, { description = description, type = kind or 'inform' })
end

return Officers
