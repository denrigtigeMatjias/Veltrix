--========================================================--
--  Veltrix Key Check  (returning module)
--  Usage from a main script:
--     local KEYCHECK = "https://raw.githubusercontent.com/denrigtigeMatjias/Veltrix/main/keycheck.lua"
--     if not loadstring(game:HttpGet(KEYCHECK))() then
--         return            -- stops the main script; loader GUI handles re-entry
--     end
--     -- ... rest of the script runs only when the key is valid ...
--========================================================--

local HttpService = game:GetService("HttpService")
local WORKER_URL  = "https://veltrix-worker.matjias.workers.dev"
local KEY_FILE    = "veltrix_key.txt"
local LOADER_URL  = "https://raw.githubusercontent.com/denrigtigeMatjias/Veltrix/main/loader.lua"

local function validateKey(key)
    if type(key) ~= "string" or not key:match("^VLX%-") then
        return false, 0, "Invalid key format."
    end

    local hwid = (gethwid and gethwid())
              or (getdeviceid and getdeviceid())
              or nil

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

    local ok, raw = pcall(function() return game:HttpGet(url) end)
    if not ok then
        return false, 0, "NETWORK_ERROR"
    end
    if type(raw) ~= "string" or raw == "" then
        return false, 0, "NETWORK_ERROR"
    end

    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
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

-- Launches the key-entry GUI. Non-blocking: returns once the GUI is built.
local function showLoader()
    pcall(function()
        loadstring(game:HttpGet(LOADER_URL))()
    end)
end

--====================  DECISION  ========================--

local saved = loadSavedKey()

-- No saved key at all -> show loader, tell caller "not valid".
if saved == "" then
    print("[Veltrix] No saved key found.")
    showLoader()
    return false
end

local valid, ttl, reason = validateKey(saved)

if valid then
    local hours = math.round(ttl / 3600)
    print(("[Veltrix] Key valid (~%d hour%s remaining). Loading..."):format(
        hours, hours ~= 1 and "s" or ""))
    return true
end

-- Invalid from here. Wipe the key ONLY on an explicit server rejection,
-- never on a network error (so a dropped request doesn't nuke a good key).
if reason == "Key is bound to a different account." and writefile then
    pcall(function() writefile(KEY_FILE, "") end)
    print("[Veltrix] Key is bound to a different account.")
elseif reason == "NETWORK_ERROR" then
    print("[Veltrix] Network error.")
else
    print("[Veltrix] " .. (reason ~= "" and reason or "No valid key."))
end

showLoader()
return false
