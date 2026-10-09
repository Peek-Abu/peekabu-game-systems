--!strict
return {
	Name = "npcspawn",
	Aliases = {},
	Description = "Spawns an NPC of a registered kind in front of you.",
	Group = "Admins",
	Args = {
		{ Type = "string", Name = "kind", Description = "A registered NPC kind" },
	},
}
