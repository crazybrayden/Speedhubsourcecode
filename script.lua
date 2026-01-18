-- Lavender Hub - WindUI Version (Original)
local success, WindUI = pcall(function()
    return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)

if not success then
    warn("Failed to load WindUI, trying alternative...")
    WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/main.lua"))()
end

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

-- Player
local player = Players.LocalPlayer

-- Wait for character
local character
local humanoid

-- Show loading notification
task.spawn(function()
    if WindUI and WindUI.Notify then
        WindUI:Notify({
            Title = "Lavender Hub",
            Content = "Loading... Please wait",
            Duration = 3,
            Icon = "loader"
        })
    end
end)

-- Try to get character safely
pcall(function()
    character = player.Character or player.CharacterAdded:Wait()
    humanoid = character:WaitForChild("Humanoid")
end)

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UseItemRemote = Remotes:WaitForChild("UseItem")
local MakeHoneyRemote = Remotes:WaitForChild("MakeHoney")
local UseMachineRemote = Remotes:WaitForChild("UseMachine")

-- Configuration
local GRID_SIZE = 6
local CHECK_INTERVAL = 0.2
local TOKEN_CLEAR_INTERVAL = 5
local HIVE_CHECK_INTERVAL = 10

-- Webhook Configuration
local webhookEnabled = false
local webhookURL = ""
local webhookInterval = 5 -- minutes
local lastWebhookTime = 0
local webhookCooldownActive = false

-- Script Uptime Tracking
local scriptStartTime = tick()

-- Field Coordinates
local fieldCoords = {
    ["Mushroom Field"] = Vector3.new(-896.98, 73.50, -124.88),
    ["Blueberry Field"] = Vector3.new(-752.17, 73.50, -98.35),
    ["Clover Field"] = Vector3.new(-644.85, 90.94, -87.69),
    ["Spider Field"] = Vector3.new(-902.24, 88.77, -220.61),
    ["Pineapple Field"] = Vector3.new(-612.01, 118.17, -271.24),
    ["Strawberry Field"] = Vector3.new(-844.44, 127.44, 107.52),
    ["Mountain Field"] = Vector3.new(-750.01, 175.73, -476.97),
    ["Pine Field"] = Vector3.new(-619.52, 171.32, -477.91),
    ["Watermelon Field"] = Vector3.new(-1052.50, 140.74, -152.79),
    ["Banana Field"] = Vector3.new(-1063.40, 163.61, -292.46),
    ["Cog Field"] = Vector3.new(-1051.02, 149.11, 135.28)
}

-- Hive Coordinates
local hiveCoords = {
    ["Hive_1"] = Vector3.new(-824.83, 75.37, 32.97),
    ["Hive_2"] = Vector3.new(-799.37, 75.37, 32.29),
    ["Hive_3"] = Vector3.new(-774.27, 75.37, 32.52),
    ["Hive_4"] = Vector3.new(-748.93, 75.37, 31.49),
    ["Hive_5"] = Vector3.new(-722.73, 75.37, 32.69)
}

-- Toggles and State
local toggles = {
    field = "Mushroom Field",
    movementMethod = "Tween",
    autoFarm = false,
    autoDig = false,
    autoEquip = false,
    antiLag = false,
    tweenSpeed = 70,
    walkspeedEnabled = false,
    walkspeed = 50,
    isFarming = false,
    isConverting = false,
    atField = false,
    atHive = false,
    visitedTokens = {},
    lastTokenClearTime = tick(),
    lastHiveCheckTime = tick(),
    
    lastPollenValue = 0,
    lastPollenChangeTime = 0,
    fieldArrivalTime = 0,
    hasCollectedPollen = false,
    
    isMoving = false,
    currentTarget = nil,
    
    objectsDeleted = 0,
    performanceStats = {
        fps = 0,
        memory = 0,
        ping = 0
    }
}

-- Honey tracking
local honeyStats = {
    startHoney = 0,
    currentHoney = 0,
    lastHoneyCheck = tick(),
    honeyMade = 0,
    hourlyRate = 0,
    lastHoneyValue = 0,
    trackingStarted = false,
    startTrackingTime = 0,
    firstAutoFarmEnabled = false,
    sessionHoney = 0,
    dailyHoney = 0
}

-- Auto Sprinklers System
local autoSprinklersEnabled = false
local selectedSprinkler = "Basic Sprinkler"
local sprinklerPlacementCount = 0
local lastSprinklerPlaceTime = 0
local sprinklerCooldown = 3
local currentFieldVisits = {}
local placingSprinklers = false
local sprinklersPlaced = false
local sprinklerRetryCount = 0
local MAX_SPRINKLER_RETRIES = 3
local lastFieldBeforeConvert = nil
local placedSprinklersCount = 0
local expectedSprinklerCount = 0

-- Ticket Converter System
local useTicketConverters = false
local currentConverterIndex = 1
local converterSequence = {"Instant Converter", "Instant Converter1", "Instant Converter2"}
local lastConverterUseTime = 0
local converterCooldown = 5

-- Toys/Boosters System
local mountainBoosterEnabled = false
local redBoosterEnabled = false
local blueBoosterEnabled = false
local wealthClockEnabled = false
local lastMountainBoosterTime = 0
local lastRedBoosterTime = 0
local lastBlueBoosterTime = 0
local lastWealthClockTime = 0

-- Sprinkler configurations
local sprinklerConfigs = {
    ["Broken Sprinkler"] = {
        count = 1,
        pattern = function(fieldPos)
            return {fieldPos}
        end
    },
    ["Basic Sprinkler"] = {
        count = 1,
        pattern = function(fieldPos)
            return {fieldPos}
        end
    },
    ["Silver Soakers"] = {
        count = 2,
        pattern = function(fieldPos)
            return {
                fieldPos + Vector3.new(-2, 0, 0),
                fieldPos + Vector3.new(2, 0, 0)
            }
        end
    },
    ["Golden Gushers"] = {
        count = 3,
        pattern = function(fieldPos)
            return {
                fieldPos + Vector3.new(-2, 0, 0),
                fieldPos + Vector3.new(2, 0, 0),
                fieldPos + Vector3.new(0, 0, -1.5)
            }
        end
    },
    ["Diamond Drenchers"] = {
        count = 4,
        pattern = function(fieldPos)
            return {
                fieldPos + Vector3.new(-2, 0, -2),
                fieldPos + Vector3.new(2, 0, -2),
                fieldPos + Vector3.new(-2, 0, 2),
                fieldPos + Vector3.new(2, 0, 2)
            }
        end
    },
    ["Supreme Saturator"] = {
        count = 1,
        pattern = function(fieldPos)
            return {fieldPos}
        end
    }
}

local digRunning = false

-- Console System
local consoleLogs = {}
local maxConsoleLines = 30

-- Variables for GUI elements
local Window, MainTab, FarmTab, ToysTab, WebhookTab, ConsoleTab, DebugTab
local consoleLabelElement, statusLabel, pollenLabel, hourlyHoneyLabel, sprinklerStatusLabel
local honeyMadeLabel, hourlyRateLabel, sessionHoneyLabel, dailyHoneyLabel
local fpsLabel, memoryLabel, objectsLabel
local webhookToggleElement, webhookURLElement, webhookIntervalElement

-- Function to check if GUI loaded
local function isGUILoaded()
    return Window ~= nil
end

-- Manual GUI toggle key
local guiVisible = true
local toggleKey = Enum.KeyCode.RightControl
-- Get current pollen value
local function getCurrentPollen()
    local pollenValue = player:FindFirstChild("Pollen")
    if pollenValue and pollenValue:IsA("NumberValue") then
        return pollenValue.Value
    end
    return 0
end

-- Get current honey value - FIXED
local function getCurrentHoney()
    for _, child in pairs(player:GetChildren()) do
        if child:IsA("NumberValue") then
            if child.Name:lower():find("honey") then
                return child.Value
            end
        end
    end
    return 0
end

