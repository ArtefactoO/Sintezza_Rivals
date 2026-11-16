local _, root = ...
local ns = root.PvP
local X = ns.UIX
local L = ns.L
local EMPTY = "—"

local duelColumns = {
	{ "Opponent", 220, "LEFT", "name", nil, false }, { "Level", 50, "CENTER", "level" },
	{ "Side", 80, "CENTER", "side" }, { "Result", 264, "LEFT", "won" },
	{ "Fought in", 176, "LEFT", "zone" },
	{ "When", 68, "RIGHT", "last" },
}

local opponentColumns = {
	{ "Opponent", 220, "LEFT", "name", nil, false }, { "Level", 50, "CENTER", "level" },
	{ "Side", 80, "CENTER", "side" }, { "Record", 100, "CENTER", "wins" },
	{ "Win rate", 95, "CENTER", "rate" }, { "Last result", 240, "LEFT", "lastres" },
	{ "When", 68, "RIGHT", "last" },
}

local classColumns = {
	{ "Class", 245, "LEFT", "name", nil, false }, { "Duel count", 85, "RIGHT", "total" },
	{ "Duel wins", 80, "RIGHT", "wins" }, { "Duel losses", 100, "RIGHT", "losses" },
	{ "Unknown outcomes", 115, "RIGHT", "unknown" }, { "Win rate", 95, "RIGHT", "rate" },
	{ "Last duel", 103, "RIGHT", "last" },
}

X.TABS = {
	{
		title = "Stats",
		hint = root.Text("В открытом мире учитываются смерти с установленным противником.",
			"Open-world deaths count when attributed to an opponent."),
		cols = {
			{ root.Text("Режим", "Mode"), 200, "LEFT" },
			{ root.Text("Добивания / победы", "Kills / wins"), 180, "RIGHT" },
			{ root.Text("Смерти / поражения", "Deaths / losses"), 180, "RIGHT" },
			{ root.Text("Записано", "Recorded"), 200, "RIGHT" },
		},
		hideRowCount = true,
	},
}

function X.tabIndex(title)
	for i, tab in ipairs(X.TABS) do
		if tab.title == title then return i end
	end
end

function X.duelColumns(mode)
	if mode == "class" then return classColumns end
	return mode == "opponent" and opponentColumns or duelColumns
end

local function resultValue(duel)
	if duel.won == nil then return -1 end
	return duel.won and 1 or 0
end

local function resultText(duel)
	if duel.won == nil then return "|cffaaa8a2" .. L("Duel result unknown") .. "|r" end
	local color = duel.won and "|cff40ff40" or "|cffff6050"
	local result = color .. L(duel.won and "Duel win" or "Duel loss") .. "|r"
	if duel.kind == "retreat" then
		result = result .. " · " .. L(duel.won and "opponent fled" or "you fled")
	end
	return result
end

local function classOf(duel)
	return type(duel.class) == "string" and duel.class ~= "" and duel.class or false
end

local function className(class)
	if not class then return L("Unknown class") end
	return root.ClassName(class)
end

function X.duelClassQuery(class)
	return L("Class filter: %s"):format(class and className(class) or L("Unknown"))
end

