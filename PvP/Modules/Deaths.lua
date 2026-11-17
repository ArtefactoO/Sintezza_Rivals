-- Sintezza Rivals / Deaths.lua: own deaths, killers, kills, nemesis
-- No combat log on this client (ADDON_ACTION_FORBIDDEN). The killer comes from
-- the death recap; without one, from who was targeted or seen around you.
local ADDON, root = ...
local ns = root.PvP

local D = {}
ns.Deaths = D
ns.modules.Deaths = D

local now = _G.GetServerTime or time
local Safe = ns.Safe

local MAX_CONTACTS = 8       -- rolling hostile-player contact list
local CONTACT_WINDOW = 120   -- seconds a contact stays a candidate
local KILLER_WINDOW = 60     -- seconds within which a contact is blamed
local HINT_WINDOW = 25       -- seconds of combat chat kept with a death
local HINT_CAP = 12
local DEATH_CAP = 100
local NEMESIS_CAP = 300

D.contacts = {}
D.hints = {}

----------------------------------------------------------------- helpers
local function try(fn, ...)
	local ok, a, b, c = pcall(fn, ...)
	if not ok then return nil end
	return Safe(a), Safe(b), Safe(c)
end

local function here()
	local mapID, x, y
	if ns.Sightings and ns.Sightings.PlayerPos then mapID, x, y = ns.Sightings.PlayerPos() end
	-- UnitPosition returns y, x (that order), and the minimap math depends on it
	local wy, wx = try(UnitPosition, "player")
	return {
		mapID = mapID, x = x, y = y, worldX = wx, worldY = wy,
		zone = try(GetRealZoneText), subZone = try(GetSubZoneText),
	}
end
D.PlayerLocation = here

local function nemesisBump(who, field, zone)
	if not who or not (who.guid or who.name) then return end
	local key = who.guid or who.name
	local n = Sintezza_RivalsPvPDB.nemesis[key]
	if not n then
		n = { name = who.name, class = who.class, killsOnMe = 0, killedByMe = 0 }
		Sintezza_RivalsPvPDB.nemesis[key] = n
	end
	n.name = who.name or n.name
	n.class = who.class or n.class
	n[field] = (n[field] or 0) + 1
	n.lastEncounter = now()
	n.lastZone = zone or n.lastZone
	if field == "killsOnMe" and ns.Watchlist then
		ns.Watchlist:AutoWatch(key, n.name, n.class, n.killsOnMe)
	end
	-- the tally is keyed by enemy and nothing else ever removed from it
	local count = 0
	for _ in pairs(Sintezza_RivalsPvPDB.nemesis) do count = count + 1 end
	if count > NEMESIS_CAP then
		local oldestKey, oldestTs
		for k, v in pairs(Sintezza_RivalsPvPDB.nemesis) do
			if not oldestTs or (v.lastEncounter or 0) < oldestTs then oldestKey, oldestTs = k, v.lastEncounter or 0 end
		end
		Sintezza_RivalsPvPDB.nemesis[oldestKey] = nil
	end
end

local function zoneBump(mapID, field)
	local z = mapID and Sintezza_RivalsPvPDB.zones[mapID]
	if not z then return end
	z[field] = (z[field] or 0) + 1
	z.lastActivity = now()
end

----------------------------------------------------------------- contacts
-- called by Sightings for every qualified enemy player sighting
function D:Contact(rec, source)
	if not ns:IsRecording("fights") then return end
	local key = rec.guid or rec.name
	if not key then return end
	for i = #D.contacts, 1, -1 do
		if D.contacts[i].key == key then table.remove(D.contacts, i) end
	end
	table.insert(D.contacts, 1, {
		key = key, name = rec.name, class = rec.class, level = rec.level,
		guid = rec.guid, ts = now(), source = source,
	})
	while #D.contacts > MAX_CONTACTS do table.remove(D.contacts) end
end

local CANDIDATE_KEEP = 3

local function candidates(ts)
	local out = {}
	for _, c in ipairs(D.contacts) do
		if #out >= CANDIDATE_KEEP then break end
		if ts - c.ts <= CONTACT_WINDOW then
			out[#out + 1] = { name = c.name, class = c.class, level = c.level,
				guid = c.guid, age = ts - c.ts, source = c.source }
		end
	end
	return out
end

----------------------------------------------------------------- combat chat sniffer
-- Only the chat events this client has (NOTES.md): registering a missing one
-- logs an error on every login. The text is kept as hints on a death record,
-- and the durability and honor messages carry signals of their own.
local CHAT_EVENTS = {
	"CHAT_MSG_COMBAT_HONOR_GAIN", "CHAT_MSG_COMBAT_XP_GAIN", "CHAT_MSG_COMBAT_FACTION_CHANGE",
	"CHAT_MSG_COMBAT_MISC_INFO", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_MONSTER_EMOTE",
}
local pendingDurability

