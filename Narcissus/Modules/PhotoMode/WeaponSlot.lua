local _, addon = ...
local TransmogDataProvider = addon.TransmogDataProvider;
local API = addon.API;
local GetItemInfo = API.GetItemInfo;
local GetItemInfoInstant = API.GetItemInfoInstant;
local Narci = Narci;

local function GetItemIcon(itemID)
    if itemID then
        local _, _, _, _, icon = GetItemInfoInstant(itemID);
        if icon == 0 then
            icon = nil;
        end
        return icon
    end
end


local function HoldWeaponButton_OnClick(self)
	local model = Narci:GetActiveActor();
	self.isOn = not self.isOn;
    
    local isSheathed;

	if model.SetSheathed then
        isSheathed = not model:GetSheathed();
        self.isOn = not isSheathed;
		model:SetSheathed(isSheathed);
        if model.bowData then
            if isSheathed then
                model:SetItemTransmogInfo(model.bowData, 16);
            else
                model:SetItemTransmogInfo(model.bowData, 17); --swtich bow to the left hand
                model:UndressSlot(16);
            end
        end
    elseif model.EquipItem then
		if self.isOn then
            local weapons = model.equippedWeapons;
            if weapons[1] then
                model:EquipItem(weapons[1]);
                if weapons[2] then
                    model:EquipItem(weapons[2]);
                end
            elseif weapons[2] then
                --use 2 same weapons then remove the mainhand
                model:EquipItem(weapons[2]);
                model:EquipItem(weapons[2]);
                model:EquipItem(111532);
            end
		else
			model:EquipItem(111532);
            model:EquipItem(130105);
		end
		model.holdWeapon = self.isOn;
        isSheathed = false;
	end

    if not isSheathed then
        self.Icon:SetTexCoord(0.5, 1, 0, 1);
    else
        self.Icon:SetTexCoord(0, 0.5, 0, 1);
    end
end

local UnequipButtonScripts = {};

function UnequipButtonScripts.OnEnter(self)
    NarciTooltip:NewText(self, Narci.L["Unequip Item"], nil, nil, 1);
end

function UnequipButtonScripts.OnLeave(self)
    NarciTooltip:HideTooltip();
end

function UnequipButtonScripts.OnMouseDown(self)
    self.Icon:SetSize(16, 16);
    NarciTooltip:HideTooltip();
end

function UnequipButtonScripts.OnMouseUp(self)
    self.Icon:SetSize(18, 18);
end

function UnequipButtonScripts.OnClick(self)
    local model = Narci:GetActiveActor();
    if model then
        if not model.equippedWeapons then
            model.equippedWeapons = {};
        end
        if model.UndressSlot then
            if self.slotID == 16 then
                model:EquipWeapon(0, 0, 1);
                model.equippedWeapons[1] = nil;
            else
                model:EquipWeapon(0, 0, 2);
                model.equippedWeapons[2] = nil
            end
        elseif model.UnequipItems then
            if self.slotID == 16 then
                model:EquipWeapon(111532, 0, 1);
                model.equippedWeapons[1] = nil;
            else
                model:EquipWeapon(130105, 0, 2);
                model.equippedWeapons[2] = nil;
            end
        end
        self:GetParent():SetSlotInfo(nil);
    end
end

NarciActorWeaponSlotMixin = {};

function NarciActorWeaponSlotMixin:OnLoad()
    local id = self:GetID();
    if id == 1 then
        --self.UnequipButton.slotID = 16;
        self.EmptyText:SetText("Main");
        self.inventoryText = INVTYPE_WEAPONMAINHAND;
    else
        --self.UnequipButton.slotID = 17;
        self.EmptyText:SetText("Off");
        self.inventoryText = INVTYPE_WEAPONOFFHAND;
    end
    local offset = 0.05;
    local range = (1- offset)*14/24/2 ;
    self.ItemIcon:SetTexCoord(offset, 1 - offset, 0.5 - range, 0.5 + range);

    --[[
    for methodName, func in pairs(UnequipButtonScripts) do
        self.UnequipButton:SetScript(methodName, func);
    end
    --]]

    self:RegisterForClicks("LeftButtonUp", "RightButtonUp");
    self:SetEmptyVisual(true);
    self:OnLeave();
    self:SetScript("OnLoad", nil);
end

function NarciActorWeaponSlotMixin:OnClick(button)
    if button == "LeftButton" then
        --Narci_WeaponBrowser:Open();
        self:GetParent():SetPreferredWeapon(self:GetID());
    elseif button == "RightButton" then
        --self.UnequipButton:Click();
    end
end

function NarciActorWeaponSlotMixin:OnEnter()
    self.ItemIcon:SetVertexColor(1, 1, 1);
    self.EmptyText:SetAlpha(1);

    local IDFrame = self:GetParent().IDFrame;
    IDFrame:ClearAllPoints();
    if self:GetID() == 2 then
        IDFrame:SetText(STAT_CATEGORY_RANGED);  --self.itemName or (self.inventoryText)
    else
        IDFrame:SetText(STAT_CATEGORY_MELEE);
    end
    
    IDFrame:SetPoint("BOTTOM", self, "TOP", 0, 0);
    IDFrame:Show();
