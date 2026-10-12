--!strict
-- Original filled company prop shapes, matching the approved SVG study's colour/silhouette.
export type Kind = "jobs" | "guide" | "gear" | "settings" | "vacuum"
export type Shape = { x: number, y: number, w: number, h: number, rotation: number, round: number, color: string }
local function shape(
	x: number,
	y: number,
	w: number,
	h: number,
	color: string,
	rotation: number?,
	round: number?
): Shape
	return { x = x, y = y, w = w, h = h, color = color, rotation = rotation or 0, round = round or 0 }
end
local SHAPES: { [Kind]: { Shape } } = {
	jobs = {
		shape(15, 7, 34, 48, "ink", -5),
		shape(13, 5, 32, 48, "cork", -5),
		shape(17, 11, 24, 36, "cream", -5),
		shape(23, 2, 15, 8, "ink", -5),
		shape(22, 26, 11, 5, "companyTeal", 35),
		shape(28, 20, 18, 5, "companyTeal", -55),
		shape(23, 37, 14, 2, "manilaDeep", -5),
		shape(24, 43, 11, 2, "manilaDeep", -5),
		shape(37, 44, 14, 7, "manila", -5),
	},
	guide = {
		shape(7, 12, 49, 42, "ink", 2),
		shape(6, 10, 48, 40, "companyTeal", 2),
		shape(10, 13, 19, 32, "cream", -5),
		shape(33, 13, 17, 30, "manila", 5),
		shape(29, 9, 4, 41, "manilaDeep"),
		shape(17, 13, 5, 14, "stamp", -5),
		shape(14, 27, 11, 2, "companyTeal", -5),
		shape(14, 34, 11, 2, "companyTeal", -5),
		shape(36, 26, 11, 2, "companyTeal", 5),
		shape(36, 33, 11, 2, "companyTeal", 5),
	},
	gear = {
		shape(16, 8, 27, 16, "ink", -4, 0.3),
		shape(23, 12, 13, 8, "cream", -4),
		shape(7, 20, 49, 34, "ink", -4, 0.15),
		shape(5, 18, 49, 33, "companyTeal", -4, 0.15),
		shape(6, 18, 47, 13, "inkGreen", -4),
		shape(8, 30, 46, 3, "ink", -4),
		shape(14, 27, 7, 13, "manila", -4),
		shape(41, 25, 7, 13, "manila", -4),
		shape(26, 41, 13, 7, "cream", -4),
	},
	settings = {
		shape(7, 22, 48, 22, "manila", 0, 0.15),
		shape(7, 22, 48, 22, "manila", 45, 0.15),
		shape(7, 22, 48, 22, "manila", 90, 0.15),
		shape(7, 22, 48, 22, "manila", 135, 0.15),
		shape(14, 16, 34, 34, "ink", 0, 1),
		shape(17, 19, 28, 28, "companyTeal", 0, 1),
		shape(23, 25, 16, 16, "cream", 0, 1),
	},
	vacuum = {
		shape(36, 4, 8, 13, "ink", -15, 0.3),
		shape(31, 14, 8, 28, "manilaDeep", -15),
		shape(17, 19, 21, 12, "companyTeal", -15, 0.3),
		shape(16, 28, 23, 20, "cream", -15, 0.3),
		shape(20, 29, 3, 17, "manilaDeep", -15),
		shape(29, 27, 3, 17, "manilaDeep", -15),
		shape(13, 46, 35, 10, "companyTeal", -4, 0.3),
		shape(26, 18, 7, 4, "manila", -15),
	},
}
local VM = {}
function VM.shapes(kind: Kind): { Shape }
	return SHAPES[kind]
end
return VM
