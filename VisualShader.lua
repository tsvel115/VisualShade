-- Visual Shader + Freecam (client-side, untuk executor)
local Lighting = game:GetService("Lighting")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local cam = workspace.CurrentCamera

local uiDrag = false -- true saat slider sedang digeser

local function get(cls, parent)
    local o = parent:FindFirstChildOfClass(cls) or Instance.new(cls)
    o.Parent = parent
    return o
end

local cc     = get("ColorCorrectionEffect", Lighting)
local bloom  = get("BloomEffect", Lighting)
local dof    = get("DepthOfFieldEffect", Lighting)
local rays   = get("SunRaysEffect", Lighting)
local atm    = get("Atmosphere", Lighting)
local clouds = get("Clouds", workspace.Terrain)

local S = {}
local function add(name, min, max, o, p)
    table.insert(S, {name, min, max, function() return o[p] end, function(v) o[p] = v end})
end

-- Warna
add("Saturation", -1, 2, cc, "Saturation")
add("Contrast", -1, 1, cc, "Contrast")
add("Brightness", -1, 1, cc, "Brightness")
for _, ch in ipairs({"R", "G", "B"}) do
    table.insert(S, {"Tint " .. ch, 0, 1,
        function() return cc.TintColor[ch] end,
        function(v)
            local c = cc.TintColor
            cc.TintColor = Color3.new(ch == "R" and v or c.R, ch == "G" and v or c.G, ch == "B" and v or c.B)
        end})
end

-- Matahari & cahaya
add("Time of Day", 0, 24, Lighting, "ClockTime")
add("Sun Brightness", 0, 10, Lighting, "Brightness")
add("Exposure", -3, 3, Lighting, "ExposureCompensation")
add("Sun Glare", 0, 10, atm, "Glare")
add("Sun Rays", 0, 1, rays, "Intensity")
add("Rays Spread", 0, 1, rays, "Spread")
add("Bloom", 0, 3, bloom, "Intensity")
add("Bloom Size", 0, 56, bloom, "Size")
add("Bloom Threshold", 0, 4, bloom, "Threshold")

-- DOF
add("DOF Far", 0, 1, dof, "FarIntensity")
add("DOF Near", 0, 1, dof, "NearIntensity")
add("DOF Focus Dist", 0, 500, dof, "FocusDistance")
add("DOF Radius", 0, 200, dof, "InFocusRadius")

-- Fog & awan
add("Fog Density", 0, 1, atm, "Density")
add("Fog Haze", 0, 10, atm, "Haze")
add("Fog Offset", 0, 1, atm, "Offset")
add("Cloud Cover", 0, 1, clouds, "Cover")
add("Cloud Density", 0, 1, clouds, "Density")

-- GUI
local sg = Instance.new("ScreenGui")
sg.ResetOnSpawn = false
local ok = pcall(function() sg.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not ok or not sg.Parent then
    sg.Parent = plr:WaitForChild("PlayerGui")
end

local sf = Instance.new("ScrollingFrame")
sf.Size = UDim2.new(0, 240, 0, 320)
sf.Position = UDim2.new(0, 20, 0.2, 0)
sf.CanvasSize = UDim2.new(0, 0, 0, #S * 44 + 10)
sf.ScrollBarThickness = 4
sf.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
sf.Parent = sg

local function mkBtn(text, x, y, w)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w or 36, 0, 36)
    b.Position = UDim2.new(x[1], x[2], y[1], y[2])
    b.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.TextSize = 16
    b.Text = text
    b.Parent = sg
    return b
end

-- Tombol sembunyi/tampilkan menu
local tbtn = mkBtn("☰", {0, 20}, {0.2, -42})
tbtn.TextSize = 20
tbtn.MouseButton1Click:Connect(function() sf.Visible = not sf.Visible end)
UIS.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.RightShift then
        sf.Visible = not sf.Visible
    end
end)

