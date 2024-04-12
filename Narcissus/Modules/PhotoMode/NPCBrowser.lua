local Narci = Narci;
local L = Narci.L;
local FadeFrame = NarciFadeUI.Fade;
local NarciPhotoModeAPI = NarciPhotoModeAPI;
local DoesCreatureDisplayIDExist = NarciAPI.DoesCreatureDisplayIDExist;

local BROWSER_WIDTH = 192;
local BROWSER_HEIGHT = 208;
local BROWSER_SHRINK_WIDTH = 16;
local BROWSER_SHRINK_HEIGHT = 16;

local NUM_NPC_TOTAL = 0;        --For Test
local TAB_WIDTH = 192;
local NPC_BUTTON_HEIGHT = 32;
local COVER_BUTTON_HEIGHT = 96;
local COVER_BUTTON_WIDTH = 64;
local NUM_BUTTONS_PER_PAGE = 6;
local NUM_COVER_ROW_PER_PAGE = 2;
local NUM_MAX_MATCHES = 80;
local TAB_HEIGHT = NUM_BUTTONS_PER_PAGE * NPC_BUTTON_HEIGHT;

local BrowserFrame, CategoryTab, EntryTab, MatchTab, HeaderFrame, HomeButton, SearchBox, SearchTrigger, MatchPreviewModel;
local MouseOverButtons, QuickFavoriteButton;
local LoadingIndicator;

local TARGET_MODEL_INDEX = 1;     --Add an NPC to NarciNPCModelFrame(n)
local ACTOR_CREATED = false;      --Whether user has added an NPC from browser or not

local _;
local _G = _G;
local pi = math.pi;
local min = math.min;
local max = math.max;
local sin = math.sin;
local cos = math.cos;
local floor = math.floor;
local tinsert = table.insert;
local tremove = table.remove;

local function outSine(t, b, e, d)                  --elapsed, begin, end, duration
	return (e - b) * sin(t / d * (pi / 2)) + b
end

local function inOutSine(t, b, e, d)
	return (b - e) / 2 * (cos(pi * t / d) - 1) + b
end

local function GetApproximation(number)
    --4 Decimals
    return floor(number* 10^4 + 0.5)/ 10^4
end

local sub = string.sub;
local gsub = string.gsub;
local format = string.format;

local function SortFunc(a, b)
    if a[1] == b[1] then
        return a[2] < b[2]
    else
        return a[1] < b[1]
    end
end

local function HexToRGBPercent(hexColor)
    return GetApproximation(tonumber(sub(hexColor, 1, 2), 16)/255), GetApproximation(tonumber(sub(hexColor, 3, 4), 16)/255), GetApproximation(tonumber(sub(hexColor, 5, 6), 16)/255)
end

------------------------------------------------------
local LOADING_RATE_PER_FRAME = 4;
local numLoadingThisFrame = 0;
local numTexturesInQueue = 0;
local isTextureLoading = false;
local TextureQueue = {};
local After = C_Timer.After;

local function LoadTexture(fadeIn)
    local object = TextureQueue[numTexturesInQueue];
    if object then
        object[1]:SetTexture(object[3]);
        object[2]:SetTexture(object[3]);
        numTexturesInQueue = numTexturesInQueue - 1;
        if fadeIn then
            FadeFrame(object[1], 0.25, 1, 0);
        else
            object[1]:Show();
        end
    end
    numLoadingThisFrame = numLoadingThisFrame + 1;
    if numTexturesInQueue > 0 then
        if numLoadingThisFrame <= LOADING_RATE_PER_FRAME then
            LoadTexture(fadeIn);
        else
            --print(numTexturesInQueue)
            numLoadingThisFrame = 0;
            After(0, function()
                LoadTexture(fadeIn)
            end);
        end
    else
        wipe(TextureQueue);
        isTextureLoading = false;
    end
end

local function QueueTexture(textureObject1, textureObject2, file)
    tinsert(TextureQueue, {textureObject1, textureObject2, file});
    numTexturesInQueue = numTexturesInQueue + 1;
end

------------------------------------------------------
--Tab Changing Animation    (Choose a category and go)
local SwipeAnim = NarciAPI_CreateAnimationFrame(0.25);

SwipeAnim:SetScript("OnShow", function(self)
    self.point, self.relativeTo, self.relativePoint, self.startOffset, self.offsetY = CategoryTab:GetPoint();
end);

local function Swipe_OnUpdate(self, elapsed)
	self.total = self.total + elapsed;
	local offset = outSine(self.total, self.startOffset, self.endOffset, self.duration);

	if self.total >= self.duration then
		offset = self.endOffset;
		self:Hide();
    end
    CategoryTab:SetPoint(self.point, self.relativeTo, self.relativePoint, offset, self.offsetY);
end

SwipeAnim:SetScript("OnUpdate", Swipe_OnUpdate);

local function GoToTab(index, isFavoriteTab)
    SwipeAnim:Hide();
    SwipeAnim.endOffset = (1 - index) * (TAB_WIDTH + 2);
    SwipeAnim:Show();
    if index == 1 then
        SearchTrigger:Show();
        SearchBox:Hide();
    else
        FadeFrame(HomeButton, 0.2, 1);
        HomeButton.CurrentTabIndex = index;
        if index == 2 then
            SearchTrigger:Hide();
            SearchBox:Hide();
        else
            --Tab 3
            if isFavoriteTab then
                SearchTrigger:Hide();
                SearchBox:Hide();
                HeaderFrame.Tab3Label:Show();
            else
                HeaderFrame.Tab3Label:Hide();
            end
        end
    end
    
    MouseOverButtons:Hide();
end


--Tab collapsing Animation
local CollapseAnim = NarciAPI_CreateAnimationFrame(0.2);

CollapseAnim:SetScript("OnShow", function(self)
    self.startHeight = self.tab:GetHeight();
end);

local function Collapse_OnUpdate(self, elapsed)
	self.total = self.total + elapsed;
	local height = outSine(self.total, self.startHeight, self.endHeight, self.duration);

	if self.total >= self.duration then
		height = self.endHeight;
		self:Hide();
    end
    self.tab:SetHeight(height);
end

CollapseAnim:SetScript("OnUpdate", Collapse_OnUpdate);

local function CollapseTab(tab, endHeight)
    CollapseAnim:Hide();
    CollapseAnim.tab = tab;
    CollapseAnim.endHeight = endHeight;
    CollapseAnim:Show();
end


--Opening/closing animation
local animSizing = NarciAPI_CreateAnimationFrame(0.25);
animSizing.duration2 = 0.5;
animSizing.relativeTo = Narci_NPCBrowser_Toggle;
animSizing:SetScript("OnShow", function(self)
    self.startWidth, self.startHeight = BrowserFrame:GetSize();
end);

local function Sizing_OnUpdate(self, elapsed)
	self.total = self.total + elapsed;

    local width = inOutSine(self.total, self.startWidth, self.endWidth, self.duration);
    
	if self.total >= self.duration then
        width = self.endWidth;
        local height = inOutSine(self.total - self.duration, self.startHeight, self.endHeight, self.duration2 - self.duration);
        if self.total >= self.duration2 then
            height = self.endHeight;
            self:Hide();
        end
        BrowserFrame:SetHeight(height);
    end

    BrowserFrame:SetWidth(width);
end

local function Sizing_Collapse_OnUpdate(self, elapsed)
	self.total = self.total + elapsed;

    local width = inOutSine(self.total, self.startWidth, self.endWidth, self.duration);
    local height = inOutSine(self.total, self.startHeight, self.endHeight, self.duration);

    if self.total >= self.duration then
        width = self.endWidth;
        height = self.endHeight;

        if not self.trigger then
            self.trigger = true;
            After(0.15, function()
                FadeFrame(BrowserFrame, 0.15, 0);
            end)
        end

        local offsetY = inOutSine(self.total - self.duration, -5, -60, self.duration2 - self.duration);
        BrowserFrame:SetPoint("TOP", self.relativeTo, "TOP", 0, offsetY);
        if self.total >= self.duration2 then
            self:Hide();
            self.trigger = nil;
        end
    end

    BrowserFrame:SetSize(width, height);
end

animSizing:SetScript("OnUpdate", Sizing_OnUpdate);

local function PlayToggleAnimation(state)
    if animSizing:IsShown() then return end

    if state then
        animSizing.endWidth = BROWSER_WIDTH;
        animSizing.endHeight = BROWSER_HEIGHT;
        animSizing.duration = 0.25;
        animSizing:SetScript("OnUpdate", Sizing_OnUpdate);

        FadeFrame(BrowserFrame, 0.15, 1, 0);
    else
        animSizing.endWidth = BROWSER_SHRINK_WIDTH;
        animSizing.endHeight = BROWSER_SHRINK_HEIGHT;
        animSizing.duration = 0.2;
        animSizing:SetScript("OnUpdate", Sizing_Collapse_OnUpdate);
    end

    animSizing:Show();
end

-----------------------------------------------------------------------------------------------

local CP = {
    --Color presets
    ["r"] = "ce7272",
    ["o"] = "cfa972",       --Brown
    ["y"] = "ffd200",
    ["g"] = "72ce7d",
    ["c"] = "40c7eb",
    ["b"] = "7da7e0",
    ["p"] = "9f72ce",
    ["bp"] = "8c9ec4",      --Pastel Blue
    ["bk"] = "989898",      --Black
    ["tt"] = "b6f0f0",      --Titan
    ["dn"] = "b09dd3",      --Draenei
    ["lg"] = "a2ff00",      --Legion
    ["kt"] = "4eb38c",      --Kultiran
}

for k, v in pairs(CP) do
    CP[k] = {v, HexToRGBPercent(v)};
end

--[[
Weapons
2200    --Vial Offhand
2210    --Wood Shield
--]]

