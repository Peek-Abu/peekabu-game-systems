local ServerScriptService = game:GetService("ServerScriptService")
local System = require(ServerScriptService.Features.Animation.Systems.AnimationVacuumSystem)
return function()
	local function fixture(available)
		local events = {}
		local sink = {
			play = function(id)
				table.insert(events, "play:" .. id)
				return available ~= false
			end,
			stop = function(id)
				table.insert(events, "stop:" .. id)
			end,
			available = function(_id)
				return available ~= false
			end,
		}
		return System.new(sink), events
	end
	local function snapshot(character, equipped, active, carrying, alive, authorized)
		return {
			character = character,
			equipped = equipped,
			active = active,
			carrying = carrying or false,
			alive = alive ~= false,
			authorized = authorized ~= false,
		}
	end
	describe("server vacuum animation lifecycle", function()
		it("plays equip once, then hold, then accepted suction and release", function()
			local rig = Instance.new("Model")
			local system, events = fixture()
			system.update(snapshot(rig, true, false), 0)
			system.update(snapshot(rig, true, false), 0.2)
			expect(#events).to.equal(1)
			system.update(snapshot(rig, true, false), 0.65)
			expect(events[3]).to.equal("play:cleanupVacuumHold")
			system.update(snapshot(rig, true, true), 1)
			expect(events[5]).to.equal("play:cleanupVacuumUse")
			system.update(snapshot(rig, true, false), 2)
			expect(events[7]).to.equal("play:cleanupVacuumHold")
			rig:Destroy()
		end)
		it("manual stow plays once and expires without replaying", function()
			local rig = Instance.new("Model")
			local system, events = fixture()
			system.update(snapshot(rig, true, false), 0)
			system.update(snapshot(rig, false, false), 0.1)
			expect(events[3]).to.equal("play:cleanupVacuumStow")
			system.update(snapshot(rig, false, false), 0.55)
			expect(events[4]).to.equal("stop:cleanupVacuumStow")
			system.update(snapshot(rig, false, false), 0.8)
			expect(#events).to.equal(4)
			rig:Destroy()
		end)
		it("carry, death and shift revocation cancel without a stow gesture", function()
			for _, blocked in { "carry", "death", "revoke" } do
				local rig = Instance.new("Model")
				local system, events = fixture()
				system.update(snapshot(rig, true, true), 0)
				system.update(
					snapshot(rig, false, false, blocked == "carry", blocked ~= "death", blocked ~= "revoke"),
					1
				)
				expect(events[#events]).to.equal("stop:cleanupVacuumEquip")
				expect(#events).to.equal(2)
				rig:Destroy()
			end
		end)
		it("respawn restarts equip and never keeps the old grant", function()
			local old, new = Instance.new("Model"), Instance.new("Model")
			local system, events = fixture()
			system.update(snapshot(old, true, false), 0)
			system.update(snapshot(new, true, false), 1)
			expect(events[2]).to.equal("stop:cleanupVacuumEquip")
			expect(events[3]).to.equal("play:cleanupVacuumEquip")
			old:Destroy()
			new:Destroy()
		end)
		it("unpublished clips never attempt loading", function()
			local rig = Instance.new("Model")
			local system, events = fixture(false)
			system.update(snapshot(rig, true, false), 0)
			system.update(snapshot(rig, true, true), 1)
			expect(#events).to.equal(0)
			rig:Destroy()
		end)
		it("a missing equip clip does not delay available hold or accepted suction", function()
			local rig = Instance.new("Model")
			local events = {}
			local system = System.new({
				available = function(id)
					return id ~= "cleanupVacuumEquip"
				end,
				play = function(id)
					table.insert(events, "play:" .. id)
					return true
				end,
				stop = function(id)
					table.insert(events, "stop:" .. id)
				end,
			})
			system.update(snapshot(rig, true, false), 0)
			expect(events[1]).to.equal("play:cleanupVacuumHold")
			system.update(snapshot(rig, true, true), 0.1)
			expect(events[3]).to.equal("play:cleanupVacuumUse")
			rig:Destroy()
		end)
		it("a refused animation grant retries without recording a false playing state", function()
			local rig = Instance.new("Model")
			local attempts = 0
			local stops = 0
			local system = System.new({
				available = function(_id)
					return true
				end,
				play = function(_id)
					attempts += 1
					return attempts > 1
				end,
				stop = function(_id)
					stops += 1
				end,
			})
			system.update(snapshot(rig, true, false), 0)
			system.update(snapshot(rig, true, false), 0.2)
			expect(attempts).to.equal(2)
			expect(stops).to.equal(0)
			system.stop()
			expect(stops).to.equal(1)
			rig:Destroy()
		end)
		it("stop is idempotent and next selection can equip", function()
			local rig = Instance.new("Model")
			local system, events = fixture()
			system.update(snapshot(rig, true, false), 0)
			system.stop()
			system.stop()
			expect(#events).to.equal(2)
			system.update(snapshot(rig, true, false), 1)
			expect(events[3]).to.equal("play:cleanupVacuumEquip")
			rig:Destroy()
		end)
	end)
end
