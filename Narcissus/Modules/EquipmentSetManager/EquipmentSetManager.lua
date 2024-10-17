local _, addon = ...

do
    --Check API validity
    if not C_EquipmentSet then
        print("Narcissus: C_EquipmentSet Missing");
    else
        local API = {
            "CreateEquipmentSet",
            "DeleteEquipmentSet",
            "GetEquipmentSetIDs",
            "GetEquipmentSetInfo",
            "SaveEquipmentSet",
            "UseEquipmentSet",
        };

        local count = 0;

        for _, name in ipairs(API) do
            if not C_EquipmentSet[name] then
                if count == 0 then
                    print("Narcissus: EquipmentSet API Missing");
                end
                count = count + 1;
                print(count..". "..name);
            end
        end
    end
end

local MAX_SETS = MAX_EQUIPMENT_SETS_PER_PLAYER or 10;
local GAME_HAS_EQUIPMENT_MANAGER = PaperDollFrame.EquipmentManagerPane and true or false;

local C_EquipmentSet = C_EquipmentSet or {};
local GetEquipmentSetInfo = C_EquipmentSet.GetEquipmentSetInfo
local SetEquipmentSetTooltip = addon.GameTooltip_SetEquipmentSet;
local L = Narci.L;
local After = C_Timer.After;
local GameTooltip = GameTooltip;
local NarciGameTooltip = NarciGameTooltip;
local SetGradientTexture = NarciClassicAPI.SetGradientTexture;

local MainFrame, MouseOverFrame, IconSelector, NameEditor, FocusedButton, OverwriteButton, DeleteButton;
local NARCISSUS_MODE;
local EDIT_MODE;
local EDIT_TARGET;  --the equipmentSetID that's being changed

local SetButtons = {};


local function DeleteSet(setID)
    if not setID then return end;
    C_EquipmentSet.DeleteEquipmentSet(setID);
    MainFrame:OnEvent("EQUIPMENT_SETS_CHANGED");
end


local OnEnterHandler = CreateFrame("Frame");    --delay scripts
OnEnterHandler:Hide();

local function OnEnterHandlerOnUpdate_ShowSetInfo(self, elapsed)
    self.t = self.t + elapsed;
    if self.t >= 0 then
        if self.owner and self.owner.setID then
            if NARCISSUS_MODE then
                NarciGameTooltip:HideTooltip();
                NarciGameTooltip:SetOwner(self.owner, "ANCHOR_NONE");
                NarciGameTooltip:SetPoint("TOPRIGHT", self.owner, "TOPLEFT", -8, -8);
                SetEquipmentSetTooltip(NarciGameTooltip, self.owner.setID, true);
                NarciGameTooltip:FadeIn();
            else
                GameTooltip:Hide();
                GameTooltip:SetOwner(self.owner, "ANCHOR_NONE");
                GameTooltip:SetPoint("TOPLEFT", self.owner, "TOPRIGHT", 2, 0);
                SetEquipmentSetTooltip(GameTooltip, self.owner.setID, true);
                GameTooltip:Show();
            end
        end
        self:Stop();
    end
end

local function OnEnterHandlerOnUpdate_ShowNewSet(self, elapsed)
    self.t = self.t + elapsed;
    if self.t >= 0 then
        if self.owner then
            if NARCISSUS_MODE then
                NarciGameTooltip:HideTooltip();
                NarciGameTooltip:SetOwner(self.owner, "ANCHOR_NONE");
                NarciGameTooltip:SetPoint("TOPRIGHT", self.owner, "TOPLEFT", -8, -8);
                NarciGameTooltip:SetText(L["New Set"], 1, 1, 1, true);
                NarciGameTooltip:AddLine(L["Equipment Gesture Create"], 0.25, 0.78, 0.92, true);
                NarciGameTooltip:Show();
                NarciGameTooltip:FadeIn();
            else
                GameTooltip:Hide();
                GameTooltip:SetOwner(self.owner, "ANCHOR_NONE");
                GameTooltip:SetPoint("TOPLEFT", self.owner, "TOPRIGHT", 2, 0);
                GameTooltip:SetText(L["New Set"], 1, 1, 1, true);
                GameTooltip:AddLine(L["Equipment Gesture Create"], 0.25, 0.78, 0.92, true);
                GameTooltip:Show();
            end
        end
        self:Stop();
    end
end

function OnEnterHandler:ShowSetInfo(button)
    self.t = -0.5;
    self.owner = button;
    self:SetScript("OnUpdate", OnEnterHandlerOnUpdate_ShowSetInfo);
    self:Show();
end

function OnEnterHandler:ShowNewSet(button)
    self.t = -0.5;
    self.owner = button;
    self:SetScript("OnUpdate", OnEnterHandlerOnUpdate_ShowNewSet);
    self:Show();
