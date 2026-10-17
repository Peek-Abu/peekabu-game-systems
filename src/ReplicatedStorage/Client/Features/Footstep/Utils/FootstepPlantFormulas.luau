--!strict
--[=[
	FootstepPlantFormulas: when a foot lands, read from the foot itself. Each frame gets the foot's height (its
	centre minus the HumanoidRootPart's height, so the floor's level cancels out) and
	keeps the last WINDOW seconds of it: the lowest is where this foot stands, the highest how far it swings. A
	foot is ARMED once it rises LIFT_FRACTION of that swing above its stand, and PLANTS (a footstep) the frame it comes
	back down to within PLANT_FRACTION of it: the moment of contact, whatever the clip, the rig's size or the speed
	it plays at. A clip's strides need not all stand at the same depth (Pippa's run loops two strides, the second
	standing ~0.1 studs higher, a third of her swing): an armed foot that bottoms out in the lower STAND_FRACTION of
	the swing without reaching the plant line also plants, on the frame it starts back up, when it came down at least
	BOTTOM_DROP x the rig's scale from its peak (a stride, not a shuffle). Nothing plants:
	- while the swing is below MIN_RANGE x the rig's scale (its HipHeight): an idle sway, a breath, a typing pose;
	- for a foot held up longer than MAX_SWING (sitting, a stand-up, a carry pose): it is disarmed and must come down
	  below the arm line before it can arm again, so the drop that ends it is not a step.
	Whether the character is moving on the ground is the caller's gate (FootstepEmitterSystem). Pure (a foot's state
	table is updated in place).

	@class FootstepPlantFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FootstepConstants = require(ReplicatedStorage.Client.Features.Footstep.Data.FootstepConstants)

export type Foot = {
	-- Seconds since this foot was first sampled.
	clock: number,
	-- The last WINDOW seconds of heights, oldest first.
	times: { number },
	heights: { number },
	armed: boolean,
	armedAt: number,
	-- Since it armed: its highest height, and its lowest since that peak (where a shallower stride bottoms out).
	peak: number,
	bottom: number,
	-- Held up too long: may not arm until it comes back down below the arm line.
	blocked: boolean,
}

local FootstepPlantFormulas = {}

--[=[
	A foot first seen at `height`.
]=]
function FootstepPlantFormulas.fresh(height: number): Foot
	return {
		clock = 0,
		times = { 0 },
		heights = { height },
		armed = false,
		armedAt = 0,
		peak = height,
		bottom = height,
		blocked = false,
	}
end

--[=[
	Feeds one frame (`height` after `dt` seconds) to `foot`, on a rig of `scale` (its HipHeight, studs).
	@return boolean -- true on the frame the foot plants
]=]
function FootstepPlantFormulas.step(foot: Foot, height: number, dt: number, scale: number): boolean
	foot.clock += dt
	local now = foot.clock
	table.insert(foot.times, now)
	table.insert(foot.heights, height)
	local cutoff = now - FootstepConstants.WINDOW
	local drop = 0
	for index, at in foot.times do
		if at >= cutoff then
			break
		end
		drop = index
	end
	if drop > 0 then
		local keep = #foot.times - drop
		table.move(foot.times, drop + 1, #foot.times, 1)
		table.move(foot.heights, drop + 1, #foot.heights, 1)
		for index = #foot.times, keep + 1, -1 do
			foot.times[index] = nil
			foot.heights[index] = nil
		end
	end

	local low, high = math.huge, -math.huge
	for _, value in foot.heights do
		low = math.min(low, value)
		high = math.max(high, value)
	end
	local range = high - low
	local armLine = low + FootstepConstants.LIFT_FRACTION * range
	local plantLine = low + FootstepConstants.PLANT_FRACTION * range
	local standLine = low + FootstepConstants.STAND_FRACTION * range

	if foot.armed and now - foot.armedAt > FootstepConstants.MAX_SWING then
		foot.armed = false
		foot.blocked = true
	end
	if foot.blocked and height < armLine then
		foot.blocked = false
		return false
	end
	if range < FootstepConstants.MIN_RANGE * scale then
		foot.armed = false
		return false
	end
	if foot.armed then
		-- Down to the stand, or came down from its peak and bottomed out (now rising again) in the lower part of the
		-- swing: a shallower stride's contact.
		local bottomedOut = foot.peak - foot.bottom >= FootstepConstants.BOTTOM_DROP * scale
			and height > foot.bottom
			and foot.bottom <= standLine
		if height <= plantLine or bottomedOut then
			foot.armed = false
			return true
		end
		if height >= foot.peak then
			foot.peak = height
			foot.bottom = height
		else
			foot.bottom = math.min(foot.bottom, height)
		end
	elseif not foot.blocked and height > armLine then
		foot.armed = true
		foot.armedAt = now
		foot.peak = height
		foot.bottom = height
	end
	return false
end

return FootstepPlantFormulas
