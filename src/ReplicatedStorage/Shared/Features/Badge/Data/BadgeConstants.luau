--!strict
--[=[
	BadgeConstants: Odd Hours' badges (plan docs/superpowers/plans/2026-10-28-social-perks.md, Batch B). Static data
	(spec-exempt).

	`badgeId` is the Roblox badge id from the Creator Dashboard; 0 means the badge is not created yet, so it is not
	registered and never awarded (BadgeMilestoneSystem warns once at boot with the list). Fill an id in and the badge
	starts awarding: nothing else to touch. `name` and `description` are what to type on the Dashboard.

	@class BadgeConstants
]=]

export type Entry = {
	key: string,
	badgeId: number,
	name: string,
	description: string,
}

return table.freeze({
	GAME = table.freeze({
		{ key = "hired", badgeId = 3102324321053952, name = "Hired!", description = "Join the night crew." },
		{
			key = "clocked-in",
			badgeId = 3827245446127215,
			name = "Clocked In",
			description = "Finish your first shift.",
		},
		{
			key = "hide-and-squeak",
			badgeId = 0,
			name = "Hide and Squeak",
			description = "Stay hidden until the Manager walks away.",
		},
		{
			key = "clean-sweep",
			badgeId = 0,
			name = "Clean Sweep",
			description = "Meet the contract and get the whole crew out.",
		},
		{
			key = "night-shift-squad",
			badgeId = 215606491879488,
			name = "Night Shift Squad",
			description = "Finish a shift with 4 players.",
		},
		{ key = "rank-2", badgeId = 0, name = "Sweeper", description = "Reach the Sweeper rank." },
		{ key = "rank-3", badgeId = 0, name = "Cleaner", description = "Reach the Cleaner rank." },
		{ key = "rank-4", badgeId = 0, name = "Super Cleaner", description = "Reach the Super Cleaner rank." },
		{ key = "rank-5", badgeId = 0, name = "Little Boss", description = "Reach the Little Boss rank." },
		{ key = "rank-6", badgeId = 0, name = "Boss", description = "Reach the Boss rank." },
		{ key = "rank-7", badgeId = 0, name = "Big Boss", description = "Reach the Big Boss rank." },
		{
			key = "epic-pull",
			badgeId = 3516727949322324,
			name = "Lucky Locker",
			description = "Get an Epic or better from a Locker.",
		},
		{
			key = "legendary-pull",
			badgeId = 0,
			name = "Super Lucky Locker",
			description = "Get a Legendary or better from a Locker.",
		},
		{ key = "new-look", badgeId = 2884062252116463, name = "New Look", description = "Wear a new skin." },
	} :: { Entry }),
	-- A finished shift with at least this many on the crew earns Night Shift Squad.
	SQUAD_SIZE = 4,
})
