local _, addon = ...
local API = addon.API;

--Pre WotLK: Add flyout to paperdoll itembutton for fast swapping items (Alt + Mouseover).
local FORCE_SHOWN = false;

if (PaperDollFrameItemFlyout or EquipmentFlyoutFrame) or FORCE_SHOWN then
    --PaperDollItemFlyout seems to be only working while using EquipmentSetManager? --WotLK Classic
    NarciAPI.SetUsePaperDollFlyout = function() end
    return
end

local NUM_BUTTONS_X = 5;
local NUM_BUTTONS_Y = 4;
local NUM_BUTTONS_PAGE = NUM_BUTTONS_X * NUM_BUTTONS_Y;

local tinsert = table.insert;
local IsKeyDown = IsKeyDown;
local CursorHasItem = CursorHasItem;
local ClearCursor = ClearCursor;
local GetContainerNumFreeSlots = C_Container.GetContainerNumFreeSlots;
local IsInventoryItemLocked = IsInventoryItemLocked;
local PickupInventoryItem = PickupInventoryItem;
local PickUpItemByItemID = NarciAPI.PickUpItemByItemID;
local GetItemInfo = API.GetItemInfo;
local GetItemCount = API.GetItemCount;
local GetCurrentItemLevel = C_Item.GetCurrentItemLevel;
local GetItemIcon = C_Item.GetItemIcon;
local GetItemIconByID = C_Item.GetItemIconByID;
local GetItemQuality = C_Item.GetItemQuality;
local DoesItemExist = C_Item.DoesItemExist;
local InCombatLockdown = InCombatLockdown;
local SharedItemLocation = ItemLocation:CreateEmpty();
local PaperDollFrame = PaperDollFrame;
local PaperDollItemButtons = {};
local GetInventoryItemsForSlot = GetInventoryItemsForSlot;
local UnpackLocation = NarciClassicAPI.EquipmentManager.UnpackLocation;
local GetOwnedAmmo = NarciClassicAPI.GetOwnedAmmo;
local NineSliceUtil = NarciAPI.NineSliceUtil;
local ITEM_INVENTORY_LOCATION_PLAYER = ITEM_INVENTORY_LOCATION_PLAYER or 1048576;
local BAG_ITEM_QUALITY_COLORS = BAG_ITEM_QUALITY_COLORS;
local NUM_BAG_SLOTS = NUM_BAG_SLOTS or 4;
local GameTooltip = GameTooltip;

local WEAPON_SLOTS_ID = {
    [16] = true,
    [17] = true,
    [18] = true,
    [0] = true,
}

local FocusedItemButton;
local FlyoutButtons, FlyoutData;


local FlyoutFrame = CreateFrame("Frame", nil, PaperDollFrame);
FlyoutFrame:EnableMouse(true);
FlyoutFrame:SetFrameStrata("DIALOG");
FlyoutFrame:SetFrameLevel(20);
FlyoutFrame:Hide();

FlyoutFrame.Background = FlyoutFrame:CreateTexture(nil, "BACKGROUND");
FlyoutFrame.Background:SetColorTexture(0.08, 0.08, 0.08, 0.8);
FlyoutFrame.Background:SetPoint("TOPLEFT", FlyoutFrame, "TOPLEFT", 0, 0);
FlyoutFrame.Background:SetPoint("BOTTOMRIGHT", FlyoutFrame, "BOTTOMRIGHT", 0, 0);

local CombatAlert = FlyoutFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
CombatAlert:Hide();
CombatAlert:SetSize(37 * (NUM_BUTTONS_X - 1), 36);
CombatAlert:SetPoint("CENTER", FlyoutFrame, "CENTER", 0, 0);
CombatAlert:SetText(Narci.L["Cannot Unequip Combat"]);
CombatAlert:SetTextColor(1, 1, 1);
CombatAlert:SetJustifyH("CENTER");
CombatAlert:SetJustifyV("MIDDLE");
CombatAlert:SetSpacing(2);

