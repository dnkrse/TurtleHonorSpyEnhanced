-- TurtleHonorSpyEnhanced: in-game diagnostics
-- Called via /hsver diag

-- ===== Reusable copy-paste window =====
local FONT = "Fonts\\FRIZQT__.TTF"
local _copyFrame

local function StripColors(s)
	s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
	s = string.gsub(s, "|r", "")
	return s
end

function THSE:ShowCopyWindow(title, text)
	if not _copyFrame then
		local f = CreateFrame("Frame", "HonorSpyDiagFrame", UIParent)
		f:SetWidth(560); f:SetHeight(440)
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		f:SetFrameStrata("DIALOG")
		f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true)
		f:SetBackdrop({
			bgFile   = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 },
		})
		f:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
		f:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", function() this:StartMoving() end)
		f:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)

		local titleFS = f:CreateFontString(nil, "OVERLAY")
		titleFS:SetFont(FONT, 12, "OUTLINE")
		titleFS:SetPoint("TOP", f, "TOP", 0, -8)
		titleFS:SetTextColor(1, 0.82, 0)
		f._title = titleFS

		local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
		closeBtn:SetWidth(20); closeBtn:SetHeight(20)
		closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -4)
		closeBtn:SetScript("OnClick", function() f:Hide() end)

		local sf = CreateFrame("ScrollFrame", "HonorSpyDiagScroll", f, "UIPanelScrollFrameTemplate")
		sf:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -28)
		sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 8)

		local eb = CreateFrame("EditBox", "HonorSpyDiagEditBox", sf)
		eb:SetMultiLine(true)
		eb:SetAutoFocus(false)
		eb:SetFont(FONT, 10)
		eb:SetWidth(510)
		eb:SetTextColor(0.85, 0.85, 0.85)
		eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
		sf:SetScrollChild(eb)

		_copyFrame = f
		f._eb = eb
	end
	_copyFrame._title:SetText((title or "Output") .. " — Ctrl+A, Ctrl+C to copy")
	_copyFrame._eb:SetText(text)
	_copyFrame._eb:HighlightText()
	_copyFrame._eb:SetFocus()
	_copyFrame:Show()
end

-- ===== DB state summary (prints to chat) =====
function THSE:DebugDatabase()
	local out = DEFAULT_CHAT_FRAME

	local function p(text, r, g, b)
		out:AddMessage(text, r or 0.7, g or 0.7, b or 0.7)
	end

	p("|cffFFD100=== THSE DB State ===|r", 1, 0.82, 0)

	-- Version
	local ver = GetAddOnMetadata("TurtleHonorSpyEnhanced", "Version") or "?"
	p("Version: " .. ver)

	-- DB access
	local hs = THSE.GetDB()
	if not hs then
		p("DB not accessible — HonorSpy.db.realm.hs is nil", 1, 0.3, 0.3)
		return
	end
	p("DB: OK")

	-- Honor history
	local histCount = hs.honorHistory and table.getn(hs.honorHistory) or 0
	p("Honor history entries: " .. histCount)

	if histCount > 0 then
		local newest = hs.honorHistory[1]
		local oldest = hs.honorHistory[histCount]
		p("  Newest: " .. date("%Y-%m-%d %H:%M", newest.t) ..
			"  type=" .. (newest.type or "?") ..
			"  +" .. (newest.amount or 0) ..
			"  zone=" .. (newest.zone or "nil"))
		p("  Oldest: " .. date("%Y-%m-%d %H:%M", oldest.t) ..
			"  type=" .. (oldest.type or "?") ..
			"  +" .. (oldest.amount or 0) ..
			"  zone=" .. (oldest.zone or "nil"))
	end

	-- Overlay position
	if hs.overlayPos then
		local pos = hs.overlayPos
		p("Overlay pos: " .. (pos.point or "?") ..
			string.format("  x=%.1f y=%.1f", pos.x or 0, pos.y or 0))
	else
		p("Overlay pos: default (not saved)")
	end

	-- Minimap angle
	p("Minimap angle: " .. string.format("%.1f", hs.minimapAngle or 200))

	-- Weekly progress
	if hs.weeklyStartProgress then
		p("Weekly start progress: " ..
			string.format("%.4f", hs.weeklyStartProgress))
	end

	-- Session start
	if hs.sessionStartHonor then
		p("Session start honor: " .. (hs.sessionStartHonor or 0))
	end

	-- Collapse state
	local nCollapsed = 0
	if hs.histCollapsed then
		for _, v in pairs(hs.histCollapsed) do
			if v then nCollapsed = nCollapsed + 1 end
		end
	end
	p("Collapsed days: " .. nCollapsed)

	-- Addon users seen
	local nUsers = 0
	if THSE.addonUsers then
		for _ in pairs(THSE.addonUsers) do nUsers = nUsers + 1 end
	end
	p("Addon users seen: " .. nUsers)

	-- Player PvP info
	local rank = UnitPVPRank("player") or 0
	local progress = GetPVPRankProgress() or 0
	local weekHonor = 0
	if GetPVPThisWeekStats then
		local _, h = GetPVPThisWeekStats()
		weekHonor = h or 0
	end
	p("Player rank: " .. rank ..
		string.format("  progress=%.4f  weekHonor=%d", progress, weekHonor))

	p("|cffFFD100=== End DB State ===|r", 1, 0.82, 0)
