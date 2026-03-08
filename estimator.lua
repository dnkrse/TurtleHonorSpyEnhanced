-- HonorSpy Estimator: "What if" honor slider panel
-- Shows projected rank/RP outcome for any hypothetical honor value

local PAD = 10
local FRAME_W = 340
local FRAME_H = 370
local SLIDER_W = 300

-- ===== Main Frame =====
local Frame = CreateFrame("Frame", "HonorSpyEstimatorFrame", UIParent)
Frame:SetWidth(FRAME_W)
Frame:SetHeight(FRAME_H)
Frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
Frame:SetFrameStrata("DIALOG")
Frame:SetFrameLevel(20)
Frame:SetMovable(true)
Frame:EnableMouse(true)
Frame:SetClampedToScreen(true)
Frame:SetBackdrop({
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
Frame:SetBackdropColor(0, 0, 0, 0.92)
Frame:SetBackdropBorderColor(0.6, 0.5, 0.2, 1)
Frame:RegisterForDrag("LeftButton")
Frame:SetScript("OnDragStart", function() this:StartMoving() end)
Frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
Frame:Hide()

-- ===== Title =====
local title = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", Frame, "TOP", 0, -PAD)
title:SetText("|cffddbb44Honor Estimator|r")

local subtitleText = Frame:CreateFontString(nil, "OVERLAY")
subtitleText:SetFont("Fonts\\FRIZQT__.TTF", 8)
subtitleText:SetPoint("TOP", title, "BOTTOM", 0, -1)
subtitleText:SetTextColor(0.5, 0.5, 0.5)
subtitleText:SetText("Recheck throughout the week as standings change!")

-- ===== Close Button =====
local closeBtn = CreateFrame("Button", nil, Frame, "UIPanelCloseButton")
closeBtn:SetWidth(20)
closeBtn:SetHeight(20)
closeBtn:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -2, -2)
closeBtn:SetScript("OnClick", function() Frame:Hide() end)

-- ===== Honor Value Label =====
local honorLabel = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
honorLabel:SetPoint("TOP", subtitleText, "BOTTOM", 0, -6)
honorLabel:SetText("|cffffffffHonor: 0|r")

-- ===== Slider =====
local slider = CreateFrame("Slider", "HonorSpyEstimatorSlider", Frame, "OptionsSliderTemplate")
slider:SetWidth(SLIDER_W)
slider:SetHeight(16)
slider:SetPoint("TOP", honorLabel, "BOTTOM", 0, -8)
slider:SetMinMaxValues(0, 1000000)
slider:SetValueStep(1000)
slider:SetValue(0)
getglobal(slider:GetName() .. "Low"):SetText("0")
getglobal(slider:GetName() .. "High"):SetText("")
getglobal(slider:GetName() .. "Text"):SetText("")

-- ===== Current Honor Marker on Slider =====
local markerLine = slider:CreateTexture(nil, "ARTWORK")
markerLine:SetWidth(2)
markerLine:SetHeight(20)
markerLine:SetTexture(0.3, 0.8, 1, 0.8)
markerLine:Hide()

local markerLabel = slider:CreateFontString(nil, "ARTWORK")
markerLabel:SetFont("Fonts\\FRIZQT__.TTF", 7)
markerLabel:SetPoint("TOP", markerLine, "BOTTOM", 0, -1)
markerLabel:SetTextColor(0.3, 0.8, 1)
markerLabel:SetText("You")
markerLabel:Hide()

local cachedPlayerHonor = 0

local function UpdateMarker()
	if cachedPlayerHonor <= 0 then
		markerLine:Hide()
		markerLabel:Hide()
		return
	end
	local sMin, sMax = slider:GetMinMaxValues()
	local range = sMax - sMin
	if range <= 0 then
		markerLine:Hide()
		markerLabel:Hide()
		return
	end
	local frac = (cachedPlayerHonor - sMin) / range
	if frac < 0 then frac = 0 end
	if frac > 1 then frac = 1 end
	-- Slider thumb travel area: account for thumb half-width on each side
	local thumbHalf = 14
	local usable = SLIDER_W - thumbHalf * 2
	local xOff = thumbHalf + frac * usable - SLIDER_W / 2
	markerLine:ClearAllPoints()
	markerLine:SetPoint("CENTER", slider, "CENTER", xOff, 0)
	markerLine:Show()
	markerLabel:Show()
end

-- ===== Divider =====
local div1 = Frame:CreateTexture(nil, "ARTWORK")
div1:SetTexture(1, 1, 1, 0.15)
div1:SetWidth(SLIDER_W)
div1:SetHeight(1)
div1:SetPoint("TOP", slider, "BOTTOM", 0, -10)

-- ===== Result: Standing / Bracket =====
local standingText = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
standingText:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -100)
standingText:SetJustifyH("LEFT")
standingText:SetTextColor(0.7, 0.7, 0.7)

