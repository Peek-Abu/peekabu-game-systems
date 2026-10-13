local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeExpressionSystem = require(script.Parent.EmployeeExpressionSystem)

return function()
	local FACE = EmployeeConstants.FACE_ATTRIBUTE

	local function makeEmployee(position, name)
		local model = Instance.new("Model")
		model:SetAttribute(EmployeeConstants.NAME_ATTRIBUTE, name or "Pippa")
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

	local function subject(userId, character, vacuuming, carrying)
		return { userId = userId, character = character, vacuuming = vacuuming, carrying = carrying }
	end

	describe("tick", function()
		it("shows Pippa's idle face with no Manager around and nothing to do", function()
			local state = { now = 0 }
			local system = EmployeeExpressionSystem.new(sources(state))
			local employee = makeEmployee(Vector3.new())
			system.tick({ subject(1, employee, false, false) })
			expect(employee:GetAttribute(FACE)).to.equal("Content")
			employee:Destroy()
		end)

		it("shows Pippa's cleaning face while vacuuming and for the short tail after", function()
			local state = { now = 0 }
			local system = EmployeeExpressionSystem.new(sources(state))
			local employee = makeEmployee(Vector3.new())
			system.tick({ subject(1, employee, true, false) })
			expect(employee:GetAttribute(FACE)).to.equal("Happy")
			state.now = EmployeeConstants.CLEANING_LINGER / 2
			system.tick({ subject(1, employee, false, false) })
			expect(employee:GetAttribute(FACE)).to.equal("Happy")
			state.now = EmployeeConstants.CLEANING_LINGER + 1
			system.tick({ subject(1, employee, false, false) })
			expect(employee:GetAttribute(FACE)).to.equal("Content")
			employee:Destroy()
		end)

		it("does not make carrying cargo Happy for Pippa", function()
			local state = { now = 0 }
			local system = EmployeeExpressionSystem.new(sources(state))
			local employee = makeEmployee(Vector3.new())
			system.tick({ subject(1, employee, false, true) })
			expect(employee:GetAttribute(FACE)).to.equal("Content")
			-- Banking (the pockets empty) is not a happy moment either.
			state.now = 1
			system.tick({ subject(1, employee, false, false) })
			expect(employee:GetAttribute(FACE)).to.equal("Content")
			employee:Destroy()
		end)

		it("is Worried for the chased player and for anyone near an alert Manager", function()
			local state = { now = 0, mind = mind("chase", 7), manager = Vector3.new(0, 0, 0) }
			local system = EmployeeExpressionSystem.new(sources(state))
			local chased = makeEmployee(Vector3.new(200, 0, 0))
			local near = makeEmployee(Vector3.new(EmployeeConstants.WORRIED_RADIUS - 5, 0, 0))
			local far = makeEmployee(Vector3.new(0, 0, EmployeeConstants.WORRIED_RADIUS + 50))
			system.tick({
				subject(7, chased, true, true),
				subject(8, near, false, false),
				subject(9, far, false, false),
			})
			expect(chased:GetAttribute(FACE)).to.equal("Worried")
			expect(near:GetAttribute(FACE)).to.equal("Worried")
			expect(far:GetAttribute(FACE)).to.equal("Content")
			chased:Destroy()
			near:Destroy()
			far:Destroy()
		end)

		it("leaves non-employee characters and unknown employees alone", function()
			local state = { now = 0 }
			local system = EmployeeExpressionSystem.new(sources(state))
			local plain = Instance.new("Model")
			local stranger = makeEmployee(Vector3.new(), "Nobody")
			system.tick({ subject(1, plain, true, false), subject(2, stranger, true, false) })
			expect(plain:GetAttribute(FACE)).never.to.be.ok()
			expect(stranger:GetAttribute(FACE)).never.to.be.ok()
			plain:Destroy()
			stranger:Destroy()
		end)

		it("forgets a player's cleaning history", function()
			local state = { now = 0 }
			local system = EmployeeExpressionSystem.new(sources(state))
			local employee = makeEmployee(Vector3.new())
			system.tick({ subject(1, employee, true, false) })
			system.forget(1)
			system.tick({ subject(1, employee, false, false) })
			expect(employee:GetAttribute(FACE)).to.equal("Content")
			expect(system.getState().faces.Content).to.equal(1)
			employee:Destroy()
		end)
	end)
end
