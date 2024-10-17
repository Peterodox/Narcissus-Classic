local _, addon = ...

local ag = addon.CreateActionGroup("EquipmentSlot");
ag.repeatInterval = 0.25;

local SlotBorder = NarciGamePadOverlay.SlotBorder;

ag:SetButtonDescription("A", Narci.L["Select"]);
ag:SetButtonDescription("B", Narci.L["Cancel"]);
ag:SetButtonDescription("X", Narci.L["Use"]);

function ag:Init()
    local slotFrame = Narci_Character;
    self.buttons = {};
    self.buttons[1] = {     --Left column
        slotFrame.HeadSlot,
        slotFrame.NeckSlot,
        slotFrame.ShoulderSlot,
        slotFrame.BackSlot,
        slotFrame.ChestSlot,
        slotFrame.WristSlot,
        slotFrame.MainHandSlot,
        slotFrame.SecondaryHandSlot,
    };

    if slotFrame.RangedSlot then
        table.insert(self.buttons[1], slotFrame.RangedSlot);
    end

    self.buttons[2] = {     --Right column
        slotFrame.HandsSlot,
        slotFrame.WaistSlot,
        slotFrame.LegsSlot,
        slotFrame.FeetSlot,
        slotFrame.Finger0Slot,
        slotFrame.Finger1Slot,
        slotFrame.Trinket0Slot,
        slotFrame.Trinket1Slot,
        slotFrame.ShirtSlot,
        slotFrame.TabardSlot,
    };

    self.row = 0;
    self.col = 1;
    self.maxRow = math.max(#self.buttons[1], #self.buttons[2]);
    self.maxCol = 2;
end

function ag:Enter(currentObj)
    self:Leave();
    if currentObj and currentObj.OnEnter then
        SlotBorder:AnchorToSlotButton(currentObj);
        currentObj:OnEnter(nil, true);
        addon.ClickProxy:SetUseItem(currentObj.slotID);
    end
    self.currentObj = currentObj;
end

function ag:KeyDown(key)
    local hold, propagate;
    if key == "PAD1" then
        if self.currentObj then
            Narci_EquipmentOption:SetFromSlotButton(self.currentObj, true);
        end
    elseif key == "PAD2" then
        self:Leave();
    elseif key == "PAD3" then
        --use item
        if self.currentObj and self.currentObj.AnchorAlertFrame then
            self.currentObj:AnchorAlertFrame();
        end
        propagate = true;
    end
    return hold, propagate
end

function ag:KeyUp(key)

end

function ag:Navigate(x, y)
    -- x > 0 PADDRIGHT, x < 0 PADDLEFT
    -- y > 0 PADDUP, x < 0 PADDDOWN
    if x > 0 then
        self.col = self.col + 1;
        if self.col > self.maxCol then
            self.col = 1;
        end
    elseif x < 0 then
        self.col = self.col - 1;
        if self.col < 1 then
            self.col = self.maxCol;
        end
    end

    if not self.buttons[self.col][self.row] then
        self.row = #self.buttons[self.col];
    end

    if y > 0 then
        self.row = self.row - 1;
        if self.row < 1 then
            self.row = #self.buttons[self.col];
        end
    elseif y < 0 then
        self.row = self.row + 1;
        if self.row > #self.buttons[self.col] then
            self.row = 1;
        end
    end
    self:Enter(self.buttons[self.col][self.row]);
    return true
end

function ag:Switch(x)
    if x > 0 then
        addon.SelectActionGroup("CharacterFrame", 0);
        self:Leave();
    end
end

function ag:OnActiveCallback(mode)
    if mode then
        if mode == 1 then
            self.col = 1;
            self.row = 1;
        elseif mode == 2 then
            self.col = 2;
            self.row = 1;
        elseif mode == 3 then
            self.col = 1;
            self.row = self.maxRow;
        elseif mode == 4 then
            if self.row == 0 then
                self.row = 1;
            end
        end
    end
    self:Enter(self.buttons[self.col][self.row]);
    addon.GamePadNavBar:SelectButtonByID(1);
end

function ag:ResetNavigation()
    self.row = 0;
    self.col = 1;
end