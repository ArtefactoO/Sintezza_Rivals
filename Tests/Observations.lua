local source, previous = ...
local nativePairs = pairs
if previous then previous = previous:gsub("local CAP = 500", "local CAP = 1000", 1) end
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end

local function serialize(value)
    if type(value) ~= "table" then return type(value) .. ":" .. tostring(value) end
    local fields = {}
    for key, item in nativePairs(value) do
        fields[#fields + 1] = serialize(key) .. "=" .. serialize(item)
    end
    table.sort(fields)
    return "{" .. table.concat(fields, ",") .. "}"
end

local function exercise(code, size, mode, context)
    local clock, visits = 100000, 0
    local calls = {}
    local ns = { modules = {}, context = context or "world", SIGHTING_LIMIT = 1000 }
    local root = { PvP = ns, ClassName = function(value) return value end }
    ns.Safe = function(value) return value end
    ns.L = function(value) return value end
    ns.Ago = function(value) return tostring(value) end
    ns.UnitCharacterName = function() return mode ~= "unreadable" and "Alma Enemy" or nil end
    ns.IsRecording = function() return mode ~= "disabled" end
    ns.Notify = function(_, ...)
        local message = {}
        for index = 1, select("#", ...) do message[index] = tostring(select(index, ...)) end
        calls[#calls + 1] = table.concat(message, "|")
    end
    ns.Deaths = { Contact = function(_, record, via)
        calls[#calls + 1] = "contact:" .. tostring(record.guid) .. ":" .. via
    end }
    ns.Watchlist = { IsWatched = function() return mode == "watched" or mode == "ignored" end }
    ns.UI = {
        MarkDirty = function() calls[#calls + 1] = "dirty" end,
        Banner = function(_, text, detail) calls[#calls + 1] = text .. ":" .. detail end,
    }
    local records = {}
    for index = 1, size do
        local timestamp = mode == "ties" and 10 or clock - size + index
        records["Player-" .. index] = { guid = "Player-" .. index, name = "Enemy " .. index,
            lastSeen = index % 13 ~= 0 and timestamp or nil, count = index % 7 }
    end
    if mode == "dedupe" or mode == "repeat" then
        records["Player-new"] = { guid = "Player-new", lastSeen = clock - (mode == "dedupe" and 10 or 120), count = 2 }
    end
    local db = {
        sightings = records, zones = {}, ignore = mode == "ignored" and { ["Player-new"] = true } or {},
        sightingStats = { total = size, secretFields = {} },
        settings = {
            sightings = { dedupeSeconds = 60 },
            alerts = { chat = { sighting = true }, banner = true, soundOnSighting = true, stealthCast = true },
        },
    }
    Sintezza_RivalsPvPDB = db
    GetServerTime = function() return clock end
    date = function() return "12" end
    UnitExists = function() return mode ~= "missing" end
    UnitIsPlayer = function() return mode ~= "npc" end
    UnitIsUnit = function() return mode == "self" end
    UnitCanAttack = function() return mode ~= "friendly" end
    UnitGUID = function() return mode ~= "unreadable" and "Player-new" or nil end
    UnitName = function() return "Alma", "Realm" end
    UnitClass = function() return "Priest", "PRIEST" end
    UnitRace = function() return "Human", "Human" end
    GetGuildInfo = function() return "Guild" end
    UnitLevel = function() return 60 end
    UnitFactionGroup = function() return "Horde" end
    UnitIsPVP = function() return true end
    GetRealZoneText = function() return "Zone" end
    GetSubZoneText = function() return "Subzone" end
    UnitPosition = function() return 200, 100, 0, 1 end
    UnitOnTaxi = function() return false end
    C_Map = {
        GetBestMapForUnit = function() return 42 end,
        GetPlayerMapPosition = function() return { GetXY = function() return .25, .75 end } end,
    }
    SOUNDKIT = { RAID_WARNING = 1 }
    PlaySound = function(id) calls[#calls + 1] = "sound:" .. id end
    pairs = function(tableValue)
        local iterator, state, first = nativePairs(tableValue)
        if tableValue ~= records then return iterator, state, first end
        return function(...)
            local key, value = iterator(...)
            if key ~= nil then visits = visits + 1 end
            return key, value
        end, state, first
    end
    local chunk, error = loadstring(code)
    assert(chunk, error)
    chunk("Sintezza_Rivals", root)
    ns.Sightings:Consider("target", "target")
    pairs = nativePairs

    local valid = mode ~= "disabled" and mode ~= "missing" and mode ~= "npc"
        and mode ~= "self" and mode ~= "friendly" and mode ~= "unreadable"
        and ns.context ~= "arena"
    local expected = valid and math.min(1000, size + 1) or size
    -- The legacy collector postponed overflow cleanup while a record was inside dedupe.
    if previous and code == previous and not ns.Sightings.Init and mode == "dedupe" then expected = size + 1 end
    local actual = 0
    for _ in nativePairs(records) do actual = actual + 1 end
    check(actual == expected, "archive capacity or recording gate changed: " .. size .. "/" .. mode .. " got " .. actual .. " expected " .. expected)
    if valid then
        local record = assert(records["Player-new"])
        check(record.name == "Alma Enemy" and record.class == "PRIEST", "opponent identity lost")
        check(record.lastMapID == 42 and record.lastX == .25 and record.lastY == .75, "map data lost")
        check(record.guild == "Guild" and record.faction == "Horde", "profile details lost")
        check(calls[1] == "contact:Player-new:target", "death-contact data lost")
    end
    if mode == "ignored" then
        local cast
        for index = 1, 30 do
            local key, value = debug.getupvalue(ns.Sightings.Enable, index)
            if not key then break end
            if key == "onCastStart" then cast = value; break end
        end
        check(cast ~= nil, "missing stealth event handler")
        cast(nil, "nameplate1", nil, 1784)
        local messages = serialize(calls)
        check(not messages:find("sighting|", 1, true) and not messages:find("watched|", 1, true)
            and not messages:find("sound:", 1, true), "ignored player still triggers an encounter or stealth alert")
    end
    return db, serialize(calls), visits, ns
end

local function compare(current, baseline)
    local function timestamps(records)
        local values = {}
        for _, record in nativePairs(records) do values[#values + 1] = record.lastSeen or 0 end
        table.sort(values, function(a, b) return a > b end)
        while #values > 1000 do values[#values] = nil end
        return serialize(values)
    end
    local first, second = current.sightings, baseline.sightings
    check(timestamps(first) == timestamps(second), "archive keeps different observation ages")
    local same = true
    for key, record in nativePairs(first) do
        if second[key] and serialize(record) ~= serialize(second[key]) then same = false; break end
    end
    check(same, "retained opponent details differ from baseline")
    current.sightings, baseline.sightings = nil, nil
    check(serialize(current) == serialize(baseline), "metadata outside retention differs")
    current.sightings, baseline.sightings = first, second
end

local scenarios = 0
for _, size in ipairs({ 0, 1, 49, 499, 500, 999, 1000, 1001, 2000 }) do
    for _, mode in ipairs({ "normal", "ties", "watched", "dedupe", "repeat",
        "disabled", "missing", "npc", "self", "friendly", "unreadable" }) do
        local current, events, visits = exercise(source, size, mode)
        scenarios = scenarios + 1
        if previous then
            local baseline, oldEvents, oldVisits = exercise(previous, size, mode)
            compare(current, baseline)
            check(events == oldEvents, "alerts or contacts differ from baseline")
        end
    end
end
local current, events = exercise(source, 500, "normal", "arena")
if previous then
    local baseline, oldEvents = exercise(previous, 500, "normal", "arena")
    compare(current, baseline)
    check(events == oldEvents, "instance recording gate changed")
end
exercise(source, 500, "ignored")
local audioDB, _, _, audioNS = exercise(source, 0, 'normal')
local sounds = {}
SOUNDKIT = { RAID_WARNING = 1, UI_RAID_BOSS_WHISPER_WARNING = 2 }
PlaySound = function(id) sounds[#sounds + 1] = id; return true end
check(audioNS.Sightings:CanPlayAlertSound() and audioNS.Sightings:HasAlternateAlertSound(), 'client sound capability detection')
check(audioNS.Sightings:PlayAlertSound(false) and sounds[#sounds] == 1, 'normal sound preview')
check(audioNS.Sightings:PlayAlertSound(true) and sounds[#sounds] == 2, 'alternate sound preview')
local record = { name = 'Watched Enemy', class = 'ROGUE', level = 60, lastZone = 'Zone' }
audioDB.settings.alerts.soundOnSighting = false
local before = #sounds
audioNS.Sightings:WatchAlert('muted', record, 'target')
check(#sounds == before, 'disabled automatic sound should stay silent')
audioDB.settings.alerts.soundOnSighting, audioDB.settings.alerts.stealthSound = true, true
audioNS.Sightings:WatchAlert('audible', record, 'target')
check(#sounds == before + 1 and sounds[#sounds] == 2, 'watched rogue should use the configured alternate sound')
UnitOnTaxi = function() return true end
audioNS.Sightings:WatchAlert('taxi', record, 'target')
check(#sounds == before + 1, 'taxi should suppress automatic alert sound')
UnitOnTaxi = function() return false end
PlaySound = function() return false end
check(not audioNS.Sightings:PlayAlertSound(false), 'failed native sound call must be reported')
SOUNDKIT = {}
check(not audioNS.Sightings:CanPlayAlertSound() and not audioNS.Sightings:PlayAlertSound(false), 'missing sound kits must not expose a false capability')
SOUNDKIT = { RAID_WARNING = 1 }
PlaySound = function(id) sounds[#sounds + 1] = id; return true end
check(not audioNS.Sightings:HasAlternateAlertSound() and audioNS.Sightings:PlayAlertSound(true) and sounds[#sounds] == 1,
    'one available kit should retain a working fallback without pretending to offer two sounds')
return checks, scenarios + 3
