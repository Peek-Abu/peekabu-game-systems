--!strict
--[=[
	EmployeeTailSmartBoneUtils: hands a character's outfit tails to SmartBone 2 (Packages.SmartBone, MIT,
	github.com/smartbone-org/SmartBone-2) on this client, for outfits that ask for it
	(EmployeeConstants.TAIL_PHYSICS_ATTRIBUTE on the fitted Outfit folder).

	SmartBone simulates a tree of Bones under a tagged part. The outfit fit leaves each tail flat under LowerTorso
	(Tail<side><n>Bone, see EmployeeConstants), so `prepare` nests every chain in place (each bone keeps its world
	CFrame), marks the last one as the chain's end ("_end"), clears the outfit-bone mark so our own spring
	(EmployeeTailSystem) leaves them alone, writes SmartBone's settings (EmployeeConstants.SMARTBONE_DEFAULTS, each
	overridable by a Tail<name> attribute on the outfit), puts the outfit's per-bone TailBone<name> settings on every
	simulated bone below each chain's root (lengths scaled by the character's scale) and tags the character's own legs
	as its colliders under a collider key of its own. The local nesting never replicates; the server's flat bones stay as fitted.

	@class EmployeeTailSmartBoneUtils
]=]

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)

local END_SUFFIX = "_end"

local EmployeeTailSmartBoneUtils = {}

local function outfitFolder(character: Model): Instance?
	return character:FindFirstChild(EmployeeConstants.OUTFIT_FOLDER)
end

local function partOf(character: Model, name: string): BasePart?
	local found = character:FindFirstChild(name)
	return if found ~= nil and found:IsA("BasePart") then found else nil
end

--[=[
	Whether `character`'s fitted outfit asks for SmartBone tails.
]=]
function EmployeeTailSmartBoneUtils.wantsSmartBone(character: Model): boolean
	local folder = outfitFolder(character)
	return folder ~= nil
		and folder:GetAttribute(EmployeeConstants.TAIL_PHYSICS_ATTRIBUTE)
			== EmployeeConstants.TAIL_PHYSICS_SMARTBONE
end

-- A SmartBone setting as an attribute holds it.
export type Setting = string | number | boolean | Vector3 | NumberRange
export type Settings = { [string]: Setting }

-- `value` as a SmartBone setting, or nil when it is no kind a setting can be (attributes read as unknown).
local function asSetting(value: unknown): Setting?
	if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
		return value
	elseif typeof(value) == "Vector3" or typeof(value) == "NumberRange" then
		return value
	end
	return nil
end

-- Sets `result[name]` to `value` when `name` is a string and `value` is a setting.
local function put(result: Settings, name: unknown, value: unknown)
	local setting = asSetting(value)
	if type(name) == "string" and setting ~= nil then
		result[name] = setting
	end
end

