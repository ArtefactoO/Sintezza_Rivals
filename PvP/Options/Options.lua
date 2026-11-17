local _, root = ...
local ns = root.PvP
local O = {}
ns.Options, ns.modules.Options = O, O

local panel, tabs, scroll, body, bar
local pages, definitions, offsets = {}, {}, {}
local current = 1
local W = Sintezza_Theme:CreateWidgets(root.Theme)

local function layoutPage(holder)
	local y = -8
	for _, row in ipairs(holder.rows or {}) do
		local visible = not row.visibleWhen or row.visibleWhen()
		row:SetShown(visible)
		if visible then
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, y)
			row:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, y)
			y = y - row:GetHeight() - 3
		end
	end
	holder:SetHeight(-y + 10)
	body:SetHeight(holder:GetHeight())
	scroll:RefreshRange()
end

local function ensurePage(index)
	if not pages[index] then
		local holder = CreateFrame("Frame", nil, body)
		holder:SetPoint("TOPLEFT")
		holder:SetPoint("TOPRIGHT")
		holder:SetHeight(1)
		holder:Hide()
		pages[index] = holder
		definitions[index].build(holder)
	end
	return pages[index]
end

function O:ReflowCurrent()
	local holder = pages[current]
	if not holder then return end
	if holder.RefreshState then holder:RefreshState() end
	for _, row in ipairs(holder.rows or {}) do if row.Refresh then row:Refresh() end end
	body:SetWidth(math.max(1, scroll:GetWidth()))
	layoutPage(holder)
end

local function showPage(index)
	if not definitions[index] then return end
	if pages[current] then offsets[current] = scroll:GetVerticalScroll() end
	current = index
	local holder = ensurePage(index)
	for key, page in pairs(pages) do page:SetShown(key == current) end
	O:ReflowCurrent()
	scroll:SetVerticalScroll(math.max(0, math.min(offsets[current] or 0, body:GetHeight() - scroll:GetHeight())))
	scroll:RefreshRange()
	tabs:Refresh()
	return holder
end

local function build()
	for _, definition in ipairs(O.PAGES) do
		if not definition.devOnly or ns:IsDev() then definitions[#definitions + 1] = definition end
	end
	panel = ns.Theme.Window({
		name = "Sintezza_RivalsPvPOptions", width = 680, height = 544,
		resizable = true, minW = 650, minH = 420,
		title = root.Text("Настройки Sintezza Rivals", "Sintezza Rivals Settings"), addonName = "Sintezza_Rivals",
		windowAppearance = ns.WindowAppearance, defaultLayer = "DIALOG",
	})
	O.Panel = panel
	panel.footer:Hide()
	panel.content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
	local labels, values = {}, {}
	for index, definition in ipairs(definitions) do labels[index], values[index] = ns.Theme.L(definition.label), index end
	tabs = W:Segmented(panel.content, labels, values, function() return current end, showPage, true)
	tabs:SetPoint("TOPLEFT", 12, -4)
	tabs:SetPoint("TOPRIGHT", -12, -4)
	scroll, body, bar = W:ScrollFrame(panel.content, nil, 42)
	scroll:SetPoint("TOPLEFT", tabs, "BOTTOMLEFT", 12, -3)
	scroll:SetPoint("BOTTOMRIGHT", panel.content, "BOTTOMRIGHT", -27, 10)
	bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, 0)
	bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 0)
	panel:HookScript("OnSizeChanged", function() O:ReflowCurrent() end)
	panel:HookScript("OnShow", function()
		O:ReflowCurrent()
		C_Timer.After(0, function() if panel:IsVisible() then O:ReflowCurrent() end end)
	end)
	showPage(1)
end

function O:Open(key)
	if not panel then build() end
	if key then
		for index, definition in ipairs(definitions) do
			if definition.key == key then showPage(index); break end
		end
	end
	panel:Show()
	panel:Raise()
end

function O:Enable()
	local shared = Sintezza_Theme
	if self.category or not shared.RegisterLauncherPage then return end
	self.category = shared:RegisterLauncherPage({
		title = "Sintezza Rivals", icon = shared.icons.Sintezza_Rivals,
		buttonLabel = root.Text("Открыть настройки", "Open settings"),
		open = function() self:Open() end, appearance = root.Theme, keepSettingsOpen = true,
	})
end
