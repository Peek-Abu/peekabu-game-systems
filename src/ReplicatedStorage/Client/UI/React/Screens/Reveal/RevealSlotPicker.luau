--!strict
--[=[
	RevealSlotPicker: the small picker the reveal's Add to wheel! / Use stickers! opens over the reveal (owner 11-14:
	a small on-screen panel, never a whole new menu). A dim over the reveal, and a cream panel in the middle:
	- `wheel`: the emote's wheel, its 4 slots in a row (what is in each; the emote's own slot in gold). Tapping a slot
	  puts the emote there; a slot holding another emote asks first (RevealViewModel.swapQuestion: Yes! / No), then the
	  panel closes.
	- `stickers`: the pack's stickers in a row and your 4 sticker spots under them: tap a sticker, then a spot, for
	  as many as you like; Done closes.
	The slots and stickers are the Inventory's own (RevealViewModel.wheel / .stickers over InventoryViewModel).
	Presentational (exempt; values specced in RevealViewModel).

	@class RevealSlotPicker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)
local InventoryViewModel = require(script.Parent.Parent.Inventory.InventoryViewModel)
local VM = require(script.Parent.RevealViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH

type Nodes = { [string]: React.ReactNode }

export type RevealSlotPickerProps = {
	phone: boolean,
	picker: VM.Picker,
	-- The emote or the pack being placed (its name for the title and the swap question).
	name: string,
	-- `wheel`: the emote's wheel slots; `stickers`: the pack's stickers and your spots.
	wheel: { InventoryViewModel.WheelSlot }?,
	stickers: VM.StickerPick?,
	onWheel: (slot: number) -> (),
	onSticker: (id: string, slot: number) -> (),
	onClose: () -> (),
}

local function picture(image: string?, size: number): React.ReactNode
	if image == nil then
		return nil
	end
	return e("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Image = image,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 4,
	})
end

-- A label inside a square button: its words along the bottom.
local function under(text: string, size: number): React.ReactNode
	return e(ToonText, {
		text = text,
		textSize = size,
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -DEPTH.lip - 4),
		size = UDim2.new(1, -10, 0, size + 2),
		align = "center",
		fit = true,
		zIndex = 5,
	})
end