end

function OnEnterHandler:Stop()
    self:Hide();
    self.t = nil;
    self.owner = nil;
end


local function HideButtonTooltip()
    OnEnterHandler:Stop();
    if NARCISSUS_MODE then
        NarciGameTooltip:FadeOut();
    else
        GameTooltip:Hide();
    end
end

local function ToggleBlackScreen(state)
    if state then
        local blackscreenLevel = Narci_FlyoutBlack:GetFrameLevel();
        Narci_FlyoutBlack:In();
        Narci_Attribute:SetFrameLevel(blackscreenLevel - 2);
    else
        Narci_FlyoutBlack:Out();
    end
end

local function TriggerButtonOnEnter()
    for _, button in pairs(SetButtons) do
        button:Disable();
        button:Enable();
    end
end

local function LockAllSetButtons()
    for _, button in pairs(SetButtons) do
        button:Disable();
    end
end

local function UnlockAllSetButtons()
    for _, button in pairs(SetButtons) do
        button:Enable();
    end
end

local function BrieflyBlockMotion()
    LockAllSetButtons();
    After(0, UnlockAllSetButtons);
end

local function NameEditor_Cancel()
    NameEditor:Hide();
    NameEditor:SetText("");
    NameEditor:ClearAllPoints();
end

local function EditButton_SetMode(self, mode, disable)
    self.mode = mode;

    local colorName, buttonText;

    if disable then
        colorName = "grey";
        self:Disable();
    else
        self:Enable();
    end

    if mode == "delete" then
        if not disable then
            colorName = "red";
        end
        buttonText = DELETE;
    elseif mode == "overwrite" then
        if not disable then
            colorName = "yellow";
        end
        buttonText = L["Equipment Overwrite"];
    elseif mode == "create" then
        if not disable then
            colorName = "green";
        end
        buttonText = BATTLETAG_CREATE;
    elseif mode == "cancel" then
        if not disable then
            colorName = "red";
        end
        buttonText = CANCEL;
    end

    self:SetButtonText(buttonText);
    self:SetColor(colorName);
end

local function EditButton_OnEnter(self)
    if not self.mode then return end;

    local tooltip;

    if NARCISSUS_MODE then
        tooltip = NarciGameTooltip;
        NarciGameTooltip:HideTooltip();
        tooltip:SetOwner(self, "ANCHOR_NONE");
        tooltip:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 8, 12);
    else
        tooltip = GameTooltip;
        tooltip:Hide();
        tooltip:SetOwner(self, "ANCHOR_NONE");
        tooltip:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 2);
    end

    if self.mode == "overwrite" then
        tooltip:SetText(L["Equipment Overwrite Items"], 1, 1, 1, true);
        if self:IsEnabled() then
            tooltip:AddLine(L["Equipment Overwrite Tooltip"], 1, 0.82, 0, true);
        else
            tooltip:AddLine(L["Equipment Overwrite Same"], 1, 0.82, 0, true);
        end
    elseif self.mode == "delete" then
        tooltip:SetText(L["Equipment Delete Set"], 1, 1, 1, true);
        tooltip:AddLine(L["Equipment Delete Tooltip"], 1, 0.82, 0, true);
    elseif self.mode == "create" then
        return
    elseif self.mode == "cancel" then
        return
    elseif self.mode == "confirm" then
        tooltip:SetText(L["Equipment Save Name"], 1, 1, 1, true);
    else
        return
    end

    tooltip:Show();
    if NARCISSUS_MODE then
        tooltip:FadeIn();
    end
end

local function EditButton_OnLeave(self)
    if NARCISSUS_MODE then
        NarciGameTooltip:HideTooltip();
    else
        GameTooltip:Hide();
    end
end


local function PlaceMouseOverFrame(equipmentSetButton, showEditButton)
    MouseOverFrame:ClearAllPoints();
    if equipmentSetButton then
        local level = equipmentSetButton:GetFrameLevel();
        MouseOverFrame:SetParent(equipmentSetButton);
        MouseOverFrame:SetPoint("TOPLEFT", equipmentSetButton, "TOPLEFT", 0, 0);
        MouseOverFrame:SetPoint("BOTTOMRIGHT", equipmentSetButton, "BOTTOMRIGHT", 0, 0);
        MouseOverFrame:SetFrameLevel(level);
        MouseOverFrame:Show();
        equipmentSetButton.Name:SetTextColor(1, 1, 1);
        if showEditButton then

        end
    else
        MouseOverFrame:Hide();
    end
    FocusedButton = equipmentSetButton;
end


local function DeleteButton_OnLongClick(setID)
    DeleteSet(setID);
    MainFrame:ExitEditMode();
    if FocusedButton then
        FocusedButton:OnLeave();
    end
end


