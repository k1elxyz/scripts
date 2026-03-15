-- ================================================
--   AUTO FRUIT → CHIP → FLAME RAID → HOP
--   Functions lifted directly from REDZ_HUB source
-- ================================================

local Players     = game:GetService("Players")
local RepStorage  = game:GetService("ReplicatedStorage")
local TweenSvc    = game:GetService("TweenService")
local TpSvc       = game:GetService("TeleportService")
local Workspace   = game:GetService("Workspace")

local Plr  = Players.LocalPlayer
local Char = Plr.Character or Plr.CharacterAdded:Wait()
local Root = Char:WaitForChild("HumanoidRootPart")
local CommF_ = RepStorage.Remotes.CommF_

local World2 = game.PlaceId == 4442272183 or game.PlaceId == 79091703265657
local World3 = game.PlaceId == 7449423635 or game.PlaceId == 100117331123089

-- ================================================
-- CONFIG
-- ================================================
local Config = {
    ChipType     = "Flame",
    MinFruits    = 1,      -- kahit 1 fruit, aaksyon na
    FruitRadius  = 2000,
    TweenSpeed   = 0.3,
    HopDelay     = 5,
    RaidTimeout  = 300,    -- 5 min max bago mag-timeout
    LoopEnabled  = true,
}

-- ================================================
-- UTILITY
-- ================================================

local function Notify(msg)
    print("[FruitRaid] " .. msg)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "FruitRaid", Text = msg, Duration = 4
        })
    end)
end

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

-- ================================================
-- STEP 1: DETECT DROPPED FRUITS
-- ================================================

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

-- ================================================
-- STEP 2: TWEEN + COLLECT FRUIT
-- ================================================

local function CollectFruit(fruit)
    if not fruit or not fruit:FindFirstChild("Handle") then return end
    Notify("Kinukuha: " .. fruit.Name)
    TweenTo(fruit.Handle.CFrame)
    task.wait(0.3)
    pcall(function()
        Root.CFrame = fruit.Handle.CFrame
    end)
    task.wait(0.5)
end

-- ================================================
-- STEP 3: BUY CHIP
-- CommF_:InvokeServer("RaidsNpc", "Select", chip)
-- ================================================

local function BuyChip()
    Notify("Binibili ang " .. Config.ChipType .. " chip...")

    if World2 then
        topos(CFrame.new(-6438.73, 250.64, -4501.5))
    elseif World3 then
        pcall(function()
            CommF_:InvokeServer("requestEntrance", Vector3.new(-5075.5, 314.51, -3150.02))
        end)
        topos(CFrame.new(-5017.4, 314.84, -2823.01))
    end

    task.wait(0.5)
    pcall(function()
        CommF_:InvokeServer("RaidsNpc", "Select", Config.ChipType)
    end)
    task.wait(1)
    Notify("Chip bought!")
end

-- ================================================
-- STEP 4: START RAID
-- fireclickdetector(RaidSummon2)
-- ================================================

local function StartRaid()
    -- Hintayin ang chip sa backpack/char
    local waited = 0
    repeat
        task.wait(1)
        waited = waited + 1
    until Plr.Backpack:FindFirstChild("Special Microchip")
        or Char:FindFirstChild("Special Microchip")
        or waited >= 10

    if not (Plr.Backpack:FindFirstChild("Special Microchip")
        or Char:FindFirstChild("Special Microchip")) then
        Notify("Walang Special Microchip! Skip.")
        return false
    end

    -- Hintayin na walang active raid (Timer not visible)
    local gui = Plr.PlayerGui:FindFirstChild("Main")
    if gui and gui:FindFirstChild("Timer") and gui.Timer.Visible then
        Notify("May active raid pa, naghihintay...")
        repeat task.wait(1) until not gui.Timer.Visible
    end

    if World2 then
        topos(CFrame.new(-6438.73, 250.64, -4501.5))
        pcall(function() CommF_:InvokeServer("SetSpawnPoint") end)
        pcall(function()
            fireclickdetector(Workspace.Map.CircleIsland.RaidSummon2.Button.Main.ClickDetector)
        end)
    elseif World3 then
        pcall(function()
            CommF_:InvokeServer("requestEntrance", Vector3.new(-5075.5, 314.51, -3150.02))
        end)
        topos(CFrame.new(-5017.4, 314.84, -2823.01))
        pcall(function() CommF_:InvokeServer("SetSpawnPoint") end)
        pcall(function()
            fireclickdetector(Workspace.Map["Boat Castle"].RaidSummon2.Button.Main.ClickDetector)
        end)
    end

    task.wait(1)
    Notify("Raid started!")
    return true
