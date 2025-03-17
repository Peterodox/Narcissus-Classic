--[[
This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License. To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
--]]

--Settings storaged in NarcissusDB
local _, addon = ...
local API = addon.API;
local MsgAlertContainer = addon.MsgAlertContainer;

local Narci = Narci;

Narci.refreshCombatRatings = true;

local SLOT_TABLE = {};
local L = Narci.L;
local VIGNETTE_ALPHA = 0.5;
local IS_OPENED = false;									--Addon was opened by clicking
local MOG_MODE = false;
local XMOG_MODE = 0;										-- 0 off	1 "Texts Only" 	2 "Texts & Model"
local CAN_MOG = addon.expansionID >= 4;

local NarciAPI = NarciAPI;
local GetItemEnchantID = NarciAPI.GetItemEnchantID;
local GetEnchantTextByItemLink = NarciAPI.GetEnchantTextByItemLink;
local EnchantInfo = Narci.EnchantData;						--Bridge/GearBonus.lua
local SmartFontType = NarciAPI.SmartFontType;
local IsItemSocketable = NarciAPI.IsItemSocketable;
local SetBorderTexture = NarciAPI.SetBorderTexture;
local GetBorderArtByItemID = NarciAPI.GetBorderArtByItemID;
local GetVerticalRunicLetters = NarciAPI.GetVerticalRunicLetters;
local FadeFrame = NarciFadeUI.Fade;
local GetGemBorderTexture = NarciAPI.GetGemBorderTexture;
local GetItemQualityColor = NarciAPI.GetItemQualityColor;
local QueueFrame = NarciAPI.CreateProcessor(nil, 0.5);
local AttributeController = Narci.AttributeController;
local GetInventoryItemsForSlot = GetInventoryItemsForSlot;
local GetItemInfo = API.GetItemInfo;
local GetItemInfoInstant = API.GetItemInfoInstant;
local InCombatLockdown = InCombatLockdown;
local PlayLetteboxAnimation = NarciAPI_LetterboxAnimation;
local GetToolbarButtonByButtonType = addon.GetToolbarButtonByButtonType;
local TransmogDataProvider = addon.TransmogDataProvider;
local ConfirmBinding = addon.ConfirmBinding;

local Narci_AlertFrame_Autohide = Narci_AlertFrame_Autohide;
local C_Item = C_Item;

local After = C_Timer.After;
local ItemLocation = ItemLocation;
local GetAlternateFormInfo = C_PlayerInfo.GetAlternateFormInfo or HasAlternateForm;

local floor = math.floor;
local max = math.max;

local UIParent = _G.UIParent;
local Toolbar = NarciScreenshotToolbar;
local EquipmentFlyoutFrame;
local ItemLevelFrame;
local ItemTooltip;
local FlyoutBlackScreen;

local MiniButton = Narci_MinimapButton;
local NarciThemeUtil = NarciThemeUtil;

--Classic API
local NarciClassicAPI = NarciClassicAPI;
local EquipmentManagerAPI = NarciClassicAPI.EquipmentManager;
local EngravingSlotUtil = addon.EngravingSlotUtil;


local EL = CreateFrame("Frame");	--Event Listener
EL:Hide();

EL.dynamicEvents = {"PLAYER_TARGET_CHANGED", "COMBAT_RATING_UPDATE", "PLAYER_MOUNT_DISPLAY_CHANGED",
"PLAYER_STARTED_MOVING", "PLAYER_REGEN_DISABLED", "UNIT_MAXPOWER", "PLAYER_STARTED_TURNING", "PLAYER_STOPPED_TURNING",
"BAG_UPDATE_COOLDOWN", "UNIT_STATS", "BAG_UPDATE", "PLAYER_EQUIPMENT_CHANGED",
};

EL.unitEvents = {"UNIT_DAMAGE", "UNIT_ATTACK_SPEED", "UNIT_MAXHEALTH", "UNIT_AURA", "UNIT_INVENTORY_CHANGED"};


function Narci:UpdateVignetteStrength()
	local alpha = tonumber(NarcissusDB.VignetteStrength) or 0.5;
	VIGNETTE_ALPHA = alpha;
	Narci_Vignette.VignetteLeft:SetAlpha(alpha);
	Narci_Vignette.VignetteRight:SetAlpha(alpha);
	Narci_Vignette.VignetteRightSmall:SetAlpha(alpha);
	Narci_PlayerModelGuideFrame.VignetteRightSmall:SetAlpha(alpha);
end

--[[
local TakenOutFrames = {
	[2] = AzeriteEmpoweredItemUI, 		--
	[3] = ItemSocketingFrame,			--
	[4] = ArtifactFrame,				--
}

local function TakeOutFromUIParent(frame, frameStrata, state)
	local effectiveScale = UIParent:GetEffectiveScale();
	frameStrata = frameStrata or "MEDIUM";

	if frame then
		if state then
			frame:SetParent(nil);
			frame:SetFrameStrata(frameStrata);
			frame:SetScale(effectiveScale);
		else
			frame:SetScale(1);
			frame:SetParent(UIParent);
			frame:SetFrameStrata(frameStrata);
		end
	end
end
--]]

--take out frames from UIParent, so they will still be visible when UI is hidden
local function TakeOutFrames(state)
	local frameNames = {
		"AzeriteEmpoweredItemUI", "AzeriteEssenceUI", "ItemSocketingFrame",
	};
	local frame;
	if state then
		local scale = UIParent:GetEffectiveScale();
		for _, frameName in pairs(frameNames) do
			frame = _G[frameName];
			if frame then
				frame:SetParent(nil);
				frame:SetScale(scale);
			end
		end
	else
		for _, frameName in pairs(frameNames) do
			frame = _G[frameName];
			if frame then
				frame:SetParent(UIParent);
				frame:SetScale(1);
			end
		end
	end
end


local DefaultTooltip;
local ShowDelayedTooltip = NarciAPI_ShowDelayedTooltip;

function Narci_ShowButtonTooltip(self)
	DefaultTooltip:HideTooltip();
	DefaultTooltip:SetOwner(self, "ANCHOR_NONE");
	if not self.tooltipHeadline then
		return
	end

	DefaultTooltip:SetPoint("BOTTOM", self, "TOP", 0, 2);

	DefaultTooltip:SetText(self.tooltipHeadline);

	if self.tooltipLine1 then
		DefaultTooltip:AddLine(self.tooltipLine1, 1, 1, 1, true);
	end

	if self.tooltipSpecial then
		DefaultTooltip:AddLine(" ", 1, 1, 1, true);
		DefaultTooltip:AddLine(self.tooltipSpecial, 0.25, 0.78, 0.92, true);
	end


	DefaultTooltip:ShowTooltip();
	DefaultTooltip:FadeIn();

	--ShowDelayedTooltip("BOTTOM", self, "TOP", 0, 2);
end

function Narci:HideButtonTooltip()
	--ShowDelayedTooltip(false);
	DefaultTooltip:HideTooltip();
	ItemTooltip:HideTooltip();
	--DefaultTooltip:SetFrameStrata("TOOLTIP");
end


local linear = addon.EasingFunctions.linear;
local outSine = addon.EasingFunctions.outSine;
local inOutSine = addon.EasingFunctions.inOutSine;


--------------------------------
local UIPA = CreateFrame("Frame");	--UIParentAlphaAnimation
UIPA:Hide()
UIPA.t = 0;
UIPA.totalTime = 0;
UIPA.frame = UIParent;

UIPA:SetScript("OnShow", function(self)
	self.startAlpha = self.frame:GetAlpha();
end);

UIPA:SetScript("OnUpdate", function(self, elapsed)
	self.t = self.t + elapsed
	self.totalTime = self.totalTime + elapsed;
	if self.t < 0.08 then	--Limit update frequency to mitigate the impact on FPS
		return;
	else
		self.t = 0;
	end

	local alpha = linear(self.totalTime, self.startAlpha, self.endAlpha, 0.5);

	if self.totalTime >= 0.5 then
		alpha = self.endAlpha;
		self:Hide();
	end

	self.frame:SetAlpha(alpha);
end);

UIPA:SetScript("OnHide", function(self)
	self.t = 0;
	self.totalTime = 0;
end);


--------------------------------
-----------CVar Backup----------
--------------------------------
local ConsoleExec = ConsoleExec;
local GetCVar = GetCVar;
local SetCVar = SetCVar;

ConsoleExec("pitchlimit 88");

local CVarTemp = {};

function CVarTemp:BackUp()
	self.ZoomLevel = GetCameraZoom();
	self.DynamicPitch = tonumber(GetCVar("test_cameraDynamicPitch"));
	self.OverShoulder = GetCVar("test_cameraOverShoulder");
	self.MusicVolume = GetCVar("Sound_MusicVolume");
	self.CameraViewBlendStyle = GetCVar("cameraViewBlendStyle");
end

function CVarTemp:BackUpDynamicCam()
	self.DynmicCamShoulderOffsetZoomUpperBound = DynamicCam.db.profile.shoulderOffsetZoom.lowerBound;	--New
	DynamicCam.db.profile.shoulderOffsetZoom.lowerBound = 0;
end

function CVarTemp:RestoreDynamicCam()
	DynamicCam.db.profile.shoulderOffsetZoom.lowerBound = self.DynmicCamShoulderOffsetZoomUpperBound;
end

local function GetKeepActionCam()
	return CVarTemp.isDynamicCamLoaded or Narci.keepActionCam
end

CVarTemp.OverShoulder = tonumber(GetCVar("test_cameraOverShoulder"));
CVarTemp.DynamicPitch = tonumber(GetCVar("test_cameraDynamicPitch"));		--No CVar directly shows the current state of ActionCam. Check this CVar for the moment. 1~On  2~Off
CVarTemp.MusicVolume = tonumber(GetCVar("Sound_MusicVolume"));
CVarTemp.ZoomLevel = 2;

local ZoomFactor = {};
ZoomFactor.Time = 1.5;			--1.5 outSine
--ZoomFactor.Amplifier = 0.65; 	--0.65
ZoomFactor.toSpeedBasic = 0.004;	--yawmovespeed 180
ZoomFactor.fromSpeedBasic = 1.05;	--yawmovespeed 180
ZoomFactor.toSpeed = 0.005;	--yawmovespeed 180
ZoomFactor.fromSpeed = 1.0;	--yawmovespeed 180 outSine 1.4 
ZoomFactor.SpeedFactor = 180 / tonumber(GetCVar("cameraYawMoveSpeed") or 180);
ZoomFactor.Goal = 2.5; --2.5 with dynamic pitch

local MogModeOffset = 0;
local ZoomValuebyRaceID = {
	--[raceID] = {ZoomValue Bust, factor1, factor2, ZoomValue for XmogMode},
	[0] = {[2] = {2.1, 0.361, -0.1654, 4},},		--Default Value

	[1] = {[2] = {2.1, 0.3283, -0.02, 4},		--1 Human √
		   [3] = {2.0, 0.38, 0.0311, 3.6}},

	[2] = {[2] = {2.4, 0.2667, -0.1233, 5.2},	--2 Orc √
		   [3] = {2.1, 0.3045, -0.0483, 5}},

	[3] = {[2] = {2.0, 0.2667, -0.0267, 3.6},	--3 Dwarf √
		   [3] = {1.8, 0.3533, -0.02, 3.6}},

	[4] = {[2] = {2.1, 0.30, -0.0404, 5},		--4 NE √
		   [3] = {2.1, 0.329, 0.025, 4.6}},

	[5] = {[2] = {2.1, 0.3537, -0.15, 4.2},		--5 UD √
		   [3] = {2.0, 0.3447, 0.03, 3.6}},

	[6] = {[2] = {4.5, 0.2027, -0.18, 5.5},		--6 Tauren Male √
		   [3] = {3.0, 0.2427, -0.1867, 5.5}},

	[7] = {[2] = {2.1, 0.329, 0.0517, 3.2},		--7 Gnome √
		   [3] = {2.1, 0.329, -0.012, 3.1}},

	[8] = {[2] = {2.1, 0.2787, 0.04, 5.2},		--8 Troll √
		   [3] = {2.1, 0.355, -0.1317, 5}},

	[9] = {[2] = {2.1, 0.2787, 0.04, 4.2},		--9 Goblin √
		   [3] = {2.1, 0.3144, -0.054, 4}},

	[10] = {[2] = {2.1, 0.361, -0.1654, 4},		--10 BloodElf Male √
		    [3] = {2.1, 0.3177, 0.0683, 3.8}},

	[11] = {[2] = {2.4, 0.248, -0.02, 5.5},		--11 Goat Male √
			[3] = {2.1, 0.3177, 0, 5}},
			
	[24] = {[2] = {2.5, 0.2233, -0.04, 5.2},		--24 Pandaren Male √
		    [3] = {2.5, 0.2433, 0.04, 5.2}},

	[27] = {[2] = {2.1, 0.3067, -0.02, 5.2},		--27 Nightborne √
		   [3] = {2.1, 0.3347, -0.0563, 4.7}},

	[28] = {[2] = {3.5, 0.2027, -0.18, 5.5},		--28 Tauren Male √
		   [3] = {2.3, 0.2293, 0.0067, 5.5}},

	[29] = {[2] = {2.1, 0.3556, -0.1038, 4.5},		--24 VE √
			[3] = {2.1, 0.3353, -0.02, 3.8}},

	[31] = {[2] = {2.3, 0.2387, -0.04, 5.5},		--32 Zandalari √
		   [3] = {2.1, 0.2733, -0.1243, 5.5}},

	[32] = {[2] = {2.3, 0.2387, 0.04, 5.2},			--32 Kul'Tiran √
		   [3] = {2.1, 0.312, -0.02, 4.7}},

	[35] = {[2] = {2.1, 0.31, -0.03, 3.1},			--35 Vulpera √
		   [3] = {2.1, 0.31, -0.03, 3.1}},	

	["Wolf"] = {[2] = {2.6, 0.2266, -0.02, 5},	--22 Worgen Wolf form √
		   	[3] = {2.1, 0.2613, -0.0133, 4.7}},
	
	["Druid"] = {[1] = {3.71, 0.2027, -0.02, 5},		--Cat
				 [5] = {4.8, 0.1707, -0.04, 5},			--Bear
				 [31] = {4.61, 0.1947, -0.02, 5},		--Moonkin
				 [4] = {4.61, 0.1307, -0.04, 5},		--Swim
				 [27] = {3.61, 0.1067, -0.02, 5},		--Fly Swift
				 [29] = {3.61, 0.1067, -0.02, 5},		--Fly
				 [3] = {4.91, 0.184, -0.02, 5},			--Travel Form
				 [36] = {4.2, 0.1707, -0.04, 5},		--Treant
				 [2] = {5.4, 0.1707, -0.04, 5},			--Tree of Life
				},

	["Mounted"] = {[2] = {8, 1.2495, -4, 5.5},
				   [3] = {8, 1.2495, -4, 5.5}},
	
	--1 	Human 32 Kultiran
	--2 	Orc
	--3 	Dwarf
	--4 	Night Elf
	--5 	Undead
	--6 	Tauren
	--7 	Gnome
	--8 	Troll
	--9 	Goblin
	--10 	Blood Elf
	--11 	Draenei
};

do --Classic: Redirect druid shapeshift ID
	local classicToModern = {
		[8] = 5,	--Dire Bear
		[32] = 31,	--Moonkin
		[33] = 31,	--Moonkin
		[34] = 31,	--Moonkin
		[35] = 31,	--Moonkin
	};

	for classicFormID, modernFormID in pairs(classicToModern) do
		ZoomValuebyRaceID["Druid"][classicFormID] = ZoomValuebyRaceID["Druid"][modernFormID]
	end
end


local _, _, PLAYER_RACE_ID = UnitRace("player")
local PLAYER_GENDER_ID = UnitSex("player")
local CAM_DISTANCE_INDEX = 1;
local ZOOM_IN_VALUE = ZoomValuebyRaceID[0][1];
local ZOOM_IN_VALUE_MOG = 3.8;
local SHOULDER_FACTOR_1 = ZoomValuebyRaceID[0][2];
local SHOULDER_FACTOR_2 = ZoomValuebyRaceID[0][3];

