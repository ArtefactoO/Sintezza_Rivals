-- Sintezza Rivals / UI/Card.lua
--
-- The player card: everything known about one player on one page. Who they
-- are, the score between you, the duel record, where you keep meeting, and
-- who else reports them. A table row holds one line; this holds the rest.
--
-- Laid out rather than printed: a header, three figures across the top, then
-- sections of label and value. The widgets are pooled, so reopening it on a
-- different player creates nothing.

local ADDON, root = ...
local ns = root.PvP

local U, X = ns.UI, ns.UIX
local T, TC = ns.Theme, ns.Theme.C
local rgb, ago = X.rgb, X.ago
local raceText, coords, isWatched = X.raceText, X.coords, X.isWatched

local detailFrame

local function keyForName(name)
	if not name then return nil end
	for k, rec in pairs(Sintezza_RivalsPvPDB.sightings) do
		if rec.name == name then return k, rec end
	end
	return nil
end

local function duelRecord(name)
	local key = ns.Duels.OpponentKey(name)
	local wins, losses, last, total, longest = 0, 0, nil, 0, 0
	local timed, unknown, faction = 0, 0, nil
	for _, d in ipairs(Sintezza_RivalsPvPDB.duels) do
		if key and ns.Duels.OpponentKey(d.opponent) == key then
			if d.won == true then wins = wins + 1
			elseif d.won == false then losses = losses + 1
			else unknown = unknown + 1 end
			faction = faction or d.faction
			if not last or (d.ts or 0) > (last.ts or 0) then last = d end
			if d.seconds and d.seconds > 0 then
				total = total + d.seconds
				timed = timed + 1
				if d.seconds > longest then longest = d.seconds end
			end
		end
	end
	return wins, losses, last, (timed > 0) and math.floor(total / timed) or nil,
		longest, unknown, faction
end

local function secs(n)
	if not n or n <= 0 then return nil end
	if n < 60 then return T.L("%ds"):format(n) end
	return T.L("%dm %02ds"):format(math.floor(n / 60), n % 60)
end

local function showSighting(sighting)
	ns.Map:ShowSpot(sighting.lastMapID, sighting.lastX, sighting.lastY, sighting.name)
end

--------------------------------------------------------------------- widgets
-- wide enough for two columns of sections, so a full card rarely needs to scroll
local CARD_W, CARD_H = 760, 520
local CARD_BODY_W, CARD_COLUMN_GAP = CARD_W - 24, 24
local CARD_ROW_H, CARD_HEAD_H = 19, 26
local CARD_TILE_GAP, CARD_TILE_W = 8, (CARD_BODY_W - 8) / 2

