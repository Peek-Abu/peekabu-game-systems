--!strict
-- One synchronous claim -> accepted authoritative credit -> consume flow for explicit and settled loads.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CargoShared = ReplicatedStorage.Shared.Features.Cargo
local CargoTypes = require(CargoShared.Data.CargoTypes)
local CargoConstants = require(CargoShared.Data.CargoConstants)
local CargoRegistry = require(CargoShared.Data.CargoRegistry)
local CargoBankRules = require(CargoShared.Rules.CargoBankRules)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local log = Logger.new("CargoLoadSystem")
local CargoClaimTracker = require(ServerScriptService.Features.Cargo.State.CargoClaimTracker)
export type Deps = {
	claims: CargoClaimTracker.CargoClaimTracker,
	entryOf: (Instance) -> CargoTypes.CargoEntry?,
	idOf: (Instance) -> number?,
	handler: () -> CargoTypes.BankHandler?,
	container: () -> Instance?,
	isPresent: (Player) -> boolean,
	getCarried: (Player) -> Instance?,
	forceDrop: (Player) -> (),
	pockets: {
		list: (number) -> { CargoTypes.CargoEntry },
		take: (number) -> (),
	},
	announce: (CargoTypes.Deposit, Vector3, BasePart, number?) -> (),
	tell: ((Player, string) -> ())?,
}
export type Controller = {
	load: (self: Controller, player: Player, bed: BasePart) -> (boolean, string?),
	landed: (self: Controller, player: Player, item: BasePart, bed: BasePart) -> (boolean, string?),
	settled: (self: Controller, player: Player, item: BasePart) -> boolean,
}
local CargoLoadSystem = {}
function CargoLoadSystem.new(deps: Deps): Controller
	local function bedOf(): BasePart?
		-- Cargo lives under Office.ShiftSpawns; the authoritative truck is its sibling Office.Truck.
		local container = deps.container()
		local office = if container ~= nil then container.Parent else nil
		local truck = if office ~= nil then office:FindFirstChild("Truck") else nil
		local bed = if truck ~= nil then truck:FindFirstChild("TruckBed") else nil
		return if bed ~= nil
				and bed:IsA("BasePart")
				and bed:GetAttribute(InteractionConstants.KIND_ATTRIBUTE) == CargoConstants.LOAD_KIND
			then bed
			else nil
	end
	local function bank(
		player: Player,
		item: Instance?,
		pockets: { CargoTypes.CargoEntry },
		bed: BasePart,
		automatic: boolean
	): (boolean, string?)
		local handler = deps.handler()
		if handler == nil or not deps.isPresent(player) then
			return false, "the truck is not taking cargo"
		end
		local hands = if item ~= nil then deps.entryOf(item) else nil
		local id = if item ~= nil then deps.idOf(item) else nil
		local deposit, reason = CargoBankRules.deposit(hands, pockets, CargoRegistry.get)
		if deposit == nil then
			return false, reason
		end
		if hands ~= nil and (id == nil or not deps.claims:claim(id)) then
			return false, "already loaded"
		end
		local from = if item ~= nil and item:IsA("BasePart") then item.Position else bed.Position
		local ok, accepted, credited = pcall(handler, player, deposit)
		if not ok then
			log:warn(`banking handler failed: {accepted}`)
		end
		if not ok or accepted ~= true then
			if hands ~= nil and id ~= nil then
				deps.claims:release(id)
			end
			return false, "the truck is not taking cargo"
		end
		if not automatic then
			deps.pockets.take(player.UserId)
		end
		if item ~= nil and hands ~= nil then
			if not automatic then
				deps.forceDrop(player)
			end
			item:Destroy()
		end
		deps.announce(deposit, from, bed, credited)
		return true, nil
	end
	local system: Controller = {
		load = function(_self, player, bed)
			if bed ~= bedOf() then
				return false, "the truck is not taking cargo"
			end
			local character = player.Character
			local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
			if
				root == nil
				or not root:IsA("BasePart")
				or not CargoBankRules.canLoad(bed.CFrame:PointToObjectSpace(root.Position), bed.Size)
			then
				return false, "move closer to the truck bed to load"
			end
			return bank(player, deps.getCarried(player), deps.pockets.list(player.UserId), bed, false)
		end,
		settled = function(self, player, item)
			local bed = bedOf()
			if
				bed == nil
				or not bed:IsA("BasePart")
				or not CargoBankRules.landedOnBed(bed.CFrame:PointToObjectSpace(item.Position), item.Size, bed.Size)
			then
				return false
			end
			local accepted, reason = self:landed(player, item, bed)
			if not accepted and reason ~= nil and deps.tell ~= nil then
				deps.tell(player, reason)
			end
			-- A refused deposit stays cargo on the bed; it must not spill after the refusal.
			return true
		end,
		landed = function(_self, player, item, bed)
			local container = deps.container()
			if
				container == nil
				or item.Parent == nil
				or not item:IsDescendantOf(container)
				or bed ~= bedOf()
				or bed:GetAttribute(InteractionConstants.KIND_ATTRIBUTE) ~= CargoConstants.LOAD_KIND
				or item:GetAttribute(CarryConstants.CARRIED_BY_ATTRIBUTE) ~= nil
				or not CargoBankRules.landedOnBed(bed.CFrame:PointToObjectSpace(item.Position), item.Size, bed.Size)
			then
				return false, nil
			end
			return bank(player, item, {}, bed, true)
		end,
	}
	return system
end
return CargoLoadSystem
