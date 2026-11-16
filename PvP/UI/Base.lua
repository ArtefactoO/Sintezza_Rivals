-- Sintezza Rivals / UI/Base.lua
--
-- The main window is split over the files in UI/. This one loads first: it
-- creates the UI module, the shared state table X (ns.UIX) and the small text
-- helpers every tab uses. Window state that more than one file reads or writes
-- (the selected tab, the sort, the list frame) lives on X and nowhere else, so
-- no file depends on another file's locals.

local ADDON, root = ...
local ns = root.PvP

local U = {}
ns.UI = U
ns.modules.UI = U

local X = {}
ns.UIX = X

X.now = _G.GetServerTime or time
X.W, X.H = 1000, 700
U.DEFAULT_W, U.DEFAULT_H = X.W, X.H
X.ROW_H = 24

-- window state; the frames are filled in by UI/Window.lua when it builds
X.rows, X.numRows = {}, 0
X.selected, X.sortKey, X.sortDesc = 1, nil, true
-- the row descriptors of the current tab; wiped and refilled, never replaced
X.data = {}

X.rgb = ns.ClassRGB
X.ago = ns.Ago
function X.factionIcon(faction, size)
	local theme = Sintezza_Theme
	local tex = theme.GetFactionCrest and theme:GetFactionCrest(faction)
	if not tex then return nil end
	size = size or 16
	return string.format("|T%s:%d:%d:0:0|t", tex, size, size)
end

-- the race token reads "Scourge" or "NightElf"; the localized name is preferred
local RACE_FALLBACK = {
	Scourge = "Undead", NightElf = "Night Elf", BloodElf = "Blood Elf",
	HighmountainTauren = "Highmountain", LightforgedDraenei = "Lightforged",
	VoidElf = "Void Elf", DarkIronDwarf = "Dark Iron", MagharOrc = "Mag'har",
	ZandalariTroll = "Zandalari", KulTiran = "Kul Tiran",
}

function X.raceText(rec)
	return rec.raceName or RACE_FALLBACK[rec.race or ""] or rec.race or "?"
end

function X.coords(x, y)
	if not x or not y then return "-" end
	return string.format("%.1f, %.1f", x * 100, y * 100)
end

-- the current tab's filter text, lowercased, or nil when the box is empty
function X.filterText()
	local box = X.filterBox
	local f = box and box:GetText() or ""
	return f ~= "" and ns.Lower(f) or nil
end

function X.hits(f, ...)
	if not f then return true end
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if v and string.find(ns.Lower(tostring(v)), f, 1, true) then return true end
	end
	return false
end

function X.isWatched(key)
	return ns.Watchlist and ns.Watchlist:IsWatched(key)
end

