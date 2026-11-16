-- Sintezza Rivals / Duels.lua
--
-- Duel records: who, which class, which side, won or lost, where and how long.
--
-- There is no event that says "a duel started and X won". What the game gives
-- is DUEL_REQUESTED (who challenged you), DUEL_FINISHED (it is over) and a
-- system message naming the winner. The message is built from the global
-- strings DUEL_WINNER_KNOCKOUT and DUEL_WINNER_RETREAT, so the patterns come
-- from those globals rather than from English text.
--
-- What is known about the opponent is kept past DUEL_FINISHED because the
-- result message can arrive after it. If the message does not
-- match, the duel is recorded with an unknown result and the system lines
-- seen during it are kept on the record, so the pattern can be fixed from
-- real data instead of guessed at.
--
-- Duels with your own faction count. Standing outside Stormwind being
-- challenged by a passing Horde player counts too; the only thing the faction
-- changes is the column it shows in.

local ADDON, root = ...
local ns = root.PvP

local D = {}
ns.Duels = D
ns.modules.Duels = D

local now = _G.GetServerTime or time
local Safe = ns.Safe
local CAP = 200
local RAW_KEEP = 6
local MIN_UNKNOWN_DUEL_SECONDS = 8

local function PlainText(text)
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
		:gsub("|3%-%d+%(([^()]*)%)", "%1")
		:gsub("|Hplayer:[^|]*|h(.-)|h", function(name)
			return (name:gsub("^%[(.*)%]$", "%1"))
		end):match("^%s*(.-)%s*$"))
end

local function ResultLine(text)
	return (PlainText(text):gsub("%.$", ""))
end

