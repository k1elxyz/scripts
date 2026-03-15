--[[
    OPTIMIZED RAID FARM HOP SCRIPT
    Features:
    - Auto join Marines team
    - Fruit detection and collection within radius
    - Auto buy raid chip
    - Auto start raid
    - Auto farm raid enemies with proper combat
    - Auto complete raid (all 5 islands)
    - Server hop when no fruits found
    - Proper equipment and Haki usage
]]

-- Services
local Players = game:GetService("Players")
local RepStorage = game:GetService("ReplicatedStorage")
local TweenSvc = game:GetService("TweenService")
local TpSvc = game:GetService("TeleportService")
local HttpSvc = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- Player References
local Plr = Players.LocalPlayer
local function GetChar() return Plr.Character end
local function GetRoot() return GetChar() and GetChar():FindFirstChild("HumanoidRootPart") end
local function GetHum() return GetChar() and GetChar():FindFirstChild("Humanoid") end

-- World Detection
local World1 = game.PlaceId == 2753915549 or game.PlaceId == 85211729168715
local World2 = game.PlaceId == 4442272183 or game.PlaceId == 79091703265657
local World3 = game.PlaceId == 7449423635 or game.PlaceId == 100117331123089

-- Configuration
local Config = {
    ChipType = "Flame", -- Change this: Flame, Ice, Sand, Dark, Light, Magma, Quake, Buddha, Spider, Phoenix, Lightning, Dough
    FruitRadius = 6000, -- Detection radius for fruits
    TweenSpeed = 360, -- Movement speed
    HopDelay = 10, -- Delay before hopping
    RaidTimeout = 600, -- Max raid duration (10 minutes)
    LoopEnabled = true,
    AutoHaki = true,
    SelectWeapon = "Combat", -- Your main weapon
}

-- Global States
_G.RaidRunning = false
_G.NotAutoEquip = false
local NoClip = false
local TweenActive = false

-- ===============================
-- UTILITY FUNCTIONS
-- ===============================

local function Notify(msg)
    print("[RaidFarm] " .. msg)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "RaidFarm", 
            Text = msg, 
            Duration = 5
        })
    end)
end

local function getCommF()
    return RepStorage:WaitForChild("Remotes"):WaitForChild("CommF_")
end

local function WaitForChar()
    local char = Plr.Character or Plr.CharacterAdded:Wait()
    char:WaitForChild("HumanoidRootPart")
    char:WaitForChild("Humanoid")
    return char
end

-- ===============================
-- COMBAT FUNCTIONS
-- ===============================

function AutoHaki()
    if not Config.AutoHaki then return end
    local char = GetChar()
    if char and not char:FindFirstChild("HasBuso") then
        pcall(function()
            getCommF():InvokeServer("Buso")
        end)
    end
end

function EquipWeapon(weaponName)
    if _G.NotAutoEquip then return end
    local weapon = weaponName or Config.SelectWeapon
    
    pcall(function()
        if Plr.Backpack:FindFirstChild(weapon) then
            local tool = Plr.Backpack:FindFirstChild(weapon)
            local hum = GetHum()
            if hum then
                hum:EquipTool(tool)
            end
        end
    end)
end

-- ===============================
-- MOVEMENT FUNCTIONS
-- ===============================

local function StopTween()
    TweenActive = false
    local root = GetRoot()
    if not root then return end
    
    pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.Velocity = Vector3.zero
        
        for _, obj in pairs(root:GetChildren()) do
            if obj:IsA("BodyVelocity") or obj:IsA("BodyGyro") or 
               obj:IsA("BodyPosition") or obj:IsA("AlignPosition") or 
               obj:IsA("AlignOrientation") then
                obj:Destroy()
            end
        end
        
        if root:FindFirstChild("BodyClip") then
            root.BodyClip:Destroy()
        end
    end)
    
    local char = GetChar()
    if char and char:FindFirstChild("PartTele") then
        char.PartTele:Destroy()
    end
end

