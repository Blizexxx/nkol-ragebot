-- Original owner: Blizexxx / integrated chat system
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

-- Follow / ragebot / sentry
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

local function getFormattedName(player)
    return string.format("%s (@%s)", player.DisplayName, player.Name)
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

-- =========================
-- ?b Bring (updated)
-- =========================
commands.b = function(_, name)
    local target = getplayer(name)
    if not target then
        send("Player not found: "..(name or "nil"))
        return
    end

    local saved = saveRB()
    local rb_targets = api:get_ui_object("ragebot_targets")
    if rb_targets then rb_targets:SetValue({[target.Name]=true}) end
    api:set_ragebot(true)
    send("Bringing "..target.DisplayName.."...")

    local glue_connection
    task.spawn(function()
        local initial_char = target.Character
        -- Wait until target is KO
        repeat task.wait(0.15) until api:get_status_cache(target)["K.O"]

        -- Stop ragebot before gluing
        api:set_ragebot(false)
        if rb_targets then rb_targets:SetValue({}) end

        -- Glue your character above target
        glue_connection = RunService.Heartbeat:Connect(function()
            if not target.Character or not target.Character:FindFirstChild("UpperTorso") then return end
            if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return end
            local targetPos = target.Character.UpperTorso.Position
            LocalPlayer.Character.PrimaryPart.CFrame = CFrame.new(targetPos + Vector3.new(0, 4.5, 0))
        end)

        -- Wait 10 seconds while glued
        task.wait(10)
        if glue_connection then glue_connection:Disconnect() glue_connection = nil end

        -- Restore previous ragebot state
        restoreRB(saved)
        send("Finished bringing "..target.DisplayName)
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

-- WHITELIST / UNWHITELIST
commands.whitelist = function(_, name)
    local plr = getplayer(name)
    if plr then whitelist[plr.Name]=true; send(plr.DisplayName.." added to whitelist") end
end
commands.unwhitelist = function(_, name)
    local plr = getplayer(name)
    if plr and whitelist[plr.Name] then whitelist[plr.Name]=nil; send(plr.DisplayName.." removed from whitelist") end
end

-- SENTRY
commands.sentry = function(_, arg)
    if not arg then send("Usage: ?sentry on | off") return end
    arg = arg:lower()
    local ownerPlr = getplayer(owner)
    if not ownerPlr then return end
    local targets_obj = api:get_ui_object("protector_targets")
    local protector_toggle = api:get_ui_object("protector_active")
    if arg == "on" then
        if sentry_active then send("Sentry already active") return end
        sentry_active=true; send("Sentry enabled: Protecting "..ownerPlr.DisplayName)
        if protector_toggle then protector_toggle:SetValue(true) end
        local sentry_targets = {}; sentry_targets[getFormattedName(ownerPlr)]=true
        for name,_ in pairs(whitelist) do local p=Players:FindFirstChild(name); if p then sentry_targets[getFormattedName(p)]=true end end
        if targets_obj then targets_obj:SetValue(sentry_targets) end
    elseif arg == "off" then
        if not sentry_active then send("Sentry already inactive") return end
        sentry_active=false; send("Sentry disabled")
        if protector_toggle then protector_toggle:SetValue(false) end
        if targets_obj then targets_obj:SetValue({}) end
        restoreRB(saveRB())
    else send("Usage: ?sentry on | off") end
end

-- ?ka / ?karange
commands.ka = function() api:set_killaura(true); send("KillAura enabled") end
commands.karange = function(_, range) api:set_killaura_range(tonumber(range) or 10); send("KillAura range set to "..(range or 10)) end

-- ?fix resets character
commands.fix = function()
    if api and api.reset_character then
        api:reset_character()
    else
        LocalPlayer:LoadCharacter()
    end
    send("Character reset!")
end

-- ?v void bot
commands.v = function()
    if api and api.toggle_void then
        api.toggle_void()
        send("Better Void toggled!")
    else
        send("Void API not found.")
    end
end

-- ?flame <player>
commands.flame = function(_, targetName)
    if not targetName then 
        send("Usage: ?flame <player>")
        return
    end
    local plr = getplayer(targetName)
    if not plr then
        send("Player not found: "..targetName)
        return
    end

    local saved = saveRB()
    local rb_targets = api:get_ui_object("ragebot_targets")
    if rb_targets then rb_targets:SetValue({[plr.Name] = true}) end

    local rb_flame = api:get_ui_object("ragebot_flame")
    if rb_flame then rb_flame:SetValue(true) end

    api:set_ragebot(true)
    send("Flame activated on "..plr.DisplayName)

    task.spawn(function()
        while plr.Parent and plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") do
            task.wait(0.5)
        end
        restoreRB(saved)
        send("Flame finished for "..plr.DisplayName)
    end)
end

-- EMOTES
for _,em in ipairs(config.Emotes) do
    commands[em] = function() api:emote(em); send("Emoting: "..em) end
end

-- ?leave
commands.leave = function() send("Leaving game..."); LocalPlayer:Kick("Left the game") end

-- =========================
-- GUI: Commands Tab
-- =========================
local commandsTab = api:GetTab("commands") or api:AddTab("commands")
local cmdBox = commandsTab:AddLeftGroupbox("Chat Commands")
cmdBox:AddLabel("?a → Auto ragebot")
cmdBox:AddLabel("?kill → Kill target")
cmdBox:AddLabel("?b → Bring target")
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

-- =========================
-- REGISTER
-- =========================
for n,f in pairs(commands) do
    api:on_command(prefix..n,function(p,...) if p.Name==owner then f(p,...) end end)
end
