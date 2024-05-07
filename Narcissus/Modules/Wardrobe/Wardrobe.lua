-- Cata Classic
---- Transmogrifier: Save/Load Outfits

local _, addon = ...
local TransmogDataProvider = addon.TransmogDataProvider;
local ProfileAPI = addon.ProfileAPI;
local L = Narci.L;

local Mixin = Mixin;
local CreateFrame = CreateFrame;
local InCombatLockdown = InCombatLockdown;

local MainFrame = CreateFrame("Frame", nil, UIParent);
local DropDownMenu, SaveButton, PreviewModel, EditButton, StaticPopup;

local MAX_SAVES = 20;
local MENUBUTTON_HIGHT = 20;

local DropDownToggleMixin = {};

local function GetOutfitName(outfitID)
    local info = ProfileAPI:GetClassicOutfitInfo(outfitID);
    if info then
        return info.n
    end
end

do
    function DropDownToggleMixin:SetText(text, r, g, b)
        self.Text:SetText(text);
        if r then
            self.Text:SetTextColor(r, g, b);
        end
    end

    function DropDownToggleMixin:LoadSelection()
        local outfitID = ProfileAPI:GetLastAppliedOutfitID();
        if outfitID then
            self:SetText(GetOutfitName(outfitID), 1, 1, 1);
        else
            self:SetText(L["Select Outfit"], 0.5, 0.5, 0.5);
        end
    end

    function DropDownToggleMixin:OnLoad()
        self:SetScript("OnEnter", self.OnEnter);
        self:SetScript("OnLeave", self.OnLeave);
        self:SetScript("OnMouseDown", self.OnMouseDown);
        self:SetScript("OnMouseUp", self.OnMouseUp);
        self:SetScript("OnClick", self.OnClick);
    end

    function DropDownToggleMixin:SetButtonState(state)
        self.ButtonTexture:SetTexture("Interface/ChatFrame/UI-ChatIcon-ScrollDown-"..state);
    end

    function DropDownToggleMixin:OnMouseDown()
        self:SetButtonState("Down");
    end

    function DropDownToggleMixin:OnMouseUp()
        self:SetButtonState("Up");
    end

    function DropDownToggleMixin:OnDisable()
        self:SetButtonState("Disabled")
    end

    function DropDownToggleMixin:OnClick()
        DropDownMenu:Toggle();
    end
end


local function SaveCurrentOutfit(name, icon)
    name = name or "Unnamed Outfit";

    if ProfileAPI:GetNumSavedClassicOutfits() >= MAX_SAVES then return end;

    local list, string = TransmogDataProvider:GetPendingClassicOutfit();
    if list and string then
        if not icon then
            for slotID = 1, 20 do
                if list[slotID] and list[slotID] ~= 0 then
                    icon = select(4, C_TransmogCollection.GetAppearanceSourceInfo(list[slotID]));
                    break
                end
            end
        end

        local result = ProfileAPI:SaveClassicOutfit(name, icon, list);

        if result then
            local newOutfitID = ProfileAPI:GetNumSavedClassicOutfits();
            ProfileAPI:SetLastAppliedOutfitID(newOutfitID);
            MainFrame:UpdateAll();
        end

        return result
    end
end