-- Format numbers with K, M, B, T, Q
local function formatNumberCorrect(num)
    if num < 1000 then
        return tostring(math.floor(num))
    elseif num < 1000000 then
        local formatted = num / 1000
        if formatted >= 100 then
            return string.format("%.0fK", formatted)
        elseif formatted >= 10 then
            return string.format("%.1fK", formatted)
        else
            return string.format("%.2fK", formatted)
        end
    elseif num < 1000000000 then
        local formatted = num / 1000000
        if formatted >= 100 then
            return string.format("%.0fM", formatted)
        elseif formatted >= 10 then
            return string.format("%.1fM", formatted)
        else
            return string.format("%.2fM", formatted)
        end
    elseif num < 1000000000000 then
        local formatted = num / 1000000000
        if formatted >= 100 then
            return string.format("%.0fB", formatted)
        elseif formatted >= 10 then
            return string.format("%.1fB", formatted)
        else
            return string.format("%.2fB", formatted)
        end
    elseif num < 1000000000000000 then
        local formatted = num / 1000000000000
        if formatted >= 100 then
            return string.format("%.0fT", formatted)
        elseif formatted >= 10 then
            return string.format("%.1fT", formatted)
        else
            return string.format("%.2fT", formatted)
        end
    else
        local formatted = num / 1000000000000000
        if formatted >= 100 then
            return string.format("%.0fQ", formatted)
        elseif formatted >= 10 then
            return string.format("%.1fQ", formatted)
        else
            return string.format("%.2fQ", formatted)
        end
    end
end

-- Format time function for uptime
local function formatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    
    if hours > 0 then
        return string.format("%dh %dm %ds", hours, minutes, secs)
    elseif minutes > 0 then
        return string.format("%dm %ds", minutes, secs)
    else
        return string.format("%ds", secs)
    end
end

-- Console function
local function addToConsole(message)
    local timestamp = os.date("%H:%M:%S")
    local logEntry = "[" .. timestamp .. "] " .. message
    
    table.insert(consoleLogs, logEntry)
    
    if #consoleLogs > maxConsoleLines then
        table.remove(consoleLogs, 1)
    end
    
    if consoleLabelElement then
        consoleLabelElement:SetDesc(table.concat(consoleLogs, "\n"))
    end
    print("[Lavender Hub] " .. message)
end

-- Auto-Save Functions
local function saveSettings()
    local settingsToSave = {
        field = toggles.field,
        movementMethod = toggles.movementMethod,
        autoFarm = toggles.autoFarm,
        autoDig = toggles.autoDig,
        autoEquip = toggles.autoEquip,
        antiLag = toggles.antiLag,
        tweenSpeed = toggles.tweenSpeed,
        walkspeedEnabled = toggles.walkspeedEnabled,
        walkspeed = toggles.walkspeed,
        autoSprinklersEnabled = autoSprinklersEnabled,
        selectedSprinkler = selectedSprinkler,
        webhookEnabled = webhookEnabled,
        webhookURL = webhookURL,
        webhookInterval = webhookInterval,
        useTicketConverters = useTicketConverters,
        mountainBoosterEnabled = mountainBoosterEnabled,
        redBoosterEnabled = redBoosterEnabled,
        blueBoosterEnabled = blueBoosterEnabled,
        wealthClockEnabled = wealthClockEnabled
    }
    
    local success, encoded = pcall(function()
        return HttpService:JSONEncode(settingsToSave)
    end)
    
    if success then
        local writeSuccess, writeError = pcall(function()
            if writefile then
                writefile("LavenderHub_WindUI_Settings.txt", encoded)
            end
        end)
        if writeSuccess then
            addToConsole("Settings saved")
        end
    end
end

local function loadSettings()
    local fileSuccess, content = pcall(function()
        if isfile and isfile("LavenderHub_WindUI_Settings.txt") then
            return readfile("LavenderHub_WindUI_Settings.txt")
        end
        return nil
    end)
    
    if fileSuccess and content then
        local decodeSuccess, decoded = pcall(function()
            return HttpService:JSONDecode(content)
        end)
        
        if decodeSuccess and decoded then
            toggles.field = decoded.field or toggles.field
            toggles.movementMethod = decoded.movementMethod or toggles.movementMethod
            toggles.autoFarm = decoded.autoFarm or toggles.autoFarm
            toggles.autoDig = decoded.autoDig or toggles.autoDig
            toggles.autoEquip = decoded.autoEquip or toggles.autoEquip
            toggles.antiLag = decoded.antiLag or toggles.antiLag
            toggles.tweenSpeed = decoded.tweenSpeed or toggles.tweenSpeed
            toggles.walkspeedEnabled = decoded.walkspeedEnabled or toggles.walkspeedEnabled
            toggles.walkspeed = decoded.walkspeed or toggles.walkspeed
            autoSprinklersEnabled = decoded.autoSprinklersEnabled or autoSprinklersEnabled
            selectedSprinkler = decoded.selectedSprinkler or selectedSprinkler
            webhookEnabled = decoded.webhookEnabled or webhookEnabled
            webhookURL = decoded.webhookURL or webhookURL
            webhookInterval = decoded.webhookInterval or webhookInterval
            useTicketConverters = decoded.useTicketConverters or useTicketConverters
            mountainBoosterEnabled = decoded.mountainBoosterEnabled or mountainBoosterEnabled
            redBoosterEnabled = decoded.redBoosterEnabled or redBoosterEnabled
            blueBoosterEnabled = decoded.blueBoosterEnabled or blueBoosterEnabled
            wealthClockEnabled = decoded.wealthClockEnabled or wealthClockEnabled
            addToConsole("Settings loaded")
            return true
        end
    end
    addToConsole("No saved settings")
    return false
end

-- Toys/Boosters Functions - FIXED
local function useMountainBooster()
    local args = {
        "Mountain Booster",
        0
    }
    UseMachineRemote:FireServer(unpack(args))
    lastMountainBoosterTime = tick()
    addToConsole("🏔️ Mountain Booster used")
end

local function useRedBooster()
    local args = {
        "Red Booster",
        0
    }
    UseMachineRemote:FireServer(unpack(args))
    lastRedBoosterTime = tick()
    addToConsole("🔴 Red Booster used")
end

local function useBlueBooster()
    local args = {
        "Blue Booster",
        0
    }
    UseMachineRemote:FireServer(unpack(args))
    lastBlueBoosterTime = tick()
    addToConsole("🔵 Blue Booster used")
end

local function useWealthClock()
    local args = {
        "Ticket Dispenser",
        22
    }
    UseMachineRemote:FireServer(unpack(args))
    lastWealthClockTime = tick()
    addToConsole("⏰ Wealth Clock used")
end

-- Ticket Converter Functions - FIXED
local function useTicketConverter()
    if not useTicketConverters then return false end
    if tick() - lastConverterUseTime < converterCooldown then return false end
    
    local converterName = converterSequence[currentConverterIndex]
    local args = {
        converterName,
        0
    }
    
    local success = pcall(function()
        UseMachineRemote:FireServer(unpack(args))
        return true
    end)
    
    if success then
        addToConsole("🎫 Used " .. converterName)
        lastConverterUseTime = tick()
        
        currentConverterIndex = currentConverterIndex + 1
        if currentConverterIndex > #converterSequence then
            currentConverterIndex = 1
        end
        return true
    end
    
    return false
end

-- Auto Toys Loop
local function updateToys()
    local currentTime = tick()
    
    if mountainBoosterEnabled and currentTime - lastMountainBoosterTime >= 1800 then
        useMountainBooster()
    end
    
    if redBoosterEnabled and currentTime - lastRedBoosterTime >= 1800 then
        useRedBooster()
    end
    
    if blueBoosterEnabled and currentTime - lastBlueBoosterTime >= 1800 then
        useBlueBooster()
    end
    
    if wealthClockEnabled and currentTime - lastWealthClockTime >= 3600 then
        useWealthClock()
    end
