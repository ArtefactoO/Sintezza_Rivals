-- Sintezza Rivals / Options/Pages.lua
--
-- The contents of the settings window: one builder per category, each a
-- column of rows built from the Theme widgets. Options.lua owns the window,
-- the navigation and the search around them.

local ADDON, root = ...
local ns = root.PvP

local O = ns.Options
local T, Text = ns.Theme, root.Text

--------------------------------------------------------------------- helpers
local function setting(path)
	local t = Sintezza_RivalsPvPDB.settings
	for i = 1, #path - 1 do t = t[path[i]] end
	return t, path[#path]
end

local function get(path)
	local t, k = setting(path)
	return t[k]
end

local function set(path, v)
	local t, k = setting(path)
	t[k] = v
end

-- every control is a row; the row owns the label and the explanation
local function toggleRow(parent, y, name, help, path, onChange)
	local row = T.Row(parent, y, name, help)
	local toggle = T.Toggle(row, function() return get(path) end, function(v)
		set(path, v)
		if onChange then onChange(v) end
	end)
	T.AttachControl(row, toggle, T.TOGGLE_H)
	row.control = toggle
	return row, y - row:GetHeight()
end

local function sliderRow(parent, y, name, help, path, min, max, step, format, onChange)
	local row = T.Row(parent, y, name, help)
	local slider = T.Slider(row, 210, min, max, step,
		function() return get(path) end,
		function(v)
			set(path, v)
			if onChange then onChange(v) end
		end, format)
	T.AttachControl(row, slider, 32)
	row.control = slider
	return row, y - row:GetHeight()
end

local function choiceRow(parent, y, name, help, values, path, onChange)
	local row = T.Row(parent, y, name, help)
	local sel = T.Select(row, 170, values,
		function() return get(path) end,
		function(v) set(path, v) end,
		onChange)
	T.AttachControl(row, sel, 26)
	row.control = sel
	return row, y - row:GetHeight()
end

local function buttonRow(parent, y, name, help, label, onClick, width)
	local row = T.Row(parent, y, name, help)
	local b = T.Button(row, label, width or 140, onClick)
	T.AttachControl(row, b, 26)
	row.control = b
	return row, y - row:GetHeight()
end

-- two actions that belong to one setting, side by side: "Add" and "Clear" read
-- as two things you can do, where one button labelled "Add / clear" reads as a
-- guess about which one you are going to get
local function buttonsRow(parent, y, name, help, first, second)
	local row = T.Row(parent, y, name, help)
	local w1 = first[3] or 110
	local w2 = second and (second[3] or 110) or 0
	local holder = CreateFrame("Frame", nil, row)
	holder:SetSize(w1 + (second and (w2 + 8) or 0), 26)
	local a = T.Button(holder, first[1], w1, first[2])
	a:SetPoint("TOPLEFT")
	row.control = a
	if second then
		local b = T.Button(holder, second[1], w2, second[2])
		b:SetPoint("TOPLEFT", a, "TOPRIGHT", 8, 0)
		row.control2 = b
	end
	T.AttachControl(row, holder, 26)
	return row, y - row:GetHeight()
end

local function header(parent, y, text)
	local _, n = T.HeaderRow(parent, y, text)
	return n
end

--------------------------------------------------------------------- pages
local function Advanced(parent, y, build)
	local label = Text("Дополнительно", "Advanced")
	local open
	local row, n
	row, n = buttonRow(parent, y, label, nil, Text("Развернуть", "Expand"), function()
		open = not open
		row.control.label:SetText(open and Text("Свернуть", "Collapse") or Text("Развернуть", "Expand"))
		O:ReflowCurrent()
	end)
	local from = #parent.rows + 1
	local bottom = build(parent, n)
	for index = from, #parent.rows do
		parent.rows[index].visibleWhen = function(filter) return open or filter ~= nil end
	end
	return bottom
end

local function buildRecording(parent)
	local n = header(parent, -10, Text("Запись PvP", "PvP recording"))
	local controls = {}
	local function RefreshState()
		local enabled = ns:IsRecording() == true
		for _, control in ipairs(controls) do
			if control.slider then
				control.slider:EnableMouse(enabled)
				control:SetAlpha(enabled and 1 or 0.5)
			else
				control:SetEnabled(enabled)
			end
		end
	end
	local _
	_, n = toggleRow(parent, n, Text("Записывать PvP", "Record PvP"), nil, { "enabled" }, function(value)
		ns:OnRecordingChanged(value)
		RefreshState()
		O:ReflowCurrent()
	end)
	local paused = T.Row(parent, n, Text("Запись и оповещения приостановлены. История доступна.",
		"Recording and alerts are paused. History is available."))
	paused.visibleWhen = function() return not ns:IsRecording() end
	n = n - paused:GetHeight()

	local function Toggle(name, path, changed)
		local row
		row, n = toggleRow(parent, n, name, nil, path, changed)
		controls[#controls + 1] = row.control
	end
	Toggle(Text("Встречи", "Encounters"), { "modules", "enemies" })
	Toggle(Text("Бои в мире", "World fights"), { "modules", "fights" }, function(value)
		if not value then ns.Deaths:StopRecording() end
	end)
	Toggle(Text("Поля боя", "Battlegrounds"), { "modules", "battlegrounds" }, function(value)
		if not value then ns.Deaths:StopRecording() end
	end)
	Toggle(Text("Дуэли", "Duels"), { "modules", "duels" }, function(value)
		if not value then ns.Duels:StopRecording() end
	end)

	n = header(parent, n, Text("Игрок из списка наблюдения", "Watched players"))
	Toggle(Text("Сообщение в чат", "Chat message"), { "alerts", "chat", "watched" })
	Toggle(Text("Плашка на экране", "On-screen banner"), { "alerts", "banner" })
	Toggle(Text("Звук", "Sound"), { "alerts", "soundOnSighting" })
	n = header(parent, n, Text("Опасная зона", "Dangerous zone"))
	Toggle(Text("Сообщение в чат", "Chat message"), { "alerts", "chat", "zone" })

	return Advanced(parent, n, function(_, y)
		n = y
		local row
		row, n = sliderRow(parent, n, Text("Интервал повторной встречи", "Repeat encounter interval"),
			nil, { "sightings", "dedupeSeconds" }, 10, 300, 10, function(v) return T.L("%d s"):format(v) end)
		controls[#controls + 1] = row.control
		row, n = sliderRow(parent, n, Text("Интервал оповещения", "Alert interval"),
			nil, { "alerts", "watchSeconds" }, 5, 120, 5, function(v) return T.L("%d s"):format(v) end)
		controls[#controls + 1] = row.control
		Toggle("Watch nameplates", { "sightings", "fromNameplates" })
		Toggle("Watch your target", { "sightings", "fromTarget" })
		Toggle("Watch mouseover", { "sightings", "fromMouseover" })
		Toggle("You died", { "alerts", "chat", "death" })
		Toggle("You killed somebody", { "alerts", "chat", "kill" })
		Toggle("Duel results", { "alerts", "chat", "duel" })
		Toggle("Every new enemy seen", { "alerts", "chat", "sighting" })
		Toggle("Your own actions", { "alerts", "chat", "action" })
		Toggle("Warn when someone stealths next to you", { "alerts", "stealthCast" })
		Toggle("Different sound for rogues and druids", { "alerts", "stealthSound" })
		Toggle("Screenshot when you die", { "alerts", "screenshotOnDeath" })
		Toggle("A line on unit tooltips", { "alerts", "unitTooltip" })
		row, n = sliderRow(parent, n, "Ignore enemies this far below you",
			"A level difference. At -5 an enemy five or more levels under you is recorded but never alerts, because they are not a threat. Zero alerts on everyone.",
			{ "alerts", "minLevelDiff" }, -30, 0, 1,
			function(v) return v == 0 and T.L("everyone alerts") or T.L("%d levels"):format(v) end)
		controls[#controls + 1] = row.control
		row, n = sliderRow(parent, n, Text("Автоматически отмечать после смертей", "Watch after repeated deaths"),
			Text("0 отключает автоматические отметки.", "0 turns off automatic watching."),
			{ "autoWatchKills" }, 0, 10, 1)
		controls[#controls + 1] = row.control
		RefreshState()
		return n
	end)
end

local function buildMap(parent, y)
	local function refreshMap() if ns.Map then ns.Map:Update() end end
	local _, n = toggleRow(parent, y, Text("Точки на карте и миникарте", "Map and minimap pins"), nil,
		{ "modules", "map" }, refreshMap)
	_, n = toggleRow(parent, n, root.Text("Места боев на карте мира", "PvP fights on the world map"),
		root.Text("Красные мечи отмечают смерти, зеленые — добивания.", "Red swords mark your deaths. Green swords mark your kills."),
		{ "map", "enabled" }, refreshMap)
	_, n = toggleRow(parent, n, "Pins for enemy sightings", "", { "map", "sightings" }, refreshMap)
	_, n = toggleRow(parent, n, "Pins for your deaths", "", { "map", "deaths" }, refreshMap)
	_, n = toggleRow(parent, n, "Pins for your kills", "", { "map", "kills" }, refreshMap)
	_, n = toggleRow(parent, n, "Hand coordinates to TomTom as well",
		"When TomTom is installed, clicking a coordinate also sets a waypoint there.",
		{ "map", "useTomTom" })
	_, n = sliderRow(parent, n, "Hide sightings older than",
		"Deaths and kills are always shown.", { "map", "minutes" }, 10, 360, 10,
		function(v) return T.L("%d min"):format(v) end)
	_, n = toggleRow(parent, n, "Minimap blips",
		"Marks where you saw an enemy last. It is your own position at the time, not theirs now.",
		{ "minimap", "enabled" })
	_, n = toggleRow(parent, n, "Minimap: watched enemies only",
		"Off shows every recent sighting.", { "minimap", "watchedOnly" })
	_, n = toggleRow(parent, n, "Keep watched blips on the minimap edge",
		"When they were last seen further away than the minimap reaches, the blip sticks to the rim so the direction still reads.",
		{ "minimap", "floatOnEdge" })
	_, n = toggleRow(parent, n, "Your deaths on the minimap",
		root.Text("Красные мечи остаются на тот же срок, что и метки встреч.",
			"Red swords stay visible for the same period as sightings."), { "minimap", "deaths" })
	_, n = sliderRow(parent, n, "Hide blips older than", "",
		{ "minimap", "minutes" }, 5, 120, 5, function(v) return T.L("%d min"):format(v) end)
	return n
end

local function buildWindow(parent)
	local y = -10
	local n = header(parent, y, "Look")
	local _
	local appearance = T.Row(parent, n, root.Text("Оформление", "Appearance"))
	T.AttachControl(appearance, T.Button(appearance, "Sintezza Theme", 170,
		function() Sintezza_Theme:OpenSettings() end), 26)
	n = n - appearance:GetHeight()
	local shared = T.Row(parent, n, root.Text("Окно и миникарта", "Window and minimap"), "")
	local block = Sintezza_Theme:CreateWindowOptions(shared, root.Theme, {
		windows = { { prefs = ns.WindowAppearance } },
		getMinimap = function() return not root.db.minimap.hide end,
		setMinimap = function(value)
			root.db.minimap.hide = not value
			root.Launcher:RefreshMinimap(root.db.minimap)
		end,
	})
	shared.name:Hide()
	shared.fixedHeight = block:GetHeight() + 6
	shared:SetHeight(shared.fixedHeight)
	block:SetPoint("TOPLEFT", 10, -3)
	block:SetPoint("TOPRIGHT", -10, -3)
	shared.searchText = ns.Lower(root.Text(
		"окно миникарта масштаб непрозрачность слой закрепить положение",
		"window minimap scale opacity layer lock position"))
	shared.control = block
	n = n - shared:GetHeight()

	n = header(parent, n, "Opening it")
	_, n = choiceRow(parent, n, "Open the window on",
		"Which tab the window starts on.",
		{ { 0, "Last used" }, { 9, root.Text("История PvP", "PvP history") },
		  { 10, root.Text("Неймплейты", "Nameplates") }, { 7, "PvP history: Duels" }, { 8, "Stats" } },
		{ "ui", "defaultTab" })
	_, n = buttonRow(parent, n, "Keybindings",
		"Opens the game key bindings; look for the Sintezza Rivals section.",
		"Open bindings", function()
			if SettingsPanel and SettingsPanel.OpenToCategory and Settings and Settings.KEYBINDINGS_CATEGORY_ID then
				pcall(Settings.OpenToCategory, Settings.KEYBINDINGS_CATEGORY_ID)
			elseif KeyBindingFrame_LoadUI then
				pcall(KeyBindingFrame_LoadUI)
				if KeyBindingFrame then KeyBindingFrame:Show() end
			else
				ns:Print("open Game Menu, then Key Bindings, and look for Sintezza Rivals")
			end
		end)

	n = header(parent, n, "On-screen strip")
	_, n = toggleRow(parent, n, "Show the strip",
		"A thin bar you leave on screen: recent enemy sightings in this zone and watched enemies nearby.",
		{ "hud", "show" }, function() if ns.HUD then ns.HUD:Update() end end)
	_, n = toggleRow(parent, n, "Lock the strip",
		"Stops dragging it around.", { "hud", "locked" })

	return n
end

local function buildDiagnostics(parent)
	local y = -10
	local _, n = buttonsRow(parent, y, "Demo data",
		"Fills every table with made-up records, marked as demo in the window. Clear removes exactly what it added.",
		{ "Add", function() if ns.UI then ns.UI:Demo(false) end end, 90 },
		{ "Clear", function() if ns.UI then ns.UI:Demo(true) end end, 90 })
	_, n = buttonRow(parent, n, "Interface self test",
		"Drives every tab, view, sort, scroll, popup and the message parser, and reports anything that errors.",
		"Run self test", function() if ns.UI then ns.UI:SelfTest() end end)
	_, n = toggleRow(parent, n, "Keep an internal log",
		"Off by default. Warnings and errors are always kept; this adds the chatty info lines, useful only when something needs diagnosing.",
		{ "debug", "logging" })
	_, n = toggleRow(parent, n, "Capture raw chat payloads",
		"Keeps system and honor messages as they were received. Off by default.",
		{ "debug", "raw" })
	_, n = sliderRow(parent, n, "Log line limit", "", { "debug", "logCap" }, 100, 2000, 100)
	_, n = toggleRow(parent, n, "Run the API probe automatically",
		"The probe mapped this client already. Leaving it off saves memory and a battery run on every context change; /rivals probe still works. Takes effect after a reload.",
		{ "probe", "autoRun" })
	_, n = buttonRow(parent, n, "Run the probe now",
		"Re-runs the API diagnostic for the context you are in and prints a summary.",
		"Run probe", function() SlashCmdList.SINTEZZA_RIVALS_PVP("probe") end)
	_, n = buttonRow(parent, n, "Print the full probe result",
		"One line per API call for the context you are in: ok, secret, nil, error, missing or blocked.",
		"Probe dump", function() SlashCmdList.SINTEZZA_RIVALS_PVP("probe dump") end)
	_, n = buttonRow(parent, n, "Check the probe's own logic",
		"A tiny self test of the classifier that decides ok / secret / nil / error.",
		"Run check", function() SlashCmdList.SINTEZZA_RIVALS_PVP("selftest") end)
	_, n = buttonRow(parent, n, "Re-test the combat log",
		"Tries to register the combat log again. It is forbidden on this client, so expect the blocked popup.",
		"Test combat log", function() SlashCmdList.SINTEZZA_RIVALS_PVP("cleu") end)
	return n
end

O.PAGES = {
	{ key = "recording", label = Text("Запись и оповещения", "Recording and alerts"),
		title = Text("Запись и оповещения", "Recording and alerts"), build = buildRecording },
	{ key = "markers", label = Text("Карта", "Map"), title = Text("Карта и миникарта", "Map and minimap"),
		build = function(parent) return buildMap(parent, -10) end },
	{ key = "window", label = Text("Окно и миникарта", "Window and minimap"),
		title = Text("Окно и миникарта", "Window and minimap"), build = buildWindow },
	{ key = "diag", label = "Diagnostics", title = "Diagnostics",
		note = "Logging and the API probe. All off by default.", build = buildDiagnostics,
		-- the probe is a separate development add-on; without it this page has
		-- nothing to offer and the combat-log test would only produce the
		-- blocked-action popup
		devOnly = true },
}
