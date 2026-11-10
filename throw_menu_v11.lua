task.wait(2)

local Players    = game:GetService("Players")
local lp         = Players.LocalPlayer
local RS         = game:GetService("ReplicatedStorage")
local UIS        = game:GetService("UserInputService")
local VIM        = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

-- Remotes
local Remotes        = RS:WaitForChild("Remotes", 10)
local ThrowMeter     = Remotes:WaitForChild("Throw_MeterStarted", 5)
local SetThrowPower  = Remotes:WaitForChild("Player_SetThrowPower", 5)
local Training_Start = Remotes:WaitForChild("Training_Start", 5)
local Training_Stop  = Remotes:WaitForChild("Training_Stop", 5)
local Training_Bonus = Remotes:WaitForChild("Training_TapBonus", 5)

-- إحداثيات مؤكدة
local THROW_POS = Vector3.new(0, 5.6, -45.0)
local TRAIN_POS = Vector3.new(-60.2, 5.5, -16.0)

-- Helpers
local function getRoot()
    return lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
end

local function teleport(pos)
    local root = getRoot()
    if root then root.CFrame = CFrame.new(pos) end
end

local function getScreenCenter()
    local cam = workspace.CurrentCamera
    if cam then return cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2 end
    return 400, 300
end

local function simulateTap(x, y)
    pcall(function()
        VIM:SendMouseButtonEvent(x, y, 0, true,  game, 0)
        task.wait(0.04)
        VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
    pcall(function()
        VIM:SendTouchEvent(0, Vector2.new(x, y), Enum.UserInputState.Begin)
        task.wait(0.04)
        VIM:SendTouchEvent(0, Vector2.new(x, y), Enum.UserInputState.End)
    end)
end

-- ===== PERFECT THROW SYSTEM =====
-- يراقب ProgressBar أو RingScoreLabel في GUI
-- عندما يصل البار لأعلى = perfect = يضغط
local function findMeterBar()
    for _, v in pairs(lp.PlayerGui:GetDescendants()) do
        if v.Name == "ProgressBar" and v:IsA("Frame") then
            return v
        end
    end
    return nil
end

local function findRingScore()
    for _, v in pairs(lp.PlayerGui:GetDescendants()) do
        if v.Name == "RingScoreLabel" and v:IsA("TextLabel") then
            return v
        end
    end
    return nil
end

-- perfect mode: يراقب البار ويضغط عند max
local perfectOn = false
local perfectConn = nil

local function startPerfectWatch(onPerfect)
    if perfectConn then perfectConn:Disconnect() end
    perfectConn = RunService.Heartbeat:Connect(function()
        if not perfectOn then return end
        -- طريقة 1: راقب ProgressBar
        local bar = findMeterBar()
        if bar then
            -- البار الممتلئ = Size.X.Scale قريب من 1
            if bar.Size.X.Scale >= 0.85 then
                if onPerfect then onPerfect() end
                return
            end
        end
        -- طريقة 2: راقب RingScoreLabel
        local scoreLabel = findRingScore()
        if scoreLabel then
            local txt = scoreLabel.Text
            local num = tonumber(txt:match("%d+"))
            if num and num >= 18 then
                if onPerfect then onPerfect() end
                return
            end
        end
    end)
end

-- STATE
local autoOn    = false
local trainOn   = false
local customPow = 999999
local throwCount = 0
local trainCount = 0
local throwDelay = 1.5

-- ===== GUI =====
-- احذف أي menu قديم
for _, v in pairs(game.CoreGui:GetChildren()) do
    if v.Name:find("ThrowFinal") or v.Name:find("ThrowMenu") then v:Destroy() end
end
pcall(function()
    for _, v in pairs(lp.PlayerGui:GetChildren()) do
        if v.Name:find("ThrowFinal") or v.Name:find("ThrowMenu") then v:Destroy() end
    end
end)

local sg = Instance.new("ScreenGui")
sg.Name = "ThrowFinal_"..math.random(10000,99999)
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
pcall(function()
    if syn then syn.protect_gui(sg) end
    sg.Parent = game.CoreGui
end)
if sg.Parent ~= game.CoreGui then sg.Parent = lp.PlayerGui end

-- Main — أفقي عريض
local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 580, 0, 200)
Main.Position = UDim2.new(0.5, -290, 1, -215)
Main.BackgroundColor3 = Color3.fromRGB(8, 8, 18)
Main.BorderSizePixel = 0
Main.Parent = sg
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 16)
local ms = Instance.new("UIStroke", Main)
ms.Color = Color3.fromRGB(100, 60, 220)
ms.Thickness = 2

