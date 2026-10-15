local ReplicatedStorage = game:GetService("ReplicatedStorage")
return function()
	it("shares the approved renderer with client visual effects", function()
		expect(require(script.Parent.ArtVisualSystem)).to.equal(
			require(ReplicatedStorage.Shared.Features.Art.Systems.ArtVisualSystem)
		)
	end)
end
