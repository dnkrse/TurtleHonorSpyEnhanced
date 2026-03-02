local C = AceLibrary("Crayon-2.0")
local BC = AceLibrary("Babble-Class-2.2")
local L = AceLibrary("AceLocale-2.2"):new("HonorSpy")

HonorSpyStandings = HonorSpy:NewModule("HonorSpyStandings", "AceDB-2.0")

local playerName = UnitName("player")

-- Reusable rank icon texture for GameTooltip hover
local ttRankIcon = GameTooltip:CreateTexture("HonorSpyTooltipRankIcon", "OVERLAY")
ttRankIcon:SetWidth(16)
ttRankIcon:SetHeight(16)
ttRankIcon:Hide()

local ttSafeIcon = GameTooltip:CreateTexture("HonorSpyTooltipSafeIcon", "OVERLAY")
ttSafeIcon:SetWidth(16)
ttSafeIcon:SetHeight(16)
ttSafeIcon:SetTexture("Interface\\Icons\\Ability_Creature_Cursed_02")
ttSafeIcon:Hide()

-----------------------------------------------------------------------
-- Layout constants
-----------------------------------------------------------------------
local ROW_H       = 18
local PAD         = 8
local HDR_H       = 20
local MAX_VISIBLE = 25
local FRAME_W     = 565

-- Column layout: x = left offset inside row, w = width, j = justification
local C_RICON  = {x = 4,   w = 16}
local C_NAME   = {x = 24,  w = 120, j = "LEFT"}
local C_STATUS = {x = 146, w = 32,  j = "LEFT"}
local C_HONOR  = {x = 180, w = 55,  j = "RIGHT"}
local C_RPAW   = {x = 239, w = 50,  j = "LEFT"}
local C_TOTRP  = {x = 292, w = 55,  j = "RIGHT"}
local C_GAIN   = {x = 352, w = 55,  j = "LEFT"}
local C_CRANK  = {x = 408, w = 30,  j = "RIGHT"}
local C_CICON  = {x = 440, w = 14}
local C_NRANK  = {x = 462, w = 30,  j = "RIGHT"}
local C_NICON  = {x = 494, w = 14}
local C_DIFF   = {x = 516, w = 25,  j = "RIGHT"}

-----------------------------------------------------------------------
-- State
-----------------------------------------------------------------------
local mainFrame, bodyFrame
local rows = {}         -- fixed pool of MAX_VISIBLE row frames
local scrollOffset = 0  -- index of first visible data row (0-based)
local displayRows = {}  -- built by RenderStandings, read by UpdateRows

-----------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------
local function MakeFS(parent, col)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameTooltipText")
	fs:SetPoint("LEFT", parent, "LEFT", col.x, 0)
	fs:SetWidth(col.w)
	fs:SetJustifyH(col.j or "LEFT")
	return fs
end

local function MakeIcon(parent, col, size)
	local tex = parent:CreateTexture(nil, "ARTWORK")
	tex:SetWidth(size)
	tex:SetHeight(size)
	tex:SetPoint("LEFT", parent, "LEFT", col.x, 0)
	return tex
end

-----------------------------------------------------------------------
-- Apply one data row to one visible row frame
-----------------------------------------------------------------------
local function ApplyRow(r, d)
	if not d then
		r:Hide()
		return
	end
	r:Show()
	if d.type == "sep" then
		r.rankIcon:Hide()
		r.nameFS:SetText(C:Colorize("888866", string.format("-- Bracket %d --", d.bracket)))
		if d._ext or d._b14_players then
			r:EnableMouse(true)
			r.rowData = d
		else
			r:EnableMouse(false)
			r.rowData = nil
		end
		r.statusFS:SetText("")
		r.honorFS:SetText("")
		r.rpAwFS:SetText("")
		r.totRPFS:SetText(d.showTotal and C:Colorize("666644", "Total") or "")
		r.gainFS:SetText("")
		r.cRankIcon:Hide()
		r.cRankFS:SetText("")
		r.nRankIcon:Hide()
		r.nRankFS:SetText("")
		r.diffFS:SetText("")
		r.stopIcon:Hide()
		r.addonIcon:Hide()
	else
		r.rankIcon:SetTexture(d.rankIconPath)
		r.rankIcon:SetAlpha(d.rankIconAlpha)
		r.rankIcon:Show()
		r.nameFS:SetText(d.nameText)
		r.statusFS:SetText(d.statusText)
		r.honorFS:SetText(d.honorText)
		r.rpAwFS:SetText(d.rpAwText)
		r.totRPFS:SetText(d.totRPText)
		r.gainFS:SetText(d.gainText)
		r.cRankIcon:SetTexture(d.cRankIconPath)
		r.cRankIcon:SetAlpha(d.cRankIconAlpha)
		r.cRankIcon:Show()
		r.cRankFS:SetText(d.cRankText)
		r.nRankIcon:SetTexture(d.nRankIconPath)
		r.nRankIcon:SetAlpha(d.nRankIconAlpha)
		r.nRankIcon:Show()
		r.nRankFS:SetText(d.nRankText)
		r.diffFS:SetText(d.diffText)
		-- Fixed slots after status: dot(146) bomb(158) skull(172) honor(180)
		if d._addonVer then
			r.addonIcon:ClearAllPoints()
			r.addonIcon:SetPoint("LEFT", r, "LEFT", 158, 0)
			r.addonIcon:Show()
		else
			r.addonIcon:Hide()
		end
		if d._b14Safety == "over" then
			r.stopIcon:ClearAllPoints()
			r.stopIcon:SetPoint("LEFT", r, "LEFT", 172, 0)
			r.stopIcon:SetVertexColor(1, 1, 1)
			r.stopIcon:Show()
		else
			r.stopIcon:Hide()
		end
		r:EnableMouse(true)
		r.rowData = d  -- for tooltip handler
	end
