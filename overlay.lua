-- HonorSpy Overlay: current rank widget

local PAD     = 8
local INNER_W = 194

-- ===== Frame =====
local Frame = CreateFrame("Frame", "HonorSpyOverlayFrame", UIParent)
Frame:SetWidth(210)
Frame:SetHeight(92)
Frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
Frame:SetFrameStrata("HIGH")
Frame:SetFrameLevel(10)
Frame:SetMovable(true)
Frame:EnableMouse(true)
Frame:SetClampedToScreen(true)
Frame:SetBackdrop({
	bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
Frame:SetBackdropColor(0, 0, 0, 0.85)
Frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
Frame:RegisterForDrag("LeftButton")
Frame:SetScript("OnDragStart", function() this:StartMoving() end)
Frame:SetScript("OnDragStop", function()
	this:StopMovingOrSizing()
	local hs = HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
	if hs then
		local point, _, relPoint, x, y = this:GetPoint()
		hs.overlayPos = { point = point, relPoint = relPoint, x = x, y = y }
	end
end)
Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
Frame:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")
Frame:RegisterEvent("PLAYER_PVP_RANK_CHANGED")

-- ===== Close Button =====
local closeBtn = CreateFrame("Button", nil, Frame, "UIPanelCloseButton")
closeBtn:SetWidth(20)
closeBtn:SetHeight(20)
closeBtn:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -2, -2)
closeBtn:SetScript("OnClick", function()
	Frame:Hide()
	local hs = HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
	if hs then hs.overlayHidden = true end
end)

-- ===== Top-right Icon Buttons (greyed out, coming soon) =====
local btnEstimator = CreateFrame("Button", nil, Frame)
btnEstimator:SetWidth(13)
btnEstimator:SetHeight(13)
btnEstimator:SetPoint("RIGHT", closeBtn, "LEFT", -1, 0)
local btnEstTex = btnEstimator:CreateTexture(nil, "ARTWORK")
btnEstTex:SetAllPoints(btnEstimator)
btnEstTex:SetTexture("Interface\\Buttons\\UI-GuildButton-MOTD-Up")
btnEstTex:SetVertexColor(0.35, 0.35, 0.35)
btnEstimator:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine("Rank Calculator", 0.5, 0.5, 0.5)
	GameTooltip:AddLine("Coming soon", 0.35, 0.35, 0.35)
	GameTooltip:Show()
end)
btnEstimator:SetScript("OnLeave", function() GameTooltip:Hide() end)

local btnTable = CreateFrame("Button", nil, Frame)
btnTable:SetWidth(13)
btnTable:SetHeight(13)
btnTable:SetPoint("RIGHT", btnEstimator, "LEFT", -3, 0)
local btnTableTex = btnTable:CreateTexture(nil, "ARTWORK")
btnTableTex:SetAllPoints(btnTable)
btnTableTex:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
btnTableTex:SetVertexColor(0.7, 0.7, 0.7)
btnTable:SetScript("OnClick", function()
	if HonorHistory_Open then HonorHistory_Open() end
end)
btnTable:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine("Honor History", 1, 0.82, 0)
	GameTooltip:AddLine("Click to open", 0.7, 0.7, 0.7)
	GameTooltip:Show()
end)
btnTable:SetScript("OnLeave", function() GameTooltip:Hide() end)

local btnPool = CreateFrame("Button", nil, Frame)
btnPool:SetWidth(16)
btnPool:SetHeight(13)
btnPool:SetPoint("RIGHT", btnTable, "LEFT", -3, 0)
local btnPoolFS = btnPool:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
btnPoolFS:SetAllPoints()
btnPoolFS:SetJustifyH("CENTER")
btnPoolFS:SetText("%")
btnPoolFS:SetTextColor(0.35, 0.35, 0.35)
btnPool:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine("New Feature", 0.5, 0.5, 0.5)
	GameTooltip:AddLine("Coming soon", 0.35, 0.35, 0.35)
	GameTooltip:Show()