end
-- Simple Anti-Lag System
local function runAntiLag()
    if not toggles.antiLag then return end
    
    local targets = {
        "mango", "strawberry", "fence", "blueberry", "pear",
        "apple", "orange", "banana", "grape", "pineapple",
        "watermelon", "lemon", "lime", "cherry", "peach",
        "plum", "kiwi", "coconut", "avocado", "raspberry",
        "blackberry", "pomegranate", "fig", "apricot", "melon",
        "fruit", "fruits", "berry", "berries",
        "daisy", "cactus", "forrest", "bamboo",
        "leader", "cave", "crystal"
    }

    local deleted = 0
    for _, obj in pairs(Workspace:GetDescendants()) do
        if toggles.antiLag then
            local name = obj.Name:lower()
            for _, target in pairs(targets) do
                if name:find(target) then
                    pcall(function()
                        obj:Destroy()
                        deleted = deleted + 1
                    end)
                    break
                end
            end
        else
            break
        end
    end

    toggles.objectsDeleted = toggles.objectsDeleted + deleted
    addToConsole("🌿 Deleted " .. deleted .. " laggy objects")
end

-- Performance Monitoring
local function updatePerformanceStats()
    toggles.performanceStats.fps = math.floor(1 / RunService.RenderStepped:Wait())
    
    local stats = game:GetService("Stats")
    local memory = stats:FindFirstChild("Workspace") and stats.Workspace:FindFirstChild("Memory")
    if memory then
        toggles.performanceStats.memory = math.floor(memory:GetValue() / 1024 / 1024)
    end
    
    if fpsLabel then 
        fpsLabel:SetTitle("FPS: " .. toggles.performanceStats.fps)
        fpsLabel:SetDesc("Frames per second")
    end
    if memoryLabel then 
        memoryLabel:SetTitle("Memory: " .. toggles.performanceStats.memory .. " MB")
        memoryLabel:SetDesc("Memory usage")
    end
    if objectsLabel then 
        objectsLabel:SetTitle("Objects Deleted: " .. toggles.objectsDeleted)
        objectsLabel:SetDesc("Anti-lag objects deleted")
    end
end

-- Utility Functions
local function GetCharacter()
    return player.Character or player.CharacterAdded:Wait()
end

local function SafeCall(func, name)
    local success, err = pcall(func)
    if not success then
        addToConsole("Error in " .. (name or "unknown") .. ": " .. err)
    end
    return success
end

-- Update honey statistics
local function updateHoneyStats()
    local currentHoney = getCurrentHoney()
    
    if toggles.autoFarm and not honeyStats.firstAutoFarmEnabled then
        honeyStats.firstAutoFarmEnabled = true
        honeyStats.trackingStarted = true
        honeyStats.startTrackingTime = tick()
        honeyStats.startHoney = currentHoney
        honeyStats.currentHoney = currentHoney
        honeyStats.lastHoneyValue = currentHoney
        honeyStats.honeyMade = 0
        honeyStats.hourlyRate = 0
        honeyStats.sessionHoney = 0
        honeyStats.dailyHoney = 0
        honeyStats.lastHoneyCheck = tick()
        addToConsole("📊 Honey tracking started")
        return
    end
    
    if not honeyStats.trackingStarted then
        honeyStats.lastHoneyValue = currentHoney
        return
    end
    
    if currentHoney > honeyStats.lastHoneyValue then
        local honeyGained = currentHoney - honeyStats.lastHoneyValue
        honeyStats.honeyMade = honeyStats.honeyMade + honeyGained
        honeyStats.sessionHoney = honeyStats.sessionHoney + honeyGained
        honeyStats.dailyHoney = honeyStats.dailyHoney + honeyGained
        honeyStats.currentHoney = currentHoney
        honeyStats.lastHoneyValue = currentHoney
        
        local timeElapsed = (tick() - honeyStats.startTrackingTime) / 3600
        if timeElapsed > 0 then
            honeyStats.hourlyRate = honeyStats.honeyMade / timeElapsed
        end
    elseif currentHoney < honeyStats.lastHoneyValue then
        honeyStats.lastHoneyValue = currentHoney
    end
end

-- Auto-detect owned hive
local function getOwnedHive()
    local hiveObject = player:FindFirstChild("Hive")
    if hiveObject and hiveObject:IsA("ObjectValue") and hiveObject.Value then
        local hiveName = hiveObject.Value.Name
        if hiveCoords[hiveName] then
            return hiveName
        end
    end
    return nil
end

local ownedHive = getOwnedHive()
local displayHiveName = ownedHive and "Hive" or "None"

-- Periodic hive checking function
local function checkHiveOwnership()
    if tick() - toggles.lastHiveCheckTime >= HIVE_CHECK_INTERVAL then
        local previousHive = ownedHive
        ownedHive = getOwnedHive()
        
        if ownedHive and ownedHive ~= previousHive then
            addToConsole("New hive: " .. ownedHive)
            displayHiveName = "Hive"
        elseif not ownedHive and previousHive then
            addToConsole("Hive lost")
            displayHiveName = "None"
        elseif ownedHive and previousHive == nil then
            addToConsole("Hive acquired: " .. ownedHive)
            displayHiveName = "Hive"
        end
        
        toggles.lastHiveCheckTime = tick()
    end
end

-- Get character safely
local function getCharacterSafe()
    return player.Character or player.CharacterAdded:Wait()
end

-- Smooth Tween Movement System - FIXED
local function smoothTweenToPosition(targetPos)
    local character = getCharacterSafe()
    local humanoid = character:WaitForChild("Humanoid")
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    if not humanoid or not humanoidRootPart then return false end

    local SPEED = toggles.tweenSpeed
    local TARGET_HEIGHT = 3
    
    local startPos = humanoidRootPart.Position
    local adjustedTargetPos = Vector3.new(
        targetPos.X,
        targetPos.Y + TARGET_HEIGHT,
        targetPos.Z
    )
    
    local distance = (startPos - adjustedTargetPos).Magnitude
    local duration = distance / SPEED
    
    humanoid:ChangeState(Enum.HumanoidStateType.Flying)
    humanoid.AutoRotate = false
    
    local tweenInfo = TweenInfo.new(
        duration,
        Enum.EasingStyle.Linear,
        Enum.EasingDirection.Out,
        0,
        false,
        0
    )
    
    local tween = TweenService:Create(humanoidRootPart, tweenInfo, {
        CFrame = CFrame.new(adjustedTargetPos)
    })
    
    tween:Play()
    
    local success = true
    local startTime = tick()
    
    while tick() - startTime < duration + 2 do
        if not humanoidRootPart or not humanoidRootPart.Parent then
            success = false
            break
        end
        task.wait(0.1)
    end
    
    if humanoidRootPart then
        humanoid.AutoRotate = true
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end
    
    return success
end

-- Improved Walk Movement with Pathfinding - SIMPLIFIED
local function moveToPositionWalk(targetPos)
    local character = getCharacterSafe()
    local humanoid = character:WaitForChild("Humanoid")
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    if not humanoid or not humanoidRootPart then return false end
    
    humanoid:MoveTo(targetPos)
    
    local startTime = tick()
    while (humanoidRootPart.Position - targetPos).Magnitude > 10 do
        if tick() - startTime > 20 then
            return false
        end
        
        if tick() - startTime > 5 then
            humanoid.Jump = true
        end
        
        task.wait(0.1)
    end
    
    return true
end

-- Main Movement Function
local function moveToPosition(targetPos)
    toggles.isMoving = true
    
    local success = false
    if toggles.movementMethod == "Tween" then
        success = smoothTweenToPosition(targetPos)
    else
        success = moveToPositionWalk(targetPos)
    end
    
    toggles.isMoving = false
    return success
end

-- Optimized Movement Functions
local function getRandomPositionInField()
    local fieldPos = fieldCoords[toggles.field]
    if not fieldPos then return nil end
    
    local fieldRadius = 25
    local randomX = fieldPos.X + math.random(-fieldRadius, fieldRadius)
    local randomZ = fieldPos.Z + math.random(-fieldRadius, fieldRadius)
    local randomY = fieldPos.Y
    
    return Vector3.new(randomX, randomY, randomZ)