local bracketText = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
bracketText:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -PAD, -100)
bracketText:SetJustifyH("RIGHT")
bracketText:SetTextColor(1, 1, 1)

-- ===== Result: Your Current Honor =====
local yourHonorLabel = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
yourHonorLabel:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -118)
yourHonorLabel:SetJustifyH("LEFT")
yourHonorLabel:SetTextColor(0.5, 0.5, 0.5)
yourHonorLabel:SetText("Your Honor:")

local yourHonorValue = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
yourHonorValue:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -PAD, -118)
yourHonorValue:SetJustifyH("RIGHT")
yourHonorValue:SetTextColor(0.3, 0.8, 1)

-- ===== Result: This Week (current) =====
local curLabel = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
curLabel:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -134)
curLabel:SetJustifyH("LEFT")
curLabel:SetTextColor(0.5, 0.5, 0.5)
curLabel:SetText("This Week:")

local curIcon = Frame:CreateTexture(nil, "ARTWORK")
curIcon:SetWidth(18)
curIcon:SetHeight(18)
curIcon:SetPoint("LEFT", curLabel, "RIGHT", 4, 0)

local curRankText = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
curRankText:SetPoint("LEFT", curIcon, "RIGHT", 4, 0)
curRankText:SetJustifyH("LEFT")
curRankText:SetTextColor(0.8, 0.8, 0.8)

-- ===== Result: Next Week (projected) =====
local nextLabel = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nextLabel:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -154)
nextLabel:SetJustifyH("LEFT")
nextLabel:SetTextColor(0.7, 0.7, 0.7)
nextLabel:SetText("Next Week:")

local nextIcon = Frame:CreateTexture(nil, "ARTWORK")
nextIcon:SetWidth(18)
nextIcon:SetHeight(18)
nextIcon:SetPoint("LEFT", nextLabel, "RIGHT", 4, 0)

local nextRankText = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nextRankText:SetPoint("LEFT", nextIcon, "RIGHT", 4, 0)
nextRankText:SetJustifyH("LEFT")

local deltaText = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
deltaText:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -PAD, -154)
deltaText:SetJustifyH("RIGHT")

-- ===== Next Bracket Hint =====
local hintText = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hintText:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -179)
hintText:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -PAD, -179)
hintText:SetJustifyH("CENTER")
hintText:SetTextColor(0.6, 0.6, 0.4)

local wasteText = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
wasteText:SetWidth(FRAME_W - PAD * 2)
wasteText:SetPoint("TOP", hintText, "BOTTOM", 0, -1)
wasteText:SetJustifyH("CENTER")
wasteText:SetTextColor(1, 0.4, 0.4)

local impactText = Frame:CreateFontString(nil, "OVERLAY")
impactText:SetFont("Fonts\\FRIZQT__.TTF", 9)
impactText:SetWidth(FRAME_W - PAD * 2)
impactText:SetPoint("TOP", wasteText, "BOTTOM", 0, -1)
impactText:SetJustifyH("CENTER")

-- ===== RP Curve Graph =====
local GRAPH_H = 100
local GRAPH_BOTTOM = 16
local GRAPH_AREA_W = SLIDER_W  -- 240
local GRAPH_SAMPLES = 120

local div2 = Frame:CreateTexture(nil, "ARTWORK")
div2:SetTexture(1, 1, 1, 0.15)
div2:SetWidth(SLIDER_W)
div2:SetHeight(1)
div2:SetPoint("BOTTOM", Frame, "BOTTOM", 0, GRAPH_BOTTOM + GRAPH_H + 16)

local graphTitle = Frame:CreateFontString(nil, "OVERLAY")
graphTitle:SetFont("Fonts\\FRIZQT__.TTF", 8)
graphTitle:SetPoint("BOTTOM", div2, "TOP", 0, 2)
graphTitle:SetTextColor(0.7, 0.7, 0.5)
graphTitle:SetText("RP Earning by Honor")