local function SortByItemLevel(a, b)
    if a.level ~= b.level then
        return a.level > b.level
    else
        return a.location > b.location
    end
end


local function HideTooltip()
    GameTooltip:Hide();
end

local function PaperDollItemButton_ShowTooltip(self)
    --if not FlyoutFrame:IsShown() then return end;

    GameTooltip:Hide();
	GameTooltip:SetOwner(FlyoutFrame, "ANCHOR_NONE");
    GameTooltip:SetPoint("BOTTOMLEFT", FlyoutFrame, "BOTTOMRIGHT", 4, -4);
	GameTooltip:SetInventoryItem("player", self:GetID(), nil, true);
    GameTooltip:Show();
end

local function UnequipSlot()
    local slotID = FlyoutFrame and FlyoutFrame.slotID;
    if not slotID then return end

    ClearCursor();

    if ( IsInventoryItemLocked(slotID) ) then
        return;
    else
        PickupInventoryItem(slotID);
    end

	if ( not CursorHasItem() ) then
		return;
	end

    local numSlots, bagType;
    local anyFreeSlots;

    for bag = 0, NUM_BAG_SLOTS do
        numSlots, bagType = GetContainerNumFreeSlots(bag);
        if numSlots and numSlots > 0 then
            if bag == 0 then
                PutItemInBackpack();
            else
                bag = bag + 19; --Player bag 20 - 24
                PutItemInBag(bag);
            end
            anyFreeSlots = true;
            break
        end
    end

    if not anyFreeSlots then
        UIErrorsFrame:AddMessage(ERR_INV_FULL, 1, 0, 0, 1.0, 0);   --ERR_EQUIPMENT_MANAGER_BAGS_FULL
    end

    ClearCursor();
end

local function FlyoutButton_OnEnable(self)
    self.Icon:SetDesaturated(false);
    self.IconBorder:SetDesaturated(false);
end

local function FlyoutButton_OnDisable(self)
    self.Icon:SetDesaturated(true);
    self.IconBorder:SetDesaturated(true);
    self.PushedTexture:Hide();
end

local function FlyoutButton_OnEnter(self)
    --GameTooltip:Hide();

    if self.unequip then
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT");
        GameTooltip:SetText(EQUIPMENT_MANAGER_PLACE_IN_BAGS, 1, 1, 1, true);
        GameTooltip:Show();
    else
        if self.slot then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT");

            if self.bag then
                GameTooltip:SetBagItem(self.bag, self.slot);
            else
                GameTooltip:SetInventoryItem("player", self.slot, nil, true);
            end

            GameTooltip:Show();
            GameTooltip_ShowCompareItem(GameTooltip);
        elseif self.itemID then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT");
            GameTooltip:SetItemByID(self.itemID);
            GameTooltip:Show();
            --GameTooltip_ShowCompareItem(GameTooltip);   --doesn't work
        end
    end
end

local function LockFlyoutButtons()
    for _, button in ipairs(FlyoutButtons) do
        button:Disable();
    end
end

local function FlyoutButton_OnClick(self, mouseButton)
    if self.unequip then
        LockFlyoutButtons();
        UnequipSlot();
    else
        local targetSlot = FlyoutFrame and FlyoutFrame.slotID;
        if not targetSlot then return end

        ClearCursor();

        if self.slot then
            LockFlyoutButtons();

            if self.bag then
                C_Container.PickupContainerItem(self.bag, self.slot);
            else
                PickupInventoryItem(self.slot);
            end

            if CursorHasItem() then
                PickupInventoryItem(targetSlot);
                ClearCursor()
            end
        elseif self.itemID then
            PickUpItemByItemID(self.itemID);
            if CursorHasItem() then
                PickupInventoryItem(18);
                ClearCursor();
            end
        end
    end
end

local function CleanFlyoutButton(button)
    button.bag = nil;
    button.slot = nil;
    button.itemID = nil;
end

