-- The motion layers the vacuum hold validator lays on every frame (split out of AnimationVacuumHarness).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local VacuumMotionConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumMotionConstants)
local Layers = require(ServerScriptService.Features.Animation.Testing.AnimationVacuumLayerHarness)

return function()
	local function find(name)
		for _, layer in Layers.LAYERS do
			if layer.name == name then
				return layer.layers
			end
		end
		return nil
	end

	it("lists every layer extreme in order", function()
		local names = {}
		for _, layer in Layers.LAYERS do
			table.insert(names, layer.name)
		end
		expect(table.concat(names, ",")).to.equal(table.concat({
			"rest",
			"aim up",
			"aim out",
			"aim in",
			"brace",
			"brace+out",
			"brace+in",
			"brace+up",
			"recoil",
			"recoil back",
			"recoil+up",
			"shimmy+",
			"shimmy-",
			"sway left",
			"sway right",
			"sway stop",
			"sway+up",
			"aim left",
			"aim right",
			"brace+left",
			"brace+right",
			"all",
		}, ","))
	end)

	it("lays every layer off at rest", function()
		local rest = find("rest")
		for _, key in
			{ "raise", "reach", "brace", "kick", "shimmyYaw", "shimmyRoll", "swayYaw", "swayPitch", "lookYaw" }
		do
			expect(rest[key]).to.equal(0)
		end
	end)

	it("takes each extreme from VacuumMotionConstants", function()
		expect(find("aim up").raise).to.equal(VacuumMotionConstants.aim.maxUp)
		expect(find("recoil").kick).to.equal(VacuumMotionConstants.kick.maxScale)
		expect(find("shimmy+").shimmyYaw).to.equal(VacuumMotionConstants.shimmy.yaw)
		expect(find("shimmy-").shimmyRoll).to.equal(-VacuumMotionConstants.shimmy.roll)
		expect(find("sway left").swayYaw).to.equal(VacuumMotionConstants.sway.maxYaw)
		expect(find("aim right").lookYaw).to.equal(-VacuumMotionConstants.aim.maxLook)
	end)
end
