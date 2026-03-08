-- HonorSpy Overlay: compact rank/honor widget
-- Uses data from TurtleHonorSpyEnhanced standings

local playerName = nil
local PAD = 8
local INNER_W = 194

-- ===== Frame Setup =====
local Frame = CreateFrame("Frame", "HonorSpyOverlayFrame", UIParent)
Frame:SetWidth(210)
Frame:SetHeight(150)
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
	if HonorSpyPoolPanel then HonorSpyPoolPanel:Hide() end
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

local btnPool = CreateFrame("Button", nil, Frame)
btnPool:SetWidth(16)
btnPool:SetHeight(13)
btnPool:SetPoint("RIGHT", btnTable, "LEFT", -3, 0)
local btnPoolFS = btnPool:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
btnPoolFS:SetAllPoints()
btnPoolFS:SetJustifyH("CENTER")
btnPoolFS:SetText("%")
btnPoolFS:SetTextColor(0.55, 0.55, 0.55)

-- ===== Pool Correction Panel =====
local ppFactorEB, ppToggleFS  -- forward declare for closures

local function ApplyPoolFactor()
	local hs = HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
	if not hs then return end
	local val = tonumber(ppFactorEB:GetText()) or 15
	val = math.floor(math.max(1, math.min(200, val)))
	hs.poolFactor = val
	ppFactorEB:SetText(tostring(val))
	if HonorSpyStandings then HonorSpyStandings:RenderStandings() end
	if HonorSpyOverlay_Refresh then HonorSpyOverlay_Refresh() end
	if HonorSpyEstimator_Refresh then HonorSpyEstimator_Refresh() end
end

local function PoolRefreshAll()
	if HonorSpyStandings then HonorSpyStandings:RenderStandings() end
	if HonorSpyOverlay_Refresh then HonorSpyOverlay_Refresh() end
	if HonorSpyEstimator_Refresh then HonorSpyEstimator_Refresh() end
end

function HonorSpyPoolPanel_Update()
	local hs = HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
	if not (hs and ppSwitchDot and ppFactorEB) then return end
	if hs.poolCorrection then
		ppSwitchDot:SetTexture(0.2, 0.9, 0.3, 1)
		ppSwitchLabel:SetText("ON")
		ppSwitchLabel:SetTextColor(0.2, 0.9, 0.3)
		btnPoolFS:SetTextColor(0.2, 1.0, 0.2)
	else
		ppSwitchDot:SetTexture(0.5, 0.5, 0.5, 1)
		ppSwitchLabel:SetText("OFF")
		ppSwitchLabel:SetTextColor(0.5, 0.5, 0.5)
		btnPoolFS:SetTextColor(0.55, 0.55, 0.55)
	end
	ppFactorEB:SetText(tostring(hs.poolFactor or 15))
end

