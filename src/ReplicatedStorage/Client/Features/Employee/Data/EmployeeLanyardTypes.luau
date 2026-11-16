--!strict
--[=[
	EmployeeLanyardTypes: the types the client lanyard modules share (EmployeeLanyardSystem, EmployeeLanyardCardSystem,
	EmployeeLanyardSwaySystem). Types only (spec-exempt). Split out of EmployeeLanyardSystem.

	@class EmployeeLanyardTypes
]=]

export type Handle = {
	folder: Folder,
	strap: MeshPart?,
	badgeWeld: Weld?,
	badgeRoot: BasePart?,
	badgeTurn: CFrame,
	-- Local z of the plane the info card sits on: in front of the badge's own front-most part (nil without a badge).
	cardZ: number?,
	scale: number,
	destroy: () -> (),
}

return {}
