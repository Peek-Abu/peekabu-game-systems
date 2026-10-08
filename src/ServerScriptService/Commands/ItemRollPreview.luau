--!strict
return {
	Name = "itemrollpreview",
	Aliases = {},
	Description = "Previews N sample affix rolls for an item type (reads the pool/chance; mints nothing).",
	Group = "Admins",
	Args = {
		{
			Type = "itemType",
			Name = "itemType",
			Description = "The item type to sample affix rolls for",
		},
		{
			Type = "number",
			Name = "samples",
			Description = "How many sample rolls (default 10)",
			Optional = true,
			Default = 10,
		},
	},
}
