local _, addon = ...

local L = Narci.L;
local format = string.format;
local GetActionInfo = GetActionInfo;
local GetMacroBody = GetMacroBody;
local GetEquipmentSetMissingSlot = NarciClassicAPI.EquipmentManager.GetEquipmentSetMissingSlot;
local GetSlotName = NarciAPI.GetSlotNameBySlotID;


local function AppendEquipmentSetInfo(tooltip, setID, showActions, hideEquipStatus)
    local name, _, _, isEquipped, numItems, numEquipped, numInInventory, numLost = C_EquipmentSet.GetEquipmentSetInfo(setID);

    if InCombatLockdown() then
        local r, g, b = NarciAPI.GetColorPresetRGB("red");
        tooltip:AddLine(Narci.L["Cannot Unequip Combat"], r, g, b, true);
    else
        if not hideEquipStatus then
            tooltip:AddDoubleLine(name, format(ITEMS_VARIABLE_QUANTITY, numItems), 1, 1, 1, 1, 0.82, 0);
            local missing;
            if isEquipped then
                local r, g, b = NarciAPI.GetColorPresetRGB("green");
                tooltip:AddLine(CURRENTLY_EQUIPPED, r, g, b, true);
            else
                tooltip:AddLine(format(ITEMS_EQUIPPED, numEquipped), 1, 0.82, 0, true);
                if numInInventory and numInInventory > 0 then
                    tooltip:AddLine(format(ITEMS_IN_INVENTORY, numInInventory), 1, 1, 1, true);
                end
                if numLost and numLost > 0 then
                    missing = true;
                    if numLost > 4 then
                        tooltip:AddLine(format(ITEMS_NOT_IN_INVENTORY, numLost), 1, 0, 0, true);
                    else
                        local slots = GetEquipmentSetMissingSlot(setID);
                        if slots then
                            local ITEM_MISSING = ITEM_MISSING or "%s missing";
                            for i = 1, #slots do
                                tooltip:AddLine(format(ITEM_MISSING, GetSlotName(slots[i])), 1, 0, 0, true);
                            end
                        end
                    end
                end
            end
        end

        if showActions then
            tooltip:AddLine(" ");
            if not (isEquipped or missing) then
                tooltip:AddLine(L["Equipment Gesture Use"], 0.25, 0.78, 0.92, true);
            end
            tooltip:AddLine(L["Equipment Gesture Edit"], 0.25, 0.78, 0.92, true);
        end
    end

    tooltip:Show();
end

local function SetupActionBarTooltip(tooltip, slot)
    --slot: ActionBarButton
    local actionType, id = GetActionInfo(slot);
    if not (actionType == "macro" and id and id >= 121) then
        return
    end

    local body = GetMacroBody(id) or "";
    local setID = string.match(body, "UseEquipmentSet%((%d+)%)");
    setID = tonumber(setID);

    if setID then
        AppendEquipmentSetInfo(tooltip, setID);
    end
end


if NarciGameTooltip and not NarciGameTooltip.SetEquipmentSet then
    function NarciGameTooltip:SetEquipmentSet(setID)
        AppendEquipmentSetInfo(self, setID, true);
    end
end



local GameTooltip_SetEquipmentSet;

if GameTooltip and GameTooltip.SetEquipmentSet then
    function GameTooltip_SetEquipmentSet(tooltip, setID)
        local name = C_EquipmentSet.GetEquipmentSetInfo(setID);
        tooltip:SetEquipmentSet(name);
        AppendEquipmentSetInfo(tooltip, setID, true, true);
    end
else
    --If there is no SetEquipmentSet method, displays set our way
    function GameTooltip_SetEquipmentSet(tooltip, setID, showActions)
        AppendEquipmentSetInfo(tooltip, setID, showActions);
    end

    hooksecurefunc(GameTooltip, "SetAction", SetupActionBarTooltip);
end

addon.GameTooltip_SetEquipmentSet = GameTooltip_SetEquipmentSet;