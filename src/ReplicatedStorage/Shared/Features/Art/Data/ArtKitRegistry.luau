--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArtTypes = require(ReplicatedStorage.Shared.Features.Art.Data.ArtTypes)

local ArtKitRegistry = {}
ArtKitRegistry.DEFAULT_KIT = "client-office-slate"
local kits: { [string]: ArtTypes.Kit } = {
	["client-office-slate"] = { id = "client-office-slate", name = "Client office slate" },
	["odd-hours-b1"] = { id = "odd-hours-b1", name = "Odd Hours B1 office" },
}
local keys: { [ArtTypes.Family]: { string } } = {
	building = {
		"wallSolid",
		"wallDoorway",
		"wallCorner",
		"doorLeaf",
		"ceilingTile",
		"floorTile",
		"skirting",
		"window",
		"fluorescent",
		"exitSign",
		"pillar",
		"garageDoor",
		"doorLeafGlass",
		"floorTile_server",
		"floorTile_breakout",
		"floorTile_hallway",
		"stairwellSign",
	},
	furniture = {
		"desk",
		"officeChair",
		"locker",
		"shelf",
		"corkboard",
		"filingDrawer",
		"wasteBin",
		"wallClock",
		"breakTable",
		"kitchenCounter",
		"elevatorFront",
		"pipeSet",
		"cableSet",
		"supplyCabinet",
		"serverRack",
		"conferenceTable",
		"receptionDesk",
		"partition",
		"sofa",
		"vending",
		"waterCooler",
		"copier",
		"floorLamp",
		"planter",
		"artFrame",
		"wallScreen",
		"sconce",
		"deskPlant",
	},
	cargo = {
		"rubbishBag",
		"recyclingBox",
		"bottleBag",
		"officePlant",
		"plaque",
		"monitor",
		"waterJug",
		"coffeeMachine",
		"fishTank",
		"goldenStapler",
		"filingCabinet",
		"coffeeMug",
		"wristwatch",
		"deskClock",
		"snowGlobe",
		"keyring",
	},
	props = {
		"keyboard",
		"mug",
		"paperTray",
		"folder",
		"paperStack",
		"mouse",
		"bookStack",
		"stationeryCup",
	},
	-- Equipment is an extension family: company equipment has its own visual systems.
	equipment = {},
}
for _, familyKeys in keys do
	table.freeze(familyKeys)
end
for _, kit in kits do
	table.freeze(kit)
end
ArtKitRegistry.kits = table.freeze(kits)
ArtKitRegistry.keys = table.freeze(keys)
function ArtKitRegistry.contains(family: ArtTypes.Family, key: string): boolean
	return table.find(ArtKitRegistry.keys[family], key) ~= nil
end
return table.freeze(ArtKitRegistry)
