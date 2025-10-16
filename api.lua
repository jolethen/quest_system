local M = {}

-- Data containers for quest templates
M.daily_quests_template = {}
M.weekly_quests_template = {}

-- Function to register daily quests
function M.register_daily_quest(def)
    if not (def.name and def.type and def.target) then
        return false, "Invalid quest definition"
    end
    table.insert(M.daily_quests_template, def)
    return true
end

-- Function to register weekly quests
function M.register_weekly_quest(def)
    if not (def.name and def.type and def.target) then
        return false, "Invalid quest definition"
    end
    table.insert(M.weekly_quests_template, def)
    return true
end

-- Function to clear all quests (useful for reloading)
function M.clear_quests()
    M.daily_quests_template = {}
    M.weekly_quests_template = {}
end

return M
