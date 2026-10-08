--!strict
--[=[
	CustomizationArtCheckSystem: reports, at boot, whether the ART matches the CATALOG.

	A System started by `CustomizationServiceServer` (one service per feature), not a service itself:
	it is a diagnostic, and nothing in the customization flow depends on it.

	The check itself is `CustomizationArtCheck` (pure, injected trees, fully specced). This System
	only supplies the two real trees and decides what to do with the answer: LOG it, never throw. Art is
	place-owned; a server must boot with a missing hat.

	@class CustomizationArtCheckSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local CustomizationCosmeticRegistry =
	require(ReplicatedStorage.Shared.Features.Customization.Data.CustomizationCosmeticRegistry)
local CustomizationArtCheck = require(ReplicatedStorage.Shared.Features.Customization.Rules.CustomizationArtCheck)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)

local log = Logger.new("CustomizationArtCheck")

-- The rig template every character is cloned from.
local RIG_NAME = "StarterCharacter"

-- Walks the registry-declared art path, or nil if any step is missing — which is itself a finding the
-- checker reports rather than an error to raise.
local function artRoot(): Instance?
	local current: Instance = ReplicatedStorage
	-- `ipairs`, like every other ordered walk here: the path is a SEQUENCE (Assets, then Customization)
	-- and generalized iteration leaves that order to chance rather than stating it.
	for _, segment in ipairs(CustomizationCosmeticRegistry.artRootPath()) do
		local nextFolder = current:FindFirstChild(segment)
		if not nextFolder then
			return nil
		end
		current = nextFolder
	end
	return current
end

local CustomizationArtCheckSystem = {}

--[=[
	Runs the check against the live art tree and the StarterCharacter rig.

	The rig is `StarterPlayer.StarterCharacter` rather than a spawned character: it is the template
	every character is cloned from, it exists before any player joins, and checking it at boot is the
	whole point. A socket that is missing there is missing for everyone.
	@return CustomizationArtCheck.Summary
]=]
function CustomizationArtCheckSystem.check(): CustomizationArtCheck.Summary
	local customs = artRoot()
	local rig = StarterPlayer:FindFirstChild(RIG_NAME)
	return CustomizationArtCheck.summarize(CustomizationArtCheck.check(customs, rig))
end

--[=[
	Logs the report. Warn-level per issue, so a broken art sync is visible in the output without
	anyone asking for it: that is the failure this exists to turn from silent into loud. Never throws.
	Art is place-owned, and a server must boot with a missing hat.
]=]
function CustomizationArtCheckSystem.run()
	local summary = CustomizationArtCheckSystem.check()
	if summary.ok then
		log:info("art conformance: all catalogued cosmetics resolve")
		return
	end
	log:warn(`art conformance: {summary.total} issue(s) — cosmetics below will NOT appear in game`)
	for _, line in summary.lines do
		log:warn(line)
	end
end

return CustomizationArtCheckSystem
