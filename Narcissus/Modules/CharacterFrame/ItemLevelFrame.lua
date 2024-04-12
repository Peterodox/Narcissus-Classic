local _, addon = ...
local AttributeController = Narci.AttributeController;

local FadeFrame = NarciFadeUI.Fade;
local floor = math.floor;
local sin = math.sin;
local pi = math.pi;

local SharedItemLocation = ItemLocation:CreateEmpty();
local ItemLevelFrame, CenterButton;

local function outSine(t, b, e, d)
	return (e - b) * sin(t / d * (pi / 2)) + b
end

local function RoundLevel(lvl)
	return floor(lvl * 100 + 0.5)/100
end


local function GenericItemLevel_OnEnter(self)
	Narci_ShowButtonTooltip(self);
end


local Themes = {
    grey = {
        fluidColor = {0.9, 0.9, 0.9},
        showLevel = true,
		frameTex = "HexagonTube",
        bakcgroundTex = "QualityGrey",
        highlightTex = "GenericHighlight",
        highlightSize = 100,
        highlightBlend = "ADD",
    },

    hardcore = {
        fluidColor = {0.82, 0.1, 0.1},
        showLevel = true,
		frameTex = "HexagonTube",
        bakcgroundTex = "Scratched",
        highlightTex = "GenericHighlight",
        highlightSize = 100,
        highlightBlend = "ADD",
    },
};



NarciItemLevelFrameMixin = {};

function NarciItemLevelFrameMixin:SetItemLevel(avgItemLevel)
	local playerLevel = UnitLevel("player");

	local avgItemLevelBase = floor(avgItemLevel);
	avgItemLevel = RoundLevel(avgItemLevel);

	self.LeftButton.avgItemLevel = avgItemLevel;
	
	local percentage = avgItemLevel - avgItemLevelBase;

	local height;		--Set the bar(Fluid) height in the Tube
	if percentage < 0.10 then
		height = 0.1;
	elseif percentage > 0.90 then
		height = 84;
	else
		height = 84 * percentage;
	end
	self.CenterButton.Fluid:SetHeight(height);
	self.CenterButton.Level:SetText(avgItemLevelBase);
	self.CenterButton.tooltipHeadline = STAT_AVERAGE_ITEM_LEVEL .." "..avgItemLevel;
end


function NarciItemLevelFrameMixin:SetThemeByName(themeName)
	if themeName ~= self.theme then
		local asset = Themes[themeName];
		local prefix = "Interface\\AddOns\\Narcissus\\Art\\Widgets\\ItemLevel\\";

		local file = prefix.. asset.frameTex;
		self.CenterButton.FluidBackground:SetTexture(file);
		self.CenterButton.TubeBorder:SetTexture(file);
		self.LeftButton.Background:SetTexture(file);
		self.LeftButton.Highlight:SetTexture(file);
		self.RightButton.Background:SetTexture(file);
		self.RightButton.Highlight:SetTexture(file);

		file = prefix.. asset.highlightTex;
		self.CenterButton.Highlight:SetTexture(file, nil, nil, "TRILINEAR");
		self.CenterButton.Highlight:SetSize(asset.highlightSize, asset.highlightSize);
		self.CenterButton.Highlight:SetDrawLayer("OVERLAY", asset.highlightLevel or 1);
		self.CenterButton.Highlight:SetBlendMode(asset.highlightBlend or "ADD");
		self.CenterButton:ShowMaxLevel(asset.showLevel);

		if asset.bakcgroundTex then
			self.CenterButton.Background:SetTexture(prefix.. asset.bakcgroundTex);
			self.CenterButton.Background:SetTexCoord(0, 1, 0, 1);
		else
			self.CenterButton.Background:SetTexture(nil);
		end
		if asset.fluidColor then
			self.CenterButton.Fluid:SetColorTexture(unpack(asset.fluidColor));
		end

		self.theme = themeName;

		self.CenterButton.onEnterFunc = asset.onEnterFunc or GenericItemLevel_OnEnter;
		self.CenterButton.onLeaveFunc = asset.onLeaveFunc;
	end
end

local SLOT_IDS = {
	1, 2, 3, 15, 5, 9,
	10, 6, 7, 8, 11, 12, 13, 14,
	16, 17, 18,
};

local ItemLevelCalculator = {};

function ItemLevelCalculator:Reset()
	self.numSlots = 0;
	self.levelSum = 0;
	self.i = 0;
end

function ItemLevelCalculator:GetValue()
	return (self.numSlots > 0 and self.levelSum / self.numSlots) or 1
end

function ItemLevelCalculator:ProcessNextSlot()
	self.i = self.i + 1;
	if SLOT_IDS[self.i] then
		SharedItemLocation:SetEquipmentSlot(SLOT_IDS[self.i]);
		if C_Item.DoesItemExist(SharedItemLocation) then
			local level = C_Item.GetCurrentItemLevel(SharedItemLocation);
			if level and level > 0 then
				self.levelSum = self.levelSum + level;
				self.numSlots = self.numSlots + 1;
			end
		end
	else
		ItemLevelFrame:SetItemLevel( ItemLevelCalculator:GetValue() );
	end
