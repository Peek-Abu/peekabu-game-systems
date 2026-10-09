--!strict
--[=[
	UIPanel (React): the F4 Debugger's "UI" tab — the observation surface for the UI framework, and
	the driver the V2 checkpoint uses BEFORE any real screen exists.

	Shows the live scene stack (top-down, top = active, rest suspended) and the world-suppression
	counts per capability, and offers buttons that push/pop/replace the throwaway UIDebugScenes so the
	stack and the refcounted union can be exercised by hand. Handled capabilities (mouse, blur) apply
	real effects this phase; the declared-but-unhandled ones (movement/…) show with a marker.

	CLIENT-ONLY: scenes live in client UIStore, so DebuggerOverlay hides this tab in the Server context.

	Polls rather than subscribing: it must read UISuppression.counts() (plain data, refreshed by the
	suppression service on stack change), and a poll keeps the stack and the counts consistent in one
	frame regardless of subscriber order — the same reasoning as AnimationsPanel.

	@class UIPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIStore = require(ReplicatedStorage.Client.UI.Scenes.UIStore)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local UIDebugScenes = require(ReplicatedStorage.Client.UI.Scenes.UIDebugScenes)
local UISuppression = require(ReplicatedStorage.Client.UI.Suppression.UISuppression)
local UIRenderCounters = require(ReplicatedStorage.Client.UI.UIRenderCounters)
local DebuggerTheme = require(ReplicatedStorage.Client.UI.React.Debugger.DebuggerTheme)
local Button = require(ReplicatedStorage.Client.UI.React.Primitives.Button)

local e = React.createElement

local POLL_SECONDS = 0.1

-- Capabilities UI handles THIS phase (just the pointer). Everything else — blur, movement, camera —
-- is a declared seam a specialist system registers later; the panel flags them as unhandled.
local HANDLED: { [string]: boolean } = { mouse = true }

type Snapshot = {
	stack: { string },
	counts: { [string]: number },
	renders: { [string]: number },
}

-- A map's keys in a stable order. Both readouts below assign LayoutOrder by ITERATION POSITION, and a
-- Luau dictionary has no defined iteration order — so without this the rows physically reshuffle on
-- every poll, ten times a second. That ruins the one readout you are meant to sit and WATCH: a render
-- count holding flat while a bar moves is the proof that health rides a binding, and it cannot be read
-- if the row it is on keeps jumping.
local function sortedKeys(map: { [string]: number }): { string }
	local keys: { string } = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

local function readSnapshot(): Snapshot
	return {
		stack = UIStore.sceneStack(),
		counts = UISuppression.counts(),
		renders = UIRenderCounters.snapshot(),
	}
end

-- A scene-driving button: the shared Button primitive with the debug label + action.
local function button(text: string, order: number, onClick: () -> ()): React.ReactNode
	return e(Button, {
		text = text,
		layoutOrder = order,
		onActivated = onClick,
	})
end

--[=[
	The panel component.
	@return React.ReactNode
]=]
local function UIPanel(): React.ReactNode
	local snapshot, setSnapshot = React.useState(readSnapshot)

	React.useEffect(function(): () -> ()
		local running = true
		local pollThread = task.spawn(function()
			while running do
				setSnapshot(readSnapshot())
				task.wait(POLL_SECONDS)
			end
		end)
		return function()
			running = false
			-- `running` alone only retires the thread when it next WAKES, leaving it parked in
			-- `task.wait` for up to POLL_SECONDS past the unmount; cancelling makes teardown immediate.
			-- Guarded on the running coroutine because a snapshot write can re-render this panel out of
			-- existence, which lands this cleanup ON the poll thread — and cancelling yourself throws.
			-- Janitor's own thread cleanup takes the same precaution.
			if coroutine.running() ~= pollThread then
				task.cancel(pollThread)
			end
		end
	end, {})

	local stack = snapshot.stack
	local depth = #stack

	local children: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	-- Row of scene-driving buttons (harness).
	children.buttons = e("Frame", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
	}, {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		pushA = button("push A", 1, function()
			SceneStack.push(UIDebugScenes.PANEL_A)
		end),
		pushB = button("push B", 2, function()
			SceneStack.push(UIDebugScenes.PANEL_B)
		end),
		pushMv = button("push Mv", 3, function()
			SceneStack.push(UIDebugScenes.MOVEMENT)
		end),
		pop = button("pop", 4, function()
			SceneStack.pop()
		end),
		clear = button("clear", 5, function()
			while SceneStack.depth() > 0 do
				SceneStack.pop()
			end
		end),
	})

	-- Scene stack, top-down (top = active).
	children.stackHeader = DebuggerTheme.line(`scene stack — depth {depth}`, DebuggerTheme.ACCENT, 2)
	if depth == 0 then
		children.stackEmpty = DebuggerTheme.line("  (empty — nothing open)", DebuggerTheme.MUTED, 3)
	else
		for position = depth, 1, -1 do
			local name = stack[position]
			local tag = if position == depth then "active" else "suspended"
			local color = if position == depth then DebuggerTheme.GOOD else DebuggerTheme.MUTED
			children[`stack-{position}`] =
				DebuggerTheme.line(`  [{position}] {name}  ({tag})`, color, 100 + (depth - position))
		end
	end

	-- Suppression counts per capability.
	children.suppHeader = DebuggerTheme.line("world suppression", DebuggerTheme.ACCENT, 200)
	local anyCounts = next(snapshot.counts) ~= nil
	if not anyCounts then
		children.suppEmpty = DebuggerTheme.line("  (nothing suppressed)", DebuggerTheme.MUTED, 201)
	else
		local order = 210
		for _, capability in sortedKeys(snapshot.counts) do
			local count = snapshot.counts[capability]
			local handled = HANDLED[capability] == true
			local marker = if handled then "" else "  ⚠ no handler yet (declared)"
			local color = if handled then DebuggerTheme.TEXT else DebuggerTheme.WARNING
			children[`supp-{capability}`] = DebuggerTheme.line(`  {capability} × {count}{marker}`, color, order)
			order += 1
		end
	end

	-- Render tallies. The point of this readout: take damage and watch the HUD's health bar move while
	-- its render count stays FLAT — the proof that health rides a binding, not state.
	children.renderHeader = DebuggerTheme.line("render counts", DebuggerTheme.ACCENT, 300)
	if next(snapshot.renders) == nil then
		children.renderEmpty = DebuggerTheme.line("  (nothing rendered yet)", DebuggerTheme.MUTED, 301)
	else
		local order = 310
		for _, name in sortedKeys(snapshot.renders) do
			local count = snapshot.renders[name]
			children[`render-{name}`] = DebuggerTheme.line(`  {name} × {count}`, DebuggerTheme.TEXT, order)
			order += 1
		end
	end

	return DebuggerTheme.scroller(children)
end

return UIPanel
