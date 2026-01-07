-- Original owner: Blizexxx / integrated chat system
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local MainEvent = ReplicatedStorage:FindFirstChild("MainEvent")

-- FIX: Global safety check to prevent the 'on_event' nil error
local utility = utility or _G.utility

-- CONFIG
local config = getgenv().NKOL_RAGEBOT or {
    Owner = LocalPlayer.Name,
    Prefix = "?",
    SelectedWeapons = "LMG/Rifle",
    Emotes = {"floss","samba","twerk","twirl"}
}

local owner = config.Owner
local prefix = config.Prefix

-- Follow / ragebot / sentry variables
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

-- =========================
-- COMMANDS
-- =========================
local commands = {}

-- ?v - UPDATED FOR CHARACTER TAB VOID TOGGLE
commands.v = function()
    -- According to your screenshot, Void is in the 'character' tab
    local charTab = api:get_tab("character")
    local voidEnabled = nil

    if charTab then
        -- Attempt to find the 'enabled' toggle specifically within the character tab context
        voidEnabled = charTab:get_ui_object("void_enabled") or charTab:get_ui_object("enabled")
    end

    -- Fallback if tab-specific lookup fails
    if not voidEnabled then
        voidEnabled = api:get_ui_object("void_enabled") or api:get_ui_object("void_active")
    end
    
    if voidEnabled then
        local newState = not voidEnabled.Value
        voidEnabled:SetValue(newState)
        send("Void bot: " .. (newState and "ENABLED" or "DISABLED"))
    else
        send("Error: Could not find Void toggle in Character tab.")
    end
end

-- ?fix - Resets character
commands.fix = function()
    send("Resetting character...")
    if api and api.reset_character then
        api:reset_character()
    elseif LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.Health = 0
    end
end

-- ?a - Auto ragebot
commands.a = function(_, ...)
    for _,n in pairs({...}) do
        local plr = getplayer(n)
        if plr then
            targets[plr.Name] = true
            send("Autoing "..plr.DisplayName)
        end
    end
    local rb_obj = api:get_ui_object("ragebot_targets")
    if rb_obj then rb_obj:SetValue(targets) end
    api:set_ragebot(true)
end

-- ?reset - Clear ragebot
commands.reset = function()
    targets = {}
    local rb_obj = api:get_ui_object("ragebot_targets")
    if rb_obj then rb_obj:SetValue({}) end
    api:set_ragebot(false)
    send("Ragebot cleared")
end

-- ?f - Follow owner
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

-- ?tp - Teleport to player
commands.tp = function(_,name)
    local t = getplayer(name)
    if t and t.Character then
        api:teleport(t.Character.HumanoidRootPart.CFrame)
        send("Teleported to "..t.DisplayName)
    end
end

-- ?leave - Leave game
commands.leave = function() send("Leaving..."); LocalPlayer:Kick("User requested leave") end

-- EMOTES
for _,em in ipairs(config.Emotes) do
    commands[em] = function() api:emote(em); send("Emoting: "..em) end
end

-- =========================
-- GUI: Commands Tab
-- =========================
local commandsTab = api:get_tab("commands") or api:add_tab("commands")
local cmdBox = commandsTab:add_left_groupbox("Chat Commands")
cmdBox:add_label("?v → Toggle Void (Character Tab)")
cmdBox:add_label("?a → Auto ragebot")
cmdBox:add_label("?reset → Clear ragebot")
cmdBox:add_label("?f / ?f off → Follow owner")
cmdBox:add_label("?tp → Teleport to player")
cmdBox:add_label("?fix → Reset character")
cmdBox:add_label("?leave → Exit game")

-- =========================
-- REGISTRATION & LOAD FIX
-- =========================
local function initialize()
    -- Loop until the utility system is actually available to prevent nil errors
    local currentUtil = utility or _G.utility
    while not currentUtil do
        task.wait(1)
        currentUtil = utility or _G.utility
    end

    if currentUtil.on_event then
        currentUtil.on_event("on_message", function(player, message)
            local sender = type(player) == "string" and Players:FindFirstChild(player) or player
            if sender and sender.Name == owner and message:sub(1, #prefix) == prefix then
                local args = string.split(message:sub(#prefix + 1), " ")
                local cmd = table.remove(args, 1):lower()
                if commands[cmd] then commands[cmd](sender, unpack(args)) end
            end
        end)
    else
        -- Fallback: Register commands normally if on_event isn't available
        for n, f in pairs(commands) do
            pcall(function() api:on_command(prefix..n, function(p,...) if p.Name==owner then f(p,...) end end) end)
        end
    end
end

-- Start the initialization process safely
task.spawn(initialize)
