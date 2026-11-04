--!strict
--[=[
	CalloutConstants: how long pings and stickers show, where a sticker floats, how far a ping may be placed, the rate
	limit, and the chat wheel's input action (design §8; plan 2026-10-25 step 5: hold T).

	@class CalloutConstants
]=]

export type Kind = "ping" | "sticker"

-- One callout as the server tells it: who, what, and where (a ping's spot; a sticker's, when its sender had a head).
export type Shown = { userId: number, kind: Kind, id: string, at: Vector3? }

return table.freeze({
	WHEEL_ACTION = "chatWheel",
	WHEEL_KEY = Enum.KeyCode.T,
	WHEEL_GAMEPAD = Enum.KeyCode.DPadUp,
	-- Seconds on screen.
	PING_SECONDS = 6,
	STICKER_SECONDS = 2.5,
	-- A sticker is thrown (owner, 2026-11-04): it leaves the sender's throwing hand STICKER_RELEASE seconds into the
	-- toss and flies for STICKER_FLIGHT seconds to where it floats: STICKER_LIFT studs above their head top and
	-- STICKER_AHEAD in front of them, as they were when they sent it. It stays there (it does not jump or walk
	-- with them) and drifts up STICKER_RISE studs while it shows.
	STICKER_RELEASE = 0.13,
	STICKER_FLIGHT = 0.45,
	STICKER_LIFT = 2.4,
	STICKER_AHEAD = 1.5,
	STICKER_RISE = 1.2,
	-- The sender's toss (AnimationEmployeeRegistry): faded in over TOSS_FADE_IN, held to TOSS_FADE_START seconds, then
	-- faded out over TOSS_FADE_OUT back to their own idle. The sticker leaves the hand at STICKER_RELEASE.
	TOSS_ANIMATION = "stickertoss",
	TOSS_FADE_IN = 0.1,
	TOSS_FADE_START = 0.42,
	TOSS_FADE_OUT = 0.3,
	-- How far from your body a ping may be placed (studs).
	PING_RANGE = 150,
	-- At most one callout a second, and BURST in any WINDOW seconds.
	GAP = 1,
	BURST = 5,
	WINDOW = 10,
})