end)
btnPool:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- ===== Header bar (version label top-left) =====
local hdrDiv = Frame:CreateTexture(nil, "ARTWORK")
hdrDiv:SetTexture(1, 1, 1, 0.15)
hdrDiv:SetWidth(INNER_W)
hdrDiv:SetHeight(1)
hdrDiv:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -20)

local versionFooter = Frame:CreateFontString(nil, "OVERLAY")
versionFooter:SetFont("Fonts\\FRIZQT__.TTF", 9)
versionFooter:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -6)
versionFooter:SetJustifyH("LEFT")
versionFooter:SetTextColor(0.35, 0.35, 0.35)
versionFooter:SetText("v" .. (GetAddOnMetadata("TurtleHonorSpyEnhanced", "Version") or ""))
Frame.versionFooter = versionFooter

-- ===== Rank Display =====
local rankIcon = Frame:CreateTexture(nil, "ARTWORK")
rankIcon:SetWidth(26)
rankIcon:SetHeight(26)
rankIcon:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -26)

local rankNum = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
rankNum:SetPoint("TOPLEFT", rankIcon, "TOPRIGHT", 5, -1)
rankNum:SetJustifyH("LEFT")
rankNum:SetTextColor(1, 1, 1)

local rankPctText = Frame:CreateFontString(nil, "OVERLAY")
rankPctText:SetFont("Fonts\\FRIZQT__.TTF", 9)
rankPctText:SetPoint("LEFT", rankNum, "RIGHT", 4, 0)
rankPctText:SetJustifyH("LEFT")
rankPctText:SetTextColor(0.87, 0.73, 0.27)

local rankName = Frame:CreateFontString(nil, "OVERLAY")
rankName:SetFont("Fonts\\FRIZQT__.TTF", 9)
rankName:SetPoint("TOPLEFT", rankNum, "BOTTOMLEFT", 0, -1)
rankName:SetJustifyH("LEFT")
rankName:SetTextColor(0.55, 0.55, 0.55)

-- Rank progress two-tone bar (blue = week start, green = this week's gain)
local rankBarBg = Frame:CreateTexture(nil, "ARTWORK")
rankBarBg:SetTexture(0, 0, 0, 0.5)
rankBarBg:SetWidth(INNER_W)
rankBarBg:SetHeight(18)
rankBarBg:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -56)

local barLabel = Frame:CreateFontString(nil, "OVERLAY")
barLabel:SetFont("Fonts\\FRIZQT__.TTF", 8)
barLabel:SetPoint("TOPLEFT", rankBarBg, "BOTTOMLEFT", 0, -2)
barLabel:SetJustifyH("LEFT")
barLabel:SetTextColor(0.4, 0.4, 0.4)
barLabel:SetText("Rank Progress")

local rankBarBlue = CreateFrame("StatusBar", nil, Frame)
rankBarBlue:SetWidth(INNER_W)
rankBarBlue:SetHeight(18)
rankBarBlue:SetPoint("TOPLEFT", rankBarBg, "TOPLEFT", 0, 0)
rankBarBlue:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
rankBarBlue:SetStatusBarColor(0.25, 0.45, 0.9, 0.9)
rankBarBlue:SetMinMaxValues(0, 1)
rankBarBlue:SetFrameLevel(Frame:GetFrameLevel() + 1)

local rankBarGreen = CreateFrame("StatusBar", nil, Frame)
rankBarGreen:SetHeight(18)
rankBarGreen:SetPoint("TOPLEFT", rankBarBg, "TOPLEFT", 0, 0)
rankBarGreen:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
rankBarGreen:SetStatusBarColor(0.27, 0.87, 0.47, 0.9)
rankBarGreen:SetMinMaxValues(0, 1)
rankBarGreen:SetFrameLevel(Frame:GetFrameLevel() + 2)

-- Text overlay above both rank bars
local rankBarTextFrame = CreateFrame("Frame", nil, Frame)
rankBarTextFrame:SetWidth(INNER_W)
rankBarTextFrame:SetHeight(18)
rankBarTextFrame:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -56)
rankBarTextFrame:SetFrameLevel(Frame:GetFrameLevel() + 3)

