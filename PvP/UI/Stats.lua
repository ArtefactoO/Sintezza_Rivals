local _, root = ...
local ns = root.PvP
local X = ns.UIX
local Text = root.Text

local function FillResults()
	local db = Sintezza_RivalsPvPDB
	local kills, deaths, opponents = 0, 0, 0
	for _, score in pairs(root.PvPSource:PlayerScores(db)) do
		kills, deaths = kills + score.kills, deaths + score.deaths
		opponents = opponents + 1
	end
	X.add({ cells = { Text("Открытый мир", "Open world"), kills, deaths,
		Text("Противников: %d", "Opponents: %d"):format(opponents) } })

	local bgKills, bgDeaths = 0, 0
	local matches = root.db.battlegrounds
	for _, match in ipairs(matches) do
		local matchKills, matchDeaths = root.PvPSource:BattlegroundScore(match)
		bgKills, bgDeaths = bgKills + matchKills, bgDeaths + matchDeaths
	end
	X.add({ cells = { Text("Поля боя", "Battlegrounds"), bgKills, bgDeaths,
		Text("Матчей: %d", "Matches: %d"):format(#matches) } })

	if ns:Module("duels") or #db.duels > 0 then
		local wins, losses = 0, 0
		for _, duel in ipairs(db.duels) do
			if duel.won == true then wins = wins + 1
			elseif duel.won == false then losses = losses + 1 end
		end
		X.add({ cells = { Text("Дуэли", "Duels"), wins, losses,
			Text("Дуэлей: %d", "Duels: %d"):format(#db.duels) } })
	end
end

local function FillData()
	for index = 1, 4 do
		local section = root.DataTransferSpec.sections[index]
		X.add({ cells = { section.label, section.count() } })
	end
end

local results = X.TABS[X.tabIndex("Stats")]
results.hint = ""
local overview = { cols = results.cols, note = results.note, hint = results.hint, fill = FillResults }
local records = {
	cols = { { Text("Записи", "Records"), 245, "LEFT" }, { Text("Количество", "Count"), 130, "RIGHT" } },
	note = Text("Данные текущего персонажа.", "Records for the current character."),
	fill = FillData,
}
local view = "results"
results.layoutColumns = overview.cols
results.fill = FillResults

function results.buildToolbar(parent)
	local theme = ns.Theme
	local widgets = Sintezza_Theme:CreateWidgets(root.Theme)
	local toolbar = CreateFrame("Frame", nil, parent)
	toolbar:SetPoint("TOPLEFT", 14, -51)
	toolbar:SetPoint("TOPRIGHT", -28, -51)
	toolbar:SetHeight(28)
	local switch = widgets:Segmented(toolbar, { Text("Результаты", "Results"), Text("Данные", "Data") },
		{ "results", "data" }, function() return view end, function(value)
			if value == view then return end
			view = value
			local page = value == "data" and records or overview
			results.cols, results.note, results.hint, results.fill = page.cols, page.note, page.hint, page.fill
			toolbar:Refresh()
			ns.UI:Refresh()
			X.scrollTo(0)
		end)
	switch:SetWidth(198)
	switch:SetPoint("LEFT")
	local maintenance = theme.Button(toolbar, Text("Обслуживание", "Maintenance"), 137, function()
		Sintezza_Theme.DataTransfer:OpenMaintenance(parent, root.DataTransferSpec)
	end)
	maintenance:SetPoint("RIGHT")
	local csv = theme.Button(toolbar, Text("Экспорт и импорт CSV", "Export and import CSV"), 172, function()
		Sintezza_Theme.DataTransfer:Open(parent, root.DataTransferSpec)
	end)
	csv:SetPoint("RIGHT", maintenance, "LEFT", -8, 0)
	function toolbar:Refresh()
		switch:Refresh()
		maintenance:SetShown(view == "data")
		csv:SetShown(view == "data")
	end
	return toolbar
end
