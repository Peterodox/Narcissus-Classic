local _, addon = ...

local EXPANSION_ID;
local PLAYER_ARMOR_TYPE = 1;	--1-4  Cloth-Leather-Mail-Plate
local PLAYER_ARMOR_TYPE_NAME = "Cloth";

do
	local _, _, _, tocVersion = GetBuildInfo();
	EXPANSION_ID = tonumber(string.sub(tocVersion, 0, 1)) or 1;
	addon.expansionID = EXPANSION_ID;

	local className, clssFileName, classID = UnitClass("player");
	local armorItemID;

	if classID == 1 or classID == 2 or classID == 6 then
		PLAYER_AMROR_TYPE = 4;
		armorItemID = 7930;
	elseif classID == 3 or classID == 7 then
		PLAYER_AMROR_TYPE = 3;
		armorItemID = 4922;
	elseif classID == 4 or classID == 10 or classID == 11 or classID == 12 then
		PLAYER_AMROR_TYPE = 2;
		armorItemID = 4929;
	else
		PLAYER_AMROR_TYPE = 1;
		armorItemID = 4916;
	end

	_, _, PLAYER_ARMOR_TYPE_NAME = GetItemInfoInstant(armorItemID);
end


NarciClassicAPI = {};
addon.ClassicAPI = NarciClassicAPI;

NarciClassicAPI.GetExpansionID = function()
	return EXPANSION_ID
end

NarciClassicAPI.GetPlayerArmorTypeID = function()
	return PLAYER_ARMOR_TYPE
end

NarciClassicAPI.GetPlayerArmorTypeName = function()
	return PLAYER_ARMOR_TYPE_NAME
end

function NarciClassicAPI.GetExpansionName(id)
	id = (id or EXPANSION_ID) - 1;

	if _G["EXPANSION_NAME"..id] then
		return _G["EXPANSION_NAME"..id]
	else
		return "Expansion #"..id
	end
end



local EquipmentManager = {};
NarciClassicAPI.EquipmentManager = EquipmentManager;

local bit = bit;
local ITEM_INVENTORY_LOCATION_PLAYER = ITEM_INVENTORY_LOCATION_PLAYER;
local ITEM_INVENTORY_LOCATION_BANK = ITEM_INVENTORY_LOCATION_BANK;
local ITEM_INVENTORY_LOCATION_BAGS = ITEM_INVENTORY_LOCATION_BAGS;
local ITEM_INVENTORY_LOCATION_VOIDSTORAGE = ITEM_INVENTORY_LOCATION_VOIDSTORAGE;
local ITEM_INVENTORY_BAG_BIT_OFFSET = ITEM_INVENTORY_BAG_BIT_OFFSET;
local GetInventoryItemID = GetInventoryItemID;
local GetItemInfoInstant = GetItemInfoInstant;
local GetItemCount = GetItemCount;

local EQUIP_ITEM = 1;
local UNEQUIP_ITEM = 2;
local SWAP_ITEM = 3;

local function EquipmentManager_UnpackLocation (location)	--Copied from Retail
	if ( location < 0 ) then
		return false, false, false, 0;
	end

	local player = (bit.band(location, ITEM_INVENTORY_LOCATION_PLAYER) ~= 0);
	local bank = (bit.band(location, ITEM_INVENTORY_LOCATION_BANK) ~= 0);
	local bags = (bit.band(location, ITEM_INVENTORY_LOCATION_BAGS) ~= 0);
	local voidStorage = (bit.band(location, ITEM_INVENTORY_LOCATION_VOIDSTORAGE) ~= 0);
	local tab, voidSlot;
	if ( player ) then
		location = location - ITEM_INVENTORY_LOCATION_PLAYER;
	elseif ( bank ) then
		location = location - ITEM_INVENTORY_LOCATION_BANK;
	elseif ( voidStorage ) then
		location = location - ITEM_INVENTORY_LOCATION_VOIDSTORAGE;
		tab = bit.rshift(location, ITEM_INVENTORY_BAG_BIT_OFFSET);
		voidSlot = location - bit.lshift(tab, ITEM_INVENTORY_BAG_BIT_OFFSET);
	end

	if ( bags ) then
		location = location - ITEM_INVENTORY_LOCATION_BAGS;
		local bag = bit.rshift(location, ITEM_INVENTORY_BAG_BIT_OFFSET);
		local slot = location - bit.lshift(bag, ITEM_INVENTORY_BAG_BIT_OFFSET);

		if ( bank ) then
			bag = bag + ITEM_INVENTORY_BANK_BAG_OFFSET;
		end
		return player, bank, bags, voidStorage, slot, bag, tab, voidSlot
	else
		return player, bank, bags, voidStorage, location, nil, tab, voidSlot
	end
