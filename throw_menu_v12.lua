task.wait(2)

local Players    = game:GetService("Players")
local lp         = Players.LocalPlayer
local RS         = game:GetService("ReplicatedStorage")
local UIS        = game:GetService("UserInputService")
local VIM        = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- ===== REMOTES =====
local Remotes        = RS:WaitForChild("Remotes", 10)
local ThrowMeter     = Remotes:WaitForChild("Throw_MeterStarted", 5)
local SetThrowPower  = Remotes:WaitForChild("Player_SetThrowPower", 5)
local Training_Start = Remotes:WaitForChild("Training_Start", 5)
local Training_Stop  = Remotes:WaitForChild("Training_Stop", 5)
local Training_Bonus = Remotes:WaitForChild("Training_TapBonus", 5)

-- ===== POSITIONS =====
local THROW_POS = Vector3.new(0, 5.6, -45.0)
local TRAIN_POS = Vector3.new(-60.2, 5.5, -16.0)

-- ===== HELPERS =====
local function getRoot()
    return lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
end

local function teleport(pos)
    local root = getRoot()
    if root then root.CFrame = CFrame.new(pos) end
end

local function getScreenCenter()
    local cam = workspace.CurrentCamera
    if cam then return cam.ViewportSize.X/2, cam.ViewportSize.Y/2 end
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

-- ===== PERFECT METER DETECTION =====
-- يراقب FrameSize للبار أو Text — يضغط عند وصول MAX
local function findMeterBarFill()
    for _, v in pairs(lp.PlayerGui:GetDescendants()) do
        if v:IsA("Frame") then
            local n = v.Name:lower()
            if n == "fill" or n == "bar" or n == "meter"
            or n == "progress" or n == "indicator" then
                -- البار العمودي: طوله أكبر من عرضه
                if v.AbsoluteSize.Y > v.AbsoluteSize.X then
                    return v
                end
            end
        end
    end
    return nil
end

-- الحل الصحيح للـ perfect:
-- نراقب متى يظهر البار (يبدأ من 0)
-- ثم ننتظر حتى يصل لـ MAX (Size.Y.Scale = 1 أو قريب منه)
-- ثم نضغط
local perfectConn = nil
local perfectOn   = false
local lastBarVisible = false

local function startPerfectMode(onPress)
    if perfectConn then perfectConn:Disconnect() end
    lastBarVisible = false

    perfectConn = RunService.Heartbeat:Connect(function()
        if not perfectOn then return end

        local bar = findMeterBarFill()
        if not bar then return end

        local visible = bar.Visible and bar.AbsoluteSize.Y > 10

        -- البار ظهر حديثاً = بدأ
        if visible and not lastBarVisible then
            lastBarVisible = true
        end

        -- البار وصل لأعلى = max
        if visible and lastBarVisible then
            -- Size.Y.Scale أو AbsoluteSize قرب الـ parent
            local parent = bar.Parent
            if parent and parent:IsA("GuiObject") then
                local ratio = bar.AbsoluteSize.Y / math.max(parent.AbsoluteSize.Y, 1)
                if ratio >= 0.88 then
                    lastBarVisible = false
                    if onPress then onPress() end
                end
            end
        end

        -- البار اختفى = reset
        if not visible and lastBarVisible then
            lastBarVisible = false
        end
    end)
end

-- ===== STATE =====
local autoOn    = false
local trainOn   = false
local customPow = 999999
local throwCount = 0
local trainCount = 0
local throwDelay = 1.5
local tapConn   = nil

local function startTapLoop()
    local cx, cy = getScreenCenter()
    if tapConn then tapConn:Disconnect() end
    tapConn = RunService.Heartbeat:Connect(function()
        if not autoOn then return end
        local root = getRoot()
        if not root then return end
        if math.abs(root.Position.X - THROW_POS.X) < 4
        and math.abs(root.Position.Z - THROW_POS.Z) < 4 then
            pcall(function() ThrowMeter:FireServer() end)
            simulateTap(cx, cy)
        end
    end)
end

local function stopTapLoop()
    if tapConn then tapConn:Disconnect(); tapConn = nil end
end

-- ===== CLEANUP OLD GUI =====
for _, v in pairs(game.CoreGui:GetChildren()) do
    if tostring(v.Name):find("ThrowFinal") or tostring(v.Name):find("ThrowMenu") then
        v:Destroy()
    end