local poolPanel = CreateFrame("Frame", "HonorSpyPoolPanel", UIParent)
poolPanel:SetWidth(210)
poolPanel:SetHeight(170)
poolPanel:SetFrameStrata("DIALOG")
poolPanel:SetClampedToScreen(true)
poolPanel:SetBackdrop({
	bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
poolPanel:SetBackdropColor(0, 0, 0, 0.92)
poolPanel:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
poolPanel:SetPoint("TOPLEFT", Frame, "BOTTOMLEFT", 0, -2)
poolPanel:Hide()

-- Header: close button
local ppClose = CreateFrame("Button", nil, poolPanel, "UIPanelCloseButton")
ppClose:SetWidth(20)
ppClose:SetHeight(20)
ppClose:SetPoint("TOPRIGHT", poolPanel, "TOPRIGHT", -2, -2)
ppClose:SetScript("OnClick", function() poolPanel:Hide() end)

-- Header: title (as a button for hover tooltip)
local ppTitleBtn = CreateFrame("Button", nil, poolPanel)
ppTitleBtn:SetWidth(90)
ppTitleBtn:SetHeight(14)
ppTitleBtn:SetPoint("TOPLEFT", poolPanel, "TOPLEFT", 8, -8)
local ppTitle = ppTitleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ppTitle:SetAllPoints()
ppTitle:SetJustifyH("LEFT")
ppTitle:SetText("Pool Correction")
ppTitle:SetTextColor(1, 0.82, 0)
ppTitleBtn:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
	GameTooltip:SetText("Pool Correction")
	GameTooltip:AddLine("The addon only knows players it has", 0.7, 0.7, 0.7)
	GameTooltip:AddLine("personally seen. Anyone who never", 0.7, 0.7, 0.7)
	GameTooltip:AddLine("crossed paths with an addon user is", 0.7, 0.7, 0.7)
	GameTooltip:AddLine("missing, so the true pool is larger.", 0.7, 0.7, 0.7)
	GameTooltip:AddLine("This correction adds them back in.", 0.7, 0.7, 0.7)
	GameTooltip:AddLine(" ", 0.7, 0.7, 0.7)
	GameTooltip:AddLine("Example: a lvl 30 gets one kill in a", 0.55, 0.55, 0.55)
	GameTooltip:AddLine("BG with no addon users and leaves.", 0.55, 0.55, 0.55)
	GameTooltip:AddLine("He counts in the weekly pool but is", 0.55, 0.55, 0.55)
	GameTooltip:AddLine("completely invisible to this addon.", 0.55, 0.55, 0.55)
	GameTooltip:Show()
end)
ppTitleBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Header: toggle beside title
local ppToggle = CreateFrame("Button", nil, poolPanel)
ppToggle:SetWidth(28)
ppToggle:SetHeight(14)
ppToggle:SetPoint("LEFT", ppTitleBtn, "RIGHT", 4, 0)

ppSwitchDot = ppToggle:CreateTexture(nil, "OVERLAY")
ppSwitchDot:SetWidth(6)
ppSwitchDot:SetHeight(6)
ppSwitchDot:SetTexture("Interface\\BUTTONS\\WHITE8X8")
ppSwitchDot:SetPoint("LEFT", ppToggle, "LEFT", 0, 0)

ppSwitchLabel = ppToggle:CreateFontString(nil, "OVERLAY")
ppSwitchLabel:SetFont("Fonts\\FRIZQT__.TTF", 9)
ppSwitchLabel:SetPoint("LEFT", ppSwitchDot, "RIGHT", 3, 0)

ppToggle:SetScript("OnEnter", function()
	local hs = HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
	if hs and hs.poolCorrection then
		ppSwitchLabel:SetTextColor(0.4, 1.0, 0.5)
		ppSwitchDot:SetTexture(0.4, 1.0, 0.5, 1)
	else
		ppSwitchLabel:SetTextColor(0.8, 0.8, 0.8)
		ppSwitchDot:SetTexture(0.8, 0.8, 0.8, 1)
	end
end)
ppToggle:SetScript("OnLeave", function()
	HonorSpyPoolPanel_Update()
end)

ppToggle:SetScript("OnClick", function()
	local hs = HonorSpy.db.realm.hs
	hs.poolCorrection = not hs.poolCorrection
	HonorSpyPoolPanel_Update()
	PoolRefreshAll()
end)

-- Separator line
local ppSep = poolPanel:CreateTexture(nil, "ARTWORK")
ppSep:SetHeight(1)
ppSep:SetPoint("TOPLEFT",  poolPanel, "TOPLEFT",  6, -22)
ppSep:SetPoint("TOPRIGHT", poolPanel, "TOPRIGHT", -6, -22)
ppSep:SetTexture(0.4, 0.4, 0.4, 0.8)

-- Description text
local ppDesc = poolPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ppDesc:SetPoint("TOPLEFT",  poolPanel, "TOPLEFT",  8, -28)
ppDesc:SetPoint("TOPRIGHT", poolPanel, "TOPRIGHT", -8, -28)
ppDesc:SetJustifyH("LEFT")
ppDesc:SetTextColor(0.75, 0.75, 0.75)
ppDesc:SetText("|cffddaa44Recommended Value: 15%|r\n" ..
	"Based on data from previous weeks,\n" ..
	"15% is a proven safe factor to use.\n" ..
	"Your actual RP earned will be at\n" ..
	"least as high as the estimate shows.\n\n" ..
	"|cffff6633Caution above 20%|r\n" ..
	"The bracket boundaries shift further\n" ..
	"than the real data supports. You may\n" ..
	"end up with less progress than\n" ..
	"calculated from the addon.")

-- Second separator
local ppSep2 = poolPanel:CreateTexture(nil, "ARTWORK")
ppSep2:SetHeight(1)
ppSep2:SetPoint("TOPLEFT",  poolPanel, "TOPLEFT",  6, -140)
ppSep2:SetPoint("TOPRIGHT", poolPanel, "TOPRIGHT", -6, -140)
ppSep2:SetTexture(0.4, 0.4, 0.4, 0.8)

-- Controls row: Extra [-] [n] [+] %
local ppLabel = poolPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ppLabel:SetPoint("BOTTOMLEFT", poolPanel, "BOTTOMLEFT", 8, 12)
ppLabel:SetText("Correction:")
ppLabel:SetTextColor(0.7, 0.7, 0.7)

local ppMinus = CreateFrame("Button", nil, poolPanel, "UIPanelButtonTemplate")
ppMinus:SetWidth(20)
ppMinus:SetHeight(20)
ppMinus:SetPoint("LEFT", ppLabel, "RIGHT", 4, 0)
ppMinus:SetText("-")
ppMinus:SetScript("OnClick", function()
	local hs = HonorSpy.db.realm.hs
	hs.poolFactor = math.max(1, (hs.poolFactor or 15) - 1)
	HonorSpyPoolPanel_Update()
	PoolRefreshAll()
end)


ppFactorEB = CreateFrame("EditBox", "HonorSpyPoolFactorEB", poolPanel, "InputBoxTemplate")
ppFactorEB:SetWidth(34)
ppFactorEB:SetHeight(14)
ppFactorEB:SetPoint("LEFT", ppMinus, "RIGHT", 2, 0)
ppFactorEB:SetAutoFocus(false)
ppFactorEB:SetNumeric(true)
ppFactorEB:SetMaxLetters(3)
ppFactorEB:SetJustifyH("CENTER")
ppFactorEB:SetScript("OnEnterPressed", function() ApplyPoolFactor(); ppFactorEB:ClearFocus() end)
ppFactorEB:SetScript("OnEditFocusLost", ApplyPoolFactor)
ppFactorEB:SetScript("OnEscapePressed", function() ppFactorEB:ClearFocus() end)

local ppPlus = CreateFrame("Button", nil, poolPanel, "UIPanelButtonTemplate")
ppPlus:SetWidth(20)
ppPlus:SetHeight(20)
ppPlus:SetPoint("LEFT", ppFactorEB, "RIGHT", 2, 0)
ppPlus:SetText("+")
ppPlus:SetScript("OnClick", function()
	local hs = HonorSpy.db.realm.hs
	hs.poolFactor = math.min(200, (hs.poolFactor or 15) + 1)
	HonorSpyPoolPanel_Update()
	PoolRefreshAll()
end)


local ppPctLabel = poolPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ppPctLabel:SetPoint("LEFT", ppPlus, "RIGHT", 2, 0)
ppPctLabel:SetText("%")
ppPctLabel:SetTextColor(0.7, 0.7, 0.7)

-- Tooltip on editbox
ppFactorEB:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
	GameTooltip:SetText("Hidden player estimate (%)")
	GameTooltip:AddLine("Percentage of extra players to add to", 0.7, 0.7, 0.7)
	GameTooltip:AddLine("the pool. 15 means the real pool is", 0.7, 0.7, 0.7)
	GameTooltip:AddLine("assumed to be 15% larger than observed.", 0.7, 0.7, 0.7)
	GameTooltip:AddLine("Type a number and press Enter to apply.", 0.7, 0.7, 0.7)
	GameTooltip:Show()
end)
ppFactorEB:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Tooltip on the % header button
btnPool:SetScript("OnEnter", function()
	local hs = HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
	if hs and hs.poolCorrection then
		btnPoolFS:SetTextColor(0.4, 1.0, 0.4)
	else
		btnPoolFS:SetTextColor(0.8, 0.8, 0.8)
	end
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:SetText("Pool Correction")
	GameTooltip:AddLine("The addon only knows players it has", 0.7, 0.7, 0.7)
	GameTooltip:AddLine("personally seen. Anyone who never", 0.7, 0.7, 0.7)
	GameTooltip:AddLine("crossed paths with an addon user is", 0.7, 0.7, 0.7)
	GameTooltip:AddLine("missing, so the true pool is larger.", 0.7, 0.7, 0.7)
	GameTooltip:AddLine("This correction adds them back in.", 0.7, 0.7, 0.7)
	GameTooltip:AddLine(" ", 0.7, 0.7, 0.7)
	GameTooltip:AddLine("Example: a lvl 30 gets one kill in a", 0.55, 0.55, 0.55)
	GameTooltip:AddLine("BG with no addon users and leaves.", 0.55, 0.55, 0.55)
	GameTooltip:AddLine("He counts in the weekly pool but is", 0.55, 0.55, 0.55)
	GameTooltip:AddLine("completely invisible to this addon.", 0.55, 0.55, 0.55)
	GameTooltip:AddLine(" ", 0.7, 0.7, 0.7)
	GameTooltip:AddLine("|cffaaaaaaLeft-click|r to open settings.", 0.7, 0.7, 0.7)
	GameTooltip:AddLine("|cffaaaaaaRight-click|r to toggle on/off.", 0.7, 0.7, 0.7)
	GameTooltip:Show()
end)
btnPool:SetScript("OnLeave", function()
	local hs = HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
	if hs and hs.poolCorrection then
		btnPoolFS:SetTextColor(0.2, 1.0, 0.2)
	else
		btnPoolFS:SetTextColor(0.55, 0.55, 0.55)
	end
	GameTooltip:Hide()
end)

