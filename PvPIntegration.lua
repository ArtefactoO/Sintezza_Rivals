local _, ns = ...
local Text = ns.Text
local Source = {}
local historyTitle = Text("История PvP", "PvP history")
local nameplatesTitle = Text("Неймплейты", "Nameplates")

local function CurrentDB()
    local db = Sintezza_RivalsPvPDB
    if type(db) == "table" and type(db.settings) == "table" then return db end
end

local function RecapParticipants(db)
    if Source.recapParticipants then return Source.recapParticipants end
    local participants = {}
    for _, fight in ipairs(db.deaths or {}) do
        if fight.killerSource == "death recap" then
            for _, player in ipairs(fight.attackers or {}) do
                if ns.IsPlayerGUID(player.guid) then participants[player.guid] = participants[player.guid] or "attacker" end
            end
            local killer = fight.verifiedKiller and Source:RecapKiller(fight)
            if killer and ns.IsPlayerGUID(killer.guid) then
                participants[killer.guid] = "killer"
            end
        end
    end
    for _, fight in ipairs(db.incoming or {}) do
        for _, player in ipairs(fight.players or {}) do
            if ns.IsPlayerGUID(player.guid) then participants[player.guid] = participants[player.guid] or "attacker" end
        end
    end
    Source.recapParticipants = participants
    return participants
end

function Source:Kind(guid, localRecord)
    local db = CurrentDB()
    if not db or db.settings.ui.showMarkers == false
        or (db.ignore and db.ignore[guid]) then return end
    local role = RecapParticipants(db)[guid]
    if role == "killer" or (localRecord and (localRecord.kills or 0) > 0) then return "killer" end
    local watch = db.watch and db.watch[guid]
    if (watch and not watch.auto) or (localRecord and localRecord.manual) then return "manual" end
    if role or (localRecord and (localRecord.recaps or 0) > 0) then return "attacker" end
    if localRecord and (localRecord.defeats or 0) > 0 then return "defeated" end
end

local function ExampleFights()
    local stamp = GetServerTime()
    return {
        { time = stamp - 65, win = true,
            who = { name = Text("Гримвольд", "Grimwald"), class = "ROGUE", level = 36, raceName = Text("Нежить", "Undead") },
            location = { zone = Text("Тернистая долина", "Stranglethorn Vale"), x = .342, y = .515 } },
        { time = stamp - 190, group = {},
            who = { name = Text("Боргрим", "Borgrim"), class = "WARRIOR", level = 39, raceName = Text("Орк", "Orc"), damage = 921 },
            location = { zone = Text("Нагорье Арати", "Arathi Highlands"), x = .681, y = .462 },
            participants = {
                { name = Text("Тенегрив", "Shadowmane"), class = "HUNTER", level = 38, raceName = Text("Тролль", "Troll"), damage = 543 },
                { name = Text("Громорог", "Thunderhorn"), class = "SHAMAN", level = 37, raceName = Text("Таурен", "Tauren"), damage = 318 },
                { name = Text("Мортис", "Mortis"), class = "MAGE", level = 38, raceName = Text("Нежить", "Undead"), damage = 207 },
            } },
    }
end

function Source:OpenHistory(preview)
    local open, tab = self.addon, self.historyTab
    if not (tab and open.UI and open.UI.Show and open.UI.SelectTab) then return false end
    local function Select()
        open.UI:Show()
        for i, entry in ipairs(open.UIX.TABS) do
            if entry == tab then
                self.preview = preview and ExampleFights() or nil
                if preview then self:SelectWorldHistory() end
                open.UI:SelectTab(i)
                return true
            end
        end
    end
    local ok, selected = pcall(Select)
    return ok and selected == true
end

function Source:StopPreview()
    self.preview = nil
end

local function Place(location)
    if not location then return "" end
    local zone, sub = location.zone or "", location.subZone or ""
    if sub == "" or sub == zone then return zone end
    return zone == "" and sub or sub .. " · " .. zone
end

local function SamePlayer(a, b)
    if not a or not b then return false end
    if a.guid and b.guid then return a.guid == b.guid end
    if not a.name or not b.name then return false end
    return a.name == b.name
end

