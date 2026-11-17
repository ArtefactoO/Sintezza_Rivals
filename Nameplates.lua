local _, ns = ...
local visible, active, pool = {}, {}, {}
local ticker

local function SetIcon(texture, style, kind, layout)
    if style == "swords" then
        texture:SetTexture("Interface\\AddOns\\Sintezza_Rivals\\Media\\NameplateSwords.tga")
        texture:SetTexCoord(0, 1, 0, 1)
        texture:SetVertexColor(1, 1, 1, 1)
    else
        if style == "diamond" then
            local r, g, b = unpack(ns.Color(kind))
            texture:SetTexture(Sintezza_Theme.icons.RivalsMarker)
            texture:SetTexCoord(0, 1, 0, 1)
            texture:SetVertexColor(r, g, b, .9)
        else
            texture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
            if SetRaidTargetIconTexture then SetRaidTargetIconTexture(texture, 8)
            else texture:SetTexCoord(.75, 1, .25, .5) end
            texture:SetVertexColor(.92, .85, .73, 1)
        end
    end
    local custom = layout.iconColor
    if custom and style ~= "diamond" then texture:SetVertexColor(custom[1], custom[2], custom[3], 1) end
end

local function CanUse(region)
    return region and not (region.IsForbidden and region:IsForbidden())
end

local function ReadColor(text)
    if not CanUse(text) then return end
    local ok, r, g, b, a = pcall(text.GetTextColor, text)
    if ok then
        r, g, b, a = ns.Public(r), ns.Public(g), ns.Public(b), ns.Public(a)
        if r and g and b then return { r, g, b, a or 1 } end
    end
end

local function SameColor(a, b)
    if not a or not b then return false end
    for i = 1, 4 do
        if math.abs(a[i] - b[i]) > .001 then return false end
    end
    return true
end

local function RestoreName(state)
    local text = state.text
    if text and SameColor(ReadColor(text), state.applied) then
        pcall(text.SetTextColor, text, unpack(state.original))
    end
    state.text, state.applied, state.original = nil, nil, nil
end

local function PaintName(state, text, kind, opacity)
    if state.text ~= text then RestoreName(state) end
    local current = ReadColor(text)
    if not current then return end
    local original = SameColor(current, state.applied) and state.original or current
    local color = ns.Color(kind)
    local desired = {
        original[1] + (color[1] - original[1]) * opacity,
        original[2] + (color[2] - original[2]) * opacity,
        original[3] + (color[3] - original[3]) * opacity,
        original[4],
    }
    if SameColor(current, desired) then return end
    if pcall(text.SetTextColor, text, unpack(desired)) then
        state.text, state.original, state.applied = text, original, desired
    end
end

