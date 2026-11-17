local sources = ...
local checks = 0
local captures = {}
local function check(value, message) checks = checks + 1; assert(value, message) end
local function capture(card, mode, locale)
    local result = { mode = mode, locale = locale, width = card:GetWidth(), height = card:GetHeight(),
        title = card.title:GetText(), subtitle = card.subtitle:GetText(),
        leftScore = card.scoreLeft:GetText(), rightScore = card.scoreRight:GetText(), sections = {}, rows = {}, actions = {} }
    for _, button in ipairs(card.actions.children) do
        result.actions[#result.actions + 1] = { text = button.text:GetText(), width = button:GetWidth() }
    end
    for index, section in ipairs(card.sections) do result.sections[index] = section.title:GetText() end
    for _, row in ipairs(card.rows) do
        if row:IsShown() then result.rows[#result.rows + 1] = { label = row.caption, value = row.fullText,
            x = row.point[4], y = -row.point[5], width = row:GetWidth(), height = row:GetHeight(),
            valueWidth = row.value:GetWidth(), align = row.caption == (locale == "ruRU" and "Манера боя" or "Fight patterns") and "left" or "right" } end
    end
    captures[#captures + 1] = result
end

local function fixture(locale)
    local named, frames, factoryCalls, pending = {}, {}, {}, {}
    local methods = {}
    local function frame(parent, name)
        local value = setmetatable({ parent = parent, scripts = {}, children = {}, shown = true, enabled = true }, { __index = methods })
        frames[#frames + 1] = value
        if parent and parent.children then parent.children[#parent.children + 1] = value end
        if name then named[name] = value end
        return value
    end
    function methods:SetSize(w, h) self.width, self.height = w, h end
    function methods:SetWidth(w) self.width = w end
    function methods:SetHeight(h) self.height = h end
    function methods:GetWidth() return self.width or self.parent and self.parent:GetWidth() or 680 end
    function methods:GetHeight() return self.height or 400 end
    function methods:SetPoint(...)
        self.anchorWrites = (self.anchorWrites or 0) + 1
        self.point = { ... }; self.points = self.points or {}; self.points[select(1, ...)] = { ... }
    end
    function methods:ClearAllPoints() self.point, self.points = nil, {} end
    function methods:SetAllPoints() end
    function methods:SetParent(parent) self.parent = parent end
    function methods:GetParent() return self.parent end
    function methods:SetText(text)
        self.text = tostring(text or "")
        if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
    end
    function methods:GetText() return self.text or "" end
    function methods:SetTextColor(...) self.color = { ... } end
    function methods:GetStringWidth() return #(self:GetText():gsub("[\128-\191]", "")) * 6 end
    function methods:GetStringHeight() return self.wrap and math.max(12, math.ceil(self:GetStringWidth() / math.max(1, self:GetWidth())) * 12) or 12 end
    function methods:SetWordWrap(wrap) self.wrap = wrap end
    function methods:SetScript(key, callback) self.scripts[key] = callback end
    function methods:GetScript(key) return self.scripts[key] end
    function methods:HookScript(key, callback)
        local previous = self.scripts[key]
        self.scripts[key] = function(...) if previous then previous(...) end; callback(...) end
    end
    function methods:SetShown(shown) self.shown = not not shown end
    function methods:Show() self.shown = true end
    function methods:Hide() self.shown = false end
    function methods:IsShown() return self.shown end
    function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function methods:SetEnabled(enabled) self.enabled = not not enabled end
    function methods:SetAvailable(enabled) self.available = enabled; self:SetEnabled(enabled) end
    function methods:SetExpanded(expanded) self.expanded = expanded end
    function methods:SetTexture(texture) self.texture = texture end
    function methods:SetNumber(value) self:SetText(value) end
    function methods:SetAlpha(alpha) self.alpha = alpha end
    function methods:CreateTexture() return frame(self) end
    function methods:CreateFontString() return frame(self) end
    function methods:SetVerticalScroll(value) self.offset = value end
    function methods:GetVerticalScroll() return self.offset or 0 end
    function methods:RefreshRange() end
    function methods:HasFocus() return false end
    for _, name in ipairs({ "SetFrameStrata", "SetJustifyH", "SetJustifyV", "SetMaxLines", "SetTexCoord",
        "SetColorTexture", "EnableMouse", "RegisterForDrag", "Raise", "SetNumeric", "SetMaxLetters",
        "SetAutoFocus", "SetBackdropBorderColor", "HighlightText", "ClearFocus", "SetTextInsets", "SetMultiLine",
        "SetFocus", "SetClampedToScreen", "SetMovable", "RegisterForClicks" }) do methods[name] = function() end end

    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.GetServerTime = function() return 100000 end
    env.CreateFrame = function(_, name, parent) return frame(parent, name) end
    env.C_Timer = { After = function(_, callback) pending[#pending + 1] = callback end }
    env.CLASS_ICON_TCOORDS = { ROGUE = { 0, 1, 0, 1 }, PRIEST = { 0, 1, 0, 1 } }
    local root = { locale = locale, db = { players = {}, minimap = {} } }
    root.Text = function(ru, en) return locale == "ruRU" and ru or en end
    root.Theme = {
        Font = function(_, region, size, flags, color, role) region.themeSize, region.themeRole = size, role end,
        DisclosureArrow = function(_, parent) return frame(parent) end,
        Backdrop = function() end, PaintButton = function() end, DropdownArrow = function() end,
        selection = { .2, .1, .1, .2 }, text = { 1, 1, 1 }, muted = { .7, .6, .5 },
        brass = { 1, .6, .4 }, lineSoft = { .3, .2, .1 }, danger = { 1, .1, .1 }, accentLine = { .8, .5, .3 },
    }
    root.InterfaceFonts = { ApplyFamily = function() end }
    root.ClassName = function(token) return token end
    local ns = { modules = {}, UI = {}, UIX = {}, Safe = function(value) return value end, Lower = string.lower }
    root.PvP = ns
    ns.L = function(key) return ns.LOCALE and ns.LOCALE[key] or key end
    local changed, hud, dirty = 0, 0, 0
    root.Changed = function() changed = changed + 1 end
    ns.HUD = { Update = function() hud = hud + 1 end }
    ns.UI.MarkDirty = function() dirty = dirty + 1 end
    ns.UI.Refresh = function() end
    ns.UI.CopyText = function(_, title, text) ns.copied = text end
    ns.UIX.rgb = function(class) if class == "ROGUE" then return 1, .96, .41 end; return .78, .78, .78 end
    ns.ClassRGB = ns.UIX.rgb
    ns.UIX.ago = function() return "1d" end
    ns.UIX.raceText = function(rec) return rec.raceName or "-" end
    ns.UIX.coords = function(x, y) return string.format("%.1f, %.1f", x * 100, y * 100) end
    ns.UIX.isWatched = function(key) return env.Sintezza_RivalsPvPDB.watch[key] ~= nil end
    ns.Duels = { OpponentKey = function(name) return name and name:lower() end, FindSighting = function() return "Player-1" end }
    ns.Map = { ShowSpot = function(_, id, x, y) ns.spot = { id, x, y } end, Update = function() end }
    ns.IsRecording = function(_, module)
        local settings = env.Sintezza_RivalsPvPDB.settings
        return settings.enabled and (not module or settings.modules[module] ~= false)
    end
    ns.Sightings = {
        CanPlayAlertSound = function() return ns.audioAvailable ~= false end,
        HasAlternateAlertSound = function() return ns.audioAvailable ~= false end,
        PlayAlertSound = function() ns.soundPreviews = (ns.soundPreviews or 0) + 1; return ns.audioAvailable ~= false end,
    }
    ns.OnRecordingChanged = function() end
    ns.IsDev = function() return false end
    ns.Notify, ns.Count, ns.Print = function() end, function() return 0 end, function() end
    local score = { class = "ROGUE", kills = 1, deaths = 2, last = 90000 }
    root.PvPSource = { PlayerScore = function() return score end, RecapKiller = function(_, rec) return rec.killer end }
    local W = {}
    function W:Label(parent, text) local label = frame(parent); label:SetText(text); return label end
    function W:SettingRow(parent, text, height)
        local row = frame(parent); row:SetHeight(height or 30); row.label = self:Label(row, text); return row
    end
    function W:Button(parent, text, callback)
        local button = frame(parent); button.text = self:Label(button, text); button:SetHeight(22)
        button:SetScript("OnClick", callback); return button
    end
    function W:Toggle(parent, text, get, set)
        factoryCalls.Toggle = (factoryCalls.Toggle or 0) + 1
        local row = self:SettingRow(parent, text, 28); row.getValue, row.setValue = get, set
        row.Refresh = function(self) self.value = get() end
        row:SetScript("OnClick", function() set(not get()) end); row:Refresh(); return row
    end
    function W:SliderRow(parent, text, low, high, step, get, set, suffix)
        factoryCalls.SliderRow = (factoryCalls.SliderRow or 0) + 1
        local row = self:SettingRow(parent, text); row.getValue, row.setValue, row.suffix = get, set, suffix
        row.slider, row.edit = frame(row), frame(row)
        row.SetRange = function(self, low, high) self.low, self.high = low, high end
        row.Refresh = function(self) self.value = get() end; row:Refresh(); return row
    end
    function W:ChoiceRow(parent, text, choices, get, set)
        factoryCalls.ChoiceRow = (factoryCalls.ChoiceRow or 0) + 1
        local row = self:SettingRow(parent, text); row.getValue, row.setValue = get, set
        row.button = self:Button(row, '', function() end)
        row.Refresh = function(self) self.value = get() end; row:Refresh(); return row
    end
    function W:Help(row, text) row.helpText = text end
    function W:Card(parent, title)
        local card = frame(parent); card.title = self:Label(card, title); card.card = true; return card
    end
    function W:Surface(parent) return frame(parent) end
    function W:ColorRow(parent, text, get, set)
        local row = self:SettingRow(parent, text); row.Refresh = function(self) self.value = get() end
        row.getValue, row.setValue = get, set; row:Refresh(); return row
    end
    function W:EditBox(parent, placeholder)
        local box = frame(parent); box.placeholder = self:Label(box, placeholder or '')
        box:SetScript('OnTextChanged', function(self) self.placeholder:SetShown(self:GetText() == '') end)
        return box
    end
    function W:CloseButton(parent, callback) return self:Button(parent, '', callback) end
    function W:EnableSettingsTab() end
    function W:CloseColorPicker() end
    function W:Section(parent, text)
        local row = frame(parent); row.title = self:Label(row, text); row.headerHeight = 25
        row.LayoutTitleRule = function() end; return row
    end
    function W:SettingsDivider() end
    function W:Tooltip(owner, title, text, anchor) ns.tooltip, ns.tooltipAnchor = text, anchor end
    function W:Segmented(parent, labels, values, get, set)
        local tabs = frame(parent); tabs.labels, tabs.values, tabs.getValue, tabs.setValue = labels, values, get, set
        tabs:SetHeight(32); tabs.Refresh = function() end; ns.tabs = tabs; return tabs
    end
    function W:ScrollFrame(parent)
        local scroll = frame(parent); scroll:SetHeight(420); local body, bar = frame(scroll), frame(parent)
        ns.testScroll, ns.testBar = scroll, bar
        return scroll, body, bar
    end
    env.Sintezza_Theme = {
        CreateWidgets = function() return W end, HideTooltip = function() end,
        TrackAppearance = function(_, owner, key, callback) owner.appearance = owner.appearance or {}; owner.appearance[key] = callback end,
        Tint = function(_, owner) owner.themeTint = true end,
        icons = { Sintezza_Rivals = 'icon', RivalsMarker = 'diamond' },
        GetFactionCrest = function(_, faction) return faction end,
        CreateWindowOptions = function(_, parent, appearance, options)
            factoryCalls.WindowOptions = true; factoryCalls.WindowOptionsOptions = options
            local row = frame(parent); row:SetHeight(170); return row
        end,
    }
    ns.Theme = { L = ns.L, Tip = function(widget, title, help) widget.helpText = ns.L(help) end,
        C = { fg = { 1, 1, 1 }, muted = { .7, .6, .5 }, accent2 = { 1, .6, .4 }, red = { 1, .1, .1 } } }
    ns.Theme.Window = function(options)
        local f = frame(nil, options.name); f:SetSize(options.width, options.height)
        f.windowOptions = options
        f.header, f.footer, f.content = frame(f), frame(f), frame(f)
        f.title, f.subtitle, f.closeButton = frame(f.header), frame(f.header), frame(f.header)
        f:SetScript("OnDragStart", function() end); f:SetScript("OnDragStop", function() end)
        return f
    end
    local db = { sightings = {}, deaths = {}, watch = {}, ignore = {}, nemesis = {}, duels = {}, settings = {
        enabled = true, modules = {}, sightings = { dedupeSeconds = 60 },
            alerts = { chat = {}, watchSeconds = 20, minLevelDiff = -5, soundOnSighting = true, stealthSound = true, banner = true }, autoWatchKills = 0,
        map = { minutes = 180 }, minimap = { minutes = 30 }, hud = {}, ui = { defaultTab = 0 },
    } }
    env.Sintezza_RivalsPvPDB = db
    local function load(path)
        local chunk, err = loadstring(assert(sources[path], path), path); assert(chunk, err)
        setfenv(chunk, env)("Sintezza_Rivals", root)
    end
    load("PvP/Core/Locales.lua")
    load("PvP/Modules/Watchlist.lua")
    load("PvP/Modules/Deaths.lua")
    load("PvPIntegration.lua")
    for index = 1, 30 do
        local key, value = debug.getupvalue(root.ConnectPvP, index)
        if not key then break end
        if key == "Source" then root.PvPSource.BattlegroundPlayerScore = value.BattlegroundPlayerScore; break end
    end
    load("PvP/UI/Card.lua")
    return { root = root, ns = ns, db = db, load = load, named = named, frame = frame, score = score, env = env,
        frames = frames, calls = factoryCalls, counts = function() return changed, hud, dirty end,
        pendingCount = function() return #pending end,
        flushAfter = function() local batch = pending; pending = {}; for _, callback in ipairs(batch) do callback() end end }
end

for _, locale in ipairs({ "enUS", "ruRU" }) do
    local f = fixture(locale)
    local db, ns = f.db, f.ns
    db.sightings["Player-1"] = { guid = "Player-1", name = "First Enemy", class = "ROGUE", level = 44,
        raceName = "Undead", faction = "Horde", firstSeen = 80000, lastSeen = 90000,
        lastMapID = 42, lastX = .477, lastY = .707, count = 4, hours = { [19] = 2, [18] = 2 }, lastZone = "Town", lastSource = "nameplate" }
    for index = 1, 2 do db.deaths[index] = { ts = index * 100, killer = { name = "First Enemy", guid = "Player-1" },
        confidence = "high", crowd = 1, attackers = { { guid = "Player-1", name = "First Enemy", damage = 100 } } } end
    ns.UI:ShowDetail("First Enemy", "Player-1", false)
    local card = f.named.Sintezza_RivalsPvPDetail
    card.title:SetTextColor(0, 0, 0); card.title.appearance.state(card.title)
    check(card.title.color[1] == 1 and card.title.color[2] == .96, 'theme repaint must preserve class-colored card titles')
    check(card:GetWidth() == 560 and card:GetHeight() < 420, "all-visible card is not compact")
    check(not card.detailsToggle and not card.details, "card should show all fields without a disclosure")
    check(#card.actions.children == 3, "removed marker action still exists")
    check(card.title:GetText() == "First Enemy" and card.title.color[1] == 1, "title identity/class color")
    check(card.plain:find("18:00–18:59", 1, true), "hour tie should have a stable earlier-hour result")
    check(card.plain:find(ns.L("Fight patterns"), 1, true), "copy omitted visible details")
    capture(card, "world", locale)
    local pattern = card.rows[#card.rows]
    check(pattern.helpText:find(ns.Deaths:PatternHelp("Lone wolf"), 1, true), "pattern tooltip omitted qualification rule")
    card.ignoreBtn:GetScript("OnClick")()
    check(db.ignore["Player-1"] and pattern:IsShown(), "ignore should preserve visible details")
    check(#db.deaths == 2 and db.sightings["Player-1"].count == 4, "ignore erased recorded history")
    local changed, hud = f.counts()
    check(changed > 0 and hud > 0, "ignore did not immediately refresh markers and HUD")
    card.ignoreBtn:GetScript("OnClick")()
    check(not db.ignore["Player-1"], "unignore did not restore normal state")
    card.actions.children[3]:GetScript("OnClick")()
    check(ns.copied == card.plain, "copy action omitted detail text")
    ns.UI:ShowDetail("Unknown", false, false)
    check(not card.ignoreBtn.enabled, "unknown player action/state leaked")
    db.duels = { { opponent = "First Enemy", won = true, ts = 100, seconds = 30, class = "ROGUE" },
        { opponent = "First Enemy", won = false, ts = 200, seconds = 40 },
        { opponent = "Other Enemy", won = true, ts = 300 } }
    ns.UI:ShowDetail("First Enemy", "Player-1", true)
    check(card.scoreLeft:GetText():find("1", 1, true) and card.scoreRight:GetText():find("1", 1, true), "duel score crossed opponent boundaries")
    check(card.plain:find(ns.L("Average duration"), 1, true) and card.plain:find(ns.L("Longest duel"), 1, true), "duel lengths should use separate readable fields")
    capture(card, "duel", locale)
    local link
    for _, row in ipairs(card.rows) do if row.mapSighting then link = row.mapLink end end
    check(link and link:IsShown(), "duel sighting shortcut was lost with the ellipsis menu")
    link:GetScript("OnClick")()
    check(ns.spot[1] == 42, "sighting link did not open the recorded map")

    local match = { name = "Warsong Gulch", completed = true, time = 500, fights = {
        { guid = "Player-1", name = "First Enemy", class = "ROGUE", result = "win", time = 510 },
        { guid = "Player-1", name = "First Enemy", result = "loss", damage = 200, time = 520,
            combatAttackers = { { guid = "Player-1", name = "First Enemy", damage = 9999 } } },
        { result = "incoming", time = 530, players = { { guid = "Player-1", name = "First Enemy", damage = 500 } } },
        { guid = "Player-2", name = "Other Enemy", result = "loss", time = 540, damage = 1000 },
    } }
    local bg = f.root.PvPSource:BattlegroundPlayerScore(match, "First Enemy", "Player-1")
    check(bg.kills == 1 and bg.deaths == 1 and bg.fights == 3 and bg.last == 530, "battleground opponent totals")
    check(bg.damage == 200 and bg.recapCount == 1, "battleground recap damage mixed in full-fight snapshots")
    ns.UI:ShowDetail("First Enemy", "Player-1", false, { kind = "battleground", match = match })
    check(card.plain:find("Warsong Gulch", 1, true) and not card.plain:find("18:00", 1, true), "battleground card contains world sightings")
    local bgDeaths = card.scoreLeft:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^(%d+)")
    check(tonumber(bgDeaths) == 1, "battleground score contains world deaths")
    capture(card, "battleground", locale)
    card.ignoreBtn:GetScript("OnClick")()
    check(card.subject.context.match == match and card.plain:find("Warsong Gulch", 1, true), "battleground context lost after ignore")
    card.ignoreBtn:GetScript("OnClick")()

    db.deaths = {}
    for index = 1, 2 do db.deaths[index] = { ts = index * 100, killer = { name = "First Enemy" }, confidence = "high", crowd = 1 } end
    check(ns.Deaths:KnownFor("First Enemy")[1] == "Lone wolf", "canonical pattern changed")
    local labels = {}
    for index = 1, 50 do
        local name = "Enemy " .. index
        local text = ns.Deaths:PatternLabel(name, "Lone wolf")
        labels[text] = true
        check(text == ns.Deaths:PatternLabel(name, "Lone wolf"), "pattern rerolled on reopening")
    end
    local distinct = 0; for _ in pairs(labels) do distinct = distinct + 1 end
    check(distinct >= 4, "identical fight patterns should support varied wording")
    db.deaths[2].confidence = "low"
    check(ns.Deaths:KnownFor("First Enemy") == nil, "one qualified death should not grant a lone-wolf description")

    f.load("PvP/Options/Options.lua")
    f.load("PvP/Options/Pages.lua")
    ns.Options:Open()
    check(ns.testBar.points.TOPLEFT[2] == ns.testScroll and ns.testBar.points.BOTTOMLEFT[2] == ns.testScroll,
        "settings scrollbar has no anchors")
    check(#ns.tabs.labels == 3, "settings tabs/dev-page filtering")
    local recording
    for _, row in ipairs(f.frames) do
        if row.label and row.label:GetText() == f.root.Text("Записывать PvP", "Record PvP") then recording = row end
        check(not row.label or row.label:GetText() ~= f.root.Text("Дополнительно", "Advanced"), "advanced settings remain hidden")
    end
    check(recording and f.calls.Toggle >= 20 and f.calls.SliderRow >= 4, "settings did not use shared controls")
    recording:GetScript("OnClick")()
    check(not db.settings.enabled, "recording setting was not persisted")
    local previewButton, actionChat
    for _, row in ipairs(f.frames) do
        if row.label and row.label:GetText() == f.root.Text('Проверка звука', 'Sound preview') then previewButton = row.control end
        if row.label and row.label:GetText() == ns.L('Your own actions') then actionChat = row end
    end
    check(previewButton and previewButton.enabled and actionChat.available, 'sound preview and action messages should work while recording is paused')
    previewButton:GetScript('OnClick')()
    check(ns.soundPreviews == 1, 'sound preview did not reach its runtime provider')
    local dependent
    for _, row in ipairs(f.frames) do if row.label and row.label:GetText() == f.root.Text("Встречи", "Encounters") then dependent = row end end
    check(dependent and dependent.available == false, "recording pause did not disable dependent settings")
    recording:GetScript("OnClick")()
    check(dependent.available == true, "recording resume did not restore dependent settings")
    ns.Options:Open("markers")
    local deaths, fights
    for _, row in ipairs(f.frames) do
        if row.label and row.label:GetText() == f.root.Text('Ваши смерти', 'Your deaths') then deaths = row end
        if row.label and row.label:GetText() == f.root.Text('Показывать места боев', 'Show fight locations') then fights = row end
    end
    check(deaths and not deaths.available, 'fight-type controls should be inactive when fight pins are off')
    fights:GetScript('OnClick')()
    check(deaths.available, 'enabling fight pins should activate the saved per-type choices')
    ns.Options:Open("window")
    check(f.calls.WindowOptions and f.calls.ChoiceRow > 0, "window options are not shared")
    check(f.calls.WindowOptionsOptions.inset == 0 and f.calls.WindowOptionsOptions.labelRole == 'body',
        'window option labels must use the same inset and font role as the other settings')
    local bindings
    f.env.Settings = { KEYBINDINGS_CATEGORY_ID = 'bindings', OpenToCategory = function(id) bindings = id end }
    for _, row in ipairs(f.frames) do
        if row.label and row.label:GetText() == ns.L('Keybindings') then row.control:GetScript('OnClick')() end
    end
    check(bindings == 'bindings', 'bindings action must call the available Settings API without requiring a redundant panel method')

    local root = f.root
    root.db.marks, root.db.colors, root.db.markerLayouts = {}, {}, {}
    root.Kinds = { killer = { label = "Killers" }, attacker = { label = "Attackers" },
        defeated = { label = "Defeated" }, manual = { label = "Manual" } }
    root.MarkChoices = { { "off", "No marker" }, { "swords", "Brass swords" }, { "edge", "Border" }, { "name", "Name color" } }
    root.MarkerAnchors = { { "right", "Right" }, { "left", "Left" } }
    root.Color = function() return { 1, .5, .3 } end
    root.MarkStyle = function(kind) return root.db.marks[kind] or "swords" end
    root.IsMarkerIcon = function(style) return style == "swords" end
    root.MarkerLayout = function(kind)
        if not root.db.markerLayouts[kind] then root.db.markerLayouts[kind] = { anchor = "right", size = 150, opacity = 95, x = 0, y = 0,
            scaling = { enabled = true, count = 4, tiers = { { kills = 5, bonus = 10 }, { kills = 10, bonus = 15 },
                { kills = 25, bonus = 25 }, { kills = 50, bonus = 50 } } } } end
        return root.db.markerLayouts[kind]
    end
    root.MarkerScaling = function(kind) return root.MarkerLayout(kind).scaling end
    root.MarkerScalingAvailable = function(kind, style) return (kind == "killer" or kind == "attacker" or kind == "defeated") and style == "swords" end
    root.MarkerSizePercent = function() return 188, 3 end
    root.SetMarkerLayout = function(kind, key, value) root.MarkerLayout(kind)[key] = value end
    root.SetMarkerScaling = function(kind, key, value) root.MarkerScaling(kind)[key] = value end
    root.SetMarkerThreshold = function(kind, index, field, value) root.MarkerScaling(kind).tiers[index][field] = value; return true end
    root.MarkTarget = function() end
    root.CreateMarkerPreview = function(parent)
        local sample = f.frame(parent); sample.RefreshMarker = function(self, style) self.style = style end; return sample
    end
    f.load("Options.lua")
    local editor = f.frame(); editor:SetSize(1000, 1)
    local manual = { anchor = 'left', size = 177 }
    root.db.markerLayouts.manual = manual
    root.BuildMarkerControls(editor, -12)
    local appearance, preview, scaling
    for _, child in ipairs(editor.children) do
        if child.title then
            if child.title:GetText() == root.Text("Оформление метки", "Marker appearance") then appearance = child
            elseif child.title:GetText() == root.Text('Предпросмотр', 'Preview') then preview = child end
        end
        if child.LayoutColumns then scaling = child end
        check(not child.card, 'nameplate controls should not use large filled cards')
        check(not child.text or child.text:GetText() ~= root.Text('Отметить цель', 'Mark target'), 'manual action should be hidden')
    end
    check(#ns.tabs.labels == 3 and ns.tabs.values[3] == 'defeated', 'manual category should be hidden')
    check(root.db.markerLayouts.manual == manual, 'hidden manual settings should be retained')
    check(appearance and preview and appearance:GetWidth() + preview:GetWidth() + 16 == 820,
        "nameplate columns should use bounded compact width")
    check(scaling and scaling:GetWidth() == 820, 'scaling sliders should use the width below both columns')
    local thresholdSliders = {}
    for _, child in ipairs(scaling.children) do if child.slider then thresholdSliders[#thresholdSliders + 1] = child end end
    check(#thresholdSliders == 8 and thresholdSliders[1]:GetWidth() == thresholdSliders[2]:GetWidth(),
        'thresholds and bonuses should be paired shared slider rows')
    local wideHeight = editor:GetHeight()
    check(wideHeight < 570, 'wide nameplate editor should remain compact')
    editor:SetWidth(680); editor:GetScript("OnSizeChanged")(editor, 680)
    check(appearance:GetWidth() == 648 and preview:GetWidth() == 648 and editor:GetHeight() > wideHeight,
        "narrow nameplate columns should stack without losing controls")
    local style, offset
    for _, row in ipairs(appearance.children) do
        if row.label and row.label:GetText() == root.Text("Метка", "Marker") then style = row end
        if row.label and row.label:GetText() == root.Text("Смещение X", "X offset") then offset = row end
    end
    style.setValue("off"); editor:RefreshMarkers()
    check(not offset:IsShown(), "non-icon markers should not expose icon offsets")
    check(thresholdSliders[1]:IsShown(), 'threshold configuration should remain visible before an icon is selected')
    style.setValue("swords"); editor:RefreshMarkers()
    check(offset:IsShown(), "icon offsets did not return")
    for _, kind in ipairs({ 'attacker', 'defeated' }) do
        ns.tabs.setValue(kind)
        check(thresholdSliders[1]:IsShown(), 'scaling should be available for ' .. kind)
        thresholdSliders[2].setValue(17)
        check(root.MarkerScaling(kind).tiers[1].bonus == 17, 'slider edit did not persist for ' .. kind)
    end
    root.SetMarkerScaling('defeated', 'count', 3); editor:RefreshMarkers()
    check(not thresholdSliders[7]:IsShown() and root.MarkerScaling('defeated').tiers[4].kills == 50,
        'switching to three thresholds should hide the fourth pair and preserve its values')
    local writes = offset.anchorWrites
    thresholdSliders[2].setValue(18); editor:RefreshMarkers()
    check(offset.anchorWrites == writes, 'value changes must not rebuild the control layout during dragging')
    offset:ClearAllPoints()
    offset.IsShown = function() return false end
    editor:SetWidth(700); editor:GetScript('OnSizeChanged')(editor, 700)
    check(offset.points.TOPLEFT ~= nil, 'layout must use desired visibility even while native shown state is unresolved')
    offset.IsShown = nil
    editor:GetScript('OnShow')(editor)
    check(f.pendingCount() > 0, 'opening the panel should schedule one post-layout refresh')
    f.flushAfter()
    check(offset.points.TOPLEFT ~= nil, 'deferred first-show refresh lost visible controls')

    f.load('PvP/Theme/Widgets.lua')
    local changes = 0
    local search = ns.Theme.SearchBox(f.frame(), 200, function() changes = changes + 1 end, 'Name')
    search:SetText('Enemy')
    check(search.hint == search.placeholder and search.clearButton:IsShown() and changes == 1,
        'search box should reuse the shared input and update its existing clear behavior')
    search.clearButton:GetScript('OnClick')()
    check(search:GetText() == '' and not search.clearButton:IsShown() and search.placeholder:IsShown(), 'shared search clear failed')

    local X = ns.UIX
    X.now, X.ago, X.ROW_H, X.rows, X.data = function() return 100000 end, function() return "1d" end, 24, {}, {}
    X.TABS, X.selected, X.numRows, X.list = { { cols = { { "Result", 100, "LEFT" }, { "Name", 200, "LEFT" } } } }, 1, 1, f.frame()
    local row = f.frame(); row.cells = { f.frame(), f.frame() }
    for _, field in ipairs({ "stripe", "band", "mark", "cls", "classBorder", "groupArrow", "participantMarker" }) do row[field] = f.frame(row) end
    X.rows[1] = row
    X.data[1] = { kind = "fight", cells = { "Earlier", "First Enemy" }, class = "ROGUE", markCol = 2,
        indent = 16, participant = true, tone = "red" }
    f.load("PvP/UI/List.lua")
    X.renderVisible()
    check(row.cells[2].color[2] == .96 and row.cells[1].color[2] == .1, "event color overrode nested class color")
    X.data[1].class = nil
    X.renderVisible()
    check(row.cells[2].color[1] == .95, "unknown class inherited event tone")

    ns.WindowAppearance = {}
    f.env.UIParent = f.frame()
    f.env.C_Timer = { NewTimer = function() return { Cancel = function() end } end }
    f.root.Theme.Font = function(_, region) region.themeFont = true end
    ns.Theme.Font = function(parent) local region = f.frame(parent); region.themeFont = true; return region end
    ns.Theme.Solid = function(parent) return f.frame(parent) end
    ns.Theme.Border = function() end
    f.load('PvP/UI/Popups.lua')
    ns.UI:CopyText('Copy test', 'Saved card text')
    local copy = f.named.Sintezza_RivalsPvPCopy
    check(copy.edit.themeFont and copy.windowOptions.windowAppearance == ns.WindowAppearance,
        'copy dialog must use shared fonts and window preferences')
    check(copy.edit:GetText() == 'Saved card text' and ns.testBar.points.TOPLEFT[2] == copy.scroll,
        'copy text or its shared scrollbar was lost')
    ns.UI:Banner('Enemy', 'Nearby', 'ROGUE')
    local banner = f.named.Sintezza_RivalsPvPBanner
    check(banner.title.themeFont and banner.tag.themeFont and banner.sub.themeFont, 'banner retained native fixed fonts')
    banner.title:SetTextColor(0, 0, 0); banner.title.appearance.state(banner.title)
    check(banner.title.color[2] == .96, 'theme repaint should preserve banner class color')
    f.load('PvP/Modules/HUD.lua')
    db.settings.hud.show = true
    ns.HUD:Update()
    f.named.Sintezza_RivalsPvPHUD:GetScript('OnEnter')(f.named.Sintezza_RivalsPvPHUD)
    check(ns.tooltipAnchor == 'cursor', 'HUD tooltip did not use the shared cursor mode')
    ns.Ago = function() return '1d' end
    f.load('PvP/Map/Map.lua')
    local pin = f.frame()
    pin.fights = { { win = true, time = 100, who = { name = 'Enemy' } }, { win = false, time = 200 } }
    f.env.Sintezza_RivalsPvPPinMixin.OnMouseEnter(pin)
    check(ns.tooltipAnchor == 'cursor' and ns.tooltip:find('Enemy', 1, true), 'map fight tooltip did not use the shared provider')
end

return checks, captures
