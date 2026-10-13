local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToonConstants = require(ReplicatedStorage.Shared.Features.Toon.Data.ToonConstants)
local ToonExpressionSystem = require(script.Parent.ToonExpressionSystem)

return function()
	local function makeToon(position)
		local model = Instance.new("Model")
		model:SetAttribute(ToonConstants.NAME_ATTRIBUTE, "Pippa")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Anchored = true
		root.CFrame = CFrame.new(position)
		root.Parent = model
		model.PrimaryPart = root
		return model
	end

	local function sources(state)
		return {
			mind = function()
				return state.mind
			end,
			managerPosition = function()
				return state.manager
			end,
			now = function()
				return state.now
			end,
		}
	end

	local function mind(mode, target)
		return { mode = mode, since = 0, routeIndex = 1, routeStep = 1, target = target, grace = {} }
	end

	describe("tick", function()
		it("is Content with no Manager around and nothing to do", function()
			local state = { now = 0 }
			local system = ToonExpressionSystem.new(sources(state))
			local toon = makeToon(Vector3.new())
			system.tick({ { userId = 1, character = toon, busy = false } })
			expect(toon:GetAttribute(ToonConstants.FACE_ATTRIBUTE)).to.equal("Content")
			toon:Destroy()
		end)

		it("is Happy while busy and for the linger window after", function()
			local state = { now = 0 }
			local system = ToonExpressionSystem.new(sources(state))
			local toon = makeToon(Vector3.new())
			system.tick({ { userId = 1, character = toon, busy = true } })
			expect(toon:GetAttribute(ToonConstants.FACE_ATTRIBUTE)).to.equal("Happy")
			state.now = ToonConstants.HAPPY_LINGER / 2
			system.tick({ { userId = 1, character = toon, busy = false } })
			expect(toon:GetAttribute(ToonConstants.FACE_ATTRIBUTE)).to.equal("Happy")
			state.now = ToonConstants.HAPPY_LINGER + 1
			system.tick({ { userId = 1, character = toon, busy = false } })
			expect(toon:GetAttribute(ToonConstants.FACE_ATTRIBUTE)).to.equal("Content")
			toon:Destroy()
		end)

		it("is Worried for the chased player and for anyone near an alert Manager", function()
			local state = { now = 0, mind = mind("chase", 7), manager = Vector3.new(0, 0, 0) }
			local system = ToonExpressionSystem.new(sources(state))
			local chased = makeToon(Vector3.new(200, 0, 0))
			local near = makeToon(Vector3.new(ToonConstants.WORRIED_RADIUS - 5, 0, 0))
			local far = makeToon(Vector3.new(0, 0, ToonConstants.WORRIED_RADIUS + 50))
			system.tick({
				{ userId = 7, character = chased, busy = true },
				{ userId = 8, character = near, busy = false },
				{ userId = 9, character = far, busy = false },
			})
			expect(chased:GetAttribute(ToonConstants.FACE_ATTRIBUTE)).to.equal("Worried")
			expect(near:GetAttribute(ToonConstants.FACE_ATTRIBUTE)).to.equal("Worried")
			expect(far:GetAttribute(ToonConstants.FACE_ATTRIBUTE)).to.equal("Content")
			chased:Destroy()
			near:Destroy()
			far:Destroy()
		end)

		it("leaves non-toon characters alone", function()
			local state = { now = 0 }
			local system = ToonExpressionSystem.new(sources(state))
			local plain = Instance.new("Model")
			system.tick({ { userId = 1, character = plain, busy = true } })
			expect(plain:GetAttribute(ToonConstants.FACE_ATTRIBUTE)).never.to.be.ok()
			plain:Destroy()
		end)

		it("forgets a player's busy history", function()
			local state = { now = 0 }
			local system = ToonExpressionSystem.new(sources(state))
			local toon = makeToon(Vector3.new())
			system.tick({ { userId = 1, character = toon, busy = true } })
			system.forget(1)
			system.tick({ { userId = 1, character = toon, busy = false } })
			expect(toon:GetAttribute(ToonConstants.FACE_ATTRIBUTE)).to.equal("Content")
			expect(system.getState().faces.Content).to.equal(1)
			toon:Destroy()
		end)
	end)
end
