-- Original owner: Blizexxx / Integrated with Utility API
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- CONFIG
local config = getgenv().NKOL_RAGEBOT or {
    Owner = LocalPlayer.Name,
    Prefix = "?",
    SelectedWeapons = "LMG/Rifle",
    Emotes = {"floss","samba","twerk","twirl"}
}

local owner = config.Owner
local prefix = config.Prefix

-- CHAT SYSTEM (Internal)
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

-- The ?fix command
commands.fix = function()
    send("Resetting character...")
    if api and api.reset_character then
        api:reset_character()
    elseif LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.Health = 0
    else
        LocalPlayer:LoadCharacter()
    end
end

-- Add other commands to the table
commands.reset = function()
    if api then
        api:get_ui_object("ragebot_targets"):SetValue({})
        api:set_ragebot(false)
        send("Ragebot cleared")
    end
end

-- =========================
-- UTILITY EVENT LISTENER
-- =========================

-- We use pcall here so if 'utility' isn't ready yet, the script doesn't break
local status, err = pcall(function()
    utility.on_event("on_message", function(player_name, message)
        -- In some APIs, player_name is a string, in others it's an object
        local senderName = type(player_name) == "string" and player_name or player_name.Name
        
        if senderName == owner then
            if message:sub(1, #prefix) == prefix then
                local full_content = message:sub(#prefix + 1)
                local args = string.split(full_content, " ")
                local command_name = table.remove(args, 1):lower()

                local func = commands[command_name]
                if func then
                    func(Players:FindFirstChild(senderName), unpack(args))
                end
            end
        end
    end)
end)

if not status then
    warn("Utility API Error: " .. tostring(err))
    -- Fallback: If utility.on_event fails, try the standard way
    LocalPlayer.Chatted:Connect(function(msg)
        if msg:sub(1, #prefix) == prefix then
            local args = string.split(msg:sub(#prefix+1), " ")
            local cmd = table.remove(args, 1):lower()
            if commands[cmd] then commands[cmd](LocalPlayer, unpack(args)) end
        end
    end)
end

utility.notify("Script Active. Prefix: " .. prefix)
