local NARCI_VERSION_INFO = "1.1.8";

local VERSION_DATE = 1712888888;
local CURRENT_VERSION = 10108;
local PREVIOUS_VERSION = CURRENT_VERSION;
local TIME_SINCE_LAST_UPDATE = 0;

do
    TIME_SINCE_LAST_UPDATE = ((time and time()) or (VERSION_DATE)) - VERSION_DATE;
    if TIME_SINCE_LAST_UPDATE < 0 then
        TIME_SINCE_LAST_UPDATE = 0;
    end
end


local _, addon = ...
local SettingFunctions = {};
addon.SettingFunctions = SettingFunctions;

--[[
Saved Variables:
1. NarcissusDB (primary)
2. NarciCreatureOptions (creature database)
3. NarcissusDB_PC (per character)
--]]

Narci = {};
NarciAPI = {};
NarciViewUtil = {};

local DefaultValues = {
    IsSortedByCategory = true,                  --Title Sorting
    FontHeightItemName = 10,
    GlobalScale = 0.8,
    EnableDoubleTap = false,
    CameraOrbit = true,
    CameraSafeMode = true,
    TooltipTheme = "Bright",
    TruncateText = false,
    ItemNameWidth = 180,
    WeatherEffect = true,
    VignetteStrength = 0.5,
    LetterboxEffect = false,
    LetterboxRatio = 2,
    AFKScreen = false,
    AKFScreenDelay = false,                     --Ope Narcissus when you go afk with a delay. Move to cancel.
    GemManager = true,                          --Enable gem manager for Blizzard item socketing frame
    UseEntranceVisual = true,
    ModelPanelScale = 1,
    BaseLineOffset = 0,                         --Ultra-wide
    ShrinkArea = 0,                             --Reduce the width of the area where you can control the model
    AutoPlayAnimation = false,                  --Play recommended animation when clicking a spell visual entry
    UseEscapeButton = true,                     --Use Escape button to exit
    ShowMinimapButton = true,
    FadeButton = false,
    ShowModulePanelOnMouseOver = true,          --Mouseover to show Module panel while mouseover minimap button
    IndependentMinimapButton = false,           --Set Minimap Button Parent to Minimap or UIParent; Handle by other addons like MBB
    AnchorToMinimap = true,                     --Anchor the mini button to Minimap
    CameraTransition = true,                    --(2nd you use the Character Pane) Camera moves smoothly bewtween presets
    UseBustShot = true,                         --Zoom in to the upper torso
    OnlyShowOwnedUpgradeItem = true,            --Filter for gems/enchant scrolls
    ShowItemID = false,                         --Show itemID on equipment tooltip
    HideTextsWithUI = true,                     --Hide all texts when UI is hidden

    LoopAnimation = false,                      --Photo Mode Loop Animation
    SpeedyScreenshotAlert = true,               --Make "Screen Captured" message disappear faster

    --# NPC
    SearchRelatives = false,                    --Search for NPCs with the same last name
    TranslateName = false,                      --Show NPC localized name
    NameTranslationPosition = 1,                --Show translated name on 1.tooltip 2.nameplate
    NamePlateNameOffset = 0,                    --Y Offset
    NamePlateLanguage = "enUS",                 --The localized name on NamePlate  (only one)
    TooltipLanguages = {},                      --Enabled localized names on tooltip

    --# Internal Hotkey
    SearchRelativesHotkey = "TAB",              --The key you press to begin/cycle relative search

    --Classic
    EquipmentSetManager = true,
    ItemFlyout = true,

    --# Initializationd in other files
    --["MinimapIconStyle = 1,                     --Change the icon of minimap button (Main.lua)
};


local AchievementOptions = {
    UseAsDefault = false,
    Scale = 1,
    Theme = 1,
    IncompleteFirst = true,
    ShowRedMark = false,                        --Mark achievement that was not earned by me with a red cross
    ReplaceToast = true,                        --Replace the original achievement toast
};


local TutorialMarkers = {
    "SpellVisualBrowser", "Movement", "ExitConfirmation",    --"IndependentMinimapButton" , "EquipmentSetManager"
    "NPCBrowserEntance", "NPCBrowser",
    "WeaponBrowser",
};

local function LoadDatabase()
    NarcissusDB = NarcissusDB or {};                            --Account-wide Variables
    local db = NarcissusDB;

    NarciCreatureOptions = NarciCreatureOptions or {};          --Creature Database
    NarciAchievementOptions = NarciAchievementOptions or {};    --Achievement Settings

    NarcissusDB_PC = NarcissusDB_PC or {};                      --Character-specific Variables
    NarcissusDB_PC.EquipmentSetDB = NarcissusDB_PC.EquipmentSetDB or {};

    db.MinimapButton = db.MinimapButton or {};
    db.MinimapButton.Position = db.MinimapButton.Position or math.rad(150);


    --Migrate deprecated variables
    if db.HideTextsWithUI == nil then
        if db.PhotoModeButton and db.PhotoModeButton.HideTexts ~= nil then
            db.HideTextsWithUI = db.PhotoModeButton.HideTexts;
        end
    end


    ---- Preference ----
    local type = type;

    for k, v in pairs(DefaultValues) do
        if db[k] == nil or type(db[k]) ~= type(v) then
            db[k] = v;
        end
    end


    ---- Achievement Data ----
    for k, v in pairs(AchievementOptions) do
        if NarciAchievementOptions[k] == nil then
            NarciAchievementOptions[k] = v;
        end
    end


    ---- Per Character ----
    if NarcissusDB_PC.UseAlias == nil then
        NarcissusDB_PC.UseAlias = false;
    end

    if NarcissusDB_PC.PlayerAlias == nil then
        NarcissusDB_PC.PlayerAlias = "";
    end


    ---- Tutorial Markers ----
    db.Tutorials = db.Tutorials or {};
    local Tutorials = db.Tutorials;
    for _, v in pairs(TutorialMarkers) do
        if Tutorials[v] == nil then
            Tutorials[v] = true;   --True ~ will show tutorial
        end
    end


    ---- Addon Update Info ----
    if (not db.Version) or (type(db.Version) ~= "number") then    --Used for showing patch notes when opening Narcissus after an update
        db.Version = 10000;
    end

    if CURRENT_VERSION > db.Version then
        PREVIOUS_VERSION = db.Version;
        --wake SplashFrame
    end

    if not db.installTime or type(db.installTime) ~= "number" then
        db.installTime = (time and time()) or VERSION_DATE;
    end

    DefaultValues = nil;
    AchievementOptions = nil;
    TutorialMarkers = nil;

    if db.SearchRelatives or db.TranslateName then
        C_Timer.After(0, function()
            LoadAddOn("Narcissus_Database_NPC");
        end)
    end
end

local function LoadSettings()
    if not NarcissusDB then
        LoadDatabase();
    end

    local db = NarcissusDB;

    for _, func in pairs(SettingFunctions) do
        func(nil, db);
    end

    C_Timer.After(0, function()
        collectgarbage("collect");
    end)
end


local CallbackList = {};
CallbackList.PLAYER_ENTERING_WORLD = {};
CallbackList.LOADING_SCREEN_DISABLED = {};

local function AddFunctionToCallbackList(callback)
    table.insert(CallbackList.PLAYER_ENTERING_WORLD, callback);
end
addon.AddInitializationCallback = AddFunctionToCallbackList;

local function AddFunctionToCallbackList_LoadingComplete(callback)
    table.insert(CallbackList.LOADING_SCREEN_DISABLED, callback);
end
addon.AddLoadingCompleteCallback = AddFunctionToCallbackList_LoadingComplete;


local Initialization = CreateFrame("Frame");
Initialization:RegisterEvent("ADDON_LOADED");
Initialization:RegisterEvent("PLAYER_ENTERING_WORLD");
Initialization:RegisterEvent("LOADING_SCREEN_DISABLED");

Initialization:SetScript("OnEvent",function(self,event,...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == "Narcissus" then
            self:UnregisterEvent(event);
            LoadDatabase();
        end
        return

    elseif event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent(event);
        LoadSettings();

        for i, callback in ipairs(CallbackList.PLAYER_ENTERING_WORLD) do
            callback();
        end

        CallbackList.PLAYER_ENTERING_WORLD = nil;

    elseif event == "LOADING_SCREEN_DISABLED" then
        self:UnregisterEvent(event);

        C_Timer.After(1, function()
            for i, callback in ipairs(CallbackList.LOADING_SCREEN_DISABLED) do
                callback();
            end

            self:SetScript("OnEvent", nil);
            CallbackList = nil;
        end)
    end
end);


local function GetAddOnVersionInfo(versionOnly)
    if versionOnly then
        return NARCI_VERSION_INFO
    end

    local dateString;
    local timeString = date("%d %m %y", VERSION_DATE);
    local day, month, year = string.split(" ", timeString);

    if day and month and year then
        day = tonumber(day);
        month = tonumber(month);
        year = tonumber(year);
        dateString = FormatShortDate(day, month, year);
    end

    -- time since last update
    local timeDiff;
    local days = math.floor(TIME_SINCE_LAST_UPDATE / 86400 + 0.5);
    if days > 2 then
        if days < 60 then
            timeDiff = string.format(Narci.L["Format Days Ago"], days);
        else
            local months = math.floor(days / 30.5 + 0.5);
            timeDiff = string.format(Narci.L["Format Months Ago"], months);
        end
    else
        timeDiff = string.lower(KBASE_RECENTLY_UPDATED or "recently updated");
    end

    return NARCI_VERSION_INFO, dateString, timeDiff
end

NarciAPI.GetAddOnVersionInfo = GetAddOnVersionInfo;


do
    local version, _, _, tocVersion = GetBuildInfo();
    local expansionID = string.match(version, "(%d+)%.");
    tocVersion = tonumber(tocVersion);

    local tooltipInfoVersion = 0;

    local function GetTooltipInfoVersion()
        return tooltipInfoVersion
    end
    addon.GetTooltipInfoVersion = GetTooltipInfoVersion;
end