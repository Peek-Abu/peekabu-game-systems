--!strict
--[=[
	ShiftLandingReadout.story: the landing readout in UI Labs, on the office backdrop. Controls: Screen (1 temperature
	and weather, 2 the time, 3 the anomaly level, or Play: the three in turn with the real timing from
	ShiftLandingRules, again on Replay), the map (Office one Gloom drop, School two), the seed (another night), the
	crew size (the desktop readout sits under the crew list) and Phone (the phone layout at 844x390 design px). Night
	(0: a quick shift) plays a Night Shift's four screens: NIGHT n / WEEK w first (screen 4 is then the anomaly level,
	a drop more a week).
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local ShiftLandingRules = require(ReplicatedStorage.Client.Features.Shift.Rules.ShiftLandingRules)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftLandingReadout = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftLandingReadout)
local ShiftLandingViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftLandingViewModel)
local ShiftNightFormulas = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftNightFormulas)

local e = React.createElement

local OFFICE = "Office"
local SCHOOL = "School"
local PLAY = "Play"
local SCREEN_CHOICES = { PLAY, "1", "2", "3", "4" }

type StoryProps = {
	choice: string,
	school: boolean,
	seed: number,
	crew: number,
	phone: boolean,
	replay: number,
	night: number,
}

local function Story(props: StoryProps): React.ReactNode
	local alpha, setAlpha = React.useBinding(1)
	local playing, setPlaying = React.useState(1)
	local run: ShiftLandingViewModel.NightInput? = if props.night > 0
		then { night = props.night, week = ShiftNightFormulas.week(props.night) }
		else nil
	local count = if run ~= nil then ShiftLandingRules.SCREENS + 1 else ShiftLandingRules.SCREENS
	local deps: { unknown } = { props.choice, props.replay, count }
	React.useEffect(function(): (() -> ())?
		if props.choice ~= PLAY then
			setAlpha(1)
			return nil
		end
		local startedAt = os.clock()
		local connection = RunService.Heartbeat:Connect(function()
			local index, value = ShiftLandingRules.screenAt(os.clock() - startedAt, count)
			setAlpha(value)
			if index > 0 then
				setPlaying(index)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, deps)
	local index = if props.choice == PLAY then playing else tonumber(props.choice) or 1
	local layout: UIPaperConstants.Layout = if props.phone then "phone" else "desktop"
	local viewport = if props.phone then Vector2.new(844, 390) else Vector2.new(1920, 1080)
	local screens = ShiftLandingViewModel.screens(props.seed, if props.school then "school" else "office", run)
	-- Keyed by the screen, so each one mounts fresh as it tweens in.
	local children: { [string]: React.ReactNode } = {
		[`screen{index}`] = e(ShiftLandingReadout, {
			screen = screens[index] or screens[1],
			layout = layout,
			frame = ShiftLandingViewModel.frame(layout, viewport, props.crew),
			alpha = alpha,
		}),
	}
	return e("Frame", {
		Size = UDim2.fromOffset(viewport.X, viewport.Y),
		BackgroundColor3 = UIPaperConstants.COLOR.office,
		BorderSizePixel = 0,
	}, children)
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Screen = UILabs.Choose(SCREEN_CHOICES),
		Map = UILabs.Choose({ OFFICE, SCHOOL }),
		Seed = 42,
		Crew = 3,
		Phone = false,
		Replay = 0,
		Night = 4,
	},
}, function(props)
	local controls = props.controls
	return e(Story, {
		choice = controls.Screen,
		school = controls.Map == SCHOOL,
		seed = controls.Seed,
		crew = controls.Crew,
		phone = controls.Phone,
		replay = controls.Replay,
		night = controls.Night,
	})
end)