local graphArea = CreateFrame("Frame", nil, Frame)
graphArea:SetWidth(GRAPH_AREA_W)
graphArea:SetHeight(GRAPH_H)
graphArea:SetPoint("BOTTOM", Frame, "BOTTOM", 0, GRAPH_BOTTOM)

local graphBg = graphArea:CreateTexture(nil, "BACKGROUND")
graphBg:SetAllPoints()
graphBg:SetTexture(0, 0, 0, 0.3)

local xAxisLine = graphArea:CreateTexture(nil, "ARTWORK")
xAxisLine:SetWidth(GRAPH_AREA_W)
xAxisLine:SetHeight(1)
xAxisLine:SetTexture(1, 1, 1, 0.2)
xAxisLine:SetPoint("BOTTOMLEFT", graphArea, "BOTTOMLEFT", 0, 0)

local yAxisLine = graphArea:CreateTexture(nil, "ARTWORK")
yAxisLine:SetWidth(1)
yAxisLine:SetHeight(GRAPH_H)
yAxisLine:SetTexture(1, 1, 1, 0.2)
yAxisLine:SetPoint("BOTTOMLEFT", graphArea, "BOTTOMLEFT", 0, 0)

local yMaxLabel = graphArea:CreateFontString(nil, "OVERLAY")
yMaxLabel:SetFont("Fonts\\FRIZQT__.TTF", 7)
yMaxLabel:SetPoint("TOPLEFT", graphArea, "TOPLEFT", 2, -1)
yMaxLabel:SetTextColor(0.6, 0.6, 0.4)

local yMinLabel = graphArea:CreateFontString(nil, "OVERLAY")
yMinLabel:SetFont("Fonts\\FRIZQT__.TTF", 7)
yMinLabel:SetPoint("BOTTOMLEFT", graphArea, "BOTTOMLEFT", 2, 2)
yMinLabel:SetTextColor(0.6, 0.6, 0.4)
yMinLabel:SetText("0")

local xMinLabel = graphArea:CreateFontString(nil, "OVERLAY")
xMinLabel:SetFont("Fonts\\FRIZQT__.TTF", 7)
xMinLabel:SetPoint("TOPLEFT", graphArea, "BOTTOMLEFT", 0, -1)
xMinLabel:SetTextColor(0.6, 0.6, 0.4)
xMinLabel:SetText("0")

local xMaxLabel = graphArea:CreateFontString(nil, "OVERLAY")
xMaxLabel:SetFont("Fonts\\FRIZQT__.TTF", 7)
xMaxLabel:SetPoint("TOPRIGHT", graphArea, "BOTTOMRIGHT", 0, -1)
xMaxLabel:SetJustifyH("RIGHT")
xMaxLabel:SetTextColor(0.6, 0.6, 0.4)

local graphBars = {}
local barWidth = math.ceil(GRAPH_AREA_W / GRAPH_SAMPLES) + 1
for i = 1, GRAPH_SAMPLES do
	graphBars[i] = graphArea:CreateTexture(nil, "ARTWORK")
	graphBars[i]:SetWidth(barWidth)
	graphBars[i]:SetTexture(0.8, 0.65, 0.2, 0.3)
	graphBars[i]:Hide()
end

local graphDots = {}
for i = 1, GRAPH_SAMPLES do
	graphDots[i] = graphArea:CreateTexture(nil, "OVERLAY")
	graphDots[i]:SetWidth(barWidth)
	graphDots[i]:SetHeight(2)
	graphDots[i]:SetTexture(1, 0.82, 0.2, 0.9)
	graphDots[i]:Hide()
end

local graphCursor = graphArea:CreateTexture(nil, "OVERLAY")
graphCursor:SetWidth(1)
graphCursor:SetHeight(GRAPH_H)
graphCursor:SetTexture(1, 1, 1, 0.35)
graphCursor:Hide()

local cursorDot = graphArea:CreateTexture(nil, "OVERLAY")
cursorDot:SetWidth(5)
cursorDot:SetHeight(5)
cursorDot:SetTexture(1, 0.9, 0.4, 1)
cursorDot:Hide()

local cursorRPLabel = graphArea:CreateFontString(nil, "OVERLAY")
cursorRPLabel:SetFont("Fonts\\FRIZQT__.TTF", 8)
cursorRPLabel:SetTextColor(1, 0.9, 0.5)
cursorRPLabel:Hide()

