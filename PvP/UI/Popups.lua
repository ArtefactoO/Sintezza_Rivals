-- Sintezza Rivals / UI/Popups.lua
--
-- The two small frames that live outside the main window: the copy-out text
-- box (CSV export, reports, anything to paste elsewhere) and the watched-enemy
-- banner near the top of the screen.

local ADDON, root = ...
local ns = root.PvP

local U, X = ns.UI, ns.UIX
local rgb = X.rgb
local widgets = Sintezza_Theme:CreateWidgets(root.Theme)

--------------------------------------------------------------------- copy popup
local copyFrame

function U:CopyText(caption, text)
	if not copyFrame then
		copyFrame = ns.Theme.Window({
			name = "Sintezza_RivalsPvPCopy", width = 640, height = 380,
			windowAppearance = ns.WindowAppearance, defaultLayer = "DIALOG",
			title = "Copy out", subtitle = root.Text("Ctrl+C — копировать", "Ctrl+C — copy"),
		})
		copyFrame:SetFrameStrata("DIALOG")
		local eb = CreateFrame("EditBox", nil, copyFrame.content)
		eb:SetMultiLine(true)
		root.Theme:Font(eb, 12, "", root.Theme.text)
		eb:SetWidth(580)
		eb:SetAutoFocus(false)
		eb:SetScript("OnEscapePressed", function() copyFrame:Hide() end)
		local sf, _, bar = widgets:ScrollFrame(copyFrame.content, eb, 40)
		sf:SetPoint("TOPLEFT", 12, -8)
		sf:SetPoint("BOTTOMRIGHT", -30, 8)
		bar:SetPoint("TOPLEFT", sf, "TOPRIGHT", 4, 0)
		bar:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 4, 0)
		sf:HookScript("OnSizeChanged", function(_, width) eb:SetWidth(math.max(1, width)) end)
		-- the box grows with its text; the bar follows
		eb:SetScript("OnTextChanged", function() sf:RefreshRange() end)
		copyFrame.edit, copyFrame.scroll = eb, sf
	end
	copyFrame.title:SetText(caption)
	copyFrame.edit:SetText(text or "")
	copyFrame.scroll:SetVerticalScroll(0)
	copyFrame.edit:HighlightText()
	copyFrame:Show()
	copyFrame.edit:SetFocus()
end

function U:ShowCopyAll()
	Sintezza_Theme.DataTransfer:Open(UIParent, root.DataTransferSpec)
end
U.ShowCopy = function() U:ShowCopyAll() end

--------------------------------------------------------------------- banner
local banner

-- opts (optional): tag, the small line on top;
-- onClick, what a click does before the banner closes
function U:Banner(title, sub, classToken, opts)
	if not banner then
		banner = CreateFrame("Button", "Sintezza_RivalsPvPBanner", UIParent)
		banner:SetSize(440, 66)
		banner:SetPoint("TOP", UIParent, "TOP", 0, -140)
		banner:SetFrameStrata("DIALOG")
		banner:SetMovable(true)
		banner:RegisterForDrag("LeftButton")
		banner:SetScript("OnDragStart", function(self) self:StartMoving() end)
		banner:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

		banner.bg = banner:CreateTexture(nil, "BACKGROUND")
		banner.bg:SetAllPoints()
		Sintezza_Theme:Tint(banner.bg, "SetColorTexture", ns.Theme.C.bg, 0.95)
		ns.Theme.Border(banner, ns.Theme.C.line, 1)
		banner.accent = banner:CreateTexture(nil, "ARTWORK")
		banner.accent:SetPoint("TOPLEFT")
		banner.accent:SetPoint("BOTTOMLEFT")
		banner.accent:SetWidth(4)

		banner.icon = banner:CreateTexture(nil, "ARTWORK")
		banner.icon:SetSize(34, 34)
		banner.icon:SetPoint("LEFT", 14, 0)
		banner.icon:SetTexture("Interface\\WorldStateFrame\\ICONS-CLASSES")

		-- three fixed rows with explicit widths, so nothing can overlap
		banner.tag = ns.Theme.Font(banner, 11, ns.Theme.C.muted)
		banner.tag:SetPoint("TOPLEFT", 58, -8)
		banner.tag:SetWidth(250)
		banner.tag:SetJustifyH("LEFT")

		banner.title = ns.Theme.Font(banner, 14, ns.Theme.C.fg)
		banner.title:SetPoint("TOPLEFT", 58, -24)
		banner.title:SetWidth(370)
		banner.title:SetJustifyH("LEFT")
		banner.title:SetWordWrap(false)
		Sintezza_Theme:TrackAppearance(banner.title, "state", function(owner)
			owner:SetTextColor(rgb(banner.classToken))
		end)

		banner.sub = ns.Theme.Font(banner, 11, ns.Theme.C.muted)
		banner.sub:SetPoint("TOPLEFT", 58, -46)
		banner.sub:SetWidth(370)
		banner.sub:SetJustifyH("LEFT")
		banner.sub:SetWordWrap(false)


		banner:SetScript("OnClick", function(self)
			local act = self.onClick
			self.onClick = nil
			self:Hide()
			if act then ns:Guard(act) end
		end)
		banner:Hide()
	end

	banner.tag:SetText((opts and opts.tag) or ("|cffff5555" .. root.Text("ОТСЛЕЖИВАЕМЫЙ ПРОТИВНИК", "WATCHED ENEMY") .. "|r"))
	banner.onClick = opts and opts.onClick or nil
	banner.classToken = classToken
	local r, g, b = rgb(classToken)
	banner.accent:SetColorTexture(r, g, b, 0.9)
	banner.title:SetText(title or "")
	banner.title:SetTextColor(r, g, b)
	banner.sub:SetText(sub or "")
	if classToken and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classToken] then
		local t = CLASS_ICON_TCOORDS[classToken]
		banner.icon:SetTexCoord(t[1], t[2], t[3], t[4])
		banner.icon:Show()
	else
		banner.icon:Hide()
	end
	banner:Show()
	if banner.timer then banner.timer:Cancel() end
	banner.timer = C_Timer.NewTimer(8, function() if banner then banner:Hide() end end)
end
