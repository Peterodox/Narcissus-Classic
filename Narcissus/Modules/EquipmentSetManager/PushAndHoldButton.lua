local DEFAULT_LONG_CLICK_DURATION = 0.8;

local GetColorPresetRGB = NarciAPI.GetColorPresetRGB;

local function Bar_OnUpdate(self, elapsed)
    self.t = self.t + elapsed;

    self.w = (self.t / self.duration) * self.width;
    self.Bar:SetWidth(self.w);

    if self.t >= self.duration then
        self:Reset();
        if self.onLongClickFunc then
            self.onLongClickFunc(self.arg1);
        end
    end
end

NarciPushAndHoldButtonMixin = {};

function NarciPushAndHoldButtonMixin:OnLoad()
    self.duration = DEFAULT_LONG_CLICK_DURATION;
end

function NarciPushAndHoldButtonMixin:SetLongClick(onLongClickFunc, arg1)
    self.onLongClickFunc = onLongClickFunc;
    self.onClickFunc = nil;
    self.arg1 = arg1;
end

function NarciPushAndHoldButtonMixin:SetClick(onClickFunc, arg1)
    self.onLongClickFunc = nil;
    self.onClickFunc = onClickFunc;
    self.arg1 = arg1;
end

function NarciPushAndHoldButtonMixin:OnHide()
    self:Reset();
end

function NarciPushAndHoldButtonMixin:Start()
    self.Name:SetPoint("CENTER", self, "CENTER", 0, -1);
    self.holding = true;

    if self.onLongClickFunc then
        self.width = self:GetWidth();
        self.Bar:Show();
        self.t = 0;
        self:SetScript("OnUpdate", Bar_OnUpdate);
    end
end

function NarciPushAndHoldButtonMixin:Reset()
    self:SetScript("OnUpdate", nil);
    self.t = nil;
    self.w = nil;
    self.width = nil;
    self.Bar:Hide();
    self.Name:SetPoint("CENTER", self, "CENTER", 0, 0);
    if self.holding then
        self.holding = nil;
        if not (self:IsMouseOver() and self:IsVisible()) then
            self.Highlight:Hide();
        end
    end
end

function NarciPushAndHoldButtonMixin:OnMouseDown()
    if self:IsEnabled() then
        self:Start();
    end
end

function NarciPushAndHoldButtonMixin:OnMouseUp()
    self:Reset();
end

function NarciPushAndHoldButtonMixin:OnClick()
    if self.onClickFunc then
        self.onClickFunc(self.arg1);
    end
end

function NarciPushAndHoldButtonMixin:SetDuration(duration)
    self.duration = duration;
end

function NarciPushAndHoldButtonMixin:OnEnter()
    if self:IsEnabled() then
        self.Highlight:Show();
    end

    if self.onEnterFunc then
        self.onEnterFunc(self);
    end
end

function NarciPushAndHoldButtonMixin:OnLeave()
    if not self.holding then
        self.Highlight:Hide();
    end
    if self.onLeaveFunc then
        self.onLeaveFunc(self);
    end
end

function NarciPushAndHoldButtonMixin:SetButtonText(text)
    self.Name:SetText(text)
end

function NarciPushAndHoldButtonMixin:SetTextColor(r, g, b)
    self.Name:SetTextColor(r, g, b);
end

function NarciPushAndHoldButtonMixin:SetColor(colorName)
    if colorName ~= self.color then
        self.color = colorName;
        local r, g, b = GetColorPresetRGB(colorName);
        self:SetTextColor(r, g, b);
    end
end