local NPCInfo = {
    --[ID] = { customTitle, color, voice, {weapons} }
    [4968]   = {"", "b", 7216, {2177} },          --Lady Jaina Proudmoore <Ruler of Theramore>
    [64727]  = {"", "b", 34500, {2177} },         --Jaina Kirin Tor
    [120922] = {"Lord Admiral", "bp", 115285, {153575} },        --Jaina 8.0
    [138197] = {"", "bp", 114950, {153575}},       --Little Jaina
    [144437] = {"", "kt", 114408},        --Tandred Proudmoore
    [140917] = {"", "bk", 127768},        --Derek Proudmoore UD
    [70084]  = {"King of Lordaeron", "o", 17398},    --Terenas Menethil
    [115489] = {"", "b", 78206},           --Anduin Lothar
    [115490] = {"", "tt", 78207},          --Prince Llane Wrynn
    [11699]  = {"", "y", 5971},            --Varian Old
    [29611]  = {"", "b", 16105, {45899}},         --King Varian Wrynn
    [142294] = {"", "g", 74134},           --Broll Bearmantle
    [142299] = {"", "o", 72747, {63052} },           --Archdruid Hamuul Runetotem
    [135614] = {"", "b", 74903, {47104, 47104} },         --Master Mathias Shaw
    [29607] = {"", "r", 72298, {171193, 171193} },         --Valeera
    [155496] = {"", "bk", 146147, {171194} },       --Wrathion <The Black Prince> humanoid
    [57777] = {"", "bk", 146147, },       --Wrathion <The Black Prince> Teen
    [44365]  = {"", "p", 95141, {42775} },         --Lady Sylvanas Windrunner <Banshee Queen>
    [144793] = {"", "b", 95141, {128826} },        --Sylvanas Windrunner <Ranger General of Quel'Thalas>
    [25237]  = {"", "r", 16024, {23428, 23428} },           --Garrosh Hellscream <Overlord of the Warsong Offensive>     Northrend
    [71865]  = {"", "r", 20516, {30414} },           --Garrosh Hellscream <Warchief>  --101441 Sha Weapon
    [97346]  = {"", "g", 57827},           --Sira Moonwarden <The Wardens>
    [149126] = {"", "p", 123599, {165224, 165224} },          --Sira Moonwarden <Dark Warden>
    [58207]  = {"", "r", 135369},          --Alexstrasza <Aspect of Life> Dragonkin
    [32295]  = {"", "r", 135371},          --Alexstrasza the Life-Binder <Queen of the Dragons> Dragon     animID 233
    [73691]  = {"", "o", 139316},          --Chromie <The Timewalkers> gnome
    [55913]  = {"", "o", 3525},            --Champion of Time <Bronze Dragonflight>
    [110596] = {"", "y", 71554},          --Calia Human 7.0
    [156513] = {"Princess of Lordaeron", "p", 139555},          --Calia Menethil
    [36743]  = {"", "bk", 19716, {46737} },          --King Genn Greymane  Gilneas City
    [120788] = {"", "o", 134540, {46737} },          --Genn Greymane <King of Gilneas> Human
    [149700] = {"", "o", 134542},          --Genn Greymane <King of Gilneas> Worgen
    [37065]  = {"", "bk", 19613},           --Prince Liam Greymane
    [142816] = {"", "b", 115307},          --Mia Greymane <Queen of Gilneas>
    [150115] = {"", "bk", 71562, {5284, 5284} },          --Princess Tess Greymane
    [35552] = {"", "o", 19501, {15258} },  --Lord Darius Crowley
    [37195] = {"", "bk", 81013, {56171} },  --Lord Darius Crowley Worgen
    [117480] = {"", "tt", 81272, {54877, 54878} },  --Lord Darius Crowley Worgen
    [35378] = {"", "o", 19681, {63227} },  --Lorna Crowley Gilneas
    [93779] = {"", "o", 53022, {60338, 43085}},  --Commander Lorna Crowley <Gilneas Brigade>

    [140176] = {"", "tt", 59119, {55305} },          --Nathanos Blightcaller    65795 Axe
    [20354]  = {"", "o", 5971},            --Nathanos Marris
    [139098] = {"", "kt", 108042},         --Thomas Zelling KT
    [142211] = {"", "p", 123088},          --Thomas Zelling UD
    [6767]   = {"", "bk", 21264, {31669, 31669} },           --Garona Vanilla
    [138708] = {"", "lg", 120388, {141347, 141347} },          --Garona Halforcen
    [26499]  = {"", "bp", 14326, {37579} },          --Arthas <Prince of Lordaeron>
    [32326]  = {"", "p", 14759, {33475} },           --Prince Arthas Menethil UD
    [103996]  = {"", "p", 14759, {33475} },           --Arthas the Lich King      --103996 No weapon     95941 Weapon
    [1748]   = {"", "bp", 5971, {2178, 143} },           --Highlord Bolvar Fordragon
    [95942]  = {"", "y", 121042, },          --Bolvar Fordragon <The Lich King>
    [146986] = {"", "y", 52473},           --The Lich King red
    [148015] = {"", "kt", 111570, {166781} },         --Taelia Fordragon
    [26528]  = {"", "b", 12840, {37579, 12860} },           --Uther the Lightbringer <Knight of the Silver Hand>
    [120424] = {"", "bp", 72735},          --Alonsus Faol <Bishop of Secrets> UD
    [146011] = {"", "o", 115196, {118400} },          --Saurfang Hoody
    [100636] = {"", "r", 115196, {155857} },          --High Overlord Saurfang
    [4949]   = {"", "bk", 7214, {56228} },            --Thrall Old
    [54634]  = {"", "o", 10700, {109674} },           --Thrall <The Earthen Ring> Hoody
    [110516] = {"", "o", 74514, {109674}},           --Thrall <The Earthen Ring>
    [152977] = {"", "o", 137435, {168268} },           --Thrall New
    [54938]  = {"", "b", 7218, {31700} },            --Archbishop Benedictus Old
    [54953]  = {"Twilight Prophet", "p", 127200, {31700} },          --Archbishop Benedictus Twilight Prophet
    [30115]  = {"", "b", 72851, {50268} },           --Vereesa Windrunner <Ranger-General of the Silver Covenant>    42140 Bow
    [121230] = {"", "b", 89530, {151781} },           --Alleria Windrunner
    [152718] = {"", "p", 89611},           --Alleria Windrunner Void
    [152194] = {"", "tt", 127919},         --MOTHER
    [7228]   = {"", "tt", 5851},           --Ironaya
    [154481] = {"", "bk", 76130},          --Spiritwalker Ebonhorn
    [152365] = {"", "b", 134249},          --Kalecgos <Emissary of the Blue Dragonflight>
    [56101]  = {"", "b", 134252},          --Kalecgos <The Spellweaver>
    [28859]  = {"", "b", 14527},           --Malygos Dragon
    [33535]  = {"", "b", 14539},           --Malygos <The Spell-Weaver> Human

    [89975]  = {"", "b", 54048},       --Senegos
    [89794]  = {"", "b", 54105},       --Stellagosa
    [89371]  = {"", "b", 3525},        --Stellagosa Dragon

    [2784]   = {"", "b", 7225, {158463, 161683}},            --King Magni Bronzebeard <Lord of Ironforge>
    [152206] = {"", "b", 115765, {101388, 138831} },          --Magni Bronzebeard <The Speaker>
    [127021] = {"", "b", 113541, {49775, 49774} },          --Muradin Bronzebeard <High Thane>
    [155934] = {"", "o", 14242},           --Brann Bronzebeard <Explorer's League>
    [152503] = {"", "o", 23615},           --Sir Finley Mrrgglton <Explorer's League>
    [152501] = {"", "o", 5998},            --Elise Starseeker <Explorer's League>
    [152502] = {"", "o", 48877},           --Reno Jackson <Explorer's League>
    [44238] =  {"", "bk", 5974},           --Harrison Jones <Archaeology Trainer>
    [8929]   = {"", "b", 7064},            --Princess Moira Bronzebeard <Princess of Ironforge>
    [100979] = {"", "bk", 114682, {95049, 12865} },         --Moira Thaurissan <Dark Iron Representative>
    [153051] = {"", "r", 21567, {22213} },           --Moira Thaurissan <Queen of the Dark Iron>
    [9019]   = {"", "b", 5908},            --Emperor Dagran Thaurissan
    [148104] = {"", "bk", 104920, {154134} },         --Bwonsamdi
    [21984]  = {"", "o", 114405},          --Rexxar <Champion of the Horde> 155098 Visons
    [148369] = {"", "r", 53739},           --Misha
    [157354] = {"", "p", 133720},          --Vexiona
    [1747]   = {"", "b", 21076, {12748} },           --Anduin Wrynn <Prince of Stormwind>
    [69257] = {"", "y", 27559, {12748} },		--Anduin MoP
    [100973] = {"", "b", 73936},           --Anduin Wrynn <Broken King of Stormwind>
    [134202] = {"", "y", 73936, {152482} },           --Anduin Wrynn <King of Stormwind> Helm On
    [91735] = {"", "y", 73936, {152482} },            --Anduin Wrynn <King of Stormwind> Helm Off
    [120264] = {"", "o", 73936},           --Anduin Wrynn <King of Stormwind> Hooded
    [119723] = {"", "b", 81431},           --Image of Aegwynn
    [125885] = {"", "bp", 88534},          --Aman'Thul
    [126267] = {"", "y", 90885},           --Eonar
    [126266] = {"", "tt", 13683},          --Norgannon
    [126268] = {"", "bp", 13683},          --Golganneth
    [125886] = {"", "o", 13683},           --Khaz'goroth
    [154427] = {"", "tt", 86365},          --Aggramar Blue
    [124691] = {"", "r", 86360, {147371} },           --Aggramar Red
    [126010] = {"", "o", 72358},           --Sargeras
    [145802] = {"", "r", 120829},          --Anasterian Sunstrider
    [115213] = {"", "b", 77539},           --Image of Arcanagos
    [114895] = {"", "bk", 77544},          --Nightbane
    [17968] = {"", "lg", 10990},           --Archimonde Hyjal Summit
    [91331] = {"", "lg", 50678},           --Archimonde <The Defiler>  Hellfire Citadel
    [124677] = {"", "dn", 9762},           --Archimonde <Master of the Augari>
    [143009] = {"", "kt", 104320},         --Daelin Proudmoore
    [121144] = {"", "kt", 115763},         --Katherine Proudmoore <Lord Admiral of Kul Tiras>

    [130704] = {"", "r", 108206, {159927} },       --Lord Stormsong
    [134060] = {"", "p", 110178},       --Lord Stormsong K'thir
    [121360] = {"", "r", 113406, {155816} },       --Priscilla Lady Ashvane
    [130934] = {"", "b", 112977, {155763, 155791} },       --Brother Pike
    [121239] = {"", "o", 110633, {155766, 155766} },       --Flynn Fairwind
    [133006] = {"", "o", 105945},       --Lady Meredith Waycrest
    [132994] = {"", "bk", 103406},      --Lord Arthur Waycrest
    [125380] = {"", "o", 103429},       --Lucille Waycrest
    [134953] = {"", "o", 112518},       --Alexander Treadward
    [144755] = {"", "p", 124584},     --Zaxasj the Speaker
    [137069] = {"", "bk", 94999},    --King Rakataka
    [128674] = {"", "r", 95000},     --Gut-Gut the Glutton
    [137194] = {"", "r", 90068},     --Ranishu Grub  Colors
    [134344] = {"", "y", 113927},     --Scrollsage Nola
    [134345] = {"", "g", 113384},     --Collector Kojo
    [134346] = {"", "r", 114411},     --Toki
    [123586] = {"", "o", 113030},     --Kiro
    [126848] = {"", "tt", 97234, {153433} },    --Captain Eudora
    [123876] = {"", "r", 112986},     --Nisha
    [122583] = {"", "r", 111563},     --Meerah
    [127742] = {"", "y", },     --Meerah's Caravan
    [124522] = {"", "o", 115778},     --Alpaca    Colors
    [133392] = {"", "tt", 114398},    --Sethraliss
    [134601] = {"", "r", 107664, {151335} },     --Emperor Korthek
    [128694] = {"", "g", 111567, {151335} },     --Vorrik
    [134292] = {"", "o", 109931},     --Sulthis
    [62837] = {"", "r", 29278},      --Grand Empress Shek'zeer
    [62151] = {"", "o", 32851},      --Xaril the Poisoned Mind
    [64724] = {"", "tt", 31059},     --Karanosh
    [134445] = {"", "r", 135563},     --Zek'voz <Herald of N'Zoth>
    [157620] = {"", "r", 143640},     --Prophet Skitra
    [144754] = {"", "r", 124585},     --Fa'thuul the Feared
    [37955] = {"", "r", 16782},      --Blood-Queen Lana'thel
    [25601] = {"", "tt", 16684},     --Prince Valanar
    [23953] = {"", "o", 16724},      --Prince Keleseth
    [135612] = {"", "y", 112840, {118080} },     --Halford Wyrmbane
    [38243] = {"", "g", 72314},      --Zen'tabra
    [3679] = {"", "g", 62223},      --Naralex
    [97923] = {"", "y", 75430},     --Rensar Greathoof <Archdruid of the Grove>
    [19554] = {"", "p", 31261},      --Dimensius the All-Devouring
    [20454] = {"", "kt", 9161},      --Nexus-King Salhadaar
    [121597] = {"", "p", 89046},     --Locus-Walker
    [104399] = {"", "p", 61633},     --Nexus-Prince Bilaal
    [86235] = {"", "p", 12215},     --Nhallish Void Revenant
    [93068] = {"", "lg", 50621},     --Xhul'horac
    [121663] = {"", "p", 88645},     --Nhal'athoth
    [8379] = {"", "bk", 84242, {29688} },     --Xylem


    [93951] = {"", "p", 5977},             --Gavinrad the Cruel
    [80747] = {"", "r", 6018},             --Golmash Hellscream
    [142275] = {"", "r", 6024},            --Grommash Hellscream <Warchief of the Mag'har>
    [76278] = {"", "r", 46500},            --Grommash Hellscream <Warchief of the Iron Horde>
    [18076] = {"", "kt", 6024},            --Grommash Hellscream <Chieftain of the Warsong Clan> Outland
    [17008] = {"", "p", 45320},            --Gul'dan BC
    [78333] = {"", "lg", 50946},           --Gul'dan 6.0
    --[52222]  = {"The Soulflayer", "r", 8465},       --Hakkar the Soulflayer
    [120533] = {"", "dn", 11789},          --Velen
    [127880] = {"", "dn", 45403},          --Echo of Velen <The Triumvirate>
    [142664] = {"", "dn", 45680},          --High Exarch Yrel <Voice of the Naaru>
    [81412]  = {"", "dn", 45582},          --Vindicator Yrel
    [75992]  = {"", "dn", 45681},          --Yrel
    [80078]  = {"", "dn", 46738},          --Exarch Akama <High Vindicator> Alternate
    [108249] = {"", "bk", 72162},          --Akama <Illidari>
    [18538] = {"", "tt", 68284},           --Ishanah <High Priestess of the Aldor>
    [91923]  = {"", "dn", 45900},          --Exarch Naielle <Rangari Prime>
    [75028]  = {"", "dn", 44640},          --Exarch Maladaar <Speaker for the Dead>
    [80076]  = {"", "dn", 43301},          --Exarch Othaar <Sha'tari Proconsul>
    [75145]  = {"", "dn", 44847},          --Vindicator Maraad
    [80075]  = {"", "dn", 46768},          --Exarch Hataaru <Chief Artificer>
    [19044]  = {"", "r", 11355},           --Gruul the Dragonkiller
    [17545]  = {"", "tt", 51323},          --K'ure
    [18481]  = {"", "tt", 51323},          --A'dal
    [82950]  = {"", "o", 42170},           --Pridelord Karash Saberon
    [77428]  = {"", "o", 42015},           --Imperator Mar'gok <Sorcerer King>
    [109222] = {"", "p", 72243},           --Meryl Felstorm
    [106313] = {"", "bk", 71521},           --Rehgar Earthfury <Hero of the Storm>
    [102846] = {"", "b", 72143},           --Alodi
    [18708]  = {"", "kt", 10820},          --Murmur
    [18166]  = {"", "b", 45024, {28067} },           --Archmage Khadgar <Sons of Lothar>
    [114562] = {"", "b", 1398},            --Khadgar's Upgraded Servant
    [15687]  = {"", "r", 9211},            --Moroes <Tower Steward> UD
    [101276] = {"", "r", 77510},           --Vision of Moroes <Tower Steward>
    [114463] = {"", "bk", 78202, {28067} },          --Medivh
    [117269] = {"", "r", 83568},           --Kil'jaeden <The Deceiver> ToS
    [25315]  = {"", "r", 12504},           --Kil'jaeden <The Deceiver> Sunwell
    [127878] = {"", "dn", 9766},           --Echo of Kil'jaeden <The Triumvirate>
    [125233] = {"", "lg", 87972},          --Talgath <Kil'jaeden's Second>
    [127872] = {"", "dn", 9762},           --Echo of Talgath <Council to the Triumvirate>
    [76268]  = {"", "p", 43586, {110990} },           --Ner'zhul <Warlord of the Shadowmoon Clan> 95946
    [55419]  = {"", "tt", 26138},          --Captain Varo'then <The Hand of Azshara>
    [56190]  = {"", "lg", 50453},          --Mannoroth <The Destructor> Well of Eternity
    [91349]  = {"", "lg", 50455},          --Mannoroth Bone
    [95990]  = {"", "lg", 50482},          --Mannoroth Flesh
    [115427] = {"", "b", 9325},            --Nielas Aran
    [15690]  = {"", "lg", 9322},           --Prince Malchezaar
    [34780]  = {"", "r", 16144},           --Lord Jaraxxus
    [90296]  = {"", "lg", 50250},          --Soulbound Construct
    [92330]  = {"", "lg", 50847},          --Soul of Socrethar
    [75884]  = {"", "r", 43250},           --Rulkan 	Leader of the Shadowmoon Exiles
    [11980]  = {"", "bk", 6024},           --Zuluhed the Whacked <Chieftain of the Dragonmaw Clan>
    [10812] = {"", "r", 5971},             --Grand Crusader Dathrohan
    [10813] = {"", "tt", 63807},           --Balnazzar Stratholme
    [90981] = {"", "p", 63804},            --Balnazzar Darkshore
    [21838] = {"", "o", 9092},             --Terokk
    [84017] = {"", "o", 46475},            --Terokk <The Talon King>
    [83599] = {"", "o", 42887},            --Lithic  daughter of Terokk
    [22871] = {"", "p", 11519},            --Teron Gorefiend Black Temple
    [103144] = {"", "b", 72733},           --Thoradin <King of Arathor>
    [109000] = {"The Four Horsemen", "b", 74263},          --King Thoras Trollbane
    [107806] = {"", "bk", 73977},          --Prince Galen Trollbane <Fallen Prince of Stromgarde>
    [137701] = {"", "r", 111573, {125319, 13814} },          --Danath Trollbane Arathi Red
    [96183] = {"", "b", 111573},           --Danath Trollbane  Helm
    [16819] = {"", "y", 111573},           --Force Commander Danath Trollbane <Sons of Lothar> Outland
    [12126] = {"", "b", 14879},            --Lord Tirion Fordring <Order of the Silver Hand>  Classic
    [31044] = {"", "y", 14568, {13262}},            --Highlord Tirion Fordring  Icecrown 54168
    [20349] = {"", "b", 5971},             --Tirion Fordring   Old Hillsbrad Foothills
    [126319] = {"", "y", 89488, {150577} },           --Turalyon
    [57945] = {"", "o", 25965},            --Nozdormu the Timeless One <Aspect of Time> Huamn
    [27925] = {"", "o", 25954},            --Nozdormu <The Lord of Time> Dragon
    [54432] = {"", "bk", 25936},           --Murozond <The Lord of the Infinite>
    [19935] = {"", "o", 9730},             --Soridormi <The Scale of Sands>     55395 Soridormi <Prime Consort to Nozdormu>
    [143692] = {"", "o", 6638},            --Anachronos
    [162419] = {"", "o", 5983},            --Zidormi
    [133263] = {"", "o", 5971},            --Rhonormu  Silithus
    [22004] = {"", "o", 6018},             --Leoroxx  father of Rexxar  Blade's Edge Mountains
    [151949] = {"", "g", 136237},          --Merithra of the Dream <Daughter of Ysera>
    [55393] = {"", "g", 60787},            --Ysera <The Dreamer> Dargon
    [104762] = {"", "r", 52058},           --Ysera <The Corrupted>
    [58209] = {"", "g", 26152},            --Ysera <Aspect of Dreams> Human
    [106316] = {"", "dn", 71242},          --Farseer Nobundo <The Earthen Ring>
    [85315] = {"", "dn", 44163},           --Vindicator Nobundo    Alternate
    [83474] = {"", "r", 50419},            --Kilrogg Deadeye <Warlord of the Bleeding Hollow>
    [90378] = {"", "lg", 50430},           --Kilrogg Deadeye Hellfire Citadel
    [135618] = {"", "o", 120874},          --Falstad Wildhammer <High Thane>
    [110513] = {"", "o", 20728},           --Kurdran Wildhammer
    [19379] = {"", "o", 1378},             --Sky'ree <Gryphon of Kurdran Wildhammer>
    [78714] = {"", "r", 44529},            --Kargath Bladefist <Warlord of the Shattered Hand> Alternate
    [16808] = {"", "r", 10325},            --Warchief Kargath Bladefist  Outland
    [22917] = {"", "lg", 11466, {32632, 32633} },           --Illidan Stormrage <The Betrayer>  --150732
    [55500] = {"", "kt", 26057, {32065, 32066} },           --Illidan Stormrage  Well of Eternity
    [113851] = {"", "g", 72793, {134845} },                 --Illidan Stormrage <Captain of the Moon Guard>
    [17011] = {"", "p", 62509},            --Blackhand the Destroyer <Warchief of the Horde>
    [77325] = {"", "r", 45420, {113126} },            --Blackhand <Warlord of the Blackrock> in Blackrock Foundry
    --[17028] = {"", "r", 6018},             --Maim Blackhand No pants!
    [10429] = {"", "r", 6018},             --Warchief Rend Blackhand 51419
    [77257] = {"", "r", 46079},            --Orgrim Doomhammer
    [92142] = {"", "lg", 50410, {124388} },            --Blademaster Jubei'thos
    [55971] = {"", "bk", 37644},           --Deathwing <The Destroyer> Dragon
    --[56173] = {"", "bk", 37644},           --Deathwing <The Destroyer> Maelstrom  Too Large!!!
    [33523] = {"", "bk", 5977},            --Neltharion <The Earthwarder>  Human
    [46471] = {"", "bk", 20282},           --Deathwing <Aspect of Death>  Human
    [23284] = {"", "bk", 67792},           --Lady Sinestra
    [45213] = {"", "bk", 20212},           --Sinestra <Consort of Deathwing>
    [1749] = {"", "bk", 5983},             --Lady Katrana Prestor
    [10184] = {"", "bk", 19755},           --Onyxia
    [74594] = {"", "r", 45297},            --Durotan <Chieftain of the Frostwolf Clan>
    [76354] = {"", "bk", 49565},            --Nightstalker <Durotan's Companion>
    [81695] = {"", "p", 46618},            --Cho'gall <Shadow Council>
    [43324] = {"", "p", 22079},            --Cho'gall  Bastion of Twilight
    [11946] = {"", "bp", 6024},             --Drek'Thar <Frostwolf General>   Alterac Valley
    [80597] = {"", "r", 46676},            --Farseer Drek'Thar Alternate
    [21181] = {"", "lg", 3685},            --Cyrukh the Firelord <The Dirge of Karabor>
    [90481] = {"", "o", 44754},            --Draka
    [137472] = {"", "r", 82183},           --Eitrigg

    [41406] = {"The Mother Wisp", "g", 	20733},  --Aessina
    [46753] = {"The Windlord", "tt", 20867},     --Al'Akir
    [32871] = {"", "bp", 15394},            --Algalon the Observer
    [131071] = {"", "bp", 132836, {163037} },          --Queen Azshara Naga
    [54853] = {"", "bp", 26026},             --Queen Azshara WoE
    [104636] = {"", "r", 58861},            --Cenarius Corrupted    --58869 Sacred Vine
    [40773] = {"", "g", 80403},             --Cenarius
    [115813] = {"", "g", 6516},             --Daughter of Cenarius
    [12238] = {"", "g", 1128},              --Zaetar's Spirit
    [71952] = {"", "r", 37257},             --Chi-Ji <The Red Crane>
    [71953] = {"", "bp", 38211},            --Xuen <The White Tiger>
    [71954] = {"", "o", 38755},             --Niuzao <The Black Ox>
    [71955] = {"", "g", 38225},             --Yu'lon <The Jade Serpent>
    [2748] = {"", "tt", 5858},              --Archaedas <Ancient Stone Watcher>
    [52571] = {"", "r", 24479},             --Majordomo Staghelm <Archdruid of the Flame>
    [40140] = {"", "g", 7222},              --Archdruid Fandral Staghelm
    [53286] = {"", "g", 5995},              --Valstann Staghelm
    [53289] = {"", "g", 5998},              --Leyara Wife
    [53014] = {"", "r", 6000},              --Leyara Flame Druid
    [53291] = {"", "r", 11819},             --Istaria  Daughter  Blood Elf Kid
    [32906] = {"", "tt", 15526},            --Freya
    [32913] = {"", "o", 6530},              --Elder Ironbranch
    [32914] = {"", "g", 6530},              --Elder Stonebark
    [32915] = {"", "p", 6530},              --Elder Brightleaf
    [115750] = {"", "tt", 22243},           --Goldrinn <Ancient>
    [97929] = {"", "tt", 22249},            --Tortolla <Ancient>
    [112927] = {"", "lg", 66565},           --Hakkar the Houndmaster
    [108695] = {"", "p", 1248},             --Czaadym <Hakkar's Minion>  Purple Felhound
    [107441] = {"", "r", 1248},             --Zoarg <Hakkar's Minion>  Red
    [108175] = {"", "bk", 1248},            --Pryykun <Hakkar's Minion>  Green
    [114537] = {"", "bp", 77492},           --Helya
    [101582] = {"", "bk", 51440},           --Dakarr <Shadow of Helya>  Nightsaber
    [96211] = {"", "b", 5977},              --Ignaeus Trollbane
    [107993] = {"", "tt", 74117},           --Hodir
    [33118]  = {"", "r", 15567},            --Ignis the Furnace Master
    [11496]  = {"", "p", 6819},             --Immol'thar
    [11486]  = {"", "kt", 5992},            --Prince Tortheldrin <Ruler of the Shen'dralar>
    [36479]  = {"", "bp", 5989},            --Archmage Mordent Evenshade <The Highborne>
    [89355] = {"", "p", 60765, {13753} },             --Prince Farondis
    [97903]  = {"", "o", 58525, {45266, 45287} },            --Jarod Shadowsong     109637
    [108610] = {"", "r", 61722},            --Kathra'natir
    [71155] = {"", "y", 38667},             --Korven the Prime
    [98965] = {"", "p", 54536},             --Kur'talos Ravencrest <Lord of Black Rook Hold>
    [68397] = {"", "bp", 35594},            --Lei Shen <The Thunder King>
    [58817] = {"", "o", 26943},             --Spirit of Lao-Fe <The Slavebinder>
    [61923] = {"", "o", 29368},             --Liu Lang

    [28923] = {"", "tt", 14162},            --Loken
    [106558] = {"", "tt", 72278},           --Mimiron
    --[106678] = {"", "y", },           --Aerial Command Unit <Mimiron's Creation>
    [154418] = {"", "tt", 146847},          --Ra-den <Keeper of Storms> --No sound names 8.3
    [69473]  = {"", "r", 35759},            --Ra-den <Fallen Keeper of Storms>
    [156866] = {"", "p", 144983},           --Ra-den <The Despoiled>
    [120436] = {"", "lg", 83443},           --Fallen Avatar

    [96281] = {"", "g", 54090, {32425} },             --Maiev Shadowsong <Warden>
    [106905] = {"", "tt", 71043},           --Malorne <Ancient>
    [106910] = {"", "tt", 62108},           --Ursol <Ancient>
    [106909] = {"", "tt", 62292},           --Ursoc <Ancient>
    [100497] = {"", "r", 58389},            --Ursoc <Cursed Bear God>
    [55570] = {"", "g", 26490},             --Malfurion Stormrage  WoE
    [15362] = {"", "g", 60972},             --Malfurion Stormrage
    [146990] = {"", "g", 121588},           --Malfurion Stormrage Bear
    [7999] = {"", "g", 114685, {77364} },             --Tyrande Whisperwind <High Priestess of Elune>
    [146927] = {"", "bk", 123536, {164726} },          --Tyrande Whisperwind <The Night Warrior>
    [145357] = {"", "g", 3604},             --Dori'thur <Tyrande's Companion>
    [103769] = {"", "r", 52106},            --Xavius <Nightmare Lord>  Giant
    [113587] = {"", "r", 54473},            --Xavius Defeated
    --Peroth'arn

    [61942] = {"", "y", 34425},            --The Monkey King
    [56336] = {"", "y", 26819},            --Chief Kah Kah
    [61603] = {"", "y", 26819},            --Emperor RikkTik
    [55678] = {"", "r", 31096},            --Riko

    [96219] = {"", "b", 5907},              --Modimus Anvilmar
    [156347] = {"", "bp", 19477},           --Neptulon <The Tidehunter>
    [11502] = {"The Firelord", "r", 8046},  --Ragnaros MC
    [52409] = {"The Firelord", "r", 24531},       --Ragnaros with feet
    [51600] = {"", "r", 23794},            --Lil' Ragnaros
    [143607] = {"", "r", 5907},             --High Justice Grimstone <Herald of Ragnaros>
    [44025] = {"", "o", 71137},             --Therazane <The Stonemother>
    [12201] = {"", "o", 209},               --Princess Theradras
    [119894] = {"", "tt", 71637},           --Odyn <Prime Designate>
    [112046] = {"", "tt", 76146},           --Thorim <The Stormlord>

    [60709] = {"", "r", 28059},             --Qiang the Merciless <Warlord King>
    [101651] = {"", "y", 61869},            --Belysra Starbreeze <Priestess of the Moon>
    [140323] = {"", "o", 123605, {55048} },           --Shandris Feathermoon <General of the Sentinel Army>
    [33196] = {"", "bp", 15777},            --Sif
    
    [73303] = {"", "y", 37308},             --Emperor Shaohao
    [54975] = {"", "b", 27407},             --Aysa Cloudsinger
    [54568] = {"", "r", 27310},             --Ji Firepaw
    [61907] = {"", "y", 29368},             --Kang <Fist of the First Dawn>
    [21212] = {"", "bp", 11533},            --Lady Vashj <Coilfang Matron>

    [10926] = {"", "b", 11819},             --Pamela Redpath
    [11063] = {"", "bk", 5977},             --Carlin Redpath <The Argent Crusade>  uncle
    --[11629] = {"", "b", 5986},              --Jessica Redpath  older sister
    [10936] = {"", "b", 5977},              --Joseph Redpath father
    --[30556] = {"", "b", 8983},              --Marlene Redpath aunt
    --[10938] = {"", "p", 5979},              --Redpath the Corrupted
    --[10937] = {"", "b", 5977},              --Captain Redpath
    [10944] = {"", "b", 5977},              --Davil Lightfire
    [10939] = {"", "p", 6041},              --Marduk the Black
    [10946] = {"", "p", 12939},             --Horgus the Ravager

    [33288] = {"", "p", 15755},             --Yogg-Saron
    [33136] = {"", "p", 99356},             --Guardian of Yogg-Saron
    [72228] = {"", "p", 37147},             --Heart of Y'Shaarj
    [15589] = {"", "p", 8582},              --Eye of C'Thun
    [22137] = {"", "p", 8674},              --Summoned Old God
    [15215] = {"", "p", 62501},             --Mistress Natalia Mar'alith <High Priestess of C'Thun>
    [158041] = {"", "p", 132781},           --N'Zoth the Corruptor
    [159767] = {"", "r", 115595},           --Sanguimar <Blood of N'Zoth>
    [163405] = {"", "r", 106383},           --G'huun
    [141851] = {"", "r", 28513},            --Spawn of G'huun
    [133007] = {"", "r", 115902},           --Unbound Abomination
    [131318] = {"", "r", 101025},           --Elder Leaxa <Voice of G'huun>
    [128184] = {"", "r", 101801},           --Jungo, Herald of G'huun
    [142765] = {"", "r", 98477},            --Ma'da Renkala <Disciple of G'huun>
    [126001] = {"", "p", 93891},            --Uul'gyneth <The Darkness>
    [26861] = {"", "o", 75200},             --King Ymiron
    [96756] = {"", "bk", 54357},            --Ymiron, the Fallen King
    [131442] = {"", "tt", 105628},          --Leandro Royston <Mayor of Falconhurst>
    [16802] = {"", "r", 95137, {168606} },             --Lor'themar Theron   Blood Elf
    [146430] = {"", "bp", 34502},           --Lor'themar Theron <Ranger Lord>
    [19622] = {"", "r", 11268},             --Kael'thas Sunstrider
    [24664] = {"", "bk", 12419},            --Kael'thas Sunstrider - Pale
    [146433] = {"", "bp", 120758},          --High Priestess Liadrin
    [17076]  = {"", "bp", 72771, {24034, 27406} },           --Liadrin Old
    [145793] = {"", "r", 114772, {163831, 163832} },         --Liadrin Arathi
    
    [3057] = {"", "o", 7219},               --Cairne Bloodhoof <High Chieftain>
    [36648]  = {"", "o", 123094},           --Baine Bloodhoof <High Chieftain>
    [149742] = {"", "o", 6058},             --Tamaala Cairne's wife
    [93846] = {"", "o", 74750},             --Mayla Highmountain
    [93841] = {"", "y", 76255},             --Lasan Skyhorn Chieftain
    [93833] = {"", "bp", 73184},            --Jale Rivermane Chieftain
    [93836] = {"", "r", 74745},             --Torok Bloodtotem
    [4046] = {"", "bk", 7220},              --Magatha Grimtotem <Elder Crone>
    [45410] = {"", "bk", 6014},             --Elder Stormhoof <Grimtotem Chief>
    [45438] = {"", "bk", 6011},             --Arnak Grimtotem
    [11858] = {"", "bk", 6008},             --Grundig Darkcloud <Chieftain>
    [99107] = {"", "lg", 6010},             --Feltotem Blademaster
    [2487] = {"", "y", 6008},               --Fleet Master Seahorn

    [96180] = {"", "g", 145490, {53096, 11587} },            --Gelbin Mekkatorque <High Tinker, King of Gnomes>
    [90716] = {"Mechbot", "y", 74125},      --Gelbin Mekkatorque's Steam Armor
    [42489]	= {"", "b", 134538},	        --Captain Tread Sparknozzle <Mekkatorque's Advisor>
    [147950] = {"", "b", 135067},           --Cog Captain Winklespring <G.E.A.R.>
    [40478] = {"", "b", 5937},              --Elgin Clickspring Advisor>
    [147952] = {"", "b", 136565},           --Fizzi Tinkerbow <G.E.A.R.>

    [150208] = {"", "b", 60731},            --Tinkmaster Overspark <Chief Architect of Gnomish Engineering>
    [162393] = {"", "b", 136484},           --Gila Crosswires <Tinkmaster's Assistant>
    [157997] = {"", "bk", 146131, {155762, 155762} },          --Kelsey Steelspark <Gnomeregan Covert Ops>
    [149814] = {"", "b", 134597},           --Sapphronetta Flivvers
    [42396] = {"", "g", 5922},              --Nevin Twistwrench <S.A.F.E. Commander>
    [124153] = {"", "p", 16269},            --Wilfred Fizzlebang <Master Summoner>
    [114596] = {"", "bp", 76192, {18842} },           --Millhouse Manastorm <Kirin Tor>
    [101976] = {"", "bk", 57473},           --Millificent Manastorm <Engineering Genius>
    [116744] = {"", "g", 5808},             --Mekgineer-Lord Thermaplugg
    [149816] = {"", "kt", 133698},          --Prince Erazmin
    [150397] = {"", "y", 132213},           --King Mechagon
    [150760] = {"", "y", 134769},           --Bondo Bigblock <Yard Chief>
    [152747] = {"", "y", 135755},           --Christy Punchcog <Upgrade Specialist>
    [154967] = {"", "y", 132716},           --Walton Cogfrenzy <Chief Architect of Mechagon>

    [145616] = {"", "y", 112983},           --King Rastakhan
    [120904] = {"", "y", },                 --Princess Talanji
    [69918] = {"", "y", 110631},            --Zul the Prophet
    [138967] = {"", "r", 106151},           --Zul, Reborn
    [122760] = {"", "y", 116102},           --Wardruid Loti <Zanchuli Council>
    [126564] = {"", "y", 115119},           --Hexlord Raal <Zanchuli Council>
    [122864] = {"", "tt", 112919},          --Yazma <Zanchuli Council>
    [146124] = {"", "tt", 100495},          --Jo'nok, Bulwark of Torcali <Zanchuli Council>
    [122866] = {"", "y", 102515},           --Vol'kaal <Zanchuli Council>
    [134231] = {"", "bk", 129708},          --High Prelate Rata
    
    [130122] = {"", "bk", 5955},            --Speaker Ik'nal <Shadowtooth Clan>
    [1061] = {"", "r", 5943},               --Gan'zulah <Bloodscalp Chief>

    [69131] = {"", "bp", 35390},            --Frost King Malakk
    [29306] = {"", "bp", 14430},            --Gal'darah <High Prophet of Akali>
    [28503] = {"", "bk", 14016},            --Overlord Drakuru
    [28902] = {"", "r", 5945},              --Warlord Zol'Maz
    [28916] = {"", "r", 5949},              --Tiri Wife of Zol'maz
    [28917] = {"", "r", 5955},              --Yara
    [28918] = {"", "r", 5943},              --Drek'Maz

    [130255] = {"", "g", 12098},            --Zul'jin Amani
    [69134] = {"", "g", 35570},             --Kazra'jin
    [23863] = {"", "o", 24221},             --Daakara <The Invincible>
    [24239] = {"", "p", 12041},             --Hex Lord Malacrass
    [15407] = {"", "g", 1034},              --Chieftain Zul'Marosh

    [10540] = {"", "r", 34556},             --Vol'jin
    [131465] = {"", "r", 111238, {29433} },         --Rokhan NEW
    [145377] = {"", "r", 142796, {29433} },         --Rokhan BFA NEW
    [82877] = {"", "r", 46575},             --High Warlord Volrath <Horde War Captain>
    [158312] = {"", "r", 123091},           --Zekhan
    [16575] = {"", "r", 5943},              --Shadow Hunter Ty'jin <Ears of the Warchief>

    [11380] = {"", "p", 24256},             --Jin'do the Hexxer
    [52148] = {"", "o", 24261},             --Jin'do the Godbreaker
    [2534] = {"", "kt", 24342},             --Zanzil the Outcast
    [69132] = {"", "tt", 35435},            --High Priestess Mar'li    Gurubashi

    [7267] = {"", "o", 5878},               --Chief Ukorz Sandscalp
    [7272] = {"", "o", 	8419},              --Theka the Martyr
    [122661] = {"", "o", 115760},           --General Jakra'zet <Zanchuli Council>

    [14625] = {"", "bk", 7060},             --Overseer Oilfist <The Thorium Brotherhood>
    [10637] = {"", "bk", 7063},             --Malyfous Darkhammer <The Thorium Brotherhood>
    [134578] = {"", "g", 115274},           --Captain Delaryn Summermoon
    [90688] = {"", "lg", 54810},            --Tichondrius the Darkener <Lord of the Nathrezim>
    [110965] = {"", "bp", 58566},           --Elisande <Grand Magistrix>
    [121540] = {"", "lg", 713},             --Lalathin <Elisande's Pet>
    [114915] = {"", "lg", 78373},           --Andaris Narassin
    [101830] = {"", "r", 71525},            --First Arcanist Thalyssra
    [115505] = {"", "r", 74306},            --Chief Telemancer Oculeth
    [104998] = {"", "p", 72159},            --Silgryn
    [115092] = {"", "p", 71132},            --Arcanist Valtrois
    [104218] = {"", "bp", 58654},           --Advisor Melandrus <First Blade of Elisande>
    [103758] = {"", "bp", 58445},           --Star Augur Etraeus
    [104881] = {"", "bp", 58392, {137255, 137258} },           --Spellblade Aluriel <Captain of the Magistrix's Guard>  Lots of Nightborne NPC weapons
    [104528] = {"", "y", 68622},            --High Botanist Tel'arn
    [98208] = {"", "bp", 57776},            --Advisor Vandros

    [92347] = {"", "y", 72092, {42322} },             --Aponi Brightmane <Sunwalker Chieftain>
    [90883]	= {"", "bk", 72221, {108923} },	        --Lord Maxwell Tyrosus
    [16886] = {"", "y", 75746, {26003} },             --Arator the Redeemer
    [90250] = {"", "o", 72221, {85428} },             --Lord Grayson Shadowbreaker
    [17684] = {"", "bk", 9762},             --Vindicator Boros <Triumvirate of the Hand>
    [17844] = {"", "bk", 9762},             --Vindicator Aesom <Triumvirate of the Hand>
    [17843] = {"", "g", 9762},              --Vindicator Kuros <Triumvirate of the Hand>
    [68019] = {"", "lg", 82756},            --Kanrethad Ebonlocke
    [14823] = {"", "bk", 5925},             --Silas Darkmoon
    [98771] = {"", "r", 72590},             --Ritssyn Flamescowl <Council of the Black Harvest>
    [101513] = {"", "bk", 75213},		    --Lord Jorach Ravenholdt #2
    [15552] = {"", "lg", 7071},             --Doctor Weavil
    [21691] = {"", "b", 5925, {42822} },              --Toshley
    [126646] = {"", "b", 94654},            --Magister Umbric
    [132382] = {"", "p", 95017, {125668} },            --Magister Umbric VE

    [35222]  = {"", "r", 137828},          --Trade Prince Gallywix
    [152522] = {"", "o", 137828},          --Gazlowe
    [155390] = {"", "o", 136034},          --Grizzek Fizzwrench
    [2496] = {"", "bk", 7228},             --Baron Revilgaz
    [86225] = {"", "o", 43738},            --Railmaster Rocketspark <Blackfuse Company>
    [72694] = {"", "p", 38462},            --Siegecrafter Blackfuse
    [80808] = {"", "tt", 46128},           --Neesa Nox
    [46078] = {"", "bk", 18812},           --Boss Mida <Her Tallness>
    [75986] = {"", "bk", 18812},            --Ketya Shrediron <Principal Engineer>
    [6946] = {"", "b", 5964},              --Renzik "The Shiv"
    [136579]= {"", "bp", 18812},            --Cesi Loosecannon <Boss of Anyport>
    [41018] = {"", "bp", 136423},           --King Gurboggle
    [149904] = {"", "bp", 136037},          --Neri Sharpfin
    [34954] =  {"", "o", 37113},            --Gobber   

    [46133] = {"", "o", 143110},            --King Phaoris
    [45799] = {"", "o", 22043},             --Prince Nadun
    [47753] = {"", "bk", 145746},           --Dark Pharaoh Tekahn

    [126983] = {"", "r", 97285, {159635, 159635} },            --Harlan Sweete <Lord of the Irontide>
    [126832] = {"", "r", 98113, {159587} },            --Skycap'n Kragg
    [126841] = {"", "r", 98104},            --Sharkbait

    [108571] = {"", "bp", 57869, {128360, 128370} },     --Altruis the Sufferer
    [89362] = {"", "r", 56763, {128359, 128371} },      --Kayn Sunfury
    [21215] = {"", "bk", 11305, {32065, 32066} },        --Leotheras the Blind   21845 Demon Grandpa
    [94836] = {"", "p", 52005, {128360, 128370} },         --Varedis Felsoul
    [98914] = {"", "p", 56205},         --Caria Felsoul
    [7783] = {"", "r", 5995},           --Loramus Thalipedes
    [89398] = {"", "o", 57068, {122430}},  --	Allari the Souleater
    [90624] = {"", "g", 56804, {128359, 128371} },      --Kor'vas Bloodthorn
    [101317] = {"", "p", 57101, {128360, 128370} },     --Illysanna Ravencrest
    [105841] = {"", "g", 53899},        --Lil'idan
    [142152] = {"", "r", 5937},         --Kinndy Sparkshine
    [29261] = {"", "p", 5922},          --Windle Sparkshine
    [16128] = {"", "bp", 15650, {42139} }, --Rhonin <Leader of the Kirin Tor>
    [16800] = {"", "r", 95030, {29114} }, --Grand Magister Rommath
    [16801] = {"", "bp", 72620, {128826} }, --Halduron Brightwing
    [122366]= {"", "lg", 87042},        --Varimathras LEG
    [16287] = {"", "r", 9742},  --Ambassador Sunsorrow
    [20406] = {"", "r", 9730, {27405, 27406} },  --Champion Cyssa Dawnrose
    [10778] = {"", "b", 5980},          --Janice Felstone
    [3520]  = {"", "o", 5983},          --Ol' Emma
    [4488]  = {"", "o", 6036},          --Parqual Fintallas     Desolate Council
    [36296] = {"", "p", 6044},          --Apothecary Hummel
    [16075] = {"", "g", 5964},          --Kwee Q. Peddlefeet
    [13429] = {"", "r", 6632},          --Nardstrum Copperpinch <Smokywood Pastures>
    [13434] = {"", "r", 6629},          --Macey Jinglepocket <Smokywood Pastures>
    [4606] = {"", "bp", 80723},         --Aelthalyste Banshee
    [10436] = {"", "p", 6052},          --Baroness Anastari     Stratholme
    [27683] = {"", "r", 7014},          --Dahlia Suntouch  High Elf
    [28318] = {"", "lg", 16294},        --Grand Apothecary Putress
    [27922] = {"", "bk", 123392, {34269} },   --Ranger Captain Areiel
    [36225] = {"", "bk", 123392, {45085, 45085} },   --Dark Ranger Anya
    [44637] = {"", "bk", 123392, {166783} },   --Dark Ranger Velonara
    [139609] = {"", "o", 5977},         --John J. Keeshan
    [117084] = {"", "bp", 70676, {13623} },       --Kruul     	Doomlord
    [94015]  = {"", "r", 50326, {124085} },        --Kazzak    --Same model as Kaz'rogal 95280
    [31283]  = {"", "r", 14608, {43110} },     --Orbaz Bloodbane <The Hand of Suffering>
    [95136] = {"", "r", 75387, {82594} },    --Addie Fizzlebog <Apprentice Hunter>
    [27210] = {"", "r", 14192, },           --High General Abbendis {14954} Scarlet Shield
    [3977] = {"", "r", 5840, {812} },       --Sally Whitemane
    [639] = {"", "bk", 5780, {68195, 68195} },   --Edwin Vancleef <Defias Kingpin>
    [42372] = {"", "r", 72306, {18816, 18816} },  --Vanessa Vancleef
    [102914] = {"", "g", 75808, {65972} },        --Emmarel Shadewarden
    [3432] = {"", "lg", 6018},          --Mankrik
    [10668] = {"Olgra", "kt", 6027},        --Beaten Corpse Olgra, Mankrik's Wife
    [54870] = {"", "r", 29194, {7612} },      --General Nazgrim
    [109915] = {"The Four Horsemen", "bk", 72381, {38633} },    --Nazgrim
    [112504] = {"The Four Horsemen", "p", 74292, {79321} },     --High Inquisitor Whitemane
    [113580] = {"", "bp", 38692},       --Whitemane's Deathcharger
    [26581] = {"", "bp", 75837, {35939} },     --Koltira Deathweaver
    [29799] = {"", "b", 14674, {35561, 35561} },      --Thassarian
    [18141] = {"", "bp", 6030},         --Greatmother Geyah
    [137837] = {"", "o", 115768, {118400} },     --Overlord Geya'rah
    [67846] = {"", "o", 6018, {13052} },      --Ishi <Blademaster>
    [44640] = {"", "bk", 6021, {105686} },     --High Warlord Cromush
    [37813] = {"", "bp", 16694, {51905} },     --Deathbringer Saurfang
    [25257] = {"Kor\'kron Warlord", "r", 6018, {12784} },  --Saurfang the Younger  Dranosh Saurfang
    [80751] = {"", "o", 6030},          --Mother Kashur
    [21950] = {"", "r", 6018},          --Garm Wolfbrother <Chieftain of the Thunderlord Clan>
    [18106] = {"", "bk", 6024},         --Jorin Deadeye
    [3230] = {"", "bk", 6021, {14870}},      --Nazgrel <Advisor to Thrall>
    [77020] = {"", "o", 39967},         --Kor'gall
    [29227] = {"", "b", 14497, {13262} },      --Highlord Alexandros Mograine <The Ashbringer>
    [28444] = {"The Four Horsemen", "bk", 14715, {40276, 40276} },     --Darion Mograine DK
    [20423] = {"", "p", 5974},          --Kel'Thuzad <The Kirin Tor>
    [15990] = {"", "p", 8811},          --Kel'Thuzad Lich
    [16028] = {"", "o", 8909},          --Patchwerk
    [16061] = {"", "bp", 8859},         --Instructor Razuvious
    [16060] = {"", "b", 8808},          --Gothik the Harvester
    [15953] = {"", "y", 8795},          --Grand Widow Faerlina
    [15954] = {"", "bk", 8846},         --Noth the Plaguebringer
    [15936] = {"", "p", 1333},          --Heigan the Unclean
    [4275] = {"", "lg", 5791, {6322} },  --Archmage Arugal
    [23433] = {"", "r", 9746},          --Barthamus
    [55869] = {"", "o", 25777},         --Alizabal <Mistress of Hate>
    [125083] = {"", "bk", 86926},       --Diima, Mother of Gloom
    [125084] = {"", "r", 87025},        --Noura, Mother of Flames
    [125085] = {"", "p", 86912},        --Asara, Mother of Night
    [125436] = {"", "lg", 87039},       --Thu'raya, Mother of the Cosmos
    [136413] = {"", "lg", 9888},        --Syrawon the Dominus
    [102649] = {"", "p", 82296, {49340, 49340} },   --Lilian Voss
    [138287] = {"", "bk", 140415, {160500, 160501} },   --Lilian Voss Horde

    --Shadowlands
    [165714] = {"", "b", 161885, {177089} },    --Kyrestia the Firstborne <Archon>
    [167168] = {"", "y", 162051, {174413} },    --Devos <Paragon of Loyalty>
    [167410] = {"", "p", 162051, {174415} },    --Devos Purple
    [159929] = {"", "b", 168730, },             --Uther Kyrian Blue
    [166668] = {"", "p", 168730, {173905} },    --Uther Kyrian Purple
    [165716] = {"", "y", 168051, {174438} },    --Xandria <Paragon of Courage>
    [166156] = {"", "y", 169715, {176074, 174433} },    --Thenios <Paragon of Wisdom>
    [166153] = {"", "bp", 169328, {171130, 174429} },   --Vesiphone <Paragon of Purity>
    [166609] = {"", "bp", 162228, {174424} },   --Chyrus <Paragon of Humility>
    [165097] = {"", "bp", 159616, {182152} },   --Polemarch Adrestes
    [165011] = {"", "bp", 160858, },            --Pelagos
    [165042] = {"", "bp", 160091, {171132} },   --Kleia
    [165248] = {"", "y", 158521, },             --Mikanikos <Forgelite Prime>

    [165653] = {"", "bp", 169436},  --Winter Queen
    [166909] = {"", "bp", 169689, {180024} }, --Lord Herne <The Wild Hunt>
    [165249] = {"", "bp", 165162, {180071} },   --Hunt-Captain Korayn
    [165250] = {"", "bp", 174884, {178119} },  --Ara'lon <The Wild Hunt>
    [165218] = {"", "bp", 163204, {178119} }, --Niya
    [165797] = {"", "bp", 159591},      --Lady Moonberry
    [165567] = {"", "tt", 164362},      --Dreamweaver
    [165246] = {"", "bp", 169665},      --Droman Tashmur
    [171648] = {"", "g", 166417},       --Ysera

    [165005] = {"", "r", 166196, {179391} },    --Sire Denathrius
    [158653] = {"", "y", 166196, {178716} },    --Prince Renathal
    [165291] = {"", "bk", 160308, {175939} },   --The Accuser <Harvester of Pride>
    [165589] = {"", "o", 166196, {178716} },    --The Curator <Harvester of Avarice>
    [165269] = {"", "bk", 160497, },    --The Countess <Harvester of Desire>
    [165820] = {"", "bk", 163359, {178494} },   --The Tithelord <Harvester of Envy>
    [165866] = {"", "bk", 160516, },    --The Stonewright <Harvester of Wrath>
    [166442] = {"", "bk", 167241, {173724} },   --The Fearstalker <Harvester of Dread>
    [165652] = {"", "r", 161346}, --Kael'thas
    [170813] = {"", "r", 161346}, --Kael'thas Sunstrider <Lord of the Blood Elves>
    [165864] = {"", "bk", 169130, {175847} },   --Nadjia the Mistblade
    [165031] = {"", "bk", 163273, },            --Theotar <The Mad Duke>
    [165676] = {"", "tt", 161345, {174639} },   --General Draven

    [165182] = {"", "g", 154350, {105037, 105037} }, --Baroness Draka
    [165417] = {"", "bk", 169153, {181255} },   --Alexandros Mograine <The Ashbringer>
    [165819] = {"", "y", 168421, }, --Kel'Thuzad <Archlich>
    [162549] = {"", "g", 169115, {156712} },   --Baroness Vashj <Matron of Spies>
    [165966] = {"", "r", 167843, {32841} },    --Khaliiq <Vashj's Devoted>
    [167748] = {"", "bk", 162237},  --Osbourne Black <Soul Warden>
    [158007] = {"", "o", 168807, },    --Margrave Krexus
    [165571] = {"", "bk", 164384, {176551} }, --Secutor Mevix <House of the Chosen>
    [165333] = {"", "bk", 169700},    --Plague Deviser Marileth
    [165210] = {"", "bk", 169669},  --Emeni <The Slaughter Daughter>
    [165130] = {"", "bk", 168753, {174305, 174305} },  --Bonesmith Heirmir
    
    [165654] = {"", "tt", },    --The Arbitor
    [167486] = {"", "tt", 164386},    --Tal-Inara <Honored Voice>
    [167424] = {"", "o", 165485}, --Overseer Kah-Sher <Will of the Arbiter>
    [163490] = {"", "bk", 165748, {177838}},    --Highlord Bolvar Fordragon <Knights of the Ebon Blade>

    [171770] = {"", "tt", 169718},  --Ve'nari
    [165799] = {"", "tt", },    --The Jailer **Sound
    [171356] = {"", "tt", 171008},    --Runecarver
    [164449] = {"", "tt", 139981, {181374}},    --Sylvanas Windrunner **Sound

    --9.1
    --Sound files are still encrypted
    [178372] = {"", "tt", nil, {183938} },  --Maw Anduin
    [178072] = {"", "tt", nil, {183938} },  --Maw Anduin Helm
    [179314] = {"", "bk", nil, },   --Banshee Sylvanas
    [180211] = {"", "y", nil, {168268} },    --Thrall SL
    [178295] = {"", "r", nil, },  --Kin'tessa Dread Queen
    [177514] = {"", "r", nil, },        --Mal'Ganis     Sound File:4078587

    --9.2
    [185421] = {"", "tt", nil, {185436} },   --The Jailer 2.0
    [180140] = {"", "bk", 182879, {185955} }, --Primus Regular

    [183685] = {"", "bk", 188855, },     --Pocopoc
    [181546] = {"", "y", }, --Prototype of Renewal
    [181548] = {"", "y", }, --Prototype of Absolution
    [181549] = {"", "y", }, --Prototype of War
    [181551] = {"", "y", nil, {189799}}, --Prototype of Duty
    [181286] = {"", "bk", 191052, {42775}},    --Sylvanas 9.2
    [181274] = {"", "bk", 191052},      --Sylvanas Simple
    --[] = {"", "", },
};

