local SprintStickSystem = require(script.Parent.SprintStickSystem)

local function child(className, name, parent)
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

-- A CharacterContext with its MoveAction, under `parent.<holder>.InputContexts` (or straight under `parent` when no
-- holder is named).
local function moveAction(parent, holder)
	local base = if holder ~= nil then child("ModuleScript", holder, parent) else parent
	local contexts = child("Folder", "InputContexts", base)
	local context = child("InputContext", "CharacterContext", contexts)
	return child("InputAction", "MoveAction", context)
end

local function withHost(body)
	local starterPlayer = Instance.new("Folder")
	local player = Instance.new("Folder")
	body(starterPlayer, player)
	starterPlayer:Destroy()
	player:Destroy()
end

return function()
	describe("findMoveAction", function()
		it("finds StarterPlayer.PlayerModule.InputContexts.CharacterContext.MoveAction", function()
			withHost(function(starterPlayer, player)
				local action = moveAction(starterPlayer, "PlayerModule")
				expect(SprintStickSystem.findMoveAction(starterPlayer, player)).to.equal(action)
			end)
		end)

		it("prefers the player's own clone of the contexts (server-authority places)", function()
			withHost(function(starterPlayer, player)
				moveAction(starterPlayer, "PlayerModule")
				local mine = moveAction(player, nil)
				expect(SprintStickSystem.findMoveAction(starterPlayer, player)).to.equal(mine)
			end)
		end)

		it("is nil without the Input Action System's player scripts", function()
			withHost(function(starterPlayer, player)
				child("ModuleScript", "PlayerModule", starterPlayer)
				expect(SprintStickSystem.findMoveAction(starterPlayer, player)).to.equal(nil)
				expect(SprintStickSystem.findMoveAction(starterPlayer, nil)).to.equal(nil)
			end)
		end)

		it("ignores a MoveAction that is not an InputAction", function()
			withHost(function(starterPlayer, player)
				local playerModule = child("ModuleScript", "PlayerModule", starterPlayer)
				local contexts = child("Folder", "InputContexts", playerModule)
				local context = child("InputContext", "CharacterContext", contexts)
				child("Folder", "MoveAction", context)
				expect(SprintStickSystem.findMoveAction(starterPlayer, player)).to.equal(nil)
			end)
		end)
	end)

	describe("magnitudeOf", function()
		it("reads how far a direction state is pushed", function()
			expect(SprintStickSystem.magnitudeOf(Vector2.new(0.6, 0.8))).to.be.near(1, 1e-6)
			expect(SprintStickSystem.magnitudeOf(Vector2.new(0, 0.5))).to.be.near(0.5, 1e-6)
			expect(SprintStickSystem.magnitudeOf(Vector3.new(0, 0, 0.3))).to.be.near(0.3, 1e-6)
		end)

		it("reads anything else as not pushed", function()
			expect(SprintStickSystem.magnitudeOf(nil)).to.equal(0)
			expect(SprintStickSystem.magnitudeOf(true)).to.equal(0)
			expect(SprintStickSystem.magnitudeOf(0.9)).to.equal(0)
		end)
	end)
end