local function CancelChanges()
    MainFrame:ExitEditMode();

    if FocusedButton then
        FocusedButton.Name:Show();
        if IconSelector:IsChanged()then
            if FocusedButton.setID then
                FocusedButton:SetSetID(FocusedButton.setID);
            else
                FocusedButton:SetNewSet();
            end
        end
        FocusedButton:OnLeave();
    end

    BrieflyBlockMotion();
end

local function ConfirmChanges()
    local name = strtrim( NameEditor:GetText() );
    if not name or name == "" then
        name = NameEditor.defaultName;
    end

    local icon = IconSelector:GetSelectedIcon();

    local existID = EDIT_TARGET;

    if existID then
        C_EquipmentSet.ModifyEquipmentSet(existID, name, icon)
    else
        local sameNameID = C_EquipmentSet.GetEquipmentSetID(name);
        if sameNameID then
            C_EquipmentSet.ModifyEquipmentSet(sameNameID, name, icon);
        else
            C_EquipmentSet.CreateEquipmentSet(name, icon);
        end
    end

    MainFrame:ExitEditMode();

    if FocusedButton then
        FocusedButton.Name:Show();
        FocusedButton:OnLeave();
    end

    MainFrame:OnEvent("EQUIPMENT_SETS_CHANGED");
    TriggerButtonOnEnter();
end

local function OverwriteButton_OnLongClick(setID)
    local icon;
    if IconSelector:IsChanged() then
        icon = IconSelector:GetSelectedIcon();
    end
    C_EquipmentSet.SaveEquipmentSet(setID, icon);
    MainFrame:ExitEditMode();
    if FocusedButton then
        FocusedButton:OnLeave();
    end
    MainFrame:OnEvent("EQUIPMENT_SETS_CHANGED");
end

local function EditEquipmentSetButton(button)
    EDIT_MODE = true;

    ToggleBlackScreen(true);
    MainFrame:SendButtonToTop(button);

    NameEditor:ClearAllPoints();
    NameEditor:SetParent(button);
    NameEditor:SetPoint("LEFT", button, "LEFT", 36, 0);
    NameEditor:Show();

    NameEditor.ConfirmButton:ClearAllPoints();
    NameEditor.ConfirmButton:SetPoint("RIGHT", button, "RIGHT", -6, 0);

    local defaultName, icon;
    local setID = button.setID;

    if setID then
        defaultName, icon = GetEquipmentSetInfo(setID);
        EditButton_SetMode(OverwriteButton, "overwrite", button.EquippedMarker:IsShown());
        EditButton_SetMode(DeleteButton, "delete");
        OverwriteButton:SetLongClick(OverwriteButton_OnLongClick, setID);
        DeleteButton:SetLongClick(DeleteButton_OnLongClick, setID);
    else
        local sets = C_EquipmentSet.GetEquipmentSetIDs() or {};
        defaultName = (L["New Set"]) .." "..(#sets + 1);
        icon = 134400;
        EditButton_SetMode(OverwriteButton, "create");
        EditButton_SetMode(DeleteButton, "cancel");
        DeleteButton:SetLongClick(nil, nil);
        OverwriteButton:SetClick(ConfirmChanges, nil);
        DeleteButton:SetClick(CancelChanges, nil);
    end

    NameEditor.defaultName = defaultName;
    NameEditor:SetText(defaultName);
    NameEditor:HighlightText();


    IconSelector:OpenAt(button, (NARCISSUS_MODE and "left") or "right", icon);
    IconSelector:SelectIcon(icon);

    if FocusedButton then
        FocusedButton.Name:Show();
    end
    button.Name:Hide();
    button.EquippedMarker:Hide();

    FocusedButton = button;

    OverwriteButton:ClearAllPoints();
    OverwriteButton:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, 0);
    OverwriteButton:Show();

    DeleteButton:ClearAllPoints();
    DeleteButton:SetPoint("BOTTOMRIGHT", button, "TOPRIGHT", 0, 0);
    DeleteButton:Show();
end




--Pre WotLK: Can't create any equipment set action button cuz EquipmentManager isn't in the game, so this is the solution.
--Also, macro "/equipset" doesn't exist so we'll have to use the API

local GetMacroIndexByName = GetMacroIndexByName;
local GetMacroInfo = GetMacroInfo;
local match = string.match;
local find = string.find;

