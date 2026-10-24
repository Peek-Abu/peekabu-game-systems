local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cargo = ReplicatedStorage.Shared.Features.Cargo.Data
local Registry = require(Cargo.CargoRegistry)
local Constants = require(Cargo.CargoConstants)
local Carry = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local Interaction = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local Spawn = require(script.Parent.CargoSpawnSystem)
local Formulas = require(ReplicatedStorage.Shared.Features.Cargo.Utils.CargoAppraisalFormulas)
local Vacuum = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
-- What a freshly spawned item pays: a trash item its price, a valuable 30% of its reference value (fully grimy).
local function freshValue(def)
	return if def.grimy then Formulas.value(def, def.value, 0, 0) else def.value
end
local Visuals = require(game:GetService("ServerScriptService").Features.Art.Systems.ArtVisualSystem)
return function()
	local parent
	local assets
	local art
	beforeEach(function()
		assets = Instance.new("Folder")
		art = Visuals.new(assets)
		parent = Instance.new("Model")
		parent:SetAttribute("ArtKitId", "missing-test-kit")
	end)
	afterEach(function()
		parent:Destroy()
		assets:Destroy()
	end)
	local function kit(id)
		local folder = Instance.new("Folder")
		folder.Name = id
		folder.Parent = assets
		local cargo = Instance.new("Folder")
		cargo.Name = "cargo"
		cargo.Parent = folder
		for _, key in Registry.ids() do
			local template = Instance.new("Model")
			template.Name = key
			template:SetAttribute("RuntimeApproved", true)
			template:SetAttribute("BaseSize", Vector3.new(1, 1, 1))
			local body = Instance.new("Part")
			body.Name = "Body"
			body.Size = Vector3.new(1, 1, 1)
			body.CFrame = CFrame.new(0, 0.5, 0)
			body.Transparency = 0.25
			body.Parent = template
			template.WorldPivot = CFrame.identity
			template.Parent = cargo
		end
	end
	describe("overtime loot", function()
		it("marks only items spawned with the overtime option", function()
			local spawn = Spawn.new(art)
			local floor = CFrame.new(30000, 20, 0)
			local marked = spawn:spawn("monitor", floor, parent, { overtime = true })
			local plain = spawn:spawn("monitor", floor, parent)
			expect(marked:GetAttribute(Constants.OVERTIME_ATTRIBUTE)).to.equal(true)
			expect(plain:GetAttribute(Constants.OVERTIME_ATTRIBUTE)).to.equal(nil)
		end)
	end)
	describe("cargo art authority and fallback", function()
		it("preserves every registry kind's proxy dimensions, values, tags and floor", function()
			local spawn = Spawn.new(art)
			for _, id in Registry.ids() do
				local def = Registry.get(id)
				local floor = CFrame.new(30000, 20, 0)
				local item = spawn:spawn(id, floor, parent)
				expect(item.Size).to.equal(def.partSize)
				expect(item.CFrame).to.equal(floor * CFrame.new(0, def.partSize.Y / 2, 0))
				expect(item:GetAttribute(Carry.KIND_ATTRIBUTE)).to.equal(id)
				expect(item:GetAttribute(Constants.VALUE_ATTRIBUTE)).to.equal(freshValue(def))
				expect(CollectionService:HasTag(item, Carry.TAG)).to.equal(true)
				expect(item.Transparency).to.equal(0)
				expect(item.CanCollide).to.equal(false)
				expect(item.CanQuery).to.equal(true)
			end
		end)
		it("attaches all twelve visuals and honors ancestry and spawn overrides", function()
			kit("test-map-a")
			kit("test-map-b")
			parent:SetAttribute("ArtKitId", "test-map-a")
			local spawn = Spawn.new(art)
			for _, id in Registry.ids() do
				local item = spawn:spawn(id, CFrame.new(), parent)
				local visual = item:FindFirstChild("ArtVisual")
				expect(visual ~= nil).to.equal(true)
				expect(visual:GetAttribute("ArtKitId")).to.equal("test-map-a")
				expect(item.Size).to.equal(Registry.get(id).partSize)
				expect(item.Transparency).to.equal(1)
				expect(item:GetAttribute(Constants.VALUE_ATTRIBUTE)).to.equal(freshValue(Registry.get(id)))
				expect(CollectionService:HasTag(item, Carry.TAG)).to.equal(true)
				local other = spawn:spawn(id, CFrame.new(), parent, { artKit = "test-map-b" })
				expect(other:FindFirstChild("ArtVisual"):GetAttribute("ArtKitId")).to.equal("test-map-b")
			end
		end)
		it("falls back to the default kit when the map's kit has no cargo art", function()
			-- The office's kit (odd-hours-b1) holds building and furniture only; cargo art lives in the default kit.
			local DefaultKit = require(ReplicatedStorage.Shared.Features.Art.Data.ArtKitRegistry).DEFAULT_KIT
			kit(DefaultKit)
			local mapKit = Instance.new("Folder")
			mapKit.Name = "test-map-no-cargo"
			mapKit.Parent = assets
			parent:SetAttribute("ArtKitId", "test-map-no-cargo")
			local spawn = Spawn.new(art)
			for _, id in Registry.ids() do
				local item = spawn:spawn(id, CFrame.new(), parent)
				local visual = item:FindFirstChild("ArtVisual")
				expect(visual ~= nil).to.equal(true)
				expect(visual:GetAttribute("ArtKitId")).to.equal(DefaultKit)
				expect(item.Transparency).to.equal(1)
				local buried = spawn:spawn(id, CFrame.new(), parent, { hidden = true })
				expect(buried:FindFirstChild("ArtVisual") ~= nil).to.equal(true)
				spawn:reveal(buried)
				expect(buried.Transparency).to.equal(1)
			end
		end)

		it("reveals the approved visual while its authoritative proxy remains invisible and welded", function()
			kit("test-map-a")
			parent:SetAttribute("ArtKitId", "test-map-a")
			local spawn = Spawn.new(art)
			local item = spawn:spawn("goldenStapler", CFrame.new(), parent, { hidden = true })
			local body = item:FindFirstChild("ArtVisual"):FindFirstChild("Body")
			expect(body.Transparency).to.equal(1)
			spawn:reveal(item)
			expect(item.Transparency).to.equal(1)
			expect(body.Transparency).to.equal(0.25)
			expect(item.CanCollide).to.equal(false)
			expect(item.CanQuery).to.equal(true)
			expect(body.CanCollide).to.equal(false)
			expect(body.CanQuery).to.equal(false)
			expect(body.CanTouch).to.equal(false)
			expect(body.Massless).to.equal(true)
			expect(body:FindFirstChildOfClass("WeldConstraint") ~= nil).to.equal(true)
			item.Anchored = false
			task.wait()
			expect(body.Anchored).to.equal(false)
		end)
		it("reveals a missing-template hidden item with its label and prompt", function()
			local spawn = Spawn.new(art)
			local item = spawn:spawn("goldenStapler", CFrame.new(), parent, { hidden = true })
			local label = item:FindFirstChild(Constants.LABEL_NAME)
			expect(item.Transparency).to.equal(1)
			expect(item.CanCollide).to.equal(false)
			expect(item.CanQuery).to.equal(false)
			expect(label.Enabled).to.equal(false)
			expect(item:GetAttribute(Interaction.ENABLED_ATTRIBUTE)).to.equal(false)
			spawn:reveal(item)
			expect(item.Transparency).to.equal(0)
			expect(item.CanCollide).to.equal(false)
			expect(item.CanQuery).to.equal(true)
			expect(label.Enabled).to.equal(true)
			expect(item:GetAttribute(Interaction.ENABLED_ATTRIBUTE)).to.equal(nil)
			expect(item:GetAttribute(Constants.HIDDEN_ATTRIBUTE)).to.equal(nil)
		end)
	end)
	describe("grime and appraisal", function()
		it("spawns valuables fully grimy and cleanable, trash clean and untagged", function()
			local spawn = Spawn.new(art)
			for _, id in Registry.ids() do
				local def = Registry.get(id)
				local item = spawn:spawn(id, CFrame.new(), parent)
				if def.grimy then
					expect(item:GetAttribute(Constants.CLEAN_ATTRIBUTE)).to.equal(0)
					expect(item:GetAttribute(Constants.APPRAISED_ATTRIBUTE)).to.equal(false)
					expect(item:GetAttribute(Constants.BASE_VALUE_ATTRIBUTE)).to.equal(def.value)
					expect(item:GetAttribute(Interaction.CHANNEL_KIND_ATTRIBUTE)).to.equal(Vacuum.GRIME_KINDS[def.size])
					expect(CollectionService:HasTag(item, Vacuum.GRIME_TAG)).to.equal(true)
					local shell = item:FindFirstChild(Constants.LABEL_NAME)
					expect(shell:GetAttribute(Constants.LABEL_KEYS.grimy)).to.equal(true)
					expect(shell:GetAttribute(Constants.LABEL_KEYS.clean)).to.equal(0)
					expect(shell:GetAttribute(Constants.LABEL_KEYS.appraised)).to.equal(false)
				else
					expect(item:GetAttribute(Constants.CLEAN_ATTRIBUTE)).to.equal(nil)
					expect(item:GetAttribute(Interaction.CHANNEL_KIND_ATTRIBUTE)).to.equal(nil)
					expect(CollectionService:HasTag(item, Vacuum.GRIME_TAG)).to.equal(false)
				end
			end
		end)

		it("follows a given appraisal and ignores a plain value for a valuable", function()
			local spawn = Spawn.new(art)
			local item = spawn:spawn("monitor", CFrame.new(), parent, {
				value = 999,
				appraisal = { base = 200, variant = "Gold-trim", clean = 0.5, appraised = true },
			})
			expect(item:GetAttribute(Constants.BASE_VALUE_ATTRIBUTE)).to.equal(200)
			expect(item:GetAttribute(Constants.VARIANT_ATTRIBUTE)).to.equal("Gold-trim")
			expect(item:GetAttribute(Constants.VALUE_ATTRIBUTE)).to.equal(130)
			local shell = item:FindFirstChild(Constants.LABEL_NAME)
			expect(shell:GetAttribute(Constants.LABEL_KEYS.name)).to.equal("Gold-trim monitor")
		end)

		it("spawns an already clean valuable without the cleaning channel", function()
			local spawn = Spawn.new(art)
			local item = spawn:spawn("plaque", CFrame.new(), parent, {
				appraisal = { base = 80, clean = 1, appraised = true },
			})
			expect(item:GetAttribute(Constants.VALUE_ATTRIBUTE)).to.equal(80)
			expect(item:GetAttribute(Interaction.CHANNEL_KIND_ATTRIBUTE)).to.equal(nil)
			expect(CollectionService:HasTag(item, Vacuum.GRIME_TAG)).to.equal(false)
		end)

		it("re-prices from base, impacts and cleanliness", function()
			local spawn = Spawn.new(art)
			local item = spawn:spawn("monitor", CFrame.new(), parent, {
				appraisal = { base = 100, clean = 1, appraised = true },
			})
			item:SetAttribute(Constants.IMPACTS_ATTRIBUTE, 1)
			spawn:reprice(item)
			expect(item:GetAttribute(Constants.VALUE_ATTRIBUTE)).to.equal(50)
			local shell = item:FindFirstChild(Constants.LABEL_NAME)
			expect(shell:GetAttribute(Constants.LABEL_KEYS.value)).to.equal(50)
			expect(shell:GetAttribute(Constants.LABEL_KEYS.impacts)).to.equal(1)
		end)

		it("cleans: raises the value, appraises once, then stops being a vacuum target when spotless", function()
			local spawn = Spawn.new(art)
			local item = spawn:spawn("monitor", CFrame.new(), parent, {
				appraisal = { base = 100, variant = "Gold-trim", clean = 0, appraised = false },
			})
			expect(spawn:setClean(item, 0.5, 10)).to.equal(false)
			expect(item:GetAttribute(Constants.VALUE_ATTRIBUTE)).to.equal(65)
			expect(item:GetAttribute(Constants.APPRAISED_ATTRIBUTE)).to.equal(false)
			local shell = item:FindFirstChild(Constants.LABEL_NAME)
			expect(shell:GetAttribute(Constants.LABEL_KEYS.name)).to.equal("Monitor")
			expect(spawn:setClean(item, 0.7, 11)).to.equal(true)
			expect(item:GetAttribute(Constants.APPRAISED_ATTRIBUTE)).to.equal(true)
			expect(item:GetAttribute(Constants.APPRAISED_AT_ATTRIBUTE)).to.equal(11)
			expect(shell:GetAttribute(Constants.LABEL_KEYS.name)).to.equal("Gold-trim monitor")
			expect(shell:GetAttribute(Constants.LABEL_KEYS.appraisedAt)).to.equal(11)
			expect(spawn:setClean(item, 0.9, 12)).to.equal(false)
			expect(item:GetAttribute(Constants.APPRAISED_AT_ATTRIBUTE)).to.equal(11)
			expect(CollectionService:HasTag(item, Vacuum.GRIME_TAG)).to.equal(true)
			spawn:setClean(item, 1, 13)
			expect(item:GetAttribute(Constants.VALUE_ATTRIBUTE)).to.equal(100)
			expect(item:GetAttribute(Interaction.CHANNEL_KIND_ATTRIBUTE)).to.equal(nil)
			expect(CollectionService:HasTag(item, Vacuum.GRIME_TAG)).to.equal(false)
		end)

		it("never makes an item dirtier", function()
			local spawn = Spawn.new(art)
			local item = spawn:spawn("plaque", CFrame.new(), parent)
			spawn:setClean(item, 0.6, 1)
			spawn:setClean(item, 0.2, 2)
			expect(item:GetAttribute(Constants.CLEAN_ATTRIBUTE)).to.equal(0.6)
		end)

		it("appraises at the truck without cleaning", function()
			local spawn = Spawn.new(art)
			local item = spawn:spawn("plaque", CFrame.new(), parent)
			expect(spawn:appraise(item, 5)).to.equal(true)
			expect(item:GetAttribute(Constants.APPRAISED_ATTRIBUTE)).to.equal(true)
			expect(item:GetAttribute(Constants.CLEAN_ATTRIBUTE)).to.equal(0)
			expect(spawn:appraise(item, 6)).to.equal(false)
		end)
	end)

	describe("grime lock (sealed as found)", function()
		it("seals a dirty valuable: no longer cleanable, keeps its cleanliness and value, tag marked", function()
			local spawn = Spawn.new(art)
			local item = spawn:spawn("monitor", CFrame.new(), parent, {
				appraisal = { base = 100, clean = 0.4, appraised = false },
			})
			local value = item:GetAttribute(Constants.VALUE_ATTRIBUTE)
			expect(spawn:seal(item)).to.equal(true)
			expect(item:GetAttribute(Constants.SEALED_ATTRIBUTE)).to.equal(true)
			expect(item:GetAttribute(Constants.CLEAN_ATTRIBUTE)).to.equal(0.4)
			expect(item:GetAttribute(Constants.VALUE_ATTRIBUTE)).to.equal(value)
			expect(item:GetAttribute(Interaction.CHANNEL_KIND_ATTRIBUTE)).to.equal(nil)
			expect(CollectionService:HasTag(item, Vacuum.GRIME_TAG)).to.equal(false)
			local shell = item:FindFirstChild(Constants.LABEL_NAME)
			expect(shell:GetAttribute(Constants.LABEL_KEYS.sealed)).to.equal(true)
			expect(spawn:seal(item)).to.equal(false)
		end)

		it("refuses to clean a sealed valuable", function()
			local spawn = Spawn.new(art)
			local item = spawn:spawn("plaque", CFrame.new(), parent)
			spawn:seal(item)
			expect(spawn:setClean(item, 0.9, 3)).to.equal(false)
			expect(item:GetAttribute(Constants.CLEAN_ATTRIBUTE)).to.equal(0)
			expect(item:GetAttribute(Constants.APPRAISED_ATTRIBUTE)).to.equal(false)
		end)

		it("never seals trash or a spotless valuable", function()
			local spawn = Spawn.new(art)
			local bag = spawn:spawn("rubbishBag", CFrame.new(), parent)
			local clean = spawn:spawn("monitor", CFrame.new(), parent, {
				appraisal = { base = 100, clean = 1, appraised = true },
			})
			expect(spawn:seal(bag)).to.equal(false)
			expect(spawn:seal(clean)).to.equal(false)
			expect(clean:GetAttribute(Constants.SEALED_ATTRIBUTE)).to.equal(nil)
		end)

		it("respawns a sealed appraisal sealed (a pocket entry)", function()
			local spawn = Spawn.new(art)
			local item = spawn:spawn("plaque", CFrame.new(), parent, {
				appraisal = { base = 80, clean = 0.3, appraised = false, sealed = true },
			})
			expect(item:GetAttribute(Constants.SEALED_ATTRIBUTE)).to.equal(true)
			expect(CollectionService:HasTag(item, Vacuum.GRIME_TAG)).to.equal(false)
			expect(item:GetAttribute(Interaction.CHANNEL_KIND_ATTRIBUTE)).to.equal(nil)
		end)
	end)
end
