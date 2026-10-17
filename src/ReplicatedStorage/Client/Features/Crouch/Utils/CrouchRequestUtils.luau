--!strict
--[=[
	CrouchRequestUtils: what the local player asks for. A crouch is wanted while the crouch key is held (Left Ctrl)
	or a toggle is on (gamepad B, the phone's CROUCH button). The server has the last word, and a toggle follows it
	(`settle`): one the server stands the player up from (a sprint, a hide, a big pick-up) turns off, and one it never
	honoured turns off after TOGGLE_CONFIRM seconds, so a refused toggle never crouches the player later by surprise.
	A held key is left alone: still held, it crouches again once allowed. Pure (every call returns a new Request).

	@class CrouchRequestUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CrouchConstants = require(ReplicatedStorage.Shared.Features.Crouch.Data.CrouchConstants)

export type Request = {
	held: boolean,
	toggled: boolean,
	-- When the toggle went on, until the server first crouches the player (then nil).
	toggledAt: number?,
}

local CrouchRequestUtils = {}

function CrouchRequestUtils.fresh(): Request
	return { held = false, toggled = false, toggledAt = nil }
end

function CrouchRequestUtils.wanted(request: Request): boolean
	return request.held or request.toggled
end

--[=[
	The crouch key pressed (`down`) or let go.
]=]
function CrouchRequestUtils.hold(request: Request, down: boolean): Request
	return { held = down, toggled = request.toggled, toggledAt = request.toggledAt }
end

--[=[
	A toggle press at `now`: on when standing (`crouching` false) with no toggle on, otherwise off.
]=]
function CrouchRequestUtils.toggle(request: Request, crouching: boolean, now: number): Request
	if request.toggled or crouching then
		return { held = request.held, toggled = false, toggledAt = nil }
	end
	return { held = request.held, toggled = true, toggledAt = now }
end

--[=[
	The server's word at `now`: whether the player was crouched before (`was`) and is now (`crouching`).
]=]
function CrouchRequestUtils.settle(request: Request, was: boolean, crouching: boolean, now: number): Request
	if not request.toggled then
		return table.clone(request)
	end
	if crouching then
		return { held = request.held, toggled = true, toggledAt = nil }
	end
	local since = request.toggledAt
	if was or (since ~= nil and now - since > CrouchConstants.TOGGLE_CONFIRM) then
		return { held = request.held, toggled = false, toggledAt = nil }
	end
	return table.clone(request)
end

return CrouchRequestUtils