local function CleanEquipmentSetMacros()
    --match icon/name
    --remove duplicated/nonexistent macros

    if InCombatLockdown() then return end;

    local name, icon;

    local sets = C_EquipmentSet.GetEquipmentSetIDs() or {};
    local setInfo = {};

    for _, setID in ipairs(sets) do
        name, icon = C_EquipmentSet.GetEquipmentSetInfo(setID);
        setInfo[setID] = {name, icon};
    end

    local _, perChar = GetNumMacros();
    local DeleteMacro = DeleteMacro;
    local EditMacro = EditMacro;
    local isNarcissus, body, setID;
    local setFound = {};
    local macroName;

    for macroID = 121, 121 + perChar - 1 do
        name, icon, body = GetMacroInfo(macroID);
        if body then
            isNarcissus = find(body, "%-%-narcissus");
            if isNarcissus then
                setID = match(body, "UseEquipmentSet%((%d+)%)");
                setID = tonumber(setID);
                if setID then
                    if setInfo[setID] then
                        if not setFound[setID] then
                            setFound[setID] = true;
                            macroName = "Equip "..setInfo[setID][1];
                            if (name ~= macroName) or (icon ~= setInfo[setID][2]) then
                                EditMacro(macroID, macroName, setInfo[setID][2], body);     --make Macro name/icon match the equipment set data
                            end
                        else
                            DeleteMacro(macroID);   --remove duplicated set
                        end
                    else
                        DeleteMacro(macroID);   --remove nonexistent set
                    end
                end
            end
        end
    end
end

local function GetBestMacroIDForSet(newName, newSetID)
    local _, perChar = GetNumMacros();

    local exsistMacroID = GetMacroIndexByName(newName);
    if exsistMacroID == 0 then
        exsistMacroID = nil;
    else
        return exsistMacroID
    end

    local name, icon, body;
    local setID;
    local isNarcissus;

    for macroID = 121, 121 + perChar - 1 do
        name, icon, body = GetMacroInfo(macroID);
        if body then
            isNarcissus = find(body, "%-%-narcissus");
            if isNarcissus then
                setID = match(body, "UseEquipmentSet%((%d+)%)");
                setID = tonumber(setID);
                if setID == newSetID then
                    exsistMacroID = macroID;
                    break
                end
            end
        end
    end

    return exsistMacroID
end

local function CreateAndPickupEquipmentSetMacro(setID)
    if GAME_HAS_EQUIPMENT_MANAGER then
        C_EquipmentSet.PickupEquipmentSet(setID);
        return true
    end

    if InCombatLockdown() then
        UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0, 0, 1.0, 0);
        return false, "combat"
    end

    CleanEquipmentSetMacros();

    local name, icon = C_EquipmentSet.GetEquipmentSetInfo(setID);
    name = "Equip "..name;

    local body = string.format("/script if InCombatLockdown() then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0, 0, 1.0, 0);else C_EquipmentSet.UseEquipmentSet(%d) end;--narcissus", setID);

    local macroID = GetBestMacroIDForSet(name, setID);

    if macroID then
        macroID = EditMacro(macroID, name, icon, body);
    else
        local perCharacter = true;
        macroID = CreateMacro(name, icon, body, perCharacter);
    end

    if macroID then
        PickupMacro(macroID);
        return macroID
    else
        return false    --max char specific macros: 18
    end
end



NarciEquipmentSetButtonMixin = {};

function NarciEquipmentSetButtonMixin:OnLoad()
    self:RegisterForDrag("LeftButton");
end

function NarciEquipmentSetButtonMixin:OnMouseDown()
    MouseOverFrame.Background:SetColorTexture(0.5, 0.5, 0.5);
end

function NarciEquipmentSetButtonMixin:OnMouseUp()
    MouseOverFrame.Background:SetColorTexture(0.45, 0.45, 0.45);
end

function NarciEquipmentSetButtonMixin:OnEnter()
    if EDIT_MODE then
        return
    end

    PlaceMouseOverFrame(self);
    self.Name:SetTextColor(1, 1, 1);

    if self.setID then
        OnEnterHandler:ShowSetInfo(self);
    else
        OnEnterHandler:ShowNewSet(self);
    end
end

function NarciEquipmentSetButtonMixin:OnLeave()
    if EDIT_MODE then
        return
    end

    PlaceMouseOverFrame(nil);

    if self.setID then
        self.Name:SetTextColor(0.81, 0.78, 0.62);
    else
        self.Name:SetTextColor(0.67, 0.67, 0.67);
    end

    OnEnterHandler:Stop();
    if NARCISSUS_MODE then
        NarciGameTooltip:HideTooltip();
    else
        GameTooltip:Hide();
    end
end


function NarciEquipmentSetButtonMixin:OnClick(button)
    if self.setID then
        if button == "RightButton" then
            EDIT_TARGET = self.setID;
            EditEquipmentSetButton(self);
            HideButtonTooltip();
        end
    else
        EDIT_TARGET = nil;
        EditEquipmentSetButton(self);
        HideButtonTooltip();
    end
end

function NarciEquipmentSetButtonMixin:OnDoubleClick()
    if self.setID then
        local _, _, _, isEquipped = GetEquipmentSetInfo(self.setID);
        C_EquipmentSet.UseEquipmentSet(self.setID);
        if not isEquipped then
            HideButtonTooltip();
        end
    end