end
pcall(function()
    for _, v in pairs(lp.PlayerGui:GetChildren()) do
        if tostring(v.Name):find("ThrowFinal") or tostring(v.Name):find("ThrowMenu") then
            v:Destroy()
        end
    end
end)

-- ===== DESIGN TOKENS =====
local CLR = {
    bg        = Color3.fromRGB(10,  10,  18),
    surface   = Color3.fromRGB(16,  14,  30),
    surface2  = Color3.fromRGB(22,  18,  40),
    border    = Color3.fromRGB(50,  35,  100),
    accent    = Color3.fromRGB(110, 60,  240),
    accentLit = Color3.fromRGB(150, 90,  255),
    green     = Color3.fromRGB(50,  220, 100),
    greenDim  = Color3.fromRGB(20,  80,  40),
    gold      = Color3.fromRGB(255, 200, 50),
    goldDim   = Color3.fromRGB(80,  60,  10),
    red       = Color3.fromRGB(220, 50,  70),
    text      = Color3.fromRGB(220, 215, 240),
    textDim   = Color3.fromRGB(100, 90,  130),
    white     = Color3.new(1, 1, 1),
}

-- ===== GUI ROOT =====
local sg = Instance.new("ScreenGui")
sg.Name = "ThrowFinal_"..math.random(10000,99999)
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
pcall(function()
    if syn then syn.protect_gui(sg) end
    sg.Parent = game.CoreGui
end)
if sg.Parent ~= game.CoreGui then sg.Parent = lp.PlayerGui end

-- ===== MAIN FRAME =====
local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 400, 0, 260)
Main.Position = UDim2.new(0.5, -200, 1, -275)
Main.BackgroundColor3 = CLR.bg
Main.BorderSizePixel = 0
Main.Parent = sg
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 18)

-- Outer glow stroke
local outerStroke = Instance.new("UIStroke", Main)
outerStroke.Color = CLR.accent
outerStroke.Thickness = 1.5
outerStroke.Transparency = 0.4

-- ===== TITLE BAR =====
local TB = Instance.new("Frame")
TB.Size = UDim2.new(1, 0, 0, 44)
TB.BackgroundColor3 = CLR.surface
TB.BorderSizePixel = 0
TB.Parent = Main
Instance.new("UICorner", TB).CornerRadius = UDim.new(0, 18)

-- gradient بنفسجي للعنوان
local tbGrad = Instance.new("UIGradient", TB)
tbGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(80, 30, 180)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 15, 130)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(30,  8,  90)),
})
tbGrad.Rotation = 90

-- أيقونة + عنوان
local TIcon = Instance.new("TextLabel")
TIcon.Text = "🌿"
TIcon.Size = UDim2.new(0, 28, 1, 0)
TIcon.Position = UDim2.new(0, 10, 0, 0)
TIcon.BackgroundTransparency = 1
TIcon.TextSize = 18
TIcon.Parent = TB

local TTxt = Instance.new("TextLabel")
TTxt.Text = "THROW MENU"
TTxt.Size = UDim2.new(0, 160, 1, 0)
TTxt.Position = UDim2.new(0, 40, 0, 0)
TTxt.BackgroundTransparency = 1
TTxt.TextColor3 = CLR.white
TTxt.TextSize = 14
TTxt.Font = Enum.Font.GothamBold
TTxt.TextXAlignment = Enum.TextXAlignment.Left
TTxt.Parent = TB

local TVersion = Instance.new("TextLabel")
TVersion.Text = "v12"
TVersion.Size = UDim2.new(0, 30, 1, 0)
TVersion.Position = UDim2.new(0, 196, 0, 0)
TVersion.BackgroundTransparency = 1
TVersion.TextColor3 = CLR.accentLit
TVersion.TextSize = 10
TVersion.Font = Enum.Font.GothamBold
TVersion.TextXAlignment = Enum.TextXAlignment.Left
TVersion.Parent = TB

-- موقع اللاعب
local PosTxt = Instance.new("TextLabel")
PosTxt.Text = "..."
PosTxt.Size = UDim2.new(0, 130, 1, 0)
PosTxt.Position = UDim2.new(1, -218, 0, 0)
PosTxt.BackgroundTransparency = 1
PosTxt.TextColor3 = CLR.textDim
PosTxt.TextSize = 8
PosTxt.Font = Enum.Font.Gotham
PosTxt.TextXAlignment = Enum.TextXAlignment.Right
PosTxt.Parent = TB

