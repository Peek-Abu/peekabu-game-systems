local SettingRegistry = require(script.Parent.SettingRegistry)
local SettingConstants = require(script.Parent.SettingConstants)
local SoundConstants = require(game:GetService("ReplicatedStorage").Shared.Features.Sound.Data.SoundConstants)

local function ensure(id, def)
	if SettingRegistry.get(id) == nil then
		SettingRegistry.register(id, def)
	end
end

return function()
	it("pre-registers the base settings in order", function()
		local ids = SettingRegistry.ids()
		expect(ids[1]).to.equal("musicVolume")
		expect(SettingRegistry.get("cameraShake").kind).to.equal("number")
		expect(SettingRegistry.get("keybinds").kind).to.equal("keybinds")
	end)

	it("drives every Sound group from a registered volume: music with ambience, effects with UI", function()
		for _, group in SoundConstants.GROUPS do
			local id = SettingConstants.VOLUME_SETTINGS[group]
			expect(id).to.be.ok()
			local def = SettingRegistry.get(id)
			expect(def).to.be.ok()
			expect(def.kind).to.equal("number")
		end
		expect(SettingConstants.VOLUME_SETTINGS.Music).to.equal("musicVolume")
		expect(SettingConstants.VOLUME_SETTINGS.Ambient).to.equal("musicVolume")
		expect(SettingConstants.VOLUME_SETTINGS.SFX).to.equal("sfxVolume")
		expect(SettingConstants.VOLUME_SETTINGS.UI).to.equal("sfxVolume")
		-- The merged volumes are retired, not registered.
		expect(SettingRegistry.get("uiVolume")).to.equal(nil)
		expect(SettingRegistry.get("ambientVolume")).to.equal(nil)
	end)

	it("registers a game's own setting after the base ones", function()
		ensure("spec-colorblind", { kind = "choice", default = "off", options = { "off", "protan", "deutan" } })
		local ids = SettingRegistry.ids()
		expect(table.find(ids, "spec-colorblind") > table.find(ids, "keybinds")).to.equal(true)
	end)

	it("rejects a duplicate id", function()
		ensure("spec-dup", { kind = "boolean", default = false })
		expect(function()
			SettingRegistry.register("spec-dup", { kind = "boolean", default = true })
		end).to.throw()
	end)

	it("rejects inconsistent number definitions", function()
		expect(function()
			SettingRegistry.register("spec-bad-range", { kind = "number", default = 0, min = 1, max = 0 })
		end).to.throw()
		expect(function()
			SettingRegistry.register("spec-bad-default", { kind = "number", default = 5, min = 0, max = 1 })
		end).to.throw()
		expect(function()
			SettingRegistry.register("spec-bad-step", { kind = "number", default = 0, min = 0, max = 1, step = 0 })
		end).to.throw()
		expect(SettingRegistry.get("spec-bad-range")).to.equal(nil)
	end)

	it("rejects a choice whose default is not an option, and bad keybind defaults", function()
		expect(function()
			SettingRegistry.register("spec-bad-choice", { kind = "choice", default = "x", options = { "a" } })
		end).to.throw()
		expect(function()
			SettingRegistry.register("spec-bad-keys", { kind = "keybinds", default = "a=kb:NotAKey" })
		end).to.throw()
	end)

	it("rejects an empty or over-long id", function()
		expect(function()
			SettingRegistry.register("", { kind = "boolean", default = false })
		end).to.throw()
		expect(function()
			SettingRegistry.register(string.rep("x", 65), { kind = "boolean", default = false })
		end).to.throw()
	end)
end