btnPool:RegisterForClicks("LeftButtonUp", "RightButtonUp")
btnPool:SetScript("OnClick", function()
	if arg1 == "RightButton" then
		local hs = HonorSpy.db.realm.hs
		hs.poolCorrection = not hs.poolCorrection
		HonorSpyPoolPanel_Update()
		PoolRefreshAll()
	else
		if poolPanel:IsVisible() then
			poolPanel:Hide()
		else
			HonorSpyPoolPanel_Update()
			poolPanel:Show()
		end
	end
end)

-- ===== Section 1: Current Rank =====
local rankIcon = Frame:CreateTexture(nil, "ARTWORK")
rankIcon:SetWidth(26)
rankIcon:SetHeight(26)
rankIcon:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -26)

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
barBg:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -58)

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
div1:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -72)

-- ===== Section 2: This Week Stats (two columns) =====
local honorLeft = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
honorLeft:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -77)
honorLeft:SetJustifyH("LEFT")
honorLeft:SetTextColor(0.7, 0.7, 0.7)

local honorRight = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
honorRight:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -PAD, -77)
honorRight:SetJustifyH("RIGHT")
honorRight:SetTextColor(0.87, 0.73, 0.27)

local standLeft = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
standLeft:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -89)
standLeft:SetJustifyH("LEFT")
standLeft:SetTextColor(0.7, 0.7, 0.7)

