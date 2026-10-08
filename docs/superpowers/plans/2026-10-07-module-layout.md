# Module Layout Move Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move all 146 first-party modules into the agreed feature layout with role-word names, and make the layout rules self-enforcing through docs, AGENTS.md, a project skill and automated checks.

**Architecture:** Scripted and mechanical. A one-off Python mover reads the agreed map, rewrites every reference, then `git mv`s one feature per commit. Requires stay full addresses; a file that requires three or more modules from one feature folder names that folder once (spec §3 rule 7). While the move is under way, service discovery and `SpecRoots` look in both the old and the new roots, so every commit boots and passes `check.sh`. Once the tree is fully moved, the transitional code is removed and the layout checks are wired into `check_pr_rules.py`. Behaviour does not change. The spec's §6.3 has one fold and three extractions that the code-line cap forces.

**Tech Stack:** Luau `--!strict`, Rojo, TestEZ (Studio and Open Cloud), Python 3 standard library (`unittest`), ruff, selene, stylua, luau-lsp.

**Spec:** [docs/superpowers/specs/2026-10-07-module-layout-design.md](../specs/2026-10-07-module-layout-design.md)

**Execution method:** subagent-driven development (chosen by the developer, 2026-10-07). It runs on `feature/module-layout`, a branch based on R5's head (`feature/replication-chat-voice`, 330ba8c). It merges after R2–R5.

**Attachments** (tested before this plan was written: 47 unit tests pass. A full dry run over the R5 tree moved all 205 rows, then applied the fold and all three extractions: 0 layout errors, selene clean, and every file within 400 code lines): `docs/superpowers/plans/2026-10-07-module-layout/`
- `moves.json`: the 205 move rows (`group`, `from`, `to`), generated from the spec's §8 map plus the UI and command renames, and the spec-only replication load test.
- `move_layout.py` + `test_move_layout.py`: the one-off mover.
- `layout_rules.py` + `test_layout_rules.py`: the permanent layout checks (spec §5.4).
- `module_map.py` + `test_module_map.py`: the permanent generator and checker for the module map in `docs/project-structure.md` (spec §5.1).

## Global Constraints

- **Branch:** `feature/module-layout`, based on R5's head (`feature/replication-chat-voice` at 330ba8c). R5 is done (developer, 2026-10-07). The layout merges after R2–R5 (#29 → #31 → #34 → #38). Once #38 is in main, this branch rebases onto main: R2–R5 arrive as merge commits, so only the layout commits replay.
- **A fix landing on R2–R5 meanwhile:** rebuild, don't rebase. Branch again from the new R5 head, then re-run the tasks; the mover and the extractions are scripted. Record the rebuild in the ledger.
- `--!strict` everywhere. No `any`. No new `::` casts.
- Commits: plain messages only. **No `Co-Authored-By:` or `Claude-Session:` trailers** (`check_pr_rules.py` fails the build on them).
- Never run `rojo`, `scripts/check.sh` or `git rebase` in a folder the developer is serving. Work in this plan's own worktree.
- Spec-first: a module without a `.spec` sibling must be in `SpecRoots.EXEMPT_MODULES` with a reason.
- The 400 code-line cap (`check_file_length.py`) applies; the cap is never raised to make a file pass.
- Approval-gated changes need the developer's explicit approval and are never decided by an agent: a new subfolder kind (3+ modules that share it **and** approval), a new role word, a second service in one feature and realm (spec §3, rules 2–4).
- No behaviour changes. Only the spec's §6.3 changes code shape: the art-check fold and three extractions.
- Requires (spec §3 rule 7): full addresses. A folder variable `<Feature><Realm>` only when a file requires **three or more** modules from that folder. Never for one long line. No relative requires, except a spec requiring its own module.
- `bash scripts/check.sh` is green after every commit.
- PR merge subject: `Merge PR #N: <short description>`, as a merge commit. Never merge until the developer verifies in Studio.

## Review Focus

1. **A require that resolves to the wrong module.** `luau-lsp` only checks non-spec files; spec requires are proven only by TestEZ. Each move task greps spec files for old paths (Step "spec sweep"). Task 11 runs the full TestEZ suite.
2. **A renamed service name left in a string.** `dependencies`, `getService` and `Logger.new` refer to services by name. A stale name means a service doesn't start, or starts in the wrong order. The mover renames quoted names. Each move task greps for the old service names. Task 11's play test looks for "skipped by discovery" and "unknown dependency" warnings.
3. **Stale instances in a served place.** `ReplicatedStorage` keeps unknown children, so an old `Shared/Modules` folder can survive a `rojo serve`. Task 11 checks the served tree by hand.
4. **English words renamed as module names.** Admin, Actions, General and Locomotion are single words. The mover renames them only where they are bound to the module, and reports them so the diff can be reviewed by hand.
5. **Command names typed by admins.** Every command's `Name` must be its file name in lower case (the check in Task 9 covers this). Task 11 runs three renamed commands live.

---

## Task 1: Install the tooling

**Files:**
- Create: `scripts/python/move_layout.py`, `scripts/python/test_move_layout.py`, `scripts/python/layout_rules.py`, `scripts/python/test_layout_rules.py`, `scripts/python/module_map.py`, `scripts/python/test_module_map.py`. Copy each from the attachments folder.
- Modify: `scripts/check.sh` (Python unit-test step), `.github/workflows/ci-cd.yml` (`scripts-lint` job: unit-test step)

**Interfaces:**
- Produces:
  - `python3 scripts/python/move_layout.py verify`: exits 0 when every module is mapped, moved or kept.
  - `python3 scripts/python/move_layout.py move <Group>...`: rewrites references, then moves the files.
  - `layout_rules.check_layout(paths: Iterable[str], read: Callable[[str], str]) -> list[str]`
  - `python3 scripts/python/module_map.py --check | --write`

- [ ] **Step 1: Branch.** Work in the `feature/module-layout` worktree (never a served one). It already sits on R5's head with the spec and plan commits. Confirm that:

```bash
git merge-base --is-ancestor feature/replication-chat-voice HEAD && echo "on R5"
```

- [ ] **Step 2: Copy the six files.**

```bash
cp docs/superpowers/plans/2026-10-07-module-layout/{move_layout,test_move_layout,layout_rules,test_layout_rules,module_map,test_module_map}.py scripts/python/
```

- [ ] **Step 3: Run the unit tests.**

Run: `python3 -m unittest discover -s scripts/python -p "test_*.py"`
Expected: `OK`, 47 tests.

- [ ] **Step 4: Check the map against the merged tree.**

Run: `python3 scripts/python/move_layout.py verify`
Expected: `0 unmapped, 0 stale rows`.

If a module merged after this plan was written is UNMAPPED, add a row to `moves.json` before going on:
- Place it with the spec's §2–4 rules: the feature whose job it does, the subfolder from the three-question test, and `<Feature><What><RoleWord>`.
- Record each added row in the ledger as a ruling.
- If no existing subfolder or role word fits, **stop and ask the developer.** That is an approval-gated change.

If a row is STALE (its module was deleted or renamed upstream), remove the row and record that too.

- [ ] **Step 5: Run the unit tests in check.sh.** In `scripts/check.sh`, insert this before `echo "==> Python scripts lint (ruff)"`:

```bash
echo "==> Python unit tests"
# The layout rules, the module-map generator and (while the move runs) the mover are tested like
# first-party code: a regex that silently stopped matching would let the layout drift.
python3 -m unittest discover -s scripts/python -p "test_*.py"

echo ""
```

