--!strict
--[=[
	Animation registry for all battle characters.
	Maps character ID → animation asset IDs + attack timelines.

	Timeline event types:
	  "damage"         — visual damage number display (waits for MoveResolved data)
	  "hitReaction"    — play hit/dodge/parry animation on target
	  "cameraFocus"    — focus camera on "attacker" | "defender" | "center"
	  "cameraShake"    — shake camera { intensity, duration }
	  "cameraOverview" — return to battle overview
	  "vfx"            — spawn VFX { id = string }
	  "sound"          — play sound { id = string }
	  "qteWindow"      — open QTE prompt for defender (timing synced to animation)

	Reaction config (per-move, optional):
	  type: "Parry" | "Dodge"
	  duration: window length in seconds
	  timeOffset: when in the animation the window opens (seconds from start)

	@class BattleAnimationData
]=]

export type TimelineEvent = {
	time: number,
	event: string,
	[string]: any,
}

export type AttackAnimData = {
	id: string,
	priority: Enum.AnimationPriority?,
	duration: number?,
	timeline: { TimelineEvent },
}

export type CharacterAnimData = {
	battleIdle: string?,
	hit: string?,
	death: string?,
	dodge: string?,
	parry: string?,
	attacks: { [string]: AttackAnimData },
}

-- ── Registry ─────────────────────────────────────────────────────────────────
-- Character IDs must match CharacterDefinitions (uppercase: NATSU, GOKU, etc.)
-- Animation IDs are placeholder "rbxassetid://0" — replace with real IDs.

