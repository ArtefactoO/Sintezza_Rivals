-- Sintezza Rivals / UI/Help.lua
--
-- Diagnostic report.

local ADDON, root = ...
local ns = root.PvP

local U = ns.UI
function U:ReportProblem()
	local db = Sintezza_RivalsPvPDB
	local b = db.build or {}
	local lines = {
		"Sintezza Rivals " .. tostring(ns.version),
		string.format(root.Text("Клиент %s, сборка %s, интерфейс %s", "Client %s, build %s, interface %s"), tostring(b.version), tostring(b.build), tostring(b.interface)),
		string.format(root.Text("Язык клиента %s, масштаб %s, тема %s, язык аддона %s", "Client language %s, scale %s, theme %s, addon language %s"),
			tostring(GetLocale and GetLocale()), tostring(db.settings.ui.scale),
			Sintezza_Theme:GetPalette(), root.locale),
		string.format(root.Text("Контекст %s, зона %s", "Context %s, zone %s"), tostring(ns.context), tostring(GetRealZoneText and GetRealZoneText())),
		string.format(root.Text("Встречи %d, смерти %d, добивания %d, дуэли %d, наблюдение %d", "Encounters %d, deaths %d, kills %d, duels %d, watched %d"),
			ns.Count(db.sightings), #db.deaths, #root.WorldKills(), #db.duels, ns.Count(db.watch)),
		"",
		root.Text("Что произошло", "What happened"),
		"",
		"",
		root.Text("Последние ошибки", "Recent errors"),
	}
	local errs = db.errors or {}
	for i = math.max(1, #errs - 7), #errs do
		local e = errs[i]
		lines[#lines + 1] = string.format("%s  %s", e.ts and date("%d.%m %H:%M", e.ts) or "?", tostring(e.msg))
	end
	if #errs == 0 then lines[#lines + 1] = root.Text("Нет ошибок", "No errors") end
	U:CopyText(root.Text("Отчет о проблеме", "Problem report"), table.concat(lines, "\n"))
end
