local T = AceLibrary("Tablet-2.0")
local C = AceLibrary("Crayon-2.0")
local BC = AceLibrary("Babble-Class-2.2")
local L = AceLibrary("AceLocale-2.2"):new("HonorSpy")

HonorSpyStandings = HonorSpy:NewModule("HonorSpyStandings", "AceDB-2.0")

local playerName = UnitName("player");

-- Reusable rank icon texture for GameTooltip hover
local ttRankIcon = GameTooltip:CreateTexture("HonorSpyTooltipRankIcon", "OVERLAY")
ttRankIcon:SetWidth(16)
ttRankIcon:SetHeight(16)
ttRankIcon:Hide()

function HonorSpyStandings:OnEnable()
  if not T:IsRegistered("HonorSpyStandings") then
    T:Register("HonorSpyStandings",
      "children", function()
        T:SetTitle(L["HonorSpy standings"])
        self:OnTooltipUpdate()
      end,
  		"showTitleWhenDetached", false,
  		"showHintWhenDetached", false,
  		"cantAttach", true
    )
  end
  if not T:IsAttached("HonorSpyStandings") then
    T:Open("HonorSpyStandings")
  end
end

function HonorSpyStandings:OnDisable()
  T:Close("HonorSpyStandings")
end

function HonorSpyStandings:Refresh()
	if (T:IsRegistered("HonorSpyStandings")) then
		T:Refresh("HonorSpyStandings")
	end
end

function HonorSpyStandings:Toggle()
  if T:IsAttached("HonorSpyStandings") then
    T:Detach("HonorSpyStandings")
    if (T:IsLocked("HonorSpyStandings")) then
      T:ToggleLocked("HonorSpyStandings")
    end
  else
    T:Attach("HonorSpyStandings")
  end
end

function HonorSpyStandings:BuildStandingsTable()
  local t = { }
  -- ADD: Get enemy faction table from parent
  local eFaction = {}
  local horde = { Orc=true, Tauren=true, Troll=true, Undead=true, Scourge=true, Goblin=true }
  local alliance = { Dwarf=true, Gnome=true, Human=true, ["Night Elf"]=true, ["High Elf"]=true, NightElf=true, BloodElf=true, HighElf=true }
  if alliance[UnitRace("player")] == true then
    eFaction = horde
  else
    eFaction = alliance
  end

  for playerName, player in pairs(HonorSpy.db.realm.hs.currentStandings) do
    -- ADD: Skip enemy faction players
    if not (player.race and eFaction[player.race]) then
      table.insert(t, {playerName, player.class, player.thisWeekHonor, player.lastWeekHonor, player.standing, player.RP, player.rank, player.last_checked})
    end
  end
  local sort_column = 3; -- ThisWeekHonor
  if (HonorSpy.db.realm.hs.sort == L["Rank"]) then sort_column = 6; end
  table.sort(t, function(a,b)
    return a[sort_column] > b[sort_column]
    end)
  return t
end

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
	local online = {}
	local inBG = {}
	local allFriends = {}
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

