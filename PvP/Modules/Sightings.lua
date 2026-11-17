-- Sintezza Rivals / Sightings.lua: enemy player sightings from nameplates/target/mouseover
local ADDON, root = ...
local ns = root.PvP

local S = {}
ns.Sightings = S
ns.modules.Sightings = S

local now = _G.GetServerTime or time
local Safe = ns.Safe
local CAP = ns.SIGHTING_LIMIT or 1000

----------------------------------------------------------------- helpers
local function try(fn, ...)
	local ok, a, b, c = pcall(fn, ...)
	if not ok then return nil end
	return Safe(a), Safe(b), Safe(c)
end

-- the enemy's own position is not available, so a sighting is stored at the
-- player's position: "seen near here"
local function playerPos()
	local m = try(C_Map.GetBestMapForUnit, "player")
	if not m then return nil end
	local p = select(1, try(C_Map.GetPlayerMapPosition, m, "player"))
	if not p or not p.GetXY then return m end
	local ok, x, y = pcall(p.GetXY, p)
	if not ok then return m end
	return m, Safe(x), Safe(y)
end

S.PlayerPos = playerPos   -- shared with Deaths.lua

-- the map alone, for callers on a ticker: GetPlayerMapPosition builds a fresh
-- vector on every call, GetBestMapForUnit returns a plain number
function S.PlayerMap()
	return (try(C_Map.GetBestMapForUnit, "player"))
end

local function noteSecret(field)
	local st = Sintezza_RivalsPvPDB.sightingStats
	st.secretFields[field] = (st.secretFields[field] or 0) + 1
end

local function classColor(token, text)
	if not token then return text end
	local ok, c = pcall(function()
		if C_ClassColor and C_ClassColor.GetClassColor then return C_ClassColor.GetClassColor(token) end
		return RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
	end)
	if not ok or not c then return text end
	local okHex, hex = pcall(function()
		if c.GenerateHexColor then return c:GenerateHexColor() end
		return c.colorStr
	end)
	if okHex and hex then return "|c" .. hex .. text .. "|r" end
	return text
end

local ago = ns.Ago

----------------------------------------------------------------- zone aggregate
local function bumpZone(mapID, zone, ts)
	if not mapID then return end
	local z = Sintezza_RivalsPvPDB.zones[mapID]
	if not z then
		z = { name = zone, sightings = 0, deaths = 0, kills = 0 }
		Sintezza_RivalsPvPDB.zones[mapID] = z
	end
	z.name = zone or z.name
	z.sightings = z.sightings + 1
	z.lastActivity = ts
end

local retentionHeap, retentionPositions = {}, {}
local indexedArchive = setmetatable({}, { __mode = "v" })

local function SeenTime(record)
	local value = type(record) == "table" and tonumber(record.lastSeen) or 0
	return value and value == value and value or 0
end

local function Older(firstTime, firstKey, secondTime, secondKey)
	return firstTime < secondTime or (firstTime == secondTime and tostring(firstKey) < tostring(secondKey))
end

local function SiftUp(position)
	local entry = retentionHeap[position]
	while position > 1 do
		local parent = math.floor(position / 2)
		local other = retentionHeap[parent]
		if not Older(entry.seen, entry.key, other.seen, other.key) then break end
		retentionHeap[position] = other
		retentionPositions[other.key] = position
		position = parent
	end
	retentionHeap[position] = entry
	retentionPositions[entry.key] = position
	return position
end

local function SiftDown(position)
	local entry = retentionHeap[position]
	local size = #retentionHeap
	while position * 2 <= size do
		local child = position * 2
		local first, second = retentionHeap[child], retentionHeap[child + 1]
		if second and Older(second.seen, second.key, first.seen, first.key) then
			child = child + 1
			first = second
		end
		if not Older(first.seen, first.key, entry.seen, entry.key) then break end
		retentionHeap[position] = first
		retentionPositions[first.key] = position
		position = child
	end
	retentionHeap[position] = entry
	retentionPositions[entry.key] = position
