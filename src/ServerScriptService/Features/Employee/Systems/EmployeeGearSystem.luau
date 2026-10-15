--!strict
--[=[
	EmployeeGearSystem: fits art-owned gear onto a spawned employee character, on the server (so every client sees it
	through normal replication), and paints the rank lanyard.

	Fitted gear is a Model (under EmployeeConstants.ACCESSORIES_PATH in the game) modelled for one employee's body at
	the template's authored size: its `MountPart` attribute (EmployeeConstants.GEAR_MOUNT_ATTRIBUTE) names the body
	part it sits on, and its WorldPivot is that part's frame. Fitting clones it, scales it by the character's own scale
	(Model:ScaleTo, so an employee spawned at 1.25x wears 1.25x gear), pivots it onto the part and welds every piece
	there, weightless and out of collisions, queries and touches. It is gear rather than an Accessory because an
	Accessory added to a Model:ScaleTo'd character is not scaled, and fitted gear has several parts.

	The company uniform (vest, lanyard + ID card) is fitted gear every employee wears over its skin (EmployeeRegistry
	`uniform`); a skin's accessories can be fitted gear too (EmployeeSkinSystem). `badge` writes the rank onto the
	lanyard: the strap and the card's band in the rank colour, the holder's name, title and photo (their skin's
	portrait) on the card. The names it looks for are EmployeeConstants' LANYARD_STRAP / BADGE_*; anything missing is
	skipped.

	@class EmployeeGearSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)

-- What the lanyard shows: built by the caller from the holder's rank.
export type Badge = {
	holder: string,
	title: string,
	-- The text on the card's colour band.
	band: string,
	colour: Color3,
	-- The card's photo: "rbxassetid://<image id>" (EmployeeSkinRules.portrait).
	photo: string,
}

local EmployeeGearSystem = {}

--[=[
	Fits one gear template onto `character` (see the header). Returns the fitted clone, or nil when the template
	names no mount part or the character has no such part.
]=]
function EmployeeGearSystem.fit(character: Model, template: Model): Model?
	local mountName = template:GetAttribute(EmployeeConstants.GEAR_MOUNT_ATTRIBUTE)
	if type(mountName) ~= "string" then
		return nil
	end
	local mount = character:FindFirstChild(mountName)
	if mount == nil or not mount:IsA("BasePart") then
		return nil
	end
	local gear = template:Clone()
	local scale = character:GetScale()
	if scale ~= 1 then
		gear:ScaleTo(gear:GetScale() * scale)
	end
	gear:PivotTo(mount.CFrame)
	for _, descendant in gear:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = mount
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
	gear.Parent = character
	return gear
end

--[=[
	Fits each named gear Model found in `source` (names that are missing or not Models are skipped).
	@return number -- how many were fitted
]=]
function EmployeeGearSystem.wear(character: Model, names: { string }, source: Instance?): number
	if source == nil then
		return 0
	end
	local fitted = 0
	for _, name in names do
		local template = source:FindFirstChild(name)
		if template ~= nil and template:IsA("Model") and EmployeeGearSystem.fit(character, template) ~= nil then
			fitted += 1
		end
	end
	return fitted
end

--[=[
	Writes `badge` onto every lanyard the character wears.
	@return number -- how many strap parts and card elements were painted (0 without a lanyard)
]=]
function EmployeeGearSystem.badge(character: Model, badge: Badge): number
	local painted = 0
	for _, descendant in character:GetDescendants() do
		local name = descendant.Name
		if descendant:IsA("BasePart") and name == EmployeeConstants.LANYARD_STRAP then
			descendant.Color = badge.colour
			painted += 1
		elseif descendant:IsA("TextLabel") then
			if name == EmployeeConstants.BADGE_HOLDER then
				descendant.Text = badge.holder
				painted += 1
			elseif name == EmployeeConstants.BADGE_TITLE then
				descendant.Text = badge.title
				painted += 1
			elseif name == EmployeeConstants.BADGE_BAND_TEXT then
				descendant.Text = badge.band
				painted += 1
			end
		elseif descendant:IsA("Frame") and name == EmployeeConstants.BADGE_BAND then
			descendant.BackgroundColor3 = badge.colour
			painted += 1
		elseif descendant:IsA("ImageLabel") and name == EmployeeConstants.BADGE_PHOTO then
			descendant.Image = badge.photo
			painted += 1
		end
	end
	return painted
end

return EmployeeGearSystem
