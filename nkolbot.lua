-- Original owner: Blizexxx / integrated chat system
-- Better Void Framework by Protchy
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local MainEvent = ReplicatedStorage:FindFirstChild("MainEvent")
local api = getfenv().api or {}

-- =========================
-- VOID FRAMEWORK CONSTANTS
-- =========================
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

-- =========================
-- VOID CORE FUNCTIONS
-- =========================
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
        local speed = framework.elements.speedSlider.Value
        if tick() - framework.lastSwitch < speed then return end

        framework.currentVoidIndex = (framework.currentVoidIndex % #deepVoidPositions) + 1
        local target = deepVoidPositions[framework.currentVoidIndex]
        
        hrp.AssemblyLinearVelocity = Vector3.new()
        pcall(function() api:teleport(target) end)
        framework.lastSwitch = tick()
    end)
end

-- =========================
-- UI SETUP (VOID TAB)
-- =========================
local deepVoidTab = api:AddTab("void")
local mainGroup = deepVoidTab:AddLeftGroupbox("better void")

framework.elements.voidToggle = mainGroup:AddToggle("true_void_enabled", {
    Text = "better void",
    Default = false,
    Callback = function(v) if v then startDeepVoid() else stopDeepVoid() end end
})

framework.elements.speedSlider = mainGroup:AddSlider("void_switch_speed", {
    Text = "switch speed", Default = 0.05, Min = 0.01, Max = 0.2, Rounding = 2
})

mainGroup:AddButton("emergency return", function()
    framework.forceReturnCFrame = CFrame.new(0, 200, 0)
    framework.elements.voidToggle:SetValue(false)
end)

-- =========================
-- CONFIG & COMMANDS
-- =========================
local config = getgenv().NKOL_RAGEBOT or {
    Owner = LocalPlayer.Name, Prefix = "?", SelectedWeapons = "LMG/Rifle", Emotes = {"floss","samba","twerk","twirl"}
}
local owner = config.Owner
local prefix = config.Prefix
local followConnection
local targets = {}
local whitelist = {}
local sentry_active = false

local function send(msg)
    pcall(function() if api and api.chat then api:chat(msg) elseif api and api.Chat then api:Chat(msg) end end)
end

local function getFormattedName(player) return string.format("%s (@%s)", player.DisplayName, player.Name) end

local function getplayer(txt)
    if not txt then return end
    txt = txt:lower()
    for _,p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():sub(1,#txt)==txt or p.DisplayName:lower():sub(1,#txt)==txt then return p end
    end
end

-- RAGEBOT SAVE/RESTORE
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
    if rb_targets then rb_targets:SetValue(s.targets) end
    if rb_enabled then api:set_ragebot(s.enabled) end
end

local commands = {}

-- ?a Auto ragebot
commands.a = function(_, ...)
    for _,n in pairs({...}) do
        local plr = getplayer(n)
        if plr then targets[plr.Name] = true send("Autoing "..plr.DisplayName) end
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
    if arg == "off" then if followConnection then followConnection:Disconnect() end send("Follow disabled") return end
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
    if t and t.Character then api:teleport(t.Character.HumanoidRootPart.CFrame) send("Teleported to "..t.DisplayName) end
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

-- WHITELIST
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
        sentry_active=true; send("Sentry enabled")
        if protector_toggle then protector_toggle:SetValue(true) end
        local st = {}; st[getFormattedName(ownerPlr)]=true
        for name,_ in pairs(whitelist) do local p=Players:FindFirstChild(name) if p then st[getFormattedName(p)]=true end end
        if targets_obj then targets_obj:SetValue(st) end
    elseif arg == "off" then
        sentry_active=false; send("Sentry disabled")
        if protector_toggle then protector_toggle:SetValue(false) end
        if targets_obj then targets_obj:SetValue({}) end
    end
end

-- ?fix
commands.fix = function()
    send("Character reset!")
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.Health = 0
    else LocalPlayer:LoadCharacter() end
end

-- ?v BETTER VOID TOGGLE
commands.v = function()
    if framework.elements.voidToggle then
        local targetState = not framework.elements.voidToggle.Value
        framework.elements.voidToggle:SetValue(targetState)
        send("Better Void: " .. (targetState and "ON" or "OFF"))
    else
        send("Void Framework Error.")
    end
end

-- ?flame
commands.flame = function(_, targetName)
    local plr = getplayer(targetName)
    if not plr then return end
    local saved = saveRB()
    api:get_ui_object("ragebot_targets"):SetValue({[plr.Name] = true})
    api:get_ui_object("ragebot_flame"):SetValue(true)
    api:set_ragebot(true)
    send("Flaming "..plr.DisplayName)
    task.spawn(function()
        while plr.Parent and plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") do task.wait(0.5) end
        restoreRB(saved)
    end)
end

-- EMOTES
for _,em in ipairs(config.Emotes) do
    commands[em] = function() api:emote(em) send("Emoting: "..em) end
end

-- =========================
-- GUI: Commands Tab
-- =========================
local commandsTab = api:GetTab("commands") or api:AddTab("commands")
local cmdBox = commandsTab:AddLeftGroupbox("Chat Commands")
local list = {"?a","?kill","?b","?reset","?fp","?f","?tp","?sentry","?fix","?v (Void)","?flame"}
for _,v in pairs(list) do cmdBox:AddLabel(v) end

-- =========================
-- REGISTRATION
-- =========================
for n, f in pairs(commands) do
    pcall(function() api:on_command(prefix..n, function(p, ...) if p.Name == owner then f(p, ...) end end) end)
end

pcall(function()
    if utility and utility.on_event then
        utility.on_event("on_message", function(player, message)
            if player == owner and message:sub(1, #prefix) == prefix then
                local args = string.split(message:sub(#prefix + 1), " ")
                local cmd = table.remove(args, 1):lower()
                if commands[cmd] then commands[cmd](LocalPlayer, unpack(args)) end
            end
        end)
    end
end)

api:Notify("Integrated System Loaded.", 3)
