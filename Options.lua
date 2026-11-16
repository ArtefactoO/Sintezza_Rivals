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
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, 30)
    button.label = Label(button, title, 13, T.text)
    button.label:SetPoint("CENTER")
    T:SkinButton(button, button.label, 13)
    function button:Refresh() T:PaintButton(self, self.selected == true) end
    button:SetScript("OnClick", callback)
    button:Refresh()
    return button
end

local kinds = { "killer", "attacker", "defeated", "manual" }
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

local function OpenColor(owner, kind, style)
    local stock = style == "swords" or style == "skull"
    local original
    if stock then original = ns.MarkerLayout(kind).iconColor else original = ns.db.colors[kind] end
    local r, g, b = unpack(stock and (original or { 1, 1, 1 }) or ns.Color(kind))
    local function Apply(color)
        if stock then
            ns.SetMarkerLayout(kind, "iconColor", color)
        else
            ns.db.colors[kind] = color
            ns.Changed()
        end
    end
    widgets:OpenColorPicker(owner, { r = r, g = g, b = b }, false, function(color)
        Apply({ color.r, color.g, color.b })
    end, function() Apply(original) end)
end

local function ThresholdInput(parent, get, set, showError)
    local edit = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    edit:SetSize(57, 22)
    edit:SetAutoFocus(false)
    edit:SetNumeric(true)
    edit:SetMaxLetters(3)
    edit:SetJustifyH("CENTER")
    T:SkinInput(edit, 11)
    widgets:EnableSettingsTab(edit)
    function edit:Refresh()
        if not self:HasFocus() then self:SetNumber(get()) end
    end
    edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    edit:SetScript("OnTextChanged", function(self, user)
        if not user then return end
        local accepted = set(tonumber(self:GetText()))
        showError(not accepted)
        self:SetBackdropBorderColor(unpack(accepted and T.accentLine or T.danger))
    end)
    edit:HookScript("OnEditFocusLost", function(self)
        self:Refresh()
        showError(false)
    end)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return edit
end

local function BuildThresholdPanel(frame, preview, controls, getKind)
    local rules = Frame(frame, T.panel, T.lineSoft)
    rules:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -12)
    rules:SetPoint("TOPRIGHT", controls, "BOTTOMRIGHT", 0, -12)
    local heading = Label(rules, Text("Масштаб по убийствам", "Scale by kills"), 13, T.accent)
    heading:SetPoint("TOPLEFT", 12, -12)
    if widgets.Help then
        widgets:Help(rules, Text(
            "Увеличивает метку по заданным порогам. Действует прибавка с самого высокого достигнутого порога.",
            "Increases the marker size at configured thresholds. The highest reached threshold supplies the bonus."), heading)
    end
    local toggle = widgets:Toggle(rules, Text("Включить", "Enable"),
        function() return ns.MarkerScaling(getKind()).enabled end,
        function(value) ns.SetMarkerScaling(getKind(), "enabled", value) end)
    toggle:SetSize(108, 25)
    toggle:SetPoint("TOPRIGHT", -11, -5)

    local tableFrame = CreateFrame("Frame", nil, rules)
    tableFrame:SetAllPoints()
    Label(tableFrame, Text("Прибавка к базовому размеру", "Bonus to base size"), 11, T.muted):SetPoint("TOPLEFT", 12, -39)
    local counts = { { 3, Text("3 порога", "3 thresholds") }, { 4, Text("4 порога", "4 thresholds") } }
    local countButton = Button(tableFrame, "", 115, function(owner)
        Select(owner, counts, ns.MarkerScaling(getKind()).count,
            function(value) ns.SetMarkerScaling(getKind(), "count", value) end)
    end)
    T:DropdownArrow(countButton, countButton.label)
    countButton:SetHeight(24)
    countButton:SetPoint("TOPRIGHT", -11, -31)
    local heads = Frame(tableFrame, T.bg, T.lineSoft)
    heads:SetPoint("TOPLEFT", 12, -60)
    heads:SetPoint("TOPRIGHT", -12, -60)
    heads:SetHeight(20)
    Label(heads, Text("От убийств", "Kills required"), 11, T.muted):SetPoint("LEFT", 8, 0)
    Label(heads, Text("Прибавка", "Bonus"), 11, T.muted):SetPoint("CENTER")
    Label(heads, Text("Размер", "Size"), 11, T.muted):SetPoint("RIGHT", -8, 0)
    local errorText = Label(tableFrame, Text("Пороги должны расти. Прибавка от 0 до 200%.",
        "Use increasing thresholds and a bonus from 0 to 200%."), 11, T.danger)
    errorText:SetPoint("BOTTOMLEFT", 12, 9)
    errorText:Hide()
    local function ShowError(shown)
        errorText:SetShown(shown)
    end
    local unavailable = Label(rules, "", 11, T.muted)
    unavailable:SetPoint("TOPLEFT", 12, -39)

    local rows = {}
    for index = 1, 4 do
        local row = CreateFrame("Frame", nil, tableFrame)
        local y = -82 - (index - 1) * 26
        row:SetPoint("TOPLEFT", 12, y)
        row:SetPoint("TOPRIGHT", -12, y)
        row:SetHeight(24)
        row.highlight = row:CreateTexture(nil, "BACKGROUND")
        row.highlight:SetAllPoints()
        row.highlight:SetColorTexture(unpack(T.selection))
        local function Input(field)
            return ThresholdInput(row, function() return ns.MarkerScaling(getKind()).tiers[index][field] end,
                function(value) return ns.SetMarkerThreshold(getKind(), index, field, value) end, ShowError)
        end
        row.kills = Input("kills")
        row.kills:SetPoint("LEFT", 8, 0)
        row.bonus = Input("bonus")
        row.bonus:SetPoint("CENTER", -3, 0)
        Label(row, "%", 11, T.muted):SetPoint("LEFT", row.bonus, "RIGHT", 4, 0)
        row.total = Label(row, "", 12, T.brass)
        row.total:SetPoint("RIGHT", -8, 0)
        rows[index] = row
    end

    function rules:Refresh(kind, style, base, active)
        local available = ns.MarkerScalingAvailable(kind, style)
        local scaling = ns.MarkerScaling(kind)
        toggle:SetShown(available)
        if available then toggle:Refresh(false) end
        unavailable:SetShown(not available)
        unavailable:SetText((kind == "killer" or kind == "defeated") and
            Text("Для масштабирования выбери метку-иконку.", "Choose an icon to use scaling.")
            or Text("У этой категории фиксированный размер.", "This category uses a fixed size."))
        tableFrame:SetShown(available)
        rules:SetHeight(available and (scaling.count == 4 and 205 or 179) or 61)
        countButton.label:SetText(ChoiceLabel(counts, scaling.count))
        for index, row in ipairs(rows) do
            row:SetShown(index <= scaling.count)
            row.highlight:SetShown(index == active)
            row.kills:Refresh()
            row.bonus:Refresh()
            row.total:SetText(("%.0f%%"):format(base * (1 + scaling.tiers[index].bonus / 100)))
        end
    end
    return rules
