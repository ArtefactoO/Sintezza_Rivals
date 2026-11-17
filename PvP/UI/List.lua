-- Sintezza Rivals / UI/List.lua
--
-- The virtual list: tabs fill X.data with plain row descriptors and only as
-- many row widgets exist as fit on screen. Rows never move; scrolling repaints
-- them from a different index. Also the shared sort and the row handlers.

local ADDON, root = ...
local ns = root.PvP

local U, X = ns.UI, ns.UIX
local now, rgb, ago = X.now, X.rgb, X.ago
local coords = X.coords
local ROW_H, rows, data = X.ROW_H, X.rows, X.data
local GROUP_ARROW_WIDTH = 16
local widgets = Sintezza_Theme:CreateWidgets(root.Theme)

-- column index and spec under an x offset into the row
function X.colAt(x)
	local acc = 6
	for i, spec in ipairs(X.TABS[X.selected].cols) do
		if x >= acc and x <= acc + spec[2] then return i, spec end
		acc = acc + spec[2] + 6
	end
end

--------------------------------------------------------------------- row widgets
-- One shared handler set for every row: descriptors carry plain fields and a
-- reference to the record, so a refresh builds no closures and no tooltips.
-- A player row has no tooltip: the card a click opens has everything. Hovering
-- only explains a death from the recap (who hit you) and a zone.
local function rowEnter(self)
	self.hl:Show()
	local d = self.desc
	if not d or not d.kind then return end
	local lines = {}
	local rec = d.rec
	if d.kind == "fight" and rec and rec.attackers then
		lines[#lines + 1] = root.Text("Добивающий удар: %s", "Killing blow: %s"):format(rec.killer and rec.killer.name or "—")
		for _, a in ipairs(rec.attackers) do
			local r, g, b = ns.ClassRGB(a.class)
			local damage = a.damage and root.Text("%d урона", "%d damage"):format(a.damage) or ""
			lines[#lines + 1] = string.format("|cff%02x%02x%02x%s|r  %s", math.floor(r * 255 + .5),
				math.floor(g * 255 + .5), math.floor(b * 255 + .5), a.name or a.guid or "—", damage)
		end
	elseif not (d.place and d.place ~= "") then
		Sintezza_Theme:HideTooltip(self)
		return
	end
	if d.place and d.place ~= "" then lines[#lines + 1] = d.place end
	widgets:Tooltip(self, root.Text("Подробности боя", "Fight details"), table.concat(lines, "\n"), "cursor")
end
X.rowEnter = rowEnter

local function rowClick(self, button)
	local d = self.desc
	if not d or not d.kind then return end
	if button == "RightButton" then
		if not d.key then return end
		-- shift turns the alerts off for someone you do not want to hear about,
		-- a duelling partner or a friend on the other side
		if IsShiftKeyDown() then
			local ig = Sintezza_RivalsPvPDB.ignore
			if ig[d.key] then
				ns.Watchlist:SetIgnored(d.key, false)
				ns:Notify("action", "alerts for %s are back on", tostring(d.name))
			else
				ns.Watchlist:SetIgnored(d.key, true)
				ns:Notify("action", "ignoring %s: no more alerts about them", tostring(d.name))
			end
			U:MarkDirty()
			U:Refresh()
			return
		end
		if ns.Watchlist then
			ns.Watchlist:ToggleWatch(d.key, d.name, d.class)
			U:Refresh()
		end
		return
	end
	if d.toggle and d.toggleRow then
		d.toggle()
		U:Refresh()
		return
	end
	local x = GetCursorPosition() / self:GetEffectiveScale() - self:GetLeft()
	local _, spec = X.colAt(x)
	if spec and spec[5] == "fightMap" and d.mapPoint and ns.Map then
		local point = d.mapPoint
		ns.Map:ShowSpot(point.mapID, point.x, point.y, d.name)
		return
	end
	local arrowX = self.groupArrowX
	if d.toggle and arrowX and x >= arrowX and x < arrowX + GROUP_ARROW_WIDTH then
		d.toggle()
		U:Refresh()
		return
	end
	if spec and spec[5] == "copy" and d.rec then
		local rec = d.rec
		-- clicking a coordinate shows it on the map, which is what a coordinate is
		-- for; ctrl-click copies it as text instead
		if IsControlKeyDown() then
			U:CopyText(rec.name or root.Text("Противник", "Enemy"), string.format("%s  %s  %s  %s",
				rec.name or "?", rec.lastZone or "?",
				(rec.lastSubZone and rec.lastSubZone ~= "" and rec.lastSubZone) or "",
				coords(rec.lastX, rec.lastY)))
		elseif ns.Map then
			ns.Map:ShowSpot(rec.lastMapID, rec.lastX, rec.lastY, rec.name)
		end
		return
	end
	-- anywhere else on a row that names a player opens the card
	if d.name then
		local key = d.key
		if not key and d.kind == "rivalsPlayerScore" then key = false end
		U:ShowDetail(d.name, key, d.kind == "duel", d.cardContext)
	end
end

-- one handler for the per-row button, whatever that row's button does
local function rowButtonClick(self)
	local d = self:GetParent().desc
	if not d then return end
	if d.unignore and d.key then
		ns.Watchlist:SetIgnored(d.key, false)
		ns:Notify("action", "alerts for %s are back on", tostring(d.name))
		if ns.Nameplates then ns.Nameplates:RefreshAll() end
		U:MarkDirty()
		U:Refresh()
	end
end

local function rowLeave(self)
	self.hl:Hide()
	Sintezza_Theme:HideTooltip(self)
end

local function buildRow(i)
	local list = X.list
	local r = CreateFrame("Button", nil, list)
	r:SetSize(list:GetWidth() > 0 and list:GetWidth() or (X.W - 180), ROW_H)
	r:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(i - 1) * ROW_H)
	r:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	r.stripe = r:CreateTexture(nil, "BACKGROUND")
	r.stripe:SetAllPoints()
	r.band = root.Theme:RowBand(r)
	r.hl = r:CreateTexture(nil, "BORDER")
	r.hl:SetAllPoints()
	Sintezza_Theme:Tint(r.hl, "SetColorTexture", ns.Theme.C.accent, 0.18)
	r.hl:Hide()
	-- Icons are textures, not inline |T..|t markup: markup is laid out by the
	-- font, so a CJK name (a taller font) would scale the icons with it. The
	-- raid target icons are cut out of the one 4x4 sheet every client has.
	r.mark = r:CreateTexture(nil, "OVERLAY")
	r.mark:SetSize(14, 14)
	r.mark:SetPoint("LEFT", r, "LEFT", 6, 0)
	r.mark:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	r.mark:Hide()
	r.cls = r:CreateTexture(nil, "OVERLAY")
	r.cls:SetSize(16, 16)
	r.cls:SetTexture("Interface\\WorldStateFrame\\ICONS-CLASSES")
	r.cls:Hide()
	r.classBorder = root.Theme:FrameIcon(r, r.cls)
	r.classBorder:Hide()
	r.groupArrow = root.Theme:DisclosureArrow(r, GROUP_ARROW_WIDTH)
	r.groupArrow:Hide()
	r.participantMarker = root.CreateParticipantMarker(r)

	r.cells = {}

	r:SetScript("OnEnter", rowEnter)
	r:SetScript("OnLeave", rowLeave)
	r:SetScript("OnHide", rowLeave)
	r:SetScript("OnClick", rowClick)

	rows[i] = r
	return r
end

local function cellOf(r, i, spec, x, width)
	local fs = r.cells[i]
	if not fs then
		fs = r:CreateFontString(nil, "OVERLAY")
		-- same size for every alphabet, so a Chinese name cannot enlarge the row
		root.InterfaceFonts:ApplyFamily(fs, 10, "", root.db)
		r.cells[i] = fs
	end
	fs:ClearAllPoints()
	fs:SetPoint("LEFT", r, "LEFT", x, 0)
	fs:SetWidth(width or spec[2])
	-- fixed height and a single line: CJK glyphs are taller than Latin ones and
	-- would stretch rows out of alignment
	fs:SetHeight(ROW_H - 4)
	fs:SetJustifyH(spec[3])
	fs:SetJustifyV("MIDDLE")
	fs:SetWordWrap(false)
	if fs.SetMaxLines then fs:SetMaxLines(1) end
	fs:Show()
	return fs
end

-- The relative time is the only cell that changes without the data changing,
-- and it changes slowly. Each bucket maps to exactly one string, so the bucket
-- is compared as a number and the string is only built when it would differ.
local function agoBucket(ts)
	local d = now() - (ts or 0)
	if d < 0 then d = 0 end
	if d < 60 then return d end
	if d < 3600 then return 100 + math.floor(d / 60) end
	if d < 86400 then return 10000 + math.floor(d / 3600) end
	return 1000000 + math.floor(d / 86400)
end

-- paint one physical row from a descriptor
local function paint(r, desc, index, cols)
	if not desc then
		r:Hide()
		return
	end
	r.desc = desc
	local tone = desc.tone and ns.Theme.C[desc.tone]
	local outcome = tone and desc.tone ~= "muted"
	r.stripe:SetShown(outcome and true or false)
	r.band:SetShown(not outcome and index % 2 == 0)
	if outcome then
		r.stripe:SetColorTexture(tone[1], tone[2], tone[3], .10)
	end
	r:SetAlpha(desc.faded and 0.45 or 1)

	-- the marks and the class icon sit in the name column, which is the first
	-- one unless the row says otherwise (the leaderboard has a rank in front)
	local markCol = desc.markCol or 1
	local colX = 6
	for i = 1, markCol - 1 do colX = colX + (cols[i] and cols[i][2] or 0) + 6 end
	local nameX = colX + (markCol == 2 and (desc.indent or 0) or 0)
	if desc.watched then
		r.mark:SetTexCoord(0.75, 1, 0.25, 0.5)
		r.mark:ClearAllPoints()
		r.mark:SetPoint("LEFT", r, "LEFT", nameX, 0)
		r.mark:Show()
		nameX = nameX + 18
	else
		r.mark:Hide()
	end
	local class = desc.class or desc.color
	local coords2 = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
	if coords2 then
		r.cls:ClearAllPoints()
		r.cls:SetPoint("LEFT", r, "LEFT", nameX, 0)
		r.cls:SetTexCoord(coords2[1], coords2[2], coords2[3], coords2[4])
		r.cls:Show()
		r.classBorder:Show()
		nameX = nameX + 20
	else
		r.cls:Hide()
		r.classBorder:Hide()
	end
	local marker
	r.groupArrowX = nil
	if desc.groupExpanded ~= nil then
		r.groupArrow:SetExpanded(desc.groupExpanded)
		marker = r.groupArrow
		r.groupArrowX = nameX
	elseif desc.participant then
		marker = r.participantMarker
	end
	r.groupArrow:SetShown(marker == r.groupArrow)
	r.participantMarker:SetShown(marker == r.participantMarker)
	if marker then
		marker:ClearAllPoints()
		marker:SetPoint("LEFT", r, "LEFT", nameX, 0)
		nameX = nameX + (marker == r.groupArrow and GROUP_ARROW_WIDTH + 1 or 13)
	end

	local agoCol = desc.agoCol
	local x = 6
	for i, spec in ipairs(cols) do
		local start = i == markCol and nameX or x + (i == 2 and (desc.indent or 0) or 0)
		local fs = cellOf(r, i, spec, start, spec[2] - (start - x))
		if i ~= agoCol then fs:SetText(desc.cells[i] or "") end
		if i == markCol and (desc.class or desc.color) then fs:SetTextColor(rgb(desc.class or desc.color))
		elseif i == markCol then fs:SetTextColor(0.95, 0.95, 0.95)
		elseif tone and (i == 1 or desc.indent) then fs:SetTextColor(tone[1], tone[2], tone[3], 1)
		else fs:SetTextColor(0.9, 0.9, 0.9) end
		x = x + spec[2] + 6
	end
	-- The relative time is written here, not at fill time, so the clock ticker
	-- repaints one cell instead of rebuilding every descriptor. Scrolling
	-- repaints every row on every frame of a drag, so the text is only rebuilt
	-- when the bucket or the column differs from what the cell already shows.
	if agoCol and r.cells[agoCol] then
		local bucket = agoBucket(desc.agoTs)
		if bucket ~= r.agoBucket or agoCol ~= r.agoCol then
			r.agoBucket, r.agoCol = bucket, agoCol
			r.cells[agoCol]:SetText(ago(desc.agoTs))
		end
	else
		r.agoBucket, r.agoCol = nil, nil
	end
	for i = #cols + 1, #r.cells do r.cells[i]:Hide() end

	if desc.unignore then
		if not r.button then
			r.button = ns.Theme.Button(r, "Stop ignoring", 100, rowButtonClick)
			r.button:SetSize(100, 20)
			r.button:SetPoint("RIGHT", r, "RIGHT", -8, 0)
		end
		r.button:Show()
	elseif r.button then
		r.button:Hide()
	end
	r:Show()
end

-- The list owns one index. Every row widget that exists is either painted or
-- hidden on every pass, so nothing is left over from a previous tab or size.
local firstIndex = 0

function X.renderVisible()
	local list = X.list
	if not list then return end
	local cols = X.TABS[X.selected].cols
	local numRows = X.numRows
	local maxFirst = math.max(0, #data - numRows)
	if firstIndex > maxFirst then firstIndex = maxFirst end
	if firstIndex < 0 then firstIndex = 0 end

	for i = 1, numRows do
		local r = rows[i] or buildRow(i)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(i - 1) * ROW_H)
		r:SetWidth(list:GetWidth())
		paint(r, data[firstIndex + i], firstIndex + i, cols)
	end
	for i = numRows + 1, #rows do
		rows[i]:Hide()
	end
	if X.scrollBar then X.scrollBar:Update(#data, numRows, firstIndex) end
end

function X.scrollTo(first)
	firstIndex = first or 0
	X.renderVisible()
end

function X.scrollBy(rowsDelta)
	X.scrollTo(firstIndex + rowsDelta)
end

-- the once-a-second clock: only cells whose bucket moved are rewritten
function X.tickClock()
	for i = 1, X.numRows do
		local r = rows[i]
		if r and r:IsShown() then
			local d = r.desc
			if d and d.agoCol and r.cells[d.agoCol] then
				local bucket = agoBucket(d.agoTs)
				if bucket ~= r.agoBucket then
					r.agoBucket = bucket
					r.cells[d.agoCol]:SetText(ago(d.agoTs))
				end
			end
		end
	end
end

--------------------------------------------------------------------- sorting
-- sorts src by the active column through getters[sortKey], falling back to
-- the tab's own order; returns src
function X.sortList(src, getters, fallback)
	local get = X.sortKey and getters[X.sortKey]
	local sortDesc = X.sortDesc
	table.sort(src, function(a, b)
		if get then
			local va, vb = get(a), get(b)
			if va ~= vb then
				if type(va) == "string" or type(vb) == "string" then
					va, vb = tostring(va), tostring(vb)
					if sortDesc then return va > vb end
					return va < vb
				end
				va, vb = va or 0, vb or 0
				if sortDesc then return va > vb end
				return va < vb
			end
		end
		return fallback(a, b)
	end)
	return src
end

function X.add(desc)
	data[#data + 1] = desc
end
