--!strict
--[=[
	filmlight: brightens or darkens the whole place for a shot (Lighting.ExposureCompensation, replicated to everyone).
	The place's own value is remembered on the first change, and `normal` returns to it. Admins only (the Admins group
	fails closed in AdminServiceServer).
]=]
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FilmConstants = require(ReplicatedStorage.Shared.Features.Film.Data.FilmConstants)

-- The place's own exposure, read before the first change (nil while unchanged).
local base: number? = nil

return function(_context: { Executor: Player }, preset: string)
	local name = string.lower(preset)
	local offset = FilmConstants.LIGHT_PRESETS[name]
	if offset == nil then
		return `Unknown preset "{preset}". Use normal, dark or bright.`
	end
	local own = base or Lighting.ExposureCompensation
	Lighting.ExposureCompensation = own + offset
	base = if offset == 0 then nil else own
	return `Light: {name}.`
end
