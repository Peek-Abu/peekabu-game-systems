--!strict
--[=[
	TrainingHarlowSystem: carries out Mr. Harlow's scripted pass at the training's escape stop (TrainingPassRules decides;
	owner-approved redesign, 2026-11-10). One per training run.

	- Before the pass and after it, he waits offstage: parked at the map's offstage spot, frozen (no sight, hearing or
	  catches), so he never wanders the training hall.
	- `begin` starts a pass; every `poll` senses him and the player (TrainingPassRules.Sense) and carries out the
	  commands: OccupantServiceServer:direct walks, turns, parks and frees him or starts a real chase.
	- His two doors swing open and shut on their -X edge (PASS.swing; while open they do not block). Each door's
	  TrainingSwingOpen attribute says it is open, so the client plays the creak and the slam (TrainingHallSystem).
	  The offstage spot's lights (the light spilling through the STAFF door) shine only while that door is open.
	- While he is in the room he carries a flashlight (a warm spot from his head and a faint glow), so a hidden player
	  can watch him walk past in the dark; it goes when he is parked offstage.
	- `caught` marks a catch this pass; `clean` is true once he left without one (the stop is done).

	Spec-exempt shell (Instances, tweens, Occupant, Hide); the decisions are the specced TrainingPassRules.

	@class TrainingHarlowSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local HideServiceServer = require(ServerScriptService.Features.Hide.HideServiceServer)
local OccupantServiceServer = require(ServerScriptService.Features.Occupant.OccupantServiceServer)
local TrainingMapRules = require(ServerScriptService.Features.Training.Rules.TrainingMapRules)
local TrainingPassRules = require(ServerScriptService.Features.Training.Rules.TrainingPassRules)

export type Director = {
	begin: (self: Director) -> (),
	poll: (self: Director) -> (),
	caught: (self: Director) -> (),
	clean: (self: Director) -> boolean,
	stop: (self: Director) -> (),
}

-- How far a door swings open (degrees).
local SWING_DEGREES = 100
-- He sees a player within this half-angle of his facing (degrees).
local SIGHT_HALF_ANGLE = 70
-- His brain's modes that mean he is after someone.
local HUNTING: { [string]: boolean } = { chase = true, search = true, stare = true, alert = true, catch = true }

-- One of his doors: the part, its shut frame, and its swing.
type Door = { part: BasePart, shut: CFrame, tween: Tween? }

local function doorOf(model: Model, role: string): Door?
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute(TrainingConstants.ROLE_ATTRIBUTE) == role then
			return { part = part, shut = part.CFrame, tween = nil }
		end
	end
	return nil
end

-- Swings `door` open (on its -X edge) or shut. Open, it never blocks him or the player.
local function swing(door: Door?, open: boolean)
	if door == nil then
		return
	end
	local part = door.part
	local hinge = door.shut * CFrame.new(-part.Size.X / 2, 0, 0)
	local goal = if open
		then hinge * CFrame.Angles(0, math.rad(SWING_DEGREES), 0) * CFrame.new(part.Size.X / 2, 0, 0)
		else door.shut
	local running = door.tween
	if running ~= nil then
		running:Cancel()
	end
	part.Anchored = true
	part.CanCollide = not open
	part:SetAttribute("TrainingSwingOpen", open)
	local tween = TweenService:Create(
		part,
		TweenInfo.new(
			TrainingConstants.PASS.swing,
			if open then Enum.EasingStyle.Quad else Enum.EasingStyle.Back,
			if open then Enum.EasingDirection.Out else Enum.EasingDirection.In
		),
		{ CFrame = goal }
	)
	door.tween = tween
	tween:Play()
end

local TrainingHarlowSystem = {}

function TrainingHarlowSystem.new(player: Player, model: Model, plan: TrainingMapRules.Plan): Director
	local pass = TrainingPassRules.new()
	local staff = doorOf(model, "staffDoor")
	local exit = doorOf(model, "exitDoor")
	local spill: { Light } = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute(TrainingConstants.ROLE_ATTRIBUTE) == "offstage" then
			for _, light in part:GetDescendants() do
				if light:IsA("Light") then
					light.Enabled = false
					table.insert(spill, light)
				end
			end
		end
	end
	local function spilling(on: boolean)
		for _, light in spill do
			light.Enabled = on
		end
	end

	-- His flashlight while he walks the room (made on his current rig, removed when he is parked).
	local torch: { Instance } = {}
	local function flashlight(on: boolean)
		for _, light in torch do
			light:Destroy()
		end
		table.clear(torch)
		local harlow = OccupantServiceServer:getHarlow()
		local head = if harlow ~= nil then harlow:FindFirstChild("Head") else nil
		if not on or head == nil or not head:IsA("BasePart") then
			return
		end
		local beam = Instance.new("SpotLight")
		beam.Name = "TrainingFlashlight"
		beam.Face = Enum.NormalId.Front
		beam.Angle = 55
		beam.Range = 30
		beam.Brightness = 4
		beam.Color = Color3.fromRGB(255, 226, 170)
		beam.Shadows = true
		beam.Parent = head
		local glow = Instance.new("PointLight")
		glow.Name = "TrainingGlow"
		glow.Range = 9
		glow.Brightness = 0.8
		glow.Color = Color3.fromRGB(255, 214, 160)
		glow.Parent = head
		table.insert(torch, beam)
		table.insert(torch, glow)
	end

	local function rootOf(): BasePart?
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		return if root ~= nil and root:IsA("BasePart") then root else nil
	end

	-- He sees the player in the open: not hidden, in front of him, within PASS.spot, a clear line.
	local function spots(harlow: Model, root: BasePart): boolean
		if HideServiceServer:isHidden(player) then
			return false
		end
		local head = harlow:FindFirstChild("Head")
		local eye = if head ~= nil and head:IsA("BasePart") then head.Position else harlow:GetPivot().Position
		local toPlayer = root.Position - eye
		if toPlayer.Magnitude > TrainingConstants.PASS.spot then
			return false
		end
		local look = harlow:GetPivot().LookVector * Vector3.new(1, 0, 1)
		local flat = toPlayer * Vector3.new(1, 0, 1)
		if look.Magnitude > 0.01 and flat.Magnitude > 0.01 then
			if look.Unit:Dot(flat.Unit) < math.cos(math.rad(SIGHT_HALF_ANGLE)) then
				return false
			end
		end
		local params = RaycastParams.new()
		local ignore: { Instance } = { harlow }
		if player.Character ~= nil then
			table.insert(ignore, player.Character)
		end
		params.FilterDescendantsInstances = ignore
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.RespectCanCollide = true
		return Workspace:Raycast(eye, toPlayer, params) == nil
	end

	local function sense(): TrainingPassRules.Sense
		local now = os.clock()
		local harlow = OccupantServiceServer:getHarlow()
		local root = rootOf()
		if harlow == nil then
			return {
				now = now,
				arrived = false,
				spotted = false,
				hunting = false,
				missing = true,
				player = if root ~= nil then root.Position else nil,
			}
		end
		local directed = OccupantServiceServer:directed()
		local mind = OccupantServiceServer:getMind()
		return {
			now = now,
			arrived = directed ~= nil and directed.kind == "freeze",
			spotted = root ~= nil and spots(harlow, root),
			hunting = mind ~= nil and HUNTING[mind.mode] == true,
			missing = false,
			player = if root ~= nil then root.Position else nil,
		}
	end

	local function carry(commands: { TrainingPassRules.Command })
		for _, command in commands do
			if command.kind == "openStaff" then
				swing(staff, true)
				spilling(true)
				flashlight(true)
			elseif command.kind == "closeStaff" then
				swing(staff, false)
				spilling(false)
			elseif command.kind == "openExit" then
				swing(exit, true)
			elseif command.kind == "closeExit" then
				swing(exit, false)
			elseif command.kind == "walk" then
				OccupantServiceServer:direct({ kind = "walk", position = command.position, run = false })
			elseif command.kind == "face" then
				OccupantServiceServer:direct({ kind = "face", position = command.position })
			elseif command.kind == "chase" then
				OccupantServiceServer:direct({ kind = "chase", userId = player.UserId })
			elseif command.kind == "park" then
				OccupantServiceServer:direct({ kind = "park", cframe = plan.offstage })
				flashlight(false)
			end
		end
	end

	-- Offstage (before and after a pass): parked out of sight, once per rig (a new rig is parked again).
	local parkedRig: Model? = nil
	local function keepOffstage()
		local harlow = OccupantServiceServer:getHarlow()
		if harlow ~= nil and (harlow ~= parkedRig or OccupantServiceServer:directed() == nil) then
			if OccupantServiceServer:direct({ kind = "park", cframe = plan.offstage }) then
				parkedRig = harlow
			end
		end
	end

	local director: Director = {
		begin = function(_self)
			carry(TrainingPassRules.begin(pass, os.clock()))
		end,

		poll = function(_self)
			local phase = pass.phase
			if phase == "offstage" or (phase == "gone" and not pass.caught) then
				keepOffstage()
				return
			end
			carry(TrainingPassRules.step(pass, sense(), plan.lane))
			if pass.phase == "gone" then
				parkedRig = OccupantServiceServer:getHarlow()
			end
		end,

		caught = function(_self)
			TrainingPassRules.caught(pass)
		end,

		clean = function(_self)
			return TrainingPassRules.clean(pass)
		end,

		stop = function(_self)
			flashlight(false)
			swing(staff, false)
			swing(exit, false)
			spilling(false)
		end,
	}
	return director
end

return TrainingHarlowSystem