local CameraMover = {};
Narci.CameraMover = CameraMover;

local CameraUtil = {};

function CameraUtil:UpdateParametersDefault()
	local raceKey;
	if IsMounted() then
		raceKey = "Mounted";
	else
		raceKey = self:GetRaceKey();
	end

	ZOOM_IN_VALUE = ZoomValuebyRaceID[raceKey][PLAYER_GENDER_ID][CAM_DISTANCE_INDEX];
	SHOULDER_FACTOR_1 = ZoomValuebyRaceID[raceKey][PLAYER_GENDER_ID][2];
	SHOULDER_FACTOR_2 = ZoomValuebyRaceID[raceKey][PLAYER_GENDER_ID][3];
	ZOOM_IN_VALUE_MOG = ZoomValuebyRaceID[raceKey][PLAYER_GENDER_ID][4];
end

CameraUtil.UpdateParameters = CameraUtil.UpdateParametersDefault;

function CameraUtil:GetRaceKey()
	return PLAYER_RACE_ID
end

function CameraUtil:GetRaceKey_Worgen()
	local raceKey;
	local inAlternateForm = NarciClassicAPI.IsPlayerInAlteredForm();
	if inAlternateForm then
		--Human
		raceKey = 1;
	else
		raceKey = "Wolf";
	end
	return raceKey
end

function CameraUtil:GetRaceKey_Dracthyr()
	local raceKey;
	local inAlternateForm = NarciClassicAPI.IsPlayerInAlteredForm();
	if inAlternateForm then
		--Visage
		raceKey = 52;
	else
		raceKey = "Dracthyr";
	end
	return raceKey
end

function CameraUtil:UpdateParameters_Druid()
	local formID = GetShapeshiftFormID();

	if formID then
		if formID == 31 and GetCurrentGlyphNameForSpell then
			local _, glyphID = GetCurrentGlyphNameForSpell(24858);		--Moonkin form with Glyph of Stars use regular configuration
			if glyphID and glyphID == 114301 then
				self:UpdateParametersDefault();
				return
			end
		end

		local raceKey = "Druid";
		ZOOM_IN_VALUE = ZoomValuebyRaceID[raceKey][formID][CAM_DISTANCE_INDEX];
		SHOULDER_FACTOR_1 = ZoomValuebyRaceID[raceKey][formID][2];
		SHOULDER_FACTOR_2 = ZoomValuebyRaceID[raceKey][formID][3];
		ZOOM_IN_VALUE_MOG = ZoomValuebyRaceID[raceKey][formID][4];
	else
		self:UpdateParametersDefault();
	end
end


do
	if PLAYER_RACE_ID == 25 or PLAYER_RACE_ID == 26 then	--Pandaren A|H
		PLAYER_RACE_ID = 24;
	elseif PLAYER_RACE_ID == 30 then						--Lightforged
		PLAYER_RACE_ID = 11;
	elseif PLAYER_RACE_ID == 36 then						--Mag'har Orc
		PLAYER_RACE_ID = 2;
	elseif PLAYER_RACE_ID == 34 then						--DarkIron
		PLAYER_RACE_ID = 3;
	elseif PLAYER_RACE_ID == 37 then						--Mechagnome
		PLAYER_RACE_ID = 7;
	elseif PLAYER_RACE_ID == 22 then
		CameraUtil.GetRaceKey = CameraUtil.GetRaceKey_Worgen;
	elseif PLAYER_RACE_ID == 52 or PLAYER_RACE_ID == 70 then
		PLAYER_RACE_ID = 52;								--Dracthyr Horde -> Alliance
		CameraUtil.GetRaceKey = CameraUtil.GetRaceKey_Dracthyr;
	end

	local _, _, playerClassID = UnitClass("player");
	if playerClassID == 11 then
		CameraUtil.UpdateParameters = CameraUtil.UpdateParameters_Druid;
		table.insert(EL.dynamicEvents, "UPDATE_SHAPESHIFT_FORM");
	end
end

for raceKey, data in pairs(ZoomValuebyRaceID) do
	local id = tonumber(raceKey);
	if id and id > 1 and id ~= PLAYER_RACE_ID then
		ZoomValuebyRaceID[raceKey] = nil;
	end
end


function CameraUtil:OnPlayerFormChanged(pauseDuration)
	if not self.frame then
		self.frame = CreateFrame("Frame");
		self.frame:SetScript("OnUpdate", function(f, elapsed)
			f.t = f.t + elapsed;
			if f.t > 0 then
				f:Hide();
				self:UpdateParameters();
				CameraMover:OnCameraChanged();
			end
		end);
	end

	if not self.pauseUpdate then
		--self.pauseUpdate = true;
		pauseDuration = pauseDuration or 0;
		self.frame.t = -pauseDuration;
		self.frame:Show();
	end
end

local function GetShoulderOffsetByZoom(zoom)
	return zoom * SHOULDER_FACTOR_1 + SHOULDER_FACTOR_2 + MOG_MODE_OFFSET
end

local SmoothShoulder = CreateFrame("Frame");
SmoothShoulder.t = 0;
SmoothShoulder.duration = 1;
SmoothShoulder:Hide();

SmoothShoulder:SetScript("OnShow", function(self)
	self.fromPoint = GetCVar("test_cameraOverShoulder");
end);

local function SmoothShoulder_OnUpdate_ToValue(self, elapsed)
	self.t = self.t + elapsed;
	local value = outSine(self.t, self.fromPoint, self.toPoint, self.duration);

	if self.t >= self.duration then
		value = self.toPoint;
		self:Hide();
	end

	SetCVar("test_cameraOverShoulder", value);
end

SmoothShoulder:SetScript("OnHide", function(self)
	self.t = 0;
end);

local function SmoothShoulderCVar(toPoint, clampToZero)
	if not toPoint then
		return
	end
	if clampToZero then
		if toPoint < 0 then
			toPoint = 0;
		end
	end
	SmoothShoulder:SetScript("OnUpdate", SmoothShoulder_OnUpdate_ToValue);
	SmoothShoulder.t = 0;
	SmoothShoulder.toPoint = toPoint;
	SmoothShoulder.fromPoint = GetCVar("test_cameraOverShoulder");
	SmoothShoulder:Show();
end

local function SmoothShoulder_OnUpdate_UntilStable(self, elapsed)
	self.t = self.t + elapsed;

	if self.t >= 0.1 then
		local zoom = GetCameraZoom();
		if zoom ~= self.zoom then
			self.zoom = zoom;
			self.t = 0;
		else
			local value = GetShoulderOffsetByZoom(zoom);
			if value < 0 then
				value = 0;
			end
			SmoothShoulderCVar(value, true);
		end
	end
end

local UpdateShoulderCVar = {};
UpdateShoulderCVar.steps = 0;

function UpdateShoulderCVar:Start(increment)
	SmoothShoulder:SetScript("OnUpdate", SmoothShoulder_OnUpdate_UntilStable);
	SmoothShoulder.t = 0;
	SmoothShoulder:Show();
end

local DURATION_LOCK = 1.5;
local DURATION_TRANSLATION = 0.8;

function Narci_LeftLineAnimFrame_OnUpdate(self, elapsed)
	local toX = self.toX;
	local t = self.TimeSinceLastUpdate + elapsed;
	self.TimeSinceLastUpdate = t;
	local offsetX = outSine(t, toX - 120, toX , DURATION_TRANSLATION);	--outSine
	if t >= DURATION_TRANSLATION then
		offsetX = toX;
		self:Hide();
	end
	if not self.frame then
		self.frame = self:GetParent();
	end
	self.frame:SetPoint(self.anchorPoint, offsetX, 0);
end

function Narci_RightLineAnimFrame_OnUpdate(self, elapsed)
	local toX = self.toX;
	local t = self.TimeSinceLastUpdate + elapsed;
	self.TimeSinceLastUpdate = t;
	local offsetX = outSine(t, self.fromX, toX, DURATION_TRANSLATION);
	if t >= DURATION_TRANSLATION then
		offsetX = toX;
		self:Hide();
	end
	if not self.frame then
		self.frame = self:GetParent();
	end
	self.frame:SetPoint(self.anchorPoint, offsetX, 0);
end

--Views
local ViewProfile = {
	isEnabled = true,
};

function ViewProfile:Disable()
	self.isEnabled = false;
	--print("Dynamic Cam Enabled")
end

function ViewProfile:SaveView(index)
	if self.isEnabled then
		SaveView(index);
	end
end

function ViewProfile:ResetView(index)
	if self.isEnabled then
		ResetView(index);
	end
end

---Camera
--[[
hooksecurefunc("CameraZoomIn", function(increment)
	if IS_OPENED and (XMOG_MODE ~= 1) then
		UpdateShoulderCVar:Start(-increment);
	end
end)

hooksecurefunc("CameraZoomOut", function(increment)
	if IS_OPENED and (XMOG_MODE ~= 1)then
		UpdateShoulderCVar:Start(increment);
	end
end)
--]]



function CameraMover:ZoomIn(toPoint)
	local goal = toPoint or ZoomFactor.Goal;
	ZoomFactor.Current = GetCameraZoom();
	if ZoomFactor.Current >= goal then
		CameraZoomIn(ZoomFactor.Current - goal);
	else
		CameraZoomOut(-ZoomFactor.Current + goal);
	end
end

function CameraMover:OnCameraChanged()
	if not self.pauseUpdate then
		self.pauseUpdate = true;
		After(0.05, function()
			self:ZoomIn(ZOOM_IN_VALUE);
			self.pauseUpdate = nil;
		end);
	end
end

function CameraMover:SetBlend(enable)
	local divisor;
	if enable then
		--Smooth
		DURATION_LOCK = 1.5;
		DURATION_TRANSLATION = 0.8;
		divisor = 20;
	else
		--Instant
		DURATION_LOCK = 0.4;
		DURATION_TRANSLATION = 0.4;
		divisor = 80;
	end

	AttributeController:SetFadeInDelay(divisor)

	self.blend = enable;
end

CameraMover.smoothYaw = NarciAPI_CreateAnimationFrame(1.5);
CameraMover.smoothYaw.MoveView = MoveViewRightStart;

CameraMover.smoothYaw:SetScript("OnUpdate", function(frame, elapsed)
	frame.total = frame.total + elapsed;
	local factor = ZoomFactor;
	local speed = inOutSine(frame.total, factor.fromSpeed, factor.toSpeed, 1.5);	--inOutSine
	frame.MoveView(speed);
	
	if frame.total >= 1.5 then
		if not IsPlayerMoving() then
			frame.MoveView(factor.toSpeed);
		else
			MoveViewRightStop();
		end
		frame:Hide();
	end
end);

CameraMover.smoothPitch = NarciAPI_CreateAnimationFrame(1.5);
CameraMover.smoothPitch:SetScript("OnUpdate", function(frame, elapsed)
	frame.total = frame.total + elapsed
	--local x = frame.total;
	--local EndDistance = ZoomFactor.Goal;
	local PL = tostring(outSine(frame.total, 88,  1, frame.duration));	--outSine
	ConsoleExec( "pitchlimit "..PL)
	if frame.total >= frame.duration then
		ConsoleExec( "pitchlimit 1");
		After(0, function()
			ConsoleExec( "pitchlimit 88");
		end)
		frame:Hide();
	end
end);


function CameraMover:InstantZoomIn()
	SetCVar("cameraViewBlendStyle", 2);
	SetView(4);

	ConsoleExec( "pitchlimit 1");
	After(0, function()
		ConsoleExec( "pitchlimit 88");
	end)
	
	local zoom = ZOOM_IN_VALUE or GetCameraZoom();
	local shoulderOffset = zoom * SHOULDER_FACTOR_1 + SHOULDER_FACTOR_2 + MogModeOffset;
	SetCVar("test_cameraOverShoulder", shoulderOffset);		--CameraZoomIn(0.0)	--Smooth
	
	self:ZoomIn(ZOOM_IN_VALUE);
	
	self:ShowFrame();
	SetUIVisibility(false);
	if not IsPlayerMoving() and NarcissusDB.CameraOrbit then
		MoveViewRightStart(ZoomFactor.toSpeed);
	end
end

function CameraMover:HideUI()
	if UIParent:IsShown() then
		UIPA.endAlpha = 0;
		UIPA:Show();
	end

	After(0.5, function()
		SetUIVisibility(false); 		--Same as pressing Alt + Z
		After(0.3, function()
			UIParent:SetAlpha(1);
		end)
	end)
end

function CameraMover:Enter()
	SetCVar("test_cameraDynamicPitch", 1);

	if self.blend then
		if NarcissusDB.CameraOrbit and not IsPlayerMoving() then
			if NarcissusDB.CameraOrbit then
				self.smoothYaw:Show();
			end
			SetView(2);
		end

		if not IsFlying("player") then
			self.smoothPitch:Show();
		end
		
		After(0.1, function()
			self:ZoomIn(ZOOM_IN_VALUE);
			After(0.7, function()
				self:ShowFrame();
			end)
		end)

		self:HideUI();
	else
		if not self.hasInitialized then
			if NarcissusDB.CameraOrbit then
				self.smoothYaw:Show();
			end
			SetView(2);
			self.smoothPitch:Show();
			After(0.1, function()
				self:ZoomIn(ZOOM_IN_VALUE);
				After(0.7, function()
					self:ShowFrame();
				end)
			end)
			After(1, function()
				if not IsMounted() then
					self.hasInitialized = true;
					SaveView(1);
				end
			end)
			self:HideUI();
		else
			self:InstantZoomIn();
		end
	end
end

function CameraMover:Pitch()
	self.smoothPitch:Show();
end

function CameraMover:MakeActive()
	--Reserved for DynamicCam users
end

function CameraMover:MakeInactive()
	--Reserved for DynamicCam users
end

function CameraMover:UpdateMovementMethodForDynamicCam()
	if not self.handler then
		self.handler = CreateFrame("Frame");
	end

	local f = self.handler;
	f:Hide();
	f.t = 0;

	f:SetScript("OnUpdate", function(_, elapsed)
		f.t = f.t + elapsed;
		if f.t >= 0.2 then
			f.currentZoom = GetCameraZoom();
			if f.currentZoom ~= f.lastZoom then
				f.lastZoom = f.currentZoom;
				UpdateShoulderCVar:Start();
			end
		end
	end);

	function self:MakeActive()
		f.lastZoom = -1;
		f:Show();
	end

	function self:MakeInactive()
		f:Hide();
	end
end

------------------------------


local function ExitFunc()
	IS_OPENED = false;
	MOG_MODE_OFFSET = 0;
	EL:Hide();
	CameraMover:MakeInactive();
	MoveViewRightStop();
	if not GetKeepActionCam() then		--(not CVarTemp.isDynamicCamLoaded and CVarTemp.DynamicPitch == 0) or not Narci.keepActionCam
		SetCVar("test_cameraDynamicPitch", 0);								--Note: "test_cameraDynamicPitch" may cause camera to jitter while reseting the player's view
		SmoothShoulderCVar(0);
		After(1, function()
			ConsoleExec( "actioncam off" );
			MoveViewRightStop();
		end)
	else
		--Restore the acioncam state
		SmoothShoulderCVar(CVarTemp.OverShoulder);
		SetCVar("test_cameraDynamicPitch", CVarTemp.DynamicPitch);
		After(1, function()
			MoveViewRightStop();
		end)
	end

	ConsoleExec("pitchlimit 88");

	FadeFrame(Narci_Vignette, 0.5, 0);
	if Narci_Attribute:IsVisible() then
		Narci_Attribute.animOut:Play();
	end
	UIParent:SetAlpha(0);
	After(0.1, function()
		UIPA.startAlpha = 0;
		UIPA.endAlpha = 1;
		UIPA:Show();
		SetUIVisibility(true);
		--UIFrameFadeIn(UIParent, 0.5, 0, 1);	--cause frame rate drop
		Minimap:Show();
		local CameraFollowStyle = GetCVar("cameraSmoothStyle");
		if CameraFollowStyle == "0" and ViewProfile.isEnabled then		--workaround for auto-following
			SetView(5);
		else
			SetView(2);
			CameraMover:ZoomIn(CVarTemp.ZoomLevel);
		end
		SetCVar("cameraViewBlendStyle", CVarTemp.CameraViewBlendStyle);
	end);

	Narci.isActive = false;
	Narci.isAFK = false;

	DefaultTooltip:HideTooltip();
	MsgAlertContainer:Hide();

	UIErrorsFrame:Clear();

	Narci_ModelContainer:HideAndClearModel();
	Narci_ModelSettings:Hide();
	Narci_XmogNameFrame:Hide();
	NarciSettingsFrame:CloseUI();

	MOG_MODE = false;
