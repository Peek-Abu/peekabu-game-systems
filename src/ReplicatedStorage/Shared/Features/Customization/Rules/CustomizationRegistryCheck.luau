--!strict
--[=[
	CustomizationRegistryCheck: the load-time assertions `CustomizationCosmeticRegistry` runs over its own catalog.

	Extracted for two reasons. The registry is mostly DATA and was crowding the 400-line gate, and —
	more usefully — assertions that only ever run at module load are otherwise impossible to test: you
	cannot construct a malformed registry to prove the guard fires. Taking the value as an argument
	makes each rule an ordinary function with an ordinary spec.

	These FAIL LOUD, unlike `CustomizationArtCheck`, which reports. The distinction is ownership:
	this validates data this repo owns, where a contradiction is a programming error and should stop
	the boot; the conformance checker validates place-owned art that artists edit outside the repo,
	where a missing hat must not stop a server.

	@class CustomizationRegistryCheck
]=]

local CustomizationRegistryCheck = {}

--[=[
	Asserts a colour component is an integer in [0, 255].
	@param value number
	@param label string -- what to name in the failure
]=]
function CustomizationRegistryCheck.assertColorComponent(value: number, label: string)
	assert(
		type(value) == "number" and value == math.floor(value) and value >= 0 and value <= 255,
		`[CosmeticRegistry] {label} must be an integer in [0, 255], got {tostring(value)}`
	)
end

--[=[
	Asserts an optional socket list is a DENSE, non-empty array of unique non-empty strings.

	Each rule earns its place from a way the data can break the runtime quietly:
	- an empty or SPARSE list reports `#list == 0`, and a cosmetic with no sockets silently never
	  mounts — the shell has nothing to bind and skips it;
	- a DUPLICATE in `occupies` makes an accessory conflict with ITSELF in the occupancy rule, so
	  equipping it is refused with no visible cause.

	@param list { string }? -- nil is fine; the field is optional
	@param label string -- what to name in the failure
]=]
function CustomizationRegistryCheck.assertSocketList(list: { string }?, label: string)
	if list == nil then
		return
	end
	local count = 0
	local seen: { [string]: boolean } = {}
	for _, socket in list do
		count += 1
		assert(
			type(socket) == "string" and socket ~= "",
			`[CosmeticRegistry] {label} holds a non-string or empty socket`
		)
		assert(not seen[socket], `[CosmeticRegistry] {label} repeats "{socket}"`)
		seen[socket] = true
	end
	assert(count > 0, `[CosmeticRegistry] {label} is empty — omit the field instead`)
	assert(count == #list, `[CosmeticRegistry] {label} is sparse; it must be a dense array`)
end

return CustomizationRegistryCheck
