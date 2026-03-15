local Players = game:GetService("Players")
local RepStorage = game:GetService("ReplicatedStorage")
local TweenSvc = game:GetService("TweenService")
local TpSvc = game:GetService("TeleportService")
local HttpSvc = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Plr = Players.LocalPlayer

local function GetChar()
    return Plr.Character
end

local function GetRoot()
    local char = GetChar()
    if char then
        return char:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

local function GetHum()
    local char = GetChar()
    if char then
        return char:FindFirstChild("Humanoid")
    end
    return nil
end

local function WaitForChar()
    local char = Plr.Character or Plr.CharacterAdded:Wait()
    char:WaitForChild("HumanoidRootPart")
    char:WaitForChild("Humanoid")
    return char
end

local World2 = game.PlaceId == 4442272183 or game.PlaceId == 79091703265657
local World3 = game.PlaceId == 7449423635 or game.PlaceId == 100117331123089

local Config = {
    ChipType = "Flame",
    FruitRadius = 6000,
    TweenSpeed = 360,
    HopDelay = 10,
    RaidTimeout = 600,
    LoopEnabled = true,
    AutoHaki = true,
    SelectWeapon = "Combat",
}

_G.RaidRunning = false
_G.NotAutoEquip = false
local NoClip = false
local TweenActive = false

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

local function AutoHaki()
    if not Config.AutoHaki then return end
    local char = GetChar()
    if char and not char:FindFirstChild("HasBuso") then
        pcall(function()
            getCommF():InvokeServer("Buso")
        end)
    end
end

local function EquipWeapon(weaponName)
    if _G.NotAutoEquip then return end
    local weapon = weaponName or Config.SelectWeapon
    pcall(function()
        local tool = Plr.Backpack:FindFirstChild(weapon)
        if tool then
            local hum = GetHum()
            if hum then
                hum:EquipTool(tool)
            end
        end
    end)
end

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

local function topos(targetCF)
    local char = GetChar()
    local root = GetRoot()
    local hum = GetHum()
    if not char or not root or not hum then return end
    if hum.Health <= 0 then return end
    if not targetCF then return end

    local distance = (targetCF.Position - root.Position).Magnitude

    if not char:FindFirstChild("PartTele") then
        local part = Instance.new("Part")
        part.Size = Vector3.new(10, 1, 10)
        part.Name = "PartTele"
        part.Anchored = true
        part.Transparency = 1
        part.CanCollide = false
        part.CFrame = root.CFrame
        part.Parent = char

        part:GetPropertyChangedSignal("CFrame"):Connect(function()
            if TweenActive then
                local c = GetChar()
                local r = GetRoot()
                if c and r then
                    r.CFrame = part.CFrame
                end
            end
        end)
    end

    TweenActive = true
    local tweenTime = distance / Config.TweenSpeed
    if tweenTime < 0.1 then tweenTime = 0.1 end
    local tweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle.Linear)
    local tween = TweenSvc:Create(char.PartTele, tweenInfo, {CFrame = targetCF})

    tween:Play()

    local done = false
    tween.Completed:Connect(function()
        done = true
        if char:FindFirstChild("PartTele") then
            char.PartTele:Destroy()
        end
        TweenActive = false
    end)

    local waited = 0
    while not done and waited < (tweenTime + 5) do
        task.wait(0.1)
        waited = waited + 0.1
    end

    if not done then
        StopTween()
    end
end

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
    pcall(function()
        local root = GetRoot()
        if root then
            root.CFrame = fruit.Handle.CFrame
        end
    end)
    task.wait(0.7)
    NoClip = false
end

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
    pcall(function()
        getCommF():InvokeServer("RaidsNpc", "Select", Config.ChipType)
    end)
    task.wait(1)
    NoClip = false
    Notify("Chip purchased!")
end

local function HasMicrochip()
    local char = GetChar()
    if Plr.Backpack:FindFirstChild("Special Microchip") then return true end
    if char and char:FindFirstChild("Special Microchip") then return true end
    return false
end

local function IsRaidActive()
    local ok, result = pcall(function()
        return Workspace._WorldOrigin.Locations:FindFirstChild("Island 1") ~= nil
    end)
    return ok and result
end

local function StartRaid()
    local waited = 0
    repeat
        task.wait(0.5)
        waited = waited + 0.5
    until HasMicrochip() or waited >= 15

    if not HasMicrochip() then
        Notify("No Special Microchip found!")
        return false
    end

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

    task.wait(1)
    if IsRaidActive() then
        Notify("Raid started successfully!")
        return true
    else
        Notify("Failed to start raid")
        return false
    end
end

local function GetIsland(num)
    local closest, dist = nil, math.huge
    local ok, _ = pcall(function()
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
    end)
    return closest
end

local function GetNextIsland()
    for _, i in ipairs({5, 4, 3, 2, 1}) do
        local isl = GetIsland(i)
        if isl then
            local root = GetRoot()
            if root and (isl.Position - root.Position).Magnitude <= 5000 then
                return isl
            end
        end
    end
    return nil
end

