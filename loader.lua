-- ╔══════════════════════════════════════════════════════════╗
-- ║  Veltrix - Universal Loader                              ║
-- ║  loadstring(game:HttpGet("https://raw.githubusercontent  ║
-- ║  .com/denrigtigematjias/denrigtigematjias.github.io      ║
-- ║  /main/loader.lua"))()                                   ║
-- ╚══════════════════════════════════════════════════════════╝

-- ── CONFIG ──────────────────────────────────────────────────────────────────
local WORKER_URL = "https://veltrix-worker.matjias.workers.dev"
local RAW        = "https://raw.githubusercontent.com/denrigtigematjias/denrigtigematjias.github.io/main"
local KEY_FILE   = "veltrix_key.txt"
local KEY_URL    = "https://denrigtigematjias.github.io/getkey"

-- PlaceId → game folder mapping
local PLACE_MAP = {
    [96033111684913] = "tef",
}

-- ── SERVICES ────────────────────────────────────────────────────────────────
local Http = game:GetService("HttpService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local lp = Players.LocalPlayer

-- ── KEY VALIDATION ──────────────────────────────────────────────────────────
local function validateKey(key)
    if type(key) ~= "string" or not key:match("^VLX%-") then
        return false, 0, "Invalid key format."
    end

    -- Try executor HWID functions in order of preference.
    local hwid = (gethwid and gethwid())
              or (getdeviceid and getdeviceid())
              or nil

    -- UrlEncode the key manually in case Http:UrlEncode isn't available
    local encodedKey = key:gsub("[^%w%-]", function(c)
        return ("%%%02X"):format(c:byte())
    end)
    local url = WORKER_URL .. "/validate?key=" .. encodedKey
    if hwid then
        local encodedHwid = tostring(hwid):gsub("[^%w%-]", function(c)
            return ("%%%02X"):format(c:byte())
        end)
        url = url .. "&hwid=" .. encodedHwid
    end

    -- Use game:HttpGet — universally supported across executors
    local ok, raw = pcall(function() return game:HttpGet(url) end)
    if not ok then
        return false, 0, "NETWORK_ERROR"
    end
    if type(raw) ~= "string" or raw == "" then
        return false, 0, "NETWORK_ERROR"
    end

    local ok2, data = pcall(function() return Http:JSONDecode(raw) end)
    if not ok2 or type(data) ~= "table" then
        return false, 0, "NETWORK_ERROR"
    end

    return data.valid == true, data.ttl or 0, data.reason or ""
end

local function loadSavedKey()
    if readfile and isfile and isfile(KEY_FILE) then
        local raw = readfile(KEY_FILE)
        return raw and raw:match("^%s*(.-)%s*$") or ""
    end
    return ""
end

local function saveKey(key)
    if writefile then
        pcall(function() writefile(KEY_FILE, key) end)
    end
end

-- ── GUI BUILDER ──────────────────────────────────────────────────────────────
-- Colours mirror ui.lua's palette exactly so the loader feels like part of
-- the same product.
local C = {
    bg     = Color3.fromRGB(11,  13,  18),
    card   = Color3.fromRGB(19,  21,  30),
    card2  = Color3.fromRGB(24,  27,  38),
    border = Color3.fromRGB(30,  34,  50),
    text   = Color3.fromRGB(225, 228, 238),
    sub    = Color3.fromRGB(160, 165, 185),
    muted  = Color3.fromRGB(90,  96,  115),
    accent = Color3.fromRGB(124, 92,  252),
    green  = Color3.fromRGB(34,  211, 165),
    red    = Color3.fromRGB(240, 100, 100),
    yellow = Color3.fromRGB(251, 191, 36),
}

local function tw(o, props, t)
    TweenService:Create(o, TweenInfo.new(t or .14, Enum.EasingStyle.Quad), props):Play()
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

local function buildGui()
    local existing = CoreGui:FindFirstChild("VeltrixLoader")
    if existing then existing:Destroy() end

    local gui = mk("ScreenGui", {
        Name = "VeltrixLoader", ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
    }, CoreGui)

    -- ── Wrapper (provides the 1px border via background colour) ──────────────
    -- Identical technique to ui.lua: outer wrapper = border colour,
    -- inner frame = bg colour, 1px inset on each side.
    -- Panel: 400 wide, 220 tall  →  wrapper adds 2px each axis = 402 × 222
    local PW, PH = 400, 202
    local wrapper = mk("Frame", {
        Size             = UDim2.new(0, PW+2, 0, PH+2),
        Position         = UDim2.new(0.5, -(PW+2)/2, 0.62, -(PH+2)/2),
        BackgroundColor3 = C.border,
        BorderSizePixel  = 0, ZIndex = 2,
        ClipsDescendants = true,
        BackgroundTransparency = 1,
    }, gui)

    local frame = mk("Frame", {
        Size             = UDim2.new(1,-2,1,-2),
        Position         = UDim2.new(0,1,0,1),
        BackgroundColor3 = C.bg,
        BorderSizePixel  = 0, ZIndex = 2,
        ClipsDescendants = true,
    }, wrapper)

    -- 2px accent line at very top (same as ui.lua window)
    mk("Frame", {
        Size = UDim2.new(1,0,0,2), Position = UDim2.new(0,0,0,0),
        BackgroundColor3 = C.accent, BorderSizePixel = 0, ZIndex = 3,
    }, frame)

    -- ── Header (44px, matching HH in ui.lua) ─────────────────────────────────
    local HH = 44
    local hdr = mk("Frame", {
        Size = UDim2.new(1,0,0,HH), Position = UDim2.new(0,0,0,2),
        BackgroundColor3 = C.bg, BorderSizePixel = 0, ZIndex = 3,
    }, frame)

    -- Accent dot
    local dot = mk("Frame", {
        Size = UDim2.new(0,6,0,6), Position = UDim2.new(0,16,0.5,-3),
        BackgroundColor3 = C.accent, BorderSizePixel = 0, ZIndex = 4,
    }, hdr)
    rnd(dot, 99)

    -- "Veltrix" title
    mk("TextLabel", {
        Size = UDim2.new(0,120,0,20), Position = UDim2.new(0,28,0.5,-10),
        BackgroundTransparency = 1, Text = "Veltrix",
        TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
    }, hdr)

    -- "Key System" chip — right side, same style as ui.lua's segment labels
    local chip = mk("Frame", {
        Size = UDim2.new(0,78,0,20), Position = UDim2.new(1,-94,0.5,-10),
        BackgroundColor3 = C.card2, BorderSizePixel = 0, ZIndex = 4,
    }, hdr)
    rnd(chip, 99)
    mk("UIStroke", { Color = C.border, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, chip)
    mk("TextLabel", {
        Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1,
        Text = "Key System", TextColor3 = C.muted,
        Font = Enum.Font.Gotham, TextSize = 10, ZIndex = 5,
    }, chip)

    -- Header bottom divider
    mk("Frame", {
        Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,1,-1),
        BackgroundColor3 = C.border, BorderSizePixel = 0, ZIndex = 4,
    }, hdr)

    -- ── Content (starts below header) ────────────────────────────────────────
    -- All elements use absolute Y from top of `frame`, content area begins at
    -- 2 (accent) + 44 (header) + 1 (divider) = 47px
    local Y0   = 47   -- content area top
    local PAD  = 18   -- horizontal padding each side

    -- "Enter your key to continue"
    mk("TextLabel", {
        Size = UDim2.new(1,-PAD*2,0,14), Position = UDim2.new(0,PAD,0,Y0+14),
        BackgroundTransparency = 1, Text = "Enter your key to continue",
        TextColor3 = C.muted, Font = Enum.Font.Gotham, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
    }, frame)

    -- ── Input row (matches ui.lua Input element) ──────────────────────────────
    local inputBg = mk("Frame", {
        Size = UDim2.new(1,-PAD*2,0,36), Position = UDim2.new(0,PAD,0,Y0+36),
        BackgroundColor3 = C.card, BorderSizePixel = 0, ZIndex = 4,
    }, frame)
    rnd(inputBg, 6)
    local inputStroke = mk("UIStroke", {
        Color = C.border, Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, inputBg)

    local input = mk("TextBox", {
        Size = UDim2.new(1,-16,1,0), Position = UDim2.new(0,8,0,0),
        BackgroundTransparency = 1,
        PlaceholderText = "VLX-XXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
        PlaceholderColor3 = C.muted, Text = "",
        TextColor3 = C.accent, Font = Enum.Font.Code, TextSize = 11,
        ClearTextOnFocus = false, ZIndex = 5,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, inputBg)

    -- Focus highlight on input (matches ui.lua Input behaviour)
    input.Focused:Connect(function()
        tw(inputStroke, { Color = C.accent }, .12)
    end)
    input.FocusLost:Connect(function()
        tw(inputStroke, { Color = C.border }, .12)
    end)

    -- ── Status label ──────────────────────────────────────────────────────────
    local statusLbl = mk("TextLabel", {
        Size = UDim2.new(1,-PAD*2,0,13), Position = UDim2.new(0,PAD,0,Y0+80),
        BackgroundTransparency = 1, Text = "Get your key at " .. KEY_URL,
        TextColor3 = C.muted, Font = Enum.Font.Gotham, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, frame)

    -- ── Button row: [Validate Key] [Get Key →] ────────────────────────────────
    local GAP     = 8
    local BTN_H   = 34
    local totalW  = PW - PAD*2          -- 364
    local keyW    = 108                 -- width of the secondary button
    local valW    = totalW - keyW - GAP -- 248

    -- Primary: Validate Key
    local btn = mk("TextButton", {
        Size = UDim2.new(0,valW,0,BTN_H), Position = UDim2.new(0,PAD,0,Y0+102),
        BackgroundColor3 = C.accent, BorderSizePixel = 0,
        Text = "Validate Key", TextColor3 = Color3.fromRGB(255,255,255),
        Font = Enum.Font.GothamBold, TextSize = 13,
        AutoButtonColor = false, ZIndex = 4,
    }, frame)
    rnd(btn, 6)

    btn.MouseEnter:Connect(function() tw(btn, { BackgroundColor3 = Color3.fromRGB(108,76,230) }, .12) end)
    btn.MouseLeave:Connect(function() tw(btn, { BackgroundColor3 = C.accent }, .12) end)

    -- Secondary: Get Key →
    local keyLinkBtn = mk("TextButton", {
        Size = UDim2.new(0,keyW,0,BTN_H), Position = UDim2.new(0,PAD+valW+GAP,0,Y0+102),
        BackgroundColor3 = C.card2, BorderSizePixel = 0,
        Text = "Get Key", TextColor3 = C.muted,
        Font = Enum.Font.Gotham, TextSize = 12,
        AutoButtonColor = false, ZIndex = 4,
    }, frame)
    rnd(keyLinkBtn, 6)
    mk("UIStroke", {
        Color = C.border, Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, keyLinkBtn)

    keyLinkBtn.MouseEnter:Connect(function() tw(keyLinkBtn, { TextColor3 = C.text  }, .12) end)
    keyLinkBtn.MouseLeave:Connect(function() tw(keyLinkBtn, { TextColor3 = C.muted }, .12) end)
    keyLinkBtn.MouseButton1Click:Connect(function()
        pcall(setclipboard, KEY_URL)
        keyLinkBtn.Text = "Copied!"
        task.delay(2, function() if keyLinkBtn and keyLinkBtn.Parent then keyLinkBtn.Text = "Get Key" end end)
    end)

    -- ── Animate wrapper in (slide up + fade, like ui.lua window) ─────────────
    TweenService:Create(wrapper, TweenInfo.new(.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position             = UDim2.new(0.5, -(PW+2)/2, 0.5, -(PH+2)/2),
        BackgroundTransparency = 0,
    }):Play()

    -- ── Drag (via header) ─────────────────────────────────────────────────────
    local UIS = game:GetService("UserInputService")
    local dragging, dragStart, startPos = false, nil, nil

    hdr.InputBegan:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        dragging  = true
        dragStart = Vector2.new(i.Position.X, i.Position.Y)
        startPos  = wrapper.AbsolutePosition
        -- Snap to pure-offset so dragging is frame-of-reference agnostic
        wrapper.Position = UDim2.new(0, startPos.X, 0, startPos.Y)
    end)

    hdr.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UIS.InputChanged:Connect(function(i)
        if not dragging or i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local delta = Vector2.new(i.Position.X, i.Position.Y) - dragStart
        wrapper.Position = UDim2.new(0, startPos.X + delta.X, 0, startPos.Y + delta.Y)
    end)

    return gui, input, btn, statusLbl, inputStroke
end

-- ── STATUS HELPERS ───────────────────────────────────────────────────────────
local function setStatus(lbl, stroke, text, col)
    lbl.Text       = text
    lbl.TextColor3 = col or C.muted
    TweenService:Create(stroke, TweenInfo.new(.12), {
        Color = col or C.border, Thickness = col and 1.5 or 1,
    }):Play()
end

local function resetStroke(stroke)
    TweenService:Create(stroke, TweenInfo.new(.12), {
        Color = C.border, Thickness = 1,
    }):Play()
end

-- ── LOAD GAME SCRIPTS ────────────────────────────────────────────────────────
local function loadGame()
    local folder = PLACE_MAP[game.PlaceId]
    if not folder then
        warn("[Veltrix] Unsupported game (PlaceId: " .. tostring(game.PlaceId) .. ")")
        return
    end
    local url = RAW .. "/games/" .. folder .. "/init.lua"
    local ok, err = pcall(function()
        loadstring(game:HttpGet(url))()
    end)
    if not ok then
        warn("[Veltrix] Failed to load " .. folder .. " — " .. tostring(err))
    end
end

-- ── MAIN FLOW ────────────────────────────────────────────────────────────────

-- 1. Try the saved key first — no GUI needed if it's still valid
local saved = loadSavedKey()
if saved ~= "" then
    local valid, ttl, reason = validateKey(saved)
    if valid then
        local hours = math.round(ttl / 3600)
        print(("[Veltrix] Key valid (~%d hour%s remaining). Loading..."):format(
            hours, hours ~= 1 and "s" or ""))
        getgenv().script_key = saved
        loadGame()
        return
    end
    -- Only wipe the saved key if the server explicitly rejects it (not on network errors)
    if reason == "Key is bound to a different account." and writefile then
        pcall(function() writefile(KEY_FILE, "") end)
    end
    -- On network error, still show the GUI but don't pre-fill an expired warning
    if reason == "NETWORK_ERROR" then
        saved = ""
    end
end

-- 2. Saved key missing or expired — show GUI
local gui, input, btn, statusLbl, inputStroke = buildGui()

-- Pre-fill the input if there was a saved (expired) key so user can see it
if saved ~= "" then
    input.Text = saved
    setStatus(statusLbl, inputStroke, "Your key has expired. Get a new one.", C.yellow)
end

local busy = false

local function onSubmit()
    if busy then return end
    local key = input.Text:match("^%s*(.-)%s*$"):upper()

    if key == "" then
        setStatus(statusLbl, inputStroke, "Please enter your key.", C.red)
        return
    end

    if not key:match("^VLX%-") then
        setStatus(statusLbl, inputStroke, "Invalid format. Keys start with VLX-", C.red)
        return
    end

    busy = true
    btn.Text = "Checking..."
    setStatus(statusLbl, inputStroke, "Contacting key server...", C.muted)

    task.spawn(function()
        local valid, ttl, reason = validateKey(key)

        if valid then
            local hours = math.round(ttl / 3600)
            setStatus(statusLbl, inputStroke,
                ("Key valid — ~%d hour%s remaining."):format(hours, hours ~= 1 and "s" or ""),
                C.green)
            btn.Text             = "Valid"
            btn.BackgroundColor3 = C.green
            saveKey(key)
            getgenv().script_key = key
            task.wait(1.2)

            -- Fade wrapper out then destroy
            TweenService:Create(gui:FindFirstChildWhichIsA("Frame"), TweenInfo.new(.3), {
                BackgroundTransparency = 1
            }):Play()
            task.wait(.35)
            gui:Destroy()
            loadGame()
        else
            busy = false
            btn.Text             = "Validate Key"
            btn.BackgroundColor3 = C.accent
            if reason == "NETWORK_ERROR" then
                setStatus(statusLbl, inputStroke, "Could not reach key server. Check your connection.", C.red)
            else
                local msg = (reason ~= "" and reason or "Invalid or expired key.")
                    .. " Get one at " .. KEY_URL
                setStatus(statusLbl, inputStroke, "✕ " .. msg, C.red)
            end
        end
    end)
end

btn.MouseButton1Click:Connect(onSubmit)
input.FocusLost:Connect(function(enter)
    if enter then onSubmit() end
end)
