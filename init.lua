local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
local api = dofile(modpath .. "/api.lua")

-- Load default quests file if present (pre-built)
local basic_path = modpath .. "/quests_basic.lua"
local custom_path = modpath .. "/quests.lua" -- if user placed this, load it
local template_path = modpath .. "/quests_template.lua"

-- Safe loader: prefer user custom file 'quests.lua' if present, otherwise load basic
local function safe_dofile(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        local ok, err = pcall(dofile, path)
        if not ok then
            minetest.log("error", "[quest_system] error loading " .. path .. ": " .. tostring(err))
        end
    end
end

-- Load quest template files
safe_dofile(custom_path)
if #api.daily_quests_template == 0 and #api.weekly_quests_template == 0 then
    safe_dofile(basic_path)
end
-- template file exists for reference only; do not auto-load it
-- safe_dofile(template_path)

local storage = minetest.get_mod_storage()
local player_data = {}     -- cache per-player
local player_dirty = {}    -- dirty flags for batched saving
local last_save_acc = 0

-- helpers
local function safe_deserialize(s)
    if not s or s == "" then return nil end
    local ok, res = pcall(minetest.deserialize, s)
    if ok and type(res) == "table" then return res end
    return nil
end

local function load_player(name)
    if player_data[name] then return end
    local raw = storage:get_string(name)
    local data = safe_deserialize(raw)
    if type(data) ~= "table" then
        data = {
            daily = {},
            weekly = {},
            last_daily = 0,
            last_weekly = 0
        }
    else
        -- ensure fields exist
        data.daily = data.daily or {}
        data.weekly = data.weekly or {}
        data.last_daily = data.last_daily or 0
        data.last_weekly = data.last_weekly or 0
    end
    player_data[name] = data
end

local function save_player(name)
    if not player_data[name] then return end
    local ok, err = pcall(function()
        storage:set_string(name, minetest.serialize(player_data[name]))
    end)
    if not ok then
        minetest.log("error", "[quest_system] failed to save player " .. name .. ": " .. tostring(err))
    end
    player_dirty[name] = nil
end

local function mark_dirty(name)
    player_dirty[name] = true
end

-- time helpers
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

-- reset quests for player when new day/week
local function reset_quests(name)
    load_player(name)
    local pdata = player_data[name]

    if is_new_day(pdata.last_daily) then
        pdata.daily = {}
        for _, q in ipairs(api.daily_quests_template) do
            table.insert(pdata.daily, {
                name = q.name,
                type = q.type,
                target = q.target,
                progress = 0,
                done = false,
                claimed = false,
                reward = q.reward
            })
        end
        pdata.last_daily = os.time()
    end

    if is_new_week(pdata.last_weekly) then
        pdata.weekly = {}
        for _, q in ipairs(api.weekly_quests_template) do
            table.insert(pdata.weekly, {
                name = q.name,
                type = q.type,
                target = q.target,
                progress = 0,
                done = false,
                claimed = false,
                reward = q.reward
            })
        end
        pdata.last_weekly = os.time()
    end

    mark_dirty(name)
end

-- update progress (does NOT immediately write to storage; uses dirty batching)
local function update_progress(name, qtype, amount)
    if not name or not qtype or not amount then return end
    load_player(name)
    reset_quests(name)
    local pdata = player_data[name]
    local changed = false

    local function apply(list)
        for _, q in ipairs(list) do
            if q.type == qtype and not q.done then
                q.progress = (q.progress or 0) + amount
                if q.progress >= (q.target or 0) then
                    q.done = true
                    q.progress = q.target or q.progress
                end
                changed = true
            end
        end
    end

    apply(pdata.daily)
    apply(pdata.weekly)

    if changed then
        mark_dirty(name)
    end
end

-- give reward and mark claimed
local function claim_reward(name, section, index)
    load_player(name)
    local pdata = player_data[name]
    if not pdata then return false, "no data" end
    local list = (section == "daily") and pdata.daily or pdata.weekly
    index = tonumber(index)
    if not list or not list[index] then return false, "invalid quest" end
    local q = list[index]
    if not q.done then return false, "not completed" end
    if q.claimed then return false, "already claimed" end
    if not q.reward or not q.reward.item then
        -- nothing to give, just mark claimed
        q.claimed = true
        mark_dirty(name)
        return true
    end

    local player = minetest.get_player_by_name(name)
    if not player then return false, "player offline" end
    local inv = player:get_inventory()
    if not inv then return false, "no inventory" end

    local itemstr = tostring(q.reward.item)
    local count = tonumber(q.reward.count) or 1
    local stack = itemstr .. " " .. tostring(count)
    local leftover = inv:add_item("main", stack)
    if not leftover or leftover:is_empty() then
        q.claimed = true
        mark_dirty(name)
        return true
    else
        -- if inventory can't hold, do not claim and notify
        return false, "inventory full"
    end
end

-- formspec builder
local function build_formspec(name)
    load_player(name)
    reset_quests(name)
    local pdata = player_data[name]

    local fs = "size[9,9]"  -- width 9
    fs = fs .. "box[0,0;9,0.8;#222222]" -- header background
    fs = fs .. "label[0.2,0.12;Quest Log]"
    -- close X (button_exit so it closes)
    fs = fs .. "button_exit[8.6,0.05;0.34,0.55;quit;X]"

    -- Daily header
    fs = fs .. "label[0,0.9;Daily Quests]"
    fs = fs .. "tablecolumns[color;text;width=4;text;width=2;text;width=2;text]" -- not required but nice
    local y = 1.25
    for i, q in ipairs(pdata.daily or {}) do
        local status = q.done and (q.claimed and "Claimed" or "Done") or string.format("%d/%d", math.floor(q.progress or 0), q.target or 0)
        local reward_str = (q.reward and q.reward.item) and (q.reward.item .. " x" .. (q.reward.count or 1)) or "-"
        fs = fs .. string.format("label[0.2,%f;%s]", y, q.name or "Unnamed")
        fs = fs .. string.format("label[4.5,%f;%s]", y, status)
        fs = fs .. string.format("label[6.4,%f;%s]", y, reward_str)
        if q.done and not q.claimed then
            fs = fs .. string.format("button[8.1,%f;0.8,0.5;claim_daily_%d;Claim]", y - 0.12, i)
        else
            -- empty space (no button) to keep alignment
            fs = fs .. string.format("label[8.1,%f; ]", y)
        end
        y = y + 0.6
        if y > 4.8 then break end -- don't overflow the area
    end

    -- Weekly header
    fs = fs .. "label[0,4.9;Weekly Quests]"
    y = 5.25
    for i, q in ipairs(pdata.weekly or {}) do
        local status = q.done and (q.claimed and "Claimed" or "Done") or string.format("%d/%d", math.floor(q.progress or 0), q.target or 0)
        local reward_str = (q.reward and q.reward.item) and (q.reward.item .. " x" .. (q.reward.count or 1)) or "-"
        fs = fs .. string.format("label[0.2,%f;%s]", y, q.name or "Unnamed")
        fs = fs .. string.format("label[4.5,%f;%s]", y, status)
        fs = fs .. string.format("label[6.4,%f;%s]", y, reward_str)
        if q.done and not q.claimed then
            fs = fs .. string.format("button[8.1,%f;0.8,0.5;claim_weekly_%d;Claim]", y - 0.12, i)
        else
            fs = fs .. string.format("label[8.1,%f; ]", y)
        end
        y = y + 0.6
        if y > 8.5 then break end
    end

    return fs
end

-- receive fields (handles claim buttons)
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "quest_system:main" then return end
    local name = player:get_player_name()
    for field, _ in pairs(fields) do
        local s, sec, idx = string.match(field, "^claim_(%a+)_(%d+)$")
        if s and sec and idx then
            local ok, msg = claim_reward(name, sec, tonumber(idx))
            if ok then
                minetest.chat_send_player(name, "Reward claimed.")
            else
                minetest.chat_send_player(name, "Claim failed: " .. tostring(msg))
            end
        end
    end
    minetest.show_formspec(name, "quest_system:main", build_formspec(name))
end)