function topos(targetCF)
    local char = GetChar()
    local root = GetRoot()
    local hum = GetHum()
    
    if not char or not root or not hum or hum.Health <= 0 then return end
    if not targetCF then return end
    
    local distance = (targetCF.Position - root.Position).Magnitude
    
    -- Create teleport part if doesn't exist
    if not char:FindFirstChild("PartTele") then
        local part = Instance.new("Part", char)
        part.Size = Vector3.new(10, 1, 10)
        part.Name = "PartTele"
        part.Anchored = true
        part.Transparency = 1
        part.CanCollide = false
        part.CFrame = root.CFrame
        
        part:GetPropertyChangedSignal("CFrame"):Connect(function()
            if TweenActive and char and root then
                root.CFrame = part.CFrame
            end
        end)
    end
    
    TweenActive = true
    local tweenInfo = TweenInfo.new(distance / Config.TweenSpeed, Enum.EasingStyle.Linear)
    local tween = TweenSvc:Create(char.PartTele, tweenInfo, {CFrame = targetCF})
    
    tween:Play()
    tween.Completed:Connect(function(state)
        if state == Enum.PlaybackState.Completed then
            if char:FindFirstChild("PartTele") then
                char.PartTele:Destroy()
            end
            TweenActive = false
        end
    end)
end

-- NoClip for smooth movement
RunService.Stepped:Connect(function()
    if NoClip then
        pcall(function()
            local char = GetChar()
            if char then
                for _, v in pairs(char:GetDescendants()) do
                    if v:IsA("BasePart") then
                        v.CanCollide = false
                    end
                end
            end
        end)
    end
end)

-- ===============================
-- FRUIT COLLECTION
-- ===============================

local function GetDroppedFruits()
    local fruits = {}
    local root = GetRoot()
    if not root then return fruits end
    
    for _, obj in pairs(Workspace:GetChildren()) do
        if string.find(obj.Name, "Fruit") and obj:FindFirstChild("Handle") then
            local dist = (root.Position - obj.Handle.Position).Magnitude
            if dist <= Config.FruitRadius then
                table.insert(fruits, {obj = obj, dist = dist})
            end
        end
    end
    
    -- Sort by distance (closest first)
    table.sort(fruits, function(a, b) return a.dist < b.dist end)
    
    local result = {}
    for _, f in ipairs(fruits) do
        table.insert(result, f.obj)
    end
    
    return result
end

local function CollectFruit(fruit)
    if not fruit or not fruit:FindFirstChild("Handle") then return end
    
    Notify("Collecting: " .. fruit.Name)
    NoClip = true
    topos(fruit.Handle.CFrame)
    task.wait(0.5)
    
    -- Direct teleport to ensure pickup
    pcall(function()
        local root = GetRoot()
        if root then
            root.CFrame = fruit.Handle.CFrame
        end
    end)
    
    task.wait(0.7)
    NoClip = false
end

-- ===============================
-- RAID FUNCTIONS
-- ===============================

local function BuyChip()
    Notify("Buying " .. Config.ChipType .. " chip...")
    NoClip = true
    
    if World2 then
        topos(CFrame.new(-6438.73, 250.64, -4501.5))
        task.wait(0.5)
    elseif World3 then
        pcall(function()
            getCommF():InvokeServer("requestEntrance", Vector3.new(-5075.5, 314.51, -3150.02))
        end)
        task.wait(0.3)
        topos(CFrame.new(-5017.4, 314.84, -2823.01))
        task.wait(0.5)
    end
    
    task.wait(0.5)
    
    -- Buy the chip
    pcall(function()
        getCommF():InvokeServer("RaidsNpc", "Select", Config.ChipType)
    end)
    
    task.wait(1)
    NoClip = false
    Notify("Chip purchased!")
end

local function HasMicrochip()
    return Plr.Backpack:FindFirstChild("Special Microchip") or 
           (GetChar() and GetChar():FindFirstChild("Special Microchip"))
end

local function IsRaidActive()
    local ok, result = pcall(function()
        return Workspace._WorldOrigin.Locations:FindFirstChild("Island 1") ~= nil
    end)
    return ok and result
end

