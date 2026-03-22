-- TurtleHonorSpyEnhanced: slash command handlers
-- /hs or /honorspy — main command dispatcher

SLASH_HONORSPY1 = "/hs"
SLASH_HONORSPY2 = "/honorspy"

SlashCmdList["HONORSPY"] = function(msg)
	local cmd = string.lower(msg or "")

	if cmd == "" or cmd == "show" or cmd == "overlay" then
		if HonorSpyOverlay_Toggle then HonorSpyOverlay_Toggle() end

	elseif cmd == "history" or cmd == "hist" or cmd == "log" then
		if HonorHistory_Open then HonorHistory_Open() end

	elseif cmd == "version" or cmd == "ver" then
		local ver = GetAddOnMetadata("TurtleHonorSpyEnhanced", "Version") or "?"
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cffFFD100TurtleHonorSpyEnhanced|r v" .. ver .. " by Citrin (Tel'Abim)",
			1, 0.82, 0)

	elseif cmd == "minimap" then
		if HonorSpyMinimap_Toggle then HonorSpyMinimap_Toggle() end

	elseif cmd == "help" or cmd == "?" then
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cffFFD100TurtleHonorSpyEnhanced|r commands:", 1, 0.82, 0)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  |cffffff00/hs|r          — Toggle overlay", 1, 1, 1)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  |cffffff00/hs history|r  — Toggle honor history window", 1, 1, 1)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  |cffffff00/hs minimap|r  — Toggle minimap button", 1, 1, 1)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  |cffffff00/hs version|r  — Show addon version", 1, 1, 1)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  |cffffff00/hsver diag|r  — Dump DB/addon state", 1, 1, 1)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  |cffffff00/hsver pvpdebug|r  — Toggle PvP event debug", 1, 1, 1)
	else
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cffFFD100TurtleHonorSpyEnhanced:|r Unknown command '" .. cmd ..
			"'. Try |cffffff00/hs help|r.", 1, 0.82, 0)
	end
end