local CreateMenuButton;
do
    local OFFSET_X = 12;

    local MenuButtonMixin = {};

    function MenuButtonMixin:OnLoad()
        self:SetScript("OnEnter", self.OnEnter);
        self:SetScript("OnLeave", self.OnLeave);
        self:SetScript("OnClick", self.OnClick);
        self:SetScript("OnMouseDown", self.OnMouseDown);
        self:SetScript("OnMouseUp", self.OnMouseUp);
        self.Ref = self.Text;
    end

    function MenuButtonMixin:OnEnter()
        DropDownMenu:HighlightButton(self);

        if self.info then
            PreviewModel:DisplayOutfit(self.outfitID, self);
        else
            PreviewModel:Hide();
        end
    end

    function MenuButtonMixin:OnLeave()
        if self:IsMouseOver() then return end;

        DropDownMenu:HighlightButton(nil);
        PreviewModel:Hide();
    end

    function MenuButtonMixin:OnClick()
        DropDownMenu:Hide();

        if self.info and self.info.s then
            local result = TransmogDataProvider:ApplyClassicOutfitString(self.info.s);
            if result then
                ProfileAPI:SetLastAppliedOutfitID(self.outfitID);
                MainFrame:UpdateAll();
            end
        end
    end

    function MenuButtonMixin:OnClick_NewOutfit()
        MainFrame:ShowDialog("NEW_OUTFIT");
    end

    function MenuButtonMixin:OnMouseDown()
        self.Ref:SetPoint("LEFT", self, "LEFT", OFFSET_X + 1, -1);
    end

    function MenuButtonMixin:OnMouseUp()
        self.Ref:SetPoint("LEFT", self, "LEFT", OFFSET_X, 0);
    end

    function MenuButtonMixin:SetIcon(icon)
        if icon then
            if not self.Icon then
                self.Icon = self:CreateTexture(nil, "OVERLAY");
                self.Icon:SetSize(12, 12);
                self.Icon:SetPoint("LEFT", self, "LEFT", OFFSET_X, 0);
            end
            self.Icon:SetTexture(icon);
            self.Text:ClearAllPoints();
            self.Text:SetPoint("LEFT", self.Icon, "RIGHT", 4, 0);
            self.Ref = self.Icon;
        else
            if self.Icon then
                self.Icon:Hide();
                self.Text:ClearAllPoints();
                self.Text:SetPoint("LEFT", self, "LEFT", OFFSET_X, 0);
            end
            self.Ref = self.Text;
        end
    end

    function MenuButtonMixin:SetText(text, r, g, b)
        self.Text:SetText(text);
        if r then
            self.Text:SetTextColor(r, g, b);
        end
    end

    function MenuButtonMixin:SetOutfit(outfitID)
        self.outfitID = outfitID;

        local info = ProfileAPI:GetClassicOutfitInfo(outfitID);
        local name = info.n or "Unnamed Outfit";
        local icon = info.i or 134400;

        self.info = info;

        self:SetText(name, 1, 0.82, 0);
        self:SetIcon(icon);
        --self.Icon:SetTexCoord(0.075, 0.925, 0.075, 0.925);
    end

    function CreateMenuButton(parent)
        local f = CreateFrame("Button", nil, parent);
        f:Hide();
        Mixin(f, MenuButtonMixin);

        local Text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
        f.Text = Text;
        Text:SetJustifyH("LEFT");
        Text:SetJustifyV("MIDDLE");
        Text:SetMaxLines(1);
        Text:SetPoint("LEFT", f, "LEFT", OFFSET_X, 0);

        f:SetSize(100, MENUBUTTON_HIGHT);
        f:OnLoad();

        return f
    end
end


local DropDownMenuMixin = {};
do
    local MENU_PADDING_V = 10;
    local MIN_MENU_WIDTH = 180;
    local MAX_MENU_WIDTH = 296;

    function DropDownMenuMixin:OnLoad()
        self.isDirty = true;

        self:SetScript("OnShow", self.OnShow);
        self:SetScript("OnHide", self.OnHide);
        self:SetScript("OnEvent", self.OnEvent);
        self:SetSize(180, 180);

        if not self.NewOutfitButton then
            self.buttons = {};
            local NewOutfitButton = CreateMenuButton(self);
            self.NewOutfitButton = NewOutfitButton;
            NewOutfitButton:SetIcon("Interface/PaperDollInfoFrame/Character-Plus");
            NewOutfitButton:SetText(TRANSMOG_OUTFIT_NEW, 0.098, 1.000, 0.098);    --GREEN_FONT_COLOR
            NewOutfitButton:SetScript("OnClick", NewOutfitButton.OnClick_NewOutfit);
        end
    end

    function DropDownMenuMixin:RequestUpdate()
        if self:IsShown() then
            self:Update();
        else
            self.isDirty = true;
        end
    end

    function DropDownMenuMixin:Layout()

    end

    function DropDownMenuMixin:OnShow()
        self:RegisterEvent("GLOBAL_MOUSE_DOWN");
        if self.isDirty then
            self:Update();
        end
    end

    function DropDownMenuMixin:OnHide()
        self:Hide();
        self:HighlightButton(nil);
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN");
    end

    function DropDownMenuMixin:Toggle()
        self:SetShown(not self:IsShown());
    end

    function DropDownMenuMixin:HighlightButton(object)
        self.Highlight:Hide();
        self.Highlight:ClearAllPoints();

        if object then
            self.Highlight:SetPoint("TOPLEFT", object, "TOPLEFT", 0, 0);
            self.Highlight:SetPoint("BOTTOMRIGHT", object, "BOTTOMRIGHT", 0, 0);
            self.Highlight:Show();

            if object.outfitID then
                EditButton:SetParentButton(object);
            else
                EditButton:Hide();
            end
            MainFrame.highlightedOutfitID = object.outfitID;
        else
            MainFrame.highlightedOutfitID = nil;
            EditButton:Hide();
        end
    end

    function DropDownMenuMixin:ReleaseButtons()
        self.numButtons = 0;

        for _, button in pairs(self.buttons) do
            button:Hide();
        end
    end

    function DropDownMenuMixin:AcquireButton()
        local n = self.numButtons + 1;
        self.numButtons = n;

        local button = self.buttons[n];
        if not button then
            button = CreateMenuButton(self);
            self.buttons[n] = button;
            button:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -MENU_PADDING_V + (1 - n) * MENUBUTTON_HIGHT);
        end

        button:Show();

        return button
    end

    function DropDownMenuMixin:Update()
        self.isDirty = nil;

        self:ReleaseButtons();

        local numOutfits = ProfileAPI:GetNumSavedClassicOutfits();
        local lastAppliedOutfitID = ProfileAPI:GetLastAppliedOutfitID();

        local maxTextWidth = 0;
        local button;

        self:SetChecked(nil);

        for i = 1, numOutfits do
            button = self:AcquireButton();
            button:SetOutfit(i);
            button:OnMouseUp();

            if i == lastAppliedOutfitID then
                self:SetChecked(button);
            end
        end

        local canSaveMoreOutfit = true;
        local NewOutfitButton = self.NewOutfitButton;
        NewOutfitButton:SetShown(canSaveMoreOutfit);
        NewOutfitButton:ClearAllPoints();
        if button then
            NewOutfitButton:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, 0);
        else
            NewOutfitButton:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -MENU_PADDING_V);
        end

        local numButtons = numOutfits;

        if canSaveMoreOutfit then
            numButtons = numOutfits + 1;
        end

        local buttonWidth = MAX_MENU_WIDTH;

        for _, b in pairs(self.buttons) do
            b:SetWidth(buttonWidth);
        end
        self.NewOutfitButton:SetWidth(buttonWidth);

        self:SetWidth(buttonWidth);
        self:SetHeight(numButtons * MENUBUTTON_HIGHT + 2 * MENU_PADDING_V);
        --self:SetWidth();
    end

    function DropDownMenuMixin:OnEvent(event, ...)
        if event == "GLOBAL_MOUSE_DOWN" then
            if not (MainFrame.OutfitButton:IsMouseOver() or self:IsMouseOver(8, 0, 0, 0)) then
                self:Hide();
            end
        else

        end
    end

    function DropDownMenuMixin:SetChecked(menuButton)
        self.CheckIcon:Hide();
        if menuButton then
            self.CheckIcon:ClearAllPoints();
            self.CheckIcon:SetPoint("LEFT", menuButton.Text, "RIGHT", 4, 0);
            self.CheckIcon:Show();
        end
    end
