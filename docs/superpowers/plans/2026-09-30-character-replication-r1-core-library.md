# Character Replication R1 — Core Library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the pure, spec-first shared modules every later replication phase stands on — the record codec, the interpolator with dead reckoning, the render clock (delay controller), and the send policy — plus the harness as an acceptance spec that proves the chosen "v3" design end to end.

**Architecture:** Four pure Luau modules under `ReplicatedStorage.Shared.Modules.CharacterReplication` (no services, no Instances, time always passed in, so client and server run the same code and TestEZ can drive them deterministically). Two are ports of spike code that was measured in the A/B (codec, interpolator); two are new modules that extract the logic the harness proved (render clock, send policy). A `Harness` subfolder ports the spike's harness and wires it to the REAL modules, so the acceptance spec measures exactly what R2 will ship. No networking, no gameplay change: R2 builds the services on top.

**Tech Stack:** Luau `--!strict`, `bit32` + `buffer`, TestEZ specs (Studio `RunTests`), Rojo, selene, StyLua, luau-lsp.

**Spec:** `docs/superpowers/specs/2026-09-22-character-replication-design.md` — read the **Verdict (2026-09-30)** section first; it supersedes older numbers in §6. Background: §6.2 (record), §6.6 (time base and rendering), §6.7 (epochs), §10 (proving it).

## Global Constraints