local Catalogue;
local NUM_MAX_ENTRY_BUTTONS = 0;

do
    local expansionID = NarciClassicAPI.GetExpansionID();

    if expansionID > 1 then
        Catalogue = {
            {
                {
                    11699,
                    1747,
                    1748,
                    ["name"] = "Stormwind",
                },
                {
                    20354,
                    10778,
                    3520,
                    ["name"] = "Lordaeron",
                },
                {
                    4968,
                    16128,
                    18166,
                    20423,
                    8379,
                    4275,
                    ["name"] = "Spellcaster",
                },
                {
                    16819,
                    ["name"] = "Stromgarde",
                },
                {
                    10812,
                    20349,
                    12126,
                    10944,
                    ["name"] = "Silver Hand",
                },
                {
                    639,
                    3977,
                    10926,
                    10936,
                    11063,
                    ["name"] = "Misc",
                },
                ["name"] = "Human",
            },
            {
                {
                    22917,
                    15362,
                    7999,
                    3679,
                    15215,
                    ["name"] = "Night Elf",
                },
                {
                    11486,
                    ["name"] = "Highborne",
                },
                {
                    16886,
                    ["name"] = "High Elf",
                },
                {
                    19622,
                    24664,
                    16802,
                    16800,
                    16801,
                    17076,
                    16287,
                    20406,
                    ["name"] = "Blood Elf",
                },
                {
                    21212,
                    ["name"] = "Naga",
                },
                ["name"] = "Elf",
            },
            {
                {
                    3057,
                    ["name"] = "Thunder Bluff",
                },
                {
                    4046,
                    11858,
                    ["name"] = "Grimtotem",
                },
                {
                    2487,
                    ["name"] = "Misc",
                },
                ["name"] = "Tauren",
            },
            {
                {
                    4488,
                    4606,
                    10436,
                    ["name"] = "The Forsaken",
                },
                {
                    15990,
                    16060,
                    15936,
                    15953,
                    15954,
                    16028,
                    10939,
                    10946,
                    ["name"] = "Scourge",
                },
                {
                    16061,
                    ["name"] = "Ebon Blade",
                },
                {
                    15687,
                    ["name"] = "Neutral",
                },
                ["name"] = "Undead",
            },
            {
                {
                    14823,
                    21691,
                    15552,
                    ["name"] = "Misc",
                },
                ["name"] = "Gnome",
            },
            {
                {
                    2496,
                    6946,
                    16075,
                    13429,
                    13434,
                    ["name"] = "Goblin",
                },
                ["name"] = "Goblin",
            },
            {
                {
                    23284,
                    1749,
                    10184,
                    ["name"] = "Black",
                },
                {
                    19935,
                    ["name"] = "Bronze",
                },
                {
                    23433,
                    ["name"] = "Misc",
                },
                ["name"] = "Dragon",
            },
            {
                {
                    11502,
                    21181,
                    ["name"] = "Fire",
                },
                {
                    12201,
                    ["name"] = "Earth",
                },
                {
                    18708,
                    ["name"] = "Misc",
                },
                ["name"] = "Elemental",
            },
            {
                {
                    2784,
                    8929,
                    ["name"] = "Ironforge",
                },
                {
                    19379,
                    ["name"] = "Wildhammer",
                },
                {
                    9019,
                    14625,
                    10637,
                    ["name"] = "Dark Iron",
                },
                ["name"] = "Dwarf",
            },
            {
                {
                    18076,
                    ["name"] = "Warsong",
                },
                {
                    4949,
                    11946,
                    3230,
                    ["name"] = "Frostwolf",
                },
                {
                    17011,
                    10429,
                    ["name"] = "Blackrock",
                },
                {
                    17008,
                    22871,
                    ["name"] = "Shadowmoon",
                },
                {
                    18106,
                    ["name"] = "Bleeding Hollow",
                },
                {
                    16808,
                    ["name"] = "Shattered Hand",
                },
                {
                    18141,
                    ["name"] = "Mag'har",
                },
                {
                    6767,
                    22004,
                    21984,
                    3432,
                    10668,
                    21950,
                    11980,
                    ["name"] = "Misc",
                },
                ["name"] = "Orc",
            },
            {
                {
                    10540,
                    16575,
                    ["name"] = "Darkspear",
                },
                {
                    11380,
                    2534,
                    ["name"] = "Gurubashi",
                },
                {
                    23863,
                    24239,
                    15407,
                    ["name"] = "Amani",
                },
                {
                    7267,
                    7272,
                    ["name"] = "Farraki",
                },
                {
                    1061,
                    ["name"] = "Misc",
                },
                ["name"] = "Troll",
            },
            {
                {
                    18481,
                    17545,
                    ["name"] = "Naaru",
                },
                ["name"] = "Interstellar",
            },
            {
                {
                    2748,
                    7228,
                    ["name"] = "Watchers",
                },
                ["name"] = "Titan-forged",
            },
            {
                {
                    22917,
                    21215,
                    7783,
                    ["name"] = "Demon Hunter",
                },
                {
                    17968,
                    25315,
                    15690,
                    ["name"] = "Eredar",
                },
                {
                    10813,
                    ["name"] = "Nathrezim",
                },
                ["name"] = "Demon",
            },
            {
                {
                    17684,
                    17843,
                    17844,
                    ["name"] = "Argus",
                },
                {
                    18538,
                    ["name"] = "Outland",
                },
                ["name"] = "Draenei",
            },
            {
                {
                    19044,
                    ["name"] = "Gronn",
                },
                {
                    21838,
                    ["name"] = "Arakkoa",
                },
                ["name"] = "Draenor",
            },
            {
                {
                    12238,
                    ["name"] = "Wild Gods",
                },
                ["name"] = "Ancients",
            },
            {
                {
                    15589,
                    22137,
                    ["name"] = "Old Gods",
                },
                {
                    19554,
                    ["name"] = "Void Lord",
                },
                {
                    20454,
                    ["name"] = "Ethereal",
                },
                {
                    11496,
                    ["name"] = "Misc",
                },
                ["name"] = "Void",
            },
        };
    else
        Catalogue = {
            {
                {
                    11699,
                    1747,
                    1748,
                    ["name"] = "Stormwind",
                },
                {
                    10778,
                    3520,
                    ["name"] = "Lordaeron",
                },
                {
                    4968,
                    16128,
                    8379,
                    4275,
                    ["name"] = "Spellcaster",
                },
                {
                    10812,
                    12126,
                    10944,
                    ["name"] = "Silver Hand",
                },
                {
                    639,
                    3977,
                    10926,
                    10936,
                    11063,
                    ["name"] = "Misc",
                },
                ["name"] = "Human",
            },
            {
                {
                    15362,
                    7999,
                    3679,
                    15215,
                    ["name"] = "Night Elf",
                },
                {
                    11486,
                    ["name"] = "Highborne",
                },
                ["name"] = "Elf",
            },
            {
                {
                    3057,
                    ["name"] = "Thunder Bluff",
                },
                {
                    4046,
                    11858,
                    ["name"] = "Grimtotem",
                },
                {
                    2487,
                    ["name"] = "Misc",
                },
                ["name"] = "Tauren",
            },
            {
                {
                    4488,
                    4606,
                    10436,
                    ["name"] = "The Forsaken",
                },
                {
                    15990,
                    16060,
                    15936,
                    15953,
                    15954,
                    16028,
                    10939,
                    10946,
                    ["name"] = "Scourge",
                },
                {
                    16061,
                    ["name"] = "Ebon Blade",
                },
                ["name"] = "Undead",
            },
            {
                {
                    14823,
                    15552,
                    ["name"] = "Misc",
                },
                ["name"] = "Gnome",
            },
            {
                {
                    2496,
                    6946,
                    16075,
                    13429,
                    13434,
                    ["name"] = "Goblin",
                },
                ["name"] = "Goblin",
            },
            {
                {
                    1749,
                    10184,
                    ["name"] = "Black",
                },
                ["name"] = "Dragon",
            },
            {
                {
                    11502,
                    ["name"] = "Fire",
                },
                {
                    12201,
                    ["name"] = "Earth",
                },
                ["name"] = "Elemental",
            },
            {
                {
                    2784,
                    8929,
                    ["name"] = "Ironforge",
                },
                {
                    9019,
                    14625,
                    10637,
                    ["name"] = "Dark Iron",
                },
                ["name"] = "Dwarf",
            },
            {
                {
                    4949,
                    11946,
                    3230,
                    ["name"] = "Frostwolf",
                },
                {
                    10429,
                    ["name"] = "Blackrock",
                },
                {
                    6767,
                    3432,
                    10668,
                    11980,
                    ["name"] = "Misc",
                },
                ["name"] = "Orc",
            },
            {
                {
                    10540,
                    ["name"] = "Darkspear",
                },
                {
                    11380,
                    2534,
                    ["name"] = "Gurubashi",
                },
                {
                    7267,
                    7272,
                    ["name"] = "Farraki",
                },
                {
                    1061,
                    ["name"] = "Misc",
                },
                ["name"] = "Troll",
            },
            {
                {
                    2748,
                    7228,
                    ["name"] = "Watchers",
                },
                ["name"] = "Titan-forged",
            },
            {
                {
                    7783,
                    ["name"] = "Demon Hunter",
                },
                {
                    10813,
                    ["name"] = "Nathrezim",
                },
                ["name"] = "Demon",
            },
            {
                {
                    12238,
                    ["name"] = "Wild Gods",
                },
                ["name"] = "Ancients",
            },
            {
                {
                    15589,
                    ["name"] = "Old Gods",
                },
                {
                    11496,
                    ["name"] = "Misc",
                },
                ["name"] = "Void",
                },
        };
    end

    Catalogue.numCategory = #Catalogue;
    for i = 1, Catalogue.numCategory do
        local subCategory = Catalogue[i];
        local numSubcategory = #subCategory;
        local entry;
        local numEntries = 0;
        local numButtons = 0;
        for j = 1, numSubcategory do
            entry = subCategory[j];
            numEntries = numEntries + #entry;
        end
        numButtons = numEntries + numSubcategory;
        subCategory.numEntries = numEntries;
        NUM_MAX_ENTRY_BUTTONS = max(NUM_MAX_ENTRY_BUTTONS, numButtons);
    end
    Catalogue.numCategory = Catalogue.numCategory + 1;
