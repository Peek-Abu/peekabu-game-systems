--!strict
--[=[
	ShiftPromptStore: the interaction prompt on screen, as the paper prompt chip and the phone LOAD button see it (Cleanup
	Crew M3 UI). ShiftPromptSystem writes it from the engine's prompt events; `hide` and the hold calls act only on the
	prompt that is shown, so an old prompt's late Hidden event cannot hide a newer one. `holdStartedAt` is on the server
	clock (Workspace:GetServerTimeNow(), the clock useServerClock returns), so the chip's fill can compare the two.
	Client-only UI state.

	@class ShiftPromptStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

export type PromptView = {
	id: number,
	action: string,
	object: string,
	key: string,
	hold: number,
	kind: string?,
	holdStartedAt: number?,
}

local initial: PromptView? = nil
local shown = Charm.atom(initial)

local ShiftPromptStore = {
	shown = shown,
}

function ShiftPromptStore.show(view: PromptView)
	shown(table.clone(view))
end

function ShiftPromptStore.hide(id: number)
	local current = shown()
	if current ~= nil and current.id == id then
		shown(nil)
	end
end

function ShiftPromptStore.holdBegan(id: number, now: number)
	local current = shown()
	if current ~= nil and current.id == id then
		local nextView = table.clone(current)
		nextView.holdStartedAt = now
		shown(nextView)
	end
end

function ShiftPromptStore.holdEnded(id: number)
	local current = shown()
	if current ~= nil and current.id == id then
		local nextView = table.clone(current)
		nextView.holdStartedAt = nil
		shown(nextView)
	end
end

function ShiftPromptStore.clear()
	shown(nil)
end

return ShiftPromptStore