end

-----------------------------------------------------------------------
-- Refresh all visible rows from displayRows + scrollOffset
-----------------------------------------------------------------------
local function UpdateVisibleRows()
	for vi = 1, MAX_VISIBLE do
		local dataIdx = scrollOffset + vi
		ApplyRow(rows[vi], displayRows[dataIdx])
	end
end

-----------------------------------------------------------------------
-- Scroll (virtual — just changes offset & rebinds data)
-----------------------------------------------------------------------
local function OnMouseWheel()
	local totalRows = table.getn(displayRows)
	local maxOffset = math.max(0, totalRows - MAX_VISIBLE)
	if arg1 > 0 then
		scrollOffset = math.max(0, scrollOffset - 3)
	else
		scrollOffset = math.min(maxOffset, scrollOffset + 3)
	end
	UpdateVisibleRows()
end

-----------------------------------------------------------------------
-- Row creation (one-time, fixed pool)
-----------------------------------------------------------------------
local function CreateRow(vi, parent)
	local r = CreateFrame("Frame", "HSSRow" .. vi, parent)
	r:SetHeight(ROW_H)
	r:SetWidth(FRAME_W - PAD * 2)
	r:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((vi - 1) * ROW_H))
	r:EnableMouse(true)
	r:EnableMouseWheel(true)
	r:SetScript("OnMouseWheel", OnMouseWheel)

	r.hl = r:CreateTexture(nil, "HIGHLIGHT")
	r.hl:SetAllPoints()
	r.hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	r.hl:SetBlendMode("ADD")
	r.hl:SetAlpha(0.15)

	r.rankIcon  = MakeIcon(r, C_RICON, 16)
	r.nameFS    = MakeFS(r, C_NAME)
	r.statusFS  = MakeFS(r, C_STATUS)
	r.honorFS   = MakeFS(r, C_HONOR)
	r.rpAwFS    = MakeFS(r, C_RPAW)
	r.totRPFS   = MakeFS(r, C_TOTRP)
	r.gainFS    = MakeFS(r, C_GAIN)
	r.cRankIcon = MakeIcon(r, C_CICON, 14)
	r.cRankFS   = MakeFS(r, C_CRANK)
	r.nRankIcon = MakeIcon(r, C_NICON, 14)
	r.nRankFS   = MakeFS(r, C_NRANK)
	r.diffFS    = MakeFS(r, C_DIFF)

	r.stopIcon = r:CreateTexture(nil, "OVERLAY")
	r.stopIcon:SetWidth(12)
	r.stopIcon:SetHeight(12)
	r.stopIcon:SetPoint("LEFT", r, "LEFT", 172, 0)
	r.stopIcon:SetTexture("Interface\\Icons\\Ability_Creature_Cursed_02")
	r.stopIcon:Hide()

	r.addonIcon = r:CreateTexture(nil, "ARTWORK")
	r.addonIcon:SetWidth(12)
	r.addonIcon:SetHeight(12)
	r.addonIcon:SetTexture("Interface\\Icons\\Inv_Misc_Bomb_04")
	r.addonIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	r.addonIcon:Hide()

	-- Shared tooltip handlers — read data from r.rowData
	r:SetScript("OnEnter", function()
		local td = this.rowData
		if not td then return end
		if td.type == "sep" then
			local ext = td._ext
			local hasSlotInfo = ext and ext.need1 and ext.need1 > 0
			local hasB14 = td.bracket == 14 and td._b14_slots and td._b14_slots >= 1 and td._b14_players
			if not hasSlotInfo and not hasB14 then return end

			GameTooltip:SetOwner(this, "ANCHOR_CURSOR")
			GameTooltip:ClearLines()
			GameTooltip:AddLine(string.format("|cffddaa44Bracket %d — Slot Info|r", td.bracket), 0.87, 0.67, 0.27)
			GameTooltip:AddLine(" ", 1, 1, 1)
			GameTooltip:AddDoubleLine("Players ranked this week:", string.format("%d", td._pool_size), 0.7, 0.7, 0.7, 1, 1, 1)
			if ext then
				GameTooltip:AddDoubleLine("Open slots in bracket:", string.format("%d", ext.slots), 0.7, 0.7, 0.7, 1, 1, 1)
			end
			if hasSlotInfo then
				GameTooltip:AddLine(" ", 1, 1, 1)
				GameTooltip:AddDoubleLine("+1 slot at:", string.format("%d  (+%d more)", ext.pool1, ext.need1), 0.7, 0.7, 0.7, 1, 1, 0.6)
				if ext.need2 > 0 then
					GameTooltip:AddDoubleLine("+2 slots at:", string.format("%d  (+%d more)", ext.pool2, ext.need2), 0.7, 0.7, 0.7, 0.6, 0.6, 0.4)
				end
				if not hasB14 then
					GameTooltip:AddLine(" ", 1, 1, 1)
					GameTooltip:AddLine("Any player earning honor this week counts.", 0.6, 0.6, 0.6)
				end
			end

			if hasB14 then
				local players = td._b14_players
				local nSlots  = td._b14_slots
				local avg     = td._b14_avg or 0
				local safeTarget = td._b14_safe_target or 0

				local minH, maxH = players[1].honor, players[1].honor
				for pi = 2, nSlots do
					local p = players[pi]
					if p then
						if p.honor < minH then minH = p.honor end
						if p.honor > maxH then maxH = p.honor end
					end
				end
				local spread = maxH - minH
				local optPct = (avg > 0 and spread > 0) and math.max(0, math.floor((1 - spread / avg) * 100 + 0.5)) or 100

				GameTooltip:AddLine(" ", 1, 1, 1)
				local optClr = optPct >= 80 and {0.27, 0.87, 0.47} or (optPct >= 50 and {0.87, 0.73, 0.27} or {1, 0.4, 0.4})
				GameTooltip:AddDoubleLine("Bracket Optimization:", string.format("%d%%", optPct), 0.87, 0.67, 0, optClr[1], optClr[2], optClr[3])
				GameTooltip:AddLine("Shows how close bracket 14 players are in honor.", 0.6, 0.6, 0.6)
				GameTooltip:AddLine("When everyone farms similar amounts, you all get", 0.6, 0.6, 0.6)
				GameTooltip:AddLine("more rank points (up to |cffbba860" .. "13,000 RP|r each).", 0.6, 0.6, 0.6)
				GameTooltip:AddLine("If this % is low, those ahead should take a break", 0.6, 0.6, 0.6)
				GameTooltip:AddLine("so others can catch up. Coordinate on a shared honor", 0.6, 0.6, 0.6)
				GameTooltip:AddLine("target to help everyone rank faster.", 0.6, 0.6, 0.6)

				-- Per-player overshoot warning for the local player
				local myName = UnitName("player")
				local myHonor = 0
				for pi = 1, nSlots do
					local p = players[pi]
					if p and p.name == myName then myHonor = p.honor; break end
				end
				if safeTarget > 0 and myHonor > safeTarget then
					local excess = myHonor - safeTarget
					GameTooltip:AddLine(" ", 1, 1, 1)
					GameTooltip:AddDoubleLine("Your honor:",  string.format("%d", myHonor),   0.7, 0.7, 0.7, 1, 0.4, 0.4)
					GameTooltip:AddDoubleLine("Recommended target:", string.format("%d", safeTarget), 0.7, 0.7, 0.7, 1, 1, 1)
					GameTooltip:AddDoubleLine("Excess:",      string.format("+%d", excess),    0.7, 0.7, 0.7, 1, 0.5, 0.5)
				end

				GameTooltip:AddLine(" ", 1, 1, 1)
				GameTooltip:AddLine("Current RP awards:", 0.87, 0.73, 0.27)
				for pi = 1, nSlots do
					local p = players[pi]
					if p then
						local isMe = p.name == myName
						local offPct = p.progressLoss or 0
						local offStr = ""
						if offPct > 0 then
							local intensity = math.min(offPct / 50, 1)
							local r = string.format("%02x", math.floor(255 - intensity * 105 + 0.5))
							local g = string.format("%02x", math.floor(100 - intensity * 80 + 0.5))
							local b = string.format("%02x", math.floor(100 - intensity * 80 + 0.5))
							offStr = string.format("|cff%s%s%s-%d%%|r ", r, g, b, offPct)
						end
						GameTooltip:AddDoubleLine(
							isMe and ("|cffff6666" .. p.name .. "|r") or p.name,
							isMe and string.format("|cffff6666%s%d RP|r", offStr, p.award) or string.format("%s|cffaaaaaa%d RP|r", offStr, p.award),
							1, 1, 1, 1, 1, 1
						)
					end
				end
			end

			GameTooltip:Show()
			return
		end
		local lastWeekBracket = 0
		if td._standing > 0 then
			lastWeekBracket = 1
			for b = 2, 14 do
				if td._standing > td._brk_abs[b] then break end
				lastWeekBracket = b
			end
		end
		GameTooltip:SetOwner(this, "ANCHOR_CURSOR")
		GameTooltip:ClearLines()
		local cr, cg, cb = BC:GetColor(td._class)
		GameTooltip:AddLine("     " .. td._name, cr or 1, cg or 1, cb or 1)
		if td._race then
			GameTooltip:AddDoubleLine("Race:", td._race, 0.7, 0.7, 0.7, 1, 1, 1)
		end
		GameTooltip:AddDoubleLine("Last Week Honor:", string.format("%d", td._lastWeekHonor), 0.7, 0.7, 0.7, 1, 1, 1)
		GameTooltip:AddDoubleLine("Last Week Standing:", string.format("#%d |cff888888(Bracket %d)|r", td._standing, lastWeekBracket), 0.7, 0.7, 0.7, 1, 1, 1)
		GameTooltip:AddDoubleLine("Last Seen:", td._last_seen_human, 0.7, 0.7, 0.7, 1, 1, 1)
		if td._bgZone then
			GameTooltip:AddDoubleLine("Battleground:", "|cffff4444" .. td._bgZone .. "|r", 0.7, 0.7, 0.7, 1, 0.3, 0.3)
		elseif td._isOnline then
			GameTooltip:AddDoubleLine("Status:", "|cff88cc88Online|r", 0.7, 0.7, 0.7, 0.5, 0.8, 0.5)
		end
		if td._addonVer then
			if td._addonVer == "pre-1.2" then
				GameTooltip:AddDoubleLine("Addon:", "pre-1.2", 0.7, 0.7, 0.7, 0.8, 0.6, 0.2)
			else
				GameTooltip:AddDoubleLine("Addon:", "v" .. td._addonVer, 0.7, 0.7, 0.7, 0.8, 0.47, 1)
			end
		end
		if HonorSpy.debugMode and td._source then
			GameTooltip:AddDoubleLine("Source:", td._source, 0.7, 0.7, 0.7, 0.6, 0.8, 1)
			if td._received then
				GameTooltip:AddDoubleLine("Received:", date("%d/%m/%y %H:%M:%S", td._received), 0.7, 0.7, 0.7, 0.6, 0.8, 1)
			end
		end
		local skullLine
		if td._b14Safety then
			local players = td._b14_players
			local nSlots = td._b14_slots or 0
			local safeTarget = td._b14_safe_target or 0

			-- Find this player's honor
			local myHonor = 0
			if players then
				for pi = 1, nSlots do
					local p = players[pi]
					if p and p.name == td._name then
						myHonor = p.honor
						break
					end
				end
			end
			local excess = safeTarget > 0 and (myHonor - safeTarget) or 0

			GameTooltip:AddLine(" ", 1, 1, 1)
			GameTooltip:AddLine("     |cffdd4422-- Above Recommended Target --|r", 0.87, 0.27, 0.13)
			skullLine = GameTooltip:NumLines()
			GameTooltip:AddLine("You're already safely in bracket 14 if the reset", 0.6, 0.6, 0.6)
			GameTooltip:AddLine("happened right now. Farming further above the recommended", 0.6, 0.6, 0.6)
			GameTooltip:AddLine("target spreads the bracket and lowers RP for others.", 0.6, 0.6, 0.6)
			GameTooltip:AddLine("Coordinate with your bracket on a shared honor target.", 0.87, 0.73, 0.27)
			GameTooltip:AddLine(" ", 1, 1, 1)
			GameTooltip:AddDoubleLine("Your honor:",  string.format("%d", myHonor),   0.7, 0.7, 0.7, 1, 0.4, 0.4)
			GameTooltip:AddDoubleLine("Recommended target:", string.format("%d", safeTarget), 0.7, 0.7, 0.7, 1, 1, 1)
			GameTooltip:AddDoubleLine("Ahead by:",    string.format("+%d", excess),    0.7, 0.7, 0.7, 1, 0.5, 0.5)
		end
		GameTooltip:Show()
		if td._rank > 0 then
			ttRankIcon:ClearAllPoints()
			ttRankIcon:SetPoint("LEFT", GameTooltipTextLeft1, "LEFT", 0, 0)
			ttRankIcon:SetTexture(string.format("Interface\\PvPRankBadges\\PvPRank%02d", td._rank))
			ttRankIcon:Show()
		else
			ttRankIcon:Hide()
		end
		if skullLine then
			local anchor = getglobal("GameTooltipTextLeft" .. skullLine)
			if anchor then
				ttSafeIcon:ClearAllPoints()
				ttSafeIcon:SetPoint("LEFT", anchor, "LEFT", 0, 0)
				ttSafeIcon:Show()
			end
		else
			ttSafeIcon:Hide()
		end
	end)
	r:SetScript("OnLeave", function()
		ttRankIcon:Hide()
		ttSafeIcon:Hide()
		GameTooltip:Hide()
	end)

	return r
