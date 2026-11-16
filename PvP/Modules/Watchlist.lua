local _, root = ...
local ns = root.PvP
local W = {}
ns.Watchlist = W
local now, Safe = GetServerTime or time, ns.Safe

local WATCH_CAP = 500

local function watchFull()
	return ns.Count(Sintezza_RivalsPvPDB.watch) >= WATCH_CAP
end

function W:IsWatched(key)
	return key and Sintezza_RivalsPvPDB.watch[key] ~= nil
end

function W:ToggleWatch(key, name, class)
	if not key then return end
	local w = Sintezza_RivalsPvPDB.watch
	if w[key] then
		w[key] = nil
		ns:Notify("action", "no longer watching %s", tostring(name or key))
		return false
	end
	if watchFull() then
		ns:Print("the watchlist is full (%d); unwatch someone first", WATCH_CAP)
		return false
	end
	w[key] = { name = name, class = class, ts = now() }
	ns:Notify("action", "watching %s: you will be told when you spot them", tostring(name or key))
	return true
end

function W:WatchTarget()
	if root.IsBattleground() then return end
	if not Safe(UnitExists("target")) or not Safe(UnitIsPlayer("target"))
		or not Safe(UnitCanAttack("player", "target")) then
		return ns:Print("target an enemy player first")
	end
	local guid = Safe(UnitGUID("target"))
	local name = ns.UnitCharacterName("target")
	local class = Safe(select(2, UnitClass("target")))
	W:ToggleWatch(guid or name, name, class)
	if ns.Nameplates then ns.Nameplates:RefreshAll() end
	if ns.UI then ns.UI:Refresh() end
end

-- called from Deaths when someone keeps killing you
function W:AutoWatch(key, name, class, killsOnMe)
	if not ns:IsRecording("fights") then return end
	local n = Sintezza_RivalsPvPDB.settings.autoWatchKills
	if not n or n <= 0 or killsOnMe < n then return end
	if Sintezza_RivalsPvPDB.watch[key] or watchFull() then return end
	Sintezza_RivalsPvPDB.watch[key] = { name = name, class = class, ts = now(), auto = true }
	ns:Notify("watched", "%s killed you %dx, added to the watchlist", tostring(name or key), killsOnMe)
end

