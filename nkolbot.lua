-- Original owner: Blizexxx / integrated chat system
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local MainEvent = ReplicatedStorage:FindFirstChild("MainEvent")

-- FIX 1: Safety check for utility to prevent the 'on_event' nil error
local utility = utility or _G.utility or {}

-- CONFIG
local config = getgenv().NKOL_RAGEBOT or {
    Owner = LocalPlayer.Name,
    Prefix = "?",
    SelectedWeapons = "LMG/Rifle",
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

-- HELPER: Search for a UI object by name across all tabs
local function findUIObject(name)
    local found = nil
    pcall(function()
        found = api:get_ui_object(name)
        if not found then
            -- Deep search if standard lookup fails
            for _, tab in pairs(api:get_tabs()) do
                if tab.get_ui_object then
                    found = tab:get_ui_object(name)
                    if found then break end
                end
            end
        end
    end)
    return found
end

-- =========================
-- COMMANDS
-- =========================
local commands = {}

-- ?v toggle (Updated to fix "Not Found" error)
commands.v = function()
    -- Look for common internal names for that 'enabled' checkbox in the void tab
    local voidToggle = findUIObject("void_enabled") or findUIObject("enabled_void") or findUIObject("void_active")
    
    if voidToggle then
        local newState = not voidToggle.Value
        voidToggle:SetValue(newState)
        send("Void toggle: " .. (newState and "ENABLED" or "DISABLED"))
    else
        -- If we still can't find it by name, we try the API function directly
        if api and api.toggle_void then
            api:toggle_void()
            send("Void toggled via API.")
        else
            send("Error: Script cannot find the Void toggle path. Please check the tab name.")
        end
    end
end

-- ?fix resets character
commands.fix = function()
    if api and api.reset_character then
        api:reset_character()
    elseif LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.Health = 0
    end
    send("Character reset!")
end

-- ?a Auto ragebot
commands.a = function(_, ...)
    local targets = {}
    for _,n in pairs({...}) do
        local plr = nil
        for _,p in ipairs(Players:GetPlayers()) do
            if p.Name:lower():sub(1,#n)==n:lower() or p.DisplayName:lower():sub(1,#n)==n:lower() then
                plr = p; break
            end
        end
        if plr then targets[plr.Name] = true end
    end
    local obj = findUIObject("ragebot_targets")
    if obj then obj:SetValue(targets) end
    api:set_ragebot(true)
    send("Ragebot targets updated.")
end

-- ... [Other commands like ?tp, ?kill remain the same]

-- =========================
-- REGISTER (The Final Fix)
-- =========================
local function startBot()
    -- We wrap this in a loop that checks every second until the utility is ready
    task.spawn(function()
        local registered = false
        while not registered do
            local currentUtil = utility or _G.utility
            if currentUtil and currentUtil.on_event then
                currentUtil.on_event("on_message", function(player, message)
                    local sender = type(player) == "string" and Players:FindFirstChild(player) or player
                    if sender and sender.Name == owner and message:sub(1, #prefix) == prefix then
                        local args = string.split(message:sub(#prefix + 1), " ")
                        local cmd = table.remove(args, 1):lower()
                        if commands[cmd] then commands[cmd](sender, unpack(args)) end
                    end
                end)
                registered = true
            else
                -- If UE utility isn't ready, use standard API command registration as a backup
                for n, f in pairs(commands) do
                    pcall(function() api:on_command(prefix..n, function(p,...) if p.Name==owner then f(p,...) end end) end)
                end
                task.wait(2) -- Wait before trying to find 'on_event' again
            end
        end
    end)
end

startBot()
