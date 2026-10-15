--!strict
--[=[
	CargoFeedbackUtils: Cargo's feel decisions (Cleanup Crew spec §7 "Banking: item swoops into the truck,
	cha-ching, '+15' floater"; §4 drops by weight, fragile, the jug's splash, rattly, search, the office plant's
	leaves). The floater lines for a Load (clearance, then the bonus actually credited; zero omitted; rounded
	like the review), the `Banked` announcement the server sends for a Load, the swoop's arc (a quadratic curve
	lifted `height` at its control point), which sound a drop or a noise makes, and the hands/pocket cues read
	from the public fields. Also snapshots server-owned item attributes before banking destroys it.

	@class CargoFeedbackUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local ArtVisualSystem = require(ReplicatedStorage.Shared.Features.Art.Systems.ArtVisualSystem)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)

export type Tone = "clearance" | "bonus"

export type Floater = {
	text: string,
	tone: Tone,
}

-- What the server announces for one Load (CargoEvents.packets.Banked).
export type BankedMessage = {
	kinds: { string },
	visuals: { CargoTypes.VisualIdentity },
	from: Vector3,
	to: Vector3,
	clearance: number,
	bonus: number,
}

-- Older callers/recorded messages may have no visual metadata; the client uses the catalog fallback.
export type ReceivedBankedMessage = {
	kinds: { string },
	visuals: { CargoTypes.VisualIdentity }?,
	from: Vector3,
	to: Vector3,
	clearance: number,
	bonus: number,
}

-- The Banked packet carries its amounts as uint16.
local MAX_AMOUNT = 65535

local function round(value: number): number
	return math.floor(value + 0.5)
end

local CargoFeedbackUtils = {}

function CargoFeedbackUtils.entryOf(object: Instance): CargoTypes.CargoEntry?
	local kind = object:GetAttribute(CarryConstants.KIND_ATTRIBUTE)
	local id = object:GetAttribute(CargoConstants.ID_ATTRIBUTE)
	local value = object:GetAttribute(CargoConstants.VALUE_ATTRIBUTE)
	if type(kind) ~= "string" or not CargoRegistry.has(kind) or type(id) ~= "number" or type(value) ~= "number" then
		return nil
	end
	local visual: CargoTypes.VisualIdentity? = nil
	if object:IsA("BasePart") then
		local model = object:FindFirstChild("ArtVisual")
		visual = {
			kitId = ArtVisualSystem.resolveKit(model or object),
			proxySize = object.Size,
			rotation = object.CFrame.Rotation,
		}
	end
	return { kind = kind, value = value, visual = visual }
end

function CargoFeedbackUtils.floaters(clearance: number, bonus: number): { Floater }
	local list: { Floater } = {}
	local cleared = round(clearance)
	local earned = round(bonus)
	if cleared > 0 then
		table.insert(list, { text = `+{cleared}`, tone = "clearance" })
	end
	if earned > 0 then
		table.insert(list, { text = `+{earned}`, tone = "bonus" })
	end
	return list
end

--[=[
	The `Banked` announcement for a Load: the kinds loaded, the swoop from `from` to the top of the bed (centre
	`bed`, size `bedSize`), and the amounts credited, rounded like the review and clamped to the packet's range.
	`credited` is the banking handler's second value (the bonus after any overtime multiplier); nil = the deposit's.
]=]
function CargoFeedbackUtils.banked(
	deposit: CargoTypes.Deposit,
	from: Vector3,
	bed: Vector3,
	bedSize: Vector3,
	credited: number?
): BankedMessage
	local kinds: { string } = {}
	local visuals: { CargoTypes.VisualIdentity } = {}
	for _, item in deposit.items do
		table.insert(kinds, item.kind)
		local def = CargoRegistry.get(item.kind)
		table.insert(
			visuals,
			if item.visual ~= nil
				then table.clone(item.visual)
				else {
					kitId = "",
					proxySize = if def ~= nil then def.partSize else Vector3.one,
					rotation = CFrame.identity,
				}
		)
	end
	return {
		kinds = kinds,
		visuals = visuals,
		from = from,
		to = bed + Vector3.new(0, bedSize.Y / 2, 0),
		clearance = math.clamp(round(deposit.clearance), 0, MAX_AMOUNT),
		bonus = math.clamp(round(credited or deposit.bonus), 0, MAX_AMOUNT),
	}
end

function CargoFeedbackUtils.arc(from: Vector3, to: Vector3, alpha: number, height: number): Vector3
	local t = math.clamp(alpha, 0, 1)
	local control = (from + to) / 2 + Vector3.new(0, height, 0)
	local first = from:Lerp(control, t)
	local second = control:Lerp(to, t)
	return first:Lerp(second, t)
end

function CargoFeedbackUtils.dropSound(def: CargoTypes.ItemDef): string
	if def.splashes then
		return "cargoSplash"
	end
	if def.fragile then
		return "cargoShatter"
	end
	if def.size == "heavy" or def.size == "bulky" then
		return "cargoThudHeavy"
	end
	return "cargoThudLight"
end

function CargoFeedbackUtils.noiseSound(source: string): string?
	if source == "rattle" then
		return "cargoRattle"
	end
	if source == "search" then
		return "cargoRummage"
	end
	return nil
end

function CargoFeedbackUtils.pickedUp(before: string?, after: string?): boolean
	return after ~= nil and after ~= before
end

function CargoFeedbackUtils.pocketed(before: number, after: number): boolean
	return after > before
end

function CargoFeedbackUtils.blocksView(kind: string?): boolean
	if kind == nil then
		return false
	end
	local def = CargoRegistry.get(kind)
	return def ~= nil and def.blocksView
end

return CargoFeedbackUtils
