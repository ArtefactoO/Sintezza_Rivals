-- Sintezza Rivals / Core.lua: namespace, DB, Safe(), logger, context, event bus, slash
local ADDON, root = ...
local ns = root.PvP
_G.Sintezza_RivalsPvP = ns

ns.version = "1.15.0"
ns.modules = ns.modules or {}
ns.SIGHTING_LIMIT = 1000
ns.WindowAppearance = Sintezza_Theme:NewWindowPreferences(function()
	local db = Sintezza_RivalsPvPDB
	return db and db.settings and db.settings.ui
end, function(ui)
	return { scale = (tonumber(ui.scale) or 1) * 100, opacity = (tonumber(ui.alpha) or 1) * 100, locked = ui.locked }
end)
if Sintezza_Theme.RegisterGlobalWindowPreferences then
    Sintezza_Theme:RegisterGlobalWindowPreferences("Sintezza Rivals", ns.WindowAppearance)
end

function ns.WindowAppearance:OnReset()
	local ui = Sintezza_RivalsPvPDB.settings.ui
	ui.point, ui.x, ui.y = "CENTER", 0, 0
end

function ns.WindowAppearance:OnResetSize()
	local ui = Sintezza_RivalsPvPDB.settings.ui
	ui.w, ui.h = nil, nil
end

local now = _G.GetServerTime or time

----------------------------------------------------------------- print / secrets
-- every printed line goes through the locale table, so a translation only has
-- to map the format strings; ns.LOCALE is filled by a Locales file if present
ns.LOCALE = {}

function ns.L(text)
	return ns.LOCALE[text] or text
end

local cyrillicLower = { ["\208\129"] = "\209\145" }
for i = 144, 175 do
	cyrillicLower[string.char(208, i)] = i < 160 and string.char(208, i + 32) or string.char(209, i - 32)
end

function ns.Lower(text)
	return (text:gsub("[A-Z]", string.lower):gsub("[\208\209][\128-\191]", cyrillicLower))
end

function ns:Print(fmt, ...)
	fmt = ns.LOCALE[fmt] or fmt
	local ok, msg = pcall(string.format, fmt, ...)
	print("|cff33ff99[Sintezza Rivals]|r " .. (ok and msg or tostring(fmt)))
end

-- issecretvalue is a real global on this build (verified in BetterBlizzFrames/forever);
-- keep a comparison-based fallback so a rename cannot kill the addon.
local issecret = _G.issecretvalue
if type(issecret) ~= "function" then
	ns.secretGlobalMissing = true
	issecret = function(v) return not pcall(function() return v == v end) end
end
ns.IsSecret = issecret

-- Safe(v): nil for secrets, value otherwise. Anything concatenated, compared,
-- formatted or used as a table key must pass through this first.
function ns.Safe(v)
	if issecret(v) then return nil end
	return v
end

function ns.CharacterNameKey(name)
	if type(name) ~= "string" then return nil end
	name = name:match("^%s*(.-)%s*$"):gsub("%s+", " ")
	if name ~= "" then return ns.Lower(name) end
end