local function FarmRaidEnemies()
    local root = GetRoot()
    if not root then return end

    local enemies = {}
    pcall(function()
        for _, mob in pairs(Workspace.Enemies:GetChildren()) do
            if mob:FindFirstChild("HumanoidRootPart") and
               mob:FindFirstChild("Humanoid") and
               mob.Humanoid.Health > 0 then
                local dist = (mob.HumanoidRootPart.Position - root.Position).Magnitude
                if dist <= 1500 then
                    table.insert(enemies, mob)
                end
            end
        end
    end)

    for _, mob in ipairs(enemies) do
        if not _G.RaidRunning then break end

        local mobHum = mob:FindFirstChild("Humanoid")
        local mobRoot = mob:FindFirstChild("HumanoidRootPart")
        if not mobHum or not mobRoot then continue end
        if mobHum.Health <= 0 then continue end

        repeat
            task.wait(0.1)
            WaitForChar()
            mobRoot = mob:FindFirstChild("HumanoidRootPart")
            mobHum = mob:FindFirstChild("Humanoid")

            if mobRoot and mobHum and mobHum.Health > 0 then
                AutoHaki()
                EquipWeapon()
                NoClip = true

                pcall(function()
                    mobRoot.CanCollide = false
                    mobHum.WalkSpeed = 0
                end)

                topos(mobRoot.CFrame * CFrame.new(0, 30, 0))

                pcall(function()
                    sethiddenproperty(Plr, "SimulationRadius", math.huge)
                end)
            else
                break
            end
        until not mobHum or mobHum.Health <= 0 or not mob.Parent or not _G.RaidRunning

        NoClip = false
    end
end

local function CompleteRaid()
    _G.RaidRunning = true
    Notify("Farming raid...")

    local startTime = tick()
    local lastIsland = nil

    while _G.RaidRunning and (tick() - startTime) < Config.RaidTimeout do
        task.wait(0.1)

        if not IsRaidActive() then
            Notify("Raid completed!")
            _G.RaidRunning = false
            break
        end

        FarmRaidEnemies()

        local nextIsland = GetNextIsland()
        if nextIsland and nextIsland ~= lastIsland then
            Notify("Moving to " .. nextIsland.Name)
            NoClip = true
            topos(nextIsland.CFrame * CFrame.new(0, 70, 0))
            task.wait(0.5)
            NoClip = false
            lastIsland = nextIsland
        end

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
    StopTween()
    task.wait(2)
end

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

        if not success or not data or not data.data then return false end

        if data.nextPageCursor and data.nextPageCursor ~= "null" then
            cursor = data.nextPageCursor
        end

        for _, server in pairs(data.data) do
            local serverId = tostring(server.id)
            if serverId ~= currentJobId and
               tonumber(server.maxPlayers) > tonumber(server.playing) and
               tonumber(server.playing) >= 1 then

                local alreadyTried = false
                for _, t in pairs(tried) do
                    if t == serverId then
                        alreadyTried = true
                        break
                    end
                end

                if not alreadyTried then
                    table.insert(tried, serverId)
                    Notify("Joining server: " .. string.sub(serverId, 1, 8) .. "...")
                    pcall(function()
                        TpSvc:TeleportToPlaceInstance(placeId, serverId, Plr)
                    end)
                    task.wait(5)
                    return true
                end
            end
        end
        return false
    end

    for i = 1, 10 do
        if TryHop() then
            return
        end
        task.wait(1)
    end

    Notify("No servers found, force hopping...")
    pcall(function()
        TpSvc:Teleport(placeId, Plr)
    end)
end

Notify("Initializing script...")

repeat task.wait(1) until Plr.Character and Plr.Character:FindFirstChild("HumanoidRootPart")
task.wait(3)

Notify("Joining Marines...")
pcall(function()
    game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("SetTeam", "Marines")
end)

local marineWait = 0
repeat
    task.wait(1)
    marineWait = marineWait + 1
    if marineWait % 5 == 0 then
        pcall(function()
            game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("SetTeam", "Marines")
        end)
    end
until (Plr.Team and Plr.Team.Name == "Marines") or marineWait >= 30

if Plr.Team and Plr.Team.Name == "Marines" then
    Notify("Marines joined!")
else
    Notify("Marines join failed, proceeding anyway...")
end

task.wait(2)

local function RunMainLoop()
    Notify("Loop started!")
    while Config.LoopEnabled do
        task.wait(2)
        WaitForChar()

        local fruits = GetDroppedFruits()
        Notify("Fruits detected: " .. #fruits)

        if #fruits == 0 then
            Notify("No fruits. Hopping...")
            Hop()
        else
            while true do
                WaitForChar()
                local currentFruits = GetDroppedFruits()

                if #currentFruits == 0 then
                    Notify("No more fruits. Hopping...")
                    Hop()
                    break
                end

                local fruit = currentFruits[1]
                CollectFruit(fruit)
                task.wait(1)

                BuyChip()
                task.wait(1)

                local raidStarted = false
                for attempt = 1, 3 do
                    if StartRaid() then
                        raidStarted = true
                        break
                    end
                    task.wait(2)
                end

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

task.spawn(RunMainLoop)
Notify("Script fully loaded!")
