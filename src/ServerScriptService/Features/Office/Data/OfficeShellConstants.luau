--!strict
--[=[
	OfficeShellConstants: the shell's looks, split out of OfficeConstants (which re-exports both tables). MATERIALS: each
	ShellMaterial's Material, MaterialVariant (used only where the place has one), colour and transparency. THEMES: each
	art kit's shell dress (OfficeTypes.ShellTheme; OfficeShellVisualSystem.themed / floorMaterial); a kit with no entry
	keeps the shared materials. Static data (spec-exempt; the looks are checked through OfficeShellVisualSystem.spec).

	@class OfficeShellConstants
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)

local SHELL_MATERIALS: { [OfficeTypes.ShellMaterial]: { material: Enum.Material, variant: string?, color: Color3, transparency: number } } =
	{
		plaster = {
			material = Enum.Material.Plaster,
			variant = "OH_Plaster",
			color = Color3.new(1, 1, 1),
			transparency = 0,
		},
		oak = { material = Enum.Material.Wood, variant = "OH_Oak", color = Color3.new(1, 1, 1), transparency = 0 },
		rail = { material = Enum.Material.Wood, variant = nil, color = Color3.fromRGB(110, 80, 56), transparency = 0 },
		skirt = {
			material = Enum.Material.SmoothPlastic,
			variant = nil,
			color = Color3.fromRGB(150, 112, 80),
			transparency = 0,
		},
		frame = {
			material = Enum.Material.SmoothPlastic,
			variant = nil,
			color = Color3.fromRGB(46, 48, 56),
			transparency = 0,
		},
		grid = {
			material = Enum.Material.SmoothPlastic,
			variant = nil,
			color = Color3.fromRGB(170, 165, 156),
			transparency = 0,
		},
		glass = {
			material = Enum.Material.Glass,
			variant = nil,
			color = Color3.fromRGB(170, 205, 215),
			transparency = 0.6,
		},
		ceiling = {
			material = Enum.Material.Concrete,
			variant = "OH_Ceiling",
			color = Color3.new(1, 1, 1),
			transparency = 0,
		},
		carpet = {
			material = Enum.Material.Fabric,
			variant = "OH_Carpet",
			color = Color3.new(1, 1, 1),
			transparency = 0,
		},
		hallcarpet = {
			material = Enum.Material.Fabric,
			variant = "OH_Carpet",
			color = Color3.fromRGB(191, 191, 198),
			transparency = 0,
		},
		lino = {
			material = Enum.Material.Plastic,
			variant = "OH_Lino",
			color = Color3.new(1, 1, 1),
			transparency = 0,
		},
		vinyl = {
			material = Enum.Material.Plastic,
			variant = "OH_Vinyl",
			color = Color3.new(1, 1, 1),
			transparency = 0,
		},
		-- The School kit's (SHELL_THEMES), owner-approved 2026-11-12: halls of cream painted block over a teal block
		-- band with a cream stripe on slate VCT; rooms of cream paint over a sage band with a wood rail; blue-grey carpet
		-- tiles in classrooms, maple in the gym, the green checker in the cafeteria and white tile in the bathrooms.
		schoolHallFloor = {
			material = Enum.Material.Plastic,
			variant = "School_HallVct",
			color = Color3.new(1, 1, 1),
			transparency = 0,
		},
		schoolHallBlock = {
			material = Enum.Material.Concrete,
			variant = "School_HallBlock",
			color = Color3.new(1, 1, 1),
			transparency = 0,
		},
		schoolHallBand = {
			material = Enum.Material.Concrete,
			variant = "School_HallBand",
			color = Color3.new(1, 1, 1),
			transparency = 0,
		},
		schoolHallStripe = {
			material = Enum.Material.SmoothPlastic,
			variant = nil,
			color = Color3.fromRGB(216, 208, 188),
			transparency = 0,
		},
		schoolRoomPaint = {
			material = Enum.Material.Plaster,
			variant = "School_RoomPaint",
			color = Color3.new(1, 1, 1),
			transparency = 0,
		},
		schoolRoomBand = {
			material = Enum.Material.Plaster,
			variant = "School_RoomBand",
			color = Color3.new(1, 1, 1),
			transparency = 0,
		},
		schoolRoomRail = {
			material = Enum.Material.Wood,
			variant = "OH_Oak",
			color = Color3.new(1, 1, 1),
			transparency = 0,
		},
		schoolCarpet = {
			material = Enum.Material.Fabric,
			variant = "School_Carpet",
			color = Color3.new(1, 1, 1),
			transparency = 0,
		},
		schoolMaple = {
			material = Enum.Material.Wood,
			variant = "School_Maple",
			color = Color3.new(1, 1, 1),
			transparency = 0,
		},
		schoolChecker = {
			material = Enum.Material.Plastic,
			variant = "School_Checker",
			color = Color3.new(1, 1, 1),
			transparency = 0,
		},
		schoolTile = {
			material = Enum.Material.Plastic,
			variant = "School_Tile",
			color = Color3.new(1, 1, 1),
			transparency = 0,
		},
	}

-- Each kit's shell look (OfficeShellVisualSystem.themed / floorMaterial; OfficeTypes.ShellTheme). A kit with no entry
-- (the Office's) keeps the shared materials. The School: a wall face looking into a hallway takes the hall dress, any
-- other face the room dress; the wainscot (oak) is the lower band, the rail the stripe or rail, the slab the wall.
local SHELL_THEMES: { [string]: OfficeTypes.ShellTheme } = {
	["school-maple-hill"] = {
		hallway = { plaster = "schoolHallBlock", oak = "schoolHallBand", rail = "schoolHallStripe" },
		rooms = { plaster = "schoolRoomPaint", oak = "schoolRoomBand", rail = "schoolRoomRail" },
		floors = {
			hallway = "schoolHallFloor",
			classroom = "schoolCarpet",
			gym = "schoolMaple",
			cafeteria = "schoolChecker",
			bathroom = "schoolTile",
		},
	},
}

return table.freeze({
	MATERIALS = table.freeze(SHELL_MATERIALS),
	THEMES = table.freeze(SHELL_THEMES),
})