end


--[[
local function SetDate()
	local CalendarTime = C_Calendar.GetDate();
	local hour = CalendarTime.hour;
	local minute = CalendarTime.minute;
	if minute < 10 then
		minute = "0"..tostring(minute)
	end
	Narci_Vignette.Time:SetText(hour..":"..minute)
	local zoneText = GetMinimapZoneText()
	Narci_Vignette.Location:SetText(zoneText)
end
--]]


function Narci:EmergencyStop()
	print("Camera has been reset.");
	UIParent:SetAlpha(1);
	MoveViewRightStop();
	MoveViewLeftStop();
	ViewProfile:ResetView(5);
	ConsoleExec( "pitchlimit 88");
	CVarTemp.OverShoulder = 0;
	SetCVar("test_cameraOverShoulder", 0);
	SetCVar("cameraViewBlendStyle", 1);
	ConsoleExec( "actioncam off" );
	Narci_ModelContainer:Hide();
	Narci_ModelSettings:Hide();
	Narci_Character:Hide();
	Narci_Attribute:Hide();
	Narci_Vignette:Hide();
	IS_OPENED = false;
	XMOG_MODE = 0;
	MogModeOffset = 0;
	NarciPlayerModelFrame1.XMOG_MODE = 0;
	EL:Hide();
end


---Get Transmog Appearance---
--[[
	==sourceInfo==
	sourceType					TRANSMOG_SOURCE_1 = "Boss Drop";
	invType						TRANSMOG_SOURCE_2 = "Quest";
	visualID					TRANSMOG_SOURCE_3 = "Vendor";
	isCollected					TRANSMOG_SOURCE_4 = "World Drop";
	sourceID					TRANSMOG_SOURCE_5 = "Achievement";
	isHideVisual				TRANSMOG_SOURCE_6 = "Profession";
	itemID
	itemModID					Normal 0, Heroic 1, Mythic 3, LFG 4
	categoryID
	name
	quality	
--]]

local xmogTable = {
	{1, INVTYPE_HEAD}, {3, INVTYPE_SHOULDER}, {15, INVTYPE_CLOAK}, {5, INVTYPE_CHEST}, {4, INVTYPE_BODY}, {19, INVTYPE_TABARD}, {9, INVTYPE_WRIST},		--Left 	**slotID for TABARD is 19
	{10, INVTYPE_HAND}, {6, INVTYPE_WAIST}, {7, INVTYPE_LEGS}, {8, INVTYPE_FEET},																		--Right
	{16, INVTYPE_WEAPONMAINHAND}, {17, INVTYPE_WEAPONOFFHAND},																							--Weapon
};

--[[
local function ShareHyperLink()																	--Send transmog hyperlink to chat
	local delay = 0;																			--Keep message in order
	print(MYMOG_GRADIENT)et
	for i=1, #xmogTable do
		local index =  xmogTable[i][1]
		if SLOT_TABLE[index] and SLOT_TABLE[index].hyperlink then			
			After(delay, function()
				SendChatMessage(xmogTable[i][2]..": "..slotTable[index].hyperlink, "GUILD")
			end)
			delay = delay + 0.1;
		end
	end
end
--]]

local GetInventoryItemCooldown = GetInventoryItemCooldown;

local function SetItemSocketingFramePosition(self)		--Let ItemSocketingFrame appear on the side of the slot
	if ItemSocketingFrame then																		
		if self.GemSlot:IsShown() then
			ItemSocketingFrame:Show()
		else
			ItemSocketingFrame:Hide()
			return;
		end
		ItemSocketingFrame:ClearAllPoints();
		if self.isRight then
			ItemSocketingFrame:SetPoint("TOPRIGHT", self, "TOPLEFT", 4, 0);
		else
			ItemSocketingFrame:SetPoint("TOPLEFT", self, "TOPRIGHT", -4, 0);
		end
		DefaultTooltip:HideTooltip();
	end
end

local IsItemEnchantable = {
	[11] = true,
	[12] = true,
	[16] = true,
	[17] = true,
	[5]  = true,

	[8] = true,
	[9] = true,
	[10] = true,
	[15] = true,
};

local function DisplayRuneSlot(equipmentSlot, slotID, itemQuality, itemLink)
	--! RuneSlot.Background is disabled
	if not equipmentSlot.RuneSlot then
		return;
	elseif (itemQuality == 0) or (not itemLink) then
		equipmentSlot.RuneSlot:Hide();
		return;
	end

	if IsItemEnchantable[slotID] then
		equipmentSlot.RuneSlot:Show();
	else
		equipmentSlot.RuneSlot:Hide();
		return;
	end

	local enchantID = GetItemEnchantID(itemLink);
	if enchantID ~= 0 then
		equipmentSlot.RuneSlot.RuneLetter:Show();
		if EnchantInfo[enchantID] then
			equipmentSlot.RuneSlot.RuneLetter:SetText( GetVerticalRunicLetters( EnchantInfo[enchantID][1] ) );
			equipmentSlot.RuneSlot.spellID = EnchantInfo[enchantID][3]
		end
	else
		equipmentSlot.RuneSlot.spellID = nil;
		equipmentSlot.RuneSlot.RuneLetter:Hide();
	end
end

function Narci_RuneButton_OnEnter(self)
	local spellID = self.spellID;
	if (not spellID) then
		return;
	end
	DefaultTooltip:SetOwner(self, "ANCHOR_NONE");
	if self:GetParent().isRight then
		DefaultTooltip:SetPoint("TOPRIGHT", self, "TOPLEFT", 8, 8);
	else
		DefaultTooltip:SetPoint("TOPLEFT", self, "TOPRIGHT", 0, 8);
	end
	DefaultTooltip:SetSpellByID(spellID);
	DefaultTooltip:Show();
	DefaultTooltip:FadeIn();
end

----------------------------------------------------------
--Show a list of compatible ammo when clicking the ammo slot

local AmmoProvider = {};

AmmoProvider.GetItemCount = GetItemCount;

function AmmoProvider:WrapAmmoCountInColor(itemCount)
	if itemCount > 9999 then
		itemCount = "|cffffffff".."9999+".."|r";
	elseif itemCount <= 50 then
		itemCount = "|cffff0000"..itemCount.."|r"
	elseif itemCount <= 200 then
		itemCount = "|cffffD100"..itemCount.."|r"
	end
	return itemCount
end

function AmmoProvider:CreateFlyout(slotButton, ammos, currentAmmo)
	if not self.flyout then
		self.buttons = {};

		self.flyout = CreateFrame("Frame", nil, slotButton);
		local flyout = self.flyout;
		flyout:Hide();
		flyout:SetPoint("BOTTOMLEFT", slotButton, "TOPRIGHT", 0, 4);
		flyout:SetSize(248, 24);
		flyout.Background = flyout:CreateTexture(nil, "BACKGROUND");
		flyout.Background:SetColorTexture(0.1, 0.1, 0.1);
		flyout.Background:SetPoint("TOPLEFT", flyout, "TOPLEFT", 0, 0);
		flyout.Background:SetPoint("BOTTOMRIGHT", flyout, "BOTTOMRIGHT", 0, 0);

		NarciAPI.NineSliceUtil.SetUpBackdrop(flyout, "shadowHugeR0", 1);

		local function FlyOut_OnShow(f)
			f:RegisterEvent("GLOBAL_MOUSE_DOWN");
			f:RegisterEvent("MODIFIER_STATE_CHANGED");
		end
		local function FlyOut_OnHide(f)
			f:UnregisterEvent("GLOBAL_MOUSE_DOWN");
			f:UnregisterEvent("MODIFIER_STATE_CHANGED");
			f:Hide();
		end
		local function FlyOut_OnEvent(f, event, ...)
			if event == "GLOBAL_MOUSE_DOWN" then
				if not (f:IsMouseOver() or (self.parentSlot and self.parentSlot:IsMouseOver(12, -12, -12, 48)) ) then
					self:HideAvailableAmmos();
				end
			elseif ( event == "MODIFIER_STATE_CHANGED" ) then
				local key, state = ...;
				if ( key == "LALT" ) and state == 0 then
					self:HideAvailableAmmos();
				end
			end
		end
		flyout:SetScript("OnShow", FlyOut_OnShow);
		flyout:SetScript("OnHide", FlyOut_OnHide);
		flyout:SetScript("OnEvent", FlyOut_OnEvent);
	end

	if ammos then
		local total = #ammos;
		total = (total > 1) and total or 1;

		local button;

		for i = 1, total do
			button = self.buttons[i];

			if not button then
				self.buttons[i] = CreateFrame("Button", nil, self.flyout, "NarciAmmoFlyoutButtonTemplate");
				button = self.buttons[i];
				button.id = i;
				button:SetPoint("TOPLEFT", self.flyout, "TOPLEFT", 4, 28*(1 - i) -4);
			end


			button:SetItem(ammos[i], ammos[i] == currentAmmo);
			button:Show();
		end

		for i = total + 1, #self.buttons do
			self.buttons[i]:Hide();
		end

		self.flyout:SetHeight(28 * total + 4);
		self.flyout:Show();
	else
		self.flyout:SetHeight(32);
		self.flyout:Hide();
	end
end

function AmmoProvider:ShowAvailableAmmos(slotButton)
	local includeEquippedAmmo = true;
	local ammos, currentAmmo = NarciClassicAPI.GetOwnedAmmo(includeEquippedAmmo);
	self:CreateFlyout(slotButton, ammos, currentAmmo);
	self.parentSlot = slotButton;
	EquipmentFlyoutFrame.parentButton = slotButton;

	local blackscreenLevel = FlyoutBlackScreen:GetFrameLevel();
	slotButton:SetFrameLevel(blackscreenLevel + 1);

	FlyoutBlackScreen:In();
	NarciGameTooltip:HideTooltip();
end

function AmmoProvider:HideAvailableAmmos()
	if self.flyout and self.flyout:IsShown() then
		self.flyout:Hide();
		self.parentSlot = nil;
		FlyoutBlackScreen:Out();
	end
end

function AmmoProvider:ToggleAvailableAmmos(slotButton)
	if self.flyout and self.flyout:IsShown() then
		self:HideAvailableAmmos();
	else
		self:ShowAvailableAmmos(slotButton);
	end
end

function AmmoProvider:UpdateFlyout()
	if self.parentSlot and self.flyout and self.flyout:IsShown() then
		self:ShowAvailableAmmos(self.parentSlot);
	end
end



NarciAmmoFlyoutButtonMixin = {};

function NarciAmmoFlyoutButtonMixin:OnClick()
	if self.itemID then
		NarciAPI.PickUpItemByItemID(self.itemID);
		if CursorHasItem() then
			PickupInventoryItem(18);
		end
		ClearCursor();
	end
end

function NarciAmmoFlyoutButtonMixin:OnMouseDown()
	if self.equipped then return end;

	self.pushed = true;
	self:SetPoint("TOPLEFT", AmmoProvider.flyout, "TOPLEFT", 5, 28*(1 - self.id) -4);
end

function NarciAmmoFlyoutButtonMixin:OnMouseUp()
	self.pushed = nil;
	self:SetPoint("TOPLEFT", AmmoProvider.flyout, "TOPLEFT", 4, 28*(1 - self.id) -4);
end

function NarciAmmoFlyoutButtonMixin:OnEnter()
	self.Highlight:Show();
	if self.itemID then
		local tooltip = NarciGameTooltip;
		tooltip:HideTooltip();
		tooltip:SetOwner(AmmoProvider.flyout, "ANCHOR_NONE");
		tooltip:SetPoint("BOTTOMLEFT", AmmoProvider.flyout, "TOPLEFT", 8, 12);
		tooltip:SetItemByID(self.itemID);
		tooltip:Show();
		tooltip:FadeIn();
	end
end

function NarciAmmoFlyoutButtonMixin:OnLeave()
	self.Highlight:Hide();
	NarciGameTooltip:HideTooltip();
end

function NarciAmmoFlyoutButtonMixin:SetItem(itemID, equipped)
	self.itemID = itemID;
	self.equipped = equipped;

	if itemID then
		local count = AmmoProvider.GetItemCount(itemID);
		count = AmmoProvider:WrapAmmoCountInColor(count);
		self.ItemCount:SetText(count);

		local itemName, itemLink, itemQuality, itemLevel, _, _, _,_, _, icon = GetItemInfo(itemID);

		if equipped and itemName then
			itemName = itemName.. "|TInterface\\AddOns\\Narcissus\\Art\\Modules\\EquipmentSetManager\\EquippedMarker:24:24|t";
		end

		self.Name:SetText(itemName);
		self.Icon:SetTexture(icon);

		if itemQuality then
			local r, g, b = GetItemQualityColor(itemQuality);
			self.Name:SetTextColor(r, g, b);
		end

		local dps = NarciAPI.GetAmmoDps(itemID);
		if dps > 0 then
			self.DamageText:SetText(dps);
		else
			self.DamageText:SetText("");
		end
	else
		self.Name:SetText(L["Ammo Slot No Alternative"]);
		self.Name:SetTextColor(0.5, 0.5, 0.5);
		self.Icon:SetTexture(nil);
		self.DamageText:SetText("");
	end

	if equipped then
		self.DamageText:SetTextColor(1, 1, 1);
	else
		self.DamageText:SetTextColor(0.67, 0.67, 0.67);
	end
end

function NarciAmmoFlyoutButtonMixin:OnHide()
	self.itemID = nil;
	if self.pushed then
		self:OnMouseUp();
	end
end




----------------------------------------------------------

NarciItemButtonSharedMixin = {};

function NarciItemButtonSharedMixin:RegisterErrorEvent()
	self:RegisterEvent("UI_ERROR_MESSAGE");
end

function NarciItemButtonSharedMixin:UnregisterErrorEvent()
	self:UnregisterEvent("UI_ERROR_MESSAGE");
end

function NarciItemButtonSharedMixin:OnErrorMessage(...)
	self:UnregisterErrorEvent();
	local _, msg = ...
	Narci_AlertFrame_Autohide:AddMessage(msg, true);
end

function NarciItemButtonSharedMixin:AnchorAlertFrame()
	self:RegisterErrorEvent();
	Narci_AlertFrame_Autohide:SetAnchor(self, -24, true);
end

function NarciItemButtonSharedMixin:PlayGamePadAnimation()
	if self.gamepad then
		self.Icon.ScaleUp:Play();
		self.IconMask.ScaleUp:Play();
		self.Border.ScaleUp:Play();
		self.Border.BorderMask.ScaleUp:Play();
	end
end

function NarciItemButtonSharedMixin:ResetAnimation()
	if self.gamepad then
		self.Icon.ScaleUp:Stop();
		self.Border.ScaleUp:Stop();
		self.Border.BorderMask.ScaleUp:Stop();
		self.IconMask.ScaleUp:Stop();
		self.Icon:SetScale(1);
		self.Border:SetScale(1);
		self.IconMask:SetScale(1);
		self.Border.BorderMask:SetScale(1);
		if self.gamepadOverlay then
			self.gamepadOverlay:Hide();
			self.gamepadOverlay = nil;
		end
	end
end

function NarciItemButtonSharedMixin:SetBorderTexture(border, texKey)
	SetBorderTexture(border, texKey, 2);
end

function NarciItemButtonSharedMixin:ShowAlphaChannel()
	self.itemLink = nil;
	self.Icon:SetColorTexture(1, 1, 1);
	self.Border:SetColorTexture(1, 1, 1);
	self.Border.textureKey = -1;
end

-----------------------------------------------------------------------
local validForTempEnchant = {
	[16] = true,
	[17] = true,
	[5] = true,
	[0] = true,
};

