--!strict
--[=[
	OfficeAmbienceSourceUtils: where OfficeAmbienceSystem's sounds can come from: the tagged OfficeAmbient emitters
	(emitters), where the crew stands (crew, so a phone rings only with nobody near), and the point a yard one-shot
	sounds from (yardSource: a rolled point inside one of its source volumes within reach, on the caller's Random).
	Reads only; changes nothing.

	Split out of OfficeAmbienceSystem.

	@class OfficeAmbienceSourceUtils
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfficeDecorConstants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeDecorConstants)
local OfficeAmbienceUtils = require(ReplicatedStorage.Client.Features.Office.Utils.OfficeAmbienceUtils)

local OfficeAmbienceSourceUtils = {}

--[=[
	Every tagged emitter with a kind (kind and position), and its part at the same index.
]=]
function OfficeAmbienceSourceUtils.emitters(): ({ OfficeAmbienceUtils.Emitter }, { BasePart })
	local list: { OfficeAmbienceUtils.Emitter } = {}
	local parts: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(OfficeDecorConstants.AMBIENT_TAG) do
		local kind = instance:GetAttribute(OfficeDecorConstants.AMBIENT_KIND_ATTRIBUTE)
		if instance:IsA("BasePart") and type(kind) == "string" then
			table.insert(list, { kind = kind, position = instance.Position })
			table.insert(parts, instance)
		end
	end
	return list, parts
end

--[=[
	Where each player's character stands (its HumanoidRootPart).
]=]
function OfficeAmbienceSourceUtils.crew(): { Vector3 }
	local positions: { Vector3 } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if root ~= nil and root:IsA("BasePart") then
			table.insert(positions, root.Position)
		end
	end
	return positions
end

-- Where a yard one-shot of `kind` sounds: a rolled point inside one of its source volumes within `reach` of the
-- camera; nil when none is (it stays quiet rather than play from the wrong place).
function OfficeAmbienceSourceUtils.yardSource(
	rng: Random,
	kind: string,
	reach: number,
	center: Vector3,
	list: { OfficeAmbienceUtils.Emitter },
	parts: { BasePart }
): Vector3?
	local sources: { BasePart } = {}
	local distances: { number } = {}
	for index, emitter in list do
		if emitter.kind == kind then
			local part = parts[index]
			table.insert(sources, part)
			table.insert(distances, OfficeAmbienceUtils.boxDistance(center, part.CFrame, part.Size))
		end
	end
	local picked = OfficeAmbienceUtils.pickNear(distances, reach, rng:NextNumber())
	if picked == nil then
		return nil
	end
	local part = sources[picked]
	return OfficeAmbienceUtils.pointInReach(
		center,
		part.CFrame,
		part.Size,
		reach,
		rng:NextNumber(),
		rng:NextNumber(),
		rng:NextNumber()
	)
end

return OfficeAmbienceSourceUtils
