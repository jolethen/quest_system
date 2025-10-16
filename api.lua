local M = {}

M.daily_quests_template = {}
M.weekly_quests_template = {}

-- Validate quest definition
local function valid_def(def)
    return type(def) == "table" and def.name and def.type and def.target and type(def.target) == "number"
end

function M.register_daily_quest(def)
    if not valid_def(def) then
        return false, "Invalid quest definition"
    end
    table.insert(M.daily_quests_template, def)
    return true
end

function M.register_weekly_quest(def)
    if not valid_def(def) then
        return false, "Invalid quest definition"
    end
    table.insert(M.weekly_quests_template, def)
    return true
end

function M.clear_quests()
    M.daily_quests_template = {}
    M.weekly_quests_template = {}
end

-- expose globally for /lua testing convenience
quest_api = M

return M