local function RevealSlotPicker(props: RevealSlotPickerProps): React.ReactNode
	local phone = props.phone
	-- `wheel`: the slot waiting on its swap question (lazy initialisers, so the states are typed number? / string?).
	local asking, setAsking = React.useState(function(): number?
		return nil
	end)
	-- `stickers`: the sticker tapped, waiting for a spot.
	local chosen, setChosen = React.useState(function(): string?
		return nil
	end)

	local width = if phone then 340 else 640
	local text = if phone then 15 else 26
	local small = if phone then 11 else 18
	local pad = if phone then 14 else 26
	local inner = width - 2 * pad
	local face: Nodes = {}
	local y = pad
	local function line(key: string, words: string, textSize: number, meaning: UIToonConstants.Meaning?)
		face[key] = e(ToonText, {
			text = words,
			textSize = textSize,
			meaning = meaning,
			font = if meaning == nil then "body" else nil,
			color = if meaning == nil then COLOR.ink else nil,
			position = UDim2.fromOffset(pad, y),
			size = UDim2.fromOffset(inner, textSize + 6),
			align = "center",
			fit = true,
		})
		y += textSize + 12
	end

	if props.picker == "wheel" then
		local slots: { InventoryViewModel.WheelSlot } = props.wheel or {}
		local ask = if asking ~= nil and slots[asking] ~= nil then VM.swapQuestion(slots[asking], props.name) else nil
		line("title", "PICK A SLOT", text + 8, "grape")
		if ask ~= nil and asking ~= nil then
			local slot = asking
			line("question", ask, text, nil)
			local buttonWidth = math.floor((inner - 16) / 2)
			local buttonHeight = if phone then 40 else 64
			face.yes = e(ToonButton, {
				variant = "primary",
				text = "Yes!",
				textSize = text,
				sound = "cta",
				position = UDim2.fromOffset(pad, y),
				size = UDim2.fromOffset(buttonWidth, buttonHeight),
				onActivated = function()
					setAsking(nil)
					props.onWheel(slot)
					props.onClose()
				end,
			})
			face.no = e(ToonButton, {
				variant = "secondary",
				text = "No",
				textSize = text,
				sound = "back",
				position = UDim2.fromOffset(pad + buttonWidth + 16, y),
				size = UDim2.fromOffset(buttonWidth, buttonHeight),
				onActivated = function()
					setAsking(nil)
				end,
			})
			y += buttonHeight + DEPTH.drop + pad
		else
			line("hint", `Tap a slot for {props.name}.`, small + 2, nil)
			local count = math.max(1, #slots)
			local gap = 10
			local slotWidth = math.floor((inner - (count - 1) * gap) / count)
			local slotHeight = if phone then 52 else 84
			for index, slot in slots do
				face[`slot{index}`] = e(ToonButton, {
					variant = if slot.mine then "gleam" elseif slot.empty then "secondary" else "grape",
					selected = slot.mine,
					text = `{slot.slot}  {slot.name}`,
					textSize = small,
					position = UDim2.fromOffset(pad + (index - 1) * (slotWidth + gap), y),
					size = UDim2.fromOffset(slotWidth, slotHeight),
					onActivated = function()
						if slot.mine then
							props.onClose()
						elseif VM.swapQuestion(slot, props.name) ~= nil then
							setAsking(index)
						else
							props.onWheel(slot.slot)
							props.onClose()
						end
					end,
				})
			end
			y += slotHeight + DEPTH.drop + 14
			local closeHeight = if phone then 34 else 54
			face.close = e(ToonButton, {
				variant = "secondary",
				text = "Not now",
				textSize = small + 2,
				sound = "back",
				anchor = Vector2.new(0.5, 0),
				position = UDim2.new(0.5, 0, 0, y),
				size = UDim2.fromOffset(math.floor(inner * 0.4), closeHeight),
				onActivated = props.onClose,
			})
			y += closeHeight + DEPTH.drop + pad
		end
	else
		local pick: VM.StickerPick = props.stickers or { slots = {}, stickers = {} }
		line("title", "PLACE YOUR STICKERS", text + 8, "grape")
		line("hint", if chosen == nil then "Tap a sticker, then a spot." else "Now tap a spot for it.", small + 2, nil)
		local gap = 10
		local tile = math.floor((inner - 3 * gap) / 4)
		for index, sticker in pick.stickers do
			face[`sticker{index}`] = e(ToonButton, {
				variant = if chosen == sticker.id then "gleam" else "secondary",
				selected = chosen == sticker.id,
				content = {
					picture = picture(sticker.image, math.floor(tile * 0.6)),
					name = under(sticker.name, small),
				},
				position = UDim2.fromOffset(pad + (index - 1) * (tile + gap), y),
				size = UDim2.fromOffset(tile, tile),
				onActivated = function()
					setChosen(if chosen == sticker.id then nil else sticker.id)
				end,
			})
		end
		y += tile + DEPTH.drop + 12
		line("spots", "YOUR SPOTS", small + 4, "grape")
		for index, slot in pick.slots do
			local id = chosen
			local spot: Nodes = {
				number = e(ToonText, {
					text = tostring(slot.slot),
					textSize = small,
					position = UDim2.fromOffset(8, 4),
					size = UDim2.fromOffset(24, small + 2),
					zIndex = 5,
				}),
				picture = picture(slot.image, math.floor(tile * 0.5)),
				name = under(slot.name, small),
			}
			face[`spot{index}`] = e(ToonButton, {
				variant = if slot.empty then "night" else "grape",
				disabled = id == nil,
				content = spot,
				position = UDim2.fromOffset(pad + (index - 1) * (tile + gap), y),
				size = UDim2.fromOffset(tile, tile),
				onActivated = function()
					if id ~= nil then
						props.onSticker(id, slot.slot)
						setChosen(nil)
					end
				end,
			})
		end
		y += tile + DEPTH.drop + 14
		local doneHeight = if phone then 40 else 64
		face.done = e(ToonButton, {
			variant = "primary",
			text = "Done",
			textSize = text,
			sound = "cta",
			anchor = Vector2.new(0.5, 0),
			position = UDim2.new(0.5, 0, 0, y),
			size = UDim2.fromOffset(math.floor(inner * 0.45), doneHeight),
			onActivated = props.onClose,
		})
		y += doneHeight + DEPTH.drop + pad
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 40,
	}, {
		-- The dim: the reveal stays visible behind it, and it takes the clicks the panel does not.
		dim = e("TextButton", {
			-- Past every edge of the scaled frame, so the strip above it (the top bar's room) is dimmed too.
			Position = UDim2.fromOffset(-400, -400),
			Size = UDim2.new(1, 800, 1, 800),
			BackgroundColor3 = COLOR.ink,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 40,
		}),
		panel = e(ToonSurface, {
			hue = "cream",
			radius = 26,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.5),
			size = UDim2.fromOffset(width, y),
			zIndex = 41,
			children = face,
		}),
	})
end

return RevealSlotPicker