- [ ] **Step 6: Run them in CI too.** In `.github/workflows/ci-cd.yml`, job `scripts-lint`, add this step after `- run: ruff check scripts/python`:

```yaml
      # The layout rules and the module-map generator are pure functions with unit tests; run them
      # before the gates that use them.
      - name: Python unit tests
        run: python3 -m unittest discover -s scripts/python -p "test_*.py"
```

- [ ] **Step 7: Gate and commit.**

Run: `bash scripts/check.sh`. Expected: `==> All checks passed.`

```bash
git add scripts/python scripts/check.sh .github/workflows/ci-cd.yml docs/superpowers/plans/2026-10-07-module-layout/moves.json
git commit -m "chore(layout): add the layout mover, rules and module-map tooling (#37)"
```

---

## Task 2: Let discovery and spec roots see both trees

During the move, services and specs live under both the old roots and the new ones. This task lets every commit boot and test, whatever has moved so far. Task 9 removes it.

**Files:**
- Modify: `src/ServerScriptService/ServerHandler.server.luau:9-36`
- Modify: `src/StarterPlayer/StarterPlayerScripts/ClientHandler.client.luau:13-40`
- Modify: `src/ServerScriptService/Modules/SpecRoots.luau` (`SpecRoots.get`)
- Test: `src/ServerScriptService/Modules/SpecRoots.spec.luau` (`describe("SpecRoots.get")`)
- Modify: `scripts/python/check_pr_rules.py` (asset-id allowed places, UI lifecycle tree)

**Interfaces:**
- Produces: `SpecRoots.get(): { Instance }`, which returns every existing root among the old and new names. Task 9 restores the fixed list of seven.

- [ ] **Step 1: Write the failing spec.** Replace the `SpecRoots.get` describe block with:

```lua
	describe("SpecRoots.get", function()
		it("returns only live roots, always including the client tree and the commands", function()
			local roots = SpecRoots.get()
			local names = {}
			for _, root in roots do
				expect(typeof(root)).to.equal("Instance")
				names[root:GetFullName()] = true
			end
			expect(names["ReplicatedStorage.Client"]).to.equal(true)
			expect(names["ServerScriptService.Commands"]).to.equal(true)
		end)

		it("lists each root once", function()
			local seen = {}
			for _, root in SpecRoots.get() do
				expect(seen[root]).to.equal(nil)
				seen[root] = true
			end
		end)
	end)
```

This only runs in TestEZ, so it is proven in Task 11. There is no headless runner.

- [ ] **Step 2: Implement.** Replace `SpecRoots.get` with:

```lua
-- Appends each named child of `parent` that exists. Transitional (issue #37): while the layout move
-- runs, specs live under both the old folders and the new ones, and a root that has not been
-- created yet is skipped. The move plan's Task 9 restores a fixed list.
local function appendExisting(roots: { Instance }, parent: Instance, names: { string })
	for _, name in names do
		local child = parent:FindFirstChild(name)
		if child then
			table.insert(roots, child)
		end
	end
end

--[=[
	The roots TestEZ scans.
	@return { Instance }
]=]
function SpecRoots.get(): { Instance }
	local roots: { Instance } = {}
	appendExisting(roots, ReplicatedStorage.Shared, { "Core", "Data", "Features", "Modules", "State" })
	table.insert(roots, ReplicatedStorage.Client)
	appendExisting(roots, ServerScriptService, { "Commands", "Core", "Features", "Modules", "Services", "State" })
	return roots
end
```

- [ ] **Step 3: Discover services in both trees.** In `ServerHandler.server.luau`, replace the line `local Services = ServerScriptService.Services` and its `for` loop header with a loop over both roots. Keep the loop body exactly as it is:

```lua
-- Register all server services. Transitional (issue #37): during the layout move services live under
-- both `Services` and `Features`; the move plan's Task 9 walks `Features` only.
for _, rootName in { "Features", "Services" } do
	local root = ServerScriptService:FindFirstChild(rootName)
	if not root then
		continue
	end
	for _, ServerService in root:GetDescendants() do
		-- (unchanged body: the `*ServiceServer` match, register, and the near-miss warning)
	end
end
```

Make the same change in `ClientHandler.client.luau`, with `ReplicatedStorage.Client` as the parent, the same two names, and its own unchanged body.

- [ ] **Step 4: Let the PR rules accept the new homes.** In `scripts/python/check_pr_rules.py`:

```python
# Feature registries: every `Features/<Feature>/Data/` folder is registry land (issue #37 layout).
ASSET_ID_FEATURE_DATA = re.compile(r"^src/(?:ReplicatedStorage/(?:Shared|Client)|ServerScriptService)/Features/[^/]+/Data/")
```

In `asset_id_scatter`, change the skip test to:

```python
        if not path.endswith(".luau") or path.startswith(ASSET_ID_ALLOWED_PREFIXES) or ASSET_ID_FEATURE_DATA.match(path):
```

Change `UI_LIFECYCLE_TREE` to a tuple, and update its one use in `imperative_visibility` from `(UI_TREE, UI_LIFECYCLE_TREE)` to `(UI_TREE, *UI_LIFECYCLE_TREE)`:

```python
UI_LIFECYCLE_TREE = ("src/ReplicatedStorage/Client/Services/", "src/ReplicatedStorage/Client/Features/")
```

- [ ] **Step 5: Gate and commit.** Run `stylua src`, then `bash scripts/check.sh`. Expected: all checks pass.

```bash
git add src scripts/python/check_pr_rules.py
git commit -m "refactor(layout): discover services and specs in old and new roots during the move (#37)"
```

---

## The move loop (Tasks 3–8)

Each move task runs this loop once per group, in the order given, **one commit per group**:

1. **Move:** `python3 scripts/python/move_layout.py move <Group>`
2. **Read the report:**
   - `BY HAND`: a requirer declares its own `type <Old>`. Rename its local by hand to the module's new name, and keep the type alias's meaning.
   - `REVIEW`: a single-word rename (Admin, Actions, General, Locomotion). Read `git diff` for that word, and put back any place where it was English or a data key rather than the module.
   - `LEFTOVER`: an old module name still in the text. Decide each one. If it refers to the module (usually a comment or a doc path written relative to `Shared/`), rename it. If it is a different thing with the same name (a ByteNet packet such as `DepositCurrency`, a type such as `PlayerDataTypes.ProfilePath`, a UI label), leave it.
3. **Exempt new Events modules.** If the group has a `Net/<Feature>Events` module with no spec, it now sits under a spec root. Add it to `SpecRoots.EXEMPT_MODULES` with the reason `"ByteNet packet definitions (no logic)"`, keyed by its new full name.
4. **Spec sweep:** `git grep -nE "Shared\.Modules|Shared\.State|Shared\.Events|Shared\.Types|Client\.Modules|Client\.State|Client\.Services|ServerScriptService\.(Modules|Services|State)" -- '*.spec.luau'`. Nothing may name a module of this group by its old path.
5. **Format and gate:** `stylua src`, then `bash scripts/check.sh`. The mover adds folder variables where rule 7 calls for them. The three files that go over the cap are handled by the extractions in Tasks 6 and 8. Never raise the cap.
6. **Map check:** `python3 scripts/python/move_layout.py verify` still reports `0 unmapped, 0 stale rows`.
7. **Commit:** `git add -A src tasks docs scripts` then `git commit -m "refactor(layout): move <Group> into the feature layout (#37)"`.

---

## Task 3: Core and Data

**Files:** the 7 Core rows and 2 Data rows in `moves.json`. Also every requirer of Logger, Guard, SignalTyped, ServiceController, RequestHandler, SpecRoots, ProfileStoreTyped, PlayerDataTypes and PublicPlayerTypes (about 100 files). Also `tasks/runTests.luau`, `TestRunner.server.luau`, and both handlers.