end

local function EquipmentManager_EquipItemByLocation (location, invSlot)
	local player, bank, bags, voidStorage, slot, bag = EquipmentManager_UnpackLocation(location);

	ClearCursor();

	if ( not bags and slot == invSlot ) then
		return nil;
	end

	local currentItemID = GetInventoryItemID("player", invSlot);
	local action = {};
	action.type = (currentItemID and SWAP_ITEM) or EQUIP_ITEM;
	action.invSlot = invSlot;
	action.player = player;
	action.bank = bank;
	action.bags = bags;
	action.slot = slot;
	action.bag = bag;

	return action;
end

local function EquipmentManager_UnequipItemInSlot (invSlot)
	local itemID = GetInventoryItemID("player", invSlot);
	if ( not itemID ) then
		return nil;
	end

	local action = {};
	action.type = UNEQUIP_ITEM;
	action.invSlot = invSlot;

	return action;
end

local function EquipmentManager_EquipContainerItem (action)
	ClearCursor();
	C_Container.PickupContainerItem(action.bag, action.slot);
	if ( not CursorHasItem() ) then
		return false;
	end
	if ( IsInventoryItemLocked(action.invSlot) ) then
		return false;
	end
	PickupInventoryItem(action.invSlot);

	--EQUIPMENTMANAGER_BAGSLOTS[action.bag][action.slot] = action.invSlot;
	--EQUIPMENTMANAGER_INVENTORYSLOTS[action.invSlot] = SLOT_LOCKED;

	return true;
end


local function EquipmentManager_PutItemInInventory (action)
	if ( not CursorHasItem() ) then
		return;
	end

    local numSlots;
    for bag = 0, NUM_BAG_SLOTS do
        numSlots = C_Container.GetContainerNumFreeSlots(bag);
        if numSlots and numSlots > 0 then
            if bag == 0 then
                PutItemInBackpack();
            else
				bag = bag + 19; --Player bag 20 - 24
                PutItemInBag(bag);
            end
            break
        end
    end

	ClearCursor();
end


local _EquipmentManager_RunAction;

if EquipmentManager_RunAction then
	_EquipmentManager_RunAction = EquipmentManager_RunAction;
else
	function _EquipmentManager_RunAction (action)
		if ( UnitAffectingCombat("player") and not INVSLOTS_EQUIPABLE_IN_COMBAT[action.invSlot] ) then
			return true;
		end
	
		--EquipmentManager_UpdateFreeBagSpace();
	
		action.run = true;
		if ( action.type == EQUIP_ITEM or action.type == SWAP_ITEM ) then
			if ( not action.bags ) then
				return EquipmentManager_EquipInventoryItem(action);
			else
				local hasItem = action.invSlot and GetInventoryItemID("player", action.invSlot);
				local pending = EquipmentManager_EquipContainerItem(action);
				
				return pending;
			end
		elseif ( action.type == UNEQUIP_ITEM ) then
			ClearCursor();
	
			if ( IsInventoryItemLocked(action.invSlot) ) then
				return;
			else
				PickupInventoryItem(action.invSlot);
				return EquipmentManager_PutItemInInventory(action);
			end
		end
	end
end

EquipmentManager.UnpackLocation = EquipmentManager_UnpackLocation;
EquipmentManager.EquipItemByLocation = EquipmentManager_EquipItemByLocation;
EquipmentManager.UnequipItemInSlot = EquipmentManager_UnequipItemInSlot;
EquipmentManager.RunAction = _EquipmentManager_RunAction;


