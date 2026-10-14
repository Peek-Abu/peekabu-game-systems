--!strict
-- Original source geometry: +Y up, -Z front, grip at origin.
export type VisualPart = {
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	frame: CFrame,
	color: Color3,
	metal: boolean,
}
local function entry(
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	frame: CFrame,
	color: Color3,
	metal: boolean?
): VisualPart
	return { name = name, shape = shape, size = size, frame = frame, color = color, metal = metal == true }
end
local parts: { VisualPart } = {
	entry(
		"Motor housing",
		Enum.PartType.Block,
		Vector3.new(1.05, 0.98, 1.12),
		CFrame.new(0, -0.9400001, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		Color3.new(0.260067, 0.516881, 0.484529)
	),
	entry(
		"Lower impact bumper",
		Enum.PartType.Block,
		Vector3.new(1.13, 1.03, 0.14),
		CFrame.new(0, -1.49, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		Color3.new(0.179236, 0.205984, 0.212098)
	),
	entry(
		"Detachable dust canister",
		Enum.PartType.Block,
		Vector3.new(0.89, 0.66, 0.97),
		CFrame.new(0, -1.07, 0.73, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		Color3.new(0.896244, 0.865042, 0.773573)
	),
	entry(
		"Canister seal",
		Enum.PartType.Block,
		Vector3.new(0.94, 0.1, 1),
		CFrame.new(0, -1.07, 0.43, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		Color3.new(0.179236, 0.205984, 0.212098)
	),
	entry(
		"Canister lid",
		Enum.PartType.Block,
		Vector3.new(0.94, 0.72, 0.12),
		CFrame.new(0, -0.5600001, 0.75, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		Color3.new(0.260067, 0.516881, 0.484529)
	),
	entry(
		"Rear release latch",
		Enum.PartType.Block,
		Vector3.new(0.28, 0.06, 0.23),
		CFrame.new(0, -0.78, 1.1, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		Color3.new(0.963976, 0.754781, 0.282779)
	),
	entry(
		"Handle support",
		Enum.PartType.Cylinder,
		Vector3.new(0.39, 0.146, 0.146),
		CFrame.new(0, -0.1949999, -0.35, 0, -1.509958e-07, -1, 1, 0, -0, 0, -1, 1.509958e-07),
		Color3.new(0.687217, 0.735357, 0.735357)
	),
	entry(
		"Handle support.001",
		Enum.PartType.Cylinder,
		Vector3.new(0.39, 0.146, 0.146),
		CFrame.new(0, -0.1949999, 0.35, 0, -1.509958e-07, -1, 1, 0, -0, 0, -1, 1.509958e-07),
		Color3.new(0.687217, 0.735357, 0.735357)
	),
	entry(
		"Carry grip",
		Enum.PartType.Cylinder,
		Vector3.new(0.72, 0.23, 0.23),
		CFrame.new(0, 0, 0, 1.139987e-14, -1.509958e-07, -1, -7.54979e-08, 1, -1.509958e-07, 1, 7.54979e-08, -0),
		Color3.new(0.179236, 0.205984, 0.212098)
	),
	entry(
		"Grip rib",
		Enum.PartType.Cylinder,
		Vector3.new(0.02200001, 0.248, 0.248),
		CFrame.new(
			0,
			0,
			-0.269,
			-8.742278e-08,
			-8.742279e-08,
			-1,
			7.54979e-08,
			1,
			-8.74228e-08,
			1,
			-7.549791e-08,
			-8.742278e-08
		),
		Color3.new(0.179236, 0.205984, 0.212098)
	),
	entry(
		"Grip rib.001",
		Enum.PartType.Cylinder,
		Vector3.new(0.022, 0.248, 0.248),
		CFrame.new(
			0,
			0,
			-0.169,
			-8.742278e-08,
			-8.742279e-08,
			-1,
			7.54979e-08,
			1,
			-8.74228e-08,
			1,
			-7.549791e-08,
			-8.742278e-08
		),
		Color3.new(0.179236, 0.205984, 0.212098)
	),
	entry(
		"Grip rib.002",
		Enum.PartType.Cylinder,
		Vector3.new(0.022, 0.248, 0.248),
		CFrame.new(
			0,
			0,
			-0.069,
			-8.742278e-08,
			-8.742279e-08,
			-1,
			7.54979e-08,
			1,
			-8.74228e-08,
			1,
			-7.549791e-08,
			-8.742278e-08
		),
		Color3.new(0.179236, 0.205984, 0.212098)
	),
	entry(
		"Grip rib.003",
		Enum.PartType.Cylinder,
		Vector3.new(0.022, 0.248, 0.248),
		CFrame.new(
			0,
			0,
			0.031,
			-8.742278e-08,
			-8.742279e-08,
			-1,
			7.54979e-08,
			1,
			-8.74228e-08,
			1,
			-7.549791e-08,
			-8.742278e-08
		),
		Color3.new(0.179236, 0.205984, 0.212098)
	),
	entry(
		"Grip rib.004",
		Enum.PartType.Cylinder,
		Vector3.new(0.02200001, 0.248, 0.248),
		CFrame.new(
			0,
			0,
			0.131,
			-8.742278e-08,
			-8.742279e-08,
			-1,
			7.54979e-08,
			1,
			-8.74228e-08,
			1,
			-7.549791e-08,
			-8.742278e-08
		),
		Color3.new(0.179236, 0.205984, 0.212098)
	),
	entry(
		"Grip rib.005",
		Enum.PartType.Cylinder,
		Vector3.new(0.022, 0.248, 0.248),
		CFrame.new(
			0,
			0,
			0.231,
			-8.742278e-08,
			-8.742279e-08,
			-1,
			7.54979e-08,
			1,
			-8.74228e-08,
			1,
			-7.549791e-08,
			-8.742278e-08
		),
		Color3.new(0.179236, 0.205984, 0.212098)
	),
	entry(
		"Trigger",
		Enum.PartType.Block,
		Vector3.new(0.17, 0.14, 0.12),
		CFrame.new(0, -0.16, -0.42, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		Color3.new(0.963976, 0.754781, 0.282779)
	),
	entry(
		"Tube collar",
		Enum.PartType.Cylinder,
		Vector3.new(0.2137756, 0.33, 0.33),
		CFrame.new(0, -1.26, -0.585, 0, 0, 1, -0.1871122, 0.9823385, -0, -0.9823385, -0.1871122, -0),
		Color3.new(0.179236, 0.205984, 0.212098)
	),
	entry(
		"Suction wand",
		Enum.PartType.Cylinder,
		Vector3.new(1.505722, 0.206, 0.206),
		CFrame.new(0, -1.49, -1.33, 0, 0, 1, -0.2922185, 0.9563516, -0, -0.9563516, -0.2922185, -0),
		Color3.new(0.687217, 0.735357, 0.735357)
	),
	entry(
		"Nozzle neck",
		Enum.PartType.Cylinder,
		Vector3.new(0.245153, 0.29, 0.29),
		CFrame.new(0, -1.715, -2.11, 0, 0, 1, -0.2039544, 0.9789804, -0, -0.9789804, -0.2039544, -0),
		Color3.new(0.260067, 0.516881, 0.484529)
	),
	entry(
		"Wide floor head",
		Enum.PartType.Block,
		Vector3.new(1.4, 0.58, 0.29),
		CFrame.new(0, -1.75, -2.35, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		Color3.new(0.260067, 0.516881, 0.484529)
	),
	entry(
		"Floor contact gasket",
		Enum.PartType.Block,
		Vector3.new(1.43, 0.58, 0.07),
		CFrame.new(0, -1.885, -2.35, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		Color3.new(0.179236, 0.205984, 0.212098)
	),
	entry(
		"Nozzle safety insert",
		Enum.PartType.Block,
		Vector3.new(0.53, 0.08, 0.08),
		CFrame.new(0, -1.69, -2.52, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		Color3.new(0.963976, 0.754781, 0.282779)
	),
	entry(
		"Head bumper",
		Enum.PartType.Block,
		Vector3.new(0.12, 0.6, 0.19),
		CFrame.new(0.55, -1.77, -2.35, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		Color3.new(0.179236, 0.205984, 0.212098)
	),
	entry(
		"Head bumper.001",
		Enum.PartType.Block,
		Vector3.new(0.12, 0.6, 0.19),
		CFrame.new(-0.55, -1.77, -2.35, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		Color3.new(0.179236, 0.205984, 0.212098)
	),
	entry(
		"Motor ventilation slot",
		Enum.PartType.Block,
		Vector3.new(0.015, 0.055, 0.28),
		CFrame.new(-0.533, -0.64, -0.28, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		Color3.new(0.179236, 0.205984, 0.212098)
	),
	entry(
		"Motor ventilation slot.001",
		Enum.PartType.Block,
		Vector3.new(0.015, 0.055, 0.28),
		CFrame.new(-0.533, -0.64, -0.16, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		Color3.new(0.179236, 0.205984, 0.212098)
	),
	entry(
		"Motor ventilation slot.002",
		Enum.PartType.Block,
		Vector3.new(0.015, 0.055, 0.28),
		CFrame.new(-0.533, -0.64, -0.04, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		Color3.new(0.179236, 0.205984, 0.212098)
	),
	entry(
		"Motor ventilation slot.003",
		Enum.PartType.Block,
		Vector3.new(0.015, 0.055, 0.28),
		CFrame.new(-0.533, -0.64, 0.08, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		Color3.new(0.179236, 0.205984, 0.212098)
	),
	entry(
		"Motor ventilation slot.004",
		Enum.PartType.Block,
		Vector3.new(0.015, 0.055, 0.28),
		CFrame.new(-0.533, -0.64, 0.2, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		Color3.new(0.179236, 0.205984, 0.212098)
	),
	entry(
		"Service label",
		Enum.PartType.Block,
		Vector3.new(0.72, 0.018, 0.29),
		CFrame.new(0, -0.87, -0.503, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		Color3.new(0.935741, 0.921191, 0.870345)
	),
	entry(
		"Service screw",
		Enum.PartType.Cylinder,
		Vector3.new(0.02499998, 0.052, 0.052),
		CFrame.new(0.39, -1.34, -0.5125, 0, 0, 1, -1.629207e-07, 1, -0, -1, -1.629207e-07, -0),
		Color3.new(0.687217, 0.735357, 0.735357)
	),
	entry(
		"Service screw.001",
		Enum.PartType.Cylinder,
		Vector3.new(0.02499998, 0.052, 0.052),
		CFrame.new(0.39, -0.49, -0.5125, 0, 0, 1, -1.629207e-07, 1, -0, -1, -1.629207e-07, -0),
		Color3.new(0.687217, 0.735357, 0.735357)
	),
	entry(
		"Service screw.002",
		Enum.PartType.Cylinder,
		Vector3.new(0.02499998, 0.052, 0.052),
		CFrame.new(-0.39, -1.34, -0.5125, 0, 0, 1, -1.629207e-07, 1, -0, -1, -1.629207e-07, -0),
		Color3.new(0.687217, 0.735357, 0.735357)
	),
	entry(
		"Service screw.003",
		Enum.PartType.Cylinder,
		Vector3.new(0.02499998, 0.052, 0.052),
		CFrame.new(-0.39, -0.49, -0.5125, 0, 0, 1, -1.629207e-07, 1, -0, -1, -1.629207e-07, -0),
		Color3.new(0.687217, 0.735357, 0.735357)
	),
	entry(
		"Canister gauge recess",
		Enum.PartType.Block,
		Vector3.new(0.025, 0.32, 0.42),
		CFrame.new(-0.45, -1.02, 0.73, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		Color3.new(0.179236, 0.205984, 0.212098)
	),
	entry(
		"Capacity marker",
		Enum.PartType.Block,
		Vector3.new(0.02, 0.21, 0.065),
		CFrame.new(-0.467, -1.16, 0.73, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		Color3.new(0.963976, 0.754781, 0.282779)
	),
	entry(
		"Capacity marker.001",
		Enum.PartType.Block,
		Vector3.new(0.02, 0.21, 0.065),
		CFrame.new(-0.467, -1.02, 0.73, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		Color3.new(0.963976, 0.754781, 0.282779)
	),
	entry(
		"Capacity marker.002",
		Enum.PartType.Block,
		Vector3.new(0.02, 0.21, 0.065),
		CFrame.new(-0.467, -0.88, 0.73, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		Color3.new(0.963976, 0.754781, 0.282779)
	),
}
return table.freeze({
	parts = parts,
	grip = CFrame.Angles(-math.pi / 2, 0, 0),
	-- Fitting a short holder (VacuumVisualSystem.holdScale): studs kept between the floor head and the floor under
	-- a straight hanging arm (the walk swing lifts it further), and the smallest the vacuum is ever built.
	holdClearance = 0.08,
	minHoldScale = 0.35,
})
