--!strict
--[=[
	OfficeHazardUtils: the yard's parked car with its hazards on (the yard dressing's corner lights). A classic hazard
	blink: on for the first `onSeconds` of every `period`, off for the rest, read off one clock (the server's time) so
	every corner, and every client, blinks in step. Which instances are its lamps: an Attachment named the lamp name
	(the yard placer's "HazardLamp") on the lamp's part. Pure.

	@class OfficeHazardUtils
]=]

local OfficeHazardUtils = {}

--[=[
	Whether the hazards are lit at `now` (seconds): within the first `onSeconds` of each `period`. Never lit for a
	period of 0 or less.
]=]
function OfficeHazardUtils.lit(now: number, period: number, onSeconds: number): boolean
	if period <= 0 then
		return false
	end
	return now % period < onSeconds
end

--[=[
	Whether `instance` is a hazard lamp: an Attachment named `name` on a part (the part is the lamp's lens).
]=]
function OfficeHazardUtils.isLamp(instance: Instance, name: string): boolean
	local parent = instance.Parent
	return instance:IsA("Attachment") and instance.Name == name and parent ~= nil and parent:IsA("BasePart")
end

return OfficeHazardUtils
