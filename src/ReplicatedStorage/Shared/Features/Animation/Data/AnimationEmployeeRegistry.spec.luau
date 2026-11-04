local AnimationEmployeeRegistry = require(script.Parent.AnimationEmployeeRegistry)
local AnimationRegistry = require(script.Parent.AnimationRegistry)
local AnimationTypes = require(script.Parent.AnimationTypes)

return function()
	it("holds Pippa's, Cappy's and Prickles' idle, walk, run and crouch as looped Core locomotion", function()
		local keys = {}
		for _, who in { "pippa", "cappy", "prickles" } do
			for _, clip in { "idle", "walk", "run", "crouchidle", "crouchwalk" } do
				table.insert(keys, who .. clip)
			end
		end
		for _, key in keys do
			local def = AnimationEmployeeRegistry[key]
			expect(def).to.be.ok()
			expect(AnimationTypes.isCanonicalAssetId(def.assetId)).to.equal(true)
			expect(def.looped).to.equal(true)
			expect(def.priority).to.equal(Enum.AnimationPriority.Core)
			expect(def.interruption).to.equal("ambient")
			expect(def.replicable).never.to.equal(true)
		end
	end)

	it("holds the reveals and menu reactions as one-shot Action clips no one else sees (previews only)", function()
		for _, key in
			{
				"pippahirereveal",
				"prickleshirereveal",
				"cappyhirereveal",
				"pippabubblebuddyreveal",
				"pricklessheriffreveal",
				"cappypjreveal",
				"pippaselect",
				"cappyselect",
				"pricklesselect",
			}
		do
			local def = AnimationEmployeeRegistry[key]
			expect(def).to.be.ok()
			expect(AnimationTypes.isCanonicalAssetId(def.assetId)).to.equal(true)
			expect(def.looped).to.equal(false)
			expect(def.priority).to.equal(Enum.AnimationPriority.Action)
			expect(def.replicable).never.to.equal(true)
		end
	end)

	it("holds the fidgets as one-shot Action clips the idle can drop", function()
		for _, key in
			{
				"pippafidget",
				"cappyfidget",
				"pricklesfidget",
				"pricklessherifffidget",
				"pippabubblebuddyfidget",
				"cappypjfidget",
			}
		do
			local def = AnimationEmployeeRegistry[key]
			expect(def).to.be.ok()
			expect(AnimationTypes.isCanonicalAssetId(def.assetId)).to.equal(true)
			expect(def.looped).to.equal(false)
			expect(def.priority).to.equal(Enum.AnimationPriority.Action)
			expect(def.interruption).to.equal("ambient")
			expect(def.replicable).never.to.equal(true)
		end
	end)

	it("holds the sticker toss: one shared one-shot Action clip on the right arm for every employee", function()
		local def = AnimationEmployeeRegistry.stickertoss
		expect(def).to.be.ok()
		expect(AnimationTypes.isCanonicalAssetId(def.assetId)).to.equal(true)
		expect(def.looped).to.equal(false)
		expect(def.priority).to.equal(Enum.AnimationPriority.Action)
		expect(def.interruption).to.equal("ambient")
		expect(def.replicable).never.to.equal(true)
	end)

	it("is composed as the employee domain", function()
		expect(AnimationRegistry.domain("employee")).to.equal(AnimationEmployeeRegistry)
		expect(AnimationRegistry.domainOf("pippawalk")).to.equal("employee")
	end)

	it("is frozen", function()
		expect(table.isfrozen(AnimationEmployeeRegistry)).to.equal(true)
	end)
end
