-- MG DUELS v2.1 by void (Modified)
-- Discord: discord.gg/V2m8qstna
-- ADDITIONS: Hitbox Expander (purple visual), Overhead Speed Label, FPS + Ping in hub

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function protectGui(gui)
    pcall(function()
        if syn and syn.protect_gui then
            syn.protect_gui(gui)
            gui.Parent = CoreGui
        elseif gethui then
            gui.Parent = gethui()
        else
            gui.Parent = CoreGui
        end
    end)
end

local theme = {
    Primary = Color3.fromRGB(138, 43, 226),
    Secondary = Color3.fromRGB(75, 0, 130)
}

local config = {
    SpeedBoost = false,
    Speed = 50,
    StealBoost = false,
    Steal = 30,
    AntiRagdoll = false,
    AutoGrab = false,
    GrabRadius = 20,
    AutoDuel = false,
    AutoBat = false,
    MeleeAimbot = false,
    MeleeCircleRadius = 7.25,
    ESPPlayers = false,
    OptimizerXRay = false,
    InfiniteJump = false,
    SpinBot = false,
    SpinSpeed = 10,
    NoAnimation = false,
    FOVChanger = false,
    FOV = 70,
    BatAimbot = false,
    GalaxySkyBright = false,
    AutoLeft = false,
    AutoRight = false,
    Float = false,
    HitboxExpander = false,
    HitboxSize = 8,
    OverheadSpeed = true,
}

local CONFIG_FILE_NAME = "MG_DUELS_v21_Config.json"

local function saveConfig()
    pcall(function()
        if writefile then
            local configData = HttpService:JSONEncode(config)
            writefile(CONFIG_FILE_NAME, configData)
            StarterGui:SetCore("SendNotification", {
                Title = "MG DUELS v2.1";
                Text = "Config saved!";
                Duration = 3;
            })
        end
    end)
end

local function loadConfig()
    pcall(function()
        if readfile and isfile and isfile(CONFIG_FILE_NAME) then
            local configData = readfile(CONFIG_FILE_NAME)
            local loadedConfig = HttpService:JSONDecode(configData)
            for key, value in pairs(loadedConfig) do
                if config[key] ~= nil then
                    config[key] = value
                end
            end
            StarterGui:SetCore("SendNotification", {
                Title = "MG DUELS v2.1";
                Text = "Config loaded!";
                Duration = 3;
            })
        end
    end)
end

local connections = {}
local toggleSetters = {}

-- ========== AUTO STEAL SYSTEM ==========

local autoStealActive = false
local autoStealStealConnection = nil
local autoStealAnimalsCache = {}
local autoStealPromptCache = {}
local autoStealInternalCache = {}
local autoStealLastUID = nil
local autoStealIsStealing = false
local AUTO_STEAL_PROX_RADIUS = 7

local setStealBoostRef = nil

local function autoSteal_getHRP()
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso")
end

local function autoSteal_isMyBase(plotName)
    local plots = workspace:FindFirstChild("Plots")
    local plot = plots and plots:FindFirstChild(plotName)
    if not plot then return false end
    local sign = plot:FindFirstChild("PlotSign")
    if sign then
        local yourBase = sign:FindFirstChild("YourBase")
        if yourBase and yourBase:IsA("BillboardGui") then
            return yourBase.Enabled == true
        end
    end
    return false
end

local animalsDataAS = {}
pcall(function()
    animalsDataAS = require(ReplicatedStorage:WaitForChild("Datas", 5):WaitForChild("Animals", 5))
end)

local function autoSteal_scanPlot(plot)
    if not plot or not plot:IsA("Model") then return end
    if autoSteal_isMyBase(plot.Name) then return end
    local podiums = plot:FindFirstChild("AnimalPodiums")
    if not podiums then return end
    for _, podium in ipairs(podiums:GetChildren()) do
        if podium:IsA("Model") and podium:FindFirstChild("Base") then
            local animalName = "Unknown"
            local spawn = podium.Base:FindFirstChild("Spawn")
            if spawn then
                for _, child in ipairs(spawn:GetChildren()) do
                    if child:IsA("Model") and child.Name ~= "PromptAttachment" then
                        animalName = child.Name
                        local info = animalsDataAS[animalName]
                        if info and info.DisplayName then animalName = info.DisplayName end
                        break
                    end
                end
            end
            table.insert(autoStealAnimalsCache, {
                name = animalName,
                plot = plot.Name,
                slot = podium.Name,
                worldPosition = podium:GetPivot().Position,
                uid = plot.Name .. "_" .. podium.Name,
            })
        end
    end
end

local autoStealScannerStarted = false
local function autoSteal_initScanner()
    if autoStealScannerStarted then return end
    autoStealScannerStarted = true
    task.spawn(function()
        task.wait(2)
        local plots = workspace:WaitForChild("Plots", 10)
        if not plots then return end
        for _, plot in ipairs(plots:GetChildren()) do
            if plot:IsA("Model") then autoSteal_scanPlot(plot) end
        end
        plots.ChildAdded:Connect(function(plot)
            if plot:IsA("Model") then task.wait(0.5) autoSteal_scanPlot(plot) end
        end)
        task.spawn(function()
            while task.wait(5) do
                autoStealAnimalsCache = {}
                for _, plot in ipairs(plots:GetChildren()) do
                    if plot:IsA("Model") then autoSteal_scanPlot(plot) end
                end
            end
        end)
    end)
end

local function autoSteal_findPrompt(animalData)
    if not animalData then return nil end
    local cached = autoStealPromptCache[animalData.uid]
    if cached and cached.Parent then return cached end
    local plots = workspace:FindFirstChild("Plots")
    local plot = plots and plots:FindFirstChild(animalData.plot)
    if not plot then return nil end
    local podiums = plot:FindFirstChild("AnimalPodiums")
    if not podiums then return nil end
    local podium = podiums:FindFirstChild(animalData.slot)
    if not podium then return nil end
    local base = podium:FindFirstChild("Base")
    if not base then return nil end
    local spawn = base:FindFirstChild("Spawn")
    if not spawn then return nil end
    local attach = spawn:FindFirstChild("PromptAttachment")
    if not attach then return nil end
    for _, p in ipairs(attach:GetChildren()) do
        if p:IsA("ProximityPrompt") then
            autoStealPromptCache[animalData.uid] = p
            return p
        end
    end
    return nil
end

local function autoSteal_buildCallbacks(prompt)
    if autoStealInternalCache[prompt] then return end
    local data = { holdCallbacks = {}, triggerCallbacks = {}, ready = true }
    local ok1, conns1 = pcall(getconnections, prompt.PromptButtonHoldBegan)
    if ok1 and type(conns1) == "table" then
        for _, conn in ipairs(conns1) do
            if type(conn.Function) == "function" then
                table.insert(data.holdCallbacks, conn.Function)
            end
        end
    end
    local ok2, conns2 = pcall(getconnections, prompt.Triggered)
    if ok2 and type(conns2) == "table" then
        for _, conn in ipairs(conns2) do
            if type(conn.Function) == "function" then
                table.insert(data.triggerCallbacks, conn.Function)
            end
        end
    end
    if (#data.holdCallbacks > 0) or (#data.triggerCallbacks > 0) then
        autoStealInternalCache[prompt] = data
    end
end

local function autoSteal_execute(prompt)
    local data = autoStealInternalCache[prompt]
    if not data or not data.ready then return false end
    data.ready = false
    autoStealIsStealing = true

    if config.SpeedBoost and not config.StealBoost then
        config.StealBoost = true
        if setStealBoostRef then setStealBoostRef(true, true) end
    end

    task.spawn(function()
        for _, fn in ipairs(data.holdCallbacks) do task.spawn(fn) end
        task.wait(0.2)
        for _, fn in ipairs(data.triggerCallbacks) do task.spawn(fn) end
        task.wait(0.01)
        data.ready = true
        task.wait(0.01)
        autoStealIsStealing = false
    end)
    return true
end

local function autoSteal_attempt(prompt)
    if not prompt or not prompt.Parent then return false end
    autoSteal_buildCallbacks(prompt)
    if not autoStealInternalCache[prompt] then return false end
    return autoSteal_execute(prompt)
end

local function autoSteal_getNearest()
    local hrp = autoSteal_getHRP()
    if not hrp then return nil end
    local nearest, minDist = nil, math.huge
    for _, animalData in ipairs(autoStealAnimalsCache) do
        if autoSteal_isMyBase(animalData.plot) then continue end
        if animalData.worldPosition then
            local dist = (hrp.Position - animalData.worldPosition).Magnitude
            if dist < minDist then minDist = dist nearest = animalData end
        end
    end
    return nearest
end

local function startAutoStealLoop()
    if autoStealStealConnection then autoStealStealConnection:Disconnect() end
    autoStealStealConnection = RunService.Heartbeat:Connect(function()
        if not autoStealActive then return end
        if autoStealIsStealing then return end
        local target = autoSteal_getNearest()
        if not target or not target.worldPosition then return end
        local hrp = autoSteal_getHRP()
        if not hrp then return end
        if (hrp.Position - target.worldPosition).Magnitude > AUTO_STEAL_PROX_RADIUS then return end
        if autoStealLastUID ~= target.uid then autoStealLastUID = target.uid end
        local prompt = autoStealPromptCache[target.uid]
        if not prompt or not prompt.Parent then prompt = autoSteal_findPrompt(target) end
        if prompt then autoSteal_attempt(prompt) end
    end)
end

local function stopAutoStealLoop()
    if autoStealStealConnection then autoStealStealConnection:Disconnect() autoStealStealConnection = nil end
    autoStealIsStealing = false
end

local function enableAutoSteal()
    autoStealActive = true
    autoSteal_initScanner()
    startAutoStealLoop()
end

local function disableAutoSteal()
    autoStealActive = false
    stopAutoStealLoop()
end

-- ========== CIRCLE VISUALIZER ==========

local circleParts = {}
local PartsCount = 65

local function createCircle()
    for _, p in ipairs(circleParts) do if p then pcall(function() p:Destroy() end) end end
    table.clear(circleParts)
    for i = 1, PartsCount do
        local part = Instance.new("Part")
        part.Anchored = true part.CanCollide = false part.Material = Enum.Material.Neon
        part.Color = Color3.fromRGB(138, 43, 226) part.Transparency = 0.35
        part.Size = Vector3.new(1, 0.2, 0.3) part.Parent = workspace
        table.insert(circleParts, part)
    end
end

-- ========== MELEE AIMBOT ==========

local MeleeAimbot = {
    Enabled = false,
    Circle = nil,
    Align = nil,
    Attach = nil,
    Conn = nil,
}

local function findNearestMeleeTarget(hrp, radius)
    local nearest, dmin = nil, radius
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local d = (p.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
            if d <= dmin then
                dmin = d
                nearest = p.Character.HumanoidRootPart
            end
        end
    end
    return nearest
end

local function EnableMeleeAimbot()
    if MeleeAimbot.Enabled then return end
    MeleeAimbot.Enabled = true

    local char = player.Character or player.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")

    MeleeAimbot.Attach = Instance.new("Attachment", hrp)
    MeleeAimbot.Align = Instance.new("AlignOrientation", hrp)
    MeleeAimbot.Align.Attachment0 = MeleeAimbot.Attach
    MeleeAimbot.Align.Mode = Enum.OrientationAlignmentMode.OneAttachment
    MeleeAimbot.Align.RigidityEnabled = true

    local circlePart = Instance.new("Part")
    circlePart.Shape = Enum.PartType.Cylinder
    circlePart.Material = Enum.Material.Neon
    local r = config.MeleeCircleRadius
    circlePart.Size = Vector3.new(0.05, r * 2, r * 2)
    circlePart.Color = Color3.fromRGB(138, 43, 226)
    circlePart.CanCollide = false
    circlePart.Massless = true
    circlePart.Transparency = 0.4
    circlePart.Parent = workspace
    local weld = Instance.new("Weld")
    weld.Part0 = hrp
    weld.Part1 = circlePart
    weld.C0 = CFrame.new(0, -1, 0) * CFrame.Angles(0, 0, math.rad(90))
    weld.Parent = circlePart
    MeleeAimbot.Circle = circlePart

    MeleeAimbot.Conn = RunService.RenderStepped:Connect(function()
        if not MeleeAimbot.Enabled then return end
        local c = player.Character if not c then return end
        local h = c:FindFirstChild("HumanoidRootPart")
        local hum = c:FindFirstChildOfClass("Humanoid")
        if not h or not hum then return end

        local target = findNearestMeleeTarget(h, config.MeleeCircleRadius)
        if target then
            hum.AutoRotate = false
            MeleeAimbot.Align.Enabled = true
            MeleeAimbot.Align.CFrame = CFrame.lookAt(h.Position, Vector3.new(target.Position.X, h.Position.Y, target.Position.Z))
            local tool = c:FindFirstChild("Bat") or c:FindFirstChild("Medusa")
            if tool then tool:Activate() end
        else
            MeleeAimbot.Align.Enabled = false
            hum.AutoRotate = true
        end
    end)
end

local function DisableMeleeAimbot()
    if not MeleeAimbot.Enabled then return end
    MeleeAimbot.Enabled = false
    if MeleeAimbot.Conn then MeleeAimbot.Conn:Disconnect() MeleeAimbot.Conn = nil end
    if MeleeAimbot.Circle then MeleeAimbot.Circle:Destroy() MeleeAimbot.Circle = nil end
    if MeleeAimbot.Align then MeleeAimbot.Align:Destroy() MeleeAimbot.Align = nil end
    if MeleeAimbot.Attach then MeleeAimbot.Attach:Destroy() MeleeAimbot.Attach = nil end
    if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
        player.Character:FindFirstChildOfClass("Humanoid").AutoRotate = true
    end
end

-- ========== INFINITE JUMP ==========

local jumpForce = 50
local clampFallSpeed = 80
local heartbeatJumpConn, jumpRequestConn

local function startInfiniteJump()
    if jumpRequestConn then return end
    heartbeatJumpConn = RunService.Heartbeat:Connect(function()
        if not config.InfiniteJump then return end
        local char = player.Character if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and hrp.AssemblyLinearVelocity.Y < -clampFallSpeed then
            hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, -clampFallSpeed, hrp.AssemblyLinearVelocity.Z)
        end
    end)
    jumpRequestConn = UserInputService.JumpRequest:Connect(function()
        if not config.InfiniteJump then return end
        local char = player.Character if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, jumpForce, hrp.AssemblyLinearVelocity.Z) end
    end)
