local ICON_GAP = 6;
local HEADER_HEIGHT = 24;

local NUM_ICONS_X = 5;
local NUM_ICONS_Y = 5;
local NUM_ICONS_SHOWN = NUM_ICONS_X * NUM_ICONS_Y;

local ICON_FILES, ICON_INFO;   --wipe when closed

local HeaderFontString;

local function IconButton_OnEnter(self)
    if self.iconInfo then
        local infoType, id = string.split(":", self.iconInfo);
        id = tonumber(id);
        if infoType == "spell" then
            HeaderFontString:SetText( GetSpellInfo(id) );
        elseif infoType == "slot" then
            local itemID = GetInventoryItemID("player", id);
            if itemID then
                HeaderFontString:SetText(C_Item.GetItemNameByID(itemID));
            end
        end
    else
        HeaderFontString:SetText(self.Icon:GetTexture());
    end
    self.Icon:SetVertexColor(1, 1, 1);
end

local function IconButton_OnLeave(self)
    if not self.selected then
        self.Icon:SetVertexColor(0.8, 0.8, 0.8);
    end
end

local function IconButton_OnClick(self)
    local selector = self:GetParent();
    for _, button in ipairs(selector.buttons) do
        if button.selected then
            button.Icon:SetVertexColor(0.8, 0.8, 0.8);
            button.selected = nil;
            break
        end
    end
    self.selected = true;
    local fileID = self.Icon:GetTexture();
    selector.Selection:ClearAllPoints();
    selector.Selection:SetPoint("CENTER", self, "CENTER", 0, 0);
    selector.Selection:Show();
    selector:SelectIcon(fileID);
end


NarciIconSelectorMixin = {};

function NarciIconSelectorMixin:OnLoad()
    HeaderFontString = self.Header;

    local width = (24 + ICON_GAP) * NUM_ICONS_X + ICON_GAP;
    self.Header:SetWidth(width - 12);
    self:SetSize(width, (24 + ICON_GAP) * NUM_ICONS_Y - ICON_GAP + HEADER_HEIGHT * 2); --plus header and footer
end

function NarciIconSelectorMixin:OnHide()
    self:Close(true);
end

function NarciIconSelectorMixin:OnMouseWheel(delta)
    if delta > 0 then
        if self.page > 1 then
            self.page = self.page - 1;
        else
            return
        end
    else
        if self.page < self.maxPage then
            self.page = self.page + 1;
        else
            return
        end
    end

    self:SetPage(self.page);
end

function NarciIconSelectorMixin:Init()
    self.buttons = {};
    self.page = 1;
    self.maxPage = 1;

    local row = 0;
    local col = 0;
    local button;

    for i = 1, NUM_ICONS_SHOWN do
        col = col + 1;
        if col > NUM_ICONS_X then
            col = 1;
            row = row + 1;
        end
        self.buttons[i] = CreateFrame("Button", nil, self);
        button = self.buttons[i];
        button:SetSize(24, 24);
        button:SetPoint("TOPLEFT", self, "TOPLEFT", ICON_GAP + (24 + ICON_GAP) * (col - 1), -(24 + ICON_GAP) * row -HEADER_HEIGHT);
        button:SetHitRectInsets(-3, -3, -3, -3);
        button.Icon = button:CreateTexture(nil, "ARTWORK");
        button.Icon:SetTexCoord(0.075, 0.925, 0.075, 0.925);
        button.Icon:SetSize(24, 24);
        button.Icon:SetPoint("CENTER", button, "CENTER", 0, 0);
        button.Icon:SetVertexColor(0.8, 0.8, 0.8);

        button:SetScript("OnEnter", IconButton_OnEnter);
        button:SetScript("OnLeave", IconButton_OnLeave);
        button:SetScript("OnClick", IconButton_OnClick);
    end

    self.Init = nil;
    NarciIconSelectorMixin.Init = nil;
end

function NarciIconSelectorMixin:OpenAt(parentButton, direction, selectedIcon)
    self:ClearAllPoints();
    if direction == "right" then
        self:SetPoint("TOPLEFT", parentButton, "TOPRIGHT", 2, HEADER_HEIGHT);
    else --"left"
        self:SetPoint("TOPRIGHT", parentButton, "TOPLEFT", -ICON_GAP, HEADER_HEIGHT);
    end

    self.OverlayIcon:ClearAllPoints();
    self.OverlayIcon:SetPoint("CENTER", parentButton.Icon, "CENTER", 0, 0);
    self.OverlayIcon:SetTexture(selectedIcon);

    if self.Init then
        self:Init();
    end

    self.selectedIcon = selectedIcon;
    self.parentButton = parentButton;
    self.anyChange = nil;

    self:LoadIcons();
    self:SetPage(1);
    self:Show();
    self:SetFrameStrata(parentButton:GetFrameStrata());
    local level = parentButton:GetFrameLevel();
    self:SetFrameLevel(level);
    level = level + 2;
    for _, button in pairs(self.buttons) do
        button:SetFrameLevel(level);
    end