-- Title Bar
local TB = Instance.new("Frame")
TB.Size = UDim2.new(1, 0, 0, 36)
TB.BackgroundColor3 = Color3.fromRGB(50, 15, 130)
TB.BorderSizePixel = 0
TB.Parent = Main
Instance.new("UICorner", TB).CornerRadius = UDim.new(0, 16)
local tbg = Instance.new("UIGradient", TB)
tbg.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(110, 50, 230)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(40,  10, 110))
})
tbg.Rotation = 90

local TTxt = Instance.new("TextLabel")
TTxt.Text = "🌿  THROW MENU  v11"
TTxt.Size = UDim2.new(1, -100, 1, 0)
TTxt.Position = UDim2.new(0, 14, 0, 0)
TTxt.BackgroundTransparency = 1
TTxt.TextColor3 = Color3.new(1, 1, 1)
TTxt.TextSize = 13
TTxt.Font = Enum.Font.GothamBold
TTxt.TextXAlignment = Enum.TextXAlignment.Left
TTxt.Parent = TB

-- موقع اللاعب في العنوان
local PosTxt = Instance.new("TextLabel")
PosTxt.Size = UDim2.new(0, 160, 1, 0)
PosTxt.Position = UDim2.new(1, -260, 0, 0)
PosTxt.BackgroundTransparency = 1
PosTxt.TextColor3 = Color3.fromRGB(120, 120, 180)
PosTxt.TextSize = 8
PosTxt.Font = Enum.Font.Gotham
PosTxt.TextXAlignment = Enum.TextXAlignment.Right
PosTxt.Parent = TB

task.spawn(function()
    while true do
        task.wait(0.5)
        local root = getRoot()
        if root then
            local p = root.Position
            PosTxt.Text = string.format("X:%.0f Y:%.0f Z:%.0f", p.X, p.Y, p.Z)
        end
    end
end)

local MinBtn = Instance.new("TextButton")
MinBtn.Text = "—"
MinBtn.Size = UDim2.new(0, 24, 0, 18)
MinBtn.Position = UDim2.new(1, -54, 0.5, -9)
MinBtn.BackgroundColor3 = Color3.fromRGB(50, 30, 100)
MinBtn.TextColor3 = Color3.new(1, 1, 1)
MinBtn.TextSize = 11
MinBtn.Font = Enum.Font.GothamBold
MinBtn.BorderSizePixel = 0
MinBtn.Parent = TB
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 5)

local XBtn = Instance.new("TextButton")
XBtn.Text = "✕"
XBtn.Size = UDim2.new(0, 24, 0, 18)
XBtn.Position = UDim2.new(1, -26, 0.5, -9)
XBtn.BackgroundColor3 = Color3.fromRGB(180, 30, 50)
XBtn.TextColor3 = Color3.new(1, 1, 1)
XBtn.TextSize = 11
XBtn.Font = Enum.Font.GothamBold
XBtn.BorderSizePixel = 0
XBtn.Parent = TB
Instance.new("UICorner", XBtn).CornerRadius = UDim.new(0, 5)

-- Content — أعمدة أفقية
local C = Instance.new("Frame")
C.Size = UDim2.new(1, -16, 1, -44)
C.Position = UDim2.new(0, 8, 0, 38)
C.BackgroundTransparency = 1
C.Parent = Main

