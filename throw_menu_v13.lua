task.wait(2)

local Players      = game:GetService("Players")
local lp           = Players.LocalPlayer
local RS           = game:GetService("ReplicatedStorage")
local UIS          = game:GetService("UserInputService")
local VIM          = game:GetService("VirtualInputManager")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- ===== REMOTES =====
local Remotes        = RS:WaitForChild("Remotes", 10)
local ThrowMeter     = Remotes:WaitForChild("Throw_MeterStarted", 5)
local SetThrowPower  = Remotes:WaitForChild("Player_SetThrowPower", 5)
local Training_Start = Remotes:WaitForChild("Training_Start", 5)
local Training_Stop  = Remotes:WaitForChild("Training_Stop", 5)
local Training_Bonus = Remotes:WaitForChild("Training_TapBonus", 5)

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

-- ===== COLOR DETECTION =====
-- البار يتغير من أحمر → برتقالي → أصفر → أخضر
-- نراقب لون الـ Frame الذي يمثل المؤشر (الشريط الأبيض)
-- أو نراقب لون أعلى جزء من البار

local function isGreenColor(color)
    -- اللون الأخضر: G عالي، R منخفض، B منخفض
    return color.G > 0.5 and color.R < 0.6 and color.B < 0.4
end

local function isYellowOrGreen(color)
    -- أصفر أو أخضر: كلاهما G عالي
    return color.G > 0.45
end

-- البحث عن الـ Frame الذي يمثل المؤشر الأبيض (الشريط المتحرك)
local function findWhiteMarker()
    for _, v in pairs(lp.PlayerGui:GetDescendants()) do
        if v:IsA("Frame") and v.Visible then
            local c = v.BackgroundColor3
            -- الشريط الأبيض: R,G,B كلها قريبة من 1
            if c.R > 0.85 and c.G > 0.85 and c.B > 0.85
            and v.AbsoluteSize.X > 10
            and v.AbsoluteSize.Y > 3
            and v.AbsoluteSize.Y < 30 then
                return v
            end
        end
    end
    return nil
end

-- البحث عن البار الرئيسي (عمودي، ملون)
local function findMainBar()
    local best = nil
    local bestH = 0
    for _, v in pairs(lp.PlayerGui:GetDescendants()) do
        if v:IsA("Frame") and v.Visible then
            local sz = v.AbsoluteSize
            -- البار العمودي: طوله > عرضه * 2، وحجم معقول
            if sz.Y > sz.X * 2 and sz.Y > 60 and sz.Y < 500
            and sz.X > 10 and sz.X < 100 then
                if sz.Y > bestH then
                    bestH = sz.Y
                    best = v
                end
            end
        end
    end
    return best
end

-- نحسب موقع المؤشر الأبيض بالنسبة للبار
-- إذا كان في الجزء الأخضر (أعلى البار) = اضغط
local function getMarkerRatio()
    local marker = findWhiteMarker()
    local bar = findMainBar()
    if not marker or not bar then return nil end

    local barTop = bar.AbsolutePosition.Y
    local barH   = bar.AbsoluteSize.Y
    local markerY = marker.AbsolutePosition.Y + marker.AbsoluteSize.Y / 2

    -- ratio: 0 = أسفل البار (أحمر)، 1 = أعلى البار (أخضر)
    local ratio = 1 - ((markerY - barTop) / math.max(barH, 1))
    return math.clamp(ratio, 0, 1)
end

-- ===== STATE =====
local autoOn     = false
local trainOn    = false
local customPow  = 999999
local throwCount = 0
local trainCount = 0
local throwDelay = 1.5
local tapConn    = nil
local perfectConn = nil

-- threshold: كم ratio يعتبر "أخضر"
-- البار الأخضر يبدأ من ~65% للأعلى
local GREEN_THRESHOLD = 0.65

local function doPerfectTap()
    local cx, cy = getScreenCenter()
    pcall(function() ThrowMeter:FireServer() end)
    simulateTap(cx, cy)
end

