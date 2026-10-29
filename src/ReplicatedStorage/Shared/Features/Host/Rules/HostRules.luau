--!strict
--[=[
	HostRules: the decisions about a hosted truck (characters/launch/crew-hosting/DESIGN.md). Pure.

	- `hostAfter`: the first player in hosts; the host stays host while others come and go; when the host leaves,
	  the earliest member left takes over (Queue keeps members in boarding order); an empty truck has none.
	- `seats`: 4, or 6 when the host owns the Big Crew pass.
	- `canAct`: only the host starts, cancels, kicks and locks; any member may leave; the host kicks only another
	  member.
	- `canBoard`: a kicked player never (a kicked member is taken off); on a friends-only truck only the host's
	  friends get on, but the lock never ejects the host or anyone already aboard.
	- `idleDue`: a truck with someone aboard that nobody started for IDLE_SECONDS starts on its own.
	- `exit`: where LEAVE (or a kick) puts a player: on the floor past the pad's front (-Z) edge, facing away.

	@class HostRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HostConstants = require(ReplicatedStorage.Shared.Features.Host.Data.HostConstants)
local HostTypes = require(ReplicatedStorage.Shared.Features.Host.Data.HostTypes)

local HostRules = {}

function HostRules.hostAfter(previous: number?, members: { number }): number?
	if previous ~= nil and table.find(members, previous) ~= nil then
		return previous
	end
	return members[1]
end

function HostRules.seats(ownsPass: boolean): number
	return if ownsPass then HostConstants.PASS_SEATS else HostConstants.SEATS
end

function HostRules.canAct(
	action: HostTypes.Action,
	actor: number,
	host: number?,
	members: { number },
	target: number?
): boolean
	if host == nil or table.find(members, actor) == nil then
		return false
	end
	if action == "leave" then
		return true
	end
	if actor ~= host then
		return false
	end
	if action == "kick" then
		return target ~= nil and target ~= host and table.find(members, target) ~= nil
	end
	return true
end

function HostRules.canBoard(
	userId: number,
	host: number?,
	members: { number },
	locked: boolean,
	kicked: boolean,
	friendOfHost: boolean
): (boolean, HostTypes.RefuseReason?)
	if kicked then
		return false, "kicked"
	end
	if host == nil or not locked or userId == host or table.find(members, userId) ~= nil or friendOfHost then
		return true, nil
	end
	return false, "friends"
end

-- Whether a truck boarded (or last changed host, or last stopped its countdown) at `since` starts on its own now.
function HostRules.idleDue(since: number?, started: boolean, now: number): boolean
	return since ~= nil and not started and now - since >= HostConstants.IDLE_SECONDS
end

function HostRules.exit(padCFrame: CFrame, padSize: Vector3): CFrame
	local offset =
		Vector3.new(0, -padSize.Y / 2 + HostConstants.EXIT_HEIGHT, -(padSize.Z / 2 + HostConstants.EXIT_DISTANCE))
	local position = padCFrame:PointToWorldSpace(offset)
	local front = padCFrame.LookVector
	local flat = Vector3.new(front.X, 0, front.Z)
	local facing = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	return CFrame.lookAt(position, position + facing)
end

return HostRules
