--!strict
--[=[
	TableView: a structured key/value grid — the Matter-debugger-style alternative to a JSON blob.

	Renders a header row ("Component | Data" style) and one row per entry. A value that is itself a
	table is expanded one level deep, each field on its own line (`goal = Vector3(-500, 500, -500)`),
	instead of being serialized into one long JSON string; deeper nesting falls back to the compact
	serializer. Reused anywhere a table needs inspecting: the State tab's entity detail (one row per
	slice) and the Services tab's expanded getState (one row per state field).

	@class TableView
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local theme = require(ReplicatedStorage.Client.UI.React.Debugger.theme)

local e = React.createElement

local KEY_COLUMN_WIDTH = 110

export type Row = {
	name: string,
	value: any,
}

export type Props = {
	keyHeader: string,
	valueHeader: string,
	rows: { Row },
	layoutOrder: number?,
}

--[=[
	Renders a value for the Data column. Tables expand one level deep, one `field = value` line each
	(array entries as `[i] = value`), sorted for a stable display; scalars go through the serializer.
	@param value any
	@return string
]=]
local function renderValue(value: any): string
	if typeof(value) ~= "table" then
		return theme.serialize(value)
	end

	local lines: { string } = {}
	if #value > 0 then
		for index, item in ipairs(value) do
			table.insert(lines, `[{index}] = {theme.serialize(item)}`)
		end
	else
		for key, item in pairs(value) do
			table.insert(lines, `{tostring(key)} = {theme.serialize(item)}`)
		end
		table.sort(lines)
	end

	if #lines == 0 then
		return "{}"
	end
	return table.concat(lines, "\n")
end

--[=[
	One grid row: fixed-width key cell, auto-height value cell.
	@param row Row
	@param order number
	@param striped boolean -- Alternate-row background for readability
	@return React.ReactNode
]=]
local function gridRow(row: Row, order: number, striped: boolean): React.ReactNode
	return e("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = theme.ROW,
		BackgroundTransparency = if striped then 0.5 else 0.8,
		BorderSizePixel = 0,
	}, {
		key = e("TextLabel", {
			Size = UDim2.fromOffset(KEY_COLUMN_WIDTH, 18),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 13,
			TextColor3 = theme.ACCENT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = ` {row.name}`,
		}),
		value = e("TextLabel", {
			Position = UDim2.fromOffset(KEY_COLUMN_WIDTH + 6, 0),
			Size = UDim2.new(1, -(KEY_COLUMN_WIDTH + 6), 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 13,
			TextColor3 = theme.TEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			Text = renderValue(row.value),
		}),
	})
end

--[=[
	The TableView component: header row + striped entry rows, auto-height (embed inside a scroller).
	@param props Props
	@return React.ReactNode
]=]
local function TableView(props: Props): React.ReactNode
	local children: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		header = e("Frame", {
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundColor3 = theme.PANEL_LIGHT,
			BorderSizePixel = 0,
		}, {
			key = e("TextLabel", {
				Size = UDim2.new(0, KEY_COLUMN_WIDTH, 1, 0),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextColor3 = theme.TEXT,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = ` {props.keyHeader}`,
			}),
			value = e("TextLabel", {
				Position = UDim2.fromOffset(KEY_COLUMN_WIDTH + 6, 0),
				Size = UDim2.new(1, -(KEY_COLUMN_WIDTH + 6), 1, 0),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextColor3 = theme.TEXT,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = props.valueHeader,
			}),
		}),
	}

	for index, row in props.rows do
		children[`row-{row.name}-{index}`] = gridRow(row, index, index % 2 == 0)
	end
	if #props.rows == 0 then
		children["empty"] = theme.line("(empty)", theme.MUTED, 1)
	end

	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, children)
end

return TableView
