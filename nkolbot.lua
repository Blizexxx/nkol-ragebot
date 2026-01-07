-- Original owner: Blizexxx / integrated chat system
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local MainEvent = ReplicatedStorage:FindFirstChild("MainEvent")

-- ==========================================
-- API DETECTION (Ensures commands work)
-- ==========================================
local api
for i = 1, 100 do
    api = getfenv().api or getgenv().api or _G.api
    if api and type(api) == "table" and api.teleport then break end
    task.wait(0.1)
end

-- ==========================================
-- CONFIG & VARIABLES
-- ==========================================
local config = getgenv().NKOL_RAGEBOT or {
    Owner = LocalPlayer.Name,
    Prefix = "?",
    SelectedWeapons = "LMG/Rifle",
    Emotes = {"floss","samba","twerk","twirl"}
}

local owner = config.Owner
local prefix = config.Prefix
local targets = {}
local whitelist = {}
local sentry_active = false
local followConnection

-- =========================
-- VOID FRAMEWORK
-- =========================
local framework = {
    elements = {},
    voidActive = false,
    originalCFrame = nil,
    lastSwitch = 0,
    currentVoidIndex = 1
}

local function getSafeOriginalCFrame(currentHRP)
    if currentHRP and currentHRP.Position.Y > -10000 then return currentHRP.CFrame end
    return CFrame.new(0, 150, 0)
end