end

function NarciActorWeaponSlotMixin:OnLeave()
    self.ItemIcon:SetVertexColor(0.8, 0.8, 0.8);
    self.EmptyText:SetAlpha(0.8);

    self:GetParent().IDFrame:Hide();
end

function NarciActorWeaponSlotMixin:OnMouseDown()
    self:GetParent().IDFrame:Hide();
    self.Selection:SetSize(16, 16);
end

function NarciActorWeaponSlotMixin:OnMouseUp()
    self.Selection:SetSize(18, 18);
end

function NarciActorWeaponSlotMixin:SetSlotInfo(id, name, icon)
    if id == 0 then
        id = nil;
        name = nil;
    end
    self.itemID = id;
    self.itemName = name;
    self.ItemIcon:SetTexture(icon);
    self:SetEmptyVisual(not id);
    self:Enable();
end

function NarciActorWeaponSlotMixin:SetEmptyVisual(state)
    if state then
        self.ItemIcon:SetTexture(nil);
        self.Border:SetTexCoord(0.34375, 0.671875, 0, 0.1171875);
        --self.Highlight:SetTexCoord(0.34375, 0.671875, 0.125, 0.2421875);
        self.EmptyText:Show();
        --self.UnequipButton:Hide();
        --self:SetHitRectInsets(3, 3, 0, 0);
    else
        self.Border:SetTexCoord(0, 0.328125, 0, 0.1171875);
        --self.Highlight:SetTexCoord(0, 0.328125, 0.125, 0.2421875);
        self.EmptyText:Hide();
        --self.UnequipButton:Show();
        --self:SetHitRectInsets(3, 12, 0, 0);
    end
end

function NarciActorWeaponSlotMixin:DisableSlot()
    self:Disable();
    self.EmptyText:Hide();
    self.ItemIcon:SetTexture(nil);
    self.Border:SetTexCoord(0.34375, 0.671875, 0, 0.1171875);
    self.Selection:Hide();
end

--------------------------------------------------------------------
local RANGED_WEAPON_SUBCLASS = {
    [2] = true,
    [3] = true,
    [16] = true,
    [18] = true,
    [19] = true,
};

NarciPhotoModeWeaponFrameMixin = {};

function NarciPhotoModeWeaponFrameMixin:OnLoad()
    self.SheathButton:SetScript("OnClick", HoldWeaponButton_OnClick);
    self.SheathButton.Background:SetVertexColor(0.5, 0.5, 0.5);
    self.SheathButton.Background:Hide();
    self.SheathButton:SetScript("OnEnter", function(f)
        f.Background:Show();
        NarciTooltip:NewText(f, BINDING_NAME_TOGGLESHEATH, nil, nil, 1);
    end);
    self.SheathButton:SetScript("OnLeave", function(f)
        f.Background:Hide();
        NarciTooltip:HideTooltip();
    end);
    self.SheathButton:SetScript("OnMouseDown", function(f)
        if f:IsEnabled() then
            f.Icon:SetSize(12, 12);
        end
    end);
    self.SheathButton:SetScript("OnMouseUp", function(f)
        f.Icon:SetSize(14, 14);
    end);
    self.SheathButton:SetScript("OnEnable", function(f)
        f.Icon:SetVertexColor(1, 1, 1);
    end);
    self.SheathButton:SetScript("OnDisable", function(f)
        f.Icon:SetVertexColor(0.5, 0.5, 0.5);
    end);
    --self.Label:SetText(Narci.L["Draw Weapon"]);
    self:SetScript("OnLoad", nil);
    self.OnLoad = nil;
    NarciPhotoModeBar_OnLoad(self);
end

function NarciPhotoModeWeaponFrameMixin:SetItemInfo(id, slot, databaseName, overrideSheathStatus)
    local icon, name;
    if id then
        icon = GetItemIcon(id);
        name = GetItemInfo(id) or databaseName;
    end
    if slot == 1 then
        self.MainHandSlot:SetSlotInfo(id, name, icon);
    elseif slot == 2 then
        self.OffHandSlot:SetSlotInfo(id, name, icon);
    end
    if overrideSheathStatus then
        self:ToggleSheathButton();
    end
end