end


local SaveButtonMixin = {};
do
    function SaveButtonMixin:OnClick()
        local outfitID = ProfileAPI:GetLastAppliedOutfitID();
        if outfitID then
            
        else
            MainFrame:ShowDialog("NEW_OUTFIT");
        end
    end

    function SaveButtonMixin:SetMode(mode)
        if mode == self.mode then return end;
        self.mode = mode;

        if mode == 1 then   --Save
            self:Enable();
            self:SetText(SAVE);
        elseif mode == 2 then   --Overwrite
            self:Enable();
            self:SetText(SAVE_CHANGES or SAVE);
        elseif mode == 3 then   --Disabled (Saved)
            self:Disable();
            self:SetText(L["Outfit Saved"]);
        elseif mode == 4 then
            self:Disable();
            self:SetText(SAVE);
        end
    end

    function SaveButtonMixin:Update()
        local list, string = TransmogDataProvider:GetPendingClassicOutfit();

        if string then
            local isUnique, duplicateOutfitID = ProfileAPI:IsUniqueTransmogString(string);
            if isUnique then
                local outfitID = ProfileAPI:GetLastAppliedOutfitID();
                if outfitID then
                    self:SetMode(2);
                else
                    self:SetMode(1);
                end
            else
                self:SetMode(3);
            end
        else
            self:SetMode(4);
        end
    end

    function SaveButtonMixin:OnUpdate(elapsed)
        self.t = self.t + elapsed;
        if self.t > 0.034 then
            self.t = nil;
            self:SetScript("OnUpdate", nil);
            self:Update();
        end
    end

    function SaveButtonMixin:RequestUpdate()
        self.t = 0;
        self:SetScript("OnUpdate", self.OnUpdate);
    end
end


local function ApplyOutfitToModel(outfitID, model)
    if not outfitID then return end;

    local info = ProfileAPI:GetClassicOutfitInfo(outfitID);
    if info then
        local list = TransmogDataProvider:ConvertClassicTransmogStringToList(info.s);
        if list then
            for slotID, sourceID in pairs(list) do
                model:TryOn(sourceID);
            end

            return true
        end
    end
end

