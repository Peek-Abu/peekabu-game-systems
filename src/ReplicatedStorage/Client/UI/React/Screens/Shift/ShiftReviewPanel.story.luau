--!strict
--[=[
	ShiftReviewPanel.story: the performance review over the dark office, in Studio's edit mode (UI Labs), for the
	side-by-side check against Figma 5a (31:557), 5c (31:611) and 5b (31:665). The review is drawn in a fixed
	screen-sized frame centred in the viewport: `Variant` picks quota met (5a) or missed (5c), `Phone` switches to the
	844x390 landscape phone (5b), `MyVote` marks the local player's vote (or none) and `Small` draws desktop at
	1366x768 (the folder scales down to fit). Crew Sam, Alex, Jo and you (userId 4); 20 s left on the vote. `Rank` draws
	the company rank slip: none (not published yet), a first shift at level 1, a promotion to level 2 that has
	landed, or a caught shift with its incident line.

	@class ShiftReviewPanel.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftReviewPanel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewPanel)
local ShiftReviewViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewViewModel)
local ShiftStoryFixtures = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftStoryFixtures)
local RankViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Rank.RankViewModel)

local e = React.createElement

local MET = "5a met"
local MISSED = "5c missed"
local PHONE = Vector2.new(844, 390)
local DESKTOP = Vector2.new(1920, 1080)
local SMALL = Vector2.new(1366, 768)
local ME = 4
-- Story time; the vote closes 20 s later.
local NOW = 0

-- The rating shown when the quota is met (a missed quota is always NEEDS IMPROVEMENT); EXCEEDS is the longest text.
local function ratingOf(choice: string): ShiftTypes.Rating
	return if choice == "exceeds" then "exceeds" else "satisfactory"
end

local function results(met: boolean, rating: ShiftTypes.Rating): ShiftTypes.ShiftResults
	local titles = ShiftConstants.AWARD_TITLES
	return {
		outcome = if met then "clockout" else "timeout",
		quota = 350,
		cleared = if met then 362 else 288,
		bonus = if met then 215 else 90,
		salvage = if met then 5 else 2,
		piles = 12,
		catches = if met then 3 else 5,
		offered = 9,
		rating = if met then rating else "needsImprovement",
		quotaMet = met,
		crew = {},
		awards = if met
			then {
				{ title = titles.employee, name = "Sam", userId = 1, detail = "hauled 140" },
				{ title = titles.rehired, name = "Alex", userId = 2, detail = "caught twice" },
				{ title = titles.butterfingers, name = "Jo", userId = 3, detail = "dropped the fish tank" },
				{ title = titles.quietest, name = "Me", userId = ME, detail = "never heard once" },
			}
			else {
				{ title = titles.employee, name = "Jo", userId = 3, detail = "hauled 120" },
				{ title = titles.rehired, name = "Alex", userId = 2, detail = "caught 3 times" },
				{ title = titles.butterfingers, name = "Sam", userId = 1, detail = "dropped the printer" },
				{ title = titles.loudest, name = "Me", userId = ME, detail = "woke the Manager 4 times" },
			},
	}
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Variant = UILabs.Choose({ MET, MISSED }),
		Phone = false,
		MyVote = UILabs.Choose({ "another", "depot", "none" }),
		Small = false,
		Rating = UILabs.Choose({ "satisfactory", "exceeds" }),
		Rank = UILabs.Choose({ "promoted", "first shift", "caught", "none" }),
	},
}, function(props)
	local met = props.controls.Variant ~= MISSED
	local phone: boolean = props.controls.Phone
	local small: boolean = props.controls.Small
	local choice: string = props.controls.MyVote
	local snapshot = ShiftStoryFixtures.snapshot({ cleared = if met then 362 else 288, quotaMet = met })
	snapshot.phase = "results"
	snapshot.voteEndsAt = NOW + 20
	snapshot.votesAnother = 2
	snapshot.votesDepot = 1
	snapshot.results = results(met, ratingOf(props.controls.Rating))
	-- The rank slip reads its own one-line review for you (the panel's review keeps its crew list empty).
	local rankChoice: string = props.controls.Rank
	local mine: ShiftTypes.CrewLine = {
		userId = ME,
		name = "Me",
		banked = 60,
		piles = 3,
		salvage = 1,
		caught = if rankChoice == "caught" then 1 else 0,
		items = 4,
		overtimeSalvage = 0,
	}
	local rankReview = results(met, ratingOf(props.controls.Rating))
	rankReview.crew = { mine }
	local rankState: RankViewModel.Rank? = if rankChoice == "promoted"
		then { xp = 55, prevXp = 16 }
		elseif rankChoice == "first shift" then { xp = 39, prevXp = 0 }
		elseif rankChoice == "caught" then { xp = 29, prevXp = 0 }
		else nil
	local rank = RankViewModel.slip(rankState, rankReview, { ME }, ME)
	local screen = if phone then PHONE elseif small then SMALL else DESKTOP
	local layout: UIPaperConstants.Layout = if phone then "phone" else "desktop"
	local view = ShiftReviewViewModel.review(snapshot, if choice == "none" then nil else choice, ME, NOW, phone)
	local panel = if view ~= nil
		then e(ShiftReviewPanel, {
			view = view,
			layout = layout,
			scale = ShiftReviewViewModel.fit(screen, phone),
			onVote = function(vote: ShiftTypes.Vote)
				print(`ShiftReviewPanel.story: vote {vote}`)
			end,
			rank = rank,
		})
		else nil
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIPaperConstants.COLOR.night,
		BorderSizePixel = 0,
	}, {
		-- The office behind the review, in a fixed screen-sized frame.
		screen = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(screen.X, screen.Y),
			BackgroundColor3 = UIPaperConstants.COLOR.office,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, { panel = panel }),
	})
end)
