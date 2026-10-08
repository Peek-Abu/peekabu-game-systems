--[=[
	Unit tests for AnimationRegistry — the composed index over the per-domain animation modules. The
	registry is the ONE lookup surface: consumers never require a domain module directly.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local AnimationLocomotionRegistry =
	require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationLocomotionRegistry)

return function()
	describe("get", function()
		it("resolves a domain entry by its key", function()
			local def = AnimationRegistry.get("idle")
			expect(def).to.be.ok()
			expect(def.assetId).to.equal(AnimationLocomotionRegistry.idle.assetId)
		end)

		it("returns nil for an unknown key rather than throwing", function()
			expect(AnimationRegistry.get("no-such-animation")).to.equal(nil)
			expect(AnimationRegistry.get("")).to.equal(nil)
		end)
	end)

	describe("domainOf", function()
		it("names the domain an entry came from", function()
			expect(AnimationRegistry.domainOf("idle")).to.equal("locomotion")
		end)

		it("returns nil for an unknown key", function()
			expect(AnimationRegistry.domainOf("no-such-animation")).to.equal(nil)
		end)
	end)

	describe("domain", function()
		it("returns a domain's entries exactly as the domain module declares them", function()
			local domain = AnimationRegistry.domain("locomotion")
			expect(domain).to.be.ok()
			local count = 0
			for key, def in domain do
				count += 1
				expect(def).to.equal(AnimationLocomotionRegistry[key])
			end
			local expected = 0
			for _ in AnimationLocomotionRegistry do
				expected += 1
			end
			expect(count).to.equal(expected)
		end)

		it("returns nil for an unknown domain", function()
			expect(AnimationRegistry.domain("combat")).to.equal(nil)
		end)
	end)

	describe("ids", function()
		it("lists every entry key across domains, sorted, for Cmdr enums", function()
			local ids = AnimationRegistry.ids()
			expect(#ids > 0).to.equal(true)
			for index = 2, #ids do
				expect(ids[index - 1] < ids[index]).to.equal(true)
			end
			local found = false
			for _, id in ids do
				if id == "idle" then
					found = true
				end
			end
			expect(found).to.equal(true)
		end)
	end)

	describe("composition purity", function()
		it("is frozen and does not mutate the domain modules", function()
			expect(table.isfrozen(AnimationRegistry.ids())).to.equal(true)
			-- The domain module is exactly what it exports — no bothAnimations-style merge wrote
			-- into it at require time.
			expect(table.isfrozen(AnimationLocomotionRegistry)).to.equal(true)
			expect(AnimationLocomotionRegistry["no-such-animation"]).to.equal(nil)
		end)
	end)

	describe("replicated actions (R3)", function()
		-- A replicable one-shot; `omit` lists fields to leave out.
		local function replicable(overrides, omit)
			local def = {
				assetId = "rbxassetid://123",
				priority = Enum.AnimationPriority.Action,
				looped = false,
				interruption = "attack",
				replicable = true,
				wireId = 7,
				layer = "full",
				durationMs = 500,
			}
			for key, value in overrides or {} do
				def[key] = value
			end
			for _, key in omit or {} do
				def[key] = nil
			end
			return def
		end

		it("gives every replicable entry in the real registry a unique wire id that resolves back", function()
			local seen = {}
			local count = 0
			for _, id in AnimationRegistry.ids() do
				local def = AnimationRegistry.get(id)
				if def.replicable then
					count += 1
					expect(seen[def.wireId]).to.equal(nil)
					seen[def.wireId] = id
					expect(AnimationRegistry.idForWire(def.wireId)).to.equal(id)
				end
			end
			expect(count > 0).to.equal(true)
		end)

		it("resolves no entry for an unused wire id", function()
			expect(AnimationRegistry.idForWire(60000)).to.equal(nil)
		end)

		it("indexes replicable entries by wire id", function()
			local composed = AnimationRegistry.composeDomains({ alpha = { leap = replicable() } })
			expect(composed.byWireId[7]).to.equal("leap")
		end)

		it("rejects two entries sharing a wire id, even across domains", function()
			expect(function()
				AnimationRegistry.composeDomains({
					alpha = { leap = replicable() },
					beta = { guard = replicable() },
				})
			end).to.throw()
		end)

		it("rejects a replicable entry without a whole wire id from 1 to 65535", function()
			for _, bad in { 0, 1.5, 70000 } do
				expect(function()
					AnimationRegistry.composeDomains({ alpha = { leap = replicable({ wireId = bad }) } })
				end).to.throw()
			end
			expect(function()
				AnimationRegistry.composeDomains({ alpha = { leap = replicable(nil, { "wireId" }) } })
			end).to.throw()
		end)

		it("rejects a replicable entry with an unknown layer", function()
			expect(function()
				AnimationRegistry.composeDomains({ alpha = { leap = replicable({ layer = "legs" }) } })
			end).to.throw()
		end)

		it("rejects a replicable one-shot without durationMs", function()
			expect(function()
				AnimationRegistry.composeDomains({ alpha = { leap = replicable(nil, { "durationMs" }) } })
			end).to.throw()
		end)

		it("rejects a looped replicable entry that declares durationMs, and accepts one without", function()
			expect(function()
				AnimationRegistry.composeDomains({ alpha = { pose = replicable({ looped = true }) } })
			end).to.throw()
			expect(function()
				AnimationRegistry.composeDomains({ alpha = { pose = replicable({ looped = true }, { "durationMs" }) } })
			end).never.to.throw()
		end)

		it("rejects wireId, layer or durationMs on an entry that is not replicable", function()
			for _, field in { "wireId", "layer", "durationMs" } do
				local plain = {
					assetId = "rbxassetid://123",
					priority = Enum.AnimationPriority.Core,
					looped = false,
					interruption = "ambient",
				}
				plain[field] = replicable()[field]
				expect(function()
					AnimationRegistry.composeDomains({ alpha = { walkish = plain } })
				end).to.throw()
			end
		end)
	end)

	describe("composeDomains (the pure core, on fabricated domains)", function()
		it("indexes entries from multiple domains", function()
			local composed = AnimationRegistry.composeDomains({
				alpha = { one = AnimationLocomotionRegistry.idle },
				beta = { two = AnimationLocomotionRegistry.walk },
			})
			expect(composed.byId.one).to.equal(AnimationLocomotionRegistry.idle)
			expect(composed.domainOf.two).to.equal("beta")
		end)

		it("rejects the same key declared by two domains — keys are unique ACROSS domains", function()
			expect(function()
				AnimationRegistry.composeDomains({
					alpha = { dupe = AnimationLocomotionRegistry.idle },
					beta = { dupe = AnimationLocomotionRegistry.walk },
				})
			end).to.throw()
		end)

		it("rejects a non-canonical asset id at compose time", function()
			expect(function()
				AnimationRegistry.composeDomains({
					alpha = {
						bad = {
							assetId = "http://www.roblox.com/asset/?id=123",
							priority = Enum.AnimationPriority.Core,
							looped = false,
							interruption = "ambient",
						},
					},
				})
			end).to.throw()
		end)

		it("rejects a non-canonical variant id at compose time", function()
			expect(function()
				AnimationRegistry.composeDomains({
					alpha = {
						bad = {
							assetId = "rbxassetid://123",
							priority = Enum.AnimationPriority.Core,
							looped = false,
							interruption = "ambient",
							variants = { "456" },
						},
					},
				})
			end).to.throw()
		end)

		-- Qodo PR #13 finding: `#` is undefined on tables with holes, so the play-time variant
		-- roll needs density proven at compose time.
		it("rejects a sparse variants table at compose time", function()
			local sparse = {}
			sparse[1] = "rbxassetid://456"
			sparse[3] = "rbxassetid://789"
			expect(function()
				AnimationRegistry.composeDomains({
					alpha = {
						bad = {
							assetId = "rbxassetid://123",
							priority = Enum.AnimationPriority.Core,
							looped = false,
							interruption = "ambient",
							variants = sparse,
						},
					},
				})
			end).to.throw()
		end)

		it("rejects an unknown interruption class at compose time", function()
			expect(function()
				AnimationRegistry.composeDomains({
					alpha = {
						bad = {
							assetId = "rbxassetid://123",
							priority = Enum.AnimationPriority.Core,
							looped = false,
							interruption = "sometimes",
						},
					},
				})
			end).to.throw()
		end)
	end)
end
