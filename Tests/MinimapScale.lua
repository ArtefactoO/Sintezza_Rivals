local current, previous = ...
local nativePairs, nativeIpairs = pairs, ipairs
local checks = 0
local function check(value, message) checks = checks + 1; assert(value, message) end

local function serialize(value)
    if type(value) ~= "table" then return type(value) .. ":" .. tostring(value) end
    local entries = {}
    for key, item in nativePairs(value) do entries[#entries + 1] = serialize(key) .. "=" .. serialize(item) end
    table.sort(entries)
    return "{" .. table.concat(entries, ",") .. "}"
end

local function exercise(code, count, mode)
    local visible, enabled, module, radius, here = true, true, true, 100, 1
    local stats = { sightings = 0, deaths = 0, watched = 0 }
    local sightings, deaths, widgets = {}, {}, {}
    local stamp = 100000
    for i = 1, count do
        sightings["Player-" .. i] = {
            guid = "Player-" .. i, class = "WARRIOR", lastMapID = 1, lastSeen = stamp - 10,
            worldX = 0, worldY = 0, instanceID = 1,
        }
    end
    for i = 1, 40 do deaths[i] = { guid = "Death-" .. i, worldX = 0, worldY = 0, ts = stamp - 10 } end
    local cfg = { enabled = true, minutes = 30, watchedOnly = false, deaths = false }
    local expected = 30
    if mode == "watched" then
        cfg.watchedOnly = true
        expected = math.floor(count / 100)
    elseif mode == "stale" then
        for _, rec in nativePairs(sightings) do
            local id = tonumber(rec.guid:match("%d+$"))
            if id > 25 then rec.lastSeen = 0 end
        end
        expected = 25
    elseif mode == "other-zone" then
        for _, rec in nativePairs(sightings) do rec.lastMapID = 2 end
        expected = 0
    elseif mode == "no-world" or mode == "deaths" then
        for _, rec in nativePairs(sightings) do rec.worldX, rec.worldY, rec.noWorld = nil, nil, true end
        cfg.deaths = mode == "deaths"
        expected = cfg.deaths and 30 or 0
    elseif mode == "mixed" then
        for _, rec in nativePairs(sightings) do
            if tonumber(rec.guid:match("%d+$")) > 20 then rec.lastSeen = 0 end
        end
        cfg.deaths = true
    elseif mode == "zero-radius" then radius = 0; expected = 0
    elseif mode == "unknown-zone" then here = nil; expected = 0
    elseif mode == "module-off" then module = false; expected = 0 end

    local methods = {}
    local minimap = {
        IsVisible = function() return visible end, GetWidth = function() return 200 end,
        GetHeight = function() return 200 end, GetFrameLevel = function() return 1 end,
    }
    function methods:SetFrameStrata() end
    function methods:SetFrameLevel() end
    function methods:EnableMouse() end
    function methods:SetScript(key, callback) self.scripts[key] = callback end
    function methods:HookScript(key, callback)
        local previous = self.scripts[key]
        self.scripts[key] = function(...) if previous then previous(...) end; callback(...) end
    end
    function methods:ClearAllPoints() self.x, self.y = nil, nil end
    function methods:SetPoint(_, _, _, x, y) self.x, self.y = x, y end
    function methods:Show() self.shown = true end
    function methods:Hide() self.shown = false end
    local ns = { modules = {}, Safe = function(value) return value end,
        Module = function() return module end,
        Map = { Dress = function() end, Paint = function() end },
        Watchlist = { IsWatched = function(_, key)
            stats.watched = stats.watched + 1
            return tonumber(key:match("%d+$")) % 100 == 0
        end },
        Sightings = { PlayerMap = function() return here end },
        Guard = function(_, fn) fn() end,
    }
    local root = { PvP = ns }
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.Sintezza_Theme = { CreateWidgets = function() return { Tooltip = function() end } end, HideTooltip = function() end }
    env.Sintezza_RivalsPvPDB = { sightings = sightings, deaths = deaths, settings = { minimap = cfg } }
    env.GetServerTime = function() return stamp end
    env.UnitPosition = function() return 0, 0, 0, 1 end
    env.Minimap = minimap
    env.C_Minimap = { GetViewRadius = function() return radius end }
    env.GetCVar = function() return "0" end
    local timer
    env.C_Timer = { NewTicker = function(_, callback) timer = callback; return {} end }
    env.CreateFrame = function()
        local item = setmetatable({ shown = false, scripts = {} }, { __index = methods })
        widgets[#widgets + 1] = item
        return item
    end
    env.pairs = function(tbl)
        if tbl ~= sightings then return nativePairs(tbl) end
        return function(t, key)
            local nextKey, value = next(t, key)
            if nextKey ~= nil then stats.sightings = stats.sightings + 1 end
            return nextKey, value
        end, tbl
    end
    env.ipairs = function(tbl)
        if tbl ~= deaths then return nativeIpairs(tbl) end
        return function(t, index)
            index = index + 1
            if t[index] then stats.deaths = stats.deaths + 1; return index, t[index] end
        end, tbl, 0
    end
    local fn = assert(loadstring(code, "Minimap.lua"))
    setfenv(fn, env)("Sintezza_Rivals", root)
    local pins = ns.MinimapPins
    pins:Update()
    local initial = {}
    for _, item in nativeIpairs(widgets) do
        if item.shown then initial[#initial + 1] = {
            kind = item.kind, guid = item.rec.guid, watched = item.watched, edge = item.onEdge,
            x = item.x, y = item.y,
        } end
    end
    check(pins.lastCount == expected and #initial == expected, mode .. " pin count")
    check(#widgets <= 30, mode .. " pool remains bounded")
    local scanned = { sightings = stats.sightings, deaths = stats.deaths, watched = stats.watched }
    pins:Enable()
    visible = false
    stats.sightings, stats.deaths, stats.watched = 0, 0, 0
    timer()
    check(stats.sightings == 0 and stats.deaths == 0 and stats.watched == 0,
        "Hidden minimap ticker skips collection")
    pins:Update()
    check(pins.lastCount == 0, "Direct hidden update hides pooled pins")
    for _, item in nativeIpairs(widgets) do check(not item.shown, "Hidden pin") end
    visible, cfg.enabled = true, false
    stats.sightings, stats.deaths, stats.watched = 0, 0, 0
    pins:Update()
    check(stats.sightings == 0 and stats.deaths == 0 and stats.watched == 0,
        "Disabled minimap skips collection")
    return initial, scanned
end

local cases = { "default", "watched", "stale", "other-zone", "no-world", "deaths", "mixed",
    "zero-radius", "unknown-zone", "module-off" }
local measurements = {}
for _, size in ipairs({ 500, 1000, 2000 }) do
    for _, mode in ipairs(cases) do
        local output, scanned = exercise(current, size, mode)
        if previous then
            local original, before = exercise(previous, size, mode)
            check(serialize(output) == serialize(original), "Original pin output retained: " .. mode)
            if mode == "default" then
                check(scanned.sightings == 31 and scanned.watched == 30, "Stop after 30 sighting pins")
                check(before.sightings == size and before.watched == size, "Baseline walks the archive")
            elseif mode == "deaths" then
                check(scanned.deaths == 31 and before.deaths == 40, "Stop after 30 death pins")
            elseif mode == "mixed" then
                check(scanned.deaths == 11 and before.deaths == 40, "Stop after remaining death-pin slots")
            end
        end
        measurements[#measurements + 1] = { size = size, mode = mode, counters = scanned }
    end
end
return checks, #cases * 3, measurements
