local VM = require(script.Parent.DepotGuideViewModel)

return function()
	local function words(text)
		local count = 0
		for _ in string.gmatch(text, "%S+") do
			count += 1
		end
		return count
	end

	describe("tabs", function()
		it("opens on HOW TO PLAY, with MONSTERS beside it", function()
			expect(VM.DEFAULT_TAB).to.equal("play")
			expect(VM.tabs("play")[1].label).to.equal("HOW TO PLAY")
			expect(VM.tabs("play")[1].selected).to.equal(true)
			expect(VM.tabs("play")[2].label).to.equal("MONSTERS")
			expect(VM.tabs("monsters")[2].selected).to.equal(true)
			expect(VM.tabs("monsters")[1].selected).to.equal(false)
		end)
	end)

	describe("steps", function()
		it("is four photo steps in the order you play a shift", function()
			local steps = VM.steps()
			expect(#steps).to.equal(4)
			local titles = {}
			for index, step in steps do
				expect(step.number).to.equal(index)
				table.insert(titles, step.title)
			end
			expect(table.concat(titles, "|")).to.equal("HOP ON|VACUUM|SHH! HIDE!|LOAD UP")
		end)

		it("gives each step one short line a young player can read", function()
			for _, step in VM.steps() do
				expect(words(step.line) <= 8).to.equal(true)
				expect(step.photo).to.be.a("string")
			end
			expect(VM.steps()[2].line).to.equal("Suck up the purple Gloom.")
		end)

		it("teaches that Gloom goes away as you vacuum, with no dust bags to carry", function()
			local text = ""
			for _, step in VM.steps() do
				text ..= string.lower(step.title .. " " .. step.line) .. " "
			end
			expect(string.find(text, "gloom", 1, true) ~= nil).to.equal(true)
			for _, old in { "dust bag", "empty your vacuum", "empty at the truck" } do
				expect(string.find(text, old, 1, true)).to.equal(nil)
			end
		end)

		it("puts the live vacuum control under the vacuum step, never a guessed key", function()
			expect(VM.steps("Hold R2 to clean.")[2].hint).to.equal("Hold R2 to clean.")
			expect(VM.steps()[2].hint).to.equal(nil)
			for index, step in VM.steps("Hold R2 to clean.") do
				if index ~= 2 then
					expect(step.hint).to.equal(nil)
				end
			end
		end)

		it("gives each step its own colour and its own photo", function()
			local seen, photos = {}, {}
			for _, step in VM.steps() do
				expect(seen[step.hue]).to.equal(nil)
				seen[step.hue] = true
				expect(photos[step.photo]).to.equal(nil)
				photos[step.photo] = true
			end
		end)
	end)

	describe("monsters", function()
		it("shows the Manager, Bramble and a coming-soon card, in that order", function()
			local cards = VM.monsters()
			expect(#cards).to.equal(3)
			expect(cards[1].name).to.equal("THE MANAGER")
			expect(cards[1].place).to.equal("THE OFFICE")
			expect(cards[2].name).to.equal("BRAMBLE")
			expect(cards[2].place).to.equal("THE SCHOOL")
			expect(cards[3].soon).to.equal(true)
			expect(cards[3].name).to.equal("???")
		end)

		it("keeps the cards to lore: no danger meter and no rules for escaping (owner 2026-11-13)", function()
			for _, card in VM.monsters() do
				expect(card.danger).to.equal(nil)
				for _, line in card.lore do
					local lower = string.lower(line)
					for _, banned in { "danger", "escape", "hide from", "run from", "when he", "if he", "don't let" } do
						expect(string.find(lower, banned, 1, true)).to.equal(nil)
					end
					expect(words(line) <= 7).to.equal(true)
				end
			end
		end)

		it("uses the owner's lore words", function()
			local cards = VM.monsters()
			expect(table.concat(cards[1].lore, " ")).to.equal("He never went home. He still checks every desk.")
			expect(table.concat(cards[2].lore, " ")).to.equal("Maple Hill's old owl mascot. He is very, very shy.")
			expect(table.concat(cards[3].lore, " ")).to.equal("Someone new is moving in. Keep your flashlight close.")
		end)

		it("gives the real monsters a photo and a cut-out, and the coming-soon card neither", function()
			local cards = VM.monsters()
			for index = 1, 2 do
				expect(cards[index].photo).to.be.a("string")
				expect(cards[index].cut).to.be.a("string")
			end
			expect(cards[3].cut).to.equal(nil)
		end)
	end)

	describe("crop", function()
		it("keeps the whole photo when the frame has its shape", function()
			local offset, size = VM.crop(Vector2.new(592, 720), Vector2.new(296, 360), 0.25)
			expect(offset).to.equal(Vector2.new(0, 0))
			expect(size).to.equal(Vector2.new(592, 720))
		end)

		it("cuts a short, wide frame's rows near the top, so heads stay in", function()
			local offset, size = VM.crop(Vector2.new(592, 720), Vector2.new(592, 296), 0.25)
			expect(size.X).to.equal(592)
			expect(size.Y).to.be.near(296, 0.5)
			expect(offset.X).to.equal(0)
			expect(offset.Y).to.be.near((720 - 296) * 0.25, 0.5)
		end)

		it("cuts a tall, narrow frame's columns from the middle", function()
			local offset, size = VM.crop(Vector2.new(592, 720), Vector2.new(100, 720), 0.25)
			expect(size.Y).to.equal(720)
			expect(size.X).to.be.near(100, 0.5)
			expect(offset.X).to.be.near((592 - 100) / 2, 0.5)
			expect(offset.Y).to.equal(0)
		end)

		it("gives the step photos their source size and a focus near the top", function()
			expect(VM.STEP_PHOTO).to.equal(Vector2.new(592, 720))
			expect(VM.STEP_FOCUS < 0.5).to.equal(true)
		end)
	end)

	describe("layout", function()
		it("gives the Guide a wide sheet, never past the screen", function()
			local wide = VM.layout(Vector2.new(1920, 1080), false)
			expect(wide.width).to.equal(VM.SIZE.X)
			expect(wide.height).to.equal(VM.SIZE.Y)
			local small = VM.layout(Vector2.new(900, 500), false)
			expect(small.width <= 900 - 32).to.equal(true)
			expect(small.height <= 500 - 48).to.equal(true)
			local phone = VM.layout(Vector2.new(844, 390), true)
			expect(phone.width <= 844 - 32).to.equal(true)
		end)
	end)
end
