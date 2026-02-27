HonorSpy = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceEvent-2.0", "AceModuleCore-2.0", "FuBarPlugin-2.0", "AceComm-2.0", "AceHook-2.1")
local T = AceLibrary("Tablet-2.0")
local L = AceLibrary("AceLocale-2.2"):new("HonorSpy")

HonorSpy:RegisterDB("HonorSpyDB")
HonorSpy:RegisterDefaults('realm', {
	hs = {
		currentStandings = {},
		last_reset = 0,
		sort = L["ThisWeekHonor"],
		limit = 750
	}
})

-- put this near the top of honorspy.lua
local function sanitize_player_for_comm(p)
  if type(p) ~= "table" then return nil end
  local out = {}
  -- copy only primitives we expect to share
  out.last_checked   = tonumber(p.last_checked) or 0
  out.thisWeekHonor  = tonumber(p.thisWeekHonor) or 0
  out.lastWeekHonor  = tonumber(p.lastWeekHonor) or 0
  out.standing       = tonumber(p.standing) or 0
  out.rank           = tonumber(p.rank) or 0
  out.rankProgress   = tonumber(p.rankProgress) or 0
  out.RP             = tonumber(p.RP) or 0
  out.class          = type(p.class) == "string" and p.class or nil
  out.race           = type(p.race)  == "string" and p.race  or nil  -- REQUIRED for faction filtering
  return out
end

local commPrefix = "HonorSpy";
HonorSpy:SetCommPrefix(commPrefix)

local VERSION = 3;
local paused = false; -- pause all inspections when user opens inspect frame
local playerName = UnitName("player");
local horde = { Orc=true, Tauren=true, Troll=true, Undead=true, Scourge=true, Goblin=true } --horde if more races are added in the future, just add them here 
local alliance = { Dwarf=true, Gnome=true, Human=true, ["Night Elf"]=true, ["High Elf"]=true, NightElf=true, BloodElf=true, HighElf=true } --aliance if more races are added in the future, just add them here
local eFaction = {}
local myFaction = nil

local RealmPlayersAddon = false;
if (type(VF_InspectDone) ~= "nil" and type(VF_StartInspectingTarget) ~= "nil") then
	RealmPlayersAddon = true;
end

function HonorSpy:OnEnable()
	self:Hook("InspectUnit");
	self:RegisterComm(commPrefix, "GROUP", "OnCommReceive")
	self:RegisterComm(commPrefix, "GUILD", "OnCommReceive")
	-- self:RegisterComm(commPrefix, "CUSTOM", "HS", "OnCommReceiveCustom")
	self:RegisterEvent("PLAYER_DEAD");
	self:RegisterEvent("PLAYER_TARGET_CHANGED");
	self:RegisterEvent("UPDATE_MOUSEOVER_UNIT");
	self:RegisterEvent("INSPECT_HONOR_UPDATE");
	self.OnMenuRequest = BuildMenu();
	checkNeedReset();
	if alliance[UnitRace("player")] == true
	then
		eFaction = horde;
		myFaction = "Alliance";
	else
		eFaction = alliance;
		myFaction = "Horde";
	end

end

local inspectedPlayers = {}; -- stores last_checked time of all players met
local inspectedPlayerName = nil; -- name of currently inspected player

