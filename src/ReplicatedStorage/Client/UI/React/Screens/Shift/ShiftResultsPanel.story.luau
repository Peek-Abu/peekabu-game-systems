--!strict
--[=[
	ShiftResultsPanel.story: the placeholder performance review with a sample crew, in Studio's edit mode
	(UI Labs).

	@class ShiftResultsPanel.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
local ShiftResultsPanel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftResultsPanel)

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		QuotaMet = true,
		VotedAnother = false,
	},
}, function(props)
	local controls = props.controls
	local review: ShiftTypes.ShiftResults = {
		outcome = "clockout",
		quota = 350,
		cleared = if controls.QuotaMet then 380 else 210,
		bonus = 95,
		salvage = 3,
		piles = 12,
		catches = 0,
		offered = 9,
		rating = if controls.QuotaMet then "satisfactory" else "needsImprovement",
		quotaMet = controls.QuotaMet,
		crew = {
			{ userId = 1, name = "Ava", banked = 200, piles = 6, salvage = 2, caught = 0 },
			{ userId = 2, name = "Ben", banked = 180, piles = 6, salvage = 1, caught = 0 },
		},
		awards = {
			{ title = "EMPLOYEE OF THE NIGHT", name = "Ava", userId = 1, detail = "hauled 200" },
			{ title = "QUIETEST FEET", name = "Ben", userId = 2, detail = "never heard once" },
		},
	}
	local snapshot: ShiftTypes.ShiftSnapshot = {
		phase = "results",
		sub = "normal",
		stage = "normal",
		tier = 0,
		shift = 1,
		voteEndsAt = 24,
		quota = 350,
		cleared = review.cleared,
		bonus = review.bonus,
		quotaMet = review.quotaMet,
		variant = "B",
		votesAnother = if controls.VotedAnother then 1 else 0,
		votesDepot = 0,
		results = review,
		crew = { 1, 2 },
	}
	local view = ShiftHudViewModel.results(snapshot, 0)
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Tokens.color.background,
	}, {
		results = if view ~= nil
			then e(ShiftResultsPanel, {
				view = view,
				myVote = if controls.VotedAnother then "another" else nil,
				onVote = function(choice)
					print("vote", choice)
				end,
			})
			else nil,
	})
end)