- [ ] **Step 1:** Run the move loop for `Core`.
  - Expected report: no BY HAND, no REVIEW.
  - `SpecRoots` moves to `ServerScriptService/Core/Testing/SpecRoots`.
  - `tasks/runTests.luau` and `TestRunner.server.luau` now require it from there.
- [ ] **Step 2:** Run the move loop for `Data`.
  - In step 3 of the loop, add exemptions for the two type modules, which now sit under the `Shared.Data` root: `["ReplicatedStorage.Shared.Data.PlayerDataTypes"] = "type definitions only (no runtime logic)"` and the same reason for `PublicPlayerTypes`.

---

## Task 4: Leaf features

**Files:** all `moves.json` rows in groups Admin, Bank, Currency, Debugger, Equipment, Inventory, Item, Slot, Stat, Title, Voice and UI, plus their requirers.

- [ ] **Step 1:** Run the move loop for each group, in this order, one commit each: `Admin`, `Bank`, `Currency`, `Debugger`, `Equipment`, `Inventory`, `Item`, `Slot`, `Stat`, `Title`, `Voice`, `UI`.
- [ ] **Step 2: Notes from the dry run.**
  - **Admin:** REVIEW `Admin`. Strings like `"Admin"` (the typo test for `"Admins"` in `AdminServiceServer.spec`) must stay as they are.
  - **Bank, Debugger, Equipment, Title:** each gains an Events exemption (loop step 3).
  - **Equipment:** LEFTOVER lines naming `EquipItem` / `UnequipItem` are ByteNet packets. Leave them.
  - **Item:** `GameItems` becomes `ItemContentRegistry` and keeps its `init()`. Both handlers and `tasks/runTests.luau` call it, and the mover rewrites those requires.
  - **Stat, Title:** the services are renamed (`StatServiceServer`, `TitleServiceServer` and their clients). Grep for the old names in quotes. The result must be empty:

    ```bash
    git grep -nE '"(StatsService|TitlesService)(Server|Client)"'
    ```

  - **Title:** REVIEW `General`. A `"General"` category key in title data is data. Leave it.
  - **UI:** `UIAssets` moves from Shared to the Client realm (`Client/Features/UI/Data/UIAssets`). If `luau-lsp` reports a server or shared requirer, stop and ask the developer: that would change a decided realm.

---

## Task 5: Animation

**Files:** the 12 Animation rows and their requirers.

- [ ] **Step 1:** Run the move loop for `Animation`.
- [ ] **Step 2: Notes.**
  - REVIEW `Actions` and `Locomotion`. Animation docs and comments use both as English words. Keep those as words.
  - `AnimationPlayer`, `AnimationPlayerRuntime` and `LocomotionAnimator` carry own-named export types. These follow the rename (for example `AnimationPlayerSystem.AnimationPlayerSystem`).
  - Add the AnimationEvents exemption (loop step 3).

---

## Task 6: Customization, and the art-check fold

**Files:**
- The 19 Customization rows and their requirers.
- Modify: `src/ServerScriptService/Features/Customization/Systems/CustomizationArtCheckSystem.luau` (after the move)
- Test: `src/ServerScriptService/Features/Customization/Systems/CustomizationArtCheckSystem.spec.luau`
- Modify: `src/ServerScriptService/Features/Customization/CustomizationServiceServer.luau` (`start`)
- Modify: `src/ServerScriptService/Commands/CheckArtServer.luau` (renamed to `CustomizationCheckArtServer` in Task 8)
- Modify: `src/ServerScriptService/Modules/SpecRoots.luau` (`EXEMPT_MODULES`, if it names the old service)
- Create: `src/ServerScriptService/Features/Customization/Rules/CustomizationEntitlementRules.luau` and its `.spec.luau` (Step 5, extraction 3)

**Interfaces:**
- Produces:
  - `CustomizationArtCheckSystem.check(): CustomizationArtCheck.Summary`
  - `CustomizationArtCheckSystem.run(): ()`, which logs the report and never throws. `CustomizationServiceServer.start` calls it.

- [ ] **Step 1:** Run the move loop for `Customization`, but **don't commit yet**.
  - `CustomizationConformanceServiceServer` lands as `Systems/CustomizationArtCheckSystem`.
  - Because its name no longer ends in `ServiceServer`, discovery stops registering it. That is intended.
- [ ] **Step 2: Rewrite the spec first.** Replace `CustomizationArtCheckSystem.spec.luau` with:

```lua
--!strict
--[=[
	Unit tests for CustomizationArtCheckSystem: the boot-time wrapper around CustomizationArtCheck.

	The CHECKING logic is specced exhaustively in CustomizationArtCheck.spec against fabricated trees.
	What is worth pinning here is only what this wrapper adds: it looks up the real trees, hands back a
	well-formed Summary, and never throws, whatever state the place is in. A test place has no art at
	all, so "reports problems" is the expected result here, not a failure.
]=]

local CustomizationArtCheckSystem = require(script.Parent.CustomizationArtCheckSystem)

return function()
	describe("check", function()
		it("returns a well-formed summary without throwing", function()
			local summary = CustomizationArtCheckSystem.check()

			expect(type(summary.ok)).to.equal("boolean")
			expect(type(summary.total)).to.equal("number")
			expect(type(summary.lines)).to.equal("table")
			expect(summary.ok).to.equal(summary.total == 0)
			expect(#summary.lines).to.equal(summary.total)
		end)

		it("is repeatable: a re-check after an art edit must be a fresh read", function()
			local first = CustomizationArtCheckSystem.check()
			local second = CustomizationArtCheckSystem.check()
			expect(second.total).to.equal(first.total)
		end)
	end)

	describe("run", function()
		it("logs the report without throwing", function()
			expect(function()
				CustomizationArtCheckSystem.run()
			end).never.to.throw()
		end)
	end)

	describe("not a service", function()
		it("has no service lifecycle: CustomizationServiceServer starts it", function()
			local shape: any = CustomizationArtCheckSystem
			expect(shape.dependencies).to.equal(nil)
			expect(shape.start).to.equal(nil)
		end)
	end)
end
```

(Spec files are intentionally untyped, and `any` is allowed in specs. `check_pr_rules` exempts them.)

- [ ] **Step 3: Rewrite the module as a System.** Keep the doc block's reasoning but retitle it, keep `artRoot()` and `RIG_NAME` unchanged, and replace the service literal with:

```lua
local CustomizationArtCheckSystem = {}

--[=[
	Runs the check against the live art tree and the StarterCharacter rig.

	The rig is `StarterPlayer.StarterCharacter` rather than a spawned character: it is the template
	every character is cloned from, it exists before any player joins, and checking it at boot is the
	whole point. A socket that is missing there is missing for everyone.
	@return CustomizationArtCheck.Summary
]=]
function CustomizationArtCheckSystem.check(): CustomizationArtCheck.Summary
	local customs = artRoot()
	local rig = StarterPlayer:FindFirstChild(RIG_NAME)
	return CustomizationArtCheck.summarize(CustomizationArtCheck.check(customs, rig))
end

--[=[
	Logs the report. Warn-level per issue, so a broken art sync is visible in the output without
	anyone asking for it: that is the failure this exists to turn from silent into loud. Never throws.
	Art is place-owned, and a server must boot with a missing hat.
]=]
function CustomizationArtCheckSystem.run()
	local summary = CustomizationArtCheckSystem.check()
	if summary.ok then
		log:info("art conformance: all catalogued cosmetics resolve")
		return
	end
	log:warn(`art conformance: {summary.total} issue(s) — cosmetics below will NOT appear in game`)
	for _, line in summary.lines do
		log:warn(line)
	end
end

return CustomizationArtCheckSystem
```

