-- Sintezza Rivals / UI/Window.lua
--
-- The main frame: navigation, page header with the context chip,
-- toolbar, column headers, the refresh that fills the current tab, tab
-- selection and the public show/hide API. The chrome comes from Theme.lua.

local ADDON, root = ...
local ns = root.PvP

local U, X = ns.UI, ns.UIX
local T, TC = ns.Theme, ns.Theme.C
local data, ROW_H = X.data, X.ROW_H
local widgets = Sintezza_Theme:CreateWidgets(root.Theme)

local frame, nav
local tabPanels = {}
local tabToolbars = {}
local defaultTabs = { [7] = "rivalsHistory", [8] = "Stats", [9] = "rivalsHistory", [10] = "rivalsNameplates" }

local function FindTab(key)
	for index, tab in ipairs(X.TABS) do
		if (tab.id or tab.title) == key then return index end
	end
end

-- The context chip only appears when the addon is not fully at work: in the
-- open world there is nothing to say, elsewhere it says why it is quiet.
local CTX = {
	world_combat = { "In combat", TC.gold },
	bg = { root.Text("Поле боя", "Battleground"), TC.dim },
	arena = { "Paused", TC.dim },
	dungeon = { "Paused", TC.dim },
	raid = { "Paused", TC.dim },
}

--------------------------------------------------------------------- refresh
-- Modules call MarkDirty when they touch data. The window ticker rebuilds the
-- rows only then, and otherwise just repaints the relative-time column.
U.dirty = true

function U:MarkDirty()
	U.dirty = true
end