end

local function stopInfiniteJump()
    if heartbeatJumpConn then heartbeatJumpConn:Disconnect() heartbeatJumpConn = nil end
    if jumpRequestConn then jumpRequestConn:Disconnect() jumpRequestConn = nil end
end

startInfiniteJump()

-- ========== BAT / ENEMY HELPERS ==========

local function findBat()
    local c = player.Character
    local bp = player:FindFirstChildOfClass("Backpack")
    if c then for _, ch in ipairs(c:GetChildren()) do if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end end end
    if bp then for _, ch in ipairs(bp:GetChildren()) do if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end end end
    return nil
end

local function findNearestEnemy(myHRP)
    local nearest, nearestDist, nearestTorso = nil, math.huge, nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local eh = p.Character:FindFirstChild("HumanoidRootPart")
            local tor = p.Character:FindFirstChild("UpperTorso") or p.Character:FindFirstChild("Torso")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if eh and hum and hum.Health > 0 then
                local d = (eh.Position - myHRP.Position).Magnitude
                if d < nearestDist then nearestDist = d nearest = eh nearestTorso = tor or eh end
            end
        end
    end
    return nearest, nearestDist, nearestTorso
end

-- ========== BAT AIMBOT ==========

local batAimbotConnection = nil

local function startBatAimbot()
    if batAimbotConnection then return end
    batAimbotConnection = RunService.Heartbeat:Connect(function()
        if not config.BatAimbot then return end
        local c = player.Character if not c then return end
        local h = c:FindFirstChild("HumanoidRootPart")
        local hum = c:FindFirstChildOfClass("Humanoid")
        if not h or not hum then return end
        local bat = findBat()
        if bat and bat.Parent ~= c then hum:EquipTool(bat) end
        local target, _, torso = findNearestEnemy(h)
        if target and torso then
            local dir = (torso.Position - h.Position)
            local flatDir = Vector3.new(dir.X, 0, dir.Z)
            local flatDist = flatDir.Magnitude
            local spd = 55
            if flatDist > 1.5 then
                local moveDir = flatDir.Unit
                h.AssemblyLinearVelocity = Vector3.new(moveDir.X*spd, h.AssemblyLinearVelocity.Y, moveDir.Z*spd)
            else
                local tv = target.AssemblyLinearVelocity
                h.AssemblyLinearVelocity = Vector3.new(tv.X, h.AssemblyLinearVelocity.Y, tv.Z)
            end
        end
    end)
end

local function stopBatAimbot()
    if batAimbotConnection then batAimbotConnection:Disconnect() batAimbotConnection = nil end
end

-- ========== OPTIMIZER ==========

local function enableOptimizer()
    if getgenv and getgenv().OPTIMIZER_ACTIVE then return end
    if getgenv then getgenv().OPTIMIZER_ACTIVE = true end
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        Lighting.GlobalShadows = false Lighting.Brightness = 3 Lighting.FogEnd = 9e9
    end)
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            pcall(function()
                if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then obj:Destroy()
                elseif obj:IsA("BasePart") then obj.CastShadow = false obj.Material = Enum.Material.Plastic end
            end)
        end
    end)
end

local originalTransparency = {}
local xrayEnabled = false

local function disableOptimizer()
    if getgenv then getgenv().OPTIMIZER_ACTIVE = false end
    if xrayEnabled then
        for part, value in pairs(originalTransparency) do if part then part.LocalTransparencyModifier = value end end
        originalTransparency = {} xrayEnabled = false
    end
end

-- ========== GALAXY SKY ==========

local originalSkybox, galaxySkyBright, galaxySkyBrightConn
local galaxyPlanets = {}
local galaxyBloom, galaxyCC

local function enableGalaxySkyBright()
    if galaxySkyBright then return end
    originalSkybox = Lighting:FindFirstChildOfClass("Sky")
    if originalSkybox then originalSkybox.Parent = nil end
    galaxySkyBright = Instance.new("Sky")
    galaxySkyBright.SkyboxBk = "rbxassetid://1534951537" galaxySkyBright.SkyboxDn = "rbxassetid://1534951537"
    galaxySkyBright.SkyboxFt = "rbxassetid://1534951537" galaxySkyBright.SkyboxLf = "rbxassetid://1534951537"
    galaxySkyBright.SkyboxRt = "rbxassetid://1534951537" galaxySkyBright.SkyboxUp = "rbxassetid://1534951537"
    galaxySkyBright.StarCount = 10000 galaxySkyBright.CelestialBodiesShown = false galaxySkyBright.Parent = Lighting
    galaxyBloom = Instance.new("BloomEffect") galaxyBloom.Intensity = 1.5 galaxyBloom.Size = 40 galaxyBloom.Threshold = 0.8 galaxyBloom.Parent = Lighting
    galaxyCC = Instance.new("ColorCorrectionEffect") galaxyCC.Saturation = 0.8 galaxyCC.Contrast = 0.3 galaxyCC.TintColor = Color3.fromRGB(200,150,255) galaxyCC.Parent = Lighting
    Lighting.Ambient = Color3.fromRGB(120,60,180) Lighting.Brightness = 3 Lighting.ClockTime = 0
    for i = 1, 2 do
        local p = Instance.new("Part") p.Shape = Enum.PartType.Ball
        p.Size = Vector3.new(800+i*200,800+i*200,800+i*200) p.Anchored = true p.CanCollide = false p.CastShadow = false
        p.Material = Enum.Material.Neon p.Color = Color3.fromRGB(140+i*20,60+i*10,200+i*15) p.Transparency = 0.3
        p.Position = Vector3.new(math.cos(i*2)*(3000+i*500), 1500+i*300, math.sin(i*2)*(3000+i*500)) p.Parent = workspace
        table.insert(galaxyPlanets, p)
    end
    galaxySkyBrightConn = RunService.Heartbeat:Connect(function()
        if not config.GalaxySkyBright then return end
        local t = tick()*0.5
        Lighting.Ambient = Color3.fromRGB(120+math.sin(t)*60, 50+math.sin(t*0.8)*40, 180+math.sin(t*1.2)*50)
        if galaxyBloom then galaxyBloom.Intensity = 1.2+math.sin(t*2)*0.4 end
    end)
end

local function disableGalaxySkyBright()
    if galaxySkyBrightConn then galaxySkyBrightConn:Disconnect() galaxySkyBrightConn = nil end
    if galaxySkyBright then galaxySkyBright:Destroy() galaxySkyBright = nil end
    if originalSkybox then originalSkybox.Parent = Lighting end
    if galaxyBloom then galaxyBloom:Destroy() galaxyBloom = nil end
    if galaxyCC then galaxyCC:Destroy() galaxyCC = nil end
    for _, obj in ipairs(galaxyPlanets) do if obj then obj:Destroy() end end
    galaxyPlanets = {}
    Lighting.Ambient = Color3.fromRGB(127,127,127) Lighting.Brightness = 2 Lighting.ClockTime = 14
end

-- ========== NO ANIMATION ==========

local savedAnimations = {}

local function startUnwalk()
    local c = player.Character if not c then return end
    local hum = c:FindFirstChildOfClass("Humanoid")
    if hum then for _, t in ipairs(hum:GetPlayingAnimationTracks()) do t:Stop() end end
    local anim = c:FindFirstChild("Animate")
    if anim then savedAnimations.Animate = anim:Clone() anim:Destroy() end