- `--!strict` in every module; specs are untyped (repo rule). **No `any`, no `::` casts** (`check_pr_rules.py` rejects added `::` without a justification comment).
- Spec first: write `<Name>.spec.luau` before `<Name>.luau`. Every module needs a `.spec` sibling or an `EXEMPT_MODULES` entry with a reason in `src/ServerScriptService/Modules/SpecRoots.luau` (build fails otherwise).
- Max **400 code lines** per module (`scripts/python/check_file_length.py`; doc comments don't count).
- Location: `src/ReplicatedStorage/Shared/Modules/CharacterReplication/` (pure shared logic; `Shared.Modules` is a spec root).
- Record: **16 bytes**, bit layout LSB-first `slot 7 · generation 2 · epoch 3 · age 10 · x 18 · z 18 · y 16 · yaw 8 · pitch 6 · vx 11 · vy 11 · vz 11 · state 5 · grounded 1 · hasAction 1`. Quantisation box centre `(-1228, 0, -363)`, X/Z `±2048` at 1/64 stud, Y `-512…+1536` at 1/32 stud, velocity `±768` studs/s sqrt-companded. Ragdoll variant `STATE_RAGDOLL = 29` (33 velocity bits carry a smallest-three quaternion). Batch header **7 bytes** `u16 seq · u32 batchTimeMs · u8 count`. Action extension **2 bytes** `index 7 · variant 3 · elapsed 6` (32 ms steps).
- Render clock ("v3"): target = p95 of NEW-sample lateness + (lossLevel + 1) × 16.67 ms + 4 ms, retargeted every 250 ms with 6 ms hysteresis; rises by gliding 60 ms/s, jumps when starving or > 25 ms away; falls 15 ms/s; loss over the last 240 batches (> 1.5 % → level 1, > 6 % → level 2); cap 600 ms and never further back than a FULL sample buffer reaches; batches processed within 100 ms after a local stall (a frame gap > 100 ms) don't vote on lateness.
- Send policy ("v3"): send on change; after the last change, 2 resends 50 ms apart; 1 Hz repair.
- Commits: plain messages, **no `Co-Authored-By` or `Claude-Session` trailers** (AGENTS.md).
- Never run `bash scripts/check.sh` (its `wally install` kills a live `rojo serve`). Use the individual commands in "Commands" below.

## Review Focus

1. **Owner clock slightly ahead of the server** — the 10-bit owner timestamp must unwrap to "just now", not "one second ago" (Task 1 test `unwrapOwnerTime tolerates an owner up to 64 ms ahead`).
2. **A straggler from the previous epoch arriving after a respawn** — must be dropped, not flush the new body's buffer and snap it back (Task 2 test `drops a record from an older epoch after a flush`).
3. **Sequence numbers wrapping at 65535** — must not read as massive packet loss and inflate the delay (Task 3 test `counts a seq wrap as one step`).
4. **NaN / infinite values reaching the encoder** (a physics glitch on the owner) — must encode as finite values, never throw or corrupt neighbouring bits (Task 1 test `encodes NaN and infinities as finite values`).
5. **Empty or single-sample buffers** (first record after a flush) — evaluate, reckon and reach must behave (Task 2 tests `evaluate on an empty buffer`, `reckon with one sample`, `reach is unlimited until the buffer is full`).

---

## File Structure

```
src/ReplicatedStorage/Shared/Modules/CharacterReplication/
  CharacterRecordCodec.luau        (Task 1) 16 B record, 7 B header, 2 B action extension, owner-time unwrap
  CharacterRecordCodec.spec.luau
  CharacterInterpolator.luau       (Task 2) sample buffer, Hermite, fast path, dead reckoning, reach
  CharacterInterpolator.spec.luau
  RenderClock.luau                 (Task 3) per-viewer render delay controller
  RenderClock.spec.luau
  SendPolicy.luau                  (Task 4) change / resend / repair decisions, record change test
  SendPolicy.spec.luau
  Harness/
    HarnessTrace.luau              (Task 5) parkour truth trace + idle builder   [spec-exempt: harness]
    HarnessNetwork.luau            (Task 5) deterministic lossy link             [spec-exempt: harness]
    HarnessRunner.luau             (Task 5) runs a system over a trace, scores   [spec-exempt: harness]
    HarnessVenture.luau            (Task 5) adapter wiring the four REAL modules
    HarnessVenture.spec.luau       (Task 5) the acceptance spec
src/ServerScriptService/Modules/SpecRoots.luau   (Task 5) three EXEMPT_MODULES entries
docs/ROADMAP.md                                   (Task 6) the replication track
```

Spike sources are ported from commit `07c3aaa` on branch `spike/character-replication` (frozen reference). Use `git -c safe.directory=* show 07c3aaa:<path>` — the `-c safe.directory=*` is needed on this machine.

## Commands

Run from the worktree root (`.claude/worktrees/character-replication`).

| Purpose | Command |
|---|---|
| Format | `stylua src/ReplicatedStorage/Shared/Modules/CharacterReplication` |
| Lint | `selene src/ReplicatedStorage/Shared/Modules/CharacterReplication` |
| Typecheck | `rojo sourcemap default.project.json --output sourcemap.json && luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau --ignore="**/*.spec.luau" src/ReplicatedStorage/Shared/Modules/CharacterReplication` |
| Tests | Studio only. The developer serves THIS worktree with `rojo serve` and connects; set the Workspace boolean attribute `RunTests = true`, press Play, read Output. Expected tail: `<N> passed, 0 failed, 0 skipped`. Remove the attribute afterwards (a test session destroys live singletons; never play in it). |

If `globalTypes.d.luau` is missing, fetch it once: `curl -fsSL "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.68.1/scripts/globalTypes.d.luau" -o globalTypes.d.luau`.

Each task's "run tests" step means the Studio run above. When an implementer cannot drive Studio, stop at that step and hand it to the developer with the exact spec names expected to fail or pass.

---

### Task 1: CharacterRecordCodec

**Files:**
- Create: `src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterRecordCodec.spec.luau`
- Create: `src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterRecordCodec.luau` (port of `src/ReplicatedStorage/Shared/Spike/SpikeRecordCodec.luau` @ `07c3aaa`)

**Interfaces:**
- Produces:
  - `CharacterRecordCodec.RECORD_BYTES: number` (16), `HEADER_BYTES` (7), `ACTION_BYTES` (2), `STATE_RAGDOLL` (29), `ACTION_ELAPSED_STEP_MS` (32), `ACTION_ELAPSED_MAX_MS` (2016), `OWNER_AHEAD_MS` (64)
  - `export type Record = { slot: number, generation: number, epoch: number, ageMs: number, position: Vector3, yaw: number, pitch: number, velocity: Vector3, state: number, grounded: boolean, hasAction: boolean, rotation: CFrame? }`
  - `export type Header = { seq: number, batchTimeMs: number, count: number }`
  - `export type Action = { index: number, variant: number, elapsedMs: number }`
  - `writeRecord(b: buffer, offset: number, r: Record)`, `readRecord(b: buffer, offset: number): Record`
  - `writeHeader(b: buffer, offset: number, h: Header)`, `readHeader(b: buffer, offset: number): Header`
  - `writeAction(b: buffer, offset: number, a: Action)`, `readAction(b: buffer, offset: number): Action`
  - `recordBytes(r: Record): number`
  - `unwrapOwnerTime(arrivalMs: number, low10: number): number`

- [ ] **Step 1: Write the failing spec**

Create `CharacterRecordCodec.spec.luau`:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Codec = require(ReplicatedStorage.Shared.Modules.CharacterReplication.CharacterRecordCodec)

local function record(overrides)
	local r = {
		slot = 5,
		generation = 2,
		epoch = 3,
		ageMs = 40,
		position = Vector3.new(-1200.3, 42.7, -350.9),
		yaw = 1.2,
		pitch = -0.3,
		velocity = Vector3.new(12.5, -30.25, 0.75),
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

local function roundTrip(r)
	local b = buffer.create(Codec.RECORD_BYTES)
	Codec.writeRecord(b, 0, r)
	return Codec.readRecord(b, 0)
end

-- Half a companding step at |v| (the worst quantisation error for that speed).
local function velocityTolerance(v)
	return math.sqrt(768 * math.abs(v)) / 1023 + 1e-3
end

local function angleDelta(a, b)
	return math.abs((a - b + math.pi) % (2 * math.pi) - math.pi)
end

return function()
	describe("sizes", function()
		it("uses a 16 B record, a 7 B header and a 2 B action extension", function()
			expect(Codec.RECORD_BYTES).to.equal(16)
			expect(Codec.HEADER_BYTES).to.equal(7)
			expect(Codec.ACTION_BYTES).to.equal(2)
		end)

		it("counts the action extension in recordBytes", function()
			expect(Codec.recordBytes(record())).to.equal(16)
			expect(Codec.recordBytes(record({ hasAction = true }))).to.equal(18)
		end)
	end)

	describe("record round trip", function()
		it("keeps every integer field exactly, including maximum values", function()
			local out = roundTrip(record({ slot = 127, generation = 3, epoch = 7, ageMs = 1023, state = 31, hasAction = true }))
			expect(out.slot).to.equal(127)
			expect(out.generation).to.equal(3)
			expect(out.epoch).to.equal(7)
			expect(out.ageMs).to.equal(1023)
			expect(out.state).to.equal(31)
			expect(out.grounded).to.equal(true)
			expect(out.hasAction).to.equal(true)
		end)

		it("keeps position within half a quantisation step", function()
			local r = record()
			local out = roundTrip(r)
			expect(math.abs(out.position.X - r.position.X) <= 1 / 128 + 1e-6).to.equal(true)
			expect(math.abs(out.position.Z - r.position.Z) <= 1 / 128 + 1e-6).to.equal(true)
			expect(math.abs(out.position.Y - r.position.Y) <= 1 / 64 + 1e-6).to.equal(true)
		end)

		it("keeps yaw within 1.4 degrees and pitch within 2.9 degrees", function()
			for _, yaw in { -3.1, -1, 0, 0.5, 3.1, 7 } do
				local out = roundTrip(record({ yaw = yaw }))
				expect(angleDelta(out.yaw, yaw) <= math.pi / 256 + 1e-6).to.equal(true)
			end
			for _, pitch in { -1.5, -0.2, 0, 0.9, 1.5 } do
				local out = roundTrip(record({ pitch = pitch }))
				expect(math.abs(out.pitch - pitch) <= math.pi / 63 + 1e-6).to.equal(true)
			end
		end)

		it("keeps velocity within half a companding step, sign included", function()
			for _, v in { 0, 0.3, -2, 10, -16, 50.9, -185, 400, 767 } do
				local out = roundTrip(record({ velocity = Vector3.new(v, -v, v / 2) }))
				expect(math.abs(out.velocity.X - v) <= velocityTolerance(v)).to.equal(true)
				expect(math.abs(out.velocity.Y + v) <= velocityTolerance(v)).to.equal(true)
				expect(math.abs(out.velocity.Z - v / 2) <= velocityTolerance(v / 2)).to.equal(true)
			end
		end)

		it("clamps out-of-range values to the edge of their field", function()
			local out = roundTrip(record({
				position = Vector3.new(-1228 + 5000, 5000, -363 - 5000),
				velocity = Vector3.new(2000, -2000, 0),
				ageMs = 5000,
			}))
			expect(out.position.X).to.be.near(-1228 + 2048 - 1 / 64, 0.02)
			expect(out.position.Z).to.be.near(-363 - 2048, 0.02)
			expect(out.position.Y).to.be.near(1536 - 1 / 32, 0.04)
			expect(out.velocity.X).to.be.near(768, 0.01)
			expect(out.velocity.Y).to.be.near(-768, 0.01)
			expect(out.ageMs).to.equal(1023)
		end)

		it("encodes NaN and infinities as finite values without disturbing other fields", function()
			local nan = 0 / 0
			local out = roundTrip(record({
				position = Vector3.new(nan, math.huge, -math.huge),
				velocity = Vector3.new(nan, math.huge, -math.huge),
				yaw = nan,
				pitch = nan,
				slot = 9,
				state = 12,
			}))
			for _, value in { out.position.X, out.position.Y, out.position.Z, out.velocity.X, out.velocity.Y, out.velocity.Z, out.yaw, out.pitch } do
				expect(value == value).to.equal(true)
				expect(math.abs(value) < math.huge).to.equal(true)
			end
			expect(out.slot).to.equal(9)
			expect(out.state).to.equal(12)
		end)

		it("carries a full rotation instead of velocity on a ragdoll record", function()
			local rotation = CFrame.Angles(0.4, -1.1, 2.2)
			local out = roundTrip(record({ state = Codec.STATE_RAGDOLL, rotation = rotation }))
			expect(out.rotation).to.be.ok()
			local _, angle = (out.rotation:Inverse() * rotation):ToAxisAngle()
			expect(math.abs(angle) < math.rad(0.3)).to.equal(true)
			expect(out.velocity).to.equal(Vector3.zero)
		end)

		it("writes at an offset without touching neighbouring bytes", function()
			local b = buffer.create(3 + Codec.RECORD_BYTES + 3)
			buffer.fill(b, 0, 0xAB)
			Codec.writeRecord(b, 3, record())
			for i = 0, 2 do
				expect(buffer.readu8(b, i)).to.equal(0xAB)
				expect(buffer.readu8(b, 3 + Codec.RECORD_BYTES + i)).to.equal(0xAB)
			end
			expect(Codec.readRecord(b, 3).slot).to.equal(5)
		end)
	end)

	describe("header", function()
		it("round-trips and wraps seq at 16 bits and batch time at 32 bits", function()
			local b = buffer.create(Codec.HEADER_BYTES)
			Codec.writeHeader(b, 0, { seq = 65536 + 3, batchTimeMs = 4294967296 + 5, count = 43 })
			local h = Codec.readHeader(b, 0)
			expect(h.seq).to.equal(3)
			expect(h.batchTimeMs).to.equal(5)
			expect(h.count).to.equal(43)
		end)
	end)

	describe("action extension", function()
		it("round-trips index, variant and elapsed time in 32 ms steps", function()
			local b = buffer.create(Codec.ACTION_BYTES)
			Codec.writeAction(b, 0, { index = 100, variant = 5, elapsedMs = 330 })
			local a = Codec.readAction(b, 0)
			expect(a.index).to.equal(100)
			expect(a.variant).to.equal(5)
			expect(a.elapsedMs).to.equal(320)
		end)

		it("saturates elapsed time at 2016 ms", function()
			local b = buffer.create(Codec.ACTION_BYTES)
			Codec.writeAction(b, 0, { index = 1, variant = 0, elapsedMs = 9000 })
			expect(Codec.readAction(b, 0).elapsedMs).to.equal(Codec.ACTION_ELAPSED_MAX_MS)
		end)
	end)

	describe("unwrapOwnerTime", function()
		it("recovers an owner timestamp from its low 10 bits", function()
			expect(Codec.unwrapOwnerTime(5000, 4970 % 1024)).to.equal(4970)
		end)

		it("recovers a timestamp across a 1024 ms boundary", function()
			expect(Codec.unwrapOwnerTime(1030, 1020 % 1024)).to.equal(1020)
		end)

		it("tolerates an owner up to 64 ms ahead of the server clock", function()
			expect(Codec.unwrapOwnerTime(5000, 5040 % 1024)).to.equal(5040)
		end)

		it("reads a timestamp 900 ms old as old, not as ahead", function()
			expect(Codec.unwrapOwnerTime(5000, 4100 % 1024)).to.equal(4100)
		end)
	end)
end
```

- [ ] **Step 2: Run the tests and verify they fail**

Studio test run. Expected: the suite fails to require `CharacterRecordCodec` (module missing), and `SpecRoots` may also report the spec's missing module.

- [ ] **Step 3: Port the spike codec**

```bash
mkdir -p src/ReplicatedStorage/Shared/Modules/CharacterReplication
git -c safe.directory=* show 07c3aaa:src/ReplicatedStorage/Shared/Spike/SpikeRecordCodec.luau > src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterRecordCodec.luau
```

Then edit `CharacterRecordCodec.luau`:

1. Rename every `SpikeRecordCodec` to `CharacterRecordCodec` (the module table, `@class`, all `SpikeRecordCodec.` references).
2. Replace the doc-comment line `SPIKE — deleted after the replication decision (spec 2026-09-22 §11, CP0).` with `Character record codec (spec 2026-09-22 §6.2; measured in the spike's CP0 and A/B).` and delete the paragraph that begins `Also exposes the deterministic motion function the soak uses` (the synthetic-body helper is not ported).
3. Delete the whole `syntheticBody` function and its doc comment (from `--[=[` `Deterministic synthetic motion for soak body` down to its `end`).
4. Make `clampInt` NaN-safe (a NaN reaching `bit32` is undefined behaviour). Replace:

```luau
local function clampInt(value: number, bits: number): number
	local maxValue = 2 ^ bits - 1
	return math.clamp(math.floor(value + 0.5), 0, maxValue)
end
```

with:

```luau
local function clampInt(value: number, bits: number): number
	local maxValue = 2 ^ bits - 1
	if value ~= value then
		return 0 -- NaN (an owner physics glitch): encode the field's floor rather than an undefined bit pattern
	end
	return math.clamp(math.floor(value + 0.5), 0, maxValue)
end
```

5. Append before `return CharacterRecordCodec`:

```luau
--[=[
	The uplink carries the owner's timestamp as its low 10 bits in `ageMs` (Verdict: 17 B uplink). Recover the
	full value against the server's arrival time. The accepted window is [arrival − 960, arrival + 64] ms: an
	owner clock slightly ahead of the server's reads as "just now", not as a second old.
]=]
CharacterRecordCodec.OWNER_AHEAD_MS = 64

function CharacterRecordCodec.unwrapOwnerTime(arrivalMs: number, low10: number): number
	local ahead = CharacterRecordCodec.OWNER_AHEAD_MS
	return arrivalMs + ahead - ((arrivalMs + ahead - low10) % 1024)
end
```

- [ ] **Step 4: Run the tests and verify they pass**

Studio test run. Expected: every `CharacterRecordCodec` test passes. Then run Format, Lint and Typecheck; all clean.

- [ ] **Step 5: Commit**

```bash
git add src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterRecordCodec.luau src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterRecordCodec.spec.luau
git commit -m "feat(replication): character record codec

The 16 B record, 7 B batch header and 2 B action extension from the spike (measured in CP0 and the
A/B), NaN-safe, plus unwrapping the owner's 10-bit timestamp with a 64 ms ahead window."
```

---

### Task 2: CharacterInterpolator

**Files:**
- Create: `src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterInterpolator.spec.luau`
- Create: `src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterInterpolator.luau` (port of `src/ReplicatedStorage/Shared/Spike/SpikeInterpolator.luau` @ `07c3aaa`)

**Interfaces:**
- Consumes: nothing (pure; does not require the codec).
- Produces:
  - `CharacterInterpolator.MAX_SAMPLES: number` (32), `GRAVITY: number` (185)
  - `export type Sample = { timeMs: number, position: Vector3, velocity: Vector3, yaw: number, state: number, grounded: boolean, rotation: CFrame? }`
  - `export type Buffer = { samples: { Sample }, epoch: number }`
  - `export type Mode = "interpolate" | "extrapolate" | "hold" | "behind" | "empty"`
  - `export type Evaluation = { position: Vector3, velocity: Vector3, yaw: number, state: number, grounded: boolean, rotation: CFrame?, mode: Mode }`
  - `export type Hint = { index: number }`
  - `newBuffer(): Buffer`, `newHint(): Hint`
  - `push(b: Buffer, epoch: number, sample: Sample): boolean` — true when the sample opened a new epoch (the caller snaps)
  - `evaluate(b: Buffer, timeMs: number): Evaluation`
  - `evaluatePosition(b: Buffer, timeMs: number, hint: Hint): (Vector3, Mode)`
  - `reckon(b: Buffer, timeMs: number, maxAheadMs: number, groundBelow: ((position: Vector3) -> number)?): Vector3?`
  - `newestTimeMs(b: Buffer): number?`, `reachMs(b: Buffer, nowMs: number): number`

- [ ] **Step 1: Write the failing spec**

Create `CharacterInterpolator.spec.luau`:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Interp = require(ReplicatedStorage.Shared.Modules.CharacterReplication.CharacterInterpolator)

local function sample(timeMs, x, overrides)
	local s = {
		timeMs = timeMs,
		position = Vector3.new(x, 10, 0),
		velocity = Vector3.new(16, 0, 0),
		yaw = 0,
		state = 8,
		grounded = true,
		rotation = nil,
	}
	for key, value in overrides or {} do
		s[key] = value
	end
	return s
end

-- A body walking +X at 16 studs/s, one sample every 16.67 ms.
local function walking(count, epoch)
	local b = Interp.newBuffer()
	for i = 0, count - 1 do
		local t = i * 1000 / 60
		Interp.push(b, epoch or 0, sample(t, 16 * t / 1000))
	end
	return b
end

return function()
	describe("push", function()
		it("keeps samples in time order and drops exact duplicates", function()
			local b = Interp.newBuffer()
			Interp.push(b, 0, sample(20, 1))
			Interp.push(b, 0, sample(10, 0))
			Interp.push(b, 0, sample(20, 5))
			expect(#b.samples).to.equal(2)
			expect(b.samples[1].timeMs).to.equal(10)
			expect(b.samples[2].position.X).to.equal(1)
		end)

		it("keeps at most MAX_SAMPLES, dropping the oldest", function()
			local b = walking(Interp.MAX_SAMPLES + 5)
			expect(#b.samples).to.equal(Interp.MAX_SAMPLES)
			expect(b.samples[1].timeMs).to.be.near(5 * 1000 / 60, 1e-6)
		end)

		it("flushes on the next epoch and reports it", function()
			local b = walking(5, 3)
			local flushed = Interp.push(b, 4, sample(500, 90))
			expect(flushed).to.equal(true)
			expect(#b.samples).to.equal(1)
			expect(b.epoch).to.equal(4)
		end)

		it("treats 7 -> 0 as the next epoch", function()
			local b = walking(3, 7)
			expect(Interp.push(b, 0, sample(500, 90))).to.equal(true)
			expect(b.epoch).to.equal(0)
		end)

		it("drops a record from an older epoch after a flush", function()
			local b = walking(3, 3)
			Interp.push(b, 4, sample(500, 90))
			local flushed = Interp.push(b, 3, sample(510, 1))
			expect(flushed).to.equal(false)
			expect(#b.samples).to.equal(1)
			expect(b.samples[1].position.X).to.equal(90)
			expect(b.epoch).to.equal(4)
		end)

		it("accepts any epoch on an empty buffer", function()
			local b = Interp.newBuffer()
			expect(Interp.push(b, 6, sample(0, 0))).to.equal(true)
			expect(b.epoch).to.equal(6)
		end)
	end)

	describe("evaluate", function()
		it("evaluate on an empty buffer reports empty", function()
			expect(Interp.evaluate(Interp.newBuffer(), 0).mode).to.equal("empty")
			local _, mode = Interp.evaluatePosition(Interp.newBuffer(), 0, Interp.newHint())
			expect(mode).to.equal("empty")
		end)

		it("passes exactly through the samples", function()
			local b = walking(10)
			local s = b.samples[4]
			expect((Interp.evaluate(b, s.timeMs).position - s.position).Magnitude < 1e-6).to.equal(true)
		end)

		it("follows a straight walk between samples", function()
			local b = walking(10)
			local e = Interp.evaluate(b, 60)
			expect(e.mode).to.equal("interpolate")
			expect(e.position.X).to.be.near(16 * 0.06, 1e-3)
		end)

		it("does not dip below either endpoint when grounded flips (landing)", function()
			local b = Interp.newBuffer()
			Interp.push(b, 0, sample(0, 0, { position = Vector3.new(0, 20, 0), velocity = Vector3.new(0, -150, 0), grounded = false }))
			Interp.push(b, 0, sample(33, 0, { position = Vector3.new(0, 10, 0), velocity = Vector3.new(0, 0, 0), grounded = true }))
			for t = 0, 33, 3 do
				expect(Interp.evaluate(b, t).position.Y >= 10 - 1e-6).to.equal(true)
			end
		end)

		it("reports behind before the oldest sample and hold past the extrapolation window", function()
			local b = walking(5)
			expect(Interp.evaluate(b, -50).mode).to.equal("behind")
			local newest = b.samples[#b.samples].timeMs
			expect(Interp.evaluate(b, newest + 50).mode).to.equal("extrapolate")
			expect(Interp.evaluate(b, newest + 500).mode).to.equal("hold")
		end)

		it("evaluatePosition matches evaluate at every frame of a walk", function()
			local b = walking(20)
			local hint = Interp.newHint()
			for t = 0, 300, 7 do
				local position, mode = Interp.evaluatePosition(b, t, hint)
				local e = Interp.evaluate(b, t)
				expect(mode).to.equal(e.mode)
				expect((position - e.position).Magnitude < 1e-6).to.equal(true)
			end
		end)
	end)

	describe("reckon", function()
		it("reckon with one sample moves it along its horizontal velocity", function()
			local b = Interp.newBuffer()
			Interp.push(b, 0, sample(0, 0))
			local p = Interp.reckon(b, 50, 60, nil)
			expect(p.X).to.be.near(0.8, 1e-6)
			expect(p.Y).to.equal(10)
		end)

		it("returns nil on an empty buffer", function()
			expect(Interp.reckon(Interp.newBuffer(), 0, 60, nil)).to.equal(nil)
		end)

		it("stops at maxAheadMs", function()
			local b = Interp.newBuffer()
			Interp.push(b, 0, sample(0, 0))
			expect(Interp.reckon(b, 1000, 60, nil).X).to.be.near(16 * 0.06, 1e-6)
		end)

		it("applies gravity to an airborne body and stops it at the ground", function()
			local b = Interp.newBuffer()
			Interp.push(b, 0, sample(0, 0, { position = Vector3.new(0, 11, 0), velocity = Vector3.new(0, -100, 0), grounded = false }))
			local free = Interp.reckon(b, 60, 60, nil)
			expect(free.Y).to.equal(11) -- no world query: never guess a body through a floor
			local grounded = Interp.reckon(b, 60, 60, function()
				return 10
			end)
			expect(grounded.Y).to.equal(10)
			local open = Interp.reckon(b, 60, 60, function()
				return -500
			end)
			expect(open.Y).to.be.near(11 - 100 * 0.06 - 0.5 * 185 * 0.06 * 0.06, 1e-6)
		end)
	end)

	describe("reach", function()
		it("reach is unlimited until the buffer is full", function()
			expect(Interp.reachMs(walking(3), 1000)).to.equal(math.huge)
		end)

		it("is the age of the oldest sample once the buffer is full", function()
			local b = walking(Interp.MAX_SAMPLES)
			expect(Interp.reachMs(b, 1000)).to.be.near(1000 - b.samples[1].timeMs, 1e-6)
		end)

		it("reports the newest sample time", function()
			expect(Interp.newestTimeMs(Interp.newBuffer())).to.equal(nil)
			expect(Interp.newestTimeMs(walking(4))).to.be.near(50, 1e-6)
		end)
	end)
end
```

- [ ] **Step 2: Run the tests and verify they fail**

Studio test run. Expected: `CharacterInterpolator` cannot be required.

- [ ] **Step 3: Port the spike interpolator**

```bash
git -c safe.directory=* show 07c3aaa:src/ReplicatedStorage/Shared/Spike/SpikeInterpolator.luau > src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterInterpolator.luau
```

Then edit `CharacterInterpolator.luau`:

1. Rename every `SpikeInterpolator` to `CharacterInterpolator`. Replace the doc line `SPIKE — deleted after the replication decision (spec 2026-09-22 §6.6, CP4 puppets).` with `Character interpolator (spec 2026-09-22 §6.6, §6.7; measured in the spike's CP4 and A/B).`
2. Replace `local MAX_SAMPLES = 16` with:

```luau
-- 32 samples = 533 ms of 60 Hz history: the render clock's delay (up to ~330 ms on a mobile link) must stay
-- inside what the buffer holds (Verdict: "never further back than a full buffer reaches").
local MAX_SAMPLES = 32
local GRAVITY = 185
CharacterInterpolator.MAX_SAMPLES = MAX_SAMPLES
CharacterInterpolator.GRAVITY = GRAVITY
```

3. Add a `Mode` type and use it. After the `Buffer` type add:

```luau
export type Mode = "interpolate" | "extrapolate" | "hold" | "behind" | "empty"
```

In `Evaluation`, replace the `mode: "interpolate" | "extrapolate" | "hold" | "behind" | "empty",` field with `mode: Mode,`. In `evaluatePosition`'s signature, replace the return type `(Vector3, "interpolate" | "extrapolate" | "hold" | "behind" | "empty")` with `(Vector3, Mode)`.

4. Replace the epoch handling at the top of `push` (spec §6.7: only the NEXT epoch flushes; anything else from another epoch is a straggler). Replace:

```luau
	local flushed = false
	if epoch ~= b.epoch then
		b.epoch = epoch
		table.clear(b.samples)
		flushed = true
	end
```

with:

```luau
	local flushed = false
	if epoch ~= b.epoch then
		if b.epoch >= 0 and epoch ~= (b.epoch + 1) % 8 then
			return false -- a straggler from an older epoch (or a skipped one; R2's reliable slot table resets those)
		end
		b.epoch = epoch
		table.clear(b.samples)
		flushed = true
	end
```

and update `push`'s doc comment sentence `A new epoch flushes the buffer (teleport / respawn)` to `The next epoch (current + 1 mod 8) flushes the buffer (teleport / respawn); a record from any other epoch is dropped`.

5. Append before `return CharacterInterpolator`:

```luau
--[=[
	State-aware dead reckoning past the newest sample (A/B finding: a lost landing packet used to draw the body
	through the floor at 180 studs/s). Horizontal motion continues at the sent velocity; an airborne body falls
	under gravity and stops at `groundBelow` (the viewer's downward raycast); with no world query, an airborne
	body is never extrapolated downward. At most `maxAheadMs` past the newest sample.
]=]
function CharacterInterpolator.reckon(
	b: Buffer,
	timeMs: number,
	maxAheadMs: number,
	groundBelow: ((position: Vector3) -> number)?
): Vector3?
	local newest = b.samples[#b.samples]
	if newest == nil then
		return nil
	end
	local ahead = math.clamp(timeMs - newest.timeMs, 0, maxAheadMs) / 1000
	local v = newest.velocity
	local position = newest.position + Vector3.new(v.X, 0, v.Z) * ahead
	local y = if newest.grounded
		then newest.position.Y
		else newest.position.Y + v.Y * ahead - 0.5 * GRAVITY * ahead * ahead
	if groundBelow ~= nil then
		y = math.max(y, groundBelow(Vector3.new(position.X, newest.position.Y, position.Z)))
	elseif not newest.grounded and y < newest.position.Y then
		y = newest.position.Y
	end
	return Vector3.new(position.X, y, position.Z)
end

function CharacterInterpolator.newestTimeMs(b: Buffer): number?
	local newest = b.samples[#b.samples]
	return if newest ~= nil then newest.timeMs else nil
end

--[=[
	How far back from `nowMs` this buffer can still be rendered. Unlimited until the buffer is full (a body that
	just appeared must not drag the render clock down); once full, the oldest sample's age.
]=]
function CharacterInterpolator.reachMs(b: Buffer, nowMs: number): number
	local samples = b.samples
	if #samples < MAX_SAMPLES then
		return math.huge
	end
	return nowMs - samples[1].timeMs
end
```

- [ ] **Step 4: Run the tests and verify they pass**

Studio test run: every `CharacterInterpolator` test passes. Format, Lint, Typecheck clean.

- [ ] **Step 5: Commit**

```bash
git add src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterInterpolator.luau src/ReplicatedStorage/Shared/Modules/CharacterReplication/CharacterInterpolator.spec.luau
git commit -m "feat(replication): character interpolator with dead reckoning

Hermite with the sent velocity and the zero-allocation fast path from the spike, a 32-sample buffer,
next-epoch-only flushes (older stragglers are dropped), gravity and ground dead reckoning, and the
buffer's reach for the render clock."
```

---

### Task 3: RenderClock

**Files:**
- Create: `src/ReplicatedStorage/Shared/Modules/CharacterReplication/RenderClock.spec.luau`
- Create: `src/ReplicatedStorage/Shared/Modules/CharacterReplication/RenderClock.luau`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `export type Config = { frameMs: number, latenessPct: number, spacingIntervals: number, marginMs: number, riseMsPerSecond: number, fallMsPerSecond: number, hysteresisMs: number, jumpAboveMs: number, maxDelayMs: number, initialDelayMs: number, window: number, lossWindow: number, retargetMs: number, maxLatenessMs: number, localStallMs: number, stallBlockMs: number }`
  - `RenderClock.DEFAULT_CONFIG: Config`
  - `export type Clock` (opaque to callers except `delayMs`, `lossLevel`, `skipped`)
  - `new(config: Config?): Clock`
  - `noteFrame(clock: Clock, nowMs: number)` — call once per rendered frame, BEFORE `advance`
  - `onBatch(clock: Clock, nowMs: number, seq: number, latenessMs: number, isNewSample: boolean)` — call per received batch
  - `advance(clock: Clock, nowMs: number, starving: boolean, reachMs: number): number` — returns the delay to render with

- [ ] **Step 1: Write the failing spec**

Create `RenderClock.spec.luau`:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RenderClock = require(ReplicatedStorage.Shared.Modules.CharacterReplication.RenderClock)

local FRAME = 1000 / 60

-- Drive a clock for `seconds` of 60 Hz frames with one batch per frame at `lateness` ms, seq +1 each frame
-- (or +`seqStep`). Returns the clock and the time reached.
local function drive(clock, fromMs, seconds, lateness, seqStep, startSeq)
	local now = fromMs
	local seq = startSeq or 0
	for _ = 1, math.floor(seconds * 60) do
		now += FRAME
		RenderClock.noteFrame(clock, now)
		seq = (seq + (seqStep or 1)) % 65536
		RenderClock.onBatch(clock, now, seq, lateness, true)
		RenderClock.advance(clock, now, false, math.huge)
	end
	return clock, now, seq
end

local function target(lateness, lossLevel)
	return lateness + (lossLevel + 1) * FRAME + 4
end

return function()
	describe("steady network", function()
		it("starts at the initial delay", function()
			expect(RenderClock.new().delayMs).to.equal(100)
		end)

		it("jumps to a target more than 25 ms above", function()
			local clock = drive(RenderClock.new(), 0, 1, 150)
			expect(clock.delayMs).to.be.near(target(150, 0), 0.01)
		end)

		it("ignores target moves under the 6 ms hysteresis", function()
			local clock = drive(RenderClock.new(), 0, 1, 150)
			drive(clock, 1000, 1, 153)
			expect(clock.delayMs).to.be.near(target(150, 0), 0.01)
		end)

		-- The next three set the target directly (white-box) so the rate is measured exactly: `sinceRetargetMs = 0`
		-- keeps a retarget from replacing it during the advances.
		it("glides up at 60 ms/s toward a target less than 25 ms above", function()
			local clock, now = drive(RenderClock.new(), 0, 5, 150)
			local start = clock.delayMs
			clock.targetMs = start + 15
			clock.sinceRetargetMs = 0
			RenderClock.advance(clock, now + 100, false, math.huge)
			expect(clock.delayMs).to.be.near(start + 6, 1e-6)
			RenderClock.advance(clock, now + 200, false, math.huge)
			expect(clock.delayMs).to.be.near(start + 12, 1e-6)
		end)

		it("jumps when starving even for a small rise", function()
			local clock, now = drive(RenderClock.new(), 0, 5, 150)
			local start = clock.delayMs
			clock.targetMs = start + 15
			clock.sinceRetargetMs = 0
			RenderClock.advance(clock, now + 16, true, math.huge)
			expect(clock.delayMs).to.be.near(start + 15, 1e-6)
		end)

		it("falls at 15 ms/s", function()
			local clock, now = drive(RenderClock.new(), 0, 5, 300)
			local start = clock.delayMs
			clock.targetMs = start - 50
			for i = 1, 10 do
				clock.sinceRetargetMs = 0
				RenderClock.advance(clock, now + i * 100, false, math.huge)
			end
			expect(clock.delayMs).to.be.near(start - 15, 1e-6)
		end)

		it("never exceeds 600 ms", function()
			local clock = drive(RenderClock.new(), 0, 5, 950)
			expect(clock.delayMs).to.equal(600)
		end)
	end)

	describe("loss", function()
		it("adds one interval at 1.5–6 % loss and two above 6 %", function()
			local clock = drive(RenderClock.new(), 0, 5, 150, 2) -- every other batch lost: 50 %
			expect(clock.lossLevel).to.equal(2)
			expect(clock.delayMs).to.be.near(target(150, 2), 0.01)
		end)

		it("counts a seq wrap as one step", function()
			local clock = drive(RenderClock.new(), 0, 5, 150, 1, 65536 - 100)
			expect(clock.lossLevel).to.equal(0)
		end)

		it("ignores a reordered older batch instead of counting it as loss", function()
			local clock = RenderClock.new()
			local now = 0
			for seq = 1, 300 do
				now += FRAME
				RenderClock.noteFrame(clock, now)
				RenderClock.onBatch(clock, now, seq, 150, true)
				if seq % 10 == 0 then
					RenderClock.onBatch(clock, now, seq - 3, 150, false) -- a late duplicate
				end
				RenderClock.advance(clock, now, false, math.huge)
			end
			expect(clock.lossLevel).to.equal(0)
		end)
	end)

	describe("lateness sampling", function()
		it("does not let resends and repairs (old samples) vote", function()
			local clock, now = drive(RenderClock.new(), 0, 3, 150)
			for i = 1, 200 do
				RenderClock.onBatch(clock, now, i + 5000, 900, false)
			end
			drive(clock, now, 1, 150, 1, 5200)
			expect(clock.delayMs).to.be.near(target(150, 0), 0.01)
		end)

		it("keeps batches processed right after a local stall out of the delay", function()
			local clock, now, seq = drive(RenderClock.new(), 0, 5, 80)
			local before = clock.delayMs
			-- The window was in the background for 1.6 s; the backlog is processed in the frame that ends it.
			now += 1600
			for i = 1, 96 do
				RenderClock.onBatch(clock, now, (seq + i) % 65536, 1600 - i * FRAME, true)
			end
			RenderClock.noteFrame(clock, now)
			for i = 97, 100 do
				RenderClock.onBatch(clock, now + 5, (seq + i) % 65536, 1500, true)
			end
			RenderClock.advance(clock, now, false, math.huge)
			drive(clock, now, 1, 80, 1, (seq + 100) % 65536)
			expect(clock.skipped).to.equal(100)
			expect(clock.delayMs).to.be.near(before, 0.01)
		end)
	end)

	describe("reach", function()
		it("never renders further back than the buffers reach", function()
			local clock, now = drive(RenderClock.new(), 0, 5, 300)
			RenderClock.noteFrame(clock, now + FRAME)
			local delay = RenderClock.advance(clock, now + FRAME, false, 200)
			expect(delay).to.equal(200)
		end)
	end)
end
```

- [ ] **Step 2: Run the tests and verify they fail**

Studio test run. Expected: `RenderClock` cannot be required.

- [ ] **Step 3: Write the implementation**

Create `RenderClock.luau`:

```luau
--!strict
--[=[
	Per-viewer render delay controller (spec 2026-09-22 §6.6, as superseded by the Verdict: the "v3" clock
	measured in the spike's A/B).

	The delay a viewer renders remote bodies behind real time is chosen from what this viewer measures:

	  target = p95(lateness of NEW samples) + (lossLevel + 1) × frame + margin

	retargeted every 250 ms with hysteresis. The delay jumps up when the target is far above or the renderer is
	starving, glides up otherwise, and falls slowly. It never exceeds `maxDelayMs`, and never renders further back
	than the sample buffers reach (`reachMs`, from `CharacterInterpolator.reachMs`).

	Two developer-run findings are built in:
	  - Resends and repairs carry OLD samples: only samples newer than the buffer's newest vote on lateness.
	  - A local stall (window in the background, a long frame) makes the backlog look late. Batches processed
	    within `stallBlockMs` after a frame gap over `localStallMs`, or before the stalled frame is noted, feed
	    the buffer but do not vote.

	Pure: time is passed in (ms), so client code and specs drive it the same way.

	@class RenderClock
]=]

local RenderClock = {}

export type Config = {
	frameMs: number,
	latenessPct: number,
	spacingIntervals: number,
	marginMs: number,
	riseMsPerSecond: number,
	fallMsPerSecond: number,
	hysteresisMs: number,
	jumpAboveMs: number,
	maxDelayMs: number,
	initialDelayMs: number,
	window: number,
	lossWindow: number,
	retargetMs: number,
	maxLatenessMs: number,
	localStallMs: number,
	stallBlockMs: number,
}

local DEFAULT_CONFIG: Config = {
	frameMs = 1000 / 60,
	latenessPct = 0.95,
	spacingIntervals = 1,
	marginMs = 4,
	riseMsPerSecond = 60,
	fallMsPerSecond = 15,
	hysteresisMs = 6,
	jumpAboveMs = 25,
	maxDelayMs = 600,
	initialDelayMs = 100,
	window = 240,
	lossWindow = 240,
	retargetMs = 250,
	maxLatenessMs = 1000,
	localStallMs = 100,
	stallBlockMs = 100,
}
RenderClock.DEFAULT_CONFIG = DEFAULT_CONFIG

export type Clock = {
	config: Config,
	lateness: { number },
	latenessIndex: number,
	lossSteps: { number },
	lossIndex: number,
	lastSeq: number?,
	lossLevel: number,
	delayMs: number,
	targetMs: number,
	sinceRetargetMs: number,
	lastAdvanceMs: number?,
	lastFrameMs: number?,
	blockedUntilMs: number,
	skipped: number,
}

function RenderClock.new(config: Config?): Clock
	local cfg = config or DEFAULT_CONFIG
	return {
		config = cfg,
		lateness = {},
		latenessIndex = 0,
		lossSteps = {},
		lossIndex = 0,
		lastSeq = nil,
		lossLevel = 0,
		delayMs = cfg.initialDelayMs,
		targetMs = cfg.initialDelayMs,
		sinceRetargetMs = 0,
		lastAdvanceMs = nil,
		lastFrameMs = nil,
		blockedUntilMs = -math.huge,
		skipped = 0,
	}
end

local function percentile(values: { number }, p: number): number
	if #values == 0 then
		return 0
	end
	local sorted = table.clone(values)
	table.sort(sorted)
	return sorted[math.clamp(math.ceil(#sorted * p), 1, #sorted)]
end

local function stalled(clock: Clock, nowMs: number): boolean
	local lastFrame = clock.lastFrameMs
	return nowMs < clock.blockedUntilMs or (lastFrame ~= nil and nowMs - lastFrame > clock.config.localStallMs)
end

--[=[
	Once per rendered frame, before `advance`. A frame gap over `localStallMs` blocks lateness voting for
	`stallBlockMs`.
]=]
function RenderClock.noteFrame(clock: Clock, nowMs: number)
	local lastFrame = clock.lastFrameMs
	if lastFrame ~= nil and nowMs - lastFrame > clock.config.localStallMs then
		clock.blockedUntilMs = nowMs + clock.config.stallBlockMs
	end
	clock.lastFrameMs = nowMs
end

--[=[
	Per received batch. `latenessMs` is arrival time minus the newest record's sample time; `isNewSample` is
	false for a resend or repair whose sample the buffer already holds.
]=]
function RenderClock.onBatch(clock: Clock, nowMs: number, seq: number, latenessMs: number, isNewSample: boolean)
	local cfg = clock.config
	local lastSeq = clock.lastSeq
	if lastSeq == nil then
		clock.lastSeq = seq
	else
		local step = (seq - lastSeq) % 65536
		if step > 0 and step < 1000 then
			clock.lossIndex = clock.lossIndex % cfg.lossWindow + 1
			clock.lossSteps[clock.lossIndex] = step
			clock.lastSeq = seq
		end
	end
	if not isNewSample then
		return
	end
	if stalled(clock, nowMs) then
		clock.skipped += 1 -- before the lateness cap: a stall backlog is mostly over 1 s late and must be counted
		return
	end
	if latenessMs >= cfg.maxLatenessMs then
		return
	end
	clock.latenessIndex = clock.latenessIndex % cfg.window + 1
	clock.lateness[clock.latenessIndex] = latenessMs
end

local function retarget(clock: Clock)
	local cfg = clock.config
	local expected = 0
	for _, step in clock.lossSteps do
		expected += step
	end
	local lossRate = if expected > 0 then 1 - #clock.lossSteps / expected else 0
	clock.lossLevel = if lossRate > 0.06 then 2 elseif lossRate > 0.015 then 1 else 0
	local candidate = percentile(clock.lateness, cfg.latenessPct)
		+ (clock.lossLevel + cfg.spacingIntervals) * cfg.frameMs
		+ cfg.marginMs
	if math.abs(candidate - clock.targetMs) >= cfg.hysteresisMs then
		clock.targetMs = candidate
	end
end

--[=[
	Once per rendered frame. `starving` is whether last frame's evaluation ran out of samples (hold / behind);
	`reachMs` is the smallest `CharacterInterpolator.reachMs` across visible bodies. Returns the delay.
]=]
function RenderClock.advance(clock: Clock, nowMs: number, starving: boolean, reachMs: number): number
	local cfg = clock.config
	local lastAdvance = clock.lastAdvanceMs
	local dtMs = if lastAdvance ~= nil then math.clamp(nowMs - lastAdvance, 0, 100) else 0
	clock.lastAdvanceMs = nowMs
	clock.sinceRetargetMs += dtMs
	if clock.sinceRetargetMs >= cfg.retargetMs then
		clock.sinceRetargetMs = 0
		retarget(clock)
	end
	local target = math.min(clock.targetMs, cfg.maxDelayMs, reachMs)
	if target > clock.delayMs then
		local jump = starving or target - clock.delayMs > cfg.jumpAboveMs
		clock.delayMs = if jump then target else math.min(target, clock.delayMs + cfg.riseMsPerSecond * dtMs / 1000)
	elseif clock.delayMs > reachMs or clock.delayMs > cfg.maxDelayMs then
		clock.delayMs = target -- the buffers can't serve this delay: come forward at once
	else
		clock.delayMs = math.max(target, clock.delayMs - cfg.fallMsPerSecond * dtMs / 1000)
	end
	return clock.delayMs
end

return RenderClock
```

- [ ] **Step 4: Run the tests and verify they pass**

Studio test run: every `RenderClock` test passes. If `glides up at 60 ms/s` or `falls at 15 ms/s` fails by a frame's worth, check the arithmetic in the spec against `advance` before changing either: the implementation above is the harness-measured behaviour and is the source of truth; fix the spec's timing, not the constants. Format, Lint, Typecheck clean.

- [ ] **Step 5: Commit**

```bash
git add src/ReplicatedStorage/Shared/Modules/CharacterReplication/RenderClock.luau src/ReplicatedStorage/Shared/Modules/CharacterReplication/RenderClock.spec.luau
git commit -m "feat(replication): render clock

The measured v3 delay controller: p95 lateness of new samples plus spacing and a loss term over the
last 240 batches, glide up, jump when starving or far off, slow fall, capped at 600 ms and at the
buffers' reach. Batches processed right after a local stall do not vote (tab-out froze puppets)."
```

---

### Task 4: SendPolicy

**Files:**
- Create: `src/ReplicatedStorage/Shared/Modules/CharacterReplication/SendPolicy.spec.luau`
- Create: `src/ReplicatedStorage/Shared/Modules/CharacterReplication/SendPolicy.luau`

**Interfaces:**
- Consumes: `CharacterRecordCodec.Record` (type only).
- Produces:
  - `export type Config = { repairMs: number, resends: number, resendSpacingMs: number }`, `SendPolicy.DEFAULT_CONFIG: Config` (1000, 2, 50)
  - `export type Decision = "change" | "resend" | "repair"`
  - `export type Policy`
  - `new(config: Config?): Policy`
  - `changed(previous: CharacterRecordCodec.Record?, current: CharacterRecordCodec.Record): boolean`
  - `decide(policy: Policy, nowMs: number, changed: boolean): Decision?`

- [ ] **Step 1: Write the failing spec**

Create `SendPolicy.spec.luau`:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SendPolicy = require(ReplicatedStorage.Shared.Modules.CharacterReplication.SendPolicy)

local function record(overrides)
	local r = {
		slot = 1,
		generation = 0,
		epoch = 0,
		ageMs = 0,
		position = Vector3.new(0, 10, 0),
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

return function()
	describe("changed", function()
		it("treats a first record as a change", function()
			expect(SendPolicy.changed(nil, record())).to.equal(true)
		end)

		it("ignores sub-threshold jitter and the timestamp field", function()
			local a = record()
			local b = record({ position = Vector3.new(0.01, 10, 0), velocity = Vector3.new(0.02, 0, 0), ageMs = 500 })
			expect(SendPolicy.changed(a, b)).to.equal(false)
		end)

		it("sees movement, state, grounded, epoch, action and aim", function()
			local a = record()
			expect(SendPolicy.changed(a, record({ position = Vector3.new(0.05, 10, 0) }))).to.equal(true)
			expect(SendPolicy.changed(a, record({ velocity = Vector3.new(0, 0.1, 0) }))).to.equal(true)
			expect(SendPolicy.changed(a, record({ state = 3 }))).to.equal(true)
			expect(SendPolicy.changed(a, record({ grounded = false }))).to.equal(true)
			expect(SendPolicy.changed(a, record({ epoch = 1 }))).to.equal(true)
			expect(SendPolicy.changed(a, record({ hasAction = true }))).to.equal(true)
			expect(SendPolicy.changed(a, record({ yaw = 0.1 }))).to.equal(true)
			expect(SendPolicy.changed(a, record({ pitch = 0.1 }))).to.equal(true)
		end)

		it("compares yaw across the ±π seam", function()
			expect(SendPolicy.changed(record({ yaw = math.pi - 0.005 }), record({ yaw = -math.pi + 0.005 }))).to.equal(false)
		end)

		it("sees a ragdoll rotation change and ignores an identical one", function()
			local a = record({ state = 29, rotation = CFrame.Angles(0, 1, 0) })
			expect(SendPolicy.changed(a, record({ state = 29, rotation = CFrame.Angles(0, 1, 0) }))).to.equal(false)
			expect(SendPolicy.changed(a, record({ state = 29, rotation = CFrame.Angles(0, 1.2, 0) }))).to.equal(true)
			expect(SendPolicy.changed(a, record({ state = 29, rotation = nil }))).to.equal(true)
		end)
	end)

	describe("decide", function()
		it("sends every change", function()
			local p = SendPolicy.new()
			for t = 0, 100, 16 do
				expect(SendPolicy.decide(p, t, true)).to.equal("change")
			end
		end)

		it("resends the last change twice, 50 ms apart, then goes quiet", function()
			local p = SendPolicy.new()
			expect(SendPolicy.decide(p, 0, true)).to.equal("change")
			local decisions = {}
			for t = 16, 900, 16 do
				local d = SendPolicy.decide(p, t, false)
				if d ~= nil then
					table.insert(decisions, { t = t, d = d })
				end
			end
			expect(#decisions).to.equal(2)
			expect(decisions[1].d).to.equal("resend")
			expect(decisions[1].t).to.equal(64)
			expect(decisions[2].d).to.equal("resend")
			expect(decisions[2].t).to.equal(128)
		end)

		it("repairs 1 s after the last send", function()
			local p = SendPolicy.new()
			SendPolicy.decide(p, 0, true)
			SendPolicy.decide(p, 64, false)
			SendPolicy.decide(p, 128, false)
			expect(SendPolicy.decide(p, 1127, false)).to.equal(nil)
			expect(SendPolicy.decide(p, 1128, false)).to.equal("repair")
			expect(SendPolicy.decide(p, 1500, false)).to.equal(nil)
			expect(SendPolicy.decide(p, 2128, false)).to.equal("repair")
		end)

		it("restarts the resends on a new change", function()
			local p = SendPolicy.new()
			SendPolicy.decide(p, 0, true)
			SendPolicy.decide(p, 64, false)
			SendPolicy.decide(p, 80, true)
			expect(SendPolicy.decide(p, 112, false)).to.equal(nil)
			expect(SendPolicy.decide(p, 130, false)).to.equal("resend")
			expect(SendPolicy.decide(p, 180, false)).to.equal("resend")
			expect(SendPolicy.decide(p, 240, false)).to.equal(nil)
		end)

		it("honours a custom config", function()
			local p = SendPolicy.new({ repairMs = 200, resends = 0, resendSpacingMs = 50 })
			SendPolicy.decide(p, 0, true)
			expect(SendPolicy.decide(p, 100, false)).to.equal(nil)
			expect(SendPolicy.decide(p, 200, false)).to.equal("repair")
		end)
	end)
end
```

- [ ] **Step 2: Run the tests and verify they fail**

Studio test run. Expected: `SendPolicy` cannot be required.

- [ ] **Step 3: Write the implementation**

Create `SendPolicy.luau`:

```luau
--!strict
--[=[
	When to send a body's record (Verdict: the v3 send policy, measured in the spike's A/B). Used for both links:
	the owner's uplink and each body's downlink.

	  change   the record differs from the last one sent (`changed`): send it.
	  resend   after the last change, `resends` more copies `resendSpacingMs` apart. Without them, losing the final
	           change before a body goes still (a respawn, a stop) leaves viewers drawing the old spot until the
	           repair: measured once in 32 mobile runs, 97 studs off.
	  repair   `repairMs` after the last send of any kind, so a still body is confirmed and a new viewer catches up.

	Pure: time is passed in (ms).

	@class SendPolicy
]=]

local CharacterRecordCodec = require(script.Parent.CharacterRecordCodec)

local SendPolicy = {}

export type Config = {
	repairMs: number,
	resends: number,
	resendSpacingMs: number,
}

local DEFAULT_CONFIG: Config = {
	repairMs = 1000,
	resends = 2,
	resendSpacingMs = 50,
}
SendPolicy.DEFAULT_CONFIG = DEFAULT_CONFIG

export type Decision = "change" | "resend" | "repair"

export type Policy = {
	config: Config,
	lastSentMs: number,
	resendsLeft: number,
	nextResendMs: number,
}

-- Below these, two records draw the same body (quantisation is 1/64 stud and ~1.4°).
local POSITION_EPSILON = 0.02
local VELOCITY_EPSILON = 0.05
local ANGLE_EPSILON = 0.03
local ROTATION_EPSILON = 1e-3

local function angleDelta(a: number, b: number): number
	return math.abs((a - b + math.pi) % (2 * math.pi) - math.pi)
end

local function rotationChanged(a: CFrame?, b: CFrame?): boolean
	if a == nil or b == nil then
		return a ~= b
	end
	return not a:FuzzyEq(b, ROTATION_EPSILON)
end

function SendPolicy.new(config: Config?): Policy
	return {
		config = config or DEFAULT_CONFIG,
		lastSentMs = -math.huge,
		resendsLeft = 0,
		nextResendMs = 0,
	}
end

--[=[
	Whether `current` draws a different body from `previous` (the timestamp field `ageMs` is ignored).
]=]
function SendPolicy.changed(previous: CharacterRecordCodec.Record?, current: CharacterRecordCodec.Record): boolean
	if previous == nil then
		return true
	end
	return (previous.position - current.position).Magnitude >= POSITION_EPSILON
		or (previous.velocity - current.velocity).Magnitude >= VELOCITY_EPSILON
		or angleDelta(previous.yaw, current.yaw) >= ANGLE_EPSILON
		or math.abs(previous.pitch - current.pitch) >= ANGLE_EPSILON
		or previous.state ~= current.state
		or previous.grounded ~= current.grounded
		or previous.epoch ~= current.epoch
		or previous.hasAction ~= current.hasAction
		or rotationChanged(previous.rotation, current.rotation)
end

--[=[
	What to send at `nowMs`, given whether the record changed since the last send. `nil` = send nothing.
]=]
function SendPolicy.decide(policy: Policy, nowMs: number, changed: boolean): Decision?
	local cfg = policy.config
	local decision: Decision? = nil
	if changed then
		policy.resendsLeft = cfg.resends
		policy.nextResendMs = nowMs + cfg.resendSpacingMs
		decision = "change"
	elseif policy.resendsLeft > 0 and nowMs >= policy.nextResendMs then
		policy.resendsLeft -= 1
		policy.nextResendMs = nowMs + cfg.resendSpacingMs
		decision = "resend"
	elseif nowMs - policy.lastSentMs >= cfg.repairMs then
		decision = "repair"
	end
	if decision ~= nil then
		policy.lastSentMs = nowMs
	end
	return decision
end

return SendPolicy
```

- [ ] **Step 4: Run the tests and verify they pass**

Studio test run: every `SendPolicy` test passes. Format, Lint, Typecheck clean.

- [ ] **Step 5: Commit**

```bash
git add src/ReplicatedStorage/Shared/Modules/CharacterReplication/SendPolicy.luau src/ReplicatedStorage/Shared/Modules/CharacterReplication/SendPolicy.spec.luau
git commit -m "feat(replication): send policy

Send on change, two resends of the last change 50 ms apart, and a 1 Hz repair, for both links, plus
the record change test the policy runs on (yaw compared across the seam, timestamp ignored)."
```

---

### Task 5: Harness and the acceptance spec

**Files:**
- Create: `src/ReplicatedStorage/Shared/Modules/CharacterReplication/Harness/HarnessNetwork.luau` (port, `07c3aaa`)
- Create: `src/ReplicatedStorage/Shared/Modules/CharacterReplication/Harness/HarnessTrace.luau` (port + `withIdle`)
- Create: `src/ReplicatedStorage/Shared/Modules/CharacterReplication/Harness/HarnessRunner.luau` (port + local-stall option)
- Create: `src/ReplicatedStorage/Shared/Modules/CharacterReplication/Harness/HarnessVenture.spec.luau`
- Create: `src/ReplicatedStorage/Shared/Modules/CharacterReplication/Harness/HarnessVenture.luau`
- Modify: `src/ServerScriptService/Modules/SpecRoots.luau` (`EXEMPT_MODULES`)

**Interfaces:**
- Consumes: all four modules from Tasks 1–4, exactly as listed in their Produces blocks.
- Produces:
  - `HarnessTrace.parkour(origin: Vector3): Trace`, `HarnessTrace.withIdle(base: Trace, plan: { number | "P" }): Trace`, `HarnessTrace.groundBelow(trace, position): number`, `HarnessTrace.FRAME_MS`
  - `HarnessNetwork.PROFILES.studio | good | spec | mobile`
  - `HarnessRunner.run(system, trace, profile, seed, viewerDistance, options: RunOptions?): Result`, `export type RunOptions = { stallAtMs: number?, stallForMs: number? }`
  - `HarnessVenture.new(options: Options?): (HarnessRunner.System, Probe)`, `export type Options = { groundBelow: ((position: Vector3) -> number)?, uplinkOnChange: boolean? }`, `export type Probe = { delayLog: { { atMs: number, delayMs: number } } }`

- [ ] **Step 1: Port the harness infrastructure**

```bash
H=src/ReplicatedStorage/Shared/Modules/CharacterReplication/Harness
mkdir -p $H
for f in HarnessNetwork HarnessTrace HarnessRunner; do
  git -c safe.directory=* show 07c3aaa:src/ReplicatedStorage/Shared/Spike/Harness/$f.luau > $H/$f.luau
done
```

In all three files replace the doc line `SPIKE — deleted after the replication decision (spec §10: the A/B harness).` with `Replication harness (spec 2026-09-22 §10), ported from the spike's A/B.`

In `HarnessRunner.luau`, add the local-stall option (a viewer whose window is in the background: it neither receives nor renders, and the backlog lands in the frame that ends the stall). Replace:

```luau
function HarnessRunner.run(
	system: System,
	trace: HarnessTrace.Trace,
	profile: HarnessNetwork.Profile,
	seed: number,
	viewerDistance: number
): Result
	local frameMs = HarnessTrace.FRAME_MS
```

with:

```luau
export type RunOptions = {
	stallAtMs: number?, -- the viewer stops processing (window in the background) at this time...
	stallForMs: number?, -- ...for this long; packets queue and all land in the next processed frame
}

function HarnessRunner.run(
	system: System,
	trace: HarnessTrace.Trace,
	profile: HarnessNetwork.Profile,
	seed: number,
	viewerDistance: number,
	options: RunOptions?
): Result
	local frameMs = HarnessTrace.FRAME_MS
	local stallAtMs = if options ~= nil then options.stallAtMs else nil
	local stallForMs = if options ~= nil and options.stallForMs ~= nil then options.stallForMs else 0
```

and replace:

```luau
		for _, payload in HarnessNetwork.receive(down, nowMs) do
			system.viewerReceive(nowMs, payload)
		end
		local position = system.viewerRender(nowMs)
		if position ~= nil then
			rendered[f] = position
		end
```

with:

```luau
		local viewerStalled = stallAtMs ~= nil and nowMs >= stallAtMs and nowMs < stallAtMs + stallForMs
		if not viewerStalled then
			for _, payload in HarnessNetwork.receive(down, nowMs) do
				system.viewerReceive(nowMs, payload)
			end
			local position = system.viewerRender(nowMs)
			if position ~= nil then
				rendered[f] = position
			end
		end
```

In `HarnessTrace.luau`, append before `return HarnessTrace`:

```luau
--[=[
	A session with idle time: `plan` is a list of steps, each either "P" (the parkour trace, continued from where
	the body stands) or a number of seconds standing still. Teleport and respawn frames are carried over.
]=]
function HarnessTrace.withIdle(base: Trace, plan: { number | "P" }): Trace
	local samples: { TruthSample } = {}
	local teleports: { [number]: boolean } = {}
	local respawns: { [number]: boolean } = {}
	local last: TruthSample? = nil
	for _, step in plan do
		if step == "P" then
			local offset = if last ~= nil then last.position - base.samples[1].position else Vector3.zero
			local start = #samples
			for i, s in base.samples do
				samples[start + i] = {
					tMs = 0,
					position = s.position + offset,
					velocity = s.velocity,
					yaw = s.yaw,
					state = s.state,
					grounded = s.grounded,
					floorY = s.floorY + offset.Y,
				}
			end
			for frame in base.teleportFrames do
				teleports[start + frame] = true
			end
			for frame in base.respawnFrames do
				respawns[start + frame] = true
			end
			last = samples[#samples]
		elseif typeof(step) == "number" then
			local at = last or base.samples[1]
			for _ = 1, math.floor(step * 60) do
				table.insert(samples, {
					tMs = 0,
					position = at.position,
					velocity = Vector3.zero,
					yaw = at.yaw,
					state = Enum.HumanoidStateType.Running.Value,
					grounded = true,
					floorY = at.floorY,
				})
			end
			last = samples[#samples]
		end
	end
	for i, s in samples do
		s.tMs = (i - 1) * DT * 1000
	end
	return { samples = samples, teleportFrames = teleports, respawnFrames = respawns, name = "idle mix" }
end
```

In `src/ServerScriptService/Modules/SpecRoots.luau`, add to `EXEMPT_MODULES` (keep the table's existing ordering style):

```luau
	["ReplicatedStorage.Shared.Modules.CharacterReplication.Harness.HarnessNetwork"] = "replication harness; exercised end to end by HarnessVenture.spec",
	["ReplicatedStorage.Shared.Modules.CharacterReplication.Harness.HarnessTrace"] = "replication harness; exercised end to end by HarnessVenture.spec",
	["ReplicatedStorage.Shared.Modules.CharacterReplication.Harness.HarnessRunner"] = "replication harness; exercised end to end by HarnessVenture.spec",
```

- [ ] **Step 2: Write the failing acceptance spec**

Create `Harness/HarnessVenture.spec.luau`. Thresholds are the v3 results from the A/B (seeds 1–8, mean over seeds: studio 0.043, good 0.026, spec 0.033, mobile 0.093; worst single run 2.85 studs; uplink 868 B/s parkour, 559 B/s idle mix) with headroom:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Harness = ReplicatedStorage.Shared.Modules.CharacterReplication.Harness
local HarnessRunner = require(Harness.HarnessRunner)
local HarnessTrace = require(Harness.HarnessTrace)
local HarnessNetwork = require(Harness.HarnessNetwork)
local HarnessVenture = require(Harness.HarnessVenture)

local SEEDS = { 1, 2, 3, 4 }
local MEAN_LIMIT = { studio = 0.07, good = 0.06, spec = 0.07, mobile = 0.16 }

local function runOnce(trace, profileName, seed, options, venture)
	local system, probe = HarnessVenture.new(venture or {
		groundBelow = function(position)
			return HarnessTrace.groundBelow(trace, position)
		end,
		uplinkOnChange = true,
	})
	return HarnessRunner.run(system, trace, HarnessNetwork.PROFILES[profileName], seed, 50, options), probe
end

return function()
	local parkour = HarnessTrace.parkour(Vector3.new(0, 100, 0))

	for _, profileName in { "studio", "good", "spec", "mobile" } do
		describe(`parkour over the {profileName} network`, function()
			local results = {}
			beforeAll(function()
				for _, seed in SEEDS do
					table.insert(results, runOnce(parkour, profileName, seed))
				end
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
					expect(r.upBytesPerSecond < 950).to.equal(true)
					expect(r.downBytesPerSecond < 1400).to.equal(true)
					expect(r.retransmits).to.equal(0)
				end
			end)
		end)
	end

	describe("a session with idle time", function()
		it("cuts the uplink when the player stands still", function()
			local trace = HarnessTrace.withIdle(parkour, { 5, "P", 10, "P", 6 })
			local r = runOnce(trace, "good", 1)
			expect(r.upBytesPerSecond < 650).to.equal(true)
			expect(r.fidelity.max < 5).to.equal(true)
		end)
	end)

	describe("a local stall (window in the background)", function()
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

- [ ] **Step 3: Run the tests and verify they fail**

Studio test run. Expected: `HarnessVenture` cannot be required.

- [ ] **Step 4: Write the adapter**

Create `Harness/HarnessVenture.luau`:

```luau
--!strict
--[=[
	The harness adapter for the design R2 ships, wired to the REAL shared modules (codec, interpolator, render
	clock, send policy), so the acceptance spec measures exactly the production logic.

	  uplink    u8 packet id + one 16 B record, unreliable; the record's `ageMs` carries the owner's timestamp
	            (low 10 bits). With `uplinkOnChange`, the owner runs `SendPolicy` too.
	  server    unwraps the owner time, keeps the newest sample, relays by `SendPolicy`.
	  downlink  u8 id + 7 B header + one 16 B record, unreliable, sequence-numbered.
	  viewer    `CharacterInterpolator` on the owner's timeline, `RenderClock` delay, dead reckoning when the
	            buffer runs out.

	@class HarnessVenture
]=]

local Codec = require(script.Parent.Parent.CharacterRecordCodec)
local Interp = require(script.Parent.Parent.CharacterInterpolator)
local RenderClock = require(script.Parent.Parent.RenderClock)
local SendPolicy = require(script.Parent.Parent.SendPolicy)
local HarnessRunner = require(script.Parent.HarnessRunner)

local HarnessVenture = {}

local PACKET_ID = 2
local MAX_RECKON_MS = 60

export type Options = {
	groundBelow: ((position: Vector3) -> number)?,
	uplinkOnChange: boolean?,
}

export type Probe = {
	delayLog: { { atMs: number, delayMs: number } },
}

type Latest = { record: Codec.Record, sampleMs: number, fresh: boolean }

function HarnessVenture.new(options: Options?): (HarnessRunner.System, Probe)
	local opts: Options = options or {}
	local groundBelow = opts.groundBelow
	local uplinkOnChange = opts.uplinkOnChange == true
	local probe: Probe = { delayLog = {} }

	-- owner
	local epoch = 0
	local ownerPolicy = SendPolicy.new()
	local ownerLastSent: Codec.Record? = nil

	-- server
	local latest: Latest? = nil
	local lastSeenSampleMs = -math.huge
	local serverPolicy = SendPolicy.new()
	local serverLastSent: Codec.Record? = nil
	local batchSeq = 0

	-- viewer
	local samples = Interp.newBuffer()
	local clock = RenderClock.new()
	local starving = false

	local system: HarnessRunner.System = {
		name = "Venture (R1 modules)",

		ownerFrame = function(nowMs, truth, respawned)
			if respawned then
				epoch = (epoch + 1) % 8
			end
			local record: Codec.Record = {
				slot = 0,
				generation = 0,
				epoch = epoch,
				ageMs = math.floor(nowMs) % 1024,
				position = truth.position,
				yaw = truth.yaw,
				pitch = 0,
				velocity = truth.velocity,
				state = truth.state,
				grounded = truth.grounded,
				hasAction = false,
				rotation = nil,
			}
			if uplinkOnChange then
				local decision = SendPolicy.decide(ownerPolicy, nowMs, SendPolicy.changed(ownerLastSent, record))
				if decision == nil then
					return {}
				end
				ownerLastSent = record
			end
			local packet = buffer.create(1 + Codec.RECORD_BYTES)
			buffer.writeu8(packet, 0, PACKET_ID)
			Codec.writeRecord(packet, 1, record)
			return { { payload = packet, reliable = false } }
		end,

		serverReceive = function(nowMs, payload)
			local record = Codec.readRecord(payload, 1)
			local sampleMs = Codec.unwrapOwnerTime(math.floor(nowMs), record.ageMs)
			if sampleMs > lastSeenSampleMs then
				lastSeenSampleMs = sampleMs
				latest = { record = record, sampleMs = sampleMs, fresh = true }
			end
		end,

		serverFrame = function(nowMs, _distance)
			local current = latest
			if current == nil then
				return {}
			end
			local changed = current.fresh and SendPolicy.changed(serverLastSent, current.record)
			current.fresh = false
			if SendPolicy.decide(serverPolicy, nowMs, changed) == nil then
				return {}
			end
			serverLastSent = current.record
			batchSeq = (batchSeq + 1) % 65536
			local batch = buffer.create(1 + Codec.HEADER_BYTES + Codec.RECORD_BYTES)
			buffer.writeu8(batch, 0, PACKET_ID)
			Codec.writeHeader(batch, 1, { seq = batchSeq, batchTimeMs = math.floor(nowMs), count = 1 })
			local r = current.record
			Codec.writeRecord(batch, 1 + Codec.HEADER_BYTES, {
				slot = 1,
				generation = 0,
				epoch = r.epoch,
				ageMs = math.clamp(math.floor(nowMs) - current.sampleMs, 0, 1023),
				position = r.position,
				yaw = r.yaw,
				pitch = r.pitch,
				velocity = r.velocity,
				state = r.state,
				grounded = r.grounded,
				hasAction = false,
				rotation = nil,
			})
			return { { payload = batch, reliable = false } }
		end,

		viewerReceive = function(nowMs, payload)
			local header = Codec.readHeader(payload, 1)
			local record = Codec.readRecord(payload, 1 + Codec.HEADER_BYTES)
			local sampleTime = header.batchTimeMs - record.ageMs
			local newest = Interp.newestTimeMs(samples)
			local isNew = newest == nil or record.epoch ~= samples.epoch or sampleTime > newest
			RenderClock.onBatch(clock, nowMs, header.seq, nowMs - sampleTime, isNew)
			Interp.push(samples, record.epoch, {
				timeMs = sampleTime,
				position = record.position,
				velocity = record.velocity,
				yaw = record.yaw,
				state = record.state,
				grounded = record.grounded,
				rotation = nil,
			})
		end,

		viewerRender = function(nowMs)
			RenderClock.noteFrame(clock, nowMs)
			local delay = RenderClock.advance(clock, nowMs, starving, Interp.reachMs(samples, nowMs))
			table.insert(probe.delayLog, { atMs = nowMs, delayMs = delay })
			local renderTime = nowMs - delay
			local e = Interp.evaluate(samples, renderTime)
			if e.mode == "empty" then
				return nil
			end
			starving = e.mode == "hold" or e.mode == "behind"
			if e.mode == "extrapolate" or e.mode == "hold" then
				return Interp.reckon(samples, renderTime, MAX_RECKON_MS, groundBelow)
			end
			return e.position
		end,
	}
	return system, probe
end

return HarnessVenture
```

- [ ] **Step 5: Run the tests and verify they pass**

Studio test run: every `HarnessVenture` test passes and the whole suite is green (the harness runs take ~20 s in total). If a threshold fails, read the failing run's numbers before touching anything: a threshold is only relaxed with the developer's agreement and a line in the spec's appendix saying why; a behaviour regression is fixed in the module that caused it. Format, Lint, Typecheck clean.

- [ ] **Step 6: Commit**

```bash
git add src/ReplicatedStorage/Shared/Modules/CharacterReplication/Harness src/ServerScriptService/Modules/SpecRoots.luau
git commit -m "test(replication): harness and acceptance spec on the real modules

The spike's harness (trace, lossy link, runner), plus an idle-session trace and a local-stall option,
driving the production codec, interpolator, render clock and send policy. The acceptance spec pins
the v3 results on four networks, the idle uplink saving and the tab-out stall."
```

---

### Task 6: Roadmap entry

**Files:**
- Modify: `docs/ROADMAP.md`

- [ ] **Step 1: Add the replication track**

In `docs/ROADMAP.md`, in the "Presentation & infrastructure track" section (before the Movement / Traversal entry), add:

```markdown
- **Character replication** — custom replication with client-only bodies, decided by a spike
  (`docs/superpowers/specs/2026-09-22-character-replication-design.md`, Verdict 2026-09-30). Phases R1–R7:
  R1 core library (codec, interpolator, render clock, send policy, harness as acceptance spec) — plan
  `docs/superpowers/plans/2026-09-30-character-replication-r1-core-library.md`; R2 bodies on screen; R3 animation
  and actions; R4 appearance; R5 player collision; R6 anti-cheat; R7 lag compensation (with the combat core).
  Movement / Traversal builds on R2; Ragdoll (its own system) uses the record's ragdoll variant.
```

- [ ] **Step 2: Commit**

```bash
git add docs/ROADMAP.md
git commit -m "docs(roadmap): character replication track"
```

---

## After R1

Open a PR from `feature/character-replication` into `main` titled `Character replication R1: core library`. The developer runs the Studio suite and reviews before merge (AGENTS.md: runtime changes wait for the developer's verification; this phase has no runtime change, but the suite is Studio-only). Then write the R2 plan against what landed.