local function StartInspecting(unitID)
	local name = UnitName(unitID);

	if (name ~= inspectedPlayerName) then -- changed target, clear currently inspected player
		ClearInspectPlayer();
		inspectedPlayerName = nil;
	end
	if (name == nil
		or name == inspectedPlayerName
		or not UnitIsPlayer(unitID)
		--or not UnitIsFriend("player", unitID)  -- all grouped players are Alliance on turtle so this will record enemy players data
		or eFaction[UnitRace(unitID)] -- check if players race is of other faciton
		or not CheckInteractDistance(unitID, 1)
		or not CanInspect(unitID)) then
		return
	end
	
	local player = HonorSpy.db.realm.hs.currentStandings[name] or inspectedPlayers[name]; --need to check for faction
	if (player == nil) then
		inspectedPlayers[name] = {last_checked = 0};
		player = inspectedPlayers[name];
	end
	if (time() - player.last_checked < 30) then -- 30 seconds until new inspection request
		return
	end
	-- we gonna inspect new player, clear old one
	ClearInspectPlayer();
	inspectedPlayerName = name;
	player.unitID = unitID;
	NotifyInspect(unitID);
	RequestInspectHonorData();
	_, player.rank = GetPVPRankInfo(UnitPVPRank(player.unitID)); -- rank must be get asap while mouse is still over a unit
	_, player.class = UnitClass(player.unitID); -- same
	_, player.race = UnitRace(player.unitID); -- same
end

function HonorSpy:INSPECT_HONOR_UPDATE()
	if (inspectedPlayerName == nil or paused) then
		return;
	end

	local player = self.db.realm.hs.currentStandings[inspectedPlayerName] or inspectedPlayers[inspectedPlayerName];
	if (player.class == nil) then player.class = "nil" end

	-- ADD THIS CHECK: Don't save enemy faction players
	if player.race and eFaction[player.race] then
		ClearInspectPlayer();
		inspectedPlayerName = nil;
		return;
	end

	local _, _, _, _, thisweekHK, thisWeekHonor, _, lastWeekHonor, standing = GetInspectHonorData();
	player.thisWeekHonor = thisWeekHonor;
	player.lastWeekHonor = lastWeekHonor;
	player.standing = standing;

	player.rankProgress = GetInspectPVPRankProgress();
	ClearInspectPlayer();
	NotifyInspect("target"); -- change real target back to player's target, broken by prev NotifyInspect call
	ClearInspectPlayer();
	if (RealmPlayersAddon) then
		VF_TemporarySupressTargetChange = nil;
		VF_PlayerChosenTarget = true;
		VF_StartInspectingTarget();
	end
	player.last_checked = time();
	player.RP = 0;

	if (thisweekHK >= 1) then -- turtle only requried one HK compared to 15 on blizzlike
		if (player.rank >= 3) then
			player.RP = math.ceil((player.rank-2) * 5000 + player.rankProgress * 5000)
		elseif (player.rank == 2) then
			player.RP = math.ceil(player.rankProgress * 3000 + 2000)
		end
		self.db.realm.hs.currentStandings[inspectedPlayerName] = player;
		-- INSPECT_HONOR_UPDATE send site
		local to_send = sanitize_player_for_comm(player)
		if to_send then
			self:SendCommMessage("GROUP", inspectedPlayerName, to_send)
			self:SendCommMessage("GUILD", inspectedPlayerName, to_send)
		end

		-- self:SendCommMessage("CUSTOM", "HS", inspectedPlayerName, player);
	end
	inspectedPlayers[inspectedPlayerName] = {last_checked = player.last_checked};
	inspectedPlayerName = nil;
end

-- RESET WEEK
function resetWeek(must_reset_on)
	HonorSpy.db.realm.hs.last_reset = must_reset_on;
	inspectedPlayers = {};
	HonorSpy.db.realm.hs.currentStandings={};
	HonorSpyStandings:Refresh();
	HonorSpy:Print(L["Weekly data was reset"]);
end
function checkNeedReset()
	if (HonorSpy.db.realm.hs.reset_day == nil) then HonorSpy.db.realm.hs.reset_day = 3 end
	local day = date("!%w");
	local h = date("!%H");
	local m = date("!%M");
	local s = date("!%S");
	local days_diff = (7 + (day - HonorSpy.db.realm.hs.reset_day)) - math.floor((7 + (day - HonorSpy.db.realm.hs.reset_day))/7) * 7;
	local diff_in_seconds = s + m*60 + h*60*60 + days_diff*24*60*60 - 1; -- resets at midnight on turtle
	if (diff_in_seconds > 0) then -- it is negative on reset_day untill midnight
		local must_reset_on = time()-diff_in_seconds;
		if (must_reset_on > HonorSpy.db.realm.hs.last_reset) then resetWeek(must_reset_on) end
	end
