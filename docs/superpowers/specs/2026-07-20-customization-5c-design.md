# Design — Customization 5c: asset pipeline, mounting, and fit

**Status:** draft · **Date:** 2026-07-20 · **Phase:** 5c of 3 (follows 5b, PR #11 — the final
customization phase)

## Purpose

Close out customization by fixing the layer 5a and 5b deliberately deferred: how cosmetic art is
FOUND, how it is ATTACHED, and how well it FITS. 5b proved the data model and the application seam;
what it could not do was mount reliably, diagnose missing art, or place a cosmetic precisely.

Scope: asset layout + explicit lookup, a boot-time conformance checker, an owned mounting mechanism,
shoes, per-cosmetic offsets with live tuning, and the two rig-independent carry-overs recorded in the
5b spec (retired-cosmetic validator leniency, `--!strict` on the CmdrTypes).

## Grounding (read-only live inspection, 2026-07-20)

Verified against `VentureTestingPlace` before designing, the same discipline as 5a and 5b:

- **Socket depth genuinely varies**, confirming the measurement 5b recorded as UNPROVEN. Relative to
  the rig: `Head` / `Helm` / `Mouth` / `Eyebrows` / `Chest` / `Pauldrons` / `Greaves` sit on direct part
  children (**depth 1**); `Hair` on `Head.Color 1`, `ShoeLeft` / `ShoeRight` on `Skin Color`, and the
  limb sockets on `Color 1` / `Color 2` (**depth 2**); `Eyes` on `Head.Eyes 1.Eye Color` and every
  backpack/weapon socket on `Backpack Color 1` / `Backpack Color 2` (**depth 3**).
- **`ReplicatedStorage.Customs` is structurally inconsistent.** Accessories sit at the ROOT
  (`FishingHat`, `WizardHat`, `Blindfold 1`, `Tabard`, …) alongside category folders (`Hair` 11,
  `Eyebrows` 4, `Eyelashes` 3, `Shoes` 1, `Dyes` 6, `TexturesFolder` 12, the pattern folders). There is
  a folder literally named **`Folder`** holding 19 accessories, and a dead **`TabardBackup`**.
- **`Customs` carries a `PackageLink`** — it is a Roblox Package owned by Venture and used by the
  developers working on the LIVE base game, not only by this refactor.
- **`RigidConstraint` is available**, with `Attachment0` / `Attachment1` / `Enabled` (probed with an
  unparented instance; the place was not modified).
- **⚠ The rigs DID diverge, and nothing noticed.** At first inspection `VentureTestingPlace` still had
  `Head.Skin ColorCovered` while the working place had the renamed `Skin Color-Covered` that 5b's skin
  body-channel depends on. The developer reconciled it the same day (both now carry the hyphenated
  name), so it is no longer live — but it went undetected until a human happened to look, and the
  failure mode it would have produced is silent: the skin channel simply stops colouring the head. It
  stands as the motivating example for Decision 3, and the risk recurs every time art moves between
  places.

**Standing constraint:** the rig is slated for a **big redo** (moving to controllers), months out.
Every decision below is therefore judged on whether it survives that redo, not only on whether it works
against today's rig.

## Decision 1 — own the mount: name-based socket lookup + `RigidConstraint`

Replace `Humanoid:AddAccessory` with an explicit mount: find the rig Attachment whose NAME matches the
descriptor's socket (searching the whole character, at any depth), then bind the cosmetic Handle's
Attachment to it with a `RigidConstraint`.

**This is what makes the phase rig-redo-proof.** `AddAccessory` performs its own attachment search, and
that search is the entire source of the depth sensitivity 5b could not resolve. Owning the mount
collapses every socket to identical code: `Hair` (depth 2), `Eyes` (depth 3) and `ShoeLeft` (depth 2)
stop being special cases. A structural rig change then costs nothing; only a socket RENAME breaks a
binding, and Decision 3 detects exactly that.

It also unlocks the two things 5b could not express: a per-cosmetic offset is just the constraint's
attachment CFrame (Decision 5), and a multi-socket cosmetic is just more than one constraint
(Decision 4).

- **Rejected: keep `AddAccessory`.** Its matching rules are engine-internal, so the depth question can
  only ever be answered empirically and re-answered after the rig redo. Building on an opaque search we
  have already been burned by, when the explicit alternative is ~40 lines, is the wrong trade.
- **Rejected: add sibling Attachments to `Head` so the native path works.** An art change that fixes
  only the depth-2 head sockets, leaves `Eyes` at depth 3 unsolved, and would have to be redone by hand
  on the new rig.

Cosmetics stay `Accessory` instances tagged as ours, so 5b's `clearApplied` idempotency is unchanged.

## Decision 2 — purpose-grouped folders and EXPLICIT lookup; unlink the package

Every catalog entry declares the folder its art lives in, and lookup is a direct child read of that
folder — no `FindFirstChild(id, true)` recursion, and no fallback to the `Customs` root.

The recursive lookup shipped in 5a is what lets today's inconsistent layout work at all, and it is
actively dangerous: 5b already had to remove one root-fallback because clothing channels deliberately
share ids across folders (`clothing1` and `clothing2` both contain `Skin2`), so a root-wide search
returns whichever duplicate it reaches first. Explicit lookup makes "which art is this?" answerable by
reading the registry instead of by guessing at tree order.

