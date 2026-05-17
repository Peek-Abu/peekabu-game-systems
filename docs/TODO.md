- see if everything has docs and it is consistent
- prompt check for analysis of repo
- check for syntax / lint / warnings
- check for pcall additives
1. **Build Client UI** to display battle state and prompts
2. **Implement QTE UI** for parry/dodge/rhythm mechanics
3. ✅ **Create character definitions** with varied stats and movesets
   - ✅ Each character should have unique movesets (6 characters with 5 moves each)
   - ✅ Each character should have unique stats (distinct HP/ATK/DEF/SPD distributions)
   - ✅ Each character should have unique abilities (passive abilities implemented)
   - Moves
      - Status effect system expansion (burn, paralysis, etc. referenced by moves)
      - Character morphing / model changes, respawn issues / characterAdded! events
      - ⏳ Each character's moves should have unique animations - TODO: Implement animations
         - attacks shouldn't fully end / next person get prompted before animation fully ends and attack concludes
         - QTE
         - camera jump around, etc based on moves
         - should we base QTEs, camera movements, etc on animation events???
   - ⏳ Each character should have unique sound effects - TODO: Add audio

4. **Add more moves** to SampleMoves.luau
5. **Create enemy definitions** with varied stats and movesets
6. **Rework QTE system** to be more flexible and easier to use
7. **Implement rewards** (items, currency, XP)
- add windsurf / ai rules
- use requesthandler for current events!(RequestHandler.wrap Type Erasure)


## Known Limitations

- **AoE + Combo**: `Combo` in `Attempt.luau` breaks when `context.defender` (primary target) dies. For a hypothetical AoE Combo (multi-hit on all enemies), the combo would stop early if the primary target dies even though other enemies are alive. No current moves use AoE + Combo, so this is future-proofing only. Fix: make Combo break condition check if any valid target is alive, not just the primary.
- **AoE damage tracking**: `context.damage` in `SingleAttempt`/`Combo` only tracks HP change on `context.defender` (primary target). AoE damage to secondary targets isn't captured. `AfterHit` passives (OnKill, OnDamaged) only trigger for the primary target. Client still sees correct HP for all battlers via `sendBattleStateToPlayers`.
- **ActionExecuted reports single target**: The `ActionExecuted` event sends `target` as the primary battler only. For AoE, `targetType = "allEnemies"` tells the client the scope. Damage in the event payload is primary-target-only.

- half the tests dont work!
- Natsu issues
   - camera for moves and battle system(might be good as a whole client service?)
      - default camera placement for battle based on both player and enemy positions(general positioning and angling like in most turn based games)
      - camera shake, tweens, states, etc for moves, hits, etc frames for dodging, etc(based on moves I presume)
         - Dont worry about actually making them per move, just worry on infrastructure for it
         - I was thinking of using animation events to trigger camera effects, but if there are better / other ways, I'm all ears.
      - not just fov changes or whatever is happening now
      - camera should be able to zoom in and out based on moves and stuff, camera should be able to change angles, target / focus on different things, tween, etc.

   - implement luffy moveset
   - handle ties?(burn proc dead, etc)
   - vfx & sounds for all moves for natsu + luffy
   - first attack from pve battles for AI / npc characters doesn't show up in logs but effects visible in ui(if it was a damaging move you see your hp is lower than max, if its a buffing move you see the buff on them, etc).
   - Attacker QTEs?
   - natsu humanoidDescription!
   - I need too implement two more attacks for natsu - just give me several ideas and I'll pick two(natsu is fire type but as a dragon slayer he should have some other types of moves too - beast, or physical, etc)
   - For AoE attacks, only the single resolved self.defender gets a QTE window. If they dodge, cancelHit = true cancels the whole action — all targets are spared. Fine for 1v1, a design concern if multi-player AoE is ever added.
   - In the future, we could gate Fire Dragon Stacks gain from passive eating fire behind a successful defensive QTE or specific move triggers for more skill-based expression.
      - similarly for all attacks you deal!
   - Is combo execute reactionResult working correctly with reaction stuff(parry, dodge, etc)?  
   - multiple dodge, parry and damage events per animation, etc?
   - test multi target moves with multiple enemies!
   - walk to speed too high or anim speed on the walks is too high(look like the flash when walking back or to)
   - test what battle modifiers are even being added???(are they actually being constrained to the turn action)
   - npcs dont have an animate script?!
   - Cant tell the difference between characters from the battle log if attacker and defender are the same character!
   - event for tping - no walking animation
   - move billboard action prompt are displaying much better around the character but it could be better! Right now the second and third move have some overlap and some of the button is covered by the player's character! Also 1st and 4th moves are too far apart from the center character!