end

-----------------------------------------------------------------------
-- One-time frame creation
-----------------------------------------------------------------------
local function CreateMainFrame()
	if mainFrame then return end

	mainFrame = CreateFrame("Frame", "HonorSpyStandingsFrame", UIParent)
	mainFrame:SetWidth(FRAME_W)
	mainFrame:SetHeight(PAD + HDR_H + 2 + MAX_VISIBLE * ROW_H + PAD)
	mainFrame:SetBackdrop({
		bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	mainFrame:SetBackdropColor(0, 0, 0, 0.92)
	mainFrame:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)
	mainFrame:EnableMouse(true)
	mainFrame:SetMovable(true)
	mainFrame:SetClampedToScreen(true)
	mainFrame:SetFrameStrata("MEDIUM")
	mainFrame:RegisterForDrag("LeftButton")
	mainFrame:SetScript("OnDragStart", function() mainFrame:StartMoving() end)
	mainFrame:SetScript("OnDragStop", function()
		mainFrame:StopMovingOrSizing()
		local p, _, rp, x, y = mainFrame:GetPoint()
		if HonorSpy and HonorSpy.db and HonorSpy.db.realm then
			HonorSpy.db.realm.hs.standingsPos = { point = p, relPoint = rp, x = x, y = y }
		end
	end)

	-- close button (positioned outside top-right corner)
	local cb = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
	cb:SetPoint("CENTER", mainFrame, "TOPRIGHT", -3, -3)
	cb:SetScript("OnClick", function() mainFrame:Hide() end)

	-- header row
	local hdr = CreateFrame("Frame", nil, mainFrame)
	hdr:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", PAD, -PAD)
	hdr:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -PAD, -PAD)
	hdr:SetHeight(HDR_H)

	local function HdrText(col, txt)
		local fs = hdr:CreateFontString(nil, "OVERLAY", "GameTooltipText")
		fs:SetPoint("LEFT", hdr, "LEFT", col.x, 0)
		fs:SetWidth(col.w)
		fs:SetJustifyH(col.j or "LEFT")
		fs:SetTextColor(1, 0.65, 0)
		fs:SetText(txt)
	end
	HdrText(C_NAME,  L["Name"])
	HdrText(C_HONOR, "Honor")
	HdrText(C_RPAW,  "RP")
	HdrText(C_TOTRP, "RP")
	HdrText(C_GAIN,  "Gain")
	HdrText(C_CRANK, "Rank")
	HdrText(C_NRANK, "Next")
	HdrText(C_DIFF,  "")

	-- body area (rows live here, no ScrollFrame)
	bodyFrame = CreateFrame("Frame", "HSSBody", mainFrame)
	bodyFrame:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, -2)
	bodyFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -PAD, PAD)
	bodyFrame:EnableMouseWheel(true)
	bodyFrame:SetScript("OnMouseWheel", OnMouseWheel)

	-- create fixed row pool
	for vi = 1, MAX_VISIBLE do
		rows[vi] = CreateRow(vi, bodyFrame)
	end

	mainFrame:Hide()
