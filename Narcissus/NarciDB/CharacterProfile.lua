local _, addon = ...
local TransmogDataProvider = addon.TransmogDataProvider;


local DB;
local CharacterData;   --NarciCharacterProfiles
local Roaster = {};    --uid

local ProfileAPI = {};
addon.ProfileAPI = ProfileAPI;

local _, CURRENT_SERVER_ID, CURRENT_PLAYER_UID = strsplit("-", UnitGUID("player"));

function ProfileAPI:GetCurrentPlayerUID()
    return CURRENT_PLAYER_UID
end

function ProfileAPI:Init()
    if CharacterData then return end;

    if not NarciCharacterProfiles then
        NarciCharacterProfiles = {};
    end
    DB = NarciCharacterProfiles;

    --Create this character table, playerUID as key
    local serverID, playerUID = CURRENT_SERVER_ID, CURRENT_PLAYER_UID;
    if not CURRENT_PLAYER_UID then return end;

    CharacterData = DB[playerUID];
    if not (CharacterData and type(CharacterData) == "table") then
        DB[playerUID] = {};
        CharacterData = DB[playerUID];
        CharacterData.birth = time();
    end

    if CharacterData then
        CharacterData.name = UnitName("player");
        CharacterData.serverID = serverID;
        CharacterData.lastVisit = time();

        local _, raceID, classID;
        _, _, raceID= UnitRace("player");
        CharacterData.race = raceID;

        _, _, classID= UnitClass("player");
        CharacterData.class = classID;
    end

    local total = 0;
    for uid, data in pairs(DB) do
        total = total + 1;
        Roaster[total] = uid;
    end
end

function ProfileAPI:SaveOutfits()
    self:Init();

    local C_TransmogCollection = C_TransmogCollection;

    local outfitIDs =  C_TransmogCollection.GetOutfits();
    local numOutfits = (outfitIDs and #outfitIDs) or 0;

    CharacterData.outfits = {};

    local outfitID, name;
    for i = 1, numOutfits do
        outfitID = outfitIDs[i];
        name = C_TransmogCollection.GetOutfitInfo(outfitID);
        CharacterData.outfits[i] = {
            n = name;
            s = TransmogDataProvider:ConvertTransmogListToString(C_TransmogCollection.GetOutfitItemTransmogInfoList(outfitID))
        };
    end
end

local function SortByName(uid1, uid2)
    local data1 = DB[uid1];
    local data2 = DB[uid2];
    if data1.name == data2.name then
        return data1.serverID < data2.serverID
    else
        return data1.name < data2.name
    end
end


local function SortByServer(uid1, uid2)
    local data1 = DB[uid1];
    local data2 = DB[uid2];
    if data1.serverID == data2.serverID then
        return data1.name < data2.name
    else
        return data1.serverID < data2.serverID
    end
end

local function SortByRecent(uid1, uid2)
    local data1 = DB[uid1];
    local data2 = DB[uid2];
    return data1.lastVisit > data2.lastVisit
end

local SortMethodFuncs = {
    name = SortByName,
    recent = SortByRecent,
    server = SortByServer,
};

local function Filter_None()
    return true
end

local function Filter_AnyOutfit(data)
    return data.outfits and #data.outfits > 0
end

local DataFilters = {
    none = Filter_None,
    outfit = Filter_AnyOutfit,
};

function ProfileAPI:GetRoster(sortMethod, filter)
    self:Init();

    local uidList = {};
    local total = 0;
    local ignored = 0;

    local filterFunc = filter and DataFilters[filter];
    if filterFunc then
        for uid, data in pairs(DB) do
            if filterFunc(data) then
                total = total + 1;
                uidList[total] = uid;
            else
                ignored = ignored + 1;
            end
        end
    else
        for uid, data in pairs(DB) do
            total = total + 1;
            uidList[total] = uid;
        end
    end

    sortMethod = sortMethod or "name";
    local sortFunc = SortMethodFuncs[sortMethod] or SortByName;
    table.sort(uidList, sortFunc);

    return uidList, total, ignored
end

function ProfileAPI:GetPlayerInfo(uid, key)
    if DB[uid] then
        if key then
            return DB[uid][key]
        else
            return DB[uid]
        end
    end
end

function ProfileAPI:SaveClassicOutfit(name, icon, itemTransmogInfoList)
    self:Init();

    if not CharacterData.classicOutfits then
        CharacterData.classicOutfits = {};
    end

    local string = TransmogDataProvider:ConvertClassicTransmogListToString(itemTransmogInfoList)

    local outfitData = {
        n = name,
        i = icon,
        t = time(),
        s = string,
    };

    table.insert(CharacterData.classicOutfits, outfitData);

    return true
end

function ProfileAPI:GetNumSavedClassicOutfits()
    self:Init();

    if CharacterData.classicOutfits then
        return #CharacterData.classicOutfits
    end

    return 0
end

function ProfileAPI:GetClassicOutfitInfo(id)
    self:Init();

    if CharacterData.classicOutfits then
        return CharacterData.classicOutfits[id];
    end
end

function ProfileAPI:GetLastAppliedOutfitID()
    self:Init();

    local outfitID = CharacterData.lastAppliedOutfitID;
    if outfitID and self:GetClassicOutfitInfo(outfitID) ~= nil then
        return outfitID
    end
end

function ProfileAPI:SetLastAppliedOutfitID(id)
    self:Init();

    CharacterData.lastAppliedOutfitID = id;
end

function ProfileAPI:IsUniqueTransmogString(itemTransmogString)
    self:Init();

    local isUnique = true;
    local duplicateOutfitID;

    if CharacterData.classicOutfits then
        for outfitID, outfitData in ipairs(CharacterData.classicOutfits) do
            if itemTransmogString == outfitData.s then
                isUnique = false;
                duplicateOutfitID = outfitID;
                break
            end
        end
    end

    return isUnique, duplicateOutfitID
end

function ProfileAPI:RenameClassicOutfit(outfitID, newName)
    self:Init();

    if CharacterData.classicOutfits and CharacterData.classicOutfits[outfitID] then
        CharacterData.classicOutfits[outfitID].n = newName;
    end
end

function ProfileAPI:DeleteClassicOutfit(outfitID)
    self:Init();

    if CharacterData.classicOutfits and CharacterData.classicOutfits[outfitID] then
        if outfitID == self:GetLastAppliedOutfitID() then
            self:SetLastAppliedOutfitID(nil);
        end
        table.remove(CharacterData.classicOutfits, outfitID);
    end
end