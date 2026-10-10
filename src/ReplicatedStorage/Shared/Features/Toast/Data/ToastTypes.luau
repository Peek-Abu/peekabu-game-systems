--!strict
--[=[
	ToastTypes: the Toast feature's shapes. Types only (spec-exempt).

	@class ToastTypes
]=]

export type ToastStyle = {
	background: Color3,
	text: Color3,
	accent: Color3,
	font: Enum.Font,
	-- SoundRegistry id played when a toast in this style appears; absent = silent.
	sound: string?,
}

-- What a game sends. Absent style = ToastConstants.DEFAULT_STYLE; absent duration = DEFAULT_DURATION.
export type ToastRequest = {
	text: string,
	style: string?,
	duration: number?,
}

-- A toast on screen (client), expiring at `expiresAt` (os.clock()).
export type Toast = {
	id: number,
	text: string,
	style: string,
	expiresAt: number,
}

return {}
