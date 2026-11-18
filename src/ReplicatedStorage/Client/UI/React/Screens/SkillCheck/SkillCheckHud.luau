--!strict
--[=[
	SkillCheckHud: the closing ring's HUD widget (registered by SkillCheckServiceClient). While SkillCheckStore holds a
	ring it draws SkillCheckRing at the game's one UI scale (PaperHudFrame, usePaperHudScale). A Heartbeat drives the
	ring's bindings with no re-render: how far the outer ring has closed (SkillCheckRingViewModel.fraction on the server
	clock), the icon's angle (SkillCheckInputSystem), the verdict's flash once the server's Result for this ring is in,
	and where the ring sits. For that it projects the local character's bounds (Model:GetBoundingBox, which holds the
	head, ears, hats and every accessory, so it fits any employee or skin) through Camera:WorldToViewportPoint into HUD
	design px (SkillCheckRingViewModel.toDesign from the HUD frame's own origin, so the top-bar inset and topShift are
	whatever the frame really has), boxes the corners (screenBox) and places the ring above the character's top, or
	beside it when there is no room (placement). The words go beside the ring, away from the character (hintSide; a
	re-render only when that side changes). It also tells SkillCheckInputSystem the ring's centre on screen every frame
	(inset-free, as InputObject.Position reports) and its inner radius in real px, so input is read round the ring
	where it is now; unmounting tells it no ring shows. HUD widget shell (exempt; the layout, placement and motion are
	the specced SkillCheckRingViewModel, the input maths SkillCheckInputFormulas).

	@class SkillCheckHud
]=]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
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

-- The eight corners of a box of `size` at `cframe`.
local SIGNS: { Vector3 } = {
	Vector3.new(-1, -1, -1),
	Vector3.new(-1, -1, 1),
	Vector3.new(-1, 1, -1),
	Vector3.new(-1, 1, 1),
	Vector3.new(1, -1, -1),
	Vector3.new(1, -1, 1),
	Vector3.new(1, 1, -1),
	Vector3.new(1, 1, 1),
}

-- Whether `frame`'s ScreenGui draws under Roblox's top bar (its coordinates then start at the viewport's corner).
local function ignoresInset(frame: GuiObject): boolean
	local screen = frame:FindFirstAncestorOfClass("ScreenGui")
	return screen ~= nil and screen.IgnoreGuiInset
end

-- The local character's on-screen box in HUD design px, measured from `container` (the HUD frame) drawn at `scale`;
-- nil without a character, a camera, or when any corner is behind the camera.
local function characterBox(container: GuiObject, scale: number): SkillCheckRingViewModel.Box?
	local camera = Workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	if camera == nil or character == nil then
		return nil
	end
	local cframe, size = character:GetBoundingBox()
	-- WorldToViewportPoint counts from the viewport's corner; a ScreenGui that keeps clear of the top bar starts lower.
	local shift = if ignoresInset(container) then Vector2.zero else GuiService:GetGuiInset()
	local points: { Vector2 } = {}
	for _, sign in SIGNS do
		local screen = camera:WorldToViewportPoint(cframe:PointToWorldSpace(size * sign / 2))
		if screen.Z <= 0 then
			return nil
		end
		local point = Vector2.new(screen.X, screen.Y) - shift
		table.insert(points, SkillCheckRingViewModel.toDesign(point, container.AbsolutePosition, scale))
	end
	return SkillCheckRingViewModel.screenBox(points)
end

-- Tells the input where the ring's centre is on screen now (InputObject.Position's inset-free px) and its inner radius.
local function placeInput(container: GuiObject, centre: Vector2, scale: number, inner: number)
	local at = container.AbsolutePosition + centre * scale
	if ignoresInset(container) then
		at -= GuiService:GetGuiInset()
	end
	SkillCheckInputSystem.setRing(at, inner * scale)
end

local function SkillCheckHud(): React.ReactNode
	local ring = useAtom(SkillCheckStore.ring)
	local result = useAtom(SkillCheckStore.result)
	local seen = useAtom(SkillCheckStore.seen)
	local hudScale = usePaperHudScale()
	local layout: SkillCheckRingViewModel.Layout = if hudScale.layout == "phone" then "phone" else "desktop"
	local viewport = hudScale.viewport
	local scale = hudScale.scale
	local fraction, setFraction = React.useBinding(0)
	local angle, setAngle = React.useBinding(SkillCheckInputSystem.angle())
	local flash, setFlash = React.useBinding(0)
	local centre, setCentre = React.useBinding(SkillCheckRingViewModel.centre(layout, viewport))
	local hintSide, setHintSide = React.useState(SkillCheckRingViewModel.HINT_SIDE[layout])
	local hub = React.useMemo(function(): { frame: Frame? }
		return { frame = nil }
	end, {})
	local ringId = if ring ~= nil then ring.id else 0
	local resultAt = if result ~= nil and ring ~= nil and result.id == ring.id then result.at else nil
	local deps: { unknown } = { ringId, resultAt or 0, layout, viewport, scale }
	React.useEffect(function(): (() -> ())?
		local current = ring
		if current == nil then
			return nil
		end
		local inner = SkillCheckRingViewModel.METRICS[layout].inner
		local function step()
			setFraction(
				SkillCheckRingViewModel.fraction(Workspace:GetServerTimeNow(), current.arriveAt, current.travel)
			)
			setAngle(SkillCheckInputSystem.angle())
			setFlash(if resultAt ~= nil then SkillCheckRingViewModel.flash(os.clock() - resultAt) else 0)
			local frame = hub.frame
			local parent = if frame ~= nil then frame.Parent else nil
			if parent == nil or not parent:IsA("GuiObject") then
				return
			end
			local placed = SkillCheckRingViewModel.placement(layout, viewport, characterBox(parent, scale))
			setCentre(placed.centre)
			local away = if placed.spot == "right" then 1 elseif placed.spot == "left" then -1 else nil
			setHintSide(SkillCheckRingViewModel.hintSide(layout, placed.centre, viewport, away))
			placeInput(parent, placed.centre, scale, inner)
		end
		local connection = RunService.Heartbeat:Connect(step)
		step()
		return function()
			connection:Disconnect()
			SkillCheckInputSystem.setRing(nil, 1)
		end
	end, deps)
	if ring == nil then
		return nil
	end
	return e(PaperHudFrame, {
		scale = scale,
		children = {
			ring = e(SkillCheckRing, {
				layout = layout,
				centre = centre,
				gap = ring.gap,
				width = ring.width,
				fraction = fraction,
				angle = angle,
				flash = flash,
				hit = if resultAt ~= nil and result ~= nil then result.hit else nil,
				hint = if SkillCheckRingViewModel.hint(seen, SkillCheckConstants.HINT_RINGS)
					then SkillCheckConstants.HINT
					else nil,
				hintSide = hintSide,
				onHub = function(frame: Frame?)
					hub.frame = frame
				end,
			}),
		},
	})
end

return SkillCheckHud
