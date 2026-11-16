-- Sintezza Rivals / Theme/Widgets.lua
--
-- The controls built on the Theme primitives: buttons, the search box, the
-- switch, the drop-down select, the slider, the column chart, the list scroll
-- bar and the settings rows. Everything in the window and the options panel
-- is made from these, so the two cannot drift apart.

local ADDON, root = ...
local ns = root.PvP

local Theme = ns.Theme
local C, L = Theme.C, Theme.L

--------------------------------------------------------------------- widgets
function Theme.Button(parent, text, width, onClick, tipText)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 90, 26)
    button.label = Theme.Font(button, 12, C.fg)
    button.label:SetPoint("CENTER")
    button.label:SetText(L(text))
    root.Theme:SkinButton(button, button.label, 12)
    if onClick then button:SetScript("OnClick", onClick) end
    if tipText then Theme.Tip(button, L(text), L(tipText), "ANCHOR_TOP") end
    return button
end

function Theme.SearchBox(parent, width, onChange, placeholder)
	local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
	box:SetSize(width or 200, 24)
	box:SetAutoFocus(false)
	box:SetTextInsets(8, 24, 0, 0)
	root.Theme:SkinInput(box, 12)
	local hint = Theme.Font(box, 12, C.dim)
	hint:SetPoint("LEFT", 8, 0)
	hint:SetText(placeholder and Theme.L(placeholder) or "")

	-- a clear button, because backspacing a search box is nobody's idea of fun
	local clear = CreateFrame("Button", nil, box)
	clear:SetSize(18, 18)
	clear:SetPoint("RIGHT", -3, 0)
	local cx = Theme.Cross(clear, 12)
	cx:SetPoint("CENTER")
	clear:SetScript("OnEnter", function() cx:SetVertexColor(C.fg[1], C.fg[2], C.fg[3]) end)
	clear:SetScript("OnLeave", function() cx:SetVertexColor(C.muted[1], C.muted[2], C.muted[3]) end)
	clear:SetScript("OnClick", function()
		box:SetText("")
		box:ClearFocus()
	end)
	clear:Hide()

	box:SetScript("OnTextChanged", function(self)
		local empty = self:GetText() == ""
		hint:SetShown(empty)
		clear:SetShown(not empty)
		if onChange then onChange(self) end
	end)
	box:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
	box.clearButton = clear
	box.hint = hint
	-- the placeholder says what this particular list can be searched by, so it
	-- changes with the tab
	function box:SetPlaceholder(text)
		hint:SetText(text and Theme.L(text) or "")
	end
	return box
end

Theme.TOGGLE_W, Theme.TOGGLE_H = 44, 20

function Theme.Toggle(parent, get, set)
	local t = CreateFrame("Button", nil, parent)
	t:SetSize(Theme.TOGGLE_W, Theme.TOGGLE_H)
	local track = CreateFrame("Frame", nil, t)
	track:SetSize(Theme.TOGGLE_W, Theme.TOGGLE_H)
	track:SetAllPoints()
	local sync = root.Theme:SkinToggle(t, track, get)
	function t:Sync() sync(false) end
	t:SetScript("OnClick", function()
		set(not get())
		sync(true)
	end)
	return t
end

function Theme.Select(parent, width, values, get, set, onChange)
    local b = Theme.Button(parent, "", width or 170)
    root.Theme:DropdownArrow(b, b.label)

    function b:Sync()
        for _, entry in ipairs(values) do
            if entry[1] == get() then
                self.label:SetText(L(entry[2]))
                return
            end
        end
        self.label:SetText(values[1] and L(values[1][2]) or "")
    end

    b:SetScript("OnClick", function(owner)
        local entries = {}
        for index, entry in ipairs(values) do
            entries[index] = { value = entry[1], label = L(entry[2]) }
        end
        root.Theme:OpenPicker(owner, entries, get(), function(value)
            set(value)
            owner:Sync()
            if onChange then onChange(value) end
        end)
    end)
    b:Sync()
    return b
end

