--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local VM = require(script.Parent.PaperPropViewModel)
local C = require(script.Parent.UIPaperConstants).COLOR
local COLORS: { [string]: Color3 } = {
	ink = C.ink,
	cork = C.cork,
	cream = C.cream,
	companyTeal = C.companyTeal,
	manila = C.manila,
	manilaDeep = C.manilaDeep,
	stamp = C.stamp,
	inkGreen = C.inkGreen,
}
local function PaperPropIcon(props: { kind: VM.Kind }): React.ReactNode
	local nodes: { [string]: React.ReactNode } = {}
	for index, part in VM.shapes(props.kind) do
		nodes[tostring(index)] = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale((part.x + part.w / 2) / 64, (part.y + part.h / 2) / 64),
			Size = UDim2.fromScale(part.w / 64, part.h / 64),
			Rotation = part.rotation,
			BackgroundColor3 = COLORS[part.color],
			BorderSizePixel = 0,
			ZIndex = index + 3,
		}, { corner = React.createElement("UICorner", { CornerRadius = UDim.new(part.round / 2, 0) }) })
	end
	return React.createElement("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, nodes)
end
return PaperPropIcon
