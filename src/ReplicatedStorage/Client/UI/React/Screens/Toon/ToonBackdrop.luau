--!strict
--[=[
	ToonBackdrop: the full-screen background every character menu sits on (Inventory, the pick, the Shop, reveals):
	the screen's colour as a top-to-bottom gradient, broad 45-degree stripes over it (the kit's stripe tile), optional
	rays behind the hero, and a vignette on the edges. `see` lets the world show through the top (0 = opaque), and
	`blur` blurs the world behind while the backdrop is up (a BlurEffect on the camera, removed on unmount). The
	stripes drift slowly and the rays turn (both still under Roblox's Reduce Motion setting).
	While the 3D preview stage is up (EmployeeStageSystem.wall), everything but the children is drawn on the stage's
	backdrop wall too (opaque, no blur), and once the stage is live (EmployeeStageSystem.live: its camera is held) only
	there: the stage shows in the screen's middle with the same backdrop round it, and never the world in between.
	A screen can dress it further (the shop by the open item's rarity, ShopRarityLookViewModel): `counterRays` turn the
	other way over the rays, `word` writes a word huge and faint behind the hero, `edge` tints the edge vignette, and
	`goo` pours Gloom goo along the top edge (ToonGoo).
	Presentational (exempt; story in ToonBackdrop.story).

	@class ToonBackdrop
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local EmployeeStageSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeeStageSystem)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local ToonGoo = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonGoo)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)
local useToonPlay = require(ReplicatedStorage.Client.UI.React.Screens.Toon.useToonPlay)

local e = React.createElement

export type Rays = {
	-- Where the rays' centre sits on the screen, and their size as a share of the screen width.
	position: UDim2,
	size: number,
	color: Color3,
	transparency: number?,
}

-- A word written huge and faint behind the hero (the shop's rarity name).
export type Word = {
	text: string,
	color: Color3,
	transparency: number,
	position: UDim2,
	size: UDim2,
}

export type ToonBackdropProps = {
	top: Color3,
	bottom: Color3,
	-- How much of the world shows through at the top (0 = opaque, default 0).
	see: number?,
	stripes: boolean?,
	rays: Rays?,
	-- A second ray layer turning the other way.
	counterRays: Rays?,
	word: Word?,
	-- The edge vignette's colour (default ink), drawn stronger when set.
	edge: Color3?,
	-- Gloom goo along the top edge.
	goo: boolean?,
	blur: boolean?,
	zIndex: number?,
	children: { [string]: React.ReactNode }?,
}

local BLUR_SIZE = 14
-- The stripes drift one tile down-right every STRIPE_SECONDS; the rays turn once every RAYS_SECONDS.
local STRIPE_TILE = 180
local STRIPE_SECONDS = 9
local RAYS_SECONDS = 48
-- The top-edge goo's size (1 = the kit's 128 px tiles).
local GOO_SCALE = 1.3