function HonorSpyStandings:OnTooltipUpdate()
	local cat = T:AddCategory(
	  "columns", 10,
	  "text",  C:Orange(L["Name"]),   "justify",  "LEFT",  "child_justify",  "LEFT",
	  "text2", "",                    "justify2", "LEFT",  "child_justify2", "LEFT",
	  "text3", C:Orange("Honor"),     "justify3", "RIGHT", "child_justify3", "RIGHT",
	  "text4", C:Orange("RP"),        "justify4", "LEFT",  "child_justify4", "LEFT",
	  "text5", "",                    "justify5", "RIGHT", "child_justify5", "RIGHT",
	  "text6", C:Orange("RP"),  "justify6", "RIGHT", "child_justify6", "RIGHT",
	  "text7", C:Orange("Gain"),      "justify7", "LEFT", "child_justify7", "LEFT",
	  "text8", C:Orange("Rank"),      "justify8", "RIGHT",  "child_justify8", "RIGHT",
	  "checkIcon5", "Interface\\PvPRankBadges\\PvPRank01", "checkIcon5Alpha", 0,
	  "text9", C:Orange("Next"),      "justify9", "RIGHT",  "child_justify9", "RIGHT",
	  "checkIcon6", "Interface\\PvPRankBadges\\PvPRank01", "checkIcon6Alpha", 0,
	  "text10", C:Orange("Diff"),     "justify10", "RIGHT", "child_justify10", "RIGHT"
	)
	local t = self:BuildStandingsTable()
	local onlineFriends, bgFriends, allFriends = GetOnlineFriends()
	local pool_size = table.getn(t)

	-- Bracket boundary percentages (0-indexed, matching vmangos HonorScores BRK[])
	-- BRK[0]=100%, BRK[1]=84.5%, ..., BRK[13]=0.3%
	local BRK = {}
	local brk_pct_0 = {[0]=1, [1]=0.845, [2]=0.697, [3]=0.566, [4]=0.436, [5]=0.327, [6]=0.228, [7]=0.159, [8]=0.100, [9]=0.060, [10]=0.035, [11]=0.020, [12]=0.008, [13]=0.003}
	for k = 0, 13 do
		BRK[k] = math.floor(brk_pct_0[k] * pool_size + 0.5)
	end
	-- 1-indexed brk_abs for bracket separator display (brk_abs[k] = BRK[k-1])
	local brk_abs = {}
	for k = 1, 14 do
		brk_abs[k] = BRK[k - 1]
	end
	-- RP award curve (FY): fixed RP values at each bracket boundary (0-indexed)
	local FY = {[0] = 0, [1] = 400}
	for k = 2, 13 do FY[k] = (k - 1) * 1000 end
	FY[14] = 13000
	local RankThresholds = {0, 2000}
	for k = 3, 14 do
		RankThresholds[k] = (k - 2) * 5000
	end

	-- Helper: get CP of player at standing position (1-based), 0 if not found
	local function getCP(pos)
		if pos >= 1 and pos <= pool_size and t[pos] then
			return t[pos][3] or 0
		end
		return 0
	end

	-- Build FX array: honor (CP) values at each bracket boundary (0-indexed)
	-- Matches vmangos GenerateScores(): FX[i] = avg of CP at BRK[i] and BRK[i]+1
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
	-- FX[14] = top scorer honor (only if all 13 boundaries were populated)
	FX[14] = (not top) and getCP(1) or 0

	-- Honor-based RP interpolation (matches vmangos CalculateRpEarning)
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

	-- Server-accurate decay (matches vmangos CalculateRpDecay)
	local function CalcRpDecay(rpEarning, oldRp)
		local decay = math.floor(0.2 * oldRp + 0.5)
		local delta = rpEarning - decay
		if delta < 0 then delta = delta / 2 end
		if delta < -2500 then delta = -2500 end
		return oldRp + delta
	end

	local prev_bracket = 0

	for i = 1, table.getn(t) do
		local name, class, thisWeekHonor, lastWeekHonor, standing, RP, rank, last_checked = unpack(t[i])

		-- Determine bracket for this position (for display separator only)
		local my_bracket = 1
		for b = 2, 14 do
			if (i > brk_abs[b]) then
				break
			end
			my_bracket = b
		end

		-- Insert bracket separator when bracket changes
		if my_bracket ~= prev_bracket then
			local sepColor = "666644"
			if prev_bracket == 0 then
				-- First bracket (14): show subheaders
				cat:AddLine(
					"text",  C:Colorize(sepColor, string.format("-- Bracket %d --", my_bracket)),
					"text2", "",
					"text3", "",
					"text4", "",
					"text5", "",
					"text6", C:Colorize(sepColor, "Total"),
					"text7", "",
					"text8", "",
					"text9", "",
					"text10", ""
				)
			else
				cat:AddLine(
					"text",  C:Colorize(sepColor, string.format("-- Bracket %d --", my_bracket)),
					"text2", "",
					"text3", "",
					"text4", "",
					"text5", "",
					"text6", "",
					"text7", "",
					"text8", "",
					"text9", "",
					"text10", ""
				)
			end
			prev_bracket = my_bracket
		end

		local last_seen, last_seen_human = (time() - last_checked), ""
		if (last_seen/60/60/24 > 1) then
			last_seen_human = ""..math.floor(last_seen/60/60/24)..L["d"]
		elseif (last_seen/60/60 > 1) then
			last_seen_human = ""..math.floor(last_seen/60/60)..L["h"]
		elseif (last_seen/60 > 1) then
			last_seen_human = ""..math.floor(last_seen/60)..L["m"]
		else
			last_seen_human = ""..last_seen..L["s"]
		end

		local award = CalcRpEarning(thisWeekHonor)
		local EstRP = math.floor(CalcRpDecay(award, RP) + 0.5)
		if EstRP < 0 then EstRP = 0 end
		-- Turtle WoW: no de-ranking — clamp to current rank's minimum RP
		local minRP = 0
		if rank >= 3 then minRP = (rank - 2) * 5000
		elseif rank == 2 then minRP = 2000 end
		if EstRP < minRP then EstRP = minRP end
		local EstRank = 14
		for r = 3, 14 do
			if (EstRP < RankThresholds[r]) then
				EstRank = r - 1
				break
			end
		end
		local EstProgress = math.floor((EstRP - math.floor(EstRP / 5000) * 5000) / 5000 * 100)
		local nextWeekStr = string.format("%d%%", EstProgress)
		local curProgress = math.floor((RP - math.floor(RP / 5000) * 5000) / 5000 * 100)
		local curRankStr = string.format("%d%%", curProgress)
		local rankingUp = EstRank > rank
		local rankDiff = EstRank - rank
		local rankUp = ""
		if rankDiff > 0 then
			rankUp = " " .. C:Colorize("ddbb44", "+" .. rankDiff)
		elseif rankDiff < 0 then
			rankUp = " " .. C:Colorize("ff6666", rankDiff)
		end
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

		local class_color = BC:GetHexColor(class)
		local weekRP = EstRP - RP
		local weekRPColor = weekRP >= 0 and "44ddaa" or "ff6666"
		local weekRPStr = weekRP >= 0 and string.format("+%d", weekRP) or string.format("%d", weekRP)

		local rankIcon = string.format("Interface\\PvPRankBadges\\PvPRank%02d", rank > 0 and rank or 1)
		local curRankIcon = string.format("Interface\\PvPRankBadges\\PvPRank%02d", rank > 0 and rank or 1)
		local nextRankIcon = string.format("Interface\\PvPRankBadges\\PvPRank%02d", EstRank > 0 and EstRank or 1)
		local displayName = string.len(name) > 12 and string.sub(name, 1, 12) .. ".." or name
		local onlineDot = ""
		if bgFriends[name] then
			onlineDot = "|cffff4444o|r"
		elseif onlineFriends[name] then
			onlineDot = "|cff88cc88o|r"
		elseif allFriends[name] then
			onlineDot = "|cff333333o|r"
		end
		cat:AddLine(
			"text", C:Colorize("444444", i).." "..C:Colorize(class_color, displayName),
			"hasCheck", true,
			"checkIcon", rankIcon,
			"checked", true,
			"text2", onlineDot,
			"text3", C:Colorize(class_color, string.format("%d", thisWeekHonor)),
			"text4", C:Colorize("ddbb44", string.format("%d", math.floor(award + 0.5))),
			"text5", "",
			"text6", C:Colorize(class_color, string.format("%d", RP)),
			"text7", C:Colorize(weekRPColor, weekRPStr),
			"text8", C:Colorize(curRankColor, curRankStr),
			"checkIcon5", curRankIcon,
			"checkIcon5Alpha", rank > 0 and 1 or 0,
			"text9", C:Colorize(nextRankColor, nextWeekStr),
			"checkIcon6", nextRankIcon,
			"checkIcon6Alpha", EstRank > 0 and 1 or 0,
			"text10", rankDiff > 0 and C:Colorize("ddbb44", "+" .. rankDiff) or (rankDiff < 0 and C:Colorize("ff6666", tostring(rankDiff)) or ""),
			"onEnterFunc", function()
				local lastWeekBracket = 0
				if standing > 0 then
					lastWeekBracket = 1
					for b = 2, 14 do
						if standing > brk_abs[b] then break end
						lastWeekBracket = b
					end
				end
				GameTooltip:SetOwner(this, "ANCHOR_CURSOR")
				GameTooltip:ClearLines()
				local cr, cg, cb = BC:GetColor(class)
				GameTooltip:AddLine("     " .. name, cr or 1, cg or 1, cb or 1)
				GameTooltip:AddDoubleLine("Last Week Honor:", string.format("%d", lastWeekHonor), 0.7, 0.7, 0.7, 1, 1, 1)
				GameTooltip:AddDoubleLine("Last Week Standing:", string.format("#%d |cff888888(Bracket %d)|r", standing, lastWeekBracket), 0.7, 0.7, 0.7, 1, 1, 1)
				GameTooltip:AddDoubleLine("Last Seen:", last_seen_human, 0.7, 0.7, 0.7, 1, 1, 1)
				if bgFriends[name] then
					GameTooltip:AddDoubleLine("Battleground:", "|cffff4444" .. bgFriends[name] .. "|r", 0.7, 0.7, 0.7, 1, 0.3, 0.3)
				elseif onlineFriends[name] then
					GameTooltip:AddDoubleLine("Status:", "|cff88cc88Online|r", 0.7, 0.7, 0.7, 0.5, 0.8, 0.5)
				end
				GameTooltip:Show()
				if rank > 0 then
					ttRankIcon:ClearAllPoints()
					ttRankIcon:SetPoint("LEFT", GameTooltipTextLeft1, "LEFT", 0, 0)
					ttRankIcon:SetTexture(string.format("Interface\\PvPRankBadges\\PvPRank%02d", rank))
					ttRankIcon:Show()
				else
					ttRankIcon:Hide()
				end
			end,
			"onLeaveFunc", function()
				ttRankIcon:Hide()
				GameTooltip:Hide()
			end
		)

		if (tonumber(HonorSpy.db.realm.hs.limit) > 0 and i == tonumber(HonorSpy.db.realm.hs.limit)) then
			break
		end
	end
end

