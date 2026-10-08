--!strict
--[=[
	VitalsHud: the resource-bar HUD widget — health / rot / stamina (bottom-centre). Pure wiring: it
	owns the health data path and hands eased fractions to the presentational `ResourceBars`. Composed
	onto the Hud layer by `HudRoot` (which owns the shared hide gate); this widget only renders bars.

	**The health path is bindings, not state.** Health changes constantly, so it rides React **bindings**
	— the Humanoid feeds a raw fraction, and `useEasedTrail` eases a smooth **fill** (a gentle drain, not
	a snap) plus a lagging **trail** off it, all via Heartbeat writes with no re-render. `UIRenderCounters`
	makes that checkable: take damage, watch the bar move while this widget's render count stays flat.
	(This component is also `React.memo`'d so `HudRoot` re-rendering — e.g. a scene opening — never
	cascades a re-render here.)

	**The damage trail.** The trail lags the fill on the way down (slow down-rate) but keeps up on heal,
	so lost health shows as a dark-red chunk catching up — the same `useEasedTrail` mechanism XP uses for
	its gain-lead, just configured to lag instead of lead.

	(Rot and Stamina are shown full and undriven — see ResourceBars for why.)

	@class VitalsHud
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIRenderCounters = require(ReplicatedStorage.Client.UI.UIRenderCounters)
local useEasedTrail = require(ReplicatedStorage.Client.UI.React.Hooks.useEasedTrail)
local ResourceBars = require(ReplicatedStorage.Client.UI.React.Screens.Vitals.ResourceBars)
local VitalsViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Vitals.VitalsViewModel)

local e = React.createElement

local COMPONENT_NAME = "VitalsHud"

-- Health easing: the fill heals fast and drains smoothly; the trail keeps up on heal but, on damage,
-- HOLDS 0.5s before draining behind the fill (the dark "lost" chunk lingers, then catches up). Rates are
-- per-second; a big rate is effectively a snap. To drop the hold: remove hold/holdDir from `trail`.
local HEALTH_TRAIL: useEasedTrail.TrailConfig = {
	fill = { up = 22, down = 9 },
	trail = { up = 22, down = 3, hold = 0.5, holdDir = "down" },
}

type HealthValue = { current: number, max: number }

local function healthFractionOf(value: HealthValue): number
	return VitalsViewModel.fromHealth(value.current, value.max).fraction
end

--[=[
	@return React.ReactNode
]=]
local function VitalsHud(): React.ReactNode
	local health, setHealth = React.useBinding({ current = 0, max = 0 } :: HealthValue) -- type the binding's seed

	-- Tally every render. No dependency array on purpose: this runs after EVERY render, which is what
	-- makes the binding-vs-state claim checkable in the F4 UI tab.
	React.useEffect(function()
		UIRenderCounters.tick(COMPONENT_NAME)
	end)

	-- Follow the local character's Humanoid across respawns and slot switches. Writes the binding only
	-- — no setState — so none of this re-renders.
	React.useEffect(function(): () -> ()
		local player = Players.LocalPlayer
		local characterConnections: { RBXScriptConnection } = {}

		local function clearCharacterConnections()
			for _, connection in characterConnections do
				connection:Disconnect()
			end
			table.clear(characterConnections)
		end

		local function bindHumanoid(humanoid: Humanoid)
			local function push()
				setHealth({ current = humanoid.Health, max = humanoid.MaxHealth })
			end
			push()
			table.insert(characterConnections, humanoid.HealthChanged:Connect(push))
			table.insert(characterConnections, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(push))
		end

		local function bindCharacter(character: Model)
			clearCharacterConnections()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid ~= nil then
				bindHumanoid(humanoid)
				return
			end
			-- The Humanoid is not always a child YET: `CharacterAdded` fires when the model replicates to
			-- this client, and its children can land a frame later. Returning here bound nothing and
			-- reported nothing — the bar simply held the previous character's value forever, with no error
			-- anywhere. Waiting on the character's own `ChildAdded` costs one connection, and the next
			-- respawn's `clearCharacterConnections` drops it whether or not it ever fired.
			table.insert(
				characterConnections,
				character.ChildAdded:Connect(function(child: Instance)
					if child:IsA("Humanoid") then
						bindHumanoid(child)
					end
				end)
			)
		end

		local existing = player.Character
		if existing ~= nil then
			bindCharacter(existing)
		end
		local characterAdded = player.CharacterAdded:Connect(bindCharacter)

		return function()
			characterAdded:Disconnect()
			clearCharacterConnections()
		end
	end, {})

	-- The raw target (from the Humanoid); the hook eases a smooth fill and a lagging trail off it.
	local target = health:map(healthFractionOf)
	local healthFill, healthCatchup = useEasedTrail(target, HEALTH_TRAIL)

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		resources = e(ResourceBars, { healthFill = healthFill, healthCatchup = healthCatchup }),
	})
end

return React.memo(VitalsHud)