local rankBarText = rankBarTextFrame:CreateFontString(nil, "OVERLAY")
rankBarText:SetFont("Fonts\\FRIZQT__.TTF", 9)
rankBarText:SetPoint("CENTER", rankBarTextFrame, "CENTER", 0, 0)
rankBarText:SetJustifyH("CENTER")
rankBarText:SetTextColor(1, 1, 1)

local rankBarGainText = Frame:CreateFontString(nil, "OVERLAY")
rankBarGainText:SetFont("Fonts\\FRIZQT__.TTF", 8)
rankBarGainText:SetPoint("TOPRIGHT", rankBarBg, "BOTTOMRIGHT", 0, -2)
rankBarGainText:SetJustifyH("RIGHT")
rankBarGainText:SetTextColor(0.27, 0.87, 0.47)

-- Invisible tooltip trigger over the progress bar area
local rankTip = CreateFrame("Frame", nil, Frame)
rankTip:SetPoint("TOPLEFT",  Frame, "TOPLEFT",  PAD,  -56)
rankTip:SetPoint("BOTTOMRIGHT", Frame, "TOPLEFT", 210 - PAD, -86)
rankTip:EnableMouse(true)
rankTip:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine("Rank Progress", 1, 0.82, 0)
	GameTooltip:AddLine(" ", 1,1,1)
	local base = rankTip._base
	local gain = rankTip._wkGain or "+0.00"
	local cur  = (rankTip._pct or "?") .. "%"
	if base then
		GameTooltip:AddDoubleLine("Week start", base .. "%",  0.6,0.6,0.6,  0.6,0.6,0.6)
		GameTooltip:AddDoubleLine("+ This week", gain .. "%",  0.45,0.85,0.35,  0.45,0.85,0.35)
		GameTooltip:AddDoubleLine("= Current", cur,  1,0.82,0,  1,0.82,0)
	else
		GameTooltip:AddDoubleLine("+ This week", gain .. "%",  0.45,0.85,0.35,  0.45,0.85,0.35)
		GameTooltip:AddDoubleLine("= Current", cur,  1,0.82,0,  1,0.82,0)
	end
	GameTooltip:AddLine(" ", 1,1,1)
	GameTooltip:AddLine("Your progress toward the next rank.", 0.5, 0.5, 0.5)
	GameTooltip:AddLine("Earning honor increases your rank %.", 0.5, 0.5, 0.5)
	GameTooltip:AddLine("At 100% you advance to the next rank.", 0.5, 0.5, 0.5)
	GameTooltip:Show()
end)
rankTip:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Weekly honor: "Honor" label top right, number+(%)+ icon below
local honorLabel = Frame:CreateFontString(nil, "OVERLAY")
honorLabel:SetFont("Fonts\\FRIZQT__.TTF", 10)
honorLabel:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -PAD, -28)
honorLabel:SetJustifyH("RIGHT")
honorLabel:SetTextColor(0.87, 0.73, 0.27)
honorLabel:SetText("Honor")

local honorLine = Frame:CreateFontString(nil, "OVERLAY")
honorLine:SetFont("Fonts\\FRIZQT__.TTF", 9)
honorLine:SetPoint("TOPRIGHT", honorLabel, "BOTTOMRIGHT", 0, -2)
honorLine:SetJustifyH("RIGHT")

local honorIconFrame = CreateFrame("Frame", nil, Frame)
honorIconFrame:SetWidth(12)
honorIconFrame:SetHeight(12)
honorIconFrame:SetFrameLevel(Frame:GetFrameLevel() + 5)
honorIconFrame:SetPoint("RIGHT", honorLabel, "LEFT", -2, 0)

local honorIcon = honorIconFrame:CreateTexture(nil, "OVERLAY")
honorIcon:SetAllPoints(honorIconFrame)
honorIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Alliance")
honorIcon:SetTexCoord(0.09, 0.63, 0.05, 0.63)
honorIcon:SetAlpha(0.90)