end

local function stopUnwalk()
    local c = player.Character
    if c and savedAnimations.Animate then savedAnimations.Animate:Clone().Parent = c savedAnimations.Animate = nil end
end

-- ========== ANTI RAGDOLL ==========

local antiRagdollMode    = nil
local ragdollConnections = {}
local cachedCharData     = {}
local arIsBoosting       = false
local AR_BOOST_SPEED     = 400
local AR_DEFAULT_SPEED   = 16

local function arCacheCharacterData()
    local char = player.Character
    if not char then return false end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return false end
    cachedCharData = { character = char, humanoid = hum, root = root }
    return true
end

local function arDisconnectAll()
    for _, conn in ipairs(ragdollConnections) do
        pcall(function() conn:Disconnect() end)
    end
    ragdollConnections = {}
end

local function arIsRagdolled()
    if not cachedCharData.humanoid then return false end
    local state = cachedCharData.humanoid:GetState()
    local ragdollStates = {
        [Enum.HumanoidStateType.Physics]     = true,
        [Enum.HumanoidStateType.Ragdoll]     = true,
        [Enum.HumanoidStateType.FallingDown] = true,
    }
    if ragdollStates[state] then return true end
    local endTime = player:GetAttribute("RagdollEndTime")
    if endTime and (endTime - workspace:GetServerTimeNow()) > 0 then return true end
    return false
end

local function arForceExitRagdoll()
    if not cachedCharData.humanoid or not cachedCharData.root then return end
    pcall(function()
        player:SetAttribute("RagdollEndTime", workspace:GetServerTimeNow())
    end)
    for _, descendant in ipairs(cachedCharData.character:GetDescendants()) do
        if descendant:IsA("BallSocketConstraint") or
           (descendant:IsA("Attachment") and descendant.Name:find("RagdollAttachment")) then
            descendant:Destroy()
        end
    end
    if not arIsBoosting then
        arIsBoosting = true
        cachedCharData.humanoid.WalkSpeed = AR_BOOST_SPEED
    end
    if cachedCharData.humanoid.Health > 0 then
        cachedCharData.humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end
    cachedCharData.root.Anchored = false
end

local function arHeartbeatLoop()
    while antiRagdollMode == "active" do
        task.wait()
        local isRagdolled = arIsRagdolled()
        if isRagdolled then
            arForceExitRagdoll()
        elseif arIsBoosting and not isRagdolled then
            arIsBoosting = false
            if cachedCharData.humanoid then
                cachedCharData.humanoid.WalkSpeed = AR_DEFAULT_SPEED
            end
        end
    end
end

local function EnableAntiRagdoll()
    if antiRagdollMode == "active" then return end
    if not arCacheCharacterData() then return end
    antiRagdollMode = "active"

    local camConn = RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        if cam and cachedCharData.humanoid then
            cam.CameraSubject = cachedCharData.humanoid
        end
    end)
    table.insert(ragdollConnections, camConn)

    local respawnConn = player.CharacterAdded:Connect(function()
        arIsBoosting = false
        task.wait(0.5)
        arCacheCharacterData()
    end)
    table.insert(ragdollConnections, respawnConn)

    task.spawn(arHeartbeatLoop)
end

local function DisableAntiRagdoll()
    antiRagdollMode = nil
    if arIsBoosting and cachedCharData.humanoid then
        cachedCharData.humanoid.WalkSpeed = AR_DEFAULT_SPEED
    end
    arIsBoosting = false
    arDisconnectAll()
    cachedCharData = {}
end

-- ========== ESP ==========

local espInstances = {}

local function EnableESPPlayers()
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local highlight = Instance.new("Highlight")
            highlight.FillColor = Color3.fromRGB(138,43,226) highlight.OutlineColor = Color3.fromRGB(200,100,255)
            highlight.FillTransparency = 0.5 highlight.Adornee = p.Character highlight.Parent = p.Character
            espInstances[p] = highlight
        end
    end
end

local function DisableESPPlayers()
    for _, highlight in pairs(espInstances) do if highlight then highlight:Destroy() end end
    espInstances = {}
end

-- ========== AUTO BAT ==========

local batLoopActive = false

local function EnableAutoBat()
    batLoopActive = true
    task.spawn(function()
        while batLoopActive do
            local character = player.Character
            if character then
                local humanoid = character:FindFirstChild("Humanoid")
                if humanoid then
                    local bat = character:FindFirstChild("Bat") or player.Backpack:FindFirstChild("Bat")
                    if bat then
                        if bat.Parent == player.Backpack then humanoid:EquipTool(bat) task.wait(0.1) end
                        local equippedBat = character:FindFirstChild("Bat")
                        if equippedBat then equippedBat:Activate() end
                    end
                end
            end
            task.wait(0.15)
        end
    end)
end

local function DisableAutoBat()
    batLoopActive = false
end

-- ========== SPIN BOT ==========

local function EnableSpinBot()
    local function addSpin(character)
        local hrp = character:WaitForChild("HumanoidRootPart")
        if hrp:FindFirstChild("PanquakeSpin") then return end
        local bav = Instance.new("BodyAngularVelocity")
        bav.Name = "PanquakeSpin" bav.AngularVelocity = Vector3.new(0, config.SpinSpeed or 35, 0)
        bav.MaxTorque = Vector3.new(0,1e7,0) bav.P = 1250 bav.Parent = hrp
    end
    if player.Character then addSpin(player.Character) end
    connections["SPIN BOT"] = player.CharacterAdded:Connect(function(char) task.wait(1) addSpin(char) end)
end

local function DisableSpinBot()
    if connections["SPIN BOT"] then connections["SPIN BOT"]:Disconnect() connections["SPIN BOT"] = nil end
    if player.Character then
        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
        if hrp and hrp:FindFirstChild("PanquakeSpin") then hrp.PanquakeSpin:Destroy() end
    end
end

-- ========== AUTO DUEL ==========

local path, pathIndex = {}, 1
local isMoving = false
local moveConn = nil
local pathEndPending = false

local function startDuelMovement()
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    isMoving = true pathEndPending = false
    if (root.Position - Vector3.new(-475,-7,96)).Magnitude > (root.Position - Vector3.new(-474,-7,23)).Magnitude then
        path = {{position=Vector3.new(-475,-7,96),speed=59},{position=Vector3.new(-483,-5,95),speed=59},{position=Vector3.new(-487,-5,95),speed=55},{position=Vector3.new(-492,-5,95),speed=55},{position=Vector3.new(-473,-7,95),speed=29},{position=Vector3.new(-473,-7,11),speed=29}}
    else
        path = {{position=Vector3.new(-474,-7,23),speed=55},{position=Vector3.new(-484,-5,24),speed=55},{position=Vector3.new(-488,-5,24),speed=55},{position=Vector3.new(-493,-5,25),speed=55},{position=Vector3.new(-473,-7,25),speed=29},{position=Vector3.new(-474,-7,112),speed=29}}
    end
    pathIndex = 1
    if moveConn then moveConn:Disconnect() end
    moveConn = RunService.Stepped:Connect(function()
        if not config.AutoDuel or not isMoving then return end
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local wp = path[pathIndex]
        if not wp then isMoving = false return end
        local dist = (root.Position - wp.position).Magnitude
        -- Use tighter stop distance for final waypoint (grab point) to avoid overshooting
        local stopDist = (pathIndex == #path) and 1.2 or 2.5
        if dist < stopDist then
            if pathIndex == #path then
                root.AssemblyLinearVelocity = Vector3.zero
                if not pathEndPending then
                    pathEndPending = true
                    task.delay(0.8, function()
                        if not config.AutoDuel then return end
                        pathIndex = 1 pathEndPending = false
                    end)
                end
            else
                pathIndex = pathIndex + 1
            end
        else
            local dir = (wp.position - root.Position).Unit
            -- Slow down when very close to final waypoint to avoid overshooting
            local speed = wp.speed
            if pathIndex == #path and dist < 8 then
                speed = math.max(12, speed * (dist / 8))
            end
            root.AssemblyLinearVelocity = Vector3.new(dir.X*speed, root.AssemblyLinearVelocity.Y, dir.Z*speed)
        end
    end)
end

local function stopDuelMovement()
    isMoving = false pathEndPending = false
    if moveConn then moveConn:Disconnect() moveConn = nil end
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if root then root.AssemblyLinearVelocity = Vector3.zero end
end

-- ========== AUTO LEFT / RIGHT ==========

local pathActive      = false
local lastFlatVel     = Vector3.zero
local AutoLeftEnabled  = false
local AutoRightEnabled = false

local PATH_VELOCITY_SPEED  = 59.2
local PATH_SECOND_SPEED    = 29.6
local PATH_BASE_STOP       = 1.35
local PATH_MIN_STOP        = 0.65
local PATH_NEXT_POINT_BIAS = 0.45
local PATH_SMOOTH_FACTOR   = 0.12

local stealPath1 = {
    {pos = Vector3.new(-470.6, -5.9,  34.4)},
    {pos = Vector3.new(-484.2, -3.9,  21.4)},
    {pos = Vector3.new(-475.6, -5.8,  29.3)},
    {pos = Vector3.new(-473.4, -5.9, 111.0)},
}
local stealPath2 = {
    {pos = Vector3.new(-474.7, -5.9,  91.0)},
    {pos = Vector3.new(-483.4, -3.9,  97.3)},
    {pos = Vector3.new(-474.7, -5.9,  91.0)},
    {pos = Vector3.new(-476.1, -5.5,  25.4)},
}

local function pathMoveToPoint(hrp, current, nextPoint, speed)
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not pathActive then
            conn:Disconnect()
            hrp.AssemblyLinearVelocity = Vector3.zero
            return
        end
        local pos     = hrp.Position
        local target  = Vector3.new(current.X, pos.Y, current.Z)
        local dir     = target - pos
        local dist    = dir.Magnitude
        local stopDist = math.clamp(PATH_BASE_STOP - dist * 0.04, PATH_MIN_STOP, PATH_BASE_STOP)
        if dist <= stopDist then
            conn:Disconnect()
            hrp.AssemblyLinearVelocity = Vector3.zero
            return
        end
        local moveDir = dir.Unit
        if nextPoint then
            local nextDir = (Vector3.new(nextPoint.X, pos.Y, nextPoint.Z) - pos).Unit
            moveDir = (moveDir + nextDir * PATH_NEXT_POINT_BIAS).Unit
        end
        if lastFlatVel.Magnitude > 0.1 then
            moveDir = (moveDir * (1 - PATH_SMOOTH_FACTOR) + lastFlatVel.Unit * PATH_SMOOTH_FACTOR).Unit
        end
        local vel = Vector3.new(moveDir.X * speed, hrp.AssemblyLinearVelocity.Y, moveDir.Z * speed)
        hrp.AssemblyLinearVelocity = vel
        lastFlatVel = Vector3.new(vel.X, 0, vel.Z)
    end)
    while pathActive and
        (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(current.X, 0, current.Z)).Magnitude > PATH_BASE_STOP do
        RunService.Heartbeat:Wait()
    end