local function SetupFlyoutButton(button, data)
    if data then
        button.bag = data.bag;
        button.slot = data.slot;
        button.itemID = data.itemID;

        if data.unequip then
            button.Icon:SetTexture("Interface\\PaperDollInfoFrame\\UI-GearManager-ItemIntoBag");
            button.IconBorder:Hide();
            button.unequip = true;
        else
            button.Icon:SetTexture(data.icon);
            button.IconBorder:Show();
            button.unequip = nil;
        end

        if data.level then
            button.ItemLevel:Show();
            button.ItemLevel:SetText(data.level);
        else
            button.ItemLevel:Hide();
        end

        if data.ammo and data.itemID then
            button.ItemLevel:Show();
            local count = GetItemCount(data.itemID);
            if count > 9999 then
                count = "9999+";
            end
            button.ItemLevel:SetText(count);
            button.ItemLevel:Show();
        end

        --Set Quality Color
        local quality = data.quality;
        if quality then
            if BAG_ITEM_QUALITY_COLORS[quality] then
                button.IconBorder:Show();
                button.IconBorder:SetVertexColor(BAG_ITEM_QUALITY_COLORS[quality].r, BAG_ITEM_QUALITY_COLORS[quality].g, BAG_ITEM_QUALITY_COLORS[quality].b);
            else
                button.IconBorder:Hide();
            end
        end
    else
        CleanFlyoutButton(button);
    end
end

local ShowFlyout;

local function HideFlyout(itemButton)
    FlyoutFrame:Hide();
    FlyoutFrame:ClearAllPoints();
    FlyoutFrame.slotID = nil;
    FlyoutData = nil;
    GameTooltip:Hide();
end

local function FlyoutFrame_OnUpdate(self, elapsed)
    self:SetScript("OnUpdate", nil);
    self.pauseUpdate = nil;

    if self:IsVisible() then
        if self.parentButton then
            ShowFlyout(self.parentButton);
        end
    end
end

local function FlyoutFrame_OnShow(self)
    self:RegisterEvent("BAG_UPDATE");
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
    self:RegisterEvent("PLAYER_REGEN_DISABLED");
    self:RegisterEvent("PLAYER_REGEN_ENABLED");
    self:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player");
end

local function FlyoutFrame_OnHide(self)
    self:UnregisterEvent("BAG_UPDATE");
    self:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED");
    self:UnregisterEvent("PLAYER_REGEN_DISABLED");
    self:UnregisterEvent("PLAYER_REGEN_ENABLED");
    self:UnregisterEvent("UNIT_INVENTORY_CHANGED");
    HideFlyout();
end

local function FlyoutFrame_OnEvent(self, event, ...)
    if not self.pauseUpdate then
        self.pauseUpdate = true;
        self:SetScript("OnUpdate", FlyoutFrame_OnUpdate);
    end

    if event == "PLAYER_REGEN_DISABLED" then
        LockFlyoutButtons();
    end
end

