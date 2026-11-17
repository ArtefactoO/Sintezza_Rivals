-- Sintezza Rivals / HUD.lua
--
-- A thin strip you leave on screen. The window answers "what happened"; this
-- answers "what is happening", which is the only question that matters while
-- you are riding through contested ground:
--
--   how many enemies your side reports in this zone, how many are watched and
--   nearby, and where the newest call for help is.
--
-- It is deliberately small, draggable, click-through to the window, and off
-- unless asked for.

local ADDON, root = ...
local ns = root.PvP

local H = {}
ns.HUD = H
ns.modules.HUD = H

local now = _G.GetServerTime or time
local bar
local widgets = Sintezza_Theme:CreateWidgets(root.Theme)

--------------------------------------------------------------------- helpers
local function nearby()
	local db = Sintezza_RivalsPvPDB
	local map = ns.Sightings and ns.Sightings.PlayerMap and ns.Sightings.PlayerMap()
	if not map then return 0, 0 end
	local cut = now() - 120
	local seen, watched = 0, 0
	for key, rec in pairs(db.sightings) do
		if rec.lastMapID == map and (rec.lastSeen or 0) >= cut and not db.ignore[key] then
			seen = seen + 1
			if ns.Watchlist:IsWatched(key) then watched = watched + 1 end
		end
	end
	return seen, watched
end

--------------------------------------------------------------------- build
local function build()
	local T, TC = ns.Theme, ns.Theme.C
	local store = Sintezza_RivalsPvPDB.settings.hud

	bar = CreateFrame("Button", "Sintezza_RivalsPvPHUD", UIParent)
	bar:SetSize(store.width or 300, 24)
	bar:SetFrameStrata("MEDIUM")
	bar:SetClampedToScreen(true)
	bar:SetMovable(true)
	bar:RegisterForDrag("LeftButton")
	bar:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	T.Solid(bar, "BACKGROUND", TC.bg, 0.8):SetAllPoints()
	T.Border(bar, TC.line, 1)

	bar.live = T.Font(bar, 12, TC.fg)
	bar.live:SetPoint("LEFT", 8, 0)

	bar:SetScript("OnDragStart", function(self)
		if store.locked then return end
		self:StartMoving()
	end)
	bar:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local p, _, _, x, y = self:GetPoint()
		store.point, store.x, store.y = p, x, y
	end)
	bar:SetScript("OnClick", function(_, click)
		if click == "RightButton" then ns.Options:Open() else ns.UI:Toggle() end
	end)
	bar:SetScript("OnEnter", function(self)
		widgets:Tooltip(self, "Sintezza Rivals", (self.tipText or "") .. "\n\n" .. root.Text(
			"ЛКМ — окно, ПКМ — настройки. Перетащи, чтобы переместить панель.",
			"Left-click to open, right-click for settings. Drag to move the bar."), "cursor")
	end)
	bar:SetScript("OnLeave", function(self) Sintezza_Theme:HideTooltip(self) end)
	bar:HookScript("OnHide", function(self) Sintezza_Theme:HideTooltip(self) end)

	bar:SetPoint(store.point or "TOP", UIParent, store.point or "TOP", store.x or 0, store.y or -220)
	if store.scale then bar:SetScale(store.scale) end
end

--------------------------------------------------------------------- update
function H:Update()
	local cfg = Sintezza_RivalsPvPDB.settings.hud
	if not cfg.show then
		if bar then bar:Hide() end
		return
	end
	if not bar then build() end

	local seen, watched = nearby()
	if seen ~= H.seen or watched ~= H.watched then
		H.seen, H.watched = seen, watched
		bar.live:SetText(root.Text("%d врагов поблизости  ·  %d отмечено", "%d enemies nearby  ·  %d watched"):format(seen, watched))
		bar.tipText = root.Text("Встречи в этой зоне за последние две минуты.", "Sightings in this zone over the past two minutes.")
	end

	bar:Show()
end

function H:Toggle()
	local cfg = Sintezza_RivalsPvPDB.settings.hud
	cfg.show = not cfg.show
	H:Update()
	ns:Print("the on-screen strip is %s", ns.L(cfg.show and "on" or "off"))
end

local function update() H:Update() end

function H:Enable()
	-- one second is plenty for a strip that counts people, and it does nothing
	-- at all while it is switched off
	H.ticker = C_Timer.NewTicker(1, function()
		if Sintezza_RivalsPvPDB.settings.hud.show then ns:Guard(update) end
	end)
	H:Update()
end
