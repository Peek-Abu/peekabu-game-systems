--!strict
return {
	Name = "customizationcheckart",
	Aliases = { "conformance" },
	Description = "Re-checks that every catalogued cosmetic resolves to mountable art on the current rig.",
	Group = "Admins",
	-- No arguments on purpose: the check is over the WHOLE catalog. Narrowing it to one category would
	-- invite running it on the part you already suspect, which is the opposite of what it is for.
	Args = {},
}