NarciEquipmentSlotMixin = CreateFromMixins{NarciItemButtonSharedMixin};

function NarciEquipmentSlotMixin:Refresh(forceRefresh)
	local _;
	local slotID = self.slotID;
	local itemLocation = ItemLocation:CreateFromEquipmentSlot(slotID);
	--print(slotName..slotID)
	--local texture = CharacterHeadSlot.popoutButton.icon:GetTexture()
	local itemLink;
	local itemIcon, itemName, itemQuality, effectiveLvl, gemName, gemLink, gemID;
	local borderTexKey;

	local bR, bG, bB;		--Item Name Color
	if C_Item.DoesItemExist(itemLocation) then
		if CAN_MOG and MOG_MODE then
			self:UntrackCooldown();
			self:UntrackTempEnchant();
			self:HideVFX();
			self.itemLink = nil;
			self.isSlotHidden = false;	--Undress an item from player model
			self.RuneSlot:Hide();
			self.GradientBackground:Show();
			local appliedSourceID, appliedVisualID, hasSecondaryAppearance = NarciClassicAPI.GetSlotVisualID(slotID);
			self.sourceID = appliedSourceID;

			if appliedVisualID > 0 then
				local sourceInfo = C_TransmogCollection.GetSourceInfo(appliedSourceID);
				itemName = sourceInfo and sourceInfo.name;
				if not itemName or itemName == "" then
					QueueFrame:Add(self, self.Refresh);
					return
				end
				self.itemID = sourceInfo.itemID;
				itemQuality = sourceInfo.quality;
				self.itemModID = sourceInfo.itemModID;
				itemIcon = C_TransmogCollection.GetSourceIcon(appliedSourceID);

				effectiveLvl = TransmogDataProvider:GetSpecialItemSourceText(appliedSourceID, self.itemID, self.itemModID);

				if effectiveLvl then
					self.sourcePlainText = NarciAPI.RemoveColorString(effectiveLvl);
					_, _, self.hyperlink = TransmogDataProvider:GetFormattedSourceText(sourceInfo);
				else
					effectiveLvl, self.sourcePlainText, self.hyperlink = TransmogDataProvider:GetFormattedSourceText(sourceInfo);
				end

				if self.hyperlink then
					_, self.hyperlink = GetItemInfo(self.hyperlink);																		--original hyperlink cannot be printed (workaround)
				end

				local bonusID;
				if itemQuality == 6 then
					if slotID == 16 then
						bonusID = (sourceInfo.itemModID or 0);	--Artifact use itemModID "7V0" + modID - 1
					else
						bonusID = 0;
					end
				end
				self.bonusID = bonusID;

				if effectiveLvl == nil then
					effectiveLvl = TransmogDataProvider:GetSpecialItemSourceText(appliedSourceID, self.itemID, self.itemModID) or " ";
				end


			else	--irrelevant slot
				itemName = " ";
				itemQuality = 0;
				itemIcon = GetInventoryItemTexture("player", slotID);
				self.Icon:SetDesaturated(true);
				self.Name:Hide();
				self.ItemLevel:Hide();
				self.GradientBackground:Hide();
				self.bonusID = nil;
			end
			self:DisplayDirectionMark(hasSecondaryAppearance, itemQuality);
		else
			self:TrackCooldown();
			self:DisplayDirectionMark(false);
			self.Icon:SetDesaturated(false)
			self.Name:Show();
			self.ItemLevel:Show();
			self.GradientBackground:Show();
			self.hyperlink = nil;
			self.sourcePlainText = nil;
			--[[
			local current, maximum = GetInventoryItemDurability(slotID);
			if current and maximum then
				self.durability = (current / maximum);
			end
			--]]
			itemLink = C_Item.GetItemLink(itemLocation);
			
			if validForTempEnchant[slotID] then
				local hasTempEnchant = NarciTempEnchantIndicatorController:InitFromSlotButton(self);
				if hasTempEnchant ~= self.hasTempEnchant then
					self.hasTempEnchant = hasTempEnchant;
				else
					if itemLink == self.itemLink then
						return
					end
				end
			else
				if itemLink == self.itemLink and (slotID ~= 18 and slotID ~= 0) then
					return
				end
			end
			
			local itemVFX;
			local itemID = GetItemInfoInstant(itemLink);
			borderTexKey, itemVFX, bR, bG, bB = GetBorderArtByItemID(itemID);

			itemIcon = GetInventoryItemTexture("player", slotID);
			itemName = C_Item.GetItemName(itemLocation);
			itemQuality = C_Item.GetItemQuality(itemLocation);
			effectiveLvl = C_Item.GetCurrentItemLevel(itemLocation);
			self.ItemLevelCenter.ItemLevel:SetText(effectiveLvl);

			gemName, gemLink = IsItemSocketable(itemLink);

			self.GemSlot.ItemLevel = effectiveLvl;
			self.gemLink = gemLink;		--Later used in OnEnter func in NarciSocketing.lua

			local enchantText = GetEnchantTextByItemLink(itemLink, true);	--GetItemEnchantText(itemLink, true);
			local engravingName = EngravingSlotUtil:UpdateSlotButton(self);	--Engraving has itemEnchantmentID but not shown in the itemlink

			if engravingName then
				if enchantText then
					enchantText = engravingName.."  "..enchantText;
				else
					enchantText = engravingName;
				end
			end

			if enchantText then
				if self.isRight then
					effectiveLvl = enchantText.."  "..effectiveLvl;
				else
					effectiveLvl = effectiveLvl.."  "..enchantText;
				end
			end

			--Enchant Frame--
			if itemQuality then	--and not isRuneforgeLegendary
				DisplayRuneSlot(self, slotID, itemQuality, itemLink);
			end

			--Item Visual Effects
			if itemVFX then
				self:ShowVFX(itemVFX);
			else
				self:HideVFX();
			end

			if not itemName or itemName == "" then
				QueueFrame:Add(self, self.Refresh);
				return
			end

			--Thrown weapon count
			if slotID == 18 then
				local classID, subclassID = select(6, GetItemInfoInstant(itemID));
				if classID == 2 and subclassID == 16 then
					local quantity = GetItemCount(itemID);
					if quantity <= 50 then
						quantity = "|cffff0000x"..quantity.."|r";
					elseif quantity <= 100 then
						quantity = "|cffffD100x"..quantity.."|r";
					else
						quantity = "x"..quantity;
					end
					effectiveLvl = effectiveLvl.."  "..quantity;
				end
			end

			self.itemLink = itemLink;
		end
	else
		self:UntrackCooldown();
		self:UntrackTempEnchant();
		self:HideVFX();
		self:DisplayDirectionMark(false);
		self.GradientBackground:Hide();
		self.Icon:SetDesaturated(false);
		self.ItemLevelCenter.ItemLevel:SetText("");
		self.itemID = nil;
		self.bonusID = nil;
		self.itemLink = nil;
		self.gemLink = nil;
		itemQuality = 0;
		itemIcon = self.emptyTexture;
		itemName = " " ;
		effectiveLvl = "";
		DisplayRuneSlot(self, slotID, 0);

		EngravingSlotUtil:HideEngraving(self);
	end

	self.itemQuality = itemQuality;

	if itemQuality and not bR then --itemQuality sometimes return nil. This is a temporary solution
		bR, bG, bB = GetItemQualityColor(itemQuality);
		if not borderTexKey then
			borderTexKey = itemQuality;
		end
	end
	bR = bR or 1;
	bG = bG or 1;
	bB = bB or 1;

	--Gem Slot--
	if gemName ~= nil then
		local gemBorder, gemIcon, itemSubClassID;

		if gemLink then
			gemID, _, _, _, gemIcon, _, itemSubClassID = GetItemInfoInstant(gemLink);
			gemBorder = GetGemBorderTexture(itemSubClassID, gemID);
		else
			gemBorder = GetGemBorderTexture(nil);
		end

		self.GemSlot.GemBorder:SetTexture(gemBorder);
		self.GemSlot.GemIcon:SetTexture(gemIcon);
		self.GemSlot.GemIcon:Show();
		self.GemSlot.sockedGemItemID = gemID;
		if self:IsVisible() then
			self.GemSlot:FadeIn();
		else
			self.GemSlot:ShowSlot();
		end
	else
		if self:IsVisible() then
			self.GemSlot:FadeOut();
		else
			self.GemSlot:HideSlot();
		end
		self.GemSlot.sockedGemItemID = nil;
	end

	--if slotID == 13 then itemName = "The Lion\'s Roar"; end	--Antumbra, Shadow of the Cosmos
	--------------------------------------------------
	if self:IsVisible() then
		self:SetBorderTexture(self.Border, borderTexKey);
		if itemIcon then
			self.IconOverlay:SetTexture(itemIcon);
			self.Icon.anim:Play();
		end
		self.ItemLevel.anim1:SetScript("OnFinished", function()
			self.ItemLevel:SetText(effectiveLvl);
			self.ItemLevel.anim2:Play();
		end)
		self.Name.anim1:SetScript("OnFinished", function()
			self.Name:SetText(itemName);
			self.Name:SetTextColor(bR, bG, bB);
			self.Name.anim2:Play();
			After(0, function()
				self:UpdateGradientSize();
			end)
		end)
		self.ItemLevel.anim1:Play();
		self.Name.anim1:Play();
	else
		self.ItemLevel:SetText(effectiveLvl);
		self.Name:SetText(itemName);
		self.Name:SetTextColor(bR, bG, bB);
		self:SetBorderTexture(self.Border, borderTexKey);
		if itemIcon then
			self.Icon:SetTexture(itemIcon);
		end
		self:UpdateGradientSize();
	end
	--self.GradientBackground:SetHeight(self.Name:GetHeight() + self.ItemLevel:GetHeight() + 18);
	self.itemNameColor = {bR, bG, bB};

	return true
end

function NarciEquipmentSlotMixin:UpdateGradientSize()
	local text2Width = self.ItemLevel:GetWrappedWidth();
	local extraWidth;
	if self.TempEnchantIndicator then
		extraWidth = 48;
		self.TempEnchantIndicator:ClearAllPoints();
		if self.isRight then
			self.TempEnchantIndicator:SetPoint("TOPRIGHT", self.ItemLevel, "TOPRIGHT", -text2Width - 6, 0);
		else
			local extraOffset;
			if self.ItemLevel:IsTruncated() then
				text2Width = self.ItemLevel:GetWidth();
			end
			self.TempEnchantIndicator:SetPoint("TOPLEFT", self.ItemLevel, "TOPLEFT", text2Width + 6, 0);
		end
	else
		extraWidth = 0;
	end
	self.GradientBackground:SetHeight(self.Name:GetHeight() + self.ItemLevel:GetHeight() + 18);
	self.GradientBackground:SetWidth(max(self.Name:GetWrappedWidth(), text2Width + extraWidth, 48) + 48);
end



local AmmoSlotMixin = {};

function AmmoSlotMixin:Refresh()
	if NarciClassicAPI.DoesRangedWeaponRequireAmmo() then
		self:Show();
	else
		self:Hide();
		return
	end

	local itemID, itemName, itemLink, itemQuality, itemCount, itemLevel;
	local nameR, nameG, nameB;
	local itemIcon = GetInventoryItemTexture("player", 0);

	if itemIcon then
		itemID = GetInventoryItemID("player", 0);		--GetInventoryItemLink return nil for ammo
		itemName, itemLink, itemQuality, itemLevel = GetItemInfo(itemID);
		itemCount = GetInventoryItemCount("player", 0);

		itemCount = AmmoProvider:WrapAmmoCountInColor(itemCount);
	else
		itemName = SPELL_FAILED_NO_AMMO;
		itemIcon = 136520;	--ranged slot texture
		itemQuality = 0;
		itemCount = "";
		nameR, nameG, nameB = 1, 0, 0;
	end

	local isAmmoMatched, bestAmmoItemID = NarciClassicAPI.IsAmmoMatched(true);

	if (not isAmmoMatched) and IS_OPENED then
		if bestAmmoItemID then
			--Try to auto equip ammo if the ammo type is incompatible with the current ranged weapon
			nameR, nameG, nameB = 0.5, 0.5, 0.5;
			itemName = L["Item Switching In Progress"];
			itemCount = "";
			After(0.1, function()
				if not InCombatLockdown() then
					NarciAPI.PickUpItemByItemID(bestAmmoItemID);
					if CursorHasItem() then
						PickupInventoryItem(18);
					end
					ClearCursor();
				end
			end);
		else
			nameR, nameG, nameB = 1, 0, 0;
		end
	end

	if not nameR then
		nameR, nameG, nameB = GetItemQualityColor(itemQuality);
	end

	self.Name:SetText(itemName);
	self.Name:SetTextColor(nameR, nameG, nameB);

	self.ItemLevel:SetText(itemCount);

	self.Icon:SetTexture(itemIcon);
	self:SetBorderTexture(self.Border, itemQuality);
	self:UpgradeGradientSize();
end

function AmmoSlotMixin:UpgradeGradientSize()
	self.GradientBackground:SetWidth(max(self.Name:GetWrappedWidth(), 48) + 48);
end

local function AmmoSlotMixin_PostClick(self, button)
	if self.equipped or MOG_MODE then return end;

	if button == "LeftButton" then
		AmmoProvider:ToggleAvailableAmmos(self);
	end
end




function NarciEquipmentSlotMixin:OnLoad()
	local slotName = self.slotName;
	local slotID, textureName = GetInventorySlotInfo(slotName);
	self.emptyTexture = textureName;
	self:SetID(slotID);
	self.slotID = slotID;
	self:SetAttribute("type2", "item");
	self:SetAttribute("item", slotID);
	self:RegisterForDrag("LeftButton");
	self:RegisterForClicks("LeftButtonUp", "RightButtonDown", "RightButtonUp");
	if self:GetParent() then
		if not self:GetParent().slotTable then
			self:GetParent().slotTable = {}
		end
		tinsert(self:GetParent().slotTable, self);
	end
	SLOT_TABLE[slotID] = self;

	self:SetScript("OnLoad", nil);
	self.OnLoad = nil;

	if slotID == 0 then
		for k, v in pairs(AmmoSlotMixin) do
			self[k] = v;
		end
		self:SetScript("PostClick", AmmoSlotMixin_PostClick);
		self:SetHitRectInsets(-4, -48, 0, -4);
	end
end

function NarciEquipmentSlotMixin:OnEvent(event, ...)
	if event == "MODIFIER_STATE_CHANGED" then
		local key, state = ...;
		if ( key == "LALT" and self:IsMouseOver() ) then
			local flyout = EquipmentFlyoutFrame;
			if state == 1 then
				if flyout:IsShown() and flyout.slotID == self:GetID() then
					flyout:Hide();
				else
					flyout:SetItemSlot(self, true);
				end
			else

			end
		end
	elseif event == "UI_ERROR_MESSAGE" then
		self:OnErrorMessage(...);
	end
end

function NarciEquipmentSlotMixin:UntrackCooldown()
	if self.CooldownFrame then
		self.CooldownFrame:Clear();
		self.CooldownFrame = nil;
	end
end

function NarciEquipmentSlotMixin:TrackCooldown()
	local start, duration, enable = GetInventoryItemCooldown("player", self:GetID());
	if enable and enable ~= 0 and start > 0 and duration > 0 then
		if not self.CooldownFrame then
			self.CooldownFrame = NarciItemCooldownUtil.AccquireFrame(self);
		end
		self.CooldownFrame:SetCooldown(start, duration);
		return true
	else
		self:UntrackCooldown();
	end
	return false
end

function NarciEquipmentSlotMixin:UntrackTempEnchant()
	if self.TempEnchantIndicator then
		self.TempEnchantIndicator:Hide();
		self.TempEnchantIndicator = nil;
	end
end

function NarciEquipmentSlotMixin:OnEnter(motion, isGamepad)
	self:RegisterEvent("MODIFIER_STATE_CHANGED");

	if isGamepad then
		self:PlayGamePadAnimation();
	else
		FadeFrame(self.Highlight, 0.15, 1);
	end

	if IsAltKeyDown() and not MOG_MODE then
		EquipmentFlyoutFrame:SetItemSlot(self, true);
	end

	if EquipmentFlyoutFrame:IsShown() then
		Narci_Comparison_SetComparison(EquipmentFlyoutFrame.BaseItem, self);
		return;
	end

	ItemTooltip:SetFromSlotButton(self, -2, 6, isGamepad and 0.4);	--delay 0.4s