end

function NarciIconSelectorMixin:Close(clearCache)
    self:Hide();
    self:ClearAllPoints();
    self.anyChange = nil;

    if clearCache then
        self:UnloadIcons();
    end
end

function NarciIconSelectorMixin:LoadIcons()
    if ICON_FILES then
        return
    end

    ICON_FILES = { 134400 };    --INV_MISC_QUESTIONMARK
    ICON_INFO = {};

    local total = #ICON_FILES;

	local activeIcons = {};

    local GetInventoryItemTexture = GetInventoryItemTexture;
    local GetSpellTabInfo = GetSpellTabInfo;
    local GetSpellBookItemInfo = GetSpellBookItemInfo;
    local GetSpellBookItemTexture = GetSpellBookItemTexture;
    local GetFlyoutInfo = GetFlyoutInfo;
    local GetFlyoutSlotInfo = GetFlyoutSlotInfo;
    local GetSpellTexture = GetSpellTexture;


    local _, fileID, spellType, tabEnd, offset, numSpells, numSlots, isKnown, spellID;

    --Inventory Icons
    for slotID = 1, 19 do
        fileID = GetInventoryItemTexture("player", slotID);
        if fileID then
            if not activeIcons[fileID] then
                activeIcons[fileID] = true;
                total = total + 1;
                ICON_FILES[total] = fileID;
                ICON_INFO[total] = "slot:"..slotID;
            end
        end
    end

    --Known Spell Icons
	for i = 1, GetNumSpellTabs() do
        _,  _, offset, numSpells, _ = GetSpellTabInfo(i);
		offset = offset + 1;
		tabEnd = offset + numSpells;
		for j = offset, tabEnd - 1 do
			spellType, ID = GetSpellBookItemInfo(j, "player");
			if (spellType ~= "FUTURESPELL") then
				fileID = GetSpellBookItemTexture(j, "player");
				if fileID then
                    if not activeIcons[fileID] then
                        activeIcons[fileID] = true;
                        total = total + 1;
                        ICON_FILES[total] = fileID;
                        ICON_INFO[total] = "spell:"..ID;
                    end
				end
			end
			if (spellType == "FLYOUT") then
				_, _, numSlots, isKnown = GetFlyoutInfo(ID);
				if (isKnown and numSlots > 0) then
					for k = 1, numSlots do
						spellID, _, isKnown = GetFlyoutSlotInfo(ID, k)
						if isKnown then
							fileID = GetSpellTexture(spellID);
							if fileID then
                                if not activeIcons[fileID] then
                                    activeIcons[fileID] = true;
                                    total = total + 1;
                                    ICON_FILES[total] = fileID;
                                    ICON_INFO[total] = "spell:"..spellID;
                                end
							end
						end
					end
				end
			end
		end
	end

    GetMacroItemIcons(ICON_FILES);

    total = #ICON_FILES;
    self.maxPage = math.ceil(total / NUM_ICONS_SHOWN);
end

function NarciIconSelectorMixin:UnloadIcons()
    if self.buttons then
        for _, button in pairs(self.buttons) do
            button.Icon:SetTexture(nil);
            button.iconInfo = nil;
        end
    end
    ICON_FILES = nil;
    ICON_INFO = nil;
end

function NarciIconSelectorMixin:SetPage(page)
    self.page = page;
    self.Selection:Hide();

    local offset = (page - 1) * NUM_ICONS_SHOWN;
    local index, fileID;

    for i = 1, NUM_ICONS_SHOWN do
        index = i + offset;
        fileID = ICON_FILES[index];

        self.buttons[i]:Hide(); --to trigger OnEnter
        self.buttons[i].Icon:SetVertexColor(0.8, 0.8, 0.8);
        self.buttons[i].selected = nil;

        if fileID then
            self.buttons[i].Icon:SetTexture(fileID);
            self.buttons[i]:Show();
            if fileID == self.selectedIcon then
                self.Selection:ClearAllPoints();
                self.Selection:SetPoint("CENTER", self.buttons[i], "CENTER", 0, 0);
                self.Selection:Show();
                self.buttons[i].selected = true;
                self.buttons[i].Icon:SetVertexColor(1, 1, 1);
            end
        else

        end
        self.buttons[i].iconInfo = ICON_INFO[index];
    end

    self.PageText:SetText(self.page .. " / " .. self.maxPage);
end

function NarciIconSelectorMixin:SelectIcon(fileID, programmatical)
    self.selectedIcon = fileID;
    self.OverlayIcon:SetTexture(fileID);
    --[[
    if self.parentButton then
        self.parentButton.Icon:SetTexture(fileID);
        self.parentButton.Icon:SetTexCoord(0.075, 0.925, 0.075, 0.925);
    end
    --]]

    if not programmatical then
        self.anyChange = true;
    end
end

function NarciIconSelectorMixin:GetSelectedIcon()
    return self.selectedIcon
end

function NarciIconSelectorMixin:IsChanged()
    return self.anyChange
end