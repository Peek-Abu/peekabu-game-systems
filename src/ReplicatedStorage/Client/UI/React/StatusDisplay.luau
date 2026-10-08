--!strict
--[=[
	StatusDisplay: how an item STATUS reads — its line on the detail card, the tints and gradients that
	dress the card and slot, and which parts of the item it hides. Sits beside `RarityDisplay` and
	`StatDisplay` for the same reason: the status is domain, how it looks is not.

	`obscure` is real logic, not dressing, so it is specced like any other pure function — the exemption
	list is for modules that only map props to instances.

	⚠ **PREVIEW — NOT WIRED TO ANY DATA.** Nothing stores an item status; `ItemDetail` takes one as a PROP
	so the treatment can be judged before the data shape is settled. See the handover note in `ItemDetail`.

	**Why this is a style table rather than a second card.** The authored game ships `ItemInfoRotbound` as
	a full duplicate of `ItemInfo` — same rects, same aspect, same layers, every child merely RENAMED
	(`NameLabel`→`ItemName`, `ItemInfoFrame`→`FrameBackground`, `RarityBarItemInfo`→`Rarity`, and so on).
	Nothing about the layout differs; only the dressing does. Duplicating the card here would duplicate
	every region constant with it and guarantee the two drift, so the card stays single and reads its
	dressing from here.

	The authored game has exactly two states and treats BIND ON EQUIP as the default, so this models the
	exception rather than an enum with a boring member: `nil` is an ordinary item.

	@class StatusDisplay
]=]

local StatusDisplay = {}

export type Status = "rotbound"

--[=[
	One status's presentation. Every field is something the card or slot reads directly.
	@interface StatusStyle
	.label string -- the card's status line, already phrased
	.overlayTint Color3 -- tint for the card's full-bleed overlay
	.overlayTransparency number -- how strongly that overlay reads
	.overlayGradient ColorSequence -- colours across that overlay
	.overlayFalloff NumberSequence -- and its transparency, which is what keeps it to the card's edges
	.overlayRotation number
	.textGradient ColorSequence -- laid over obscured text and the card's backing
	.slotTint Color3 -- tint for the same treatment on an item SLOT
	.slotTransparency number
	.descriptionColor Color3 -- the description's colour under this status
	.statusColor Color3 -- the status line's own colour
	.obscuresDetail boolean -- whether the item's description and stat list are hidden
]=]
export type StatusStyle = {
	label: string,
	overlayTint: Color3,
	overlayTransparency: number,
	overlayGradient: ColorSequence,
	overlayFalloff: NumberSequence,
	overlayRotation: number,
	textGradient: ColorSequence,
	slotTint: Color3,
	slotTransparency: number,
	descriptionColor: Color3,
	statusColor: Color3,
	obscuresDetail: boolean,
}

-- The authored `RotBoundTextGradient`, in its two forms.
--
-- The 0-degree one is laid over the card's backing and every obscured label — 16 copies of it in the
-- authored tree, which is what makes rotbound read as one treatment rather than a recolour.
local ROTBOUND_TEXT_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(159, 145, 191)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(187, 205, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(243, 185, 255)),
	ColorSequenceKeypoint.new(0.74, Color3.fromRGB(189, 226, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(166, 128, 190)),
})

-- The 90-degree one dresses the card's overlay. Its transparency is the important part: opaque only at
-- the very top and bottom and fully clear between, so the overlay bleeds in from the card's edges rather
-- than washing the whole thing purple.
local ROTBOUND_OVERLAY_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(51, 38, 191)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(191, 145, 182)),
})
local ROTBOUND_OVERLAY_FALLOFF = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.24),
	NumberSequenceKeypoint.new(0.2, 1),
	NumberSequenceKeypoint.new(0.79, 1),
	NumberSequenceKeypoint.new(1, 0),
})

local STYLES: { [string]: StatusStyle } = {
	rotbound = {
		label = "ITEM IS ROTBOUND",
		overlayTint = Color3.fromRGB(148, 153, 255),
		overlayTransparency = 0.25,
		overlayGradient = ROTBOUND_OVERLAY_GRADIENT,
		overlayFalloff = ROTBOUND_OVERLAY_FALLOFF,
		overlayRotation = 90,
		textGradient = ROTBOUND_TEXT_GRADIENT,
		slotTint = Color3.fromRGB(168, 96, 255),
		slotTransparency = 0.2,
		descriptionColor = Color3.fromRGB(233, 194, 255),
		statusColor = Color3.fromRGB(236, 197, 255),
		obscuresDetail = true,
	},
}

