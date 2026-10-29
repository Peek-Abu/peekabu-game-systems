--!strict
--[=[
	EmployeeOutfitFormulas: the maths for fitting a skinned outfit (EmployeeOutfitSystem) onto a character spawned at a
	scale other than the template's. An outfit is authored at the template's size: every offset in it (a Bone against
	its body part, a mesh against LowerTorso, a prop joint's C0/C1) has its position scaled by the character's scale and
	its rotation kept.

	@class EmployeeOutfitFormulas
]=]

local EmployeeOutfitFormulas = {}

--[=[
	`offset` with its position times `scale` and its rotation unchanged. Errors on a scale of 0 or below.
]=]
function EmployeeOutfitFormulas.scaled(offset: CFrame, scale: number): CFrame
	assert(scale > 0, "outfit scale must be positive")
	return offset - offset.Position + offset.Position * scale
end

--[=[
	A prop's Motor6D C0 and C1 at `scale`.
]=]
function EmployeeOutfitFormulas.joint(c0: CFrame, c1: CFrame, scale: number): (CFrame, CFrame)
	return EmployeeOutfitFormulas.scaled(c0, scale), EmployeeOutfitFormulas.scaled(c1, scale)
end

--[=[
	Where a joint's Part1 sits at rest (its animated Transform left out): Part0 * C0 * C1^-1. The fit places the meshes
	from LowerTorso's rest, so the pose the character is animating at fit time does not matter.
]=]
function EmployeeOutfitFormulas.rest(part0: CFrame, c0: CFrame, c1: CFrame): CFrame
	return part0 * c0 * c1:Inverse()
end

--[=[
	Where a piece goes on the character: it sat at `piece` against `reference` in the outfit (both at the template's
	size), and `target` is the character's matching frame.
]=]
function EmployeeOutfitFormulas.place(target: CFrame, reference: CFrame, piece: CFrame, scale: number): CFrame
	return target * EmployeeOutfitFormulas.scaled(reference:ToObjectSpace(piece), scale)
end

return EmployeeOutfitFormulas