Rewrite the doc block's first paragraph to say it is a System started by `CustomizationServiceServer`. Delete the "Deliberately its OWN service" reasons: rule 2 (one service per feature) replaces them. The 400-line pressure is addressed by keeping the call to a single line.

- [ ] **Step 4: Start it from the service.** `CustomizationServiceServer.luau` now requires three server Customization modules: the publisher, the art check, and Step 5's entitlement rules. Rule 7 therefore gives it a folder variable. Add it under the existing `CustomizationShared` line:

```lua
local CustomizationServer = ServerScriptService.Features.Customization
```

Then replace the (wrapped) `CustomizationPublishSystem` require with these three:

```lua
local CustomizationPublishSystem = require(CustomizationServer.Systems.CustomizationPublishSystem)
local CustomizationArtCheckSystem = require(CustomizationServer.Systems.CustomizationArtCheckSystem)
local CustomizationEntitlementRules = require(CustomizationServer.Rules.CustomizationEntitlementRules)
```

Then make this the first line of `start`:

```lua
		CustomizationArtCheckSystem.run()
```

- [ ] **Step 5: Extraction 3, the entitlement rules (spec §6.3).** The ownership gate answers "is this allowed?", which is a Rules job.

  Write the spec first, `src/ServerScriptService/Features/Customization/Rules/CustomizationEntitlementRules.spec.luau`:

```lua
--[=[
	Unit tests for CustomizationEntitlementRules: the ownership gate every equip path runs. Uses real
	registry ids: FishingHat is a free accessory, WizardHat a lockable one.
]=]

local CustomizationEntitlementRules = require(script.Parent.CustomizationEntitlementRules)

local OWNS_WIZARD_HAT = { cosmetics = { accessory = { WizardHat = true } } }
local OWNS_NOTHING = { cosmetics = {} }

return function()
	describe("isUnlocked", function()
		it("passes a FREE cosmetic with no entitlements at all, even without a profile", function()
			expect(CustomizationEntitlementRules.isUnlocked(nil, "account", "accessory", "FishingHat")).to.equal(true)
		end)

		it("refuses a LOCKABLE cosmetic the account does not own", function()
			local ok, reason = CustomizationEntitlementRules.isUnlocked(OWNS_NOTHING, "account", "accessory", "WizardHat")
			expect(ok).to.equal(false)
			expect(reason:find("locked")).to.be.ok()
		end)

		it("passes a LOCKABLE cosmetic the account owns", function()
			expect(CustomizationEntitlementRules.isUnlocked(OWNS_WIZARD_HAT, "account", "accessory", "WizardHat")).to.equal(
				true
			)
		end)

		it("refuses a lockable cosmetic when no profile is loaded", function()
			local ok, reason = CustomizationEntitlementRules.isUnlocked(nil, "account", "accessory", "WizardHat")
			expect(ok).to.equal(false)
			expect(reason).to.equal("no profile loaded")
		end)

		it("refuses loudly for a per-slot scope, which is not implemented", function()
			local ok, reason = CustomizationEntitlementRules.isUnlocked(OWNS_WIZARD_HAT, "slot", "accessory", "WizardHat")
			expect(ok).to.equal(false)
			expect(reason:find("not implemented")).to.be.ok()
		end)
	end)

	describe("canEquip", function()
		it("refuses an id that is not registered in its category", function()
			local ok, reason = CustomizationEntitlementRules.canEquip(OWNS_WIZARD_HAT, "account", "accessory", "NoSuchHat")
			expect(ok).to.equal(false)
			expect(reason:find("not a registered")).to.be.ok()
		end)

		it("defers to isUnlocked for a registered id", function()
			expect(CustomizationEntitlementRules.canEquip(OWNS_NOTHING, "account", "accessory", "FishingHat")).to.equal(true)
			expect((CustomizationEntitlementRules.canEquip(OWNS_NOTHING, "account", "accessory", "WizardHat"))).to.equal(false)
		end)
	end)
end
```

  Then the module, `src/ServerScriptService/Features/Customization/Rules/CustomizationEntitlementRules.luau`:

```lua
--!strict
--[=[
	CustomizationEntitlementRules: may this player wear this cosmetic?

	The ownership gate every equip path runs before it writes. Pure: the caller hands in the player's
	entitlements and the category's unlock scope, so the rule needs no profile and no service, and both
	slices meet here without either slice validator seeing the other (a per-slice validator only ever
	sees its own value). A FREE cosmetic always passes: only lockable ids are ever stored as
	entitlements. Moved out of CustomizationServiceServer (issue #37): "is it allowed?" is a Rules job.

	@class CustomizationEntitlementRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomizationCosmeticRegistry =
	require(ReplicatedStorage.Shared.Features.Customization.Data.CustomizationCosmeticRegistry)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

--[=[
	Where a cosmetic category's UNLOCKS live. Every category is account-wide today; the indirection is
	the extensibility seam the developer asked for (design spec, Decision 1a): flipping a category to
	"slot" later means adding a per-slot entitlement store and changing one row in the service's
	scope table, and this gate already routes through the scope.
	@type EntitlementScope "account" | "slot"
]=]
export type EntitlementScope = "account" | "slot"

local CustomizationEntitlementRules = {}

--[=[
	Whether `id` in `category` is unlocked for a player with `entitlements`.
	@param entitlements PlayerDataTypes.Entitlements? -- nil when no profile is loaded
	@param scope EntitlementScope -- where this category's unlocks live
	@param category string
	@param id string
	@return (boolean, string?) -- (ok, reason)
]=]
function CustomizationEntitlementRules.isUnlocked(
	entitlements: PlayerDataTypes.Entitlements?,
	scope: EntitlementScope,
	category: string,
	id: string
): (boolean, string?)
	if not CustomizationCosmeticRegistry.isLockable(category, id) then
		return true
	end
	if scope ~= "account" then
		-- Reached only once a category is deliberately flipped to per-slot; refusing loudly beats
		-- silently consulting the wrong store and handing out a cosmetic the player has not earned.
		return false, `entitlement scope "{scope}" for category "{category}" is not implemented yet`
	end
	if not entitlements then
		return false, "no profile loaded"
	end
	local owned = entitlements.cosmetics[category]
	if not owned or owned[id] ~= true then
		return false, `"{id}" is locked — unlock it before equipping`
	end
	return true
end

--[=[
	The pre-flight for every equip path: the id must be registered in its category AND unlocked.
	@param entitlements PlayerDataTypes.Entitlements?
	@param scope EntitlementScope
	@param category string
	@param id string
	@return (boolean, string?) -- (ok, reason)
]=]
function CustomizationEntitlementRules.canEquip(
	entitlements: PlayerDataTypes.Entitlements?,
	scope: EntitlementScope,
	category: string,
	id: string
): (boolean, string?)
	if not CustomizationCosmeticRegistry.isRegistered(category, id) then
		return false, `"{id}" is not a registered {category} cosmetic`
	end
	return CustomizationEntitlementRules.isUnlocked(entitlements, scope, category, id)
end

return CustomizationEntitlementRules
```

  Then edit `CustomizationServiceServer.luau`:
  - Replace the `EntitlementScope` doc block and its `export type` line with:

```lua
-- Where each category's unlocks live (CustomizationEntitlementRules.EntitlementScope).
type EntitlementScope = CustomizationEntitlementRules.EntitlementScope
```

  - Keep `ENTITLEMENT_SCOPE`, `scopeOf` and `_setEntitlementScopeForTesting` exactly as they are.
  - Replace both local functions `isUnlocked` and `canEquip`, with the comment above them, by:

```lua
-- The ownership gate (CustomizationEntitlementRules) with this player's entitlements and scope.
local function canEquip(userId: number, category: string, id: string): (boolean, string?)
	return CustomizationEntitlementRules.canEquip(entitlementsSlice.get(userId), scopeOf(category), category, id)
end
```

  The two `canEquip(userId, ...)` call sites are unchanged. The existing `CustomizationServiceServer.spec` cases for locked, free, unlocked and the per-slot scope pass unchanged: they prove the service still routes through the gate.

- [ ] **Step 5b: Point the command at it.** In `src/ServerScriptService/Commands/CheckArtServer.luau`, replace the `ConformanceService` require and its call:

```lua
local CustomizationArtCheckSystem =
	require(ServerScriptService.Features.Customization.Systems.CustomizationArtCheckSystem)
```

```lua
	local summary = CustomizationArtCheckSystem.check()
```

- [ ] **Step 6: Clean up the old service name.**
  - If `SpecRoots.EXEMPT_MODULES` or any doc names `CustomizationConformanceServiceServer`, update it. A System with a spec needs no exemption.
  - Then run `git grep -n "CustomizationConformanceServiceServer"`. Expected: no matches outside `docs/superpowers/`.
- [ ] **Step 7:** Finish the loop (steps 4–7).
  - `check_file_length` must show `CustomizationServiceServer` at about 380 code lines (dry run, with the fold and extraction 3).
  - Commit message: `refactor(layout): move Customization into the feature layout; art check becomes a System (#37)`.

---

## Task 7: PlayerData and StateSync

**Files:** the 5 PlayerData rows and 7 StateSync rows, plus their requirers (most of the server).

- [ ] **Step 1:** Run the move loop for `PlayerData`.
  - `SliceOwner`, `ProfilePath` and `PlayerDataMigrations` are renamed.
  - LEFTOVER `PlayerDataTypes.ProfilePath` is a type. Leave it.
  - `check_file_length.py`'s `ALLOWLIST` key for `PlayerDataServiceServer` is rewritten by the mover (a slash path). Confirm that it now names `src/ServerScriptService/Features/PlayerData/PlayerDataServiceServer.luau`.
- [ ] **Step 2:** Run the move loop for `StateSync`.
  - `ClientStore`, `ServerStore`, `PublicPlayerState`, `SliceManifest` and `SyncState` are renamed.
  - The `Shared.State`, `Client.State` and `ServerScriptService.State` folders empty out. Git drops empty folders.

---

## Task 8: Replication, UI tree and commands

**Files:** the 40 Replication rows (plus the load-test row), 3 UITree rows and 59 Commands rows, plus their requirers. Also `CustomizationOutfitSystem.luau` and its spec (Step 1b), and the new `Replication/Net/ReplicationSlotSender` with its spec (Step 1c).

- [ ] **Step 1:** Run the move loop for `Replication`.
  - This is the largest group. It has folder aliases (`local Replication = ReplicatedStorage.Shared.Modules.CharacterReplication`, `local Folder = ServerScriptService.Services.CharacterReplicationService`). The mover inlines them and drops each alias once it is unused.
  - Add the ReplicationEvents exemption (loop step 3).
  - `ReplicationLoad.spec` (the 60-player load test, a spec with no module of its own) moves to `Features/Replication/Testing/ReplicationLoadHarness.spec`.
  - Then check that the result is empty:

    ```bash
    git grep -nE '"CharacterReplicationService(Server|Client)"'
    ```

- [ ] **Step 1b: The one extraction (spec §6.3), before Step 1's gate and commit.**

  In the dry run, `ReplicationServiceClient` lands at 402 code lines: the four cross-feature Customization requires wrap. Building the piece folder, the pool and the outfit system is Customization's job, so it moves there. Behaviour is unchanged: creation and teardown happen in the same order.

  First write the failing spec. Append this `describe` block inside the returned function of `src/ReplicatedStorage/Client/Features/Customization/Systems/CustomizationOutfitSystem.spec.luau`:

```lua
	describe("mount", function()
		it("creates the CosmeticPieces folder and a live system, and the teardown removes the folder", function()
			local Workspace = game:GetService("Workspace")
			local state, unmount = CustomizationOutfitSystem.mount()
			local folder = Workspace:FindFirstChild("CosmeticPieces")
			expect(folder).to.be.ok()
			expect(state.pieces).to.be.ok()
			expect(state.owner).to.equal(nil)
			unmount()
			expect(folder.Parent).to.equal(nil)
		end)

		it("leaves no subscriptions behind after the teardown", function()
			local state, unmount = CustomizationOutfitSystem.mount()
			unmount()
			expect(#state.cleanups).to.equal(0)
		end)
	end)
```

  Then add the function to `CustomizationOutfitSystem.luau`, before `return CustomizationOutfitSystem`. The module also needs `local Workspace = game:GetService("Workspace")` next to its `ReplicatedStorage` line, and `local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)` among its requires.

```lua
-- Where the shared cosmetic pieces live while they are on a rig or pooled.
local PIECE_FOLDER_NAME = "CosmeticPieces"

--[=[
	Mounts the game's outfit system: the `CosmeticPieces` folder in Workspace, its piece pool, and a
	system that dresses from this client's synced atoms. Returns the system and the one call that tears
	all three down, in reverse order. The replication client decides WHEN; WHAT gets built is
	Customization's job.
	@return (State, () -> ())
]=]
function CustomizationOutfitSystem.mount(): (State, () -> ())
	local folder = Instance.new("Folder")
	folder.Name = PIECE_FOLDER_NAME
	folder.Parent = Workspace
	local pieces = CustomizationPiecePool.new(folder)
	local state = CustomizationOutfitSystem.new({
		ownAppearance = StateSyncClientStore.appearance,
		publicPlayers = StateSyncClientStore.publicPlayers,
		pieces = pieces,
	})
	return state, function()
		CustomizationOutfitSystem.destroy(state)
		CustomizationPiecePool.destroy(pieces)
		folder:Destroy()
	end
end
```

  Then edit `src/ReplicatedStorage/Client/Features/Replication/ReplicationServiceClient.luau`:
  - Delete the `CustomizationPiecePool` require, the `PIECE_FOLDER_NAME` constant, and the `StateSyncClientStore` require. Its only use was the outfit deps; selene flags it if that is no longer true.
  - In `init`, replace the nine lines from `local pieceFolder = Instance.new("Folder")` through the closing `})` of `CustomizationOutfitSystem.new` with:

```lua
		local dressing, unmountDressing = CustomizationOutfitSystem.mount()
		outfits = dressing
```

  - In the janitor teardown, replace the block from `local dressing = outfits` through `pieceFolder:Destroy()` with:

```lua
			outfits = nil
			unmountDressing()
```

  `CustomizationOutfitSystem.luau` also needs `local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)` next to its `StateSyncConstants` require.

  Expected: `check_file_length` reports the client service at about 386 code lines, and `CustomizationOutfitSystem` at about 223 (dry run).

- [ ] **Step 1c: Extraction 2, the slot sender (spec §6.3), before Step 1's gate and commit.** `ReplicationServiceServer` lands at 408 code lines. Deciding who receives a slot update is a Sender's job.

  Write the spec first, `src/ServerScriptService/Features/Replication/Net/ReplicationSlotSender.spec.luau`:

```lua
--[=[
	Unit tests for ReplicationSlotSender: the slot entry's shape, and who a broadcast reaches. A recording
	packet stands in for ByteNet, so no real players are needed.
]=]

local ReplicationSlotSender = require(script.Parent.ReplicationSlotSender)

local function body(userId, ready)
	return { slot = 4, userId = userId, generation = 3, epoch = { value = 7 }, ready = ready }
end

return function()
	describe("entryOf", function()
		it("carries the slot, the owner, the generation, the epoch value and the active flag", function()
			local entry = ReplicationSlotSender.entryOf(body(-41, true), false)
			expect(entry.slot).to.equal(4)
			expect(entry.userId).to.equal(-41)
			expect(entry.generation).to.equal(3)
			expect(entry.epoch).to.equal(7)
			expect(entry.active).to.equal(false)
		end)
	end)

	describe("broadcast", function()
		it("reaches every ready viewer that is a connected player, and no one else", function()
			local sent = {}
			local packet = {
				sendTo = function(entry, player)
					table.insert(sent, { entry = entry, player = player })
				end,
			}
			local bodies = { [-1] = body(-1, true), [-2] = body(-2, false), [-3] = body(-3, true) }
			local players = { [-1] = "playerOne", [-2] = "playerTwo" } -- -3 has no player: left mid-tick
			ReplicationSlotSender.broadcast(packet, body(-9, true), true, bodies, players)
			expect(#sent).to.equal(1)
			expect(sent[1].player).to.equal("playerOne")
			expect(sent[1].entry.userId).to.equal(-9)
			expect(sent[1].entry.active).to.equal(true)
		end)

		it("sends a release with active = false", function()
			local sent = {}
			local packet = {
				sendTo = function(entry)
					table.insert(sent, entry)
				end,
			}
			ReplicationSlotSender.broadcast(packet, body(-9, true), false, { [-1] = body(-1, true) }, { [-1] = "p" })
			expect(sent[1].active).to.equal(false)
		end)
	end)
end
```

  Then the module, `src/ServerScriptService/Features/Replication/Net/ReplicationSlotSender.luau`:

```lua
--!strict
--[=[
	ReplicationSlotSender: tells viewers which body holds which slot.

	A slot entry announces a body taking a slot, or releasing it, to every viewer that has finished its
	handshake (`ready`). Deciding who receives a slot update is a Sender's job, so it lives here rather
	than in ReplicationServiceServer, which calls it on spawn, respawn and leave (issue #37). The packet
	is passed in, like ReplicationObserverUtils.sendToObservers, so a spec can record the sends.

	@class ReplicationSlotSender
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local ReplicationFanoutSystem = require(ServerScriptService.Features.Replication.Systems.ReplicationFanoutSystem)
local ReplicationObserverUtils = require(ServerScriptService.Features.Replication.Utils.ReplicationObserverUtils)

type Body = ReplicationFanoutSystem.Body

-- One row of the slot table, as the `SlotEntry` packet carries it.
export type SlotEntry = {
	slot: number,
	userId: number,
	generation: number,
	epoch: number,
	active: boolean,
}

local ReplicationSlotSender = {}

--[=[
	The slot-table row a viewer receives for `body`.
	@param body Body
	@param active boolean -- false when the body is releasing its slot
	@return SlotEntry
]=]
function ReplicationSlotSender.entryOf(body: Body, active: boolean): SlotEntry
	return {
		slot = body.slot,
		userId = body.userId,
		generation = body.generation,
		epoch = body.epoch.value,
		active = active,
	}
end

--[=[
	Sends `body`'s slot entry through `packet` to every ready viewer that is still a connected player.
	@param packet ReplicationObserverUtils.Sendable<SlotEntry>
	@param body Body
	@param active boolean
	@param bodiesByUserId { [number]: Body }
	@param playersByUserId { [number]: Player }
]=]
function ReplicationSlotSender.broadcast(
	packet: ReplicationObserverUtils.Sendable<SlotEntry>,
	body: Body,
	active: boolean,
	bodiesByUserId: { [number]: Body },
	playersByUserId: { [number]: Player }
)
	local entry = ReplicationSlotSender.entryOf(body, active)
	for userId, other in bodiesByUserId do
		local player: Player? = playersByUserId[userId]
		if other.ready and player ~= nil then
			packet.sendTo(entry, player)
		end
	end
end

return ReplicationSlotSender
```

  Then edit `ReplicationServiceServer.luau`:
  - Add `local ReplicationSlotSender = require(ReplicationServer.Net.ReplicationSlotSender)` after the `ReplicationReceiver` require.
  - Replace the two local functions `slotEntryOf` and `broadcastSlot` with:

```lua
-- Every ready viewer learns which body holds `body`'s slot (ReplicationSlotSender).
local function broadcastSlot(body: Body, active: boolean)
	ReplicationSlotSender.broadcast(ReplicationEvents.packets.SlotEntry, body, active, bodiesByUserId, playersByUserId)
end
```

  - In `onReady`, change `sendTo(slotEntryOf(other, true), player)` to `sendTo(ReplicationSlotSender.entryOf(other, true), player)`.
  - The three `broadcastSlot(...)` call sites are unchanged.

  Expected: `ReplicationServiceServer` at about 394 code lines (dry run).

- [ ] **Step 2:** Run the move loop for `UITree` (`UIStore`, `DebuggerTheme`, `TrailEasingUtils`).
- [ ] **Step 3:** Run the move loop for `Commands`.
  - Each definition's `Name` becomes its new file name in lower case.
  - LEFTOVER lines naming the old verbs are mostly ByteNet packets and UI labels. Leave those.
  - Test files that type a command name, such as `describe("addCurrency")` in a service spec, are about the service method, not the command. Leave them.

---

## Task 9: Final roots and the layout checks

**Files:**
- Modify: `src/ServerScriptService/ServerHandler.server.luau`, `src/StarterPlayer/StarterPlayerScripts/ClientHandler.client.luau`
- Modify: `src/ServerScriptService/Core/Testing/SpecRoots.luau` (`get`, doc comments that name old folders)
- Test: `src/ServerScriptService/Core/Testing/SpecRoots.spec.luau`
- Modify: `scripts/python/check_pr_rules.py`
- Delete: `scripts/python/move_layout.py`, `scripts/python/test_move_layout.py`

**Interfaces:**
- Consumes: `layout_rules.check_layout` (Task 1)
- Produces: `SpecRoots.get()`, which returns exactly the seven roots from spec §6.1.

- [ ] **Step 1: Confirm the tree is fully moved.** Run `python3 scripts/python/move_layout.py verify`, then:

```bash
git ls-files src | grep -E "Shared/(Modules|State|Events|Types)/|Client/(Modules|State|Services)/|ServerScriptService/(Modules|Services|State)/"
```

Expected: the verify passes, and the grep prints nothing.

- [ ] **Step 2: Restore the fixed spec in SpecRoots.spec.** Replace the `SpecRoots.get` describe block with:

```lua
	describe("SpecRoots.get", function()
		it("returns the seven scanned roots as live Instances", function()
			local roots = SpecRoots.get()
			expect(#roots).to.equal(7)
			for _, root in roots do
				expect(typeof(root)).to.equal("Instance")
			end
		end)
	end)
```

- [ ] **Step 3: Fix the root list.** In `SpecRoots.luau`, delete `appendExisting` and set:

```lua
--[=[
	The roots TestEZ scans: Core, Data and Features in each realm, the client tree (features and UI),
	and the Cmdr commands.
	@return { Instance }
]=]
function SpecRoots.get(): { Instance }
	return {
		ReplicatedStorage.Shared.Core,
		ReplicatedStorage.Shared.Data,
		ReplicatedStorage.Shared.Features,
		ReplicatedStorage.Client,
		ServerScriptService.Commands,
		ServerScriptService.Core,
		ServerScriptService.Features,
	}
end
```

Also update the `assertAllSpecsCovered` doc comment that says this project's shared code lives under `Shared`. It still does, so keep the sentence, but drop any mention of `Shared.Modules` as a first-party folder.

- [ ] **Step 4: Walk `Features` only.** In `ServerHandler.server.luau`, replace the transitional two-root loop with:

```lua
-- Register all server services: every `*ServiceServer` at a feature root (docs/project-structure.md).
local Features = ServerScriptService.Features
for _, ServerService in Features:GetDescendants() do
	-- (unchanged body)
end
```

Make the same change in `ClientHandler.client.luau`: `local Features = ReplicatedStorage.Client.Features`, then `*ServiceClient`.

- [ ] **Step 5: Wire in the layout checks.** In `check_pr_rules.py`:
  - Add `import layout_rules` beside the other imports. The script runs as `python3 scripts/python/check_pr_rules.py`, so its own folder is on `sys.path`.
  - Add a `layout_errors` function:

```python
def layout_errors() -> list[str]:
    """Whole-tree: every module sits where docs/project-structure.md says and is named for it."""

    def read(path: str) -> str:
        with open(path, encoding="utf-8") as handle:
            return handle.read()

    return layout_rules.check_layout(run("ls-files", "src").splitlines(), read)
```

  - In `main`, add `*layout_errors(),` to the `errors` list after `*remote_calls_in_react(),`.
  - Add a bullet to the module docstring:

```
* **Module layout (issue #37).** Whole-tree invariants from ``layout_rules.py``: placement, depth,
  feature prefix, role word, one service per feature, command names, UI names. The move left the
  tree compliant, so there is no past to grandfather. The allowed subfolders, role words and service
  exceptions live in that module; changing them is a rule change that needs the developer's approval.
```

  - Drop the old homes from the transitional constants:

```python
ASSET_ID_ALLOWED_PREFIXES: tuple[str, ...] = ()
UI_LIFECYCLE_TREE = ("src/ReplicatedStorage/Client/Features/",)
```

  - Rewrite the asset-id docstring bullet and comment to say registries live in each feature's `Data/` folder (`ASSET_ID_FEATURE_DATA`).
  - Then remove `ASSET_ID_ALLOWED_PREFIXES` entirely, together with its `startswith` test and its mention in the error message. The message should now say "outside a feature's Data/ folder".

- [ ] **Step 6: Prove each check fails, then passes.** Create each file below, run the check, see the expected `FAIL`, delete the file, and move to the next:

| Planted file | Expected `FAIL` contains |
|---|---|
| `src/ReplicatedStorage/Shared/Modules/Stray.luau` | `outside every Features/<Feature>/ root` |
| `src/ReplicatedStorage/Shared/Features/Bank/Net/Deep/BankEvents2.luau` | `too deep` |
| `src/ReplicatedStorage/Shared/Features/Bank/Signals/BankSignal.luau` | `not a subfolder kind` |
| `src/ReplicatedStorage/Shared/Features/Bank/Net/MoneyEvents.luau` | `must start with its feature` |
| `src/ReplicatedStorage/Shared/Features/Bank/State/BankHelper.luau` | `role word` |
| `src/ServerScriptService/Features/Bank/BankAuditServiceServer.luau` | `only \`BankServiceServer\` sits at the feature root` |
| `src/ServerScriptService/Commands/AddMoney.luau` with `return { Name = "addmoney" }` | `must start with its feature's name` |
| `src/ReplicatedStorage/Client/UI/React/lowercase.luau` | `PascalCase` |

Each file holds `--!strict\nreturn {}` unless the table says otherwise.

Run: `python3 scripts/python/check_pr_rules.py origin/main`. Afterwards, `git status --short` must show no planted file.

- [ ] **Step 7: Delete the mover.**

```bash
git rm scripts/python/move_layout.py scripts/python/test_move_layout.py
```

The attachments in `docs/superpowers/plans/2026-10-07-module-layout/` stay as the record of the move.

- [ ] **Step 8: Gate and commit.** Run `stylua src`, then `bash scripts/check.sh`. Expected: all pass, including `PR rules passed`.

```bash
git add -A src scripts
git commit -m "feat(layout): enforce the module layout in check_pr_rules; drop the transitional roots (#37)"
```

---

## Task 10: Docs, AGENTS.md, the skill and the module map

**Files:**
- Modify: `docs/project-structure.md` (rewrite)
- Modify: `AGENTS.md`
- Create: `.claude/skills/module-placement/SKILL.md`
- Modify: `docs/architecture.md`, `docs/testing.md`, `docs/animation.md`, `docs/conventions.md`, `docs/tech-stack.md`, `docs/limitations.md`, `docs/ROADMAP.md`. Fix the leftovers the mover could not.
- Modify: `scripts/check.sh` and `.github/workflows/ci-cd.yml` (module-map check)

- [ ] **Step 1: Rewrite `docs/project-structure.md`.**
  - Keep its "The spec-sibling rule" and "Adding a profile slice" sections, with paths updated (the mover already rewrote the full paths).
  - Replace "Realm layout" and "Service discovery" with these sections, in this order. Copy their content from the spec, adjusted to describe the present rather than the move:
    - `## Realm roots`: spec §2.1, the table.
    - `## Outside features`: spec §2.2, the table and the "closed lists" paragraph.
    - `## Inside a feature`: spec §2.3, the subfolder table, the three-question test, and the Bank example from §2.4.
    - `## Rules`: spec §3, rules 1–7, including all three approval gates and the folder-variable rule with its example.
    - `## Naming`: spec §4.1 (pattern, role-word table, feature names, ByteNet note, "not renamed"), §4.2 (the UI convention, without the rename table), and §4.3 (the command convention, without the rename table).
    - `## Service discovery`: `ServerHandler` / `ClientHandler` walk `ServerScriptService.Features` / `ReplicatedStorage.Client.Features` for `*ServiceServer` / `*ServiceClient`, and warn on a near-miss name.
    - `## Where does my new code go?`: the decision list below.
    - `## Module map`: one sentence ("Generated by `scripts/python/module_map.py --write`; `check.sh` and CI fail when it is stale."), then the two markers on their own lines: `<!-- module-map:start -->` and `<!-- module-map:end -->`.

  The decision list:

```markdown
1. **Which feature does this job?** The feature whose job it is, not the one it runs inside. A new
   feature needs a name: singular, PascalCase.
2. **Which realm?** Needed by both server and client → shared. Client only → client. Server only →
   server.
3. **Is it the feature's service?** One per feature per realm, at the feature root:
   `<Feature>ServiceServer` / `<Feature>ServiceClient`. A second one needs the developer's approval.
4. **Otherwise, which subfolder?** Data (what exists), Net (how it travels), Rules (allowed or
   valid?), Testing (test tools). Otherwise ask, in order: acts on its own or changes what it
   doesn't own → Systems; remembers anything → State; otherwise → Utils.
5. **Name it** `<Feature><What><RoleWord>` with a role word its subfolder allows.
6. **Nothing fits?** Stop and ask. A new subfolder kind needs three modules that share it and the
   developer's approval; a new role word needs approval.
7. **Write its spec** beside it, or add it to `SpecRoots.EXEMPT_MODULES` with a reason.
8. Run `python3 scripts/python/module_map.py --write`.
```

