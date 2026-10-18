--!strict
--[=[
	EmployeePortraitSystem: builds a portrait copy of a character for a ViewportFrame (CharacterPortrait): a static
	model that shows the character's look (skin palette, faces, uniform, accessories) in a chosen pose, and that the
	engine never needs to update.

	- Copy: the character is cloned (a player's character is not Archivable: the flag is lifted for the clone and
	  put back), so the live character is never touched otherwise.
	- Strip: scripts, sounds, Tools, effects (particles, beams, trails, lights, fire, highlights), GUIs, IK, the
	  Animator and the equipment EmployeePoseRegistry.STRIP names leave the copy.
	- Pose: every Motor6D's offset is rebuilt from its C0/C1 under the pose's turn (rest for joints the pose does
	  not name, so the live animation frame never leaks in); welds keep their offsets. The parts are placed by
	  forward kinematics from the root (EmployeePoseFormulas.solve), standing at the origin facing -Z. A part no
	  joint ties to the root (something carried loose) is dropped.
	- Freeze: every joint is removed and every part anchored: with no WorldModel and nothing animated, the
	  viewport renders the copy once and then only when it is resized, instead of every frame.
	- Face: the pose's face goes on the FacePlate (EmployeeFaceSystem.apply) and the unused face set is dropped.

	@class EmployeePortraitSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeShared = ReplicatedStorage.Shared.Features.Employee
local EmployeeConstants = require(EmployeeShared.Data.EmployeeConstants)
local EmployeePoseRegistry = require(EmployeeShared.Data.EmployeePoseRegistry)
local EmployeePoseFormulas = require(EmployeeShared.Utils.EmployeePoseFormulas)
local EmployeeFaceSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeeFaceSystem)

local ROOT = "HumanoidRootPart"

local EmployeePortraitSystem = {}

-- Classes a portrait never needs: behaviour, sound, effects and anything the engine would update per frame.
local function strippable(instance: Instance): boolean
	return instance:IsA("LuaSourceContainer")
		or instance:IsA("Sound")
		or instance:IsA("Tool")
		or instance:IsA("ParticleEmitter")
		or instance:IsA("Beam")
		or instance:IsA("Trail")
		or instance:IsA("Light")
		or instance:IsA("Fire")
		or instance:IsA("Smoke")
		or instance:IsA("Sparkles")
		or instance:IsA("Highlight")
		or instance:IsA("ForceField")
		or instance:IsA("LayerCollector")
		or instance:IsA("IKControl")
		or instance:IsA("Animator")
		or instance:IsA("AnimationController")
		or instance:IsA("ProximityPrompt")
		or instance:IsA("ClickDetector")
end

local function copyOf(character: Model): Model?
	local was = character.Archivable
	character.Archivable = true
	local ok, copy = pcall(function(): Instance?
		return character:Clone()
	end)
	character.Archivable = was
	if ok and copy ~= nil and copy:IsA("Model") then
		return copy
	end
	return nil
end

local function strip(copy: Model)
	for _, name in EmployeePoseRegistry.STRIP do
		local equipment = copy:FindFirstChild(name)
		if equipment ~= nil then
			equipment:Destroy()
		end
	end
	for _, descendant in copy:GetDescendants() do
		if descendant.Parent ~= nil and strippable(descendant) then
			descendant:Destroy()
		end
	end
end

type Links = { parts: { BasePart }, links: { EmployeePoseFormulas.Link } }

-- The copy's joint graph: its parts by index and a link per joint, Motor6Ds under the pose's turns.
local function linksOf(copy: Model, pose: EmployeePoseRegistry.PoseDef?): Links
	local parts: { BasePart } = {}
	local index: { [BasePart]: number } = {}
	local function indexOf(part: BasePart): number
		local found = index[part]
		if found == nil then
			table.insert(parts, part)
			found = #parts
			index[part] = found
		end
		return found
	end
	local links: { EmployeePoseFormulas.Link } = {}
	for _, joint in copy:GetDescendants() do
		local part0: BasePart?, part1: BasePart?, offset: CFrame? = nil, nil, nil
		if joint:IsA("Motor6D") then
			local turn = if pose ~= nil then pose.joints[joint.Name] else nil
			local transform = if turn ~= nil then EmployeePoseFormulas.turn(turn) else CFrame.identity
			part0, part1, offset = joint.Part0, joint.Part1, EmployeePoseFormulas.motor(joint.C0, joint.C1, transform)
		elseif joint:IsA("JointInstance") then
			part0, part1, offset = joint.Part0, joint.Part1, joint.C0 * joint.C1:Inverse()
		elseif joint:IsA("WeldConstraint") or joint:IsA("RigidConstraint") then
			local a: BasePart?, b: BasePart? = nil, nil
			if joint:IsA("WeldConstraint") then
				a, b = joint.Part0, joint.Part1
			elseif joint:IsA("RigidConstraint") then
				local at0, at1 = joint.Attachment0, joint.Attachment1
				local p0 = if at0 ~= nil then at0.Parent else nil
				local p1 = if at1 ~= nil then at1.Parent else nil
				if
					at0 ~= nil
					and at1 ~= nil
					and p0 ~= nil
					and p0:IsA("BasePart")
					and p1 ~= nil
					and p1:IsA("BasePart")
				then
					a, b = p0, p1
				end
			end
			if a ~= nil and b ~= nil then
				part0, part1, offset = a, b, a.CFrame:ToObjectSpace(b.CFrame)
			end
		end
		if
			part0 ~= nil
			and part1 ~= nil
			and offset ~= nil
			and part0:IsDescendantOf(copy)
			and part1:IsDescendantOf(copy)
		then
			table.insert(links, { a = indexOf(part0), b = indexOf(part1), offset = offset })
		end
	end
	return { parts = parts, links = links }
end

--[=[
	A posed, static portrait copy of `character`, or nil when it has no root part yet (not streamed in). The caller
	owns the copy (parents it into a ViewportFrame and destroys it).
	@param pose nil = the rig's rest pose with its current face.
]=]
function EmployeePortraitSystem.build(character: Model, pose: EmployeePoseRegistry.PoseDef?): Model?
	if character:FindFirstChild(ROOT) == nil then
		return nil
	end
	local copy = copyOf(character)
	if copy == nil then
		return nil
	end
	local root = copy:FindFirstChild(ROOT)
	if root == nil or not root:IsA("BasePart") then
		copy:Destroy()
		return nil
	end
	strip(copy)
	local graph = linksOf(copy, pose)
	local rootIndex = table.find(graph.parts, root)
	local placed: { [number]: CFrame } = if rootIndex ~= nil
		then EmployeePoseFormulas.solve(rootIndex, CFrame.identity, graph.links)
		else {}
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("JointInstance") or descendant:IsA("Constraint") or descendant:IsA("WeldConstraint") then
			descendant:Destroy()
		end
	end
	local frames: { [BasePart]: CFrame } = { [root] = CFrame.identity }
	for index, frame in placed do
		frames[graph.parts[index]] = frame
	end
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Parent ~= nil then
			local frame: CFrame? = frames[descendant]
			if frame == nil then
				descendant:Destroy()
			else
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
				descendant.CastShadow = false
				descendant.CFrame = frame
			end
		end
	end
	if pose ~= nil and pose.face ~= nil then
		EmployeeFaceSystem.apply(copy, pose.face, true)
	end
	local faces = copy:FindFirstChild(EmployeeConstants.FACES_FOLDER)
	if faces ~= nil then
		faces:Destroy()
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	copy.PrimaryPart = root
	return copy
end

--[=[
	The boxes of the copy's visible parts called one of `names` (framing a head or a bust), or of every visible part
	when none of them is there.
]=]
function EmployeePortraitSystem.boxes(copy: Model, names: { string }?): { EmployeePoseFormulas.Box }
	local named: { EmployeePoseFormulas.Box } = {}
	local all: { EmployeePoseFormulas.Box } = {}
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Transparency < 1 then
			local box: EmployeePoseFormulas.Box = { cframe = descendant.CFrame, size = descendant.Size }
			table.insert(all, box)
			if names ~= nil and table.find(names, descendant.Name) ~= nil then
				table.insert(named, box)
			end
		end
	end
	return if #named > 0 then named else all
end

return EmployeePortraitSystem
