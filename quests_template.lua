-- Copy this file to create a custom quests file or edit it directly.
-- Use this template to add new daily/weekly quests.

local api = dofile(minetest.get_modpath("quest_system") .. "/api.lua")

-- If you want to clear all previous templates at runtime, uncomment:
-- api.clear_quests()

-- Example daily quest
api.register_daily_quest({
    name = "Example: Mine 20 Stone",
    type = "mine_stone",
    target = 20,
    reward = { item = "default:pick_steel", count = 1 }
})

-- Example weekly quest
api.register_weekly_quest({
    name = "Example Weekly: Gather 200 Wood",
    type = "collect_wood",
    target = 200,
    reward = { item = "default:diamond", count = 1 }
})

-- Notes:
-- - name: string (displayed in formspec)
-- - type: string (must match the event you implement in init.lua)
-- - target: number (progress to reach)
-- - reward: table { item = "<itemname>", count = <number> }