local function startsWith(name: string, prefix: string): boolean
	return string.sub(name, 1, #prefix) == prefix
end

--[=[
	SmartBone's settings for an outfit: EmployeeConstants.SMARTBONE_DEFAULTS, each replaced by the outfit folder's
	Tail<name> attribute when it has one (TailPhysics itself and the per-bone TailBone<name> ones are not).
]=]
function EmployeeTailSmartBoneUtils.settings(folder: Instance): Settings
	local result: Settings = {}
	for name, value in EmployeeConstants.SMARTBONE_DEFAULTS do
		put(result, name, value)
	end
	local prefix = EmployeeConstants.TAIL_ATTRIBUTE_PREFIX
	for name, value in folder:GetAttributes() do
		if
			name ~= EmployeeConstants.TAIL_PHYSICS_ATTRIBUTE
			and startsWith(name, prefix)
			and not startsWith(name, EmployeeConstants.TAIL_BONE_ATTRIBUTE_PREFIX)
		then
			put(result, string.sub(name, #prefix + 1), value)
		end
	end
	return result
end

--[=[
	SmartBone's per-bone settings for an outfit: its TailBone<name> attributes, the lengths
	(EmployeeConstants.SMARTBONE_SCALED_BONE_SETTINGS) times `scale` (the character's scale).
]=]
function EmployeeTailSmartBoneUtils.boneSettings(folder: Instance, scale: number): Settings
	local result: Settings = {}
	local prefix = EmployeeConstants.TAIL_BONE_ATTRIBUTE_PREFIX
	for name, value in folder:GetAttributes() do
		if startsWith(name, prefix) then
			local setting = string.sub(name, #prefix + 1)
			local scaled = table.find(EmployeeConstants.SMARTBONE_SCALED_BONE_SETTINGS, setting) ~= nil
			if scaled and type(value) == "number" then
				result[setting] = value * scale
			elseif scaled and typeof(value) == "NumberRange" then
				result[setting] = NumberRange.new(value.Min * scale, value.Max * scale)
			else
				put(result, setting, value)
			end
		end
	end
	return result
end

-- The flat tail chains under `lower`, each in link order (the last bone is the chain's end marker).
local function chains(lower: BasePart): { { Bone } }
	local sides: { [string]: { { n: number, bone: Bone } } } = {}
	for _, child in lower:GetChildren() do
		if child:IsA("Bone") then
			local side, n = string.match(child.Name, EmployeeConstants.TAIL_BONE_PATTERN)
			local index = if n ~= nil then tonumber(n) else nil
			if side ~= nil and index ~= nil then
				local list = sides[side] or {}
				table.insert(list, { n = index, bone = child })
				sides[side] = list
			end
		end
	end
	local result: { { Bone } } = {}
	for _, list in sides do
		table.sort(list, function(a, b)
			return a.n < b.n
		end)
		if #list >= 2 then
			local chain: { Bone } = {}
			for i, entry in list do
				chain[i] = entry.bone
			end
			table.insert(result, chain)
		end
	end
	return result
end

--[=[
	Sets `character` up for SmartBone (see the header). Returns false, changing nothing, when its outfit doesn't ask
	for SmartBone or it has no tail chains.
]=]
function EmployeeTailSmartBoneUtils.prepare(character: Model): boolean
	local folder = outfitFolder(character)
	local lower = partOf(character, "LowerTorso")
	if folder == nil or lower == nil or not EmployeeTailSmartBoneUtils.wantsSmartBone(character) then
		return false
	end
	local found = chains(lower)
	if #found == 0 then
		return false
	end
	local roots: { string } = {}
	local perBone = EmployeeTailSmartBoneUtils.boneSettings(folder, character:GetScale())
	for _, chain in found do
		for _, bone in chain do
			bone.Transform = CFrame.identity
			bone:SetAttribute(EmployeeConstants.OUTFIT_BONE_ATTRIBUTE, nil)
		end
		for i = 2, #chain do
			local world = chain[i].WorldCFrame
			chain[i].Parent = chain[i - 1]
			chain[i].WorldCFrame = world
		end
		for i = 2, #chain do
			for name, value in perBone do
				chain[i]:SetAttribute(name, value)
			end
		end
		chain[#chain].Name ..= END_SUFFIX
		table.insert(roots, chain[1].Name)
	end
	local key = HttpService:GenerateGUID(false)
	for _, name in EmployeeConstants.SMARTBONE_LEG_COLLIDERS do
		local leg = partOf(character, name)
		if leg ~= nil then
			leg:SetAttribute("ColliderKey", key)
			leg:SetAttribute("ColliderShape", "Capsule")
			CollectionService:AddTag(leg, EmployeeConstants.SMARTBONE_COLLIDER_TAG)
		end
	end
	for name, value in EmployeeTailSmartBoneUtils.settings(folder) do
		lower:SetAttribute(name, value)
	end
	lower:SetAttribute("Roots", table.concat(roots, ","))
	lower:SetAttribute("ColliderKey", key)
	-- Last: SmartBone reads the colliders and settings when the tag arrives.
	CollectionService:AddTag(lower, EmployeeConstants.SMARTBONE_TAG)
	return true
end

--[=[
	Takes `character` out of SmartBone: removes its root-part and leg tags.
]=]
function EmployeeTailSmartBoneUtils.release(character: Model)
	local lower = partOf(character, "LowerTorso")
	if lower ~= nil then
		CollectionService:RemoveTag(lower, EmployeeConstants.SMARTBONE_TAG)
	end
	for _, name in EmployeeConstants.SMARTBONE_LEG_COLLIDERS do
		local leg = partOf(character, name)
		if leg ~= nil then
			CollectionService:RemoveTag(leg, EmployeeConstants.SMARTBONE_COLLIDER_TAG)
		end
	end
end

return EmployeeTailSmartBoneUtils
