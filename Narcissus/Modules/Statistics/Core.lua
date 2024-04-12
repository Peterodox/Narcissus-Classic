local FormatTime = NarciAPI_FormatTime;


--Private
local EventListener = CreateFrame("Frame");

local DataManager = {};

DataManager.ListByName = {};

function DataManager:LoadData()
    if not NarciStatisticsDB then
        NarciStatisticsDB = {};
    end
    if not NarciStatisticsDB_PC then
        NarciStatisticsDB_PC = {};
    end

    ---------------------
    -----Statistics------
    ---------------------
    --"InstalledDate" (added in 1.1.2)
    --"TimeSpentInNarcissus"
    --"ScreenshotsTakenInNarcissus"
    if not NarciStatisticsDB.InstalledDate then
        NarciStatisticsDB.InstalledDate = time();
    end

    for id, data in pairs(self.List) do
        self.ListByName[data.name] = id;
    end
end

function DataManager:SaveAccountData(field, value)
    NarciStatisticsDB[field] = value;
end

function DataManager:SaveCharacterData(field, value)
    NarciStatisticsDB_PC[field] = value;
end

function DataManager:GetDataByID(id)
    if id and self.List[id] then
        if self.List[id].printFunc then
            self.List[id].printFunc();
        else
            local fields = self.List[id].fields;
            local dataSource;
            local isTime = self.List[id].isTime;
            if self.List[id].isAccountWide then
                dataSource = NarciStatisticsDB;
            else
                dataSource = NarciStatisticsDB_PC;
            end
            for i = 1, #fields do
                local value = dataSource[fields[i].name];
                if value then
                    if isTime then
                        value = FormatTime( tonumber(value) );
                    end
                    print( string.format(fields[i].format, value) );
                end
            end
        end
        return true
    else
        print("Invalid Field");
        return false
    end
end

function DataManager:GetDataByName(name)
    self:GetDataByID(self.ListByName[name]);
end

function DataManager:PrintList()
    print("|cFFFFD100Player Statistics|r")
    for i = 1, #self.List do
        print("#"..i .. ": "..self.List[i].name);
    end
end


--Temporary
SLASH_PLAYERSTATS1 = "/playerstats";
SlashCmdList["PLAYERSTATS"] = function(msg)
    msg = strlower(msg);
    if msg == "" then
        DataManager:PrintList()
    else
        local id = tonumber(msg);
        if id then
            DataManager:GetDataByID(id);
        else
            DataManager:GetDataByName(id)
        end
    end
end

-------------------------------------------------------------------
local SharedTrackerMixin = {};

function SharedTrackerMixin:RegisterEvent(event)
    if not self.isEventRegistered then
        self.isEventRegistered = {};
    end
    EventListener:RegisterEvent(event);
    self.isEventRegistered[event] = true;
    --print("RegisterEvent: "..event)
end

function SharedTrackerMixin:UnregisterEvent(event)
    if not self.isEventRegistered then
        self.isEventRegistered = {};
    end
    self.isEventRegistered[event] = false;
    --print("Unregistered: "..event);
end

function SharedTrackerMixin:IsEventRegistered(event)
    return self.isEventRegistered[event]
end

function SharedTrackerMixin:OnEvent(event, ...)
    if self:IsEventRegistered(event) then
        local killEvent = self:HandleEvent(event, ...);
        if killEvent then
            self:UnregisterEvent(event);
        end
    end
end

function SharedTrackerMixin:HandleEvent(event, ...)
end

function SharedTrackerMixin:Load()
end


--------------------------------------------------------------------------------
local function PrintAddOnUsage()
    local timeSpent = NarciStatisticsDB.TimeSpentInNarcissus or 0;
    local installedDate = NarciStatisticsDB.InstalledDate;
    if timeSpent and installedDate then
        local installedDateString = date("%d %m %y", installedDate);
        local day, month, year = string.split(" ", installedDateString);
        if day and month and year then
            day = tonumber(day);
            month = tonumber(month);
            year = tonumber(year);
            local dateString = FormatShortDate(day, month, year);
            timeSpent = SecondsToTime(timeSpent);
            print(string.format("|cFFFFD100Total time spent in Narcissus:|r %s", timeSpent));
            print(string.format("|cFFFFD100Installed On:|r %s", dateString));
        end
    end
end

local function PrintScreenshotsTaken()
    local numTaken = NarciStatisticsDB.ScreenshotsTakenInNarcissus or 0;
    print(string.format("|cFFFFD100Screenshots Taken In Narcissus:|r %s", numTaken));
end

------------------------------------------------------------------------------------------------------------
DataManager.List ={
    [1] = {
        name = "TimeSpentInNarcissus",
        printFunc = PrintAddOnUsage,
    },

    [2] = {
        name = "ScreenshotsTakenInNarcissus",
        printFunc = PrintScreenshotsTaken,
    },
};

--local events = {"GOSSIP_SHOW", "GOSSIP_CLOSED", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "ADDON_LOADED", "PLAYER_CHOICE_UPDATE", "PLAYER_CHOICE_CLOSE"}
EventListener:RegisterEvent("PLAYER_ENTERING_WORLD");


EventListener:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent(event);
        DataManager:LoadData();
    end
    --print(event);
    --print(...)
end)

--[[
hooksecurefunc("StaticPopup_Show", function(name)
    print(name)
end)
--]]