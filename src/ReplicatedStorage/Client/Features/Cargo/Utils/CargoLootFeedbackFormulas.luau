--!strict
--[=[
	CargoLootFeedbackFormulas: how the loot loop looks (docs/superpowers/specs/2026-10-15-cleanup-crew-loot-loop-design.md
	§5). A grimy valuable's darkening (a Highlight's fill transparency) and dust motes fade with its cleanliness and are
	drawn only near the camera; a buried pile's glint comes every GLINT_INTERVAL_MIN..MAX seconds and is seen only up
	close; an appraisal's stamp pops while it is fresh. Pure.

	@class CargoLootFeedbackFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)

local CargoLootFeedbackFormulas = {}

--[=[
	The grime Highlight's fill transparency at `clean`: GRIME_FILL_TRANSPARENCY fully grimy, 1 (none) when clean.
]=]
function CargoLootFeedbackFormulas.grimeFill(clean: number): number
	local from = CargoConstants.GRIME_FILL_TRANSPARENCY
	return from + (1 - from) * math.clamp(clean, 0, 1)
end

--[=[
	Dust motes per second at `clean`.
]=]
function CargoLootFeedbackFormulas.moteRate(clean: number): number
	return CargoConstants.GRIME_MOTE_RATE * (1 - math.clamp(clean, 0, 1))
end

--[=[
	Whether a valuable `distance` studs from the camera shows its grime: not while buried, not once clean.
]=]
function CargoLootFeedbackFormulas.grimeShown(distance: number, hidden: boolean, clean: number): boolean
	return not hidden and clean < 1 and distance <= CargoConstants.GRIME_VISUAL_DISTANCE
end

--[=[
	Seconds until a buried pile's next glint, from a uniform draw `u` (0-1).
]=]
function CargoLootFeedbackFormulas.glintDelay(u: number): number
	local low, high = CargoConstants.GLINT_INTERVAL_MIN, CargoConstants.GLINT_INTERVAL_MAX
	return low + (high - low) * math.clamp(u, 0, 1)
end

--[=[
	Whether a glint `distance` studs from the local character is drawn.
]=]
function CargoLootFeedbackFormulas.glintSeen(distance: number): boolean
	return distance <= CargoConstants.GLINT_DISTANCE
end

--[=[
	Whether an appraisal made at `appraisedAt` (server time; nil = never) is fresh enough at `now` for its stamp to pop.
]=]
function CargoLootFeedbackFormulas.stampFresh(appraisedAt: number?, now: number): boolean
	return appraisedAt ~= nil and now - appraisedAt <= CargoConstants.STAMP_FRESH_SECONDS
end

return CargoLootFeedbackFormulas
