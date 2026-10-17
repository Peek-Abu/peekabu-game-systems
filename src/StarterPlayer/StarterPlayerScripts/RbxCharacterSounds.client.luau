--!strict
--[=[
	RbxCharacterSounds: deliberately empty. The engine inserts its own character-sounds script into
	StarterPlayerScripts only when none of this name is there, so this one turns Roblox's default character sounds off
	(the running loop, free-fall wind, jump, landing, climb, swim, get-up and the death "oof"; round-3 default-sounds
	audit, 2026-10-17). The game plays its own instead: footsteps (FootstepEmitterSystem), the land, the jump and the
	ragdoll body-fall (FootstepLandingSystem).
]=]
