-- Version check: broadcasts addon version via addon messages to guild/party/raid.
-- If another player has a newer version, shows a one-time chat notification
-- and updates the overlay footer.

local ADDON_NAME = "TurtleHonorSpyEnhanced"
local MY_VERSION = GetAddOnMetadata(ADDON_NAME, "Version") or "0.0.0"
local MSG_PREFIX = "THSE"
local updateNotified = false

THSE_VersionDebug = false

local function VerDebug(direction, channel, who, payload)
	if not THSE_VersionDebug then return end
	local tag = direction == "OUT"
		and "|cff44ff44[THSE SEND]|r"
		or  "|cff44ddff[THSE RECV]|r"
	DEFAULT_CHAT_FRAME:AddMessage(
		tag .. " " .. channel .. " " .. (who or "?") .. " => " .. tostring(payload))
end

-- Global table: THSE_AddonUsers[name] = { ver = "x.y.z", seen = <timestamp> }
THSE_AddonUsers = {}
local EXPIRY_SECONDS = 7 * 24 * 60 * 60

local function IsInBattleground()
	for i = 1, (MAX_BATTLEFIELD_QUEUES or 3) do
		if GetBattlefieldStatus(i) == "active" then return true end
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

local function ParseVersion(str)
	local nums, letter = {}, nil
	for num in string.gfind(str, "(%d+)") do
		table.insert(nums, tonumber(num))
	end
	local _, _, l = string.find(str, "(%a)%s*$")
	if l then letter = string.lower(l) end
	return { nums = nums, letter = letter }
end

local function CompareVersions(a, b)
	local pa, pb = ParseVersion(a), ParseVersion(b)
	local len = math.max(table.getn(pa.nums), table.getn(pb.nums))
	for i = 1, len do
		local va = pa.nums[i] or 0
		local vb = pb.nums[i] or 0
		if va > vb then return  1 end
		if va < vb then return -1 end
	end
	local la, lb = pa.letter or "", pb.letter or ""
	if la > lb then return  1 end
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
		SendAddonMessage(MSG_PREFIX, msg, "RAID")
		VerDebug("OUT", "BATTLEGROUND", me, msg)
	elseif GetNumRaidMembers() > 0 then
		SendAddonMessage(MSG_PREFIX, msg, "RAID")
		VerDebug("OUT", "RAID", me, msg)
	elseif GetNumPartyMembers() > 0 then
		SendAddonMessage(MSG_PREFIX, msg, "PARTY")
		VerDebug("OUT", "PARTY", me, msg)
	end
end

local function ReplyVersion(distribution)
	SendAddonMessage(MSG_PREFIX, MY_VERSION, distribution)
	VerDebug("OUT", distribution .. "(reply)", UnitName("player"), MY_VERSION)
end

local function OnRemoteVersion(version)
	if updateNotified then return end
	if CompareVersions(version, MY_VERSION) > 0 then
		updateNotified = true
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cffFFD100TurtleHonorSpyEnhanced:|r Update available: v" ..
			version .. " (you have v" .. MY_VERSION .. ")",
			1, 0.82, 0)
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
local REBROADCAST_INTERVAL      = 60
local REBROADCAST_INTERVAL_INST = 300
local timeSinceLastBroadcast = 0

