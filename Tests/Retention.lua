local source = ...
local nativePairs = pairs
local checks, scenarios = 0, 0
local metrics = {}
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end

local function seen(record)
    local value = type(record) == "table" and tonumber(record.lastSeen) or 0
    return value and value == value and value or 0
end

local function seed(size, tied)
    local records = {}
    for index = 1, size do
        local key = "Player-" .. index
        records[key] = { guid = key, name = "Enemy " .. index, count = 0,
            lastSeen = index % 13 ~= 0 and (tied and 10 or 50000 + index) or nil }
    end
    return records
end

local function times(records)
    local values = {}
    for key, record in nativePairs(records) do values[key] = seen(record) end
    return values
end

local function prune(values)
    local keys = {}
    for key in nativePairs(values) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        if values[a] == values[b] then return tostring(a) > tostring(b) end
        return values[a] > values[b]
    end)
    for index = 1001, #keys do values[keys[index]] = nil end
end

local function heapOf(sightings)
    local searched = {}
    local function find(fn)
        if searched[fn] then return end
        searched[fn] = true
        for index = 1, 40 do
            local name, value = debug.getupvalue(fn, index)
            if not name then break end
            if name == "retentionHeap" then return value end
            if type(value) == "function" then
                local found = find(value)
                if found then return found end
            end
        end
    end
    return assert(find(sightings.InvalidateRetention), "retention heap is unavailable")
end

