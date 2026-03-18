-- HonorSpy Overlay: current rank widget
-- v2.0 placeholder — full rework in progress for Patch 1.18.1 new PvP system.

local PAD     = 8
local INNER_W = 194

-- ===== Frame =====
local Frame = CreateFrame("Frame", "HonorSpyOverlayFrame", UIParent)
Frame:SetWidth(210)
Frame:SetHeight(107)
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
rankIcon:SetWidth(24)
rankIcon:SetHeight(24)
rankIcon:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -24)

local rankName = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
rankName:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD + 30, -25)
rankName:SetJustifyH("LEFT")
rankName:SetTextColor(1, 1, 1)

local rankPct = Frame:CreateFontString(nil, "OVERLAY")
rankPct:SetFont("Fonts\\FRIZQT__.TTF", 9)
rankPct:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD + 30, -37)
rankPct:SetJustifyH("LEFT")
rankPct:SetTextColor(0.87, 0.73, 0.27)

-- ===== Weekly Honor Cap Bar =====
local capLabel = Frame:CreateFontString(nil, "OVERLAY")
capLabel:SetFont("Fonts\\FRIZQT__.TTF", 9)
capLabel:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -52)
capLabel:SetJustifyH("LEFT")
capLabel:SetTextColor(0.6, 0.6, 0.6)
capLabel:SetText("Weekly Honor")

local capRight = Frame:CreateFontString(nil, "OVERLAY")
capRight:SetFont("Fonts\\FRIZQT__.TTF", 9)
capRight:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -PAD, -52)
capRight:SetJustifyH("RIGHT")
capRight:SetTextColor(0.6, 0.6, 0.6)

local capBarBg = Frame:CreateTexture(nil, "ARTWORK")
capBarBg:SetTexture(0, 0, 0, 0.5)
capBarBg:SetWidth(INNER_W)
capBarBg:SetHeight(8)
capBarBg:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -63)

local capBar = CreateFrame("StatusBar", nil, Frame)
capBar:SetWidth(INNER_W)
capBar:SetHeight(8)
capBar:SetPoint("TOPLEFT", capBarBg, "TOPLEFT", 0, 0)
capBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
capBar:SetStatusBarColor(0.87, 0.73, 0.27, 0.85)
capBar:SetMinMaxValues(0, 20000)
capBar:SetFrameLevel(Frame:GetFrameLevel() + 1)

-- ===== Divider 2 =====
local div2 = Frame:CreateTexture(nil, "ARTWORK")
div2:SetTexture(1, 1, 1, 0.15)
div2:SetWidth(INNER_W)
div2:SetHeight(1)
div2:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -75)

-- ===== Rework Notice =====
local noticeText = Frame:CreateFontString(nil, "OVERLAY")
noticeText:SetFont("Fonts\\FRIZQT__.TTF", 8)
noticeText:SetPoint("TOPLEFT",  Frame, "TOPLEFT",  PAD, -80)
noticeText:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -PAD, -80)
noticeText:SetJustifyH("CENTER")
noticeText:SetTextColor(1, 0.62, 0)
noticeText:SetText(
	"Rework in progress for Patch 1.18.1\n" ..
	"|cff888888new PvP system — live Friday Mar 20|r")

-- ===== Update Logic =====
local function UpdateOverlay()
	local _, rank = GetPVPRankInfo(UnitPVPRank("player"))
	rank = rank or 0
	if rank > 0 then
		rankIcon:SetTexture(
			string.format("Interface\\PvPRankBadges\\PvPRank%02d", rank))
		rankIcon:Show()
		rankName:SetText("Rank " .. rank)
	else
		rankIcon:Hide()
		rankName:SetText("|cff888888No PvP Rank|r")
	end

	local progress = GetPVPRankProgress() or 0
	local pct = math.floor(progress * 100 + 0.5)
	rankPct:SetText(pct .. "%")

	-- Weekly honor cap (20k) — placeholder using ThisWeekHonor if available
	local weekHonor = 0
	if GetPVPThisWeekStats then
		local _, honor = GetPVPThisWeekStats()
		weekHonor = honor or 0
	end
	capBar:SetValue(math.min(weekHonor, 20000))
	local honorStr = weekHonor >= 1000
		and string.format("%d,%03d", math.floor(weekHonor/1000), weekHonor - math.floor(weekHonor/1000)*1000)
		or tostring(weekHonor)
	capRight:SetText(honorStr .. " / ??")
end

-- ===== Event Handler =====
Frame:SetScript("OnEvent", function()
	if event == "PLAYER_ENTERING_WORLD" then
		local hs = HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
		if hs then
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
	end
end)

-- Refresh every 5 seconds
local elapsed_total = 0
Frame:SetScript("OnUpdate", function()
	elapsed_total = elapsed_total + arg1
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