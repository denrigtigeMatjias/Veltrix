--[[
    Veltrix UI  •  v2
    Dark purple/blue theme matching the Veltrix website.
    Compatible with Synapse X, KRNL, Fluxus, Script-Ware.
]]

local UI = {}
UI.__index = UI

-- ── Services ──────────────────────────────────────────────────────────────────
local TweenSvc = game:GetService("TweenService")
local UIS      = game:GetService("UserInputService")
local Run      = game:GetService("RunService")
local Http     = game:GetService("HttpService")
local Plrs     = game:GetService("Players")
local lp       = Plrs.LocalPlayer

-- ── Palette ───────────────────────────────────────────────────────────────────
local C = {
    bg      = Color3.fromRGB(11,  13,  18),
    sidebar = Color3.fromRGB(14,  16,  23),
    card    = Color3.fromRGB(19,  21,  30),
    card2   = Color3.fromRGB(24,  27,  38),
    border  = Color3.fromRGB(30,  34,  50),
    text    = Color3.fromRGB(225, 228, 238),
    sub     = Color3.fromRGB(160, 165, 185),
    muted   = Color3.fromRGB(90,  96,  115),
    accent  = Color3.fromRGB(124, 92,  252),
    blue    = Color3.fromRGB(91,  141, 238),
    green   = Color3.fromRGB(34,  211, 165),
    red     = Color3.fromRGB(240, 100, 100),
    yellow  = Color3.fromRGB(251, 191, 36),
    white   = Color3.fromRGB(255, 255, 255),
    black   = Color3.fromRGB(0,   0,   0),
}

-- ── Layout ────────────────────────────────────────────────────────────────────
local WW   = 820     -- window width
local WH   = 480     -- window height
local SW   = 172     -- sidebar width
local HH   = 44      -- header height
local EH   = 32      -- element row height (base)
local EHD  = 46      -- element row height with description
local ERPAD = 8      -- right padding for widgets
local LBLW  = 0.60   -- label takes 60% of row

-- ── Tiny helpers ──────────────────────────────────────────────────────────────
local function tw(o, p, t, s, d)
    TweenSvc:Create(o, TweenInfo.new(t or .14, s or Enum.EasingStyle.Quad,
        d or Enum.EasingDirection.Out), p):Play()
end

local function mk(cls, props, parent)
    local o = Instance.new(cls)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function rnd(p, r)
    mk("UICorner", { CornerRadius = UDim.new(0, r or 6) }, p)
end

local function bdr(p, col, thick)
    mk("UIStroke", {
        Color = col or C.border, Thickness = thick or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, p)
end

local function pad(p, t, r, b, l)
    mk("UIPadding", {
        PaddingTop    = UDim.new(0, t or 0),
        PaddingRight  = UDim.new(0, r or 0),
        PaddingBottom = UDim.new(0, b or 0),
        PaddingLeft   = UDim.new(0, l or 0),
    }, p)
end

local function lst(p, dir, gap)
    mk("UIListLayout", {
        FillDirection = dir or Enum.FillDirection.Vertical,
        SortOrder     = Enum.SortOrder.LayoutOrder,
        Padding       = UDim.new(0, gap or 0),
    }, p)
end

local function lbl(txt, col, sz, font, parent, props)
    props = props or {}
    props.BackgroundTransparency = 1
    props.Text      = txt
    props.TextColor3 = col or C.text
    props.Font       = font or Enum.Font.Gotham
    props.TextSize   = sz or 13
    if not props.Size then props.Size = UDim2.new(1,0,0,sz and sz+4 or 17) end
    props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
    props.ZIndex = props.ZIndex or 8
    return mk("TextLabel", props, parent)
end

-- ── GUI parent (CoreGui with executor fallbacks) ───────────────────────────────
local function guiParent()
    if gethui then return gethui() end
    local cg = game:GetService("CoreGui")
    local ok = pcall(function()
        mk("Folder", {}, cg):Destroy()
    end)
    if ok then return cg end
    return lp:WaitForChild("PlayerGui")
end

-- ── Dragging ──────────────────────────────────────────────────────────────────
local function makeDraggable(frame, handle, shouldClamp)
    local dragging, sp, sf = false
    handle.InputBegan:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        dragging = true
        sp = i.Position
        sf = frame.Position
    end)
    handle.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if not dragging or i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local d = i.Position - sp
        local nx = sf.X.Offset + d.X
        local ny = sf.Y.Offset + d.Y
        if shouldClamp and shouldClamp() then
            local vp = workspace.CurrentCamera.ViewportSize
            nx = math.clamp(nx, 0, vp.X - WW)
            ny = math.clamp(ny, 0, vp.Y - WH)
        end
        frame.Position = UDim2.new(sf.X.Scale, nx, sf.Y.Scale, ny)
    end)
end

-- ── Classes ───────────────────────────────────────────────────────────────────
local Tab     = {}; Tab.__index     = Tab
local Segment = {}; Segment.__index = Segment

