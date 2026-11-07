--!strict
--[=[
	TrainingCoachStore: the training guide as the local UI sees it (tutorial v3). `stop` is the run's stop (the
	`training` world entry; nil off a run) and `situation` what the trail system sees of the player there (the stop's
	door open, carrying the treasure, hidden), so Pippa's line follows them (TrainingGuideRules.coach). A line can be
	said over that (`say`: a tour step, the catch tip) until it runs out or is quieted. `catch` is the latest training
	catch (the catch beat plays from it) and `finish` the finish screen's payout once the run is done. Written by
	TrainingServiceClient and the training systems; read by the training screens. Client-only UI state.

	@class TrainingCoachStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local TrainingGuideRules = require(ReplicatedStorage.Shared.Features.Training.Rules.TrainingGuideRules)

-- A line said over the stop's own, until `untilAt` (os.clock; nil = until quieted).
export type Said = { line: TrainingConstants.CoachLine, untilAt: number? }
export type Catch = { at: number, lives: number }
export type Finish = { gleam: number }
-- The finish screen's pick: ride home now, or play again (TrainingServiceClient sends it).
export type Pick = "back" | "again"

local CALM: TrainingGuideRules.Situation = table.freeze({ stopDone = false, carrying = false, hidden = false })

local initialStop: number? = nil
local initialSaid: Said? = nil
local initialCatch: Catch? = nil
local initialFinish: Finish? = nil
local initialPick: Pick? = nil
local stop = Charm.atom(initialStop)
local situation = Charm.atom(CALM)
local said = Charm.atom(initialSaid)
local catch = Charm.atom(initialCatch)
local finish = Charm.atom(initialFinish)
local picked = Charm.atom(initialPick)

local TrainingCoachStore = {
	stop = stop,
	situation = situation,
	said = said,
	catch = catch,
	finish = finish,
	picked = picked,
}

-- The run's stop (nil off a run); a new stop starts calm.
function TrainingCoachStore.setStop(value: number?)
	if stop() ~= value then
		situation(CALM)
	end
	stop(value)
end

function TrainingCoachStore.setSituation(value: TrainingGuideRules.Situation)
	local current = situation()
	if current.stopDone ~= value.stopDone or current.carrying ~= value.carrying or current.hidden ~= value.hidden then
		situation(table.freeze(table.clone(value)))
	end
end

-- Says `line` over the stop's own from `now` for `seconds` (nil = until quieted).
function TrainingCoachStore.say(line: TrainingConstants.CoachLine, now: number, seconds: number?)
	said({ line = line, untilAt = if seconds ~= nil then now + seconds else nil })
end

-- Drops a said line.
function TrainingCoachStore.quiet()
	said(nil)
end

-- What Pippa says at `now` (os.clock): a said line still running, else the stop's own; nil off a run.
function TrainingCoachStore.line(now: number): TrainingConstants.CoachLine?
	local current = said()
	if current ~= nil and (current.untilAt == nil or now < current.untilAt) then
		return current.line
	end
	local at = stop()
	if at == nil then
		return nil
	end
	return TrainingGuideRules.coach(at, situation())
end

function TrainingCoachStore.caught(now: number, lives: number)
	catch({ at = now, lives = lives })
end

function TrainingCoachStore.finished(gleam: number)
	finish({ gleam = gleam })
	picked(nil)
end

-- The finish screen's pick (once: a second pick is ignored).
function TrainingCoachStore.pick(value: Pick)
	if picked() == nil then
		picked(value)
	end
end

-- Back to nothing (off a run, or a test).
function TrainingCoachStore.reset()
	stop(nil)
	situation(CALM)
	said(nil)
	catch(nil)
	finish(nil)
	picked(nil)
end

return TrainingCoachStore
