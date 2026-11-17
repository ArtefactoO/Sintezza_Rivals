local _, ns = ...
local T = ns.Theme
local widgets = Sintezza_Theme:CreateWidgets(T)
local Text = ns.Text
local function Frame(parent, fill, border)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    T:Backdrop(frame, fill, border)
    return frame
end

local function Label(parent, value, size, color, outline)
    local text = parent:CreateFontString(nil, "OVERLAY")
    T:Font(text, size, outline, color)
    text:SetText(value)
    return text
end

local function Button(parent, title, width, callback)
    local button = widgets:Button(parent, title, callback)
    button:SetSize(width, 30)
    button.label = button.text
    function button:Refresh() T:PaintButton(self, self.selected == true) end
    button:Refresh()
    return button
end

local kinds = { "killer", "attacker", "defeated" }
local markerPanels = setmetatable({}, { __mode = "k" })
local journal, journalOffset = nil, 0
local historyTitle = Text("История PvP", "PvP history")

local function MakeWindow(name, title, width, height)
    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    frame:Hide()
    frame:SetSize(width, height)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    T:WindowSurface(frame)
    local header = widgets:WindowHeader(frame, {
        icon = Sintezza_Theme.icons.Sintezza_Rivals,
        title = title,
    })
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        local prefs = ns.PvP and ns.PvP.WindowAppearance
        if prefs and prefs:CanMove() then frame:StartMoving() end
    end)
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    frame:HookScript("OnHide", function() frame:StopMovingOrSizing() end)
    table.insert(UISpecialFrames, name)
    return frame
end

local function Show(frame)
    local prefs = ns.PvP and ns.PvP.WindowAppearance
    if prefs then prefs:Bind(frame, { resize = {
        maxWidth = 1150, maxHeight = 900,
    } }) end
    frame:Show()
    frame:Raise()
end

local function Select(owner, choices, current, commit)
    local entries = {}
    for index, choice in ipairs(choices) do
        entries[index] = { value = choice[1], label = choice[2] }
    end
    T:OpenPicker(owner, entries, current, commit)
end

local function ChoiceLabel(choices, value)
    for _, choice in ipairs(choices) do
        if choice[1] == value then return choice[2] end
    end
    return ""
end

function ns.RefreshOptions()
    for panel in pairs(markerPanels) do panel:RefreshMarkers() end
end