end

local function RestorePosition()
	if not mainFrame then return end
	local pos = HonorSpy and HonorSpy.db and HonorSpy.db.realm
	            and HonorSpy.db.realm.hs and HonorSpy.db.realm.hs.standingsPos
	if pos and pos.point then
		mainFrame:ClearAllPoints()
		mainFrame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
	else
		mainFrame:ClearAllPoints()
		mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
end

-----------------------------------------------------------------------
-- Public API
-----------------------------------------------------------------------
function HonorSpyStandings:OnEnable()
	CreateMainFrame()
	RestorePosition()
	self:RenderStandings()
	mainFrame:Hide()
end

function HonorSpyStandings:OnDisable()
	if mainFrame then mainFrame:Hide() end
end

function HonorSpyStandings:Refresh()
	if mainFrame and mainFrame:IsShown() then
		self:RenderStandings()
	end
end

function HonorSpyStandings:Toggle()
	if not mainFrame then
		CreateMainFrame()
		RestorePosition()
	end
	if mainFrame:IsShown() then
		mainFrame:Hide()
	else
		self:RenderStandings()
		mainFrame:Show()
	end
end

-----------------------------------------------------------------------
-- BuildStandingsTable  (unchanged business logic)
-----------------------------------------------------------------------
local raceDisplayNames = {
	NightElf = "Night Elf",
	BloodElf = "High Elf",
	HighElf = "High Elf",
	Scourge = "Undead",
}

