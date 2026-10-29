--!strict
--[=[
	HostTypes: crew hosting's shapes. Types only (spec-exempt).

	@class HostTypes
]=]

-- What a player asks of their truck. Only the host starts, cancels, kicks and locks; any member may leave.
export type Action = "start" | "cancel" | "leave" | "kick" | "lock"

-- Why a player may not board a truck: the host kicked them, or it is friends only and they aren't the host's friend.
export type RefuseReason = "kicked" | "friends"

-- One hosted truck as every client sees it, keyed by its Queue pad id.
export type TruckView = {
	host: number,
	locked: boolean,
}

export type HostSnapshot = {
	trucks: { [string]: TruckView },
}

return {}
