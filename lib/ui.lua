--[[
    Veltrix UI  •  v2.3
    Dark purple/blue theme. Compatible with Synapse X, KRNL, Fluxus, Script-Ware.
]]

local UI = {}
UI.__index = UI

local TweenSvc = game:GetService("TweenService")
local UIS      = game:GetService("UserInputService")
local Run      = game:GetService("RunService")
local Http     = game:GetService("HttpService")
local Plrs     = game:GetService("Players")
local lp       = Plrs.LocalPlayer

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

local WW    = 820
local WH    = 480
local SW    = 172
local HH    = 44
local EH    = 32
local EHD   = 46
local ERPAD = 8
local LBLW  = 0.60

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
    return mk("UIStroke", {
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

-- lbl: consistent Gotham family throughout, no Code font except hex picker
local function lbl(txt, col, sz, font, parent, props)
    props = props or {}
    props.BackgroundTransparency = 1
    props.Text       = txt
    props.TextColor3 = col or C.text
    props.Font       = font or Enum.Font.Gotham
    props.TextSize   = sz or 13
    if not props.Size then props.Size = UDim2.new(1,0,0,sz and sz+4 or 17) end
    props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
    props.ZIndex = props.ZIndex or 8
    return mk("TextLabel", props, parent)
end

local function guiParent()
    if gethui then return gethui() end
    local cg = game:GetService("CoreGui")
    local ok = pcall(function() mk("Folder",{},cg):Destroy() end)
    if ok then return cg end
    return lp:WaitForChild("PlayerGui")
end

-- Dragging: moves `target` (wrapper) via absolute position so initial centering
-- via Scale doesn't corrupt the offset math.
local function makeDraggable(target, handle, shouldClamp)
    local dragging, sp, sf = false, nil, nil
    handle.InputBegan:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        dragging = true
        sp = Vector2.new(i.Position.X, i.Position.Y)
        sf = target.AbsolutePosition
    end)
    handle.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UIS.InputChanged:Connect(function(i)
        if not dragging or i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local d  = Vector2.new(i.Position.X, i.Position.Y) - sp
        local nx = sf.X + d.X
        local ny = sf.Y + d.Y
        if shouldClamp and shouldClamp() then
            local vp = workspace.CurrentCamera.ViewportSize
            local fs = target.AbsoluteSize
            nx = math.clamp(nx, 0, math.max(0, vp.X - fs.X))
            ny = math.clamp(ny, 0, math.max(0, vp.Y - fs.Y))
        end
        target.Position = UDim2.new(0, nx, 0, ny)
    end)
end

local Tab     = {}; Tab.__index     = Tab
local Segment = {}; Segment.__index = Segment

-- =============================================================================
--  WINDOW
-- =============================================================================
function UI:Window(opts)
    opts = opts or {}
    local self = setmetatable({
        _tabs       = {},
        _elements   = {},
        _conns      = {},
        _visible    = true,
        _enlarged   = false,
        _clamp      = opts.ClampScreen ~= false,
        _resizable  = opts.Resizable  ~= false,
        _uiKey      = opts.ToggleKey or Enum.KeyCode.RightShift,
        _panicKey   = opts.PanicKey  or Enum.KeyCode.End,
        _startTime  = tick(),
        _key        = opts.Key or "",
        _notifStack = {},
        _resizeBtn  = nil,
    }, { __index = UI })

    for _, v in ipairs(guiParent():GetChildren()) do
        if v.Name == "VeltrixUI" then v:Destroy() end
    end

    local gui = mk("ScreenGui", {
        Name = "VeltrixUI", ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1000,
    }, guiParent())
    self._gui = gui

    -- Outer wrapper provides the 1px border by using its background colour.
    -- Using a wrapper+inner instead of UIStroke avoids square-corner artefacts
    -- that some executors produce when UIStroke meets UICorner.
    local normSz  = UDim2.new(0, WW+2, 0, WH+2)
    local normPos = UDim2.new(.5, -(WW+2)/2, .5, -(WH+2)/2)

    local wrapper = mk("Frame", {
        Size = normSz, Position = normPos, BackgroundTransparency = 1,
        BackgroundColor3 = C.border, BorderSizePixel = 0, ZIndex = 2,
        ClipsDescendants = true,
    }, gui)
    rnd(wrapper, 13)
    self._wrapper = wrapper

    -- UIScale lives on the wrapper so fullscreen mode scales all content.
    local uiScale = mk("UIScale", {Scale = 1}, wrapper)
    self._uiScale = uiScale

    -- frame has no UICorner: all rounded-corner clipping is delegated to wrapper
    -- (ClipsDescendants + UICorner r=13). Frame clips its children to a rectangle;
    -- wrapper then clips the whole lot to the rounded shape. One reliable clip layer.
    local frame = mk("Frame", {
        Size = UDim2.new(1,-2,1,-2), Position = UDim2.new(0,1,0,1),
        BackgroundColor3 = C.bg, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 2,
    }, wrapper)
    self._frame = frame

    -- Full-width accent line; ClipsDescendants on `frame` rounds its corners naturally.
    mk("Frame", {
        Size = UDim2.new(1,0,0,2), Position = UDim2.new(0,0,0,0),
        BackgroundColor3 = C.accent, BorderSizePixel = 0, ZIndex = 3,
    }, frame)

    -- Header
    local hdr = mk("Frame", {
        Size = UDim2.new(1,0,0,HH), Position = UDim2.new(0,0,0,2),
        BackgroundColor3 = C.bg, BorderSizePixel = 0, ZIndex = 3, Active = true,
    }, frame)

    local dot = mk("Frame", {
        Size = UDim2.new(0,6,0,6), Position = UDim2.new(0,16,0.5,-3),
        BackgroundColor3 = C.accent, BorderSizePixel = 0, ZIndex = 4,
    }, hdr)
    rnd(dot, 99)

    lbl(opts.Title or "Veltrix", C.text, 14, Enum.Font.GothamBold, hdr, {
        Size = UDim2.new(0,140,0,20), Position = UDim2.new(0,28,0.5,-10), ZIndex = 4,
    })

    local ctrlFrame = mk("Frame", {
        Size = UDim2.new(0,64,0,26), Position = UDim2.new(1,-72,0.5,-13),
        BackgroundTransparency = 1, ZIndex = 4,
    }, hdr)
    lst(ctrlFrame, Enum.FillDirection.Horizontal, 4)

    local function ctrlBtn(sym, col)
        local b = mk("TextButton", {
            Size = UDim2.new(0,28,0,26), BackgroundColor3 = C.card2,
            Text = sym, TextColor3 = col or C.sub,
            Font = Enum.Font.GothamBold, TextSize = 13,
            BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 5,
        }, ctrlFrame)
        rnd(b, 6); bdr(b, C.border, 1)
        b.MouseEnter:Connect(function() tw(b,{BackgroundColor3=C.border},.1) end)
        b.MouseLeave:Connect(function() tw(b,{BackgroundColor3=C.card2},.1) end)
        return b
    end

    local enlargeBtn = ctrlBtn("+", C.sub)
    local closeBtn   = ctrlBtn("x", C.red)

    mk("Frame", {
        Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,1,-1),
        BackgroundColor3 = C.border, BorderSizePixel = 0, ZIndex = 4,
    }, hdr)

    -- Drag moves the outer wrapper, not the inner frame.
    makeDraggable(wrapper, hdr, function() return self._clamp and not self._enlarged end)

    -- Sidebar
    local sbY = HH + 2
    local sbH = WH - sbY
    local sidebar = mk("Frame", {
        Size = UDim2.new(0,SW,0,sbH), Position = UDim2.new(0,0,0,sbY),
        BackgroundColor3 = C.sidebar, BorderSizePixel = 0, ZIndex = 3,
    }, frame)
    mk("Frame", {
        Size = UDim2.new(0,1,0,sbH), Position = UDim2.new(0,SW,0,sbY),
        BackgroundColor3 = C.border, BorderSizePixel = 0, ZIndex = 3,
    }, frame)

    -- User card
    local uCard = mk("Frame", {
        Size = UDim2.new(1,0,0,76),
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4,
    }, sidebar)
    pad(uCard, 12,10,0,12)

    local avWrap = mk("Frame", {
        Size = UDim2.new(0,34,0,34), BackgroundColor3 = C.border,
        BorderSizePixel = 0, ZIndex = 5,
    }, uCard)
    rnd(avWrap, 99)
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

    lbl(lp.DisplayName, C.text, 12, Enum.Font.GothamBold, uCard, {
        Size = UDim2.new(1,-42,0,15), Position = UDim2.new(0,42,0,2), ZIndex = 5,
    })
    lbl("@"..lp.Name, C.muted, 10, Enum.Font.Gotham, uCard, {
        Size = UDim2.new(1,-42,0,13), Position = UDim2.new(0,42,0,18), ZIndex = 5,
    })
    local keyLbl = lbl("Key: ...", C.muted, 10, Enum.Font.Gotham, uCard, {
        Size = UDim2.new(1,0,0,13), Position = UDim2.new(0,0,0,38), ZIndex = 5,
    })

    if self._key ~= "" then
        task.spawn(function()
            local ok, raw = pcall(Http.GetAsync, Http,
                "https://veltrix-worker.matjias.workers.dev/validate?key="..Http:UrlEncode(self._key))
            if ok then
                local ok2, data = pcall(Http.JSONDecode, Http, raw)
                if ok2 and data and data.valid then
                    local h = math.floor(data.ttl/3600)
                    local m = math.floor(data.ttl%3600/60)
                    keyLbl.Text = ("Key: %dh %dm"):format(h,m)
                    keyLbl.TextColor3 = C.green
                else
                    keyLbl.Text = "Key: expired"; keyLbl.TextColor3 = C.red
                end
            else
                keyLbl.Text = "Key: offline"
            end
        end)
    else
        keyLbl.Text = "Key: not set"
    end

    mk("Frame", {
        Size = UDim2.new(1,-20,0,1), Position = UDim2.new(0,10,0,76),
        BackgroundColor3 = C.border, BorderSizePixel = 0, ZIndex = 4,
    }, sidebar)

    local tabList = mk("Frame", {
        Size = UDim2.new(1,0,1,-84), Position = UDim2.new(0,0,0,84),
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4,
    }, sidebar)
    pad(tabList, 4,6,6,6)
    lst(tabList, Enum.FillDirection.Vertical, 2)
    self._tabList = tabList

    -- Content area
    local cX = SW + 1
    local cW = WW - cX
    local cY = sbY
    local cH = WH - cY

    local srchH = 36
    local srchBar = mk("Frame", {
        Size = UDim2.new(0,cW,0,srchH), Position = UDim2.new(0,cX,0,cY),
        BackgroundColor3 = C.bg, BorderSizePixel = 0, ZIndex = 3,
    }, frame)
    local srchBox = mk("TextBox", {
        Size = UDim2.new(1,-16,1,-10), Position = UDim2.new(0,10,0,5),
        BackgroundTransparency = 1,
        PlaceholderText = "Search elements...", PlaceholderColor3 = C.muted,
        Text = "", TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false, ZIndex = 4,
    }, srchBar)
    mk("Frame", {
        Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,1,-1),
        BackgroundColor3 = C.border, BorderSizePixel = 0, ZIndex = 4,
    }, srchBar)
    self._srchBox = srchBox

    local contentArea = mk("Frame", {
        Size = UDim2.new(0,cW,0,cH-srchH), Position = UDim2.new(0,cX,0,cY+srchH),
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3,
        ClipsDescendants = true,
    }, frame)
    self._contentArea = contentArea

    local srchOverlay = mk("ScrollingFrame", {
        Size = UDim2.new(1,0,1,0), BackgroundColor3 = C.bg,
        BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent,
        CanvasSize = UDim2.new(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false, ZIndex = 10,
    }, contentArea)
    pad(srchOverlay, 10,10,10,10)
    lst(srchOverlay, Enum.FillDirection.Vertical, 4)
    self._srchOverlay = srchOverlay

    -- Controls
    local function setVis(v)
        self._visible = v
        wrapper.Visible = v
        if self._resizeBtn then self._resizeBtn.Visible = v end
    end

    -- No gp check on keyboard so modifier keys like RightShift work as toggle.
    local kc = UIS.InputBegan:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if i.KeyCode == self._uiKey   then setVis(not self._visible) end
        if i.KeyCode == self._panicKey then self:_destroy() end
    end)
    table.insert(self._conns, kc)

    -- Fullscreen: scale content via UIScale so layout proportions are preserved.
    -- ViewportSize includes the Roblox top bar; subtract GuiInset so the UI
    -- fits within the ScreenGui's usable coordinate space (y=0 is below the bar).
    enlargeBtn.MouseButton1Click:Connect(function()
        self._enlarged = not self._enlarged
        if self._enlarged then
            self._preFS = wrapper.Position
            local vp     = workspace.CurrentCamera.ViewportSize
            local inset  = game:GetService("GuiService"):GetGuiInset()
            local availW = vp.X
            local availH = vp.Y - inset.Y
            local s      = math.min(availW / (WW+2), availH / (WH+2))
            uiScale.Scale = s
            local sw = math.floor((WW+2)*s + .5)
            local sh = math.floor((WH+2)*s + .5)
            wrapper.Position = UDim2.new(0,
                math.floor((availW - sw) / 2), 0,
                math.floor((availH - sh) / 2))
            enlargeBtn.Text = "-"
            if self._resizeBtn then self._resizeBtn.Visible = false end
        else
            uiScale.Scale = 1
            wrapper.Position = self._preFS or normPos
            enlargeBtn.Text = "+"
            if self._resizeBtn then self._resizeBtn.Visible = self._visible end
        end
    end)

    closeBtn.MouseButton1Click:Connect(function() setVis(false) end)

    -- Uptime
    self._uptimeFns = {}
    local uc = Run.Heartbeat:Connect(function()
        local e = tick() - self._startTime
        local str = ("Session: %d:%02d:%02d"):format(
            math.floor(e/3600), math.floor(e%3600/60), math.floor(e%60))
        for _, fn in ipairs(self._uptimeFns) do fn(str) end
    end)
    table.insert(self._conns, uc)

    -- Search with click-to-navigate
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

    -- Resize handle — child of gui (ScreenGui), not wrapper, so ClipsDescendants
    -- doesn't clip it. A Heartbeat connection keeps it glued to wrapper's corner.
    if self._resizable then
        local RS = 16
        local resizeBtn = mk("TextButton", {
            Size = UDim2.new(0, RS, 0, RS),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundColor3 = C.card2, Text = "",
            ZIndex = 70, BorderSizePixel = 0, AutoButtonColor = false,
        }, gui)
        rnd(resizeBtn, 5); bdr(resizeBtn, C.border, 1)
        -- Three-dot diagonal grip
        for di = 1, 3 do
            mk("Frame", {
                Size = UDim2.new(0, 2, 0, 2),
                Position = UDim2.new(0, 3+(di-1)*4, 0, RS-5-(di-1)*4),
                BackgroundColor3 = C.muted, BorderSizePixel = 0, ZIndex = 71,
            }, resizeBtn)
        end
        resizeBtn.MouseEnter:Connect(function() tw(resizeBtn,{BackgroundColor3=C.border},.1) end)
        resizeBtn.MouseLeave:Connect(function() tw(resizeBtn,{BackgroundColor3=C.card2},.1) end)
        self._resizeBtn = resizeBtn

        -- Track corner position every frame
        local rbHB; rbHB = Run.Heartbeat:Connect(function()
            if not wrapper.Parent then rbHB:Disconnect(); return end
            local ap = wrapper.AbsolutePosition
            local as = wrapper.AbsoluteSize
            resizeBtn.Position = UDim2.new(0, ap.X + as.X - RS/2, 0, ap.Y + as.Y - RS/2)
        end)
        table.insert(self._conns, rbHB)

        local resizing, rAnchor = false, nil
        resizeBtn.InputBegan:Connect(function(i)
            if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            resizing = true
            rAnchor  = wrapper.AbsolutePosition
        end)
        resizeBtn.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then resizing = false end
        end)
        local rsConn = UIS.InputChanged:Connect(function(i)
            if not resizing or i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            local mp = Vector2.new(i.Position.X, i.Position.Y)
            local sx = (mp.X - rAnchor.X) / (WW + 2)
            local sy = (mp.Y - rAnchor.Y) / (WH + 2)
            uiScale.Scale = math.clamp((sx + sy) * 0.5, 0.35, 2.0)
        end)
        table.insert(self._conns, rsConn)
    end

    return self
