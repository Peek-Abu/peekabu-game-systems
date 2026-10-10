--!strict
--[=[
	ToastRules: turns a game's toast request into what is sent: trimmed, non-empty text cut to MAX_TEXT,
	a known style (else the default), a clamped duration. Pure.

	@class ToastRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToastConstants = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastConstants)
local ToastTypes = require(ReplicatedStorage.Shared.Features.Toast.Data.ToastTypes)

export type Normalized = { text: string, style: string, duration: number }

local ToastRules = {}

function ToastRules.normalize(
	request: ToastTypes.ToastRequest,
	hasStyle: (name: string) -> boolean
): (Normalized?, string?)
	local text = string.match(request.text, "^%s*(.-)%s*$") or ""
	if text == "" then
		return nil, "empty"
	end
	local style = request.style
	local duration = request.duration or ToastConstants.DEFAULT_DURATION
	return {
		text = string.sub(text, 1, ToastConstants.MAX_TEXT),
		style = if style ~= nil and hasStyle(style) then style else ToastConstants.DEFAULT_STYLE,
		duration = math.clamp(duration, ToastConstants.MIN_DURATION, ToastConstants.MAX_DURATION),
	},
		nil
end

return ToastRules
