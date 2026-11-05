--!strict
-- Authoritative progress adapter. Sources are injectable so lifecycle and duplicate guards are testable.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local Registry = require(ReplicatedStorage.Shared.Features.WorkOrder.Data.WorkOrderRegistry)
export type Source = {
	piles: SignalTyped.Signal<BasePart, { Player }>,
	loaded: SignalTyped.Signal<Player, number, number, number>,
	changed: SignalTyped.Signal<ShiftTypes.ShiftState>,
	eligible: (Player) -> boolean,
	crew: () -> { Player },
	-- The userIds who worked the shift just reviewed (RankFormulas.workedIds); only they get "shifts" progress.
	worked: () -> { number },
}
local System = {}
function System.start(source: Source, record: (Player, Registry.Kind, number) -> ()): () -> ()
	local completed: { [number]: boolean } = {}
	local piles = source.piles:Connect(function(_pile, contributors)
		local seen: { [number]: boolean } = {}
		for _, player in contributors do
			if not seen[player.UserId] and player.Parent ~= nil and source.eligible(player) then
				seen[player.UserId] = true
				record(player, "piles", 1)
			end
		end
	end)
	local loaded = source.loaded:Connect(function(player, items, _salvage, overtimeLoot)
		if player.Parent == nil or not source.eligible(player) then
			return
		end
		if items > 0 then
			record(player, "cargo", items)
		end
		if overtimeLoot > 0 then
			record(player, "salvage", overtimeLoot)
		end
	end)
	local changed = source.changed:Connect(function(state)
		if state.phase ~= "results" or completed[state.shift] then
			return
		end
		completed[state.shift] = true
		local worked = source.worked()
		local seen: { [number]: boolean } = {}
		for _, player in source.crew() do
			if player.Parent ~= nil and not seen[player.UserId] and table.find(worked, player.UserId) ~= nil then
				seen[player.UserId] = true
				record(player, "shifts", 1)
			end
		end
	end)
	return function()
		piles:Disconnect()
		loaded:Disconnect()
		changed:Disconnect()
	end
end
return System
