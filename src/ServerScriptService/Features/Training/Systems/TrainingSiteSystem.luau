--!strict
--[=[
	TrainingSiteSystem: the Studio-built Training map as Office's site for a training run (OfficeTypes.Site). `find`
	returns the map (the one Model tagged TrainingConstants.MAP_TAG) and its plan, read from its parts' attributes and
	checked by TrainingMapRules, or the problems found. `new` makes the site: spawns, Harlow's route and rest point,
	the safe and bay boxes from the plan; `spawn` places the plan's Gloom piles (Vacuum) and cargo (Cargo) in the shift
	folder and hands the spawned parts to `spawned`, so the run can follow them. The marker parts (spawn, stops, zones,
	route, rest, boxes, pile and item spots) are hidden and non-solid at runtime; the doors, lights, creep and signs stay
	(the run and the client drive them).

	Spec-exempt shell (Instances, Vacuum and Cargo); the reading and checks are the specced TrainingMapRules.

	@class TrainingSiteSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local CargoServiceServer = require(ServerScriptService.Features.Cargo.CargoServiceServer)
local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)
local TrainingMapRules = require(ServerScriptService.Features.Training.Rules.TrainingMapRules)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)

export type Spawned = { stop: number, part: BasePart, treasure: boolean }

-- The roles whose parts only mark a spot or a box: hidden and non-solid at runtime.
local MARKERS: { [string]: boolean } = {
	spawn = true,
	stop = true,
	zone = true,
	route = true,
	rest = true,
	safe = true,
	bay = true,
	pile = true,
	item = true,
}

-- Rises a spawn a little above its marker, so a character lands on the floor.
local SPAWN_LIFT = 3
-- Side-by-side gap between two crew spawns (training is solo; kept for an admin's extra player).
local SPAWN_GAP = 3

local KINDS: TrainingMapRules.Kinds = {
	pile = function(kind)
		return VacuumConstants.PILE_KINDS[kind] ~= nil
	end,
	item = function(kind)
		return CargoRegistry.has(kind)
	end,
	treasure = function(kind)
		local def = CargoRegistry.get(kind)
		return def ~= nil and def.category == "salvage"
	end,
}

local function number(part: Instance, attribute: string): number?
	local value = part:GetAttribute(attribute)
	return if type(value) == "number" then value else nil
end

local function text(part: Instance, attribute: string): string?
	local value = part:GetAttribute(attribute)
	return if type(value) == "string" then value else nil
end

-- The map's parts with a role, as plain entries (a pile or item spot is its part's bottom face).
local function entriesOf(model: Model): { TrainingMapRules.Entry }
	local entries: { TrainingMapRules.Entry } = {}
	for _, part in model:GetDescendants() do
		local role = if part:IsA("BasePart") then text(part, TrainingConstants.ROLE_ATTRIBUTE) else nil
		if role ~= nil and part:IsA("BasePart") then
			local floor = role == "pile" or role == "item"
			table.insert(entries, {
				role = role,
				stop = number(part, TrainingConstants.STOP_ATTRIBUTE),
				order = number(part, TrainingConstants.ORDER_ATTRIBUTE),
				kind = text(part, TrainingConstants.KIND_ATTRIBUTE),
				cframe = if floor then part.CFrame * CFrame.new(0, -part.Size.Y / 2, 0) else part.CFrame,
				size = part.Size,
			})
		end
	end
	return entries
end

local function hideMarkers(model: Model)
	for _, part in model:GetDescendants() do
		local role = if part:IsA("BasePart") then text(part, TrainingConstants.ROLE_ATTRIBUTE) else nil
		if role ~= nil and MARKERS[role] and part:IsA("BasePart") then
			part.Transparency = 1
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
end

local function bedOf(model: Model): BasePart?
	local truck = model:FindFirstChild("Truck")
	local bed = if truck ~= nil then truck:FindFirstChild("TruckBed") else nil
	return if bed ~= nil and bed:IsA("BasePart") then bed else nil
end

local TrainingSiteSystem = {}

--[=[
	The Training map and its plan; nil and the problems when there is no map, more than one, or it does not check out.
]=]
function TrainingSiteSystem.find(): (Model?, TrainingMapRules.Plan?, { string })
	local maps: { Model } = {}
	for _, tagged in CollectionService:GetTagged(TrainingConstants.MAP_TAG) do
		if tagged:IsA("Model") then
			table.insert(maps, tagged)
		end
	end
	if #maps ~= 1 then
		return nil, nil, { `needs exactly one Model tagged {TrainingConstants.MAP_TAG} (found {#maps})` }
	end
	local model = maps[1]
	local plan, errors = TrainingMapRules.read(entriesOf(model), KINDS)
	if bedOf(model) == nil then
		table.insert(errors, "needs a Truck folder with a TruckBed part")
		plan = nil
	end
	return model, plan, errors
end

--[=[
	The site for one run on `model` (read by `find`); `spawned` gets every pile and item it places.
]=]
function TrainingSiteSystem.new(
	model: Model,
	plan: TrainingMapRules.Plan,
	spawned: (piles: { Spawned }, items: { Spawned }) -> ()
): OfficeTypes.Site
	hideMarkers(model)
	local bed = bedOf(model)
	if bed ~= nil then
		bed:SetAttribute(InteractionConstants.KIND_ATTRIBUTE, CargoConstants.LOAD_KIND)
		CollectionService:AddTag(bed, InteractionConstants.TAG)
	end
	local site: OfficeTypes.Site = {
		model = model,
		spawnCFrame = function(index)
			return plan.spawn * CFrame.new((index - 1) * SPAWN_GAP, SPAWN_LIFT, 0)
		end,
		route = function()
			return table.clone(plan.route)
		end,
		restPoint = function()
			return plan.rest
		end,
		safeZone = function()
			return plan.safe.min, plan.safe.max
		end,
		loadingBay = function()
			return plan.bay.min, plan.bay.max
		end,
		whereIs = function(position)
			for index, zone in plan.zones do
				if TrainingMapRules.inside(zone, position) then
					return "Training", index, nil
				end
			end
			return "Training", 1, nil
		end,
		truckBed = function()
			return bed
		end,
		spawn = function(folder)
			local piles: { Spawned } = {}
			for _, pile in plan.piles do
				local part = VacuumServiceServer:spawnPile(pile.kind, pile.cframe, folder)
				table.insert(piles, { stop = pile.stop, part = part, treasure = false })
			end
			local items: { Spawned } = {}
			for _, item in plan.items do
				local part = CargoServiceServer:spawnItem(item.kind, item.cframe, folder)
				table.insert(items, { stop = item.stop, part = part, treasure = KINDS.treasure(item.kind) })
			end
			spawned(piles, items)
			return { piles = {}, items = {}, searchables = {}, greed = nil, value = 0 }
		end,
	}
	return site
end

return TrainingSiteSystem
