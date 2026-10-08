--!strict
--[=[
	CurrencyTransfer: the bank's coin strip — an amount field and four verbs, on the authored
	`TransferCoinMenu` art.

	**This is the ONE place a quantity is real.** Items move as whole holdings (bank design Decision 4),
	so nothing else on this screen has an amount control; currency does, because `depositCurrency` takes
	one. Splitting the two apart in the UI is not a style choice — a partial ITEM transfer is a server
	verb that does not exist.

	"Deposit all" sends the full balance rather than being a fifth verb, so the server keeps exactly one
	currency path to reason about. That means the button is only as accurate as the last sync, which is
	fine: the server clamps to what is actually there, and a stale "all" is refused rather than
	over-drawing.

	**The amount field accepts digits only, and is filtered as you type** rather than validated on
	submit. A field that lets you type "12x" and then refuses is a worse trade than one that never holds
	an unusable value — and the packet's `uint32` cannot carry a negative anyway, so a minus sign is
	meaningless before it ever reaches the wire.

	Presentational: it reads no state and calls no service. Balances and handlers come from `BankPanel`.

	@class CurrencyTransfer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)

local e = React.createElement

-- The strip and its title, as fractions of the screen, off the authored `BankerMenu`.
local TITLE_POSITION = UDim2.fromScale(0.46, 0.196)
local TITLE_SIZE = UDim2.fromScale(0.086, 0.044)
local STRIP_POSITION = UDim2.fromScale(0.423, 0.231)
local STRIP_SIZE = UDim2.fromScale(0.163, 0.164)
local STRIP_TINT = Color3.fromRGB(193, 193, 193) -- the authored flat grey over the plate

-- Inside the strip, as fractions of it.
local BACKING_POSITION = UDim2.fromScale(0.019, 0.392)
local BACKING_SIZE = UDim2.fromScale(0.949, 0.498)
local WELL_POSITION = UDim2.fromScale(0.364, 0.214)
local WELL_SIZE = UDim2.fromScale(0.272, 0.182)
local BUTTON_SIZE = UDim2.fromScale(0.441, 0.161)
local BUTTON_LEFT_X = 0.047
local BUTTON_RIGHT_X = 0.503
local BUTTON_TOP_Y = 0.46
local BUTTON_BOTTOM_Y = 0.669

-- Inside the amount well.
local WELL_ICON_POSITION = UDim2.fromScale(-0.241, -0.604)
local WELL_ICON_SIZE = UDim2.fromScale(0.223, 0.504)
local WELL_LABEL_POSITION = UDim2.fromScale(0.052, -0.549)
local WELL_LABEL_SIZE = UDim2.fromScale(1.169, 0.467)
local WELL_FIELD_POSITION = UDim2.fromScale(0.02, 0.008)
local WELL_FIELD_SIZE = UDim2.fromScale(0.939, 0.992)

local TITLE_TEXT = "TRANSFER COIN"
local FIELD_COLOR = Color3.fromRGB(255, 231, 190) -- the authored warm coin tint
local LABEL_COLOR = Color3.fromRGB(255, 233, 202)

local PLATE_ZINDEX = 1
local CONTENT_ZINDEX = 2

export type CurrencyTransferProps = {
	currencyType: CurrencyConstants.CurrencyType,
	-- The two balances, for the "all" verbs and nothing else — the strip never displays them itself
	-- (each side's own CoinCounter does).
	bagAmount: number,
	bankAmount: number,
	onDeposit: (amount: number) -> (),
	onWithdraw: (amount: number) -> (),
	-- The rung this strip sits on in BankPanel's screen-level ladder (see the rooted Frame below).
	zIndex: number?,
}

--[=[
	@param props CurrencyTransferProps
	@return React.ReactNode
]=]
local function CurrencyTransfer(props: CurrencyTransferProps): React.ReactNode
	-- The typed amount, held as TEXT: an empty field is a real state, and a number cannot represent it.
	local amountText, setAmountText = React.useState("")
	-- Clamped, not merely digits-only: the packet's `uint32` is written with `buffer.writeu32`, which
	-- does no range check, so anything past 2^32-1 was silently truncated MOD 2^32 on the wire. Typing
	-- 4294967796 — ten keystrokes — sent the server a deposit of 500. MAX_CURRENCY is the real ceiling
	-- any balance can reach, so clamping there refuses the impossible amount instead of transmuting it.
	local amount = math.min(tonumber(amountText) or 0, CurrencyConstants.MAX_CURRENCY)

	--[=[
		One transfer button on the authored plate.
		@param label string
		@param x number -- left edge, as a fraction of the strip
		@param y number -- top edge, as a fraction of the strip
		@param onClick () -> ()
		@return React.ReactNode
	]=]
	local function button(label: string, x: number, y: number, onClick: () -> ()): React.ReactNode
		return e("ImageLabel", {
			Position = UDim2.fromScale(x, y),
			Size = BUTTON_SIZE,
			BackgroundTransparency = 1,
			Image = UIAssets.bank.buttonPlate,
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = CONTENT_ZINDEX,
		}, {
			hit = e("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Font = Tokens.font.bold,
				TextScaled = true,
				TextColor3 = Tokens.color.text,
				Text = label,
				AutoButtonColor = false,
				[React.Event.Activated] = onClick,
			}),
		})
	end

	local definition = CurrencyConstants.getCurrencyDefinition(props.currencyType)

	local strip: { [string]: React.ReactNode } = {
		plate = e("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = UIAssets.bank.menuPlate,
			ImageColor3 = STRIP_TINT,
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = PLATE_ZINDEX,
		}),
		-- A strip of the button plate behind the four buttons, as authored.
		backing = e("ImageLabel", {
			Position = BACKING_POSITION,
			Size = BACKING_SIZE,
			BackgroundTransparency = 1,
			Image = UIAssets.bank.buttonPlate,
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = PLATE_ZINDEX,
		}),
		well = e("ImageLabel", {
			Position = WELL_POSITION,
			Size = WELL_SIZE,
			BackgroundTransparency = 1,
			Image = UIAssets.bank.coinWell,
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = CONTENT_ZINDEX,
		}, {
			icon = e("ImageLabel", {
				Position = WELL_ICON_POSITION,
				Size = WELL_ICON_SIZE,
				BackgroundTransparency = 1,
				Image = UIAssets.bank.coinIcon,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = CONTENT_ZINDEX,
			}),
			label = e("TextLabel", {
				Position = WELL_LABEL_POSITION,
				Size = WELL_LABEL_SIZE,
				BackgroundTransparency = 1,
				Font = Tokens.font.bold,
				TextScaled = true,
				TextColor3 = LABEL_COLOR,
				-- The registry's display name, not the id: "Jaku" is data, "jaku" is a key.
				Text = `{string.upper(definition.name)} AMOUNT`,
				ZIndex = CONTENT_ZINDEX,
			}),
			field = e("TextBox", {
				Position = WELL_FIELD_POSITION,
				Size = WELL_FIELD_SIZE,
				BackgroundTransparency = 1,
				Font = Tokens.font.bold,
				TextScaled = true,
				TextColor3 = FIELD_COLOR,
				TextXAlignment = Enum.TextXAlignment.Center,
				Text = amountText,
				PlaceholderText = "0",
				PlaceholderColor3 = FIELD_COLOR,
				ClearTextOnFocus = false,
				ZIndex = CONTENT_ZINDEX,
				[React.Change.Text] = function(rbx: TextBox)
					-- Digits only, filtered as typed (see the header). Assigning back is what makes the
					-- rejected character never appear, rather than appearing and then being taken away.
					local digits = string.gsub(rbx.Text, "%D", "")
					setAmountText(digits)
					rbx.Text = digits
				end,
			}),
		}),
	}

	-- The typed amount is only meaningful when it is positive; "all" ignores the field entirely.
	strip.deposit = button("DEPOSIT", BUTTON_LEFT_X, BUTTON_TOP_Y, function()
		if amount > 0 then
			props.onDeposit(amount)
		end
	end)
	strip.withdraw = button("WITHDRAW", BUTTON_RIGHT_X, BUTTON_TOP_Y, function()
		if amount > 0 then
			props.onWithdraw(amount)
		end
	end)
	strip.depositAll = button("DEPOSIT ALL", BUTTON_LEFT_X, BUTTON_BOTTOM_Y, function()
		if props.bagAmount > 0 then
			props.onDeposit(props.bagAmount)
		end
	end)
	strip.withdrawAll = button("WITHDRAW ALL", BUTTON_RIGHT_X, BUTTON_BOTTOM_Y, function()
		if props.bankAmount > 0 then
			props.onWithdraw(props.bankAmount)
		end
	end)

	-- Rooted in a Frame rather than returned as a Fragment. A Fragment has no instance, so `title` and
	-- `strip` became direct siblings of BankPanel's own children while still carrying THIS module's
	-- private ladder (PLATE=1 / CONTENT=2) — below BankPanel's CONTENT_ZINDEX of 3. Nothing overlaps the
	-- strip today, but the moment a plate widened into it the opaque backdrop would have drawn over these
	-- buttons while leaving them clickable (an ImageLabel does not sink input): DEPOSIT and WITHDRAW
	-- firing from a blank patch of plate. The Frame is full-size and transparent, so every child's
	-- `fromScale` position is unchanged.
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
	}, {
		title = e("ImageLabel", {
			Position = TITLE_POSITION,
			Size = TITLE_SIZE,
			BackgroundTransparency = 1,
			Image = UIAssets.bank.buttonPlate,
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = CONTENT_ZINDEX,
		}, {
			label = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Font = Tokens.font.bold,
				TextScaled = true,
				TextColor3 = Tokens.color.text,
				Text = TITLE_TEXT,
			}),
		}),
		strip = e("Frame", {
			Position = STRIP_POSITION,
			Size = STRIP_SIZE,
			BackgroundTransparency = 1,
			ZIndex = CONTENT_ZINDEX,
		}, strip),
	})
end

return CurrencyTransfer