function Theme.Slider(parent, width, min, max, step, get, set, format)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(width or 180, 32)
	local value = Theme.Font(holder, 12, C.fg)
	value:SetPoint("TOPRIGHT")
	value:SetJustifyH("RIGHT")

	local s = CreateFrame("Slider", nil, holder)
	s:SetPoint("BOTTOMLEFT")
	s:SetPoint("BOTTOMRIGHT")
	s:SetHeight(16)
	s:SetOrientation("HORIZONTAL")
	s:SetMinMaxValues(min, max)
	s:SetValueStep(step)
	s:SetObeyStepOnDrag(true)
	local function paint(v)
		value:SetText(format and format(v) or tostring(v))
	end
	s:SetScript("OnValueChanged", function(self, v)
		v = math.floor(v / step + 0.5) * step
		set(v)
		paint(v)
	end)
	root.Theme:SkinSlider(s)
	s:SetValue(get())
	paint(get())
	holder.slider = s
	holder.Sync = function() s:SetValue(get()); paint(get()) end
	return holder
end

function Theme.VScroll(parent, onScroll)
	local bar = CreateFrame("Frame", nil, parent)
	bar.step = 1
	bar:SetWidth(10)

	local track = CreateFrame("Frame", nil, bar)
	track:SetAllPoints()
	root.Theme:ScrollTrack(track)

	-- anchored by its top corners only: mixing LEFT/RIGHT (which centre
	-- vertically) with TOP fights over the vertical position
	local thumb = CreateFrame("Frame", nil, track)
	thumb:SetPoint("TOPLEFT", 1, -1)
	thumb:SetPoint("TOPRIGHT", -1, -1)
	thumb:SetHeight(40)
	thumb:EnableMouse(true)
	local fill = thumb:CreateTexture(nil, "ARTWORK")
	fill:SetPoint("TOP")
	fill:SetPoint("BOTTOM")
	fill:SetWidth(6)
	local base = root.Theme.scrollThumb
	local function lit(on)
		root.Theme:ScrollThumbArt(fill, on and C.accent or base)
	end
	lit(false)
	thumb:SetScript("OnEnter", function() lit(true) end)
	thumb:SetScript("OnLeave", function() if not thumb.dragging then lit(false) end end)

	bar.total, bar.visible, bar.first = 0, 0, 0

	local function reportFromY()
		local trackH = track:GetHeight() - 2
		local thumbH = thumb:GetHeight()
		local room = math.max(1, trackH - thumbH)
		local top = (track:GetTop() or 0) - (thumb:GetTop() or 0) - 1
		local frac = math.max(0, math.min(1, top / room))
		local maxFirst = math.max(0, bar.total - bar.visible)
		onScroll(math.floor(frac * maxFirst + 0.5))
	end

	thumb:SetScript("OnMouseDown", function(self)
		self.dragging = true
		self:SetScript("OnUpdate", function()
			local _, cy = GetCursorPosition()
			cy = cy / track:GetEffectiveScale()
			local trackTop = track:GetTop() - 1
			local trackH = track:GetHeight() - 2
			local thumbH = self:GetHeight()
			local y = math.max(trackTop - trackH + thumbH, math.min(trackTop, cy + thumbH / 2))
			self:ClearAllPoints()
			self:SetPoint("TOPLEFT", track, "TOPLEFT", 1, y - trackTop)
			self:SetPoint("TOPRIGHT", track, "TOPRIGHT", -1, y - trackTop)
			reportFromY()
		end)
	end)
	local function StopDrag(self)
		self.dragging = nil
		self:SetScript("OnUpdate", nil)
		lit(false)
	end
	thumb:SetScript("OnMouseUp", StopDrag)
	thumb:SetScript("OnHide", StopDrag)

	-- total and visible in rows or pixels, first is the current offset
	function bar:Update(total, visible, first)
		self.total, self.visible, self.first = total, visible, first
		local trackH = track:GetHeight() - 2
		local scrolls = total > visible and trackH > 0
		if self.up then
			self.up:SetEnabled(scrolls and first > 0)
			self.down:SetEnabled(scrolls and first < total - visible)
		end
		if not scrolls then
			thumb:Hide()
			self:Hide()
			return
		end
		self:Show()
		thumb:Show()
		local thumbH = math.min(trackH, math.max(classic and 18 or 24, trackH * visible / total))
		thumb:SetHeight(thumbH)
		local maxFirst = math.max(1, total - visible)
		local pos = (first / maxFirst) * (trackH - thumbH)
		thumb:ClearAllPoints()
		thumb:SetPoint("TOPLEFT", track, "TOPLEFT", 1, -1 - pos)
		thumb:SetPoint("TOPRIGHT", track, "TOPRIGHT", -1, -1 - pos)
	end

	return bar
