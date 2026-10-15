local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CargoGrimeSystem = require(script.Parent.CargoGrimeSystem)
local CargoSpawnSystem = require(script.Parent.CargoSpawnSystem)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local Visuals = require(ServerScriptService.Features.Art.Systems.ArtVisualSystem)

return function()
	local parent, assets, spawner, system, appraisals, clock

	beforeEach(function()
		assets = Instance.new("Folder")
		parent = Instance.new("Model")
		spawner = CargoSpawnSystem.new(Visuals.new(assets))
		appraisals = {}
		clock = 100
		system = CargoGrimeSystem.new({
			spawner = spawner,
			now = function()
				return clock
			end,
			-- Each appraisal by cleaning plays cargoAppraise at the item (and stamps the crew near it: nobody here).
			sound = function(position, id)
				if id == "cargoAppraise" then
					table.insert(appraisals, position)
				end
			end,
		})
	end)

	afterEach(function()
		parent:Destroy()
		assets:Destroy()
	end)

	local function monitor(clean)
		return spawner:spawn("monitor", CFrame.new(40000, 0, 0), parent, {
			appraisal = { base = 100, clean = clean or 0, appraised = false },
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
		local bag = spawner:spawn("dustBag", CFrame.new(40000, 0, 0), parent)
		bag:SetAttribute(InteractionConstants.CHANNEL_PROGRESS_ATTRIBUTE, 0.5)
		system:update(bag)
		system:finish(bag)
		expect(bag:GetAttribute(CargoConstants.CLEAN_ATTRIBUTE)).to.equal(nil)
		expect(bag:GetAttribute(CargoConstants.VALUE_ATTRIBUTE)).to.equal(15)
	end)
end
