local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local EmoteEffectRegistry = require(script.Parent.EmoteEffectRegistry)

return function()
	describe("entries", function()
		it("keys only clips the AnimationRegistry knows", function()
			for key in EmoteEffectRegistry.entries do
				expect(AnimationRegistry.get(key)).to.be.ok()
			end
		end)

		it("gives every effect an id and a start marker, and never ends one on its own start marker", function()
			for key, entry in EmoteEffectRegistry.entries do
				expect(#entry.effects > 0).to.equal(true)
				for _, effect in entry.effects do
					expect(type(effect.id) == "string" and effect.id ~= "").to.equal(true)
					expect(type(effect.on) == "string" and effect.on ~= "").to.equal(true)
					expect(effect.off ~= effect.on).to.equal(true)
				end
				expect(key).to.be.ok()
			end
		end)

		it("gives Bubble Ride its stream, giant bubble, landing puff and faces", function()
			local entry = EmoteEffectRegistry.get("emote:Pippa.Bubbles")
			expect(entry).to.be.ok()
			local byId = {}
			for _, effect in entry.effects do
				byId[effect.id] = effect
			end
			expect(byId.bubbleStream.on).to.equal("BubbleBlow")
			expect(byId.bubbleStream.off).to.equal("BubbleBlowEnd")
			expect(byId.giantBubble.on).to.equal("BubbleGrow")
			expect(byId.giantBubble.off).to.equal("BubblePop")
			expect(byId.bubbleLand.on).to.equal("Land")
			expect(byId.face.on).to.equal("Face")
		end)
	end)

	describe("Big Roundup", function()
		it("gives the lasso its dust, throw, tumbleweed and faces", function()
			local entry = EmoteEffectRegistry.get("emote:Prickles.Lasso")
			expect(entry).to.be.ok()
			local on = {}
			for _, effect in entry.effects do
				on[effect.on] = effect
			end
			expect(on.LoopOut.id).to.equal("lassoPuff")
			expect(on.Yank.id).to.equal("lassoPuff")
			expect(on.DustSwirl.id).to.equal("dustSwirl")
			expect(on.DustSwirl.off).to.equal("DustSwirlEnd")
			expect(on.Throw.id).to.equal("lassoThrow")
			expect(on.Tumbleweed.id).to.equal("tumbleweed")
			expect(on.Face.id).to.equal("face")
		end)
	end)

	describe("sounds", function()
		local function on(key: string): { [string]: string }
			local byId = {}
			for _, effect in EmoteEffectRegistry.get(key).effects do
				byId[effect.id] = effect.on
			end
			return byId
		end

		it("plays Cocoa Sip's sounds from the marker where the mug appears", function()
			expect(on("emote:Cappy.CocoaSip").cocoaSounds).to.equal("PropsShow")
		end)

		it(
			"steams Cocoa Sip's mug for as long as it is out, and changes his face on the clip's Face markers",
			function()
				local steam, face
				for _, effect in EmoteEffectRegistry.get("emote:Cappy.CocoaSip").effects do
					if effect.id == "cocoaSteam" then
						steam = effect
					elseif effect.id == "face" then
						face = effect
					end
				end
				expect(steam).to.be.ok()
				expect(steam.on).to.equal("PropsShow")
				expect(steam.off).to.equal("PropsStow")
				expect(face).to.be.ok()
				expect(face.on).to.equal("Face")
			end
		)

		it("plays Bubble Ride's inflate and wobble from the bubble's growth and the bloop on the pop", function()
			local byId = on("emote:Pippa.Bubbles")
			expect(byId.bubbleGrowSound).to.equal("BubbleGrow")
			expect(byId.bubblePopSound).to.equal("BubblePop")
		end)

		it("plays Big Roundup's coil, swings, crack and yank on their markers", function()
			local byId = on("emote:Prickles.Lasso")
			expect(byId.lassoCoilSound).to.equal("PropsShow")
			expect(byId.lassoShakeSound).to.equal("LoopOut")
			expect(byId.lassoSpinSound).to.equal("DustSwirl")
			expect(byId.lassoCrackSound).to.equal("Throw")
			expect(byId.lassoYankSound).to.equal("Yank")
		end)
	end)

	describe("hire reveals", function()
		it("change the face on the clip's Face markers", function()
			for _, key in { "pippahirereveal", "prickleshirereveal", "cappyhirereveal" } do
				local entry = EmoteEffectRegistry.get(key)
				expect(entry).to.be.ok()
				expect(entry.effects[1].id).to.equal("face")
				expect(entry.effects[1].on).to.equal("Face")
			end
		end)
	end)

	describe("lookup", function()
		it("is nil for a clip without effects", function()
			expect(EmoteEffectRegistry.get("emote:Nobody.Nothing")).never.to.be.ok()
		end)

		it("finds the key from the clip's asset id", function()
			local def = AnimationRegistry.get("emote:Pippa.Bubbles")
			expect(EmoteEffectRegistry.keyForAsset(def.assetId)).to.equal("emote:Pippa.Bubbles")
			expect(EmoteEffectRegistry.keyForAsset("rbxassetid://1")).never.to.be.ok()
		end)
	end)
end