end

local function GetIncludedNPCList()
    local tbl = {};
    local n = 0;
    for i, category in ipairs(Catalogue) do
        for j, raceNPC in ipairs(category) do
            for k, npcID in ipairs(raceNPC) do
                n = n + 1;
                tbl[n] = npcID;
            end
        end
    end
    return tbl
end

function GetExistList()
    local invalidID = {};
    for _, id in ipairs(NarciDevOutput) do
        invalidID[id] = true;
    end

    local tbl = {};

    --NarciNPCCategory
    local tinsert = table.insert;
    local numCategory = 0;

    for i, category in ipairs(Catalogue) do
        --Elf
        tbl[i] = {};
        tbl[i].name = category.name;

        local numSubcategory = 0;
        for j, raceNPC in ipairs(category) do
            --Night Elf
            local npcList = {};
            for k, npcID in ipairs(raceNPC) do
                --Tyrande
                if not invalidID[npcID] then
                    tinsert(npcList, npcID);
                end
            end
            if #npcList > 0 then
                npcList.name = raceNPC.name;
                tinsert(tbl[i], npcList);
            end
        end
    end

    NarciNPCCategory = tbl;
end

-----------------------------------------------------------------------------------------------
--Gradually Update Scroll Range
local RangeAnim = NarciAPI_CreateAnimationFrame(0.5);