-- /quests command to open UI
minetest.register_chatcommand("quests", {
    description = "Open quest log",
    func = function(name)
        load_player(name)
        reset_quests(name)
        minetest.show_formspec(name, "quest_system:main", build_formspec(name))
        return true
    end
})

-- Event hooks for quest types
-- collect_wood: digging default:wood
minetest.register_on_dignode(function(pos, oldnode, digger)
    if not (digger and digger:is_player() and oldnode and oldnode.name) then return end
    if oldnode.name == "default:wood" then
        update_progress(digger:get_player_name(), "collect_wood", 1)
    end
end)

-- travel: measure horizontal distance; batch updates and reduce frequency to reduce lag
local player_last_pos = {}
local player_travel_acc = {}
local travel_acc_interval = 1.0 -- seconds between travel checks
local travel_timer = 0

minetest.register_globalstep(function(dtime)
    -- batched saving timer
    last_save_acc = last_save_acc + dtime
    if last_save_acc >= 10.0 then
        -- save all dirty players
        for pname, _ in pairs(player_dirty) do
            save_player(pname)
        end
        last_save_acc = 0
    end

    -- travel update
    travel_timer = travel_timer + dtime
    if travel_timer < travel_acc_interval then return end
    travel_timer = 0

    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        local pos = player:get_pos()
        if pos then
            local last = player_last_pos[name]
            if last then
                local dx = pos.x - last.x
                local dz = pos.z - last.z
                local dist = math.sqrt(dx*dx + dz*dz)
                if dist > 0.15 then
                    player_travel_acc[name] = (player_travel_acc[name] or 0) + dist
                    -- only update quest progress when accumulated travel >= 1 to avoid excessive ops
                    if player_travel_acc[name] >= 1 then
                        update_progress(name, "travel", math.floor(player_travel_acc[name]))
                        player_travel_acc[name] = 0
                    end
                end
            end
            player_last_pos[name] = pos
        end
    end
end)

-- ensure players get reset/quests when they join
minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    load_player(name)
    reset_quests(name)
    -- do not force-save immediately; batched saving will handle it
end)

-- ensure mod storage saved on shutdown for dirty players
minetest.register_on_shutdown(function()
    for pname, _ in pairs(player_dirty) do
        save_player(pname)
    end
end)
