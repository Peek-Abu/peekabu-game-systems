local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeSpawnRules = require(script.Parent.OfficeSpawnRules)
local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
local OfficeLayoutConstants = require(ServerScriptService.Features.Office.Data.OfficeLayoutConstants)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)

local LAYOUT = OfficeLayoutConstants.LAYOUT

-- Three piles (PILE_GLOOM each) and the fish tank's grime (heavy) are the site's Gloom; the two rubbish bags (old
-- fixtures) carry none. A contract may ask at most CONTRACT_SHARE_MAX of it.
local function plan()
	return {
		piles = {
			{ marker = "lobby.pile.1", kind = "paper" },
			{ marker = "lobby.pile.2", kind = "debris" },
			{ marker = "lobby.pile.3", kind = "cables" },
		},
		items = {
			{ marker = "lobby.item.1", kind = "rubbishBag" },
			{ marker = "lobby.item.2", kind = "rubbishBag" },
			{ marker = "archive.item.1", kind = "fishTank", appraisal = { base = 260 } },
		},
		searchables = {},
		greed = { marker = "archive.item.1", kind = "fishTank" },
		value = 295,
	}
end

return function()
	it("accepts a plan that meets the guarantees", function()
		local ok, reason = OfficeSpawnRules.check(plan(), LAYOUT, 20)
		expect(reason).to.equal(nil)
		expect(ok).to.equal(true)
	end)

	it("refuses a site too thin in Gloom for the contract", function()
		local site = 3 * VacuumConstants.PILE_GLOOM + CargoConstants.GLOOM_BY_SIZE.heavy
		local need = math.ceil(200 / OfficeConstants.CONTRACT_SHARE_MAX)
		local ok, reason = OfficeSpawnRules.check(plan(), LAYOUT, 200)
		expect(ok).to.equal(false)
		expect(reason).to.equal(`only {site} of a needed {need} Gloom for a contract of 200`)
		expect(OfficeSpawnRules.check(plan(), LAYOUT, math.floor(site * OfficeConstants.CONTRACT_SHARE_MAX))).to.equal(
			true
		)
	end)

	it("refuses a missing greed target", function()
		local noGreed = plan()
		noGreed.greed = nil
		local ok, reason = OfficeSpawnRules.check(noGreed, LAYOUT, 20)
		expect(ok).to.equal(false)
		expect(reason).to.equal("no greed target")
	end)

	it("refuses a greed target placed shallow", function()
		local shallow = plan()
		shallow.items[3].marker = "lobby.item.3"
		shallow.greed.marker = "lobby.item.3"
		local ok, reason = OfficeSpawnRules.check(shallow, LAYOUT, 20)
		expect(ok).to.equal(false)
		expect(reason).to.equal("the greed target is not placed deep")
	end)

	it("refuses a greed record naming a non-greed item", function()
		local wrong = plan()
		wrong.greed.kind = "coffeeMachine"
		local ok, reason = OfficeSpawnRules.check(wrong, LAYOUT, 20)
		expect(ok).to.equal(false)
		expect(reason).to.equal('"coffeeMachine" is not a greed target')
	end)

	it("refuses a marker used twice", function()
		local twice = plan()
		twice.items[2].marker = "lobby.item.1"
		local ok, reason = OfficeSpawnRules.check(twice, LAYOUT, 20)
		expect(ok).to.equal(false)
		expect(reason).to.equal('marker "lobby.item.1" is used twice')
	end)

	it("accepts appliances on counters and refuses anything else there", function()
		local layout = table.clone(LAYOUT)
		layout.markers = table.clone(LAYOUT.markers)
		table.insert(layout.markers, { id = "lobby.counter.1", room = "lobby", kind = "counter", x = 5, z = 35 })
		local surfaced = plan()
		table.insert(surfaced.items, { marker = "lobby.counter.1", kind = "coffeeMachine" })
		local ok, reason = OfficeSpawnRules.check(surfaced, layout, 20)
		expect(reason).to.equal(nil)
		expect(ok).to.equal(true)
		local wrong = plan()
		table.insert(wrong.items, { marker = "lobby.counter.1", kind = "rubbishBag" })
		local bad, why = OfficeSpawnRules.check(wrong, layout, 20)
		expect(bad).to.equal(false)
		expect(why).to.equal('"rubbishBag" does not belong on a counter')
	end)

	it("accepts meeting-table monitors and cabinet plaques, and refuses counter monitors", function()
		local layout = table.clone(LAYOUT)
		layout.markers = table.clone(LAYOUT.markers)
		table.insert(layout.markers, { id = "lobby.table.1", room = "lobby", kind = "table", x = 5, z = 35 })
		table.insert(layout.markers, { id = "lobby.cabinet.1", room = "lobby", kind = "cabinet", x = 8, z = 35 })
		table.insert(layout.markers, { id = "lobby.counter.1", room = "lobby", kind = "counter", x = 11, z = 35 })
		local surfaced = plan()
		table.insert(surfaced.items, { marker = "lobby.table.1", kind = "monitor" })
		table.insert(surfaced.items, { marker = "lobby.cabinet.1", kind = "plaque" })
		local ok, reason = OfficeSpawnRules.check(surfaced, layout, 20)
		expect(reason).to.equal(nil)
		expect(ok).to.equal(true)
		local wrong = plan()
		table.insert(wrong.items, { marker = "lobby.counter.1", kind = "monitor" })
		local bad, why = OfficeSpawnRules.check(wrong, layout, 20)
		expect(bad).to.equal(false)
		expect(why).to.equal('"monitor" does not belong on a counter')
	end)
	it("refuses surface-only appliance floor overflow but permits searched floor reveals", function()
		local wrong = plan()
		table.insert(wrong.items, { marker = "lobby.item.3", kind = "coffeeMachine" })
		local ok, why = OfficeSpawnRules.check(wrong, LAYOUT, 20)
		expect(ok).to.equal(false)
		expect(why).to.equal('"coffeeMachine" requires a furniture surface')
		local searched = plan()
		searched.searchables = { { marker = "lobby.desk.1", kind = "coffeeMachine" } }
		expect(OfficeSpawnRules.check(searched, LAYOUT, 20)).to.equal(true)
	end)
	it("allows water-jug and coffee overflow onto meeting tables", function()
		expect(table.find(OfficeSpawnRules.surfaceKindsFor("waterJug"), "table") ~= nil).to.equal(true)
		expect(table.find(OfficeSpawnRules.surfaceKindsFor("coffeeMachine"), "table") ~= nil).to.equal(true)
	end)
end