function U:Refresh()
	if not frame or not frame:IsShown() then return end
	U.dirty = false
	local TABS, selected = X.TABS, X.selected
	local tab = TABS[selected]
	frame.pageNote:SetText(T.L(tab.note) or "")
	wipe(data)
	if tab.build then
		root.RefreshOptions()
	else
		tab.fill()
		X.renderVisible()
	end

	-- context chip
	local ctx = CTX[ns.context or "world"]
	frame.ctxChip:SetShown(ctx and true or false)
	if ctx then
		frame.ctxLabel:SetText(T.L(ctx[1]))
		frame.ctxLabel:SetTextColor(ctx[2][1], ctx[2][2], ctx[2][3])
	end

	-- column captions with the sort arrow on the active one
	local cols = TABS[selected].cols
	local sortKey = X.sortKey or tab.defaultSortKey
	local sortDesc = not X.sortKey or X.sortDesc
	local colHeaders = X.colHeaders
	for i, fs in ipairs(colHeaders) do
		local spec = cols[i]
		if spec then
			local caption = T.L(spec[1])
			if spec[4] and spec[4] == sortKey then
				caption = caption .. (sortDesc and "  v" or "  ^")
			end
			fs:SetText(caption)
			fs:ClearAllPoints()
			local x = 6
			for j = 1, i - 1 do x = x + cols[j][2] + 6 end
			fs:SetPoint("LEFT", colHeaders.parent, "LEFT", x, 0)
			fs:SetWidth(spec[2])
			fs:SetJustifyH(spec[3])
			fs:Show()
		else
			fs:Hide()
		end
	end

	frame.footerLeft:SetText(T.L(TABS[selected].hint) or "")
	frame.footerRight:SetText((tab.build or tab.hideRowCount) and "" or tab.footerText or T.L("%d rows"):format(#data))
end

--------------------------------------------------------------------- tab selection
function X.useSort(scope)
	local sort = Sintezza_RivalsPvPDB.settings.ui.sort
	local saved = sort and sort[scope]
	if scope == "Duels" and saved and saved.key == "how" then
		sort[scope], saved = nil, nil
	end
	X.sortKey = saved and saved.key or nil
	X.sortDesc = (saved == nil) or saved.desc
end

-- what you typed in the filter belongs to the tab you typed it in
local filters = {}

function U:SelectTab(i)
	local TABS, filterBox = X.TABS, X.filterBox
	-- a saved index may no longer exist
	if type(i) ~= "number" or i < 1 or i > #TABS then i = 1 end
	if X.selected and filterBox then filters[X.selected] = filterBox:GetText() end
	X.selected = i
	-- the sort you chose for a tab is remembered per tab
	local ui = Sintezza_RivalsPvPDB.settings.ui
	local tab = TABS[i]
	local key = tab.id or tab.title
	X.useSort(tab.sortScope or key)
	ui.tab = i
	if tab.id ~= "rivalsHistory" and root.PvPSource then root.PvPSource:StopPreview() end
	ui.tabKey = key
	nav:Select(i)
	for _, panel in pairs(tabPanels) do panel:Hide() end
	X.colHeaders.parent:SetShown(not tab.build)
	X.list:SetShown(not tab.build)
	X.colHeaders.parent:SetPoint("TOPLEFT", frame.page, "TOPLEFT", 12, tab.extraToolbar and -118 or -84)
	X.colHeaders.parent:SetPoint("TOPRIGHT", frame.page, "TOPRIGHT", -28, tab.extraToolbar and -118 or -84)
	if tab.build then X.scrollBar:Hide() end
	if tab.build then
		local panel = tabPanels[tab]
		if not panel then
			panel = CreateFrame("Frame", nil, frame.page)
			panel:Hide()
			panel:SetPoint("TOPLEFT", 0, -52)
			panel:SetPoint("BOTTOMRIGHT", frame.page, "BOTTOMRIGHT", 0, 8)
			tab.build(panel)
			tabPanels[tab] = panel
		end
		panel:Show()
	end
	filterBox:ClearAllPoints()
	filterBox:SetPoint("TOPLEFT", frame.page, "TOPLEFT", 14, -52)
	if tab.search then
		filterBox:SetPlaceholder(tab.search)
		filterBox:SetText(filters[i] or "")
		filterBox:Show()
	else
		filterBox:SetText("")
		filterBox:Hide()
	end
	for _, toolbar in pairs(tabToolbars) do toolbar:Hide() end
	if tab.buildToolbar then
		local toolbar = tabToolbars[tab]
		if not toolbar then
			toolbar = tab.buildToolbar(filterBox:GetParent(), filterBox)
			tabToolbars[tab] = toolbar
		end
		toolbar:Refresh()
		toolbar:Show()
	end
	frame.pageTitle:SetText(T.L(TABS[i].title))
	frame.pageNote:SetText(T.L(TABS[i].note) or "")
	if not tab.build then X.scrollTo(0) end
	U:MarkDirty()
	-- guarded: a fill that errors must never leave the previous tab's rows on
	-- screen with nothing to say why
	ns:Guard(U.Refresh, U)
end

--------------------------------------------------------------------- ticker
-- A rebuild walks every record and formats every cell, so in a busy zone it
-- is coalesced to once every three seconds; between rebuilds only the clock
-- column is repainted.
local lastBuild = 0
local function refreshNow() U:Refresh() end
local function tick()
	if not frame or not frame:IsShown() then return end
	if U.dirty and (GetTime() - lastBuild) >= 3 then
		lastBuild = GetTime()
		ns:Guard(refreshNow)
	else
		ns:Guard(X.tickClock)
	end
end

--------------------------------------------------------------------- build
local function build()
	local ui = Sintezza_RivalsPvPDB.settings.ui
	-- The smallest the window may go is the width of its widest table plus the
	-- navigation column: below that the columns run into each other.
	local widest = 0
	for _, tab in ipairs(X.TABS) do
		local sum = 0
		for _, spec in ipairs(tab.layoutColumns or tab.cols) do sum = sum + spec[2] + 6 end
		if sum > widest then widest = sum end
	end
	local minW, minH = T.NAV_W + widest + 60, 560
	frame = T.Window({
		name = "Sintezza_RivalsPvPFrame", width = math.max(ui.w or X.W, minW), height = math.max(ui.h or X.H, minH),
		defaultW = X.W, defaultH = X.H,
		minW = minW, minH = minH, key = ui, resizable = true,
		windowAppearance = ns.WindowAppearance,
		title = "Sintezza Rivals", addonName = "Sintezza_Rivals",
	})

	local content = frame.content

	local TABS = X.TABS
	local navEntries = {}
	for _, tab in ipairs(TABS) do
		navEntries[#navEntries + 1] = { key = tab.title, label = tab.title }
	end
	nav = T.Nav(content, navEntries, function(i) U:SelectTab(i) end)

	local settings = widgets:Button(frame.header, T.L("Settings"), function() ns.Options:Open() end)
	settings:SetWidth(100)
	settings:SetPoint("RIGHT", frame.closeButton, "LEFT", -4, 0)
	-- page area
	local page = CreateFrame("Frame", nil, content)
	page:SetPoint("TOPLEFT", nav, "TOPRIGHT", 0, 0)
	page:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
	frame.page = page

	frame.pageTitle = T.Font(page, 15, TC.fg)
	root.Theme:Font(frame.pageTitle, 20, "", TC.fg, "display")
	frame.pageTitle:SetPoint("TOPLEFT", 14, -12)
	frame.pageNote = T.Font(page, 11, TC.muted)
	frame.pageNote:SetPoint("TOPLEFT", frame.pageTitle, "BOTTOMLEFT", 0, -3)
	frame.pageNote:SetWidth(math.max(200, frame:GetWidth() - T.NAV_W - 160))
	frame.pageNote:SetWordWrap(false)

	local function chip(width)
		local c = CreateFrame("Frame", nil, page)
		c:SetSize(width, 26)
		c:SetPoint("TOPRIGHT", page, "TOPRIGHT", -14, -12)
		T.Solid(c, "BACKGROUND", TC.panel, 1):SetAllPoints()
		T.Border(c, TC.line, 1)
		c.label = T.Font(c, 12, TC.fg)
		c.label:SetPoint("CENTER")
		c.label:SetJustifyH("CENTER")
		return c
	end
	local ctxChip = chip(120)
	frame.ctxLabel = ctxChip.label
	frame.ctxChip = ctxChip

	-- toolbar: search
	local filterBox = T.SearchBox(page, 240, function()
		U:MarkDirty()
		U:Refresh()
		if X.TABS[X.selected].id == "rivalsHistory" then X.scrollTo(0) end
	end,
		"search name, class, race, zone")
	filterBox:SetPoint("TOPLEFT", page, "TOPLEFT", 14, -52)
	X.filterBox = filterBox

	-- column header strip
	local hdr = CreateFrame("Button", nil, page)
	hdr:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -84)
	hdr:SetPoint("TOPRIGHT", page, "TOPRIGHT", -28, -84)
	hdr:SetHeight(22)
	T.Solid(hdr, "BACKGROUND", TC.panel, 1):SetAllPoints()
	T.Rule(hdr, "BOTTOM", TC.line, 1)
	local colHeaders = { parent = hdr }
	for i = 1, 9 do
		local fs = T.Font(hdr, 11, TC.fg)
		fs:SetWordWrap(false)
		colHeaders[i] = fs
	end
	X.colHeaders = colHeaders
	hdr:SetScript("OnClick", function(self)
		local x = GetCursorPosition() / self:GetEffectiveScale() - self:GetLeft()
		local _, spec = X.colAt(x)
		if spec and spec[4] then
			local tab = X.TABS[X.selected]
			local sortKey = X.sortKey or tab.defaultSortKey
			local sortDesc = not X.sortKey or X.sortDesc
			X.sortKey = spec[4]
			if sortKey == X.sortKey then X.sortDesc = not sortDesc else X.sortDesc = spec[6] ~= false end
			ui.sort = ui.sort or {}
			ui.sort[tab.sortScope or tab.id or tab.title] = { key = X.sortKey, desc = X.sortDesc }
			U:Refresh()
			if tab.defaultSortKey then X.scrollTo(0) end
		end
	end)

	-- rows live in a clipping container with our own scrollbar beside it
	local list = CreateFrame("Frame", nil, page)
	list:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, -2)
	list:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -30, 10)
	if list.SetClipsChildren then list:SetClipsChildren(true) end
	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", function(_, delta)
		X.scrollBy(delta > 0 and -3 or 3)
	end)
	X.list = list

	local scrollBar = T.VScroll(page, X.scrollTo)
	scrollBar:SetPoint("TOPRIGHT", list, "TOPRIGHT", 16, 0)
	scrollBar:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 16, 0)
	X.scrollBar = scrollBar

	local function fitRows()
		local h = list:GetHeight()
		-- floor, not ceil: a half row at the bottom would be clipped anyway
		X.numRows = math.max(4, math.floor(h / ROW_H))
		X.renderVisible()
	end
	list:SetScript("OnSizeChanged", fitRows)
	frame.onResized = function()
		frame.pageNote:SetWidth(math.max(200, frame:GetWidth() - T.NAV_W - 160))
		fitRows()
		U:MarkDirty()
		U:Refresh()
	end
	X.numRows = math.max(4, math.floor((frame:GetHeight() - 230) / ROW_H))

	frame:HookScript("OnHide", function()
		if root.PvPSource then root.PvPSource:StopPreview() end
	end)
	frame:SetScript("OnShow", function()
		U:MarkDirty()
		U:Refresh()
		if not U.ticker then U.ticker = C_Timer.NewTicker(1, tick) end
	end)

	U:SelectTab(FindTab(ui.tabKey) or FindTab(defaultTabs[ui.tab or 0]) or 1)