local CreatePreviewModel;
do
    local PreviewModelMixin = {};

    function PreviewModelMixin:OnUpdate(elapsed)
        self.t = self.t + elapsed;
        if self.t >= 0 and self.outfitID and not self.dressed then
            self.dressed = true;
            local success = ApplyOutfitToModel(self.outfitID, self);
            self:SetSheathed(true)
            if not success then
                self:Hide();
            end
        end
        if self.t > 0.25 then
            self:SetModelAlpha(1);
            self:SetScript("OnUpdate", nil);
        elseif self.t > 0.05 then
            self:SetModelAlpha(self.t * 4);
        end
    end

    function PreviewModelMixin:OnHide()
        self:Hide();
        self:SetScript("OnUpdate", nil);
        self.outfitID = nil;
        self.t = nil;
    end

    function PreviewModelMixin:DisplayOutfit(outfitID, anchorTo)
        if outfitID == self.outfitID then
            return
        end
        self.outfitID = outfitID;
        self:SetUnit("player");

        self:ClearAllPoints();
        self:SetPoint("BOTTOMRIGHT", anchorTo, "BOTTOMRIGHT", -12, 1);
        self.t = -0.2;
        self.dressed = nil;
        self:Show();
        self:SetScript("OnUpdate", self.OnUpdate);
        self:Undress();
        self:SetModelAlpha(0);

        --local detailsCameraID, transmogCameraID = C_TransmogSets.GetCameraIDs();
        --Model_ApplyUICamera(self, transmogCameraID);
    end

    function PreviewModelMixin:OnModelLoaded()
        self:SetCamera(0);
        self:SetPortraitZoom(1);
        self:SetPortraitZoom(0.5);
    end

    function CreatePreviewModel(parent)
        local m = CreateFrame("DressUpModel", nil, parent);
        m:Hide();
        Mixin(m, PreviewModelMixin);
        m:SetSize(129, 186);
        m:SetAutoDress(false);
        m:SetUnit("player");
        m:FreezeAnimation(0, 0, 0);

        local vector3D = CreateVector3D(0, 0, 0);
        vector3D:SetXYZ(0, 0, -0.25);
        local position = m:TransformCameraSpaceToModelSpace(vector3D);
        local x, y, z = position:GetXYZ();
        m:SetPosition(x, y, z);

        m:SetViewTranslation(0, -57);
        NarciClassicAPI.SetModelLight(m, true, false, -1, 1, -1, 0.8, 1, 1, 1, 0.5, 1, 1, 1);

        m:SetScript("OnHide", m.OnHide);
        m:SetScript("OnModelLoaded", m.OnModelLoaded);

        return m
    end
end

local CreateEditButton;
do
    local EDITBUTTON_WIDTH = 40;
    local EDITBUTTON_HEIGHT = MENUBUTTON_HIGHT;
    local Tooltip;

    local EditButtonMixin = {};

    function EditButtonMixin:OnEnter()
        self.Icon:SetAlpha(1);

        Tooltip:SetOwner(self, "ANCHOR_RIGHT");
        Tooltip:SetText(TRANSMOG_OUTFIT_EDIT);
        Tooltip:Show();
    end

    function EditButtonMixin:OnLeave()
        self.Icon:SetAlpha(0.5);
        Tooltip:Hide();

        if self.parentButton and (not self.parentButton:IsMouseOver()) then
            self.parentButton:OnLeave();
        end
    end

    function EditButtonMixin:OnClick()
        MainFrame:ShowDialog("EDIT_OUTFIT");
    end

    function EditButtonMixin:SetParentButton(menuButton)
        self.parentButton = menuButton;

        if not (menuButton and menuButton.outfitID) then
            self:Hide();
        else
            self:ClearAllPoints();
            self:SetPoint("RIGHT", menuButton, "RIGHT", 0, 0);
            self:SetParent(menuButton);
            self:Show();
        end
    end

    function CreateEditButton(parent)
        Tooltip = GameTooltip;

        local f = CreateFrame("Button", nil, parent);
        f:Hide();
        f:SetSize(EDITBUTTON_WIDTH, EDITBUTTON_HEIGHT);
        Mixin(f, EditButtonMixin);

        f.Icon = f:CreateTexture(nil, "OVERLAY");
        f.Icon:SetPoint("CENTER", f, "CENTER", 0, 0);
        f.Icon:SetSize(16, 16);
        f.Icon:SetTexture("Interface/WorldMap/GEAR_64GREY");
        f.Icon:SetAlpha(0.5);

        f:SetScript("OnEnter", f.OnEnter);
        f:SetScript("OnLeave", f.OnLeave);
        f:SetScript("OnClick", f.OnClick);

        return f
    end
end


local function CreateDropDownToggle(parent)
    local f = CreateFrame("Button", nil, parent);
    Mixin(f, DropDownToggleMixin);
    f:SetSize(93, 24);

    local bgData = {
        Left = {0, 0.1953125, 0, 1},
        Middle = {0.1953125, 0.8046875, 0, 1},
        Right = {0.8046875, 1, 0, 1},
    };
    local bgFile = "Interface/Glues/CharacterCreate/CharacterCreate-LabelFrame";

    for k, v in pairs(bgData) do
        local texture = f:CreateTexture(nil, "BORDER");
        f[k] = texture;
        texture:SetTexture(bgFile, (k == "Middle" and "REPEAT") or nil);
        texture:SetTexCoord(v[1], v[2], v[3], v[4]);
        texture:ClearAllPoints();
    end

    f.Left:SetSize(25, 64);
    f.Right:SetSize(25, 64);

    f.Left:SetPoint("LEFT", f, "LEFT", -15, -1);
    f.Right:SetPoint("RIGHT", f, "RIGHT", 15, -1);
    f.Middle:SetPoint("TOPLEFT", f.Left, "TOPRIGHT", 0, 0);
    f.Middle:SetPoint("BOTTOMRIGHT", f.Right, "BOTTOMLEFT", 0, 0);

    local Text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
    Text:SetJustifyH("LEFT");
    Text:SetJustifyV("MIDDLE");
    Text:SetMaxLines(1);
    Text:SetPoint("LEFT", f, "LEFT", 12, 0);
    Text:SetPoint("RIGHT", f, "RIGHT", -36, 0);
    f.Text = Text;

    local ButtonTexture = f:CreateTexture(nil, "OVERLAY");
    f.ButtonTexture = ButtonTexture;
    ButtonTexture:SetSize(24, 24);
    ButtonTexture:SetPoint("CENTER", f, "RIGHT", -14, 0);

    local ButtonHighlight = f:CreateTexture(nil, "HIGHLIGHT");
    ButtonHighlight:SetPoint("TOPLEFT", ButtonTexture, "TOPLEFT", 0, 0);
    ButtonHighlight:SetPoint("BOTTOMRIGHT", ButtonTexture, "BOTTOMRIGHT", 0, 0);
    ButtonHighlight:SetTexture("Interface/Buttons/UI-Common-MouseHilight");
    ButtonHighlight:SetBlendMode("ADD");

    f:SetButtonState("Up");
    f:OnLoad();

    return f
