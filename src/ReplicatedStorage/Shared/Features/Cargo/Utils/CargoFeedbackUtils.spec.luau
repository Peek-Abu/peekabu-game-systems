local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoFeedbackUtils = require(script.Parent.CargoFeedbackUtils)
local CargoAssets = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoAssets)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)

return function()
	describe("floaters", function()
		it("shows clearance as a green +N", function()
			local list = CargoFeedbackUtils.floaters(15, 0)
			expect(#list).to.equal(1)
			expect(list[1].text).to.equal("+15")
			expect(list[1].tone).to.equal("clearance")
		end)

		it("shows clearance first, then the bonus", function()
			local list = CargoFeedbackUtils.floaters(15, 45)
			expect(#list).to.equal(2)
			expect(list[2].text).to.equal("+45")
			expect(list[2].tone).to.equal("bonus")
		end)

		it("omits a zero amount", function()
			local list = CargoFeedbackUtils.floaters(0, 38)
			expect(#list).to.equal(1)
			expect(list[1].tone).to.equal("bonus")
			expect(#CargoFeedbackUtils.floaters(0, 0)).to.equal(0)
		end)

		it("rounds like the review", function()
			expect(CargoFeedbackUtils.floaters(0, 37.5)[1].text).to.equal("+38")
		end)
	end)

	describe("banked", function()
		local deposit = {
			clearance = 10,
			bonus = 25,
			items = {
				{ kind = "rubbishBag", category = "trash", value = 10 },
				{ kind = "plaque", category = "salvage", value = 25 },
			},
		}

		it("lists the kinds loaded and lands on top of the bed", function()
			local bed, size = Vector3.new(10, 2, 0), Vector3.new(8, 1, 12)
			local message = CargoFeedbackUtils.banked(deposit, Vector3.new(1, 2, 3), bed, size, nil)
			expect(#message.kinds).to.equal(2)
			expect(message.kinds[2]).to.equal("plaque")
			expect((message.from - Vector3.new(1, 2, 3)).Magnitude).to.be.near(0, 1e-6)
			expect((message.to - Vector3.new(10, 2.5, 0)).Magnitude).to.be.near(0, 1e-6)
			expect(message.clearance).to.equal(10)
		end)

		it("carries the credited bonus, else the deposit's, rounded like the review", function()
			local size = Vector3.new(1, 1, 1)
			expect(CargoFeedbackUtils.banked(deposit, Vector3.zero, Vector3.zero, size, nil).bonus).to.equal(25)
			expect(CargoFeedbackUtils.banked(deposit, Vector3.zero, Vector3.zero, size, 37.5).bonus).to.equal(38)
		end)

		it("clamps the amounts to the packet's range", function()
			local odd = { clearance = 1e9, bonus = -4, items = {} }
			local message = CargoFeedbackUtils.banked(odd, Vector3.zero, Vector3.zero, Vector3.new(1, 1, 1), nil)
			expect(message.clearance).to.equal(65535)
			expect(message.bonus).to.equal(0)
			expect(#message.kinds).to.equal(0)
		end)
	end)

	describe("visual identity", function()
		it("snapshots actual kit, proxy size and rotation before the source is destroyed", function()
			local part = Instance.new("Part")
			part.Size = Vector3.new(3, 4, 5)
			part.CFrame = CFrame.new(20, 9, 30) * CFrame.Angles(0, 0.7, 0)
			part:SetAttribute("CarryKind", "recyclingBox")
			part:SetAttribute("CargoId", 17)
			part:SetAttribute("CargoValue", 20)
			local art = Instance.new("Model")
			art.Name = "ArtVisual"
			art:SetAttribute("ArtKitId", "item-override")
			art.Parent = part
			local entry = CargoFeedbackUtils.entryOf(part)
			expect(entry.visual.kitId).to.equal("item-override")
			expect(entry.visual.proxySize).to.equal(part.Size)
			expect(entry.visual.rotation).to.equal(part.CFrame.Rotation)
			part:Destroy()
			expect(entry.visual.kitId).to.equal("item-override")
		end)
		it("preserves per-item identities in packet order without changing authoritative values", function()
			local visual =
				{ kitId = "second-company", proxySize = Vector3.new(2, 3, 4), rotation = CFrame.Angles(0, 0.5, 0) }
			local deposit = {
				clearance = 20,
				bonus = 0,
				items = { { kind = "recyclingBox", category = "trash", value = 20, visual = visual } },
			}
			local packet = CargoFeedbackUtils.banked(deposit, Vector3.zero, Vector3.zero, Vector3.one, nil)
			expect(packet.visuals[1].kitId).to.equal("second-company")
			expect(packet.visuals[1].proxySize).to.equal(visual.proxySize)
			expect(packet.visuals[1].rotation).to.equal(visual.rotation)
			expect(packet.clearance).to.equal(20)
			packet.visuals[1].kitId = "mutated-output"
			expect(visual.kitId).to.equal("second-company")
		end)
	end)

	describe("arc", function()
		it("starts at the item and ends in the truck", function()
			local from, to = Vector3.new(0, 0, 0), Vector3.new(10, 0, 0)
			expect((CargoFeedbackUtils.arc(from, to, 0, 6) - from).Magnitude).to.be.near(0, 1e-6)
			expect((CargoFeedbackUtils.arc(from, to, 1, 6) - to).Magnitude).to.be.near(0, 1e-6)
		end)

		it("lifts half the arc height at the middle", function()
			local middle = CargoFeedbackUtils.arc(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), 0.5, 6)
			expect((middle - Vector3.new(5, 3, 0)).Magnitude).to.be.near(0, 1e-6)
		end)
	end)

	describe("sounds", function()
		it("picks the drop sound by trait, then by weight", function()
			expect(CargoFeedbackUtils.dropSound(CargoRegistry.get("waterJug"))).to.equal("cargoSplash")
			expect(CargoFeedbackUtils.dropSound(CargoRegistry.get("monitor"))).to.equal("cargoShatter")
			expect(CargoFeedbackUtils.dropSound(CargoRegistry.get("coffeeMachine"))).to.equal("cargoThudHeavy")
			expect(CargoFeedbackUtils.dropSound(CargoRegistry.get("filingCabinet"))).to.equal("cargoThudHeavy")
			expect(CargoFeedbackUtils.dropSound(CargoRegistry.get("rubbishBag"))).to.equal("cargoThudLight")
		end)

		it("gives rattle and search noises their sounds, and nothing else", function()
			expect(CargoFeedbackUtils.noiseSound("rattle")).to.equal("cargoRattle")
			expect(CargoFeedbackUtils.noiseSound("search")).to.equal("cargoRummage")
			expect(CargoFeedbackUtils.noiseSound("drop")).to.equal(nil)
			expect(CargoFeedbackUtils.noiseSound("vacuum")).to.equal(nil)
		end)

		it("only names sounds CargoAssets declares", function()
			for _, kind in CargoRegistry.ids() do
				expect(CargoAssets.SOUNDS[CargoFeedbackUtils.dropSound(CargoRegistry.get(kind))]).to.be.ok()
			end
			expect(CargoAssets.SOUNDS[CargoFeedbackUtils.noiseSound("rattle")]).to.be.ok()
			expect(CargoAssets.SOUNDS[CargoFeedbackUtils.noiseSound("search")]).to.be.ok()
			for _, id in { "cargoChaChing", "cargoSwoosh", "cargoPickup", "cargoPocket" } do
				expect(CargoAssets.SOUNDS[id]).to.be.ok()
			end
		end)
	end)

	describe("hands and pockets", function()
		it("cues a pickup when something new comes into the hands", function()
			expect(CargoFeedbackUtils.pickedUp(nil, "monitor")).to.equal(true)
			expect(CargoFeedbackUtils.pickedUp("plaque", "monitor")).to.equal(true)
			expect(CargoFeedbackUtils.pickedUp("monitor", "monitor")).to.equal(false)
			expect(CargoFeedbackUtils.pickedUp("monitor", nil)).to.equal(false)
		end)

		it("cues a pocket when a pocket fills", function()
			expect(CargoFeedbackUtils.pocketed(0, 1)).to.equal(true)
			expect(CargoFeedbackUtils.pocketed(1, 1)).to.equal(false)
			expect(CargoFeedbackUtils.pocketed(2, 0)).to.equal(false)
		end)

		it("hides the view only behind the office plant", function()
			expect(CargoFeedbackUtils.blocksView("officePlant")).to.equal(true)
			expect(CargoFeedbackUtils.blocksView("monitor")).to.equal(false)
			expect(CargoFeedbackUtils.blocksView(nil)).to.equal(false)
			expect(CargoFeedbackUtils.blocksView("no-such-item")).to.equal(false)
		end)
	end)
end
