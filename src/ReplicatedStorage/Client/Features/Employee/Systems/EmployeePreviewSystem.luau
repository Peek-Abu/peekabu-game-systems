--!strict
--[=[
	EmployeePreviewSystem: the models the character screens show in ViewportFrames (Inventory, the first-join pick,
	later the Shop and reveals): any employee in any skin, built on the client from the art in ReplicatedStorage and
	dressed by the same EmployeeSkinSystem the server dresses real characters with, so a preview never drifts.

	- `static(employee, skin, source, pose?)`: posed once and frozen (EmployeePortraitSystem.build): every part
	  anchored, no Animator, no scripts. The engine renders it once: cards and grids.
	- `live(employee, skin, source)`: the dressed model with its root held and the body free, an Animator, no
	  scripts: put it in a WorldModel and `playIdle` it. At most LIVE_CAP exist at once (the hero and one hovered
	  card); `live` returns nil past the cap, and a destroyed live preview frees its slot.
	- `skin` is an EmployeeRegistry skin key (nil = the default look); an unknown one falls back to the default.
	- `outfit(outfit, source, character, live, pose?)`: a whole player's look (CosmeticOutfitRules): a clone of
	  `character` (your own, live one) when it is that employee in that skin, so everything the server put on it
	  comes along (the rank lanyard and badge, the vacuum pack), else the dressed template; then the outfit's vacuum
	  goes on the pack (VacuumPreviewSystem.swap). Live (and its second result true) when asked and a slot is free,
	  else posed and frozen like `static`.

	@class EmployeePreviewSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeShared = ReplicatedStorage.Shared.Features.Employee
local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local EmployeeConstants = require(EmployeeShared.Data.EmployeeConstants)
local EmployeePoseRegistry = require(EmployeeShared.Data.EmployeePoseRegistry)
local EmployeeRegistry = require(EmployeeShared.Data.EmployeeRegistry)
local EmployeeSkinRules = require(EmployeeShared.Rules.EmployeeSkinRules)
local EmployeeSkinSystem = require(EmployeeShared.Systems.EmployeeSkinSystem)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local VacuumSkinRules = require(ReplicatedStorage.Shared.Features.Vacuum.Rules.VacuumSkinRules)
local EmployeePortraitSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeePortraitSystem)
local VacuumPreviewSystem = require(ReplicatedStorage.Client.Features.Vacuum.Systems.VacuumPreviewSystem)

local LIVE_CAP = 2

local EmployeePreviewSystem = {
	LIVE_CAP = LIVE_CAP,
}

local live: { [Model]: RBXScriptConnection } = {}
local liveCount = 0

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

-- A dressed clone of the employee's art (scripts removed), or nil.
local function dressed(employee: string, skin: string?, source: Instance): Model?
	local def = EmployeeRegistry.get(employee)
	if def == nil then
		return nil
	end
	local template = resolve(source, def.templatePath)
	if template == nil or not template:IsA("Model") then
		return nil
	end
	local model = template:Clone()
	model:SetAttribute(EmployeeConstants.NAME_ATTRIBUTE, def.name)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	local look = EmployeeSkinRules.select(def, skin)
	if look ~= nil then
		EmployeeSkinSystem.apply(model, look, resolve(source, EmployeeConstants.ACCESSORIES_PATH))
	end
	return model
end

function EmployeePreviewSystem.static(
	employee: string,
	skin: string?,
	source: Instance,
	pose: EmployeePoseRegistry.PoseDef?
): Model?
	local model = dressed(employee, skin, source)
	if model == nil then
		return nil
	end
	local copy = EmployeePortraitSystem.build(model, pose)
	model:Destroy()
	return copy
end

-- Readies `model` to animate in a WorldModel (root held, body free, an Animator) and takes a live slot.
local function makeLive(model: Model): Model
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = descendant.Name == "HumanoidRootPart"
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil and humanoid:FindFirstChildOfClass("Animator") == nil then
		Instance.new("Animator").Parent = humanoid
	end
	liveCount += 1
	live[model] = model.Destroying:Connect(function()
		local connection: RBXScriptConnection? = live[model]
		if connection then
			connection:Disconnect()
			live[model] = nil
			liveCount -= 1
		end
	end)
	return model
end

function EmployeePreviewSystem.live(employee: string, skin: string?, source: Instance): Model?
	if liveCount >= LIVE_CAP then
		return nil
	end
	local model = dressed(employee, skin, source)
	return if model ~= nil then makeLive(model) else nil
end

-- A copy of a live character for a preview: scripts, tools and overhead labels left out.
local function cloneCharacter(character: Model): Model
	-- A player's character is not Archivable; it is made so just for the copy.
	local archivable = character.Archivable
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = archivable
	for _, descendant in copy:GetDescendants() do
		if
			descendant:IsA("LuaSourceContainer")
			or descendant:IsA("Tool")
			or descendant:IsA("BillboardGui")
			or descendant:IsA("ForceField")
		then
			descendant:Destroy()
		end
	end
	return copy
end

function EmployeePreviewSystem.outfit(
	outfit: CosmeticTypes.Outfit,
	source: Instance,
	character: Model?,
	wantLive: boolean,
	pose: EmployeePoseRegistry.PoseDef?
): (Model?, boolean)
	local skinKey = CosmeticRegistry.keyOf(outfit.look.skin)
	local model: Model? = nil
	if
		character ~= nil
		and character:GetAttribute(EmployeeConstants.NAME_ATTRIBUTE) == outfit.employee
		and character:GetAttribute(EmployeeConstants.SKIN_ATTRIBUTE) == skinKey
	then
		model = cloneCharacter(character)
	end
	if model == nil then
		model = dressed(outfit.employee, skinKey, source)
	end
	if model == nil then
		return nil, false
	end
	VacuumPreviewSystem.swap(model, VacuumSkinRules.select(CosmeticRegistry.keyOf(outfit.vacuum)), source)
	if wantLive and liveCount < LIVE_CAP then
		return makeLive(model), true
	end
	local copy = EmployeePortraitSystem.build(model, pose, true)
	model:Destroy()
	return copy, false
end

-- The animation registry key of the employee's idle loop (nil = no own locomotion).
function EmployeePreviewSystem.idleOf(employee: string): string?
	local def = EmployeeRegistry.get(employee)
	local locomotion = if def ~= nil then def.locomotion else nil
	return if locomotion ~= nil then locomotion.idle else nil
end

--[=[
	Plays the employee's idle loop on a live preview (call after it is parented into a WorldModel). Returns the
	track, nil when there is nothing to play.
]=]
function EmployeePreviewSystem.playIdle(model: Model, employee: string): AnimationTrack?
	local key = EmployeePreviewSystem.idleOf(employee)
	local def = if key ~= nil then AnimationRegistry.get(key) else nil
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = if humanoid ~= nil then humanoid:FindFirstChildOfClass("Animator") else nil
	if def == nil or animator == nil then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = def.assetId
	local track = animator:LoadAnimation(animation)
	track.Looped = true
	track:Play(0)
	return track
end

function EmployeePreviewSystem.liveCount(): number
	return liveCount
end

-- Forgets every live slot (between specs).
function EmployeePreviewSystem.reset()
	for _, connection in live do
		connection:Disconnect()
	end
	table.clear(live)
	liveCount = 0
end

return EmployeePreviewSystem