-- Loop التلقائي الذكي
local function startAutoLoop()
    local cx, cy = getScreenCenter()
    if tapConn then tapConn:Disconnect() end

    tapConn = RunService.Heartbeat:Connect(function()
        if not autoOn then return end
        local root = getRoot()
        if not root then return end

        -- تأكد اللاعب في منطقة الرمي
        if math.abs(root.Position.X - THROW_POS.X) < 4
        and math.abs(root.Position.Z - THROW_POS.Z) < 4 then

            -- راقب نسبة المؤشر
            local ratio = getMarkerRatio()
            if ratio then
                -- اضغط فقط عندما المؤشر في المنطقة الخضراء
                if ratio >= GREEN_THRESHOLD then
                    pcall(function() ThrowMeter:FireServer() end)
                    simulateTap(cx, cy)
                end
            else
                -- لو ما وجدنا البار = اضغط مباشرة (fallback)
                pcall(function() ThrowMeter:FireServer() end)
                simulateTap(cx, cy)
            end
        end
    end)
end

local function stopAutoLoop()
    if tapConn then tapConn:Disconnect(); tapConn = nil end
end

-- ===== CLEANUP =====
for _, v in pairs(game.CoreGui:GetChildren()) do
    if tostring(v.Name):find("ThrowFinal") then v:Destroy() end
end
pcall(function()
    for _, v in pairs(lp.PlayerGui:GetChildren()) do
        if tostring(v.Name):find("ThrowFinal") then v:Destroy() end
    end
end)

-- ===== DESIGN =====
local CLR = {
    bg       = Color3.fromRGB(10,  10,  18),
    surface  = Color3.fromRGB(16,  14,  30),
    surface2 = Color3.fromRGB(22,  18,  40),
    border   = Color3.fromRGB(50,  35, 100),
    accent   = Color3.fromRGB(110,  60, 240),
    accentL  = Color3.fromRGB(150,  90, 255),
    green    = Color3.fromRGB(50,  220, 100),
    greenD   = Color3.fromRGB(20,   80,  40),
    gold     = Color3.fromRGB(255, 200,  50),
    red      = Color3.fromRGB(220,  50,  70),
    text     = Color3.fromRGB(220, 215, 240),
    textDim  = Color3.fromRGB(100,  90, 130),
    white    = Color3.new(1, 1, 1),
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

-- ===== MAIN =====
local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 420, 0, 265)
Main.Position = UDim2.new(0.5, -210, 1, -280)
Main.BackgroundColor3 = CLR.bg
Main.BorderSizePixel = 0
Main.Parent = sg
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 18)
local mainStroke = Instance.new("UIStroke", Main)
mainStroke.Color = CLR.accent
mainStroke.Thickness = 1.5
mainStroke.Transparency = 0.4

-- ===== TITLE =====
local TB = Instance.new("Frame")
TB.Size = UDim2.new(1, 0, 0, 44)
TB.BackgroundColor3 = CLR.surface
TB.BorderSizePixel = 0
TB.Parent = Main
Instance.new("UICorner", TB).CornerRadius = UDim.new(0, 18)
local tbg = Instance.new("UIGradient", TB)
tbg.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(80, 30, 180)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 15, 130)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(30,  8,  90)),
})
tbg.Rotation = 90

local TIcon = Instance.new("TextLabel")
TIcon.Text = "🌿"
TIcon.Size = UDim2.new(0, 28, 1, 0)
TIcon.Position = UDim2.new(0, 10, 0, 0)
TIcon.BackgroundTransparency = 1
TIcon.TextSize = 18
TIcon.Parent = TB

local TTxt = Instance.new("TextLabel")
TTxt.Text = "THROW MENU  v13"
TTxt.Size = UDim2.new(0, 180, 1, 0)
TTxt.Position = UDim2.new(0, 40, 0, 0)
TTxt.BackgroundTransparency = 1
TTxt.TextColor3 = CLR.white
TTxt.TextSize = 13
TTxt.Font = Enum.Font.GothamBold
TTxt.TextXAlignment = Enum.TextXAlignment.Left
TTxt.Parent = TB

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

-- ===== BUILDERS =====
local function card(x, y, w, h)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(0, w, 0, h)
    f.Position = UDim2.new(0, x, 0, y)
    f.BackgroundColor3 = CLR.surface
    f.BorderSizePixel = 0
    f.Parent = C
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 12)
    local st = Instance.new("UIStroke", f)
    st.Color = CLR.border
    st.Thickness = 1
    return f, st
