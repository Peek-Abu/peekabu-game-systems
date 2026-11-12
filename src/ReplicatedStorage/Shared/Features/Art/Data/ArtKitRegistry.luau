--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArtTypes = require(ReplicatedStorage.Shared.Features.Art.Data.ArtTypes)

local ArtKitRegistry = {}
ArtKitRegistry.DEFAULT_KIT = "client-office-slate"
local kits: { [string]: ArtTypes.Kit } = {
	["client-office-slate"] = { id = "client-office-slate", name = "Client office slate" },
	["odd-hours-b1"] = { id = "odd-hours-b1", name = "Odd Hours B1 office" },
	-- The School (Maple Hill): its own furniture, and the Office kit's for everything it shares (doors, lights, sofas...).
	["school-maple-hill"] = { id = "school-maple-hill", name = "Maple Hill school", fallback = "odd-hours-b1" },
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
		"stairwellSign",
		-- The School's (school-maple-hill).
		"studentDesk",
		"chalkboard",
		"cubbies",
		"projectTable",
		"easel",
		"artSink",
		"piano",
		"bench",
		"scorersTable",
		"equipmentCloset",
		"scoreboard",
		"basketballHoop",
		"bleachers",
		"lunchTable",
		"lunchBench",
		"servingCounter",
		"libraryDesk",
		"readingTable",
		"studyTable",
		"bookReturn",
		"trophyCase",
		"cot",
		"medicineCabinet",
		"stall",
		"sinkCounter",
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
		-- The vacuum's dust piles (VacuumPileArtSystem), in the default kit so every map shows them.
		"pilePaper",
		"pileCables",
		"pileJunk",
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
--[=[
	The kits a key is looked up in, in order: `kitId`, then each fallback it names (a kit is visited once), then
	DEFAULT_KIT (once). An unregistered kit (a place-only kit) goes straight to the default.
]=]
function ArtKitRegistry.chain(kitId: string): { string }
	local order: { string } = {}
	local current: string? = kitId
	while current ~= nil and not table.find(order, current) do
		table.insert(order, current)
		local kit = kits[current]
		current = if kit ~= nil then kit.fallback else nil
	end
	if not table.find(order, ArtKitRegistry.DEFAULT_KIT) then
		table.insert(order, ArtKitRegistry.DEFAULT_KIT)
	end
	return order
end
return table.freeze(ArtKitRegistry)
