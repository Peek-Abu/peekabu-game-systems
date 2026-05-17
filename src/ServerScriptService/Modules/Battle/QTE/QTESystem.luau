--!strict
--[=[
	QTE (Quick Time Event) and Interactive Combat System
	
	Provides various interactive mechanics for attacks and reactions:
	- **Timing**: Simple button press at the right moment (parry/dodge)
	- **Rhythm**: Multi-hit timing sequences (combo attacks)
	- **OSU-style**: Cursor/aim-based minigames (precision attacks)
	- **Mashing**: Rapid button presses (charge attacks, escapes)
	
	## Usage
	
	```lua
	local QTESystem = require(ServerScriptService.Modules.Battle.QTE.QTESystem)
	
	-- Create a timing-based QTE for a parry
	local qte = QTESystem.createTiming({
		duration = 0.5,
		perfectWindow = 0.15,
		goodWindow = 0.35,
	})
	
	-- Evaluate player input
	local result = qte:evaluate(timingDelta)
	-- result: "Perfect", "Good", "Miss"
	```
	
	@class QTESystem
]=]

local QTESystem = {}

-- ── QTE Types ─────────────────────────────────────────────────────────────────

export type QTEConfig = {
	duration: number,
	perfectWindow: number?,
	goodWindow: number?,
	difficulty: number?, -- 1-5 scale
}

export type RhythmConfig = {
	beats: { number }, -- array of timing offsets
	perfectWindow: number?,
	goodWindow: number?,
	difficulty: number?,
}

export type OsuConfig = {
	duration: number,
	targetPositions: { { x: number, y: number } },
	hitRadius: number,
	perfectRadius: number?,
	difficulty: number?,
}

export type MashConfig = {
	duration: number,
	targetPresses: number,
	difficulty: number?,
}

-- ── Timing QTE ────────────────────────────────────────────────────────────────

local TimingQTE = {}
TimingQTE.__index = TimingQTE

function TimingQTE.new(config: QTEConfig)
	local self = setmetatable({}, TimingQTE)
	self.duration = config.duration
	self.perfectWindow = config.perfectWindow or 0.15
	self.goodWindow = config.goodWindow or 0.35
	self.difficulty = config.difficulty or 3
	return self
end

function TimingQTE:evaluate(timingDelta: number): string
	if timingDelta >= self.duration then
		return "Miss"
	elseif timingDelta <= self.perfectWindow then
		return "Perfect"
	elseif timingDelta <= self.goodWindow then
		return "Good"
	else
		return "Miss"
	end
end

function TimingQTE:getDamageMultiplier(result: string): number
	if result == "Perfect" then
		return 1.5
	elseif result == "Good" then
		return 1.2
	else
		return 1.0
	end
end

-- ── Rhythm QTE ────────────────────────────────────────────────────────────────

local RhythmQTE = {}
RhythmQTE.__index = RhythmQTE

function RhythmQTE.new(config: RhythmConfig)
	local self = setmetatable({}, RhythmQTE)
	self.beats = config.beats
	self.perfectWindow = config.perfectWindow or 0.1
	self.goodWindow = config.goodWindow or 0.2
	self.difficulty = config.difficulty or 3
	return self
end

function RhythmQTE:evaluateSequence(inputTimings: { number }): { result: string, accuracy: number }
	if #inputTimings ~= #self.beats then
		return { result = "Miss", accuracy = 0.0 }
	end
	
	local perfectHits = 0
	local goodHits = 0
	local totalHits = #self.beats
	
	for i, beatTime in self.beats do
		local inputTime = inputTimings[i]
		local delta = math.abs(inputTime - beatTime)
		
		if delta <= self.perfectWindow then
			perfectHits += 1
		elseif delta <= self.goodWindow then
			goodHits += 1
		end
	end
	
	local accuracy = (perfectHits + goodHits * 0.7) / totalHits
	
	local result: string
	if accuracy >= 0.9 then
		result = "Perfect"
	elseif accuracy >= 0.6 then
		result = "Good"
	else
		result = "Miss"
	end
	
	return { result = result, accuracy = accuracy }
end

function RhythmQTE:getDamageMultiplier(accuracy: number): number
	return 1.0 + (accuracy * 0.5) -- 1.0x to 1.5x based on accuracy
end

-- ── OSU-style QTE ─────────────────────────────────────────────────────────────

