--!strict
--[=[
	ShiftSiteSystem: the office as one run's site (Cleanup Crew spec §6.2, §6.5). It picks a run's A/B variant
	(ShiftAnalyticsSystem.pickVariant) and the quota for the crew (ShiftQuotaFormulas), sets Round's clearance target,
	rebuilds and spawns the office for it (OfficeServiceServer:beginShift, a fresh seed each run) and remembers how much
	salvage the roll offered (the review's "salvage found N of M"). `clear` resets everything a run made (Office,
	Vacuum, Cargo), each step guarded so a throwing reset never stops the next shift, and forgets a prepared run.

	- `prepare` is the transit's step, under the load screen, before the crew is placed; `take` hands its choice to the
	  run when Round starts it (once);

	- `choose` + `build` are a run started some other way (an admin's round start): the office is built when the run
	  begins and the crew moved into the truck.

	Spec-exempt shell (the services it drives); the variant is the specced ShiftVariantRules, the quota the specced
	ShiftQuotaFormulas, the roll the specced OfficeSpawnUtils.

	@class ShiftSiteSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftQuotaFormulas = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftQuotaFormulas)
local CargoServiceServer = require(ServerScriptService.Features.Cargo.CargoServiceServer)
local OfficeServiceServer = require(ServerScriptService.Features.Office.OfficeServiceServer)
local OfficeTypes = require(ServerScriptService.Features.Office.Data.OfficeTypes)
local OfficeSpawnUtils = require(ServerScriptService.Features.Office.Utils.OfficeSpawnUtils)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)
local ShiftAnalyticsSystem = require(ServerScriptService.Features.Shift.Systems.ShiftAnalyticsSystem)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)

-- A run's A/B variant and quota.
export type Choice = {
	variant: ShiftTypes.Variant,
	quota: number,
}

export type ShiftSiteSystem = {
	clear: (self: ShiftSiteSystem) -> (),
	choose: (self: ShiftSiteSystem, shift: number, crewSize: number) -> Choice,
	prepare: (self: ShiftSiteSystem, shift: number, crewSize: number) -> Choice,
	build: (self: ShiftSiteSystem, choice: Choice, players: { Player }) -> (),
	take: (self: ShiftSiteSystem) -> Choice?,
	offered: (self: ShiftSiteSystem) -> number,
}

local log = Logger.new("ShiftSiteSystem")

local function guarded(label: string, body: () -> ())
	xpcall(body, function(err: unknown)
		log:error(`{label} failed: {err}`)
	end)
end

local ShiftSiteSystem = {}

function ShiftSiteSystem.new(): ShiftSiteSystem
	local rng = Random.new()
	local offered = 0
	local prepared: Choice? = nil

	-- The clearance target, and the office rebuilt and spawned for `choice`.
	local function rebuild(choice: Choice): OfficeTypes.SpawnPlan
		RoundServiceServer:setTarget(ShiftConstants.CLEARANCE, choice.quota)
		local plan = OfficeServiceServer:beginShift({
			seed = rng:NextInteger(1, 1000000000),
			variant = choice.variant,
			quota = choice.quota,
		})
		offered = OfficeSpawnUtils.salvageCount(plan)
		return plan
	end

	local system: ShiftSiteSystem = {
		clear = function(_self)
			prepared = nil
			guarded("office reset", function()
				OfficeServiceServer:reset()
			end)
			guarded("vacuum reset", function()
				VacuumServiceServer:reset()
			end)
			guarded("cargo reset", function()
				CargoServiceServer:reset()
			end)
		end,

		choose = function(_self, shift, crewSize)
			-- Each run's A/B variant (spec §4; rewards never read it); the quota scales with the crew.
			local variant: ShiftTypes.Variant = ShiftAnalyticsSystem.pickVariant(shift)
			return { variant = variant, quota = ShiftQuotaFormulas.quota(crewSize) }
		end,

		prepare = function(self, shift, crewSize)
			local choice = self:choose(shift, crewSize)
			local plan = rebuild(choice)
			prepared = choice
			local greed = plan.greed
			log:info(
				`shift {shift} prepared: variant {choice.variant}, quota {choice.quota}, greed {if greed ~= nil
					then greed.kind
					else "?"}`
			)
			return choice
		end,

		build = function(_self, choice, players)
			rebuild(choice)
			for index, player in players do
				local character = player.Character
				if character ~= nil then
					character:PivotTo(OfficeServiceServer:spawnCFrame(index))
				end
			end
		end,

		take = function(_self)
			local choice = prepared
			prepared = nil
			return choice
		end,

		offered = function(_self)
			return offered
		end,
	}
	return system
end

return ShiftSiteSystem