-- زر تصغير
local MinBtn = Instance.new("TextButton")
MinBtn.Text = "−"
MinBtn.Size = UDim2.new(0, 24, 0, 20)
MinBtn.Position = UDim2.new(1, -54, 0.5, -10)
MinBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 70)
MinBtn.TextColor3 = CLR.textDim
MinBtn.TextSize = 14
MinBtn.Font = Enum.Font.GothamBold
MinBtn.BorderSizePixel = 0
MinBtn.Parent = TB
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

-- زر إغلاق
local XBtn = Instance.new("TextButton")
XBtn.Text = "✕"
XBtn.Size = UDim2.new(0, 24, 0, 20)
XBtn.Position = UDim2.new(1, -26, 0.5, -10)
XBtn.BackgroundColor3 = Color3.fromRGB(120, 20, 35)
XBtn.TextColor3 = Color3.fromRGB(255, 100, 120)
XBtn.TextSize = 11
XBtn.Font = Enum.Font.GothamBold
XBtn.BorderSizePixel = 0
XBtn.Parent = TB
Instance.new("UICorner", XBtn).CornerRadius = UDim.new(0, 6)

-- ===== CONTENT =====
local C = Instance.new("Frame")
C.Size = UDim2.new(1, -16, 1, -52)
C.Position = UDim2.new(0, 8, 0, 48)
C.BackgroundTransparency = 1
C.Parent = Main

-- ===== CARD BUILDER =====
local function makeCard(parent, x, y, w, h)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(0, w, 0, h)
    card.Position = UDim2.new(0, x, 0, y)
    card.BackgroundColor3 = CLR.surface
    card.BorderSizePixel = 0
    card.Parent = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
    local st = Instance.new("UIStroke", card)
    st.Color = CLR.border
    st.Thickness = 1
    return card, st
end

-- ===== TOGGLE BUTTON BUILDER =====
local function makeToggle(parent, icon, label, y, h, activeColor)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, h)
    btn.Position = UDim2.new(0, 0, 0, y)
    btn.BackgroundColor3 = CLR.surface2
    btn.TextColor3 = CLR.textDim
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold
    btn.Text = ""
    btn.BorderSizePixel = 0
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    local bst = Instance.new("UIStroke", btn)
    bst.Color = CLR.border
    bst.Thickness = 1

    -- أيقونة
    local ic = Instance.new("TextLabel")
    ic.Text = icon
    ic.Size = UDim2.new(0, 28, 1, 0)
    ic.Position = UDim2.new(0, 8, 0, 0)
    ic.BackgroundTransparency = 1
    ic.TextSize = 14
    ic.Parent = btn

    -- نص
    local lbl = Instance.new("TextLabel")
    lbl.Text = label
    lbl.Size = UDim2.new(1, -80, 1, 0)
    lbl.Position = UDim2.new(0, 38, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = CLR.textDim
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = btn

    -- pill ON/OFF
    local pill = Instance.new("Frame")
    pill.Size = UDim2.new(0, 36, 0, 16)
    pill.Position = UDim2.new(1, -44, 0.5, -8)
    pill.BackgroundColor3 = CLR.border
    pill.BorderSizePixel = 0
    pill.Parent = btn
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 12, 0, 12)
    dot.Position = UDim2.new(0, 2, 0.5, -6)
    dot.BackgroundColor3 = CLR.textDim
    dot.BorderSizePixel = 0
    dot.Parent = pill
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local isOn = false
    local function setState(on)
        isOn = on
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad)
        if on then
            TweenService:Create(pill, tweenInfo, {BackgroundColor3 = activeColor}):Play()
            TweenService:Create(dot, tweenInfo, {
                Position = UDim2.new(1, -14, 0.5, -6),
                BackgroundColor3 = CLR.white
            }):Play()
            TweenService:Create(bst, tweenInfo, {Color = activeColor}):Play()
            lbl.TextColor3 = CLR.white
        else
            TweenService:Create(pill, tweenInfo, {BackgroundColor3 = CLR.border}):Play()
            TweenService:Create(dot, tweenInfo, {
                Position = UDim2.new(0, 2, 0.5, -6),
                BackgroundColor3 = CLR.textDim
            }):Play()
            TweenService:Create(bst, tweenInfo, {Color = CLR.border}):Play()
            lbl.TextColor3 = CLR.textDim
        end
    end

    return btn, setState, function() return isOn end