end

local function RetainKey(key, seen)
	local position = retentionPositions[key]
	if position then
		local entry = retentionHeap[position]
		if entry.seen == seen then return end
		entry.seen = seen
		SiftDown(SiftUp(position))
		return
	end
	if #retentionHeap < CAP then
		local last = #retentionHeap + 1
		retentionHeap[last] = { key = key, seen = seen }
		SiftUp(last)
		return
	end
	local oldest = retentionHeap[1]
	if not Older(oldest.seen, oldest.key, seen, key) then return key end
	local removed = oldest.key
	retentionPositions[removed] = nil
	oldest.key, oldest.seen = key, seen
	retentionPositions[key] = 1
	SiftDown(1)
	return removed
end

local function RebuildRetention(archive)
	indexedArchive[1] = nil
	retentionHeap, retentionPositions = {}, {}
	for key, record in pairs(archive) do RetainKey(key, SeenTime(record)) end
	for key in pairs(archive) do
		if not retentionPositions[key] then archive[key] = nil end
	end
	indexedArchive[1] = archive
end

function S:InvalidateRetention()
	indexedArchive[1] = nil
	retentionHeap, retentionPositions = {}, {}
end

function S:Init()
	RebuildRetention(Sintezza_RivalsPvPDB.sightings)
end

local function RetainObservation(key, record)
	local archive = Sintezza_RivalsPvPDB.sightings
	if indexedArchive[1] ~= archive then
		RebuildRetention(archive)
	else
		local removed = RetainKey(key, SeenTime(record))
		if removed then archive[removed] = nil end
	end
end

