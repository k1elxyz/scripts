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
    TweenSpeed = 0.3,
    HopDelay = 10,
    RaidTimeout = 300,
    LoopEnabled = true,
    SelectWeapon = "Melee", -- Melee/Sword/Gun/Fruit
    FastAttackDelay = 0.1,
}

-- GLOBALS FOR RAID
_G.RaidRunning = false
_G.StartBring = false
_G.BringPos = nil
_G.MonFarm = nil

-- UTILITY FUNCTIONS
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

-- TWEEN FUNCTIONS
local function TweenTo(cf)
    pcall(function()
        local info = TweenInfo.new(Config.TweenSpeed, Enum.EasingStyle.Linear)
        TweenSvc:Create(Root, info, {CFrame = cf}):Play()
        task.wait(Config.TweenSpeed + 0.1)
    end)
end

local function topos(cf)
    pcall(function() Root.CFrame = cf end)
    task.wait(0.6)
end

local function TP1(cf)
    pcall(function()
        local dist = (cf.Position - Root.Position).Magnitude
        local speed = 300
        local t = dist / speed
        if t > 0 then
            local tween = TweenSvc:Create(Root, TweenInfo.new(t, Enum.EasingStyle.Linear), {CFrame = cf})
            tween:Play()
            tween.Completed:Wait()
        end
    end)
end

-- NOCLIP SYSTEM (CRITICAL FOR RAID)
local NoClip = false
local function enableNoclip()
    if not Root:FindFirstChild("BodyClip") then
        local bodyClip = Instance.new("BodyVelocity")
        bodyClip.Name = "BodyClip"
        bodyClip.Parent = Root
        bodyClip.MaxForce = Vector3.new(100000, 100000, 100000)
        bodyClip.Velocity = Vector3.new(0, 0, 0)
    end
end

local function disableNoclip()
    local bc = Root:FindFirstChild("BodyClip")
    if bc then bc:Destroy() end
end

spawn(function()
    while task.wait(0.2) do
        pcall(function()
            if NoClip or _G.RaidRunning then
                enableNoclip()
                for _, v in pairs(Char:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide = false end
                end
            else
                disableNoclip()
            end
        end)
    end
end)

-- COMBAT FUNCTIONS (CRITICAL - THESE WERE MISSING!)
local function AutoHaki()
    if not Char:FindFirstChild("HasBuso") then
        pcall(function()
            getCommF():InvokeServer("Buso")
        end)
    end
end

local function EquipWeapon(weaponType)
    if not weaponType then weaponType = Config.SelectWeapon end
    pcall(function()
        local tool
        if weaponType == "Melee" then
            for _, v in pairs(Plr.Backpack:GetChildren()) do
                if v:IsA("Tool") and v.ToolTip == "Melee" then
                    tool = v; break
                end
            end
        elseif weaponType == "Sword" then
            for _, v in pairs(Plr.Backpack:GetChildren()) do
                if v:IsA("Tool") and v.ToolTip == "Sword" then
                    tool = v; break
                end
            end
        elseif weaponType == "Gun" then
            for _, v in pairs(Plr.Backpack:GetChildren()) do
                if v:IsA("Tool") and v.ToolTip == "Gun" then
                    tool = v; break
                end
            end
        elseif weaponType == "Fruit" or weaponType == "Blox Fruit" then
            for _, v in pairs(Plr.Backpack:GetChildren()) do
                if v:IsA("Tool") and v.ToolTip == "Blox Fruit" then
                    tool = v; break
                end
            end
        end
        if tool then
            Char.Humanoid:EquipTool(tool)
        end
    end)
end

local function AttackNoCD()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:Button1Down(Vector2.new(1280, 672))
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
        local url
        if cursor ~= "" then
            url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100&cursor=" .. cursor
        else
            url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
        end

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
                for _, t in pairs(tried) do
                    if t == serverId then alreadyTried = true; break end
                end
                if not alreadyTried then
                    table.insert(tried, serverId)
                    Notify("Hopping to server: " .. serverId)
                    pcall(function()
                        TpSvc:TeleportToPlaceInstance(placeId, serverId, Plr)
                    end)
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
    TweenTo(fruit.Handle.CFrame)
    task.wait(0.3)
    pcall(function() Root.CFrame = fruit.Handle.CFrame end)
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
        Notify("No Special Microchip found! Skipping raid.")
        return false
    end

    -- Check if already in raid
    local gui = Plr.PlayerGui:FindFirstChild("Main")
    if gui and gui:FindFirstChild("Timer") and gui.Timer.Visible then
        Notify("Active raid detected, joining...")
        return true
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

    task.wait(2)
    Notify("Raid started!")
    return true
end

-- FIXED RAID ISLAND DETECTION
local function GetRaidIsland()
    local locations = Workspace:FindFirstChild("_WorldOrigin") 
        and Workspace._WorldOrigin:FindFirstChild("Locations")
    if not locations then return nil end
    
    -- Raid islands are numbered 1-5
    for i = 1, 5 do
        local island = locations:FindFirstChild("Island " .. i)
        if island then
            local dist = (island.Position - Root.Position).Magnitude
            if dist <= 5000 then
                return island
            end
        end
    end
    return nil
end

local function GetNextRaidIsland()
    local locations = Workspace:FindFirstChild("_WorldOrigin") 
        and Workspace._WorldOrigin:FindFirstChild("Locations")
    if not locations then return nil end
    
    -- Find highest available island
    for i = 5, 1, -1 do
        local island = locations:FindFirstChild("Island " .. i)
        if island then
            local dist = (island.Position - Root.Position).Magnitude
            if dist <= 4500 then
                return island
            end
        end
    end
    return nil
end

local function IsRaidActive()
    local locations = Workspace:FindFirstChild("_WorldOrigin") 
        and Workspace._WorldOrigin:FindFirstChild("Locations")
    if not locations then return false end
    return locations:FindFirstChild("Island 1") ~= nil
        or locations:FindFirstChild("Island 2") ~= nil
        or locations:FindFirstChild("Island 3") ~= nil
        or locations:FindFirstChild("Island 4") ~= nil
        or locations:FindFirstChild("Island 5") ~= nil
end

-- FIXED RAID ENEMY FARMING - THIS WAS THE MAIN PROBLEM!
local function FarmRaidEnemies()
    for _, mob in pairs(Workspace.Enemies:GetChildren()) do
        if mob:FindFirstChild("HumanoidRootPart")
        and mob:FindFirstChild("Humanoid")
        and mob.Humanoid.Health > 0
        and (mob.HumanoidRootPart.Position - Root.Position).Magnitude <= 1500 then
            
            -- SETUP BRING SYSTEM
            _G.BringPos = mob.HumanoidRootPart.CFrame
            _G.MonFarm = mob.Name
            _G.StartBring = true
            
            repeat
                task.wait(Config.FastAttackDelay)
                refreshChar()
                
                if mob.Humanoid.Health > 0 then
                    -- ENABLE COMBAT
                    AutoHaki()
                    EquipWeapon(Config.SelectWeapon)
                    NoClip = true
                    
                    -- ATTACK POSITION (above enemy)
                    local targetPos = mob.HumanoidRootPart.CFrame * CFrame.new(0, 35, 0)
                    TP1(targetPos)
                    
                    -- LOCK ENEMY
                    mob.HumanoidRootPart.CanCollide = false
                    mob.Humanoid.WalkSpeed = 0
                    mob.HumanoidRootPart.Size = Vector3.new(60, 60, 60)
                    mob.HumanoidRootPart.CFrame = _G.BringPos
                    
                    -- ATTACK!
                    AttackNoCD()
                    
                    -- EXTEND SIMULATION RADIUS
                    pcall(function()
                        sethiddenproperty(Plr, "SimulationRadius", math.huge)
                    end)
                end
                
            until mob.Humanoid.Health <= 0 
                or not mob.Parent 
                or not _G.RaidRunning
                or not IsRaidActive()
            
            _G.StartBring = false
        end
    end
end

-- BRING SYSTEM FOR RAID
spawn(function()
    while task.wait(0.1) do
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
                    end
                end
            end
        end)
    end
end)

