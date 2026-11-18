--!strict
--[=[
	ShiftLandingHud: the landing readout's HUD widget (registered by ShiftServiceClient). When ShiftTransitSystem
	writes an arrival to ShiftTransitStore.landing (at the reveal of a hold, once per arrival at a shift, never in the
	hub or training), it waits for the big ARRIVAL contract card in the centre to close: each frame it looks at
	DepotStore.card (kind "arrival") through ShiftLandingRules.watch, and starts at ShiftLandingRules.startAt (a beat
	after the card closed; the reveal's fallback when no card showed). From the start it plays the three screens one
	at a time (ShiftLandingRules.screenAt: temperature and weather, the time, the anomaly level; ShiftLandingViewModel
	.screens), driving the screen's `alpha` binding on a Heartbeat and re-rendering only when the screen changes. Drawn
	at the game's one UI scale (PaperHudFrame, usePaperHudScale) where ShiftLandingViewModel.frame puts it (under the
	crew list, which grows with the crew). Once ShiftLandingRules.over it stops and draws nothing until the next
	arrival. Hidden while the transit screen covers the view. HUD widget shell (exempt; the timing is the specced
	ShiftLandingRules, the words and place ShiftLandingViewModel).

	@class ShiftLandingHud
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local DepotStore = require(ReplicatedStorage.Client.Features.Depot.State.DepotStore)
local ShiftLandingRules = require(ReplicatedStorage.Client.Features.Shift.Rules.ShiftLandingRules)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local ShiftTransitStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftTransitStore)
local PaperHudFrame = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudFrame)
local usePaperHudScale = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperHudScale)
local ShiftLandingReadout = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftLandingReadout)
local ShiftLandingViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftLandingViewModel)

local e = React.createElement
local useAtom = ReactCharm.useAtom

local function arrivalShowing(): boolean
	local card = DepotStore.card()
	return card ~= nil and card.kind == "arrival"
end

local function ShiftLandingHud(): React.ReactNode
	local landing = useAtom(ShiftTransitStore.landing)
	local covered = useAtom(ShiftTransitStore.covered)
	local transit = useAtom(ShiftTransitStore.snapshot)
	local shift = useAtom(ShiftStore.snapshot)
	local hudScale = usePaperHudScale()
	local alpha, setAlpha = React.useBinding(0)
	-- The screen showing (0: none) and the arrival whose readout has finished (0: none yet).
	local screen, setScreen = React.useState(0)
	local doneId, setDoneId = React.useState(0)
	local landingId = if landing ~= nil then landing.id else 0
	React.useEffect(function(): (() -> ())?
		local current = landing
		if current == nil then
			return nil
		end
		local watch: ShiftLandingRules.CardWatch = {}
		local startedAt: number? = nil
		local shown = 0
		local connection: RBXScriptConnection? = nil
		local function stop()
			local live = connection
			if live ~= nil then
				live:Disconnect()
				connection = nil
			end
		end
		local function step()
			local now = os.clock()
			local start = startedAt
			if start == nil then
				watch = ShiftLandingRules.watch(watch, arrivalShowing(), now)
				start = ShiftLandingRules.startAt({
					revealAt = current.at,
					now = now,
					seenAt = watch.seenAt,
					closedAt = watch.closedAt,
				})
				startedAt = start
			end
			if start == nil then
				return
			end
			local elapsed = now - start
			local index, value = ShiftLandingRules.screenAt(elapsed)
			setAlpha(value)
			if index ~= shown then
				shown = index
				setScreen(index)
			end
			if ShiftLandingRules.over(elapsed) then
				stop()
				setDoneId(current.id)
			end
		end
		connection = RunService.Heartbeat:Connect(step)
		step()
		return stop
	end, { landingId })
	if landing == nil or doneId == landing.id or covered or screen == 0 then
		return nil
	end
	local screens = ShiftLandingViewModel.screens(landing.seed, if transit ~= nil then transit.map else nil)
	local current = screens[screen]
	if current == nil then
		return nil
	end
	local crew = if shift ~= nil then #shift.crew else 1
	return e(PaperHudFrame, {
		scale = hudScale.scale,
		children = {
			-- Keyed by the screen, so each one mounts fresh as it tweens in.
			[`screen{screen}`] = e(ShiftLandingReadout, {
				screen = current,
				layout = hudScale.layout,
				frame = ShiftLandingViewModel.frame(hudScale.layout, hudScale.viewport, crew),
				alpha = alpha,
			}),
		},
	})
end

return ShiftLandingHud