-- دالة إنشاء عمود
local function makeColumn(x, w)
    local col = Instance.new("Frame")
    col.Size = UDim2.new(0, w, 1, 0)
    col.Position = UDim2.new(0, x, 0, 0)
    col.BackgroundTransparency = 1
    col.Parent = C
    return col
end

-- دالة زر كبير
local function makeBigBtn(parent, txt, y, h, col1, col2)
    local b = Instance.new("TextButton")
    b.Text = txt
    b.Size = UDim2.new(1, 0, 0, h)
    b.Position = UDim2.new(0, 0, 0, y)
    b.BackgroundColor3 = col1
    b.TextColor3 = Color3.new(1, 1, 1)
    b.TextSize = 11
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    local st = Instance.new("UIStroke", b)
    st.Color = col2 or col1
    st.Thickness = 1.2
    local grad = Instance.new("UIGradient", b)
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, col1),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(
            math.floor(col1.R*255*0.6),
            math.floor(col1.G*255*0.6),
            math.floor(col1.B*255*0.6)
        ))
    })
    grad.Rotation = 90
    return b, st
end

local function makeLbl(parent, txt, y, color)
    local l = Instance.new("TextLabel")
    l.Text = txt
    l.Size = UDim2.new(1, 0, 0, 14)
    l.Position = UDim2.new(0, 0, 0, y)
    l.BackgroundTransparency = 1
    l.TextColor3 = color or Color3.fromRGB(150, 100, 255)
    l.TextSize = 9
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local colW = 130
local gap  = 8

-- ===== العمود 1: AUTO THROW =====
local col1 = makeColumn(0, colW)

makeLbl(col1, "🤖  AUTO THROW", 0, Color3.fromRGB(150, 100, 255))
local AutoBtn, autost = makeBigBtn(col1,
    "  🤖  OFF", 16, 34,
    Color3.fromRGB(18, 14, 34),
    Color3.fromRGB(80, 50, 160))

-- Speed
local SpeedF = Instance.new("Frame")
SpeedF.Size = UDim2.new(1, 0, 0, 22)
SpeedF.Position = UDim2.new(0, 0, 0, 54)
SpeedF.BackgroundColor3 = Color3.fromRGB(14, 10, 28)
SpeedF.BorderSizePixel = 0
SpeedF.Parent = col1
Instance.new("UICorner", SpeedF).CornerRadius = UDim.new(0, 6)

local throwDelay = 1.5
local SpeedTxt = Instance.new("TextLabel")
SpeedTxt.Text = "⏱ "..throwDelay.."ث"
SpeedTxt.Size = UDim2.new(0.55, 0, 1, 0)
SpeedTxt.BackgroundTransparency = 1
SpeedTxt.TextColor3 = Color3.fromRGB(180, 180, 220)
SpeedTxt.TextSize = 9
SpeedTxt.Font = Enum.Font.Gotham
SpeedTxt.TextXAlignment = Enum.TextXAlignment.Left
SpeedTxt.Parent = SpeedF

local function mkSB(txt, x, delta)
    local b = Instance.new("TextButton")
    b.Text = txt
    b.Size = UDim2.new(0.2, 0, 1, 0)
    b.Position = UDim2.new(x, 1, 0, 0)
    b.BackgroundColor3 = Color3.fromRGB(50, 30, 100)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.TextSize = 10
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.Parent = SpeedF
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    b.MouseButton1Click:Connect(function()
        throwDelay = math.max(0.5, throwDelay + delta)
        throwDelay = math.floor(throwDelay * 10) / 10
        SpeedTxt.Text = "⏱ "..throwDelay.."ث"
    end)
end
mkSB("－", 0.56, -0.5)
mkSB("＋", 0.78,  0.5)

