local Server = game:GetService("ServerScriptService").Features.Depot
local Build = require(script.Parent.DepotBuildSystem)
local Layout = require(Server.Data.DepotLayoutConstants).LAYOUT
return function()
	local built
	afterEach(function()
		if built then
			built.model:Destroy()
			built = nil
		end
	end)
	describe("physical enclosure", function()
		it("builds collidable visible ceiling geometry", function()
			built = Build.build(Layout, CFrame.new(50000, 0, 0), {})
			local ceiling = built.model:FindFirstChild("Ceiling", true)
			expect(ceiling ~= nil).to.equal(true)
			expect(ceiling.CanCollide).to.equal(true)
			expect(ceiling.Transparency).to.equal(0)
		end)
		it("uses physical surfaces for contract/results and keeps truck tags camera-facing", function()
			built = Build.build(Layout, CFrame.new(50000, 0, 0), {})
			local contract = built.model:FindFirstChild("ContractSign", true)
			local result = built.model:FindFirstChild("ResultSign", true)
			expect(contract:IsA("SurfaceGui")).to.equal(true)
			expect(result:IsA("SurfaceGui")).to.equal(true)
			expect(contract.AlwaysOnTop).to.equal(false)
			expect(contract.Adornee).to.equal(built.contractBoard)
			expect(built.model:FindFirstChild("PadTag", true):IsA("BillboardGui")).to.equal(true)
		end)
	end)
end
