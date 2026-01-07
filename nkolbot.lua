-- Original owner: Blizexxx / integrated chat system
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local MainEvent = ReplicatedStorage:FindFirstChild("MainEvent")

-- Safety check for the API
local api = getgenv().api or _G.api
if not api then return end

-- CONFIG (Full original emote list)
local config = getgenv().NKOL_RAGEBOT or {
    Owner = LocalPlayer.Name,
    Prefix = "?",
    SelectedWeapons = "LMG/Rifle",
    Emotes = {"floss", "samba", "twerk", "twirl"}
}

local owner = config.Owner
local prefix = config.Prefix

-- State Variables
local followConnection
local targets = {}
local whitelist = {}
local sentry_active = false

-- CHAT SYSTEM
local function send(msg)
    pcall(function()
        if api and api.chat then api:chat(msg)
        elseif api and api.Chat then api:Chat(msg) end
    end)
end

local function getFormattedName(player)
    return string.format("%s (@%s)", player.DisplayName, player.Name)
end

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
    local rb_targets = api:get_ui_object("ragebot_targets")
    local rb_enabled = api:get_ui_object("ragebot_enabled")
    local rb_flame = api:get_ui_object("ragebot_flame")
    return {
        targets = rb_targets and rb_targets.Value or {},
        enabled = rb_enabled and rb_enabled.Value or false,
        flame = rb_flame and rb_flame.Value or false
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
-- COMMANDS (Nothing Removed)
-- =========================
local commands = {}

-- ?a Auto ragebot
commands.a = function(_, ...)
    for _,n in pairs({...}) do
        local plr = getplayer(n)
        if plr then
            targets[plr.Name] = true
            send("Autoing "..plr.DisplayName)
        end
    end
    local obj = api:get_ui_object("ragebot_targets")
    if obj then obj:SetValue(targets) end
    api:set_ragebot(true)
end

-- ?reset
commands.reset = function()
    targets = {}
    local obj = api:get_ui_object("ragebot_targets")
    if obj then obj:SetValue({}) end
    api:set_ragebot(false)
    send("Ragebot cleared")
end

-- ?fp fake position
commands.fp = function(_,arg)
    api:set_fake(arg ~= "off")
    send("Fake position "..(arg ~= "off" and "enabled" or "disabled"))
end

-- ?f follow owner
commands.f = function(_,arg)
    if arg == "off" then
        if followConnection then followConnection:Disconnect() end
        send("Follow disabled")
        return
    end
    local ownerPlr = getplayer(owner)
    if not ownerPlr or not ownerPlr.Character then return end
    followConnection = RunService.Heartbeat:Connect(function()
        local hrp = ownerPlr.Character:FindFirstChild("HumanoidRootPart")
        local me = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp and me then me.CFrame = hrp.CFrame * CFrame.new(0,0,-5) end
    end)
    send("Following "..ownerPlr.DisplayName)
end

-- ?tp
commands.tp = function(_,name)
    local t = getplayer(name)
    if t and t.Character then
        api:teleport(t.Character.HumanoidRootPart.CFrame)
        send("Teleported to "..t.DisplayName)
    end
end

-- ?b bring
commands.b = function(_,name)
    local t = getplayer(name)
    if not t then return end
    local saved = saveRB()
    local obj = api:get_ui_object("ragebot_targets")
    if obj then obj:SetValue({[t.Name]=true}) end
    api:set_ragebot(true)
    send("Bringing "..t.DisplayName)
    task.spawn(function()
        repeat task.wait(.15) until api:get_status_cache(t)["K.O"]
        api:set_ragebot(false)
        api:teleport(t.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-2))
        restoreRB(saved)
        send("Finished bringing "..t.DisplayName)
    end)
end

-- ?kill
commands.kill = function(_,name)
    local t = getplayer(name)
    if not t or not MainEvent then return end
    local saved = saveRB()
    local obj = api:get_ui_object("ragebot_targets")
    if obj then obj:SetValue({[t.Name]=true}) end
    api:set_ragebot(true)
    send("Killing "..t.DisplayName)
    task.spawn(function()
        repeat task.wait(.15) until api:get_status_cache(t)["K.O"]
        api:set_ragebot(false)
        api:teleport(t.Character.HumanoidRootPart.CFrame * CFrame.new(0,4.5,0))
        for i=1,6 do MainEvent:FireServer("Stomp") task.wait(.05) end
        restoreRB(saved)
        send("Killed "..t.DisplayName)
    end)