RangeAnim:SetScript("OnShow", function(self)
    _, self.StartValue = self.scrollBar:GetMinMaxValues();
    if self.EndValue < 0.1 then
        self.scrollBar.Thumb:Hide();
    else
        self.scrollBar.Thumb:Show();
    end
end)

local function Range_OnUpdate(self, elapsed)
	self.total = self.total + elapsed;
	local range = inOutSine(self.total, self.StartValue, self.EndValue, self.duration);

	if self.total >= self.duration then
		range = self.EndValue;
        self:Hide();
    end
    self.scrollBar:SetMinMaxValues(0, range);
end

RangeAnim:SetScript("OnUpdate", Range_OnUpdate);

local function SmoothRange(scrollBar, newRange)
    RangeAnim:Hide();
    RangeAnim.scrollBar = scrollBar;
    RangeAnim.EndValue = newRange;
    RangeAnim:Show();
end

local function UpdateInnerShadowStates(scrollBar, newMax, smoothing)
	local currValue = scrollBar:GetValue();
    local minVal, maxVal = scrollBar:GetMinMaxValues();
    local maxVal = newMax or maxVal;
    if maxVal == 0 then
        scrollBar.Thumb:Hide();
        scrollBar.TopShadow:Hide();
        scrollBar.BottomShadow:Hide();
        return
    else
        scrollBar.Thumb:Show();
    end

    if not smoothing then
        if ( currValue >= maxVal - 12) then
            scrollBar.BottomShadow:Hide();
        else
            scrollBar.BottomShadow:Show();
        end
        
        if ( currValue <= minVal + 12) then
            scrollBar.TopShadow:Hide();
        else
            scrollBar.TopShadow:Show();
        end

        scrollBar.BottomShadow:SetAlpha(1);
        scrollBar.TopShadow:SetAlpha(1);
    else
        if ( currValue >= maxVal - 12) then
            FadeFrame(scrollBar.BottomShadow, 0.2, 0);
            --reach bottom
        else
            if not scrollBar.BottomShadow:IsShown() then
                FadeFrame(scrollBar.BottomShadow, 0.2, 1);
            end
        end
        
        if ( currValue <= minVal + 12) then
            FadeFrame(scrollBar.TopShadow, 0.2, 0);
        else
            if not scrollBar.TopShadow:IsShown() then
                FadeFrame(scrollBar.TopShadow, 0.2, 1);
            end
        end
    end
end

local UpdateModelDelay = NarciAPI_CreateAnimationFrame(0.25);
UpdateModelDelay:SetScript("OnUpdate", function(self, elapsed)
	self.total = self.total + elapsed;
    if self.total >= self.duration then
        self:Hide();
        MatchPreviewModel:Show();
        MatchPreviewModel:SetAlpha(0);
        if self.isDisplayID then
            MatchPreviewModel.isDisplayID = true;
            MatchPreviewModel:SetDisplayInfo(self.id);
        else
            MatchPreviewModel.isDisplayID = nil;
            MatchPreviewModel:SetCreature(self.id);
        end
        MatchPreviewModel.id = self.id;
        After(0.1, function()
            FadeFrame(MatchPreviewModel, 0.25, 1, 0);
        end)
    end
end)

local function UpdatePreviewModel(id, isDisplayID)
    if id then
        if MatchPreviewModel.id ~= id or MatchPreviewModel.isDisplayID ~= isDisplayID then
            UpdateModelDelay.total = 0;
            UpdateModelDelay.id = id;
            UpdateModelDelay.isDisplayID = isDisplayID;
            UpdateModelDelay:Show();
        end
    end
end

-----------------------------------------------------------------------------------------------
local function UpdateRenderAreaEntry(value)
    local buttons = EntryTab.buttons;
    local button;
    local offset = 0;
    local npcHeight = NPC_BUTTON_HEIGHT;
    local categoryHeight = npcHeight / 2;
    local endValue = value + TAB_HEIGHT + 4 * npcHeight;
    local i = 1;

    value = value - 4 * npcHeight;

    while (i <= EntryTab.numActiveButton) do
        button = buttons[i];
        if button.mode == "npc" then
            offset = offset + npcHeight;
            if offset > value and offset <= endValue then
                button:Show();
            else
                button:Hide();
            end
        else
            offset = offset + categoryHeight;
            if button.isCollapsed then
                i = i + button.numChild;
            end
        end

        i = i + 1;
    end
end