local function BuildThresholdPanel(frame, getKind)
    local rules = CreateFrame("Frame", nil, frame)
    local heading = widgets:Section(rules, "", nil, "settings")
    heading:SetPoint("TOPLEFT")
    heading:SetHeight(heading.headerHeight)
    heading.title:SetWordWrap(false)
    local toggle = widgets:Toggle(rules, Text("Включить", "Enable"),
        function() return ns.MarkerScaling(getKind()).enabled end,
        function(value) ns.SetMarkerScaling(getKind(), "enabled", value) end)
    toggle:SetSize(104, 25)
    toggle:SetPoint("TOPRIGHT", 0, -2)
    local count = widgets:ChoiceRow(rules, Text("Порогов", "Thresholds"), { [3] = "3", [4] = "4" },
        function() return ns.MarkerScaling(getKind()).count end,
        function(value) ns.SetMarkerScaling(getKind(), "count", value) end, { [3] = 1, [4] = 2 })
    count:SetSize(150, 28)
    count.button:SetWidth(64)
    local unavailable = widgets:Label(rules,
        Text("Прибавки работают только с метками-иконками.", "Size bonuses apply to icon markers."), 11, T.muted)
    unavailable:SetPoint("TOPLEFT", 0, -32)
    unavailable:SetPoint("TOPRIGHT", 0, -32)
    unavailable:SetWordWrap(true)
    local rows, available = {}, false
    for index = 1, 4 do
        local tierIndex = index
        local threshold = widgets:SliderRow(rules, Text("Порог %d", "Threshold %d"):format(index), 1, 999, 1,
            function() return ns.MarkerScaling(getKind()).tiers[tierIndex].kills end,
            function(value) ns.SetMarkerThreshold(getKind(), tierIndex, "kills", value) end)
        local bonus = widgets:SliderRow(rules, Text("Прибавка", "Bonus"), 0, 200, 1,
            function() return ns.MarkerScaling(getKind()).tiers[tierIndex].bonus end,
            function(value) ns.SetMarkerThreshold(getKind(), tierIndex, "bonus", value) end, "%")
        rows[index] = { threshold = threshold, bonus = bonus }
    end
    function rules:LayoutColumns(width)
        local paired = width >= 580
        heading:SetPoint("TOPRIGHT", paired and -278 or -116, 0)
        heading:LayoutTitleRule()
        count:ClearAllPoints()
        if paired then count:SetPoint("TOPRIGHT", toggle, "TOPLEFT", -12, 0)
        else count:SetPoint("TOPLEFT", 0, -30) end
        local y = paired and 32 or 62
        unavailable:ClearAllPoints()
        unavailable:SetPoint("TOPLEFT", 0, -y)
        unavailable:SetPoint("TOPRIGHT", 0, -y)
        if not available then y = y + 24 end
        local columnWidth = paired and (width - 18) / 2 or width
        for index, row in ipairs(rows) do
            if index <= ns.MarkerScaling(getKind()).count then
                row.threshold:ClearAllPoints()
                row.bonus:ClearAllPoints()
                row.threshold:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
                row.threshold:SetWidth(columnWidth)
                row.bonus:SetPoint("TOPLEFT", self, "TOPLEFT", paired and columnWidth + 18 or 0,
                    -(paired and y or y + row.threshold:GetHeight() + 2))
                row.bonus:SetWidth(columnWidth)
                y = y + (paired and math.max(row.threshold:GetHeight(), row.bonus:GetHeight())
                    or row.threshold:GetHeight() + row.bonus:GetHeight() + 2) + 2
            end
        end
        self:SetHeight(y + 4)
    end
    function rules:Refresh(kind, style, base)
        available = ns.MarkerScalingAvailable(kind, style)
        local scaling = ns.MarkerScaling(kind)
        local metric = kind == "attacker" and Text("Масштаб по эпизодам урона", "Scale by damage episodes")
            or kind == "defeated" and Text("Масштаб по добиваниям", "Scale by kills")
            or Text("Масштаб по смертям", "Scale by deaths")
        heading.title:SetText(metric)
        local help = Text("Применяется прибавка самого высокого достигнутого порога. Прибавки не складываются.",
            "The highest reached threshold supplies the bonus. Bonuses do not stack.")
        help = help .. "\n\n" .. Text("При редактировании соседние значения изменяются только для сохранения порядка: пороги растут, прибавки не уменьшаются. Точное значение можно ввести в поле справа.",
            "Edits adjust neighboring values only to preserve order: thresholds increase and bonuses never decrease. Enter an exact value in the field on the right.")
        if kind == "attacker" then
            help = help .. "\n\n" .. Text("Счетчик: сохраненные эпизоды, где игрок нанес вам урон. Сводка смерти и полный снимок одного боя считаются одним эпизодом, если у них есть общий идентификатор боя.",
                "Counts saved episodes where this player damaged you. A death recap and full snapshot count once when they share a combat identifier.")
        elseif kind == "defeated" then
            help = help .. "\n\n" .. Text("Счетчик: ваши подтвержденные добивания этого игрока.",
                "Counts your confirmed killing blows against this player.")
        else
            help = help .. "\n\n" .. Text("Счетчик: сколько раз этот игрок убил вас.",
                "Counts how often this player killed you.")
        end
        widgets:Help(heading, help, heading.title)
        toggle:Show()
        count:Show()
        unavailable:SetShown(not available)
        toggle:Refresh(false)
        count:Refresh()
        for index, row in ipairs(rows) do
            local shown = index <= scaling.count
            row.threshold:SetShown(shown)
            row.bonus:SetShown(shown)
            row.bonus.labelText = Text("Прибавка · итог %.0f%%", "Bonus · final %.0f%%"):format(base * (1 + scaling.tiers[index].bonus / 100))
            row.bonus.label:SetText(row.bonus.labelText)
            row.threshold:Refresh()
            row.bonus:Refresh()
        end
    end
    return rules