end

function UI:_destroy()
    for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    if self._gui then self._gui:Destroy() end
end

-- =============================================================================
--  NOTIFICATIONS  — toast cards that slide in from the right and stack upward
--  opts: { Title, Message, Duration (s), Type = "info"|"success"|"warning"|"error" }
-- =============================================================================
function UI:Notify(opts)
    opts = opts or {}
    local title    = opts.Title    or "Notification"
    local message  = opts.Message  or ""
    local duration = opts.Duration or 4
    local ntype    = opts.Type     or "info"

    local typeAccent = {
        info    = C.blue,
        success = C.green,
        warning = C.yellow,
        error   = C.red,
    }
    local accent = typeAccent[ntype] or C.blue
    local hasMsg = message ~= ""
    local NH     = hasMsg and 72 or 52
    local NW     = 290

    self._notifStack = self._notifStack or {}

    -- Shift existing cards upward to make room
    for _, e in ipairs(self._notifStack) do
        local cy = e.card.Position.Y.Offset
        tw(e.card, { Position = UDim2.new(1, -NW-14, 1, cy - NH - 8) }, .2)
    end

    -- Build card (parented to ScreenGui so it's always on top)
    local card = mk("Frame", {
        Size = UDim2.new(0, NW, 0, NH),
        Position = UDim2.new(1, NW + 20, 1, -NH - 14),  -- start off-screen right
        BackgroundColor3 = C.card, BorderSizePixel = 0, ZIndex = 500,
    }, self._gui)
    rnd(card, 8); bdr(card, C.border, 1)

    -- Coloured left strip
    local strip = mk("Frame", {
        Size = UDim2.new(0, 3, 1, -12),
        Position = UDim2.new(0, 6, 0, 6),
        BackgroundColor3 = accent, BorderSizePixel = 0, ZIndex = 501,
    }, card)
    rnd(strip, 99)

    -- Title
    lbl(title, C.text, 12, Enum.Font.GothamBold, card, {
        Size = UDim2.new(1, -38, 0, 16),
        Position = UDim2.new(0, 16, 0, hasMsg and 9 or 18),
        ZIndex = 501,
    })

    -- Body message
    if hasMsg then
        lbl(message, C.sub, 11, Enum.Font.Gotham, card, {
            Size = UDim2.new(1, -38, 0, 28),
            Position = UDim2.new(0, 16, 0, 30),
            ZIndex = 501, TextWrapped = true,
        })
    end

    -- Close ✕ button
    local xBtn = mk("TextButton", {
        Size = UDim2.new(0, 18, 0, 18),
        Position = UDim2.new(1, -22, 0, 6),
        BackgroundTransparency = 1, Text = "✕",
        TextColor3 = C.muted, Font = Enum.Font.GothamBold, TextSize = 10,
        BorderSizePixel = 0, ZIndex = 502, AutoButtonColor = false,
    }, card)
    xBtn.MouseEnter:Connect(function() xBtn.TextColor3 = C.text end)
    xBtn.MouseLeave:Connect(function() xBtn.TextColor3 = C.muted end)

    -- Progress bar that shrinks over `duration` seconds
    local bar = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 1, -2),
        BackgroundColor3 = accent, BorderSizePixel = 0, ZIndex = 501,
    }, card)

    local entry = { card = card, h = NH }
    table.insert(self._notifStack, entry)

    -- Slide in from right
    tw(card, { Position = UDim2.new(1, -NW-14, 1, -NH-14) }, .28,
        Enum.EasingStyle.Back, Enum.EasingDirection.Out)

    local dismissed = false
    local function dismiss()
        if dismissed then return end
        dismissed = true
        -- Remove from stack
        for i, e in ipairs(self._notifStack) do
            if e == entry then table.remove(self._notifStack, i); break end
        end
        -- Shift remaining cards downward to fill the gap
        for _, e in ipairs(self._notifStack) do
            local cy = e.card.Position.Y.Offset
            tw(e.card, { Position = UDim2.new(1, -NW-14, 1, cy + NH + 8) }, .2)
        end
        -- Slide out to the right
        tw(card, { Position = UDim2.new(1, NW + 20, 1, card.Position.Y.Offset) }, .2)
        task.delay(.25, function() if card.Parent then card:Destroy() end end)
    end

    xBtn.MouseButton1Click:Connect(dismiss)

    -- Auto-dismiss after duration (with shrinking progress bar)
    task.spawn(function()
        tw(bar, { Size = UDim2.new(0, 0, 0, 2) }, duration, Enum.EasingStyle.Linear)
        task.wait(duration)
        dismiss()
    end)