local function machine(records)
    local state = { clock = 100000, key = "Player-new", visits = 0 }
    local ns = { modules = {}, context = "world", SIGHTING_LIMIT = 1000 }
    local root = { PvP = ns, ClassName = function(value) return value end }
    ns.Safe = function(value) return value end
    ns.L = function(value) return value end
    ns.Ago = tostring
    ns.UnitCharacterName = function() return "Enemy " .. state.key end
    ns.IsRecording = function() return true end
    ns.Notify = function() end
    ns.UI = { MarkDirty = function() end }
    ns.Deaths = { Contact = function() end }
    ns.Watchlist = { IsWatched = function() return false end }
    local db = {
        sightings = records, zones = {}, ignore = {},
        sightingStats = { total = 0, secretFields = {} },
        settings = {
            sightings = { dedupeSeconds = 60 },
            alerts = { chat = { sighting = false }, watchSeconds = 20 },
        },
    }
    local env = setmetatable({
        Sintezza_RivalsPvPDB = db,
        GetServerTime = function() return state.clock end,
        date = function() return "12" end,
        UnitExists = function() return true end,
        UnitIsPlayer = function() return true end,
        UnitIsUnit = function() return false end,
        UnitCanAttack = function() return true end,
        UnitGUID = function() return state.key end,
        UnitName = function() return "Enemy", "Realm" end,
        UnitClass = function() return "Priest", "PRIEST" end,
        UnitRace = function() return "Human", "Human" end,
        GetGuildInfo = function() return "Guild" end,
        UnitLevel = function() return 60 end,
        UnitFactionGroup = function() return "Horde" end,
        UnitIsPVP = function() return true end,
        GetRealZoneText = function() return "Zone" end,
        GetSubZoneText = function() return "Subzone" end,
        UnitPosition = function() return 200, 100, 0, 1 end,
        UnitOnTaxi = function() return false end,
        C_Map = {
            GetBestMapForUnit = function() return 42 end,
            GetPlayerMapPosition = function() return { GetXY = function() return .25, .75 end } end,
        },
    }, { __index = _G })
    env._G = env
    env.pairs = function(value)
        local iterator, container, first = nativePairs(value)
        if value ~= db.sightings then return iterator, container, first end
        return function(...)
            local key, item = iterator(...)
            if key ~= nil then state.visits = state.visits + 1 end
            return key, item
        end, container, first
    end
    local chunk = assert(loadstring(source))
    setfenv(chunk, env)
    chunk("Sintezza_Rivals", root)
    local current = { ns = ns, db = db, state = state }
    function current:Observe(key, timestamp, via)
        state.key, state.clock = key, timestamp
        ns.Sightings:Consider("target", via or "target")
    end
    function current:Check(expected)
        local total = 0
        for key, record in nativePairs(db.sightings) do
            total = total + 1
            check(expected[key] == seen(record), "unexpected retained key or age: " .. key)
        end
        local expectedCount = 0
        for key in nativePairs(expected) do
            expectedCount = expectedCount + 1
            check(db.sightings[key] ~= nil, "missing retained key: " .. key)
        end
        check(total == expectedCount and total <= 1000, "archive exceeds the shared cap")
        local heap = heapOf(ns.Sightings)
        check(#heap == total and #heap <= 1000, "index exceeds the archive bound")
        local keys = {}
        for _, entry in ipairs(heap) do
            check(not keys[entry.key] and db.sightings[entry.key] ~= nil, "stale or duplicate index node")
            check(entry.seen == seen(db.sightings[entry.key]), "stale indexed timestamp")
            keys[entry.key] = true
        end
    end
    return current
end

-- Warm updates must never traverse the archive or allocate replacement heap nodes.
local initial = seed(1000)
local expected = times(initial)
local warm = machine(initial)
warm.ns.Sightings:Init()
prune(expected)
warm:Check(expected)
metrics.warmupArchiveVisits = warm.state.visits
local originalNodes = {}
for _, node in ipairs(heapOf(warm.ns.Sightings)) do originalNodes[node] = true end
warm.state.visits = 0
for index = 1, 50 do
    local key, timestamp = "Player-" .. index, 100000 + index
    warm:Observe(key, timestamp)
    expected[key] = timestamp
    prune(expected)
end
warm:Check(expected)
check(warm.state.visits == 0, "known observations traversed the archive")
metrics.known50ArchiveVisits = warm.state.visits

local beforeCount = warm.db.sightings["Player-1"].count
for _, via in ipairs({ "target", "nameplate", "mouseover" }) do warm:Observe("Player-1", 100001, via) end
check(warm.db.sightings["Player-1"].count == beforeCount, "duplicate sources changed the encounter count")
check(warm.state.visits == 0, "duplicate sources traversed the archive")
warm:Check(expected)
scenarios = scenarios + 1

for index = 1, 50 do
    local key, timestamp = "Player-insert-" .. index, 100100 + index
    warm:Observe(key, timestamp)
    expected[key] = timestamp
    prune(expected)
end
warm:Check(expected)
check(warm.state.visits == 0, "new observations traversed a warm archive")
metrics.new50ArchiveVisits = warm.state.visits
local newNodes = 0
for _, node in ipairs(heapOf(warm.ns.Sightings)) do
    if not originalNodes[node] then newNodes = newNodes + 1 end
end
check(newNodes == 0, "full-index inserts allocated extra nodes")
metrics.heapNodesAllocatedFor50FullInserts = newNodes
scenarios = scenarios + 1

-- A server clock moving backward must repair the heap in either direction.
local futureRecords = seed(1000)
for _, record in nativePairs(futureRecords) do record.lastSeen = record.lastSeen or 50000 end
futureRecords["Player-1"].lastSeen = 500000
local future = machine(futureRecords)
local futureExpected = times(futureRecords)
future.ns.Sightings:Init()
prune(futureExpected)
future:Observe("Player-1", 5)
futureExpected["Player-1"] = 5
prune(futureExpected)
future:Check(futureExpected)
future:Observe("Player-later", 6)
futureExpected["Player-later"] = 6
prune(futureExpected)
future:Check(futureExpected)
check(future.db.sightings["Player-1"] == nil, "a backward timestamp left the wrong record indexed")
scenarios = scenarios + 1

for _, size in ipairs({ 0, 1, 999, 1000, 1001, 2000, 10000 }) do
    local archived = seed(size, true)
    local expectedAges = times(archived)
    local current = machine(archived)
    current.ns.Sightings:Init()
    prune(expectedAges)
    current:Check(expectedAges)
    check(current.state.visits == size * 2, "cold archive requires more than two traversals")
    if size == 2000 then metrics.cold2000ArchiveVisits = current.state.visits end
    current:Observe("Player-fresh", 100000)
    expectedAges["Player-fresh"] = 100000
    prune(expectedAges)
    current:Check(expectedAges)
    scenarios = scenarios + 1
end

-- CSV writers replace or extend records in place and explicitly invalidate the index.
local importedRecords = seed(1000)
local imported = machine(importedRecords)
imported.ns.Sightings:Init()
for index = 1, 500 do
    local key = "Imported-" .. index
    imported.db.sightings[key] = { guid = key, lastSeen = 90000 + index, count = 1 }
end
imported.db.sightings["Player-2"] = { guid = "Player-2", lastSeen = 1, count = 3 }
local importExpected = times(imported.db.sightings)
imported.ns.Sightings:InvalidateRetention()
check(#heapOf(imported.ns.Sightings) == 0, "import invalidation retains stale index nodes")
imported.state.visits = 0
imported:Observe("Player-import-touch", 100500)
importExpected["Player-import-touch"] = 100500
prune(importExpected)
imported:Check(importExpected)
check(imported.state.visits == 3002, "import rebuilding traversed more than twice")
scenarios = scenarios + 1

-- Replacing the table is enough to invalidate an index, including an account clear.
local replacement = seed(1200)
imported.db.sightings = replacement
local replacementExpected = times(replacement)
imported.state.visits = 0
imported:Observe("Player-table-switch", 100600)
replacementExpected["Player-table-switch"] = 100600
prune(replacementExpected)
imported:Check(replacementExpected)
check(imported.state.visits == 2402, "replacement table was not rebuilt once")
local weakOld = setmetatable({ imported.db.sightings }, { __mode = "v" })
imported.db.sightings = {}
replacement = nil
collectgarbage("collect")
check(weakOld[1] == nil, "retention strongly holds a replaced archive")
imported:Observe("Player-after-clear", 100700)
imported:Check({ ["Player-after-clear"] = 100700 })
scenarios = scenarios + 1

-- A failed consumer cannot leave an updated timestamp out of the retention index.
local failing = machine(seed(1000))
local failureExpected = times(failing.db.sightings)
failing.ns.Sightings:Init()
prune(failureExpected)
failing.ns.Deaths.Contact = function() error("consumer failed") end
local ok = pcall(failing.Observe, failing, "Player-callback-failure", 200000)
check(not ok, "consumer failure was unexpectedly swallowed")
failureExpected["Player-callback-failure"] = 200000
prune(failureExpected)
failing:Check(failureExpected)
failing.ns.Deaths.Contact = function() end
failing:Observe("Player-recovery", 200001)
failureExpected["Player-recovery"] = 200001
prune(failureExpected)
failing:Check(failureExpected)
scenarios = scenarios + 1

-- Arrival order has no influence on which equal-age keys survive the cutoff.
local first, second = seed(2000, true), {}
for key, record in nativePairs(first) do
    second[key] = { guid = key, lastSeen = record.lastSeen, count = record.count }
end
local a, b = machine(first), machine(second)
local tieExpected = times(first)
prune(tieExpected)
a.ns.Sightings:Init()
b.ns.Sightings:Init()
a:Check(tieExpected)
b:Check(tieExpected)
scenarios = scenarios + 1

return checks, scenarios, metrics
