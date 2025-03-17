--Manage WoW API here

local _, addon = ...
local API = addon.API;
local _G = _G;


local function AlwaysNil()

end

local function AlwaysFalse()
    return false
end


local WoWAPI = {
    C_Item = {
        "GetItemCount",
        "GetItemInfoInstant",
        "GetItemInfo",
        "GetItemGem",
        "GetItemIcon",
        "GetItemIconByID",
        "GetItemSpell",

        --Not in Classic
        "GetItemStats",
    },

    C_Container = {
        "GetContainerItemLink",
    },
};


for namespace, data in pairs(WoWAPI) do
    local c = _G[namespace]
    for _, name in ipairs(data) do
        API[name] = c[name] or _G[name] or AlwaysNil;
    end
end


if GetMouseFocus then
    API.GetMouseFocus = GetMouseFocus;
else
    function API.GetMouseFocus()
        local foci = GetMouseFoci();
        if foci then
            return foci[1]
        end
    end
end