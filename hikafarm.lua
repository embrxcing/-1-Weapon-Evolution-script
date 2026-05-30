local player = game.Players.LocalPlayer
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")

local enabled = false
local farmRunning = false
local routeRunning = false
local runToken = 0

local POS_CASH = Vector3.new(2927, 4, -4)
local POS_SWORD = Vector3.new(57, 6, 48)
local POS_TRAIN = Vector3.new(148, 5, -61)

local function isActive(token)
    return enabled and runToken == token
end

local function safeWait(seconds, token)
    local start = tick()
    while tick() - start < seconds do
        if not isActive(token) then
            return false
        end
        task.wait(0.03)
    end
    return true
end

local function enablePotatoMode()
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        local lighting = game:GetService("Lighting")
        lighting.GlobalShadows = false
        lighting.FogEnd = 999999
        lighting.Brightness = 2
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") then
                v.Material = Enum.Material.SmoothPlastic
            end
        end
    end)
end

local function antiAFK()
    local VirtualUser = game:GetService("VirtualUser")

    player.Idled:Connect(function()
        if enabled then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end)
end

local function removeRebirthWarning()
    task.spawn(function()
        while true do
            pcall(function()
                local container = player.PlayerGui:FindFirstChild("NotificationsContainer")
                if container then
                    for _, v in pairs(container:GetChildren()) do
                        if v:IsA("TextLabel") then
                            local text = string.lower(v.Text or "")
                            if string.find(text, "not enough") or string.find(text, "rebirth") then
                                v.Visible = false
                                v.TextTransparency = 1
                                v.BackgroundTransparency = 1
                                v.Size = UDim2.new(0, 1, 0, 1)
                            end
                        end
                    end
                end
            end)
            task.wait(0.03)
        end
    end)
end

local function getRebirthFrame()
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local gameUI = pg:FindFirstChild("GameUI")
    if not gameUI then return nil end
    return gameUI:FindFirstChild("RebirthFrame")
end

local function getCurrentRebirthValue()
    local frame = getRebirthFrame()
    if not frame then return nil end
    local label = frame:FindFirstChild("CurrentRebirth")
    if not label then return nil end
    local text = tostring(label.Text or "")
    text = text:gsub(",", "")
    local lastNumber = nil
    for num in text:gmatch("%d+") do
        lastNumber = tonumber(num)
    end
    return lastNumber
end

local function clickRebirthButton()
    local frame = getRebirthFrame()
    if not frame then return false end
    local rebirthList = frame:FindFirstChild("RebirthList")
    if not rebirthList then return false end
    local button = rebirthList:FindFirstChild("Rebirth")
    if not button then return false end
    pcall(function() firesignal(button.Activated) end)
    pcall(function() button:Activate() end)
    pcall(function() firesignal(button.MouseButton1Click) end)
    pcall(function() button.MouseButton1Click:Fire() end)
    return true
end

local function getHRP()
    local char = player.Character
    if not char then
        char = player.CharacterAdded:Wait()
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        hrp = char:WaitForChild("HumanoidRootPart", 5)
    end
    return hrp
end

local function lockAtTrain(token)
    task.spawn(function()
        while isActive(token) do
            if not routeRunning then
                local hrp = getHRP()
                if hrp and hrp.Parent then
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                    hrp.CFrame = CFrame.new(POS_TRAIN)
                end
            end
            task.wait(0.12)
        end
    end)
end

local function tinyCircleMovement(token)
    local hrp = getHRP()
    if not hrp then return end
    local radius = 0.12
    local steps = 8
    for i = 1, steps do
        if not isActive(token) then return end
        hrp = getHRP()
        if not hrp or not hrp.Parent then return end
        local angle = math.rad((360 / steps) * i)
        local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
        hrp.CFrame = hrp.CFrame + offset
        task.wait(0.03)
    end
end

local function teleportInstant(pos, token, doMovement)
    if not isActive(token) then return false end
    local hrp = getHRP()
    if not hrp then return false end
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    hrp.CFrame = CFrame.new(pos)
    task.wait(0.05)
    hrp = getHRP()
    if hrp and hrp.Parent then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.CFrame = CFrame.new(pos)
    end
    if doMovement then
        tinyCircleMovement(token)
    end
    return true
