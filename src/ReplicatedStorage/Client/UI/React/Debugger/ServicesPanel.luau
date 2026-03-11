--!strict
--[=[
	ServicesPanel: the Services tab — a health board for the active realm's ServiceController.

	Per service it shows a status mark (started / init-only / not started / errored), boot timing
	(init + start ms), and a "logs" button that jumps to the Logs tab filtered to that service. Clicking
	a row expands its dependencies, full (untruncated) getState, and any init/start/state errors.

	Reads the realm from `DebuggerState.context`: server services come from the snapshot, client services
	are read locally. Re-renders when either atom changes.

	@class ServicesPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local DebuggerEvents = require(ReplicatedStorage.Shared.Events.DebuggerEvents)
local DebuggerState = require(ReplicatedStorage.Client.State.DebuggerState)
local theme = require(ReplicatedStorage.Client.UI.React.Debugger.theme)
local TableView = require(ReplicatedStorage.Client.UI.React.Debugger.TableView)

local e = React.createElement
local useAtom = ReactCharm.useAtom

type ServiceSnapshot = DebuggerEvents.ServiceSnapshot

export type Props = {
	onJumpToLogs: (serviceContext: string) -> (),
}

--[=[
	Picks the status glyph + color for a service from its health/lifecycle.
	@param service ServiceSnapshot
	@return (string, Color3) -- glyph, color
]=]
local function statusOf(service: ServiceSnapshot): (string, Color3)
	if service.initError or service.startError then
		return "✕", theme.BAD
	elseif service.started then
		return "●", theme.GOOD
	elseif service.initialized then
		return "◐", theme.WARNING
	end
	return "○", theme.MUTED
end

--[=[
	Builds the expanded detail block (deps, full state, errors) shown under a selected service.
	@param service ServiceSnapshot
	@param order number -- LayoutOrder for the block
	@return React.ReactNode
]=]
local function expansion(service: ServiceSnapshot, order: number): React.ReactNode
	local rows: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		pad = e("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingBottom = UDim.new(0, 4) }),
	}
	local i = 0
	local function push(node: React.ReactNode)
		i += 1
		rows[`x-{i}`] = node
	end

	if #service.dependencies > 0 then
		push(theme.line(`deps: {table.concat(service.dependencies, ", ")}`, theme.MUTED, i))
	else
		push(theme.line("deps: (none)", theme.MUTED, i))
	end

	if service.initError then
		push(theme.line(`init error: {service.initError}`, theme.BAD, i))
	end
	if service.startError then
		push(theme.line(`start error: {service.startError}`, theme.BAD, i))
	end

	if service.stateError then
		push(theme.line(`state error: {service.stateError}`, theme.BAD, i))
	elseif service.state then
		-- Structured Component/Data grid (same TableView as the State tab) instead of raw lines.
		local stateRows: { TableView.Row } = {}
		for key, value in service.state do
			table.insert(stateRows, { name = key, value = value })
		end
		table.sort(stateRows, function(a, b)
			return a.name < b.name
		end)
		i += 1
		rows[`x-{i}`] = e(TableView, {
			keyHeader = "State",
			valueHeader = "Data",
			rows = stateRows,
			layoutOrder = i,
		})
	else
		push(theme.line("state: (no getState)", theme.MUTED, i))
	end

	return e("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, rows)
end

--[=[
	One service row: a wide select/expand button plus a small jump-to-logs button.
	@param service ServiceSnapshot
	@param order number
	@param onSelect () -> ()
	@param onJumpToLogs () -> ()
	@return React.ReactNode
]=]
local function serviceRow(
	service: ServiceSnapshot,
	order: number,
	onSelect: () -> (),
	onJumpToLogs: () -> ()
): React.ReactNode
	local glyph, color = statusOf(service)
	local timing = ""
	local total = (service.initDurationMs or 0) + (service.startDurationMs or 0)
	if total > 0 then
		timing = ` · {string.format("%.1f", total)}ms`
	end

	return e("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
	}, {
		select = e("TextButton", {
			Size = UDim2.new(1, -54, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 13,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = `{glyph} {service.name}{timing}`,
			[React.Event.Activated] = onSelect,
		}),
		logs = e("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 50, 1, 0),
			BackgroundColor3 = theme.PANEL_LIGHT,
			BorderSizePixel = 0,
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextColor3 = theme.MUTED,
			Text = "logs",
			[React.Event.Activated] = onJumpToLogs,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		}),
	})
end

--[=[
	The Services panel component.
	@param props Props
	@return React.ReactNode
]=]
local function ServicesPanel(props: Props): React.ReactNode
	local context = useAtom(DebuggerState.context)
	local snapshot = useAtom(DebuggerState.serverSnapshot)
	local selected, setSelected = React.useState(nil :: string?)

	local services: { ServiceSnapshot }
	if context == "server" then
		services = if snapshot then snapshot.services else {}
	else
		services = DebuggerState.getClientServices()
	end

	local rows: { [string]: React.ReactNode } = {}
	local order = 0
	if #services == 0 then
		rows["empty"] = theme.line("waiting for snapshot…", theme.MUTED, 0)
	end
	for _, service in services do
		order += 10
		local name = service.name
		rows[`row-{name}`] = serviceRow(service, order, function()
			setSelected(if selected == name then nil else name)
		end, function()
			props.onJumpToLogs(name)
		end)
		if selected == name then
			rows[`exp-{name}`] = expansion(service, order + 1)
		end
	end

	return theme.scroller(rows)
end

return ServicesPanel
