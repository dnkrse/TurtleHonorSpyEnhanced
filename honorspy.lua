HonorSpy = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceEvent-2.0", "AceModuleCore-2.0", "AceComm-2.0", "AceHook-2.1")
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

local commPrefix = "HonorSpy"
HonorSpy:SetCommPrefix(commPrefix)

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
	self.OnMenuRequest = BuildMenu()
	self:Hook("InspectUnit");
	self:RegisterComm(commPrefix, "GROUP", "OnCommReceive")
	self:RegisterComm(commPrefix, "GUILD", "OnCommReceive")
	self:RegisterEvent("PLAYER_DEAD");
	self:RegisterEvent("PLAYER_TARGET_CHANGED");
	self:RegisterEvent("UPDATE_MOUSEOVER_UNIT");
	self:RegisterEvent("INSPECT_HONOR_UPDATE");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
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
		-- share with group/guild
		local to_send = sanitize_player_for_comm(player)
		if to_send then
			self:SendCommMessage("GROUP", inspectedPlayerName, to_send)
			self:SendCommMessage("GUILD", inspectedPlayerName, to_send)
		end
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
	}
}
HonorSpy:RegisterChatCommand({"/honorspy", "/hs"}, options)

-- MINIMAP
local MINIMAP_ICON = "Interface\\Icons\\Inv_Misc_Bomb_04"
local minimapButton
local minimapAngle = 200  -- degrees; saved in realm db once button is created

local function updateMinimapButtonPosition()
	local angle = math.rad(minimapAngle)
	local x = 80 * math.cos(angle)
	local y = 80 * math.sin(angle)
	minimapButton:ClearAllPoints()
	minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function HonorSpy:PLAYER_ENTERING_WORLD()
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")

	-- restore saved angle
	if self.db and self.db.realm and self.db.realm.hs and self.db.realm.hs.minimapAngle then
		minimapAngle = self.db.realm.hs.minimapAngle
	end

	-- Button
	minimapButton = CreateFrame("Button", "HonorSpyMinimapButton", Minimap)
	minimapButton:SetWidth(31)
	minimapButton:SetHeight(31)
	minimapButton:SetFrameStrata("BACKGROUND")
	minimapButton:SetFrameLevel(4)
	minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
	icon:SetTexture(MINIMAP_ICON)
	icon:SetWidth(20)
	icon:SetHeight(20)
	icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
	icon:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 7, -5)

	local overlay = minimapButton:CreateTexture(nil, "OVERLAY")
	overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	overlay:SetWidth(53)
	overlay:SetHeight(53)
	overlay:SetPoint("TOPLEFT", minimapButton, "TOPLEFT")

	minimapButton:EnableMouse(true)
	minimapButton:RegisterForDrag("LeftButton")
	minimapButton:RegisterForClicks("LeftButtonUp")

	minimapButton:SetScript("OnClick", function()
		checkNeedReset()
		if IsShiftKeyDown() then
			if HonorSpyStandings and HonorSpyStandings.Toggle then
				HonorSpyStandings:Toggle()
			end
		else
			if HonorSpyOverlay_Toggle then
				HonorSpyOverlay_Toggle()
			end
		end
	end)

	minimapButton:SetScript("OnMouseDown", function()
		if arg1 == "RightButton" then
			local dewdrop = AceLibrary("Dewdrop-2.0")
			dewdrop:Open(this, 'children', function()
				dewdrop:FeedAceOptionsTable(HonorSpy.OnMenuRequest)
			end)
		end
	end)

	minimapButton:SetScript("OnDragStart", function()
		this:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local px, py = GetCursorPosition()
			local scale = UIParent:GetEffectiveScale()
			px, py = px / scale, py / scale
			minimapAngle = math.mod(math.deg(math.atan2(py - my, px - mx)), 360)
			if HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs then
				HonorSpy.db.realm.hs.minimapAngle = minimapAngle
			end
			updateMinimapButtonPosition()
		end)
	end)

	minimapButton:SetScript("OnDragStop", function()
		this:SetScript("OnUpdate", nil)
	end)

	minimapButton:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:AddLine("TurtleHonorSpyEnhanced")
		GameTooltip:AddLine("Left-click: Toggle Overlay", 1, 1, 1)
		GameTooltip:AddLine("Shift+click: Toggle Standings Table", 1, 1, 1)
		GameTooltip:AddLine("Right-click: Menu", 1, 1, 1)
		GameTooltip:Show()
	end)

	minimapButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	updateMinimapButtonPosition()