end

function UI:_srchCard(el)
    local card = mk("TextButton", {
        Size = UDim2.new(1,0,0,46), BackgroundColor3 = C.card,
        BorderSizePixel = 0, ZIndex = 11, Text = "", AutoButtonColor = false,
    }, self._srchOverlay)
    rnd(card, 8); bdr(card, C.border, 1)
    card.MouseEnter:Connect(function() tw(card,{BackgroundColor3=C.card2},.08) end)
    card.MouseLeave:Connect(function() tw(card,{BackgroundColor3=C.card},.08) end)
    card.MouseButton1Click:Connect(function()
        for _, tab in ipairs(self._tabs) do
            if tab._name == el._tabName then self:_selectTab(tab); break end
        end
        self._srchBox.Text = ""
        self._srchOverlay.Visible = false
    end)
    lbl(el._name or "", C.text, 12, Enum.Font.GothamBold, card, {
        Size = UDim2.new(1,-100,0,16), Position = UDim2.new(0,10,0,6), ZIndex = 12,
    })
    lbl(el._desc ~= "" and el._desc or el._type, C.muted, 10, Enum.Font.Gotham, card, {
        Size = UDim2.new(1,-100,0,13), Position = UDim2.new(0,10,0,24), ZIndex = 12,
    })
    local loc = (el._tabName or "")..(el._segName and (" > "..el._segName) or "")
    lbl(loc, C.accent, 10, Enum.Font.Gotham, card, {
        Size = UDim2.new(0,90,1,0), Position = UDim2.new(1,-96,0,0),
        TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 12,
    })
