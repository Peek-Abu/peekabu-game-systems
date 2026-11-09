--!strict
--[=[
	CoffeeRules: Coffee for the crew's decisions. The `coffee` account slice counts unspent coffees (vouchers): every
	purchase adds one in the same save as its receipt (exactly once), and the server spends it on a running shift
	(`spends`); one that cannot be spent yet (no shift running, a training run, or coffee already on) stays for the
	player's next shift, where the button says FREE. Coffee doubles the shift's Credits pay (`payScale`). Pure.

	@class CoffeeRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoffeeConstants = require(ReplicatedStorage.Shared.Features.Coffee.Data.CoffeeConstants)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

local CoffeeRules = {}

--[=[
	A new player's slice: no unspent coffees.
]=]
function CoffeeRules.fresh(): PlayerDataTypes.Coffee
	return { vouchers = 0 }
end

--[=[
	The data layer's validator: `vouchers` is a whole number, 0 or more.
]=]
function CoffeeRules.validate(value: PlayerDataTypes.Coffee): (boolean, string?)
	local vouchers = value.vouchers
	if type(vouchers) ~= "number" or vouchers < 0 or vouchers ~= math.floor(vouchers) then
		return false, "coffee.vouchers must be a whole number, 0 or more"
	end
	return true, nil
end

--[=[
	Whether the shift HUD offers coffee: only while a real shift (not training) runs and nobody has bought coffee yet.
]=]
function CoffeeRules.offered(phase: string, training: boolean, active: boolean): boolean
	return phase == "running" and not training and not active
end

--[=[
	Whether to spend one of the player's `vouchers` now: when coffee is offered and they have one.
]=]
function CoffeeRules.spends(phase: string, training: boolean, active: boolean, vouchers: number): boolean
	return vouchers > 0 and CoffeeRules.offered(phase, training, active)
end

--[=[
	What the shift's Credits pay is multiplied by.
]=]
function CoffeeRules.payScale(active: boolean): number
	return if active then CoffeeConstants.PAY_SCALE else 1
end

--[=[
	The office PA's line for `buyer`.
]=]
function CoffeeRules.paLine(buyer: string): string
	return string.format(CoffeeConstants.TEXT.pa, buyer)
end

return CoffeeRules