local function StartRaid()
    -- Wait for microchip
    local waited = 0
    repeat
        task.wait(0.5)
        waited = waited + 0.5
    until HasMicrochip() or waited >= 15
    
    if not HasMicrochip() then
        Notify("No Special Microchip found!")
        return false
    end
    
    -- Check if raid already active
    local gui = Plr.PlayerGui:FindFirstChild("Main")
    if gui and gui:FindFirstChild("Timer") and gui.Timer.Visible then
        Notify("Raid already active, farming...")
        return true
    end
    
    if IsRaidActive() then
        Notify("Raid already started!")
        return true
    end
    
    Notify("Starting raid...")
    NoClip = true
    
    if World2 then
        topos(CFrame.new(-6438.73, 250.64, -4501.5))
        task.wait(0.5)
        pcall(function()
            getCommF():InvokeServer("SetSpawnPoint")
        end)
        task.wait(0.3)
        pcall(function()
            fireclickdetector(Workspace.Map.CircleIsland.RaidSummon2.Button.Main.ClickDetector)
        end)
    elseif World3 then
        pcall(function()
            getCommF():InvokeServer("requestEntrance", Vector3.new(-5075.5, 314.51, -3150.02))
        end)
        task.wait(0.3)
        topos(CFrame.new(-5017.4, 314.84, -2823.01))
        task.wait(0.5)
        pcall(function()
            getCommF():InvokeServer("SetSpawnPoint")
        end)
        task.wait(0.3)
        pcall(function()
            fireclickdetector(Workspace.Map["Boat Castle"].RaidSummon2.Button.Main.ClickDetector)
        end)
    end
    
    task.wait(2)
    NoClip = false
    
    -- Verify raid started
    task.wait(1)
    if IsRaidActive() then
        Notify("Raid started successfully!")
        return true
    else
        Notify("Failed to start raid, retrying...")
        return false
    end
end

local function GetIsland(num)
    local closest, dist = nil, math.huge
    for _, v in pairs(Workspace._WorldOrigin.Locations:GetChildren()) do
        if v.Name == "Island " .. num then
            local root = GetRoot()
            if root then
                local mag = (v.Position - root.Position).Magnitude
                if mag < dist then
                    dist = mag
                    closest = v
                end
            end
        end
    end
    return closest
end

local function GetNextIsland()
    -- Check islands in reverse order (5, 4, 3, 2, 1)
    for _, i in ipairs({5, 4, 3, 2, 1}) do
        local isl = GetIsland(i)
        if isl then
            local root = GetRoot()
            if root and (isl.Position - root.Position).Magnitude <= 5000 then
                return isl
            end
        end
    end
end

local function FarmRaidEnemies()
    local root = GetRoot()
    if not root then return end
    
    for _, mob in pairs(Workspace.Enemies:GetChildren()) do
        if mob:FindFirstChild("HumanoidRootPart") and
           mob:FindFirstChild("Humanoid") and
           mob.Humanoid.Health > 0 then
            
            local dist = (mob.HumanoidRootPart.Position - root.Position).Magnitude
            
            if dist <= 1500 then
                repeat
                    task.wait(0.1)
                    WaitForChar()
                    local mobRoot = mob:FindFirstChild("HumanoidRootPart")
                    local mobHum = mob:FindFirstChild("Humanoid")
                    
                    if mobRoot and mobHum and mobHum.Health > 0 then
                        AutoHaki()
                        EquipWeapon()
                        NoClip = true
                        
                        -- Disable mob collision
                        pcall(function()
                            mobRoot.CanCollide = false
                            mobHum.WalkSpeed = 0
                        end)
                        
                        -- Attack from above
                        topos(mobRoot.CFrame * CFrame.new(0, 30, 0))
                        
                        -- Increase simulation radius for better mob rendering
                        pcall(function()
                            sethiddenproperty(Plr, "SimulationRadius", math.huge)
                        end)
                    else
                        break
                    end
                until mobHum.Health <= 0 or not mob.Parent or not _G.RaidRunning
                
                NoClip = false
            end
        end
    end
end

