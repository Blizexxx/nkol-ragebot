-- Original owner: Blizexxx / integrated chat system
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local MainEvent = ReplicatedStorage:FindFirstChild("MainEvent")
local api = getfenv().api or getgenv().api or {}

-- ==========================================
-- BETTER VOID FRAMEWORK (PROTCHY INTEGRATION)
-- ==========================================
local framework = {
    connections = {},
    elements = {},
    voidActive = false,
    originalCFrame = nil,
    lastSwitch = 0,
    currentVoidIndex = 1,
    isTeleporting = false,
    isReturning = false,
    forceReturnCFrame = nil
}

local function find_first_child(obj, name) return obj and obj:FindFirstChild(name) end

local function is_cframe_in_void(cf)
    if not cf then return true end
    local pos = cf.Position
    return pos.Y < -10000 or math.abs(pos.X) > 500000 or math.abs(pos.Z) > 500000
end

local function getSafeOriginalCFrame(currentHRP)
    if currentHRP and not is_cframe_in_void(currentHRP.CFrame) then return currentHRP.CFrame end
    return CFrame.new(0, 150, 0)
end

local function generateDeepVoidPositions()
    local positions = {}
    local deepY = {-2000000, -5000000, -10000000, -20000000, -50000000}
    local farCoords = {-1000000, -500000, -250000, -100000, 100000, 250000, 500000, 1000000}
    for i = 1, 25 do
        table.insert(positions, CFrame.new(
            farCoords[math.random(1, #farCoords)] + math.random(-10000, 10000),
            deepY[math.random(1, #deepY)] + math.random(-10000, 10000),
            farCoords[math.random(1, #farCoords)] + math.random(-10000, 10000)
        ))
    end
    return positions
end

local deepVoidPositions = generateDeepVoidPositions()
local evasionConn

local function stopDeepVoid()
    if framework.isReturning then return end
    framework.isReturning = true
    if evasionConn then evasionConn:Disconnect() evasionConn = nil end
    framework.voidActive = false
    local char = LocalPlayer.Character
    local hrp = char and find_first_child(char, "HumanoidRootPart")
    if hrp and (framework.originalCFrame or framework.forceReturnCFrame) then
        local dest = framework.forceReturnCFrame or framework.originalCFrame
        hrp.AssemblyLinearVelocity = Vector3.new()
        api:teleport(dest)
        framework.originalCFrame = nil
        framework.forceReturnCFrame = nil
    end
    framework.isReturning = false
end

local function startDeepVoid()
    local char = LocalPlayer.Character
    local hrp = char and find_first_child(char, "HumanoidRootPart")
    if not hrp then return end
    if not framework.originalCFrame then framework.originalCFrame = getSafeOriginalCFrame(hrp) end
    framework.voidActive = true
    evasionConn = RunService.Heartbeat:Connect(function()
        if not (framework.elements.voidToggle and framework.elements.voidToggle.Value) then
            stopDeepVoid()
            return
        end
        local speed = framework.elements.speedSlider and framework.elements.speedSlider.Value or 0.05
        if tick() - framework.lastSwitch < speed then return end
        framework.currentVoidIndex = (framework.currentVoidIndex % #deepVoidPositions) + 1
        local target = deepVoidPositions[framework.currentVoidIndex]
        hrp.AssemblyLinearVelocity = Vector3.new()
        pcall(function() api:teleport(target) end)
        framework.lastSwitch = tick()
    end)
end

-- ==========================================
-- CONFIG & ORIGINAL VARIABLES
-- ==========================================
local config = getgenv().NKOL_RAGEBOT or {
    Owner = LocalPlayer.Name,
    Prefix = "?",
    SelectedWeapons = "LMG/Rifle",
    Emotes = {"floss","samba","twerk","twirl"}
}

local owner = config.Owner
local prefix = config.Prefix

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

-- SUMMON COMMAND (Teleport to owner)
commands.s = function()
    local ownerPlr = getplayer(owner)
    if ownerPlr and ownerPlr.Character then
        local hrp = ownerPlr.Character:FindFirstChild("HumanoidRootPart")
        local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp and myHrp then
            myHrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            api:teleport(hrp.CFrame)
            send("Summoned to " .. ownerPlr.DisplayName)
        end
    end
end

-- AURA COMMANDS
commands.aura = function(_, range)
    local r = tonumber(range) or 15
    api:set_killaura_range(r)
    api:set_killaura(true)
    send("KillAura Enabled | Range: " .. r)
end

commands.unaura = function()
    api:set_killaura(false)
    send("KillAura Disabled")
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

commands.fp = function(_,arg)
    api:set_fake(arg ~= "off")
    send("Fake position "..(arg ~= "off" and "enabled" or "disabled"))
end

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

commands.tp = function(_,name)
    local t = getplayer(name)
    if t and t.Character then
        api:teleport(t.Character.HumanoidRootPart.CFrame)
        send("Teleported to "..t.DisplayName)
    end
end

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

commands.protect = function(_, name)
    local plr = getplayer(name)
    if plr then 
        whitelist[plr.Name] = true
        send("Now protecting " .. plr.DisplayName)
    end
end

commands.unprotect = function(_, name)
    local plr = getplayer(name)
    if plr then 
        whitelist[plr.Name] = nil
        send("No longer protecting " .. plr.DisplayName)
    end
end

commands.whitelist = function(_, name)
    local plr = getplayer(name)
    if plr then whitelist[plr.Name]=true; send(plr.DisplayName.." added to whitelist") end
end

commands.unwhitelist = function(_, name)
    local plr = getplayer(name)
    if plr and whitelist[plr.Name] then whitelist[plr.Name]=nil; send(plr.DisplayName.." removed from whitelist") end
end

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
    end
end

commands.fix = function()
    send("Character reset!")
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.Health = 0
    else
        LocalPlayer:LoadCharacter()
    end
end

commands.v = function(_, arg)
    if framework.elements.voidToggle then
        local newState = (arg ~= "off")
        framework.elements.voidToggle:SetValue(newState)
        send("Better Void: " .. (newState and "ON" or "OFF"))
    else
        send("Void API not found.")
    end
end

commands.flame = function(_, targetName)
    if not targetName then send("Usage: ?flame <player>") return end
    local plr = getplayer(targetName)
    if not plr then send("Player not found: "..targetName) return end
    local saved = saveRB()
    local rb_targets = api:get_ui_object("ragebot_targets")
    if rb_targets then rb_targets:SetValue({[plr.Name] = true}) end
    local rb_flame = api:get_ui_object("ragebot_flame")
    if rb_flame then rb_flame:SetValue(true) end
    api:set_ragebot(true)
    send("Flame activated on "..plr.DisplayName)
    task.spawn(function()
        while plr.Parent and plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") do task.wait(0.5) end
        restoreRB(saved)
        send("Flame finished for "..plr.DisplayName)
    end)
end

for _,em in ipairs(config.Emotes) do
    commands[em] = function() api:emote(em); send("Emoting: "..em) end
end

commands.leave = function() send("Leaving game..."); LocalPlayer:Kick("Left the game") end

-- =========================
-- COUNTER-ATTACK LISTENER
-- =========================
api:on_event("player_got_shot", function(victim_name, attacker_name)
    if victim_name == LocalPlayer.Name or whitelist[victim_name] then
        local attacker = Players:FindFirstChild(attacker_name)
        if attacker and attacker ~= LocalPlayer and not whitelist[attacker_name] then
            targets[attacker_name] = true
            api:get_ui_object("ragebot_targets"):SetValue(targets)
            api:set_ragebot(true)
            send("Countering " .. attacker.DisplayName .. " for shooting a protected user!")
        end
    end
end)

-- =========================
-- REGISTRATION & LISTENER
-- =========================

-- Standard command registration
for n, f in pairs(commands) do
    pcall(function()
        api:on_command(prefix..n, function(p, ...) 
            if p.Name == owner then f(p, ...) end 
        end)
    end)
end

-- MASTER CHAT LISTENER (Supports .aura, s, and ?)
local function handleChatted(msg)
    local ownerPlr = Players:FindFirstChild(owner)
    if not ownerPlr then return end
    
    local lowerMsg = msg:lower()
    local cleanMsg = lowerMsg:gsub("%s+", "") -- Strip all spaces for standalone checks
    
    -- 1. Check for standalone "s"
    if cleanMsg == "s" then
        commands.s()
        return
    end

    -- 2. Check for "." prefix commands (aura / unaura)
    if lowerMsg:sub(1,1) == "." then
        local args = string.split(lowerMsg:sub(2), " ")
        local cmd = table.remove(args, 1)
        if commands[cmd] then
            commands[cmd](LocalPlayer, unpack(args))
        end
        return
    end

    -- 3. Check for standard prefix "?" commands
    if lowerMsg:sub(1, #prefix) == prefix then
        local args = string.split(lowerMsg:sub(#prefix + 1), " ")
        local cmd = table.remove(args, 1)
        if commands[cmd] then
            commands[cmd](LocalPlayer, unpack(args))
        end
    end
end

-- Initialize chat listeners
local currentOwner = Players:FindFirstChild(owner)
if currentOwner then currentOwner.Chatted:Connect(handleChatted) end

Players.PlayerAdded:Connect(function(plr)
    if plr.Name == owner then
        plr.Chatted:Connect(handleChatted)
    end
end)

-- Backup Utility Listener
pcall(function()
    local utility = getgenv().utility or _G.utility
    if utility and utility.on_event then
        utility.on_event("on_message", function(player, message)
            if player.Name == owner then handleChatted(message) end
        end)
    end
end)
