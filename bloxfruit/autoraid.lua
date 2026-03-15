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
local Workspace = game:GetService("Workspace")

local Plr = Players.LocalPlayer
local Char = Plr.Character or Plr.CharacterAdded:Wait()
local Root = Char:WaitForChild("HumanoidRootPart")

local World2 = game.PlaceId == 4442272183 or game.PlaceId == 79091703265657
local World3 = game.PlaceId == 7449423635 or game.PlaceId == 100117331123089

local Config = {
    ChipType = "Flame",
    FruitRadius = 5000,
    TweenSpeed = 0.3,
    HopDelay = 5,
    RaidTimeout = 300,
    LoopEnabled = true,
}

local function Notify(msg)
    print("[FruitRaid] " .. msg)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "FruitRaid", Text = msg, Duration = 4
        })
    end)
end

Notify("Marines joined! Starting script...")

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

local function refreshChar()
    Char = Plr.Character or Plr.CharacterAdded:Wait()
    Root = Char:WaitForChild("HumanoidRootPart")
end

local function getCommF()
    return RepStorage:WaitForChild("Remotes"):WaitForChild("CommF_")
end

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

    local gui = Plr.PlayerGui:FindFirstChild("Main")
    if gui and gui:FindFirstChild("Timer") and gui.Timer.Visible then
        Notify("Active raid detected, waiting...")
        repeat task.wait(1) until not gui.Timer.Visible
    end

    if World2 then
        topos(CFrame.new(-6438.73, 250.64, -4501.5))
        pcall(function() getCommF():InvokeServer("SetSpawnPoint") end)
        pcall(function()
            fireclickdetector(Workspace.Map.CircleIsland.RaidSummon2.Button.Main.ClickDetector)
        end)
    elseif World3 then
        pcall(function()
            getCommF():InvokeServer("requestEntrance", Vector3.new(-5075.5, 314.51, -3150.02))
        end)
        topos(CFrame.new(-5017.4, 314.84, -2823.01))
        pcall(function() getCommF():InvokeServer("SetSpawnPoint") end)
        pcall(function()
            fireclickdetector(Workspace.Map["Boat Castle"].RaidSummon2.Button.Main.ClickDetector)
        end)
    end

    task.wait(1)
    Notify("Raid started!")
    return true
end

local function GetIsland(num)
    local closest, dist = nil, math.huge
    for _, v in pairs(Workspace._WorldOrigin.Locations:GetChildren()) do
        if v.Name == "Island " .. num then
            local mag = (v.Position - Root.Position).Magnitude
            if mag < dist then
                dist = mag
                closest = v
            end
        end
    end
    return closest
end

local function GetNextIsland()
    for _, i in ipairs({5, 4, 3, 2, 1}) do
        local isl = GetIsland(i)
        if isl and (isl.Position - Root.Position).Magnitude <= 4500 then
            return isl
        end
    end
end

local function FarmRaidEnemies()
    for _, mob in pairs(Workspace.Enemies:GetChildren()) do
        if mob:FindFirstChild("HumanoidRootPart")
        and mob:FindFirstChild("Humanoid")
        and mob.Humanoid.Health > 0
        and (mob.HumanoidRootPart.Position - Root.Position).Magnitude <= 1000 then
            repeat
                task.wait(0.1)
                refreshChar()
                if mob.Humanoid.Health > 0 then
                    TweenTo(mob.HumanoidRootPart.CFrame * CFrame.new(0, 30, 0))
                end
            until mob.Humanoid.Health <= 0
                or not mob.Parent
                or not _G.RaidRunning
        end
    end
end

local function IsRaidActive()
    local ok, result = pcall(function()
        return Workspace._WorldOrigin.Locations:FindFirstChild("Island 1") ~= nil
    end)
    return ok and result
end

local function CompleteRaid()
    _G.RaidRunning = true
    Notify("Completing raid...")
    local elapsed = 0
    while _G.RaidRunning and elapsed < Config.RaidTimeout do
        task.wait(0.1)
        elapsed = elapsed + 0.1
        if not IsRaidActive() then
            Notify("Raid completed!")
            _G.RaidRunning = false
            break
        end
        FarmRaidEnemies()
        local isl = GetNextIsland()
        if isl then
            topos(isl.CFrame * CFrame.new(0, 60, 0))
        end
    end
    if elapsed >= Config.RaidTimeout then
        Notify("Raid timed out!")
    end
    _G.RaidRunning = false
    task.wait(1)
end

local function Hop()
    Notify("Server hopping...")
    task.wait(Config.HopDelay)
    pcall(function()
        if _G.Hop then
            _G.Hop()
        else
            TpSvc:Teleport(game.PlaceId, Plr)
        end
    end)
end

local function RunLoop()
    Notify("Loop started!")
    while Config.LoopEnabled do
        task.wait(2)
        refreshChar()
        local fruits = GetDroppedFruits()
        Notify("Fruits detected: " .. #fruits)
        if #fruits == 0 then
            Notify("No fruits. Hopping...")
            Hop()
        else
            while true do
                refreshChar()
                local currentFruits = GetDroppedFruits()
                if #currentFruits == 0 then
                    Notify("No more fruits. Hopping...")
                    Hop()
                    break
                end
                local fruit = currentFruits[1]
                Notify("Picking up: " .. fruit.Name)
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
                end
                refreshChar()
                task.wait(2)
            end
        end
    end
end

task.spawn(RunLoop)
