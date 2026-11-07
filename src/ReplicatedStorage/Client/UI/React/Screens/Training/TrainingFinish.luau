--!strict
--[=[
	TrainingFinish: the training run's finish screen (tutorial v3), the results look: a grape scrim with turning gold
	rays, a big gold TRAINING DONE! title on a clean wipe band, YOUR employee in your skin (your current outfit,
	ToonViewport, in the victory pose) with a YOU tag, the award card (+100 Gleam the first time, a practice line on a
	repeat) and two buttons: BACK TO THE DEPOT and PLAY AGAIN (the ride home, where the hub points at the Training
	pad). Shown while TrainingCoachStore.finish is set; a pick goes to TrainingCoachStore.pick (TrainingServiceClient
	sends it) and disables both. A registered HUD widget (TrainingServiceClient). Presentational (exempt).

	@class TrainingFinish
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CosmeticOutfitRules = require(ReplicatedStorage.Shared.Features.Cosmetic.Rules.CosmeticOutfitRules)
local CosmeticRules = require(ReplicatedStorage.Shared.Features.Cosmetic.Rules.CosmeticRules)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local TrainingCoachStore = require(ReplicatedStorage.Client.Features.Training.State.TrainingCoachStore)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local PaperHudFrame = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudFrame)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperHudScale = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperHudScale)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonIcon = require(Toon.ToonIcon)
local ToonPanel = require(Toon.ToonPanel)
local ToonPill = require(Toon.ToonPill)
local ToonText = require(Toon.ToonText)
local ToonViewport = require(Toon.ToonViewport)

local e = React.createElement
local useAtom = ReactCharm.useAtom

-- Degrees a second the rays turn.
local RAY_SPEED = 6

-- The rays' turn as a binding (no re-render a frame).
local function useSpin(running: boolean): React.Binding<number>
	local angle, setAngle = React.useBinding(0)
	React.useEffect(function()
		local start = os.clock()
		local connection = if running
			then RunService.Heartbeat:Connect(function()
				setAngle(((os.clock() - start) * RAY_SPEED) % 360)
			end)
			else nil
		return function()
			if connection then
				connection:Disconnect()
			end
		end
	end, { running })
	return angle
end

