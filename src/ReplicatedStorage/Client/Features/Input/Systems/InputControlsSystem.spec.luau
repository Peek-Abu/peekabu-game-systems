local InputControlsSystem = require(script.Parent.InputControlsSystem)

local function child(className, name, parent)
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

-- A stand-in StarterPlayer with the current layout's PlayerModule.InputContexts.CharacterContext.
local function currentLayout(starterPlayer)
	local playerModule = child("ModuleScript", "PlayerModule", starterPlayer)
	local contexts = child("Folder", "InputContexts", playerModule)
	return child("InputContext", "CharacterContext", contexts)
end

local function withHost(body)
	local starterPlayer = Instance.new("Folder")
	local playerScripts = Instance.new("Folder")
	body(starterPlayer, playerScripts)
	starterPlayer:Destroy()
	playerScripts:Destroy()
end

return function()
	describe("findControls", function()
		it("finds the current layout's CharacterContext under StarterPlayer.PlayerModule", function()
			withHost(function(starterPlayer, playerScripts)
				local context = currentLayout(starterPlayer)
				local found, kind = InputControlsSystem.findControls(starterPlayer, playerScripts)
				expect(found).to.equal(context)
				expect(kind).to.equal("inputContext")
			end)
		end)

		it("falls back to the legacy PlayerScripts.PlayerModule", function()
			withHost(function(starterPlayer, playerScripts)
				local legacy = child("ModuleScript", "PlayerModule", playerScripts)
				local found, kind = InputControlsSystem.findControls(starterPlayer, playerScripts)
				expect(found).to.equal(legacy)
				expect(kind).to.equal("playerModule")
			end)
		end)

		it("prefers the current layout when both are present", function()
			withHost(function(starterPlayer, playerScripts)
				local context = currentLayout(starterPlayer)
				child("ModuleScript", "PlayerModule", playerScripts)
				expect(InputControlsSystem.findControls(starterPlayer, playerScripts)).to.equal(context)
			end)
		end)

		it("ignores a CharacterContext that is not an InputContext", function()
			withHost(function(starterPlayer, playerScripts)
				local playerModule = child("ModuleScript", "PlayerModule", starterPlayer)
				child("Folder", "CharacterContext", child("Folder", "InputContexts", playerModule))
				expect(InputControlsSystem.findControls(starterPlayer, playerScripts)).to.equal(nil)
			end)
		end)

		it("finds nothing when no PlayerModule exists (not a real client)", function()
			withHost(function(starterPlayer, playerScripts)
				local found, kind = InputControlsSystem.findControls(starterPlayer, playerScripts)
				expect(found).to.equal(nil)
				expect(kind).to.equal(nil)
				expect(InputControlsSystem.findControls(starterPlayer, nil)).to.equal(nil)
			end)
		end)
	end)

	describe("setEnabled", function()
		it("no-ops without yielding outside a client, on every call", function()
			for _, enabled in { false, true, false } do
				local thread = coroutine.create(InputControlsSystem.setEnabled)
				local ok, err = coroutine.resume(thread, enabled)
				expect(ok).to.equal(true)
				expect(err).to.equal(nil)
				expect(coroutine.status(thread)).to.equal("dead")
			end
		end)
	end)
end
