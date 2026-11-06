--!strict
--[=[
	OfficeGlowSystem: light from cleaning and from the crew, on this client, while a shift runs (OfficeGlowRules decides).

	- Rooms glow when cleaned: each room of the office model (a folder holding its "Floor" part) counts the Gloom piles
	  (VacuumConstants.PILE_TAG) standing on its floor. A room that had piles this shift and has none left gets a soft
	  warm PointLight of its own above its floor, faded in. Its own light, not the room's lamps: the lamps belong to
	  OfficeAtmosphereSystem (colour, brightness) and OccupantTellSystem (on/off), so this composes with both.
	- Every crew member carries a small warm lantern (a PointLight on their root), culled with distance and dropped
	  for teammates on low graphics. On low graphics rooms do not glow.

	Everything is local (a folder under the camera, lights on roots made on this client): nothing replicates.
	Updated UPDATE_SECONDS apart. A new shift (the snapshot's shift number) forgets every room.

	Spec-exempt shell (Instances, CollectionService, UserGameSettings, RunService); the choices are the specced
	OfficeGlowRules.

	@class OfficeGlowSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local OfficeGlowRules = require(ReplicatedStorage.Client.Features.Office.Rules.OfficeGlowRules)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)

local UPDATE_SECONDS = 0.1
-- Piles are recounted this often (the glow fades on every update).
local RECOUNT_SECONDS = 0.5
local OFFICE_NAME = "CleanupCrewOffice"
local FLOOR_NAME = "Floor"
local LANTERN_NAME = "CrewLantern"
local GLOW_COLOR = Color3.fromRGB(255, 226, 170)
local LANTERN_COLOR = Color3.fromRGB(255, 205, 140)
-- How high above its floor a room's glow hangs, and how far above a floor a pile may stand and still count.
local GLOW_HEIGHT = 7
local PILE_HEIGHT = 12

type Room = {
	floor: BasePart,
	hadGloom: boolean,
	cleanedAt: number?,
	light: PointLight?,
}

local OfficeGlowSystem = {}

local function quality(): number
	local ok, level = pcall(function(): number
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	return if ok then level else 0
end

-- Whether `position` stands on `floor` (inside its footprint, at most PILE_HEIGHT above it).
local function onFloor(floor: BasePart, position: Vector3): boolean
	local localPoint = floor.CFrame:PointToObjectSpace(position)
	local half = floor.Size / 2
	return math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Z) <= half.Z
		and localPoint.Y >= -half.Y - 1
		and localPoint.Y <= PILE_HEIGHT
end

--[=[
	Starts the glows and lanterns; returns the stopper.
]=]
function OfficeGlowSystem.start(): () -> ()
	local folder = Instance.new("Folder")
	folder.Name = "OfficeGlow"
	local rooms: { [BasePart]: Room } = {}
	local lanterns: { [Player]: PointLight } = {}
	local shiftNumber: number? = nil
	local elapsed = 0
	local sinceCount = math.huge

	local function forgetRooms()
		for _, room in rooms do
			local light = room.light
			if light ~= nil and light.Parent ~= nil then
				local anchor = light.Parent
				anchor:Destroy()
			end
		end
		table.clear(rooms)
	end

	local function updateRooms(camera: Camera, low: boolean, recount: boolean)
		local office = Workspace:FindFirstChild(OFFICE_NAME)
		if office == nil then
			return
		end
		local floors: { BasePart } = {}
		for _, child in office:GetChildren() do
			local floor = if child:IsA("Folder") then child:FindFirstChild(FLOOR_NAME) else nil
			if floor ~= nil and floor:IsA("BasePart") then
				table.insert(floors, floor)
				if rooms[floor] == nil then
					rooms[floor] = { floor = floor, hadGloom = false }
				end
			end
		end
		local piles = CollectionService:GetTagged(VacuumConstants.PILE_TAG)
		local now = os.clock()
		for _, floor in floors do
			local room = rooms[floor]
			local distance = (floor.Position - camera.CFrame.Position).Magnitude
			if recount and OfficeGlowRules.judged(distance) then
				local count = 0
				for _, pile in piles do
					local position = if pile:IsA("BasePart")
						then pile.Position
						elseif pile:IsA("Model") then pile:GetPivot().Position
						else nil
					if position ~= nil and onFloor(floor, position) then
						count += 1
					end
				end
				if count > 0 then
					room.hadGloom = true
					room.cleanedAt = nil
				elseif OfficeGlowRules.cleaned(count, room.hadGloom) and room.cleanedAt == nil then
					room.cleanedAt = now
				end
			end
			local cleanedAt = room.cleanedAt
			local show = cleanedAt ~= nil and not low and distance <= OfficeGlowRules.CULL_RANGE
			local light = room.light
			if show and cleanedAt ~= nil then
				if light == nil then
					local anchor = Instance.new("Part")
					anchor.Name = "RoomGlow"
					anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
					anchor.Transparency = 1
					anchor.CastShadow = false
					anchor.Size = Vector3.one
					anchor.CFrame = CFrame.new(floor.Position + Vector3.new(0, GLOW_HEIGHT, 0))
					local made = Instance.new("PointLight")
					made.Color = GLOW_COLOR
					made.Shadows = false
					made.Range = OfficeGlowRules.range(floor.Size)
					made.Parent = anchor
					anchor.Parent = folder
					light = made
					room.light = made
				end
				if light ~= nil then
					light.Brightness = OfficeGlowRules.glow(now - cleanedAt)
					light.Enabled = true
				end
			elseif light ~= nil then
				light.Enabled = false
			end
		end
	end

	local function updateLanterns(camera: Camera, crew: { number }, running: boolean, low: boolean)
		local me = Players.LocalPlayer
		local wanted: { [Player]: boolean } = {}
		if running then
			local level = quality()
			for _, userId in crew do
				local player = Players:GetPlayerByUserId(userId)
				local character = if player ~= nil then player.Character else nil
				local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
				if player ~= nil and root ~= nil and root:IsA("BasePart") then
					local distance = (root.Position - camera.CFrame.Position).Magnitude
					local brightness = OfficeGlowRules.lantern(player == me, if low then 1 else level, distance)
					if brightness ~= nil then
						wanted[player] = true
						local old: PointLight? = lanterns[player]
						if old and old.Parent ~= root then
							old:Destroy()
							old = nil
						end
						local lantern: PointLight = old or Instance.new("PointLight")
						if not old then
							lantern.Name = LANTERN_NAME
							lantern.Color = LANTERN_COLOR
							lantern.Range = OfficeGlowRules.LANTERN_RANGE
							lantern.Shadows = false
							lantern.Parent = root
							lanterns[player] = lantern
						end
						lantern.Brightness = brightness
					end
				end
			end
		end
		for player, lantern in lanterns do
			if not wanted[player] then
				lantern:Destroy()
				lanterns[player] = nil
			end
		end
	end

	local function update(dt: number)
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		if folder.Parent ~= camera then
			folder.Parent = camera
		end
		local view = ShiftStore.snapshot()
		local running = view ~= nil and view.phase == "running"
		if view == nil or view.shift ~= shiftNumber then
			shiftNumber = if view ~= nil then view.shift else nil
			forgetRooms()
		end
		local low = OfficeGlowRules.lowEnd(quality())
		sinceCount += dt
		local recount = sinceCount >= RECOUNT_SECONDS
		if recount then
			sinceCount = 0
		end
		if running then
			updateRooms(camera, low, recount)
		elseif next(rooms) ~= nil then
			forgetRooms()
		end
		updateLanterns(camera, if view ~= nil then view.crew else {}, running, low)
	end

	local connection = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < UPDATE_SECONDS then
			return
		end
		local step = elapsed
		elapsed = 0
		update(step)
	end)

	return function()
		connection:Disconnect()
		forgetRooms()
		for _, lantern in lanterns do
			lantern:Destroy()
		end
		table.clear(lanterns)
		folder:Destroy()
	end
end

return OfficeGlowSystem
