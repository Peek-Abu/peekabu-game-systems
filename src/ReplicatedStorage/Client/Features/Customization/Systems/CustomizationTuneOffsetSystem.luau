--!strict
--[=[
	CustomizationTuneOffsetSystem: the body of the `customizationtuneoffset` Cmdr command, run on the caller's own client
	(`ClientRun` in the command definition).

	Bodies are client-built (character replication), so the only rig wearing a cosmetic is on a client:
	the owner rig is `LocalPlayer.Character`. The command nudges a mounted piece there — the
	RigidConstraint binding follows the attachment edit live — and prints the registry literal to paste.
	It never saves and never touches another player's rig (puppets are views of other players).

	Client-only on purpose: it changes nothing authoritative and nothing that replicates, so it needs
	no server round-trip. That also means Cmdr's server-side BeforeRun allowlist does not gate it —
	acceptable for a visual-only instrument that moves a client's own local parts, which any client
	can already do.

	@class CustomizationTuneOffsetSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomizationDressSystem =
	require(ReplicatedStorage.Client.Features.Customization.Systems.CustomizationDressSystem)
local CustomizationPlanUtils = require(ReplicatedStorage.Shared.Features.Customization.Utils.CustomizationPlanUtils)

-- Formats the tuned value as the exact registry literal to paste, omitting zero components so the
-- catalog records only what was actually decided. Typing the number back in by hand is the POINT:
-- the registry is the source of truth, and a value that never lands in a commit never gets reviewed.
local function registrySnippet(x: number, y: number, z: number, rx: number, ry: number, rz: number): string
	-- Named fields rather than positional pairs: a mixed { string, number } array has no honest single
	-- element type, and forcing one would need exactly the kind of cast this project refuses.
	local axes: { { key: string, value: number } } = {
		{ key = "x", value = x },
		{ key = "y", value = y },
		{ key = "z", value = z },
		{ key = "rx", value = rx },
		{ key = "ry", value = ry },
		{ key = "rz", value = rz },
	}
	local parts: { string } = {}
	for _, axis in axes do
		if axis.value ~= 0 then
			table.insert(parts, `{axis.key} = {axis.value}`)
		end
	end
	if #parts == 0 then
		return "offset = {}"
	end
	-- Concatenation, not interpolation: `{` has meaning inside a Luau interpolated string.
	return "offset = { " .. table.concat(parts, ", ") .. " }"
end

--[=[
	@param localPlayer Player -- the client running the command
	@param target Player -- the player named in the command; must be `localPlayer`
	@param id string -- the mounted cosmetic id
	@return string -- the reply Cmdr prints
]=]
return function(
	localPlayer: Player,
	target: Player,
	id: string,
	x: number,
	y: number,
	z: number,
	rx: number,
	ry: number,
	rz: number
): string
	-- A non-finite component would produce a CFrame that silently corrupts every position derived from
	-- it, and NaN compares unequal to itself so it would not even be visible as a wrong number.
	for _, axis in { x, y, z, rx, ry, rz } do
		if axis ~= axis or axis == math.huge or axis == -math.huge then
			return "Offset components must be finite numbers."
		end
	end
	local snippet = registrySnippet(x, y, z, rx, ry, rz)
	if target ~= localPlayer then
		return `customizationtuneoffset moves your own rig only (other players are puppets on this client). Registry value for these numbers:\n    {snippet}`
	end
	local rig = localPlayer.Character
	if rig == nil then
		return `You have no body right now. Registry value for these numbers:\n    {snippet}`
	end
	-- An all-zero offset is a real request here: it puts the piece back on its authored placement.
	local offset = CustomizationPlanUtils.composeOffset({ x = x, y = y, z = z, rx = rx, ry = ry, rz = rz })
	local moved = CustomizationDressSystem.nudgeOffset(rig, id, offset or CFrame.identity)
	if moved == 0 then
		return `No mounted piece of "{id}" on your rig — is it equipped (and its art bound)? Registry value:\n    {snippet}`
	end
	return `Nudged {moved} piece(s) of "{id}" (not saved). Paste into its CosmeticRegistry row:\n    {snippet}`
end
