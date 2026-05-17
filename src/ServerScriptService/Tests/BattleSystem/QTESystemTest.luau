--!strict
--[=[
	Unit tests for the QTE (Quick Time Event) system.
	
	Tests verify:
	- Timing QTE evaluation (Perfect/Good/Miss)
	- Rhythm QTE sequence evaluation
	- OSU-style position-based QTE
	- Mashing QTE press counting
	- Damage multipliers
	
	@class QTESystemTest
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local QTESystem = require(ServerScriptService.Modules.Battle.QTE.QTESystem)

local QTESystemTest = {}

function QTESystemTest.testTimingQTEPerfect()
	local qte = QTESystem.createTiming({
		duration = 0.5,
		perfectWindow = 0.15,
		goodWindow = 0.35,
	})
	
	local result = qte:evaluate(0.10)
	assert(result == "Perfect", `Expected Perfect, got {result}`)
	
	local multiplier = qte:getDamageMultiplier(result)
	assert(multiplier == 1.5, `Expected 1.5x multiplier, got {multiplier}`)
	
	return true
end

function QTESystemTest.testTimingQTEGood()
	local qte = QTESystem.createTiming({
		duration = 0.5,
		perfectWindow = 0.15,
		goodWindow = 0.35,
	})
	
	local result = qte:evaluate(0.25)
	assert(result == "Good", `Expected Good, got {result}`)
	
	local multiplier = qte:getDamageMultiplier(result)
	assert(multiplier == 1.2, `Expected 1.2x multiplier, got {multiplier}`)
	
	return true
end

function QTESystemTest.testTimingQTEMiss()
	local qte = QTESystem.createTiming({
		duration = 0.5,
		perfectWindow = 0.15,
		goodWindow = 0.35,
	})
	
	local result = qte:evaluate(0.6)
	assert(result == "Miss", `Expected Miss, got {result}`)
	
	return true
end

function QTESystemTest.testRhythmQTEPerfect()
	local qte = QTESystem.createRhythm({
		beats = { 0.0, 0.3, 0.6, 0.9 },
		perfectWindow = 0.1,
		goodWindow = 0.2,
	})
	
	local evaluation = qte:evaluateSequence({ 0.05, 0.32, 0.58, 0.88 })
	
	assert(evaluation.result == "Perfect", `Expected Perfect, got {evaluation.result}`)
	assert(evaluation.accuracy >= 0.9, `Expected accuracy >= 0.9, got {evaluation.accuracy}`)
	
	return true
end

function QTESystemTest.testRhythmQTEWrongLength()
	local qte = QTESystem.createRhythm({
		beats = { 0.0, 0.3, 0.6, 0.9 },
		perfectWindow = 0.1,
		goodWindow = 0.2,
	})
	
	local evaluation = qte:evaluateSequence({ 0.0, 0.3 }) -- Too few inputs
	
	assert(evaluation.result == "Miss", "Wrong input count should result in Miss")
	assert(evaluation.accuracy == 0.0, "Accuracy should be 0.0")
	
	return true
end

function QTESystemTest.testOsuQTEPerfect()
	local qte = QTESystem.createOsu({
		duration = 1.5,
		targetPositions = {
			{ x = 0.5, y = 0.5 },
			{ x = 0.8, y = 0.3 },
		},
		hitRadius = 0.15,
		perfectRadius = 0.05,
	})
	
	local evaluation = qte:evaluateHits({
		{ x = 0.51, y = 0.49 },
		{ x = 0.79, y = 0.31 },
	})
	
	assert(evaluation.result == "Perfect", `Expected Perfect, got {evaluation.result}`)
	assert(evaluation.accuracy >= 0.9, `Expected high accuracy, got {evaluation.accuracy}`)
	
	return true
end

function QTESystemTest.testOsuQTEMiss()
	local qte = QTESystem.createOsu({
		duration = 1.5,
		targetPositions = {
			{ x = 0.5, y = 0.5 },
		},
		hitRadius = 0.15,
		perfectRadius = 0.05,
	})
	
	local evaluation = qte:evaluateHits({
		{ x = 0.9, y = 0.9 }, -- Way off target
	})
	
	assert(evaluation.result == "Miss", `Expected Miss, got {evaluation.result}`)
	
	return true
end

function QTESystemTest.testMashQTEPerfect()
	local qte = QTESystem.createMash({
		duration = 2.0,
		targetPresses = 20,
	})
	
	local evaluation = qte:evaluate(25) -- Exceeded target
	
	assert(evaluation.result == "Perfect", `Expected Perfect, got {evaluation.result}`)
	assert(evaluation.ratio == 1.25, `Expected ratio 1.25, got {evaluation.ratio}`)
	
	return true
end

function QTESystemTest.testMashQTEGood()
	local qte = QTESystem.createMash({
		duration = 2.0,
		targetPresses = 20,
	})
	
	local evaluation = qte:evaluate(18) -- Close to target
	
	assert(evaluation.result == "Good", `Expected Good, got {evaluation.result}`)
	
	return true
end

function QTESystemTest.testMashQTEMiss()
	local qte = QTESystem.createMash({
		duration = 2.0,
		targetPresses = 20,
	})
	
	local evaluation = qte:evaluate(10) -- Too few presses
	
	assert(evaluation.result == "Miss", `Expected Miss, got {evaluation.result}`)
	
	return true
end

function QTESystemTest.testPresetParry()
	local qte = QTESystem.Presets.Parry()
	
	assert(qte ~= nil, "Parry preset should create a QTE")
	
	local result = qte:evaluate(0.12)
	assert(result == "Perfect", "Parry preset should work correctly")
	
	return true
end

function QTESystemTest.testPresetComboAttack()
	local qte = QTESystem.Presets.ComboAttack()
	
	assert(qte ~= nil, "ComboAttack preset should create a QTE")
	assert(qte.beats ~= nil, "ComboAttack should have beats")
	
	return true
end

return QTESystemTest
