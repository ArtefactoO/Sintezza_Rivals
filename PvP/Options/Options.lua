-- Sintezza Rivals / Options.lua
--
-- Settings in the same house look as the main window: a left navigation column
-- of categories, and on the right one row per setting with its name, a line
-- explaining what it does, and the control on the right edge.
--
-- Built on first open, so a player who never touches the options pays nothing.

local ADDON, root = ...
local ns = root.PvP

local O = {}
ns.Options = O
ns.modules.Options = O

local W, H = 820, 600
local panel, nav, page, scroll, body, searchBox
local pages, current = {}, 1

local T, TC
-- the category list, from Options/Pages.lua; taken when the window is built
local PAGES

--------------------------------------------------------------------- build
local function ensurePage(i)
	if pages[i] then return pages[i] end
	local holder = CreateFrame("Frame", nil, body)
	holder:SetPoint("TOPLEFT")
	holder:SetPoint("TOPRIGHT")
	holder:SetHeight(1)
	holder.startY = -10
	holder:Hide()
	pages[i] = holder
	PAGES[i].build(holder)
	T.Reflow(holder)
	return holder
end

-- the search needs every page to exist, so it can count matches per category
local function buildAllPages()
	for i = 1, #PAGES do ensurePage(i) end
end

local function searchText()
	local s = searchBox and searchBox:GetText() or ""
	return s ~= "" and ns.Lower(s) or nil
end

local function updateNavCounts()
	local filter = searchText()
	for i, b in ipairs(nav.buttons) do
		if filter then
			local n = T.CountMatches(pages[i], filter)
			b.count:SetText(n > 0 and tostring(n) or "|cff6b6f76-|r")
		else
			b.count:SetText("")
		end
	end
end

local function showPage(i)
	current = i
	nav:Select(i)
	page.title:SetText(T.L(PAGES[i].title))
	page.note:SetText(T.L(PAGES[i].note) or "")
	local holder = ensurePage(i)
	for idx, h in pairs(pages) do h:SetShown(idx == i) end
	local filter = searchText()
	local _, shown = T.Reflow(holder, filter)
	body:SetHeight(holder:GetHeight())
	scroll:ToTop()
	if page.empty then
		page.empty:SetShown(filter ~= nil and shown == 0)
	end
end

function O:ReflowCurrent()
	local holder = pages[current]
	if not holder or not scroll then return end
	T.Reflow(holder, searchText())
	body:SetHeight(holder:GetHeight())
	scroll:Refresh()
end

-- called when the search text changes: count matches everywhere, and jump to a
-- category that actually has one
local function applySearch()
	local filter = searchText()
	buildAllPages()
	updateNavCounts()
	if filter and T.CountMatches(pages[current], filter) == 0 then
		for i = 1, #PAGES do
			if T.CountMatches(pages[i], filter) > 0 then
				showPage(i)
				return
			end
		end
	end
	showPage(current)
end

local function build()
	T = ns.Theme
	TC = T.C
	PAGES = O.PAGES

	panel = T.Window({
		name = "Sintezza_RivalsPvPOptions", width = W, height = H,
		resizable = true, minW = W, minH = 520, title = "Sintezza Rivals",
		windowAppearance = ns.WindowAppearance, defaultLayer = "DIALOG",
	})
	O.Panel = panel

	-- the Diagnostics page only exists in development mode (see ns:IsDev)
	for i = #PAGES, 1, -1 do
		if PAGES[i].devOnly and not ns:IsDev() then table.remove(PAGES, i) end
	end
	local entries = {}
	for i, p in ipairs(PAGES) do entries[i] = { key = p.key, label = p.label } end
	nav = T.Nav(panel.content, entries, function(i) showPage(i) end)

	page = CreateFrame("Frame", nil, panel.content)
	page:SetPoint("TOPLEFT", nav, "TOPRIGHT", 0, 0)
	page:SetPoint("BOTTOMRIGHT", panel.content, "BOTTOMRIGHT", 0, 0)

	page.title = T.Font(page, 15, TC.fg)
	page.title:SetPoint("TOPLEFT", 14, -12)
	page.note = T.Font(page, 11, TC.muted)
	page.note:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -3)
	page.note:SetPoint("TOPRIGHT", page, "TOPRIGHT", -250, -32)
	page.note:SetJustifyH("LEFT")

	-- search across every category, with a match count beside each one
	searchBox = T.SearchBox(page, 220, function() applySearch() end, "search every setting")
	searchBox:SetPoint("TOPRIGHT", page, "TOPRIGHT", -20, -10)

	page.empty = T.Font(page, 12, TC.muted)
	page.empty:SetPoint("TOPLEFT", 16, -70)
	page.empty:SetText(T.L("No matching settings in this category."))
	page.empty:Hide()

	local divider = T.Solid(page, "BORDER", TC.line, 1)
	divider:SetHeight(1)
	divider:SetPoint("TOPLEFT", 10, -52)
	divider:SetPoint("TOPRIGHT", -20, -52)

	scroll, body = T.ScrollArea(page, 48)
	scroll:SetPoint("TOPLEFT", 10, -56)
	scroll:SetPoint("BOTTOMRIGHT", -28, 10)
	body:SetSize(W - T.NAV_W - 50, 10)

	panel.footerRight:SetText("")
	panel.onResized = function()
		body:SetWidth(panel:GetWidth() - T.NAV_W - 50)
		if pages[current] then
			T.Reflow(pages[current], searchText())
			body:SetHeight(pages[current]:GetHeight())
			scroll:Refresh()
		end
	end

	showPage(1)
end

--------------------------------------------------------------------- api
function O:Open(key)
	if not panel then build() end
	if key then
		for index, definition in ipairs(PAGES) do
			if definition.key == key then
				if searchBox:GetText() ~= "" then searchBox:SetText("") end
				showPage(index)
				break
			end
		end
	end
	-- somebody with a window manager addon may have it parked behind the main
	-- window; clicking Options has to bring it forward, not just show it
	panel:Show()
	panel:Raise()
end

-- a small entry in the Blizzard settings list, so the addon is discoverable
-- there without squeezing a whole settings page into that canvas
local function registerStub()
	if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
	local stub = CreateFrame("Frame", "Sintezza_RivalsPvPSettingsStub", UIParent)
	stub:SetSize(500, 200)
	stub.name = "Sintezza Rivals"
	local t = stub:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	local icon = stub:CreateTexture(nil, "ARTWORK")
	icon:SetSize(24, 24)
	icon:SetPoint("TOPLEFT", 16, -16)
	icon:SetTexture(Sintezza_Theme.icons.Sintezza_Rivals)
	t:SetPoint("LEFT", icon, "RIGHT", 8, 0)
	t:SetText("Sintezza Rivals " .. ns.version)
	local widgets = Sintezza_Theme:CreateWidgets(root.Theme)
	local b = widgets:Button(stub, root.Text("Открыть настройки", "Open settings"), function() O:Open() end)
	b:SetSize(220, 26)
	b:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -16)
	local ok, cat = pcall(Settings.RegisterCanvasLayoutCategory, stub, "Sintezza Rivals")
	if ok and cat then
		O.category = cat
		pcall(Settings.RegisterAddOnCategory, cat)
	end
end

function O:Enable()
	registerStub()
end