end

-- ===== LAYOUT =====
-- الصف الأول: 3 بطاقات
local cardW1 = 120
local cardW2 = 120
local cardW3 = 128
local cardH  = 90
local gap    = 6

-- ===== بطاقة AUTO THROW =====
local card1, card1st = makeCard(C, 0, 0, cardW1, cardH)

local c1Title = Instance.new("TextLabel")
c1Title.Text = "AUTO THROW"
c1Title.Size = UDim2.new(1, -10, 0, 16)
c1Title.Position = UDim2.new(0, 8, 0, 8)
c1Title.BackgroundTransparency = 1
c1Title.TextColor3 = CLR.textDim
c1Title.TextSize = 9
c1Title.Font = Enum.Font.GothamBold
c1Title.TextXAlignment = Enum.TextXAlignment.Left
c1Title.Parent = card1

local AutoBtn, setAutoState, getAutoState = makeToggle(card1,
    "🤖", "يرمي تلقائياً", 26, 34, CLR.green)

-- Speed row
local speedRow = Instance.new("Frame")
speedRow.Size = UDim2.new(1, -10, 0, 22)
speedRow.Position = UDim2.new(0, 5, 0, 64)
speedRow.BackgroundTransparency = 1
speedRow.Parent = card1

local spLbl = Instance.new("TextLabel")
spLbl.Text = "⏱ 1.5ث"
spLbl.Size = UDim2.new(0.55, 0, 1, 0)
spLbl.BackgroundTransparency = 1
spLbl.TextColor3 = CLR.textDim
spLbl.TextSize = 8
spLbl.Font = Enum.Font.Gotham
spLbl.TextXAlignment = Enum.TextXAlignment.Left
spLbl.Parent = speedRow

local throwDelay = 1.5
local function mkSB(txt, x, delta)
    local b = Instance.new("TextButton")
    b.Text = txt
    b.Size = UDim2.new(0.2, -1, 1, 0)
    b.Position = UDim2.new(x, 1, 0, 0)
    b.BackgroundColor3 = CLR.surface2
    b.TextColor3 = CLR.text
    b.TextSize = 10
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.Parent = speedRow
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    b.MouseButton1Click:Connect(function()
        throwDelay = math.max(0.5, throwDelay + delta)
        throwDelay = math.floor(throwDelay*10)/10
        spLbl.Text = "⏱ "..throwDelay.."ث"
    end)
end
mkSB("−", 0.56, -0.5)
mkSB("＋", 0.78,  0.5)

-- عداد رميات
local CountTxt = Instance.new("TextLabel")
CountTxt.Text = "0 رمية"
CountTxt.Size = UDim2.new(1, -10, 0, 12)
CountTxt.Position = UDim2.new(0, 8, 1, -16)
CountTxt.BackgroundTransparency = 1
CountTxt.TextColor3 = CLR.textDim
CountTxt.TextSize = 8
CountTxt.Font = Enum.Font.Gotham
CountTxt.TextXAlignment = Enum.TextXAlignment.Left
CountTxt.Parent = card1

-- ===== بطاقة PERFECT THROW =====
local card2, card2st = makeCard(C, cardW1 + gap, 0, cardW2, cardH)

local c2Title = Instance.new("TextLabel")
c2Title.Text = "PERFECT THROW"
c2Title.Size = UDim2.new(1, -10, 0, 16)
c2Title.Position = UDim2.new(0, 8, 0, 8)
c2Title.BackgroundTransparency = 1
c2Title.TextColor3 = CLR.textDim
c2Title.TextSize = 9
c2Title.Font = Enum.Font.GothamBold
c2Title.TextXAlignment = Enum.TextXAlignment.Left
c2Title.Parent = card2

local PerfectBtn, setPerfectState, getPerfectState = makeToggle(card2,
    "🎯", "ضغط عند 20", 26, 34, CLR.gold)

-- مؤشر الوضع
local PerfectHint = Instance.new("TextLabel")
PerfectHint.Text = "ينتظر البار..."
PerfectHint.Size = UDim2.new(1, -10, 0, 12)
PerfectHint.Position = UDim2.new(0, 8, 0, 64)
PerfectHint.BackgroundTransparency = 1
PerfectHint.TextColor3 = CLR.textDim
PerfectHint.TextSize = 8
PerfectHint.Font = Enum.Font.Gotham
PerfectHint.TextXAlignment = Enum.TextXAlignment.Left
PerfectHint.Parent = card2

