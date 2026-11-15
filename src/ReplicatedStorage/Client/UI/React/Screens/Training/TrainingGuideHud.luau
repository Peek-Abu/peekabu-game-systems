--!strict
--[=[
	TrainingGuideHud: the training run's guide on the HUD (tutorial v3): the coach's card (bottom left on desktop; on a
	phone top centre in the Gloom meter's place, the hearts under it, since a run has no goal bar: owner 2026-11-15),
	the five stop dots on its top edge (TrainingStopDots) and the catch beat (TrainingGuideRules.catchPhase): after
	the grab, one coral card slides down under the hearts (a gloomed heart breaking its edge: the hearts row above it
	pops by itself), then the screen goes dark while the server moves the player back, then it clears and
	Pippa gives her tip. Off a run it draws nothing. A registered HUD widget (TrainingServiceClient); it ticks only
	while a catch beat or a timed line runs. Presentational (exempt; the choices are the specced TrainingGuideRules
	and TrainingCoachStore).

	@class TrainingGuideHud
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local TrainingGuideRules = require(ReplicatedStorage.Shared.Features.Training.Rules.TrainingGuideRules)
local TrainingCoachStore = require(ReplicatedStorage.Client.Features.Training.State.TrainingCoachStore)
local PaperHudFrame = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudFrame)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperHudScale = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperHudScale)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
local CrewVM = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftCrewViewModel)
local TrainingCoach = require(ReplicatedStorage.Client.UI.React.Screens.Training.TrainingCoach)
local TrainingStopDots = require(ReplicatedStorage.Client.UI.React.Screens.Training.TrainingStopDots)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local ToonPanel = require(Toon.ToonPanel)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement
local useAtom = ReactCharm.useAtom

local BEAT = TrainingConstants.CATCH_BEAT
-- The dark's fade in and out (seconds).
local DARK_FADE = BEAT.fade
-- The card's slide (seconds).
local CARD_SLIDE = 0.18
-- The phone coach card's width (TrainingCoach), and the crew list's inset from the right edge and the gap kept from it.
local COACH_PHONE_WIDTH = 330
local CREW_INSET = 10
local CREW_GAP = 8

-- Re-renders every frame while `running`.

-- The run coach's place on screen, for the phone's sticky notes (stable, so the card's effect never re-subscribes).
local function guideArea(area: TrainingCoachStore.Area?)
	TrainingCoachStore.setArea("guide", area)
end
local function useTicking(running: boolean): number
	local now, setNow = React.useState(os.clock())
	React.useEffect(function()
		local connection = if running
			then RunService.Heartbeat:Connect(function()
				setNow(os.clock())
			end)
			else nil
		return function()
			if connection then
				connection:Disconnect()
			end
		end
	end, { running })
	return if running then now else os.clock()
end

-- How dark the screen is `elapsed` seconds after the grab (1 = clear).
local function darkness(elapsed: number): number
	if elapsed < BEAT.dark or elapsed >= BEAT.back + DARK_FADE then
		return 1
	elseif elapsed < BEAT.dark + DARK_FADE then
		return 1 - (elapsed - BEAT.dark) / DARK_FADE
	elseif elapsed < BEAT.back then
		return 0
	end
	return (elapsed - BEAT.back) / DARK_FADE
end

local function catchCard(phone: boolean, top: number, elapsed: number): React.ReactNode
	local slide = math.clamp((elapsed - BEAT.card) / CARD_SLIDE, 0, 1)
	local size = if phone then Vector2.new(340, 58) else Vector2.new(700, 116)
	local icon = if phone then 66 else 140
	local face: { [string]: React.ReactNode } = {
		heart = e(ToonIcon, {
			icon = "heartGloomed",
			position = UDim2.fromOffset(-icon * 0.28, -icon * 0.3),
			size = UDim2.fromOffset(icon, icon),
			drop = 4,
			zIndex = 44,
		}),
		title = e(ToonText, {
			text = TrainingConstants.TEXT.caughtCard,
			textSize = if phone then 20 else 42,
			position = UDim2.fromOffset(icon * 0.8, if phone then 6 else 14),
			size = UDim2.new(1, -icon * 0.8 - 16, 0, if phone then 24 else 48),
			fit = true,
			zIndex = 42,
		}),
		line = e(ToonText, {
			text = TrainingConstants.TEXT.caughtLine,
			font = "body",
			color = Color3.new(1, 1, 1),
			textSize = if phone then 12 else 24,
			position = UDim2.fromOffset(icon * 0.8, if phone then 32 else 66),
			size = UDim2.new(1, -icon * 0.8 - 16, 0, if phone then 16 else 30),
			fit = true,
			zIndex = 42,
		}),
	}
	return e(ToonPanel, {
		size = size,
		anchor = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, top - (1 - slide) * 40),
		hue = "coral",
		radius = if phone then 16 else 26,
		zIndex = 40,
		children = face,
	})
