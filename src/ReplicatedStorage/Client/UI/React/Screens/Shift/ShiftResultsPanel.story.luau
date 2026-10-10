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
		quotaMet = controls.QuotaMet,
		crew = {
			{ name = "Ava", banked = 200, piles = 6, salvage = 2 },
			{ name = "Ben", banked = 180, piles = 6, salvage = 1 },
		},
		awards = { { title = "Top Hauler", name = "Ava" }, { title = "Dust Devil", name = "Ava" } },
	}
	local snapshot: ShiftTypes.ShiftSnapshot = {
		phase = "results",
		sub = "normal",
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
