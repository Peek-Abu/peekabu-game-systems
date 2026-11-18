--!strict
--[=[
	SkillCheckHud: the closing ring's HUD widget (registered by SkillCheckServiceClient). While SkillCheckStore holds a
	ring it draws SkillCheckRing at the game's one UI scale (PaperHudFrame, usePaperHudScale), centred by
	SkillCheckRingViewModel.centre. A Heartbeat drives the ring's bindings with no re-render: how far the outer ring has
	closed (SkillCheckRingViewModel.fraction on the server clock), the icon's angle (SkillCheckInputSystem) and the
	verdict's flash once the server's Result for this ring is in. It also tells SkillCheckInputSystem where the ring is
	on screen (the inner circle's centre, inset-free, and its radius in real px), so a pointer or a touch is read round
	the ring as drawn; unmounting tells it no ring shows. HUD widget shell (exempt; the layout and motion are the
	specced SkillCheckRingViewModel, the input maths SkillCheckInputFormulas).

	@class SkillCheckHud
]=]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local SkillCheckConstants = require(ReplicatedStorage.Shared.Features.SkillCheck.Data.SkillCheckConstants)
local SkillCheckStore = require(ReplicatedStorage.Client.Features.SkillCheck.State.SkillCheckStore)
local SkillCheckInputSystem = require(ReplicatedStorage.Client.Features.SkillCheck.Systems.SkillCheckInputSystem)
local PaperHudFrame = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudFrame)
local usePaperHudScale = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperHudScale)
local SkillCheckRing = require(ReplicatedStorage.Client.UI.React.Screens.SkillCheck.SkillCheckRing)
local SkillCheckRingViewModel = require(ReplicatedStorage.Client.UI.React.Screens.SkillCheck.SkillCheckRingViewModel)

local e = React.createElement
local useAtom = ReactCharm.useAtom

-- Tells the input where the ring's inner circle is on screen, in InputObject.Position's inset-free px.
local function placeInput(frame: Frame?)
	if frame == nil or frame.AbsoluteSize.X <= 0 then
		return
	end
	local centre = frame.AbsolutePosition + frame.AbsoluteSize / 2
	local screen = frame:FindFirstAncestorOfClass("ScreenGui")
	if screen ~= nil and screen.IgnoreGuiInset then
		centre -= GuiService:GetGuiInset()
	end
	SkillCheckInputSystem.setRing(centre, frame.AbsoluteSize.X / 2)
end

local function SkillCheckHud(): React.ReactNode
	local ring = useAtom(SkillCheckStore.ring)
	local result = useAtom(SkillCheckStore.result)
	local seen = useAtom(SkillCheckStore.seen)
	local hudScale = usePaperHudScale()
	local fraction, setFraction = React.useBinding(0)
	local angle, setAngle = React.useBinding(SkillCheckInputSystem.angle())
	local flash, setFlash = React.useBinding(0)
	local hub = React.useMemo(function(): { frame: Frame? }
		return { frame = nil }
	end, {})
	local ringId = if ring ~= nil then ring.id else 0
	local resultAt = if result ~= nil and ring ~= nil and result.id == ring.id then result.at else nil
	React.useEffect(function(): (() -> ())?
		local current = ring
		if current == nil then
			return nil
		end
		local function step()
			setFraction(
				SkillCheckRingViewModel.fraction(Workspace:GetServerTimeNow(), current.arriveAt, current.travel)
			)
			setAngle(SkillCheckInputSystem.angle())
			setFlash(if resultAt ~= nil then SkillCheckRingViewModel.flash(os.clock() - resultAt) else 0)
			placeInput(hub.frame)
		end
		local connection = RunService.Heartbeat:Connect(step)
		step()
		return function()
			connection:Disconnect()
			SkillCheckInputSystem.setRing(nil, 1)
		end
	end, { ringId, resultAt or 0 })
	if ring == nil then
		return nil
	end
	local layout: SkillCheckRingViewModel.Layout = if hudScale.layout == "phone" then "phone" else "desktop"
	return e(PaperHudFrame, {
		scale = hudScale.scale,
		children = {
			ring = e(SkillCheckRing, {
				layout = layout,
				centre = SkillCheckRingViewModel.centre(layout, hudScale.viewport),
				gap = ring.gap,
				width = ring.width,
				fraction = fraction,
				angle = angle,
				flash = flash,
				hit = if resultAt ~= nil and result ~= nil then result.hit else nil,
				hint = if SkillCheckRingViewModel.hint(seen, SkillCheckConstants.HINT_RINGS)
					then SkillCheckConstants.HINT
					else nil,
				onHub = function(frame: Frame?)
					hub.frame = frame
				end,
			}),
		},
	})
end

return SkillCheckHud
