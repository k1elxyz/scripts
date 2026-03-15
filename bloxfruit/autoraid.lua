local args = {
    "SetTeam",
    "Marines"
}
game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer(unpack(args))

repeat task.wait(1) until game:GetService("Players").LocalPlayer.Team and game:GetService("Players").LocalPlayer.Team.Name == "Marines"

local Players = game:GetService("Players")
local RepStorage = game:GetService("ReplicatedStorage")
local TweenSvc = game:GetService("TweenService")
local TpSvc = game:GetService("TeleportService")
local HttpSvc = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")

local Plr = Players.LocalPlayer
local Char = Plr.Character or Plr.CharacterAdded:Wait()
local Root = Char:WaitForChild("HumanoidRootPart")

local World2 = game.PlaceId == 4442272183 or game.PlaceId == 79091703265657
local World3 = game.PlaceId == 7449423635 or game.PlaceId == 100117331123089

-- CONFIGURATION
local Config = {
    ChipType = "Flame",
    FruitRadius = 6000,
    TweenSpeed = 0.2,
    HopDelay = 10,
    RaidTimeout = 300,
    LoopEnabled = true,
    SelectWeapon = "Melee",
    FastAttackDelay = 0.05,
    MobDistance = 1000, -- Distance to detect raid mobs
}

-- GLOBALS
_G.RaidRunning = false
_G.StartBring = false
_G.BringPos = nil
_G.MonFarm = nil
_G.NeedAttacking = false

-- UTILITY
local function Notify(msg)
    print("[FruitRaid] " .. msg)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "FruitRaid", Text = msg, Duration = 4
        })
    end)
end

Notify("Marines joined! Starting script...")

local function refreshChar()
    Char = Plr.Character or Plr.CharacterAdded:Wait()
    Root = Char:WaitForChild("HumanoidRootPart")
end

local function getCommF()
    return RepStorage:WaitForChild("Remotes"):WaitForChild("CommF_")
end

-- FAST ATTACK SYSTEM (CRITICAL - CONTINUOUS ATTACK)
spawn(function()
    while task.wait(Config.FastAttackDelay) do
        pcall(function()
            if _G.NeedAttacking then
                VirtualUser:CaptureController()
                VirtualUser:Button1Down(Vector2.new(1280, 672))
            end
        end)
    end
end)

-- TWEEN FUNCTIONS
local function topos(cf)
    pcall(function()
        local dist = (cf.Position - Root.Position).Magnitude
        local speed = 300
        local t = math.max(dist / speed, 0.01)
        local tween = TweenSvc:Create(Root, TweenInfo.new(t, Enum.EasingStyle.Linear), {CFrame = cf})
        tween:Play()
        if t > 0.5 then
            tween.Completed:Wait()
        end
    end)
end

local function TweenTo(cf)
    topos(cf)
end