end

-- =============================================================================
--  TAB
-- =============================================================================
function UI:Tab(name, icon)
    local td = setmetatable({ _name = name, _win = self }, { __index = Tab })
    local tabBtn = mk("TextButton", {
        Size = UDim2.new(1,0,0,30), BackgroundColor3 = C.bg,
        Text = (icon and (icon.."  ") or "") .. name,
        TextColor3 = C.muted, Font = Enum.Font.Gotham, TextSize = 12,
        BorderSizePixel = 0, AutoButtonColor = false,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
    }, self._tabList)
    rnd(tabBtn, 7); pad(tabBtn, 0,8,0,10)
    td._btn = tabBtn

    local scroll = mk("ScrollingFrame", {
        Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent,
        CanvasSize = UDim2.new(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false, ZIndex = 4,
    }, self._contentArea)
    pad(scroll, 14,14,14,14)
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

-- =============================================================================
--  SEGMENT
-- =============================================================================
function Tab:Segment(name)
    local seg = setmetatable({ _name=name, _tab=self, _win=self._win }, { __index=Segment })
    local wrapper = mk("Frame", {
        Size = UDim2.new(1,0,0,0), BackgroundTransparency=1, BorderSizePixel=0,
        AutomaticSize = Enum.AutomaticSize.Y, ZIndex=5,
    }, self._scroll)
    lst(wrapper, Enum.FillDirection.Vertical, 6)
    lbl(name:upper(), C.muted, 10, Enum.Font.GothamBold, wrapper, {
        Size = UDim2.new(1,0,0,14), ZIndex=6,
    })
    mk("Frame", {
        Size = UDim2.new(1,0,0,1), BackgroundColor3=C.border, BorderSizePixel=0, ZIndex=6,
    }, wrapper)
    local content = mk("Frame", {
        Size = UDim2.new(1,0,0,0), BackgroundTransparency=1,
        AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel=0, ZIndex=6,
    }, wrapper)
    lst(content, Enum.FillDirection.Vertical, 2)
    seg._content = content
    return seg
end

local function eRow(parent, h)
    return mk("Frame", {
        Size = UDim2.new(1,0,0,h), BackgroundTransparency=1, BorderSizePixel=0, ZIndex=7,
    }, parent)
end

local function eNames(row, name, desc, h)
    local blockH = desc ~= "" and 32 or 17
    local ny = math.floor((h - blockH) / 2)
    lbl(name, C.text, 13, Enum.Font.Gotham, row, {
        Size = UDim2.new(LBLW,0,0,17), Position = UDim2.new(0,0,0,ny), ZIndex=8,
    })
    if desc ~= "" then
        lbl(desc, C.muted, 10, Enum.Font.Gotham, row, {
            Size = UDim2.new(LBLW,0,0,13), Position = UDim2.new(0,0,0,ny+19), ZIndex=8,
        })
    end
end

local function regEl(seg, name, desc, etype)
    local el = { _name=name, _desc=desc or "", _type=etype,
                 _tabName=seg._tab._name, _segName=seg._name }
    table.insert(seg._win._elements, el)
    return el
end

-- =============================================================================
--  BUTTON
-- =============================================================================
function Segment:Button(name, opts, cb)
    if type(opts)=="function" then cb=opts; opts={} end
    opts = opts or {}
    local desc = opts.Description or ""
    local h    = desc ~= "" and EHD or EH
    local el   = regEl(self, name, desc, "Button")
    local row  = eRow(self._content, h)
    eNames(row, name, desc, h)

    local W = 80
    local btn = mk("TextButton", {
        Size = UDim2.new(0,W,0,24), Position = UDim2.new(1,-W-ERPAD, 0.5, -12),
        BackgroundColor3 = C.accent,
        Text = opts.Label or "Run", TextColor3 = C.white,
        Font = Enum.Font.GothamBold, TextSize = 12,
        BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 8,
    }, row)
    rnd(btn, 6)
    btn.MouseEnter:Connect(function() tw(btn,{BackgroundColor3=Color3.fromRGB(140,108,255)},.1) end)
    btn.MouseLeave:Connect(function() tw(btn,{BackgroundColor3=C.accent},.1) end)
    btn.MouseButton1Click:Connect(function()
        tw(btn,{BackgroundColor3=Color3.fromRGB(100,70,220)},.06)
        task.wait(.1); tw(btn,{BackgroundColor3=C.accent},.06)
        if cb then task.spawn(cb) end
    end)
    el._instance = btn
    return el
end

-- =============================================================================
--  HOLD BUTTON  — fill grows inside the button, text sits on top
-- =============================================================================
function Segment:HoldButton(name, opts, cb)
    if type(opts)=="function" then cb=opts; opts={} end
    opts = opts or {}
    local desc     = opts.Description or ""
    local holdTime = opts.HoldTime or 1.5
    local h        = desc ~= "" and EHD or EH
    local el       = regEl(self, name, desc, "HoldButton")
    local row      = eRow(self._content, h)
    eNames(row, name, desc, h)

    local W = 80
    -- Outer container (acts as button background)
    local btnFrame = mk("Frame", {
        Size = UDim2.new(0,W,0,24), Position = UDim2.new(1,-W-ERPAD, 0.5, -12),
        BackgroundColor3 = C.card2, BorderSizePixel = 0, ZIndex = 8,
        ClipsDescendants = true,
    }, row)
    rnd(btnFrame, 6); bdr(btnFrame, C.border, 1)

    -- Fill that grows left-to-right behind the text
    local fill = mk("Frame", {
        Size = UDim2.new(0,6,1,0), Position = UDim2.new(0,-6,0,0),
        BackgroundColor3 = C.accent, BorderSizePixel = 0, ZIndex = 8,
    }, btnFrame)
    rnd(fill, 6)

    -- Text label always on top of the fill
    local textLbl = lbl("Hold", C.sub, 12, Enum.Font.GothamBold, btnFrame, {
        Size = UDim2.new(1,0,1,0), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9,
    })

    -- Invisible click-catcher on top of everything
    local clickBtn = mk("TextButton", {
        Size = UDim2.new(1,0,1,0), BackgroundTransparency=1,
        Text="", ZIndex=10, BorderSizePixel=0, AutoButtonColor=false,
    }, btnFrame)

    local held, hConn = false, nil
    clickBtn.InputBegan:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        held = true; textLbl.TextColor3 = C.text
        local t0 = tick()
        hConn = Run.Heartbeat:Connect(function()
            if not held then hConn:Disconnect(); return end
            local p = math.min((tick()-t0)/holdTime, 1)
            fill.Size = UDim2.new(p,6,1,0)
            if p >= 1 then
                held=false; hConn:Disconnect()
                textLbl.TextColor3 = C.sub
                tw(fill,{Size=UDim2.new(0,6,1,0)},.15)
                if cb then task.spawn(cb) end
            end
        end)
    end)
    clickBtn.InputEnded:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        held=false; textLbl.TextColor3 = C.sub
        tw(fill,{Size=UDim2.new(0,6,1,0)},.15)
    end)
    el._instance = btnFrame
    return el
