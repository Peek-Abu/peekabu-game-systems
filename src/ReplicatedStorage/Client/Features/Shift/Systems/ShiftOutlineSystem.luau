--!strict
--[=[
	ShiftOutlineSystem: the shift's through-the-walls outlines on this client (ShiftOutlineRules decides when and how
	strong). The truck the crew came in (the office's Truck folder: its art model, else its bed) is outlined once it is
	time to go; every other crew member is outlined, faded in with distance. Outlines only (no fill), drawn on top of
	walls: a Highlight each, a handful at most (crew of up to 6 plus the truck), so it stays cheap on phones.

	Local only: the Highlights live in a folder under the camera, so nothing replicates and Harlow never "sees" them.
	Updated UPDATE_SECONDS apart, not every frame.

	Spec-exempt shell (Highlight instances, Players, RunService); the choices are the specced ShiftOutlineRules.

	@class ShiftOutlineSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local ShiftOutlineRules = require(ReplicatedStorage.Client.Features.Shift.Rules.ShiftOutlineRules)

local UPDATE_SECONDS = 0.1
local TEAM_COLOR = Color3.fromRGB(120, 235, 195)
local TRUCK_COLOR = Color3.fromRGB(255, 214, 92)
local TRUCK_TRANSPARENCY = 0.35
local OFFICE_NAME = "CleanupCrewOffice"
local TRUCK_FOLDER = "Truck"
local TRUCK_BED = "TruckBed"

local ShiftOutlineSystem = {}

local function newHighlight(name: string, color: Color3, parent: Instance): Highlight
	local highlight = Instance.new("Highlight")
	highlight.Name = name
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillTransparency = 1
	highlight.OutlineColor = color
	highlight.OutlineTransparency = 1
	highlight.Enabled = false
	highlight.Parent = parent
	return highlight
end

-- The truck to outline: the art model in the office's Truck folder, else its bed.
local function truckTarget(): PVInstance?
	local office = Workspace:FindFirstChild(OFFICE_NAME)
	local folder = if office ~= nil then office:FindFirstChild(TRUCK_FOLDER) else nil
	if folder == nil then
		return nil
	end
	local art = folder:FindFirstChildWhichIsA("Model")
	if art ~= nil then
		return art
	end
	local bed = folder:FindFirstChild(TRUCK_BED)
	return if bed ~= nil and bed:IsA("BasePart") then bed else nil
end

--[=[
	Starts the outlines; returns the stopper.
]=]
function ShiftOutlineSystem.start(): () -> ()
	local folder = Instance.new("Folder")
	folder.Name = "ShiftOutlines"
	local truck = newHighlight("Truck", TRUCK_COLOR, folder)
	local crew: { [number]: Highlight } = {}
	local elapsed = 0

	local function update()
		local camera = Workspace.CurrentCamera
		if camera ~= nil and folder.Parent ~= camera then
			folder.Parent = camera
		end
		local view = ShiftStore.snapshot()
		local running = view ~= nil and view.phase == "running"
		-- The way back.
		local target = if ShiftOutlineRules.truckShown(view, Workspace:GetServerTimeNow()) then truckTarget() else nil
		truck.Adornee = target
		truck.OutlineTransparency = TRUCK_TRANSPARENCY
		truck.Enabled = target ~= nil
		-- Teammates.
		local me = Players.LocalPlayer
		local myCharacter = me.Character
		local myRoot = if myCharacter ~= nil then myCharacter:FindFirstChild("HumanoidRootPart") else nil
		local wanted: { [number]: boolean } = {}
		if running and view ~= nil and myRoot ~= nil and myRoot:IsA("BasePart") then
			for _, userId in view.crew do
				local player = if userId ~= me.UserId then Players:GetPlayerByUserId(userId) else nil
				local character = if player ~= nil then player.Character else nil
				local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
				if character ~= nil and root ~= nil and root:IsA("BasePart") then
					local transparency =
						ShiftOutlineRules.teammateTransparency((root.Position - myRoot.Position).Magnitude)
					if transparency ~= nil then
						wanted[userId] = true
						local highlight: Highlight = crew[userId] or newHighlight(`Crew{userId}`, TEAM_COLOR, folder)
						crew[userId] = highlight
						highlight.Adornee = character
						highlight.OutlineTransparency = transparency
						highlight.Enabled = true
					end
				end
			end
		end
		for userId, highlight in crew do
			if not wanted[userId] then
				highlight:Destroy()
				crew[userId] = nil
			end
		end
	end

	local connection = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < UPDATE_SECONDS then
			return
		end
		elapsed = 0
		update()
	end)

	return function()
		connection:Disconnect()
		folder:Destroy()
		table.clear(crew)
	end
end

return ShiftOutlineSystem