end

function ns.BuildMarkerControls(frame, top)
    local kind = kinds[1]
    local categories = {}
    for index, key in ipairs(kinds) do categories[index] = { key, ns.Kinds[key].label } end
    local color
    local category = Button(frame, "", 280, function(owner)
        Select(owner, categories, kind, function(value)
            widgets:CloseColorPicker(color)
            kind = value
            frame:RefreshMarkers()
        end)
    end)
    T:DropdownArrow(category, category.label)
    category:SetPoint("TOPLEFT", 16, top)

    local preview = Frame(frame, T.panel, T.lineSoft)
    preview:SetSize(284, 194)
    preview:SetPoint("TOPLEFT", category, "BOTTOMLEFT", 0, -8)
    Label(preview, Text("Предпросмотр", "Preview"), 11, T.muted):SetPoint("TOPLEFT", 12, -10)
    local previewSource = Label(preview, "", 10, T.dim)
    previewSource:SetPoint("TOPRIGHT", -12, -11)
    local stage = Frame(preview, T.bg, T.lineSoft)
    stage:SetPoint("TOPLEFT", 11, -31)
    stage:SetPoint("TOPRIGHT", -11, -31)
    stage:SetHeight(71)
    if stage.SetClipsChildren then stage:SetClipsChildren(true) end
    local sample = ns.CreateMarkerPreview(stage, previewSource)
    sample:SetPoint("CENTER")
    local previewCounts = { killer = 25, defeated = 25 }
    local previewCaption = Label(preview, "", 11, T.muted)
    previewCaption:SetPoint("TOPLEFT", 12, -108)
    local previewSlider = widgets:SliderRow(preview, "", 0, 60, 1,
        function() return previewCounts[kind] or 0 end, function(value)
            previewCounts[kind] = value
            frame:RefreshMarkers()
        end)
    previewSlider:SetPoint("TOPLEFT", 10, -124)
    previewSlider:SetPoint("TOPRIGHT", -10, -124)
    Label(preview, Text("Итоговый размер", "Final size"), 11, T.muted):SetPoint("BOTTOMLEFT", 12, 12)
    local finalSize = Label(preview, "", 14, T.brass)
    finalSize:SetPoint("BOTTOMRIGHT", -12, 9)
    local reset = Button(preview, Text("Сбросить оформление", "Reset appearance"), 165, function()
        widgets:CloseColorPicker(color)
        ns.db.markerLayouts[kind], ns.db.colors[kind] = nil, nil
        ns.Changed()
    end)

    local controls = CreateFrame("Frame", nil, frame)
    controls:SetPoint("TOPLEFT", preview, "TOPRIGHT", 14, 0)
    controls:SetPoint("TOPRIGHT", -16, top - 38)
    controls:SetHeight(194)
    local rules = BuildThresholdPanel(frame, preview, controls, function() return kind end)
    local style = Button(controls, "", 152, function(owner)
        Select(owner, ns.MarkChoices, ns.MarkStyle(kind), function(value)
            widgets:CloseColorPicker(color)
            ns.db.marks[kind] = value
            ns.Changed()
        end)
    end)
    T:DropdownArrow(style, style.label)
    style:SetPoint("TOPLEFT")
    color = Button(controls, Text("Цвет", "Color"), 74, function(owner) OpenColor(owner, kind, ns.MarkStyle(kind)) end)
    color:SetPoint("LEFT", style, "RIGHT", 8, 0)
    color.label:SetPoint("CENTER", 6, 0)
    color.swatch = color:CreateTexture(nil, "OVERLAY")
    color.swatch:SetSize(9, 9)
    color.swatch:SetPoint("LEFT", 7, 0)
    color:HookScript("OnHide", function() widgets:CloseColorPicker(color) end)

    local anchorRow = widgets:SettingRow(controls, Text("Положение", "Position"), 28)
    anchorRow:SetPoint("TOPLEFT", style, "BOTTOMLEFT", 0, -4)
    anchorRow:SetPoint("TOPRIGHT", 0, -34)
    local anchor = Button(anchorRow, "", 152, function(owner)
        Select(owner, ns.MarkerAnchors, ns.MarkerLayout(kind).anchor,
            function(value) ns.SetMarkerLayout(kind, "anchor", value) end)
    end)
    T:DropdownArrow(anchor, anchor.label)
    anchor:SetHeight(24)
    anchor:SetPoint("RIGHT", -2, 0)
    local sliders = {}
    local fields = {
        { "size", Text("Базовый размер", "Base size"), 50, 250, 5, "%" },
        { "opacity", Text("Прозрачность", "Opacity"), 10, 100, 5, "%" },
        { "x", Text("Смещение X", "X offset"), -32, 32, 1 },
        { "y", Text("Смещение Y", "Y offset"), -24, 24, 1 },
    }
    local function PlaceSlider(slider, y)
        slider:SetPoint("TOPLEFT", 0, y)
        slider:SetPoint("TOPRIGHT", 0, y)
    end
    for _, field in ipairs(fields) do
        local key, label, low, high, step, suffix = unpack(field)
        local slider = widgets:SliderRow(controls, label, low, high, step,
            function() return ns.MarkerLayout(kind)[key] end,
            function(value) ns.SetMarkerLayout(kind, key, value) end, suffix)
        slider:SetHeight(26)
        sliders[key] = slider
    end
    PlaceSlider(sliders.x, -117)
    PlaceSlider(sliders.y, -144)

    function frame:RefreshMarkers()
        local current = ns.MarkStyle(kind)
        local icon = ns.IsMarkerIcon(current)
        local layout = ns.MarkerLayout(kind)
        category.label:SetText(ns.Kinds[kind].label)
        style.label:SetText(ChoiceLabel(ns.MarkChoices, current))
        local previewCount = previewCounts[kind]
        local size, active = ns.MarkerSizePercent(kind, current, previewCount)
        local eligible = ns.MarkerScalingAvailable(kind, current)
        previewCaption:SetShown(eligible)
        previewSlider:SetShown(eligible)
        previewCaption:SetText(kind == "killer" and Text("Сколько раз тебя убил", "Times they killed you")
            or Text("Сколько раз ты его убил", "Times you killed them"))
        local scaling = ns.MarkerScaling(kind)
        previewSlider:SetRange(0, math.max(60, scaling.tiers[scaling.count].kills + 5))
        previewSlider:Refresh()
        finalSize:SetText((icon or current == "edge") and ("%.0f%%"):format(size) or "—")
        sample:RefreshMarker(current, kind, previewCount)
        rules:Refresh(kind, current, layout.size, active)
        color:SetShown(current ~= "off")
        local stock = current == "swords" or current == "skull"
        local r, g, b = unpack(stock and (layout.iconColor or T.text) or ns.Color(kind))
        color.swatch:SetColorTexture(r, g, b, 1)
        anchorRow:SetShown(icon)
        anchor.label:SetText(ChoiceLabel(ns.MarkerAnchors, layout.anchor))
        sliders.size:SetShown(icon or current == "edge")
        sliders.opacity:SetShown(current ~= "off")
        PlaceSlider(sliders.size, icon and -63 or -33)
        PlaceSlider(sliders.opacity, icon and -90 or current == "edge" and -60 or -33)
        sliders.x:SetShown(icon)
        sliders.y:SetShown(icon)
        for _, slider in pairs(sliders) do slider:Refresh() end
    end

    local mark = Button(frame, Text("Отметить цель", "Mark target"), 145, ns.MarkTarget)
    mark:SetPoint("TOPLEFT", rules, "BOTTOMLEFT", 0, -12)
    reset:SetPoint("LEFT", mark, "RIGHT", 8, 0)
    markerPanels[frame] = true
    frame:HookScript("OnShow", frame.RefreshMarkers)
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
    end, ns.ToggleJournal, historyTitle)
end
