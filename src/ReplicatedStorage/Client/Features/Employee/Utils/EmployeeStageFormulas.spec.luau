local EmployeeStageFormulas = require(script.Parent.EmployeeStageFormulas)

return function()
	local SCREEN = Vector2.new(1600, 900)
	local FOV = 40

	-- Where a world point lands on the screen (pixels) for a camera frame with this vertical field of view.
	local function project(camera, point)
		local p = camera:PointToObjectSpace(point)
		local t = math.tan(math.rad(FOV) / 2)
		local aspect = SCREEN.X / SCREEN.Y
		local x = (0.5 + (p.X / -p.Z) / (2 * t * aspect)) * SCREEN.X
		local y = (0.5 - (p.Y / -p.Z) / (2 * t)) * SCREEN.Y
		return Vector2.new(x, y), -p.Z
	end

	local bounds = { min = Vector3.new(-1, 0, -1), max = Vector3.new(1, 6, 1) }
	local rect = { position = Vector2.new(900, 100), size = Vector2.new(600, 700) }
	local front = CFrame.new(10, 3000, -4)

	describe("camera", function()
		it("puts the model's centre on the window's centre", function()
			local camera = EmployeeStageFormulas.camera(bounds, rect, SCREEN, FOV, front)
			local centre = project(camera, Vector3.new(0, 3, 0) + front.Position)
			expect((centre - (rect.position + rect.size / 2)).Magnitude < 1).to.equal(true)
		end)

		it("fills FILL of the window's height with the model, seen from its front", function()
			local camera = EmployeeStageFormulas.camera(bounds, rect, SCREEN, FOV, front)
			local top, depth = project(camera, Vector3.new(0, 6, 0) + front.Position)
			local bottom = project(camera, front.Position)
			expect(math.abs((bottom.Y - top.Y) - EmployeeStageFormulas.FILL * rect.size.Y) < 1).to.equal(true)
			expect(depth > 0).to.equal(true)
			-- in front of the model: the camera sits on the model's front side, looking back along its LookVector
			expect(front.LookVector:Dot(camera.Position - front.Position) > 0).to.equal(true)
		end)

		it("fits a wide model by its width when that is the tighter side", function()
			local wide = { min = Vector3.new(-6, 0, -1), max = Vector3.new(6, 3, 1) }
			local camera = EmployeeStageFormulas.camera(wide, rect, SCREEN, FOV, front)
			local left = project(camera, Vector3.new(-6, 1.5, 0) + front.Position)
			local right = project(camera, Vector3.new(6, 1.5, 0) + front.Position)
			expect(math.abs(left.X - right.X) <= EmployeeStageFormulas.FILL * rect.size.X + 1).to.equal(true)
		end)
	end)

	describe("wall", function()
		it("fills the whole screen behind the model, facing the camera", function()
			local camera = EmployeeStageFormulas.camera(bounds, rect, SCREEN, FOV, front)
			local wall, size = EmployeeStageFormulas.wall(camera, SCREEN, FOV, 30)
			local half = size / 2
			local low, high = Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge)
			for _, corner in { Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(1, 1) } do
				local point = wall:PointToWorldSpace(Vector3.new(corner.X * half.X, corner.Y * half.Y, 0))
				local onScreen = project(camera, point)
				low, high = low:Min(onScreen), high:Max(onScreen)
			end
			-- its corners reach the screen's edges (or past them) on every side
			expect(low.X <= 1 and low.Y <= 1).to.equal(true)
			expect(high.X >= SCREEN.X - 1 and high.Y >= SCREEN.Y - 1).to.equal(true)
			expect(wall.LookVector:Dot(camera.LookVector) < -0.999).to.equal(true)
		end)
	end)
	describe("lighting", function()
		it("lights the stage flat and bright, with no shadows, fog or sky light that change with the place", function()
			local light = EmployeeStageFormulas.LIGHTING
			expect(light.GlobalShadows).to.equal(false)
			expect(light.FogEnd >= 100000).to.equal(true)
			expect(light.EnvironmentDiffuseScale).to.equal(0)
			expect(light.ExposureCompensation).to.equal(0)
			for _, color in { light.Ambient, light.OutdoorAmbient } do
				expect(math.min(color.R, color.G, color.B) >= 0.5).to.equal(true)
			end
		end)

		it("puts back only what still holds the stage's value (a time-of-day change meanwhile is kept)", function()
			local saved = { ClockTime = 18.3, Brightness = 1.4, GlobalShadows = true }
			local now = {
				ClockTime = 21, -- changed by the place while the stage was up
				Brightness = EmployeeStageFormulas.LIGHTING.Brightness,
				GlobalShadows = EmployeeStageFormulas.LIGHTING.GlobalShadows,
			}
			local back = EmployeeStageFormulas.restore(saved, now)
			expect(back.ClockTime).to.equal(nil)
			expect(back.Brightness).to.equal(1.4)
			expect(back.GlobalShadows).to.equal(true)
		end)

		it("counts a value read back a hair off (float32) as still the stage's", function()
			local light = EmployeeStageFormulas.LIGHTING
			local back = EmployeeStageFormulas.restore({ Brightness = 1.4, Ambient = Color3.new(0, 0, 0) }, {
				Brightness = light.Brightness + 1e-6,
				Ambient = Color3.new(light.Ambient.R + 1e-5, light.Ambient.G, light.Ambient.B),
			})
			expect(back.Brightness).to.equal(1.4)
			expect(back.Ambient).to.equal(Color3.new(0, 0, 0))
		end)
	end)
end