end

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
	options.args["standings"] = {
		type = "execute",
		name = "Show Table",
		desc = "Show Table",
		order = 2,
		func = function()
			if HonorSpyStandings and HonorSpyStandings.Toggle then
				HonorSpyStandings:Toggle()
			end
		end,
	}
	options.args["estimator"] = {
		type = "execute",
		name = "Show Estimator",
		desc = "Show Estimator",
		order = 3,
		func = function()
			if HonorSpyEstimator_Toggle then
				HonorSpyEstimator_Toggle()
			end
		end,
	}
	options.args["sep1"] = {
		type = "header",
		name = "",
		order = 4,
	}
	--[[ display group removed; sort option preserved below if needed
	options.args["display"] = { type="group", name="Display", order=4, args = {
		sort = { type="text", name=L["Sort By"], desc=L["Set up sorting column"],
			get=function() return HonorSpy.db.realm.hs.sort end,
			set=function(v) HonorSpy.db.realm.hs.sort=v; HonorSpyStandings:Refresh() end,
			validate={L["Rank"],L["ThisWeekHonor"]} },
	}}
	]]

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
			limit = {
				type = "text",
				name = L["Limit Rows"],
				desc = L["Limits number of rows shown in table"],
				order = 2,
				get = function() return HonorSpy.db.realm.hs.limit end,
				set = function(v) HonorSpy.db.realm.hs.limit = v; HonorSpy:Print(L["Limit"].." = "..v) end,
				usage = L["<EP>"],
				validate = function(v)
					local n = tonumber(v)
					return n and n >= 0 and n < 10000
				end
			},
			purge_data = {
				type = "execute",
				name = L["_ purge all data"],
				desc = L["Delete all collected data"],
				order = 3,
				func = function() purgeData() end,
			},
		},
	}

	-- 4. Export
	options.args["export"] = {
		type = "execute",
		name = L["Export to CSV"],
		desc = L["Show window with current data in CSV format"],
		order = 6,
		func = function() HonorSpy:ExportCSV() end,
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

-- RECEIVE via AceComm-2.0
function HonorSpy:OnCommReceive(prefix, sender, distribution, playerName, player, filtered_players)
	if playerName == false and type(filtered_players) == "table" then
		for pn, pl in pairs(filtered_players) do
			store_player(pn, pl)
		end
		return
	end
	if type(playerName) ~= "string" then return end
	store_player(playerName, player)
end

-- SEND on death: share all standings with group/guild
local last_send_time = 0;
function HonorSpy:PLAYER_DEAD()
	local filtered_players, count = {}, 0
	if (time() - last_send_time < 5*60) then return end
	last_send_time = time()
	for pName, player in pairs(self.db.realm.hs.currentStandings) do
		local to_send = sanitize_player_for_comm(player)
		if to_send then
			filtered_players[pName] = to_send
			count = count + 1
			if count == 10 then
				self:SendCommMessage("GROUP", false, false, filtered_players)
				self:SendCommMessage("GUILD", false, false, filtered_players)
				filtered_players, count = {}, 0
			end
		end
	end
	if count > 0 then
		self:SendCommMessage("GROUP", false, false, filtered_players)
		self:SendCommMessage("GUILD", false, false, filtered_players)
	end
end
