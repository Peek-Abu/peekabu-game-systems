--!strict
--[=[
	DepotTruckPopConstants: how a hub truck shows (crew hosting, characters/launch/crew-hosting/DESIGN.md batch 4). An
	empty bay holds a faint ghost of the truck; when a host steps in their truck pops in (a quick dust puff, a bounce
	from START_SCALE and a fade from the ghost to solid over POP_SECONDS); when the bay empties it fades back to the
	ghost over LEAVE_SECONDS. DepotTruckPopFormulas does the maths, DepotTruckGhostSystem the drawing.

	- PUFF: a ring of chunky dust clouds round the truck's wheels with a few Gleam bubbles. Kid-safe: no red, no light.

	@class DepotTruckPopConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxShared = ReplicatedStorage.Shared.Features.Vfx
local VfxAssets = require(VfxShared.Data.VfxAssets)
local VfxConstants = require(VfxShared.Data.VfxConstants)
local VfxFormulas = require(VfxShared.Utils.VfxFormulas)
local VfxTypes = require(VfxShared.Data.VfxTypes)

local T = VfxAssets.TEXTURES
local P = VfxConstants.PALETTE
local seq = VfxFormulas.sequence
local gradient = VfxFormulas.gradient

local PUFF: VfxTypes.Burst = {
	layers = {
		{
			texture = T.puff,
			color = gradient({ P.porcelain, P.dust, P.dustDark }),
			size = seq({ { 0, 2 }, { 0.4, 4 }, { 1, 5 } }),
			transparency = seq({ { 0, 0.1 }, { 0.6, 0.4 }, { 1, 1 } }),
			lifetime = NumberRange.new(0.5, 0.9),
			speed = NumberRange.new(10, 16),
			count = 18,
			spread = Vector2.new(90, 10),
			acceleration = Vector3.new(0, 2, 0),
			drag = 6,
			rotation = NumberRange.new(0, 360),
			rotSpeed = NumberRange.new(-60, 60),
			lightInfluence = 0.6,
		},
		{
			texture = T.bubble,
			color = gradient({ P.gleamLight, P.gleam }),
			size = seq({ { 0, 0 }, { 0.25, 1 }, { 1, 0 } }),
			transparency = seq({ { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } }),
			lifetime = NumberRange.new(0.6, 0.9),
			speed = NumberRange.new(8, 12),
			count = 8,
			delay = 0.1,
			spread = Vector2.new(40, 40),
			acceleration = Vector3.new(0, -10, 0),
			drag = 1,
			rotation = NumberRange.new(-20, 20),
			lightEmission = 0.5,
			lightInfluence = 0.2,
			zOffset = 1,
		},
	},
}

return table.freeze({
	PUFF_ID = "depotTruckPop",
	PUFF = PUFF,
	POP_SECONDS = 0.5,
	LEAVE_SECONDS = 0.4,
	-- The pop's first frame is this big; BACK is its ease-out-back strength (3: a peak about 7% over full size).
	START_SCALE = 0.7,
	BACK = 3,
	-- How see-through the empty bay's ghost truck is (its outline stays: GHOST_OUTLINE).
	GHOST_TRANSPARENCY = 0.85,
	GHOST_OUTLINE = Color3.fromRGB(250, 246, 236),
	GHOST_OUTLINE_TRANSPARENCY = 0.35,
})