function ns.UnitCharacterName(unit)
	local name, surname = root.Read(UnitNameUnmodified, unit)
	if not name or name == "" then
		name, surname = root.Read(UnitName, unit), nil
	end
	if type(name) ~= "string" or name == "" then return nil end
	if type(surname) == "string" and surname ~= "" then
		local separator = Constants and Constants.CharacterNameSeparatorConsts
			and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR or " "
		local suffix = separator .. surname
		if #name > #suffix and name:sub(-#suffix) == suffix then name = name:sub(1, -#suffix - 1) end
		suffix = " " .. surname
		if name:sub(-#suffix) ~= suffix then name = name .. suffix end
	end
	return name
end

-- Display names for the actions in the root Bindings.xml.
BINDING_HEADER_RIVALSPVP = "Sintezza Rivals"
BINDING_NAME_RIVALSPVP_TOGGLE = root.Text("Главное окно", "Main window")
BINDING_NAME_RIVALSPVP_WATCH = root.Text("Переключить наблюдение за целью", "Toggle watching the target")
BINDING_NAME_RIVALSPVP_HUD = root.Text("Переключить панель встреч", "Toggle encounters display")

----------------------------------------------------------------- small shared helpers
function ns.Count(t)
	local n = 0
	if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
	return n
end

function ns.Ago(ts)
	local d = now() - (ts or 0)
	if d < 0 then d = 0 end
	if d < 60 then return ns.L("%ds"):format(d) end
	if d < 3600 then return ns.L("%dm"):format(math.floor(d / 60)) end
	if d < 86400 then return ns.L("%dh"):format(math.floor(d / 3600)) end
	return ns.L("%dd"):format(math.floor(d / 86400))
end

-- a plain table lookup: this runs per pin and per row and must not allocate
function ns.ClassRGB(token)
	local c = token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
	if c and c.r then return c.r, c.g, c.b end
	return 0.78, 0.78, 0.78
end

----------------------------------------------------------------- DB
local defaults = {
	version = ns.version,
	build = nil,
	settings = {
		enabled = true,
		-- the probe is discovery tooling and stays off unless asked for: it costs
		-- memory and a battery run per context
		probe = { autoRun = false },
		-- logging is opt-in: warnings and errors are always kept, the chatty
		-- info/raw lines are not
		debug = { logging = false, raw = false, logCap = 400, autoTidy = true },
		autoWatchKills = 0,
		sightings = { fromNameplates = true, fromTarget = true, fromMouseover = true, dedupeSeconds = 60 },
		-- chat stays quiet by default: a line per enemy spotted spams the frame.
		-- Watched enemies, deaths and kills still announce themselves.
		alerts = { soundOnSighting = true, minLevelDiff = -5,
			-- which categories of the addon's own messages reach the chat frame.
			chat = { watched = true, death = true, kill = true,
				zone = true, duel = true, sighting = false,
				action = false },
			watchSeconds = 20, banner = true,
			stealthCast = true, unitTooltip = true,
			screenshotOnDeath = false, stealthSound = true },
		ui = { point = "CENTER", x = 0, y = 0, scale = 1, scale100 = 100, locked = false, shown = false,
			defaultTab = 0,
			alpha = 1, alpha100 = 100, views = {} },
		modules = { enemies = true, fights = true, battlegrounds = true, duels = true, map = true },
		map = { enabled = false, sightings = false, deaths = true, kills = true, minutes = 180,
			useTomTom = true },
		minimap = { enabled = false, watchedOnly = true, deaths = false, minutes = 30,
			floatOnEdge = true },
		hud = { show = false, point = "TOP", x = 0, y = -220, locked = false, width = 300 },
	},
	sightings     = {},
	incoming      = {},   -- completed fights with confirmed damage from players
	zones         = {},
	sightingStats = { total = 0, secretFields = {} },
	deaths        = {},
	nemesis       = {},
	watch         = {},   -- key -> { name, class, ts } enemies worth a shout
	ignore        = {},   -- key -> true, never alert about these
	duels         = {},   -- duel results: opponent, class, won, where
	probe        = {},
	log          = {},
	errors       = {},
	rawCounts    = {},
	blockedItems = {},   -- probe item -> protected function that blocked it
}

local function merge(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			merge(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

local function MigrateRemovedViews(db)
	db.feed, db.honor, db.settings.debug.honorHistory = nil, nil, nil
	for _, zone in pairs(db.zones) do zone.hourly = nil end
	local ui = db.settings.ui
	ui.chartMetric, ui.chartPeriod, ui.watchedOnly = nil, nil, nil
	if ui.defaultTab == 6 then ui.defaultTab = 9 end
	local duels = db.settings.modules.duels ~= false
	local oldTabs = { "rivalsHistory", "rivalsNameplates", "rivalsHistory", duels and "Duels" or "Stats", "Stats" }
	ui.tabKey = ui.tabKey == "Log" and "rivalsHistory" or ui.tabKey or oldTabs[ui.tab]
	if type(ui.sort) == "table" then
		ui.sort.rivalsHistory = ui.sort.rivalsHistory or ui.sort[1]
		if duels then ui.sort.Duels = ui.sort.Duels or ui.sort[4] end
		for i = 1, 5 do ui.sort[i] = nil end
	end
end

function ns:WantsNotification(category)
	if category ~= "action" and not self:IsRecording() then return false end
	local db = Sintezza_RivalsPvPDB
	local alerts = db and db.settings and db.settings.alerts
	return alerts and alerts.chat[category]
end

function ns:Notify(category, fmt, ...)
	if self:WantsNotification(category) then self:Print(fmt, ...) end
end

----------------------------------------------------------------- logger
-- ring buffer caps: the log cap is user-settable because it is the only part
-- of the saved data that can grow without a hard limit
local ERR_CAP, RAW_PER_KIND = 100, 20
local function logCap()
	local d = Sintezza_RivalsPvPDB and Sintezza_RivalsPvPDB.settings and Sintezza_RivalsPvPDB.settings.debug
	return (d and d.logCap) or 400
end

function ns:Log(level, fmt, ...)
	local db = Sintezza_RivalsPvPDB
	if not db then return end
	-- info lines are dropped unless logging is switched on; warn and error are
	-- always kept, they are rare and they are the ones worth reading
	if level == "info" and not (db.settings and db.settings.debug and db.settings.debug.logging) then
		return
	end
	local msg
	if select("#", ...) > 0 then
		local ok, res = pcall(string.format, fmt, ...)
		msg = ok and res or ("<format failed: secret arg?> " .. tostring(fmt))
		if not ok then db.secretFormatFailure = true end
	else
		msg = tostring(fmt)
	end
	local t = db.log
	t[#t + 1] = { ts = now(), ctx = ns.context, level = level, msg = msg }
	while #t > logCap() do table.remove(t, 1) end
end

-- verbatim event/chat payloads for later pattern work, capped per kind
function ns:LogRaw(kind, text)
	local db = Sintezza_RivalsPvPDB
	if not db then return end
	if not (db.settings and db.settings.debug and db.settings.debug.raw) then return end
	text = ns.Safe(text)
	if text == nil then
		kind = kind .. "(secret)"
		text = "<secret>"
	end
	local n = (db.rawCounts[kind] or 0) + 1
	db.rawCounts[kind] = n
	if n > RAW_PER_KIND then return end
	local t = db.log
	t[#t + 1] = { ts = now(), ctx = ns.context, level = "raw", msg = kind .. " :: " .. tostring(text) }
	while #t > logCap() do table.remove(t, 1) end
end

function ns:Err(msg, trace)
	local db = Sintezza_RivalsPvPDB
	if not db then return end
	msg = tostring(msg)
	for _, e in ipairs(db.errors) do
		if e.msg == msg then
			e.count = (e.count or 1) + 1
			e.ts = now()
			return
		end
	end
	db.errors[#db.errors + 1] = {
		ts = now(), ctx = ns.context, msg = msg, count = 1,
		trace = trace and string.sub(tostring(trace), 1, 1500) or nil,
	}
	while #db.errors > ERR_CAP do table.remove(db.errors, 1) end
end

local function errHandler(err)
	local trace = _G.debugstack and debugstack(2, 8, 8) or nil
	ns:Err(err, trace)
	return err
end

-- Guard wraps rare calls (slash commands, timers, module init) and keeps a
-- traceback. Called with arguments it allocates a table and a closure, so a
-- hot path either passes none or uses dispatch() below.
function ns:Guard(fn, ...)
	-- the common case has no arguments and must not build a table and a
	-- closure for them: tickers call this several times a second
	if select("#", ...) == 0 then return xpcall(fn, errHandler) end
	local n, args = select("#", ...), { ... }
	return xpcall(function() return fn(unpack(args, 1, n)) end, errHandler)
end

-- Hot path: pcall takes arguments natively, so this allocates nothing per
-- event. Events like UNIT_HEALTH fire dozens of times a second.
local function dispatch(fn, event, ...)
	local ok, err = pcall(fn, event, ...)
	if not ok then ns:Err(err) end
end

----------------------------------------------------------------- context
function ns:GetContext()
	if root.IsBattleground() then return "bg" end
	local _, itype = root.Read(IsInInstance)
	if not itype then return "unknown" end
	if itype == "arena" then return "arena" end
	if itype == "party" then return "dungeon" end
	if itype == "raid"  then return "raid" end
	local okc, c = pcall(UnitAffectingCombat, "player")
	if okc and ns.Safe(c) then return "world_combat" end
	return "world"
end

function ns:ZoneInfo()
	local okZ, zone = pcall(GetRealZoneText)
	local okS, sub  = pcall(GetSubZoneText)
	local mapID
	if C_Map and C_Map.GetBestMapForUnit then
		local okM, m = pcall(C_Map.GetBestMapForUnit, "player")
		if okM then mapID = ns.Safe(m) end
	end
	return (okZ and ns.Safe(zone)) or "?", (okS and ns.Safe(sub)) or "", mapID
end

local function updateContext(why)
	local new = ns:GetContext()
	if new ~= ns.context then
		local old = ns.context
		ns.context = new
		local zone, sub, mapID = ns:ZoneInfo()
		ns:Log("info", "context %s -> %s (%s) zone=%s/%s mapID=%s",
			tostring(old), new, tostring(why), tostring(zone), tostring(sub), tostring(mapID))
		for _, m in pairs(ns.modules) do
			if m.OnContextChanged then ns:Guard(m.OnContextChanged, m, new, old) end
		end
	end
end

----------------------------------------------------------------- event bus
local f = CreateFrame("Frame", "Sintezza_RivalsPvPEventFrame")
ns.frame = f
local listeners = {}

function ns:On(event, fn)
	if not listeners[event] then
		listeners[event] = {}
		local ok, err = pcall(f.RegisterEvent, f, event)
		if not ok then ns:Err("RegisterEvent failed for " .. tostring(event) .. ": " .. tostring(err)) end
	end
	listeners[event][#listeners[event] + 1] = fn
end

function ns:Off(event)
	listeners[event] = nil
	pcall(f.UnregisterEvent, f, event)
end

f:SetScript("OnEvent", function(_, event, ...)
	local l = listeners[event]
	if not l then return end
	for i = 1, #l do dispatch(l[i], event, ...) end
end)

----------------------------------------------------------------- bootstrap
local initialized = false

ns:On("ADDON_LOADED", function(_, name)
	if name ~= ADDON or initialized then return end
	initialized = true

	Sintezza_RivalsPvPDB = Sintezza_RivalsPvPDB or {}
	local oldVersion = Sintezza_RivalsPvPDB.version
	local oldSettings = Sintezza_RivalsPvPDB.settings
	local oldModules = type(oldSettings) == "table" and oldSettings.modules
	if type(oldModules) == "table" and oldModules.battlegrounds == nil then
		oldModules.battlegrounds = oldModules.fights ~= false
	end
	local oldMap = type(oldSettings) == "table" and oldSettings.map
	local oldMajor, oldMinor = tostring(oldVersion):match("^(%d+)%.(%d+)")
	local hideLegacySightings = type(oldMap) == "table" and oldMap.enabled == false
		and (not oldMajor or tonumber(oldMajor) == 1 and tonumber(oldMinor) < 6)
	merge(Sintezza_RivalsPvPDB, defaults)
	local db = Sintezza_RivalsPvPDB
	local alerts, ui = db.settings.alerts, db.settings.ui
	if alerts.zoneWarning ~= nil then
		alerts.chat.zone = alerts.zoneWarning and alerts.chat.zone or false
		alerts.zoneWarning = nil
	end
	if ui.showMarkers == nil then ui.showMarkers = db.settings.enabled ~= false end
	if hideLegacySightings then db.settings.map.sightings = false end
	local oldSharing = db.settings.comms
	if type(oldSharing) == "table" and type(oldSharing.autoWatchKills) == "number" then
		db.settings.autoWatchKills = oldSharing.autoWatchKills
	end
	db.settings.comms, db.settings.modules.sharing = nil, nil
	db.settings.map.groups, db.settings.map.sideDeaths = nil, nil
	db.settings.groups, db.settings.minimap.allies, db.settings.minimap.helpArrow = nil, nil, nil
	db.settings.alerts.helpMinutes, db.settings.alerts.helpCooldown = nil, nil
	db.settings.alerts.chat.help, db.settings.alerts.chat.comms, db.settings.alerts.chat.group = nil, nil, nil
	db.settings.alerts.spikeAlert, db.settings.alerts.spikeJump, db.settings.alerts.chat.spike = nil, nil, nil
	db.comms, db.reports, db.helpCalls, db.sideDeaths = nil, nil, nil, nil
	db.settings.modules.wanted, db.settings.ui.skin = nil, nil
	for _, field in ipairs({ "wanted", "community", "kills" }) do
		if type(db[field]) == "table" and not next(db[field]) then db[field] = nil end
	end
	for key, sighting in pairs(db.sightings) do
		if sighting.lastSource == "comms" then db.sightings[key] = nil end
	end
	if oldVersion ~= ns.version then MigrateRemovedViews(db) end
	if db.settings.ui.tabKey == "Duels" then
		db.settings.ui.tabKey, db.settings.ui.historyView = "rivalsHistory", "duels"
	end
	Sintezza_RivalsPvPDB.version = ns.version
	Sintezza_RivalsPvPCharDB = Sintezza_RivalsPvPCharDB or {}

	local v, b, d, iface = GetBuildInfo()
	Sintezza_RivalsPvPDB.build = {
		version = tostring(v), build = tostring(b), date = tostring(d), interface = tostring(iface),
	}
	ns.context = ns:GetContext()
	ns:Log("info", "loaded %s on %s build %s (interface %s)", ns.version, tostring(v), tostring(b), tostring(iface))
	if ns.secretGlobalMissing then ns:Log("warn", "global issecretvalue missing, using comparison fallback") end

	Sintezza_RivalsPvPCharDB.name  = ns.UnitCharacterName("player")
	Sintezza_RivalsPvPCharDB.realm = ns.Safe(GetRealmName and GetRealmName())
	Sintezza_RivalsPvPCharDB.class = ns.Safe(select(2, UnitClass("player")))
	Sintezza_RivalsPvPCharDB.guid  = ns.Safe(UnitGUID("player"))

	for _, m in pairs(ns.modules) do
		if m.Init then ns:Guard(m.Init, m) end
	end
	if root.ConnectPvP then root.ConnectPvP() end
end)

ns:On("PLAYER_LOGIN", function()
	updateContext("PLAYER_LOGIN")
	for _, m in pairs(ns.modules) do
		if m.Enable then ns:Guard(m.Enable, m) end
	end
end)

for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
	ns:On(e, function(event) updateContext(event) end)
end

----------------------------------------------------------------- blocked actions
-- "blocked from an action only available to the Blizzard UI" is not a Lua error,
-- so this event is the only way to learn which call is protected. It lives here
-- rather than in the probe, because it is worth catching during normal play too.
ns:On("ADDON_ACTION_BLOCKED", function(event, addonName, funcName)
	ns:Log("warn", "%s addon=%s func=%s ctx=%s", event, tostring(ns.Safe(addonName)),
		tostring(ns.Safe(funcName)), tostring(ns.context))
	if ns.Safe(addonName) ~= ADDON then return end
	local item = ns.Probe and ns.Probe.current
	if item then
		Sintezza_RivalsPvPDB.blockedItems[item] = tostring(ns.Safe(funcName) or "?")
		ns:Print("BLOCKED func=%s on item=%s, skipped from now on", tostring(ns.Safe(funcName)), item)
	end
end)
ns:On("ADDON_ACTION_FORBIDDEN", function(event, addonName, funcName)
	ns:Log("warn", "%s addon=%s func=%s ctx=%s", event, tostring(ns.Safe(addonName)),
		tostring(ns.Safe(funcName)), tostring(ns.context))
end)

----------------------------------------------------------------- keeping tidy
-- WoW shows each addon the memory it has allocated since the last collection, so
-- the number in the add-on list climbs for every addon until Lua happens to run a
-- full cycle. Nobody should have to click anything to keep that honest, so we
-- nudge the collector along out of combat: an incremental step costs a fraction
-- of a millisecond and never produces the hitch a full collect can.
local function tidyStep()
	if InCombatLockdown and InCombatLockdown() then return end
	collectgarbage("step", 400)
end

-- every twenty seconds is often enough to keep the figure from climbing and rare
-- enough to be free
C_Timer.NewTicker(20, function()
	local db = Sintezza_RivalsPvPDB
	if db and db.settings and db.settings.debug and db.settings.debug.autoTidy then tidyStep() end
end)

function ns:Tidy()
	collectgarbage("collect")
	if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
		UpdateAddOnMemoryUsage()
		ns:Print("tidied up, now holding %.2f MB", (GetAddOnMemoryUsage(ADDON) or 0) / 1024)
	else
		ns:Print("tidied up")
	end
end

function ns:Module(key)
	local m = Sintezza_RivalsPvPDB and Sintezza_RivalsPvPDB.settings and Sintezza_RivalsPvPDB.settings.modules
	return not m or m[key] ~= false
end

function ns:IsRecording(module)
	local db = Sintezza_RivalsPvPDB
	return db and db.settings and db.settings.enabled and (not module or self:Module(module))
end

function ns:OnRecordingChanged(enabled)
	if not enabled then
		self.Deaths:StopRecording()
		self.Duels:StopRecording()
	end
	root.Changed()
end

-- Development mode: the RivalsPvP_Probe add-on is installed. Demo data, the self
-- test and the Diagnostics page exist only then; a normal install never sees
-- them. GetAddOnInfo echoes the name back even for an addon that is not there,
-- so DoesAddOnExist is asked first and the reason field is the fallback.
local devMode
function ns:IsDev()
	if devMode == nil then
		devMode = false
		if C_AddOns and C_AddOns.DoesAddOnExist then
			devMode = C_AddOns.DoesAddOnExist("RivalsPvP_Probe") and true or false
		elseif C_AddOns and C_AddOns.GetAddOnInfo then
			local _, _, _, _, reason = C_AddOns.GetAddOnInfo("RivalsPvP_Probe")
			devMode = reason ~= "MISSING"
		end
	end
	return devMode
end

function ns:EnsureProbe()
	if ns.Probe then return true end
	local load = (C_AddOns and C_AddOns.LoadAddOn) or _G.LoadAddOn
	if load and ns:IsDev() then
		_G.RivalsPvP = _G.RivalsPvP or ns
		pcall(load, "RivalsPvP_Probe")
	end
	if not ns.Probe then
		ns:Print("the probe module is not installed: add the RivalsPvP_Probe folder next to this one")
		return false
	end
	return true
end

----------------------------------------------------------------- slash
local pendingClear
local count = ns.Count

local function status()
	local db = Sintezza_RivalsPvPDB
	local zone, sub, mapID = ns:ZoneInfo()
	ns:Print("context=%s zone=%s%s mapID=%s", tostring(ns.context), tostring(zone),
		(sub ~= "" and (" / " .. sub) or ""), tostring(mapID))
	ns:Print("build=%s %s interface=%s addon=%s",
		db.build.version, db.build.build, db.build.interface, ns.version)
	local ctxs = {}
	for k, v in pairs(db.probe) do
		local s = v.summary
		ctxs[#ctxs + 1] = string.format("%s[ok=%d sec=%d nil=%d err=%d miss=%d blk=%d]", k,
			(s and s.ok) or 0, (s and s.secret) or 0, (s and s["nil"]) or 0,
			(s and s.error) or 0, (s and s.missing) or 0, (s and s.blocked) or 0)
	end
	table.sort(ctxs)
	ns:Print("probed: %s", #ctxs > 0 and table.concat(ctxs, " ") or root.Text("пока ничего", "nothing yet"))
	ns:Print("log=%d raw-kinds=%d errors=%d blocked=%d",
		#db.log, count(db.rawCounts), #db.errors, count(db.blockedItems))
	for item, func in pairs(db.blockedItems) do
		ns:Print("blocked: %s -> %s", item, tostring(func))
	end
	ns:Print("sightings=%d zones=%d deaths=%d kills=%d nemesis=%d (alerts %s)",
		count(db.sightings), count(db.zones), #db.deaths, #root.WorldKills(), count(db.nemesis),
		ns.L(db.settings.alerts.chat.sighting and "on" or "off"))
	local sf = {}
	for field, n in pairs(db.sightingStats.secretFields) do sf[#sf + 1] = field .. "=" .. n end
	if #sf > 0 then ns:Print("secret/missing sighting fields: %s", table.concat(sf, " ")) end
	if #db.errors > 0 then ns:Print("last error: %s", tostring(db.errors[#db.errors].msg)) end
end

-- /rivals mem: the facts: what survives a collection, what the whole interface
-- costs for comparison, what is stored, and whether repainting the window leaks
local function memory()
	local db = Sintezza_RivalsPvPDB
	local function live(name)
		if not (UpdateAddOnMemoryUsage and GetAddOnMemoryUsage) then return 0 end
		UpdateAddOnMemoryUsage()
		return GetAddOnMemoryUsage(name) or 0
	end

	if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
		UpdateAddOnMemoryUsage()
		local before = GetAddOnMemoryUsage(ADDON) or 0
		collectgarbage("collect")
		local mine = live(ADDON)
		local probe = live("RivalsPvP_Probe")
		local total = collectgarbage("count") or 0
		ns:Print("|cff40ff40live: %.2f MB|r%s   (before the collect: %.2f MB, so %.1f MB was garbage)",
			mine / 1024, probe > 0 and root.Text(" + %.2f МБ (модуль проверки)", " + %.2f MB probe"):format(probe / 1024) or "",
			before / 1024, (before - mine) / 1024)
		ns:Print("the whole interface, every addon included: %.1f MB", total / 1024)

		-- does repainting leak? twenty full rebuilds, then collect and compare
		if ns.UI and ns.UI.Refresh then
			local base = mine
			for _ = 1, 20 do
				ns.UI:MarkDirty()
				pcall(function() ns.UI:Refresh() end)
			end
			collectgarbage("collect")
			local after = live(ADDON)
			ns:Print("twenty window rebuilds left %+.0f KB behind; anything under ~20 KB is noise",
				after - base)
		end
	else
		ns:Print("memory API unavailable")
	end
	local probeItems = 0
	for _, ctx in pairs(db.probe) do
		for _ in pairs(ctx.results or {}) do probeItems = probeItems + 1 end
	end
	ns:Print("stored: %d sightings, %d zones, %d deaths, %d kills, %d nemesis, %d watched",
		count(db.sightings), count(db.zones), #db.deaths, #root.WorldKills(),
		count(db.nemesis), count(db.watch))
	ns:Print("logs: %d lines (cap %d), %d errors, %d probe rows in %d contexts",
		#db.log, (db.settings.debug.logCap or 400), #db.errors, probeItems, count(db.probe))
	if probeItems > 200 then
		ns:Print("the probe results are the biggest thing stored; |cffffd100/rivals clear probe|r frees them")
	end
	ns:Print("logging=%s raw=%s probe autoRun=%s; all three are off by default",
		tostring(db.settings.debug.logging), tostring(db.settings.debug.raw),
		tostring(db.settings.probe.autoRun))

	-- How fast garbage piles up while you play: what the addon allocates in
	-- twenty seconds, measured right after a collect so nothing is freed in
	-- between. This is the number behind "it grows until a tidy".
	if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
		collectgarbage("collect")
		UpdateAddOnMemoryUsage()
		local start = GetAddOnMemoryUsage(ADDON) or 0
		local open = ns.UI and ns.UI.IsShown and ns.UI:IsShown()
		ns:Print("measuring what the addon allocates for 20 seconds...")
		C_Timer.After(20, function()
			UpdateAddOnMemoryUsage()
			local grew = math.max(0, (GetAddOnMemoryUsage(ADDON) or 0) - start)
			ns:Print("allocating about %.1f KB/s (%.1f MB an hour) with the window %s",
				grew / 20, grew / 20 * 3600 / 1024, ns.L(open and "open" or "closed"))
		end)
	end
end

local function selftest()
	-- smallest runnable check of the probe classifier
	if not ns:EnsureProbe() then return end
	local C = ns.Probe and ns.Probe.Classify
	if not C then return ns:Print("selftest FAIL: classifier missing") end
	local cases = {
		{ "ok",      C("t", function() return "hello" end).status },
		{ "nil",     C("t", function() return nil end).status },
		{ "error",   C("t", function() error("boom") end).status },
		{ "missing", C("t", function() end, "No.Such.Api").status },
	}
	local bad = 0
	for _, c in ipairs(cases) do
		if c[1] ~= c[2] then
			bad = bad + 1
			ns:Print("selftest: expected %s, got %s", c[1], tostring(c[2]))
		end
	end
	ns:Print("selftest %s (%d/%d)", bad == 0 and "PASS" or "FAIL", #cases - bad, #cases)
end

local function clear(what)
	local db = Sintezza_RivalsPvPDB
	local sections = { log = true, errors = true, probe = true, raw = true, all = true }
	if not sections[what or ""] then
		return ns:Print("usage: /rivals clear log|errors|probe|raw|all")
	end
	if pendingClear ~= what then
		pendingClear = what
		C_Timer.After(10, function() if pendingClear == what then pendingClear = nil end end)
		return ns:Print("repeat /rivals clear %s within 10s to confirm", what)
	end
	pendingClear = nil
	if what == "log"    or what == "all" then db.log = {} end
	if what == "errors" or what == "all" then db.errors = {} end
	if what == "probe"  or what == "all" then db.probe = {} end
	if what == "raw"    or what == "all" then db.rawCounts = {} end
	ns:Print("cleared %s", what)
end

local function export()
	local db = Sintezza_RivalsPvPDB
	local probed = {}
	for k in pairs(db.probe) do probed[#probed + 1] = k end
	db.exportMeta = {
		ts = now(), build = db.build, char = Sintezza_RivalsPvPCharDB,
		errorCount = #db.errors, logCount = #db.log, contextsProbed = probed,
	}
	ns:Print("export stamped (%d contexts, %d errors). Now /reload or logout, then send:",
		#probed, #db.errors)
	ns:Print("WTF/Account/<ACCOUNT>/<REALM>/<CHARACTER>/SavedVariables/Sintezza_Rivals.lua")
end

SLASH_SINTEZZA_RIVALS_PVP1 = "/rivalspvp"
SlashCmdList.SINTEZZA_RIVALS_PVP = function(msg)
	msg = string.lower(string.gsub(msg or "", "^%s+", ""))
	local cmd, rest = string.match(msg, "^(%S*)%s*(.-)$")
	ns:Guard(function()
		if cmd == "" or cmd == "toggle" then
			ns.UI:Toggle()
		elseif cmd == "probe" then
			if not ns:EnsureProbe() then return end
			if rest == "dump" then ns.Probe:Dump()
			elseif rest == "forever" then ns.Probe:Forever()
			else ns.Probe:Run("manual") end
		elseif cmd == "status" then
			status()
		elseif cmd == "export" then
			export()
		elseif cmd == "clear" then
			clear(rest ~= "" and rest or nil)
		elseif cmd == "mem" or cmd == "memory" then
			memory()
		elseif cmd == "tidy" then
			ns:Tidy()
		elseif cmd == "selftest" then
			selftest()
		elseif cmd == "hud" then
			ns.HUD:Toggle()
		elseif cmd == "cleu" then
			if not ns:EnsureProbe() then return end
			ns.Probe:TestCLEU()
		elseif cmd == "list" then
			ns.Sightings:List(tonumber(rest))
		elseif cmd == "zones" then
			ns.Sightings:Zones()
		elseif cmd == "deaths" then
			ns.Deaths:List(tonumber(rest))
		elseif cmd == "alert" then
			local chat = Sintezza_RivalsPvPDB.settings.alerts.chat
			chat.sighting = (rest ~= "off")
			ns:Print("a chat line for every new enemy: %s", ns.L(chat.sighting and "on" or "off"))
		elseif cmd == "watch" and rest == "target" then
			ns.Watchlist:WatchTarget()
		elseif cmd == "watch" then
			local w, n = Sintezza_RivalsPvPDB.watch, 0
			for k, v in pairs(w) do
				n = n + 1
				ns:Print("watching: %s (%s)%s", tostring(v.name or k), tostring(v.class), v.auto and root.Text(" [авто]", " [auto]") or "")
			end
			if n == 0 then ns:Print("watchlist empty: right-click a row in the window, or use /rivals watch target") end
		elseif cmd == "config" or cmd == "options" then
			ns.Options:Open()
		elseif cmd == "map" then
			if rest == "debug" then
				if ns.Map then ns.Map:Debug() end
				if ns.MinimapPins then ns.MinimapPins:Debug() end
			else
				local m = Sintezza_RivalsPvPDB.settings.map
				m.enabled = not m.enabled
				if ns.Map then ns.Map:Update() end
				ns:Print(m.enabled and root.Text("Бои показаны на карте.", "PvP fights shown on the map.")
					or root.Text("Бои скрыты с карты.", "PvP fights hidden from the map."))
			end
		elseif cmd == "minimap" then
			local m = Sintezza_RivalsPvPDB.settings.minimap
			m.enabled = not m.enabled
			if ns.MinimapPins then ns.MinimapPins:Update() end
			ns:Print("minimap blips %s", ns.L(m.enabled and "on" or "off"))
		elseif cmd == "csv" or cmd == "copy" then
			ns.UI.ShowCopy()
		elseif cmd == "lock" or cmd == "unlock" then
			ns.WindowAppearance:Set("locked", cmd == "lock")
			ns:Print("window %s", ns.L(cmd == "lock" and "locked" or "unlocked"))
		elseif cmd == "scale" then
			local v = tonumber(rest)
			if v and v >= 0.5 and v <= 2 then
				ns.WindowAppearance:Set("scale", math.floor(v * 100 + 0.5))
				ns:Print("scale %.2f", v)
			else
				ns:Print("usage: /rivals scale 0.5-2.0")
			end
		elseif cmd == "reset" then
			local ui = Sintezza_RivalsPvPDB.settings.ui
			ns.WindowAppearance:ResetPosition()
			ns.WindowAppearance:Set("scale", 100)
			ui.w, ui.h = nil, nil
			if Sintezza_RivalsPvPFrame then
				Sintezza_RivalsPvPFrame:SetSize(ns.UI and ns.UI.DEFAULT_W or 1000, ns.UI and ns.UI.DEFAULT_H or 700)
				ns.WindowAppearance:ApplyTo(Sintezza_RivalsPvPFrame)
				if ns.UI and Sintezza_RivalsPvPFrame.onResized then Sintezza_RivalsPvPFrame.onResized() end
			end
			ns:Print("window position reset")
		else
			ns:Print(root.Text("Команды /rivals: config · history · marks · csv · status",
				"/rivals commands: config · history · marks · csv · status"))
		end
	end)
end
