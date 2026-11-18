--!strict
--[=[
	SkillCheckServiceClient: the closing-ring skill check on this client. Registers the ring HUD widget (SkillCheckHud)
	and starts SkillCheckInputSystem. A Ring from the server goes to SkillCheckStore (drawn by the HUD); at its arrival
	(the server clock, workspace:GetServerTimeNow) this client reports the icon's angle once (SkillCheckEvents.Report)
	and the ring stays a moment for the verdict's flash (SkillCheckRingViewModel.shown), then goes. The server's Result
	is kept for the flash and plays an existing UI cue: the dull clunk on a miss (SkillCheckConstants.MISS_SOUND), a
	light tick on a hit (HIT_SOUND). The judging, the timing window and the miss's noise are the server's.

	Spec-exempt shell (the HUD registry, RunService, ByteNet, Sound); the decisions are the specced SkillCheckStore,
	SkillCheckInputFormulas and SkillCheckRingViewModel.

	@class SkillCheckServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local SkillCheckConstants = require(ReplicatedStorage.Shared.Features.SkillCheck.Data.SkillCheckConstants)
local SkillCheckEvents = require(ReplicatedStorage.Shared.Features.SkillCheck.Net.SkillCheckEvents)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)
local SkillCheckStore = require(ReplicatedStorage.Client.Features.SkillCheck.State.SkillCheckStore)
local SkillCheckInputSystem = require(ReplicatedStorage.Client.Features.SkillCheck.Systems.SkillCheckInputSystem)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local HudRegistry = require(ReplicatedStorage.Client.UI.React.Screens.Hud.HudRegistry)
local SkillCheckHud = require(ReplicatedStorage.Client.UI.React.Screens.SkillCheck.SkillCheckHud)
local SkillCheckRingViewModel = require(ReplicatedStorage.Client.UI.React.Screens.SkillCheck.SkillCheckRingViewModel)

local HUD_KEY = "skillCheck"

local janitor = Janitor.new()
-- The last ring this client reported (each is reported once).
local reportedId = 0

-- Plays one of UIAssets' registered UI cues, if it is there.
local function cue(id: string)
	if UIAssets.sounds[id] ~= nil then
		SoundServiceClient:playOneShot(id)
	end
end

-- Each frame: report the ring at its arrival, take it away once its flash has had its moment.
local function step()
	local ring = SkillCheckStore.ring()
	if ring == nil then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if reportedId ~= ring.id and now >= ring.arriveAt then
		reportedId = ring.id
		SkillCheckEvents.packets.Report.send({ id = ring.id, angle = SkillCheckInputSystem.angle() })
	end
	if not SkillCheckRingViewModel.shown(now, ring.arriveAt) then
		SkillCheckStore.hide(ring.id)
	end
end

export type SkillCheckServiceClient = {
	dependencies: { string },
	init: (self: SkillCheckServiceClient) -> (),
	start: (self: SkillCheckServiceClient) -> (),
	stop: (self: SkillCheckServiceClient) -> (),
}

local SkillCheckServiceClient: SkillCheckServiceClient = {
	dependencies = { "SoundServiceClient", "UIServiceClient" },

	init = function(_self)
		if not HudRegistry.has(HUD_KEY) then
			-- Over the shift HUD, beside the landing card.
			HudRegistry.register(HUD_KEY, SkillCheckHud, ShiftConstants.HUD_ORDER + 4)
		end
	end,

	start = function(_self)
		janitor:Add(SkillCheckInputSystem.start(), true)
		janitor:Add(
			SkillCheckEvents.packets.Ring.listen(
				function(data: { id: number, gap: number, width: number, arriveAt: number, travel: number })
					SkillCheckStore.show({
						id = data.id,
						gap = data.gap,
						width = data.width,
						arriveAt = data.arriveAt,
						travel = data.travel,
					})
				end
			),
			true
		)
		janitor:Add(
			SkillCheckEvents.packets.Result.listen(function(data: { id: number, hit: boolean })
				SkillCheckStore.judged(data.id, data.hit, os.clock())
				cue(if data.hit then SkillCheckConstants.HIT_SOUND else SkillCheckConstants.MISS_SOUND)
			end),
			true
		)
		janitor:Add(RunService.Heartbeat:Connect(step), "Disconnect")
	end,

	stop = function(_self)
		janitor:Cleanup()
		SkillCheckStore.reset()
	end,
}

return SkillCheckServiceClient
