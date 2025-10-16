local api = dofile(minetest.get_modpath("quest_system") .. "/api.lua")

-- clear previous templates (on reload)
api.clear_quests()

-- Daily quests (examples)
api.register_daily_quest({
    name = "Chop 10 Wood",
    type = "collect_wood",
    target = 10,
    reward = { item = "default:apple", count = 5 }
})

api.register_daily_quest({
    name = "Walk 500 Blocks",
    type = "travel",
    target = 500,
    reward = { item = "default:steel_ingot", count = 1 }
})

-- Weekly quests (examples)
api.register_weekly_quest({
    name = "Collect 100 Wood",
    type = "collect_wood",
    target = 100,
    reward = { item = "default:diamond", count = 1 }
})

api.register_weekly_quest({
    name = "Travel 5000 Blocks",
    type = "travel",
    target = 5000,
    reward = { item = "default:gold_ingot", count = 2 }
})
