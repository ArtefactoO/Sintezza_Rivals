local source, integration = ...
local checks = 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local function upvalue(fn, wanted, replacement)
    for index = 1, 40 do
        local name, value = debug.getupvalue(fn, index)
        if not name then break end
        if name == wanted then
            if replacement then debug.setupvalue(fn, index, replacement) end
            return replacement or value
        end
    end
    error("Missing test access to " .. wanted)
end

local function fixture()
    local pending, badges = {}, {}
    local metrics = { queued = 0, refreshes = 0, scores = 0, paints = 0 }
    local units, driver = {}, nil
    local db = { settings = { ui = {} }, sightings = {}, deaths = {}, incoming = {}, nemesis = {}, watch = {}, ignore = {} }
    local root = { db = { players = {}, fights = {}, hiddenMarkers = {} },
        Text = function(_, en) return en end, Public = function(value) return value end,
        IsBattleground = function() return false end,
        IsPlayerGUID = function(guid) return type(guid) == "string" and guid:match("^Player%-") ~= nil end }
    root.PvP = { UI = { MarkDirty = function() end }, Lower = string.lower,
        Deaths = { OwnNames = function() return { ["Self Player"] = true } end } }
    for i = 1, 1000 do db.sightings["Player-" .. i] = { name = "Enemy " .. i, class = "WARRIOR" } end
    root.EnemyGUID = function(token) return units[token] and units[token].guid end
    root.MarkStyle = function() return "swords" end
    root.MarkerScalingAvailable = function() return true end
    root.MarkerScaling = function() return { enabled = true } end
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.UIParent = {}
    env.Sintezza_RivalsPvPDB = db
    env.GetServerTime = function() return 100000 end
    env.C_NamePlate = { GetNamePlates = function()
        local result = {}
        for token, unit in pairs(units) do
            if unit.onMap then result[#result + 1] = { namePlateUnitToken = token } end
        end
        return result
    end }
    env.wipe = function(tbl) for key in pairs(tbl) do tbl[key] = nil end end
    env.C_Timer = {
        After = function(delay, callback)
            check(delay == 0, "Nameplate work is queued for the next client callback")
            pending[#pending + 1] = callback
            metrics.queued = metrics.queued + 1
        end,
        NewTicker = function() error("Sword markers do not start a name-color ticker") end,
    }
    env.hooksecurefunc = function(owner, key, callback)
        local original = owner[key]
        owner[key] = function(...) original(...); callback(...) end
    end
    env.CreateFrame = function()
        local frame = { scripts = {} }
        function frame:RegisterEvent() end
        function frame:SetScript(key, callback) self.scripts[key] = callback end
        driver = frame
        return frame
    end
    local chunk = assert(loadstring(source, "Nameplates.lua"))
    setfenv(chunk, env)("Sintezza_Rivals", root)
    local attempt = upvalue(root.RefreshPlates, "TryUnit")
    local refresh = upvalue(attempt, "RefreshUnit")
    local health, label, plate = {}, {}, { GetFrameLevel = function() return 1 end }
    upvalue(refresh, "PlateParts", function() return plate, health, label end)
    upvalue(refresh, "CreateBadge", function()
        local badge = { shown = false }
        function badge:SetParent() end
        function badge:SetFrameLevel() end
        function badge:ClearAllPoints() end
        function badge:Hide() self.shown = false end
        badges[#badges + 1] = badge
        return badge
    end)
    upvalue(refresh, "PaintMarker", function(state, _, _, style)
        state.style = style
        state.badge.guid, state.badge.shown = state.guid, true
        metrics.paints = metrics.paints + 1
    end)
    local actualRefresh = root.RefreshPlates
    root.RefreshPlates = function() metrics.refreshes = metrics.refreshes + 1; actualRefresh() end
    chunk = assert(loadstring(integration, "PvPIntegration.lua"))
    setfenv(chunk, env)("Sintezza_Rivals", root)
    local provider = upvalue(root.ConnectPvP, "Source")
    local score = provider.PlayerScores
    provider.PlayerScores = function(self, ...)
        metrics.scores = metrics.scores + 1
        return score(self, ...)
    end
    upvalue(root.ConnectPvP, "AddHistoryTab", function() return {} end)
    root.ConnectPvP()
    root.StartNameplates()
    local object = { root = root, metrics = metrics, units = units }
    function object:Add(token, guid, onMap)
        units[token] = { guid = guid, onMap = onMap }
        root.db.players[guid] = { name = "Enemy " .. guid, kills = 1, defeats = 1, class = "WARRIOR" }
        driver.scripts.OnEvent(driver, "NAME_PLATE_UNIT_ADDED", token)
    end
    function object:Event(event, token) driver.scripts.OnEvent(driver, event, token) end
    function object:Dirty() root.PvP.UI:MarkDirty() end
    function object:Flush()
        local batch = pending
        pending = {}
        for _, callback in ipairs(batch) do callback() end
    end
    function object:Reset()
        check(#pending == 0, "Reset only after deferred work is drained")
        metrics.queued, metrics.refreshes, metrics.scores, metrics.paints = 0, 0, 0, 0
    end
    function object:Active()
        local current, count = {}, 0
        for _, badge in ipairs(badges) do
            if badge.shown then current[badge.guid] = true; count = count + 1 end
        end
        return current, count
    end
    return object
end

local object = fixture()
for i = 1, 50 do
    object:Add("nameplate" .. i, "Player-" .. i)
    object:Dirty()
end
check(object.metrics.queued == 1 and object.metrics.refreshes == 0, "Mixed appearance and dirty events share one queue")
object:Flush()
check(object.metrics.refreshes == 1 and object.metrics.scores == 1, "The batch computes scores once")
check(object.metrics.paints == 50 and select(2, object:Active()) == 50, "All 50 current plates render")

object:Reset()
for i = 1, 50 do object:Dirty() end
object:Flush()
check(object.metrics.queued == 1 and object.metrics.refreshes == 1 and object.metrics.scores == 1,
    "Repeated dirty notifications produce one refresh")

object:Reset()
object:Event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
local active, count = object:Active()
check(not active["Player-1"] and count == 49, "Removal releases its badge before deferred refresh")
object:Add("nameplate1", "Player-1001")
object:Dirty()
check(object.metrics.queued == 1, "A reused unit token shares the pending refresh")
object:Flush()
active, count = object:Active()
check(active["Player-1001"] and not active["Player-1"] and count == 50, "Reused token receives only the new identity")
check(object.metrics.refreshes == 1 and object.metrics.scores == 1, "Reused identity refresh is coalesced")

object:Reset()
object.root.RefreshPlates()
check(object.metrics.refreshes == 1 and object.metrics.paints == 50 and object.metrics.queued == 0,
    "Explicit refresh stays synchronous")
object:Reset()
object:Event("UNIT_FACTION", "missing")
check(object.metrics.queued == 0, "Untracked faction events are ignored")
object.units.nameplate1.onMap = true
object.units.nameplate2.onMap = true
object:Event("PLAYER_ENTERING_WORLD")
check(select(2, object:Active()) == 0, "World transition releases old markers synchronously")
object:Flush()
active, count = object:Active()
check(count == 2 and active["Player-1001"] and active["Player-2"], "World transition renders the new visible set")

object = fixture()
object:Add("nameplate1", "Player-1")
object:Dirty()
object:Event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
object:Flush()
check(object.metrics.refreshes == 1 and object.metrics.paints == 0 and select(2, object:Active()) == 0,
    "Removed-before-flush tokens never acquire a badge")
object:Add("nameplate1", "Player-2")
object:Dirty()
object:Flush()
check(object.metrics.refreshes == 2 and object.metrics.paints == 1, "A completed queue accepts the next event batch")
return checks
