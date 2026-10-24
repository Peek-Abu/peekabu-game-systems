--!strict
--[=[
	EmployeeCharacterSystem: builds each player's own employee character and makes it theirs (character systems
	step 2; spike: reports/2026-10-24-character-spawn-spike.md). Replaces the one shared StarterCharacter for everyone.

	- `prepared(def, source)`: the employee's art (def.templatePath under `source`), prepared once per employee and
	  kept: rig + grip attachments and Animator (EmployeeSpawnSystem.prepare), scaled to def.scale, every part
	  un-anchored (art is often saved with its root anchored so it stands in the editor), overhead name/health off, and
	  HipHeight fitted from the geometry when the art was saved with 0 (EmployeeRigUtils.hipHeight). nil when this place
	  has no art for it.
	- `build(def, source, scripts)`: a fresh clone of that, stamped with its employee name and footstep set, with the
	  character scripts copied in (what the engine would copy from StarterCharacterScripts).
	- `assign(player, model, at, keepPlace)`: puts it at `at`, marks it to keep its place (Death's spawn point skips
	  it) when asked, makes it the player's character and removes the old one.

	@class EmployeeCharacterSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local DeathConstants = require(ReplicatedStorage.Shared.Features.Death.Data.DeathConstants)
local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)
local EmployeeRigUtils = require(ReplicatedStorage.Shared.Features.Employee.Utils.EmployeeRigUtils)
local EmployeeSpawnSystem = require(ServerScriptService.Features.Employee.Systems.EmployeeSpawnSystem)

local EmployeeCharacterSystem = {}

-- Prepared art per employee (and the source it came from, so a different source never reuses it).
local cache: { [string]: { source: Instance, model: Model } } = {}

local function resolve(root: Instance, path: { string }): Instance?
	local current: Instance? = root
	for _, name in path do
		if current == nil then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

-- The HipHeight that stands the model on its lowest point (rest pose).
local function fitHipHeight(model: Model, humanoid: Humanoid)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local lowest = math.huge
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= root then
			lowest = math.min(lowest, descendant.Position.Y - descendant.Size.Y / 2)
		end
	end
	if lowest < math.huge then
		humanoid.HipHeight = EmployeeRigUtils.hipHeight(root.Position.Y - root.Size.Y / 2, lowest)
	end
end

function EmployeeCharacterSystem.prepared(def: EmployeeRegistry.EmployeeDef, source: Instance): Model?
	local hit = cache[def.name]
	if hit ~= nil and hit.source == source and hit.model.Parent == nil then
		return hit.model
	end
	local template = resolve(source, def.templatePath)
	if template == nil or not template:IsA("Model") then
		return nil
	end
	local model = template:Clone()
	model:SetAttribute(EmployeeConstants.NAME_ATTRIBUTE, def.name)
	EmployeeSpawnSystem.prepare(model)
	EmployeeSpawnSystem.scale(model, def.scale)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		-- The crew never wear the engine's overhead name tag or health bar (as EmployeeSpawnSystem.install).
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		if humanoid.HipHeight <= 0 then
			fitHipHeight(model, humanoid)
		end
	end
	cache[def.name] = { source = source, model = model }
	return model
end

--[=[
	A fresh character for `def`, or nil when this place has no art for it. `scripts` is the folder whose children
	every character gets (StarterPlayer.StarterCharacterScripts in the game).
]=]
function EmployeeCharacterSystem.build(def: EmployeeRegistry.EmployeeDef, source: Instance, scripts: Instance): Model?
	local prepared = EmployeeCharacterSystem.prepared(def, source)
	if prepared == nil then
		return nil
	end
	local model = prepared:Clone()
	if def.footstepSet ~= nil then
		model:SetAttribute(EmployeeConstants.FOOTSTEP_SET_ATTRIBUTE, def.footstepSet)
	end
	for _, child in scripts:GetChildren() do
		child:Clone().Parent = model
	end
	return model
end

--[=[
	Makes `model` the player's character: named after them, pivoted to `at` (when given), marked to keep its place
	(Death's spawn point then leaves it there) when `keepPlace`, parented to the Workspace, and their old character
	removed. Shell over Players (spec-exempt behaviour; the spike covers it).
]=]
function EmployeeCharacterSystem.assign(player: Player, model: Model, at: CFrame?, keepPlace: boolean)
	local old = player.Character
	model.Name = player.Name
	if at ~= nil then
		model:PivotTo(at)
	end
	if keepPlace then
		model:SetAttribute(DeathConstants.KEEP_PLACE_ATTRIBUTE, true)
	end
	player.Character = model
	model.Parent = Workspace
	if old ~= nil and old ~= model then
		old:Destroy()
	end
end

-- Drops the prepared art (a place's art changed, or between specs).
function EmployeeCharacterSystem.clearCache()
	for _, entry in cache do
		entry.model:Destroy()
	end
	table.clear(cache)
end

return EmployeeCharacterSystem
