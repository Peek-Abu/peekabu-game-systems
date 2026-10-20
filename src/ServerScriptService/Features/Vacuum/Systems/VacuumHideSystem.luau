--!strict
-- Puts a hiding player's vacuum back on the backpack. A player going into a hiding spot (their HideSpotId attribute
-- changes from nil to a spot id) is unequipped once; moving between spots while hiding, or leaving one, does nothing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)

local VacuumHideSystem = {}

export type Deps = { unequip: (player: Player) -> () }
export type Controller = {
	watch: (player: Player) -> (),
	unwatch: (player: Player) -> (),
	stop: () -> (),
}

function VacuumHideSystem.new(deps: Deps): Controller
	local watched: { [Player]: RBXScriptConnection } = {}

	local function unwatch(player: Player)
		local connection = watched[player]
		if connection ~= nil then
			connection:Disconnect()
			watched[player] = nil
		end
	end

	local function watch(player: Player)
		unwatch(player)
		local hiding = player:GetAttribute(HideConstants.PLAYER_SPOT_ATTRIBUTE) ~= nil
		watched[player] = player:GetAttributeChangedSignal(HideConstants.PLAYER_SPOT_ATTRIBUTE):Connect(function()
			local now = player:GetAttribute(HideConstants.PLAYER_SPOT_ATTRIBUTE) ~= nil
			local entered = now and not hiding
			hiding = now
			if entered then
				deps.unequip(player)
			end
		end)
	end

	local function stop()
		for player in watched do
			unwatch(player)
		end
	end

	return { watch = watch, unwatch = unwatch, stop = stop }
end

return VacuumHideSystem
