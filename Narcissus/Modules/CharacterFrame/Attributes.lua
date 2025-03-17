local _, addon = ...

local _G = _G;
local Narci = Narci;
local L = Narci.L;
local FormatLargeNumbers = NarciAPI.FormatLargeNumbers;
local BreakUpLargeNumbers = BreakUpLargeNumbers;

local format = string.format;
local floor = math.floor;
local ceil = math.ceil;
local max = math.max;
local min = math.min;

local NavBarStat;
local DefaultTooltip = NarciGameTooltip;	--Created in NarciAPI.lua

local C_PaperDollInfo = C_PaperDollInfo;
local UnitStat = UnitStat;
local UnitLevel = UnitLevel;
local UnitResistance = UnitResistance;
local GetCombatRating = GetCombatRating;
local GetCombatRatingBonus = GetCombatRatingBonus;
local GetSpellBonusDamage = GetSpellBonusDamage;
local GetSpellCritChance = GetSpellCritChance;
local IsSpellKnown = IsSpellKnown;

local FONT_COLOR_CODE_CLOSE = FONT_COLOR_CODE_CLOSE;
local GREEN_FONT_COLOR_CODE = GREEN_FONT_COLOR_CODE;
local RED_FONT_COLOR_CODE = RED_FONT_COLOR_CODE;
local HIGHLIGHT_FONT_COLOR_CODE = HIGHLIGHT_FONT_COLOR_CODE;
local HIGHLIGHT_FONT_COLOR = HIGHLIGHT_FONT_COLOR;
local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR;
local CLASS_COLORS_MAGE = RAID_CLASS_COLORS["MAGE"];

local RANGE_WEAPON_EQUIPPED = false;
local PLAYER_CLASS = "HUNTER";

do
	local _, unitClass = UnitClass("player");
	PLAYER_CLASS = string.upper(unitClass);
end

local function ReturnZero()
	return 0
end

local function FormatPercentage(value)
	return format("%.2f", value).."%"
end

local ComputePetBonus = ComputePetBonus or ReturnZero;

local MAX_SPELL_SCHOOLS = MAX_SPELL_SCHOOLS or 7;
local BASE_MOVEMENT_SPEED = BASE_MOVEMENT_SPEED or 7;
local ATTACK_POWER_MAGIC_NUMBER = ATTACK_POWER_MAGIC_NUMBER or 14;
local BLOCK_PER_STRENGTH = BLOCK_PER_STRENGTH or 0.05;
local HEALTH_PER_STAMINA = HEALTH_PER_STAMINA or 10;
local ARMOR_PER_AGILITY = ARMOR_PER_AGILITY or 2;
local MANA_PER_INTELLECT = MANA_PER_INTELLECT or 15;
local DODGE_PARRY_BLOCK_PERCENT_PER_DEFENSE = DODGE_PARRY_BLOCK_PERCENT_PER_DEFENSE or 0.04;

local CR_DEFENSE_SKILL = CR_DEFENSE_SKILL or 2;
local CR_DODGE = CR_DODGE or 3;
local CR_PARRY = CR_PARRY or 4;
local CR_BLOCK = CR_BLOCK or 5;
local CR_HIT_MELEE = CR_HIT_MELEE or 6;
local CR_HIT_RANGED = CR_HIT_RANGED or 7;
local CR_HIT_SPELL = CR_HIT_SPELL or 8;
local CR_CRIT_MELEE = CR_CRIT_MELEE or 9;
local CR_CRIT_RANGED = CR_CRIT_RANGED or 10;
local CR_CRIT_SPELL = CR_CRIT_SPELL or 11;
local CR_RESILIENCE_CRIT_TAKEN = CR_RESILIENCE_CRIT_TAKEN or 15;
local CR_HASTE_MELEE = CR_HASTE_MELEE or 18;
local CR_HASTE_RANGED = CR_HASTE_RANGED or 19;
local CR_HASTE_SPELL = CR_HASTE_SPELL or 20;
local CR_EXPERTISE = CR_EXPERTISE or 24;
local CR_ARMOR_PENETRATION = CR_ARMOR_PENETRATION or 25;

local HitCalculator = {};

local function PaperDollFrame_GetArmorReduction(armor, attackerLevel)
	local levelModifier = attackerLevel;
	if ( levelModifier > 59 ) then
		levelModifier = levelModifier + (4.5 * (levelModifier-59));
	end
	local temp = 0.1*armor/(8.5*levelModifier + 40);
	temp = temp/(1+temp);

	if ( temp > 0.75 ) then
		return 75;
	end

	if ( temp < 0 ) then
		return 0;
	end

	return format("%.2f", (temp*100));
end

local function GetDodgeBlockParryChanceFromDefense()
	local base, modifier = UnitDefense("player");
	local defensePercent = DODGE_PARRY_BLOCK_PERCENT_PER_DEFENSE * ((base + modifier) - (UnitLevel("player")*5));
	defensePercent = max(defensePercent, 0);
	return defensePercent;
end



