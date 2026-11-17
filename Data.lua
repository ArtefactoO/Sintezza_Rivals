local addonName, root = ...
local Text, ns = root.Text, root.PvP
local Transfer = Sintezza_Theme.DataTransfer
local invalid = Text("В CSV есть некорректная запись истории PvP.", "The CSV contains an invalid PvP history record.")
local limit = Text("Импорт превысит лимит истории. Выбери меньший раздел.", "Import would exceed the history limit. Use a smaller section.")

local function Plain(value)
    return type(value) == "string" and #value <= 320 and not value:find("[%z\001-\031\127|]")
end

local function Number(value)
    return type(value) == "number" and value == value and math.abs(value) <= 1e12
end

local function Count(value)
    return Number(value) and value >= 0 and value == math.floor(value)
end

local function Stamp(value) return Count(value) and value > 0 end
local function Boolean(value) return type(value) == "boolean" end
local function GUID(value) return Plain(value) and root.IsPlayerGUID(value) end
local function Class(value) return Plain(value) and value:match("^[A-Z]+$") end
local function Choice(value) return value == "win" or value == "loss" or value == "incoming" end

local function Shape(fields, ...)
    local required = { ... }
    return function(value)
        if type(value) ~= "table" then return false end
        for key, field in pairs(value) do
            if not fields[key] or not fields[key](field) then return false end
        end
        for _, key in ipairs(required) do if value[key] == nil then return false end end
        return true
    end
end

local function Array(check, limitCount)
    return function(value)
        if type(value) ~= "table" or #value > limitCount then return false end
        local length = #value
        for index, entry in pairs(value) do
            if not Count(index) or index < 1 or index > length or not check(entry) then return false end
        end
        for index = 1, length do if value[index] == nil then return false end end
        return true
    end
end

local function Fields(base, extra)
    local fields = {}
    for key, check in pairs(base) do fields[key] = check end
    for key, check in pairs(extra) do fields[key] = check end
    return fields
end

local person = { guid = GUID, name = Plain, class = Class, race = Plain, raceName = Plain, faction = Plain,
    guild = Plain, level = Number, damage = Number, share = Number, order = Count, age = Number, source = Plain }
local location = { zone = Plain, subZone = Plain, mapID = Count, x = Number, y = Number, worldX = Number, worldY = Number }
local participants = Array(Shape(person), 100)
local fields = {
    sighting = Fields(person, {
        realm = Plain, firstSeen = Stamp, lastSeen = Stamp, count = Count, isPVP = Boolean,
        posStale = Boolean, lastMapID = Count, lastZone = Plain, lastSubZone = Plain, lastX = Number, lastY = Number,
        worldX = Number, worldY = Number, instanceID = Count, lastSource = Plain, inCombatWhenSeen = Boolean,
        trail = Array(Shape({ x = Number, y = Number, ts = Stamp, mapID = Count }, "x", "y", "ts"), 4),
        hours = function(value)
            if type(value) ~= "table" then return false end
            for hour, count in pairs(value) do
                if not Count(hour) or hour > 23 or not Count(count) then return false end
            end
            return true
        end,
    }),
    world_fight = Fields(person, {
        time = Stamp, result = Choice, started = Stamp, ended = Stamp, location = Shape(location),
        verifiedRecap = Boolean, helpers = participants, players = participants,
        combatAttackers = participants, meterSession = Count, meterStartedAt = Stamp,
    }),
    world_death = Fields(location, {
        ts = Stamp, myLevel = Number, killer = Shape(person), killerSource = Plain, killerClass = Class,
        confidence = Plain, candidates = participants, attackers = participants, combatSeconds = Number,
        verifiedKiller = Boolean, crowd = Count, counted = Boolean,
        combatAttackers = participants, meterSession = Count, meterStartedAt = Stamp,
    }),
    world_incoming = { ts = Stamp, ended = Stamp, location = Shape(location), players = participants,
        meterSession = Count, meterStartedAt = Stamp },
    world_player = { name = Plain, class = Class, lastSeen = Stamp, defeats = Count, kills = Count, recaps = Count },
    world_nemesis = { name = Plain, class = Class, lastEncounter = Stamp, lastZone = Plain, killsOnMe = Count, killedByMe = Count },
    battleground = { name = Plain, time = Stamp, completed = Boolean, closed = Boolean, kills = Count, deaths = Count },
    duel = { ts = Stamp, opponent = Plain, guid = GUID, class = Class, level = Number, race = Plain,
        raceName = Plain, faction = Plain, sameSide = Boolean, won = Boolean, kind = Plain, zone = Plain, seconds = Number },
}
fields.battleground_fight = fields.world_fight

