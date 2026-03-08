-- Version check: broadcasts addon version via addon messages to guild/party/raid.
-- If another player has a newer version, shows a one-time chat notification
-- and updates the overlay footer.

local ADDON_NAME = "TurtleHonorSpyEnhanced"
local MY_VERSION = GetAddOnMetadata(ADDON_NAME, "Version") or "0.0.0"
local MSG_PREFIX = "THSE"
local updateNotified = false

-- Global debug flag: toggled via the Debug menu or /hsver debug reset
THSE_VersionDebug = false

local function VerDebug(direction, channel, who, payload)
	if not THSE_VersionDebug then return end
	local tag = direction == "OUT" and "|cff44ff44[THSE SEND]|r" or "|cff44ddff[THSE RECV]|r"
	DEFAULT_CHAT_FRAME:AddMessage(tag .. " " .. channel .. " " .. (who or "?") .. " => " .. tostring(payload))
end

-- Global table so standings.lua can read who has the addon installed
-- Entries: THSE_AddonUsers[name] = { ver = "x.y.z", seen = <timestamp> }
THSE_AddonUsers = {}
local EXPIRY_SECONDS = 7 * 24 * 60 * 60  -- 7 days

local function IsInBattleground()
	for i = 1, (MAX_BATTLEFIELD_QUEUES or 3) do
		local status = GetBattlefieldStatus(i)
		if status == "active" then return true end
	end
	return false
end

local function LoadAddonUsers()
	local hs = HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
	if not hs then return end
	if not hs.addonUsers then hs.addonUsers = {} end
	local now = time()
	for name, entry in pairs(hs.addonUsers) do
		if type(entry) == "table" and entry.seen and (now - entry.seen) < EXPIRY_SECONDS then
			if entry.ver == "pre-1.2" then entry.ver = "pre-1.2.2" end
			THSE_AddonUsers[name] = entry
		else
			hs.addonUsers[name] = nil
		end
	end
end

local function SaveAddonUser(name, version)
	THSE_AddonUsers[name] = { ver = version, seen = time() }
	local hs = HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
	if hs then
		if not hs.addonUsers then hs.addonUsers = {} end
		hs.addonUsers[name] = THSE_AddonUsers[name]
	end
end

-- Parses "1.2.3a" into { nums = {1, 2, 3}, letter = "a" }
local function ParseVersion(str)
	local nums = {}
	local letter = nil
	for num in string.gfind(str, "(%d+)") do
		table.insert(nums, tonumber(num))
	end
	local _, _, l = string.find(str, "(%a)%s*$")
	if l then letter = string.lower(l) end
	return { nums = nums, letter = letter }
end

-- Returns 1 if a > b, -1 if a < b, 0 if equal
local function CompareVersions(a, b)
	local pa = ParseVersion(a)
	local pb = ParseVersion(b)
	local len = math.max(table.getn(pa.nums), table.getn(pb.nums))
	for i = 1, len do
		local va = pa.nums[i] or 0
		local vb = pb.nums[i] or 0
		if va > vb then return 1 end
		if va < vb then return -1 end
	end
	local la = pa.letter or ""
	local lb = pb.letter or ""
	if la > lb then return 1 end
	if la < lb then return -1 end
	return 0
end

local function BroadcastVersion()
	local me = UnitName("player")
	if me then SaveAddonUser(me, MY_VERSION) end
	local msg = MY_VERSION
	if IsInGuild() then
		SendAddonMessage(MSG_PREFIX, msg, "GUILD")
		VerDebug("OUT", "GUILD", me, msg)
	end
	if IsInBattleground() then
		SendAddonMessage(MSG_PREFIX, msg, "BATTLEGROUND")
		VerDebug("OUT", "BATTLEGROUND", me, msg)
		SendAddonMessage(MSG_PREFIX, msg, "RAID")  -- also RAID so pre-BATTLEGROUND clients see it
		VerDebug("OUT", "RAID(compat)", me, msg)
	elseif GetNumRaidMembers() > 0 then
		SendAddonMessage(MSG_PREFIX, msg, "RAID")
		VerDebug("OUT", "RAID", me, msg)
	elseif GetNumPartyMembers() > 0 then
		SendAddonMessage(MSG_PREFIX, msg, "PARTY")
		VerDebug("OUT", "PARTY", me, msg)
	end