end

function NarciEquipmentSetButtonMixin:SetSetID(setID)
    local name, icon, _, isEquipped, numItems, _, _, numLost = GetEquipmentSetInfo(setID);

    self.Icon:SetTexture(icon);
    self.Icon:SetTexCoord(0.075, 0.925, 0.075, 0.925);
    self.Name:SetText(name);

    if numLost == 0 then
        self.Name:SetText(name);
    else
        self.Name:SetText("|cfff05253".. name .."|r");
    end

    if FocusedButton and FocusedButton == self then
        self.Name:SetTextColor(1, 1, 1);
    else
        self.Name:SetTextColor(0.81, 0.78, 0.62);
    end

    self.EquippedMarker:SetShown(isEquipped);
    if isEquipped then
        self.EquippedMarker.AnimShow:Play();
    end

    self:Show();
    self.setID = setID;
end

function NarciEquipmentSetButtonMixin:SetNewSet()
    self.Icon:SetTexture("Interface/AddOns/Narcissus/Art/Modules/EquipmentSetManager/UI");
    self.Icon:SetTexCoord(0, 0.1875, 0.25, 0.4375);
    self.Name:SetText(L["New Set"]);
    self.Name:SetTextColor(0.67, 0.67, 0.67);
    self.EquippedMarker:Hide();
    self:Show();
    self.setID = nil;
end

function NarciEquipmentSetButtonMixin:Wipe()
    self.Icon:SetTexture(nil);
    self.Name:SetText(nil);
    self.EquippedMarker:Hide();
    self.setID = nil;
    self:Hide();

    FocusedButton = nil;
end

function NarciEquipmentSetButtonMixin:OnDragStart()
    MouseOverFrame.Background:SetColorTexture(0.4, 0.4, 0.4);

    if not self.setID then return end;

    local result, reason = CreateAndPickupEquipmentSetMacro(self.setID);
    if result then
        SetUIVisibility(true);
    end
end


local function NameEditor_OnEditFocusGained(self)
    Narci.UserIsInputing = true;
end

local function NameEditor_OnEditFocusLost(self)
    Narci.UserIsInputing = false;
end

local SmartEditBoxFont = NarciAPI_SmartEditBoxType;

local function NameEditor_OnTextChanged(self, isUserInput)
    SmartEditBoxFont(self);

    local diff = 16 - self:GetNumLetters();
    if diff > 6 then
        self.LetterCount:Hide();
    else
        self.LetterCount:Show();
        if diff > 0 then
            self.LetterCount:SetTextColor(0.5, 0.5 ,0.5);
        else
            self.LetterCount:SetTextColor(1, 0, 0);
        end
        self.LetterCount:SetText(diff);
    end
end


local function NameEditor_OnShow(self)
    self:RegisterEvent("GLOBAL_MOUSE_DOWN");
end

local function NameEditor_OnHide(self)
    self:UnregisterEvent("GLOBAL_MOUSE_DOWN");
    self.defaultName = nil;
end

local function NameEditor_OnEvent(self, event, ...)
    if not ( self:GetParent():IsMouseOver() or IconSelector:IsMouseOver() or DeleteButton:IsMouseOver() or OverwriteButton:IsMouseOver() ) then
        BrieflyBlockMotion();
        CancelChanges();
    end
end


---- Animations ----
local outQuart = addon.EasingFunctions.outQuart;
local linear = addon.EasingFunctions.linear;

local function ShowFrame_OnUpdate(self, elapsed)
    self.total = self.total + elapsed;

    local x = outQuart(self.total, -96, 0, 0.5);
    local y = outQuart(self.total, 48, 0, 0.35);
    if self.total >= 0.35 then
        y = 0;
    end

    local alpha = self.total * 4;
    if alpha > 1 then
        alpha = 1;
    end

    local ax = outQuart(self.total, 0, -96, 0.5);

    if self.total >= 0.5 then
       self:SetScript("OnUpdate", nil);
       x = 0;
       y = 0;
       ax = -96;
    end

    MainFrame:SetAlpha(alpha);
    MainFrame:SetPoint("TOPLEFT", MainFrame.defaultAnchor, "BOTTOM", x + 48, y - 24);
    MainFrame.attributeButton:SetPoint("TOP", MainFrame.defaultAnchor, "BOTTOM", ax, -24);
end

local function HideFrame_OnUpdate(self, elapsed)
    self.total = self.total + elapsed;

    local alpha = 1 - self.total * 8;
    if alpha < 0 then
        alpha = 0;
    elseif alpha < 0.1 then
        MainFrame:Hide();
    end

    local x = outQuart(self.total, -96, 0, 0.5);

    if self.total >= 0.5 then
       self:SetScript("OnUpdate", nil);
       self:Hide();
       x = 0;
    end

    MainFrame:SetAlpha(alpha);
    MainFrame.attributeButton:SetPoint("TOP", MainFrame.defaultAnchor, "BOTTOM", x, -24);
