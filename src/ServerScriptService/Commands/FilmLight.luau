--!strict
return {
	Name = "filmlight",
	Aliases = {},
	Description = "Filming: brightens or darkens the whole place for a shot. normal, dark or bright.",
	Group = "Admins",
	Args = {
		{ Type = "string", Name = "preset", Description = "normal, dark or bright" },
	},
}