- [ ] **Step 2: Generate the map.**

Run: `python3 scripts/python/module_map.py --write`, then `python3 scripts/python/module_map.py --check`
Expected: `module map is current`.

- [ ] **Step 3: Gate the map.**

In `scripts/check.sh`, add this after the file-length step:

```bash
echo ""
echo "==> Module map (docs/project-structure.md matches src/)"
python3 scripts/python/module_map.py --check
```

In `.github/workflows/ci-cd.yml` (`scripts-lint`), add this after the file-length step:

```yaml
      # docs/project-structure.md's module map is generated; a stale map means a module was added,
      # moved or renamed without regenerating it.
      - name: Module map
        run: python3 scripts/python/module_map.py --check
```

- [ ] **Step 4: Update AGENTS.md.**
  - Under "Non-negotiable working rules", add after the spec-first bullet:

```markdown
- **Module placement.** Every new module's feature, realm, subfolder and name are stated in the plan
  before it is written, and follow [docs/project-structure.md](docs/project-structure.md). Use the
  `module-placement` skill when planning, adding a module, or reviewing. A new subfolder kind (three
  modules that share it **and** the developer's approval), a new role word, or a second service in one
  feature needs the developer's approval; `check_pr_rules` fails any file that breaks the layout.
```

  - In "Architecture in one screen", change the ServiceController bullet's discovery sentence to: "Services are auto-discovered under each realm's `Features/` root by the `*ServiceServer` / `*ServiceClient` filename suffix."
  - In "Where to look", change the project-structure row to: "The feature layout and naming rules, where new code goes, service discovery, the spec-sibling rule, the add-a-slice recipe, and the generated module map."

- [ ] **Step 5: Create the skill.** Write `.claude/skills/module-placement/SKILL.md`:

```markdown
---
name: module-placement
description: Use when writing an implementation plan, adding or renaming a Luau module, or reviewing a change in this repo - places every module by the feature layout rules and stops on approval-gated changes
---

# Module placement

The layout rules live in `docs/project-structure.md`; `check_pr_rules` enforces them. This skill makes
placement a decision written down **before** code exists, not something discovered when CI fails.

## When writing a plan

Every plan that creates or renames a module carries a **New modules** table before the first task
that writes one:

| Feature | Realm | Subfolder | Name | Job (one line) |
|---|---|---|---|---|

Fill each row by walking "Where does my new code go?" in `docs/project-structure.md`:

1. The feature whose JOB it is (not the one it runs inside).
2. The realm: shared, client or server.
3. The feature's service sits at the root; everything else in exactly one subfolder.
4. The subfolder: Data, Net, Rules, Testing by what it is; else the three-question test (acts on its
   own or changes what it doesn't own → Systems; remembers → State; otherwise → Utils).
5. The name: `<Feature><What><RoleWord>`, with a role word its subfolder allows.

## When adding a module

Use the plan's row. No row? Add one to the plan first. After adding, moving or renaming any module
run `python3 scripts/python/module_map.py --write`.

## When reviewing

For each new or moved module: does its feature do this job? Does the three-question test land it in
this subfolder? A name that passes the check can still be in the wrong feature; that is the review's
job.

## Stop and ask, never decide

These need the developer's explicit approval. Present the case (the modules involved, why nothing
existing fits) and wait:

- A new subfolder kind. It also needs at least three modules that share it.
- A new role word.
- A second service in one feature and realm.

Editing `layout_rules.py`'s tables to make a failing file pass is a CI bypass. Don't.
```

- [ ] **Step 6: Fix the doc leftovers.**
  - Run `git grep -nE "Shared/(Modules|State|Events|Types)|Client/(Modules|State|Services)|ServerScriptService/(Modules|Services|State)|Shared\.(Modules|State|Events|Types)" -- docs AGENTS.md README.md CONTRIBUTING.md ':!docs/superpowers'`.
  - Rewrite every hit to its new path. The mover only handled full paths.
  - Use the module map for the new location.
- [ ] **Step 7: Gate and commit.** Run `bash scripts/check.sh`. Expected: all pass, including the module map.

```bash
git add docs AGENTS.md .claude/skills scripts/check.sh .github/workflows/ci-cd.yml
git commit -m "docs(layout): project-structure rules and module map, AGENTS.md rule, module-placement skill (#37)"
```

---

## Task 11: Studio verification and PR

The developer runs this task. An agent prepares it and reads results, but never serves or merges on its own.

- [ ] **Step 1: Push and open the PR.**

```bash
git push -u origin feature/module-layout
gh pr create --draft --base feature/replication-chat-voice --title "Module layout: features, role-word names, enforced placement (#37)" --body-file <notes>
```

The PR is based on R5's branch, so it shows only the layout commits, like the R2–R5 stack. After #38 merges, rebase onto main, retarget the PR to `main`, and mark it ready. The body lists the spec, the commits, and the verification checklist below. CI must be green, including Tests on Open Cloud.

- [ ] **Step 2: TestEZ in Studio.**
  - The developer serves this worktree.
  - Set the Workspace attribute `RunTests = true`, hit Play, and read the output.
  - Expected: the same pass count as main before the move, give or take the art-check spec (one test renamed, one shape test replaced), and 0 errors.
  - `assertAllSpecsCovered` and `assertAllModulesSpecced` both pass.
- [ ] **Step 3: Stale folders.**
  - In the served place, check `ReplicatedStorage.Shared` and `ReplicatedStorage.Client` for `Modules`, `State`, `Events`, `Types` or `Services`.
  - Expected: none. If any survived, delete it by hand in Studio. That is the `$ignoreUnknownInstances` trade-off.
  - Add the same folder names to the cutover hand-clean list in `docs/REFACTORHANDOFF.md`.
- [ ] **Step 4: Two-player play test.**
  - Expected: no "skipped by discovery" warnings and no dependency errors.
  - Customization dresses both players, replication moves both, voice and chat work, and F4 opens the Debugger.
  - `art conformance:` logs once at boot.
  - Run `currencyadd`, `slotswitch` and `customizationcheckart` from Cmdr. Each works.
- [ ] **Step 4b: The three extractions (spec §6.3), each checked on its own.** These are the only changes in the move that alter code shape, so they get their own rows.

  **Extraction 1, the outfit mount:**
  - TestEZ: the two new `CustomizationOutfitSystem` `mount` tests pass (Step 2's run).
  - In play, `Workspace.CosmeticPieces` exists on each client, as before.
  - Each player sees their own rig dressed at spawn, with no undressed frame, and sees the other player's
    puppet dressed (hair and shoes included).
  - Change your appearance with a customization command: both screens update.
  - Respawn, and have one player leave and rejoin the same server: the rejoiner is dressed on both
    screens, and F4 shows no climbing piece or puppet counts.
  - Stop the session: no errors from the teardown (`unmountDressing`).

  **Extraction 2, the slot sender:**
  - TestEZ: the three `ReplicationSlotSender` tests pass.
  - Each player sees the other appear on join, after a respawn, and after a leave and rejoin. When a player leaves, their puppet disappears on the other screen.

  **Extraction 3, the entitlement rules:**
  - TestEZ: the seven `CustomizationEntitlementRules` tests pass, and the existing `CustomizationServiceServer` equip tests are unchanged and pass.
  - In play, equipping a free cosmetic works.
  - Equipping a locked one (WizardHat) is refused with the "locked" message.
  - After `customizationunlockcosmetic`, the same equip works.
- [ ] **Step 5:** Only on the developer's sign-off, merge it:

```bash
gh pr merge <N> --merge --subject "Merge PR #<N>: Module layout and enforced placement"
```
