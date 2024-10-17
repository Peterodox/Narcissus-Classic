local _, addon = ...

local L = Narci.L;
local AttributeFrame = Narci_Attribute;
local ESM = NarciEquipmentSetManager;
local GamePadButtonPool = addon.GamePadButtonPool;

local ag = addon.CreateActionGroup("ClassicEquipmentSet");
ag.repeatInterval = 0.25;

function ag:Init()
    self.setButtons = ESM:GetSetButtons();
    self.setIndex = 1;

    hooksecurefunc(ESM, "ExitEditMode", function()
        self.editMode = nil;
        if ag.active then
            ag:Navigate(0, 0);
        end
    end);

    hooksecurefunc(ESM, "OnUpdateComplete", function()
        if ag.active then
            self.setButtons = ESM:GetSetButtons();
            local numSets = #self.setButtons;
            local y = 0;
            if numSets ~= self.numSets then
                if numSets < self.numSets then
                    y = numSets - self.numSets;
                end
                self.numSets = numSets;
                ag:Navigate(0, y);
            end
        end
    end);
end

function ag:OnActiveCallback()
    self.setButtons = ESM:GetSetButtons();
    self.numSets = #self.setButtons;
    self.setIndex = 0;
    self.editMode = nil;

    self:Navigate(0, -1);
    addon.GamePadNavBar:SelectButtonByID(2);
end

function ag:ResetNavigation()

end

function ag:Navigate(x, y)
    if self.editMode then

    else
        --Browsing saved sets
        local moveDirection;
        if x > 0 or y < 0 then
            if self.setIndex < self.numSets then
                self.setIndex = self.setIndex + 1;
                moveDirection = -1;
            else
                return
            end
        elseif x < 0 or y > 0 then
            if self.setIndex > 1 then
                self.setIndex = self.setIndex - 1;
                moveDirection = 1;
            else
                return
            end
        end
        GamePadButtonPool:HideAllButtons();
        self:Enter(self.setButtons[self.setIndex]);
        if self.currentObj then
            if self.currentObj.setID then
                local pad1 = GamePadButtonPool:SetupButton("PAD3", L["GamePad Equip"], AttributeFrame, "TOPLEFT", ESM, "BOTTOMLEFT", 0, -4, 1);
                local pad3 = GamePadButtonPool:SetupButton("PAD1", L["Edit Loadout"], AttributeFrame, "TOPLEFT", pad1, "BOTTOMLEFT", 0, -4, 1);
            else
                --"New Set" button
                local pad1 = GamePadButtonPool:SetupButton("PAD1", L["New Set"], AttributeFrame, "TOPLEFT", ESM, "BOTTOMLEFT", 0, -4, 1);
            end
        end
    end
end

function ag:Switch(x)
    if x < 0 then
        addon.SelectActionGroup("EquipmentSlot");
        if ESM:IsShown() then
            Narci_ItemLevelFrame.CenterButton:Click();
        end
    elseif x > 0 then

    end
end

function ag:KeyDown(key)
    if self.editMode then
        if key =="PAD2" then
            ESM:CancelChanges();
            self.editMode = nil;
            self:Navigate(0, 0);
        elseif key == "PAD3" then
            if self.currentObj then
                ESM:ConfirmChanges();
            end
            self.editMode = nil;
            self:Navigate(0, 0);
        end
    else
        if key == "PAD1" then
            self:Click("RightButton");
            self.editMode = true;
            GamePadButtonPool:HideAllButtons();
            if self.currentObj then
                local pad3 = GamePadButtonPool:SetupButton("PAD3", L["GamePad Confirm"], AttributeFrame, "TOPLEFT", ESM, "BOTTOMLEFT", 0, -4, 1);
                local pad2 = GamePadButtonPool:SetupButton("PAD2", L["GamePad Cancel"], AttributeFrame, "TOP", pad3, "BOTTOM", 0, -4, 1);
            end
        elseif key == "PAD3" then
            if self.currentObj and self.currentObj.setID then
                self.currentObj:OnDoubleClick("LeftButton");
            end
        elseif key == "PAD2" then
            addon.SelectActionGroup("CharacterFrame");
            if ESM:IsShown() then
                Narci_ItemLevelFrame.CenterButton:Click();
            end
        end
    end
end