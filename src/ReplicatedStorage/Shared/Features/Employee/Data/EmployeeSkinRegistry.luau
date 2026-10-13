--!strict
--[=[
	EmployeeSkinRegistry: which players wear a skin other than their employee's default.

	MVP ONLY. This is a hard-coded allowlist so the owner can wear a personal skin while playtesting with
	family; it is not an unlock, purchase or inventory system. Replace it with a real owned-skins slice
	(PlayerDataSliceSystem) before skins are earned or sold, and delete this module then.

	The skin name must exist in the employee's `skins` (EmployeeRegistry); an unknown name falls back to
	the default skin (EmployeeSkinRules.select).

	@class EmployeeSkinRegistry
]=]

-- UserId -> skin name. MVP only (see above).
local OWNER_SKINS: { [number]: string } = {
	[20661908] = "OwnerSpecial", -- icemonkey1 (the owner)
}

local EmployeeSkinRegistry = {}

-- The skin this player wears, nil for the employee's default.
function EmployeeSkinRegistry.skinFor(userId: number): string?
	return OWNER_SKINS[userId]
end

return EmployeeSkinRegistry
