--!strict
--[=[
    ShiftHudPanel.story: approved compact HUD in UI Labs. EmptyHands, Equipped and CrewOpen expose
    equipment/disclosure states; Variant exposes quota/overtime/clock-out, and Phone uses an 844x390 frame.
    Compare with Figma 75:2732; real touch input is verified separately from this visual story.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftCrewViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftCrewViewModel)
local ShiftHudPanel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftCompactHudPanel)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
local ShiftStoryFixtures = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftStoryFixtures)

local e = React.createElement

local NORMAL = "1a normal"
local QUOTA_MET = "1b quota met"
local OVERTIME = "1c overtime + clock-out"
-- Figma 1d / 1e: a landscape phone (iPhone 14).
local PHONE_WIDTH = 844
local PHONE_HEIGHT = 390

local function changesFor(variant: string, secondsLeft: number): ShiftStoryFixtures.SnapshotChanges
	if variant == QUOTA_MET then
		return { endsAt = secondsLeft, cleared = 362, quotaMet = true }
	elseif variant == OVERTIME then
		return {
			endsAt = secondsLeft,
			cleared = 362,
			quotaMet = true,
			stage = "overtime",
			tier = 2,
			sub = "clockout",
			clockOutAt = 7,
		}
	end
	return { endsAt = secondsLeft }
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Variant = UILabs.Choose({ NORMAL, QUOTA_MET, OVERTIME }),
		Phone = false,
		EmptyHands = true,
		Equipped = true,
		CrewOpen = false,
		SecondsLeft = 252,
	},
}, function(props)
	local variant: string = props.controls.Variant
	local phone: boolean = props.controls.Phone
	local secondsLeft: number = props.controls.SecondsLeft
	local snapshot = ShiftStoryFixtures.snapshot(changesFor(variant, secondsLeft))
	local me: PublicPlayerTypes.PublicPlayer = {}
	for key, value in ShiftStoryFixtures.me do
		if not props.controls.EmptyHands or (key ~= "carrying" and key ~= "pocket1" and key ~= "pocket2") then
			me[key] = value
		end
	end
	me.vacuumEquipped = props.controls.Equipped
	local view = ShiftHudViewModel.hud(snapshot, me, 0, false)
	local roster = ShiftCrewViewModel.roster(
		snapshot.crew,
		ShiftStoryFixtures.players,
		ShiftStoryFixtures.names,
		snapshot.truck,
		variant == OVERTIME,
		0
	)
	local layout: UIPaperConstants.Layout = if phone then "phone" else "desktop"
	-- The screen frame's real size drives the same layout rules the live HUD uses (resize the viewport to check them).
	local screenSize, setScreenSize = React.useState(Vector2.new(1920, 1080))
	local hud = if view ~= nil
		then e(ShiftHudPanel, {
			view = view,
			roster = roster,
			layout = layout,
			viewport = if phone then Vector2.new(PHONE_WIDTH, PHONE_HEIGHT) else screenSize,
			crewOpen = props.controls.CrewOpen,
		})
		else nil
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = if phone then UIPaperConstants.COLOR.night else UIPaperConstants.COLOR.office,
		BorderSizePixel = 0,
	}, {
		-- On phone, a landscape phone screen centred in the viewport; on desktop, the viewport itself.
		screen = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = if phone then UDim2.fromOffset(PHONE_WIDTH, PHONE_HEIGHT) else UDim2.fromScale(1, 1),
			BackgroundColor3 = UIPaperConstants.COLOR.office,
			BorderSizePixel = 0,
			ClipsDescendants = phone,
			[React.Change.AbsoluteSize] = function(frame: Frame)
				setScreenSize(frame.AbsoluteSize)
			end,
		}, { hud = hud }),
	})
end)
