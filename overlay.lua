-- HonorSpy Overlay: compact rank/honor widget
-- Uses data from TurtleHonorSpyEnhanced standings

local playerName = nil
local PAD = 8
local INNER_W = 194

-- ===== Frame Setup =====
local Frame = CreateFrame("Frame", "HonorSpyOverlayFrame", UIParent)
Frame:SetWidth(210)
Frame:SetHeight(132)
Frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
Frame:SetFrameStrata("HIGH")
Frame:SetFrameLevel(10)
Frame:SetMovable(true)
Frame:EnableMouse(true)
Frame:SetClampedToScreen(true)
Frame:SetBackdrop({
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
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
	if HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs then
		local point, _, relPoint, x, y = this:GetPoint()
		HonorSpy.db.realm.hs.overlayPos = { point = point, relPoint = relPoint, x = x, y = y }
	end
end)
Frame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- ===== Close Button =====
local closeBtn = CreateFrame("Button", nil, Frame, "UIPanelCloseButton")
closeBtn:SetWidth(20)
closeBtn:SetHeight(20)
closeBtn:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -2, -2)
closeBtn:SetScript("OnClick", function()
	Frame:Hide()
	if HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs then
		HonorSpy.db.realm.hs.overlayHidden = true
	end
end)

-- ===== Top-right Icon Buttons =====
local btnEstimator = CreateFrame("Button", nil, Frame)
btnEstimator:SetWidth(13)
btnEstimator:SetHeight(13)
btnEstimator:SetPoint("RIGHT", closeBtn, "LEFT", -1, 0)
local btnEstTex = btnEstimator:CreateTexture(nil, "ARTWORK")
btnEstTex:SetAllPoints(btnEstimator)
btnEstTex:SetTexture("Interface\\Buttons\\UI-GuildButton-MOTD-Up")
btnEstTex:SetVertexColor(0.7, 0.7, 0.7)
btnEstimator:SetHighlightTexture("Interface\\Buttons\\UI-GuildButton-MOTD-Up")
btnEstimator:SetScript("OnClick", function()
	if HonorSpyEstimator_Toggle then
		HonorSpyEstimator_Toggle()
	end
end)
btnEstimator:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:SetText("Honor Estimator")
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
btnTable:SetHighlightTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
btnTable:SetScript("OnClick", function()
	if HonorSpyStandings and HonorSpyStandings.Toggle then
		HonorSpyStandings:Toggle()
	end
end)
btnTable:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:SetText("Full Table")
	GameTooltip:Show()
end)
btnTable:SetScript("OnLeave", function() GameTooltip:Hide() end)
local menuFrame = CreateFrame("Frame", "HonorSpyOverlayMenu", UIParent, "UIDropDownMenuTemplate")
local function OverlayMenu_Init()
	local info

	info = {}
	info.text = "Show Full Table"
	info.notCheckable = 1
	info.func = function()
		if HonorSpyStandings and HonorSpyStandings.Toggle then
			HonorSpyStandings:Toggle()
		end
	end
	UIDropDownMenu_AddButton(info)

	info = {}
	info.text = "Honor Estimator"
	info.notCheckable = 1
	info.func = function()
		if HonorSpyEstimator_Toggle then
			HonorSpyEstimator_Toggle()
		end
	end
	UIDropDownMenu_AddButton(info)

	info = {}
	info.text = "Close Overlay"
	info.notCheckable = 1
	info.func = function()
		Frame:Hide()
		if HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs then
			HonorSpy.db.realm.hs.overlayHidden = true
		end
	end
	UIDropDownMenu_AddButton(info)

	info = {}
	info.text = "Cancel"
	info.notCheckable = 1
	info.func = function() end
	UIDropDownMenu_AddButton(info)
end
UIDropDownMenu_Initialize(menuFrame, OverlayMenu_Init, "MENU")

Frame:SetScript("OnMouseUp", function()
	if arg1 == "RightButton" then
		ToggleDropDownMenu(1, nil, menuFrame, "cursor", 0, 0)
	end
end)

-- ===== Section 1: Current Rank =====
local rankIcon = Frame:CreateTexture(nil, "ARTWORK")
rankIcon:SetWidth(26)
rankIcon:SetHeight(26)
rankIcon:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -PAD)

local rankName = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
rankName:SetPoint("TOPLEFT", rankIcon, "TOPRIGHT", 5, -1)
rankName:SetJustifyH("LEFT")
rankName:SetTextColor(1, 1, 1)

