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

-- A fidget: one rare move above the idle (AnimationFidgetSystem). The Animator replicates a client's own character.
local function fidget(assetId: string): AnimationTypes.AnimationDef
	local def: AnimationTypes.AnimationDef = {
		assetId = assetId,
		priority = Enum.AnimationPriority.Action,
		looped = false,
		interruption = "ambient",
	}
	return table.freeze(def)
end

local AnimationEmployeeRegistry: AnimationDomain = table.freeze({
	-- Pippa lore idle v2: 4.0 s loop, feet fixed, a small bounce and a look around (owner-approved 2026-10-29;
	-- launch/production-batch-2026-10-25 Pippa_Idle; v1 75845395212929 superseded).
	pippaidle = locomotion("rbxassetid://118670136851083"),
	-- Pippa's fidget, two hops: 6.0 s (fidgets-v2, owner-approved 2026-10-23).
	pippafidget = fidget("rbxassetid://133361579221208"),
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

	-- Legendary skins' showcase idles and fidgets (EmployeeRegistry `showcaseIdle` / `showcaseFidget`; menus and a shift
	-- play them when the skin is worn). Sheriff Prickles v2 (owner-approved 2026-11-03,
	-- workflow/legendary-idles-2026-11-03/sheriff): Prickles' own rooted sway, the hose coil at his hip (glued in the
	-- paw), a slow look side to side; 6.0 s, two loops of his idle's body (v1 103766062745572 superseded). His quick
	-- draw: the coil snaps up, a squint right then left, a nod, back (6.0 s, Face markers).
	pricklessheriffidle = locomotion("rbxassetid://82098357572254"),
	pricklessherifffidget = fidget("rbxassetid://112652290604749"),

	-- Cappy v1 clips (characters/cappy/anim, owner-approved, Icey Labs): loose and unbothered, hands in the hoodie.
	-- Planted at 1x: walk 1.06, run 2.06, crouch walk 1.32 st/s.
	-- Lore idle v2: 4.0 s loop, bobbing to his earbuds (owner-approved 2026-10-29; v1 124155807682224 superseded).
	cappyidle = locomotion("rbxassetid://108700334463820"),
	-- His fidget, fixing an earbud and grooving: 8.0 s (fidgets-v2, owner-approved 2026-10-23).
	cappyfidget = fidget("rbxassetid://120652353962976"),
	cappywalk = locomotion("rbxassetid://105426576584816"),
	cappyrun = locomotion("rbxassetid://87388143018692"),
	cappycrouchidle = locomotion("rbxassetid://78456687803253"),
	cappycrouchwalk = locomotion("rbxassetid://140157048070101"),

	-- PJ Cappy's showcase idle, revision 2 (owner pick 2026-11-03, "asleep standing up"; revision 1 Sleepy Sway with
	-- the pillow and mug): asleep on his feet, chin on the pillow held under it in both paws, eyes shut (Face marker),
	-- the mug put away; 6.0 s. His fidget, the pillow slip: it slides out of his arms, he jolts awake and catches it,
	-- looks round, snuggles back in (6.0 s, Face markers). workflow/legendary-idles-2026-11-03/pj.
	cappypjidle = locomotion("rbxassetid://75476202945517"),
	cappypjfidget = fidget("rbxassetid://70473288014563"),
	-- Bubble Buddy's showcase idle (owner pick 2026-11-03, "duck ring float"): Pippa's own bouncy idle, both paws on the
	-- duck ring she wears at her waist (no props); 4.0 s. Her fidget: the wand out at her side, a few bubbles, back
	-- (8.0 s; PropsShow/PropsStow, BubbleBlow .. BubbleBlowEnd, Face markers). workflow/legendary-idles-2026-11-03/bubble.
	pippabubblebuddyidle = locomotion("rbxassetid://135311387362712"),
	pippabubblebuddyfidget = fidget("rbxassetid://112807601879936"),

	-- Reveals (EmployeeRegistry `hireReveal` / a skin's `unlockReveal`; the reveal screen plays one, then the idle).
	-- Hire reveals, owner-approved (launch-finish-2026-10-25/<who>/hire, faces as Face markers by hire_markers.py; Cappy's
	-- v2 from cappy/hire/v2-2026-10-29/cappy_hire_game.py, with his phone). 101 frames at 30 fps; Prickles' 136, its tail
	-- settling into his old idle (workflow/menu-reactions-idle-seam-2026-10-30/prickles-hire; 140175715881141 superseded).
	pippahirereveal = reveal("rbxassetid://121771751200181"),
	prickleshirereveal = reveal("rbxassetid://112352734198136"),
	cappyhirereveal = reveal("rbxassetid://100703500122066"),
	-- Menu reactions (EmployeeRegistry `selectReaction`; a click on an employee's pick card, or opening their Inventory
	-- page or a Shop page that shows them, plays one on the hero): launch/production-batch-2026-10-25
	-- selection_reaction, owner-approved. Cappy's is a fist bump offered to you, not his free emote (the Shrug).
	pippaselect = reveal("rbxassetid://88439470380372"),
	cappyselect = reveal("rbxassetid://115461604220450"),
	-- His guarded nod, re-posed to his old idle (workflow/prickles-old-idle-2026-10-29, owner-approved 2026-10-30).
	pricklesselect = reveal("rbxassetid://137811464482102"),
	-- Unlock reveals a skin can name later (no skin does yet: every skin plays the hire reveal for now, owner
	-- 2026-10-29): the Legendary skins', props glued in the paw (legendary-clips-2026-10-29/glue_idles.py), and PJ
	-- Cappy's Cozy Unlock (pj_cappy/v6-2026-10-29).
	pippabubblebuddyreveal = reveal("rbxassetid://131200183097709"),
	pricklessheriffreveal = reveal("rbxassetid://130789932413457"),
	cappypjreveal = reveal("rbxassetid://86895730118507"),

	-- Prickles v1 clips (characters/prickles/anim, owner-approved, Icey Labs): short, stiff and sturdy, arms crossed
	-- when he stops. Planted at 1x: walk 1.03, run 1.93, crouch walk 1.34 st/s.
	pricklesidle = locomotion("rbxassetid://108680458550464"),
	-- His fidget, impatient root taps: 6.0 s, re-posed to this idle (owner-approved 2026-10-30).
	pricklesfidget = fidget("rbxassetid://71661621842416"),
	prickleswalk = locomotion("rbxassetid://137832099996706"),
	pricklesrun = locomotion("rbxassetid://82235036410910"),
	pricklescrouchidle = locomotion("rbxassetid://126115556970677"),
	pricklescrouchwalk = locomotion("rbxassetid://112633928289035"),
})

return AnimationEmployeeRegistry
