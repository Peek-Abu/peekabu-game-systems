--!strict
--[=[
	AnimationActionRegistry: the server-granted action domain. Entries here are granted by the server
	(`AnimationServiceServer:play`) and played by the owning client on its character with the server's
	variant and speed; the engine replicates the character's animations to everyone else.

	The base has no real actions, so this domain holds STAND-INS that prove the pipeline through Cmdr
	`animationplay` until a game's combat, abilities or emotes bring their own domains. They reuse locomotion seed
	assets at Action priority: the locomotion entries themselves stay ambient, Core and local (an action
	at Core blends at half weight with locomotion, which the spike's observer-animation run showed).

	- `testleap` — a full-body one-shot with a variant (variant sync, speed, start alignment, stop-attacks).
	- `testguard` — a protected full-body one-shot (an attack on the same layer cannot replace it).
	- `testpose` — an open-ended looped upper-layer pose (two layers at once, explicit stop, safety cap).

	`durationMs` is each clip's length at speed 1, measured in Studio (R3 plan, Task 3 Step 1). The F4
	length check warns when a real clip disagrees with it. Wire ids are permanent: never reuse or
	renumber one, even after deleting its entry.

	@class AnimationActionRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationTypes = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationTypes)

type AnimationDomain = AnimationTypes.AnimationDomain
type AnimationDef = AnimationTypes.AnimationDef

local function freezeDef(def: AnimationDef): AnimationDef
	if def.variants ~= nil then
		table.freeze(def.variants)
	end
	return table.freeze(def)
end

local AnimationActionRegistry: AnimationDomain = table.freeze({
	testleap = freezeDef({
		assetId = "rbxassetid://11525667271",
		variants = { "rbxassetid://128472778455853" },
		priority = Enum.AnimationPriority.Action2,
		looped = false,
		interruption = "attack",
		replicable = true,
		wireId = 1,
		layer = "full",
		durationMs = 1200,
	}),
	testguard = freezeDef({
		assetId = "rbxassetid://11525764926",
		priority = Enum.AnimationPriority.Action2,
		looped = false,
		interruption = "protected",
		replicable = true,
		wireId = 2,
		layer = "full",
		durationMs = 1433,
	}),
	testpose = freezeDef({
		assetId = "rbxassetid://11868152140",
		priority = Enum.AnimationPriority.Action,
		looped = true,
		interruption = "ambient",
		replicable = true,
		wireId = 3,
		layer = "upper",
	}),
})

return AnimationActionRegistry