end

-- A scrolling area with that bar beside it: the view, its content frame, and
-- mouse-wheel scrolling. child is optional (an edit box, for one); without it
-- a plain frame is made. Call view:Refresh() after the content changes height.
function Theme.ScrollArea(parent, step, child)
	local view = CreateFrame("ScrollFrame", nil, parent)
	if child then child:SetParent(view) else child = CreateFrame("Frame", nil, view) end
	if child:GetHeight() < 1 then child:SetSize(1, 1) end
	view:SetScrollChild(child)
	local bar
	local function set(v)
		local max = math.max(0, child:GetHeight() - view:GetHeight())
		v = math.max(0, math.min(max, v or 0))
		view:SetVerticalScroll(v)
		bar:Update(child:GetHeight(), view:GetHeight(), v)
	end
	bar = Theme.VScroll(parent, set)
	bar.step = step or 40
	bar:SetPoint("TOPLEFT", view, "TOPRIGHT", 4, 0)
	bar:SetPoint("BOTTOMLEFT", view, "BOTTOMRIGHT", 4, 0)
	view:EnableMouseWheel(true)
	view:SetScript("OnMouseWheel", function(self, delta) set(self:GetVerticalScroll() - delta * bar.step) end)
	view:SetScript("OnSizeChanged", function(self)
		child:SetWidth(self:GetWidth())
		set(self:GetVerticalScroll())
	end)
	function view:Refresh() set(self:GetVerticalScroll()) end
	function view:ToTop() set(0) end
	view.child, view.bar = child, bar
	return view, child
end

--------------------------------------------------------------------- settings rows
-- A settings row: name and explanation on the left, control on the right. The
-- height comes from how tall the explanation actually wraps, so a three-line
-- help text can never spill over the next row, and Reflow re-measures when the
-- window is resized.
local CONTROL_ROOM = 230
local CONTROL_INSET = 16
local ROW_TOP, ROW_BOTTOM = 10, 10

-- The row is as tall as whatever is tallest in it: the label, the label plus its
-- explanation, or the control, so nothing hangs into the row below.
function Theme.RowHeight(row)
	if row.fixedHeight then return row.fixedHeight end
	local textH = row.name:GetStringHeight() or 14
	if row.help then
		textH = textH + 4 + (row.help:GetStringHeight() or 12)
	end
	local controlH = (row.controlHeight or 0) + 8
	return math.max(Theme.SET_ROW_H, textH + ROW_TOP + ROW_BOTTOM, controlH + ROW_TOP + ROW_BOTTOM)
end

-- Re-measures every row of a page and re-stacks them. With a filter, rows that
-- do not match are hidden and the rest close up, which is how the settings
-- search works without moving rows between pages.
function Theme.Reflow(holder, filter)
	if not holder.rows then return 0, 0 end
	local width = holder:GetWidth()
	local y = holder.startY or -10
	local shown = 0
	for _, row in ipairs(holder.rows) do
		local match = true
		if filter and filter ~= "" then
			match = row.searchText and string.find(row.searchText, filter, 1, true) and true or false
		end
		if match and (not row.visibleWhen or row.visibleWhen(filter)) then
			shown = shown + 1
			row:Show()
			-- the text stops where this row's own control starts: two buttons side by
			-- by side need more room than one switch, and the text must never run under them
			local textWidth = math.max(180, width - math.max(CONTROL_ROOM, (row.controlWidth or 0) + 2 * CONTROL_INSET + 14))
			row.name:SetWidth(textWidth)
			if row.help then row.help:SetWidth(textWidth) end
			local h = Theme.RowHeight(row)
			row:SetHeight(h)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, y)
			row:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, y)
			y = y - h
		else
			row:Hide()
		end
	end
	holder:SetHeight(math.abs(y) + 20)
	return y, shown