function Source:RecapKiller(death)
    local killer = death.killer
    if not (death.verifiedKiller and killer and killer.name and not killer.guid) then return killer end
    local player
    for _, attacker in ipairs(death.attackers or {}) do
        if attacker.guid and attacker.name == killer.name then
            if player then return killer end
            player = attacker
        end
    end
    if not player then return killer end

    local merged = {}
    for field, value in pairs(player) do merged[field] = value end
    merged.damage = (player.damage or 0) + (killer.damage or 0)
    return merged
end

local function Participants(death, verified, killer)
    local participants = {}
    local function Add(player)
        if SamePlayer(player, killer) then return end
        for _, known in ipairs(participants) do
            if SamePlayer(player, known) then return end
        end
        participants[#participants + 1] = player
    end
    for _, player in ipairs(death and death.killerSource == "death recap" and death.attackers or {}) do Add(player) end
    for _, player in ipairs(verified and verified.helpers or {}) do Add(player) end
    return participants
end

function Source:WorldOutcomes(db)
    local records, byTime, byDeath, matched = {}, {}, {}, {}
    for _, death in ipairs(db.deaths or {}) do
        if type(death.ts) == "number" then
            local atTime = byTime[death.ts] or {}
            atTime[#atTime + 1] = death
            byTime[death.ts] = atTime
        end
    end
    -- Match the same death from both collectors, preferring the closest timestamp.
    for gap = 0, 3 do
        for _, fight in ipairs(ns.db.fights) do
            if fight.result == "loss" and not matched[fight] then
                local earlier, later = byTime[fight.time - gap], byTime[fight.time + gap]
                local death = earlier and table.remove(earlier)
                if not death and later ~= earlier and later then death = table.remove(later) end
                if death then
                    byDeath[death], matched[fight] = fight, true
                end
            end
        end
    end
    for _, death in ipairs(db.deaths or {}) do
        local verified = byDeath[death]
        local killer = verified and (verified.guid or verified.name) and verified
            or ((death.verifiedKiller or not verified) and Source:RecapKiller(death) or nil)
        local started = type(death.combatSeconds) == "number" and death.combatSeconds >= 0
            and (death.ts or 0) - death.combatSeconds or nil
        records[#records + 1] = { death = death, who = killer, verified = verified, group = death, location = death,
            time = death.ts or 0, started = started }
    end
    for _, fight in ipairs(ns.db.fights) do
        if fight.result == "win" then
            records[#records + 1] = { time = fight.time, started = fight.started,
                who = fight, win = true, group = fight, location = fight.location }
        elseif fight.result == "loss" and not matched[fight] then
            local killer = (fight.guid or fight.name) and fight or nil
            records[#records + 1] = { time = fight.time, who = killer, verified = fight, group = fight, location = fight.location }
        end
    end
    return records
end

local function RecordedClass(db, guid)
    if not guid then return end
    local sighting = db.sightings and db.sightings[guid]
    local nemesis = db.nemesis and db.nemesis[guid]
    local watch = db.watch and db.watch[guid]
    local saved = ns.db.players[guid]
    return (sighting and sighting.class) or (nemesis and nemesis.class)
        or (watch and watch.class) or (saved and saved.class)
end

local function ScoreName(name)
    return name and name ~= "" and ns.PvP.Lower(name) or nil
end

function Source:PlayerScores(db)
    local outcomes = self:WorldOutcomes(db)
    local byName, scores, names = {}, {}, {}
    local ownNames = ns.PvP.Deaths:OwnNames()

    local function Remember(guid, name)
        local normalized = ScoreName(name)
        if not normalized or not ns.IsPlayerGUID(guid) then return end
        names[guid] = name
        local existing = byName[normalized]
        if existing == nil then byName[normalized] = guid
        elseif existing ~= guid then byName[normalized] = false end
    end

    for guid, player in pairs(db.sightings or {}) do Remember(guid, player.name) end
    for guid, player in pairs(db.nemesis or {}) do Remember(guid, player.name) end
    for _, entry in ipairs(outcomes) do
        if entry.who then Remember(entry.who.guid, entry.who.name) end
    end
    for guid, player in pairs(ns.db.players) do Remember(guid, player.name) end

    local function Score(guid, name, class)
        local normalized = ScoreName(name)
        guid = ns.IsPlayerGUID(guid) and guid or (normalized and byName[normalized]) or nil
        if not guid and name and ownNames[name] then return end
        local key = guid or normalized
        if not key then return end
        local score = scores[key]
        if not score then
            score = { key = key, guid = guid, name = names[guid] or name or guid,
                class = RecordedClass(db, guid) or class, kills = 0, deaths = 0, recordedKills = 0, last = 0 }
            scores[key] = score
        else
            score.class = score.class or class
        end
        return score
    end

    for guid, player in pairs(ns.db.players) do
        if (player.defeats or 0) > 0 then
            local score = Score(guid, player.name, player.class)
            if score then score.kills = player.defeats end
        end
    end

    -- The cumulative death counters outlive the individual records. Reattribute
    -- the records we still have using the resolved killer, then add older deaths.
    local counted = {}
    for _, entry in ipairs(outcomes) do
        local death, who = entry.death, entry.who
        if death and death.counted and death.killer then
            local rawKey = death.killer.guid or death.killer.name
            if rawKey then counted[rawKey] = (counted[rawKey] or 0) + 1 end
        end
        if who and (entry.win or entry.verified or (death and (death.counted or death.verifiedKiller))) then
            local score = Score(who.guid, who.name, who.class)
            if score then
                if entry.win then score.recordedKills = score.recordedKills + 1
                else score.deaths = score.deaths + 1 end
                score.last = math.max(score.last, entry.time)
            end
        end
    end

    for key, player in pairs(db.nemesis or {}) do
        local older = (player.killsOnMe or 0) - (counted[key] or 0)
        if older > 0 then
            local guid = ns.IsPlayerGUID(key) and key or nil
            local score = Score(guid, player.name or (not guid and key or nil), player.class)
            if score then
                score.deaths = score.deaths + older
                score.last = math.max(score.last, player.lastEncounter or 0)
            end
        end
    end
    for _, score in pairs(scores) do
        score.kills = math.max(score.kills, score.recordedKills)
    end
    return scores, byName
end

function Source:PlayerScore(name, guid)
    local db = CurrentDB()
    if not db then return end
    local scores, byName = self:PlayerScores(db)
    if guid then return scores[guid] end
    local normalized = ScoreName(name)
    if normalized then return scores[normalized] or scores[byName[normalized]] end
end

function Source:MarkerCount(guid, kind)
    local db = CurrentDB()
    if not db then return 0 end
    if not self.markerScores then self.markerScores = self:PlayerScores(db) end
    local score = self.markerScores[guid]
    if not score then return 0 end
    return kind == "killer" and score.deaths or score.kills
end

function Source:BattlegroundScore(match)
    local kills, deaths = match.kills, match.deaths
    if kills ~= nil and deaths ~= nil then return kills, deaths end
    local recordedKills, recordedDeaths = 0, 0
    for _, fight in ipairs(match.fights) do
        if fight.result == "win" then recordedKills = recordedKills + 1
        elseif fight.result == "loss" then recordedDeaths = recordedDeaths + 1 end
    end
    return kills or recordedKills, deaths or recordedDeaths
end

local function Nearby(a, b)
    if not (a and b) then return false end
    if a.mapID and b.mapID and a.mapID ~= b.mapID then return false end
    if not a.zone or a.zone == "" or a.zone ~= b.zone then return false end
    if a.worldX and a.worldY and b.worldX and b.worldY then
        return (a.worldX - b.worldX)^2 + (a.worldY - b.worldY)^2 <= 150^2
    end
    return a.subZone and a.subZone ~= "" and a.subZone == b.subZone
end

local function SharesAttacker(earlier, later)
    local function Matches(player)
        if SamePlayer(player, later.who) and (later.incoming or later.win or later.verified or (later.death and later.death.verifiedKiller)) then
            return true
        end
        for _, other in ipairs(later.participants or {}) do
            if SamePlayer(player, other) then return true end
        end
        return false
    end
    if Matches(earlier.who) then return true end
    for _, player in ipairs(earlier.participants or {}) do
        if Matches(player) then return true end
    end
    return false
end

local CONTINUATION_SECONDS = 40

local function FindContinuation(records, index)
    local record = records[index]
    local ended = record.ended or record.time
    local closest, delay
    for i = index - 1, 1, -1 do
        local later = records[i]
        local gap = (later.started or later.time) - ended
        if record.time < later.time and gap >= 0 and gap <= CONTINUATION_SECONDS and (not delay or gap < delay)
            and Nearby(record.location, later.location) and SharesAttacker(record, later) then
            closest, delay = later, gap
        end
        if not later.incoming and not later.win then break end
    end
    return closest
end

local function GroupFights(records)
    table.sort(records, function(a, b) return a.time > b.time end)
    local groups, grouped = {}, {}
    for i, record in ipairs(records) do
        local later = record.incoming and FindContinuation(records, i)
        local group = later and grouped[later]
        if group then
            group.earlier = group.earlier or {}
            group.earlier[#group.earlier + 1] = record
        else
            groups[#groups + 1] = record
            group = record
        end
        grouped[record] = group
    end
    return groups
end

local function AddHistoryTab(open)
    local x = open.UIX
    if Sintezza_RivalsPvPFrame or not (x and type(x.TABS) == "table" and x.add and x.hits and x.filterText) then return end
    local expandedGroups = setmetatable({}, { __mode = "k" })
    local expandedMatches = setmetatable({}, { __mode = "k" })
    local ui = CurrentDB().settings.ui
    local view = "world"
    local generalView = "world"
    local outcome = "all"
    local searches, toolbar = {}
    local function DuelMode()
        local saved = ui.views and ui.views.Duels
        return (saved == "opponent" or saved == "class") and saved or "every"
    end
    local function SetDuelMode(value)
        ui.views = ui.views or {}
        ui.views.Duels = value
    end
    local function OpenClassDuels(class)
        SetDuelMode("every")
        toolbar:Refresh()
        x.filterBox:SetText(x.duelClassQuery(class))
        x.scrollTo(0)
    end
    local function FilterFights(records, filter)
        local function Matches(record)
            local who = record.who
            if x.hits(filter, who and who.name, who and who.guid, who and who.class, Place(record.location)) then return true end
            for _, player in ipairs(record.participants or {}) do
                if x.hits(filter, player.name, player.guid, player.class) then
                    record.reveal = true
                    return true
                end
            end
        end
        local matching = {}
        for _, record in ipairs(records) do
            local matches = Matches(record)
            for _, earlier in ipairs(record.earlier or {}) do
                if Matches(earlier) and not matches then
                    record.reveal = true
                    matches = true
                end
            end
            if matches then matching[#matching + 1] = record end
        end
        return matching
    end

    local function Collect(db)
        local records = Source:WorldOutcomes(db)
        for _, entry in ipairs(records) do
            entry.participants = Participants(entry.death, entry.verified, entry.who)
        end
        local ownNames = open.Deaths:OwnNames()
        for _, incoming in ipairs(db.incoming or {}) do
            local leader, others = nil, {}
            for _, player in ipairs(incoming.players) do
                if not ownNames[player.name] then
                    if leader then others[#others + 1] = player else leader = player end
                end
            end
            if leader then
                records[#records + 1] = { time = incoming.ts, started = incoming.ts, ended = incoming.ended, who = leader, group = incoming,
                    location = incoming.location, participants = others, incoming = true }
            end
        end
        return GroupFights(records)
    end
    local function Profile(who)
        if not who then return "", "" end
        local level = type(who.level) == "number" and who.level > 0 and tostring(who.level) or ""
        local race = (who.raceName or who.race) and x.raceText(who) or ""
        return level, race
    end
    local function Damage(who)
        if who and type(who.damage) == "number" then return Text("Урон: %d", "Damage: %d"):format(who.damage) end
        return ""
    end
    local function FightRows(records, db, preview, battleground, earlierPhase)
        if preview then
            x.add({ cells = { Text("Предпросмотр", "Preview"), Text("Тестовые бои", "Sample fights"),
                "", "", "/rivals test stop" } })
        end
        for _, entry in ipairs(records) do
            local who, death = entry.who, entry.death
            local label = entry.win and Text("Ты убил", "You killed")
                or earlierPhase and Text("Ранее в бою", "Earlier in fight")
                or entry.incoming and Text("Нанес тебе урон", "Damaged you")
                or who and Text("Тебя убили", "You were killed") or Text("Ты погиб", "You died")
            local name = who and (who.name or who.guid) or (entry.win and "—"
                or Text("Убийца неизвестен", "Killer unknown"))
            local location = entry.location or {}
            local fallback = entry.verified and entry.verified.location or {}
            local point = (location.x and location.y) and location or fallback
            local note = death and not entry.verified and not death.verifiedKiller and death.killer
                and (death.killerSource == "death recap" and Text("Из сводки", "From recap")
                    or Text("Предположение", "Estimated")) or ""
            local helpers = entry.participants or {}
            local expanded, toggle
            if #helpers > 0 or entry.earlier then
                local group = entry.group
                expanded = expandedGroups[group]
                if expanded == nil then expanded = not entry.earlier end
                expanded = expanded or entry.reveal == true
                if not entry.reveal then toggle = function() expandedGroups[group] = not expanded end end
                if #helpers > 0 then name = name .. ("  +%d"):format(#helpers) end
            end
            local level, race = Profile(who)
            local recap = not entry.incoming and #helpers > 0 and { killer = who, attackers = helpers } or nil
            local coords = not battleground and type(point.x) == "number" and type(point.y) == "number" and x.coords(point.x, point.y) or ""
            local place = Place(location)
            if place == "" then place = Place(fallback) end
            local class = who and (who.class or RecordedClass(db, who.guid)
                or (death and SamePlayer(who, death.killer) and (death.killer.class or death.killerClass)))
            local interactive = not preview and not battleground
            local indent = (battleground and 12 or 0) + (earlierPhase and 16 or 0)
            x.add({ kind = recap and "fight" or "rivalsHistory", rec = recap, key = interactive and who and who.guid,
                name = interactive and who and who.name, class = class, color = class,
                markCol = 2, agoCol = 8, agoTs = entry.time, toggle = toggle,
                groupExpanded = expanded, toggleRow = battleground == true, indent = indent > 0 and indent or nil,
                place = place, mapPoint = interactive and coords ~= "" and point.mapID and point or nil,
                tone = entry.win and "green" or entry.incoming and "muted" or "red",
                cells = { label, name, level, race, place, coords, note ~= "" and note or Damage(who), "" } })
            if expanded then
                for _, helper in ipairs(helpers) do
                    local helperLevel, helperRace = Profile(helper)
                    local helperClass = helper.class or RecordedClass(db, helper.guid)
                    x.add({ kind = "rivalsHistory", name = interactive and helper.name, key = interactive and helper.guid,
                        class = helperClass, color = helperClass, markCol = 2, tone = "muted", participant = true,
                        cells = { "", helper.name or helper.guid or "—", helperLevel, helperRace, "", "", Damage(helper), "" },
                        indent = indent + 16 })
                end
                if entry.earlier then FightRows(entry.earlier, db, false, battleground, true) end
            end
        end
    end

    local function BattlegroundRows(db, filter)
        local found
        for _, match in ipairs(ns.db.battlegrounds) do
            local title = match.name or Text("Поле боя", "Battleground")
            local matchesMap = x.hits(filter, title)
            local records = {}
            for _, fight in ipairs(match.fights) do
                local win, incoming = fight.result == "win", fight.result == "incoming"
                local who = incoming and fight.players[1] or ((fight.name or fight.guid) and fight or nil)
                local others = fight.helpers or {}
                if incoming then
                    others = {}
                    for i = 2, #fight.players do others[#others + 1] = fight.players[i] end
                end
                records[#records + 1] = { time = fight.time, started = incoming and fight.time or fight.started, ended = fight.ended,
                    who = who, win = win, incoming = incoming, verified = fight.verifiedRecap and fight or nil,
                    location = fight.location, group = fight, participants = others }
            end
            records = GroupFights(records)
            if not matchesMap then records = FilterFights(records, filter) end
            if matchesMap or #records > 0 then
                found = true
                local reveal = not matchesMap and expandedMatches[match] == nil
                local expanded = expandedMatches[match] == true or reveal
                local status = match.completed and Text("Матч завершен", "Match complete")
                    or match.closed and Text("Выход из матча", "Left match") or Text("Текущий матч", "Current match")
                x.add({ kind = "rivalsBattleground", markCol = 1, groupExpanded = expanded, toggleRow = true,
                    toggle = function() expandedMatches[match] = not expanded end,
                    agoCol = 8, agoTs = match.time,
                    cells = { status, title, "", "", "", "", ("%d / %d"):format(Source:BattlegroundScore(match)), "" } })
                if expanded then
                    if #records == 0 then
                        x.add({ cells = { "", Text("Нет подробностей боя", "No fight details") }, indent = 12 })
                    else
                        FightRows(records, db, false, true)
                    end
                end
            end
        end
        if not found then
            x.add({ cells = { "", filter and Text("Ничего не найдено", "No matches found")
                or Text("Матчей пока нет", "No battlegrounds recorded") } })
        end
    end

    local function ByKills(a, b)
        if a.kills ~= b.kills then return a.kills > b.kills end
        if a.last ~= b.last then return a.last > b.last end
        local aName, bName = ns.PvP.Lower(a.name), ns.PvP.Lower(b.name)
        if aName ~= bName then return aName < bName end
        return a.key < b.key
    end
    local colors = open.Theme.C
    local function PlayerCount(value, color)
        local r, g, b = unpack(value > 0 and color or colors.dim)
        return ("|cff%02x%02x%02x%d|r"):format(math.floor(r * 255 + .5), math.floor(g * 255 + .5),
            math.floor(b * 255 + .5), value)
    end
    local playerSort = {
        name = function(score) return ns.PvP.Lower(score.name) end,
        kills = function(score) return score.kills end,
        deaths = function(score) return score.deaths end,
        last = function(score) return score.last end,
    }
    local function PlayerRows(db, filter)
        local scores, visible = Source:PlayerScores(db), {}
        for _, score in pairs(scores) do
            if (outcome == "all" or score[outcome] > 0) and x.hits(filter, score.name, score.guid) then
                visible[#visible + 1] = score
            end
        end
        x.sortList(visible, playerSort, ByKills)
        if #visible == 0 then
            x.add({ cells = { (filter or outcome ~= "all") and Text("Игроки не найдены", "No players found")
                or Text("Записей пока нет", "No entries yet") } })
        end
        for _, score in ipairs(visible) do
            x.add({ kind = "rivalsPlayerScore", name = score.name, key = score.guid, class = score.class, color = score.class,
                agoCol = score.last > 0 and 4 or nil, agoTs = score.last,
                cells = { score.name, PlayerCount(score.kills, colors.green), PlayerCount(score.deaths, colors.red), "—" } })
        end
        return #visible
    end

    local tab
    local function Fill()
        local db = CurrentDB()
        if not db then return end
        tab.footerText = nil
        local preview, filter = Source.preview, x.filterText()
        if view == "duels" and not preview then
            local mode = DuelMode()
            tab.cols = x.duelColumns(mode)
            tab.footerText = x.fillDuels(db.duels, mode, filter, OpenClassDuels)
            return
        end
        if view == "bg" and not preview then
            BattlegroundRows(db, filter)
            return
        end
        if view == "players" and not preview then
            tab.footerText = Text("Игроков в списке: %d", "Players listed: %d"):format(PlayerRows(db, filter))
            return
        end
        local records = preview or FilterFights(Collect(db), filter)
        FightRows(records, db, preview)
        if preview then return end
        local legacy = {}
        for _, player in ipairs(ns.db.legacyPlayers or {}) do
            if x.hits(filter, player.name) then legacy[#legacy + 1] = player end
        end
        if #legacy > 0 then
            local byName = {}
            local function Remember(name, guid)
                if not name then return end
                local previous = byName[name]
                if previous == nil then byName[name] = guid
                elseif previous ~= guid then byName[name] = false end
            end
            for guid, record in pairs(ns.db.players) do
                Remember(record.name or guid, guid)
            end
            for guid, record in pairs(db.sightings or {}) do Remember(record.name, guid) end
            for guid, record in pairs(db.nemesis or {}) do
                if ns.IsPlayerGUID(guid) then Remember(record.name, guid) end
            end
            x.add({ cells = { "", Text("Старые отметки", "Previous marks"), "", "", Text("Без разбивки по боям", "Player totals") } })
            for _, player in ipairs(legacy) do
                local kind = ns.Kinds[player.kind]
                local guid = player.guid or byName[player.name]
                local class = player.class or RecordedClass(db, guid)
                x.add({ tone = player.kind == "killer" and "red" or player.kind == "defeated" and "green" or "muted",
                    class = class, markCol = 2,
                    cells = { kind and kind.label or "", player.name, "" }, indent = 16 })
            end
        elseif #records == 0 then
            x.add({ cells = { "", Text("Записей пока нет", "No entries yet") } })
        end
    end
    tab = { title = historyTitle, search = Text("Имя или зона", "Name or zone"),
        hint = Text("Для записи боев без смертей нужен счетчик урона WoW.",
            "Recording fights without deaths requires WoW's Damage Meter."),
        cols = { { Text("Результат", "Result"), 152, "LEFT" }, { Text("Игрок", "Player"), 218, "LEFT" },
            { Text("Ур.", "Lvl"), 36, "CENTER" }, { Text("Раса", "Race"), 90, "LEFT" },
            { Text("Место боя", "Fight location"), 166, "LEFT" }, { Text("Коорд.", "Coords"), 80, "RIGHT", nil, "fightMap" },
            { Text("Подробности", "Details"), 112, "LEFT" }, { Text("Когда", "When"), 56, "RIGHT" } },
        fill = Fill, extraToolbar = true }
    tab.id, tab.layoutColumns = "rivalsHistory", tab.cols
    local worldHint = tab.hint
    local worldColumns = tab.cols
    local bgColumns = { worldColumns[1], { Text("Поле боя / игрок", "Battleground / player"), 218, "LEFT" },
        worldColumns[3], worldColumns[4], { Text("Место боя", "Fight location"), 166, "LEFT" },
        { "", 80, "RIGHT" }, { Text("Добив. / смерти", "KB / deaths"), 112, "LEFT" }, worldColumns[8] }
    local playerColumns = {
        { Text("Игрок", "Player"), 385, "LEFT", "name", nil, false },
        { Text("Я убил", "I killed"), 152, "CENTER", "kills" },
        { Text("Меня убили", "Killed me"), 152, "CENTER", "deaths" },
        { Text("Последний бой", "Last fight"), 185, "RIGHT", "last" },
    }
    local historyViews = {
        world = { cols = worldColumns, hint = worldHint, search = tab.search },
        bg = { cols = bgColumns, search = Text("Имя или поле боя", "Name or battleground") },
        players = { cols = playerColumns, search = Text("Имя игрока", "Player name"), defaultSort = "kills" },
        duels = { search = "search opponent, class or zone", sortScope = "Duels" },
    }
    local function SetView(value)
        if value == "world" or value == "players" then generalView = value end
        local active = toolbar and x.TABS[x.selected] == tab
        if active then searches[view] = x.filterBox:GetText() end
        view = value
        ui.historyView = value
        local mode = historyViews[value]
        tab.cols = mode.cols or x.duelColumns(DuelMode())
        tab.note, tab.hint, tab.search = mode.note, mode.hint, mode.search
        tab.defaultSortKey, tab.sortScope = mode.defaultSort, mode.sortScope
        if active then
            x.useSort(tab.sortScope or tab.id)
            toolbar:Refresh()
            local search = searches[value] or ""
            if x.filterBox:GetText() ~= search then x.filterBox:SetText(search) end
        end
    end
    local function SwitchView(value)
        if view == value and not Source.preview then return end
        Source:StopPreview()
        SetView(value)
        open.UI:Refresh()
        x.scrollTo(0)
    end
    SetView(historyViews[ui.historyView] and ui.historyView or "world")
    tab.buildToolbar = function(parent, searchBox)
        local widgets = Sintezza_Theme:CreateWidgets(ns.Theme)
        toolbar = CreateFrame("Frame", nil, parent)
        toolbar:SetPoint("TOPLEFT", 14, -51)
        toolbar:SetPoint("TOPRIGHT", -28, -51)
        toolbar:SetHeight(59)

        local section = widgets:Segmented(toolbar,
            { Text("Общая", "General"), Text("Поля боя", "Battlegrounds"), open.L("Duels") },
            { "general", "bg", "duels" }, function() return view == generalView and "general" or view end,
            function(value)
                SwitchView(value == "general" and generalView or value)
            end)
        section:SetWidth(322)
        section:SetPoint("TOPLEFT")

        local mode = widgets:Segmented(toolbar, { Text("Журнал", "Journal"), Text("По игрокам", "By player") },
            { "world", "players" }, function() return view end, SwitchView, true)
        mode:SetWidth(176)
        mode:SetPoint("BOTTOMLEFT", 0, -2)

        local duels = widgets:Segmented(toolbar, { open.L("Every duel"), open.L("By opponent"), open.L("By class") },
            { "every", "opponent", "class" }, DuelMode, function(value)
                if value == DuelMode() then return end
                SetDuelMode(value)
                if value == "class" and x.isDuelClassQuery(x.filterText()) then searchBox:SetText("") end
                open.UI:Refresh()
                x.scrollTo(0)
            end, true)
        duels:SetWidth(274)
        duels:SetPoint("BOTTOMLEFT", 0, -2)

        local picker = open.Theme.Select(toolbar, 152, {
            { "all", Text("Все исходы", "All outcomes") },
            { "kills", Text("Кого я убил", "Players I killed") },
            { "deaths", Text("Кто меня убил", "Players who killed me") },
        }, function() return outcome end, function(value) outcome = value end, function()
            open.UI:Refresh()
            x.scrollTo(0)
        end)
        picker:SetPoint("RIGHT", toolbar, "BOTTOMRIGHT", 0, 14)

        function toolbar:Refresh()
            section:Refresh()
            mode:SetShown(view == generalView)
            mode:Refresh()
            duels:SetShown(view == "duels")
            duels:Refresh()
            picker:SetShown(view == "players")
            searchBox:ClearAllPoints()
            local searchX = view == "bg" and 14 or view == "duels" and 300 or 202
            searchBox:SetPoint("TOPLEFT", parent, "TOPLEFT", searchX, -83)
            searchBox:SetPlaceholder(tab.search)
        end
        return toolbar
    end
    function Source:SelectWorldHistory()
        SetView("world")
    end
    function Source:SelectDuelHistory()
        if view ~= "duels" then SwitchView("duels") end
    end
    table.insert(x.TABS, 1, tab)
    table.insert(x.TABS, 2, { id = "rivalsNameplates", title = nameplatesTitle, cols = {},
        build = function(parent)
            local scroll, editor = open.Theme.ScrollArea(parent, 40)
            scroll:SetPoint("TOPLEFT")
            scroll:SetPoint("BOTTOMRIGHT", -18, 0)
            editor:SetSize(650, 510)
            local widgets = Sintezza_Theme:CreateWidgets(ns.Theme)
            local ui = CurrentDB().settings.ui
            local toggle = widgets:Toggle(editor, Text("Показывать метки", "Show nameplate markers"),
                function() return ui.showMarkers ~= false end, function(value)
                    ui.showMarkers = value
                    ns.Changed()
                end)
            toggle:SetSize(218, 30)
            toggle:SetPoint("TOPRIGHT", -16, -12)
            ns.BuildMarkerControls(editor, -12)
            scroll:Refresh()
        end })
    return tab
end

function ns.ConnectPvP()
    local open = ns.PvP
    if ns.PvPSource or type(open) ~= "table" or not CurrentDB() then return end
    Source.addon = open
    ns.PvPSource = Source
    open.Nameplates = { RefreshAll = function() ns.RefreshPlates() end }
    Source.historyTab = AddHistoryTab(open)
    if open.UI and open.UI.MarkDirty and hooksecurefunc then
        hooksecurefunc(open.UI, "MarkDirty", function()
            Source.recapParticipants = nil
            Source.markerScores = nil
            if Source.refreshQueued then return end
            Source.refreshQueued = true
            C_Timer.After(0, function()
                Source.refreshQueued = nil
                ns.RefreshPlates()
            end)
        end)
    end
end