end

function ns.BuildMarkerControls(frame, top)
    local kind = kinds[1]
    local labels = { Text("Убийцы", "Killers"), Text("Нападавшие", "Attackers"),
        Text("Побежденные", "Defeated") }
    local color
    local category = widgets:Segmented(frame, labels, kinds, function() return kind end, function(value)
        if color then widgets:CloseColorPicker(color) end
        kind = value
        frame:RefreshMarkers()
    end, true)
    category:SetPoint("TOPLEFT", 16, top)
    category:SetPoint("TOPRIGHT", -16, top)

    local controls = widgets:Section(frame, Text("Оформление метки", "Marker appearance"), nil, "settings")
    local preview = widgets:Section(frame, Text("Предпросмотр", "Preview"), nil, "settings")
    local ui = ns.PvP and Sintezza_RivalsPvPDB.settings.ui
    local enabled = widgets:Toggle(controls, Text("Показывать метки", "Show markers"),
        function() return not ui or ui.showMarkers ~= false end, function(value)
            if ui then ui.showMarkers = value; ns.Changed() end
        end)
    enabled:SetSize(190, 25)
    enabled:SetPoint("TOPRIGHT", 0, -1)
    local layoutControlsRule = controls.LayoutTitleRule
    function controls:LayoutTitleRule(width)
        layoutControlsRule(self, (width or self:GetWidth()) - enabled:GetWidth() - 12)
    end
    widgets:Help(enabled, Text("Общий переключатель всех меток Rivals на неймплейтах. Не меняет выбранное оформление категорий.",
        "Controls all Rivals nameplate markers. Preserves each category's appearance."))

    local rows = {}
    local function Add(row, help)
        row.markerVisible = true
        rows[#rows + 1] = row
        if help then widgets:Help(row, help) end
        return row
    end
    local styles, order = {}, {}
    for index, entry in ipairs(ns.MarkChoices) do styles[entry[1]], order[entry[1]] = entry[2], index end
    Add(widgets:ChoiceRow(controls, Text("Метка", "Marker"), styles, function() return ns.MarkStyle(kind) end,
        function(value) widgets:CloseColorPicker(color); ns.db.marks[kind] = value; ns.Changed() end, order),
        Text("Иконки можно перемещать относительно полосы. Окантовка выделяет полосу здоровья, цвет имени меняет поддерживаемый текст имени.",
            "Icons can be positioned around the bar. Border outlines the health bar; Name color recolors supported name text."))
    color = Add(widgets:ColorRow(controls, Text("Цвет", "Color"), function()
        local current = ns.MarkStyle(kind)
        local stock = current == "swords" or current == "skull"
        return stock and (ns.MarkerLayout(kind).iconColor or { 1, 1, 1 }) or ns.Color(kind)
    end, function(r, g, b)
        local current = ns.MarkStyle(kind)
        if current == "swords" or current == "skull" then ns.SetMarkerLayout(kind, "iconColor", { r, g, b })
        else ns.db.colors[kind] = { r, g, b }; ns.Changed() end
    end))
    local anchors, anchorOrder = {}, {}
    for index, entry in ipairs(ns.MarkerAnchors) do anchors[entry[1]], anchorOrder[entry[1]] = entry[2], index end
    local anchor = Add(widgets:ChoiceRow(controls, Text("Положение", "Position"), anchors,
        function() return ns.MarkerLayout(kind).anchor end,
        function(value) ns.SetMarkerLayout(kind, "anchor", value) end, anchorOrder))
    local sliders = {}
    local fields = {
        { "size", Text("Базовый размер", "Base size"), 50, 250, 5, "%" },
        { "opacity", Text("Непрозрачность", "Opacity"), 10, 100, 5, "%" },
        { "x", Text("Смещение X", "X offset"), -32, 32, 1 },
        { "y", Text("Смещение Y", "Y offset"), -24, 24, 1 },
    }
    for _, field in ipairs(fields) do
        local key, label, low, high, step, suffix = unpack(field)
        sliders[key] = Add(widgets:SliderRow(controls, label, low, high, step,
            function() return ns.MarkerLayout(kind)[key] end,
            function(value) ns.SetMarkerLayout(kind, key, value) end, suffix))
    end
    widgets:Help(sliders.size, Text("Размер до прибавки по порогам. Итог виден в предпросмотре.",
        "The size before threshold bonuses. The preview shows the final size."))
    widgets:Help(sliders.x, Text("Горизонтальное смещение от выбранной стороны полосы здоровья.",
        "Horizontal offset from the selected side of the health bar."))
    widgets:Help(sliders.y, Text("Вертикальное смещение от выбранной стороны полосы здоровья.",
        "Vertical offset from the selected side of the health bar."))

    local source = widgets:Label(preview, "", 10, T.muted)
    source:SetPoint("TOPLEFT", 0, -29)
    source:SetPoint("TOPRIGHT", 0, -29)
    source:SetWordWrap(false)
    local stage = Frame(preview, T.input, T.lineSoft)
    stage:SetPoint("TOPLEFT", 0, -47)
    stage:SetPoint("TOPRIGHT", 0, -47)
    stage:SetHeight(76)
    if stage.SetClipsChildren then stage:SetClipsChildren(true) end
    local sample = ns.CreateMarkerPreview(stage, source)
    sample:SetPoint("CENTER")
    local previewCounts = { killer = 25, attacker = 25, defeated = 25 }
    local caption = widgets:Label(preview, "", 11, T.muted)
    caption:SetPoint("TOPLEFT", stage, "BOTTOMLEFT", 0, -10)
    local previewSlider = widgets:SliderRow(preview, "", 0, 999, 1,
        function() return previewCounts[kind] or 0 end, function(value)
            previewCounts[kind] = value
            frame:RefreshMarkers()
        end)
    previewSlider:SetPoint("TOPLEFT", 0, -151)
    previewSlider:SetPoint("TOPRIGHT", 0, -151)
    local final = widgets:SettingRow(preview, Text("Итоговый размер", "Final size"))
    final:SetPoint("LEFT", 14, 0)
    final:SetPoint("RIGHT", -14, 0)
    local finalSize = widgets:Label(final, "", 13, T.brass)
    finalSize:SetPoint("RIGHT")
    final.label:SetPoint("RIGHT", finalSize, "LEFT", -8, 0)
    local rules = BuildThresholdPanel(frame, function() return kind end)
    local reset = Button(frame, Text("Сбросить оформление", "Reset appearance"), 165, function()
        widgets:CloseColorPicker(color)
        ns.db.markerLayouts[kind], ns.db.colors[kind] = nil, nil
        ns.Changed()
    end)
    reset:SetHeight(24)
    reset:SetPoint("TOPLEFT", rules, "BOTTOMLEFT", 0, -10)

    local layingOut, lastLayoutWidth, layoutKey
    local function Layout()
        if layingOut then return end
        layingOut = true
        local width = math.min(820, math.max(1, frame:GetWidth() - 32))
        category:ClearAllPoints()
        category:SetPoint("TOPLEFT", 16, top)
        category:SetWidth(width)
        category:Refresh()
        controls:ClearAllPoints()
        preview:ClearAllPoints()
        local stacked = width < 680
        if stacked then
            preview:SetPoint("TOPLEFT", category, "BOTTOMLEFT", 0, -12)
            preview:SetWidth(width)
            controls:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -12)
            controls:SetWidth(width)
        else
            local left = math.min(420, math.floor((width - 16) * .56))
            controls:SetPoint("TOPLEFT", category, "BOTTOMLEFT", 0, -12)
            controls:SetWidth(left)
            preview:SetPoint("TOPLEFT", controls, "TOPRIGHT", 16, 0)
            preview:SetWidth(width - left - 16)
        end
        local y = -33
        for _, row in ipairs(rows) do
            if row.markerVisible then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", controls, "TOPLEFT", 0, y)
                row:SetPoint("TOPRIGHT", controls, "TOPRIGHT", 0, y)
                y = y - row:GetHeight() - 2
            end
        end
        controls:SetHeight(-y + 6)
        controls:LayoutTitleRule()
        preview:LayoutTitleRule()
        local height = stacked and (preview:GetHeight() + 12 + controls:GetHeight()) or math.max(preview:GetHeight(), controls:GetHeight())
        rules:ClearAllPoints()
        rules:SetPoint("TOPLEFT", category, "BOTTOMLEFT", 0, -height - 24)
        rules:SetWidth(width)
        rules:LayoutColumns(width)
        frame:SetHeight(math.abs(top) + category:GetHeight() + 12 + height + 12 + rules:GetHeight() + 10 + 24 + 12)
        lastLayoutWidth = frame:GetWidth()
        layingOut = nil
    end
    local function Visible(row, shown)
        row.markerVisible = shown == true
        row:SetShown(row.markerVisible)
    end
    function frame:RefreshMarkers(forceLayout)
        local current = ns.MarkStyle(kind)
        local icon = ns.IsMarkerIcon(current)
        local layout = ns.MarkerLayout(kind)
        local count = previewCounts[kind]
        local size, active = ns.MarkerSizePercent(kind, current, count)
        local eligible = ns.MarkerScalingAvailable(kind, current)
        category:Refresh()
        enabled:Refresh(false)
        Visible(color, current ~= "off")
        Visible(anchor, icon)
        Visible(sliders.size, icon or current == "edge")
        Visible(sliders.opacity, current ~= "off")
        Visible(sliders.x, icon)
        Visible(sliders.y, icon)
        caption:SetShown(eligible)
        previewSlider:SetShown(eligible)
        caption:SetText(kind == "killer" and Text("Сколько раз тебя убил", "Times they killed you")
            or kind == "attacker" and Text("Эпизодов урона по вам", "Damage episodes against you")
            or Text("Сколько раз ты его убил", "Times you killed them"))
        local scaling = ns.MarkerScaling(kind)
        previewSlider:Refresh()
        finalSize:SetText((icon or current == "edge") and ("%.0f%%"):format(size) or "—")
        preview:SetHeight(eligible and 224 or 170)
        sample:RefreshMarker(current, kind, count)
        rules:Refresh(kind, current, layout.size, active)
        local nextKey = kind .. ":" .. current .. ":" .. scaling.count
        if forceLayout or nextKey ~= layoutKey then
            layoutKey = nextKey
            final:ClearAllPoints()
            final:SetPoint("TOPLEFT", 0, eligible and -187 or -133)
            final:SetPoint("TOPRIGHT", 0, eligible and -187 or -133)
            Layout()
        end
        for _, row in ipairs(rows) do row:Refresh() end
    end
    markerPanels[frame] = true
    frame:HookScript("OnSizeChanged", function(_, width) if width ~= lastLayoutWidth then Layout() end end)
    frame:HookScript("OnShow", function(self)
        self:RefreshMarkers(true)
        C_Timer.After(0, function() if self:IsVisible() then self:RefreshMarkers(true) end end)
    end)
    frame:HookScript("OnHide", function() widgets:CloseColorPicker(color) end)
    frame:RefreshMarkers()
