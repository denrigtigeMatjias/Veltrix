--[[
    Veltrix UI Library
    Matches the Veltrix website aesthetic — dark purple/blue theme.

    Usage:
        local UI  = loadstring(game:HttpGet(RAW .. "/lib/ui.lua"))()
        local win = UI:Window({ Title = "Veltrix", Key = getgenv().script_key })
        local tab = win:Tab("Combat")
        local seg = tab:Segment("Aimbot")
        seg:Toggle("Enable", { Default = false, Bindable = true }, function(v) end)
        win:SettingsTab()
        win:ConfigTab()
]]

local UI = {}
UI.__index = UI

-- ── services ──────────────────────────────────────────────────────────────────
local Tween  = game:GetService("TweenService")
local UIS    = game:GetService("UserInputService")
local Run    = game:GetService("RunService")
local Http   = game:GetService("HttpService")
local Plr    = game:GetService("Players")
local lp     = Plr.LocalPlayer
local pGui   = lp:WaitForChild("PlayerGui")

-- ── palette ───────────────────────────────────────────────────────────────────
local C = {
    bg      = Color3.fromRGB(11,  13,  18),
    card    = Color3.fromRGB(19,  21,  28),
    card2   = Color3.fromRGB(24,  27,  36),
    border  = Color3.fromRGB(30,  33,  48),
    border2 = Color3.fromRGB(40,  45,  65),
    text    = Color3.fromRGB(232, 234, 240),
    muted   = Color3.fromRGB(107, 114, 128),
    ok      = Color3.fromRGB(34,  211, 165),
    accent  = Color3.fromRGB(124, 92,  252),
    blue    = Color3.fromRGB(91,  141, 238),
    red     = Color3.fromRGB(248, 113, 113),
    yellow  = Color3.fromRGB(251, 191, 36),
    white   = Color3.fromRGB(255, 255, 255),
    black   = Color3.fromRGB(0,   0,   0),
}

-- ── layout constants ──────────────────────────────────────────────────────────
local WIN_W    = 800
local WIN_H    = 510
local TAB_W    = 158
local HDR_H    = 60
local SRCH_H   = 38
local FOOT_H   = 32
local CONTENT_Y = HDR_H + SRCH_H + 1

-- ── tiny helpers ──────────────────────────────────────────────────────────────
local function tw(obj, props, t, style, dir)
    Tween:Create(obj, TweenInfo.new(t or .15, style or Enum.EasingStyle.Quad,
        dir or Enum.EasingDirection.Out), props):Play()
end

