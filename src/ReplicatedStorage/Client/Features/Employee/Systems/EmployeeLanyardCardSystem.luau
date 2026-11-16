--!strict
--[=[
	EmployeeLanyardCardSystem: mounts the v6 rank badge's whole-face front `InfoCard` on a built lanyard: an
	invisible `InfoCardHost` welded on the badge's front-most face, a `SurfaceGui` in `PlayerGui` adorned to it (so
	its circular 3D headshot `ViewportFrame` renders in Play), the holder's name and the rank line. Split out of
	EmployeeLanyardSystem.

	@class EmployeeLanyardCardSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local EmployeeShared = ReplicatedStorage.Shared.Features.Employee
local EmployeeConstants = require(EmployeeShared.Data.EmployeeConstants)
local EmployeeLanyardConstants = require(EmployeeShared.Data.EmployeeLanyardConstants)
local EmployeeClient = ReplicatedStorage.Client.Features.Employee
local EmployeeLanyardTypes = require(EmployeeClient.Data.EmployeeLanyardTypes)
local EmployeeLanyardPartUtils = require(EmployeeClient.Utils.EmployeeLanyardPartUtils)
local EmployeePortraitSystem = require(EmployeeClient.Systems.EmployeePortraitSystem)

type CardLayout = EmployeeLanyardConstants.CardLayout
type Handle = EmployeeLanyardTypes.Handle

local quiet = EmployeeLanyardPartUtils.quiet

local EmployeeLanyardCardSystem = {}

local function oneLine(label: TextLabel, text: string, font: Enum.Font, w: number, h: number, maxSize: number)
	local size = math.floor(math.min(maxSize, h))
	while size > 4 and TextService:GetTextSize(text, size, font, Vector2.new(10000, 10000)).X > w do
		size -= 1
	end
	label.Text = text
	label.Font = font
	label.TextSize = size
	label.TextScaled = false
	label.TextWrapped = false
end

local function px(box: { number }, canvas: { number }): (UDim2, UDim2)
	return UDim2.fromScale(box[1] / canvas[1], box[2] / canvas[2]),
		UDim2.fromScale(box[3] / canvas[1], box[4] / canvas[2])
end

local function mountPortrait(character: Model, parent: Instance, lay: CardLayout)
	local pos, size = px(lay.portrait, lay.canvas)
	local ring = Instance.new("Frame")
	ring.Name = "PortraitRing"
	ring.Position, ring.Size = pos, size
	ring.BackgroundColor3 = Color3.fromHex(lay.ringColour)
	ring.BorderSizePixel = 0
	Instance.new("UICorner", ring).CornerRadius = UDim.new(0.5, 0)
	ring.Parent = parent

	local vf = Instance.new("ViewportFrame")
	vf.Name = "Portrait"
	local inset = lay.ring / lay.portrait[3]
	vf.Position = UDim2.fromScale(inset, inset)
	vf.Size = UDim2.fromScale(1 - 2 * inset, 1 - 2 * inset)
	vf.BackgroundColor3 = Color3.fromHex(lay.backdrop)
	vf.BackgroundTransparency = 0
	vf.BorderSizePixel = 0
	vf.Ambient = Color3.fromRGB(190, 190, 190)
	vf.LightColor = Color3.new(1, 1, 1)
	vf.LightDirection = Vector3.new(-0.4, -0.6, 0.7)
	Instance.new("UICorner", vf).CornerRadius = UDim.new(0.5, 0)
	vf.Parent = ring

	local copy = EmployeePortraitSystem.build(character, nil)
	if copy == nil then
		return
	end
	for _, n in { EmployeeConstants.LANYARD_FOLDER, "VacuumBackpack" } do
		local x = copy:FindFirstChild(n, true)
		if x ~= nil then
			x:Destroy()
		end
	end
	local head = copy:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		copy:Destroy()
		return
	end
	local lo, hi = head.Position - head.Size / 2, head.Position + head.Size / 2
	local reach = head.Size.Magnitude * 1.2
	local neckY = head.Position.Y - head.Size.Y / 2
	for _, p in copy:GetDescendants() do
		if
			p:IsA("BasePart")
			and p ~= head
			and p.Transparency < 1
			and p.Position.Y > neckY
			and (p.Position - head.Position).Magnitude < reach
		then
			lo = lo:Min(p.Position - p.Size / 2)
			hi = hi:Max(p.Position + p.Size / 2)
		end
	end
	local centre = (lo + hi) / 2
	local half = math.max(hi.Y - lo.Y, hi.X - lo.X) / 2
	local cam = Instance.new("Camera")
	cam.FieldOfView = 28
	local dist = half / math.tan(math.rad(14)) * 1.1
	cam.CFrame = CFrame.lookAt(centre + Vector3.new(0, 0, -dist), centre)
	cam.Parent = vf
	vf.CurrentCamera = cam
	copy.Parent = vf
end

function EmployeeLanyardCardSystem.mountInfoCard(character: Model, handle: Handle, rank: number, holderName: string)
	local badgeRoot = handle.badgeRoot
	local localPlayer = Players.LocalPlayer
	local playerGui = if localPlayer ~= nil then localPlayer:FindFirstChildOfClass("PlayerGui") else nil
	if badgeRoot == nil or playerGui == nil then
		return
	end
	local lay = EmployeeLanyardConstants.INFO_FRONT[rank] or EmployeeLanyardConstants.INFO_FRONT[1]
	local s = handle.scale
	local thickness = 0.001 * s
	local host = Instance.new("Part")
	host.Name = "InfoCardHost"
	host.Size = Vector3.new(lay.size[1] * s, lay.size[2] * s, thickness)
	host.Transparency = 1
	quiet(host)
	-- On the badge's own front-most face (per rank), not at the model origin: the badge body is up to 0.02 studs
	-- deep, so the old fixed depth buried the card and its portrait inside it and they vanished as the camera
	-- came close. The SurfaceGui draws on the host's Front (-Z) face, half a thickness in front of its centre.
	local plane = handle.cardZ or lay.centre[3] * s
	host.CFrame = badgeRoot.CFrame
		* handle.badgeTurn
		* CFrame.new(lay.centre[1] * s, lay.centre[2] * s, plane + thickness / 2)
	local wc = Instance.new("WeldConstraint")
	wc.Part0, wc.Part1 = badgeRoot, host
	wc.Parent = host

	local gui = Instance.new("SurfaceGui")
	gui.Name = "InfoCard"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(lay.canvas[1], lay.canvas[2])
	gui.LightInfluence = 1
	gui.Adornee = host
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	host.Destroying:Connect(function()
		gui:Destroy()
	end)

	mountPortrait(character, gui, lay)

	local npos, nsize = px(lay.name, lay.canvas)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Position, nameLabel.Size = npos, nsize
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromHex("#1E0F3A")
	oneLine(nameLabel, string.upper(holderName), Enum.Font.LuckiestGuy, lay.name[3], lay.name[4], lay.nameMax)
	nameLabel.Parent = gui

	local lpos, lsize = px(lay.line, lay.canvas)
	local pill = Instance.new("TextLabel")
	pill.Name = "RankLine"
	pill.Position, pill.Size = lpos, lsize
	pill.BackgroundColor3 = Color3.fromHex(lay.fill)
	pill.BorderSizePixel = 0
	pill.TextColor3 = Color3.fromHex(lay.ink)
	local rankTitle = EmployeeLanyardConstants.RANK_NAMES[rank] or "NEW KID"
	local line = `RANK {rank} \u{00B7} {rankTitle}`
	oneLine(pill, line, Enum.Font.FredokaOne, lay.line[3] * 0.88, lay.line[4] * 0.8, lay.lineMax)
	Instance.new("UICorner", pill).CornerRadius = UDim.new(0.5, 0)
	pill.Parent = gui
	host.Parent = handle.folder
end

return EmployeeLanyardCardSystem
