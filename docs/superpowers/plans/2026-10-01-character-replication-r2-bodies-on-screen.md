# Character Replication R2 — Bodies on Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every player gets a client-only body: the owner simulates its own rig and streams it to the server, the server validates and relays it under the 700 B per-viewer cap, and every other client draws it as a pooled, interpolated puppet in the default look — with no engine character anywhere.

**Architecture:** A new `CharacterReplicationService` (server + client) built as thin shells over pure, spec-first cores. Server cores: `UplinkIngest` (dedupe, epoch, time bounds), `UplinkPipeline` (the uplink through an extended `RequestHandler.wrap`), `ReplicationSlots`, `VisibilitySet`, `DownlinkScheduler` (encode once, priority accumulator, cap, budget) and `ReplicationFanout` (one server frame). Client cores: `UplinkSender` and `RemoteBodies` (slot table, batches, render clock, interpolation). Shared wire codecs (`CharacterUplinkCodec`, `CharacterBatchCodec`) sit beside R1's modules. Other players' public data rides charm-sync through a relevance-filtered public slice. Stats, Slots, Customization, Animate/Locomotion, Admin, TuneOffset and the Debugger are rewired to one body API.

**Tech Stack:** Luau `--!strict`, ByteNetMax (first unreliable packets), Charm + charm-sync, SignalPlus via `SignalTyped`, TestEZ specs (Studio `RunTests`), Rojo, selene, StyLua, luau-lsp 1.68.1.

**Spec:** `docs/superpowers/specs/2026-09-22-character-replication-design.md` — read the **Verdict** (top ~95 lines: phase map, "Decided for the R2 plan", "R2 must carry") first; it supersedes older numbers in §6. Then §5.1, §6, §8, §12. R1 plan (format and the modules R2 consumes): `docs/superpowers/plans/2026-09-30-character-replication-r1-core-library.md`.

## Global Constraints

- `--!strict` in every module; specs are intentionally untyped (repo rule). **No `any`, no `::` casts** in production code (`scripts/python/check_pr_rules.py` rejects `:: any` and warns on any uncommented `::`).
- **Service shape: lean annotated literal** — `export type X = {...}` + `local X: X = {...}`, methods as fields, callers use colon syntax (AGENTS.md, `docs/conventions.md`).
- Discovery by filename: `*ServiceServer` under `ServerScriptService/Services`, `*ServiceClient` under `ReplicatedStorage/Client/Services`. Helper modules in those folders must NOT contain the word `Service` (the boot loaders warn on near-misses).
- **Pure core + thin shell.** Pure modules are written spec-first (`<Name>.spec.luau` before `<Name>.luau`). Every module under a spec root has a `.spec` sibling or an `EXEMPT_MODULES` entry with a reason in `src/ServerScriptService/Modules/SpecRoots.luau` (the suite fails otherwise).
- Max **400 code lines** per module (`scripts/python/check_file_length.py`; comments and blank lines don't count).
- Specs are TestEZ and run **only in Studio** (`RunTests` Workspace attribute). Specs under `ReplicatedStorage.Client` run on the SERVER during the suite, so client cores must not touch `Players.LocalPlayer` at require time.
- **Never run `bash scripts/check.sh` or `wally install`** — they break the developer's live `rojo serve`. Use the individual static checks in "Commands". The controller runs the Studio TestEZ suite.
- Never name other games or studios in code comments, docs or commit messages; describe alternatives as "several techniques were tried". Library names (ByteNet, Charm, charm-sync, Chickynoid) are fine.
- Commits: plain messages, **no `Co-Authored-By:` or `Claude-Session:` trailers** (AGENTS.md).
- **Server-authoritative.** Clients never write authoritative state: the epoch, the slot table, spawn points, health and visibility are server-owned; the owner's samples are validated before anything is relayed.
- One body API: no system reads `player.Character` for another player's body. Server: `bodySpawned` / `bodyDespawned` / `observeBodies` / `hasBody` / `getBodyPosition` / `respawn` / `setMaxHealth`. Client: `bodySpawned` / `bodyDespawned` / `getRig` / `getPlayerFromRig` / `getLocalRig`.
- Wire constants (from the Verdict and R1): record 16 B; batch header 7 B (`u16 seq · u32 batchTimeMs · u8 count`); uplink packet `u32 sentMs · u8 count · count × 16 B` (count 1–3, newest first, each record's `ageMs` = sentMs − sample time); relevance 600 studs, release 630; hard cap 700 B per viewer-frame; per-viewer budget 24 KB/s; uplink bucket 10, refill 60/s on the send-time clock `min(sentMs, serverSessionNowMs + 64) / 1000`; epoch bumps ≥ 250 ms apart; ragdoll state 29 is rejected on the uplink.
- **R2–R5 are stacked with no feature flag.** R2 draws other players in the default look, without animation, chat bubbles or voice; the owner's own rig animates locally. Do not add dual paths.
- **Anti-cheat is its own later phase.** R2 keeps basic ingest validation only (exact sizes, field ranges via the codec, epoch, time bounds, dedupe, timestamp-paced flood limit, ragdoll rejection). No `AntiCheatServiceServer`, no `MovementRules` envelope.

## Review Focus

1. **A player leaves and a new one (or the same one) joins seconds later** — the slot is reused at once; viewers must build a fresh body for the newcomer, never inherit the leaver's buffer or puppet (Task 5 test `release bumps the slot generation, so a reused slot is a new identity`; Task 11 test `a new generation on a slot replaces the body (a rejoiner inherits nothing)`).
2. **The owner's window stalls (tab-out, long frame) and its uplink backlog lands in one burst** — it must be accepted, paced by the packets' send times, not dropped as a flood and not misread as future samples (Task 4 tests `lets a backlog through: 30 packets sent 17 ms apart arrive at once` and `never reads an old sample as a future one`).
3. **A body standing still for minutes** — repairs keep arriving once a second; they must hold the puppet in place as new samples with transit-only lateness, not raise the render delay or read as stale (Task 6 test `restamps a sample older than 1023 ms as a still body at batch time`; Task 11 test `a restamped repair is a new sample with transit-only lateness`).
4. **A viewer pacing back and forth at the edge of relevance** — no enter/leave churn between 600 and 630 studs (Task 5 test `holds membership between 600 and 630 studs`; Task 7 test `enters at 600 studs and leaves past 630, once each`).
5. **A respawn whose first new-epoch records are lost, or two respawns in a row** — the puppet must recover from the reliable slot table instead of dropping every record forever (Task 2 test `lets a buffer skip lost epochs when the slot table says so`; Task 11 test `the slot table resets a buffer that missed an epoch bump`).

## Rulings this plan makes (where the spec was silent or conflicted)

Each is binding for the implementer; the reasons are in the report and in the code comments where they apply.

1. `RequestHandler` validates **before** rate limiting only when a custom `clock` is set (the clock reads packet bytes). Without a clock the order stays rate-limit-then-validate, so invalid spam is still capped before validation. Both behaviours are pinned by specs.
2. Luau generics accept existing two-return validators (verified with luau-lsp 1.68.1 against the exact `HandlerConfig<T, D>` shape below). Inference does NOT catch a mismatch between a validator's third return and the handler's third parameter, so every decoding caller annotates both against one named type. No separate `decode` field.
3. Uplink record ages are relative to the packet's full u32 send time, so the 10-bit owner-time unwrap is not used on the uplink and the alias cannot happen. Ingest keeps samples in `[now − 1000 ms, now + 64 ms]`; the alias regression test lives in Task 3 and Task 4.
4. Uplink redundancy carries the previous samples as full 16 B records (21 / 37 / 53 B packets), not delta-coded.
5. The uplink has no sequence number: a sample's time is its identity. Dedupe compares against the last 4 accepted samples (age bits masked); an older sample outside that window is dropped as stale. R2 keeps no history ring (it lands with lag compensation).
6. §6.3's lower timestamp bound and drift-slope check are deferred to the anti-cheat phase: they would reject the stall backlog the Verdict says must be accepted. R2 bounds: 1000 ms old, 64 ms ahead, 15 ms minimum spacing.
7. Downlink scheduling is a priority accumulator (Verdict, "Downlink scheduling is a priority accumulator"). The v3 send policy per body decides which bodies are due (change / 2 resends 50 ms apart / 1 Hz repair, encoded once). Per viewer, each due body's score grows every frame by a closeness weight (3 within 50 studs, falling linearly to 1 at 600); bodies that are not due never accumulate. If every due record fits the 700 B cap and the budget, all of them go with no ordering; otherwise the highest scores fill the batch (an in-place partial heap selection, no full sort, no allocation), and a sent body's score resets to 0. Far cap: a body beyond 300 studs whose last record to that viewer went out under 33 ms ago is held that frame (30 Hz at most), staying due with its score kept. A due record that is not sent stays due until it is. All numbers live in `DownlinkScheduler.DEFAULT_CONFIG` and are measured in Task 13. §6.4's full error prediction is not built.
8. Repair restamp: a sample older than 1023 ms at batch time goes out with age 0 and zero velocity — "still here as of now".
9. `starving` means the renderer is in `hold` only. `behind` is a too-large delay that `reachMs` corrects; it is never lateness.
10. A batch's lateness vote is the largest lateness among the batch's new samples; resends and repairs whose samples a buffer already holds never vote.
11. The R2 public entry is `{ health, maxHealth }`; a viewer's relevant set is its loaded bodies plus itself; map keys are string userIds; each player has its own entry atom so one player's change re-runs only the getters of viewers who have that player relevant.
12. In R2 the replication service owns body health (`health`, `maxHealth`); `StatsServiceServer` pushes `maxHealth`. There is no damage source in R2.
13. `tuneoffset` refuses (with the reason) until client-side appearance lands in R4 — there is no server rig to nudge and no cosmetics on any rig in R2.
14. Server-side appearance application is removed; the default-backfill stays on `bodySpawned`. `CustomizationApplication` is left in place, unused, for R4 to move.
15. `Animate.client.luau` is replaced by `LocomotionBinding` (bound by the client service on the owner rig); the `StarterCharacterScripts` project node is removed.
16. `AdminServiceClient` no longer waits for a character at all: with no engine character the engine never copies StarterGui, so CmdrClient's own GUI is the only one.
17. An epoch bump requested under 250 ms after the last one is ignored (the body is already fresh).
18. The server publishes the rig template (`StarterPlayer.StarterCharacter`, scripts stripped) to `ReplicatedStorage.CharacterRigTemplate`; a place without `StarterCharacter` fails the boot loudly.
19. A fall-plane respawn request is honoured only when the last accepted position is within 100 studs of `Workspace.FallenPartsDestroyHeight`.
20. Reliable packets (`Session`, `SlotEntry`, `Spawn`, `Enter`, `Leave`, `Ready`, `RespawnRequest`) are typed ByteNet structs; `Uplink` and `Downlink` are unreliable `buff` packets.
21. Puppets: at most one build per frame; up to 8 idle puppets pooled; hidden at (0, 50000, 0), never unparented.
22. The integrated harness and the load measurement live in the server service folder (they need server cores).
23. (Studio run, 2026-10-01) Superseded in Task 2: the loss "takeback" (receivedMask) was removed — a reordered batch counts toward the render margin like a loss (measured: mobile mean 0.175 → 0.104). And a missing StarterCharacter now leaves replication inert with a logged error instead of failing the boot (supersedes ruling 18). Task 2's receivedMask code below is historical.

---

## File Structure

```
src/ServerScriptService/Modules/RequestHandler.luau(+spec)                     (T1) token bucket, clock, decode, onReject
src/ReplicatedStorage/Shared/Events/DebuggerEvents.luau                         (T1) RateLimitSnapshot shape
src/ServerScriptService/Services/DebuggerService/DebuggerServiceServer.luau(+spec) (T1) rate rows + test seam
src/ReplicatedStorage/Client/UI/React/Debugger/StatePanel.luau                  (T1, T12) rate rows; rig highlight
src/ReplicatedStorage/Shared/Modules/CharacterReplication/
  CharacterInterpolator.luau(+spec)       (T2) push result, isNewSample, resetEpoch, isStarving, evaluatePose
  RenderClock.luau(+spec)                 (T2) loss under reorder, starving/lateness docs
  Harness/HarnessVenture.luau             (T2) uses push's result and isStarving
  CharacterUplinkCodec.luau(+spec)        (T3) uplink packet, decode-side checks
  CharacterBatchCodec.luau(+spec)         (T3) downlink batch validation
src/ReplicatedStorage/Shared/Events/CharacterReplicationEvents.luau             (T9) ByteNet namespace
src/ReplicatedStorage/Shared/Types/PublicPlayerTypes.luau                       (T8) public entry type
src/ReplicatedStorage/Shared/State/SyncState.luau(+spec)                        (T8) public keys
src/ServerScriptService/State/PublicPlayerState.luau(+spec)                     (T8) public slice + relevance
src/ReplicatedStorage/Client/State/ClientStore.luau                             (T8) publicPlayers atom
src/ServerScriptService/Services/StateSyncService/StateSyncServiceServer.luau(+spec) (T8)
src/ReplicatedStorage/Client/Services/StateSyncService/StateSyncServiceClient.luau   (T8)
src/ServerScriptService/Services/CharacterReplicationService/
  UplinkIngest.luau(+spec)                (T4)
  UplinkPipeline.luau(+spec)              (T4)
  ReplicationSlots.luau(+spec)            (T5)
  VisibilitySet.luau(+spec)               (T5)
  DownlinkScheduler.luau(+spec)           (T6)
  ReplicationFanout.luau(+spec)           (T7)
  ReplicationInstances.luau               (T9)  [spec-exempt: shell] rig template, focus parts, spawn point
  CharacterReplicationServiceServer.luau  (T9)  [spec-exempt: shell]
  HarnessIntegrated.luau(+spec)           (T13)
  ReplicationLoad.spec.luau               (T13) measurement spec
src/ReplicatedStorage/Client/Services/CharacterReplicationService/
  UplinkSender.luau(+spec)                (T10)
  OwnerRig.luau                           (T10) [spec-exempt: shell]
  CharacterReplicationServiceClient.luau  (T10, T11) [spec-exempt: shell]
  RemoteBodies.luau(+spec)                (T11)
  PuppetPool.luau                         (T11) [spec-exempt: shell]
src/ReplicatedStorage/Client/Services/AnimationService/LocomotionBinding.luau   (T10) [spec-exempt: shell]
src/StarterPlayer/StarterCharacterScripts/Animate.client.luau                   (T10) deleted
src/ReplicatedStorage/Client/Services/AdminService/AdminServiceClient.luau      (T10)
default.project.json                                                            (T9, T10)
src/ServerScriptService/Services/SlotService/SlotServiceServer.luau(+spec)      (T12)
src/ServerScriptService/Services/StatsService/StatsServiceServer.luau(+spec)    (T12)
src/ServerScriptService/Services/CustomizationService/CustomizationServiceServer.luau(+spec) (T12)
src/ServerScriptService/Commands/TuneOffsetServer.luau(+spec)                   (T12)
src/ServerScriptService/Modules/SpecRoots.luau                                  (T9, T10, T11) exemptions
docs/architecture.md, docs/animation.md, docs/conventions.md, AGENTS.md          (T12)
docs/ROADMAP.md                                                                  (T13)
```

## Commands

Run from the worktree root `B:\Projects\venture-game-systems\.claude\worktrees\character-replication-r2` (Git Bash). Branch: `feature/replication-bodies`, stacked on the R1 branch `feature/character-replication` (PR #28). Later stacked phases follow `feature/replication-<topic>` (R3 `feature/replication-animation`, R4 `feature/replication-appearance`).

**One-time setup** (the worktree has no package folders; copy them — never run `wally install`):

```bash
cp -r ../../../Packages ../../../ServerPackages ../../../DevPackages ../../../globalTypes.d.luau .
```

All four are gitignored. If `globalTypes.d.luau` is missing in the main checkout too: `curl -fsSL "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.68.1/scripts/globalTypes.d.luau" -o globalTypes.d.luau`.

| Purpose | Command |
|---|---|
| Format | `stylua <touched paths>` then `stylua --check src` |
| Lint | `selene src` |
| Typecheck | `rojo sourcemap default.project.json --output sourcemap.json && luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau --ignore="**/*.spec.luau" src` — no NEW diagnostics in the files the task touched |
| File length | `python scripts/python/check_file_length.py` |
| Project rules | `python scripts/python/check_pr_rules.py feature/character-replication` (casts, trailers) |
| Tests | Studio only. The developer serves THIS worktree with `rojo serve` and connects; set the Workspace boolean attribute `RunTests = true`, press Play, read Output. Expected tail: `<N> passed, 0 failed, 0 skipped`. Remove the attribute afterwards (a test session destroys live singletons; never play in it). |

Each task's "run the tests" step means the Studio run above. When an implementer cannot drive Studio, stop at that step and hand it to the controller with the exact spec names expected to fail or pass. Tasks marked **Runtime behaviour: yes** change what a play session does; the developer verifies those in Studio before merge (AGENTS.md / developer rule: never merge runtime changes unverified).

---
### Task 1: Extend `RequestHandler.wrap` (token bucket, clock, decode once, onReject)

**Runtime behaviour: yes** — every existing limiter becomes a token bucket (same `maxRequests` per `windowSeconds` on average, bursts up to `maxRequests`), and the F4 State tab's rate-limit rows show tokens left and drops instead of a request count.

**Files:**
- Modify: `src/ServerScriptService/Modules/RequestHandler.luau` (full replacement below)
- Modify: `src/ServerScriptService/Modules/RequestHandler.spec.luau`
- Modify: `src/ReplicatedStorage/Shared/Events/DebuggerEvents.luau:66-75` (`RateLimitSnapshot`)
- Modify: `src/ServerScriptService/Services/DebuggerService/DebuggerServiceServer.luau:100-114` (`collectRateLimits`) and its interface/literal (test seam)
- Modify: `src/ServerScriptService/Services/DebuggerService/DebuggerServiceServer.spec.luau`
- Modify: `src/ReplicatedStorage/Client/UI/React/Debugger/StatePanel.luau:336-350` (rate rows)

**Interfaces:**
- Produces (later tasks rely on these exact names):
  - `export type RateLimitConfig = { maxRequests: number, windowSeconds: number }`
  - `export type RejectMode = "warn" | "count"`
  - `export type HandlerConfig<T, D> = { name: string, rateLimit: RateLimitConfig?, validate: ((data: T, player: Player) -> (boolean, string?, D?))?, handler: (data: T, player: Player, decoded: D?) -> ...any, clock: ((data: T, player: Player) -> number)?, onReject: RejectMode?, audit: boolean? }`
  - `RequestHandler.wrap<T, D>(config: HandlerConfig<T, D>): (data: T, player: Player) -> any`
  - `RequestHandler.createRateLimiter(actionName: string, config: RateLimitConfig): (userId: number) -> boolean`
  - `export type RateLimitEntry = { userId: number, action: string, tokensRemaining: number?, capacity: number?, rejected: number }`
  - `RequestHandler.getAllRateLimitStatus(): { RateLimitEntry }`
  - `RequestHandler.getRateLimitStatus(userId: number, actionName: string): { tokensRemaining: number?, capacity: number?, rejected: number }`
  - `RequestHandler.resetRateLimit(userId: number, actionName: string?)` (unchanged)
  - `DebuggerServiceServer._collectRateLimits: () -> { DebuggerEvents.RateLimitSnapshot }` (test seam)

- [ ] **Step 1: Write the failing specs**

In `src/ServerScriptService/Modules/RequestHandler.spec.luau`:

(a) Replace the whole `describe("resetRateLimit", ...)` block's second test body (`"should clear all actions when no actionName given"`) with:

```luau
		it("should clear all actions when no actionName given", function()
			RequestHandler.resetRateLimit(21)
			local status = RequestHandler.getRateLimitStatus(21, "anything")
			expect(status.tokensRemaining).to.equal(nil)
			expect(status.rejected).to.equal(0)
		end)
```

(b) Replace the whole `describe("getRateLimitStatus", ...)` block with:

```luau
	describe("getRateLimitStatus", function()
		afterEach(function()
			RequestHandler.resetRateLimit(30)
		end)

		it("reports no bucket and no drops for a new userId/action", function()
			local status = RequestHandler.getRateLimitStatus(30, "NewAction")
			expect(status.tokensRemaining).to.equal(nil)
			expect(status.capacity).to.equal(nil)
			expect(status.rejected).to.equal(0)
		end)

		it("reports the tokens left after requests", function()
			local wrapped = RequestHandler.wrap({
				name = "StatusCheck",
				rateLimit = { maxRequests = 10, windowSeconds = 60 },
				handler = function() end,
			})
			local p = mockPlayer(30)
			wrapped({}, p)
			wrapped({}, p)
			local status = RequestHandler.getRateLimitStatus(30, "StatusCheck")
			expect(status.capacity).to.equal(10)
			expect(status.tokensRemaining).to.be.near(8, 0.01)
		end)
	end)
```

(c) Replace the whole `describe("getAllRateLimitStatus", ...)` block with:

```luau
	describe("getAllRateLimitStatus", function()
		afterEach(function()
			RequestHandler.resetRateLimit(701)
			RequestHandler.resetRateLimit(702)
		end)

		it("returns an entry for every tracked (user, action) pair", function()
			local wrapped = RequestHandler.wrap({
				name = "DumpA",
				rateLimit = { maxRequests = 10, windowSeconds = 60 },
				handler = function() end,
			})
			wrapped({}, mockPlayer(701))
			wrapped({}, mockPlayer(701))
			wrapped({}, mockPlayer(702))

			local spent = {}
			for _, entry in RequestHandler.getAllRateLimitStatus() do
				-- Only assert on the users this test created; the dump is global.
				if (entry.userId == 701 or entry.userId == 702) and entry.action == "DumpA" then
					spent[entry.userId] = (entry.capacity or 0) - (entry.tokensRemaining or 0)
				end
			end

			expect(spent[701]).to.be.near(2, 0.01)
			expect(spent[702]).to.be.near(1, 0.01)
		end)
	end)
```

(d) Append these blocks inside the returned function, after the `getAllRateLimitStatus` block (before the final `end`):

```luau
	-- -------------------------------------------------------------------------
	describe("wrap — token bucket", function()
		afterEach(function()
			RequestHandler.resetRateLimit(60)
		end)

		-- A custom clock makes refill deterministic: maxRequests = 2 per 1 s → bucket 2, refill 2/s.
		local function bucketed(nowRef)
			local calls = 0
			local wrapped = RequestHandler.wrap({
				name = "Bucket",
				rateLimit = { maxRequests = 2, windowSeconds = 1 },
				clock = function()
					return nowRef.now
				end,
				handler = function()
					calls += 1
				end,
			})
			return wrapped, function()
				return calls
			end
		end

		it("holds maxRequests tokens and refills maxRequests / windowSeconds per second", function()
			local nowRef = { now = 0 }
			local wrapped, calls = bucketed(nowRef)
			local p = mockPlayer(60)
			for _ = 1, 3 do
				wrapped({}, p)
			end
			expect(calls()).to.equal(2)
			nowRef.now = 0.5 -- one token back
			wrapped({}, p)
			wrapped({}, p)
			expect(calls()).to.equal(3)
			nowRef.now = 100 -- refill caps at the bucket size
			for _ = 1, 3 do
				wrapped({}, p)
			end
			expect(calls()).to.equal(5)
		end)

		it("never refills on a clock that moves backwards", function()
			local nowRef = { now = 5 }
			local wrapped, calls = bucketed(nowRef)
			local p = mockPlayer(60)
			wrapped({}, p)
			wrapped({}, p)
			nowRef.now = 4
			wrapped({}, p)
			nowRef.now = 4.9 -- still behind the last clock reading (5): no refill
			wrapped({}, p)
			expect(calls()).to.equal(2)
			nowRef.now = 5.5
			wrapped({}, p)
			expect(calls()).to.equal(3)
		end)

		it("refills nothing on a NaN clock", function()
			local nowRef = { now = 1 }
			local wrapped, calls = bucketed(nowRef)
			local p = mockPlayer(60)
			wrapped({}, p)
			wrapped({}, p)
			nowRef.now = 0 / 0
			wrapped({}, p)
			expect(calls()).to.equal(2)
		end)
	end)

	-- -------------------------------------------------------------------------
	describe("wrap — order of validate and rate limit", function()
		afterEach(function()
			RequestHandler.resetRateLimit(61)
		end)

		it("validates before a custom clock reads the packet, and an invalid packet costs no token", function()
			local order = {}
			local wrapped = RequestHandler.wrap({
				name = "ClockOrder",
				rateLimit = { maxRequests = 3, windowSeconds = 1 },
				onReject = "count",
				validate = function(data)
					table.insert(order, "validate")
					return data.ok == true, "bad"
				end,
				clock = function()
					table.insert(order, "clock")
					return 0
				end,
				handler = function() end,
			})
			wrapped({ ok = false }, mockPlayer(61))
			expect(table.concat(order, ",")).to.equal("validate")
			expect(RequestHandler.getRateLimitStatus(61, "ClockOrder").tokensRemaining).to.equal(nil)
			wrapped({ ok = true }, mockPlayer(61))
			expect(table.concat(order, ",")).to.equal("validate,validate,clock")
			expect(RequestHandler.getRateLimitStatus(61, "ClockOrder").tokensRemaining).to.be.near(2, 1e-9)
		end)

		it("without a clock, a rate-limited request never reaches validate", function()
			local validations = 0
			local wrapped = RequestHandler.wrap({
				name = "PlainOrder",
				rateLimit = { maxRequests = 1, windowSeconds = 60 },
				onReject = "count",
				validate = function()
					validations += 1
					return true
				end,
				handler = function() end,
			})
			wrapped({}, mockPlayer(61))
			wrapped({}, mockPlayer(61))
			expect(validations).to.equal(1)
		end)
	end)

	-- -------------------------------------------------------------------------
	describe("wrap — decode once", function()
		it("passes the validator's third return to the handler", function()
			local seen = nil
			local wrapped = RequestHandler.wrap({
				name = "Decode",
				validate = function(data)
					return true, nil, { doubled = data.value * 2 }
				end,
				handler = function(_data, _player, decoded)
					seen = decoded
				end,
			})
			wrapped({ value = 21 }, mockPlayer(62))
			expect(seen).to.be.ok()
			expect(seen.doubled).to.equal(42)
		end)

		it("leaves the third argument nil for a two-return validator", function()
			local argumentCount = -1
			local wrapped = RequestHandler.wrap({
				name = "TwoReturn",
				validate = function()
					return true, nil
				end,
				handler = function(...)
					argumentCount = select("#", ...)
					local _, _, decoded = ...
					expect(decoded).to.equal(nil)
				end,
			})
			wrapped({}, mockPlayer(62))
			expect(argumentCount).to.equal(3)
		end)
	end)

	-- -------------------------------------------------------------------------
	describe("wrap — onReject", function()
		afterEach(function()
			RequestHandler.resetRateLimit(63)
		end)

		local function countWarnings(fn)
			local warnings = 0
			local unsubscribe = Logger.subscribe(function(entry)
				if entry.level == "WARN" then
					warnings += 1
				end
			end)
			fn()
			unsubscribe()
			return warnings
		end

		it("count mode counts drops without logging a warning", function()
			local wrapped = RequestHandler.wrap({
				name = "Counted",
				rateLimit = { maxRequests = 1, windowSeconds = 60 },
				onReject = "count",
				validate = function(data)
					return data.ok == true, "bad"
				end,
				handler = function() end,
			})
			local warnings = countWarnings(function()
				wrapped({ ok = true }, mockPlayer(63))
				wrapped({ ok = true }, mockPlayer(63)) -- rate limited
				wrapped({ ok = false }, mockPlayer(63)) -- rate limited before validation (no clock)
			end)
			expect(warnings).to.equal(0)
			expect(RequestHandler.getRateLimitStatus(63, "Counted").rejected).to.equal(2)
		end)

		it("warn mode (the default) logs a warning per drop", function()
			local prev = Logger.getGlobalLevel()
			Logger.setGlobalLevel("WARN")
			local wrapped = RequestHandler.wrap({
				name = "Warned",
				validate = function()
					return false, "bad"
				end,
				handler = function() end,
			})
			local warnings = countWarnings(function()
				wrapped({}, mockPlayer(63))
				wrapped({}, mockPlayer(63))
			end)
			Logger.setGlobalLevel(prev)
			expect(warnings).to.equal(2)
		end)
	end)

	-- -------------------------------------------------------------------------
	describe("wrap — per-call cost", function()
		afterEach(function()
			RequestHandler.resetRateLimit(64)
		end)

		it("allocates nothing per accepted call", function()
			local wrapped = RequestHandler.wrap({
				name = "Cheap",
				rateLimit = { maxRequests = 100000, windowSeconds = 1 },
				validate = function()
					return true
				end,
				handler = function() end,
			})
			local payload = {}
			local player = mockPlayer(64)
			for _ = 1, 100 do
				wrapped(payload, player) -- warm: the (user, action) bucket is created once
			end
			local before = collectgarbage("count")
			for _ = 1, 2000 do
				wrapped(payload, player)
			end
			local grownKb = collectgarbage("count") - before
			-- A closure or table per call would be ≥ 64 KB here.
			expect(grownKb < 16).to.equal(true)
		end)
	end)
```

In `src/ServerScriptService/Services/DebuggerService/DebuggerServiceServer.spec.luau`, append inside the returned function (after the admin-gate `describe`):

```luau
	describe("rate-limit rows", function()
		local USER = -9101

		afterEach(function()
			RequestHandler.resetRateLimit(USER)
		end)

		it("reports tokens remaining, the bucket size and drops per (user, action)", function()
			local wrapped = RequestHandler.wrap({
				name = "DebuggerSpecRows",
				rateLimit = { maxRequests = 2, windowSeconds = 60 },
				onReject = "count",
				handler = function() end,
			})
			local player = { UserId = USER } :: any
			wrapped(true, player)
			wrapped(true, player)
			wrapped(true, player) -- dropped
			local found = nil
			for _, row in DebuggerServiceServer._collectRateLimits() do
				if row.userId == USER and row.action == "DebuggerSpecRows" then
					found = row
				end
			end
			expect(found).to.be.ok()
			expect(found.capacity).to.equal(2)
			expect(found.tokensRemaining < 1).to.equal(true)
			expect(found.rejected).to.equal(1)
		end)
	end)
```

- [ ] **Step 2: Run the tests and verify they fail**

Studio test run. Expected failures: the new `wrap — token bucket`, `wrap — order of validate and rate limit`, `wrap — decode once`, `wrap — onReject`, `wrap — per-call cost` cases, the rewritten `getRateLimitStatus` / `getAllRateLimitStatus` / `resetRateLimit` cases (no `tokensRemaining` field yet), and `rate-limit rows` (`_collectRateLimits` is nil).

- [ ] **Step 3: Replace `RequestHandler.luau`**

(Four-backtick fence: the module's doc comment contains a ```lua usage block.)

````luau
--!strict
--[=[
	RequestHandler: middleware for inbound client requests.

	Wraps ByteNet packet handlers with:
	- a per-player TOKEN BUCKET per action: `maxRequests` is the bucket size, refilled at
	  `maxRequests / windowSeconds` tokens per second. Constant time and allocation-free per call (one
	  bucket per (player, action), created on first use).
	- validation that may also DECODE: a validator's optional third return is passed to the handler as
	  its third argument, so a packet is decoded once.
	- an optional custom `clock` (seconds) the bucket refills by. The character uplink uses the send time
	  written in each packet, so a backlog released after a stall pays for itself instead of reading as a
	  flood. Elapsed time is never negative: a clock that moves backwards (or reads NaN) refills nothing.
	- `onReject = "count"` for high-rate packets: drops are counted per (player, action) for the Debugger
	  instead of logging a warning each. The default, "warn", logs one warning per drop.
	- audit logging (optional) and `xpcall` isolation of the handler.

	Order: rate limit, then validate — a flood of invalid requests is capped before validation runs.
	EXCEPT with a custom `clock`: the clock reads the packet, which only validation proves well-formed,
	so validation runs first and an invalid packet costs no token.

	Typing: `HandlerConfig<T, D>` accepts the existing two-return validators unchanged (D is then
	unconstrained and the handler's third argument is nil). Luau's inference does NOT check that a
	validator's third return and the handler's third parameter agree, so a decoding caller annotates both
	against one named type (see UplinkPipeline).

	Usage:
	```lua
	MyEvents.packets.BuyItem.listen(function(data, player)
		if player then onBuyItem(data, player) end
	end)
	local onBuyItem = RequestHandler.wrap({
		name = "BuyItem",
		rateLimit = { maxRequests = 5, windowSeconds = 10 },
		handler = function(data, player)
			return ShopService:buyItem(player.UserId, data.itemId)
		end,
	})
	```

	CONTRACT — fire-and-forget events ONLY. On a rate-limit hit or validation failure the wrapped
	handler silently returns nil to the caller; the sender is never told. That is correct for
	one-way RemoteEvent/ByteNet event handlers (all current consumers), but it must NOT back a
	request/response (query) endpoint — the client would hang on, or misread, the silent nil.
	A query wrapper needs a typed rejection channel; add a `wrapQuery` variant if that need arises.

	@class RequestHandler
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Logger = require(ReplicatedStorage.Shared.Modules.Logger)

local log = Logger.new("RequestHandler")

local RequestHandler = {}

export type RateLimitConfig = {
	maxRequests: number, -- bucket size (the largest burst)
	windowSeconds: number, -- the bucket refills maxRequests tokens per windowSeconds
}

export type RejectMode = "warn" | "count"

export type HandlerConfig<T, D> = {
	name: string, -- action name for logging / rate limiting
	rateLimit: RateLimitConfig?,
	-- Returns ok, an error message, and optionally the decoded request handed to `handler`.
	validate: ((data: T, player: Player) -> (boolean, string?, D?))?,
	handler: (data: T, player: Player, decoded: D?) -> ...any,
	-- Seconds the bucket refills by (default os.clock). Requires `rateLimit`. Validation runs first.
	clock: ((data: T, player: Player) -> number)?,
	onReject: RejectMode?, -- "warn" (default) logs each drop; "count" counts it for the Debugger
	audit: boolean?, -- audit-log every accepted request (default false)
}

type Bucket = {
	tokens: number,
	lastClock: number,
	capacity: number,
	refillPerSecond: number,
	customClock: boolean,
}

type Entry = {
	bucket: Bucket?,
	rejected: number,
}

-- { [userId]: { [action]: Entry } }, created on first use, dropped when the player leaves.
local entries: { [number]: { [string]: Entry } } = {}

local function assertRateLimitConfig(config: RateLimitConfig)
	assert(type(config) == "table", `rateLimit must be a table, got {type(config)}`)
	assert(
		type(config.maxRequests) == "number" and config.maxRequests > 0,
		`rateLimit.maxRequests must be a positive number, got {type(config.maxRequests)}: {tostring(config.maxRequests)}`
	)
	assert(
		type(config.windowSeconds) == "number" and config.windowSeconds > 0,
		`rateLimit.windowSeconds must be a positive number, got {type(config.windowSeconds)}: {tostring(
			config.windowSeconds
		)}`
	)
end

Players.PlayerRemoving:Connect(function(player: Player)
	entries[player.UserId] = nil
end)

local function entryFor(userId: number, action: string): Entry
	local actions = entries[userId]
	if actions == nil then
		actions = {}
		entries[userId] = actions
	end
	local entry = actions[action]
	if entry == nil then
		entry = { bucket = nil, rejected = 0 }
		actions[action] = entry
	end
	return entry
end

-- The (user, action) bucket, created full on first use.
local function bucketFor(entry: Entry, config: RateLimitConfig, now: number, customClock: boolean): Bucket
	local existing = entry.bucket
	if existing ~= nil then
		return existing
	end
	local created: Bucket = {
		tokens = config.maxRequests,
		lastClock = now,
		capacity = config.maxRequests,
		refillPerSecond = config.maxRequests / config.windowSeconds,
		customClock = customClock,
	}
	entry.bucket = created
	return created
end

--[=[
	Takes one token at `now` (seconds on the bucket's clock). Elapsed time is only ever added when positive,
	so a clock that steps back (or is NaN) refills nothing and the last reading is kept.
]=]
local function takeToken(entry: Entry, config: RateLimitConfig, now: number, customClock: boolean): boolean
	local bucket = bucketFor(entry, config, now, customClock)
	local elapsed = now - bucket.lastClock
	if elapsed > 0 then
		bucket.tokens = math.min(bucket.capacity, bucket.tokens + elapsed * bucket.refillPerSecond)
		bucket.lastClock = now
	end
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

--[=[
	Wraps a handler with rate limiting, validation (and decoding), audit logging and isolation.
	@param config HandlerConfig<T, D>
	@return (data: T, player: Player) -> any -- the wrapped handler
]=]
function RequestHandler.wrap<T, D>(config: HandlerConfig<T, D>): (data: T, player: Player) -> any
	assert(type(config) == "table", `config must be a table, got {type(config)}`)
	assert(type(config.name) == "string", `config.name must be a string, got {type(config.name)}`)
	assert(type(config.handler) == "function", `config.handler must be a function, got {type(config.handler)}`)
	if config.validate ~= nil then
		assert(type(config.validate) == "function", `config.validate must be a function, got {type(config.validate)}`)
	end
	if config.rateLimit then
		assertRateLimitConfig(config.rateLimit)
	end
	if config.clock ~= nil then
		assert(type(config.clock) == "function", `config.clock must be a function, got {type(config.clock)}`)
		assert(config.rateLimit ~= nil, "config.clock needs config.rateLimit (it only drives the bucket)")
	end
	assert(
		config.onReject == nil or config.onReject == "warn" or config.onReject == "count",
		`config.onReject must be "warn" or "count", got {tostring(config.onReject)}`
	)

	local name = config.name
	local rateLimit = config.rateLimit
	local validate = config.validate
	local clock = config.clock
	local handler = config.handler
	local counting = config.onReject == "count"
	local audit = config.audit == true

	-- One closure per wrap (not per call): the reject path for both drop kinds.
	local function reject(userId: number, rateLimited: boolean, message: string?)
		if counting then
			entryFor(userId, name).rejected += 1
		elseif rateLimited then
			log:warn("Rate limited:", name, "userId:", userId)
		else
			log:warn("Validation failed:", name, "userId:", userId, "error:", message or "unknown")
		end
	end

	return function(data: T, player: Player)
		local userId = player.UserId
		local decoded: D? = nil

		if clock ~= nil and rateLimit ~= nil then
			-- The clock reads packet bytes: validate first, so it only ever sees a well-formed packet.
			if validate ~= nil then
				local ok, message, value = validate(data, player)
				if not ok then
					reject(userId, false, message)
					return nil
				end
				decoded = value
			end
			if not takeToken(entryFor(userId, name), rateLimit, clock(data, player), true) then
				reject(userId, true, nil)
				return nil
			end
		else
			if rateLimit ~= nil and not takeToken(entryFor(userId, name), rateLimit, os.clock(), false) then
				reject(userId, true, nil)
				return nil
			end
			if validate ~= nil then
				local ok, message, value = validate(data, player)
				if not ok then
					reject(userId, false, message)
					return nil
				end
				decoded = value
			end
		end

		-- Audit logging: the dedicated audit level, payload serialized so the line shows its contents.
		if audit then
			local ok, encoded = pcall(function()
				return HttpService:JSONEncode(data)
			end)
			log:audit("Audit:", name, "userId:", userId, "data:", ok and encoded or tostring(data))
		end

		-- The handler and its arguments go straight to xpcall: no closure per call.
		local success, result = xpcall(handler, debug.traceback, data, player, decoded)
		if not success then
			log:error("Handler error:", name, "userId:", userId, "error:", result)
			return nil
		end
		return result
	end
end

--[=[
	A standalone limiter for services that check a rate manually (same token bucket, os.clock).
	Check-AND-consume: each call that returns true takes a token. Call it once per logical request.
	@param actionName string
	@param config RateLimitConfig
	@return (userId: number) -> boolean
]=]
function RequestHandler.createRateLimiter(actionName: string, config: RateLimitConfig): (userId: number) -> boolean
	assert(type(actionName) == "string", `actionName must be a string, got {type(actionName)}`)
	assertRateLimitConfig(config)
	return function(userId: number): boolean
		return takeToken(entryFor(userId, actionName), config, os.clock(), false)
	end
end

--[=[
	One row of the rate-limit dump. `tokensRemaining` / `capacity` are nil for an action that has no
	rate limit and only counts drops (`onReject = "count"`).
]=]
export type RateLimitEntry = {
	userId: number,
	action: string,
	tokensRemaining: number?,
	capacity: number?,
	rejected: number,
}

-- Tokens as of now. A custom-clock bucket reports what it holds (this dump cannot read its clock).
local function tokensNow(bucket: Bucket): number
	if bucket.customClock then
		return bucket.tokens
	end
	local elapsed = os.clock() - bucket.lastClock
	if elapsed <= 0 then
		return bucket.tokens
	end
	return math.min(bucket.capacity, bucket.tokens + elapsed * bucket.refillPerSecond)
end

--[=[
	Every tracked (user, action): tokens left, bucket size, drops. Read-only introspection for the F4
	debugger's rate-limit rows.
	@return { RateLimitEntry }
]=]
function RequestHandler.getAllRateLimitStatus(): { RateLimitEntry }
	local result: { RateLimitEntry } = {}
	for userId, actions in entries do
		for action, entry in actions do
			local bucket = entry.bucket
			table.insert(result, {
				userId = userId,
				action = action,
				tokensRemaining = if bucket ~= nil then tokensNow(bucket) else nil,
				capacity = if bucket ~= nil then bucket.capacity else nil,
				rejected = entry.rejected,
			})
		end
	end
	return result
end

--[=[
	Resets one action's state for a player, or all of the player's state when `actionName` is nil.
	@param userId number
	@param actionName string?
]=]
function RequestHandler.resetRateLimit(userId: number, actionName: string?)
	if actionName then
		local actions = entries[userId]
		if actions then
			actions[actionName] = nil
		end
	else
		entries[userId] = nil
	end
end

--[=[
	One (user, action)'s bucket for debugging. Always returns a table.
	@param userId number
	@param actionName string
	@return { tokensRemaining: number?, capacity: number?, rejected: number }
]=]
function RequestHandler.getRateLimitStatus(
	userId: number,
	actionName: string
): { tokensRemaining: number?, capacity: number?, rejected: number }
	local actions = entries[userId]
	local entry = actions and actions[actionName]
	if entry == nil then
		return { tokensRemaining = nil, capacity = nil, rejected = 0 }
	end
	local bucket = entry.bucket
	return {
		tokensRemaining = if bucket ~= nil then tokensNow(bucket) else nil,
		capacity = if bucket ~= nil then bucket.capacity else nil,
		rejected = entry.rejected,
	}
end

return RequestHandler
````

- [ ] **Step 4: Update the Debugger consumers**

In `src/ReplicatedStorage/Shared/Events/DebuggerEvents.luau`, replace the `RateLimitSnapshot` doc and type:

```luau
--[=[
	One rate-limit bucket: tokens left (and the bucket size) for `userId`'s `action`, plus how many of
	those requests were dropped. `tokensRemaining`/`capacity` are nil for an action with no rate limit
	that only counts drops. Sourced from RequestHandler.getAllRateLimitStatus.
]=]
export type RateLimitSnapshot = {
	userId: number,
	action: string,
	tokensRemaining: number?,
	capacity: number?,
	rejected: number,
}
```

In `src/ServerScriptService/Services/DebuggerService/DebuggerServiceServer.luau`, replace `collectRateLimits`:

```luau
--[=[
	Collects every tracked rate-limit bucket from RequestHandler.
	@return { RateLimitSnapshot } -- One entry per tracked (user, action)
]=]
local function collectRateLimits(): { RateLimitSnapshot }
	local result: { RateLimitSnapshot } = {}
	for _, entry in RequestHandler.getAllRateLimitStatus() do
		table.insert(result, {
			userId = entry.userId,
			action = entry.action,
			tokensRemaining = entry.tokensRemaining,
			capacity = entry.capacity,
			rejected = entry.rejected,
		})
	end
	return result
end
```

Add to the `DebuggerServiceServer` export type (after `_pruneUnauthorizedSubscribers`):

```luau
	-- TEST SEAM — the rate-limit rows exactly as the snapshot assembles them.
	_collectRateLimits: () -> { RateLimitSnapshot },
```

and to the literal, next to the other seams (`_onSetSubscription = ...`):

```luau
	_collectRateLimits = collectRateLimits,
```

In `src/ReplicatedStorage/Client/UI/React/Debugger/StatePanel.luau`, replace the rate-row loop and header:

```luau
		local rateRows: { TableView.Row } = {}
		for _, entry in rateLimits do
			if entry.userId == effectiveSelected then
				local tokensRemaining, capacity = entry.tokensRemaining, entry.capacity
				local tokens = if tokensRemaining ~= nil and capacity ~= nil
					then string.format("%.1f / %d tokens", tokensRemaining, capacity)
					else "no limit"
				table.insert(rateRows, { name = entry.action, value = `{tokens} · {entry.rejected} dropped` })
			end
		end
		if #rateRows > 0 then
			detailChildren["rates"] = e(TableView, {
				keyHeader = "Rate limit",
				valueHeader = "Bucket",
				rows = rateRows,
				layoutOrder = 2,
			})
		end
```

- [ ] **Step 5: Run the static checks**

Format, Lint, Typecheck, File length, Project rules (see Commands). Typecheck must show no new diagnostics in `DebuggerServiceServer.luau` and `StateSyncServiceServer.luau` — this is the proof that the two-return validators (`validateAdmin`) and validator-less callers still type-check against `HandlerConfig<T, D>`.

- [ ] **Step 6: Run the tests and verify they pass**

Studio test run: all `RequestHandler` cases, `rate-limit rows`, and the existing `StateSyncServiceServer` (`rate limits the ready ping ... (5 per 10s window)`) and `DebuggerServiceServer` admin-gate cases pass; whole suite green.

- [ ] **Step 7: Commit**

```bash
git add src/ServerScriptService/Modules/RequestHandler.luau src/ServerScriptService/Modules/RequestHandler.spec.luau src/ReplicatedStorage/Shared/Events/DebuggerEvents.luau src/ServerScriptService/Services/DebuggerService/DebuggerServiceServer.luau src/ServerScriptService/Services/DebuggerService/DebuggerServiceServer.spec.luau src/ReplicatedStorage/Client/UI/React/Debugger/StatePanel.luau
git commit -m "feat(request-handler): token bucket, custom clock, decode once, counted rejects

maxRequests is now a bucket refilled at maxRequests/windowSeconds; existing callers keep their
configs. An optional clock drives the refill (validation runs first when it is set), a third validate
return reaches the handler, onReject = count replaces a warning per drop, and the handler goes to
xpcall without a closure. The Debugger shows tokens left and drops."
```

---
### Task 2: R1 carry fixes in the shared modules

**Runtime behaviour: no** (pure modules and the harness adapter).

Carries four of the R1 final-review items: `isNew` from what `push` actually did, epoch reset support for the slot table, what `starving` means (and docs that agree), and loss counting under true reorder.

**Files:**
- Modify: `src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterInterpolator.luau`
- Modify: `src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterInterpolator.spec.luau`
- Modify: `src/ReplicatedStorage/Shared/Modules/CharacterReplication/RenderClock.luau`
- Modify: `src/ReplicatedStorage/Shared/Modules/CharacterReplication/RenderClock.spec.luau`
- Modify: `src/ReplicatedStorage/Shared/Modules/CharacterReplication/Harness/HarnessVenture.luau:139-171`

**Interfaces:**
- Consumes: R1's `CharacterInterpolator` (`Buffer`, `Sample`, `Mode`, `Hint`, `evaluatePosition`, `evaluate`), `RenderClock` (`onBatch`, `advance`).
- Produces:
  - `export type PushResult = "newest" | "inserted" | "flushed" | "dropped"`
  - `CharacterInterpolator.push(b: Buffer, epoch: number, sample: Sample): PushResult` (was `boolean`)
  - `CharacterInterpolator.isNewSample(result: PushResult): boolean` — `newest` or `flushed`
  - `CharacterInterpolator.resetEpoch(b: Buffer, epoch: number)` — empties the buffer and sets `b.epoch = epoch % 8`
  - `CharacterInterpolator.isStarving(mode: Mode): boolean` — `hold` only
  - `CharacterInterpolator.evaluatePose(b: Buffer, timeMs: number, hint: Hint): (Vector3, number, Mode)` — position, yaw, mode, allocation-free
  - `RenderClock.Clock` gains `receivedMask: number`

- [ ] **Step 1: Write the failing specs**

In `CharacterInterpolator.spec.luau`, inside `describe("push", ...)`, replace the four epoch tests with:

```luau
		it("flushes on the next epoch and reports it", function()
			local b = walking(5, 3)
			expect(Interp.push(b, 4, sample(500, 90))).to.equal("flushed")
			expect(#b.samples).to.equal(1)
			expect(b.epoch).to.equal(4)
		end)

		it("treats 7 -> 0 as the next epoch", function()
			local b = walking(3, 7)
			expect(Interp.push(b, 0, sample(500, 90))).to.equal("flushed")
			expect(b.epoch).to.equal(0)
		end)

		it("drops a record from an older epoch after a flush", function()
			local b = walking(3, 3)
			Interp.push(b, 4, sample(500, 90))
			expect(Interp.push(b, 3, sample(510, 1))).to.equal("dropped")
			expect(#b.samples).to.equal(1)
			expect(b.samples[1].position.X).to.equal(90)
			expect(b.epoch).to.equal(4)
		end)

		it("accepts any epoch on an empty buffer", function()
			local b = Interp.newBuffer()
			expect(Interp.push(b, 6, sample(0, 0))).to.equal("flushed")
			expect(b.epoch).to.equal(6)
		end)

		it("reports newest, inserted and dropped", function()
			local b = Interp.newBuffer()
			expect(Interp.push(b, 0, sample(20, 1))).to.equal("flushed") -- the first sample sets the epoch
			expect(Interp.push(b, 0, sample(40, 2))).to.equal("newest")
			expect(Interp.push(b, 0, sample(30, 3))).to.equal("inserted")
			expect(Interp.push(b, 0, sample(30, 9))).to.equal("dropped")
		end)

		it("reports a sample older than a full buffer as dropped", function()
			local b = walking(Interp.MAX_SAMPLES)
			expect(Interp.push(b, 0, sample(-100, 0))).to.equal("dropped")
			expect(#b.samples).to.equal(Interp.MAX_SAMPLES)
			expect(b.samples[1].timeMs).to.equal(0)
		end)

		it("counts only newest and flushed as new samples", function()
			expect(Interp.isNewSample("newest")).to.equal(true)
			expect(Interp.isNewSample("flushed")).to.equal(true)
			expect(Interp.isNewSample("inserted")).to.equal(false)
			expect(Interp.isNewSample("dropped")).to.equal(false)
		end)
```

Append, as new top-level `describe` blocks inside the returned function:

```luau
	describe("resetEpoch", function()
		it("lets a buffer skip lost epochs when the slot table says so", function()
			local b = walking(3, 2)
			expect(Interp.push(b, 4, sample(500, 90))).to.equal("dropped") -- epoch 3's records were all lost
			Interp.resetEpoch(b, 12) -- the slot table's full 8-bit epoch; 12 % 8 == 4
			expect(#b.samples).to.equal(0)
			expect(b.epoch).to.equal(4)
			expect(Interp.push(b, 4, sample(500, 90))).to.equal("newest")
		end)
	end)

	describe("isStarving", function()
		it("is true only for hold — behind is a too-large delay, not late samples", function()
			expect(Interp.isStarving("hold")).to.equal(true)
			expect(Interp.isStarving("behind")).to.equal(false)
			expect(Interp.isStarving("extrapolate")).to.equal(false)
			expect(Interp.isStarving("interpolate")).to.equal(false)
			expect(Interp.isStarving("empty")).to.equal(false)
		end)
	end)

	describe("evaluatePose", function()
		it("matches evaluate's position and yaw while turning across ±π", function()
			local b = Interp.newBuffer()
			for i = 0, 20 do
				local t = i * 1000 / 60
				Interp.push(b, 0, sample(t, 16 * t / 1000, { yaw = 3.0 + i * 0.05 }))
			end
			local hint = Interp.newHint()
			for t = 0, 333, 7 do
				local position, yaw, mode = Interp.evaluatePose(b, t, hint)
				local e = Interp.evaluate(b, t)
				expect(mode).to.equal(e.mode)
				expect((position - e.position).Magnitude < 1e-3).to.equal(true)
				local delta = math.abs((yaw - e.yaw + math.pi) % (2 * math.pi) - math.pi)
				expect(delta < 1e-6).to.equal(true)
			end
		end)

		it("reports empty with zero yaw on an empty buffer", function()
			local _, yaw, mode = Interp.evaluatePose(Interp.newBuffer(), 10, Interp.newHint())
			expect(mode).to.equal("empty")
			expect(yaw).to.equal(0)
		end)
	end)
```

In `RenderClock.spec.luau`, inside `describe("loss", ...)`, append:

```luau
		it("takes back a loss when a reordered batch arrives late (5, 7, 6, 8)", function()
			local clock = RenderClock.new()
			local now = 0
			local seq = 0
			for _ = 1, 150 do
				for _, offset in { 1, 3, 2, 4 } do
					now += FRAME
					RenderClock.noteFrame(clock, now)
					RenderClock.onBatch(clock, now, (seq + offset) % 65536, 150, true)
					RenderClock.advance(clock, now, false, math.huge)
				end
				seq += 4
			end
			expect(clock.lossLevel).to.equal(0)
		end)

		it("still counts a batch that never arrives", function()
			local clock = RenderClock.new()
			local now = 0
			for seq = 1, 600 do
				if seq % 10 ~= 0 then -- 10 % loss
					now += FRAME
					RenderClock.noteFrame(clock, now)
					RenderClock.onBatch(clock, now, seq, 150, true)
					RenderClock.advance(clock, now, false, math.huge)
				end
			end
			expect(clock.lossLevel).to.equal(2)
		end)
```

- [ ] **Step 2: Run the tests and verify they fail**

Studio test run. Expected failures: the rewritten `push` cases (it returns booleans), `reports newest, inserted and dropped`, `reports a sample older than a full buffer as dropped`, `counts only newest and flushed as new samples`, `resetEpoch`, `isStarving`, `evaluatePose` (nil functions), and `takes back a loss when a reordered batch arrives late` (counts 25 % loss today → level 2).

- [ ] **Step 3: Implement the interpolator changes**

In `CharacterInterpolator.luau`, replace the `push` doc comment and function with:

```luau
--[=[
	What `push` did with a sample:
	  newest    appended as the buffer's newest sample;
	  inserted  accepted, but older than the newest (a reordered record or a resend of a missed one);
	  flushed   the next epoch (current + 1 mod 8) emptied the buffer and this is now its only sample;
	  dropped   a duplicate time, a straggler from any other epoch, or older than a full buffer holds.
	Only `newest` and `flushed` are NEW samples for the render clock's lateness (`isNewSample`).
]=]
export type PushResult = "newest" | "inserted" | "flushed" | "dropped"

--[=[
	Insert a sample in time order. The next epoch (current + 1 mod 8) flushes the buffer (teleport /
	respawn); a record from any other epoch is dropped — the reliable slot table resets a buffer that
	missed a bump (`resetEpoch`).
]=]
function CharacterInterpolator.push(b: Buffer, epoch: number, sample: Sample): PushResult
	local flushed = false
	if epoch ~= b.epoch then
		if b.epoch >= 0 and epoch ~= (b.epoch + 1) % 8 then
			return "dropped"
		end
		b.epoch = epoch
		table.clear(b.samples)
		flushed = true
	end
	local samples = b.samples
	local index = #samples + 1
	while index > 1 and samples[index - 1].timeMs >= sample.timeMs do
		if samples[index - 1].timeMs == sample.timeMs then
			return "dropped"
		end
		index -= 1
	end
	local newest = index == #samples + 1
	table.insert(samples, index, sample)
	local trimmed = 0
	while #samples > MAX_SAMPLES do
		table.remove(samples, 1)
		trimmed += 1
	end
	if flushed then
		return "flushed"
	end
	if index <= trimmed then
		return "dropped" -- older than everything a full buffer keeps: it was trimmed straight away
	end
	return if newest then "newest" else "inserted"
end

function CharacterInterpolator.isNewSample(result: PushResult): boolean
	return result == "newest" or result == "flushed"
end

--[=[
	Empty the buffer and adopt `epoch` (the slot table's full epoch; the wire carries its low 3 bits).
	Used when the reliable slot table announces an epoch the buffer would otherwise never accept (a lost
	bump), and when a body re-enters relevance (a fresh buffer, so it never slides from old samples).
]=]
function CharacterInterpolator.resetEpoch(b: Buffer, epoch: number)
	b.epoch = epoch % 8
	table.clear(b.samples)
end

--[=[
	Whether an evaluation means the samples are late: `hold` only. `behind` (render time older than the
	buffer) means the delay is too large — `RenderClock.advance`'s reach brings it forward — and must
	never raise the delay.
]=]
function CharacterInterpolator.isStarving(mode: Mode): boolean
	return mode == "hold"
end
```

After `evaluatePosition`, add:

```luau
--[=[
	`evaluatePosition` plus the yaw, for the per-frame puppet placement: allocation-free, same curve.
	Yaw is the shortest-arc blend across the bracket, or the edge sample's yaw outside it.
]=]
function CharacterInterpolator.evaluatePose(b: Buffer, timeMs: number, hint: Hint): (Vector3, number, Mode)
	-- Annotated: Luau widens the singleton-union return to `string` on an unannotated local.
	local position: Vector3, mode: Mode = CharacterInterpolator.evaluatePosition(b, timeMs, hint)
	local samples = b.samples
	local count = #samples
	if count == 0 then
		return position, 0, mode
	end
	if mode ~= "interpolate" then
		local edge = if mode == "behind" then samples[1] else samples[count]
		return position, edge.yaw, mode
	end
	local a, c = samples[hint.index], samples[hint.index + 1]
	local spanMs = c.timeMs - a.timeMs
	local s = if spanMs > 0 then (timeMs - a.timeMs) / spanMs else 1
	return position, lerpAngle(a.yaw, c.yaw, s), mode
end
```

(`lerpAngle` is the module-local defined above `hermite`; `evaluatePosition` leaves `hint.index` on the bracket in interpolate mode.)

- [ ] **Step 4: Implement the render clock changes**

In `RenderClock.luau`:

Add `receivedMask: number,` to `export type Clock` (after `lastSeq: number?,`) and `receivedMask = 0,` to `RenderClock.new` (after `lastSeq = nil,`).

Replace the `onBatch` doc comment and its seq-handling block (from `local lastSeq = clock.lastSeq` through the end of that `if ... end`) with:

```luau
--[=[
	Per received batch. `latenessMs` is arrival time minus a new sample's time — with several bodies in one
	batch, the LARGEST among the batch's new samples. `isNewSample` is whether any record in the batch was
	new to its buffer (`CharacterInterpolator.isNewSample` of what `push` returned); false for a batch of
	resends or repairs whose samples the buffers already hold, which must not vote on lateness.

	Loss: each forward seq step is recorded; `receivedMask` remembers which of the last 32 seqs arrived, so a
	reordered batch that fills a gap records a zero step (one more arrival, nothing more expected) and takes
	that loss back. A duplicate changes nothing.
]=]
function RenderClock.onBatch(clock: Clock, nowMs: number, seq: number, latenessMs: number, isNewSample: boolean)
	local cfg = clock.config
	local lastSeq = clock.lastSeq
	if lastSeq == nil then
		clock.lastSeq = seq
		clock.receivedMask = 1
	else
		local step = (seq - lastSeq) % 65536
		if step > 0 and step < 1000 then
			clock.lossIndex = clock.lossIndex % cfg.lossWindow + 1
			clock.lossSteps[clock.lossIndex] = step
			clock.lastSeq = seq
			clock.receivedMask = if step >= 32 then 1 else bit32.bor(bit32.lshift(clock.receivedMask, step), 1)
		elseif step >= 1000 and step < 32768 then
			clock.lastSeq = seq
			clock.receivedMask = 1
		elseif step ~= 0 then
			local behind = 65536 - step
			if behind < 32 and not bit32.btest(clock.receivedMask, bit32.lshift(1, behind)) then
				clock.receivedMask = bit32.bor(clock.receivedMask, bit32.lshift(1, behind))
				clock.lossIndex = clock.lossIndex % cfg.lossWindow + 1
				clock.lossSteps[clock.lossIndex] = 0
			end
		end
	end
```

(The rest of `onBatch` — the `isNewSample`, stall and lateness lines — is unchanged.)

In `retarget`, replace `local lossRate = if expected > 0 then 1 - #clock.lossSteps / expected else 0` with:

```luau
	local lossRate = if expected > 0 then math.max(0, 1 - #clock.lossSteps / expected) else 0
```

Replace the `advance` doc comment with:

```luau
--[=[
	Once per rendered frame. `starving` is whether last frame's evaluation was in `hold` — samples genuinely
	late (`CharacterInterpolator.isStarving`). `behind` is NOT starving: render time older than the buffer
	means the delay is too large, and `reachMs` (the smallest `CharacterInterpolator.reachMs` across visible
	bodies) brings it forward. Returns the delay.
]=]
```

- [ ] **Step 5: Update the harness adapter**

In `Harness/HarnessVenture.luau`, replace `viewerReceive` with:

```luau
		viewerReceive = function(nowMs, payload)
			local header = Codec.readHeader(payload, 1)
			local record = Codec.readRecord(payload, 1 + Codec.HEADER_BYTES)
			local sampleTime = header.batchTimeMs - record.ageMs
			local result: Interp.PushResult = Interp.push(samples, record.epoch, {
				timeMs = sampleTime,
				position = record.position,
				velocity = record.velocity,
				yaw = record.yaw,
				state = record.state,
				grounded = record.grounded,
				rotation = nil,
			})
			RenderClock.onBatch(clock, nowMs, header.seq, nowMs - sampleTime, Interp.isNewSample(result))
		end,
```

and in `viewerRender` replace `starving = e.mode == "hold" or e.mode == "behind"` with:

```luau
			starving = Interp.isStarving(e.mode)
```

- [ ] **Step 6: Run the tests and verify they pass**

Studio test run: every `CharacterInterpolator`, `RenderClock` and `HarnessVenture` case passes (the acceptance thresholds are unchanged; if one fails, read the run's numbers before touching anything — thresholds move only with the developer's agreement). Format, Lint, Typecheck clean.

- [ ] **Step 7: Commit**

```bash
git add src/ReplicatedStorage/Shared/Modules/CharacterReplication
git commit -m "fix(replication): push reports what it did, slot-table epoch reset, starving is hold only, reorder-safe loss

push returns newest / inserted / flushed / dropped and isNewSample derives the lateness vote from it;
resetEpoch lets the reliable slot table recover a buffer that missed a bump; behind no longer counts as
starving; a reordered batch that fills a gap takes its loss back. evaluatePose adds yaw to the fast path."
```

---
### Task 3: Wire codecs — uplink packet and downlink batch validation

**Runtime behaviour: no** (pure shared modules).

Carries the R1 review's decode-side checks: exact size before decoding, batch `count` against the buffer length, action index against the registry, ragdoll (state 29) rejected on the uplink — and the owner-time alias, which the u32 send time removes by construction.

**Files:**
- Create: `src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterUplinkCodec.spec.luau`
- Create: `src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterUplinkCodec.luau`
- Create: `src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterBatchCodec.spec.luau`
- Create: `src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterBatchCodec.luau`

**Interfaces:**
- Consumes: `CharacterRecordCodec` (`Record`, `RECORD_BYTES` 16, `HEADER_BYTES` 7, `ACTION_BYTES` 2, `STATE_RAGDOLL` 29, `writeRecord`, `readRecord`).
- Produces:
  - `CharacterUplinkCodec.HEADER_BYTES` (5), `MAX_RECORDS` (3), `MAX_AGE_MS` (1023)
  - `export type UplinkSample = { record: CharacterRecordCodec.Record, sampleMs: number }`
  - `export type Uplink = { sentMs: number, samples: { UplinkSample } }` — newest first
  - `CharacterUplinkCodec.size(count: number): number`
  - `CharacterUplinkCodec.encode(sentMs: number, samples: { UplinkSample }): buffer` — writes each record's `ageMs`
  - `CharacterUplinkCodec.decode(b: buffer): (boolean, string?, Uplink?)` — reasons `"size"`, `"action"`, `"ragdoll"`, `"order"`
  - `CharacterBatchCodec.hasActionAt(b: buffer, offset: number): boolean`
  - `CharacterBatchCodec.validate(b: buffer, actionCount: number): (boolean, string?)` — reasons `"short"`, `"empty"`, `"truncated"`, `"action"`, `"trailing"`

- [ ] **Step 1: Write the failing specs**

`CharacterUplinkCodec.spec.luau`:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Replication = ReplicatedStorage.Shared.Modules.CharacterReplication
local Codec = require(Replication.CharacterRecordCodec)
local Uplink = require(Replication.CharacterUplinkCodec)

local function record(overrides)
	local r = {
		slot = 0,
		generation = 0,
		epoch = 1,
		ageMs = 0,
		position = Vector3.new(-1200, 40, -350),
		yaw = 0.5,
		pitch = 0,
		velocity = Vector3.new(16, 0, 0),
		state = 8,
		grounded = true,
		hasAction = false,
		rotation = nil,
	}
	for key, value in overrides or {} do
		r[key] = value
	end
	return r
end

local function sample(sampleMs, overrides)
	return { record = record(overrides), sampleMs = sampleMs }
end

return function()
	describe("encode", function()
		it("writes the send time, the count and newest-first records aged from the send time", function()
			local b = Uplink.encode(5000, { sample(5000), sample(4983), sample(4966) })
			expect(Uplink.size(3)).to.equal(5 + 48)
			expect(buffer.len(b)).to.equal(Uplink.size(3))
			expect(buffer.readu32(b, 0)).to.equal(5000)
			expect(buffer.readu8(b, 4)).to.equal(3)
			expect(Codec.readRecord(b, 5).ageMs).to.equal(0)
			expect(Codec.readRecord(b, 21).ageMs).to.equal(17)
			expect(Codec.readRecord(b, 37).ageMs).to.equal(34)
		end)

		it("leaves out previous samples older than 1023 ms", function()
			local b = Uplink.encode(5000, { sample(5000), sample(4000), sample(3000) })
			expect(buffer.readu8(b, 4)).to.equal(2)
			expect(buffer.len(b)).to.equal(Uplink.size(2))
		end)

		it("writes at most three records", function()
			local b = Uplink.encode(100, { sample(100), sample(84), sample(68), sample(52) })
			expect(buffer.readu8(b, 4)).to.equal(3)
		end)
	end)

	describe("decode", function()
		it("round-trips the send time, sample times and records", function()
			local b = Uplink.encode(5000, {
				sample(5000, { position = Vector3.new(-1200, 40, -350) }),
				sample(4983, { position = Vector3.new(-1201, 40, -350) }),
			})
			local ok, reason, uplink = Uplink.decode(b)
			expect(ok).to.equal(true)
			expect(reason).to.equal(nil)
			expect(uplink.sentMs).to.equal(5000)
			expect(#uplink.samples).to.equal(2)
			expect(uplink.samples[1].sampleMs).to.equal(5000)
			expect(uplink.samples[2].sampleMs).to.equal(4983)
			expect(uplink.samples[2].record.position.X).to.be.near(-1201, 0.02)
		end)

		it("rejects empty, short and oversized packets before decoding", function()
			for _, length in { 0, 4, 5, 20, 22, 70 } do
				local ok, reason = Uplink.decode(buffer.create(length))
				expect(ok).to.equal(false)
				expect(reason).to.equal("size")
			end
		end)

		it("rejects a packet whose length does not match its count", function()
			local b = Uplink.encode(5000, { sample(5000), sample(4983) })
			buffer.writeu8(b, 4, 3)
			local ok, reason = Uplink.decode(b)
			expect(ok).to.equal(false)
			expect(reason).to.equal("size")
		end)

		it("rejects a count of zero", function()
			local b = Uplink.encode(5000, { sample(5000) })
			buffer.writeu8(b, 4, 0)
			local ok, reason = Uplink.decode(b)
			expect(ok).to.equal(false)
			expect(reason).to.equal("size")
		end)

		it("rejects the ragdoll state (ragdoll is server-granted)", function()
			local b = Uplink.encode(5000, { sample(5000, { state = Codec.STATE_RAGDOLL }) })
			local ok, reason = Uplink.decode(b)
			expect(ok).to.equal(false)
			expect(reason).to.equal("ragdoll")
		end)

		it("rejects an owner-claimed action extension bit", function()
			local b = Uplink.encode(5000, { sample(5000, { hasAction = true }) })
			local ok, reason = Uplink.decode(b)
			expect(ok).to.equal(false)
			expect(reason).to.equal("action")
		end)

		it("rejects samples that are not strictly newest first", function()
			local b = Uplink.encode(5000, { sample(5000), sample(4983) })
			local second = Codec.readRecord(b, 21)
			second.ageMs = 0
			Codec.writeRecord(b, 21, second)
			local ok, reason = Uplink.decode(b)
			expect(ok).to.equal(false)
			expect(reason).to.equal("order")
		end)

		it("never reads an old sample as a future one (no 10-bit owner-time alias)", function()
			-- A previous sample 1000 ms old: the 10-bit unwrap would have read it as 24 ms in the future.
			local b = Uplink.encode(10000, { sample(10000), sample(9000) })
			local ok, _, uplink = Uplink.decode(b)
			expect(ok).to.equal(true)
			expect(uplink.samples[2].sampleMs).to.equal(9000)
		end)
	end)
end
```

`CharacterBatchCodec.spec.luau`:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Replication = ReplicatedStorage.Shared.Modules.CharacterReplication
local Codec = require(Replication.CharacterRecordCodec)
local Batch = require(Replication.CharacterBatchCodec)

local function record(overrides)
	local r = {
		slot = 3,
		generation = 1,
		epoch = 2,
		ageMs = 10,
		position = Vector3.new(-1200, 40, -350),
		yaw = 0,
		pitch = 0,
		velocity = Vector3.zero,
		state = 8,
		grounded = true,
		hasAction = false,
		rotation = nil,
	}
	for key, value in overrides or {} do
		r[key] = value
	end
	return r
end

-- `records`: a list of record overrides; `actions[i]`: the action written after record i when it has one.
local function batch(records, actions, extraBytes)
	local total = Codec.HEADER_BYTES + (extraBytes or 0)
	for _, overrides in records do
		total += if overrides.hasAction then Codec.RECORD_BYTES + Codec.ACTION_BYTES else Codec.RECORD_BYTES
	end
	local b = buffer.create(total)
	Codec.writeHeader(b, 0, { seq = 1, batchTimeMs = 1000, count = #records })
	local offset = Codec.HEADER_BYTES
	for i, overrides in records do
		local r = record(overrides)
		Codec.writeRecord(b, offset, r)
		offset += Codec.RECORD_BYTES
		if r.hasAction then
			Codec.writeAction(b, offset, (actions or {})[i] or { index = 0, variant = 0, elapsedMs = 0 })
			offset += Codec.ACTION_BYTES
		end
	end
	return b
end

return function()
	describe("validate", function()
		it("accepts a well-formed batch of plain records", function()
			expect(Batch.validate(batch({ {}, { slot = 4 }, { slot = 5 } }), 0)).to.equal(true)
		end)

		it("accepts a record carrying an action whose index is in the registry", function()
			local b = batch({ {}, { hasAction = true } }, { [2] = { index = 4, variant = 0, elapsedMs = 64 } })
			expect(Batch.validate(b, 5)).to.equal(true)
		end)

		it("rejects an action index beyond the registry", function()
			local b = batch({ { hasAction = true } }, { { index = 5, variant = 0, elapsedMs = 0 } })
			local ok, reason = Batch.validate(b, 5)
			expect(ok).to.equal(false)
			expect(reason).to.equal("action")
		end)

		it("rejects a count larger than the records present", function()
			local b = batch({ {}, {} })
			buffer.writeu8(b, 6, 3)
			local ok, reason = Batch.validate(b, 0)
			expect(ok).to.equal(false)
			expect(reason).to.equal("truncated")
		end)

		it("rejects trailing bytes after the last record", function()
			local ok, reason = Batch.validate(batch({ {} }, nil, 3), 0)
			expect(ok).to.equal(false)
			expect(reason).to.equal("trailing")
		end)

		it("rejects a batch shorter than its header, and an empty batch", function()
			local ok, reason = Batch.validate(buffer.create(6), 0)
			expect(ok).to.equal(false)
			expect(reason).to.equal("short")
			ok, reason = Batch.validate(batch({}), 0)
			expect(ok).to.equal(false)
			expect(reason).to.equal("empty")
		end)
	end)

	describe("hasActionAt", function()
		it("reads the action bit without decoding the record", function()
			local b = batch({ {}, { hasAction = true } })
			expect(Batch.hasActionAt(b, Codec.HEADER_BYTES)).to.equal(false)
			expect(Batch.hasActionAt(b, Codec.HEADER_BYTES + Codec.RECORD_BYTES)).to.equal(true)
		end)
	end)
end
```

- [ ] **Step 2: Run the tests and verify they fail**

Studio test run. Expected: both new spec files fail at `require` (modules missing).

- [ ] **Step 3: Write `CharacterUplinkCodec.luau`**

```luau
--!strict
--[=[
	The owner → server uplink packet (spec 2026-09-22 §6.3; Verdict: "uplink goes through an extended
	RequestHandler.wrap"; plan R2 Task 3).

	  u32 sentMs | u8 count | count × 16 B record      count 1–3, newest first

	`sentMs` is the owner's send time in session milliseconds (`GetServerTimeNow` minus the session epoch
	from the slot table). Each record's 10-bit `ageMs` is `sentMs − sample time`, so a sample's time is
	`sentMs − ageMs` — no 10-bit wrap, so an old sample can never alias into the future (the R1 review's
	alias item). The current sample comes first, then up to two previously SENT samples (redundancy: the
	packet survives two consecutive losses). A previous sample older than 1023 ms is left out.

	Decode-side checks (R1 review): the exact size is checked before anything is decoded; an owner may not
	set the action bit (actions are server-granted) or claim the ragdoll state (server-granted); ages must
	strictly increase (one sample time each). The server's send-time clock (`UplinkIngest.clockSeconds`)
	reads `sentMs` only after this passes.

	Pure.

	@class CharacterUplinkCodec
]=]

local CharacterRecordCodec = require(script.Parent.CharacterRecordCodec)

local CharacterUplinkCodec = {}

local HEADER_BYTES = 5
local MAX_RECORDS = 3
local MAX_AGE_MS = 1023
local RECORD_BYTES = CharacterRecordCodec.RECORD_BYTES

CharacterUplinkCodec.HEADER_BYTES = HEADER_BYTES
CharacterUplinkCodec.MAX_RECORDS = MAX_RECORDS
CharacterUplinkCodec.MAX_AGE_MS = MAX_AGE_MS

export type UplinkSample = {
	record: CharacterRecordCodec.Record,
	sampleMs: number,
}

export type Uplink = {
	sentMs: number,
	samples: { UplinkSample }, -- newest first
}

function CharacterUplinkCodec.size(count: number): number
	return HEADER_BYTES + count * RECORD_BYTES
end

--[=[
	Encode `samples` (newest first; at least one). Writes each record's `ageMs` (the records belong to the
	sender). Stops at the first previous sample older than 1023 ms; the newest is always written.
]=]
function CharacterUplinkCodec.encode(sentMs: number, samples: { UplinkSample }): buffer
	assert(#samples >= 1, "an uplink packet carries at least one sample")
	local count = 1
	for i = 2, math.min(#samples, MAX_RECORDS) do
		if sentMs - samples[i].sampleMs > MAX_AGE_MS then
			break
		end
		count = i
	end
	local b = buffer.create(CharacterUplinkCodec.size(count))
	buffer.writeu32(b, 0, sentMs % 4294967296)
	buffer.writeu8(b, 4, count)
	for i = 1, count do
		local sample = samples[i]
		sample.record.ageMs = math.clamp(sentMs - sample.sampleMs, 0, MAX_AGE_MS)
		CharacterRecordCodec.writeRecord(b, HEADER_BYTES + (i - 1) * RECORD_BYTES, sample.record)
	end
	return b
end

--[=[
	Validate and decode. Returns ok, a reason on failure, and the decoded packet on success — the shape
	`RequestHandler.wrap`'s `validate` expects, so the packet is decoded once.
]=]
function CharacterUplinkCodec.decode(b: buffer): (boolean, string?, Uplink?)
	local length = buffer.len(b)
	if length < CharacterUplinkCodec.size(1) or length > CharacterUplinkCodec.size(MAX_RECORDS) then
		return false, "size", nil
	end
	local count = buffer.readu8(b, 4)
	if count < 1 or count > MAX_RECORDS or length ~= CharacterUplinkCodec.size(count) then
		return false, "size", nil
	end
	local sentMs = buffer.readu32(b, 0)
	local samples: { UplinkSample } = table.create(count)
	local previousAge = -1
	for i = 1, count do
		local record = CharacterRecordCodec.readRecord(b, HEADER_BYTES + (i - 1) * RECORD_BYTES)
		if record.hasAction then
			return false, "action", nil
		end
		if record.state == CharacterRecordCodec.STATE_RAGDOLL then
			return false, "ragdoll", nil
		end
		if record.ageMs <= previousAge then
			return false, "order", nil
		end
		previousAge = record.ageMs
		samples[i] = { record = record, sampleMs = sentMs - record.ageMs }
	end
	return true, nil, { sentMs = sentMs, samples = samples }
end

return CharacterUplinkCodec
```

- [ ] **Step 4: Write `CharacterBatchCodec.luau`**

```luau
--!strict
--[=[
	Downlink batch validation (spec §6.2 batch header; R1 review: decode-side checks; plan R2 Task 3).

	A batch is the 7 B header (`u16 seq · u32 batchTimeMs · u8 count`) and `count` records back to back,
	each 16 B, or 18 B when its `hasAction` bit carries the 2 B action extension. `validate` walks the
	records by their action bit alone (no decoding) and proves, before a viewer decodes anything, that
	`count` records fit exactly, nothing trails them, and every action index is inside the registry
	(`actionCount` = `#AnimationRegistry.ids()`; indices are 0-based positions in that list).

	Pure.

	@class CharacterBatchCodec
]=]

local CharacterRecordCodec = require(script.Parent.CharacterRecordCodec)

local CharacterBatchCodec = {}

local HEADER_BYTES = CharacterRecordCodec.HEADER_BYTES
local RECORD_BYTES = CharacterRecordCodec.RECORD_BYTES
local ACTION_BYTES = CharacterRecordCodec.ACTION_BYTES

-- `hasAction` is the record's last bit (bit 127): the top bit of its 16th byte (little-endian words).
function CharacterBatchCodec.hasActionAt(b: buffer, offset: number): boolean
	return bit32.btest(buffer.readu8(b, offset + RECORD_BYTES - 1), 0x80)
end

function CharacterBatchCodec.validate(b: buffer, actionCount: number): (boolean, string?)
	local length = buffer.len(b)
	if length < HEADER_BYTES then
		return false, "short"
	end
	local count = buffer.readu8(b, 6)
	if count == 0 then
		return false, "empty"
	end
	local offset = HEADER_BYTES
	for _ = 1, count do
		if offset + RECORD_BYTES > length then
			return false, "truncated"
		end
		if CharacterBatchCodec.hasActionAt(b, offset) then
			if offset + RECORD_BYTES + ACTION_BYTES > length then
				return false, "truncated"
			end
			local index = bit32.band(buffer.readu16(b, offset + RECORD_BYTES), 127)
			if index >= actionCount then
				return false, "action"
			end
			offset += RECORD_BYTES + ACTION_BYTES
		else
			offset += RECORD_BYTES
		end
	end
	if offset ~= length then
		return false, "trailing"
	end
	return true, nil
end

return CharacterBatchCodec
```

- [ ] **Step 5: Run the tests and verify they pass**

Studio test run: both new spec files pass; suite green. Format, Lint, Typecheck clean.

- [ ] **Step 6: Commit**

```bash
git add src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterUplinkCodec.luau src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterUplinkCodec.spec.luau src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterBatchCodec.luau src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterBatchCodec.spec.luau
git commit -m "feat(replication): uplink packet codec and downlink batch validation

The uplink carries a full u32 send time and up to three newest-first records aged from it, so old
samples cannot alias forward. Both sides check sizes before decoding; owners cannot claim actions or
the ragdoll state; batches must hold exactly count records with in-registry action indices."
```

---
### Task 4: Server ingest core and the uplink pipeline

**Runtime behaviour: no** (pure server modules, not wired yet).

`UplinkIngest` decides which uplink samples enter the body: epoch, time bounds, spacing, dedupe with mismatch detection. `UplinkPipeline` is the uplink handler built on the extended `RequestHandler.wrap` — validate/decode once, timestamp-paced bucket (10, refill 60/s on the send-time clock), counted rejects — shared by the service and the load measurement.

**Files:**
- Create: `src/ServerScriptService/Services/CharacterReplicationService/UplinkIngest.spec.luau`
- Create: `src/ServerScriptService/Services/CharacterReplicationService/UplinkIngest.luau`
- Create: `src/ServerScriptService/Services/CharacterReplicationService/UplinkPipeline.spec.luau`
- Create: `src/ServerScriptService/Services/CharacterReplicationService/UplinkPipeline.luau`

**Interfaces:**
- Consumes: `CharacterRecordCodec` (`Record`, `RECORD_BYTES`, `OWNER_AHEAD_MS` 64), `CharacterUplinkCodec` (`Uplink`, `HEADER_BYTES`, `decode`), `RequestHandler.wrap` (Task 1).
- Produces:
  - `UplinkIngest.RING` (4), `MAX_AGE_MS` (1000), `MIN_SPACING_MS` (15), `AHEAD_MS` (64)
  - `export type Counters = { accepted: number, duplicate: number, mismatched: number, stale: number, ahead: number, tooFast: number, wrongEpoch: number }`
  - `export type State = { epoch: number, newestMs: number, ringTimes: { number }, ringWords: { number }, ringNext: number, latest: CharacterRecordCodec.Record?, latestMs: number, fresh: boolean, counters: Counters }`
  - `UplinkIngest.new(): State`, `UplinkIngest.reset(state: State, epoch: number)`
  - `UplinkIngest.ingest(state: State, packet: buffer, uplink: CharacterUplinkCodec.Uplink, serverNowMs: number): number` — samples accepted
  - `UplinkIngest.clockSeconds(sentMs: number, serverNowMs: number): number`
  - `UplinkPipeline.ACTION` (`"CharacterUplink"`), `BUCKET` (10), `REFILL_PER_SECOND` (60)
  - `UplinkPipeline.wrap(resolve: (player: Player) -> UplinkIngest.State?, nowMs: () -> number, onAccepted: (player: Player, state: UplinkIngest.State) -> ()): (data: buffer, player: Player) -> any`

- [ ] **Step 1: Write the failing specs**

`UplinkIngest.spec.luau`:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Uplink = require(ReplicatedStorage.Shared.Modules.CharacterReplication.CharacterUplinkCodec)
local UplinkIngest = require(ServerScriptService.Services.CharacterReplicationService.UplinkIngest)

local function sample(sampleMs, x, overrides)
	local r = {
		slot = 0,
		generation = 0,
		epoch = 1,
		ageMs = 0,
		position = Vector3.new(-1200 + x, 40, -350),
		yaw = 0,
		pitch = 0,
		velocity = Vector3.new(16, 0, 0),
		state = 8,
		grounded = true,
		hasAction = false,
		rotation = nil,
	}
	for key, value in overrides or {} do
		r[key] = value
	end
	return { record = r, sampleMs = sampleMs }
end

-- Encode then decode, exactly as the wire does, and ingest at `nowMs` (default: 30 ms after sending).
local function ingest(state, sentMs, samples, nowMs)
	local b = Uplink.encode(sentMs, samples)
	local ok, reason, uplink = Uplink.decode(b)
	assert(ok, reason)
	return UplinkIngest.ingest(state, b, uplink, nowMs or sentMs + 30)
end

local function fresh(epoch)
	local state = UplinkIngest.new()
	UplinkIngest.reset(state, epoch or 1)
	return state
end

return function()
	it("accepts a new sample and marks the body fresh", function()
		local state = fresh()
		expect(ingest(state, 1000, { sample(1000, 0) })).to.equal(1)
		expect(state.fresh).to.equal(true)
		expect(state.latestMs).to.equal(1000)
		expect(state.latest.position.X).to.be.near(-1200, 0.02)
	end)

	it("takes redundant samples oldest first and counts the repeats as duplicates", function()
		local state = fresh()
		local s1, s2, s3 = sample(1000, 0), sample(1017, 0.3), sample(1034, 0.6)
		ingest(state, 1017, { s2, s1 })
		expect(ingest(state, 1034, { s3, s2, s1 })).to.equal(1)
		expect(state.counters.accepted).to.equal(3)
		expect(state.counters.duplicate).to.equal(2)
		expect(state.latestMs).to.equal(1034)
	end)

	it("counts a sample whose content changed as a mismatched duplicate and keeps the first version", function()
		local state = fresh()
		ingest(state, 1000, { sample(1000, 0) })
		ingest(state, 1017, { sample(1017, 0.3), sample(1000, 5) }) -- "the 1000 ms sample", now 5 studs away
		expect(state.counters.mismatched).to.equal(1)
		expect(state.counters.accepted).to.equal(2)
	end)

	it("drops samples from another body epoch", function()
		local state = fresh(2)
		expect(ingest(state, 1000, { sample(1000, 0, { epoch = 1 }) })).to.equal(0)
		expect(state.counters.wrongEpoch).to.equal(1)
	end)

	it("matches the epoch on its low three bits", function()
		local state = fresh(9) -- 9 % 8 == 1
		expect(ingest(state, 1000, { sample(1000, 0, { epoch = 1 }) })).to.equal(1)
	end)

	it("drops a sample more than 64 ms ahead of server time", function()
		local state = fresh()
		expect(ingest(state, 1100, { sample(1100, 0) }, 1000)).to.equal(0)
		expect(state.counters.ahead).to.equal(1)
		expect(ingest(state, 1060, { sample(1060, 0) }, 1000)).to.equal(1)
	end)

	it("accepts a backlog sample up to 1000 ms old and drops older ones as stale", function()
		local state = fresh()
		expect(ingest(state, 4000, { sample(4000, 0) }, 4900)).to.equal(1)
		expect(ingest(state, 4100, { sample(4100, 0) }, 5200)).to.equal(0) -- 1100 ms old
		expect(state.counters.stale).to.equal(1)
	end)

	it("never reads an old sample as a future one", function()
		local state = fresh()
		-- Taken at 9000, carried in a packet sent at 10000 that arrives at 10020: stale, never "ahead".
		expect(ingest(state, 10000, { sample(10000, 1), sample(9000, 0) }, 10020)).to.equal(1)
		expect(state.counters.ahead).to.equal(0)
		expect(state.counters.stale).to.equal(1)
		expect(state.latestMs).to.equal(10000)
	end)

	it("drops a sample closer than 15 ms to the newest", function()
		local state = fresh()
		ingest(state, 1000, { sample(1000, 0) })
		expect(ingest(state, 1010, { sample(1010, 0.2) })).to.equal(0)
		expect(state.counters.tooFast).to.equal(1)
	end)

	it("counts an older sample outside the duplicate window as stale", function()
		local state = fresh()
		for i = 0, 5 do
			ingest(state, 1000 + i * 17, { sample(1000 + i * 17, i * 0.3) })
		end
		-- The 1000 ms sample has left the last-4 window.
		expect(ingest(state, 1200, { sample(1200, 3), sample(1000, 0) })).to.equal(1)
		expect(state.counters.stale).to.equal(1)
	end)

	it("reset starts a new body: new epoch, empty window, counters kept", function()
		local state = fresh(1)
		ingest(state, 1000, { sample(1000, 0) })
		UplinkIngest.reset(state, 2)
		expect(state.latest).to.equal(nil)
		expect(state.fresh).to.equal(false)
		expect(state.counters.accepted).to.equal(1)
		expect(ingest(state, 990, { sample(990, 0, { epoch = 2 }) }, 1020)).to.equal(1)
	end)

	it("clockSeconds is the send time, clamped to server time + 64 ms", function()
		expect(UplinkIngest.clockSeconds(5000, 6000)).to.be.near(5, 1e-9)
		expect(UplinkIngest.clockSeconds(9000, 6000)).to.be.near(6.064, 1e-9)
	end)
end
```

`UplinkPipeline.spec.luau`:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local Codec = require(ReplicatedStorage.Shared.Modules.CharacterReplication.CharacterRecordCodec)
local Uplink = require(ReplicatedStorage.Shared.Modules.CharacterReplication.CharacterUplinkCodec)
local RequestHandler = require(ServerScriptService.Modules.RequestHandler)
local Folder = ServerScriptService.Services.CharacterReplicationService
local UplinkIngest = require(Folder.UplinkIngest)
local UplinkPipeline = require(Folder.UplinkPipeline)

local USER = -88001

local function packet(sentMs, overrides)
	local r = {
		slot = 0,
		generation = 0,
		epoch = 1,
		ageMs = 0,
		position = Vector3.new(-1200 + sentMs / 1000, 40, -350),
		yaw = 0,
		pitch = 0,
		velocity = Vector3.new(16, 0, 0),
		state = 8,
		grounded = true,
		hasAction = false,
		rotation = nil,
	}
	for key, value in overrides or {} do
		r[key] = value
	end
	return Uplink.encode(sentMs, { { record = r, sampleMs = sentMs } })
end

local function fixture(nowMs)
	local state = UplinkIngest.new()
	UplinkIngest.reset(state, 1)
	local f = { state = state, accepted = 0, nowMs = nowMs, player = { UserId = USER } }
	f.handler = UplinkPipeline.wrap(function(player)
		return if player.UserId == USER then state else nil
	end, function()
		return f.nowMs
	end, function()
		f.accepted += 1
	end)
	return f
end

local function rejected()
	return RequestHandler.getRateLimitStatus(USER, UplinkPipeline.ACTION).rejected
end

return function()
	afterEach(function()
		RequestHandler.resetRateLimit(USER)
	end)

	it("feeds a valid packet to ingest and reports the accept", function()
		local f = fixture(1030)
		f.handler(packet(1000), f.player)
		expect(f.accepted).to.equal(1)
		expect(f.state.latestMs).to.equal(1000)
	end)

	it("counts a malformed packet without a warning and never reaches ingest", function()
		local f = fixture(1030)
		local warnings = 0
		local unsubscribe = Logger.subscribe(function(entry)
			if entry.level == "WARN" then
				warnings += 1
			end
		end)
		f.handler(buffer.create(7), f.player)
		unsubscribe()
		expect(warnings).to.equal(0)
		expect(rejected()).to.equal(1)
		expect(f.state.counters.accepted).to.equal(0)
	end)

	it("rejects a ragdoll claim at validation", function()
		local f = fixture(1030)
		f.handler(packet(1000, { state = Codec.STATE_RAGDOLL }), f.player)
		expect(rejected()).to.equal(1)
		expect(f.accepted).to.equal(0)
	end)

	it("lets a backlog through: 30 packets sent 17 ms apart arrive at once", function()
		local f = fixture(1600)
		for i = 0, 29 do
			f.handler(packet(1100 + i * 17), f.player)
		end
		expect(rejected()).to.equal(0)
		expect(f.state.counters.accepted).to.equal(30)
	end)

	it("caps a flood: 30 packets with one send time pass the bucket at most", function()
		local f = fixture(1600)
		for _ = 1, 30 do
			f.handler(packet(1500), f.player)
		end
		expect(rejected()).to.equal(30 - UplinkPipeline.BUCKET)
		expect(f.state.counters.accepted).to.equal(1)
		expect(f.state.counters.duplicate).to.equal(UplinkPipeline.BUCKET - 1)
	end)

	it("refills nothing when the send time steps backwards", function()
		local f = fixture(1600)
		for _ = 1, UplinkPipeline.BUCKET do
			f.handler(packet(1500), f.player)
		end
		f.handler(packet(1000), f.player)
		expect(rejected()).to.equal(1)
	end)
end
```

- [ ] **Step 2: Run the tests and verify they fail**

Studio test run. Expected: both new spec files fail at `require`.

- [ ] **Step 3: Write `UplinkIngest.luau`**

```luau
--!strict
--[=[
	UplinkIngest: which owner samples enter a body (spec §6.3, Verdict "R2 must carry"; plan R2 Task 4).

	Per sample, oldest first (a packet carries the current sample and up to two previous ones):
	  wrongEpoch  its epoch (low 3 bits) is not the body's current epoch — a sample from the previous body
	  ahead       more than 64 ms after server time (owner clocks are synced by GetServerTimeNow)
	  stale       more than 1000 ms old, or older than the newest accepted and outside the dedupe window
	  duplicate   a time already accepted, same content (redundancy: expected, harmless)
	  mismatched  a time already accepted, DIFFERENT content: the first accepted version is final; this is
	              counted for the anti-cheat phase to judge
	  tooFast     under 15 ms after the newest accepted sample (the owner samples at most 60 Hz)
	  accepted    newer than everything accepted: it becomes the body's latest sample

	There is no uplink sequence number: a sample's time (`sentMs − ageMs`) is its identity, and dedupe
	compares the last 4 accepted samples' bytes with the 10-bit age masked out (the age differs per packet).
	The 1000 ms bound accepts the backlog an owner releases after a stall (Verdict) while keeping samples a
	1 s history could hold; the stricter §6.3 window and drift-slope check belong to the anti-cheat phase.

	Pure.

	@class UplinkIngest
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Replication = ReplicatedStorage.Shared.Modules.CharacterReplication
local CharacterRecordCodec = require(Replication.CharacterRecordCodec)
local CharacterUplinkCodec = require(Replication.CharacterUplinkCodec)

local UplinkIngest = {}

local RING = 4
local MAX_AGE_MS = 1000
local MIN_SPACING_MS = 15
local AHEAD_MS = CharacterRecordCodec.OWNER_AHEAD_MS
-- Word 0 holds slot 7 · generation 2 · epoch 3 · age 10: clear bits 12–21 (the age) before comparing.
local AGE_MASK = bit32.bnot(bit32.lshift(1023, 12))

UplinkIngest.RING = RING
UplinkIngest.MAX_AGE_MS = MAX_AGE_MS
UplinkIngest.MIN_SPACING_MS = MIN_SPACING_MS
UplinkIngest.AHEAD_MS = AHEAD_MS

export type Counters = {
	accepted: number,
	duplicate: number,
	mismatched: number,
	stale: number,
	ahead: number,
	tooFast: number,
	wrongEpoch: number,
}

export type State = {
	epoch: number, -- the body's full epoch; samples must match its low 3 bits
	newestMs: number,
	ringTimes: { number }, -- RING accepted sample times (-math.huge = empty)
	ringWords: { number }, -- RING × 4 record words, age masked
	ringNext: number,
	latest: CharacterRecordCodec.Record?,
	latestMs: number,
	fresh: boolean, -- set on accept; the fan-out clears it when it reads the sample
	counters: Counters,
}

function UplinkIngest.new(): State
	local state: State = {
		epoch = 0,
		newestMs = -math.huge,
		ringTimes = table.create(RING, -math.huge),
		ringWords = table.create(RING * 4, 0),
		ringNext = 1,
		latest = nil,
		latestMs = -math.huge,
		fresh = false,
		counters = {
			accepted = 0,
			duplicate = 0,
			mismatched = 0,
			stale = 0,
			ahead = 0,
			tooFast = 0,
			wrongEpoch = 0,
		},
	}
	return state
end

--[=[
	A new body (spawn / respawn): adopt its epoch and forget the previous body's samples. Counters stay —
	they describe the player's link, not one body.
]=]
function UplinkIngest.reset(state: State, epoch: number)
	state.epoch = epoch
	state.newestMs = -math.huge
	for i = 1, RING do
		state.ringTimes[i] = -math.huge
	end
	state.ringNext = 1
	state.latest = nil
	state.latestMs = -math.huge
	state.fresh = false
end

--[=[
	The uplink rate limiter's clock: the owner's send time, never more than 64 ms past server time.
	`RequestHandler` never lets a bucket's clock move backwards, so a send time that steps back refills
	nothing.
]=]
function UplinkIngest.clockSeconds(sentMs: number, serverNowMs: number): number
	return math.min(sentMs, serverNowMs + AHEAD_MS) / 1000
end

local function findInRing(state: State, sampleMs: number): number?
	for i = 1, RING do
		if state.ringTimes[i] == sampleMs then
			return i
		end
	end
	return nil
end

local function wordAt(packet: buffer, offset: number, w: number): number
	local word = buffer.readu32(packet, offset + w * 4)
	return if w == 0 then bit32.band(word, AGE_MASK) else word
end

local function sameContent(state: State, ringSlot: number, packet: buffer, offset: number): boolean
	local base = (ringSlot - 1) * 4
	for w = 0, 3 do
		if state.ringWords[base + w + 1] ~= wordAt(packet, offset, w) then
			return false
		end
	end
	return true
end

local function remember(state: State, sampleMs: number, packet: buffer, offset: number)
	local ringSlot = state.ringNext
	state.ringTimes[ringSlot] = sampleMs
	local base = (ringSlot - 1) * 4
	for w = 0, 3 do
		state.ringWords[base + w + 1] = wordAt(packet, offset, w)
	end
	state.ringNext = ringSlot % RING + 1
end

--[=[
	Ingest one decoded uplink packet. `packet` is the raw buffer `uplink` was decoded from (for the byte
	comparison). Returns how many samples were accepted.
]=]
function UplinkIngest.ingest(
	state: State,
	packet: buffer,
	uplink: CharacterUplinkCodec.Uplink,
	serverNowMs: number
): number
	local counters = state.counters
	local epochLow = state.epoch % 8
	local samples = uplink.samples
	local accepted = 0
	for i = #samples, 1, -1 do
		local sample = samples[i]
		local record = sample.record
		local sampleMs = sample.sampleMs
		local offset = CharacterUplinkCodec.HEADER_BYTES + (i - 1) * CharacterRecordCodec.RECORD_BYTES
		if record.epoch ~= epochLow then
			counters.wrongEpoch += 1
		elseif sampleMs > serverNowMs + AHEAD_MS then
			counters.ahead += 1
		elseif sampleMs < serverNowMs - MAX_AGE_MS then
			counters.stale += 1
		elseif sampleMs <= state.newestMs then
			local ringSlot = findInRing(state, sampleMs)
			if ringSlot == nil then
				counters.stale += 1
			elseif sameContent(state, ringSlot, packet, offset) then
				counters.duplicate += 1
			else
				counters.mismatched += 1
			end
		elseif sampleMs - state.newestMs < MIN_SPACING_MS then
			counters.tooFast += 1
		else
			state.newestMs = sampleMs
			remember(state, sampleMs, packet, offset)
			state.latest = record
			state.latestMs = sampleMs
			state.fresh = true
			counters.accepted += 1
			accepted += 1
		end
	end
	return accepted
end

return UplinkIngest
```

- [ ] **Step 4: Write `UplinkPipeline.luau`**

```luau
--!strict
--[=[
	UplinkPipeline: the uplink packet handler (Verdict: "Uplink goes through an extended
	RequestHandler.wrap"; plan R2 Task 4).

	  validate  CharacterUplinkCodec.decode — exact size, no action bit, no ragdoll, ordered ages. The
	            decoded packet is handed to the handler (decoded once).
	  clock     UplinkIngest.clockSeconds(sentMs, now): the bucket refills by the owner's send times, so a
	            backlog released after a stall pays for itself, while a flood stamped with one send time
	            gets at most a bucket's worth through (developer run: arrival-paced limits dropped an
	            honest backlog as Flood).
	  bucket    10 tokens, refilled 60 per second of send time.
	  onReject  "count": drops are counted per player for the Debugger, never a warning each.
	  handler   UplinkIngest.ingest on the player's current body; `onAccepted` when a sample got in.

	Shared by CharacterReplicationServiceServer and the load measurement, so both run the same path.

	@class UplinkPipeline
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterUplinkCodec = require(ReplicatedStorage.Shared.Modules.CharacterReplication.CharacterUplinkCodec)
local RequestHandler = require(ServerScriptService.Modules.RequestHandler)
local UplinkIngest = require(script.Parent.UplinkIngest)

local UplinkPipeline = {}

UplinkPipeline.ACTION = "CharacterUplink"
UplinkPipeline.BUCKET = 10
UplinkPipeline.REFILL_PER_SECOND = 60

--[=[
	@param resolve -- the player's live body ingest state, or nil (no body / dead)
	@param nowMs -- server session time in ms
	@param onAccepted -- called after a packet put at least one sample into the body
	@return the wrapped handler for `CharacterReplicationEvents.packets.Uplink`
]=]
function UplinkPipeline.wrap(
	resolve: (player: Player) -> UplinkIngest.State?,
	nowMs: () -> number,
	onAccepted: (player: Player, state: UplinkIngest.State) -> ()
): (data: buffer, player: Player) -> any
	return RequestHandler.wrap({
		name = UplinkPipeline.ACTION,
		rateLimit = {
			maxRequests = UplinkPipeline.BUCKET,
			windowSeconds = UplinkPipeline.BUCKET / UplinkPipeline.REFILL_PER_SECOND,
		},
		validate = function(data: buffer, _player: Player): (boolean, string?, CharacterUplinkCodec.Uplink?)
			return CharacterUplinkCodec.decode(data)
		end,
		clock = function(data: buffer, _player: Player): number
			-- Safe: validation already proved the packet holds at least the 5-byte header.
			return UplinkIngest.clockSeconds(buffer.readu32(data, 0), nowMs())
		end,
		onReject = "count",
		handler = function(data: buffer, player: Player, uplink: CharacterUplinkCodec.Uplink?)
			local state = resolve(player)
			if uplink == nil or state == nil then
				return
			end
			if UplinkIngest.ingest(state, data, uplink, nowMs()) > 0 then
				onAccepted(player, state)
			end
		end,
	})
end

return UplinkPipeline
```

- [ ] **Step 5: Run the tests and verify they pass**

Studio test run: `UplinkIngest` and `UplinkPipeline` specs pass; suite green. Format, Lint, Typecheck (the `validate` / `handler` annotations both name `CharacterUplinkCodec.Uplink` — Ruling 2) clean.

- [ ] **Step 6: Commit**

```bash
git add src/ServerScriptService/Services/CharacterReplicationService/UplinkIngest.luau src/ServerScriptService/Services/CharacterReplicationService/UplinkIngest.spec.luau src/ServerScriptService/Services/CharacterReplicationService/UplinkPipeline.luau src/ServerScriptService/Services/CharacterReplicationService/UplinkPipeline.spec.luau
git commit -m "feat(replication): uplink ingest and the RequestHandler uplink pipeline

Samples enter a body only in its epoch, within 1000 ms old / 64 ms ahead, 15 ms apart, newer than the
newest; repeats are checked against the last four with the age masked and a changed repeat is counted.
The pipeline decodes once, paces the bucket by send time, and counts drops."
```

---
### Task 5: Replication slots, body epochs and distance visibility

**Runtime behaviour: no** (pure server modules).

**Files:**
- Create: `src/ServerScriptService/Services/CharacterReplicationService/ReplicationSlots.spec.luau`
- Create: `src/ServerScriptService/Services/CharacterReplicationService/ReplicationSlots.luau`
- Create: `src/ServerScriptService/Services/CharacterReplicationService/VisibilitySet.spec.luau`
- Create: `src/ServerScriptService/Services/CharacterReplicationService/VisibilitySet.luau`

**Interfaces:**
- Produces:
  - `ReplicationSlots.MAX_SLOT` (127), `EPOCH_SPACING_MS` (250)
  - `export type Slots = { used: { [number]: boolean }, generations: { [number]: number } }`
  - `export type Epoch = { value: number, lastBumpMs: number }`
  - `ReplicationSlots.new(): Slots`, `claim(slots: Slots): number?`, `release(slots: Slots, slot: number)`, `generationOf(slots: Slots, slot: number): number`, `count(slots: Slots): number`
  - `ReplicationSlots.newEpoch(): Epoch`, `bumpEpoch(epoch: Epoch, nowMs: number): boolean`
  - `VisibilitySet.RELEVANT_STUDS` (600), `RELEASE_STUDS` (630)
  - `export type Set = { members: { [number]: boolean }, count: number }`
  - `export type Change = "entered" | "left"`
  - `VisibilitySet.new(): Set`, `update(set: Set, viewer: Vector3, slot: number, position: Vector3): Change?`, `remove(set: Set, slot: number): boolean`, `has(set: Set, slot: number): boolean`

- [ ] **Step 1: Write the failing specs**

`ReplicationSlots.spec.luau`:

```luau
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicationSlots = require(ServerScriptService.Services.CharacterReplicationService.ReplicationSlots)

return function()
	describe("slots", function()
		it("claims the lowest free slot, starting at 1", function()
			local slots = ReplicationSlots.new()
			expect(ReplicationSlots.claim(slots)).to.equal(1)
			expect(ReplicationSlots.claim(slots)).to.equal(2)
			ReplicationSlots.release(slots, 1)
			expect(ReplicationSlots.claim(slots)).to.equal(1)
			expect(ReplicationSlots.count(slots)).to.equal(2)
		end)

		it("returns nil when all 127 slots are taken", function()
			local slots = ReplicationSlots.new()
			for _ = 1, ReplicationSlots.MAX_SLOT do
				expect(ReplicationSlots.claim(slots)).to.be.ok()
			end
			expect(ReplicationSlots.claim(slots)).to.equal(nil)
		end)

		it("release bumps the slot generation, so a reused slot is a new identity", function()
			local slots = ReplicationSlots.new()
			local slot = ReplicationSlots.claim(slots)
			expect(ReplicationSlots.generationOf(slots, slot)).to.equal(0)
			ReplicationSlots.release(slots, slot)
			expect(ReplicationSlots.claim(slots)).to.equal(slot)
			expect(ReplicationSlots.generationOf(slots, slot)).to.equal(1)
		end)

		it("wraps the generation at 4 (2 bits on the wire)", function()
			local slots = ReplicationSlots.new()
			for _ = 1, 4 do
				ReplicationSlots.claim(slots)
				ReplicationSlots.release(slots, 1)
			end
			expect(ReplicationSlots.generationOf(slots, 1)).to.equal(0)
		end)

		it("ignores releasing a slot that is not in use", function()
			local slots = ReplicationSlots.new()
			ReplicationSlots.release(slots, 5)
			expect(ReplicationSlots.generationOf(slots, 5)).to.equal(0)
		end)
	end)

	describe("epochs", function()
		it("bumps from 0 and keeps bumps at least 250 ms apart", function()
			local epoch = ReplicationSlots.newEpoch()
			expect(ReplicationSlots.bumpEpoch(epoch, 1000)).to.equal(true)
			expect(epoch.value).to.equal(1)
			expect(ReplicationSlots.bumpEpoch(epoch, 1200)).to.equal(false)
			expect(epoch.value).to.equal(1)
			expect(ReplicationSlots.bumpEpoch(epoch, 1250)).to.equal(true)
			expect(epoch.value).to.equal(2)
		end)

		it("wraps the full epoch at 256", function()
			local epoch = ReplicationSlots.newEpoch()
			epoch.value = 255
			ReplicationSlots.bumpEpoch(epoch, 0)
			expect(epoch.value).to.equal(0)
		end)
	end)
end
```

`VisibilitySet.spec.luau`:

```luau
local ServerScriptService = game:GetService("ServerScriptService")
local VisibilitySet = require(ServerScriptService.Services.CharacterReplicationService.VisibilitySet)

local VIEWER = Vector3.new(-1228, 10, -363)

local function at(distance)
	return VIEWER + Vector3.new(distance, 0, 0)
end

return function()
	it("enters within 600 studs", function()
		local set = VisibilitySet.new()
		expect(VisibilitySet.update(set, VIEWER, 3, at(700))).to.equal(nil)
		expect(VisibilitySet.update(set, VIEWER, 3, at(600))).to.equal("entered")
		expect(VisibilitySet.has(set, 3)).to.equal(true)
		expect(set.count).to.equal(1)
	end)

	it("holds membership between 600 and 630 studs", function()
		local set = VisibilitySet.new()
		VisibilitySet.update(set, VIEWER, 3, at(100))
		for _, distance in { 610, 630, 605, 629, 601 } do
			expect(VisibilitySet.update(set, VIEWER, 3, at(distance))).to.equal(nil)
		end
		expect(VisibilitySet.has(set, 3)).to.equal(true)
	end)

	it("leaves past 630 studs and does not re-enter until back within 600", function()
		local set = VisibilitySet.new()
		VisibilitySet.update(set, VIEWER, 3, at(100))
		expect(VisibilitySet.update(set, VIEWER, 3, at(631))).to.equal("left")
		expect(VisibilitySet.update(set, VIEWER, 3, at(615))).to.equal(nil)
		expect(VisibilitySet.update(set, VIEWER, 3, at(599))).to.equal("entered")
	end)

	it("ignores a NaN position instead of churning", function()
		local set = VisibilitySet.new()
		local nan = Vector3.new(0 / 0, 0, 0)
		expect(VisibilitySet.update(set, VIEWER, 3, nan)).to.equal(nil)
		VisibilitySet.update(set, VIEWER, 4, at(10))
		expect(VisibilitySet.update(set, VIEWER, 4, nan)).to.equal(nil)
		expect(VisibilitySet.has(set, 4)).to.equal(true)
	end)

	it("remove reports whether the slot was a member", function()
		local set = VisibilitySet.new()
		VisibilitySet.update(set, VIEWER, 3, at(10))
		expect(VisibilitySet.remove(set, 3)).to.equal(true)
		expect(VisibilitySet.remove(set, 3)).to.equal(false)
		expect(set.count).to.equal(0)
	end)
end
```

- [ ] **Step 2: Run the tests and verify they fail**

Studio test run. Expected: both new spec files fail at `require`.

- [ ] **Step 3: Write `ReplicationSlots.luau`**

```luau
--!strict
--[=[
	ReplicationSlots: the replication slot table's identities and the body epoch (spec §6.2, §6.7; plan
	R2 Task 5).

	A slot (1–127, 7 bits on the wire) names a body in every record. A slot is an identity only together
	with its GENERATION (2 bits on the wire): releasing a slot bumps it, so a leaver's late records never
	land on the next owner's body and a viewer rebuilds instead of inheriting (spike CP10 lesson).

	The EPOCH (8 bits; 3 on the wire) is server-owned and bumped on every spawn — join, respawn, slot
	switch. Bumps are at least 250 ms apart; a bump inside that window is refused (the body is already
	fresh).

	Pure.

	@class ReplicationSlots
]=]

local ReplicationSlots = {}

local MAX_SLOT = 127
local EPOCH_SPACING_MS = 250

ReplicationSlots.MAX_SLOT = MAX_SLOT
ReplicationSlots.EPOCH_SPACING_MS = EPOCH_SPACING_MS

export type Slots = {
	used: { [number]: boolean },
	generations: { [number]: number },
}

export type Epoch = {
	value: number,
	lastBumpMs: number,
}

function ReplicationSlots.new(): Slots
	return { used = {}, generations = {} }
end

function ReplicationSlots.claim(slots: Slots): number?
	for slot = 1, MAX_SLOT do
		if not slots.used[slot] then
			slots.used[slot] = true
			return slot
		end
	end
	return nil
end

function ReplicationSlots.release(slots: Slots, slot: number)
	if not slots.used[slot] then
		return
	end
	slots.used[slot] = nil
	slots.generations[slot] = ((slots.generations[slot] or 0) + 1) % 4
end

function ReplicationSlots.generationOf(slots: Slots, slot: number): number
	return slots.generations[slot] or 0
end

function ReplicationSlots.count(slots: Slots): number
	local count = 0
	for _ in slots.used do
		count += 1
	end
	return count
end

function ReplicationSlots.newEpoch(): Epoch
	return { value = 0, lastBumpMs = -math.huge }
end

--[=[
	Bump the body epoch at `nowMs`. False (and unchanged) within 250 ms of the previous bump.
]=]
function ReplicationSlots.bumpEpoch(epoch: Epoch, nowMs: number): boolean
	if nowMs - epoch.lastBumpMs < EPOCH_SPACING_MS then
		return false
	end
	epoch.value = (epoch.value + 1) % 256
	epoch.lastBumpMs = nowMs
	return true
end

return ReplicationSlots
```

- [ ] **Step 4: Write `VisibilitySet.luau`**

```luau
--!strict
--[=[
	VisibilitySet: which bodies a viewer has loaded (spec §6.5, C6: distance only in this phase; plan R2
	Task 5).

	A body enters within 600 studs and leaves past 630: the 30-stud hysteresis keeps a viewer walking along
	the edge from flapping (each flap is a reliable enter/leave message and a public-slice change). The set
	doubles as the viewer's relevant set for public data, so it changes ONLY on enter/leave — movement
	inside the set never touches it. Squared distances; a NaN position never changes membership.

	Pure.

	@class VisibilitySet
]=]

local VisibilitySet = {}

local RELEVANT_STUDS = 600
local RELEASE_STUDS = 630
local RELEVANT_SQUARED = RELEVANT_STUDS * RELEVANT_STUDS
local RELEASE_SQUARED = RELEASE_STUDS * RELEASE_STUDS

VisibilitySet.RELEVANT_STUDS = RELEVANT_STUDS
VisibilitySet.RELEASE_STUDS = RELEASE_STUDS

export type Set = {
	members: { [number]: boolean }, -- by slot
	count: number,
}

export type Change = "entered" | "left"

function VisibilitySet.new(): Set
	return { members = {}, count = 0 }
end

function VisibilitySet.update(set: Set, viewer: Vector3, slot: number, position: Vector3): Change?
	local offset = position - viewer
	local squared = offset:Dot(offset)
	if set.members[slot] then
		if squared > RELEASE_SQUARED then
			set.members[slot] = nil
			set.count -= 1
			return "left"
		end
	elseif squared <= RELEVANT_SQUARED then
		set.members[slot] = true
		set.count += 1
		return "entered"
	end
	return nil
end

function VisibilitySet.remove(set: Set, slot: number): boolean
	if set.members[slot] then
		set.members[slot] = nil
		set.count -= 1
		return true
	end
	return false
end

function VisibilitySet.has(set: Set, slot: number): boolean
	return set.members[slot] == true
end

return VisibilitySet
```

- [ ] **Step 5: Run the tests and verify they pass**

Studio test run: both specs pass; suite green. Format, Lint, Typecheck clean.

- [ ] **Step 6: Commit**

```bash
git add src/ServerScriptService/Services/CharacterReplicationService/ReplicationSlots.luau src/ServerScriptService/Services/CharacterReplicationService/ReplicationSlots.spec.luau src/ServerScriptService/Services/CharacterReplicationService/VisibilitySet.luau src/ServerScriptService/Services/CharacterReplicationService/VisibilitySet.spec.luau
git commit -m "feat(replication): replication slots with generations, body epochs, distance visibility

Slots 1-127 with a 2-bit generation bumped on release; an 8-bit epoch bumped at least 250 ms apart;
membership enters within 600 studs and leaves past 630."
```

---
### Task 6: Downlink scheduler — encode once, priority accumulator, 700 B cap, 24 KB/s budget

**Runtime behaviour: no** (pure server module).

Carries the R1 review's repair-restamp item: a body still for over 1 s is sent as "still here as of now" because the downlink age field saturates at 1023 ms. Implements ruling 7: the v3 send policy decides which bodies are due; a per-viewer priority accumulator with a far cap decides which of them fit this frame.

**Files:**
- Create: `src/ServerScriptService/Services/CharacterReplicationService/DownlinkScheduler.spec.luau`
- Create: `src/ServerScriptService/Services/CharacterReplicationService/DownlinkScheduler.luau`

**Interfaces:**
- Consumes: `CharacterRecordCodec` (`Record`, `writeRecord`, `HEADER_BYTES`, `RECORD_BYTES`, `ACTION_BYTES`).
- Produces:
  - `DownlinkScheduler.HARD_CAP_BYTES` (700), `BUDGET_BYTES_PER_SECOND` (24000), `SCRATCH_BYTES` (18)
  - `export type Config = { nearStuds: number, nearWeight: number, farStuds: number, farWeight: number, farCapStuds: number, farMinIntervalMs: number }`
  - `DownlinkScheduler.DEFAULT_CONFIG: Config` (frozen: 50 studs → 3, 600 studs → 1, far cap 300 studs / 33 ms)
  - `export type Viewer = { seq: number, allowanceBytes: number, lastPackMs: number?, config: Config, pending: { [number]: boolean }, scores: { [number]: number }, lastSentMs: { [number]: number }, eligible: { number }, chosen: { number }, sentBytes: number, sentBatches: number }`
  - `DownlinkScheduler.newViewer(config: Config?): Viewer`
  - `DownlinkScheduler.forget(viewer: Viewer, slot: number)`
  - `DownlinkScheduler.closeness(config: Config, distance: number): number` — a due body's gain per frame
  - `DownlinkScheduler.encode(out: buffer, slot: number, generation: number, epoch: number, record: CharacterRecordCodec.Record, sampleMs: number, batchTimeMs: number): number` — bytes written (16)
  - `DownlinkScheduler.pack(viewer: Viewer, nowMs: number, slots: { number }, bytes: { [number]: buffer }, lengths: { [number]: number }, distances: { number }): buffer?` — `nowMs` is also the batch time; `distances[i]` is the viewer's distance to the body in `slots[i]`. The `distances` argument is new with the accumulator (the closeness weight and the far cap need it); Task 7 passes it.

- [ ] **Step 1: Write the failing spec**

`DownlinkScheduler.spec.luau`:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Codec = require(ReplicatedStorage.Shared.Modules.CharacterReplication.CharacterRecordCodec)
local DownlinkScheduler = require(ServerScriptService.Services.CharacterReplicationService.DownlinkScheduler)

local FRAME_MS = 1000 / 60

local function record(overrides)
	local r = {
		slot = 0,
		generation = 0,
		epoch = 1,
		ageMs = 0,
		position = Vector3.new(-1200, 40, -350),
		yaw = 0,
		pitch = 0,
		velocity = Vector3.new(16, 0, 0),
		state = 8,
		grounded = true,
		hasAction = false,
		rotation = nil,
	}
	for key, value in overrides or {} do
		r[key] = value
	end
	return r
end

-- One encoded record per slot (all 20 ms old at `nowMs`), as the fan-out prepares them.
local function encoded(count, nowMs)
	local bytes, lengths = {}, {}
	for slot = 1, count do
		local b = buffer.create(DownlinkScheduler.SCRATCH_BYTES)
		local position = Vector3.new(-1228 + slot, 10, -363)
		lengths[slot] = DownlinkScheduler.encode(b, slot, 0, 1, record({ position = position }), nowMs - 20, nowMs)
		bytes[slot] = b
	end
	return bytes, lengths
end

local function range(first, last)
	local t = {}
	for i = first, last do
		table.insert(t, i)
	end
	return t
end

-- Distances parallel to `slots`: `distanceOf(slot)` studs from the viewer.
local function distancesFor(slots, distanceOf)
	local t = {}
	for i, slot in slots do
		t[i] = distanceOf(slot)
	end
	return t
end

local function constant(distance)
	return function()
		return distance
	end
end

local function slotsIn(batch)
	local out = {}
	if batch == nil then
		return out
	end
	local header = Codec.readHeader(batch, 0)
	for i = 1, header.count do
		table.insert(out, Codec.readRecord(batch, Codec.HEADER_BYTES + (i - 1) * Codec.RECORD_BYTES).slot)
	end
	return out
end

local function contains(list, value)
	return table.find(list, value) ~= nil
end

return function()
	describe("encode", function()
		it("writes slot, generation, the epoch's low bits and the age at batch time", function()
			local b = buffer.create(DownlinkScheduler.SCRATCH_BYTES)
			expect(DownlinkScheduler.encode(b, 7, 2, 9, record(), 980, 1000)).to.equal(16)
			local r = Codec.readRecord(b, 0)
			expect(r.slot).to.equal(7)
			expect(r.generation).to.equal(2)
			expect(r.epoch).to.equal(1)
			expect(r.ageMs).to.equal(20)
			expect(r.velocity.X).to.be.near(16, 0.2)
			expect(r.hasAction).to.equal(false)
		end)

		it("restamps a sample older than 1023 ms as a still body at batch time", function()
			local b = buffer.create(DownlinkScheduler.SCRATCH_BYTES)
			DownlinkScheduler.encode(b, 7, 0, 1, record(), -500, 1000)
			local r = Codec.readRecord(b, 0)
			expect(r.ageMs).to.equal(0)
			expect(r.velocity.Magnitude).to.equal(0)
			expect(r.position.X).to.be.near(-1200, 0.02)
		end)

		it("clamps a sample stamped after the batch time to age 0", function()
			local b = buffer.create(DownlinkScheduler.SCRATCH_BYTES)
			DownlinkScheduler.encode(b, 7, 0, 1, record(), 1040, 1000)
			expect(Codec.readRecord(b, 0).ageMs).to.equal(0)
		end)
	end)

	describe("closeness", function()
		it("weighs 3 within 50 studs, falls linearly, and weighs 1 from 600 studs", function()
			local config = DownlinkScheduler.DEFAULT_CONFIG
			expect(DownlinkScheduler.closeness(config, 0)).to.equal(3)
			expect(DownlinkScheduler.closeness(config, 50)).to.equal(3)
			expect(DownlinkScheduler.closeness(config, 325)).to.be.near(2, 1e-9)
			expect(DownlinkScheduler.closeness(config, 600)).to.equal(1)
			expect(DownlinkScheduler.closeness(config, 630)).to.equal(1)
		end)
	end)

	describe("pack", function()
		it("packs every candidate under the cap behind a sequenced header", function()
			local viewer = DownlinkScheduler.newViewer()
			local bytes, lengths = encoded(5, 1000)
			local slots = range(1, 5)
			local batch = DownlinkScheduler.pack(viewer, 1000, slots, bytes, lengths, distancesFor(slots, constant(10)))
			expect(buffer.len(batch)).to.equal(Codec.HEADER_BYTES + 5 * 16)
			local header = Codec.readHeader(batch, 0)
			expect(header.seq).to.equal(1)
			expect(header.count).to.equal(5)
			expect(header.batchTimeMs).to.equal(1000)
			expect(buffer.readstring(batch, Codec.HEADER_BYTES, 16)).to.equal(buffer.readstring(bytes[1], 0, 16))
		end)

		it("sends every due body when they all fit, whatever their scores, and resets the scores", function()
			local viewer = DownlinkScheduler.newViewer()
			viewer.scores[1] = 0
			viewer.scores[5] = 1000
			local bytes, lengths = encoded(5, 1000)
			local slots = range(1, 5)
			local distances = { 10, 200, 290, 550, 620 }
			local sent = slotsIn(DownlinkScheduler.pack(viewer, 1000, slots, bytes, lengths, distances))
			expect(#sent).to.equal(5)
			for slot = 1, 5 do
				expect(contains(sent, slot)).to.equal(true)
				expect(viewer.scores[slot]).to.equal(0)
			end
		end)

		it("never exceeds 700 B: 50 bodies send 43, and the rest go first next frame", function()
			local viewer = DownlinkScheduler.newViewer()
			local bytes, lengths = encoded(50, 1000)
			local slots = range(1, 50)
			local distances = distancesFor(slots, constant(10))
			local first = DownlinkScheduler.pack(viewer, 1000, slots, bytes, lengths, distances)
			expect(buffer.len(first) <= DownlinkScheduler.HARD_CAP_BYTES).to.equal(true)
			expect(#slotsIn(first)).to.equal(43)
			local second = slotsIn(DownlinkScheduler.pack(viewer, 1017, slots, bytes, lengths, distances))
			for i = 1, 7 do
				expect(second[i]).to.equal(43 + i)
			end
		end)

		it("sends the nearer bodies first over the cap", function()
			local viewer = DownlinkScheduler.newViewer()
			local bytes, lengths = encoded(50, 1000)
			local slots = range(1, 50)
			-- Slots 1–25 at 550 studs, 26–50 at 20 studs: listed first, the far ones still lose.
			local distances = distancesFor(slots, function(slot)
				return if slot <= 25 then 550 else 20
			end)
			local sent = slotsIn(DownlinkScheduler.pack(viewer, 1000, slots, bytes, lengths, distances))
			expect(#sent).to.equal(43)
			for slot = 26, 50 do
				expect(contains(sent, slot)).to.equal(true)
			end
		end)

		it("resets a sent body's score and keeps the unsent ones' scores and pending flags", function()
			local viewer = DownlinkScheduler.newViewer()
			local bytes, lengths = encoded(50, 1000)
			local slots = range(1, 50)
			local distances = distancesFor(slots, function(slot)
				return if slot <= 25 then 550 else 20
			end)
			local sent = slotsIn(DownlinkScheduler.pack(viewer, 1000, slots, bytes, lengths, distances))
			local farWeight = DownlinkScheduler.closeness(DownlinkScheduler.DEFAULT_CONFIG, 550)
			for slot = 1, 50 do
				if contains(sent, slot) then
					expect(viewer.scores[slot]).to.equal(0)
					expect(viewer.pending[slot]).to.equal(nil)
				else
					expect(viewer.scores[slot]).to.be.near(farWeight, 1e-9)
					expect(viewer.pending[slot]).to.equal(true)
				end
			end
		end)

		it("never accumulates a score for a body that is not due", function()
			local viewer = DownlinkScheduler.newViewer()
			local bytes, lengths = encoded(51, 0)
			local slots = range(1, 50)
			local distances = distancesFor(slots, constant(10))
			DownlinkScheduler.pack(viewer, 0, slots, bytes, lengths, distances)
			expect(viewer.scores[1]).to.equal(0) -- sent in the first frame
			local rest = range(2, 50)
			local restDistances = distancesFor(rest, constant(10))
			for frame = 1, 5 do
				DownlinkScheduler.pack(viewer, frame * FRAME_MS, rest, bytes, lengths, restDistances)
			end
			expect(viewer.scores[1]).to.equal(0)
			expect(viewer.scores[51]).to.equal(nil)
		end)

		it("sends a far body within a bound set by the weights, under sustained overload", function()
			local config = DownlinkScheduler.DEFAULT_CONFIG
			local n = 50
			local far = n -- the highest slot: it loses every tie
			local viewer = DownlinkScheduler.newViewer()
			local bytes, lengths = encoded(n, 0)
			local slots = range(1, n)
			local distances = distancesFor(slots, function(slot)
				return if slot == far then config.farStuds else 10
			end)
			--[[
				The bound. Near bodies gain wNear = 3 per frame, the far one wFar = 1 (it is beyond the far cap,
				so it is held the one frame after each send). Per frame at least K records go:
				K = floor((24000 / 60 − 7) / 16) = 24. Say the far body is unsent for T frames after a send. In
				the last floor(T / 2) of them its score is at least wFar · T / 2, and every body sent instead
				had a score at least that high, so it had waited at least T / (2 · r) frames since its own
				previous send (r = wNear / wFar): each of the other n − 1 bodies is sent at most r + 1 times in
				that window. Those windows hold at least K · floor(T / 2) sends, so
				K · floor(T / 2) ≤ (n − 1)(r + 1): floor(T / 2) ≤ 8 here, T ≤ 17, and the far body is sent at
				least once in every 18 frames.
			]]
			local ratio = config.nearWeight / config.farWeight
			local perFrame = math.floor((DownlinkScheduler.BUDGET_BYTES_PER_SECOND / 60 - Codec.HEADER_BYTES) / 16)
			local halfWindow = math.floor((n - 1) * (ratio + 1) / perFrame)
			local bound = 2 * halfWindow + 2 -- frames between two sends: T + 1
			local lastSentFrame, maxGap = 0, 0
			for frame = 1, 600 do
				local batch = DownlinkScheduler.pack(viewer, frame * FRAME_MS, slots, bytes, lengths, distances)
				if contains(slotsIn(batch), far) then
					maxGap = math.max(maxGap, frame - lastSentFrame)
					lastSentFrame = frame
				end
			end
			maxGap = math.max(maxGap, 600 - lastSentFrame)
			expect(bound).to.equal(18)
			expect(maxGap > 2).to.equal(true) -- overloaded: the far body really waited
			expect(maxGap <= bound).to.equal(true)
		end)

		it("holds a far body inside 33 ms, never a near one, and sends it once the interval passes", function()
			local viewer = DownlinkScheduler.newViewer()
			local bytes, lengths = encoded(2, 1000)
			local slots = { 1, 2 }
			local distances = { 100, 400 }
			expect(#slotsIn(DownlinkScheduler.pack(viewer, 1000, slots, bytes, lengths, distances))).to.equal(2)
			local held = slotsIn(DownlinkScheduler.pack(viewer, 1017, slots, bytes, lengths, distances))
			expect(contains(held, 1)).to.equal(true)
			expect(contains(held, 2)).to.equal(false)
			expect(viewer.pending[2]).to.equal(true)
			expect(viewer.scores[2]).to.equal(0) -- held: keeps its place, gains nothing
			local after = slotsIn(DownlinkScheduler.pack(viewer, 1034, slots, bytes, lengths, distances))
			expect(contains(after, 1)).to.equal(true)
			expect(contains(after, 2)).to.equal(true)
			expect(viewer.pending[2]).to.equal(nil)
		end)

		it("keeps to the 24 KB/s budget over a second", function()
			local viewer = DownlinkScheduler.newViewer()
			local bytes, lengths = encoded(50, 0)
			local slots = range(1, 50)
			local distances = distancesFor(slots, constant(10))
			local total = 0
			for frame = 0, 59 do
				local batch = DownlinkScheduler.pack(viewer, frame * FRAME_MS, slots, bytes, lengths, distances)
				if batch ~= nil then
					total += buffer.len(batch)
				end
			end
			expect(total <= DownlinkScheduler.HARD_CAP_BYTES + DownlinkScheduler.BUDGET_BYTES_PER_SECOND).to.equal(true)
			expect(total >= 22000).to.equal(true)
		end)

		it("sends nothing when the allowance cannot fit a record, and marks every candidate pending", function()
			local viewer = DownlinkScheduler.newViewer()
			viewer.allowanceBytes = 10
			viewer.lastPackMs = 1000
			local bytes, lengths = encoded(3, 1000)
			local slots = range(1, 3)
			expect(DownlinkScheduler.pack(viewer, 1000, slots, bytes, lengths, distancesFor(slots, constant(10)))).to.equal(
				nil
			)
			expect(viewer.pending[1]).to.equal(true)
			expect(viewer.pending[3]).to.equal(true)
			expect(viewer.seq).to.equal(0)
		end)

		it("clears a body's pending flag once it is sent", function()
			local viewer = DownlinkScheduler.newViewer()
			viewer.pending[2] = true
			local bytes, lengths = encoded(3, 1000)
			local slots = range(1, 3)
			DownlinkScheduler.pack(viewer, 1000, slots, bytes, lengths, distancesFor(slots, constant(10)))
			expect(viewer.pending[2]).to.equal(nil)
		end)

		it("returns nil for no candidates", function()
			local viewer = DownlinkScheduler.newViewer()
			expect(DownlinkScheduler.pack(viewer, 1000, {}, {}, {}, {})).to.equal(nil)
		end)

		it("forget drops a body's pending flag, score and last send time", function()
			local viewer = DownlinkScheduler.newViewer()
			viewer.pending[4] = true
			viewer.scores[4] = 12
			viewer.lastSentMs[4] = 1000
			DownlinkScheduler.forget(viewer, 4)
			expect(viewer.pending[4]).to.equal(nil)
			expect(viewer.scores[4]).to.equal(nil)
			expect(viewer.lastSentMs[4]).to.equal(nil)
		end)
	end)
end
```

- [ ] **Step 2: Run the tests and verify they fail**

Studio test run. Expected: `DownlinkScheduler.spec` fails at `require`.

- [ ] **Step 3: Write `DownlinkScheduler.luau`**

```luau
--!strict
--[=[
	DownlinkScheduler: what one viewer receives in one frame (spec §6.4 as superseded by the Verdict's v3
	send policy and its "Downlink scheduling is a priority accumulator" decision; plan R2 Task 6).

	`encode` writes a body's newest accepted sample ONCE per frame (the fan-out reuses the bytes for every
	viewer): slot, slot generation, the epoch's low bits, and the age at batch time. Restamp (R1 review): the
	10-bit age saturates at 1023 ms, so a sample older than that — a body that stopped sending, typically
	standing still — goes out with age 0 and zero velocity: "still here as of now". Viewers receive it as a
	new sample with transit-only lateness and hold the body.

	`pack` builds the viewer's batch from the candidates due this frame (scheduled by their body's send
	policy, or pending from a frame where they were not sent):
	  - far cap: a body beyond `farCapStuds` whose last record to this viewer went out less than
	    `farMinIntervalMs` ago is held this frame (about 30 Hz at most, the floor the single render delay
	    covers). It stays due and keeps its score; it does not accumulate while held;
	  - every other due body's score (per viewer, per body) grows by its closeness weight: `nearWeight`
	    within `nearStuds`, falling linearly to `farWeight` at `farStuds`. Bodies that are not due never
	    accumulate;
	  - if every due record fits — at most 700 B (hard cap) and within the viewer's 24 KB/s budget (an
	    allowance refilled per ms, capped at 700 B) — all of them go, with no ordering at all;
	  - otherwise the highest scores fill the batch (see `selectTop`). Near bodies go first in a crowd, and a
	    far body still climbs every frame until it outranks them, so nothing starves;
	  - a sent body's score resets to 0; every due body that is not sent becomes pending: it stays due (it
	    keeps being a candidate even if its body stopped changing) until it is sent.

	Pure. No allocation per frame in steady state except the batch buffer itself: scores, last-send times
	and the selection arrays are reused per viewer.

	@class DownlinkScheduler
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterRecordCodec = require(ReplicatedStorage.Shared.Modules.CharacterReplication.CharacterRecordCodec)

local DownlinkScheduler = {}

local HARD_CAP_BYTES = 700
local BUDGET_BYTES_PER_SECOND = 24000
local HEADER_BYTES = CharacterRecordCodec.HEADER_BYTES
local MIN_RECORD_BYTES = CharacterRecordCodec.RECORD_BYTES
local MAX_AGE_MS = 1023

DownlinkScheduler.HARD_CAP_BYTES = HARD_CAP_BYTES
DownlinkScheduler.BUDGET_BYTES_PER_SECOND = BUDGET_BYTES_PER_SECOND
-- Room for a record with its action extension (R3), so a body's scratch buffer never needs resizing.
DownlinkScheduler.SCRATCH_BYTES = CharacterRecordCodec.RECORD_BYTES + CharacterRecordCodec.ACTION_BYTES

export type Config = {
	nearStuds: number, -- within this, a due body gains `nearWeight` per frame
	nearWeight: number,
	farStuds: number, -- at and beyond this, `farWeight` per frame (linear in between)
	farWeight: number,
	farCapStuds: number, -- beyond this, at most one record per `farMinIntervalMs` to this viewer
	farMinIntervalMs: number,
}

-- Starting values; R2's last task measures them (Verdict: all numbers are config).
local DEFAULT_CONFIG: Config = {
	nearStuds = 50,
	nearWeight = 3,
	farStuds = 600,
	farWeight = 1,
	farCapStuds = 300,
	farMinIntervalMs = 33,
}
table.freeze(DEFAULT_CONFIG)
DownlinkScheduler.DEFAULT_CONFIG = DEFAULT_CONFIG

export type Viewer = {
	seq: number,
	allowanceBytes: number,
	lastPackMs: number?,
	config: Config,
	pending: { [number]: boolean }, -- slot → was due and not sent; due until sent
	scores: { [number]: number }, -- slot → accumulated priority; 0 after a send
	lastSentMs: { [number]: number }, -- slot → when its last record went to this viewer (the far cap)
	eligible: { number }, -- scratch: this frame's due slots not held by the far cap (permuted by selection)
	chosen: { number }, -- scratch: the slots kept this frame when not everything fits
	sentBytes: number,
	sentBatches: number,
}

function DownlinkScheduler.newViewer(config: Config?): Viewer
	return {
		seq = 0,
		allowanceBytes = HARD_CAP_BYTES,
		lastPackMs = nil,
		config = config or DEFAULT_CONFIG,
		pending = {},
		scores = {},
		lastSentMs = {},
		eligible = {},
		chosen = {},
		sentBytes = 0,
		sentBatches = 0,
	}
end

-- A body left this viewer's set: it owes nothing, and a later re-entry starts from a clean score.
function DownlinkScheduler.forget(viewer: Viewer, slot: number)
	viewer.pending[slot] = nil
	viewer.scores[slot] = nil
	viewer.lastSentMs[slot] = nil
end

-- What a due body at `distance` studs gains per frame.
function DownlinkScheduler.closeness(config: Config, distance: number): number
	if distance <= config.nearStuds then
		return config.nearWeight
	elseif distance >= config.farStuds then
		return config.farWeight
	end
	local t = (distance - config.nearStuds) / (config.farStuds - config.nearStuds)
	return config.nearWeight + (config.farWeight - config.nearWeight) * t
end

-- One scratch record reused for every encode: no table per body per frame.
local scratch: CharacterRecordCodec.Record = {
	slot = 0,
	generation = 0,
	epoch = 0,
	ageMs = 0,
	position = Vector3.zero,
	yaw = 0,
	pitch = 0,
	velocity = Vector3.zero,
	state = 0,
	grounded = true,
	hasAction = false,
	rotation = nil,
}

function DownlinkScheduler.encode(
	out: buffer,
	slot: number,
	generation: number,
	epoch: number,
	record: CharacterRecordCodec.Record,
	sampleMs: number,
	batchTimeMs: number
): number
	local ageMs = batchTimeMs - sampleMs
	local velocity = record.velocity
	if ageMs > MAX_AGE_MS then
		ageMs = 0
		velocity = Vector3.zero
	elseif ageMs < 0 then
		ageMs = 0
	end
	scratch.slot = slot
	scratch.generation = generation
	scratch.epoch = epoch
	scratch.ageMs = ageMs
	scratch.position = record.position
	scratch.yaw = record.yaw
	scratch.pitch = record.pitch
	scratch.velocity = velocity
	scratch.state = record.state
	scratch.grounded = record.grounded
	scratch.hasAction = false -- R2 relays no actions (they are server-granted, R3)
	scratch.rotation = record.rotation
	CharacterRecordCodec.writeRecord(out, 0, scratch)
	return CharacterRecordCodec.RECORD_BYTES
end

-- Higher score first; equal scores go to the lower slot, so the order is deterministic.
local function outranks(scores: { [number]: number }, a: number, b: number): boolean
	local scoreA, scoreB = scores[a], scores[b]
	return scoreA > scoreB or (scoreA == scoreB and a < b)
end

local function siftDown(heap: { number }, scores: { [number]: number }, index: number, size: number)
	while true do
		local best = index * 2
		if best > size then
			return
		end
		if best < size and outranks(scores, heap[best + 1], heap[best]) then
			best += 1
		end
		if not outranks(scores, heap[best], heap[index]) then
			return
		end
		heap[index], heap[best] = heap[best], heap[index]
		index = best
	end
end

--[=[
	Over the limit: keep the highest scores that fit `budget`, into `viewer.chosen`. Returns the batch size.

	A binary max-heap built in place over the reused `eligible` array and popped only until the batch is
	full: O(n + k log n), under ~900 comparisons for n = 128 candidates and k = 43 picks, against ~5,000 for
	a repeated max-scan. Unlike `table.sort` it orders only what is sent and needs no comparator closure over
	the scores (an allocation per call). Records of different sizes (R3's action extension) are handled
	greedily: one that does not fit is skipped and a smaller one behind it may still go.
]=]
local function selectTop(viewer: Viewer, lengths: { [number]: number }, budget: number): number
	local heap = viewer.eligible
	local scores = viewer.scores
	local pending = viewer.pending
	local chosen = viewer.chosen
	table.clear(chosen)
	local size = #heap
	for i = 1, size do
		pending[heap[i]] = true -- cleared again for every slot that is sent
	end
	for i = size // 2, 1, -1 do
		siftDown(heap, scores, i, size)
	end
	local total = HEADER_BYTES
	while size > 0 and budget - total >= MIN_RECORD_BYTES do
		local top = heap[1]
		heap[1] = heap[size]
		size -= 1
		siftDown(heap, scores, 1, size)
		local length = lengths[top]
		if total + length <= budget then
			total += length
			table.insert(chosen, top)
		end
	end
	return total
end

--[=[
	Build this viewer's batch. `slots` holds the due slots and `distances[i]` is the distance in studs from
	the viewer to the body in `slots[i]`; `bytes[slot]` and `lengths[slot]` are this frame's encodings.
	`nowMs` is also the batch time. Returns nil when nothing is sent.
]=]
function DownlinkScheduler.pack(
	viewer: Viewer,
	nowMs: number,
	slots: { number },
	bytes: { [number]: buffer },
	lengths: { [number]: number },
	distances: { number }
): buffer?
	local lastPack = viewer.lastPackMs
	if lastPack ~= nil then
		local refill = BUDGET_BYTES_PER_SECOND * math.max(0, nowMs - lastPack) / 1000
		viewer.allowanceBytes = math.min(HARD_CAP_BYTES, viewer.allowanceBytes + refill)
	end
	viewer.lastPackMs = nowMs
	local count = #slots
	if count == 0 then
		return nil
	end
	local config = viewer.config
	local scores = viewer.scores
	local lastSentMs = viewer.lastSentMs
	local pending = viewer.pending
	local eligible = viewer.eligible
	table.clear(eligible)
	local total = HEADER_BYTES
	for i = 1, count do
		local slot = slots[i]
		local distance = distances[i]
		local lastSent = lastSentMs[slot]
		if distance > config.farCapStuds and lastSent ~= nil and nowMs - lastSent < config.farMinIntervalMs then
			pending[slot] = true
		else
			scores[slot] = (scores[slot] or 0) + DownlinkScheduler.closeness(config, distance)
			table.insert(eligible, slot)
			total += lengths[slot]
		end
	end
	local budget = math.min(HARD_CAP_BYTES, viewer.allowanceBytes)
	local kept = eligible
	if total > budget then
		total = selectTop(viewer, lengths, budget)
		kept = viewer.chosen
	end
	if #kept == 0 then
		return nil
	end
	viewer.seq = (viewer.seq + 1) % 65536
	local batch = buffer.create(total)
	buffer.writeu16(batch, 0, viewer.seq)
	buffer.writeu32(batch, 2, nowMs % 4294967296)
	buffer.writeu8(batch, 6, #kept)
	local offset = HEADER_BYTES
	for _, slot in kept do
		local length = lengths[slot]
		buffer.copy(batch, offset, bytes[slot], 0, length)
		offset += length
		pending[slot] = nil
		scores[slot] = 0
		lastSentMs[slot] = nowMs
	end
	viewer.allowanceBytes -= total
	viewer.sentBytes += total
	viewer.sentBatches += 1
	return batch
end

return DownlinkScheduler
```

- [ ] **Step 4: Run the tests and verify they pass**

Studio test run: `DownlinkScheduler.spec` passes; suite green. Format, Lint, Typecheck clean.

- [ ] **Step 5: Commit**

```bash
git add src/ServerScriptService/Services/CharacterReplicationService/DownlinkScheduler.luau src/ServerScriptService/Services/CharacterReplicationService/DownlinkScheduler.spec.luau
git commit -m "feat(replication): downlink scheduler with a priority accumulator, 700 B cap and 24 KB/s budget

Records are encoded once per frame with the age at batch time; a sample older than 1023 ms is
restamped as a still body. Each due body's per-viewer score grows by a closeness weight; when
everything fits all due records go, otherwise the highest scores fill the batch and reset. Bodies
beyond 300 studs get at most one record per 33 ms, and a record that is not sent stays due."
```

---
### Task 7: Replication fan-out — one server frame

**Runtime behaviour: no** (pure server module).

**Files:**
- Create: `src/ServerScriptService/Services/CharacterReplicationService/ReplicationFanout.spec.luau`
- Create: `src/ServerScriptService/Services/CharacterReplicationService/ReplicationFanout.luau`

**Interfaces:**
- Consumes: `SendPolicy` (R1: `new`, `changed`, `decide`), `UplinkIngest` (Task 4), `ReplicationSlots` / `VisibilitySet` (Task 5), `DownlinkScheduler` (Task 6), `CharacterRecordCodec.Record`.
- Produces:
  - `ReplicationFanout.DEFAULT_MAX_HEALTH` (100)
  - `export type Body = { userId: number, slot: number, generation: number, epoch: ReplicationSlots.Epoch, ready: boolean, alive: boolean, position: Vector3, ingest: UplinkIngest.State, policy: SendPolicy.Policy, lastSent: CharacterRecordCodec.Record?, scheduled: boolean, frameBytes: buffer, visibility: VisibilitySet.Set, viewer: DownlinkScheduler.Viewer, relevant: { [number]: boolean }, health: number, maxHealth: number }`
  - `export type World = { bodies: { [number]: Body }, candidates: { number }, distances: { number }, bytes: { [number]: buffer }, lengths: { [number]: number } }`
  - `export type Hooks = { send: (viewer: Body, batch: buffer) -> (), visibility: (viewer: Body, subject: Body, entered: boolean) -> () }`
  - `ReplicationFanout.newWorld(): World`
  - `ReplicationFanout.newBody(userId: number, slot: number, generation: number, position: Vector3): Body`
  - `ReplicationFanout.addBody(world: World, body: Body)`
  - `ReplicationFanout.removeBody(world: World, slot: number, hooks: Hooks): Body?`
  - `ReplicationFanout.respawned(body: Body)` — call after `ReplicationSlots.bumpEpoch(body.epoch, …)` succeeded
  - `ReplicationFanout.resetViewer(body: Body)` — a viewer that (re)joined the stream
  - `ReplicationFanout.setMaxHealth(body: Body, maxHealth: number): boolean`
  - `ReplicationFanout.enterRecord(subject: Body, nowMs: number): (CharacterRecordCodec.Record, number)`
  - `ReplicationFanout.step(world: World, nowMs: number, hooks: Hooks): number` — batches sent

- [ ] **Step 1: Write the failing spec**

`ReplicationFanout.spec.luau`:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Codec = require(ReplicatedStorage.Shared.Modules.CharacterReplication.CharacterRecordCodec)
local Fanout = require(ServerScriptService.Services.CharacterReplicationService.ReplicationFanout)

local ORIGIN = Vector3.new(-1228, 10, -363)

local function body(userId, slot, position)
	local b = Fanout.newBody(userId, slot, 0, position)
	b.ready = true
	b.epoch.value = 1
	Fanout.respawned(b)
	return b
end

-- Simulate an accepted uplink sample for `b`.
local function feed(b, nowMs, position)
	b.ingest.latest = {
		slot = 0,
		generation = 0,
		epoch = 1,
		ageMs = 0,
		position = position,
		yaw = 0,
		pitch = 0,
		velocity = Vector3.new(16, 0, 0),
		state = 8,
		grounded = true,
		hasAction = false,
		rotation = nil,
	}
	b.ingest.latestMs = nowMs
	b.ingest.fresh = true
	b.position = position
end

local function recorder()
	local log = { sends = {}, enters = {}, leaves = {} }
	local hooks = {
		send = function(viewer, batch)
			table.insert(log.sends, { viewer = viewer.userId, batch = batch })
		end,
		visibility = function(viewer, subject, entered)
			table.insert(if entered then log.enters else log.leaves, { viewer = viewer.userId, subject = subject.userId })
		end,
	}
	return log, hooks
end

local function slotsIn(batch)
	local header = Codec.readHeader(batch, 0)
	local out = {}
	for i = 1, header.count do
		table.insert(out, Codec.readRecord(batch, Codec.HEADER_BYTES + (i - 1) * Codec.RECORD_BYTES).slot)
	end
	return out
end

local function sendsTo(log, userId)
	local out = {}
	for _, s in log.sends do
		if s.viewer == userId then
			table.insert(out, s.batch)
		end
	end
	return out
end

local function world(...)
	local w = Fanout.newWorld()
	for _, b in { ... } do
		Fanout.addBody(w, b)
	end
	return w
end

return function()
	it("relays a moving body to a nearby viewer every frame, after one enter each way", function()
		local a, v = body(1, 1, ORIGIN), body(2, 2, ORIGIN + Vector3.new(50, 0, 0))
		local w = world(a, v)
		local log, hooks = recorder()
		for frame = 1, 5 do
			feed(a, frame * 17, ORIGIN + Vector3.new(frame * 0.3, 0, 0))
			Fanout.step(w, frame * 17, hooks)
		end
		expect(#log.enters).to.equal(2)
		local batches = sendsTo(log, 2)
		expect(#batches).to.equal(5)
		for _, batch in batches do
			expect(slotsIn(batch)[1]).to.equal(1)
		end
	end)

	it("never sends a viewer its own body", function()
		local a, v = body(1, 1, ORIGIN), body(2, 2, ORIGIN + Vector3.new(50, 0, 0))
		local w = world(a, v)
		local log, hooks = recorder()
		feed(a, 17, ORIGIN)
		Fanout.step(w, 17, hooks)
		expect(#sendsTo(log, 1)).to.equal(0)
	end)

	it("encodes each body once per frame: two viewers get identical bytes", function()
		local a = body(1, 1, ORIGIN)
		local v1, v2 = body(2, 2, ORIGIN + Vector3.new(30, 0, 0)), body(3, 3, ORIGIN + Vector3.new(0, 0, 30))
		local w = world(a, v1, v2)
		local log, hooks = recorder()
		feed(a, 17, ORIGIN)
		Fanout.step(w, 17, hooks)
		local b1, b2 = sendsTo(log, 2)[1], sendsTo(log, 3)[1]
		expect(buffer.readstring(b1, 0, buffer.len(b1))).to.equal(buffer.readstring(b2, 0, buffer.len(b2)))
	end)

	it("enters at 600 studs and leaves past 630, once each", function()
		local a, v = body(1, 1, ORIGIN + Vector3.new(700, 0, 0)), body(2, 2, ORIGIN)
		local w = world(a, v)
		local log, hooks = recorder()
		for frame, distance in { 700, 590, 615, 625, 640, 620, 595 } do
			feed(a, frame * 17, ORIGIN + Vector3.new(distance, 0, 0))
			Fanout.step(w, frame * 17, hooks)
		end
		local enters, leaves = 0, 0
		for _, e in log.enters do
			if e.viewer == 2 then
				enters += 1
			end
		end
		for _, l in log.leaves do
			if l.viewer == 2 then
				leaves += 1
			end
		end
		expect(enters).to.equal(2)
		expect(leaves).to.equal(1)
	end)

	it("sends a still body only on change, its two resends and the 1 Hz repair", function()
		local a, v = body(1, 1, ORIGIN), body(2, 2, ORIGIN + Vector3.new(50, 0, 0))
		local w = world(a, v)
		local log, hooks = recorder()
		feed(a, 0, ORIGIN)
		for frame = 1, 72 do -- 1.2 s
			Fanout.step(w, frame * 1000 / 60, hooks)
		end
		expect(#sendsTo(log, 2)).to.equal(4)
	end)

	it("gives a viewer nothing until it is ready", function()
		local a, v = body(1, 1, ORIGIN), body(2, 2, ORIGIN + Vector3.new(50, 0, 0))
		v.ready = false
		local w = world(a, v)
		local log, hooks = recorder()
		feed(a, 17, ORIGIN)
		Fanout.step(w, 17, hooks)
		expect(#sendsTo(log, 2)).to.equal(0)
		for _, e in log.enters do
			expect(e.viewer).never.to.equal(2)
		end
	end)

	it("takes a body that died out of every viewer", function()
		local a, v = body(1, 1, ORIGIN), body(2, 2, ORIGIN + Vector3.new(50, 0, 0))
		local w = world(a, v)
		local log, hooks = recorder()
		feed(a, 17, ORIGIN)
		Fanout.step(w, 17, hooks)
		a.alive = false
		Fanout.step(w, 34, hooks)
		expect(#log.leaves).to.equal(1)
		expect(log.leaves[1].viewer).to.equal(2)
		expect(log.leaves[1].subject).to.equal(1)
	end)

	it("removeBody fires a leave for each viewer that had the body", function()
		local a = body(1, 1, ORIGIN)
		local v1, v2 = body(2, 2, ORIGIN + Vector3.new(30, 0, 0)), body(3, 3, ORIGIN + Vector3.new(0, 0, 30))
		local w = world(a, v1, v2)
		local log, hooks = recorder()
		feed(a, 17, ORIGIN)
		Fanout.step(w, 17, hooks)
		expect(Fanout.removeBody(w, 1, hooks)).to.equal(a)
		local fromA = 0
		for _, l in log.leaves do
			if l.subject == 1 then
				fromA += 1
			end
		end
		expect(fromA).to.equal(2)
		expect(w.bodies[1]).to.equal(nil)
	end)

	it("setMaxHealth clamps health down, never heals, and refuses nonsense", function()
		local a = body(1, 1, ORIGIN)
		expect(Fanout.setMaxHealth(a, 210)).to.equal(true)
		expect(a.maxHealth).to.equal(210)
		expect(a.health).to.equal(100)
		expect(Fanout.setMaxHealth(a, 50)).to.equal(true)
		expect(a.health).to.equal(50)
		expect(Fanout.setMaxHealth(a, 0 / 0)).to.equal(false)
		expect(Fanout.setMaxHealth(a, 0)).to.equal(false)
		expect(Fanout.setMaxHealth(a, math.huge)).to.equal(false)
		expect(a.maxHealth).to.equal(50)
		Fanout.respawned(a)
		expect(a.health).to.equal(50)
	end)

	it("enterRecord synthesises a still record at the spawn point before any uplink", function()
		local a = body(1, 1, ORIGIN + Vector3.new(5, 0, 0))
		local record, sampleMs = Fanout.enterRecord(a, 1234)
		expect(sampleMs).to.equal(1234)
		expect(record.position).to.equal(ORIGIN + Vector3.new(5, 0, 0))
		expect(record.velocity).to.equal(Vector3.zero)
		feed(a, 1300, ORIGIN)
		local latest, latestMs = Fanout.enterRecord(a, 1400)
		expect(latest).to.equal(a.ingest.latest)
		expect(latestMs).to.equal(1300)
	end)
end
```

- [ ] **Step 2: Run the tests and verify they fail**

Studio test run. Expected: `ReplicationFanout.spec` fails at `require`.

- [ ] **Step 3: Write `ReplicationFanout.luau`**

```luau
--!strict
--[=[
	ReplicationFanout: one server frame of the downlink (spec §6.4, §6.5; plan R2 Task 7).

	1. Every live body's send policy decides ONCE whether its newest accepted sample goes out this frame
	   (change / resend / repair — the v3 policy the Verdict chose).
	2. For every ready, live viewer: distance visibility is updated against every other live body (600 /
	   630 studs; `hooks.visibility` reports enter and leave — the shell sends the reliable full-state
	   record and updates the public-data relevant set), and the bodies it has loaded that are due —
	   scheduled by their policy, or pending from a frame where they were not sent — are handed to
	   `DownlinkScheduler.pack` with their distances: its priority accumulator and far cap pick what fits
	   under the 700 B cap and the 24 KB/s budget.
	3. Encode once: a due body is encoded at most once per frame with the frame time as batch time, so every
	   viewer receives the same bytes for it.

	A viewer never receives its own body. Pure: no Instances, no services; time is server session ms.

	@class ReplicationFanout
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Replication = ReplicatedStorage.Shared.Modules.CharacterReplication
local CharacterRecordCodec = require(Replication.CharacterRecordCodec)
local SendPolicy = require(Replication.SendPolicy)
local UplinkIngest = require(script.Parent.UplinkIngest)
local ReplicationSlots = require(script.Parent.ReplicationSlots)
local VisibilitySet = require(script.Parent.VisibilitySet)
local DownlinkScheduler = require(script.Parent.DownlinkScheduler)

local ReplicationFanout = {}

local DEFAULT_MAX_HEALTH = 100
ReplicationFanout.DEFAULT_MAX_HEALTH = DEFAULT_MAX_HEALTH

export type Body = {
	userId: number,
	slot: number,
	generation: number,
	epoch: ReplicationSlots.Epoch,
	ready: boolean, -- the client finished the handshake and can receive
	alive: boolean, -- has a spawned body
	position: Vector3, -- newest accepted position, or the spawn point
	ingest: UplinkIngest.State,
	policy: SendPolicy.Policy,
	lastSent: CharacterRecordCodec.Record?,
	scheduled: boolean, -- the send policy picked this body this frame
	frameBytes: buffer, -- this body's encoding, reused every frame
	visibility: VisibilitySet.Set, -- as a viewer: the bodies it has loaded
	viewer: DownlinkScheduler.Viewer,
	relevant: { [number]: boolean }, -- userIds whose public data this viewer may see (loaded + self)
	health: number,
	maxHealth: number,
}

export type World = {
	bodies: { [number]: Body }, -- by slot
	candidates: { number }, -- scratch, reused per viewer
	distances: { number }, -- scratch, parallel to `candidates`: studs from the viewer
	bytes: { [number]: buffer }, -- slot → that body's frameBytes
	lengths: { [number]: number }, -- slot → bytes encoded this frame (0 = not yet)
}

export type Hooks = {
	send: (viewer: Body, batch: buffer) -> (),
	visibility: (viewer: Body, subject: Body, entered: boolean) -> (),
}

function ReplicationFanout.newWorld(): World
	return { bodies = {}, candidates = {}, distances = {}, bytes = {}, lengths = {} }
end

function ReplicationFanout.newBody(userId: number, slot: number, generation: number, position: Vector3): Body
	return {
		userId = userId,
		slot = slot,
		generation = generation,
		epoch = ReplicationSlots.newEpoch(),
		ready = false,
		alive = false,
		position = position,
		ingest = UplinkIngest.new(),
		policy = SendPolicy.new(),
		lastSent = nil,
		scheduled = false,
		frameBytes = buffer.create(DownlinkScheduler.SCRATCH_BYTES),
		visibility = VisibilitySet.new(),
		viewer = DownlinkScheduler.newViewer(),
		relevant = { [userId] = true },
		health = DEFAULT_MAX_HEALTH,
		maxHealth = DEFAULT_MAX_HEALTH,
	}
end

function ReplicationFanout.addBody(world: World, body: Body)
	world.bodies[body.slot] = body
	world.bytes[body.slot] = body.frameBytes
	world.lengths[body.slot] = 0
end

--[=[
	Remove a body (its player left). Every viewer that had it loaded gets a leave first.
]=]
function ReplicationFanout.removeBody(world: World, slot: number, hooks: Hooks): Body?
	local subject = world.bodies[slot]
	if subject == nil then
		return nil
	end
	for _, viewer in world.bodies do
		if viewer ~= subject and VisibilitySet.remove(viewer.visibility, slot) then
			DownlinkScheduler.forget(viewer.viewer, slot)
			hooks.visibility(viewer, subject, false)
		end
	end
	world.bodies[slot] = nil
	world.bytes[slot] = nil
	world.lengths[slot] = nil
	return subject
end

--[=[
	A new body after a successful epoch bump: alive, full health, a fresh send policy, and ingest reset to
	the new epoch (samples from the previous body are dropped from here on).
]=]
function ReplicationFanout.respawned(body: Body)
	body.alive = true
	body.health = body.maxHealth
	body.policy = SendPolicy.new()
	body.lastSent = nil
	body.scheduled = false
	UplinkIngest.reset(body.ingest, body.epoch.value)
end

-- A viewer starting the stream again (a repeated handshake): nothing loaded, nothing owed.
function ReplicationFanout.resetViewer(body: Body)
	body.visibility = VisibilitySet.new()
	body.viewer = DownlinkScheduler.newViewer()
	body.relevant = { [body.userId] = true }
end

--[=[
	Apply a new maximum health. Current health is clamped DOWN to it, never healed up. Refuses NaN,
	non-positive and infinite values (returns false, nothing changes).
]=]
function ReplicationFanout.setMaxHealth(body: Body, maxHealth: number): boolean
	if maxHealth ~= maxHealth or maxHealth <= 0 or maxHealth == math.huge then
		return false
	end
	body.maxHealth = maxHealth
	if body.health > maxHealth then
		body.health = maxHealth
	end
	return true
end

--[=[
	The full-state record a viewer gets when `subject` enters its set (spec §6.4 "entering relevance"): the
	newest accepted sample, or — before the first uplink of a fresh body — a still record at the spawn point.
]=]
function ReplicationFanout.enterRecord(subject: Body, nowMs: number): (CharacterRecordCodec.Record, number)
	local latest = subject.ingest.latest
	if latest ~= nil then
		return latest, subject.ingest.latestMs
	end
	return {
		slot = subject.slot,
		generation = subject.generation,
		epoch = subject.epoch.value,
		ageMs = 0,
		position = subject.position,
		yaw = 0,
		pitch = 0,
		velocity = Vector3.zero,
		state = Enum.HumanoidStateType.Running.Value,
		grounded = true,
		hasAction = false,
		rotation = nil,
	},
		nowMs
end

local function ensureEncoded(world: World, subject: Body, nowMs: number)
	local latest = subject.ingest.latest
	if latest ~= nil and world.lengths[subject.slot] == 0 then
		world.lengths[subject.slot] = DownlinkScheduler.encode(
			subject.frameBytes,
			subject.slot,
			subject.generation,
			subject.epoch.value,
			latest,
			subject.ingest.latestMs,
			nowMs
		)
	end
end

--[=[
	Run one frame. Returns how many batches were handed to `hooks.send`.
]=]
function ReplicationFanout.step(world: World, nowMs: number, hooks: Hooks): number
	local bodies = world.bodies
	local lengths = world.lengths

	for slot, subject in bodies do
		lengths[slot] = 0
		subject.scheduled = false
		local latest = subject.ingest.latest
		if subject.alive and latest ~= nil then
			local changed = subject.ingest.fresh and SendPolicy.changed(subject.lastSent, latest)
			subject.ingest.fresh = false
			if SendPolicy.decide(subject.policy, nowMs, changed) ~= nil then
				subject.scheduled = true
				subject.lastSent = latest
			end
		end
	end

	local sent = 0
	local candidates = world.candidates
	local distances = world.distances
	for _, viewer in bodies do
		if not (viewer.ready and viewer.alive) then
			continue
		end
		table.clear(candidates)
		table.clear(distances)
		local pending = viewer.viewer.pending
		for slot, subject in bodies do
			if subject == viewer then
				continue
			end
			local change: VisibilitySet.Change? = nil
			if subject.alive then
				change = VisibilitySet.update(viewer.visibility, viewer.position, slot, subject.position)
			elseif VisibilitySet.remove(viewer.visibility, slot) then
				change = "left"
			end
			if change == "entered" then
				hooks.visibility(viewer, subject, true)
			elseif change == "left" then
				DownlinkScheduler.forget(viewer.viewer, slot)
				hooks.visibility(viewer, subject, false)
			end
			if
				VisibilitySet.has(viewer.visibility, slot)
				and subject.ingest.latest ~= nil
				and (subject.scheduled or pending[slot] == true)
			then
				ensureEncoded(world, subject, nowMs)
				table.insert(candidates, slot)
				table.insert(distances, (subject.position - viewer.position).Magnitude)
			end
		end
		local batch = DownlinkScheduler.pack(viewer.viewer, nowMs, candidates, world.bytes, lengths, distances)
		if batch ~= nil then
			hooks.send(viewer, batch)
			sent += 1
		end
	end
	return sent
end

return ReplicationFanout
```

- [ ] **Step 4: Run the tests and verify they pass**

Studio test run: `ReplicationFanout.spec` passes; suite green. Format, Lint, Typecheck clean.

- [ ] **Step 5: Commit**

```bash
git add src/ServerScriptService/Services/CharacterReplicationService/ReplicationFanout.luau src/ServerScriptService/Services/CharacterReplicationService/ReplicationFanout.spec.luau
git commit -m "feat(replication): per-frame fan-out with visibility, send policy and encode once

Each body's send policy decides once per frame; each ready viewer updates distance visibility
(enter/leave hooks) and gets one batch of its due bodies, encoded once and packed under the cap by
the scheduler's priority accumulator (distances passed per candidate).
Bodies carry server-owned health with a clamp-down maximum."
```

---
### Task 8: The public slice — other players' public data on charm-sync, filtered by relevance

**Runtime behaviour: yes** — every client gets one more charm-sync key (`publicPlayers:<userId>`). It stays an empty map until Task 9's service writes entries and relevant sets.

**Files:**
- Create: `src/ReplicatedStorage/Shared/Types/PublicPlayerTypes.luau`
- Modify: `src/ReplicatedStorage/Shared/State/SyncState.luau` and `SyncState.spec.luau`
- Create: `src/ServerScriptService/State/PublicPlayerState.spec.luau`
- Create: `src/ServerScriptService/State/PublicPlayerState.luau`
- Modify: `src/ReplicatedStorage/Client/State/ClientStore.luau`
- Modify: `src/ServerScriptService/Services/StateSyncService/StateSyncServiceServer.luau:103-116` and its spec
- Modify: `src/ReplicatedStorage/Client/Services/StateSyncService/StateSyncServiceClient.luau:44-50`

**Interfaces:**
- Consumes: Charm (`atom`, `effect`, `subscribe`), charm-sync (getters are wrapped in `Charm.effect`, so a getter re-runs whenever an atom it read changes).
- Produces:
  - `PublicPlayerTypes.PublicPlayer = { health: number, maxHealth: number }`, `PublicPlayerTypes.PublicPlayerMap = { [string]: PublicPlayer }`
  - `SyncState.PUBLIC_SLICE` (`"publicPlayers"`), `SyncState.publicKey(viewerUserId: number): string`, `SyncState.publicEntryKey(userId: number): string`
  - `PublicPlayerState.set(userId: number, entry: PublicPlayer)`, `remove(userId: number)`, `get(userId: number): PublicPlayer?`
  - `PublicPlayerState.setRelevant(viewerUserId: number, userIds: { number })`, `relevantOf(viewerUserId: number): { number }`
  - `PublicPlayerState.getterFor(viewerUserId: number): () -> PublicPlayerMap`
  - `ClientStore.publicPlayers: Charm.Atom<PublicPlayerMap>` (also served by `ClientStore.setterFor("publicPlayers")`)

- [ ] **Step 1: Write the failing specs**

Append to `src/ReplicatedStorage/Shared/State/SyncState.spec.luau` (inside the returned function):

```luau
	describe("public slice keys", function()
		it("builds the per-viewer charm-sync key from the public slice name", function()
			expect(SyncState.PUBLIC_SLICE).to.equal("publicPlayers")
			expect(SyncState.publicKey(123)).to.equal("publicPlayers:123")
		end)

		it("never collides with a profile slice", function()
			expect(table.find(SyncState.SLICES, SyncState.PUBLIC_SLICE)).to.equal(nil)
		end)

		it("keys map entries by the userId as a string", function()
			expect(SyncState.publicEntryKey(456)).to.equal("456")
		end)
	end)
```

`src/ServerScriptService/State/PublicPlayerState.spec.luau`:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local PublicPlayerState = require(script.Parent.PublicPlayerState)

local VIEWER, A, B, C = 970001, 970002, 970003, 970004

return function()
	afterEach(function()
		for _, userId in { VIEWER, A, B, C } do
			PublicPlayerState.remove(userId)
		end
	end)

	it("serves only the entries in the viewer's relevant set, keyed by string userId", function()
		PublicPlayerState.set(A, { health = 80, maxHealth = 100 })
		PublicPlayerState.set(B, { health = 50, maxHealth = 200 })
		PublicPlayerState.setRelevant(VIEWER, { A })
		local map = PublicPlayerState.getterFor(VIEWER)()
		expect(map[tostring(A)].health).to.equal(80)
		expect(map[tostring(B)]).to.equal(nil)
	end)

	it("follows relevant-set changes", function()
		PublicPlayerState.set(A, { health = 80, maxHealth = 100 })
		PublicPlayerState.set(B, { health = 50, maxHealth = 200 })
		local getter = PublicPlayerState.getterFor(VIEWER)
		PublicPlayerState.setRelevant(VIEWER, { A, B })
		expect(getter()[tostring(B)].maxHealth).to.equal(200)
		PublicPlayerState.setRelevant(VIEWER, { B })
		expect(getter()[tostring(A)]).to.equal(nil)
	end)

	it("re-runs a viewer's getter for relevant changes only, never for irrelevant players", function()
		PublicPlayerState.set(A, { health = 80, maxHealth = 100 })
		PublicPlayerState.set(C, { health = 10, maxHealth = 100 })
		PublicPlayerState.setRelevant(VIEWER, { A })
		local getter = PublicPlayerState.getterFor(VIEWER)
		local runs = 0
		local dispose = Charm.effect(function()
			getter()
			runs += 1
		end)
		local baseline = runs
		PublicPlayerState.set(C, { health = 20, maxHealth = 100 }) -- not relevant to VIEWER
		expect(runs).to.equal(baseline)
		PublicPlayerState.set(A, { health = 70, maxHealth = 100 })
		expect(runs).to.equal(baseline + 1)
		PublicPlayerState.setRelevant(VIEWER, { A, C })
		expect(runs).to.equal(baseline + 2)
		dispose()
	end)

	it("snapshots an entry: mutating the source afterwards changes nothing", function()
		local source = { health = 80, maxHealth = 100 }
		PublicPlayerState.set(A, source)
		source.health = 1
		expect(PublicPlayerState.get(A).health).to.equal(80)
	end)

	it("remove drops the entry and the player's own relevant set", function()
		PublicPlayerState.set(A, { health = 80, maxHealth = 100 })
		PublicPlayerState.setRelevant(VIEWER, { A })
		PublicPlayerState.setRelevant(A, { A })
		PublicPlayerState.remove(A)
		expect(PublicPlayerState.get(A)).to.equal(nil)
		expect(PublicPlayerState.getterFor(VIEWER)()[tostring(A)]).to.equal(nil)
		expect(#PublicPlayerState.relevantOf(A)).to.equal(0)
	end)
end
```

In `src/ServerScriptService/Services/StateSyncService/StateSyncServiceServer.spec.luau`, replace the test `"registers one getter per manifest slice, keyed to the reporting player's UserId"` with:

```luau
			it("registers one getter per manifest slice plus the public slice, keyed to the reporting player", function()
				StateSyncService:init()
				StateSyncService:_simulateClientReadyForTesting(fakePlayer(910001))

				expect(#addSignalsCalls).to.equal(1)
				local getters = addSignalsCalls[1].getters

				local keyCount = 0
				for _ in getters do
					keyCount += 1
				end
				expect(keyCount).to.equal(#SliceManifest.NAMES + 1)

				for _, slice in SliceManifest.NAMES do
					expect(getters[SyncState.key(slice, 910001)]).to.be.ok()
				end
				expect(getters[SyncState.publicKey(910001)]).to.be.ok()
			end)
```

- [ ] **Step 2: Run the tests and verify they fail**

Studio test run. Expected failures: `public slice keys` (nil fields), `PublicPlayerState.spec` (module missing), and the rewritten StateSync key-count test (counts `#NAMES`).

- [ ] **Step 3: Write the shared type and keys**

`src/ReplicatedStorage/Shared/Types/PublicPlayerTypes.luau`:

```luau
--!strict
--[=[
	PublicPlayerTypes: what any client may know about another player (spec Verdict, "Other players' public
	data rides charm-sync"; plan R2 Task 8). Never private data. R2 carries health; appearance and the
	equipped title join in R4.

	The map is keyed by the userId as a STRING (`SyncState.publicEntryKey`): charm-sync ships it through a
	RemoteEvent, and string keys keep it a plain dictionary on the wire.

	@class PublicPlayerTypes
]=]

export type PublicPlayer = {
	health: number,
	maxHealth: number,
}

export type PublicPlayerMap = { [string]: PublicPlayer }

return {}
```

In `src/ReplicatedStorage/Shared/State/SyncState.luau`, add before `return SyncState`:

```luau
--[=[
	The public slice (other players' public data, `PublicPlayerState` on the server, `ClientStore.publicPlayers`
	on the client). Not a profile slice, so it is not in `SLICES`: each client syncs ONE key holding the map of
	players relevant to it.
]=]
SyncState.PUBLIC_SLICE = "publicPlayers"

function SyncState.publicKey(viewerUserId: number): string
	return SyncState.key(SyncState.PUBLIC_SLICE, viewerUserId)
end

-- The public map's key for one player.
function SyncState.publicEntryKey(userId: number): string
	return tostring(userId)
end
```

- [ ] **Step 4: Write `PublicPlayerState.luau`**

```luau
--!strict
--[=[
	PublicPlayerState: the server half of the public slice (spec Verdict, "Other players' public data rides
	charm-sync"; plan R2 Task 8).

	- One atom PER PLAYER for their public entry, and one atom PER VIEWER for the set of players relevant to
	  them (the bodies they have loaded, plus themselves — maintained by CharacterReplicationServiceServer,
	  changed only on enter/leave).
	- `getterFor(viewer)` is the charm-sync getter for `SyncState.publicKey(viewer)`. charm-sync runs getters
	  inside `Charm.effect`, so the getter re-runs exactly when the viewer's relevant set changes or the entry
	  of a player IN that set changes — never for players the viewer cannot see, and never for movement.
	- Entries are frozen snapshots: a write replaces the entry (new identity, so charm sees a change) and a
	  caller mutating its table afterwards changes nothing.

	@class PublicPlayerState
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local PublicPlayerTypes = require(ReplicatedStorage.Shared.Types.PublicPlayerTypes)
local SyncState = require(ReplicatedStorage.Shared.State.SyncState)

type PublicPlayer = PublicPlayerTypes.PublicPlayer
type PublicPlayerMap = PublicPlayerTypes.PublicPlayerMap

local entries: { [number]: Charm.Atom<PublicPlayer?> } = {}
local relevant: { [number]: Charm.Atom<{ number }> } = {}

local PublicPlayerState = {}

local function entryAtom(userId: number): Charm.Atom<PublicPlayer?>
	local atom = entries[userId]
	if atom == nil then
		local initial: PublicPlayer? = nil
		atom = Charm.atom(initial)
		entries[userId] = atom
	end
	return atom
end

local function relevantAtom(viewerUserId: number): Charm.Atom<{ number }>
	local atom = relevant[viewerUserId]
	if atom == nil then
		local initial: { number } = {}
		atom = Charm.atom(initial)
		relevant[viewerUserId] = atom
	end
	return atom
end

function PublicPlayerState.set(userId: number, entry: PublicPlayer)
	local snapshot: PublicPlayer = { health = entry.health, maxHealth = entry.maxHealth }
	entryAtom(userId)(table.freeze(snapshot))
end

function PublicPlayerState.get(userId: number): PublicPlayer?
	local atom = entries[userId]
	return if atom ~= nil then atom() else nil
end

--[=[
	The player left: their entry and their own relevant set go. Viewers that still list them (none, once the
	replication service has processed the leave) would simply read nothing.
]=]
function PublicPlayerState.remove(userId: number)
	local atom = entries[userId]
	if atom ~= nil then
		atom(nil)
		entries[userId] = nil
	end
	local viewerAtom = relevant[userId]
	if viewerAtom ~= nil then
		local empty: { number } = {}
		viewerAtom(empty)
		relevant[userId] = nil
	end
end

--[=[
	Replace a viewer's relevant set (sorted, frozen copy). Called only on enter/leave.
]=]
function PublicPlayerState.setRelevant(viewerUserId: number, userIds: { number })
	local copy = table.clone(userIds)
	table.sort(copy)
	relevantAtom(viewerUserId)(table.freeze(copy))
end

function PublicPlayerState.relevantOf(viewerUserId: number): { number }
	local atom = relevant[viewerUserId]
	return if atom ~= nil then atom() else {}
end

--[=[
	The charm-sync getter for one viewer's public map.
]=]
function PublicPlayerState.getterFor(viewerUserId: number): () -> PublicPlayerMap
	local viewerAtom = relevantAtom(viewerUserId)
	return function(): PublicPlayerMap
		local result: PublicPlayerMap = {}
		for _, userId in viewerAtom() do
			local entry = entryAtom(userId)()
			if entry ~= nil then
				result[SyncState.publicEntryKey(userId)] = entry
			end
		end
		return result
	end
end

return PublicPlayerState
```

- [ ] **Step 5: Wire the client atom and both transports**

In `src/ReplicatedStorage/Client/State/ClientStore.luau`:

Add the require after `local SyncState = ...`:

```luau
local PublicPlayerTypes = require(ReplicatedStorage.Shared.Types.PublicPlayerTypes)
```

After the `entitlements` atom declaration, add:

```luau
-- The public slice: other players' public data, already filtered by the server to the players relevant
-- to this client (plus this client itself). Not a profile slice; synced under SyncState.publicKey.
local initialPublicPlayers: PublicPlayerTypes.PublicPlayerMap = {}
local publicPlayers = Charm.atom(initialPublicPlayers)
```

Add `publicPlayers = publicPlayers,` to the `ClientStore` table literal and to the `atoms` registry literal (after `entitlements = entitlements,` in each). The boot assert only checks that every manifest slice has an atom, so the extra registry key is allowed; it makes `ClientStore.setterFor(SyncState.PUBLIC_SLICE)` serve it through the same documented boundary.

In `src/ServerScriptService/Services/StateSyncService/StateSyncServiceServer.luau`, add the require after `local ServerStore = ...`:

```luau
local PublicPlayerState = require(ServerScriptService.State.PublicPlayerState)
```

and inside the ready handler, after the `for _, slice in SyncState.SLICES do ... end` loop and before `server.addSignalsToClient(player, getters)`:

```luau
				-- The public slice: one key per client, holding the players relevant to it (PublicPlayerState).
				getters[SyncState.publicKey(player.UserId)] = PublicPlayerState.getterFor(player.UserId)
```

In `src/ReplicatedStorage/Client/Services/StateSyncService/StateSyncServiceClient.luau`, after the `for _, slice in SyncState.SLICES do ... end` loop and before `client.addSignals(setters)`:

```luau
		setters[SyncState.publicKey(userId)] = ClientStore.setterFor(SyncState.PUBLIC_SLICE)
```

- [ ] **Step 6: Run the tests and verify they pass**

Studio test run: `SyncState`, `PublicPlayerState` and `StateSyncServiceServer` specs pass; suite green. Format, Lint, Typecheck, File length clean.

- [ ] **Step 7: Commit**

```bash
git add src/ReplicatedStorage/Shared/Types/PublicPlayerTypes.luau src/ReplicatedStorage/Shared/State/SyncState.luau src/ReplicatedStorage/Shared/State/SyncState.spec.luau src/ServerScriptService/State/PublicPlayerState.luau src/ServerScriptService/State/PublicPlayerState.spec.luau src/ReplicatedStorage/Client/State/ClientStore.luau src/ServerScriptService/Services/StateSyncService/StateSyncServiceServer.luau src/ServerScriptService/Services/StateSyncService/StateSyncServiceServer.spec.luau src/ReplicatedStorage/Client/Services/StateSyncService/StateSyncServiceClient.luau
git commit -m "feat(state): public slice of other players' data, filtered by each viewer's relevant set

Per-player entry atoms and per-viewer relevant-set atoms; each client syncs one publicPlayers key whose
getter re-runs only when its relevant set or a relevant player's entry changes."
```

---
### Task 9: Events namespace and `CharacterReplicationServiceServer`

**Runtime behaviour: yes** — `CharacterAutoLoads` goes off (Rojo property node, plus a loud runtime guard): from this task until Task 10 lands, a play session has **no body at all**. The server publishes the rig template, creates per-player focus parts in a non-replicating container, and waits for clients' `Ready`.

**Files:**
- Create: `src/ReplicatedStorage/Shared/Events/CharacterReplicationEvents.luau`
- Create: `src/ServerScriptService/Services/CharacterReplicationService/ReplicationInstances.luau`
- Create: `src/ServerScriptService/Services/CharacterReplicationService/ReplicationPackets.luau`
- Create: `src/ServerScriptService/Services/CharacterReplicationService/CharacterReplicationServiceServer.luau`
- Modify: `default.project.json` (add the property-only `Players` node)
- Modify: `src/ServerScriptService/Modules/SpecRoots.luau` (`EXEMPT_MODULES`)

**Interfaces:**
- Consumes: Tasks 1–8 (`UplinkPipeline.wrap`, `UplinkIngest`, `ReplicationSlots`, `DownlinkScheduler.encode`, `ReplicationFanout.*`, `PublicPlayerState.*`), `SignalTyped`, Janitor, Observers.
- Produces (packets — names and payload shapes are the contract Tasks 10 and 11 consume):
  - `Uplink`: `buffer`, unreliable, client → server
  - `Downlink`: `buffer`, unreliable, server → client (a batch)
  - `Ready`: `boolean`, reliable, client → server (handshake; the value is ignored)
  - `RespawnRequest`: `boolean`, reliable, client → server (the owner fell through the fall plane)
  - `Session`: `{ epochSeconds: number }` (float64), reliable
  - `SlotEntry`: `{ slot: number, userId: number, generation: number, epoch: number, active: boolean }` (uint8 / float64 / uint8 / uint8 / bool), reliable
  - `Spawn`: `{ position: Vector3, epoch: number }`, reliable, to the owner
  - `Enter`: `{ slot: number, generation: number, batchTimeMs: number, record: buffer }` (uint8 / uint8 / uint32 / 16 B), reliable
  - `Leave`: `{ slot: number, generation: number }`, reliable
- Produces (service API, documented in `docs/architecture.md` by Task 12):
  - `CharacterReplicationServiceServer.bodySpawned: SignalTyped.Signal<Player, number>` (player, epoch)
  - `CharacterReplicationServiceServer.bodyDespawned: SignalTyped.Signal<Player, number>`
  - `:observeBodies(callback: (player: Player, epoch: number) -> (() -> ())?): () -> ()`
  - `:hasBody(player: Player): boolean`, `:getBodyPosition(player: Player): Vector3?`
  - `:respawn(player: Player, reason: string): boolean`
  - `:setMaxHealth(userId: number, maxHealth: number)`
  - `:getState(): { [string]: any }`
  - `ReplicatedStorage.CharacterRigTemplate` (Model, scripts stripped)
  - `ReplicationInstances.TEMPLATE_NAME` (`"CharacterRigTemplate"`), `publishRigTemplate(): Instance`, `createFocusHolder(): (Folder, Camera)`, `createFocus(holder: Camera, position: Vector3): Part`, `spawnPoint(): Vector3`
  - `export type ReplicationPackets.Handlers = { uplink: (data: buffer, player: Player) -> any, ready: (player: Player) -> (), respawnRequest: (player: Player) -> () }`, `ReplicationPackets.connect(handlers: Handlers)`, `ReplicationPackets.disconnect()`

- [ ] **Step 1: Add the Rojo property node**

In `default.project.json`, add a `Players` node next to `SoundService` (property-only: no `$path`, so it manages exactly this property and nothing else):

```json
    "Players": {
      "$properties": {
        "CharacterAutoLoads": false
      }
    },
```

- [ ] **Step 2: Write the events namespace**

`src/ReplicatedStorage/Shared/Events/CharacterReplicationEvents.luau`:

```luau
--!strict
--[=[
	CharacterReplicationEvents: the ByteNet contract for client-only bodies (spec 2026-09-22 §6.1, C7; plan
	R2 Task 9). The repo's first UNRELIABLE packets: continuous, high-rate, per-viewer motion is neither
	queryable state (charm-sync) nor a one-off event — see docs/architecture.md, Networking.

	Unreliable (single `buff` payload):
	- `Uplink`   owner → server: `u32 sentMs · u8 count · records` (CharacterUplinkCodec).
	- `Downlink` server → viewer: one batch per viewer per frame (header + records, ≤ 700 B).

	Reliable (typed structs):
	- `Ready`          client → server once its listeners are connected; the server answers with `Session`,
	                   the whole slot table, and (on join) a `Spawn`.
	- `RespawnRequest` client → server: the owner rig fell through the fall plane.
	- `Session`        the session time epoch (seconds): every time on the wire is ms since it.
	- `SlotEntry`      one row of the slot table: slot → userId, generation, full 8-bit epoch, active. Sent to
	                   everyone on claim, epoch bump and release; the reliable epoch resets a viewer that missed
	                   a bump.
	- `Spawn`          to the owner: build your rig here, in this epoch.
	- `Enter`/`Leave`  to a viewer: a body entered / left its visibility set. `Enter` carries a full-state
	                   record (age relative to `batchTimeMs`) so the body can be placed at once.

	Boot timing: the client waits for the namespace value the server creates when it requires this module
	(same guard as DebuggerEvents).

	@class CharacterReplicationEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "CharacterReplicationEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local CharacterReplicationEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			Uplink = ByteNet.definePacket({
				value = ByteNet.buff,
				reliabilityType = "unreliable",
			}),
			Downlink = ByteNet.definePacket({
				value = ByteNet.buff,
				reliabilityType = "unreliable",
			}),
			Ready = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
			RespawnRequest = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
			Session = ByteNet.definePacket({
				value = ByteNet.struct({
					epochSeconds = ByteNet.float64,
				}),
				reliabilityType = "reliable",
			}),
			SlotEntry = ByteNet.definePacket({
				value = ByteNet.struct({
					slot = ByteNet.uint8,
					userId = ByteNet.float64,
					generation = ByteNet.uint8,
					epoch = ByteNet.uint8,
					active = ByteNet.bool,
				}),
				reliabilityType = "reliable",
			}),
			Spawn = ByteNet.definePacket({
				value = ByteNet.struct({
					position = ByteNet.vec3,
					epoch = ByteNet.uint8,
				}),
				reliabilityType = "reliable",
			}),
			Enter = ByteNet.definePacket({
				value = ByteNet.struct({
					slot = ByteNet.uint8,
					generation = ByteNet.uint8,
					batchTimeMs = ByteNet.uint32,
					record = ByteNet.buff,
				}),
				reliabilityType = "reliable",
			}),
			Leave = ByteNet.definePacket({
				value = ByteNet.struct({
					slot = ByteNet.uint8,
					generation = ByteNet.uint8,
				}),
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return CharacterReplicationEvents
```

- [ ] **Step 3: Write `ReplicationInstances.luau`**

```luau
--!strict
--[=[
	ReplicationInstances: the Instances the replication server owns (plan R2 Task 9) — the published rig
	template, the non-replicating focus container and per-player focus parts — and the spawn point. Kept
	apart so CharacterReplicationServiceServer stays a small shell.

	Spec-exempt shell (Instances).

	@class ReplicationInstances
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local ReplicationInstances = {}

ReplicationInstances.TEMPLATE_NAME = "CharacterRigTemplate"

-- The live map's spawn area, measured in the spike (CP1): used only when the place has no SpawnLocation.
local FALLBACK_SPAWN = Vector3.new(-1028, 80, -263)
local SPAWN_SCATTER = 8

--[=[
	Publishes `StarterPlayer.StarterCharacter`, scripts stripped, as `ReplicatedStorage.CharacterRigTemplate`
	for clients to clone (StarterCharacterScripts never reach a client-built rig; locomotion is bound by the
	client service). A place without the rig fails the boot loudly.
]=]
function ReplicationInstances.publishRigTemplate(): Instance
	local starter = StarterPlayer:FindFirstChild("StarterCharacter")
	if starter == nil or not starter:IsA("Model") then
		error("[CharacterReplicationServiceServer] StarterPlayer.StarterCharacter (the rig) is missing from this place")
	end
	local existing = ReplicatedStorage:FindFirstChild(ReplicationInstances.TEMPLATE_NAME)
	if existing ~= nil then
		existing:Destroy()
	end
	local template = starter:Clone()
	template.Name = ReplicationInstances.TEMPLATE_NAME
	for _, descendant in template:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	template.Parent = ReplicatedStorage
	return template
end

--[=[
	A Camera never replicates, so focus parts under it stay server-only (spike CP2: no position leak). It
	sits in a Folder because a Camera directly under Workspace can be destroyed when CurrentCamera is
	reassigned.
]=]
function ReplicationInstances.createFocusHolder(): (Folder, Camera)
	local folder = Instance.new("Folder")
	folder.Name = "CharacterFocus"
	folder.Parent = Workspace
	local holder = Instance.new("Camera")
	holder.Name = "FocusHolder"
	holder.Parent = folder
	return folder, holder
end

-- One player's streaming focus (assign it to `player.ReplicationFocus`).
function ReplicationInstances.createFocus(holder: Camera, position: Vector3): Part
	local focus = Instance.new("Part")
	focus.Name = "Focus"
	focus.Anchored = true
	focus.CanCollide = false
	focus.CanQuery = false
	focus.CanTouch = false
	focus.Transparency = 1
	focus.Size = Vector3.one
	focus.Position = position
	focus.Parent = holder
	return focus
end

function ReplicationInstances.spawnPoint(): Vector3
	local spawnLocation = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local base = if spawnLocation ~= nil and spawnLocation:IsA("BasePart")
		then spawnLocation.Position + Vector3.new(0, 4, 0)
		else FALLBACK_SPAWN
	local scatter = Vector3.new(math.random(-SPAWN_SCATTER, SPAWN_SCATTER), 0, math.random(-SPAWN_SCATTER, SPAWN_SCATTER))
	return base + scatter
end

return ReplicationInstances
```

- [ ] **Step 4: Write `ReplicationPackets.luau`**

```luau
--!strict
--[=[
	ReplicationPackets: wires CharacterReplicationEvents' client → server packets to the service (plan R2
	Task 9): the uplink handler (built by UplinkPipeline) and the `Ready` / `RespawnRequest` handlers behind
	RequestHandler rate limits. ByteNet listeners cannot be disconnected one by one, so they are connected
	once and route through replaceable handlers (`disconnect` drops the handlers).

	Spec-exempt shell (ByteNet).

	@class ReplicationPackets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterReplicationEvents = require(ReplicatedStorage.Shared.Events.CharacterReplicationEvents)
local RequestHandler = require(ServerScriptService.Modules.RequestHandler)

local ReplicationPackets = {}

export type Handlers = {
	uplink: (data: buffer, player: Player) -> any,
	ready: (player: Player) -> (),
	respawnRequest: (player: Player) -> (),
}

local uplinkHandler: ((data: buffer, player: Player) -> any)? = nil
local readyHandler: ((data: boolean, player: Player) -> any)? = nil
local respawnHandler: ((data: boolean, player: Player) -> any)? = nil
local listening = false

function ReplicationPackets.connect(handlers: Handlers)
	uplinkHandler = handlers.uplink
	readyHandler = RequestHandler.wrap({
		name = "CharacterReplicationReady",
		rateLimit = { maxRequests = 3, windowSeconds = 10 },
		handler = function(_data: boolean, player: Player)
			handlers.ready(player)
		end,
	})
	respawnHandler = RequestHandler.wrap({
		name = "CharacterRespawnRequest",
		rateLimit = { maxRequests = 2, windowSeconds = 5 },
		handler = function(_data: boolean, player: Player)
			handlers.respawnRequest(player)
		end,
	})
	if listening then
		return
	end
	listening = true
	local packets = CharacterReplicationEvents.packets
	packets.Uplink.listen(function(data: buffer, player: Player?)
		local handler = uplinkHandler
		if player ~= nil and handler ~= nil then
			handler(data, player)
		end
	end)
	packets.Ready.listen(function(data: boolean, player: Player?)
		local handler = readyHandler
		if player ~= nil and handler ~= nil then
			handler(data, player)
		end
	end)
	packets.RespawnRequest.listen(function(data: boolean, player: Player?)
		local handler = respawnHandler
		if player ~= nil and handler ~= nil then
			handler(data, player)
		end
	end)
end

function ReplicationPackets.disconnect()
	uplinkHandler = nil
	readyHandler = nil
	respawnHandler = nil
end

return ReplicationPackets
```

- [ ] **Step 5: Write `CharacterReplicationServiceServer.luau`**

```luau
--!strict
--[=[
	CharacterReplicationServiceServer: the server side of client-only bodies (spec 2026-09-22 §5.1 option A,
	§6; plan R2 Task 9).

	There is no engine character: `Players.CharacterAutoLoads` is false (default.project.json) and any
	character that appears anyway is destroyed and logged. Per player the server holds a replication slot,
	a body epoch, the validated newest sample, server-owned health, and a streaming focus part inside a
	server-side Camera (a Camera's descendants never replicate, so the focus leaks no position — spike CP2).

	Lifecycle: join → slot claimed, slot entry broadcast → the client's `Ready` → `Session`, the slot table,
	and the first spawn. A spawn bumps the epoch (≥ 250 ms apart), picks the spawn point, pre-streams it,
	then sends `Spawn` to the owner, who builds its rig. `respawn` (slot switch, fall plane) does the same.

	Every Heartbeat `ReplicationFanout.step` relays bodies to viewers. The uplink runs through
	`UplinkPipeline` (RequestHandler: decode once, send-time bucket, counted rejects).

	Body API (docs/architecture.md, "Bodies"): `bodySpawned` / `bodyDespawned` (player, epoch),
	`observeBodies`, `hasBody`, `getBodyPosition`, `respawn`, `setMaxHealth`. No system reads
	`player.Character` for a body.

	Spec-exempt shell (Players, ByteNet, Instances); the logic lives in the specced cores beside it.

	@class CharacterReplicationServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Observers = require(ReplicatedStorage.Packages.Observers)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Modules.SignalTyped)
local CharacterReplicationEvents = require(ReplicatedStorage.Shared.Events.CharacterReplicationEvents)
local CharacterRecordCodec = require(ReplicatedStorage.Shared.Modules.CharacterReplication.CharacterRecordCodec)
local PublicPlayerState = require(ServerScriptService.State.PublicPlayerState)
local UplinkIngest = require(script.Parent.UplinkIngest)
local UplinkPipeline = require(script.Parent.UplinkPipeline)
local ReplicationSlots = require(script.Parent.ReplicationSlots)
local DownlinkScheduler = require(script.Parent.DownlinkScheduler)
local ReplicationFanout = require(script.Parent.ReplicationFanout)
local ReplicationInstances = require(script.Parent.ReplicationInstances)
local ReplicationPackets = require(script.Parent.ReplicationPackets)

type Body = ReplicationFanout.Body

local log = Logger.new("CharacterReplicationServiceServer")

local STREAM_TIMEOUT_SECONDS = 5
-- A fall-plane respawn is honoured only near the plane (the owner's last accepted samples were falling).
local FALL_PLANE_MARGIN = 100

local janitor = Janitor.new()
local world = ReplicationFanout.newWorld()
local slots = ReplicationSlots.new()
local bodiesByUserId: { [number]: Body } = {}
-- Lookups are read into `Player?` / `Part?` locals: an indexer read is typed non-optional, and Luau refuses
-- to compare an Instance type with nil.
local playersByUserId: { [number]: Player } = {}
local focusParts: { [number]: Part } = {}
local focusHolder: Camera? = nil
local sessionEpochSeconds = 0
local stats = { frames = 0, fanoutSeconds = 0, batches = 0, bytes = 0 }

local bodySpawned: SignalTyped.Signal<Player, number> = SignalTyped.new()
local bodyDespawned: SignalTyped.Signal<Player, number> = SignalTyped.new()

local function sessionNowMs(): number
	return math.floor((Workspace:GetServerTimeNow() - sessionEpochSeconds) * 1000)
end

local function slotEntryOf(body: Body, active: boolean)
	return {
		slot = body.slot,
		userId = body.userId,
		generation = body.generation,
		epoch = body.epoch.value,
		active = active,
	}
end

local function broadcastSlot(body: Body, active: boolean)
	local entry = slotEntryOf(body, active)
	for userId, other in bodiesByUserId do
		local player: Player? = playersByUserId[userId]
		if other.ready and player ~= nil then
			CharacterReplicationEvents.packets.SlotEntry.sendTo(entry, player)
		end
	end
end

local function publishVitals(body: Body)
	PublicPlayerState.set(body.userId, { health = body.health, maxHealth = body.maxHealth })
end

local function publishRelevant(body: Body)
	local userIds: { number } = {}
	for userId in body.relevant do
		table.insert(userIds, userId)
	end
	PublicPlayerState.setRelevant(body.userId, userIds)
end

local function moveFocus(body: Body, position: Vector3)
	local focus: Part? = focusParts[body.userId]
	if focus ~= nil then
		focus.Position = position
	end
end

local function spawnBody(player: Player, body: Body, reason: string): boolean
	local wasAlive = body.alive
	local previousEpoch = body.epoch.value
	if not ReplicationSlots.bumpEpoch(body.epoch, sessionNowMs()) then
		log:debug(`spawn for {player.Name} ({reason}) ignored: the body is under 250 ms old`)
		return false
	end
	if wasAlive then
		bodyDespawned:Fire(player, previousEpoch)
	end
	local position = ReplicationInstances.spawnPoint()
	body.position = position
	ReplicationFanout.respawned(body)
	moveFocus(body, position)
	publishVitals(body)
	broadcastSlot(body, true)
	local epoch = body.epoch.value
	task.spawn(function()
		local ok, err = pcall(function()
			player:RequestStreamAroundAsync(position, STREAM_TIMEOUT_SECONDS)
		end)
		if not ok then
			log:warn(`RequestStreamAroundAsync failed for {player.Name}: {err}`)
		end
		if bodiesByUserId[body.userId] == body and body.epoch.value == epoch and player.Parent ~= nil then
			CharacterReplicationEvents.packets.Spawn.sendTo({ position = position, epoch = epoch }, player)
		end
	end)
	log:info(`spawn {player.Name} epoch {epoch} ({reason})`)
	bodySpawned:Fire(player, epoch)
	return true
end

local hooks: ReplicationFanout.Hooks = {
	send = function(viewer: Body, batch: buffer)
		local player: Player? = playersByUserId[viewer.userId]
		if player ~= nil then
			CharacterReplicationEvents.packets.Downlink.sendTo(batch, player)
			stats.batches += 1
			stats.bytes += buffer.len(batch)
		end
	end,
	visibility = function(viewer: Body, subject: Body, entered: boolean)
		local player: Player? = playersByUserId[viewer.userId]
		if entered then
			viewer.relevant[subject.userId] = true
			if player ~= nil then
				local nowMs = sessionNowMs()
				local record, sampleMs = ReplicationFanout.enterRecord(subject, nowMs)
				local bytes = buffer.create(CharacterRecordCodec.RECORD_BYTES)
				DownlinkScheduler.encode(bytes, subject.slot, subject.generation, subject.epoch.value, record, sampleMs, nowMs)
				CharacterReplicationEvents.packets.Enter.sendTo({
					slot = subject.slot,
					generation = subject.generation,
					batchTimeMs = nowMs,
					record = bytes,
				}, player)
			end
		else
			viewer.relevant[subject.userId] = nil
			if player ~= nil then
				CharacterReplicationEvents.packets.Leave.sendTo({ slot = subject.slot, generation = subject.generation }, player)
			end
		end
		publishRelevant(viewer)
	end,
}

local function onReady(player: Player)
	local body = bodiesByUserId[player.UserId]
	if body == nil then
		return
	end
	if body.ready then
		-- A repeated handshake: the client lost its view; start its stream over.
		ReplicationFanout.resetViewer(body)
		publishRelevant(body)
	end
	body.ready = true
	CharacterReplicationEvents.packets.Session.sendTo({ epochSeconds = sessionEpochSeconds }, player)
	for _, other in bodiesByUserId do
		CharacterReplicationEvents.packets.SlotEntry.sendTo(slotEntryOf(other, true), player)
	end
	if not body.alive then
		spawnBody(player, body, "join")
	end
end

local function onRespawnRequest(player: Player)
	local body = bodiesByUserId[player.UserId]
	if body == nil or not body.alive then
		return
	end
	if body.position.Y > Workspace.FallenPartsDestroyHeight + FALL_PLANE_MARGIN then
		log:debug(`respawn request from {player.Name} refused: last accepted Y {body.position.Y}`)
		return
	end
	spawnBody(player, body, "fell")
end

local function onPlayer(player: Player): (() -> ())?
	local holder = focusHolder
	if holder == nil then
		return nil -- the service is stopped
	end
	local userId = player.UserId
	local slot = ReplicationSlots.claim(slots)
	if slot == nil then
		log:error(`no replication slot left for {player.Name}; they get no body`)
		return nil
	end
	local generation = ReplicationSlots.generationOf(slots, slot)
	local body = ReplicationFanout.newBody(userId, slot, generation, ReplicationInstances.spawnPoint())
	ReplicationFanout.addBody(world, body)
	bodiesByUserId[userId] = body
	playersByUserId[userId] = player

	local focus = ReplicationInstances.createFocus(holder, body.position)
	player.ReplicationFocus = focus
	focusParts[userId] = focus

	publishVitals(body)
	publishRelevant(body)
	broadcastSlot(body, true)

	local characterConnection = player.CharacterAdded:Connect(function(character: Model)
		log:warn(`an engine character appeared for {player.Name}; destroying it (bodies are client-only)`)
		character:Destroy()
	end)

	return function()
		characterConnection:Disconnect()
		if body.alive then
			bodyDespawned:Fire(player, body.epoch.value)
		end
		body.alive = false
		ReplicationFanout.removeBody(world, slot, hooks)
		bodiesByUserId[userId] = nil
		playersByUserId[userId] = nil
		ReplicationSlots.release(slots, slot)
		broadcastSlot(body, false)
		focus:Destroy()
		focusParts[userId] = nil
		PublicPlayerState.remove(userId)
	end
end

local function step()
	local started = os.clock()
	ReplicationFanout.step(world, sessionNowMs(), hooks)
	stats.frames += 1
	stats.fanoutSeconds += os.clock() - started
end

export type CharacterReplicationServiceServer = {
	dependencies: { string },
	init: (self: CharacterReplicationServiceServer) -> (),
	start: (self: CharacterReplicationServiceServer) -> (),
	stop: (self: CharacterReplicationServiceServer) -> (),
	bodySpawned: SignalTyped.Signal<Player, number>,
	bodyDespawned: SignalTyped.Signal<Player, number>,
	observeBodies: (
		self: CharacterReplicationServiceServer,
		callback: (player: Player, epoch: number) -> (() -> ())?
	) -> () -> (),
	hasBody: (self: CharacterReplicationServiceServer, player: Player) -> boolean,
	getBodyPosition: (self: CharacterReplicationServiceServer, player: Player) -> Vector3?,
	respawn: (self: CharacterReplicationServiceServer, player: Player, reason: string) -> boolean,
	setMaxHealth: (self: CharacterReplicationServiceServer, userId: number, maxHealth: number) -> (),
	getState: (self: CharacterReplicationServiceServer) -> { [string]: any },
}

local CharacterReplicationServiceServer: CharacterReplicationServiceServer = {
	dependencies = {},
	bodySpawned = bodySpawned,
	bodyDespawned = bodyDespawned,

	--[=[
		Turns engine characters off (loudly, if the place lacks the project's Players node), publishes the rig
		template, creates the focus container, and wires the packets.
	]=]
	init = function(_self)
		if Players.CharacterAutoLoads then
			log:error("Players.CharacterAutoLoads was true: the default.project.json Players node is not applied; turning it off")
			Players.CharacterAutoLoads = false
		end
		sessionEpochSeconds = math.floor(Workspace:GetServerTimeNow())

		janitor:Add(ReplicationInstances.publishRigTemplate(), "Destroy")
		local folder, holder = ReplicationInstances.createFocusHolder()
		focusHolder = holder
		janitor:Add(folder, "Destroy")

		ReplicationPackets.connect({
			uplink = UplinkPipeline.wrap(function(player: Player): UplinkIngest.State?
				local body = bodiesByUserId[player.UserId]
				return if body ~= nil and body.alive then body.ingest else nil
			end, sessionNowMs, function(player: Player, state: UplinkIngest.State)
				local body = bodiesByUserId[player.UserId]
				local latest = state.latest
				if body ~= nil and latest ~= nil then
					body.position = latest.position
					moveFocus(body, latest.position)
				end
			end),
			ready = onReady,
			respawnRequest = onRespawnRequest,
		})
	end,

	--[=[
		Starts tracking players and the per-frame fan-out.
	]=]
	start = function(_self)
		janitor:Add(Observers.observePlayer(onPlayer), true)
		janitor:Add(RunService.Heartbeat:Connect(step), "Disconnect")
		log:debug("CharacterReplicationServiceServer started")
	end,

	stop = function(_self)
		janitor:Cleanup()
		ReplicationPackets.disconnect()
		focusHolder = nil
	end,

	--[=[
		Runs `callback(player, epoch)` for every live body now and for every body that spawns later. The
		cleanup it returns runs when that body despawns (or the observer is disconnected). The returned
		function disconnects the observer.
	]=]
	observeBodies = function(_self, callback)
		local cleanups: { [Player]: () -> () } = {}
		local function spawned(player: Player, epoch: number)
			local previous = cleanups[player]
			if previous ~= nil then
				cleanups[player] = nil
				previous()
			end
			local cleanup = callback(player, epoch)
			if cleanup ~= nil then
				cleanups[player] = cleanup
			end
		end
		local function despawned(player: Player, _epoch: number)
			local cleanup = cleanups[player]
			if cleanup ~= nil then
				cleanups[player] = nil
				cleanup()
			end
		end
		local spawnConnection = bodySpawned:Connect(spawned)
		local despawnConnection = bodyDespawned:Connect(despawned)
		for userId, body in bodiesByUserId do
			local player: Player? = playersByUserId[userId]
			if body.alive and player ~= nil then
				task.spawn(spawned, player, body.epoch.value)
			end
		end
		return function()
			spawnConnection:Disconnect()
			despawnConnection:Disconnect()
			for _, cleanup in cleanups do
				cleanup()
			end
			table.clear(cleanups)
		end
	end,

	hasBody = function(_self, player)
		local body = bodiesByUserId[player.UserId]
		return body ~= nil and body.alive
	end,

	getBodyPosition = function(_self, player)
		local body = bodiesByUserId[player.UserId]
		return if body ~= nil and body.alive then body.position else nil
	end,

	--[=[
		Respawns a live body (new epoch, server-chosen spawn, the owner rebuilds). Does not yield. False when
		the player has no live body yet (their first spawn happens at their handshake) or the previous spawn
		is under 250 ms old.
	]=]
	respawn = function(_self, player, reason)
		local body = bodiesByUserId[player.UserId]
		if body == nil or not body.alive then
			return false
		end
		return spawnBody(player, body, reason)
	end,

	--[=[
		The body's maximum health (StatsServiceServer pushes the derived value). Health is clamped down,
		never healed up; the public entry follows.
	]=]
	setMaxHealth = function(_self, userId, maxHealth)
		local body = bodiesByUserId[userId]
		if body ~= nil and ReplicationFanout.setMaxHealth(body, maxHealth) then
			publishVitals(body)
		end
	end,

	getState = function(_self)
		local ingest: { [string]: UplinkIngest.Counters } = {}
		local bodies = 0
		for userId, body in bodiesByUserId do
			bodies += 1
			local player: Player? = playersByUserId[userId]
			ingest[if player ~= nil then player.Name else tostring(userId)] = table.clone(body.ingest.counters)
		end
		return {
			bodies = bodies,
			slotsUsed = ReplicationSlots.count(slots),
			fanoutMsAvg = if stats.frames > 0 then stats.fanoutSeconds / stats.frames * 1000 else 0,
			downlinkBatches = stats.batches,
			downlinkBytes = stats.bytes,
			ingest = ingest,
		}
	end,
}

return CharacterReplicationServiceServer
```

- [ ] **Step 6: Register the shells' spec exemptions**

In `src/ServerScriptService/Modules/SpecRoots.luau` `EXEMPT_MODULES`, after the replication harness entries:

```luau
	-- Character replication shells (R2): Players, ByteNet, Instances and Heartbeat wiring only. Their logic
	-- lives in the specced cores beside them (UplinkIngest, UplinkPipeline, ReplicationSlots, VisibilitySet,
	-- DownlinkScheduler, ReplicationFanout, PublicPlayerState) and they are verified by the Studio checklist.
	["ServerScriptService.Services.CharacterReplicationService.CharacterReplicationServiceServer"] = "network/Instance shell (cores are specced)",
	["ServerScriptService.Services.CharacterReplicationService.ReplicationInstances"] = "Instance shell (rig template, focus parts, spawn point)",
	["ServerScriptService.Services.CharacterReplicationService.ReplicationPackets"] = "ByteNet wiring shell (handlers are RequestHandler-wrapped)",
```

- [ ] **Step 7: Run the static checks**

Format, Lint, Typecheck, File length (the shell must stay under 400 code lines), Project rules.

- [ ] **Step 8: Run the tests**

Studio test run: suite green (`SpecRoots` accepts the new exemption).

- [ ] **Step 9: Studio smoke check (controller)**

Serve the worktree, Play solo (no `RunTests`). Expected: no errors from `CharacterReplicationServiceServer`; server command bar `print(game.Players.CharacterAutoLoads)` → `false`; `ReplicatedStorage.CharacterRigTemplate` exists and has no scripts; `Workspace.CharacterFocus.FocusHolder` holds one `Focus` part per player; no body yet (the client half lands in Task 10).

- [ ] **Step 10: Commit**

```bash
git add default.project.json src/ReplicatedStorage/Shared/Events/CharacterReplicationEvents.luau src/ServerScriptService/Services/CharacterReplicationService/ReplicationInstances.luau src/ServerScriptService/Services/CharacterReplicationService/ReplicationPackets.luau src/ServerScriptService/Services/CharacterReplicationService/CharacterReplicationServiceServer.luau src/ServerScriptService/Modules/SpecRoots.luau
git commit -m "feat(replication): server service for client-only bodies and its packet namespace

CharacterAutoLoads goes off through a property-only Players node. Per player: a slot, an epoch bumped
on spawn, validated samples through the uplink pipeline, server-owned health on the public slice, and
a focus part under a non-replicating Camera. The fan-out runs every Heartbeat."
```

---
### Task 10: Client owner half — owner rig, locomotion binding, uplink

**Runtime behaviour: yes** — players get a body again: the client builds its rig from the server's template on `Spawn`, makes it `LocalPlayer.Character`, animates it locally, and streams it. `Animate.client.luau` is deleted (StarterCharacterScripts never reach a client-built rig); Cmdr boots without waiting for a character.

**Files:**
- Create: `src/ReplicatedStorage/Client/Services/CharacterReplicationService/UplinkSender.spec.luau`
- Create: `src/ReplicatedStorage/Client/Services/CharacterReplicationService/UplinkSender.luau`
- Create: `src/ReplicatedStorage/Client/Services/AnimationService/LocomotionBinding.luau`
- Create: `src/ReplicatedStorage/Client/Services/CharacterReplicationService/OwnerRig.luau`
- Create: `src/ReplicatedStorage/Client/Services/CharacterReplicationService/CharacterReplicationServiceClient.luau`
- Delete: `src/StarterPlayer/StarterCharacterScripts/Animate.client.luau`
- Modify: `default.project.json` (remove the `StarterCharacterScripts` node)
- Modify: `src/ReplicatedStorage/Client/Services/AdminService/AdminServiceClient.luau:42-62`
- Modify: `src/ServerScriptService/Modules/SpecRoots.luau` (`EXEMPT_MODULES`)

**Interfaces:**
- Consumes: `CharacterUplinkCodec` (Task 3), `SendPolicy` (R1), `CharacterReplicationEvents` (`Ready`, `Session`, `Spawn`, `Uplink`, `RespawnRequest` — Task 9), `ClientStore.publicPlayers` and `SyncState.publicEntryKey` (Task 8), `LocomotionAnimator`, `AnimationPlayerRuntime`, `AnimationRegistry`.
- Produces:
  - `UplinkSender.MIN_SPACING_MS` (15)
  - `export type Sender = { policy: SendPolicy.Policy, lastSent: CharacterRecordCodec.Record?, history: { CharacterUplinkCodec.UplinkSample }, lastSampleMs: number, sent: number }`
  - `UplinkSender.new(): Sender`, `reset(sender: Sender)`, `step(sender: Sender, nowMs: number, record: CharacterRecordCodec.Record): buffer?`
  - `UplinkSender.isGrounded(state: Enum.HumanoidStateType, floorMaterial: Enum.Material): boolean`
  - `LocomotionBinding.bind(character: Model): (() -> ())?` — may yield (Animator lookup); returns the unbind
  - `export type Rig = { model: Model, humanoid: Humanoid, root: BasePart, epoch: number, cleanup: () -> () }`
  - `OwnerRig.build(template: Model, position: Vector3, epoch: number, onFell: () -> ()): (Rig?, string?)`, `OwnerRig.destroy(rig: Rig)`
  - `CharacterReplicationServiceClient.bodySpawned: SignalTyped.Signal<Player, Model>`, `bodyDespawned` (same), `:getRig(player: Player): Model?`, `:getPlayerFromRig(rig: Model): Player?`, `:getLocalRig(): Model?`, `:getState(): { [string]: any }`

- [ ] **Step 1: Write the failing spec**

`UplinkSender.spec.luau`:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Replication = ReplicatedStorage.Shared.Modules.CharacterReplication
local Uplink = require(Replication.CharacterUplinkCodec)
local UplinkSender = require(ReplicatedStorage.Client.Services.CharacterReplicationService.UplinkSender)

local function record(x, overrides)
	local r = {
		slot = 0,
		generation = 0,
		epoch = 1,
		ageMs = 0,
		position = Vector3.new(-1200 + x, 40, -350),
		yaw = 0,
		pitch = 0,
		velocity = Vector3.new(16, 0, 0),
		state = 8,
		grounded = true,
		hasAction = false,
		rotation = nil,
	}
	for key, value in overrides or {} do
		r[key] = value
	end
	return r
end

local function decode(packet)
	local ok, reason, uplink = Uplink.decode(packet)
	assert(ok, reason)
	return uplink
end

return function()
	it("sends a change, then for a still body only its two resends and the 1 Hz repair", function()
		local sender = UplinkSender.new()
		local sends = {}
		for frame = 0, 72 do -- 1.2 s at 60 Hz, never moving
			local nowMs = math.floor(frame * 1000 / 60)
			if UplinkSender.step(sender, nowMs, record(0)) ~= nil then
				table.insert(sends, nowMs)
			end
		end
		expect(#sends).to.equal(4)
		expect(sends[1]).to.equal(0)
		expect(sends[4] >= 1000).to.equal(true)
	end)

	it("never samples closer than 15 ms", function()
		local sender = UplinkSender.new()
		expect(UplinkSender.step(sender, 1000, record(0))).to.be.ok()
		expect(UplinkSender.step(sender, 1010, record(1))).to.equal(nil)
		expect(UplinkSender.step(sender, 1015, record(1))).to.be.ok()
	end)

	it("carries the current sample and the two previous sent ones, newest first", function()
		local sender = UplinkSender.new()
		UplinkSender.step(sender, 1000, record(0))
		UplinkSender.step(sender, 1017, record(0.3))
		local uplink = decode(UplinkSender.step(sender, 1034, record(0.6)))
		expect(uplink.sentMs).to.equal(1034)
		expect(#uplink.samples).to.equal(3)
		expect(uplink.samples[1].sampleMs).to.equal(1034)
		expect(uplink.samples[2].sampleMs).to.equal(1017)
		expect(uplink.samples[3].sampleMs).to.equal(1000)
		expect(uplink.samples[1].record.position.X).to.be.near(-1199.4, 0.02)
	end)

	it("leaves previous samples older than 1023 ms out of a repair", function()
		local sender = UplinkSender.new()
		local last = nil
		for frame = 0, 150 do -- 2.5 s still: change, two resends, repairs at ~1.1 s and ~2.1 s
			local packet = UplinkSender.step(sender, math.floor(frame * 1000 / 60), record(0))
			if packet ~= nil then
				last = packet
			end
		end
		local uplink = decode(last)
		for i = 2, #uplink.samples do
			expect(uplink.sentMs - uplink.samples[i].sampleMs <= 1023).to.equal(true)
		end
	end)

	it("reset forgets the previous body's samples", function()
		local sender = UplinkSender.new()
		UplinkSender.step(sender, 1000, record(0))
		UplinkSender.reset(sender)
		local uplink = decode(UplinkSender.step(sender, 1005, record(5, { epoch = 2 })))
		expect(#uplink.samples).to.equal(1)
	end)

	it("reports grounded from the state machine and the floor together", function()
		expect(UplinkSender.isGrounded(Enum.HumanoidStateType.Running, Enum.Material.Plastic)).to.equal(true)
		expect(UplinkSender.isGrounded(Enum.HumanoidStateType.Jumping, Enum.Material.Plastic)).to.equal(false)
		expect(UplinkSender.isGrounded(Enum.HumanoidStateType.Freefall, Enum.Material.Plastic)).to.equal(false)
		expect(UplinkSender.isGrounded(Enum.HumanoidStateType.Running, Enum.Material.Air)).to.equal(false)
	end)
end
```

- [ ] **Step 2: Run the tests and verify they fail**

Studio test run. Expected: `UplinkSender.spec` fails at `require`.

- [ ] **Step 3: Write `UplinkSender.luau`**

```luau
--!strict
--[=[
	UplinkSender: when the owner sends a sample, and the packet it sends (spec §6.3; Verdict: send-on-change
	uplink; plan R2 Task 10).

	At most one sample every 15 ms (≤ 60 Hz, honest timestamps — no accumulator repeating positions). The v3
	send policy decides: a changed sample goes at once; a still body sends two resends 50 ms apart and then a
	repair every second. Each packet carries the new sample plus the two previously SENT samples (survives
	two consecutive losses), newest first, aged from the packet's send time (CharacterUplinkCodec).

	`isGrounded` follows the spike's measured rule: the most authoritative local signal is the Humanoid STATE
	machine (FloorMaterial lags a jump by several frames), so grounded needs both a non-airborne state and a
	floor.

	Pure: time is passed in (session ms, integer).

	@class UplinkSender
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Replication = ReplicatedStorage.Shared.Modules.CharacterReplication
local CharacterRecordCodec = require(Replication.CharacterRecordCodec)
local CharacterUplinkCodec = require(Replication.CharacterUplinkCodec)
local SendPolicy = require(Replication.SendPolicy)

local UplinkSender = {}

local MIN_SPACING_MS = 15
UplinkSender.MIN_SPACING_MS = MIN_SPACING_MS

local AIRBORNE: { [Enum.HumanoidStateType]: boolean } = {
	[Enum.HumanoidStateType.Jumping] = true,
	[Enum.HumanoidStateType.Freefall] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.Flying] = true,
	[Enum.HumanoidStateType.Ragdoll] = true,
}

export type Sender = {
	policy: SendPolicy.Policy,
	lastSent: CharacterRecordCodec.Record?,
	history: { CharacterUplinkCodec.UplinkSample }, -- newest first, at most MAX_RECORDS
	lastSampleMs: number,
	sent: number,
}

function UplinkSender.new(): Sender
	return {
		policy = SendPolicy.new(),
		lastSent = nil,
		history = {},
		lastSampleMs = -math.huge,
		sent = 0,
	}
end

-- A new body: nothing of the previous one is resent.
function UplinkSender.reset(sender: Sender)
	sender.policy = SendPolicy.new()
	sender.lastSent = nil
	table.clear(sender.history)
	sender.lastSampleMs = -math.huge
end

function UplinkSender.isGrounded(state: Enum.HumanoidStateType, floorMaterial: Enum.Material): boolean
	return not AIRBORNE[state] and floorMaterial ~= Enum.Material.Air
end

--[=[
	Offer the owner's current sample at `nowMs`. Returns the packet to send, or nil. `record` must be a fresh
	table (the sender keeps it and writes its `ageMs` per packet).
]=]
function UplinkSender.step(sender: Sender, nowMs: number, record: CharacterRecordCodec.Record): buffer?
	if nowMs - sender.lastSampleMs < MIN_SPACING_MS then
		return nil
	end
	local decision = SendPolicy.decide(sender.policy, nowMs, SendPolicy.changed(sender.lastSent, record))
	if decision == nil then
		return nil
	end
	sender.lastSent = record
	sender.lastSampleMs = nowMs
	table.insert(sender.history, 1, { record = record, sampleMs = nowMs })
	if #sender.history > CharacterUplinkCodec.MAX_RECORDS then
		table.remove(sender.history)
	end
	sender.sent += 1
	return CharacterUplinkCodec.encode(nowMs, sender.history)
end

return UplinkSender
```

- [ ] **Step 4: Write `LocomotionBinding.luau` (moved from `Animate.client.luau`)**

```luau
--!strict
--[=[
	LocomotionBinding: binds the specced LocomotionAnimator core to a rig's Humanoid (Phase 6 spec,
	Decision 3; moved here from StarterCharacterScripts/Animate.client.luau by character replication R2).

	Under client-only bodies (spec §5.1) the engine never spawns a character, so StarterCharacterScripts never
	reach a rig: CharacterReplicationServiceClient calls `bind` on the owner rig it builds. Thin by design:
	every decision lives in LocomotionAnimator; this adapts Humanoid state events to it, watches the kill
	switch, and owns the lifetime (the returned function unbinds; destroying the rig without unbinding is
	also safe — the Humanoid's connections die with it).

	Kill switch: the Workspace attribute `LocomotionEnabled` (unset = enabled).

	May yield: `AnimationPlayerRuntime.forCharacter` waits up to 5 s for an Animator.

	Spec-exempt shell (needs a live Humanoid + Animator); the core is specced in LocomotionAnimator.spec.

	@class LocomotionBinding
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AnimationPlayerRuntime = require(ReplicatedStorage.Shared.Modules.AnimationPlayerRuntime)
local AnimationRegistry = require(ReplicatedStorage.Shared.Modules.Constants.Animations.AnimationRegistry)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local LocomotionAnimator = require(script.Parent.LocomotionAnimator)

local ENABLED_ATTRIBUTE = "LocomotionEnabled"

local log = Logger.new("LocomotionBinding")

local LocomotionBinding = {}

local function isEnabled(): boolean
	return Workspace:GetAttribute(ENABLED_ATTRIBUTE) ~= false
end

function LocomotionBinding.bind(character: Model): (() -> ())?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		log:warn(`{character.Name} has no Humanoid; locomotion animations disabled for it`)
		return nil
	end
	local player = AnimationPlayerRuntime.forCharacter(character)
	if player == nil then
		log:warn("no Animator found; locomotion animations disabled for this rig")
		return nil
	end
	local animator = LocomotionAnimator.new(player)

	-- Warm the locomotion set up front (spec Decision 6): a pose's first play must be a cache hit.
	task.spawn(function()
		local locomotion = AnimationRegistry.domain("locomotion")
		if locomotion == nil then
			return
		end
		player:warm("idle")
		for id in locomotion do
			if id ~= "idle" then
				player:warm(id)
			end
		end
	end)

	animator:setEnabled(isEnabled())
	local connections: { RBXScriptConnection } = {
		Workspace:GetAttributeChangedSignal(ENABLED_ATTRIBUTE):Connect(function()
			animator:setEnabled(isEnabled())
		end),
		humanoid.Running:Connect(function(speed: number)
			animator:handleEvent("running", speed, os.clock())
		end),
		humanoid.Jumping:Connect(function()
			animator:handleEvent("jumping", nil, os.clock())
		end),
		humanoid.FreeFalling:Connect(function()
			animator:handleEvent("freefall", nil, os.clock())
		end),
		humanoid.Climbing:Connect(function(speed: number)
			animator:handleEvent("climbing", speed, os.clock())
		end),
		humanoid.Swimming:Connect(function(speed: number)
			animator:handleEvent("swimming", speed, os.clock())
		end),
		humanoid.Seated:Connect(function()
			animator:handleEvent("seated", nil, os.clock())
		end),
		humanoid.GettingUp:Connect(function()
			animator:handleEvent("gettingUp", nil, os.clock())
		end),
		humanoid.PlatformStanding:Connect(function()
			animator:handleEvent("platformStanding", nil, os.clock())
		end),
		humanoid.Died:Connect(function()
			animator:handleEvent("died", nil, os.clock())
		end),
	}

	-- Start at idle (the stock script's "initialize to idle").
	if isEnabled() then
		animator:handleEvent("running", 0, os.clock())
	end

	local bound = true
	return function()
		if not bound then
			return
		end
		bound = false
		for _, connection in connections do
			connection:Disconnect()
		end
		animator:destroy()
	end
end

return LocomotionBinding
```

- [ ] **Step 5: Write `OwnerRig.luau`**

```luau
--!strict
--[=[
	OwnerRig: builds and tears down this client's own body (spec §5.1 option A, owner client; plan R2
	Task 10).

	`build` clones the server-published rig template, makes it `LocalPlayer.Character` BEFORE parenting it
	(spike CP1: the order the engine expects), sets the camera subject explicitly, binds locomotion, mirrors
	the server-owned health from the public slice onto the Humanoid (display only — health is server state),
	and reports the local fall-plane destroy (`onFell`), which the server answers with a respawn.

	Spec-exempt shell (needs a live rig, camera and Humanoid).

	@class OwnerRig
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Charm = require(ReplicatedStorage.Packages.Charm)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local PublicPlayerTypes = require(ReplicatedStorage.Shared.Types.PublicPlayerTypes)
local SyncState = require(ReplicatedStorage.Shared.State.SyncState)
local ClientStore = require(ReplicatedStorage.Client.State.ClientStore)
local LocomotionBinding = require(ReplicatedStorage.Client.Services.AnimationService.LocomotionBinding)

export type Rig = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	epoch: number,
	cleanup: () -> (),
}

local OwnerRig = {}

function OwnerRig.build(template: Model, position: Vector3, epoch: number, onFell: () -> ()): (Rig?, string?)
	local localPlayer = Players.LocalPlayer
	local model = template:Clone()
	if not model:IsA("Model") then -- Instance:Clone() is typed Instance
		model:Destroy()
		return nil, "the rig template did not clone as a Model"
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or not humanoid:IsA("Humanoid") or root == nil or not root:IsA("BasePart") then
		model:Destroy()
		return nil, "the rig template has no Humanoid / HumanoidRootPart"
	end
	model.Name = localPlayer.Name
	model:PivotTo(CFrame.new(position))
	-- Character first, then parent (spike CP1).
	localPlayer.Character = model
	model.Parent = Workspace
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		camera.CameraSubject = humanoid
	end

	local janitor = Janitor.new()
	local alive = true

	-- Health mirror (display only): the server's public entry for this player.
	local key = SyncState.publicEntryKey(localPlayer.UserId)
	local function mirror(map: PublicPlayerTypes.PublicPlayerMap)
		local entry = map[key]
		if entry ~= nil then
			humanoid.MaxHealth = entry.maxHealth
			humanoid.Health = math.min(entry.health, entry.maxHealth)
		end
	end
	mirror(ClientStore.publicPlayers())
	janitor:Add(Charm.subscribe(ClientStore.publicPlayers, mirror), true)

	-- The engine destroys the root locally below FallenPartsDestroyHeight.
	janitor:Add(
		root.AncestryChanged:Connect(function(_, parent)
			if parent == nil and alive then
				onFell()
			end
		end),
		"Disconnect"
	)

	-- Locomotion may yield (Animator lookup): bind in a thread, unbind at once if the rig died meanwhile.
	task.spawn(function()
		local unbind = LocomotionBinding.bind(model)
		if unbind == nil then
			return
		end
		if alive then
			janitor:Add(unbind, true)
		else
			unbind()
		end
	end)

	local function cleanup()
		alive = false
		janitor:Destroy()
		if localPlayer.Character == model then
			localPlayer.Character = nil
		end
		model:Destroy()
	end

	return { model = model, humanoid = humanoid, root = root, epoch = epoch, cleanup = cleanup }, nil
end

function OwnerRig.destroy(rig: Rig)
	rig.cleanup()
end

return OwnerRig
```

- [ ] **Step 6: Write `CharacterReplicationServiceClient.luau` (owner half)**

```luau
--!strict
--[=[
	CharacterReplicationServiceClient: this client's side of client-only bodies (spec 2026-09-22 §5.1 option A,
	§6; plan R2 Task 10 — the owner half).

	On `Spawn` it builds the owner rig (OwnerRig) from `ReplicatedStorage.CharacterRigTemplate` and makes it
	`LocalPlayer.Character`; every Heartbeat it offers the rig's state to UplinkSender and sends the packets
	it returns. The handshake (`Ready`) goes once the listeners are connected.

	Body API (docs/architecture.md, "Bodies"): `bodySpawned` / `bodyDespawned` (player, rig) fire for every rig
	this client shows; `getRig(player)`, `getPlayerFromRig(rig)`, `getLocalRig()`. Find a body's player by id
	through this registry, never by instance name.

	Spec-exempt shell (network, Instances, RunService); the cores (UplinkSender, OwnerRig's binding) are
	specced or verified in Studio.

	@class CharacterReplicationServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Modules.SignalTyped)
local CharacterReplicationEvents = require(ReplicatedStorage.Shared.Events.CharacterReplicationEvents)
local CharacterRecordCodec = require(ReplicatedStorage.Shared.Modules.CharacterReplication.CharacterRecordCodec)
local OwnerRig = require(script.Parent.OwnerRig)
local UplinkSender = require(script.Parent.UplinkSender)

local TEMPLATE_NAME = "CharacterRigTemplate"
local TEMPLATE_WAIT_SECONDS = 30

local log = Logger.new("CharacterReplicationServiceClient")
local janitor = Janitor.new()

local template: Model? = nil
local sessionEpochSeconds: number? = nil
local ownerRig: OwnerRig.Rig? = nil
local buildSeq = 0
local sender = UplinkSender.new()
local rigsByUserId: { [number]: Model } = {}
local userIdsByRig: { [Model]: number } = {}

local bodySpawned: SignalTyped.Signal<Player, Model> = SignalTyped.new()
local bodyDespawned: SignalTyped.Signal<Player, Model> = SignalTyped.new()

local function sessionNowMs(): number?
	local epochSeconds = sessionEpochSeconds
	if epochSeconds == nil then
		return nil
	end
	return (Workspace:GetServerTimeNow() - epochSeconds) * 1000
end

local function registerRig(player: Player, model: Model)
	rigsByUserId[player.UserId] = model
	userIdsByRig[model] = player.UserId
	bodySpawned:Fire(player, model)
end

local function unregisterRig(player: Player, model: Model)
	if rigsByUserId[player.UserId] == model then
		rigsByUserId[player.UserId] = nil
	end
	userIdsByRig[model] = nil
	bodyDespawned:Fire(player, model)
end

local function awaitTemplate(): Model?
	if template ~= nil then
		return template
	end
	local found = ReplicatedStorage:WaitForChild(TEMPLATE_NAME, TEMPLATE_WAIT_SECONDS)
	if found ~= nil and found:IsA("Model") then
		template = found
	end
	return template
end

local function dropOwnerRig()
	local rig = ownerRig
	if rig == nil then
		return
	end
	ownerRig = nil
	unregisterRig(Players.LocalPlayer, rig.model)
	OwnerRig.destroy(rig)
end

local function buildOwnerRig(position: Vector3, epoch: number)
	buildSeq += 1
	local mine = buildSeq
	local rigTemplate = awaitTemplate()
	if mine ~= buildSeq then
		return -- a newer Spawn arrived while waiting for the template
	end
	if rigTemplate == nil then
		log:error(`{TEMPLATE_NAME} never replicated; no body`)
		return
	end
	dropOwnerRig()
	local rig, err = OwnerRig.build(rigTemplate, position, epoch, function()
		CharacterReplicationEvents.packets.RespawnRequest.send(true)
	end)
	if rig == nil then
		log:error(`owner rig build failed: {err or "unknown"}`)
		return
	end
	ownerRig = rig
	UplinkSender.reset(sender)
	registerRig(Players.LocalPlayer, rig.model)
	log:info(`owner rig built (epoch {epoch})`)
end

local function sampleOwner()
	local rig = ownerRig
	local nowMs = sessionNowMs()
	if rig == nil or nowMs == nil or rig.root.Parent == nil then
		return
	end
	local cframe = rig.root.CFrame
	local look = cframe.LookVector
	local state = rig.humanoid:GetState()
	local record: CharacterRecordCodec.Record = {
		slot = 0, -- the server addresses bodies by the sender, not by these fields
		generation = 0,
		epoch = rig.epoch,
		ageMs = 0,
		position = cframe.Position,
		yaw = math.atan2(-look.X, -look.Z),
		pitch = 0,
		velocity = rig.root.AssemblyLinearVelocity,
		state = state.Value % 32,
		grounded = UplinkSender.isGrounded(state, rig.humanoid.FloorMaterial),
		hasAction = false,
		rotation = nil,
	}
	local packet = UplinkSender.step(sender, math.floor(nowMs), record)
	if packet ~= nil then
		CharacterReplicationEvents.packets.Uplink.send(packet)
	end
end

export type CharacterReplicationServiceClient = {
	dependencies: { string },
	init: (self: CharacterReplicationServiceClient) -> (),
	stop: (self: CharacterReplicationServiceClient) -> (),
	bodySpawned: SignalTyped.Signal<Player, Model>,
	bodyDespawned: SignalTyped.Signal<Player, Model>,
	getRig: (self: CharacterReplicationServiceClient, player: Player) -> Model?,
	getPlayerFromRig: (self: CharacterReplicationServiceClient, rig: Model) -> Player?,
	getLocalRig: (self: CharacterReplicationServiceClient) -> Model?,
	getState: (self: CharacterReplicationServiceClient) -> { [string]: any },
}

local CharacterReplicationServiceClient: CharacterReplicationServiceClient = {
	dependencies = {},
	bodySpawned = bodySpawned,
	bodyDespawned = bodyDespawned,

	init = function(_self)
		local packets = CharacterReplicationEvents.packets
		packets.Session.listen(function(data)
			sessionEpochSeconds = data.epochSeconds
		end)
		packets.Spawn.listen(function(data)
			task.spawn(buildOwnerRig, data.position, data.epoch)
		end)
		janitor:Add(RunService.Heartbeat:Connect(sampleOwner), "Disconnect")
		janitor:Add(dropOwnerRig, true)
		-- Listeners are connected: ask for the session, the slot table and a body.
		packets.Ready.send(true)
	end,

	stop = function(_self)
		janitor:Cleanup()
	end,

	getRig = function(_self, player)
		return rigsByUserId[player.UserId]
	end,

	getPlayerFromRig = function(_self, rig)
		local userId = userIdsByRig[rig]
		return if userId ~= nil then Players:GetPlayerByUserId(userId) else nil
	end,

	getLocalRig = function(_self)
		local rig = ownerRig
		return if rig ~= nil then rig.model else nil
	end,

	getState = function(_self)
		local rig = ownerRig
		return {
			hasSession = sessionEpochSeconds ~= nil,
			ownerEpoch = if rig ~= nil then rig.epoch else nil,
			uplinkPackets = sender.sent,
		}
	end,
}

return CharacterReplicationServiceClient
```

- [ ] **Step 7: Remove the Animate script, its project node, and the Cmdr character wait**

```bash
git rm src/StarterPlayer/StarterCharacterScripts/Animate.client.luau
```

In `default.project.json`, delete the `StarterCharacterScripts` node so `StarterPlayer` keeps only `StarterPlayerScripts`:

```json
    "StarterPlayer": {
      "StarterPlayerScripts": {
        "$path": "src/StarterPlayer/StarterPlayerScripts"
      }
    },
```

In `src/ReplicatedStorage/Client/Services/AdminService/AdminServiceClient.luau`, replace the whole `init` body (the comment block and the `task.spawn`) with:

```luau
	init = function(_self)
		-- Character replication R2: no engine character ever spawns, so the engine never copies StarterGui
		-- (where Cmdr keeps its GUI template) into PlayerGui. CmdrClient's own clone is therefore the only
		-- Cmdr GUI, and there is no copy to wait for (the old wait raced the engine copy: evaera/Cmdr#125).
		--
		-- Runs in a task so init() stays non-blocking. Custom arg types are registered by the server
		-- (`Cmdr:RegisterTypesIn`); CmdrClient auto-registers the replicated types on startup.
		task.spawn(function()
			local Cmdr = require(ReplicatedStorage:WaitForChild("CmdrClient"))
			Cmdr:SetActivationKeys({ Enum.KeyCode.F2, Enum.KeyCode.Backquote })
		end)
	end,
```

and delete the now-unused `local LocalPlayer = Players.LocalPlayer` and `local Players = game:GetService("Players")` lines.

- [ ] **Step 8: Register the shells' spec exemptions**

In `SpecRoots.luau` `EXEMPT_MODULES`, under the replication shells comment added in Task 9:

```luau
	["ReplicatedStorage.Client.Services.CharacterReplicationService.CharacterReplicationServiceClient"] = "network/Instance shell (cores are specced)",
	["ReplicatedStorage.Client.Services.CharacterReplicationService.OwnerRig"] = "Instance shell (needs a live rig, camera and Humanoid)",
	["ReplicatedStorage.Client.Services.AnimationService.LocomotionBinding"] = "Humanoid-event adapter (core is specced in LocomotionAnimator.spec)",
```

- [ ] **Step 9: Run the static checks and the tests**

Format, Lint, Typecheck, File length, Project rules. Studio test run: `UplinkSender.spec` passes; suite green.

- [ ] **Step 10: Studio check (developer, solo Play)**

You spawn at the SpawnLocation; walking, running, jumping and swimming feel native; the camera follows; locomotion animates; `LocomotionEnabled = false` on Workspace stops it and `true` restores it; F2 opens Cmdr at once and `PlayerGui` holds exactly one `Cmdr`; your rig has no child named `Animate`; the server command bar `print(game.Players:GetPlayers()[1].Character)` prints `nil`.

- [ ] **Step 11: Commit**

```bash
git add src/ReplicatedStorage/Client/Services/CharacterReplicationService src/ReplicatedStorage/Client/Services/AnimationService/LocomotionBinding.luau src/ReplicatedStorage/Client/Services/AdminService/AdminServiceClient.luau src/ServerScriptService/Modules/SpecRoots.luau default.project.json
git commit -m "feat(replication): owner rig, locomotion binding and the uplink sender

The client builds its rig from the server template on Spawn, assigns it as Character, binds
LocomotionAnimator itself (Animate.client.luau and the StarterCharacterScripts node are gone), mirrors
server health from the public slice, and streams send-on-change samples. Cmdr no longer waits for a
character the engine will never spawn."
```

---
### Task 11: Client viewer half — remote bodies and the puppet pool

**Runtime behaviour: yes** — other players appear as puppets: pooled rigs in the default look, unanimated, moved by one `BulkMoveTo` per frame from the interpolator on this client's render clock; hidden by moving them away when they leave relevance or their player leaves.

Carries the remaining R1 review items on the viewer side: the reliable slot table resets an epoch the buffer missed, and `isNew` / starving come from what the interpolator actually did.

**Files:**
- Create: `src/ReplicatedStorage/Client/Services/CharacterReplicationService/RemoteBodies.spec.luau`
- Create: `src/ReplicatedStorage/Client/Services/CharacterReplicationService/RemoteBodies.luau`
- Create: `src/ReplicatedStorage/Client/Services/CharacterReplicationService/PuppetPool.luau`
- Modify: `src/ReplicatedStorage/Client/Services/CharacterReplicationService/CharacterReplicationServiceClient.luau` (full replacement below)
- Modify: `src/ServerScriptService/Modules/SpecRoots.luau` (`EXEMPT_MODULES`)

**Interfaces:**
- Consumes: `CharacterBatchCodec.validate` (Task 3), `CharacterInterpolator` (`push` result, `isNewSample`, `resetEpoch`, `isStarving`, `evaluatePose`, `reckon`, `reachMs`; Task 2), `RenderClock` (`new`, `onBatch`, `noteFrame`, `advance`), packets `SlotEntry` / `Enter` / `Leave` / `Downlink` (Task 9), `AnimationRegistry.ids()`.
- Produces:
  - `RemoteBodies.MAX_RECKON_MS` (60)
  - `export type SlotEntry = { slot: number, userId: number, generation: number, epoch: number, active: boolean }`
  - `export type SlotChange = "added" | "replaced" | "released" | "epoch"`
  - `export type Body = { slot: number, userId: number, generation: number, epoch: number, samples: CharacterInterpolator.Buffer, hint: CharacterInterpolator.Hint, visible: boolean }`
  - `export type Stats = { batches: number, rejected: number, records: number, dropped: number, flushed: number, resets: number, newSamples: number, interpolate: number, extrapolate: number, hold: number, behind: number }`
  - `export type State = { localUserId: number, bodies: { [number]: Body }, clock: RenderClock.Clock, starving: boolean, delayMs: number, stats: Stats }`
  - `RemoteBodies.new(localUserId: number): State`
  - `RemoteBodies.applySlot(state: State, entry: SlotEntry): (SlotChange?, Body?)` — for `replaced` / `released` the Body is the OLD one
  - `RemoteBodies.enter(state: State, slot: number, generation: number, batchTimeMs: number, recordBytes: buffer): Body?`
  - `RemoteBodies.leave(state: State, slot: number, generation: number): Body?`
  - `RemoteBodies.onBatch(state: State, batch: buffer, arrivalMs: number, actionCount: number): boolean`
  - `RemoteBodies.frame(state: State, nowMs: number, outSlots: { number }, outCFrames: { CFrame }, groundBelow: ((position: Vector3) -> number)?): number`
  - `RemoteBodies.counts(state: State): (number, number)` — known, visible
  - `PuppetPool.HIDDEN_CFRAME`, `MAX_IDLE` (8); `export type Puppet = { model: Model, root: BasePart, humanoid: Humanoid }`; `export type Pool = { template: Model, container: Folder, idle: { Puppet }, buildsThisFrame: number, built: number }`
  - `PuppetPool.new(template: Model, container: Folder): Pool`, `beginFrame(pool: Pool)`, `acquire(pool: Pool, player: Player): Puppet?`, `release(pool: Pool, puppet: Puppet)`, `destroy(pool: Pool)`
  - `CharacterReplicationServiceClient:getState()` now also reports the viewer half (bodies, puppets, render delay, loss level, starving, counters) for the F4 Services tab (client context)

- [ ] **Step 1: Write the failing spec**

`RemoteBodies.spec.luau`:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Codec = require(ReplicatedStorage.Shared.Modules.CharacterReplication.CharacterRecordCodec)
local RemoteBodies = require(ReplicatedStorage.Client.Services.CharacterReplicationService.RemoteBodies)

local LOCAL_USER = 1
local OTHER = 2

local function record(overrides)
	local r = {
		slot = 5,
		generation = 1,
		epoch = 2,
		ageMs = 0,
		position = Vector3.new(-1228, 10, -363),
		yaw = 0.5,
		pitch = 0,
		velocity = Vector3.new(16, 0, 0),
		state = 8,
		grounded = true,
		hasAction = false,
		rotation = nil,
	}
	for key, value in overrides or {} do
		r[key] = value
	end
	return r
end

local function recordBytes(overrides)
	local b = buffer.create(Codec.RECORD_BYTES)
	Codec.writeRecord(b, 0, record(overrides))
	return b
end

local function batch(seq, batchTimeMs, list)
	local b = buffer.create(Codec.HEADER_BYTES + #list * Codec.RECORD_BYTES)
	Codec.writeHeader(b, 0, { seq = seq, batchTimeMs = batchTimeMs, count = #list })
	for i, overrides in list do
		Codec.writeRecord(b, Codec.HEADER_BYTES + (i - 1) * Codec.RECORD_BYTES, record(overrides))
	end
	return b
end

local function entry(overrides)
	local e = { slot = 5, userId = OTHER, generation = 1, epoch = 2, active = true }
	for key, value in overrides or {} do
		e[key] = value
	end
	return e
end

-- A state with slot 5 known and visible (its Enter sample at `enterMs`).
local function visibleState(enterMs)
	local state = RemoteBodies.new(LOCAL_USER)
	RemoteBodies.applySlot(state, entry())
	RemoteBodies.enter(state, 5, 1, enterMs or 1000, recordBytes())
	return state
end

return function()
	describe("slot table", function()
		it("adds a body for another player and ignores this client's own slot", function()
			local state = RemoteBodies.new(LOCAL_USER)
			expect(RemoteBodies.applySlot(state, entry())).to.equal("added")
			expect(RemoteBodies.applySlot(state, entry({ slot = 6, userId = LOCAL_USER }))).to.equal(nil)
			expect(state.bodies[6]).to.equal(nil)
			expect(state.bodies[5].visible).to.equal(false)
		end)

		it("a new generation on a slot replaces the body (a rejoiner inherits nothing)", function()
			local state = visibleState()
			local change, old = RemoteBodies.applySlot(state, entry({ generation = 2, userId = 3 }))
			expect(change).to.equal("replaced")
			expect(old.userId).to.equal(OTHER)
			expect(state.bodies[5].userId).to.equal(3)
			expect(state.bodies[5].visible).to.equal(false)
			expect(#state.bodies[5].samples.samples).to.equal(0)
		end)

		it("releases only the matching generation", function()
			local state = visibleState()
			expect(RemoteBodies.applySlot(state, entry({ generation = 0, active = false }))).to.equal(nil)
			expect(state.bodies[5]).to.be.ok()
			local change, old = RemoteBodies.applySlot(state, entry({ active = false }))
			expect(change).to.equal("released")
			expect(old.slot).to.equal(5)
			expect(state.bodies[5]).to.equal(nil)
		end)

		it("the slot table resets a buffer that missed an epoch bump", function()
			local state = visibleState(1000)
			-- Epoch 3's records were all lost; epoch 4's are dropped (not current + 1)...
			RemoteBodies.onBatch(state, batch(1, 1100, { { epoch = 4 } }), 1120, 0)
			expect(state.stats.dropped).to.equal(1)
			-- ...until the reliable slot table says epoch 4.
			expect(RemoteBodies.applySlot(state, entry({ epoch = 4 }))).to.equal("epoch")
			expect(state.stats.resets).to.equal(1)
			RemoteBodies.onBatch(state, batch(2, 1200, { { epoch = 4 } }), 1220, 0)
			expect(#state.bodies[5].samples.samples).to.equal(1)
		end)

		it("does not reset a buffer that already flushed to the announced epoch", function()
			local state = visibleState(1000)
			RemoteBodies.onBatch(state, batch(1, 1100, { { epoch = 3 } }), 1120, 0) -- current + 1: flushes
			RemoteBodies.applySlot(state, entry({ epoch = 3 }))
			expect(state.stats.resets).to.equal(0)
			expect(#state.bodies[5].samples.samples).to.equal(1)
		end)
	end)

	describe("enter and leave", function()
		it("enter shows the body with a fresh buffer holding the full-state sample", function()
			local state = RemoteBodies.new(LOCAL_USER)
			RemoteBodies.applySlot(state, entry())
			local body = RemoteBodies.enter(state, 5, 1, 1000, recordBytes({ ageMs = 30 }))
			expect(body.visible).to.equal(true)
			expect(#body.samples.samples).to.equal(1)
			expect(body.samples.samples[1].timeMs).to.equal(970)
		end)

		it("ignores an enter for an unknown slot or another generation", function()
			local state = RemoteBodies.new(LOCAL_USER)
			RemoteBodies.applySlot(state, entry())
			expect(RemoteBodies.enter(state, 7, 1, 1000, recordBytes())).to.equal(nil)
			expect(RemoteBodies.enter(state, 5, 2, 1000, recordBytes())).to.equal(nil)
		end)

		it("leave hides the body and forgets its samples", function()
			local state = visibleState()
			local body = RemoteBodies.leave(state, 5, 1)
			expect(body.visible).to.equal(false)
			expect(#body.samples.samples).to.equal(0)
		end)
	end)

	describe("batches", function()
		it("rejects a malformed batch and counts it", function()
			local state = visibleState()
			local b = batch(1, 1100, { {} })
			buffer.writeu8(b, 6, 2) -- claims two records, holds one
			expect(RemoteBodies.onBatch(state, b, 1120, 0)).to.equal(false)
			expect(state.stats.rejected).to.equal(1)
		end)

		it("drops records for unknown slots, hidden bodies and other generations", function()
			local state = visibleState()
			RemoteBodies.onBatch(state, batch(1, 1100, { { slot = 9 }, { generation = 2 } }), 1120, 0)
			RemoteBodies.leave(state, 5, 1)
			RemoteBodies.onBatch(state, batch(2, 1200, { {} }), 1220, 0)
			expect(state.stats.dropped).to.equal(3)
		end)

		it("lets only new samples vote on lateness", function()
			local state = visibleState(1000)
			RemoteBodies.onBatch(state, batch(1, 1100, { {} }), 1150, 0) -- new: lateness 50
			RemoteBodies.onBatch(state, batch(2, 1100, { {} }), 1300, 0) -- a resend of the same sample
			expect(state.stats.newSamples).to.equal(1)
			expect(#state.clock.lateness).to.equal(1)
			expect(state.clock.lateness[1]).to.equal(50)
		end)

		it("a restamped repair is a new sample with transit-only lateness", function()
			local state = visibleState(1000)
			-- A still body: the server restamps each repair to its batch time (age 0, zero velocity).
			RemoteBodies.onBatch(state, batch(1, 3000, { { velocity = Vector3.zero } }), 3040, 0)
			RemoteBodies.onBatch(state, batch(2, 4000, { { velocity = Vector3.zero } }), 4040, 0)
			expect(state.stats.newSamples).to.equal(2)
			expect(state.clock.lateness[1]).to.equal(40)
			expect(state.clock.lateness[2]).to.equal(40)
		end)
	end)

	describe("frame", function()
		it("places visible bodies at the interpolated pose, facing their yaw", function()
			local state = visibleState(1000)
			RemoteBodies.onBatch(state, batch(1, 1017, { { position = Vector3.new(-1227.73, 10, -363) } }), 1030, 0)
			state.clock.delayMs = 10 -- white-box: pin the delay (render time 1008.5, between the two samples)
			state.clock.targetMs = 10
			local slots, cframes = {}, {}
			local count = RemoteBodies.frame(state, 1018.5, slots, cframes, nil)
			expect(count).to.equal(1)
			expect(slots[1]).to.equal(5)
			expect(cframes[1].Position.X > -1228 and cframes[1].Position.X < -1227.7).to.equal(true)
			local look = cframes[1].LookVector
			expect(math.atan2(-look.X, -look.Z)).to.be.near(0.5, 0.03)
		end)

		it("skips hidden and empty bodies", function()
			local state = RemoteBodies.new(LOCAL_USER)
			RemoteBodies.applySlot(state, entry())
			local slots, cframes = {}, {}
			expect(RemoteBodies.frame(state, 1000, slots, cframes, nil)).to.equal(0)
		end)

		it("is starving only in hold, never when behind", function()
			local state = visibleState(1000)
			local slots, cframes = {}, {}
			state.clock.delayMs = 500 -- render time 500 ms before the only sample: behind
			state.clock.targetMs = 500
			RemoteBodies.frame(state, 1000, slots, cframes, nil)
			expect(state.starving).to.equal(false)
			state.clock.delayMs = 0 -- 300 ms past the only sample: hold
			state.clock.targetMs = 0
			RemoteBodies.frame(state, 1300, slots, cframes, nil)
			expect(state.starving).to.equal(true)
		end)
	end)
end
```

- [ ] **Step 2: Run the tests and verify they fail**

Studio test run. Expected: `RemoteBodies.spec` fails at `require`.

- [ ] **Step 3: Write `RemoteBodies.luau`**

```luau
--!strict
--[=[
	RemoteBodies: everything a viewer knows about other players' bodies (spec §6.4–§6.7; plan R2 Task 11).

	- The reliable SLOT TABLE (`applySlot`) says which player each slot is, in which generation and epoch.
	  A new generation replaces the body outright (a rejoiner inherits nothing). A newer epoch the buffer
	  never saw — its bump records were lost — resets the buffer to it (R1 review: the interpolator drops
	  any epoch other than current + 1, so only the reliable table can recover a lost bump).
	- `enter` / `leave` follow the server's visibility set; both start the buffer fresh, so a body that comes
	  back never slides from where it was last seen (spike CP10).
	- `onBatch` validates a downlink batch before decoding (CharacterBatchCodec), pushes each record into its
	  body, and gives the render clock ONE lateness vote: the largest among the batch's NEW samples
	  (`CharacterInterpolator.isNewSample` of what `push` did) — resends, repairs of held samples and
	  stragglers never vote.
	- `frame` advances the render clock (starving = some body was in `hold`; `behind` never counts), then
	  evaluates every visible body on the allocation-free path, dead-reckoning (gravity, ground) when it runs
	  past its newest sample.

	Pure: time is passed in (session ms); the caller supplies the ground query.

	@class RemoteBodies
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Replication = ReplicatedStorage.Shared.Modules.CharacterReplication
local CharacterRecordCodec = require(Replication.CharacterRecordCodec)
local CharacterBatchCodec = require(Replication.CharacterBatchCodec)
local CharacterInterpolator = require(Replication.CharacterInterpolator)
local RenderClock = require(Replication.RenderClock)

local RemoteBodies = {}

local MAX_RECKON_MS = 60
RemoteBodies.MAX_RECKON_MS = MAX_RECKON_MS

export type SlotEntry = {
	slot: number,
	userId: number,
	generation: number,
	epoch: number,
	active: boolean,
}

export type SlotChange = "added" | "replaced" | "released" | "epoch"

export type Body = {
	slot: number,
	userId: number,
	generation: number, -- low 2 bits, as on the wire
	epoch: number, -- full 8-bit epoch from the slot table
	samples: CharacterInterpolator.Buffer,
	hint: CharacterInterpolator.Hint,
	visible: boolean,
}

export type Stats = {
	batches: number,
	rejected: number,
	records: number,
	dropped: number,
	flushed: number,
	resets: number,
	newSamples: number,
	interpolate: number,
	extrapolate: number,
	hold: number,
	behind: number,
}

export type State = {
	localUserId: number,
	bodies: { [number]: Body }, -- by slot
	clock: RenderClock.Clock,
	starving: boolean,
	delayMs: number,
	stats: Stats,
}

function RemoteBodies.new(localUserId: number): State
	local clock = RenderClock.new()
	return {
		localUserId = localUserId,
		bodies = {},
		clock = clock,
		starving = false,
		delayMs = clock.delayMs,
		stats = {
			batches = 0,
			rejected = 0,
			records = 0,
			dropped = 0,
			flushed = 0,
			resets = 0,
			newSamples = 0,
			interpolate = 0,
			extrapolate = 0,
			hold = 0,
			behind = 0,
		},
	}
end

local function newBody(entry: SlotEntry): Body
	local samples = CharacterInterpolator.newBuffer()
	CharacterInterpolator.resetEpoch(samples, entry.epoch)
	return {
		slot = entry.slot,
		userId = entry.userId,
		generation = entry.generation % 4,
		epoch = entry.epoch,
		samples = samples,
		hint = CharacterInterpolator.newHint(),
		visible = false,
	}
end

local function sampleOf(record: CharacterRecordCodec.Record, timeMs: number): CharacterInterpolator.Sample
	return {
		timeMs = timeMs,
		position = record.position,
		velocity = record.velocity,
		yaw = record.yaw,
		state = record.state,
		grounded = record.grounded,
		rotation = record.rotation,
	}
end

--[=[
	Apply one slot-table row. Returns what changed; for "replaced" and "released" the body returned is the
	one that went away (the caller hides its puppet), otherwise the current body.
]=]
function RemoteBodies.applySlot(state: State, entry: SlotEntry): (SlotChange?, Body?)
	local existing = state.bodies[entry.slot]
	local generation = entry.generation % 4
	if not entry.active then
		if existing ~= nil and existing.generation == generation then
			state.bodies[entry.slot] = nil
			return "released", existing
		end
		return nil, nil
	end
	if entry.userId == state.localUserId then
		return nil, nil -- this client's own body is the owner rig, never a remote body
	end
	if existing == nil then
		state.bodies[entry.slot] = newBody(entry)
		return "added", nil
	end
	if existing.generation ~= generation or existing.userId ~= entry.userId then
		state.bodies[entry.slot] = newBody(entry)
		return "replaced", existing
	end
	if entry.epoch ~= existing.epoch then
		existing.epoch = entry.epoch
		if existing.samples.epoch ~= entry.epoch % 8 then
			CharacterInterpolator.resetEpoch(existing.samples, entry.epoch)
			state.stats.resets += 1
		end
		return "epoch", existing
	end
	return nil, existing
end

function RemoteBodies.enter(
	state: State,
	slot: number,
	generation: number,
	batchTimeMs: number,
	recordBytes: buffer
): Body?
	local body = state.bodies[slot]
	if body == nil or body.generation ~= generation % 4 or buffer.len(recordBytes) ~= CharacterRecordCodec.RECORD_BYTES then
		return nil
	end
	local record = CharacterRecordCodec.readRecord(recordBytes, 0)
	body.visible = true
	CharacterInterpolator.resetEpoch(body.samples, body.epoch)
	CharacterInterpolator.push(body.samples, record.epoch, sampleOf(record, batchTimeMs - record.ageMs))
	return body
end

function RemoteBodies.leave(state: State, slot: number, generation: number): Body?
	local body = state.bodies[slot]
	if body == nil or body.generation ~= generation % 4 then
		return nil
	end
	body.visible = false
	CharacterInterpolator.resetEpoch(body.samples, body.epoch)
	return body
end

function RemoteBodies.onBatch(state: State, batch: buffer, arrivalMs: number, actionCount: number): boolean
	local stats = state.stats
	if not CharacterBatchCodec.validate(batch, actionCount) then
		stats.rejected += 1
		return false
	end
	stats.batches += 1
	local header = CharacterRecordCodec.readHeader(batch, 0)
	local offset = CharacterRecordCodec.HEADER_BYTES
	local anyNew = false
	local worstLateness = 0
	for _ = 1, header.count do
		local record = CharacterRecordCodec.readRecord(batch, offset)
		offset += CharacterRecordCodec.recordBytes(record)
		stats.records += 1
		local body = state.bodies[record.slot]
		if body == nil or not body.visible or body.generation ~= record.generation then
			stats.dropped += 1
			continue
		end
		local sampleMs = header.batchTimeMs - record.ageMs
		-- Annotated: Luau widens a singleton-union return to `string` on an unannotated local.
		local result: CharacterInterpolator.PushResult =
			CharacterInterpolator.push(body.samples, record.epoch, sampleOf(record, sampleMs))
		if result == "dropped" then
			stats.dropped += 1
		elseif result == "flushed" then
			stats.flushed += 1
		end
		if CharacterInterpolator.isNewSample(result) then
			anyNew = true
			stats.newSamples += 1
			worstLateness = math.max(worstLateness, arrivalMs - sampleMs)
		end
	end
	RenderClock.onBatch(state.clock, arrivalMs, header.seq, worstLateness, anyNew)
	return true
end

--[=[
	One rendered frame: fills `outSlots[i]` / `outCFrames[i]` for each visible body with samples and returns
	the count. `groundBelow(position)` returns the standing root height under a position (or -math.huge).
]=]
function RemoteBodies.frame(
	state: State,
	nowMs: number,
	outSlots: { number },
	outCFrames: { CFrame },
	groundBelow: ((position: Vector3) -> number)?
): number
	local clock = state.clock
	RenderClock.noteFrame(clock, nowMs)
	local reach = math.huge
	for _, body in state.bodies do
		if body.visible then
			reach = math.min(reach, CharacterInterpolator.reachMs(body.samples, nowMs))
		end
	end
	local delay = RenderClock.advance(clock, nowMs, state.starving, reach)
	state.delayMs = delay
	local renderTime = nowMs - delay
	local stats = state.stats
	local starving = false
	local count = 0
	table.clear(outSlots)
	table.clear(outCFrames)
	for slot, body in state.bodies do
		if not body.visible then
			continue
		end
		local position: Vector3, yaw: number, mode: CharacterInterpolator.Mode =
			CharacterInterpolator.evaluatePose(body.samples, renderTime, body.hint)
		if mode == "empty" then
			continue
		end
		if CharacterInterpolator.isStarving(mode) then
			starving = true
		end
		if mode == "interpolate" then
			stats.interpolate += 1
		elseif mode == "extrapolate" then
			stats.extrapolate += 1
		elseif mode == "hold" then
			stats.hold += 1
		else
			stats.behind += 1
		end
		if mode == "extrapolate" or mode == "hold" then
			local reckoned = CharacterInterpolator.reckon(body.samples, renderTime, MAX_RECKON_MS, groundBelow)
			if reckoned ~= nil then
				position = reckoned
			end
		end
		count += 1
		outSlots[count] = slot
		outCFrames[count] = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	end
	state.starving = starving
	return count
end

function RemoteBodies.counts(state: State): (number, number)
	local known, visible = 0, 0
	for _, body in state.bodies do
		known += 1
		if body.visible then
			visible += 1
		end
	end
	return known, visible
end

return RemoteBodies
```

- [ ] **Step 4: Write `PuppetPool.luau`**

```luau
--!strict
--[=[
	PuppetPool: rigs that draw other players (spec §5.1 "Other clients"; Verdict: pooled, hidden by moving;
	plan R2 Task 11).

	Building a puppet costs 25–50 ms and unparenting/reparenting one 10–30 ms (the rig has ~109 parts, spike
	measurement), so puppets are POOLED and HIDDEN BY MOVING them far away, never by unparenting. At most one
	is built per frame (`beginFrame` resets the budget); a body waiting for one simply appears a frame later.

	A puppet: scripts stripped, every part non-colliding / non-query / non-touch, an anchored root moved by
	the client service's single BulkMoveTo, `EvaluateStateMachine = false`, the display name set per player.
	R2 draws the default look with no animation (R3 and R4 add them).

	Spec-exempt shell (Instances).

	@class PuppetPool
]=]

local PuppetPool = {}

PuppetPool.HIDDEN_CFRAME = CFrame.new(0, 50000, 0)
PuppetPool.MAX_IDLE = 8

export type Puppet = {
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
}

export type Pool = {
	template: Model,
	container: Folder,
	idle: { Puppet },
	buildsThisFrame: number,
	built: number,
}

function PuppetPool.new(template: Model, container: Folder): Pool
	return { template = template, container = container, idle = {}, buildsThisFrame = 0, built = 0 }
end

local function build(pool: Pool): Puppet?
	local model = pool.template:Clone()
	if not model:IsA("Model") then -- Instance:Clone() is typed Instance
		model:Destroy()
		return nil
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or not humanoid:IsA("Humanoid") or root == nil or not root:IsA("BasePart") then
		model:Destroy()
		return nil
	end
	humanoid.EvaluateStateMachine = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	root.Anchored = true
	model.Name = "Puppet"
	model:PivotTo(PuppetPool.HIDDEN_CFRAME)
	model.Parent = pool.container
	pool.built += 1
	return { model = model, root = root, humanoid = humanoid }
end

function PuppetPool.beginFrame(pool: Pool)
	pool.buildsThisFrame = 0
end

--[=[
	A puppet for `player`: an idle one, or a new one if this frame's build budget allows. Nil = try next frame.
]=]
function PuppetPool.acquire(pool: Pool, player: Player): Puppet?
	local puppet: Puppet? = table.remove(pool.idle)
	if puppet == nil then
		if pool.buildsThisFrame >= 1 then
			return nil
		end
		pool.buildsThisFrame += 1
		puppet = build(pool)
	end
	if puppet == nil then
		return nil
	end
	puppet.model.Name = player.Name
	puppet.humanoid.DisplayName = player.DisplayName
	return puppet
end

function PuppetPool.release(pool: Pool, puppet: Puppet)
	puppet.model:PivotTo(PuppetPool.HIDDEN_CFRAME)
	puppet.model.Name = "Puppet"
	puppet.humanoid.DisplayName = ""
	if #pool.idle >= PuppetPool.MAX_IDLE then
		puppet.model:Destroy()
	else
		table.insert(pool.idle, puppet)
	end
end

function PuppetPool.destroy(pool: Pool)
	for _, puppet in pool.idle do
		puppet.model:Destroy()
	end
	table.clear(pool.idle)
end

return PuppetPool
```

- [ ] **Step 5: Replace `CharacterReplicationServiceClient.luau` with the full version**

```luau
--!strict
--[=[
	CharacterReplicationServiceClient: this client's side of client-only bodies (spec 2026-09-22 §5.1 option A,
	§6; plan R2 Tasks 10–11).

	Owner half: on `Spawn` it builds the owner rig (OwnerRig) from `ReplicatedStorage.CharacterRigTemplate` and
	makes it `LocalPlayer.Character`; every Heartbeat it offers the rig's state to UplinkSender and sends the
	packets it returns.

	Viewer half: the slot table, enter/leave and downlink batches feed RemoteBodies; every PreRender it gives
	each visible body a pooled puppet (PuppetPool) and moves all puppets with ONE `Workspace:BulkMoveTo`.

	The handshake (`Ready`) goes once every listener is connected.

	Body API (docs/architecture.md, "Bodies"): `bodySpawned` / `bodyDespawned` (player, rig) fire for every rig
	this client shows — the owner rig and each puppet; `getRig(player)`, `getPlayerFromRig(rig)`,
	`getLocalRig()`. Find a body's player by id through this registry, never by instance name.

	Spec-exempt shell (network, Instances, RunService); its cores (UplinkSender, RemoteBodies) are specced.

	@class CharacterReplicationServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Modules.SignalTyped)
local AnimationRegistry = require(ReplicatedStorage.Shared.Modules.Constants.Animations.AnimationRegistry)
local CharacterReplicationEvents = require(ReplicatedStorage.Shared.Events.CharacterReplicationEvents)
local CharacterRecordCodec = require(ReplicatedStorage.Shared.Modules.CharacterReplication.CharacterRecordCodec)
local OwnerRig = require(script.Parent.OwnerRig)
local UplinkSender = require(script.Parent.UplinkSender)
local RemoteBodies = require(script.Parent.RemoteBodies)
local PuppetPool = require(script.Parent.PuppetPool)

local TEMPLATE_NAME = "CharacterRigTemplate"
local TEMPLATE_WAIT_SECONDS = 30
local PUPPET_FOLDER_NAME = "CharacterPuppets"
local GROUND_RAY_DEPTH = 50

type HeldPuppet = { puppet: PuppetPool.Puppet, player: Player }

local log = Logger.new("CharacterReplicationServiceClient")
local janitor = Janitor.new()

local template: Model? = nil
local sessionEpochSeconds: number? = nil
local ownerRig: OwnerRig.Rig? = nil
local buildSeq = 0
local sender = UplinkSender.new()
local remote: RemoteBodies.State? = nil
local pool: PuppetPool.Pool? = nil
local puppetFolder: Folder? = nil
local held: { [number]: HeldPuppet } = {} -- by slot
local rigsByUserId: { [number]: Model } = {}
local userIdsByRig: { [Model]: number } = {}
local placementSlots: { number } = {}
local placementCFrames: { CFrame } = {}
local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
local standingRootHeight = 0

local bodySpawned: SignalTyped.Signal<Player, Model> = SignalTyped.new()
local bodyDespawned: SignalTyped.Signal<Player, Model> = SignalTyped.new()

local function sessionNowMs(): number?
	local epochSeconds = sessionEpochSeconds
	if epochSeconds == nil then
		return nil
	end
	return (Workspace:GetServerTimeNow() - epochSeconds) * 1000
end

local function registerRig(player: Player, model: Model)
	rigsByUserId[player.UserId] = model
	userIdsByRig[model] = player.UserId
	bodySpawned:Fire(player, model)
end

local function unregisterRig(player: Player, model: Model)
	if rigsByUserId[player.UserId] == model then
		rigsByUserId[player.UserId] = nil
	end
	userIdsByRig[model] = nil
	bodyDespawned:Fire(player, model)
end

local function refreshGroundFilter()
	local exclude: { Instance } = {}
	local folder = puppetFolder
	if folder ~= nil then
		table.insert(exclude, folder)
	end
	local rig = ownerRig
	if rig ~= nil then
		table.insert(exclude, rig.model)
	end
	groundParams.FilterDescendantsInstances = exclude
end

local function adoptTemplate(found: Model)
	template = found
	local folder = Instance.new("Folder")
	folder.Name = PUPPET_FOLDER_NAME
	folder.Parent = Workspace
	puppetFolder = folder
	janitor:Add(folder, "Destroy")
	pool = PuppetPool.new(found, folder)
	local humanoid = found:FindFirstChildOfClass("Humanoid")
	local root = found:FindFirstChild("HumanoidRootPart")
	if humanoid ~= nil and humanoid:IsA("Humanoid") and root ~= nil and root:IsA("BasePart") then
		-- The root's height above the floor when standing: what dead reckoning holds a body at.
		standingRootHeight = humanoid.HipHeight + root.Size.Y / 2
	end
	refreshGroundFilter()
end

local function awaitTemplate(): Model?
	if template == nil then
		local found = ReplicatedStorage:WaitForChild(TEMPLATE_NAME, TEMPLATE_WAIT_SECONDS)
		-- Re-check after the wait: init's warm-up and a Spawn can both be waiting here.
		if template == nil and found ~= nil and found:IsA("Model") then
			adoptTemplate(found)
		end
	end
	return template
end

local function groundBelow(position: Vector3): number
	local hit = Workspace:Raycast(position, Vector3.new(0, -GROUND_RAY_DEPTH, 0), groundParams)
	return if hit ~= nil then hit.Position.Y + standingRootHeight else -math.huge
end

local function dropOwnerRig()
	local rig = ownerRig
	if rig == nil then
		return
	end
	ownerRig = nil
	unregisterRig(Players.LocalPlayer, rig.model)
	OwnerRig.destroy(rig)
end

local function buildOwnerRig(position: Vector3, epoch: number)
	buildSeq += 1
	local mine = buildSeq
	local rigTemplate = awaitTemplate()
	if mine ~= buildSeq then
		return -- a newer Spawn arrived while waiting for the template
	end
	if rigTemplate == nil then
		log:error(`{TEMPLATE_NAME} never replicated; no body`)
		return
	end
	dropOwnerRig()
	local rig, err = OwnerRig.build(rigTemplate, position, epoch, function()
		CharacterReplicationEvents.packets.RespawnRequest.send(true)
	end)
	if rig == nil then
		log:error(`owner rig build failed: {err or "unknown"}`)
		return
	end
	ownerRig = rig
	UplinkSender.reset(sender)
	registerRig(Players.LocalPlayer, rig.model)
	refreshGroundFilter()
	log:info(`owner rig built (epoch {epoch})`)
end

local function sampleOwner()
	local rig = ownerRig
	local nowMs = sessionNowMs()
	if rig == nil or nowMs == nil or rig.root.Parent == nil then
		return
	end
	local cframe = rig.root.CFrame
	local look = cframe.LookVector
	local state = rig.humanoid:GetState()
	local record: CharacterRecordCodec.Record = {
		slot = 0, -- the server addresses bodies by the sender, not by these fields
		generation = 0,
		epoch = rig.epoch,
		ageMs = 0,
		position = cframe.Position,
		yaw = math.atan2(-look.X, -look.Z),
		pitch = 0,
		velocity = rig.root.AssemblyLinearVelocity,
		state = state.Value % 32,
		grounded = UplinkSender.isGrounded(state, rig.humanoid.FloorMaterial),
		hasAction = false,
		rotation = nil,
	}
	local packet = UplinkSender.step(sender, math.floor(nowMs), record)
	if packet ~= nil then
		CharacterReplicationEvents.packets.Uplink.send(packet)
	end
end

local function releasePuppet(slot: number)
	local entry = held[slot]
	if entry == nil then
		return
	end
	held[slot] = nil
	unregisterRig(entry.player, entry.puppet.model)
	local activePool = pool
	if activePool ~= nil then
		PuppetPool.release(activePool, entry.puppet)
	end
end

local function renderPuppets()
	local state = remote
	local activePool = pool
	local nowMs = sessionNowMs()
	if state == nil or activePool == nil or nowMs == nil then
		return
	end
	PuppetPool.beginFrame(activePool)
	for slot, body in state.bodies do
		if body.visible and held[slot] == nil then
			local player = Players:GetPlayerByUserId(body.userId)
			if player ~= nil then
				local puppet = PuppetPool.acquire(activePool, player)
				if puppet ~= nil then
					held[slot] = { puppet = puppet, player = player }
					registerRig(player, puppet.model)
				end
			end
		end
	end
	local count = RemoteBodies.frame(state, nowMs, placementSlots, placementCFrames, groundBelow)
	table.clear(moveParts)
	table.clear(moveCFrames)
	for i = 1, count do
		local entry = held[placementSlots[i]]
		if entry ~= nil then
			table.insert(moveParts, entry.puppet.root)
			table.insert(moveCFrames, placementCFrames[i])
		end
	end
	if #moveParts > 0 then
		Workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

export type CharacterReplicationServiceClient = {
	dependencies: { string },
	init: (self: CharacterReplicationServiceClient) -> (),
	stop: (self: CharacterReplicationServiceClient) -> (),
	bodySpawned: SignalTyped.Signal<Player, Model>,
	bodyDespawned: SignalTyped.Signal<Player, Model>,
	getRig: (self: CharacterReplicationServiceClient, player: Player) -> Model?,
	getPlayerFromRig: (self: CharacterReplicationServiceClient, rig: Model) -> Player?,
	getLocalRig: (self: CharacterReplicationServiceClient) -> Model?,
	getState: (self: CharacterReplicationServiceClient) -> { [string]: any },
}

local CharacterReplicationServiceClient: CharacterReplicationServiceClient = {
	dependencies = {},
	bodySpawned = bodySpawned,
	bodyDespawned = bodyDespawned,

	init = function(_self)
		local state = RemoteBodies.new(Players.LocalPlayer.UserId)
		remote = state
		local actionCount = #AnimationRegistry.ids()
		local packets = CharacterReplicationEvents.packets

		packets.Session.listen(function(data)
			sessionEpochSeconds = data.epochSeconds
		end)
		packets.Spawn.listen(function(data)
			task.spawn(buildOwnerRig, data.position, data.epoch)
		end)
		packets.SlotEntry.listen(function(entry)
			local change = RemoteBodies.applySlot(state, entry)
			if change == "replaced" or change == "released" then
				releasePuppet(entry.slot)
			end
		end)
		packets.Enter.listen(function(data)
			RemoteBodies.enter(state, data.slot, data.generation, data.batchTimeMs, data.record)
		end)
		packets.Leave.listen(function(data)
			if RemoteBodies.leave(state, data.slot, data.generation) ~= nil then
				releasePuppet(data.slot)
			end
		end)
		packets.Downlink.listen(function(batch)
			local nowMs = sessionNowMs()
			if nowMs ~= nil then
				RemoteBodies.onBatch(state, batch, nowMs, actionCount)
			end
		end)

		janitor:Add(RunService.Heartbeat:Connect(sampleOwner), "Disconnect")
		janitor:Add(RunService.PreRender:Connect(renderPuppets), "Disconnect")
		janitor:Add(dropOwnerRig, true)
		janitor:Add(function()
			for slot in held do
				releasePuppet(slot)
			end
			local activePool = pool
			if activePool ~= nil then
				PuppetPool.destroy(activePool)
			end
		end, true)
		task.spawn(awaitTemplate) -- the pool and the puppet folder are ready before the first body
		-- Every listener is connected: ask for the session, the slot table and a body.
		packets.Ready.send(true)
	end,

	stop = function(_self)
		janitor:Cleanup()
	end,

	getRig = function(_self, player)
		return rigsByUserId[player.UserId]
	end,

	getPlayerFromRig = function(_self, rig)
		local userId = userIdsByRig[rig]
		return if userId ~= nil then Players:GetPlayerByUserId(userId) else nil
	end,

	getLocalRig = function(_self)
		local rig = ownerRig
		return if rig ~= nil then rig.model else nil
	end,

	--[=[
		This client's replication view, for the F4 Services tab (client context).
	]=]
	getState = function(_self)
		local state = remote
		local activePool = pool
		local rig = ownerRig
		local puppets = 0
		for _ in held do
			puppets += 1
		end
		local current = state or RemoteBodies.new(0) -- before init: an empty view
		local known, visible = RemoteBodies.counts(current)
		return {
			hasSession = sessionEpochSeconds ~= nil,
			ownerEpoch = if rig ~= nil then rig.epoch else nil,
			uplinkPackets = sender.sent,
			knownBodies = known,
			visibleBodies = visible,
			puppets = puppets,
			pooledPuppets = if activePool ~= nil then #activePool.idle else 0,
			builtPuppets = if activePool ~= nil then activePool.built else 0,
			delayMs = math.floor(current.delayMs + 0.5),
			lossLevel = current.clock.lossLevel,
			starving = current.starving,
			counters = table.clone(current.stats),
		}
	end,
}

return CharacterReplicationServiceClient
```

- [ ] **Step 6: Register the pool's spec exemption**

In `SpecRoots.luau` `EXEMPT_MODULES`, with the other replication shells:

```luau
	["ReplicatedStorage.Client.Services.CharacterReplicationService.PuppetPool"] = "Instance shell (builds and moves rigs)",
```

- [ ] **Step 7: Run the static checks and the tests**

Format, Lint, Typecheck, File length (the client service must stay under 400 code lines), Project rules. Studio test run: `RemoteBodies.spec` passes; suite green.

- [ ] **Step 8: Studio check (developer, Test → Clients and Servers, 2 players)**

Each client sees the other as a puppet in the default look (unanimated), moving smoothly and facing the way it faces; nobody sees a puppet of themselves; `Workspace.CharacterPuppets` holds one shown puppet per visible player; walking more than 630 studs apart hides the puppet (moved to the hidden spot, still in the folder) and walking back within 600 shows it again without sliding from where it was; client 2 leaving removes its puppet on client 1 (returned to the pool), and rejoining brings a fresh one.

- [ ] **Step 9: Commit**

```bash
git add src/ReplicatedStorage/Client/Services/CharacterReplicationService src/ServerScriptService/Modules/SpecRoots.luau
git commit -m "feat(replication): remote bodies and pooled puppets on every viewer

RemoteBodies follows the reliable slot table (a new generation replaces, a missed epoch resets),
enter/leave and validated batches, and votes lateness only for new samples. Puppets are pooled,
built one per frame, hidden by moving, and moved with one BulkMoveTo per frame."
```

---
### Task 12: Lifecycle rewires onto the body API, and the docs

**Runtime behaviour: yes** — `switchslot` respawns the client-built body instead of spawning an engine character over it (spike CP10: `LoadCharacter` spawns one even with `CharacterAutoLoads` off); maximum health follows stats and gear onto the body (mirrored on the owner's Humanoid); the default-appearance backfill runs on body spawn and the server no longer dresses a character; `tuneoffset` explains why it cannot nudge until R4; the F4 State tab highlights the selected player's rig through the body API.

**Files:**
- Modify: `src/ServerScriptService/Services/SlotService/SlotServiceServer.luau` and its spec
- Modify: `src/ServerScriptService/Services/StatsService/StatsServiceServer.luau` and its spec
- Modify: `src/ServerScriptService/Services/CustomizationService/CustomizationServiceServer.luau` and its spec header
- Modify: `src/ServerScriptService/Commands/TuneOffsetServer.luau` and its spec (full replacements)
- Modify: `src/ReplicatedStorage/Client/UI/React/Debugger/StatePanel.luau:198-221` (rig highlight)
- Modify: `docs/architecture.md`, `docs/animation.md:24`, `docs/conventions.md:775-776`, `AGENTS.md:104-109`

**Interfaces:**
- Consumes: `CharacterReplicationServiceServer:respawn`, `:observeBodies`, `:setMaxHealth` (Task 9); `CharacterReplicationServiceClient:getRig` (Task 10/11).
- Produces:
  - `StatsServiceServer:applyToBody(userId: number)` (replaces `applyToCharacter(player)`)
  - `CustomizationServiceServer.applyToCharacter` is removed
  - `SlotServiceServer:switchSlot` keeps `(boolean, string?)`; `true` = committed, mirrored and a respawn requested

- [ ] **Step 1: Update the specs first**

**SlotService spec** (`SlotServiceServer.spec.luau`):

Add the require after `local SlotService = ...`:

```luau
local CharacterReplicationService =
	require(ServerScriptService.Services.CharacterReplicationService.CharacterReplicationServiceServer)
```

Replace the `fakePlayer` helper and its comment with:

```luau
-- The narrow Player surface switchSlot uses: UserId. The respawn itself goes through
-- CharacterReplicationServiceServer:respawn, patched below to count calls per user — every rejection path
-- asserts zero respawns, which proves we never respawn a player we are about to refuse.
local function fakePlayer(userId: number)
	return { UserId = userId }
end

local respawnCalls: { [number]: number } = {}

local function respawns(userId: number): number
	return respawnCalls[userId] or 0
end
```

Inside `describe("SlotServiceServer", ...)`: declare `local _origRespawn` next to the other `_orig…` locals; at the end of `beforeAll` add

```luau
			_origRespawn = CharacterReplicationService.respawn
			CharacterReplicationService.respawn = function(_self: any, player: any, _reason: string): boolean
				respawnCalls[player.UserId] = respawns(player.UserId) + 1
				return true
			end
```

at the end of `afterAll` add `CharacterReplicationService.respawn = _origRespawn`, and at the top of the `describe("switchSlot", ...)` block add

```luau
			beforeEach(function()
				table.clear(respawnCalls)
			end)
```

Then in the `switchSlot` tests replace every `player.loadCharacterCalls` with `respawns(player.UserId)`, and rename the first test to `"switches to an unlocked slot and respawns the body"`.

**Stats spec** (`StatsServiceServer.spec.luau`):

Add the require after `local StatsService = ...`:

```luau
local CharacterReplicationService =
	require(ServerScriptService.Services.CharacterReplicationService.CharacterReplicationServiceServer)
```

Replace the `makeHumanoid` and `makeFakePlayer` helpers (and their comments) with:

```luau
-- applyToBody pushes the derived maximum health to the replication service (bodies are client-only; the
-- server holds health on the body). The spec captures those calls, patched in beforeAll.
local maxHealthCalls: { { userId: number, maxHealth: number } } = {}

local function lastMaxHealth(userId: number): number?
	for i = #maxHealthCalls, 1, -1 do
		if maxHealthCalls[i].userId == userId then
			return maxHealthCalls[i].maxHealth
		end
	end
	return nil
end
```

Declare `local _origSetMaxHealth` with the other `_orig…` locals; at the end of `beforeAll` add

```luau
			_origSetMaxHealth = CharacterReplicationService.setMaxHealth
			CharacterReplicationService.setMaxHealth = function(_self: any, userId: number, maxHealth: number)
				table.insert(maxHealthCalls, { userId = userId, maxHealth = maxHealth })
			end
```

at the end of `afterAll` add `CharacterReplicationService.setMaxHealth = _origSetMaxHealth`, and in `beforeEach` add `table.clear(maxHealthCalls)`.

Replace the whole `describe("applyToCharacter", ...)` block with:

```luau
		describe("applyToBody", function()
			it("pushes the derived health as the body's maximum", function()
				_profiles[1] = makeProfile(250, { health = 2 }) -- derived health = 210
				StatsService:applyToBody(1)
				expect(lastMaxHealth(1)).to.equal(210)
			end)

			it("pushes nothing when the profile is not loaded", function()
				StatsService:applyToBody(424242)
				expect(lastMaxHealth(424242)).to.equal(nil)
			end)
		end)
```

Replace the whole `describe("mirror subscription (equipment)", ...)` block (and its leading comment) with:

```luau
		-- -------------------------------------------------------------------------
		-- Exercises the EXACT subscription primitives start() wires — Charm.computed wrapping
		-- ServerStore.getterFor, Charm.subscribe calling applyToBody — against the real ServerStore/Charm
		-- machinery. start() wraps this in CharacterReplicationServiceServer:observeBodies, which needs a live
		-- body (Studio checklist); this still proves the reactive wiring fires on a real atom write and is
		-- player-isolated.
		describe("mirror subscription (equipment)", function()
			beforeEach(function()
				ServerStore.remove(1)
				ServerStore.remove(2)
			end)

			afterEach(function()
				ServerStore.remove(1)
				ServerStore.remove(2)
			end)

			it("applyToBody re-runs when the equipment slice changes for a live body", function()
				_profiles[1] = makeProfile(0, {})
				local readEquipment = ServerStore.getterFor("equipment", 1)
				local equipmentSelector = Charm.computed(function(_previous)
					return readEquipment()
				end)
				local unsubscribe = Charm.subscribe(equipmentSelector, function()
					StatsService:applyToBody(1)
				end)

				-- The mirroring write PlayerDataService performs after a committed equip(): the only thing
				-- that calls applyToBody here is the subscription.
				ServerStore.set(
					"equipment",
					1,
					{ slots = { pauldrons = { itemType = TEST_HEALTH_CHARM_ITEM_TYPE, uid = "hc1" } } }
				)

				expect(lastMaxHealth(1)).to.equal(StatConstants.DEFINITIONS.health.base + 20) -- 200 + charm's bonus
				unsubscribe()
			end)

			it("does NOT re-apply for an unrelated player's equipment change", function()
				_profiles[1] = makeProfile(0, {})
				_profiles[2] = makeProfile(0, {})
				local readEquipmentB = ServerStore.getterFor("equipment", 2)
				local equipmentSelectorB = Charm.computed(function(_previous)
					return readEquipmentB()
				end)
				local unsubscribeB = Charm.subscribe(equipmentSelectorB, function()
					StatsService:applyToBody(2)
				end)

				ServerStore.set(
					"equipment",
					1,
					{ slots = { pauldrons = { itemType = TEST_HEALTH_CHARM_ITEM_TYPE, uid = "hc1" } } }
				)

				expect(lastMaxHealth(2)).to.equal(nil) -- no callback fired for player 2
				unsubscribeB()
			end)
		end)
```

In the `describe("getState", ...)` leading comment, replace "start()'s `Observers.observeCharacter` callback" with "start()'s `observeBodies` callback" and "the local player's real character has already triggered the observer" with "the local player's body has already triggered the observer".

**TuneOffset spec** — replace `src/ServerScriptService/Commands/TuneOffsetServer.spec.luau` with:

```luau
--!strict
--[=[
	Unit tests for the TuneOffset Cmdr command implementation. Until client-side appearance lands (character
	replication R4) the command cannot nudge anything — bodies are client-only and undressed — so what is
	covered is the refusal and the REGISTRY SNIPPET, the command's lasting deliverable: a tuning pass
	produces a number a human pastes into the catalog.
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local tuneOffsetCommand = require(ServerScriptService.Commands.TuneOffsetServer)

return function()
	describe("TuneOffsetServer", function()
		local fakePlayer = { Name = "TestPlayer" } :: any

		it("says nothing was nudged, and why", function()
			local message = tuneOffsetCommand(nil, fakePlayer, "Eyebrows4", 0, 0.25, 0, 0, 0, 0)
			expect(message:find("Nothing was nudged on TestPlayer", 1, true)).to.be.ok()
			expect(message:find("R4", 1, true)).to.be.ok()
		end)

		it("refuses a non-finite component rather than composing a corrupt CFrame", function()
			local nan = 0 / 0
			expect(tuneOffsetCommand(nil, fakePlayer, "Eyebrows4", nan, 0, 0, 0, 0, 0):find("finite", 1, true)).to.be.ok()
			expect(tuneOffsetCommand(nil, fakePlayer, "Eyebrows4", math.huge, 0, 0, 0, 0, 0):find("finite", 1, true)).to.be.ok()
		end)

		-- The snippet omits zeros: a catalog row should record what was DECIDED, not six numbers where
		-- five are noise.
		it("prints a paste-ready registry snippet carrying only the non-zero axes", function()
			local message = tuneOffsetCommand(nil, fakePlayer, "Eyebrows4", 0, 0.25, 0, 0, 0, 0)
			expect(message:find("offset = { y = 0.25 }", 1, true)).to.be.ok()
			expect(message:find("x =", 1, true)).to.equal(nil)
		end)

		it("prints every supplied axis, in a stable order", function()
			local message = tuneOffsetCommand(nil, fakePlayer, "Eyebrows4", 1, 2, 3, 0, 0, 45)
			expect(message:find("offset = { x = 1, y = 2, z = 3, rz = 45 }", 1, true)).to.be.ok()
		end)

		it("prints an empty offset when every axis is zero", function()
			local message = tuneOffsetCommand(nil, fakePlayer, "Eyebrows4", 0, 0, 0, 0, 0, 0)
			expect(message:find("offset = {}", 1, true)).to.be.ok()
		end)
	end)
end
```

**Customization spec** — in the header of `CustomizationServiceServer.spec.luau`, replace the paragraph that starts "The `observeCharacter` application seam is NOT driven here" with:

```
	The `observeBodies` default-backfill seam is NOT driven here — it needs a live body from
	CharacterReplicationServiceServer (Studio checklist). Appearance is not applied server-side under
	client-only bodies; R4 applies it on the client, and the logic deciding WHAT to apply is fully specced
	in CustomizationPlan.spec.
```

- [ ] **Step 2: Run the tests and verify they fail**

Studio test run. Expected failures: the `switchSlot` tests (`respawns` stays 0 — `LoadCharacter` is still called on a fake without that method, which also throws), `applyToBody` and the mirror-subscription tests (method missing), and `says nothing was nudged, and why`.

- [ ] **Step 3: Rewire `SlotServiceServer`**

Add the require after `local ServerStore = ...`:

```luau
local CharacterReplicationService =
	require(ServerScriptService.Services.CharacterReplicationService.CharacterReplicationServiceServer)
```

Set `dependencies = { "PlayerDataServiceServer", "CharacterReplicationServiceServer" },`.

In the `switchSlot` doc comment, replace

```
		EVERY rejection is decided BEFORE the first side effect. The character is despawned only once
		the switch is certain: discovering a refusal after LoadCharacter() would leave the player
		standing in the wrong body, or in none.
```

with

```
		EVERY rejection is decided BEFORE the first side effect. The body is respawned only once the
		switch is certain: discovering a refusal after the respawn would leave the player standing in
		the wrong body, or in none.
```

replace `@param player Player -- The switching player (needed for LoadCharacter)` with `@param player Player -- The switching player (their body is respawned)`, and replace the `@return` note

```
		@return (boolean, string?) -- Success, plus a human-readable reason when refused. NOTE: `true`
			means the switch was committed and mirrored, NOT that the new character exists yet —
			LoadCharacter() below does not yield, so the respawn is still in flight when this returns.
```

with

```
		@return (boolean, string?) -- Success, plus a human-readable reason when refused. NOTE: `true`
			means the switch was committed and mirrored and a respawn was requested, NOT that the new
			body exists yet — the respawn does not yield; the owner rebuilds its rig when the server's
			Spawn reaches it.
```

Replace the tail of `switchSlot` (the "Respawn LAST" comment, `player:LoadCharacter()` and `return true`) with:

```luau
		-- Respawn LAST: the profile and the mirror already describe the new character, so the new body
		-- spawns into correct state. Bodies are client-only (character replication): the replication
		-- service bumps the body epoch, picks the spawn, and tells the owner to rebuild its rig. It does not
		-- yield — the same contract LoadCharacter() had, without the engine character LoadCharacter would
		-- spawn over the client-built rig even with CharacterAutoLoads off (spec CP10). A respawn refused
		-- because the previous one was under 250 ms ago is fine: that body is already fresh.
		CharacterReplicationService:respawn(player, "slot switch")
		return true
```

- [ ] **Step 4: Rewire `StatsServiceServer`**

Replace `local Observers = require(ReplicatedStorage.Packages.Observers)` with nothing (delete it) and add after `local ServerStore = ...`:

```luau
local CharacterReplicationService =
	require(ServerScriptService.Services.CharacterReplicationService.CharacterReplicationServiceServer)
```

Replace the `activeSubscriptions` comment with:

```luau
-- Diagnostic counter for getState: how many live Charm.subscribe pairs start()'s observeBodies callback
-- currently holds (one pair per live body). Incremented at the top of the callback, decremented in its
-- returned cleanup — see start() below.
```

In the `StatsServiceServer` type, replace `applyToCharacter: (self: StatsServiceServer, player: Player) -> (),` with:

```luau
	applyToBody: (self: StatsServiceServer, userId: number) -> (),
```

Set `dependencies = { "PlayerDataServiceServer", "CharacterReplicationServiceServer" },`.

Replace the whole `start` field (doc comment included) with:

```luau
	--[=[
		Wires the body's maximum health to every body spawn AND to every later change in the "stats" or
		"equipment" mirror. Bodies are client-only (character replication): the server holds health on the
		body and the owner mirrors it onto its Humanoid, so this pushes the derived maximum to
		CharacterReplicationServiceServer instead of writing a Humanoid. `observeBodies` replays live bodies,
		so one that spawned before this start() is covered. Any committed write to either slice, through ANY
		path, re-derives and re-applies. `Charm.computed` wraps `ServerStore.getterFor`'s zero-arg reader
		because `computed`'s getter takes one parameter; `Charm.subscribe` fires only on an actual change,
		synchronously inside the write. Both subscriptions are torn down when the body despawns.
		@param self StatsServiceServer -- The service instance
	]=]
	start = function(self)
		janitor:Add(
			CharacterReplicationService:observeBodies(function(player, _epoch)
				activeSubscriptions += 1
				local userId = player.UserId
				self:applyToBody(userId)

				local readStats = ServerStore.getterFor("stats", userId)
				local readEquipment = ServerStore.getterFor("equipment", userId)
				local statsSelector = Charm.computed(function(_previous)
					return readStats()
				end)
				local equipmentSelector = Charm.computed(function(_previous)
					return readEquipment()
				end)
				local unsubStats = Charm.subscribe(statsSelector, function()
					self:applyToBody(userId)
				end)
				local unsubEquipment = Charm.subscribe(equipmentSelector, function()
					self:applyToBody(userId)
				end)

				return function()
					unsubStats()
					unsubEquipment()
					activeSubscriptions -= 1
				end
			end),
			true
		)
		log:debug("StatsServiceServer started")
	end,
```

Replace the whole `applyToCharacter` field (doc comment included) with:

```luau
	--[=[
		Pushes the player's derived health to their body as its maximum. The replication service clamps
		current health DOWN to it (never heals up) and publishes it; the owner's Humanoid mirrors it. An
		unloaded profile is a no-op.
		@param userId number -- The player whose body to update
	]=]
	applyToBody = function(self, userId)
		local derived = self:getDerived(userId)
		if not derived then
			return
		end
		CharacterReplicationService:setMaxHealth(userId, derived.health)
	end,
```

In the `getState` doc comment, replace "start()'s observeCharacter callback currently holds" with "start()'s observeBodies callback currently holds".

- [ ] **Step 5: Rewire `CustomizationServiceServer`**

Delete the requires of `Observers`, `Charm`, `CustomizationPlan`, `CustomizationApplication` and `ServerStore` (each is now unused), and add after `local PlayerDataService = ...`:

```luau
local CharacterReplicationService =
	require(ServerScriptService.Services.CharacterReplicationService.CharacterReplicationServiceServer)
```

Set `dependencies = { "PlayerDataServiceServer", "CharacterReplicationServiceServer" },`.

Delete `applyToCharacter: (self: CustomizationServiceServer, player: Player) -> (),` from the type, and delete the whole `applyToCharacter` field (doc comment included) from the literal.

Replace the whole `start` field (doc comment included) with:

```luau
	--[=[
		Backfills the active character's appearance defaults whenever their body spawns, BEFORE anyone draws
		it: a profile predating a default (e.g. one saved before shoes had one) spawns complete rather than
		waiting for an unrelated setHeadType to fix it. The mutation no-ops for anyone already filled, and
		flows through the validated path like every other write.

		The server does not dress bodies: under client-only bodies (character replication) every rig is
		built on a client, and appearance is applied there from the public slice (R4). Until then bodies
		render in the default look.
		@param _self CustomizationServiceServer -- The service instance
	]=]
	start = function(_self)
		janitor:Add(
			CharacterReplicationService:observeBodies(function(player, _epoch)
				appearanceSlice.mutate(player.UserId, function(appearance)
					return CustomizationCompatibility.fillEmptyDefaults(appearance)
				end)
				return nil
			end),
			true
		)
		log:debug("CustomizationServiceServer started")
	end,
```

In the `stop` doc comment, replace "Tears down the character/mirror subscriptions." with "Tears down the body observer."

- [ ] **Step 6: Replace `TuneOffsetServer.luau`**

```luau
--!strict
--[=[
	tuneoffset (Cmdr): nudge an equipped cosmetic's fit and print the registry value to paste.

	Character replication R2: bodies are client-only and render in the default look until client-side
	appearance lands (R4). There is no server rig to nudge and no cosmetic mounted anywhere, so the command
	validates the numbers, prints the registry value they make, and says why nothing moved. R4 routes the
	nudge to a client-side preview.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomizationPlan = require(ReplicatedStorage.Shared.Modules.CustomizationPlan)

-- Formats the tuned value as the exact registry literal to paste, omitting zero components so the
-- catalog records only what was actually decided. Typing the number back in by hand is the POINT:
-- the registry is the source of truth, and a value that never lands in a commit never gets reviewed.
local function registrySnippet(x: number, y: number, z: number, rx: number, ry: number, rz: number): string
	-- Named fields rather than positional pairs: a mixed { string, number } array has no honest single
	-- element type, and forcing one would need exactly the kind of cast this project refuses.
	local axes: { { key: string, value: number } } = {
		{ key = "x", value = x },
		{ key = "y", value = y },
		{ key = "z", value = z },
		{ key = "rx", value = rx },
		{ key = "ry", value = ry },
		{ key = "rz", value = rz },
	}
	local parts: { string } = {}
	for _, axis in axes do
		if axis.value ~= 0 then
			table.insert(parts, `{axis.key} = {axis.value}`)
		end
	end
	if #parts == 0 then
		return "offset = {}"
	end
	-- Concatenation, not interpolation: `{` has meaning inside a Luau interpolated string, and the
	-- whole output here is literal braces.
	return "offset = { " .. table.concat(parts, ", ") .. " }"
end

return function(
	_context,
	target: Player,
	id: string,
	x: number,
	y: number,
	z: number,
	rx: number,
	ry: number,
	rz: number
)
	-- A non-finite component would produce a CFrame that silently corrupts every position derived from
	-- it, and NaN compares unequal to itself so it would not even be visible as a wrong number.
	for _, axis in { x, y, z, rx, ry, rz } do
		if axis ~= axis or axis == math.huge or axis == -math.huge then
			return "Offset components must be finite numbers."
		end
	end

	local offset = CustomizationPlan.composeOffset({ x = x, y = y, z = z, rx = rx, ry = ry, rz = rz })
	if not offset then
		return "No offset given."
	end

	return `Nothing was nudged on {target.Name}: bodies render in the default look until client-side appearance lands (character replication R4), so no "{id}" is mounted anywhere. Registry value for these numbers:\n    {registrySnippet(
		x,
		y,
		z,
		rx,
		ry,
		rz
	)}`
end
```

- [ ] **Step 7: Highlight rigs through the body API in the State tab**

In `StatePanel.luau`, add the require after `local DebuggerState = ...`:

```luau
local CharacterReplicationServiceClient =
	require(ReplicatedStorage.Client.Services.CharacterReplicationService.CharacterReplicationServiceClient)
```

and in the highlight `React.useEffect`, replace

```luau
		local player = Players:GetPlayerByUserId(effectiveSelected)
		local character = player and player.Character
		if not character then
			-- No character yet (respawning / not spawned): skip. The effect keys only off the userId,
			-- so a later spawn won't re-run it — reselecting the player reapplies the highlight, a fine
			-- tradeoff for a debug overlay versus wiring up CharacterAdded listeners here.
			return
		end
```

with

```luau
		local player = Players:GetPlayerByUserId(effectiveSelected)
		-- Through the body API: the owner rig for yourself, a puppet for anyone this client has loaded.
		local character = if player ~= nil then CharacterReplicationServiceClient:getRig(player) else nil
		if not character then
			-- No rig on this client (not spawned, or out of range): skip. The effect keys only off the
			-- userId, so a later spawn won't re-run it — reselecting reapplies the highlight, a fine
			-- tradeoff for a debug overlay versus wiring bodySpawned listeners here.
			return
		end
```

- [ ] **Step 8: Document the body API and the transport amendment**

In `docs/architecture.md`, Networking section, directly after the "Rule of thumb" blockquote, add:

```markdown
> *Continuous, high-rate, per-viewer state (character motion) is a third case: it rides typed **unreliable**
> ByteNet packets owned by the character replication service. It is not an atom, because charm-sync is
> reliable-ordered, diffs every frame, and is identical for every viewer. It is not a one-off event either.*
> The packets live in [`Shared/Events/CharacterReplicationEvents.luau`](../src/ReplicatedStorage/Shared/Events/CharacterReplicationEvents.luau)
> (the repo's first unreliable packets); see [Bodies](#bodies-character-replication).
```

and add a new section before `## Type synchronization`:

```markdown
## Bodies (character replication)

There is **no engine character**. `Players.CharacterAutoLoads` is `false` (a property-only node in
`default.project.json`); the server destroys any engine character that appears and holds, per player, a
replication slot, a body epoch, the validated newest sample, and server-owned health — never a model. Each
client builds its own rig (`LocalPlayer.Character`, simulated by a normal Humanoid) and draws everyone else as
pooled, anchored **puppets**. Design: `docs/superpowers/specs/2026-09-22-character-replication-design.md`.

**One body API.** No system reads `player.Character` for another player's body.

| Side | API | Meaning |
|---|---|---|
| Server (`CharacterReplicationServiceServer`) | `bodySpawned(player, epoch)` / `bodyDespawned(player, epoch)` | A body began / ended (join, respawn, slot switch, leave). SignalPlus: delivered deferred, in order |
| | `observeBodies(callback) -> disconnect` | `callback(player, epoch)` for every live body now and later; the cleanup it returns runs at despawn |
| | `hasBody(player)`, `getBodyPosition(player)` | The live body and its newest accepted position |
| | `respawn(player, reason)` | New epoch, server-chosen spawn; the owner rebuilds. Does not yield |
| | `setMaxHealth(userId, maxHealth)` | Health is server state; clamped down, published on the public slice |
| Client (`CharacterReplicationServiceClient`) | `bodySpawned(player, rig)` / `bodyDespawned(player, rig)` | A rig this client shows appeared / went (the owner rig, or a puppet) |
| | `getRig(player)`, `getPlayerFromRig(rig)`, `getLocalRig()` | The rig registry. Resolve owners by id through it, never by instance name |

**Lifecycle.** Join → slot claimed and broadcast → the client's `Ready` → `Session` (time epoch), the whole
slot table, `Spawn` → the owner builds its rig and streams send-on-change samples (unreliable `Uplink`,
through `RequestHandler`). Every Heartbeat the server relays bodies to the viewers that have them loaded
(600 studs in, 630 out; reliable `Enter` / `Leave`; unreliable `Downlink` ≤ 700 B per viewer-frame).

**Public data.** What any client may know about another player (R2: health) rides charm-sync as the
public slice: `PublicPlayerState` on the server, `ClientStore.publicPlayers` on the client, filtered to the
players relevant to that client (its loaded bodies plus itself). A body whose entry has not arrived yet
renders with defaults.
```

In `docs/animation.md`, replace the `Animate shell` row with:

```markdown
| Locomotion binding | `Client/Services/AnimationService/LocomotionBinding.luau` | Thin adapter: Humanoid events → LocomotionAnimator. Bound by `CharacterReplicationServiceClient` on the owner rig — bodies are client-only, so StarterCharacterScripts never reach a rig |
```

In `docs/conventions.md`, replace

```
**It matters more than it used to:** `SlotService:switchSlot` calls `LoadCharacter()`, so a respawn is now a
routine action (every character switch), not just a death.
```

with

```
**Keep doing it even now:** bodies are client-only (character replication), so no engine respawn resets
PlayerGui today — but a Studio session with `CharacterAutoLoads` on, or any future engine-character path,
brings the reset straight back, and the rule costs nothing.
```

In `AGENTS.md`, replace the property-only paragraph's examples and parenthetical:

```
One sanctioned exception: **property-only service nodes** (`$properties` with NO `$path`, like
`SoundService.RespectFilteringEnabled`, `Workspace.Retargeting = Disabled` and
`Players.CharacterAutoLoads = false`). These manage
exactly the listed properties and cannot create or delete children, so artist content stays
untouchable — a node with `$path` on an artist-owned service remains forbidden.
(`Workspace.Retargeting` MUST stay `Disabled`: the custom-proportioned rig uses standard R15
joint names, and retargeting visibly breaks every animation pose. `Players.CharacterAutoLoads` MUST stay
`false`: bodies are client-only — see docs/architecture.md, "Bodies".)
```

- [ ] **Step 9: Run the static checks and the tests**

Format, Lint (no unused requires left in Stats/Customization/TuneOffset), Typecheck, File length, Project rules. Studio test run: SlotService, Stats, Customization and TuneOffset specs pass; suite green.

- [ ] **Step 10: Studio check (developer, 2 players)**

`unlockslot <me> 2` then `switchslot <me> 2` (F2): your rig rebuilds at the spawn, F4 → Client context → Services → `CharacterReplicationServiceClient` shows `ownerEpoch` up by one, client 2 sees your puppet snap to the spawn, and the server command bar `print(game.Players:GetPlayers()[1].Character)` still prints `nil`. `investstat <me> health 1`: your Humanoid's `MaxHealth` rises (Explorer → your rig → Humanoid). `tuneoffset <me> Hair9 0 0.1` explains why nothing was nudged and prints `offset = { y = 0.1 }`. F4 State tab: selecting the other player highlights their puppet.

- [ ] **Step 11: Commit**

```bash
git add src/ServerScriptService/Services/SlotService src/ServerScriptService/Services/StatsService src/ServerScriptService/Services/CustomizationService src/ServerScriptService/Commands/TuneOffsetServer.luau src/ServerScriptService/Commands/TuneOffsetServer.spec.luau src/ReplicatedStorage/Client/UI/React/Debugger/StatePanel.luau docs/architecture.md docs/animation.md docs/conventions.md AGENTS.md
git commit -m "feat(replication): slots, stats, customization, tuneoffset and the debugger on the body API

switchSlot respawns the client-built body instead of spawning an engine character; maximum health
goes to the body; the appearance backfill runs on body spawn and the server no longer dresses rigs;
tuneoffset says why it cannot nudge until R4. architecture.md documents the body API and the
unreliable-transport amendment."
```

---
### Task 13: Measure the integrated build, roadmap, and the developer's Studio checklist

**Runtime behaviour: no** (measurement specs and docs).

The Verdict asks for the integrated build to be measured at the end of R2: the harness profiles rerun against the modules R2 actually ships, server µs per uplink packet through `RequestHandler`, garbage per second, and a two-client Studio run. The scheduler's far cap is measured too: what it saves in download for a body beyond 300 studs, and what it costs in stutter (pops, freezes, error at ~30 Hz). Results are compared with the saved scorecard results, which live outside the repo.

**Files:**
- Create: `src/ServerScriptService/Services/CharacterReplicationService/HarnessIntegrated.luau`
- Create: `src/ServerScriptService/Services/CharacterReplicationService/HarnessIntegrated.spec.luau`
- Create: `src/ServerScriptService/Services/CharacterReplicationService/ReplicationLoad.spec.luau`
- Modify: `docs/ROADMAP.md` (the Character replication row)

**Interfaces:**
- Consumes: R1 harness (`HarnessRunner.System`, `HarnessRunner.run`, `HarnessTrace.parkour`, `HarnessTrace.withIdle`, `HarnessTrace.groundBelow`, `HarnessNetwork.PROFILES`), `UplinkSender` (Task 10), `CharacterUplinkCodec` (Task 3), `UplinkIngest` / `UplinkPipeline` (Task 4), `DownlinkScheduler` (Task 6), `ReplicationFanout` (Task 7), `RemoteBodies` (Task 11).
- Produces: `HarnessIntegrated.new(options: { groundBelow: ((position: Vector3) -> number)? }?): (HarnessRunner.System, { delayLog: { { atMs: number, delayMs: number } } })`.

- [ ] **Step 1: Write the acceptance spec**

`HarnessIntegrated.spec.luau`:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Harness = ReplicatedStorage.Shared.Modules.CharacterReplication.Harness
local HarnessRunner = require(Harness.HarnessRunner)
local HarnessTrace = require(Harness.HarnessTrace)
local HarnessNetwork = require(Harness.HarnessNetwork)
local HarnessIntegrated = require(script.Parent.HarnessIntegrated)

local SEEDS = { 1, 2, 3, 4 }
-- R1's fidelity limits (HarnessVenture.spec), held against the integrated modules. The byte limits below
-- differ from R1's: the uplink now carries up to three records, and the viewer gets one reliable Enter.
local MEAN_LIMIT = { studio = 0.07, good = 0.06, spec = 0.07, mobile = 0.16 }

local NEAR_STUDS = 50
local FAR_STUDS = 400 -- beyond DownlinkScheduler's 300-stud far cap

local function runOnce(trace, profileName, seed, options, viewerDistance)
	local system, probe = HarnessIntegrated.new({
		groundBelow = function(position)
			return HarnessTrace.groundBelow(trace, position)
		end,
	})
	local profile = HarnessNetwork.PROFILES[profileName]
	return HarnessRunner.run(system, trace, profile, seed, viewerDistance or NEAR_STUDS, options), probe
end

return function()
	local parkour = HarnessTrace.parkour(Vector3.new(0, 100, 0))

	for _, profileName in { "studio", "good", "spec", "mobile" } do
		describe(`integrated R2 modules, parkour over the {profileName} network`, function()
			local results = {}
			beforeAll(function()
				for _, seed in SEEDS do
					table.insert(results, (runOnce(parkour, profileName, seed)))
				end
				-- One line per profile for the developer to compare with the saved scorecard results.
				local mean, p95, maxError, pops, stalls, up, down, latency = 0, 0, 0, 0, 0, 0, 0, 0
				for _, r in results do
					mean += r.fidelity.mean / #results
					p95 += r.fidelity.p95 / #results
					maxError = math.max(maxError, r.fidelity.max)
					pops += r.pops
					stalls += r.stalls
					up += r.upBytesPerSecond / #results
					down += r.downBytesPerSecond / #results
					latency += r.latencyMs / #results
				end
				print(
					string.format(
						"[R2 harness] %s: mean %.3f p95 %.3f max %.2f studs · pops %d freezes %d (%d runs) · up %.0f B/s down %.0f B/s · latency %.0f ms",
						profileName,
						mean,
						p95,
						maxError,
						pops,
						stalls,
						#results,
						up,
						down,
						latency
					)
				)
			end)

			it("keeps the mean shape error under its limit", function()
				local sum = 0
				for _, r in results do
					sum += r.fidelity.mean
				end
				expect(sum / #results < MEAN_LIMIT[profileName]).to.equal(true)
			end)

			it("never draws a body more than 5 studs from its path", function()
				for _, r in results do
					expect(r.fidelity.max < 5).to.equal(true)
				end
			end)

			it("shows at most 2 pops and no freezes per run", function()
				for _, r in results do
					expect(r.pops <= 2).to.equal(true)
					expect(r.stalls).to.equal(0)
				end
			end)

			it("stays within the byte budget and never retransmits", function()
				for _, r in results do
					-- Uplink: up to 3 records of redundancy (53 B) at 60 Hz while moving.
					expect(r.upBytesPerSecond < 3300).to.equal(true)
					expect(r.downBytesPerSecond < 1500).to.equal(true)
					expect(r.retransmits).to.equal(0)
				end
			end)
		end)
	end

	describe("integrated R2 modules, a session with idle time", function()
		it("cuts the uplink when the player stands still", function()
			local idle = HarnessTrace.withIdle(parkour, { 5, "P", 10, "P", 6 })
			local moving = runOnce(parkour, "good", 1)
			local mixed = runOnce(idle, "good", 1)
			expect(mixed.upBytesPerSecond < 0.75 * moving.upBytesPerSecond).to.equal(true)
			expect(mixed.fidelity.max < 5).to.equal(true)
		end)
	end)

	-- The far cap: a moving body 400 studs away reaches the viewer at about 30 Hz instead of 60. The printed
	-- line is the saving and the stutter it costs; the developer compares it with the near line above.
	for _, profileName in { "good", "mobile" } do
		describe(`integrated R2 modules, a body beyond the far cap over the {profileName} network`, function()
			local near, far = {}, {}
			beforeAll(function()
				for _, seed in SEEDS do
					table.insert(near, (runOnce(parkour, profileName, seed, nil, NEAR_STUDS)))
					table.insert(far, (runOnce(parkour, profileName, seed, nil, FAR_STUDS)))
				end
				local nearDown, farDown, mean, p95, maxError, pops, stalls = 0, 0, 0, 0, 0, 0, 0
				for i, r in far do
					nearDown += near[i].downBytesPerSecond / #far
					farDown += r.downBytesPerSecond / #far
					mean += r.fidelity.mean / #far
					p95 += r.fidelity.p95 / #far
					maxError = math.max(maxError, r.fidelity.max)
					pops += r.pops
					stalls += r.stalls
				end
				print(
					string.format(
						"[R2 harness] far cap %s (%d studs): down %.0f -> %.0f B/s (%.0f %% saved) · mean %.3f p95 %.3f max %.2f studs · pops %d freezes %d (%d runs)",
						profileName,
						FAR_STUDS,
						nearDown,
						farDown,
						(1 - farDown / nearDown) * 100,
						mean,
						p95,
						maxError,
						pops,
						stalls,
						#far
					)
				)
			end)

			it("saves at least a quarter of the download for a moving far body", function()
				for i, r in far do
					expect(r.downBytesPerSecond < 0.75 * near[i].downBytesPerSecond).to.equal(true)
				end
			end)

			it("draws the far body without freezes, at most 2 pops, never more than 5 studs off", function()
				for _, r in far do
					expect(r.stalls).to.equal(0)
					expect(r.pops <= 2).to.equal(true)
					expect(r.fidelity.max < 5).to.equal(true)
				end
			end)
		end)
	end

	describe("integrated R2 modules, a local stall (window in the background)", function()
		it("does not raise the render delay after the stall", function()
			local stallAtMs, stallForMs = 8000, 1600
			local _, probe = runOnce(parkour, "good", 1, { stallAtMs = stallAtMs, stallForMs = stallForMs })
			local before, after = nil, nil
			for _, entry in probe.delayLog do
				if entry.atMs < stallAtMs then
					before = entry.delayMs
				elseif entry.atMs >= stallAtMs + stallForMs + 1000 and after == nil then
					after = entry.delayMs
				end
			end
			expect(before).to.be.ok()
			expect(after).to.be.ok()
			expect(after <= before + 10).to.equal(true)
		end)
	end)
end
```

`ReplicationLoad.spec.luau` (a measurement spec: loose bounds that catch a regression, exact numbers printed for the scorecard comparison):

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RequestHandler = require(ServerScriptService.Modules.RequestHandler)
local UplinkPipeline = require(script.Parent.UplinkPipeline)
local ReplicationFanout = require(script.Parent.ReplicationFanout)
local UplinkSender = require(ReplicatedStorage.Client.Services.CharacterReplicationService.UplinkSender)

local PLAYERS = 60
local FRAMES = 300 -- 5 s at 60 Hz
local FRAME_MS = 1000 / 60
local FIRST_USER = -71000

-- 60 owners walking small circles inside one 160-stud square (everyone sees everyone: the worst case for
-- the fan-out), each streaming through the REAL uplink pipeline (RequestHandler) and one server fan-out per
-- frame. Owner-side packet building is outside the measured windows; only server work is timed.
local function run()
	local world = ReplicationFanout.newWorld()
	local bodies, senders, players, byUser = {}, {}, {}, {}
	for i = 1, PLAYERS do
		local base = Vector3.new(-1228 + (i % 8) * 20, 10, -363 + (i // 8) * 20)
		local body = ReplicationFanout.newBody(FIRST_USER - i, i, 0, base)
		body.ready = true
		body.epoch.value = 1
		ReplicationFanout.respawned(body)
		ReplicationFanout.addBody(world, body)
		bodies[i] = { body = body, base = base }
		senders[i] = UplinkSender.new()
		players[i] = { UserId = body.userId }
		byUser[body.userId] = body
	end
	local nowMs = 0
	local handler = UplinkPipeline.wrap(function(player)
		local body = byUser[player.UserId]
		return if body ~= nil and body.alive then body.ingest else nil
	end, function()
		return math.floor(nowMs)
	end, function(player, state)
		local body = byUser[player.UserId]
		if body ~= nil and state.latest ~= nil then
			body.position = state.latest.position
		end
	end)
	local hooks = {
		send = function() end,
		visibility = function() end,
	}
	local uplinkSeconds, packets, fanoutSeconds, garbageKb, batchesSent = 0, 0, 0, 0, 0
	local outgoing = {}
	for frame = 1, FRAMES do
		nowMs = frame * FRAME_MS
		table.clear(outgoing)
		for i, entry in bodies do
			local angle = frame / 60 * 2 + i
			local record = {
				slot = 0,
				generation = 0,
				epoch = 1,
				ageMs = 0,
				position = entry.base + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 3,
				yaw = angle,
				pitch = 0,
				velocity = Vector3.new(-math.sin(angle), 0, math.cos(angle)) * 6,
				state = 8,
				grounded = true,
				hasAction = false,
				rotation = nil,
			}
			local packet = UplinkSender.step(senders[i], math.floor(nowMs), record)
			if packet ~= nil then
				table.insert(outgoing, { packet = packet, player = players[i] })
			end
		end
		local before = collectgarbage("count")
		local started = os.clock()
		for _, out in outgoing do
			handler(out.packet, out.player)
		end
		uplinkSeconds += os.clock() - started
		packets += #outgoing
		local fanoutStarted = os.clock()
		batchesSent += ReplicationFanout.step(world, math.floor(nowMs), hooks)
		fanoutSeconds += os.clock() - fanoutStarted
		local after = collectgarbage("count")
		if after > before then
			garbageKb += after - before
		end
	end
	for i = 1, PLAYERS do
		RequestHandler.resetRateLimit(FIRST_USER - i)
	end
	return {
		uplinkMicroseconds = uplinkSeconds / math.max(packets, 1) * 1e6,
		fanoutMilliseconds = fanoutSeconds / FRAMES * 1000,
		garbageKbPerSecond = garbageKb / (FRAMES / 60),
		packets = packets,
		batches = batchesSent,
	}
end

return function()
	describe("server load at 60 players in one view", function()
		local result
		beforeAll(function()
			result = run()
			print(
				string.format(
					"[R2 load] %d players: %.1f µs per uplink packet (RequestHandler + decode + ingest, %d packets) · fan-out %.3f ms/frame (%d batches) · server garbage %.0f KB/s",
					PLAYERS,
					result.uplinkMicroseconds,
					result.packets,
					result.fanoutMilliseconds,
					result.batches,
					result.garbageKbPerSecond
				)
			)
		end)

		it("streams every owner and relays to every viewer", function()
			expect(result.packets > PLAYERS * FRAMES * 0.9).to.equal(true)
			expect(result.batches > PLAYERS * (FRAMES - 1) * 0.9).to.equal(true)
		end)

		it("keeps an uplink packet under 100 µs on the server", function()
			expect(result.uplinkMicroseconds < 100).to.equal(true)
		end)

		it("keeps the fan-out under 4 ms per frame", function()
			expect(result.fanoutMilliseconds < 4).to.equal(true)
		end)

		-- Loose on purpose: decoding and the per-viewer batch buffers allocate by design (about 2–4 MB/s at
		-- this load); the printed number is what gets compared with the scorecard.
		it("keeps server garbage under 10 MB per second", function()
			expect(result.garbageKbPerSecond < 10000).to.equal(true)
		end)
	end)
end
```

- [ ] **Step 2: Run the tests and verify they fail**

Studio test run. Expected: `HarnessIntegrated.spec` fails at `require` (`HarnessIntegrated` missing); `ReplicationLoad.spec` passes or fails on its own numbers (it only uses landed modules) — note its printed line.

- [ ] **Step 3: Write `HarnessIntegrated.luau`**

```luau
--!strict
--[=[
	HarnessIntegrated: the R1 harness adapter rebuilt on the modules R2 ships (Verdict: "Measure the
	integrated build"; plan R2 Task 13), so the acceptance numbers describe the real pipeline:

	  owner   UplinkSender — send on change, two resends, 1 Hz repair; the current sample plus two previous,
	          aged from a u32 send time (CharacterUplinkCodec)
	  server  CharacterUplinkCodec.decode → UplinkIngest → ReplicationFanout (send policy, visibility, encode
	          once, 700 B cap and budget). The RequestHandler limiter is measured separately (ReplicationLoad)
	  viewer  RemoteBodies — slot table, enter, validated batches, render clock, interpolation, dead reckoning

	One subject (the trace) and one viewer standing `viewerDistance` studs beside it. A respawn in the trace
	bumps the epoch on the owner and the server at once and sends the viewer a reliable slot entry, as the
	real server does. Server → viewer payloads carry a one-byte tag (harness framing only): 1 slot entry,
	2 enter, 3 batch.

	@class HarnessIntegrated
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Replication = ReplicatedStorage.Shared.Modules.CharacterReplication
local CharacterRecordCodec = require(Replication.CharacterRecordCodec)
local CharacterUplinkCodec = require(Replication.CharacterUplinkCodec)
local HarnessRunner = require(Replication.Harness.HarnessRunner)
local UplinkSender = require(ReplicatedStorage.Client.Services.CharacterReplicationService.UplinkSender)
local RemoteBodies = require(ReplicatedStorage.Client.Services.CharacterReplicationService.RemoteBodies)
local UplinkIngest = require(script.Parent.UplinkIngest)
local DownlinkScheduler = require(script.Parent.DownlinkScheduler)
local ReplicationFanout = require(script.Parent.ReplicationFanout)

local HarnessIntegrated = {}

local SUBJECT_SLOT, VIEWER_SLOT = 1, 2
local SUBJECT_USER, VIEWER_USER = 1, 2
local TAG_SLOT, TAG_ENTER, TAG_BATCH = 1, 2, 3
local ENTER_HEADER_BYTES = 6 -- slot u8 · generation u8 · batchTimeMs u32
local ACTION_COUNT = 128 -- R2 never relays actions; any index is "in the registry" here

export type Options = {
	groundBelow: ((position: Vector3) -> number)?,
}

export type Probe = {
	delayLog: { { atMs: number, delayMs: number } },
}

local function tagged(tag: number, body: buffer): buffer
	local out = buffer.create(1 + buffer.len(body))
	buffer.writeu8(out, 0, tag)
	buffer.copy(out, 1, body)
	return out
end

local function untag(payload: buffer): (number, buffer)
	local body = buffer.create(buffer.len(payload) - 1)
	buffer.copy(body, 0, payload, 1)
	return buffer.readu8(payload, 0), body
end

function HarnessIntegrated.new(options: Options?): (HarnessRunner.System, Probe)
	local groundBelow = if options ~= nil then options.groundBelow else nil
	local probe: Probe = { delayLog = {} }
	local epoch = 1

	-- owner
	local sender = UplinkSender.new()

	-- server: the subject (alive from its first accepted sample) and a ready viewer
	local world = ReplicationFanout.newWorld()
	local subject = ReplicationFanout.newBody(SUBJECT_USER, SUBJECT_SLOT, 0, Vector3.zero)
	local viewer = ReplicationFanout.newBody(VIEWER_USER, VIEWER_SLOT, 0, Vector3.zero)
	for _, body in { subject, viewer } do
		body.epoch.value = epoch
		body.ready = true
		ReplicationFanout.respawned(body)
		ReplicationFanout.addBody(world, body)
	end
	subject.alive = false
	local frameNowMs = 0
	local slotEntryPending = false
	local outgoing: { HarnessRunner.Outgoing } = {}
	local hooks: ReplicationFanout.Hooks = {
		send = function(_viewer, batch)
			table.insert(outgoing, { payload = tagged(TAG_BATCH, batch), reliable = false })
		end,
		visibility = function(_viewer, body, entered)
			if not entered then
				return
			end
			local record, sampleMs = ReplicationFanout.enterRecord(body, frameNowMs)
			local enter = buffer.create(ENTER_HEADER_BYTES + CharacterRecordCodec.RECORD_BYTES)
			buffer.writeu8(enter, 0, body.slot)
			buffer.writeu8(enter, 1, body.generation)
			buffer.writeu32(enter, 2, frameNowMs)
			local recordBytes = buffer.create(CharacterRecordCodec.RECORD_BYTES)
			DownlinkScheduler.encode(recordBytes, body.slot, body.generation, body.epoch.value, record, sampleMs, frameNowMs)
			buffer.copy(enter, ENTER_HEADER_BYTES, recordBytes)
			table.insert(outgoing, { payload = tagged(TAG_ENTER, enter), reliable = true })
		end,
	}

	-- viewer
	local remote = RemoteBodies.new(VIEWER_USER)
	RemoteBodies.applySlot(remote, { slot = SUBJECT_SLOT, userId = SUBJECT_USER, generation = 0, epoch = epoch, active = true })
	local slots: { number } = {}
	local cframes: { CFrame } = {}

	local system: HarnessRunner.System = {
		name = "Venture (R2 integrated)",

		ownerFrame = function(nowMs, truth, respawned)
			if respawned then
				epoch = (epoch + 1) % 256
				UplinkSender.reset(sender)
				subject.epoch.value = epoch
				ReplicationFanout.respawned(subject)
				subject.position = truth.position
				slotEntryPending = true
			end
			local record: CharacterRecordCodec.Record = {
				slot = 0,
				generation = 0,
				epoch = epoch,
				ageMs = 0,
				position = truth.position,
				yaw = truth.yaw,
				pitch = 0,
				velocity = truth.velocity,
				state = truth.state,
				grounded = truth.grounded,
				hasAction = false,
				rotation = nil,
			}
			local packet = UplinkSender.step(sender, math.floor(nowMs), record)
			if packet == nil then
				return {}
			end
			return { { payload = packet, reliable = false } }
		end,

		serverReceive = function(nowMs, payload)
			local ok, _reason, uplink = CharacterUplinkCodec.decode(payload)
			if not ok or uplink == nil then
				return
			end
			if UplinkIngest.ingest(subject.ingest, payload, uplink, math.floor(nowMs)) > 0 then
				local latest = subject.ingest.latest
				if latest ~= nil then
					subject.position = latest.position
					subject.alive = true
				end
			end
		end,

		serverFrame = function(nowMs, viewerDistance)
			frameNowMs = math.floor(nowMs)
			outgoing = {}
			viewer.position = subject.position + Vector3.new(viewerDistance, 0, 0)
			if slotEntryPending then
				slotEntryPending = false
				local entry = buffer.create(1)
				buffer.writeu8(entry, 0, epoch)
				table.insert(outgoing, { payload = tagged(TAG_SLOT, entry), reliable = true })
			end
			ReplicationFanout.step(world, frameNowMs, hooks)
			return outgoing
		end,

		viewerReceive = function(nowMs, payload)
			local tag, body = untag(payload)
			if tag == TAG_SLOT then
				RemoteBodies.applySlot(remote, {
					slot = SUBJECT_SLOT,
					userId = SUBJECT_USER,
					generation = 0,
					epoch = buffer.readu8(body, 0),
					active = true,
				})
			elseif tag == TAG_ENTER then
				local record = buffer.create(CharacterRecordCodec.RECORD_BYTES)
				buffer.copy(record, 0, body, ENTER_HEADER_BYTES, CharacterRecordCodec.RECORD_BYTES)
				RemoteBodies.enter(remote, buffer.readu8(body, 0), buffer.readu8(body, 1), buffer.readu32(body, 2), record)
			elseif tag == TAG_BATCH then
				RemoteBodies.onBatch(remote, body, nowMs, ACTION_COUNT)
			end
		end,

		viewerRender = function(nowMs)
			local count = RemoteBodies.frame(remote, nowMs, slots, cframes, groundBelow)
			table.insert(probe.delayLog, { atMs = nowMs, delayMs = remote.delayMs })
			for i = 1, count do
				if slots[i] == SUBJECT_SLOT then
					return cframes[i].Position
				end
			end
			return nil
		end,
	}
	return system, probe
end

return HarnessIntegrated
```

- [ ] **Step 4: Run the tests and verify they pass**

Studio test run: every `HarnessIntegrated` case and every `ReplicationLoad` case passes, and the R1 `HarnessVenture` cases still pass; suite green (the harness runs take ~45 s). Copy the printed `[R2 harness]` lines (including the two `far cap` lines: the download saved beyond 300 studs and the far body's mean / p95 / max error, pops and freezes, against the near line of the same profile) and the `[R2 load]` line into the hand-off to the developer. The far-cap numbers decide whether `farCapStuds` / `farMinIntervalMs` keep their defaults: a far mean error well above the near one, or any pop or freeze, is reported to the developer rather than tuned silently. If a threshold fails, read the run's numbers before touching anything: a threshold is only relaxed with the developer's agreement (and a line in the spec's appendix saying why); a behaviour regression is fixed in the module that caused it. Format, Lint, Typecheck clean.

- [ ] **Step 5: Update the roadmap**

In `docs/ROADMAP.md`, in the **Character replication** row, replace `R2 bodies on screen;` with:

```
R2 bodies on screen (client-only bodies, uplink through RequestHandler, encode-once fan-out, pooled puppets, public slice, lifecycle rewires) — plan `docs/superpowers/plans/2026-10-01-character-replication-r2-bodies-on-screen.md`, stacked with R3–R5 (merged together once R5 is verified);
```

- [ ] **Step 6: Commit**

```bash
git add src/ServerScriptService/Services/CharacterReplicationService/HarnessIntegrated.luau src/ServerScriptService/Services/CharacterReplicationService/HarnessIntegrated.spec.luau src/ServerScriptService/Services/CharacterReplicationService/ReplicationLoad.spec.luau docs/ROADMAP.md
git commit -m "test(replication): integrated harness and 60-player server load measurement

The R1 harness profiles rerun against the modules R2 ships (uplink sender, ingest, fan-out, remote
bodies) with the R1 acceptance limits; a load spec times uplink packets through RequestHandler and the
fan-out at 60 players in one view, and reports server garbage per second."
```

- [ ] **Step 7: Hand the developer the two-client Studio checklist**

Studio: serve this worktree, Test → Clients and Servers, 2 players (no `RunTests`). Each line is pass/fail; report anything else seen.

1. **Boot.** No errors in either Output from `CharacterReplicationService*`. Server command bar: `print(game.Players.CharacterAutoLoads, game.Players:GetPlayers()[1].Character)` → `false nil`.
2. **Owner rig.** Each client spawns at the SpawnLocation and controls a native-feeling body: walk, run, jump, swim, fall; the camera follows; locomotion animates; the rig has no `Animate` child. `Workspace.LocomotionEnabled = false` freezes your poses, `true` restores them.
3. **Cmdr.** F2 opens Cmdr at once on both clients; `PlayerGui` holds exactly one `Cmdr`.
4. **Puppets.** Each client sees the other as one puppet in the default look (not animated), moving smoothly, facing the right way, at the right height on slopes and stairs; nobody sees their own puppet.
5. **Relevance.** Walk more than 630 studs apart: the puppet disappears (it moves to the hidden spot; `Workspace.CharacterPuppets` keeps it). Walk back within 600: it reappears where the player is, without sliding from where it was last seen.
6. **Far body.** Stand 350–550 studs apart while client 2 runs and jumps: on client 1 the puppet moves as smoothly as it does up close (it arrives at ~30 Hz there; no visible stutter, hitching or sliding).
7. **Leave / rejoin.** Close client 2 and rejoin it: client 1's puppet goes, then a fresh one appears; never two.
8. **Slot switch.** `unlockslot <client1> 2`, `switchslot <client1> 2`: client 1's rig rebuilds at the spawn; F4 → Client context → Services → `CharacterReplicationServiceClient.ownerEpoch` is +1; client 2 sees the puppet snap to the spawn; no engine character appears (check 1 still prints `nil`).
9. **Fall plane.** Walk or fly off the map below `Workspace.FallenPartsDestroyHeight`: you respawn at the spawn.
10. **Health.** `investstat <client1> health 1`: client 1's Humanoid `MaxHealth` rises; re-equipping gear with a health bonus does the same.
11. **Tab-out.** Background client 1's window for ~5 s, then return: on client 2 the puppet holds still during the gap and resumes without a long freeze or a jump across the map; F4 (server context) → Services → `CharacterReplicationServiceServer.ingest.<client1>.mismatched` stays `0`.
12. **F4.** Client context → Services → `CharacterReplicationServiceClient`: `delayMs` in the tens of ms, `counters.interpolate` far above `hold`, `counters.rejected` 0. Server context → Services → `CharacterReplicationServiceServer`: `fanoutMsAvg` small, ingest counters plausible. State tab: rate-limit rows show tokens and drops; selecting the other player highlights their puppet.
13. **No leak.** Client 2's command bar: `print(#workspace.CharacterFocus:GetDescendants())` → `0` (the focus parts stay on the server).
14. **Measurements.** Paste the `[R2 harness]` lines (near and far cap) and the `[R2 load]` line from the last test run; compare them with the saved scorecard results, and note the far cap's download saving against the far-body stutter seen in check 6.

---

## After R2

Push `feature/replication-bodies` and open a PR into `feature/character-replication` (R1, PR #28) titled `Character replication R2: bodies on screen`. Per the stacked-phase decision it does not merge on its own: R3 (`feature/replication-animation`), R4 (`feature/replication-appearance`) and R5 (`feature/replication-voice`) stack on it, and the stack merges once R5 is verified in Studio (AGENTS.md: merge commits, never squash; rebase still-open stacked branches after each merge).

## Deferred (useful, out of R2's scope — not tasks here)

- **F4 replication panel** (§8's Debugger row suggests one): R2 exposes the client's numbers through `CharacterReplicationServiceClient:getState` (Services tab, client context) instead.
- **Bubble chat and spatial voice on puppets** (§5.1, §5.1.3, C4): with no engine character, chat bubbles and the client-wired voice route need the puppet head. Moved to R5 (chat and voice).
- **Puppet LOD** (lighter far rigs, animation rate by distance): belongs with puppet animation (R3) and the rig clean-up.
- **§6.4's full error prediction** (running the interpolator per viewer to rank by the error of its picture): the priority accumulator with the far cap ships in R2 (ruling 7); revisit only if the measurements ask for it.
- **Delta-coded uplink redundancy**, **a 12 B far-body record**: v3's send policy and full records ship in R2; revisit only if the measurements ask for it.
- **History ring and sent-seq brackets** (lag compensation, R7); **the §6.3 timestamp window lower bound, drift-slope check and MovementRules envelope** (anti-cheat phase).
