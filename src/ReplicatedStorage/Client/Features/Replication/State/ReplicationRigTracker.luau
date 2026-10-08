--!strict
--[=[
	ReplicationRigTracker: this client's player ↔ rig registry (the R2 body API: `bodySpawned` / `bodyDespawned`,
	`getRig`, `getPlayerFromRig`), moved out of ReplicationServiceClient.

	R5 (spec 2026-10-05 §2.1): it is also the ONE writer of a REMOTE player's `Player.Character`. Registering
	a remote player's puppet sets `Character` to it; unregistering clears it only if it still points at that
	puppet. The engine then draws its own speaking icon over the puppet (CP12 T5a). It is client-local — the
	server keeps `Character = nil` (measured). The local player's `Character` belongs to ReplicationOwnerRigSystem; this never
	touches it. Nothing reads a remote player's `Character`: this registry stays the source of truth.

	A stale unregister (a rig that is no longer the player's current one) is a no-op, so a pooled puppet reused
	by another player never loses its new owner's lookups or `Character`.

	@class ReplicationRigTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)

local ReplicationRigTracker = {}

export type Registry = {
	localUserId: number,
	rigsByUserId: { [number]: Model },
	userIdsByRig: { [Model]: number },
	spawned: SignalTyped.Signal<Player, Model>,
	despawned: SignalTyped.Signal<Player, Model>,
}

--[=[
	@param localUserId number -- this client's player
	@return Registry
]=]
function ReplicationRigTracker.new(localUserId: number): Registry
	return {
		localUserId = localUserId,
		rigsByUserId = {},
		userIdsByRig = {},
		spawned = SignalTyped.new(),
		despawned = SignalTyped.new(),
	}
end

--[=[
	Maps `player` ↔ `model`, sets a remote player's `Character`, and fires `spawned`.
	@param registry Registry
	@param player Player
	@param model Model
]=]
function ReplicationRigTracker.register(registry: Registry, player: Player, model: Model)
	registry.rigsByUserId[player.UserId] = model
	registry.userIdsByRig[model] = player.UserId
	if player.UserId ~= registry.localUserId then
		player.Character = model
	end
	registry.spawned:Fire(player, model)
end

--[=[
	Undoes `register` when `model` is still `player`'s current rig; otherwise does nothing.
	@param registry Registry
	@param player Player
	@param model Model
]=]
function ReplicationRigTracker.unregister(registry: Registry, player: Player, model: Model)
	if registry.rigsByUserId[player.UserId] ~= model then
		return
	end
	registry.rigsByUserId[player.UserId] = nil
	registry.userIdsByRig[model] = nil
	if player.UserId ~= registry.localUserId and player.Character == model then
		player.Character = nil
	end
	registry.despawned:Fire(player, model)
end

--[=[
	@param registry Registry
	@param userId number
	@return Model?
]=]
function ReplicationRigTracker.rigFor(registry: Registry, userId: number): Model?
	return registry.rigsByUserId[userId]
end

--[=[
	@param registry Registry
	@param model Model
	@return number?
]=]
function ReplicationRigTracker.userIdFor(registry: Registry, model: Model): number?
	return registry.userIdsByRig[model]
end

return ReplicationRigTracker
