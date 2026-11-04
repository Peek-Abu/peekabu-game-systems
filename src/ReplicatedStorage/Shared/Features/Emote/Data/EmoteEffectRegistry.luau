--!strict
--[=[
	EmoteEffectRegistry: the effects a clip's markers start, keyed by AnimationRegistry key (`emote:<item id>`). Each
	effect starts on its `on` marker and ends on its `off` marker, or when the clip stops (finish, cancel, a newer clip,
	the character gone): EmoteEffectSystem. The marker times live in the clip itself (exported by
	characters/launch/animation-workbench/workflow/legendary-v2-2026-10-29/finish.py); a marker's Value reaches the
	effect (the `face` effect's face name). The effects are cosmetic and per client (EmoteVfxSystem plays them).

	@class EmoteEffectRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)

export type Effect = {
	-- EmoteVfxSystem's handler id.
	id: string,
	on: string,
	off: string?,
}
export type Entry = { effects: { Effect } }

local entries: { [string]: Entry } = {
	-- Bubble Buddy's Bubble Ride: bubbles stream from the wand, a giant bubble grows round her and floats her up, it
	-- pops, she lands in a little splash of bubbles. Her face changes on the beats (puffed cheeks, delighted, startled).
	["emote:Pippa.Bubbles"] = {
		effects = {
			{ id = "bubbleStream", on = "BubbleBlow", off = "BubbleBlowEnd" },
			{ id = "giantBubble", on = "BubbleGrow", off = "BubblePop" },
			{ id = "bubbleLand", on = "Land" },
			{ id = "bubbleGrowSound", on = "BubbleGrow" },
			{ id = "bubblePopSound", on = "BubblePop" },
			{ id = "face", on = "Face" },
		},
	},
	-- Sheriff Prickles' Big Roundup: a dust puff as the coil shakes out into a loop, a dust ring trailing under the
	-- overhead spin, a whoosh of dust on the throw, a puff on the yank, a tumbleweed rolling by during his hero pose,
	-- and his face (gritting, then smug).
	["emote:Prickles.Lasso"] = {
		effects = {
			{ id = "lassoPuff", on = "LoopOut" },
			{ id = "dustSwirl", on = "DustSwirl", off = "DustSwirlEnd" },
			{ id = "lassoThrow", on = "Throw" },
			{ id = "lassoPuff", on = "Yank" },
			{ id = "tumbleweed", on = "Tumbleweed" },
			{ id = "lassoCoilSound", on = "PropsShow" },
			{ id = "lassoShakeSound", on = "LoopOut" },
			{ id = "lassoSpinSound", on = "DustSwirl" },
			{ id = "lassoCrackSound", on = "Throw" },
			{ id = "lassoYankSound", on = "Yank" },
			{ id = "face", on = "Face" },
		},
	},
	-- PJ Cappy's Cocoa Sip: a mug sound as the mug appears, then a sip as it reaches his mouth (EmoteVfxConstants.SOUND_CUES);
	-- a few steam wisps off the mug while it is out; his eyes shut on the sip, then a happy face (Face markers).
	["emote:Cappy.CocoaSip"] = {
		effects = {
			{ id = "cocoaSounds", on = "PropsShow" },
			{ id = "cocoaSteam", on = "PropsShow", off = "PropsStow" },
			{ id = "face", on = "Face" },
		},
	},
	-- The hire reveals: their face timelines as Face markers (hire_markers.py), on the reveal screen's preview.
	pippahirereveal = { effects = { { id = "face", on = "Face" } } },
	prickleshirereveal = { effects = { { id = "face", on = "Face" } } },
	cappyhirereveal = { effects = { { id = "face", on = "Face" } } },
	-- PJ Cappy asleep (his skin's idle: eyes shut on its first frame) and his pillow slip (startled, awake, asleep).
	cappypjidle = { effects = { { id = "face", on = "Face" } } },
	cappypjfidget = { effects = { { id = "face", on = "Face" } } },
	-- Bubble Buddy's fidget: a few light bubbles while she blows (not Bubble Ride's stream), and her faces.
	pippabubblebuddyfidget = {
		effects = {
			{ id = "fidgetBubbles", on = "BubbleBlow", off = "BubbleBlowEnd" },
			{ id = "face", on = "Face" },
		},
	},
	-- Sheriff Prickles' quick draw (his skin's fidget): a squint while he checks for trouble, then his usual face.
	pricklessherifffidget = { effects = { { id = "face", on = "Face" } } },
	-- The ability clips: their faces as Face markers.
	cappyspotit = { effects = { { id = "face", on = "Face" } } },
	cappyspotitupper = { effects = { { id = "face", on = "Face" } } },
	pricklesplantenter = { effects = { { id = "face", on = "Face" } } },
	pricklesplanthold = { effects = { { id = "face", on = "Face" } } },
	pricklesplantexit = { effects = { { id = "face", on = "Face" } } },
}
for _, entry in entries do
	for _, effect in entry.effects do
		table.freeze(effect)
	end
	table.freeze(entry.effects)
	table.freeze(entry)
end
table.freeze(entries)

-- Every asset id (the entry's own and its variants) of a registered clip -> its key.
local byAsset: { [string]: string } = {}
for key in entries do
	local def = AnimationRegistry.get(key)
	if def ~= nil then
		byAsset[def.assetId] = key
		local variants = def.variants
		if variants ~= nil then
			for _, variant in variants do
				byAsset[variant] = key
			end
		end
	end
end

local EmoteEffectRegistry = {
	entries = entries,
}

--[=[
	The entry for an animation key, or nil when that clip has no effects.
]=]
function EmoteEffectRegistry.get(key: string): Entry?
	return entries[key]
end

--[=[
	The key of the effect clip with this asset id (`rbxassetid://N`), or nil.
]=]
function EmoteEffectRegistry.keyForAsset(assetId: string): string?
	return byAsset[assetId]
end

return table.freeze(EmoteEffectRegistry)