end

-- =============================================================================
--  TOGGLE  — minimal key chip left of pill, no gp filter on rebind
-- =============================================================================
function Segment:Toggle(name, opts, cb)
    if type(opts)=="function" then cb=opts; opts={} end
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
    local pillOff = bindable and (PW + 44 + ERPAD) or (PW + ERPAD)
    local pill = mk("Frame", {
        Size = UDim2.new(0,PW,0,PH), Position = UDim2.new(1,-pillOff, 0.5, -PH/2),
        BackgroundColor3 = default and C.accent or C.border, BorderSizePixel=0, ZIndex=8,
    }, row)
    rnd(pill, 99)

    local KS = 14
    local knob = mk("Frame", {
        Size = UDim2.new(0,KS,0,KS),
        Position = UDim2.new(0, default and PW-KS-3 or 3, 0.5, -KS/2),
        BackgroundColor3 = C.white, BorderSizePixel=0, ZIndex=9,
    }, pill)
    rnd(knob, 99)

    local function setState(v, fire)
        el._value = v
        tw(pill,{BackgroundColor3=v and C.accent or C.border},.14)
        tw(knob,{Position=UDim2.new(0,v and PW-KS-3 or 3,0.5,-KS/2)},.14)
        if fire and cb then task.spawn(cb, v) end
    end
    el._setValue = setState

    mk("TextButton",{
        Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",ZIndex=10,
    },pill).MouseButton1Click:Connect(function() setState(not el._value, true) end)

    if bindable then
        local boundKey = nil
        local bBtn = mk("TextButton", {
            Size = UDim2.new(0,40,0,18),
            Position = UDim2.new(1,-pillOff+PW+6, 0.5, -9),
            BackgroundColor3 = C.card2,
            Text = "none", TextColor3 = C.muted,
            Font = Enum.Font.Gotham, TextSize = 10,
            BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 8,
        }, row)
        rnd(bBtn, 4); bdr(bBtn, C.border, 1)

        local listening = false
        bBtn.MouseButton1Click:Connect(function()
            if listening then return end
            listening = true; bBtn.Text = "..."; bBtn.TextColor3 = C.yellow
            local c; c = UIS.InputBegan:Connect(function(i)
                if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
                boundKey = i.KeyCode
                bBtn.Text = i.KeyCode.Name:sub(1,8)
                bBtn.TextColor3 = C.accent
                listening = false; c:Disconnect()
            end)
        end)
        local bc = UIS.InputBegan:Connect(function(i)
            if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
            if boundKey and i.KeyCode == boundKey then setState(not el._value, true) end
        end)
        table.insert(self._win._conns, bc)
    end

    el._instance = pill
    return el
end

-- =============================================================================
--  SLIDER  — solid fill, consistent Gotham font
-- =============================================================================
function Segment:Slider(name, opts, cb)
    if type(opts)=="function" then cb=opts; opts={} end
    opts = opts or {}
    local desc   = opts.Description or ""
    local mn     = opts.Min or 0
    local mx     = opts.Max or 100
    local def    = math.clamp(opts.Default or mn, mn, mx)
    local suffix = opts.Suffix or ""
    local el     = regEl(self, name, desc, "Slider")
    el._value    = def
    el._min      = mn
    el._max      = mx

    local h   = desc ~= "" and 56 or 44
    local row = eRow(self._content, h)
    lbl(name, C.text, 13, Enum.Font.Gotham, row, {
        Size = UDim2.new(LBLW,0,0,17), Position = UDim2.new(0,0,0,2), ZIndex=8,
    })
    if desc ~= "" then
        lbl(desc, C.muted, 10, Enum.Font.Gotham, row, {
            Size = UDim2.new(1,0,0,13), Position = UDim2.new(0,0,0,20), ZIndex=8,
        })
    end
    local valLbl = lbl(def..suffix, C.accent, 12, Enum.Font.Gotham, row, {
        Size = UDim2.new(1-LBLW,-ERPAD,0,17), Position = UDim2.new(LBLW,0,0,2),
        TextXAlignment = Enum.TextXAlignment.Right, ZIndex=8,
    })

    local track = mk("Frame", {
        Size = UDim2.new(1,-ERPAD,0,6), Position = UDim2.new(0,0,1,-10),
        BackgroundColor3 = C.border, BorderSizePixel=0, ZIndex=8,
    }, row)
    rnd(track, 99)

    local p0   = (def-mn)/(mx-mn)
    local fill = mk("Frame", {
        Size = UDim2.new(p0,0,1,0), BackgroundColor3=C.accent,
        BorderSizePixel=0, ZIndex=9,
    }, track)
    rnd(fill, 99)

    local thumb = mk("Frame", {
        Size = UDim2.new(0,14,0,14), AnchorPoint = Vector2.new(.5,.5),
        Position = UDim2.new(p0,0,.5,0),
        BackgroundColor3=C.white, BorderSizePixel=0, ZIndex=10,
    }, track)
    rnd(thumb, 99); bdr(thumb, C.border, 1.5)

    local function set(pct)
        pct = math.clamp(pct, 0, 1)
        local v = math.floor(mn + pct*(mx-mn) + .5)
        el._value = v; valLbl.Text = v..suffix
        fill.Size = UDim2.new(pct,0,1,0)
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
        drag=true; onPos(i.Position.X)
    end)
    thumb.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag=true end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag=false end
    end)
    UIS.InputChanged:Connect(function(i)
        if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
            onPos(i.Position.X)
        end
    end)
    el._instance = track
    return el
end

-- =============================================================================
--  INPUT
-- =============================================================================
function Segment:Input(name, opts, cb)
    if type(opts)=="function" then cb=opts; opts={} end
    opts = opts or {}
    local desc    = opts.Description or ""
    local numeric = opts.Numeric == true
    local el      = regEl(self, name, desc, "Input")
    el._value     = opts.Default or ""

    local h   = desc ~= "" and 62 or 52
    local row = eRow(self._content, h)
    lbl(name, C.text, 13, Enum.Font.Gotham, row, {
        Size = UDim2.new(1,0,0,17), Position = UDim2.new(0,0,0,2), ZIndex=8,
    })
    if desc ~= "" then
        lbl(desc, C.muted, 10, Enum.Font.Gotham, row, {
            Size = UDim2.new(1,0,0,13), Position = UDim2.new(0,0,0,20), ZIndex=8,
        })
    end
    local by = desc ~= "" and 36 or 24
    local bg = mk("Frame", {
        Size = UDim2.new(1,-ERPAD,0,24), Position = UDim2.new(0,0,0,by),
        BackgroundColor3=C.card2, BorderSizePixel=0, ZIndex=8,
    }, row)
    rnd(bg, 6)
    local st = bdr(bg, C.border, 1)
    pad(bg, 0,8,0,8)

    local box = mk("TextBox", {
        Size = UDim2.new(1,0,1,0), BackgroundTransparency=1,
        PlaceholderText = opts.Placeholder or "Enter value...",
        PlaceholderColor3=C.muted, Text=el._value,
        TextColor3=C.text, Font=Enum.Font.Gotham, TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Left,
        ClearTextOnFocus=false, ZIndex=9,
    }, bg)
    box.Focused:Connect(function()  st.Color=C.accent end)
    box.FocusLost:Connect(function()
        st.Color=C.border
        if numeric then
            local n=tonumber(box.Text)
            box.Text = n and tostring(n) or ""
        end
        el._value=box.Text
        if cb then task.spawn(cb, el._value) end
    end)
    box:GetPropertyChangedSignal("Text"):Connect(function() el._value=box.Text end)
    el._instance = box
    return el