end

local function lbl(parent, txt, y, fs, color, xa)
    local l = Instance.new("TextLabel")
    l.Text = txt
    l.Size = UDim2.new(1, -10, 0, fs + 4)
    l.Position = UDim2.new(0, 6, 0, y)
    l.BackgroundTransparency = 1
    l.TextColor3 = color or CLR.textDim
    l.TextSize = fs
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = xa or Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local function toggle(parent, icon, text, y, activeColor)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, 32)
    btn.Position = UDim2.new(0, 4, 0, y)
    btn.BackgroundColor3 = CLR.surface2
    btn.Text = ""
    btn.BorderSizePixel = 0
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    local bst = Instance.new("UIStroke", btn)
    bst.Color = CLR.border
    bst.Thickness = 1

    local ic = Instance.new("TextLabel")
    ic.Text = icon
    ic.Size = UDim2.new(0, 24, 1, 0)
    ic.Position = UDim2.new(0, 6, 0, 0)
    ic.BackgroundTransparency = 1
    ic.TextSize = 13
    ic.Parent = btn

    local tx = Instance.new("TextLabel")
    tx.Text = text
    tx.Size = UDim2.new(1, -78, 1, 0)
    tx.Position = UDim2.new(0, 32, 0, 0)
    tx.BackgroundTransparency = 1
    tx.TextColor3 = CLR.textDim
    tx.TextSize = 10
    tx.Font = Enum.Font.GothamBold
    tx.TextXAlignment = Enum.TextXAlignment.Left
    tx.Parent = btn

    local pill = Instance.new("Frame")
    pill.Size = UDim2.new(0, 34, 0, 14)
    pill.Position = UDim2.new(1, -40, 0.5, -7)
    pill.BackgroundColor3 = CLR.border
    pill.BorderSizePixel = 0
    pill.Parent = btn
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 10, 0, 10)
    dot.Position = UDim2.new(0, 2, 0.5, -5)
    dot.BackgroundColor3 = CLR.textDim
    dot.BorderSizePixel = 0
    dot.Parent = pill
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local isOn = false
    local ti = TweenInfo.new(0.18, Enum.EasingStyle.Quad)

    local function set(on)
        isOn = on
        if on then
            TweenService:Create(pill, ti, {BackgroundColor3 = activeColor}):Play()
            TweenService:Create(dot,  ti, {
                Position = UDim2.new(1, -12, 0.5, -5),
                BackgroundColor3 = CLR.white
            }):Play()
            TweenService:Create(bst, ti, {Color = activeColor}):Play()
            tx.TextColor3 = CLR.white
        else
            TweenService:Create(pill, ti, {BackgroundColor3 = CLR.border}):Play()
            TweenService:Create(dot,  ti, {
                Position = UDim2.new(0, 2, 0.5, -5),
                BackgroundColor3 = CLR.textDim
            }):Play()
            TweenService:Create(bst, ti, {Color = CLR.border}):Play()
            tx.TextColor3 = CLR.textDim
        end
    end

    return btn, set, function() return isOn end
end

local function smBtn(parent, txt, x, y, w, h, col, action)
    local b = Instance.new("TextButton")
    b.Text = txt
    b.Size = UDim2.new(0, w, 0, h)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = col
    b.TextColor3 = CLR.white
    b.TextSize = 9
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(action)
    return b
end

-- ===== LAYOUT =====
local cW = 128  -- عرض كل بطاقة
local cH = 100  -- ارتفاع الصف الأول
local g  = 6    -- فراغ

-- ========== بطاقة 1: AUTO THROW ==========
local c1, c1st = card(0, 0, cW, cH)
lbl(c1, "🤖  AUTO THROW", 6, 9, CLR.textDim)

local AutoBtn, setAuto, getAuto = toggle(c1, "🤖", "يرمي تلقائياً", 20, CLR.green)

-- Speed
local spF = Instance.new("Frame")
spF.Size = UDim2.new(1, -8, 0, 20)
spF.Position = UDim2.new(0, 4, 0, 56)
spF.BackgroundTransparency = 1
spF.Parent = c1