end

-- Reply to a version request with our version (only to the channel it came from)
local function ReplyVersion(distribution)
	local msg = MY_VERSION
	SendAddonMessage(MSG_PREFIX, msg, distribution)
	VerDebug("OUT", distribution .. "(reply)", UnitName("player"), msg)
end

local function OnRemoteVersion(version)
	if updateNotified then return end
	if CompareVersions(version, MY_VERSION) > 0 then
		updateNotified = true
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cffFFD100TurtleHonorSpyEnhanced:|r Update available: v" .. version .. " (you have v" .. MY_VERSION .. ")",
			1, 0.82, 0
		)
		-- Update overlay footer if it exists
		local overlay = getglobal("HonorSpyOverlayFrame")
		if overlay and overlay.versionFooter then
			overlay.versionFooter:SetTextColor(1, 0.5, 0.2)
			overlay.versionFooter:SetText("Update available!")
		end
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
frame:RegisterEvent("RAID_ROSTER_UPDATE")

local broadcastDelay = 0
local needsBroadcast = false
local REBROADCAST_INTERVAL = 60  -- re-broadcast every 1 minute
local timeSinceLastBroadcast = 0

frame:SetScript("OnEvent", function()
	if event == "CHAT_MSG_ADDON" then
		if arg1 == MSG_PREFIX and arg2 and arg4 ~= UnitName("player") then
			local _, _, msgType, payload = string.find(arg2, "^(%u+):(.+)$")
			if not msgType then
				-- legacy bare version string from older clients
				msgType, payload = "VER", arg2
			end
			VerDebug("IN", arg3 or "?", arg4, msgType .. ":" .. tostring(payload))
			if msgType == "VER" then
				SaveAddonUser(arg4, payload)
				OnRemoteVersion(payload)
			elseif msgType == "REQ" then
				-- Someone is asking for our version; reply on the same channel
				ReplyVersion(arg3)
			end
			-- future message types handled here
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		LoadAddonUsers()
		needsBroadcast = true
		broadcastDelay = 0
	elseif event == "PARTY_MEMBERS_CHANGED"
		or event == "RAID_ROSTER_UPDATE" then
		needsBroadcast = true
		broadcastDelay = 0
	end
end)

frame:SetScript("OnUpdate", function()
	if needsBroadcast then
		broadcastDelay = broadcastDelay + arg1
		if broadcastDelay >= 5 then
			needsBroadcast = false
			BroadcastVersion()
			timeSinceLastBroadcast = 0
			-- Also send a request so others reply with their version
			local reqMsg = "REQ:1"
			if IsInGuild() then
				SendAddonMessage(MSG_PREFIX, reqMsg, "GUILD")
			end
			if IsInBattleground() then
				SendAddonMessage(MSG_PREFIX, reqMsg, "BATTLEGROUND")
				SendAddonMessage(MSG_PREFIX, reqMsg, "RAID")
			elseif GetNumRaidMembers() > 0 then
				SendAddonMessage(MSG_PREFIX, reqMsg, "RAID")
			elseif GetNumPartyMembers() > 0 then
				SendAddonMessage(MSG_PREFIX, reqMsg, "PARTY")
			end
		end
	else
		-- Periodic re-broadcast
		timeSinceLastBroadcast = timeSinceLastBroadcast + arg1
		if timeSinceLastBroadcast >= REBROADCAST_INTERVAL then
			timeSinceLastBroadcast = 0
			BroadcastVersion()
			-- Also request versions from others who may have come online since last check
			local reqMsg = "REQ:1"
			if IsInGuild() then
				SendAddonMessage(MSG_PREFIX, reqMsg, "GUILD")
			end
			if IsInBattleground() then
				SendAddonMessage(MSG_PREFIX, reqMsg, "BATTLEGROUND")
				SendAddonMessage(MSG_PREFIX, reqMsg, "RAID")
			elseif GetNumRaidMembers() > 0 then
				SendAddonMessage(MSG_PREFIX, reqMsg, "RAID")
			elseif GetNumPartyMembers() > 0 then
				SendAddonMessage(MSG_PREFIX, reqMsg, "PARTY")
			end
		end
	end
end)

