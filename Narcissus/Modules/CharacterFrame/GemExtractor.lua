local Narci = Narci;

local After = C_Timer.After;
local GetContainerNumFreeSlots = GetContainerNumFreeSlots;
local GetContainerNumSlots = GetContainerNumSlots;
local GetContainerItemID = GetContainerItemID;
local GetItemCount = GetItemCount;
local NUM_BAGS = NUM_BAG_SLOTS or 4;

local REQUIREMENT_FORMAT = "|cff808080"..REQUIRES_LABEL.." %s|r";
local EXTRACTOR_ITEM_ID = 187532;   --Soulfire Chisel
local EXTRACTOR_ITEM_NAME = "Soulfire Chisel";
local EXTRACTOR_ITEM_LOCALIZED_NAME = C_Item.GetItemNameByID(EXTRACTOR_ITEM_ID);    --nilable
local MARCO_USE_ITEM_BY_ID = "/use item:%s";

local targetItem;

local function DoesPlayerHaveItem(itemID)
    return GetItemCount(itemID) > 0
end

local function GetBagPosition(itemID)
    for bagID = 0, NUM_BAGS do
        for slotIndex = 1, GetContainerNumSlots(bagID) do
            if(GetContainerItemID(bagID, slotIndex) == itemID) then
                return bagID, slotIndex
            end
        end
    end
end

local function GetNumFreeBagSlots()
    --a copy of CalculateTotalNumberOfFreeBagSlots
	local totalFree, freeSlots, bagFamily = 0;
	for i = 0, NUM_BAGS do --BACKPACK_CONTAINER, NUM_BAG_SLOTS
		freeSlots, bagFamily = GetContainerNumFreeSlots(i);
		if ( bagFamily == 0 ) then
			totalFree = totalFree + freeSlots;
		end
	end
	return totalFree;
end

local function GetCurrentSocketingItem(bag, slot)
    local itemlocation;
    if not bag then
        itemlocation = ItemLocation:CreateFromEquipmentSlot(slot);
    else
        itemlocation = ItemLocation:CreateFromBagAndSlot(bag, slot);
    end
    return itemlocation;
end


--/dump GetMouseFocus().itemLocation:GetBagAndSlot()
--Protected: UseContainerItem
--ItemLocation:SetBagAndSlot(bagID, slotIndex);
--local itemIsValidItem = itemLocation:IsValid() and C_Item.DoesItemExist(itemLocation);

--[[
    1, 16
--]]


local IsMounted = IsMounted;
local IsFlying = IsFlying;
local function ActionButton_OnUpdate(self, elapsed)
    if not self.t then
        self.t = 0;
    end
    self.t = self.t + elapsed;
    if self.t >= 0.5 then
        if IsFlying() then
            self.t = nil;
            self:SetScript("OnUpdate", nil);
            self:SetFailedReason(2);
        end
    else
        return
    end
end


--------------------------------------------------------------
--Extract Domination Shard
local function SharedPostClickFunc(self, button)
    if button == "RightButton" then
        return
    end
    self:StopAnimating();
    self.ArrowLeft.Expand:Play();
    self.ArrowRight.Expand:Play();
    self:Disable();
    After(0.8, function()
        self:AttemptToEnable();
    end);
end

local function NarcissusActionButton_PostClick(self, button)
    if button == "RightButton" then
        Narci_EquipmentOption:ShowMenu();
        return
    end
    self:RegisterEvent("BAG_UPDATE");
    SharedPostClickFunc(self);
    local gemFrame = NarciGemSlotOverlay;
    if gemFrame:IsShown() then
        gemFrame.Pulse.Expand:Stop();
        gemFrame.Pulse.Shrink:Play();
    end
end


NarciItemSocketingActionButtonMixin = {};

function NarciItemSocketingActionButtonMixin:OnLoad()
    self.isReleased = true;
    self:SetLabelText("Extract Shard");
    self:OnLeave();
end