-- What an ordinary item shows. The authored game has no flag for this: it is simply what you get when an
-- item is not rotbound.
local DEFAULT_LABEL = "ITEM IS BIND ON EQUIP"

--[=[
	The presentation for a status, or nil for an ordinary item.
	@param status Status?
	@return StatusStyle?
]=]
function StatusDisplay.style(status: Status?): StatusStyle?
	if status == nil then
		return nil
	end
	return STYLES[status]
end

--[=[
	The card's status line for an item, which every item has.
	@param status Status?
	@return string
]=]
function StatusDisplay.label(status: Status?): string
	local style = StatusDisplay.style(status)
	if style == nil then
		return DEFAULT_LABEL
	end
	return style.label
end

-- The authored obscured text is not a symbol soup: every character is a HYPHEN carrying a stack of
-- combining diacritics, which renders as corrupted, bleeding glyphs. The marks are transcribed from
-- those used across `ItemInfoRotbound`'s description and stat rows.
local BASE_GLYPH = "-"
-- The two characters obscure() preserves in place, as codepoints (see the loop for why not substrings).
local SPACE_CODEPOINT = 32
local NEWLINE_CODEPOINT = 10
local MARKS_ABOVE = {
	"\u{0300}",
	"\u{0301}",
	"\u{0302}",
	"\u{0303}",
	"\u{0304}",
	"\u{0306}",
	"\u{0307}",
	"\u{0308}",
	"\u{030A}",
	"\u{030C}",
	"\u{0311}",
	"\u{0313}",
	"\u{031A}",
	"\u{0357}",
}
local MARKS_BELOW = {
	"\u{0316}",
	"\u{0318}",
	"\u{031C}",
	"\u{031E}",
	"\u{0323}",
	"\u{0325}",
	"\u{032C}",
	"\u{0330}",
	"\u{0331}",
	"\u{0339}",
	"\u{033C}",
	"\u{0345}",
	"\u{034D}",
	"\u{0353}",
}

--[=[
	Obscured stand-in text of the same shape as `text`: word lengths and spacing survive so the layout
	stays honest, but nothing is readable. Deterministic for a given input, so it cannot shimmer between
	renders.

	Matches the AUTHORED look — a hyphen under a stack of combining marks — rather than an invented glyph
	set. The authored card ships pre-scrambled twin strings of FIXED length (plus a hidden folder of
	readable "secret phrases"); deriving the same style instead means any text can be obscured at its own
	length, including item names and stats that did not exist when that art was made.
	@param text string
	@return string
]=]
function StatusDisplay.obscure(text: string): string
	local out = {}
	-- Iterated by CODEPOINT, not by byte. `#text` is a BYTE count, so a multi-byte character — any
	-- accented name, "Café" — produced one glyph stack per byte, making the obscured string LONGER than
	-- its source and breaking the length-preservation this function's contract rests on ("word lengths
	-- and spacing survive so the layout stays honest"). `position` counts characters, so it is still the
	-- character's index and pure-ASCII output is byte-for-byte what it was.
	--
	-- `utf8.codes` errors on malformed input, which cannot arise here: both callers pass registry-authored
	-- text (an item's description, or a stat row built from ids and numbers), never anything from a player.
	local position = 0
	for _, codepoint in utf8.codes(text) do
		position += 1
		-- Compared as codepoints rather than substrings: a byte-wise " " test would also match the
		-- continuation byte of some multi-byte character and split it.
		if codepoint == SPACE_CODEPOINT or codepoint == NEWLINE_CODEPOINT then
			table.insert(out, utf8.char(codepoint))
		else
			-- Indexed by position, so the same input always yields the same output.
			table.insert(out, BASE_GLYPH)
			table.insert(out, MARKS_ABOVE[(position % #MARKS_ABOVE) + 1])
			table.insert(out, MARKS_BELOW[((position * 3) % #MARKS_BELOW) + 1])
			if position % 3 == 0 then
				table.insert(out, MARKS_ABOVE[((position * 7) % #MARKS_ABOVE) + 1])
			end
		end
	end
	return table.concat(out)
end

return StatusDisplay
