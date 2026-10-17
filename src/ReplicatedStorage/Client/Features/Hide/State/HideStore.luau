--!strict
--[=[
	HideStore: hiding as the local UI sees it (docs/superpowers/specs/2026-10-15-cleanup-crew-chase-kit-design.md §4):
	`prompt`, the hiding spot's prompt the engine shows now (its words, key and hold; `holdStartedAt` on the server
	clock), and `hidden`, the spot the local player hides in (from the server's Player attributes). `hidePrompt` and the
	hold calls act only on the prompt shown, so a late Hidden event never clears a newer one. Written only by
	HideServiceClient. Client-only UI state.

	@class HideStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

export type PromptView = {
	id: number,
	action: string,
	noun: string,
	key: string,
	hold: number,
	holdStartedAt: number?,
}

export type HiddenView = {
	spotId: string,
	kind: string,
	noun: string,
	-- When they went in (server time).
	since: number,
	-- A supply cabinet's door stands open (the Manager opening it to look in).
	doorOpen: boolean?,
	-- Until when (server time) the server holds off the camping push-out (the Manager at or sitting over the spot).
	heldUntil: number?,
}

local initialPrompt: PromptView? = nil
local initialHidden: HiddenView? = nil
local prompt = Charm.atom(initialPrompt)
local hidden = Charm.atom(initialHidden)

local HideStore = {
	prompt = prompt,
	hidden = hidden,
}

function HideStore.showPrompt(view: PromptView)
	prompt(table.clone(view))
end

function HideStore.hidePrompt(id: number)
	local current = prompt()
	if current ~= nil and current.id == id then
		prompt(nil)
	end
end

function HideStore.holdBegan(id: number, now: number)
	local current = prompt()
	if current ~= nil and current.id == id then
		local nextView = table.clone(current)
		nextView.holdStartedAt = now
		prompt(nextView)
	end
end

function HideStore.holdEnded(id: number)
	local current = prompt()
	if current ~= nil and current.id == id then
		local nextView = table.clone(current)
		nextView.holdStartedAt = nil
		prompt(nextView)
	end
end

function HideStore.setHidden(view: HiddenView?)
	hidden(if view ~= nil then table.clone(view) else nil)
end

--[=[
	Marks the door of the spot the player hides in open or shut (nothing while not hiding).
]=]
function HideStore.setDoorOpen(open: boolean)
	local current = hidden()
	if current ~= nil and current.doorOpen ~= open then
		local nextView = table.clone(current)
		nextView.doorOpen = open
		hidden(nextView)
	end
end

--[=[
	Marks until when (server time; nil: not held) the camping push-out is held off for the spot the player hides in
	(nothing while not hiding).
]=]
function HideStore.setHeldUntil(untilTime: number?)
	local current = hidden()
	if current ~= nil and current.heldUntil ~= untilTime then
		local nextView = table.clone(current)
		nextView.heldUntil = untilTime
		hidden(nextView)
	end
end

function HideStore.clear()
	prompt(nil)
	hidden(nil)
end

return HideStore