end

local function performContinuousMovement()
    if not toggles.atField or toggles.isConverting or toggles.isMoving then return end
    
    local randomPos = getRandomPositionInField()
    if randomPos then
        toggles.isMoving = true
        toggles.currentTarget = randomPos
        
        local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid:MoveTo(randomPos)
            task.spawn(function()
                task.wait(2)
                toggles.isMoving = false
                toggles.currentTarget = nil
            end)
        else
            toggles.isMoving = false
            toggles.currentTarget = nil
        end
    end
end
-- Auto Sprinklers Functions - FIXED
local function getFieldFlowerPart(fieldName)
    local fieldsFolder = Workspace:FindFirstChild("Fields")
    if not fieldsFolder then return nil end
    
    local field = fieldsFolder:FindFirstChild(fieldName)
    if field then
        return field:FindFirstChild("FlowerPart")
    end
    return nil
end

local function useSprinklerRemote(fieldName)
    local flowerPart = getFieldFlowerPart(fieldName)
    if not flowerPart then
        addToConsole("❌ Could not find FlowerPart for " .. fieldName)
        return false
    end
    
    local args = {
        "Sprinkler",
        flowerPart
    }
    
    local success = pcall(function()
        UseItemRemote:FireServer(unpack(args))
        return true
    end)
    
    if success then
        addToConsole("✅ Placed sprinkler at " .. fieldName)
        return true
    else
        addToConsole("❌ Failed to place sprinkler")
        return false
    end
end

local function getPlacedSprinklersCount()
    local placedCount = 0
    local character = getCharacterSafe()
    
    if character then
        for _, tool in pairs(character:GetChildren()) do
            if tool:IsA("Tool") and string.find(tool.Name:lower(), "sprinkler") then
                placedCount = placedCount + 1
            end
        end
    end
    
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and string.find(tool.Name:lower(), "sprinkler") then
                placedCount = placedCount + 1
            end
        end
    end
    
    return placedCount
end

local function placeSprinklers()
    if not autoSprinklersEnabled then return end
    if not toggles.autoFarm then return end
    if toggles.isConverting then return end
    if placingSprinklers then return end
    if not toggles.atField then return end
    
    if lastFieldBeforeConvert == toggles.field then
        sprinklersPlaced = true
        return
    end
    
    local currentTime = tick()
    if currentTime - lastSprinklerPlaceTime < sprinklerCooldown then return end
    
    placingSprinklers = true
    
    local config = sprinklerConfigs[selectedSprinkler]
    if not config then
        placingSprinklers = false
        return
    end
    
    expectedSprinklerCount = config.count
    local currentPlacedCount = getPlacedSprinklersCount()
    placedSprinklersCount = currentPlacedCount
    
    if currentPlacedCount >= expectedSprinklerCount then
        sprinklersPlaced = true
        placingSprinklers = false
        return
    end
    
    if not currentFieldVisits[toggles.field] then
        currentFieldVisits[toggles.field] = 0
    end
    currentFieldVisits[toggles.field] = currentFieldVisits[toggles.field] + 1
    
    local fieldPos = fieldCoords[toggles.field]
    if not fieldPos then
        placingSprinklers = false
        return
    end
    
    local positions = config.pattern(fieldPos)
    local successfulPlacements = 0
    
    for i, position in ipairs(positions) do
        if i > config.count then break end
        
        if getPlacedSprinklersCount() >= expectedSprinklerCount then
            break
        end
        
        if moveToPosition(position) then
            task.wait(0.8)
            
            local placed = false
            for retry = 1, 2 do
                if useSprinklerRemote(toggles.field) then
                    sprinklerPlacementCount = sprinklerPlacementCount + 1
                    successfulPlacements = successfulPlacements + 1
                    placed = true
                    break
                else
                    task.wait(0.5)
                end
            end
            
            task.wait(0.5)
        end
    end
    
    placedSprinklersCount = getPlacedSprinklersCount()
    
    if successfulPlacements > 0 or placedSprinklersCount >= expectedSprinklerCount then
        sprinklersPlaced = true
        sprinklerRetryCount = 0
    else
        sprinklerRetryCount = sprinklerRetryCount + 1
        
        if sprinklerRetryCount >= MAX_SPRINKLER_RETRIES then
            resetSprinklers()
            sprinklerRetryCount = 0
        end
    end
    
    lastSprinklerPlaceTime = currentTime
    placingSprinklers = false
end

local function resetSprinklers()
    sprinklersPlaced = false
    sprinklerRetryCount = 0
    
    if currentFieldVisits[toggles.field] then
        currentFieldVisits[toggles.field] = 0
    end
end

local function changeFieldWhileFarming(newField)
    if not toggles.autoFarm or not toggles.isFarming then return end
    
    local newFieldPos = fieldCoords[newField]
    if not newFieldPos then return end
    
    addToConsole("🔄 Changing field to: " .. newField)
    
    if autoSprinklersEnabled then
        for i = 1, 2 do
            useSprinklerRemote(toggles.field)
            task.wait(0.3)
        end
    end
    
    resetSprinklers()
    
    if moveToPosition(newFieldPos) then
        toggles.field = newField
        toggles.atField = true
        local initialPollen = getCurrentPollen()
        toggles.lastPollenValue = initialPollen
        toggles.lastPollenChangeTime = tick()
        toggles.fieldArrivalTime = tick()
        toggles.hasCollectedPollen = (initialPollen > 0)
        
        task.wait(1)
        
        if autoSprinklersEnabled then
            placeSprinklers()
        end
        
        addToConsole("✅ Arrived at new field")
    else
        addToConsole("❌ Failed to reach new field")
    end
end

-- Death respawn system
local function onCharacterDeath()
    if toggles.autoFarm and toggles.isFarming then
        addToConsole("💀 Character died - respawning to field...")
        
        task.wait(3)
        
        local character = getCharacterSafe()
        if character then
            task.wait(2)
            
            resetSprinklers()
            
            local fieldPos = fieldCoords[toggles.field]
            if fieldPos then
                addToConsole("🔄 Respawning to field")
                if moveToPosition(fieldPos) then
                    toggles.atField = true
                    addToConsole("✅ Respawned to field successfully")
                    
                    if autoSprinklersEnabled then
                        task.wait(1)
                        for i = 1, 2 do
                            if useSprinklerRemote(toggles.field) then
                                sprinklerPlacementCount = sprinklerPlacementCount + 1
                            end
                            task.wait(0.5)
                        end
                        sprinklersPlaced = true
                    end
                else
                    addToConsole("❌ Failed to respawn to field")
                end
            end
        end
    end
end

local function setupDeathDetection()
    local character = getCharacterSafe()
    local humanoid = character:FindFirstChild("Humanoid")
    
    if humanoid then
        humanoid.Died:Connect(onCharacterDeath)
    end
    
    player.CharacterAdded:Connect(function(newCharacter)
        task.wait(1)
        local newHumanoid = newCharacter:FindFirstChild("Humanoid")
        if newHumanoid then
            newHumanoid.Died:Connect(onCharacterDeath)
        end
    end)
end

-- Auto Equip Tools Function
local function equipAllTools()
    local character = getCharacterSafe()
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return end
    
    for _, tool in pairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            humanoid:EquipTool(tool)
            task.wait(0.05)
        end
    end
end

local lastEquipTime = 0
local function autoEquipTools()
    if not toggles.autoEquip then return end
    if tick() - lastEquipTime < 10 then return end
    
    equipAllTools()
    lastEquipTime = tick()
end

-- Auto-dig function - FIXED
local function DigLoop()
    if digRunning then return end
    digRunning = true
    
    while toggles.autoDig and toggles.atField and not toggles.isConverting do
        SafeCall(function()
            local char = getCharacterSafe()
            local toolsFired = 0
            
            for _, tool in pairs(char:GetChildren()) do
                if toolsFired >= 3 then break end
                if tool:IsA("Tool") then
                    local remote = tool:FindFirstChild("ToolRemote") or tool:FindFirstChild("Remote")
                    if remote then
                        remote:FireServer()
                        toolsFired = toolsFired + 1
                        task.wait(0.1)
                    end
                end
            end
        end, "DigLoop")
        task.wait(0.3)
    end
    
    digRunning = false