-- ═══════════════════════════════════════════════════════════════════════════════
--  WINDOW
-- ═══════════════════════════════════════════════════════════════════════════════
function UI:Window(opts)
    opts = opts or {}
    local self = setmetatable({
        _tabs      = {},
        _elements  = {},
        _conns     = {},
        _visible   = true,
        _enlarged  = false,
        _clamp     = opts.ClampScreen ~= false,
        _uiKey     = opts.ToggleKey or Enum.KeyCode.RightShift,
        _panicKey  = opts.PanicKey  or Enum.KeyCode.End,
        _startTime = tick(),
        _key       = opts.Key or "",
    }, { __index = UI })

    -- destroy previous instance
    for _, v in ipairs(guiParent():GetChildren()) do
        if v.Name == "VeltrixUI" then v:Destroy() end
    end

    -- root ScreenGui
    local gui = mk("ScreenGui", {
        Name = "VeltrixUI", ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1000,
    }, guiParent())
    self._gui = gui

    -- ── main frame ────────────────────────────────────────────────────────────
    local frame = mk("Frame", {
        Size     = UDim2.new(0, WW, 0, WH),
        Position = UDim2.new(.5, -WW/2, .5, -WH/2),
        BackgroundColor3 = C.bg,
        BorderSizePixel  = 0, ClipsDescendants = true, ZIndex = 2,
    }, gui)
    rnd(frame, 12)
    bdr(frame, C.border, 1)
    self._frame = frame

    -- top gradient accent line
    local accentLine = mk("Frame", {
        Size = UDim2.new(1,0,0,2), BackgroundColor3 = C.accent,
        BorderSizePixel = 0, ZIndex = 3,
    }, frame)
    mk("UIGradient", {
        Color    = ColorSequence.new(C.accent, C.blue),
        Rotation = 0,
    }, accentLine)

    -- ── HEADER ────────────────────────────────────────────────────────────────
    local hdr = mk("Frame", {
        Size = UDim2.new(1, 0, 0, HH),
        Position = UDim2.new(0,0,0,2),
        BackgroundColor3 = C.bg,
        BorderSizePixel = 0, ZIndex = 3,
        Active = true,
    }, frame)

    -- title dot + text
    mk("Frame", {
        Size = UDim2.new(0,6,0,6), Position = UDim2.new(0,16,0.5,-3),
        BackgroundColor3 = C.accent, BorderSizePixel = 0, ZIndex = 4,
    }, hdr); rnd(hdr:FindFirstChild("Frame") or hdr, 99)

    lbl(opts.Title or "Veltrix", C.text, 14, Enum.Font.GothamBold, hdr, {
        Size = UDim2.new(0,120,0,20),
        Position = UDim2.new(0,28,0.5,-10),
        ZIndex = 4,
    })

    -- header right-side controls
    local ctrlFrame = mk("Frame", {
        Size = UDim2.new(0,72,0,26),
        Position = UDim2.new(1,-80,0.5,-13),
        BackgroundTransparency = 1, ZIndex = 4,
    }, hdr)
    lst(ctrlFrame, Enum.FillDirection.Horizontal, 6)

    local function ctrlBtn(sym, col)
        local b = mk("TextButton", {
            Size = UDim2.new(0,28,0,26),
            BackgroundColor3 = C.card2,
            Text = sym, TextColor3 = col or C.sub,
            Font = Enum.Font.GothamBold, TextSize = 14,
            BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 5,
        }, ctrlFrame)
        rnd(b, 6)
        bdr(b, C.border, 1)
        b.MouseEnter:Connect(function() tw(b, { BackgroundColor3 = C.border }, .1) end)
        b.MouseLeave:Connect(function() tw(b, { BackgroundColor3 = C.card2  }, .1) end)
        return b
    end

    local enlargeBtn = ctrlBtn("⊞", C.sub)
    local closeBtn   = ctrlBtn("✕", C.red)

    -- header bottom divider
    mk("Frame", {
        Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,1,-1),
        BackgroundColor3 = C.border, BorderSizePixel = 0, ZIndex = 4,
    }, hdr)

    -- drag from empty header space
    makeDraggable(frame, hdr, function() return self._clamp and not self._enlarged end)

    -- ── LEFT SIDEBAR ──────────────────────────────────────────────────────────
    local sbY  = HH + 2
    local sbH  = WH - sbY
    local sidebar = mk("Frame", {
        Size = UDim2.new(0, SW, 0, sbH),
        Position = UDim2.new(0, 0, 0, sbY),
        BackgroundColor3 = C.sidebar,
        BorderSizePixel = 0, ZIndex = 3,
    }, frame)

    -- sidebar right divider
    mk("Frame", {
        Size = UDim2.new(0,1,0,sbH), Position = UDim2.new(0,SW,0,sbY),
        BackgroundColor3 = C.border, BorderSizePixel = 0, ZIndex = 3,
    }, frame)

    -- ── User card ─────────────────────────────────────────────────────────────
    local uCard = mk("Frame", {
        Size = UDim2.new(1,0,0,88),
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4,
    }, sidebar)
    pad(uCard, 14,10,0,12)

    local avWrap = mk("Frame", {
        Size = UDim2.new(0,36,0,36), Position = UDim2.new(0,0,0,0),
        BackgroundColor3 = C.border, BorderSizePixel = 0, ZIndex = 5,
    }, uCard)
    rnd(avWrap, 99)
    bdr(avWrap, C.border, 1)

    local avImg = mk("ImageLabel", {
        Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, ZIndex = 6,
    }, avWrap)
    rnd(avImg, 99)

    task.spawn(function()
        local ok, uid = pcall(Plrs.GetUserIdFromNameAsync, Plrs, lp.Name)
        if not ok then return end
        local ok2, img = pcall(Plrs.GetUserThumbnailAsync, Plrs, uid,
            Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
        if ok2 then avImg.Image = img end
    end)

    lbl(lp.DisplayName, C.text, 13, Enum.Font.GothamBold, uCard, {
        Size = UDim2.new(1,-44,0,16), Position = UDim2.new(0,44,0,2), ZIndex = 5,
    })
    lbl("@"..lp.Name, C.muted, 11, Enum.Font.Gotham, uCard, {
        Size = UDim2.new(1,-44,0,14), Position = UDim2.new(0,44,0,19), ZIndex = 5,
    })

    -- key label beneath avatar+name
    local keyLbl = lbl("Key: …", C.muted, 10, Enum.Font.Code, uCard, {
        Size = UDim2.new(1,0,0,14), Position = UDim2.new(0,0,0,42), ZIndex = 5,
    })

    -- fetch key TTL
    if self._key ~= "" then
        task.spawn(function()
            local ok, raw = pcall(Http.GetAsync, Http,
                "https://veltrix-worker.matjias.workers.dev/validate?key="
                ..Http:UrlEncode(self._key))
            if ok then
                local ok2, data = pcall(Http.JSONDecode, Http, raw)
                if ok2 and data and data.valid then
                    local h = math.floor(data.ttl/3600)
                    local m = math.floor(data.ttl%3600/60)
                    keyLbl.Text       = ("Key: %dh %dm"):format(h,m)
                    keyLbl.TextColor3  = C.green
                else
                    keyLbl.Text        = "Key: expired"
                    keyLbl.TextColor3  = C.red
                end
            else
                keyLbl.Text = "Key: offline"
            end
        end)
    else
        keyLbl.Text = "Key: not set"
    end

    -- sidebar divider below user card
    mk("Frame", {
        Size = UDim2.new(1,-20,0,1), Position = UDim2.new(0,10,0,90),
        BackgroundColor3 = C.border, BorderSizePixel = 0, ZIndex = 4,
    }, sidebar)

    -- tab list container
    local tabList = mk("Frame", {
        Size = UDim2.new(1,0,1,-100),
        Position = UDim2.new(0,0,0,98),
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4,
    }, sidebar)
    pad(tabList, 4,6,6,6)
    lst(tabList, Enum.FillDirection.Vertical, 2)
    self._tabList = tabList

    -- ── CONTENT AREA ──────────────────────────────────────────────────────────
    local cX  = SW + 1
    local cW  = WW - cX
    local cY  = sbY
    local cH  = WH - cY

    -- search bar at top of content
    local srchH = 36
    local srchBar = mk("Frame", {
        Size = UDim2.new(0,cW,0,srchH),
        Position = UDim2.new(0,cX,0,cY),
        BackgroundColor3 = C.bg, BorderSizePixel = 0, ZIndex = 3,
    }, frame)

    lbl("⌕", C.muted, 14, Enum.Font.Gotham, srchBar, {
        Size = UDim2.new(0,28,1,0), Position = UDim2.new(0,6,0,0),
        TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4,
    })

    local srchBox = mk("TextBox", {
        Size = UDim2.new(1,-34,1,-8), Position = UDim2.new(0,30,0,4),
        BackgroundTransparency = 1,
        PlaceholderText = "Search…", PlaceholderColor3 = C.muted,
        Text = "", TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false, ZIndex = 4,
    }, srchBar)

    mk("Frame", {
        Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,1,-1),
        BackgroundColor3 = C.border, BorderSizePixel = 0, ZIndex = 4,
    }, srchBar)

    self._srchBox = srchBox

    -- content scroll container (per-tab scrollframes live here)
    local contentArea = mk("Frame", {
        Size = UDim2.new(0,cW,0,cH-srchH),
        Position = UDim2.new(0,cX,0,cY+srchH),
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3,
        ClipsDescendants = true,
    }, frame)
    self._contentArea = contentArea

    -- search overlay
    local srchOverlay = mk("ScrollingFrame", {
        Size = UDim2.new(1,0,1,0),
        BackgroundColor3 = C.bg,
        BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.accent,
        CanvasSize = UDim2.new(0,0,0,0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false, ZIndex = 10,
    }, contentArea)
    pad(srchOverlay, 10,10,10,10)
    lst(srchOverlay, Enum.FillDirection.Vertical, 4)
    self._srchOverlay = srchOverlay

    -- ── Controls ──────────────────────────────────────────────────────────────
    local normSz  = UDim2.new(0,WW,0,WH)
    local normPos = UDim2.new(.5,-WW/2,.5,-WH/2)

    local function setVis(v)
        self._visible = v
        frame.Visible = v
    end

    local kc = UIS.InputBegan:Connect(function(i, gp)
        if gp then return end
        if i.KeyCode == self._uiKey   then setVis(not self._visible) end
        if i.KeyCode == self._panicKey then self:_destroy() end
    end)
    table.insert(self._conns, kc)

    enlargeBtn.MouseButton1Click:Connect(function()
        self._enlarged = not self._enlarged
        if self._enlarged then
            tw(frame, { Size = UDim2.new(1,0,1,0), Position = UDim2.new(0,0,0,0) }, .2, Enum.EasingStyle.Quart)
            enlargeBtn.Text = "⊟"
        else
            tw(frame, { Size = normSz, Position = normPos }, .2, Enum.EasingStyle.Quart)
            enlargeBtn.Text = "⊞"
        end
    end)

    closeBtn.MouseButton1Click:Connect(function() setVis(false) end)

    -- ── Uptime runner ─────────────────────────────────────────────────────────
    self._uptimeFns = {}
    local uc = Run.Heartbeat:Connect(function()
        local e = tick() - self._startTime
        local h = math.floor(e/3600)
        local m = math.floor(e%3600/60)
        local s = math.floor(e%60)
        local str = ("Session: %d:%02d:%02d"):format(h,m,s)
        for _, fn in ipairs(self._uptimeFns) do fn(str) end
    end)
    self._uptimeConn = uc
    table.insert(self._conns, uc)

    -- ── Search logic ──────────────────────────────────────────────────────────
    srchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local q = srchBox.Text:lower()
        if q == "" then srchOverlay.Visible = false; return end
        srchOverlay.Visible = true
        for _, c in ipairs(srchOverlay:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end
        for _, el in ipairs(self._elements) do
            if ((el._name or ""):lower():find(q,1,true))
            or ((el._desc or ""):lower():find(q,1,true)) then
                self:_srchCard(el)
            end
        end
    end)

    return self
end

function UI:_destroy()
    for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    if self._gui then self._gui:Destroy() end
end

function UI:_srchCard(el)
    local card = mk("Frame", {
        Size = UDim2.new(1,0,0,46), BackgroundColor3 = C.card,
        BorderSizePixel = 0, ZIndex = 11,
    }, self._srchOverlay)
    rnd(card, 8); bdr(card, C.border, 1)

    lbl(el._name or "", C.text, 12, Enum.Font.GothamBold, card, {
        Size = UDim2.new(1,-100,0,16), Position = UDim2.new(0,10,0,6), ZIndex = 12,
    })
    lbl(el._desc ~= "" and el._desc or el._type, C.muted, 10, Enum.Font.Gotham, card, {
        Size = UDim2.new(1,-100,0,13), Position = UDim2.new(0,10,0,24), ZIndex = 12,
    })
    lbl(el._segName and (el._tabName.." › "..el._segName) or (el._tabName or ""), C.accent, 10, Enum.Font.Gotham, card, {
        Size = UDim2.new(0,90,1,0), Position = UDim2.new(1,-96,0,0),
        TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 12,
    })
end

-- ═══════════════════════════════════════════════════════════════════════════════
--  TAB
-- ═══════════════════════════════════════════════════════════════════════════════
function UI:Tab(name, icon)
    local td = setmetatable({ _name = name, _win = self }, { __index = Tab })

    local btnText = (icon and (icon.."  ") or "") .. name
    local tabBtn = mk("TextButton", {
        Size = UDim2.new(1,0,0,30),
        BackgroundColor3 = C.bg,
        Text = btnText, TextColor3 = C.muted,
        Font = Enum.Font.Gotham, TextSize = 12,
        BorderSizePixel = 0, AutoButtonColor = false,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
    }, self._tabList)
    rnd(tabBtn, 7)
    pad(tabBtn, 0,8,0,10)
    td._btn = tabBtn

    local scroll = mk("ScrollingFrame", {
        Size = UDim2.new(1,0,1,0),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent,
        CanvasSize = UDim2.new(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Visible = false, ZIndex = 4,
    }, self._contentArea)
    pad(scroll, 14, 14, 14, 14)
    lst(scroll, Enum.FillDirection.Vertical, 16)
    td._scroll = scroll

    tabBtn.MouseButton1Click:Connect(function() self:_selectTab(td) end)
    table.insert(self._tabs, td)
    if #self._tabs == 1 then self:_selectTab(td) end

    return td
end

function UI:_selectTab(t)
    self._activeTab = t
    for _, tab in ipairs(self._tabs) do
        local a = (tab == t)
        tab._btn.BackgroundColor3 = a and C.border  or C.bg
        tab._btn.TextColor3       = a and C.text    or C.muted
        tab._btn.Font             = a and Enum.Font.GothamBold or Enum.Font.Gotham
        tab._scroll.Visible       = a
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
--  SEGMENT
-- ═══════════════════════════════════════════════════════════════════════════════
function Tab:Segment(name)
    local seg = setmetatable({
        _name = name, _tab = self, _win = self._win,
    }, { __index = Segment })

    -- just a label header, no background frame
    local wrapper = mk("Frame", {
        Size = UDim2.new(1,0,0,0),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 5,
    }, self._scroll)
    lst(wrapper, Enum.FillDirection.Vertical, 6)

    -- segment title
    lbl(name:upper(), C.muted, 10, Enum.Font.GothamBold, wrapper, {
        Size = UDim2.new(1,0,0,14), ZIndex = 6,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    -- thin accent line beneath title
    mk("Frame", {
        Size = UDim2.new(1,0,0,1), BackgroundColor3 = C.border,
        BorderSizePixel = 0, ZIndex = 6,
    }, wrapper)

    -- element container
    local content = mk("Frame", {
        Size = UDim2.new(1,0,0,0),
        BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0, ZIndex = 6,
    }, wrapper)
    lst(content, Enum.FillDirection.Vertical, 2)
    seg._content = content
    seg._wrapper = wrapper

    return seg
end

-- ── Element helpers ───────────────────────────────────────────────────────────
local function eRow(parent, h)
    return mk("Frame", {
        Size = UDim2.new(1,0,0,h), BackgroundTransparency = 1,
        BorderSizePixel = 0, ZIndex = 7,
    }, parent)
end

local function eNames(row, name, desc, h)
    -- name always on the left, vertically centered for simple rows
    local ny = desc ~= "" and 4 or math.floor(h/2)-8
    lbl(name, C.text, 13, Enum.Font.Gotham, row, {
        Size = UDim2.new(LBLW,0,0,17),
        Position = UDim2.new(0,0,0,ny), ZIndex = 8,
    })
    if desc ~= "" then
        lbl(desc, C.muted, 10, Enum.Font.Gotham, row, {
            Size = UDim2.new(LBLW,0,0,13),
            Position = UDim2.new(0,0,0,22), ZIndex = 8,
        })
    end
end

local function regEl(seg, name, desc, etype)
    local el = {
        _name = name, _desc = desc or "", _type = etype,
        _tabName = seg._tab._name, _segName = seg._name,
    }
    table.insert(seg._win._elements, el)
    return el
end

-- ═══════════════════════════════════════════════════════════════════════════════
--  BUTTON
-- ═══════════════════════════════════════════════════════════════════════════════
function Segment:Button(name, opts, cb)
    if type(opts) == "function" then cb = opts; opts = {} end
    opts = opts or {}
    local desc = opts.Description or ""
    local h    = desc ~= "" and EHD or EH
    local el   = regEl(self, name, desc, "Button")

    local row = eRow(self._content, h)
    eNames(row, name, desc, h)

    local W = 84
    local btn = mk("TextButton", {
        Size = UDim2.new(0,W,0,26),
        Position = UDim2.new(1,-W-ERPAD, 0.5,-13),
        BackgroundColor3 = C.accent,
        Text = opts.Label or "Run", TextColor3 = C.white,
        Font = Enum.Font.GothamBold, TextSize = 12,
        BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 8,
    }, row)
    rnd(btn, 6)
    btn.MouseEnter:Connect(function() tw(btn,{BackgroundColor3=C.blue},.1) end)
    btn.MouseLeave:Connect(function() tw(btn,{BackgroundColor3=C.accent},.1) end)
    btn.MouseButton1Click:Connect(function()
        tw(btn,{Size=UDim2.new(0,W-4,0,23)},.05)
        task.wait(.05)
        tw(btn,{Size=UDim2.new(0,W,0,26)},.05)
        if cb then task.spawn(cb) end
    end)
    el._instance = btn
    return el
end

-- ═══════════════════════════════════════════════════════════════════════════════
--  HOLD BUTTON
-- ═══════════════════════════════════════════════════════════════════════════════
function Segment:HoldButton(name, opts, cb)
    if type(opts) == "function" then cb = opts; opts = {} end
    opts = opts or {}
    local desc     = opts.Description or ""
    local holdTime = opts.HoldTime or 1.5
    local h        = desc ~= "" and EHD or EH
    local el       = regEl(self, name, desc, "HoldButton")

    local row = eRow(self._content, h)
    eNames(row, name, desc, h)

    local W = 84
    local btn = mk("TextButton", {
        Size = UDim2.new(0,W,0,26),
        Position = UDim2.new(1,-W-ERPAD,0.5,-13),
        BackgroundColor3 = C.card2,
        Text = "Hold", TextColor3 = C.sub,
        Font = Enum.Font.GothamBold, TextSize = 12,
        ClipsDescendants = true,
        BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 8,
    }, row)
    rnd(btn, 6); bdr(btn, C.border, 1)

    local fill = mk("Frame", {
        Size = UDim2.new(0,0,1,0),
        BackgroundColor3 = C.accent, BorderSizePixel = 0, ZIndex = 7,
    }, btn)
    rnd(fill, 6)
    mk("UIGradient",{Color=ColorSequence.new(C.accent,C.blue),Rotation=0},fill)

    local held, hConn = false, nil
    btn.InputBegan:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        held = true
        local t0 = tick()
        hConn = Run.Heartbeat:Connect(function()
            if not held then hConn:Disconnect(); return end
            local p = math.min((tick()-t0)/holdTime,1)
            fill.Size = UDim2.new(p,0,1,0)
            if p >= 1 then
                held=false; hConn:Disconnect()
                tw(fill,{Size=UDim2.new(0,0,1,0)},.15)
                if cb then task.spawn(cb) end
            end
        end)
    end)
    btn.InputEnded:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        held = false
        tw(fill,{Size=UDim2.new(0,0,1,0)},.15)
    end)
    el._instance = btn
    return el
end

-- ═══════════════════════════════════════════════════════════════════════════════
--  TOGGLE
-- ═══════════════════════════════════════════════════════════════════════════════
function Segment:Toggle(name, opts, cb)
    if type(opts) == "function" then cb = opts; opts = {} end
    opts = opts or {}
    local desc     = opts.Description or ""
    local default  = opts.Default ~= false
    local bindable = opts.Bindable == true
    local h        = desc ~= "" and EHD or EH
    local el       = regEl(self, name, desc, "Toggle")
    el._value      = default

    local row = eRow(self._content, h)
    eNames(row, name, desc, h)

    local PW, PH = 36, 20
    -- if bindable, shift pill left to make room for bind button
    local pillRX = bindable and (PW + 32 + ERPAD*2) or (PW + ERPAD)
    local pill = mk("Frame", {
        Size = UDim2.new(0,PW,0,PH),
        Position = UDim2.new(1,-pillRX,0.5,-PH/2),
        BackgroundColor3 = default and C.accent or C.border,
        BorderSizePixel = 0, ZIndex = 8,
    }, row)
    rnd(pill, 99)

    local KS = 14
    local knob = mk("Frame", {
        Size = UDim2.new(0,KS,0,KS),
        Position = UDim2.new(0, default and PW-KS-3 or 3, 0.5, -KS/2),
        BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 9,
    }, pill)
    rnd(knob, 99)

    local function setState(v, fire)
        el._value = v
        tw(pill, {BackgroundColor3 = v and C.accent or C.border}, .14)
        tw(knob, {Position=UDim2.new(0, v and PW-KS-3 or 3, 0.5, -KS/2)}, .14)
        if fire and cb then task.spawn(cb, v) end
    end
    el._setValue = setState

    mk("TextButton", {
        Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, Text="", ZIndex=10,
    }, pill).MouseButton1Click:Connect(function() setState(not el._value, true) end)

    if bindable then
        local boundKey = nil
        local bBtn = mk("TextButton", {
            Size = UDim2.new(0,28,0,20),
            Position = UDim2.new(1,-ERPAD-28,0.5,-10),
            BackgroundColor3 = C.card2,
            Text = "–", TextColor3 = C.muted,
            Font = Enum.Font.Code, TextSize = 10,
            BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 8,
        }, row)
        rnd(bBtn, 5); bdr(bBtn, C.border, 1)

        local listening = false
        bBtn.MouseButton1Click:Connect(function()
            if listening then return end
            listening = true; bBtn.Text = "…"; bBtn.TextColor3 = C.yellow
            local c; c = UIS.InputBegan:Connect(function(i, gp)
                if gp or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
                boundKey = i.KeyCode
                bBtn.Text = i.KeyCode.Name:sub(1,5)
                bBtn.TextColor3 = C.accent
                listening = false; c:Disconnect()
            end)
        end)
        local bc = UIS.InputBegan:Connect(function(i, gp)
            if gp then return end
            if boundKey and i.KeyCode == boundKey then setState(not el._value, true) end
        end)
        table.insert(self._win._conns, bc)
    end

    el._instance = pill
    return el
end

-- ═══════════════════════════════════════════════════════════════════════════════
--  SLIDER
-- ═══════════════════════════════════════════════════════════════════════════════
function Segment:Slider(name, opts, cb)
    if type(opts) == "function" then cb = opts; opts = {} end
    opts = opts or {}
    local desc    = opts.Description or ""
    local mn      = opts.Min or 0
    local mx      = opts.Max or 100
    local def     = math.clamp(opts.Default or mn, mn, mx)
    local suffix  = opts.Suffix or ""
    local el      = regEl(self, name, desc, "Slider")
    el._value     = def

    local h  = desc ~= "" and 56 or 44
    local row = eRow(self._content, h)

    -- name (left) + value (right)
    lbl(name, C.text, 13, Enum.Font.Gotham, row, {
        Size = UDim2.new(LBLW,0,0,17), Position = UDim2.new(0,0,0,2), ZIndex = 8,
    })
    if desc ~= "" then
        lbl(desc, C.muted, 10, Enum.Font.Gotham, row, {
            Size = UDim2.new(1,0,0,13), Position = UDim2.new(0,0,0,20), ZIndex = 8,
        })
    end
    local valLbl = lbl(def..suffix, C.accent, 12, Enum.Font.Code, row, {
        Size = UDim2.new(1-LBLW,-ERPAD,0,17),
        Position = UDim2.new(LBLW,0,0,2),
        TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 8,
    })

    local track = mk("Frame", {
        Size = UDim2.new(1,-ERPAD,0,6),
        Position = UDim2.new(0,0,1,-10),
        BackgroundColor3 = C.border, BorderSizePixel = 0, ZIndex = 8,
    }, row)
    rnd(track, 99)

    local p0 = (def-mn)/(mx-mn)
    local fill = mk("Frame", {
        Size = UDim2.new(p0,0,1,0),
        BackgroundColor3 = C.accent, BorderSizePixel = 0, ZIndex = 9,
    }, track)
    rnd(fill, 99)
    mk("UIGradient",{Color=ColorSequence.new(C.accent,C.blue),Rotation=0},fill)

    local thumb = mk("Frame", {
        Size = UDim2.new(0,14,0,14), AnchorPoint = Vector2.new(.5,.5),
        Position = UDim2.new(p0,0,.5,0),
        BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 10,
    }, track)
    rnd(thumb, 99); bdr(thumb, C.border, 1.5)

    local function set(pct)
        pct = math.clamp(pct, 0, 1)
        local v = math.floor(mn + pct*(mx-mn) + .5)
        el._value = v
        valLbl.Text = v..suffix
        fill.Size   = UDim2.new(pct,0,1,0)
        thumb.Position = UDim2.new(pct,0,.5,0)
        if cb then task.spawn(cb, v) end
    end
    el._setValue = set

    local drag = false
    local function onPos(px)
        set((px - track.AbsolutePosition.X) / track.AbsoluteSize.X)
    end
    track.InputBegan:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        drag = true; onPos(i.Position.X)
    end)
    thumb.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
    end)
    UIS.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            onPos(i.Position.X)
        end
    end)
    el._instance = track
    return el