local standRight = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
standRight:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -PAD, -89)
standRight:SetJustifyH("RIGHT")
standRight:SetTextColor(1, 1, 1)

-- ===== Divider 2 =====
local div2 = Frame:CreateTexture(nil, "ARTWORK")
div2:SetTexture(1, 1, 1, 0.15)
div2:SetWidth(INNER_W)
div2:SetHeight(1)
div2:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -102)

-- ===== Section 3: Next Week Estimate =====
local nextWeekLabel = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nextWeekLabel:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -106)
nextWeekLabel:SetJustifyH("LEFT")
nextWeekLabel:SetTextColor(0.7, 0.7, 0.7)
nextWeekLabel:SetText("Next Week:")

local nextIcon = Frame:CreateTexture(nil, "ARTWORK")
nextIcon:SetWidth(20)
nextIcon:SetHeight(20)
nextIcon:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -118)

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
netRPLabel:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -PAD, -118)
netRPLabel:SetJustifyH("RIGHT")

local nextRPRight = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nextRPRight:SetPoint("TOPRIGHT", netRPLabel, "BOTTOMRIGHT", 0, -1)
nextRPRight:SetJustifyH("RIGHT")
nextRPRight:SetTextColor(0.87, 0.73, 0.27)

-- ===== Header Bar =====
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
local tocVer = GetAddOnMetadata("TurtleHonorSpyEnhanced", "Version") or ""
versionFooter:SetText("v" .. tocVer)
Frame.versionFooter = versionFooter

-- ===== Overshoot Warning =====
local overshootDiv = Frame:CreateTexture(nil, "ARTWORK")
overshootDiv:SetTexture(1, 1, 1, 0.15)
overshootDiv:SetWidth(INNER_W)
overshootDiv:SetHeight(1)
overshootDiv:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -150)
overshootDiv:Hide()

local overshootBtn = CreateFrame("Button", nil, Frame)
overshootBtn:SetWidth(INNER_W)
overshootBtn:SetHeight(24)
overshootBtn:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -157)
overshootBtn:Hide()

local overshootIcon = overshootBtn:CreateTexture(nil, "ARTWORK")
overshootIcon:SetWidth(20)
overshootIcon:SetHeight(20)
overshootIcon:SetPoint("TOPLEFT", overshootBtn, "TOPLEFT", 0, 0)
overshootIcon:SetTexture("Interface\\Icons\\Ability_Creature_Cursed_02")
overshootIcon:SetVertexColor(1, 1, 1)