----------------------------------------------------------------- core
function S:Consider(unit, source)
	if not ns:IsRecording("enemies") then return end
	local ctx = ns.context
	if ctx ~= "world" and ctx ~= "world_combat" then return end

	if not Safe(UnitExists(unit)) then return end
	if not Safe(UnitIsPlayer(unit)) then return end
	if Safe(UnitIsUnit(unit, "player")) then return end
	if not Safe(UnitCanAttack("player", unit)) then return end

	local guid = try(UnitGUID, unit)
	local name = ns.UnitCharacterName(unit)
	local _, realm = try(UnitName, unit)
	if not name then noteSecret("name") end
	if not guid then noteSecret("guid") end

	local key = guid or (name and (name .. "-" .. (realm or "")))
	if not key then return end -- nothing we can key on, count it and move on

	local ts = now()
	local db = Sintezza_RivalsPvPDB.sightings
	local rec = db[key]
	local dedupe = Sintezza_RivalsPvPDB.settings.sightings.dedupeSeconds or 60
	local isNew = not rec or (ts - (rec.lastSeen or 0)) > dedupe

	if not rec then
		rec = { guid = guid, firstSeen = ts, count = 0 }
		db[key] = rec
		Sintezza_RivalsPvPDB.sightingStats.total = Sintezza_RivalsPvPDB.sightingStats.total + 1
	end

	if name and (not rec.name or name:find("%S%s+%S") or not rec.name:find("%S%s+%S")) then rec.name = name end
	rec.realm = realm or rec.realm
	local _, classToken = try(UnitClass, unit)
	if classToken then rec.class = classToken else noteSecret("class") end
	-- UnitRace returns the localized name first, the file token second. The token
	-- reads "Scourge" for Undead, so the localized name is what we display.
	local raceName, raceToken = try(UnitRace, unit)
	rec.raceName = raceName or rec.raceName
	rec.race = raceToken or rec.race
	-- a guild name groups gankers far better than anything else we can read
	local guild = try(GetGuildInfo, unit)
	if guild and guild ~= "" then rec.guild = guild end
	local level = try(UnitLevel, unit)
	if level and level > 0 then rec.level = level elseif not level then noteSecret("level") end
	rec.faction = try(UnitFactionGroup, unit) or rec.faction
	local pvp = try(UnitIsPVP, unit)
	if pvp ~= nil then rec.isPVP = pvp end

	local mapID, x, y = playerPos()
	if mapID then
		rec.lastMapID, rec.posStale = mapID, nil
		if x then rec.lastX, rec.lastY = x, y else rec.posStale = true; noteSecret("position") end
	else
		rec.posStale = true
		noteSecret("position")
	end
	rec.lastZone = try(GetRealZoneText) or rec.lastZone
	rec.lastSubZone = try(GetSubZoneText) or rec.lastSubZone
	-- world yards, for minimap placement. UnitPosition returns y, x, z, instanceID
	-- (y first: the swap is the API, not a typo).
	local okPos, wy, wx, _, inst = pcall(UnitPosition, "player")
	if okPos then
		wy, wx, inst = Safe(wy), Safe(wx), Safe(inst)
		if wx then rec.worldY, rec.worldX, rec.instanceID = wy, wx, inst end
	end
	rec.lastSource = source
	rec.inCombatWhenSeen = (ctx == "world_combat")
	rec.lastSeen = ts
	-- a nameplate, a target and a mouseover of the same player a moment apart
	-- are one sighting: the count and the hours only move once per dedupe window
	if isNew then
		rec.count = rec.count + 1
		-- when this one is usually about: 24 small counters, filled only for
		-- hours they were actually seen in
		local hour = tonumber(date("%H", ts))
		if hour then
			rec.hours = rec.hours or {}
			rec.hours[hour] = (rec.hours[hour] or 0) + 1
		end
	end


	-- a short trail of distinct spots: enough to show a farming route, cheap
	-- enough to keep for hundreds of players
	if isNew and rec.lastX then
		rec.trail = rec.trail or {}
		local last = rec.trail[#rec.trail]
		if not last or math.abs(last.x - rec.lastX) > 0.01 or math.abs(last.y - rec.lastY) > 0.01 then
			rec.trail[#rec.trail + 1] = { x = rec.lastX, y = rec.lastY, ts = ts, mapID = rec.lastMapID }
			while #rec.trail > 4 do table.remove(rec.trail, 1) end
		end
	end

	RetainObservation(key, rec)

	-- feed the killer-guess contact list (no combat log on this client)
	if ns.Deaths then ns.Deaths:Contact(rec, source) end

	-- A watched enemy alerts on its own cooldown, independent of the sighting
	-- dedupe window, so re-finding them inside a minute is not silent.
	if ns.Watchlist and ns.Watchlist:IsWatched(key) then S:WatchAlert(key, rec, source) end

	if isNew then
		bumpZone(rec.lastMapID, rec.lastZone, ts)
		S:Alert(rec, key)
		if ns.UI then ns.UI:MarkDirty() end
	end
end

local watchAlerted = {}

local function alertSound(stealthy)
	local kits = SOUNDKIT
	if type(kits) ~= "table" then return end
	local primary = stealthy and kits.UI_RAID_BOSS_WHISPER_WARNING or kits.RAID_WARNING
	if type(primary) == "number" and primary > 0 then return primary end
	for _, name in ipairs({ "RAID_WARNING", "UI_RAID_BOSS_WHISPER_WARNING" }) do
		local kit = kits[name]
		if type(kit) == "number" and kit > 0 then return kit end
	end
end

function S:CanPlayAlertSound()
	return type(PlaySound) == "function" and alertSound(false) ~= nil
end

function S:HasAlternateAlertSound()
	return self:CanPlayAlertSound() and alertSound(true) ~= alertSound(false)
end

function S:PlayAlertSound(stealthy)
	local kit = alertSound(stealthy)
	if not kit or type(PlaySound) ~= "function" then return false end
	local ok, played = pcall(PlaySound, kit)
	return ok and played ~= false
end

function S:WatchAlert(key, rec, source)
	local a = Sintezza_RivalsPvPDB.settings.alerts
	if Sintezza_RivalsPvPDB.ignore[key] then return end   -- duelling partners, friends on the other faction
	if S.TooLow(rec) then return end
	local cd = a.watchSeconds or 20
	if (now() - (watchAlerted[key] or 0)) < cd then return end
	watchAlerted[key] = now()
	local where = (rec.lastSubZone and rec.lastSubZone ~= "" and rec.lastSubZone) or rec.lastZone or "?"
	ns:Notify("watched", "|cffff2020WATCHED|r %s (%s) spotted via %s, %s",
		classColor(rec.class, rec.name or "?"), tostring(rec.level or "?"),
		ns.L(source or "unknown"), where)
	local class = root.ClassName(rec.class)
	if a.banner and ns.UI and ns.UI.Banner then
		ns.UI:Banner(ns.L("%s is here"):format(rec.name or "?"),
			("%s %s, %s (%s)"):format(class or rec.class or "?", tostring(rec.level or "?"), where, ns.L(source or "unknown")),
			rec.class)
	end
	if a.soundOnSighting and not UnitOnTaxi("player") then
		local stealthy = a.stealthSound and (rec.class == "ROGUE" or rec.class == "DRUID")
		self:PlayAlertSound(stealthy)
	end
end

-- "Ignore enemies this far below you": at -5, someone five or more levels under
-- you is recorded but never alerts. Watched enemies included: you asked to be
-- told about them, not about them while they are no threat.
function S.TooLow(rec)
	local diff = Sintezza_RivalsPvPDB.settings.alerts.minLevelDiff
	if not diff or diff >= 0 or not rec.level then return false end
	local myLevel = try(UnitLevel, "player") or 0
	return myLevel > 0 and (rec.level - myLevel) <= diff
end

function S:Alert(rec, key)
	local db = Sintezza_RivalsPvPDB
	if db.ignore[key or rec.guid or rec.name] or not db.settings.alerts.chat.sighting or S.TooLow(rec) then return end
	ns:Notify("sighting", "%s (%s) spotted in %s",
		classColor(rec.class, rec.name or "?"), tostring(rec.level or "?"),
		(rec.lastSubZone ~= "" and rec.lastSubZone) or rec.lastZone or "?")
	-- no sound here: the setting is "Sound for watched enemies", and a siren
	-- for every stranger in Stranglethorn is how people uninstall addons
end

local lastGroundZone, zoneTimer
local function IsAirborne()
	return try(UnitOnTaxi, "player") == true or try(IsFlying, "player") == true
end

function S:ZoneWarning()
	if IsAirborne() then return end
	local zone, _, mapID = ns:ZoneInfo()
	if not mapID then return end
	local visit = zone ~= "" and zone ~= "?" and zone or mapID
	if visit == lastGroundZone then return end
	lastGroundZone = visit
	if not ns:WantsNotification("zone") then return end
	local z = Sintezza_RivalsPvPDB.zones[mapID]
	if not z then return end
	local hourAgo = now() - 3600
	local recent = 0
	for _, rec in pairs(Sintezza_RivalsPvPDB.sightings) do
		if rec.lastMapID == mapID and (rec.lastSeen or 0) >= hourAgo then recent = recent + 1 end
	end
	local deaths = z.deaths or 0
	if deaths == 0 and recent == 0 then return end
	ns:Notify("zone", "|cffff8000%s|r: %d of your deaths here, %d enemies seen in the last hour",
		z.name or ns.L("this zone"), deaths, recent)
end

----------------------------------------------------------------- output
function S:List(n)
	n = n or 20
	local list = {}
	for key, r in pairs(Sintezza_RivalsPvPDB.sightings) do list[#list + 1] = r end
	table.sort(list, function(a, b) return (a.lastSeen or 0) > (b.lastSeen or 0) end)
	if #list == 0 then return ns:Print("no sightings yet") end
	ns:Print("--- last %d of %d sightings ---", math.min(n, #list), #list)
	for i = 1, math.min(n, #list) do
		local r = list[i]
		ns:Print("%s L%s %s - %s ago - %sx - %s", classColor(r.class, r.name or "?"),
			tostring(r.level or "?"), (r.lastSubZone ~= "" and r.lastSubZone) or r.lastZone or "?",
			ago(r.lastSeen), tostring(r.count), tostring(r.lastSource))
	end
end

function S:Zones()
	local list = {}
	for mapID, z in pairs(Sintezza_RivalsPvPDB.zones) do
		local distinct = 0
		for _, r in pairs(Sintezza_RivalsPvPDB.sightings) do
			if r.lastMapID == mapID then distinct = distinct + 1 end
		end
		list[#list + 1] = { mapID = mapID, z = z, distinct = distinct }
	end
	table.sort(list, function(a, b) return (a.z.lastActivity or 0) > (b.z.lastActivity or 0) end)
	if #list == 0 then return ns:Print("no zone data yet") end
	ns:Print("--- zones ---")
	for _, e in ipairs(list) do
		local hot = (now() - (e.z.lastActivity or 0)) < 900 and " |cffff2020HOT|r" or ""
		ns:Print("%s (%d): %d sightings, %d players, %d deaths, %d kills, %s ago%s",
			tostring(e.z.name), e.mapID, e.z.sightings, e.distinct, e.z.deaths or 0, e.z.kills or 0,
			ago(e.z.lastActivity), hot)
	end
end

----------------------------------------------------------------- module hooks

----------------------------------------------------------------- unit tooltip
-- One line on the game's own unit tooltip: the record, where everyone looks
-- first. Identity is readable, so this works in and out of combat.
local function tooltipLine(tooltip, unit)
	if not ns:Module("enemies") then return end
	if not Sintezza_RivalsPvPDB.settings.alerts.unitTooltip then return end
	if not unit or not Safe(UnitIsPlayer(unit)) then return end
	local guid = try(UnitGUID, unit)
	local rec = guid and Sintezza_RivalsPvPDB.sightings[guid]
	local nem = guid and Sintezza_RivalsPvPDB.nemesis[guid]
	if not rec and not nem and not rank then return end
	local parts = {}
	if nem and (nem.killsOnMe or 0) > 0 then parts[#parts + 1] = string.format("killed you %dx", nem.killsOnMe) end
	local confirmed = guid and root.db.players[guid]
	if confirmed and (confirmed.defeats or 0) > 0 then parts[#parts + 1] = string.format("you killed %dx", confirmed.defeats) end
	if rec then parts[#parts + 1] = string.format("seen %dx", rec.count or 1) end
	if ns.Watchlist and ns.Watchlist:IsWatched(guid) then parts[#parts + 1] = "|cffffd100WATCHED|r" end
	if #parts == 0 then return end
	tooltip:AddLine("|cff33ff99Sintezza Rivals|r  " .. table.concat(parts, ", "), 0.85, 0.85, 0.85)
end

-- the unit tooltip refreshes many times while it is up: pcall takes the
-- arguments directly, where Guard would build a closure every time
local function safeTooltipLine(tooltip, unit)
	local ok, err = pcall(tooltipLine, tooltip, unit)
	if not ok then ns:Err(err) end
end

local function hookTooltip()
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
			if tooltip ~= GameTooltip then return end
			local _, unit = tooltip:GetUnit()
			safeTooltipLine(tooltip, unit)
		end)
	elseif GameTooltip and GameTooltip.HookScript then
		GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
			local _, unit = tooltip:GetUnit()
			safeTooltipLine(tooltip, unit)
		end)
	end
end

----------------------------------------------------------------- stealth casts
-- UNIT_SPELLCAST_START fires for nameplate units with readable arguments on
-- this client (NOTES.md). A rogue or druid going into stealth in front of you
-- is the one cast worth a shout: after it there is nothing to see.
local STEALTH = { [1784] = true, [1856] = true, [1857] = true, [5215] = true, [6783] = true, [9913] = true, [58984] = true }
local lastStealthAlert = {}

local function onCastStart(_, unit, _, spellID)
	if not ns:IsRecording("enemies") then return end
	if not Sintezza_RivalsPvPDB.settings.alerts.stealthCast then return end
	if type(unit) ~= "string" or not string.find(unit, "^nameplate") then return end
	spellID = Safe(spellID)
	if not STEALTH[spellID or 0] then return end
	if not Safe(UnitIsPlayer(unit)) or not Safe(UnitCanAttack("player", unit)) then return end
	local name = ns.UnitCharacterName(unit) or ns.L("someone")
	local guid = try(UnitGUID, unit)
	if Sintezza_RivalsPvPDB.ignore[guid or name] then return end
	if (now() - (lastStealthAlert[name] or 0)) < 20 then return end
	-- keyed by enemy name, so expired entries go before a new one is added
	for who, ts in pairs(lastStealthAlert) do
		if (now() - ts) >= 20 then lastStealthAlert[who] = nil end
	end
	lastStealthAlert[name] = now()
	local _, class = try(UnitClass, unit)
	ns:Notify("watched", "|cffff8000%s went into stealth|r right next to you", name)
	if Sintezza_RivalsPvPDB.settings.alerts.banner and ns.UI and ns.UI.Banner then
		ns.UI:Banner(ns.L("%s went into stealth"):format(name), ns.L("within nameplate range"), class,
			{ tag = ns.L("|cffff5555STEALTH|r") })
	end
	if Sintezza_RivalsPvPDB.settings.alerts.soundOnSighting and not UnitOnTaxi("player") then
		S:PlayAlertSound(true)
	end
end

function S:Enable()
	-- Most enemies are seen through their nameplates. With enemy nameplates off
	-- only the target and the mouseover are left, so that is said once a login.
	C_Timer.After(15, function()
		if not ns:IsRecording("enemies") or not (C_CVar and C_CVar.GetCVarBool) then return end
		local ok, on = pcall(C_CVar.GetCVarBool, "nameplateShowEnemies")
		if ok and on == false then
			ns:Print("enemy nameplates are off (Ctrl+V turns them on): Sintezza Rivals sees most enemies through their nameplates")
		end
	end)
	-- the three switches are read on every event, so flipping them in the
	-- options takes effect at once instead of after a reload
	ns:On("NAME_PLATE_UNIT_ADDED", function(_, unit)
		if Sintezza_RivalsPvPDB.settings.sightings.fromNameplates then S:Consider(unit, "nameplate") end
	end)
	ns:On("PLAYER_TARGET_CHANGED", function()
		if Sintezza_RivalsPvPDB.settings.sightings.fromTarget then S:Consider("target", "target") end
	end)
	ns:On("UPDATE_MOUSEOVER_UNIT", function()
		if Sintezza_RivalsPvPDB.settings.sightings.fromMouseover then S:Consider("mouseover", "mouseover") end
	end)
	ns:On("ZONE_CHANGED_NEW_AREA", function()
		if zoneTimer then
			zoneTimer:Cancel()
			zoneTimer = nil
		end
		if not ns:IsRecording() or IsAirborne() then return end
		zoneTimer = C_Timer.NewTimer(3, function()
			zoneTimer = nil
			ns:Guard(S.ZoneWarning, S)
		end)
	end)
	-- Stealth, Prowl and Vanish are instant: they fire SUCCEEDED, not START
	ns:On("UNIT_SPELLCAST_SUCCEEDED", onCastStart)
	hookTooltip()
end
