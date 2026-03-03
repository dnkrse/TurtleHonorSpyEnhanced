HonorSpy = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceEvent-2.0", "AceModuleCore-2.0", "AceComm-2.0", "AceHook-2.1")
local L = AceLibrary("AceLocale-2.2"):new("HonorSpy")

HonorSpy:RegisterDB("HonorSpyDB")
HonorSpy:RegisterDefaults('realm', {
	hs = {
		currentStandings = {},
		last_reset = 0,
		sort = L["ThisWeekHonor"],
		limit = 750,
		debugMenu = false,
		commErrors = false,
		commRawData = false,
	}
})

-- put this near the top of honorspy.lua
local function safe_num(v)
  local n = tonumber(v) or 0
  if n ~= n then return 0 end  -- NaN guard (NaN ~= NaN)
  return n
end

local function sanitize_player_for_comm(p)
  if type(p) ~= "table" then return nil end
  local out = {}
  -- copy only primitives we expect to share
  out.last_checked   = safe_num(p.last_checked)
  out.thisWeekHonor  = safe_num(p.thisWeekHonor)
  out.lastWeekHonor  = safe_num(p.lastWeekHonor)
  out.standing       = safe_num(p.standing)
  out.rank           = safe_num(p.rank)
  if out.rank < 0 or out.rank > 14 then out.rank = 0 end
  out.rankProgress   = safe_num(p.rankProgress)
  out.RP             = safe_num(p.RP)
  out.class          = type(p.class) == "string" and p.class or nil
  out.race           = type(p.race)  == "string" and p.race  or nil  -- REQUIRED for faction filtering
  return out
end

local commPrefix = "HonorSpy"
HonorSpy:SetCommPrefix(commPrefix)

-- Debug flags: toggle independently via the Debug menu (visible after /hsver debug).
HonorSpyCommErrors  = false  -- show AceComm deserialization failures and unsuppress error handler
HonorSpyCommRawData = false  -- log raw chunk hex, outgoing sends, incoming receives, and store events
-- Convenience alias: true when either debug flag is on (used in AceComm low-level hooks)
HonorSpyCommDebug = false
local function updateCommDebug() HonorSpyCommDebug = HonorSpyCommErrors or HonorSpyCommRawData end
-- Controls whether the Debug menu group is visible (toggled via /hsver)
local debugMenuEnabled = false
-- Storage for failed chunks (populated by AceComm-2.0 when HonorSpyCommErrors is true)
HonorSpy_FailedChunks = {}
-- Temporary slot used by AceComm-2.0 HandleMessage to pass context into Deserialize's error handler
HonorSpy_PendingChunk = nil

-- Suppress AceComm/serialization errors unless error display is on.
-- WoW 1.12 fires the global error handler even inside pcall, so corrupt
-- comm data from other players causes red ERROR spam.
do
	local origHandler = geterrorhandler()
	seterrorhandler(function(msg)
		if not HonorSpyCommErrors then
			local s = msg or ""
			if string.find(s, "AceComm") or string.find(s, "Deserialize")
			   or string.find(s, "HandleMessage") or string.find(s, "CHAT_MSG_ADDON") then
				return  -- swallow silently
			end
		end
		if origHandler then return origHandler(msg) end
	end)
end

-- Debug-aware send wrapper: logs outgoing data to chat when raw data logging is enabled
local function debugSend(self, dist, pName, data)
	if HonorSpyCommRawData then
		local fields = ""
		if type(data) == "table" then
			fields = "honor=" .. tostring(data.thisWeekHonor)
				.. " rank=" .. tostring(data.rank)
				.. " RP=" .. tostring(data.RP)
				.. " class=" .. tostring(data.class)
				.. " race=" .. tostring(data.race)
				.. " checked=" .. tostring(data.last_checked)
		end
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[HonorSpy SEND]|r " .. dist .. " -> |cffffffff" .. tostring(pName) .. "|r " .. fields)
	end
	self:SendCommMessage(dist, pName, data)
