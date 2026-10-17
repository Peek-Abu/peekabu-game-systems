local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoBankRules = require(script.Parent.CargoBankRules)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)

local BED = Vector3.new(12, 3, 16)

return function()
	describe("onBed", function()
		it("accepts a player standing on the bed", function()
			expect(CargoBankRules.onBed(Vector3.new(0, 4, 0), BED)).to.equal(true)
			expect(CargoBankRules.onBed(Vector3.new(6.5, 4, -8.5), BED)).to.equal(true)
		end)

		it("refuses a player beside the truck or far above it", function()
			expect(CargoBankRules.onBed(Vector3.new(9, 4, 0), BED)).to.equal(false)
			expect(CargoBankRules.onBed(Vector3.new(0, 4, 11), BED)).to.equal(false)
			expect(CargoBankRules.onBed(Vector3.new(0, 20, 0), BED)).to.equal(false)
		end)
	end)

	describe("canLoad", function()
		it("loads from the bed or within reach beside it", function()
			expect(CargoBankRules.canLoad(Vector3.new(0, 4, 0), BED)).to.equal(true)
			expect(CargoBankRules.canLoad(Vector3.new(10, 3, 0), BED)).to.equal(true)
		end)
		it("measures corner reach radially and rejects distant or vertically invalid loads", function()
			expect(CargoBankRules.canLoad(Vector3.new(9, 3, 11), BED)).to.equal(false)
			expect(CargoBankRules.canLoad(Vector3.new(10.1, 3, 0), BED)).to.equal(false)
			expect(CargoBankRules.canLoad(Vector3.new(0, 20, 0), BED)).to.equal(false)
			expect(CargoBankRules.canLoad(Vector3.new(0, -10, 0), BED)).to.equal(false)
		end)
	end)

	describe("landedOnBed", function()
		local item = Vector3.new(2, 4, 2)
		it("accepts cargo whose bottom rests on the bed footprint", function()
			expect(CargoBankRules.landedOnBed(Vector3.new(0, 3.5, 0), item, BED)).to.equal(true)
		end)
		it("rejects airborne cargo, cargo under the bed and beside the truck", function()
			expect(CargoBankRules.landedOnBed(Vector3.new(0, 6, 0), item, BED)).to.equal(false)
			expect(CargoBankRules.landedOnBed(Vector3.new(0, 0, 0), item, BED)).to.equal(false)
			expect(CargoBankRules.landedOnBed(Vector3.new(6.1, 3.5, 0), item, BED)).to.equal(false)
		end)
	end)

	describe("deposit", function()
		it("adds hands trash to clearance", function()
			local deposit = CargoBankRules.deposit({ kind = "rubbishBag", value = 10 }, {}, CargoRegistry.get)
			expect(deposit.clearance).to.equal(10)
			expect(deposit.bonus).to.equal(0)
			expect(#deposit.items).to.equal(1)
		end)

		it("adds salvage to bonus and unloads pockets with the hands item", function()
			local deposit = CargoBankRules.deposit(
				{ kind = "recyclingBox", value = 15 },
				{ { kind = "plaque", value = 25 }, { kind = "goldenStapler", value = 80 } },
				CargoRegistry.get
			)
			expect(deposit.clearance).to.equal(15)
			expect(deposit.bonus).to.equal(105)
			expect(#deposit.items).to.equal(3)
			expect(deposit.items[2].category).to.equal("salvage")
		end)

		it("loads pockets alone when the hands are empty", function()
			local deposit = CargoBankRules.deposit(nil, { { kind = "plaque", value = 25 } }, CargoRegistry.get)
			expect(deposit.bonus).to.equal(25)
		end)

		it("uses the item's current (damaged) value", function()
			local deposit = CargoBankRules.deposit({ kind = "monitor", value = 15 }, {}, CargoRegistry.get)
			expect(deposit.bonus).to.equal(15)
		end)

		it("keeps each valuable's appraisal on its deposit line", function()
			local appraisal = { base = 100, clean = 0.2, appraised = false }
			local deposit = CargoBankRules.deposit(
				{ kind = "monitor", value = 44, appraisal = appraisal },
				{ { kind = "recyclingBox", value = 15 } },
				CargoRegistry.get
			)
			expect(deposit.items[1].appraisal).to.equal(appraisal)
			expect(deposit.items[2].appraisal).to.equal(nil)
		end)

		it("refuses an empty load", function()
			local deposit, reason = CargoBankRules.deposit(nil, {}, CargoRegistry.get)
			expect(deposit).to.equal(nil)
			expect(reason).to.equal("nothing to load")
		end)

		it("refuses an unknown kind", function()
			local deposit, reason = CargoBankRules.deposit({ kind = "spaceship", value = 999 }, {}, CargoRegistry.get)
			expect(deposit).to.equal(nil)
			expect(reason).to.equal('unknown cargo "spaceship"')
		end)
	end)
end