frame:SetScript("OnEvent", function()
	if event == "CHAT_MSG_ADDON" then
		if arg1 == MSG_PREFIX and arg2 and arg4 ~= UnitName("player") then
			local _, _, msgType, payload = string.find(arg2, "^(%u+):(.+)$")
			if not msgType then msgType, payload = "VER", arg2 end
			VerDebug("IN", arg3 or "?", arg4, msgType .. ":" .. tostring(payload))
			if msgType == "VER" then
				SaveAddonUser(arg4, payload)
				OnRemoteVersion(payload)
			elseif msgType == "REQ" then
				ReplyVersion(arg3)
			end
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		LoadAddonUsers()
		needsBroadcast = true
		broadcastDelay = 0
	elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
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
			local reqMsg = "REQ:1"
			if IsInGuild() then SendAddonMessage(MSG_PREFIX, reqMsg, "GUILD") end
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
		timeSinceLastBroadcast = timeSinceLastBroadcast + arg1
		local rebroadcastRate = REBROADCAST_INTERVAL
		if IsInInstance and IsInInstance() then
			local _, iType = IsInInstance()
			if iType == "party" or iType == "raid" then
				rebroadcastRate = REBROADCAST_INTERVAL_INST
			end
		end
		if timeSinceLastBroadcast >= rebroadcastRate then
			timeSinceLastBroadcast = 0
			BroadcastVersion()
			local reqMsg = "REQ:1"
			if IsInGuild() then SendAddonMessage(MSG_PREFIX, reqMsg, "GUILD") end
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

-- ===== /hsver slash command =====
SLASH_HSVER1 = "/hsver"
SlashCmdList["HSVER"] = function(msg)
	msg = string.lower(msg or "")

	if string.sub(msg, 1, 8) == "test msg" then
		local rest = string.sub(msg, 10)
		local fakeVer, fakeName
		local _, _, v, n = string.find(rest, "^(%S+)%s+(%S+)")
		if v then fakeVer, fakeName = v, n
		else fakeVer = rest ~= "" and rest or "9.9.9" end
		fakeName = fakeName or "TestPlayer"
		updateNotified = false
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cffFFD100THSE Debug:|r Simulating receive: sender=" ..
			fakeName .. " version=" .. fakeVer, 0.6, 0.8, 1)
		SaveAddonUser(fakeName, fakeVer)
		OnRemoteVersion(fakeVer)
		return
	end

	if msg == "test" then
		updateNotified = false
		OnRemoteVersion("9.9.9")

	elseif msg == "reset" then
		updateNotified = false
		local overlay = getglobal("HonorSpyOverlayFrame")
		if overlay and overlay.versionFooter then
			overlay.versionFooter:SetTextColor(0.35, 0.35, 0.35)
			overlay.versionFooter:SetText("v" .. MY_VERSION)
		end
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cffFFD100TurtleHonorSpyEnhanced:|r Version display reset.",
			1, 0.82, 0)

	elseif msg == "debug" then
		THSE_VersionDebug = not THSE_VersionDebug
		local hs = HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
		if hs then hs.versionDebug = THSE_VersionDebug end
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cffFFD100TurtleHonorSpyEnhanced:|r Version comm debug " ..
			(THSE_VersionDebug and "|cff00ff00ON|r" or "|cffff4444OFF|r"),
			1, 0.82, 0)

	elseif msg == "users bg" then
		local numRaid = GetNumRaidMembers()
		if numRaid == 0 then
			DEFAULT_CHAT_FRAME:AddMessage(
				"|cffFFD100TurtleHonorSpyEnhanced:|r Not in a raid/battleground.",
				1, 0.82, 0)
			return
		end
		local uptodate, outdated, missing = {}, {}, {}
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
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cffFFD100TurtleHonorSpyEnhanced:|r BG version check (you: v" ..
			MY_VERSION .. ")", 1, 0.82, 0)
		if table.getn(uptodate) > 0 then
			DEFAULT_CHAT_FRAME:AddMessage(
				"  |cff88cc88Up to date (" .. table.getn(uptodate) .. "):|r",
				0.7, 0.7, 0.7)
			for _, name in ipairs(uptodate) do
				DEFAULT_CHAT_FRAME:AddMessage("    |cff88cc88" .. name .. "|r",
					0.7, 0.7, 0.7)
			end
		end
		if table.getn(outdated) > 0 then
			DEFAULT_CHAT_FRAME:AddMessage("  Outdated:", 0.87, 0.73, 0.27)
			for _, p in ipairs(outdated) do
				DEFAULT_CHAT_FRAME:AddMessage(
					"    |cffffffff" .. p.name .. "|r — |cffffaa44v" .. p.ver .. "|r",
					0.7, 0.7, 0.7)
			end
		end
		if table.getn(missing) > 0 then
			DEFAULT_CHAT_FRAME:AddMessage(
				"  No addon: |cffffffff" .. table.concat(missing, ", ") .. "|r",
				0.87, 0.73, 0.27)
		end

	elseif msg == "users req" then
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
			DEFAULT_CHAT_FRAME:AddMessage(
				"|cffFFD100TurtleHonorSpyEnhanced:|r Version request sent to: " ..
				table.concat(channels, ", "), 1, 0.82, 0)
		else
			DEFAULT_CHAT_FRAME:AddMessage(
				"|cffFFD100TurtleHonorSpyEnhanced:|r Not in guild, party, or raid.",
				1, 0.82, 0)
		end

	elseif msg == "users reset" then
		THSE_AddonUsers = {}
		local hs = HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
		if hs then hs.addonUsers = {} end
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cffFFD100TurtleHonorSpyEnhanced:|r Addon users list cleared.",
			1, 0.82, 0)

	elseif msg == "users all" or msg == "users" then
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
				DEFAULT_CHAT_FRAME:AddMessage(
					"  |cffffffff" .. name .. "|r — |cff" .. color .. ver .. "|r" .. seenAgo,
					0.7, 0.7, 0.7)
				count = count + 1
			end
		end
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cffFFD100TurtleHonorSpyEnhanced:|r " .. count .. " known addon user(s).",
			1, 0.82, 0)

	else
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cffFFD100TurtleHonorSpyEnhanced:|r v" .. MY_VERSION, 1, 0.82, 0)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  /hsver test — simulate update available", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  /hsver test msg [ver] [name] — simulate receive from a fake player",
			0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  /hsver reset — revert update display", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  /hsver debug — toggle version comm debug logging", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  /hsver users all — list known addon users and versions", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  /hsver users reset — clear the addon users list", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  /hsver users bg — show raid members not on current version", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  /hsver users req — send version request to guild/party/raid", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  /hsver pvp [rank|week|last|life|sess] — dump PvP API values", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  /hsver watch — watch rank progress / honor live (1s poll)", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  /hsver watch stop — stop the watcher", 0.7, 0.7, 0.7)
	end
end