end

local function CreateNineSliceBackground(f)
    local offset;

    if not f.NineSlice then
        f.NineSlice = CreateFrame("Frame", nil, f);
    end

    offset = -5;
    f.NineSlice:ClearAllPoints();
    f.NineSlice:SetPoint("TOPLEFT", f, "TOPLEFT", offset, -offset);
    f.NineSlice:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -offset, offset);

    NineSliceUtil.ApplyLayoutByName(f.NineSlice, "Dialog");

    if not f.Background then
        f.Background = f:CreateTexture(nil, "BACKGROUND");
    end

    offset = 6;
    f.Background:SetColorTexture(0, 0, 0, 0.9);
    f.Background:ClearAllPoints();
    f.Background:SetPoint("TOPLEFT", f, "TOPLEFT", offset, -offset);
    f.Background:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -offset, offset);
end

local function CreateDropDownMenu(parent)
    local f = CreateFrame("Frame", nil, parent);
    Mixin(f, DropDownMenuMixin);
    f:Hide();

    CreateNineSliceBackground(f);

    local Highlight = f:CreateTexture(nil, "ARTWORK");
    f.Highlight = Highlight;
    Highlight:SetTexture("Interface/QuestFrame/UI-QuestTitleHighlight");
    Highlight:SetBlendMode("ADD");
    Highlight:SetDesaturated(true);
    Highlight:SetVertexColor(0.6, 0.6, 0.6);
    Highlight:Hide();

    local CheckIcon = f:CreateTexture(nil, "OVERLAY");
    f.CheckIcon = CheckIcon;
    CheckIcon:Hide();
    CheckIcon:SetTexture("Interface/Buttons/UI-CheckBox-Check");
    CheckIcon:SetSize(14, 14);

    f:OnLoad();
    f:EnableMouse(true);

    return f
end


function MainFrame:Init()
    self.Init = nil;

    local parent = WardrobeTransmogFrame;

    if not (parent and parent.Model) then
        return
    end

    self.ModelFrame = parent.Model;

    self:SetParent(parent);
    self:SetFrameStrata("HIGH");

    local fullWidth = math.floor(parent.Model:GetWidth());
    local redButtonWidth = fullWidth * 0.33;
    local outfitButtonWidth = fullWidth - redButtonWidth;

    local OutfitButton = CreateDropDownToggle(self);
    MainFrame.OutfitButton = OutfitButton;
    OutfitButton:SetWidth(outfitButtonWidth);
    OutfitButton:SetPoint("BOTTOMLEFT", parent.Model, "TOPLEFT", 0, 8);

    DropDownMenu = CreateDropDownMenu(self);
    DropDownMenu:SetWidth(160);
    DropDownMenu:SetPoint("TOPLEFT", OutfitButton, "BOTTOMLEFT", 0, -4);

    SaveButton = CreateFrame("Button", nil, self, "UIPanelButtonTemplate");
    SaveButton:SetWidth(redButtonWidth);
    SaveButton:SetHeight(22);
    SaveButton:SetPoint("LEFT", OutfitButton, "RIGHT", 2, 0);

    Mixin(SaveButton, SaveButtonMixin);
    SaveButton:SetScript("OnClick", SaveButtonMixin.OnClick);
    SaveButton:SetMode(1);

    self:SetScript("OnShow", self.OnShow);
    self:SetScript("OnHide", self.OnHide);
    self:SetScript("OnEvent", self.OnEvent);

    self:OnShow();

    PreviewModel = CreatePreviewModel(DropDownMenu);
    local frameLevel = DropDownMenu:GetFrameLevel();
    PreviewModel:SetFrameLevel(frameLevel + 2);

    EditButton = CreateEditButton(self);
end

function MainFrame:OnFirstEvent(event)
    if event == "TRANSMOGRIFY_OPEN" then
        self:UnregisterEvent(event);
        C_Timer.After(0.1, function()
            if NarcissusDB.TransmogOutfitSelect then
                self:Init();
            end
        end);
    end
end

