--!strict
-- Original desktop dressing. Decoration cannot intercept search rays or obstruct walking.
local OfficeDeskVisualSystem = {}
function OfficeDeskVisualSystem.build(desk: BasePart)
	local top = desk.Size.Y / 2
	local function part(name: string, size: Vector3, offset: Vector3, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = desk.CFrame * CFrame.new(offset)
		p.Color = color
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = desk
		return p
	end
	local graphite = Color3.fromRGB(28, 35, 37)
	local ivory = Color3.fromRGB(220, 210, 180)
	-- The layout below was drawn on a 5x3 top; each cluster's anchor moves with the real top, its parts keep their size.
	local scaleX, scaleZ = desk.Size.X / 5, desk.Size.Z / 3
	local monitorX, monitorZ = -0.5 * scaleX, 0.65 * scaleZ
	local keyboardX, keyboardZ = -0.5 * scaleX, -0.55 * scaleZ
	part("MonitorBase", Vector3.new(1.2, 0.1, 0.55), Vector3.new(monitorX, top + 0.05, monitorZ), graphite)
	part("MonitorNeck", Vector3.new(0.15, 0.5, 0.15), Vector3.new(monitorX, top + 0.35, monitorZ), graphite)
	part("Monitor", Vector3.new(2, 1.25, 0.25), Vector3.new(monitorX, top + 1.1, monitorZ), graphite)
	part(
		"MonitorScreen",
		Vector3.new(1.8, 1.05, 0.025),
		Vector3.new(monitorX, top + 1.1, monitorZ - 0.14),
		Color3.fromRGB(28, 88, 76)
	)
	part("Keyboard", Vector3.new(2.4, 0.12, 1.05), Vector3.new(keyboardX, top + 0.08, keyboardZ), graphite)
	for row = 1, 5 do
		local count = if row == 5 then 6 else 12
		for key = 1, count do
			local x = if row == 5
				then (if key <= 3 then -1.58 + (key - 1) * 0.18 else -0.03 + (key - 4) * 0.18)
				else -1.58 + (key - 1) * 0.19
			local p = part(
				"Keycap",
				Vector3.new(0.16, 0.045, 0.15),
				Vector3.new(keyboardX + x + 0.5, top + 0.16, keyboardZ + 0.33 - (row - 1) * 0.19),
				ivory
			)
			p:SetAttribute("KeyRow", row)
		end
	end
	part("SpaceBar", Vector3.new(0.85, 0.045, 0.15), Vector3.new(keyboardX - 0.22, top + 0.16, keyboardZ - 0.43), ivory)
	part("Mouse", Vector3.new(0.35, 0.15, 0.5), Vector3.new(1.05 * scaleX, top + 0.1, -0.5 * scaleZ), ivory)
end
return OfficeDeskVisualSystem
