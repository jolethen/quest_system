-- Load API
local quest_api = dofile(minetest.get_modpath("quest_system") .. "/api.lua")

-- Clear previous quests (useful when reloading)
quest_api.clear_quests()

-- === Daily Quests ===
quest_api.register_daily_quest({
    name = "Chop 10 Wood",
    type = "collect_wood",
    target = 10,
    reward = { item = "default:apple", count = 5 }
})

quest_api.register_daily_quest({
    name = "Walk 500 Blocks",
    type = "travel",
    target = 500,
    reward = { item = "default:steel_ingot", count = 1 }
})

-- === Weekly Quests ===
quest_api.register_weekly_quest({
    name = "Collect 100 Wood",
    type = "collect_wood",
    target = 100,
    reward = { item = "default:diamond", count = 1 }
})

quest_api.register_weekly_quest({
    name = "Travel 5000 Blocks",
    type = "travel",
    target = 5000,
    reward = { item = "default:gold_ingot", count = 2 }
})

-- You can now add more quests here or from the console like:
-- /lua quest_api.register_daily_quest({name="Kill 5 Mobs", type="kill", target=5, reward={item="default:apple", count=10}})