end

-- Token Collection - ORIGINAL VERSION (No Token Link priority)
local isCollectingToken = false

local function getNearestToken()
    local tokensFolder = Workspace:FindFirstChild("Debris")
    if tokensFolder then
        tokensFolder = tokensFolder:FindFirstChild("Tokens")
    end
    
    if not tokensFolder then return nil end

    for _, token in pairs(tokensFolder:GetChildren()) do
        if token:IsA("BasePart") and token:FindFirstChild("Token") then
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local distance = (token.Position - char.HumanoidRootPart.Position).Magnitude
                if distance <= 30 and not toggles.visitedTokens[token] then
                    return token, distance
                end
            end
        end
    end
    return nil
end

local function areTokensNearby()
    local token = getNearestToken()
    return token ~= nil
end

local function collectTokens()
    if not toggles.autoFarm or toggles.isConverting or not toggles.atField or isCollectingToken then return end
    
    local token = getNearestToken()
    if token then
        isCollectingToken = true
        local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid:MoveTo(token.Position)
            local startTime = tick()
            local char = player.Character
            while char and char:FindFirstChild("HumanoidRootPart") and 
                  (char.HumanoidRootPart.Position - token.Position).Magnitude > 4 and 
                  tick() - startTime < 3 do
                if not token.Parent then break end
                task.wait()
            end
            if token.Parent then
                toggles.visitedTokens[token] = true
            end
        end
        isCollectingToken = false
    end
end
-- Pollen Tracking
local function updatePollenTracking()
    if not toggles.atField then return end
    
    local currentPollen = getCurrentPollen()
    
    if currentPollen > 0 and not toggles.hasCollectedPollen then
        toggles.hasCollectedPollen = true
    end
    
    if currentPollen ~= toggles.lastPollenValue then
        toggles.lastPollenValue = currentPollen
        toggles.lastPollenChangeTime = tick()
    end
end

local function shouldConvertToHive()
    if not toggles.isFarming or not toggles.atField or not ownedHive then return false end
    
    local currentPollen = getCurrentPollen()
    local timeSinceLastChange = tick() - toggles.lastPollenChangeTime
    
    return toggles.hasCollectedPollen and (timeSinceLastChange >= 8 or currentPollen == 0)
end

local function shouldReturnToField()
    if not toggles.isConverting or not toggles.atHive then return false end
    
    local currentPollen = getCurrentPollen()
    return currentPollen == 0
end

-- Improved converting with ticket converters
local function startConverting()
    if toggles.isConverting or not ownedHive then return end
    
    lastFieldBeforeConvert = toggles.field
    
    local hivePos = hiveCoords[ownedHive]
    if not hivePos then return end
    
    toggles.isFarming = false
    toggles.isConverting = true
    toggles.atField = false
    toggles.atHive = false
    toggles.isMoving = false
    
    addToConsole("Moving to hive")
    
    if moveToPosition(hivePos) then
        toggles.atHive = true
        addToConsole("✅ At hive")
        
        task.wait(2)
        
        if useTicketConverters then
            addToConsole("🎫 Using ticket converters...")
            local converterUsed = false
            
            for i = 1, #converterSequence do
                if useTicketConverter() then
                    converterUsed = true
                    task.wait(1)
                    
                    local pollenAfterConvert = getCurrentPollen()
                    if pollenAfterConvert == 0 then
                        addToConsole("✅ Successfully converted with ticket converter")
                        break
                    else
                        addToConsole("🔄 Converter didn't work, trying next...")
                    end
                end
                task.wait(0.5)
            end
            
            if not converterUsed or getCurrentPollen() > 0 then
                addToConsole("🍯 Converting honey normally")
                local args = {true}
                MakeHoneyRemote:FireServer(unpack(args))
            end
        else
            addToConsole("🍯 Converting honey")
            local args = {true}
            MakeHoneyRemote:FireServer(unpack(args))
        end
    else
        toggles.isConverting = false
        addToConsole("❌ Failed to reach hive")
    end
end

-- Farming Logic
local function startFarming()
    if not toggles.autoFarm or toggles.isFarming or not ownedHive then return end
    
    local fieldPos = fieldCoords[toggles.field]
    if not fieldPos then return end
    
    toggles.isFarming = true
    toggles.isConverting = false
    toggles.atField = false
    toggles.atHive = false
    toggles.isMoving = false
    
    toggles.lastPollenValue = getCurrentPollen()
    toggles.lastPollenChangeTime = tick()
    toggles.fieldArrivalTime = tick()
    toggles.hasCollectedPollen = false
    
    addToConsole("Moving to: " .. toggles.field)
    
    if moveToPosition(fieldPos) then
        toggles.atField = true
        local initialPollen = getCurrentPollen()
        toggles.lastPollenValue = initialPollen
        toggles.lastPollenChangeTime = tick()
        toggles.fieldArrivalTime = tick()
        toggles.hasCollectedPollen = (initialPollen > 0)
        
        addToConsole("✅ Arrived at field")
        
        if autoSprinklersEnabled then
            task.wait(1)
            placeSprinklers()
        end
        
        if toggles.autoDig then
            task.spawn(DigLoop)
        end
    else
        toggles.isFarming = false
        addToConsole("❌ Failed to reach field")
    end
end

-- Main Loop
local lastUpdateTime = 0
local function updateFarmState()
    if not toggles.autoFarm then return end
    
    local currentTime = tick()
    if currentTime - lastUpdateTime < CHECK_INTERVAL then return end
    lastUpdateTime = currentTime
    
    checkHiveOwnership()
    updatePollenTracking()
    
    if toggles.isFarming and toggles.atField then
        if shouldConvertToHive() then
            addToConsole("Converting to honey")
            startConverting()
        else
            if areTokensNearby() then
                collectTokens()
            elseif not toggles.isMoving then
                performContinuousMovement()
            end
        end
        
    elseif toggles.isConverting and toggles.atHive then
        if shouldReturnToField() then
            addToConsole("Returning to field")
            resetSprinklers()
            startFarming()
        end
    end
end

-- Walkspeed Management
local function updateWalkspeed()
    if not toggles.walkspeedEnabled then return end
    local character = getCharacterSafe()
    local humanoid = character and character:FindFirstChild("Humanoid")
    if humanoid then 
        humanoid.WalkSpeed = toggles.walkspeed 
    end
end

-- Token Management
local function clearVisitedTokens()
    if tick() - toggles.lastTokenClearTime >= TOKEN_CLEAR_INTERVAL then
        toggles.visitedTokens = {}
        toggles.lastTokenClearTime = tick()
    end
end