end

local function TrainingGuideHud(): React.ReactNode
	local stop = useAtom(TrainingCoachStore.stop)
	local said = useAtom(TrainingCoachStore.said)
	local catch = useAtom(TrainingCoachStore.catch)
	-- The finish screen covers the run: nothing of the guide shows under it.
	local finished = useAtom(TrainingCoachStore.finish) ~= nil
	-- A spotlight tour step shows its own Pippa: the run's coach steps aside meanwhile.
	local touring = useAtom(TrainingCoachStore.touring)
	-- Read so the coach follows the situation (TrainingCoachStore.line reads it).
	useAtom(TrainingCoachStore.situation)
	local hudScale = usePaperHudScale()
	local layout: UIPaperConstants.Layout = hudScale.layout
	local phone = layout == "phone"
	local clock = os.clock()
	local beatRunning = catch ~= nil and TrainingGuideRules.catchPhase(clock - catch.at) ~= "done"
	local timedLine = said ~= nil and said.untilAt ~= nil and clock < said.untilAt
	local now = useTicking(beatRunning or timedLine)
	if stop == nil or finished then
		return nil
	end
	local stopNow: number = stop
	local line = TrainingCoachStore.line(now)
	local elapsed = if catch ~= nil then now - catch.at else -1
	local phase = TrainingGuideRules.catchPhase(elapsed)
	local metrics = if phone then ShiftHudViewModel.METER.phone else ShiftHudViewModel.METER.desktop
	local viewport = hudScale.viewport
	-- The catch card: under the hearts on a phone (they drop under the coach on a run), under the meter's place on
	-- desktop.
	local heartsAt, heartsSize = ShiftHudViewModel.livesFrame(layout, viewport, true)
	local underBar = if phone then heartsAt.Y + heartsSize.Y + 10 else metrics.top + metrics.size.Y + 70
	local children: { [string]: React.ReactNode } = {}
	if line ~= nil and phase ~= "dark" and not touring then
		-- Phone: in the Gloom meter's place, top centre (no goal bar on a run, owner 2026-11-15), pushed left of the
		-- crew list on a narrow phone; desktop: bottom left. The stop dots ride the card's top edge.
		local coachAt = UDim2.new(0, 24, 1, -170)
		if phone then
			local fit = CrewVM.phoneFit(viewport.X)
			local rightEdge = viewport.X - CREW_INSET - fit.list - CREW_GAP
			local left = math.min(viewport.X / 2 - COACH_PHONE_WIDTH / 2, rightEdge - COACH_PHONE_WIDTH)
			coachAt = UDim2.fromOffset(left, metrics.top)
		end
		children.coach = e(TrainingCoach, {
			line = line,
			phone = phone,
			position = coachAt,
			anchor = if phone then Vector2.zero else nil,
			onArea = guideArea,
			badge = function(z: number): React.ReactNode
				return e(TrainingStopDots, { stop = stopNow, phone = phone, zIndex = z })
			end,
		})
	end
	-- The card stays through the move back, so the player stands up at the stop start with it and Pippa's tip.
	if phase == "card" or phase == "dark" or phase == "back" then
		children.card = catchCard(phone, underBar, elapsed)
	end
	local dark = darkness(elapsed)
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		-- Over the dark: the card stays readable while the screen is dark.
		layer = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 40,
		}, {
			frame = e(PaperHudFrame, {
				scale = hudScale.scale,
				children = children,
			}),
		}),
		dark = if dark < 1
			then e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = UIToonConstants.COLOR.ink,
				BackgroundTransparency = 0.08 + 0.92 * dark,
				BorderSizePixel = 0,
				ZIndex = 35,
			})
			else nil,
	})
end

return TrainingGuideHud