local function SetStatTooltipText(self)
	DefaultTooltip:ClearAllPoints();
	DefaultTooltip:SetOwner(self, "ANCHOR_NONE");
	DefaultTooltip:SetText(self.tooltip, 1, 1, 1);
	if ( self.tooltip2 ) then
		if type(self.tooltip2) == "table" then
			for _, line in ipairs(self.tooltip2) do
				if line.rightText then
					DefaultTooltip:AddDoubleLine(line.leftText, line.rightText, 1, 0.82, 0, 1, 1, 1);
				elseif line.leftText then
					DefaultTooltip:AddLine(line.leftText, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true);
				end
			end
		else
			DefaultTooltip:AddLine(self.tooltip2, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true);
		end
	end
	if ( self.tooltip3 ) then
		DefaultTooltip:AddLine(" ");
		DefaultTooltip:AddLine(self.tooltip3, CLASS_COLORS_MAGE.r, CLASS_COLORS_MAGE.g, CLASS_COLORS_MAGE.b, true);
	end
	if ( self.tooltip4 ) then
		DefaultTooltip:AddLine(" ");
		DefaultTooltip:AddDoubleLine(self.tooltip4[1], self.tooltip4[2], NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
	end
end

function Narci_ShowStatTooltip(self)
	if ( not self.tooltip ) then
		return;
	end
	SetStatTooltipText(self);
	DefaultTooltip:SetPoint("TOPRIGHT",self,"TOPLEFT", -8, -8);
	DefaultTooltip:ShowTooltip();
end

local Narci_ShowStatTooltip = Narci_ShowStatTooltip;


local function PaperDollFormatStat(name, base, posBuff, negBuff, frame)
	--Set up tooltip e.g., Armor 10 (10 + 5 - 5)
	local effective = max(0, base + posBuff + negBuff);
	local text = HIGHLIGHT_FONT_COLOR_CODE..name.." "..effective;
	if ( ( posBuff == 0 ) and ( negBuff == 0 ) ) then
		text = text..FONT_COLOR_CODE_CLOSE;
	else
		if ( posBuff > 0 or negBuff < 0 ) then
			text = text.." ("..base..FONT_COLOR_CODE_CLOSE;
		end
		if ( posBuff > 0 ) then
			text = text..FONT_COLOR_CODE_CLOSE..GREEN_FONT_COLOR_CODE.."+"..posBuff..FONT_COLOR_CODE_CLOSE;
		end
		if ( negBuff < 0 ) then
			text = text..RED_FONT_COLOR_CODE.." "..negBuff..FONT_COLOR_CODE_CLOSE;
		end
		if ( posBuff > 0 or negBuff < 0 ) then
			text = text..HIGHLIGHT_FONT_COLOR_CODE..")"..FONT_COLOR_CODE_CLOSE;
		end

		-- if there is a negative buff then show the main number in red, even if there are
		-- positive buffs. Otherwise show the number in green
		--[[
		if ( negBuff < 0 ) then
			textString:SetText(RED_FONT_COLOR_CODE..effective..FONT_COLOR_CODE_CLOSE);
		else
			textString:SetText(GREEN_FONT_COLOR_CODE..effective..FONT_COLOR_CODE_CLOSE);
		end
		--]]
	end
	frame.tooltip = text;
end

local function GetHitTooltip_PreWrath(dpsType, ratingBonus)
	if dpsType == 1 then
		return format(CR_HIT_MELEE_TOOLTIP, UnitLevel("player"), ratingBonus, GetArmorPenetration());
	else
		return format(CR_HIT_RANGED_TOOLTIP, UnitLevel("player"), ratingBonus, GetArmorPenetration());
	end
end

local function GetHitTooltip_Wrath(dpsType, ratingBonus)
	if dpsType == 1 then
		return format(CR_HIT_MELEE_TOOLTIP, UnitLevel("player"), ratingBonus, GetCombatRating(CR_ARMOR_PENETRATION), GetArmorPenetration());
	else
		return format(CR_HIT_RANGED_TOOLTIP, UnitLevel("player"), ratingBonus, GetCombatRating(CR_ARMOR_PENETRATION), GetArmorPenetration());
	end
end

local GetHitTooltipText = GetHitTooltip_PreWrath;


local function PaperDollFrame_SetRating(statFrame, ratingIndex)
	--Derivative of the global function with same name
	local statName = _G["COMBAT_RATING_NAME"..ratingIndex];
	local rating = GetCombatRating(ratingIndex);
	local ratingBonus = GetCombatRatingBonus(ratingIndex);

	statFrame:SetLabelAndValue(statName, rating, (rating and rating == 0));

	statFrame.tooltip = HIGHLIGHT_FONT_COLOR_CODE..statName.." "..rating..FONT_COLOR_CODE_CLOSE;

	if ( ratingIndex == CR_HIT_MELEE ) then
		statFrame.tooltip2 = GetHitTooltipText(1, ratingBonus);
	elseif ( ratingIndex == CR_HIT_RANGED ) then
		statFrame.tooltip2 = GetHitTooltipText(2, ratingBonus);
	elseif ( ratingIndex == CR_DODGE ) then
		statFrame.tooltip2 = format(CR_DODGE_TOOLTIP, ratingBonus);
	elseif ( ratingIndex == CR_PARRY ) then
		statFrame.tooltip2 = format(CR_PARRY_TOOLTIP, ratingBonus);
	elseif ( ratingIndex == CR_BLOCK ) then
		statFrame.tooltip2 = format(CR_PARRY_TOOLTIP, ratingBonus);
	elseif ( ratingIndex == CR_HIT_SPELL ) then
		statFrame.tooltip2 = format(CR_HIT_SPELL_TOOLTIP, UnitLevel("player"), ratingBonus, GetSpellPenetration(), GetSpellPenetration());
	elseif ( ratingIndex == CR_CRIT_SPELL ) then
		local holySchool = 2;
		local minCrit = GetSpellCritChance(holySchool);
		statFrame.spellCrit = {};
		statFrame.spellCrit[holySchool] = minCrit;
		local spellCrit;
		for i=(holySchool+1), MAX_SPELL_SCHOOLS do
			spellCrit = GetSpellCritChance(i);
			minCrit = min(minCrit, spellCrit);
			statFrame.spellCrit[i] = spellCrit;
		end
		minCrit = format("%.2f%%", minCrit);
		statFrame.minCrit = minCrit;
	elseif ( ratingIndex == CR_EXPERTISE ) then
		statFrame.tooltip2 = format(CR_EXPERTISE_TOOLTIP, ratingBonus);
	else
		statFrame.tooltip2 = HIGHLIGHT_FONT_COLOR_CODE..statName.." "..rating;
	end
end

local function MovementSpeed_OnUpdate(object, elapsed)
	object.t = object.t + elapsed;
	if object.t > 0.1 then
		object.t = 0;
	else
		return
	end

	local unit = object.unit;
	local _, runSpeed, flightSpeed, swimSpeed = GetUnitSpeed(unit);
	runSpeed = runSpeed/BASE_MOVEMENT_SPEED*100;
	flightSpeed = flightSpeed/BASE_MOVEMENT_SPEED*100;
	swimSpeed = swimSpeed/BASE_MOVEMENT_SPEED*100;

	-- Determine whether to display running, flying, or swimming speed
	local speed = runSpeed;
	local swimming = IsSwimming(unit);
	if (swimming) then
		speed = swimSpeed;
	elseif (IsFlying(unit)) then
		speed = flightSpeed;
	end

	-- Hack so that your speed doesn't appear to change when jumping out of the water
	if (IsFalling(unit)) then
		if (object.wasSwimming) then
			speed = swimSpeed;
		end
	else
		object.wasSwimming = swimming;
	end

	local valueText = format("%d%%", speed+0.5);

	object.Label:SetText(L["Movement Speed"]);		--STAT_MOVEMENT_SPEED
	object.Value:SetText(valueText);

	object.speed = speed;
	object.runSpeed = runSpeed;
	object.flightSpeed = flightSpeed;
	object.swimSpeed = swimSpeed;
end

local function MovementSpeed_OnEnter(object)
	DefaultTooltip:SetOwner(object, "ANCHOR_NONE");
	DefaultTooltip:SetText("|cffffffff".. STAT_MOVEMENT_SPEED .." "..format("%d%%", object.speed+0.5).."|r");

	DefaultTooltip:AddLine(format(STAT_MOVEMENT_GROUND_TOOLTIP, object.runSpeed+0.5));
	if (object.unit ~= "pet") then
		DefaultTooltip:AddLine(format(STAT_MOVEMENT_FLIGHT_TOOLTIP, object.flightSpeed+0.5));
	end
	DefaultTooltip:AddLine(format(STAT_MOVEMENT_SWIM_TOOLTIP, object.swimSpeed+0.5));
	DefaultTooltip:AddLine(" ");
	DefaultTooltip:AddLine(format(CR_SPEED_TOOLTIP, BreakUpLargeNumbers(GetCombatRating(CR_SPEED)), GetCombatRatingBonus(CR_SPEED)));

	DefaultTooltip:SetPoint("TOPRIGHT",object,"TOPLEFT", -4, 0)
	DefaultTooltip:ShowTooltip();

	object.UpdateTooltip = MovementSpeed_OnEnter;
end

local function GetEffectiveCrit()
	local rating;
	local spellCrit, rangedCrit, meleeCrit;
	local critChance;
	
	-- Start at 2 to skip physical damage
	local holySchool = 2;
	local minCrit = GetSpellCritChance(holySchool);
	local spellCritTable = {};
	spellCritTable[holySchool] = minCrit;

	for i = (holySchool+1), MAX_SPELL_SCHOOLS do
		spellCrit = GetSpellCritChance(i);
		minCrit = min(minCrit, spellCrit);
		spellCritTable[i] = spellCrit;
	end
	spellCrit = minCrit
	rangedCrit = GetRangedCritChance();
	meleeCrit = GetCritChance();

	if (spellCrit >= rangedCrit and spellCrit >= meleeCrit) then
		critChance = spellCrit;
		rating = CR_CRIT_SPELL;
	elseif (rangedCrit >= meleeCrit) then
		critChance = rangedCrit;
		rating = CR_CRIT_RANGED;
	else
		critChance = meleeCrit;
		rating = CR_CRIT_MELEE;
	end

	return critChance, rating
end

Narci.GetEffectiveCrit = GetEffectiveCrit;

------------------------------------------------------------------
----The following codes are derivated from PapaerDollFrame.lua----
------------------------------------------------------------------
local UpdateFunc = {};

local PRIMARY_STAT_NAMES = {
	"STRENGTH", "AGILITY", "STAMINA", "INTELLECT", "SPIRIT",
};

function UpdateFunc.Primary(object, statIndex)
	local unit = "player";
	statIndex = statIndex or 1;

	local stat, effectiveStat, posBuff, negBuff = UnitStat(unit, statIndex);
	local effectiveStatDisplay = FormatLargeNumbers(effectiveStat);
	object.Value:SetText(stat);

	-- Set the tooltip text
	local statName = _G["SPELL_STAT"..statIndex.."_NAME"];
	object.Label:SetText(statName);
	local tooltipText = "|cffffffff".. statName .." ";

	if ( ( posBuff == 0 ) and ( negBuff == 0 ) ) then
		object.tooltip = tooltipText..effectiveStatDisplay.."|r";
	else
		tooltipText = tooltipText..effectiveStatDisplay;
		if ( posBuff > 0 or negBuff < 0 ) then
			tooltipText = tooltipText.." ("..BreakUpLargeNumbers(stat - posBuff - negBuff).."|r";
		end
		if ( posBuff > 0 ) then
			tooltipText = tooltipText.."|r"..GREEN_FONT_COLOR_CODE.."+"..BreakUpLargeNumbers(posBuff).."|r";
		end
		if ( negBuff < 0 ) then
			tooltipText = tooltipText..RED_FONT_COLOR_CODE.." "..BreakUpLargeNumbers(negBuff).."|r";
		end
		if ( posBuff > 0 or negBuff < 0 ) then
			tooltipText = tooltipText.."|cffffffff"..")".."|r";
		end
		object.tooltip = tooltipText;

		-- If there are any negative buffs then show the main number in red even if there are
		-- positive buffs. Otherwise show in green.
		--if ( negBuff < 0 and not GetPVPGearStatRules() ) then
		--	effectiveStatDisplay = RED_FONT_COLOR_CODE..effectiveStatDisplay.."|r";
		--end
	end

	-- Get class specific tooltip for that stat
	if not object.tooltipFormat then
		object.tooltipFormat = _G[PLAYER_CLASS.."_"..PRIMARY_STAT_NAMES[statIndex].."_TOOLTIP"] or _G["DEFAULT_"..PRIMARY_STAT_NAMES[statIndex].."_TOOLTIP"] or _G["DEFAULT_STAT"..statIndex.."_TOOLTIP"] or "";
	end

	return stat
end


local function CharacterDamageFrame_OnEnter(self)
	if not self.damage then return end;

	-- Main hand weapon
	DefaultTooltip:SetOwner(self, "ANCHOR_NONE");
	DefaultTooltip:SetText(INVTYPE_WEAPONMAINHAND, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
	DefaultTooltip:AddDoubleLine(ATTACK_SPEED_SECONDS or ATTACK_SPEED, format("%.2F", self.attackSpeed), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);	--ATTACK_SPEED_COLON
	DefaultTooltip:AddDoubleLine(DAMAGE_COLON, self.damage, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
	DefaultTooltip:AddDoubleLine(DAMAGE_PER_SECOND, format("%.1F", self.dps), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
	-- Check for offhand weapon
	if ( self.offhandAttackSpeed ) then
		DefaultTooltip:AddLine(" "); -- Blank line.
		DefaultTooltip:AddLine(INVTYPE_WEAPONOFFHAND, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
		DefaultTooltip:AddDoubleLine(ATTACK_SPEED_SECONDS or ATTACK_SPEED, format("%.2F", self.offhandAttackSpeed), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
		DefaultTooltip:AddDoubleLine(DAMAGE_COLON, self.offhandDamage, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
		DefaultTooltip:AddDoubleLine(DAMAGE_PER_SECOND, format("%.1F", self.offhandDps), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
	end
	DefaultTooltip:SetPoint("TOPRIGHT", self,"TOPLEFT", -8, -8);
	DefaultTooltip:ShowTooltip();
end

---- Stat Melee ----
function UpdateFunc.MeleeDamage(object)
	local unit = "player";
	local valueText;

	local speed, offhandSpeed = UnitAttackSpeed(unit);
	local minDamage, maxDamage, minOffHandDamage, maxOffHandDamage, physicalBonusPos, physicalBonusNeg, percent = UnitDamage(unit);

	local displayMin = max(floor(minDamage),1);
	local displayMax = max(ceil(maxDamage),1);

	if (percent == 0) then
		minDamage = 0;
		maxDamage = 0;
	else
		minDamage = (minDamage / percent) - physicalBonusPos - physicalBonusNeg;
		maxDamage = (maxDamage / percent) - physicalBonusPos - physicalBonusNeg;
	end

	local baseDamage = (minDamage + maxDamage) * 0.5;
	local fullDamage = (baseDamage + physicalBonusPos + physicalBonusNeg) * percent;
	local totalBonus = (fullDamage - baseDamage);
	local damagePerSecond;
	if speed == 0 then
		damagePerSecond = 0;
	else
		damagePerSecond = (max(fullDamage,1) / speed);
	end
	local damageTooltip = max(floor(minDamage),1).." - "..max(ceil(maxDamage),1);

	local colorPos = "|cff20ff20";
	local colorNeg = "|cffff2020";

	-- epsilon check
	if ( totalBonus < 0.1 and totalBonus > -0.1 ) then
		totalBonus = 0.0;
	end

	if ( totalBonus == 0 ) then
		if ( ( displayMin < 100 ) and ( displayMax < 100 ) ) then
			valueText = displayMin.." - "..displayMax;
		else
			valueText = displayMin.."-"..displayMax;
		end
	else
		local color;
		if ( totalBonus > 0 ) then
			color = colorPos;
		else
			color = colorNeg;
		end
		if ( ( displayMin < 100 ) and ( displayMax < 100 ) ) then 
			valueText = color..displayMin.." - "..displayMax.."|r";
		else
			valueText = color..displayMin.."-"..displayMax.."|r";
		end
		if ( physicalBonusPos > 0 ) then
			damageTooltip = damageTooltip..colorPos.." +"..physicalBonusPos.."|r";
		end
		if ( physicalBonusNeg < 0 ) then
			damageTooltip = damageTooltip..colorNeg.." "..physicalBonusNeg.."|r";
		end
		if ( percent > 1 ) then
			damageTooltip = damageTooltip..colorPos.." x"..floor(percent*100+0.5).."%|r";
		elseif ( percent < 1 ) then
			damageTooltip = damageTooltip..colorNeg.." x"..floor(percent*100+0.5).."%|r";
		end

	end
	object.damage = damageTooltip;
	object.attackSpeed = speed;
	object.dps = damagePerSecond;

	-- If there's an offhand speed then add the offhand info to the tooltip
	if ( offhandSpeed ) then
		minOffHandDamage = (minOffHandDamage / percent) - physicalBonusPos - physicalBonusNeg;
		maxOffHandDamage = (maxOffHandDamage / percent) - physicalBonusPos - physicalBonusNeg;

		local offhandBaseDamage = (minOffHandDamage + maxOffHandDamage) * 0.5;
		local offhandFullDamage = (offhandBaseDamage + physicalBonusPos + physicalBonusNeg) * percent;
		local offhandDamagePerSecond;
		if offhandSpeed == 0 then
			offhandDamagePerSecond = 0;
		else
			offhandDamagePerSecond = (max(offhandFullDamage,1) / offhandSpeed);
		end
		local offhandDamageTooltip = max(floor(minOffHandDamage),1).." - "..max(ceil(maxOffHandDamage),1);
		if ( physicalBonusPos > 0 ) then
			offhandDamageTooltip = offhandDamageTooltip..colorPos.." +"..physicalBonusPos.."|r";
		end
		if ( physicalBonusNeg < 0 ) then
			offhandDamageTooltip = offhandDamageTooltip..colorNeg.." "..physicalBonusNeg.."|r";
		end
		if ( percent > 1 ) then
			offhandDamageTooltip = offhandDamageTooltip..colorPos.." x"..floor(percent*100+0.5).."%|r";
		elseif ( percent < 1 ) then
			offhandDamageTooltip = offhandDamageTooltip..colorNeg.." x"..floor(percent*100+0.5).."%|r";
		end
		object.offhandDamage = offhandDamageTooltip;
		object.offhandAttackSpeed = offhandSpeed;
		object.offhandDps = offhandDamagePerSecond;
	else
		object.offhandAttackSpeed = nil;
	end

	object:SetLabelAndValue(DAMAGE, valueText);

	object:SetScript("OnEnter", CharacterDamageFrame_OnEnter);
end

function UpdateFunc.MeleeAttackSpeed(object)
	local unit = "player";

	local speed, offhandSpeed = UnitAttackSpeed(unit);
	speed = format("%.2f", speed);
	if ( offhandSpeed ) then
		offhandSpeed = format("%.2f", offhandSpeed);
	end
	local text;
	if ( offhandSpeed ) then
		text = speed.." / "..offhandSpeed;
	else
		text = speed;
	end
	object:SetLabelAndValue(WEAPON_SPEED, text);

	object.tooltip = HIGHLIGHT_FONT_COLOR_CODE..ATTACK_SPEED.." "..text..FONT_COLOR_CODE_CLOSE;
	object.tooltip2 = format(CR_HASTE_RATING_TOOLTIP, GetCombatRating(CR_HASTE_MELEE), GetCombatRatingBonus(CR_HASTE_MELEE));
end

function UpdateFunc.MeleeAttackPower(object)
	local base, posBuff, negBuff = UnitAttackPower("player");
	local effectiveStat = max((base + posBuff + negBuff));
	object:SetLabelAndValue(ATTACK_POWER, effectiveStat);
	PaperDollFormatStat(MELEE_ATTACK_POWER, base, posBuff, negBuff, object);
	object.tooltip2 = format(MELEE_ATTACK_POWER_TOOLTIP, effectiveStat / ATTACK_POWER_MAGIC_NUMBER);
end

function UpdateFunc.MeleeHitRating(object)
	PaperDollFrame_SetRating(object, CR_HIT_MELEE);
end

function UpdateFunc.MeleeCritChance(object)
	local critChance = GetCritChance();
	critChance = format("%.2f%%", critChance);
	object:SetLabelAndValue(MELEE_CRIT_CHANCE, critChance)
	object.tooltip = HIGHLIGHT_FONT_COLOR_CODE..MELEE_CRIT_CHANCE.." "..critChance..FONT_COLOR_CODE_CLOSE;
	object.tooltip2 = format(CR_CRIT_MELEE_TOOLTIP, GetCombatRating(CR_CRIT_MELEE), GetCombatRatingBonus(CR_CRIT_MELEE));
end

function UpdateFunc.Expertise(object)
	local expertise, offhandExpertise = GetExpertise();
	local speed, offhandSpeed = UnitAttackSpeed("player");
	local text;
	if( offhandSpeed ) then
		text = expertise.." / "..offhandExpertise;
	else
		text = expertise;
	end
	object:SetLabelAndValue(STAT_EXPERTISE, text, (expertise == 0) and (offhandExpertise == 0));
	object.tooltip = HIGHLIGHT_FONT_COLOR_CODE..STAT_EXPERTISE.." "..text..FONT_COLOR_CODE_CLOSE;
	
	local expertisePercent, offhandExpertisePercent = GetExpertisePercent();
	expertisePercent = format("%.2f", expertisePercent);
	if( offhandSpeed ) then
		offhandExpertisePercent = format("%.2f", offhandExpertisePercent);
		text = expertisePercent.."% / "..offhandExpertisePercent.."%";
	else
		text = expertisePercent.."%";
	end
	object.tooltip2 = format(CR_EXPERTISE_TOOLTIP, text, GetCombatRating(CR_EXPERTISE), GetCombatRatingBonus(CR_EXPERTISE));
end


---- Stat Ranged ----
function UpdateFunc.RangedDamage(object)
	-- If no ranged attack then set to n/a
	local hasRelic = UnitHasRelicSlot("player");
	local rangedTexture = GetInventoryItemTexture("player", 18);

	object:SetScript("OnEnter", CharacterDamageFrame_OnEnter);

	if ( rangedTexture and not hasRelic ) then
		RANGE_WEAPON_EQUIPPED = true;
	else
		RANGE_WEAPON_EQUIPPED = false;
		object.damage = nil;
		object:SetLabelAndValue(DAMAGE, NOT_APPLICABLE, true);
		return
	end

	local rangedAttackSpeed, minDamage, maxDamage, physicalBonusPos, physicalBonusNeg, percent = UnitRangedDamage("player");
	local displayMin = max(floor(minDamage),1);
	local displayMax = max(ceil(maxDamage),1);

	local baseDamage;
	local fullDamage;
	local totalBonus;
	local damagePerSecond;
	local tooltip;

	if ( HasWandEquipped() ) then
		baseDamage = (minDamage + maxDamage) * 0.5;
		fullDamage = baseDamage * percent;
		totalBonus = 0;
		damagePerSecond = (max(fullDamage,1) / rangedAttackSpeed);
		tooltip = max(floor(minDamage),1).." - "..max(ceil(maxDamage),1);
	else
		minDamage = (minDamage / percent) - physicalBonusPos - physicalBonusNeg;
		maxDamage = (maxDamage / percent) - physicalBonusPos - physicalBonusNeg;

		baseDamage = (minDamage + maxDamage) * 0.5;
		fullDamage = (baseDamage + physicalBonusPos + physicalBonusNeg) * percent;
		totalBonus = (fullDamage - baseDamage);
		if (rangedAttackSpeed == 0) then
		-- Egan's Blaster!!! --WHAT?
			damagePerSecond = math.huge;
		else
			damagePerSecond = (max(fullDamage,1) / rangedAttackSpeed);
		end
		tooltip = max(floor(minDamage),1).." - "..max(ceil(maxDamage),1);
	end

	local damageText = displayMin.." - "..displayMax;
	if ( totalBonus == 0 ) then
		--damageText = displayMin.." - "..displayMax;
	else
		local colorPos = "|cff20ff20";
		local colorNeg = "|cffff2020";
		--[[
		local color;
		if ( totalBonus > 0 ) then
			color = colorPos;
		else
			color = colorNeg;
		end
		damageText = color..displayMin.." - "..displayMax.."|r";
		--]]

		if ( physicalBonusPos > 0 ) then
			tooltip = tooltip..colorPos.." +"..physicalBonusPos.."|r";
		end
		if ( physicalBonusNeg < 0 ) then
			tooltip = tooltip..colorNeg.." "..physicalBonusNeg.."|r";
		end
		if ( percent > 1 ) then
			tooltip = tooltip..colorPos.." x"..floor(percent*100+0.5).."%|r";
		elseif ( percent < 1 ) then
			tooltip = tooltip..colorNeg.." x"..floor(percent*100+0.5).."%|r";
		end
		object.tooltip = tooltip.." "..format(DPS_TEMPLATE, damagePerSecond);
	end
	object.attackSpeed = rangedAttackSpeed;
	object.damage = tooltip;
	object.dps = damagePerSecond;
	object.offhandAttackSpeed = nil;

	object:SetLabelAndValue(DAMAGE, damageText);	--RANGED_DAMAGE_TOOLTIP
end

function UpdateFunc.RangedAttackSpeed(object)
	if RANGE_WEAPON_EQUIPPED then
		local text = UnitRangedDamage("player");
		text = format("%.2f", text);
		object.tooltip = HIGHLIGHT_FONT_COLOR_CODE..ATTACK_SPEED.." "..text..FONT_COLOR_CODE_CLOSE;
		object:SetLabelAndValue(WEAPON_SPEED, text);
	else
		object.tooltip = nil;
		object:SetLabelAndValue(WEAPON_SPEED, NOT_APPLICABLE, true);
	end
	object.tooltip2 = format(CR_HASTE_RATING_TOOLTIP, GetCombatRating(CR_HASTE_RANGED), GetCombatRatingBonus(CR_HASTE_RANGED));
end

function UpdateFunc.RangedAttackPower(object)
	local base, posBuff, negBuff = UnitRangedAttackPower("player");

	object:SetLabelAndValue(ATTACK_POWER, base + posBuff + negBuff);
	PaperDollFormatStat(RANGED_ATTACK_POWER, base, posBuff, negBuff, object);

	local totalAP = base+posBuff+negBuff;
	object.tooltip2 = format(RANGED_ATTACK_POWER_TOOLTIP, max((totalAP), 0)/ATTACK_POWER_MAGIC_NUMBER);
	local petAPBonus = ComputePetBonus( "PET_BONUS_RAP_TO_AP", totalAP );
	if( petAPBonus > 0 ) then
		object.tooltip2 = object.tooltip2 .. "\n" .. format(PET_BONUS_TOOLTIP_RANGED_ATTACK_POWER, math.floor(petAPBonus));
	end

	local petSpellDmgBonus = ComputePetBonus( "PET_BONUS_RAP_TO_SPELLDMG", totalAP );
	if( petSpellDmgBonus > 0 ) then
		object.tooltip2 = object.tooltip2 .. "\n" .. format(PET_BONUS_TOOLTIP_SPELLDAMAGE, math.floor(petSpellDmgBonus));
	end
end

function UpdateFunc.RangedHitRating(object)
	PaperDollFrame_SetRating(object, CR_HIT_RANGED);
end

function UpdateFunc.RangedCritChance(object)
	local critChance = GetRangedCritChance();
	critChance = format("%.2f%%", critChance);
	object:SetLabelAndValue(RANGED_CRIT_CHANCE, critChance);
	object.tooltip = HIGHLIGHT_FONT_COLOR_CODE..RANGED_CRIT_CHANCE.." "..critChance..FONT_COLOR_CODE_CLOSE;
	object.tooltip2 = format(CR_CRIT_RANGED_TOOLTIP, GetCombatRating(CR_CRIT_RANGED), GetCombatRatingBonus(CR_CRIT_RANGED));
end


---- Stat Spell ----
local function SpellBonus_OnEnter(self)
	DefaultTooltip:Hide();
	DefaultTooltip:SetOwner(self, "ANCHOR_NONE");

	if self.statName == "SpellBonusDamage" then
		local minModifier = self.Value:GetText();
		DefaultTooltip:SetText(HIGHLIGHT_FONT_COLOR_CODE..BONUS_DAMAGE.." "..minModifier..FONT_COLOR_CODE_CLOSE);

		local bonusDamage, fireDamage, shadowDamage;

		for i= 2, MAX_SPELL_SCHOOLS do
			bonusDamage = GetSpellBonusDamage(i);
			DefaultTooltip:AddDoubleLine("|TInterface\\PaperDollInfoFrame\\SpellSchoolIcon"..i..":16|t " .. _G["DAMAGE_SCHOOL"..i], bonusDamage, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);

			if i == 3 then
				fireDamage = bonusDamage;
			elseif i == 6 then
				shadowDamage = bonusDamage;
			end
		end

		local petStr, damage;
		if shadowDamage > fireDamage then
			petStr = PET_BONUS_TOOLTIP_WARLOCK_SPELLDMG_SHADOW;
			damage = shadowDamage;
		else
			petStr = PET_BONUS_TOOLTIP_WARLOCK_SPELLDMG_FIRE;
			damage = fireDamage;
		end

		local petBonusAP = ComputePetBonus("PET_BONUS_SPELLDMG_TO_AP", damage );
		local petBonusDmg = ComputePetBonus("PET_BONUS_SPELLDMG_TO_SPELLDMG", damage );
		if petBonusAP > 0 or petBonusDmg > 0 then
			DefaultTooltip:AddLine("\n" .. format(petStr, petBonusAP, petBonusDmg), nil, nil, nil, 1);
		end

	elseif self.statName == "SpellCritChance" then
		DefaultTooltip:SetText(HIGHLIGHT_FONT_COLOR_CODE..COMBAT_RATING_NAME11.." "..GetCombatRating(11)..FONT_COLOR_CODE_CLOSE);

		local spellCrit;
		for i= 2, MAX_SPELL_SCHOOLS do
			spellCrit = GetSpellCritChance(i);
			spellCrit = format("%.2f%%", spellCrit);
			DefaultTooltip:AddDoubleLine("|TInterface\\PaperDollInfoFrame\\SpellSchoolIcon"..i..":16|t " .. _G["DAMAGE_SCHOOL"..i], spellCrit, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
		end
	end

	DefaultTooltip:SetPoint("TOPRIGHT", self,"TOPLEFT", -8, -8);
	DefaultTooltip:ShowTooltip();
end

function UpdateFunc.SpellBonusDamage(object)
	local minModifier = GetSpellBonusDamage(2);
	local bonusDamage;
	for i = 2, MAX_SPELL_SCHOOLS do
		bonusDamage = GetSpellBonusDamage(i);
		minModifier = min(minModifier, bonusDamage);
	end

	object:SetLabelAndValue(BONUS_DAMAGE, minModifier, minModifier == 0);
	object:SetScript("OnEnter", SpellBonus_OnEnter);
end

function UpdateFunc.SpellBonusHealing(object)
	local bonusHealing = GetSpellBonusHealing();
	object:SetLabelAndValue(BONUS_HEALING, bonusHealing, bonusHealing == 0);
	object.tooltip = HIGHLIGHT_FONT_COLOR_CODE .. BONUS_HEALING .. FONT_COLOR_CODE_CLOSE;
	object.tooltip2 =format(BONUS_HEALING_TOOLTIP, bonusHealing);
end

function UpdateFunc.SpellHitRating(object)
	PaperDollFrame_SetRating(object, CR_HIT_SPELL);
end

function UpdateFunc.SpellCritChance(object)
	local minCrit;

	local spellCrit;
	for i = 2, MAX_SPELL_SCHOOLS do
		spellCrit = GetSpellCritChance(i);
		if minCrit then
			minCrit = min(minCrit, spellCrit);
		else
			minCrit = spellCrit;
		end
	end

	minCrit = format("%.2f%%", minCrit);
	object:SetLabelAndValue(SPELL_CRIT_CHANCE, minCrit);
	object:SetScript("OnEnter", SpellBonus_OnEnter);
end

function UpdateFunc.SpellHaste(object)
	local rating = GetCombatRating(CR_HASTE_SPELL);
	object:SetLabelAndValue(SPELL_HASTE, rating, rating == 0);
	object.tooltip = HIGHLIGHT_FONT_COLOR_CODE .. SPELL_HASTE .. FONT_COLOR_CODE_CLOSE;
	object.tooltip2 = format(SPELL_HASTE_TOOLTIP, GetCombatRatingBonus(CR_HASTE_SPELL));
end


---- Stat Defense ----
function UpdateFunc.Armor(object)
	local unit = "player"
	local base, effectiveArmor, armor, posBuff, negBuff = UnitArmor(unit);

	object:SetLabelAndValue(ARMOR, effectiveArmor);
	PaperDollFormatStat(ARMOR, base, posBuff, negBuff, object);

	local armorReduction = PaperDollFrame_GetArmorReduction(effectiveArmor, UnitLevel(unit));
	object.tooltip2 = format(DEFAULT_STATARMOR_TOOLTIP, armorReduction);

	local petBonus = ComputePetBonus("PET_BONUS_ARMOR", effectiveArmor );
	if( petBonus > 0 ) then
		object.tooltip2 = object.tooltip2 .. "\n" .. format(PET_BONUS_TOOLTIP_ARMOR, petBonus);
	end
end

function UpdateFunc.Defense(object)
	local base, modifier = UnitDefense("player");
	local posBuff = 0;
	local negBuff = 0;
	if ( modifier > 0 ) then
		posBuff = modifier;
	elseif ( modifier < 0 ) then
		negBuff = modifier;
	end

	object:SetLabelAndValue(DEFENSE, max(0, base + posBuff + negBuff));
	PaperDollFormatStat(DEFENSE, base, posBuff, negBuff, object);

	local defensePercent = GetDodgeBlockParryChanceFromDefense();
	object.tooltip2 = format(DEFAULT_STATDEFENSE_TOOLTIP, GetCombatRating(CR_DEFENSE_SKILL), GetCombatRatingBonus(CR_DEFENSE_SKILL), defensePercent, defensePercent);
end

function UpdateFunc.Reduction(object)
	local unit = "player";
	local baselineArmor, effectiveArmor, armor, bonusArmor = UnitArmor(unit);

	local armorReduction = C_PaperDollInfo.GetArmorEffectiveness(effectiveArmor, UnitLevel(unit)) or 0;
	armorReduction = 100 * armorReduction;
	local armorReductionAgainstTarget = C_PaperDollInfo.GetArmorEffectivenessAgainstTarget(effectiveArmor);
	local armorReductionText = FormatPercentage(armorReduction);

	object.tooltip = "|cffffffff"..COMBAT_TEXT_SHOW_RESISTANCES_TEXT.." "..armorReductionText.."|r";
	object.tooltip2 = format(STAT_ARMOR_TOOLTIP, armorReduction);
	if STAT_ARMOR_TARGET_TOOLTIP and armorReductionAgainstTarget then
		object.tooltip3 = format(STAT_ARMOR_TARGET_TOOLTIP, 100*armorReductionAgainstTarget);
		armorReduction = 100 * armorReductionAgainstTarget;
	else
		object.tooltip3 = nil;
	end

	object:SetLabelAndValue(L["Damage Reduction Percentage"], armorReductionText, armorReduction == 0);
end

function UpdateFunc.Dodge(object)
	local chance = GetDodgeChance();
	local chanceText = format("%.2F%%", chance)
	object:SetLabelAndValue(STAT_DODGE, chanceText);

	object.tooltip = "|cffffffff".. DODGE_CHANCE .." "..format("%.2F", chance).."%".."|r";
	object.tooltip2 = format(CR_DODGE_TOOLTIP, GetCombatRating(CR_DODGE), GetCombatRatingBonus(CR_DODGE));
end

function UpdateFunc.Parry(object)
	local chance = GetParryChance();
	local chanceText = format("%.2F%%", chance);
	object:SetLabelAndValue(STAT_PARRY, chanceText);

	object.tooltip = "|cffffffff".. PARRY_CHANCE .." "..format("%.2F", chance).."%".."|r";
	object.tooltip2 = format(CR_PARRY_TOOLTIP, GetCombatRating(CR_PARRY), GetCombatRatingBonus(CR_PARRY));
end

function UpdateFunc.Block(object)
	local unit = "player";

	local chance = GetBlockChance();
	local chanceText = format("%.2F%%", chance);

	if chance ~= 0 and C_PaperDollInfo.OffhandHasShield() then
		object:SetLabelAndValue(STAT_BLOCK, chanceText);
	else
		object:SetLabelAndValue(STAT_BLOCK, chanceText, true);
	end

	object.tooltip = "|cffffffff".. BLOCK_CHANCE .." "..format("%.2F", chance).."%".."|r";
	object.tooltip2 = format(CR_BLOCK_TOOLTIP, GetCombatRating(CR_BLOCK), GetCombatRatingBonus(CR_BLOCK), GetShieldBlock());
end

function UpdateFunc.Resilience(object)
	local resilience = GetCombatRating(CR_RESILIENCE_CRIT_TAKEN);
	local bonus = GetCombatRatingBonus(CR_RESILIENCE_CRIT_TAKEN);
	object:SetLabelAndValue(STAT_RESILIENCE, resilience, resilience == 0);
	object.tooltip = HIGHLIGHT_FONT_COLOR_CODE..STAT_RESILIENCE.." "..resilience..FONT_COLOR_CODE_CLOSE;
	object.tooltip2 = format(RESILIENCE_TOOLTIP, bonus, min(bonus * 2, 25.00), bonus);
end



function UpdateFunc.Health(object, unit)
	if (not unit) then
		unit = "player";
	end
	local health = UnitHealthMax(unit);
	local healthText = FormatLargeNumbers(health);
	object.Label:SetText(HEALTH)
	object.Value:SetText(healthText)
	object.tooltip = "|cffffffff".. HEALTH .." "..healthText.."|r";
	if (unit == "player") then
		object.tooltip2 = STAT_HEALTH_TOOLTIP;
	elseif (unit == "pet") then
		object.tooltip2 = STAT_HEALTH_PET_TOOLTIP;
	end
	object:Show();
end

function UpdateFunc.Power(object)
	local unit = "player";
	local powerType, powerToken = UnitPowerType(unit);
	local power = UnitPowerMax(unit) or 0;
	local powerText = FormatLargeNumbers(power);
	local powerName = _G[powerToken];
	if (powerToken and powerName) then
		object.Label:SetText(powerName)
		object.Value:SetText(powerText)
		object.tooltip = "|cffffffff".. powerName .." "..powerText.."|r";
		object.tooltip2 = _G["STAT_"..powerToken.."_TOOLTIP"];
		object:Show();
	else
		object:SetLabelAndValue("Resource", "N/A", true);
	end
end

function UpdateFunc.Regen(object)
	local powerType, powerToken = UnitPowerType("player");
	local regenRate = GetPowerRegen();
	local regenRateText = BreakUpLargeNumbers(regenRate);
	local regenRatePerSec = format("%.2f", regenRate).."/s";
	local labelText;
	if powerToken == "ENERGY" then
		labelText = STAT_ENERGY_REGEN;
		object.tooltip2 = STAT_ENERGY_REGEN_TOOLTIP;
	elseif powerToken == "RUNES" then
		labelText = STAT_RUNE_REGEN;
		object.tooltip2 = STAT_RUNE_REGEN_TOOLTIP;
	elseif powerToken == "FOCUS" then
		labelText = STAT_FOCUS_REGEN;
		object.tooltip2 = STAT_FOCUS_REGEN_TOOLTIP;
	elseif UnitHasMana("player") then
		local base, casting = GetManaRegen();
		-- All mana regen stats are displayed as mana/5 sec.
		base = floor( base * 5.0 );
		casting = floor( casting * 5.0 );
		object:SetLabelAndValue(MANA_REGEN, base);
		object.tooltip = HIGHLIGHT_FONT_COLOR_CODE .. MANA_REGEN .. FONT_COLOR_CODE_CLOSE;
		object.tooltip2 = format(MANA_REGEN_TOOLTIP, base, casting);
		return
	else
		local _, class = UnitClass("player");
		if (class ~= "DEATHKNIGHT") then
			object:SetLabelAndValue(MANA_REGEN_COMBAT, "N/A", true);		--MANA_REGEN_ABBR
			return;
		end
		local _, regenRate = GetRuneCooldown(1);
		regenRateText = (format(STAT_RUNE_REGEN_FORMAT, regenRate));
		object:SetLabelAndValue(STAT_RUNE_REGEN, regenRateText);
		return;
	end
	if labelText then
		object.tooltip = "|cffffffff".. labelText .." "..regenRateText.."|r";
	end
	object:SetLabelAndValue(labelText, regenRatePerSec);
end

function UpdateFunc.Crit(object)
	if not Narci.refreshCombatRatings then return end;
	local critChance, rating = GetEffectiveCrit();

	object.tooltip = "|cffffffff".. STAT_CRITICAL_STRIKE .." "..format("%.2F%%", critChance).."|r";
	local extraCritChance = GetCombatRatingBonus(rating);
	local extraCritRating = GetCombatRating(rating);
	object.tooltip4 = nil;
	if false and (GetCritChanceProvidesParryEffect()) then	--##
		object.tooltip2 = format(CR_CRIT_PARRY_RATING_TOOLTIP, BreakUpLargeNumbers(extraCritRating), extraCritChance, GetCombatRatingBonusForCombatRatingValue(CR_PARRY, extraCritRating));
	else
		if extraCritChance == 0 then
			object.tooltip2 = format(CR_CRIT_TOOLTIP, BreakUpLargeNumbers(extraCritRating), extraCritChance);
		else
			object.tooltip2 = NARCI_CRIT_TOOLTIP;
			object.tooltip4 = {format(NARCI_CRIT_TOOLTIP_FORMAT, BreakUpLargeNumbers(extraCritRating), extraCritChance), floor( (extraCritRating / extraCritChance) * 100 + 0.5) / 100 .. " [+1%]"}
		end
	end

	local PercentageText = FormatPercentage(critChance);
	object.Label:SetText(NARCI_CRITICAL_STRIKE);		--COMBAT_RATING_NAME10
	object.Value:SetText(PercentageText);
end

function UpdateFunc.Haste(object)
	if not Narci.refreshCombatRatings then return end;
	local unit = "player";
	local haste = GetHaste();
	local rating = CR_HASTE_MELEE;
	local hasteFormatString;

	if (haste < 0 and not GetPVPGearStatRules()) then
		hasteFormatString = RED_FONT_COLOR_CODE.."%s".."|r";
	else
		hasteFormatString = "%s";
	end

	object.tooltip = "|cffffffff" .. STAT_HASTE .. " " .. format(hasteFormatString, format("%.2F%%", haste)) .. "|r";

	local _, class = UnitClass(unit);
	object.tooltip2 = _G["STAT_HASTE_"..class.."_TOOLTIP"];
	if (not object.tooltip2) then
		object.tooltip2 = STAT_HASTE_TOOLTIP;
	end

	local Rating = GetCombatRating(rating);
	local RatingBonus = GetCombatRatingBonus(rating);
	if RatingBonus == 0 then
		object.tooltip2 = object.tooltip2 .. format(STAT_HASTE_BASE_TOOLTIP, BreakUpLargeNumbers(Rating), RatingBonus);
		object.tooltip4 = nil;
	else
		object.tooltip4 = {format(NARCI_HASTE_TOOLTIP_FORMAT, BreakUpLargeNumbers(Rating), RatingBonus), floor( (Rating / RatingBonus) * 100 + 0.5) / 100 .. " [+1%]"};
	end

	object.Label:SetText(STAT_HASTE);
	object.Value:SetText(FormatPercentage(haste));
end

function UpdateFunc.MovementSpeed(object)
	local unit = "player";

	object.wasSwimming = nil;
	object.unit = unit;
	object.t = 0;
	MovementSpeed_OnUpdate(object, 1);
	object:SetScript("OnEnter", MovementSpeed_OnEnter);
	object:SetScript("OnUpdate", MovementSpeed_OnUpdate);
end

function UpdateFunc.Strengh(object)
	local effectiveStat = UpdateFunc.Primary(object, 1);

	local attackPower = GetAttackPowerForStat(1, effectiveStat);
	object.tooltip2 = format(object.tooltipFormat, attackPower);
	if ( PLAYER_CLASS == "WARRIOR" or PLAYER_CLASS == "SHAMAN" or PLAYER_CLASS == "PALADIN" ) then
		object.tooltip2 = object.tooltip2 .. "\n" .. format(STAT_BLOCK_TOOLTIP, effectiveStat * BLOCK_PER_STRENGTH);
	end
end

function UpdateFunc.Agility(object)
	local effectiveStat = UpdateFunc.Primary(object, 2);

	local attackPower = GetAttackPowerForStat(2, effectiveStat);
	if ( attackPower > 0 ) then
		object.tooltip2 = format(STAT_ATTACK_POWER, attackPower) .. format(object.tooltipFormat, GetCritChanceFromAgility("player"), effectiveStat*ARMOR_PER_AGILITY);
	else
		object.tooltip2 = format(object.tooltipFormat, GetCritChanceFromAgility("player"), effectiveStat*ARMOR_PER_AGILITY);
	end
end

function UpdateFunc.Stamina(object)
	local effectiveStat = UpdateFunc.Primary(object, 3);

	local baseStam = min(20, effectiveStat);
	local moreStam = effectiveStat - baseStam;
	object.tooltip2 = format(object.tooltipFormat, (baseStam + (moreStam*HEALTH_PER_STAMINA))*GetUnitMaxHealthModifier("player"));
	local petStam = ComputePetBonus("PET_BONUS_STAM", effectiveStat);
	if( petStam > 0 ) then
		object.tooltip2 = object.tooltip2 .. "\n" .. format(PET_BONUS_TOOLTIP_STAMINA, petStam);
	end
end

function UpdateFunc.Intellect(object)
	local effectiveStat = UpdateFunc.Primary(object, 4);

	local baseInt = min(20, effectiveStat);
	local moreInt = effectiveStat - baseInt;

	if ( UnitHasMana("player") ) then
		object.tooltip2 = format(object.tooltipFormat, baseInt + moreInt*MANA_PER_INTELLECT, GetSpellCritChanceFromIntellect("player"));
	else
		local stat = "INTELLECT";
		local _, classFileName = UnitClass("player");
		local classStatText = _G[string.upper(classFileName).."_"..stat.."_".."TOOLTIP"];

		if ( not classStatText ) then
			classStatText = _G["DEFAULT".."_"..stat.."_".."TOOLTIP"];
		end

		object.tooltip2 = classStatText;
	end

	local petInt = ComputePetBonus("PET_BONUS_INT", effectiveStat);
	if( petInt > 0 ) then
		if ( not object.tooltip2 ) then
			object.tooltip2 = "";
		end
		object.tooltip2 = object.tooltip2 .. "\n" .. format(PET_BONUS_TOOLTIP_INTELLECT, petInt);
	end
end

function UpdateFunc.Spirit(object)
	UpdateFunc.Primary(object, 5);

	-- All mana regen stats are displayed as mana/5 sec.
	object.tooltip2 = format(object.tooltipFormat, GetUnitHealthRegenRateFromSpirit("player"));
	if ( UnitHasMana("player") ) then
		local regen = GetUnitManaRegenRateFromSpirit("player");
		regen = floor( regen * 5.0 );
		object.tooltip2 = object.tooltip2.."\n"..format(MANA_REGEN_FROM_SPIRIT, regen);
	end
end

function UpdateFunc.Null(object)
	UpdateFunc.Primary(object, 5);
end

local function Mastery_OnEnter(object)
	local CR_MASTERY = 26;

	DefaultTooltip:SetOwner(object, "ANCHOR_NONE");

	local _, class = UnitClass("player");
	local mastery = GetMastery();
	local masteryBonus = GetCombatRatingBonus(CR_MASTERY);
	local title = HIGHLIGHT_FONT_COLOR_CODE..format(PAPERDOLLFRAME_TOOLTIP_FORMAT, STAT_MASTERY).." "..format("%.2F", mastery)..FONT_COLOR_CODE_CLOSE;
	if (masteryBonus > 0) then
		title = title..HIGHLIGHT_FONT_COLOR_CODE.." ("..format("%.2F", mastery-masteryBonus)..FONT_COLOR_CODE_CLOSE..GREEN_FONT_COLOR_CODE.."+"..format("%.2F", masteryBonus)..FONT_COLOR_CODE_CLOSE..HIGHLIGHT_FONT_COLOR_CODE..")";
	end

	DefaultTooltip:SetText(title);

	local masteryKnown = IsSpellKnown(CLASS_MASTERY_SPELLS[class]);
	local primaryTalentTree = GetPrimaryTalentTree();
	if (masteryKnown and primaryTalentTree) then
		local masterySpell, masterySpell2 = GetTalentTreeMasterySpells(primaryTalentTree);
		if (masterySpell) then
			DefaultTooltip:AddSpellByID(masterySpell);
		end
		if (masterySpell2) then
			DefaultTooltip:AddLine(" ");
			DefaultTooltip:AddSpellByID(masterySpell2);
		end
		DefaultTooltip:AddLine(" ");
		DefaultTooltip:AddLine(format(STAT_MASTERY_TOOLTIP, GetCombatRating(CR_MASTERY), masteryBonus), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true);
	else
		DefaultTooltip:AddLine(format(STAT_MASTERY_TOOLTIP, GetCombatRating(CR_MASTERY), masteryBonus), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true);
		DefaultTooltip:AddLine(" ");
		if (masteryKnown) then
			DefaultTooltip:AddLine(STAT_MASTERY_TOOLTIP_NO_TALENT_SPEC, GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b, true);
		else
			DefaultTooltip:AddLine(STAT_MASTERY_TOOLTIP_NOT_KNOWN, GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b, true);
		end
	end

	DefaultTooltip:SetPoint("TOPRIGHT", object, "TOPLEFT", -4, 0)
	DefaultTooltip:ShowTooltip();
end

function UpdateFunc.Mastery(object)
	local labelText = STAT_MASTERY;
	local mastery = GetMastery();
	mastery = format("%.2F", mastery);
	object:SetLabelAndValue(labelText, mastery);
	object:SetScript("OnEnter", Mastery_OnEnter);
end


local function ResistanceFrame_OnEnter(self)
	if self.nonZero then
		self.Icon:SetVertexColor(1, 1, 1);
	else
		self.Icon:SetVertexColor(0.7, 0.7, 0.7);
		self.Icon:SetDesaturation(0.5);
	end

	DefaultTooltip:SetOwner(self, "ANCHOR_NONE");

	local base, resistance, positive, negative = UnitResistance("player", self.id);
	local petBonus = ComputePetBonus( "PET_BONUS_RES", resistance );

	local resistanceName = _G["RESISTANCE"..(self.id).."_NAME"];
	local line1 = resistanceName.." "..resistance;

	if ( positive ~= 0 or negative ~= 0 ) then
		line1 = line1.. " ( "..HIGHLIGHT_FONT_COLOR_CODE..base;
		if( positive > 0 ) then
			line1 = line1..GREEN_FONT_COLOR_CODE.." +"..positive;
		end
		if( negative < 0 ) then
			line1 = line1.." "..RED_FONT_COLOR_CODE..negative;
		end
		line1 = line1..FONT_COLOR_CODE_CLOSE.." )";
	end
	DefaultTooltip:SetText(line1, 1, 1, 1);

	local unitLevel = UnitLevel("player");
	unitLevel = max(unitLevel, 20);
	local magicResistanceNumber = resistance / unitLevel;
	local resistanceLevel;
	if ( magicResistanceNumber > 5 ) then
		resistanceLevel = RESISTANCE_EXCELLENT;
	elseif ( magicResistanceNumber > 3.75 ) then
		resistanceLevel = RESISTANCE_VERYGOOD;
	elseif ( magicResistanceNumber > 2.5 ) then
		resistanceLevel = RESISTANCE_GOOD;
	elseif ( magicResistanceNumber > 1.25 ) then
		resistanceLevel = RESISTANCE_FAIR;
	elseif ( magicResistanceNumber > 0 ) then
		resistanceLevel = RESISTANCE_POOR;
	else
		resistanceLevel = RESISTANCE_NONE;
	end

	local subText = format(RESISTANCE_TOOLTIP_SUBTEXT, _G["RESISTANCE_TYPE"..self.id], unitLevel, resistanceLevel);
	if( petBonus > 0 ) then
		subText = subText .. "\n" .. format(PET_BONUS_TOOLTIP_RESISTANCE, petBonus);
	end

	DefaultTooltip:AddLine(subText, 1, 0.82, 0, true);
	DefaultTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 8, -8);
	DefaultTooltip:ShowTooltip();
end

local function ResistanceFrame_OnLeave(self)
	Narci:HideButtonTooltip();

	if self.nonZero then
		self.Icon:SetVertexColor(0.8, 0.8, 0.8);
	else
		self.Icon:SetVertexColor(0.5, 0.5, 0.5);
		self.Icon:SetDesaturation(1);
	end
end

local STAT_CVAR_MAPPING = {
	PLAYERSTAT_MELEE_COMBAT = 1,	--melee
	PLAYERSTAT_RANGED_COMBAT = 2,	--ranged
	PLAYERSTAT_SPELL_COMBAT = 3,	--spell
	PLAYERSTAT_DEFENSES = 4,		--defense
};

local function GetDefaultStatTabID()
	local stat1 = GetCVar("playerStatLeftDropdown");
	local stat2 = GetCVar("playerStatRightDropdown");
	--print("StatDropdown", stat1, stat2);

	local stat;

	if stat1 and stat1 ~= "PLAYERSTAT_BASE_STATS" then
		stat = stat1;
	elseif stat2 and stat2 ~= "PLAYERSTAT_BASE_STATS" then
		stat = stat2;
	end

	if (not stat) or (not STAT_CVAR_MAPPING[stat]) then
		if ( PLAYER_CLASS == "MAGE" or PLAYER_CLASS == "PRIEST" or PLAYER_CLASS == "WARLOCK" or PLAYER_CLASS == "DRUID" ) then
			stat = "PLAYERSTAT_SPELL_COMBAT";
		elseif ( PLAYER_CLASS == "HUNTER" ) then
			stat = "PLAYERSTAT_RANGED_COMBAT";
		else
			stat = "PLAYERSTAT_MELEE_COMBAT";
		end
	end

	return STAT_CVAR_MAPPING[stat];
end

---------------------------------------------------------------------------
NarciAttributeMixin = {};

function NarciAttributeMixin:Update()
	if self.updateFunc then
		self.updateFunc(self);
	end
end

function NarciAttributeMixin:SetLabelAndValue(label, value, grey)
	self.Label:SetText(label);
	self.Value:SetText(value);
	if grey then
		self.Label:SetTextColor(0.5, 0.5, 0.5);
		self.Value:SetTextColor(0.5, 0.5, 0.5);
	else
		self.Label:SetTextColor(0.92, 0.92, 0.92);
		self.Value:SetTextColor(0.92, 0.92, 0.92);
	end
end

---------------------------------------------------------------------------
--Create attribute button from schematics

local LAYOUTS = {
	vital = {"Health", "Power"},
	base = {"Strengh", "Agility", "Stamina", "Intellect", "Spirit", "Armor"},
	melee = {"MeleeDamage", "MeleeAttackSpeed", "MeleeAttackPower", "MeleeHitRating", "MeleeCritChance", "Expertise"},
	ranged = {"RangedDamage", "RangedAttackSpeed", "RangedAttackPower", "RangedHitRating", "RangedCritChance"},
	spell = {"SpellBonusDamage", "SpellBonusHealing", "SpellHitRating", "SpellCritChance", "SpellHaste", "Regen"},
	defense = {"Defense", "Reduction", "Dodge", "Parry", "Block", "Resilience"},
};

do
    local expansionID = NarciClassicAPI.GetExpansionID();
    if expansionID == 1 then
		LAYOUTS = {
			vital = {"Health", "Power"},
			base = {"Strengh", "Agility", "Stamina", "Intellect", "Spirit", "Armor"},
			melee = {"MeleeDamage", "MeleeAttackSpeed", "MeleeAttackPower", "MeleeHitRating_Vanilla", "MeleeCritChance"},
			ranged = {"RangedDamage", "RangedAttackSpeed", "RangedAttackPower", "RangedHitRating_Vanilla", "RangedCritChance"},
			spell = {"SpellBonusDamage", "SpellBonusHealing", "SpellHitRating_Vanilla", "SpellCritChance", "SpellHaste", "Regen"},
			defense = {"Defense", "Reduction", "Dodge", "Parry", "Block"},
		};
	elseif expansionID == 3 then
		GetHitTooltipText = GetHitTooltip_Wrath;
	elseif expansionID == 4 then
		table.insert(LAYOUTS.melee, "Mastery");
		table.insert(LAYOUTS.ranged, "Mastery");
		table.insert(LAYOUTS.spell, "Mastery");
    end
end

local AttributeController = {};
Narci.AttributeController = AttributeController;

AttributeController.buttons = {};
AttributeController.magicRes = {};
AttributeController.delayDivisor = 20;

function AttributeController:PlayFadeIn()
	for i, b in ipairs(self.buttons) do
		b.animIn:Play();
	end
end

function AttributeController:SetFadeInDelay(divisor)
	AttributeController.delayDivisor = divisor;

	for i, b in ipairs(self.buttons) do
		b.animIn.A2:SetStartDelay( i / divisor );
	end
end

function AttributeController:ResetLayout()
	for i, b in ipairs(self.buttons) do
		b:Hide();
		b:ClearAllPoints();
	end
	self.numButtons = 0;
end

function AttributeController:ResetOptionalStats()
	for i = self.numStaticButtons + 1, #self.buttons do
		self.buttons[i]:Hide();
		self.buttons[i]:ClearAllPoints();
	end
	self.numButtons = self.numStaticButtons;
end

function AttributeController:BuildResistanceFrame()
	if not self.magicRes[1] then
		local numTypes = 5;
		local width = 240 / numTypes;
		local f;
		local textures = {
			136116, 135805, 136085, 135865, 136121,
		};
		local parent = Narci_Attribute;

		for i = 1, numTypes do
			self.magicRes[i] = CreateFrame("Frame", nil, parent);
			f = self.magicRes[i];
			f:SetSize(width, 24);

			f.Icon = f:CreateTexture(nil, "ARTWORK");
			f.Icon:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0);
			f.Icon:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0);
			f.Icon:SetTexture(textures[i]);
			f.Icon:SetTexCoord(0.1, 0.9, 0.3, 0.7);
			f.Icon:SetVertexColor(0.5, 0.5, 0.5);

			f.Value = f:CreateFontString(nil, "OVERLAY", "NarciFontStatusNumber");
			f.Value:SetPoint("CENTER", f, "CENTER", 0, 0);
			f.Value:SetJustifyH("CENTER");
			f.Value:SetText(0);

			f.Shadow = f:CreateTexture(nil, "ARTWORK", nil, 2);
			f.Shadow:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0);
			f.Shadow:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0);
			f.Shadow:SetTexture("Interface/AddOns/Narcissus/Art/Modules/CharacterFrame/MagicResistance/TextShadow");

			if i > 1 then
				self.magicRes[i]:SetPoint("LEFT", self.magicRes[i - 1], "RIGHT", 0, 0);
				f.id = i;
			else
				f.id = 6;	--6 arcane, 1 Holy
			end
			f:SetScript("OnEnter", ResistanceFrame_OnEnter);
			f:SetScript("OnLeave", ResistanceFrame_OnLeave);
		end
	end

	local offset = 0;	-- -24
	self.magicRes[1]:ClearAllPoints();
	self.magicRes[1]:SetPoint("TOPLEFT", self.buttons[self.numButtons], "BOTTOMLEFT", 0, offset);
end

function AttributeController:Build(layoutName, initialOffsetY, idOffset)
	local layout = LAYOUTS[layoutName];

	if not layout then
		print("Invalid Arribute Layout");
		return
	end

	idOffset = idOffset or 0;

	local parent = Narci_Attribute;
	local numButtons = self.numButtons;

	local button;

	for id, statName in ipairs(layout) do
		numButtons = numButtons + 1;

		button = self.buttons[numButtons];
		if not button then
			self.buttons[numButtons] = CreateFrame("Frame", nil, parent, "Narci_AttributeTemplate");
			button = self.buttons[numButtons];
			button.animIn.A2:SetStartDelay( numButtons / self.delayDivisor );
			button:SetID(id + idOffset);
			Narci_AttributeFrame_UpdateBackgroundColor(button);
		end

		button:ClearAllPoints();
		if id == 1 then
			initialOffsetY = initialOffsetY or 0;
			if numButtons == 1 then
				button:SetPoint("TOP", Narci_ItemLevelFrame, "BOTTOM", 0, initialOffsetY);

				NarciEquipmentSetManager:SetParentMode("narcissus");
				NarciEquipmentSetManager:ClearAllPoints();
				NarciEquipmentSetManager:SetPoint("TOPLEFT", Narci_ItemLevelFrame, "BOTTOM", 48, -24);
			else
				button:SetPoint("TOP", self.buttons[numButtons - 1], "BOTTOM", 0, initialOffsetY);
			end
		else
			button:SetPoint("TOP", self.buttons[numButtons - 1], "BOTTOM", 0, 0);
		end

		button:SetScript("OnEnter", Narci_ShowStatTooltip);
		button:SetID(id + idOffset);
		button.updateFunc = UpdateFunc[statName];
		button.statName = statName;

		button:Show();
	end

	self.numButtons = numButtons;
	self.bottomButton = button;
end

local function ShowOptionalStats(index)
	local ac = AttributeController;

	ac:ResetOptionalStats();

	local y = -24.0;

	if index == 1 then
		ac:Build("melee", -24 + y, 1);
	elseif index == 2 then
		ac:Build("ranged", -24 + y, 1);
	elseif index == 3 then
		ac:Build("spell", -24 + y, 1);
	elseif index == 4 then
		ac:Build("defense", -24 + y, 1);
	end

	for i = ac.numStaticButtons + 1, #ac.buttons do
		ac.buttons[i]:Update();
	end

	--Re-anchor
	ac:BuildResistanceFrame();
end

function AttributeController:Initialize()
	self:ResetLayout();
	self:Build("vital", -24);
	self:Build("base", -24.0);
	self.numStaticButtons = self.numButtons;

	local attributeNames = {
		PLAYERSTAT_MELEE_COMBAT, PLAYERSTAT_RANGED_COMBAT, PLAYERSTAT_SPELL_COMBAT, PLAYERSTAT_DEFENSES,
	};

	local defaultTabID = GetDefaultStatTabID();
	NavBarStat = addon.CreateNavBar(240, Narci_Attribute, "TOP", self.bottomButton, "BOTTOM", 0, -24.0, attributeNames, ShowOptionalStats, defaultTabID);
	NavBarStat:SetHitRectInsets(0, 0, 0, -24 * 6);

	self:BuildResistanceFrame();
end

function AttributeController:UpdateResistance()
	local anyRes;
	local base, resistance, positive, negative;

	for i, f in ipairs(self.magicRes) do
		base, resistance, positive, negative = UnitResistance("player", f.id);
		if resistance > 0 then
			f.Value:SetText(resistance);
			f.Value:SetTextColor(0.92, 0.92, 0.92);
			f.Icon:SetDesaturation(0);
			f.Icon:SetVertexColor(0.8, 0.8, 0.8);
			f.nonZero = true;
		else
			f.Value:SetText(nil);
			f.Value:SetTextColor(0.5, 0.5, 0.5);
			f.Icon:SetDesaturation(1);
			f.Icon:SetVertexColor(0.5, 0.5, 0.5);
			f.nonZero = nil;
		end

		if positive > 0 then	--don't show UI if the only source of resistance is from racials
			anyRes = true;
		end
	end

	--if no resistance, hide this frame
	--ignore racial resistance
	if anyRes then
		for i, f in ipairs(self.magicRes) do
			f:Show();
		end
	else
		for i, f in ipairs(self.magicRes) do
			f:Hide();
		end
	end
end

function AttributeController:InstantRefresh()
	for i, b in ipairs(self.buttons) do
		b:Update();
	end
	self:UpdateResistance();
end

function AttributeController:SetFrameOffset(offsetX)
	if self.buttons[1] then
		self.buttons[1]:SetPoint("TOP", Narci_ItemLevelFrame, "BOTTOM", offsetX, -24);		--96 EquipmentSetManager Offset
	end
end

function AttributeController:GetNavButtons()
	return NavBarStat.navButtons
end


do	--Hit Chance Calculator (Classic Era)
	local GetHitModifier = GetHitModifier;
	local GetSpellHitModifier = GetSpellHitModifier;
	local GetTalentInfo = GetTalentInfo;
	local GetTalentTabInfo = GetTalentTabInfo;
	local FindAura = AuraUtil.FindAura;
	local tinsert = table.insert;
	local band = bit.band;

	local function FormatHitChance(value)
		return format("%.0f", value).."%"
	end

	HitCalculator.HitBuffs = {
		[6562] = 1,
		[28878] = 1,

		--[132333] = 1,	--debug
	};

	HitCalculator.HitEnchants_Ranged = {
		--Extra Enchant ID (SpellItemEnchantment dbc)
		--[enchantID] = {itemID, value}
		[2523] = {18283, 3},		--Biznicks 247x128 Accurascope (Ranged Only)
	};

	HitCalculator.ClassTalents = {
		--{hitType, tabIndex, talentIndex, {value1, value2, ... (depended on the rank)}, affectSpellTypes = {talentIndex1, ...}}
		--hitType (bit 000 Melee/Ranged/Spell): 1(Spell), 2(Ranged), 4(Melee), 6(M/R), 5(M/S), 7(ALL), 3(R/S)
		HUNTER = {
			{type = 7, tab = 3, index = 8, ranks = {1, 2, 3}},			--Surefooted (3)
		},

		ROGUE = {
			{type = 4, tab = 2, index = 1, ranks = {1, 2, 3, 4, 5}},		--Precision (5)
		},

		SHAMAN = {
			{type = 5, tab = 3, index = 3, ranks = {1, 2, 3}},			--Nature's Guidance (3)
		},

		PALADIN = {
			{type = 4, tab = 2, index = 15, ranks = {1, 2, 3}},			--Precision (3)
		},

		WARLOCK = {
			{type = 1, tab = 1, index = 5, ranks = {2, 4, 6, 8, 10}, affectSpellTypes = {1}},			--Suppression (5) Affliction only
		},

		PRIEST = {
			{type = 1, tab = 3, index = 3, ranks = {2, 4, 6, 8, 10}, affectSpellTypes = {3}},			--Shadow Focus (5) Shadow only
		},

		MAGE = {
			{type = 1, tab = 1, index = 3, ranks = {2, 4, 6, 8, 10}, affectSpellTypes = {1}},			--Arcane Focus (5) Arcane only
			{type = 1, tab = 3, index = 17, ranks = {2, 4, 6}, affectSpellTypes = {2, 3}},				--Elemental Precision (3) Fire/Frost
		},
	};

	HitCalculator.PlayerTalents = HitCalculator.ClassTalents[PLAYER_CLASS];

	HitCalculator.BIT_MELEE = 4;
	HitCalculator.BIT_RANGED = 2;
	HitCalculator.BIT_SPELL = 1;

	function HitCalculator:GetHitFromBuff()
		local bonus = 0;
		local buffs = {};
		local value;

		local function predicate(arg1, arg2, arg3, spellName, spellID)
			value = self.HitBuffs[spellID];
			if value then
				tinsert(buffs, {spellName, FormatHitChance(value)});
				bonus = bonus + value;
			end
		end

		FindAura(predicate, "player", "HELPFUL");

		return bonus, buffs
	end

	function HitCalculator:GetHitFromEnchant(slotID)
		--Ranged only
		local bonus = 0;
		local enchants = {};

		if not (slotID and self.HitEnchants) then
			return bonus, enchants
		end

		local itemLink = GetInventoryItemLink("player", slotID);
		if itemLink then
			local extraEnchantID = string.match(itemLink, ":(%d+):|h");
			if extraEnchantID then
				extraEnchantID = tonumber(extraEnchantID);
				local info = self.HitEnchants[extraEnchantID];
				if info then
					local name = C_Item.GetItemNameByID(info[1]) or (ENSCRIBE or "Enchant");
					bonus = bonus + info[2];
					tinsert(enchants, {name, FormatHitChance(bonus)});
				end
			end
		end

		return bonus, enchants
	end

	function HitCalculator:GetHitFromTalent(damageTypeBitValue)
		local bonus = 0;
		local talents = {};

		if self.PlayerTalents then
			local _, name, rank, value, specName;
			for _, info in ipairs(self.PlayerTalents) do
				name, _, _, _, rank = GetTalentInfo(info.tab, info.index);
				if rank and rank > 0 then
					value = info.ranks[rank] or 0;
					if value > 0 then
						if band(info.type, damageTypeBitValue) == damageTypeBitValue then
							if info.affectSpellTypes then
								for _, talentTabIndex in ipairs(info.affectSpellTypes) do
									_, specName = GetTalentTabInfo(talentTabIndex);
									tinsert(talents, {name, "("..specName..") "..FormatHitChance(value)});
								end
							else
								bonus = bonus + value;
								tinsert(talents, {name, FormatHitChance(value)});
							end
						end
					end
				end
			end
		end

		return bonus, talents
	end

	function HitCalculator:Setup(object, labelText, tooltipFormat, slotID, damageTypeBitValue)
		local base;
		if damageTypeBitValue == self.BIT_SPELL then
			base = GetSpellHitModifier();
		else
			base = GetHitModifier()
		end
		base = base or 0;

		local bonusFromEnchant, enchants = self:GetHitFromEnchant(slotID);
		local bonusFromTalent, talents = HitCalculator:GetHitFromTalent(damageTypeBitValue);
		local bonusFromBuff, buffs = HitCalculator:GetHitFromBuff();
		local total = base + bonusFromEnchant + bonusFromTalent + bonusFromBuff;
		local valueText = FormatPercentage(total);

		object.tooltip = labelText.." "..valueText;

		local tooltip2 = {};

		if tooltipFormat then
			tinsert(tooltip2, {
				leftText = format(tooltipFormat, UnitLevel("player"), total),
			});
		end

		local anyBonus = total > 0;

		if bonusFromEnchant > 0 or (bonusFromTalent > 0 or #talents > 0) or bonusFromBuff > 0 then
			anyBonus = true;
			tinsert(tooltip2, {leftText = " "});
			if base > 0 then
				tinsert(tooltip2, {
					leftText = BANK_TAB_ASSIGN_EQUIPMENT_CHECKBOX or "Item",
					rightText = FormatPercentage(base),
				});
			end
			if bonusFromEnchant > 0 then
				for _, info in ipairs(enchants) do
					tinsert(tooltip2, {
						leftText = info[1],
						rightText = info[2],
					});
				end
			end
			if (bonusFromTalent > 0 or #talents > 0) then
				for _, info in ipairs(talents) do
					tinsert(tooltip2, {
						leftText = info[1],
						rightText = info[2],
					});
				end
			end
			if bonusFromBuff > 0 then
				for _, info in ipairs(buffs) do
					tinsert(tooltip2, {
						leftText = info[1],
						rightText = info[2],
					});
				end
			end
		end

		object.tooltip2 = tooltip2;

		object:SetLabelAndValue(labelText, valueText, not anyBonus);
	end

	function UpdateFunc.MeleeHitRating_Vanilla(object)
		HitCalculator.HitEnchants = nil;
		HitCalculator:Setup(object, _G["COMBAT_RATING_NAME"..CR_HIT_MELEE], _G.CR_HIT_MELEE_TOOLTIP, nil, HitCalculator.BIT_MELEE);
	end

	function UpdateFunc.RangedHitRating_Vanilla(object)
		HitCalculator.HitEnchants = HitCalculator.HitEnchants_Ranged;
		local rangedSlot = 18;
		HitCalculator:Setup(object, _G["COMBAT_RATING_NAME"..CR_HIT_RANGED], _G.CR_HIT_RANGED_TOOLTIP, rangedSlot, HitCalculator.BIT_RANGED);
	end

	function UpdateFunc.SpellHitRating_Vanilla(object)
		HitCalculator.HitEnchants = nil;
		HitCalculator:Setup(object, _G["COMBAT_RATING_NAME"..CR_HIT_SPELL], _G.CR_HIT_SPELL_TOOLTIP, nil, HitCalculator.BIT_SPELL);
	end


	--debug
	--[[
	function OVR()
		function PlayerTalentFrameTalent_OnEnter(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			local tab = PanelTemplates_GetSelectedTab(PlayerTalentFrame);
			local id = self:GetID();
			GameTooltip:SetTalent(tab, id, PlayerTalentFrame.inspect, PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup, GetCVarBool("previewTalentsOption"));
			local name, icon, tier, column, rank, maxRank = GetTalentInfo(tab, id);
			GameTooltip:AddLine(name);
			GameTooltip:AddDoubleLine(tab, id);
			GameTooltip:Show();
			self.UpdateTooltip = PlayerTalentFrameTalent_OnEnter;
		end
	end
	--]]
end