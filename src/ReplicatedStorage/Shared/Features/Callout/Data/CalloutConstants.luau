--!strict
--[=[
	CalloutConstants: how long pings and stickers show, how far a ping may be placed, the rate limit, and the chat
	wheel's input action (design §8; plan 2026-10-25 step 5: hold T).

	@class CalloutConstants
]=]

export type Kind = "ping" | "sticker"

-- One callout as the server tells it: who, what, and (a ping) where.
export type Shown = { userId: number, kind: Kind, id: string, at: Vector3? }

return table.freeze({
	WHEEL_ACTION = "chatWheel",
	WHEEL_KEY = Enum.KeyCode.T,
	WHEEL_GAMEPAD = Enum.KeyCode.DPadUp,
	-- Seconds on screen.
	PING_SECONDS = 6,
	STICKER_SECONDS = 2.5,
	-- How far from your body a ping may be placed (studs).
	PING_RANGE = 150,
	-- At most one callout a second, and BURST in any WINDOW seconds.
	GAP = 1,
	BURST = 5,
	WINDOW = 10,
})