function NarciItemSocketingActionButtonMixin:OnEnter()
    self.Label:SetTextColor(0.92, 0.92, 0.92);
    self.ArrowLeft:SetVertexColor(1, 1, 1);
    self.ArrowRight:SetVertexColor(1, 1, 1);
    self:StopAnimating();
    self.ArrowLeft.Close:Play();
    self.ArrowRight.Close:Play();
end

function NarciItemSocketingActionButtonMixin:OnLeave()
    self.Label:SetTextColor(102/255, 187/255, 1);
    self.ArrowLeft:SetVertexColor(0.5, 0.5, 0.5);
    self.ArrowRight:SetVertexColor(0.5, 0.5, 0.5);
    self.ArrowLeft.Close:Stop();
    self.ArrowRight.Close:Stop();
end

function NarciItemSocketingActionButtonMixin:OnShow()
    self:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED");
    self:RegisterEvent("PLAYER_REGEN_DISABLED");
    if not self:IsMouseOver() then
        self:OnLeave();
    end
end

function NarciItemSocketingActionButtonMixin:OnHide()
    self:StopAnimating();
    self:UnregisterEvent("PLAYER_REGEN_DISABLED");
    self:UnregisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED");
    self:Release();
end

function NarciItemSocketingActionButtonMixin:DisableButton()
    self:Disable();
    if not EXTRACTOR_ITEM_LOCALIZED_NAME then
        EXTRACTOR_ITEM_LOCALIZED_NAME = C_Item.GetItemNameByID(EXTRACTOR_ITEM_ID);
    end
    self.Label:SetText( string.format(REQUIREMENT_FORMAT, (EXTRACTOR_ITEM_LOCALIZED_NAME or EXTRACTOR_ITEM_NAME)) );
end

function NarciItemSocketingActionButtonMixin:AttemptToEnable()
    self:Show();
    self:SetScript("OnUpdate", nil);
    local numFreeSlots = GetNumFreeBagSlots();
    if numFreeSlots > 0 then
        if IsMounted() then
            if IsFlying() then
                self:SetFailedReason(2);
            else
                self:TrackFlyingStatus();
                self:Enable();
                self.Label:SetText(Narci.L["Extract Shard"]);
            end
        else
            self:Enable();
            self.Label:SetText(Narci.L["Extract Shard"]);
        end
    else
        self:SetFailedReason(1);
    end
end

function NarciItemSocketingActionButtonMixin:TrackFlyingStatus()
    self:SetScript("OnUpdate", ActionButton_OnUpdate);
end

function NarciItemSocketingActionButtonMixin:SetFailedReason(id)
    self:Disable();
    if id == 1 then
        self.Label:SetText(TUTORIAL_TITLE58);
    elseif id == 2 then
        self.Label:SetText(string.gsub(SPELL_FAILED_NOT_FLYING, "[%.。]", ""));
    end
end

function NarciItemSocketingActionButtonMixin:SetLabelText(text)
    self.Label:SetText(text);
    local textWidth = self.Label:GetWidth();
    if textWidth < 64 then
        textWidth = 64;
    end
    --self:SetWidth(textWidth + 24);
end

function NarciItemSocketingActionButtonMixin:SetActionForBlizzardUI()
    self:SetExtractAction();
    self:SetScript("PostClick", SharedPostClickFunc);
    self:UnregisterEvent("BAG_UPDATE");
end


function NarciItemSocketingActionButtonMixin:OnEnterCombat()
    self:Release();
    if self.parentFrame and self.parentFrame.ErrorMsg then
        self.parentFrame.ErrorMsg:Show();
    end
    self:RegisterEvent("PLAYER_REGEN_ENABLED");
end

function NarciItemSocketingActionButtonMixin:OnLeaveCombat()
    if self.parentFrame and self.parentFrame.ErrorMsg then
        self.parentFrame.ErrorMsg:Hide();
        self:SetParentFrame(self.parentFrame);
    end
end

