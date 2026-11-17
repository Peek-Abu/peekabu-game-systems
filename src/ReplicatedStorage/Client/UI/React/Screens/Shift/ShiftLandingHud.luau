--!strict
--[=[
	ShiftLandingHud: the landing status card's HUD widget (registered by ShiftServiceClient). When ShiftTransitSystem
	writes an arrival to ShiftTransitStore.landing (at the reveal of a hold, once per arrival at a shift, never in the
	hub or training), it draws ShiftLandingCard for that arrival: the night drawn from the arrival's seed and the run's
	map's danger (ShiftLandingViewModel.card, the map off the transit entry), at the game's one UI scale
	(PaperHudFrame, usePaperHudScale). A Heartbeat drives the card's `alpha` binding from the time since the reveal
	(ShiftLandingRules.alpha: in a moment after the route slip lifts, up about six seconds, then out), with no
	re-render; once ShiftLandingRules.over it stops and draws nothing until the next arrival. Hidden while the transit
	screen covers the view. HUD widget shell (exempt; the timing is the specced ShiftLandingRules, the words and place
	ShiftLandingViewModel).

	@class ShiftLandingHud
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local ShiftLandingRules = require(ReplicatedStorage.Client.Features.Shift.Rules.ShiftLandingRules)
local ShiftTransitStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftTransitStore)
local PaperHudFrame = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudFrame)
local usePaperHudScale = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperHudScale)
local ShiftLandingCard = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftLandingCard)
local ShiftLandingViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftLandingViewModel)

local e = React.createElement
local useAtom = ReactCharm.useAtom

local function ShiftLandingHud(): React.ReactNode
	local landing = useAtom(ShiftTransitStore.landing)
	local covered = useAtom(ShiftTransitStore.covered)
	local transit = useAtom(ShiftTransitStore.snapshot)
	local hudScale = usePaperHudScale()
	local alpha, setAlpha = React.useBinding(0)
	-- The arrival whose card has gone (0: none yet).
	local doneId, setDoneId = React.useState(0)
	local landingId = if landing ~= nil then landing.id else 0
	React.useEffect(function(): (() -> ())?
		local current = landing
		if current == nil then
			return nil
		end
		local connection: RBXScriptConnection? = nil
		local function step()
			local elapsed = os.clock() - current.at
			setAlpha(ShiftLandingRules.alpha(elapsed))
			if ShiftLandingRules.over(elapsed) then
				local live = connection
				if live ~= nil then
					live:Disconnect()
				end
				setDoneId(current.id)
			end
		end
		connection = RunService.Heartbeat:Connect(step)
		step()
		return function()
			local live = connection
			if live ~= nil then
				live:Disconnect()
			end
		end
	end, { landingId })
	if landing == nil or doneId == landing.id or covered then
		return nil
	end
	local view = ShiftLandingViewModel.card(landing.seed, if transit ~= nil then transit.map else nil)
	return e(PaperHudFrame, {
		scale = hudScale.scale,
		children = {
			card = e(ShiftLandingCard, {
				view = view,
				layout = hudScale.layout,
				viewport = hudScale.viewport,
				alpha = alpha,
			}),
		},
	})
end

return ShiftLandingHud
