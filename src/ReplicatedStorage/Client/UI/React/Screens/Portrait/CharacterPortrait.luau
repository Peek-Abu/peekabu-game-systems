--!strict
--[=[
	CharacterPortrait: a player's own character, in the UI, as it looks in the game right now (skin, face set,
	uniform, rank lanyard, accessories), posed for where it is shown. Used wherever the UI shows a crew member: the
	hub's profile card, the shift's crew list, the truck seats, the rehire notice, the results' featured award.

	How it draws: a ViewportFrame holding a static copy of the character (EmployeePortraitSystem.build: no scripts,
	sounds, tools or effects; the pose applied once by forward kinematics; every part anchored; no WorldModel, no
	Animator). Nothing in it ever moves, so the engine renders it once and then only when the frame is resized: the
	cost of an image after the first frame. The copy is rebuilt only when the character changes
	(usePortraitCharacter: a respawn, an accessory or uniform put on or off) or the pose does, and destroyed with it.

	The pose: EmployeePoseRules over the employee's set (EmployeePoseRegistry) for `context`, the player's Clearance
	Level (looked up from the published rank unless `level` is given) and the results' `grade`.
	The frame: `framing` (head, bust, upper body or full figure) fitted to the frame's aspect
	(PortraitViewModel.camera), refitted without a rebuild when the frame is resized. The light: PortraitViewModel.lighting for the plate's `tone`.
	Until there is a character to show (not spawned, streamed out) it shows the ID-card photo of the player's own skin
	(PortraitViewModel.fallback). Exempt (needs a renderer and live characters); story in CharacterPortrait.story.

	@class CharacterPortrait
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local EmployeeShared = ReplicatedStorage.Shared.Features.Employee
local EmployeeConstants = require(EmployeeShared.Data.EmployeeConstants)
local EmployeePoseRegistry = require(EmployeeShared.Data.EmployeePoseRegistry)
local EmployeePoseRules = require(EmployeeShared.Rules.EmployeePoseRules)
local EmployeePoseFormulas = require(EmployeeShared.Utils.EmployeePoseFormulas)
local RankFormulas = require(ReplicatedStorage.Shared.Features.Rank.Utils.RankFormulas)
local EmployeePortraitSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeePortraitSystem)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local PortraitViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Portrait.PortraitViewModel)
local usePortraitCharacter = require(ReplicatedStorage.Client.UI.React.Screens.Portrait.usePortraitCharacter)
local RankViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Rank.RankViewModel)

local e = React.createElement

-- A receded portrait (a caught crew member): greyed, like the kit's dimmed slots.
local DIM_COLOR = Color3.fromRGB(150, 140, 165)

export type CharacterPortraitProps = {
	-- Whose character; ignored when `model` is given.
	userId: number?,
	-- A model to show instead of a player's character (stories, a non-player).
	model: Model?,
	context: EmployeePoseRegistry.PortraitContext,
	framing: PortraitViewModel.Framing,
	tone: PortraitViewModel.Tone?,
	-- The Clearance Level; nil = the player's published rank.
	level: number?,
	-- The results' grade letter.
	grade: string?,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	zIndex: number?,
	-- Clip to a circle (a ring portrait).
	round: boolean?,
	dim: boolean?,
	-- The image while there is no character (default: the player's skin's ID-card photo).
	fallback: string?,
}

local function aspectOf(frame: ViewportFrame): number
	local size = frame.AbsoluteSize
	return if size.X > 0 and size.Y > 0 then size.X / size.Y else 1
end

local function CharacterPortrait(props: CharacterPortraitProps): React.ReactNode
	local live = usePortraitCharacter(if props.model == nil then props.userId else nil)
	local publicPlayers = ReactCharm.useAtom(StateSyncClientStore.publicPlayers)
	local noFrame: ViewportFrame? = nil
	local frame, setFrame = React.useState(noFrame)
	local shown, setShown = React.useState(false)

	local source = props.model or live.character
	local employee = if source ~= nil then source:GetAttribute(EmployeeConstants.NAME_ATTRIBUTE) else nil
	local level = props.level
	if level == nil and props.userId ~= nil then
		local rank = RankViewModel.rankOf(publicPlayers, props.userId)
		level = if rank ~= nil then RankFormulas.levelFor(rank.xp).level else nil
	end
	local pose = EmployeePoseRules.select(
		if type(employee) == "string" then EmployeePoseRegistry.get(employee) else nil,
		props.context,
		{ level = level, grade = props.grade }
	)
	local poseName = if pose ~= nil then pose.name else ""

	local deps: { unknown } = { frame, source, live.revision, poseName, props.framing }
	React.useEffect(function(): () -> ()
		if frame == nil or source == nil then
			setShown(false)
			return function() end
		end
		local copy = EmployeePortraitSystem.build(source, pose)
		if copy == nil then
			setShown(false)
			return function() end
		end
		local bounds =
			EmployeePoseFormulas.bounds(EmployeePortraitSystem.boxes(copy, PortraitViewModel.parts(props.framing)))
		local camera = Instance.new("Camera")
		local function fit()
			if bounds ~= nil then
				local view = PortraitViewModel.camera(bounds, props.framing, aspectOf(frame))
				camera.FieldOfView = view.fov
				camera.CFrame = view.cframe
			end
		end
		fit()
		camera.Parent = frame
		copy.Parent = frame
		frame.CurrentCamera = camera
		setShown(true)
		local resized = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		return function()
			resized:Disconnect()
			copy:Destroy()
			camera:Destroy()
		end
	end, deps)

	local light = PortraitViewModel.lighting(props.tone or "light")
	local corner = if props.round == true then e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) else nil
	local fallbackImage = props.fallback
		or PortraitViewModel.fallback(props.userId or 0, if type(employee) == "string" then employee else nil)
	return e("Frame", {
		Size = props.size,
		Position = props.position,
		AnchorPoint = props.anchor,
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
	}, {
		view = e("ViewportFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Ambient = light.ambient,
			LightColor = light.color,
			LightDirection = light.direction,
			ImageColor3 = if props.dim == true then DIM_COLOR else Color3.new(1, 1, 1),
			Visible = shown,
			ZIndex = props.zIndex,
			ref = setFrame,
		}, { corner = corner }),
		photo = if shown
			then nil
			else e("ImageLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = fallbackImage,
				ImageColor3 = if props.dim == true then DIM_COLOR else Color3.new(1, 1, 1),
				ScaleType = Enum.ScaleType.Crop,
				ZIndex = props.zIndex,
			}, { corner = if props.round == true then e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) else nil }),
	})
end

return CharacterPortrait
