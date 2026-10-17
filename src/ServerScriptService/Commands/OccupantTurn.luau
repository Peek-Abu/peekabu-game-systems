--!strict
return {
	Name = "occupantturn",
	Aliases = { "manager-turn" },
	Description = "Dev: forces the Manager's next head turn to a variant (snap, knowing, stare; auto clears). If he can see you, he starts it at you at once.",
	Group = "Admins",
	Args = {
		{
			Type = "string",
			Name = "variant",
			Description = "snap, knowing, stare or auto",
		},
	},
}