end

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
	-- Restore persisted debug flags
	debugMenuEnabled = self.db.realm.hs.debugMenu or false
	self.debugMode = debugMenuEnabled
	HonorSpyCommErrors = self.db.realm.hs.commErrors or false
	HonorSpyCommRawData = self.db.realm.hs.commRawData or false
	updateCommDebug()
	self.OnMenuRequest = BuildMenu()
	self:Hook("InspectUnit");
	self:RegisterComm(commPrefix, "GROUP", "OnCommReceive")
	self:RegisterComm(commPrefix, "GUILD", "OnCommReceive")
	self:RegisterEvent("PLAYER_DEAD");
	self:RegisterEvent("PLAYER_TARGET_CHANGED");
	self:RegisterEvent("UPDATE_MOUSEOVER_UNIT");
	self:RegisterEvent("INSPECT_HONOR_UPDATE");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("RAID_ROSTER_UPDATE");
	self:RegisterEvent("PARTY_MEMBERS_CHANGED");
	checkNeedReset();
	self:ScheduleRepeatingEvent("HonorSpy_ResetCheck", checkNeedReset, 60)
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
		or name == "Unknown"
		or name == inspectedPlayerName
		or not UnitIsPlayer(unitID)
		--or not UnitIsFriend("player", unitID)  -- all grouped players are Alliance on turtle so this will record enemy players data
		or not UnitRace(unitID) -- race must be known for faction filtering (nil in cross-faction BGs if unit out of range)
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

	-- Don't save players with unknown or enemy-faction race
	if not player.race or player.race == "" or eFaction[player.race] then
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
		player._source = "INSPECT"
		player._received = time()
		if HonorSpyCommRawData then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[HonorSpy Debug]|r Stored |cffffffff" .. inspectedPlayerName .. "|r from |cff00ff00INSPECT|r honor=" .. tostring(player.thisWeekHonor) .. " rank=" .. tostring(player.rank))
		end
		self.db.realm.hs.currentStandings[inspectedPlayerName] = player;
		-- share with group/guild
		local to_send = sanitize_player_for_comm(player)
		if to_send then
			debugSend(self, "GROUP", inspectedPlayerName, to_send)
			debugSend(self, "GUILD", inspectedPlayerName, to_send)
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