end

local function ItemLevelCalculator_OnUpdate(self, elapsed)
	self.delay = self.delay + elapsed;
	if self.delay >= 0.016 then
		self.delay = 0;
		ItemLevelCalculator:ProcessNextSlot();
	end
end

function NarciItemLevelFrameMixin:AsyncUpdate(delay)
	self.delay = (delay and -delay) or 0;
	ItemLevelCalculator:Reset();
	self:SetScript("OnUpdate", ItemLevelCalculator_OnUpdate);
end

function NarciItemLevelFrameMixin:InstantUpdate()

end

function NarciItemLevelFrameMixin:ToggleExtraInfo(state, replayAnimation)
	if not self.animFrame then
		self.animFrame = CreateFrame("Frame");
		self.animFrame:Hide();
		self.animFrame:SetScript("OnUpdate", function(f, elapsed)
			f.t = f.t + elapsed;
			local offsetX = outSine(f.t, f.fromX, f.toX, 0.4);
			if f.t >= 0.4 then
				offsetX = f.toX;
				f:Hide();
				if f.hideButton then
					self.LeftButton:Hide();
					self.RightButton:Hide();
				end
			end
			self.LeftButton:SetPoint("RIGHT", self, "CENTER", -offsetX, 0);
			self.RightButton:SetPoint("LEFT", self, "CENTER", offsetX, 0);
		end);
	end
	self.animFrame:Hide();
	self.animFrame.t = 0;
	local _, _, _, fromX = self.RightButton:GetPoint();
	self.animFrame.fromX = fromX;
	if state then
		self.animFrame.toX = 28;
		self.LeftButton:Show();
		self.RightButton:Show();
		self.animFrame.hideButton = false;
	else
		self.animFrame.toX = -32;
		self.animFrame.hideButton = true;
	end
	if fromX ~= self.animFrame.toX or replayAnimation then
		self.animFrame:Show();
	end
end


NarciItemLevelCenterButtonMixin = {};

function NarciItemLevelCenterButtonMixin:OnLoad()
	CenterButton = self;
	ItemLevelFrame = self:GetParent();

	self.tooltipLine1 = HIGHLIGHT_FONT_COLOR_CODE .. STAT_AVERAGE_ITEM_LEVEL_TOOLTIP .. FONT_COLOR_CODE_CLOSE;
	self.tooltipSpecial = Narci.L["Toggle Equipment Set Manager"];

	self.onEnterFunc = GenericItemLevel_OnEnter;

	self:SetScript("OnLoad", nil);
	self.OnLoad = nil;
end

local function OnEnterDelay_OnUpdate(self, elapsed)
	self.delay = self.delay + elapsed;
	if self.delay > 0 then
		if self.onEnterFunc then
			self.onEnterFunc(self);
		end
		self:StopDelay();
	end
end

function NarciItemLevelCenterButtonMixin:OnEnter()
	FadeFrame(self.Highlight, 0.2, 1);

	if self.onEnterFunc then
		self.delay = -0.5;
		self:SetScript("OnUpdate", OnEnterDelay_OnUpdate);
	else
		self:StopDelay();
	end
end

function NarciItemLevelCenterButtonMixin:OnMouseDown()
	self.Background:SetPoint("CENTER", 0, -4);
	self:StopDelay();
end

function NarciItemLevelCenterButtonMixin:OnMouseUp()
	self.Background:SetPoint("CENTER", 0, 0);
end

function NarciItemLevelCenterButtonMixin:OnLeave()
	FadeFrame(self.Highlight, 0.2, 0);
	Narci:HideButtonTooltip();
	if self.onLeaveFunc then
		self.onLeaveFunc(self);
	end
	self:StopDelay();
end

function NarciItemLevelCenterButtonMixin:OnClick()
	Narci:HideButtonTooltip();

	local esm = NarciEquipmentSetManager;
	esm:SetParentMode("narcissus");

	if esm.openedInNarcissus then
		esm:HideUI();
		AttributeController:SetFrameOffset(0);
	else
		esm:ShowUI();
		AttributeController:SetFrameOffset(-96);
	end

	self.showManager = not self.showManager;
end

function NarciItemLevelCenterButtonMixin:OnShow()
	if self.showManager then
		local esm = NarciEquipmentSetManager;
		if not esm:IsNarcissusMode() then
			esm:SetParentMode("narcissus");
		end
		esm:Show();
	end
end

function NarciItemLevelCenterButtonMixin:OnHide()
	if self.onHideFunc then
		self.onHideFunc(self);
	end
	self:StopDelay();
end

function NarciItemLevelCenterButtonMixin:ShowItemLevel()
	self:GetParent():Update();
end

function NarciItemLevelCenterButtonMixin:ShowMaxLevel(state)
	self.Header:SetShown(state);
	self.Level:SetShown(state);
	self.Surface:SetShown(state);
	self.Fluid:SetShown(state);
	self.Background:SetShown(state);
end

function NarciItemLevelCenterButtonMixin:StopDelay()
	if self.delay then
		self:SetScript("OnUpdate", nil);
		self.delay = nil;
	end
end