local graphPlayerLine = graphArea:CreateTexture(nil, "ARTWORK")
graphPlayerLine:SetWidth(1)
graphPlayerLine:SetHeight(GRAPH_H)
graphPlayerLine:SetTexture(0.3, 0.8, 1, 0.3)
graphPlayerLine:Hide()

local graphCapLine = graphArea:CreateTexture(nil, "ARTWORK")
graphCapLine:SetWidth(1)
graphCapLine:SetHeight(GRAPH_H)
graphCapLine:SetTexture(0.2, 0.9, 0.3, 0.4)
graphCapLine:Hide()

local graphCapLabel = graphArea:CreateFontString(nil, "OVERLAY")
graphCapLabel:SetFont("Fonts\\FRIZQT__.TTF", 7)
graphCapLabel:SetTextColor(0.3, 0.9, 0.4)
graphCapLabel:Hide()

local function ShowTargetTooltip(owner)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText("Recommended Target (as of today)")
	GameTooltip:AddLine("This is the honor value you should aim for based on", 0.9, 0.9, 0.9)
	GameTooltip:AddLine("current standings. Above this, you earn no extra RP", 0.9, 0.9, 0.9)
	GameTooltip:AddLine("but push others down, hurting your bracket.", 0.9, 0.9, 0.9)
	GameTooltip:AddLine(" ", 0.9, 0.9, 0.9)
	GameTooltip:AddLine("This value changes as other players farm more honor", 0.87, 0.73, 0.27)
	GameTooltip:AddLine("throughout the week. Check back regularly!", 0.87, 0.73, 0.27)
	GameTooltip:Show()
end

local graphCapTooltipBtn = CreateFrame("Button", nil, graphArea)
graphCapTooltipBtn:SetWidth(30)
graphCapTooltipBtn:SetHeight(12)
graphCapTooltipBtn:Hide()
graphCapTooltipBtn:SetScript("OnEnter", function()
	ShowTargetTooltip(this)
end)
graphCapTooltipBtn:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)

local graphCapLineTooltipBtn = CreateFrame("Button", nil, graphArea)
graphCapLineTooltipBtn:SetWidth(12)
graphCapLineTooltipBtn:SetHeight(GRAPH_H)
graphCapLineTooltipBtn:Hide()
graphCapLineTooltipBtn:SetScript("OnEnter", function()
	ShowTargetTooltip(this)
end)
graphCapLineTooltipBtn:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)

-- ===== Calculation Helpers (same as overlay/standings) =====
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

local function FormatNumber(n)
	if n >= 1000000 then
		local m = math.floor(n / 1000000)
		local rest = math.floor((n - m * 1000000) / 1000)
		local last = n - m * 1000000 - rest * 1000
		return m .. "," .. string.format("%03d", rest) .. "," .. string.format("%03d", last)
	elseif n >= 1000 then
		local left = math.floor(n / 1000)
		local right = n - left * 1000
		return left .. "," .. string.format("%03d", right)
	end
	return tostring(n)
end

-- ===== Cached pool data =====
local cachedTable = nil
local cachedBRK = nil
local cachedFX = nil
local cachedPlayerRP = 0
local cachedPlayerRank = 0
local cachedPoolSize = 0
local cachedObservedSize = 0
local cachedBrkAbs = nil
local cachedCapHonor = 0

