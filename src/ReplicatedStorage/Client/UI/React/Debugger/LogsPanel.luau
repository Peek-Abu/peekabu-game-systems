--!strict
--[=[
	LogsPanel: the Logs tab — a console-like view over the active realm's Logger ring buffer.

	Features:
	- Per-level filter toggles, built from `Logger.getLevels()` so they track the real level set (change
	  the levels and the buttons follow — no hard-coded list).
	- A context filter chip: arriving here via a service's "logs" button filters to that service's
	  context; the chip's ✕ clears it.
	- A Clear button that empties the buffer for the active realm (local buffer for client, a gated
	  request for server).
	- Newest-first rows, colored by level.

	@class LogsPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local DebuggerState = require(ReplicatedStorage.Client.State.DebuggerState)
local theme = require(ReplicatedStorage.Client.UI.React.Debugger.theme)

local e = React.createElement
local useAtom = ReactCharm.useAtom

export type Props = {
	logContextFilter: string?,
	onClearContextFilter: () -> (),
}

--[=[
	A small level-toggle button. Bright (level color) when enabled, muted when off.
	@param level string -- A LogLevel name (kept as string; it widens across the getLevels boundary)
	@param order number
	@param enabled boolean
	@param onToggle () -> ()
	@return React.ReactNode
]=]
local function levelButton(level: string, order: number, enabled: boolean, onToggle: () -> ()): React.ReactNode
	local color = theme.LEVEL_COLOR[level] or theme.TEXT
	return e("TextButton", {
		LayoutOrder = order,
		Size = UDim2.new(0, 52, 1, 0),
		BackgroundColor3 = if enabled then color else theme.PANEL_LIGHT,
		BackgroundTransparency = if enabled then 0.15 else 0.5,
		BorderSizePixel = 0,
		Font = Enum.Font.Gotham,
		TextSize = 10,
		TextColor3 = if enabled then theme.PANEL else theme.MUTED,
		Text = level,
		[React.Event.Activated] = onToggle,
	}, {
		corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
	})
end

--[=[
	The Logs panel component.
	@param props Props
	@return React.ReactNode
]=]
local function LogsPanel(props: Props): React.ReactNode
	local context = useAtom(DebuggerState.context)
	local snapshot = useAtom(DebuggerState.serverSnapshot)
	local enabledLevels, setEnabledLevels = React.useState(function()
		local initial: { [string]: boolean } = {}
		for _, level in Logger.getLevels() do
			initial[level] = true
		end
		return initial
	end)

	local logs: { Logger.LogEntry }
	if context == "server" then
		logs = if snapshot then snapshot.logs else {}
	else
		logs = DebuggerState.getClientLogs()
	end

	-- Level toggle buttons.
	local controls: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	local order = 0
	for _, level in Logger.getLevels() do
		order += 1
		local thisLevel = level
		controls[`lvl-{level}`] = levelButton(level, order, enabledLevels[level] == true, function()
			local next: { [string]: boolean } = table.clone(enabledLevels)
			next[thisLevel] = not next[thisLevel]
			setEnabledLevels(next)
		end)
	end
	-- Clear button, pinned right.
	controls["clear"] = e("TextButton", {
		LayoutOrder = 100,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 52, 1, 0),
		BackgroundColor3 = theme.BAD,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = theme.PANEL,
		Text = "Clear",
		[React.Event.Activated] = function()
			DebuggerState.clearLogs(context)
		end,
	}, {
		corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
	})

	-- Log rows, newest first, filtered by enabled levels and the optional context filter.
	local rows: { [string]: React.ReactNode } = {}
	local rowOrder = 0
	for i = #logs, 1, -1 do
		local entry = logs[i]
		local levelOn = enabledLevels[entry.level] == true
		local contextOn = props.logContextFilter == nil or entry.context == props.logContextFilter
		if levelOn and contextOn then
			rowOrder += 1
			local color = theme.LEVEL_COLOR[entry.level] or theme.TEXT
			local contextTag = if entry.context ~= "" then `[{entry.context}] ` else ""
			rows[`log-{i}`] = theme.line(`{entry.level} {contextTag}{entry.message}`, color, rowOrder)
		end
	end
	if rowOrder == 0 then
		rows["empty"] = theme.line("(no matching log lines)", theme.MUTED, 0)
	end

	-- Optional context-filter chip.
	local chip: React.ReactNode = nil
	if props.logContextFilter ~= nil then
		chip = e("TextButton", {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundColor3 = theme.PANEL_LIGHT,
			BorderSizePixel = 0,
			Font = Enum.Font.Code,
			TextSize = 11,
			TextColor3 = theme.ACCENT,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = `  filtering: {props.logContextFilter}   (✕ clear)`,
			[React.Event.Activated] = props.onClearContextFilter,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		})
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		layout = e("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		controls = e("Frame", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
		}, controls),
		chip = chip,
		list = e(
			"ScrollingFrame",
			{
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 1, if props.logContextFilter ~= nil then -46 else -28),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = theme.MUTED,
			},
			(function()
				rows.layout = e("UIListLayout", {
					Padding = UDim.new(0, 2),
					SortOrder = Enum.SortOrder.LayoutOrder,
				})
				return rows
			end)()
		),
	})
end

return LogsPanel