end

local function runStealPath(stealPath)
    local hrp = (player.Character or player.CharacterAdded:Wait()):WaitForChild("HumanoidRootPart")
    for i, p in ipairs(stealPath) do
        if not pathActive then return end
        local speed = i > 2 and PATH_SECOND_SPEED or PATH_VELOCITY_SPEED
        local nextP = stealPath[i + 1] and stealPath[i + 1].pos
        pathMoveToPoint(hrp, p.pos, nextP, speed)
        if i == 2 then task.wait(0.2) else task.wait(0.01) end
    end
end

local function startStealPath(stealPath)
    pathActive = true
    task.spawn(function()
        while pathActive do
            runStealPath(stealPath)
            task.wait(0.1)
        end
    end)
end

local function stopStealPath()
    pathActive = false
    lastFlatVel = Vector3.zero
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.AssemblyLinearVelocity = Vector3.zero end
end

local function startAutoRight()
    if AutoLeftEnabled then
        stopStealPath()
        AutoLeftEnabled = false
        config.AutoLeft = false
        if toggleSetters.AutoLeft then toggleSetters.AutoLeft(false, true) end
    end
    AutoRightEnabled = true
    config.AutoRight = true
    startStealPath(stealPath1)
end

local function stopAutoRight()
    AutoRightEnabled = false
    config.AutoRight = false
    stopStealPath()
end

local function startAutoLeft()
    if AutoRightEnabled then
        stopStealPath()
        AutoRightEnabled = false
        config.AutoRight = false
        if toggleSetters.AutoRight then toggleSetters.AutoRight(false, true) end
    end
    AutoLeftEnabled = true
    config.AutoLeft = true
    startStealPath(stealPath2)
end

local function stopAutoLeft()
    AutoLeftEnabled = false
    config.AutoLeft = false
    stopStealPath()
end

-- ========================================
-- HITBOX EXPANDER
-- ========================================

local hitboxConn = nil
local hitboxVisuals = {}

local function applyHitboxToPlayer(p)
    if p == player then return end
    local char = p.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    pcall(function()
        hrp.Size = Vector3.new(config.HitboxSize, config.HitboxSize, config.HitboxSize)
    end)

    local vis = Instance.new("Part")
    vis.Name = "MG_HitboxVis"
    vis.Material = Enum.Material.Neon
    vis.Color = Color3.fromRGB(138, 43, 226)
    vis.Size = Vector3.new(config.HitboxSize, config.HitboxSize * 1.8, config.HitboxSize)
    vis.Transparency = 0.78
    vis.CanCollide = false
    vis.Massless = true
    vis.CastShadow = false
    vis.Parent = workspace

    local weld = Instance.new("Weld")
    weld.Part0 = hrp
    weld.Part1 = vis
    weld.C0 = CFrame.new(0, 0, 0)
    weld.Parent = vis

    hitboxVisuals[p] = vis
end

local function removeHitboxFromPlayer(p)
    local vis = hitboxVisuals[p]
    if vis then pcall(function() vis:Destroy() end) hitboxVisuals[p] = nil end
    if p.Character then
        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
        if hrp then pcall(function() hrp.Size = Vector3.new(2, 2, 1) end) end
    end
end

local function EnableHitboxExpander()
    if hitboxConn then hitboxConn:Disconnect() hitboxConn = nil end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            applyHitboxToPlayer(p)
            p.CharacterAdded:Connect(function()
                task.wait(0.5)
                if config.HitboxExpander then applyHitboxToPlayer(p) end
            end)
        end
    end

    hitboxConn = Players.PlayerAdded:Connect(function(p)
        p.CharacterAdded:Connect(function()
            task.wait(0.5)
            if config.HitboxExpander then applyHitboxToPlayer(p) end
        end)
    end)

    task.spawn(function()
        while config.HitboxExpander do
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p.Character then
                    local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        pcall(function()
                            if hrp.Size.X < config.HitboxSize then
                                hrp.Size = Vector3.new(config.HitboxSize, config.HitboxSize, config.HitboxSize)
                            end
                        end)
                    end
                end
            end
            task.wait(0.5)
        end
    end)
end

local function DisableHitboxExpander()
    if hitboxConn then hitboxConn:Disconnect() hitboxConn = nil end
    for _, p in ipairs(Players:GetPlayers()) do
        removeHitboxFromPlayer(p)
    end
    hitboxVisuals = {}
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name == "MG_HitboxVis" then obj:Destroy() end
    end
end

-- ========================================
-- OVERHEAD SPEED LABEL
-- ========================================

local overheadSpeedGui = nil

local function EnableOverheadSpeed()
    if overheadSpeedGui then overheadSpeedGui:Destroy() overheadSpeedGui = nil end

    local function attachToChar(char)
        if overheadSpeedGui then overheadSpeedGui:Destroy() overheadSpeedGui = nil end
        local hrp = char:WaitForChild("HumanoidRootPart")
        local head = char:WaitForChild("Head")

        local bg = Instance.new("BillboardGui")
        bg.Name = "MG_OverheadSpeed"
        bg.Size = UDim2.new(0, 100, 0, 18)
        bg.StudsOffset = Vector3.new(0, 2.4, 0)
        bg.AlwaysOnTop = true
        bg.Adornee = head
        bg.ResetOnSpawn = false
        bg.LightInfluence = 0
        bg.Parent = head

        local speedLbl = Instance.new("TextLabel")
        speedLbl.Name = "SpeedValue"
        speedLbl.Size = UDim2.new(1, 0, 1, 0)
        speedLbl.BackgroundTransparency = 1
        speedLbl.Text = "âš¡ speed: 0"
        speedLbl.TextColor3 = Color3.fromRGB(190, 100, 255)
        speedLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        speedLbl.TextStrokeTransparency = 0.2
        speedLbl.TextSize = 12
        speedLbl.Font = Enum.Font.GothamBold
        speedLbl.TextXAlignment = Enum.TextXAlignment.Center
        speedLbl.Parent = bg

        overheadSpeedGui = bg

        task.spawn(function()
            while bg.Parent do
                local vel = hrp and hrp.AssemblyLinearVelocity
                local realSpd = 0
                if vel then
                    realSpd = math.floor(Vector3.new(vel.X, 0, vel.Z).Magnitude + 0.5)
                end
                speedLbl.Text = "âš¡ speed: " .. realSpd
                task.wait(0.05)
            end
            if bg and bg.Parent then bg:Destroy() end
            overheadSpeedGui = nil
        end)
    end

    if player.Character then
        task.spawn(function() attachToChar(player.Character) end)
    end

    connections["OVERHEAD_SPEED_RESPAWN"] = player.CharacterAdded:Connect(function(char)
        task.wait(1)
        if config.OverheadSpeed then attachToChar(char) end
    end)
end

local function DisableOverheadSpeed()
    if overheadSpeedGui then overheadSpeedGui:Destroy() overheadSpeedGui = nil end
    if connections["OVERHEAD_SPEED_RESPAWN"] then
        connections["OVERHEAD_SPEED_RESPAWN"]:Disconnect()
        connections["OVERHEAD_SPEED_RESPAWN"] = nil
    end
end

-- ========================================
-- FPS + PING TRACKER
-- ========================================

local mgFpsValue  = 0
local pingValue = 0
local fpsFrameCount = 0
local fpsLastTime   = tick()

RunService.Heartbeat:Connect(function()
    fpsFrameCount = fpsFrameCount + 1
    local now = tick()
    if now - fpsLastTime >= 0.5 then
        mgFpsValue = math.floor(fpsFrameCount / (now - fpsLastTime))
        fpsFrameCount = 0
        fpsLastTime = now
    end
    pcall(function()
        pingValue = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
    end)
end)

-- ========== APPLY LOADED CONFIG ==========

local function applyLoadedConfig()
    task.wait(2)
    for configKey, setter in pairs(toggleSetters) do
        if config[configKey] ~= nil and setter then pcall(function() setter(config[configKey], true) end) end
    end
    task.wait(0.5)
    if config.AutoGrab   then createCircle() enableAutoSteal() end
    if config.AutoDuel   then startDuelMovement() end
    if config.AntiRagdoll then EnableAntiRagdoll() end
    if config.AutoBat    then EnableAutoBat() end
    if config.MeleeAimbot then EnableMeleeAimbot() end
    if config.ESPPlayers then EnableESPPlayers() end
    if config.OptimizerXRay then enableOptimizer() end
    if config.NoAnimation then startUnwalk() end
    if config.SpinBot    then EnableSpinBot() end
    if config.FOVChanger then workspace.CurrentCamera.FieldOfView = config.FOV end
    if config.BatAimbot  then startBatAimbot() end
    if config.GalaxySkyBright then enableGalaxySkyBright() end
    if config.AutoLeft   then AutoLeftEnabled = true  startStealPath(stealPath2) end
    if config.AutoRight  then AutoRightEnabled = true startStealPath(stealPath1) end
    if config.HitboxExpander then EnableHitboxExpander() end
    if config.OverheadSpeed  then EnableOverheadSpeed() end
end

-- ========== MAIN GUI ==========

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MG_v21_"..tostring(math.random(1000,9999))
screenGui.ResetOnSpawn = false
protectGui(screenGui)

-- ========================================
-- TOGGLE BUTTON - Script 2 style (left side, center-vertical, square purple MG)
-- ========================================
local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 50, 0, 50)
toggleButton.Position = UDim2.new(0, 10, 0.5, -25)  -- Left side, centered vertically
toggleButton.BackgroundColor3 = theme.Primary
toggleButton.Text = "MG"
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.TextSize = 16
toggleButton.Font = Enum.Font.GothamBold
toggleButton.ZIndex = 1000
toggleButton.Parent = screenGui
Instance.new("UICorner", toggleButton).CornerRadius = UDim.new(0, 10)

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Color = Color3.fromRGB(255, 255, 255)
toggleStroke.Thickness = 2
toggleStroke.Parent = toggleButton

local toggleGlow = Instance.new("ImageLabel")
toggleGlow.Size = UDim2.new(2, 0, 2, 0)
toggleGlow.Position = UDim2.new(-0.5, 0, -0.5, 0)
toggleGlow.BackgroundTransparency = 1
toggleGlow.Image = "rbxassetid://4965945816"
toggleGlow.ImageColor3 = theme.Primary
toggleGlow.ImageTransparency = 0.6
toggleGlow.ZIndex = -1
toggleGlow.Parent = toggleButton

task.spawn(function()
    while toggleButton.Parent do
        TweenService:Create(toggleGlow, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {ImageTransparency=0.3}):Play()
        task.wait(1.5)
        TweenService:Create(toggleGlow, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {ImageTransparency=0.6}):Play()
        task.wait(1.5)
    end
end)