local overshootText = overshootBtn:CreateFontString(nil, "OVERLAY")
overshootText:SetFont("Fonts\\FRIZQT__.TTF", 8)
overshootText:SetPoint("TOPLEFT", overshootBtn, "TOPLEFT", 23, -1)
overshootText:SetPoint("RIGHT", overshootBtn, "RIGHT", -6, 0)
overshootText:SetJustifyH("LEFT")
overshootText:SetTextColor(1, 0.3, 0.3)
overshootText:SetText("You might be farming too much honor!")

local overshootSubText = overshootBtn:CreateFontString(nil, "OVERLAY")
overshootSubText:SetFont("Fonts\\FRIZQT__.TTF", 8)
overshootSubText:SetPoint("TOPLEFT", overshootText, "BOTTOMLEFT", 0, -1)
overshootSubText:SetPoint("RIGHT", overshootBtn, "RIGHT", -6, 0)
overshootSubText:SetJustifyH("LEFT")
overshootSubText:SetTextColor(0.53, 0.8, 1)
overshootSubText:SetText("[More Info]")

local overshootState = { excess = 0, target = 0, daysLeft = 0, b14Players = {} }

-- Debug: set via /hsver honor N to simulate a different thisWeekHonor
HonorSpyDebugHonorOverride = nil

overshootBtn:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
	GameTooltip:ClearLines()
	GameTooltip:AddLine("Above Recommended Target", 1, 0.3, 0.2)
	GameTooltip:AddLine(" ", 1, 1, 1)
	GameTooltip:AddLine("The recommended target is the honor amount", 0.9, 0.9, 0.9)
	GameTooltip:AddLine("that lets other bracket 14 players catch up", 0.9, 0.9, 0.9)
	GameTooltip:AddLine("to you. When everyone is closer in honor,", 0.9, 0.9, 0.9)
	GameTooltip:AddLine("you all earn more rank points (up to 13,000", 0.9, 0.9, 0.9)
	GameTooltip:AddLine("RP each). Consider slowing down at this", 0.9, 0.9, 0.9)
	GameTooltip:AddLine("point to let others catch up.", 0.9, 0.9, 0.9)
	GameTooltip:AddLine(" ", 1, 1, 1)
	GameTooltip:AddLine("This target moves as more players farm", 0.87, 0.73, 0.27)
	GameTooltip:AddLine("honor throughout the week. Check back", 0.87, 0.73, 0.27)
	GameTooltip:AddLine("regularly until the weekly reset.", 0.87, 0.73, 0.27)
	if overshootState.excess > 0 then
		local myHonorTotal = overshootState.excess + overshootState.target
		GameTooltip:AddLine(" ", 1, 1, 1)
		GameTooltip:AddDoubleLine("Your honor:",   string.format("%d", myHonorTotal),   0.7, 0.7, 0.7, 1, 0.4, 0.4)
		GameTooltip:AddDoubleLine("Recommended target:",  string.format("%d", overshootState.target), 0.7, 0.7, 0.7, 1, 1, 1)
		GameTooltip:AddDoubleLine("Ahead by:",     string.format("+%d", overshootState.excess), 0.7, 0.7, 0.7, 1, 0.5, 0.5)
		GameTooltip:AddDoubleLine("Days to reset:", string.format("%.1f", overshootState.daysLeft), 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
	end
	GameTooltip:Show()
end)
overshootBtn:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)

Frame.overshootDiv = overshootDiv
Frame.overshootBtn = overshootBtn
Frame.overshootText = overshootText

-- ===== Flagged Player Warning =====
local flaggedDiv = Frame:CreateTexture(nil, "ARTWORK")
flaggedDiv:SetTexture(1, 1, 1, 0.15)
flaggedDiv:SetWidth(INNER_W)
flaggedDiv:SetHeight(1)
flaggedDiv:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -150)
flaggedDiv:Hide()

local flaggedBtn = CreateFrame("Button", nil, Frame)
flaggedBtn:SetWidth(INNER_W)
flaggedBtn:SetHeight(24)
flaggedBtn:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -157)
flaggedBtn:Hide()

local flaggedIcon = flaggedBtn:CreateTexture(nil, "ARTWORK")
flaggedIcon:SetWidth(20)
flaggedIcon:SetHeight(20)
flaggedIcon:SetPoint("TOPLEFT", flaggedBtn, "TOPLEFT", 0, 0)
flaggedIcon:SetTexture("Interface\\Icons\\Ability_Creature_Cursed_02")
flaggedIcon:SetVertexColor(1, 0.3, 0.3)