function HonorSpyStandings:BuildStandingsTable()
	local t = {}
	local eFaction = {}
	local horde   = { Orc = true, Tauren = true, Troll = true, Undead = true, Scourge = true, Goblin = true }
	local alliance = { Dwarf = true, Gnome = true, Human = true, ["Night Elf"] = true, ["High Elf"] = true, NightElf = true, BloodElf = true, HighElf = true }
	if alliance[UnitRace("player")] == true then
		eFaction = horde
	else
		eFaction = alliance
	end

	for pn, player in pairs(HonorSpy.db.realm.hs.currentStandings) do
		if not (player.race and eFaction[player.race]) then
			local displayRace = raceDisplayNames[player.race] or player.race
			table.insert(t, { pn, player.class, player.thisWeekHonor, player.lastWeekHonor, player.standing, player.RP, player.rank, player.last_checked, displayRace, player._source, player._received })
		end
	end
	local sort_column = 3
	if HonorSpy.db.realm.hs.sort == L["Rank"] then sort_column = 6 end
	table.sort(t, function(a, b) return a[sort_column] > b[sort_column] end)
	return t
end

-----------------------------------------------------------------------
-- BG zones & friend helpers
-----------------------------------------------------------------------
local BG_ZONES = {
	["Warsong Gulch"] = true,
	["Arathi Basin"] = true,
	["Alterac Valley"] = true,
	["Azshara Crater"] = true,
	["Tol Barad"] = true,
	["Korrak's Valley"] = true,
	["Stranglethorn Vale PvP Arena"] = true,
	["Sunstrider Court"] = true,
	["Blood Ring"] = true,
	["Lordaeron Arena"] = true,
	["Sunnyglade Valley"] = true,
}