local function inst(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function corner(p, r)
    return inst("UICorner", { CornerRadius = UDim.new(0, r or 8) }, p)
end

local function stroke(p, col, thick)
    return inst("UIStroke", { Color = col or C.border, Thickness = thick or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
end

local function pad(p, t, r, b, l)
    return inst("UIPadding", {
        PaddingTop    = UDim.new(0, t or 0), PaddingRight  = UDim.new(0, r or 0),
        PaddingBottom = UDim.new(0, b or 0), PaddingLeft   = UDim.new(0, l or 0),
    }, p)
end

local function list(p, dir, gap, align)
    local o = inst("UIListLayout", {
        FillDirection      = dir   or Enum.FillDirection.Vertical,
        SortOrder          = Enum.SortOrder.LayoutOrder,
        Padding            = UDim.new(0, gap or 0),
        HorizontalAlignment= align or Enum.HorizontalAlignment.Left,
    }, p)
    return o
end

local function gradient(p, c0, c1, rot)
    inst("UIGradient", {
        Color    = ColorSequence.new(c0, c1),
        Rotation = rot or 90,
    }, p)
end

-- ── dragging ──────────────────────────────────────────────────────────────────
local function draggable(frame, handle, getClamp)
    local drag, sp, sf = false, nil, nil
    handle.InputBegan:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        drag = true; sp = i.Position; sf = frame.Position
    end)
    handle.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
    end)
    UIS.InputChanged:Connect(function(i)
        if not drag or i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local d = i.Position - sp
        local x = sf.X.Offset + d.X
        local y = sf.Y.Offset + d.Y
        if getClamp then x, y = getClamp(x, y, frame) end
        frame.Position = UDim2.new(sf.X.Scale, x, sf.Y.Scale, y)
    end)
end

-- ── icon text button ──────────────────────────────────────────────────────────
local function iconBtn(txt, parent, color, w)
    w = w or 30
    local b = inst("TextButton", {
        Size             = UDim2.new(0, w, 0, 30),
        BackgroundColor3 = C.card2,
        Text             = txt,
        TextColor3       = color or C.muted,
        Font             = Enum.Font.GothamBold,
        TextSize         = 13,
        BorderSizePixel  = 0,
        AutoButtonColor  = false,
        ZIndex           = 6,
    }, parent)
    corner(b, 7)
    stroke(b, C.border, 1)
    b.MouseEnter:Connect(function() tw(b, { BackgroundColor3 = C.border  }, .1) end)
    b.MouseLeave:Connect(function() tw(b, { BackgroundColor3 = C.card2   }, .1) end)
    return b
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- WINDOW
-- ═══════════════════════════════════════════════════════════════════════════════
local Tab     = {}; Tab.__index     = Tab
local Segment = {}; Segment.__index = Segment

function UI:Window(opts)
    opts = opts or {}

    local self = setmetatable({
        _tabs      = {},
        _elements  = {},
        _visible   = true,
        _enlarged  = false,
        _clamp     = opts.ClampScreen ~= false,
        _uiKey     = opts.ToggleKey  or Enum.KeyCode.RightShift,
        _panicKey  = opts.PanicKey   or Enum.KeyCode.End,
        _startTime = tick(),
        _key       = opts.Key or "",
        _conns     = {},
    }, { __index = UI })

    -- destroy any previous instance
    local old = pGui:FindFirstChild("VeltrixUI")
    if old then old:Destroy() end

    -- root
    local gui = inst("ScreenGui", {
        Name = "VeltrixUI", ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1000,
    }, pGui)
    self._gui = gui

    -- dim backdrop
    local bg = inst("Frame", {
        Size = UDim2.new(1,0,1,0), BackgroundColor3 = C.black,
        BackgroundTransparency = .55, BorderSizePixel = 0, ZIndex = 1,
    }, gui)
    self._bg = bg

    -- main frame
    local frame = inst("Frame", {
        Size = UDim2.new(0, WIN_W, 0, WIN_H),
        Position = UDim2.new(.5, -WIN_W/2, .5, -WIN_H/2),
        BackgroundColor3 = C.bg, BorderSizePixel = 0, ZIndex = 2,
    }, gui)
    corner(frame, 14)
    stroke(frame, C.border, 1)
    self._frame = frame

    -- top accent gradient bar
    local accentBar = inst("Frame", {
        Size = UDim2.new(1,0,0,3), BackgroundColor3 = C.accent,
        BorderSizePixel = 0, ZIndex = 3,
    }, frame)
    corner(accentBar, 14)
    gradient(accentBar, C.accent, C.blue, 0)

    -- ── HEADER ────────────────────────────────────────────────────────────────
    local hdr = inst("Frame", {
        Size = UDim2.new(1,0,0,HDR_H), BackgroundTransparency = 1, ZIndex = 3,
    }, frame)

    -- avatar
    local avFrame = inst("Frame", {
        Size = UDim2.new(0,38,0,38), Position = UDim2.new(0,14,0.5,-19),
        BackgroundColor3 = C.border, BorderSizePixel = 0, ZIndex = 4,
    }, hdr)
    corner(avFrame, 99)
    stroke(avFrame, C.border2, 1)
    local avImg = inst("ImageLabel", {
        Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, ZIndex = 5,
    }, avFrame)
    corner(avImg, 99)
    task.spawn(function()
        local ok, id = pcall(Plr.GetUserIdFromNameAsync, Plr, lp.Name)
        if not ok then return end
        local ok2, img = pcall(Plr.GetUserThumbnailAsync, Plr, id,
            Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
        if ok2 then avImg.Image = img end
    end)

    -- names column
    local nameCol = inst("Frame", {
        Size = UDim2.new(0,160,0,38), Position = UDim2.new(0,60,0.5,-19),
        BackgroundTransparency = 1, ZIndex = 4,
    }, hdr)
    list(nameCol, Enum.FillDirection.Vertical, 2)
    inst("TextLabel", {
        Size = UDim2.new(1,0,0,18), BackgroundTransparency = 1,
        Text = lp.DisplayName, TextColor3 = C.text,
        Font = Enum.Font.GothamBold, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
    }, nameCol)
    inst("TextLabel", {
        Size = UDim2.new(1,0,0,16), BackgroundTransparency = 1,
        Text = "@"..lp.Name, TextColor3 = C.muted,
        Font = Enum.Font.Gotham, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
    }, nameCol)

    -- key TTL  +  uptime  (right of names)
    local infoCol = inst("Frame", {
        Size = UDim2.new(0,200,0,38), Position = UDim2.new(0,228,0.5,-19),
        BackgroundTransparency = 1, ZIndex = 4,
    }, hdr)
    list(infoCol, Enum.FillDirection.Vertical, 2)
    local keyLbl = inst("TextLabel", {
        Size = UDim2.new(1,0,0,18), BackgroundTransparency = 1,
        Text = "Key: checking…", TextColor3 = C.muted,
        Font = Enum.Font.Code, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
    }, infoCol)
    local uptimeLbl = inst("TextLabel", {
        Size = UDim2.new(1,0,0,16), BackgroundTransparency = 1,
        Text = "Uptime: 0:00:00", TextColor3 = C.muted,
        Font = Enum.Font.Code, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
    }, infoCol)

    -- key TTL fetch
    if self._key ~= "" then
        task.spawn(function()
            local ok, raw = pcall(function()
                return Http:GetAsync("https://veltrix-worker.matjias.workers.dev/validate?key="
                    ..Http:UrlEncode(self._key))
            end)
            if ok then
                local ok2, data = pcall(Http.JSONDecode, Http, raw)
                if ok2 and data and data.valid then
                    local h = math.floor(data.ttl / 3600)
                    local m = math.floor(data.ttl % 3600 / 60)
                    keyLbl.Text      = ("Key: %dh %dm remaining"):format(h, m)
                    keyLbl.TextColor3 = C.ok
                else
                    keyLbl.Text       = "Key: expired"
                    keyLbl.TextColor3 = C.red
                end
            else
                keyLbl.Text = "Key: offline"
            end
        end)
    else
        keyLbl.Text = "Key: none"
    end

    -- header right buttons
    local btnRow = inst("Frame", {
        Size = UDim2.new(0,100,0,30), Position = UDim2.new(1,-110,.5,-15),
        BackgroundTransparency = 1, ZIndex = 4,
    }, hdr)
    list(btnRow, Enum.FillDirection.Horizontal, 6)
    local enlargeBtn = iconBtn("⛶", btnRow, C.muted, 30)
    local closeBtn   = iconBtn("✕", btnRow, C.red,   30)

    -- header divider
    inst("Frame", {
        Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,0,HDR_H),
        BackgroundColor3 = C.border, BorderSizePixel = 0, ZIndex = 3,
    }, frame)

    -- ── SEARCH BAR ────────────────────────────────────────────────────────────
    local srchBar = inst("Frame", {
        Size = UDim2.new(1,-(TAB_W+1),0,SRCH_H),
        Position = UDim2.new(0,TAB_W+1,0,HDR_H+1),
        BackgroundColor3 = C.card, BorderSizePixel = 0, ZIndex = 3,
    }, frame)
    pad(srchBar, 0,12,0,36)

    inst("TextLabel", {
        Size = UDim2.new(0,20,1,0), Position = UDim2.new(0,10,0,0),
        BackgroundTransparency = 1, Text = "🔍",
        TextColor3 = C.muted, Font = Enum.Font.Gotham, TextSize = 13, ZIndex = 5,
    }, srchBar)

    local srchBox = inst("TextBox", {
        Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1,
        PlaceholderText = "Search elements…", PlaceholderColor3 = C.muted,
        Text = "", TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ZIndex = 4,
    }, srchBar)

    inst("Frame", {
        Size = UDim2.new(1,-(TAB_W+1),0,1),
        Position = UDim2.new(0,TAB_W+1,0,HDR_H+SRCH_H+1),
        BackgroundColor3 = C.border, BorderSizePixel = 0, ZIndex = 3,
    }, frame)

    -- ── LEFT TAB BAR ──────────────────────────────────────────────────────────
    local tabBar = inst("Frame", {
        Size = UDim2.new(0,TAB_W,1,-(HDR_H+2)),
        Position = UDim2.new(0,0,0,HDR_H+2),
        BackgroundColor3 = C.card, BorderSizePixel = 0, ZIndex = 3,
    }, frame)
    pad(tabBar, 8,6,8,6)
    list(tabBar, Enum.FillDirection.Vertical, 3)

    -- vertical divider
    inst("Frame", {
        Size = UDim2.new(0,1,1,-(HDR_H+2)),
        Position = UDim2.new(0,TAB_W,0,HDR_H+2),
        BackgroundColor3 = C.border, BorderSizePixel = 0, ZIndex = 3,
    }, frame)

    self._tabBar = tabBar

    -- ── CONTENT AREA ──────────────────────────────────────────────────────────
    local contentArea = inst("Frame", {
        Size = UDim2.new(1,-(TAB_W+2),1,-(CONTENT_Y+FOOT_H)),
        Position = UDim2.new(0,TAB_W+2,0,CONTENT_Y),
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3,
    }, frame)
    self._contentArea = contentArea

    -- search results overlay
    local srchOverlay = inst("ScrollingFrame", {
        Size = UDim2.new(1,0,1,0), BackgroundColor3 = C.bg,
        BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.accent, CanvasSize = UDim2.new(0,0,0,0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false, ZIndex = 10,
    }, contentArea)
    pad(srchOverlay, 10,10,10,10)
    list(srchOverlay, Enum.FillDirection.Vertical, 6)
    self._srchOverlay = srchOverlay

    -- ── FOOTER ────────────────────────────────────────────────────────────────
    local footer = inst("Frame", {
        Size = UDim2.new(1,0,0,FOOT_H),
        Position = UDim2.new(0,0,1,-FOOT_H),
        BackgroundColor3 = C.card, BorderSizePixel = 0, ZIndex = 3,
    }, frame)
    corner(footer, 14)
    stroke(footer, C.border, 1)

    local unloadBtn = inst("TextButton", {
        Size = UDim2.new(0,72,0,22), Position = UDim2.new(1,-82,.5,-11),
        BackgroundColor3 = Color3.fromRGB(38,18,18),
        Text = "Unload", TextColor3 = C.red,
        Font = Enum.Font.GothamBold, TextSize = 11,
        BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 5,
    }, footer)
    corner(unloadBtn, 6)
    stroke(unloadBtn, Color3.fromRGB(70,25,25), 1)
    unloadBtn.MouseEnter:Connect(function()
        tw(unloadBtn, { BackgroundColor3 = Color3.fromRGB(60,20,20) }, .1)
    end)
    unloadBtn.MouseLeave:Connect(function()
        tw(unloadBtn, { BackgroundColor3 = Color3.fromRGB(38,18,18) }, .1)
    end)

    self._frame   = frame
    self._uptimeLbl = uptimeLbl

    -- ── UPTIME ────────────────────────────────────────────────────────────────
    local uptimeConn = Run.Heartbeat:Connect(function()
        local e = tick() - self._startTime
        local h = math.floor(e/3600)
        local m = math.floor(e%3600/60)
        local s = math.floor(e%60)
        uptimeLbl.Text = ("Uptime: %d:%02d:%02d"):format(h, m, s)
    end)
    self._uptimeConn = uptimeConn

    -- ── KEYBINDS ──────────────────────────────────────────────────────────────
    local function setVis(v)
        self._visible = v
        frame.Visible = v
        bg.Visible    = v
    end

    local kbConn = UIS.InputBegan:Connect(function(i, gp)
        if gp then return end
        if i.KeyCode == self._uiKey   then setVis(not self._visible) end
        if i.KeyCode == self._panicKey then
            uptimeConn:Disconnect()
            gui:Destroy()
        end
    end)
    table.insert(self._conns, kbConn)

    -- ── ENLARGE ───────────────────────────────────────────────────────────────
    local normSize = UDim2.new(0,WIN_W,0,WIN_H)
    local normPos  = UDim2.new(.5,-WIN_W/2,.5,-WIN_H/2)
    enlargeBtn.MouseButton1Click:Connect(function()
        self._enlarged = not self._enlarged
        if self._enlarged then
            tw(frame, { Size = UDim2.new(1,0,1,0), Position = UDim2.new(0,0,0,0) }, .22, Enum.EasingStyle.Quart)
            enlargeBtn.Text = "⊡"
        else
            tw(frame, { Size = normSize, Position = normPos }, .22, Enum.EasingStyle.Quart)
            enlargeBtn.Text = "⛶"
        end
    end)

    -- ── CLOSE ─────────────────────────────────────────────────────────────────
    closeBtn.MouseButton1Click:Connect(function() setVis(false) end)

    -- ── UNLOAD ────────────────────────────────────────────────────────────────
    unloadBtn.MouseButton1Click:Connect(function()
        uptimeConn:Disconnect()
        for _, c in ipairs(self._conns) do pcall(c.Disconnect, c) end
        gui:Destroy()
    end)

    -- ── DRAG ──────────────────────────────────────────────────────────────────
    local function clampFn(x, y, f)
        if not self._clamp then return x, y end
        local vp = workspace.CurrentCamera.ViewportSize
        local sz = f.AbsoluteSize
        return math.clamp(x, 0, vp.X - sz.X), math.clamp(y, 0, vp.Y - sz.Y)
    end
    draggable(frame, hdr, clampFn)

    -- ── SEARCH ────────────────────────────────────────────────────────────────
    srchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local q = srchBox.Text:lower()
        if q == "" then
            srchOverlay.Visible = false
            return
        end
        srchOverlay.Visible = true
        for _, c in ipairs(srchOverlay:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end
        for _, el in ipairs(self._elements) do
            local n = (el._name or ""):lower()
            local d = (el._desc or ""):lower()
            if n:find(q, 1, true) or d:find(q, 1, true) then
                self:_srchCard(srchOverlay, el)
            end
        end
    end)

    return self
end

-- ── search result card ────────────────────────────────────────────────────────
function UI:_srchCard(parent, el)
    local card = inst("Frame", {
        Size = UDim2.new(1,0,0,50), BackgroundColor3 = C.card,
        BorderSizePixel = 0, ZIndex = 11,
    }, parent)
    corner(card, 8)
    stroke(card, C.border, 1)

    inst("TextLabel", {
        Size = UDim2.new(1,-14,0,18), Position = UDim2.new(0,10,0,7),
        BackgroundTransparency = 1, Text = el._name or "",
        TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12,
    }, card)
    inst("TextLabel", {
        Size = UDim2.new(1,-14,0,14), Position = UDim2.new(0,10,0,27),
        BackgroundTransparency = 1,
        Text = el._desc ~= "" and el._desc or (el._type or ""),
        TextColor3 = C.muted, Font = Enum.Font.Gotham, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12,
    }, card)
    inst("TextLabel", {
        Size = UDim2.new(0,100,0,14), Position = UDim2.new(1,-108,0,7),
        BackgroundTransparency = 1,
        Text = el._tabName or "",
        TextColor3 = C.accent, Font = Enum.Font.Gotham, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 12,
    }, card)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- TAB
-- ═══════════════════════════════════════════════════════════════════════════════
function UI:Tab(name, icon)
    local tabData = setmetatable({ _name = name, _win = self }, { __index = Tab })

    local lbl = (icon and icon.."  " or "") .. name
    local btn = inst("TextButton", {
        Size = UDim2.new(1,0,0,32),
        BackgroundColor3 = C.bg,
        Text = lbl, TextColor3 = C.muted,
        Font = Enum.Font.Gotham, TextSize = 12,
        BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 4,
    }, self._tabBar)
    corner(btn, 7)
    pad(btn, 0,8,0,10)
    tabData._btn = btn

    local scroll = inst("ScrollingFrame", {
        Size = UDim2.new(1,0,1,0),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent,
        CanvasSize = UDim2.new(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false, ZIndex = 4,
    }, self._contentArea)
    pad(scroll, 10,10,10,10)
    list(scroll, Enum.FillDirection.Vertical, 8)
    tabData._scroll = scroll

    btn.MouseButton1Click:Connect(function() self:_selectTab(tabData) end)
    table.insert(self._tabs, tabData)
    if #self._tabs == 1 then self:_selectTab(tabData) end

    return tabData
end

function UI:_selectTab(t)
    self._activeTab = t
    for _, tab in ipairs(self._tabs) do
        local active = (tab == t)
        tab._btn.TextColor3       = active and C.text   or C.muted
        tab._btn.BackgroundColor3 = active and C.border2 or C.bg
        tab._btn.Font             = active and Enum.Font.GothamBold or Enum.Font.Gotham
        tab._scroll.Visible       = active
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SEGMENT
-- ═══════════════════════════════════════════════════════════════════════════════
function Tab:Segment(name)
    local seg = setmetatable({ _name = name, _tab = self, _win = self._win }, { __index = Segment })

    local segFrame = inst("Frame", {
        Size = UDim2.new(1,0,0,0), BackgroundColor3 = C.card,
        BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 5,
    }, self._scroll)
    corner(segFrame, 10)
    stroke(segFrame, C.border, 1)

    -- segment header (clickable to collapse)
    local segHdr = inst("TextButton", {
        Size = UDim2.new(1,0,0,36), BackgroundTransparency = 1,
        Text = "", BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 6,
    }, segFrame)
    inst("TextLabel", {
        Size = UDim2.new(1,-36,1,0), Position = UDim2.new(0,12,0,0),
        BackgroundTransparency = 1, Text = name,
        TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7,
    }, segHdr)
    local chev = inst("TextLabel", {
        Size = UDim2.new(0,22,1,0), Position = UDim2.new(1,-26,0,0),
        BackgroundTransparency = 1, Text = "▾",
        TextColor3 = C.muted, Font = Enum.Font.GothamBold, TextSize = 11, ZIndex = 7,
    }, segHdr)

    local div = inst("Frame", {
        Size = UDim2.new(1,-24,0,1), Position = UDim2.new(0,12,0,36),
        BackgroundColor3 = C.border, BorderSizePixel = 0, ZIndex = 6,
    }, segFrame)

    local content = inst("Frame", {
        Size = UDim2.new(1,0,0,0), Position = UDim2.new(0,0,0,37),
        BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0, ZIndex = 6,
    }, segFrame)
    pad(content, 6,10,8,10)
    list(content, Enum.FillDirection.Vertical, 6)
    seg._content = content

    local collapsed = false
    segHdr.MouseButton1Click:Connect(function()
        collapsed = not collapsed
        content.Visible = not collapsed
        div.Visible     = not collapsed
        chev.Text       = collapsed and "▸" or "▾"
    end)

    return seg
end

-- ── element row factory ───────────────────────────────────────────────────────
local function eRow(parent, h)
    return inst("Frame", {
        Size = UDim2.new(1,0,0,h or 36),
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 7,
    }, parent)
end

local function nameLbl(parent, name, desc, yOff)
    yOff = yOff or 0
    inst("TextLabel", {
        Size = UDim2.new(.62,0,0,17), Position = UDim2.new(0,0,0,yOff+1),
        BackgroundTransparency = 1, Text = name,
        TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8,
    }, parent)
    if desc and desc ~= "" then
        inst("TextLabel", {
            Size = UDim2.new(.7,0,0,13), Position = UDim2.new(0,0,0,yOff+19),
            BackgroundTransparency = 1, Text = desc,
            TextColor3 = C.muted, Font = Enum.Font.Gotham, TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8,
        }, parent)
    end
end

local function regEl(seg, name, desc, etype)
    local el = { _name = name, _desc = desc or "", _type = etype, _tabName = seg._tab._name }
    table.insert(seg._win._elements, el)
    return el
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- BUTTON
-- ═══════════════════════════════════════════════════════════════════════════════
function Segment:Button(name, opts, cb)
    if type(opts) == "function" then cb = opts; opts = {} end
    opts = opts or {}
    local desc = opts.Description or ""
    local el   = regEl(self, name, desc, "Button")
    local h    = desc ~= "" and 46 or 34
    local row  = eRow(self._content, h)
    nameLbl(row, name, desc)

    local btn = inst("TextButton", {
        Size = UDim2.new(0,88,0,26), Position = UDim2.new(1,-88,.5,-13),
        BackgroundColor3 = C.accent,
        Text = opts.Label or "Run", TextColor3 = C.white,
        Font = Enum.Font.GothamBold, TextSize = 12,
        BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 8,
    }, row)
    corner(btn, 7)

    btn.MouseEnter:Connect(function() tw(btn, { BackgroundColor3 = C.blue }, .1) end)
    btn.MouseLeave:Connect(function() tw(btn, { BackgroundColor3 = C.accent }, .1) end)
    btn.MouseButton1Click:Connect(function()
        tw(btn, { Size = UDim2.new(0,84,0,23) }, .06)
        task.wait(.06)
        tw(btn, { Size = UDim2.new(0,88,0,26) }, .06)
        if cb then task.spawn(cb) end
    end)
    el._instance = btn
    return el
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- HOLD BUTTON
-- ═══════════════════════════════════════════════════════════════════════════════
function Segment:HoldButton(name, opts, cb)
    if type(opts) == "function" then cb = opts; opts = {} end
    opts = opts or {}
    local desc     = opts.Description or ""
    local holdTime = opts.HoldTime or 1.5
    local el       = regEl(self, name, desc, "HoldButton")
    local h        = desc ~= "" and 46 or 34
    local row      = eRow(self._content, h)
    nameLbl(row, name, desc)

    local btn = inst("TextButton", {
        Size = UDim2.new(0,88,0,26), Position = UDim2.new(1,-88,.5,-13),
        BackgroundColor3 = C.card2,
        Text = "Hold", TextColor3 = C.text,
        Font = Enum.Font.GothamBold, TextSize = 12,
        ClipsDescendants = true,
        BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 8,
    }, row)
    corner(btn, 7)
    stroke(btn, C.border, 1)

    local fill = inst("Frame", {
        Size = UDim2.new(0,0,1,0), BackgroundColor3 = C.accent,
        BorderSizePixel = 0, ZIndex = 7,
    }, btn)
    corner(fill, 7)

    local held, fillConn = false, nil
    btn.InputBegan:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        held = true
        local t0 = tick()
        fillConn = Run.Heartbeat:Connect(function()
            if not held then fillConn:Disconnect(); return end
            local pct = math.min((tick()-t0)/holdTime, 1)
            fill.Size = UDim2.new(pct,0,1,0)
            if pct >= 1 then
                held = false; fillConn:Disconnect()
                fill.Size = UDim2.new(0,0,1,0)
                if cb then task.spawn(cb) end
            end
        end)
    end)
    btn.InputEnded:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        held = false
        tw(fill, { Size = UDim2.new(0,0,1,0) }, .15)
    end)
    el._instance = btn
    return el
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- TOGGLE
-- ═══════════════════════════════════════════════════════════════════════════════
function Segment:Toggle(name, opts, cb)
    if type(opts) == "function" then cb = opts; opts = {} end
    opts = opts or {}
    local desc     = opts.Description or ""
    local default  = opts.Default ~= false
    local bindable = opts.Bindable == true
    local el       = regEl(self, name, desc, "Toggle")
    el._value      = default

    local h   = (desc ~= "" and 46 or 34)
    local row = eRow(self._content, h)
    nameLbl(row, name, desc)

    local PW, PH = 38, 21
    local pill = inst("Frame", {
        Size = UDim2.new(0,PW,0,PH),
        Position = UDim2.new(1, -(PW + (bindable and 36 or 0)), .5, -PH/2),
        BackgroundColor3 = default and C.accent or C.border,
        BorderSizePixel = 0, ZIndex = 8,
    }, row)
    corner(pill, 99)

    local knob = inst("Frame", {
        Size = UDim2.new(0,15,0,15),
        Position = UDim2.new(0, default and PW-18 or 3, .5, -7),
        BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 9,
    }, pill)
    corner(knob, 99)

    local function setState(v, fire)
        el._value = v
        tw(pill,  { BackgroundColor3 = v and C.accent or C.border }, .15)
        tw(knob,  { Position = UDim2.new(0, v and PW-18 or 3, .5, -7) }, .15)
        if fire and cb then task.spawn(cb, v) end
    end
    el._setValue = setState

    inst("TextButton", {
        Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1,
        Text = "", ZIndex = 10,
    }, pill).MouseButton1Click:Connect(function() setState(not el._value, true) end)

    -- bind button
    if bindable then
        local boundKey = nil
        local bBtn = inst("TextButton", {
            Size = UDim2.new(0,30,0,21), Position = UDim2.new(1,-30,.5,-10),
            BackgroundColor3 = C.card2, Text = "–",
            TextColor3 = C.muted, Font = Enum.Font.Code, TextSize = 10,
            BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 8,
        }, row)
        corner(bBtn, 5)
        stroke(bBtn, C.border, 1)

        local listening = false
        bBtn.MouseButton1Click:Connect(function()
            if listening then return end
            listening = true
            bBtn.Text = "…"; bBtn.TextColor3 = C.yellow
            local c; c = UIS.InputBegan:Connect(function(i, gp)
                if gp or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
                boundKey = i.KeyCode
                bBtn.Text = i.KeyCode.Name:sub(1,5); bBtn.TextColor3 = C.accent
                listening = false; c:Disconnect()
            end)
        end)
        local bConn = UIS.InputBegan:Connect(function(i, gp)
            if gp then return end
            if boundKey and i.KeyCode == boundKey then setState(not el._value, true) end
        end)
        table.insert(self._win._conns, bConn)
    end

    el._instance = pill
    return el
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SLIDER
-- ═══════════════════════════════════════════════════════════════════════════════
function Segment:Slider(name, opts, cb)
    if type(opts) == "function" then cb = opts; opts = {} end
    opts = opts or {}
    local desc    = opts.Description or ""
    local mn      = opts.Min or 0
    local mx      = opts.Max or 100
    local default = math.clamp(opts.Default or mn, mn, mx)
    local suffix  = opts.Suffix or ""
    local el      = regEl(self, name, desc, "Slider")
    el._value     = default

    local h = (desc ~= "" and 56 or 44)
    local row = eRow(self._content, h)

    -- name
    inst("TextLabel", {
        Size = UDim2.new(.7,0,0,17), Position = UDim2.new(0,0,0,1),
        BackgroundTransparency = 1, Text = name,
        TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8,
    }, row)
    if desc ~= "" then
        inst("TextLabel", {
            Size = UDim2.new(1,0,0,13), Position = UDim2.new(0,0,0,19),
            BackgroundTransparency = 1, Text = desc,
            TextColor3 = C.muted, Font = Enum.Font.Gotham, TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8,
        }, row)
    end

    local valLbl = inst("TextLabel", {
        Size = UDim2.new(.3,0,0,17), Position = UDim2.new(.7,0,0,1),
        BackgroundTransparency = 1, Text = default..suffix,
        TextColor3 = C.accent, Font = Enum.Font.Code, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 8,
    }, row)

    -- track
    local track = inst("Frame", {
        Size = UDim2.new(1,0,0,8), Position = UDim2.new(0,0,1,-12),
        BackgroundColor3 = C.border, BorderSizePixel = 0, ZIndex = 8,
    }, row)
    corner(track, 99)

    local pct0 = (default - mn) / (mx - mn)
    local fill = inst("Frame", {
        Size = UDim2.new(pct0,0,1,0), BackgroundColor3 = C.accent,
        BorderSizePixel = 0, ZIndex = 9,
    }, track)
    corner(fill, 99)
    gradient(fill, C.accent, C.blue, 0)

    local thumb = inst("Frame", {
        Size = UDim2.new(0,14,0,14), AnchorPoint = Vector2.new(.5,.5),
        Position = UDim2.new(pct0,0,.5,0),
        BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 10,
    }, track)
    corner(thumb, 99)
    stroke(thumb, C.accent, 2)

    local function set(p)
        p = math.clamp(p, 0, 1)
        local v = math.floor(mn + p*(mx-mn) + .5)
        el._value    = v
        valLbl.Text  = v..suffix
        fill.Size    = UDim2.new(p,0,1,0)
        thumb.Position = UDim2.new(p,0,.5,0)
        if cb then task.spawn(cb, v) end
    end
    el._setValue = set

    local drag = false
    thumb.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true end
    end)
    track.InputBegan:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        drag = true
        local p = (i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
        set(p)
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
    end)
    UIS.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            set((i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X)
        end
    end)
    el._instance = track
    return el
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- INPUT FIELD
-- ═══════════════════════════════════════════════════════════════════════════════
function Segment:Input(name, opts, cb)
    if type(opts) == "function" then cb = opts; opts = {} end
    opts = opts or {}
    local desc    = opts.Description or ""
    local numeric = opts.Numeric == true
    local el      = regEl(self, name, desc, "Input")
    el._value     = opts.Default or ""

    local row = eRow(self._content, desc ~= "" and 58 or 46)
    nameLbl(row, name, desc)

    local bg2 = inst("Frame", {
        Size = UDim2.new(1,0,0,26), Position = UDim2.new(0,0,1,-30),
        BackgroundColor3 = C.bg, BorderSizePixel = 0, ZIndex = 8,
    }, row)
    corner(bg2, 7)
    local st = stroke(bg2, C.border, 1)
    pad(bg2, 0,8,0,8)

    local box = inst("TextBox", {
        Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1,
        PlaceholderText = opts.Placeholder or "Enter value…",
        PlaceholderColor3 = C.muted, Text = el._value,
        TextColor3 = C.text, Font = Enum.Font.Code, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ZIndex = 9,
    }, bg2)

    box.Focused:Connect(function()    st.Color = C.accent end)
    box.FocusLost:Connect(function()
        st.Color = C.border
        if numeric then
            local n = tonumber(box.Text)
            box.Text = n and tostring(n) or "0"
        end
        el._value = box.Text
        if cb then task.spawn(cb, el._value) end
    end)
    box:GetPropertyChangedSignal("Text"):Connect(function()
        el._value = box.Text
    end)
    el._instance = box
    return el
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- DROPDOWN (single & multi)
-- ═══════════════════════════════════════════════════════════════════════════════
function Segment:Dropdown(name, opts, cb)
    if type(opts) == "function" then cb = opts; opts = {} end
    opts = opts or {}
    local desc    = opts.Description or ""
    local options = opts.Options or {}
    local multi   = opts.Multi == true
    local default = multi and {} or (opts.Default or options[1])
    local el      = regEl(self, name, desc, multi and "MultiDropdown" or "Dropdown")
    el._value     = default

    local h = desc ~= "" and 54 or 42
    local row = eRow(self._content, h)
    nameLbl(row, name, desc, 0)

    local ddBtn = inst("TextButton", {
        Size = UDim2.new(1,0,0,26), Position = UDim2.new(0,0,1,-30),
        BackgroundColor3 = C.bg, Text = "",
        BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 8,
    }, row)
    corner(ddBtn, 7)
    stroke(ddBtn, C.border, 1)
    pad(ddBtn, 0,26,0,8)

    local ddLbl = inst("TextLabel", {
        Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1,
        Text = multi and "Select…" or (default or "Select…"),
        TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9,
    }, ddBtn)
    inst("TextLabel", {
        Size = UDim2.new(0,20,1,0), Position = UDim2.new(1,-22,0,0),
        BackgroundTransparency = 1, Text = "▾",
        TextColor3 = C.muted, Font = Enum.Font.GothamBold, TextSize = 11, ZIndex = 9,
    }, ddBtn)

    local open, listFr = false, nil

    local function updateLabel()
        if multi then
            local sel = {}
            for k, v in pairs(el._value) do if v then table.insert(sel, k) end end
            ddLbl.Text = #sel > 0 and table.concat(sel, ", ") or "Select…"
        else
            ddLbl.Text = el._value or "Select…"
        end
    end

    local function closeList()
        if listFr then listFr:Destroy(); listFr = nil end
        open = false
    end

    ddBtn.MouseButton1Click:Connect(function()
        if open then closeList(); return end
        open = true
        local ap   = ddBtn.AbsolutePosition
        local as   = ddBtn.AbsoluteSize
        local itemH = 28
        local lh    = math.min(#options * itemH, 160)

        listFr = inst("Frame", {
            Size = UDim2.new(0,as.X,0,lh),
            Position = UDim2.new(0,ap.X,0,ap.Y+as.Y+4),
            BackgroundColor3 = C.card, BorderSizePixel = 0, ZIndex = 50,
        }, self._win._gui)
        corner(listFr, 8)
        stroke(listFr, C.border, 1)

        local ls = inst("ScrollingFrame", {
            Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1,
            BorderSizePixel = 0, ScrollBarThickness = 2,
            ScrollBarImageColor3 = C.accent,
            CanvasSize = UDim2.new(0,0,0,#options*itemH), ZIndex = 51,
        }, listFr)
        list(ls, Enum.FillDirection.Vertical, 0)

        for _, opt in ipairs(options) do
            local isSel = multi and el._value[opt] or (el._value == opt)
            local item = inst("TextButton", {
                Size = UDim2.new(1,0,0,itemH),
                BackgroundColor3 = isSel and Color3.fromRGB(28,22,48) or C.card,
                Text = "", BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 52,
            }, ls)
            pad(item, 0,8,0,10)
            local txt = inst("TextLabel", {
                Size = UDim2.new(1,multi and -24 or 0,1,0),
                BackgroundTransparency = 1, Text = tostring(opt),
                TextColor3 = isSel and C.accent or C.text,
                Font = Enum.Font.Gotham, TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 53,
            }, item)
            local chk; if multi then
                chk = inst("TextLabel", {
                    Size = UDim2.new(0,18,0,18), Position = UDim2.new(1,-22,.5,-9),
                    BackgroundTransparency = 1, Text = isSel and "✓" or "",
                    TextColor3 = C.ok, Font = Enum.Font.GothamBold, TextSize = 12, ZIndex = 53,
                }, item)
            end

            item.MouseEnter:Connect(function() tw(item, { BackgroundColor3 = C.border  }, .08) end)
            item.MouseLeave:Connect(function()
                local s = multi and el._value[opt] or (el._value == opt)
                tw(item, { BackgroundColor3 = s and Color3.fromRGB(28,22,48) or C.card }, .08)
            end)

            if multi then
                item.MouseButton1Click:Connect(function()
                    el._value[opt] = not el._value[opt]
                    chk.Text  = el._value[opt] and "✓" or ""
                    txt.TextColor3 = el._value[opt] and C.accent or C.text
                    item.BackgroundColor3 = el._value[opt] and Color3.fromRGB(28,22,48) or C.card
                    updateLabel()
                    if cb then task.spawn(cb, el._value) end
                end)
            else
                item.MouseButton1Click:Connect(function()
                    el._value = opt; updateLabel(); closeList()
                    if cb then task.spawn(cb, opt) end
                end)
            end
        end
    end)

    -- close on outside click
    self._win._gui.InputBegan:Connect(function(i)
        if not open or i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if not listFr then return end
        local mp  = UIS:GetMouseLocation()
        local ap2 = listFr.AbsolutePosition
        local as2 = listFr.AbsoluteSize
        if mp.X < ap2.X or mp.X > ap2.X+as2.X or mp.Y < ap2.Y or mp.Y > ap2.Y+as2.Y then
            closeList()
        end
    end)

    el._instance = ddBtn
    return el
end

function Segment:MultiDropdown(name, opts, cb)
    opts = opts or {}; opts.Multi = true
    return self:Dropdown(name, opts, cb)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- COLOR PICKER
-- ═══════════════════════════════════════════════════════════════════════════════
function Segment:ColorPicker(name, opts, cb)
    if type(opts) == "function" then cb = opts; opts = {} end
    opts = opts or {}
    local desc    = opts.Description or ""
    local default = opts.Default or C.accent
    local el      = regEl(self, name, desc, "ColorPicker")
    el._value     = default

    local h   = desc ~= "" and 46 or 34
    local row = eRow(self._content, h)
    nameLbl(row, name, desc)

    local swatch = inst("TextButton", {
        Size = UDim2.new(0,34,0,22), Position = UDim2.new(1,-34,.5,-11),
        BackgroundColor3 = default, Text = "",
        BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 8,
    }, row)
    corner(swatch, 6)
    stroke(swatch, C.border2, 1)

    local h_hsv, s_hsv, v_hsv = Color3.toHSV(default)
    local pickerFr, pickerOpen = nil, false
    local SV = 160

    local function applyColor(nh, ns, nv)
        h_hsv, s_hsv, v_hsv = nh, ns, nv
        local col = Color3.fromHSV(nh, ns, nv)
        el._value = col
        swatch.BackgroundColor3 = col
        if cb then task.spawn(cb, col) end
    end

    local function toHex(c)
        return ("#%02X%02X%02X"):format(c.R*255, c.G*255, c.B*255)
    end

    local function buildPicker()
        local ap = swatch.AbsolutePosition
        local as2 = swatch.AbsoluteSize
        local PW, PH = 210, 230

        pickerFr = inst("Frame", {
            Size = UDim2.new(0,PW,0,PH),
            Position = UDim2.new(0, math.min(ap.X, workspace.CurrentCamera.ViewportSize.X - PW - 10),
                                 0, ap.Y + as2.Y + 6),
            BackgroundColor3 = C.card, BorderSizePixel = 0, ZIndex = 60,
        }, self._win._gui)
        corner(pickerFr, 10)
        stroke(pickerFr, C.border2, 1)
        pad(pickerFr, 10,10,10,10)

        -- SV box (uses a gradient texture)
        local svBox = inst("ImageLabel", {
            Size = UDim2.new(0,SV,0,SV),
            BackgroundColor3 = Color3.fromHSV(h_hsv,1,1),
            Image = "rbxassetid://4155801252", -- SV overlay (white→transparent, black fade)
            ZIndex = 61,
        }, pickerFr)
        corner(svBox, 6)

        local svThumb = inst("Frame", {
            Size = UDim2.new(0,12,0,12), AnchorPoint = Vector2.new(.5,.5),
            Position = UDim2.new(s_hsv,0,1-v_hsv,0),
            BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 63,
        }, svBox)
        corner(svThumb, 99)
        stroke(svThumb, C.border, 1.5)

        -- hue bar
        local hueBar = inst("ImageLabel", {
            Size = UDim2.new(0,SV,0,13),
            Position = UDim2.new(0,0,0,SV+10),
            Image = "rbxassetid://698052001", -- rainbow hue bar
            BackgroundTransparency = 1, ZIndex = 61,
        }, pickerFr)
        corner(hueBar, 4)

        local hThumb = inst("Frame", {
            Size = UDim2.new(0,5,0,13), AnchorPoint = Vector2.new(.5,0),
            Position = UDim2.new(h_hsv,0,0,0),
            BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 62,
        }, hueBar)
        corner(hThumb, 3)
        stroke(hThumb, C.border, 1)

        -- hex input
        local hexBg = inst("Frame", {
            Size = UDim2.new(0,SV,0,24), Position = UDim2.new(0,0,0,SV+30),
            BackgroundColor3 = C.bg, BorderSizePixel = 0, ZIndex = 61,
        }, pickerFr)
        corner(hexBg, 6)
        local hexSt = stroke(hexBg, C.border, 1)
        pad(hexBg, 0,6,0,6)
        local hexBox = inst("TextBox", {
            Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1,
            Text = toHex(el._value), TextColor3 = C.text,
            Font = Enum.Font.Code, TextSize = 11,
            ClearTextOnFocus = false, ZIndex = 62,
        }, hexBg)
        hexBox.Focused:Connect(function()  hexSt.Color = C.accent end)
        hexBox.FocusLost:Connect(function()
            hexSt.Color = C.border
            local tx = hexBox.Text:gsub("#","")
            if #tx == 6 then
                local r = tonumber(tx:sub(1,2),16)
                local g = tonumber(tx:sub(3,4),16)
                local b = tonumber(tx:sub(5,6),16)
                if r and g and b then
                    local nh,ns,nv = Color3.toHSV(Color3.fromRGB(r,g,b))
                    applyColor(nh,ns,nv)
                    svBox.BackgroundColor3 = Color3.fromHSV(nh,1,1)
                    svThumb.Position = UDim2.new(ns,0,1-nv,0)
                    hThumb.Position  = UDim2.new(nh,0,0,0)
                end
            end
        end)

        -- SV drag
        local svDrag = false
        local function svUpdate(pos)
            local rel = pos - svBox.AbsolutePosition
            local ns  = math.clamp(rel.X/SV,0,1)
            local nv  = 1-math.clamp(rel.Y/SV,0,1)
            applyColor(h_hsv,ns,nv)
            svThumb.Position = UDim2.new(ns,0,1-nv,0)
            hexBox.Text = toHex(el._value)
        end
        svBox.InputBegan:Connect(function(i)
            if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            svDrag = true; svUpdate(i.Position)
        end)
        UIS.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then svDrag = false end
        end)
        UIS.InputChanged:Connect(function(i)
            if svDrag and i.UserInputType == Enum.UserInputType.MouseMovement then svUpdate(i.Position) end
        end)

        -- hue drag
        local hueDrag = false
        local function hueUpdate(pos)
            local nh = math.clamp((pos.X - hueBar.AbsolutePosition.X)/SV,0,1)
            applyColor(nh,s_hsv,v_hsv)
            svBox.BackgroundColor3 = Color3.fromHSV(nh,1,1)
            hThumb.Position = UDim2.new(nh,0,0,0)
            hexBox.Text = toHex(el._value)
        end
        hueBar.InputBegan:Connect(function(i)
            if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            hueDrag = true; hueUpdate(i.Position)
        end)
        UIS.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then hueDrag = false end
        end)
        UIS.InputChanged:Connect(function(i)
            if hueDrag and i.UserInputType == Enum.UserInputType.MouseMovement then hueUpdate(i.Position) end
        end)
    end

    swatch.MouseButton1Click:Connect(function()
        if pickerOpen then
            if pickerFr then pickerFr:Destroy(); pickerFr = nil end
            pickerOpen = false
        else
            pickerOpen = true; buildPicker()
        end
    end)
    -- close picker on outside click
    self._win._gui.InputBegan:Connect(function(i)
        if not pickerOpen or i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if not pickerFr then return end
        local mp = UIS:GetMouseLocation()
        local ap = pickerFr.AbsolutePosition; local as2 = pickerFr.AbsoluteSize
        if mp.X<ap.X or mp.X>ap.X+as2.X or mp.Y<ap.Y or mp.Y>ap.Y+as2.Y then
            pickerFr:Destroy(); pickerFr = nil; pickerOpen = false
        end
    end)

    el._instance = swatch
    return el
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- LABEL (read-only)
-- ═══════════════════════════════════════════════════════════════════════════════
function Segment:Label(text, color)
    return inst("TextLabel", {
        Size = UDim2.new(1,0,0,18), BackgroundTransparency = 1,
        Text = text, TextColor3 = color or C.muted,
        Font = Enum.Font.Gotham, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, ZIndex = 7,
    }, self._content)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SETTINGS TAB