end

local function doRewardRoute(token)
    if routeRunning then return end
    routeRunning = true
    if not safeWait(2.5, token) then
        routeRunning = false
        return
    end
    teleportInstant(POS_CASH, token, true)
    if not safeWait(0.5, token) then
        routeRunning = false
        return
    end
    teleportInstant(POS_SWORD, token, false)
    if not safeWait(1, token) then
        routeRunning = false
        return
    end
    teleportInstant(POS_TRAIN, token, false)
    routeRunning = false
end

local function startFarm()
    if farmRunning then return end
    enabled = true
    farmRunning = true
    routeRunning = false
    runToken += 1
    local token = runToken
    task.spawn(function()
        teleportInstant(POS_TRAIN, token, false)
        lockAtTrain(token)
        local lastRebirth = getCurrentRebirthValue()
        while isActive(token) do
            clickRebirthButton()
            local currentRebirth = getCurrentRebirthValue()
            if currentRebirth and lastRebirth and currentRebirth > lastRebirth then
                lastRebirth = currentRebirth
                if not routeRunning then
                    task.spawn(function()
                        doRewardRoute(token)
                    end)
                end
            elseif currentRebirth and not lastRebirth then
                lastRebirth = currentRebirth
            end
            task.wait(0.2)
        end
        farmRunning = false
        routeRunning = false
    end)
end

local function stopFarm()
    enabled = false
    farmRunning = false
    routeRunning = false
    runToken += 1
end

local sg = Instance.new("ScreenGui")
sg.ResetOnSpawn = false
sg.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 280, 0, 120)
frame.Position = UDim2.new(0.5, -140, 0.5, -60)
frame.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
frame.BorderSizePixel = 0
frame.Draggable = true
frame.Active = true
frame.Parent = sg

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 18)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(120, 80, 255)
stroke.Transparency = 0.25
stroke.Parent = frame

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 25, 38)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(45, 30, 90))
})
gradient.Rotation = 35
gradient.Parent = frame

local scale = Instance.new("UIScale")
scale.Scale = 1
scale.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -24, 0, 42)
title.Position = UDim2.new(0, 12, 0, 10)
title.BackgroundTransparency = 1
title.Text = "Hika's Auto Farm Script"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = frame

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1, -30, 0, 48)
btn.Position = UDim2.new(0, 15, 0, 60)
btn.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
btn.Text = "START"
btn.TextColor3 = Color3.fromRGB(255, 255, 255)
btn.TextScaled = true
btn.Font = Enum.Font.GothamBlack
btn.AutoButtonColor = false
btn.Parent = frame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 14)
btnCorner.Parent = btn

local btnStroke = Instance.new("UIStroke")
btnStroke.Thickness = 1.5
btnStroke.Color = Color3.fromRGB(255, 255, 255)
btnStroke.Transparency = 0.65
btnStroke.Parent = btn

local clickSound = Instance.new("Sound")
clickSound.SoundId = "rbxassetid://12221967"
clickSound.Volume = 0.55
clickSound.Parent = btn

local function animateButton()
    pcall(function()
        clickSound:Play()
    end)
    TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.94}):Play()
    task.wait(0.08)
    TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
end

local function setButtonState()
    if enabled then
        btn.Text = "STOP"
        TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundColor3 = Color3.fromRGB(220, 70, 90)
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Color = Color3.fromRGB(255, 90, 120)
        }):Play()
    else
        btn.Text = "START"
        TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundColor3 = Color3.fromRGB(80, 200, 120)
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Color = Color3.fromRGB(120, 80, 255)
        }):Play()
    end
end

btn.MouseButton1Click:Connect(function()
    animateButton()
    if enabled then
        stopFarm()
    else
        startFarm()
    end
    setButtonState()
end)

enablePotatoMode()
antiAFK()
removeRebirthWarning()

print("✅ Script Loaded")