local function UpdateRenderAreaMatch(value)
    local buttons = MatchTab.buttons;
    local button;
    local offset = 0;
    local npcHeight = NPC_BUTTON_HEIGHT;
    local endValue = value + TAB_HEIGHT + 4 * npcHeight;
    local i = 1;

    value = value - 4 * npcHeight;

    while (i <= MatchTab.numActiveButton) do
        button = buttons[i];
        offset = offset + npcHeight;
        if offset > value and offset <= endValue then
            button:Show();
        else
            button:Hide();
        end

        i = i + 1;
    end
end

local function UpdateScrollRange(scrollFrame, smoothing, frameType)
    --frameType  0 Each button has the same height  1 Heights varies
    local scrollBar = scrollFrame.scrollBar;
    local numActiveButton = scrollFrame.numActiveButton;
    local categoryButtons = scrollFrame.categoryButtons;
    local numCollapsedButton, numSubcategory= 0, 0;

    if categoryButtons then
        numSubcategory = scrollFrame.numSubcategory;
        local categoryButton;
        for i = 1, #categoryButtons do
            categoryButton = categoryButtons[i];
            if categoryButton.isCollapsed then
                numCollapsedButton = numCollapsedButton + categoryButton.numChild;
            end
        end
    end

    local buttonHeight = 16;
    local ButtonPerPage = 8;
    local totalHeight = (numActiveButton - numCollapsedButton - numSubcategory/2 + 0) * NPC_BUTTON_HEIGHT;
    local maxScroll = max(0, totalHeight - TAB_HEIGHT);
    scrollFrame.range = maxScroll;

    if smoothing then
        SmoothRange(scrollBar, maxScroll);
        UpdateInnerShadowStates(scrollBar, maxScroll, true);
    else
        scrollBar:SetMinMaxValues(0, maxScroll);
        UpdateInnerShadowStates(scrollBar, maxScroll, false);
    end
    
    if frameType == 1 then
        UpdateRenderAreaEntry(scrollBar:GetValue());
    else
        --UpdateRenderAreaMatch(scrollBar:GetValue());
    end
end

--------------------
--Build Name Table--
--------------------
local VirtualTooltipName = "Narci_CreatureNameRetriever";
local NPCTooltipName = "Narci_NPCSearchBoxTooltip";

local VirtualTooltip = CreateFrame("GameTooltip", VirtualTooltipName, UIParent, "GameTooltipTemplate");
local lineName = _G[VirtualTooltipName.. "TextLeft1"];
local lineTitle = _G[VirtualTooltipName.. "TextLeft2"];

local TOOLTIP_UNIT_LEVEL = "%?";                    --"Level %d"
local NARCI_NPC_BROWSER_TITLE_LEVEL = NARCI_NPC_BROWSER_TITLE_LEVEL;      --"Level ??"

local find = string.find;
local function IsTooltipLineTitle(text)
    if not text then
        return false
    else
        return not (find(text, TOOLTIP_UNIT_LEVEL) or find(text, NARCI_NPC_BROWSER_TITLE_LEVEL))
    end
end

local function GetKeyTable(table)
    local keys = {};
    for k, v in pairs(table) do
        tinsert(keys, k);
        NUM_NPC_TOTAL = NUM_NPC_TOTAL + 1;
    end
    return keys;
end

local function RequestCreatureInfo(id)
    VirtualTooltip:SetHyperlink(format("unit:Creature-0-0-0-0-%d", id));
end

local function RequestAllCreatureInfo(list)
    for k, v in pairs(list) do
        VirtualTooltip:SetHyperlink(format("unit:Creature-0-0-0-0-%d", k));
    end
end


local function GetNPCName(creatureID)
    VirtualTooltip:SetOwner(UIParent, "ANCHOR_NONE");
    VirtualTooltip:SetHyperlink(format("unit:Creature-0-0-0-0-%d", creatureID));
    return lineName:GetText()
end

local function GetNPCTitle(creatureID)
    VirtualTooltip:SetOwner(UIParent, "ANCHOR_NONE");
    VirtualTooltip:SetHyperlink(format("unit:Creature-0-0-0-0-%d", creatureID));
    if IsTooltipLineTitle(lineTitle:GetText()) then
        return lineTitle:GetText()
    else
        return false
    end
end

local tempName;
local function GetNPCNameAndTitle(creatureID)
    VirtualTooltip:SetOwner(UIParent, "ANCHOR_NONE");
    VirtualTooltip:SetHyperlink(format("unit:Creature-0-0-0-0-%d", creatureID));
    tempName = lineName:GetText() or "";
    if IsTooltipLineTitle(lineTitle:GetText()) then
        return {tempName, lineTitle:GetText()}, (tempName == "")
    else
        return {tempName, nil}, (tempName == "")
    end
end

--------------------------------------------------------------------------
--My Favorites
local FavUtil = {};
FavUtil.favNPCs = {};
FavUtil.numFavs = 0;

function FavUtil:Load()
    if not NarcissusDB then
        print("Cannot find NarcissusDB");
        return
    end

    NarcissusDB.Favorites = NarcissusDB.Favorites or {};
    NarcissusDB.Favorites.FavoriteCreatureIDs = NarcissusDB.Favorites.FavoriteCreatureIDs or {};
    self.db = NarcissusDB.Favorites.FavoriteCreatureIDs;

    local numFavs = 0;
    for npcID, isFav in pairs(self.db) do
        if isFav then
            self.favNPCs[npcID] = true;
            numFavs = numFavs +1;
            RequestCreatureInfo(npcID);
        end
    end
    self.numFavs = numFavs;

    return numFavs
end

function FavUtil:Add(creatureID)
    if creatureID then
        self.favNPCs[creatureID] = true;
        self.db[creatureID] = true;
        self.numFavs = self.numFavs + 1;
        PlaySound(39672, "SFX");
        return true;
    else
        return false;
    end
end

function FavUtil:Remove(creatureID)
    if not creatureID then return false end;
    self.favNPCs[creatureID] = false;
    local numFavs = 0;
    wipe(self.db);
    for id, isFav in pairs(self.favNPCs) do
        if isFav then
            self.db[id] = true;
            numFavs = numFavs + 1;
        end
    end
    self.numFavs = numFavs;

    return numFavs;
end

function FavUtil:IsFavorite(creatureID)
    return self.favNPCs[creatureID];
end

function FavUtil:GetFavoriteNPCs()
    return self.favNPCs;
end

function FavUtil:GetNumFavorites()
    return self.numFavs or 0;
end


-----------------------------------------------------------------------------------------------
local NPCCardAPI = {};

local function ShowMouseOverButtons(anchorButton)
    MouseOverButtons:SetPoint("RIGHT", anchorButton, "RIGHT", -2, 0);
    MouseOverButtons:Show();
    MouseOverButtons.parent = anchorButton;
    QuickFavoriteButton.parent = anchorButton;
    QuickFavoriteButton.isFav = anchorButton.isFav;

    if anchorButton.isFav then
        QuickFavoriteButton.Icon:SetTexCoord(0.75, 1, 0.25, 0.5);
    else
        QuickFavoriteButton.Icon:SetTexCoord(0.5, 0.75, 0.25, 0.5);
    end

    MouseOverButtons.WeaponMark:SetShown(anchorButton.weapons);
end

local function SetNPCModel(model, id, isDisplayID)
    model.isModelLoaded = false;
    if isDisplayID then
        model:SetDisplayInfo(id);
        model.displayID = id;
        model.creatureID = nil;
    else
        model:SetCreature(id);
        model.creatureID = id;
        model.displayID = nil;
    end

    model:SetModelAlpha(0);
    After(0.1, function()
        model:SetModelAlpha(1);
	end);
end

local function NPCCard_OnEnter(self)
    if self.Highlight:IsShown() then
        FadeFrame(self.Highlight, 0.12, 1);
    end

    if self.creatureID then
        ShowMouseOverButtons(self);
    else
        MouseOverButtons:Hide();
    end
end

local function NPCCard_OnClick(self, button, down, holdWeapon)
    if self.creatureID or self.displayID then
        ACTOR_CREATED = true;
        local model = _G["NarciNPCModelFrame"..TARGET_MODEL_INDEX];
        if self.displayID then
            SetNPCModel(model, self.displayID, true);
        else
            SetNPCModel(model, self.creatureID);
        end

        model.holdWeapon = holdWeapon;
        model.equippedWeapons = self.weapons;
        if holdWeapon and self.weapons then
            for i = 1, #self.weapons do
                model:EquipItem(self.weapons[i]);
            end
        end
        if self.voiceID then
            PlaySound(self.voiceID, "Dialog");
        end
     
        local creatureName = self.creatureName;
        model.creatureName = creatureName;
        if self.hasPortrait and self.creatureID then
            NarciPhotoModeAPI.OverrideActorInfo(TARGET_MODEL_INDEX, creatureName, self.weapons, "Interface/AddOns/Narcissus/Art/Widgets/NPCBrowser/Portraits/".. self.creatureID);
        else
            NarciPhotoModeAPI.OverrideActorInfo(TARGET_MODEL_INDEX, creatureName, self.weapons);
        end
        model:SetActive(true);

        if button == "RightButton" then
            BrowserFrame:Close();
        end
    end
end

local function AddModelAndEquipItems(self, button)
    if not MouseOverButtons.parent then return end
    local holdWeapon = true;
    NPCCard_OnClick(MouseOverButtons.parent, button, nil, holdWeapon);
end

local function Category_OnClick(self)
    local endHeight;
    self.isCollapsed = not self.isCollapsed;

    if self.isCollapsed then
        endHeight = 16;
        self.ExpandMark:SetTexCoord(0, 1, 0, 1);
        FadeFrame(self.Drawer, 0.15, 0);
    else
        endHeight = self.numChild * NPC_BUTTON_HEIGHT + 16;
        self.ExpandMark:SetTexCoord(0, 1, 1, 0);
        FadeFrame(self.Drawer, 0.2, 1);
    end

    CollapseTab(self.Drawer, endHeight);
    UpdateScrollRange(self:GetParent():GetParent(), true, 1);
end


function NPCCardAPI:SetNPC(button, id)
    button.mode = "npc";
    button:SetHeight(32);
    button.Highlight = button.HighlightNPC;

    local info = NPCInfo[id];
    button.creatureID = id;

    if info then
        button.isCategorized = true;
        button.voiceID = info[3];
        button.weapons = info[4];
        button.hasPortrait = true;

        if info[1][2] then
            button.Name:SetText(info[1][1]);
            button.Title:SetText(info[1][2]);
            button.Name:Show();
            button.Title:Show();
            button.NameCenter:Hide();
            button.hasTitle = true;
        else
            button.NameCenter:SetText(info[1][1]);
            button.NameCenter:Show();
            button.Name:Hide();
            button.Title:Hide();
            button.hasTitle = nil;
        end

        local color = CP[info[2]] or {"cccccc", 0.5, 0.5, 0.5};
        button.ColorBackground:SetColorTexture(color[2], color[3], color[4]);
        button.Title:SetTextColor(color[2], color[3], color[4]);
        button.ColorBackground:Show();
        button.creatureName = "|cff".. color[1] .. info[1][1] .."|r";   --for actor panel label

        QueueTexture(button.Portrait, button.HighlightNPC, "Interface/AddOns/Narcissus/Art/Widgets/NPCBrowser/Portraits/".. id);
    else
        button.hasPortrait = nil;
    end

    button.CategoryName:Hide();
    button.Count:Hide();
    button.ExpandMark:Hide();
    button.GreyBackground:Hide();
    button.HighlightFull:Hide();
    button.Portrait:Hide();
    button.HighlightNPC:Show();

    button:SetScript("OnClick", NPCCard_OnClick);
    button:Hide();

    --Favorites
    if FavUtil:IsFavorite(id) then
        button.isFav = true;
        button.Star:Show();
    else
        button.isFav = nil;
        button.Star:Hide();
    end
end

function NPCCardAPI:SetCategory(button, name, numChild)
    button.mode = "category";
    button.creatureID = nil;
    button:SetHeight(16);
    button.Highlight = button.HighlightFull;

    button.Name:Hide();
    button.Title:Hide();
    button.NameCenter:Hide();
    button.ColorBackground:Hide();
    button.Portrait:Hide();
    button.HighlightNPC:Hide();

    button.CategoryName:Show();
    button.Count:Show();
    button.ExpandMark:Show();
    button.GreyBackground:Show();
    button.HighlightFull:Show();
    button.Star:Hide();

    button.CategoryName:SetText(name);
    button.Count:SetText(numChild);
    button.numChild = numChild;
    
    button.isCollapsed = true;
    button.creatureName = nil;

    button:SetScript("OnClick", Category_OnClick);
    button:Show();

    --Reset collpase status
    button.isCollapsed = true;
    button.Drawer:SetHeight(16);
    button.Drawer:Hide();
    button.Drawer:SetAlpha(0);
    button.Drawer:SetFrameLevel(1);
    button.ExpandMark:SetTexCoord(0, 1, 0, 1);

    button.isFav = false;
end

local upper = string.upper;
local HighlightMatchedWord;

do
    local textLocale = GetLocale();
    if textLocale == "enUS" or textLocale == "ruRU" then
        function HighlightMatchedWord(name, keyword)
            if keyword then
                keyword = gsub(keyword, "^%l", upper);
                keyword = gsub(keyword, " %l", upper);
                return gsub(name, keyword, "|cffffffff"..keyword.."|r", 1);
            else
                return "|cffffffff"..name.."|r";
            end
        end
    else
        function HighlightMatchedWord(name, keyword)
            if keyword then
                return gsub(name, keyword, "|cffffffff"..keyword.."|r", 1);
            else
                return "|cffffffff"..name.."|r";
            end
        end
    end
end

function NPCCardAPI:SetMatchedNPC(button, id, name, title, keyword)
    if id ~= button.creatureID then
        button.mode = "npc";
        button.creatureID = id;

        if title then
            button.hasTitle = true;
            button.Name:Show();
            button.Title:Show();
            button.NameCenter:Hide();
            button.Name:SetTextColor(0.72, 0.72, 0.72);
            button.Title:SetText(title);
        else
            button.hasTitle = nil;
            button.Name:Hide();
            button.Title:Hide();
            button.NameCenter:Show();
            button.NameCenter:SetTextColor(0.72, 0.72, 0.72);
        end
    end

    button.creatureName = name;

    --Highlight matched words
    name = HighlightMatchedWord(name, keyword)
    if button.hasTitle then
        button.Name:SetText(name);
    else
        button.NameCenter:SetText(name);
    end

    button.Highlight:SetAlpha(0)

    --Favorites
    if FavUtil:IsFavorite(id) then
        button.isFav = true;
        button.Star:Show();
    else
        button.isFav = nil;
        button.Star:Hide();
    end
end

--[[
function NPCCardAPI:Render(state)
    self.Portrait:SetShown(state);
    self.HighlightNPC:SetShown(state);
    self.isRendered = state;
end
--]]

--------------------------------------------------------------------------------------------------
local function CreateSmoothScroll(scrollFrame, buttonHeight, numButtonPerpage, step, positionFunc)
    local totalHeight = floor(numButtonPerpage * buttonHeight + 0.5);
    local maxScroll = max(0, totalHeight - numButtonPerpage * buttonHeight);
    scrollFrame.scrollBar:SetMinMaxValues(0, maxScroll)
    scrollFrame.scrollBar:SetValueStep(0.001);
    scrollFrame.buttonHeight = totalHeight;
    scrollFrame.range = 0; --maxScroll
    scrollFrame.scrollBar:SetScript("OnValueChanged", function(self, value)
        self:GetParent():SetVerticalScroll(value);
        UpdateInnerShadowStates(self, nil, false);
    end)
    NarciAPI_SmoothScroll_Initialization(scrollFrame, nil, nil, step/(numButtonPerpage), 0.14, nil, positionFunc);
end

local function CreateButtonsForScrollFrame(frame, sum, template, onEnterFunc, onClickFunc)
    --print("Total Buttons: ".. sum)
    local buttons = {};
    local button;
    for i = 1, sum do
        button = CreateFrame("Button", nil, frame.ScrollChild, template);
        button.index = i;
        buttons[i] = button;
        if i == 1 then
            button:SetPoint("TOP", frame.ScrollChild, "TOP", 0, 0);
        else
            button:SetPoint("TOP", buttons[i - 1], "BOTTOM", 0, 0);
        end

        if onEnterFunc then
            button:SetScript("OnEnter", onEnterFunc);
        end

        if onClickFunc then
            button:SetScript("OnClick", onClickFunc);
        end
    end
    frame.buttons = buttons;
    frame.numActiveButton = 0;
end

