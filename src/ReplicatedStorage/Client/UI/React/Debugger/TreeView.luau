--!strict
--[=[
	TreeView: a collapsible tree for arbitrarily deep tables — the fix for TableView's one-level-deep
	limit, which pushes anything nested past depth 1 through the truncating serializer and collapses a
	real inventory into an uninspectable `...`.

	Renders Matter-debugger style: a fixed-width KEY column on the left, a DATA column on the right,
	exactly like TableView's grid (same `KEY_COLUMN_WIDTH`, same striped rows). A table node's key cell
	is a ▸/▾ toggle; its data cell shows, while collapsed, a compact one-line-per-immediate-child
	summary — primitive children as `key = value` (via DebuggerTheme.serialize, untruncated — the detail window
	already scrolls and resizes, so there's no reason to cap width) and nested-table children as
	`key = { … }` with no entry count. Once expanded, the data cell goes empty and the children render
	as their own indented rows beneath, each a two-column row in turn. Root entries and their direct
	children start open; anything deeper starts collapsed, so a first render stays glanceable while
	still letting you drill all the way into a large inventory. Open/closed state for every node lives
	in one `React.useState` map keyed by node path (e.g. `"items.3.uid"`), so expanding one branch
	doesn't disturb any other.

	@class TreeView
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local DebuggerTheme = require(ReplicatedStorage.Client.UI.React.Debugger.DebuggerTheme)

local e = React.createElement

export type Props = {
	value: any, -- The root table to render
	layoutOrder: number?,
}

local ROW_HEIGHT = 18
local KEY_COLUMN_WIDTH = 110 -- matches TableView's grid so the State and Services tabs read as one system
local INDENT = 14 -- pixels of left padding added per nesting depth, eaten out of the key column's width

-- Sentinel StatePanel substitutes for a slice with no synced value yet (single source of truth in
-- DebuggerTheme). Rendered in DebuggerTheme.MUTED instead of DebuggerTheme.TEXT so "absent" reads as de-emphasized rather
-- than as a real value.
local NIL_SENTINEL = DebuggerTheme.NIL_SENTINEL

--[=[
	Sorted keys for stable display: numeric (array-style) keys first in ascending order, then the
	remaining keys alphabetically by their string form.
	@param value { [any]: any }
	@return { any }
]=]
local function sortedKeys(value: { [any]: any }): { any }
	local numeric: { number } = {}
	local rest: { any } = {}
	for key in value do
		if typeof(key) == "number" then
			table.insert(numeric, key)
		else
			table.insert(rest, key)
		end
	end
	table.sort(numeric)
	table.sort(rest, function(a, b)
		return tostring(a) < tostring(b)
	end)

	local keys: { any } = {}
	for _, key in numeric do
		table.insert(keys, key)
	end
	for _, key in rest do
		table.insert(keys, key)
	end
	return keys
end

--[=[
	Collapsed-state data-column text for a table node: one line per immediate child, in the same
	sorted order the children would render in if expanded. Primitive children show their full
	untruncated value (`lasered = true`); nested-table children show just their name, no count
	(`items = { … }`) — drilling into them means expanding this node.
	@param value { [any]: any }
	@return string
]=]
local function collapsedSummary(value: { [any]: any }): string
	local lines: { string } = {}
	for _, childKey in sortedKeys(value) do
		local childValue = value[childKey]
		if typeof(childValue) == "table" then
			table.insert(lines, tostring(childKey) .. " = { … }")
		else
			table.insert(lines, tostring(childKey) .. " = " .. DebuggerTheme.serialize(childValue, false))
		end
	end
	if #lines == 0 then
		return "{}"
	end
	return table.concat(lines, "\n")
end

--[=[
	The fixed-width, depth-indented key cell for a primitive row (plain label, no toggle). Indent is
	real pixel offset (not text padding), eaten out of the column's width so long/deep keys still
	truncate inside the column instead of spilling into the data column.
	@param text string
	@param depth number
	@param color Color3
	@return React.ReactNode
]=]
local function keyLabelCell(text: string, depth: number, color: Color3): React.ReactNode
	local offset = math.min(depth * INDENT, KEY_COLUMN_WIDTH - 20)
	return e("TextLabel", {
		Position = UDim2.fromOffset(offset, 0),
		Size = UDim2.fromOffset(math.max(KEY_COLUMN_WIDTH - offset, 20), ROW_HEIGHT),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 13,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = text,
	})
end

--[=[
	The fixed-width, depth-indented key cell for a table-node row: same geometry as `keyLabelCell`, but
	a clickable TextButton carrying the ▸/▾ toggle.
	@param text string -- Already includes the ▸/▾ prefix
	@param depth number
	@param color Color3
	@param onActivated () -> () -- Flips this node's open state
	@return React.ReactNode
]=]
local function keyToggleCell(text: string, depth: number, color: Color3, onActivated: () -> ()): React.ReactNode
	local offset = math.min(depth * INDENT, KEY_COLUMN_WIDTH - 20)
	return e("TextButton", {
		Position = UDim2.fromOffset(offset, 0),
		Size = UDim2.fromOffset(math.max(KEY_COLUMN_WIDTH - offset, 20), ROW_HEIGHT),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 13,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = text,
		[React.Event.Activated] = onActivated,
	})
end

--[=[
	The auto-height data cell, positioned just past the fixed key column regardless of depth (the DATA
	column doesn't indent — only the KEY column does).
	@param text string
	@param color Color3
	@return React.ReactNode
]=]
local function dataCell(text: string, color: Color3): React.ReactNode
	return e("TextLabel", {
		Position = UDim2.fromOffset(KEY_COLUMN_WIDTH + 6, 0),
		Size = UDim2.new(1, -(KEY_COLUMN_WIDTH + 6), 0, 0),
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
	Wraps a key cell and an optional data cell in a striped grid row.
	@param order number -- LayoutOrder, also drives the stripe parity
	@param keyCellNode React.ReactNode
	@param dataCellNode React.ReactNode? -- Omitted (rather than empty) for an expanded table node,
		whose children carry the data instead
	@return React.ReactNode
]=]
local function gridRow(order: number, keyCellNode: React.ReactNode, dataCellNode: React.ReactNode?): React.ReactNode
	local children: { [string]: React.ReactNode } = { key = keyCellNode }
	if dataCellNode ~= nil then
		children.value = dataCellNode
	end
	return e("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = DebuggerTheme.ROW,
		BackgroundTransparency = if order % 2 == 0 then 0.5 else 0.8,
		BorderSizePixel = 0,
	}, children)
end

--[=[
	Renders one node — and, if open, its children — appending onto `rows` in display order. A table
	value becomes a toggleable two-column row (▸/▾ key cell + collapsed-summary or empty data cell);
	anything else renders as a plain two-column key/value row.
	Rows are keyed by node `path` (prefixed `node-` to keep them out of the way of sentinel keys like
	`layout`/`empty`), not by array position — the path is stable across re-renders regardless of
	which siblings are open, so toggling one node never changes another's React key and never forces
	an unnecessary remount. Paths are unique because `sortedKeys` yields each table's keys once and
	every recursive call appends its own key to the parent path, forming a prefix tree; the one
	caveat is a table mixing a numeric key and its string form (e.g. both `1` and `"1"`), which would
	collide on `tostring` — not a shape this debugger's data produces.
	@param rows { [string]: React.ReactNode } -- Accumulator, keyed by `node-{path}`
	@param counter { value: number } -- Shared mutable row counter, drives LayoutOrder and stripe parity
	@param key any -- This node's key (display label)
	@param value any -- This node's value
	@param path string -- Unique path for open-state lookups, e.g. "items.3.uid"
	@param depth number -- Nesting depth: drives indentation and the default-open rule (depth < 2)
	@param openState { [string]: boolean } -- Explicit open/closed overrides, keyed by path
	@param toggle (path: string, default: boolean) -> () -- Flips a node's open state; `default` is
		this node's open state when `openState[path]` is unset (depth < 2), so the toggle can derive
		"currently open" from the latest `previous` state inside its functional updater instead of
		closing over a render-time snapshot.
]=]
local function renderNode(
	rows: { [string]: React.ReactNode },
	counter: { value: number },
	key: any,
	value: any,
	path: string,
	depth: number,
	openState: { [string]: boolean },
	toggle: (path: string, default: boolean) -> ()
)
	counter.value += 1
	local order = counter.value

	if typeof(value) ~= "table" then
		local isSentinel = typeof(value) == "string" and value == NIL_SENTINEL
		local keyNode = keyLabelCell(tostring(key), depth, DebuggerTheme.ACCENT)
		local valueNode = dataCell(
			DebuggerTheme.serialize(value, false),
			if isSentinel then DebuggerTheme.MUTED else DebuggerTheme.TEXT
		)
		rows[`node-{path}`] = gridRow(order, keyNode, valueNode)
		return
	end

	local defaultOpen = depth < 2
	local isOpen = if openState[path] ~= nil then openState[path] else defaultOpen

	local keyNode = keyToggleCell(
		`{if isOpen then "▾" else "▸"} {tostring(key)}`,
		depth,
		DebuggerTheme.ACCENT,
		function()
			toggle(path, defaultOpen)
		end
	)
	local valueNode: React.ReactNode? = if isOpen then nil else dataCell(collapsedSummary(value), DebuggerTheme.TEXT)
	rows[`node-{path}`] = gridRow(order, keyNode, valueNode)

	if isOpen then
		for _, childKey in sortedKeys(value) do
			renderNode(
				rows,
				counter,
				childKey,
				value[childKey],
				`{path}.{tostring(childKey)}`,
				depth + 1,
				openState,
				toggle
			)
		end
	end
end

--[=[
	The TreeView component: the root value's entries become top-level rows (the root itself isn't
	drawn as a row), each independently expandable. A non-table value renders as a single line.
	@param props Props
	@return React.ReactNode
]=]
local function TreeView(props: Props): React.ReactNode
	-- Per-node open/closed overrides, keyed by path. Luau has no call-site syntax for explicit generic
	-- instantiation (`useState<S>(...)` is a parse error), so a typed local supplies useState<S>'s S
	-- through inference instead of a `::` cast on the argument.
	local initialOpenState: { [string]: boolean } = {}
	local openState, setOpenState = React.useState(initialOpenState)
	local function toggle(path: string, default: boolean)
		setOpenState(function(previous: { [string]: boolean })
			local next = table.clone(previous)
			local currentlyOpen = if previous[path] ~= nil then previous[path] else default
			next[path] = not currentlyOpen
			return next
		end)
	end

	local children: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			Padding = UDim.new(0, 1),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	if typeof(props.value) == "table" then
		local counter = { value = 0 }
		for _, key in sortedKeys(props.value) do
			renderNode(children, counter, key, props.value[key], tostring(key), 0, openState, toggle)
		end
		if counter.value == 0 then
			children["empty"] = DebuggerTheme.line("(empty)", DebuggerTheme.MUTED, 1)
		end
	else
		children["root"] = DebuggerTheme.line(DebuggerTheme.serialize(props.value, false), DebuggerTheme.TEXT, 1)
	end

	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, children)
end

return TreeView