**The package link is broken in OUR place.** `Customs` is shared with the base-game developers;
restructuring a live package would land in their working tree, and a later package re-sync could
silently revert the reorg. Unlinking makes our copy independently owned.

**The honest cost:** art they add no longer flows to us automatically, so syncing becomes a manual step
the developer owns. That is precisely why Decision 3 lands in the same phase — the checker is what
converts a missed sync from a silent invisible-hat bug into a boot-time list.

## Decision 3 — a boot-time conformance checker that REPORTS, never crashes

A checker walks the catalog at server start and reports, per entry: art resolves in its declared
folder; it is an `Accessory`; it has a `Handle`; the Handle carries an Attachment named for its socket;
and the socket exists on the rig.

**It reports; it does not assert.** This deliberately breaks from the load-time `assert`s in
`CosmeticRegistry`, and the split is principled: the registry validates DATA THIS REPO OWNS, where a
contradiction is a programming error and should fail loud. The checker validates PLACE-OWNED ART that
artists edit outside our control — and a live server refusing to boot because one hat is missing is
strictly worse than a player briefly missing a hat. Same reasoning as the tolerant plan-builder.

The 5b evidence is direct: a missing `Customs` folder produced NO error — every command reported
success, the slice validated, the F4 panel updated, and nothing appeared. It cost a full debugging
round. It is also the only thing that would have caught the rig divergence found while grounding this
spec.

Surfaced two ways: a structured summary in the server log at boot, and an admin command for on-demand
re-checks after an art change, so the loop during the rig redo is one command rather than a restart.

## Decision 4 — shoes are just a multi-socket mount

`ShoeLeft` and `ShoeRight` both sit on `Skin Color` (depth 2). Deferred from 5b only because
two-socket welding on top of `AddAccessory` would have been bespoke work thrown away by this phase;
under Decision 1 a cosmetic's descriptor carries a LIST of sockets and each becomes its own constraint.
Content is still a single shoe option — a known gap, not a bug.

## Decision 5 — per-cosmetic offsets, tuned live, stored in the REGISTRY

Mount descriptors gain an optional offset applied to the constraint. A live-tuning admin command nudges
the offset on a spawned character and prints the resulting value to paste into the registry.

**Outcome (2026-07-20): the justification was a misdiagnosis, the mechanism shipped anyway.** 5b read
eyebrow/eyelash fit as wrong; it was actually missing geometry — 21 accessories had parts welded to
nothing, so they never followed their Handle. Welding the art fixed the fit with no offset at all.
The mechanism is kept because it is small and the coming rig redo is the likely first real customer,
but NO cosmetic declares an offset today, and an absent offset stays meaningfully different from zero.

**The registry stays the source of truth, and the command is a measuring instrument, not a writer.**
Code is version-controlled and reviewable; a value nudged into a place file is invisible to review and
lost at the next art sync. Tuning is interactive by nature, so the command exists to find the number —
committing it stays a normal code change.

## Carry-overs from 5b (recorded there, resolved here)

- **Retired cosmetics must not freeze the slice.** `validateAppearance` rejects unregistered ids and
  runs against the WHOLE resulting appearance on every write, so one retired id blocks every unrelated
  change until it is cleared — while the plan-builder deliberately skips retired ids so the character
  still renders. Align cosmetics with the affix precedent (PR #8): tolerate unregistered COSMETIC ids
  in `appearance`, since services pre-check on equip and clients never write, while `entitlements`
  stays strict (a retired id there is dead weight, not a rendering concern).
- **`--!strict` on all SEVEN `CmdrTypes`**, including the pre-5b `currencyType` / `itemType` / `statId`.
  The set moves together; the Cmdr-internal `registry` argument is untyped, so expect to type the
  boundary rather than suppress it.

## Testing (spec-first, the cases that matter)

- **Lookup**: an id resolves from its declared folder; the SAME id in a different folder resolves to
  different art (the `Skin2` collision, as a regression test); a missing folder resolves to nothing
  rather than falling back.
- **Conformance checker** (pure over an injected tree, like `CustomizationCompatibility`'s injectable
  lookup): reports a missing entry, a non-`Accessory`, a Handle with no socket Attachment, and a socket
  absent from the rig — and reports CLEAN on a well-formed fixture. Never throws.
- **Mounting**: the plan-to-constraint step is unit-testable where it is pure (socket resolution,
  offset composition); the Instance binding stays in the spec-exempt shell.
- **Multi-socket**: a two-socket descriptor emits two mounts.
- **Retired leniency**: an appearance holding a retired cosmetic still accepts an unrelated write (the
  regression this fixes), while `entitlements` still rejects one.

## Deliberately NOT in 5c

- **Re-tuning offsets for the NEW rig** — that is the rig redo's own work; this phase provides the
  mechanism and the checker that will tell you what moved.
- **Restructuring the `Customs` package in the base-game devs' place** — we unlink and own our copy;
  their tree is theirs.
- **The Soul Color gacha roll / spinner** → economy phase.
- **Customization UI** → the UI-framework phase.
