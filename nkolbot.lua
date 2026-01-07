-- Original owner: Blizexxx / integrated chat system
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local MainEvent = ReplicatedStorage:FindFirstChild("MainEvent")

-- ==========================================
-- API DETECTION & WAIT (Fixes "Nothing works")
-- ==========================================
local api
for i = 1, 100 do
    api = getfenv().api or getgenv().api or _G.api
    if api and type(api) == "table" then break end
    task.wait(0.1)
end

if not api then
    warn("CRITICAL: API NOT FOUND. Ensure you are using the correct environment.")
    return
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
local whitelist = {}
local targets = {}

-- =========================
-- CORE FUNCTIONS
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
        if p.Name:lower():sub(1,#txt)==txt or p.DisplayName:lower():sub(1,#txt)==txt then
            return p
        end
    end
end

-- =========================
-- COMMAND LOGIC
-- =========================
local commands = {}

-- SUMMON
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

-- KILL AURA (.aura <range> and .unaura)
commands.aura = function(_, range)
    local r = tonumber(range) or 15
    
    -- Safety: Whitelist ignore
    if api.set_killaura_ignore then
        local names = {}
        for n, _ in pairs(whitelist) do table.insert(names, n) end
        api:set_killaura_ignore(names)
    end
    
    api:set_killaura_range(r)
    api:set_killaura(true)
    send("KillAura ENABLED | Range: " .. r)
end

commands.unaura = function()
    api:set_killaura(false)
    send("KillAura DISABLED")
end

-- WHITELIST
commands.whitelist = function(_, name)
    local plr = getplayer(name)
    if plr then 
        whitelist[plr.Name] = true 
        send(plr.DisplayName .. " whitelisted.")
    end
end

commands.unwhitelist = function(_, name)
    local plr = getplayer(name)
    if plr then 
        whitelist[plr.Name] = nil 
        send(plr.DisplayName .. " removed.")
    end
end

-- =========================
-- MASTER CHAT LISTENER
-- =========================
local function masterParser(msg)
    local lowMsg = msg:lower()
    local cleanMsg = lowMsg:gsub("%s+", "")
    
    -- Standalone "s"
    if cleanMsg == "s" then
        commands.s()
        return
    end

    -- .aura / .unaura
    if lowMsg:sub(1,1) == "." then
        local args = string.split(lowMsg:sub(2), " ")
        local cmd = table.remove(args, 1)
        if commands[cmd] then
            commands[cmd](LocalPlayer, unpack(args))
        end
        return
    end
    
    -- Prefix ?
    if lowMsg:sub(1, #prefix) == prefix then
        local args = string.split(lowMsg:sub(#prefix + 1), " ")
        local cmd = table.remove(args, 1)
        if commands[cmd] then
            commands[cmd](LocalPlayer, unpack(args))
        end
    end
end

-- Connection Logic
local function connectOwner(plr)
    if plr.Name == owner or plr.Name:lower() == owner:lower() then
        plr.Chatted:Connect(masterParser)
    end
end

for _, p in ipairs(Players:GetPlayers()) do connectOwner(p) end
Players.PlayerAdded:Connect(connectOwner)

-- Register commands for UI if they don't show up
pcall(function()
    for n, f in pairs(commands) do
        api:on_command(prefix..n, function(p, ...) if p.Name == owner then f(p, ...) end end)
    end
end)

send("Ragebot Ready. Commands: s, .aura, .unaura")
