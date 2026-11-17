local _, root = ...
local ns = root.PvP
local U, X = ns.UI, ns.UIX
local T, TC = ns.Theme, ns.Theme.C
local W = Sintezza_Theme:CreateWidgets(root.Theme)
local CARD_W, HEADER_H, ROW_H, COLUMN_GAP = 560, 54, 22, 20
local detailFrame

local function keyForName(name)
	for key, record in pairs(Sintezza_RivalsPvPDB.sightings) do
		if record.name == name then return key, record end
	end
end

local function duelRecord(name)
	local key = ns.Duels.OpponentKey(name)
	local wins, losses, last, total, longest = 0, 0, nil, 0, 0
	local timed, unknown, faction = 0, 0, nil
	for _, duel in ipairs(Sintezza_RivalsPvPDB.duels) do
		if key and ns.Duels.OpponentKey(duel.opponent) == key then
			if duel.won == true then wins = wins + 1
			elseif duel.won == false then losses = losses + 1
			else unknown = unknown + 1 end
			faction = faction or duel.faction
			if not last or (duel.ts or 0) > (last.ts or 0) then last = duel end
			if duel.seconds and duel.seconds > 0 then
				total, timed = total + duel.seconds, timed + 1
				longest = math.max(longest, duel.seconds)
			end
		end
	end
	return wins, losses, last, timed > 0 and math.floor(total / timed) or nil, longest, unknown, faction
end

local function secs(value)
	if not value or value <= 0 then return nil end
	if value < 60 then return T.L("%ds"):format(value) end
	return T.L("%dm %02ds"):format(math.floor(value / 60), value % 60)
end

local function showSighting(record)
	if ns.Map and record then ns.Map:ShowSpot(record.lastMapID, record.lastX, record.lastY, record.name) end
end

local function refreshActions()
	if root.Changed then root.Changed() end
	if ns.HUD then ns.HUD:Update() end
	U:MarkDirty()
	U:Refresh()
end

local function layoutCard(f)
	f.actions:ClearAllPoints()
	f.actions:SetPoint("TOPLEFT", f.body, "BOTTOMLEFT", 0, -12)
	f:SetHeight(HEADER_H + 8 + 26 + 10 + f.body:GetHeight() + 12 + 24 + 12)
end

local function buildCard()
	local f = T.Window({ name = "Sintezza_RivalsPvPDetail", width = CARD_W, height = 300,
		title = "Player", subtitle = " ", windowAppearance = ns.WindowAppearance, defaultLayer = "DIALOG" })
	f:SetFrameStrata("DIALOG")
	f.footer:Hide()
	f.header:SetHeight(HEADER_H)
	f.content:ClearAllPoints()
	f.content:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", -1, 0)
	f.content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	local crest = CreateFrame("Frame", nil, f.header)
	crest:SetSize(28, 34)
	crest:SetPoint("RIGHT", f.closeButton, "LEFT", -8, 0)
	crest.icon = crest:CreateTexture(nil, "ARTWORK")
	crest.icon:SetAllPoints()
	f.factionCrest = crest
	f.title:SetPoint("RIGHT", crest, "LEFT", -8, 0)
	Sintezza_Theme:TrackAppearance(f.title, "state", function(owner)
		if f.subject then owner:SetTextColor(X.rgb(f.subject.class)) end
	end)
	f.subtitle:SetPoint("RIGHT", crest, "LEFT", -8, 0)
	f.header:EnableMouse(true)
	f.header:RegisterForDrag("LeftButton")
	f.header:SetScript("OnDragStart", function() f:GetScript("OnDragStart")(f) end)
	f.header:SetScript("OnDragStop", function() f:GetScript("OnDragStop")(f) end)
	f.header:HookScript("OnEnter", function(owner)
		W:Tooltip(owner, f.subject and f.subject.name or "", f.profileText or "", "cursor")
	end)
	f.header:HookScript("OnLeave", function(owner) Sintezza_Theme:HideTooltip(owner) end)
	f.header:HookScript("OnHide", function(owner) Sintezza_Theme:HideTooltip(owner) end)

	local score = CreateFrame("Frame", nil, f.content)
	score:SetPoint("TOPLEFT", 12, -8)
	score:SetPoint("TOPRIGHT", -12, -8)
	score:SetHeight(26)
	f.scoreLeft = W:Label(score, "", 12, TC.fg)
	f.scoreLeft:SetPoint("LEFT", 0, 0)
	f.scoreRight = W:Label(score, "", 12, TC.fg)
	f.scoreRight:SetPoint("LEFT", f.scoreLeft, "RIGHT", 22, 0)
	f.badge = W:Label(score, "", 10, TC.accent2)
	f.badge:SetPoint("RIGHT")
	W:SettingsDivider(score)
	f.body = CreateFrame("Frame", nil, f.content)
	f.body:SetPoint("TOPLEFT", score, "BOTTOMLEFT", 0, -10)
	f.body:SetWidth(CARD_W - 24)
	f.rows = {}
	f.sections = {}
	for index = 1, 2 do
		local section = W:Section(f.body, "", nil, "settings")
		section:SetPoint("TOPLEFT", (index - 1) * ((CARD_W - 24 - COLUMN_GAP) / 2 + COLUMN_GAP), 0)
		section:SetSize((CARD_W - 24 - COLUMN_GAP) / 2, 28)
		f.sections[index] = section
	end
	f.actions = CreateFrame("Frame", nil, f.content)
	f.actions:SetSize(CARD_W - 24, 24)
	local function action(label, width, previous, callback, help)
		local button = W:Button(f.actions, T.L(label), callback)
		button:SetSize(width, 24)
		if previous then button:SetPoint("LEFT", previous, "RIGHT", 8, 0) else button:SetPoint("LEFT") end
		T.Tip(button, label, help)
		return button
	end
	f.watchBtn = action("Watch", 128, nil, function()
		local d = f.subject
		if not (d and d.key and ns.Watchlist) then return end
		ns.Watchlist:ToggleWatch(d.key, d.name, d.class)
		U:ShowDetail(d.name, d.key, d.duel, d.context)
		refreshActions()
	end, "Watch help")
	f.ignoreBtn = action("Ignore", 142, f.watchBtn, function()
		local d = f.subject
		if not (d and d.key) then return end
		ns.Watchlist:SetIgnored(d.key, not Sintezza_RivalsPvPDB.ignore[d.key])
		U:ShowDetail(d.name, d.key, d.duel, d.context)
		U:Refresh()
	end, "Ignore help")
	action("Copy", 100, f.ignoreBtn, function()
		if f.subject then U:CopyText(f.subject.name, f.plain or "") end
	end, "Copy player help")
	return f