function NarciPhotoModeWeaponFrameMixin:SetItemFromActor(actor)
    if not actor then return end;

    actor.isItemLoaded = true;
    actor.bowData = nil;

    if actor.GetItemTransmogInfo then
        --New Method in 9.1.0   return ItemTransmogInfoMixin
        --DressUpModel / ModelSceneActor
        local transmogInfo;
        local sourceID, sourceInfo, itemID, name, icon;
        for slotID = 16, 17 do
            transmogInfo = actor:GetItemTransmogInfo(slotID);
            if transmogInfo then
                sourceID = transmogInfo.appearanceID;
                sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID);
                if sourceInfo then
                    itemID = sourceInfo.itemID;
                    name = sourceInfo.name;
                else
                    itemID = 0;
                end
                if TransmogDataProvider:IsSourceBow(sourceID) then
                    actor.bowData = transmogInfo;
                end
            else
                itemID = 0;
                sourceID = 0;
            end
            icon = C_TransmogCollection.GetSourceIcon(sourceID);
            if slotID == 16 then
                self.MainHandSlot:SetSlotInfo(itemID, name, icon);
            else
                self.OffHandSlot:SetSlotInfo(itemID, name, icon);
            end
        end

    elseif actor.GetSlotTransmogSources then
        --DressUpModel / ModelSceneActor
        local sourceID, sourceInfo, itemID, name, icon;
        for slotID = 16, 17 do
            sourceID = actor:GetSlotTransmogSources(slotID);
            sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID);
            if sourceInfo then
                itemID = sourceInfo.itemID;
                name = sourceInfo.name;
            else
                itemID = 0;
                sourceID = 0;
            end
            icon = C_TransmogCollection.GetSourceIcon(sourceID);
            if slotID == 16 then
                self.MainHandSlot:SetSlotInfo(itemID, name, icon);
            else
                self.OffHandSlot:SetSlotInfo(itemID, name, icon);
            end
        end

    else
        --Classic
        if actor:IsObjectType("DressUpModel") then
            local weapons = actor.originalWeapons;
            if weapons then
                local itemID, name, icon;

                itemID = weapons[1] or weapons[2];
                if itemID then
                    icon = GetItemIcon(itemID);
                    name = C_Item.GetItemNameByID(itemID);  --in fact, itemlink
                    self.MainHandSlot:SetSlotInfo(itemID, name, icon);
                else
                    self.MainHandSlot:SetSlotInfo(nil);
                end

                itemID = weapons[3];
                if itemID then
                    icon = GetItemIcon(itemID);
                    name = C_Item.GetItemNameByID(itemID);
                    self.OffHandSlot:SetSlotInfo(itemID, name, icon);
                else
                    self.OffHandSlot:SetSlotInfo(nil);
                end
            else
                self.MainHandSlot:SetSlotInfo(nil);
                self.OffHandSlot:SetSlotInfo(nil);
            end

            if actor.equippedWeapons and actor.equippedWeapons[1] then
                local weaponItemLink = actor.equippedWeapons[1];
                local _, _, _, _, _, classID, subclassID = GetItemInfoInstant(weaponItemLink);
                if classID == 2 and RANGED_WEAPON_SUBCLASS[subclassID] then
                    self:SetWeaponTypeSelection(true);
                else
                    self:SetWeaponTypeSelection();
                end
            else
                self:SetWeaponTypeSelection();
            end
        else
            self.MainHandSlot:DisableSlot();
            self.OffHandSlot:DisableSlot();
        end
    end

    self:UpdateSheathButton(actor);
end

function NarciPhotoModeWeaponFrameMixin:UpdateSheathButton(actor)
    if actor then
        local isHolding;
        if actor.SetSheathed and actor.GetSheathed then
            self.SheathButton:Enable();
            isHolding = not actor:GetSheathed();
        else
            if actor.equippedWeapons then
                self.SheathButton:Enable();
                isHolding = actor.holdWeapon;
            else
                self.SheathButton:Disable();
                isHolding = false;
            end
        end
        self.SheathButton.isOn = isHolding;
        if isHolding then
            self.SheathButton.Icon:SetTexCoord(0.5, 1, 0, 1);
        else
            self.SheathButton.Icon:SetTexCoord(0, 0.5, 0, 1);
        end
    end
end

function NarciPhotoModeWeaponFrameMixin:ToggleSheathButton()
    self.SheathButton:Enable();
    self.SheathButton.Icon:SetTexCoord(0.5, 1, 0, 1);
    self.SheathButton.isOn = true;
end

function NarciPhotoModeWeaponFrameMixin:SetWeaponTypeSelection(rangedWeapon)
    if rangedWeapon then
        --Use ranged weapon
        self.MainHandSlot.Selection:Hide();
        self.OffHandSlot.Selection:Show();
    else
        --use melee weapon
        self.MainHandSlot.Selection:Show();
        self.OffHandSlot.Selection:Hide();
    end
end

function NarciPhotoModeWeaponFrameMixin:SetPreferredWeapon(id)
    local rangedWeapon = id == 2;
    self:SetWeaponTypeSelection(rangedWeapon);

    local model = Narci.GetActiveActor();
    if model and model:IsObjectType("DressUpModel") then
        if model.originalWeapons then
            if rangedWeapon then
                model.equippedWeapons = { model.originalWeapons[3] };
            else
                model.equippedWeapons = { model.originalWeapons[1], model.originalWeapons[2] };
            end
            model:ReEquipWeapons();
        end
    end
end