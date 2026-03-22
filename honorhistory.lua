-- HonorHistory: scrollable log of honor events with day grouping, BG icons,
-- win/loss tracking, rank progress, and mark-turn-in detection.

local MAX_ENTRIES   = 20000
local GROUP_GAP_SEC = 300

local BG_ZONES = {
	["Warsong Gulch"] = true,
	["Arathi Basin"]  = true,
	["Alterac Valley"]= true,
	["Thorn Gorge"]   = true,
	["Blood Ring"]    = true,
}

local ZONE_ABBR = {
	["Warsong Gulch"] = "WSG",
	["Arathi Basin"]  = "AB",
	["Alterac Valley"]= "AV",
	["Thorn Gorge"]   = "Thorn",
	["Blood Ring"]    = "Blood",
}

local BG_ICON = {
	["Warsong Gulch"] = "Interface\\Icons\\INV_Misc_Rune_07",
	["Arathi Basin"]  = "Interface\\Icons\\INV_Jewelry_Amulet_07",
	["Alterac Valley"]= "Interface\\Icons\\INV_Jewelry_Necklace_21",
	["Thorn Gorge"]   = "Interface\\Icons\\INV_Jewelry_Talisman_04",
	["Blood Ring"]    = "Interface\\Icons\\INV_Jewelry_Talisman_05",
}

local BG_COLOR = {
	["Warsong Gulch"] = { 0.9, 0.3, 0.3 },
	["Arathi Basin"]  = { 0.3, 0.8, 0.3 },
	["Alterac Valley"]= { 0.3, 0.5, 0.9 },
	["Thorn Gorge"]   = { 0.8, 0.6, 0.2 },
	["Blood Ring"]    = { 0.8, 0.3, 0.8 },
}

local WIN_W  = 340
local WIN_H  = 400
local ROW_H  = 14
local DATESEP_H = 18
local FONT   = "Fonts\\FRIZQT__.TTF"
local TIP_W  = 220
local TABLE_W = WIN_W - 32
local TABLE_H = WIN_H - 44
local TABLE_ROWS = math.floor(TABLE_H / ROW_H)

-- ===== Helper: GetDB =====
local function GetDB()
	return HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
end

-- ===== Helper: QuestToBG =====
local function QuestToBG(questName)
	if not questName then return nil end
	local q = string.lower(questName)
	for zone, _ in pairs(ZONE_ABBR) do
		if string.find(q, string.lower(zone), 1, true) then
			return zone
		end
	end
	return nil
end

-- ===== Rank tables =====
local RANK_NAMES = {
	[1]  = "Private",        [2]  = "Corporal",
	[3]  = "Sergeant",       [4]  = "Master Sergeant",
	[5]  = "Sergeant Major", [6]  = "Knight",
	[7]  = "Knight-Lieutenant",[8] = "Knight-Captain",
	[9]  = "Knight-Champion", [10] = "Lieutenant Commander",
	[11] = "Commander",       [12] = "Marshal",
	[13] = "Field Marshal",   [14] = "Grand Marshal",
}
-- Horde equivalents (same slot, different names)
local RANK_NAMES_H = {
	[1]  = "Scout",          [2]  = "Grunt",
	[3]  = "Sergeant",       [4]  = "Senior Sergeant",
	[5]  = "First Sergeant", [6]  = "Stone Guard",
	[7]  = "Blood Guard",    [8]  = "Legionnaire",
	[9]  = "Centurion",      [10] = "Champion",
	[11] = "Lieutenant General", [12] = "General",
	[13] = "Warlord",        [14] = "High Warlord",
}

local function GetRankName(rankNum)
	local faction, _ = UnitFactionGroup("player")
	if faction == "Horde" then
		return RANK_NAMES_H[rankNum] or ("Rank " .. rankNum)
	end
	return RANK_NAMES[rankNum] or ("Rank " .. rankNum)
end

-- ===== Pending quest tracker =====
local _pendingQuest   = nil
local _pendingQuestTs = nil

-- ===== Main frame =====
local Win
local _histFrame
local _rows = {}
local _listLines = {}
local _listOffset = 0
local _collapsed  = {}  -- day keys → bool
local _scrollBar

-- ===== Forward declarations =====
local HonorHistory_Refresh
local RefreshListRows
local BuildListLines

-- ===== Day key helper =====
local function DayKey(t)
	return date("%Y-%m-%d", t)
end