local validate = {
    sighting = Shape(fields.sighting, "lastSeen", "count"),
    world_fight = Shape(fields.world_fight, "time", "result"),
    world_death = Shape(fields.world_death, "ts"),
    world_incoming = Shape(fields.world_incoming, "ts", "players"),
    world_player = Shape(fields.world_player, "lastSeen"),
    world_nemesis = Shape(fields.world_nemesis, "lastEncounter"),
    battleground = Shape(fields.battleground, "time"),
    battleground_fight = Shape(fields.battleground_fight, "time", "result"),
    duel = Shape(fields.duel, "ts", "opponent"),
}

local function Key(...)
    local parts = {}
    for i = 1, select("#", ...) do
        local value = tostring(select(i, ...) or "")
        parts[i] = #value .. ":" .. value
    end
    return table.concat(parts)
end

local function BaseKey(kind, value, parent)
    local killer = value.killer
    local other = value.players and value.players[1]
    local guid = kind ~= "duel" and value.guid or nil
    return Key(kind, parent, value.time or value.ts, value.result or value.kind,
        guid or value.name or value.opponent or (killer and (killer.guid or killer.name))
        or (other and (other.guid or other.name)), value.ended)
end

local function Identity(kind, value, parent, counters)
    local key = BaseKey(kind, value, parent)
    counters[key] = (counters[key] or 0) + 1
    return Key(key, counters[key])
end

