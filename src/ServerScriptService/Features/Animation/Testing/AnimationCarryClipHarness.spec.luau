-- The carry validator's clips: a live frame is sampled only once its clip has loaded, at the sampled time and full
-- weight; a clip that never loads is reported instead of sampled as the rest pose.
local ServerScriptService = game:GetService("ServerScriptService")
local ClipHarness = require(ServerScriptService.Features.Animation.Testing.AnimationCarryClipHarness)
local RigHarness = require(ServerScriptService.Features.Animation.Testing.AnimationCarryRigHarness)
return function()
	it("shows a live frame only once its clip has loaded, at the sampled time and full weight", function()
		local rig = RigHarness.stockR15(Vector3.new(0, 3000, -640))
		local carriers = RigHarness.carriers({ "StockR15" })
		local walk = carriers[1].walk
		carriers[1].model:Destroy()
		-- A clip id that never loads is reported, not sampled as the rest pose.
		local missing, why = ClipHarness.show(RigHarness.animator(rig), "rbxassetid://0", 0.6, 1)
		expect(missing).to.equal(nil)
		expect(why).to.be.ok()
		if walk ~= nil then
			local track, problem = ClipHarness.show(RigHarness.animator(rig), walk, 0.6)
			expect(problem).to.equal(nil)
			expect(track.Length > 0).to.equal(true)
			RigHarness.settle(4)
			expect(ClipHarness.shown(track, 0.6)).to.equal(nil)
			track:Stop(0)
			track:Destroy()
		end
		rig:Destroy()
	end)
end