local OsuQTE = {}
OsuQTE.__index = OsuQTE

function OsuQTE.new(config: OsuConfig)
	local self = setmetatable({}, OsuQTE)
	self.duration = config.duration
	self.targetPositions = config.targetPositions
	self.hitRadius = config.hitRadius
	self.perfectRadius = config.perfectRadius or config.hitRadius * 0.5
	self.difficulty = config.difficulty or 3
	return self
end

function OsuQTE:evaluateHits(inputPositions: { { x: number, y: number } }): { result: string, accuracy: number }
	if #inputPositions ~= #self.targetPositions then
		return { result = "Miss", accuracy = 0.0 }
	end
	
	local perfectHits = 0
	local goodHits = 0
	local totalTargets = #self.targetPositions
	
	for i, target in self.targetPositions do
		local input = inputPositions[i]
		local distance = math.sqrt((input.x - target.x)^2 + (input.y - target.y)^2)
		
		if distance <= self.perfectRadius then
			perfectHits += 1
		elseif distance <= self.hitRadius then
			goodHits += 1
		end
	end
	
	local accuracy = (perfectHits + goodHits * 0.7) / totalTargets
	
	local result: string
	if accuracy >= 0.9 then
		result = "Perfect"
	elseif accuracy >= 0.6 then
		result = "Good"
	else
		result = "Miss"
	end
	
	return { result = result, accuracy = accuracy }
end

function OsuQTE:getDamageMultiplier(accuracy: number): number
	return 1.0 + (accuracy * 0.8) -- 1.0x to 1.8x for perfect OSU gameplay
end

-- ── Mashing QTE ───────────────────────────────────────────────────────────────

local MashQTE = {}
MashQTE.__index = MashQTE

function MashQTE.new(config: MashConfig)
	local self = setmetatable({}, MashQTE)
	self.duration = config.duration
	self.targetPresses = config.targetPresses
	self.difficulty = config.difficulty or 3
	return self
end

function MashQTE:evaluate(actualPresses: number): { result: string, ratio: number }
	local ratio = actualPresses / self.targetPresses
	
	local result: string
	if ratio >= 1.2 then
		result = "Perfect"
	elseif ratio >= 0.8 then
		result = "Good"
	else
		result = "Miss"
	end
	
	return { result = result, ratio = math.min(ratio, 1.5) }
end

function MashQTE:getDamageMultiplier(ratio: number): number
	return math.min(ratio, 1.5) -- Up to 1.5x for exceeding target
end

-- ── Factory Functions ─────────────────────────────────────────────────────────

function QTESystem.createTiming(config: QTEConfig)
	return TimingQTE.new(config)
end

function QTESystem.createRhythm(config: RhythmConfig)
	return RhythmQTE.new(config)
end

function QTESystem.createOsu(config: OsuConfig)
	return OsuQTE.new(config)
end

function QTESystem.createMash(config: MashConfig)
	return MashQTE.new(config)
end

-- ── Presets ───────────────────────────────────────────────────────────────────

QTESystem.Presets = {
	-- Defensive reactions
	Parry = function()
		return QTESystem.createTiming({
			duration = 0.5,
			perfectWindow = 0.15,
			goodWindow = 0.35,
			difficulty = 3,
		})
	end,

	Dodge = function()
		return QTESystem.createTiming({
			duration = 0.6,
			perfectWindow = 0.2,
			goodWindow = 0.4,
			difficulty = 2,
		})
	end,

	-- Offensive enhancements
	PowerStrike = function()
		return QTESystem.createTiming({
			duration = 0.8,
			perfectWindow = 0.2,
			goodWindow = 0.5,
			difficulty = 2,
		})
	end,

	ComboAttack = function()
		return QTESystem.createRhythm({
			beats = { 0.0, 0.3, 0.6, 0.9 },
			perfectWindow = 0.08,
			goodWindow = 0.15,
			difficulty = 4,
		})
	end,

	ChargeAttack = function()
		return QTESystem.createMash({
			duration = 2.0,
			targetPresses = 20,
			difficulty = 3,
		})
	end,

	PrecisionShot = function()
		return QTESystem.createOsu({
			duration = 1.5,
			targetPositions = {
				{ x = 0.5, y = 0.5 },
			},
			hitRadius = 0.15,
			perfectRadius = 0.05,
			difficulty = 4,
		})
	end,
}

return QTESystem