local function OrderedKey(kind, value, parent, id)
    local key = BaseKey(kind, value, parent)
    local prefix = #key .. ":" .. key
    local counter = tonumber(id:sub(#prefix + 1):match("^%d+:(%d+)$"))
    return Count(counter) and counter >= 1 and counter <= 500 and id == Key(key, counter)
end

local function Columns(kind, id, value, parent, payload)
    local result = value.result
    if kind == "duel" then result = value.won == nil and "unknown" or (value.won and "win" or "loss") end
    if kind == "battleground" then result = value.completed and "complete" or "partial" end
    local other = value.killer or value.players and value.players[1]
    local player = value.name or value.opponent or (other and other.name) or ""
    local class = value.class or value.killerClass or (other and other.class) or ""
    local zone = value.zone or value.lastZone or (value.location and value.location.zone) or ""
    local stamp = value.time or value.ts or value.lastSeen or value.lastEncounter
    return { kind, id, stamp, result or "", player, class, zone, parent or "", payload }
end

local function SortedKeys(records)
    local result = {}
    for key in pairs(records) do result[#result + 1] = key end
    table.sort(result)
    return result
end

local function Visit(scope, visit)
    local db, localDB = Sintezza_RivalsPvPDB, root.db
    local counters = {}
    local function Include(kind, records)
        for _, value in ipairs(records) do visit(kind, Identity(kind, value, nil, counters), value) end
    end
    if scope == "all" or scope == "encounters" then
        for _, key in ipairs(SortedKeys(db.sightings)) do visit("sighting", key, db.sightings[key]) end
    end
    if scope == "all" or scope == "world" then
        Include("world_fight", localDB.fights)
        Include("world_death", db.deaths)
        Include("world_incoming", db.incoming)
        for _, guid in ipairs(SortedKeys(localDB.players)) do
            local value = localDB.players[guid]
            if (value.defeats or 0) > 0 or (value.kills or 0) > 0 or (value.recaps or 0) > 0 then
                visit("world_player", guid, value)
            end
        end
        for _, key in ipairs(SortedKeys(db.nemesis)) do visit("world_nemesis", key, db.nemesis[key]) end
    end
    if scope == "all" or scope == "battlegrounds" then
        for _, value in ipairs(localDB.battlegrounds) do
            local id = Identity("battleground", value, nil, counters)
            visit("battleground", id, value)
            for _, fight in ipairs(value.fights) do
                visit("battleground_fight", Identity("battleground_fight", fight, id, counters), fight, id)
            end
        end
    end
    if scope == "all" or scope == "duels" then Include("duel", db.duels) end
end

local function Export(scope)
    local rows, problem = {}
    Visit(scope, function(kind, id, source, parent)
        if problem then return end
        local record = {}
        for key in pairs(fields[kind]) do record[key] = source[key] end
        local payload, issue = Transfer:EncodeRecord(record)
        if not payload then problem = issue or invalid; return end
        rows[#rows + 1] = Columns(kind, id, record, parent, payload)
    end)
    if problem then return nil, problem end
    return rows
end

local CAPS = { sighting = ns.SIGHTING_LIMIT, world_fight = 100, world_death = 100, world_incoming = 100, world_player = 5000,
    world_nemesis = 300, battleground = 30, duel = 200 }

local function Stage(rows)
    local known, totals, matches, fightCounts = {}, {}, {}, {}
    Visit("all", function(kind, id, value, parent)
        known[Key(kind, id)] = true
        totals[kind] = (totals[kind] or 0) + 1
        if kind == "battleground" then matches[id] = value end
        if parent then fightCounts[parent] = (fightCounts[parent] or 0) + 1 end
    end)
    for guid in pairs(root.db.players) do known[Key("world_player", guid)] = true end
    local plan = { added = 0, duplicates = 0, rows = {}, matches = matches }
    for _, row in ipairs(rows) do
        local kind, id, parent = row[1], row[2], row[8]
        local value = Transfer:DecodeRecord(row[9])
        if not validate[kind] or not validate[kind](value) then return nil, invalid end
        if kind == "sighting" then
            if not Plain(id) or id == "" or (value.guid and value.guid ~= id)
                or (not value.guid and id ~= (value.name or "") .. "-" .. (value.realm or "")) then return nil, invalid end
        elseif kind == "world_nemesis" then
            if not Plain(id) or id == "" or (not GUID(id) and id ~= value.name) then return nil, invalid end
        elseif kind == "world_player" then
            if not GUID(id) then return nil, invalid end
        elseif not OrderedKey(kind, value, parent, id) then
            return nil, invalid
        end
        if (kind == "battleground_fight") ~= (parent ~= "") then return nil, invalid end
        local columns = Columns(kind, id, value, parent, row[9])
        for index = 1, 8 do
            if tostring(columns[index]) ~= tostring(row[index]) then return nil, invalid end
        end
        local key = Key(kind, id)
        if known[key] then
            plan.duplicates = plan.duplicates + 1
        else
            known[key] = true
            totals[kind] = (totals[kind] or 0) + 1
            if CAPS[kind] and totals[kind] > CAPS[kind] then return nil, limit end
            if kind == "battleground" then
                value.fights, value.closed = {}, true
                matches[id] = value
            elseif parent ~= "" then
                fightCounts[parent] = (fightCounts[parent] or 0) + 1
                if fightCounts[parent] > 300 then return nil, limit end
            end
            plan.added = plan.added + 1
            plan.rows[#plan.rows + 1] = { kind = kind, id = id, value = value, parent = parent }
        end
    end
    for _, row in ipairs(plan.rows) do
        if row.parent ~= "" and not matches[row.parent] then return nil, invalid end
    end
    return plan
end

local function AddSighting(db, id, value)
    db.sightings[id] = value
    db.sightingStats.total = (db.sightingStats.total or 0) + 1
    if value.lastMapID then
        local zone = db.zones[value.lastMapID] or { sightings = 0, deaths = 0, kills = 0 }
        db.zones[value.lastMapID] = zone
        zone.sightings = (zone.sightings or 0) + value.count
        zone.lastActivity = math.max(zone.lastActivity or 0, value.lastSeen)
        zone.name = zone.name or value.lastZone
    end
end

local function Ordered(records, field, oldestFirst, openFirst)
    local order = {}
    for index, value in ipairs(records) do order[value] = index end
    table.sort(records, function(a, b)
        if openFirst and (a.closed == true) ~= (b.closed == true) then return b.closed == true end
        local first, second = tonumber(a[field]) or 0, tonumber(b[field]) or 0
        if first == second then return order[a] < order[b] end
        if oldestFirst then return first < second end
        return first > second
    end)
end

local function Apply(plan)
    local db, localDB = Sintezza_RivalsPvPDB, root.db
    local touched = {}
    local addedSightings
    for _, row in ipairs(plan.rows) do
        local kind, id, value = row.kind, row.id, row.value
        if kind == "sighting" then
            AddSighting(db, id, value)
            addedSightings = true
        elseif kind == "world_fight" then
            table.insert(localDB.fights, value)
        elseif kind == "world_death" then
            table.insert(db.deaths, value)
        elseif kind == "world_incoming" then
            table.insert(db.incoming, value)
        elseif kind == "world_player" then
            if not localDB.players[id] then localDB.players[id] = value end
        elseif kind == "world_nemesis" then
            db.nemesis[id] = value
        elseif kind == "battleground" then
            table.insert(localDB.battlegrounds, value)
        elseif kind == "battleground_fight" then
            local match = plan.matches[row.parent]
            table.insert(match.fights, value)
            touched[match] = true
        elseif kind == "duel" then
            table.insert(db.duels, value)
        end
    end
    if addedSightings and ns.Sightings and ns.Sightings.InvalidateRetention then
        ns.Sightings:InvalidateRetention()
    end
    Ordered(localDB.fights, "time")
    Ordered(localDB.battlegrounds, "time", false, true)
    for match in pairs(touched) do Ordered(match.fights, "time") end
    Ordered(db.deaths, "ts", true)
    Ordered(db.incoming, "ts", true)
    Ordered(db.duels, "ts", true)
    ns.Duels:PruneWorldDamage()
    return true
end

local function ClearEncounters()
    local db = Sintezza_RivalsPvPDB
    db.sightings = {}
    db.sightingStats = { total = 0, secretFields = {} }
    for mapID, zone in pairs(db.zones) do
        zone.sightings = 0
        if (zone.deaths or 0) == 0 and (zone.kills or 0) == 0 then db.zones[mapID] = nil end
    end
    return true
end

local function ClearWorld()
    local db = Sintezza_RivalsPvPDB
    ns.Deaths:ClearWorldRecording()
    db.deaths, db.incoming, db.nemesis, db.kills = {}, {}, {}, nil
    for _, zone in pairs(db.zones) do zone.deaths, zone.kills = 0, 0 end
    for guid, value in pairs(root.db.players) do
        if value.manual then
            value.kills, value.recaps, value.defeats = 0, 0, nil
        else
            root.db.players[guid] = nil
        end
    end
    root.ClearWorldHistory()
    return true
end

local encounterLabel = Text("Встречи", "Encounters")
local worldLabel = Text("Бои в мире", "World fights")
local battlegroundLabel = Text("Матчи на полях боя", "Battleground matches")
local duelLabel = Text("Дуэли", "Duels")
root.DataTransferSpec = {
    addon = addonName,
    title = Text("История PvP", "PvP history"),
    note = Text("Замер включает код, интерфейс и данные аддона. Управление данными действует для текущего персонажа.",
        "Memory includes addon code, interface, and data. Data management applies to the current character."),
    columns = { "type", "id", "time", "result", "player", "class", "zone", "parent_id", "payload" },
    scopes = {
        { key = "all", label = Text("Все записи", "All records") },
        { key = "encounters", label = encounterLabel }, { key = "world", label = worldLabel },
        { key = "battlegrounds", label = battlegroundLabel }, { key = "duels", label = duelLabel },
    },
    export = Export,
    stage = Stage,
    apply = Apply,
    sections = {
        { label = encounterLabel, count = function() return ns.Count(Sintezza_RivalsPvPDB.sightings) end, clear = ClearEncounters },
        { label = worldLabel, count = function()
            local db = Sintezza_RivalsPvPDB
            local outcomes = root.PvPSource and root.PvPSource:WorldOutcomes(db)
            return (outcomes and #outcomes or #root.db.fights + #db.deaths) + #db.incoming
        end, clear = ClearWorld },
        { label = battlegroundLabel, count = function() return #root.db.battlegrounds end, clear = function()
            root.ClearBattlegroundHistory()
            return true
        end },
        { label = duelLabel, count = function() return #Sintezza_RivalsPvPDB.duels end, clear = function()
            ns.Duels:StopRecording()
            Sintezza_RivalsPvPDB.duels = {}
            return true
        end },
        { label = Text("Список наблюдения", "Watchlist"), count = function() return ns.Count(Sintezza_RivalsPvPDB.watch) end,
            clear = function() Sintezza_RivalsPvPDB.watch = {}; return true end },
        { label = Text("Список игнора", "Ignore list"), count = function() return ns.Count(Sintezza_RivalsPvPDB.ignore) end,
            clear = function() Sintezza_RivalsPvPDB.ignore = {}; return true end },
    },
    changed = function()
        if ns.Map then ns.Map:Update() end
        if ns.UI then
            ns.UI:MarkDirty()
            ns.UI:Refresh()
        end
        root.Changed()
    end,
}
