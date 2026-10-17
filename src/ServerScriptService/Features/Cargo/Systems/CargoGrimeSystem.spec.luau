local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CargoGrimeSystem = require(script.Parent.CargoGrimeSystem)
local CargoSpawnSystem = require(script.Parent.CargoSpawnSystem)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local Visuals = require(ServerScriptService.Features.Art.Systems.ArtVisualSystem)

return function()
	local parent, assets, spawner, system, appraisals, jackpots, clock, hints, removed

	beforeEach(function()
		assets = Instance.new("Folder")
		parent = Instance.new("Model")
		spawner = CargoSpawnSystem.new(Visuals.new(assets))
		appraisals = {}
		jackpots = {}
		clock = 100
		hints = {}
		removed = {}
		system = CargoGrimeSystem.new({
			spawner = spawner,
			now = function()
				return clock
			end,
			-- Each appraisal by cleaning plays cargoAppraise at the item, cargoJackpot for a jackpot (and slips the crew
			-- near it: nobody here).
			sound = function(position, id)
				if id == "cargoAppraise" then
					table.insert(appraisals, position)
				elseif id == "cargoJackpot" then
					table.insert(jackpots, position)
				end
			end,
			-- The first grime lock of a shift tells its carrier (a sticky note in the game).
			lockHint = function(player)
				table.insert(hints, player)
			end,
			-- The Gloom each cleaning step removed (the shift credits it to the contract).
			cleaned = function(item, gloom)
				table.insert(removed, { item = item, gloom = gloom })
			end,
		})
	end)

	afterEach(function()
		parent:Destroy()
		assets:Destroy()
	end)

	local function monitor(clean, variant)
		return spawner:spawn("monitor", CFrame.new(40000, 0, 0), parent, {
			appraisal = { base = 100, clean = clean or 0, appraised = false, variant = variant },
		})
	end

	local function progress(item, value)
		item:SetAttribute(InteractionConstants.CHANNEL_PROGRESS_ATTRIBUTE, value)
		system:update(item)
	end

	it("mirrors channel progress into cleanliness and value", function()
		local item = monitor()
		progress(item, 0.4)
		expect(item:GetAttribute(CargoConstants.CLEAN_ATTRIBUTE)).to.be.near(0.4, 1e-9)
		expect(item:GetAttribute(CargoConstants.VALUE_ATTRIBUTE)).to.equal(58)
	end)

	it("cleans only the grime that was left when the channel started", function()
		local item = monitor(0.5)
		progress(item, 0.5)
		expect(item:GetAttribute(CargoConstants.CLEAN_ATTRIBUTE)).to.be.near(0.75, 1e-9)
	end)

	it("folds the reached cleanliness in when the channel forgets the item", function()
		local item = monitor()
		progress(item, 0.4)
		progress(item, nil)
		progress(item, 0.5)
		expect(item:GetAttribute(CargoConstants.CLEAN_ATTRIBUTE)).to.be.near(0.7, 1e-9)
	end)

	it("announces the appraisal once, when cleanliness first reaches the threshold", function()
		local item = monitor()
		progress(item, 0.5)
		expect(#appraisals).to.equal(0)
		clock = 104
		progress(item, 0.66)
		expect(#appraisals).to.equal(1)
		expect(appraisals[1]).to.equal(item.Position)
		expect(item:GetAttribute(CargoConstants.APPRAISED_AT_ATTRIBUTE)).to.equal(104)
		progress(item, 0.9)
		expect(#appraisals).to.equal(1)
	end)

	it("announces a jackpot with the jackpot sound instead of the plain appraisal", function()
		local item = monitor(0, "Gold-trim")
		progress(item, 0.7)
		expect(#jackpots).to.equal(1)
		expect(jackpots[1]).to.equal(item.Position)
		expect(#appraisals).to.equal(0)
	end)

	it("finishes an item spotless when its channel completes", function()
		local item = monitor()
		progress(item, 0.3)
		progress(item, nil)
		system:finish(item)
		expect(item:GetAttribute(CargoConstants.CLEAN_ATTRIBUTE)).to.equal(1)
		expect(item:GetAttribute(CargoConstants.VALUE_ATTRIBUTE)).to.equal(100)
		expect(item:GetAttribute(InteractionConstants.CHANNEL_KIND_ATTRIBUTE)).to.equal(nil)
		expect(#appraisals).to.equal(1)
	end)

	it("ignores trash", function()
		local bag = spawner:spawn("rubbishBag", CFrame.new(40000, 0, 0), parent)
		bag:SetAttribute(InteractionConstants.CHANNEL_PROGRESS_ATTRIBUTE, 0.5)
		system:update(bag)
		system:finish(bag)
		expect(bag:GetAttribute(CargoConstants.CLEAN_ATTRIBUTE)).to.equal(nil)
		expect(bag:GetAttribute(CargoConstants.VALUE_ATTRIBUTE)).to.equal(10)
		expect(#removed).to.equal(0)
	end)

	describe("Gloom removed", function()
		local function total()
			local sum = 0
			for _, step in removed do
				sum += step.gloom
			end
			return sum
		end

		it("credits the Gloom each cleaning step removes, live", function()
			local item = monitor()
			progress(item, 0.4)
			expect(total()).to.equal(6)
			expect(removed[#removed].item).to.equal(item)
			progress(item, 0.6)
			expect(total()).to.equal(9)
		end)

		it("adds up to exactly the item's Gloom once it is spotless", function()
			local item = monitor()
			progress(item, 0.33)
			progress(item, nil)
			progress(item, 0.21)
			system:finish(item)
			expect(total()).to.equal(CargoConstants.GLOOM_BY_SIZE.medium)
		end)

		it("never credits a step that removed nothing", function()
			local item = monitor()
			progress(item, 0.01)
			expect(#removed).to.equal(0)
		end)

		it("never gives the rest of an item grabbed dirty", function()
			local item = monitor()
			progress(item, 0.4)
			system:pickedUp(item, { UserId = 1, Name = "Carrier" })
			progress(item, nil)
			system:finish(item)
			expect(total()).to.equal(6)
		end)
	end)

	describe("grime lock", function()
		local alice = { UserId = 1 }
		local bob = { UserId = 2 }

		it("seals a dirty valuable on its first pick-up, as it is", function()
			local item = monitor(0.4)
			system:pickedUp(item, alice)
			expect(item:GetAttribute(CargoConstants.SEALED_ATTRIBUTE)).to.equal(true)
			expect(item:GetAttribute(CargoConstants.CLEAN_ATTRIBUTE)).to.equal(0.4)
			expect(item:GetAttribute(InteractionConstants.CHANNEL_KIND_ATTRIBUTE)).to.equal(nil)
		end)

		it("stops cleaning a sealed item, even if its channel progress still moves", function()
			local item = monitor()
			progress(item, 0.3)
			system:pickedUp(item, alice)
			progress(item, 0.9)
			system:finish(item)
			expect(item:GetAttribute(CargoConstants.CLEAN_ATTRIBUTE)).to.be.near(0.3, 1e-9)
			expect(#appraisals).to.equal(0)
		end)

		it("tells each carrier once a shift, and again after a reset", function()
			system:pickedUp(monitor(), alice)
			system:pickedUp(monitor(), alice)
			system:pickedUp(monitor(), bob)
			expect(#hints).to.equal(2)
			system:reset()
			system:pickedUp(monitor(), alice)
			expect(#hints).to.equal(3)
		end)

		it("leaves trash and spotless valuables alone, and tells nobody", function()
			local bag = spawner:spawn("rubbishBag", CFrame.new(40000, 0, 0), parent)
			system:pickedUp(bag, alice)
			system:pickedUp(monitor(1), alice)
			expect(bag:GetAttribute(CargoConstants.SEALED_ATTRIBUTE)).to.equal(nil)
			expect(#hints).to.equal(0)
		end)
	end)
end
