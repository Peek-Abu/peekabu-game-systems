--!strict
--[=[
	CalloutStickerSystem: a sticker popping over a character's head (design §8): a BillboardGui on the head with the
	sticker's picture that pops in (scale bounce), wobbles, then fades, CalloutConstants.STICKER_SECONDS in all. A new
	sticker on the same character replaces the one showing. No sound (stickers are quiet).

	@class CalloutStickerSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CalloutConstants = require(ReplicatedStorage.Shared.Features.Callout.Data.CalloutConstants)

local NAME = "CalloutSticker"
-- Studs: the sticker's size and how far above the head's top it floats.
local SIZE = 2.6
local LIFT = 2.4

local CalloutStickerSystem = {
	NAME = NAME,
}

--[=[
	Shows `image` over `character`'s head (its HumanoidRootPart when it has no Head). Returns the BillboardGui, nil
	when the character has neither. `reducedMotion` skips the bounce and wobble.
]=]
function CalloutStickerSystem.show(character: Model, image: string, reducedMotion: boolean?): BillboardGui?
	local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
	if head == nil or not head:IsA("BasePart") then
		return nil
	end
	local old = head:FindFirstChild(NAME)
	if old ~= nil then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = NAME
	gui.Size = UDim2.fromScale(SIZE, SIZE)
	gui.StudsOffsetWorldSpace = Vector3.new(0, head.Size.Y / 2 + LIFT, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Adornee = head
	local picture = Instance.new("ImageLabel")
	picture.Name = "Picture"
	picture.Size = UDim2.fromScale(1, 1)
	picture.BackgroundTransparency = 1
	picture.Image = image
	picture.ScaleType = Enum.ScaleType.Fit
	picture.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = if reducedMotion then 1 else 0.2
	scale.Parent = picture
	gui.Parent = head

	local life = CalloutConstants.STICKER_SECONDS
	if not reducedMotion then
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
		picture.Rotation = -10
		TweenService:Create(
			picture,
			TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true),
			{ Rotation = 10 }
		):Play()
	end
	TweenService
		:Create(picture, TweenInfo.new(0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, life - 0.4), {
			ImageTransparency = 1,
		})
		:Play()
	task.delay(life, function()
		if gui.Parent ~= nil then
			gui:Destroy()
		end
	end)
	return gui
end

return CalloutStickerSystem