-- Drag logic for toggle button
do
    local tog_drag, tog_dragStart, tog_startPos = false, nil, nil
    toggleButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            tog_drag = true
            tog_dragStart = input.Position
            tog_startPos = toggleButton.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then tog_drag = false end
            end)
        end
    end)
    local tog_dragInput = nil
    toggleButton.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            tog_dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == tog_dragInput and tog_drag then
            local delta = input.Position - tog_dragStart
            toggleButton.Position = UDim2.new(tog_startPos.X.Scale, tog_startPos.X.Offset+delta.X, tog_startPos.Y.Scale, tog_startPos.Y.Offset+delta.Y)
        end
    end)
end

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0,360,0,680) mainFrame.Position = UDim2.new(0.5,-180,0,20)
mainFrame.BackgroundColor3 = Color3.fromRGB(12,12,16) mainFrame.BorderSizePixel = 0
mainFrame.Active = true mainFrame.Draggable = true mainFrame.ClipsDescendants = true
mainFrame.Visible = false mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0,14)

local shadowFrame = Instance.new("ImageLabel")
shadowFrame.Size = UDim2.new(1,30,1,30) shadowFrame.Position = UDim2.new(0,-15,0,-15)
shadowFrame.BackgroundTransparency = 1 shadowFrame.Image = "rbxassetid://297694300"
shadowFrame.ImageColor3 = Color3.fromRGB(0,0,0) shadowFrame.ImageTransparency = 0.5
shadowFrame.ScaleType = Enum.ScaleType.Slice shadowFrame.SliceCenter = Rect.new(95,95,905,905)
shadowFrame.ZIndex = -1 shadowFrame.Parent = mainFrame

local borderFrame = Instance.new("Frame")
borderFrame.Size = UDim2.new(1,4,1,4) borderFrame.Position = UDim2.new(0,-2,0,-2)
borderFrame.BackgroundColor3 = theme.Primary borderFrame.BorderSizePixel = 0 borderFrame.ZIndex = 0 borderFrame.Parent = mainFrame
Instance.new("UICorner", borderFrame).CornerRadius = UDim.new(0,14)
local borderGradient = Instance.new("UIGradient")
borderGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,theme.Primary),ColorSequenceKeypoint.new(0.5,theme.Secondary),ColorSequenceKeypoint.new(1,theme.Primary)}
borderGradient.Rotation = 0 borderGradient.Parent = borderFrame
task.spawn(function()
    while task.wait(0.03) do
        if borderGradient and borderGradient.Parent then borderGradient.Rotation = (borderGradient.Rotation+2)%360
        else break end
    end
end)

local snowContainer = Instance.new("Frame")
snowContainer.Size = UDim2.new(1,0,1,0) snowContainer.BackgroundTransparency = 1
snowContainer.ClipsDescendants = true snowContainer.ZIndex = 100 snowContainer.Parent = mainFrame

local function createSnowflake()
    if not snowContainer or not snowContainer.Parent then return end
    local sf = Instance.new("Frame")
    sf.Size = UDim2.new(0,math.random(3,8),0,math.random(3,8))
    sf.Position = UDim2.new(math.random(0,100)/100,0,0,-10)
    sf.BackgroundColor3 = Color3.fromRGB(255,255,255) sf.BackgroundTransparency = math.random(30,70)/100
    sf.BorderSizePixel = 0 sf.ZIndex = 100 sf.Parent = snowContainer
    Instance.new("UICorner", sf).CornerRadius = UDim.new(1,0)
    local t = TweenService:Create(sf, TweenInfo.new(math.random(3,6), Enum.EasingStyle.Linear), {Position=UDim2.new(sf.Position.X.Scale+math.random(-20,20)/100,0,1,10)})
    t:Play() t.Completed:Connect(function() sf:Destroy() end)
end
task.spawn(function()
    while task.wait(math.random(10,30)/100) do
        if snowContainer and snowContainer.Parent then pcall(createSnowflake) else break end
    end
end)

for i = 1, 60 do
    local ball = Instance.new("Frame", mainFrame)
    ball.Size = UDim2.new(0,math.random(2,4),0,math.random(2,4))
    ball.Position = UDim2.new(math.random(2,98)/100,0,math.random(2,98)/100,0)
    ball.BackgroundColor3 = Color3.fromRGB(100,170,255) ball.BackgroundTransparency = math.random(10,40)/100
    ball.BorderSizePixel = 0 ball.ZIndex = 2
    Instance.new("UICorner", ball).CornerRadius = UDim.new(1,0)
    task.spawn(function()
        local sx = ball.Position.X.Scale local sy = ball.Position.Y.Scale
        local ph = math.random()*math.pi*2 local sp = 0.3+math.random()*0.4
        while ball.Parent do
            local t = tick()+ph
            ball.Position = UDim2.new(math.clamp(sx+math.sin(t*sp)*0.02,0.01,0.99),0, math.clamp(sy+math.cos(t*sp*0.8)*0.015,0.01,0.99),0)
            ball.BackgroundTransparency = 0.2+math.sin(t*1.5+ph)*0.25
            task.wait(0.03)
        end
    end)
end

local headerBg = Instance.new("Frame")
headerBg.Size = UDim2.new(1,0,0,50) headerBg.BackgroundColor3 = Color3.fromRGB(18,18,22)
headerBg.BorderSizePixel = 0 headerBg.Parent = mainFrame
Instance.new("UICorner", headerBg).CornerRadius = UDim.new(0,14)

local logo = Instance.new("TextLabel")
logo.Size = UDim2.new(0,35,0,35) logo.Position = UDim2.new(0,8,0,7)
logo.BackgroundColor3 = theme.Primary logo.Text = "MG"
logo.TextColor3 = Color3.fromRGB(255,255,255) logo.TextSize = 14 logo.Font = Enum.Font.GothamBold logo.Parent = mainFrame
Instance.new("UICorner", logo).CornerRadius = UDim.new(0,8)
task.spawn(function()
    local lg = Instance.new("ImageLabel", logo)
    lg.Size = UDim2.new(2,0,2,0) lg.Position = UDim2.new(-0.5,0,-0.5,0)
    lg.BackgroundTransparency = 1 lg.Image = "rbxassetid://4965945816"
    lg.ImageColor3 = theme.Primary lg.ImageTransparency = 0.6 lg.ZIndex = -1
    while logo.Parent do
        TweenService:Create(lg, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {ImageTransparency=0.3}):Play()
        task.wait(1.5)
        TweenService:Create(lg, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {ImageTransparency=0.6}):Play()
        task.wait(1.5)
    end
end)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0,160,0,20) titleLabel.Position = UDim2.new(0,48,0,8)
titleLabel.BackgroundTransparency = 1 titleLabel.Text = "MG DUELS v2.1"
titleLabel.TextColor3 = Color3.fromRGB(255,255,255) titleLabel.TextSize = 16
titleLabel.Font = Enum.Font.GothamBold titleLabel.TextXAlignment = Enum.TextXAlignment.Left titleLabel.Parent = mainFrame

local subtitleLbl = Instance.new("TextLabel")
subtitleLbl.Size = UDim2.new(0,150,0,15) subtitleLbl.Position = UDim2.new(0,48,0,28)
subtitleLbl.BackgroundTransparency = 1 subtitleLbl.Text = "made by void"
subtitleLbl.TextColor3 = theme.Primary subtitleLbl.TextSize = 10 subtitleLbl.Font = Enum.Font.Gotham
subtitleLbl.TextXAlignment = Enum.TextXAlignment.Left subtitleLbl.Parent = mainFrame

local discordText = Instance.new("TextLabel")
discordText.Size = UDim2.new(0,150,0,40) discordText.Position = UDim2.new(1,-155,0,5)
discordText.BackgroundTransparency = 1 discordText.Text = "Discord:\ndiscord.gg/V2m8qstna"
discordText.TextColor3 = Color3.fromRGB(88,101,242) discordText.TextSize = 9
discordText.Font = Enum.Font.GothamBold discordText.TextXAlignment = Enum.TextXAlignment.Right
discordText.TextYAlignment = Enum.TextYAlignment.Center discordText.Parent = mainFrame

do
    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
    headerBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true dragStart = input.Position startPos = mainFrame.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    headerBg.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+delta.X, startPos.Y.Scale, startPos.Y.Offset+delta.Y)
        end
    end)
end

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1,-20,0,490) scrollFrame.Position = UDim2.new(0,10,0,60)
scrollFrame.BackgroundTransparency = 1 scrollFrame.ScrollBarThickness = 6
scrollFrame.ScrollBarImageColor3 = theme.Primary scrollFrame.CanvasSize = UDim2.new(0,0,0,1500)
scrollFrame.Parent = mainFrame

-- ===== GUI HELPERS =====

local function createToggle(name, icon, position, callback)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Size = UDim2.new(0,160,0,38) toggleFrame.Position = position
    toggleFrame.BackgroundColor3 = Color3.fromRGB(20,20,24) toggleFrame.BorderSizePixel = 0
    toggleFrame.Parent = scrollFrame
    Instance.new("UICorner", toggleFrame).CornerRadius = UDim.new(0,8)
    local stroke = Instance.new("UIStroke") stroke.Color = Color3.fromRGB(35,35,40) stroke.Thickness = 1 stroke.Parent = toggleFrame
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(0,25,0,25) iconLabel.Position = UDim2.new(0,6,0,6)
    iconLabel.BackgroundTransparency = 1 iconLabel.Text = icon iconLabel.TextSize = 16 iconLabel.Parent = toggleFrame
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0,80,0,25) label.Position = UDim2.new(0,35,0,6)
    label.BackgroundTransparency = 1 label.Text = name
    label.TextColor3 = Color3.fromRGB(210,210,210) label.TextSize = 10
    label.Font = Enum.Font.GothamMedium label.TextXAlignment = Enum.TextXAlignment.Left label.Parent = toggleFrame
    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0,42,0,22) toggle.Position = UDim2.new(1,-48,0,8)
    toggle.BackgroundColor3 = Color3.fromRGB(35,35,40) toggle.Text = "" toggle.Parent = toggleFrame
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(1,0)
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0,16,0,16) knob.Position = UDim2.new(0,3,0.5,-8)
    knob.BackgroundColor3 = Color3.fromRGB(160,160,160) knob.BorderSizePixel = 0 knob.Parent = toggle
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)
    local isOn = false
    local function setToggleState(state, skipCallback)
        isOn = state
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        if isOn then
            TweenService:Create(toggle, tweenInfo, {BackgroundColor3=theme.Primary}):Play()
            TweenService:Create(knob, tweenInfo, {Position=UDim2.new(1,-19,0.5,-8), BackgroundColor3=Color3.fromRGB(255,255,255)}):Play()
            TweenService:Create(stroke, tweenInfo, {Color=theme.Primary}):Play()
        else
            TweenService:Create(toggle, tweenInfo, {BackgroundColor3=Color3.fromRGB(35,35,40)}):Play()
            TweenService:Create(knob, tweenInfo, {Position=UDim2.new(0,3,0.5,-8), BackgroundColor3=Color3.fromRGB(160,160,160)}):Play()
            TweenService:Create(stroke, tweenInfo, {Color=Color3.fromRGB(35,35,40)}):Play()
        end
        if not skipCallback then callback(isOn) end
    end
    toggle.MouseButton1Click:Connect(function() setToggleState(not isOn) end)
    return toggleFrame, setToggleState