-- Tooltip trigger over honor display
local honorTip = CreateFrame("Frame", nil, Frame)
honorTip:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -PAD, -26)
honorTip:SetPoint("BOTTOMLEFT", Frame, "TOPRIGHT", -80, -52)
honorTip:EnableMouse(true)
honorTip:SetFrameLevel(Frame:GetFrameLevel() + 6)
honorTip._honor = 0

honorTip:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine("Weekly Honor", 1, 0.82, 0)
	GameTooltip:AddLine(" ", 1,1,1)
	local h = honorTip._honor or 0
	local cap = 20000
	local hFmt = h >= 1000
		and string.format("%d,%03d", math.floor(h/1000), h - math.floor(h/1000)*1000)
		or tostring(h)
	GameTooltip:AddDoubleLine("This week", hFmt, 0.87,0.73,0.27, 1,1,1)
	GameTooltip:AddDoubleLine("Weekly cap", "20,000", 0.6,0.6,0.6, 0.6,0.6,0.6)
	if h >= cap then
		GameTooltip:AddLine(" ", 1,1,1)
		GameTooltip:AddLine("Honor cap reached!", 0.2, 1.0, 0.2)
	end
	GameTooltip:AddLine(" ", 1,1,1)
	GameTooltip:AddLine("Honor earned from PvP kills this week.", 0.5, 0.5, 0.5)
	GameTooltip:AddLine("Resets every Wednesday at 00:00 UTC.", 0.5, 0.5, 0.5)
	GameTooltip:AddLine("Only the first 20,000 honor counts", 0.5, 0.5, 0.5)
	GameTooltip:AddLine("toward your rank progression.", 0.5, 0.5, 0.5)
	GameTooltip:Show()
end)
honorTip:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- ===== Update Logic =====
-- Wednesday 00:00 UTC weekly reset. Jan 7, 1970 = first Wednesday epoch.
local FIRST_WED_UTC = 518400
local WEEK_SECS     = 604800

local function GetLastWedResetUTC()
	local now = time()
	local weeksSince = math.floor((now - FIRST_WED_UTC) / WEEK_SECS)
	return FIRST_WED_UTC + weeksSince * WEEK_SECS
end

local sessionStartProgress = nil
local sessionStartRank     = nil
local weeklyStartProgress  = nil
local sessionStartHonor    = nil

local function UpdateOverlay()
	local pvpRank = UnitPVPRank("player") or 0
	if pvpRank > 0 then
		local rankNameStr, rankTex = GetPVPRankInfo(pvpRank)
		rankTex = rankTex or pvpRank
		rankIcon:SetTexture(
			string.format("Interface\\PvPRankBadges\\PvPRank%02d", rankTex))
		rankIcon:Show()
		rankName:SetText(rankNameStr or ("Rank " .. rankTex))
		rankNum:SetText("Rank " .. rankTex)
		rankNum:Show()
	else
		rankIcon:Hide()
		rankName:SetText("|cff888888No PvP Rank|r")
		rankNum:Hide()
	end

	local progress = GetPVPRankProgress() or 0
	local pct = string.format("%.2f", progress * 100)
	local hs = HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs

	-- Weekly gain % as secondary text next to rank %
	local wGain = 0
	local wGainStr = "+0.00"
	local wStart = weeklyStartProgress or 0
	if weeklyStartProgress ~= nil then
		wGain = progress - weeklyStartProgress
		if wGain < 0 then wGain = 0 end
		wGainStr = string.format("+%.2f", wGain * 100)
	end

	-- Rank progress two-tone bar: blue = week start, green = this week's gain
	rankBarBlue:SetValue(wStart)
	local bluePixels = wStart * INNER_W
	local greenWidth = math.max(1, INNER_W - bluePixels)
	rankBarGreen:SetWidth(greenWidth)
	rankBarGreen:ClearAllPoints()
	rankBarGreen:SetPoint("TOPLEFT", rankBarBg, "TOPLEFT", bluePixels, 0)
	rankBarGreen:SetMinMaxValues(0, greenWidth)
	rankBarGreen:SetValue(wGain * INNER_W)

	local pctStr = string.format("%.2f", progress * 100)
	local wGainBar = string.format("+%d", wGain * 100)
	rankBarText:SetText(pctStr .. "%")
	rankBarGainText:SetText(wGainBar .. "%")
	rankTip._pct    = pctStr
	rankTip._wkGain = wGainStr
	rankTip._base   = weeklyStartProgress and string.format("%.2f", weeklyStartProgress * 100) or nil

	-- Weekly honor text line
	local weekHonor = 0
	if GetPVPThisWeekStats then
		local _, honor = GetPVPThisWeekStats()
		weekHonor = honor or 0
	end
	local honorFmt = weekHonor >= 1000
		and string.format("%d,%03d", math.floor(weekHonor/1000), weekHonor - math.floor(weekHonor/1000)*1000)
		or tostring(weekHonor)
	local honorPct = math.min(weekHonor, 20000) / 200
	honorLine:SetText(string.format("|cff888888(%d%%)|r  %s", honorPct, honorFmt))
	honorLine:SetTextColor(1, 1, 1)
	honorTip._honor = weekHonor
	-- Update faction icon
	local faction, _ = UnitFactionGroup("player")
	if faction == "Horde" then
		honorIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Horde")
		honorIcon:SetTexCoord(0.09, 0.63, 0.05, 0.63)
	else
		honorIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Alliance")
		honorIcon:SetTexCoord(0.09, 0.63, 0.05, 0.63)
	end
