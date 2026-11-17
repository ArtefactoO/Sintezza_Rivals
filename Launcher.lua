local addonName, ns = ...
local Launcher = {}
ns.Launcher = Launcher

function Launcher:RefreshMinimap(db)
    if self.icon then self.icon:Refresh(db) end
end

function Launcher:RegisterMinimap(title, icon, db, toggle)
    if self.icon then self:RefreshMinimap(db); return end
    self.icon = Sintezza_Theme:CreateMinimapButton(addonName, icon, db,
        toggle,
        function(tooltip)
            tooltip:AddLine(title)
            Sintezza_Theme:AddMinimapToggleHint(tooltip)
        end)
end