end

-- =============================================================================
--  DROPDOWN  — backdrop catch, UIListLayout, arrow toggles v/^
-- =============================================================================
function Segment:Dropdown(name, opts, cb)
    if type(opts)=="function" then cb=opts; opts={} end
    opts = opts or {}
    local desc  = opts.Description or ""
    local multi = opts.Multi == true
    local el    = regEl(self, name, desc, multi and "MultiDropdown" or "Dropdown")
    el._value   = multi and {} or opts.Default
    el._opts    = type(opts.Options)=="table" and opts.Options or {}

    local function getOptions()
        if type(opts.Options)=="function" then return opts.Options() end
        return el._opts or {}
    end

    local h   = desc ~= "" and 60 or 50
    local row = eRow(self._content, h)
    lbl(name, C.text, 13, Enum.Font.Gotham, row, {
        Size = UDim2.new(1,0,0,17), Position = UDim2.new(0,0,0,2), ZIndex=8,
    })
    if desc ~= "" then
        lbl(desc, C.muted, 10, Enum.Font.Gotham, row, {
            Size = UDim2.new(1,0,0,13), Position = UDim2.new(0,0,0,20), ZIndex=8,
        })
    end

    local dy = desc ~= "" and 36 or 24
    local ddBtn = mk("TextButton", {
        Size = UDim2.new(1,-ERPAD,0,24), Position = UDim2.new(0,0,0,dy),
        BackgroundColor3=C.card2, Text="",
        BorderSizePixel=0, AutoButtonColor=false, ZIndex=8,
    }, row)
    rnd(ddBtn, 6); bdr(ddBtn, C.border, 1)
    pad(ddBtn, 0,20,0,8)

    local function displayText()
        if multi then
            local sel={}
            for k,v in pairs(el._value) do if v then table.insert(sel,k) end end
            return #sel>0 and table.concat(sel,", ") or "Select..."
        end
        return tostring(el._value or "Select...")
    end

    local ddLbl = lbl(displayText(), C.text, 12, Enum.Font.Gotham, ddBtn, {
        Size = UDim2.new(1,-18,1,0), ZIndex=9,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd,
    })
    -- Arrow: sits flush at right edge, toggles between v and ^
    local arrowLbl = lbl("v", C.muted, 10, Enum.Font.GothamBold, ddBtn, {
        Size = UDim2.new(0,16,1,0), Position = UDim2.new(1,-17,0,0),
        TextXAlignment=Enum.TextXAlignment.Center, ZIndex=9,
    })

    local open, listFr, backdrop = false, nil, nil

    local function closeList()
        if listFr then listFr:Destroy(); listFr=nil end
        if backdrop then backdrop:Destroy(); backdrop=nil end
        arrowLbl.Text = "v"
        open = false
    end

    ddBtn.MouseButton1Click:Connect(function()
        if open then closeList(); return end
        open = true
        arrowLbl.Text = "^"
        local options = getOptions()
        local ap = ddBtn.AbsolutePosition
        local as = ddBtn.AbsoluteSize
        local IH = 28
        local LH = math.min(#options * IH, 168)

        backdrop = mk("TextButton", {
            Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
            Text="", ZIndex=48, BorderSizePixel=0,
        }, self._win._gui)
        backdrop.MouseButton1Click:Connect(closeList)

        listFr = mk("Frame", {
            Size = UDim2.new(0,as.X,0,LH),
            Position = UDim2.new(0,ap.X,0,ap.Y+as.Y+3),
            BackgroundColor3=C.card, BorderSizePixel=0, ZIndex=50, ClipsDescendants=true,
        }, self._win._gui)
        rnd(listFr, 7); bdr(listFr, C.border, 1)

        local scroll = mk("ScrollingFrame", {
            Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
            BorderSizePixel=0, ScrollBarThickness=2, ScrollBarImageColor3=C.accent,
            CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y,
            ZIndex=51,
        }, listFr)
        lst(scroll, Enum.FillDirection.Vertical, 0)

        for _, opt in ipairs(options) do
            local isSel = multi and el._value[opt] or (el._value==opt)
            local item = mk("TextButton", {
                Size = UDim2.new(1,0,0,IH),
                BackgroundColor3 = isSel and Color3.fromRGB(26,20,50) or C.card,
                Text="", BorderSizePixel=0, AutoButtonColor=false, ZIndex=52,
            }, scroll)
            pad(item, 0,8,0,10)

            local itxt = lbl(tostring(opt), isSel and C.accent or C.sub, 12, Enum.Font.Gotham, item, {
                Size=UDim2.new(1, multi and -22 or 0, 1,0), ZIndex=53,
                TextXAlignment=Enum.TextXAlignment.Left,
            })
            local chkLbl
            if multi then
                chkLbl = lbl(isSel and "v" or "", C.green, 11, Enum.Font.GothamBold, item, {
                    Size=UDim2.new(0,18,1,0), Position=UDim2.new(1,-20,0,0),
                    TextXAlignment=Enum.TextXAlignment.Center, ZIndex=53,
                })
            end
            item.MouseEnter:Connect(function() tw(item,{BackgroundColor3=C.card2},.08) end)
            item.MouseLeave:Connect(function()
                local s = multi and el._value[opt] or (el._value==opt)
                tw(item,{BackgroundColor3=s and Color3.fromRGB(26,20,50) or C.card},.08)
            end)
            if multi then
                item.MouseButton1Click:Connect(function()
                    el._value[opt] = not el._value[opt]
                    if chkLbl then chkLbl.Text = el._value[opt] and "v" or "" end
                    itxt.TextColor3 = el._value[opt] and C.accent or C.sub
                    item.BackgroundColor3 = el._value[opt] and Color3.fromRGB(26,20,50) or C.card
                    ddLbl.Text = displayText()
                    if cb then task.spawn(cb, el._value) end
                end)
            else
                item.MouseButton1Click:Connect(function()
                    el._value=opt; ddLbl.Text=displayText()
                    closeList()
                    if cb then task.spawn(cb, opt) end
                end)
            end
        end

        if #options == 0 then
            lbl("(empty)", C.muted, 12, Enum.Font.Gotham, scroll, {
                Size=UDim2.new(1,0,0,IH), ZIndex=52,
                TextXAlignment=Enum.TextXAlignment.Center,
            })
        end
    end)

    function el:SetOptions(newOpts)
        self._opts = newOpts
        if not multi and (not self._value or not table.find(newOpts, self._value)) then
            self._value = newOpts[1]
        end
        ddLbl.Text = displayText()
    end

    if not multi and not el._value then
        local o = getOptions()
        el._value = o[1]; ddLbl.Text = displayText()
    end

    el._instance = ddBtn
    return el
end

function Segment:MultiDropdown(name, opts, cb)
    opts=opts or {}; opts.Multi=true
    return self:Dropdown(name, opts, cb)
end

-- =============================================================================
--  COLOR PICKER
--  SV box uses stacked UIGradient frames (no asset IDs for base).
--  A transparent catch button sits on top of all overlays so InputBegan fires
--  reliably regardless of which child element is under the cursor.
-- =============================================================================
function Segment:ColorPicker(name, opts, cb)
    if type(opts)=="function" then cb=opts; opts={} end
    opts = opts or {}
    local desc    = opts.Description or ""
    local default = opts.Default or C.accent
    local el      = regEl(self, name, desc, "ColorPicker")
    el._value     = default

    local h   = desc ~= "" and EHD or EH
    local row = eRow(self._content, h)
    eNames(row, name, desc, h)

    local swatch = mk("TextButton", {
        Size=UDim2.new(0,32,0,20), Position=UDim2.new(1,-32-ERPAD, 0.5, -10),
        BackgroundColor3=default, Text="",
        BorderSizePixel=0, AutoButtonColor=false, ZIndex=8,
    }, row)
    rnd(swatch, 5); bdr(swatch, C.border, 1)

    local h_h, s_h, v_h = Color3.toHSV(default)
    local pickerFr, pickerOpen = nil, false
    local SV = 152

    local function toHex(c)
        return ("#%02X%02X%02X"):format(
            math.floor(c.R*255+.5), math.floor(c.G*255+.5), math.floor(c.B*255+.5))
    end

    local function closePicker()
        if pickerFr then pickerFr:Destroy(); pickerFr=nil end
        pickerOpen = false
    end

    local function buildPicker()
        local ap = swatch.AbsolutePosition
        local as = swatch.AbsoluteSize
        local vp = workspace.CurrentCamera.ViewportSize
        local PW = 180
        local px = math.clamp(ap.X + as.X - PW, 4, vp.X - PW - 4)
        local py = ap.Y + as.Y + 6
        if py + 234 > vp.Y then py = ap.Y - 234 - 6 end

        pickerFr = mk("Frame", {
            Size=UDim2.new(0,PW,0,234), Position=UDim2.new(0,px,0,py),
            BackgroundColor3=C.card, BorderSizePixel=0, ZIndex=60,
        }, self._win._gui)
        rnd(pickerFr, 10); bdr(pickerFr, C.border, 1)
        pad(pickerFr, 10,10,10,10)

        -- SV box: base hue, white overlay (h-grad), black overlay (v-grad)
        local svBox = mk("Frame", {
            Size=UDim2.new(0,SV,0,SV),
            BackgroundColor3=Color3.fromHSV(h_h,1,1),
            BorderSizePixel=0, ZIndex=61,
        }, pickerFr)
        rnd(svBox, 4)

        local whiteOv = mk("Frame", {
            Size=UDim2.new(1,0,1,0), BackgroundColor3=Color3.new(1,1,1),
            BorderSizePixel=0, ZIndex=62,
        }, svBox)
        rnd(whiteOv, 4)
        mk("UIGradient",{
            Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(1,1,1)),
            Transparency=NumberSequence.new({
                NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1),
            }), Rotation=0,
        }, whiteOv)

        local blackOv = mk("Frame", {
            Size=UDim2.new(1,0,1,0), BackgroundColor3=Color3.new(0,0,0),
            BorderSizePixel=0, ZIndex=63,
        }, svBox)
        rnd(blackOv, 4)
        mk("UIGradient",{
            Color=ColorSequence.new(Color3.new(0,0,0),Color3.new(0,0,0)),
            Transparency=NumberSequence.new({
                NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(1,0),
            }), Rotation=90,
        }, blackOv)

        local svThumb = mk("Frame", {
            Size=UDim2.new(0,10,0,10), AnchorPoint=Vector2.new(.5,.5),
            Position=UDim2.new(s_h,0,1-v_h,0),
            BackgroundColor3=C.white, BorderSizePixel=0, ZIndex=65,
        }, svBox)
        rnd(svThumb, 99); bdr(svThumb, C.black, 1.5)

        -- Transparent catch layer on top of ALL SV children so InputBegan fires here.
        -- This fixes the issue where clicks on overlay frames would be swallowed,
        -- causing the picker to read stale AbsolutePosition from the wrong element.
        local svCatch = mk("TextButton", {
            Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
            Text="", ZIndex=67, BorderSizePixel=0, AutoButtonColor=false,
        }, svBox)

        -- Hue bar
        local hBar = mk("ImageLabel", {
            Size=UDim2.new(0,SV,0,12), Position=UDim2.new(0,0,0,SV+8),
            Image="rbxassetid://698052001",
            BackgroundTransparency=1, ZIndex=61,
        }, pickerFr)
        rnd(hBar, 4)
        local hThumb = mk("Frame", {
            Size=UDim2.new(0,4,0,12), AnchorPoint=Vector2.new(.5,0),
            Position=UDim2.new(h_h,0,0,0),
            BackgroundColor3=C.white, BorderSizePixel=0, ZIndex=62,
        }, hBar)
        rnd(hThumb, 3); bdr(hThumb, C.border, 1)
        local hueCatch = mk("TextButton", {
            Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
            Text="", ZIndex=63, BorderSizePixel=0, AutoButtonColor=false,
        }, hBar)

        -- Hex input
        local hexBg = mk("Frame", {
            Size=UDim2.new(0,SV,0,22), Position=UDim2.new(0,0,0,SV+26),
            BackgroundColor3=C.card2, BorderSizePixel=0, ZIndex=61,
        }, pickerFr)
        rnd(hexBg, 5)
        local hexSt = bdr(hexBg, C.border, 1)
        pad(hexBg, 0,6,0,6)
        local hexBox = mk("TextBox", {
            Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
            Text=toHex(el._value), TextColor3=C.text,
            Font=Enum.Font.Code, TextSize=11,  -- Code only here for monospace hex
            ClearTextOnFocus=false, ZIndex=62,
        }, hexBg)

        local function apply(nh, ns, nv)
            h_h,s_h,v_h = nh,ns,nv
            local col = Color3.fromHSV(nh,ns,nv)
            el._value=col; swatch.BackgroundColor3=col
            svBox.BackgroundColor3=Color3.fromHSV(nh,1,1)
            svThumb.Position=UDim2.new(ns,0,1-nv,0)
            hThumb.Position=UDim2.new(nh,0,0,0)
            hexBox.Text=toHex(col)
            if cb then task.spawn(cb,col) end
        end

        hexBox.Focused:Connect(function() hexSt.Color=C.accent end)
        hexBox.FocusLost:Connect(function()
            hexSt.Color=C.border
            local tx=hexBox.Text:gsub("#","")
            if #tx==6 then
                local r=tonumber(tx:sub(1,2),16)
                local g=tonumber(tx:sub(3,4),16)
                local b=tonumber(tx:sub(5,6),16)
                if r and g and b then apply(Color3.toHSV(Color3.fromRGB(r,g,b))) end
            end
        end)

        -- SV drag via the catch button (guarantees InputBegan always fires here)
        local svD = false
        svCatch.InputBegan:Connect(function(i)
            if i.UserInputType~=Enum.UserInputType.MouseButton1 then return end
            svD=true
            local mp  = Vector2.new(i.Position.X, i.Position.Y)
            local rel = mp - svBox.AbsolutePosition
            apply(h_h, math.clamp(rel.X/SV,0,1), 1-math.clamp(rel.Y/SV,0,1))
        end)
        UIS.InputEnded:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1 then svD=false end
        end)
        UIS.InputChanged:Connect(function(i)
            if svD and i.UserInputType==Enum.UserInputType.MouseMovement then
                local mp  = Vector2.new(i.Position.X, i.Position.Y)
                local rel = mp - svBox.AbsolutePosition
                apply(h_h, math.clamp(rel.X/SV,0,1), 1-math.clamp(rel.Y/SV,0,1))
            end
        end)

        -- Hue drag via catch button
        local hD = false
        hueCatch.InputBegan:Connect(function(i)
            if i.UserInputType~=Enum.UserInputType.MouseButton1 then return end
            hD=true
            local mp=Vector2.new(i.Position.X, i.Position.Y)
            apply(math.clamp((mp.X-hBar.AbsolutePosition.X)/hBar.AbsoluteSize.X,0,1),s_h,v_h)
        end)
        UIS.InputEnded:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1 then hD=false end
        end)
        UIS.InputChanged:Connect(function(i)
            if hD and i.UserInputType==Enum.UserInputType.MouseMovement then
                local mp=Vector2.new(i.Position.X, i.Position.Y)
                apply(math.clamp((mp.X-hBar.AbsolutePosition.X)/hBar.AbsoluteSize.X,0,1),s_h,v_h)
            end
        end)

        -- Outside click (swatch excluded so toggle works cleanly)
        local outsideConn
        outsideConn = UIS.InputBegan:Connect(function(i)
            if i.UserInputType~=Enum.UserInputType.MouseButton1 then return end
            if not pickerFr then outsideConn:Disconnect(); return end
            local mp=UIS:GetMouseLocation()
            local pa=pickerFr.AbsolutePosition; local ps=pickerFr.AbsoluteSize
            if mp.X>=pa.X and mp.X<=pa.X+ps.X and mp.Y>=pa.Y and mp.Y<=pa.Y+ps.Y then return end
            local sa=swatch.AbsolutePosition; local ss=swatch.AbsoluteSize
            if mp.X>=sa.X and mp.X<=sa.X+ss.X and mp.Y>=sa.Y and mp.Y<=sa.Y+ss.Y then return end
            closePicker(); outsideConn:Disconnect()
        end)
    end

    swatch.MouseButton1Click:Connect(function()
        if pickerOpen then closePicker() else pickerOpen=true; buildPicker() end
    end)
    el._instance = swatch
    return el