-- ===== Color helper: pct → hex =====
local function PctHex(pct)
	-- pct 0-100, green at 100, red at 0
	local r = math.max(0, math.min(1, 1 - pct / 100))
	local g = math.max(0, math.min(1, pct / 100))
	local b = 0
	return string.format("%02x%02x%02x",
		math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
end

-- ===== Build day totals =====
local function BuildDayTotals(entries)
	-- Returns table keyed by dayKey with { honor=N, nWins=N, nLosses=N, nKills=N, nTurnin=N, progressStart, progressEnd }
	local days = {}
	local dayOrder = {}
	for i = 1, table.getn(entries) do
		local e = entries[i]
		local dk = DayKey(e.t)
		if not days[dk] then
			days[dk] = { honor=0, nWins=0, nLosses=0, nKills=0, nTurnin=0 }
			table.insert(dayOrder, dk)
		end
		local d = days[dk]
		d.honor = d.honor + (e.amount or 0)
		if e.type == "award" or e.type == "turnin" then
			if e.outcome == "win"  then d.nWins   = d.nWins + 1   end
			if e.outcome == "loss" then d.nLosses = d.nLosses + 1 end
			if e.type == "turnin"  then d.nTurnin = d.nTurnin + 1 end
		elseif e.type == "kill" then
			d.nKills = d.nKills + 1
		end
	end
	return days, dayOrder
end

-- ===== Group tooltip builder =====
local function BuildGroupTip(group)
	-- group: { zone, outcome, entries={...} }
	local lines = {}
	local zone  = group.zone
	local total = 0
	local nKills = 0
	local nTurnin = 0
	for _, e in ipairs(group.entries or {}) do
		total = total + (e.amount or 0)
		if e.type == "kill" then nKills = nKills + 1 end
		if e.type == "turnin" then nTurnin = nTurnin + 1 end
	end
	table.insert(lines, { label = zone or "Unknown", r=1, g=0.82, b=0 })
	if group.outcome then
		local outcomeColor = { win = {0.3,1,0.3}, loss = {1,0.4,0.4} }
		local oc = outcomeColor[group.outcome] or {0.7,0.7,0.7}
		table.insert(lines, { label = string.upper(string.sub(group.outcome, 1, 1)) .. string.sub(group.outcome, 2),
			r=oc[1], g=oc[2], b=oc[3] })
	end
	table.insert(lines, { label = "Total honor: +" .. total, r=0.87, g=0.73, b=0.27 })
	if nKills > 0  then table.insert(lines, { label = nKills .. " kills",  r=0.7,g=0.7,b=0.7 }) end
	if nTurnin > 0 then table.insert(lines, { label = nTurnin .. " marks turned in", r=0.4,g=0.9,b=0.9 }) end
	return lines
end

-- ===== Day tooltip builder =====
local function BuildDayTip(dk, dayTotals)
	local d = dayTotals[dk]
	if not d then return {} end
	local lines = {}
	table.insert(lines, { label = dk, r=1, g=0.82, b=0 })
	table.insert(lines, { label = "" })
	table.insert(lines, { label = "Honor gained: +" .. d.honor, r=0.87, g=0.73, b=0.27 })
	if d.nWins > 0 or d.nLosses > 0 then
		local total = d.nWins + d.nLosses
		local pct = total > 0 and math.floor(d.nWins / total * 100) or 0
		table.insert(lines, { label = "BG record: " .. d.nWins .. "W / " .. d.nLosses .. "L  (" .. pct .. "%)", r=0.7,g=0.7,b=0.7 })
	end
	if d.nKills > 0 then
		table.insert(lines, { label = "Kills: " .. d.nKills, r=0.7,g=0.7,b=0.7 })
	end
	if d.nTurnin > 0 then
		table.insert(lines, { label = "Marks turned in: " .. d.nTurnin, r=0.4,g=0.9,b=0.9 })
	end
	return lines
end

-- ===== Build list lines from DB =====
BuildListLines = function()
	_listLines = {}
	local hs = GetDB()
	if not hs or not hs.honorHistory or table.getn(hs.honorHistory) == 0 then
		return
	end

	local entries = hs.honorHistory

	-- Build day totals
	local dayTotals, dayOrder = BuildDayTotals(entries)

	-- Walk entries newest-first (index 1 = newest)
	local i = 1
	local total = table.getn(entries)

	while i <= total do
		local e = entries[i]
		local dk = DayKey(e.t)

		-- Emit day separator if first entry of new day (entries are newest-first, so check prev)
		local prevDk = nil
		if i > 1 then prevDk = DayKey(entries[i-1].t) end
		if prevDk ~= dk then
			-- Day separator row
			local d   = dayTotals[dk]
			local honorStr = "+" .. (d and d.honor or 0)
			local nW  = d and d.nWins   or 0
			local nL  = d and d.nLosses or 0
			local total_bg = nW + nL
			local winPct = total_bg > 0 and math.floor(nW / total_bg * 100) or nil
			local dayTip = BuildDayTip(dk, dayTotals)
			table.insert(_listLines, {
				type    = "datesep",
				dayKey  = dk,
				label   = dk,
				honor   = d and d.honor or 0,
				nWins   = nW,
				nLosses = nL,
				winPct  = winPct,
				tip     = dayTip,
			})
		end

		-- Skip rest of day if collapsed
		if _collapsed[dk] then
			-- Skip all entries for this day
			while i <= total and DayKey(entries[i].t) == dk do
				i = i + 1
			end
		else
			-- Collect a group of nearby entries
			local groupStart = i
			local groupZone  = e.zone
			local groupT     = e.t

			-- Determine group color
			local gtr, gtg, gtb = 0.5, 0.5, 0.5
			if groupZone and BG_COLOR[groupZone] then
				gtr = BG_COLOR[groupZone][1]
				gtg = BG_COLOR[groupZone][2]
				gtb = BG_COLOR[groupZone][3]
			end

			-- Collect group entries (same zone, within GROUP_GAP_SEC)
			local groupEntries = {}
			local j = i
			while j <= total and DayKey(entries[j].t) == dk do
				local ej = entries[j]
				if j > i and (groupT - ej.t) > GROUP_GAP_SEC then break end
				if ej.zone ~= groupZone then break end
				table.insert(groupEntries, ej)
				groupT = ej.t
				j = j + 1
			end

			-- Group outcome (last award/turnin in group)
			local groupOutcome = nil
			local nTurnin = 0
			for _, ge in ipairs(groupEntries) do
				if ge.outcome then groupOutcome = ge.outcome end
				if ge.type == "turnin" then nTurnin = nTurnin + 1 end
			end

			local gTip = BuildGroupTip({ zone=groupZone, outcome=groupOutcome, entries=groupEntries })

			-- Emit group header
			local groupHonor = 0
			for _, ge in ipairs(groupEntries) do groupHonor = groupHonor + (ge.amount or 0) end
			local groupIcon = groupZone and BG_ICON[groupZone] or nil
			local groupAbbr = groupZone and ZONE_ABBR[groupZone] or (groupZone or "Kill")

			local outcomeStr = ""
			if groupOutcome == "win"  then outcomeStr = "|cff45ff45WIN|r"  end
			if groupOutcome == "loss" then outcomeStr = "|cffff4545LOSS|r" end

			local turninStr = nTurnin > 0 and (nTurnin .. "x") or ""

			table.insert(_listLines, {
				type        = "hdr",
				zone        = groupZone,
				icon        = groupIcon,
				label       = groupAbbr,
				outcomeStr  = outcomeStr,
				turninStr   = turninStr,
				honor       = groupHonor,
				outcome     = groupOutcome,
				dayKey      = dk,
				tr = gtr, tg = gtg, tb = gtb,
				tip         = gTip,
			})

			-- Emit individual entry rows
			for _, ge in ipairs(groupEntries) do
				local ts = date("%H:%M", ge.t)
				local rankNum = ge.rankNum or 0

				local name, nr, ng, nb
				local amt, ar, ag, ab
				local dotText = "o"

				if ge.type == "kill" then
					name = ge.targetName or "Unknown"
					nr, ng, nb = 0.9, 0.7, 0.7
					amt = "+" .. (ge.amount or 0)
					ar, ag, ab = 0.87, 0.73, 0.27
					dotText = "o"
				elseif ge.type == "award" then
					name = groupAbbr .. " (award)"
					nr, ng, nb = 0.7, 0.85, 1.0
					amt = "+" .. (ge.amount or 0)
					ar, ag, ab = 0.87, 0.73, 0.27
					dotText = "o"
				elseif ge.type == "turnin" then
					local label
					if ge.markBG then
						label = "<< " .. (ZONE_ABBR[ge.markBG] or ge.markBG) .. " Mark"
					else
						label = "<< " .. (ge.questName or "Mark")
					end
					name = label
					nr, ng, nb = 0.4, 0.9, 0.9
					amt = "+" .. (ge.amount or 0)
					ar, ag, ab = 0.4, 0.9, 0.9
					dotText = "1x"
				else
					name = ge.targetName or ge.questName or "?"
					nr, ng, nb = 0.7, 0.7, 0.7
					amt = "+" .. (ge.amount or 0)
					ar, ag, ab = 0.87, 0.73, 0.27
					dotText = "o"
				end

				table.insert(_listLines, {
					type    = "entry",
					ts      = ts,
					rankNum = rankNum,
					name    = name,
					nr = nr, ng = ng, nb = nb,
					amt     = amt,
					ar = ar, ag = ag, ab = ab,
					br = gtr, bg = gtg, bb = gtb,
					dotText = dotText,
					tip     = gTip,
				})
			end

			i = j
		end
	end
end

-- ===== Create row frames =====
local function CreateRowFrame(parent, index)
	local F = CreateFrame("Frame", nil, parent)
	F:SetWidth(TABLE_W)
	F:SetHeight(ROW_H)
	F:EnableMouse(true)

	-- Left-edge bar
	F._bar = F:CreateTexture(nil, "BACKGROUND")
	F._bar:SetWidth(4)
	F._bar:SetPoint("TOPLEFT", F, "TOPLEFT", 0, 0)
	F._bar:SetPoint("BOTTOMLEFT", F, "BOTTOMLEFT", 0, 0)
	F._bar:SetTexture(1, 1, 1, 1)
	F._bar:Hide()

	-- datesep label (big bold day text)
	F._sep = F:CreateFontString(nil, "OVERLAY")
	F._sep:SetFont(FONT, 11, "OUTLINE")
	F._sep:SetJustifyH("LEFT")
	F._sep:SetTextColor(0.85, 0.85, 0.85)
	F._sep:SetPoint("TOPLEFT", F, "TOPLEFT", 8, -1)
	F._sep:Hide()

	-- hdr: BG icon
	F._bgIco = F:CreateTexture(nil, "ARTWORK")
	F._bgIco:SetWidth(12)
	F._bgIco:SetHeight(12)
	F._bgIco:SetPoint("TOPLEFT", F, "TOPLEFT", 6, -1)
	F._bgIco:Hide()

	-- hdr: zone label
	F._zone = F:CreateFontString(nil, "OVERLAY")
	F._zone:SetFont(FONT, 10, "OUTLINE")
	F._zone:SetJustifyH("LEFT")
	F._zone:SetPoint("TOPLEFT", F, "TOPLEFT", 22, -1)
	F._zone:SetWidth(TABLE_W - 22 - 116)
	F._zone:Hide()

	-- hdr: group honor amount
	F._hdrAmt = F:CreateFontString(nil, "OVERLAY")
	F._hdrAmt:SetFont(FONT, 10, "OUTLINE")
	F._hdrAmt:SetJustifyH("RIGHT")
	F._hdrAmt:SetWidth(56)
	F._hdrAmt:SetPoint("TOPRIGHT", F, "TOPRIGHT", 0, -1)
	F._hdrAmt:Hide()

	-- hdr: time
	F._hdrTime = F:CreateFontString(nil, "OVERLAY")
	F._hdrTime:SetFont(FONT, 10, "OUTLINE")
	F._hdrTime:SetJustifyH("RIGHT")
	F._hdrTime:SetWidth(80)
	F._hdrTime:SetPoint("TOPRIGHT", F, "TOPRIGHT", -58, -1)
	F._hdrTime:Hide()

	-- datesep: wins (right-justified in 26px slot)
	F._hdrWins = F:CreateFontString(nil, "OVERLAY")
	F._hdrWins:SetFont(FONT, 9, "OUTLINE")
	F._hdrWins:SetJustifyH("RIGHT")
	F._hdrWins:SetWidth(26)
	F._hdrWins:SetPoint("TOPRIGHT", F, "TOPRIGHT", -120, -1)
	F._hdrWins:Hide()

	-- datesep: losses (left-justified in 28px slot)
	F._hdrLoss = F:CreateFontString(nil, "OVERLAY")
	F._hdrLoss:SetFont(FONT, 9, "OUTLINE")
	F._hdrLoss:SetJustifyH("LEFT")
	F._hdrLoss:SetWidth(28)
	F._hdrLoss:SetPoint("TOPLEFT", F, "TOPLEFT", 188, -1)
	F._hdrLoss:Hide()

	-- datesep: win-rate pct (right justified)
	F._hdrPct = F:CreateFontString(nil, "OVERLAY")
	F._hdrPct:SetFont(FONT, 9, "OUTLINE")
	F._hdrPct:SetJustifyH("RIGHT")
	F._hdrPct:SetWidth(40)
	F._hdrPct:SetPoint("TOPRIGHT", F, "TOPRIGHT", -58, -1)
	F._hdrPct:Hide()

	-- entry: timestamp
	F._ts = F:CreateFontString(nil, "OVERLAY")
	F._ts:SetFont(FONT, 9)
	F._ts:SetJustifyH("LEFT")
	F._ts:SetTextColor(0.5, 0.5, 0.5)
	F._ts:SetPoint("TOPLEFT", F, "TOPLEFT", 6, -1)
	F._ts:SetWidth(38)
	F._ts:Hide()

	-- entry: rank icon (12x12)
	F._ico = F:CreateTexture(nil, "ARTWORK")
	F._ico:SetWidth(12)
	F._ico:SetHeight(12)
	F._ico:SetPoint("TOPLEFT", F, "TOPLEFT", 46, -1)
	F._ico:Hide()

	-- entry: name
	F._name = F:CreateFontString(nil, "OVERLAY")
	F._name:SetFont(FONT, 9)
	F._name:SetJustifyH("LEFT")
	F._name:SetPoint("TOPLEFT", F, "TOPLEFT", 60, -1)
	F._name:SetWidth(TABLE_W - 60 - 70)
	F._name:Hide()

	-- entry: amount
	F._amt = F:CreateFontString(nil, "OVERLAY")
	F._amt:SetFont(FONT, 9)
	F._amt:SetJustifyH("RIGHT")
	F._amt:SetWidth(56)
	F._amt:SetPoint("TOPRIGHT", F, "TOPRIGHT", 0, -1)
	F._amt:Hide()

	-- entry: dot indicator (small left-of-name)
	F._dot = F:CreateFontString(nil, "OVERLAY")
	F._dot:SetFont(FONT, 8)
	F._dot:SetJustifyH("CENTER")
	F._dot:SetWidth(10)
	F._dot:SetPoint("TOPLEFT", F, "TOPLEFT", 50, -1)
	F._dot:Hide()

	-- hover highlight
	F._hl = F:CreateTexture(nil, "HIGHLIGHT")
	F._hl:SetAllPoints(F)
	F._hl:SetTexture(1, 1, 1, 0.05)

	F:SetScript("OnEnter", function()
		if F._tip then
			GameTooltip:SetOwner(F, "ANCHOR_RIGHT")
			GameTooltip:ClearLines()
			local tipLines = F._tip
			for ti, tl in ipairs(tipLines) do
				if tl.label == "" then
					GameTooltip:AddLine(" ", 1, 1, 1)
				elseif ti == 1 then
					GameTooltip:AddLine(tl.label, tl.r or 1, tl.g or 1, tl.b or 0)
				else
					GameTooltip:AddLine(tl.label, tl.r or 0.8, tl.g or 0.8, tl.b or 0.8)
				end
			end
			GameTooltip:Show()
		end
	end)
	F:SetScript("OnLeave", function() GameTooltip:Hide() end)

	return F
end

-- ===== Refresh row display =====
RefreshListRows = function()
	local total = table.getn(_listLines)
	local yOff  = 0

	for ri = 1, TABLE_ROWS do
		local lineIdx = _listOffset + ri
		local F = _rows[ri]

		-- Reset all sub-elements
		F._bar:Hide()
		F._sep:Hide()
		F._bgIco:Hide()
		F._zone:Hide()
		F._hdrAmt:Hide()
		F._hdrTime:Hide()
		F._hdrWins:Hide()
		F._hdrLoss:Hide()
		F._hdrPct:Hide()
		F._ts:Hide()
		F._ico:Hide()
		F._name:Hide()
		F._amt:Hide()
		F._dot:Hide()
		F:EnableMouse(false)
		F._tip = nil

		if lineIdx > total then
			local rowH = ROW_H
			F:SetHeight(rowH)
			F:SetPoint("TOPLEFT", Win, "TOPLEFT", 6, -25 - yOff)
			F._bar:SetHeight(rowH)
			yOff = yOff + rowH
		else
			local ln = _listLines[lineIdx]
			local rowH = (ln.type == "datesep") and DATESEP_H or ROW_H
			F:SetHeight(rowH)
			F:SetPoint("TOPLEFT", Win, "TOPLEFT", 6, -25 - yOff)
			F._bar:SetHeight(rowH)
			yOff = yOff + rowH

			F:EnableMouse(true)
			F._tip = ln.tip

			if ln.type == "datesep" then
				-- 4px grey bar (highest hierarchy)
				F._bar:SetWidth(4)
				F._bar:SetVertexColor(0.7, 0.7, 0.7, 1)
				F._bar:Show()

				F._sep:SetPoint("TOPLEFT", F, "TOPLEFT", 8, -1)
				F._sep:SetText(ln.label)
				F._sep:Show()

				-- W/L display
				if ln.nWins ~= nil then
					F._hdrWins:SetText("|cff45ff45" .. ln.nWins .. "|r")
					F._hdrWins:Show()
					F._hdrLoss:SetText("|cff888888/|r|cffff4545" .. ln.nLosses .. "|r")
					F._hdrLoss:Show()
				end

				if ln.winPct ~= nil then
					local pHex = PctHex(ln.winPct)
					F._hdrPct:SetText("|cff" .. pHex .. ln.winPct .. "%|r")
					F._hdrPct:Show()
				end

				-- Datesep toggle on click
				local dk = ln.dayKey
				F:SetScript("OnMouseUp", function()
					if arg1 == "LeftButton" then
						_collapsed[dk] = not _collapsed[dk]
						local hs = GetDB()
						if hs then
							if not hs.histCollapsed then hs.histCollapsed = {} end
							hs.histCollapsed[dk] = _collapsed[dk]
						end
						BuildListLines()
						_listOffset = 0
						RefreshListRows()
					end
				end)

			elseif ln.type == "hdr" then
				-- 2px colored bar
				F._bar:SetWidth(2)
				if ln.tr then
					F._bar:SetVertexColor(ln.tr, ln.tg, ln.tb, 1)
				else
					F._bar:SetVertexColor(0.6, 0.6, 0.6, 1)
				end
				F._bar:Show()

				if ln.icon then
					F._bgIco:SetTexture(ln.icon)
					F._bgIco:Show()
				end

				local zoneText = ln.label
				if ln.outcomeStr ~= "" then
					zoneText = zoneText .. "  " .. ln.outcomeStr
				end
				if ln.turninStr ~= "" then
					zoneText = zoneText .. "  |cff44ddff" .. ln.turninStr .. "|r"
				end
				F._zone:SetText(zoneText)
				if ln.tr then
					F._zone:SetTextColor(ln.tr, ln.tg, ln.tb)
				else
					F._zone:SetTextColor(0.7, 0.7, 0.7)
				end
				F._zone:Show()

				F._hdrAmt:SetText("|cffFFD100+" .. ln.honor .. "|r")
				F._hdrAmt:Show()

			elseif ln.type == "entry" then
				-- 1px dim colored bar
				if ln.br then
					F._bar:SetWidth(1)
					F._bar:SetVertexColor(ln.br, ln.bg, ln.bb, 0.55)
					F._bar:Show()
				end

				F._ts:SetText(ln.ts or "")
				F._ts:Show()

				if ln.rankNum and ln.rankNum > 0 then
					F._ico:SetTexture(string.format("Interface\\PvPRankBadges\\PvPRank%02d", ln.rankNum))
					F._ico:Show()
				end

				F._name:SetText(ln.name or "")
				F._name:SetTextColor(ln.nr or 0.8, ln.ng or 0.8, ln.nb or 0.8)
				F._name:Show()

				F._amt:SetText(ln.amt or "")
				F._amt:SetTextColor(ln.ar or 0.87, ln.ag or 0.73, ln.ab or 0.27)
				F._amt:Show()

				F._dot:SetText(ln.dotText or "o")
				F._dot:SetTextColor(ln.br or 0.5, ln.bg or 0.5, ln.bb or 0.5)
				F._dot:Show()
			end
		end
	end

	-- Update scrollbar
	if _scrollBar then
		local maxOffset = math.max(0, table.getn(_listLines) - TABLE_ROWS)
		if maxOffset == 0 then
			_scrollBar:Hide()
		else
			_scrollBar:Show()
			_scrollBar:SetMinMaxValues(0, maxOffset)
			_scrollBar:SetValue(_listOffset)
		end
	end
end

-- ===== Full refresh =====
HonorHistory_Refresh = function()
	BuildListLines()
	RefreshListRows()
end

-- ===== Create main window =====
local function CreateHistoryWindow()
	Win = CreateFrame("Frame", "HonorHistoryWin", UIParent)
	Win:SetWidth(WIN_W)
	Win:SetHeight(WIN_H)
	Win:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
	Win:SetFrameStrata("HIGH")
	Win:SetFrameLevel(10)
	Win:SetMovable(true)
	Win:EnableMouse(true)
	Win:SetClampedToScreen(true)
	Win:SetBackdrop({
		bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	Win:SetBackdropColor(0, 0, 0, 0.88)
	Win:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
	Win:RegisterForDrag("LeftButton")
	Win:SetScript("OnDragStart", function() this:StartMoving() end)
	Win:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	Win:Hide()

	-- Title bar
	local title = Win:CreateFontString(nil, "OVERLAY")
	title:SetFont(FONT, 12, "OUTLINE")
	title:SetPoint("TOPLEFT", Win, "TOPLEFT", 14, -6)
	title:SetTextColor(0.87, 0.73, 0.27)
	title:SetText("Honor History")

	-- Faction badge
	local factionBadge = Win:CreateTexture(nil, "OVERLAY")
	factionBadge:SetWidth(14)
	factionBadge:SetHeight(14)
	factionBadge:SetPoint("LEFT", title, "RIGHT", 5, 0)

	local function UpdateFactionBadge()
		local faction, _ = UnitFactionGroup("player")
		if faction == "Horde" then
			factionBadge:SetTexture("Interface\\TargetingFrame\\UI-PVP-Horde")
		else
			factionBadge:SetTexture("Interface\\TargetingFrame\\UI-PVP-Alliance")
		end
		factionBadge:SetTexCoord(0.09, 0.63, 0.05, 0.63)
	end
	UpdateFactionBadge()

	-- Close button
	local closeBtn = CreateFrame("Button", nil, Win, "UIPanelCloseButton")
	closeBtn:SetWidth(20)
	closeBtn:SetHeight(20)
	closeBtn:SetPoint("TOPRIGHT", Win, "TOPRIGHT", -2, -2)
	closeBtn:SetScript("OnClick", function() Win:Hide() end)

	-- Expand All button
	local expandBtn = CreateFrame("Button", nil, Win)
	expandBtn:SetWidth(60)
	expandBtn:SetHeight(14)
	expandBtn:SetPoint("TOPRIGHT", Win, "TOPRIGHT", -26, -6)
	local expandTex = expandBtn:CreateFontString(nil, "OVERLAY")
	expandTex:SetFont(FONT, 9)
	expandTex:SetAllPoints(expandBtn)
	expandTex:SetJustifyH("RIGHT")
	expandTex:SetTextColor(0.5, 0.5, 0.6)
	expandTex:SetText("Expand All")
	expandBtn:SetScript("OnClick", function()
		for dk, _ in pairs(_collapsed) do
			_collapsed[dk] = false
		end
		local hs = GetDB()
		if hs then hs.histCollapsed = {} end
		BuildListLines()
		_listOffset = 0
		RefreshListRows()
	end)

	-- Divider under title
	local divider = Win:CreateTexture(nil, "ARTWORK")
	divider:SetTexture(1, 1, 1, 0.15)
	divider:SetHeight(1)
	divider:SetPoint("TOPLEFT",  Win, "TOPLEFT",  6, -22)
	divider:SetPoint("TOPRIGHT", Win, "TOPRIGHT", -6, -22)

	-- Scrollbar
	_scrollBar = CreateFrame("Slider", "HonorHistoryScrollBar", Win, "UIPanelScrollBarTemplate")
	_scrollBar:SetWidth(16)
	_scrollBar:SetPoint("TOPRIGHT",    Win, "TOPRIGHT",  -6, -26)
	_scrollBar:SetPoint("BOTTOMRIGHT", Win, "BOTTOMRIGHT", -6, 6)
	_scrollBar:SetMinMaxValues(0, 0)
	_scrollBar:SetValueStep(1)
	_scrollBar:SetValue(0)
	_scrollBar:SetScript("OnValueChanged", function()
		local v = math.floor(this:GetValue() + 0.5)
		if v ~= _listOffset then
			_listOffset = v
			RefreshListRows()
		end
	end)

	-- Mouse-wheel scroll
	Win:EnableMouseWheel(true)
	Win:SetScript("OnMouseWheel", function()
		local delta = arg1
		local maxOffset = math.max(0, table.getn(_listLines) - TABLE_ROWS)
		_listOffset = math.max(0, math.min(maxOffset, _listOffset - delta * 3))
		if _scrollBar then _scrollBar:SetValue(_listOffset) end
		RefreshListRows()
	end)

	-- Footer divider
	local footDiv = Win:CreateTexture(nil, "ARTWORK")
	footDiv:SetTexture(1, 1, 1, 0.1)
	footDiv:SetHeight(1)
	footDiv:SetPoint("BOTTOMLEFT",  Win, "BOTTOMLEFT",  6, 20)
	footDiv:SetPoint("BOTTOMRIGHT", Win, "BOTTOMRIGHT", -6, 20)

	-- Footer count label
	local footCount = Win:CreateFontString(nil, "OVERLAY")
	footCount:SetFont(FONT, 8)
	footCount:SetPoint("BOTTOMLEFT", Win, "BOTTOMLEFT", 8, 6)
	footCount:SetJustifyH("LEFT")
	footCount:SetTextColor(0.4, 0.4, 0.4)
	Win._footCount = footCount

	-- Footer clear button
	local clearBtn = CreateFrame("Button", nil, Win)
	clearBtn:SetWidth(46)
	clearBtn:SetHeight(14)
	clearBtn:SetPoint("BOTTOMRIGHT", Win, "BOTTOMRIGHT", -10, 4)
	local clearTex = clearBtn:CreateFontString(nil, "OVERLAY")
	clearTex:SetFont(FONT, 9)
	clearTex:SetAllPoints(clearBtn)
	clearTex:SetJustifyH("RIGHT")
	clearTex:SetTextColor(0.5, 0.3, 0.3)
	clearTex:SetText("Clear All")
	clearBtn:SetScript("OnClick", function()
		local hs = GetDB()
		if hs then
			hs.honorHistory = {}
			hs.histCollapsed = {}
			_collapsed = {}
			_listOffset = 0
			HonorHistory_Refresh()
		end
	end)

	-- Create row frames
	for ri = 1, TABLE_ROWS do
		_rows[ri] = CreateRowFrame(Win, ri)
		_rows[ri]:SetPoint("TOPLEFT", Win, "TOPLEFT", 6, -25 - (ri - 1) * ROW_H)
	end

	return Win
end

-- ===== Event frame =====
_histFrame = CreateFrame("Frame", "HonorHistoryEventFrame")
_histFrame:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")
_histFrame:RegisterEvent("QUEST_TURNED_IN")
_histFrame:RegisterEvent("CHAT_MSG_SYSTEM")
_histFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
_histFrame:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
_histFrame:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
_histFrame:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")

local _currentZone = nil
local _lastBGOutcome = nil
local _lastBGOutcomeTs = nil

_histFrame:SetScript("OnEvent", function()
	local hs = GetDB()

	if event == "PLAYER_ENTERING_WORLD" then
		_currentZone = GetZoneName()
		-- Restore collapse state
		if hs and hs.histCollapsed then
			for dk, v in pairs(hs.histCollapsed) do
				_collapsed[dk] = v
			end
		end
		-- Ensure honorHistory table exists
		if hs and not hs.honorHistory then
			hs.honorHistory = {}
		end

	elseif event == "CHAT_MSG_BG_SYSTEM_NEUTRAL"
		or event == "CHAT_MSG_BG_SYSTEM_ALLIANCE"
		or event == "CHAT_MSG_BG_SYSTEM_HORDE" then
		-- Detect BG win/loss outcomes
		local msg = string.lower(arg1 or "")
		if string.find(msg, "win") or string.find(msg, "victori") or string.find(msg, "conquer") then
			_lastBGOutcome   = "win"
			_lastBGOutcomeTs = time()
		elseif string.find(msg, "lost") or string.find(msg, "los") or string.find(msg, "defeat") then
			_lastBGOutcome   = "loss"
			_lastBGOutcomeTs = time()
		end

	elseif event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
		if not hs then return end
		if not hs.honorHistory then hs.honorHistory = {} end

		local msg = arg1 or ""
		-- Parse: "You gain X honor." or "You gain X honor from SomeName."
		local amount = nil
		local targetName = nil
		local _, _, amtStr = string.find(msg, "You gain (%d+) honor")
		if amtStr then amount = tonumber(amtStr) end
		-- Try to extract target name "from <Name>"
		local _, _, fromName = string.find(msg, "from (.+)%.")
		if fromName then targetName = fromName end

		if not amount then return end

		local zone = GetZoneName()
		local isBG = BG_ZONES[zone]

		-- Determine outcome (win/loss from recent BG message, within 30s)
		local outcome = nil
		if isBG and _lastBGOutcome and _lastBGOutcomeTs then
			if (time() - _lastBGOutcomeTs) <= 30 then
				outcome = _lastBGOutcome
			end
		end

		local entryType = isBG and "award" or "kill"
		local entry = {
			type       = entryType,
			t          = time(),
			amount     = amount,
			zone       = zone,
			targetName = targetName,
			outcome    = outcome,
			rankNum    = UnitPVPRank("player") or 0,
		}

		-- Prepend (newest first)
		table.insert(hs.honorHistory, 1, entry)

		-- Trim to MAX_ENTRIES
		while table.getn(hs.honorHistory) > MAX_ENTRIES do
			table.remove(hs.honorHistory)
		end

		if Win and Win:IsVisible() then
			HonorHistory_Refresh()
		end

	elseif event == "QUEST_TURNED_IN" then
		-- arg1 = questName, arg2 = xpReward, arg3 = moneyReward
		local questName = arg1
		if not questName then return end
		_pendingQuest   = questName
		_pendingQuestTs = time()
		local markBG = QuestToBG(questName)
		if markBG and hs and hs.honorHistory then
			-- Retroactively patch the most recent "award" entry within 10s
			local now = time()
			for ri = 1, math.min(5, table.getn(hs.honorHistory)) do
				local e = hs.honorHistory[ri]
				if e.type == "award" and (now - e.t) <= 10 then
					e.type      = "turnin"
					e.questName = questName
					e.markBG    = markBG
					if Win and Win:IsVisible() then HonorHistory_Refresh() end
					break
				elseif e.type ~= "award" then
					break
				end
			end
		end

	elseif event == "CHAT_MSG_SYSTEM" then
		local msg = arg1 or ""
		if string.find(string.lower(msg), "completed") then
			local markBG = QuestToBG(msg)
			if markBG and hs and hs.honorHistory then
				local now = time()
				for ri = 1, math.min(5, table.getn(hs.honorHistory)) do
					local e = hs.honorHistory[ri]
					if e.type == "award" and (now - e.t) <= 10 then
						e.type      = "turnin"
						e.questName = msg
						e.markBG    = markBG
						if Win and Win:IsVisible() then HonorHistory_Refresh() end
						break
					elseif e.type ~= "award" then
						break
					end
				end
			end
		end
	end
end)

-- ===== Public API =====
function HonorHistory_Open()
	if not Win then
		CreateHistoryWindow()
	end
	if Win:IsVisible() then
		Win:Hide()
	else
		Win:Show()
		HonorHistory_Refresh()
	end
end

function HonorHistory_Close()
	if Win then Win:Hide() end
end