local CountTxt = Instance.new("TextLabel")
CountTxt.Text = "رميات: 0"
CountTxt.Size = UDim2.new(1, 0, 0, 12)
CountTxt.Position = UDim2.new(0, 0, 0, 80)
CountTxt.BackgroundTransparency = 1
CountTxt.TextColor3 = Color3.fromRGB(150, 150, 200)
CountTxt.TextSize = 9
CountTxt.Font = Enum.Font.Gotham
CountTxt.TextXAlignment = Enum.TextXAlignment.Left
CountTxt.Parent = col1

-- ===== العمود 2: PERFECT THROW =====
local col2 = makeColumn(colW + gap, colW)

makeLbl(col2, "🎯  PERFECT THROW", 0, Color3.fromRGB(255, 180, 50))
local PerfectBtn, perfst = makeBigBtn(col2,
    "  🎯  OFF", 16, 34,
    Color3.fromRGB(18, 14, 24),
    Color3.fromRGB(150, 100, 20))

local PerfectStatusTxt = Instance.new("TextLabel")
PerfectStatusTxt.Text = "يضغط عند max البار"
PerfectStatusTxt.Size = UDim2.new(1, 0, 0, 12)
PerfectStatusTxt.Position = UDim2.new(0, 0, 0, 54)
PerfectStatusTxt.BackgroundTransparency = 1
PerfectStatusTxt.TextColor3 = Color3.fromRGB(150, 150, 150)
PerfectStatusTxt.TextSize = 8
PerfectStatusTxt.Font = Enum.Font.Gotham
PerfectStatusTxt.TextXAlignment = Enum.TextXAlignment.Left
PerfectStatusTxt.TextWrapped = true
PerfectStatusTxt.Parent = col2

-- ===== العمود 3: AUTO TRAIN =====
local col3 = makeColumn((colW + gap) * 2, colW)

makeLbl(col3, "💪  AUTO TRAIN", 0, Color3.fromRGB(100, 200, 100))
local TrainBtn, trainst = makeBigBtn(col3,
    "  💪  OFF", 16, 34,
    Color3.fromRGB(14, 20, 14),
    Color3.fromRGB(40, 150, 40))

local TrainCountTxt = Instance.new("TextLabel")
TrainCountTxt.Text = "تدريبات: 0"
TrainCountTxt.Size = UDim2.new(1, 0, 0, 12)
TrainCountTxt.Position = UDim2.new(0, 0, 0, 54)
TrainCountTxt.BackgroundTransparency = 1
TrainCountTxt.TextColor3 = Color3.fromRGB(150, 150, 200)
TrainCountTxt.TextSize = 9
TrainCountTxt.Font = Enum.Font.Gotham
TrainCountTxt.TextXAlignment = Enum.TextXAlignment.Left
TrainCountTxt.Parent = col3

-- ===== العمود 4: SET POWER =====
local col4 = makeColumn((colW + gap) * 3, colW)

makeLbl(col4, "⚡  THROW POWER", 0, Color3.fromRGB(100, 150, 255))

local ValF = Instance.new("Frame")
ValF.Size = UDim2.new(1, 0, 0, 24)
ValF.Position = UDim2.new(0, 0, 0, 16)
ValF.BackgroundColor3 = Color3.fromRGB(14, 12, 28)
ValF.BorderSizePixel = 0
ValF.Parent = col4
Instance.new("UICorner", ValF).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", ValF).Color = Color3.fromRGB(80, 50, 160)

local ValTxt = Instance.new("TextLabel")
ValTxt.Text = tostring(customPow)
ValTxt.Size = UDim2.new(1, 0, 1, 0)
ValTxt.BackgroundTransparency = 1
ValTxt.TextColor3 = Color3.new(1, 1, 1)
ValTxt.TextSize = 11
ValTxt.Font = Enum.Font.GothamBold
ValTxt.Parent = ValF