local function buildCard()
	local f = T.Window({
		name = "Sintezza_RivalsPvPDetail", width = CARD_W, height = CARD_H,
		title = "Player",
	})
	f:SetFrameStrata("DIALOG")
	local content = f.content

	local head = CreateFrame("Frame", nil, content)
	head:SetPoint("TOPLEFT", 12, -10)
	head:SetPoint("TOPRIGHT", -12, -10)
	head:SetHeight(80)
	T.Solid(head, "BACKGROUND", TC.raised, 0.55):SetAllPoints()
	T.Border(head, TC.line, 1)
	f.classBar = T.Solid(head, "ARTWORK", TC.accent, 1)
	f.classBar:SetWidth(4)
	f.classBar:SetPoint("TOPLEFT")
	f.classBar:SetPoint("BOTTOMLEFT")

	f.classIcon = head:CreateTexture(nil, "ARTWORK")
	f.classIcon:SetSize(20, 20)
	f.classIcon:SetPoint("TOPLEFT", 16, -12)
	f.classIcon:SetTexture("Interface/WorldStateFrame/ICONS-CLASSES")

	local crest = CreateFrame("Frame", nil, head)
	crest:SetSize(60, 60)
	crest:SetPoint("RIGHT", -12, 0)
	crest.icon = crest:CreateTexture(nil, "ARTWORK")
	crest.icon:SetAllPoints()
	crest:EnableMouse(true)
	crest:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(T.L(self.faction))
		GameTooltip:Show()
	end)
	local function hideCrestTip(self)
		if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
	end
	crest:SetScript("OnLeave", hideCrestTip)
	crest:SetScript("OnHide", hideCrestTip)
	f.factionCrest = crest

	f.nameText = T.Font(head, 18, TC.fg, true)
	f.nameText:SetPoint("TOPLEFT", f.classIcon, "TOPRIGHT", 8, 1)
	f.badge = CreateFrame("Frame", nil, head)
	f.badge:SetSize(92, 22)
	f.badge:SetPoint("TOPRIGHT", crest, "TOPLEFT", -8, -2)
	f.badge.bg = T.Solid(f.badge, "BACKGROUND", TC.accent, 1)
	f.badge.bg:SetAllPoints()
	T.Border(f.badge, TC.line, 1)
	f.badge.text = T.Font(f.badge, 11, TC.fg)
	f.badge.text:SetPoint("CENTER")
	f.badge:Hide()
	f.nameText:SetPoint("RIGHT", f.badge, "LEFT", -10, 0)
	f.nameText:SetWordWrap(false)
	f.whatText = T.Font(head, 12, TC.muted)
	f.whatText:SetPoint("TOPLEFT", f.classIcon, "BOTTOMLEFT", 0, -8)
	f.whatText:SetPoint("RIGHT", crest, "LEFT", -8, 0)
	f.whatText:SetWordWrap(false)
	f.guildText = T.Font(head, 11, TC.accent2)
	f.guildText:SetPoint("TOPLEFT", f.whatText, "BOTTOMLEFT", 0, -6)
	f.guildText:SetPoint("RIGHT", crest, "LEFT", -8, 0)
	f.guildText:SetWordWrap(false)

	f.tiles = {}
	for i = 1, 2 do
		local tile = CreateFrame("Frame", nil, content)
		tile:SetSize(CARD_TILE_W, 52)
		if i == 1 then
			tile:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -8)
		else
			tile:SetPoint("TOPLEFT", f.tiles[1], "TOPRIGHT", CARD_TILE_GAP, 0)
		end
		T.Solid(tile, "BACKGROUND", TC.raised, 0.55):SetAllPoints()
		T.Border(tile, TC.line, 1)
		tile.value = T.Font(tile, 20, TC.fg, true)
		tile.value:SetPoint("TOP", 0, -7)
		tile.value:SetPoint("LEFT")
		tile.value:SetPoint("RIGHT")
		tile.value:SetJustifyH("CENTER")
		tile.label = T.Font(tile, 10, TC.dim)
		tile.label:SetPoint("BOTTOM", 0, 7)
		tile.label:SetPoint("LEFT")
		tile.label:SetPoint("RIGHT")
		tile.label:SetJustifyH("CENTER")
		f.tiles[i] = tile
	end
	-- the rest is rows, pooled: a section heading or a label and a value. The
	-- form has a fixed set of rows, so the card grows to fit and never scrolls.
	local body = CreateFrame("Frame", nil, content)
	body:SetPoint("TOPLEFT", f.tiles[1], "BOTTOMLEFT", 0, -10)
	body:SetWidth(CARD_BODY_W)
	f.body = body
	f.rows = {}

	-- buttons along the bottom
	local watchBtn = T.Button(content, "Watch", 128, function()
		local d = f.subject
		if d and d.key and ns.Watchlist then
		ns.Watchlist:ToggleWatch(d.key, d.name, d.class)
		U:ShowDetail(d.name, d.key, d.duel)
		U:MarkDirty()
		U:Refresh()
		end
	end)
	watchBtn:SetPoint("BOTTOMLEFT", 12, 12)
	f.watchBtn = watchBtn

	local ignoreBtn = T.Button(content, "Ignore", 128, function()
		local d = f.subject
		if not (d and d.key) then return end
		local ig = Sintezza_RivalsPvPDB.ignore
		if ig[d.key] then ig[d.key] = nil else ig[d.key] = true end
		U:ShowDetail(d.name, d.key, d.duel)
		U:MarkDirty()
		U:Refresh()
	end)
	ignoreBtn:SetPoint("LEFT", watchBtn, "RIGHT", 8, 0)
	f.ignoreBtn = ignoreBtn

	local copyBtn = T.Button(content, "Copy", 90, function()
		local d = f.subject
		if d then U:CopyText(d.name or T.L("Player"), f.plain or "") end
	end)
	copyBtn:SetPoint("LEFT", ignoreBtn, "RIGHT", 8, 0)

	local actions = T.Button(content, "…", 34, function(owner)
		local d = f.subject
		local entries = {}
		if d.duel and d.sighting then
			entries[#entries + 1] = { value = "map", label = T.L("Last sighting on map") }
		end
		if d.markerAction then
			entries[#entries + 1] = { value = "marker", label = T.L(d.markerAction) }
		end
		root.Theme:OpenPicker(owner, entries, nil, function(action)
			if f.subject ~= d then return end
			if action == "map" then
				showSighting(d.sighting)
			elseif action == "marker" then
				root.SetMarkerHidden(d.key, not root.db.hiddenMarkers[d.key])
				U:ShowDetail(d.name, d.key, d.duel)
			end
		end)
	end)
	actions:SetPoint("BOTTOMRIGHT", -12, 12)
	T.Tip(actions, "Actions")
	f.actions = actions

	return f
end

--------------------------------------------------------------------- filling

function U:ShowDetail(name, key, duel)
	if not name then return end
	if key == nil then
		if duel then key = ns.Duels:FindSighting(name)
		else key = keyForName(name) end
	end
	local rec = key and Sintezza_RivalsPvPDB.sightings[key]
	local sighting = ns.Map and rec and rec.lastMapID and rec.lastX and rec.lastY and rec or nil
	local db = Sintezza_RivalsPvPDB
	if not detailFrame then detailFrame = buildCard() end
	local f = detailFrame

	local bodyHeight = CARD_HEAD_H + 5 * CARD_ROW_H
	f.body:SetHeight(bodyHeight)
	f:SetHeight(212 + bodyHeight + 46 + 40)

	-- lay the rows out from the top in two columns, reusing whatever is already built
	local ys, col = { 0, 0 }, 1
	local colW = duel and CARD_BODY_W or math.floor((CARD_BODY_W - CARD_COLUMN_GAP) / 2)
	local used, plain = 0, {}
	local function row(label, value, mapSighting)
		used = used + 1
		local r = f.rows[used]
		if not r then
			r = CreateFrame("Frame", nil, f.body)
			r.label = T.Font(r, 12, TC.muted)
			r.label:SetPoint("LEFT", 2, 0)
			r.value = T.Font(r, 12, TC.fg)
			r.value:SetPoint("RIGHT", -2, 0)
			r.value:SetJustifyH("RIGHT")
			r.rule = T.Solid(r, "ARTWORK", TC.line, 1)
			r.rule:SetHeight(1)
			r.rule:SetPoint("BOTTOMLEFT")
			r.rule:SetPoint("BOTTOMRIGHT")
			f.rows[used] = r
		end
		local height = label == nil and CARD_HEAD_H or CARD_ROW_H
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", f.body, "TOPLEFT", (col - 1) * (colW + CARD_COLUMN_GAP), -ys[col])
		r:SetSize(colW, height)
		ys[col] = ys[col] + height
		if label == nil then
			r.label:SetTextColor(TC.accent2[1], TC.accent2[2], TC.accent2[3])
			local heading = string.upper(T.L(value))
			r.label:SetText(heading)
			r.value:SetText("")
			r.rule:Show()
			plain[#plain + 1] = ""
			plain[#plain + 1] = heading
		else
			if value == nil or value == "" then value = "-" end
			local c = TC.muted
			r.label:SetTextColor(c[1], c[2], c[3])
			local caption = T.L(label)
			r.label:SetText(caption)
			r.value:SetText(value)
			r.value:SetTextColor(unpack(mapSighting and TC.accent2 or TC.fg))
			r.rule:Hide()
			plain[#plain + 1] = string.format("%s: %s", caption,
				tostring(value):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
		end
		if mapSighting and not r.mapLink then
			local link = CreateFrame("Button", nil, r)
			link:SetPoint("RIGHT", r.value, "RIGHT", 2, 0)
			link:SetHeight(CARD_ROW_H)
			link:SetScript("OnClick", function(self) showSighting(self.sighting) end)
			T.Tip(link, "Show on map")
			local underline = T.Solid(link, "ARTWORK", TC.accent2, 0.65)
			underline:SetHeight(1)
			underline:SetPoint("BOTTOMLEFT", 2, 2)
			underline:SetPoint("BOTTOMRIGHT", -2, 2)
			r.mapLink = link
		end
		if r.mapLink then
			r.mapLink.sighting = mapSighting
			r.mapLink:SetShown(mapSighting ~= nil)
			if mapSighting then r.mapLink:SetWidth(math.min(r.value:GetStringWidth() + 4, colW)) end
		end
		r:Show()
	end
	local function section(title, column)
		col = column
		row(nil, title)
	end

	--------------------------------------------------- who
	local score = not duel and root.PvPSource and root.PvPSource:PlayerScore(name, key)
	local cls = (rec and rec.class) or (score and score.class)
	local wins, losses, lastDuel, avg, longest, unknownDuels, duelFaction
	if duel then
		wins, losses, lastDuel, avg, longest, unknownDuels, duelFaction = duelRecord(name)
		cls = cls or (lastDuel and lastDuel.class)
	end
	local profile = (rec and (rec.race or rec.raceName)) and rec or lastDuel or rec
	local faction = (rec and rec.faction) or duelFaction
	local r, g, b = rgb(cls)
	f.classBar:SetColorTexture(r, g, b, 1)
	f.nameText:SetText(name)
	f.nameText:SetTextColor(r, g, b)

	-- the class icon out of the sheet, or nothing if the class is unknown
	local tc = cls and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[cls]
	if tc then
		f.classIcon:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
		f.classIcon:Show()
	else
		f.classIcon:Hide()
	end

	-- "Level 60   Orc": the class is already said by the icon and the colour
	local what = {}
	local level = (rec and rec.level) or (lastDuel and lastDuel.level)
	if level and level > 0 then what[#what + 1] = T.L("Level %d"):format(level) end
	if profile then what[#what + 1] = raceText(profile) end
	f.whatText:SetText(table.concat(what, "   "))
	local guild = rec and rec.guild
	f.guildText:SetText(guild and ("<" .. guild .. ">") or "")

	local crest = f.factionCrest
	local theme = Sintezza_Theme
	local texture = theme.GetFactionCrest and theme:GetFactionCrest(faction)
	crest.faction = texture and faction or nil
	crest.icon:SetTexture(texture)
	crest:SetShown(texture ~= nil)

	if duel then
		f.tiles[1]:SetWidth(CARD_BODY_W)
		f.tiles[2]:Hide()
		f.tiles[1].value:SetText(string.format("|cff40ff40%d|r / |cffff4040%d|r", wins, losses))
		f.tiles[1].label:SetText(T.L("duels won / lost"))
		section("Duels", 1)
		local decided = wins + losses
		row("win rate", decided > 0 and T.L("%.0f%% of %d"):format((wins / decided) * 100, decided) or nil)
		row("Unknown results", unknownDuels)
		row("last duel", lastDuel and string.format("%s, %s", lastDuel.ts and ago(lastDuel.ts) or "—",
			T.L(lastDuel.won == true and "you won" or lastDuel.won == false and "you lost" or "result not read")) or nil)
		row("fought in", lastDuel and lastDuel.zone)
		row("length", avg and T.L("%s average, %s longest"):format(secs(avg) or "-", secs(longest) or "-"))
	else
		f.tiles[1]:SetWidth(CARD_TILE_W)
		f.tiles[2]:Show()
		local deaths = score and score.deaths or 0
		local kills = score and score.kills or 0
		f.tiles[1].label:SetText(T.L("times they killed you"))
		f.tiles[2].value:SetText("|cff60ff60" .. kills .. "|r")
		f.tiles[2].label:SetText(T.L("times you killed them"))

		--------------------------------------------------- where
		section("Where", 1)
		row("last seen", rec and string.format("%s, %s", ago(rec.lastSeen), tostring(rec.lastZone or "?")) or nil)
		local sub = rec and rec.lastSubZone ~= "" and rec.lastSubZone ~= rec.lastZone and rec.lastSubZone
		row("exactly", rec and rec.lastX and ((sub and (sub .. "  ") or "") .. coords(rec.lastX, rec.lastY)) or nil, sighting)
		row("times seen", rec and T.L("%d, first %s"):format(rec.count or 1, ago(rec.firstSeen)) or nil)
		local peak, peakN = nil, 0
		for h, n in pairs(rec and rec.hours or {}) do
			if n > peakN then peak, peakN = h, n end
		end
		row("usually around", (peak and peakN > 1) and string.format("%02d:00", peak) or nil)
		row("Source", rec and T.L(rec.lastSource) or nil)

		--------------------------------------------------- between you
		-- the death recap also says who hit you hardest, which need not be
		-- whoever landed the last blow
		local zoneHits, inRecap, topDamage, damage = {}, 0, 0, 0
		for _, d in ipairs(db.deaths) do
			local killer = root.PvPSource and root.PvPSource:RecapKiller(d) or d.killer
			if killer and ((key and killer.guid == key) or (not killer.guid and killer.name == name)) then
				if d.zone then zoneHits[d.zone] = (zoneHits[d.zone] or 0) + 1 end
			end
			local dealt
			for i, a in ipairs(d.attackers or {}) do
				local namedKiller = key and killer and killer.guid == key and a.name == killer.name
				if (key and a.guid == key) or (not a.guid and (a.name == name or namedKiller)) then
					dealt = (dealt or 0) + (a.damage or 0)
					if i == 1 then topDamage = topDamage + 1 end
				end
			end
			if dealt then inRecap, damage = inRecap + 1, damage + dealt end
		end
		f.tiles[1].value:SetText("|cffff6060" .. deaths .. "|r")
		local topZone, topN = nil, 0
		for z, n in pairs(zoneHits) do
			if n > topN then topZone, topN = z, n end
		end
		local nem = key and db.nemesis[key]
		section("Between you", 2)
		local lastFight = score and score.last > 0 and score.last
		row("last fought", lastFight and (nem and nem.lastEncounter == lastFight and nem.lastZone
			and string.format("%s, %s", ago(lastFight), nem.lastZone) or ago(lastFight)) or nil)
		row("kills you most in", topZone and string.format("%s (%d)", topZone, topN) or nil)
		row("hit you in", inRecap > 0 and T.L("%d of your deaths, %d damage"):format(inRecap, damage) or nil)
		row("most damage", inRecap > 0 and T.L("in %d of them"):format(topDamage) or nil)
		local known = ns.Deaths and ns.Deaths.KnownFor and ns.Deaths:KnownFor(name)
		if known then
			for i, description in ipairs(known) do known[i] = T.L(description) end
		end
		row("known for", known and table.concat(known, ", ") or nil)
	end

	-- watched or ignored is a badge in the header, beside the faction
	local watched, ignored = key and isWatched(key), key and db.ignore[key]
	if watched or ignored then
		if watched then
		f.badge.bg:SetColorTexture(0.85, 0.66, 0.1, 0.95)
		f.badge.text:SetText(T.L("WATCHED"))
		f.badge.text:SetTextColor(0.1, 0.08, 0.02)
		else
		f.badge.bg:SetColorTexture(0.35, 0.36, 0.4, 0.95)
		f.badge.text:SetText(T.L("IGNORED"))
		f.badge.text:SetTextColor(1, 1, 1)
		end
		f.badge:Show()
	else
		f.badge:Hide()
	end

	for i = used + 1, #f.rows do f.rows[i]:Hide() end
	local canMark = root.IsPlayerGUID(key)
	local hidden = canMark and root.db.hiddenMarkers[key]
	local kind = canMark and root.PvPSource and root.PvPSource:Kind(key, root.db.players[key])
	local markerAction
	if hidden then markerAction = "Restore nameplate marker"
	elseif kind and root.MarkStyle(kind) ~= "off" then markerAction = "Hide nameplate marker" end
	f.subject = { name = name, key = key, class = cls, duel = duel, sighting = sighting, markerAction = markerAction }
	f.plain = table.concat(plain, "\n")
	f.title:SetText(name)
	f.subtitle:SetText("")
	f.watchBtn.label:SetText(key and isWatched(key) and T.L("Unwatch") or T.L("Watch"))
	f.ignoreBtn.label:SetText(key and db.ignore[key] and T.L("Stop ignoring") or T.L("Ignore"))
	f.watchBtn:SetEnabled(key and true or false)
	f.ignoreBtn:SetEnabled(key and true or false)
	f.actions:SetShown(markerAction ~= nil or (duel and sighting ~= nil) or false)
	f:Show()
	f:Raise()
end
