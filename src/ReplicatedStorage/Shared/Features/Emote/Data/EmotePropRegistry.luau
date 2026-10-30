--!strict
--[=[
	EmotePropRegistry: the clips that bring out props, keyed by AnimationRegistry key (`emote:<item id>`, later the
	skins' showcase clips), each with the props it shows. A prop is the skin's own part in the character's
	EmployeeConstants.PROPS_FOLDER (fitted hidden by EmployeeOutfitSystem, in the skin's style) when the skin has it;
	otherwise each client mounts the emote's own template of that name (EmoteConstants.PROP_TEMPLATES_PATH), so an
	emote works in any skin (owner, 2026-10-29). The clip itself says when: its
	EmoteConstants.PROPS_SHOW / PROPS_STOW markers and keyframes (EmotePropSystem; owner pick, 2026-10-29: the timing
	lives in the clip, never a server timer).

	@class EmotePropRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)

export type Entry = {
	-- Shown on PROPS_SHOW, hidden on PROPS_STOW (and worn at the holster in between, if the skin wears them).
	props: { string },
	-- Hand props only a PROP_SHOW marker (Value = the prop's name) brings out, e.g. the coil shaken out into a loop.
	swaps: { string }?,
}

local entries: { [string]: Entry } = {
	-- Bubble Buddy's Bubble Ride: the kit bubble wand in the right hand. The duck ring stays worn at her waist.
	["emote:Pippa.Bubbles"] = { props = { "BubbleWand" } },
	-- Sheriff Prickles' Big Roundup: the hose coil in the right hand, shaken out into the LassoLoop for the spin and
	-- the throw, then coiled back up (PROP_HIDE / PROP_SHOW markers).
	["emote:Prickles.Lasso"] = { props = { "HoseLasso" }, swaps = { "LassoLoop" } },
	-- Sheriff Prickles' showcase idle (previews only): a PropsShow at the first frame and no stow, so the props
	-- stay out for as long as the loop plays; the coil leaves his hip while it does.
	pricklessheriffidle = { props = { "HoseLasso" } },
}
for _, entry in entries do
	table.freeze(entry.props)
	local swaps = entry.swaps
	if swaps ~= nil then
		table.freeze(swaps)
	end
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

local EmotePropRegistry = {
	entries = entries,
}

--[=[
	The entry for an animation key, or nil when that clip brings out no props.
	@param key string
	@return Entry?
]=]
function EmotePropRegistry.get(key: string): Entry?
	return entries[key]
end

--[=[
	The key of the prop clip with this asset id (`rbxassetid://N`), or nil: how a client names a track it did not
	start (another player's replicated emote).
	@param assetId string
	@return string?
]=]
function EmotePropRegistry.keyForAsset(assetId: string): string?
	return byAsset[assetId]
end

return table.freeze(EmotePropRegistry)
