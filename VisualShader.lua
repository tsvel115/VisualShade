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
local dof = Lighting:FindFirstChild("TestDOF")
    or (cam and cam:FindFirstChild("TestDOF"))
    or Instance.new("DepthOfFieldEffect")
dof.Name = "TestDOF"
dof.Parent = dof.Parent or Lighting
local rays   = get("SunRaysEffect", Lighting)
local atm    = get("Atmosphere", Lighting)
local clouds = get("Clouds", workspace.Terrain)

-- Pastikan efek aktif, dan matikan efek duplikat bawaan game yang bisa menimpa
for _, e in ipairs(Lighting:GetChildren()) do
    if (e:IsA("ColorCorrectionEffect") and e ~= cc)
    or (e:IsA("BloomEffect") and e ~= bloom)
    or (e:IsA("SunRaysEffect") and e ~= rays) then
        e.Enabled = false
    end
end
cc.Enabled, bloom.Enabled, rays.Enabled = true, true, true

-- DOF: instance sendiri, nilai awal langsung terlihat (dekat tajam, jauh blur)
local DOF_DEF = {far = 0.8, near = 0, focus = 20, radius = 10}
local dofParentMode = (dof.Parent == Lighting) and "Lighting" or "Camera"
local dofLock = true

local function dofTarget()
    return dofParentMode == "Camera" and workspace.CurrentCamera or Lighting
end

local dofVals = {far = DOF_DEF.far, near = DOF_DEF.near, focus = DOF_DEF.focus, radius = DOF_DEF.radius}

local function setDOF(far, near, focus, radius)
    dofVals.far, dofVals.near, dofVals.focus, dofVals.radius = far, near, focus, radius
    dof.Enabled = true
    dof.FarIntensity = far
    dof.NearIntensity = near
    dof.FocusDistance = focus
    dof.InFocusRadius = radius
end

local function otherDOFs()
    local list = {}
    for _, p in ipairs({Lighting, workspace.CurrentCamera}) do
        for _, e in ipairs(p:GetChildren()) do
            if e:IsA("DepthOfFieldEffect") and e ~= dof then
                table.insert(list, e)
            end
        end
    end
    return list
end

local function killOtherDOFs()
    for _, e in ipairs(otherDOFs()) do e.Enabled = false end
end

setDOF(DOF_DEF.far, DOF_DEF.near, DOF_DEF.focus, DOF_DEF.radius)
killOtherDOFs()

-- Mode kunci: terapkan ulang tiap frame kalau game menimpa efek
RS.Heartbeat:Connect(function()
    if not dofLock then return end
    if dof.Parent ~= dofTarget() then dof.Parent = dofTarget() end
    setDOF(dofVals.far, dofVals.near, dofVals.focus, dofVals.radius)
    killOtherDOFs()
end)

local S = {}
local saved = {} -- nilai slider yang sudah kamu atur (dipakai ulang setelah ganti map)

-- Objek diambil saat dipakai (bukan disimpan), supaya tetap benar kalau efeknya dibuat ulang
local getObj = {
    cc     = function() return cc end,
    bloom  = function() return bloom end,
    rays   = function() return rays end,
    atm    = function() return atm end,
    clouds = function() return clouds end,
    light  = function() return Lighting end,
}

local function add(name, min, max, key, p)
    local f = getObj[key]
    table.insert(S, {name, min, max, function() return f()[p] end, function(v) f()[p] = v end})
end

-- Warna
add("Saturation", -1, 2, "cc", "Saturation")
add("Contrast", -1, 1, "cc", "Contrast")
add("Brightness", -1, 1, "cc", "Brightness")
for _, ch in ipairs({"R", "G", "B"}) do
    table.insert(S, {"Tint " .. ch, 0, 1,
        function() return cc.TintColor[ch] end,
        function(v)
            local c = cc.TintColor
            cc.TintColor = Color3.new(ch == "R" and v or c.R, ch == "G" and v or c.G, ch == "B" and v or c.B)
        end})
end

-- Matahari & cahaya
add("Time of Day", 0, 24, "light", "ClockTime")
add("Sun Brightness", 0, 10, "light", "Brightness")
add("Exposure", -3, 3, "light", "ExposureCompensation")
add("Sun Glare", 0, 10, "atm", "Glare")
add("Sun Rays", 0, 1, "rays", "Intensity")
add("Rays Spread", 0, 1, "rays", "Spread")
add("Bloom", 0, 3, "bloom", "Intensity")
add("Bloom Size", 0, 56, "bloom", "Size")
add("Bloom Threshold", 0, 4, "bloom", "Threshold")

-- DOF
local function addDOF(name, min, max, key, prop)
    table.insert(S, {name, min, max,
        function() return dof[prop] end,
        function(v)
            dofVals[key] = v
            dof.Enabled = true
            dof[prop] = v
        end})
