local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HidePromptUtils = require(script.Parent.HidePromptUtils)
local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)

return function()
	local function prompt(name, parent)
		local p = Instance.new("ProximityPrompt")
		p.Name = name
		p.Parent = parent
		return p
	end

	describe("isHidePrompt", function()
		it("is true for the hiding prompt on a tagged spot anchor", function()
			local anchor = Instance.new("Attachment")
			anchor:AddTag(HideConstants.SPOT_TAG)
			expect(HidePromptUtils.isHidePrompt(prompt(HideConstants.PROMPT_NAME, anchor))).to.equal(true)
			anchor:Destroy()
		end)

		it("is true on a reach side carrying the spot's id", function()
			local reach = Instance.new("Attachment")
			reach.Name = HideConstants.REACH_NAME
			reach:SetAttribute(HideConstants.SPOT_ID_ATTRIBUTE, "spec")
			expect(HidePromptUtils.isHidePrompt(prompt(HideConstants.PROMPT_NAME, reach))).to.equal(true)
			reach:Destroy()
		end)

		it("is false for another prompt, an untagged parent, no parent or a non-prompt", function()
			local anchor = Instance.new("Attachment")
			anchor:AddTag(HideConstants.SPOT_TAG)
			expect(HidePromptUtils.isHidePrompt(prompt(HideConstants.PROMPT_NAME .. "Other", anchor))).to.equal(false)
			local plain = Instance.new("Attachment")
			expect(HidePromptUtils.isHidePrompt(prompt(HideConstants.PROMPT_NAME, plain))).to.equal(false)
			expect(HidePromptUtils.isHidePrompt(prompt(HideConstants.PROMPT_NAME, nil))).to.equal(false)
			local folder = Instance.new("Folder")
			folder.Name = HideConstants.PROMPT_NAME
			folder.Parent = anchor
			expect(HidePromptUtils.isHidePrompt(folder)).to.equal(false)
			anchor:Destroy()
			plain:Destroy()
		end)
	end)

	describe("spotAnchor", function()
		it("is nil for a spot that is not in the world", function()
			expect(HidePromptUtils.spotAnchor("no-such-spot-spec")).to.equal(nil)
		end)
	end)
end