local function CreateEntryButton(categoryID)
    local frame = EntryTab;
    local button, categoryButton;
    local buttons, categoryButtons = frame.buttons, {};
    local id;

    local subCategory = Catalogue[categoryID];
    if not subCategory then return end;

    local numActiveButton = 0;
    local numSubcategory = #subCategory;
    local numChild = 0;

    for i = 1, numSubcategory do
        categoryButton = buttons[numActiveButton + 1];
        categoryButton:SetParent(frame.ScrollChild);
        tinsert(categoryButtons, categoryButton);

        categoryButton:ClearAllPoints();
        if i == 1 then
            categoryButton:SetPoint("TOP", frame.ScrollChild, "TOP", 0, 0);
        else
            categoryButton:SetPoint("TOP", categoryButtons[i - 1].Drawer, "BOTTOM", 0, 0);
        end

        numChild = #subCategory[i];
        NPCCardAPI:SetCategory(categoryButton, subCategory[i]["name"], numChild);

        numActiveButton = numActiveButton + 1;

        for j = 1, numChild do
            button = buttons[numActiveButton + 1];
            if button then
                button:SetParent(categoryButton.Drawer);
                button:ClearAllPoints();
                
                if j == 1 then
                    button:SetPoint("BOTTOM", categoryButton.Drawer, "BOTTOM", 0, (numChild- 1 )*NPC_BUTTON_HEIGHT);
                else
                    button:SetPoint("TOP", buttons[numActiveButton], "BOTTOM", 0, 0);
                end
                id = subCategory[i][j];
                NPCCardAPI:SetNPC(button, id);
                numActiveButton = numActiveButton + 1;
            end
        end
    end

    for i = numActiveButton + 1, NUM_MAX_ENTRY_BUTTONS do
        buttons[i]:Hide();
    end

    frame.categoryButtons = categoryButtons;
    frame.numActiveButton = numActiveButton;
    frame.numSubcategory = numSubcategory;

    --Update Scroll Range then Go to 2nd Tab
    LoadTexture();
    After(0, function()
        UpdateScrollRange(frame, false, 1)
        After(0, function()
            GoToTab(2);
        end)
    end)
end

local function SetUpMatchButton(button, creatureData, keyword)
    if creatureData then
        button:Show();
        button.Highlight:SetAlpha(0);
        if creatureData[3] then
            --displayID
            local displayID = creatureData[3];
            button.creatureID = nil;
            button.displayID = displayID;
            button.Name:Show();
            button.Title:Show();
            button.NameCenter:Hide();
            button.Name:SetTextColor(1, 1, 1);
            button.Title:SetText("DisplayID");
            button.Name:SetText(displayID);
            button.isFav = nil;
            button.Star:Hide();
            button.creatureName = "|cffffd200DisplayID: "..displayID.."|r";
        else
            button.displayID = nil;
            local id = creatureData[2];
            local name, title;
            if id ~= button.creatureID then
                button.creatureID = id;
                name = creatureData[1];
                title = GetNPCTitle(id);
                if title then
                    button.hasTitle = true;
                    button.Name:Show();
                    button.Title:Show();
                    button.NameCenter:Hide();
                    button.Name:SetTextColor(0.72, 0.72, 0.72);
                    button.Title:SetText(title);
                else
                    button.hasTitle = nil;
                    button.Name:Hide();
                    button.Title:Hide();
                    button.NameCenter:Show();
                    button.NameCenter:SetTextColor(0.72, 0.72, 0.72);
                end
            else
                return
            end

            button.creatureName = "|cffffd200"..name.."|r";

            --Highlight matched words
            name = HighlightMatchedWord(name, keyword)
            if button.hasTitle then
                button.Name:SetText(name);
            else
                button.NameCenter:SetText(name);
            end

            --Favorites
            if FavUtil:IsFavorite(id) then
                button.isFav = true;
                button.Star:Show();
            else
                button.isFav = nil;
                button.Star:Hide();
            end
        end
    else
        button:Hide();
        button.creatureID = nil;
        button.displayID = nil;
    end
end

local function Match_OnEnter(self)
    FadeFrame(self.Highlight, 0.2, 1);

    if self.displayID then
        UpdatePreviewModel(self.displayID, true);
        MouseOverButtons:Hide();
    elseif self.creatureID then
        UpdatePreviewModel(self.creatureID);
        ShowMouseOverButtons(self);
    end
end

local function Match_OnLeave(self)
    if not self:IsMouseOver() then
        FadeFrame(self.Highlight, 0.2, 0);
    end
end


local ScrollMatch = {};
ScrollMatch.data = {};
ScrollMatch.indexOffset = -1;
ScrollMatch.buttons = {};
ScrollMatch.numButtons = 12; --6 visible, 6 for buffer

function ScrollMatch:HideButtons()
    for k, button in pairs(self.buttons) do
        button:Hide();
    end
    MatchPreviewModel:Hide();
    MouseOverButtons:Hide();
    MatchTab.Notes:Show();
end

function ScrollMatch:SetMatchData(data, keyword)
    self.data = data;
    self.keyword = keyword;
end

function ScrollMatch:UpdateScrollChild(offset, forced)
    local index = floor((offset + 2) / NPC_BUTTON_HEIGHT);
    if index == self.indexOffset and not forced then
        return
    end

    local anchorTo = MatchTab.ScrollChild;
    local button;

    if index > self.indexOffset then
        local topButton = tremove(self.buttons, 1);
        if topButton then
            tinsert(self.buttons, topButton);
        end
    else
        local bottomButton = tremove(self.buttons);
        if bottomButton then
            tinsert(self.buttons, 1, bottomButton);
        end
    end
    self.indexOffset = index;
    local dataIndex;
    for i = 1, self.numButtons do
        button = self.buttons[i];
        if not button then
            button = CreateFrame("Button", nil, anchorTo, "NarciNPCMatchButtonTemplate");
            button:SetScript("OnEnter", Match_OnEnter);
            button:SetScript("OnLeave", Match_OnLeave);
            button:SetScript("OnClick", NPCCard_OnClick);
            self.buttons[i] = button;
        end
        dataIndex = i + index;
        button:ClearAllPoints();
        button:SetPoint("TOP", anchorTo, "TOP", 0, NPC_BUTTON_HEIGHT * (1 - dataIndex));
        SetUpMatchButton(button, self.data[dataIndex], self.keyword);
    end
end

local function DisplaySearchResult(matchTable, keyword)
    ScrollMatch:SetMatchData(matchTable, keyword);
    local frame = MatchTab;
    local numMacthes = #matchTable;
    if numMacthes > 0 then
        frame.Notes:Hide();
        MouseOverButtons:Hide();
    else
        ScrollMatch:HideButtons();
        return
    end
    local numActiveButton = min(numMacthes, NUM_MAX_MATCHES);

    frame.numActiveButton = numActiveButton;

    After(0, function()
        UpdateScrollRange(frame, false, 0);
        ScrollMatch:UpdateScrollChild(0, true);
        frame.scrollBar:SetValue(0);
    end);
end

local function CreateFavoritesButton()
    --not a RAM friendly way but let it be for now
    local matchedIDs = {};
    local name;
    for npcID, isFav in pairs( FavUtil:GetFavoriteNPCs() ) do
        if isFav then
            name = GetNPCName(npcID) or "";
            tinsert(matchedIDs, {name, npcID});
        end
    end
    table.sort(matchedIDs, SortFunc);
    DisplaySearchResult(matchedIDs);
    local isFavoriteTab = true;
    GoToTab(3, isFavoriteTab);
end

NarciNPCBrowserCoverButtonMixin = {};

function NarciNPCBrowserCoverButtonMixin:OnClick()
    if self.categoryID ~= 0 then
        CreateEntryButton(self.categoryID);
        HeaderFrame.Tab2Label:SetText(self.Name:GetText());
    else
        CreateFavoritesButton();
    end
end

function NarciNPCBrowserCoverButtonMixin:OnMouseUp()
    self.Image:SetTexCoord(0.046875, 0.625, 0.06640625, 0.93359375);
end

function NarciNPCBrowserCoverButtonMixin:OnMouseDown()
    self.Image:SetTexCoord(0, 0.66796875, 0, 1);
end

function NarciNPCBrowserCoverButtonMixin:OnEnter()
    FadeFrame(self.Highlight, 0.12, 1);
    self.Name:SetAlpha(1);
end

function NarciNPCBrowserCoverButtonMixin:OnLeave()
    FadeFrame(self.Highlight, 0.2, 0);
    self.Name:SetAlpha(0.88);
end

function NarciNPCBrowserCoverButtonMixin:Init(categoryID)
    if (categoryID == self.categoryID) and (categoryID ~= 0) then
        return
    end
    self.categoryID = categoryID;

    if categoryID then
        if categoryID == 0 then
            self.Count:SetText( FavUtil:GetNumFavorites() );
            self.Name:SetText(L["My Favorites"]);
            self.Image:SetTexture("Interface/AddOns/Narcissus/Art/Widgets/NPCBrowser/Covers/MyFavorites");
        else
            local category = Catalogue[categoryID];
            if category then
                self.Count:SetText(category.numEntries);
                self.Name:SetText(category.name);
                self.Image:SetTexture("Interface/AddOns/Narcissus/Art/Widgets/NPCBrowser/Covers/".. (category.name) );
            else
                self:Hide();
                return
            end
        end
        self:Show();
    else
        self:Hide();
    end
end

local ScrollCategory = {};
ScrollCategory.indexOffset = -1;
ScrollCategory.buttons = {};
ScrollCategory.numButtons = 12; --6 visible, 6 for buffer

function ScrollCategory:UpdateData()
    self.data = {};

    local numCategory = Catalogue.numCategory;
    local index;
    if FavUtil:GetNumFavorites() > 0 then
        numCategory = numCategory + 1;
        index = 0;
    else
        index = 1;
    end
    local numCol = 3;
    local numRow = math.ceil(numCategory / numCol);
    for row = 1, numRow do
        self.data[row] = {};
        for col = 1, numCol do
            self.data[row][col] = index;
            index = index + 1;
            if index > numCategory then
                return
            end
        end
    end
end

function ScrollCategory:UpdateScrollChild(offset, forced)
    local index = floor((offset + 2) / COVER_BUTTON_HEIGHT) - 1;
    if index == self.indexOffset and not forced then
        return
    end

    local anchorTo = CategoryTab.ScrollChild;
    local row, col = index + 1, 1;
    local button;

    if index > self.indexOffset then
        local topButton;
        for i = 1, 3 do
            topButton = tremove(self.buttons, 1);
            if topButton then
                tinsert(self.buttons, topButton);
            else
                break;
            end
        end
    else
        local bottomButton;
        for i = 1, 3 do
            bottomButton = tremove(self.buttons);
            if bottomButton then
                tinsert(self.buttons, 1, bottomButton);
            else
                break;
            end
        end
    end
    self.indexOffset = index;

    for i = 1, self.numButtons do
        button = self.buttons[i];
        if not button then
            button = CreateFrame("Button", nil, anchorTo, "NarciNPCCoverTemplate");
            self.buttons[i] = button;
        end
        button:ClearAllPoints();
        button:SetPoint("TOPLEFT", anchorTo, "TOPLEFT", COVER_BUTTON_WIDTH * (col - 1), COVER_BUTTON_HEIGHT * (1 - row));
        if self.data[row] then
            button:Init( self.data[row][col] );
        else
            button:Init(nil);
        end
        col = col + 1;
        if col > 3 then
            col = 1;
            row = row + 1;
        end
    end
end

function ScrollCategory:Update()
    ScrollCategory:UpdateData();
    ScrollCategory:UpdateScrollChild(0, true);
end


local function QuickFavoriteButton_OnClick(self)
    if not self.parent then return end

    local isFav = not self.isFav;
    self.isFav = isFav;
    self.parent.isFav = isFav;
    local creatureID = MouseOverButtons.parent.creatureID;
    if isFav then
        FavUtil:Add(creatureID);
    else
        FavUtil:Remove(creatureID);
    end
    self:PlayVisual();

    ScrollCategory:Update();
end
--------------------------------------------------------------------------

local function NPCBrowser_OnLoad(self)
    CategoryTab = self.Container.CategoryTab;
    EntryTab = self.Container.EntryTab;
    MatchTab = self.Container.MatchTab;
    MatchPreviewModel = MatchTab.MatchPreview;
    MouseOverButtons = self.Container.MouseOverButtons;
    QuickFavoriteButton = MouseOverButtons.QuickFavoriteButton;
    HeaderFrame = self.Container.Header;
    HomeButton = HeaderFrame.HomeButton;
    SearchBox = HeaderFrame.SearchBox;
    SearchTrigger = HeaderFrame.SearchTrigger;
    LoadingIndicator = self.Container.LoadingIndicator;

    NarciClassicAPI.SetModelLight(MatchPreviewModel, true, false, - 0.44699833180028 ,  0.72403680806459 , -0.52532198881773, 0.8, 172/255, 172/255, 172/255, 1, 0.8, 0.8, 0.8);
    CreateSmoothScroll(EntryTab, NPC_BUTTON_HEIGHT, NUM_BUTTONS_PER_PAGE, 2, UpdateRenderAreaEntry);

    ScrollCategory:Update();
    CreateSmoothScroll(CategoryTab, COVER_BUTTON_HEIGHT, NUM_COVER_ROW_PER_PAGE, 1);
    CategoryTab.scrollBar:SetScript("OnValueChanged", function(bar, value)
        CategoryTab:SetVerticalScroll(value);
        ScrollCategory:UpdateScrollChild(value);
    end);

    CreateSmoothScroll(MatchTab, NPC_BUTTON_HEIGHT, NUM_BUTTONS_PER_PAGE, 2);
    MatchTab.scrollBar:SetScript("OnValueChanged", function(bar, value)
        MatchTab:SetVerticalScroll(value);
        ScrollMatch:UpdateScrollChild(value);
    end);

    local numCover = Catalogue.numCategory;
    local numRow = floor( (numCover + 2) /3 );
    local maxScroll = max(0, (numRow - NUM_COVER_ROW_PER_PAGE) * COVER_BUTTON_HEIGHT);
    CategoryTab.range = maxScroll;
    CategoryTab.scrollBar:SetMinMaxValues(0, maxScroll);

    HomeButton:SetScript("OnClick", function(self)
        GoToTab(1);
        FadeFrame(self, 0.2, 0);
    end)
    
    SearchTrigger:Show();
    HeaderFrame.Tab1Label:SetTextColor(0.72, 0.72, 0.72);
    SearchTrigger:SetScript("OnClick", function(self)
        self:Hide();
        SearchBox:Show();
        GoToTab(3);

        if not self.isDatabaseLoaded then
            local addOnName = "Narcissus_Database_NPC";
            if IsAddOnLoaded(addOnName) then
                self.isDatabaseLoaded = true;
            else
                local timeStart = 0;

                self:RegisterEvent("ADDON_LOADED");
                self:SetScript("OnEvent", function(self, event, ...)
                    if event == "ADDON_LOADED" then
                        local name = ...
                        if name == addOnName then
                            self.isDatabaseLoaded = true;
                            self:UnregisterAllEvents();
                            After(0.5, function()
                                FadeFrame(LoadingIndicator, 0.5, 0);
                            end)
                        end
                    end
                end)

                if GetAddOnEnableState( UnitName("player"), addOnName ) == 0 then
                    EnableAddOn(addOnName);
                end

                LoadingIndicator.Notes:SetText(L["Loading Database"]);
                LoadingIndicator:Show();

                After(0.2, function()
                    local loaded, reason = LoadAddOn(addOnName);
                    if not loaded then
                        PlaySound(138528);
                        if reason == "DISABLED" then
                            LoadingIndicator.Notes:SetText("Please enable Narcissus Database on the addon list.")
                        else
                            LoadingIndicator.Notes:SetText( _G["ADDON_"..reason] );
                        end
                        self:UnregisterEvent("ADDON_LOADED");
                        self.isDatabaseLoaded = true;
                        LoadingIndicator.Notes:SetTextColor(1, 0.3137, 0.3137);
                        LoadingIndicator.LoadingIcon:Hide();
                        After(3, function()
                            FadeFrame(LoadingIndicator, 1, 0);
                        end)
                    end
                end)
            end
        end
    end)

    QuickFavoriteButton:SetScript("OnClick", QuickFavoriteButton_OnClick);
    MouseOverButtons.WeaponMark:SetScript("OnClick", AddModelAndEquipItems);

    --localization
    MatchTab.Notes:SetText(CLUB_FINDER_APPLICANT_LIST_NO_MATCHING_SPECS);   --No matches
    HeaderFrame.Tab3Label:SetText(L["My Favorites"]);

    function Narci_GetNumRendered()
        local sum = 0;
        local buttons = EntryTab.buttons;
        local button;
        for i = 1, #buttons do
            --if NPCCardAPI:IsRendered(buttons[i]) then
            button = buttons[i];
            if button:IsVisible() and button.mode == "npc" then
                sum = sum + 1;
            end
        end
        print(sum.." visible buttons")
    end
