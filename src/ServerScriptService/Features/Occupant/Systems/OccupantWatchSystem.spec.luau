local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerScriptService = game:GetService("ServerScriptService")

local OccupantWatchSystem = require(script.Parent.OccupantWatchSystem)
local OccupantWatchRules = require(ServerScriptService.Features.Occupant.Rules.OccupantWatchRules)
local C = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

-- A bare rig: a 2-stud root at y 5 (hip height 2), a head at y 7.5, and the kind attribute when given.
local function rig(kind)
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Position = Vector3.new(0, 5, 0)
	root.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1, 1, 1)
	head.Position = Vector3.new(0, 7.5, 0)
	head.Parent = model
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 2
	humanoid.Parent = model
	if kind ~= nil then
		model:SetAttribute(C.KIND_ATTRIBUTE, kind)
	end
	return { model = model, humanoid = humanoid, root = root, head = head }
end

return function()
	describe("parseReport", function()
		local function data(extra)
			local value = {
				position = Vector3.new(1, 2, 3),
				look = Vector3.new(0, 0, 4),
				up = Vector3.new(0, 2, 0),
				fov = 70,
				aspect = 16 / 9,
			}
			for key, item in extra or {} do
				value[key] = item
			end
			return value
		end

		it("keeps a finite camera with a unit look, an up square to it, and its screen", function()
			local report = OccupantWatchSystem.parseReport(data())
			expect(report).to.be.ok()
			expect(report.position).to.equal(Vector3.new(1, 2, 3))
			expect(report.look.Magnitude).to.be.near(1, 1e-6)
			expect(report.look.Z).to.be.near(1, 1e-6)
			expect(report.up.Magnitude).to.be.near(1, 1e-6)
			expect(report.up:Dot(report.look)).to.be.near(0, 1e-6)
			local tanV, tanH = OccupantWatchRules.screen(70, 16 / 9)
			expect(report.tanV).to.be.near(tanV, 1e-6)
			expect(report.tanH).to.be.near(tanH, 1e-6)
		end)

		it("squares a tilted up to the look, and falls back to world up for a broken one", function()
			local tilted = OccupantWatchSystem.parseReport(data({ up = Vector3.new(0, 1, 1) }))
			expect(tilted.up:Dot(tilted.look)).to.be.near(0, 1e-6)
			expect(tilted.up.Y).to.be.near(1, 1e-6)
			local broken = OccupantWatchSystem.parseReport(data({ up = Vector3.new(0, 0, 3) }))
			expect(broken.up:Dot(broken.look)).to.be.near(0, 1e-6)
		end)

		it("clamps a forged FOV and aspect to a real screen", function()
			local wide = OccupantWatchSystem.parseReport(data({ fov = 179, aspect = 40 }))
			local tanV, tanH = OccupantWatchRules.screen(C.FREEZE_FOV_MAX, C.FREEZE_ASPECT_MAX)
			expect(wide.tanV).to.be.near(tanV, 1e-6)
			expect(wide.tanH).to.be.near(tanH, 1e-6)
		end)

		it("refuses a zero look, NaN or infinity anywhere", function()
			local nan = 0 / 0
			expect(OccupantWatchSystem.parseReport(data({ look = Vector3.zero }))).to.equal(nil)
			expect(OccupantWatchSystem.parseReport(data({ position = Vector3.new(nan, 0, 0) }))).to.equal(nil)
			expect(OccupantWatchSystem.parseReport(data({ look = Vector3.new(math.huge, 0, 0) }))).to.equal(nil)
			expect(OccupantWatchSystem.parseReport(data({ fov = nan }))).to.equal(nil)
			expect(OccupantWatchSystem.parseReport(data({ aspect = math.huge }))).to.equal(nil)
		end)
	end)

	describe("points", function()
		it(
			"is every visible part of its body, the top of its head and its feet (owner 11-14: any of it on screen)",
			function()
				local body = rig("bramble")
				local wing = Instance.new("Part")
				wing.Name = "LeftHand"
				wing.Size = Vector3.new(1, 1, 1)
				wing.Position = Vector3.new(2, 5, 0)
				wing.Parent = body.model
				local hidden = Instance.new("Part")
				hidden.Name = "Hitbox"
				hidden.Transparency = 1
				hidden.Position = Vector3.new(9, 9, 9)
				hidden.Parent = body.model
				local points = OccupantWatchSystem.points(body)
				local function has(point)
					for _, item in points do
						if (item - point).Magnitude < 1e-3 then
							return true
						end
					end
					return false
				end
				expect(has(body.head.Position)).to.equal(true)
				expect(has(wing.Position)).to.equal(true)
				-- The top of the head (y 8) and the feet: the root's bottom (y 4) less the hip height, lifted FEET_LIFT.
				expect(has(Vector3.new(0, 8, 0))).to.equal(true)
				local lowest = math.huge
				for _, item in points do
					lowest = math.min(lowest, item.Y)
				end
				expect(lowest).to.be.near(2 + OccupantWatchSystem.FEET_LIFT, 1e-6)
				-- Never the invisible root or an invisible part.
				expect(has(body.root.Position)).to.equal(false)
				expect(has(hidden.Position)).to.equal(false)
				body.model:Destroy()
			end
		)
	end)

	describe("freezes", function()
		it("is only for a kind with the freeze twist: never Harlow", function()
			local bramble = rig("bramble")
			local harlow = rig("harlow")
			local bare = rig(nil)
			expect(OccupantWatchSystem.freezes(bramble.model)).to.equal(true)
			expect(OccupantWatchSystem.freezes(harlow.model)).to.equal(false)
			expect(OccupantWatchSystem.freezes(bare.model)).to.equal(false)
			bramble.model:Destroy()
			harlow.model:Destroy()
			bare.model:Destroy()
		end)
	end)

	describe("freezeFor", function()
		it("has no freeze for a rig it is not watching (Harlow's senses stay untouched)", function()
			local harlow = rig(nil)
			expect(OccupantWatchSystem.freezeFor(harlow.model)).to.equal(nil)
			harlow.model:Destroy()
		end)
	end)
end
