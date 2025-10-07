-- mod name: quest_system
local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

-- Persistent storage
local storage = minetest.get_mod_storage()

-- Player quest data
local player_data = {}

-- ===== Helper Functions =====
local function load_player(name)
    local str = storage:get_string(name)
    if str == "" then
        player_data[name] = {
            daily = {},
            weekly = {},
            last_daily = 0,
            last_weekly = 0
        }
    else
        player_data[name] = minetest.deserialize(str)
    end
end

local function save_player(name)
    storage:set_string(name, minetest.serialize(player_data[name]))
end

local function is_new_day(last_time)
    local last = os.date("*t", last_time)
    local now = os.date("*t")
    return last.yday ~= now.yday or last.year ~= now.year
end

local function is_new_week(last_time)
    local last = os.date("*t", last_time)
    local now = os.date("*t")
    local last_week = os.date("%U", last_time)
    local now_week = os.date("%U")
    return last_week ~= now_week or last.year ~= now.year
end

-- ===== Quest Templates =====
local daily_quests_template = {
    {name="Kill 5 mobs", type="kill", target=5},
    {name="Collect 10 wood", type="collect", target=10}
}

local weekly_quests_template = {
    {name="Kill 50 mobs", type="kill", target=50},
    {name="Collect 50 wood", type="collect", target=50}
}

local function reset_quests(name)
    -- Daily reset
    if is_new_day(player_data[name].last_daily) then
        player_data[name].daily = {}
        for _, q in ipairs(daily_quests_template) do
            table.insert(player_data[name].daily, {name=q.name, type=q.type, target=q.target, progress=0, done=false})
        end
        player_data[name].last_daily = os.time()
    end
    -- Weekly reset
    if is_new_week(player_data[name].last_weekly) then
        player_data[name].weekly = {}
        for _, q in ipairs(weekly_quests_template) do
            table.insert(player_data[name].weekly, {name=q.name, type=q.type, target=q.target, progress=0, done=false})
        end
        player_data[name].last_weekly = os.time()
    end
end

-- ===== Forms =====
local function show_quests_formspec(player)
    local name = player:get_player_name()
    reset_quests(name)
    
    local formspec = "size[8,9]"
    formspec = formspec .. "label[0,0;=== Daily Quests ===]"
    for i, q in ipairs(player_data[name].daily) do
        local status = q.done and "✔ Done" or q.progress.."/"..q.target
        formspec = formspec .. string.format("label[0,%d;%s: %s]", i, q.name, status)
    end
    
    formspec = formspec .. "label[0,5;=== Weekly Quests ===]"
    for i, q in ipairs(player_data[name].weekly) do
        local status = q.done and "✔ Done" or q.progress.."/"..q.target
        formspec = formspec .. string.format("label[0,%d;%s: %s]", i+5, q.name, status)
    end
    
    minetest.show_formspec(name, "quest_system:quests", formspec)
end

-- ===== Chat Command =====
minetest.register_chatcommand("quests", {
    description = "Show your quests",
    func = function(name)
        if not player_data[name] then load_player(name) end
        show_quests_formspec(minetest.get_player_by_name(name))
        return true
    end
})

-- ===== Quest Progress Update =====
local function update_quest_progress(name, quest_type, amount)
    if not player_data[name] then load_player(name) end
    reset_quests(name)
    
    for _, q in ipairs(player_data[name].daily) do
        if q.type == quest_type and not q.done then
            q.progress = q.progress + amount
            if q.progress >= q.target then q.done = true end
        end
    end
    for _, q in ipairs(player_data[name].weekly) do
        if q.type == quest_type and not q.done then
            q.progress = q.progress + amount
            if q.progress >= q.target then q.done = true end
        end
    end
    save_player(name)
end

-- ===== Example Hooks =====
-- Kill mob
minetest.register_on_killedplayer(function(victim, killer, reason)
    if killer and killer:is_player() then
        update_quest_progress(killer:get_player_name(), "kill", 1)
    end
end)

-- Collect item example (you can hook this to your own gather events)
minetest.register_on_dignode(function(pos, oldnode, digger)
    if digger and digger:is_player() then
        if oldnode.name == "default:wood" then
            update_quest_progress(digger:get_player_name(), "collect", 1)
        end
    end
end)
