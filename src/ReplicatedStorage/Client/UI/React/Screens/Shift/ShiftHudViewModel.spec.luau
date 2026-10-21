local CrewVM = require(script.Parent.ShiftCrewViewModel)
local ShiftHudViewModel = require(script.Parent.ShiftHudViewModel)

local function snapshot(extra)
	local value = {
		phase = "running",
		sub = "normal",
		shift = 1,
		endsAt = 1000,
		quota = 350,
		cleared = 120,
		bonus = 40,
		quotaMet = false,
		variant = "B",
		votesAnother = 0,
		votesDepot = 0,
		stage = "normal",
		tier = 0,
		crew = {},
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

-- The gap between two round buttons (a spot is a top-left offset and a diameter): centre distance minus both radii.
local function circleGap(a, b)
	local ax, ay = a.x + a.size / 2, a.y + a.size / 2
	local bx, by = b.x + b.size / 2, b.y + b.size / 2
	return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2) - a.size / 2 - b.size / 2
end

-- The gap between a round button and the Jump button's rectangle (a square spot).
local function rectGap(button, rect)
	local cx, cy = button.x + button.size / 2, button.y + button.size / 2
	local dx = math.max(rect.x - cx, 0, cx - (rect.x + rect.size))
	local dy = math.max(rect.y - cy, 0, cy - (rect.y + rect.size))
	return math.sqrt(dx * dx + dy * dy) - button.size / 2
end

local BUTTONS = { "primary", "drop", "throw", "sprint", "crouch" }

