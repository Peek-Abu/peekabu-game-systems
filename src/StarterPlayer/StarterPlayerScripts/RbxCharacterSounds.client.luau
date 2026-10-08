--!strict
--[=[
	Replaces the engine's default `RbxCharacterSounds` (a LocalScript of this name in StarterPlayerScripts takes
	its place). The default reacts to EVERY player's `Character`: each remote puppet R5 assigns as a `Character`
	got 9 Sounds and Humanoid hooks built synchronously, which measured about 9 ms per body entering view
	against 0.8 ms with the script off (R5 spec, "Assignment cost"). It also risked engine movement sounds on
	puppets, which do not run a Humanoid state machine.

	Intentionally empty: character sounds (the local body included) belong to the later sound work.
]=]
