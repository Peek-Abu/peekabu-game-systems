--!strict
--[=[
	Unit tests for CustomizationPublishSystem: when a player's look goes onto the public slice. Driven with fake
	profile reads and the real StateSyncPublicPlayerStore. The staging bugs it pins: a same-server rejoin published
	nothing (viewers drew the empty placeholder), and a profile that loads after the spawn was never published.
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local CustomizationPublishSystem = require(script.Parent.CustomizationPublishSystem)
local StateSyncPublicPlayerStore = require(ServerScriptService.Features.StateSync.State.StateSyncPublicPlayerStore)

local USER = 980001

return function()
	local function look(hair: string?): any
		return {
			cosmetics = if hair ~= nil then { hair = { id = hair, colors = {} } } else {},
			accessories = {},
			body = {},
			headType = "Uncovered",
			surfaces = {},
		}
	end

	-- A fake profile: `current` is the stored look (nil = not loaded), `toFill` is what a defaults backfill
	-- would add (nil = nothing missing), `slot` the active slot.
	local function fake()
		local world = { current = nil :: any, toFill = nil :: string?, slot = 1 :: number? }
		local publisher = CustomizationPublishSystem.new({
			appearance = function(_userId)
				return world.current
			end,
			fillDefaults = function(_userId)
				if world.current == nil or world.toFill == nil then
					return false
				end
				world.current = look(world.toFill)
				world.toFill = nil
				return true
			end,
			activeSlot = function(_userId)
				return if world.current ~= nil then world.slot else nil
			end,
		})
		return world, publisher
	end

	beforeEach(function()
		StateSyncPublicPlayerStore._resetVersionsForTesting() -- other spec files publish without resetting
	end)

	afterEach(function()
		StateSyncPublicPlayerStore.remove(USER)
		StateSyncPublicPlayerStore._resetVersionsForTesting()
	end)

	it("publishes the look with version 1 on the first spawn", function()
		local world, publisher = fake()
		world.current = look("Hair9")
		CustomizationPublishSystem.onBodySpawn(publisher, USER)
		expect(StateSyncPublicPlayerStore.get(USER).appearanceVersion).to.equal(1)
		expect(StateSyncPublicPlayerStore.get(USER).appearance.cosmetics.hair.id).to.equal("Hair9")
	end)

	it("publishes nothing on a plain respawn", function()
		local world, publisher = fake()
		world.current = look("Hair9")
		CustomizationPublishSystem.onBodySpawn(publisher, USER)
		CustomizationPublishSystem.onBodySpawn(publisher, USER)
		expect(StateSyncPublicPlayerStore.get(USER).appearanceVersion).to.equal(1)
	end)

	it("publishes again when a defaults backfill filled something", function()
		local world, publisher = fake()
		world.current = look(nil)
		CustomizationPublishSystem.onBodySpawn(publisher, USER)
		world.toFill = "Hair9"
		CustomizationPublishSystem.onBodySpawn(publisher, USER)
		expect(StateSyncPublicPlayerStore.get(USER).appearanceVersion).to.equal(2)
		expect(StateSyncPublicPlayerStore.get(USER).appearance.cosmetics.hair.id).to.equal("Hair9")
	end)

	it("publishes again on a slot switch", function()
		local world, publisher = fake()
		world.current = look("Hair9")
		CustomizationPublishSystem.onBodySpawn(publisher, USER)
		world.slot = 2
		CustomizationPublishSystem.onBodySpawn(publisher, USER)
		expect(StateSyncPublicPlayerStore.get(USER).appearanceVersion).to.equal(2)
	end)

	it("publishes again after a leave and a rejoin to the same server", function()
		local world, publisher = fake()
		world.current = look("Hair9")
		CustomizationPublishSystem.onBodySpawn(publisher, USER)
		StateSyncPublicPlayerStore.remove(USER)
		StateSyncPublicPlayerStore.set(USER, { health = 100, maxHealth = 100 })
		CustomizationPublishSystem.onBodySpawn(publisher, USER)
		expect(StateSyncPublicPlayerStore.get(USER).appearanceVersion).to.equal(2)
		expect(StateSyncPublicPlayerStore.get(USER).appearance.cosmetics.hair.id).to.equal("Hair9")
	end)

	it("publishes when the profile loads after the body spawned", function()
		local world, publisher = fake()
		StateSyncPublicPlayerStore.set(USER, { health = 100, maxHealth = 100 })
		CustomizationPublishSystem.onBodySpawn(publisher, USER) -- no profile yet
		expect(StateSyncPublicPlayerStore.get(USER).appearanceVersion).to.equal(0)
		world.current = look("Hair9")
		CustomizationPublishSystem.onProfileLoaded(publisher, USER)
		expect(StateSyncPublicPlayerStore.get(USER).appearanceVersion).to.equal(1)
		expect(StateSyncPublicPlayerStore.get(USER).appearance.cosmetics.hair.id).to.equal("Hair9")
	end)

	it("publishes nothing on a profile load before the player has an entry", function()
		local world, publisher = fake()
		world.current = look("Hair9")
		CustomizationPublishSystem.onProfileLoaded(publisher, USER)
		expect(StateSyncPublicPlayerStore.get(USER)).to.equal(nil)
	end)

	it("does not republish on a profile load once a look is published", function()
		local world, publisher = fake()
		world.current = look("Hair9")
		CustomizationPublishSystem.onBodySpawn(publisher, USER)
		CustomizationPublishSystem.onProfileLoaded(publisher, USER)
		expect(StateSyncPublicPlayerStore.get(USER).appearanceVersion).to.equal(1)
	end)

	it("publish is a no-op while no profile is loaded", function()
		local _, publisher = fake()
		CustomizationPublishSystem.publish(publisher, USER)
		expect(StateSyncPublicPlayerStore.get(USER)).to.equal(nil)
	end)
end