-- Every gap the arc must keep, as a list of the ones it breaks (empty when clear): >= 16 px from the Jump button and
-- between buttons, and right of the thumbstick zone (the left 40% of a `width` px screen). Pure, so it can live
-- outside the spec body; the `it` blocks assert the result with `expect`.
local function arcFailures(arc, width)
	local failures = {}
	for index, first in BUTTONS do
		local jumpGap = rectGap(arc[first], arc.jump)
		if jumpGap < 16 then
			table.insert(failures, `{first}-jump {jumpGap}`)
		end
		if width + arc[first].x < width * 0.4 then
			table.insert(failures, `{first} in the thumbstick zone at width {width}`)
		end
		for _, second in table.move(BUTTONS, index + 1, #BUTTONS, 1, {}) do
			local gap = circleGap(arc[first], arc[second])
			if gap < 16 then
				table.insert(failures, `{first}-{second} {gap}`)
			end
		end
	end
	return table.concat(failures, "; ")
end

return function()
	describe("compact HUD policy", function()
		it("counts no items and offers no carry actions with an empty inventory", function()
			local view = ShiftHudViewModel.hud(snapshot(), {}, 0, false)
			local compact = ShiftHudViewModel.compact(view, {})
			expect(compact.itemCount).to.equal(0)
			expect(#compact.actions).to.equal(0)
			expect(compact.equipped).to.equal(false)
		end)
		it("reads equipped state and rebound carry keys", function()
			local view = ShiftHudViewModel.hud(snapshot(), { vacuumEquipped = true, carrying = "monitor" }, 0, false)
			local compact = ShiftHudViewModel.compact(view, { drop = { Enum.KeyCode.R }, throw = { Enum.KeyCode.T } })
			expect(compact.equipped).to.equal(true)
			expect(compact.actions[1].key).to.equal("R")
			expect(compact.actions[1].label).to.equal("drop")
			expect(#compact.actions).to.equal(1)
		end)
		it("describes trash as clearance and salvage as bonus value", function()
			local trash = ShiftHudViewModel.hud(snapshot(), { carrying = "rubbishBag" }, 0, false)
			local salvage = ShiftHudViewModel.hud(snapshot(), { carrying = "monitor" }, 0, false)
			expect(ShiftHudViewModel.compact(trash, {}).cargoValue).to.equal("+10 clearance")
			-- A valuable's worth is a mystery until appraised (its tag shows it): the HUD never guesses.
			expect(ShiftHudViewModel.compact(salvage, {}).cargoValue).to.equal("??? Gleam")
		end)
		it("counts pocketed items even with empty hands", function()
			local view = ShiftHudViewModel.hud(snapshot(), { inv1 = "plaque", inv3 = "keyring" }, 0, false)
			expect(ShiftHudViewModel.compact(view, {}).itemCount).to.equal(2)
		end)
	end)

	describe("untilTick", function()
		local slack = ShiftHudViewModel.TICK_SLACK
		it("waits until the shown second changes, just past it", function()
			expect(math.abs(ShiftHudViewModel.untilTick(5.3) - (0.3 + slack)) < 1e-6).to.equal(true)
			expect(math.abs(ShiftHudViewModel.untilTick(0.4) - (0.4 + slack)) < 1e-6).to.equal(true)
		end)

		it("waits a whole second on an exact second (m:ss rounds up)", function()
			expect(math.abs(ShiftHudViewModel.untilTick(5) - (1 + slack)) < 1e-6).to.equal(true)
			-- Shown 0:05 at 5.0 left; still 0:05 just after, 0:04 from 4.0.
			expect(ShiftHudViewModel.clock(5)).to.equal(ShiftHudViewModel.clock(4.01))
		end)

		it("never ticks again once the countdown shows 0:00", function()
			expect(ShiftHudViewModel.untilTick(0)).to.equal(nil)
			expect(ShiftHudViewModel.untilTick(-3)).to.equal(nil)
		end)
	end)

	describe("clock", function()
		it("formats minutes and seconds, rounding up and never negative", function()
			expect(ShiftHudViewModel.clock(420)).to.equal("7:00")
			expect(ShiftHudViewModel.clock(61)).to.equal("1:01")
			expect(ShiftHudViewModel.clock(59.2)).to.equal("1:00")
			expect(ShiftHudViewModel.clock(0)).to.equal("0:00")
			expect(ShiftHudViewModel.clock(-5)).to.equal("0:00")
		end)
	end)

	describe("hud", function()
		it("shows nothing outside a running shift, or while hidden", function()
			expect(ShiftHudViewModel.hud(nil, nil, 0, false)).to.equal(nil)
			expect(ShiftHudViewModel.hud(snapshot({ phase = "results" }), nil, 0, false)).to.equal(nil)
			expect(ShiftHudViewModel.hud(snapshot(), nil, 0, true)).to.equal(nil)
		end)

		it(
			"fills the contract folder with the Gloom removed, and the fee plate with the Gleam earned so far",
			function()
				local view = ShiftHudViewModel.hud(snapshot(), nil, 580, false)
				expect(view.cleared).to.equal("120")
				expect(view.quotaText).to.equal("/ 350 Gloom")
				expect(view.clearedShort).to.equal("Gloom 120 / 350")
				expect(math.abs(view.fill - 120 / 350) < 1e-6).to.equal(true)
				-- 120 Gloom at 1 Gleam each, plus 40 Gleam of valuables banked.
				expect(view.fee).to.equal("160 Gleam")
				expect(view.feeBoost).to.equal(nil)
				expect(view.feeBoostShort).to.equal(nil)
			end
		)

		it("caps the clearance bar at full", function()
			local view = ShiftHudViewModel.hud(snapshot({ cleared = 400, quotaMet = true }), nil, 0, false)
			expect(view.fill).to.equal(1)
			expect(view.quotaMet).to.equal(true)
		end)

		it("punches the time card as the shift goes and lights a pip per tier", function()
			-- endsAt 1000: at now 580 there are 420 s left (nothing punched); at 832, 168 s left (3 of 5 punched).
			expect(ShiftHudViewModel.hud(snapshot(), nil, 580, false).punched).to.equal(0)
			expect(ShiftHudViewModel.hud(snapshot(), nil, 832, false).punched).to.equal(3)
			expect(ShiftHudViewModel.hud(snapshot({ tier = 0 }), nil, 600, false).pressure).to.equal(1)
			expect(ShiftHudViewModel.hud(snapshot({ tier = 2 }), nil, 600, false).pressure).to.equal(3)
		end)

		it("reads the time, OUT and the stage label", function()
			local view = ShiftHudViewModel.hud(snapshot(), nil, 748, false)
			expect(view.time).to.equal("4:12")
			expect(view.outText).to.equal("OUT 7:00")
			expect(view.clockLabel).to.equal("SHIFT")
			expect(view.overtime).to.equal(false)
		end)

		it("labels the break, the warning and overtime", function()
			expect(ShiftHudViewModel.hud(snapshot({ stage = "break", stageEndsAt = 124 }), nil, 100, false).clockLabel).to.equal(
				"MANAGER ON BREAK 0:24"
			)
			expect(
				ShiftHudViewModel.hud(snapshot({ stage = "warning", stageEndsAt = 112 }), nil, 100, false).clockLabel
			).to.equal("OVERTIME IN 0:12")
			local overtime = ShiftHudViewModel.hud(snapshot({ stage = "overtime" }), nil, 100, false)
			expect(overtime.clockLabel).to.equal("OVERTIME")
			expect(overtime.overtime).to.equal(true)
			expect(overtime.feeBoost).to.equal("×1.5 now")
			expect(overtime.feeBoostShort).to.equal("×1.5")
		end)

		it("offers overtime once the quota is met and the break is over", function()
			local open = ShiftHudViewModel.hud(snapshot({ quotaMet = true, stage = "normal" }), nil, 100, false)
			expect(open.clockLabel).to.equal("OVERTIME OPTIONAL")
			expect(open.overtime).to.equal(false)
			expect(open.feeBoost).to.equal(nil)
		end)

		it("describes the hands item with its value and traits", function()
			local view = ShiftHudViewModel.hud(snapshot(), { carrying = "monitor" }, 0, false)
			expect(view.hands.name).to.equal("Monitor")
			expect(view.hands.value).to.equal("??? Gleam")
			expect(view.hands.traits).to.equal("medium · FRAGILE")
			expect(view.hands.short).to.equal("??? Gleam fragile")
			expect(view.hands.fragile).to.equal(true)
		end)

		it("shows empty hands, an empty hotbar and the contract on the vacuum's canister", function()
			local view = ShiftHudViewModel.hud(snapshot(), nil, 0, false)
			expect(view.hands).to.equal(nil)
			expect(#view.hotbar.slots).to.equal(5)
			expect(view.hotbar.slots[2].empty).to.equal(true)
			expect(view.hotbar.slots[2].name).to.equal("")
			expect(view.hotbar.slots[1].tag).to.equal("120/350")
		end)

		it("names a pocketed item in its hotbar slot", function()
			local view = ShiftHudViewModel.hud(snapshot(), { inv2 = "plaque" }, 0, false)
			expect(view.hotbar.slots[3].name).to.equal("Employee of the Month plaque")
			expect(view.hotbar.slots[3].empty).to.equal(false)
		end)

		it("carries the truck", function()
			local view =
				ShiftHudViewModel.hud(snapshot({ sub = "clockout", clockOutAt = 107, truck = 2 }), nil, 100, false)
			expect(view.truck).to.equal(2)
		end)

		it("carries the deadline the shift clock counts down to, so it ticks without the whole HUD", function()
			expect(ShiftHudViewModel.hud(snapshot(), nil, 100, false).endsAt).to.equal(1000)
			local open = snapshot()
			open.endsAt = nil
			expect(ShiftHudViewModel.hud(open, nil, 100, false).endsAt).to.equal(nil)
		end)
	end)

	describe("phone buttons", function()
		it("offers VACUUM with empty hands, and nothing to drop or throw", function()
			local view = ShiftHudViewModel.buttons(nil, false)
			expect(view.primary).to.equal("VACUUM")
			expect(view.primaryReady).to.equal(false)
			expect(view.drop).to.equal(false)
			expect(view.throw).to.equal(false)
		end)

		it("switches to LOAD while holding something, lit only at the truck", function()
			expect(ShiftHudViewModel.buttons({ carrying = "monitor" }, false).primary).to.equal("BANK")
			expect(ShiftHudViewModel.buttons({ carrying = "monitor" }, false).primaryReady).to.equal(false)
			expect(ShiftHudViewModel.buttons({ carrying = "monitor" }, true).primaryReady).to.equal(true)
		end)

		it("allows a throw only for a throwable item", function()
			expect(ShiftHudViewModel.buttons({ carrying = "rubbishBag" }, false).throw).to.equal(true)
			expect(ShiftHudViewModel.buttons({ carrying = "coffeeMachine" }, false).throw).to.equal(false)
		end)

		it("offers SPRINT with or without a load, never while hiding", function()
			expect(ShiftHudViewModel.buttons(nil, false).sprint).to.equal(true)
			expect(ShiftHudViewModel.buttons({ carrying = "coffeeMachine" }, false).sprint).to.equal(true)
			expect(ShiftHudViewModel.buttons(nil, false, true).sprint).to.equal(false)
		end)

		it("offers the CROUCH toggle with or without a load, never while hiding", function()
			expect(ShiftHudViewModel.buttons(nil, false).crouch).to.equal(true)
			expect(ShiftHudViewModel.buttons({ carrying = "coffeeMachine" }, false).crouch).to.equal(true)
			expect(ShiftHudViewModel.buttons(nil, false, true).crouch).to.equal(false)
		end)

		it("puts CROUCH right above the Jump button, its own column", function()
			for _, short in { 390, 768 } do
				local arc = ShiftHudViewModel.arcFor(short)
				local crouchCentre = arc.crouch.x + arc.crouch.size / 2
				local jumpCentre = arc.jump.x + arc.jump.size / 2
				expect(math.abs(crouchCentre - jumpCentre) <= 1).to.equal(true)
				expect(arc.crouch.y + arc.crouch.size <= arc.jump.y).to.equal(true)
			end
		end)

		it("keeps SPRINT clear of the other buttons on a narrow phone too", function()
			expect(arcFailures(ShiftHudViewModel.arcFor(375), 667)).to.equal("")
		end)

		it("never lights LOAD with empty hands, even at the truck", function()
			local view = ShiftHudViewModel.buttons(nil, true)
			expect(view.primary).to.equal("VACUUM")
			expect(view.primaryReady).to.equal(false)
		end)

		it("keeps VACUUM usable and LOAD usable only while the Load prompt is up", function()
			expect(ShiftHudViewModel.buttons(nil, false).primaryAvailable).to.equal(true)
			expect(ShiftHudViewModel.buttons({ carrying = "monitor" }, false).primaryAvailable).to.equal(false)
			expect(ShiftHudViewModel.buttons({ carrying = "monitor" }, true).primaryAvailable).to.equal(true)
		end)

		it("calls LOAD live only while it shows, reads LOAD and its prompt is up", function()
			expect(ShiftHudViewModel.loadLive(ShiftHudViewModel.buttons({ carrying = "monitor" }, true))).to.equal(true)
			expect(ShiftHudViewModel.loadLive(ShiftHudViewModel.buttons({ carrying = "monitor" }, false))).to.equal(
				false
			)
			expect(ShiftHudViewModel.loadLive(ShiftHudViewModel.buttons(nil, true))).to.equal(false)
			expect(ShiftHudViewModel.loadLive(nil)).to.equal(false)
		end)
	end)

	describe("mobile buttons", function()
		it("shows the arc only on a touch device while a shift runs and the HUD is up", function()
			local me = { carrying = "monitor" }
			expect(ShiftHudViewModel.mobileButtons(snapshot(), me, true, false, false)).never.to.equal(nil)
			expect(ShiftHudViewModel.mobileButtons(snapshot(), me, false, false, false)).to.equal(nil)
			expect(ShiftHudViewModel.mobileButtons(nil, me, true, false, false)).to.equal(nil)
			expect(ShiftHudViewModel.mobileButtons(snapshot({ phase = "results" }), me, true, false, false)).to.equal(
				nil
			)
			expect(ShiftHudViewModel.mobileButtons(snapshot(), me, true, true, false)).to.equal(nil)
		end)

		it("passes the hands and the truck's Load prompt through to the buttons", function()
			local view = ShiftHudViewModel.mobileButtons(snapshot(), { carrying = "monitor" }, true, false, true)
			expect(view.primary).to.equal("BANK")
			expect(view.primaryReady).to.equal(true)
		end)
	end)

	describe("phone time card", function()
		it("reads OUT on the compact card until overtime, then OVERTIME", function()
			expect(ShiftHudViewModel.hud(snapshot(), nil, 0, false).compactSub).to.equal("OUT 7:00")
			expect(ShiftHudViewModel.hud(snapshot({ stage = "overtime" }), nil, 0, false).compactSub).to.equal(
				"OVERTIME"
			)
		end)
	end)

	describe("hidden", function()
		it("hides the HUD during the scare beat and while the local player is caught", function()
			expect(ShiftHudViewModel.hidden(nil, false)).to.equal(false)
			expect(ShiftHudViewModel.hidden({ carrying = "monitor" }, false)).to.equal(false)
			expect(ShiftHudViewModel.hidden(nil, true)).to.equal(true)
			expect(ShiftHudViewModel.hidden({ dead = true }, false)).to.equal(true)
		end)
	end)

	describe("action arc", function()
		it("keeps the phone arc around the 70 px phone Jump button", function()
			local arc = ShiftHudViewModel.arcFor(390)
			expect(arc.jump.size).to.equal(70)
			expect(arc.primary.size).to.equal(104)
			expect(arc.primary.x).to.equal(-236)
			expect(arc.primary.y).to.equal(-124)
			expect(arc.drop.x).to.equal(-332)
			expect(arc.throw.y).to.equal(-196)
			expect(arcFailures(arc, 844)).to.equal("")
			expect(ShiftHudViewModel.arcFor(500).jump.size).to.equal(70)
		end)

		it("moves the arc clear of the 120 px Jump button on a larger touch screen", function()
			local arc = ShiftHudViewModel.arcFor(768)
			expect(arc.jump.size).to.equal(120)
			expect(arc.jump.x).to.equal(-170)
			expect(arc.jump.y).to.equal(-210)
			expect(arcFailures(arc, 1024)).to.equal("")
			-- Portrait, and the smallest screen that gets the large Jump button.
			expect(arcFailures(arc, 768)).to.equal("")
			expect(arcFailures(ShiftHudViewModel.arcFor(501), 501)).to.equal("")
		end)
	end)

	describe("prompt chip", function()
		local function prompt(extra)
			local value =
				{ id = 1, action = "Bank cargo", object = "Recovery Unit", key = "E", hold = 0, kind = "cargo-load" }
			for key, item in extra or {} do
				value[key] = item
			end
			return value
		end

		it("says what banking does with the item in hand", function()
			local chip = ShiftHudViewModel.prompt(prompt(), "monitor", 0)
			expect(chip.key).to.equal("E")
			expect(chip.text).to.equal("BANK monitor")
		end)

		it("falls back to the prompt's own words", function()
			local chip = ShiftHudViewModel.prompt(
				prompt({ kind = "shift-clockout", action = "Clock out", object = "Time clock" }),
				nil,
				0
			)
			expect(chip.text).to.equal("CLOCK OUT time clock")
		end)

		it("fills a hold prompt while it is held", function()
			local chip = ShiftHudViewModel.prompt(
				prompt({ kind = "cargo-search", action = "Search", object = "Desk", hold = 2, holdStartedAt = 10 }),
				nil,
				11
			)
			expect(chip.fill).to.equal(0.5)
			expect(ShiftHudViewModel.prompt(prompt({ hold = 2 }), nil, 11).fill).to.equal(0)
			expect(ShiftHudViewModel.prompt(prompt(), nil, 11).fill).to.equal(nil)
		end)

		it("shows nothing without a prompt", function()
			expect(ShiftHudViewModel.prompt(nil, "monitor", 0)).to.equal(nil)
		end)

		it("shows nothing while the HUD is hidden", function()
			expect(ShiftHudViewModel.prompt(prompt(), "monitor", 0, true)).to.equal(nil)
			expect(ShiftHudViewModel.prompt(prompt(), "monitor", 0, false).text).to.equal("BANK monitor")
		end)

		it("lights LOAD only while the truck's Load prompt is shown", function()
			expect(ShiftHudViewModel.loadReady(prompt())).to.equal(true)
			expect(ShiftHudViewModel.loadReady(prompt({ kind = "shift-clockout" }))).to.equal(false)
			expect(ShiftHudViewModel.loadReady(nil)).to.equal(false)
		end)
	end)

	describe("key hints", function()
		it("names keys and mouse buttons the way the HUD prints them", function()
			expect(ShiftHudViewModel.keyName(Enum.KeyCode.G)).to.equal("G")
			expect(ShiftHudViewModel.keyName(Enum.KeyCode.LeftControl)).to.equal("Ctrl")
			expect(ShiftHudViewModel.keyName(Enum.UserInputType.MouseButton1)).to.equal("LMB")
			expect(ShiftHudViewModel.keyName(Enum.KeyCode.Left)).to.equal("←")
		end)

		it("lists the actions in Figma's order with each first keyboard binding", function()
			local hints = ShiftHudViewModel.keyHints({
				vacuum = { Enum.UserInputType.MouseButton1 },
				drop = { Enum.KeyCode.G },
				throw = { Enum.KeyCode.F },
				interact = { Enum.KeyCode.E },
			})
			expect(#hints).to.equal(4)
			expect(hints[1].prefix).to.equal("Hold")
			expect(hints[1].key).to.equal("LMB")
			expect(hints[1].label).to.equal("vacuum")
			expect(hints[4].key).to.equal("E")
			expect(hints[4].label).to.equal("bank / search")
		end)

		it("skips an action with no binding", function()
			expect(#ShiftHudViewModel.keyHints({ drop = { Enum.KeyCode.G } })).to.equal(1)
		end)

		it("names the hint actions it reads bindings for", function()
			local actions = ShiftHudViewModel.HINT_ACTIONS
			expect(#actions).to.equal(6)
			expect(actions[1]).to.equal("vacuum")
			expect(actions[4]).to.equal("interact")
			expect(actions[5]).to.equal("sprint")
			expect(actions[6]).to.equal("crouch")
		end)

		it("draws the hint row on desktop with a keyboard only", function()
			expect(ShiftHudViewModel.showHints("desktop", true)).to.equal(true)
			expect(ShiftHudViewModel.showHints("desktop", false)).to.equal(false)
			expect(ShiftHudViewModel.showHints("phone", true)).to.equal(false)
		end)
	end)

	describe("centreShift", function()
		it("is 0 on a wide screen", function()
			expect(ShiftHudViewModel.centreShift(1920)).to.equal(0)
		end)

		it("moves the centred pieces right of the left column on a laptop", function()
			expect(ShiftHudViewModel.centreShift(1366)).to.equal(101)
			expect(ShiftHudViewModel.centreShift(1280)).to.equal(144)
		end)

		it("never goes below 0", function()
			expect(ShiftHudViewModel.centreShift(5000)).to.equal(0)
			expect(ShiftHudViewModel.centreShift(1568)).to.equal(0)
		end)

		it("clears the left column by the gap exactly where it starts to apply", function()
			local width = 1366
			local slipLeft = width / 2 - 250 + ShiftHudViewModel.centreShift(width)
			expect(slipLeft).to.equal(518 + 16)
		end)
	end)

	describe("carryLeft", function()
		it("keeps the carry panel at the left inset on a tall viewport", function()
			expect(ShiftHudViewModel.carryLeft(Vector2.new(1920, 1080))).to.equal(48)
			expect(ShiftHudViewModel.carryLeft(Vector2.new(1366, 780))).to.equal(48)
		end)

		it("moves it right of the roster column on a short viewport", function()
			expect(ShiftHudViewModel.carryLeft(Vector2.new(1366, 690))).to.equal(418)
			expect(ShiftHudViewModel.carryLeft(Vector2.new(1366, 779))).to.equal(418)
		end)

		it("fits inside a 1366 px screen when moved", function()
			expect(ShiftHudViewModel.carryLeft(Vector2.new(1366, 690)) + 640 <= 1366).to.equal(true)
		end)
	end)

	describe("promptTouchable", function()
		it("is a button only on a touch device without a keyboard", function()
			expect(ShiftHudViewModel.promptTouchable(true, false)).to.equal(true)
			expect(ShiftHudViewModel.promptTouchable(true, true)).to.equal(false)
			expect(ShiftHudViewModel.promptTouchable(false, true)).to.equal(false)
			expect(ShiftHudViewModel.promptTouchable(false, false)).to.equal(false)
		end)
	end)
	describe("meter (V1)", function()
		it("asks the crew to clean the Gloom until the contract is met", function()
			local meter = ShiftHudViewModel.meter({ quotaMet = false, overtime = false })
			expect(meter.title).to.equal("CLEAN THE GLOOM")
			expect(meter.site).to.equal("Harlow & Finch · offices")
			expect(meter.met).to.equal(false)
		end)

		it("celebrates a met contract, and calls out overtime", function()
			expect(ShiftHudViewModel.meter({ quotaMet = true, overtime = false }).title).to.equal("CONTRACT MET!")
			expect(ShiftHudViewModel.meter({ quotaMet = true, overtime = false }).met).to.equal(true)
			expect(ShiftHudViewModel.meter({ quotaMet = true, overtime = true }).title).to.equal("OVERTIME!")
		end)
	end)

	describe("livesFrame", function()
		local function overlaps(aAt, aSize, bAt, bSize)
			return aAt.X < bAt.X + bSize.X
				and bAt.X < aAt.X + aSize.X
				and aAt.Y < bAt.Y + bSize.Y
				and bAt.Y < aAt.Y + aSize.Y
		end

		-- The viewport of each layout (HUD design px) the frame is specced at.
		local cases = {
			{ layout = "phone", viewport = Vector2.new(844, 390), count = 4 },
			{ layout = "desktop", viewport = Vector2.new(1920, 1080), count = 4 },
		}

		it("sits centred under the meter and its drop shadow", function()
			for _, case in cases do
				local at, size = ShiftHudViewModel.livesFrame(case.layout, case.viewport)
				local meter = ShiftHudViewModel.METER[case.layout]
				expect(at.X + size.X / 2).to.equal(case.viewport.X / 2)
				expect(at.Y >= meter.top + meter.size.Y + 7).to.equal(true)
			end
		end)

		it("never overlaps the meter, the crew list or the clock-out board", function()
			for _, case in cases do
				local phone = case.layout == "phone"
				local at, size = ShiftHudViewModel.livesFrame(case.layout, case.viewport)
				local meter = ShiftHudViewModel.METER[case.layout]
				local w = case.viewport.X
				-- The meter plate with its Gloom render, its stopwatch render and its drop shadow.
				local plate = if phone then CrewVM.phoneFit(w).meter else meter.size.X
				local meterAt = Vector2.new(
					w / 2 - plate / 2 - meter.icon * ShiftHudViewModel.METER_ICON_OVERHANG,
					meter.top - (if phone then 24 else 34)
				)
				local meterEnd =
					Vector2.new(w / 2 + plate / 2 + (if phone then 16 else 22), meter.top + meter.size.Y + 7)
				expect(overlaps(at, size, meterAt, meterEnd - meterAt)).to.equal(false)
				-- The crew list: top-right on phone, top-left under Roblox's buttons on desktop.
				local listWidth = if phone then CrewVM.phoneFit(w).list else nil
				local listSize = CrewVM.listSize(phone, case.count, listWidth)
				local listAt = if phone then Vector2.new(w - 10 - listSize.X, 6) else Vector2.new(24, 66)
				expect(overlaps(at, size, listAt, listSize)).to.equal(false)
				-- The clock-out board: centred, `boardTop` down, 7 px of outline above it, its clock render reaching out.
				local boardWidth = if phone then 330 else 470
				local boardHeight = if phone then 80 else 108
				local boardAt = Vector2.new(
					w / 2 - boardWidth / 2 - (if phone then 29 else 40),
					ShiftHudViewModel.boardTop(case.layout, case.viewport) - 7
				)
				expect(overlaps(at, size, boardAt, Vector2.new(boardWidth + 40, boardHeight + 14))).to.equal(false)
			end
		end)

		it("pops to 1.25 at the midpoint and settles back to 1", function()
			expect(ShiftHudViewModel.lossPop(0)).to.equal(1)
			expect(math.abs(ShiftHudViewModel.lossPop(1) - 1) < 1e-9).to.equal(true)
			expect(math.abs(ShiftHudViewModel.lossPop(0.5) - 1.25) < 1e-9).to.equal(true)
			expect(ShiftHudViewModel.lossPop(-1)).to.equal(1)
		end)

		it("fits a full set of lives", function()
			local _, size = ShiftHudViewModel.livesFrame("phone", Vector2.new(844, 390))
			expect(size).to.equal(Vector2.new(3 * 20 - 2 * 6, 20))
		end)
	end)
end