end

function NarciEquipmentSlotMixin:OnLeave()
	self:UnregisterEvent("MODIFIER_STATE_CHANGED");
	self:UnregisterErrorEvent();
	FadeFrame(self.Highlight, 0.25, 0);
	Narci:HideButtonTooltip();
	self:ResetAnimation();
end

function NarciEquipmentSlotMixin:OnHide()
	self.Highlight:Hide();
	self.Highlight:SetAlpha(0);
	self:ResetAnimation();
end

function NarciEquipmentSlotMixin:PostClick(button)
	if CursorHasItem() then
		EquipCursorItem(self:GetID());
		return
	end

	ClearCursor();
	if ( IsModifiedClick() ) then
		if IsAltKeyDown() and button == "LeftButton" then
			local action = EquipmentManagerAPI.UnequipItemInSlot(self:GetID())
			if action then
				EquipmentManagerAPI.RunAction(action)
			end
			return;
		elseif IsShiftKeyDown() and button == "LeftButton" then
			if self.hyperlink then
				SendChatMessage(self.hyperlink)
			end
			--ShareHyperLink()
		else
			PaperDollItemSlotButton_OnModifiedClick(self, button);
			TakeOutFrames(true);
			SetItemSocketingFramePosition(self);
		end
	else
		if button == "LeftButton" then
			if not MOG_MODE then	--Undress an item from player model while in Xmog Mode
				--EquipmentFlyoutFrame:SetItemSlot(self);
				Narci_EquipmentOption:SetFromSlotButton(self, true)
			end
		elseif button == "RightButton" then
			self:AnchorAlertFrame();
		end
	end
end

function NarciEquipmentSlotMixin:OnDragStart()
	local itemLocation = ItemLocation:CreateFromEquipmentSlot(self:GetID())
	if C_Item.DoesItemExist(itemLocation) then
		C_Item.UnlockItem(itemLocation);
		PickupInventoryItem(self:GetID());
	end
end

function NarciEquipmentSlotMixin:OnReceiveDrag()
	PickupInventoryItem(self:GetID());	--In fact, attemp to equip cursor item
end

function NarciEquipmentSlotMixin:DisplayDirectionMark(visible, itemQuality)
	if self.slotID == 2 or self.slotID == 3 then
		if visible then
			if not self.DirectionMark then
				self.DirectionMark = CreateFrame("Frame", nil, self, "NarciTransmogSlotDirectionMarkTemplate");
				self.DirectionMark:SetPoint("RIGHT", self, "LEFT", 9, 0);
				self.DirectionMark:SetDirection(self.slotID - 1);
			end
			FadeFrame(self.DirectionMark, 0.25, 1);
			if itemQuality then
				self.DirectionMark:SetQualityColor(itemQuality);
			end
		else
			if self.DirectionMark then
				self.DirectionMark:Hide();
				self.DirectionMark:SetAlpha(0);
			end
		end
	end
end

function NarciEquipmentSlotMixin:ShowVFX(effectName)
	if effectName then
		if self.VFX then
			self.VFX:SetUpByName(effectName);
		else
			self.VFX = NarciItemVFXContainer:AcquireAndSetModelScene(self, effectName);
		end
	else
		self:HideVFX();
	end
end

function NarciEquipmentSlotMixin:HideVFX()
	if self.VFX then
		self.VFX:Remove();
	end
end


--/dump GetItemStats(GetInventoryItemLink("player", 8))
--/script DEFAULT_CHAT_FRAME:AddMessage("\124cff0070dd\124Hitem:152783::::::::120::::1:1672:\124h[Mac'Aree Focusing Amethyst]\124h\124r");
--/script DEFAULT_CHAT_FRAME:AddMessage("\124cff0070dd\124Hitem:152783::::::::120::::1:1657:\124h[Mac'Aree Focusing Amethyst]\124h\124r");
--/script DEFAULT_CHAT_FRAME:AddMessage("\124cff0070dd\124Hitem:158362::::::::120::::2:1557:4778:\124h[Lord Waycrest's Signet]\124h\124r");
--[[				 Stats sum						ilvl							ilvl+ from Gem
	Ring		1.7626*ilvl - 246.88		(sum + 246.88) / 1.7626				40  / 1.7626 = 22.6937
--]]



function NarciItemLevelFrameMixin:OnLoad()
	--Declared in Modules\CharacterFrame\ItemLevelFrame.lua
	ItemLevelFrame = self;

	local LeftButton = self.LeftButton;
	LeftButton:SetScript("OnEnter", function(f)
		if f.isSameLevel then
			f.tooltipHeadline = format(f.tooltipFormat, f.Level:GetText());
		else
			f.tooltipHeadline = format(f.tooltipFormat, f.Level:GetText()) .. format("  (max %s)", f.avgItemLevel);
		end
		if f.avgItemLevelPvp and f.avgItemLevelPvp ~= 0 then
			f.tooltipSpecial = format(STAT_AVERAGE_PVP_ITEM_LEVEL, f.avgItemLevelPvp);
		else
			f.tooltipSpecial = nil;
		end
		Narci_ShowButtonTooltip(f);
		FadeFrame(f.Highlight, 0.15, 1);
	end);

	local themeName = "hardcore";
	self:SetThemeByName(themeName);
end


local PlayTimeUtil = {};	--Effecive only in Hardcore

function PlayTimeUtil:SetBasePlayTime(basePlayTime)
	--Only request play time once at the start of the session
	self.basePlayTime = basePlayTime;
	self.fromTime = time();
end

function PlayTimeUtil:Format(time)
    local hours = math.floor(time / 3600);
	local minutes = math.floor((time - hours * 3600) / 60);
	--local seconds = math.fmod(time, 60);

    local text;

    if hours > 0 then
        text = string.format(HOURS_ABBR, hours);
		if hours >= 24 then
			return text
		end
    end

    if minutes > 0 then
        local mText = string.format(MINUTES_ABBR, minutes);
        if text then
            text = text .. " "..mText;
        else
            text = mText;
        end
    end

    return text
end

function PlayTimeUtil:GetTimeString()
	if self.basePlayTime then
		local currentTime = time();
		local playTime = self.basePlayTime + currentTime - self.fromTime;
		return self:Format(playTime);
	end
end


local function UpdateCharacterInfoFrame(newLevel)
	local level = newLevel or UnitLevel("player");

	local className, englishClass = UnitClass("player");
	local _, _, _, rgbHex = GetClassColor(englishClass);

	local currentSpecName, talentTabName, pointsSpent;
	local maxPoints = 0;

	for i = 1, GetNumTalentTabs() do
		talentTabName, _, pointsSpent = NarciClassicAPI.GetTalentTabNameAndPoints(i);
		if pointsSpent and pointsSpent > maxPoints then
			maxPoints = pointsSpent;
			currentSpecName = talentTabName;
		end
	end

	local frame = Narci_PlayerInfoFrame;

	if currentSpecName then
		className = currentSpecName.." "..className;
	end

	local titleID = GetCurrentTitle and GetCurrentTitle();
	local titleName = titleID and titleID > 0 and GetTitleName(titleID);
	--titleName = "Test Cool Title";

	local timePlayed = PlayTimeUtil:GetTimeString();

	if timePlayed then
		frame.Miscellaneous:SetText("|cFFFFD100"..level.."|r  ".."|c"..rgbHex..className.."|r".."|cff808080  |  |r"..timePlayed);
	else
		if titleName then
			titleName = strtrim(titleName); --delete the space in Title
			frame.Miscellaneous:SetText(titleName.."  |  ".."|cFFFFD100"..level.."|r  ".."|c"..rgbHex..className.."|r");
		else
			frame.Miscellaneous:SetText("|cFFFFD100"..level.."|r  ".."|c"..rgbHex..className.."|r");
		end
	end

	---- Titles are not available in Vanilla
	--local titleButton = Narci_TitleManager_Switch;
	--titleButton:SetWidth(max( (frame.Miscellaneous:GetWidth() or 0) + 16, 160) );
	--titleButton:Enable();

	ItemLevelFrame:AsyncUpdate();
end

local SlotController = {};
SlotController.updateFrame = CreateFrame("Frame");
SlotController.updateFrame:Hide();
SlotController.updateFrame:SetScript("OnUpdate", function(f, elapsed)
	f.t = f.t + elapsed;
	if f.t >= 0.05 then
		f.t = 0;
		if SlotController:Refresh( f.sequence[f.i], f.forceRefresh) then
			f.i = f.i + 1;
		else
			f:Hide();
		end
	end
end);

SlotController.refreshSequence = {
	1, 2, 3, 15, 5, 9, 16, 17, 18, 0,
	10, 6, 7, 8, 11, 12, 13, 14, 4, 19,
};

SlotController.tempEnchantSequence = {};

for slotID in pairs(validForTempEnchant) do
	tinsert(SlotController.tempEnchantSequence, slotID);
end

function SlotController:Refresh(slotID, forceRefresh)
	if SLOT_TABLE[slotID] then
		SLOT_TABLE[slotID]:Refresh(forceRefresh);
		return true
	end
end

function SlotController:RefreshAll()
	for slotID, slotButton in pairs(SLOT_TABLE) do
		slotButton:Refresh();
	end
end

function SlotController:StopRefresh()
	if self.updateFrame then
		self.updateFrame:Hide();
	end
end

function SlotController:LazyRefresh(sequenceName)
	local f = self.updateFrame;
	f:Hide();
	f.t = 0;
	f.i = 1;
	if sequenceName == "temp" then
		f.sequence = self.tempEnchantSequence;
		f.forceRefresh = true;
	else
		f.sequence = self.refreshSequence;
		f.forceRefresh = false;
	end
	f:Show();
end

function SlotController:UpdateCooldown()
	for slotID, slotButton in pairs(SLOT_TABLE) do
		slotButton:TrackCooldown();
	end
end

function SlotController:PlayAnimOut()
	if not InCombatLockdown() and Narci_Character:IsShown() then
		for slotID, slotButton in pairs(SLOT_TABLE) do
			slotButton.animOut:Play();
		end
		Narci_Character.animOut:Play();
	end
end

function SlotController:IsMouseOver()
	for slotID, slotButton in pairs(SLOT_TABLE) do
		if slotButton:IsMouseOver() then
			return true
		end
	end
	return false
end



------------------------------------------------------------------
-----Some of the codes are derivated from EquipmentFlyout.lua-----
------------------------------------------------------------------

NarciEquipmentFlyoutButtonMixin = CreateFromMixins{NarciItemButtonSharedMixin};

function NarciEquipmentFlyoutButtonMixin:OnClick(button, down, isGamepad)
	if button == "LeftButton" then
		local action = EquipmentManagerAPI.EquipItemByLocation(self.location, self.slotID)
		if action then
			self:AnchorAlertFrame();
			ConfirmBinding();
			EquipmentManagerAPI.RunAction(action)
		end
		self:Disable();
		if isGamepad then
			EquipmentFlyoutFrame.gamepadButton = self;
		end
	end
end

function NarciEquipmentFlyoutButtonMixin:OnLeave()
	FadeFrame(self.Highlight, 0.25, 0);
	Narci:HideButtonTooltip();
	self:ResetAnimation();
end

function NarciEquipmentFlyoutButtonMixin:OnEnter(motion, isGamepad)
	Narci_Comparison_SetComparison(self.itemLocation, self);
	if isGamepad then
		self:PlayGamePadAnimation();
	else
		FadeFrame(self.Highlight, 0.15, 1);
	end
end

function NarciEquipmentFlyoutButtonMixin:OnEvent(event, ...)
	if event == "UI_ERROR_MESSAGE" then
		self:OnErrorMessage(...);
	end
end

function NarciEquipmentFlyoutButtonMixin:SetUp(maxItemLevel)
	self.FlyUp:Stop();
	local itemLocation = self.itemLocation;
	self.hyperlink = C_Item.GetItemLink(itemLocation)
	if ( not itemLocation ) then
		return;
	end

	local itemID = C_Item.GetItemID(itemLocation);
	local itemQuality = C_Item.GetItemQuality(itemLocation);
	local itemLevel = C_Item.GetCurrentItemLevel(itemLocation);
	local itemIcon = C_Item.GetItemIcon(itemLocation);
	local itemLink = C_Item.GetItemLink(itemLocation);

	itemQuality = GetBorderArtByItemID(itemID) or itemQuality;

	if maxItemLevel and itemLevel < maxItemLevel then
		itemQuality = 0;
		self.Icon:SetDesaturated(true);
	else
		self.Icon:SetDesaturated(false);
	end

	self.Icon:SetTexture(itemIcon)
	--self.Border:SetTexture(BorderTexture[itemQuality])
	self:SetBorderTexture(self.Border, itemQuality);
	self.ItemLevelCenter.ItemLevel:SetText(itemLevel);
	self.ItemLevelCenter:Show();

	if itemLink then
		DisplayRuneSlot(self, self.slotID, itemQuality, itemLink);
	end
end

function NarciEquipmentFlyoutButtonMixin:HideButton()
	self:Hide();
	self.location = nil;
	self.hyperlink = nil;
end

local function ShowLessItemInfo(self, state)
	if state then
		self.Name:Hide();
		if self.ItemLevelCenter then
			self.ItemLevel:Hide();
			self.ItemLevelCenter:Show();
		end
	else
		self.Name:Show();
		if self.ItemLevelCenter then
			self.ItemLevel:Show();
			self.ItemLevelCenter:Hide();
		end
	end
end

local function ShowAllItemInfo()
	if XMOG_MODE ~=0 then
		return;
	end

	local level = FlyoutBlackScreen:GetFrameLevel() - 1;

	for slotID, slotButton in pairs(SLOT_TABLE) do
		ShowLessItemInfo(slotButton, false);
		slotButton:SetFrameLevel(level -1)
		slotButton.RuneSlot:SetFrameLevel(level);
	end
end

NarciEquipmentFlyoutFrameMixin = {};

function NarciEquipmentFlyoutFrameMixin:OnLoad()
	EquipmentFlyoutFrame = self;
	self.buttons = {};
	self.slotID = -1;
	self.itemSortFunc = function(a,b)
		return tonumber(a.level) > tonumber(b.level)
	end
	self:SetScript("OnLoad", nil);
	self.OnLoad = nil;
end

function NarciEquipmentFlyoutFrameMixin:OnHide()
	ShowAllItemInfo();
	self.slotID = -1;
	self:UnregisterEvent("MODIFIER_STATE_CHANGED");
	self:UnregisterEvent("GLOBAL_MOUSE_DOWN");
	self.Arrow:Hide();
	self:StopAnimating();

	if Narci_Character.animOut:IsPlaying() then return; end

	FlyoutBlackScreen:Out();
end

function NarciEquipmentFlyoutFrameMixin:OnShow()
	self:RegisterEvent("MODIFIER_STATE_CHANGED");
	self:RegisterEvent("GLOBAL_MOUSE_DOWN");
	self.Arrow.anim:Play();
end

function NarciEquipmentFlyoutFrameMixin:OnEvent(event, ...)	--Hide Flyout if Left-Alt is released
	if ( event == "MODIFIER_STATE_CHANGED" ) then
		local key, state = ...;
		if ( key == "LALT" ) then
			local flyout = EquipmentFlyoutFrame;
			if state == 0 and flyout:IsShown() then
				flyout:Hide();
			end
		end
	elseif (event == "GLOBAL_MOUSE_DOWN") then
		if not self:IsMouseOverButtons() then
			self:Hide();
		end
	end
end