function MainFrame:OnEvent(event, ...)
    if event == "TRANSMOGRIFY_UPDATE" then
        self:UpdateSaveButton();
    elseif event == "TRANSMOGRIFY_ITEM_UPDATE" then
        local transmogLocation = ...
        self:UpdateSaveButton();
    end
end

function MainFrame:ListenEvents(state)
    if state then
        self:RegisterEvent("TRANSMOGRIFY_UPDATE");
        self:RegisterEvent("TRANSMOGRIFY_ITEM_UPDATE");
    else
        self:UnregisterEvent("TRANSMOGRIFY_UPDATE");
        self:UnregisterEvent("TRANSMOGRIFY_ITEM_UPDATE");
    end
end

function MainFrame:OnKeyDown(key)
    local valid;

    if key == self.sheatheKey then
        valid = true;
        self.ModelFrame:SetSheathed(not self.ModelFrame:GetSheathed());
    else
        valid = false;
    end

    if not InCombatLockdown() then
        self:SetPropagateKeyboardInput(not valid);
    end
end

local function GetBestSheatheKey()
    local key1, key2 = GetBindingKey("TOGGLESHEATH");

    if key1 and string.find(key1, "%-") then
        key1 = nil;
    end

    if key2 and string.find(key2, "%-") then
        key2 = nil;
    end

    local key = key1 or key2 or "Z";

    return key
end

function MainFrame:OnShow()
    --The WardrobeTransmogFrame itself caused massive frame rate drop when opened
    local lastAppliedOutfitID = ProfileAPI:GetLastAppliedOutfitID();
    if lastAppliedOutfitID then
        local info = ProfileAPI:GetClassicOutfitInfo(lastAppliedOutfitID);
        TransmogDataProvider:ApplyClassicOutfitString(info.s);
    end

    self:ListenEvents(true);
    self:UpdateAll();

    self.sheatheKey = GetBestSheatheKey();
    self:SetScript("OnKeyDown", self.OnKeyDown);
end

function MainFrame:OnHide()
    self:ListenEvents(false);
    self:SetScript("OnKeyDown", nil);
end

function MainFrame:UpdateAll()
    self.OutfitButton:LoadSelection();
    DropDownMenu:RequestUpdate();
    self:UpdateSaveButton();
end

function MainFrame:UpdateSaveButton()
    SaveButton:RequestUpdate();
end