local function mkPB(txt, x, col, action)
    local b = Instance.new("TextButton")
    b.Text = txt
    b.Size = UDim2.new(0.3, -2, 0, 22)
    b.Position = UDim2.new(x, 1, 0, 44)
    b.BackgroundColor3 = col
    b.TextColor3 = Color3.new(1, 1, 1)
    b.TextSize = 9
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.Parent = col4
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(action)
    return b
end

mkPB("－10K", 0,    Color3.fromRGB(120, 25, 25), function()
    customPow = math.max(1000, customPow - 10000)
    ValTxt.Text = tostring(customPow)
end)
mkPB("RST",   0.35, Color3.fromRGB(50, 40, 90), function()
    customPow = 7703
    ValTxt.Text = tostring(customPow)
end)
mkPB("＋10K", 0.68, Color3.fromRGB(25, 100, 25), function()
    customPow = customPow + 10000
    ValTxt.Text = tostring(customPow)
end)

local AppBtn = Instance.new("TextButton")
AppBtn.Text = "⚡ SET NOW"
AppBtn.Size = UDim2.new(1, 0, 0, 22)
AppBtn.Position = UDim2.new(0, 0, 0, 70)
AppBtn.BackgroundColor3 = Color3.fromRGB(70, 35, 160)
AppBtn.TextColor3 = Color3.new(1, 1, 1)
AppBtn.TextSize = 10
AppBtn.Font = Enum.Font.GothamBold
AppBtn.BorderSizePixel = 0
AppBtn.Parent = col4
Instance.new("UICorner", AppBtn).CornerRadius = UDim.new(0, 6)

-- ===== STATUS BAR =====
local StBar = Instance.new("Frame")
StBar.Size = UDim2.new(1, -16, 0, 20)
StBar.Position = UDim2.new(0, 8, 1, -26)
StBar.BackgroundColor3 = Color3.fromRGB(12, 10, 24)
StBar.BorderSizePixel = 0
StBar.Parent = Main
Instance.new("UICorner", StBar).CornerRadius = UDim.new(0, 6)

local StTxt = Instance.new("TextLabel")
StTxt.Text = "● Ready"
StTxt.Size = UDim2.new(1, -8, 1, 0)
StTxt.Position = UDim2.new(0, 6, 0, 0)
StTxt.BackgroundTransparency = 1
StTxt.TextColor3 = Color3.fromRGB(80, 220, 80)
StTxt.TextSize = 9
StTxt.Font = Enum.Font.GothamBold
StTxt.TextXAlignment = Enum.TextXAlignment.Left
StTxt.Parent = StBar

-- Credit
local CrTxt = Instance.new("TextLabel")
CrTxt.Text = "dotbhai @#9002111185000#"
CrTxt.Size = UDim2.new(0, 160, 1, 0)
CrTxt.Position = UDim2.new(1, -164, 0, 0)
CrTxt.BackgroundTransparency = 1
CrTxt.TextColor3 = Color3.fromRGB(50, 40, 90)
CrTxt.TextSize = 8
CrTxt.Font = Enum.Font.Gotham
CrTxt.TextXAlignment = Enum.TextXAlignment.Right
CrTxt.Parent = StBar

-- ===== DRAG =====
local drag, dInp, dSt, dPos = false, nil, nil, nil
TB.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch
    or i.UserInputType == Enum.UserInputType.MouseButton1 then
        drag = true; dSt = i.Position; dPos = Main.Position
        i.Changed:Connect(function()
            if i.UserInputState == Enum.UserInputState.End then drag = false end
        end)
    end
end)
TB.InputChanged:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch
    or i.UserInputType == Enum.UserInputType.MouseButton1 then dInp = i end
end)
UIS.InputChanged:Connect(function(i)
    if i == dInp and drag then
        local d = i.Position - dSt
        Main.Position = UDim2.new(
            dPos.X.Scale, dPos.X.Offset + d.X,
            dPos.Y.Scale, dPos.Y.Offset + d.Y
        )
    end
end)

