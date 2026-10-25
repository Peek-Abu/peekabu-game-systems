local CalloutStickerSystem = require(script.Parent.CalloutStickerSystem)

return function()
	local function character()
		local model = Instance.new("Model")
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Parent = model
		return model, head
	end

	it("puts the sticker over the head, replacing one already showing", function()
		local model, head = character()
		local first = CalloutStickerSystem.show(model, "rbxassetid://1", true)
		expect(first.Parent).to.equal(head)
		expect(first.Picture.Image).to.equal("rbxassetid://1")
		local second = CalloutStickerSystem.show(model, "rbxassetid://2", true)
		expect(first.Parent).never.to.be.ok()
		expect(#head:GetChildren()).to.equal(1)
		expect(second.Picture.Image).to.equal("rbxassetid://2")
		model:Destroy()
	end)

	it("shows nothing on a body with no head or root", function()
		expect(CalloutStickerSystem.show(Instance.new("Model"), "rbxassetid://1", true)).never.to.be.ok()
	end)
end