end

local function createNumberInput(name, position, default, minVal, maxVal, callback)
    local inputFrame = Instance.new("Frame")
    inputFrame.Size = UDim2.new(0,160,0,38) inputFrame.Position = position
    inputFrame.BackgroundColor3 = Color3.fromRGB(20,20,24) inputFrame.BorderSizePixel = 0
    inputFrame.Parent = scrollFrame
    Instance.new("UICorner", inputFrame).CornerRadius = UDim.new(0,8)
    local stroke = Instance.new("UIStroke") stroke.Color = Color3.fromRGB(35,35,40) stroke.Thickness = 1 stroke.Parent = inputFrame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0,88,0,38) label.Position = UDim2.new(0,8,0,0)
    label.BackgroundTransparency = 1 label.Text = name
    label.TextColor3 = Color3.fromRGB(210,210,210) label.TextSize = 10
    label.Font = Enum.Font.GothamMedium label.TextXAlignment = Enum.TextXAlignment.Left label.Parent = inputFrame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0,56,0,24) box.Position = UDim2.new(1,-62,0.5,-12)
    box.BackgroundColor3 = Color3.fromRGB(10,10,14)
    box.Text = tostring(default)
    box.TextColor3 = theme.Primary
    box.PlaceholderText = tostring(default) box.PlaceholderColor3 = Color3.fromRGB(80,80,90)
    box.TextSize = 11 box.Font = Enum.Font.GothamBold
    box.TextXAlignment = Enum.TextXAlignment.Center box.ClearTextOnFocus = false box.BorderSizePixel = 0
    box.Parent = inputFrame
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,6)
    local boxStroke = Instance.new("UIStroke") boxStroke.Color = Color3.fromRGB(50,25,80) boxStroke.Thickness = 1 boxStroke.Parent = box

    local currentVal = default
    local function applyValue()
        local num = tonumber(box.Text)
        if num then
            num = math.clamp(num, minVal, maxVal)
            currentVal = num
            box.Text = tostring(num)
            TweenService:Create(boxStroke, TweenInfo.new(0.15), {Color=theme.Primary}):Play()
            task.delay(0.6, function()
                TweenService:Create(boxStroke, TweenInfo.new(0.3), {Color=Color3.fromRGB(50,25,80)}):Play()
            end)
            callback(num)
        else
            TweenService:Create(boxStroke, TweenInfo.new(0.15), {Color=Color3.fromRGB(200,50,50)}):Play()
            task.delay(0.5, function()
                TweenService:Create(boxStroke, TweenInfo.new(0.3), {Color=Color3.fromRGB(50,25,80)}):Play()
                box.Text = tostring(currentVal)
            end)
        end
    end

    box.Focused:Connect(function()
        TweenService:Create(boxStroke, TweenInfo.new(0.15), {Color=theme.Primary}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.15), {Color=theme.Primary}):Play()
    end)
    box.FocusLost:Connect(function(enterPressed)
        TweenService:Create(boxStroke, TweenInfo.new(0.2), {Color=Color3.fromRGB(50,25,80)}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), {Color=Color3.fromRGB(35,35,40)}):Play()
        applyValue()
    end)

    return inputFrame
end

local function createActionButton(name, icon, position, callback)
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Size = UDim2.new(0,160,0,38) buttonFrame.Position = position
    buttonFrame.BackgroundColor3 = Color3.fromRGB(20,20,24) buttonFrame.BorderSizePixel = 0
    buttonFrame.Parent = scrollFrame
    Instance.new("UICorner", buttonFrame).CornerRadius = UDim.new(0,8)
    local stroke = Instance.new("UIStroke") stroke.Color = theme.Primary stroke.Thickness = 1 stroke.Parent = buttonFrame
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1,0,1,0) button.BackgroundTransparency = 1 button.Text = "" button.Parent = buttonFrame
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(0,25,0,25) iconLabel.Position = UDim2.new(0,6,0,6)
    iconLabel.BackgroundTransparency = 1 iconLabel.Text = icon iconLabel.TextSize = 16 iconLabel.Parent = buttonFrame
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0,120,0,25) label.Position = UDim2.new(0,35,0,6)
    label.BackgroundTransparency = 1 label.Text = name
    label.TextColor3 = theme.Primary label.TextSize = 12 label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left label.Parent = buttonFrame
    button.MouseButton1Click:Connect(function()
        local ti = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(buttonFrame, ti, {BackgroundColor3=theme.Primary}):Play()
        task.wait(0.1)
        TweenService:Create(buttonFrame, ti, {BackgroundColor3=Color3.fromRGB(20,20,24)}):Play()
        callback()
    end)
    return buttonFrame
end

-- ===== LEFT COLUMN TOGGLES (matching screenshot emojis) =====

local _, setSpeedBoost = createToggle("Speed Boost", "âš¡", UDim2.new(0,5,0,5), function(v)
    config.SpeedBoost = v
end)
toggleSetters.SpeedBoost = setSpeedBoost

createNumberInput("Speed", UDim2.new(0,5,0,50), 50, 16, 100, function(v) config.Speed = v end)

local _, setStealBoost = createToggle("Steal Boost", "ðŸ’¨", UDim2.new(0,5,0,95), function(v)
    config.StealBoost = v
end)
toggleSetters.StealBoost = setStealBoost
setStealBoostRef = setStealBoost

createNumberInput("Steal Spd", UDim2.new(0,5,0,140), 30, 0, 100, function(v) config.Steal = v end)

local _, setAutoDuel = createToggle("Auto Duel", "âš”ï¸", UDim2.new(0,5,0,185), function(v)
    config.AutoDuel = v
    if v then startDuelMovement() else stopDuelMovement() end
end)
toggleSetters.AutoDuel = setAutoDuel

local _, setAntiRagdoll = createToggle("Anti Ragdoll", "ðŸ›¡ï¸", UDim2.new(0,5,0,230), function(v)
    config.AntiRagdoll = v
    if v then EnableAntiRagdoll() else DisableAntiRagdoll() end
end)
toggleSetters.AntiRagdoll = setAntiRagdoll

local _, setAutoGrab = createToggle("Auto Steal", "ðŸŽ¯", UDim2.new(0,5,0,275), function(v)
    config.AutoGrab = v
    if v then createCircle() enableAutoSteal()
    else for _, p in ipairs(circleParts) do p:Destroy() end disableAutoSteal() end
end)
toggleSetters.AutoGrab = setAutoGrab

createNumberInput("Grab Radius", UDim2.new(0,5,0,320), 20, 5, 200, function(v) config.GrabRadius = v end)

local _, setBatAimbot = createToggle("Bat Aimbot", "ðŸŽ¯", UDim2.new(0,5,0,365), function(v)
    config.BatAimbot = v
    if v then startBatAimbot() else stopBatAimbot() end
end)
toggleSetters.BatAimbot = setBatAimbot

local _, setAutoLeft = createToggle("Auto Left", "â¬…ï¸", UDim2.new(0,5,0,410), function(v)
    if v then startAutoLeft() else stopAutoLeft() end
end)
toggleSetters.AutoLeft = setAutoLeft

local _, setAutoRight = createToggle("Auto Right", "âž¡ï¸", UDim2.new(0,5,0,455), function(v)
    if v then startAutoRight() else stopAutoRight() end
end)
toggleSetters.AutoRight = setAutoRight

-- Hitbox Expander (left column)
local _, setHitboxExpander = createToggle("Hitbox Exp", "ðŸŽ¯", UDim2.new(0,5,0,500), function(v)
    config.HitboxExpander = v
    if v then EnableHitboxExpander() else DisableHitboxExpander() end
end)
toggleSetters.HitboxExpander = setHitboxExpander

createNumberInput("Hitbox Sz", UDim2.new(0,5,0,545), 8, 2, 50, function(v)
    config.HitboxSize = v
    if config.HitboxExpander then
        DisableHitboxExpander()
        EnableHitboxExpander()
    end
end)

-- ===== RIGHT COLUMN TOGGLES (matching screenshot emojis) =====

createActionButton("Save Config", "ðŸ’¾", UDim2.new(0,170,0,5), function() saveConfig() end)

local setAutoBat
local _, setAutoBatRef = createToggle("Auto Bat", "âš¾", UDim2.new(0,170,0,50), function(v)
    config.AutoBat = v
    if v then EnableAutoBat() else DisableAutoBat() end
end)
setAutoBat = setAutoBatRef
toggleSetters.AutoBat = setAutoBat

local _, setMeleeAimbot = createToggle("Melee Aimbot", "ðŸ‘Š", UDim2.new(0,170,0,95), function(v)
    config.MeleeAimbot = v
    if v then EnableMeleeAimbot() else DisableMeleeAimbot() end
end)
toggleSetters.MeleeAimbot = setMeleeAimbot

local _, setESPPlayers = createToggle("ESP Players", "ðŸ‘ï¸", UDim2.new(0,170,0,140), function(v)
    config.ESPPlayers = v
    if v then EnableESPPlayers() else DisableESPPlayers() end
end)
toggleSetters.ESPPlayers = setESPPlayers

local _, setOptimizerXRay = createToggle("Optimizer+XRay", "ðŸ”§", UDim2.new(0,170,0,185), function(v)
    config.OptimizerXRay = v
    if v then enableOptimizer() else disableOptimizer() end
end)
toggleSetters.OptimizerXRay = setOptimizerXRay

local _, setNoAnimation = createToggle("No Animation", "ðŸŽ­", UDim2.new(0,170,0,230), function(v)
    config.NoAnimation = v
    if v then startUnwalk() else stopUnwalk() end
end)
toggleSetters.NoAnimation = setNoAnimation

local _, setInfiniteJump = createToggle("Infinite Jump", "ðŸš€", UDim2.new(0,170,0,275), function(v)
    config.InfiniteJump = v
end)
toggleSetters.InfiniteJump = setInfiniteJump

local _, setSpinBot = createToggle("Spin Bot", "ðŸŒ€", UDim2.new(0,170,0,320), function(v)
    config.SpinBot = v
    if v then EnableSpinBot() else DisableSpinBot() end
end)
toggleSetters.SpinBot = setSpinBot

createNumberInput("Spin Speed", UDim2.new(0,170,0,365), 10, 0, 100, function(v)
    config.SpinSpeed = v
    if config.SpinBot and player.Character then
        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
        if hrp and hrp:FindFirstChild("PanquakeSpin") then hrp.PanquakeSpin.AngularVelocity = Vector3.new(0,v,0) end
    end
end)