local CreateStaticPopup;
do
    local PADDING_OUTER = 16;
    local PADDING_INNER = 8;
    local FRAME_WIDTH = 312;

    --[[
    function StaticPopupMixin:ReleaseObjects()
        if self.objectCount then
            for type, count in pairs(self.objectCount) do
                self.objectCount[type] = 0;
            end
        else
            self.objectCount = {};
        end

        if self.objects then
            for _, typeObjects in pairs(self.objects) do
                for _, object in pairs(typeObjects) do
                    object:Hide();
                    object:ClearAllPoints();
                end
            end
        end
    end

    function StaticPopupMixin:AcquireObject(type)
        if not self.objects then
            self.objects = {};
        end

        if not self.objectCount then
            self.objectCount = {};
        end

        if not self.objectCount[type] then
            self.objectCount[type] = 0;
        end

        local n = self.objectCount[type] + 1;
        self.objectCount[type] = n;

        if not self.objects[type] then
            self.objects[type] = {};
        end

        local object = self.objects[type][n];

        if not object then

        end
        
        return object
    end
    --]]

    local EditBoxMixin = {};

    function EditBoxMixin:OnLoad()
        if not self.LetterCount then
            self.LetterCount = self:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
            self.LetterCount:SetTextColor(0.35, 0.35, 0.35);
            self.LetterCount:SetPoint("LEFT", self, "RIGHT", 12, 0);
        end

        self:SetScript("OnEscapePressed", self.OnEscapePressed);
        self:SetScript("OnEnterPressed", self.OnEnterPressed);
        self:SetScript("OnTextChanged", self.OnTextChanged);
        self:SetScript("OnEditFocusGained", self.OnEditFocusGained);
    end

    function EditBoxMixin:OnEscapePressed()
        StaticPopup:Hide();
    end

    function EditBoxMixin:OnEnterPressed()
        if self.AcceptButton and self.AcceptButton:IsEnabled() then
            self.AcceptButton.onClickFunc();
        end
    end

    function EditBoxMixin:SetMaxLetters(maxLetters)
        self:_SetMaxLetters(maxLetters);
        self.maxLetters = maxLetters;
    end

    function EditBoxMixin:OnTextChanged(useInput)
        local numLetters = self:GetNumLetters() or 0;
        local remaining = self.maxLetters - numLetters;
        self.LetterCount:SetText(remaining);
        self.LetterCount:SetShown(remaining < 11);

        if self.AcceptButton then
            if numLetters > 0 then
                self.AcceptButton:Enable();
            else
                self.AcceptButton:Disable();
            end
        end
    end

    function EditBoxMixin:OnEditFocusGained()
        self:HighlightText();
    end


    local StaticPopupMixin = {};

    function StaticPopupMixin:OnShow()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPEN);
    end

    function StaticPopupMixin:OnHide()
        self:Hide();
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE);
    end

    function StaticPopupMixin:ResetPosition()
        self:ClearAllPoints();
        self:SetPoint("TOP", UIParent, "TOP", 0, -135);
        self:Show();
    end

    local function CreateRedButton(parent)
        local f = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate");
        f:SetWidth(128);
        f:SetHeight(22);
        f:Hide();
        return f
    end

    function StaticPopupMixin:OnLoad()
        local Title = self:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
        self.Text1 = Title;
        Title:SetJustifyH("CENTER");
        Title:SetJustifyV("TOP");
        Title:SetPoint("TOP", self, "TOP", 0, -PADDING_OUTER);

        local EditBox = CreateFrame("EditBox", nil, self);
        EditBox:Hide();
        self.EditBox = EditBox;
        EditBox._SetMaxLetters = EditBox.SetMaxLetters;
        Mixin(EditBox, EditBoxMixin);
        EditBox:OnLoad();
        EditBox:SetAutoFocus(true);
        EditBox:SetFontObject("ChatFontNormal");
        EditBox:SetSize(130, 32);
        EditBox:SetTextInsets(2, 2, 0, 0);
        EditBox:SetMaxLetters(24);

        do
            local Left = EditBox:CreateTexture(nil, "BORDER");
            local Right = EditBox:CreateTexture(nil, "BORDER");
            local Middle = EditBox:CreateTexture(nil, "BORDER");

            Left:SetSize(32, 32);
            Right:SetSize(32, 32);

            Left:SetPoint("LEFT", EditBox, "LEFT", -10, 0);
            Right:SetPoint("RIGHT", EditBox, "RIGHT", 10, 0);
            Middle:SetPoint("TOPLEFT", Left, "TOPRIGHT", 0, 0);
            Middle:SetPoint("BOTTOMRIGHT", Right, "BOTTOMLEFT", 0, 0);

            Left:SetTexture("Interface/ChatFrame/UI-ChatInputBorder-Left2");
            Right:SetTexture("Interface/ChatFrame/UI-ChatInputBorder-Right2");
            Middle:SetTexture("Interface/ChatFrame/UI-ChatInputBorder-Mid2", "REPEAT");
        end

        self.Button1 = CreateRedButton(self);
        self.Button2 = CreateRedButton(self);
        self.Button3 = CreateRedButton(self);

        local buttonWidth = math.floor(0.5*(FRAME_WIDTH - 2 * PADDING_OUTER - PADDING_INNER));
        self.Button1:SetWidth(buttonWidth);
        self.Button2:SetWidth(buttonWidth);

        self.Button2:SetScript("OnClick", function()
            self:Hide();
        end);

        self.Divider1 = self:CreateTexture(nil, "OVERLAY");
        self.Divider1:SetTexture("Interface/AddOns/Narcissus/Art/Frames/Divider-Gradient-H");
        self.Divider1:SetSize(FRAME_WIDTH - 2*PADDING_OUTER, 4);
        self.Divider1:SetAlpha(0.2);

        self.Text3 = self:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
        self.Text3:SetJustifyH("LEFT");
        self.Text3:SetJustifyV("TOP");

        self:SetScript("OnShow", self.OnShow);
        self:SetScript("OnHide", self.OnHide);
    end

    function StaticPopupMixin:ReleaseObjects()
        self.EditBox:Hide();
        self.Button3:Hide();
        self.Text3:Hide();
        self.Divider1:Hide();
    end

    local function AddContentHeight(old, object, offset)
        return old + object:GetHeight() + (offset or 0)
    end

    local function FitButtonToText(redButton)
        local textWidth = redButton.Text:GetWrappedWidth();
        local width = (math.max(textWidth, 38) + 32);
        redButton:SetWidth(width);
    end

    function StaticPopupMixin:Layout(layout)
        self:ReleaseObjects();
        self:ResetPosition();

        local contentHeight = PADDING_OUTER;

        self.Text1:SetText(TRANSMOG_OUTFIT_NAME or "Enter Outfit Name:");
        contentHeight = AddContentHeight(contentHeight, self.Text1);

        self.EditBox:SetPoint("TOP", self.Text1, "BOTTOM", 0, -PADDING_INNER);
        self.EditBox.AcceptButton = self.Button1;
        self.EditBox:SetText(layout.defaultText);
        self.EditBox:Show();
        contentHeight = AddContentHeight(contentHeight, self.EditBox, PADDING_INNER);

        self.Button1:ClearAllPoints();
        self.Button1:SetPoint("TOPRIGHT", self.EditBox, "BOTTOM", -PADDING_INNER * 0.5, -PADDING_INNER);
        self.Button1:SetText(SAVE);
        self.Button1:Show();
        self.Button1:SetScript("OnClick", layout.OnAccept);
        self.Button1.onClickFunc = layout.OnAccept;

        self.Button2:ClearAllPoints();
        self.Button2:SetPoint("TOPLEFT", self.EditBox, "BOTTOM", PADDING_INNER * 0.5, -PADDING_INNER);
        self.Button2:SetText(CANCEL);
        self.Button2:Show();

        contentHeight = AddContentHeight(contentHeight, self.Button2, PADDING_INNER);

        --delete
        if layout.showDelete then
            local dividerPadding = 4;
            contentHeight = contentHeight + PADDING_INNER;
            contentHeight = contentHeight + dividerPadding;
            self.Divider1:ClearAllPoints();
            self.Divider1:SetPoint("TOP", self, "TOP", 0, -contentHeight);
            self.Divider1:Show();
            contentHeight = AddContentHeight(contentHeight, self.Divider1, PADDING_INNER + dividerPadding);

            self.Text3:ClearAllPoints();
            self.Text3:SetPoint("LEFT", self, "TOPLEFT", PADDING_OUTER, -contentHeight -0.5 * self.Button3:GetHeight());
            self.Text3:SetText(TRANSMOG_OUTFIT_DELETE);
            self.Text3:SetTextColor(1.000, 0.125, 0.125);
            self.Text3:Show();

            self.Button3:ClearAllPoints();
            self.Button3:SetPoint("TOPRIGHT", self, "TOPRIGHT", -PADDING_OUTER, -contentHeight);
            self.Button3:SetText(DELETE);
            self.Button3:Show();
            FitButtonToText(self.Button3);
            self.Button3:SetScript("OnClick", layout.OnDelete);

            contentHeight = AddContentHeight(contentHeight, self.Button3);
        end

        contentHeight = contentHeight + PADDING_OUTER;

        self:SetHeight(math.floor(0.5 + contentHeight));
    end

    function CreateStaticPopup(parent)
        local f = CreateFrame("Frame", nil, parent);
        Mixin(f, StaticPopupMixin);
        f:SetFrameStrata("DIALOG");
        f:SetSize(FRAME_WIDTH, 120);
        CreateNineSliceBackground(f);

        f:SetScript("OnShow", f.OnShow);
        f:SetScript("OnHide", f.OnHide);

        f:OnLoad();

        return f
    end
