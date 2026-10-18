--!strict
--[=[
	usePortraitCharacter: the character a portrait of `userId` shows, and a revision that moves whenever the portrait
	should be rebuilt: the player respawns, or something is put on or taken off the character (a skin's accessory or
	uniform landing after the spawn, a part streaming in). Tools are ignored: equipping the vacuum does not rebuild a
	portrait (they are stripped from it anyway). Changes are settled for SETTLE seconds first, so a spawn's burst of
	children rebuilds once. Every connection and pending rebuild ends with the hook. React hook (exempt: needs a
	renderer and live Players; what a rebuild produces is specced in EmployeePortraitSystem).

	@class usePortraitCharacter
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local SETTLE = 0.4

export type PortraitCharacter = { character: Model?, revision: number }

local function usePortraitCharacter(userId: number?): PortraitCharacter
	local initial: PortraitCharacter = { character = nil, revision = 0 }
	local state, setState = React.useState(initial)
	React.useEffect(function(): () -> ()
		local player = if userId ~= nil then Players:GetPlayerByUserId(userId) else nil
		if player == nil then
			setState({ character = nil, revision = 0 })
			return function() end
		end
		local alive = true
		local revision = 0
		local pending: thread? = nil
		local watch: { RBXScriptConnection } = {}
		local function unwatch()
			for _, connection in watch do
				connection:Disconnect()
			end
			table.clear(watch)
		end
		local function publish(character: Model?)
			pending = nil
			if alive then
				revision += 1
				setState({ character = character, revision = revision })
			end
		end
		local function settle(character: Model?)
			if pending ~= nil then
				task.cancel(pending)
			end
			pending = task.delay(SETTLE, publish, character)
		end
		local function follow(character: Model)
			unwatch()
			local function changed(child: Instance)
				if not child:IsA("Tool") then
					settle(character)
				end
			end
			table.insert(watch, character.ChildAdded:Connect(changed))
			table.insert(watch, character.ChildRemoved:Connect(changed))
			settle(character)
		end
		local added = player.CharacterAdded:Connect(follow)
		local current = player.Character
		if current ~= nil then
			-- Show what is there now; the settle then catches anything still landing.
			publish(current)
			follow(current)
		else
			publish(nil)
		end
		return function()
			alive = false
			added:Disconnect()
			unwatch()
			if pending ~= nil then
				task.cancel(pending)
				pending = nil
			end
		end
	end, { userId })
	return state
end

return usePortraitCharacter
