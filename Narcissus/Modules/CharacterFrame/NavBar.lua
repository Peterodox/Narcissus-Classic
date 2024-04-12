local function CreateNavBar(width, parent, point, relativeTo, relativePoint, offsetX, offsetY, tabNames, onTabChangedCallback, defaultIndex)
    local bar = CreateFrame("Frame", nil, parent, "NarciNavBarTemplate");
    bar:SetWidth(width);
    bar:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY);
    bar:SetUp(tabNames, onTabChangedCallback, defaultIndex);
    return bar
end

do
    local _, addon = ...
    addon.CreateNavBar = CreateNavBar;
end



NarciNavBarTabButtonMixin = {};

function NarciNavBarTabButtonMixin:OnEnter()
    if not self.isSelected then
        self.Label:SetTextColor(0.85, 0.85, 0.85);
    end
end

function NarciNavBarTabButtonMixin:OnLeave()
    if not self.isSelected then
        self.Label:SetTextColor(0.5, 0.5, 0.5);
    end
end

function NarciNavBarTabButtonMixin:OnClick()
    self:GetParent():SelectTab(self.tabIndex);
end

function NarciNavBarTabButtonMixin:OnMouseDown()
    if not self.isSelected then
        self.Label:SetPoint("CENTER", self, "CENTER", 0, -1);
    end
end

function NarciNavBarTabButtonMixin:OnMouseUp()
    self.Label:SetPoint("CENTER", self, "CENTER", 0, 0);
end

function NarciNavBarTabButtonMixin:SetSelection(state)
    if state then
        self.Highlight:Show();
        self.isSelected = true;
        self.Label:SetTextColor(0.92, 0.92, 0.92);
    else
        self.Highlight:Hide();
        self.isSelected = nil;
        self.Label:SetTextColor(0.5, 0.5, 0.5);
    end
end

function NarciNavBarTabButtonMixin:SetUp(labelText, tabIndex)
    self.Label:SetWidth(0);
    self.Label:SetText(labelText);
    local textWidth = self.Label:GetWidth();
    local MAX_WIDTH = 60;
    if textWidth < 30 then
        textWidth = 30;
        self.Label:SetWidth(textWidth);
    elseif textWidth > MAX_WIDTH then
        textWidth = MAX_WIDTH;
        self.Label:SetWidth(textWidth);
    end
    self:SetWidth(textWidth + 20);
    self.tabIndex = tabIndex;
end



NarciNavBarMixin = {};

function NarciNavBarMixin:GoNext()
    if self.tabID < self.numTabs then
        self:SelectTab(self.tabID + 1);
    end
end

function NarciNavBarMixin:GoPrevious()
    if self.tabID > 1 then
        self:SelectTab(self.tabID - 1);
    end
end

function NarciNavBarMixin:OnMouseWheel(delta)
    if delta > 0 then
        self:GoPrevious();
    else
        self:GoNext();
    end
end

function NarciNavBarMixin:SelectTab(tabIndex, forceUpdate)
    if tabIndex ~= self.tabID or forceUpdate then
        self.tabID = tabIndex;
        if self.onTabChanged then
            self.onTabChanged(tabIndex);
        end

        for k, button in pairs(self.navButtons) do
            button:SetSelection(k == tabIndex);
        end
    end
end

function NarciNavBarMixin:SetUp(tabNames, onTabChangedCallback, defaultIndex)
    if self.navButtons then
        for _, button in pairs(self.navButtons) do
            button:Hide();
            button:ClearAllPoints();
        end
    else
        self.navButtons = {};
    end

    self.numTabs = #tabNames;

    for i = 1, self.numTabs do
        if not self.navButtons[i] then
            self.navButtons[i] = CreateFrame("Button", nil, self, "NarciNavBarTabButtonTemplate");
        end
        if i == 1 then
            self.navButtons[i]:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0);
        else
            self.navButtons[i]:SetPoint("TOPLEFT", self.navButtons[i - 1], "TOPRIGHT", 0, 0);
        end
        self.navButtons[i]:SetUp(tabNames[i], i);
    end

    self.onTabChanged = onTabChangedCallback;

    if defaultIndex then
        self:SelectTab(defaultIndex);
    end
end