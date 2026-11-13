local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantKindRegistry = require(script.Parent.OccupantKindRegistry)
local OccupantAssets = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantAssets)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local TipRegistry = require(ReplicatedStorage.Shared.Features.Tip.Data.TipRegistry)

return function()
	describe("the kinds", function()
		it("lists harlow and bramble, sorted", function()
			local ids = OccupantKindRegistry.ids()
			expect(#ids).to.equal(2)
			expect(ids[1]).to.equal("bramble")
			expect(ids[2]).to.equal("harlow")
		end)

		it("keys every entry by its own id", function()
			for _, id in OccupantKindRegistry.ids() do
				expect(OccupantKindRegistry.get(id).id).to.equal(id)
			end
		end)

		it("knows its kinds and nothing else", function()
			expect(OccupantKindRegistry.has("harlow")).to.equal(true)
			expect(OccupantKindRegistry.has("bramble")).to.equal(true)
			expect(OccupantKindRegistry.has("substitute")).to.equal(false)
			expect(OccupantKindRegistry.get("substitute")).to.equal(nil)
		end)
	end)

	describe("harlow", function()
		local harlow = OccupantKindRegistry.get("harlow")

		it("is today's manager: his template, his faces, his speeds, every block", function()
			expect(harlow.templatePath).to.equal(OccupantAssets.TEMPLATE_PATH)
			expect(harlow.faces).to.equal(true)
			expect(harlow.patrolSpeed).to.equal(OccupantConstants.PATROL_SPEED)
			expect(harlow.chaseSpeed).to.equal(OccupantConstants.CHASE_SPEED)
			expect(harlow.blocks.desks).to.equal(true)
			expect(harlow.blocks.stares).to.equal(true)
		end)

		it("has no freeze twist", function()
			expect(harlow.freeze).to.equal(nil)
			expect(OccupantKindRegistry.freezes("harlow")).to.equal(false)
		end)

		it("is the default kind", function()
			expect(OccupantKindRegistry.DEFAULT).to.equal("harlow")
		end)
	end)

	describe("bramble", function()
		local bramble = OccupantKindRegistry.get("bramble")

		it("has its own template under the characters folder", function()
			expect(bramble.templatePath[#bramble.templatePath]).to.equal("Bramble")
			expect(bramble.templatePath[1]).to.equal(OccupantAssets.TEMPLATE_PATH[1])
		end)

		it("has no painted face swap", function()
			expect(bramble.faces).to.equal(false)
		end)

		it(
			"is much faster (owner 11-13): patrols at 16 and chases at 27, past a sprint (23), so only watching it stops it",
			function()
				expect(bramble.patrolSpeed).to.equal(16)
				expect(bramble.chaseSpeed).to.equal(27)
			end
		)

		it("catches with a strike (its sound and one life, owner 11-13), not Harlow's catch sequence", function()
			expect(OccupantKindRegistry.catchStyleOf("bramble")).to.equal("strike")
		end)

		it("never sits at desks but still stares at a spot it saw someone go into", function()
			expect(bramble.blocks.desks).to.equal(false)
			expect(bramble.blocks.stares).to.equal(true)
		end)

		it("freezes while watched, with the owl head swapping every 10 s and a feather trail", function()
			expect(OccupantKindRegistry.freezes("bramble")).to.equal(true)
			expect(bramble.freeze.headSwapSeconds).to.equal(OccupantConstants.HEAD_SWAP_SECONDS)
			expect(bramble.freeze.headTurn).to.equal(true)
			expect(bramble.freeze.trail).to.equal(true)
		end)
	end)

	describe("catchStyleOf", function()
		it("is the full catch sequence for Harlow and for an unknown kind", function()
			expect(OccupantKindRegistry.catchStyleOf("harlow")).to.equal("sequence")
			expect(OccupantKindRegistry.catchStyleOf("nope")).to.equal("sequence")
		end)
	end)

	describe("templatePaths", function()
		it("is only Harlow's own template for Harlow (his path, unchanged)", function()
			local paths = OccupantKindRegistry.templatePaths("harlow")
			expect(#paths).to.equal(1)
			expect(paths[1]).to.equal(OccupantAssets.TEMPLATE_PATH)
		end)

		it("is Bramble's template first, then Harlow's as the stand-in while Bramble's model is not built", function()
			local paths = OccupantKindRegistry.templatePaths("bramble")
			expect(#paths).to.equal(2)
			expect(paths[1]).to.equal(OccupantKindRegistry.get("bramble").templatePath)
			expect(paths[2]).to.equal(OccupantAssets.TEMPLATE_PATH)
		end)

		it("is Harlow's template for an unknown kind", function()
			local paths = OccupantKindRegistry.templatePaths("ghost")
			expect(#paths).to.equal(1)
			expect(paths[1]).to.equal(OccupantAssets.TEMPLATE_PATH)
		end)
	end)

	describe("kindOf", function()
		it("reads a rig's kind attribute", function()
			local model = Instance.new("Model")
			model:SetAttribute(OccupantConstants.KIND_ATTRIBUTE, "bramble")
			expect(OccupantKindRegistry.kindOf(model)).to.equal("bramble")
			model:Destroy()
		end)

		it("is harlow without the attribute, or with an unknown one", function()
			local model = Instance.new("Model")
			expect(OccupantKindRegistry.kindOf(model)).to.equal("harlow")
			model:SetAttribute(OccupantConstants.KIND_ATTRIBUTE, "nobody")
			expect(OccupantKindRegistry.kindOf(model)).to.equal("harlow")
			model:SetAttribute(OccupantConstants.KIND_ATTRIBUTE, 5)
			expect(OccupantKindRegistry.kindOf(model)).to.equal("harlow")
			model:Destroy()
		end)
	end)

	describe("parse", function()
		it("turns a known id into a kind id and anything else into nil", function()
			expect(OccupantKindRegistry.parse("bramble")).to.equal("bramble")
			expect(OccupantKindRegistry.parse("harlow")).to.equal("harlow")
			expect(OccupantKindRegistry.parse("Bramble")).to.equal(nil)
			expect(OccupantKindRegistry.parse(nil)).to.equal(nil)
			expect(OccupantKindRegistry.parse(3)).to.equal(nil)
		end)
	end)

	describe("words", function()
		it("keeps Harlow's words: the Manager, and his own tips", function()
			local words = OccupantKindRegistry.wordsOf("harlow")
			expect(words.caughtBy).to.equal("the Manager")
			expect(words.catchTip).to.equal("firstCatch")
			expect(words.overtimeTip).to.equal("overtime")
		end)

		it("gives Bramble its own name and tips, none of them naming Harlow or the Manager", function()
			local words = OccupantKindRegistry.wordsOf("bramble")
			expect(words.caughtBy).to.equal("Bramble")
			expect(words.catchTip).to.equal("firstCatchBramble")
			expect(words.overtimeTip).to.equal("overtimeBramble")
		end)

		it("names a registered tip for every kind's catch and overtime", function()
			for _, id in OccupantKindRegistry.ids() do
				local words = OccupantKindRegistry.wordsOf(id)
				expect(TipRegistry.has(words.catchTip)).to.equal(true)
				expect(TipRegistry.has(words.overtimeTip)).to.equal(true)
			end
		end)

		it("is Harlow's for an unknown kind", function()
			expect(OccupantKindRegistry.wordsOf("substitute")).to.equal(OccupantKindRegistry.wordsOf("harlow"))
		end)
	end)

	describe("voice", function()
		it("keeps Harlow's voice: his lines, his fallback lines and his clips", function()
			local voice = OccupantKindRegistry.voiceOf("harlow")
			expect(voice).to.be.ok()
			expect(voice.lines).to.equal(OccupantConstants.LINE_VARIANTS)
			expect(voice.fallback).to.equal(OccupantConstants.LINES)
			expect(voice.fallback.caught).to.equal("You're FIRED!")
			expect(voice.clips).to.equal(OccupantAssets.GIBBERISH)
		end)

		it("gives Bramble no voice at all", function()
			expect(OccupantKindRegistry.voiceOf("bramble")).to.equal(nil)
		end)

		it("is Harlow's for an unknown kind", function()
			expect(OccupantKindRegistry.voiceOf("substitute")).to.equal(OccupantKindRegistry.voiceOf("harlow"))
		end)
	end)

	describe("sounds", function()
		local SLOTS = {
			"mutter",
			"curious",
			"sigh",
			"typing",
			"sit",
			"ambush",
			"creak",
			"crack",
			"catchSting",
			"catchStamp",
			"grab",
			"powerDown",
			"unfreeze",
		}

		it("keeps every one of Harlow's sounds where it was", function()
			local sounds = OccupantKindRegistry.soundsOf("harlow")
			expect(sounds.mutter).to.equal("harlowMutter")
			expect(sounds.curious).to.equal("harlowCurious")
			expect(sounds.sigh).to.equal("harlowSigh")
			expect(sounds.typing).to.equal("harlowTyping")
			expect(sounds.sit).to.equal("harlowSit")
			expect(sounds.ambush).to.equal("harlowAmbush")
			expect(sounds.creak).to.equal("harlowCreak")
			expect(sounds.crack).to.equal("harlowCrack")
			expect(sounds.catchSting).to.equal("harlowCatchSting")
			expect(sounds.catchStamp).to.equal("catchFired")
			expect(sounds.grab).to.equal("harlowGrab")
			expect(sounds.powerDown).to.equal("harlowPowerDown")
			expect(sounds.unfreeze).to.equal(nil)
			expect(sounds.footsteps).to.equal("harlow")
		end)

		it("never gives Bramble one of Harlow's sounds or steps", function()
			local sounds = OccupantKindRegistry.soundsOf("bramble")
			for _, slot in SLOTS do
				local id = sounds[slot]
				if id ~= nil then
					expect(string.find(id, "harlow", 1, true)).to.equal(nil)
					expect(id).never.to.equal("catchFired")
				end
			end
			expect(sounds.footsteps).to.equal(nil)
			expect(sounds.mutter).to.equal(nil)
			expect(sounds.curious).to.equal(nil)
			expect(sounds.sigh).to.equal(nil)
		end)

		it("gives Bramble its own uploaded catch and unfreeze sounds", function()
			local sounds = OccupantKindRegistry.soundsOf("bramble")
			expect(sounds.catchSting).to.equal("brambleCatch")
			expect(sounds.unfreeze).to.equal("brambleUnfreeze")
			for _, id in { "brambleCatch", "brambleUnfreeze" } do
				expect(OccupantAssets.SOUNDS[id]).to.be.ok()
				expect(string.match(OccupantAssets.SOUNDS[id].assetId, "^rbxassetid://%d+$")).to.be.ok()
			end
		end)

		it("names only OccupantAssets sounds", function()
			for _, kindId in OccupantKindRegistry.ids() do
				local sounds = OccupantKindRegistry.soundsOf(kindId)
				for _, slot in SLOTS do
					local id = sounds[slot]
					if id ~= nil then
						expect(OccupantAssets.SOUNDS[id]).to.be.ok()
					end
				end
			end
		end)

		it("is Harlow's for an unknown kind", function()
			expect(OccupantKindRegistry.soundsOf("substitute")).to.equal(OccupantKindRegistry.soundsOf("harlow"))
		end)
	end)

	describe("footstepSetOf", function()
		it("is a rig's kind's footstep set: Harlow's heels for him, none for Bramble", function()
			local harlow = Instance.new("Model")
			expect(OccupantKindRegistry.footstepSetOf(harlow)).to.equal("harlow")
			local bramble = Instance.new("Model")
			bramble:SetAttribute(OccupantConstants.KIND_ATTRIBUTE, "bramble")
			expect(OccupantKindRegistry.footstepSetOf(bramble)).to.equal(nil)
		end)
	end)
end