end


do
    local DialogInfo = {};

    local function AccpetNewOutfit()
        local name = StaticPopup.EditBox:GetText();
        if name and name ~= "" then
            if SaveCurrentOutfit(name) then
                StaticPopup:Hide();
                return true
            end
        end
    end

    local function RenameOutfit()
        local name = StaticPopup.EditBox:GetText();
        local outfitID = StaticPopup.arg1;
        if outfitID and name and name ~= "" then
            ProfileAPI:RenameClassicOutfit(outfitID, name);
            StaticPopup:Hide();
            MainFrame:UpdateAll();
        end
    end

    local function DeleteOutfit()
        local outfitID = StaticPopup.arg1;
        if outfitID then
            ProfileAPI:DeleteClassicOutfit(outfitID);
            StaticPopup:Hide();
            MainFrame:UpdateAll();
        end
    end

    local LAYOUT_NEW_OUTFIT = {
        showDelete = false,
        defaultText = L["Default Outfit Name"],
        OnAccept = AccpetNewOutfit,
    };

    function DialogInfo.NEW_OUTFIT(self)
        StaticPopup:Layout(LAYOUT_NEW_OUTFIT);

        return true
    end

    local LAYOUT_EDIT_OUTFIT = {
        showDelete = true,
        OnAccept = RenameOutfit,
        OnDelete = DeleteOutfit,
    };


    function DialogInfo.EDIT_OUTFIT(self, outfitID)
        if not outfitID then
            outfitID = MainFrame.highlightedOutfitID;
        end

        if not outfitID then return false end;

        StaticPopup.arg1 = outfitID;
        LAYOUT_EDIT_OUTFIT.defaultText = GetOutfitName(outfitID);
        StaticPopup:Layout(LAYOUT_EDIT_OUTFIT);

        return true
    end

    function MainFrame:ShowDialog(which, ...)
        if DialogInfo[which] then
            if not StaticPopup then
                StaticPopup = CreateStaticPopup(self)
            end

            if DialogInfo[which](self, ...) then
                StaticPopup:Show();
            else
                StaticPopup:Hide();
            end
        end

        DropDownMenu:Hide();
    end
end


function MainFrame:EnableModule(state)
    if state then
        if self.Init then
            MainFrame:RegisterEvent("TRANSMOGRIFY_OPEN");
        else
            self:Show();
        end
    else
        if self.Init then
            MainFrame:UnregisterEvent("TRANSMOGRIFY_OPEN");
        else
            self:Hide();
        end
    end
end

do
    local SettingFunctions = addon.SettingFunctions;

    function SettingFunctions.EnableWardrobeTransmogModule(state, db)
        if state == nil then
            state = db["TransmogOutfitSelect"];
        end

        MainFrame:EnableModule(state);
    end
end

MainFrame:SetScript("OnEvent", MainFrame.OnFirstEvent);