end

-- ═══════════════════════════════════════════════════════════════════════════════
--  INPUT
-- ═══════════════════════════════════════════════════════════════════════════════
function Segment:Input(name, opts, cb)
    if type(opts) == "function" then cb = opts; opts = {} end
    opts = opts or {}
    local desc    = opts.Description or ""
    local numeric = opts.Numeric == true
    local el      = regEl(self, name, desc, "Input")
    el._value     = opts.Default or ""

    local h   = desc ~= "" and 62 or 52
    local row = eRow(self._content, h)
    lbl(name, C.text, 13, Enum.Font.Gotham, row, {
        Size = UDim2.new(1,0,0,17), Position = UDim2.new(0,0,0,2), ZIndex = 8,
    })
    if desc ~= "" then
        lbl(desc, C.muted, 10, Enum.Font.Gotham, row, {
            Size = UDim2.new(1,0,0,13), Position = UDim2.new(0,0,0,20), ZIndex = 8,
        })
    end

    local by = desc ~= "" and 36 or 24
    local bg = mk("Frame", {
        Size = UDim2.new(1,-ERPAD,0,24), Position = UDim2.new(0,0,0,by),
        BackgroundColor3 = C.card2, BorderSizePixel = 0, ZIndex = 8,
    }, row)
    rnd(bg, 6)
    local st = bdr(bg, C.border, 1)
    pad(bg, 0,8,0,8)

    local box = mk("TextBox", {
        Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1,
        PlaceholderText = opts.Placeholder or "Enter value…",
        PlaceholderColor3 = C.muted, Text = el._value,
        TextColor3 = C.text, Font = Enum.Font.Code, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false, ZIndex = 9,
    }, bg)
    box.Focused:Connect(function()   st.Color = C.accent end)
    box.FocusLost:Connect(function()
        st.Color = C.border
        if numeric then
            local n = tonumber(box.Text)
            box.Text = n and tostring(n) or ""
        end
        el._value = box.Text
        if cb then task.spawn(cb, el._value) end
    end)
    box:GetPropertyChangedSignal("Text"):Connect(function() el._value = box.Text end)
    el._instance = box
    return el
