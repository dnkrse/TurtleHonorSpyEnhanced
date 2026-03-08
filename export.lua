function HonorSpy:ExportCSV()
	local _G = getfenv(0)
	local PaneBackdrop  = {
		bgFile = [[Interface\DialogFrame\UI-DialogBox-Background]],
		edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]],
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 3, right = 3, top = 5, bottom = 3 }
	}

	-- If we haven't created these frames, then lets do so now.
	if (not _G["ARLCopyFrame"]) then
		local frame = CreateFrame("Frame", "ARLCopyFrame", UIParent)
		tinsert(UISpecialFrames, "ARLCopyFrame")
		frame:SetBackdrop(PaneBackdrop)
		frame:SetBackdropColor(0,0,0,1)
		frame:SetWidth(500)
		frame:SetHeight(400)
		frame:SetPoint("CENTER", UIParent, "CENTER")
		frame:SetFrameStrata("DIALOG")
		
		local scrollArea = CreateFrame("ScrollFrame", "ARLCopyScroll", frame, "UIPanelScrollFrameTemplate")
		scrollArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -30)
		scrollArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 8)
		
		local editBox = CreateFrame("EditBox", "ARLCopyEdit", frame)
		editBox:SetMultiLine(true)
		editBox:SetMaxLetters(0)
		editBox:EnableMouse(true)
		editBox:SetAutoFocus(false)
		editBox:SetFontObject(ChatFontNormal)
		editBox:SetWidth(400)
		editBox:SetHeight(270)
		editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
		
		scrollArea:SetScrollChild(editBox)
		
		local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT",frame,"TOPRIGHT")
	end

	local exportwindow = _G["ARLCopyFrame"]
	local editbox = _G["ARLCopyEdit"]

	local data = HonorSpyStandings:BuildStandingsTable();
	local observed    = table.getn(data)
	local pool_size   = HonorSpyStandings:GetPoolSize(observed)

	-- Bracket boundary percentages (0-indexed, matching vmangos server)
	local BRK = {}
	local brk_pct_0 = {[0]=1, [1]=0.845, [2]=0.697, [3]=0.566, [4]=0.436, [5]=0.327, [6]=0.228, [7]=0.159, [8]=0.100, [9]=0.060, [10]=0.035, [11]=0.020, [12]=0.008, [13]=0.003}
	for k = 0, 13 do
		BRK[k] = math.floor(brk_pct_0[k] * pool_size + 0.5)
	end

	local FY = {[0] = 0, [1] = 400}
	for k = 2, 13 do FY[k] = (k - 1) * 1000 end
	FY[14] = 13000

	local RankThresholds = {0, 2000}
	for k = 3, 14 do RankThresholds[k] = (k - 2) * 5000 end

	local function getCP(pos)
		if pos >= 1 and pos <= observed and data[pos] then
			return data[pos][3] or 0
		end
		return 0
	end

	local FX = {[0] = 0}
	local top = false
	for i = 1, 13 do
		local honor = 0
		local tempHonor = getCP(BRK[i])
		if tempHonor > 0 then
			honor = tempHonor
			tempHonor = getCP(BRK[i] + 1)
			if tempHonor > 0 then honor = honor + tempHonor end
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

	local function CalcRpDecay(rpEarning, oldRp)
		local decay = math.floor(0.2 * oldRp + 0.5)
		local delta = rpEarning - decay
		if delta < 0 then delta = delta / 2 end
		if delta < -2500 then delta = -2500 end
		return oldRp + delta
	end

	-- Build CSV into a table for fast concatenation
	local lines = {}
	tinsert(lines, "Standing,Name,Race,Class,ThisWeekHonor,LastWeekHonor,OldStanding,RP,Rank,Bracket,RPEarning,EstRP,WeekRP,EstRank,EstProgress,LastChecked")

	for i, row in ipairs(data) do
		local name, class, thisWeekHonor, lastWeekHonor, standing, RP, rank, last_checked, race = unpack(row)
		thisWeekHonor = thisWeekHonor or 0
		lastWeekHonor = lastWeekHonor or 0
		standing = standing or 0
		RP = RP or 0
		rank = rank or 0
		last_checked = last_checked or 0

		-- Determine bracket
		local my_bracket = 1
		for b = 2, 14 do
			if not BRK[b - 1] or (i > BRK[b - 1]) then break end
			my_bracket = b
		end

		local award = CalcRpEarning(thisWeekHonor)
		local EstRP = math.floor(CalcRpDecay(award, RP) + 0.5)
		if EstRP < 0 then EstRP = 0 end
		-- Turtle WoW: no de-ranking — clamp to current rank's minimum RP
		if rank < 0 or rank > 14 then rank = 0 end  -- guard corrupted rank
		local minRP = 0
		if rank >= 3 then minRP = (rank - 2) * 5000
		elseif rank == 2 then minRP = 2000 end
		if EstRP < minRP then EstRP = minRP end
		local weekRP = EstRP - RP
		local EstRank = 14
		for r = 3, 14 do
			if (EstRP < RankThresholds[r]) then
				EstRank = r - 1
				break
			end
		end
		local EstProgress = math.floor((EstRP - math.floor(EstRP / 5000) * 5000) / 5000 * 100)

		local lastCheckedStr = date("%d/%m/%y %H:%M:%S", last_checked)

		local line = string.format("%d,%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s",
			i, name, race or "", class or "",
			thisWeekHonor, lastWeekHonor, standing,
			RP, rank, my_bracket,
			math.floor(award + 0.5), EstRP, weekRP,
			EstRank, EstProgress, lastCheckedStr)
		tinsert(lines, line)
	end

	editbox:SetText(table.concat(lines, "\n"))
	editbox:HighlightText(0)
	exportwindow:Show()
end