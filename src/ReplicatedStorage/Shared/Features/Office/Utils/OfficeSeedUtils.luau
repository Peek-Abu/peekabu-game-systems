--!strict
--[=[
	OfficeSeedUtils: the stable per-run hash both server and clients read the shift seed through. Pure integer
	arithmetic (FNV-1a over the seed's bytes then the key's bytes, 32-bit), so every machine agrees.

	@class OfficeSeedUtils
]=]

local FNV_OFFSET = 2166136261
local FNV_PRIME = 16777619
local TWO_32 = 4294967296

local OfficeSeedUtils = {}

local function mix(h: number, byte: number): number
	h = bit32.bxor(h, byte)
	-- h * 16777619 mod 2^32 without losing precision: split the prime into 16-bit halves.
	local lo = (h * (FNV_PRIME % 65536)) % TWO_32
	local hi = ((h * math.floor(FNV_PRIME / 65536)) % 65536) * 65536
	return (lo + hi) % TWO_32
end

--[=[
	A deterministic value in [0, 1) for a (seed, key) pair.
	@param seed number -- the shift's layout seed (integer)
	@param key string -- what is being decided
	@return number
]=]
function OfficeSeedUtils.hash01(seed: number, key: string): number
	local h = FNV_OFFSET
	local s = math.floor(seed) % TWO_32
	for _ = 1, 4 do
		h = mix(h, bit32.band(s, 255))
		s = math.floor(s / 256)
	end
	h = mix(h, 0)
	for i = 1, #key do
		h = mix(h, string.byte(key, i))
	end
	-- Final avalanche so short keys spread.
	h = bit32.bxor(h, bit32.rshift(h, 15))
	h = mix(h, 0x9E)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	return h / TWO_32
end

return OfficeSeedUtils