end

-- ═══════════════════════════════════════════════════════════════════════════════
--  DROPDOWN  (single & multi)
-- ═══════════════════════════════════════════════════════════════════════════════
function Segment:Dropdown(name, opts, cb)
    if type(opts) == "function" then cb = opts; opts = {} end
    opts = opts or {}
    local desc    = opts.Description or ""
    local options = opts.Options or {}
    local multi   = opts.Multi == true
    local el      = regEl(self, name, desc, multi and "MultiDropdown" or "Dropdown")
    el._value     = multi and {} or (opts.Default or options[1])

    local h   = desc ~= "" and 60 or 50
    local row = eRow(self._content, h)
    lbl(name, C.text, 13, Enum.Font.Gotham, row, {
        Size = UDim2.new(1,0,0,17), Position = UDim2.new(0,0,0,2), ZIndex = 8,
    })
    if desc ~= "" then
        lbl(desc, C.muted, 10, Enum.Font.Gotham, row, {
            Size = UDim2.new(1,0,0,13), Position = UDim2.new(0,0,0,20), ZIndex = 8,
        })
    end

    local dy = desc ~= "" and 36 or 24
    local ddBtn = mk("TextButton", {
        Size = UDim2.new(1,-ERPAD,0,24), Position = UDim2.new(0,0,0,dy),
        BackgroundColor3 = C.card2, Text = "",
        BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 8,
    }, row)
    rnd(ddBtn, 6); bdr(ddBtn, C.border, 1)
    pad(ddBtn, 0,22,0,8)

    local ddLbl = lbl(multi and "Select…" or (el._value or "Select…"), C.text, 12, Enum.Font.Gotham, ddBtn, {
        Size = UDim2.new(1,0,1,0), ZIndex = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    lbl("▾", C.muted, 11, Enum.Font.GothamBold, ddBtn, {
        Size = UDim2.new(0,18,1,0), Position = UDim2.new(1,-18,0,0),
        TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9,
    })

    local function updateLbl()
        if multi then
            local sel = {}
            for k,v in pairs(el._value) do if v then table.insert(sel,k) end end
            ddLbl.Text = #sel > 0 and table.concat(sel,", ") or "Select…"
        else
            ddLbl.Text = el._value or "Select…"
        end
    end

    local open, listFr, outsideConn = false, nil, nil

    local function closeList()
        if listFr then listFr:Destroy(); listFr = nil end
        if outsideConn then outsideConn:Disconnect(); outsideConn = nil end
        open = false
    end

    ddBtn.MouseButton1Click:Connect(function()
        if open then closeList(); return end
        open = true
        local ap   = ddBtn.AbsolutePosition
        local as   = ddBtn.AbsoluteSize
        local IH   = 26
        local LH   = math.min(#options * IH, 150)

        listFr = mk("Frame", {
            Size = UDim2.new(0,as.X,0,LH),
            Position = UDim2.new(0,ap.X,0,ap.Y+as.Y+3),
            BackgroundColor3 = C.card2, BorderSizePixel = 0, ZIndex = 50,
        }, self._win._gui)
        rnd(listFr, 7); bdr(listFr, C.border, 1)

        local ls = mk("ScrollingFrame", {
            Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1,
            BorderSizePixel = 0, ScrollBarThickness = 2,
            ScrollBarImageColor3 = C.accent,
            CanvasSize = UDim2.new(0,0,0,#options*IH), ZIndex = 51,
        }, listFr)

        for i, opt in ipairs(options) do
            local isSel = multi and el._value[opt] or (el._value == opt)
            local item = mk("TextButton", {
                Size = UDim2.new(1,0,0,IH), Position = UDim2.new(0,0,0,(i-1)*IH),
                BackgroundColor3 = isSel and Color3.fromRGB(26,20,50) or C.card2,
                Text = "", BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 52,
            }, ls)
            pad(item, 0,8,0,10)

            local itxt = lbl(tostring(opt), isSel and C.accent or C.sub, 12, Enum.Font.Gotham, item, {
                Size = UDim2.new(1, multi and -22 or 0, 1, 0), ZIndex = 53,
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            local chk
            if multi then
                chk = lbl(isSel and "✓" or "", C.green, 11, Enum.Font.GothamBold, item, {
                    Size = UDim2.new(0,18,1,0), Position = UDim2.new(1,-20,0,0),
                    TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 53,
                })
            end
            item.MouseEnter:Connect(function() tw(item,{BackgroundColor3=C.border},.08) end)
            item.MouseLeave:Connect(function()
                local s = multi and el._value[opt] or (el._value==opt)
                tw(item,{BackgroundColor3=s and Color3.fromRGB(26,20,50) or C.card2},.08)
            end)
            if multi then
                item.MouseButton1Click:Connect(function()
                    el._value[opt] = not el._value[opt]
                    if chk then chk.Text = el._value[opt] and "✓" or "" end
                    itxt.TextColor3 = el._value[opt] and C.accent or C.sub
                    item.BackgroundColor3 = el._value[opt] and Color3.fromRGB(26,20,50) or C.card2
                    updateLbl()
                    if cb then task.spawn(cb, el._value) end
                end)
            else
                item.MouseButton1Click:Connect(function()
                    el._value = opt; updateLbl(); closeList()
                    if cb then task.spawn(cb, opt) end
                end)
            end
        end

        -- close on outside click
        outsideConn = UIS.InputBegan:Connect(function(i)
            if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            if not listFr then return end
            local mp  = UIS:GetMouseLocation()
            local la  = listFr.AbsolutePosition
            local ls2 = listFr.AbsoluteSize
            if mp.X<la.X or mp.X>la.X+ls2.X or mp.Y<la.Y or mp.Y>la.Y+ls2.Y then
                closeList()
            end
        end)
    end)

    el._instance = ddBtn
    return el
end

function Segment:MultiDropdown(name, opts, cb)
    opts = opts or {}; opts.Multi = true
    return self:Dropdown(name, opts, cb)
end

-- ═══════════════════════════════════════════════════════════════════════════════
--  COLOR PICKER
-- ═══════════════════════════════════════════════════════════════════════════════
function Segment:ColorPicker(name, opts, cb)
    if type(opts) == "function" then cb = opts; opts = {} end
    opts = opts or {}
    local desc    = opts.Description or ""
    local default = opts.Default or C.accent
    local el      = regEl(self, name, desc, "ColorPicker")
    el._value     = default

    local h   = desc ~= "" and EHD or EH
    local row = eRow(self._content, h)
    eNames(row, name, desc, h)

    local swatch = mk("TextButton", {
        Size = UDim2.new(0,32,0,20),
        Position = UDim2.new(1,-32-ERPAD,0.5,-10),
        BackgroundColor3 = default, Text = "",
        BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 8,
    }, row)
    rnd(swatch, 5); bdr(swatch, C.border, 1)

    local h_h, s_h, v_h = Color3.toHSV(default)
    local pickerFr, pickerOpen, outsideConn2 = nil, false, nil
    local SV = 156

    local function toHex(c)
        return ("#%02X%02X%02X"):format(c.R*255, c.G*255, c.B*255)
    end

    local function buildPicker()
        local ap  = swatch.AbsolutePosition
        local as2 = swatch.AbsoluteSize
        local vp  = workspace.CurrentCamera.ViewportSize
        local PW  = 196
        local px  = math.min(ap.X + as2.X - PW, vp.X - PW - 8)

        pickerFr = mk("Frame", {
            Size = UDim2.new(0,PW,0,226),
            Position = UDim2.new(0,px,0,ap.Y+as2.Y+6),
            BackgroundColor3 = C.card, BorderSizePixel = 0, ZIndex = 60,
        }, self._win._gui)
        rnd(pickerFr, 10); bdr(pickerFr, C.border, 1)
        pad(pickerFr, 10,10,10,10)

        -- SV box
        local svBox = mk("ImageLabel", {
            Size = UDim2.new(0,SV,0,SV),
            BackgroundColor3 = Color3.fromHSV(h_h,1,1),
            Image = "rbxassetid://4155801252",
            ZIndex = 61,
        }, pickerFr)
        rnd(svBox, 5)

        local svThumb = mk("Frame", {
            Size = UDim2.new(0,10,0,10), AnchorPoint = Vector2.new(.5,.5),
            Position = UDim2.new(s_h,0,1-v_h,0),
            BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 63,
        }, svBox)
        rnd(svThumb, 99); bdr(svThumb, C.border, 1.5)

        -- hue bar
        local hBar = mk("ImageLabel", {
            Size = UDim2.new(0,SV,0,12),
            Position = UDim2.new(0,0,0,SV+10),
            Image = "rbxassetid://698052001",
            BackgroundTransparency = 1, ZIndex = 61,
        }, pickerFr)
        rnd(hBar, 4)

        local hThumb = mk("Frame", {
            Size = UDim2.new(0,4,0,12), AnchorPoint = Vector2.new(.5,0),
            Position = UDim2.new(h_h,0,0,0),
            BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 62,
        }, hBar)
        rnd(hThumb, 3); bdr(hThumb, C.border, 1)

        -- hex input
        local hexBg = mk("Frame", {
            Size = UDim2.new(0,SV,0,22),
            Position = UDim2.new(0,0,0,SV+28),
            BackgroundColor3 = C.card2, BorderSizePixel = 0, ZIndex = 61,
        }, pickerFr)
        rnd(hexBg, 5)
        local hexSt = bdr(hexBg, C.border, 1)
        pad(hexBg, 0,6,0,6)
        local hexBox = mk("TextBox", {
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
                    h_h,s_h,v_h = nh,ns,nv
                    local col = Color3.fromRGB(r,g,b)
                    el._value = col; swatch.BackgroundColor3 = col
                    svBox.BackgroundColor3 = Color3.fromHSV(nh,1,1)
                    svThumb.Position = UDim2.new(ns,0,1-nv,0)
                    hThumb.Position  = UDim2.new(nh,0,0,0)
                    if cb then task.spawn(cb,col) end
                end
            end
        end)

        local function apply(nh,ns,nv)
            h_h,s_h,v_h = nh,ns,nv
            local col = Color3.fromHSV(nh,ns,nv)
            el._value = col; swatch.BackgroundColor3 = col
            svBox.BackgroundColor3 = Color3.fromHSV(nh,1,1)
            svThumb.Position = UDim2.new(ns,0,1-nv,0)
            hThumb.Position  = UDim2.new(nh,0,0,0)
            hexBox.Text = toHex(col)
            if cb then task.spawn(cb,col) end
        end

        -- sv drag
        local svD = false
        svBox.InputBegan:Connect(function(i)
            if i.UserInputType~=Enum.UserInputType.MouseButton1 then return end
            svD=true
            local rel=i.Position-svBox.AbsolutePosition
            apply(h_h,math.clamp(rel.X/SV,0,1),1-math.clamp(rel.Y/SV,0,1))
        end)
        UIS.InputEnded:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1 then svD=false end
        end)
        UIS.InputChanged:Connect(function(i)
            if svD and i.UserInputType==Enum.UserInputType.MouseMovement then
                local rel=i.Position-svBox.AbsolutePosition
                apply(h_h,math.clamp(rel.X/SV,0,1),1-math.clamp(rel.Y/SV,0,1))
            end
        end)

        -- hue drag
        local hD = false
        hBar.InputBegan:Connect(function(i)
            if i.UserInputType~=Enum.UserInputType.MouseButton1 then return end
            hD=true
            apply(math.clamp((i.Position.X-hBar.AbsolutePosition.X)/SV,0,1),s_h,v_h)
        end)
        UIS.InputEnded:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1 then hD=false end
        end)
        UIS.InputChanged:Connect(function(i)
            if hD and i.UserInputType==Enum.UserInputType.MouseMovement then
                apply(math.clamp((i.Position.X-hBar.AbsolutePosition.X)/SV,0,1),s_h,v_h)
            end
        end)

        outsideConn2 = UIS.InputBegan:Connect(function(i)
            if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            if not pickerFr then return end
            local mp = UIS:GetMouseLocation()
            local pa = pickerFr.AbsolutePosition
            local ps = pickerFr.AbsoluteSize
            if mp.X<pa.X or mp.X>pa.X+ps.X or mp.Y<pa.Y or mp.Y>pa.Y+ps.Y then
                pickerFr:Destroy(); pickerFr=nil; pickerOpen=false
                if outsideConn2 then outsideConn2:Disconnect() end
            end
        end)
    end

    swatch.MouseButton1Click:Connect(function()
        if pickerOpen then
            if pickerFr then pickerFr:Destroy(); pickerFr=nil end
            if outsideConn2 then outsideConn2:Disconnect() end
            pickerOpen = false
        else
            pickerOpen = true; buildPicker()
        end
    end)

    el._instance = swatch
    return el
end

-- ═══════════════════════════════════════════════════════════════════════════════
--  LABEL  (static text)
-- ═══════════════════════════════════════════════════════════════════════════════
function Segment:Label(text, color)
    lbl(text, color or C.muted, 12, Enum.Font.Gotham, self._content, {
        Size = UDim2.new(1,0,0,18), ZIndex = 7, TextWrapped = true,
    })
end

-- ═══════════════════════════════════════════════════════════════════════════════
--  UPTIME LABEL  (updates every second)
-- ═══════════════════════════════════════════════════════════════════════════════
function Segment:Uptime()
    local disp = lbl("Session: 0:00:00", C.muted, 12, Enum.Font.Code, self._content, {
        Size = UDim2.new(1,0,0,18), ZIndex = 7,
    })
    table.insert(self._win._uptimeFns, function(str) disp.Text = str end)
    return disp
end

-- ═══════════════════════════════════════════════════════════════════════════════
--  SETTINGS TAB
-- ═══════════════════════════════════════════════════════════════════════════════
function UI:SettingsTab()
    local tab = self:Tab("Settings", "⚙")
    local win = self

    local ui = tab:Segment("Interface")

    -- toggle UI key
    local tkEl = ui:Input("Toggle UI Key", {
        Placeholder = win._uiKey.Name, Default = win._uiKey.Name,
        Description = "Press Rebind then the new key.",
    })
    ui:Button("Rebind Toggle Key", { Label = "Rebind" }, function()
        tkEl._instance.Text = "Press a key…"
        local c; c = UIS.InputBegan:Connect(function(i, gp)
            if gp or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
            win._uiKey = i.KeyCode
            tkEl._instance.Text = i.KeyCode.Name
            c:Disconnect()
        end)
    end)

    -- panic key
    local pkEl = ui:Input("Panic Key", {
        Placeholder = win._panicKey.Name, Default = win._panicKey.Name,
        Description = "Instantly destroys the UI.",
    })
    ui:Button("Rebind Panic Key", { Label = "Rebind" }, function()
        pkEl._instance.Text = "Press a key…"
        local c; c = UIS.InputBegan:Connect(function(i, gp)
            if gp or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
            win._panicKey = i.KeyCode
            pkEl._instance.Text = i.KeyCode.Name
            c:Disconnect()
        end)
    end)

    ui:Toggle("Clamp UI to Screen", {
        Default = win._clamp,
        Description = "Prevents dragging off-screen.",
    }, function(v) win._clamp = v end)

    local misc = tab:Segment("Misc")
    misc:Uptime()
    misc:Button("Panic — Unload Everything", {
        Label = "Unload", Description = "Destroys the UI and stops all connections.",
    }, function() win:_destroy() end)

    return tab
end

-- ═══════════════════════════════════════════════════════════════════════════════
--  CONFIG TAB
-- ═══════════════════════════════════════════════════════════════════════════════
function UI:ConfigTab()
    local tab = self:Tab("Config", "💾")
    local seg = tab:Segment("Save & Load")
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
        return #out > 0 and out or {"(none)"}
    end

    local function serialize()
        local d = {}
        for _, el in ipairs(self._elements) do
            if el._name and el._value ~= nil then
                if typeof(el._value) == "Color3" then
                    d[el._name] = {r=el._value.R, g=el._value.G, b=el._value.B}
                else
                    d[el._name] = el._value
                end
            end
        end
        return Http:JSONEncode(d)
    end

    local function applyData(d)
        for _, el in ipairs(self._elements) do
            local v = d[el._name]; if v == nil then continue end
            if el._type == "Toggle" and el._setValue then
                el._setValue(v == true, true)
            elseif el._type == "Slider" and el._setValue then
                el._setValue(math.clamp(v/100, 0, 1))
            elseif el._type == "Input" and el._instance then
                el._instance.Text = tostring(v); el._value = v
            elseif (el._type == "Dropdown" or el._type == "MultiDropdown") then
                el._value = v
            elseif el._type == "ColorPicker" and el._instance and type(v) == "table" then
                local col = Color3.new(v.r or 1, v.g or 1, v.b or 1)
                el._value = col; el._instance.BackgroundColor3 = col
            end
        end
    end

    local nameEl  = seg:Input("Config Name", { Placeholder = "my_config", Default = "default" })
    local selEl   = seg:Dropdown("Select Config", { Options = listCfgs() })

    seg:Button("Save Config", { Label = "Save" }, function()
        local n = nameEl._value ~= "" and nameEl._value or "default"
        if writefile then pcall(writefile, DIR..n..".json", serialize()) end
    end)
    seg:Button("Load Config", { Label = "Load" }, function()
        local n = selEl._value
        if not n or n == "(none)" or not readfile then return end
        local ok, raw = pcall(readfile, DIR..n..".json")
        if not ok then return end
        local ok2, d = pcall(Http.JSONDecode, Http, raw)
        if ok2 and d then applyData(d) end
    end)
    seg:Button("Delete Config", { Label = "Delete" }, function()
        local n = selEl._value
        if n and n ~= "(none)" and delfile then pcall(delfile, DIR..n..".json") end
    end)

    return tab
end

return UI