local function RebuildPoolData()
	if not HonorSpyStandings then return false end
	local ok, t = pcall(function() return HonorSpyStandings:BuildStandingsTable() end)
	if not ok or not t then return false end

	cachedTable = t
	cachedObservedSize = table.getn(t)
	cachedPoolSize = HonorSpyStandings:GetPoolSize(cachedObservedSize)

	-- Build bracket boundaries
	cachedBRK = {}
	for k = 0, 13 do
		cachedBRK[k] = math.floor(brk_pct_0[k] * cachedPoolSize + 0.5)
	end
	cachedBrkAbs = {}
	for k = 1, 14 do
		cachedBrkAbs[k] = cachedBRK[k - 1]
	end

	-- Helper: get CP at standing position
	local function getCP(pos)
		local p = math.min(pos, cachedObservedSize)
		if p >= 1 and t[p] then
			return t[p][3] or 0
		end
		return 0
	end

	-- Build FX array
	cachedFX = {[0] = 0}
	local top = false
	for i = 1, 13 do
		local honor = 0
		local tempHonor = getCP(cachedBRK[i])
		if tempHonor > 0 then
			honor = tempHonor
			tempHonor = getCP(cachedBRK[i] + 1)
			if tempHonor > 0 then
				honor = honor + tempHonor
			end
		end
		if honor > 0 then
			cachedFX[i] = honor / 2
		else
			cachedFX[i] = 0
			if not top then
				cachedFX[i] = (cachedFX[i - 1] > 0) and getCP(1) or 0
				top = true
			end
		end
	end
	cachedFX[14] = (not top) and getCP(1) or 0

	-- Find honor cap (where RP stops increasing)
	cachedCapHonor = 0
	for i = 14, 0, -1 do
		if cachedFX[i] and cachedFX[i] > 0 then
			cachedCapHonor = math.ceil(cachedFX[i])
			break
		end
	end

	-- Find current player
	local pName = UnitName("player")
	cachedPlayerRP = 0
	cachedPlayerRank = 0
	cachedPlayerHonor = 0
	for i = 1, cachedObservedSize do
		if t[i] and t[i][1] == pName then
			cachedPlayerRP = t[i][6]
			cachedPlayerRank = t[i][7]
			cachedPlayerHonor = t[i][3] or 0
			break
		end
	end

	-- Set slider max to top honor * 1.2 or at least 100k
	local maxHonor = getCP(1)
	if maxHonor < 100000 then maxHonor = 100000 end
	maxHonor = math.ceil(maxHonor * 1.2 / 1000) * 1000
	slider:SetMinMaxValues(0, maxHonor)
	getglobal(slider:GetName() .. "High"):SetText(FormatNumber(maxHonor))
	UpdateMarker()

	return true
end

local function CalcRpEarning(cp)
	if not cachedBRK or not cachedFX then return 0 end
	local i = 0
	while i < 14 and cachedBRK[i] and cachedBRK[i] > 0 and cachedFX[i] <= cp do
		i = i + 1
	end
	if i > 0 and cachedFX[i] and cachedFX[i] > cp and cachedFX[i - 1] ~= nil and cp >= cachedFX[i - 1] then
		local denom = cachedFX[i] - cachedFX[i - 1]
		if denom > 0 then
			return (FY[i] - FY[i - 1]) * (cp - cachedFX[i - 1]) / denom + FY[i - 1]
		end
	end
	return FY[i] or 0
end

-- ===== Find standing for a hypothetical honor value =====
local function FindStanding(hypotheticalHonor)
	if not cachedTable then return 0, 1 end
	local standing = cachedPoolSize + 1
	for i = 1, cachedObservedSize do
		if hypotheticalHonor >= (cachedTable[i][3] or 0) then
			standing = i
			break
		end
	end
	-- Determine bracket
	local bracket = 1
	if cachedBrkAbs then
		for b = 2, 14 do
			if standing > cachedBrkAbs[b] then break end
			bracket = b
		end
	end
	return standing, bracket
end

-- ===== Find next bracket threshold (honor needed) =====
local function FindNextBracketHonor(currentBracket)
	if not cachedTable or not cachedBrkAbs then return nil end
	if currentBracket >= 14 then return nil end
	local nextBrk = currentBracket + 1
	local posNeeded = cachedBrkAbs[nextBrk]
	if posNeeded and posNeeded >= 1 and posNeeded <= cachedPoolSize and cachedTable[posNeeded] then
		return cachedTable[posNeeded][3] or 0
	end
	return nil
end