local BattleAnimationData: { [string]: CharacterAnimData } = {

	NATSU = {
		battleIdle = "rbxassetid://97427432980928",
		hit        = "rbxassetid://123577011225946",
		death      = "rbxassetid://130671804671282",
		dodge      = "rbxassetid://102389072202081",
		parry      = "rbxassetid://84006889552094",
		attacks = {
			FireDragonIronFist = {
				id = "rbxassetid://70431849060121",
				priority = Enum.AnimationPriority.Action2,
				duration = 2.5,
				timeline = {
					{ time = 0.33,  event = "walkTo", target = "defender", duration = 0.84, offset = 5 },
					-- { time = 0.0,  event = "cameraFocus", target = "attacker"},
					-- { time = 0.3,  event = "cameraFocus", target = "defender" },
					{ time = 1.3,  event = "walkTo", target = "defender", duration = 0.3, offset = 1 },
					{ time = 1.55,  event = "damage" },
					{ time = 1.7,  event = "hitReaction" },
					{ time = 1.7,  event = "cameraShake", intensity = 0.5, duration = 0.25 },
					{ time = 2.2,  event = "walkBack", duration = 0.5 },
					-- { time = 0.5,  event = "vfx", id = "fire_punch_impact" },
					-- { time = 0.5,  event = "sound", id = "punch_hit" },
					-- { time = 0.8,  event = "cameraOverview" },
				},
			},
			FireDragonRoar = {
				id = "rbxassetid://76459870679519",
				priority = Enum.AnimationPriority.Action2,
				duration = 1.5,
				timeline = {
					-- { time = 0.0,  event = "cameraFocus", target = "attacker" },
					-- { time = 0.3,  event = "vfx", id = "fire_breath_charge" },
					{ time = 0.9,  event = "cameraShake", intensity = 0.6, duration = 0.2 },
					{ time = 0.8,  event = "damage" },
					{ time = 0.9,  event = "hitReaction" },
					-- { time = 0.6,  event = "sound", id = "fire_roar" },
					-- { time = 1.0,  event = "cameraOverview" },
				},
			},
			FlamesOfEmotion = {
				id = "rbxassetid://129397248344695",
				priority = Enum.AnimationPriority.Action2,
				duration = 1.0,
				timeline = {
					{ time = 0.0, event = "cameraFocus", target = "attacker" },
					{ time = 0.3, event = "vfx", id = "flame_aura" },
					{ time = 0.5, event = "damage" },
					{ time = 0.5, event = "sound", id = "powerup" },
					{ time = 2.8, event = "cameraOverview" },
				},
			},
			DragonsFeast = {
				id = "rbxassetid://94575695044429",
				priority = Enum.AnimationPriority.Action2,
				duration = 1.3,
				timeline = {
					{ time = 0.0, event = "cameraFocus", target = "attacker" },
					{ time = 0.4, event = "vfx", id = "flame_devour" },
					{ time = 0.6, event = "damage" },
					{ time = 0.6, event = "sound", id = "eat_fire" },
					{ time = 1.1, event = "cameraOverview" },
				},
			},
		},
	},

	GOKU = {
		battleIdle = "rbxassetid://0",
		hit        = "rbxassetid://0",
		death      = "rbxassetid://0",
		dodge      = "rbxassetid://0",
		parry      = "rbxassetid://0",
		attacks = {
			Kamehameha = {
				id = "rbxassetid://4841403964",
				priority = Enum.AnimationPriority.Action3,
				duration = 2.9,
				timeline = {
					{ time = 0.0,  event = "cameraFocus", target = "attacker" },
					-- { time = 0.5,  event = "vfx", id = "kamehameha_charge" },
					{ time = 1.7,  event = "damage" },
					{ time = 1.7,  event = "hitReaction" },
					{ time = 1.7,  event = "cameraShake", intensity = 0.7, duration = 0.4 },
					-- { time = 1.3,  event = "cameraOverview" },
					{ time = 1.7,  event = "cameraFocus", target = "defender" },
				},
			},
			SpiritBomb = {
				id = "rbxassetid://0",
				duration = 2.0,
				timeline = {
					-- { time = 0.0, event = "cameraFocus", target = "attacker" },
					-- { time = 1.2, event = "cameraFocus", target = "defender" },
					{ time = 1.5, event = "damage" },
					{ time = 1.5, event = "hitReaction" },
					{ time = 1.5, event = "cameraShake", intensity = 0.9, duration = 0.5 },
					-- { time = 1.8, event = "cameraOverview" },
				},
			},
			SuperSaiyan    = { id = "rbxassetid://0", duration = 1.8, timeline = {
				-- { time = 0.0, event = "cameraFocus", target = "attacker" },
				-- { time = 0.8, event = "cameraShake", intensity = 0.4, duration = 0.5 },
				-- { time = 0.8, event = "vfx", id = "ssj_transform" },
				-- { time = 1.5, event = "cameraOverview" },
			}},
			DragonFist     = { id = "rbxassetid://0", duration = 1.2, timeline = {
				-- { time = 0.0, event = "cameraFocus", target = "attacker" },
				-- { time = 0.5, event = "cameraFocus", target = "defender" },
				{ time = 0.7, event = "damage" },
				{ time = 0.7, event = "hitReaction" },
				{ time = 0.7, event = "cameraShake", intensity = 0.6, duration = 0.3 },
				-- { time = 1.0, event = "cameraOverview" },
			}},
		},
	},

	NARUTO = {
		battleIdle = "rbxassetid://0",
		hit = "rbxassetid://0", death = "rbxassetid://0", dodge = "rbxassetid://0", parry = "rbxassetid://0",
		attacks = {
			Rasengan         = { id = "rbxassetid://0", duration = 1.2, timeline = {
				{ time = 0.0, event = "cameraFocus", target = "attacker" },
				{ time = 0.5, event = "cameraFocus", target = "defender" },
				{ time = 0.7, event = "damage" }, { time = 0.7, event = "hitReaction" },
				{ time = 0.7, event = "cameraShake", intensity = 0.4, duration = 0.25 },
				{ time = 1.0, event = "cameraOverview" },
			}},
			ShadowClone      = { id = "rbxassetid://0", duration = 1.0, timeline = {
				{ time = 0.0, event = "cameraFocus", target = "attacker" },
				{ time = 0.4, event = "vfx", id = "clone_poof" },
				{ time = 0.8, event = "cameraOverview" },
			}},
			Rasenshuriken    = { id = "rbxassetid://0", duration = 1.5, timeline = {
				{ time = 0.0, event = "cameraFocus", target = "attacker" },
				{ time = 0.8, event = "cameraFocus", target = "defender" },
				{ time = 1.0, event = "damage" }, { time = 1.0, event = "hitReaction" },
				{ time = 1.0, event = "cameraShake", intensity = 0.6, duration = 0.3 },
				{ time = 1.3, event = "cameraOverview" },
			}},
			BaryonMode       = { id = "rbxassetid://0", duration = 2.0, timeline = {
				{ time = 0.0, event = "cameraFocus", target = "attacker" },
				{ time = 0.8, event = "cameraShake", intensity = 0.5, duration = 0.6 },
				{ time = 1.5, event = "cameraOverview" },
			}},
		},
	},

	LUFFY = {
		battleIdle = "rbxassetid://0",
		hit = "rbxassetid://0", death = "rbxassetid://0", dodge = "rbxassetid://0", parry = "rbxassetid://0",
		attacks = {
			GumGumPistol = { id = "rbxassetid://0", duration = 0.8, timeline = {
				{ time = 0.0, event = "cameraFocus", target = "attacker" },
				{ time = 0.4, event = "damage" }, { time = 0.4, event = "hitReaction" },
				{ time = 0.4, event = "cameraShake", intensity = 0.3, duration = 0.2 },
				{ time = 0.6, event = "cameraOverview" },
			}},
			GearFourth   = { id = "rbxassetid://0", duration = 1.5, timeline = {
				{ time = 0.0, event = "cameraFocus", target = "attacker" },
				{ time = 0.6, event = "cameraShake", intensity = 0.4, duration = 0.4 },
				{ time = 1.2, event = "cameraOverview" },
			}},
			BajrangGun   = { id = "rbxassetid://0", duration = 2.0, timeline = {
				{ time = 0.0, event = "cameraFocus", target = "attacker" },
				{ time = 1.2, event = "cameraFocus", target = "defender" },
				{ time = 1.5, event = "damage" }, { time = 1.5, event = "hitReaction" },
				{ time = 1.5, event = "cameraShake", intensity = 0.9, duration = 0.4 },
				{ time = 1.8, event = "cameraOverview" },
			}, reaction = { type = "Dodge", duration = 0.6, timeOffset = 1.2 }},
		},
	},

	ICHIGO = {
		battleIdle = "rbxassetid://0",
		hit = "rbxassetid://0", death = "rbxassetid://0", dodge = "rbxassetid://0", parry = "rbxassetid://0",
		attacks = {
			GetsugaTensho = { id = "rbxassetid://0", duration = 1.3, timeline = {
				{ time = 0.0, event = "cameraFocus", target = "attacker" },
				{ time = 0.6, event = "cameraFocus", target = "defender" },
				{ time = 0.8, event = "damage" }, { time = 0.8, event = "hitReaction" },
				{ time = 0.8, event = "cameraShake", intensity = 0.5, duration = 0.3 },
				{ time = 1.1, event = "cameraOverview" },
			}},
			Bankai        = { id = "rbxassetid://0", duration = 1.8, timeline = {
				{ time = 0.0, event = "cameraFocus", target = "attacker" },
				{ time = 0.8, event = "cameraShake", intensity = 0.5, duration = 0.5 },
				{ time = 1.5, event = "cameraOverview" },
			}},
			TrueZangetsu  = { id = "rbxassetid://0", duration = 2.0, timeline = {
				{ time = 0.0, event = "cameraFocus", target = "attacker" },
				{ time = 1.0, event = "cameraFocus", target = "defender" },
				{ time = 1.3, event = "damage" }, { time = 1.3, event = "hitReaction" },
				{ time = 1.3, event = "cameraShake", intensity = 0.8, duration = 0.4 },
				{ time = 1.7, event = "cameraOverview" },
			}},
		},
	},

	GOJO = {
		battleIdle = "rbxassetid://0",
		hit = "rbxassetid://0", death = "rbxassetid://0", dodge = "rbxassetid://0", parry = "rbxassetid://0",
		attacks = {
			InfinityVoid  = { id = "rbxassetid://0", duration = 1.5, timeline = {
				{ time = 0.0, event = "cameraFocus", target = "attacker" },
				{ time = 0.8, event = "cameraShake", intensity = 0.4, duration = 0.4 },
				{ time = 1.2, event = "cameraOverview" },
			}},
			HollowPurple  = { id = "rbxassetid://0", duration = 1.8, timeline = {
				{ time = 0.0, event = "cameraFocus", target = "attacker" },
				{ time = 0.8, event = "cameraFocus", target = "defender" },
				{ time = 1.1, event = "damage" }, { time = 1.1, event = "hitReaction" },
				{ time = 1.1, event = "cameraShake", intensity = 0.7, duration = 0.35 },
				{ time = 1.5, event = "cameraOverview" },
			}},
			UnlimitedVoid = { id = "rbxassetid://0", duration = 2.0, timeline = {
				{ time = 0.0, event = "cameraFocus", target = "attacker" },
				{ time = 1.0, event = "cameraShake", intensity = 0.8, duration = 0.6 },
				{ time = 1.2, event = "damage" }, { time = 1.2, event = "hitReaction" },
				{ time = 1.7, event = "cameraOverview" },
			}},
		},
	},

	ALL_MIGHT = {
		battleIdle = "rbxassetid://0",
		hit = "rbxassetid://0", death = "rbxassetid://0", dodge = "rbxassetid://0", parry = "rbxassetid://0",
		attacks = {
			DetroitSmash      = { id = "rbxassetid://0", duration = 1.0, timeline = {
				{ time = 0.0, event = "cameraFocus", target = "attacker" },
				{ time = 0.4, event = "cameraFocus", target = "defender" },
				{ time = 0.6, event = "damage" }, { time = 0.6, event = "hitReaction" },
				{ time = 0.6, event = "cameraShake", intensity = 0.6, duration = 0.25 },
				{ time = 0.8, event = "cameraOverview" },
			}},
			UnitedStatesSmash = { id = "rbxassetid://0", duration = 1.5, timeline = {
				{ time = 0.0, event = "cameraFocus", target = "attacker" },
				{ time = 0.7, event = "cameraFocus", target = "defender" },
				{ time = 1.0, event = "damage" }, { time = 1.0, event = "hitReaction" },
				{ time = 1.0, event = "cameraShake", intensity = 0.7, duration = 0.3 },
				{ time = 1.3, event = "cameraOverview" },
			}},
			FinalStand        = { id = "rbxassetid://0", duration = 2.0, timeline = {
				{ time = 0.0, event = "cameraFocus", target = "attacker" },
				{ time = 1.0, event = "cameraShake", intensity = 0.5, duration = 0.5 },
				{ time = 1.5, event = "cameraOverview" },
			}},
		},
	},

	RIMURU = {
		battleIdle = "rbxassetid://0",
		hit = "rbxassetid://0", death = "rbxassetid://0", dodge = "rbxassetid://0", parry = "rbxassetid://0",
		attacks = {
			Predator       = { id = "rbxassetid://0", duration = 1.3, timeline = {
				{ time = 0.0, event = "cameraFocus", target = "attacker" },
				{ time = 0.6, event = "damage" }, { time = 0.6, event = "hitReaction" },
				{ time = 0.6, event = "cameraShake", intensity = 0.3, duration = 0.2 },
				{ time = 1.0, event = "cameraOverview" },
			}},
			UltimateEvolve = { id = "rbxassetid://0", duration = 2.0, timeline = {
				{ time = 0.0, event = "cameraFocus", target = "attacker" },
				{ time = 0.8, event = "cameraShake", intensity = 0.6, duration = 0.5 },
				{ time = 1.5, event = "cameraOverview" },
			}},
		},
	},
}