end



local function ConfirmNameButton_OnEnter(self)
    EditButton_OnEnter(self);
    self.Background:SetColorTexture(0.35, 0.35, 0.35);
end

local function ConfirmNameButton_OnLeave(self)
    EditButton_OnLeave(self);
    self.Background:SetColorTexture(0.25, 0.25, 0.25);
end


NarciEquipmentSetManagerMixin = {};

function NarciEquipmentSetManagerMixin:OnLoad()
    MainFrame = self;
    MouseOverFrame = self.MouseOverFrame;
    IconSelector = self.IconSelector;
    NameEditor = self.NameEditor;

    NameEditor:SetHighlightColor(0, 0, 0);
    NameEditor:SetTextInsets(0, 12, 0, 0);
    NameEditor.fontHeight = 12;

    NameEditor:SetScript("OnEscapePressed", CancelChanges);
    NameEditor:SetScript("OnEnterPressed", ConfirmChanges);
    NameEditor:SetScript("OnEditFocusGained", NameEditor_OnEditFocusGained);
    NameEditor:SetScript("OnEditFocusLost", NameEditor_OnEditFocusLost);
    NameEditor:SetScript("OnTextChanged", NameEditor_OnTextChanged);
    NameEditor:SetScript("OnShow", NameEditor_OnShow);
    NameEditor:SetScript("OnHide", NameEditor_OnHide);
    NameEditor:SetScript("OnEvent", NameEditor_OnEvent);

    OverwriteButton = self.OverwriteButton;
    OverwriteButton:SetButtonText(L["Equipment Overwrite"]);
    OverwriteButton:SetColor("yellow");
    OverwriteButton.onEnterFunc = EditButton_OnEnter;
    OverwriteButton.onLeaveFunc = EditButton_OnLeave;

    DeleteButton = self.DeleteButton;
    DeleteButton:SetButtonText(DELETE);
    DeleteButton:SetColor("red");
    DeleteButton.onEnterFunc = EditButton_OnEnter;
    DeleteButton.onLeaveFunc = EditButton_OnLeave;

    NameEditor.ConfirmButton.mode = "confirm";
    NameEditor.ConfirmButton:SetScript("OnClick", ConfirmChanges);
    NameEditor.ConfirmButton:SetScript("OnEnter", ConfirmNameButton_OnEnter);
    NameEditor.ConfirmButton:SetScript("OnLeave", ConfirmNameButton_OnLeave);


    self:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player");
    self:RegisterEvent("PLAYER_ENTERING_WORLD");

    --The following events don't fire in Vanilla&BC
    self:RegisterEvent("EQUIPMENT_SETS_CHANGED");
    self:RegisterEvent("EQUIPMENT_SWAP_FINISHED");
    self:RegisterEvent("EQUIPMENT_SWAP_PENDING");
    --self:RegisterEvent("WEAR_EQUIPMENT_SET");     --*Event removed

    self.requiresUpdate = true;
end

function NarciEquipmentSetManagerMixin:OnShow()
    self.isActive = true;
    self:SendButtonToTop();
    if self.requiresUpdate then
        self:Update();
    end
end

function NarciEquipmentSetManagerMixin:OnHide()
    self.isActive = nil;
    self:SetScript("OnUpdate", nil);
    self:Hide();

    OnEnterHandler:Stop();
    IconSelector:UnloadIcons();

    if EDIT_MODE then
        CancelChanges();
    end
end

function NarciEquipmentSetManagerMixin:OnMouseWheel(delta)
    --Do nothing
    --Prevent zooming in/out
end

function NarciEquipmentSetManagerMixin:SetParentMode(frameName)
    OnEnterHandler:Stop();
    GameTooltip:Hide();
    NarciGameTooltip:HideTooltip();
    self:SetScript("OnUpdate", nil);

    if frameName == "narcissus" and NARCISSUS_MODE ~= true then
        NARCISSUS_MODE = true;
        self:Hide();
        self:SetParent(Narci_Attribute);
        if self.openedInNarcissus then
            self:ClearAllPoints();
            if not self.defaultAnchor then
                self.defaultAnchor = Narci_ItemLevelFrame;
                self.attributeButton = Narci.AttributeController.buttons[1];
            end
            self:SetPoint("TOPLEFT", self.defaultAnchor, "BOTTOM", 48, - 24);
            self:Show();
        else
            self:Hide();
        end
        self:SetHeight(384);

    elseif frameName == "blizzard" and NARCISSUS_MODE ~= false then
        --TO-DO: Switch to game font
        NARCISSUS_MODE = false;

        local offsetX;
        local relativeTo;
        if GAME_HAS_EQUIPMENT_MANAGER then
            relativeTo = PaperDollItemsFrame or PaperDollFrame;
            offsetX = 0;
        else
            offsetX = -30;
            relativeTo = PaperDollFrame;
        end
        self:SetParent(PaperDollFrame);
        self:ClearAllPoints();
        self:SetPoint("TOPLEFT", relativeTo, "TOPRIGHT", offsetX, -52);
        self:Show();
    end

    self:SetFrameStrata("HIGH");

    if self:IsShown() then
        self:Update();
    else
        self.requiresUpdate = true;
    end
