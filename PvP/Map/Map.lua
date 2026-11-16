-- Sintezza Rivals / Map.lua: world map pins for encounters and fight outcomes.
--
-- Blizzard pins use the native provider. OpenMap's stitched view needs canvas
-- frames because a valid point can lie outside its current host map.
local ADDON, root = ...
local ns = root.PvP

local M = {}
ns.Map = M
ns.modules.Map = M

local Text = root.Text
local now = _G.GetServerTime or time
local MAX_SIGHTING_PINS = 60
local TEMPLATE = "Sintezza_RivalsPvPPinTemplate"

local rgb = ns.ClassRGB
local ago = ns.Ago
local L = ns.L

-- for timers and hooks: Guard with arguments would build a closure per call
local function update() M:Update() end

local function stitchedAPI()
	local api = _G.OpenMapAPI
	if api and api.major == 1 and type(api.WorldFromMap) == "function"
		and type(api.MapFromWorld) == "function" and root.Read(api.IsStitched) then return api end
end

----------------------------------------------------------------- the look of a pin
local MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local swords = Sintezza_Theme.icons.Sintezza_Rivals
local diamond = Sintezza_Theme.icons.RivalsMarker

M.LOOK = {
	sighting = { ring = { 0, 0, 0 }, size = 11 },
	watched  = { fill = { .18, .13, .07 }, ring = { .88, .69, .33 }, size = 17,
		glyph = diamond, tint = { 1, .88, .59 }, inset = 3 },
	trail    = { ring = { 0, 0, 0 }, size = 8, alpha = 0.45 },
	death    = { fill = { .29, .065, .045 }, ring = { .89, .35, .28 }, size = 22,
		glyph = swords, tint = { 1, .56, .49 }, desaturate = true },
	kill     = { fill = { .055, .22, .12 }, ring = { .38, .73, .49 }, size = 22,
		glyph = swords, tint = { .56, 1, .70 }, desaturate = true },
}

-- a circular mask texture over a flat one; SetMask with a path does nothing
-- on this client, so the mask is a texture of its own
local function round(p, tex)
	if not p.CreateMaskTexture then return end
	local m = p:CreateMaskTexture()
	m:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	m:SetAllPoints(tex)
	tex:AddMaskTexture(m)
end

function M.Dress(p)
	if p.tex then return end
	p.border = p:CreateTexture(nil, "ARTWORK")
	p.border:SetAllPoints()
	p.border:SetTexture("Interface\\Buttons\\WHITE8X8")
	round(p, p.border)
	p.tex = p:CreateTexture(nil, "OVERLAY")
	p.tex:SetPoint("TOPLEFT", 2, -2)
	p.tex:SetPoint("BOTTOMRIGHT", -2, 2)
	p.tex:SetTexture("Interface\\Buttons\\WHITE8X8")
	round(p, p.tex)
	p.glyph = p:CreateTexture(nil, "OVERLAY", nil, 1)
	p.glyph:Hide()
end

-- kind is a key of LOOK; class colours the fill of the kinds that have none
function M.Paint(p, kind, class)
	M.Dress(p)
	local look = M.LOOK[kind]
	p.border:Show()
	p.tex:Show()
	p.border:SetVertexColor(look.ring[1], look.ring[2], look.ring[3], 1)
	if look.fill then
		p.tex:SetVertexColor(look.fill[1], look.fill[2], look.fill[3], look.fillAlpha or 1)
	else
		p.tex:SetVertexColor(rgb(class))
	end
	local g = look.glyph
	if g then
		local inset = look.inset or 2
		p.glyph:ClearAllPoints()
		p.glyph:SetPoint("TOPLEFT", inset, -inset)
		p.glyph:SetPoint("BOTTOMRIGHT", -inset, inset)
		p.glyph:SetTexture(g)
		if p.glyph.SetDesaturated then p.glyph:SetDesaturated(look.desaturate == true) end
		p.glyph:SetVertexColor(unpack(look.tint))
		p.glyph:Show()
	else
		p.glyph:Hide()
	end
	p:SetSize(look.size, look.size)
	p:SetAlpha(look.alpha or 1)
end

