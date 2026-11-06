--!strict
--[=[
	shiftovertime: a filmmaker's skip straight into overtime (ShiftServiceServer:forceOvertime). Admins only (the
	Admins group fails closed in AdminServiceServer).
]=]
local ServerScriptService = game:GetService("ServerScriptService")

local ShiftServiceServer = require(ServerScriptService.Features.Shift.ShiftServiceServer)

return function(_context: { Executor: Player })
	if ShiftServiceServer:forceOvertime() then
		return "Overtime started."
	end
	return "Not now: overtime needs a running shift that is not already in overtime or clocking out."
end
