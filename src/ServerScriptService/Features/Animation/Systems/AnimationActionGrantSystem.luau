--!strict
--[=[
	AnimationActionGrantSystem: how a server-granted action plays.
	Gameplay owners decide WHETHER and WHAT; this decides HOW, before anything reaches the wire:

	- only a registered, replicable entry can be granted (locomotion stays local);
	- the speed is clamped to `MIN_SPEED`–`MAX_SPEED` and quantised to thousandths, the exact value every
	  receiver gets, so the grant's duration and the clients' clip times agree;
	- the variant is the caller's (checked) or the server's roll, never the client's;
	- the duration is `durationMs / speed` for a one-shot, nil (open-ended) for a looped entry;
	- a new grant on a layer replaces the current one unless the current one is `protected` and the new one
	  is not (an attack cannot cut a dodge or a hit reaction; a hit reaction can cut an attack).

	Pure: the registry entry and the roll are passed in.

	@class AnimationActionGrantSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationTypes = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationTypes)

type AnimationDef = AnimationTypes.AnimationDef
type AnimationLayer = AnimationTypes.AnimationLayer

local AnimationActionGrantSystem = {}

AnimationActionGrantSystem.MIN_SPEED = 0.25
AnimationActionGrantSystem.MAX_SPEED = 4

export type Options = {
	speed: number?,
	variant: number?,
}

-- What the grant record holds per layer, and from there the ActionStarted packet.
export type ActionData = {
	id: string,
	wireId: number,
	variant: number,
	speedMilli: number,
}

export type Grant = {
	def: AnimationDef,
	layer: AnimationLayer,
	data: ActionData,
	durationMs: number?,
}

--[=[
	Decide a grant for `id` (its registry entry `def`, nil when unregistered). `roll(count)` returns 1..count.
	Returns the grant, or nil and the reason.
]=]
function AnimationActionGrantSystem.decide(
	id: string,
	def: AnimationDef?,
	options: Options?,
	roll: (count: number) -> number
): (Grant?, string?)
	if def == nil then
		return nil, `"{id}" is not a registered animation`
	end
	local wireId = def.wireId
	local layer: AnimationLayer? = def.layer
	if def.replicable ~= true or wireId == nil or layer == nil then
		return nil, `"{id}" is not a replicable action (locomotion stays local)`
	end
	local speed = if options ~= nil and options.speed ~= nil then options.speed else 1
	if speed ~= speed or speed <= 0 or speed == math.huge then
		return nil, "speed must be a positive number"
	end
	local speedMilli = math.floor(
		math.clamp(speed, AnimationActionGrantSystem.MIN_SPEED, AnimationActionGrantSystem.MAX_SPEED) * 1000 + 0.5
	)
	local count = if def.variants ~= nil then #def.variants else 0
	local variant: number
	local requested = if options ~= nil then options.variant else nil
	if requested ~= nil then
		if requested ~= math.floor(requested) or requested < 0 or requested > count then
			return nil, `variant must be a whole number from 0 to {count} for "{id}"`
		end
		variant = requested
	else
		variant = roll(count + 1) - 1
	end
	local baseMs = def.durationMs
	return {
		def = def,
		layer = layer,
		data = { id = id, wireId = wireId, variant = variant, speedMilli = speedMilli },
		durationMs = if baseMs ~= nil then math.floor(baseMs * 1000 / speedMilli + 0.5) else nil,
	},
		nil
end

--[=[
	Whether a new grant `incoming` may replace the live grant `current` on the same layer.
]=]
function AnimationActionGrantSystem.canReplace(current: AnimationDef?, incoming: AnimationDef): boolean
	return current == nil or current.interruption ~= "protected" or incoming.interruption == "protected"
end

return AnimationActionGrantSystem