local function GetEquipmentSetMissingSlot(setID)
	--Ammo Slot is not part of equipment set
	local locations = C_EquipmentSet.GetItemLocations(setID);

	if not locations then return end;

	local slots = {};
	local numMissing = 0;
	local _, inBag, slot;

	for slotID, location in ipairs(locations) do
		_, _, inBag, _, slot = EquipmentManager_UnpackLocation(location);
		if not (inBag or slot) then
			numMissing = numMissing + 1;
			slots[numMissing] = slotID;
		end
	end

	return slots
end

EquipmentManager.GetEquipmentSetMissingSlot = GetEquipmentSetMissingSlot;


---- AMMO ----
--already sorted by dps ↓
local ARROWS = {12654, 18042, 19316, 11285, 3030, 2515, 2512};
local BULLETS = {13377, 15997, 19317, 11630, 10513, 11284, 10512, 8069, 3033, 8068, 8067, 2512, 2516};

do
	local function InsertToTop(oldData, newData)
		for i = 1, #newData do
			table.insert(oldData, 1, newData[i]);
		end
	end

	if EXPANSION_ID >= 2 then
		local TBC_ARROWS = {28053, 24417, 28056, 30611, 31949, 33803, 34581, 31737};
		local TBC_BULLETS = {28060, 23772, 28061, 30612, 32882, 32883, 23773, 34582, 31735};
		InsertToTop(ARROWS, TBC_ARROWS);
		InsertToTop(BULLETS, TBC_BULLETS);
	end

	if EXPANSION_ID >= 3 then
		local WLK_ARROWS = {41586, 41165, 52021};
		local WLK_BULLETS = {41584, 41164, 52020};
		InsertToTop(ARROWS, WLK_ARROWS);
		InsertToTop(BULLETS, WLK_BULLETS);
	end
end

local function GetOwnedAmmo(includeEquippedAmmo)
	local rangedItemID = GetInventoryItemID("player", 18);	--requires ranged weapon equipped
	if not rangedItemID then return end;

	local _, _, _, _, _, _, subclassID = GetItemInfoInstant(rangedItemID);
	local ammos;

	if subclassID == 2 or subclassID == 18 then
		--Bow/Crossbow
		ammos = ARROWS;
	elseif subclassID == 3 then
		--Gun
		ammos = BULLETS;
	else
		return
	end

	local count;
	local result = {};
	local owned = 0;
	local currentAmmo = GetInventoryItemID("player", 0);
	local ignoredID;

	if includeEquippedAmmo then
		--remove the equipped ammo from list
	else
		ignoredID = currentAmmo;
	end

	for _, itemID in ipairs(ammos) do
		if itemID ~= ignoredID then
			count = GetItemCount(itemID);
			if count and count > 0 then
				owned = owned + 1;
				result[owned] = itemID;
			end
		end
	end

	return result, currentAmmo
end

NarciClassicAPI.GetOwnedAmmo = GetOwnedAmmo;


local function DoesRangedWeaponRequireAmmo()
	local rangedItemID = GetInventoryItemID("player", 18);	--requires ranged weapon equipped
	if not rangedItemID then return end;

	local _, _, _, _, _, _, subclassID = GetItemInfoInstant(rangedItemID);

	return subclassID == 2 or subclassID == 3 or subclassID == 18
end

NarciClassicAPI.DoesRangedWeaponRequireAmmo = DoesRangedWeaponRequireAmmo;


local function IsAmmoMatched(getBestMatchedAmmo)
	local rangedItemID = GetInventoryItemID("player", 18);
	if not rangedItemID then return end;

	local ammoItemID = GetInventoryItemID("player", 0);
	if not ammoItemID then return end;

	local _, weaponSubclass, ammoSubclass;
	_, _, _, _, _, _, weaponSubclass = GetItemInfoInstant(rangedItemID);
	_, _, _, _, _, _, ammoSubclass = GetItemInfoInstant(ammoItemID);

	local isMatched = ((weaponSubclass == 2 or weaponSubclass == 18) and (ammoSubclass == 2 or ammoSubclass == 1)) or (weaponSubclass == 3 and ammoSubclass == 3);

	if (not isMatched) and getBestMatchedAmmo then
		local ammos, bestItemID;
		if weaponSubclass == 2 or weaponSubclass == 18 then
			ammos = ARROWS;
		elseif weaponSubclass == 3 then
			--Gun
			ammos = BULLETS;
		else
			return
		end

		local count;
		for _, itemID in ipairs(ammos) do
			count = GetItemCount(itemID);
			if count and count > 0 then
				ammoItemID = itemID;
				break
			end
		end
	end

	return isMatched, ammoItemID
