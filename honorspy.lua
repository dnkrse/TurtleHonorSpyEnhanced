-- TurtleHonorSpyEnhanced: core addon setup
-- Slash commands are in commands.lua; minimap button is in minimap.lua.

HonorSpy = AceLibrary("AceAddon-2.0"):new("AceDB-2.0", "AceEvent-2.0", "AceModuleCore-2.0")

HonorSpy:RegisterDB("HonorSpyDB")
HonorSpy:RegisterDefaults('realm', {
	hs = {
		overlayPos          = nil,
		overlayHidden       = false,
		minimapAngle        = 200,
		minimapHidden       = false,
		addonUsers          = {},
		weeklyStartProgress = nil,
		weeklyResetStamp    = 0,
		sessionStartHonor   = 0,
		honorHistory        = {},
		histCollapsed       = {},
	}
})

function HonorSpy:OnEnable()
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function HonorSpy:PLAYER_ENTERING_WORLD()
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	-- Minimap button creation is handled by minimap.lua
end