end

-- ================================================
-- STEP 5: COMPLETE RAID (AUTO FARM MOBS PER ISLAND)
-- FarmRaidEnemies + GetNextIsland exact from source
-- Done = Island 1 wala na sa _WorldOrigin.Locations
-- ================================================

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
    Notify("Tinatapusin ang raid...")

    local elapsed = 0
    while _G.RaidRunning and elapsed < Config.RaidTimeout do
        task.wait(0.1)
        elapsed = elapsed + 0.1

        -- Tapos na ang raid
        if not IsRaidActive() then
            Notify("Raid completed!")
            _G.RaidRunning = false
            break
        end

        -- Kill mobs sa current island
        FarmRaidEnemies()

        -- Move to next island
        local isl = GetNextIsland()
        if isl then
            topos(isl.CFrame * CFrame.new(0, 60, 0))
        end
    end

    if elapsed >= Config.RaidTimeout then
        Notify("Raid timeout! Proceeding...")
    end

    _G.RaidRunning = false
    task.wait(1)
end

-- ================================================
-- STEP 6: SERVER HOP
-- ================================================

local function Hop()
    Notify("Server hopping in " .. Config.HopDelay .. "s...")
    task.wait(Config.HopDelay)
    pcall(function()
        if _G.Hop then
            _G.Hop()
        else
            TpSvc:Teleport(game.PlaceId, Plr)
        end
    end)
end

-- ================================================
-- MAIN LOOP
-- 1 fruit na lang → collect → chip → raid → farm mobs
-- → check ulit kung may fruit → pag wala → 5s → hop
-- ================================================

local function RunLoop()
    Notify("Auto Fruit Raid Loop started!")

    while Config.LoopEnabled do
        task.wait(2)
        refreshChar()

        local fruits = GetDroppedFruits()
        Notify("Fruits detected: " .. #fruits)

        if #fruits >= 1 then

            -- Tween at kolektahin lahat ng fruits
            for _, fruit in ipairs(fruits) do
                if Char.Humanoid.Health <= 0 then
                    refreshChar()
                    task.wait(3)
                end
                CollectFruit(fruit)
            end

            -- Kunin lahat ng fruits na nasa inventory
            local fruitItems = {}
            for _, item in ipairs(Plr.Backpack:GetChildren()) do
                if string.find(item.Name, "Fruit") then
                    table.insert(fruitItems, item)
                end
            end
            for _, item in ipairs(Char:GetChildren()) do
                if string.find(item.Name, "Fruit") then
                    table.insert(fruitItems, item)
                end
            end

            Notify("Fruits sa inventory: " .. #fruitItems)

            -- Bawat fruit → chip → raid → complete
            for _, fruitItem in ipairs(fruitItems) do
                Notify("Processing: " .. fruitItem.Name)
                BuyChip()
                local started = StartRaid()
                if started then
                    CompleteRaid()
                end
                task.wait(1)
            end

            -- Pagkatapos, check kung may bagong fruit pa
            local newFruits = GetDroppedFruits()
            if #newFruits >= 1 then
                Notify("May bagong fruit! Uulitin...")
                -- Hindi mag-hop, mag-loop ulit
            else
                -- Wala na → wait 5s → hop
                Notify("Walang fruits na. Hopping in 5s...")
                task.wait(5)
                Hop()
            end

        else
            Notify("Walang fruit na detected. Naghihintay...")
        end
    end
end

-- Start
task.spawn(RunLoop)
