--[[  RIVALS // VENICE v3.1 · DELTA  ]]

--=============================================================
-- 0 · SHIMS DE COMPATIBILIDAD
--=============================================================
if getgenv().VeniceUnload then pcall(getgenv().VeniceUnload) end
getgenv().VeniceLoaded = true

local gv = getgenv()
local function shim(n, f) if not gv[n] and not _G[n] then gv[n] = f end end
shim("setfpscap", function() end)
shim("protectgui", function() end)
shim("cloneref", function(o) return o end)
shim("getnamecallmethod", function() return "" end)

local cloneref = gv.cloneref
local Players      = cloneref(game:GetService("Players"))
local RunService   = cloneref(game:GetService("RunService"))
local UIS          = cloneref(game:GetService("UserInputService"))
local TweenService = cloneref(game:GetService("TweenService"))
local Lighting     = cloneref(game:GetService("Lighting"))
local Workspace    = cloneref(game:GetService("Workspace"))

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do task.wait(0.1); LocalPlayer = Players.LocalPlayer end
local Camera = Workspace.CurrentCamera
while not Camera do task.wait(0.1); Camera = Workspace.CurrentCamera end
local Mouse = LocalPlayer:GetMouse()

local EXCLUDE = (Enum.RaycastFilterType and Enum.RaycastFilterType.Exclude)
             or Enum.RaycastFilterType.Blacklist

local Connections = {}
local function bind(s, f) local c = s:Connect(f); Connections[#Connections + 1] = c; return c end

local Aimbot, SilentAim, ESP, Player, Hitbox, Trigger, OP, Optimizer, unload
local getSilentTarget

--=============================================================
-- 1 · CONFIG
--=============================================================
local Config = {
    aimbot = { enabled = false, mode = "Hold", key = Enum.KeyCode.Q, fov = 110,
        showFov = true, part = "Head", wallcheck = true, smooth = 20,
        teamCheck = true, humanize = true, prediction = 0, lock = true },
    silent = { enabled = false, mode = "Toggle", key = Enum.KeyCode.E, fov = 160,
        part = "Head", wallcheck = false, teamCheck = true, prediction = 8,
        magic = false, showFov = true, armed = 0.18, toggled = false },
    esp = { enabled = false, box = true, fill = false, name = true, distance = true,
        health = true, tracer = true, skeleton = false, chams = true,
        color = Color3.fromRGB(0, 240, 255), teamColor = Color3.fromRGB(80, 255, 130) },
    player = { walkSpeed = 16, jumpPower = 50, lockSpeed = true, fly = false,
        flySpeed = 60, flyAuto = false, noclip = false, infJump = false },
    hitbox = { enabled = false, scale = 2.2, freeze = false },
    trigger = { enabled = false, delay = 0.06, fov = 40, part = "Head" },
    op = { noRecoil = false, antiAim = false, spin = 600, ammo = false,
        autoReload = false, autoFire = false, autoFireRange = 45, antiFling = false,
        speedCFrame = false, speedValue = 60, fov = 70, fovEnabled = false },
    misc = { guiKey = Enum.KeyCode.RightShift, optimizer = false, notify = true },
}

--=============================================================
-- 2 · HOOKS
--=============================================================
local rawIndex, rawNewIndex, rawNamecall
local spoofed = setmetatable({}, { __mode = "k" })
local bypassRay = false
local camBypass = false

local function Spoof(inst, key, val)
    local t = spoofed[inst]
    if not t then t = {}; spoofed[inst] = t end
    t[key] = val
end
local function RawIndex(inst, key)
    if rawIndex then
        local ok, v = pcall(rawIndex, inst, key)
        if ok then return v end
    end
    return inst[key]
end

if hookmetamethod then
    local ok, old = pcall(function()
        return hookmetamethod(game, "__index", function(self, key)
            local sp = spoofed[self]
            if sp then
                local v = sp[key]
                if v ~= nil then return v end
            end
            if self == Mouse and Config.silent.enabled and getSilentTarget
            and (key == "Target" or key == "Hit" or key == "UnitRay") then
                local t = getSilentTarget()
                if t then
                    if key == "Target" then return t end
                    if key == "Hit" then return CFrame.new(t.Position) end
                    local o = Camera.CFrame.Position
                    return Ray.new(o, (t.Position - o).Unit * 1000)
                end
            end
            return rawIndex(self, key)
        end)
    end)
    if ok then rawIndex = old end
end

if hookmetamethod then
    local ok, old = pcall(function()
        return hookmetamethod(game, "__newindex", function(self, key, value)
            if self == Camera and key == "CFrame" and not camBypass
            and OP and OP.noRecoilUntil and tick() < OP.noRecoilUntil then
                return
            end
            return rawNewIndex(self, key, value)
        end)
    end)
    if ok then rawNewIndex = old end
end

local function rawRay(origin, dir, params)
    bypassRay = true
    local ok, res = pcall(function() return Workspace:Raycast(origin, dir, params) end)
    bypassRay = false
    return ok and res or nil
end

if hookmetamethod and getnamecallmethod then
    local ok, old = pcall(function()
        return hookmetamethod(game, "__namecall", function(self, ...)
            if bypassRay then return rawNamecall(self, ...) end
            local m = getnamecallmethod()

            if m == "Raycast" then
                local t = getSilentTarget and getSilentTarget()
                if t then
                    local origin, dir, params = ...
                    if typeof(origin) == "Vector3" and typeof(dir) == "Vector3" then
                        local nd = t.Position - origin
                        if nd.Magnitude > 0.01 then
                            return rawNamecall(self, origin, nd.Unit * dir.Magnitude, params)
                        end
                    end
                end
            elseif m == "FindPartOnRayWithIgnoreList" then
                local t = getSilentTarget and getSilentTarget()
                if t then
                    local ray, ign, terr, wat = ...
                    if typeof(ray) == "Ray" then
                        return rawNamecall(self, Ray.new(ray.Origin, t.Position - ray.Origin), ign, terr, wat)
                    end
                end
            elseif m == "FindPartOnRay" then
                local t = getSilentTarget and getSilentTarget()
                if t then
                    local ray, ign = ...
                    if typeof(ray) == "Ray" then
                        return rawNamecall(self, Ray.new(ray.Origin, t.Position - ray.Origin), ign)
                    end
                end
            elseif m == "ScreenPointToRay" or m == "ViewportPointToRay" then
                local t = getSilentTarget and getSilentTarget()
                if t then
                    local _, _, depth = ...
                    local o = Camera.CFrame.Position
                    return Ray.new(o, (t.Position - o).Unit * (depth or 1000))
                end
            elseif Config.silent.magic and (m == "FireServer" or m == "InvokeServer")
            and tick() < (Config.silent.armedUntil or 0) then
                local t = getSilentTarget and getSilentTarget()
                if t then
                    local n = select("#", ...)
                    local args = { ... }
                    local cp = Camera.CFrame.Position
                    for i = 1, n do
                        local v = args[i]
                        local tv = typeof(v)
                        if tv == "Vector3" and (v - cp).Magnitude < 500 then
                            args[i] = t.Position
                        elseif tv == "CFrame" and (v.Position - cp).Magnitude < 500 then
                            args[i] = CFrame.new(t.Position)
                        end
                    end
                    return rawNamecall(self, table.unpack(args, 1, n))
                end
            end

            return rawNamecall(self, ...)
        end)
    end)
    if ok then rawNamecall = old end
end

local function LockProperty(hum, prop, target)
    local busy = false
    bind(hum:GetPropertyChangedSignal(prop), function()
        if busy then return end
        local cur = RawIndex(hum, prop)
        if type(cur) ~= "number" or math.abs(cur - target) < 0.01 then return end
        busy = true
        pcall(function() hum[prop] = target end)
        task.wait()
        busy = false
    end)
end

--=============================================================
-- 3 · TARGETING
--=============================================================
local rayParams = RaycastParams.new()
rayParams.FilterType = EXCLUDE
rayParams.IgnoreWater = true

local function visible(part, char)
    rayParams.FilterDescendantsInstances = { char, LocalPlayer.Character }
    local o = Camera.CFrame.Position
    return rawRay(o, part.Position - o, rayParams) == nil
end

local function lead(hrp, amt)
    if amt <= 0 then return Vector3.zero end
    return hrp.AssemblyLinearVelocity * (amt / 100) * 0.1
end

local function resolve(cfg)
    local center = Camera.ViewportSize / 2
    local best, score = nil, cfg.fov
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local ok, part, pos = pcall(function()
                local char = plr.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not (hum and hrp and hum.Health > 0) then return nil end
                if cfg.teamCheck and plr.Team and LocalPlayer.Team
                and plr.Team == LocalPlayer.Team then return nil end
                local p = char:FindFirstChild(cfg.part)
                if not p then return nil end
                local sp, on = Camera:WorldToViewportPoint(p.Position)
                if not on or sp.Z <= 0 then return nil end
                if (Vector2.new(sp.X, sp.Y) - center).Magnitude > score then return nil end
                if cfg.wallcheck and not visible(p, char) then return nil end
                return p, p.Position + lead(hrp, cfg.prediction or 0)
            end)
            if ok and part then
                local sp = Camera:WorldToViewportPoint(part.Position)
                local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                if d < score then best, score = { part = part, pos = pos }, d end
            end
        end
    end
    return best
end

getSilentTarget = function()
    if not Config.silent.enabled then return nil end
    local on = (Config.silent.mode == "Always")
        or (Config.silent.mode == "Toggle" and Config.silent.toggled)
        or (Config.silent.mode == "Hold" and UIS:IsKeyDown(Config.silent.key))
    if not on then return nil end
    local r = resolve(Config.silent)
    return r and r.part
end

--=============================================================
-- 4 · UI LIB
--=============================================================
local T = {
    bg = Color3.fromRGB(9, 9, 13), panel = Color3.fromRGB(16, 17, 23),
    item = Color3.fromRGB(22, 23, 31), stroke = Color3.fromRGB(40, 43, 56),
    acc = Color3.fromRGB(0, 240, 255), acc2 = Color3.fromRGB(255, 0, 160),
    txt = Color3.fromRGB(232, 236, 244), dim = Color3.fromRGB(116, 122, 138),
    f = Enum.Font.GothamMedium, fb = Enum.Font.GothamBold,
}
local function mk(c, p, par)
    local i = Instance.new(c)
    for k, v in next, p do i[k] = v end
    if par then i.Parent = par end
    return i
end
local function cnr(i, r) return mk("UICorner", { CornerRadius = UDim.new(0, r or 6) }, i) end
local function stk(i, c, t, tr)
    return mk("UIStroke", { Color = c or T.stroke, Thickness = t or 1, Transparency = tr or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, i)
end
local function tw(i, p, t, s)
    local x = TweenService:Create(i, TweenInfo.new(t or 0.15, s or Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out), p)
    x:Play(); return x
end
local function drag(fr, h)
    local on, sp, st
    h.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            on = true; sp = i.Position; st = fr.Position
            i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then on = false end end)
        end
    end)
    bind(UIS.InputChanged, function(i)
        if not on then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch then
            local d = i.Position - sp
            fr.Position = UDim2.new(st.X.Scale, st.X.Offset + d.X, st.Y.Scale, st.Y.Offset + d.Y)
        end
    end)
end

local UI = {}

function UI:Window()
    local host = (gethui and gethui()) or game:GetService("CoreGui")
    local sg = mk("ScreenGui", { Name = "VeniceUI", ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 200 }, host)
    pcall(protectgui, sg)

    local main = mk("Frame", { Size = UDim2.fromOffset(600, 420),
        Position = UDim2.new(0.5, -300, 0.5, -210), BackgroundColor3 = T.bg,
        BackgroundTransparency = 0.04, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 10 }, sg)
    cnr(main, 12); stk(main, T.acc, 1, 0.6)

    local us = mk("UIScale", {}, main)
    local function rs()
        local vp = Camera.ViewportSize
        us.Scale = math.clamp(math.min(1, (vp.X - 28) / 600, (vp.Y - 56) / 420), 0.48, 1)
    end
    rs(); bind(Camera:GetPropertyChangedSignal("ViewportSize"), rs)

    local bar = mk("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = T.panel,
        BorderSizePixel = 0, ZIndex = 11 }, main)
    mk("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = T.acc, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 12 }, bar)
    drag(main, bar)

    mk("Frame", { Size = UDim2.fromOffset(8, 8), Position = UDim2.new(0, 16, 0.5, -4),
        BackgroundColor3 = T.acc, BorderSizePixel = 0, ZIndex = 13 }, bar)
    mk("TextLabel", { Text = "RIVALS // VENICE", Font = T.fb, TextSize = 14, TextColor3 = T.txt,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Position = UDim2.new(0, 32, 0, 7), Size = UDim2.new(1, -170, 0, 16), ZIndex = 13 }, bar)
    mk("TextLabel", { Text = "v3.1 · delta", Font = T.f, TextSize = 10, TextColor3 = T.dim,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Position = UDim2.new(0, 32, 0, 24), Size = UDim2.new(1, -170, 0, 12), ZIndex = 13 }, bar)

    local function topBtn(txt, x, cb)
        local b = mk("TextButton", { Text = txt, Font = T.fb, TextSize = 14, TextColor3 = T.dim,
            BackgroundColor3 = T.item, AutoButtonColor = false, Size = UDim2.fromOffset(26, 26),
            Position = UDim2.new(1, x, 0.5, -13), BorderSizePixel = 0, ZIndex = 13 }, bar)
        cnr(b, 6)
        b.MouseEnter:Connect(function() tw(b, { TextColor3 = T.acc }, 0.1) end)
        b.MouseLeave:Connect(function() tw(b, { TextColor3 = T.dim }, 0.1) end)
        b.MouseButton1Click:Connect(cb)
    end
    topBtn("✕", -36, function() main.Visible = false end)
    topBtn("—", -68, function()
        main.Size = UDim2.fromOffset(600, main.Size.Y.Offset > 60 and 44 or 420)
    end)

    local strip = mk("ScrollingFrame", { Size = UDim2.new(0, 138, 1, -78),
        Position = UDim2.new(0, 12, 0, 54), BackgroundColor3 = T.panel,
        BackgroundTransparency = 0.4, BorderSizePixel = 0, ScrollBarThickness = 2,
        ScrollBarImageColor3 = T.acc, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 11 }, main)
    cnr(strip, 8)
    mk("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, strip)
    mk("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, strip)

    local content = mk("Frame", { Size = UDim2.new(1, -162, 1, -78),
        Position = UDim2.new(0, 150, 0, 54), BackgroundTransparency = 1, ZIndex = 11 }, main)
    local foot = mk("Frame", { Size = UDim2.new(1, -24, 0, 20),
        Position = UDim2.new(0, 12, 1, -26), BackgroundTransparency = 1, ZIndex = 11 }, main)
    local st = mk("TextLabel", { Text = "listo", Font = T.f, TextSize = 10, TextColor3 = T.dim,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Size = UDim2.new(1, -90, 1, 0) }, foot)
    mk("TextLabel", { Text = "venice", Font = T.fb, TextSize = 10, TextColor3 = T.acc,
        TextXAlignment = Enum.TextXAlignment.Right, BackgroundTransparency = 1,
        Position = UDim2.new(1, -90, 0, 0), Size = UDim2.fromOffset(90, 20) }, foot)

    local w = { screen = sg, main = main, strip = strip, content = content,
        pages = {}, tabs = {}, status = st, picked = false }
    function w:Set(t) st.Text = t end
    function w:Toggle(v) self.main.Visible = (v == nil) and not self.main.Visible or v end
    return w
end

function UI:Tab(win, label, glyph)
    local b = mk("TextButton", { Text = "  " .. glyph .. "   " .. label, Font = T.fb, TextSize = 11,
        TextColor3 = T.dim, BackgroundColor3 = T.item, BackgroundTransparency = 0.4,
        AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 30), BorderSizePixel = 0,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12 }, win.strip)
    cnr(b, 6)
    local pg = mk("ScrollingFrame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = T.acc,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false, ZIndex = 11 }, win.content)
    mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, pg)
    mk("UIPadding", { PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8) }, pg)
    win.tabs[label] = b; win.pages[label] = pg

    local function sel()
        for n, p in next, win.pages do
            p.Visible = (n == label)
            tw(win.tabs[n], { TextColor3 = (n == label) and T.acc or T.dim,
                BackgroundTransparency = (n == label) and 0.05 or 0.4 }, 0.14)
        end
    end
    b.MouseButton1Click:Connect(sel)
    if not win.picked then win.picked = true; sel() end
    return pg
end

function UI:Section(pg, name)
    local f = mk("Frame", { Size = UDim2.new(1, 0, 0, 19), BackgroundTransparency = 1, ZIndex = 11 }, pg)
    mk("TextLabel", { Text = string.upper(name), Font = T.fb, TextSize = 9, TextColor3 = T.acc,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0) }, f)
    mk("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = T.stroke, BorderSizePixel = 0 }, f)
end

local function row(pg, h)
    local r = mk("Frame", { Size = UDim2.new(1, 0, 0, h or 32), BackgroundColor3 = T.item,
        BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 11 }, pg)
    cnr(r, 6); return r
end

function UI:Toggle(pg, cfg)
    local r = row(pg, 32)
    mk("TextLabel", { Text = cfg.name, Font = T.f, TextSize = 11, TextColor3 = T.txt,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -70, 1, 0) }, r)
    local tr = mk("Frame", { Size = UDim2.fromOffset(34, 17), Position = UDim2.new(1, -46, 0.5, -8.5),
        BackgroundColor3 = T.stroke, BorderSizePixel = 0, ZIndex = 12 }, r)
    cnr(tr, 9)
    local kn = mk("Frame", { Size = UDim2.fromOffset(13, 13), Position = UDim2.new(0, 2, 0.5, -6.5),
        BackgroundColor3 = T.txt, BorderSizePixel = 0, ZIndex = 13 }, tr)
    cnr(kn, 7)
    local s = cfg.default or false
    local api = {}
    local function paint(a)
        local t = a and 0.15 or 0
        tw(tr, { BackgroundColor3 = s and T.acc or T.stroke }, t)
        tw(kn, { Position = UDim2.new(s and 1 or 0, s and -15 or 2, 0.5, -6.5),
            BackgroundColor3 = s and T.bg or T.txt }, t)
    end
    function api.Set(v, silent)
        s = v and true or false; paint(not silent)
        if not silent and cfg.cb then pcall(cfg.cb, s) end
    end
    function api.Get() return s end
    paint(false)
    local hit = mk("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        Text = "", ZIndex = 14 }, r)
    hit.MouseButton1Click:Connect(function() api.Set(not s) end)
    return api
end

function UI:Slider(pg, cfg)
    local r = row(pg, 44)
    mk("TextLabel", { Text = cfg.name, Font = T.f, TextSize = 11, TextColor3 = T.txt,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 5), Size = UDim2.new(1, -80, 0, 14) }, r)
    local vl = mk("TextLabel", { Text = tostring(cfg.default), Font = T.fb, TextSize = 11,
        TextColor3 = T.acc, TextXAlignment = Enum.TextXAlignment.Right,
        BackgroundTransparency = 1, Position = UDim2.new(1, -60, 0, 5),
        Size = UDim2.fromOffset(48, 14) }, r)
    local tr = mk("Frame", { Size = UDim2.new(1, -24, 0, 4), Position = UDim2.new(0, 12, 0, 27),
        BackgroundColor3 = T.stroke, BorderSizePixel = 0, ZIndex = 12 }, r)
    cnr(tr, 2)
    local fl = mk("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = T.acc,
        BorderSizePixel = 0, ZIndex = 13 }, tr)
    cnr(fl, 2)
    local kn = mk("Frame", { Size = UDim2.fromOffset(10, 10), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = T.txt, BorderSizePixel = 0, ZIndex = 14 }, tr)
    cnr(kn, 5)
    local v, dr = cfg.default, false
    local api = {}
    local function apply(x, fire)
        v = math.clamp(x, cfg.min, cfg.max)
        if cfg.step then v = math.floor(v / cfg.step + 0.5) * cfg.step end
        local a = (v - cfg.min) / (cfg.max - cfg.min)
        fl.Size = UDim2.new(a, 0, 1, 0)
        kn.Position = UDim2.new(a, 0, 0.5, 0)
        vl.Text = cfg.dec and string.format("%.1f", v) or tostring(math.floor(v + 0.5))
        if fire and cfg.cb then pcall(cfg.cb, v) end
    end
    function api.Set(x) apply(x, true) end
    function api.Get() return v end
    apply(cfg.default, false)
    local function from(i)
        local a = math.clamp((i.Position.X - tr.AbsolutePosition.X) / math.max(tr.AbsoluteSize.X, 1), 0, 1)
        apply(cfg.min + (cfg.max - cfg.min) * a, true)
    end
    tr.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then dr = true; from(i) end
    end)
    bind(UIS.InputChanged, function(i)
        if dr and (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then from(i) end
    end)
    bind(UIS.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then dr = false end
    end)
    return api
end

function UI:Dropdown(pg, cfg)
    local r = row(pg, 32)
    mk("TextLabel", { Text = cfg.name, Font = T.f, TextSize = 11, TextColor3 = T.txt,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -110, 1, 0) }, r)
    local v = cfg.default or cfg.options[1]
    local b = mk("TextButton", { Text = tostring(v) .. "  ▾", Font = T.fb, TextSize = 10,
        TextColor3 = T.acc, BackgroundColor3 = T.panel, AutoButtonColor = false,
        Position = UDim2.new(1, -96, 0.5, -11), Size = UDim2.fromOffset(84, 22),
        BorderSizePixel = 0, ZIndex = 13 }, r)
    cnr(b, 5); stk(b, T.stroke, 1, 0.2)
    local lst = mk("Frame", { Size = UDim2.new(0, 130, 0, 0), Position = UDim2.new(1, -96, 1, 4),
        BackgroundColor3 = T.panel, BorderSizePixel = 0, ClipsDescendants = true,
        Visible = false, ZIndex = 60 }, r)
    cnr(lst, 6); stk(lst, T.acc, 1, 0.5)
    mk("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, lst)
    mk("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
        PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, lst)
    local api, open = {}, false
    local function close()
        open = false
        tw(lst, { Size = UDim2.new(0, 130, 0, 0) }, 0.13)
        task.delay(0.14, function() lst.Visible = false end)
    end
    for _, o in ipairs(cfg.options) do
        local ob = mk("TextButton", { Text = tostring(o), Font = T.f, TextSize = 10,
            TextColor3 = T.txt, BackgroundColor3 = T.item, BackgroundTransparency = 0.4,
            AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 22),
            BorderSizePixel = 0, ZIndex = 61 }, lst)
        cnr(ob, 4)
        ob.MouseButton1Click:Connect(function()
            v = o; b.Text = tostring(o) .. "  ▾"; close()
            if cfg.cb then pcall(cfg.cb, o) end
        end)
    end
    b.MouseButton1Click:Connect(function()
        open = not open
        if open then
            lst.Visible = true
            tw(lst, { Size = UDim2.new(0, 130, 0, #cfg.options * 25 + 8) }, 0.17, Enum.EasingStyle.Quint)
        else close() end
    end)
    function api.Get() return v end
    function api.Set(x) v = x; b.Text = tostring(x) .. "  ▾" end
    return api
end

function UI:Keybind(pg, cfg)
    local r = row(pg, 32)
    mk("TextLabel", { Text = cfg.name, Font = T.f, TextSize = 11, TextColor3 = T.txt,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -110, 1, 0) }, r)
    local v, ls = cfg.default, false
    local b = mk("TextButton", { Text = v and v.Name or "—", Font = T.fb, TextSize = 10,
        TextColor3 = T.acc, BackgroundColor3 = T.panel, AutoButtonColor = false,
        Position = UDim2.new(1, -96, 0.5, -11), Size = UDim2.fromOffset(84, 22),
        BorderSizePixel = 0, ZIndex = 13 }, r)
    cnr(b, 5); stk(b, T.stroke, 1, 0.2)
    b.MouseButton1Click:Connect(function() ls = true; b.Text = "···"; b.TextColor3 = T.acc2 end)
    bind(UIS.InputBegan, function(i, g)
        if g or not ls then return end
        if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
        ls = false; v = i.KeyCode; b.Text = v.Name; b.TextColor3 = T.acc
        if cfg.cb then pcall(cfg.cb, v) end
    end)
    local api = {}
    function api.Get() return v end
    function api.Set(x) v = x; b.Text = x and x.Name or "—" end
    return api
end

function UI:Button(pg, cfg)
    local b = mk("TextButton", { Text = cfg.name, Font = T.fb, TextSize = 11, TextColor3 = T.acc,
        BackgroundColor3 = T.item, BackgroundTransparency = 0.25, AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, 30), BorderSizePixel = 0, ZIndex = 12 }, pg)
    cnr(b, 6); stk(b, T.acc, 1, 0.6)
    b.MouseEnter:Connect(function() tw(b, { BackgroundTransparency = 0, BackgroundColor3 = T.panel }, 0.13) end)
    b.MouseLeave:Connect(function() tw(b, { BackgroundTransparency = 0.25, BackgroundColor3 = T.item }, 0.13) end)
    b.MouseButton1Click:Connect(function() if cfg.cb then pcall(cfg.cb) end end)
end

--=============================================================
-- 5 · BUILD
--=============================================================
local Win = UI:Window()

local function notify(txt)
    if not Config.misc.notify then return end
    local t = mk("Frame", { Size = UDim2.fromOffset(200, 28), Position = UDim2.new(1, -210, 1, -58),
        BackgroundColor3 = T.panel, BorderSizePixel = 0, ZIndex = 90 }, Win.main)
    cnr(t, 6); stk(t, T.acc, 1, 0.5)
    mk("TextLabel", { Text = txt, Font = T.f, TextSize = 10, TextColor3 = T.txt,
        BackgroundTransparency = 1, Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(8, 0),
        TextXAlignment = Enum.TextXAlignment.Left }, t)
    task.delay(1.8, function()
        tw(t, { BackgroundTransparency = 1 }, 0.25)
        task.delay(0.3, function() t:Destroy() end)
    end)
end

local aP = UI:Tab(Win, "Aimbot", "◎")
UI:Section(aP, "Cámara")
UI:Toggle(aP, { name = "Aimbot", cb = function(v) Config.aimbot.enabled = v; Aimbot.Fov() end })
UI:Dropdown(aP, { name = "Activación", options = { "Hold", "Toggle", "Always" }, default = "Hold",
    cb = function(v) Config.aimbot.mode = v end })
UI:Keybind(aP, { name = "Tecla", default = Enum.KeyCode.Q, cb = function(k) Config.aimbot.key = k end })
UI:Dropdown(aP, { name = "Parte", options = { "Head", "HumanoidRootPart", "UpperTorso" }, default = "Head",
    cb = function(v) Config.aimbot.part = v end })
UI:Slider(aP, { name = "FOV", min = 20, max = 600, step = 5, default = 110,
    cb = function(v) Config.aimbot.fov = v; Aimbot.Fov() end })
UI:Slider(aP, { name = "Suavizado", min = 1, max = 100, step = 1, default = 20,
    cb = function(v) Config.aimbot.smooth = v end })
UI:Slider(aP, { name = "Predicción", min = 0, max = 100, step = 1, default = 0,
    cb = function(v) Config.aimbot.prediction = v end })
UI:Section(aP, "Filtros")
UI:Toggle(aP, { name = "Wallcheck", default = true, cb = function(v) Config.aimbot.wallcheck = v end })
UI:Toggle(aP, { name = "Ignorar aliados", default = true, cb = function(v) Config.aimbot.teamCheck = v end })
UI:Toggle(aP, { name = "Humanizer", default = true, cb = function(v) Config.aimbot.humanize = v end })
UI:Toggle(aP, { name = "Bloqueo de objetivo", default = true, cb = function(v) Config.aimbot.lock = v end })
UI:Toggle(aP, { name = "Círculo FOV", default = true,
    cb = function(v) Config.aimbot.showFov = v; Aimbot.Fov() end })

local sP = UI:Tab(Win, "Silent", "◇")
UI:Section(sP, "Silent Aim")
UI:Toggle(sP, { name = "Silent Aim",
    cb = function(v) Config.silent.enabled = v; SilentAim.Fov(); notify(v and "silent on" or "silent off") end })
UI:Dropdown(sP, { name = "Activación", options = { "Always", "Toggle", "Hold" }, default = "Toggle",
    cb = function(v) Config.silent.mode = v end })
UI:Keybind(sP, { name = "Tecla", default = Enum.KeyCode.E, cb = function(k) Config.silent.key = k end })
UI:Dropdown(sP, { name = "Parte", options = { "Head", "HumanoidRootPart", "UpperTorso" }, default = "Head",
    cb = function(v) Config.silent.part = v end })
UI:Slider(sP, { name = "FOV", min = 20, max = 700, step = 5, default = 160,
    cb = function(v) Config.silent.fov = v; SilentAim.Fov() end })
UI:Slider(sP, { name = "Predicción", min = 0, max = 100, step = 1, default = 8,
    cb = function(v) Config.silent.prediction = v end })
UI:Section(sP, "Extras")
UI:Toggle(sP, { name = "Magic Bullet",
    cb = function(v) Config.silent.magic = v; notify(v and "magic on" or "magic off") end })
UI:Toggle(sP, { name = "Wallcheck", cb = function(v) Config.silent.wallcheck = v end })
UI:Toggle(sP, { name = "Ignorar aliados", default = true, cb = function(v) Config.silent.teamCheck = v end })
UI:Toggle(sP, { name = "Círculo FOV", default = true,
    cb = function(v) Config.silent.showFov = v; SilentAim.Fov() end })

local vP = UI:Tab(Win, "Visuales", "▣")
UI:Section(vP, "ESP")
UI:Toggle(vP, { name = "ESP",
    cb = function(v) Config.esp.enabled = v; if v then ESP.Start() else ESP.Stop() end end })
UI:Toggle(vP, { name = "Caja", default = true, cb = function(v) Config.esp.box = v end })
UI:Toggle(vP, { name = "Relleno", cb = function(v) Config.esp.fill = v end })
UI:Toggle(vP, { name = "Nombre", default = true, cb = function(v) Config.esp.name = v end })
UI:Toggle(vP, { name = "Distancia", default = true, cb = function(v) Config.esp.distance = v end })
UI:Toggle(vP, { name = "Vida", default = true, cb = function(v) Config.esp.health = v end })
UI:Toggle(vP, { name = "Tracer", default = true, cb = function(v) Config.esp.tracer = v end })
UI:Toggle(vP, { name = "Skeleton", cb = function(v) Config.esp.skeleton = v end })
UI:Toggle(vP, { name = "Chams", default = true, cb = function(v) Config.esp.chams = v end })
UI:Section(vP, "Colores")
UI:Dropdown(vP, { name = "Enemigo", options = { "Cian", "Magenta", "Rojo", "Amarillo", "Blanco" },
    default = "Cian", cb = function(v)
        local m = { Cian = Color3.fromRGB(0, 240, 255), Magenta = Color3.fromRGB(255, 0, 160),
            Rojo = Color3.fromRGB(255, 70, 70), Amarillo = Color3.fromRGB(255, 220, 60),
            Blanco = Color3.fromRGB(255, 255, 255) }
        Config.esp.color = m[v]; ESP.Recolor()
    end })
UI:Dropdown(vP, { name = "Aliado", options = { "Verde", "Azul", "Gris" }, default = "Verde",
    cb = function(v)
        local m = { Verde = Color3.fromRGB(80, 255, 130), Azul = Color3.fromRGB(80, 160, 255),
            Gris = Color3.fromRGB(170, 170, 170) }
        Config.esp.teamColor = m[v]; ESP.Recolor()
    end })

local jP = UI:Tab(Win, "Jugador", "◈")
UI:Section(jP, "Movimiento")
UI:Slider(jP, { name = "WalkSpeed", min = 16, max = 200, step = 1, default = 16,
    cb = function(v) Config.player.walkSpeed = v; Player.Speed() end })
UI:Slider(jP, { name = "JumpPower", min = 50, max = 300, step = 1, default = 50,
    cb = function(v) Config.player.jumpPower = v; Player.Jump() end })
UI:Toggle(jP, { name = "Bloquear valores", default = true, cb = function(v) Config.player.lockSpeed = v end })
UI:Section(jP, "Estados")
UI:Toggle(jP, { name = "Fly", cb = function(v) Player.Fly(v) end })
UI:Slider(jP, { name = "Vel. vuelo", min = 20, max = 300, step = 5, default = 60,
    cb = function(v) Config.player.flySpeed = v end })
UI:Toggle(jP, { name = "Fly auto", cb = function(v) Config.player.flyAuto = v end })
UI:Toggle(jP, { name = "Noclip", cb = function(v) Config.player.noclip = v end })
UI:Toggle(jP, { name = "Salto infinito", cb = function(v) Config.player.infJump = v end })

local cP = UI:Tab(Win, "Combate", "✶")
UI:Section(cP, "Hitbox")
UI:Toggle(cP, { name = "Hitbox Expander",
    cb = function(v) Hitbox.Set(v); notify(v and "hitbox on" or "hitbox off") end })
UI:Slider(cP, { name = "Escala", min = 1, max = 8, step = 0.1, dec = true, default = 2.2,
    cb = function(v) Config.hitbox.scale = v; Hitbox.Refresh() end })
UI:Toggle(cP, { name = "Congelar hitbox", cb = function(v) Hitbox.Freeze(v) end })
UI:Section(cP, "Trigger")
UI:Toggle(cP, { name = "Trigger Bot",
    cb = function(v) Trigger.Set(v); notify(v and "trigger on" or "trigger off") end })
UI:Slider(cP, { name = "Retardo (ms)", min = 10, max = 400, step = 10, default = 60,
    cb = function(v) Config.trigger.delay = v / 1000 end })
UI:Slider(cP, { name = "FOV trigger", min = 5, max = 200, step = 5, default = 40,
    cb = function(v) Config.trigger.fov = v end })

local oP = UI:Tab(Win, "OP", "⚡")
UI:Section(oP, "Armas")
UI:Toggle(oP, { name = "No Recoil / Spread", cb = function(v) Config.op.noRecoil = v end })
UI:Toggle(oP, { name = "Munición infinita", cb = function(v) Config.op.ammo = v; OP.Ammo(v) end })
UI:Toggle(oP, { name = "Auto Reload", cb = function(v) Config.op.autoReload = v end })
UI:Toggle(oP, { name = "Auto Fire", cb = function(v) Config.op.autoFire = v end })
UI:Slider(oP, { name = "Rango auto fire", min = 10, max = 150, step = 5, default = 45,
    cb = function(v) Config.op.autoFireRange = v end })
UI:Section(oP, "Movimiento roto")
UI:Toggle(oP, { name = "Anti-Aim / Spinbot", cb = function(v) OP.AntiAim(v) end })
UI:Slider(oP, { name = "Grados spin", min = 100, max = 2000, step = 50, default = 600,
    cb = function(v) Config.op.spin = v end })
UI:Toggle(oP, { name = "Anti-Fling", cb = function(v) Config.op.antiFling = v end })
UI:Toggle(oP, { name = "Speed por CFrame", cb = function(v) Config.op.speedCFrame = v end })
UI:Slider(oP, { name = "Vel. CFrame", min = 20, max = 250, step = 5, default = 60,
    cb = function(v) Config.op.speedValue = v end })
UI:Section(oP, "Cámara")
UI:Toggle(oP, { name = "FOV Changer", cb = function(v) Config.op.fovEnabled = v; OP.Fov(v) end })
UI:Slider(oP, { name = "FOV cámara", min = 30, max = 120, step = 1, default = 70,
    cb = function(v) Config.op.fov = v; OP.Fov(Config.op.fovEnabled) end })
UI:Toggle(oP, { name = "Third Person", cb = function(v) OP.Third(v) end })

local mP = UI:Tab(Win, "Misc", "≡")
UI:Section(mP, "Interfaz")
UI:Keybind(mP, { name = "Mostrar / ocultar", default = Enum.KeyCode.RightShift,
    cb = function(k) Config.misc.guiKey = k end })
UI:Toggle(mP, { name = "Notificaciones", default = true, cb = function(v) Config.misc.notify = v end })
UI:Button(mP, { name = "Panic", cb = function() Win:Toggle(false) end })
UI:Section(mP, "Rendimiento")
UI:Toggle(mP, { name = "Optimizador FPS",
    cb = function(v) Config.misc.optimizer = v; Optimizer.Apply(v) end })
UI:Dropdown(mP, { name = "Límite FPS", options = { "30", "60", "90", "120", "240" }, default = "60",
    cb = function(v) pcall(setfpscap, tonumber(v)) end })
UI:Section(mP, "Sesión")
UI:Button(mP, { name = "Unload", cb = function() unload() end })

local fab = mk("TextButton", { Text = "V", Font = T.fb, TextSize = 16, TextColor3 = T.bg,
    BackgroundColor3 = T.acc, Size = UDim2.fromOffset(42, 42), Position = UDim2.new(0, 18, 0.5, -21),
    AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 20 }, Win.screen)
cnr(fab, 21); drag(fab, fab)
fab.MouseButton1Click:Connect(function() Win:Toggle() end)

--=============================================================
-- 6 · AIMBOT
--=============================================================
Aimbot = {}
local aimHeld, locked, aimFov
if Drawing then
    pcall(function()
        aimFov = Drawing.new("Circle")
        aimFov.Thickness = 1; aimFov.Filled = false; aimFov.NumSides = 64
        aimFov.Transparency = 0.35; aimFov.Color = T.acc; aimFov.Visible = false
    end)
end

function Aimbot.Fov()
    if not aimFov then return end
    pcall(function()
        aimFov.Position = Camera.ViewportSize / 2
        aimFov.Radius = Config.aimbot.fov
        aimFov.Visible = Config.aimbot.enabled and Config.aimbot.showFov
    end)
end

local function aimOn()
    if not Config.aimbot.enabled then return false end
    if Config.aimbot.mode == "Always" then return true end
    if Config.aimbot.mode == "Toggle" then return aimHeld end
    return UIS:IsKeyDown(Config.aimbot.key)
end

bind(UIS.InputBegan, function(i, g)
    if g or i.KeyCode ~= Config.aimbot.key then return end
    if Config.aimbot.mode == "Toggle" then aimHeld = not aimHeld else aimHeld = true end
end)
bind(UIS.InputEnded, function(i)
    if i.KeyCode == Config.aimbot.key and Config.aimbot.mode ~= "Toggle" then aimHeld = false end
end)

local AIM_BIND = "VeniceAimbot"
RunService:BindToRenderStep(AIM_BIND, Enum.RenderPriority.Camera.Value + 10, function(dt)
    if aimFov and Config.aimbot.enabled and Config.aimbot.showFov then
        pcall(function() aimFov.Position = Camera.ViewportSize / 2 end)
    end
    if not aimOn() then locked = nil; return end

    local tgt
    if Config.aimbot.lock and locked and locked.part and locked.part.Parent then
        local sp, on = Camera:WorldToViewportPoint(locked.part.Position)
        if on and (Vector2.new(sp.X, sp.Y) - Camera.ViewportSize / 2).Magnitude <= Config.aimbot.fov then
            tgt = locked
        end
    end
    if not tgt then tgt = resolve(Config.aimbot); locked = tgt end
    if not tgt then return end

    local pos = tgt.pos
    if Config.aimbot.humanize then
        pos = pos + Vector3.new((math.random() - .5) * .22, (math.random() - .5) * .22, (math.random() - .5) * .22)
    end
    local goal = CFrame.lookAt(Camera.CFrame.Position, pos)
    local s = math.clamp(Config.aimbot.smooth, 1, 100)
    camBypass = true
    Camera.CFrame = Camera.CFrame:Lerp(goal, math.clamp(1 - math.exp(-(110 / s) * dt), 0.03, 1))
    camBypass = false
end)

--=============================================================
-- 7 · SILENT
--=============================================================
SilentAim = {}
local silentFov
if Drawing then
    pcall(function()
        silentFov = Drawing.new("Circle")
        silentFov.Thickness = 1; silentFov.Filled = false; silentFov.NumSides = 64
        silentFov.Transparency = 0.3; silentFov.Color = T.acc2; silentFov.Visible = false
    end)
end

function SilentAim.Fov()
    if not silentFov then return end
    pcall(function()
        silentFov.Position = Camera.ViewportSize / 2
        silentFov.Radius = Config.silent.fov
        silentFov.Visible = Config.silent.enabled and Config.silent.showFov
    end)
end

bind(UIS.InputBegan, function(i, g)
    if g then return end
    if i.KeyCode == Config.silent.key then
        if Config.silent.mode == "Toggle" then
            Config.silent.toggled = not Config.silent.toggled
        else
            Config.silent.toggled = true
        end
    end
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then
        Config.silent.armedUntil = tick() + Config.silent.armed
        if OP then OP.noRecoilUntil = tick() + 0.09 end
    end
end)
bind(UIS.InputEnded, function(i)
    if i.KeyCode == Config.silent.key and Config.silent.mode ~= "Toggle" then
        Config.silent.toggled = false
    end
end)
bind(RunService.RenderStepped, function()
    if silentFov and Config.silent.enabled and Config.silent.showFov then
        pcall(function() silentFov.Position = Camera.ViewportSize / 2 end)
    end
end)

--=============================================================
-- 8 · ESP
--=============================================================
ESP = { cache = {}, acc = 0 }
local BONES = {
    { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" }, { "LowerTorso", "LeftUpperLeg" },
    { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" }, { "LowerTorso", "RightUpperLeg" },
    { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" }, { "UpperTorso", "LeftUpperArm" },
    { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" }, { "UpperTorso", "RightUpperArm" },
    { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
}
local function ds(o, p)
    if not o then return end
    for k, v in next, p do pcall(function() o[k] = v end) end
end

function ESP.Create(plr)
    if ESP.cache[plr] or not Drawing then return end
    local d = { draw = {}, bones = {} }
    local map = { outline = "Square", box = "Square", fill = "Square",
        name = "Text", dist = "Text", hpBg = "Square", hp = "Square", tracer = "Line" }
    for k, kind in next, map do
        local ok, o = pcall(Drawing.new, kind)
        if ok then d[k] = o; d.draw[#d.draw + 1] = o end
    end
    ds(d.name, { Size = 13, Center = true, Outline = true, OutlineColor = Color3.new() })
    ds(d.dist, { Size = 11, Center = true, Outline = true, OutlineColor = Color3.new() })
    ds(d.outline, { Thickness = 1, Filled = false })
    ds(d.box, { Thickness = 1, Filled = false })
    ds(d.fill, { Filled = true, Transparency = 0.82 })
    for _ = 1, #BONES do
        local ok, l = pcall(Drawing.new, "Line")
        if ok then
            d.bones[#d.bones + 1] = l
            d.draw[#d.draw + 1] = l
            ds(l, { Thickness = 1, Transparency = 0.25 })
        end
    end
    ESP.cache[plr] = d
end

function ESP.Remove(plr)
    local d = ESP.cache[plr]
    if not d then return end
    for _, o in ipairs(d.draw) do pcall(function() o:Remove() end) end
    if d.hl then pcall(function() d.hl:Destroy() end) end
    ESP.cache[plr] = nil
end

function ESP.Start()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then ESP.Create(p) end
    end
end
function ESP.Stop()
    for p in next, ESP.cache do ESP.Remove(p) end
end

function ESP.Recolor()
    for plr, d in next, ESP.cache do
        local team = plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team
        local c = team and Config.esp.teamColor or Config.esp.color
        for _, o in ipairs(d.draw) do ds(o, { Color = c }) end
        if d.hl then pcall(function() d.hl.FillColor = c; d.hl.OutlineColor = c end) end
    end
end

local function hideAll(d)
    for _, o in ipairs(d.draw) do ds(o, { Visible = false }) end
end

local function hlFor(plr, char, col)
    local d = ESP.cache[plr]
    if not d then return end
    if d.hl and d.hl.Parent == char then
        pcall(function() d.hl.FillColor = col; d.hl.OutlineColor = col end)
        return
    end
    if d.hl then pcall(function() d.hl:Destroy() end); d.hl = nil end
    local h = Instance.new("Highlight")
    h.FillColor = col; h.OutlineColor = col
    h.FillTransparency = 0.68; h.OutlineTransparency = 0.1
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Adornee = char; h.Parent = char
    d.hl = h
end

local function renderESP()
    for plr, d in next, ESP.cache do
        local char = plr.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not (char and hum and hrp and hum.Health > 0) then
            hideAll(d)
            if d.hl then pcall(function() d.hl:Destroy() end); d.hl = nil end
            continue
        end
        local team = plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team
        local col = team and Config.esp.teamColor or Config.esp.color
        if Config.esp.chams then pcall(hlFor, plr, char, col)
        elseif d.hl then pcall(function() d.hl:Destroy() end); d.hl = nil end

        local ok = pcall(function()
            local sz = char:GetExtentsSize()
            local cf = hrp.CFrame
            local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
            for a = -1, 1, 2 do for b = -1, 1, 2 do for c = -1, 1, 2 do
                local w = cf * Vector3.new(sz.X * .5 * a, sz.Y * .5 * b, sz.Z * .5 * c)
                local sp = Camera:WorldToViewportPoint(w)
                x1 = math.min(x1, sp.X); x2 = math.max(x2, sp.X)
                y1 = math.min(y1, sp.Y); y2 = math.max(y2, sp.Y)
            end end end
            local w, h = x2 - x1, y2 - y1
            if w <= 0 or h <= 0 or w > 1500 then hideAll(d); return end

            ds(d.outline, { Visible = Config.esp.box, Position = Vector2.new(x1 - 1, y1 - 1),
                Size = Vector2.new(w + 2, h + 2), Color = Color3.new() })
            ds(d.box, { Visible = Config.esp.box, Position = Vector2.new(x1, y1),
                Size = Vector2.new(w, h), Color = col })
            ds(d.fill, { Visible = Config.esp.fill, Position = Vector2.new(x1, y1),
                Size = Vector2.new(w, h), Color = col })
            ds(d.name, { Visible = Config.esp.name, Position = Vector2.new(x1 + w / 2, y1 - 16),
                Text = plr.Name, Color = col })
            ds(d.dist, { Visible = Config.esp.distance, Position = Vector2.new(x1 + w / 2, y2 + 2),
                Text = math.floor((hrp.Position - Camera.CFrame.Position).Magnitude) .. "m", Color = col })

            local fr = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            ds(d.hpBg, { Visible = Config.esp.health, Position = Vector2.new(x1 - 6, y1),
                Size = Vector2.new(3, h), Color = Color3.new(), Transparency = 0.4 })
            ds(d.hp, { Visible = Config.esp.health, Position = Vector2.new(x1 - 6, y2 - h * fr),
                Size = Vector2.new(3, h * fr),
                Color = Color3.fromRGB(60 + 195 * (1 - fr), 60 + 195 * fr, 60) })

            if Config.esp.tracer then
                ds(d.tracer, { Visible = true,
                    From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y),
                    To = Vector2.new(x1 + w / 2, y2), Color = col })
            else
                ds(d.tracer, { Visible = false })
            end

            if Config.esp.skeleton then
                for i, pr in ipairs(BONES) do
                    local A = char:FindFirstChild(pr[1])
                    local B = char:FindFirstChild(pr[2])
                    local ln = d.bones[i]
                    if A and B and ln then
                        local pa = Camera:WorldToViewportPoint(A.Position)
                        local pb = Camera:WorldToViewportPoint(B.Position)
                        ds(ln, { Visible = true, From = Vector2.new(pa.X, pa.Y),
                            To = Vector2.new(pb.X, pb.Y), Color = col })
                    elseif ln then
                        ds(ln, { Visible = false })
                    end
                end
            else
                for _, l in ipairs(d.bones) do ds(l, { Visible = false }) end
            end
        end)
        if not ok then hideAll(d) end
    end
end

bind(RunService.RenderStepped, function(dt)
    if not Config.esp.enabled then return end
    ESP.acc = ESP.acc + dt
    if ESP.acc < 1 / 30 then return end
    ESP.acc = 0
    renderESP()
end)
bind(Players.PlayerAdded, function(p)
    if p ~= LocalPlayer and Config.esp.enabled then ESP.Create(p) end
end)
bind(Players.PlayerRemoving, function(p) ESP.Remove(p) end)

--=============================================================
-- 9 · HITBOX
--=============================================================
Hitbox = { saved = {} }

function Hitbox.Apply(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp or Hitbox.saved[char] then return end
    local head = char:FindFirstChild("Head")
    Hitbox.saved[char] = { hrp = hrp.Size, head = head and head.Size }
    local s = Config.hitbox.scale
    hrp.Size = Vector3.new(3, 3, 3) * s
    hrp.Transparency = 0.75
    hrp.Massless = true
    if head then head.Size = Vector3.new(2, 1, 1) * s end
end

function Hitbox.Restore(char)
    local o = Hitbox.saved[char]
    if not o then return end
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local head = char and char:FindFirstChild("Head")
    if hrp then hrp.Size = o.hrp; hrp.Transparency = 1; hrp.Massless = false end
    if head and o.head then head.Size = o.head end
    Hitbox.saved[char] = nil
end

function Hitbox.Refresh()
    if not Config.hitbox.enabled then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then Hitbox.Apply(p.Character) end
    end
end

function Hitbox.Set(v)
    Config.hitbox.enabled = v
    if v then Hitbox.Refresh() else for c in next, Hitbox.saved do Hitbox.Restore(c) end end
end

function Hitbox.Freeze(v)
    Config.hitbox.freeze = v
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then pcall(function() hrp.Anchored = v end) end
        end
    end
end

--=============================================================
-- 10 · TRIGGER
--=============================================================
Trigger = { bound = false }
function Trigger.Set(v)
    Config.trigger.enabled = v
    if not v or Trigger.bound then return end
    Trigger.bound = true
    bind(RunService.RenderStepped, function()
        if not Config.trigger.enabled then return end
        local c = Camera.ViewportSize / 2
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local ch = p.Character
                local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                local pt = ch and ch:FindFirstChild(Config.trigger.part)
                if hum and hum.Health > 0 and pt then
                    local sp, on = Camera:WorldToViewportPoint(pt.Position)
                    if on and (Vector2.new(sp.X, sp.Y) - c).Magnitude <= Config.trigger.fov then
                        local tool = LocalPlayer.Character
                            and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                        if tool then pcall(function() tool:Activate() end) end
                        task.wait(Config.trigger.delay)
                        break
                    end
                end
            end
        end
    end)
end

--=============================================================
-- 11 · OP
--=============================================================
OP = { ammoBound = false, fovBound = false }
local spinBV, lastPos, fovBack

function OP.Ammo(v)
    if not v or OP.ammoBound then return end
    OP.ammoBound = true
    bind(RunService.Heartbeat, function()
        if not Config.op.ammo then return end
        local ch = LocalPlayer.Character
        local tool = ch and ch:FindFirstChildOfClass("Tool")
        if not tool then return end
        for _, d in ipairs(tool:GetDescendants()) do
            if d:IsA("IntValue") or d:IsA("NumberValue") then
                local n = d.Name:lower()
                if n:find("ammo") or n:find("mag") then
                    pcall(function() d.Value = 999 end)
                end
            end
        end
    end)
end

function OP.AntiAim(v)
    local _, _, hrp = Player.Parts()
    if v then
        if not hrp then return end
        spinBV = Instance.new("BodyAngularVelocity")
        spinBV.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        spinBV.AngularVelocity = Vector3.new(0, math.rad(Config.op.spin), 0)
        spinBV.Parent = hrp
    elseif spinBV then
        pcall(function() spinBV:Destroy() end)
        spinBV = nil
    end
end

function OP.Fov(v)
    if v and not OP.fovBound then
        OP.fovBound = true
        fovBack = Camera.FieldOfView
        bind(RunService.RenderStepped, function()
            if Config.op.fovEnabled then Camera.FieldOfView = Config.op.fov end
        end)
    elseif not v and fovBack then
        pcall(function() Camera.FieldOfView = fovBack end)
    end
end

function OP.Third(v)
    pcall(function()
        if v then
            LocalPlayer.CameraMaxZoomDistance = 20
            LocalPlayer.CameraMinZoomDistance = 20
        else
            LocalPlayer.CameraMaxZoomDistance = 128
            LocalPlayer.CameraMinZoomDistance = 0.5
        end
    end)
end

bind(RunService.Heartbeat, function(dt)
    if Config.op.antiFling then
        local _, _, hrp = Player.Parts()
        if hrp then
            if lastPos and (hrp.Position - lastPos).Magnitude > 60 then
                pcall(function()
                    hrp.CFrame = CFrame.new(lastPos)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end)
            else
                lastPos = hrp.Position
            end
        end
    end

    if Config.op.speedCFrame then
        local _, _, hrp = Player.Parts()
        if hrp then
            local d = Vector3.zero
            local cf = Camera.CFrame
            if UIS:IsKeyDown(Enum.KeyCode.W) then d += cf.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then d -= cf.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then d -= cf.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then d += cf.RightVector end
            if d.Magnitude > 0 then
                d = d.Unit
                hrp.CFrame = hrp.CFrame + d * Config.op.speedValue * dt
            end
        end
    end

    local ch = LocalPlayer.Character
    local tool = ch and ch:FindFirstChildOfClass("Tool")
    if tool and (Config.op.autoFire or Config.op.autoReload) then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local e = p.Character
                local hum = e and e:FindFirstChildOfClass("Humanoid")
                local hrp = e and e:FindFirstChild("HumanoidRootPart")
                if hum and hum.Health > 0 and hrp then
                    if Config.op.autoFire
                    and (hrp.Position - Camera.CFrame.Position).Magnitude <= Config.op.autoFireRange then
                        pcall(function() tool:Activate() end)
                    elseif Config.op.autoReload then
                        pcall(function() tool:Activate() end)
                    end
                    break
                end
            end
        end
    end
end)

--=============================================================
-- 12 · JUGADOR
--=============================================================
Player = {}
local flyBV, flyBG, flyConn, noclipping

function Player.Parts()
    local c = LocalPlayer.Character
    if not c then return nil end
    return c, c:FindFirstChildOfClass("Humanoid"), c:FindFirstChild("HumanoidRootPart")
end

function Player.Speed()
    local _, hum = Player.Parts()
    if not hum then return end
    pcall(function()
        hum.WalkSpeed = Config.player.walkSpeed
        if Config.player.lockSpeed then Spoof(hum, "WalkSpeed", Config.player.walkSpeed) end
    end)
end

function Player.Jump()
    local _, hum = Player.Parts()
    if not hum then return end
    pcall(function()
        hum.UseJumpPower = true
        hum.JumpPower = Config.player.jumpPower
        if Config.player.lockSpeed then Spoof(hum, "JumpPower", Config.player.jumpPower) end
    end)
end

function Player.Fly(v)
    Config.player.fly = v
    local _, hum, hrp = Player.Parts()
    if v then
        if not hrp then return end
        flyBV = Instance.new("BodyVelocity")
        flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        flyBV.Velocity = Vector3.zero
        flyBV.Parent = hrp
        flyBG = Instance.new("BodyGyro")
        flyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        flyBG.P = 1200; flyBG.D = 60
        flyBG.CFrame = hrp.CFrame
        flyBG.Parent = hrp
        if hum then hum.PlatformStand = true end
        flyConn = bind(RunService.RenderStepped, function()
            local _, _, p = Player.Parts()
            if not (p and flyBV and flyBG) then return end
            local d = Vector3.zero
            local cf = Camera.CFrame
            if UIS:IsKeyDown(Enum.KeyCode.W) then d += cf.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then d -= cf.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then d -= cf.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then d += cf.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then d += Vector3.yAxis end
            if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then d -= Vector3.yAxis end
            if d.Magnitude < 0.01 and Config.player.flyAuto then d = cf.LookVector end
            if d.Magnitude > 0 then d = d.Unit end
            flyBV.Velocity = d * Config.player.flySpeed
            flyBG.CFrame = cf
        end)
    else
        if flyConn then pcall(function() flyConn:Disconnect() end); flyConn = nil end
        if flyBV then pcall(function() flyBV:Destroy() end); flyBV = nil end
        if flyBG then pcall(function() flyBG:Destroy() end); flyBG = nil end
        local _, h = Player.Parts()
        if h then pcall(function() h.PlatformStand = false end) end
    end
end

bind(RunService.Heartbeat, function()
    if not Config.player.noclip then
        if noclipping then
            noclipping = false
            local c = LocalPlayer.Character
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then pcall(function() p.CanCollide = true end) end
                end
            end
        end
        return
    end
    noclipping = true
    local c = LocalPlayer.Character
    if not c then return end
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") then pcall(function() p.CanCollide = false end) end
    end
end)

bind(UIS.JumpRequest, function()
    if not Config.player.infJump then return end
    local _, hum = Player.Parts()
    if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end) end
end)

bind(LocalPlayer.CharacterAdded, function(char)
    task.wait(0.7)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    Player.Speed(); Player.Jump()
    if Config.player.lockSpeed then
        LockProperty(hum, "WalkSpeed", Config.player.walkSpeed)
        LockProperty(hum, "JumpPower", Config.player.jumpPower)
    end
    if Config.hitbox.enabled then Hitbox.Apply(char) end
end)

--=============================================================
-- 13 · OPTIMIZADOR
--=============================================================
Optimizer = {}
local bk = {}
function Optimizer.Apply(v)
    if v then
        pcall(function()
            bk.sh = Lighting.GlobalShadows
            bk.fog = Lighting.FogEnd
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 1e6
        end)
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        pcall(function()
            local n = 0
            for _, o in ipairs(Workspace:GetDescendants()) do
                if n > 4000 then break end
                n += 1
                if o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Smoke") or o:IsA("Fire") then
                    o.Enabled = false
                elseif o:IsA("Decal") or o:IsA("Texture") then
                    o.Transparency = 1
                end
            end
        end)
        pcall(function() Workspace.Terrain.Decoration = false end)
        notify("optimizador on")
    else
        pcall(function()
            Lighting.GlobalShadows = bk.sh ~= false
            Lighting.FogEnd = bk.fog or 100000
        end)
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level07 end)
        pcall(function() Workspace.Terrain.Decoration = true end)
        notify("optimizador off")
    end
end

--=============================================================
-- 14 · GUI KEY + UNLOAD
--=============================================================
bind(UIS.InputBegan, function(i, g)
    if g then return end
    if i.KeyCode == Config.misc.guiKey then Win:Toggle() end
end)

function unload()
    pcall(function() RunService:UnbindFromRenderStep(AIM_BIND) end)
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    Connections = {}
    pcall(function() if aimFov then aimFov:Remove() end end)
    pcall(function() if silentFov then silentFov:Remove() end end)
    pcall(ESP.Stop)
    pcall(function() Hitbox.Set(false) end)
    pcall(function() Hitbox.Freeze(false) end)
    pcall(function() if spinBV then spinBV:Destroy() end end)
    pcall(function() OP.Fov(false) end)
    pcall(function() OP.Third(false) end)
    pcall(function() if Config.player.fly then Player.Fly(false) end end)

    local c, hum = Player.Parts()
    if hum then
        pcall(function()
            hum.WalkSpeed = 16
            hum.JumpPower = 50
            hum.PlatformStand = false
        end)
    end
    if c then
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then pcall(function() p.CanCollide = true end) end
        end
    end

    pcall(function() Win.screen:Destroy() end)
    gv.VeniceLoaded = false
    gv.VeniceUnload = nil
end
gv.VeniceUnload = unload

--=============================================================
-- 15 · INIT
--=============================================================
Aimbot.Fov(); SilentAim.Fov()
Win:Set("v3.1 cargado · RightShift oculta")
notify("venice listo")
