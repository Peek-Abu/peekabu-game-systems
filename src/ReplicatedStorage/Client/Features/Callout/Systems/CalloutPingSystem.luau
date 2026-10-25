--!strict
--[=[
	CalloutPingSystem: a ping's marker in the world (design §8): an invisible anchored point at the spot with a
	BillboardGui that always shows on top (the ping's icon, its word and who sent it), CalloutConstants.PING_SECONDS
	long. One marker per sender: a new ping from the same player moves it.

	@class CalloutPingSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CalloutConstants = require(ReplicatedStorage.Shared.Features.Callout.Data.CalloutConstants)

local CalloutPingSystem = {}

-- What a marker shows.
export type Marker = { userId: number, image: string, word: string, who: string, at: Vector3 }

local INK = Color3.fromHex("1E0F3A")

local function label(parent: Instance, name: string, text: string, y: number, height: number)
	local line = Instance.new("TextLabel")
	line.Name = name
	line.BackgroundTransparency = 1
	line.Position = UDim2.fromOffset(0, y)
	line.Size = UDim2.new(1, 0, 0, height)
	line.Font = Enum.Font.LuckiestGuy
	line.Text = text
	line.TextScaled = true
	line.TextColor3 = Color3.new(1, 1, 1)
	line.TextStrokeColor3 = INK
	line.TextStrokeTransparency = 0
	line.Parent = parent
end

--[=[
	Shows a marker under `parent` (a folder in the workspace) and returns its anchor part. It removes itself after
	PING_SECONDS.
]=]
function CalloutPingSystem.show(parent: Instance, marker: Marker): BasePart
	local name = `Ping{marker.userId}`
	local old = parent:FindFirstChild(name)
	if old ~= nil then
		old:Destroy()
	end
	local point = Instance.new("Part")
	point.Name = name
	point.Anchored = true
	point.CanCollide = false
	point.CanQuery = false
	point.CanTouch = false
	point.Transparency = 1
	point.Size = Vector3.new(0.2, 0.2, 0.2)
	point.Position = marker.at
	local gui = Instance.new("BillboardGui")
	gui.Name = "Marker"
	gui.Size = UDim2.fromOffset(150, 120)
	gui.StudsOffset = Vector3.new(0, 1.5, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = point
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.fromScale(0.5, 0)
	icon.Size = UDim2.fromOffset(64, 64)
	icon.Image = marker.image
	icon.Parent = gui
	label(gui, "Word", marker.word, 66, 28)
	label(gui, "Who", marker.who, 94, 20)
	gui.Parent = point
	point.Parent = parent
	task.delay(CalloutConstants.PING_SECONDS, function()
		if point.Parent ~= nil then
			point:Destroy()
		end
	end)
	return point
end

return CalloutPingSystem
