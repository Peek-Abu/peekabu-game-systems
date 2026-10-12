--!strict
-- The server reads native Humanoid.Health at the pickup boundary. A surviving
-- character root after death (or a root-only model) must never grant a new hold.
local CarryCarrierRules = {}
function CarryCarrierRules.isAlive(health: number?): boolean
	return health ~= nil and health > 0
end
return CarryCarrierRules