local _, setFOVChanger = createToggle("FOV Changer", "ðŸ”­", UDim2.new(0,170,0,410), function(v)
    config.FOVChanger = v
    if v then workspace.CurrentCamera.FieldOfView = config.FOV else workspace.CurrentCamera.FieldOfView = 70 end
end)
toggleSetters.FOVChanger = setFOVChanger

createNumberInput("FOV", UDim2.new(0,170,0,455), 70, 30, 120, function(v)
    config.FOV = v
    if config.FOVChanger then workspace.CurrentCamera.FieldOfView = v end
end)

local _, setGalaxySky = createToggle("Galaxy Sky", "ðŸŒŒ", UDim2.new(0,170,0,500), function(v)
    config.GalaxySkyBright = v
    if v then enableGalaxySkyBright() else disableGalaxySkyBright() end
end)
toggleSetters.GalaxySkyBright = setGalaxySky

-- ========================================
-- STATUS BAR (bottom of hub)
-- ========================================

local statusBarBg = Instance.new("Frame")
statusBarBg.Size = UDim2.new(1,-20,0,24)
statusBarBg.Position = UDim2.new(0,10,0,648)
statusBarBg.BackgroundColor3 = Color3.fromRGB(14,14,18)
statusBarBg.BorderSizePixel = 0
statusBarBg.ZIndex = 50
statusBarBg.Parent = mainFrame
Instance.new("UICorner", statusBarBg).CornerRadius = UDim.new(0,6)
local sbStroke = Instance.new("UIStroke") sbStroke.Color = theme.Primary sbStroke.Thickness = 1 sbStroke.Parent = statusBarBg
local statusTextLeft = Instance.new("TextLabel")
statusTextLeft.Size = UDim2.new(1,0,1,0)
statusTextLeft.BackgroundTransparency = 1
statusTextLeft.Text = "âš¡ MG DUELS v2.1 - made by void - discord.gg/V2m8qstna"
statusTextLeft.TextColor3 = theme.Primary
statusTextLeft.TextSize = 8
statusTextLeft.Font = Enum.Font.GothamBold
statusTextLeft.TextXAlignment = Enum.TextXAlignment.Center
statusTextLeft.Parent = statusBarBg

-- ========================================
-- FPS + PING WIDGET â€” TOP-CENTER OF SCREEN WITH EMOJIS
-- ========================================

local fpsPingGui = Instance.new("ScreenGui")
fpsPingGui.Name = "MG_FpsPing"
fpsPingGui.ResetOnSpawn = false
protectGui(fpsPingGui)
if not fpsPingGui.Parent then fpsPingGui.Parent = playerGui end

-- TOP-CENTER of screen
local fpsPingFrame = Instance.new("Frame")
fpsPingFrame.Size = UDim2.new(0, 160, 0, 72)
fpsPingFrame.Position = UDim2.new(0.5, -80, 0, 8)  -- Top center, small top offset
fpsPingFrame.BackgroundColor3 = Color3.fromRGB(10, 8, 16)
fpsPingFrame.BorderSizePixel = 0
fpsPingFrame.ZIndex = 500
fpsPingFrame.Active = true
fpsPingFrame.Parent = fpsPingGui
Instance.new("UICorner", fpsPingFrame).CornerRadius = UDim.new(0, 10)

-- Drag logic for stats widget
local fpsDragging, fpsDragStart, fpsDragStartPos = false, nil, nil
fpsPingFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        fpsDragging = true
        fpsDragStart = input.Position
        fpsDragStartPos = fpsPingFrame.Position
    end
end)
fpsPingFrame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        fpsDragging = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if fpsDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - fpsDragStart
        fpsPingFrame.Position = UDim2.new(
            fpsDragStartPos.X.Scale, fpsDragStartPos.X.Offset + delta.X,
            fpsDragStartPos.Y.Scale, fpsDragStartPos.Y.Offset + delta.Y
        )
    end
end)

local fpsPingStroke = Instance.new("UIStroke")
fpsPingStroke.Color = Color3.fromRGB(138, 43, 226)
fpsPingStroke.Thickness = 1.5
fpsPingStroke.Parent = fpsPingFrame

-- Pulse glow on the stats widget
task.spawn(function()
    while fpsPingFrame.Parent do
        TweenService:Create(fpsPingStroke, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Color = Color3.fromRGB(180, 80, 255)}):Play()
        task.wait(1.2)
        TweenService:Create(fpsPingStroke, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Color = Color3.fromRGB(100, 20, 180)}):Play()
        task.wait(1.2)
    end
end)

-- Title row with emoji
local fpsPingTitle = Instance.new("TextLabel")
fpsPingTitle.Size = UDim2.new(1, 0, 0, 18)
fpsPingTitle.Position = UDim2.new(0, 0, 0, 4)
fpsPingTitle.BackgroundTransparency = 1
fpsPingTitle.Text = "ðŸ“Š MG STATS"
fpsPingTitle.TextColor3 = Color3.fromRGB(138, 43, 226)
fpsPingTitle.TextSize = 9
fpsPingTitle.Font = Enum.Font.GothamBold
fpsPingTitle.TextXAlignment = Enum.TextXAlignment.Center
fpsPingTitle.ZIndex = 501
fpsPingTitle.Parent = fpsPingFrame

local titleDiv = Instance.new("Frame")
titleDiv.Size = UDim2.new(0.85, 0, 0, 1)
titleDiv.Position = UDim2.new(0.075, 0, 0, 22)
titleDiv.BackgroundColor3 = Color3.fromRGB(60, 30, 90)
titleDiv.BorderSizePixel = 0
titleDiv.ZIndex = 501
titleDiv.Parent = fpsPingFrame

-- FPS row with emoji
local fpsRowLbl = Instance.new("TextLabel")
fpsRowLbl.Size = UDim2.new(0.5, -4, 0, 30)
fpsRowLbl.Position = UDim2.new(0, 8, 0, 28)
fpsRowLbl.BackgroundTransparency = 1
fpsRowLbl.Text = "ðŸ–¥ï¸ FPS  --"
fpsRowLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
fpsRowLbl.TextSize = 11
fpsRowLbl.Font = Enum.Font.GothamBold
fpsRowLbl.TextXAlignment = Enum.TextXAlignment.Left
fpsRowLbl.ZIndex = 501
fpsRowLbl.Parent = fpsPingFrame

local midDiv = Instance.new("Frame")
midDiv.Size = UDim2.new(0, 1, 0, 34)
midDiv.Position = UDim2.new(0.5, 0, 0, 26)
midDiv.BackgroundColor3 = Color3.fromRGB(60, 30, 90)
midDiv.BorderSizePixel = 0
midDiv.ZIndex = 501
midDiv.Parent = fpsPingFrame

-- Ping row with emoji
local pingRowLbl = Instance.new("TextLabel")
pingRowLbl.Size = UDim2.new(0.5, -4, 0, 30)
pingRowLbl.Position = UDim2.new(0.5, 4, 0, 28)
pingRowLbl.BackgroundTransparency = 1
pingRowLbl.Text = "ðŸ“¶ PING  --"
pingRowLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
pingRowLbl.TextSize = 11
pingRowLbl.Font = Enum.Font.GothamBold
pingRowLbl.TextXAlignment = Enum.TextXAlignment.Left
pingRowLbl.ZIndex = 501
pingRowLbl.Parent = fpsPingFrame

-- Bottom divider line
local bottomDivStats = Instance.new("Frame")
bottomDivStats.Size = UDim2.new(0.85, 0, 0, 1)
bottomDivStats.Position = UDim2.new(0.075, 0, 0, 60)
bottomDivStats.BackgroundColor3 = Color3.fromRGB(60, 30, 90)
bottomDivStats.BorderSizePixel = 0
bottomDivStats.ZIndex = 501
bottomDivStats.Parent = fpsPingFrame

-- Live update loop
task.spawn(function()
    while fpsPingFrame.Parent do
        task.wait(0.5)
        local fps = mgFpsValue
        local fpsColor
        if fps >= 55 then fpsColor = Color3.fromRGB(100, 255, 130)
        elseif fps >= 30 then fpsColor = Color3.fromRGB(255, 210, 50)
        else fpsColor = Color3.fromRGB(255, 70, 70) end
        fpsRowLbl.Text = "ðŸ–¥ï¸ FPS  " .. fps
        fpsRowLbl.TextColor3 = fpsColor

        local ping = pingValue
        local pingColor
        if ping <= 80 then pingColor = Color3.fromRGB(100, 255, 130)
        elseif ping <= 150 then pingColor = Color3.fromRGB(255, 210, 50)
        else pingColor = Color3.fromRGB(255, 70, 70) end
        pingRowLbl.Text = "ðŸ“¶ PING  " .. ping .. "ms"
        pingRowLbl.TextColor3 = pingColor
    end
end)

-- ========================================
-- TOGGLE BUTTON CLICK â€” open/close main frame
-- ========================================

toggleButton.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
    if mainFrame.Visible then
        TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size=UDim2.new(0,360,0,680)}):Play()
    end
end)

-- ========== SIDE BUTTONS ==========

local SideStrip = Instance.new("Frame")
SideStrip.Name = "SideStrip"
SideStrip.Size = UDim2.new(0, 58, 0, 226)
SideStrip.Position = UDim2.new(1, -66, 0, 8)
SideStrip.BackgroundTransparency = 1
SideStrip.ZIndex = 200
SideStrip.Parent = screenGui

local dragHandle = Instance.new("Frame")
dragHandle.Name = "DragHandle"
dragHandle.Size = UDim2.new(1, 0, 0, 18)
dragHandle.Position = UDim2.new(0, 0, 0, 0)
dragHandle.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
dragHandle.BorderSizePixel = 0
dragHandle.ZIndex = 205
dragHandle.Parent = SideStrip
Instance.new("UICorner", dragHandle).CornerRadius = UDim.new(0, 6)
local dhs = Instance.new("UIStroke") dhs.Color = theme.Primary dhs.Thickness = 1 dhs.Parent = dragHandle
local dhl = Instance.new("TextLabel")
dhl.Size = UDim2.new(1, 0, 1, 0)
dhl.BackgroundTransparency = 1
dhl.Text = "â ¿ drag"
dhl.TextColor3 = Color3.fromRGB(160, 160, 160)
dhl.TextSize = 8
dhl.Font = Enum.Font.GothamBold
dhl.TextXAlignment = Enum.TextXAlignment.Center
dhl.ZIndex = 206
dhl.Parent = dragHandle

do
    local ssDragging, ssDragStart, ssStartPos = false, nil, nil
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            ssDragging = true ssDragStart = input.Position ssStartPos = SideStrip.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not ssDragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - ssDragStart
            SideStrip.Position = UDim2.new(ssStartPos.X.Scale, ssStartPos.X.Offset+delta.X, ssStartPos.Y.Scale, ssStartPos.Y.Offset+delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then ssDragging = false end
    end)
end