end

NarciClassicAPI.IsAmmoMatched = IsAmmoMatched;



---- API Changes Merged 10.0, 3.4.1 ----
local CreateColor = CreateColor;

local function SetGradientTexture(texture, orientation, minR, minG, minB, maxR, maxG, maxB)    --#1
    local minColor = CreateColor(minR, minG, minB, 1);
    local maxColor = CreateColor(maxR, maxG, maxB, 1);
    texture:SetGradient(orientation, minColor, maxColor);
end

NarciClassicAPI.SetGradientTexture = SetGradientTexture;


local SharedVector3D = CreateVector3D(0, 0, 0);

local SharedLightValues = {
    omnidirectional = true,
    point = CreateVector3D(0, 0, 0),
    ambientIntensity = 0.8,
    ambientColor = CreateColor(1, 1, 1),
    diffuseIntensity = 0,
    diffuseColor = CreateColor(1, 1, 1),
};


local function SetModelLight(model, enabled, omni, dirX, dirY, dirZ, ambIntensity, ambR, ambG, ambB, dirIntensity, dirR, dirG, dirB)
    if type(omni) == "table" then
        model:SetLight(enabled, omni);
    else
        SharedLightValues.omnidirectional = omni or false;
        SharedLightValues.point:SetXYZ(dirX or 0, dirY or 0, dirZ or 0);
        SharedLightValues.ambientIntensity = ambIntensity or 0;
        SharedLightValues.ambientColor:SetRGB(ambR or 0, ambG or 0, ambB or 0);
        SharedLightValues.diffuseIntensity = dirIntensity or 0;
        SharedLightValues.diffuseColor:SetRGB(dirR or 0, dirG or 0, dirB or 0);

        model:SetLight(enabled, SharedLightValues);
    end
end

NarciClassicAPI.SetModelLight = SetModelLight;

local function GetModelLight(model)
    local enabled, light = model:GetLight();
    local _, omni, dirX, dirY, dirZ, ambIntensity, ambR, ambG, ambB, dirIntensity, dirR, dirG, dirB;
    if type(light) == "table" then
        omni = light.omnidirectional;
        dirX, dirY, dirZ = light.point:GetXYZ();

        ambIntensity = light.ambientIntensity;
        if light.ambientColor then
            ambR, ambG, ambB = light.ambientColor:GetRGB();
        else    --intensity = 0
            ambR, ambG, ambB = 0, 0, 0;
        end

        dirIntensity = light.diffuseIntensity;
        if light.diffuseColor then
            dirR, dirG, dirB = light.diffuseColor:GetRGB();
        else
            dirR, dirG, dirB = 0, 0, 0;
        end

        return enabled, omni, dirX, dirY, dirZ, ambIntensity, ambR, ambG, ambB, dirIntensity, dirR, dirG, dirB
    end
end

NarciClassicAPI.GetModelLight = GetModelLight;

local function SetModelLightFromModel(toModel, fromModel)
    local enabled, light = fromModel:GetLight();
    toModel:SetLight(enabled, light);
end

NarciClassicAPI.SetModelLightFromModel = SetModelLightFromModel;




function NarciClassicAPI.SetCameraPosition(model, x, y, z)
    if type(x) == "table" then
        x, y, z = x:GetXYZ();
    end

    if model:IsObjectType("CinematicModel") then
        local position = {
            x = x,
            y = y,
            z = z,
        }
        model:SetCameraPosition(position);
    else
        model:SetCameraPosition(x, y, z);
    end
end

function NarciClassicAPI.SetCameraTarget(model, x, y, z)
    if type(x) == "table" then
        x, y, z = x:GetXYZ();
    end

    if model:IsObjectType("CinematicModel") then
        local position = {
            x = x,
            y = y,
            z = z,
        }
        model:SetCameraTarget(position);
    else
        model:SetCameraTarget(x, y, z);
    end
end