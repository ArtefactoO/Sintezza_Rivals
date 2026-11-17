local sources = ...
local nativePairs, nativeIPairs = pairs, ipairs
local result = { checks = 0, failures = {}, cases = {}, metrics = {} }

local function Check(value, message)
    result.checks = result.checks + 1
    if not value then result.failures[#result.failures + 1] = message end
end

local function Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, item in nativePairs(value) do out[key] = Copy(item) end
    return out
end

local function Harness(useRealCodec)
    local state = { clock = 0, serverBase = 100000, combat = false, sessionID = 101,
        spellRows = {}, sessionRows = {}, recap = {}, timers = {}, frames = {}, units = {}, rows = {},
        metrics = { sessionReads = 0, sourceReads = 0, recapReads = 0, hasRecapReads = 0, spellVisits = 0, sorts = 0, mapIDReads = 0, mapPositionReads = 0, worldPositionReads = 0, zoneReads = 0, subZoneReads = 0 },
        secrets = {}, inaccessible = {}, notifications = {}, codec = {}, nextPayload = 0 }
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.GetServerTime = function() return state.serverBase + math.floor(state.clock) end
    env.GetTime = function() return state.clock end
    env.time = env.GetServerTime
    env.date = function() return "12" end
    env.issecretvalue = function(value) return state.secrets[value] == true end
    env.canaccesstable = function(value) return not state.inaccessible[value] and not state.secrets[value] end
    env.wipe = function(value) for key in nativePairs(value) do value[key] = nil end return value end
    env.InCombatLockdown = function() return state.combat end
    env.IsInInstance = function() return state.bg or false, state.bg and "pvp" or "none" end
    env.GetRealZoneText = function() state.metrics.zoneReads = state.metrics.zoneReads + 1; return "Test Zone" end
    env.GetSubZoneText = function() state.metrics.subZoneReads = state.metrics.subZoneReads + 1; return "Test Spot" end
    env.GetInstanceInfo = function() return "Test Zone" end
    env.UnitPosition = function() state.metrics.worldPositionReads = state.metrics.worldPositionReads + 1; return 200, 100, 0, 1 end
    env.UnitLevel = function() return 60 end
    env.UnitFactionGroup = function() return "Horde" end
    env.UnitName = function(unit)
        if unit == "player" then return "Hero", "One" end
        local rec = state.units[unit]
        return rec and rec.name
    end
    env.UnitNameUnmodified, env.UnitFullName = env.UnitName, env.UnitName
    env.UnitGUID = function(unit)
        if unit == "player" then return "Player-1-0000AAAA" end
        local rec = state.units[unit]
        return rec and rec.guid
    end
    env.UnitExists = function(unit) return state.units[unit] ~= nil end
    env.UnitIsPlayer = function(unit) return state.units[unit] and not state.units[unit].pet end
    env.UnitPlayerControlled = function(unit) return state.units[unit] ~= nil end
    env.UnitCanAttack = function(_, unit) return state.units[unit] ~= nil end
    env.UnitIsEnemy = env.UnitCanAttack
    env.UnitAffectingCombat = function() return state.combat end
    env.GetPlayerInfoByGUID = function(guid)
        local name = state.guidNames and state.guidNames[guid]
        return "Warrior", "WARRIOR", "Human", "Human", 2, name, "Realm"
    end
    env.UnitNameFromGUID = function(guid) return state.guidNames and state.guidNames[guid] end
    env.UnitOnTaxi = function() return false end
    env.RAID_CLASS_COLORS = { WARRIOR = {}, MAGE = {}, PRIEST = {}, HUNTER = {}, ROGUE = {} }
    env.Constants = { CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = " " } }
    env.Enum = { DamageMeterType = { DamageTaken = 7 } }
    env.C_DamageMeter = {
        GetCombatSessionFromID = function(id, kind)
            state.metrics.sessionReads = state.metrics.sessionReads + 1
            assert((id == state.sessionID or state.sessionRows[id]) and kind == 7)
            if state.meterUnavailable then return nil end
            if state.combat then
                local hidden = {}
                state.secrets[hidden] = true
                return hidden
            end
            return { combatSources = {{ isLocalPlayer = true, sourceGUID = "Player-1-0000AAAA", name = "Hero One" }} }
        end,
        GetCombatSessionSourceFromID = function(id, kind, guid)
            state.metrics.sourceReads = state.metrics.sourceReads + 1
            assert((id == state.sessionID or state.sessionRows[id]) and kind == 7 and guid == "Player-1-0000AAAA")
            if state.detailsUnavailable then return nil end
            return { combatSpells = state.sessionRows[id] or state.spellRows }
        end,
    }
    env.C_Map = {
        GetBestMapForUnit = function(unit)
            assert(unit == "player")
            state.metrics.mapIDReads = state.metrics.mapIDReads + 1
            return 42
        end,
        GetPlayerMapPosition = function(mapID, unit)
            assert(mapID == 42 and unit == "player")
            state.metrics.mapPositionReads = state.metrics.mapPositionReads + 1
            return { GetXY = function() return .1, .2 end }
        end,
    }
    env.C_DeathRecap = {
        HasRecapEvents = function()
            state.metrics.hasRecapReads = state.metrics.hasRecapReads + 1
            return (not state.recapReadyAt or state.clock >= state.recapReadyAt) and #state.recap > 0
        end,
        GetRecapEvents = function()
            state.metrics.recapReads = state.metrics.recapReads + 1
            return (not state.recapReadyAt or state.clock >= state.recapReadyAt) and state.recap or {}
        end,
    }
    env.C_Timer = { After = function(delay, callback)
        state.timers[#state.timers + 1] = { at = state.clock + delay, callback = callback }
    end, NewTicker = function() error("Unexpected background ticker") end }
    env.C_TooltipInfo = { GetUnit = function(unit)
        local rec = state.units[unit]
        return { lines = {{ leftText = rec and rec.owner and (rec.owner .. "'s Pet") }} }
    end }
    env.UNITNAME_TITLE_PET = "%s's Pet"
    env.bit = { band = function(a, b)
        local value, place = 0, 1
        while a > 0 and b > 0 do
            if a % 2 == 1 and b % 2 == 1 then value = value + place end
            a, b, place = math.floor(a / 2), math.floor(b / 2), place * 2
        end
        return value
    end }
    env.CreateFrame = function()
        local frame = { events = {}, scripts = {} }
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:UnregisterEvent(event) self.events[event] = nil end
        function frame:SetScript(event, callback)
            assert(event ~= "OnUpdate", "Unexpected per-frame callback")
            self.scripts[event] = callback
        end
        state.frames[#state.frames + 1] = frame
        return frame
    end
    env.ipairs = function(value)
        local iterate, list, first = nativeIPairs(value)
        if value ~= state.spellRows then return iterate, list, first end
        return function(t, key)
            local index, item = iterate(t, key)
            if index then state.metrics.spellVisits = state.metrics.spellVisits + 1 end
            return index, item
        end, list, first
    end
    env.table = {}
    for key, value in nativePairs(table) do env.table[key] = value end
    env.table.sort = function(items, order)
        state.metrics.sorts = state.metrics.sorts + 1
        return table.sort(items, order)
    end
    env.SlashCmdList = {}
    env.DEFAULT_CHAT_FRAME = { AddMessage = function() end }
    env.Sintezza_RivalsDB = { players = {}, fights = {}, battlegrounds = {} }
    env.Sintezza_RivalsPvPDB = { sightings = {}, zones = { [42] = { deaths = 0, kills = 0 } },
        deaths = {}, incoming = {}, nemesis = {}, watch = {}, ignore = {}, duels = {},
        sightingStats = { total = 0 }, settings = { enabled = true, modules = {}, ui = {},
        alerts = { screenshotOnDeath = false } } }

    local pvp = { modules = {}, context = "world", SIGHTING_LIMIT = 1000 }
    local root = { PvP = pvp, Text = function(_, english) return english end,
        ClassName = function(class) return class end, RegisterLaunchers = function() end,
        RefreshPlates = function() end, QueueRefreshPlates = function() end }
    pvp.Safe = function(value) if not state.secrets[value] then return value end end
    pvp.IsSecret = env.issecretvalue
    pvp.L, pvp.Lower = function(text) return text end, string.lower
    pvp.UnitCharacterName = function(unit)
        if unit == "player" then return "Hero One" end
        return state.units[unit] and state.units[unit].name
    end
    pvp.Count = function(value) local n = 0; for _ in nativePairs(value) do n = n + 1 end return n end
    pvp.IsRecording = function(_, module)
        local db = env.Sintezza_RivalsPvPDB
        return db.settings.enabled and db.settings.modules[module] ~= false
    end
    pvp.Guard = function(_, callback, ...) return callback(...) end
    pvp.Log, pvp.LogRaw, pvp.Print = function() end, function() end, function() end
    pvp.Notify = function(_, event, ...)
        state.notifications[#state.notifications + 1] = { event = event, args = {...} }
    end
    pvp.Sightings = { PlayerPos = function() return 42, .1, .2 end }
    pvp.Duels = { StripRecentDuelDamage = function() end, PruneWorldDamage = function() end, StopRecording = function() end }
    pvp.UI = { MarkDirty = function() end, Refresh = function() end }
    pvp.Theme = { C = { dim = { .5, .5, .5 }, green = { 0, 1, 0 }, red = { 1, 0, 0 } } }
    pvp.UIX = { TABS = {}, add = function(row) state.rows[#state.rows + 1] = row end,
        hits = function() return true end, filterText = function() return "" end,
        raceText = function(who) return who.raceName or who.race or "" end,
        coords = function(x, y) return tostring(x) .. "," .. tostring(y) end }
    local bus, listeners
    pvp.On = function(_, event, callback)
        if not bus then
            bus, listeners = env.CreateFrame(), {}
            bus:SetScript("OnEvent", function(_, name, ...)
                for _, listener in nativeIPairs(listeners[name] or {}) do listener(name, ...) end
            end)
        end
        bus:RegisterEvent(event)
        listeners[event] = listeners[event] or {}
        listeners[event][#listeners[event] + 1] = callback
    end
    local function Encode(_, value)
        state.nextPayload = state.nextPayload + 1
        local id = tostring(state.nextPayload)
        state.codec[id] = Copy(value)
        return id
    end
    env.Sintezza_Theme = { DataTransfer = { EncodeRecord = Encode,
        DecodeRecord = function(_, key) return Copy(state.codec[key]) end } }
    env.hooksecurefunc = function(object, name, callback)
        local before = object[name]
        object[name] = function(...)
            before(...)
            callback(...)
        end
    end
    function state:Load(name)
        local chunk, issue = loadstring(sources[name], "@" .. name)
        assert(chunk, issue)
        setfenv(chunk, env)
        chunk("Sintezza_Rivals", root)
    end
    function state:Emit(event, ...)
        for _, frame in nativeIPairs(self.frames) do
            if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
        end
    end
    function state:Advance(seconds)
        local untilTime = self.clock + seconds
        while true do
            local chosen, earliest
            for i, task in nativeIPairs(self.timers) do
                if task.at <= untilTime and (not earliest or task.at < earliest) then chosen, earliest = i, task.at end
            end
            if not chosen then break end
            local task = table.remove(self.timers, chosen)
            self.clock = task.at
            task.callback()
        end
        self.clock = untilTime
    end
    function state:Start()
        self.sessionRows[self.sessionID] = self.spellRows
        self.combat, pvp.context = true, self.bg and "bg" or "world_combat"
        self:Emit("PLAYER_REGEN_DISABLED")
        self:Emit("UNIT_COMBAT", "player", "WOUND", nil, 100)
        self:Emit("DAMAGE_METER_COMBAT_SESSION_UPDATED", 7, self.sessionID)
    end
    function state:Finish(dead)
        self:Advance(30)
        if dead then self:Emit("PLAYER_DEAD") end
        self.combat, pvp.context = false, self.bg and "bg" or "world"
        self:Emit("PLAYER_REGEN_ENABLED")
        self:Advance(3.1)
    end
    function state:Render()
        self.rows = {}
        root.PvPSource.historyTab.fill()
        return self.rows
    end
    state:Load("History.lua")
    state:Emit("ADDON_LOADED", "Sintezza_Rivals")
    if sources["PvP/Modules/Sightings.lua"] then
        state:Load("PvP/Modules/Sightings.lua")
        state.productionLocation = true
    end
    state:Load("PvP/Modules/Deaths.lua")
    pvp.Deaths:Enable()
    state:Load("PvPIntegration.lua")
    root.ConnectPvP()
    if useRealCodec then
        assert(sources["Theme/DataTransfer.lua"], "Missing production Theme/DataTransfer.lua source")
        env.Sintezza_Theme.GetLocale = function() return "enUS" end
        local chunk, issue = loadstring(sources["Theme/DataTransfer.lua"], "@Theme/DataTransfer.lua")
        assert(chunk, issue)
        setfenv(chunk, env)
        chunk("Sintezza_Theme", env.Sintezza_Theme)
    end
    state:Load("Data.lua")
    state.root, state.pvp, state.env = root, pvp, env
    return state
end

local function Meter(state, playerCount, spellsPerPlayer, sameNames)
    state.spellRows = {}
    state.guidNames, state.expectedByName = {}, {}
    local total = 0
    for i = 1, playerCount do
        local name = sameNames and "Same Enemy" or ("Enemy " .. i)
        local guid = ("Player-1-%08X"):format(i)
        state.guidNames[guid] = name
        for j = 1, spellsPerPlayer do
            local amount = i * 100 + j
            state.spellRows[#state.spellRows + 1] = { spellID = j, totalAmount = amount,
                combatSpellDetails = { unitName = name, unitClassFilename = "WARRIOR",
                    isPet = false, isMob = false, amount = amount } }
            total = total + amount
            state.expectedByName[name] = (state.expectedByName[name] or 0) + amount
        end
    end
    state.expectedTotal = total
end

local function Damage(players)
    local total = 0
    for _, player in nativeIPairs(players or {}) do total = total + (player.damage or 0) end
    return total
end

local alive = Harness()
Meter(alive, 50, 20)
alive:Start()
for i = 1, 1000 do alive:Emit("DAMAGE_METER_COMBAT_SESSION_UPDATED", 7, alive.sessionID) end
Check(alive.metrics.sessionReads == 0 and alive.metrics.sourceReads == 0, "live events must not scan the meter")
alive:Finish(false)
local incoming = alive.env.Sintezza_RivalsPvPDB.incoming
Check(#incoming == 1, "one surviving combat must create one incoming segment")
Check(#incoming[1].players == 50, "surviving combat must retain 50 players")
Check(Damage(incoming[1].players) == alive.expectedTotal, "surviving combat total must aggregate all spell amounts exactly")
for _, player in nativeIPairs(incoming[1].players) do
    Check(player.damage == alive.expectedByName[player.name], "per-player damage must sum all spells")
end
local ui = alive:Render()
Check(#ui == 50, "expanded incoming history must display all 50 participants")
Check(alive.metrics.sessionReads == 1 and alive.metrics.sourceReads == 1, "one completed segment must read the meter once")
Check(#alive.root.WorldKills() == 0, "incoming damage must not fabricate a killing blow")
result.cases.survived = { players = #incoming[1].players, damage = Damage(incoming[1].players), rows = #ui }
result.metrics.survived = alive.metrics

local dead = Harness()
Meter(dead, 50, 20)
dead:Start()
for i = 1, 10 do
    dead.recap[i] = { sourceGUID = "Player-1-00000032", sourceName = "Enemy 50",
        sourceFlags = 0x140, amount = 100 + i, timestamp = dead.env.GetServerTime() + 30 }
end
dead:Finish(true)
local death = dead.env.Sintezza_RivalsPvPDB.deaths[1]
Check(death ~= nil, "player death must be retained")
local whole = death and (death.combatAttackers or death.meterAttackers)
Check(whole and #whole == 50, "death must retain all 50 meter participants separately from recap")
Check(whole and Damage(whole) == dead.expectedTotal, "death must retain full meter total without adding recap hits twice")
Check(death and death.verifiedKiller == true and death.killer.guid == "Player-1-00000032", "only the first confirmed recap source is the killer")
Check(#dead.root.WorldKills() == 0, "death and damage taken must not create own killing blows")
result.cases.died = { fullPlayers = whole and #whole or 0, recapPlayers = death and #(death.attackers or {}) or 0,
    meterDamage = whole and Damage(whole) or 0, fullExpected = dead.expectedTotal,
    recapDamage = death and Damage(death.attackers) or 0,
    incomingSegments = #dead.env.Sintezza_RivalsPvPDB.incoming,
    mergedOutcomes = #dead.root.PvPSource:WorldOutcomes(dead.env.Sintezza_RivalsPvPDB) }
result.metrics.died = dead.metrics

local function AddedSpell(state, name, amount, options)
    local details = { unitName = name, unitClassFilename = "WARRIOR", isPet = false, isMob = false, amount = amount }
    for key, value in nativePairs(options or {}) do details[key] = value end
    state.spellRows[#state.spellRows + 1] = { spellID = 9000 + #state.spellRows, totalAmount = amount, combatSpellDetails = details }
    return state.spellRows[#state.spellRows]
end

local function Secret(state)
    local token = {}
    state.secrets[token] = true
    return token
end

local mixed = Harness()
Meter(mixed, 50, 20)
AddedSpell(mixed, "Monster", 900000, { isMob = true })
AddedSpell(mixed, "Wolf", 800000, { isPet = true })
AddedSpell(mixed, "Hero One", 700000)
AddedSpell(mixed, "Unrecognized", 600000, { unitClassFilename = "MONSTER" })
AddedSpell(mixed, "Hidden name", 500000, { unitName = Secret(mixed) })
AddedSpell(mixed, "Hidden class", 400000, { unitClassFilename = Secret(mixed) })
AddedSpell(mixed, "Hidden pet flag", 300000, { isPet = Secret(mixed) })
local priceFallback = AddedSpell(mixed, "Enemy 1", 211, { amount = Secret(mixed) })
priceFallback.totalAmount = 211
local unavailableAmount = AddedSpell(mixed, "Unknown amount", 1)
unavailableAmount.totalAmount, unavailableAmount.combatSpellDetails.amount = Secret(mixed), Secret(mixed)
local inaccessible = AddedSpell(mixed, "Hidden details", 100000)
mixed.inaccessible[inaccessible.combatSpellDetails] = true
mixed:Start()
mixed:Finish(false)
local mixedPlayers = mixed.env.Sintezza_RivalsPvPDB.incoming[1].players
Check(#mixedPlayers == 50, "mixed meter data must retain the 50 recognizable players")
Check(Damage(mixedPlayers) == mixed.expectedTotal + 211, "mixed meter data must exclude self/PvE/pets/unreadable rows and use a readable fallback")
Check(#mixed.root.WorldKills() == 0, "mixed meter rows must not fabricate a killing blow")
result.cases.mixed = { players = #mixedPlayers, damage = Damage(mixedPlayers), expected = mixed.expectedTotal + 211 }

local same = Harness()
Meter(same, 50, 3, true)
same:Start()
same:Finish(false)
local sameRows = same.env.Sintezza_RivalsPvPDB.incoming[1].players
Check(#sameRows == 1 and Damage(sameRows) == same.expectedTotal,
    "the name-only meter contract must disclose identical-name aggregation")
result.cases.nameOnlyContract = { nativeGUIDAvailable = false, mergedPlayers = #sameRows,
    damage = Damage(sameRows), sourcePlayersInFixture = 50 }

local knownGUID = Harness()
Meter(knownGUID, 0, 0)
knownGUID:Start()
for i = 1, 50 do
    local guid = ("Player-1-%08X"):format(i)
    knownGUID.guidNames[guid] = "Same Enemy"
    knownGUID.recap[i] = { sourceGUID = guid, sourceName = "Same Enemy", sourceFlags = 0x140,
        amount = i * 10, timestamp = knownGUID.env.GetServerTime() + 30 }
end
knownGUID:Finish(true)
local guidDeath = knownGUID.env.Sintezza_RivalsPvPDB.deaths[1]
Check(guidDeath and #guidDeath.attackers == 50, "recap records with distinct GUIDs must retain same-name players separately")
Check(guidDeath and Damage(guidDeath.attackers) == 12750, "GUID-based recap aggregation must retain all amounts")
local outcomes = knownGUID.root.PvPSource:WorldOutcomes(knownGUID.env.Sintezza_RivalsPvPDB)
Check(#outcomes == 1 and #knownGUID.root.WorldKills() == 0, "two death collectors must produce one outcome and no own win")
result.cases.guidRecap = { attackers = guidDeath and #guidDeath.attackers or 0,
    damage = guidDeath and Damage(guidDeath.attackers) or 0, outcomes = #outcomes,
    fixtureNote = "Synthetic 50-event recap checks aggregation, not native recap completeness" }

local pet = Harness()
Meter(pet, 1, 1)
pet.units.nameplate1 = { guid = "Pet-1-1234", name = "Wolf", pet = true, owner = "Enemy 1" }
pet:Emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
pet:Start()
pet.recap = {
    { sourceGUID = "Pet-1-1234", sourceName = "Wolf", sourceFlags = 0x140, amount = 300, timestamp = pet.env.GetServerTime() + 30 },
    { sourceGUID = "Player-1-00000001", sourceName = "Enemy 1", sourceFlags = 0x140, amount = 700, timestamp = pet.env.GetServerTime() + 30 },
}
pet:Finish(true)
local petDeath = pet.env.Sintezza_RivalsPvPDB.deaths[1]
Check(petDeath and #petDeath.attackers == 1 and Damage(petDeath.attackers) == 1000,
    "known pet damage must merge once into its owner in the recap")
Check(petDeath and petDeath.verifiedKiller and petDeath.killer.guid == "Player-1-00000001",
    "a known pet's first recap hit must verify the owner's killing blow")
Check(#pet.root.WorldKills() == 0, "an enemy pet killing you must not produce your own win")
result.cases.pet = { recapPlayers = petDeath and #petDeath.attackers or 0,
    recapDamage = petDeath and Damage(petDeath.attackers) or 0 }

local unknownPet = Harness()
Meter(unknownPet, 1, 1)
unknownPet:Start()
unknownPet.recap = {
    { sourceGUID = "Pet-1-FFFF", sourceName = "Unknown Pet", sourceFlags = 0x140, amount = 300, timestamp = unknownPet.env.GetServerTime() + 30 },
    { sourceGUID = "Player-1-00000001", sourceName = "Enemy 1", sourceFlags = 0x140, amount = 700, timestamp = unknownPet.env.GetServerTime() + 30 },
}
unknownPet:Finish(true)
local unknownDeath = unknownPet.env.Sintezza_RivalsPvPDB.deaths[1]
Check(unknownDeath and not unknownDeath.verifiedKiller and unknownDeath.killer == nil,
    "an unknown killing pet must not make a different participant the killer")
Check(unknownDeath and #unknownDeath.attackers == 1 and Damage(unknownDeath.attackers) == 700,
    "unresolved pet damage must not be assigned to another player")
Check(#unknownPet.root.WorldKills() == 0, "unknown pet recap must not produce your own win")

local incomplete = Harness()
Meter(incomplete, 50, 20)
incomplete:Start()
incomplete.recap = {
    { sourceGUID = Secret(incomplete), sourceName = "Hidden", sourceFlags = 0x140, amount = Secret(incomplete),
        timestamp = incomplete.env.GetServerTime() + 30 },
    { sourceGUID = "Player-1-00000001", sourceName = "Enemy 1", sourceFlags = 0x140, amount = 700,
        timestamp = incomplete.env.GetServerTime() + 30 },
}
incomplete:Finish(true)
local partialDeath = incomplete.env.Sintezza_RivalsPvPDB.deaths[1]
Check(partialDeath and not partialDeath.verifiedKiller and partialDeath.killer == nil,
    "an unreadable killing hit must leave the killer unknown")
local partialMeter = partialDeath and (partialDeath.combatAttackers or partialDeath.meterAttackers)
Check(partialMeter and #partialMeter == 50 and Damage(partialMeter) == incomplete.expectedTotal,
    "an incomplete recap must retain the complete readable meter snapshot")
Check(#incomplete.root.WorldKills() == 0, "incomplete recap must not fabricate an own killing blow")

local unavailable = Harness()
Meter(unavailable, 50, 20)
unavailable.detailsUnavailable = true
unavailable:Start()
unavailable.recap[1] = { sourceGUID = "Player-1-00000001", sourceName = "Enemy 1", sourceFlags = 0x140,
    amount = 700, timestamp = unavailable.env.GetServerTime() + 30 }
unavailable:Finish(true)
local fallbackDeath = unavailable.env.Sintezza_RivalsPvPDB.deaths[1]
Check(fallbackDeath and fallbackDeath.verifiedKiller and #fallbackDeath.attackers == 1,
    "unavailable meter data must preserve a readable confirmed recap")
local fallbackMeter = fallbackDeath and (fallbackDeath.combatAttackers or fallbackDeath.meterAttackers)
Check(fallbackMeter == nil or #fallbackMeter == 0, "unavailable meter data must not invent a full damage total")
Check(#unavailable.root.WorldKills() == 0, "unavailable data must not invent an own win")

local noRecap = Harness()
Meter(noRecap, 50, 20)
noRecap:Start()
noRecap:Finish(true)
local unknown = noRecap.env.Sintezza_RivalsPvPDB.deaths[1]
local unknownMeter = unknown and (unknown.combatAttackers or unknown.meterAttackers)
Check(unknown and not unknown.verifiedKiller, "an absent recap must not verify a killer")
Check(unknownMeter and #unknownMeter == 50 and Damage(unknownMeter) == noRecap.expectedTotal,
    "an absent recap must retain the full readable meter context")
Check(#noRecap.root.WorldKills() == 0, "an absent recap must not fabricate an own win")

local monster = Harness()
Meter(monster, 0, 0)
AddedSpell(monster, "Monster", 700, { isMob = true })
monster:Start()
monster.recap[1] = { sourceGUID = "Creature-1-1234", sourceName = "Monster", sourceFlags = 0x40,
    amount = 700, timestamp = monster.env.GetServerTime() + 30 }
monster:Finish(true)
Check(#monster.env.Sintezza_RivalsPvPDB.deaths == 0, "a PvE-only recap must not create a PvP death")
Check(#monster.env.Sintezza_RivalsPvPDB.incoming == 0 and #monster.root.WorldKills() == 0,
    "a PvE-only combat must not create a PvP incoming segment or win")

local exportRows = alive.root.DataTransferSpec.export("world")
Check(type(exportRows) == "table" and #exportRows == 1, "the 50-player incoming fight must export as one record")
local destination = Harness()
destination.codec = alive.codec
local plan, problem = destination.root.DataTransferSpec.stage(exportRows)
Check(plan and plan.added == 1 and problem == nil, "the actual import schema must accept 50 participants")
if plan then destination.root.DataTransferSpec.apply(plan) end
local restored = destination.env.Sintezza_RivalsPvPDB.incoming
Check(#restored == 1 and #restored[1].players == 50 and Damage(restored[1].players) == alive.expectedTotal,
    "export/import must preserve all 50 participants and exact totals")
local again = destination.root.DataTransferSpec.stage(exportRows)
Check(again and again.added == 0 and again.duplicates == 1, "reimport must detect an existing fight")
if again then destination.root.DataTransferSpec.apply(again) end
Check(#restored == 1, "reimport must not duplicate the fight")
result.cases.imported = { rows = #restored, players = restored[1] and #restored[1].players or 0 }

alive:Emit("PARTY_KILL", "Player-1-00000001", "Player-1-0000AAAA")
alive:Emit("PARTY_KILL", "Player-1-00000001", "Player-1-00000002")
alive:Emit("PARTY_KILL", Secret(alive), "Player-1-00000002")
Check(#alive.root.WorldKills() == 0, "enemy or unreadable PARTY_KILL events must not create an own win")
alive:Emit("PARTY_KILL", "Player-1-0000AAAA", "Player-1-00000002")
Check(#alive.root.WorldKills() == 1, "one confirmed own PARTY_KILL must create one win")

local large = Harness()
Meter(large, 50, 400)
large:Start()
large:Finish(false)
local largeIncoming = large.env.Sintezza_RivalsPvPDB.incoming
Check(#largeIncoming == 1 and #largeIncoming[1].players == 50 and Damage(largeIncoming[1].players) == large.expectedTotal,
    "20,000 spell rows must produce the exact 50-player total")
Check(large.metrics.sessionReads == 1 and large.metrics.sourceReads == 1 and large.metrics.spellVisits == 20000,
    "large combat collection must make one native snapshot read and one spell traversal")
result.metrics.large = large.metrics
result.cases.large = { spellRows = #large.spellRows, players = #largeIncoming[1].players, damage = Damage(largeIncoming[1].players) }


local deadRows = dead:Render()
local displayedDamage = 0
for _, row in nativeIPairs(deadRows) do
    local text = row.cells and row.cells[7]
    displayedDamage = displayedDamage + (type(text) == "string" and tonumber(text:match("^Damage:%s*(%d+)$")) or 0)
end
Check(#deadRows == 50, "a death with a full meter snapshot must display each of its 50 participants once")
Check(displayedDamage == dead.expectedTotal, "death history damage must use the meter aggregate without adding recap totals")
result.cases.died.uiRows, result.cases.died.uiDamage = #deadRows, displayedDamage

if whole then
    local rows, issue = dead.root.DataTransferSpec.export("world")
    Check(rows and not issue, "a death with 50 full participants must export")
    if rows then
        local target = Harness()
        target.codec = dead.codec
        local staged, issue = target.root.DataTransferSpec.stage(rows)
        Check(staged and not issue, "the import schema must accept the full death meter snapshot")
        if staged then
            target.root.DataTransferSpec.apply(staged)
            local record = target.env.Sintezza_RivalsPvPDB.deaths[1]
            local attackers = record and (record.combatAttackers or record.meterAttackers)
            Check(attackers and #attackers == 50 and Damage(attackers) == dead.expectedTotal,
                "death export/import must retain all 50 participants and the exact full damage")
            Check(#target.root.PvPSource:WorldOutcomes(target.env.Sintezza_RivalsPvPDB) == 1,
                "death export/import must not duplicate the two collector records in history")
        end
    end
end

local hundred = Harness()
Meter(hundred, 100, 1)
hundred:Start()
hundred:Finish(false)
local hundredRows = hundred.root.DataTransferSpec.export("world")
local hundredTarget = Harness()
hundredTarget.codec = hundred.codec
local hundredPlan = hundredTarget.root.DataTransferSpec.stage(hundredRows)
Check(hundredPlan and hundredPlan.added == 1, "the declared 100-participant import capacity must accept the boundary")

local hundredOne = Harness()
Meter(hundredOne, 101, 1)
hundredOne:Start()
hundredOne:Finish(false)
local overflowRows = hundredOne.root.DataTransferSpec.export("world")
local overflowTarget = Harness()
overflowTarget.codec = hundredOne.codec
local overflowPlan, overflowIssue = overflowTarget.root.DataTransferSpec.stage(overflowRows)
Check(overflowPlan == nil and type(overflowIssue) == "string",
    "the existing schema must reject an imported record above its 100-participant capacity")


local mixedDeath = Harness()
Meter(mixedDeath, 50, 20)
mixedDeath:Start()
mixedDeath.recap = {
    { sourceGUID = "Creature-1-1234", sourceName = "Monster", sourceFlags = 0x40, amount = 700,
        timestamp = mixedDeath.env.GetServerTime() + 30 },
}
mixedDeath:Finish(true)
local mixedRecord = mixedDeath.env.Sintezza_RivalsPvPDB.deaths[1]
local mixedFull = mixedRecord and (mixedRecord.combatAttackers or mixedRecord.meterAttackers)
if not mixedFull and mixedDeath.env.Sintezza_RivalsPvPDB.incoming[1] then
    mixedFull = mixedDeath.env.Sintezza_RivalsPvPDB.incoming[1].players
end
Check(mixedFull and #mixedFull == 50 and Damage(mixedFull) == mixedDeath.expectedTotal,
    "a PvE finishing hit must not discard the preceding readable 50-player damage context")
Check(not mixedRecord or (not mixedRecord.verifiedKiller and mixedRecord.killer == nil),
    "a PvE finishing hit must not name a player as the confirmed killer")
Check(#mixedDeath.root.WorldKills() == 0, "mixed PvP/PvE damage must not fabricate an own killing blow")
result.cases.pveFinisher = {
    fullPlayers = mixedFull and #mixedFull or 0, damage = mixedFull and Damage(mixedFull) or 0,
    expected = mixedDeath.expectedTotal, deaths = #mixedDeath.env.Sintezza_RivalsPvPDB.deaths,
}


local function EndWithoutWaiting(state, dead)
    state:Advance(10)
    if dead then state:Emit("PLAYER_DEAD") end
    state.combat, state.pvp.context = false, state.bg and "bg" or "world"
    state:Emit("PLAYER_REGEN_ENABLED")
end

local function SingleRecap(state, guid, name, amount)
    return {{ sourceGUID = guid, sourceName = name, sourceFlags = 0x140, amount = amount,
        timestamp = state.env.GetServerTime() }}
end

for _, delay in nativeIPairs({1, 2}) do
    local late = Harness()
    Meter(late, 50, 20)
    late:Start()
    late:Advance(10)
    late.recap = SingleRecap(late, "Player-1-00000032", "Enemy 50", 1055)
    late.recapReadyAt = late.clock + delay
    late:Emit("PLAYER_DEAD")
    late.combat, late.pvp.context = false, "world"
    late:Emit("PLAYER_REGEN_ENABLED")
    late:Advance(.85)
    local record = late.env.Sintezza_RivalsPvPDB.deaths[1]
    Check(record and record.combatAttackers and #record.combatAttackers == 50,
        "the meter snapshot must attach before a delayed " .. delay .. "s recap")
    Check(record and not record.verifiedKiller, "a pending recap must not verify the killer")
    late:Advance(2.3)
    record = late.env.Sintezza_RivalsPvPDB.deaths[1]
    Check(record and record.verifiedKiller and record.killer.guid == "Player-1-00000032",
        "a delayed " .. delay .. "s recap must verify the current death")
    local rows, total = late:Render(), 0
    for _, row in nativeIPairs(rows) do
        local text = row.cells and row.cells[7]
        total = total + (type(text) == "string" and tonumber(text:match("^Damage:%s*(%d+)$")) or 0)
    end
    Check(#rows == 50 and total == late.expectedTotal,
        "a delayed recap must not duplicate history participants or damage")
    Check(#late.root.PvPSource:WorldOutcomes(late.env.Sintezza_RivalsPvPDB) == 1 and #late.env.Sintezza_RivalsPvPDB.incoming == 0,
        "a delayed recap must retain one combined outcome")
    result.cases["lateRecap" .. delay] = { rows = #rows, damage = total, verified = record and record.verifiedKiller or false }
end

local cleared = Harness()
Meter(cleared, 50, 20)
cleared:Start()
EndWithoutWaiting(cleared, true)
cleared.root.DataTransferSpec.sections[2].clear()
cleared.recap = SingleRecap(cleared, "Player-1-00000032", "Enemy 50", 1055)
cleared:Advance(3.1)
Check(#cleared.env.Sintezza_RivalsPvPDB.deaths == 0 and #cleared.env.Sintezza_RivalsPvPDB.incoming == 0
    and #cleared.root.db.fights == 0, "clearing world history before callbacks must not resurrect old records")
Check(cleared.metrics.sessionReads == 0 and cleared.metrics.sourceReads == 0,
    "clearing a pending segment must cancel its meter snapshot")

local meterReset = Harness()
Meter(meterReset, 50, 20)
meterReset:Start()
EndWithoutWaiting(meterReset, true)
meterReset:Emit("DAMAGE_METER_RESET")
meterReset.meterUnavailable = true
meterReset.recap = SingleRecap(meterReset, "Player-1-00000032", "Enemy 50", 1055)
meterReset:Advance(3.1)
local resetRecord = meterReset.env.Sintezza_RivalsPvPDB.deaths[1]
Check(resetRecord and resetRecord.verifiedKiller and not resetRecord.combatAttackers,
    "resetting the native meter must preserve a valid recap without attaching stale meter data")
Check(#meterReset.env.Sintezza_RivalsPvPDB.incoming == 0 and meterReset.metrics.sessionReads == 0,
    "resetting the native meter must cancel the pending aggregate read")

local quick = Harness()
Meter(quick, 50, 20)
quick:Start()
EndWithoutWaiting(quick, true)
quick:Advance(.4)
quick.sessionID = 202
Meter(quick, 1, 1)
quick.spellRows[1].combatSpellDetails.unitName = "Second Enemy"
quick.spellRows[1].combatSpellDetails.amount = 777
quick.spellRows[1].totalAmount = 777
quick.guidNames["Player-1-FFFFFF01"] = "Second Enemy"
quick:Start()
quick:Advance(.1)
quick.recap = SingleRecap(quick, "Player-1-FFFFFF01", "Second Enemy", 77)
quick.recapReadyAt = 11
quick:Emit("PLAYER_DEAD")
quick.combat, quick.pvp.context = false, "world"
quick:Emit("PLAYER_REGEN_ENABLED")
quick:Advance(3.1)
local firstDeath, nextDeath = quick.env.Sintezza_RivalsPvPDB.deaths[1], quick.env.Sintezza_RivalsPvPDB.deaths[2]
Check(firstDeath and not firstDeath.verifiedKiller,
    "a previous death retry must not claim the next death's recap")
Check(nextDeath and nextDeath.verifiedKiller and nextDeath.killer.guid == "Player-1-FFFFFF01",
    "the current death must retain its own delayed recap")
Check(nextDeath and nextDeath.combatAttackers and #nextDeath.combatAttackers == 1 and Damage(nextDeath.combatAttackers) == 777,
    "a second combat must retain its own meter session instead of the first combat's damage")
Check(not firstDeath or not firstDeath.combatAttackers or firstDeath.meterSession == 101,
    "a previous death must not receive the next combat's meter session")
Check(#quick.root.WorldKills() == 0, "rapid deaths must not fabricate own wins")
result.cases.rapidDeaths = { deaths = #quick.env.Sintezza_RivalsPvPDB.deaths,
    firstVerified = firstDeath and firstDeath.verifiedKiller or false,
    secondVerified = nextDeath and nextDeath.verifiedKiller or false,
    secondDamage = nextDeath and Damage(nextDeath.combatAttackers) or 0 }

local bg = Harness()
bg.bg = true
bg:Emit("PLAYER_ENTERING_WORLD")
Meter(bg, 50, 20)
bg:Start()
bg:Advance(10)
bg.recap = SingleRecap(bg, "Player-1-00000032", "Enemy 50", 1055)
bg:Emit("PLAYER_DEAD")
bg.combat, bg.pvp.context = false, "bg"
bg:Emit("PLAYER_REGEN_ENABLED")
bg:Advance(3.1)
local match = bg.root.db.battlegrounds[1]
local bgDeath = match and match.fights[1]
Check(match and #match.fights == 1 and bgDeath.result == "loss",
    "a battleground death must create one loss in its match")
Check(bgDeath and bgDeath.combatAttackers and #bgDeath.combatAttackers == 50
    and Damage(bgDeath.combatAttackers) == bg.expectedTotal, "a battleground death must retain all 50 meter participants")
Check(bgDeath and bgDeath.verifiedRecap and bgDeath.guid == "Player-1-00000032",
    "a battleground death killer must come from the confirmed recap")
local kills, deaths = bg.root.PvPSource:BattlegroundScore(match)
Check(kills == 0 and deaths == 1 and #bg.root.WorldKills() == 0,
    "battleground incoming damage must not create wins or world kills")
local bgRows = bg.root.DataTransferSpec.export("battlegrounds")
local bgTarget = Harness()
bgTarget.codec = bg.codec
local bgPlan, bgIssue = bgTarget.root.DataTransferSpec.stage(bgRows)
Check(bgPlan and not bgIssue, "the import schema must accept a 50-participant battleground death")
if bgPlan then bgTarget.root.DataTransferSpec.apply(bgPlan) end
local importedBG = bgTarget.root.db.battlegrounds[1]
Check(importedBG and #importedBG.fights == 1 and #importedBG.fights[1].combatAttackers == 50,
    "battleground death import must preserve its full participant list")
result.cases.battleground = { fights = match and #match.fights or 0, players = bgDeath and #(bgDeath.combatAttackers or {}) or 0,
    damage = bgDeath and Damage(bgDeath.combatAttackers) or 0, kills = kills, deaths = deaths }


local repeated = Harness()
Meter(repeated, 50, 20)
repeated:Start()
repeated:Advance(10)
repeated.recap = SingleRecap(repeated, "Player-1-00000032", "Enemy 50", 1055)
repeated:Emit("PLAYER_DEAD")
repeated.combat, repeated.pvp.context = false, "world"
repeated:Emit("PLAYER_REGEN_ENABLED")
repeated:Advance(.4)
repeated:Emit("PLAYER_ALIVE")
repeated.recap = SingleRecap(repeated, "Player-1-FFFFFF01", "Second Enemy", 77)
repeated:Emit("PLAYER_DEAD")
repeated:Advance(3.1)
local previousRecord, repeatedRecord = repeated.env.Sintezza_RivalsPvPDB.deaths[1], repeated.env.Sintezza_RivalsPvPDB.deaths[2]
Check(previousRecord and previousRecord.combatAttackers and #previousRecord.combatAttackers == 50,
    "the original death must retain its pending full meter snapshot")
Check(repeatedRecord and not repeatedRecord.combatAttackers,
    "a repeated death without a new combat must not inherit the previous segment's meter data")
Check(#repeated.root.WorldKills() == 0, "repeated death events must not create an own win")
result.cases.repeatedDeath = { previousPlayers = previousRecord and #(previousRecord.combatAttackers or {}) or 0,
    repeatedPlayers = repeatedRecord and #(repeatedRecord.combatAttackers or {}) or 0 }


local finisher = Harness()
Meter(finisher, 50, 20)
finisher:Start()
finisher:Advance(10)
finisher.recap = {
    { sourceGUID = "Player-1-00000001", sourceName = "Enemy 1", sourceFlags = 0x140, amount = 7,
        timestamp = finisher.env.GetServerTime() },
    { sourceGUID = "Player-1-00000032", sourceName = "Enemy 50", sourceFlags = 0x140, amount = 999,
        timestamp = finisher.env.GetServerTime() },
}
finisher:Emit("PLAYER_DEAD")
finisher.combat, finisher.pvp.context = false, "world"
finisher:Emit("PLAYER_REGEN_ENABLED")
finisher:Advance(3.1)
local finished = finisher.env.Sintezza_RivalsPvPDB.deaths[1]
Check(finished and finished.verifiedKiller and finished.killer.guid == "Player-1-00000001",
    "the largest damage contributor must not replace the confirmed killing source")
local killerScore = finisher.root.PvPSource:PlayerScore("Enemy 1", "Player-1-00000001")
local contributorScore = finisher.root.PvPSource:PlayerScore("Enemy 50", "Player-1-00000032")
Check(killerScore and killerScore.deaths == 1,
    "two death collectors must count the confirmed opponent killing you once")
Check(not contributorScore or contributorScore.deaths == 0,
    "the largest damage contributor must not receive a killing-blow count")
Check(finisher.root.PvPSource:Kind("Player-1-00000032", finisher.root.db.players["Player-1-00000032"]) == "attacker",
    "a damage contributor must retain attacker classification")
local finishRows, finishTotal = finisher:Render(), 0
for _, row in nativeIPairs(finishRows) do
    local value = row.cells and row.cells[7]
    finishTotal = finishTotal + (type(value) == "string" and tonumber(value:match("^Damage:%s*(%d+)$")) or 0)
end
Check(#finishRows == 50 and finishTotal == finisher.expectedTotal,
    "a low-damage finisher must display the full 50-player meter total exactly once")
result.cases.lowDamageFinisher = { confirmedGUID = finished and finished.killer and finished.killer.guid,
    killerDeaths = killerScore and killerScore.deaths, highestContributorDeaths = contributorScore and contributorScore.deaths or 0,
    rows = #finishRows, damage = finishTotal }


local burst = Harness()
Meter(burst, 50, 20)
burst:Start()
for i = 1, 10000 do burst:Emit("UNIT_COMBAT", "player", "WOUND", nil, i) end
Check(burst.productionLocation == true, "the burst fixture must use the actual shared PlayerPos implementation")
Check(burst.metrics.mapIDReads == 1 and burst.metrics.mapPositionReads == 1
    and burst.metrics.worldPositionReads == 1 and burst.metrics.zoneReads == 1 and burst.metrics.subZoneReads == 1,
    "a WOUND burst must resolve location only for the first hit")
Check(burst.metrics.sessionReads == 0 and burst.metrics.sourceReads == 0,
    "10,000 live WOUND callbacks must not read native meter snapshots")
burst:Finish(false)
local burstPlayers = burst.env.Sintezza_RivalsPvPDB.incoming[1] and burst.env.Sintezza_RivalsPvPDB.incoming[1].players
Check(burstPlayers and #burstPlayers == 50 and Damage(burstPlayers) == burst.expectedTotal,
    "a WOUND burst must retain the exact 50-player native aggregate")
Check(burst.metrics.sessionReads == 1 and burst.metrics.sourceReads == 1 and burst.metrics.spellVisits == 1000,
    "a WOUND burst must still perform one pair of native snapshot calls after combat")
Check(burst.metrics.mapIDReads == 1 and burst.metrics.mapPositionReads == 1 and burst.metrics.worldPositionReads == 1,
    "finishing a surviving burst must reuse its stored location")
result.metrics.woundBurst = burst.metrics
result.cases.woundBurst = { events = 10001, players = burstPlayers and #burstPlayers or 0,
    damage = Damage(burstPlayers), locationBackend = burst.productionLocation and "production Sightings.PlayerPos" or "missing" }


local function RealCSV(state, scope)
    local spec = state.root.DataTransferSpec
    local records, issue = spec.export(scope)
    Check(records and issue == nil, "the real record encoder must export " .. scope)
    if not records then return end
    local transfer = state.env.Sintezza_Theme.DataTransfer
    local csv, issue = transfer:EncodeCSV(spec, records)
    Check(type(csv) == "string" and issue == nil, "the real CSV encoder must serialize " .. scope)
    if not csv then return end
    local decoded, issue = transfer:DecodeCSV(spec, csv)
    Check(decoded and issue == nil and #decoded == #records, "the real CSV decoder must retain all " .. scope .. " rows")
    return decoded, csv, records
end

local actualDeath = Harness(true)
Meter(actualDeath, 50, 20)
actualDeath:Start()
actualDeath:Advance(10)
actualDeath.recap = SingleRecap(actualDeath, "Player-1-00000032", "Enemy 50", 1055)
actualDeath:Emit("PLAYER_DEAD")
actualDeath.combat, actualDeath.pvp.context = false, "world"
actualDeath:Emit("PLAYER_REGEN_ENABLED")
actualDeath:Advance(3.1)
local sourceDeath = actualDeath.env.Sintezza_RivalsPvPDB.deaths[1]
local actualTransfer = actualDeath.env.Sintezza_Theme.DataTransfer
local payload, payloadIssue = actualTransfer:EncodeRecord(sourceDeath)
Check(type(payload) == "string" and payloadIssue == nil, "the real record encoder must accept a full 50-attacker death")
local decodedDeath = payload and actualTransfer:DecodeRecord(payload)
Check(decodedDeath and #decodedDeath.combatAttackers == 50 and Damage(decodedDeath.combatAttackers) == actualDeath.expectedTotal,
    "the real record decoder must preserve the full 50-attacker death")
local deathRows, deathCSV = RealCSV(actualDeath, "world")
local actualTarget = Harness(true)
local actualPlan, actualIssue
if deathRows then actualPlan, actualIssue = actualTarget.root.DataTransferSpec.stage(deathRows) end
Check(actualPlan and actualIssue == nil and actualPlan.added == #deathRows,
    "real CSV death rows must pass production staging")
if actualPlan then actualTarget.root.DataTransferSpec.apply(actualPlan) end
local actualRestored = actualTarget.env.Sintezza_RivalsPvPDB.deaths[1]
Check(actualRestored and #actualRestored.combatAttackers == 50
    and Damage(actualRestored.combatAttackers) == actualDeath.expectedTotal,
    "production apply must restore all 50 attackers from actual CSV")
Check(#actualTarget.root.PvPSource:WorldOutcomes(actualTarget.env.Sintezza_RivalsPvPDB) == 1,
    "the actual codec roundtrip must retain one combined death outcome")
local repeatDeath = deathRows and actualTarget.root.DataTransferSpec.stage(deathRows)
Check(repeatDeath and repeatDeath.added == 0 and repeatDeath.duplicates == #deathRows,
    "actual-codec death reimport must skip every duplicate")
result.cases.actualDeathCodec = { rows = deathRows and #deathRows or 0, csvBytes = deathCSV and #deathCSV or 0,
    recordBytes = payload and #payload or 0, participants = actualRestored and #(actualRestored.combatAttackers or {}) or 0,
    damage = actualRestored and Damage(actualRestored.combatAttackers) or 0 }

local function Observation(state, index)
    local guid = ("Player-2-%08X"):format(index)
    return guid, {
        guid = guid, name = "Observed Enemy " .. index, realm = "Realm", class = "WARRIOR",
        raceName = "Human", race = "Human", faction = "Horde", guild = "Recorded Guild",
        level = 60, firstSeen = 100000, lastSeen = 100000 + index, count = 2,
        isPVP = true, posStale = false, lastMapID = 42, lastZone = 'Test, "Quoted" Zone',
        lastSubZone = "Test Spot", lastX = .1, lastY = .2,
        worldX = 100, worldY = 200, instanceID = 1, lastSource = "target", inCombatWhenSeen = false,
        hours = { [0] = 1, [23] = 1 },
        trail = {
            { x = .1, y = .2, ts = 100000 + index, mapID = 42 },
            { x = .2, y = .3, ts = 100000 + index, mapID = 42 },
            { x = .3, y = .4, ts = 100000 + index, mapID = 42 },
            { x = .4, y = .5, ts = 100000 + index, mapID = 42 },
        },
    }
end

local actualObservations = Harness(true)
for i = 1, 1000 do
    local key, value = Observation(actualObservations, i)
    actualObservations.env.Sintezza_RivalsPvPDB.sightings[key] = value
end
actualObservations.env.Sintezza_RivalsPvPDB.sightingStats.total = 1000
local observationRows, observationCSV = RealCSV(actualObservations, "encounters")
Check(observationRows and #observationRows == 1000, "the actual codec must retain 1,000 observation rows")
local observationTarget = Harness(true)
local observationPlan, observationIssue
if observationRows then observationPlan, observationIssue = observationTarget.root.DataTransferSpec.stage(observationRows) end
Check(observationPlan and observationIssue == nil and observationPlan.added == 1000,
    "production staging must accept 1,000 actual-codec observations")
if observationPlan then observationTarget.root.DataTransferSpec.apply(observationPlan) end
local restoredObservations = observationTarget.env.Sintezza_RivalsPvPDB.sightings
local restoredCount = observationTarget.pvp.Count(restoredObservations)
Check(restoredCount == 1000 and observationTarget.env.Sintezza_RivalsPvPDB.sightingStats.total == 1000,
    "actual-codec apply must retain all 1,000 observation identities and counts")
local sample = restoredObservations["Player-2-000003E8"]
Check(sample and sample.name == "Observed Enemy 1000" and sample.lastZone == 'Test, "Quoted" Zone'
    and #sample.trail == 4 and sample.hours[0] == 1 and sample.hours[23] == 1,
    "actual CSV escaping and record decoding must retain nested observation fields")
local duplicateObservations = observationRows and observationTarget.root.DataTransferSpec.stage(observationRows)
Check(duplicateObservations and duplicateObservations.added == 0 and duplicateObservations.duplicates == 1000,
    "actual-codec observation reimport must not duplicate archived players")

local extraObservation = Harness(true)
local extraKey, extraValue = Observation(extraObservation, 1001)
extraObservation.env.Sintezza_RivalsPvPDB.sightings[extraKey] = extraValue
local extraRows, extraCSV = RealCSV(extraObservation, "encounters")
local overflow, overflowProblem = observationTarget.root.DataTransferSpec.stage(extraRows)
Check(overflow == nil and type(overflowProblem) == "string",
    "an actual-codec new observation above the 1,000-record limit must be rejected")
Check(observationTarget.pvp.Count(restoredObservations) == 1000 and restoredObservations[extraKey] == nil,
    "rejecting the 1,001st observation must keep the existing archive intact")

actualObservations.env.Sintezza_RivalsPvPDB.sightings[extraKey] = extraValue
local overfullRows, overfullCSV = RealCSV(actualObservations, "encounters")
Check(overfullRows and #overfullRows == 1001, "the real CSV transport must preserve the oversized batch for validation")
local emptyTarget = Harness(true)
local overfullPlan, overfullIssue = emptyTarget.root.DataTransferSpec.stage(overfullRows)
Check(overfullPlan == nil and type(overfullIssue) == "string",
    "production staging must reject an oversized 1,001-record actual-codec batch")
Check(emptyTarget.pvp.Count(emptyTarget.env.Sintezza_RivalsPvPDB.sightings) == 0,
    "a rejected actual-codec batch must not partially import its first 1,000 records")
result.cases.actualObservationCodec = { csvBytes = observationCSV and #observationCSV or 0,
    exported = observationRows and #observationRows or 0, restored = restoredCount,
    extraCSVBytes = extraCSV and #extraCSV or 0, overfullCSVBytes = overfullCSV and #overfullCSV or 0,
    incrementalOverflowRejected = overflow == nil, batchOverflowRejected = overfullPlan == nil }


local reviewClear = Harness()
reviewClear.bg = true
reviewClear:Emit("PLAYER_ENTERING_WORLD")
Meter(reviewClear, 50, 20)
reviewClear:Start()
EndWithoutWaiting(reviewClear, true)
reviewClear.root.DataTransferSpec.sections[3].clear()
reviewClear:Advance(3.1)
Check(#reviewClear.root.db.battlegrounds == 0, "clearing a pending battleground death must not resurrect an empty match")
Check(reviewClear.metrics.sessionReads == 0 and reviewClear.metrics.sourceReads == 0,
    "battleground clear must cancel the pending meter snapshot")

local delayedMob = Harness()
Meter(delayedMob, 50, 20)
delayedMob:Start()
delayedMob:Advance(10)
delayedMob.recap = {{ sourceGUID = "Creature-1-1234", sourceName = "Monster", sourceFlags = 0x40,
    amount = 700, timestamp = delayedMob.env.GetServerTime() }}
delayedMob.recapReadyAt = delayedMob.clock + 1
delayedMob:Emit("PLAYER_DEAD")
delayedMob.combat, delayedMob.pvp.context = false, "world"
delayedMob:Emit("PLAYER_REGEN_ENABLED")
delayedMob:Advance(3.1)
local mobContext = delayedMob.env.Sintezza_RivalsPvPDB.incoming[1]
Check(mobContext and #mobContext.players == 50 and Damage(mobContext.players) == delayedMob.expectedTotal,
    "a delayed PvE finisher recap must retain the preceding 50-player meter context")
Check(#delayedMob.env.Sintezza_RivalsPvPDB.deaths == 0 and #delayedMob.root.db.fights == 0,
    "a delayed PvE finisher must not create a player death result")
local mobRows, mobDamage = delayedMob:Render(), 0
for _, row in nativeIPairs(mobRows) do
    local value = row.cells and row.cells[7]
    mobDamage = mobDamage + (type(value) == "string" and tonumber(value:match("^Damage:%s*(%d+)$")) or 0)
end
Check(#mobRows == 50 and mobDamage == delayedMob.expectedTotal,
    "a delayed PvE finisher must display its 50 player participants and exact meter total once")
Check(delayedMob.metrics.sessionReads == 1 and delayedMob.metrics.sourceReads == 1,
    "a delayed recap must reuse the previously collected native meter snapshot")
result.cases.delayedPvEFinisher = { players = mobContext and #mobContext.players or 0,
    rows = #mobRows, damage = mobDamage }

local bgCards = Harness()
local cardMatch = { name = "Battleground sample", time = 100, completed = true, fights = {
    { guid = "Player-1-aabb", name = "Enemy One", class = "ROGUE", result = "loss", time = 110,
        helpers = { { guid = "Player-1-aacc", name = "Enemy Two", class = "PRIEST", damage = 50 } } },
} }
bgCards.root.db.battlegrounds = { cardMatch }
local fillBG = bgCards.root.PvPSource.historyTab.fill
for index = 1, 30 do
    local key = debug.getupvalue(fillBG, index)
    if not key then break end
    if key == "view" then debug.setupvalue(fillBG, index, "bg"); break end
end
local matchRows = bgCards:Render()
Check(matchRows[1] and matchRows[1].kind == "rivalsBattleground", "battleground header missing")
matchRows[1].toggle()
local playerRows, linked = bgCards:Render(), 0
for _, row in nativeIPairs(playerRows) do
    if row.name then
        Check(row.cardContext and row.cardContext.match == cardMatch,
            "battleground player card lost its match context")
        linked = linked + 1
    end
end
Check(linked == 2, "battleground main and participant names must both open cards")


local durable = Harness()
Meter(durable, 50, 20)
durable:Start()
durable:Advance(10)
durable.recap = {{ sourceGUID = "Creature-1-1234", sourceName = "Monster", sourceFlags = 0x40,
    amount = 700, timestamp = durable.env.GetServerTime() }}
durable.recapReadyAt = durable.clock + 1
durable:Emit("PLAYER_DEAD")
durable.combat, durable.pvp.context = false, "world"
durable:Emit("PLAYER_REGEN_ENABLED")
durable:Advance(1.1)
durable:Emit("CHAT_MSG_COMBAT_MISC_INFO", "Durability loss")
durable:Advance(2.1)
local durableIncoming = durable.env.Sintezza_RivalsPvPDB.incoming
Check(#durableIncoming == 1 and #durableIncoming[1].players == 50
    and Damage(durableIncoming[1].players) == durable.expectedTotal,
    "a later durability cleanup must not duplicate transferred meter context")
Check(#durable.env.Sintezza_RivalsPvPDB.deaths == 0
    and durable.env.Sintezza_RivalsPvPDB.zones[42].deaths == 0,
    "repeated cleanup must decrement the removed death count only once")
result.cases.idempotentDeathDrop = { incoming = #durableIncoming,
    zoneDeaths = durable.env.Sintezza_RivalsPvPDB.zones[42].deaths }

local attacking = Harness()
local guidA, guidB = "Player-1-00aa", "Player-1-00bb"
local attackDB = attacking.env.Sintezza_RivalsPvPDB
attackDB.deaths = {
    { meterSession = 1, meterStartedAt = 100, attackers = { { guid = guidA }, { guid = guidB } },
        combatAttackers = { { guid = guidA }, { guid = guidB } } },
    { ts = 200, attackers = { { guid = guidA }, { guid = "Creature-1-00cc" } } },
}
attackDB.incoming = {
    { meterSession = 1, meterStartedAt = 100, players = { { guid = guidA }, { guid = guidB } } },
    { meterSession = 2, meterStartedAt = 300, players = { { guid = guidA } } },
}
local markerSource = attacking.root.PvPSource
Check(markerSource:MarkerCount(guidA, "attacker") == 3 and markerSource:MarkerCount(guidB, "attacker") == 1,
    "attacker scaling must count episodes and merge recap/full-meter views of one combat")
Check(markerSource:MarkerCount("Creature-1-00cc", "attacker") == 0, "NPCs must not contribute attacker thresholds")
attackDB.incoming[3] = { meterSession = 3, meterStartedAt = 400, players = { { guid = guidA } } }
Check(markerSource:MarkerCount(guidA, "attacker") == 3, "attacker counts should be cached within one refresh batch")
attacking.pvp.UI:MarkDirty()
Check(markerSource:MarkerCount(guidA, "attacker") == 4, "dirty events must invalidate cached attacker counts")
local oldKiller = { enabled = true, count = 3, tiers = {
    { kills = 5, bonus = 10 }, { kills = 10, bonus = 20 }, { kills = 25, bonus = 30 }, { kills = 50, bonus = 50 },
} }
attacking.root.db.markerScaling.killer = oldKiller
attacking.root.SetMarkerScaling("attacker", "enabled", true)
Check(attacking.root.MarkerScalingAvailable("attacker", "swords") and attacking.root.MarkerScaling("attacker").enabled,
    "attacker category must support scaling")
Check(attacking.root.MarkerScalingAvailable("defeated", "swords"), "defeated category must retain scaling")
Check(attacking.root.db.markerScaling.killer == oldKiller and oldKiller.count == 3 and oldKiller.tiers[2].bonus == 20,
    "adding attacker settings must preserve older killer configuration")
Check(attacking.root.SetMarkerThreshold("attacker", 1, "kills", 10)
    and attacking.root.MarkerScaling('attacker').tiers[2].kills == 11,
    "crossing a threshold must push the next threshold up predictably")
Check(attacking.root.SetMarkerThreshold("attacker", 1, "kills", 6), "valid attacker slider threshold rejected")
attacking.root.SetMarkerScaling("attacker", "count", 3)
Check(attacking.root.SetMarkerThreshold("attacker", 3, "kills", 80)
    and attacking.root.MarkerScaling("attacker").tiers[4].kills == 81,
    "three-threshold editing must preserve a valid dormant fourth threshold")
Check(attacking.root.MarkerSizePercent("attacker", "swords", 80) == 125,
    "attacker marker must apply the highest reached bonus without stacking")
result.cases.attackerScaling = { episodes = 4, cached = true, oldProfilePreserved = true }

local atomic = Harness()
atomic.root.db.markerScaling.attacker = { enabled = true, count = 4, tiers = {
    { kills = 5, bonus = 10 }, { kills = 10, bonus = 15 }, { kills = 25, bonus = 25 }, { kills = 50, bonus = 50 },
} }
local commits = 0
local function Ordered()
    local previousKills, previousBonus = 0, 0
    for _, tier in ipairs(atomic.root.MarkerScaling('attacker').tiers) do
        if tier.kills <= previousKills or tier.kills > 999 or tier.bonus < previousBonus or tier.bonus > 200 then return false end
        previousKills, previousBonus = tier.kills, tier.bonus
    end
    return true
end
atomic.root.Changed = function() commits = commits + 1; Check(Ordered(), 'refresh must never observe half-updated scaling tiers') end
atomic.root.SetMarkerThreshold('attacker', 2, 'kills', 30)
local tiers = atomic.root.MarkerScaling('attacker').tiers
Check(tiers[1].kills == 5 and tiers[2].kills == 30 and tiers[3].kills == 31 and tiers[4].kills == 50 and commits == 1,
    'upward threshold cascade must only move crossed neighbors and refresh once')
atomic.root.SetMarkerThreshold('attacker', 3, 'kills', 2)
Check(tiers[1].kills == 1 and tiers[2].kills == 2 and tiers[3].kills == 3 and tiers[4].kills == 50,
    'downward threshold cascade must preserve a positive increasing sequence')
atomic.root.SetMarkerThreshold('attacker', 1, 'bonus', 40)
Check(tiers[1].bonus == 40 and tiers[2].bonus == 40 and tiers[3].bonus == 40 and tiers[4].bonus == 50,
    'higher early bonus must raise only smaller following bonuses')
atomic.root.SetMarkerThreshold('attacker', 3, 'bonus', 5)
Check(tiers[1].bonus == 5 and tiers[2].bonus == 5 and tiers[3].bonus == 5 and tiers[4].bonus == 50,
    'lower later bonus must lower only larger preceding bonuses')
local seed = 17
for index = 1, 200 do
    seed = seed * 48271 % 2147483647
    local field = index % 2 == 0 and 'kills' or 'bonus'
    local value = field == 'kills' and (seed % 999 + 1) or seed % 201
    local before = commits
    Check(atomic.root.SetMarkerThreshold('attacker', math.floor((index - 1) / 2) % 4 + 1, field, value),
        'bounded coupled edit rejected')
    Check(Ordered() and commits - before <= 1, 'coupled edits must be ordered, bounded and atomic')
end
local previousSize = 0
for count = 0, 999 do
    local size = atomic.root.MarkerSizePercent('attacker', 'swords', count)
    Check(size >= previousSize, 'marker size must never shrink at a higher count')
    previousSize = size
end
local function Upvalue(fn, wanted)
    for index = 1, 30 do local name, value = debug.getupvalue(fn, index); if not name then break end; if name == wanted then return value end end
    error('Missing upvalue: ' .. wanted)
end
local normalize = Upvalue(Upvalue(atomic.root.SetMarkerThreshold, 'EditableMarkerScaling'), 'NormalizeMarkerScaling')
local old = { enabled = true, count = 4, tiers = {
    { kills = 5, bonus = 50 }, { kills = 10, bonus = 10 }, { kills = 25, bonus = 20 }, { kills = 50, bonus = 5 },
} }
local once, twice = normalize(old), normalize(normalize(old))
for index = 1, 4 do
    Check(once.tiers[index].bonus == 50 and twice.tiers[index].bonus == 50
        and once.tiers[index].kills == old.tiers[index].kills, 'old decreasing bonuses should normalize once without changing thresholds')
end
Check(old.tiers[2].bonus == 10, 'normalizing old settings should not mutate the input table')
result.cases.atomicScaling = { edits = 200, sizeChecks = 1000, commits = commits, oldSettingsNormalized = true }

return result
