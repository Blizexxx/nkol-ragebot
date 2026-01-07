-- Original owner: Blizexxx / integrated chat system + Vexis Protector Addon
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
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

-- Follow / ragebot / sentry / protector
local followConnection
local targets = {}
local whitelist = {}
local sentry_active = false
local protected_users = {}
local active_threats = {}
local is_strafe_active = false
local stomp_connection = nil

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

-- ?a Auto ragebot
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

-- ?reset
commands.reset = function()
    targets = {}
    api:get_ui_object("ragebot_targets"):SetValue({})
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
    api:get_ui_object("ragebot_targets"):SetValue({[t.Name]=true})
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
    api:get_ui_object("ragebot_targets"):SetValue({[t.Name]=true})
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

-- ?protect / ?unprotect
commands.protect = function(_,name)
    local p = getplayer(name)
    if not p then return end
    protected_users[p.Name] = true
    send(p.DisplayName.." is now protected")
end

commands.unprotect = function(_,name)
    local p = getplayer(name)
    if not p then return end
    protected_users[p.Name] = nil
    send(p.DisplayName.." is no longer protected")
end

-- WHITELIST / UNWHITELIST
commands.whitelist = function(_, name)
    local plr = getplayer(name)
    if plr then whitelist[plr.Name]=true; send(plr.DisplayName.." added to whitelist") end
end
commands.unwhitelist = function(_, name)
    local plr = getplayer(name)
    if plr and whitelist[plr.Name] then whitelist[plr.Name]=nil; send(plr.DisplayName.." removed from whitelist") end
end

-- CHAT DAMAGE MONITOR: auto-ragebot if protected user shot
api:on_event("player_got_shot", function(victim_name, attacker_name, part, tool, origin, position)
    local victim = Players:FindFirstChild(victim_name)
    local attacker = Players:FindFirstChild(attacker_name)
    if victim and protected_users[victim.Name] and attacker and attacker ~= LocalPlayer then
        local saved = saveRB()
        api:get_ui_object("ragebot_targets"):SetValue({[attacker.Name]=true})
        api:set_ragebot(true)
        task.spawn(function()
            repeat task.wait(.15) until api:get_status_cache(attacker)["K.O"]
            api:set_ragebot(false)
            restoreRB(saved)
        end)
    end
end)

-- GUI: Commands Tab
local commandsTab = api:GetTab("commands") or api:AddTab("commands")
local cmdBox = commandsTab:AddLeftGroupbox("Chat Commands")
cmdBox:AddLabel("?a → Auto ragebot")
cmdBox:AddLabel("?kill → Kill target")
cmdBox:AddLabel("?b → Bring target")
cmdBox:AddLabel("?protect → Protect target")
cmdBox:AddLabel("?unprotect → Unprotect target")
cmdBox:AddLabel("?reset → Clear ragebot")
cmdBox:AddLabel("?fp / ?fp off → Fake position")
cmdBox:AddLabel("?f / ?f off → Follow owner")
cmdBox:AddLabel("?tp → Teleport")
cmdBox:AddLabel("?whitelist / ?unwhitelist → Sentry whitelist")
cmdBox:AddLabel("?sentry on / off → Protect owner + whitelist")
cmdBox:AddLabel("?ka → Enable KillAura")
cmdBox:AddLabel("?karange <number> → Set KillAura range")
cmdBox:AddLabel("?fix → Reset character")
cmdBox:AddLabel("?v → Void bot")
cmdBox:AddLabel("?flame <player> → Flame target")
cmdBox:AddLabel("?leave → Leave game")
for _,em in ipairs(config.Emotes) do cmdBox:AddLabel("?"..em.." → Emote "..em) end

-- REGISTER COMMANDS
for n,f in pairs(commands) do
    api:on_command(prefix..n, function(p,...)
        if p.Name == owner then f(p,...) end
    end)
end

api:notify("Ragebot + Protector Loaded", 3)
