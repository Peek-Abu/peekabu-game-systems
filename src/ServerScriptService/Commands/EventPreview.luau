--!strict
return {
	Name = "eventpreview",
	Aliases = { "previewevent" },
	Description = "Shows a limited-time event as live on this server (its Shop tab, Locker, hub props and pay), or 'off'.",
	Group = "Admins",
	Args = {
		{
			Type = "string",
			Name = "event",
			Description = "The event id (e.g. harvest), or off",
		},
	},
}
