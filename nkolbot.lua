-- Original owner: Blizexxx / Integrated Chat & Utility System
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local MainEvent = ReplicatedStorage:FindFirstChild("MainEvent")

-- 1. WAIT FOR UTILITY TO LOAD (Prevents the 'index nil' error)
local utility = utility or _G.utility
local count = 0
while not utility and count < 50 do
    task.wait(0.1)
    utility = utility or _G.utility
    count = count + 1
end

-- 2. CONFIG
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

-- 3. HELPER FUNCTIONS
local function send(msg)
    pcall(function()
        if api and api.chat then api:chat(msg)
        elseif api and api.Chat then api:Chat(msg) end
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

-- 4. COMMAND DEFINITIONS
local commands = {}

-- The ?fix command you requested
commands.fix = function()
    send("Resetting character...")
    -- Priority 1: API Reset if available
    if api and api.reset_character then
        api:reset_character()
    -- Priority 2: Standard Roblox Reset
    elseif LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.Health = 0
    -- Priority 3: Forced Respawn
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
    if api then api:get_ui_object("ragebot_targets"):SetValue(targets) end
end

commands.reset = function()
    targets = {}
    if api then
        api:get_ui_object("ragebot_targets"):SetValue({})
        api:set_ragebot(false)
    end
    send("Ragebot cleared")
end

-- 5. MAIN EXECUTION & EVENT LISTENING
if utility then
    -- Use the on_event system from your documentation
    utility.on_event("on_message", function(player_name, message)
        -- Ensure sender is the owner and message starts with prefix
        if player_name == owner and message:sub(1, #prefix) == prefix then
            local full_cmd = message:sub(#prefix + 1)
            local args = string.split(full_cmd, " ")
            local cmd_name = table.remove(args, 1):lower()

            local func = commands[cmd_name]
            if func then
                func(LocalPlayer, unpack(args))
            end
        end
    end)

    utility.notify("NKOL Loader: Success")
else
    -- Final Fallback if utility never loads
    LocalPlayer.Chatted:Connect(function(msg)
        if msg:sub(1, #prefix) == prefix then
            local args = string.split(msg:sub(#prefix+1), " ")
            local cmd = table.remove(args, 1):lower()
            if commands[cmd] then commands[cmd](LocalPlayer, unpack(args)) end
        end
    end)
end
