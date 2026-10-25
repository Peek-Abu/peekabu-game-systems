local CalloutPingSystem = require(script.Parent.CalloutPingSystem)

return function()
	it("marks the spot with the ping's icon, word and sender, one marker per sender", function()
		local folder = Instance.new("Folder")
		local marker =
			{ userId = 4, image = "rbxassetid://9", word = "Gloom here", who = "Pippa", at = Vector3.new(1, 2, 3) }
		local first = CalloutPingSystem.show(folder, marker)
		expect(first.Position).to.equal(Vector3.new(1, 2, 3))
		expect(first.Marker.Word.Text).to.equal("Gloom here")
		expect(first.Marker.Who.Text).to.equal("Pippa")
		expect(first.Marker.AlwaysOnTop).to.equal(true)
		marker.at = Vector3.new(5, 5, 5)
		CalloutPingSystem.show(folder, marker)
		expect(#folder:GetChildren()).to.equal(1)
		folder:Destroy()
	end)
end