end

-- Whitelist logic
commands.whitelist = function(_, name)
    local plr = getplayer(name)
    if plr then whitelist[plr.Name]=true; send(plr.DisplayName.." added to whitelist") end
end
commands.unwhitelist = function(_, name)
    local plr = getplayer(name)
    if plr and whitelist[plr.Name] then whitelist[plr.Name]=nil; send(plr.DisplayName.." removed from whitelist") end
end

-- ?sentry
commands.sentry = function(_, arg)
    if not arg then send("Usage: ?sentry on | off") return end
    arg = arg:lower()
    local ownerPlr = getplayer(owner)
    if not ownerPlr then return end
    local targets_obj = api:get_ui_object("protector_targets")
    local protector_toggle = api:get_ui_object("protector_active")
    if arg == "on" then
        sentry_active=true; send("Sentry enabled: Protecting "..ownerPlr.DisplayName)
        if protector_toggle then protector_toggle:SetValue(true) end
        local sentry_targets = {}; sentry_targets[getFormattedName(ownerPlr)]=true
        for name,_ in pairs(whitelist) do local p=Players:FindFirstChild(name); if p then sentry_targets[getFormattedName(p)]=true end end
        if targets_obj then targets_obj:SetValue(sentry_targets) end
    elseif arg == "off" then
        sentry_active=false; send("Sentry disabled")
        if protector_toggle then protector_toggle:SetValue(false) end
        if targets_obj then targets_obj:SetValue({}) end
        restoreRB(saveRB())
    end
end

-- ?ka / ?karange
commands.ka = function() api:set_killaura(true); send("KillAura enabled") end
commands.karange = function(_, range) api:set_killaura_range(tonumber(range) or 10); send("KillAura range set to "..(range or 10)) end

-- ?v (Void) Fixed for your UI path
commands.v = function(_, arg)
    local void_toggle = api:get_ui_object("character_void_enabled")
    if void_toggle then
        local state = (arg ~= "off")
        void_toggle:SetValue(state)
        send("Void bot "..(state and "enabled" or "disabled"))
    else send("Void toggle not found.") end
end

-- ?flame
commands.flame = function(_, targetName)
    if not targetName then send("Usage: ?flame <player>") return end
    local plr = getplayer(targetName)
    if not plr then send("Player not found") return end
    local saved = saveRB()
    api:get_ui_object("ragebot_targets"):SetValue({[plr.Name] = true})
    api:get_ui_object("ragebot_flame"):SetValue(true)
    api:set_ragebot(true)
    send("Flame activated on "..plr.DisplayName)
    task.spawn(function()
        while plr.Parent and plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") do task.wait(0.5) end
        restoreRB(saved)
        send("Flame finished")
    end)
end

-- ?fix
commands.fix = function()
    send("Character reset!")
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.Health = 0
    else LocalPlayer:LoadCharacter() end
end

-- EMOTES (Integrated)
for _, em in ipairs(config.Emotes) do
    commands[em] = function()
        if api and api.emote then api:emote(em) else MainEvent:FireServer("PlayEmote", em) end
        send("Emoting: " .. em)
    end
end

commands.leave = function() send("Leaving..."); LocalPlayer:Kick("Left") end

-- =========================
-- GUI & REGISTRATION
-- =========================
local commandsTab = api:GetTab("commands") or api:AddTab("commands")
local cmdBox = commandsTab:AddLeftGroupbox("Chat Commands")
local label_list = {"a","kill","b","reset","fp","f","tp","whitelist","sentry","ka","karange","fix","v","flame","leave"}
for _, l in ipairs(label_list) do cmdBox:AddLabel("?"..l) end
for _, em in ipairs(config.Emotes) do cmdBox:AddLabel("?"..em) end

-- Register Commands
for n, f in pairs(commands) do
    pcall(function()
        api:on_command(prefix..n, function(p, ...) if p.Name == owner then f(p, ...) end end)
    end)
end

-- Message Event fix
pcall(function()
    local util = getgenv().utility or _G.utility
    if util and util.on_event then
        util.on_event("on_message", function(player, message)
            if player.Name == owner and message:sub(1, #prefix) == prefix then
                local args = string.split(message:sub(#prefix + 1), " ")
                local cmd = table.remove(args, 1):lower()
                if commands[cmd] then commands[cmd](LocalPlayer, unpack(args)) end
            end
        end)
    end
end)