local tweenFast = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function makePurpleSideBtn(labelText, yOffset, iconText)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 44, 0, 44)
    btn.Position = UDim2.new(0, 7, 0, yOffset)
    btn.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Text = ""
    btn.ZIndex = 201
    btn.Parent = SideStrip
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 9)
    local stroke = Instance.new("UIStroke") stroke.Color = Color3.fromRGB(35, 35, 40) stroke.Thickness = 1.5 stroke.Parent = btn
    local glow = Instance.new("ImageLabel")
    glow.Size = UDim2.new(1.6, 0, 1.6, 0) glow.Position = UDim2.new(-0.3, 0, -0.3, 0)
    glow.BackgroundTransparency = 1 glow.Image = "rbxassetid://4965945816"
    glow.ImageColor3 = Color3.fromRGB(138, 43, 226) glow.ImageTransparency = 0.85 glow.ZIndex = 200 glow.Parent = btn
    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(1, 0, 0, 18) icon.Position = UDim2.new(0, 0, 0, 4)
    icon.BackgroundTransparency = 1 icon.Text = iconText icon.TextSize = 16
    icon.TextXAlignment = Enum.TextXAlignment.Center icon.ZIndex = 202 icon.Parent = btn
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -2, 0, 18) lbl.Position = UDim2.new(0, 1, 0, 22)
    lbl.BackgroundTransparency = 1 lbl.Text = labelText
    lbl.TextColor3 = Color3.fromRGB(180, 180, 180) lbl.TextSize = 6.5 lbl.Font = Enum.Font.GothamBold
    lbl.TextWrapped = true lbl.TextXAlignment = Enum.TextXAlignment.Center lbl.ZIndex = 202 lbl.Parent = btn
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 6, 0, 6) dot.Position = UDim2.new(1, -9, 0, 3)
    dot.BackgroundColor3 = Color3.fromRGB(40, 40, 45) dot.BorderSizePixel = 0 dot.ZIndex = 203 dot.Parent = btn
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    return btn, stroke, lbl, dot, glow
end

local function activateSideBtn(stroke, lbl, dot, glow)
    TweenService:Create(stroke, tweenFast, {Color=Color3.fromRGB(138,43,226)}):Play()
    TweenService:Create(lbl, tweenFast, {TextColor3=Color3.fromRGB(255,255,255)}):Play()
    TweenService:Create(dot, tweenFast, {BackgroundColor3=Color3.fromRGB(138,43,226)}):Play()
    TweenService:Create(glow, tweenFast, {ImageTransparency=0.55}):Play()
end

local function deactivateSideBtn(stroke, lbl, dot, glow)
    TweenService:Create(stroke, tweenFast, {Color=Color3.fromRGB(35,35,40)}):Play()
    TweenService:Create(lbl, tweenFast, {TextColor3=Color3.fromRGB(180,180,180)}):Play()
    TweenService:Create(dot, tweenFast, {BackgroundColor3=Color3.fromRGB(40,40,45)}):Play()
    TweenService:Create(glow, tweenFast, {ImageTransparency=0.85}):Play()
end

-- Side buttons: AUTO LEFT, AUTO DUEL, AUTO RIGHT, BAT AIMBOT (matching screenshots)
local BtnSideLeft,   StrokeSideLeft,   LblSideLeft,   DotSideLeft,   GlowSideLeft   = makePurpleSideBtn("AUTO\nLEFT",   22,  "â¬…ï¸")
local BtnSideDuel,   StrokeSideDuel,   LblSideDuel,   DotSideDuel,   GlowSideDuel   = makePurpleSideBtn("AUTO\nDUEL",   72,  "âš”ï¸")
local BtnSideRight,  StrokeSideRight,  LblSideRight,  DotSideRight,  GlowSideRight  = makePurpleSideBtn("AUTO\nRIGHT",  122, "âž¡ï¸")
local BtnSideBatAim, StrokeSideBatAim, LblSideBatAim, DotSideBatAim, GlowSideBatAim = makePurpleSideBtn("BAT\nAIMBOT", 172, "ðŸŽ¯")

SideStrip.Size = UDim2.new(0, 58, 0, 222)

-- ===== SIDE BUTTON CLICK HANDLERS =====

BtnSideLeft.MouseButton1Click:Connect(function()
    if AutoLeftEnabled then
        stopAutoLeft()
        deactivateSideBtn(StrokeSideLeft,LblSideLeft,DotSideLeft,GlowSideLeft)
        if toggleSetters.AutoLeft then toggleSetters.AutoLeft(false, true) end
    else
        if AutoRightEnabled then
            stopStealPath()
            AutoRightEnabled = false
            config.AutoRight = false
            deactivateSideBtn(StrokeSideRight,LblSideRight,DotSideRight,GlowSideRight)
            if toggleSetters.AutoRight then toggleSetters.AutoRight(false, true) end
        end
        AutoLeftEnabled = true
        config.AutoLeft = true
        startStealPath(stealPath2)
        activateSideBtn(StrokeSideLeft,LblSideLeft,DotSideLeft,GlowSideLeft)
        if toggleSetters.AutoLeft then toggleSetters.AutoLeft(true, true) end
    end
end)

BtnSideDuel.MouseButton1Click:Connect(function()
    config.AutoDuel = not config.AutoDuel
    if config.AutoDuel then activateSideBtn(StrokeSideDuel,LblSideDuel,DotSideDuel,GlowSideDuel) startDuelMovement()
    else deactivateSideBtn(StrokeSideDuel,LblSideDuel,DotSideDuel,GlowSideDuel) stopDuelMovement() end
end)

BtnSideRight.MouseButton1Click:Connect(function()
    if AutoRightEnabled then
        stopAutoRight()
        deactivateSideBtn(StrokeSideRight,LblSideRight,DotSideRight,GlowSideRight)
        if toggleSetters.AutoRight then toggleSetters.AutoRight(false, true) end
    else
        if AutoLeftEnabled then
            stopStealPath()
            AutoLeftEnabled = false
            config.AutoLeft = false
            deactivateSideBtn(StrokeSideLeft,LblSideLeft,DotSideLeft,GlowSideLeft)
            if toggleSetters.AutoLeft then toggleSetters.AutoLeft(false, true) end
        end
        AutoRightEnabled = true
        config.AutoRight = true
        startStealPath(stealPath1)
        activateSideBtn(StrokeSideRight,LblSideRight,DotSideRight,GlowSideRight)
        if toggleSetters.AutoRight then toggleSetters.AutoRight(true, true) end
    end
end)

BtnSideBatAim.MouseButton1Click:Connect(function()
    config.BatAimbot = not config.BatAimbot
    if config.BatAimbot then
        activateSideBtn(StrokeSideBatAim,LblSideBatAim,DotSideBatAim,GlowSideBatAim)
        startBatAimbot()
        if not config.AutoBat then config.AutoBat = true if setAutoBat then setAutoBat(true,true) end EnableAutoBat() end
    else
        deactivateSideBtn(StrokeSideBatAim,LblSideBatAim,DotSideBatAim,GlowSideBatAim)
        stopBatAimbot()
        if config.AutoBat then config.AutoBat = false if setAutoBat then setAutoBat(false,true) end DisableAutoBat() end
    end
end)

-- Sync side button visuals every frame
RunService.Heartbeat:Connect(function()
    if not AutoLeftEnabled   and DotSideLeft.BackgroundColor3   ~= Color3.fromRGB(40,40,45) then deactivateSideBtn(StrokeSideLeft,LblSideLeft,DotSideLeft,GlowSideLeft) end
    if not AutoRightEnabled  and DotSideRight.BackgroundColor3  ~= Color3.fromRGB(40,40,45) then deactivateSideBtn(StrokeSideRight,LblSideRight,DotSideRight,GlowSideRight) end
    if not config.AutoDuel   and DotSideDuel.BackgroundColor3   ~= Color3.fromRGB(40,40,45) then deactivateSideBtn(StrokeSideDuel,LblSideDuel,DotSideDuel,GlowSideDuel) end
    if not config.BatAimbot  and DotSideBatAim.BackgroundColor3 ~= Color3.fromRGB(40,40,45) then deactivateSideBtn(StrokeSideBatAim,LblSideBatAim,DotSideBatAim,GlowSideBatAim) end
end)

-- ========== MAIN SPEED LOOP ==========

RunService.Heartbeat:Connect(function()
    local currentSpeed = config.StealBoost and config.Steal or (config.SpeedBoost and config.Speed or 0)
    if currentSpeed > 0 then
        local character = player.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if humanoid and hrp then
                local moveDir = humanoid.MoveDirection
                if moveDir.Magnitude > 0 then
                    hrp.AssemblyLinearVelocity = Vector3.new(moveDir.X*currentSpeed, hrp.AssemblyLinearVelocity.Y, moveDir.Z*currentSpeed)
                end
            end
        end
    end
end)

-- Circle renderer
RunService.RenderStepped:Connect(function()
    if not config.AutoGrab and not config.AutoDuel then return end
    local hrp = autoSteal_getHRP()
    if not hrp then return end
    if #circleParts == 0 then createCircle() end
    for i, p in ipairs(circleParts) do
        local a1 = math.rad((i-1)/PartsCount*360)
        local a2 = math.rad(i/PartsCount*360)
        local p1 = Vector3.new(math.cos(a1),0,math.sin(a1))*config.GrabRadius
        local p2 = Vector3.new(math.cos(a2),0,math.sin(a2))*config.GrabRadius
        local c  = (p1+p2)/2 + hrp.Position
        p.Size   = Vector3.new((p2-p1).Magnitude, 0.2, 0.3)
        p.CFrame = CFrame.new(c, c+Vector3.new(p2.X-p1.X,0,p2.Z-p1.Z))*CFrame.Angles(0,math.pi/2,0)
    end
end)

-- Character respawn handling
player.CharacterAdded:Connect(function()
    task.wait(1)
    if config.AutoGrab or config.AutoDuel then createCircle() end
    if config.NoAnimation then startUnwalk() end
    stopInfiniteJump() startInfiniteJump()
    if config.AutoGrab then stopAutoStealLoop() task.wait(0.5) startAutoStealLoop() end
    if config.AntiRagdoll then task.wait(0.5) arCacheCharacterData() end
    if config.MeleeAimbot then
        DisableMeleeAimbot()
        task.wait(0.5)
        EnableMeleeAimbot()
    end
end)

loadConfig()
task.spawn(applyLoadedConfig)

-- Overhead speed always starts automatically
task.spawn(function()
    task.wait(1)
    EnableOverheadSpeed()
end)

print("âœ¨ MG DUELS v2.1 Final - made by void")
print("ðŸ”µ Toggle: Script 2 style (left side, purple square MG)")
print("ðŸ“Š MG Stats: Top-center with emojis (ðŸ“Š ðŸ–¥ï¸ ðŸ“¶)")
print("â¬…ï¸âž¡ï¸ Side buttons with correct emojis")
print("ðŸŽ® All v2.1 features: Hitbox Expander, Overhead Speed, FPS+Ping")
print("ðŸ’¬ discord.gg/V2m8qstna")