function NarciItemSocketingActionButtonMixin:OnExtactSuccess()
    self:UnregisterEvent("BAG_UPDATE");
    local slotButton = Narci.RefreshSlot(self.equipmentSlotIndex);
    After(0.5, function()
        if Narci_EquipmentOption:IsShown() then
            Narci_EquipmentOption:SetGemListFromSlotButton(slotButton);
        end
        local gemFrame = NarciGemSlotOverlay;
        if gemFrame:IsShown() then
            gemFrame.Pulse.Shrink:Stop();
            gemFrame.Pulse.Expand:Play();
        end
    end);
end

function NarciItemSocketingActionButtonMixin:OnMountChanged()
    After(0.1, function()
        if not self.isReleased then
            self:AttemptToEnable();
        end
    end)
end

function NarciItemSocketingActionButtonMixin:OnEvent(event)
    if event == "BAG_UPDATE" then
        self:OnExtactSuccess();
    elseif event == "PLAYER_REGEN_DISABLED" then
        self:OnEnterCombat();
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:OnLeaveCombat();
    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        self:OnMountChanged();
    end
end

function NarciItemSocketingActionButtonMixin:OnEnable()
    self:SetScript("OnUpdate", nil);
    self:StopAnimating();
    self.ArrowLeft:SetDesaturated(false);
    self.ArrowRight:SetDesaturated(false);
    self.ArrowLeft:SetAlpha(1);
    self.ArrowRight:SetAlpha(1);
    if self:IsMouseOver() then
        self.Label:SetTextColor(0.92, 0.92, 0.92);
    else
        self.Label:SetTextColor(102/255, 187/255, 1);
    end
end

function NarciItemSocketingActionButtonMixin:OnDisable()
    self.ArrowLeft:SetDesaturated(true);
    self.ArrowRight:SetDesaturated(true);
    self.Label:SetTextColor(0.5, 0.5, 0.5);
end

function NarciItemSocketingActionButtonMixin:SetActionForNarcissusUI()
    local itemID = EXTRACTOR_ITEM_ID;
    local equipmentSlotIndex = Narci_EquipmentOption.slotID;
    self.equipmentSlotIndex = equipmentSlotIndex;
    if DoesPlayerHaveItem(itemID) and equipmentSlotIndex then
        local macroText = string.format("/use item:%s\r/use %s", itemID, equipmentSlotIndex);
        self:SetAttribute("type1", "macro");
        self:SetAttribute("macrotext", macroText);
        self:AttemptToEnable();
        self:RegisterForClicks("LeftButtonUp", "RightButtonUp");
        self:SetScript("PostClick", NarcissusActionButton_PostClick);
    else
        self:DisableButton();
    end
end

function NarciItemSocketingActionButtonMixin:SetExtractAction()
    local itemID = EXTRACTOR_ITEM_ID;
    if DoesPlayerHaveItem(itemID) then
        local macroText = string.format("/use item:%s\r/click ItemSocketingSocket1", itemID);
        self:SetAttribute("type1", "macro");
        self:SetAttribute("macrotext", macroText);
        self:AttemptToEnable();
    else
        self:DisableButton();
    end
end

function NarciItemSocketingActionButtonMixin:SetParentFrame(frame, isNarcissusUI)
    self.parentFrame = frame;
    if InCombatLockdown() then
        self:RegisterEvent("PLAYER_REGEN_ENABLED");
        return false;
    end
    if frame then
        self:SetParent(frame);
        self:ClearAllPoints();
        self:SetPoint("CENTER", frame, "CENTER", 0, 0);
        if isNarcissusUI then
            self:SetActionForNarcissusUI();
        else
            self:SetActionForBlizzardUI();
        end
        self.isReleased = nil;
        self.FadeIn:Play();
    else
        self:Release();
    end
    return true;
end

function NarciItemSocketingActionButtonMixin:Release()
    if not self.isReleased then
        self:Hide();
        self:ClearAllPoints();
        self:SetParent(NarciSecureFrameContainer);
        self.isReleased = true;
    end
end