--!strict
return {
	Name = "anomaly",
	Aliases = {},
	Description = "Dev: forces the run's exterior anomaly to exactly one id (see OfficeAnomalyConstants.IDS), none clears them, reroll restores the seed's pick.",
	Group = "Admins",
	Args = {
		{
			Type = "string",
			Name = "choice",
			Description = "an anomaly id, none or reroll",
		},
	},
}
