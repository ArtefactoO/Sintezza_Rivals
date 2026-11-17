local addonName, ns = ...
local Text = ns.Text

local function Public(value)
    if not issecretvalue or not issecretvalue(value) then return value end
end
ns.Public = Public

function ns.Read(func, ...)
    local ok, a, b = pcall(func, ...)
    if ok then return Public(a), Public(b) end
end

function ns.IsPlayerGUID(guid)
    return type(guid) == "string" and guid:match("^Player%-%d+%-%x+$") ~= nil
end

ns.Kinds = {
    killer = { label = Text("Убил тебя", "Killed you"), color = { 1, .46, .39 } },
    attacker = { label = Text("Нанес тебе урон", "Damaged you"), color = { 1, .72, .36 } },
    manual = { label = Text("Отмечен вручную", "Marked manually"), color = { .54, .88, .83 } },
    defeated = { label = Text("Ты нанес добивающий удар", "You landed the killing blow"), color = { .60, .76, .66 } },
}

ns.MarkChoices = {
    { "off", Text("Без метки", "No marker") }, { "skull", Text("Череп", "Skull") },
    { "swords", Text("Латунные мечи", "Brass swords") }, { "diamond", Text("Маленький ромб", "Small diamond") },
    { "edge", Text("Окантовка", "Border") }, { "name", Text("Цвет имени", "Name color") },
}
local DEFAULT_MARKS = { killer = "skull", attacker = "off", manual = "diamond", defeated = "off" }
ns.DefaultMarkerLayout = { anchor = "right", size = 100, opacity = 100, x = 0, y = 0 }
ns.MarkerAnchors = {
    { "right", Text("Справа", "Right") }, { "left", Text("Слева", "Left") },
    { "top", Text("Сверху", "Above") }, { "bottom", Text("Снизу", "Below") },
}

local scalingKinds = { killer = true, attacker = true, defeated = true }
local markerIcons = { skull = true, swords = true, diamond = true }
local defaultScaling = { enabled = false, count = 4, tiers = {
    { kills = 5, bonus = 10 }, { kills = 10, bonus = 15 },
    { kills = 25, bonus = 25 }, { kills = 50, bonus = 50 },
} }
local maxThreshold = 999

function ns.IsMarkerIcon(style)
    return markerIcons[style] == true
end

function ns.MarkerScalingAvailable(kind, style)
    return scalingKinds[kind] == true and ns.IsMarkerIcon(style)
end

