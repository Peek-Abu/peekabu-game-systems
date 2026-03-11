--!strict
--[=[
	DebuggerOverlay (React): the F4 Service & State Debugger — root component.

	Owns the draggable window chrome, the Server/Client context toggle (drives every panel via
	`DebuggerState.context`), the tab bar, and cross-tab state (active tab + the log context-filter set
	when you click a service's "logs" button). Each tab's body is a dedicated panel component.

	Renders nothing while `DebuggerState.visible` is false. Uses React-lua conventions: `createElement`
	with SEPARATE props/children and children as a keyed dictionary.

	@class DebuggerOverlay
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local DebuggerState = require(ReplicatedStorage.Client.State.DebuggerState)
local theme = require(ReplicatedStorage.Client.UI.React.Debugger.theme)
local useDrag = require(ReplicatedStorage.Client.UI.React.Debugger.useDrag)
local ServicesPanel = require(ReplicatedStorage.Client.UI.React.Debugger.ServicesPanel)
local StatePanel = require(ReplicatedStorage.Client.UI.React.Debugger.StatePanel)
local LogsPanel = require(ReplicatedStorage.Client.UI.React.Debugger.LogsPanel)

local e = React.createElement
local useAtom = ReactCharm.useAtom

local TABS = { "Services", "State", "Logs" }
local PANEL_WIDTH = 440
local PANEL_HEIGHT = 560
-- Resize clamps: small enough to tuck away, large enough for wide tables on big screens.
local MIN_SIZE = Vector2.new(380, 420)
local MAX_SIZE = Vector2.new(1100, 900)

--[=[
	A pill button used for the tab bar and the context toggle.
	@param text string
	@param order number
	@param selected boolean
	@param width number
	@param onClick () -> ()
	@return React.ReactNode
]=]
local function pill(text: string, order: number, selected: boolean, width: number, onClick: () -> ()): React.ReactNode
	return e("TextButton", {
		LayoutOrder = order,
		Size = UDim2.new(0, width, 1, 0),
		BackgroundColor3 = if selected then theme.ACCENT else theme.PANEL_LIGHT,
		BackgroundTransparency = if selected then 0 else 0.3,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = if selected then theme.PANEL else theme.TEXT,
		Text = text,
		[React.Event.Activated] = onClick,
	}, {
		corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
	})
end

--[=[
	Routes the active tab to its panel, threading the cross-tab props.
	@param activeTab string
	@param logContextFilter string?
	@param setLogContextFilter (string?) -> ()
	@param setActiveTab (string) -> ()
	@return React.ReactNode
]=]
local function renderBody(
	activeTab: string,
	logContextFilter: string?,
	setLogContextFilter: (string?) -> (),
	setActiveTab: (string) -> ()
): React.ReactNode
	if activeTab == "Services" then
		return e(ServicesPanel, {
			onJumpToLogs = function(serviceContext: string)
				setLogContextFilter(serviceContext)
				setActiveTab("Logs")
			end,
		})
	elseif activeTab == "State" then
		return e(StatePanel)
	end
	return e(LogsPanel, {
		logContextFilter = logContextFilter,
		onClearContextFilter = function()
			setLogContextFilter(nil)
		end,
	})
end

--[=[
	The overlay root component. Renders nothing while closed.
	@return React.ReactNode
]=]
local function DebuggerOverlay(): React.ReactNode
	local visible = useAtom(DebuggerState.visible)
	local context = useAtom(DebuggerState.context)
	local snapshot = useAtom(DebuggerState.serverSnapshot)
	local activeTab, setActiveTab = React.useState(TABS[1])
	local logContextFilter, setLogContextFilter = React.useState(nil :: string?)
	-- Position stored as right-anchored offsets so the window opens near the top-right and drags freely.
	local position, setPosition = React.useState(Vector2.new(-(PANEL_WIDTH + 16), 16))
	local size, setSize = React.useState(Vector2.new(PANEL_WIDTH, PANEL_HEIGHT))

	-- Drag the header to move; drag the corner grip to resize (clamped). Both share the useDrag hook.
	local beginMove = useDrag(function(delta: Vector2)
		setPosition(function(previous: Vector2)
			return previous + delta
		end)
	end)
	local beginResize = useDrag(function(delta: Vector2)
		setSize(function(previous: Vector2)
			local unclamped = previous + delta
			return Vector2.new(
				math.clamp(unclamped.X, MIN_SIZE.X, MAX_SIZE.X),
				math.clamp(unclamped.Y, MIN_SIZE.Y, MAX_SIZE.Y)
			)
		end)
	end)

	if not visible then
		return nil
	end

	-- Context toggle (Server | Client).
	local contextToggle = e("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(120, 20),
		BackgroundTransparency = 1,
	}, {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		server = pill("Server", 1, context == "server", 56, function()
			DebuggerState.context("server")
		end),
		client = pill("Client", 2, context == "client", 56, function()
			DebuggerState.context("client")
		end),
	})

	-- Tab bar.
	local tabBar: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, tab in TABS do
		tabBar[`tab-{tab}`] = pill(tab, index, tab == activeTab, 84, function()
			setActiveTab(tab)
		end)
	end

	local statusText = if snapshot
		then `phase: {snapshot.phase}   ·   {#snapshot.players} players   ·   {#snapshot.services} services`
		else "waiting for server snapshot…"

	-- selene: allow(roblox_incorrect_roact_usage)
	return e("ScreenGui", {
		Name = "ServiceStateDebugger",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, {
		Panel = e("Frame", {
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(1, position.X, 0, position.Y),
			Size = UDim2.fromOffset(size.X, size.Y),
			BackgroundColor3 = theme.PANEL,
			BackgroundTransparency = 0.05,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
			stroke = e("UIStroke", { Color = theme.PANEL_LIGHT, Thickness = 1 }),
			padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
			}),
			layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			-- Header row doubles as the drag grip (empty areas drag; the toggle buttons sink their own clicks).
			header = e("Frame", {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				[React.Event.InputBegan] = function(_rbx: Frame, input: InputObject)
					beginMove(input)
				end,
			}, {
				title = e("TextLabel", {
					Size = UDim2.new(1, -130, 1, 0),
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					TextSize = 16,
					TextColor3 = theme.ACCENT,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = "Service & State Debugger",
				}),
				toggle = contextToggle,
			}),

			-- Spans the panel width exactly; TextTruncate guarantees it can never overflow it.
			status = e("TextLabel", {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
				Font = Enum.Font.Code,
				TextSize = 12,
				TextColor3 = theme.MUTED,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ClipsDescendants = true,
				Text = `[{context}]   {statusText}   ·   F4 to close`,
			}),

			tabs = e("Frame", {
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundTransparency = 1,
			}, tabBar),

			content = e("Frame", {
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 1, -84),
				BackgroundColor3 = theme.PANEL_LIGHT,
				BackgroundTransparency = 0.4,
			}, {
				corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				pad = e("UIPadding", {
					PaddingTop = UDim.new(0, 6),
					PaddingLeft = UDim.new(0, 8),
					PaddingRight = UDim.new(0, 6),
					PaddingBottom = UDim.new(0, 6),
				}),
				body = renderBody(activeTab, logContextFilter, setLogContextFilter, setActiveTab),

				-- Resize grip: bottom-right corner. Lives here (not under Panel) because Panel's
				-- UIListLayout would otherwise stack it into the flow; content has no list layout.
				grip = theme.resizeGrip(function(input: InputObject)
					beginResize(input)
				end),
			}),
		}),
	})
end

return DebuggerOverlay
