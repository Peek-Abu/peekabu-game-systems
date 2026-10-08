--!strict
-- Runs on the caller's client (ClientRun): bodies are client-built, so the rig wearing the cosmetic is
-- there. There is deliberately no TuneOffsetServer — see CustomizationTuneOffsetSystem for why it is client-only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

return {
	Name = "customizationtuneoffset",
	Aliases = { "tune" },
	Description = "Nudges an equipped cosmetic's fit on your own rig, live, and prints the registry value to paste. Does NOT save.",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player whose cosmetic to nudge" },
		{ Type = "string", Name = "id", Description = "The equipped cosmetic id (e.g. Eyebrows4)" },
		-- Studs and degrees, all defaulting to zero, so a tuning pass is one axis at a time: type the
		-- axis you are adjusting and leave the rest alone.
		{ Type = "number", Name = "x", Description = "Studs right (+) / left (-)", Default = 0 },
		{ Type = "number", Name = "y", Description = "Studs up (+) / down (-)", Default = 0 },
		{ Type = "number", Name = "z", Description = "Studs forward (+) / back (-)", Default = 0 },
		{ Type = "number", Name = "rx", Description = "Degrees pitch", Default = 0 },
		{ Type = "number", Name = "ry", Description = "Degrees yaw", Default = 0 },
		{ Type = "number", Name = "rz", Description = "Degrees roll", Default = 0 },
	},
	ClientRun = function(
		_context,
		target: Player,
		id: string,
		x: number,
		y: number,
		z: number,
		rx: number,
		ry: number,
		rz: number
	)
		local tuneOffset =
			require(ReplicatedStorage.Client.Features.Customization.Systems.CustomizationTuneOffsetSystem)
		return tuneOffset(Players.LocalPlayer, target, id, x, y, z, rx, ry, rz)
	end,
}