local spLbl = Instance.new("TextLabel")
spLbl.Text = "⏱ "..throwDelay.."ث"
spLbl.Size = UDim2.new(0.52, 0, 1, 0)
spLbl.BackgroundTransparency = 1
spLbl.TextColor3 = CLR.textDim
spLbl.TextSize = 8
spLbl.Font = Enum.Font.Gotham
spLbl.TextXAlignment = Enum.TextXAlignment.Left
spLbl.Parent = spF

smBtn(spF, "−", 68,  0, 24, 20, CLR.surface2, function()
    throwDelay = math.max(0.5, throwDelay - 0.5)
    throwDelay = math.floor(throwDelay*10)/10
    spLbl.Text = "⏱ "..throwDelay.."ث"
end)
smBtn(spF, "+", 96,  0, 24, 20, CLR.surface2, function()
    throwDelay = throwDelay + 0.5
    throwDelay = math.floor(throwDelay*10)/10
    spLbl.Text = "⏱ "..throwDelay.."ث"
end)

local CountTxt = Instance.new("TextLabel")
CountTxt.Text = "0 رمية"
CountTxt.Size = UDim2.new(1, -8, 0, 12)
CountTxt.Position = UDim2.new(0, 6, 1, -16)
CountTxt.BackgroundTransparency = 1
CountTxt.TextColor3 = CLR.textDim
CountTxt.TextSize = 8
CountTxt.Font = Enum.Font.Gotham
CountTxt.TextXAlignment = Enum.TextXAlignment.Left
CountTxt.Parent = c1

-- ========== بطاقة 2: PERFECT MODE ==========
local c2, c2st = card(cW+g, 0, cW, cH)
lbl(c2, "🎯  PERFECT MODE", 6, 9, CLR.textDim)

local PerfBtn, setPerf, getPerf = toggle(c2, "🎯", "اضغط عند أخضر", 20, CLR.gold)

-- Threshold Slider
local threshRow = Instance.new("Frame")
threshRow.Size = UDim2.new(1, -8, 0, 20)
threshRow.Position = UDim2.new(0, 4, 0, 56)
threshRow.BackgroundTransparency = 1
threshRow.Parent = c2

local threshLbl = Instance.new("TextLabel")
threshLbl.Text = "🟢 "..math.floor(GREEN_THRESHOLD*100).."%"
threshLbl.Size = UDim2.new(0.52, 0, 1, 0)
threshLbl.BackgroundTransparency = 1
threshLbl.TextColor3 = CLR.gold
threshLbl.TextSize = 8
threshLbl.Font = Enum.Font.GothamBold
threshLbl.TextXAlignment = Enum.TextXAlignment.Left
threshLbl.Parent = threshRow

smBtn(threshRow, "−", 68, 0, 24, 20, CLR.surface2, function()
    GREEN_THRESHOLD = math.max(0.4, GREEN_THRESHOLD - 0.05)
    threshLbl.Text = "🟢 "..math.floor(GREEN_THRESHOLD*100).."%"
end)
smBtn(threshRow, "+", 96, 0, 24, 20, CLR.surface2, function()
    GREEN_THRESHOLD = math.min(0.95, GREEN_THRESHOLD + 0.05)
    threshLbl.Text = "🟢 "..math.floor(GREEN_THRESHOLD*100).."%"
end)

local PerfStatusTxt = Instance.new("TextLabel")
PerfStatusTxt.Text = "منتظر..."
PerfStatusTxt.Size = UDim2.new(1, -8, 0, 12)
PerfStatusTxt.Position = UDim2.new(0, 6, 1, -16)
PerfStatusTxt.BackgroundTransparency = 1
PerfStatusTxt.TextColor3 = CLR.textDim
PerfStatusTxt.TextSize = 8
PerfStatusTxt.Font = Enum.Font.Gotham
PerfStatusTxt.TextXAlignment = Enum.TextXAlignment.Left
PerfStatusTxt.Parent = c2

-- ========== بطاقة 3: AUTO TRAIN ==========
local c3, c3st = card((cW+g)*2, 0, cW, cH)
lbl(c3, "💪  AUTO TRAIN", 6, 9, CLR.textDim)

