-- Sintezza Rivals / Theme.lua
--
-- The house look: palette, text, primitives, window chrome and the left
-- navigation. The controls built on top of these are in Theme/Widgets.lua.
--
-- The visual language follows the flat dark style used by the Forever UI suites
-- on this client: a 1px black border around a flat panel, a 52px header with
-- icon, title and subtitle, hairline rules instead of heavy frames, a left
-- navigation column rather than a row of tabs, and settings rows that put the
-- name and its explanation on the left with the control on the right.

local ADDON, root = ...
local ns = root.PvP

local Theme = {}
ns.Theme = Theme
local brass = root.Theme

Theme.C = {
	bg = brass.bg, panel = brass.panel, raised = brass.panelHover,
	line = brass.line, fg = brass.text, muted = brass.muted,
	dim = brass.dim, accent = brass.accent, accent2 = brass.accent,
	red = { .94, .43, .36 }, green = { .43, .75, .54 }, gold = brass.brass, black = { 0, 0, 0 },
}

Theme.FOOTER = 22
Theme.PAD = 12
Theme.NAV_W = 150
Theme.ROW_H = 24
Theme.SET_ROW_H = 40

local C = Theme.C
local widgets = Sintezza_Theme:CreateWidgets(root.Theme)

-- Every label the player reads goes through here, so a translation only has to
-- fill ns.LOCALE (see Locales.lua). Untranslated text falls through unchanged.
function Theme.L(text)
	if type(text) ~= "string" then return text end
	return (ns.LOCALE and ns.LOCALE[text]) or text
end
local L = Theme.L

--------------------------------------------------------------------- primitives
function Theme.Solid(parent, layer, color, alpha)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND")
	Sintezza_Theme:Tint(t, "SetColorTexture", color, alpha)
	return t
end

-- a 1px line on one side of a frame
function Theme.Rule(parent, side, color, alpha, inset)
	local t = Theme.Solid(parent, "BORDER", color or C.line, alpha or 1)
	inset = inset or 0
	if side == "TOP" or side == "BOTTOM" then
		t:SetHeight(1)
		t:SetPoint(side .. "LEFT", inset, 0)
		t:SetPoint(side .. "RIGHT", -inset, 0)
	else
		t:SetWidth(1)
		t:SetPoint("TOP" .. side, 0, -inset)
		t:SetPoint("BOTTOM" .. side, 0, inset)
	end
	return t
end

function Theme.Border(frame, color, alpha)
	for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		Theme.Rule(frame, side, color or C.black, alpha or 1)
	end
end

function Theme.Font(parent, size, color, bold)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	root.InterfaceFonts:ApplyFamily(fs, size or 12, bold and "OUTLINE" or "", root.db)
	local c = color or C.fg
	Sintezza_Theme:Tint(fs, "SetTextColor", c)
	fs:SetJustifyH("LEFT")
	return fs
end

-- A plain X: two thin bars turned 45 degrees. A font "x" sits on its baseline
-- and always looks low; the stock pass/decline icons carry a circle and read
-- as "delete". Two rotated bars are centred by construction, take any colour
-- and any size, and look the same on the window, the inputs and the cards.
function Theme.Cross(parent, size, color)
	local f = CreateFrame("Frame", nil, parent)
	size = size or 12
	f:SetSize(size, size)
	color = color or C.muted
	local thick = math.max(1, math.floor(size / 7 + 0.5))
	for i = 1, 2 do
		local bar = f:CreateTexture(nil, "OVERLAY")
		Sintezza_Theme:Tint(bar, "SetColorTexture", color)
		bar:SetSize(size * 1.25, thick)
		bar:SetPoint("CENTER")
		bar:SetRotation(math.rad(i == 1 and 45 or -45))
		f[i] = bar
	end
	function f:SetVertexColor(r, g, b, a)
		self[1]:SetColorTexture(r, g, b, a or 1)
		self[2]:SetColorTexture(r, g, b, a or 1)
	end
	return f
end

-- The triangle out of the raid-target sheet, flipped to point down. The glyph
-- characters for this are not in the game's fonts and come out as a box.
function Theme.Chevron(parent, size, color)
	local t = parent:CreateTexture(nil, "OVERLAY")
	t:SetSize(size or 10, size or 10)
	t:SetTexture("Interface/TargetingFrame/UI-RaidTargetingIcons")
	t:SetTexCoord(0.75, 1, 0.25, 0)
	color = color or C.muted
	Sintezza_Theme:Tint(t, "SetVertexColor", color)
	return t
end

function Theme.Check(parent, size, color)
	local t = parent:CreateTexture(nil, "OVERLAY")
	t:SetSize(size or 14, size or 14)
	t:SetTexture("Interface/Buttons/UI-CheckBox-Check")
	color = color or C.accent2
	Sintezza_Theme:Tint(t, "SetVertexColor", color)
	return t
end