end

function NarciEquipmentSetManagerMixin:IsNarcissusMode()
    return NARCISSUS_MODE
end

local function OnInventoryChanged(self)
    self:SetScript("OnUpdate", nil);
    self:Update();
end

function NarciEquipmentSetManagerMixin:OnEvent(event, ...)
    if self.isActive then
        if event == "UNIT_INVENTORY_CHANGED" then
            self:SetScript("OnUpdate", OnInventoryChanged);
        elseif event == "EQUIPMENT_SWAP_FINISHED" then
            local result, setID = ...
        elseif event == "EQUIPMENT_SETS_CHANGED" then
            self:SetScript("OnUpdate", OnInventoryChanged);
            After(1, CleanEquipmentSetMacros);
        end
    else
        self.requiresUpdate = true;
    end

    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent(event);
        CleanEquipmentSetMacros();
    end

    --print(event, ...)
end

function NarciEquipmentSetManagerMixin:Update()
    local sets = C_EquipmentSet.GetEquipmentSetIDs() or {};
    local button;
    local _, name, icon, setID, isEquipped, numItems, numLost;

    local numSets = #sets;
    local newSetIndex = numSets + 1;
    local numButtons = math.min(newSetIndex, MAX_SETS);

    for i = 1, numButtons do
        setID = sets[i];
        button = SetButtons[i];
        if not button then
            SetButtons[i] = CreateFrame("Button", nil, self, "NarciEquipmentSetButtonTemplate");
            button = SetButtons[i];
            button:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -24 - (i - 1) * 36);

            button.Background:SetColorTexture(1, 1, 1, 1);
            if i % 2 == 1 then
                SetGradientTexture(button.Background, "HORIZONTAL", 0.1, 0.1, 0.1, 0.18, 0.18, 0.18);
            else
                SetGradientTexture(button.Background, "HORIZONTAL", 0.18, 0.18, 0.18, 0.18, 0.18, 0.18);
            end
        end

        if i == newSetIndex then
            button:SetNewSet();
        else
            button:SetSetID(setID);
        end

        button:Disable();
        button:Enable();
        button.Name:Show();
    end

    for i = newSetIndex + 1, MAX_SETS do
        if SetButtons[i] then
            SetButtons[i]:Wipe();
        end
    end

    self.requiresUpdate = nil;

    if not NARCISSUS_MODE then
        self:SetHeight(24 + 36*numButtons);
    end

    if NARCISSUS_MODE then
        self:OnUpdateComplete();
    end
end

local AnimationFrame;

function NarciEquipmentSetManagerMixin:ShowUI()
    if not self.defaultAnchor then
        self.defaultAnchor = Narci_ItemLevelFrame;
        self.attributeButton = Narci.AttributeController.buttons[1];
    end

    self.openedInNarcissus = true;
    self:ClearAllPoints();
    self:Show();

    if not AnimationFrame then
        AnimationFrame = CreateFrame("Frame");
    end
    AnimationFrame.total = 0;
    AnimationFrame:SetScript("OnUpdate", ShowFrame_OnUpdate);
    AnimationFrame:Show();
end

function NarciEquipmentSetManagerMixin:HideUI()
    --self:Hide();
    self.openedInNarcissus = nil;

    if not self.defaultAnchor then
        self.defaultAnchor = Narci_ItemLevelFrame;
        self.attributeButton = Narci.AttributeController.buttons[1];
    end
    self:ClearAllPoints();

    if not AnimationFrame then
        AnimationFrame = CreateFrame("Frame");
    end
    AnimationFrame.total = 0;
    AnimationFrame:SetScript("OnUpdate", HideFrame_OnUpdate);
    AnimationFrame:Show();

    if EDIT_MODE then
        CancelChanges();
    end
end

function NarciEquipmentSetManagerMixin:SendButtonToTop(topButton)
    local level = self:GetFrameLevel();
    if topButton then
        local low = level - 2;
        for _, button in pairs(SetButtons) do
            if button == topButton then
                button:SetFrameLevel(level + 2);
            else
                button:SetFrameLevel(low);
            end
        end
    else
        level = level + 2;
        for _, button in pairs(SetButtons) do
            button:SetFrameLevel(level);
        end
    end
