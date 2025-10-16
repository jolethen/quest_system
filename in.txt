local modpath = minetest.get_modpath("quest_system")
local api = dofile(modpath .. "/api.lua")
dofile(modpath .. "/quests.lua")

local storage = minetest.get_mod_storage()
local player_data = {}

-------------------------------------------------------
-- Helpers
-------------------------------------------------------
local function load_player(name)
    if player_data[name] then return end
    local data = minetest.deserialize(storage:get_string(name))
    if type(data) ~= "table" then
        data = {daily = {}, weekly = {}, last_daily = 0, last_weekly = 0, rewards = {}}
    end
    player_data[name] = data
end

local function save_player(name)
    if player_data[name] then
        storage:set_string(name, minetest.serialize(player_data[name]))
    end
end

local function is_new_day(last_time)
    if not last_time or last_time == 0 then return true end
    local last = os.date("*t", last_time)
    local now = os.date("*t")
    return last.yday ~= now.yday or last.year ~= now.year
end

local function is_new_week(last_time)
    if not last_time or last_time == 0 then return true end
    local last_week = os.date("%U", last_time)
    local now_week = os.date("%U")
    local ly = os.date("*t", last_time).year
    local ny = os.date("*t").year
    return (last_week ~= now_week) or (ly ~= ny)
end

-------------------------------------------------------
-- Reset system
-------------------------------------------------------
local function reset_quests(name)
    load_player(name)

    local pdata = player_data[name]
    pdata.rewards = pdata.rewards or {}

    if is_new_day(pdata.last_daily) then
        pdata.daily = {}
        for _, q in ipairs(api.daily_quests_template) do
            table.insert(pdata.daily, {
                name=q.name, type=q.type, target=q.target,
                progress=0, done=false, claimed=false, reward=q.reward
            })
        end
        pdata.last_daily = os.time()
    end

    if is_new_week(pdata.last_weekly) then
        pdata.weekly = {}
        for _, q in ipairs(api.weekly_quests_template) do
            table.insert(pdata.weekly, {
                name=q.name, type=q.type, target=q.target,
                progress=0, done=false, claimed=false, reward=q.reward
            })
        end
        pdata.last_weekly = os.time()
    end

    save_player(name)
end

-------------------------------------------------------
-- Progress & Rewards
-------------------------------------------------------
local function update_progress(name, qtype, amount)
    load_player(name)
    reset_quests(name)
    local pdata = player_data[name]

    local function update(list)
        for _, q in ipairs(list) do
            if q.type == qtype and not q.done then
                q.progress = (q.progress or 0) + amount
                if q.progress >= q.target then
                    q.done = true
                end
            end
        end
    end

    update(pdata.daily)
    update(pdata.weekly)
    save_player(name)
end

local function claim_reward(name, section, index)
    local pdata = player_data[name]
    if not pdata or not pdata[section] or not pdata[section][index] then return end
    local q = pdata[section][index]
    if q.done and not q.claimed and q.reward then
        local player = minetest.get_player_by_name(name)
        if player and player:get_inventory() then
            player:get_inventory():add_item("main", q.reward.item .. " " .. q.reward.count)
            q.claimed = true
            save_player(name)
            minetest.chat_send_player(name, "✅ Claimed reward for quest: " .. q.name)
        end
    else
        minetest.chat_send_player(name, "❌ You haven't completed this quest yet.")
    end
end

-------------------------------------------------------
-- Formspec UI
-------------------------------------------------------
local function get_formspec(name)
    local pdata = player_data[name]
    local fs = "size[8,9]"
    fs = fs .. "label[0,0;=== Daily Quests ===]"
    local y = 0.5
    for i, q in ipairs(pdata.daily or {}) do
        local status = q.done and (q.claimed and "✔ Claimed" or "✅ Done!") or (q.progress .. "/" .. q.target)
        fs = fs .. string.format("label[0,%f;%s: %s]", y, q.name, status)
        if q.done and not q.claimed then
            fs = fs .. string.format("button[6,%f;2,0.5;claim_daily_%d;Claim]", y-0.1, i)
        end
        y = y + 0.6
    end

    fs = fs .. "label[0,5;=== Weekly Quests ===]"
    y = 5.5
    for i, q in ipairs(pdata.weekly or {}) do
        local status = q.done and (q.claimed and "✔ Claimed" or "✅ Done!") or (q.progress .. "/" .. q.target)
        fs = fs .. string.format("label[0,%f;%s: %s]", y, q.name, status)
        if q.done and not q.claimed then
            fs = fs .. string.format("button[6,%f;2,0.5;claim_weekly_%d;Claim]", y-0.1, i)
        end
        y = y + 0.6
    end
    return fs
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "quest_system:main" then return end
    local name = player:get_player_name()
    for field, _ in pairs(fields) do
        local s, section, idx = string.match(field, "claim_(%a+)_(%d+)")
        if s and section and idx then
            claim_reward(name, section, tonumber(idx))
        end
    end
    minetest.show_formspec(name, "quest_system:main", get_formspec(name))
end)

-------------------------------------------------------
-- Command
-------------------------------------------------------
minetest.register_chatcommand("quests", {
    description = "Show your quests",
    func = function(name)
        load_player(name)
        reset_quests(name)
        minetest.show_formspec(name, "quest_system:main", get_formspec(name))
    end
})

-------------------------------------------------------
-- Hooks
-------------------------------------------------------
minetest.register_on_dignode(function(pos, oldnode, digger)
    if digger and digger:is_player() and oldnode.name == "default:wood" then
        update_progress(digger:get_player_name(), "collect_wood", 1)
    end
end)

local last_pos = {}
minetest.register_globalstep(function()
    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        local pos = player:get_pos()
        local last = last_pos[name]
        if last then
            local dx, dz = pos.x - last.x, pos.z - last.z
            local dist = math.sqrt(dx*dx + dz*dz)
            if dist > 0.3 then
                update_progress(name, "travel", dist)
            end
        end
        last_pos[name] = pos
    end
end)