-- Webhook System
local function sendWebhook()
    if not webhookEnabled or webhookURL == "" then return end
    
    local currentTime = tick()
    
    if webhookCooldownActive then
        if currentTime - lastWebhookTime >= (webhookInterval * 60) then
            webhookCooldownActive = false
        else
            return
        end
    end
    
    if currentTime - lastWebhookTime < (webhookInterval * 60) then return end
    
    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or request
    if not requestFunc then
        addToConsole("❌ No HTTP request function available")
        return
    end
    
    local currentHoney = getCurrentHoney()
    local currentPollen = getCurrentPollen()
    local scriptUptime = tick() - scriptStartTime
    
    local embed = {
        title = "Lavender Hub Stats",
        color = 0x9B59B6,
        fields = {
            {
                name = "Player",
                value = player.Name,
                inline = true
            },
            {
                name = "Current Honey",
                value = formatNumberCorrect(currentHoney),
                inline = true
            },
            {
                name = "Current Pollen",
                value = formatNumberCorrect(currentPollen),
                inline = true
            },
            {
                name = "Session Honey",
                value = formatNumberCorrect(honeyStats.sessionHoney),
                inline = true
            },
            {
                name = "Daily Honey",
                value = formatNumberCorrect(honeyStats.dailyHoney),
                inline = true
            },
            {
                name = "Hourly Honey Rate",
                value = formatNumberCorrect(honeyStats.hourlyRate) .. "/h",
                inline = true
            },
            {
                name = "Script Uptime",
                value = formatTime(scriptUptime),
                inline = true
            },
            {
                name = "Field",
                value = toggles.field,
                inline = true
            },
            {
                name = "Status",
                value = toggles.isFarming and "Farming" or toggles.isConverting and "Converting" or "Idle",
                inline = true
            }
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        footer = {
            text = "Lavender Hub • " .. os.date("%H:%M:%S")
        }
    }
    
    local payload = {
        username = "Lavender Hub",
        embeds = {embed}
    }
    
    webhookCooldownActive = true
    lastWebhookTime = currentTime
    
    local success, result = pcall(function()
        local response = requestFunc({
            Url = webhookURL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(payload)
        })
        return response
    end)
    
    if success then
        addToConsole("✅ Webhook sent successfully")
    else
        addToConsole("❌ Failed to send webhook: " .. tostring(result))
        webhookCooldownActive = false
    end
end

-- Update Status Labels
local function updateStatusLabels()
    local currentPollen = getCurrentPollen()
    local currentHoney = getCurrentHoney()
    
    local statusText = "Idle"
    if toggles.autoFarm then
        if toggles.isFarming and toggles.atField then
            statusText = "Farming"
        elseif toggles.isConverting and toggles.atHive then
            statusText = "Converting"
        elseif toggles.isFarming then
            statusText = "Moving to Field"
        elseif toggles.isConverting then
            statusText = "Moving to Hive"
        end
    end
    
    if statusLabel then 
        statusLabel:SetTitle("Status: " .. statusText)
        statusLabel:SetDesc("Current activity status")
    end
    if pollenLabel then 
        pollenLabel:SetTitle("Pollen: " .. formatNumberCorrect(currentPollen))
        pollenLabel:SetDesc("Current pollen count")
    end
    if hourlyHoneyLabel then 
        hourlyHoneyLabel:SetTitle("Hourly Honey: " .. formatNumberCorrect(honeyStats.hourlyRate))
        hourlyHoneyLabel:SetDesc("Honey per hour rate")
    end
    if sprinklerStatusLabel then 
        sprinklerStatusLabel:SetTitle("Sprinklers: " .. placedSprinklersCount .. "/" .. expectedSprinklerCount .. " placed")
        sprinklerStatusLabel:SetDesc("Sprinkler placement status")
    end
    
    -- Update debug labels
    if honeyMadeLabel then 
        honeyMadeLabel:SetTitle("Honey Made: " .. formatNumberCorrect(honeyStats.honeyMade))
        honeyMadeLabel:SetDesc("Total honey made")
    end
    if hourlyRateLabel then 
        hourlyRateLabel:SetTitle("Hourly Rate: " .. formatNumberCorrect(honeyStats.hourlyRate))
        hourlyRateLabel:SetDesc("Honey per hour rate")
    end
    if sessionHoneyLabel then 
        sessionHoneyLabel:SetTitle("Session Honey: " .. formatNumberCorrect(honeyStats.sessionHoney))
        sessionHoneyLabel:SetDesc("This session's honey")
    end
    if dailyHoneyLabel then 
        dailyHoneyLabel:SetTitle("Daily Honey: " .. formatNumberCorrect(honeyStats.dailyHoney))
        dailyHoneyLabel:SetDesc("Today's honey")
    end
end
-- Create WindUI Window
Window = WindUI:CreateWindow({
    Title = "Lavender Hub",
    Icon = "flower",
    Author = "by WindUI Conversion",
    Folder = "LavenderHub",
    Size = UDim2.fromOffset(580, 460),
    Theme = "Dark",
    Resizable = true,
    Transparent = true,
    HideSearchBar = true
})

-- Create Tabs
MainTab = Window:Tab({
    Title = "Home",
    Icon = "home"
})

FarmTab = Window:Tab({
    Title = "Farming",
    Icon = "shovel"
})

ToysTab = Window:Tab({
    Title = "Toys",
    Icon = "gift"
})

WebhookTab = Window:Tab({
    Title = "Webhook",
    Icon = "globe"
})

ConsoleTab = Window:Tab({
    Title = "Console",
    Icon = "terminal"
})

DebugTab = Window:Tab({
    Title = "Debug",
    Icon = "bug"
})

-- Select Main Tab
MainTab:Select()

-- Home Tab - Stats Section
local HomeSection = MainTab:Section({
    Title = "Statistics",
    Opened = true
})

local homeStatsElement = HomeSection:Paragraph({
    Title = "Lavender Hub Stats",
    Desc = "Loading...",
    Locked = false
})

-- Farming Tab Sections
local FarmingSection = FarmTab:Section({
    Title = "Farming Settings",
    Opened = true
})

-- Field Dropdown
local fieldDropdown = FarmingSection:Dropdown({
    Title = "Field",
    Desc = "Select field to farm",
    Values = {"Mushroom Field", "Blueberry Field", "Clover Field", "Spider Field", "Pineapple Field", "Strawberry Field", "Mountain Field", "Pine Field", "Watermelon Field", "Banana Field", "Cog Field"},
    Value = toggles.field,
    Callback = function(Value)
        local oldField = toggles.field
        toggles.field = Value
        saveSettings()
        
        if toggles.autoFarm and toggles.isFarming and oldField ~= Value then
            changeFieldWhileFarming(Value)
        end
    end
})

-- Auto Farm Toggle
local autoFarmToggle
autoFarmToggle = FarmingSection:Toggle({
    Title = "Auto Farm",
    Desc = "Start automatic farming",
    Value = toggles.autoFarm,
    Callback = function(Value)
        toggles.autoFarm = Value
        saveSettings()
        if Value then
            startFarming()
        else
            toggles.isFarming = false
            toggles.isConverting = false
            toggles.atField = false
            toggles.atHive = false
            toggles.isMoving = false
        end
    end
})

-- Auto Dig Toggle
local autoDigToggle
autoDigToggle = FarmingSection:Toggle({
    Title = "Auto Dig",
    Desc = "Automatically dig while farming",
    Value = toggles.autoDig,
    Callback = function(Value)
        toggles.autoDig = Value
        saveSettings()
    end
})

-- Auto Equip Toggle
local autoEquipToggle
autoEquipToggle = FarmingSection:Toggle({
    Title = "Auto Equip Tools",
    Desc = "Automatically equip tools",
    Value = toggles.autoEquip,
    Callback = function(Value)
        toggles.autoEquip = Value
        saveSettings()
        if Value then
            addToConsole("Auto Equip Tools enabled")
            equipAllTools()
        else
            addToConsole("Auto Equip Tools disabled")
        end
    end
})

-- Ticket Converters Toggle
local ticketConvertersToggle
ticketConvertersToggle = FarmingSection:Toggle({
    Title = "Use Ticket Converters",
    Desc = "Use ticket converters at hive",
    Value = useTicketConverters,
    Callback = function(Value)
        useTicketConverters = Value
        saveSettings()
        if Value then
            addToConsole("🎫 Ticket Converters enabled")
        else
            addToConsole("🎫 Ticket Converters disabled")
        end
    end
})

-- Auto Sprinklers Toggle
local autoSprinklersToggle
autoSprinklersToggle = FarmingSection:Toggle({
    Title = "Auto Sprinklers",
    Desc = "Automatically place sprinklers",
    Value = autoSprinklersEnabled,
    Callback = function(Value)
        autoSprinklersEnabled = Value
        saveSettings()
        if Value then
            addToConsole("🚿 Auto Sprinklers enabled")
            sprinklerPlacementCount = 0
            sprinklerRetryCount = 0
            currentFieldVisits = {}
            resetSprinklers()
        else
            addToConsole("🚿 Auto Sprinklers disabled")
        end
    end
})

-- Sprinkler Type Dropdown
local sprinklerTypeDropdown
sprinklerTypeDropdown = FarmingSection:Dropdown({
    Title = "Sprinkler Type",
    Desc = "Select sprinkler type",
    Values = {"Broken Sprinkler", "Basic Sprinkler", "Silver Soakers", "Golden Gushers", "Diamond Drenchers", "Supreme Saturator"},
    Value = selectedSprinkler,
    Callback = function(Value)
        selectedSprinkler = Value
        saveSettings()
        addToConsole("🚿 Sprinkler type set to: " .. Value)
        resetSprinklers()
    end
})

-- Movement Settings Section
local MovementSection = FarmTab:Section({
    Title = "Movement Settings",
    Opened = true
})

-- Movement Method Dropdown
local movementMethodDropdown
movementMethodDropdown = MovementSection:Dropdown({
    Title = "Movement Method",
    Desc = "Select movement method",
    Values = {"Walk", "Tween"},
    Value = toggles.movementMethod,
    Callback = function(Value)
        toggles.movementMethod = Value
        saveSettings()
    end
})

-- Tween Speed Slider
local tweenSpeedSlider
tweenSpeedSlider = MovementSection:Slider({
    Title = "Tween Speed",
    Desc = "Tween movement speed",
    Step = 1,
    Value = {
        Min = 30,
        Max = 150,
        Default = toggles.tweenSpeed
    },
    Callback = function(value)
        toggles.tweenSpeed = value
        saveSettings()
    end
})

-- Player Settings Section
local PlayerSection = FarmTab:Section({
    Title = "Player Settings",
    Opened = true
})

-- Walkspeed Toggle
local walkspeedToggle
walkspeedToggle = PlayerSection:Toggle({
    Title = "Walkspeed",
    Desc = "Enable custom walkspeed",
    Value = toggles.walkspeedEnabled,
    Callback = function(Value)
        toggles.walkspeedEnabled = Value
        saveSettings()
        if not Value and player.Character then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid then humanoid.WalkSpeed = 16 end
        end
    end
})

-- Walkspeed Slider
local walkspeedSlider
walkspeedSlider = PlayerSection:Slider({
    Title = "Walkspeed",
    Desc = "Custom walkspeed value",
    Step = 1,
    Value = {
        Min = 16,
        Max = 100,
        Default = toggles.walkspeed
    },
    Callback = function(value)
        toggles.walkspeed = value
        saveSettings()
    end
})

-- Anti-Lag Section
local AntiLagSection = FarmTab:Section({
    Title = "Performance",
    Opened = true
})

-- Anti-Lag Toggle
local antiLagToggle
antiLagToggle = AntiLagSection:Toggle({
    Title = "Anti Lag",
    Desc = "Delete laggy objects",
    Value = toggles.antiLag,
    Callback = function(Value)
        toggles.antiLag = Value
        saveSettings()
        if Value then
            addToConsole("Anti-Lag enabled - cleaning objects...")
            runAntiLag()
        else
            addToConsole("Anti-Lag disabled")
        end
    end
})

-- Status Section
local StatusSection = FarmTab:Section({
    Title = "Status",
    Opened = true
})

statusLabel = StatusSection:Paragraph({
    Title = "Status: Idle",
    Desc = "Current status",
    Locked = false
})

pollenLabel = StatusSection:Paragraph({
    Title = "Pollen: 0",
    Desc = "Current pollen",
    Locked = false
})

hourlyHoneyLabel = StatusSection:Paragraph({
    Title = "Hourly Honey: 0",
    Desc = "Honey per hour",
    Locked = false
})

sprinklerStatusLabel = StatusSection:Paragraph({
    Title = "Sprinklers: 0/0 placed",
    Desc = "Sprinkler status",
    Locked = false
})

-- Toys Tab Sections
local MountainBoosterSection = ToysTab:Section({
    Title = "Mountain Booster",
    Opened = true
})

local mountainBoosterToggle
mountainBoosterToggle = MountainBoosterSection:Toggle({
    Title = "Auto Mountain Booster",
    Desc = "Use every 30 minutes",
    Value = mountainBoosterEnabled,
    Callback = function(Value)
        mountainBoosterEnabled = Value
        saveSettings()
        if Value then
            useMountainBooster()
            addToConsole("🏔️ Auto Mountain Booster enabled")
        else
            addToConsole("🏔️ Auto Mountain Booster disabled")
        end
    end
})

local RedBoosterSection = ToysTab:Section({
    Title = "Red Booster",
    Opened = true
})

local redBoosterToggle
redBoosterToggle = RedBoosterSection:Toggle({
    Title = "Auto Red Booster",
    Desc = "Use every 30 minutes",
    Value = redBoosterEnabled,
    Callback = function(Value)
        redBoosterEnabled = Value
        saveSettings()
        if Value then
            useRedBooster()
            addToConsole("🔴 Auto Red Booster enabled")
        else
            addToConsole("🔴 Auto Red Booster disabled")
        end
    end
})

local BlueBoosterSection = ToysTab:Section({
    Title = "Blue Booster",
    Opened = true
})

local blueBoosterToggle
blueBoosterToggle = BlueBoosterSection:Toggle({
    Title = "Auto Blue Booster",
    Desc = "Use every 30 minutes",
    Value = blueBoosterEnabled,
    Callback = function(Value)
        blueBoosterEnabled = Value
        saveSettings()
        if Value then
            useBlueBooster()
            addToConsole("🔵 Auto Blue Booster enabled")
        else
            addToConsole("🔵 Auto Blue Booster disabled")
        end
    end
})

local WealthClockSection = ToysTab:Section({
    Title = "Wealth Clock",
    Opened = true
})

local wealthClockToggle
wealthClockToggle = WealthClockSection:Toggle({
    Title = "Auto Wealth Clock",
    Desc = "Use every 1 hour",
    Value = wealthClockEnabled,
    Callback = function(Value)
        wealthClockEnabled = Value
        saveSettings()
        if Value then
            useWealthClock()
            addToConsole("⏰ Auto Wealth Clock enabled")
        else
            addToConsole("⏰ Auto Wealth Clock disabled")
        end
    end
})

-- Webhook Tab Sections
local WebhookSettingsSection = WebhookTab:Section({
    Title = "Webhook Settings",
    Opened = true
})

webhookToggleElement = WebhookSettingsSection:Toggle({
    Title = "Enable Webhook",
    Desc = "Enable webhook notifications",
    Value = webhookEnabled,
    Callback = function(Value)
        webhookEnabled = Value
        saveSettings()
        if Value then
            addToConsole("Webhook enabled")
        else
            addToConsole("Webhook disabled")
        end
    end
})

webhookURLElement = WebhookSettingsSection:Input({
    Title = "Webhook URL",
    Desc = "Discord webhook URL",
    Value = webhookURL,
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback = function(Value)
        webhookURL = Value
        saveSettings()
    end
})

webhookIntervalElement = WebhookSettingsSection:Slider({
    Title = "Send Interval",
    Desc = "Minutes between webhooks",
    Step = 1,
    Value = {
        Min = 1,
        Max = 60,
        Default = webhookInterval
    },
    Callback = function(value)
        webhookInterval = value
        saveSettings()
    end
})

WebhookSettingsSection:Button({
    Title = "Send Test Webhook",
    Desc = "Send a test webhook",
    Callback = function()
        if webhookEnabled and webhookURL ~= "" then
            addToConsole("Sending test webhook...")
            sendWebhook()
        else
            addToConsole("❌ Enable webhook and set URL first")
        end
    end
})

-- Console Tab Section
local ConsoleSection = ConsoleTab:Section({
    Title = "Console Output",
    Opened = true
})

consoleLabelElement = ConsoleSection:Paragraph({
    Title = "Lavender Hub v0.5 - WindUI Edition",
    Desc = "Console output will appear here...",
    Locked = false
})

-- Debug Tab Sections
local PerformanceSection = DebugTab:Section({
    Title = "Performance Stats",
    Opened = true
})

fpsLabel = PerformanceSection:Paragraph({
    Title = "FPS: 0",
    Desc = "Frames per second",
    Locked = false
})

memoryLabel = PerformanceSection:Paragraph({
    Title = "Memory: 0 MB",
    Desc = "Memory usage",
    Locked = false
})

objectsLabel = PerformanceSection:Paragraph({
    Title = "Objects Deleted: 0",
    Desc = "Anti-lag objects deleted",
    Locked = false
})

local HoneyStatsSection = DebugTab:Section({
    Title = "Honey Statistics",
    Opened = true
})

honeyMadeLabel = HoneyStatsSection:Paragraph({
    Title = "Honey Made: 0",
    Desc = "Total honey made",
    Locked = false
})

hourlyRateLabel = HoneyStatsSection:Paragraph({
    Title = "Hourly Rate: 0",
    Desc = "Honey per hour",
    Locked = false
})

sessionHoneyLabel = HoneyStatsSection:Paragraph({
    Title = "Session Honey: 0",
    Desc = "This session's honey",
    Locked = false
})

dailyHoneyLabel = HoneyStatsSection:Paragraph({
    Title = "Daily Honey: 0",
    Desc = "Today's honey",
    Locked = false
})

local DebugActionsSection = DebugTab:Section({
    Title = "Actions",
    Opened = true
})

DebugActionsSection:Button({
    Title = "Run Anti-Lag",
    Desc = "Run anti-lag cleanup",
    Callback = function()
        if toggles.antiLag then
            runAntiLag()
        else
            addToConsole("Enable Anti-Lag first")
        end
    end
})

DebugActionsSection:Button({
    Title = "Clear Console",
    Desc = "Clear console output",
    Callback = function()
        consoleLogs = {}
        if consoleLabelElement then
            consoleLabelElement:SetTitle("Console cleared")
            consoleLabelElement:SetDesc("Console cleared at " .. os.date("%H:%M:%S"))
        end
    end
})

DebugActionsSection:Button({
    Title = "Equip Tools",
    Desc = "Manually equip all tools",
    Callback = function()
        equipAllTools()
        addToConsole("Manually equipped all tools")
    end
})

DebugActionsSection:Button({
    Title = "Test Sprinkler",
    Desc = "Test sprinkler placement",
    Callback = function()
        if useSprinklerRemote(toggles.field) then
            addToConsole("✅ Test sprinkler placed successfully")
        else
            addToConsole("❌ Test sprinkler failed")
        end
    end
})

-- Manual GUI toggle
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == toggleKey then
        guiVisible = not guiVisible
        -- Toggle GUI visibility
        if Window and Window.Visible ~= nil then
            Window.Visible = guiVisible
            addToConsole(guiVisible and "GUI shown (RightControl)" or "GUI hidden (RightControl)")
        end
    end
end)