end

function NarciEquipmentSetManagerMixin:GetSetButtons()
    local buttons = {};
    local n = 0;
    for _, button in ipairs(SetButtons) do
        if button:IsShown() then
            n = n + 1;
            buttons[n] = button;
        end
    end
    return buttons
end

function NarciEquipmentSetManagerMixin:CancelChanges()
    CancelChanges();
end

function NarciEquipmentSetManagerMixin:ConfirmChanges()
    ConfirmChanges();
end

function NarciEquipmentSetManagerMixin:ExitEditMode()
    EDIT_MODE = nil;
    NameEditor_Cancel();
    IconSelector:Close();
    ToggleBlackScreen(false);
    MainFrame:SendButtonToTop();
    OverwriteButton:Hide();
    DeleteButton:Hide();
end

function NarciEquipmentSetManagerMixin:OnUpdateComplete()

end




---- Add a toggle to PaperDollFrame (above HandsSlot) ----
local EquipmentMangerToggle;


NarciEquipmentManagerToggleMixin = {};

function NarciEquipmentManagerToggleMixin:OnLoad()
    EquipmentMangerToggle = self;
end

function NarciEquipmentManagerToggleMixin:OnEnter()
    GameTooltip:Hide();
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
    GameTooltip:SetText(PAPERDOLL_EQUIPMENTMANAGER, 1, 1, 1, true);
    GameTooltip:Show();
    self:UpdateTexture();
end

function NarciEquipmentManagerToggleMixin:OnLeave()
    GameTooltip:Hide();
    self:UpdateTexture();
end

function NarciEquipmentManagerToggleMixin:OnMouseDown()
    self.down = true;
    self:UpdateTexture();
end

function NarciEquipmentManagerToggleMixin:OnMouseUp()
    self.down = nil;
    self:UpdateTexture();
end

function NarciEquipmentManagerToggleMixin:OnClick()
    local visible = not MainFrame:IsShown();
    if visible then
        MainFrame:SetParentMode("blizzard");
        MainFrame:SetAlpha(1);
        MainFrame:Show();
    else
        MainFrame:Hide();
    end
    GameTooltip:Hide();
end

function NarciEquipmentManagerToggleMixin:OnShow()
    self:UpdatePosition();
end

function NarciEquipmentManagerToggleMixin:UpdateTexture()
    if self:IsMouseOver() then
        if self.down then
            self.Texture:SetTexCoord(0.5, 1, 0.5, 1);
        else
            self.Texture:SetTexCoord(0.5, 1, 0, 0.5);
        end
    else
        if self.down then
            self.Texture:SetTexCoord(0, 0.5, 0.5, 1);
        else
            self.Texture:SetTexCoord(0, 0.5, 0, 0.5);
        end
    end
end

function NarciEquipmentManagerToggleMixin:UpdatePosition()
    local runeButton = RuneFrameControlButton;
    local isSoD = runeButton and runeButton:IsShown();

    if isSoD ~= self.isSoD then
        self.isSoD = isSoD;
    else
        return
    end

    self:ClearAllPoints();
    if isSoD then
        self:SetPoint("BOTTOMRIGHT", runeButton, "BOTTOMLEFT", -10, 0);
    else
        self:SetPoint("BOTTOM", CharacterHandsSlot, "TOP", 0, 4);
    end
end

local function SetUsePaperDollEquipmentManager(state)
    --C_CVar.GetCVarBool("equipmentManager") can returns true in Era despite not supporting EquipmentSet officially

    if (state or state == nil) and ((not GAME_HAS_EQUIPMENT_MANAGER) or (not C_CVar.GetCVarBool("equipmentManager"))) then
        EquipmentMangerToggle:Show();
    else
        EquipmentMangerToggle:Hide();
        if (not NARCISSUS_MODE) and MainFrame:IsShown() then
            MainFrame:Hide();
        end
    end
end

NarciAPI.SetUsePaperDollEquipmentManager = SetUsePaperDollEquipmentManager;


do
    local blizzardSetToggle = _G["GearManagerToggleButton"];
    if blizzardSetToggle then
        hooksecurefunc(blizzardSetToggle, "Show", function()
            EquipmentMangerToggle:Hide();
        end);
        hooksecurefunc(blizzardSetToggle, "Hide", function()
            if NarcissusDB and NarcissusDB.EquipmentSetManager then
                EquipmentMangerToggle:Show();
            end
        end);
    end

    local SettingFunctions = addon.SettingFunctions;

	function SettingFunctions.SetUsePaperDollEquipmentManager(state, db)
		if state == nil then
			state = db["EquipmentSetManager"];
		end

        SetUsePaperDollEquipmentManager(state);
	end
end
