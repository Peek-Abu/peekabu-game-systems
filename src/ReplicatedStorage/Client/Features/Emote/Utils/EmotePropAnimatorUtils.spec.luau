local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmotePropAnimatorUtils = require(ReplicatedStorage.Client.Features.Emote.Utils.EmotePropAnimatorUtils)

return function()
	describe("EmotePropAnimatorUtils.canonical", function()
		it("turns any AnimationId form into rbxassetid://N", function()
			expect(EmotePropAnimatorUtils.canonical("rbxassetid://123")).to.equal("rbxassetid://123")
			expect(EmotePropAnimatorUtils.canonical("http://www.roblox.com/asset/?id=456")).to.equal("rbxassetid://456")
		end)

		it("leaves an id with no trailing digits as it is", function()
			expect(EmotePropAnimatorUtils.canonical("")).to.equal("")
			expect(EmotePropAnimatorUtils.canonical("none")).to.equal("none")
		end)
	end)

	describe("EmotePropAnimatorUtils.realSource", function()
		it("is nil until the character has an Animator", function()
			local model = Instance.new("Model")
			expect(EmotePropAnimatorUtils.realSource(model)).to.equal(nil)
			local humanoid = Instance.new("Humanoid")
			humanoid.Parent = model
			expect(EmotePropAnimatorUtils.realSource(model)).to.equal(nil)
			model:Destroy()
		end)

		it("finds the Animator under a Humanoid", function()
			local model = Instance.new("Model")
			local humanoid = Instance.new("Humanoid")
			humanoid.Parent = model
			Instance.new("Animator").Parent = humanoid
			local source = EmotePropAnimatorUtils.realSource(model)
			expect(source).to.be.ok()
			expect(typeof(source.playing)).to.equal("function")
			expect(typeof(source.onPlayed)).to.equal("function")
			model:Destroy()
		end)

		it("finds the Animator under an AnimationController", function()
			local model = Instance.new("Model")
			local controller = Instance.new("AnimationController")
			controller.Parent = model
			Instance.new("Animator").Parent = controller
			expect(EmotePropAnimatorUtils.realSource(model)).to.be.ok()
			model:Destroy()
		end)

		it("hands back a release for each onPlayed watch", function()
			local model = Instance.new("Model")
			local humanoid = Instance.new("Humanoid")
			humanoid.Parent = model
			Instance.new("Animator").Parent = humanoid
			local release = EmotePropAnimatorUtils.realSource(model).onPlayed(function() end)
			expect(typeof(release)).to.equal("function")
			release()
			model:Destroy()
		end)
	end)
end
