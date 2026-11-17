local ADDON, root = ...
local ns = root.PvP

local O = ns.Options
local T, Text = ns.Theme, root.Text
local W = Sintezza_Theme:CreateWidgets(root.Theme)

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

local function add(parent, row, y, help)
	if row.label then root.Theme:Font(row.label, 11, "", root.Theme.text, "body") end
	parent.rows = parent.rows or {}
	parent.rows[#parent.rows + 1] = row
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
	row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
	if help and help ~= "" then W:Help(row, T.L(help), row.label or row.title) end
	return row, y - row:GetHeight() - 3
end

local function toggleRow(parent, y, name, help, path, onChange)
	local row = W:Toggle(parent, T.L(name), function() return get(path) end, function(v)
		set(path, v)
		if onChange then onChange(v) end
		if parent.RefreshState then parent:RefreshState() end
	end)
	row.control = row
	return add(parent, row, y, help)
end

local function sliderRow(parent, y, name, help, path, min, max, step, format, onChange)
	local leaf = path[#path]
	local suffix = leaf == "minutes" and Text(" мин", " min")
		or (leaf == "dedupeSeconds" or leaf == "watchSeconds") and Text(" с", " s") or nil
	local row = W:SliderRow(parent, T.L(name), min, max, step,
		function() return get(path) end,
		function(v)
			set(path, v)
			if onChange then onChange(v) end
		end, suffix)
	row.control = row
	return add(parent, row, y, help)
end

local function choiceRow(parent, y, name, help, values, path, onChange)
	local choices, order = {}, {}
	for index, entry in ipairs(values) do choices[entry[1]], order[entry[1]] = T.L(entry[2]), index end
	local row = W:ChoiceRow(parent, T.L(name), choices, function() return get(path) end,
		function(value) set(path, value); if onChange then onChange(value) end end, order)
	row.control = row
	return add(parent, row, y, help)
end

local function buttonRow(parent, y, name, help, label, onClick, width)
	local row = W:SettingRow(parent, T.L(name))
	local b = W:Button(row, T.L(label), onClick)
	b:SetSize(width or 140, 24)
	b:SetPoint("RIGHT")
	row.control = b
	return add(parent, row, y, help)
end

local function buttonsRow(parent, y, name, help, first, second)
	local row = W:SettingRow(parent, T.L(name))
	local w1 = first[3] or 110
	local w2 = second and (second[3] or 110) or 0
	local holder = CreateFrame("Frame", nil, row)
	holder:SetSize(w1 + (second and (w2 + 8) or 0), 26)
	local a = W:Button(holder, T.L(first[1]), first[2])
	a:SetSize(w1, 24)
	a:SetPoint("TOPLEFT")
	row.control = a
	if second then
		local b = W:Button(holder, T.L(second[1]), second[2])
		b:SetSize(w2, 24)
		b:SetPoint("TOPLEFT", a, "TOPRIGHT", 8, 0)
		row.control2 = b
	end
	holder:SetPoint("RIGHT")
	return add(parent, row, y, help)
end

local function header(parent, y, text)
	local section = W:Section(parent, T.L(text), nil, "settings")
	section:SetHeight(section.headerHeight + 8)
	local _, n = add(parent, section, y)
	return n
end

--------------------------------------------------------------------- pages
local function buildRecording(parent)
    local n, controls = header(parent, -8, Text("Запись PvP", "PvP recording")), {}
    local function Recording(module) return ns:IsRecording(module) == true end
    local function Observing() return Recording("enemies") end
    local function CanSound()
        return ns.Sightings and ns.Sightings.CanPlayAlertSound and ns.Sightings:CanPlayAlertSound() or false
    end
    local preview
    local function RefreshState()
        for _, entry in ipairs(controls) do entry.row:SetAvailable(entry.when() == true) end
        if preview then preview:SetEnabled(CanSound()) end
    end
    parent.RefreshState = RefreshState
    local function Toggle(name, path, help, when, changed)
        local row
        row, n = toggleRow(parent, n, name, help, path, changed)
        controls[#controls + 1] = { row = row, when = when or function() return Recording() end }
        return row
    end
    local function Slider(name, path, low, high, step, help, when)
        local row
        row, n = sliderRow(parent, n, name, help, path, low, high, step)
        controls[#controls + 1] = { row = row, when = when or Observing }
        return row
    end
    local _, row
    _, n = toggleRow(parent, n, Text("Записывать PvP", "Record PvP"), "Recording help", { "enabled" }, function(value)
        ns:OnRecordingChanged(value)
        O:ReflowCurrent()
    end)
    local paused = W:SettingRow(parent, Text("Запись и оповещения приостановлены. История доступна.",
        "Recording and alerts are paused. History is available."))
    paused.label:SetPoint("RIGHT", -2, 0)
    paused.visibleWhen = function() return not Recording() end
    _, n = add(parent, paused, n)
    Toggle(Text("Встречи", "Encounters"), { "modules", "enemies" }, "Encounters help")
    Toggle(Text("Бои в мире", "World fights"), { "modules", "fights" }, "World fights help", nil,
        function(value) if not value then ns.Deaths:StopRecording() end end)
    Toggle(Text("Поля боя", "Battlegrounds"), { "modules", "battlegrounds" }, nil, nil,
        function(value) if not value then ns.Deaths:StopRecording() end end)
    Toggle(Text("Дуэли", "Duels"), { "modules", "duels" }, nil, nil,
        function(value) if not value then ns.Duels:StopRecording() end end)
    Toggle(Text("Снимок после PvP-смерти в мире", "Screenshot after a world PvP death"),
        { "alerts", "screenshotOnDeath" }, "World screenshot help", function() return Recording("fights") end)

    n = header(parent, n, Text("Источники наблюдений", "Observation sources"))
    Toggle(Text("Неймплейты противников", "Enemy nameplates"), { "sightings", "fromNameplates" }, nil, Observing)
    Toggle(Text("Выбранная цель", "Current target"), { "sightings", "fromTarget" }, nil, Observing)
    Toggle(Text("Наведение мыши", "Mouseover"), { "sightings", "fromMouseover" }, nil, Observing)
    Slider(Text("Интервал повторной встречи", "Repeat encounter interval"), { "sightings", "dedupeSeconds" },
        10, 300, 10, "Repeat encounter help")

    n = header(parent, n, Text("Наблюдение и оповещения", "Watchlist and alerts"))
    Slider(Text("Наблюдать после повторных смертей", "Watch after repeated deaths"), { "autoWatchKills" }, 0, 10, 1,
        "Auto watch help", function() return Recording("fights") end)
    Slider(Text("Интервал оповещения", "Alert interval"), { "alerts", "watchSeconds" }, 5, 120, 5, "Alert interval help")
    Slider(Text("Порог разницы уровней для встреч", "Sighting alert level cutoff"), { "alerts", "minLevelDiff" },
        -30, 0, 1, "Sighting level help")
    Toggle(Text("Предупреждать о скрытности рядом", "Warn about nearby stealth"), { "alerts", "stealthCast" },
        "Stealth alert help", Observing)
    Toggle(Text("Плашки оповещений", "On-screen alerts"), { "alerts", "banner" }, "Shared alert outputs help", Observing)
    Toggle(Text("Звуки оповещений", "Alert sounds"), { "alerts", "soundOnSighting" }, "Alert sounds help",
        function() return Observing() and CanSound() end)
    Toggle(Text("Другой звук разбойников и друидов", "Alternate sound for rogues and druids"),
        { "alerts", "stealthSound" }, "Alternate alert sound help", function()
            return Observing() and CanSound() and get({ "alerts", "soundOnSighting" })
                and ns.Sightings.HasAlternateAlertSound and ns.Sightings:HasAlternateAlertSound() or false
        end)
    row, n = buttonRow(parent, n, Text("Проверка звука", "Sound preview"), "Sound preview help",
        Text("Проиграть", "Play"), function()
            if not (ns.Sightings and ns.Sightings:PlayAlertSound(false)) then
                ns:Print(Text("Не удалось проиграть звук. Проверь настройки звука игры.",
                    "Could not play the alert sound. Check the game's sound settings."))
            end
        end, 100)
    preview = row.control

    n = header(parent, n, Text("Сообщения в чат", "Chat messages"))
    Toggle(Text("Наблюдение и скрытность", "Watchlist and stealth alerts"), { "alerts", "chat", "watched" }, nil, Observing)
    Toggle(Text("Сводка опасности при входе в зону", "Zone danger summary"), { "alerts", "chat", "zone" }, "Zone summary help")
    Toggle("You died", { "alerts", "chat", "death" }, nil, function() return Recording("fights") end)
    Toggle("You killed somebody", { "alerts", "chat", "kill" }, nil, function() return Recording("fights") end)
    Toggle("Duel results", { "alerts", "chat", "duel" }, nil, function() return Recording("duels") end)
    Toggle("Every new enemy seen", { "alerts", "chat", "sighting" }, nil, Observing)
    Toggle("Your own actions", { "alerts", "chat", "action" }, "Action chat help", function() return true end)
    RefreshState()
    return n
end

local function buildMap(parent)
    local n = header(parent, -8, Text("Карта и метки", "Map and pins"))
    local controls = {}
    local function Active() return get({ "modules", "map" }) ~= false end
    local function RefreshState()
        for _, entry in ipairs(controls) do entry.row:SetAvailable(entry.when() == true) end
    end
    parent.RefreshState = RefreshState
    local function RefreshMap()
        if ns.Map then ns.Map:Update() end
        if ns.MinimapPins then ns.MinimapPins:Update() end
    end
    local function Toggle(name, path, help, when)
        local row
        row, n = toggleRow(parent, n, name, help, path, RefreshMap)
        if when then controls[#controls + 1] = { row = row, when = when } end
        return row
    end
    local function Age(name, path, low, high, help, when)
        local row
        row, n = sliderRow(parent, n, name, help, path, low, high, 5, nil, RefreshMap)
        controls[#controls + 1] = { row = row, when = when }
    end
    Toggle(Text("Метки на карте и миникарте", "Map and minimap pins"), { "modules", "map" }, "Map master help")
    n = header(parent, n, Text("Карта мира: встречи", "World map: sightings"))
    Toggle(Text("Показывать встречи", "Show enemy sightings"), { "map", "sightings" }, nil, Active)
    Age(Text("Скрывать встречи старше", "Hide sightings older than"), { "map", "minutes" }, 10, 360,
        "Map sighting age help", function() return Active() and get({ "map", "sightings" }) end)
    n = header(parent, n, Text("Карта мира: бои", "World map: fights"))
    Toggle(Text("Показывать места боев", "Show fight locations"), { "map", "enabled" }, "Map fight pins help", Active)
    local function Fights() return Active() and get({ "map", "enabled" }) end
    Toggle(Text("Ваши смерти", "Your deaths"), { "map", "deaths" }, nil, Fights)
    Toggle(Text("Ваши добивания", "Your killing blows"), { "map", "kills" }, nil, Fights)
    n = header(parent, n, Text("Миникарта", "Minimap"))
    Toggle(Text("Показывать метки", "Show minimap blips"), { "minimap", "enabled" }, "Minimap position help", Active)
    local function Minimap() return Active() and get({ "minimap", "enabled" }) end
    Toggle(Text("Только отслеживаемые игроки", "Watched players only"), { "minimap", "watchedOnly" }, nil, Minimap)
    Toggle(Text("Оставлять отслеживаемых на краю", "Keep watched blips on the edge"),
        { "minimap", "floatOnEdge" }, "Minimap edge help", Minimap)
    Toggle(Text("Ваши смерти на миникарте", "Your deaths on the minimap"), { "minimap", "deaths" }, nil, Minimap)
    Age(Text("Скрывать метки старше", "Hide blips older than"), { "minimap", "minutes" }, 5, 120,
        "Minimap age help", Minimap)
    n = header(parent, n, Text("Координаты", "Coordinates"))
    Toggle(Text("Передавать координаты в TomTom", "Send coordinates to TomTom"), { "map", "useTomTom" }, "TomTom help")
    RefreshState()
    return n
end

local function buildWindow(parent)
	local y = -10
	local n = header(parent, y, Text("Оформление", "Appearance"))
	local _
	_, n = buttonRow(parent, n, Text("Тема и язык", "Theme and language"), "Appearance help", "Sintezza Theme",
		function() Sintezza_Theme:OpenSettings() end, 170)
	_, n = toggleRow(parent, n, Text("Сведения в подсказках игроков", "Rivals info in player tooltips"), "Unit tooltip help", { "alerts", "unitTooltip" })
	n = header(parent, n, Text("Окно и миникарта", "Window and minimap"))
	local block = Sintezza_Theme:CreateWindowOptions(parent, root.Theme, {
		inset = 0, labelRole = "body",
		windows = { { prefs = ns.WindowAppearance } },
		getMinimap = function() return not root.db.minimap.hide end,
		setMinimap = function(value)
			root.db.minimap.hide = not value
			root.Launcher:RefreshMinimap(root.db.minimap)
		end,
	})
	_, n = add(parent, block, n)

	n = header(parent, n, Text("Открытие окна", "Opening the window"))
	_, n = choiceRow(parent, n, "Open the window on",
		"Which tab the window starts on.",
		{ { 0, "Last used" }, { 9, root.Text("История PvP", "PvP history") },
		  { 10, root.Text("Неймплейты", "Nameplates") }, { 7, "PvP history: Duels" }, { 8, "Stats" } },
		{ "ui", "defaultTab" })
	_, n = buttonRow(parent, n, "Keybindings",
		"Opens the game key bindings; look for the Sintezza Rivals section.",
		"Open bindings", function()
            if Settings and type(Settings.OpenToCategory) == "function" and Settings.KEYBINDINGS_CATEGORY_ID then
				pcall(Settings.OpenToCategory, Settings.KEYBINDINGS_CATEGORY_ID)
			elseif KeyBindingFrame_LoadUI then
				pcall(KeyBindingFrame_LoadUI)
				if KeyBindingFrame then KeyBindingFrame:Show() end
			else
				ns:Print("open Game Menu, then Key Bindings, and look for Sintezza Rivals")
			end
		end)

	n = header(parent, n, Text("Панель встреч", "Encounter strip"))
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
		build = buildMap },
	{ key = "window", label = Text("Окно и миникарта", "Window and minimap"),
		title = Text("Окно и миникарта", "Window and minimap"), build = buildWindow },
	{ key = "diag", label = "Diagnostics", title = "Diagnostics",
		note = "Logging and the API probe. All off by default.", build = buildDiagnostics,
		-- the probe is a separate development add-on; without it this page has
		-- nothing to offer and the combat-log test would only produce the
		-- blocked-action popup
		devOnly = true },
}