end

-- =============================================================================
--  LABEL / UPTIME
-- =============================================================================
function Segment:Label(text, color)
    lbl(text, color or C.muted, 12, Enum.Font.Gotham, self._content, {
        Size=UDim2.new(1,0,0,18), ZIndex=7, TextWrapped=true,
    })
end

function Segment:Uptime()
    local disp = lbl("Session: 0:00:00", C.muted, 12, Enum.Font.Gotham, self._content, {
        Size=UDim2.new(1,0,0,18), ZIndex=7,
    })
    table.insert(self._win._uptimeFns, function(str) disp.Text=str end)
    return disp
end

-- =============================================================================
--  SETTINGS TAB
-- =============================================================================
function UI:SettingsTab()
    local tab = self:Tab("Settings", "")
    local win = self

    local ui = tab:Segment("Interface")

    local tkEl = ui:Input("Toggle Key", {
        Placeholder=win._uiKey.Name, Default=win._uiKey.Name,
        Description="Key to show / hide the UI",
    })
    ui:Button("Rebind Toggle Key", {Label="Rebind"}, function()
        tkEl._instance.Text="Press key..."; tkEl._instance.TextColor3=C.yellow
        local c; c=UIS.InputBegan:Connect(function(i)
            if i.UserInputType~=Enum.UserInputType.Keyboard then return end
            win._uiKey=i.KeyCode
            tkEl._instance.Text=i.KeyCode.Name
            tkEl._instance.TextColor3=C.text
            c:Disconnect()
        end)
    end)

    local pkEl = ui:Input("Panic Key", {
        Placeholder=win._panicKey.Name, Default=win._panicKey.Name,
        Description="Instantly destroys the UI",
    })
    ui:Button("Rebind Panic Key", {Label="Rebind"}, function()
        pkEl._instance.Text="Press key..."; pkEl._instance.TextColor3=C.yellow
        local c; c=UIS.InputBegan:Connect(function(i)
            if i.UserInputType~=Enum.UserInputType.Keyboard then return end
            win._panicKey=i.KeyCode
            pkEl._instance.Text=i.KeyCode.Name
            pkEl._instance.TextColor3=C.text
            c:Disconnect()
        end)
    end)

    ui:Toggle("Clamp UI to Screen", {
        Default=win._clamp, Description="Prevents dragging off-screen",
    }, function(v) win._clamp=v end)

    local misc = tab:Segment("Session")
    misc:Uptime()
    misc:Button("Unload Veltrix", {
        Label="Unload", Description="Destroys the UI and stops all connections",
    }, function() win:_destroy() end)

    return tab