local function TrainingFinish(): React.ReactNode
	local finish = useAtom(TrainingCoachStore.finish)
	local loadout = useAtom(StateSyncClientStore.loadout)
	local entitlements = useAtom(StateSyncClientStore.entitlements)
	local picked = useAtom(TrainingCoachStore.picked) ~= nil
	local hudScale = usePaperHudScale()
	local layout: UIPaperConstants.Layout = hudScale.layout
	local phone = layout == "phone"
	local spin = useSpin(finish ~= nil)
	-- Built once per loadout change, so the 3D model is not rebuilt on every render.
	local deps: { unknown } = { loadout, entitlements }
	local outfit = React.useMemo(function()
		return CosmeticOutfitRules.current(loadout, function(id: string): boolean
			return CosmeticRules.owns(entitlements, id)
		end)
	end, deps)
	if finish == nil then
		return nil
	end
	local paid = finish.gleam > 0
	local W = if phone then 844 else 1920
	local function pick(value: TrainingCoachStore.Pick)
		TrainingCoachStore.pick(value)
	end
	local s = if phone then 0.44 else 1
	local award = Vector2.new(820 * s, 280 * s)
	local awardAt = Vector2.new(W * 0.43, (if phone then 120 else 330))
	local awardFace: { [string]: React.ReactNode } = {
		coin = e(ToonIcon, {
			icon = "gleam",
			position = UDim2.fromOffset(-10 * s, -50 * s),
			size = UDim2.fromOffset(280 * s, 280 * s),
			drop = 6,
			zIndex = 9,
		}),
		amount = e(ToonText, {
			text = if paid then `+{finish.gleam}` else "NICE!",
			meaning = "gold",
			textSize = math.floor(130 * s),
			position = UDim2.fromOffset(290 * s, 30 * s),
			size = UDim2.fromOffset(award.X - 320 * s, 140 * s),
			fit = true,
			zIndex = 8,
		}),
		line = e(ToonText, {
			text = if paid then TrainingConstants.TEXT.finishGleam else TrainingConstants.TEXT.finishAgain,
			font = "body",
			textSize = math.floor(32 * s),
			position = UDim2.fromOffset(290 * s, 180 * s),
			size = UDim2.fromOffset(award.X - 320 * s, 60 * s),
			wrapped = true,
			fit = true,
			zIndex = 8,
		}),
	}
	local face: { [string]: React.ReactNode } = {
		band = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(W / 2, 170 * s + (if phone then 0 else 0)),
			Size = UDim2.fromOffset(1240 * s, 190 * s),
			Rotation = -3,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.86,
			ZIndex = 3,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(0, 40 * s) }) }),
		title = e(ToonText, {
			text = TrainingConstants.TEXT.finishTitle,
			meaning = "gold",
			textSize = math.floor(140 * s),
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromOffset(W / 2, 165 * s),
			size = UDim2.fromOffset(1300 * s, 170 * s),
			align = "center",
			alignY = "center",
			rotation = -3,
			fit = true,
			zIndex = 5,
		}),
		you = e(ToonViewport, {
			outfit = outfit,
			framing = "full",
			context = "victory",
			size = UDim2.fromOffset(600 * s, 640 * s),
			position = UDim2.fromOffset(awardAt.X - 640 * s, awardAt.Y - 40 * s),
			zIndex = 6,
		}),
		tag = e(ToonPill, {
			text = `{TrainingConstants.TEXT.you}`,
			hue = "grape",
			meaning = "gold",
			textSize = math.floor(36 * s),
			anchor = Vector2.new(0.5, 0),
			position = UDim2.fromOffset(awardAt.X - 340 * s, awardAt.Y + 580 * s),
			size = UDim2.fromOffset(170 * s, 64 * s),
			zIndex = 8,
		}),
		award = e(ToonPanel, {
			size = award,
			position = UDim2.fromOffset(awardAt.X, awardAt.Y),
			hue = "cream",
			pop = true,
			zIndex = 6,
			children = awardFace,
		}),
		back = e(ToonButton, {
			variant = "primary",
			text = TrainingConstants.TEXT.back,
			textSize = math.floor(44 * s),
			size = UDim2.fromOffset(500 * s, 112 * s),
			position = UDim2.fromOffset(awardAt.X, awardAt.Y + award.Y + 60 * s),
			disabled = picked,
			onActivated = function()
				pick("back")
			end,
			zIndex = 8,
		}),
		again = e(ToonButton, {
			variant = "secondary",
			text = TrainingConstants.TEXT.playAgain,
			textSize = math.floor(44 * s),
			size = UDim2.fromOffset(300 * s, 112 * s),
			position = UDim2.fromOffset(awardAt.X + 520 * s, awardAt.Y + award.Y + 60 * s),
			disabled = picked,
			onActivated = function()
				pick("again")
			end,
			zIndex = 8,
		}),
		finishLine = e(ToonText, {
			text = TrainingConstants.TEXT.finishLine,
			font = "body",
			color = Color3.new(1, 1, 1),
			textSize = math.floor(30 * s),
			position = UDim2.fromOffset(awardAt.X, awardAt.Y + award.Y + 200 * s),
			size = UDim2.fromOffset(award.X, 40 * s),
			fit = true,
			zIndex = 8,
		}),
	}
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromHex("170B33"),
		BackgroundTransparency = 0.12,
		Active = true,
		ZIndex = 50,
	}, {
		glow = e("UIGradient", {
			Color = ColorSequence.new(Color3.fromHex("5523C2"), Color3.fromHex("170B33")),
			Transparency = NumberSequence.new(0, 0),
			Rotation = 90,
		}),
		rays = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1.6, 1.6),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			BackgroundTransparency = 1,
			Image = UIAssets.toon.rays,
			ImageColor3 = Color3.fromHex("FFE27A"),
			ImageTransparency = 0.82,
			Rotation = spin,
			ZIndex = 51,
		}),
		layer = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 52,
		}, {
			frame = e(PaperHudFrame, {
				scale = hudScale.scale,
				children = face,
			}),
		}),
	})
end

return TrainingFinish
