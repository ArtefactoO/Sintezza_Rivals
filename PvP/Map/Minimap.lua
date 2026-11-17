-- Sintezza Rivals / Minimap.lua: minimap blips for watched enemies (and optionally deaths)
-- Placement math follows HereBeDragons-Pins-2.0 (shipped with Questie on this
-- client, so the API set is proven): world yards from UnitPosition, divided by
-- C_Minimap.GetViewRadius(), times half the minimap size.
-- UnitPosition returns y, x, z, instanceID: the swapped order is the API.
local ADDON, root = ...
local ns = root.PvP

local MM = {}
ns.MinimapPins = MM
ns.modules.MinimapPins = MM

local now = _G.GetServerTime or time
local Safe = ns.Safe
local MAX_PINS = 30   -- hard cap: blips are frames, and frames are the memory cost
local pins = {}
local widgets = Sintezza_Theme:CreateWidgets(root.Theme)

local function paint(p, kind, class) ns.Map.Paint(p, kind, class) end

local function getPin(i)
	if pins[i] then return pins[i] end
	local p = CreateFrame("Frame", nil, Minimap)
	p:SetFrameStrata("MEDIUM")
	p:SetFrameLevel(Minimap:GetFrameLevel() + 10)
	-- the same pins as the world map, from the same table
	ns.Map.Dress(p)
	p:EnableMouse(true)
	-- built on hover, so the update formats nothing per blip
	p:SetScript("OnEnter", function(self)
		local rec = self.rec
		if not rec then return end
		local title, body
		if self.kind == "sighting" then
			title = (rec.name or "?") .. (self.watched and ("  [" .. ns.L("WATCHED") .. "]") or "")
			body = string.format("%s %s %s", rec.raceName or rec.race or "", root.ClassName(rec.class) or "", rec.level or "") .. "\n" ..
				(self.onEdge and root.Text("За пределами миникарты", "Beyond minimap range") or root.Text("Последняя встреча", "Last seen here"))
		elseif self.kind == "death" then
			title = ns.L("You died here")
			body = ns.L("Killer: %s"):format(rec.killer and rec.killer.name or ns.L("unknown"))
		end
		if title then widgets:Tooltip(self, title, body, "cursor") end
	end)
	p:SetScript("OnLeave", function(self) Sintezza_Theme:HideTooltip(self) end)
	p:HookScript("OnHide", function(self) Sintezza_Theme:HideTooltip(self) end)
	pins[i] = p
	return p
end

-- returns x/y offset in minimap pixels, or nil when the target is off the edge
-- and edge floating is disabled
local function offsetFor(py, px, ty, tx, radius, floatOnEdge)
	local w, h = Minimap:GetWidth() / 2, Minimap:GetHeight() / 2
	local xDist, yDist = px - tx, py - ty
	if GetCVar and GetCVar("rotateMinimap") == "1" then
		local facing = GetPlayerFacing()
		if facing then
			local s, c = math.sin(facing), math.cos(facing)
			xDist, yDist = xDist * c - yDist * s, xDist * s + yDist * c
		end
	end
	local dx, dy = xDist / radius, yDist / radius
	local dist = (dx * dx + dy * dy) / (0.9 * 0.9)
	if dist > 1 then
		if not floatOnEdge then return nil end
		local f = math.sqrt(dist)
		dx, dy = dx / f, dy / f
	end
	return dx * w, -dy * h, dist > 1
end

-- Records without world coordinates are converted once and the result is
-- cached on the record: GetWorldPosFromMapPos allocates a vector per call,
-- and this runs on a ticker.
local function worldOf(rec)
	if rec.worldX and rec.worldY then return rec.worldY, rec.worldX, rec.instanceID end
	if rec.noWorld then return nil end
	if rec.lastMapID and rec.lastX and C_Map and C_Map.GetWorldPosFromMapPos then
		local ok, inst, pos = pcall(C_Map.GetWorldPosFromMapPos, rec.lastMapID,
			{ x = rec.lastX, y = rec.lastY })
		if ok and pos and pos.GetXY then
			local a, b = pos:GetXY()
			rec.worldY, rec.worldX, rec.instanceID = a, b, inst
			return a, b, inst
		end
	end
	rec.noWorld = true
	return nil
end

function MM:Update()
	local cfg = Sintezza_RivalsPvPDB.settings.minimap
	local i = 0
	if cfg.enabled and ns:Module("map") and Minimap and Minimap:IsVisible() then
		local py, px, _, instanceID = UnitPosition("player")
		py, px = Safe(py), Safe(px)
		local radius = (C_Minimap and C_Minimap.GetViewRadius) and C_Minimap.GetViewRadius() or nil
		if py and px and radius and radius > 0 then
			local maxAge = (cfg.minutes or 30) * 60
			local here = ns.Sightings and ns.Sightings.PlayerMap and ns.Sightings.PlayerMap()
			for k, rec in pairs(Sintezza_RivalsPvPDB.sightings) do
				if i >= MAX_PINS then break end
				-- same zone only: a world coordinate from another continent means nothing
				local watched = (not here or rec.lastMapID == here) and ns.Watchlist and ns.Watchlist:IsWatched(k)
				local fresh = rec.lastMapID == here and (now() - (rec.lastSeen or 0)) <= maxAge
				if i < MAX_PINS and fresh and (watched or not cfg.watchedOnly) then
					local ty, tx, inst = worldOf(rec)
					if ty and tx and (not inst or not instanceID or inst == instanceID) then
						local ox, oy, onEdge = offsetFor(py, px, ty, tx, radius, cfg.floatOnEdge and watched)
						if ox then
							i = i + 1
							local p = getPin(i)
							paint(p, watched and "watched" or "sighting", rec.class)
							p.kind, p.rec, p.watched, p.onEdge = "sighting", rec, watched, onEdge
							p:ClearAllPoints()
							p:SetPoint("CENTER", Minimap, "CENTER", ox, oy)
							p:Show()
						end
					end
				end
			end
			if cfg.deaths then
				for _, d in ipairs(Sintezza_RivalsPvPDB.deaths) do
					if i >= MAX_PINS then break end
					if i < MAX_PINS and d.worldX and d.worldY and (now() - (d.ts or 0)) <= maxAge then
						local ox, oy = offsetFor(py, px, d.worldY, d.worldX, radius, false)
						if ox then
							i = i + 1
							local p = getPin(i)
							paint(p, "death")
							p.kind, p.rec, p.watched = "death", d, nil
							p:ClearAllPoints()
							p:SetPoint("CENTER", Minimap, "CENTER", ox, oy)
							p:Show()
						end
					end
				end
			end
		end
	end
	for j = i + 1, #pins do pins[j]:Hide() end
	MM.lastCount = i

end

--------------------------------------------------------------- minimap button
local function update() MM:Update() end

function MM:UpdateButton()
    root.Launcher:RefreshMinimap(root.db.minimap)
end

function MM:Enable()
	-- 0.75s is plenty for "where was he last seen"; blips are not a radar.
	-- Pins are children of the minimap, so a hidden minimap
	-- needs no update at all.
	MM.ticker = C_Timer.NewTicker(0.75, function()
		if Minimap and Minimap:IsVisible() then ns:Guard(update) end
	end)
end
