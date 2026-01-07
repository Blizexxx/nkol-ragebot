local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function safe_call(func, name)
    local success, err = pcall(func)
    if not success then
        print(string.format("[VEXIS ERROR] in %s: %s", name or "Unknown", tostring(err)))
    end
    return success, err
end

local MainEvent = ReplicatedStorage:FindFirstChild("MainEvent")
if not MainEvent then print("[VEXIS ERROR] MainEvent not found in ReplicatedStorage!") end

safe_call(function() api:set_lua_name("Vexis") end, "api:set_lua_name")

local ragebot_tab, protector_group, utility_group
safe_call(function()
    ragebot_tab = api:GetTab("ragebot") or api:AddTab("ragebot")
    protector_group = ragebot_tab:AddLeftGroupbox("Vexis Protector")
    utility_group = ragebot_tab:AddRightGroupbox("Vexis Utility")
end, "UI Setup Tabs/Groups")

safe_call(function()
    protector_group:AddToggle("protector_active", { Text = "Enable Protector", Default = false })
    protector_group:AddToggle("protector_stomp", { Text = "Stomp Target (Doesnt Work w FP)", Default = false })
    protector_group:AddDropdown("protector_targets", { Text = "Select Players to Protect", Values = {}, Multi = true, Default = {} })
    protector_group:AddDropdown("protector_strafe_style", { Text = "Strafe Style", Values = {"Circle", "Orbit", "V-Spiral", "Madness", "Figure-8", "Square", "Jitter-Void", "Hyper-Orbit", "Spiral-Out", "Zig-Zag", "Tele-Jitter"}, Default = "Madness", Multi = false })
    protector_group:AddSlider("protector_strafe_dist", { Text = "Strafe Distance", Default = 8, Min = 0, Max = 50, Rounding = 1, Compact = false })
    protector_group:AddSlider("protector_strafe_speed", { Text = "Strafe Speed", Default = 12, Min = 1, Max = 50, Rounding = 1, Compact = false })
    protector_group:AddToggle("protector_use_flame", { Text = "Use Flame while Killing", Default = false })
    protector_group:AddButton("Clear All Protected", function()
        local targets_obj = api:get_ui_object("protector_targets")
        if targets_obj then targets_obj:SetValue({}) end
    end)
    protector_group:AddButton("Force Stop Ragebot", function()
        api:set_ragebot(false)
        local rb_enabled = api:get_ui_object("ragebot_enabled")
        if rb_enabled then 
            rb_enabled:SetValue(false) 
        end
        local rb_targets = api:get_ui_object("ragebot_targets")
        if rb_targets then
            rb_targets:SetValue({})
            rb_targets:SetValue("")
        end
        api:notify("[VEXIS] Ragebot Force Stopped", 4)
    end)

    utility_group:AddDropdown("utility_bring_player", { Text = "Select Player to Bring", Values = {}, Multi = false, Default = nil, AllowNull = true })
    utility_group:AddToggle("utility_drop_on_bring", { Text = "Drop after Bring", Default = false })
    utility_group:AddButton("Bring Player", function()
        local dropdown = api:get_ui_object("utility_bring_player")
        if dropdown and dropdown.Value then
            startBring(dropdown.Value)
        else
            api:notify("[VEXIS] No player selected to bring!", 3)
        end
    end)
    utility_group:AddButton("Force Stop Bring", function()
        if bringing_target then
            api:notify("[VEXIS] Bringing operation cancelled.", 4)
            stopBringProcess()
        end
    end)
end, "UI Setup Objects")

local function getFormattedName(player)
    return string.format("%s (@%s)", player.DisplayName, player.Name)
end

local function updatePlayerList()
    safe_call(function()
        local dropdown_items = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local formatted = getFormattedName(player)
                table.insert(dropdown_items, formatted)
            end
        end
        
        local dropdown_p = api:get_ui_object("protector_targets")
        if dropdown_p then dropdown_p:SetValues(dropdown_items) end
        
        local dropdown_b = api:get_ui_object("utility_bring_player")
        if dropdown_b then dropdown_b:SetValues(dropdown_items) end
    end, "updatePlayerList")
end

safe_call(function()
    updatePlayerList()
    api:add_connection(Players.PlayerAdded:Connect(updatePlayerList))
    api:add_connection(Players.PlayerRemoving:Connect(updatePlayerList))
end, "Player List Connections")

-- =====================
-- COMMAND SYSTEM SETUP
-- =====================
local commands = {}

-- Get player helper
local function getplayer(txt)
    if not txt then return end
    txt = txt:lower()
    for _,p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():sub(1,#txt)==txt or p.DisplayName:lower():sub(1,#txt)==txt then
            return p
        end
    end
end

-- Ragebot save/restore
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

-- =====================
-- ?b Bring Command (updated)
-- =====================
commands.b = function(_, name)
    local target = getplayer(name)
    if not target then
        api:notify("Player not found: "..(name or "nil"), 3)
        return
    end

    local bringing_target = target
    local saved = saveRB()
    local rb_targets = api:get_ui_object("ragebot_targets")
    if rb_targets then rb_targets:SetValue({[target.Name]=true}) end
    api:set_ragebot(true)
    api:notify("Bringing "..target.DisplayName.."...", 4)

    local glue_connection
    task.spawn(function()
        safe_call(function()
            local initial_char = target.Character
            -- Wait until target is KO
            repeat task.wait(0.15) until api:get_status_cache(target)["K.O"]

            -- Stop ragebot before gluing
            api:set_ragebot(false)
            if rb_targets then rb_targets:SetValue({}) end

            -- Glue your character above target
            glue_connection = RunService.Heartbeat:Connect(function()
                safe_call(function()
                    if not target.Character or not target.Character:FindFirstChild("UpperTorso") then return end
                    if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return end
                    local targetPos = target.Character.UpperTorso.Position
                    LocalPlayer.Character.PrimaryPart.CFrame = CFrame.new(targetPos + Vector3.new(0, 4.5, 0))
                end, "Bring Glue Heartbeat")
            end)

            -- Wait 10 seconds while glued
            task.wait(10)
            if glue_connection then glue_connection:Disconnect() glue_connection = nil end
            if bringing_target ~= target then return end

            -- Restore previous ragebot state
            restoreRB(saved)
            api:notify("Finished bringing "..target.DisplayName, 4)
        end, "Bring Command Task")
    end)
end

-- =====================
-- Register Commands
-- =====================
local owner = LocalPlayer.Name
local prefix = "?"

for n,f in pairs(commands) do
    api:on_command(prefix..n,function(p,...) if p.Name==owner then f(p,...) end end)
end

api:notify("Vexis Addon Loaded with updated bring feature!", 3)
