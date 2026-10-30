--!strict
--[=[
	AnimationEmployeeRegistry: the `employee` animation domain (Cleanup Crew's playable employees), composed
	by AnimationRegistry. Each employee's own locomotion clips live here; EmployeeRegistry names them by key
	(`locomotion`), and the character's Animate binding plays them in place of the stock idle/walk/run.

	Pippa's clips (uploaded under the Icey Labs group, sources in `characters/pippa/anim/`) are authored
	relative to her own T-pose rest and carry no retargeting rig data, so `Workspace.Retargeting` does not
	touch them. They are root-in-place loops whose feet plant at a measured speed at 1x playback (walk
	1.27 st/s, run 1.52 st/s, crouch walk 1.3 st/s); EmployeeRegistry carries those numbers for the stride scaling.

	All entries are Core + `ambient`, like the stock locomotion: gameplay clips (carry, vacuum, actions)
	sit above them, and a bulk combat stop never kills them.

	@class AnimationEmployeeRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationTypes = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationTypes)

type AnimationDomain = AnimationTypes.AnimationDomain

local function locomotion(assetId: string): AnimationTypes.AnimationDef
	local def: AnimationTypes.AnimationDef = {
		assetId = assetId,
		priority = Enum.AnimationPriority.Core,
		looped = true,
		interruption = "ambient",
	}
	return table.freeze(def)
end

-- A reveal: played once on a preview (the reveal screen), above its idle, never replicated.
local function reveal(assetId: string): AnimationTypes.AnimationDef
	local def: AnimationTypes.AnimationDef = {
		assetId = assetId,
		priority = Enum.AnimationPriority.Action,
		looped = false,
		interruption = "protected",
	}
	return table.freeze(def)
end

local AnimationEmployeeRegistry: AnimationDomain = table.freeze({
	-- Pippa Idle v1: 3.0 s loop, feet fixed.
	pippaidle = locomotion("rbxassetid://75845395212929"),
	-- Pippa Walk v1: 1.9 s loop (2 cycles), feet planted at 1.27 st/s at 1x.
	pippawalk = locomotion("rbxassetid://93025706307245"),
	-- Pippa Run v1: 1.03 s loop (2 cycles), feet planted at 1.52 st/s at 1x.
	pipparun = locomotion("rbxassetid://106530900825479"),
	-- Pippa Crouch Idle v2: 3.0 s loop, feet fixed, a wary look left and right (root 0.30 below standing), the chest
	-- 20 degrees forward, her idle's arms (hanging, own sway). A held item's or the vacuum's IK still takes the arms.
	pippacrouchidle = locomotion("rbxassetid://133583434240097"),
	-- Pippa Crouch Walk v2: 1.33 s loop (1 cycle), feet planted at 1.3 st/s at 1x (root 0.27 below standing), the
	-- same lean and idle arms with a small step counter-swing.
	pippacrouchwalk = locomotion("rbxassetid://100643609508734"),

	-- Legendary skins' showcase idles (EmployeeRegistry `showcaseIdle`; the shop, inventory and reveal previews play
	-- them): Sheriff Prickles holds his hose coil, glued in the paw.
	-- characters/skins/runtime-candidates-2026-10-26/legendary-clips-2026-10-29/glue_idles.py.
	pricklessheriffidle = locomotion("rbxassetid://103766062745572"),

	-- Cappy v1 clips (characters/cappy/anim, owner-approved, Icey Labs): loose and unbothered, hands in the hoodie.
	-- Planted at 1x: walk 1.06, run 2.06, crouch walk 1.32 st/s.
	cappyidle = locomotion("rbxassetid://124155807682224"),
	cappywalk = locomotion("rbxassetid://105426576584816"),
	cappyrun = locomotion("rbxassetid://87388143018692"),
	cappycrouchidle = locomotion("rbxassetid://78456687803253"),
	cappycrouchwalk = locomotion("rbxassetid://140157048070101"),

	-- PJ Cappy's showcase idle (EmployeeRegistry `showcaseIdle`): Sleepy Sway, holding the pillow and cocoa mug, a
	-- PropsShow at frame 1. legendary-clips-2026-10-29/cappy_prop_clips.py.
	cappypjidle = locomotion("rbxassetid://75476202945517"),

	-- Reveals (EmployeeRegistry `hireReveal` / a skin's `unlockReveal`; the reveal screen plays one, then the idle).
	-- Hire reveals, owner-approved (launch-finish-2026-10-25/<who>/hire, faces as Face markers by hire_markers.py);
	-- Cappy's is being fixed, so he has none yet. 101 frames at 30 fps.
	pippahirereveal = reveal("rbxassetid://121771751200181"),
	prickleshirereveal = reveal("rbxassetid://140175715881141"),
	-- Unlock reveals a skin can name later (no skin does yet: every skin plays the hire reveal for now, owner
	-- 2026-10-29): the Legendary skins', props glued in the paw (legendary-clips-2026-10-29/glue_idles.py), and PJ
	-- Cappy's Cozy Unlock (pj_cappy/v6-2026-10-29).
	pippabubblebuddyreveal = reveal("rbxassetid://131200183097709"),
	pricklessheriffreveal = reveal("rbxassetid://130789932413457"),
	cappypjreveal = reveal("rbxassetid://86895730118507"),

	-- Prickles v1 clips (characters/prickles/anim, owner-approved, Icey Labs): short, stiff and sturdy, arms crossed
	-- when he stops. Planted at 1x: walk 1.03, run 1.93, crouch walk 1.34 st/s.
	pricklesidle = locomotion("rbxassetid://108680458550464"),
	prickleswalk = locomotion("rbxassetid://137832099996706"),
	pricklesrun = locomotion("rbxassetid://82235036410910"),
	pricklescrouchidle = locomotion("rbxassetid://126115556970677"),
	pricklescrouchwalk = locomotion("rbxassetid://112633928289035"),
})

return AnimationEmployeeRegistry
