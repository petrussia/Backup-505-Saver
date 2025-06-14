--[[
  OBS Studio Lua script : Control Animated Lower Thirds with hotkeys (auto‑defaults)
  Author: NoeAL + ChatGPT (2025‑06‑11)
  Modified: 2025-06-14 - Different Num-key combinations for each LT
  Version: 0.4.2 – uses unique Num-key combinations for each lower third
      • LT1: Ctrl+Num1-Num0
      • LT2: Alt+Num1-Num0
      • LT3: Shift+Num1-Num0
      • LT4: Ctrl+Alt+Num1-Num0
      • Never overwrites user‑defined keybinds
--]]

local obs = obslua
local debug
local custom_js_path = ""

-- internal state (unchanged)
local master_switch = 0
local switch = {0, 0, 0, 0}
local slot  = {
    {0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0},
}

local hk = {}

-- ########### DEFAULT KEY MAP ###########
-- modifiers per-overlay to avoid duplicates
local overlay_mods = {
    {ctrl=true,  alt=false, shift=false, command=false}, -- LT-1 Ctrl+Num
    {ctrl=false, alt=true,  shift=false, command=false}, -- LT-2 Alt+Num
    {ctrl=false, alt=false, shift=true,  command=false}, -- LT-3 Shift+Num
    {ctrl=true,  alt=true,  shift=false, command=false}, -- LT-4 Ctrl+Alt+Num
}

-- keys for master / overlay show-hide
local default_key = {
    ["A_SWITCH_0_main"] = {key="OBS_KEY_F24",ctrl=false,alt=false,shift=false,command=false},
    ["A_SWITCH_1"]      = {key="OBS_KEY_F20"},
    ["A_SWITCH_2"]      = {key="OBS_KEY_F21"},
    ["A_SWITCH_3"]      = {key="OBS_KEY_F22"},
    ["A_SWITCH_4"]      = {key="OBS_KEY_F23"},
}

-- numeric keypad keys (Num1-Num0) with different modifiers per LT
for lt = 1,4 do
    for s = 1,10 do
        local name = string.format("LT%d_SLT%02d", lt, s)
        local key_const = (s == 10) and "OBS_KEY_NUM0" or ("OBS_KEY_NUM" .. s)
        local mods = overlay_mods[lt]
        default_key[name] = {
            key = key_const,
            ctrl = mods.ctrl,
            alt = mods.alt,
            shift = mods.shift,
            command = mods.command,
        }
    end
end

-- ########### HELPERS ###########
local function log(fmt, ...)
    if debug then obs.script_log(obs.LOG_INFO, string.format(fmt, ...)) end
end

local function get_js_path()
    if custom_js_path ~= nil and custom_js_path ~= "" then return custom_js_path end
    return script_path() .. "../common/js/hotkeys.js"
end

local function update_hotkeys_js()
    local f, err = io.open(get_js_path(), "w")
    if not f then
        obs.script_log(obs.LOG_WARNING, "[LowerThirds] Can't write hotkeys.js: " .. (err or ""))
        return
    end
    f:write(string.format("hotkeyMasterSwitch = %d;\n", master_switch))
    for i = 1, 4 do f:write(string.format("hotkeySwitch%d = %d;\n", i, switch[i])) end
    for lt = 1, 4 do
        for s = 1, 10 do
            f:write(string.format("hotkeyAlt%dSlot%d = %d;\n", lt, s, slot[lt][s]))
        end
    end
    f:close()
end

-- state mutators (unchanged)
local function toggle_switch(idx) switch[idx] = 1 - switch[idx]; update_hotkeys_js() end
local function select_slot(lt_idx, slot_idx)
    for i = 1, 10 do slot[lt_idx][i] = (i == slot_idx) and 1 or 0 end
    update_hotkeys_js()
end
local function toggle_master() master_switch = 1 - master_switch; update_hotkeys_js() end

-- ########### HOTKEY DISPATCH ###########
local function onHotKey(action)
    if action == "A_SWITCH_0_main" then toggle_master(); return end
    local s_idx = action:match("^A_SWITCH_(%d)$")
    if s_idx then toggle_switch(tonumber(s_idx)); return end
    local lt, sl = action:match("^LT(%d)_SLT(%d%d)$")
    if lt then select_slot(tonumber(lt), tonumber(sl)); return end
    log("Unknown hotkey action: %s", action)
end

-- create default JSON for a binding
local function make_binding_json(name, def)
    return string.format('{ "%s": [ { "key": "%s", "control": %s, "alt": %s, "shift": %s, "command": %s } ] }',
        name, def.key,
        tostring(def.ctrl and true or false),
        tostring(def.alt and true or false),
        tostring(def.shift and true or false),
        tostring(def.command and true or false))
end

-- register + auto-assign
local function register_hotkeys(settings)
    local function reg(name, desc)
        hk[name] = obs.obs_hotkey_register_frontend(name, desc, function(pressed) if pressed then onHotKey(name) end end)
        local saved = obs.obs_data_get_array(settings, name)
        if obs.obs_data_array_count(saved) == 0 and default_key[name] then
            -- create default if empty
            local json = make_binding_json(name, default_key[name])
            local tmp = obs.obs_data_create_from_json(json)
            local def_arr = obs.obs_data_get_array(tmp, name)
            obs.obs_hotkey_load(hk[name], def_arr)
            obs.obs_data_array_release(def_arr)
            obs.obs_data_release(tmp)
            -- save so OBS remembers next time
            local save_arr = obs.obs_hotkey_save(hk[name])
            obs.obs_data_set_array(settings, name, save_arr)
            obs.obs_data_array_release(save_arr)
        else
            obs.obs_hotkey_load(hk[name], saved)
        end
        obs.obs_data_array_release(saved)
    end

    -- master + overlay switches
    reg("A_SWITCH_0_main", "Main Switch")
    for i = 1, 4 do reg(string.format("A_SWITCH_%d", i), string.format("Lower Third Switch #%d", i)) end

    -- slot binds
    for lt = 1, 4 do
        for s = 1, 10 do
            reg(string.format("LT%d_SLT%02d", lt, s), string.format("Load Slot %02d on LT #%d", s, lt))
        end
    end
end

-- ########### OBS CALLBACKS ###########
function script_load(settings)
    register_hotkeys(settings)
    update_hotkeys_js()
end

function script_unload() end

function script_update(settings)
    debug = obs.obs_data_get_bool(settings, "debug")
    custom_js_path = obs.obs_data_get_string(settings, "js_path")
end

function script_defaults(settings)
    obs.obs_data_set_default_bool(settings, "debug", false)
    obs.obs_data_set_default_string(settings, "js_path", "")
end

function script_description()
    return [[Control Animated Lower Thirds.
 • Automatic hotkey assignment on first run:
   - LT1: Ctrl+Num1-Num0
   - LT2: Alt+Num1-Num0
   - LT3: Shift+Num1-Num0
   - LT4: Ctrl+Alt+Num1-Num0
 • Preserves existing user keybinds
 • Bindings persist after OBS restart]]
end

function script_properties()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_bool(props, "debug", "Debug")
    obs.obs_properties_add_path(props, "js_path", "Custom hotkeys.js path", obs.OBS_PATH_FILE, "JS Files (*.js)", nil)
    return props
end

function script_save(settings)
    for name, _ in pairs(hk) do
        local arr = obs.obs_hotkey_save(hk[name])
        obs.obs_data_set_array(settings, name, arr)
        obs.obs_data_array_release(arr)
    end
end