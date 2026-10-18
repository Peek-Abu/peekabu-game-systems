--!strict
--[=[
	SprintStore: the local player's sprint as the HUD sees it (docs/superpowers/specs/
	2026-10-15-cleanup-crew-chase-kit-design.md §3): the stamina bar 0-1 and whether they sprint now, copied from the
	server's Player attributes by SprintServiceClient (`apply`, which reads anything it is given defensively). Nothing
	here is sent back. Client-only UI state.

	@class SprintStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

local stamina = Charm.atom(1)
local sprinting = Charm.atom(false)

-- Whether the stamina bar shows (SprintViewModel.bar: only while not full). The HUD lays out around the bar on this,
-- which flips twice a sprint, so it does not re-render with every stamina step; only the bar itself reads `stamina`.
local shown = Charm.computed(function(): boolean
	return stamina() < 1
end)

local SprintStore = {
	stamina = stamina,
	sprinting = sprinting,
	shown = shown,
}

--[=[
	Copies the server's attributes in: a stamina that is not a number reads full; anything but `true` is not sprinting.
]=]
function SprintStore.apply(rawStamina: unknown, rawSprinting: unknown)
	stamina(if type(rawStamina) == "number" and rawStamina == rawStamina then math.clamp(rawStamina, 0, 1) else 1)
	sprinting(rawSprinting == true)
end

return SprintStore
