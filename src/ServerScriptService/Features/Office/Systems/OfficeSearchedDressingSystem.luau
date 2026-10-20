--!strict
-- Hollow furniture with independently moving drawers/doors. Gameplay proxies remain unchanged.
local TweenService = game:GetService("TweenService")
local ServerScriptService = game:GetService("ServerScriptService")
local Constants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
export type FurnitureKind = "desk" | "locker"
type Saved = { frame: CFrame, weld: WeldConstraint?, tween: Tween? }
type Record = { parts: { [BasePart]: Saved }, fallback: Model?, hidden: { [BasePart]: number } }
export type Controller = { apply: (part: BasePart, kind: FurnitureKind) -> (), clear: () -> () }
local System = {}
local function piece(
	parent: Model,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	component: string?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(position)
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	if component then
		p:SetAttribute("SearchComponent", component)
	end
	p.Parent = parent
	return p
end
-- Editable native prototype of the same oak/slate furniture. Mesh imports can replace its pieces,
-- retaining SearchComponent attributes; no second searched asset or runtime overlay is required.
function System.buildTemplate(kind: FurnitureKind): Model
	local model = Instance.new("Model")
	model.Name = if kind == "desk" then "desk" else "locker"
	local oak = Color3.fromRGB(198, 154, 96)
	local slate = Color3.fromRGB(83, 101, 122)
	local steel = Color3.fromRGB(48, 54, 58)
	if kind == "desk" then
		-- Drawn at 5x3x3; every size and position grows with the desk.
		local deskScale = Constants.DESK_SIZE / Vector3.new(5, 3, 3)
		local function scaled(v: Vector3): Vector3
			return v * deskScale
		end
		piece(model, "OakTop", scaled(Vector3.new(5, 0.23, 3)), scaled(Vector3.new(0, 2.885, 0)), oak, nil)
		piece(model, "ModestyPanel", scaled(Vector3.new(4.5, 1.4, 0.1)), scaled(Vector3.new(0, 1.9, 1.23)), slate, nil)
		for _, z in { -1.1, 1.1 } do
			piece(
				model,
				"SteelLeg",
				scaled(Vector3.new(0.13, 2.77, 0.13)),
				scaled(Vector3.new(-2.2, 1.385, z)),
				steel,
				nil
			)
		end
		-- Hollow pedestal: side/back/bottom panels, two lower closed fronts; upper opening stays real.
		for _, x in { 1, 2.25 } do
			piece(
				model,
				"PedestalSide",
				scaled(Vector3.new(0.1, 2.77, 2.7)),
				scaled(Vector3.new(x, 1.385, 0)),
				oak,
				nil
			)
		end
		piece(
			model,
			"PedestalBack",
			scaled(Vector3.new(1.35, 2.77, 0.1)),
			scaled(Vector3.new(1.625, 1.385, 1.3)),
			oak,
			nil
		)
		piece(model, "PedestalBase", scaled(Vector3.new(1.35, 0.1, 2.7)), scaled(Vector3.new(1.625, 0.05, 0)), oak, nil)
		for _, y in { 0.55, 1.4 } do
			piece(
				model,
				"LowerDrawer",
				scaled(Vector3.new(1.15, 0.75, 0.08)),
				scaled(Vector3.new(1.625, y, -1.36)),
				oak,
				nil
			)
			piece(
				model,
				"LowerPull",
				scaled(Vector3.new(0.48, 0.07, 0.08)),
				scaled(Vector3.new(1.625, y + 0.1, -1.44)),
				steel,
				nil
			)
		end
		piece(
			model,
			"UpperDrawerFront",
			scaled(Vector3.new(1.15, 0.7, 0.08)),
			scaled(Vector3.new(1.625, 2.28, -1.36)),
			oak,
			"drawer"
		)
		piece(
			model,
			"UpperPull",
			scaled(Vector3.new(0.48, 0.07, 0.08)),
			scaled(Vector3.new(1.625, 2.38, -1.44)),
			steel,
			"drawer"
		)
		piece(
			model,
			"DrawerBottom",
			scaled(Vector3.new(1.1, 0.06, 2.2)),
			scaled(Vector3.new(1.625, 1.97, -0.25)),
			oak,
			"drawer"
		)
		for _, x in { 1.09, 2.16 } do
			piece(
				model,
				"DrawerSide",
				scaled(Vector3.new(0.06, 0.6, 2.2)),
				scaled(Vector3.new(x, 2.25, -0.25)),
				oak,
				"drawer"
			)
		end
		piece(
			model,
			"DrawerBack",
			scaled(Vector3.new(1.1, 0.6, 0.06)),
			scaled(Vector3.new(1.625, 2.25, 0.82)),
			oak,
			"drawer"
		)
	else
		local size = Constants.LOCKER_SIZE
		for _, x in { -size.X / 2 + 0.06, size.X / 2 - 0.06 } do
			piece(model, "LockerSide", Vector3.new(0.12, size.Y, size.Z), Vector3.new(x, size.Y / 2, 0), slate, nil)
		end
		for _, y in { 0.06, size.Y - 0.06 } do
			piece(model, "LockerCap", Vector3.new(size.X, 0.12, size.Z), Vector3.new(0, y, 0), slate, nil)
		end
		piece(
			model,
			"LockerBack",
			Vector3.new(size.X, size.Y, 0.12),
			Vector3.new(0, size.Y / 2, size.Z / 2 - 0.06),
			Color3.fromRGB(70, 82, 94),
			nil
		)
		piece(model, "LockerShelf", Vector3.new(size.X - 0.24, 0.1, size.Z - 0.15), Vector3.new(0, 1.8, 0), slate, nil)
		local door = piece(
			model,
			"SearchDoor",
			Vector3.new(size.X - 0.24, size.Y - 0.24, 0.1),
			Vector3.new(0, size.Y / 2, -size.Z / 2 + 0.05),
			slate,
			"door"
		)
		-- Door decorations stay in its local frame and rotate as one assembly.
		for _, y in { size.Y * 0.76, size.Y * 0.79, size.Y * 0.82 } do
			piece(
				model,
				"DoorVent",
				Vector3.new(size.X * 0.5, 0.045, 0.02),
				Vector3.new(0, y, door.Position.Z - 0.065),
				steel,
				"door"
			)
		end
		piece(
			model,
			"NamePlate",
			Vector3.new(0.75, 0.22, 0.02),
			Vector3.new(0, size.Y * 0.64, door.Position.Z - 0.065),
			Color3.fromRGB(238, 232, 218),
			"door"
		)
		local handle = piece(
			model,
			"DoorHandle",
			Vector3.new(0.08, 0.42, 0.09),
			door.Position + Vector3.new(0.7, 0, -0.1),
			steel,
			"door"
		)
		handle:SetAttribute("SearchDoorLeaf", false)
	end
	local cf, size = model:GetBoundingBox()
	local offset = Vector3.new(-cf.X, -cf.Y + size.Y / 2, -cf.Z)
	for _, o in model:GetDescendants() do
		if o:IsA("BasePart") then
			o.Position += offset
		end
	end
	model.WorldPivot = CFrame.identity
	model:SetAttribute("BaseSize", size)
	model:SetAttribute("FitMode", if kind == "desk" then "Stretch" else "Uniform")
	model:SetAttribute("RuntimeApproved", true)
	model:SetAttribute("SearchableRig", true)
	return model
end
function System.new(duration: number?): Controller
	local records: { [BasePart]: Record } = {}
	local seconds = duration or 0.4
	local function restore(root: BasePart)
		local record = records[root]
		if not record then
			return
		end
		records[root] = nil
		for p, saved in record.parts do
			if saved.tween then
				saved.tween:Cancel()
			end
			if p.Parent then
				p.CFrame = saved.frame
			end
			if saved.weld and saved.weld.Parent then
				saved.weld.Enabled = true
			end
		end
		for p, alpha in record.hidden do
			if p.Parent then
				p.Transparency = alpha
			end
		end
		if record.fallback then
			record.fallback:Destroy()
		end
	end
	return {
		apply = function(root, kind)
			if records[root] or not root.Anchored then
				return
			end
			local art = root:FindFirstChild("ArtVisual")
			local record: Record = { parts = {}, hidden = {} }
			local rig: Instance = art or root
			local function hasComponents(): boolean
				for _, o in rig:GetDescendants() do
					if
						o:IsA("BasePart")
						and (
							o:GetAttribute("SearchComponent") ~= nil
							or o.Name == "SearchDrawer"
							or o.Name == "SearchDoor"
						)
					then
						return true
					end
				end
				return false
			end
			if not hasComponents() then
				-- Replace the monolithic body with a complete hollow rig; never paste a solid drawer over it.
				record.hidden[root] = root.Transparency
				root.Transparency = 1
				if art then
					for _, o in art:GetDescendants() do
						if o:IsA("BasePart") then
							record.hidden[o] = o.Transparency
							o.Transparency = 1
						end
					end
				end
				local fallback = System.buildTemplate(kind)
				fallback.Name = "SearchedDressing"
				local base = fallback:GetAttribute("BaseSize")
				if typeof(base) == "Vector3" then
					local scale = root.Size / base
					for _, o in fallback:GetDescendants() do
						if o:IsA("BasePart") then
							o.Size *= scale
							o.CFrame = root.CFrame * CFrame.new(0, -root.Size.Y / 2, 0) * CFrame.new(o.Position * scale)
						end
					end
				end
				fallback.Parent = root
				record.fallback = fallback
				rig = fallback
			end
			local leaf: BasePart? = nil
			for _, o in rig:GetDescendants() do
				if o:IsA("BasePart") and o.Name == "SearchDoor" then
					leaf = o
				end
			end
			local doorTransform = CFrame.identity
			if leaf then
				-- Choose the hinge furthest from the adjacent room wall; swing outward and fold flat.
				local side = if root:GetAttribute("OfficeDoorHingeSide") == 1 then 1 else -1
				local hinge = leaf.CFrame * CFrame.new(side * leaf.Size.X / 2, 0, 0)
				doorTransform = hinge * CFrame.Angles(0, -side * math.pi, 0) * hinge:Inverse()
			end
			for _, o in rig:GetDescendants() do
				if o:IsA("BasePart") then
					local component = o:GetAttribute("SearchComponent")
					if
						component == "drawer"
						or component == "door"
						or o.Name == "SearchDrawer"
						or o.Name == "SearchDoor"
					then
						local weld = o:FindFirstChild("ArtRootWeld")
						local saved: Saved =
							{ frame = o.CFrame, weld = if weld and weld:IsA("WeldConstraint") then weld else nil }
						if saved.weld then
							saved.weld.Enabled = false
						end
						local goal = if kind == "desk"
							then o.CFrame + root.CFrame:VectorToWorldSpace(Vector3.new(0, 0, -root.Size.Z * 0.45))
							else doorTransform * o.CFrame
						record.parts[o] = saved
						if seconds <= 0 then
							o.CFrame = goal
						else
							local tween = TweenService:Create(
								o,
								TweenInfo.new(seconds, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
								{ CFrame = goal }
							)
							saved.tween = tween
							tween:Play()
						end
					end
				end
			end
			records[root] = record
		end,
		clear = function()
			for root in records do
				restore(root)
			end
		end,
	}
end
return System