local function CompleteRaid()
    _G.RaidRunning = true
    Notify("Farming raid...")
    
    local startTime = tick()
    local lastIsland = nil
    
    while _G.RaidRunning and (tick() - startTime) < Config.RaidTimeout do
        task.wait(0.1)
        
        -- Check if raid is still active
        if not IsRaidActive() then
            Notify("Raid completed!")
            _G.RaidRunning = false
            break
        end
        
        -- Farm nearby enemies
        FarmRaidEnemies()
        
        -- Move to next island
        local nextIsland = GetNextIsland()
        if nextIsland and nextIsland ~= lastIsland then
            Notify("Moving to " .. nextIsland.Name)
            NoClip = true
            topos(nextIsland.CFrame * CFrame.new(0, 70, 0))
            task.wait(0.5)
            NoClip = false
            lastIsland = nextIsland
        end
        
        -- Additional safety check
        local hum = GetHum()
        if hum and hum.Health <= 0 then
            WaitForChar()
            task.wait(3)
        end
    end
    
    if (tick() - startTime) >= Config.RaidTimeout then
        Notify("Raid timed out!")
    end
    
    _G.RaidRunning = false
    NoClip = false
    task.wait(2)
end

-- ===============================
-- SERVER HOP FUNCTION
-- ===============================

local function Hop()
    Notify("Server hopping...")
    task.wait(Config.HopDelay)
    
    local placeId = game.PlaceId
    local currentJobId = game.JobId
    local tried = {}
    local cursor = ""
    
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
        
        if not success or not data then return false end
        
        if data.nextPageCursor and data.nextPageCursor ~= "null" then
            cursor = data.nextPageCursor
        end
        
        for _, server in pairs(data.data) do
            local serverId = tostring(server.id)
            if serverId ~= currentJobId and 
               tonumber(server.maxPlayers) > tonumber(server.playing) and
               tonumber(server.playing) >= 1 then -- Avoid empty servers
                
                local alreadyTried = false
                for _, t in pairs(tried) do
                    if t == serverId then
                        alreadyTried = true
                        break
                    end
                end
                
                if not alreadyTried then
                    table.insert(tried, serverId)
                    Notify("Hopping to server: " .. serverId)
                    
                    local hopSuccess = pcall(function()
                        TpSvc:TeleportToPlaceInstance(placeId, serverId, Plr)
                    end)
                    
                    if hopSuccess then
                        task.wait(5)
                        return true
                    end
                end
            end
        end
        
        return false
    end
    
    -- Try to hop
    for i = 1, 10 do
        if TryHop() then
            return
        end
        task.wait(1)
    end
    
    Notify("Failed to find suitable server, retrying...")
    task.wait(5)
    Hop()
end

-- ===============================
-- MAIN LOOP
-- ===============================

local function JoinMarines()
    Notify("Joining Marines team...")
    
    local args = {"SetTeam", "Marines"}
    pcall(function()
        getCommF():InvokeServer(unpack(args))
    end)
    
    repeat 
        task.wait(1) 
    until Plr.Team and Plr.Team.Name == "Marines"
    
    Notify("Successfully joined Marines!")
end

local function RunMainLoop()
    Notify("Starting Raid Farm Loop!")
    
    while Config.LoopEnabled do
        task.wait(2)
        WaitForChar()
        
        -- Check for fruits
        local fruits = GetDroppedFruits()
        Notify("Fruits detected: " .. #fruits)
        
        if #fruits == 0 then
            Notify("No fruits found. Hopping servers...")
            Hop()
        else
            -- Farm fruits until none left
            while true do
                WaitForChar()
                local currentFruits = GetDroppedFruits()
                
                if #currentFruits == 0 then
                    Notify("All fruits collected. Hopping...")
                    Hop()
                    break
                end
                
                -- Pick up fruit
                local fruit = currentFruits[1]
                CollectFruit(fruit)
                task.wait(1)
                
                -- Buy chip
                BuyChip()
                task.wait(1)
                
                -- Start raid
                local raidStarted = false
                for attempt = 1, 3 do
                    if StartRaid() then
                        raidStarted = true
                        break
                    end
                    task.wait(2)
                end
                
                -- Farm raid if started successfully
                if raidStarted then
                    CompleteRaid()
                else
                    Notify("Failed to start raid after 3 attempts")
                end
                
                task.wait(3)
            end
        end
    end
end

-- ===============================
-- START SCRIPT
-- ===============================

Notify("Initializing Raid Farm Script...")

-- Join Marines
JoinMarines()

-- Wait a bit for team to fully load
task.wait(2)

-- Start main loop
task.spawn(RunMainLoop)

Notify("Script fully loaded! Running...")