local function ToonBackdrop(props: ToonBackdropProps): React.ReactNode
	local wall = ReactCharm.useAtom(EmployeeStageSystem.wall)
	local staged = ReactCharm.useAtom(EmployeeStageSystem.live) and wall ~= nil
	-- On the stage's wall the world behind is the stage itself: no blur, and nothing see-through.
	local blur = props.blur == true and not staged
	-- The backdrop's width in pixels, for the goo run along its top edge.
	local width, setWidth = React.useState(0)
	-- Two looping 0 -> 1 clocks (Reduced Motion holds them still).
	local drift = useToonPlay(STRIPE_SECONDS, 0, nil, true)
	local turn = useToonPlay(RAYS_SECONDS, 0, nil, true)
	React.useEffect(function(): () -> ()
		if not blur then
			return function() end
		end
		local camera = workspace.CurrentCamera
		if camera == nil then
			return function() end
		end
		local effect = Instance.new("BlurEffect")
		effect.Name = "ToonBackdropBlur"
		effect.Size = BLUR_SIZE
		effect.Parent = camera
		return function()
			effect:Destroy()
		end
	end, { blur })

	local see = if wall ~= nil then 0 else props.see or 0
	local nodes: { [string]: React.ReactNode } = {
		fill = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = UIToonConstants.COLOR.white,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, {
			gradient = e("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(props.top, props.bottom),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, see),
					NumberSequenceKeypoint.new(0.6, see * 0.4),
					NumberSequenceKeypoint.new(1, 0),
				}),
			}),
		}),
	}
	if props.stripes ~= false then
		-- One tile larger than the screen, sliding by exactly one tile, so the loop is seamless.
		nodes.stripes = e("ImageLabel", {
			Position = drift:map(function(alpha: number): UDim2
				local offset = -STRIPE_TILE + alpha * STRIPE_TILE
				return UDim2.fromOffset(offset, offset)
			end),
			Size = UDim2.new(1, STRIPE_TILE, 1, STRIPE_TILE),
			BackgroundTransparency = 1,
			Image = UIAssets.toon.stripes,
			ImageColor3 = UIToonConstants.COLOR.white,
			ImageTransparency = 0.9,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(STRIPE_TILE, STRIPE_TILE),
			ZIndex = 2,
		})
	end
	local function rayLayer(rays: Rays, direction: number): React.ReactNode
		return e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = rays.position,
			Size = UDim2.fromScale(rays.size, rays.size),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			BackgroundTransparency = 1,
			Image = UIAssets.toon.rays,
			ImageColor3 = rays.color,
			ImageTransparency = rays.transparency or 0.45,
			Rotation = turn:map(function(alpha: number): number
				return direction * alpha * 360
			end),
			ZIndex = 3,
		})
	end
	local rays = props.rays
	if rays ~= nil then
		nodes.rays = rayLayer(rays, 1)
	end
	local counterRays = props.counterRays
	if counterRays ~= nil then
		nodes.counterRays = rayLayer(counterRays, -1)
	end
	local word = props.word
	if word ~= nil then
		nodes.word = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = word.position,
			Size = word.size,
			BackgroundTransparency = 1,
			Text = word.text,
			FontFace = UIToonConstants.FONT.display,
			TextScaled = true,
			TextColor3 = word.color,
			TextTransparency = word.transparency,
			ZIndex = 4,
		})
	end
	local edge = props.edge
	-- The vignette: the edges darken in ink, top/bottom and left/right.
	local edgeAt = if edge ~= nil then 0.3 else 0.55
	for _, side in { { name = "vignetteY", rotation = 90 }, { name = "vignetteX", rotation = 0 } } do
		nodes[side.name] = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = edge or UIToonConstants.COLOR.ink,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, {
			gradient = e("UIGradient", {
				Rotation = side.rotation,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, edgeAt),
					NumberSequenceKeypoint.new(0.18, 1),
					NumberSequenceKeypoint.new(0.82, 1),
					NumberSequenceKeypoint.new(1, edgeAt - 0.05),
				}),
			}),
		})
	end
	if props.goo == true and width > 0 then
		nodes.goo = e(ToonGoo, {
			kind = "cap",
			width = width,
			radius = 0,
			scale = GOO_SCALE,
			zIndex = 6,
		})
	end
	if wall ~= nil then
		local onWall = ReactRoblox.createPortal(
			e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true }, nodes),
			wall
		)
		-- Drawn on both until the stage is live, so the camera moves only once the wall is ready.
		nodes = if staged then { stage = onWall } else table.clone(nodes)
		nodes.stage = onWall
	end
	if props.children ~= nil then
		nodes.content = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 7,
		}, props.children)
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = true,
		ClipsDescendants = true,
		ZIndex = props.zIndex,
		[React.Change.AbsoluteSize] = function(frame: Frame)
			setWidth(math.floor(frame.AbsoluteSize.X))
		end,
		ref = function(frame: Frame?)
			if frame ~= nil then
				setWidth(math.floor(frame.AbsoluteSize.X))
			end
		end,
	}, nodes)
end

return ToonBackdrop