-- Anti-AFK
player.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
end)

-- Setup death detection
setupDeathDetection()

-- Load settings
loadSettings()

-- Apply loaded settings to UI elements
if fieldDropdown then fieldDropdown:Select(toggles.field) end
if autoFarmToggle then autoFarmToggle:Set(toggles.autoFarm) end
if autoDigToggle then autoDigToggle:Set(toggles.autoDig) end
if autoEquipToggle then autoEquipToggle:Set(toggles.autoEquip) end
if antiLagToggle then antiLagToggle:Set(toggles.antiLag) end
if movementMethodDropdown then movementMethodDropdown:Select(toggles.movementMethod) end
if tweenSpeedSlider then tweenSpeedSlider:Set(toggles.tweenSpeed) end
if walkspeedToggle then walkspeedToggle:Set(toggles.walkspeedEnabled) end
if walkspeedSlider then walkspeedSlider:Set(toggles.walkspeed) end
if autoSprinklersToggle then autoSprinklersToggle:Set(autoSprinklersEnabled) end
if sprinklerTypeDropdown then sprinklerTypeDropdown:Select(selectedSprinkler) end
if webhookToggleElement then webhookToggleElement:Set(webhookEnabled) end
if webhookURLElement then webhookURLElement:Set(webhookURL) end
if webhookIntervalElement then webhookIntervalElement:Set(webhookInterval) end
if ticketConvertersToggle then ticketConvertersToggle:Set(useTicketConverters) end
if mountainBoosterToggle then mountainBoosterToggle:Set(mountainBoosterEnabled) end
if redBoosterToggle then redBoosterToggle:Set(redBoosterEnabled) end
if blueBoosterToggle then blueBoosterToggle:Set(blueBoosterEnabled) end
if wealthClockToggle then wealthClockToggle:Set(wealthClockEnabled) end

