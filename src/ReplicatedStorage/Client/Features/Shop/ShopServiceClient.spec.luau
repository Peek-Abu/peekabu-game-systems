local ShopServiceClient = require(script.Parent.ShopServiceClient)

return function()
	it("shows today's shop at the server clock", function()
		local live = ShopServiceClient:live()
		expect(live.featured).to.be.ok()
		expect(#live.picks > 0).to.equal(true)
		expect(live.nextRotation > workspace:GetServerTimeNow()).to.equal(true)
	end)

	it("finds offers by id and ignores a buy of an unknown one", function()
		expect(ShopServiceClient:offer("Prickles").currency).to.equal("credits")
		expect(ShopServiceClient:offer("Nope")).to.equal(nil)
		expect(function()
			ShopServiceClient:requestBuy("Nope")
		end).never.to.throw()
	end)
end
