--!strict
--[=[
	ExperimentAssignUtils: the stable 50/50 split behind every experiment. The key `{experimentId}:{unitKey}` is
	hashed with FNV-1a (32-bit) then the murmur3 `fmix32` finaliser; the low bit picks the variant. The same unit
	always lands in the same variant, and two experiments split the same players independently. The hash values
	are pinned in the spec: changing the maths would reassign every live player. Pure.

	@class ExperimentAssignUtils
]=]

local ExperimentRegistry = require(script.Parent.Parent.Data.ExperimentRegistry)

local TWO_32 = 4294967296
local FNV_OFFSET = 2166136261
local FNV_PRIME = 16777619

-- (a * b) mod 2^32 without losing precision (Luau numbers are doubles): each partial product stays below 2^49.
local function mul32(a: number, b: number): number
	local aLow = a % 65536
	local aHigh = (a - aLow) / 65536
	return (aLow * b + ((aHigh * b) % 65536) * 65536) % TWO_32
end

local ExperimentAssignUtils = {}

--[=[
	FNV-1a, 32-bit, over the string's bytes.
]=]
function ExperimentAssignUtils.fnv1a(text: string): number
	local hash = FNV_OFFSET
	for index = 1, #text do
		hash = mul32(bit32.bxor(hash, string.byte(text, index)), FNV_PRIME)
	end
	return hash
end

--[=[
	The murmur3 `fmix32` finaliser: spreads the low bit of FNV-1a so the parity is unbiased.
]=]
function ExperimentAssignUtils.mix(hash: number): number
	hash = bit32.bxor(hash, bit32.rshift(hash, 16))
	hash = mul32(hash, 0x85EBCA6B)
	hash = bit32.bxor(hash, bit32.rshift(hash, 13))
	hash = mul32(hash, 0xC2B2AE35)
	return bit32.bxor(hash, bit32.rshift(hash, 16))
end

function ExperimentAssignUtils.hash(text: string): number
	return ExperimentAssignUtils.mix(ExperimentAssignUtils.fnv1a(text))
end

--[=[
	1 or 2: the variant slot this unit gets in this experiment.
]=]
function ExperimentAssignUtils.bucket(experimentId: string, unitKey: string): number
	return (ExperimentAssignUtils.hash(`{experimentId}:{unitKey}`) % 2) + 1
end

function ExperimentAssignUtils.variantFor(definition: ExperimentRegistry.Definition, unitKey: string): string
	return definition.variants[ExperimentAssignUtils.bucket(definition.id, unitKey)]
end

return ExperimentAssignUtils
