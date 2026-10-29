--!strict
--[=[
	QueuePadRules: the decisions about one queue pad. Pure.

	- `config`: a pad's attributes, defaulted and checked.
	- `isAboard`: whether a point (a HumanoidRootPart) stands on the pad, measured in the pad's own space so
	  a rotated pad works.
	- `admit`: the party after a sample: members still aboard keep their place (even past a lowered seat count),
	  newcomers follow while seats are free, and refused players are left out.
	- `deadline`: the countdown starts when the first player boards, resets on every join, stays when
	  someone leaves and stops when the pad empties. A held pad starts none on its own: a started one stays
	  through joins and stops when the pad empties.
	- `canDepart`: anyone aboard an open pad may Depart now, except on a held pad.

	@class QueuePadRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QueueConstants = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)

local QueuePadRules = {}

-- A pad's config from its attribute values, or nil and why.
function QueuePadRules.config(
	capacity: unknown,
	countdown: unknown,
	destination: unknown,
	hold: unknown?
): (QueueTypes.PadConfig?, string?)
	local seats = if capacity == nil then QueueConstants.DEFAULT_CAPACITY else capacity
	if type(seats) ~= "number" or seats ~= math.floor(seats) or seats < 1 or seats > QueueConstants.MAX_CAPACITY then
		return nil, `{QueueConstants.CAPACITY_ATTRIBUTE} must be a whole number from 1 to {QueueConstants.MAX_CAPACITY}`
	end
	local seconds = if countdown == nil then QueueConstants.DEFAULT_COUNTDOWN else countdown
	if type(seconds) ~= "number" or seconds ~= seconds then
		return nil, `{QueueConstants.COUNTDOWN_ATTRIBUTE} must be a number of seconds`
	end
	if type(destination) ~= "string" or destination == "" then
		return nil, `{QueueConstants.DESTINATION_ATTRIBUTE} must name a role`
	end
	local held = if hold == nil then false else hold
	if type(held) ~= "boolean" then
		return nil, `{QueueConstants.HOLD_ATTRIBUTE} must be true or false`
	end
	return {
		capacity = seats,
		countdown = math.clamp(seconds, 0, QueueConstants.MAX_COUNTDOWN),
		destination = destination,
		hold = held,
	},
		nil
end

-- Whether `point` is over the pad's top face and no more than `height` studs above it.
function QueuePadRules.isAboard(padCFrame: CFrame, padSize: Vector3, point: Vector3, height: number): boolean
	local offset = padCFrame:PointToObjectSpace(point)
	local half = padSize / 2
	return math.abs(offset.X) <= half.X
		and math.abs(offset.Z) <= half.Z
		and offset.Y >= -half.Y
		and offset.Y <= half.Y + height
end

-- The party after a sample: `existing` members still in `aboard` (in their order, all of them: a seat count lowered
-- under the party unseats nobody), then newcomers from `aboard` (in its order) while fewer than `capacity` are
-- aboard. Anyone in `refused` is left out.
function QueuePadRules.admit(
	existing: { number },
	aboard: { number },
	capacity: number,
	refused: { [number]: boolean }?
): { number }
	local present: { [number]: boolean } = {}
	for _, userId in aboard do
		if refused == nil or not refused[userId] then
			present[userId] = true
		end
	end
	local result: { number } = {}
	for _, userId in existing do
		if present[userId] then
			table.insert(result, userId)
		end
	end
	for _, userId in aboard do
		if #result >= capacity then
			break
		end
		if present[userId] and table.find(result, userId) == nil then
			table.insert(result, userId)
		end
	end
	return result
end

-- When the pad departs after going from `previous` to `current` members at `now`.
function QueuePadRules.deadline(
	previous: { number },
	current: { number },
	deadline: number?,
	now: number,
	countdown: number,
	held: boolean?
): number?
	if #current == 0 then
		return nil
	end
	if held then
		return deadline
	end
	for _, userId in current do
		if table.find(previous, userId) == nil then
			return now + countdown
		end
	end
	return deadline or now + countdown
end

function QueuePadRules.canDepart(
	members: { number },
	status: QueueTypes.PadStatus,
	userId: number,
	held: boolean?
): boolean
	return not held and status == "open" and table.find(members, userId) ~= nil
end

return QueuePadRules