-- ===== Update RP Curve Graph =====
local function UpdateGraph(sliderHonor)
	if not cachedBRK or not cachedFX then
		for i = 1, GRAPH_SAMPLES do
			graphBars[i]:Hide()
			graphDots[i]:Hide()
		end
		graphCursor:Hide()
		cursorDot:Hide()
		cursorRPLabel:Hide()
		graphPlayerLine:Hide()
		graphCapLine:Hide()
		graphCapLabel:Hide()
		graphCapTooltipBtn:Hide()
		graphCapLineTooltipBtn:Hide()
		return
	end

	local sMin, sMax = slider:GetMinMaxValues()
	local range = sMax - sMin
	if range <= 0 then return end

	-- First pass: compute RP values and find max for Y scaling
	local maxRP = 0
	local rpValues = {}
	for i = 1, GRAPH_SAMPLES do
		local honor = sMin + range * (i - 1) / (GRAPH_SAMPLES - 1)
		rpValues[i] = CalcRpEarning(honor)
		if rpValues[i] > maxRP then maxRP = rpValues[i] end
	end
	if maxRP <= 0 then maxRP = 13000 end

	yMaxLabel:SetText(FormatNumber(math.floor(maxRP)))
	xMaxLabel:SetText(FormatNumber(math.floor(sMax)))

	-- Second pass: position bars and curve dots
	for i = 1, GRAPH_SAMPLES do
		local frac = (i - 1) / (GRAPH_SAMPLES - 1)
		local x = frac * GRAPH_AREA_W
		local h = math.max(1, (rpValues[i] / maxRP) * GRAPH_H)

		graphBars[i]:ClearAllPoints()
		graphBars[i]:SetPoint("BOTTOMLEFT", graphArea, "BOTTOMLEFT", x, 0)
		graphBars[i]:SetHeight(h)
		graphBars[i]:Show()

		graphDots[i]:ClearAllPoints()
		graphDots[i]:SetPoint("BOTTOMLEFT", graphArea, "BOTTOMLEFT", x, h - 1)
		graphDots[i]:Show()
	end

	-- Slider cursor vertical line
	local cursorFrac = (sliderHonor - sMin) / range
	if cursorFrac < 0 then cursorFrac = 0 end
	if cursorFrac > 1 then cursorFrac = 1 end
	local cursorX = cursorFrac * GRAPH_AREA_W
	local cursorRP = CalcRpEarning(sliderHonor)
	local cursorY = math.max(1, (cursorRP / maxRP) * GRAPH_H)

	graphCursor:ClearAllPoints()
	graphCursor:SetPoint("BOTTOMLEFT", graphArea, "BOTTOMLEFT", cursorX, 0)
	graphCursor:Show()

	cursorDot:ClearAllPoints()
	cursorDot:SetPoint("CENTER", graphArea, "BOTTOMLEFT", cursorX, cursorY)
	cursorDot:Show()

	cursorRPLabel:SetText(FormatNumber(math.floor(cursorRP)) .. " RP")
	cursorRPLabel:ClearAllPoints()
	if cursorFrac < 0.75 then
		cursorRPLabel:SetPoint("LEFT", cursorDot, "RIGHT", 3, 0)
	else
		cursorRPLabel:SetPoint("RIGHT", cursorDot, "LEFT", -3, 0)
	end
	cursorRPLabel:Show()

	-- Player position marker
	if cachedPlayerHonor > 0 then
		local playerFrac = (cachedPlayerHonor - sMin) / range
		if playerFrac >= 0 and playerFrac <= 1 then
			graphPlayerLine:ClearAllPoints()
			graphPlayerLine:SetPoint("BOTTOMLEFT", graphArea, "BOTTOMLEFT", playerFrac * GRAPH_AREA_W, 0)
			graphPlayerLine:Show()
		else
			graphPlayerLine:Hide()
		end
	else
		graphPlayerLine:Hide()
	end

	-- Recommended target marker
	if cachedCapHonor > 0 then
		local capFrac = (cachedCapHonor - sMin) / range
		if capFrac >= 0 and capFrac <= 1 then
			local capX = capFrac * GRAPH_AREA_W
			graphCapLine:ClearAllPoints()
			graphCapLine:SetPoint("BOTTOMLEFT", graphArea, "BOTTOMLEFT", capX, 0)
			graphCapLine:Show()
			graphCapLabel:ClearAllPoints()
			if capFrac < 0.85 then
				graphCapLabel:SetPoint("BOTTOMLEFT", graphCapLine, "BOTTOMRIGHT", 2, 2)
			else
				graphCapLabel:SetPoint("BOTTOMRIGHT", graphCapLine, "BOTTOMLEFT", -2, 2)
			end
			graphCapLabel:SetText("Target")
			graphCapLabel:Show()
			graphCapTooltipBtn:ClearAllPoints()
			graphCapTooltipBtn:SetAllPoints(graphCapLabel)
			graphCapTooltipBtn:Show()
			graphCapLineTooltipBtn:ClearAllPoints()
			graphCapLineTooltipBtn:SetPoint("BOTTOM", graphArea, "BOTTOMLEFT", capX, 0)
			graphCapLineTooltipBtn:Show()
		else
			graphCapLine:Hide()
			graphCapLabel:Hide()
			graphCapTooltipBtn:Hide()
			graphCapLineTooltipBtn:Hide()
		end
	else
		graphCapLine:Hide()
		graphCapLabel:Hide()
		graphCapTooltipBtn:Hide()
		graphCapLineTooltipBtn:Hide()
	end
