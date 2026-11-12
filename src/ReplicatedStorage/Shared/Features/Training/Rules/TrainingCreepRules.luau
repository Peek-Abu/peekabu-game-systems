--!strict
--[=[
	TrainingCreepRules: how a Training "creep" patch of Gloom grows in (owner 11-12: the patches read as plain
	rectangles). A patch is an invisible floor part (its TrainingRole "creep" and ORDER) holding round goo blobs as
	its children. As it creeps in, every blob grows from a fraction of its size near the patch's centre out to where
	it was authored: its round face and its distance from the centre scale, its thickness and height never do, so
	the goo spreads over the floor instead of swelling. Pure: TrainingHallSystem plays it.

	@class TrainingCreepRules
]=]

local TrainingCreepRules = {}

--[=[
	A blob at `scale` (0..1) of its authored spread.
	@param offset the blob's CFrame in the patch's own space (the patch's up is +Y)
	@param size the blob's authored size
	@return (CFrame, Vector3) -- its CFrame in the patch's space, and its size
]=]
function TrainingCreepRules.grow(offset: CFrame, size: Vector3, scale: number): (CFrame, Vector3)
	local position = offset.Position
	local frame = CFrame.new(position.X * scale, position.Y, position.Z * scale) * offset.Rotation
	-- The blob's thickness is its local axis that points most nearly up in the patch.
	local x, y, z = math.abs(offset.RightVector.Y), math.abs(offset.UpVector.Y), math.abs(offset.LookVector.Y)
	local grown = if x >= y and x >= z
		then Vector3.new(size.X, size.Y * scale, size.Z * scale)
		elseif y >= z then Vector3.new(size.X * scale, size.Y, size.Z * scale)
		else Vector3.new(size.X * scale, size.Y * scale, size.Z)
	return frame, grown
end

return TrainingCreepRules