local function style(p, w)
	p.kind, p.rec, p.watched, p.fights = w.kind, w.rec, w.watched, w.rec == nil and w.fights or nil
	local kind = w.kind
	if kind == "sighting" and w.watched then kind = "watched" end
	if kind == "mixed" then
		M.Dress(p)
		p.border:Hide()
		p.tex:Hide()
		p.glyph:Hide()
		p:SetSize(42, 22)
		p:SetAlpha(1)
		if not p.killBadge then
			p.killBadge = CreateFrame("Frame", nil, p)
			p.deathBadge = CreateFrame("Frame", nil, p)
			p.killBadge:SetPoint("LEFT")
			p.deathBadge:SetPoint("RIGHT")
			M.Paint(p.killBadge, "kill")
			M.Paint(p.deathBadge, "death")
		end
	else
		M.Paint(p, kind, w.rec and w.rec.class)
	end
	if p.killBadge then
		p.killBadge:SetShown(kind == "mixed")
		p.deathBadge:SetShown(kind == "mixed")
	end
	if p.SetMouseClickEnabled then p:SetMouseClickEnabled(false) end
end

local function fightTooltip(fights)
	local kills, deaths = 0, 0
	for _, fight in ipairs(fights) do
		if fight.win then kills = kills + 1 else deaths = deaths + 1 end
	end
	if kills > 0 then GameTooltip:AddLine(root.Text("Добивания: %d", "Kills: %d"):format(kills), .56, 1, .70) end
	if deaths > 0 then GameTooltip:AddLine(root.Text("Смерти: %d", "Deaths: %d"):format(deaths), 1, .56, .49) end
	for i = 1, math.min(8, #fights) do
		local fight = fights[i]
		local name = fight.who and (fight.who.name or fight.who.guid) or L("unknown")
		local label = fight.win and root.Text("Ты убил: %s", "You killed: %s")
			or root.Text("Тебя убили: %s", "Killed by: %s")
		GameTooltip:AddDoubleLine(label:format(name), ago(fight.time), .92, .92, .92, .76, .76, .76)
	end
	if #fights > 8 then GameTooltip:AddLine(root.Text("Еще записей: %d", "More records: %d"):format(#fights - 8)) end
end

-- built on hover, never on update, so a refresh formats nothing per pin
local function tooltip(self)
	local rec, kind = self.rec, self.kind
	if not rec and not self.fights then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	if self.fights then
		fightTooltip(self.fights)
	elseif kind == "sighting" or kind == "trail" then
		GameTooltip:AddLine((rec.name or "?") .. (self.watched and ("  |cffffd100[" .. L("WATCHED") .. "]|r") or ""), 1, 0.82, 0)
		local class = root.ClassName(rec.class)
		GameTooltip:AddLine(L("%s %s, level %s"):format(tostring(rec.raceName or rec.race or ""),
			tostring(class or ""), tostring(rec.level or "?")), 0.9, 0.9, 0.9)
		GameTooltip:AddLine(L("%s, %s ago, seen %dx"):format(rec.lastSubZone or rec.lastZone or "?",
			ago(rec.lastSeen), rec.count or 1), 0.9, 0.9, 0.9)
		if kind == "trail" then GameTooltip:AddLine(L("an earlier spot on their route"), 0.7, 0.7, 0.7) end
	end
	GameTooltip:Show()
end

----------------------------------------------------------------- where a record lands
-- A record carries the map it was taken on and a position inside that map; when
-- the open map is a different one (the continent, a parent zone) the world
-- position is converted for it, which is what the client's own pins do. Results
-- are kept per record in a weak table so the conversion runs once per map
-- change, not once per tick.
local posCache = setmetatable({}, { __mode = "k" })

-- Where a zone map sits on another map, as a rectangle in that map's 0..1
-- space. This is how the client places its own zone pins on a continent: no
-- world coordinates involved, so it cannot drift into the sea when the world
-- position and the map disagree (WoW Forever uses instance ids of its own, and
-- converting through them put pins in the ocean). Cached per pair of maps.
local rectCache = {}

local function rectOn(child, parent, depth)
	local key = child * 100000 + parent
	local r = rectCache[key]
	if r == nil then
		rectCache[key] = false
		if C_Map and C_Map.GetMapRectOnMap then
			local ok, minX, maxX, minY, maxY = pcall(C_Map.GetMapRectOnMap, child, parent)
			if ok and minX and maxX and minY and maxY and maxX > minX and maxY > minY then
				r = { minX, maxX, minY, maxY }
			elseif depth < 8 and C_Map.GetMapInfo then
				local info = root.Read(C_Map.GetMapInfo, child)
				local middle = info and info.parentMapID
				if middle and middle > 0 and middle ~= child and middle ~= parent then
					local a, b = rectOn(child, middle, depth + 1), rectOn(middle, parent, depth + 1)
					if a and b then
						local width, height = b[2] - b[1], b[4] - b[3]
						r = { b[1] + a[1] * width, b[1] + a[2] * width, b[3] + a[3] * height, b[3] + a[4] * height }
					end
				end
			end
		end
		rectCache[key] = r or false
	end
	return r or nil
end

-- A record's position on the map that is open: as stored when it is that map,
-- placed through the map rectangle when the open map contains it, and nowhere
-- otherwise. A record is never drawn on a map that does not contain the one it
-- was taken on.
local function onShownMap(rec, shownMap, api)
	if not rec then return end
	local m, x, y = rec.lastMapID or rec.mapID, rec.lastX or rec.x, rec.lastY or rec.y
	if not (type(m) == "number" and type(x) == "number" and type(y) == "number"
		and x >= 0 and x <= 1 and y >= 0 and y <= 1) then return end
	if m == shownMap and not api then return x, y end
	local c = posCache[rec]
	if c and c.map == shownMap and c.from == m and c.sx == x and c.sy == y and c.api == api then
		return c.x, c.y, c.u, c.v
	end
	local px, py, u, v
	if api then
		u, v = root.Read(api.WorldFromMap, m, x, y)
		if type(u) == "number" and type(v) == "number" then
			-- The stitched canvas can extend beyond the host zone on any side.
			px, py = root.Read(api.MapFromWorld, shownMap, u, v)
		end
	else
		local r = rectOn(m, shownMap, 0)
		if r then
			px, py = r[1] + x * (r[2] - r[1]), r[3] + y * (r[4] - r[3])
			if px < 0 or px > 1 or py < 0 or py > 1 then px, py = nil, nil end
		end
	end
	if not (type(px) == "number" and type(py) == "number" and math.abs(px) < math.huge and math.abs(py) < math.huge) then
		px, py = nil, nil
	end
	posCache[rec] = { map = shownMap, from = m, sx = x, sy = y, x = px, y = py, u = u, v = v, api = api }
	return px, py, u, v
end

----------------------------------------------------------------- what to draw
-- One reusable list of entries; both drawing paths read it. An entry is a table
-- that lives for the session and is overwritten, never rebuilt.
local wants, wantN = {}, 0

local function want(kind, rec, x, y, watched)
	wantN = wantN + 1
	local w = wants[wantN]
	if not w then
		w = {}
		wants[wantN] = w
	end
	w.kind, w.rec, w.x, w.y, w.watched = kind, rec, x, y, watched
	return w
end

local fightPins = {}
local function newer(a, b) return a.time > b.time end
local function collectFights(db, cfg, shownMap, api)
	local source = root.PvPSource
	if not source or not (cfg.deaths or cfg.kills) then return end
	wipe(fightPins)
	for _, fight in ipairs(source:WorldOutcomes(db)) do
		if (fight.win and cfg.kills) or (not fight.win and cfg.deaths) then
			local x, y, u, v = onShownMap(fight.location, shownMap, api)
			if not x and fight.verified then x, y, u, v = onShownMap(fight.verified.location, shownMap, api) end
			if x then
				local key = ("%d:%d"):format(math.floor((u or x) * 100000 + .5), math.floor((v or y) * 100000 + .5))
				local kind = fight.win and "kill" or "death"
				local pin = fightPins[key]
				if not pin then
					pin = want(kind, nil, x, y)
					pin.fights = pin.fights or {}
					wipe(pin.fights)
					fightPins[key] = pin
				elseif pin.kind ~= kind then
					pin.kind = "mixed"
				end
				table.insert(pin.fights, fight)
			end
		end
	end
	for _, pin in pairs(fightPins) do table.sort(pin.fights, newer) end
end

local function collect(shownMap, api)
	wantN = 0
	local db = Sintezza_RivalsPvPDB
	local cfg = db.settings.map
	if not shownMap then return 0 end

	if not ns:Module("map") then return wantN end
	if cfg.sightings then
		local cutoff = now() - (cfg.minutes or 180) * 60
		for k, rec in pairs(db.sightings) do
			if wantN >= MAX_SIGHTING_PINS then break end
			if rec.lastX and (rec.lastSeen or 0) >= cutoff then
				local x, y = onShownMap(rec, shownMap, api)
				if x then
					local watched = ns.Watchlist and ns.Watchlist:IsWatched(k)
					want("sighting", rec, x, y, watched)
					if watched and rec.trail then
						for t = 1, #rec.trail - 1 do
							if wantN >= MAX_SIGHTING_PINS then break end
							local spot = rec.trail[t]
							local tx, ty = onShownMap(spot, shownMap, api)
							if tx then want("trail", rec, tx, ty) end
						end
					end
				end
			end
		end
	end
	if cfg.enabled then collectFights(db, cfg, shownMap, api) end
	return wantN
end

----------------------------------------------------------------- the pin pipeline
-- The mixin is a global because the XML template names it; the data provider
-- is registered once, when the map frame is there to take it.
local provider

Sintezza_RivalsPvPPinMixin = CreateFromMixins and CreateFromMixins(MapCanvasPinMixin or {}) or {}

function Sintezza_RivalsPvPPinMixin:OnLoad()
	if self.SetScalingLimits then self:SetScalingLimits(1, 1.0, 1.2) end
	if self.UseFrameLevelType then self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI") end
	M.Dress(self)
end

function Sintezza_RivalsPvPPinMixin:OnAcquired(w)
	style(self, w)
	self:SetPosition(w.x, w.y)
end

function Sintezza_RivalsPvPPinMixin:OnMouseEnter() tooltip(self) end
function Sintezza_RivalsPvPPinMixin:OnMouseLeave() GameTooltip:Hide() end
function Sintezza_RivalsPvPPinMixin:ShouldMouseButtonBePassthrough()
	return true
end

local function addProvider()
	if provider then return true end
	if not (WorldMapFrame and WorldMapFrame.AddDataProvider and CreateFromMixins
		and MapCanvasDataProviderMixin and MapCanvasPinMixin) then return false end
	provider = CreateFromMixins(MapCanvasDataProviderMixin)
	function provider:RemoveAllData()
		self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
	end
	function provider:RefreshAllData()
		local map = self:GetMap()
		map:RemoveAllPinsByTemplate(TEMPLATE)
		if stitchedAPI() then return end
		local n = collect(map:GetMapID())
		for i = 1, n do map:AcquirePin(TEMPLATE, wants[i]) end
		M.lastCount = n
	end
	local ok, err = pcall(WorldMapFrame.AddDataProvider, WorldMapFrame, provider)
	if not ok then
		provider = nil
		ns:Log("warn", "map data provider refused: %s", tostring(err))
		return false
	end
	ns:Log("info", "map pins through the data provider")
	return true
end

----------------------------------------------------------------- fallback: frames on the canvas
local pins, canvas, layer = {}, nil, nil
local button, partyButton, watchedAPI, queued

local function getPin(i)
	if pins[i] then return pins[i] end
	local anchor = CreateFrame("Frame", nil, layer)
	anchor:SetSize(1, 1)
	local p = CreateFrame("Frame", nil, anchor)
	p:SetPoint("CENTER")
	p.anchor = anchor
	M.Dress(p)
	p:EnableMouse(true)
	p:SetScript("OnEnter", tooltip)
	p:SetScript("OnLeave", function() GameTooltip:Hide() end)
	if p.SetMouseClickEnabled then p:SetMouseClickEnabled(false) end
	pins[i] = p
	return p
end

local function placeAll(shownMap, api)
	local level = canvas:GetFrameLevel() + 120
	if api then level = math.max(level, (root.Read(api.ArtTopLevel) or 0) + 4) end
	if not layer then
		if api and InCombatLockdown() then return end
		layer = CreateFrame("Frame", nil, canvas)
		layer:SetAllPoints(canvas)
	end
	if layer:GetFrameLevel() ~= level and (not api or not InCombatLockdown()) then layer:SetFrameLevel(level) end
	if api and layer:GetFrameLevel() < level then layer:Hide(); return end
	layer:Show()
	local n = collect(shownMap, api)
	local w, h = canvas:GetWidth(), canvas:GetHeight()
	local scale = api and WorldMapFrame:GetEffectiveScale() / math.max(.01, canvas:GetEffectiveScale()) or 1
	for i = 1, n do
		local p, e = getPin(i), wants[i]
		style(p, e)
		p.anchor:SetPoint("CENTER", canvas, "TOPLEFT", e.x * w, -e.y * h)
		p:SetScale(scale)
		p:Show()
	end
	for j = n + 1, #pins do pins[j]:Hide() end
	M.lastCount = n
end

local function queueUpdate()
	if queued then return end
	queued = true
	C_Timer.After(0, function()
		queued = nil
		ns:Guard(update)
	end)
end

local function watchOpenMap()
	local api = _G.OpenMapAPI
	if api == watchedAPI or not (api and api.major == 1 and type(api.RegisterCallback) == "function") then return end
	if watchedAPI and watchedAPI.UnregisterAllCallbacks then watchedAPI.UnregisterAllCallbacks(M) end
	watchedAPI = api
	api.RegisterCallback(M, "OpenMap_StitchedChanged", queueUpdate)
	api.RegisterCallback(M, "OpenMap_ViewChanged", function()
		if canvas and (M.drawnMap ~= WorldMapFrame:GetMapID() or M.drawnScale ~= canvas:GetEffectiveScale()) then
			queueUpdate()
		end
	end)
end

function M:SetFightPinsShown(shown)
	Sintezza_RivalsPvPDB.settings.map.enabled = shown
	self:Update()
end

local function fightButtonTooltip(owner)
	GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine(Sintezza_RivalsPvPDB.settings.map.enabled and Text("Скрыть точки PvP", "Hide PvP markers")
		or Text("Показать точки PvP", "Show PvP markers"))
	GameTooltip:Show()
end

local function attachButton(map)
	if InCombatLockdown() then return end
	if not button then
		button = root.Theme:CreateMapIconButton(map, swords, function(owner)
			M:SetFightPinsShown(not Sintezza_RivalsPvPDB.settings.map.enabled)
			if GameTooltip:IsOwned(owner) then fightButtonTooltip(owner) end
		end)
		button:HookScript("OnEnter", fightButtonTooltip)
		button:HookScript("OnLeave", function(owner)
			if GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
		end)
		map:HookScript("OnShow", queueUpdate)
	end

	local sui = _G.Sintezza_UI
	local party = sui and root.Read(sui.GetModule, sui, "partyMap")
	local anchor = party and root.Read(party.RegisterMapCompanion, party, button)
	if anchor and partyButton ~= anchor then
		partyButton = anchor
		anchor:HookScript("OnShow", queueUpdate)
		anchor:HookScript("OnHide", queueUpdate)
	end
	local attached = anchor and anchor:IsShown()
	local viewport = map.ScrollContainer or map
	local relative = attached and anchor or viewport
	if button.relative ~= relative or button.attached ~= attached then
		button:ClearAllPoints()
		if attached then button:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
		else button:SetPoint("RIGHT", viewport, "RIGHT", -8, 0) end
		button.relative, button.attached = relative, attached
	end
	local level = attached and anchor:GetFrameLevel() or math.min(viewport:GetFrameLevel() + 9600, 9999)
	if button:GetFrameLevel() ~= level then button:SetFrameLevel(level) end
end

----------------------------------------------------------------- update
function M:TryInit()
	if not WorldMapFrame then return false end
	attachButton(WorldMapFrame)
	watchOpenMap()
	if canvas then return true end
	if not provider then addProvider() end
	local ok, c = pcall(function()
		if WorldMapFrame.GetCanvas then return WorldMapFrame:GetCanvas() end
		return WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
	end)
	if ok and c then
		canvas = c
		canvas:HookScript("OnSizeChanged", queueUpdate)
	end
	return provider or canvas
end

function M:Update()
	if not WorldMapFrame or not WorldMapFrame:IsShown() then return end
	self:TryInit()
	local enabled = Sintezza_RivalsPvPDB.settings.map.enabled
	if button then
		root.Theme:PaintButton(button, enabled)
	end
	local api = stitchedAPI()
	local shownMap = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID() or WorldMapFrame.mapID
	if api or not provider then
		if provider and not self.stitched then provider:RemoveAllData() end
		if canvas then placeAll(shownMap, api) end
	elseif provider then
		if layer then layer:Hide() end
		provider:RefreshAllData()
	end
	self.stitched = api ~= nil
	self.drawnMap = shownMap
	self.drawnScale = canvas and canvas:GetEffectiveScale()
end

function M:ShowSpot(mapID, x, y, label)
	if not (mapID and x and y) then return ns:Print("no coordinates for that one") end

	if self.waypoint and TomTom and TomTom.RemoveWaypoint then
		pcall(TomTom.RemoveWaypoint, TomTom, self.waypoint)
	end
	self.waypoint = nil
	if TomTom and TomTom.AddWaypoint and Sintezza_RivalsPvPDB.settings.map.useTomTom then
		local ok, waypoint = pcall(TomTom.AddWaypoint, TomTom, mapID, x, y,
			{ title = "Sintezza Rivals: " .. (label or L("Marked spot")), persistent = false })
		if ok then self.waypoint = waypoint end
	end

	-- OpenWorldMap(mapID) opens the map on that zone in one call
	if OpenWorldMap then
		pcall(OpenWorldMap, mapID)
	elseif WorldMapFrame then
		if not WorldMapFrame:IsShown() then
			if ToggleWorldMap then pcall(ToggleWorldMap) else pcall(WorldMapFrame.Show, WorldMapFrame) end
		end
		if WorldMapFrame.SetMapID then pcall(WorldMapFrame.SetMapID, WorldMapFrame, mapID) end
	end
	if WorldMapFrame and WorldMapFrame.SetMapID and WorldMapFrame.GetMapID
		and WorldMapFrame:GetMapID() ~= mapID then
		pcall(WorldMapFrame.SetMapID, WorldMapFrame, mapID)
	end
	M:Update()
	C_Timer.After(0.2, function() ns:Guard(update) end)
end

-- /rivals map debug: what the map code sees, including where the spot would land
function M:Debug()
	M:TryInit()
	local db = Sintezza_RivalsPvPDB
	local shown = WorldMapFrame and WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
	local function mapName(id)
		local info = id and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(id)
		return info and string.format("%s (type %s)", tostring(info.name), tostring(info.mapType)) or "?"
	end
	ns:Print("map: path=%s shown=%s map %s = %s pins=%s",
		provider and "data provider" or (canvas and "canvas frames" or "NONE"),
		WorldMapFrame and tostring(WorldMapFrame:IsShown()) or "no frame",
		tostring(shown), mapName(shown), tostring(M.lastCount))
	if canvas then ns:Print("canvas size %.0f x %.0f", canvas:GetWidth(), canvas:GetHeight()) end
	local s, d, k = 0, #db.deaths, #root.WorldKills()
	for _ in pairs(db.sightings) do s = s + 1 end
	ns:Print("data: %d sightings, %d deaths, %d kills | cfg enabled=%s minutes=%d",
		s, d, k, tostring(db.settings.map.enabled), db.settings.map.minutes or 0)
	M:Update()
end

function M:Enable()
	if not M:TryInit() then
		ns:Log("warn", "world map not ready yet, retrying on demand")
	end
	ns:On("ADDON_LOADED", function(_, addon)
		if addon == "Blizzard_WorldMap" or addon == "OpenMap" then queueUpdate() end
	end)
	ns:On("PLAYER_REGEN_ENABLED", queueUpdate)
	-- the provider refreshes itself on map changes; the ticker covers data
	-- that changed while the map stayed open, and the fallback path entirely
	M.ticker = C_Timer.NewTicker(2, function()
		if WorldMapFrame and WorldMapFrame:IsShown() then ns:Guard(update) end
	end)
end
