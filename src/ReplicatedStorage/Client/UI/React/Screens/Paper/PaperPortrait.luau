--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local COLOR = require(script.Parent.UIPaperConstants).COLOR
local function PaperPortrait(props: { userId: number }): React.ReactNode
	local image, setImage = React.useState("")
	React.useEffect(function(): () -> ()
		local alive = true
		setImage("")
		task.spawn(function()
			local ok, content = pcall(function(): string
				local url = Players:GetUserThumbnailAsync(
					props.userId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size150x150
				)
				return url
			end)
			if alive and ok then
				setImage(content)
			end
		end)
		return function()
			alive = false
		end
	end, { props.userId })
	return React.createElement(
		"ImageLabel",
		{ Size = UDim2.fromScale(1, 1), Image = image, BackgroundColor3 = COLOR.cream, BorderSizePixel = 0 },
		{
			corner = React.createElement("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			stroke = React.createElement("UIStroke", { Color = COLOR.companyTeal, Thickness = 2 }),
		}
	)
end
return PaperPortrait
