local addon, ns = ...
local api = _G.Sintezza_PerfAPI
if type(api) ~= "table" or api.version ~= 1 then return end
local module = api:RegisterModule(addon, "rivals", { title = "Rivals history and map", titleRu = "История и карта противников" })
if not module then return end
local call = api:RegisterPoint(module, "sort", { title = "Sort history list", titleRu = "Сортировка истории", memory = true })
local counter = api:RegisterPoint(module, "map_update", { kind = "counter", title = "Map refreshes", titleRu = "Обновления карты" })
local bridge = {}
ns.PerfBridge = bridge
function bridge.Count(key)
    if key == "map_update" and counter then api:Count(counter) end
end
local owner = ns.PvP.UIX
if call and owner and type(owner.sortList) == "function" then
    local original = owner.sortList
    owner.sortList = function(...)
        if not api:IsActive(call) then return original(...) end
        if issecretvalue then
            for i = 1, select("#", ...) do
                if issecretvalue(select(i, ...)) then return original(...) end
            end
        end
        return api:Call(call, original, ...)
    end
end