end
addDOF("DOF Far", 0, 1, "far", "FarIntensity")
addDOF("DOF Near", 0, 1, "near", "NearIntensity")
addDOF("DOF Focus Dist", 0, 300, "focus", "FocusDistance")
addDOF("DOF Radius", 0, 100, "radius", "InFocusRadius")

-- Fog & awan
add("Fog Density", 0, 1, "atm", "Density")
add("Fog Haze", 0, 10, "atm", "Haze")
add("Fog Offset", 0, 1, "atm", "Offset")
add("Cloud Cover", 0, 1, "clouds", "Cover")
add("Cloud Density", 0, 1, "clouds", "Density")

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
local refreshers = {}
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
        if apply then
            setv(v)
            saved[name] = v
        end
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        label.Text = string.format("%s: %.2f", name, v)
    end
    set((getv() - min) / (max - min), false)
    table.insert(refreshers, function() set((getv() - min) / (max - min), false) end)

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

-- Tombol DOF (di bagian bawah menu)
local function refreshAll()
    for _, f in ipairs(refreshers) do f() end
end

local function mkPanelBtn(text, x, y, w)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, 30)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.TextSize = 12
    b.Text = text
    b.Parent = sf
    return b
end

local by = #S * 44 + 14
local hdr = Instance.new("TextLabel")
hdr.Size = UDim2.new(1, -20, 0, 16)
hdr.Position = UDim2.new(0, 10, 0, by)
hdr.BackgroundTransparency = 1
hdr.TextColor3 = Color3.fromRGB(180, 220, 255)
hdr.TextSize = 12
hdr.TextXAlignment = Enum.TextXAlignment.Left
hdr.Text = "Pengaturan DOF"
hdr.Parent = sf

local testBtn = mkPanelBtn("Tes Blur MAX", 10, by + 22, 100)
testBtn.MouseButton1Click:Connect(function()
    setDOF(1, 1, 0, 0)
    refreshAll()
end)

local resetBtn = mkPanelBtn("Reset DOF", 118, by + 22, 100)
resetBtn.MouseButton1Click:Connect(function()
    setDOF(DOF_DEF.far, DOF_DEF.near, DOF_DEF.focus, DOF_DEF.radius)
    refreshAll()
end)

local parentBtn = mkPanelBtn("Parent: " .. dofParentMode, 10, by + 58, 100)
parentBtn.MouseButton1Click:Connect(function()
    dofParentMode = (dofParentMode == "Lighting") and "Camera" or "Lighting"
    dof.Parent = dofTarget()
    setDOF(dofVals.far, dofVals.near, dofVals.focus, dofVals.radius)
    parentBtn.Text = "Parent: " .. dofParentMode
end)

local lockBtn = mkPanelBtn("Kunci: ON", 118, by + 58, 100)
lockBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 60)
lockBtn.MouseButton1Click:Connect(function()
    dofLock = not dofLock
    lockBtn.Text = "Kunci: " .. (dofLock and "ON" or "OFF")
    lockBtn.BackgroundColor3 = dofLock and Color3.fromRGB(0, 120, 60) or Color3.fromRGB(50, 50, 50)
end)

local killBtn = mkPanelBtn("Matikan DOF lain", 10, by + 94, 208)
killBtn.MouseButton1Click:Connect(function()
    killOtherDOFs()
    setDOF(dofVals.far, dofVals.near, dofVals.focus, dofVals.radius)
end)

sf.CanvasSize = UDim2.new(0, 0, 0, by + 134)

-- ===== Tahan banting saat ganti map =====
-- Game sering menghapus/mengganti efek di Lighting saat ganti map. Script ini
-- membuat ulang efeknya dan menerapkan lagi nilai slider yang sudah kamu atur.
local function ensureEffects()
    if not (cc and cc.Parent == Lighting) then cc = get("ColorCorrectionEffect", Lighting) end
    if not (bloom and bloom.Parent == Lighting) then bloom = get("BloomEffect", Lighting) end
    if not (rays and rays.Parent == Lighting) then rays = get("SunRaysEffect", Lighting) end
    if not (atm and atm.Parent == Lighting) then atm = get("Atmosphere", Lighting) end
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if terrain and not (clouds and clouds.Parent == terrain) then
        clouds = get("Clouds", terrain)
    end
    if not (dof and dof.Parent == dofTarget()) then
        local c = workspace.CurrentCamera
        dof = Lighting:FindFirstChild("TestDOF")
            or (c and c:FindFirstChild("TestDOF"))
            or Instance.new("DepthOfFieldEffect")
        dof.Name = "TestDOF"
        dof.Parent = dofTarget()
    end
    cc.Enabled, bloom.Enabled, rays.Enabled = true, true, true
end

local function reapplySaved()
    for _, s in ipairs(S) do
        local v = saved[s[1]]
        if v ~= nil then pcall(s[5], v) end
    end