function NarciEquipmentFlyoutFrameMixin:SetItemSlot(slotButton, showArrow)
	if MOG_MODE then
		return;
	end

	local slotID = slotButton.slotID;

	if slotID == 0 then
		self:Hide();
		AmmoProvider:ShowAvailableAmmos(slotButton);
		return
	else
		AmmoProvider:HideAvailableAmmos();
	end

	if (slotID == -1 or (self:IsShown() and self.parentButton and self.parentButton.slotID == slotID)) and (not IsAltKeyDown()) then
		self:Hide();
		return
	end

	if self.parentButton then
		local level = FlyoutBlackScreen:GetFrameLevel() -1;
		self.parentButton:SetFrameLevel(level - 1);
		self.parentButton.RuneSlot:SetFrameLevel(level);
		ShowLessItemInfo(self.parentButton, false);
	end

	self.parentButton = slotButton;
	self:DisplayItemsBySlotID(slotID, self.slotID ~= slotID);
	self.slotID = slotID;
	self:SetParent(slotButton);
	self:ClearAllPoints();
	if slotButton.isRight then
		self:SetPoint("TOPRIGHT", slotButton, "TOPLEFT", 0, 0);			--EquipmentFlyout's Position
	else
		self:SetPoint("TOPLEFT", slotButton, "TOPRIGHT", 0, 0);
	end

	--Unequip Arrow
	self.Arrow:ClearAllPoints();
	self.Arrow:SetPoint("TOP", slotButton, "TOP", 0, 8);
	if showArrow then
		self.Arrow:Show();
	end

	local blackscreenLevel = FlyoutBlackScreen:GetFrameLevel();
	FlyoutBlackScreen:In();
	Narci_Attribute:SetFrameLevel(blackscreenLevel + 2);
	slotButton:SetFrameLevel(blackscreenLevel + 1);
	self:SetFrameLevel(20);

	NarciGameTooltip:HideTooltip();
	ShowLessItemInfo(slotButton, true)

	--Reposition Comparison Tooltip if it reaches the top of the screen--
	local Tooltip = Narci_Comparison;
	Tooltip:ClearAllPoints();
	Tooltip:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 8, 12);
	if slotButton:GetTop() > Tooltip:GetBottom() then
    	Tooltip:ClearAllPoints();
    	Tooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 8, -12);
	end
	Narci_Comparison_SetComparison(self.BaseItem, slotButton);
	Tooltip:Show();
end

function NarciEquipmentFlyoutFrameMixin:CreateItemButton()
	local perRow = 5;	--EQUIPMENTFLYOUT_ITEMS_PER_ROW
	local numButtons = #self.buttons;

	local button = CreateFrame("Button", nil, self.ButtonFrame, "NarciEquipmentFlyoutButtonTemplate");
	button:SetFrameStrata("DIALOG");
	local row = floor(numButtons/perRow);
	local col = numButtons - row * perRow;
	button:SetPoint("TOPLEFT", self, "TOPLEFT", 70*col, -74*row);
	self.buttons[numButtons + 1] = button;
	button.FlyUp.Move:SetStartDelay(numButtons/25);
	button.FlyUp.Fade:SetStartDelay(numButtons/25);
	button.isFlyout = true;
	return button
end

function NarciEquipmentFlyoutFrameMixin:DisplayItemsBySlotID(slotID, playFlyUpAnimation)
	local LoadItemData = C_Item.RequestLoadItemData;	--Cache Item Info
	local id = slotID or self.slotID;
	if not id or id <= 0 then
		return
	end
	self:Show();
	local baseItemLevel;
	local bastItemLocation = ItemLocation:CreateFromEquipmentSlot(id);
	if C_Item.DoesItemExist(bastItemLocation) then
		baseItemLevel = C_Item.GetCurrentItemLevel(bastItemLocation);
	else
		baseItemLevel = 0;
	end
	self.BaseItem = bastItemLocation;
	local buttons = self.buttons;
	
	--Get the items from bags;
	local itemTable = {};
	local sortedItems = {};

	GetInventoryItemsForSlot(id, itemTable);
	local itemLocation, itemLevel, itemInfo;
	local invLocationPlayer = ITEM_INVENTORY_LOCATION_PLAYER;
	for location, hyperlink in pairs(itemTable) do
		if ( location - id == invLocationPlayer ) then -- Remove the currently equipped item from the list
			itemTable[location] = nil;
		else
			local _, _, bags, _, slot, bag = EquipmentManagerAPI.UnpackLocation(location);
			if bags then
				itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot);
				itemLevel = C_Item.GetCurrentItemLevel(itemLocation);
				--NarciCacheTooltip:SetHyperlink(hyperlink);
				LoadItemData(itemLocation);
				itemInfo = {level = itemLevel, itemLocation = itemLocation, location = location};
				tinsert(sortedItems, itemInfo);
			end
		end
	end
	table.sort(sortedItems, self.itemSortFunc);		--Sorted by item level
	local numTotalItems = #sortedItems;
	local buttonWidth, buttonHeight = self.parentButton:GetWidth(), self.parentButton:GetHeight();
	buttonWidth, buttonHeight = floor(buttonWidth + 0.5), floor(buttonHeight + 0.5);
	local borderSize = self.parentButton.Border:GetSize();
	borderSize = floor(borderSize + 0.5);
	self:SetWidth(max(buttonWidth, math.min(numTotalItems, 5)*buttonWidth));
	local numDisplayedItems = math.min(numTotalItems, 20);	--EQUIPMENTFLYOUT_ITEMS_PER_PAGE
	self:SetHeight(max(floor((numDisplayedItems-1)/5 + 1)*buttonHeight, buttonHeight));

	local gamepadButton = self.gamepadButton;
	self.gamepadButton = nil;

	baseItemLevel = baseItemLevel - 14;		--darken button if the item level is lower than the base
	local button;

	for i = 1, numDisplayedItems do
		button = buttons[i];
		if not button then
			button = self:CreateItemButton();
		end
		button.itemLocation = sortedItems[i].itemLocation;
		button.location = sortedItems[i].location;
		button.slotID = id;
		button:SetUp(baseItemLevel);
		button:Show();
		button:SetSize(buttonWidth, buttonHeight);
		button.Border:SetSize(borderSize, borderSize);
		button:Enable();
		if button == gamepadButton then
			Narci_Comparison_SetComparison(gamepadButton.itemLocation, gamepadButton);
			Narci_GamepadOverlayContainer.SlotBorder:UpdateQualityColor(gamepadButton);
		end
	end

	for i = numDisplayedItems + 1, #buttons do
		buttons[i]:HideButton();
	end

	if playFlyUpAnimation then
		for i = 1, numDisplayedItems do
			buttons[i].FlyUp:Play();
		end
	end

	self.numDisplayedItems = numDisplayedItems;		--For gamepad to cycle
end

function NarciEquipmentFlyoutFrameMixin:IsMouseOverButtons()
	for i = 1, #self.buttons do
		if self.buttons[i]:IsShown() and self.buttons[i]:IsMouseOver() then
			return true;
		end
	end
	if self.parentButton:IsMouseOver() then
		return true
	end

	if SlotController:IsMouseOver() then
		return true
	end
	return false
end
-----------------------------------------------------------
------------------------Color Theme------------------------
-----------------------------------------------------------
local ColorUtil = {};
ColorUtil.themeColor = NarciThemeUtil:GetColorTable();

function ColorUtil:UpdateByMapID()
	local mapID = C_Map.GetBestMapForUnit("player");
	--print("mapID:".. mapID)
	if mapID then	--and NarcissusDB.AutoColorTheme
		if mapID == self.mapID then
			self.requireUpdate = false;
		else
			self.mapID = mapID;
			self.requireUpdate = true;
			self.themeColor = NarciThemeUtil:SetColorIndex(mapID);
		end
	else
		self.requireUpdate = false;
	end
end

function ColorUtil:SetWidgetColor(frame)
	if not self.requireUpdate then return end;

	local r, g, b = self.themeColor[1], self.themeColor[2], self.themeColor[3];
	local type = frame:GetObjectType();

	if type == "FontString" then
		local sqrt = math.sqrt;
		r, g, b = sqrt(r), sqrt(g), sqrt(b);
		frame:SetTextColor(r, g, b);
	else
		frame:SetColorTexture(r, g, b);
	end
end


function Narci_AttributeFrame_UpdateBackgroundColor(self)
	local frameID = self:GetID() or 0;
	local themeColor = ColorUtil.themeColor;
	local r, g, b = themeColor[1], themeColor[2], themeColor[3];
	if frameID % 2 == 0 then
		if self.Color then
			self.Color:SetColorTexture(r, g, b, 0.75);
			return;
		elseif self.Color1 and self.Color2 then
			self.Color1:SetColorTexture(r, g, b, 0.75);
			self.Color2:SetColorTexture(r, g, b, 0.75);
		end
	else
		if self.Color then
			self.Color:SetColorTexture(0.1, 0.1, 0.1, 0.75);
			return;
		elseif self.Color1 and self.Color2 then
			self.Color1:SetColorTexture(0.1, 0.1, 0.1, 0.75);
			self.Color2:SetColorTexture(0.1, 0.1, 0.1, 0.75);
		end
	end
end

function Narci_AttributeFrame_OnLoad(self)
	Narci_AttributeFrame_UpdateBackgroundColor(self);
end

function XmogList_OnLoad(self)
	Narci_AttributeFrame_UpdateBackgroundColor(self);
end



local function ShowAttributeButton(bool)
	ItemLevelFrame:SetShown(true);
end

local function UpdatePlayerName(self)
	local playerName = UnitName("player");
	self.PlayerName:SetShadowColor(0, 0, 0);
	self.PlayerName:SetShadowOffset(2, -2);
	self.PlayerName:SetText(playerName);
	SmartFontType(self.PlayerName);
end

function Narci_PlayerInfoFrame_OnLoad(self)
	UpdatePlayerName(self);

	local function OnShow()
		self:RegisterEvent("TIME_PLAYED_MSG");
		RequestTimePlayed();

		self:SetScript("OnShow", function()
			self.t = 0;
			UpdateCharacterInfoFrame();
		end);
	end

	local function OnEvent(_, event, ...)
		local totalTime, levelTime = ...
		PlayTimeUtil:SetBasePlayTime(totalTime);
		UpdateCharacterInfoFrame();
		self:SetScript("OnEvent", nil);
	end

	self.t = 0;

	local function OnUpdate(_, elapsed)
		self.t = self.t + elapsed;
		if self.t < 30 then
			return
		end

		self.t = 0;
		UpdateCharacterInfoFrame();
	end

	self:SetScript("OnEvent", OnEvent);
	self:SetScript("OnUpdate", OnUpdate);

	--Only display time played on HC mode
	local seasonID = C_Seasons and C_Seasons.GetActiveSeason();
	if seasonID == 3 then
		self:SetScript("OnShow", OnShow);
	end
end

function Narci_AliasButton_SetState()
	local editBox = Narci_PlayerInfoFrame.PlayerName;
	local button = Narci_AliasButton;

	if NarcissusDB_PC.UseAlias then
		editBox:Enable();
		editBox:SetText((NarcissusDB_PC.PlayerAlias or UnitName("player")));
		button.Label:SetText(L["Use Player Name"]);
	else
		editBox:Disable();
		editBox:SetText(UnitName("player"));
		button.Label:SetText(L["Use Alias"]);
	end

	local LetterNum = editBox:GetNumLetters();
	local w = max(LetterNum*16, 160);
	editBox:SetWidth(w);

	button:SetWidth(button.Label:GetWidth() + 12);
end

function Narci_AliasButton_OnClick(self)
	local editBox = Narci_PlayerInfoFrame.PlayerName;
	NarcissusDB_PC.UseAlias = not NarcissusDB_PC.UseAlias;

	if NarcissusDB_PC.UseAlias then
		self.Label:SetText(L["Use Player Name"]);
		editBox:Enable();
		editBox:SetFocus();
		editBox:SetText(NarcissusDB_PC.PlayerAlias or UnitName("player"));
		editBox:HighlightText();
	else
		self.Label:SetText(L["Use Alias"]);
		local text = strtrim(editBox:GetText());
		editBox:SetText(text);
		NarcissusDB_PC.PlayerAlias = text;
		editBox:Disable();
		editBox:HighlightText(0,0)
		editBox:SetText(UnitName("player"));
	end
	self:SetWidth(self.Label:GetWidth() + 12);
	local LetterNum = editBox:GetNumLetters();
	local w = max(LetterNum*16, 160);
	editBox:SetWidth(w);
end


function Narci_Open()
	if not IS_OPENED then
		if InCombatLockdown() then
			--[[
			--Can't open the default character pane either
			ShowUIPanel(CharacterFrame);
			local subFrame = _G["PaperDollFrame"];
			if not subFrame:IsShown() then
				ToggleCharacter("PaperDollFrame");
			end
			--]]
			return;
		end
		IS_OPENED = true;
		CVarTemp:BackUp();
		Toolbar:ShowUI("Narcissus");
		ViewProfile:SaveView(5);
		CameraUtil:UpdateParameters();
		CameraMover:MakeActive();
		MOG_MODE_OFFSET = 0;

		local speedFactor = 180/(GetCVar("cameraYawMoveSpeed") or 180);
		ZoomFactor.toSpeed = speedFactor * ZoomFactor.toSpeedBasic;
		ZoomFactor.fromSpeed = speedFactor * ZoomFactor.fromSpeedBasic;

		EL:Show();

		After(0, function()
			CameraMover:Enter();
			PlayLetteboxAnimation();
			local Vignette = Narci_Vignette;
			Vignette.VignetteLeft:SetAlpha(VIGNETTE_ALPHA);
			Vignette.VignetteRight:SetAlpha(VIGNETTE_ALPHA);
			Vignette.VignetteRightSmall:SetAlpha(0);
			FadeFrame(Vignette, 0.5, 1);
			Vignette.VignetteRight.animIn:Play();
			Vignette.VignetteLeft.animIn:Play();
			After(0, function()
				SlotController:LazyRefresh();
				AttributeController:InstantRefresh();
				--AttributeController:PlayFadeIn();
			end);
		end);
		
		Narci.refreshCombatRatings = true;
		Narci.isActive = true;
	else
		if Narci.showExitConfirm and not InCombatLockdown() then
			local ExitConfirm = Narci_ExitConfirmationDialog;
			if not ExitConfirm:IsShown() then
				FadeFrame(ExitConfirm, 0.25, 1);

				--"Nullify" ShowUI
				UIParent:SetAlpha(0);
				Minimap:Hide();
				After(0, function()
					SetUIVisibility(false);
					MiniButton:Enable();
					UIParent:SetAlpha(1);
					Minimap:Show()
				end);

				return;
			else
				FadeFrame(ExitConfirm, 0.15, 0);
			end
		end
		SlotController:PlayAnimOut();
		ExitFunc();
		PlayLetteboxAnimation("OUT");
		EquipmentFlyoutFrame:Hide();
		Narci_ModelSettings:Hide();

		Toolbar:HideUI();
		TakeOutFrames(false);

		Narci.showExitConfirm = false;
	end

	NarciAPI.UpdateSessionTime();
end

function Narci_OpenGroupPhoto()
	if not IS_OPENED then
		if InCombatLockdown() then
			return;
		end
		IS_OPENED = true;
		CVarTemp:BackUp();
		Toolbar:ShowUI("Narcissus");
		ViewProfile:SaveView(5);
		CameraUtil:UpdateParameters();
		CameraMover:MakeActive();
		SetCVar("test_cameraDynamicPitch", 1);
		
		local speedFactor = 180/(GetCVar("cameraYawMoveSpeed") or 180);
		ZoomFactor.toSpeed = speedFactor*ZoomFactor.toSpeedBasic;
		ZoomFactor.fromSpeed = speedFactor*ZoomFactor.fromSpeedBasic;
		EL:Show();
		
		CameraMover:Pitch();

		After(0, function()
			Toolbar:Expand(true);
			local toolbarButton = GetToolbarButtonByButtonType("Mog");
			toolbarButton:OnClick();

			SlotController:LazyRefresh();
			local Vignette = Narci_Vignette;
			Vignette.VignetteLeft:SetAlpha(VIGNETTE_ALPHA);
			Vignette.VignetteRight:SetAlpha(VIGNETTE_ALPHA);
			Vignette.VignetteRightSmall:SetAlpha(0);
			FadeFrame(Vignette, 0.8, 1);
			Vignette.VignetteRight.animIn:Play();
			Vignette.VignetteLeft.animIn:Play();

			if UIParent:IsShown() then
				UIPA.endAlpha = 0;
				UIPA:Show();
			end

			After(0, function()
				After(0.5, function()
					SetUIVisibility(false); 		--Same as pressing Alt + Z

					After(0.3, function()
						UIParent:SetAlpha(1);
					end)
				end)
			end)
		end)
		
		Narci.isActive = true;
		MsgAlertContainer:Display();
	end

	NarciAPI.UpdateSessionTime();