local flaggedText = flaggedBtn:CreateFontString(nil, "OVERLAY")
flaggedText:SetFont("Fonts\\FRIZQT__.TTF", 8)
flaggedText:SetPoint("TOPLEFT", flaggedBtn, "TOPLEFT", 23, -1)
flaggedText:SetPoint("RIGHT", flaggedBtn, "RIGHT", -6, 0)
flaggedText:SetJustifyH("LEFT")
flaggedText:SetTextColor(1, 0.3, 0.3)
flaggedText:SetText("You are flagged for not coordinating")

local flaggedSubText = flaggedBtn:CreateFontString(nil, "OVERLAY")
flaggedSubText:SetFont("Fonts\\FRIZQT__.TTF", 8)
flaggedSubText:SetPoint("TOPLEFT", flaggedText, "BOTTOMLEFT", 0, -1)
flaggedSubText:SetPoint("RIGHT", flaggedBtn, "RIGHT", -6, 0)
flaggedSubText:SetJustifyH("LEFT")
flaggedSubText:SetTextColor(1, 0.3, 0.3)
flaggedSubText:SetText("Bracket 14 targets. |cff87ccff[More Info]|r")

flaggedBtn:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
	GameTooltip:ClearLines()
	GameTooltip:AddLine("Flagged Player", 1, 0.3, 0.2)
	GameTooltip:AddLine(" ", 1, 1, 1)
	GameTooltip:AddLine("You have been flagged for refusing to coordinate", 0.9, 0.9, 0.9)
	GameTooltip:AddLine("Bracket 14 honor targets.", 0.9, 0.9, 0.9)
	GameTooltip:AddLine(" ", 1, 1, 1)
	GameTooltip:AddLine("Each week the PvP system awards rank points (RP) based", 0.6, 0.6, 0.6)
	GameTooltip:AddLine("on your standing. The highest bracket (Bracket 14) is", 0.6, 0.6, 0.6)
	GameTooltip:AddLine("shared by a handful of players. How much RP each", 0.6, 0.6, 0.6)
	GameTooltip:AddLine("of them earns depends on how close their honor totals", 0.6, 0.6, 0.6)
	GameTooltip:AddLine("are to each other.", 0.6, 0.6, 0.6)
	GameTooltip:AddLine(" ", 1, 1, 1)
	GameTooltip:AddLine("When one person farms far beyond the group, everyone", 0.6, 0.6, 0.6)
	GameTooltip:AddLine("else in the bracket loses hundreds of RP that week,", 0.6, 0.6, 0.6)
	GameTooltip:AddLine("while the person ahead gains no additional progress.", 0.6, 0.6, 0.6)
	GameTooltip:AddLine("For players pushing Rank 12, 13, or 14, that can set", 0.6, 0.6, 0.6)
	GameTooltip:AddLine("them back by weeks. To avoid this, Bracket 14 players", 0.6, 0.6, 0.6)
	GameTooltip:AddLine("agree on a shared honor target and stop farming once", 0.6, 0.6, 0.6)
	GameTooltip:AddLine("they reach it.", 0.6, 0.6, 0.6)
	GameTooltip:AddLine(" ", 1, 1, 1)
	GameTooltip:AddLine("If you agree to align on a shared target,", 0.87, 0.73, 0.27)
	GameTooltip:AddLine("the flag will be removed.", 0.87, 0.73, 0.27)
	GameTooltip:Show()
end)
flaggedBtn:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)

Frame.flaggedDiv = flaggedDiv
Frame.flaggedBtn = flaggedBtn

local FRAME_H_NORMAL = 150
local FRAME_H_WARN   = 190
local FRAME_H_EXTRA  = 40

-- Safe target: median × time-scaled buffer (tightens as reset approaches).
local OVERSHOOT = {}

-- Fractional days until the next PVP reset (0 = imminent, ~7 = just reset).
function OVERSHOOT.GetDaysUntilReset()
	local hs = HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
	local reset_day = (hs and hs.reset_day) or 3
	local day = tonumber(date("!%w"))
	local h   = tonumber(date("!%H"))
	local m   = tonumber(date("!%M"))
	local raw = 7 + reset_day - day
	local daysUntil = raw - math.floor(raw / 7) * 7
	if daysUntil == 0 then daysUntil = 7 end
	return daysUntil - (h * 60 + m - 15) / 1440
