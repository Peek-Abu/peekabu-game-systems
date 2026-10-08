local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Uplink = require(ReplicatedStorage.Shared.Features.Replication.Net.ReplicationUplinkCodec)
local ReplicationUplinkSender = require(ReplicatedStorage.Client.Features.Replication.Net.ReplicationUplinkSender)

local function record(x, overrides)
	local r = {
		slot = 0,
		generation = 0,
		epoch = 1,
		ageMs = 0,
		position = Vector3.new(-1200 + x, 40, -350),
		yaw = 0,
		pitch = 0,
		velocity = Vector3.new(16, 0, 0),
		state = 8,
		grounded = true,
		hasAction = false,
		rotation = nil,
	}
	for key, value in overrides or {} do
		r[key] = value
	end
	return r
end

local function decode(packet)
	local ok, reason, uplink = Uplink.decode(packet)
	assert(ok, reason)
	return uplink
end

return function()
	it("sends a change, then for a still body only its two resends and the 1 Hz repair", function()
		local sender = ReplicationUplinkSender.new()
		local sends = {}
		for frame = 0, 72 do -- 1.2 s at 60 Hz, never moving
			local nowMs = math.floor(frame * 1000 / 60)
			if ReplicationUplinkSender.step(sender, nowMs, record(0)) ~= nil then
				table.insert(sends, nowMs)
			end
		end
		expect(#sends).to.equal(4)
		expect(sends[1]).to.equal(0)
		expect(sends[4] >= 1000).to.equal(true)
	end)

	it("never samples closer than 15 ms", function()
		local sender = ReplicationUplinkSender.new()
		expect(ReplicationUplinkSender.step(sender, 1000, record(0))).to.be.ok()
		expect(ReplicationUplinkSender.step(sender, 1010, record(1))).to.equal(nil)
		expect(ReplicationUplinkSender.step(sender, 1015, record(1))).to.be.ok()
	end)

	it("carries the current sample and the two previous sent ones, newest first", function()
		local sender = ReplicationUplinkSender.new()
		ReplicationUplinkSender.step(sender, 1000, record(0))
		ReplicationUplinkSender.step(sender, 1017, record(0.3))
		local uplink = decode(ReplicationUplinkSender.step(sender, 1034, record(0.6)))
		expect(uplink.sentMs).to.equal(1034)
		expect(#uplink.samples).to.equal(3)
		expect(uplink.samples[1].sampleMs).to.equal(1034)
		expect(uplink.samples[2].sampleMs).to.equal(1017)
		expect(uplink.samples[3].sampleMs).to.equal(1000)
		expect(uplink.samples[1].record.position.X).to.be.near(-1199.4, 0.02)
	end)

	it("leaves previous samples older than 1023 ms out of a repair", function()
		local sender = ReplicationUplinkSender.new()
		local last = nil
		for frame = 0, 150 do -- 2.5 s still: change, two resends, repairs at ~1.1 s and ~2.1 s
			local packet = ReplicationUplinkSender.step(sender, math.floor(frame * 1000 / 60), record(0))
			if packet ~= nil then
				last = packet
			end
		end
		local uplink = decode(last)
		for i = 2, #uplink.samples do
			expect(uplink.sentMs - uplink.samples[i].sampleMs <= 1023).to.equal(true)
		end
	end)

	it("reset forgets the previous body's samples", function()
		local sender = ReplicationUplinkSender.new()
		ReplicationUplinkSender.step(sender, 1000, record(0))
		ReplicationUplinkSender.reset(sender)
		local uplink = decode(ReplicationUplinkSender.step(sender, 1005, record(5, { epoch = 2 })))
		expect(#uplink.samples).to.equal(1)
	end)

	it("reports grounded from the state machine and the floor together", function()
		expect(ReplicationUplinkSender.isGrounded(Enum.HumanoidStateType.Running, Enum.Material.Plastic)).to.equal(true)
		expect(ReplicationUplinkSender.isGrounded(Enum.HumanoidStateType.Jumping, Enum.Material.Plastic)).to.equal(
			false
		)
		expect(ReplicationUplinkSender.isGrounded(Enum.HumanoidStateType.Freefall, Enum.Material.Plastic)).to.equal(
			false
		)
		expect(ReplicationUplinkSender.isGrounded(Enum.HumanoidStateType.Running, Enum.Material.Air)).to.equal(false)
	end)
end