local TrainBtn, setTrain, getTrain = toggle(c3, "💪", "تدريب تلقائي", 20, CLR.green)

local TrainCountTxt = Instance.new("TextLabel")
TrainCountTxt.Text = "0 تدريب"
TrainCountTxt.Size = UDim2.new(1, -8, 0, 12)
TrainCountTxt.Position = UDim2.new(0, 6, 0, 56)
TrainCountTxt.BackgroundTransparency = 1
TrainCountTxt.TextColor3 = CLR.textDim
TrainCountTxt.TextSize = 8
TrainCountTxt.Font = Enum.Font.Gotham
TrainCountTxt.TextXAlignment = Enum.TextXAlignment.Left
TrainCountTxt.Parent = c3

local TrainPowerTxt = Instance.new("TextLabel")
TrainPowerTxt.Text = "Power: --"
TrainPowerTxt.Size = UDim2.new(1, -8, 0, 12)
TrainPowerTxt.Position = UDim2.new(0, 6, 1, -16)
TrainPowerTxt.BackgroundTransparency = 1
TrainPowerTxt.TextColor3 = CLR.green
TrainPowerTxt.TextSize = 8
TrainPowerTxt.Font = Enum.Font.GothamBold
TrainPowerTxt.TextXAlignment = Enum.TextXAlignment.Left
TrainPowerTxt.Parent = c3

-- ===== الصف الثاني =====
local row2Y = cH + g

-- ========== بطاقة 4: SET POWER ==========
local c4, c4st = card(0, row2Y, 200, 68)
lbl(c4, "⚡  THROW POWER", 6, 9, CLR.textDim)

local ValDisp = Instance.new("Frame")
ValDisp.Size = UDim2.new(0, 80, 0, 22)
ValDisp.Position = UDim2.new(0, 6, 0, 22)
ValDisp.BackgroundColor3 = CLR.bg
ValDisp.BorderSizePixel = 0
ValDisp.Parent = c4
Instance.new("UICorner", ValDisp).CornerRadius = UDim.new(0, 6)

local ValTxt = Instance.new("TextLabel")
ValTxt.Text = tostring(customPow)
ValTxt.Size = UDim2.new(1, 0, 1, 0)
ValTxt.BackgroundTransparency = 1
ValTxt.TextColor3 = CLR.accentL
ValTxt.TextSize = 10
ValTxt.Font = Enum.Font.GothamBold
ValTxt.Parent = ValDisp

smBtn(c4, "−10K",  92, 22, 32, 22, Color3.fromRGB(100,20,20), function()
    customPow = math.max(1000, customPow - 10000)
    ValTxt.Text = tostring(customPow)
end)
smBtn(c4, "RST", 128, 22, 28, 22, CLR.surface2, function()
    customPow = 7703
    ValTxt.Text = tostring(customPow)
end)
smBtn(c4, "+10K", 160, 22, 32, 22, Color3.fromRGB(20,80,20), function()
    customPow = customPow + 10000
    ValTxt.Text = tostring(customPow)
end)

local AppBtn = Instance.new("TextButton")
AppBtn.Text = "⚡ APPLY POWER"
AppBtn.Size = UDim2.new(1, -8, 0, 20)
AppBtn.Position = UDim2.new(0, 4, 1, -24)
AppBtn.BackgroundColor3 = CLR.accent
AppBtn.TextColor3 = CLR.white
AppBtn.TextSize = 10
AppBtn.Font = Enum.Font.GothamBold
AppBtn.BorderSizePixel = 0
AppBtn.Parent = c4
Instance.new("UICorner", AppBtn).CornerRadius = UDim.new(0, 8)

-- ========== بطاقة 5: STATUS ==========
local c5, c5st = card(206, row2Y, 208, 68)
lbl(c5, "📊  STATUS", 6, 9, CLR.textDim)

local StTxt = Instance.new("TextLabel")
StTxt.Text = "● جاهز"
StTxt.Size = UDim2.new(1, -10, 0, 32)
StTxt.Position = UDim2.new(0, 6, 0, 22)
StTxt.BackgroundTransparency = 1
StTxt.TextColor3 = CLR.green
StTxt.TextSize = 10
StTxt.Font = Enum.Font.GothamBold
StTxt.TextXAlignment = Enum.TextXAlignment.Left
StTxt.TextWrapped = true
StTxt.Parent = c5