local rpText = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
rpText:SetPoint("TOPLEFT", rankName, "BOTTOMLEFT", 0, -1)
rpText:SetJustifyH("LEFT")
rpText:SetTextColor(0.87, 0.73, 0.27)

-- ===== Progress Bar =====
local barBg = Frame:CreateTexture(nil, "ARTWORK")
barBg:SetTexture(0, 0, 0, 0.5)
barBg:SetWidth(INNER_W)
barBg:SetHeight(10)
barBg:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -40)

-- Green gain bar (behind blue bar)
local barGain = CreateFrame("StatusBar", nil, Frame)
barGain:SetWidth(INNER_W)
barGain:SetHeight(10)
barGain:SetPoint("TOPLEFT", barBg, "TOPLEFT", 0, 0)
barGain:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
barGain:SetStatusBarColor(0.27, 0.87, 0.47, 0.9)
barGain:SetMinMaxValues(0, 100)
barGain:SetFrameLevel(Frame:GetFrameLevel() + 1)

-- Blue current bar (on top of gain bar)
local bar = CreateFrame("StatusBar", nil, Frame)
bar:SetWidth(INNER_W)
bar:SetHeight(10)
bar:SetPoint("TOPLEFT", barBg, "TOPLEFT", 0, 0)
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
bar:SetStatusBarColor(0.25, 0.45, 0.9, 0.9)
bar:SetMinMaxValues(0, 100)
bar:SetFrameLevel(Frame:GetFrameLevel() + 2)

local barText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
barText:SetPoint("CENTER", bar, "CENTER", 0, 0)
barText:SetTextColor(1, 1, 1)

-- ===== Divider 1 =====
local div1 = Frame:CreateTexture(nil, "ARTWORK")
div1:SetTexture(1, 1, 1, 0.15)
div1:SetWidth(INNER_W)
div1:SetHeight(1)
div1:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -54)

-- ===== Section 2: This Week Stats (two columns) =====
local honorLeft = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
honorLeft:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -59)
honorLeft:SetJustifyH("LEFT")
honorLeft:SetTextColor(0.7, 0.7, 0.7)

local honorRight = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
honorRight:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -PAD, -59)
honorRight:SetJustifyH("RIGHT")
honorRight:SetTextColor(0.87, 0.73, 0.27)

local standLeft = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
standLeft:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -71)
standLeft:SetJustifyH("LEFT")
standLeft:SetTextColor(0.7, 0.7, 0.7)

local standRight = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
standRight:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -PAD, -71)
standRight:SetJustifyH("RIGHT")
standRight:SetTextColor(1, 1, 1)

-- ===== Divider 2 =====
local div2 = Frame:CreateTexture(nil, "ARTWORK")
div2:SetTexture(1, 1, 1, 0.15)
div2:SetWidth(INNER_W)
div2:SetHeight(1)
div2:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -84)

-- ===== Section 3: Next Week Estimate =====
local nextWeekLabel = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nextWeekLabel:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -88)
nextWeekLabel:SetJustifyH("LEFT")
nextWeekLabel:SetTextColor(0.7, 0.7, 0.7)
nextWeekLabel:SetText("Next Week:")

local nextIcon = Frame:CreateTexture(nil, "ARTWORK")
nextIcon:SetWidth(20)
nextIcon:SetHeight(20)
nextIcon:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -100)

local nextRank = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nextRank:SetPoint("TOPLEFT", nextIcon, "TOPRIGHT", 4, 0)
nextRank:SetJustifyH("LEFT")
nextRank:SetTextColor(1, 1, 1)

local nextRPText = Frame:CreateFontString(nil, "OVERLAY")
nextRPText:SetFont("Fonts\\FRIZQT__.TTF", 9)
nextRPText:SetPoint("TOPLEFT", nextRank, "BOTTOMLEFT", 0, -1)
nextRPText:SetJustifyH("LEFT")
nextRPText:SetTextColor(0.87, 0.73, 0.27)

local netRPLabel = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
netRPLabel:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -PAD, -100)
netRPLabel:SetJustifyH("RIGHT")

local nextRPRight = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nextRPRight:SetPoint("TOPRIGHT", netRPLabel, "BOTTOMRIGHT", 0, -1)
nextRPRight:SetJustifyH("RIGHT")
nextRPRight:SetTextColor(0.87, 0.73, 0.27)