end

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
	local observed  = table.getn(t)
	local pool_size = HonorSpyStandings:GetPoolSize(observed)

	-- Build bracket boundaries
	local BRK = {}
	for k = 0, 13 do
		BRK[k] = math.floor(brk_pct_0[k] * pool_size + 0.5)
	end

	-- Helper: get CP at standing position
	local function getCP(pos)
		local p = math.min(pos, observed)
		if p >= 1 and t[p] then
			return t[p][3] or 0
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
	for i = 1, observed do
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
	if HonorSpyDebugHonorOverride then thisWeekHonor = HonorSpyDebugHonorOverride end

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
	local poolTag = ""
	if HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
	   and HonorSpy.db.realm.hs.poolCorrection then
		poolTag = " |cff22dd22*|r"
	end
	standLeft:SetText("Standing  |cffffffff#" .. myStanding .. " / " .. pool_size .. "|r" .. poolTag)
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

	-- === B14 Overshoot Warning ===
	local b14_slots = BRK[13]
	local isOver = false
	if myBracket == 14 and b14_slots >= 3 and b14_slots < pool_size then
		-- Collect B14 honor values and compute median
		local honorList = {}
		for j = 1, b14_slots do
			if t[j] then table.insert(honorList, t[j][3] or 0) end
		end
		table.sort(honorList, function(a, b) return a < b end)
		local n = table.getn(honorList)
		local b14_median = 0
		if n > 0 then
			if math.mod(n, 2) == 1 then
				b14_median = honorList[math.ceil(n / 2)]
			else
				b14_median = math.floor((honorList[n / 2] + honorList[n / 2 + 1]) / 2 + 0.5)
			end
		end
		if b14_median >= 50000 then
			local daysOk, daysLeft = pcall(OVERSHOOT.GetDaysUntilReset)
			if not daysOk or type(daysLeft) ~= "number" then daysLeft = 1 end
			local buffer = 1.05 + 0.15 * (daysLeft / 7)
			local safeTarget = math.floor(b14_median * buffer / 1000 + 0.5) * 1000
			if thisWeekHonor > safeTarget then
				isOver = true
				overshootState.excess = thisWeekHonor - safeTarget
				overshootState.target = safeTarget
				overshootState.daysLeft = daysLeft

				-- Collect other B14 players
				overshootState.b14Players = {}
				for j = 1, b14_slots do
					if t[j] and t[j][1] ~= playerName then
						table.insert(overshootState.b14Players, {
							name  = t[j][1],
							honor = t[j][3] or 0,
							award = math.floor(CalcRpEarning(t[j][3] or 0) + 0.5),
						})
					end
				end
			end
		end
	end
	if isOver then
		overshootDiv:Show()
		overshootBtn:Show()
	else
		overshootDiv:Hide()
		overshootBtn:Hide()
	end

	-- === Flagged Player Warning ===
	local isFlagged = THSE_FlaggedHashes and THSE_Hash and THSE_FlaggedHashes[THSE_Hash(playerName)] or false
	local frameH = FRAME_H_NORMAL
	if isOver then frameH = FRAME_H_WARN end
	if isFlagged then
		local yOff = isOver and -190 or -150
		flaggedDiv:ClearAllPoints()
		flaggedDiv:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, yOff)
		flaggedBtn:ClearAllPoints()
		flaggedBtn:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, yOff - 7)
		flaggedDiv:Show()
		flaggedBtn:Show()
		frameH = frameH + FRAME_H_EXTRA
	else
		flaggedDiv:Hide()
		flaggedBtn:Hide()
	end
	Frame:SetHeight(frameH)
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
		HonorSpyPoolPanel_Update()

		-- Show What's New popup once
		local hs = HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
		if hs and not hs.whatsNewSeen and HonorSpyWhatsNewFrame then
			HonorSpyWhatsNewFrame:Show()
		end
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

