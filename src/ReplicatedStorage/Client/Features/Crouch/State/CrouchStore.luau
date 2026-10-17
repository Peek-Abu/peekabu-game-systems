--!strict
--[=[
	CrouchStore: whether the local player's character is crouched, as the HUD sees it (the phone's CROUCH button
	lights while it is), copied from the server's Crouching attribute by CrouchServiceClient (`apply`, which reads
	anything it is given defensively). Nothing here is sent back. Client-only UI state.

	@class CrouchStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

local crouching = Charm.atom(false)

local CrouchStore = {
	crouching = crouching,
}

--[=[
	Copies the server's attribute in: anything but `true` is standing.
]=]
function CrouchStore.apply(raw: unknown)
	crouching(raw == true)
end

return CrouchStore