-- Initialize honey tracking
honeyStats.startHoney = getCurrentHoney()
honeyStats.currentHoney = honeyStats.startHoney
honeyStats.lastHoneyValue = honeyStats.startHoney
honeyStats.trackingStarted = false
honeyStats.firstAutoFarmEnabled = false
honeyStats.honeyMade = 0
honeyStats.hourlyRate = 0
honeyStats.sessionHoney = 0
honeyStats.dailyHoney = 0

-- Run anti-lag on startup if enabled
if toggles.antiLag then
    addToConsole("Running startup Anti-Lag...")
    runAntiLag()
end

-- Main heartbeat loop
local lastHeartbeatTime = 0
RunService.Heartbeat:Connect(function()
    local currentTime = tick()
    if currentTime - lastHeartbeatTime < 0.1 then return end
    lastHeartbeatTime = currentTime
    
    updateFarmState()
    updateWalkspeed()
    clearVisitedTokens()
    updatePerformanceStats()
    autoEquipTools()
    updateToys()
    updateHoneyStats()
    sendWebhook()
    updateStatusLabels()
end)

-- Stats update loop
task.spawn(function()
    while task.wait(1) do
        local currentPollen = getCurrentPollen()
        local currentHoney = getCurrentHoney()
        
        local statsText = string.format(
            "Honey: %s\nPollen: %s\nField: %s\nHive: %s\nMove: %s\nDig: %s\nEquip: %s\nAnti-Lag: %s\nHourly Honey: %s\nAuto Sprinklers: %s\nSprinkler Type: %s\nTicket Converters: %s\nSession Honey: %s\nDaily Honey: %s",
            formatNumberCorrect(currentHoney),
            formatNumberCorrect(currentPollen),
            toggles.field,
            displayHiveName,
            toggles.movementMethod,
            toggles.autoDig and "ON" or "OFF",
            toggles.autoEquip and "ON" or "OFF",
            toggles.antiLag and "ON" or "OFF",
            formatNumberCorrect(honeyStats.hourlyRate),
            autoSprinklersEnabled and "ON" or "OFF",
            selectedSprinkler,
            useTicketConverters and "ON" or "OFF",
            formatNumberCorrect(honeyStats.sessionHoney),
            formatNumberCorrect(honeyStats.dailyHoney)
        )
        
        -- Update home stats
        if homeStatsElement then
            homeStatsElement:SetDesc(statsText)
        end
    end
end)

-- Final initialization
addToConsole("✅ Lavender Hub v0.5 - WindUI Edition Ready!")
addToConsole("🎯 Auto Farm System Ready!")
addToConsole("🚿 Auto Sprinklers System Ready!")
addToConsole("💀 Death Respawn System Ready!")
addToConsole("🌐 Webhook System Ready!")
addToConsole("🎫 Ticket Converters System Ready!")
addToConsole("🎁 Toys/Boosters System Ready!")
addToConsole("🔄 Press RightControl to toggle GUI visibility")
if ownedHive then
    addToConsole("🏠 Owned Hive: " .. ownedHive)
else
    addToConsole("💔 No hive owned")
end

-- Show welcome notification
WindUI:Notify({
    Title = "Lavender Hub Loaded",
    Content = "WindUI Edition - Press RightControl to toggle GUI",
    Duration = 5,
    Icon = "flower"
})

addToConsole("⚠️ IMPORTANT: Make sure you have a hive before starting auto farm!")
