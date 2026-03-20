HonorSpy = AceLibrary("AceAddon-2.0"):new("AceDB-2.0", "AceEvent-2.0", "AceModuleCore-2.0")

HonorSpy:RegisterDB("HonorSpyDB")
HonorSpy:RegisterDefaults('realm', {
	hs = {
		overlayPos          = nil,
		overlayHidden       = false,
		minimapAngle        = 200,
		addonUsers          = {},
		weeklyStartProgress = nil,
		weeklyResetStamp    = 0,
		sessionStartHonor   = 0,
	}
})

function HonorSpy:OnEnable()
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

-- /hs or /honorspy to toggle overlay, /hs about for info
SLASH_HONORSPY1 = "/hs"
SLASH_HONORSPY2 = "/honorspy"
SlashCmdList["HONORSPY"] = function(msg)
	local cmd = string.lower(msg or "")
	if cmd == "version" or cmd == "ver" then
		local ver = GetAddOnMetadata("TurtleHonorSpyEnhanced", "Version") or "?"
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cffFFD100TurtleHonorSpyEnhanced|r v" .. ver .. " — by Citrin (Tel'Abim)", 1, 0.82, 0)
	elseif cmd == "show" then
		if HonorSpyOverlay_Toggle then HonorSpyOverlay_Toggle() end
	else
		if HonorSpyOverlay_Toggle then HonorSpyOverlay_Toggle() end
	end
end

-- Called from /hsver debug
function HonorSpy:ToggleDebugMenu()
	DEFAULT_CHAT_FRAME:AddMessage(
		"|cffFFD100TurtleHonorSpyEnhanced:|r No debug menu available.",
		1, 0.82, 0)
end

-- ===== Minimap Button =====
local MINIMAP_ICON = "Interface\\Icons\\Inv_Misc_Bomb_04"
local minimapButton
local minimapAngle = 200

local function updateMinimapButtonPosition()
	local angle = math.rad(minimapAngle)
	minimapButton:ClearAllPoints()
	minimapButton:SetPoint("CENTER", Minimap, "CENTER",
		80 * math.cos(angle), 80 * math.sin(angle))
end

function HonorSpy:PLAYER_ENTERING_WORLD()
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")

	local hs = self.db and self.db.realm and self.db.realm.hs
	if hs and hs.minimapAngle then minimapAngle = hs.minimapAngle end

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

	local border = minimapButton:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetWidth(53)
	border:SetHeight(53)
	border:SetPoint("TOPLEFT", minimapButton, "TOPLEFT")

	minimapButton:EnableMouse(true)
	minimapButton:RegisterForDrag("LeftButton")
	minimapButton:RegisterForClicks("LeftButtonUp")

	minimapButton:SetScript("OnClick", function()
		if HonorSpyOverlay_Toggle then HonorSpyOverlay_Toggle() end
	end)

	minimapButton:SetScript("OnDragStart", function()
		this:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local px, py = GetCursorPosition()
			local s = UIParent:GetEffectiveScale()
			minimapAngle = math.mod(
				math.deg(math.atan2(py / s - my, px / s - mx)), 360)
			local db = HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
			if db then db.minimapAngle = minimapAngle end
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
		GameTooltip:Show()
	end)

	minimapButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	updateMinimapButtonPosition()
end