end

function U:ShowDetail(name, key, duel, context)
	if not name then return end
	local battleground = context and context.kind == "battleground" and context.match
	if key == nil then
		if battleground then key = false
		elseif duel then key = ns.Duels:FindSighting(name) else key = keyForName(name) end
	end
	local db = Sintezza_RivalsPvPDB
	local rec = key and db.sightings[key]
	local sighting = ns.Map and rec and rec.lastMapID and rec.lastX and rec.lastY and rec or nil
	if not detailFrame then detailFrame = buildCard() end
	local f = detailFrame
	local used, plain, ys = 0, {}, { 28, 28 }
	local function row(label, value, column, help, mapSighting)
		column = column or 1
		used = used + 1
		local r = f.rows[used]
		if not r then
			r = W:SettingRow(f.body, "", ROW_H)
			root.Theme:Font(r.label, 12, "", TC.muted)
			r.value = W:Label(r, "", 12, TC.fg)
			r.value:SetPoint("RIGHT", -1, 0)
			r.value:SetJustifyH("RIGHT")
			r.value:SetWordWrap(false)
			r.label:SetWordWrap(false)
			r:EnableMouse(true)
			r:SetScript("OnEnter", function(owner)
				W:Tooltip(owner, owner.caption, owner.fullText .. (owner.helpText and "\n\n" .. owner.helpText or ""), "cursor")
			end)
			r:SetScript("OnLeave", function(owner) Sintezza_Theme:HideTooltip(owner) end)
			r:SetScript("OnHide", function(owner) Sintezza_Theme:HideTooltip(owner) end)
			f.rows[used] = r
		end
		local width = (CARD_W - 24 - COLUMN_GAP) / 2
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", f.body, "TOPLEFT", (column - 1) * (width + COLUMN_GAP), -ys[column])
		r:SetSize(width, ROW_H)
		r.value:SetWidth(label == "Fight patterns" and width - 91 or width - 112)
		r.value:SetWordWrap(true)
		r.value:SetJustifyH(label == "Fight patterns" and "LEFT" or "RIGHT")
		r.label:ClearAllPoints()
		r.label:SetPoint("LEFT")
		r.label:SetPoint("RIGHT", r.value, "LEFT", -8, 0)
		r.caption = T.L(label)
		r.label:SetText(r.caption)
		r.fullText = value ~= nil and value ~= "" and tostring(value) or "-"
		r.helpText = help and T.L(help) or nil
		r.value:SetText(r.fullText)
		local height = math.max(ROW_H, r.value:GetStringHeight() + 6)
		r:SetHeight(height)
		ys[column] = ys[column] + height
		r.value:SetTextColor(unpack(mapSighting and TC.accent2 or TC.fg))
		plain[#plain + 1] = r.caption .. ": " .. r.fullText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
		if mapSighting and not r.mapLink then
			r.mapLink = W:Button(r, "", function() showSighting(r.mapSighting) end)
			r.mapLink:SetPoint("RIGHT", r.value, "RIGHT", 0, 0)
			r.mapLink:SetHeight(ROW_H)
			r.mapLink.text:SetJustifyH("RIGHT")
			T.Tip(r.mapLink, "Show on map", "Sighting position help")
		end
		r.mapSighting = mapSighting
		if r.mapLink then
			r.mapLink:SetShown(mapSighting ~= nil)
			r.mapLink.text:SetText(mapSighting and r.fullText or "")
			r.mapLink:SetWidth(math.min(r.value:GetWidth(), r.value:GetStringWidth() + 16))
		end
		r.value:SetShown(not mapSighting)
		r:Show()
	end

	local score = not duel and root.PvPSource and (battleground
		and root.PvPSource:BattlegroundPlayerScore(battleground, name, key)
		or root.PvPSource:PlayerScore(name, key))
	local cls = rec and rec.class or score and score.class
	local wins, losses, lastDuel, avg, longest, unknownDuels, duelFaction
	if duel then
		wins, losses, lastDuel, avg, longest, unknownDuels, duelFaction = duelRecord(name)
		cls = cls or lastDuel and lastDuel.class
	end
	local profile = battleground and score and score.profile or rec and (rec.race or rec.raceName) and rec or lastDuel or rec
	cls = cls or profile and profile.class
	local faction = profile and profile.faction or rec and rec.faction or duelFaction
	f.title:SetText(name)
	f.title:SetTextColor(X.rgb(cls))
	local what = {}
	local level = profile and profile.level or rec and rec.level or lastDuel and lastDuel.level
	if level and level > 0 then what[#what + 1] = T.L("Level %d"):format(level) end
	if profile and (profile.race or profile.raceName) then what[#what + 1] = X.raceText(profile) end
	if cls then what[#what + 1] = root.ClassName(cls) end
	if rec and rec.guild then what[#what + 1] = "<" .. rec.guild .. ">" end
	f.profileText = table.concat(what, " · ")
	f.subtitle:SetText(f.profileText)
	local crest = Sintezza_Theme:GetFactionCrest(faction)
	f.factionCrest.icon:SetTexture(crest)
	f.factionCrest:SetShown(crest ~= nil)
	plain[#plain + 1] = name
	plain[#plain + 1] = f.profileText

	if duel then
		f.sections[1].title:SetText(T.L("Duels"))
		f.sections[2].title:SetText(T.L("Statistics"))
		f.scoreLeft:SetText(T.L("Card duel wins"):format(wins))
		f.scoreRight:SetText(T.L("Card duel losses"):format(losses))
		local decided = wins + losses
		row("last duel", lastDuel and string.format("%s, %s", lastDuel.ts and X.ago(lastDuel.ts) or "-",
			T.L(lastDuel.won == true and "you won" or lastDuel.won == false and "you lost" or "result not read")))
		row("fought in", lastDuel and lastDuel.zone)
		row("win rate", decided > 0 and T.L("%.0f%% of %d"):format(wins / decided * 100, decided) or nil)
		row("Average duration", secs(avg), 2)
		row("Longest duel", secs(longest), 2)
		row("Unknown results", unknownDuels, 2, "Unknown duel results help")
		if sighting then row("Last sighting on map", X.coords(rec.lastX, rec.lastY), 2, "Sighting position help", sighting) end
	elseif battleground then
		f.sections[1].title:SetText(T.L("Match"))
		f.sections[2].title:SetText(T.L("Between you"))
		f.scoreLeft:SetText(T.L("Card deaths"):format(score.deaths))
		f.scoreRight:SetText(T.L("Card kills"):format(score.kills))
		row("Battleground", battleground.name)
		row("Match state", T.L(battleground.completed and "Match complete" or battleground.closed and "Left match" or "Current match"))
		row("last fought", score.last > 0 and X.ago(score.last) or nil)
		row("Recorded fights", score.fights, 2, "Battleground card help")
		row("hit you in", score.recapCount > 0 and T.L("%d of your deaths, %d damage"):format(score.recapCount, score.damage) or nil,
			2, "Battleground recap help")
		row("Match started", battleground.time and X.ago(battleground.time), 2)
	else
		f.sections[1].title:SetText(T.L("Where"))
		f.sections[2].title:SetText(T.L("Between you"))
		f.scoreLeft:SetText(T.L("Card deaths"):format(score and score.deaths or 0))
		f.scoreRight:SetText(T.L("Card kills"):format(score and score.kills or 0))
		local zoneHits, inRecap, topDamage, damage = {}, 0, 0, 0
		for _, death in ipairs(db.deaths) do
			local killer = root.PvPSource and root.PvPSource:RecapKiller(death) or death.killer
			if killer and ((key and killer.guid == key) or (not killer.guid and killer.name == name)) and death.zone then
				zoneHits[death.zone] = (zoneHits[death.zone] or 0) + 1
			end
			local dealt
			for index, attacker in ipairs(death.attackers or {}) do
				local namedKiller = key and killer and killer.guid == key and attacker.name == killer.name
				if (key and attacker.guid == key) or (not attacker.guid and (attacker.name == name or namedKiller)) then
					dealt = (dealt or 0) + (attacker.damage or 0)
					if index == 1 then topDamage = topDamage + 1 end
				end
			end
			if dealt then inRecap, damage = inRecap + 1, damage + dealt end
		end
		local nem = key and db.nemesis[key]
		local lastFight = score and score.last and score.last > 0 and score.last
		local sub = rec and rec.lastSubZone ~= "" and rec.lastSubZone ~= rec.lastZone and rec.lastSubZone
		row("last seen", rec and string.format("%s, %s", X.ago(rec.lastSeen), tostring(rec.lastZone or "?")))
		row("exactly", rec and rec.lastX and ((sub and sub .. "  " or "") .. X.coords(rec.lastX, rec.lastY)), nil, "Sighting position help", sighting)
		row("last fought", lastFight and (nem and nem.lastEncounter == lastFight and nem.lastZone
			and string.format("%s, %s", X.ago(lastFight), nem.lastZone) or X.ago(lastFight)), 2)
		row("times seen", rec and T.L("%d, first %s"):format(rec.count or 1, X.ago(rec.firstSeen)), 1, "Encounter count help")
		local peak, peakN = nil, 0
		for hour, count in pairs(rec and rec.hours or {}) do
			if count > peakN or (count == peakN and (not peak or hour < peak)) then peak, peakN = hour, count end
		end
		row("Most sightings at", peak and peakN > 1 and string.format("%02d:00–%02d:59", peak, peak) or nil, 1, "Sighting hours help")
		row("Source", rec and T.L(rec.lastSource), 1, "Sighting source help")
		local topZone, topN = nil, 0
		for zone, count in pairs(zoneHits) do if count > topN then topZone, topN = zone, count end end
		row("kills you most in", topZone and string.format("%s (%d)", topZone, topN), 2)
		row("hit you in", inRecap > 0 and T.L("%d of your deaths, %d damage"):format(inRecap, damage) or nil, 2, "Recap damage help")
		row("most damage", inRecap > 0 and T.L("in %d of them"):format(topDamage) or nil, 2, "Most damage help")
		local known = ns.Deaths and ns.Deaths.KnownFor and ns.Deaths:KnownFor(name)
		local explanations = {}
		if known then
			for index, pattern in ipairs(known) do
				known[index] = ns.Deaths:PatternLabel(name, pattern)
				explanations[#explanations + 1] = known[index] .. ": " .. ns.Deaths:PatternHelp(pattern)
			end
		end
		row("Fight patterns", known and table.concat(known, ", "), 2, "Fight patterns help")
		if #explanations > 0 then
			f.rows[used].helpText = T.L("Fight patterns help") .. "\n\n" .. table.concat(explanations, "\n\n")
		end
	end
	for index = used + 1, #f.rows do f.rows[index]:Hide() end
	for _, section in ipairs(f.sections) do section:LayoutTitleRule() end
	f.body:SetHeight(math.max(ys[1], ys[2]))
	local watched, ignored = key and X.isWatched(key), key and db.ignore[key]
	f.badge:SetText(ignored and T.L("IGNORED") or watched and T.L("WATCHED") or "")
	f.subject = { name = name, key = key, class = cls, duel = duel, sighting = sighting, context = context }
	local scoreText = (f.scoreLeft:GetText() .. "  " .. f.scoreRight:GetText()):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	table.insert(plain, 3, scoreText)
	f.plain = table.concat(plain, "\n")
	f.watchBtn.text:SetText(T.L(watched and "Unwatch" or "Watch"))
	f.ignoreBtn.text:SetText(T.L(ignored and "Stop ignoring" or "Ignore"))
	f.watchBtn:SetEnabled(key and true or false)
	f.ignoreBtn:SetEnabled(key and true or false)
	layoutCard(f)
	f:Show()
	f:Raise()
end