end

-- =============================================================================
--  CONFIG TAB
-- =============================================================================
function UI:ConfigTab()
    local tab = self:Tab("Config", "")
    local seg = tab:Segment("Save & Load")
    local DIR = "veltrix_configs/"

    if makefolder and not (isfolder and isfolder(DIR)) then
        pcall(makefolder, DIR)
    end

    local function listCfgs()
        if not listfiles then return {"(none)"} end
        local out={}
        for _, f in ipairs(listfiles(DIR) or {}) do
            local n=tostring(f):match("([^/\\]+)%.json$")
            if n then table.insert(out,n) end
        end
        return #out>0 and out or {"(none)"}
    end

    local function serialize()
        local d={}
        for _, el in ipairs(self._elements) do
            if el._name and el._value~=nil then
                if typeof(el._value)=="Color3" then
                    d[el._name]={r=el._value.R, g=el._value.G, b=el._value.B}
                else
                    d[el._name]=el._value
                end
            end
        end
        return Http:JSONEncode(d)
    end

    local function applyData(d)
        for _, el in ipairs(self._elements) do
            local v=d[el._name]; if v==nil then continue end
            if el._type=="Toggle" and el._setValue then
                el._setValue(v==true, true)
            elseif el._type=="Slider" and el._setValue then
                local mn,mx=el._min or 0,el._max or 100
                el._setValue(math.clamp((v-mn)/(mx-mn),0,1))
            elseif el._type=="Input" and el._instance then
                el._instance.Text=tostring(v); el._value=v
            elseif el._type=="Dropdown" or el._type=="MultiDropdown" then
                el._value=v
            elseif el._type=="ColorPicker" and el._instance and type(v)=="table" then
                local col=Color3.new(v.r or 1,v.g or 1,v.b or 1)
                el._value=col; el._instance.BackgroundColor3=col
            end
        end
    end

    local nameEl = seg:Input("Config Name", {Placeholder="my_config", Default="default"})
    local selEl  = seg:Dropdown("Select Config", {Options=listCfgs()})

    seg:Button("Save Config", {Label="Save"}, function()
        local n=(nameEl._value~="" and nameEl._value or "default"):gsub("[^%w_%-]","_")
        if writefile then pcall(writefile, DIR..n..".json", serialize()) end
        selEl:SetOptions(listCfgs())
    end)
    seg:Button("Load Config", {Label="Load"}, function()
        local n=selEl._value
        if not n or n=="(none)" or not readfile then return end
        local ok,raw=pcall(readfile, DIR..n..".json")
        if not ok then return end
        local ok2,d=pcall(Http.JSONDecode,Http,raw)
        if ok2 and d then applyData(d) end
    end)
    seg:Button("Delete Config", {Label="Delete"}, function()
        local n=selEl._value
        if n and n~="(none)" and delfile then
            pcall(delfile, DIR..n..".json")
            selEl:SetOptions(listCfgs())
        end
    end)

    return tab
end

return UI