-- COMPLETE RAID WITH PROPER LOGIC
local function CompleteRaid()
    _G.RaidRunning = true
    NoClip = true
    Notify("Completing raid...")
    
    local elapsed = 0
    local lastEnemyTime = tick()
    
    while _G.RaidRunning and elapsed < Config.RaidTimeout do
        task.wait(0.1)
        elapsed = elapsed + 0.1
        
        -- Check if raid ended
        if not IsRaidActive() then
            Notify("Raid completed!")
            break
        end
        
        refreshChar()
        
        -- Check death
        if Char.Humanoid.Health <= 0 then
            Notify("Died, waiting for respawn...")
            _G.RaidRunning = false
            NoClip = false
            task.wait(5)
            refreshChar()
            _G.RaidRunning = true
            NoClip = true
        end
        
        -- Farm enemies
        local enemyCount = 0
        for _, mob in pairs(Workspace.Enemies:GetChildren()) do
            if mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
                enemyCount = enemyCount + 1
            end
        end
        
        if enemyCount > 0 then
            lastEnemyTime = tick()
            FarmRaidEnemies()
        else
            -- No enemies, check for next island
            if tick() - lastEnemyTime > 3 then
                local nextIsland = GetNextRaidIsland()
                if nextIsland then
                    Notify("Moving to next island...")
                    topos(nextIsland.CFrame * CFrame.new(0, 60, 0))
                    task.wait(1)
                end
            end
        end
    end
    
    if elapsed >= Config.RaidTimeout then
        Notify("Raid timed out!")
    end
    
    _G.RaidRunning = false
    NoClip = false
    _G.StartBring = false
    task.wait(1)
end

-- MAIN LOOP
local function RunLoop()
    Notify("Loop started!")
    while Config.LoopEnabled do
        task.wait(2)
        refreshChar()
        
        -- Check death first
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
                
                -- Collect fruit
                Notify("Picking up: " .. fruit.Name)
                CollectFruit(fruit)
                task.wait(1)
                
                -- Buy chip and start raid
                BuyChip()
                local started = StartRaid()
                
                if started then
                    CompleteRaid()
                    task.wait(2)
                else
                    Notify("Failed to start raid, continuing...")
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