--------------------------------------------------------------------- patterns
-- "%1$s has defeated %2$s in a duel" -> "^(.+) has defeated (.+) in a duel$"
-- plus the argument number of each capture in textual order. Mainline global
-- strings are positional: the retreat message reads "%2$s has fled from %1$s",
-- so the first name in the text is the second argument. Older clients use
-- plain "%s", which counts up from one.
local function toPattern(global)
	if type(global) ~= "string" then return nil end
	global = ResultLine(global)
	local order, auto, positional = {}, 0, false
	-- pull the specifiers out first, so escaping the rest cannot touch them
	local p = global:gsub("%%(%d*)%$?([sd])", function(idx, kind)
		auto = auto + 1
		if idx ~= "" then positional = true end
		order[#order + 1] = tonumber(idx) or auto
		return kind == "d" and "\1" or "\2"
	end)
	p = p:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
	p = p:gsub("\1", "(%%d+)")
	p = p:gsub("\2", "(.+)")
	return "^" .. p .. "$", order, positional
end

local PATTERNS = {}

local function buildPatterns()
	PATTERNS = {}
	local function addPattern(global, kind)
		local pattern, order, positional = toPattern(global)
		if pattern then
			PATTERNS[#PATTERNS + 1] = { pattern = pattern, kind = kind, order = order, positional = positional }
		end
	end
	addPattern(_G.DUEL_WINNER_KNOCKOUT, "knockout")
	addPattern(_G.DUEL_WINNER_RETREAT, "retreat")
	if GetLocale() == "ruRU" then
		addPattern("%1$s побеждает в поединке с %2$s.", "knockout")
	end
end

--------------------------------------------------------------------- names
local function opponentKey(name)
	if type(name) == "string" then return ns.CharacterNameKey(PlainText(name)) end
end
D.OpponentKey = opponentKey

local function fullKey(name)
	local key = opponentKey(name)
	if key and key:find(" ", 1, true) then return key end
end

local function ReadResult(text, ownKey)
	text = Safe(text)
	if type(text) ~= "string" then return end
	text = ResultLine(text)
	for _, p in ipairs(PATTERNS) do
		local winner, loser = string.match(text, p.pattern)
		if winner and loser then
			ownKey = ownKey or opponentKey(ns.UnitCharacterName("player"))
			if not ownKey then return end
			if (p.positional and p.order[1] ~= 1) or (not p.positional and p.kind == "retreat") then
				winner, loser = loser, winner
			end
			local won, lost = opponentKey(winner) == ownKey, opponentKey(loser) == ownKey
			if won and not lost then return loser, true, p.kind end
			if lost and not won then return winner, false, p.kind end
			return
		end
	end
end

--------------------------------------------------------------------- state
-- what we know about the duel in progress; kept a little while after it ends,
-- because the result message arrives after DUEL_FINISHED
local pending
local recentDuel

local function stale()
	return not pending or ((pending.finishedAt or now()) - pending.ts) > 180
end

local function stripDuelDamage(entry, duel)
	if not duel or type(duel.ts) ~= "number"
		or type(entry.ts) ~= "number" or type(entry.ended) ~= "number" then return end
	local seconds = type(duel.seconds) == "number" and duel.seconds or 0
	if duel.won == nil and (duel.kind ~= "unknown" or seconds < MIN_UNKNOWN_DUEL_SECONDS) then return end
	-- The damage meter can close after the duel ends while combat drops.
	if entry.ts > duel.ts or entry.ended > duel.ts + 5 then return end
	if seconds > 0 then
		if entry.ts < duel.ts - seconds then return end
	elseif entry.ended < duel.ts - 2 or entry.ts < duel.ts - 180 then
		return
	end

	local key, changed = fullKey(duel.opponent)
	for i = #entry.players, 1, -1 do
		local player = entry.players[i]
		local samePlayer
		if player.guid and duel.guid then
			samePlayer = player.guid == duel.guid
		elseif key then
			samePlayer = fullKey(player.name) == key
		end
		if samePlayer then
			table.remove(entry.players, i)
			changed = true
		end
	end
	return changed
end

function D:StripRecentDuelDamage(entry)
	stripDuelDamage(entry, recentDuel)
end

function D:PruneWorldDamage(duel)
	local db = Sintezza_RivalsPvPDB
	local changed
	for i = #(db.incoming or {}), 1, -1 do
		local entry = db.incoming[i]
		local removed
		if duel then
			removed = stripDuelDamage(entry, duel)
		else
			for _, saved in ipairs(db.duels) do
				if stripDuelDamage(entry, saved) then removed = true end
				if #entry.players == 0 then break end
			end
		end
		if removed then
			changed = true
			if #entry.players == 0 then table.remove(db.incoming, i) end
		end
	end
	if changed and ns.UI then ns.UI:MarkDirty() end
end

function D:FindSighting(name, guid)
	local sightings = Sintezza_RivalsPvPDB.sightings
	if guid and sightings[guid] then return guid, sightings[guid] end
	local expected = fullKey(name)
	if not expected then return end
	local key, latest
	for k, rec in pairs(sightings) do
		if opponentKey(rec.name) == expected and (not guid or not rec.guid or rec.guid == guid)
			and (not latest or (rec.lastSeen or 0) > (latest.lastSeen or 0)) then
			key, latest = k, rec
		end
	end
	return key, latest
end

local profileFields = { "guid", "class", "level", "race", "raceName", "faction" }
local function mergeProfile(record, source)
	if not source or (record.guid and source.guid and record.guid ~= source.guid) then return end
	local changed
	for _, key in ipairs(profileFields) do
		if record[key] == nil and source[key] ~= nil then
			record[key], changed = source[key], true
		end
	end
	if record.sameSide == nil and record.faction then
		local ownFaction = root.Read(UnitFactionGroup, "player")
		if ownFaction then record.sameSide, changed = (record.faction == ownFaction), true end
	end
	return changed
end

local function unitProfile(unit)
	local _, class = root.Read(UnitClass, unit)
	local raceName, race = root.Read(UnitRace, unit)
	local level = root.Read(UnitLevel, unit)
	local guid = root.Read(UnitGUID, unit)
	return {
		guid = root.IsPlayerGUID(guid) and guid or nil,
		class = class, level = type(level) == "number" and level > 0 and level or nil,
		race = race, raceName = raceName, faction = root.Read(UnitFactionGroup, unit),
	}
end

local visibleUnits = { "target", "mouseover", "focus" }
local function matchesUnit(unit, expected)
	return type(unit) == "string" and root.Read(UnitIsPlayer, unit)
		and fullKey(ns.UnitCharacterName(unit)) == expected
end

local function findUnit(expected)
	if not expected then return end
	for _, unit in ipairs(visibleUnits) do
		if matchesUnit(unit, expected) then return unit end
	end
	local plates = C_NamePlate and root.Read(C_NamePlate.GetNamePlates)
	if type(plates) ~= "table" or (canaccesstable and not canaccesstable(plates)) then return end
	for _, plate in ipairs(plates) do
		plate = Safe(plate)
		local unit = plate and Safe(plate.namePlateUnitToken)
		if matchesUnit(unit, expected) then return unit end
	end
end

local function captureProfile(record, unit)
	if unit then mergeProfile(record, unitProfile(unit)) end
	if record.guid and record.class and record.level and record.faction and record.raceName then return end
	local _, sighting = D:FindSighting(record.opponent, record.guid)
	mergeProfile(record, sighting)
end

local function startPending(name, unit)
	name = type(name) == "string" and PlainText(name) or nil
	local key = opponentKey(name)
	if not key then return end
	pending = { opponent = name, ownKey = opponentKey(ns.UnitCharacterName("player")), ts = now(), raw = {},
		record = ns:IsRecording("duels") }
	if pending.record then captureProfile(pending, unit or findUnit(key)) end
end

--------------------------------------------------------------------- recording
local function record(opponent, won, kind)
	local key = opponentKey(opponent)
	local fight = not stale() and opponentKey(pending.opponent) == key and pending or nil
	if won == nil and not (fight and fight.finishedAt) then return end
	if fight or stale() then pending = nil end
	local shouldRecord = ns:IsRecording("duels") and (not fight or fight.record)
	local finishedAt = fight and fight.finishedAt or now()

	local result = {
		ts = finishedAt, opponent = opponent,
		won = won, kind = kind,
		seconds = fight and (finishedAt - fight.ts) or nil,
	}
	if shouldRecord then
		local zone = Safe(GetSubZoneText())
		if not zone or zone == "" then zone = Safe(GetRealZoneText()) end
		result.zone = zone
		result.rawLines = (won == nil and fight and #fight.raw > 0) and fight.raw or nil
		mergeProfile(result, fight)
		captureProfile(result, findUnit(key))
	end
	recentDuel = result
	D:PruneWorldDamage(result)
	if not shouldRecord then return end
	local t = Sintezza_RivalsPvPDB.duels
	t[#t + 1] = result
	while #t > CAP do table.remove(t, 1) end

	if won == nil then
		ns:Notify("duel", "duel with %s finished, result unreadable", tostring(opponent))
		ns:Log("warn", "duel result message did not match either pattern; raw lines kept on the record")
	else
		ns:Notify("duel", won and "duel won against %s" or "duel lost to %s", tostring(opponent))
	end
	if ns.UI then ns.UI:MarkDirty() end
end

--------------------------------------------------------------------- events
local function onSystem(_, text)
	local fight = not stale() and pending or nil
	if not (fight or ns:IsRecording("duels") or ns:IsRecording("fights")) then return end
	text = Safe(text)
	if type(text) ~= "string" then return end

	-- keep what the game said during a duel, so an unmatched result is
	-- diagnosable instead of lost
	if fight and fight.record and ns:IsRecording("duels") then
		fight.raw[#fight.raw + 1] = text
		if #fight.raw > RAW_KEEP then table.remove(fight.raw, 1) end
	end

	local opponent, won, kind = ReadResult(text, fight and fight.ownKey)
	if opponent then record(opponent, won, kind) end
end

local function onRequested(_, challenger)
	startPending(Safe(challenger))
end

-- The duel is over and no message matched: record it anyway. Who won is not
-- knowable without the message, so it is stored as unknown rather than guessed.
local function onFinished()
	if stale() then
		pending = nil
		return
	end
	-- A declined or cancelled duel fires this too. One that was actually fought
	-- took a three second countdown and then a fight; anything over in a few
	-- seconds was never a duel, so it is dropped rather than recorded as one.
	local finishedAt = now()
	if (finishedAt - pending.ts) < MIN_UNKNOWN_DUEL_SECONDS then
		pending = nil
		return
	end
	local finished = pending
	if finished.finishedAt then return end
	finished.finishedAt = finishedAt
	if finished.record and ns:IsRecording("duels") then
		captureProfile(finished, findUnit(opponentKey(finished.opponent)))
	end
	C_Timer.After(2, function()
		if pending == finished then
			ns:Guard(function() record(finished.opponent, nil, "unknown") end)
		end
	end)
end

function D:StopRecording()
	if pending then pending.record = false end
end

local function RecoverResults()
	local ownKey = opponentKey(ns.UnitCharacterName("player"))
	if not ownKey then return end
	for _, duel in ipairs(Sintezza_RivalsPvPDB.duels) do
		if duel.won == nil and type(duel.rawLines) == "table" and duel.opponent then
			local expected = opponentKey(duel.opponent)
			local result, finish, conflict
			for _, line in ipairs(duel.rawLines) do
				local opponent, won, kind = ReadResult(line, ownKey)
				if opponent and opponentKey(opponent) == expected then
					if result ~= nil and (result ~= won or finish ~= kind) then
						conflict = true
						break
					end
					result, finish = won, kind
				end
			end
			if result ~= nil and not conflict then
				duel.won, duel.kind = result, finish
				if ns.UI then ns.UI:MarkDirty() end
			end
		end
	end
end

local function NeedsProfile(record)
	return not (record.class and record.level and record.faction and record.raceName)
end

local function onTargetChanged()
	if not ns:IsRecording("duels") or not root.Read(UnitIsPlayer, "target") then return end
	local key = fullKey(ns.UnitCharacterName("target"))
	if not key then return end
	local profile, changed
	if not stale() and pending.record and opponentKey(pending.opponent) == key then
		profile = unitProfile("target")
		mergeProfile(pending, profile)
	end
	for _, duel in ipairs(Sintezza_RivalsPvPDB.duels) do
		if NeedsProfile(duel) and opponentKey(duel.opponent) == key then
			profile = profile or unitProfile("target")
			changed = mergeProfile(duel, profile) or changed
		end
	end
	if changed and ns.UI then ns.UI:MarkDirty() end
end

function D:Enable()
	buildPatterns()
	if #PATTERNS == 0 then
		ns:Log("warn", "duel result patterns unavailable (DUEL_WINNER_* globals missing)")
	end
	RecoverResults()
	self:PruneWorldDamage()
	for _, duel in ipairs(Sintezza_RivalsPvPDB.duels) do
		if NeedsProfile(duel) then
			local _, profile = self:FindSighting(duel.opponent, duel.guid)
			if mergeProfile(duel, profile) and ns.UI then ns.UI:MarkDirty() end
		end
	end
	onTargetChanged()
	ns:On("CHAT_MSG_SYSTEM", onSystem)
	ns:On("DUEL_REQUESTED", onRequested)
	ns:On("DUEL_FINISHED", onFinished)
	ns:On("PLAYER_TARGET_CHANGED", onTargetChanged)
	-- the challenger side: StartDuel is what the default UI calls
	if type(_G.StartDuel) ~= "function" then return end
	hooksecurefunc("StartDuel", function(unit)
		unit = Safe(unit) or "target"
		if type(unit) == "string" and root.Read(UnitIsPlayer, unit) then
			startPending(ns.UnitCharacterName(unit), unit)
		end
	end)
end