end

-- ===== Full debug log (/hsver debug log) =====
function THSE:DebugLog()
	local lines = {}
	local function p(s) table.insert(lines, s or "") end
	local function sec(title) p(""); p("=== " .. title .. " ===") end

	local ver = GetAddOnMetadata("TurtleHonorSpyEnhanced", "Version") or "?"
	p("THSE FULLLOG  v" .. ver .. "  " .. date("%Y-%m-%d %H:%M:%S"))

	-- ── Player PvP API ──
	sec("PvP API")
	local rankNum  = UnitPVPRank("player") or 0
	local rankPct  = GetPVPRankProgress() or 0
	local thisW_hk, thisW_h, thisW_dk = 0, 0, 0
	local lastW_h, lastW_dk = 0, 0
	local life_hk = 0
	if GetPVPThisWeekStats  then thisW_hk, thisW_h, thisW_dk = GetPVPThisWeekStats() end
	if GetPVPLastWeekStats  then _, lastW_h, lastW_dk = GetPVPLastWeekStats() end
	if GetPVPLifetimeStats  then life_hk = GetPVPLifetimeStats() end
	p(string.format("rank=%d  pct=%.10f", rankNum, rankPct))
	p(string.format("thisWeek  hk=%s  honor=%s  dk=%s", tostring(thisW_hk), tostring(thisW_h), tostring(thisW_dk)))
	p(string.format("lastWeek  honor=%s  dk=%s", tostring(lastW_h), tostring(lastW_dk)))
	p(string.format("lifetime  hk=%s", tostring(life_hk)))

	-- ── DB / Honor History ──
	local hs = THSE.GetDB()
	sec("DB State")
	if not hs then
		p("DB not accessible")
	else
		p("compactMode: " .. tostring(hs.compactMode or "nil"))
		p("hideZero:    " .. tostring(hs.hideZero or "nil"))
		local histCount = hs.honorHistory and table.getn(hs.honorHistory) or 0
		p("honorHistory entries: " .. histCount)
	end

	-- ── Full Honor History ──
	sec("Honor History (all entries)")
	if hs and hs.honorHistory then
		local hist = hs.honorHistory
		local n = table.getn(hist)
		local DUMP_LIMIT = 500
		local showN = n
		if showN > DUMP_LIMIT then
			showN = DUMP_LIMIT
			p("(showing newest " .. DUMP_LIMIT .. " of " .. n .. " entries)")
		end
		p(string.format("%-3s %-19s %-10s %-6s %6s  %-10s  extra", "#", "time", "type", "zone", "amount", "rankPct"))
		p(string.rep("-", 72))
		for i = 1, showN do
			local e = hist[i]
			local ts2 = date("%Y-%m-%d %H:%M:%S", e.t)
			local zone = e.zone and string.sub(e.zone, 1, 6) or "-"
			local rpStr = e.rankPct and string.format("%.6f", e.rankPct) or "-"
			local extra = ""
			if e.type == "tick" then
				extra = string.format("ha=%.0f hk=%.0f prevRP=%.6f", e.tickHaHq or 0, e.tickHk or 0, e.prevRankPct or 0)
			elseif e.type == "kill" then
				extra = "v=" .. (e.victim or "?") .. " vRank=" .. (e.victimRank or "?")
			elseif e.type == "bgresult" then
				extra = "result=" .. (e.result or "?")
			elseif e.type == "bgexit" then
				extra = "zone=" .. (e.zone or "?")
			elseif e.questName then
				extra = "quest=" .. e.questName
			end
			p(string.format("%-3d %-19s %-10s %-6s %+6d  %-10s  %s",
				i, ts2, e.type or "?", zone, e.amount or 0, rpStr, extra))
		end
	else
		p("No history")
	end

	-- ── BG Scoreboard Cache ──
	sec("BG Scoreboard Rank Cache")
	if THSE.HistoryGetBGScoreRank then
		local cache = THSE:HistoryGetBGScoreRank()
		local count = 0
		for name, rank2 in pairs(cache) do
			p("  " .. name .. " = " .. (rank2 or "?"))
			count = count + 1
		end
		if count == 0 then p("  (empty)") end
	else
		p("  (not exposed)")
	end

	p("")
	p("=== END FULLLOG ===")

	THSE:ShowCopyWindow("Debug Log", table.concat(lines, "\n"))
end