-- ===== AUTO THROW LOGIC =====
-- ضغط مستمر كل Heartbeat بعد تفعيل الميزة
local tapConn = nil

local function startContinuousTap()
    local cx, cy = getScreenCenter()
    if tapConn then tapConn:Disconnect() end
    tapConn = RunService.Heartbeat:Connect(function()
        if not autoOn then return end
        -- راقب الإحداثيات — بمجرد وصول للمنطقة اضغط
        local root = getRoot()
        if not root then return end
        if math.abs(root.Position.X - THROW_POS.X) < 4
        and math.abs(root.Position.Z - THROW_POS.Z) < 4 then
            pcall(function() ThrowMeter:FireServer() end)
            simulateTap(cx, cy)
        end
    end)
end

local function stopContinuousTap()
    if tapConn then tapConn:Disconnect() tapConn = nil end
end

AutoBtn.MouseButton1Click:Connect(function()
    autoOn = not autoOn

    if autoOn then
        AutoBtn.Text = "  🤖  ON"
        AutoBtn.TextColor3 = Color3.fromRGB(80, 255, 80)
        autost.Color = Color3.fromRGB(50, 200, 50)

        -- ابدأ الضغط المستمر فوراً
        startContinuousTap()

        task.spawn(function()
            while autoOn do
                -- انتقل
                StTxt.Text = "📍 ينتقل لمنطقة الرمي..."
                StTxt.TextColor3 = Color3.fromRGB(255, 200, 50)
                teleport(THROW_POS)

                -- انتظر اكتمال الرمية
                -- السيرفر يُعيد اللاعب بعد الرمية
                local completed = false
                for _ = 1, 50 do
                    task.wait(0.1)
                    local r = getRoot()
                    if r and (r.Position - THROW_POS).Magnitude > 8 then
                        completed = true
                        break
                    end
                end

                if completed then
                    throwCount = throwCount + 1
                    CountTxt.Text = "رميات: "..throwCount
                    StTxt.Text = "✅ رمية "..throwCount.." اكتملت"
                    StTxt.TextColor3 = Color3.fromRGB(80, 255, 80)
                else
                    StTxt.Text = "⚠ timeout — يحاول مجدداً"
                    StTxt.TextColor3 = Color3.fromRGB(255, 150, 50)
                end

                task.wait(throwDelay)
            end
        end)
    else
        autoOn = false
        stopContinuousTap()
        AutoBtn.Text = "  🤖  OFF"
        AutoBtn.TextColor3 = Color3.fromRGB(160, 160, 160)
        autost.Color = Color3.fromRGB(80, 50, 160)
        StTxt.Text = "● Stopped"
        StTxt.TextColor3 = Color3.fromRGB(220, 80, 80)
    end
end)

-- ===== PERFECT THROW LOGIC =====
local perfectEnabled = false

PerfectBtn.MouseButton1Click:Connect(function()
    perfectEnabled = not perfectEnabled
    perfectOn = perfectEnabled

    if perfectEnabled then
        PerfectBtn.Text = "  🎯  ON"
        PerfectBtn.TextColor3 = Color3.fromRGB(255, 220, 50)
        perfst.Color = Color3.fromRGB(200, 150, 20)
        PerfectStatusTxt.Text = "يراقب البار..."
        PerfectStatusTxt.TextColor3 = Color3.fromRGB(255, 220, 50)

        startPerfectWatch(function()
            -- عند max البار — اضغط فوراً
            local cx, cy = getScreenCenter()
            pcall(function() ThrowMeter:FireServer() end)
            simulateTap(cx, cy)
            PerfectStatusTxt.Text = "✅ Perfect!"
            PerfectStatusTxt.TextColor3 = Color3.fromRGB(80, 255, 80)
        end)
    else
        perfectEnabled = false
        perfectOn = false
        if perfectConn then perfectConn:Disconnect() end
        PerfectBtn.Text = "  🎯  OFF"
        PerfectBtn.TextColor3 = Color3.fromRGB(160, 160, 160)
        perfst.Color = Color3.fromRGB(150, 100, 20)
        PerfectStatusTxt.Text = "يضغط عند max البار"
        PerfectStatusTxt.TextColor3 = Color3.fromRGB(150, 150, 150)
    end
end)