function X.isDuelClassQuery(filter)
	local prefix = ns.Lower(L("Class filter: %s"):format(""))
	return filter and filter:sub(1, #prefix) == prefix
end

local function matches(filter, duel, exactClass)
	if not filter then return true end
	local class = classOf(duel)
	if exactClass then return filter == ns.Lower(X.duelClassQuery(class)) end
	local femaleNames = LOCALIZED_CLASS_NAMES_FEMALE
	local maleNames = LOCALIZED_CLASS_NAMES_MALE
	return X.hits(filter, duel.opponent, class, className(class), maleNames and maleNames[class], femaleNames and femaleNames[class],
		duel.zone, duel.faction, duel.faction and L(duel.faction))
end

local function levelText(level)
	return type(level) == "number" and level > 0 and tostring(level) or EMPTY
end

local function newer(a, b)
	return (a.ts or 0) > (b.ts or 0)
end

local function addDuelRow(name, class, timestamp, cells)
	X.add({ kind = "duel", name = name, class = class, color = class,
		agoCol = timestamp and timestamp > 0 and #cells or nil, agoTs = timestamp, cells = cells })
end

local duelSort = {
	name = function(d) return ns.Lower(d.opponent or "") end,
	level = function(d) return d.level or 0 end,
	won = resultValue,
	side = function(d) return d.faction or "" end,
	zone = function(d) return ns.Lower(d.zone or "") end,
	last = function(d) return d.ts or 0 end,
}

local function fillEachDuel(duels, filter)
	local visible = {}
	local exactClass = X.isDuelClassQuery(filter)
	for i = #duels, 1, -1 do
		local d = duels[i]
		if matches(filter, d, exactClass) then visible[#visible + 1] = d end
	end
	X.sortList(visible, duelSort, newer)
	for _, d in ipairs(visible) do
		addDuelRow(d.opponent, d.class, d.ts, { d.opponent or EMPTY, levelText(d.level),
			X.factionIcon(d.faction) or EMPTY, resultText(d), d.zone or EMPTY, EMPTY })
	end
	return #visible
end

local function winRate(entry)
	local decided = entry.wins + entry.losses
	return decided > 0 and entry.wins / decided or -1
end

local function rateText(entry)
	local rate = winRate(entry)
	return rate >= 0 and ("%.0f%%"):format(rate * 100) or EMPTY
end

local opponentSort = {
	name = function(entry) return ns.Lower(entry.name) end,
	level = function(entry) return entry.level or 0 end,
	side = function(entry) return entry.faction or "" end,
	wins = function(entry) return entry.wins end,
	rate = winRate,
	lastres = function(entry) return resultValue(entry.last) end,
	last = function(entry) return entry.ts end,
}

local classSort = {
	name = opponentSort.name,
	total = function(entry) return entry.wins + entry.losses + entry.unknown end,
	wins = opponentSort.wins,
	losses = function(entry) return entry.losses end,
	unknown = function(entry) return entry.unknown end,
	rate = winRate,
	last = opponentSort.last,
}

local function duelGroups(duels, filter, byClass)
	local groups, visible = {}, {}
	local exactClass = X.isDuelClassQuery(filter)
	for i = #duels, 1, -1 do
		local d = duels[i]
		local key = ns.Duels.OpponentKey(d.opponent) or EMPTY
		if byClass then key = classOf(d) end
		local entry = groups[key]
		if not entry then
			entry = { name = byClass and className(key) or (d.opponent or EMPTY), opponent = d.opponent, wins = 0, losses = 0,
				unknown = 0, last = d, ts = d.ts or 0 }
			groups[key] = entry
		end
		if d.won == true then entry.wins = entry.wins + 1
		elseif d.won == false then entry.losses = entry.losses + 1
		else entry.unknown = entry.unknown + 1 end
		entry.class, entry.faction, entry.level = entry.class or d.class, entry.faction or d.faction, entry.level or d.level
		if newer(d, entry.last) then entry.ts, entry.last = d.ts, d end
		if not entry.shown and matches(filter, d, exactClass) then
			entry.shown = true
			visible[#visible + 1] = entry
		end
	end
	return visible
end

local function fillDuelsByOpponent(duels, filter)
	local visible = duelGroups(duels, filter, false)
	X.sortList(visible, opponentSort, newer)
	for _, entry in ipairs(visible) do
		local record = ("|cff40ff40%d|r / |cffff6050%d|r"):format(entry.wins, entry.losses)
		if entry.unknown > 0 then record = record .. (" |cffaaa8a2+%d?|r"):format(entry.unknown) end
		addDuelRow(entry.opponent, entry.class, entry.ts, { entry.name, levelText(entry.level),
			X.factionIcon(entry.faction) or EMPTY, record, rateText(entry),
			resultText(entry.last), EMPTY })
	end
	return #visible
end

local function fillDuelsByClass(duels, filter, openClass)
	local visible = duelGroups(duels, filter, true)
	X.sortList(visible, classSort, function(a, b)
		if a.ts ~= b.ts then return a.ts > b.ts end
		return a.name < b.name
	end)
	for _, entry in ipairs(visible) do
		local class = classOf(entry.last)
		X.add({ kind = "duelClass", class = class or nil, color = class or nil,
			agoCol = entry.ts > 0 and 7 or nil, agoTs = entry.ts,
			toggle = function() openClass(class) end, toggleRow = true,
			cells = { entry.name, entry.wins + entry.losses + entry.unknown,
				("|cff40ff40%d|r"):format(entry.wins), ("|cffff6050%d|r"):format(entry.losses),
				entry.unknown, rateText(entry), EMPTY } })
	end
	return #visible
end

local duelFills = { every = fillEachDuel, opponent = fillDuelsByOpponent, class = fillDuelsByClass }
local duelFooters = { every = "Duels listed: %d", opponent = "Duel opponents: %d", class = "Duel classes: %d" }

function X.fillDuels(duels, mode, filter, openClass)
	local size = duelFills[mode](duels, filter, openClass)
	if size == 0 then
		X.add({ cells = { L(filter and "No matching duels" or "No recorded duels") } })
	end
	return L(duelFooters[mode]):format(size)
end