-- ===== بطاقة AUTO TRAIN =====
local card3, card3st = makeCard(C, cardW1 + cardW2 + gap*2, 0, cardW3, cardH)

local c3Title = Instance.new("TextLabel")
c3Title.Text = "AUTO TRAIN"
c3Title.Size = UDim2.new(1, -10, 0, 16)
c3Title.Position = UDim2.new(0, 8, 0, 8)
c3Title.BackgroundTransparency = 1
c3Title.TextColor3 = CLR.textDim
c3Title.TextSize = 9
c3Title.Font = Enum.Font.GothamBold
c3Title.TextXAlignment = Enum.TextXAlignment.Left
c3Title.Parent = card3

local TrainBtn, setTrainState, getTrainState = makeToggle(card3,
    "💪", "تدريب تلقائي", 26, 34, CLR.green)

local TrainCountTxt = Instance.new("TextLabel")
TrainCountTxt.Text = "0 تدريب"
TrainCountTxt.Size = UDim2.new(1, -10, 0, 12)
TrainCountTxt.Position = UDim2.new(0, 8, 0, 64)
TrainCountTxt.BackgroundTransparency = 1
TrainCountTxt.TextColor3 = CLR.textDim
TrainCountTxt.TextSize = 8
TrainCountTxt.Font = Enum.Font.Gotham
TrainCountTxt.TextXAlignment = Enum.TextXAlignment.Left
TrainCountTxt.Parent = card3

-- ===== الصف الثاني: SET POWER + STATUS =====
local row2Y = cardH + gap

-- بطاقة POWER
local card4, card4st = makeCard(C, 0, row2Y, 192, 72)

local c4Title = Instance.new("TextLabel")
c4Title.Text = "THROW POWER"
c4Title.Size = UDim2.new(1, -10, 0, 16)
c4Title.Position = UDim2.new(0, 8, 0, 6)
c4Title.BackgroundTransparency = 1
c4Title.TextColor3 = CLR.textDim
c4Title.TextSize = 9
c4Title.Font = Enum.Font.GothamBold
c4Title.TextXAlignment = Enum.TextXAlignment.Left
c4Title.Parent = card4

-- value display
local ValDisplay = Instance.new("Frame")
ValDisplay.Size = UDim2.new(0, 80, 0, 24)
ValDisplay.Position = UDim2.new(0, 8, 0, 24)
ValDisplay.BackgroundColor3 = CLR.bg
ValDisplay.BorderSizePixel = 0
ValDisplay.Parent = card4
Instance.new("UICorner", ValDisplay).CornerRadius = UDim.new(0, 6)

local ValTxt = Instance.new("TextLabel")
ValTxt.Text = tostring(customPow)
ValTxt.Size = UDim2.new(1, 0, 1, 0)
ValTxt.BackgroundTransparency = 1
ValTxt.TextColor3 = CLR.accentLit
ValTxt.TextSize = 11
ValTxt.Font = Enum.Font.GothamBold
ValTxt.Parent = ValDisplay

-- buttons
local function mkPB2(txt, xOff, col, action)
    local b = Instance.new("TextButton")
    b.Text = txt
    b.Size = UDim2.new(0, 28, 0, 24)
    b.Position = UDim2.new(0, xOff, 0, 24)
    b.BackgroundColor3 = col
    b.TextColor3 = CLR.white
    b.TextSize = 8
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.Parent = card4
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(action)
    return b
end

mkPB2("−10K", 94,  Color3.fromRGB(100,20,20), function()
    customPow = math.max(1000, customPow - 10000)
    ValTxt.Text = tostring(customPow)
end)
mkPB2("RST", 125, CLR.surface2, function()
    customPow = 7703
    ValTxt.Text = tostring(customPow)
end)
mkPB2("+10K", 156, Color3.fromRGB(20,80,20), function()
    customPow = customPow + 10000
    ValTxt.Text = tostring(customPow)
end)