local function generateDeepVoidPositions()
    local positions = {}
    local deepY = {-2000000, -5000000, -10000000}
    for i = 1, 20 do
        table.insert(positions, CFrame.new(math.random(-500000, 500000), deepY[math.random(1, #deepY)], math.random(-500000, 500000)))
    end
    return positions
end

local deepVoidPositions = generateDeepVoidPositions()
local evasionConn

local function stopDeepVoid()
    if evasionConn then evasionConn:Disconnect() evasionConn = nil end
    framework.voidActive = false
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and framework.originalCFrame then
        hrp.AssemblyLinearVelocity = Vector3.new()
        api:teleport(framework.originalCFrame)
    end
end

local function startDeepVoid()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    framework.originalCFrame = getSafeOriginalCFrame(hrp)
    framework.voidActive = true
    evasionConn = RunService.Heartbeat:Connect(function()
        local speed = framework.elements.speedSlider and framework.elements.speedSlider.Value or 0.05
        if tick() - framework.lastSwitch < speed then return end
        framework.currentVoidIndex = (framework.currentVoidIndex % #deepVoidPositions) + 1
        hrp.AssemblyLinearVelocity = Vector3.new()
        pcall(function() api:teleport(deepVoidPositions[framework.currentVoidIndex]) end)
        framework.lastSwitch = tick()
    end)
end

-- =========================
-- HELPER FUNCTIONS
-- =========================
local function send(msg)
    pcall(function()
        if api.chat then api:chat(msg) elseif api.Chat then api:Chat(msg) end
    end)
end

local function getplayer(txt)
    if not txt then return end
    txt = txt:lower()
    for _,p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():sub(1,#txt)==txt or p.DisplayName:lower():sub(1,#txt)==txt then return p end
    end
end

local function saveRB()
    return {
        targets = api:get_ui_object("ragebot_targets").Value or {},
        enabled = api:get_ui_object("ragebot_enabled").Value or false,
        flame = api:get_ui_object("ragebot_flame") and api:get_ui_object("ragebot_flame").Value or false
    }
end

local function restoreRB(s)
    if not s then return end
    pcall(function()
        api:get_ui_object("ragebot_targets"):SetValue(s.targets)
        api:set_ragebot(s.enabled)
        if api:get_ui_object("ragebot_flame") then api:get_ui_object("ragebot_flame"):SetValue(s.flame) end
    end)
end

-- =========================
-- COMMANDS
-- =========================
local commands = {}

-- SUMMON / TP
commands.s = function()
    local ownerPlr = getplayer(owner)
    if ownerPlr and ownerPlr.Character then
        local hrp = ownerPlr.Character:FindFirstChild("HumanoidRootPart")
        if hrp then api:teleport(hrp.CFrame) send("Summoned to " .. ownerPlr.DisplayName) end
    end
end

commands.tp = function(_, name)
    local t = getplayer(name)
    if t and t.Character then api:teleport(t.Character.HumanoidRootPart.CFrame) send("TP'd to "..t.DisplayName) end
end

-- KILL AURA (FIXED MAIN TAB)
commands.ka = function()
    api:set_killaura(true)
    local ka_toggle = api:get_ui_object("killaura_enabled") or api:get_ui_object("enabled")
    if ka_toggle then ka_toggle:SetValue(true) end
    send("KillAura Enabled (Main Tab)")
end

commands.unka = function()
    api:set_killaura(false)
    local ka_toggle = api:get_ui_object("killaura_enabled") or api:get_ui_object("enabled")
    if ka_toggle then ka_toggle:SetValue(false) end
    send("KillAura Disabled")
end

commands.karange = function(_, range)
    local r = tonumber(range) or 10
    api:set_killaura_range(r)
    local slider = api:get_ui_object("killaura_range")
    if slider then slider:SetValue(r) end
    send("KA Range: "..r)
end

-- RAGEBOT COMMANDS
commands.a = function(_, ...)
    for _,n in pairs({...}) do
        local plr = getplayer(n)
        if plr then targets[plr.Name] = true send("Autoing "..plr.DisplayName) end
    end
    api:get_ui_object("ragebot_targets"):SetValue(targets)
    api:set_ragebot(true)
end

commands.kill = function(_, name)
    local t = getplayer(name)
    if not t then return end
    local saved = saveRB()
    api:get_ui_object("ragebot_targets"):SetValue({[t.Name]=true})
    api:set_ragebot(true)
    send("Killing "..t.DisplayName)
    task.spawn(function()
        repeat task.wait(0.2) until api:get_status_cache(t)["K.O"]
        api:set_ragebot(false)
        api:teleport(t.Character.HumanoidRootPart.CFrame * CFrame.new(0,4,0))
        for i=1,5 do MainEvent:FireServer("Stomp") task.wait(0.1) end
        restoreRB(saved)
    end)
end

commands.reset = function()
    targets = {}
    api:get_ui_object("ragebot_targets"):SetValue({})
    api:set_ragebot(false)
    send("Ragebot cleared")
end

-- UTILITY
commands.f = function(_, arg)
    if arg == "off" then if followConnection then followConnection:Disconnect() end send("Follow off") return end
    local ownerPlr = getplayer(owner)
    followConnection = RunService.Heartbeat:Connect(function()
        pcall(function() LocalPlayer.Character.HumanoidRootPart.CFrame = ownerPlr.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-5) end)
    end)
    send("Following "..ownerPlr.DisplayName)
end

commands.v = function(_, arg)
    local state = (arg ~= "off")
    if framework.elements.voidToggle then framework.elements.voidToggle:SetValue(state) end
    send("Void: "..(state and "ON" or "OFF"))
end

commands.whitelist = function(_, name)
    local plr = getplayer(name)
    if plr then whitelist[plr.Name]=true send(plr.DisplayName.." whitelisted") end
end

commands.unwhitelist = function(_, name)
    local plr = getplayer(name)
    if plr then whitelist[plr.Name]=nil send(plr.DisplayName.." removed") end
end

commands.leave = function() LocalPlayer:Kick("Bot Disconnected") end
commands.fix = function() LocalPlayer.Character.Humanoid.Health = 0 end

-- =========================
-- CHAT LISTENER
-- =========================
local function handleChat(msg)
    local low = msg:lower()
    local clean = low:gsub("%s+", "")
    
    if clean == "s" then commands.s() return end
    if clean == ".ka" or clean == ".aura" then commands.ka() return end
    if clean == ".unka" or clean == ".unaura" then commands.unka() return end

    if low:sub(1, #prefix) == prefix then
        local args = string.split(low:sub(#prefix+1), " ")
        local cmd = table.remove(args, 1)
        if commands[cmd] then commands[cmd](LocalPlayer, unpack(args)) end
    end
end

local function hook(p) if p.Name:lower() == owner:lower() then p.Chatted:Connect(handleChat) end end
for _, p in ipairs(Players:GetPlayers()) do hook(p) end
Players.PlayerAdded:Connect(hook)

-- =========================
-- UI SETUP
-- =========================
local tab = api:GetTab("commands") or api:AddTab("commands")
local main = tab:AddLeftGroupbox("Chat Bot")
main:AddLabel("s → Summon")
main:AddLabel(".ka / .unka → Aura")
main:AddLabel("?kill <name> → Kill")
main:AddLabel("?a <name> → Auto")
main:AddLabel("?v on/off → Void")

local vTab = api:AddTab("void")
local vGroup = vTab:AddLeftGroupbox("Better Void")
framework.elements.voidToggle = vGroup:AddToggle("v_toggle", {Text = "Enable Void", Callback = function(v) if v then startDeepVoid() else stopDeepVoid() end end})
framework.elements.speedSlider = vGroup:AddSlider("v_speed", {Text = "Switch Speed", Default = 0.05, Min = 0.01, Max = 0.2, Rounding = 2})

send("Bot Fully Loaded. All commands active.")