-- ── Lookup API ───────────────────────────────────────────────────────────────

local BattleAnimationDataModule = {}

function BattleAnimationDataModule.getCharacter(characterId: string): CharacterAnimData?
	return BattleAnimationData[characterId]
end

function BattleAnimationDataModule.getAttack(characterId: string, moveName: string): AttackAnimData?
	local char = BattleAnimationData[characterId]
	if not char or not char.attacks then return nil end
	return char.attacks[moveName]
end

function BattleAnimationDataModule.getBattleIdle(characterId: string): string?
	local char = BattleAnimationData[characterId]
	return char and char.battleIdle
end

function BattleAnimationDataModule.getAnimationDuration(characterId: string, moveName: string): number
	local attack = BattleAnimationDataModule.getAttack(characterId, moveName)
	return if attack and attack.duration then attack.duration else 1.0
end

--- Returns the time (seconds) of the first "damage" event in the timeline.
--- Used by the server to wait until the animation reaches the damage frame before resolving.
function BattleAnimationDataModule.getDamageTime(characterId: string, moveName: string): number
	local attack = BattleAnimationDataModule.getAttack(characterId, moveName)
	if attack and attack.timeline then
		for _, evt in attack.timeline do
			if evt.event == "damage" then
				return evt.time
			end
		end
	end
	-- Fallback: 60% of duration if no damage event defined
	local dur = BattleAnimationDataModule.getAnimationDuration(characterId, moveName)
	return dur * 0.6
end

return BattleAnimationDataModule
