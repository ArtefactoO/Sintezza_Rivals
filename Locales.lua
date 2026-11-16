local _, ns = ...
local clientLocale = GetLocale()
local locale = Sintezza_Theme.GetLocale and Sintezza_Theme:GetLocale() or clientLocale
ns.locale = locale == "ruRU" and "ruRU" or "enUS"

function ns.Text(russian, translation)
    return ns.locale == "ruRU" and russian or translation
end

local clientMatches = clientLocale == ns.locale or (ns.locale == "enUS" and clientLocale == "enGB")
local classes = {
    WARRIOR = ns.Text("Воин", "Warrior"),
    PALADIN = ns.Text("Паладин", "Paladin"),
    HUNTER = ns.Text("Охотник", "Hunter"),
    ROGUE = ns.Text("Разбойник", "Rogue"),
    PRIEST = ns.Text("Жрец", "Priest"),
    SHAMAN = ns.Text("Шаман", "Shaman"),
    MAGE = ns.Text("Маг", "Mage"),
    WARLOCK = ns.Text("Чернокнижник", "Warlock"),
    DRUID = ns.Text("Друид", "Druid"),
    DEATHKNIGHT = ns.Text("Рыцарь смерти", "Death Knight"),
    MONK = ns.Text("Монах", "Monk"),
    DEMONHUNTER = ns.Text("Охотник на демонов", "Demon Hunter"),
    EVOKER = ns.Text("Пробудитель", "Evoker"),
}

function ns.ClassName(token)
    local names = clientMatches and LOCALIZED_CLASS_NAMES_MALE
    return names and names[token] or classes[token] or token
end
