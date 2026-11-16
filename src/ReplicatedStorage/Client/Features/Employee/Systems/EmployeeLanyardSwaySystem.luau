--!strict
--[=[
	EmployeeLanyardSwaySystem: the sleeping badge sway spring on a built lanyard: `RenderStepped` runs only while the
	torso accelerates (woken by the Humanoid's running, state and move-direction signals) and disconnects after 0.4 s
	at rest, so it costs nothing while still. Split out of EmployeeLanyardSystem.

	@class EmployeeLanyardSwaySystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EmployeeLanyardFormulas = require(ReplicatedStorage.Shared.Features.Employee.Utils.EmployeeLanyardFormulas)
local EmployeeClient = ReplicatedStorage.Client.Features.Employee
local EmployeeLanyardTypes = require(EmployeeClient.Data.EmployeeLanyardTypes)
local EmployeeLanyardPartUtils = require(EmployeeClient.Utils.EmployeeLanyardPartUtils)

type Fit = EmployeeLanyardFormulas.Fit
type Handle = EmployeeLanyardTypes.Handle

local v3 = EmployeeLanyardPartUtils.v3

local EmployeeLanyardSwaySystem = {}

-- Starts the badge sway on `handle`'s badge weld; returns the stop.
function EmployeeLanyardSwaySystem.sway(character: Model, fit: Fit, rank: number, handle: Handle): () -> ()
	local hum = character:FindFirstChildOfClass("Humanoid")
	local ut = character:FindFirstChild("UpperTorso")
	local weld = handle.badgeWeld
	if hum == nil or ut == nil or not ut:IsA("BasePart") or weld == nil then
		return function() end
	end
	local scale = ut.Size.X / fit.ut_size[1]
	local pv = v3(fit.pivot_rbx) * scale
	local spring = EmployeeLanyardFormulas.newSpring()
	local conn: RBXScriptConnection? = nil
	local lastV = ut.CFrame:VectorToObjectSpace(ut.AssemblyLinearVelocity)
	local still = 0
	local function frame(dt: number)
		local v = ut.CFrame:VectorToObjectSpace(ut.AssemblyLinearVelocity)
		local acc = (v - lastV) / math.max(dt, 1 / 240)
		lastV = v
		local p, r, y, moving =
			EmployeeLanyardFormulas.step(fit, rank, spring, { acc.X, acc.Y, acc.Z }, math.min(dt, 1 / 30))
		weld.C0 = CFrame.new(pv)
			* CFrame.Angles(math.rad(p), 0, 0)
			* CFrame.Angles(0, 0, math.rad(r))
			* CFrame.Angles(0, math.rad(y), 0)
		still = if moving then 0 else still + dt
		if still > 0.4 and conn ~= nil then
			conn:Disconnect()
			conn = nil
		end
	end
	local function wake()
		if conn == nil then
			still = 0
			lastV = ut.CFrame:VectorToObjectSpace(ut.AssemblyLinearVelocity)
			conn = RunService.RenderStepped:Connect(frame)
		end
	end
	local c1 = hum.Running:Connect(wake)
	local c2 = hum.StateChanged:Connect(wake)
	local c3 = hum:GetPropertyChangedSignal("MoveDirection"):Connect(wake)
	return function()
		c1:Disconnect()
		c2:Disconnect()
		c3:Disconnect()
		if conn ~= nil then
			conn:Disconnect()
		end
	end
end

return EmployeeLanyardSwaySystem