local CrTxt = Instance.new("TextLabel")
CrTxt.Text = "dotbhai @#9002111185000#"
CrTxt.Size = UDim2.new(1, -8, 0, 12)
CrTxt.Position = UDim2.new(0, 6, 1, -16)
CrTxt.BackgroundTransparency = 1
CrTxt.TextColor3 = CLR.textDim
CrTxt.TextSize = 7
CrTxt.Font = Enum.Font.Gotham
CrTxt.TextXAlignment = Enum.TextXAlignment.Left
CrTxt.Parent = c5

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

-- ===== POSITION UPDATE =====
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
    setAuto(autoOn)

    if autoOn then
        startAutoLoop()
        StTxt.Text = "● Auto Throw نشط"
        StTxt.TextColor3 = CLR.green

        task.spawn(function()
            while autoOn do
                StTxt.Text = "📍 ينتقل للرمي..."
                StTxt.TextColor3 = CLR.gold
                teleport(THROW_POS)

                local completed = false
                for _ = 1, 60 do
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
        stopAutoLoop()
        StTxt.Text = "● Stopped"
        StTxt.TextColor3 = CLR.textDim
    end
end)

-- ===== LOGIC: PERFECT MODE =====
-- يعمل بالتوازي مع Auto Throw
-- يراقب موقع الشريط الأبيض في البار
-- ويضغط فقط عندما يكون في المنطقة الخضراء
local perfActive = false

PerfBtn.MouseButton1Click:Connect(function()
    perfActive = not perfActive
    setPerf(perfActive)

    if perfActive then
        PerfStatusTxt.Text = "يراقب البار..."
        PerfStatusTxt.TextColor3 = CLR.gold

        if perfectConn then perfectConn:Disconnect() end
        perfectConn = RunService.Heartbeat:Connect(function()
            if not perfActive then return end
            local root = getRoot()
            if not root then return end

            -- تأكد في منطقة الرمي
            if math.abs(root.Position.X - THROW_POS.X) > 5
            or math.abs(root.Position.Z - THROW_POS.Z) > 5 then return end

            local ratio = getMarkerRatio()
            if ratio then
                -- اضغط فقط عند الأخضر
                if ratio >= GREEN_THRESHOLD then
                    local cx, cy = getScreenCenter()
                    pcall(function() ThrowMeter:FireServer() end)
                    simulateTap(cx, cy)

                    PerfStatusTxt.Text = string.format("✅ %.0f%%", ratio*100)
                    PerfStatusTxt.TextColor3 = CLR.green

                    -- reset display بعد ثانية
                    task.delay(0.8, function()
                        if perfActive then
                            PerfStatusTxt.Text = "يراقب البار..."
                            PerfStatusTxt.TextColor3 = CLR.gold
                        end
                    end)
                else
                    PerfStatusTxt.Text = string.format("📊 %.0f%%", ratio*100)
                    PerfStatusTxt.TextColor3 = ratio > 0.4
                        and CLR.gold or CLR.textDim
                end
            end
        end)
    else
        if perfectConn then perfectConn:Disconnect() end
        PerfStatusTxt.Text = "منتظر..."
        PerfStatusTxt.TextColor3 = CLR.textDim
        StTxt.Text = "● Stopped"
        StTxt.TextColor3 = CLR.textDim
    end
end)

-- ===== LOGIC: AUTO TRAIN =====
TrainBtn.MouseButton1Click:Connect(function()
    trainOn = not trainOn
    setTrain(trainOn)

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
                    TrainPowerTxt.Text = "Power: "..tostring(tp.Value)
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

-- ===== SET POWER =====
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
        and UDim2.new(0, 420, 0, 48)
        or  UDim2.new(0, 420, 0, 265)
    MinBtn.Text = mini and "+" or "−"
end)

XBtn.MouseButton1Click:Connect(function()
    autoOn   = false
    trainOn  = false
    perfActive = false
    stopAutoLoop()
    if perfectConn then perfectConn:Disconnect() end
    sg:Destroy()
end)