function Theme.Tip(widget, title, text, anchor)
	widget:HookScript("OnEnter", function(self)
		if not title and not text then return end
		GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
		GameTooltip:ClearLines()
		if title then GameTooltip:AddLine(L(title), C.gold[1], C.gold[2], C.gold[3]) end
		if text then GameTooltip:AddLine(L(text), 0.85, 0.85, 0.85, true) end
		GameTooltip:Show()
	end)
	widget:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

--------------------------------------------------------------------- window

-- opts: name, width, height, minW, minH, title, subtitle, icon, key (settings
-- table that stores point/x/y/w/h), resizable
function Theme.Window(opts)
	local f = CreateFrame("Frame", opts.name, UIParent, "BackdropTemplate")
	f:Hide()
	f:SetSize(opts.width, opts.height)
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")

	brass:WindowSurface(f)

	local store = opts.key
	local prefs = opts.windowAppearance
	local function Locked()
		if prefs then return prefs:Get("locked") end
		return store and store.locked
	end
	f:SetScript("OnDragStart", function(self)
		if InCombatLockdown() or Locked() then return end
		self.sintezzaDragging = true
		self:StartMoving()
	end)
	f:SetScript("OnDragStop", function(self)
		if not self.sintezzaDragging then return end
		self.sintezzaDragging = nil
		self:StopMovingOrSizing()
		if not store then return end
		local p, _, _, x, y = self:GetPoint()
		store.point, store.x, store.y = p, x, y
	end)

	local header = widgets:WindowHeader(f, {
		icon = opts.icon or Sintezza_Theme.icons.Sintezza_Rivals,
		title = L(opts.title),
		subtitle = L(opts.subtitle) or "",
	})
	f.header, f.title, f.subtitle, f.closeButton = header, header.title, header.subtitle, header.close

	-- footer
	local footer = CreateFrame("Frame", nil, f)
	footer:SetPoint("BOTTOMLEFT")
	footer:SetPoint("BOTTOMRIGHT")
	footer:SetHeight(Theme.FOOTER)
	Theme.Solid(footer, "BACKGROUND", C.panel, 1):SetAllPoints()
	Theme.Rule(footer, "TOP", C.line, 1)
	f.footer = footer

	f.footerLeft = Theme.Font(footer, 11, C.dim)
	f.footerLeft:SetPoint("LEFT", Theme.PAD, 0)
	f.footerRight = Theme.Font(footer, 11, C.dim)
	f.footerRight:SetPoint("RIGHT", opts.resizable and -27 or -Theme.PAD, 0)
	f.footerRight:SetJustifyH("RIGHT")

	-- content area between header and footer
	local content = CreateFrame("Frame", nil, f)
	content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -1, 0)
	content:SetPoint("BOTTOMRIGHT", 0, Theme.FOOTER)
	f.content = content

	-- restore geometry
	if store then
		if store.w and store.h then f:SetSize(math.max(store.w, opts.minW or 400), math.max(store.h, opts.minH or 300)) end
		f:SetPoint(store.point or "CENTER", UIParent, store.point or "CENTER", store.x or 0, store.y or 0)
		if store.scale and not prefs then f:SetScale(store.scale) end
	else
		f:SetPoint("CENTER")
	end
	if prefs then
		local resize
		if opts.resizable then
			resize = {
				minWidth = opts.minW or 600, minHeight = opts.minH or 400,
				maxWidth = 1640, maxHeight = 1200, width = opts.defaultW, height = opts.defaultH,
			}
			if store then
				resize.read = function() return store.w, store.h end
				resize.save = function(w, h) store.w, store.h = w, h end
			end
		end
		prefs:Bind(f, { defaultLayer = opts.defaultLayer, resize = resize })
	end

	if opts.name and UISpecialFrames then table.insert(UISpecialFrames, opts.name) end
	return f
end

--------------------------------------------------------------------- navigation
-- A left column of entries. entries: { { key, label, icon, tip }, ... }
function Theme.Nav(parent, entries, onSelect)
	local nav = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	nav:SetPoint("TOPLEFT")
	nav:SetPoint("BOTTOMLEFT")
	nav:SetWidth(Theme.NAV_W)
	brass:SidebarSurface(nav)

	nav.buttons = {}
	local y = -8
	for i, entry in ipairs(entries) do
		local b = widgets:NavButton(nav, L(entry.label), entry.key, function(key) onSelect(i, key) end)
		b:SetPoint("TOPLEFT", 0, y)
		b:SetPoint("TOPRIGHT", 0, y)
		b:SetHeight(30)
		y = y - 30

		b.label = b.text
		b.label:ClearAllPoints()
		b.label:SetPoint("LEFT", 27, 0)
		b.label:SetPoint("RIGHT", -45, 0)

		b.count = Theme.Font(b, 11, C.dim)
		b.count:SetPoint("RIGHT", -20, 0)
		b.count:SetJustifyH("RIGHT")

		if entry.tip then Theme.Tip(b, L(entry.label), L(entry.tip)) end
		nav.buttons[i] = b
	end

	function nav:Select(index)
		for i, b in ipairs(self.buttons) do
			b:SetSelected(i == index)
		end
	end

	return nav
end

