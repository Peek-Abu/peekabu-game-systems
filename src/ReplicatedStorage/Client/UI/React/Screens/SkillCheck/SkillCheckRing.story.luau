--!strict
--[=[
	SkillCheckRing.story: the closing ring in UI Labs, on the office backdrop. Controls: Phone (844x390 design px),
	Progress (the pile's progress, 0 to 1: the opening narrows as it rises), Gap (the opening's centre, degrees), Angle
	(the icon), Closed (how far the outer ring has come in, 0 to 1), Verdict (none, hit or miss: holds its flash at
	full), Hint ("Line it up!"), Character (a stand-in box for the local character's on-screen bounds: none, standing
	mid-screen, or close to the camera; the ring is placed by SkillCheckRingViewModel.placement), CharacterTop (the box's
	top, design px), and Animate (loops the real close (SkillCheckConstants.TRAVEL) with the icon sweeping, judged at each arrival
	by the same rule the server uses).
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local SkillCheckConstants = require(ReplicatedStorage.Shared.Features.SkillCheck.Data.SkillCheckConstants)
local SkillCheckAngleFormulas = require(ReplicatedStorage.Shared.Features.SkillCheck.Utils.SkillCheckAngleFormulas)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local SkillCheckRing = require(ReplicatedStorage.Client.UI.React.Screens.SkillCheck.SkillCheckRing)
local SkillCheckRingViewModel = require(ReplicatedStorage.Client.UI.React.Screens.SkillCheck.SkillCheckRingViewModel)

local e = React.createElement

local NONE = "none"
local HIT = "hit"
local MISS = "miss"

type StoryProps = {
	phone: boolean,
	progress: number,
	gap: number,
	angle: number,
	closed: number,
	verdict: string,
	hint: boolean,
	character: string,
	characterTop: number,
	animate: boolean,
}

local CHARACTER_NONE = "none"
local CHARACTER_STANDING = "standing"
local CHARACTER_CLOSE = "close"

-- The stand-in character's box (design px): standing is about a third of the screen tall, close nearly all of it.
local function standIn(kind: string, top: number, viewport: Vector2): SkillCheckRingViewModel.Box?
	if kind == CHARACTER_NONE then
		return nil
	end
	local tall = if kind == CHARACTER_CLOSE then viewport.Y * 0.8 else viewport.Y * 0.32
	local wide = if kind == CHARACTER_CLOSE then viewport.X * 0.2 else viewport.X * 0.08
	local mid = viewport.X / 2
	return { left = mid - wide / 2, right = mid + wide / 2, top = top, bottom = top + tall }
end

local function Story(props: StoryProps): React.ReactNode
	local fraction, setFraction = React.useBinding(props.closed)
	local angle, setAngle = React.useBinding(props.angle)
	local flash, setFlash = React.useBinding(if props.verdict == NONE then 0 else 1)
	local looped, setLooped = React.useState(NONE)
	local width =
		SkillCheckAngleFormulas.gapWidth(props.progress, SkillCheckConstants.WIDTH_START, SkillCheckConstants.WIDTH_END)
	local deps: { unknown } = { props.animate, props.closed, props.angle, props.verdict, props.gap, width }
	React.useEffect(function(): (() -> ())?
		if not props.animate then
			setFraction(props.closed)
			setAngle(props.angle)
			setFlash(if props.verdict == NONE then 0 else 1)
			return nil
		end
		local travel = SkillCheckConstants.TRAVEL
		local cycle = travel + SkillCheckRingViewModel.LINGER
		local startedAt = os.clock()
		local judgedCycle = -1
		local connection = RunService.Heartbeat:Connect(function()
			local elapsed = os.clock() - startedAt
			local index = math.floor(elapsed / cycle)
			local t = elapsed - index * cycle
			local sweep = SkillCheckAngleFormulas.normalize(elapsed * 140)
			setFraction(math.clamp(t / travel, 0, 1))
			if t < travel then
				setAngle(sweep)
				setFlash(0)
			else
				if judgedCycle ~= index then
					judgedCycle = index
					local hit = SkillCheckAngleFormulas.inGap(sweep, props.gap, width, SkillCheckConstants.TOLERANCE)
					setLooped(if hit then HIT else MISS)
				end
				setFlash(SkillCheckRingViewModel.flash(t - travel))
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, deps)
	local layout: SkillCheckRingViewModel.Layout = if props.phone then "phone" else "desktop"
	local viewport = if props.phone then Vector2.new(844, 390) else Vector2.new(1920, 1080)
	local verdict = if props.animate then looped else props.verdict
	local body = standIn(props.character, props.characterTop, viewport)
	local placed = SkillCheckRingViewModel.placement(layout, viewport, body)
	local centre, setCentre = React.useBinding(placed.centre)
	local placedDeps: { unknown } = { placed.centre }
	React.useEffect(function()
		setCentre(placed.centre)
	end, placedDeps)
	local away = if placed.spot == "right" then 1 elseif placed.spot == "left" then -1 else nil
	return e("Frame", {
		Size = UDim2.fromOffset(viewport.X, viewport.Y),
		BackgroundColor3 = UIPaperConstants.COLOR.office,
		BorderSizePixel = 0,
	}, {
		character = if body ~= nil
			then e("Frame", {
				Position = UDim2.fromOffset(body.left, body.top),
				Size = UDim2.fromOffset(body.right - body.left, body.bottom - body.top),
				BackgroundColor3 = Color3.fromRGB(183, 164, 236),
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
			})
			else nil,
		ring = e(SkillCheckRing, {
			layout = layout,
			centre = centre,
			hintSide = SkillCheckRingViewModel.hintSide(layout, placed.centre, viewport, away),
			gap = props.gap,
			width = width,
			fraction = fraction,
			angle = angle,
			flash = flash,
			hit = if verdict == HIT then true elseif verdict == MISS then false else nil,
			hint = if props.hint then SkillCheckConstants.HINT else nil,
		}),
	})
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Phone = false,
		Progress = UILabs.Slider(0, 0, 1, 0.05),
		Gap = UILabs.Slider(40, 0, 359, 1),
		Angle = UILabs.Slider(20, 0, 359, 1),
		Closed = UILabs.Slider(0.6, 0, 1, 0.05),
		Verdict = UILabs.Choose({ NONE, HIT, MISS }),
		Hint = true,
		Character = UILabs.Choose({ CHARACTER_STANDING, CHARACTER_CLOSE, CHARACTER_NONE }),
		CharacterTop = UILabs.Slider(520, -100, 1000, 10),
		Animate = false,
	},
}, function(props)
	local controls = props.controls
	return e(Story, {
		phone = controls.Phone,
		progress = controls.Progress,
		gap = controls.Gap,
		angle = controls.Angle,
		closed = controls.Closed,
		verdict = controls.Verdict,
		hint = controls.Hint,
		character = controls.Character,
		characterTop = controls.CharacterTop,
		animate = controls.Animate,
	})
end)
