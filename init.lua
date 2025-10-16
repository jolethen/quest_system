-- mod: quest_system
local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
local storage = minetest.get_mod_storage()
local player_data = {}

-------------------------------------------------------
-- ✅ Safe Player Data Load / Save
-------------------------------------------------------
local function load_player(name)
    if player_data[name] then return end
    local raw = storage:get_string(name)
    local data = minetest.deserialize(raw)
    if type(data) ~= "table" then
        data = {daily = {}, weekly = {}, last_daily = 0, last_weekly = 0}
    end
    player_data[name] = data
end

local function save_player(name)
    if player_data[name] then
        storage:set_string(name, minetest.serialize(player_data[name]))
    end
end

-------------------------------------------------------
-- ✅ Time Helpers
-------------------------------------------------------
local function is_new_day(last_time)
    if not last_time or last_time == 0 then return true end
    local last = os.date("*t", last_time)
    local now = os.date("*t")
    return last.yday ~= now.yday or last.year ~= now.year
end

local function is_new_week(last_time)
    if not last_time or last_time == 0 then return true end
    local last = os.date("%U", last_time)
    local now = os.date("%U")
    local ly = os.date("*t", last_time).year
    local ny = os.date("*t").year
    return (last ~= now) or (ly ~= ny)
end

-------------------------------------------------------
-- ✅ Quest Templates (You can edit these)
-------------------------------------------------------
local daily_quests_template = {
    {name="Chop 10 wood", type="collect_wood", target=10},
    {name="Walk 500 blocks", type="travel", target=500},
}

local weekly_quests_template = {
    {name="Collect 100 wood", type="collect_wood", target=100},
    {name="Travel 5000 blocks", type="travel", target=5000},
}

-------------------------------------------------------
-- ✅ Reset System
-------------------------------------------------------
local function reset_quests(name)
    load_player(name)

    if is_new_day(player_data[name].last_daily) then
        player_data[name].daily = {}
        for _, q in ipairs(daily_quests_template) do
            table.insert(player_data[name].daily, {
                name=q.name, type=q.type, target=q.target,
                progress=0, done=false
            })
        end
        player_data[name].last_daily = os.time()
    end

    if is_new_week(player_data[name].last_weekly) then
        player_data[name].weekly = {}
        for _, q in ipairs(weekly_quests_template) do
            table.insert(player_data[name].weekly, {
                name=q.name, type=q.type, target=q.target,
                progress=0, done=false
            })
        end
        player_data[name].last_weekly = os.time()
    end

    save_player(name)
end

-------------------------------------------------------
-- ✅ Progress Updater
-------------------------------------------------------
local function update_quest_progress(name, quest_type, amount)
    load_player(name)
    reset_quests(name)
    local pdata = player_data[name]

    local function update(list)
        for _, q in ipairs(list) do
            if q.type == quest_type and not q.done then
                q.progress = (q.progress or 0) + amount
                if q.progress >= (q.target or 0) then
                    q.done = true
                end
            end
        end
    end

    update(pdata.daily)
    update(pdata.weekly)
    save_player(name)
end

-------------------------------------------------------
-- ✅ Formspec UI
-------------------------------------------------------
local function show_quests_formspec(player)
    local name = player:get_player_name()
    load_player(name)
    reset_quests(name)
    local pdata = player_data[name]

    local fs = "size[8,9]"
    fs = fs .. "label[0,0;=== Daily Quests ===]"
    local y = 0.5
    for _, q in ipairs(pdata.daily) do
        local status = q.done and "✔ Done" or string.format("%d / %d", q.progress or 0, q.target or 0)
        fs = fs .. string.format("label[0,%f;%s: %s]", y, q.name or "Unknown", status)
        y = y + 0.5
    end

    fs = fs .. "label[0,5;=== Weekly Quests ===]"
    y = 5.5
    for _, q in ipairs(pdata.weekly) do
        local status = q.done and "✔ Done" or string.format("%d / %d", q.progress or 0, q.target or 0)
        fs = fs .. string.format("label[0,%f;%s: %s]", y, q.name or "Unknown", status)
        y = y + 0.5
    end

    minetest.show_formspec(name, "quest_system:main", fs)
end

-------------------------------------------------------
-- ✅ Chat Command
-------------------------------------------------------
minetest.register_chatcommand("quests", {
    description = "Show your quests",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then show_quests_formspec(player) end
        return true
    end
})

-------------------------------------------------------
-- ✅ Example Hooks
-------------------------------------------------------

-- Track wood collection
minetest.register_on_dignode(function(pos, oldnode, digger)
    if not digger or not digger:is_player() then return end
    if oldnode and oldnode.name == "default:wood" then
        update_quest_progress(digger:get_player_name(), "collect_wood", 1)
    end
end)

-- Track walking distance
local last_positions = {}

minetest.register_globalstep(function(dtime)
    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        local pos = player:get_pos()
        local last = last_positions[name]
        if last then
            local dx = pos.x - last.x
            local dz = pos.z - last.z
            local dist = math.sqrt(dx*dx + dz*dz)
            if dist > 0.1 then
                update_quest_progress(name, "travel", dist)
            end
        end
        last_positions[name] = {x=pos.x, y=pos.y, z=pos.z}
    end
end)
