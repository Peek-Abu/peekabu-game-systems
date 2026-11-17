--!strict
--[=[
	ShiftLandingCard.story: the landing status card in UI Labs, on the office backdrop. Controls: the map (Office one
	Gloom drop, School two), the seed (another night), Phone (the phone card at 844x390 design px), Animate (plays the
	real timing from ShiftLandingRules on Replay; off holds it fully in).
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local ShiftLandingRules = require(ReplicatedStorage.Client.Features.Shift.Rules.ShiftLandingRules)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftLandingCard = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftLandingCard)
local ShiftLandingViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftLandingViewModel)

local e = React.createElement

local OFFICE = "Office"
local SCHOOL = "School"

type StoryProps = {
	school: boolean,
	seed: number,
	phone: boolean,
	animate: boolean,
	replay: number,
}

local function Story(props: StoryProps): React.ReactNode
	local alpha, setAlpha = React.useBinding(1)
	local deps: { unknown } = { props.animate, props.replay }
	React.useEffect(function(): (() -> ())?
		if not props.animate then
			setAlpha(1)
			return nil
		end
		local startedAt = os.clock()
		local connection = RunService.Heartbeat:Connect(function()
			setAlpha(ShiftLandingRules.alpha(os.clock() - startedAt))
		end)
		return function()
			connection:Disconnect()
		end
	end, deps)
	local layout: UIPaperConstants.Layout = if props.phone then "phone" else "desktop"
	local viewport = if props.phone then Vector2.new(844, 390) else Vector2.new(1920, 1080)
	local view = ShiftLandingViewModel.card(props.seed, if props.school then "school" else "office")
	return e("Frame", {
		Size = UDim2.fromOffset(viewport.X, viewport.Y),
		BackgroundColor3 = UIPaperConstants.COLOR.office,
		BorderSizePixel = 0,
	}, {
		card = e(ShiftLandingCard, { view = view, layout = layout, viewport = viewport, alpha = alpha }),
	})
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Map = UILabs.Choose({ OFFICE, SCHOOL }),
		Seed = 42,
		Phone = false,
		Animate = false,
		Replay = 0,
	},
}, function(props)
	local controls = props.controls
	return e(Story, {
		school = controls.Map == SCHOOL,
		seed = controls.Seed,
		phone = controls.Phone,
		animate = controls.Animate,
		replay = controls.Replay,
	})
end)