end

local function killDupes()
    for _, e in ipairs(Lighting:GetChildren()) do
        if (e:IsA("ColorCorrectionEffect") and e ~= cc)
        or (e:IsA("BloomEffect") and e ~= bloom)
        or (e:IsA("SunRaysEffect") and e ~= rays) then
            e.Enabled = false
        end
    end
end

local busy = false
local function maintain()
    if busy then return end
    busy = true
    pcall(function()
        ensureEffects()
        reapplySaved()
        setDOF(dofVals.far, dofVals.near, dofVals.focus, dofVals.radius)
        if dofLock then
            killOtherDOFs()
            killDupes()
        end
    end)
    busy = false
end

task.spawn(function()
    while sg.Parent do
        maintain()
        task.wait(0.25)
    end
end)
Lighting.ChildRemoved:Connect(function() task.defer(maintain) end)
Lighting.ChildAdded:Connect(function() task.defer(maintain) end)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    cam = workspace.CurrentCamera
    task.defer(maintain)
end)

-- FREECAM
local fcOn = false
local rmbDown = false
local prevBehavior = Enum.MouseBehavior.Default
local pos, yaw, pitch = Vector3.zero, 0, 0
local up, down = false, false
local speeds = {0.5, 1, 2, 4}
local si = 2

local fcBtn  = mkBtn("🎥", {0, 62}, {0.2, -42})
local spdBtn = mkBtn("Spd 1x", {0, 104}, {0.2, -42}, 64)
local upBtn  = mkBtn("▲", {1, -60}, {0.5, -48})
local dnBtn  = mkBtn("▼", {1, -60}, {0.5, 0})
spdBtn.Visible, upBtn.Visible, dnBtn.Visible = false, false, false

-- Area putar kamera (setengah layar kanan, hanya aktif saat freecam menyala)
local lookInput = nil
local pad = Instance.new("Frame")
pad.Size = UDim2.new(0.5, 0, 1, 0)
pad.Position = UDim2.new(0.5, 0, 0, 0)
pad.BackgroundTransparency = 1
pad.Active = true
pad.ZIndex = 0
pad.Visible = false
pad.Parent = sg
pad.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch and not lookInput then
        lookInput = input
    end
end)

local function setFreecam(on)
    fcOn = on
    local char = plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    spdBtn.Visible, upBtn.Visible, dnBtn.Visible = on, on, on
    pad.Visible = on
    lookInput = nil
    if on then
        pos = cam.CFrame.Position
        prevBehavior = UIS.MouseBehavior
        pitch, yaw = cam.CFrame:ToOrientation()
        cam.CameraType = Enum.CameraType.Scriptable
        if hrp then hrp.Anchored = true end
    else
        up, down, rmbDown = false, false, false
        UIS.MouseBehavior = prevBehavior
        if hrp then hrp.Anchored = false end
        local function restore()
            cam = workspace.CurrentCamera
            cam.CameraType = Enum.CameraType.Custom
            if hum then cam.CameraSubject = hum end
        end
        restore()
        task.delay(0.1, function() if not fcOn then restore() end end)
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

-- Putar kamera: klik kanan + geser (PC) / geser setengah layar kanan (HP)
UIS.InputChanged:Connect(function(input)
    if fcOn and lookInput ~= nil and input == lookInput then
        yaw = yaw - input.Delta.X * 0.004
        pitch = math.clamp(pitch - input.Delta.Y * 0.004, -1.5, 1.5)
    end
end)
UIS.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then rmbDown = true end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then rmbDown = false end
    if input == lookInput then lookInput = nil end
end)

RS.RenderStepped:Connect(function(dt)
    if not fcOn then return end
    cam.CameraType = Enum.CameraType.Scriptable

    -- Putar kamera di PC (klik kanan + geser, atau langsung kalau game sudah mengunci mouse)
    if rmbDown then
        UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
    else
        UIS.MouseBehavior = prevBehavior
    end
    if rmbDown or prevBehavior ~= Enum.MouseBehavior.Default then
        local d = UIS:GetMouseDelta()
        yaw = yaw - d.X * 0.004
        pitch = math.clamp(pitch - d.Y * 0.004, -1.5, 1.5)
    end

    local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
    local move = hum and hum.MoveDirection or Vector3.zero
    local v = (up or UIS:IsKeyDown(Enum.KeyCode.E)) and 1 or 0
    v = v - ((down or UIS:IsKeyDown(Enum.KeyCode.Q)) and 1 or 0)
    local fast = UIS:IsKeyDown(Enum.KeyCode.LeftShift) and 3 or 1
    pos = pos + (move + Vector3.new(0, v, 0)) * 50 * speeds[si] * fast * dt
    cam.CFrame = CFrame.new(pos) * CFrame.fromOrientation(pitch, yaw, 0)
end)