-- ===== What's New Popup =====
local wnf = CreateFrame("Frame", "HonorSpyWhatsNewFrame", UIParent)
wnf:SetWidth(420)
wnf:SetHeight(340)
wnf:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
wnf:SetFrameStrata("FULLSCREEN_DIALOG")
wnf:SetMovable(true)
wnf:EnableMouse(true)
wnf:RegisterForDrag("LeftButton")
wnf:SetScript("OnDragStart", function() this:StartMoving() end)
wnf:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
wnf:SetBackdrop({
	bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
wnf:SetBackdropColor(0, 0, 0, 0.92)
wnf:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
wnf:Hide()

local wnTitle = wnf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
wnTitle:SetPoint("TOP", wnf, "TOP", 0, -12)
wnTitle:SetText("|cffFFD100TurtleHonorSpyEnhanced — What's New|r")

local wnClose = CreateFrame("Button", nil, wnf, "UIPanelCloseButton")
wnClose:SetWidth(24)
wnClose:SetHeight(24)
wnClose:SetPoint("TOPRIGHT", wnf, "TOPRIGHT", -2, -2)
wnClose:SetScript("OnClick", function()
	wnf:Hide()
	local hs = HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
	if hs then hs.whatsNewSeen = true end
end)

local wnSep = wnf:CreateTexture(nil, "ARTWORK")
wnSep:SetHeight(1)
wnSep:SetPoint("TOPLEFT",  wnf, "TOPLEFT",  10, -32)
wnSep:SetPoint("TOPRIGHT", wnf, "TOPRIGHT", -10, -32)
wnSep:SetTexture(0.4, 0.4, 0.4, 0.8)

local wnVerLabel = wnf:CreateFontString(nil, "OVERLAY")
wnVerLabel:SetFont("Fonts\\FRIZQT__.TTF", 13)
wnVerLabel:SetPoint("TOPLEFT", wnSep, "BOTTOMLEFT", 0, -10)
wnVerLabel:SetTextColor(0.6, 0.5, 0.8)
wnVerLabel:SetText("Version 1.3")

local wnDiv0 = wnf:CreateTexture(nil, "ARTWORK")
wnDiv0:SetHeight(1)
wnDiv0:SetWidth(70)
wnDiv0:SetPoint("TOPLEFT", wnVerLabel, "BOTTOMLEFT", 0, -4)
wnDiv0:SetTexture(0.4, 0.4, 0.4, 0.5)

local wnBody1 = wnf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
wnBody1:SetWidth(396)
wnBody1:SetHeight(0)
wnBody1:SetPoint("TOPLEFT", wnDiv0, "BOTTOMLEFT", 0, -6)
wnBody1:SetJustifyH("LEFT")
wnBody1:SetJustifyV("TOP")
wnBody1:SetSpacing(2)
wnBody1:SetText(
	"|cffFFD100Pool Correction|r  |cff666666(% button on overlay)|r\n" ..
	"|cffbbbbbbThe addon can only see players that it or other addon users have encountered. Many players with a few honor kills are never seen, so the true PvP pool is larger than what's shown.\n\nPool Correction adds an estimated percentage of hidden players to give you more accurate bracket boundaries and rank point estimates.|r\n" ..
	"|cff88cc44Click the |cff22dd22%|r|cff88cc44 button on the overlay to configure.|r"
)

local wnDiv1 = wnf:CreateTexture(nil, "ARTWORK")
wnDiv1:SetHeight(1)
wnDiv1:SetWidth(198)
wnDiv1:SetPoint("TOP", wnBody1, "BOTTOM", 0, -8)
wnDiv1:SetTexture(0.4, 0.4, 0.4, 0.5)

local wnBody2 = wnf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
wnBody2:SetWidth(396)
wnBody2:SetHeight(0)
wnBody2:SetPoint("TOP", wnDiv1, "BOTTOM", 0, -8)
wnBody2:SetPoint("LEFT", wnBody1, "LEFT", 0, 0)
wnBody2:SetJustifyH("LEFT")
wnBody2:SetJustifyV("TOP")
wnBody2:SetSpacing(2)
wnBody2:SetText(
	"|cffFFD100RP Curve Graph|r  |cff666666(in the estimator)|r\n" ..
	"|cffbbbbbbThe estimator now shows a graph of how rank points change as you farm more honor. You can see exactly where the sweet spot is and where additional farming gives diminishing returns. Drag the slider to explore.|r"
)

local wnDiv2 = wnf:CreateTexture(nil, "ARTWORK")
wnDiv2:SetHeight(1)
wnDiv2:SetPoint("TOPLEFT",  wnf, "BOTTOMLEFT",  10, 42)
wnDiv2:SetPoint("TOPRIGHT", wnf, "BOTTOMRIGHT", -10, 42)
wnDiv2:SetTexture(0.4, 0.4, 0.4, 0.5)

local wnGotIt = CreateFrame("Button", nil, wnf, "UIPanelButtonTemplate")
wnGotIt:SetWidth(80)
wnGotIt:SetHeight(22)
wnGotIt:SetPoint("BOTTOM", wnf, "BOTTOM", 0, 12)
wnGotIt:SetText("Got it!")
wnGotIt:SetScript("OnClick", function()
	wnf:Hide()
	local hs = HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
	if hs then hs.whatsNewSeen = true end
end)

-- ===== Toggle function for minimap button =====
function HonorSpyOverlay_Toggle()
	if THSE_Blacklisted then return end
	if Frame:IsVisible() then
		Frame:Hide()
		poolPanel:Hide()
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

function HonorSpyOverlay_Refresh()
	if Frame:IsVisible() then
		UpdateOverlay()
	end
end