-- ═══════════════════════════════════════════════════════════════════════════════
function UI:SettingsTab()
    local tab = self:Tab("Settings", "⚙")
    local seg = tab:Segment("UI Settings")

    -- toggle key rebind
    local win = self
    local tkRow = eRow(seg._content, 36)
    local tkLbl = inst("TextLabel", {
        Size = UDim2.new(.6,0,1,0), BackgroundTransparency = 1,
        Text = "Toggle Key: "..win._uiKey.Name,
        TextColor3 = C.muted, Font = Enum.Font.Code, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8,
    }, tkRow)
    local tkBtn = inst("TextButton", {
        Size = UDim2.new(0,78,0,24), Position = UDim2.new(1,-78,.5,-12),
        BackgroundColor3 = C.card2, Text = "Rebind",
        TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 11,
        BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 8,
    }, tkRow)
    corner(tkBtn, 6); stroke(tkBtn, C.border, 1)
    local tkListening = false
    tkBtn.MouseButton1Click:Connect(function()
        if tkListening then return end
        tkListening = true; tkBtn.Text = "Press…"; tkBtn.TextColor3 = C.yellow
        local c; c = UIS.InputBegan:Connect(function(i, gp)
            if gp or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
            win._uiKey = i.KeyCode
            tkLbl.Text = "Toggle Key: "..i.KeyCode.Name
            tkBtn.Text = i.KeyCode.Name; tkBtn.TextColor3 = C.text
            tkListening = false; c:Disconnect()
        end)
    end)

    -- panic key rebind
    local pkRow = eRow(seg._content, 36)
    local pkLbl = inst("TextLabel", {
        Size = UDim2.new(.6,0,1,0), BackgroundTransparency = 1,
        Text = "Panic Key: "..win._panicKey.Name,
        TextColor3 = C.muted, Font = Enum.Font.Code, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8,
    }, pkRow)
    local pkBtn = inst("TextButton", {
        Size = UDim2.new(0,78,0,24), Position = UDim2.new(1,-78,.5,-12),
        BackgroundColor3 = C.card2, Text = "Rebind",
        TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 11,
        BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 8,
    }, pkRow)
    corner(pkBtn, 6); stroke(pkBtn, C.border, 1)
    local pkListening = false
    pkBtn.MouseButton1Click:Connect(function()
        if pkListening then return end
        pkListening = true; pkBtn.Text = "Press…"; pkBtn.TextColor3 = C.yellow
        local c; c = UIS.InputBegan:Connect(function(i, gp)
            if gp or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
            win._panicKey = i.KeyCode
            pkLbl.Text = "Panic Key: "..i.KeyCode.Name
            pkBtn.Text = i.KeyCode.Name; pkBtn.TextColor3 = C.text
            pkListening = false; c:Disconnect()
        end)
    end)

    -- clamp toggle
    seg:Toggle("Clamp UI to Screen", {
        Default = win._clamp,
        Description = "Prevents the window from being dragged off-screen.",
    }, function(v) win._clamp = v end)

    -- panic button
    seg:Button("Panic — Unload Everything", { Label = "Panic!" }, function()
        win._uptimeConn:Disconnect()
        for _, c in ipairs(win._conns) do pcall(c.Disconnect, c) end
        win._gui:Destroy()
    end)

    return tab
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CONFIG TAB
-- ═══════════════════════════════════════════════════════════════════════════════
function UI:ConfigTab()
    local tab = self:Tab("Config", "💾")
    local seg = tab:Segment("Configs")
    local DIR = "veltrix_configs/"

    if makefolder and not (isfolder and isfolder(DIR)) then
        pcall(makefolder, DIR)
    end

    local function listCfgs()
        if not listfiles then return {} end
        local out = {}
        for _, f in ipairs(listfiles(DIR) or {}) do
            local n = tostring(f):match("([^/\\]+)%.json$")
            if n then table.insert(out, n) end
        end
        return out
    end

    local function serialize()
        local d = {}
        for _, el in ipairs(self._elements) do
            if el._name and el._value ~= nil then
                if typeof(el._value) == "Color3" then
                    d[el._name] = { r = el._value.R, g = el._value.G, b = el._value.B }
                else
                    d[el._name] = el._value
                end
            end
        end
        return Http:JSONEncode(d)
    end

    local function applyData(d)
        for _, el in ipairs(self._elements) do
            local v = d[el._name]
            if v == nil then continue end
            if el._type == "Toggle" and el._setValue then
                el._setValue(v == true, true)
            elseif el._type == "Slider" and el._setValue then
                -- re-derive pct from stored int value (opts not stored, so clamp 0-1)
                el._setValue(math.clamp((v - 0) / 100, 0, 1))
            elseif el._type == "Input" and el._instance then
                el._instance.Text = tostring(v); el._value = v
            elseif el._type == "ColorPicker" and type(v) == "table" then
                local col = Color3.new(v.r or 1, v.g or 1, v.b or 1)
                el._value = col
                if el._instance then el._instance.BackgroundColor3 = col end
            elseif el._type == "Dropdown" or el._type == "MultiDropdown" then
                el._value = v
            end
        end
    end

    local cfgList = listCfgs()
    local nameEl  = seg:Input("Config Name", { Placeholder = "my_config", Default = "default" })
    local selEl   = seg:Dropdown("Select Config", { Options = #cfgList > 0 and cfgList or {"(none)"} })

    local btnRow2 = eRow(seg._content, 34)
    list(btnRow2, Enum.FillDirection.Horizontal, 6)

    local function smBtn(lbl, parent, col)
        local b = inst("TextButton", {
            Size = UDim2.new(0,80,0,26),
            BackgroundColor3 = col or C.accent,
            Text = lbl, TextColor3 = C.white,
            Font = Enum.Font.GothamBold, TextSize = 11,
            BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 8,
        }, parent)
        corner(b, 7)
        b.MouseEnter:Connect(function() tw(b, { BackgroundColor3 = C.blue }, .1) end)
        b.MouseLeave:Connect(function() tw(b, { BackgroundColor3 = col or C.accent }, .1) end)
        return b
    end

    local saveB = smBtn("Save",   btnRow2)
    local loadB = smBtn("Load",   btnRow2, C.card2)
    local delB  = smBtn("Delete", btnRow2, Color3.fromRGB(50,20,20))
    stroke(loadB, C.border, 1); loadB.TextColor3 = C.text
    stroke(delB,  Color3.fromRGB(80,25,25), 1); delB.TextColor3 = C.red

    saveB.MouseButton1Click:Connect(function()
        local n = nameEl._value ~= "" and nameEl._value or "default"
        if writefile then pcall(writefile, DIR..n..".json", serialize()) end
    end)

    loadB.MouseButton1Click:Connect(function()
        local n = selEl._value
        if not n or n == "(none)" or not readfile then return end
        local ok, raw = pcall(readfile, DIR..n..".json")
        if not ok then return end
        local ok2, d = pcall(Http.JSONDecode, Http, raw)
        if ok2 and d then applyData(d) end
    end)

    delB.MouseButton1Click:Connect(function()
        local n = selEl._value
        if n and n ~= "(none)" and delfile then pcall(delfile, DIR..n..".json") end
    end)

    return tab
end

return UI