-- NOCLIP SYSTEM
local NoClip = false
spawn(function()
    while task.wait(0.1) do
        pcall(function()
            if NoClip or _G.RaidRunning then
                if not Root:FindFirstChild("BodyClip") then
                    local bc = Instance.new("BodyVelocity")
                    bc.Name = "BodyClip"
                    bc.Parent = Root
                    bc.MaxForce = Vector3.new(100000, 100000, 100000)
                    bc.Velocity = Vector3.new(0, 0, 0)
                end
                for _, v in pairs(Char:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide = false end
                end
            else
                local bc = Root:FindFirstChild("BodyClip")
                if bc then bc:Destroy() end
            end
        end)
    end
end)

-- COMBAT FUNCTIONS
local function AutoHaki()
    pcall(function()
        if not Char:FindFirstChild("HasBuso") then
            getCommF():InvokeServer("Buso")
        end
    end)
end

local function EquipWeapon(weaponType)
    if not weaponType then weaponType = Config.SelectWeapon end
    pcall(function()
        local tool
        for _, v in pairs(Plr.Backpack:GetChildren()) do
            if v:IsA("Tool") then
                if weaponType == "Melee" and v.ToolTip == "Melee" then tool = v; break
                elseif weaponType == "Sword" and v.ToolTip == "Sword" then tool = v; break
                elseif weaponType == "Gun" and v.ToolTip == "Gun" then tool = v; break
                elseif (weaponType == "Fruit" or weaponType == "Blox Fruit") and v.ToolTip == "Blox Fruit" then tool = v; break
                end
            end
        end
        if tool then Char.Humanoid:EquipTool(tool) end
    end)
end

-- SERVER HOP
local function Hop()
    Notify("Server hopping...")
    task.wait(Config.HopDelay)
    local placeId = game.PlaceId
    local tried = {}
    local cursor = ""
    local currentJobId = game.JobId

    local function TryHop()
        local url = cursor ~= "" 
            and "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100&cursor=" .. cursor
            or "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"

        local success, data = pcall(function()
            return HttpSvc:JSONDecode(game:HttpGet(url))
        end)

        if not success or not data then return end
        if data.nextPageCursor and data.nextPageCursor ~= "null" then
            cursor = data.nextPageCursor
        end

        for _, server in pairs(data.data) do
            local serverId = tostring(server.id)
            if serverId ~= currentJobId and tonumber(server.maxPlayers) > tonumber(server.playing) then
                local alreadyTried = false
                for _, t in pairs(tried) do if t == serverId then alreadyTried = true; break end end
                if not alreadyTried then
                    table.insert(tried, serverId)
                    Notify("Hopping to server: " .. serverId)
                    pcall(function() TpSvc:TeleportToPlaceInstance(placeId, serverId, Plr) end)
                    task.wait(5)
                end
            end
        end
    end

    while true do
        pcall(function()
            TryHop()
            if cursor ~= "" then TryHop() end
        end)
        task.wait(1)
    end
end

-- FRUIT FUNCTIONS
local function GetDroppedFruits()
    local list = {}
    for _, obj in pairs(Workspace:GetChildren()) do
        if string.find(obj.Name, "Fruit") and obj:FindFirstChild("Handle") then
            local dist = (Root.Position - obj.Handle.Position).Magnitude
            if dist <= Config.FruitRadius then
                table.insert(list, obj)
            end
        end
    end
    return list
end

local function CollectFruit(fruit)
    if not fruit or not fruit:FindFirstChild("Handle") then return end
    Notify("Collecting: " .. fruit.Name)
    topos(fruit.Handle.CFrame)
    task.wait(0.5)
end

-- RAID FUNCTIONS
local function BuyChip()
    Notify("Buying " .. Config.ChipType .. " chip...")
    if World2 then
        topos(CFrame.new(-6438.73, 250.64, -4501.5))
    elseif World3 then
        pcall(function()
            getCommF():InvokeServer("requestEntrance", Vector3.new(-5075.5, 314.51, -3150.02))
        end)
        topos(CFrame.new(-5017.4, 314.84, -2823.01))
    end
    task.wait(0.5)
    pcall(function()
        getCommF():InvokeServer("RaidsNpc", "Select", Config.ChipType)
    end)
    task.wait(1)
    Notify("Chip purchased!")
end

local function StartRaid()
    local waited = 0
    repeat
        task.wait(1)
        waited = waited + 1
    until Plr.Backpack:FindFirstChild("Special Microchip")
        or Char:FindFirstChild("Special Microchip")
        or waited >= 10

    if not (Plr.Backpack:FindFirstChild("Special Microchip")
        or Char:FindFirstChild("Special Microchip")) then
        Notify("No Special Microchip found!")
        return false
    end

    -- Check if already in raid
    local locations = Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin:FindFirstChild("Locations")
    if locations then
        for i = 1, 5 do
            if locations:FindFirstChild("Island " .. i) then
                Notify("Already in raid! Joining...")
                return true
            end
        end
    end

    if World2 then
        topos(CFrame.new(-6438.73, 250.64, -4501.5))
        pcall(function() getCommF():InvokeServer("SetSpawnPoint") end)
        task.wait(0.5)
        pcall(function()
            fireclickdetector(Workspace.Map.CircleIsland.RaidSummon2.Button.Main.ClickDetector)
        end)
    elseif World3 then
        pcall(function()
            getCommF():InvokeServer("requestEntrance", Vector3.new(-5075.5, 314.51, -3150.02))
        end)
        topos(CFrame.new(-5017.4, 314.84, -2823.01))
        pcall(function() getCommF():InvokeServer("SetSpawnPoint") end)
        task.wait(0.5)
        pcall(function()
            fireclickdetector(Workspace.Map["Boat Castle"].RaidSummon2.Button.Main.ClickDetector)
        end)
    end

    task.wait(3)
    
    -- Wait for raid to actually start (islands appear)
    local raidStarted = false
    for i = 1, 30 do
        task.wait(0.5)
        local loc = Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin:FindFirstChild("Locations")
        if loc and loc:FindFirstChild("Island 1") then
            raidStarted = true
            break
        end
    end
    
    if raidStarted then
        Notify("Raid started successfully!")
        return true
    else
        Notify("Raid failed to start!")
        return false
    end
end

-- FIXED RAID ISLAND SYSTEM
local function GetCurrentIslandNumber()
    local locations = Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin:FindFirstChild("Locations")
    if not locations then return 0 end
    
    -- Check from highest to lowest (5 to 1)
    for i = 5, 1, -1 do
        local island = locations:FindFirstChild("Island " .. i)
        if island then
            -- Check if we're close to this island
            local dist = (island.Position - Root.Position).Magnitude
            if dist <= 4000 then
                return i
            end
        end
    end
    return 0
end

local function GetIslandPosition(num)
    local locations = Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin:FindFirstChild("Locations")
    if not locations then return nil end
    
    local island = locations:FindFirstChild("Island " .. num)
    return island and island.CFrame
end

local function IsRaidActive()
    local locations = Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin:FindFirstChild("Locations")
    if not locations then return false end
    
    for i = 1, 5 do
        if locations:FindFirstChild("Island " .. i) then
            return true
        end
    end
    return false
end

-- FIXED RAID ENEMY FARMING WITH PROPER ATTACK
local function FarmRaidEnemies()
    local enemiesFound = false
    
    for _, mob in pairs(Workspace.Enemies:GetChildren()) do
        if mob:FindFirstChild("HumanoidRootPart")
        and mob:FindFirstChild("Humanoid")
        and mob.Humanoid.Health > 0
        and (mob.HumanoidRootPart.Position - Root.Position).Magnitude <= Config.MobDistance then
            
            enemiesFound = true
            
            -- SETUP BRING SYSTEM
            _G.BringPos = mob.HumanoidRootPart.CFrame
            _G.MonFarm = mob.Name
            _G.StartBring = true
            
            -- COMBAT SETUP
            AutoHaki()
            EquipWeapon(Config.SelectWeapon)
            NoClip = true
            _G.NeedAttacking = true
            
            -- ENEMY SETUP - BIG HITBOX
            mob.HumanoidRootPart.CanCollide = false
            mob.Humanoid.WalkSpeed = 0
            mob.HumanoidRootPart.Size = Vector3.new(80, 80, 80) -- BIGGER HITBOX
            mob.Head.CanCollide = false
            
            -- FIGHT LOOP
            local fightStart = tick()
            while mob.Parent 
                and mob.Humanoid.Health > 0 
                and _G.RaidRunning
                and (tick() - fightStart) < 30 do -- Max 30 sec per enemy
                
                task.wait(0.05)
                refreshChar()
                
                if Char.Humanoid.Health <= 0 then
                    _G.NeedAttacking = false
                    _G.StartBring = false
                    return "died"
                end
                
                -- KEEP ENEMY LOCKED
                mob.HumanoidRootPart.CFrame = _G.BringPos
                mob.Humanoid.WalkSpeed = 0
                
                -- ATTACK POSITION
                local attackPos = _G.BringPos * CFrame.new(0, 35, 0)
                topos(attackPos)
                
                -- SIMULATION RADIUS
                pcall(function()
                    sethiddenproperty(Plr, "SimulationRadius", math.huge)
                end)
            end
            
            _G.NeedAttacking = false
            _G.StartBring = false
        end
    end
    
    return enemiesFound
end

-- BRING SYSTEM
spawn(function()
    while task.wait(0.05) do
        pcall(function()
            if _G.StartBring and _G.BringPos and _G.MonFarm then
                for _, v in pairs(Workspace.Enemies:GetChildren()) do
                    if v.Name == _G.MonFarm 
                    and v:FindFirstChild("Humanoid") 
                    and v:FindFirstChild("HumanoidRootPart") 
                    and v.Humanoid.Health > 0 then
                        v.HumanoidRootPart.CFrame = _G.BringPos
                        v.Humanoid.WalkSpeed = 0
                        v.HumanoidRootPart.CanCollide = false
                        v.HumanoidRootPart.Size = Vector3.new(80, 80, 80)
                    end
                end
            end
        end)
    end
end)

-- COMPLETE RAID WITH ISLAND PROGRESSION
local function CompleteRaid()
    _G.RaidRunning = true
    NoClip = true
    
    local currentIsland = 1
    local lastProgressTime = tick()
    
    Notify("Raid started! Looking for Island " .. currentIsland)
    
    while _G.RaidRunning do
        task.wait(0.1)
        refreshChar()
        
        -- Check death
        if Char.Humanoid.Health <= 0 then
            _G.NeedAttacking = false
            _G.StartBring = false
            Notify("Died! Waiting for respawn...")
            NoClip = false
            task.wait(5)
            refreshChar()
            NoClip = true
            lastProgressTime = tick()
        end
        
        -- Check if raid ended
        if not IsRaidActive() then
            Notify("Raid completed! All islands cleared.")
            break
        end
        
        -- Get current island
        local islandNum = GetCurrentIslandNumber()
        if islandNum > 0 then
            currentIsland = islandNum
        end
        
        -- Try to farm enemies
        local result = FarmRaidEnemies()
        
        if result == "died" then
            -- Handled above
        elseif result == true then
            -- Enemies found and fought
            lastProgressTime = tick()
        else
            -- No enemies found - check for next island or wait
            if tick() - lastProgressTime > 5 then
                -- Try to move to next island
                local nextIsland = GetIslandPosition(currentIsland + 1)
                if nextIsland then
                    local dist = (nextIsland.Position - Root.Position).Magnitude
                    if dist > 100 and dist < 5000 then
                        Notify("Moving to Island " .. (currentIsland + 1))
                        topos(nextIsland * CFrame.new(0, 60, 0))
                        lastProgressTime = tick()
                    end
                else
                    -- Stay on current island
                    local currentPos = GetIslandPosition(currentIsland)
                    if currentPos then
                        local dist = (currentPos.Position - Root.Position).Magnitude
                        if dist > 200 then
                            topos(currentPos * CFrame.new(0, 60, 0))
                        end
                    end
                end
            end
        end
        
        -- Timeout check
        if tick() - lastProgressTime > Config.RaidTimeout then
            Notify("Raid timeout! No progress for too long.")
            break
        end
    end
    
    _G.RaidRunning = false
    _G.NeedAttacking = false
    _G.StartBring = false
    NoClip = false
    Notify("Raid ended!")
    task.wait(2)
end

-- MAIN LOOP
local function RunLoop()
    Notify("Loop started!")
    while Config.LoopEnabled do
        task.wait(2)
        refreshChar()
        
        if Char.Humanoid.Health <= 0 then
            task.wait(5)
            refreshChar()
        end
        
        local fruits = GetDroppedFruits()
        Notify("Fruits detected: " .. #fruits)
        
        if #fruits == 0 then
            Notify("No fruits. Hopping...")
            Hop()
        else
            for _, fruit in pairs(fruits) do
                refreshChar()
                
                if Char.Humanoid.Health <= 0 then
                    refreshChar()
                    task.wait(3)
                end
                
                CollectFruit(fruit)
                task.wait(1)
                
                BuyChip()
                local started = StartRaid()
                
                if started then
                    CompleteRaid()
                    task.wait(2)
                else
                    Notify("Failed to start raid, trying next fruit...")
                end
            end
        end
    end
end

-- ANTI-AFK
Plr.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
end)

-- START
task.spawn(RunLoop)