-- ===== Calculation Helpers (mirrors standings.lua logic) =====
local brk_pct_0 = {[0]=1, [1]=0.845, [2]=0.697, [3]=0.566, [4]=0.436, [5]=0.327, [6]=0.228, [7]=0.159, [8]=0.100, [9]=0.060, [10]=0.035, [11]=0.020, [12]=0.008, [13]=0.003}
local FY = {[0] = 0, [1] = 400}
for k = 2, 13 do FY[k] = (k - 1) * 1000 end
FY[14] = 13000

local RankThresholds = {0, 2000}
for k = 3, 14 do
	RankThresholds[k] = (k - 2) * 5000
end

local function CalcRpDecay(rpEarning, oldRp)
	local decay = math.floor(0.2 * oldRp + 0.5)
	local delta = rpEarning - decay
	if delta < 0 then delta = delta / 2 end
	if delta < -2500 then delta = -2500 end
	return oldRp + delta
end

-- ===== Update Logic =====
local function UpdateOverlay()
	if not playerName then
		playerName = UnitName("player")
	end
	if not playerName or playerName == "" or playerName == "Unknown" then return end
	if not HonorSpyStandings then return end

	local ok, t = pcall(function() return HonorSpyStandings:BuildStandingsTable() end)
	if not ok or not t then return end
	local pool_size = table.getn(t)

	-- Build bracket boundaries
	local BRK = {}
	for k = 0, 13 do
		BRK[k] = math.floor(brk_pct_0[k] * pool_size + 0.5)
	end

	-- Helper: get CP at standing position
	local function getCP(pos)
		if pos >= 1 and pos <= pool_size and t[pos] then
			return t[pos][3] or 0
		end
		return 0
	end

	-- Build FX array
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

	-- Find current player in standings
	local myStanding = 0
	local myData = nil
	for i = 1, pool_size do
		if t[i][1] == playerName then
			myStanding = i
			myData = t[i]
			break
		end
	end

	if not myData then
		rankIcon:Hide()
		rankName:SetText("|cff888888No data yet|r")
		rpText:SetText("")
		bar:SetValue(0)
		barGain:SetValue(0)
		barText:SetText("")
		honorLeft:SetText("")
		honorRight:SetText("")
		standLeft:SetText("")
		standRight:SetText("")
		nextIcon:Hide()
		nextRank:SetText("")
		nextRPText:SetText("")
		netRPLabel:SetText("")
		nextRPRight:SetText("")
		return
	end

	local name, class, thisWeekHonor, lastWeekHonor, standing, RP, rank, last_checked = unpack(myData)

	-- === Section 1: Current Rank ===
	if rank > 0 then
		rankIcon:SetTexture(string.format("Interface\\PvPRankBadges\\PvPRank%02d", rank))
		rankIcon:SetTexCoord(0, 1, 0, 1)
		rankIcon:Show()
	else
		rankIcon:Hide()
	end

	rankName:SetText(string.format("Rank %d", rank))

	-- Simple comma formatting for RP
	local rpStr = tostring(RP)
	if RP >= 1000 then
		local left = math.floor(RP / 1000)
		local right = RP - left * 1000
		rpStr = left .. "," .. string.format("%03d", right)
	end
	rpText:SetText(rpStr .. " RP")

	-- === Compute award + estimate (needed by bar and stats) ===
	local award = CalcRpEarning(thisWeekHonor)
	local awardInt = math.floor(award + 0.5)

	local EstRP = math.floor(CalcRpDecay(award, RP) + 0.5)
	if EstRP < 0 then EstRP = 0 end
	local minRP = 0
	if rank >= 3 then minRP = (rank - 2) * 5000
	elseif rank == 2 then minRP = 2000 end
	if EstRP < minRP then EstRP = minRP end

	-- === Progress Bar ===
	local curProgress = math.floor((RP - math.floor(RP / 5000) * 5000) / 5000 * 100)
	local gainRP = EstRP - RP
	local gainProgress = 0
	if gainRP > 0 then
		gainProgress = math.floor(gainRP / 5000 * 100 + 0.5)
	end
	local projectedTotal = curProgress + gainProgress
	if projectedTotal > 100 then projectedTotal = 100 end

	bar:SetValue(curProgress)
	barGain:SetValue(projectedTotal)
	if gainProgress > 0 then
		barText:SetText(string.format("%d%% |cff44dd77+%d%%|r", curProgress, gainProgress))
	else
		barText:SetText(string.format("%d%%", curProgress))
	end

	-- === Section 2: This Week Stats ===

	-- Left column: honor + standing
	local honorStr = tostring(thisWeekHonor)
	if thisWeekHonor >= 1000 then
		local left = math.floor(thisWeekHonor / 1000)
		local right = thisWeekHonor - left * 1000
		honorStr = left .. "," .. string.format("%03d", right)
	end
	honorLeft:SetText("Honor  |cffffffff" .. honorStr .. "|r")
	honorRight:SetText("+" .. awardInt .. " RP")

	-- Standing / bracket
	local myBracket = 1
	local brk_abs = {}
	for k = 1, 14 do brk_abs[k] = BRK[k - 1] end
	for b = 2, 14 do
		if myStanding > brk_abs[b] then break end
		myBracket = b
	end
	standLeft:SetText("Standing  |cffffffff#" .. myStanding .. " / " .. pool_size .. "|r")
	standRight:SetText("Bracket " .. myBracket)

	-- === Section 3: Next Week Estimate ===
	local EstRank = 14
	for r = 3, 14 do
		if EstRP < RankThresholds[r] then
			EstRank = r - 1
			break
		end
	end
	local EstProgress = math.floor((EstRP - math.floor(EstRP / 5000) * 5000) / 5000 * 100)

	if EstRank > 0 then
		nextIcon:SetTexture(string.format("Interface\\PvPRankBadges\\PvPRank%02d", EstRank))
		nextIcon:SetTexCoord(0, 1, 0, 1)
		nextIcon:Show()
	else
		nextIcon:Hide()
	end

	local rankDiff = EstRank - rank
	local diffStr = ""
	if rankDiff > 0 then
		diffStr = "  |cff44ddaa(+" .. rankDiff .. ")|r"
	elseif rankDiff < 0 then
		diffStr = "  |cffff6666(" .. rankDiff .. ")|r"
	end
	nextRank:SetText(string.format("Rank %d", EstRank) .. diffStr)

	-- Estimated total RP
	local estRPStr = tostring(EstRP)
	if EstRP >= 1000 then
		local left = math.floor(EstRP / 1000)
		local right = EstRP - left * 1000
		estRPStr = left .. "," .. string.format("%03d", right)
	end
	nextRPText:SetText(string.format("%d%%", EstProgress))

	-- Net RP change
	local weekRP = EstRP - RP
	local rpSign = weekRP >= 0 and "+" or ""
	if weekRP >= 0 then
		netRPLabel:SetText("|cff44ddaa" .. rpSign .. weekRP .. " RP|r")
	else
		netRPLabel:SetText("|cffff6666" .. rpSign .. weekRP .. " RP|r")
	end
	nextRPRight:SetText(estRPStr .. " RP")
