--!strict
--[=[
	theme: shared palette + element helpers for the debugger overlay panels.

	Centralizes the look (colors, log-level coloring) and the two repeated building blocks — an
	auto-height text `line` and a `scroller` wrapper — so ServicesPanel/StatePanel/LogsPanel render
	consistently and stay small. Kept separate from any single panel because all three use it.

	@class theme
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement

local theme = {}

-- Palette. Deliberately darker/cooler than the HUD so the two never read as the same surface.
theme.PANEL = Color3.fromRGB(16, 16, 22)
theme.PANEL_LIGHT = Color3.fromRGB(28, 28, 38)
theme.ROW = Color3.fromRGB(22, 22, 30)
theme.ROW_SELECTED = Color3.fromRGB(40, 46, 66)
theme.ACCENT = Color3.fromRGB(120, 200, 255)
theme.TEXT = Color3.fromRGB(228, 228, 235)
theme.MUTED = Color3.fromRGB(140, 140, 155)
theme.GOOD = Color3.fromRGB(120, 220, 150)
theme.WARNING = Color3.fromRGB(240, 200, 120)
theme.BAD = Color3.fromRGB(240, 120, 120)

-- Log-level → color. Keyed by plain string (not the LogLevel union) so callers can index it with a
-- level value that widened to string across a generic boundary — a documented Luau limitation in this
-- codebase. Falls back to TEXT for any level not listed (future-proof if levels change).
theme.LEVEL_COLOR = {
	DEBUG = theme.MUTED,
	INFO = theme.TEXT,
	WARN = theme.WARNING,
	ERROR = theme.BAD,
	AUDIT = theme.ACCENT,
} :: { [string]: Color3 }

local VALUE_LIMIT = 240 -- truncate long serialized values so one row can't dominate a panel

--[=[
	Renders any value to a compact string. Tables go through JSONEncode (pcall-guarded — a value that
	can't encode, e.g. containing an Instance, degrades to a placeholder rather than erroring the UI).
	@param value any -- The value to stringify
	@param truncate boolean? -- When true (default), cap at VALUE_LIMIT; pass false for full expansion
	@return string
]=]
function theme.serialize(value: any, truncate: boolean?): string
	local text: string
	if typeof(value) == "table" then
		local ok, encoded = pcall(function()
			return HttpService:JSONEncode(value)
		end)
		text = ok and encoded or "<unencodable table>"
	else
		text = tostring(value)
	end
	if truncate ~= false and #text > VALUE_LIMIT then
		return text:sub(1, VALUE_LIMIT) .. "…"
	end
	return text
end

--[=[
	A single left-aligned, wrapping, auto-height text line for the scrolling panels.
	@param text string -- Line text
	@param color Color3 -- Text color
	@param order number -- LayoutOrder within its list
	@return React.ReactNode
]=]
function theme.line(text: string, color: Color3, order: number): React.ReactNode
	return e("TextLabel", {
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 13,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Text = text,
	})
end

--[=[
	A bottom-right resize grip ("◢"). Parent it to a container WITHOUT a UIListLayout (list layouts
	position every child, which would pull the grip into the flow). The host owns the size state; this
	only reports the drag start.
	@param onInputBegan (input: InputObject) -> () -- Forward to a useDrag begin function
	@return React.ReactNode
]=]
function theme.resizeGrip(onInputBegan: (input: InputObject) -> ()): React.ReactNode
	return e("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 14,
		TextColor3 = theme.MUTED,
		Text = "◢",
		ZIndex = 10,
		[React.Event.InputBegan] = function(_rbx: TextButton, input: InputObject)
			onInputBegan(input)
		end,
	})
end

--[=[
	Wraps a keyed set of child rows in a vertical scrolling frame with a list layout.
	@param children { [string]: React.ReactNode } -- Keyed rows (a `layout` key is added here)
	@return React.ReactNode
]=]
function theme.scroller(children: { [string]: React.ReactNode }): React.ReactNode
	children.layout = e("UIListLayout", {
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	return e("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = theme.MUTED,
	}, children)
end

return theme
