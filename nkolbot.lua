-- Original owner: Blizexxx / Integrated with Utility API
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local MainEvent = ReplicatedStorage:FindFirstChild("MainEvent")

-- CONFIG
local config = getgenv().NKOL_RAGEBOT or {
    Owner = LocalPlayer.Name,
    Prefix = "?",
    SelectedWeapons = "LMG/Rifle",
    Emotes = {"floss","samba","twerk","twirl"}
}

local owner = config.Owner
local prefix = config.Prefix

-- State Management
local followConnection
local targets = {}
local whitelist = {}
local sentry_active = false

-- CHAT SYSTEM
local function send(msg)
    pcall(function()
        if api and api.chat then
            api:chat(msg)
        elseif api and api.Chat then
            api:Chat(msg)
        end
    end)
end

-- PLAYER FINDER
local function getplayer(txt)
    if not txt then return end
    txt = txt:lower()
    for _,p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():sub(1,#txt)==txt or p.DisplayName:lower():sub(1,#txt)==txt then
            return p
        end
    end
end

-- RAGEBOT SAVE / RESTORE
local function saveRB()
    return {
        targets = api:get_ui_object("ragebot_targets").Value or {},
        enabled = api:get_ui_object("ragebot_enabled").Value or false,
        flame = api:get_ui_object("ragebot_flame") and api:get_ui_object("ragebot_flame").Value or false
    }
end

local function restoreRB(s)
    if not s then return end
    local rb_targets = api:get_ui_object("ragebot_targets")
    local rb_enabled = api:get_ui_object("ragebot_enabled")
    local rb_flame = api:get_ui_object("ragebot_flame")
    if rb_targets then rb_targets:SetValue(s.targets) end
    if rb_enabled then api:set_ragebot(s.enabled) end
    if rb_flame then rb_flame:SetValue(s.flame) end
end

-- =========================
-- COMMANDS
-- =========================
local commands = {}

-- ?fix resets character
commands.fix = function()
    send("Resetting character...")
    -- Method 1: API Custom Reset
    if api and api.reset_character then
        api:reset_character()
    -- Method 2: Standard Humanoid Health (Most reliable for ?fix)
    elseif LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.Health = 0
    -- Method 3: Forced Respawn
    else
        LocalPlayer:LoadCharacter()
    end
end

commands.a = function(_, ...)
    for _,n in pairs({...}) do
        local plr = getplayer(n)
        if plr then
            targets[plr.Name] = true
            send("Autoing "..plr.DisplayName)
        end
    end
    api:get_ui_object("ragebot_targets"):SetValue(targets)
    api:set_ragebot(true)
end

commands.reset = function()
    targets = {}
    api:get_ui_object("ragebot_targets"):SetValue({})
    api:set_ragebot(false)
    send("Ragebot cleared")
end

commands.tp = function(_,name)
    local t = getplayer(name)
    if t and t.Character then
        api:teleport(t.Character.HumanoidRootPart.CFrame)
        send("Teleported to "..t.DisplayName)
    end
end

-- EMOTES
for _,em in ipairs(config.Emotes) do
    commands[em] = function() api:emote(em); send("Emoting: "..em) end
end

-- =========================
-- REGISTER & EVENT LISTENER
-- =========================

-- This listens for messages via the Utility API "on_event" system
utility.on_event("on_message", function(player, message)
    -- Check if sender is the owner
    if player.Name ~= owner then return end

    -- Check for prefix
    if message:sub(1, #prefix) == prefix then
        local full_content = message:sub(#prefix + 1)
        local args = string.split(full_content, " ")
        local command_name = table.remove(args, 1):lower()

        local func = commands[command_name]
        if func then
            -- Run the command function
            local success, err = pcall(function()
                func(player, unpack(args))
            end)
            if not success then
                warn("Command Error: " .. tostring(err))
            end
        end
    end
end)

utility.notify("Script Loaded. Prefix: " .. prefix)
