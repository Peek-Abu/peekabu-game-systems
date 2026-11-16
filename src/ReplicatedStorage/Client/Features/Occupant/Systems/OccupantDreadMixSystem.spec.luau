local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local OccupantDreadMixSystem = require(script.Parent.OccupantDreadMixSystem)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

return function()
	-- Each call gets a later clock, so the Music-group scan (every SCAN_INTERVAL) always runs.
	local clock = 1e7
	local function later()
		clock += 10
		return clock
	end

	local group, music, own
	beforeEach(function()
		OccupantDreadMixSystem.release()
		group = Instance.new("SoundGroup")
		group.Name = "Music"
		music = Instance.new("Sound")
		music.Name = "OccupantDreadMixSpecMusic"
		music.Volume = 0.5
		music.SoundGroup = group
		music.Parent = SoundService
		own = Instance.new("Sound")
		own.Name = "harlowDread"
		own.Volume = 0.5
		own.SoundGroup = group
		own.Parent = SoundService
	end)
	afterEach(function()
		OccupantDreadMixSystem.release()
		music:Destroy()
		own:Destroy()
		group:Destroy()
	end)

	describe("set", function()
		it("ducks and muffles another Music-group sound with an EQ", function()
			OccupantDreadMixSystem.set(later(), -12, -6)
			local eq = music:FindFirstChild("OccupantDreadEq")
			expect(eq).to.be.ok()
			expect(eq:IsA("EqualizerSoundEffect")).to.equal(true)
			expect(eq.Priority).to.equal(10)
			expect(eq.LowGain).to.be.near(-12, 1e-3)
			expect(eq.MidGain).to.be.near(-12 - 6 * OccupantConstants.DREAD.MUFFLE_MID, 1e-3)
			expect(eq.HighGain).to.be.near(-18, 1e-3)
			expect(OccupantDreadMixSystem.count() >= 1).to.equal(true)
		end)

		it("never touches the dread loop", function()
			OccupantDreadMixSystem.set(later(), -12, -6)
			expect(own:FindFirstChild("OccupantDreadEq")).never.to.be.ok()
		end)

		it("releases every EQ when the look has no duck or muffle", function()
			OccupantDreadMixSystem.set(later(), -12, -6)
			OccupantDreadMixSystem.set(later(), 0, 0)
			expect(music:FindFirstChild("OccupantDreadEq")).never.to.be.ok()
			expect(OccupantDreadMixSystem.count()).to.equal(0)
		end)
	end)

	describe("release", function()
		it("destroys every EQ it made", function()
			OccupantDreadMixSystem.set(later(), -12, -6)
			OccupantDreadMixSystem.release()
			expect(music:FindFirstChild("OccupantDreadEq")).never.to.be.ok()
			expect(OccupantDreadMixSystem.count()).to.equal(0)
		end)
	end)
end