end

--------------------------------------------------------------------- api
function U:IsShown() return frame and frame:IsShown() or false end

function U:Toggle()
	if not frame then build() end
	if frame:IsShown() then U:Hide() else U:Show() end
end

function U:Show()
	if not frame then build() end
	frame:Raise()
	-- open on the tab the player asked for, or wherever they left off
	-- the setting numbers the tabs in their full order; a switched-off feature
	-- removes its tab, so the number is turned into a title first
	local default = Sintezza_RivalsPvPDB.settings.ui.defaultTab or 0
	if default == 7 and root.PvPSource then root.PvPSource:SelectDuelHistory() end
	local want = defaultTabs[default]
	local i = want and FindTab(want)
	if i and i ~= X.selected then U:SelectTab(i) end
	frame:Show()
	Sintezza_RivalsPvPDB.settings.ui.shown = true
end

function U:OpenTab(key)
	local index = FindTab(key)
	if not index then return false end
	self:Show()
	self:SelectTab(index)
	return true
end

function U:Hide()
	if root.PvPSource then root.PvPSource:StopPreview() end
	if frame then frame:Hide() end
	Sintezza_RivalsPvPDB.settings.ui.shown = false
end

function U:Enable()
	-- built on first use, not on login: nothing is created for a player who
	-- never opens the window
	if Sintezza_RivalsPvPDB.settings.ui.shown then U:Show() end
end

function Sintezza_RivalsPvP_OnAddonCompartmentClick()
	U:Toggle()
end