end

-- PURGE
function purgeData()
	StaticPopup_Show("PURGE_DATA")
end
StaticPopupDialogs["PURGE_DATA"] = {
	text = L["This will purge ALL addon data, you sure?"],
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		inspectedPlayers = {};
		HonorSpy.db.realm.hs.currentStandings={};
		HonorSpyStandings:Refresh();
		HonorSpy:Print(L["All data was purged"]);
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

-- INSPECTION TRIGGERS
function HonorSpy:UPDATE_MOUSEOVER_UNIT()
	if (not paused) then StartInspecting("mouseover") end
end
function HonorSpy:PLAYER_TARGET_CHANGED()
	if (not paused) then
		if (RealmPlayersAddon) then
			VF_TemporarySupressTargetChange = true;
			VF_InspectDone();
		end
		StartInspecting("target");
	end
end

-- GUI
function HonorSpy:OnClick()
	checkNeedReset();
	if HonorSpyOverlay_Toggle then
		HonorSpyOverlay_Toggle()
	end
end
function HonorSpy:OnTooltipUpdate()
  T:SetHint("by Kakysha, v"..tostring(VERSION)..", Faction:"..tostring(myFaction))
end

-- PAUSING to not mess with native inspect calls
local hooked = false;
function HonorSpy:InspectUnit(unitID)
	paused = true;
	self.hooks["InspectUnit"](unitID)
	if (not hooked) then
		self:HookScript(SuperInspectFrame or InspectFrame, "OnHide");
		hooked = true;
	end
end
function HonorSpy:OnHide()
	paused = false;
end

-- CHAT COMMANDS
local options = { 
	type='group',
	args = {
		show = {
			type = 'execute',
			name = L['Show HonorSpy Standings'],
			desc = L['Show HonorSpy Standings'],
			func = function() HonorSpyStandings:Toggle() end
		},
		estimate = {
			type = 'execute',
			name = 'Honor Estimator',
			desc = 'Open the Honor Estimator panel',
			func = function() HonorSpyEstimator_Toggle() end
		},
		search = {
			type = 'text',
			name = L['Report specific player standings'],
			desc = L['Report specific player standings'],
			usage = L['player_name'],
			get = false,
			set = function(playerName) HonorSpy:Report(playerName) end
		},
	}
}
HonorSpy:RegisterChatCommand({"/honorspy", "/hs"}, options)

-- REPORT
function HonorSpy:Report(playerOfInterest)
	if (not playerOfInterest) then
		playerOfInterest = playerName
	end
	playerOfInterest = string.upper(string.sub(playerOfInterest, 1, 1))..string.lower(string.sub(playerOfInterest, 2))

	local standing = -1;
	local t = HonorSpyStandings:BuildStandingsTable()
	local pool_size = table.getn(t);

	for i = 1, pool_size do
		if (playerOfInterest == t[i][1]) then
			standing = i
		end
	end
	if (standing == -1) then
		self:Print(string.format(L["Player %s not found in table"], playerOfInterest));
		return
	end;

	-- Bracket boundaries (matches vmangos BRK[])
	local brk_pct = {[0]=1, [1]=0.845, [2]=0.697, [3]=0.566, [4]=0.436, [5]=0.327, [6]=0.228, [7]=0.159, [8]=0.100, [9]=0.060, [10]=0.035, [11]=0.020, [12]=0.008, [13]=0.003}
	local BRK = {}
	for k = 0, 13 do
		BRK[k] = math.floor(brk_pct[k] * pool_size + 0.5)
	end

	-- RP award curve (FY): fixed RP values at each bracket boundary
	local FY = {[0] = 0, [1] = 400}
	for k = 2, 13 do FY[k] = (k - 1) * 1000 end
	FY[14] = 13000

	local RankThresholds = {0, 2000}
	for k = 3, 14 do RankThresholds[k] = (k - 2) * 5000 end

	-- Helper: get CP of player at standing position (1-based)
	local function getCP(pos)
		if pos >= 1 and pos <= pool_size and t[pos] then
			return t[pos][3] or 0
		end
		return 0
	end

	-- Build FX array: honor (CP) values at each bracket boundary (matches vmangos)
	local FX = {[0] = 0}
	local top = false
	for i = 1, 13 do
		local honor = 0
		local tempHonor = getCP(BRK[i])
		if tempHonor > 0 then
			honor = tempHonor
			tempHonor = getCP(BRK[i] + 1)
			if tempHonor > 0 then
				honor = honor + tempHonor
			end
		end
		if honor > 0 then
			FX[i] = honor / 2
		else
			FX[i] = 0
			if not top then
				FX[i] = (FX[i - 1] > 0) and getCP(1) or 0
				top = true
			end
		end
	end
	FX[14] = (not top) and getCP(1) or 0

	-- Honor-based RP interpolation (matches vmangos CalculateRpEarning)
	local function CalcRpEarning(cp)
		local i = 0
		while i < 14 and BRK[i] and BRK[i] > 0 and FX[i] <= cp do
			i = i + 1
		end
		if i > 0 and FX[i] and FX[i] > cp and FX[i - 1] ~= nil and cp >= FX[i - 1] then
			local denom = FX[i] - FX[i - 1]
			if denom > 0 then
				return (FY[i] - FY[i - 1]) * (cp - FX[i - 1]) / denom + FY[i - 1]
			end
		end
		return FY[i] or 0
	end

	-- Server-accurate decay (matches vmangos CalculateRpDecay)
	local function CalcRpDecay(rpEarning, oldRp)
		local decay = math.floor(0.2 * oldRp + 0.5)
		local delta = rpEarning - decay
		if delta < 0 then delta = delta / 2 end
		if delta < -2500 then delta = -2500 end
		return oldRp + delta
	end

	-- Determine bracket for display
	local my_bracket = 1
	local brk_abs = {}
	for k = 1, 14 do brk_abs[k] = BRK[k - 1] end
	for b = 2, 14 do
		if (standing > brk_abs[b]) then break end
		my_bracket = b
	end

	local thisWeekHonor = t[standing][3] or 0
	local award = CalcRpEarning(thisWeekHonor)
	local RP = HonorSpy.db.realm.hs.currentStandings[playerOfInterest].RP;
	local Rank = HonorSpy.db.realm.hs.currentStandings[playerOfInterest].rank;
	local EstRP = math.floor(CalcRpDecay(award, RP) + 0.5)
	if EstRP < 0 then EstRP = 0 end
	-- Turtle WoW: no de-ranking — clamp to current rank's minimum RP
	local minRP = 0
	if Rank >= 3 then minRP = (Rank - 2) * 5000
	elseif Rank == 2 then minRP = 2000 end
	if EstRP < minRP then EstRP = minRP end

	local EstRank = 14;
	local Progress = math.floor(HonorSpy.db.realm.hs.currentStandings[playerOfInterest].rankProgress*100);
	local EstProgress = math.floor((EstRP - math.floor(EstRP/5000)*5000) / 5000*100);
	for i = 3,14 do
		if (EstRP < RankThresholds[i]) then
			EstRank = i-1;
			break;
		end
	end

	if (playerOfInterest ~= playerName) then
		DEFAULT_CHAT_FRAME:AddMessage(L["Report for player"].." "..playerOfInterest, 0.92, 0.85, 0,09)
	end
	DEFAULT_CHAT_FRAME:AddMessage("HonorSpy v"..tostring(VERSION)..": "..L["Pool Size"].." = "..pool_size..", "..L["Standing"].." = "..standing..",  "..L["Bracket"].." = "..my_bracket..",  "..L["current RP"].." = "..RP..",  "..L["Next Week RP"].." = "..EstRP, 0.92, 0.85, 0,09)
	DEFAULT_CHAT_FRAME:AddMessage(L["Current Rank"].." = "..Rank.." ("..Progress.."%), "..L["Next Week Rank"].." = "..EstRank.." ("..EstProgress.."%)", 0.92, 0.85, 0,09)
end

-- MINIMAP
HonorSpy.defaultMinimapPosition = 200
HonorSpy.cannotDetachTooltip = true
HonorSpy.tooltipHidderWhenEmpty = false
HonorSpy.hasIcon = "Interface\\Icons\\Inv_Misc_Bomb_04"
function BuildMenu()
	local options = {
		type = "group",
		desc = L["HonorSpy options"],
		args = { }
	}

	local days = { L["Sunday"], L["Monday"], L["Tuesday"], L["Wednesday"], L["Thursday"], L["Friday"], L["Saturday"] };

	-- 1. Top toggles and actions
	options.args["overlay"] = {
		type = "toggle",
		name = "Show Overlay",
		desc = "Toggle the HonorSpy rank overlay on screen",
		order = 1,
		get = function() return not (HonorSpy.db.realm.hs.overlayHidden) end,
		set = function()
			if HonorSpyOverlay_Toggle then
				HonorSpyOverlay_Toggle()
			end
		end,
	}
	options.args["estimator"] = {
		type = "execute",
		name = "Honor Estimator",
		desc = "Open the Honor Estimator panel",
		order = 2,
		func = function()
			if HonorSpyEstimator_Toggle then
				HonorSpyEstimator_Toggle()
			end
		end,
	}
	options.args["report"] = {
		type = "execute",
		name = L["Report My Standing"],
		desc = L["Reports your current standing as emote"],
		order = 3,
		func = function() HonorSpy:Report() end,
	}

	-- 2. Display options
	options.args["display"] = {
		type = "group",
		name = "Display",
		desc = "Display settings",
		order = 4,
		args = {
			sort = {
				type = "text",
				name = L["Sort By"],
				desc = L["Set up sorting column"],
				order = 2,
				get = function() return HonorSpy.db.realm.hs.sort end,
				set = function(v)
					HonorSpy.db.realm.hs.sort = v;
					HonorSpyStandings:Refresh();
				end,
				validate = {L["Rank"], L["ThisWeekHonor"]},
			},
			limit = {
				type = "text",
				name = L["Limit Rows"],
				desc = L["Limits number of rows shown in table"],
				order = 3,
				get = function() return HonorSpy.db.realm.hs.limit end,
				set = function(v) HonorSpy.db.realm.hs.limit = v; HonorSpy:Print(L["Limit"].." = "..v) end,
				usage = L["<EP>"],
				validate = function(v)
					local n = tonumber(v)
					return n and n >= 0 and n < 10000
				end
			},
		},
	}

	-- 3. Settings
	options.args["settings"] = {
		type = "group",
		name = "Settings",
		desc = "Addon settings",
		order = 5,
		args = {
			reset_day = {
				type = "text",
				name = L["PvP Week Reset On"],
				desc = L["Day of week when new PvP week starts (10AM UTC)"],
				order = 1,
				get = function() return days[HonorSpy.db.realm.hs.reset_day+1] end,
				set = function(v)
					for k,nv in pairs(days) do
						if (v == nv) then HonorSpy.db.realm.hs.reset_day = k-1 end;
					end
					checkNeedReset();
				end,
				validate = days,
			},
		},
	}

	-- 4. Data management (bottom)
	options.args["data"] = {
		type = "group",
		name = "Data",
		desc = "Export and manage data",
		order = 6,
		args = {
			export = {
				type = "execute",
				name = L["Export to CSV"],
				desc = L["Show window with current data in CSV format"],
				order = 1,
				func = function() HonorSpy:ExportCSV() end,
			},
			purge_data = {
				type = "execute",
				name = L["_ purge all data"],
				desc = L["Delete all collected data"],
				order = 2,
				func = function() purgeData() end,
			},
		},
	}

	return options
end

-- SYNCING --
function table.copy(t)
  local u = { }
  for k, v in pairs(t) do u[k] = v end
  return setmetatable(u, getmetatable(t))
end

-- SYNCING -- (defensive checks so we never index a non-table)
function store_player(playerName, player)
  -- Must have a reasonable name and a table payload
  if type(playerName) ~= "string" or string.len(playerName) > 12 then return end
  if type(player) ~= "table" then return end

  -- Required fields must be the right types
  if type(player.last_checked) ~= "number" then return end
  if type(player.thisWeekHonor) ~= "number" then return end
  -- race can be nil from buggy senders; also filter enemy faction
  if player.race == nil or eFaction[player.race] then return end

  -- Sanity on time window
  if player.last_checked < HonorSpy.db.realm.hs.last_reset or player.last_checked > time() then
    return
  end
  -- Ignore zero-honor rows (these are common junk packets)
  if player.thisWeekHonor == 0 then return end

  -- Copy then store if newer
  local pcopy = table.copy(player)
  local localPlayer = HonorSpy.db.realm.hs.currentStandings[playerName]
  if localPlayer == nil or (type(localPlayer.last_checked) == "number" and localPlayer.last_checked < pcopy.last_checked) then
    HonorSpy.db.realm.hs.currentStandings[playerName] = pcopy
  end
end

-- RECEIVE 
--[[function HonorSpy:OnCommReceiveCustom(prefix, sender, distribution, channelName, playerName, player, filtered_players)
	self:OnCommReceive(prefix, sender, distribution, playerName, player, filtered_players)
end]]
-- RECEIVE (robust to different AceComm-2.0 arg orders and bad payloads)
function HonorSpy:OnCommReceive(prefix, a, b, c, d, e)
  -- AceComm-2.0 sometimes invokes as (prefix, sender, distribution, ...)
  -- Some forks use (prefix, distribution, sender, ...)
  local sender, distribution, playerName, player, filtered_players

  -- Heuristic: if the 3rd vararg is a string/false, treat as (sender, distribution, ...),
  -- otherwise treat as (distribution, sender, ...)
  if type(b) == "string" and (type(c) == "string" or c == false or c == nil) then
    -- (sender, distribution, playerName, player, filtered_players)
    sender, distribution, playerName, player, filtered_players = a, b, c, d, e
  else
    -- (distribution, sender, playerName, player, filtered_players)
    distribution, sender, playerName, player, filtered_players = a, b, c, d, e
  end

  -- Defensive: ignore obviously bad shapes
  if playerName == false and type(filtered_players) == "table" then
    for pn, pl in pairs(filtered_players) do
      store_player(pn, pl)
    end
    return
  end

  if type(playerName) ~= "string" then return end
  store_player(playerName, player)
end

-- SEND
local last_send_time = 0;
function HonorSpy:PLAYER_DEAD()
	local filtered_players, count = {}, 0;
	if (time() - last_send_time < 5*60) then return	end;
	last_send_time = time();

	for playerName, player in pairs(self.db.realm.hs.currentStandings) do
		player.is_outdated = false;
		filtered_players[playerName] = player;
		count = count + 1;
		if (count == 10) then
			self:SendCommMessage("GROUP", false, false, filtered_players);
			self:SendCommMessage("GUILD", false, false, filtered_players);
			-- self:SendCommMessage("CUSTOM", "HS", false, false, filtered_players);
			filtered_players, count = {}, 0;
		end
	end
	if (count > 0) then
		self:SendCommMessage("GROUP", false, false, filtered_players);
		self:SendCommMessage("GUILD", false, false, filtered_players);
		-- self:SendCommMessage("CUSTOM", "HS", false, false, filtered_players);
	end
end
