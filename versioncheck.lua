-- Version check: broadcasts addon version via addon messages to guild/party/raid.
-- If another player has a newer version, shows a one-time chat notification
-- and updates the overlay footer.

local ADDON_NAME = "TurtleHonorSpyEnhanced"
local MY_VERSION = GetAddOnMetadata(ADDON_NAME, "Version") or "0.0.0"
local MSG_PREFIX = "THSE"
local updateNotified = false

local function ParseVersion(str)
	-- isolate only the leading x.y.z part before any separator
	local vpart = str
	local sep = string.find(str, "[^%d%.]")
	if sep then vpart = string.sub(str, 1, sep - 1) end
	local parts = {}
	for num in string.gfind(vpart, "(%d+)") do
		table.insert(parts, tonumber(num))
	end
	return parts
end

-- Returns 1 if a > b, -1 if a < b, 0 if equal
local function CompareVersions(a, b)
	local pa = ParseVersion(a)
	local pb = ParseVersion(b)
	local len = math.max(table.getn(pa), table.getn(pb))
	for i = 1, len do
		local va = pa[i] or 0
		local vb = pb[i] or 0
		if va > vb then return 1 end
		if va < vb then return -1 end
	end
	return 0
end

local function BroadcastVersion()
	local msg = "VER:" .. MY_VERSION
	if IsInGuild() then
		SendAddonMessage(MSG_PREFIX, msg, "GUILD")
	end
	if GetNumRaidMembers() > 0 then
		SendAddonMessage(MSG_PREFIX, msg, "RAID")
	elseif GetNumPartyMembers() > 0 then
		SendAddonMessage(MSG_PREFIX, msg, "PARTY")
	end
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

frame:SetScript("OnEvent", function()
	if event == "CHAT_MSG_ADDON" then
		if arg1 == MSG_PREFIX and arg2 and arg4 ~= UnitName("player") then
			local msgType, payload = string.match(arg2, "^(%u+):(.+)$")
			if not msgType then
				-- legacy bare version string from older clients
				msgType, payload = "VER", arg2
			end
			if msgType == "VER" then
				OnRemoteVersion(payload)
			end
			-- future message types handled here
		end
	elseif event == "PLAYER_ENTERING_WORLD"
		or event == "PARTY_MEMBERS_CHANGED"
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
		end
	end
end)

-- Debug slash command: /hsver test | reset | overshoot | clear | honor N | honor reset | debug
SLASH_HSVER1 = "/hsver"
SlashCmdList["HSVER"] = function(msg)
	msg = string.lower(msg or "")
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
	elseif msg == "overshoot" then
		local overlay = getglobal("HonorSpyOverlayFrame")
		if overlay and overlay.overshootDiv and overlay.overshootBtn then
			overlay.overshootText:SetText("Slow down or stop!  (hover for details)")
			overlay.overshootDiv:Show()
			overlay.overshootBtn:Show()
			overlay:SetHeight(168)
			DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100TurtleHonorSpyEnhanced:|r Overshoot warning shown (test).", 1, 0.82, 0)
		end
	elseif msg == "clear" then
		local overlay = getglobal("HonorSpyOverlayFrame")
		if overlay and overlay.overshootDiv and overlay.overshootBtn then
			overlay.overshootDiv:Hide()
			overlay.overshootBtn:Hide()
			overlay:SetHeight(150)
			DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100TurtleHonorSpyEnhanced:|r Overshoot warning cleared.", 1, 0.82, 0)
		end
	elseif msg == "debug" then
		HonorSpy:ToggleDebugMenu()
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100TurtleHonorSpyEnhanced:|r v" .. MY_VERSION, 1, 0.82, 0)
		DEFAULT_CHAT_FRAME:AddMessage("  /hsver test — simulate update available", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage("  /hsver reset — revert update display", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage("  /hsver overshoot — simulate B14 overshoot warning", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage("  /hsver clear — clear overshoot warning", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage("  /hsver honor 250000 — override your honor value", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage("  /hsver honor reset — clear honor override", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage("  /hsver debug — toggle debug menu in right-click dropdown", 0.7, 0.7, 0.7)
	end
end