end



------------------------------------------------------
------------------Photo Mode Controller---------------
------------------------------------------------------
function Narci_KeyListener_OnEscapePressed(self)
	if IS_OPENED then
		MiniButton:Click();
		if self then
			self:SetPropagateKeyboardInput(false);
			After(0, function()
				self:SetPropagateKeyboardInput(true);
			end);
		end
	end
end

function Narci_ExitButton_OnClick(self)
	if IS_OPENED then
		Narci_Open();
		SetUIVisibility(true);
	end
end



local function UseXmogLayout()
	MOG_MODE_OFFSET = 0.2;
	NarciPlayerModelFrame1.XMOG_MODE = 2;
	if Narci_Character:IsVisible() then
		FadeFrame(NarciModel_RightGradient, 0.5, 1);
	end

	Narci_ModelContainer:Show();
	Narci_PlayerModelAnimIn:Show();

	Narci_PlayerModelGuideFrame.VignetteRightSmall:Show();
	Narci_GuideLineFrame.VirtualLineRight.AnimFrame.toX = -600;
	Narci_GuideLineFrame.VirtualLineRight.AnimFrame:Show();

	After(0, function()
		if not IsMounted() then
			CameraMover:Pitch();
			CameraMover:ZoomIn(ZOOM_IN_VALUE_MOG);	--ajust by raceID
		else
			CameraMover:ZoomIn(8);	--ajust by raceID
		end
	end)
end

local function ActivateMogMode()
	Narci_GuideLineFrame.VirtualLineRight.AnimFrame:Hide();

	if MOG_MODE then
		FadeFrame(Narci_Attribute, 0.5, 0)
		FadeFrame(Narci_XmogNameFrame, 0.2, 1, 0)
		MOG_MODE_OFFSET = 0.2;
		NarciPlayerModelFrame1.XMOG_MODE = 2;
		MsgAlertContainer:Display();
		UseXmogLayout();
	else
		Narci_GuideLineFrame.VirtualLineRight.AnimFrame.toX = Narci_GuideLineFrame.VirtualLineRight.AnimFrame.defaultX
		if Toolbar:IsShown() then
			Narci_GuideLineFrame.VirtualLineRight.AnimFrame:Show()
			FadeFrame(Narci_Attribute, 0.5, 1)
			local zoom = GetCameraZoom()
			SmoothShoulderCVar(SHOULDER_FACTOR_1*zoom + SHOULDER_FACTOR_2)
		end
		FadeFrame(Narci_XmogNameFrame, 0.2, 0)
		ShowAttributeButton();
		MOG_MODE_OFFSET = 0;
		MsgAlertContainer:Hide();
	end
end

local function UpdateXmogName()
	local frame = Narci_XmogNameFrame;

	frame.MogNameEditBox:SetText(UnitName("player"));

	local armorType = NarciClassicAPI.GetPlayerArmorTypeName();
	local className, englishClass, _ = UnitClass("player");
	local _, _, _, rgbHex = GetClassColor(englishClass);
	frame.ArmorString:SetText("|cFFFFD100"..armorType.."|r".."  |  ".."|c"..rgbHex..className.."|r");
end

local function GetWowHeadDressingRoomURL()
	local slot;
	local ItemList = {};
	for i = 1, #xmogTable do
		slot = xmogTable[i][1];
		if SLOT_TABLE[slot] and SLOT_TABLE[slot].itemID then
			ItemList[slot] = {SLOT_TABLE[slot].itemID, SLOT_TABLE[slot].bonusID};
		end
	end
	return NarciAPI.EncodeItemlist(ItemList);
end

local function CopyTexts(textFormat, includeID)
	local texts = Narci_XmogNameFrame.MogNameEditBox:GetText() or "My Transmog";
	textFormat = textFormat or "text";

	local source;
	if textFormat == "text" then
		texts = texts.."\n"
		for i = 1, #xmogTable do
			local index =  xmogTable[i][1]
			if SLOT_TABLE[index] and SLOT_TABLE[index].Name:GetText() then
				local text = "|cFFFFD100"..xmogTable[i][2]..":|r "..(SLOT_TABLE[index].Name:GetText() or " ");

				if includeID and SLOT_TABLE[index].itemID then
					text = text.." |cFFacacac"..SLOT_TABLE[index].itemID.."|r";
				end

				source = SLOT_TABLE[index].ItemLevel:GetText();
				if source and source ~= " " then
					text = text.." ("..source..")"
				end
				if text then
					texts = texts.."\n"..text;
				end
			end
		end

	elseif textFormat == "reddit" then	
		texts = "|cFF959595**|r"..texts.."|cFF959595**\n\n| Slot | Name | Source |".."\n".."|:--|:--|:--|"
		for i=1, #xmogTable do
			local index =  xmogTable[i][1]
			if SLOT_TABLE[index] and SLOT_TABLE[index].Name:GetText() then
				local text = "|cFF959595| |r|cFFFFD100"..xmogTable[i][2].."|r |cFF959595| |r"
				if	includeID and SLOT_TABLE[index].itemID then
					text = text.."|cFF959595[|r"..(SLOT_TABLE[index].Name:GetText() or " ").."|cFF959595](https://www.wowhead.com/item=|r"..SLOT_TABLE[index].itemID..")|r"
				else
					text = text..(SLOT_TABLE[index].Name:GetText() or " ")
				end
				source = SLOT_TABLE[index].ItemLevel:GetText()
				if source then
				text = text.." |cFF959595| |r|cFF40C7EB"..source.."|r |cFF959595| |r"
				else
					text = text.." |cFF959595| |r"
				end
				if text then
					texts = texts.."\n"..text;
				end
			end
		end
		texts = texts.."\n";
	else
		if textFormat == "wowhead" then
			texts = "|cFF959595[table border=2 cellpadding=4]\n[tr][td colspan=3 align=center][b]|r"..texts.."|r|cFF959595[/b][/td][/tr]\n[tr][td align=center]Slot[/td][td align=center]Name[/td][td align=center]Source[/td][/tr]|r"
		elseif textFormat == "nga" then
			texts = "|cFF959595[table]\n[tr][td colspan=3][align=center][b]|r"..texts.."|r|cFF959595[/b][/align][/td][/tr]\n[tr][td][align=center]部位[/align][/td][td][align=center]装备名称[/align][/td][td][align=center]来源[/align][/td][/tr]|r"
		elseif textFormat == "mmo-champion" then
			texts =	"|cFF959595[table=\"width: 640, class: grid\"]\n[tr][td=\"colspan: 3\"][center][b]|r"..texts.."|r|cFF959595[/b][/center][/td][/tr]\n[tr][td][center]Slot[/center][/td][td][center]Name[/center][/td][td][center]Source[/center][/td][/tr]|r"
		end

		for i=1, #xmogTable do
			local index =  xmogTable[i][1]
			if SLOT_TABLE[index] and SLOT_TABLE[index].Name:GetText() then
				local text = "|cFF959595[tr][td]|r".."|cFFFFD100"..xmogTable[i][2].."|r|cFF959595[/td][td]|r"
				if includeID and SLOT_TABLE[index].itemID then
					if textFormat == "wowhead" then
						text = text.."[item="..SLOT_TABLE[index].itemID.."|r|cFF959595][/td]|r"
					elseif textFormat == "nga" then
						text = text.."|cFF959595[url=https://www.wowhead.com/item="..SLOT_TABLE[index].itemID.."]|r"..(SLOT_TABLE[index].Name:GetText() or " ").."|cFF959595[/url][/td]|r"
					elseif textFormat == "mmo-champion" then
						text = text.."|cFF959595[url=https://www.wowdb.com/items/"..SLOT_TABLE[index].itemID.."]|r"..(SLOT_TABLE[index].Name:GetText() or " ").."|cFF959595[/url][/td]|r"
					end
				else
					text = text..(SLOT_TABLE[index].Name:GetText() or " ").."|r|cFF959595[/td]|r"
				end
				source = SLOT_TABLE[index].ItemLevel:GetText()
				if source then
					text = text.."|cFF959595[td]|r|cFF40C7EB"..source.."|r|cFF959595[/td]|r"
				else
					text = text.."|cFF959595[td] [/td]|r"
				end
				if text then
					texts = texts.."\n"..text.."|cFF959595[/tr]|r"
				end
			end
		end
		texts = texts.."\n|cFF959595[/table]|r"


		-----
		if textFormat == "wowhead" then
			texts = GetWowHeadDressingRoomURL();
		end

	end
	return texts;
end


local function Narci_XmogButton_OnClick(self)
	MoveViewRightStop();
	EquipmentFlyoutFrame:Hide();
	MOG_MODE = not MOG_MODE;
	self.isOn = MOG_MODE;

	if self.isOn then
		FadeFrame(Narci_VignetteRightSmall, 0.5, NarcissusDB.VignetteStrength);
		FadeFrame(Narci_VignetteRightLarge, 0.5, 0);
		Narci_SnowEffect(false);
		PlayLetteboxAnimation("OUT");

		Narci_XmogNameFrame.MogNameEditBox:SetText(Narci_PlayerInfoFrame.PlayerName:GetText())

		Toolbar.TransmogListFrame:ShowUI();
		Toolbar.showTransmogFrame = true;
	else
		--Exit Xmog mode
		Toolbar.TransmogListFrame:Hide();
		Toolbar.showTransmogFrame = nil;
		FadeFrame(Narci_VignetteRightSmall, 0.5, 0);
		FadeFrame(Narci_VignetteRightLarge, 0.5, NarcissusDB.VignetteStrength);
		Narci_SnowEffect(true);
		PlayLetteboxAnimation();
		if Narci_ModelContainer:IsVisible() then
			if IS_OPENED then
				CameraMover:Pitch();
			else
				--SmoothShoulderCVar(0);
			end
			Narci_PlayerModelAnimOut:Show()
			After(0.4, function()
				FadeFrame(NarciPlayerModelFrame1, 0.5 , 0);
			end)
		end
		Narci_ModelSettings:Hide();

		if not Narci_ExitConfirmationDialog:IsShown() then
			Narci.showExitConfirm = false;
		end

		if (not InCombatLockdown()) and (not Narci_Character:IsShown()) then
			Narci_Character:Show();
			Narci_Character:SetAlpha(1);
			AttributeController:InstantRefresh();
		end
	end

	SlotController:LazyRefresh();
	After(0.1, function()
		ActivateMogMode();
	end)

	self:UpdateIcon();
end

addon.OverrideToolbarButtonOnClickFunc("Mog", Narci_XmogButton_OnClick);
addon.OverrideToolbarButtonOnInitFunc("Mog", function(self)
	if MOG_MODE then
		self.isOn = true;
		self:UpdateIcon();
	end
end);

Toolbar.TransmogListFrame.getItemListFunc = CopyTexts;



function Narci_SetButtonColor(self)
	ColorUtil:SetWidgetColor(self.Color);
	ColorUtil:SetWidgetColor(self.HighlightColor);
end


function CameraMover:ShowFrame()
	local GuideLineFrame = Narci_GuideLineFrame;
	local VirtualLineRight = GuideLineFrame.VirtualLineRight;
	VirtualLineRight.AnimFrame:Hide();
	local offsetX = GuideLineFrame.VirtualLineRight.AnimFrame.defaultX or -496;
	VirtualLineRight:SetPoint("RIGHT", offsetX + 120, 0);
	if MOG_MODE then
		FadeFrame(Narci_Attribute, 0.4, 0)
	else
		VirtualLineRight.AnimFrame.toX = offsetX;
		FadeFrame(Narci_Attribute, 0.4, 1, 0);
	end
	VirtualLineRight.AnimFrame:Show();
	GuideLineFrame.VirtualLineLeft.AnimFrame:Show();
	After(0, function()
		FadeFrame(Narci_Character, 0.6, 1);
	end)

	Narci_SnowEffect(true);
end


------Photo Mode Toolbar------
do
	local IsInteractingWithDialogNPC = addon.IsInteractingWithDialogNPC;	--Prevent clash with DialogUI

	hooksecurefunc("SetUIVisibility", function(state)
		if IS_OPENED then		--when Narcissus hide the UI
			if state then
				MsgAlertContainer:SetDND(true);
				Toolbar:UseLowerLevel(true);
			else
				local bar = Toolbar;
				Toolbar.ExitButton:Show();
				if not bar:IsShown() then
					bar:Show();
				end
				MsgAlertContainer:SetDND(false);
				bar:UseLowerLevel(false);
			end
		else						--when user hide the UI manually
			if state then
				--When player closes the full-screen world map, SetUIVisibility(true) fires twice, and WorldMapFrame:IsShown() returns true and false.
				--Thus, use this VisibilityTracker instead to check if WorldMapFrame has been closed recently.
				--WorldMapFrame.VisibilityTracker.state
				MsgAlertContainer:Hide();
				if Narci_Character:IsShown() then return end;
				if not Toolbar:IsShown() then return end;

				if not GetKeepActionCam() then
					After(0.6, function()
						ConsoleExec( "actioncam off" );
					end)
				end
				Toolbar:HideUI();
			else
				if IsInteractingWithDialogNPC() then return end;

				local bar = Toolbar;
				if not bar:IsShown() then
					CVarTemp.shoulderOffset = GetCVar("test_cameraOverShoulder");
				end
				bar:ShowUI("Blizzard");
				bar:FadeOut(true);
			end
		end
	end)
end

--[[
do  --UIParent OnShow/OnHide
	local IsInteractingWithDialogNPC = addon.IsInteractingWithDialogNPC;	--Prevent clash with DialogUI

	local frame = CreateFrame("Frame", nil, UIParent);

	local function UIParent_OnShow()
		if IS_OPENED then		--when Narcissus hide the UI
			MsgAlertContainer:SetDND(true);
			Toolbar:UseLowerLevel(true);
		else
			MsgAlertContainer:Hide();
			if Narci_Character:IsShown() then return end;
			if not Toolbar:IsShown() then return end;

			if not GetKeepActionCam() then
				After(0.6, function()
					ConsoleExec( "actioncam off" );
				end)
			end
			Toolbar:HideUI();
		end
	end

	local function UIParent_OnHide()
		if IS_OPENED then		--when Narcissus hide the UI
			local bar = Toolbar;
			Toolbar.ExitButton:Show();
			if not bar:IsShown() then
				bar:Show();
			end
			MsgAlertContainer:SetDND(false);
			bar:UseLowerLevel(false);
		else
			if IsInteractingWithDialogNPC() then return end;

			local bar = Toolbar;
			if not bar:IsShown() then
				CVarTemp.shoulderOffset = GetCVar("test_cameraOverShoulder");
			end
			bar:ShowUI("Blizzard");
			bar:FadeOut(true);
		end
	end

    frame:SetScript("OnShow", UIParent_OnShow);
    frame:SetScript("OnHide", UIParent_OnHide);
end
--]]


SLASH_NARCI1 = "/narci";
SLASH_NARCI2 = "/narcissus";
SlashCmdList["NARCI"] = function(msg)
	msg = string.lower(msg);
	if msg == "" then
		MiniButton:Click();
	elseif msg == "minimap" then
		MiniButton:EnableButton();
		print("Minimap button has been re-enabled.");
	elseif msg == "itemlist" then
		DressUpFrame_Show(DressUpFrame);
		if NarciDressingRoomOverlay then
			NarciDressingRoomOverlay:ShowItemList()
		end
	elseif msg == "parser" then
		NDT_ItemParser:ShowFrame();
	elseif msg == "resetposition" then
		MiniButton:ResetPosition();
	else
		local color = "|cff40C7EB";
		print(color.."Show Minimap Button:|r /narci minimap");
		print(color.."Reset Minimap Button Position:|r /narci resetposition");
		print(color.."Copy Item List:|r /narci itemlist");
		print(color.."DevTool Item Parser:|r /narci parser");
	end
