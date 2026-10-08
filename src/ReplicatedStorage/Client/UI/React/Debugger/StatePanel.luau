--!strict
--[=[
	StatePanel: the State tab — a Matter-debugger-style world inspector.

	Layout (mirroring Matter's WORLD INSPECT):
	- LEFT sidebar: each slice with its live count ("2 · currency"), clickable to toggle that slice's
	  column in the main table (a filter, like Matter's component list).
	- MAIN area: a proper table — header row (Player | Id | one column per enabled slice), one row per
	  player, searchable, selectable. Cell values are compact; the detail window shows them fully.
	- FLOATING detail window (Matter's "ENTITY n" panel): the selected player's slices as a structured
	  Component/Data grid (TableView) plus their rate-limit counters — no JSON blobs. Docked bottom-left
	  by default; drag its title bar to move it, its corner grip to resize it.
	Selecting a player also highlights their character in-world.

	Server context sources everything from the snapshot (all players); client context shows the local
	player from StateSyncClientStore. Re-renders when context or snapshot changes.

	@class StatePanel
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local DebuggerEvents = require(ReplicatedStorage.Shared.Features.Debugger.Net.DebuggerEvents)
local DebuggerStore = require(ReplicatedStorage.Client.Features.Debugger.State.DebuggerStore)
local DebuggerTheme = require(ReplicatedStorage.Client.UI.React.Debugger.DebuggerTheme)
local TableView = require(ReplicatedStorage.Client.UI.React.Debugger.TableView)
local TreeView = require(ReplicatedStorage.Client.UI.React.Debugger.TreeView)
local useDrag = require(ReplicatedStorage.Client.UI.React.Debugger.useDrag)

local e = React.createElement
local useAtom = ReactCharm.useAtom

type PlayerInfo = DebuggerEvents.PlayerInfo
type AtomSnapshot = DebuggerEvents.AtomSnapshot
type RateLimitSnapshot = DebuggerEvents.RateLimitSnapshot

local SIDEBAR_WIDTH = 108
local ROW_HEIGHT = 20
local CELL_LIMIT = 60 -- table cells are glanceable; the detail pane shows full values

-- The floating detail window (Matter's "ENTITY n" panel): default size + resize clamps.
local DETAIL_DEFAULT_SIZE = Vector2.new(300, 170)
local DETAIL_MIN_SIZE = Vector2.new(220, 110)
local DETAIL_MAX_SIZE = Vector2.new(700, 500)

--[=[
	Compact cell text for the main table (harder cap than the general serializer).
	@param value any
	@return string
]=]
local function cellText(value: any): string
	if value == nil then
		return "—"
	end
	local text = DebuggerTheme.serialize(value)
	if #text > CELL_LIMIT then
		return text:sub(1, CELL_LIMIT) .. "…"
	end
	return text
end

--[=[
	Builds the column layout for the main table: fixed Player/Id columns, then the enabled slices
	sharing the remaining width equally. Widths are scale fractions of the table width.
	@param slices { string } -- Enabled slice columns, sorted
	@return { { name: string, scale: number, offset: number } }
]=]
local function buildColumns(slices: { string }): { { name: string, scale: number, offset: number } }
	local columns = {
		{ name = "Player", scale = 0, offset = 96 },
		{ name = "Id", scale = 0, offset = 70 },
	}
	local sliceScale = if #slices > 0 then 1 / #slices else 0
	for _, slice in slices do
		table.insert(columns, { name = slice, scale = sliceScale, offset = -(166 / #slices) })
	end
	return columns
end

--[=[
	Renders one table row (header or player) as positioned cells. `x` accumulates scale+offset so the
	columns line up identically in every row.
	@param cells { string } -- One text per column, matching `columns`
	@param columns { { name: string, scale: number, offset: number } }
	@param isHeader boolean
	@return { [string]: React.ReactNode } -- Keyed cell elements
]=]
local function rowCells(
	cells: { string },
	columns: { { name: string, scale: number, offset: number } },
	isHeader: boolean
): { [string]: React.ReactNode }
	local children: { [string]: React.ReactNode } = {}
	local xScale = 0
	local xOffset = 0
	for index, column in columns do
		children[`c-{index}`] = e("TextLabel", {
			Position = UDim2.new(xScale, xOffset, 0, 0),
			Size = UDim2.new(column.scale, column.offset, 1, 0),
			BackgroundTransparency = 1,
			Font = if isHeader then Enum.Font.GothamBold else Enum.Font.Code,
			TextSize = if isHeader then 12 else 13,
			TextColor3 = if isHeader then DebuggerTheme.TEXT else DebuggerTheme.TEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = ` {cells[index] or ""}`,
		})
		xScale += column.scale
		xOffset += column.offset
	end
	return children
end

--[=[
	The State panel component.
	@return React.ReactNode
]=]
local function StatePanel(): React.ReactNode
	local context = useAtom(DebuggerStore.context)
	local snapshot = useAtom(DebuggerStore.serverSnapshot)
	-- Hooks must run unconditionally (React's rules of hooks), so this is read every render even
	-- though it's only used in the "client" branch below — the same shape as `snapshot` above, which
	-- likewise feeds only the "server" branch.
	local clientAtoms = useAtom(DebuggerStore.clientAtoms)
	local selectedUserId, setSelectedUserId = React.useState(nil :: number?)
	local search, setSearch = React.useState("")
	-- Disabled slice columns (default: all enabled). Stored inverted so a new slice is visible without
	-- state migration.
	-- Typed local (not a cast) pins useState's generic — the cast-free pattern TreeView established.
	local initialHiddenSlices: { [string]: boolean } = {}
	local hiddenSlices, setHiddenSlices = React.useState(initialHiddenSlices)

	-- Floating detail window state: offset from its default bottom-left docking point, plus size.
	local detailOffset, setDetailOffset = React.useState(Vector2.zero)
	local detailSize, setDetailSize = React.useState(DETAIL_DEFAULT_SIZE)
	local beginDetailMove = useDrag(function(delta: Vector2)
		setDetailOffset(function(previous: Vector2)
			return previous + delta
		end)
	end)
	local beginDetailResize = useDrag(function(delta: Vector2)
		setDetailSize(function(previous: Vector2)
			local unclamped = previous + delta
			return Vector2.new(
				math.clamp(unclamped.X, DETAIL_MIN_SIZE.X, DETAIL_MAX_SIZE.X),
				math.clamp(unclamped.Y, DETAIL_MIN_SIZE.Y, DETAIL_MAX_SIZE.Y)
			)
		end)
	end)

	local players: { PlayerInfo }
	local atoms: { AtomSnapshot }
	local rateLimits: { RateLimitSnapshot }
	if context == "server" then
		players = if snapshot then snapshot.players else {}
		atoms = if snapshot then snapshot.atoms else {}
		rateLimits = if snapshot then snapshot.rateLimits else {}
	else
		players = DebuggerStore.getClientPlayers()
		atoms = clientAtoms
		rateLimits = {}
	end

	-- Index atoms by (slice, userId), collect the slice universe + per-slice non-nil counts.
	local valueBySliceUser: { [string]: { [number]: any } } = {}
	local sliceCounts: { [string]: number } = {}
	local allSlices: { string } = {}
	for _, atom in atoms do
		if valueBySliceUser[atom.slice] == nil then
			valueBySliceUser[atom.slice] = {}
			sliceCounts[atom.slice] = 0
			table.insert(allSlices, atom.slice)
		end
		valueBySliceUser[atom.slice][atom.userId] = atom.value
		if atom.value ~= nil then
			sliceCounts[atom.slice] += 1
		end
	end
	table.sort(allSlices)

	local enabledSlices: { string } = {}
	for _, slice in allSlices do
		if not hiddenSlices[slice] then
			table.insert(enabledSlices, slice)
		end
	end
	local columns = buildColumns(enabledSlices)

	-- Default the selection to the first player until one is clicked.
	local effectiveSelected = selectedUserId
	if effectiveSelected == nil and #players > 0 then
		effectiveSelected = players[1].userId
	end

	-- Highlight the selected player's character in-world, cleaned up when the selection changes or the
	-- panel unmounts. `-1` stands in for "no selection" so the dependency array is always one number.
	React.useEffect(function()
		if effectiveSelected == nil then
			return
		end
		local player = Players:GetPlayerByUserId(effectiveSelected)
		local character = if player ~= nil then player.Character else nil
		if not character then
			-- Not spawned (or streamed out): skip. The effect keys only off the userId, so a later spawn
			-- won't re-run it — reselecting reapplies the highlight, a fine tradeoff for a debug overlay
			-- versus wiring up CharacterAdded listeners here.
			return
		end
		local highlight = Instance.new("Highlight")
		highlight.FillColor = DebuggerTheme.ACCENT
		highlight.FillTransparency = 0.6
		highlight.OutlineColor = DebuggerTheme.ACCENT
		highlight.Adornee = character
		highlight.Parent = character
		return function()
			highlight:Destroy()
		end
	end, { effectiveSelected or -1 })

	-- LEFT sidebar: slice filters with counts.
	local sidebarRows: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			Padding = UDim.new(0, 3),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		header = DebuggerTheme.line("SLICES", DebuggerTheme.MUTED, 0),
	}
	for index, slice in allSlices do
		local enabled = not hiddenSlices[slice]
		local thisSlice = slice
		sidebarRows[`s-{slice}`] = e("TextButton", {
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundColor3 = if enabled then DebuggerTheme.ROW_SELECTED else DebuggerTheme.ROW,
			BackgroundTransparency = if enabled then 0 else 0.5,
			BorderSizePixel = 0,
			Font = Enum.Font.Code,
			TextSize = 12,
			TextColor3 = if enabled then DebuggerTheme.TEXT else DebuggerTheme.MUTED,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = ` {sliceCounts[slice] or 0} · {slice}`,
			[React.Event.Activated] = function()
				local next = table.clone(hiddenSlices)
				next[thisSlice] = not next[thisSlice]
				setHiddenSlices(next)
			end,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		})
	end
	if #allSlices == 0 then
		sidebarRows["empty"] = DebuggerTheme.line("(none)", DebuggerTheme.MUTED, 1)
	end

	-- MAIN table rows: one per player passing the search filter.
	local tableRows: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	local rowOrder = 0
	local query = string.lower(search)
	for _, player in players do
		local matches = query == ""
			or string.find(string.lower(player.name), query, 1, true) ~= nil
			or string.find(tostring(player.userId), query, 1, true) ~= nil
		if matches then
			rowOrder += 1
			local userId = player.userId
			local isSelected = effectiveSelected == userId

			local cells: { string } = { player.name, tostring(userId) }
			for _, slice in enabledSlices do
				local values = valueBySliceUser[slice]
				table.insert(cells, cellText(values and values[userId]))
			end

			tableRows[`p-{userId}`] = e("TextButton", {
				LayoutOrder = rowOrder,
				Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
				BackgroundColor3 = if isSelected then DebuggerTheme.ROW_SELECTED else DebuggerTheme.ROW,
				BackgroundTransparency = if isSelected then 0 else (if rowOrder % 2 == 0 then 0.5 else 0.8),
				BorderSizePixel = 0,
				Text = "",
				[React.Event.Activated] = function()
					setSelectedUserId(userId)
				end,
			}, rowCells(cells, columns, false))
		end
	end
	if rowOrder == 0 then
		tableRows["empty"] =
			DebuggerTheme.line(if #players == 0 then "no players" else "no matches", DebuggerTheme.MUTED, 0)
	end

	-- FLOATING detail window (Matter's "ENTITY n" panel): the selected player's slices as a
	-- Component/Data grid, then rate limits. Dragged by its title bar, resized by its corner grip.
	local selectedName = tostring(effectiveSelected)
	for _, player in players do
		if player.userId == effectiveSelected then
			selectedName = player.name
			break
		end
	end

	local detailChildren: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	if effectiveSelected == nil then
		detailChildren["none"] = DebuggerTheme.line("select a player", DebuggerTheme.MUTED, 0)
	else
		-- Slices as one collapsible tree (keyed by slice name) instead of TableView's one-level-deep
		-- grid — a slice with nested/array data (e.g. an inventory) stays fully inspectable instead of
		-- degrading into a truncated JSON blob past the first level.
		-- Every known slice always gets a visible row, even if this player has no value for it yet —
		-- `sliceData[slice] = values and values[effectiveSelected]` would drop the key entirely when
		-- the value is nil, silently hiding a not-yet-synced slice. A sentinel string keeps "absent"
		-- distinct from "nil", which matters for a debugger.
		local sliceData: { [string]: any } = {}
		for _, slice in allSlices do
			local values = valueBySliceUser[slice]
			local value = values and values[effectiveSelected]
			sliceData[slice] = if value ~= nil then value else DebuggerTheme.NIL_SENTINEL
		end
		detailChildren["slices"] = e(TreeView, {
			value = sliceData,
			layoutOrder = 1,
		})

		local rateRows: { TableView.Row } = {}
		for _, entry in rateLimits do
			if entry.userId == effectiveSelected then
				local tokensRemaining, capacity = entry.tokensRemaining, entry.capacity
				local tokens = if tokensRemaining ~= nil and capacity ~= nil
					then string.format("%.1f / %d tokens", tokensRemaining, capacity)
					else "no limit"
				table.insert(rateRows, { name = entry.action, value = `{tokens} · {entry.rejected} dropped` })
			end
		end
		if #rateRows > 0 then
			detailChildren["rates"] = e(TableView, {
				keyHeader = "Rate limit",
				valueHeader = "Bucket",
				rows = rateRows,
				layoutOrder = 2,
			})
		end
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		sidebar = e("ScrollingFrame", {
			Size = UDim2.new(0, SIDEBAR_WIDTH, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = DebuggerTheme.MUTED,
		}, sidebarRows),

		-- The table now spans the full tab height; the detail window floats above it (like Matter).
		main = e("Frame", {
			Position = UDim2.fromOffset(SIDEBAR_WIDTH + 8, 0),
			Size = UDim2.new(1, -(SIDEBAR_WIDTH + 8), 1, 0),
			BackgroundTransparency = 1,
		}, {
			search = e("TextBox", {
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundColor3 = DebuggerTheme.ROW,
				BorderSizePixel = 0,
				Font = Enum.Font.Code,
				TextSize = 12,
				TextColor3 = DebuggerTheme.TEXT,
				PlaceholderText = "filter players…",
				PlaceholderColor3 = DebuggerTheme.MUTED,
				Text = search,
				ClearTextOnFocus = false,
				[React.Change.Text] = function(rbx: TextBox)
					setSearch(rbx.Text)
				end,
			}, {
				corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
				pad = e("UIPadding", { PaddingLeft = UDim.new(0, 6) }),
			}),
			header = e(
				"Frame",
				{
					Position = UDim2.fromOffset(0, 26),
					Size = UDim2.new(1, 0, 0, 18),
					BackgroundColor3 = DebuggerTheme.PANEL_LIGHT,
					BorderSizePixel = 0,
				},
				rowCells(
					(function()
						local headers = { "Player", "Id" }
						for _, slice in enabledSlices do
							table.insert(headers, slice)
						end
						return headers
					end)(),
					columns,
					true
				)
			),
			list = e("ScrollingFrame", {
				Position = UDim2.fromOffset(0, 48),
				Size = UDim2.new(1, 0, 1, -48),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = DebuggerTheme.MUTED,
			}, tableRows),
		}),

		-- Floating detail window: docked bottom-left by default (offset by drag), sized by its grip.
		detail = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, SIDEBAR_WIDTH + 8 + detailOffset.X, 1, detailOffset.Y),
			Size = UDim2.fromOffset(detailSize.X, detailSize.Y),
			BackgroundColor3 = DebuggerTheme.PANEL,
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			stroke = e("UIStroke", { Color = DebuggerTheme.PANEL_LIGHT, Thickness = 1 }),
			pad = e("UIPadding", {
				PaddingTop = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
			}),
			-- Title bar doubles as the drag grip.
			titleBar = e("TextButton", {
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextColor3 = DebuggerTheme.ACCENT,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = if effectiveSelected then `PLAYER {selectedName} ({effectiveSelected})   ⠿` else "PLAYER —",
				[React.Event.InputBegan] = function(_rbx: TextButton, input: InputObject)
					beginDetailMove(input)
				end,
			}),
			scroll = e("ScrollingFrame", {
				Position = UDim2.fromOffset(0, 22),
				Size = UDim2.new(1, 0, 1, -22),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = DebuggerTheme.MUTED,
			}, detailChildren),
			grip = DebuggerTheme.resizeGrip(function(input: InputObject)
				beginDetailResize(input)
			end),
		}),
	})
end

return StatePanel
