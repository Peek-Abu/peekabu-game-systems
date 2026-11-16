local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local SoundConstants = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundConstants)
local SoundGroupTracker = require(script.Parent.SoundGroupTracker)
local SoundVoicePool = require(script.Parent.SoundVoicePool)

return function()
	describe("placeOf", function()
		it("keeps a fixed point's voices in the Terrain, at that point", function()
			local where, point = SoundVoicePool.placeOf(Vector3.new(1, 2, 3))
			expect(where).to.equal(Workspace.Terrain)
			expect(point).to.equal(Vector3.new(1, 2, 3))
		end)

		it("keeps an instance's voices in the instance", function()
			local part = Instance.new("Part")
			local where, point = SoundVoicePool.placeOf(part)
			expect(where).to.equal(part)
			expect(point).to.equal(nil)
			part:Destroy()
		end)

		it("keeps a 2D play's voices in SoundService", function()
			local where, point = SoundVoicePool.placeOf(nil)
			expect(where).to.equal(SoundService)
			expect(point).to.equal(nil)
		end)
	end)

	describe("capOf", function()
		it("keeps IDLE_SHARED idle at the shared places", function()
			expect(SoundVoicePool.capOf(SoundService)).to.equal(SoundConstants.IDLE_SHARED)
			expect(SoundVoicePool.capOf(Workspace.Terrain)).to.equal(SoundConstants.IDLE_SHARED)
		end)

		it("keeps IDLE_PER_PLACE idle at any other place", function()
			local part = Instance.new("Part")
			expect(SoundVoicePool.capOf(part)).to.equal(SoundConstants.IDLE_PER_PLACE)
			part:Destroy()
		end)

		it("keeps a raised cap above the default", function()
			local part = Instance.new("Part")
			SoundVoicePool.caps[part] = SoundConstants.IDLE_PER_PLACE + 5
			expect(SoundVoicePool.capOf(part)).to.equal(SoundConstants.IDLE_PER_PLACE + 5)
			SoundVoicePool.caps[part] = nil
			part:Destroy()
		end)
	end)

	describe("configure", function()
		it("points a Sound at a registry entry", function()
			local sound = Instance.new("Sound")
			local def = {
				assetId = "rbxassetid://123",
				group = "SFX",
				volume = 0.5,
				looped = true,
				rollOffMinDistance = 20,
				rollOffMaxDistance = 80,
			}
			SoundVoicePool.configure(sound, "test.sound", def, 2, 1.5, nil)
			expect(sound.Name).to.equal("test.sound")
			expect(sound.SoundId).to.equal("rbxassetid://123")
			expect(sound.Volume).to.equal(1)
			expect(sound.PlaybackSpeed).to.equal(1.5)
			expect(sound.Looped).to.equal(true)
			expect(sound.SoundGroup).to.equal(SoundGroupTracker.groupFor("SFX"))
			expect(sound.RollOffMinDistance).to.equal(20)
			expect(sound.RollOffMaxDistance).to.equal(80)
			sound:Destroy()
		end)

		it("uses the default roll-off for an entry without one", function()
			local sound = Instance.new("Sound")
			local def = { assetId = "rbxassetid://123", group = "SFX", volume = 1 }
			SoundVoicePool.configure(sound, "test.sound", def, 1, 1, nil)
			expect(sound.Looped).to.equal(false)
			expect(sound.RollOffMinDistance).to.equal(SoundConstants.DEFAULT_ROLL_OFF_MIN)
			expect(sound.RollOffMaxDistance).to.equal(SoundConstants.DEFAULT_ROLL_OFF_MAX)
			sound:Destroy()
		end)
	end)
end
