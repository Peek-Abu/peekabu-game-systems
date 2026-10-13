local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeExpressionSystem = require(script.Parent.EmployeeExpressionSystem)

return function()
	local function makeEmployee(position)
		local model = Instance.new("Model")
		model:SetAttribute(EmployeeConstants.NAME_ATTRIBUTE, "Pippa")
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
			local system = EmployeeExpressionSystem.new(sources(state))
			local employee = makeEmployee(Vector3.new())
			system.tick({ { userId = 1, character = employee, busy = false } })
			expect(employee:GetAttribute(EmployeeConstants.FACE_ATTRIBUTE)).to.equal("Content")
			employee:Destroy()
		end)

		it("is Happy while busy and for the linger window after", function()
			local state = { now = 0 }
			local system = EmployeeExpressionSystem.new(sources(state))
			local employee = makeEmployee(Vector3.new())
			system.tick({ { userId = 1, character = employee, busy = true } })
			expect(employee:GetAttribute(EmployeeConstants.FACE_ATTRIBUTE)).to.equal("Happy")
			state.now = EmployeeConstants.HAPPY_LINGER / 2
			system.tick({ { userId = 1, character = employee, busy = false } })
			expect(employee:GetAttribute(EmployeeConstants.FACE_ATTRIBUTE)).to.equal("Happy")
			state.now = EmployeeConstants.HAPPY_LINGER + 1
			system.tick({ { userId = 1, character = employee, busy = false } })
			expect(employee:GetAttribute(EmployeeConstants.FACE_ATTRIBUTE)).to.equal("Content")
			employee:Destroy()
		end)

		it("is Worried for the chased player and for anyone near an alert Manager", function()
			local state = { now = 0, mind = mind("chase", 7), manager = Vector3.new(0, 0, 0) }
			local system = EmployeeExpressionSystem.new(sources(state))
			local chased = makeEmployee(Vector3.new(200, 0, 0))
			local near = makeEmployee(Vector3.new(EmployeeConstants.WORRIED_RADIUS - 5, 0, 0))
			local far = makeEmployee(Vector3.new(0, 0, EmployeeConstants.WORRIED_RADIUS + 50))
			system.tick({
				{ userId = 7, character = chased, busy = true },
				{ userId = 8, character = near, busy = false },
				{ userId = 9, character = far, busy = false },
			})
			expect(chased:GetAttribute(EmployeeConstants.FACE_ATTRIBUTE)).to.equal("Worried")
			expect(near:GetAttribute(EmployeeConstants.FACE_ATTRIBUTE)).to.equal("Worried")
			expect(far:GetAttribute(EmployeeConstants.FACE_ATTRIBUTE)).to.equal("Content")
			chased:Destroy()
			near:Destroy()
			far:Destroy()
		end)

		it("leaves non-employee characters alone", function()
			local state = { now = 0 }
			local system = EmployeeExpressionSystem.new(sources(state))
			local plain = Instance.new("Model")
			system.tick({ { userId = 1, character = plain, busy = true } })
			expect(plain:GetAttribute(EmployeeConstants.FACE_ATTRIBUTE)).never.to.be.ok()
			plain:Destroy()
		end)

		it("forgets a player's busy history", function()
			local state = { now = 0 }
			local system = EmployeeExpressionSystem.new(sources(state))
			local employee = makeEmployee(Vector3.new())
			system.tick({ { userId = 1, character = employee, busy = true } })
			system.forget(1)
			system.tick({ { userId = 1, character = employee, busy = false } })
			expect(employee:GetAttribute(EmployeeConstants.FACE_ATTRIBUTE)).to.equal("Content")
			expect(system.getState().faces.Content).to.equal(1)
			employee:Destroy()
		end)
	end)
end