local function onCombatChat(event, text)
	if root.IsBattleground() then return end
	local recording = ns:IsRecording("fights")
	if event == "CHAT_MSG_COMBAT_MISC_INFO" then
		-- A late durability message can still invalidate a death captured before pausing.
		local stamp = now()
		if pendingDurability and stamp - pendingDurability.time <= 3 then pendingDurability.lost = true end
		if recording then D.lastMiscInfo = stamp end
	end
	if not recording then return end
	text = Safe(text)
	ns:LogRaw(event, text)
	if not text then return end
	table.insert(D.hints, 1, { ts = now(), event = event, text = text })
	while #D.hints > HINT_CAP do table.remove(D.hints) end
end

local HINT_KEEP = 4

local function hintsSince(ts)
	local out = {}
	for _, h in ipairs(D.hints) do
		if #out >= HINT_KEEP then break end
		if ts - h.ts <= HINT_WINDOW then out[#out + 1] = h.event .. " :: " .. h.text end
	end
	return out
end

----------------------------------------------------------------- death
-- The target is already cleared by the time PLAYER_DEAD fires, so reading
-- "target" here is useless. Contacts are newest-first; an enemy we were *targeting* seconds
-- before dying is the strongest signal available without a combat log, a
-- nameplate that merely stood nearby is the weakest.
local FRESH = 5

local function pickKiller(cands)
	for _, c in ipairs(cands) do
		if c.source == "target" and c.age <= FRESH then return c, "targeted-" .. c.age .. "s-before" end
	end
	for _, c in ipairs(cands) do
		if c.age <= FRESH then return c, tostring(c.source) .. "-" .. c.age .. "s-before" end
	end
	if cands[1] and cands[1].age <= KILLER_WINDOW then
		return cands[1], "last-contact-" .. cands[1].age .. "s-before"
	end
	return nil, nil
end

-- A PvE finishing blow removes the death outcome. Readable player damage from
-- the same combat is retained as an incoming-damage entry.
local function KeepCombatDamage(rec)
	if not (rec.combatAttackers and rec.meterSession and rec.meterStartedAt) then return end
	local entries = Sintezza_RivalsPvPDB.incoming
	for _, entry in ipairs(entries) do
		if entry.meterSession == rec.meterSession and entry.meterStartedAt == rec.meterStartedAt then return end
	end
	local entry = {
		ts = rec.meterStartedAt, ended = rec.ts, players = rec.combatAttackers,
		meterSession = rec.meterSession, meterStartedAt = rec.meterStartedAt,
		location = { mapID = rec.mapID, zone = rec.zone, subZone = rec.subZone,
			x = rec.x, y = rec.y, worldX = rec.worldX, worldY = rec.worldY },
	}
	ns.Duels:StripRecentDuelDamage(entry)
	if #entry.players == 0 then return end
	entries[#entries + 1] = entry
	while #entries > 100 do table.remove(entries, 1) end
end

local function dropDeath(rec)
	local t = Sintezza_RivalsPvPDB.deaths
	local removed
	for i = #t, 1, -1 do
		if t[i] == rec then table.remove(t, i); removed = true end
	end
	if not removed then return end
	KeepCombatDamage(rec)
	local z = rec.mapID and Sintezza_RivalsPvPDB.zones[rec.mapID]
	if z and (z.deaths or 0) > 0 then z.deaths = z.deaths - 1 end
	if rec.counted and rec.killer then
		local key = rec.killer.guid or rec.killer.name
		local n = key and Sintezza_RivalsPvPDB.nemesis[key]
		if n and (n.killsOnMe or 0) > 0 then
			n.killsOnMe = n.killsOnMe - 1
			if n.killsOnMe == 0 and (n.killedByMe or 0) == 0 then Sintezza_RivalsPvPDB.nemesis[key] = nil end
		end
	end
	if ns.UI then ns.UI:MarkDirty() end
end

----------------------------------------------------------------- pet owners
-- The recap names an enemy pet by the pet's own GUID. Its tooltip says whose it
-- is ("Name's Pet"), so the owner of every hostile pet that shows up is
-- remembered, and at a death the damage of the pet goes to its owner.
local PET_TTL, PET_CAP = 3600, 200
D.petOwners = {}
local ownerPatterns

-- "%s's Pet" and its siblings, from the client's own strings, as match patterns
local function patterns()
	if ownerPatterns then return ownerPatterns end
	ownerPatterns = {}
	for _, g in ipairs({ "UNITNAME_TITLE_PET", "UNITNAME_TITLE_MINION", "UNITNAME_TITLE_GUARDIAN",
		"UNITNAME_TITLE_CREATION", "UNITNAME_TITLE_CHARM", "UNITNAME_TITLE_COMPANION" }) do
		local f = _G[g]
		if type(f) == "string" and f:find("%%s") then
			local p = f:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
			p = p:gsub("%%s", "(.+)")
			ownerPatterns[#ownerPatterns + 1] = "^" .. p .. "$"
		end
	end
	return ownerPatterns
end

local function ownerFromTooltip(unit)
	if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return nil end
	local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
	if not ok or type(data) ~= "table" or ns.IsSecret(data) or type(data.lines) ~= "table" then return nil end
	for _, line in ipairs(data.lines) do
		local text = Safe(line.leftText)
		if type(text) == "string" then
			for _, p in ipairs(patterns()) do
				local owner = text:match(p)
				if owner then return owner end
			end
		end
	end
	return nil
end

-- called for nameplates, the target and the mouseover: a hostile unit that a
-- player controls and is not a player is someone's pet or guardian
local function notePet(unit)
	if not ns:IsRecording("fights") then return end
	unit = Safe(unit)
	if not unit or not Safe(UnitExists(unit)) or Safe(UnitIsPlayer(unit)) then return end
	if not Safe(UnitPlayerControlled(unit)) or not Safe(UnitCanAttack("player", unit)) then return end
	local guid = Safe(UnitGUID(unit))
	if not guid then return end
	local previous = D.petOwners[guid]
	if previous and now() - previous.ts <= PET_TTL then return end
	local owner = ownerFromTooltip(unit)
	if not owner then return end
	D.petOwners[guid] = { name = owner, ts = now() }
	local n, cut = 0, now() - PET_TTL
	for g, o in pairs(D.petOwners) do
		if o.ts < cut then D.petOwners[g] = nil else n = n + 1 end
	end
	if n > PET_CAP then wipe(D.petOwners) end
end
D.NotePet = notePet

-- Resolve a pet by its tooltip owner, using the current recap before older sightings.
local function ownerOf(petGuid, recapNames)
	local o = D.petOwners[petGuid]
	if o and now() - o.ts > PET_TTL then o = nil end
	if not o then
		for _, unit in ipairs({ "target", "mouseover", "focus" }) do
			if Safe(UnitGUID(unit)) == petGuid then notePet(unit) end
		end
		for i = 1, 40 do
			local unit = "nameplate" .. i
			if Safe(UnitGUID(unit)) == petGuid then notePet(unit) break end
		end
		o = D.petOwners[petGuid]
	end
	local name = o and (now() - o.ts <= PET_TTL) and o.name
	if not name then return end
	local guid = recapNames[name]
	if guid then return guid, name end
	if guid == false then return "name:" .. name, name end
	for key, rec in pairs(Sintezza_RivalsPvPDB.sightings) do
		if rec.name == name and root.IsPlayerGUID(key) then
			if guid then return "name:" .. name, name end
			guid = key
		end
	end
	return guid or "name:" .. name, name
end

-- C_DeathRecap (checked on Forever 1.60.1): the last ten hits before a death,
-- newest first, each with sourceGUID, sourceName, sourceFlags, amount and a
-- server timestamp, all readable once you are dead. When it has them, nobody
-- has to be guessed: the enemy players in it, how much each took off you, and
-- who landed the killing blow. A pet's damage counts for its owner; a pet
-- whose owner cannot be found is left out. Returns nil without a recap of this
-- death.
local RECAP_AGE = 12
local CONF_WORD = { high = "sure", medium = "likely", low = "guess", none = "unknown" }
-- recap source flags: controlled by a player, hostile to you
local FLAG_PLAYER_CONTROLLED, FLAG_HOSTILE = 0x100, 0x40

local function playerInfo(guid, fallbackName)
	local rec = Sintezza_RivalsPvPDB.sightings[guid]
	if rec and rec.lastSource == "comms" then rec = nil end
	local name, class, raceName, race, level, fullName, faction
	if guid:match("^Player%-") then
		local ok, _, c, rn, rt, _, n = pcall(GetPlayerInfoByGUID, guid)
		if ok then class, raceName, race, name = Safe(c), Safe(rn), Safe(rt), Safe(n) end
		for _, unit in ipairs({ "target", "mouseover", "focus" }) do
			if try(UnitGUID, unit) == guid then
				fullName = ns.UnitCharacterName(unit)
				level = try(UnitLevel, unit)
				faction = try(UnitFactionGroup, unit)
				break
			end
		end
	end
	return { guid = (guid:match("^name:") == nil) and guid or nil,
		name = fullName or fallbackName or (rec and rec.name) or name,
		class = class or (rec and rec.class), level = level or (rec and rec.level),
		raceName = raceName or (rec and rec.raceName), race = race or (rec and rec.race),
		faction = faction or (rec and rec.faction), guild = rec and rec.guild }
end
D.PlayerInfo = playerInfo

local function ReadableTable(value)
	value = Safe(value)
	if type(value) == "table" and (not canaccesstable or canaccesstable(value)) then return value end
end

function D:OwnNames()
	local names = {}
	local separator = Constants and Constants.CharacterNameSeparatorConsts
		and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR or " "
	local function add(name, surname)
		if type(name) ~= "string" or name == "" then return end
		names[name] = true
		if type(surname) == "string" and surname ~= "" then
			names[name .. separator .. surname] = true
			names[name .. " " .. surname] = true
			names[name .. "-" .. surname] = true
		end
	end
	-- Forever's meter can include the surname even when the player hides it.
	if UnitNameUnmodified then add(try(UnitNameUnmodified, "player")) end
	add(try(UnitName, "player"))
	add(try(UnitFullName, "player"))
	return names
end

local function IncomingPlayers(sessionID, meterType)
	local meter = C_DamageMeter
	local session = ReadableTable(try(meter.GetCombatSessionFromID, sessionID, meterType))
	local sources = session and ReadableTable(session.combatSources)
	if not sources then return end
	local ownGUID = try(UnitGUID, "player")
	if not ownGUID then return end
	for _, value in ipairs(sources) do
		local source = ReadableTable(value)
		if source and Safe(source.isLocalPlayer) == true and Safe(source.sourceGUID) == ownGUID then
			local data = ReadableTable(try(meter.GetCombatSessionSourceFromID, sessionID, meterType, ownGUID))
			local spells = data and ReadableTable(data.combatSpells)
			if not spells then return end
			local ownNames = D:OwnNames()
			local sourceName = Safe(source.name)
			if type(sourceName) == "string" and sourceName ~= "" then ownNames[sourceName] = true end
			local players, byName = {}, {}
			for _, item in ipairs(spells) do
				local spell = ReadableTable(item)
				local detail = spell and ReadableTable(spell.combatSpellDetails)
				local name = detail and Safe(detail.unitName)
				local class = detail and Safe(detail.unitClassFilename)
				local amount = detail and (Safe(detail.amount) or Safe(spell.totalAmount))
				if type(name) == "string" and name ~= "" and not ownNames[name]
					and type(class) == "string" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
					and Safe(detail.isPet) == false and Safe(detail.isMob) == false
					and type(amount) == "number" and amount > 0 then
					local who = byName[name]
					if not who then
						who = { name = name, class = class, damage = 0 }
						byName[name] = who
						players[#players + 1] = who
					end
					who.damage = who.damage + amount
				end
			end
			table.sort(players, function(a, b) return a.damage > b.damage end)
			return players
		end
	end
end

local function TrackIncomingDamage()
	local meter = C_DamageMeter
	local meterType = Enum and Enum.DamageMeterType and Enum.DamageMeterType.DamageTaken
	if not (meterType and meter and meter.GetCombatSessionFromID and meter.GetCombatSessionSourceFromID) then return end
	local combat, pending, lastSession, firstHit
	local function reset() combat, pending, lastSession, firstHit = nil, nil, nil, nil end
	D.ResetIncomingDamage = reset
	local function destination()
		if root.IsBattleground() then return root.BattlegroundMatch() end
		if ns:IsRecording("fights") and try(IsInInstance) == false then return "world" end
	end
	function D:AttachCombatDeath(record)
		local segment = combat or pending
		if not segment or not segment.hit or segment.destination ~= destination() then return end
		local stamp = record.ts or record.time
		if segment.ended and stamp and stamp > segment.ended then return end
		segment.died = true
		segment.deathRecords = segment.deathRecords or {}
		for _, known in ipairs(segment.deathRecords) do
			if known == record or (known.ts ~= nil) == (record.ts ~= nil) then return end
		end
		segment.deathRecords[#segment.deathRecords + 1] = record
	end

	local function save(segment)
		if not (segment.hit and segment.id and segment.id ~= lastSession) then return end
		if destination() ~= segment.destination then return end
		local players = IncomingPlayers(segment.id, meterType)
		if not players then return end
		lastSession = segment.id
		if #players == 0 then return end
		local guids = {}
		local function Remember(person)
			if not person or not person.name or not root.IsPlayerGUID(person.guid) then return end
			local known = guids[person.name]
			guids[person.name] = (known == nil or known == person.guid) and person.guid or false
		end
		for _, contact in ipairs(D.contacts) do
			if contact.ts >= segment.hit - 5 then Remember(contact) end
		end
		for _, record in pairs(Sintezza_RivalsPvPDB.sightings) do
			if (record.lastSeen or 0) >= segment.hit - 5 then Remember(record) end
		end
		for _, record in ipairs(segment.deathRecords or {}) do
			Remember(record.killer or record)
			for _, attacker in ipairs(record.attackers or record.helpers or {}) do Remember(attacker) end
		end
		for _, player in ipairs(players) do player.guid = guids[player.name] or nil end

		local attached
		for _, record in ipairs(segment.deathRecords or {}) do
			record.combatAttackers = players
			record.meterSession, record.meterStartedAt = segment.id, segment.hit
			local records = segment.destination == "world" and Sintezza_RivalsPvPDB.deaths
				or segment.destination.fights
			for _, saved in ipairs(records) do if saved == record then attached = true; break end end
		end
		if attached then
			if ns.UI then ns.UI:MarkDirty() end
			return
		end
		if segment.destination ~= "world" then
			root.AddBattlegroundFight(segment.destination,
				{ result = "incoming", time = segment.hit, ended = segment.ended, location = segment.location, players = players })
			return
		end
		local entry = { ts = segment.hit, ended = segment.ended, location = segment.location, players = players }
		if segment.died then entry.meterSession, entry.meterStartedAt = segment.id, segment.hit end
		ns.Duels:StripRecentDuelDamage(entry)
		if #players == 0 then return end
		local entries = Sintezza_RivalsPvPDB.incoming
		entries[#entries + 1] = entry
		while #entries > 100 do table.remove(entries, 1) end
		if ns.UI then ns.UI:MarkDirty() end
	end
	ns:On("PLAYER_ENTERING_WORLD", reset)
	ns:On("DAMAGE_METER_RESET", reset)
	ns:On("PLAYER_REGEN_DISABLED", function()
		local previous = pending
		pending = nil
		if previous then save(previous) end
		local current = destination()
		combat = current and (firstHit and firstHit.destination == current
			and GetTime() - firstHit.receivedAt <= .5 and firstHit or { destination = current }) or nil
		firstHit = nil
	end)
	ns:On("PLAYER_DEAD", function()
		local segment = combat or pending
		if segment then segment.died = true end
	end)
	ns:On("UNIT_COMBAT", function(_, unit, action, _, amount)
		if Safe(unit) ~= "player" or Safe(action) ~= "WOUND" then return end
		amount = Safe(amount)
		if type(amount) == "number" and amount <= 0 then return end
		if combat then
			if not combat.hit then combat.hit, combat.location = now(), here() end
		else
			local current = destination()
			if current then firstHit = { hit = now(), location = here(), receivedAt = GetTime(), destination = current } end
		end
	end)
	ns:On("DAMAGE_METER_COMBAT_SESSION_UPDATED", function(_, kind, id)
		local segment = combat or pending
		id = Safe(id)
		if segment and Safe(kind) == meterType and type(id) == "number" and id > 0 then segment.id = id end
	end)
	ns:On("PLAYER_REGEN_ENABLED", function()
		local segment = combat
		combat, pending = nil, segment
		if not segment then return end
		segment.ended = now()
		C_Timer.After(.8, function()
			if pending ~= segment then return end
			pending = nil
			if try(InCombatLockdown) == false then save(segment) end
		end)
	end)
end

local function readRecap(ts)
	local R = C_DeathRecap
	if not (R and R.HasRecapEvents and R.GetRecapEvents) then return nil end
	local okH, has = pcall(R.HasRecapEvents)
	if not okH or Safe(has) ~= true then return nil end
	local ok, events = pcall(R.GetRecapEvents)
	if not ok or type(events) ~= "table" or ns.IsSecret(events) then return nil end
	if canaccesstable and not canaccesstable(events) then return nil end
	local first = Safe(events[1])
	if type(first) ~= "table" or (canaccesstable and not canaccesstable(first)) then return nil end
	local stamp = Safe(first.timestamp)
	if type(stamp) ~= "number" or math.abs(ts - stamp) > RECAP_AGE then return nil end
	local identity = table.concat({ stamp, Safe(first.sourceGUID) or "", Safe(first.amount) or "", #events }, "/")
	if Sintezza_RivalsPvPDB.lastRecap == identity then return nil end
	local me = Safe(UnitGUID("player"))
	local recapNames = {}
	for _, event in ipairs(events) do
		local e = ReadableTable(event)
		if e then
			local guid, name = Safe(e.sourceGUID), Safe(e.sourceName)
			if root.IsPlayerGUID(guid) and guid ~= me and type(name) == "string" and name ~= "" then
				local known = recapNames[name]
				recapNames[name] = (known == nil or known == guid) and guid or false
			end
		end
	end
	local by, list, total, blow, unknownPet = {}, {}, 0, nil, false
	for index, event in ipairs(events) do
		local e = Safe(event)
		if type(e) == "table" and (not canaccesstable or canaccesstable(e)) then
			local guid, amount, flags = Safe(e.sourceGUID), Safe(e.amount) or 0, Safe(e.sourceFlags) or 0
			local key, ownerName
			if type(guid) == "string" and guid ~= me and type(amount) == "number" and amount > 0
				and type(flags) == "number" and bit.band(flags, FLAG_HOSTILE) ~= 0 then
				if guid:match("^Player%-") then
					key = guid
				elseif bit.band(flags, FLAG_PLAYER_CONTROLLED) ~= 0 then
					key, ownerName = ownerOf(guid, recapNames)
					if not key then unknownPet = true end
				end
			end
			if key then
				local a = by[key]
				if not a then
					a = playerInfo(key, ownerName or Safe(e.sourceName))
					a.damage = 0
					by[key] = a
					list[#list + 1] = a
				end
				a.damage = a.damage + amount
				total = total + amount
				if index == 1 then blow = a end
			end
		end
	end
	Sintezza_RivalsPvPDB.lastRecap = identity
	for _, a in ipairs(list) do a.share = total > 0 and (a.damage / total) or (1 / #list) end
	table.sort(list, function(x, y) return x.damage > y.damage end)
	return { attackers = list, blow = blow, unknownPet = unknownPet }
end

-- what happened to the death once the recap is in: counted against the
-- players in it, or against the heuristic's pick when there is no recap,
-- or dropped when the recap shows nobody but monsters
local function finishDeath(rec, crowd, recap)
	if recap and #recap.attackers == 0 then
		if not recap.unknownPet then
			dropDeath(rec)
			ns:Log("info", "death dropped: the death recap names no player")
			return
		end
	end
	if recap then
		local blow = recap.blow
		rec.killer, rec.killerClass = blow, blow and blow.class
		rec.killerSource, rec.confidence = "death recap", blow and "high" or "none"
		rec.verifiedKiller = blow ~= nil
		rec.crowd = #recap.attackers
		rec.attackers = {}
		for i, a in ipairs(recap.attackers) do
			rec.attackers[i] = { guid = a.guid, name = a.name, class = a.class, level = a.level,
				raceName = a.raceName, race = a.race, damage = a.damage, share = a.share }
		end
		if blow then nemesisBump(blow, "killsOnMe", rec.zone) end
		rec.counted = blow ~= nil
	else
		rec.crowd = crowd
		if rec.killer and (rec.confidence == "high" or rec.confidence == "medium") then
			-- a bystander must not end up on the nemesis list
			nemesisBump(rec.killer, "killsOnMe", rec.zone)
			rec.counted = true
		end
	end

	local killer = rec.killer
	local outcome = killer and killer.name and ns.L("Killed by %s (%s)"):format(killer.name,
		ns.L(CONF_WORD[rec.confidence] or "unknown")) or ns.L("You died. Killer unknown.")
	local zone, subZone = rec.zone, rec.subZone
	local place = zone or ""
	if subZone and subZone ~= "" and subZone ~= zone then
		place = place ~= "" and place .. " / " .. subZone or subZone
	end
	if type(rec.x) == "number" and type(rec.y) == "number" then
		local coords = ("%.1f, %.1f"):format(rec.x * 100, rec.y * 100)
		place = place ~= "" and ("%s (%s)"):format(place, coords) or coords
	end
	if place ~= "" then place = " · " .. place end
	local top, extra = rec.attackers and rec.attackers[1], ""
	if top and top.name and #rec.attackers > 1 then
		extra = ns.L(" · Most damage from %s (%d%%)"):format(top.name, math.floor(top.share * 100 + 0.5))
	end
	ns:Notify("death", "%s%s%s", outcome, place, extra)
	ns:Log("info", "death in %s killer=%s via %s conf=%s attackers=%d",
		tostring(rec.zone), killer and tostring(killer.name) or "nil", rec.killerSource, rec.confidence,
		rec.attackers and #rec.attackers or 0)

	if ns.UI then ns.UI:MarkDirty() end
end

-- The recap is filled a moment after PLAYER_DEAD, and how long that takes
-- varies: it is read at 0.3, 1 and 2 seconds, and the first read that has
-- this death wins. After the last try the death is finished without it.
local RECAP_TRIES = { 0.3, 1, 2 }
local worldRecapGeneration = 0
local latestDeathRecord
local function tryRecap(rec, crowd, i, generation)
	if generation ~= worldRecapGeneration or rec ~= latestDeathRecord then return end
	local recap = readRecap(rec.ts)
	if not recap and i < #RECAP_TRIES then
		C_Timer.After(RECAP_TRIES[i + 1] - RECAP_TRIES[i], function() ns:Guard(tryRecap, rec, crowd, i + 1, generation) end)
		return
	end
	finishDeath(rec, crowd, recap)
end

----------------------------------------------------------------- what they are known for
-- From your own counted deaths: how a player kills you. The names are
-- Sintezza Rivals's own. Returns a list of names, or nothing.
function D:KnownFor(name)
	if not name then return nil end
	local n, solo, pack, low, slayer, times = 0, 0, 0, 0, 0, {}
	for _, d in ipairs(Sintezza_RivalsPvPDB.deaths) do
		local k = d.killer
		if k and k.name == name and (d.confidence == "high" or d.confidence == "medium") then
			n = n + 1
			local crowd = d.crowd or (d.attackers and #d.attackers)
			if crowd then
				if crowd <= 1 then solo = solo + 1 elseif crowd >= 3 then pack = pack + 1 end
			end
			if d.myLevel and k.level and k.level > 0 then
				if k.level - d.myLevel >= 10 then low = low + 1 end
				if d.myLevel - k.level >= 5 then slayer = slayer + 1 end
			end
			times[#times + 1] = d.ts or 0
		end
	end
	if n == 0 then return nil end
	local out = {}
	if n >= 2 and solo * 3 >= n * 2 then out[#out + 1] = "Lone wolf" end
	if n >= 2 and pack * 3 >= n * 2 then out[#out + 1] = "Pack hunter" end
	if low >= 2 then out[#out + 1] = "Lowbie farmer" end
	-- three kills on you inside one hour
	table.sort(times)
	for i = 3, #times do
		if times[i] - times[i - 2] <= 3600 then out[#out + 1] = "Camper" break end
	end
	if slayer >= 1 then out[#out + 1] = "Giant slayer" end
	return #out > 0 and out or nil
end

local PATTERN_LABELS = {
	["Lone wolf"] = { "One-person problem", "Solo trouble", "No backup needed", "Party of one", "Uninvited duel", "Lone wolf" },
	["Pack hunter"] = { "Brought friends", "Solo, with backup", "Full party service", "Group project", "Strength in numbers", "Pack hunter" },
	["Lowbie farmer"] = { "Sandbox champion", "Picks on the little guy", "Grey-name collector", "Training dummy enthusiast", "Low-level specialist", "Lowbie farmer" },
	["Camper"] = { "Frequent visitor", "Reserved this spot", "Same time, same place", "Not done yet", "Knows the way back", "Camper" },
	["Giant slayer"] = { "Size does not matter", "Punches above their level", "Level is just a number", "Took the uphill fight", "Found the weak spot", "Giant slayer" },
}

function D:PatternLabel(name, pattern)
	local labels = PATTERN_LABELS[pattern]
	if not labels then return ns.L(pattern) end
	-- A stable cosmetic choice; reopening a card must not reroll its description.
	local hash = 0
	local seed = tostring(name or "") .. ":" .. pattern
	for index = 1, #seed do hash = (hash * 33 + seed:byte(index)) % 2147483647 end
	return ns.L(labels[hash % #labels + 1])
end

function D:PatternHelp(pattern)
	return ns.L(pattern .. " rule")
end

function D:OnDeath()
	latestDeathRecord = nil
	if not ns:IsRecording("fights") then return end
	if ns.context ~= "world" and ns.context ~= "world_combat" then return end
	if root.IsBattleground() then return end
	local ts = now()
	local pos = here()
	local cands = candidates(ts)
	local killer, how = pickKiller(cands)

	-- already known to be a mob kill: never stored at all
	if D.lastMiscInfo and (ts - D.lastMiscInfo) <= FRESH then
		ns:Log("info", "death in %s ignored, durability loss means it was not a player", tostring(pos.zone))
		return
	end

	-- the fallback when there is no recap: who was around you
	local confidence = "none"
	if killer then
		if how and string.find(how, "^targeted") then confidence = "high"
		elseif killer.age <= FRESH then confidence = "medium"
		else confidence = "low" end
	end
	-- In a big fight "the enemy I touched last" stops meaning much. Count the
	-- distinct enemies in fresh contact: with three or more around, an
	-- untargeted pick is only a guess, and with six or more even your own
	-- target is only likely. A guess is shown but never counted against a
	-- player, so a crowded fight cannot put a bystander on your list.
	local crowd = 0
	for _, c in ipairs(D.contacts) do
		if ts - c.ts <= FRESH then crowd = crowd + 1 end
	end
	if crowd >= 6 and confidence == "high" then confidence = "medium"
	elseif crowd >= 3 and confidence == "medium" then confidence = "low" end

	local rec = {
		ts = ts, mapID = pos.mapID, x = pos.x, y = pos.y, myLevel = Safe(UnitLevel("player")),
		worldX = pos.worldX, worldY = pos.worldY, zone = pos.zone, subZone = pos.subZone,
		killer = killer, killerSource = how or "unknown",
		killerClass = killer and killer.class or nil,
		confidence = confidence,
		candidates = cands, chatHints = hintsSince(ts),
		combatSeconds = D.lastCombatStart and (ts - D.lastCombatStart) or nil,
	}
	local t = Sintezza_RivalsPvPDB.deaths
	t[#t + 1] = rec
	latestDeathRecord = rec
	if D.AttachCombatDeath then D:AttachCombatDeath(rec) end
	while #t > DEATH_CAP do table.remove(t, 1) end
	zoneBump(pos.mapID, "deaths")
	if Sintezza_RivalsPvPDB.settings.alerts.screenshotOnDeath then pcall(Screenshot) end

	local generation = worldRecapGeneration
	C_Timer.After(RECAP_TRIES[1], function() ns:Guard(tryRecap, rec, crowd, 1, generation) end)

	-- late durability message: this was a mob after all, undo everything,
	-- unless the recap already showed players in it
	local durability = { time = ts }
	pendingDurability = durability
	C_Timer.After(3, function()
		if generation ~= worldRecapGeneration then return end
		if pendingDurability == durability then pendingDurability = nil end
		if rec.killerSource == "death recap" then return end
		if durability.lost then
			dropDeath(rec)
			ns:Log("info", "death dropped, durability loss arrived late: it was not a player")
		end
	end)
end

----------------------------------------------------------------- output
function D:List(n)
	n = n or 10
	local t = Sintezza_RivalsPvPDB.deaths
	if #t == 0 then return ns:Print("no deaths recorded") end
	ns:Print("--- last %d of %d deaths ---", math.min(n, #t), #t)
	for i = #t, math.max(1, #t - n + 1), -1 do
		local r = t[i]
		ns:Print("#%d %s%s %.1f,%.1f killer=%s (%s, %s) %ds in combat",
			i, tostring(r.zone), (r.subZone and r.subZone ~= "" and (" / " .. r.subZone) or ""),
			(r.x or 0) * 100, (r.y or 0) * 100,
			r.killer and (r.killer.name or "?") or "unknown", tostring(r.killerSource),
			tostring(r.confidence), r.combatSeconds or -1)
		for _, h in ipairs(r.chatHints or {}) do ns:Print("    hint: %s", h) end
	end
	local nem = {}
	for _, v in pairs(Sintezza_RivalsPvPDB.nemesis) do nem[#nem + 1] = v end
	table.sort(nem, function(a, b) return (a.killsOnMe or 0) > (b.killsOnMe or 0) end)
	for i = 1, math.min(5, #nem) do
		local v = nem[i]
		ns:Print("nemesis: %s (%s) killed me %d, killed by me %d",
			tostring(v.name), tostring(v.class), v.killsOnMe or 0, v.killedByMe or 0)
	end
end

function D:OnContextChanged(newContext, oldContext)
	if newContext ~= "bg" and oldContext ~= "bg" then return end
	wipe(D.contacts)
	wipe(D.hints)
	wipe(D.petOwners)
	D.lastMiscInfo, D.lastCombatStart = nil, nil
end

function D:StopRecording()
	if self.ResetIncomingDamage then self.ResetIncomingDamage() end
	wipe(self.contacts)
	wipe(self.hints)
	self.lastMiscInfo, self.lastCombatStart = nil, nil
end

function D:ClearWorldRecording()
	worldRecapGeneration = worldRecapGeneration + 1
	latestDeathRecord = nil
	pendingDurability = nil
	root.CancelWorldDeathRecap()
	if not root.IsBattleground() then self:StopRecording() end
end

function D:Enable()
	TrackIncomingDamage()
	ns:On("PLAYER_DEAD", function() D:OnDeath() end)
	ns:On("PLAYER_REGEN_DISABLED", function()
		if ns:IsRecording(root.IsBattleground() and "battlegrounds" or "fights") then D.lastCombatStart = now() end
	end)
	-- enemy pets: their owner is remembered for the death recap
	ns:On("NAME_PLATE_UNIT_ADDED", function(_, unit) notePet(unit) end)
	ns:On("PLAYER_TARGET_CHANGED", function() notePet("target") end)
	ns:On("UPDATE_MOUSEOVER_UNIT", function() notePet("mouseover") end)
	ns:On("PLAYER_UNGHOST", function() if ns:IsRecording("fights") then ns:Log("info", "released/resurrected") end end)
	ns:On("PLAYER_ALIVE", function() if ns:IsRecording("fights") then ns:Log("info", "alive again") end end)
	for _, e in ipairs(CHAT_EVENTS) do ns:On(e, onCombatChat) end
end
