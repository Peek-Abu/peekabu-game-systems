--!strict
--[=[
	DepotStore: the travel card this client shows (the drive card when its truck leaves, the arrival card at
	the office; Cleanup Crew spec §3 steps 2-3). `card` is a Charm atom the HUD widget reads; `show` takes a
	card from the server (DepotEvents.Card), checks its kind and queues it behind a card still on screen (at
	most MAX_QUEUED_CARDS wait; the oldest is dropped); `expire` moves on once a card's time is up. Times are
	os.clock(). `board` / `lastShift` hold the contract board's open contract id and the player's last shift
	(DepotEvents.Board / LastShift). A mirror of what the server sent; nothing here is sent back.

	@class DepotStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)

type Pending = {
	kind: DepotTypes.CardKind,
	title: string,
	body: string,
}

local initialCard: DepotTypes.ShownCard? = nil
local card = Charm.atom(initialCard)
local initialBoard: string? = nil
local board = Charm.atom(initialBoard)
local initialLast: DepotTypes.LastShift? = nil
local lastShift = Charm.atom(initialLast)
local pending: { Pending } = {}

local function kindOf(value: string): DepotTypes.CardKind?
	if value == "drive" then
		return "drive"
	elseif value == "arrival" then
		return "arrival"
	end
	return nil
end

local function secondsFor(kind: DepotTypes.CardKind): number
	if kind == "drive" then
		return DepotConstants.DRIVE_CARD_SECONDS
	end
	return DepotConstants.ARRIVAL_CARD_SECONDS
end

local function present(entry: Pending, now: number)
	card({ kind = entry.kind, title = entry.title, body = entry.body, expiresAt = now + secondsFor(entry.kind) })
end

local DepotStore = {
	card = card,
	-- The contract id of the open board (nil: closed), and the player's last shift for its card.
	board = board,
	lastShift = lastShift,
}

-- Shows (or queues) a card from the server. False, and nothing shown, for an unknown kind.
function DepotStore.show(kind: string, title: string, body: string, now: number): boolean
	-- Annotated and tested with `not` (the RoundSnapshotUtils note): comparing an optional singleton union
	-- against nil widens it back to string.
	local parsed: DepotTypes.CardKind? = kindOf(kind)
	if not parsed then
		return false
	end
	local entry: Pending = { kind = parsed, title = title, body = body }
	local current = card()
	if current == nil or now >= current.expiresAt then
		present(entry, now)
		return true
	end
	if #pending >= DepotConstants.MAX_QUEUED_CARDS then
		table.remove(pending, 1)
	end
	table.insert(pending, entry)
	return true
end

-- Once the card's time is up: the next queued card, or none.
function DepotStore.expire(now: number)
	local current = card()
	if current == nil or now < current.expiresAt then
		return
	end
	local nextCard = table.remove(pending, 1)
	if nextCard ~= nil then
		present(nextCard, now)
	else
		card(nil)
	end
end

-- Opens the board on a contract id from the server; an unknown id reads as the first contract. Returns the id shown.
function DepotStore.openBoard(id: string): string
	local shown = DepotConstants.CONTRACTS[1].id
	for _, contract in DepotConstants.CONTRACTS do
		if contract.id == id then
			shown = id
		end
	end
	board(shown)
	return shown
end

-- Closes the board (the board scene left the stack); the last shift stays for the next opening.
function DepotStore.closeBoard()
	board(nil)
end

function DepotStore.setLastShift(value: DepotTypes.LastShift)
	lastShift(table.clone(value))
end

function DepotStore.clear()
	table.clear(pending)
	card(nil)
	board(nil)
	lastShift(nil)
end

return DepotStore
