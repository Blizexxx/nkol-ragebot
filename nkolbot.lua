-- Original owner: Blizexxx / integrated chat system
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- CONFIG
local config = getgenv().NKOL_RAGEBOT or {
    Owner = LocalPlayer.Name,
    Prefix = "?",
    Emotes = {"floss","samba","twerk","twirl"}
}

local owner = config.Owner
local prefix = config.Prefix

-- CHAT SYSTEM
local function send(msg)
    pcall(function()
        if api and api.chat then api:chat(msg)
        elseif api and api.Chat then api:Chat(msg) end
    end)
end

-- =========================
-- COMMANDS
-- =========================
local commands = {}

-- ?v - FIXED VOID TOGGLE (SEARCHES CHARACTER TAB)
commands.v = function()
    local success, result = pcall(function()
        -- 1. Try to get the specific Character Tab
        local charTab = api:get_tab("character")
        local toggle = nil
        
        if charTab then
            -- 2. Look for the "enabled" box inside the "void" section
            toggle = charTab:get_ui_object("void_enabled") or charTab:get_ui_object("enabled")
        end
        
        -- 3. Global fallback search
        if not toggle then
            toggle = api:get_ui_object("void_enabled") or api:get_ui_object("void_active")
        end
        
        if toggle then
            local newState = not toggle.Value
            toggle:SetValue(newState)
            send("Void bot: " .. (newState and "ENABLED" or "DISABLED"))
            return true
        end
        return false
    end)

    if not success or not result then
        send("Error: Void toggle not found. Is the Character tab open?")
    end
end

-- ?fix - Character Reset
commands.fix = function()
    pcall(function()
        if api and api.reset_character then
            api:reset_character()
        elseif LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.Health = 0
        end
    end)
    send("Character reset!")
end

-- ?tp - Teleport
commands.tp = function(_, name)
    if not name then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():sub(1, #name) == name:lower() or p.DisplayName:lower():sub(1, #name) == name:lower() then
            if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                api:teleport(p.Character.HumanoidRootPart.CFrame)
                send("Teleported to " .. p.DisplayName)
            end
            break
        end
    end
end

-- =========================
-- THE "STILL WON'T WORK" FIX
-- =========================
local function safeRegister()
    task.spawn(function()
        print("NKOL: Waiting for API and Utility to load...")
        
        -- Loop until the API exists
        while not _G.api and not getgenv().api do task.wait(1) end
        local currentApi = _G.api or getgenv().api
        
        -- Loop until Utility/on_event exists
        local registered = false
        while not registered do
            local util = _G.utility or getgenv().utility
            
            if util and type(util) == "table" and util.on_event then
                -- SUCCESSFUL REGISTRATION
                util.on_event("on_message", function(player, message)
                    local sender = type(player) == "string" and Players:FindFirstChild(player) or player
                    if sender and sender.Name == owner and message:sub(1, #prefix) == prefix then
                        local args = string.split(message:sub(#prefix + 1), " ")
                        local cmd = table.remove(args, 1):lower()
                        if commands[cmd] then 
                            commands[cmd](sender, unpack(args)) 
                        end
                    end
                end)
                registered = true
                send("NKOL System Loaded. Owner: " .. owner)
            else
                -- BACKUP: Try standard command registration if on_event is missing
                pcall(function()
                    for n, f in pairs(commands) do
                        currentApi:on_command(prefix..n, function(p, ...)
                            if p.Name == owner then f(p, ...) end
                        end)
                    end
                end)
                task.wait(2) -- Retry loop
            end
        end
    end)
end

safeRegister()