-- Apply
local AppBtn = Instance.new("TextButton")
AppBtn.Text = "⚡ APPLY"
AppBtn.Size = UDim2.new(1, -16, 0, 20)
AppBtn.Position = UDim2.new(0, 8, 1, -26)
AppBtn.BackgroundColor3 = CLR.accent
AppBtn.TextColor3 = CLR.white
AppBtn.TextSize = 10
AppBtn.Font = Enum.Font.GothamBold
AppBtn.BorderSizePixel = 0
AppBtn.Parent = card4
Instance.new("UICorner", AppBtn).CornerRadius = UDim.new(0, 8)

-- بطاقة STATUS
local card5, card5st = makeCard(C, 198, row2Y, 190, 72)

local StTxt = Instance.new("TextLabel")
StTxt.Text = "● جاهز"
StTxt.Size = UDim2.new(1, -10, 1, -10)
StTxt.Position = UDim2.new(0, 8, 0, 8)
StTxt.BackgroundTransparency = 1
StTxt.TextColor3 = CLR.green
StTxt.TextSize = 10
StTxt.Font = Enum.Font.GothamBold
StTxt.TextXAlignment = Enum.TextXAlignment.Left
StTxt.TextYAlignment = Enum.TextYAlignment.Top
StTxt.TextWrapped = true
StTxt.Parent = card5

-- credit
local CrTxt = Instance.new("TextLabel")
CrTxt.Text = "dotbhai @#9002111185000#"
CrTxt.Size = UDim2.new(1, -10, 0, 12)
CrTxt.Position = UDim2.new(0, 8, 1, -16)
CrTxt.BackgroundTransparency = 1
CrTxt.TextColor3 = CLR.textDim
CrTxt.TextSize = 7
CrTxt.Font = Enum.Font.Gotham
CrTxt.TextXAlignment = Enum.TextXAlignment.Left
CrTxt.Parent = card5

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
            dPos.Y.Scale, dPos.Y.Offset + d.Y)
    end
end)

-- تحديث موقع اللاعب
task.spawn(function()
    while true do
        task.wait(0.6)
        local root = getRoot()
        if root then
            local p = root.Position
            PosTxt.Text = string.format("%.0f / %.0f / %.0f", p.X, p.Y, p.Z)
        end
    end
end)

-- ===== LOGIC: AUTO THROW =====
AutoBtn.MouseButton1Click:Connect(function()
    autoOn = not autoOn
    setAutoState(autoOn)

    if autoOn then
        startTapLoop()
        StTxt.Text = "● Auto Throw نشط"
        StTxt.TextColor3 = CLR.green

        task.spawn(function()
            while autoOn do
                StTxt.Text = "📍 ينتقل للرمي..."
                StTxt.TextColor3 = CLR.gold
                teleport(THROW_POS)

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
                    CountTxt.Text = throwCount.." رمية"
                    StTxt.Text = "✅ رمية "..throwCount
                    StTxt.TextColor3 = CLR.green
                else
                    StTxt.Text = "⚠ timeout"
                    StTxt.TextColor3 = CLR.gold
                end

                task.wait(throwDelay)
            end
        end)
    else
        stopTapLoop()
        StTxt.Text = "● Stopped"
        StTxt.TextColor3 = CLR.textDim
    end
end)

-- ===== LOGIC: PERFECT THROW =====
-- الفكرة الصحيحة:
-- 1. اللاعب يذهب لمنطقة الرمي يدوياً
-- 2. Perfect mode يراقب البار
-- 3. البار يبدأ من صفر ويصعد
-- 4. عند وصوله لـ MAX يضغط فوراً
-- نراقب FrameSize للبار الذي تغير حجمه = يمثل البار المتحرك

