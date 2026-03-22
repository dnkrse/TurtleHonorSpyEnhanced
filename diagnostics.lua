-- TurtleHonorSpyEnhanced: in-game diagnostics
-- /hsdiag — dumps DB state and addon status to chat.

SLASH_HSDIAG1 = "/hsdiag"
SlashCmdList["HSDIAG"] = function(msg)
	local cmd = string.lower(msg or "")
	local out = DEFAULT_CHAT_FRAME

	local function p(text, r, g, b)
		out:AddMessage(text, r or 1, g or 0.82, b or 0)
	end

	p("|cffFFD100=== TurtleHonorSpyEnhanced Diagnostics ===|r")

	-- Version
	local ver = GetAddOnMetadata("TurtleHonorSpyEnhanced", "Version") or "?"
	p("Version: " .. ver, 1, 1, 1)

	-- DB access
	local hs = HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
	if not hs then
		p("|cffff4444DB not accessible — HonorSpy.db.realm.hs is nil|r")
		return
	end
	p("DB: OK", 0.4, 1, 0.4)

	-- Honor history
	local histCount = hs.honorHistory and table.getn(hs.honorHistory) or 0
	p("Honor history entries: " .. histCount, 1, 1, 1)

	if histCount > 0 then
		local newest = hs.honorHistory[1]
		local oldest = hs.honorHistory[histCount]
		p("  Newest: " .. date("%Y-%m-%d %H:%M", newest.t) ..
			"  type=" .. (newest.type or "?") ..
			"  +" .. (newest.amount or 0) ..
			"  zone=" .. (newest.zone or "nil"),
			0.7, 0.7, 0.7)
		p("  Oldest: " .. date("%Y-%m-%d %H:%M", oldest.t) ..
			"  type=" .. (oldest.type or "?") ..
			"  +" .. (oldest.amount or 0) ..
			"  zone=" .. (oldest.zone or "nil"),
			0.7, 0.7, 0.7)
	end

	-- Overlay position
	if hs.overlayPos then
		local pos = hs.overlayPos
		p("Overlay pos: " .. (pos.point or "?") ..
			string.format("  x=%.1f y=%.1f", pos.x or 0, pos.y or 0),
			0.7, 0.7, 0.7)
	else
		p("Overlay pos: default (not saved)", 0.7, 0.7, 0.7)
	end

	-- Minimap angle
	p("Minimap angle: " .. string.format("%.1f", hs.minimapAngle or 200), 0.7, 0.7, 0.7)

	-- Weekly progress
	if hs.weeklyStartProgress then
		p("Weekly start progress: " ..
			string.format("%.4f", hs.weeklyStartProgress), 0.7, 0.7, 0.7)
	end

	-- Session start
	if hs.sessionStartHonor then
		p("Session start honor: " .. (hs.sessionStartHonor or 0), 0.7, 0.7, 0.7)
	end

	-- Collapse state
	local nCollapsed = 0
	if hs.histCollapsed then
		for _, v in pairs(hs.histCollapsed) do
			if v then nCollapsed = nCollapsed + 1 end
		end
	end
	p("Collapsed days: " .. nCollapsed, 0.7, 0.7, 0.7)

	-- Addon users seen
	local nUsers = 0
	if THSE_AddonUsers then
		for _ in pairs(THSE_AddonUsers) do nUsers = nUsers + 1 end
	end
	p("Addon users seen this session: " .. nUsers, 0.7, 0.7, 0.7)

	-- Player PvP info
	local rank = UnitPVPRank("player") or 0
	local progress = GetPVPRankProgress() or 0
	local weekHonor = 0
	if GetPVPThisWeekStats then
		local _, h = GetPVPThisWeekStats()
		weekHonor = h or 0
	end
	p("Player rank: " .. rank ..
		string.format("  progress=%.4f  weekHonor=%d", progress, weekHonor),
		0.9, 0.9, 0.5)

	p("|cffFFD100=== End Diagnostics ===|r")
end

-- ===== PvP Debug Toggle (refactored from debug_pvp.lua) =====
local _debugPvpEnabled = false

local _debugFrame = CreateFrame("Frame", "HonorSpyDebugPvpFrame")
_debugFrame:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")
_debugFrame:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
_debugFrame:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
_debugFrame:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")
_debugFrame:RegisterEvent("CHAT_MSG_SYSTEM")
_debugFrame:RegisterEvent("QUEST_TURNED_IN")
_debugFrame:RegisterEvent("PLAYER_PVP_RANK_CHANGED")

_debugFrame:SetScript("OnEvent", function()
	if not _debugPvpEnabled then return end

	if event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cff44ddff[HonorDebug] HONOR_GAIN:|r " .. tostring(arg1),
			0.4, 0.9, 1)

	elseif event == "CHAT_MSG_BG_SYSTEM_NEUTRAL"
		or event == "CHAT_MSG_BG_SYSTEM_ALLIANCE"
		or event == "CHAT_MSG_BG_SYSTEM_HORDE" then
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cff44ddff[HonorDebug] BG_SYS (" .. event .. "):|r " .. tostring(arg1),
			0.4, 0.9, 1)

	elseif event == "CHAT_MSG_SYSTEM" then
		local msg = arg1 or ""
		if string.find(string.lower(msg), "completed") or
		   string.find(string.lower(msg), "honor") then
			DEFAULT_CHAT_FRAME:AddMessage(
				"|cff44ddff[HonorDebug] SYSTEM:|r " .. msg,
				0.4, 0.9, 1)
		end

	elseif event == "QUEST_TURNED_IN" then
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cff44ddff[HonorDebug] QUEST_TURNED_IN:|r " ..
			tostring(arg1) .. " xp=" .. tostring(arg2) .. " money=" .. tostring(arg3),
			0.4, 0.9, 1)

	elseif event == "PLAYER_PVP_RANK_CHANGED" then
		local rank = UnitPVPRank("player") or 0
		local progress = GetPVPRankProgress() or 0
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cff44ddff[HonorDebug] RANK_CHANGED:|r rank=" .. rank ..
			string.format(" progress=%.4f", progress),
			0.4, 0.9, 1)
	end
end)

function HonorSpy_ToggleDebugPvp()
	_debugPvpEnabled = not _debugPvpEnabled
	DEFAULT_CHAT_FRAME:AddMessage(
		"|cffFFD100TurtleHonorSpyEnhanced:|r PvP debug " ..
		(_debugPvpEnabled and "|cff44ff44ON|r" or "|cffff4444OFF|r"),
		1, 0.82, 0)
end
