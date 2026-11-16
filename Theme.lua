local _, ns = ...
local shared = Sintezza_Theme
ns.InterfaceFonts = shared.Fonts
ns.Theme = shared:ForAddon(function() return ns.db end)

function ns.CreateParticipantMarker(parent)
    local marker = CreateFrame("Frame", nil, parent)
    marker:SetSize(8, 8)
    local vertical = marker:CreateTexture(nil, "OVERLAY")
    vertical:SetPoint("TOPLEFT")
    vertical:SetSize(1, 7)
    local horizontal = marker:CreateTexture(nil, "OVERLAY")
    horizontal:SetPoint("BOTTOMLEFT", vertical, "BOTTOMLEFT")
    horizontal:SetSize(7, 1)
    shared:Tint(vertical, "SetColorTexture", ns.Theme.muted)
    shared:Tint(horizontal, "SetColorTexture", ns.Theme.muted)
    marker:Hide()
    return marker
end