local function NormalizeMarkerScaling(saved)
    local scaling = { enabled = saved and saved.enabled == true or false,
        count = saved and saved.count == 3 and 3 or 4, tiers = {} }
    local tiers = saved and type(saved.tiers) == "table" and saved.tiers
    local previous, previousBonus = 0, 0
    for index, default in ipairs(defaultScaling.tiers) do
        local row = tiers and tiers[index]
        local kills = type(row) == "table" and tonumber(row.kills) or default.kills
        local bonus = type(row) == "table" and tonumber(row.bonus) or default.bonus
        kills = math.min(maxThreshold - (#defaultScaling.tiers - index), math.max(previous + 1, math.floor(kills)))
        bonus = math.max(previousBonus, math.max(0, math.min(200, math.floor(bonus))))
        scaling.tiers[index] = { kills = kills, bonus = bonus }
        previous, previousBonus = kills, bonus
    end
    return scaling
end

function ns.MarkerScaling(kind)
    return ns.db.markerScaling[kind] or defaultScaling
end

local function EditableMarkerScaling(kind)
    if not ns.db.markerScaling[kind] then ns.db.markerScaling[kind] = NormalizeMarkerScaling() end
    return ns.db.markerScaling[kind]
end

function ns.SetMarkerScaling(kind, field, value)
    if not scalingKinds[kind] then return end
    if field == "enabled" then value = value == true
    elseif field == "count" then value = value == 3 and 3 or 4
    else return end
    local scaling = EditableMarkerScaling(kind)
    scaling[field] = value
    ns.Changed()
end

function ns.SetMarkerThreshold(kind, index, field, value)
    if not scalingKinds[kind] or type(value) ~= "number" or value ~= math.floor(value) then return false end
    local scaling = ns.MarkerScaling(kind)
    local row = scaling.tiers[index]
    if not row or index > scaling.count then return false end
    if field == "kills" then
        if value < 1 or value > maxThreshold then return false end
        value = math.max(index, math.min(maxThreshold - (#scaling.tiers - index), value))
    elseif field ~= "bonus" or value < 0 or value > 200 then
        return false
    end
    if row[field] ~= value then
        local tiers = EditableMarkerScaling(kind).tiers
        tiers[index][field] = value
        local distance = field == "kills" and 1 or 0
        for other = index - 1, 1, -1 do
            tiers[other][field] = math.min(tiers[other][field], tiers[other + 1][field] - distance)
        end
        for other = index + 1, #tiers do
            tiers[other][field] = math.max(tiers[other][field], tiers[other - 1][field] + distance)
        end
        ns.Changed()
    end
    return true
end

function ns.MarkerSizePercent(kind, style, count)
    local base = ns.MarkerLayout(kind).size
    if not count or not ns.MarkerScalingAvailable(kind, style) then return base end
    local scaling = ns.MarkerScaling(kind)
    if scaling.enabled then
        for index = scaling.count, 1, -1 do
            local tier = scaling.tiers[index]
            if count >= tier.kills then return base * (1 + tier.bonus / 100), index end
        end
    end
    return base
end

function ns.MarkerLayout(kind)
    return ns.db.markerLayouts[kind] or ns.DefaultMarkerLayout
end

function ns.SetMarkerLayout(kind, field, value)
    local layout = ns.db.markerLayouts[kind]
    if not layout then
        layout = {}
        for key, default in pairs(ns.DefaultMarkerLayout) do layout[key] = default end
        ns.db.markerLayouts[kind] = layout
    end
    layout[field] = value
    ns.Changed()
end

function ns.MarkStyle(kind)
    return ns.db.marks[kind] or DEFAULT_MARKS[kind]
end

function ns.Kind(record)
    if (record.kills or 0) > 0 then return "killer" end
    if record.manual then return "manual" end
    if (record.recaps or 0) > 0 then return "attacker" end
    if (record.defeats or 0) > 0 then return "defeated" end
    return "manual"
end

function ns.Color(kind)
    return ns.db.colors[kind] or ns.Kinds[kind].color
end

function ns.Message(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff82d9c8Sintezza Rivals|r  " .. message)
end

function ns.Changed()
    if ns.RefreshPlates then ns.RefreshPlates() end
    if ns.RefreshOptions then ns.RefreshOptions() end
    if ns.RefreshJournal then ns.RefreshJournal() end
end

local function NameOf(unit)
    return ns.PvP.UnitCharacterName(unit)
end

function ns.EnemyGUID(unit)
    local guid = ns.Read(UnitGUID, unit)
    if ns.IsPlayerGUID(guid) and (ns.Read(UnitIsEnemy, "player", unit) == true
        or ns.Read(UnitCanAttack, "player", unit) == true) then
        return guid
    end
end

local function Record(guid, name, stamp)
    local record = ns.db.players[guid] or { kills = 0, recaps = 0 }
    record.name = name or record.name
    record.lastSeen = stamp
    ns.db.players[guid] = record
    return record
end

local function AddFight(fight)
    local fights = ns.db.fights
    table.insert(fights, 1, fight)
    if #fights > 100 then table.remove(fights) end
    if ns.PvP.UI then ns.PvP.UI:MarkDirty() end
end

function ns.WorldKills()
    local kills = {}
    for _, fight in ipairs(ns.db.fights) do
        if fight.result == "win" then kills[#kills + 1] = fight end
    end
    return kills
end

function ns.ClearWorldHistory()
    ns.db.fights = {}
    for _, record in pairs(ns.db.players) do record.defeats = nil end
    if ns.PvP.UI then ns.PvP.UI:MarkDirty() end
    ns.Changed()
end

function ns.IsBattleground()
    local _, instanceType = ns.Read(IsInInstance)
    if instanceType == "pvp" then return true end
    if instanceType == "arena" then return false end
    return C_PvP and ns.Read(C_PvP.IsBattleground) == true
end

local match
local function MatchHistoryChanged()
    if ns.PvP.UI then ns.PvP.UI:MarkDirty() end
end

local function HistoryEnabled()
    return ns.PvP:IsRecording(ns.IsBattleground() and "battlegrounds" or "fights")
end

local function CloseMatch()
    if match then
        match.closed = true
        match = nil
        MatchHistoryChanged()
    end
end

local function UpdateMatch(resume, started, completed)
    if not ns.IsBattleground() then
        CloseMatch()
        if resume and ns.db.battlegrounds[1] then ns.db.battlegrounds[1].closed = true end
        return
    end
    if not HistoryEnabled() then
        if started then CloseMatch() end
        if resume and not match and ns.db.battlegrounds[1] then ns.db.battlegrounds[1].closed = true end
        return
    end
    local name = ns.Read(GetInstanceInfo) or ns.Read(GetRealZoneText)
    local matches = ns.db.battlegrounds
    local previous = resume and matches[1] or match
    if previous and not previous.closed and (not name or not previous.name or name == previous.name)
        and not (previous.completed and (started or (resume and completed == false))) then
        match = previous
        match.name = match.name or name
        return match
    end
    if matches[1] then matches[1].closed = true end
    match = { name = name, time = GetServerTime(), fights = {} }
    table.insert(matches, 1, match)
    if #matches > 30 then table.remove(matches) end
    MatchHistoryChanged()
    return match
end

function ns.BattlegroundMatch()
    return UpdateMatch()
end

function ns.AddBattlegroundFight(battleground, fight)
    local fights = battleground.fights
    local index = 1
    while fights[index] and fights[index].time > fight.time do index = index + 1 end
    table.insert(fights, index, fight)
    if #fights > 300 then table.remove(fights) end
    MatchHistoryChanged()
end

function ns.ClearBattlegroundHistory()
    local deaths = ns.PvP and ns.PvP.Deaths
    if ns.IsBattleground() and deaths and deaths.ResetIncomingDamage then
        deaths.ResetIncomingDamage()
    end
    match = nil
    ns.db.battlegrounds = {}
    MatchHistoryChanged()
end

local function ReadMatchScore(battleground)
    if not C_PvP then return end
    local guid = ns.Read(UnitGUID, "player")
    if not guid then return end
    local score = ns.Read(C_PvP.GetScoreInfoByPlayerGuid, guid)
    if type(score) ~= "table" or (canaccesstable and not canaccesstable(score)) then return end
    local kills, deaths = Public(score.killingBlows), Public(score.deaths)
    if type(kills) == "number" then battleground.kills = kills end
    if type(deaths) == "number" then battleground.deaths = deaths end
end

local function CompleteMatch(battleground)
    battleground.completed = true
    ReadMatchScore(battleground)
    MatchHistoryChanged()
end

local function CaptureKill(attacker, target)
    if not HistoryEnabled() then return end
    attacker, target = Public(attacker), Public(target)
    if not ns.IsPlayerGUID(target) or type(attacker) ~= "string" or attacker == "" then return end
    local player = ns.Read(UnitGUID, "player")
    if target == player or (attacker ~= player and attacker ~= ns.Read(UnitGUID, "pet")) then return end
    local onBattleground = ns.IsBattleground()
    local battleground = onBattleground and ns.BattlegroundMatch()
    if onBattleground and not battleground then return end
    local name
    for _, unit in ipairs({ "target", "mouseover", "focus" }) do
        if ns.Read(UnitGUID, unit) == target then name = NameOf(unit); break end
    end
    if not name then name = ns.Read(UnitNameFromGUID, target) end
    local stamp = GetServerTime()
    if not battleground then
        local record = Record(target, name, stamp)
        record.defeats = (record.defeats or 0) + 1
        name = record.name
    end
    local deaths = ns.PvP and ns.PvP.Deaths
    local fight = deaths and deaths.PlayerInfo(target, name) or { name = name, guid = target }
    fight.result, fight.time = "win", stamp
    fight.location = deaths and deaths.PlayerLocation()
    if deaths and ns.Read(InCombatLockdown) == true then fight.started = deaths.lastCombatStart end
    if battleground then ns.AddBattlegroundFight(battleground, fight); return end
    AddFight(fight)
    ns.PvP:Notify("kill", "You killed %s", fight.name or target)
    ns.Changed()
end

local function RecapIdentity(events, first, stamp)
    return table.concat({ stamp, Public(first.sourceGUID) or "", Public(first.amount) or "", #events }, "/")
end

local function ReadLatestRecap()
    local events = Public(C_DeathRecap.GetRecapEvents())
    if type(events) ~= "table" or (canaccesstable and not canaccesstable(events)) then return end
    local first = Public(events[1])
    if type(first) ~= "table" or (canaccesstable and not canaccesstable(first)) then return end
    local stamp = Public(first.timestamp)
    if type(stamp) ~= "number" then return end
    return events, RecapIdentity(events, first, stamp), stamp
end

local function ParseRecap(deathTime)
    local events, identity, stamp = ReadLatestRecap()
    if not events or identity == ns.db.lastRecap then return end
    -- Forever's recap timestamp is server time. Discard the prior death while waiting for this one.
    if stamp < deathTime - 12 or stamp > deathTime + 12 then return end

    local player = ns.Read(UnitGUID, "player")
    local attackers = {}
    for index, value in ipairs(events) do
        local event = Public(value)
        if type(event) == "table" and (not canaccesstable or canaccesstable(event)) then
            local guid = Public(event.sourceGUID)
            local flags = Public(event.sourceFlags)
            local amount = Public(event.amount)
            if ns.IsPlayerGUID(guid) and guid ~= player and type(flags) == "number" and bit.band(flags, 0x40) ~= 0
                and type(amount) == "number" and amount > 0 then
                local name = Public(event.sourceName)
                local entry = attackers[guid] or { killer = index == 1, order = index, damage = 0 }
                entry.damage = entry.damage + amount
                if not entry.name and type(name) == "string" and name ~= "" then entry.name = name end
                attackers[guid] = entry
            end
        end
    end
    return identity, attackers
end

local deathSerial = 0
local recapBattleground

function ns.CancelWorldDeathRecap()
    if not recapBattleground then deathSerial = deathSerial + 1 end
end

local function CaptureDeath()
    if not HistoryEnabled() then return end
    local onBattleground = ns.IsBattleground()
    local battleground = onBattleground and ns.BattlegroundMatch()
    if onBattleground and not battleground then return end
    recapBattleground = battleground
    deathSerial = deathSerial + 1
    local serial, deathTime = deathSerial, GetServerTime()
    local deaths = ns.PvP and ns.PvP.Deaths
    local location = deaths and deaths.PlayerLocation()
    local fight = { result = "loss", time = deathTime, helpers = {}, location = location }
    if battleground then ns.AddBattlegroundFight(battleground, fight) end
    if deaths and deaths.AttachCombatDeath then deaths:AttachCombatDeath(fight) end
    if not C_DeathRecap or not C_DeathRecap.GetRecapEvents then return end
    local function Try()
        if serial ~= deathSerial then return end
        local ok, identity, attackers = pcall(ParseRecap, deathTime)
        if not ok or not identity then return end
        ns.db.lastRecap = identity
        deathSerial = deathSerial + 1
        fight.verifiedRecap = true
        for guid, entry in pairs(attackers) do
            local name = entry.name
            if not battleground then
                local record = Record(guid, name, deathTime)
                record.recaps = record.recaps + 1
                if entry.killer then record.kills = record.kills + 1 end
                name = record.name
            end
            local who = deaths and deaths.PlayerInfo(guid, name) or { name = name, guid = guid }
            who.order, who.damage = entry.order, entry.damage
            if entry.killer then
                for field, value in pairs(who) do fight[field] = value end
            else
                fight.helpers[#fight.helpers + 1] = who
            end
        end
        if next(attackers) then
            table.sort(fight.helpers, function(a, b) return a.order < b.order end)
            if battleground then
                MatchHistoryChanged()
            else
                AddFight(fight)
                ns.Changed()
            end
        end
    end
    for _, delay in ipairs({ .3, 1, 2 }) do C_Timer.After(delay, Try) end
end

function ns.SortedRecords()
    local sorted = {}
    for guid, record in pairs(ns.db.players) do
        sorted[#sorted + 1] = { guid = guid, record = record }
    end
    table.sort(sorted, function(a, b)
        if a.record.lastSeen ~= b.record.lastSeen then return a.record.lastSeen > b.record.lastSeen end
        return a.guid < b.guid
    end)
    return sorted
end

function ns.MarkTarget()
    if ns.IsBattleground() then return end
    local guid = ns.EnemyGUID("target")
    if not guid then ns.Message(Text("Выбери вражеского игрока, которого игра позволяет распознать.", "Select an enemy player the game can identify.")); return end
    local record = Record(guid, NameOf("target"), GetServerTime())
    record.manual = true
    ns.Message(Text("%s отмечен вручную.", "%s marked manually."):format(record.name or guid))
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, name, target)
    if event == "PLAYER_DEAD" then CaptureDeath(); return end
    if event == "PARTY_KILL" then CaptureKill(name, target); return end
    if event == "PLAYER_ENTERING_WORLD" then
        local completed = C_PvP and ns.Read(C_PvP.IsMatchComplete)
        if match and match.completed and completed == false then CloseMatch() end
        local battleground = UpdateMatch(Public(target) == true or Public(name) == true, false, completed)
        if battleground and completed then CompleteMatch(battleground) end
        return
    end
    if event == "PVP_MATCH_ACTIVE" then UpdateMatch(false, true); return end
    if event == "PVP_MATCH_COMPLETE" then
        if not HistoryEnabled() then CloseMatch(); return end
        local battleground = ns.BattlegroundMatch()
        if battleground then CompleteMatch(battleground) end
        return
    end
    if event == "UPDATE_BATTLEFIELD_SCORE" then
        if HistoryEnabled() and match and match.completed and ns.IsBattleground()
            and (match.kills == nil or match.deaths == nil) then
            CompleteMatch(match)
        end
        return
    end
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        if not HistoryEnabled() then return end
        local ok, _, identity = pcall(ReadLatestRecap)
        if ok and identity then ns.db.lastRecap = identity end
        return
    end
    if name ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    Sintezza_RivalsDB = Sintezza_RivalsDB or {}
    ns.db = Sintezza_RivalsDB
    ns.db.players = ns.db.players or {}
    ns.db.colors = ns.db.colors or {}
    local savedScaling = ns.db.markerScaling
    ns.db.markerScaling = {}
    if type(savedScaling) == "table" then
        for kind in pairs(scalingKinds) do
            if type(savedScaling[kind]) == "table" then
                ns.db.markerScaling[kind] = NormalizeMarkerScaling(savedScaling[kind])
            end
        end
    end
    if type(ns.db.markerLayouts) ~= "table" then ns.db.markerLayouts = {} end
    for kind, layout in pairs(ns.db.markerLayouts) do
        if not ns.Kinds[kind] or type(layout) ~= "table" then
            ns.db.markerLayouts[kind] = nil
        else
            local validAnchor
            for _, choice in ipairs(ns.MarkerAnchors) do
                if layout.anchor == choice[1] then validAnchor = true; break end
            end
            if not validAnchor then layout.anchor = ns.DefaultMarkerLayout.anchor end
            layout.size = math.max(50, math.min(250, tonumber(layout.size) or 100))
            layout.opacity = math.max(10, math.min(100, tonumber(layout.opacity) or 100))
            layout.x = math.max(-32, math.min(32, tonumber(layout.x) or 0))
            layout.y = math.max(-24, math.min(24, tonumber(layout.y) or 0))
        end
    end
    ns.db.fights = ns.db.fights or {}
    ns.db.battlegrounds = type(ns.db.battlegrounds) == "table" and ns.db.battlegrounds or {}
    if type(ns.db.marks) ~= "table" then
        ns.db.marks = {}
        ns.db.legacyPlayers = {}
        for _, entry in ipairs(ns.SortedRecords()) do
            ns.db.legacyPlayers[#ns.db.legacyPlayers + 1] = { name = entry.record.name or entry.guid,
                guid = entry.guid, class = entry.record.class, kind = ns.Kind(entry.record) }
            if #ns.db.legacyPlayers >= 100 then break end
        end
        if ns.db.mode == "off" then
            for kind in pairs(DEFAULT_MARKS) do ns.db.marks[kind] = "off" end
        elseif ns.db.mode == "name" then
            ns.db.marks.killer, ns.db.marks.manual = "name", "name"
        end
    end
    ns.db.mode = nil
    ns.db.minimap = type(ns.db.minimap) == "table" and ns.db.minimap or { minimapPos = 195 }
    ns.RegisterLaunchers()
    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_DEAD")
    pcall(self.RegisterEvent, self, "PARTY_KILL")
    pcall(self.RegisterEvent, self, "PVP_MATCH_ACTIVE")
    pcall(self.RegisterEvent, self, "PVP_MATCH_COMPLETE")
    pcall(self.RegisterEvent, self, "UPDATE_BATTLEFIELD_SCORE")
    if ns.StartNameplates then ns.StartNameplates() end
end)

SLASH_SINTEZZA_RIVALS1 = "/rivals"
SLASH_SINTEZZA_RIVALS2 = "/sintezza_rivals"
SlashCmdList.SINTEZZA_RIVALS = function(message)
    local command, argument = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command, argument = command:lower(), argument:lower()
    if command == "add" then
        ns.MarkTarget()
    elseif command == "history" then
        ns.ToggleJournal()
    elseif command == "test" then
        if not (ns.PvPSource and ns.PvPSource:OpenHistory(argument ~= "stop")) then
            ns.Message(Text("Не удалось открыть историю PvP.", "Could not open PvP history."))
        end
    elseif command == "config" or command == "options" or command == "settings" then
        if ns.PvP and ns.PvP.Options then ns.PvP.Options:Open() end
    elseif command == "marks" then
        if ns.PvP and ns.PvP.UI then ns.PvP.UI:OpenTab("rivalsNameplates") end
    elseif command == "" and ns.PvP and ns.PvP.UI then
        ns.PvP.UI:Toggle()
    elseif command ~= "" and SlashCmdList.SINTEZZA_RIVALS_PVP then
        SlashCmdList.SINTEZZA_RIVALS_PVP(message)
    end
end