end




--Static Events
EL:RegisterEvent("ADDON_LOADED");
EL:RegisterEvent("PLAYER_ENTERING_WORLD");
EL:RegisterEvent("UNIT_NAME_UPDATE");
EL:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE");
EL:RegisterEvent("CHARACTER_POINTS_CHANGED");
EL:RegisterEvent("PLAYER_LEVEL_CHANGED");


EL:SetScript("OnEvent",function(self, event, ...)
	--print(event)
	if event == "ADDON_LOADED" then
		local name = ...;
		if name ~= "Narcissus" then
			return;
		end
		self:UnregisterEvent(event);

		After(2, function()
			Narci_AliasButton_SetState();
			AttributeController:InstantRefresh();
			UpdateXmogName();
		end)


		--[[
		local timeStart = Narci.timeLoadingStart;
		local timeFinished = GetTimePreciseSec();
		print("Loading Time: "..(timeFinished - timeStart))
		--]]
	elseif event == "PLAYER_ENTERING_WORLD" then
		self:UnregisterEvent(event);
		AttributeController:Initialize();
		UpdateXmogName();
		SetCVar("CameraKeepCharacterCentered", 0);
		--CameraMover:SetBlend(NarcissusDB.CameraTransition);	--Load in Preference.lua
		DefaultTooltip = NarciGameTooltip;	--Created in Module\GameTooltip.lua
		if not ItemTooltip then
			ItemTooltip = DefaultTooltip;
		end
		DefaultTooltip:SetParent(Narci_Character);
		DefaultTooltip:SetFrameStrata("TOOLTIP");
		DefaultTooltip.offsetX = 4;
		DefaultTooltip.offsetY = -16;
		DefaultTooltip:SetIgnoreParentAlpha(true);

		EngravingSlotUtil:InitializeEngravingSystem();

		if IsAddOnLoaded("DynamicCam") then
			CVarTemp.isDynamicCamLoaded = true;
			
			--Check validity
			if not (DynamicCam.BlockShoulderOffsetZoom and DynamicCam.AllowShoulderOffsetZoom) then return end;
			hooksecurefunc("Narci_Open", function()
				if IS_OPENED then
					DynamicCam:BlockShoulderOffsetZoom();
				else
					DynamicCam:AllowShoulderOffsetZoom();
				end
			end)
			hooksecurefunc("Narci_OpenGroupPhoto", function()
				DynamicCam:BlockShoulderOffsetZoom();
			end)

			ViewProfile:Disable();
		end

		After(1.7, function()
			UpdateCharacterInfoFrame();
			
			if CVarTemp.isDynamicCamLoaded then
				CameraMover:UpdateMovementMethodForDynamicCam();
			else
				hooksecurefunc("CameraZoomIn", function(increment)
					if IS_OPENED then
						UpdateShoulderCVar:Start(-increment);
					end
				end)
				
				hooksecurefunc("CameraZoomOut", function(increment)
					if IS_OPENED then
						UpdateShoulderCVar:Start(increment);
					end
				end)
			end
		end)

	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		--Don't fire when ammo slot changed
		local slotID, isItem = ...;

		SlotController:Refresh(slotID);
		if EquipmentFlyoutFrame:IsShown() and EquipmentFlyoutFrame.slotID then
			EquipmentFlyoutFrame:DisplayItemsBySlotID(EquipmentFlyoutFrame.slotID, false);
		end

		ItemLevelFrame:AsyncUpdate();

	elseif event == "PLAYER_AVG_ITEM_LEVEL_UPDATE" then
        if not self.isRefreshing then
            self.isRefreshing = true;
            After(0, function()    -- only want 1 update per 0.1s
				ItemLevelFrame:AsyncUpdate();
				After(0.1, function()
					self.isRefreshing = nil;
				end)
            end)
		end
	elseif event == "UNIT_NAME_UPDATE" then
		local unit = ...;
		if unit == "player" then
			UpdateCharacterInfoFrame();
		end

	elseif event == "CHARACTER_POINTS_CHANGED" then
		if not self.updatingTalent then
			self.updatingTalent = true;
			C_Timer.After(0.1, function()
				UpdateCharacterInfoFrame();
				self.updatingTalent = nil;
			end);
		end


	elseif event == "PLAYER_LEVEL_CHANGED" then
		local oldLevel, newLevel = ...;
		UpdateCharacterInfoFrame(newLevel)

	elseif ( event == "COMBAT_RATING_UPDATE" or
			 event == "UNIT_MAXPOWER" or
			 event == "UNIT_STATS" or
			 event == "UNIT_DAMAGE" or event == "UNIT_ATTACK_SPEED" or event == "UNIT_MAXHEALTH" or event == "UNIT_AURA"
			) and Narci.refreshCombatRatings then
		-- don't refresh stats when equipment set manager is activated
		AttributeController:InstantRefresh();


	elseif event == "PLAYER_TARGET_CHANGED" then
		--RefreshStats(8);		--Armor
		--RefreshStats(9); 		--Damage Reduction

	elseif event == "UPDATE_SHAPESHIFT_FORM" then
		CameraUtil:OnPlayerFormChanged(0.1);

	elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
		CameraUtil:OnPlayerFormChanged(0.0);

	elseif event == "PLAYER_REGEN_DISABLED" then
		if Narci.isAFK and Narci.isActive then
			--exit when entering combat during AFK mode
			MiniButton:Click();
			Narci:PlayVoice("DANGER");
		end

	elseif event == "PLAYER_STARTED_MOVING" then
		self:UnregisterEvent(event);
		MoveViewRightStop();
		if Narci.isAFK and Narci.isActive then
			--exit when entering combat during AFK mode
			MiniButton:Click();
		end

	elseif event == "PLAYER_STARTED_TURNING" and not MOG_MODE then
		NarciAR.Turning.radian = GetPlayerFacing();
		NarciAR.Turning:Show();

	elseif event == "PLAYER_STOPPED_TURNING" and not MOG_MODE then
		NarciAR.Turning:Hide();

	elseif event == "BAG_UPDATE_COOLDOWN" then
		SlotController:UpdateCooldown();
		
	elseif event == "BAG_UPDATE" then
		local newTime = GetTime();
		if self.lastTime then
			if newTime > self.lastTime + 0.2 then
				self.lastTime = newTime;
			else
				return
			end
		else
			self.lastTime = newTime;
		end
		ItemLevelFrame:AsyncUpdate(0.1);

	elseif event == "UNIT_INVENTORY_CHANGED" then
		SlotController:LazyRefresh("temp");
		AmmoProvider:UpdateFlyout();
	end
end)

function EL:ToggleDynamicEvents(state)
	if state then
		for i = 1, #self.dynamicEvents do
			self:RegisterUnitEvent(self.dynamicEvents[i]);
		end
		for i = 1, #self.unitEvents do
			self:RegisterUnitEvent(self.unitEvents[i], "player");
		end
	else
		for i = 1, #self.dynamicEvents do
			self:UnregisterEvent(self.dynamicEvents[i]);
		end
		for i = 1, #self.unitEvents do
			self:UnregisterEvent(self.unitEvents[i]);
		end
	end
end

EL:SetScript("OnShow",function(self)
	self:ToggleDynamicEvents(true);
	if NarciAR then
		NarciAR:Show();
	end
end)

EL:SetScript("OnHide",function(self)
	self:ToggleDynamicEvents(false);
	if NarciAR then
		NarciAR:Hide();
	end
end)


----------------------------------------------------------------------
--Double-click PaperDoll Button to open Narcissus
NarciPaperDollDoubleClickTriggerMixin = {};

local function Narci_DoubleClickTrigger_OnUpdate(self, elapsed)
	self.t = self.t + elapsed;
	if self.t > 0.25 then
		self:SetScript("OnUpdate", nil);
	end
end

function NarciPaperDollDoubleClickTriggerMixin:OnLoad()
	self.t = 0;

	self:SetScript("OnLoad", nil);
	self.OnLoad = nil;
end

function NarciPaperDollDoubleClickTriggerMixin:OnShow()
	self.t = 0;
	self:SetScript("OnUpdate", Narci_DoubleClickTrigger_OnUpdate);
end


function NarciPaperDollDoubleClickTriggerMixin:OnHide()
	if (self.t < 0.25 and self.t > 0.03) and NarcissusDB.EnableDoubleTap then
		MiniButton:Click();
	end
end
----------------------------------------------------------------------


function Narci_GuideLineFrame_OnSizing(self, offset)
	local W;
	local W0, H = WorldFrame:GetSize();
	if (W0 and H) and H ~= 0 then
		local ratio = floor(W0 / H * 100 + 0.5)/100 ;
		if ratio == 1.78 then
			return
		end
		self:ClearAllPoints();
		self:SetPoint("TOP", UIParent, "TOP", 0, 0);
		self:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0);
		offset = offset or 0;
		W = math.min(H / 9 * 16, W0);
		W = floor(W + 0.5);
		--print("Original: "..W0.." Calculated: "..W);
		self:SetWidth(W - offset);
	else
		W = self:GetWidth();
	end

	local C = W*0.618;

	self.VirtualLineRight:SetPoint("RIGHT", C - W +32, 0);
	self.VirtualLineRight.defaultX = C - W +32;

	local AnimFrame = self.VirtualLineRight.AnimFrame;
	AnimFrame.OppoDirection = false;
	AnimFrame.TimeSinceLastUpdate = 0;

	AnimFrame.anchorPoint, AnimFrame.relativeTo, AnimFrame.relativePoint, AnimFrame.toX, AnimFrame.toY = AnimFrame:GetParent():GetPoint();
	AnimFrame.defaultX = AnimFrame.toX;
end




NarciFlyoutOverlayMixin = {};

function NarciFlyoutOverlayMixin:OnLoad()
	FlyoutBlackScreen = self;
end

function NarciFlyoutOverlayMixin:In()
	self:Init();
	self.animFrame.toAlpha = 1;
	self.animFrame:Show();
	self:Show();
end

function NarciFlyoutOverlayMixin:Out()
	self:Init();
	self.animFrame.toAlpha = 0;
	self.animFrame:Show();
	self:Show();
end

function NarciFlyoutOverlayMixin:OnHide()
	self:SetAlpha(0);
	self:Hide();
end

function NarciFlyoutOverlayMixin:Init()
	if not self.animFrame then
		self.animFrame = CreateFrame("Frame", nil, self);
		self.animFrame:SetScript("OnUpdate", function(f, elapsed)
			f.t = f.t + elapsed;
			local alpha;
			if f.t < 0.25 then
				alpha = outSine(f.t, f.fromAlpha, f.toAlpha, 0.25);
			else
				alpha = f.toAlpha;
				if alpha <= 0 then
					self:Hide();
				end
				f:Hide();
			end
			self:SetAlpha(alpha);
		end);
	end
	self.animFrame.t = 0;
	self.animFrame.fromAlpha = self:GetAlpha();
end

function NarciFlyoutOverlayMixin:RaiseFrameLevel(widget)
	local selfLevel = self:GetFrameLevel();
	if self.lastWidget then
		self.lastWidget:SetFrameLevel(selfLevel - 1);
		self.lastWidget = nil;
	end
	local widgetLevel = widget:GetFrameLevel();
	if widgetLevel <= selfLevel then
		widget:SetFrameLevel(selfLevel + 1);
		self.lastWidget = widget;
	end
end



Narci.GetEquipmentSlotByID = function(slotID) return SLOT_TABLE[slotID] end;
Narci.RefreshSlot = function(slotID) SlotController:Refresh(slotID) return SLOT_TABLE[slotID] end;
Narci.RefreshAllSlots = SlotController.RefreshAll;
Narci.RefreshAllStats = nil;


function Narci:SetItemTooltipStyle(id)
	if id == 2 then
		ItemTooltip = NarciGameTooltip;
	else
		ItemTooltip = NarciEquipmentTooltip;
	end
	NarciEquipmentTooltip:SetParent(Narci_Character);
end

function Narci:CloseCharacterUI()
	if IS_OPENED then
		Narci_Open();
	end
end

do
    local SettingFunctions = addon.SettingFunctions;

    function SettingFunctions.SetItemTooltipStyle(id, db)
		--[[
        if id == nil then
            id = db["ItemTooltipStyle"];
        end
        if id == 2 then
            ItemTooltip = NarciGameTooltip;
        else
            ItemTooltip = NarciEquipmentTooltip;
        end
		--]]

		ItemTooltip = NarciGameTooltip;
		NarciEquipmentTooltip:SetParent(Narci_Character);
    end


	function SettingFunctions.SetVignetteStrength(alpha, db)
		if alpha == nil then
			alpha = db["VignetteStrength"];
		end
		alpha = tonumber(alpha) or 0.5;
		VIGNETTE_ALPHA = alpha;
		Narci_Vignette.VignetteLeft:SetAlpha(alpha);
		Narci_Vignette.VignetteRight:SetAlpha(alpha);
		Narci_Vignette.VignetteRightSmall:SetAlpha(alpha);
		Narci_PlayerModelGuideFrame.VignetteRightSmall:SetAlpha(alpha);
	end


	function SettingFunctions.SetUltraWideFrameOffset(offset, db)
		--A positive offset expands the reference frame.
		if not offset then
			offset = db["BaseLineOffset"];
			offset = tonumber(offset) or 0
		end
		Narci_GuideLineFrame_OnSizing(Narci_GuideLineFrame, -offset);
	end

	function SettingFunctions.SetCharacterUIScale(scale, db)
		if not scale then
			scale = db["GlobalScale"];
		end
		scale = tonumber(scale) or 1;

		NarciScreenshotToolbar:SetDefaultScale(scale);
		Narci_Character:SetScale(scale);
		Narci_Attribute:SetScale(scale);
		NarciTooltip:SetScale(scale);
	end

	function SettingFunctions.SetItemNameTextHeight(height, db)
		if not height then
			height = db["FontHeightItemName"];
		end
		height = tonumber(height) or 10;

		local font, _, flag = SLOT_TABLE[1].Name:GetFont();

		for id, slotButton in pairs(SLOT_TABLE) do
			slotButton.Name:SetFont(font, height, flag);
			slotButton:UpdateGradientSize();
		end
	end

	function SettingFunctions.SetItemNameTextWidth(width, db)
		if not width then
			width = db["ItemNameWidth"];
		end
		width = tonumber(width) or 200;

		if width >= 200 then
			width = 512;
		end

		for id, slotButton in pairs(SLOT_TABLE) do
			slotButton.Name:SetWidth(width);
			slotButton.ItemLevel:SetWidth(width);
			slotButton:UpdateGradientSize();
		end
	end

	function SettingFunctions.SetItemNameTruncated(state, db)
		if state == nil then
			state = db["TruncateText"];
		end

		local maxLines;
		if state then
			maxLines = 1;
		else
			maxLines = 2;
		end
		
		for id, slotButton in pairs(SLOT_TABLE) do
			slotButton.Name:SetMaxLines(maxLines);
			slotButton.ItemLevel:SetMaxLines(maxLines);
			slotButton.Name:SetWidth(slotButton.Name:GetWidth()+1)
			slotButton.Name:SetWidth(slotButton.Name:GetWidth()-1)
			slotButton.ItemLevel:SetWidth(slotButton.Name:GetWidth()+1)
			slotButton.ItemLevel:SetWidth(slotButton.Name:GetWidth()-1)
			slotButton:UpdateGradientSize();
		end
	end

	function SettingFunctions.UseCameraTransition(state, db)
		if state == nil then
			state = db["CameraTransition"];
		end

		CameraMover:SetBlend(state);
	end

	function SettingFunctions.EnableCameraSafeMode(state, db)
		if state == nil then
			state = db["CameraSafeMode"];
		end
		CVarTemp.cameraSafeMode = state;
	end

	function SettingFunctions.SetDefaultZoomClose(state, db)
		if state == nil then
			state = db["UseBustShot"];
		end
		if state then
			CAM_DISTANCE_INDEX = 1;
		else
			CAM_DISTANCE_INDEX = 4;
		end
	end
end


UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED");  --Disable EXPERIMENTAL_CVAR_WARNING