local function GetOnlineFriends()
	local online, inBG, allFriends = {}, {}, {}
	ShowFriends()
	for i = 1, GetNumFriends() do
		local name, _, _, area, connected = GetFriendInfo(i)
		if name then
			allFriends[name] = true
			if connected then
				online[name] = true
				if area and BG_ZONES[area] then
					inBG[name] = area
				end
			end
		end
	end
	online[UnitName("player")] = true
	return online, inBG, allFriends
end

-----------------------------------------------------------------------
-- RenderStandings  — builds displayRows[], resets scroll, updates view
-----------------------------------------------------------------------
function HonorSpyStandings:RenderStandings()
	if not mainFrame then return end

	local t = self:BuildStandingsTable()
	local onlineFriends, bgFriends, allFriends = GetOnlineFriends()
	local pool_size = table.getn(t)

	-- Bracket boundary percentages
	local BRK = {}
	local brk_pct_0 = {
		[0] = 1, [1] = 0.845, [2] = 0.697, [3] = 0.566, [4] = 0.436,
		[5] = 0.327, [6] = 0.228, [7] = 0.159, [8] = 0.100, [9] = 0.060,
		[10] = 0.035, [11] = 0.020, [12] = 0.008, [13] = 0.003,
	}
	for k = 0, 13 do
		BRK[k] = math.floor(brk_pct_0[k] * pool_size + 0.5)
	end
	local brk_abs = {}
	for k = 1, 14 do brk_abs[k] = BRK[k - 1] end

	-- RP award curve
	local FY = { [0] = 0, [1] = 400 }
	for k = 2, 13 do FY[k] = (k - 1) * 1000 end
	FY[14] = 13000

	local RankThresholds = { 0, 2000 }
	for k = 3, 14 do RankThresholds[k] = (k - 2) * 5000 end

	local function getCP(pos)
		if pos >= 1 and pos <= pool_size and t[pos] then return t[pos][3] or 0 end
		return 0
	end

	-- Build FX array
	local FX = { [0] = 0 }
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

	-- RP interpolation
	local function CalcRpEarning(cp)
		local i = 0
		while i < 14 and BRK[i] and BRK[i] > 0 and FX[i] <= cp do i = i + 1 end
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

	-- B14 safety info
	local b14_slots = BRK[13]
	local b14_cutoff_honor = 0
	local b14_cutoff_name = nil
	local b14_safe_target = 0
	local b14_daysLeft = nil
	if b14_slots >= 1 and b14_slots < pool_size then
		b14_cutoff_honor = t[b14_slots + 1][3] or 0
		b14_cutoff_name  = t[b14_slots + 1][1]
		if b14_cutoff_honor > 0 then
			local hs = HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
			local reset_day = (hs and hs.reset_day) or 3
			local wd = tonumber(date("!%w"))
			local hh = tonumber(date("!%H"))
			local mm = tonumber(date("!%M"))
			local rawD = 7 + reset_day - wd
			local daysUntil = rawD - math.floor(rawD / 7) * 7
			if daysUntil == 0 then daysUntil = 7 end
			local daysLeft = daysUntil - (hh * 60 + mm) / 1440
			-- Safe target computed below after b14_avg is known
			b14_daysLeft = daysLeft
		end
	end

	-- Slot extension info for every bracket
	local function bracketExt(bk)
		local pU = brk_pct_0[bk - 1]
		local pL = (bk < 14) and brk_pct_0[bk] or 0
		local cur = math.floor(pU * pool_size + 0.5) - math.floor(pL * pool_size + 0.5)
		local need1, pool1, need2, pool2
		for delta = 1, 2000 do
			local p = pool_size + delta
			local s = math.floor(pU * p + 0.5) - math.floor(pL * p + 0.5)
			if s >= cur + 1 and not need1 then need1 = delta; pool1 = p end
			if s >= cur + 2 and not need2 then need2 = delta; pool2 = p; break end
		end
		return { slots = cur, need1 = need1 or 0, pool1 = pool1 or pool_size, need2 = need2 or 0, pool2 = pool2 or pool_size }
	end
	local brk_ext = {}
	for bk = 1, 14 do brk_ext[bk] = bracketExt(bk) end

	-- Collect B14 player names for tooltip
	local b14_players = {}
	local b14_avg = 0
	local b14_median = 0
	if b14_slots >= 1 then
		local honorSum = 0
		local honorList = {}
		for j = 1, b14_slots do
			if t[j] then
				local hon = t[j][3] or 0
				local rp  = t[j][6] or 0
				local aw  = math.floor(CalcRpEarning(hon) + 0.5)
				local idealEnd  = CalcRpDecay(13000, rp)
				local actualEnd = CalcRpDecay(aw, rp)
				local progLoss  = (idealEnd - actualEnd) / 50
				table.insert(b14_players, {
					name  = t[j][1],
					honor = hon,
					award = aw,
					progressLoss = math.floor(progLoss + 0.5),
				})
				table.insert(honorList, hon)
				honorSum = honorSum + hon
			end
		end
		if b14_slots > 0 then
			b14_avg = math.floor(honorSum / b14_slots + 0.5)
		end
		-- Compute median
		table.sort(honorList, function(a, b) return a < b end)
		local n = table.getn(honorList)
		if n > 0 then
			if math.mod(n, 2) == 1 then
				b14_median = honorList[math.ceil(n / 2)]
			else
				b14_median = math.floor((honorList[n / 2] + honorList[n / 2 + 1]) / 2 + 0.5)
			end
		end
		-- Safe target: median × time-scaled buffer, requires 3+ players and 50k+ median
		if b14_daysLeft and b14_slots >= 3 and b14_median >= 50000 then
			local buffer = 1.05 + 0.15 * (b14_daysLeft / 7)
			b14_safe_target = math.floor(b14_median * buffer / 1000 + 0.5) * 1000
		end
		HonorSpyStandings._b14_avg = b14_avg
		HonorSpyStandings._b14_median = b14_median
		if HonorSpyDebugSafeOverride then
			b14_safe_target = HonorSpyDebugSafeOverride
		end
		HonorSpyStandings._b14_safe_target = b14_safe_target
		HonorSpyStandings._b14_daysLeft = b14_daysLeft
		HonorSpyStandings._b14_slots = b14_slots
		HonorSpyStandings._b14_players = b14_players
	end

	-- Build displayRows (fresh table each render)
	displayRows = {}

	local prev_bracket = 0
	local limit = tonumber(HonorSpy.db.realm.hs.limit) or 0

	for i = 1, table.getn(t) do
		local name, class, thisWeekHonor, lastWeekHonor, standing, RP, rank, last_checked, race, source, received = unpack(t[i])
		thisWeekHonor = thisWeekHonor or 0
		lastWeekHonor = lastWeekHonor or 0
		standing = standing or 0
		RP = RP or 0
		rank = rank or 0
		last_checked = last_checked or 0

		local my_bracket = 1
		for b = 2, 14 do
			if i > brk_abs[b] then break end
			my_bracket = b
		end

		-- Separator
		if my_bracket ~= prev_bracket then
			local sep = {
				type = "sep",
				bracket = my_bracket,
				showTotal = (prev_bracket == 0),
				_ext = brk_ext[my_bracket],
				_pool_size = pool_size,
			}
			if my_bracket == 14 and b14_slots >= 1 then
				sep._b14_slots   = b14_slots
				sep._b14_players = b14_players
				sep._b14_avg     = b14_avg
				sep._b14_safe_target = b14_safe_target
			end
			table.insert(displayRows, sep)
			prev_bracket = my_bracket
		end

		-- Last seen
		local last_seen = time() - last_checked
		local last_seen_human
		if last_seen / 86400 > 1 then
			last_seen_human = math.floor(last_seen / 86400) .. L["d"]
		elseif last_seen / 3600 > 1 then
			last_seen_human = math.floor(last_seen / 3600) .. L["h"]
		elseif last_seen / 60 > 1 then
			last_seen_human = math.floor(last_seen / 60) .. L["m"]
		else
			last_seen_human = last_seen .. L["s"]
		end

		-- RP calculations
		local award = CalcRpEarning(thisWeekHonor)
		local EstRP = math.floor(CalcRpDecay(award, RP) + 0.5)
		if EstRP < 0 then EstRP = 0 end
		if rank < 0 or rank > 14 then rank = 0 end  -- guard corrupted rank
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
		local curProgress = math.floor((RP - math.floor(RP / 5000) * 5000) / 5000 * 100)
		local rankDiff = EstRank - rank
		local weekRP = EstRP - RP

		local class_color = BC:GetHexColor(class)
		local curRankColor = "cccccc"
		local nextRankColor
		if rankDiff > 0 then
			nextRankColor = "55aa55"
		elseif EstRP > RP then
			nextRankColor = "88cc88"
		elseif EstRP < RP then
			nextRankColor = "ff6666"
		else
			nextRankColor = "ddbb44"
		end
		local weekRPColor = weekRP >= 0 and "44ddaa" or "ff6666"

		local onlineDot = ""
		if bgFriends[name] then
			onlineDot = "|cffff4444o|r"
		elseif onlineFriends[name] then
			onlineDot = "|cff88cc88o|r"
		elseif allFriends[name] then
			onlineDot = "|cff333333o|r"
		end

		local addonEntry = THSE_AddonUsers and THSE_AddonUsers[name] or nil
		local addonVer = addonEntry and addonEntry.ver or nil
		-- addonVer is used for the icon in row rendering (addonIcon texture)

		local b14Safety, b14Buffer, b14BufferPct = nil, 0, 0
		if my_bracket == 14 and b14_slots >= 1 and b14_cutoff_honor > 0 then
			b14Buffer = thisWeekHonor - b14_cutoff_honor
			b14BufferPct = b14_cutoff_honor > 0 and (b14Buffer / b14_cutoff_honor * 100) or 0
			if b14_safe_target > 0 and thisWeekHonor > b14_safe_target then
				b14Safety = "over"
			end
		end

		local honorColor = class_color
		if b14Safety == "over" then
			honorColor = "ff4444"
		end

		local displayName = string.len(name) > 12 and string.sub(name, 1, 12) .. ".." or name

		table.insert(displayRows, {
			type = "player",
			index = i,
			_my_bracket = my_bracket,
			nameText   = C:Colorize("444444", i) .. " " .. C:Colorize(class_color, displayName),
			statusText = onlineDot,
			honorText  = C:Colorize(honorColor, string.format("%d", thisWeekHonor)),
			rpAwText   = C:Colorize("ddbb44", string.format("%d", math.floor(award + 0.5))),
			totRPText  = C:Colorize(class_color, string.format("%d", RP)),
			gainText   = C:Colorize(weekRPColor, weekRP >= 0 and string.format("+%d", weekRP) or string.format("%d", weekRP)),
			cRankText  = C:Colorize(curRankColor, string.format("%d%%", curProgress)),
			nRankText  = C:Colorize(nextRankColor, string.format("%d%%", EstProgress)),
			diffText   = rankDiff > 0 and C:Colorize("ddbb44", "+" .. rankDiff)
			             or (rankDiff < 0 and C:Colorize("ff6666", tostring(rankDiff)) or ""),
			rankIconPath   = string.format("Interface\\PvPRankBadges\\PvPRank%02d", rank > 0 and rank or 1),
			rankIconAlpha  = rank > 0 and 1 or 0,
			cRankIconPath  = string.format("Interface\\PvPRankBadges\\PvPRank%02d", rank > 0 and rank or 1),
			cRankIconAlpha = rank > 0 and 1 or 0,
			nRankIconPath  = string.format("Interface\\PvPRankBadges\\PvPRank%02d", EstRank > 0 and EstRank or 1),
			nRankIconAlpha = EstRank > 0 and 1 or 0,
			_name = name,
			_class = class,
			_race = race,
			_rank = rank,
			_lastWeekHonor = lastWeekHonor,
			_standing = standing,
			_last_seen_human = last_seen_human,
			_bgZone = bgFriends[name],
			_isOnline = onlineFriends[name],
			_addonVer = addonVer,
			_source = source,
			_received = received,
			_b14Safety = b14Safety,
			_b14Buffer = b14Buffer,
			_b14BufferPct = b14BufferPct,
			_b14_cutoff_name = b14_cutoff_name,
			_b14_cutoff_honor = b14_cutoff_honor,
			_b14_safe_target = b14_safe_target,
			_b14_players = b14_players,
			_b14_avg = b14_avg,
			_b14_slots = b14_slots,
			_b14_slots_needed = b14_slots_needed,
			_b14_next_pool = b14_next_pool,
			_brk_abs = brk_abs,
		})

		if limit > 0 and i == limit then break end
	end

	-- Size frame to content (up to MAX_VISIBLE)
	local totalRows = table.getn(displayRows)
	local visibleRows = math.min(totalRows, MAX_VISIBLE)
	mainFrame:SetHeight(PAD + HDR_H + 2 + visibleRows * ROW_H + PAD)

	-- Reset scroll & draw
	scrollOffset = 0
	UpdateVisibleRows()
end

