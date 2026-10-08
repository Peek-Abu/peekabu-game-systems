--!strict
--[=[
	UIRenderCounters: a per-screen tally of how many times a component has rendered, shown in the F4
	UI tab.

	This exists to make a performance claim CHECKABLE rather than asserted. The Vitals HUD drives its
	health bar through a React binding (which writes the instance property directly) instead of state
	(which would re-render the tree on every `HealthChanged`). The difference is invisible by eye — but
	it is obvious here: take damage, watch the health bar move, and watch this number NOT climb.

	A component ticks it from an effect with no dependency array, which React runs after EVERY render.

	@class UIRenderCounters
]=]

local counters: { [string]: number } = {}

local UIRenderCounters = {}

--[=[
	Records one render of `name`.
	@param name string -- The component's display name (e.g. "VitalsHud")
]=]
function UIRenderCounters.tick(name: string)
	counters[name] = (counters[name] or 0) + 1
end

--[=[
	A copy of the current tallies — a copy so a reader (the debug panel) cannot corrupt the counts.
	@return { [string]: number }
]=]
function UIRenderCounters.snapshot(): { [string]: number }
	return table.clone(counters)
end

--[=[
	Clears every tally. For specs, and for a "reset and watch" pass while diagnosing in Studio.
]=]
function UIRenderCounters.reset()
	table.clear(counters)
end

return UIRenderCounters