end

local function JournalLines()
    local lines = {}
    for _, fight in ipairs(ns.db.fights) do
        local win = fight.result == "win"
        local heading = win and ns.Kinds.defeated.label or (fight.guid and ns.Kinds.killer.label
            or Text("Ты погиб · убийца не определен", "You died · killer unknown"))
        local name = fight.name or fight.guid
        lines[#lines + 1] = { label = name and (heading .. " · " .. name) or heading,
            date = date("%d.%m %H:%M", fight.time), color = win and T.accent or ns.Kinds.killer.color }
        for _, helper in ipairs(fight.helpers or {}) do
            lines[#lines + 1] = { label = helper.name or helper.guid or "—", detail = ns.Kinds.attacker.label,
                indent = true, participant = true, color = T.muted }
        end
    end
    if #(ns.db.legacyPlayers or {}) > 0 then
        lines[#lines + 1] = { label = Text("До обновления · без разбивки на бои", "Before the update · player totals"), color = T.muted }
        for _, entry in ipairs(ns.db.legacyPlayers) do
            lines[#lines + 1] = { label = entry.name,
                detail = ns.Kinds[entry.kind].label, indent = true, color = T.muted }
        end
    end
    return lines
end

function ns.RefreshJournal()
    if not journal then return end
    local lines = JournalLines()
    journalOffset = math.max(0, math.min(journalOffset, #lines - #journal.rows))
    journal.empty:SetShown(#lines == 0)
    journal.position:SetText(#lines > #journal.rows and ("%d / %d"):format(journalOffset + 1, #lines) or "")
    for i, row in ipairs(journal.rows) do
        local line = lines[journalOffset + i]
        row:SetShown(line ~= nil)
        if line then
            row.label:ClearAllPoints()
            row.participantMarker:SetShown(line.participant == true)
            row.label:SetPoint("LEFT", line.participant and 39 or line.indent and 26 or 9, 0)
            row.label:SetPoint("RIGHT", -157, 0)
            row.label:SetText(line.label)
            row.label:SetTextColor(line.color[1], line.color[2], line.color[3], 1)
            row.detail:SetText(line.date or line.detail or "")
        end
    end
end

local function CreateJournal()
    local frame = MakeWindow("Sintezza_RivalsJournal", historyTitle, 600, 438)
    frame.rows = {}
    frame.empty = Label(frame, Text("Здесь появятся подтвержденные добивания и смерти в PvP.",
        "Confirmed killing blows and PvP deaths appear here."), 12, T.muted)
    frame.empty:SetPoint("TOPLEFT", 18, -64)
    local function Scroll(delta) journalOffset = journalOffset + delta; ns.RefreshJournal() end
    for i = 1, 10 do
        local row = Frame(frame, i % 2 == 0 and T.bg or T.panel, T.lineSoft)
        row:SetPoint("TOPLEFT", 15, -56 - (i - 1) * 34)
        row:SetPoint("TOPRIGHT", -15, -56 - (i - 1) * 34)
        row:SetHeight(30)
        row.participantMarker = ns.CreateParticipantMarker(row)
        row.participantMarker:SetPoint("LEFT", 26, 0)
        row.label = Label(row, "", 12, T.text)
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(false)
        row.detail = Label(row, "", 10, T.muted)
        row.detail:SetPoint("RIGHT", -8, 0)
        frame.rows[i] = row
    end
    frame.position = Label(frame, "", 11, T.muted)
    frame.position:SetPoint("BOTTOM", 0, 20)
    T:ButtonArrow(Button(frame, "", 30, function() Scroll(-10) end), "left"):SetPoint("BOTTOM", -57, 11)
    T:ButtonArrow(Button(frame, "", 30, function() Scroll(10) end), "right"):SetPoint("BOTTOM", 57, 11)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta) Scroll(delta > 0 and -1 or 1) end)
    return frame
end

function ns.ToggleJournal()
    if ns.PvPSource and ns.PvPSource:OpenHistory() then
        return
    end
    if journal and journal:IsShown() then journal:Hide(); return end
    journal = journal or CreateJournal()
    journalOffset = 0
    ns.RefreshJournal()
    Show(journal)
end

function ns.RegisterLaunchers()
    local title = "Sintezza Rivals"
    local icon = Sintezza_Theme.icons.Sintezza_Rivals
    ns.Launcher:RegisterMinimap(title, icon, ns.db.minimap, function()
        if ns.PvP and ns.PvP.UI then ns.PvP.UI:Toggle() end
    end)
end
