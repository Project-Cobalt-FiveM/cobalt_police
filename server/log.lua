---@alias PoliceLogAction 'cuff'|'uncuff'|'breakout'|'search'|'jail'|'release'|'clamp'|'unclamp'|'sentence'|'licence'

---@param action PoliceLogAction
---@param officer? string
---@param target? string
---@param detail? table
---@param source? integer the acting player, logged with `LogPlayer`
---@param targetSource? integer
local function log(action, officer, target, detail, source, targetSource)
    local category <const> = 'police.' .. action
    local message <const> = ('%s: %s -> %s'):format(action, officer or 'system', target or '-')
    local data <const> = { officer = officer, target = target, detail = detail }

    if source then
        return exports.cobalt_core:LogPlayer(source, category, message, data, nil, targetSource)
    end

    exports.cobalt_core:Log(category, message, data)
end

return log