end

-- ===== Event Handler =====
local pendingRefresh = 0

Frame:SetScript("OnEvent", function()
	if event == "PLAYER_ENTERING_WORLD" then
		local curProgress = GetPVPRankProgress() or 0
		local curRank     = UnitPVPRank("player") or 0
		sessionStartProgress = curProgress
		sessionStartRank     = curRank
		local curHonor    = 0
		if GetPVPThisWeekStats then
			local _, h = GetPVPThisWeekStats()
			curHonor = h or 0
		end
		sessionStartHonor = curHonor
		local hs = HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
		if hs then
			local lastReset = GetLastWedResetUTC()
			if not hs.weeklyResetStamp or hs.weeklyResetStamp < lastReset then
				hs.weeklyStartProgress = curProgress
				hs.weeklyResetStamp    = lastReset
				hs.sessionStartHonor   = curHonor
			end
			if not hs.sessionStartHonor then
				hs.sessionStartHonor = curHonor
			end
			weeklyStartProgress = hs.weeklyStartProgress or curProgress
			local pos = hs.overlayPos
			if pos then
				Frame:ClearAllPoints()
				Frame:SetPoint(
					pos.point    or "CENTER",
					UIParent,
					pos.relPoint or "CENTER",
					pos.x or 0,
					pos.y or 200)
			end
			if hs.overlayHidden then Frame:Hide() else Frame:Show() end
		else
			Frame:Show()
		end
		UpdateOverlay()
	elseif event == "CHAT_MSG_COMBAT_HONOR_GAIN" or event == "PLAYER_PVP_RANK_CHANGED" then
		pendingRefresh = 1.5
	end
end)

-- ===== Update Loop =====
local elapsed_total = 0
Frame:SetScript("OnUpdate", function()
	local dt = arg1
	if pendingRefresh > 0 then
		pendingRefresh = pendingRefresh - dt
		if pendingRefresh <= 0 then
			pendingRefresh = 0
			UpdateOverlay()
			elapsed_total = 0
		end
	end
	elapsed_total = elapsed_total + dt
	if elapsed_total >= 5 then
		elapsed_total = 0
		UpdateOverlay()
	end
end)

-- ===== Public API =====
function HonorSpyOverlay_Toggle()
	local hs = HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
	if Frame:IsVisible() then
		Frame:Hide()
		if hs then hs.overlayHidden = true end
	else
		Frame:Show()
		if hs then hs.overlayHidden = false end
		UpdateOverlay()
	end
end

function HonorSpyOverlay_Refresh()
	if Frame:IsVisible() then UpdateOverlay() end
end