-- Slider
for i, s in ipairs(S) do
    local name, min, max, getv, setv = unpack(s)
    local y = 10 + (i - 1) * 44

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 16)
    label.Position = UDim2.new(0, 10, 0, y)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = sf

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -30, 0, 14)
    bar.Position = UDim2.new(0, 10, 0, y + 20)
    bar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    bar.Parent = sf

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    fill.BorderSizePixel = 0
    fill.Parent = bar

    local function set(alpha, apply)
        alpha = math.clamp(alpha, 0, 1)
        local v = min + (max - min) * alpha
        if apply then setv(v) end
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        label.Text = string.format("%s: %.2f", name, v)
    end
    set((getv() - min) / (max - min), false)

    local dragging = false
    local function fromInput(input)
        set((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, true)
    end
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            uiDrag = true
            sf.ScrollingEnabled = false
            fromInput(input)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            fromInput(input)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            uiDrag = false
            sf.ScrollingEnabled = true
        end
    end)
end

-- FREECAM
local fcOn = false
local pos, yaw, pitch = Vector3.zero, 0, 0
local up, down = false, false
local speeds = {0.5, 1, 2, 4}
local si = 2

local fcBtn  = mkBtn("🎥", {0, 62}, {0.2, -42})
local spdBtn = mkBtn("Spd 1x", {0, 104}, {0.2, -42}, 64)
local upBtn  = mkBtn("▲", {1, -60}, {0.5, -48})
local dnBtn  = mkBtn("▼", {1, -60}, {0.5, 0})
spdBtn.Visible, upBtn.Visible, dnBtn.Visible = false, false, false

local function setFreecam(on)
    fcOn = on
    local char = plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    spdBtn.Visible, upBtn.Visible, dnBtn.Visible = on, on, on
    if on then
        pos = cam.CFrame.Position
        pitch, yaw = cam.CFrame:ToOrientation()
        cam.CameraType = Enum.CameraType.Scriptable
        if hrp then hrp.Anchored = true end
    else
        up, down = false, false
        if hrp then hrp.Anchored = false end
        cam.CameraType = Enum.CameraType.Custom
        if hum then cam.CameraSubject = hum end
    end
end

fcBtn.MouseButton1Click:Connect(function() setFreecam(not fcOn) end)
spdBtn.MouseButton1Click:Connect(function()
    si = si % #speeds + 1
    spdBtn.Text = "Spd " .. speeds[si] .. "x"
end)

local function isPress(i)
    return i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1
end
upBtn.InputBegan:Connect(function(i) if isPress(i) then up = true end end)
upBtn.InputEnded:Connect(function() up = false end)
dnBtn.InputBegan:Connect(function(i) if isPress(i) then down = true end end)
dnBtn.InputEnded:Connect(function() down = false end)

local function overMenu(p)
    if not sf.Visible then return false end
    local a, z = sf.AbsolutePosition, sf.AbsoluteSize
    return p.X >= a.X and p.X <= a.X + z.X and p.Y >= a.Y and p.Y <= a.Y + z.Y
end

-- Putar kamera: klik kanan + geser (PC) / geser layar (HP)
UIS.InputChanged:Connect(function(input, gpe)
    if not fcOn or uiDrag then return end
    local mouseLook = input.UserInputType == Enum.UserInputType.MouseMovement
        and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    local touchLook = input.UserInputType == Enum.UserInputType.Touch
        and not gpe and not overMenu(input.Position)
    if mouseLook or touchLook then
        yaw = yaw - input.Delta.X * 0.004
        pitch = math.clamp(pitch - input.Delta.Y * 0.004, -1.5, 1.5)
    end
end)

RS.RenderStepped:Connect(function(dt)
    if not fcOn then return end
    cam.CameraType = Enum.CameraType.Scriptable
    local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
    local move = hum and hum.MoveDirection or Vector3.zero
    local v = (up or UIS:IsKeyDown(Enum.KeyCode.E)) and 1 or 0
    v = v - ((down or UIS:IsKeyDown(Enum.KeyCode.Q)) and 1 or 0)
    local fast = UIS:IsKeyDown(Enum.KeyCode.LeftShift) and 3 or 1
    pos = pos + (move + Vector3.new(0, v, 0)) * 50 * speeds[si] * fast * dt
    cam.CFrame = CFrame.new(pos) * CFrame.fromOrientation(pitch, yaw, 0)
end)
