--!strict
--[=[
	Panel: the shared surface-container primitive — a padded, bordered, rounded box with an optional
	title, the chrome most screens sit inside. Presentational only (no logic to spec); it draws itself
	from Tokens and hosts whatever `children` you hand it.

	Sizing, broad by default: fills its parent's width and grows to fit its content height. Pass `width`
	and/or `height` to fix either axis. The content region imposes NO layout — include your own
	`UIListLayout`/`UIGridLayout` (or absolute positioning) in `children`.

	@class Panel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)

local e = React.createElement

export type PanelProps = {
	title: string?,
	children: { [string]: React.ReactNode }?,
	width: number?,
	height: number?,
	layoutOrder: number?,
}

--[=[
	@param props PanelProps
	@return React.ReactNode
]=]
local function Panel(props: PanelProps): React.ReactNode
	-- Fill width + auto height by default; fix either axis if asked. Explicit branches so the optional
	-- width/height narrow cleanly under --!strict.
	local width = props.width
	local height = props.height
	local size: UDim2
	local autoSize: Enum.AutomaticSize
	if width ~= nil and height ~= nil then
		size = UDim2.fromOffset(width, height)
		autoSize = Enum.AutomaticSize.None
	elseif width ~= nil then
		size = UDim2.fromOffset(width, 0)
		autoSize = Enum.AutomaticSize.Y
	elseif height ~= nil then
		size = UDim2.new(1, 0, 0, height)
		autoSize = Enum.AutomaticSize.None
	else
		size = UDim2.fromScale(1, 0)
		autoSize = Enum.AutomaticSize.Y
	end

	-- The content region: hosts the caller's children with its own auto-height; the caller supplies
	-- the internal layout.
	local content: { [string]: React.ReactNode } = {}
	if props.children ~= nil then
		for key, node in props.children do
			content[key] = node
		end
	end

	local panelChildren: { [string]: React.ReactNode } = {
		corner = e("UICorner", { CornerRadius = UDim.new(0, Tokens.radius.lg) }),
		stroke = e("UIStroke", { Color = Tokens.color.border, Thickness = Tokens.stroke.thin }),
		padding = e("UIPadding", {
			PaddingTop = UDim.new(0, Tokens.space.md),
			PaddingBottom = UDim.new(0, Tokens.space.md),
			PaddingLeft = UDim.new(0, Tokens.space.md),
			PaddingRight = UDim.new(0, Tokens.space.md),
		}),
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, Tokens.space.sm),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		body = e("Frame", {
			LayoutOrder = 2,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, content),
	}

	if props.title ~= nil then
		panelChildren.titleLabel = e("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, Tokens.textSize.lg + Tokens.space.xs),
			BackgroundTransparency = 1,
			Font = Tokens.font.bold,
			TextSize = Tokens.textSize.lg,
			TextColor3 = Tokens.color.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = props.title,
		})
	end

	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = size,
		AutomaticSize = autoSize,
		BackgroundColor3 = Tokens.color.surface,
		BorderSizePixel = 0,
	}, panelChildren)
end

return Panel