end



------------------------------------------------------
--Search Box

local SearchDelay = NarciAPI_CreateAnimationFrame(0.5);

local function StartSearching()
    if not SearchDelay.LoadingIcon then
        SearchDelay.LoadingIcon = MatchTab.LoadingIcon;
        SearchDelay.LoadingIcon.Rotate:Play();
    end
    MatchTab.Notes:Hide();
    SearchDelay:Show();
end

local function SetCreaturePreview(id)
    local model = MatchPreviewModel;
    if id then
        model:SetAlpha(0);
        model:SetCreature(id);
        model.id = id;
        FadeFrame(model, 0.25, 1);
        MatchTab.Notes:Hide();
    else
        FadeFrame(model, 0.12, 0);
        MatchTab.Notes:Show();
    end
end

local function SearchByID(id)
    if IsKeyDown("BACKSPACE") then return end

    local Tooltip = MatchTab.NPCTooltip;
    ScrollMatch:HideButtons();

    Tooltip:SetOwner(UIParent, "ANCHOR_NONE");
    Tooltip:SetHyperlink(format("unit:Creature-0-0-0-0-%d", id));


    local result;

    local name = Tooltip.lineName:GetText();
    if name and name ~= "" then
        SetCreaturePreview(id);
        result = {
            {name, id},             --npcID
        };
        DisplaySearchResult(result, nil);
    end

    if DoesCreatureDisplayIDExist(id) then
        if result then
            tinsert(result, {"DisplayID", 0, id});
        else
            result = {
                {"DisplayID", 0, id},
            };
        end
    end

    if result then
        DisplaySearchResult(result, nil);
    else
        SetCreaturePreview(nil);
    end
end

local function SearchByName(str)
    if not str or str == "" or IsKeyDown("BACKSPACE") then return end
    if not NarciCreatureInfo then
        --Database Not Loaded
        MatchTab.Notes:SetText("Database Disabled");
        MatchTab.Notes:Show();
        return
    end

    str = gsub(str, "[%c, %-]", "%%%1");
    local keyword = gsub(str, "[%.]", "%%%1");
    local matchedIDs, numMacthes = NarciCreatureInfo.SearchNPCByName(str);

    if numMacthes > 0 then
        for i = 1, numMacthes do
            GetNPCTitle(matchedIDs[i][2])
        end
    end

    After(0.25, function()
        if numMacthes > 0 then
            table.sort(matchedIDs, SortFunc);
        end
        DisplaySearchResult(matchedIDs, keyword);
    end);
end

SearchDelay:SetScript("OnUpdate", function(self, elapsed)
	self.total = self.total + elapsed;
    if self.total >= self.duration then
        self:Hide();
        if self.type == "ID" then
            SearchByID(self.creatureID);
        else
            SearchByName(self.text);
        end
    end
end)

SearchDelay:SetScript("OnHide", function(self)
    self.total = 0;
    self.LoadingIcon:Hide();
end);

SearchDelay:SetScript("OnShow", function(self)
    self.LoadingIcon:Show();
end);


local SearchBoxOnKeydownFunc = function(self, key)
    if key == "DELETE" then
        self.onDeletePressedFunc(self, key);
    elseif self.hasNumber then
        if key == "DOWN" then
            self:SetText(self:GetNumber() + 1);
        elseif key == "UP" then
            self:SetText( max(self:GetNumber() - 1, 1) );
        end
    end
end

NarciNPCSearchBoxMixin = CreateFromMixins(NarciSearchBoxSharedMixin);

function NarciNPCSearchBoxMixin:OnLoad()
    self.delayedSearch = SearchDelay;
    self.onKeyDownFunc = SearchBoxOnKeydownFunc;
    self.DefaultText:SetText(L["Name or ID"]);

    local Tab = Narci_NPCBrowser_MatchTab;
    local TP = CreateFrame("GameTooltip", NPCTooltipName, Tab, "GameTooltipTemplate");
    TP.lineName = _G[NPCTooltipName.."TextLeft1"];
    Tab.NPCTooltip = TP;
    if TP.NiceSlice then
        TP.NiceSlice:Hide();
    elseif TP.SetBackdrop then
        TP:SetBackdrop(nil);
    end

    ---Font
    TP.TextLeft1 = _G[NPCTooltipName.."TextLeft1"];
    TP.TextLeft2 = _G[NPCTooltipName.."TextLeft2"];
end

function NarciNPCSearchBoxMixin:OnMouseWheel(delta)
    if self.hasNumber then
        if delta < 0 then
            self:SetText(self:GetNumber() + 1);
        else
            self:SetText( max(self:GetNumber() - 1, 1) );
        end
    end
end

function NarciNPCSearchBoxMixin:OnTextChanged(isUserInput)
    SearchDelay.total = 0;
    local str = self:GetNumber();

    if str ~= 0 then
        MatchTab.scrollBar:SetValue(0);
        
        self.hasNumber = true;
        self.DefaultText:Hide();
        self.EraseButton:Show();

        SearchDelay.type = "ID";
        SearchDelay.requireUpdate = nil;

        --Input NPC ID
        SearchDelay.text = "";
        local id = str;
        if id <= 999999 then
            SearchDelay.creatureID = id;
            RequestCreatureInfo(id);
            DoesCreatureDisplayIDExist(id);     --Query
            StartSearching();
        end
    else
        self.hasNumber = false;

        --NPC's name
        str = self:GetText();
        SearchDelay.type = "name";
        SearchDelay.text = str;

        if not str or str == "" then
            self.DefaultText:Show();
            self.EraseButton:Hide();
            MatchTab.Notes:Hide();
        else
            self.DefaultText:Hide();
            self.EraseButton:Show();
            if isUserInput then
                StartSearching();
            end
        end

        MatchTab.NPCTooltip:Hide();
    end
end

function NarciNPCSearchBoxMixin:OnFocusGained()
    self:OnEditFocusGained();
    if self:GetNumber() ~= 0 then
        self.hasNumber = true;
    else
        self.hasNumber = nil;
    end
end

------------------------------------------------------
local function BuildNPCList()
    CreateButtonsForScrollFrame(BrowserFrame.Container.EntryTab, NUM_MAX_ENTRY_BUTTONS, "NarciNPCButtonWithPortaitTemplate", NPCCard_OnEnter);

    local npcIDList = GetIncludedNPCList();
    RequestAllCreatureInfo(npcIDList);

    local Loader = CreateFrame("Frame");
    local numTotal = #npcIDList;
    local numLeft = numTotal;

    local id, shouldQueue;
    local idQueued = {};
    local pausedTime = 0;
    local paused;

    local function Loader_OnUpdate(f, elapsed)
        if paused then
            pausedTime = pausedTime + elapsed;
            if pausedTime > 0.2 then
                paused = false;
            else
                return
            end
        end
        id = npcIDList[numLeft];
        NPCInfo[id][1], shouldQueue = GetNPCNameAndTitle(id);
        if shouldQueue then
            if idQueued[id] then
                numLeft = numLeft - 1;
                --[[
                    --Debug
                if not NarciDevOutput then
                    NarciDevOutput = {};
                end
                tinsert(NarciDevOutput, id);
                print("NPC: "..id.." doesn't exist");
                --]]
            else
                idQueued[id] = true;
                paused = true;
                pausedTime = 0;
            end
        else
            numLeft = numLeft - 1;
        end

        if numLeft % 2 == 0 then
            LoadingIndicator.Progress:SetText( (numTotal - numLeft) .."/"..numTotal);
        end

        if numLeft == 0 then
            --Loading Complete
            f:SetScript("OnUpdate", nil);
            f:Hide();
            NPCBrowser_OnLoad(BrowserFrame);
            LoadTexture();
            LoadingIndicator.Progress:SetText("");
            LoadingIndicator:Hide();
        end
    end
    
    After(1.5, function()
        Loader:SetScript("OnUpdate", Loader_OnUpdate);
    end);

    FavUtil:Load();
end


NarciNPCBrowserMixin = {};

function NarciNPCBrowserMixin:OnLoad()
    BrowserFrame = self;
    self:Minimize();

    self:SetScript("OnLoad", nil);
    self.OnLoad = nil;
end

function NarciNPCBrowserMixin:OnEnter()
end

function NarciNPCBrowserMixin:OnHide()
    self:Hide();
    self:Minimize();
    TARGET_MODEL_INDEX = nil;
    ACTOR_CREATED = nil;
end

function NarciNPCBrowserMixin:Minimize()
    self:SetSize(BROWSER_SHRINK_WIDTH, BROWSER_SHRINK_HEIGHT);
end

function NarciNPCBrowserMixin:Init()
    if not self.isLoaded then
        self.isLoaded = true;
        LoadingIndicator = self.Container.LoadingIndicator;
        LoadingIndicator:Show();
        BuildNPCList();
        BuildNPCList = nil;
        self.Container.Header.SearchTrigger:Hide();
    end
end

function NarciNPCBrowserMixin:Open(anchorButton)
    FadeFrame(Narci_ActorPanelPopUp, 0.15, 0);
    self:ClearAllPoints();
    self:SetPoint("TOP", anchorButton, "TOP", 0, -5);
    PlayToggleAnimation(true);
    Narci_ModelSettings:SetPanelAlpha(0.5, true);
    local PopUp = anchorButton:GetParent();
    local index = PopUp.Index;
    NarciPhotoModeAPI.CreateEmptyModelForNPCBrowser(index);     --Defined in PlayerModel.lua
    TARGET_MODEL_INDEX = index;
    self:Init();
end

function NarciNPCBrowserMixin:Close()
    PlayToggleAnimation(false);
    Narci_ModelSettings:SetPanelAlpha(1, true);
    if not ACTOR_CREATED then
        NarciPhotoModeAPI.RemoveActor(TARGET_MODEL_INDEX)
    end
    ACTOR_CREATED = false;
end

function NarciNPCBrowserMixin:IsFocused()
    return self:IsShown() and self:IsMouseOver()
end




---------------------------------------------
--Utility
--[[
function Narci:SetModelByDisplayID(index, displayID)
    if not index or not displayID then
        print("Format: (index, displayID)");
        return;
    end

    local model = _G["NarciNPCModelFrame"..index] or _G["NarciPlayerModelFrame"..index];
    if model then
        model:SetDisplayInfo(displayID);
    else
        print("Can't find model frame #"..displayID)
    end
end


local ENABLE_UTILITY = true;

if not ENABLE_UTILITY then
    return
end


local NUM_WIDGETS = 10;
local NUM_NPC_ID_MAX = 10;
local TOOLTIP_NAME_PREFIX = "CreatureNameRetriever";

local OutputFrame, OutputEditBox;

local function UpdateEditBoxScrollRange()
    local maxScroll = OutputEditBox.numLines * 9;
    OutputFrame.ScrollFrame.range = maxScroll
    OutputFrame.ScrollFrame.scrollBar:SetMinMaxValues(0, maxScroll);
end

local function ResetOutputEditBox()
    OutputEditBox:SetText("");
    OutputEditBox.numLines = 0;
end

local function OutPutText(str)
    OutputEditBox.numLines = OutputEditBox.numLines + 1;
    --OutputEditBox:SetText(OutputEditBox:GetText().."\n"..str)
    OutputEditBox:Insert(str.."\n");
    UpdateEditBoxScrollRange()
end

local AllNPCID = {
    162208,
    150101,
    149684,
    145580,
    54445,
    37597,
    64560,
    37221,
    147886,
    69741,
};
local NameTemp = {};

local WidgetContainer = {};

local function CreateVirtualTooltip(index)
    local name = TOOLTIP_NAME_PREFIX..index;
    local VirtualTooltip = CreateFrame("GameTooltip", name, UIParent, "GameTooltipTemplate");
    VirtualTooltip.lineName = _G[name.. "TextLeft1"];

    local function GetName(creatureID)
        VirtualTooltip:SetOwner(UIParent, "ANCHOR_NONE");
        VirtualTooltip:SetHyperlink(format("unit:Creature-0-0-0-0-%d", creatureID));
        return VirtualTooltip.lineName:GetText() or ""
    end
    
    VirtualTooltip.GetName = GetName;

    return VirtualTooltip
end

function GetExistNPC(_endIndex)
    ResetOutputEditBox();

    local IDs = {};
    local _start, _end = (_endIndex - 1)*1000 + 1, _endIndex*1000;
    local numLeft = _end - _start + 1;

    for i = 1, numLeft do
        IDs[i] = _start + i - 1;
    end

    local name, id;
    local numExist = 0;
    local output = {
        --[creatureID] = name;
    };

    local find = string.find;

    local function Recursion()
        for i = 1, NUM_WIDGETS do
            id = IDs[numLeft];
            name = WidgetContainer[i].Tooltip.GetName(id);
            if name and name~= "" then
                --if not find(name, "PH") then
                    tinsert(output, {id, name});
                    numExist = numExist + 1;
                --end
            end
            numLeft = numLeft - 1;
            if numLeft == 0 then
                break
            end
        end

        if numLeft > 0 then
            After(0.01, Recursion);
        else
            print("Done");
            print(_start.." to ".._end.." : "..numExist)
            table.sort(output, SortFunc);
            for _, v in pairs(output) do
                OutPutText("|cffffffff".. v[1] .."|r|cffa6a6a6,  --".. v[2].."|r")
            end
        end
    end

    Recursion()
end


local function CreateVirtualModel(index)
    local VirtualModel = CreateFrame("CinematicModel");
    VirtualModel:SetScript("OnModelLoaded", function(self)
        if not self.pauseUpdate then
            self.pauseUpdate = true;
            local creatureID = self.creatureID;
            local fileID = self:GetModelFileID();
            if fileID and fileID ~= 124642 and fileID ~= 124640 then
                local name = self.Tooltip.GetName(creatureID);
                if name and name ~= "" then
                    if not NameTemp[name] then
                        NameTemp[name] = {};
                    end
                    if not NameTemp[name][fileID] then
                        NameTemp[name][fileID] = true;
                        OutPutText("|cffffffff".. (creatureID or "|cffed1c24Error") .."|r  |cffcccccc"..fileID.."|r  |cffa6a6a6"..name)
                    else
                        OutPutText("|cffffffff".. (creatureID or "|cffed1c24Error") .."|r  |cffcccccc"..fileID.."|r  |cffa6a6a6"..name.." |cffffd200Duplicated")
                    end
                end
            end
            After(0, function()
                self.pauseUpdate = nil;
            end)
        end
    end)

    VirtualModel.Tooltip = CreateVirtualTooltip(index)
    return VirtualModel
end


for i = 1, NUM_WIDGETS do
    WidgetContainer[i] = CreateVirtualModel(i);
end

function FormatAndSave()
    local raw = OutputEditBox:GetText();
    local text = {};
    local func = string.gmatch(raw, "[^\n]+[\n]");
    local match = string.match;
    local trim = string.trim;


    local outputTable = NarciDevToolOutput;
    for line in func do
        line = trim(line);
        local id, name = match(line, "(%d+)%s+([%a%d]+)");
        id = tonumber(id);
        outputTable[id] = name;
    end
end

--Loading
local Utility = CreateFrame("Frame");
Utility:RegisterEvent("PLAYER_ENTERING_WORLD");
Utility:SetScript("OnEvent", function(self, event)
    NarciDevToolOutput = NarciDevToolOutput or {};

    self:UnregisterEvent(event);
    OutputFrame = CreateFrame("Frame", "Narci_OutPutFrame", nil, "Narci_OutPutFrameTemplate");
    OutputFrame:Show();
    OutputEditBox = OutputFrame.ScrollFrame.EditBox;
    local editBoxHeight = OutputEditBox:GetHeight();
    --CreateSmoothScroll(OutputFrame.ScrollFrame, editBoxHeight, 1, 0.5);
    OutputFrame.ScrollFrame.scrollBar:SetScript("OnValueChanged", function(self, value)
        self:GetParent():SetVerticalScroll(value);
    end)
    if event == "PLAYER_ENTERING_WORLD" then
        After(1, function()
            RequestAllCreatureInfo(AllNPCID);
        end)
    end
end)
--]]