-- ===== AUTO TRAIN LOGIC =====
TrainBtn.MouseButton1Click:Connect(function()
    trainOn = not trainOn

    if trainOn then
        TrainBtn.Text = "  💪  ON"
        TrainBtn.TextColor3 = Color3.fromRGB(80, 255, 80)
        trainst.Color = Color3.fromRGB(50, 200, 50)

        task.spawn(function()
            while trainOn do
                StTxt.Text = "📍 ينتقل للتدريب..."
                StTxt.TextColor3 = Color3.fromRGB(255, 200, 50)
                teleport(TRAIN_POS)
                task.wait(0.5)

                StTxt.Text = "💪 يتدرب..."
                StTxt.TextColor3 = Color3.fromRGB(100, 255, 100)
                pcall(function() Training_Start:InvokeServer() end)
                task.wait(0.1)

                local cx, cy = getScreenCenter()
                for i = 1, 30 do
                    if not trainOn then break end
                    pcall(function() Training_Bonus:InvokeServer() end)
                    simulateTap(cx, cy)
                    task.wait(0.03)
                end

                pcall(function() Training_Stop:InvokeServer() end)
                trainCount = trainCount + 1
                TrainCountTxt.Text = "تدريبات: "..trainCount

                local ls = lp:FindFirstChild("leaderstats")
                local tp = ls and ls:FindFirstChild("Throw Power")
                if tp then
                    StTxt.Text = "💪 Power: "..tostring(tp.Value)
                    StTxt.TextColor3 = Color3.fromRGB(80, 255, 80)
                end
                task.wait(0.3)
            end
        end)
    else
        trainOn = false
        TrainBtn.Text = "  💪  OFF"
        TrainBtn.TextColor3 = Color3.fromRGB(160, 160, 160)
        trainst.Color = Color3.fromRGB(40, 150, 40)
        StTxt.Text = "● Train Stopped"
        StTxt.TextColor3 = Color3.fromRGB(220, 80, 80)
    end
end)

-- ===== SET POWER =====
AppBtn.MouseButton1Click:Connect(function()
    StTxt.Text = "● جاري تعيين القوة..."
    StTxt.TextColor3 = Color3.fromRGB(255, 200, 50)
    local ok = pcall(function() SetThrowPower:InvokeServer(customPow) end)
    task.wait(0.6)
    local ls = lp:FindFirstChild("leaderstats")
    local tp = ls and ls:FindFirstChild("Throw Power")
    if tp then
        StTxt.Text = "⚡ Power = "..tostring(tp.Value)..(ok and " ✓" or " ⚠")
        StTxt.TextColor3 = Color3.fromRGB(80, 255, 80)
    else
        StTxt.Text = ok and "⚡ تم ✓" or "⚡ فشل ✗"
        StTxt.TextColor3 = ok and Color3.fromRGB(80, 255, 80) or Color3.fromRGB(255, 80, 80)
    end
end)

-- ===== MINIMIZE / CLOSE =====
local mini = false
MinBtn.MouseButton1Click:Connect(function()
    mini = not mini
    C.Visible = not mini
    StBar.Visible = not mini
    Main.Size = mini
        and UDim2.new(0, 580, 0, 40)
        or  UDim2.new(0, 580, 0, 200)
    MinBtn.Text = mini and "+" or "—"
end)

XBtn.MouseButton1Click:Connect(function()
    autoOn = false
    trainOn = false
    perfectOn = false
    stopContinuousTap()
    if perfectConn then perfectConn:Disconnect() end
    sg:Destroy()
end)
