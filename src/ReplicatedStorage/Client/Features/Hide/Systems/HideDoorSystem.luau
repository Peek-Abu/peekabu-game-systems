--!strict
--[=[
	HideDoorSystem: a supply cabinet's door on this client (2026-10-16 tuning; the cabinet is a secure hiding spot that
	is always closed). When the Manager checks a cabinet the server sets the furniture's DOOR_OPEN_ATTRIBUTE
	(HideServiceServer:setDoor): the door rattles in its frame for DOOR_RATTLE seconds (the telegraph), then swings
	DOOR_SWING degrees outward round its hinge edge (the cabinet's -X side) over DOOR_SECONDS; when the attribute clears it
	swings shut. The door is the art's `Door` part (ArtVisualSystem's visual), moved locally only: its weld to the root is
	switched off on this client while it moves (ArtVisualSystem parents the visual under the root), and the cabinet's collision never changes.

	Spec-exempt shell (CollectionService, Instances, RunService): no decisions, the timing is HideConstants'.

	@class HideDoorSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)

type Swing = {
	root: BasePart,
	door: BasePart,
	-- The door's closed frame in the root's space, and the hinge line's frame in the root's space.
	closed: CFrame,
	hinge: CFrame,
	opening: boolean,
	since: number,
	-- How far open it is now (0-1), and where the current move started from.
	amount: number,
	from: number,
}

local HideDoorSystem = {}

-- The art's door: the `Door` part of the ArtVisual model ArtVisualSystem parents under the root.
local function visualDoor(root: BasePart): BasePart?
	local visual = root:FindFirstChild("ArtVisual")
	local door = if visual ~= nil then visual:FindFirstChild(HideConstants.DOOR_PART, true) else nil
	return if door ~= nil and door:IsA("BasePart") then door else nil
end

local function setWelded(door: BasePart, welded: boolean)
	for _, weld in door:GetChildren() do
		if weld:IsA("WeldConstraint") then
			weld.Enabled = welded
		end
	end
end

function HideDoorSystem.start(): () -> ()
	local swings: { [BasePart]: Swing } = {}
	local connections: { RBXScriptConnection } = {}
	-- Each watched cabinet's attribute connection, dropped when it leaves the tag (the office is rebuilt every shift).
	local doors: { [BasePart]: RBXScriptConnection } = {}

	local function changed(root: BasePart)
		local open = root:GetAttribute(HideConstants.DOOR_OPEN_ATTRIBUTE) == true
		local swing = swings[root]
		if swing == nil then
			if not open then
				return
			end
			local door = visualDoor(root)
			if door == nil then
				return
			end
			local hinge = CFrame.new(-root.Size.X / 2 + 0.25, 0, -root.Size.Z / 2 + 0.1)
			swing = {
				root = root,
				door = door,
				closed = root.CFrame:ToObjectSpace(door.CFrame),
				hinge = hinge,
				opening = true,
				since = os.clock(),
				amount = 0,
				from = 0,
			}
			swings[root] = swing
			setWelded(door, false)
			return
		end
		swing.opening = open
		swing.since = os.clock()
		swing.from = swing.amount
	end

	local function watch(instance: Instance)
		if
			not instance:IsA("BasePart")
			or instance:GetAttribute(HideConstants.FURNITURE_KIND_ATTRIBUTE) ~= "cabinet"
		then
			return
		end
		local root = instance
		if doors[root] ~= nil then
			return
		end
		doors[root] = root:GetAttributeChangedSignal(HideConstants.DOOR_OPEN_ATTRIBUTE):Connect(function()
			changed(root)
		end)
		changed(root)
	end

	local function unwatch(instance: Instance)
		if not instance:IsA("BasePart") then
			return
		end
		local connection = doors[instance]
		if connection ~= nil then
			connection:Disconnect()
			doors[instance] = nil
		end
		swings[instance] = nil
	end

	for _, tagged in CollectionService:GetTagged(HideConstants.FURNITURE_TAG) do
		watch(tagged)
	end
	table.insert(connections, CollectionService:GetInstanceAddedSignal(HideConstants.FURNITURE_TAG):Connect(watch))
	table.insert(connections, CollectionService:GetInstanceRemovedSignal(HideConstants.FURNITURE_TAG):Connect(unwatch))
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function()
			local now = os.clock()
			for root, swing in swings do
				if root.Parent == nil or swing.door.Parent == nil then
					swings[root] = nil
					continue
				end
				local elapsed = now - swing.since
				local wobble = 0
				if swing.opening then
					if swing.from <= 0 and elapsed < HideConstants.DOOR_RATTLE then
						-- The handle tried: the door shakes in its frame before it gives.
						wobble = math.sin(elapsed * 55) * 1.6 * (1 - elapsed / HideConstants.DOOR_RATTLE)
						swing.amount = 0
					else
						local t = elapsed - (if swing.from <= 0 then HideConstants.DOOR_RATTLE else 0)
						swing.amount = math.min(1, swing.from + t / HideConstants.DOOR_SECONDS)
					end
				else
					swing.amount = math.max(0, swing.from - elapsed / HideConstants.DOOR_SECONDS)
				end
				local eased = 1 - (1 - swing.amount) ^ 2
				local angle = math.rad(HideConstants.DOOR_SWING * eased + wobble)
				local turn = swing.hinge * CFrame.Angles(0, angle, 0) * swing.hinge:Inverse()
				swing.door.CFrame = root.CFrame * turn * swing.closed
				if not swing.opening and swing.amount <= 0 then
					swing.door.CFrame = root.CFrame * swing.closed
					setWelded(swing.door, true)
					swings[root] = nil
				end
			end
		end)
	)
	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		for _, connection in doors do
			connection:Disconnect()
		end
		table.clear(doors)
		for root, swing in swings do
			if swing.door.Parent ~= nil and root.Parent ~= nil then
				swing.door.CFrame = root.CFrame * swing.closed
				setWelded(swing.door, true)
			end
		end
		table.clear(swings)
	end
end

return HideDoorSystem