end

-- ===== Update Display =====
local function UpdateEstimator(honorValue)
	if not cachedTable then return end

	honorValue = math.floor(honorValue)
	local diffStr = ""
	if cachedPlayerHonor > 0 then
		local diff = honorValue - cachedPlayerHonor
		if diff > 0 then
			diffStr = "  |cff44ddaa(+" .. FormatNumber(diff) .. ")|r"
		elseif diff < 0 then
			diffStr = "  |cffff6666(-" .. FormatNumber(math.abs(diff)) .. ")|r"
		end
	end
	honorLabel:SetText("|cffffffffHonor: " .. FormatNumber(honorValue) .. "|r" .. diffStr)

	local standing, bracket = FindStanding(honorValue)
	standingText:SetText("Standing: |cffffffff#" .. standing .. " / " .. cachedPoolSize .. "|r")
	bracketText:SetText("|cffddbb44Bracket " .. bracket .. "|r")

	-- Current honor display
	if cachedPlayerHonor > 0 then
		yourHonorValue:SetText("|cff55ccff" .. FormatNumber(cachedPlayerHonor) .. "|r")
	else
		yourHonorValue:SetText("|cff888888—|r")
	end

	-- Current rank display
	local rank = cachedPlayerRank
	local RP = cachedPlayerRP
	local curProgress = math.floor((RP - math.floor(RP / 5000) * 5000) / 5000 * 100)
	if rank > 0 then
		curIcon:SetTexture(string.format("Interface\\PvPRankBadges\\PvPRank%02d", rank))
		curIcon:Show()
	else
		curIcon:Hide()
	end
	curRankText:SetText(string.format("Rank %d  %d%%", rank, curProgress))

	-- Projected next week
	local award = CalcRpEarning(honorValue)
	local EstRP = math.floor(CalcRpDecay(award, RP) + 0.5)
	if EstRP < 0 then EstRP = 0 end
	local minRP = 0
	if rank >= 3 then minRP = (rank - 2) * 5000
	elseif rank == 2 then minRP = 2000 end
	if EstRP < minRP then EstRP = minRP end

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
		nextIcon:Show()
	else
		nextIcon:Hide()
	end

	local rankDiff = EstRank - rank
	local nextColor = "ffffff"
	if rankDiff > 0 then nextColor = "44ddaa"
	elseif EstRP > RP then nextColor = "88cc88"
	elseif EstRP < RP then nextColor = "ff6666"
	else nextColor = "ddbb44" end
	nextRankText:SetText(string.format("|cff%sRank %d  %d%%|r", nextColor, EstRank, EstProgress))

	-- Delta
	local weekRP = EstRP - RP
	if weekRP >= 0 then
		deltaText:SetText(string.format("|cff44ddaa+%d RP|r", weekRP))
	else
		deltaText:SetText(string.format("|cffff6666%d RP|r", weekRP))
	end

	-- Next bracket hint
	local nextBrkHonor = FindNextBracketHonor(bracket)
	if nextBrkHonor and honorValue < nextBrkHonor then
		hintText:SetText(string.format("Bracket %d needs %s honor", bracket + 1, FormatNumber(math.floor(nextBrkHonor) + 1)))
	elseif bracket >= 14 then
		hintText:SetText("|cff44ddaaYou are in the highest bracket|r")
	else
		hintText:SetText("")
	end

	-- Wasted honor indicator
	if cachedCapHonor > 0 and honorValue > cachedCapHonor then
		local wasted = honorValue - cachedCapHonor
		wasteText:SetText("|cffff6666+" .. FormatNumber(wasted) .. " over recommended target|r — coordinate with bracket")

		-- Compute total RP damage to others from the gap you create.
		-- Everyone between your cap standing and your ego standing gets pushed
		-- down 1 position. For each, recalc their bracket before/after and sum
		-- the RP difference.
		local pName = UnitName("player")
		local totalRPLoss = 0
		local affectedCount = 0

		-- Build a temporary honor list as if player had capHonor (optimal)
		-- vs honorValue (ego). Players between cap..ego in honor get shifted.
		for i = 1, cachedObservedSize do
			local row = cachedTable[i]
			if row and row[1] ~= pName then
				local h = row[3] or 0
				-- This player's position stays the same in both scenarios
				-- UNLESS player's honor value pushes them down.
				-- In the "cap" scenario the player sits at capHonor; in the
				-- "ego" scenario at honorValue. Anyone with honor between
				-- those two values loses one standing position.
				if h >= cachedCapHonor and h < honorValue then
					-- This player's standing shifts by +1 (worse)
					-- Check their bracket at current pos vs pos+1
					local oldBracket = 1
					local newBracket = 1
					if cachedBrkAbs then
						for b = 2, 14 do
							if i > cachedBrkAbs[b] then break end
							oldBracket = b
						end
						for b = 2, 14 do
							if (i + 1) > cachedBrkAbs[b] then break end
							newBracket = b
						end
					end
					if newBracket < oldBracket then
						local rpBefore = FY[oldBracket] or 0
						local rpAfter = FY[newBracket] or 0
						totalRPLoss = totalRPLoss + (rpBefore - rpAfter)
						affectedCount = affectedCount + 1
					end
				end
			end
		end

		if totalRPLoss > 0 then
			impactText:SetText(string.format("|cffff8888This costs %d player%s a total of %s RP.|r",
				affectedCount, affectedCount == 1 and "" or "s",
				FormatNumber(totalRPLoss)))
		else
			impactText:SetText("|cffff6666Extra honor spreads the bracket and lowers RP for others.|r")
		end
	else
		if bracket >= 14 then
			wasteText:SetText("|cff44ddaaStay close to bracket members to maximize gains|r")
		else
			wasteText:SetText("")
		end
		impactText:SetText("")
	end

	UpdateGraph(honorValue)