end

-- ===== Initialization via events =====
local elapsed_total = 0
Frame:SetScript("OnUpdate", function()
	elapsed_total = elapsed_total + arg1
	if elapsed_total >= 30 then
		elapsed_total = 0
		UpdateOverlay()
	end
end)

Frame:SetScript("OnEvent", function()
	if event == "PLAYER_ENTERING_WORLD" then
		playerName = UnitName("player")
		-- Restore saved position
		if HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs then
			local pos = HonorSpy.db.realm.hs.overlayPos
			if pos then
				Frame:ClearAllPoints()
				Frame:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or "CENTER", pos.x or 0, pos.y or 200)
			end
			if HonorSpy.db.realm.hs.overlayHidden then
				Frame:Hide()
			else
				Frame:Show()
			end
		else
			Frame:Show()
		end
		UpdateOverlay()
	end
end)

-- Hook into the standings refresh cycle so overlay updates when data changes
if HonorSpyStandings and HonorSpyStandings.Refresh then
	local origRefresh = HonorSpyStandings.Refresh
	function HonorSpyStandings:Refresh()
		origRefresh(self)
		UpdateOverlay()
	end
end

-- ===== Toggle function for minimap button =====
function HonorSpyOverlay_Toggle()
	if Frame:IsVisible() then
		Frame:Hide()
		if HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs then
			HonorSpy.db.realm.hs.overlayHidden = true
		end
	else
		Frame:Show()
		if HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs then
			HonorSpy.db.realm.hs.overlayHidden = false
		end
		UpdateOverlay()
	end
end