function ShowFlyout(itemButton)
    local id = itemButton:GetID();
    FlyoutFrame.parentButton = itemButton;

    local isWeapon = WEAPON_SLOTS_ID[id];

    if itemButton then
        if not FlyoutButtons then
            --Initialization
            FlyoutButtons = {};
            FlyoutFrame:SetScript("OnShow", FlyoutFrame_OnShow);
            FlyoutFrame:SetScript("OnHide", FlyoutFrame_OnHide);
            FlyoutFrame:SetScript("OnEvent", FlyoutFrame_OnEvent);
            NineSliceUtil.SetUpBorder(FlyoutFrame, "blizzardTooltip", -4, 213, 181, 70);
        end

        local inCombat = InCombatLockdown();

        local itemLocations = {};
        local numItems = 0;

        FlyoutData = {};

        if id == 0 then
            local ammos = GetOwnedAmmo();
            local itemName, _, quality, itemLevel, itemIcon;
            if ammos and (#ammos > 0) then
                for i, itemID in ipairs(ammos) do
                    itemName, _, quality, itemLevel = GetItemInfo(itemID);
                    itemIcon = GetItemIconByID(itemID);
                    tinsert(FlyoutData, {level = itemLevel, icon = itemIcon, quality = quality, itemID = itemID, ammo = true });
                end
            end
            numItems = #FlyoutData;
        else
            GetInventoryItemsForSlot(id, itemLocations);

            local itemIcon, quality, itemLevel, itemInfo, player, bags, banks, _, slot, bag;
            local invLocationPlayer = id + ITEM_INVENTORY_LOCATION_PLAYER;

            for location, hyperlink in pairs(itemLocations) do
                if ( location == invLocationPlayer ) then -- Remove the currently equipped item from the list
                    itemLocations[location] = nil;
                else
                    player, _, bags, banks, slot, bag = UnpackLocation(location);
                    if player and slot and bags then
                        if bags or banks then
                            SharedItemLocation:SetBagAndSlot(bag, slot);
                        else
                            SharedItemLocation:SetEquipmentSlot(slot);
                        end
                        itemLevel = GetCurrentItemLevel(SharedItemLocation);
                        itemIcon = GetItemIcon(SharedItemLocation);
                        quality = GetItemQuality(SharedItemLocation);
                        itemInfo = {level = itemLevel, location = location, icon = itemIcon, quality = quality, bag = bag, slot = slot};
                        tinsert(FlyoutData, itemInfo);
                    end
                end
            end

            numItems = #FlyoutData;
            if numItems > 0 then
                table.sort(FlyoutData, SortByItemLevel);
            end
        end

        local numButtons = math.min(numItems, NUM_BUTTONS_PAGE);

        if id ~= 0 then
            SharedItemLocation:SetEquipmentSlot(id);
            if DoesItemExist(SharedItemLocation) then
                --Add unequip button is the slot is not empty
                numButtons = numButtons + 1;
                tinsert(FlyoutData, 1, {unequip = true});
            end
        end

        if #FlyoutData == 0 then
            HideFlyout();
            return
        end

        PaperDollItemButton_ShowTooltip(itemButton);

        local col, row = 0, 1;
        local button;

        for i = 1, numButtons do
            col = col + 1;
            if col > NUM_BUTTONS_X then
                col = 1;
                row = row + 1;
            end
            button = FlyoutButtons[i];
            if not button then
                FlyoutButtons[i] = CreateFrame("Button", nil, FlyoutFrame, "NarciPaperDollFlyoutButtonTemplate");
                button = FlyoutButtons[i];
                button:SetPoint("TOPLEFT", FlyoutFrame, "TOPLEFT", 37*(col - 1), 37*(row - 1));

                button:SetScript("OnEnter", FlyoutButton_OnEnter);
                button:SetScript("OnLeave", HideTooltip);
                button:SetScript("OnClick", FlyoutButton_OnClick);
                button:SetScript("OnEnable", FlyoutButton_OnEnable);
                button:SetScript("OnDisable", FlyoutButton_OnDisable);

                button.UpdateTooltip = FlyoutButton_OnEnter;
            end

            SetupFlyoutButton(button, FlyoutData[i]);

            if inCombat then
                button:Disable();
            else
                button:Enable();
            end

            button:Hide();
            button:Show();
        end

        for i = numButtons + 1, #FlyoutButtons do
            FlyoutButtons[i]:Hide();
        end

        if row > 1 or inCombat then
            col = NUM_BUTTONS_X;
        end

        FlyoutFrame:ClearAllPoints();
        FlyoutFrame:SetSize(37 * col, 37 * row);

        if isWeapon then
            FlyoutFrame:SetPoint("TOPLEFT", itemButton, "BOTTOMLEFT", 0, -6);
        else
            FlyoutFrame:SetPoint("TOPLEFT", itemButton, "TOPRIGHT", 6, 0);
        end

        FlyoutFrame.slotID = id;
        FlyoutFrame:Show();

        local frameLevel;

        if inCombat then
            if not CombatAlert:IsShown() then
                NineSliceUtil.SetBorderColor(FlyoutFrame, 255, 80, 80);    --red
                frameLevel = FlyoutFrame:GetFrameLevel() - 4;
                for i = 1, numButtons do
                    FlyoutButtons[i]:SetFrameLevel(frameLevel);
                end
            end
        else
            if CombatAlert:IsShown() then
                NineSliceUtil.SetBorderColor(FlyoutFrame, 213, 181, 70);    --gold regular
                frameLevel = FlyoutFrame:GetFrameLevel() + 4;
            end
        end

        if frameLevel then
            for i = 1, numButtons do
                FlyoutButtons[i]:SetFrameLevel(frameLevel);
            end
        end

        CombatAlert:SetShown(inCombat);
    end
end

local FLYOUT_ENABLED = true;
local EventHandler = CreateFrame("Frame", "NarciPaperDollEventHandler", PaperDollFrame);

EventHandler:RegisterEvent("MODIFIER_STATE_CHANGED");

local function EventHandler_AltKeyChanged(down)
    if down then
        --Get Moused-over button
        if PaperDollFrame:IsMouseOver() then
            if FocusedItemButton then
                ShowFlyout(FocusedItemButton);
            end
        end
    else
        HideFlyout();
        if FocusedItemButton and FocusedItemButton:IsMouseOver() then
            PaperDollItemSlotButton_OnEnter(FocusedItemButton);
        end
    end
end

local function EventHandler_OnEvent(self, event, ...)
    --print(event, ...);
    if event == "MODIFIER_STATE_CHANGED" then
        local key, state = ...
        if key == "LALT" then
            EventHandler_AltKeyChanged(state == 1);
        end
    end
end

EventHandler:SetScript("OnEvent", EventHandler_OnEvent);


local function ItemButton_OnEnter(self)
    FocusedItemButton = self;
    if IsKeyDown("LALT") and FLYOUT_ENABLED then
        ShowFlyout(self);
    else
        if FlyoutFrame:IsShown() then
            HideFlyout();
        end
    end
end

local function ItemButton_OnLeave(self)
    FocusedItemButton = nil;
end

local IS_PAPERDOLL_HOOKED;

local function HookPaperDollItemButtons()
    if IS_PAPERDOLL_HOOKED then return end;

    local PAPERDOLL_BUTTON_FORMAT = "Character%sSlot";
    local PAPERDOLL_BUTTON_NAMES = {
        "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist",
        "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1",
        "MainHand", "SecondaryHand", "Ranged", "Ammo",
    };

    local _G = _G;
    local button;

    for _, name in ipairs(PAPERDOLL_BUTTON_NAMES) do
        button = _G[string.format(PAPERDOLL_BUTTON_FORMAT, name)];
        if button then
            button:HookScript("OnEnter", ItemButton_OnEnter);
            button:HookScript("OnLeave", ItemButton_OnLeave);
            tinsert(PaperDollItemButtons, button);
        else
            print("Narcissus: Missing Slot "..name);
        end
    end

    IS_PAPERDOLL_HOOKED = true;
end

local function SetUsePaperDollFlyout(state)
    HookPaperDollItemButtons();
    FlyoutFrame:Hide();
    if state then
        EventHandler:RegisterEvent("MODIFIER_STATE_CHANGED");
        FLYOUT_ENABLED = true;
    else
        EventHandler:UnregisterEvent("MODIFIER_STATE_CHANGED");
        FLYOUT_ENABLED = false;
    end
end

NarciAPI.SetUsePaperDollFlyout = SetUsePaperDollFlyout;


do
    local SettingFunctions = addon.SettingFunctions;

    function SettingFunctions.SetUsePaperDollFlyout(state, db)
        if state == nil then
            state = db["ItemFlyout"];
        end

        SetUsePaperDollFlyout(state);
    end
end