end

-- ===== Reset Button (declared early so OnValueChanged can reference it) =====
local resetBtn = CreateFrame("Button", nil, Frame)
resetBtn:SetWidth(40)
resetBtn:SetHeight(14)
resetBtn:SetPoint("LEFT", honorLabel, "RIGHT", 6, 0)

local resetText = resetBtn:CreateFontString(nil, "OVERLAY")
resetText:SetFont("Fonts\\FRIZQT__.TTF", 8)
resetText:SetPoint("CENTER", resetBtn, "CENTER", 0, 0)
resetText:SetText("|cff88ccff[Reset]|r")
resetBtn:Hide()

-- ===== Slider Script =====
slider:SetScript("OnValueChanged", function()
	local val = math.floor(this:GetValue() / 1000 + 0.5) * 1000
	UpdateEstimator(val)
	if val ~= cachedPlayerHonor then
		resetBtn:Show()
	else
		resetBtn:Hide()
	end
end)

resetBtn:SetScript("OnClick", function()
	if cachedTable then
		slider:SetValue(cachedPlayerHonor)
		UpdateEstimator(cachedPlayerHonor)
		resetBtn:Hide()
	end
end)
resetBtn:SetScript("OnEnter", function()
	resetText:SetText("|cffaaddff[Reset]|r")
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
	GameTooltip:SetText("Reset to your current honor")
	GameTooltip:Show()
end)
resetBtn:SetScript("OnLeave", function()
	resetText:SetText("|cff88ccff[Reset]|r")
	GameTooltip:Hide()
end)

-- ===== Toggle Function =====
function HonorSpyEstimator_Toggle()
	if THSE_Blacklisted then return end
	if Frame:IsVisible() then
		Frame:Hide()
	else
		if RebuildPoolData() then
			-- Default slider to player's current honor
			local pName = UnitName("player")
			local curHonor = 0
			if cachedTable then
				for i = 1, cachedObservedSize do
					if cachedTable[i] and cachedTable[i][1] == pName then
						curHonor = cachedTable[i][3] or 0
						break
					end
				end
			end
			slider:SetValue(curHonor)
			UpdateEstimator(curHonor)
			resetBtn:Hide()
			Frame:Show()
		end
	end
end

function HonorSpyEstimator_Refresh()
	if Frame:IsVisible() then
		if RebuildPoolData() then
			UpdateEstimator(slider:GetValue())
		end
	end
end