PerfectBtn.MouseButton1Click:Connect(function()
    perfectOn = not perfectOn
    setPerfectState(perfectOn)

    if perfectOn then
        PerfectHint.Text = "يراقب البار..."
        PerfectHint.TextColor3 = CLR.gold

        -- الحل الصحيح: نراقب كل Frame يتغير حجمه
        -- البار الصاعد = Frame يزيد في Size.Y
        local barFrame = nil
        local prevHeight = 0
        local rising = false

        startPerfectWatch(nil) -- نلغي الـ watch القديم

        if perfectConn then perfectConn:Disconnect() end
        perfectConn = RunService.Heartbeat:Connect(function()
            if not perfectOn then return end

            -- ابحث عن البار المتحرك
            if not barFrame then
                for _, v in pairs(lp.PlayerGui:GetDescendants()) do
                    if v:IsA("Frame") and v.Visible then
                        local h = v.AbsoluteSize.Y
                        -- البار العمودي بين 50-300 pixel طولاً
                        if h > 50 and h < 350
                        and v.AbsoluteSize.X < 50 then
                            barFrame = v
                            prevHeight = h
                            break
                        end
                    end
                end
                return
            end

            if not barFrame.Visible then
                barFrame = nil
                rising = false
                prevHeight = 0
                return
            end

            local currH = barFrame.AbsoluteSize.Y
            local parent = barFrame.Parent

            -- البار يصعد؟
            if currH > prevHeight then
                rising = true
            end

            -- البار وصل لأعلى (قرب parent height)
            if rising and parent and parent:IsA("GuiObject") then
                local maxH = parent.AbsoluteSize.Y
                local ratio = currH / math.max(maxH, 1)

                if ratio >= 0.88 then
                    -- MAX! اضغط فوراً
                    rising = false
                    barFrame = nil
                    prevHeight = 0

                    local cx, cy = getScreenCenter()
                    pcall(function() ThrowMeter:FireServer() end)
                    simulateTap(cx, cy)

                    PerfectHint.Text = "✅ Perfect! 20"
                    PerfectHint.TextColor3 = CLR.green

                    -- reset بعد ثانية
                    task.delay(1, function()
                        if perfectOn then
                            PerfectHint.Text = "يراقب البار..."
                            PerfectHint.TextColor3 = CLR.gold
                        end
                    end)
                end
            end

            prevHeight = currH
        end)

        StTxt.Text = "🎯 Perfect mode نشط"
        StTxt.TextColor3 = CLR.gold
    else
        if perfectConn then perfectConn:Disconnect() end
        PerfectHint.Text = "ضغط عند 20"
        PerfectHint.TextColor3 = CLR.textDim
        StTxt.Text = "● Stopped"
        StTxt.TextColor3 = CLR.textDim
    end
end)

-- ===== LOGIC: AUTO TRAIN =====
TrainBtn.MouseButton1Click:Connect(function()
    trainOn = not trainOn
    setTrainState(trainOn)

    if trainOn then
        StTxt.Text = "💪 Train نشط"
        StTxt.TextColor3 = CLR.green

        task.spawn(function()
            while trainOn do
                StTxt.Text = "📍 ينتقل للتدريب..."
                StTxt.TextColor3 = CLR.gold
                teleport(TRAIN_POS)
                task.wait(0.5)

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
                TrainCountTxt.Text = trainCount.." تدريب"

                local ls = lp:FindFirstChild("leaderstats")
                local tp = ls and ls:FindFirstChild("Throw Power")
                if tp then
                    StTxt.Text = "💪 Power: "..tostring(tp.Value)
                    StTxt.TextColor3 = CLR.green
                end
                task.wait(0.3)
            end
        end)
    else
        StTxt.Text = "● Stopped"
        StTxt.TextColor3 = CLR.textDim
    end
end)

-- ===== LOGIC: SET POWER =====
AppBtn.MouseButton1Click:Connect(function()
    StTxt.Text = "⚡ جاري..."
    StTxt.TextColor3 = CLR.gold
    local ok = pcall(function() SetThrowPower:InvokeServer(customPow) end)
    task.wait(0.6)
    local ls = lp:FindFirstChild("leaderstats")
    local tp = ls and ls:FindFirstChild("Throw Power")
    if tp then
        StTxt.Text = "⚡ Power = "..tostring(tp.Value)..(ok and " ✓" or " ⚠")
        StTxt.TextColor3 = ok and CLR.green or CLR.gold
    else
        StTxt.Text = ok and "⚡ تم ✓" or "⚡ فشل ✗"
        StTxt.TextColor3 = ok and CLR.green or CLR.red
    end
end)

-- ===== MINIMIZE / CLOSE =====
local mini = false
MinBtn.MouseButton1Click:Connect(function()
    mini = not mini
    C.Visible = not mini
    Main.Size = mini
        and UDim2.new(0, 400, 0, 48)
        or  UDim2.new(0, 400, 0, 260)
    MinBtn.Text = mini and "+" or "−"
end)

XBtn.MouseButton1Click:Connect(function()
    autoOn = false
    trainOn = false
    perfectOn = false
    stopTapLoop()
    if perfectConn then perfectConn:Disconnect() end
    sg:Destroy()
end)