-- Debug slash command: /hsver test | reset | overshoot | clear | honor N | honor reset | debug
SLASH_HSVER1 = "/hsver"
SlashCmdList["HSVER"] = function(msg)
	msg = string.lower(msg or "")
	if string.sub(msg, 1, 5) == "safe " then
		local arg = string.sub(msg, 6)
		if arg == "reset" then
			HonorSpyDebugSafeOverride = nil
			DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100TurtleHonorSpyEnhanced:|r Recommended target override cleared.", 1, 0.82, 0)
		else
			local val = tonumber(arg)
			if val then
				HonorSpyDebugSafeOverride = val
				DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100TurtleHonorSpyEnhanced:|r Recommended target override set to " .. val .. ". Re-open standings to see effect.", 1, 0.82, 0)
			else
				DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100TurtleHonorSpyEnhanced:|r Usage: /hsver safe 100000  or  /hsver safe reset", 1, 0.82, 0)
			end
		end
		return
	end
	if string.sub(msg, 1, 6) == "honor " then
		local arg = string.sub(msg, 7)
		if arg == "reset" then
			HonorSpyDebugHonorOverride = nil
			DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100TurtleHonorSpyEnhanced:|r Honor override cleared.", 1, 0.82, 0)
		else
			local val = tonumber(arg)
			if val then
				HonorSpyDebugHonorOverride = val
				DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100TurtleHonorSpyEnhanced:|r Honor override set to " .. val .. ".", 1, 0.82, 0)
			else
				DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100TurtleHonorSpyEnhanced:|r Usage: /hsver honor 250000", 1, 0.82, 0)
			end
		end
		return
	end
	if string.sub(msg, 1, 8) == "test msg" then
		-- Simulate receiving a CHAT_MSG_ADDON from a fake player
		-- Usage: /hsver test msg [version] [name]
		local rest = string.sub(msg, 10) -- after "test msg "
		local fakeVer, fakeName
		local _, _, v, n = string.find(rest, "^(%S+)%s+(%S+)")
		if v then fakeVer, fakeName = v, n
		else fakeVer = rest ~= "" and rest or "9.9.9" end
		fakeName = fakeName or "TestPlayer"
		updateNotified = false
		DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100THSE Debug:|r Simulating receive: sender=" .. fakeName .. " version=" .. fakeVer, 0.6, 0.8, 1)
		SaveAddonUser(fakeName, fakeVer)
		OnRemoteVersion(fakeVer)
		return
	end
	if msg == "test" then
		local fakeVersion = "9.9.9"
		updateNotified = false
		OnRemoteVersion(fakeVersion)
	elseif msg == "reset" then
		updateNotified = false
		local overlay = getglobal("HonorSpyOverlayFrame")
		if overlay and overlay.versionFooter then
			overlay.versionFooter:SetTextColor(0.35, 0.35, 0.35)
			overlay.versionFooter:SetText("v" .. MY_VERSION)
		end
		DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100TurtleHonorSpyEnhanced:|r Version display reset.", 1, 0.82, 0)
	elseif msg == "debug reset" then
		HonorSpy:ResetDebugOptions()
	elseif msg == "debug" then
		HonorSpy:ToggleDebugMenu()
	elseif msg == "b14" then
		local avg = HonorSpyStandings and HonorSpyStandings._b14_avg or 0
		local med = HonorSpyStandings and HonorSpyStandings._b14_median or 0
		local safe = HonorSpyStandings and HonorSpyStandings._b14_safe_target or 0
		local days = HonorSpyStandings and HonorSpyStandings._b14_daysLeft
		local slots = HonorSpyStandings and HonorSpyStandings._b14_slots or 0
		local players = HonorSpyStandings and HonorSpyStandings._b14_players
		if (med == 0 and avg == 0) or not players or table.getn(players) == 0 then
			DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100TurtleHonorSpyEnhanced:|r No B14 data yet. Open standings first.", 1, 0.82, 0)
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100TurtleHonorSpyEnhanced:|r B14 Info", 1, 0.82, 0)
			DEFAULT_CHAT_FRAME:AddMessage(string.format("  Slots: |cffffffff%d|r", slots), 0.7, 0.7, 0.7)
			DEFAULT_CHAT_FRAME:AddMessage(string.format("  Median: |cffffffff%d|r", med), 0.7, 0.7, 0.7)
			DEFAULT_CHAT_FRAME:AddMessage(string.format("  Recommended target: |cffffffff%d|r", safe), 0.7, 0.7, 0.7)
			if days then
				local buffer = 1.05 + 0.15 * (days / 7)
				DEFAULT_CHAT_FRAME:AddMessage(string.format("  Buffer: |cffffffff%.3fx|r", buffer), 0.7, 0.7, 0.7)
				DEFAULT_CHAT_FRAME:AddMessage(string.format("  Days to reset: |cffffffff%.1f|r", days), 0.7, 0.7, 0.7)
			end
			DEFAULT_CHAT_FRAME:AddMessage("  Projected target by day:", 0.87, 0.73, 0.27)
			for d = 7, 1, -1 do
				local b = 1.05 + 0.15 * (d / 7)
				local t = math.floor(med * b / 1000 + 0.5) * 1000
				local marker = (days and math.ceil(days) == d) and "  |cff66ff66<< now|r" or ""
				DEFAULT_CHAT_FRAME:AddMessage(string.format("    %dd left: |cffffffff%d|r  (%.2fx)%s", d, t, b, marker), 0.6, 0.6, 0.6)
			end
		end
	elseif msg == "races" then
		local races = {}
		local hs = HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
		if hs and hs.currentStandings then
			for name, player in pairs(hs.currentStandings) do
				local r = player.race or "nil"
				if not races[r] then races[r] = {} end
				table.insert(races[r], name)
			end
		end
		DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100TurtleHonorSpyEnhanced:|r Race tokens in database:", 1, 0.82, 0)
		for race, names in pairs(races) do
			local sample = names[1]
			if table.getn(names) > 1 then sample = sample .. ", " .. names[2] end
			DEFAULT_CHAT_FRAME:AddMessage(string.format("  |cffffffff%s|r (%d players) e.g. %s", race, table.getn(names), sample), 0.7, 0.7, 0.7)
		end
		local _, myRaceToken = UnitRace("player")
		DEFAULT_CHAT_FRAME:AddMessage("  Your race token: |cffffffff" .. tostring(myRaceToken) .. "|r", 0.87, 0.73, 0.27)
	elseif msg == "users bg" then
		local numRaid = GetNumRaidMembers()
		if numRaid == 0 then
			DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100TurtleHonorSpyEnhanced:|r You are not in a raid/battleground.", 1, 0.82, 0)
			return
		end
		local uptodate = {}
		local outdated = {}
		local missing = {}
		for i = 1, numRaid do
			local name = GetRaidRosterInfo(i)
			if name and name ~= UnitName("player") then
				local entry = THSE_AddonUsers and THSE_AddonUsers[name]
				if entry and type(entry) == "table" and entry.ver then
					if entry.ver ~= MY_VERSION then
						table.insert(outdated, { name = name, ver = entry.ver })
					else
						table.insert(uptodate, name)
					end
				else
					table.insert(missing, name)
				end
			end
		end
		DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100TurtleHonorSpyEnhanced:|r BG version check (you: v" .. MY_VERSION .. ")", 1, 0.82, 0)
		if table.getn(uptodate) > 0 then
			DEFAULT_CHAT_FRAME:AddMessage("  |cff88cc88Up to date (" .. table.getn(uptodate) .. "):|r", 0.7, 0.7, 0.7)
			for _, name in ipairs(uptodate) do
				DEFAULT_CHAT_FRAME:AddMessage("    |cff88cc88" .. name .. "|r", 0.7, 0.7, 0.7)
			end
		end
		if table.getn(outdated) > 0 then
			DEFAULT_CHAT_FRAME:AddMessage("  Outdated versions:", 0.87, 0.73, 0.27)
			for _, p in ipairs(outdated) do
				DEFAULT_CHAT_FRAME:AddMessage("    |cffffffff" .. p.name .. "|r — |cffffaa44v" .. p.ver .. "|r", 0.7, 0.7, 0.7)
			end
		end
		if table.getn(missing) > 0 then
			DEFAULT_CHAT_FRAME:AddMessage("  No addon detected: |cffffffff" .. table.concat(missing, ", ") .. "|r", 0.87, 0.73, 0.27)
		end
		if table.getn(uptodate) == 0 and table.getn(outdated) == 0 and table.getn(missing) == 0 then
			DEFAULT_CHAT_FRAME:AddMessage("  |cff888888No other raid members found.|r", 0.7, 0.7, 0.7)
		end
	elseif msg == "users all" or msg == "users reset" or msg == "users req" then
		if msg == "users req" then
			local channels = {}
			if IsInGuild() then
				SendAddonMessage(MSG_PREFIX, "REQ:1", "GUILD")
				table.insert(channels, "GUILD")
			end
			if IsInBattleground() then
				SendAddonMessage(MSG_PREFIX, "REQ:1", "BATTLEGROUND")
				SendAddonMessage(MSG_PREFIX, "REQ:1", "RAID")
				table.insert(channels, "BATTLEGROUND+RAID")
			elseif GetNumRaidMembers() > 0 then
				SendAddonMessage(MSG_PREFIX, "REQ:1", "RAID")
				table.insert(channels, "RAID")
			elseif GetNumPartyMembers() > 0 then
				SendAddonMessage(MSG_PREFIX, "REQ:1", "PARTY")
				table.insert(channels, "PARTY")
			end
			if table.getn(channels) > 0 then
				DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100TurtleHonorSpyEnhanced:|r Version request sent to: " .. table.concat(channels, ", "), 1, 0.82, 0)
			else
				DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100TurtleHonorSpyEnhanced:|r Not in guild, party, or raid — nowhere to send REQ.", 1, 0.82, 0)
			end
			return
		end
		if msg == "users reset" then
			THSE_AddonUsers = {}
			local hs = HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
			if hs then hs.addonUsers = {} end
			DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100TurtleHonorSpyEnhanced:|r Addon users list cleared.", 1, 0.82, 0)
			return
		end
		local count = 0
		if THSE_AddonUsers then
			for name, entry in pairs(THSE_AddonUsers) do
				local ver = type(entry) == "table" and entry.ver or tostring(entry)
				local seenAgo = ""
				if type(entry) == "table" and entry.seen then
					local diff = time() - entry.seen
					if diff < 3600 then
						seenAgo = string.format(" (%dm ago)", math.floor(diff / 60))
					elseif diff < 86400 then
						seenAgo = string.format(" (%.1fh ago)", diff / 3600)
					else
						seenAgo = string.format(" (%.1fd ago)", diff / 86400)
					end
				end
				local color = ver == "pre-1.2.2" and "ffaa44" or "55ccff"
				DEFAULT_CHAT_FRAME:AddMessage("  |cffffffff" .. name .. "|r — |cff" .. color .. ver .. "|r" .. seenAgo, 0.7, 0.7, 0.7)
				count = count + 1
			end
		end
		DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100TurtleHonorSpyEnhanced:|r " .. count .. " known addon user(s).", 1, 0.82, 0)
	elseif msg == "whatsnew" then
		if HonorSpyWhatsNewFrame then
			HonorSpyWhatsNewFrame:Show()
		end
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100TurtleHonorSpyEnhanced:|r v" .. MY_VERSION, 1, 0.82, 0)
		DEFAULT_CHAT_FRAME:AddMessage("  /hsver test — simulate update available", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage("  /hsver test msg [ver] [name] — simulate full receive from a fake player", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage("  /hsver reset — revert update display", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage("  /hsver honor 250000 — override your honor value", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage("  /hsver honor reset — clear honor override", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage("  /hsver safe 100000 — override B14 recommended target", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage("  /hsver safe reset — clear recommended target override", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage("  /hsver b14 — show B14 info and recommended target", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage("  /hsver debug — toggle debug menu in right-click dropdown", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage("  /hsver debug reset — reset all debug options and overrides", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage("  /hsver users all — list known addon users and versions", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage("  /hsver users reset — clear the addon users list", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage("  /hsver users bg — show raid members not on the current version", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage("  /hsver users req — manually send a version request to guild/party/raid", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage("  /hsver whatsnew — show the What's New window", 0.7, 0.7, 0.7)
	end
end
