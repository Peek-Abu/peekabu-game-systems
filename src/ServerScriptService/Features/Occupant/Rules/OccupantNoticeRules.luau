--!strict
--[=[
	OccupantNoticeRules: the notice beat for someone far down his long cone (Cleanup Crew behaviours design; split out of
	OccupantBrainRules). While he patrols, investigates or searches, a player in his narrow long cone (longRange,
	longAngle; OccupantMindUtils.distant) stops him with his head turned to them while the beat counts up; once it is long
	enough for the distance (OccupantMindUtils.noticeDelay) he chases them. With nobody there the beat falls back
	NOTICE_DECAY a second and is dropped at 0.

	Pure (see OccupantMindUtils): it never changes the mind it is given.

	@class OccupantNoticeRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local M = require(ServerScriptService.Features.Occupant.Utils.OccupantMindUtils)

type Mind = OccupantTypes.Mind
type Senses = OccupantTypes.Senses
type Step = M.Step

local IDLE = M.IDLE

local OccupantNoticeRules = {}

-- The modes in which he looks down his long cone (not at a desk, at a spot, on his break or over a catch).
local LOOKING_FAR: { [string]: boolean } = { patrol = true, investigate = true, search = true }

-- Seconds since the last think (the notice beat's clock), like the director's.
local function tick(mind: Mind, senses: Senses): number
	return math.clamp(senses.now - (mind.lastThink or senses.now), 0, 0.5)
end

-- Someone far down his long cone: count the beat up (a step that stops him, head turned to them) or, once it is long
-- enough for the distance, chase them. Nil when there is no one there (or he is busy).
function OccupantNoticeRules.notice(current: Mind, senses: Senses): Step?
	if not LOOKING_FAR[current.mode] then
		return nil
	end
	local glimpse = M.distant(current, senses)[1]
	if glimpse == nil then
		return nil
	end
	local carried = if current.noticeId == glimpse.userId then current.noticeSeconds or 0 else 0
	local seconds = carried + tick(current, senses)
	if seconds >= M.noticeDelay((glimpse.position - senses.position).Magnitude) then
		local step = M.chase(current, senses, glimpse, false)
		step.mind.noticeId = nil
		step.mind.noticeSeconds = nil
		return step
	end
	local nextMind = table.clone(current)
	nextMind.noticeId = glimpse.userId
	nextMind.noticeSeconds = seconds
	nextMind.point = glimpse.position
	nextMind.swivelUntil = senses.now + 0.3
	return { mind = nextMind, intent = IDLE }
end

-- Nobody far down his cone this think: a noticing in progress falls back (NOTICE_DECAY a second) and is dropped at 0.
function OccupantNoticeRules.fade(current: Mind, senses: Senses): Mind
	local seconds = current.noticeSeconds
	if seconds == nil then
		return current
	end
	local nextMind = table.clone(current)
	local left = seconds - tick(current, senses) * OccupantConstants.NOTICE_DECAY
	nextMind.noticeSeconds = if left > 0 then left else 0
	if left <= 0 then
		nextMind.noticeId = nil
	end
	return nextMind
end

return OccupantNoticeRules
