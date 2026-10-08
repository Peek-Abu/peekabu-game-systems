--!strict
return {
	Name = "animationreport",
	Aliases = { "anim-report" },
	Description = "Summarizes the animation registry (entries per domain) and asks YOUR client to probe every asset id, logging dead ids by registry key.",
	Group = "Admins",
	-- No arguments on purpose: the report is over the WHOLE registry (the customizationcheckart precedent), and
	-- the asset probe goes to the invoking client because PreloadAsync only means anything there.
	Args = {},
}