-- Heal NaN-poisoned entries in SavedVariables on login
function healNaNData()
	local standings = HonorSpy.db.realm.hs.currentStandings
	local healed = 0
	local removed = 0
	for name, player in pairs(standings) do
		if type(player) == "table" then
			local dominated = false
			-- Remove "Unknown" placeholder entries (legacy data from before comm guard)
			if name == "Unknown" or name == "" then dominated = true end
			-- Fix NaN fields first
			for k, v in pairs(player) do
				if type(v) == "number" and v ~= v then
					player[k] = 0
					healed = healed + 1
				end
			end
			-- Remove entries with epoch-zero dates (last_checked == 0 or very small)
			local lc = tonumber(player.last_checked) or 0
			if lc < 1000000000 then dominated = true end  -- before ~2001 = corrupt
			-- Remove entries with negative honor
			local twh = tonumber(player.thisWeekHonor) or 0
			if twh < 0 then dominated = true end
			-- Clamp rank to 0-14
			local r = tonumber(player.rank) or 0
			if r < 0 or r > 14 then player.rank = 0; r = 0 end
			-- Clamp RP to 0-60000
			local rp = tonumber(player.RP) or 0
			if rp < 0 or rp > 60000 then player.RP = math.max(0, math.min(60000, rp)); rp = player.RP end
			-- Fix RP>0 but Rank=0: compute rank from RP (deterministic)
			if rp > 0 and r == 0 then
				local computed = 14
				for rank = 3, 14 do
					if rp < (rank - 2) * 5000 then computed = rank - 1; break end
				end
				if rp < 2000 then computed = 1
				elseif rp < 5000 then computed = 2 end
				player.rank = computed
				healed = healed + 1
			end
			-- Discard entries with Rank>1 but RP=0 (unrecoverable)
			if r > 1 and rp == 0 then dominated = true end
			-- Remove entries without a race (can't verify faction)
			if type(player.race) ~= "string" or player.race == "" then dominated = true end
			-- Remove entries with zero ThisWeekHonor (shouldn't be in standings)
			if type(player.thisWeekHonor) ~= "number" or player.thisWeekHonor <= 0 then dominated = true end
			-- Remove hopelessly corrupt entries
			if dominated then
				standings[name] = nil
				removed = removed + 1
			end
		end
	end
	if healed > 0 or removed > 0 then
		HonorSpy:Print("|cff00ff00Database healed: " .. healed .. " field(s) fixed, " .. removed .. " corrupt entry(ies) removed.|r")
	else
		HonorSpy:Print("|cff00ff00Database is clean, no issues found.|r")
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

-- Called from /hsver debug (registered in versioncheck.lua)
function HonorSpy:ToggleDebugMenu()
	debugMenuEnabled = not debugMenuEnabled
	self.debugMode = debugMenuEnabled
	self.db.realm.hs.debugMenu = debugMenuEnabled
	self.OnMenuRequest = BuildMenu()
	DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100TurtleHonorSpyEnhanced:|r Debug menu " .. (debugMenuEnabled and "|cff00ff00shown|r" or "|cffff4444hidden|r"), 1, 0.82, 0)
end

-- Called from /hsver debug reset — clears all debug overrides and flags
function HonorSpy:ResetDebugOptions()
	-- Honor and safe target overrides
	HonorSpyDebugHonorOverride = nil
	HonorSpyDebugSafeOverride = nil
	-- Comm debug flags
	HonorSpyCommErrors = false
	HonorSpyCommRawData = false
	updateCommDebug()
	self.db.realm.hs.commErrors = false
	self.db.realm.hs.commRawData = false
	-- Failed chunks storage
	HonorSpy_FailedChunks = {}
	-- Debug menu visibility
	debugMenuEnabled = false
	self.debugMode = false
	self.db.realm.hs.debugMenu = false
	self.OnMenuRequest = BuildMenu()
	DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100TurtleHonorSpyEnhanced:|r All debug options reset.", 1, 0.82, 0)
end

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
		if IsControlKeyDown() then
			HonorSpy:ToggleDebugMenu()
		elseif IsShiftKeyDown() then
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
		GameTooltip:AddLine("Ctrl+click: Toggle Debug Menu", 1, 1, 1)
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
		name = " ",
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

	-- 5. Debug (only visible after /hsver debug)
	if debugMenuEnabled then
	options.args["debug"] = {
		type = "group",
		name = "Debug",
		desc = "Debug tools for diagnosing comm issues",
		order = 7,
		args = {
			comm_errors = {
				type = "toggle",
				name = "Comm Errors",
				desc = "Show AceComm deserialization failures in chat and record failed chunks for export.",
				order = 1,
				get = function() return HonorSpyCommErrors end,
				set = function(v)
					HonorSpyCommErrors = v
					HonorSpy.db.realm.hs.commErrors = v
					updateCommDebug()
					if v then
						HonorSpy_FailedChunks = {}
						table.setn(HonorSpy_FailedChunks, 0)
					end
					HonorSpy:Print("Comm errors " .. (v and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
				end,
			},
			comm_rawdata = {
				type = "toggle",
				name = "Raw Comm Data",
				desc = "Log raw AceComm chunks, outgoing sends, incoming receives, and store events to chat.",
				order = 2,
				get = function() return HonorSpyCommRawData end,
				set = function(v)
					HonorSpyCommRawData = v
					HonorSpy.db.realm.hs.commRawData = v
					updateCommDebug()
					HonorSpy:Print("Raw comm data " .. (v and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
				end,
			},
			dump_failures = {
				type = "execute",
				name = "Dump Comm Failures",
				desc = "Open export window showing full hex of all recorded failed comm chunks (enable Comm Errors first)",
				order = 3,
				func = function() HonorSpy:DumpCommFailures() end,
			},
			heal_database = {
				type = "execute",
				name = "Heal Database",
				desc = "Fix NaN fields, remove entries with corrupt timestamps or negative honor, clamp rank/RP to valid ranges.",
				order = 4,
				func = function() healNaNData() end,
			},
		},
	}
	end -- debugMenuEnabled

	return options
end

-- Dump all recorded AceComm deserialization failures into the export window.
-- Enable Comm Debug in the HonorSpy settings first, then trigger the error, then call this.
function HonorSpy:DumpCommFailures()
	local _G = getfenv(0)
	local n = HonorSpy_FailedChunks and table.getn(HonorSpy_FailedChunks) or 0
	if n == 0 then
		self:Print("|cffff9900No comm failures recorded.|r Enable |cff00ff00Comm Errors|r in Settings, reproduce the error, then come back here.")
		return
	end

	local lines = {}
	for i = 1, n do
		local f = HonorSpy_FailedChunks[i]
		lines[i] = "=== Failure #" .. i .. " ===\n" ..
			"Time   : " .. date("%d/%m/%y %H:%M:%S", f.time) .. "\n" ..
			"Sender : " .. tostring(f.sender) .. "\n" ..
			"Channel: " .. tostring(f.dist) .. "\n" ..
			"Prefix : " .. tostring(f.prefix) .. "\n" ..
			"Len    : " .. tostring(f.len) .. " bytes\n" ..
			"Error  : " .. tostring(f.err) .. "\n" ..
			"Hex    : " .. tostring(f.hex)
	end
	local text = table.concat(lines, "\n\n")

	local PaneBackdrop = {
		bgFile = [[Interface\DialogFrame\UI-DialogBox-Background]],
		edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]],
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 3, right = 3, top = 5, bottom = 3 }
	}
	if not _G["ARLCopyFrame"] then
		local frame = CreateFrame("Frame", "ARLCopyFrame", UIParent)
		tinsert(UISpecialFrames, "ARLCopyFrame")
		frame:SetBackdrop(PaneBackdrop)
		frame:SetBackdropColor(0,0,0,1)
		frame:SetWidth(500)
		frame:SetHeight(400)
		frame:SetPoint("CENTER", UIParent, "CENTER")
		frame:SetFrameStrata("DIALOG")
		local scrollArea = CreateFrame("ScrollFrame", "ARLCopyScroll", frame, "UIPanelScrollFrameTemplate")
		scrollArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -30)
		scrollArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 8)
		local editBox = CreateFrame("EditBox", "ARLCopyEdit", frame)
		editBox:SetMultiLine(true)
		editBox:SetMaxLetters(99999)
		editBox:EnableMouse(true)
		editBox:SetAutoFocus(false)
		editBox:SetFontObject(ChatFontNormal)
		editBox:SetWidth(400)
		editBox:SetHeight(270)
		editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
		scrollArea:SetScrollChild(editBox)
		local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
	end
	_G["ARLCopyEdit"]:SetText(text)
	_G["ARLCopyFrame"]:Show()
	self:Print("Showing " .. n .. " failure(s). Select-all and copy from the window to share.")
end

-- SYNCING --
function table.copy(t)
  local u = { }
  for k, v in pairs(t) do u[k] = v end
  return setmetatable(u, getmetatable(t))
end

-- SYNCING -- (defensive checks so we never index a non-table)
function store_player(playerName, player, sender)
  -- Must have a reasonable name and a table payload
  if type(playerName) ~= "string" or string.len(playerName) > 12 then return end
  if playerName == "Unknown" then return end
  if type(player) ~= "table" then return end

  -- Required fields must be the right types
  if type(player.last_checked) ~= "number" then return end
  if type(player.thisWeekHonor) ~= "number" then return end
  -- Faction filtering: reject known enemy-faction entries
  if player.race ~= nil and eFaction[player.race] then return end
  -- If race is missing (old client), only allow updates to already-known players
  -- whose faction was previously validated. Reject unknown players without race.
  if player.race == nil then
    local existing = HonorSpy.db.realm.hs.currentStandings[playerName]
    if existing == nil or existing.race == nil then return end
  end

  -- Sanity on time window
  if player.last_checked < HonorSpy.db.realm.hs.last_reset or player.last_checked > time() then
    return
  end
  -- Ignore zero-honor rows (these are common junk packets)
  if player.thisWeekHonor == 0 then return end

  -- Copy then store if newer
  local pcopy = table.copy(player)
  pcopy.unitID = nil       -- junk from old clients ("mouseover"/"target")
  pcopy.is_outdated = nil  -- unused field from old clients
  -- Race never changes — always keep the existing one if we have it
  local existing = HonorSpy.db.realm.hs.currentStandings[playerName]
  if existing and existing.race then pcopy.race = existing.race end
  -- Scrub NaN values (NaN is the only value where x ~= x)
  for k, v in pairs(pcopy) do
    if type(v) == "number" and v ~= v then return end  -- any NaN = corrupted, discard
  end
  -- Discard entries with out-of-range values (multi-chunk corruption)
  if type(pcopy.rank) ~= "number" or pcopy.rank < 0 or pcopy.rank > 14 then return end
  if type(pcopy.RP) ~= "number" or pcopy.RP < 0 or pcopy.RP > 60000 then return end
  if pcopy.thisWeekHonor < 0 or pcopy.lastWeekHonor and pcopy.lastWeekHonor < 0 then return end
  if type(pcopy.rankProgress) == "number" and (pcopy.rankProgress < 0 or pcopy.rankProgress > 1) then return end
  if type(pcopy.standing) == "number" and pcopy.standing < 0 then return end
  -- Fix RP>0 but Rank=0: compute rank from RP (other players may send unhealed data)
  -- Bump timestamp by 1s so the healed version propagates through the network
  if pcopy.RP > 0 and pcopy.rank == 0 then
    local computed = 14
    for rank = 3, 14 do
      if pcopy.RP < (rank - 2) * 5000 then computed = rank - 1; break end
    end
    if pcopy.RP < 2000 then computed = 1
    elseif pcopy.RP < 5000 then computed = 2 end
    pcopy.rank = computed
    pcopy.last_checked = pcopy.last_checked + 1
  end
  -- Discard Rank>1 but RP=0 (unrecoverable, don't let it overwrite good local data)
  if pcopy.rank > 1 and pcopy.RP == 0 then return end
  local localPlayer = HonorSpy.db.realm.hs.currentStandings[playerName]
  if localPlayer == nil or (type(localPlayer.last_checked) == "number" and localPlayer.last_checked < pcopy.last_checked) then
    pcopy._source = sender or "unknown"
    pcopy._received = time()
    if HonorSpyCommRawData then
      DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[HonorSpy Debug]|r Stored |cffffffff" .. playerName .. "|r from |cff00ff00" .. pcopy._source .. "|r honor=" .. tostring(pcopy.thisWeekHonor) .. " rank=" .. tostring(pcopy.rank))
    end
    HonorSpy.db.realm.hs.currentStandings[playerName] = pcopy
  end
end

-- Track that a comm sender is using some HonorSpy addon.
-- If they haven't sent a VER broadcast, they're running something before v1.2
-- (which introduced the version check). A real VER broadcast overwrites this.
local function tagSenderAddon(sender)
	if type(sender) ~= "string" or sender == UnitName("player") then return end
	if not THSE_AddonUsers then return end
	local existing = THSE_AddonUsers[sender]
	-- If already identified via version broadcast (real version), just refresh timestamp
	if existing and existing.ver ~= "pre-1.2" then
		existing.seen = time()
		return
	end
	-- No VER broadcast received → pre-1.2
	if not existing then
		THSE_AddonUsers[sender] = { ver = "pre-1.2", seen = time() }
		local hs = HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
		if hs then
			if not hs.addonUsers then hs.addonUsers = {} end
			hs.addonUsers[sender] = THSE_AddonUsers[sender]
		end
	end
end

-- RECEIVE via AceComm-2.0
function HonorSpy:OnCommReceive(prefix, sender, distribution, playerName, player, filtered_players)
	if HonorSpyCommRawData then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[HonorSpy CommDebug]|r OnCommReceive from |cffffffff" .. tostring(sender) .. "|r playerName=" .. tostring(playerName) .. " player=" .. tostring(player) .. " filtered=" .. tostring(filtered_players))
	end
	if playerName == false and type(filtered_players) == "table" then
		for pn, pl in pairs(filtered_players) do
			store_player(pn, pl, sender)
		end
		tagSenderAddon(sender)
		return
	end
	if type(playerName) ~= "string" then return end
	tagSenderAddon(sender)
	store_player(playerName, player, sender)
end

-- SEND on death (BG only): share standings entries with GROUP in round-robin.
-- Shuffles all standings once, then cycles through DEATH_BURST_CAP entries per death.
-- After all entries are sent, reshuffles for the next cycle. Guarantees every entry
-- is sent exactly once before any repeats. Sends spread across ticks (10 per 0.2s).
-- A random 0-3s delay staggers when multiple addon users die at once.
local DEATH_BURST_CAP = 400
local last_send_time = 0
local death_burst_queue = {}   -- tick-by-tick send queue for current death
local death_burst_idx = 0
local death_pool = {}          -- shuffled snapshot of all standings keys
local death_pool_idx = 0       -- position in the pool across deaths

local function DeathBurstTick()
	local standings = HonorSpy.db.realm.hs.currentStandings
	local sent = 0
	while sent < 10 and death_burst_idx < table.getn(death_burst_queue) do
		death_burst_idx = death_burst_idx + 1
		local pName = death_burst_queue[death_burst_idx]
		local player = standings[pName]
		if player then
			local to_send = sanitize_player_for_comm(player)
			if to_send then
				debugSend(HonorSpy, "GROUP", pName, to_send)
			end
		end
		sent = sent + 1
	end
	if death_burst_idx >= table.getn(death_burst_queue) then
		HonorSpy:CancelScheduledEvent("HonorSpy_DeathBurstTick")
		death_burst_queue = {}
		death_burst_idx = 0
	end
end

local function DeathBurstStart()
	-- Rebuild and reshuffle pool when exhausted or empty
	if death_pool_idx >= table.getn(death_pool) then
		death_pool = {}
		for pName in pairs(HonorSpy.db.realm.hs.currentStandings) do
			table.insert(death_pool, pName)
		end
		local n = table.getn(death_pool)
		for i = n, 2, -1 do
			local j = math.random(1, i)
			death_pool[i], death_pool[j] = death_pool[j], death_pool[i]
		end
		death_pool_idx = 0
	end

	-- Take next DEATH_BURST_CAP entries from the pool
	death_burst_queue = {}
	death_burst_idx = 0
	local pool_size = table.getn(death_pool)
	local cap = DEATH_BURST_CAP
	local remaining = pool_size - death_pool_idx
	if cap > remaining then cap = remaining end
	for i = 1, cap do
		death_pool_idx = death_pool_idx + 1
		table.insert(death_burst_queue, death_pool[death_pool_idx])
	end
	if table.getn(death_burst_queue) > 0 then
		HonorSpy:ScheduleRepeatingEvent("HonorSpy_DeathBurstTick", DeathBurstTick, 0.2)
	end
end

function HonorSpy:PLAYER_DEAD()
	if not (MiniMapBattlefieldFrame and MiniMapBattlefieldFrame.status == "active") then return end
	if (time() - last_send_time < 30) then return end
	last_send_time = time()
	local delay = math.random(0, 30) * 0.1
	self:ScheduleEvent("HonorSpy_DeathBurst", DeathBurstStart, delay)
end

-- TRICKLE SYNC: send one standings entry every 0.6s to GROUP+GUILD while grouped.
-- Round-robins through a shuffled snapshot so data propagates while alive.
local trickle_keys = {}   -- snapshot of player names from standings
local trickle_idx = 0     -- current position in round-robin
local trickle_active = false

local function ShuffleTable(t)
	local n = table.getn(t)
	for i = n, 2, -1 do
		local j = math.random(1, i)
		t[i], t[j] = t[j], t[i]
	end
end

local function TrickleTick()
	local standings = HonorSpy.db.realm.hs.currentStandings
	-- Rebuild and shuffle key list when we wrap around or it's empty
	if trickle_idx >= table.getn(trickle_keys) then
		trickle_keys = {}
		for name in pairs(standings) do
			table.insert(trickle_keys, name)
		end
		ShuffleTable(trickle_keys)
		trickle_idx = 0
		if table.getn(trickle_keys) == 0 then return end
	end
	trickle_idx = trickle_idx + 1
	local pName = trickle_keys[trickle_idx]
	local player = standings[pName]
	if pName and player then
		local to_send = sanitize_player_for_comm(player)
		if to_send then
			debugSend(HonorSpy, "GROUP", pName, to_send)
			debugSend(HonorSpy, "GUILD", pName, to_send)
		end
	end
end

local function StartTrickleSync()
	if trickle_active then return end
	if GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 then return end
	trickle_active = true
	trickle_keys = {}
	trickle_idx = 0
	HonorSpy:ScheduleRepeatingEvent("HonorSpy_TrickleSync", TrickleTick, 0.6)
end

local function StopTrickleSync()
	if not trickle_active then return end
	trickle_active = false
	HonorSpy:CancelScheduledEvent("HonorSpy_TrickleSync")
end

function HonorSpy:RAID_ROSTER_UPDATE()
	if GetNumRaidMembers() > 0 then
		StartTrickleSync()
	else
		StopTrickleSync()
	end
end

function HonorSpy:PARTY_MEMBERS_CHANGED()
	if GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0 then
		StartTrickleSync()
	else
		StopTrickleSync()
	end
end
