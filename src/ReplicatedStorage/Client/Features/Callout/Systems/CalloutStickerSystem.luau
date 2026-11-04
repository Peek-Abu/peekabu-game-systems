--!strict
--[=[
	CalloutStickerSystem: a thrown sticker (design §8; owner, 2026-11-04): a BillboardGui with the sticker's picture on
	an anchored, invisible anchor. It leaves the throwing hand (`from`), grows as it flies up and away for
	CalloutConstants.STICKER_FLIGHT seconds to the spot the server pinned (above and ahead of the sender as they sent
	it), and floats free there: it stays while its sender walks or jumps on, drifts up CalloutConstants.STICKER_RISE,
	wobbles, then fades, CalloutConstants.STICKER_SECONDS in all. A new sticker from the same sender replaces theirs
	still showing. No sound (stickers are quiet).

	@class CalloutStickerSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CalloutConstants = require(ReplicatedStorage.Shared.Features.Callout.Data.CalloutConstants)

local NAME = "CalloutSticker"
-- Studs: the sticker's size.
local SIZE = 2.6

local CalloutStickerSystem = {
	NAME = NAME,
}

--[=[
	Shows `image` for the sender `userId`, thrown from `from` (their hand; nil: it appears at its spot) to `at`, its
	anchor in `folder`. Returns the BillboardGui. `reducedMotion` skips the flight, bounce, drift and wobble.
]=]
function CalloutStickerSystem.show(
	folder: Instance,
	userId: number,
	at: Vector3,
	image: string,
	reducedMotion: boolean?,
	from: Vector3?
): BillboardGui
	local key = `{NAME}_{userId}`
	local old = folder:FindFirstChild(key)
	if old ~= nil then
		old:Destroy()
	end
	local anchor = Instance.new("Part")
	anchor.Name = key
	anchor.Size = Vector3.one * 0.2
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	local start = if reducedMotion or from == nil then at else from
	anchor.Position = start

	local gui = Instance.new("BillboardGui")
	gui.Name = NAME
	gui.Size = UDim2.fromScale(SIZE, SIZE)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Adornee = anchor
	local picture = Instance.new("ImageLabel")
	picture.Name = "Picture"
	picture.Size = UDim2.fromScale(1, 1)
	picture.BackgroundTransparency = 1
	picture.Image = image
	picture.ScaleType = Enum.ScaleType.Fit
	picture.Parent = gui
	local scale = Instance.new("UIScale")
	-- Hand-sized as it leaves the hand, so the throw reads; a sticker with no flight pops up from small.
	scale.Scale = if reducedMotion then 1 elseif start ~= at then 0.45 else 0.2
	scale.Parent = picture
	gui.Parent = anchor
	anchor.Parent = folder

	local life = CalloutConstants.STICKER_SECONDS
	if not reducedMotion then
		local flight = if start ~= at then CalloutConstants.STICKER_FLIGHT else 0
		TweenService
			:Create(scale, TweenInfo.new(flight + 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
		local fly = TweenService:Create(
			anchor,
			TweenInfo.new(flight, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ Position = at }
		)
		local drift = TweenService:Create(
			anchor,
			TweenInfo.new(life - flight, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = at + Vector3.new(0, CalloutConstants.STICKER_RISE, 0) }
		)
		if flight > 0 then
			fly.Completed:Once(function(state)
				if state == Enum.PlaybackState.Completed then
					drift:Play()
				end
			end)
			fly:Play()
		else
			drift:Play()
		end
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
		if anchor.Parent ~= nil then
			anchor:Destroy()
		end
	end)
	return gui
end

return CalloutStickerSystem
