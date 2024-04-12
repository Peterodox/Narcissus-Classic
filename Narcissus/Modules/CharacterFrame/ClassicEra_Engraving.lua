local _, addon = ...

local EngravingSlotUtil = {};
addon.EngravingSlotUtil = EngravingSlotUtil;

local EngravingAPI = C_Engraving;

local function AlawysFalse(arg)
    return false
end

local IsEquipmentSlotEngravable = EngravingAPI and EngravingAPI.IsEquipmentSlotEngravable or AlawysFalse;
local GetRuneForEquipmentSlot = EngravingAPI and EngravingAPI.GetRuneForEquipmentSlot or AlawysFalse;
local IsEngravingEnabled = EngravingAPI and EngravingAPI.IsEngravingEnabled or AlawysFalse;

--[[
local DebugDataProvider = {};
DebugDataProvider.sample = {
    skillLineAbilityID = 0,
    itemEnchantmentID = 0,
    name = "Engraving",
    iconTexture = 132185,
    equipmentSlot = 5,
    level = 1,
    learnedAbilitySpellIDs = {409580},
};

function DebugDataProvider:GetRuneForEquipmentSlot(slotID)
    return self.sample
end
--]]


function EngravingSlotUtil:IsSlotValidForEngraving(slotID)
    --Need to be initialized with C_Engraving.RefreshRunesList() after game restarts
    return IsEquipmentSlotEngravable(slotID)
end

local function EngravingSlot_OnEnter(self)
    local tooltip = NarciGameTooltip;
    tooltip:Hide();
    tooltip:SetOwner(self, "ANCHOR_NONE");
    tooltip:SetPoint("TOPLEFT", self, "TOPRIGHT", 8, 0);
    if self.spellIDs then
        tooltip:SetSpellByID(self.spellIDs[1]);
        tooltip:Show();
        tooltip:FadeIn();
    else
        tooltip:Hide();
    end
end

local function EngravingSlot_OnLeave(self)
    NarciGameTooltip:Hide();
end

function EngravingSlotUtil:CreateSlot(slotButton)
    local f = CreateFrame("Frame", nil, slotButton);
    slotButton.EngravingSlot = f;
    f:SetSize(28, 32);

    f.Border = f:CreateTexture(nil, "OVERLAY", nil, 4);
    f.Border:SetPoint("CENTER", f, "CENTER", 0, 0);
    f.Border:SetSize(64, 64);
    f.Border:SetTexture("Interface/AddOns/Narcissus/Art/GemBorder/EngravingBorder");

    f.Icon = f:CreateTexture(nil, "ARTWORK");
    f.Icon:SetPoint("CENTER", f, "CENTER", 0, 0);
    f.Icon:SetSize(20, 20);
    f.Icon:SetTexCoord(0.0625, 0.9375, 0.0625, 0.9375);

    if slotButton.isRight then
        f:SetPoint("CENTER", slotButton, "CENTER", 44, 2);
    else
        f:SetPoint("CENTER", slotButton, "CENTER", -44, 2);
        f.Border:SetTexCoord(1, 0, 0, 1);
    end

    f:SetScript("OnEnter", EngravingSlot_OnEnter);
    f:SetScript("OnLeave", EngravingSlot_OnLeave);
end

function EngravingSlotUtil:SetupEngravingSlot(slotButton, engravingInfo)
    if not slotButton.EngravingSlot then
        self:CreateSlot(slotButton);
    end

    local icon, engravingName;
    if engravingInfo then
        icon = engravingInfo.iconTexture;
        engravingName = engravingInfo.name;
        slotButton.EngravingSlot.spellIDs = engravingInfo.learnedAbilitySpellIDs;
    else
        icon = "Interface/PaperDoll/UI-Backpack-EmptySlot";
        slotButton.EngravingSlot.spellID = nil;
    end
    slotButton.EngravingSlot.Icon:SetTexture(icon);
    slotButton.EngravingSlot:Show();

    if engravingName then   --colorize rune name
        return "|cffffd461"..engravingName.."|r"
    end
end

function EngravingSlotUtil:HideEngraving(slotButton)
    if slotButton.EngravingSlot then
        slotButton.EngravingSlot:Hide();
    end
end

function EngravingSlotUtil:UpdateEngravingForSlot(slotButton)
    local slotID = slotButton.slotID;
    if self:IsSlotValidForEngraving(slotID) then
        return self:SetupEngravingSlot(slotButton, GetRuneForEquipmentSlot(slotID));
    else
        self:HideEngraving(slotButton);
    end
end

function EngravingSlotUtil:UpdateSlotButton(slotButton)
end

function EngravingSlotUtil:OnOpenCharacterUI()

end

function EngravingSlotUtil:OnCloseCharacterUI()

end

function EngravingSlotUtil:InitializeEngravingSystem()

end

function EngravingSlotUtil:EnableEngravingMode()
    EngravingAPI.SetEngravingModeEnabled(true);
end

function EngravingSlotUtil:DisableEngravingMode()
    EngravingAPI.SetEngravingModeEnabled(false);
end

function EngravingSlotUtil:RefreshRunesList()
    EngravingAPI.RefreshRunesList();
end


if IsEngravingEnabled() then
    --This API returns the correct value before PLAYER_ENTERING_WORLD
    --C_Engraving.IsEquipmentSlotEngravable() however, needs to be initialized with C_Engraving.RefreshRunesList();

    EngravingSlotUtil.UpdateSlotButton = EngravingSlotUtil.UpdateEngravingForSlot;
    EngravingSlotUtil.InitializeEngravingSystem = EngravingSlotUtil.RefreshRunesList;
end