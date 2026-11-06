local FilmFlyFormulas = require(script.Parent.FilmFlyFormulas)

local function near(a, b)
	return (a - b).Magnitude < 1e-3
end

return function()
	describe("approach", function()
		it("eases toward the wanted velocity without overshooting", function()
			local v = Vector3.zero
			local wanted = Vector3.new(10, 0, 0)
			local last = 0
			for _ = 1, 30 do
				v = FilmFlyFormulas.approach(v, wanted, 1 / 60, 8)
				expect(v.X >= last).to.equal(true)
				expect(v.X <= 10).to.equal(true)
				last = v.X
			end
			expect(v.X > 9).to.equal(true)
		end)

		it("does not move with no time passing", function()
			expect(FilmFlyFormulas.approach(Vector3.zero, Vector3.new(5, 0, 0), 0, 8)).to.equal(Vector3.zero)
		end)
	end)

	describe("wanted", function()
		it("moves along the camera's own axes at the given speed", function()
			local camera = CFrame.lookAt(Vector3.zero, Vector3.new(1, 0, 0))
			-- W: forward is the camera's look.
			expect(near(FilmFlyFormulas.wanted(camera, Vector3.new(0, 0, -1), 10), Vector3.new(10, 0, 0))).to.equal(
				true
			)
			-- E: straight up in the world, whatever the look.
			expect(near(FilmFlyFormulas.wanted(camera, Vector3.new(0, 1, 0), 10), Vector3.new(0, 10, 0))).to.equal(true)
		end)

		it("keeps diagonal moves at the same speed", function()
			local wanted = FilmFlyFormulas.wanted(CFrame.identity, Vector3.new(1, 0, -1), 10)
			expect(math.abs(wanted.Magnitude - 10) < 1e-3).to.equal(true)
		end)

		it("is still with no keys held", function()
			expect(FilmFlyFormulas.wanted(CFrame.identity, Vector3.zero, 10)).to.equal(Vector3.zero)
		end)
	end)

	describe("look", function()
		it("turns with the mouse and stops short of straight up or down", function()
			local yaw, pitch = FilmFlyFormulas.look(0, 0, Vector2.new(100, 0), 0.2)
			expect(math.abs(yaw - math.rad(-20)) < 1e-6).to.equal(true)
			expect(pitch).to.equal(0)
			local _, high = FilmFlyFormulas.look(0, 0, Vector2.new(0, -10000), 0.2)
			expect(high <= math.rad(FilmFlyFormulas.MAX_PITCH) + 1e-9).to.equal(true)
			local _, low = FilmFlyFormulas.look(0, 0, Vector2.new(0, 10000), 0.2)
			expect(low >= -math.rad(FilmFlyFormulas.MAX_PITCH) - 1e-9).to.equal(true)
		end)
	end)

	describe("speed", function()
		it("steps up and down by the wheel and stays in range", function()
			local faster = FilmFlyFormulas.speed(10, 1)
			expect(faster > 10).to.equal(true)
			expect(FilmFlyFormulas.speed(faster, -1)).to.be.near(10, 1e-6)
			expect(FilmFlyFormulas.speed(10, 100)).to.equal(FilmFlyFormulas.MAX_SPEED)
			expect(FilmFlyFormulas.speed(10, -100)).to.equal(FilmFlyFormulas.MIN_SPEED)
		end)
	end)

	describe("orbit", function()
		it("turns the offset around the target, keeping its height and distance", function()
			local offset = FilmFlyFormulas.orbit(Vector3.new(10, 3, 0), 90)
			expect(near(offset, Vector3.new(0, 3, -10))).to.equal(true)
		end)
	end)

	describe("fov", function()
		it("zooms within range", function()
			expect(FilmFlyFormulas.fov(70, -1000)).to.equal(FilmFlyFormulas.MIN_FOV)
			expect(FilmFlyFormulas.fov(70, 1000)).to.equal(FilmFlyFormulas.MAX_FOV)
			expect(FilmFlyFormulas.fov(70, 5)).to.equal(75)
		end)
	end)
end