local function CreateBadge(parent)
    local badge = CreateFrame("Frame", nil, parent or UIParent)
    badge:SetSize(12, 12)
    badge.icon = badge:CreateTexture(nil, "OVERLAY")
    badge.icon:SetAllPoints()
    badge.edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local edge = badge:CreateTexture(nil, "OVERLAY")
        if side == "TOP" or side == "BOTTOM" then
            edge:SetPoint(side .. "LEFT")
            edge:SetPoint(side .. "RIGHT")
            edge:SetHeight(1)
        else
            edge:SetPoint("TOP" .. side)
            edge:SetPoint("BOTTOM" .. side)
            edge:SetWidth(1)
        end
        badge.edges[#badge.edges + 1] = edge
    end
    badge:Hide()
    return badge
end

local badgeAnchors = {
    right = { "LEFT", "RIGHT", 3, 0 }, left = { "RIGHT", "LEFT", -3, 0 },
    top = { "BOTTOM", "TOP", 0, 3 }, bottom = { "TOP", "BOTTOM", 0, -3 },
}

local function PaintMarker(state, health, text, style, kind, count)
    local layout = ns.MarkerLayout(kind)
    local opacity = layout.opacity / 100
    if style == "name" then PaintName(state, text, kind, opacity) else RestoreName(state) end
    local badge = state.badge
    if badge then
        if style == "name" or style == "off" then
            badge:Hide()
        else
            local border = style == "edge"
            local size = ns.MarkerSizePercent(kind, style, count) / 100
            if state.style ~= style or state.size ~= size or state.anchor ~= layout.anchor
                or state.x ~= layout.x or state.y ~= layout.y then
                badge:ClearAllPoints()
                if border then
                    badge:SetPoint("TOPLEFT", health, "TOPLEFT", -size, size)
                    badge:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", size, -size)
                    for index, edge in ipairs(badge.edges) do
                        if index <= 2 then edge:SetHeight(size) else edge:SetWidth(size) end
                    end
                else
                    local pixels = (style == "diamond" and 5 or 12) * size
                    badge:SetSize(pixels, pixels)
                    local anchor = badgeAnchors[layout.anchor]
                    badge:SetPoint(anchor[1], health, anchor[2], anchor[3] + layout.x, anchor[4] + layout.y)
                end
                state.size, state.anchor, state.x, state.y = size, layout.anchor, layout.x, layout.y
            end
            badge:SetAlpha(opacity)
            badge.icon:SetShown(not border)
            if not border then SetIcon(badge.icon, style, kind, layout) end
            local r, g, b
            if border then r, g, b = unpack(ns.Color(kind)) end
            for _, edge in ipairs(badge.edges) do
                edge:SetShown(border)
                if border then edge:SetColorTexture(r, g, b, .8) end
            end
            badge:Show()
        end
    end
    state.style = style
end

local function Release(unit)
    local state = active[unit]
    if not state then return end
    RestoreName(state)
    if state.badge then
        state.badge:Hide()
        state.badge:ClearAllPoints()
        state.badge:SetParent(UIParent)
        pool[#pool + 1] = state.badge
    end
    active[unit] = nil
end

local function PlateParts(unit)
    local native = ns.Read(C_NamePlate.GetNamePlateForUnit, unit)
    if not CanUse(native) then return end
    local modules = EllesmereUI and EllesmereUI._ModuleNS
    local adapter = modules and modules.EllesmereUINameplates
    local token = ns.Public(native.namePlateUnitToken)
    local plate = adapter and adapter.plates and adapter.plates[type(token) == "string" and token or unit]
    if plate and plate.nameplate == native and CanUse(plate.health) then
        return plate, plate.health, plate.name
    end
    local frame = native.UnitFrame
    if CanUse(frame) and frame:IsShown() then
        local bars = frame.HealthBarsContainer
        return frame, frame.healthBar or (bars and bars.healthBar) or frame, frame.name
    end
    return native, native
end

local function PublicMethod(region, method)
    if not CanUse(region) then return end
    local ok, a, b, c, d = pcall(region[method], region)
    if ok then return ns.Public(a), ns.Public(b), ns.Public(c), ns.Public(d) end
end

local function IsSize(value)
    return type(value) == "number" and value > 0 and value < math.huge
end

local function TargetAppearance()
    if not C_NamePlate or ns.Read(UnitCanAttack, "player", "target") ~= true then return end
    local owner, health, name = PlateParts("target")
    local status = PublicMethod(health, "GetStatusBarTexture")
    local width, height = PublicMethod(health, "GetSize")
    if not (status and IsSize(width) and IsSize(height) and PublicMethod(health, "IsVisible")) then return end
    local texture = PublicMethod(status, "GetTexture")
    local r, g, b, a = PublicMethod(health, "GetStatusBarColor")
    local appearance = {
        source = ns.Text("По видимой цели", "From visible target"), width = width, height = height,
        scale = PublicMethod(health, "GetEffectiveScale"),
        texture = (type(texture) == "string" or type(texture) == "number") and texture or nil,
        reverse = PublicMethod(health, "GetReverseFill") == true,
        color = type(r) == "number" and type(g) == "number" and type(b) == "number" and { r, g, b, a or 1 } or nil,
    }
    local hx, hy = PublicMethod(health, "GetCenter")
    local function ReadLabel(label)
        if not CanUse(label) then return end
        local file, size, flags = PublicMethod(label, "GetFont")
        local x, y = PublicMethod(label, "GetCenter")
        local scale = PublicMethod(label, "GetEffectiveScale")
        local ratio = IsSize(scale) and IsSize(appearance.scale) and scale / appearance.scale or 1
        local position = type(hx) == "number" and type(hy) == "number" and type(x) == "number" and type(y) == "number"
        return {
            shown = PublicMethod(label, "IsVisible") == true,
            file = file, size = IsSize(size) and size * ratio or nil, flags = flags,
            x = position and x * ratio - hx or nil, y = position and y * ratio - hy or nil,
            color = ReadColor(label),
        }
    end
    appearance.name = ReadLabel(name) or { shown = false }
    appearance.level = ReadLabel(owner and owner.levelText) or { shown = false }
    local amount = ReadLabel((owner and owner.hpText) or health.Text)
    if not (amount and amount.shown) and owner and owner.hpNumber then amount = ReadLabel(owner.hpNumber) end
    appearance.percent = amount or { shown = false }
    return appearance
end

local function EllesmereAppearance()
    local ui = EllesmereUI
    local adapter = ui and ui._ModuleNS and ui._ModuleNS.EllesmereUINameplates
    local profile = adapter and adapter.db and adapter.db.profile
    if not profile then return end
    local width = ns.Read(adapter.GetHealthBarWidth)
    local height = ns.Read(adapter.GetHealthBarHeight)
    if not (IsSize(width) and IsSize(height)) then return end
    local path = ns.Read(ui.ResolveTexturePath, adapter.healthBarTextures, profile.healthBarTexture,
        "Interface\\Buttons\\WHITE8X8")
    local class = RAID_CLASS_COLORS and RAID_CLASS_COLORS.WARRIOR
    return {
        source = ns.Text("Профиль EllesmereUI", "EllesmereUI profile"), width = width, height = height, texture = path,
        color = class and not profile.enemyPlayerEnemyColor and { class.r, class.g, class.b, 1 } or nil,
        name = { file = ns.Read(ui.GetFontPath, "nameplates"), size = ns.Read(adapter.GetEnemyNameTextSize) },
    }
end

local function MarkerBounds(width, height, style, kind, count)
    local left, right, bottom, top = 0, width, 0, height
    local scale = ns.MarkerSizePercent(kind, style, count) / 100
    if style == "edge" then return -scale, right + scale, -scale, top + scale end
    if not ns.IsMarkerIcon(style) then return left, right, bottom, top end
    local size = (style == "diamond" and 5 or 12) * scale
    local layout = ns.MarkerLayout(kind)
    local x, y = width / 2 + layout.x, height / 2 + layout.y
    if layout.anchor == "right" then x = width + 3 + layout.x + size / 2
    elseif layout.anchor == "left" then x = -3 + layout.x - size / 2
    elseif layout.anchor == "top" then y = height + 3 + layout.y + size / 2
    else y = -3 + layout.y - size / 2 end
    return math.min(left, x - size / 2), math.max(right, x + size / 2),
        math.min(bottom, y - size / 2), math.max(top, y + size / 2)
end

function ns.CreateMarkerPreview(parent, sourceLabel)
    local scene = CreateFrame("Frame", nil, parent)
    local sample = CreateFrame("StatusBar", nil, scene)
    sample:SetMinMaxValues(0, 100)
    sample:SetValue(74)
    local bg = sample:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(ns.Theme.input))
    local function Label(value, size)
        local label = sample:CreateFontString(nil, "OVERLAY")
        ns.Theme:Font(label, size, "OUTLINE", { 1, 1, 1, 1 })
        label:SetText(value)
        return label
    end
    local name, level, percent = Label(ns.Text("Противник", "Enemy"), 11), Label("40", 10), Label("74%", 10)
    local badge = CreateBadge(sample)
    badge:SetFrameLevel(sample:GetFrameLevel() + 5)
    local state = { badge = badge }
    local appearance, queued
    local style, kind, count
    local positions = {}
    local function SetLabel(label, spec, size, defaultX, defaultY)
        size = spec and IsSize(spec.size) and spec.size or size
        local file = spec and spec.file
        local applied
        if type(file) == "string" and file ~= "" then
            local ok, result = pcall(label.SetFont, label, file, size, spec.flags or "OUTLINE")
            applied = ok and result ~= false
        end
        if not applied then ns.Theme:Font(label, size, "OUTLINE", { 1, 1, 1, 1 }) end
        local color = spec and spec.color or { 1, 1, 1, 1 }
        label:SetTextColor(unpack(color))
        label:SetShown(not spec or spec.shown ~= false)
        local x, y = spec and spec.x or defaultX, spec and spec.y or defaultY
        label:ClearAllPoints()
        label:SetPoint("CENTER", sample, "CENTER", x, y)
        positions[label] = { x = x + appearance.width / 2, y = y + appearance.height / 2, size = size }
    end

    local function Render()
        if not (kind and appearance) then return end
        local width, height = appearance.width, appearance.height
        local l, r, b, t = MarkerBounds(width, height, style, kind, count)
        for label, pos in pairs(positions) do
            if label:IsShown() then
                local half = (label:GetStringWidth() or 0) / 2
                l, r = math.min(l, pos.x - half), math.max(r, pos.x + half)
                b, t = math.min(b, pos.y - pos.size), math.max(t, pos.y + pos.size)
            end
        end
        local actual = IsSize(appearance.scale) and appearance.scale or UIParent:GetEffectiveScale()
        local preview = parent:GetEffectiveScale()
        scene:SetScale(math.min(actual / preview, math.max(1, parent:GetWidth() - 12) / (r - l),
            math.max(1, parent:GetHeight() - 8) / (t - b)))
        scene:SetSize(r - l, t - b)
        sample:ClearAllPoints()
        sample:SetPoint("BOTTOMLEFT", scene, "BOTTOMLEFT", -l, -b)
        PaintMarker(state, sample, name, style, kind, count)
    end

    local function RefreshAppearance()
        local live
        if not InCombatLockdown() then
            local ok, result = pcall(TargetAppearance)
            if ok then live = result end
        end
        appearance = live or EllesmereAppearance() or { width = 138, height = 15,
            source = ns.Text("Условный образец", "Generic preview") }
        RestoreName(state)
        sample:SetSize(appearance.width, appearance.height)
        sample:SetStatusBarTexture(appearance.texture or "Interface\\TargetingFrame\\UI-StatusBar")
        if sample.SetReverseFill then sample:SetReverseFill(appearance.reverse == true) end
        sample:SetStatusBarColor(unpack(appearance.color or { .75, .22, .18, 1 }))
        SetLabel(name, appearance.name, 11, -appearance.width / 4, appearance.height / 2 + 8)
        SetLabel(level, appearance.level, 10, appearance.width / 2 - 8, appearance.height / 2 + 8)
        SetLabel(percent, appearance.percent, 10, appearance.width / 2 - 15, 0)
        if sourceLabel then sourceLabel:SetText(appearance.source) end
        Render()
    end

    local function QueueAppearance()
        if queued then return end
        queued = true
        C_Timer.After(0, function()
            queued = nil
            if scene:IsVisible() then RefreshAppearance() end
        end)
    end
    scene:SetScript("OnEvent", QueueAppearance)
    scene:SetScript("OnShow", function(self)
        for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
            "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "DISPLAY_SIZE_CHANGED" }) do self:RegisterEvent(event) end
        QueueAppearance()
    end)
    scene:SetScript("OnHide", scene.UnregisterAllEvents)
    parent:HookScript("OnSizeChanged", function() if scene:IsVisible() then QueueAppearance() end end)
    function scene:RefreshMarker(newStyle, newKind, newCount)
        style, kind, count = newStyle, newKind, newCount
        if appearance then Render() else RefreshAppearance() end
    end
    return scene
end

local function RefreshUnit(unit)
    local guid = ns.EnemyGUID(unit)
    local record = guid and ns.db.players[guid]
    local kind
    if guid then
        if ns.PvPSource then kind = ns.PvPSource:Kind(guid, record)
        elseif record then kind = ns.Kind(record) end
    end
    local style = kind and ns.MarkStyle(kind)
    if not style or style == "off" then Release(unit); return end

    local plate, health, text = PlateParts(unit)
    if not plate then Release(unit); return end
    local state = active[unit]
    if state and (state.guid ~= guid or state.plate ~= plate or state.health ~= health) then
        Release(unit)
        state = nil
    end
    if not state then
        state = { guid = guid, plate = plate, health = health }
        active[unit] = state
    end

    if style ~= "name" and not state.badge then
        local badge = table.remove(pool) or CreateBadge()
        state.badge = badge
        badge:SetParent(plate)
        badge:SetFrameLevel(plate:GetFrameLevel() + 5)
    end
    local count
    if ns.MarkerScalingAvailable(kind, style) and ns.MarkerScaling(kind).enabled then
        if ns.PvPSource then count = ns.PvPSource:MarkerCount(guid, kind)
        elseif record then count = kind == "killer" and (record.kills or 0)
            or kind == "attacker" and (record.recaps or 0) or record.defeats end
    end
    PaintMarker(state, health, text, style, kind, count)
end

local function TryUnit(unit)
    -- A nameplate can become forbidden between the unit event and the next refresh.
    if not pcall(RefreshUnit, unit) then Release(unit) end
end

function ns.RefreshPlates()
    if not ns.IsBattleground() and (ns.PvPSource or next(ns.db.players)) then
        for unit in pairs(visible) do TryUnit(unit) end
    else
        for unit in pairs(active) do Release(unit) end
    end
    -- Ellesmere can reapply the base name color when threat or nameplate layout changes.
    local needsNameRefresh
    for _, state in pairs(active) do if state.style == "name" then needsNameRefresh = true; break end end
    if needsNameRefresh then
        if not ticker then ticker = C_Timer.NewTicker(.45, ns.RefreshPlates) end
    elseif ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local refreshQueued
function ns.QueueRefreshPlates()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0, function()
        refreshQueued = nil
        ns.RefreshPlates()
    end)
end

function ns.StartNameplates()
    local driver = CreateFrame("Frame")
    driver:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    driver:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    driver:RegisterEvent("PLAYER_ENTERING_WORLD")
    driver:RegisterEvent("PLAYER_REGEN_ENABLED")
    driver:RegisterEvent("PLAYER_TARGET_CHANGED")
    driver:RegisterEvent("UNIT_FACTION")
    driver:SetScript("OnEvent", function(_, event, unit)
        if event == "NAME_PLATE_UNIT_ADDED" then
            if type(ns.Public(unit)) ~= "string" then return end
            visible[unit] = true
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            if type(ns.Public(unit)) ~= "string" then return end
            visible[unit] = nil
            Release(unit)
        elseif event == "PLAYER_ENTERING_WORLD" then
            for token in pairs(active) do Release(token) end
            wipe(visible)
            for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
                local token = CanUse(plate) and ns.Public(plate.namePlateUnitToken)
                if type(token) == "string" then visible[token] = true end
            end
        elseif event == "UNIT_FACTION" and (type(ns.Public(unit)) ~= "string" or not visible[unit]) then return end
        ns.QueueRefreshPlates()
    end)
end