end

-- how many rows of a page match, without touching the layout
function Theme.CountMatches(holder, filter)
	if not holder or not holder.rows then return 0 end
	if not filter or filter == "" then
		local all = 0
		for _, row in ipairs(holder.rows) do
			if not row.isHeader then all = all + 1 end
		end
		return all
	end
	local n = 0
	for _, row in ipairs(holder.rows) do
		if not row.isHeader and row.searchText
			and string.find(row.searchText, filter, 1, true) then n = n + 1 end
	end
	return n
end

function Theme.Row(parent, y, name, help)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", 0, y)
	row:SetPoint("TOPRIGHT", 0, y)

	row.hover = Theme.Solid(row, "BACKGROUND", C.fg, 0.03)
	row.hover:SetAllPoints()
	row.hover:Hide()
	row:SetScript("OnEnter", function(self) self.hover:Show() end)
	row:SetScript("OnLeave", function(self) self.hover:Hide() end)
	row:EnableMouse(true)

	local textWidth = math.max(180, (parent:GetWidth() > 0 and parent:GetWidth() or 560) - CONTROL_ROOM)

	row.name = Theme.Font(row, 13, C.fg)
	row.name:SetPoint("TOPLEFT", 14, -ROW_TOP)
	row.name:SetWidth(textWidth)
	row.name:SetJustifyV("TOP")
	row.name:SetText(L(name))

	if help and help ~= "" then
		row.help = Theme.Font(row, 11, C.muted)
		row.help:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
		row.help:SetWidth(textWidth)
		row.help:SetJustifyV("TOP")
		row.help:SetText(L(help))
	end

	row:SetHeight(Theme.RowHeight(row))
	Theme.Rule(row, "BOTTOM", C.line, 0.5, 10)

	-- what the settings search looks at
	row.searchText = ns.Lower(L(name) .. " " .. (help and L(help) or ""))

	parent.rows = parent.rows or {}
	parent.rows[#parent.rows + 1] = row
	return row
end


-- The control is anchored RIGHT to RIGHT, which means the client centres it
-- vertically in the row and keeps it centred when the row changes height. No
-- arithmetic, so there is nothing to round wrong and nothing to go stale when a
-- translation turns a one-line explanation into three.
function Theme.AttachControl(row, control, height)
	row.controlHeight = height or 18
	row.controlWidth = control:GetWidth()
	-- reserve the room now as well, before the first reflow
	local room = math.max(CONTROL_ROOM, row.controlWidth + 2 * CONTROL_INSET + 14)
	local pw = row:GetParent() and row:GetParent():GetWidth() or 0
	if pw > 0 then
		local textWidth = math.max(180, pw - room)
		row.name:SetWidth(textWidth)
		if row.help then row.help:SetWidth(textWidth) end
	end
	control:ClearAllPoints()
	control:SetPoint("RIGHT", row, "RIGHT", -CONTROL_INSET, 0)
	row:SetHeight(Theme.RowHeight(row))
	return control
end

-- A section heading inside a settings page. It is a row like any other, so the
-- page layout and the settings search move it with everything else; it carries
-- no search text, which makes the headings disappear while you are searching
-- and leaves a flat list of the settings that actually matched.
function Theme.HeaderRow(parent, y, text)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", 0, y)
	row:SetPoint("TOPRIGHT", 0, y)
	row.isHeader = true
	row.fixedHeight = 36
	row:SetHeight(36)
	row.name = Theme.Font(row, 11, C.accent2, true)
	row.name:SetPoint("BOTTOMLEFT", 14, 7)
	row.name:SetText(string.upper(L(text)))
	Theme.Rule(row, "BOTTOM", C.line, 1, 10)
	row.searchText = ""
	parent.rows = parent.rows or {}
	parent.rows[#parent.rows + 1] = row
	return row, y - 36
end
