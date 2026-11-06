--!strict
--[=[
	FilmHideSystem: hides every on-screen and floating label on this client for filming (admin-only, FilmServiceClient),
	then brings back exactly what it hid.

	`hide` turns off every enabled ScreenGui and BillboardGui under the roots (except `keep`), and keeps them off while
	hidden: a gui that appears is turned off too, and one something re-enables is turned off again (React re-renders,
	a billboard made on the fly). World signs (SurfaceGuis) are left alone. `show` turns back on only the ones it turned
	off. `onHidden` is told each change (the core UI and prompts, which are not instances here).

	@class FilmHideSystem
]=]

export type Deps = {
	roots: { Instance },
	-- Guis left showing (the admin console).
	keep: (gui: LayerCollector) -> boolean,
	onHidden: ((hidden: boolean) -> ())?,
}

export type FilmHideSystem = {
	hide: () -> (),
	show: () -> (),
	toggle: () -> (),
	isHidden: () -> boolean,
}

local FilmHideSystem = {}

local function hideable(item: Instance): boolean
	return item:IsA("ScreenGui") or item:IsA("BillboardGui")
end

function FilmHideSystem.new(deps: Deps): FilmHideSystem
	local hidden = false
	-- The guis this hide turned off (to turn back on), with their re-enable watchers.
	local turnedOff: { [LayerCollector]: RBXScriptConnection } = {}
	local watchers: { RBXScriptConnection } = {}

	local function turnOff(item: Instance)
		if not hideable(item) or not item:IsA("LayerCollector") then
			return
		end
		local collector: LayerCollector = item
		if turnedOff[collector] or deps.keep(collector) or not collector.Enabled then
			return
		end
		collector.Enabled = false
		turnedOff[collector] = collector:GetPropertyChangedSignal("Enabled"):Connect(function()
			if hidden and collector.Enabled then
				collector.Enabled = false
			end
		end)
	end

	local system: FilmHideSystem
	system = {
		hide = function()
			if hidden then
				return
			end
			hidden = true
			for _, root in deps.roots do
				for _, item in root:GetDescendants() do
					turnOff(item)
				end
				table.insert(watchers, root.DescendantAdded:Connect(turnOff))
			end
			if deps.onHidden ~= nil then
				deps.onHidden(true)
			end
		end,

		show = function()
			if not hidden then
				return
			end
			hidden = false
			for _, watcher in watchers do
				watcher:Disconnect()
			end
			table.clear(watchers)
			for collector, watcher in turnedOff do
				watcher:Disconnect()
				if collector.Parent ~= nil then
					collector.Enabled = true
				end
			end
			table.clear(turnedOff)
			if deps.onHidden ~= nil then
				deps.onHidden(false)
			end
		end,

		toggle = function()
			if hidden then
				system.show()
			else
				system.hide()
			end
		end,

		isHidden = function()
			return hidden
		end,
	}
	return system
end

return FilmHideSystem
