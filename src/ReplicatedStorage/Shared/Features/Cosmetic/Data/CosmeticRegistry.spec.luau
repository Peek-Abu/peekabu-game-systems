local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRegistry = require(script.Parent.CosmeticRegistry)
local CosmeticConstants = require(script.Parent.CosmeticConstants)
local EntitlementRegistry = require(ReplicatedStorage.Shared.Features.Entitlement.Data.EntitlementRegistry)

return function()
	local all = CosmeticRegistry.all()

	it("lists unique, well-formed ids, sorted", function()
		expect(#all > 0).to.equal(true)
		local seen = {}
		for index, item in all do
			expect(seen[item.id]).never.to.be.ok()
			seen[item.id] = true
			expect(#item.id >= 1 and #item.id <= CosmeticConstants.MAX_ID_LENGTH).to.equal(true)
			expect(item.name ~= "").to.equal(true)
			expect(item.lore ~= "").to.equal(true)
			if index > 1 then
				expect(all[index - 1].id < item.id).to.equal(true)
			end
			expect(CosmeticRegistry.get(item.id)).to.equal(item)
			expect(CosmeticRegistry.has(item.id)).to.equal(true)
		end
		expect(CosmeticRegistry.has("Nope.Nothing")).to.equal(false)
	end)

	it("has Pippa, Cappy and Prickles, with only Pippa free", function()
		local employees = CosmeticRegistry.employees()
		for _, name in { "Pippa", "Cappy", "Prickles" } do
			expect(table.find(employees, name)).to.be.ok()
		end
		for _, name in employees do
			local item = CosmeticRegistry.get(name)
			expect(item.kind).to.equal("employee")
			if name == CosmeticConstants.DEFAULT_EMPLOYEE then
				expect(item.source).to.equal("default")
			else
				expect(item.source).never.to.equal("default")
			end
		end
	end)

	it("gives every employee exactly one free skin, idle and emote of its own", function()
		for _, employee in CosmeticRegistry.employees() do
			for _, kind in { "skin", "idle", "emote" } do
				local count = 0
				for _, item in CosmeticRegistry.ofKind(kind, employee) do
					if item.source == "default" then
						count += 1
						expect(item.employee).to.equal(employee)
					end
				end
				expect(count).to.equal(1)
				local default = CosmeticRegistry.defaultOf(employee, kind)
				expect(default.kind).to.equal(kind)
				expect(default.source).to.equal("default")
			end
		end
	end)

	it("only points at things that exist", function()
		for _, item in all do
			if item.employee ~= nil then
				expect(CosmeticRegistry.get(item.employee).kind).to.equal("employee")
			end
			for _, part in item.bundle or {} do
				expect(CosmeticRegistry.has(part)).to.equal(true)
				expect(CosmeticRegistry.get(part).kind).never.to.equal("sticker")
			end
			if item.kind == "sticker" then
				expect(CosmeticRegistry.get(item.pack).kind).to.equal("stickerPack")
			else
				expect(item.pack).never.to.be.ok()
			end
		end
	end)

	it(
		"prices everything sold for Credits or Gleam (stickers are sold in their pack), and keeps styles in range",
		function()
			for _, item in all do
				if item.kind ~= "sticker" and (item.source == "credits" or item.source == "gleam") then
					expect(type(item.price) == "number" and item.price > 0).to.equal(true)
				end
				if item.styles ~= nil then
					expect(item.kind).to.equal("skin")
					expect(item.styles >= 1 and item.styles <= CosmeticConstants.MAX_STYLES).to.equal(true)
				end
			end
		end
	)

	it("registers every ownable item in the entitlements catalogue under its kind", function()
		for _, item in all do
			expect(EntitlementRegistry.has(item.kind, item.id)).to.equal(item.kind ~= "sticker")
		end
	end)

	it("filters by kind and employee; shared items come with every employee's list", function()
		for _, item in CosmeticRegistry.ofKind("skin", "Cappy") do
			expect(item.kind).to.equal("skin")
			expect(item.employee).to.equal("Cappy")
		end
		local idles = CosmeticRegistry.ofKind("idle", "Cappy")
		local shared = false
		for _, item in idles do
			if item.employee == nil then
				shared = true
			end
		end
		expect(shared).to.equal(true)
		expect(#CosmeticRegistry.ofKind("skin") >= #CosmeticRegistry.ofKind("skin", "Cappy")).to.equal(true)
	end)
end
