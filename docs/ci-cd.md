# CI/CD

Continuous integration (validation only — lint, format, typecheck, test) for venture,
built on GitHub Actions + Roblox Open Cloud. Defined in
[`.github/workflows/ci-cd.yml`](../.github/workflows/ci-cd.yml). Production is deployed **manually**
(see [Manual deployment](#manual-deployment)) — there is no automated CD.

## Pipeline overview

**Lint, Format, and Type Check run on every push to every branch** (fast feedback before a PR).
**Tests** run on pull requests into `main` and on pushes to `main`. The "When" column below is the
actual trigger for each job.

| Job | What it does | When | Needs setup? |
|-----|--------------|------|--------------|
| **Lint** | `selene src` | Every push | No |
| **Format** | `stylua --check src` | Every push | No |
| **Type Check** | `luau-lsp analyze` over `src` and `tasks/` — a **blocking** gate; any type error fails the pipeline | Every push | No (the job fetches the sourcemap, package types, and Roblox globals itself) |
| **Scripts Lint** | `ruff check scripts/python` — gates the Open Cloud upload script that the Tests job executes | Every push | No |
| **Tests** | Build place → upload to the **test** place → run TestEZ on Roblox's servers via the Open Cloud **Luau Execution API** | PR into `main` + push to `main` | API key + test place |

The tests run on real Roblox servers — no Studio and no self-hosted runner required.
This mirrors Roblox's official [place-ci-cd-demo](https://github.com/Roblox/place-ci-cd-demo).

> **No automated deploy (CD).** There is intentionally no deploy job. This game's playable places
> carry artist-owned content (maps, terrain, decorated builds) edited live in Studio/Team Create
> and **not** stored in this repo, and a Roblox publish overwrites the *whole* place — so an
> automated code-only build + publish would wipe that content. **Deployment is manual:** `rojo serve`
> code into the published place in Studio, then publish from there so art and code ship together.
> See [Manual deployment](#manual-deployment) below. CI stays fully automated for *validation*
> (lint/format/typecheck/test) — it just never publishes a playable build.

**Type checking gates everything downstream.** The `test` job `needs` `typecheck` (alongside
`lint` and `format`) — so a type error blocks tests and merges. Spec files are excluded from
analysis (they rely on TestEZ globals); everything else in `src` must be type-clean. See
[conventions: Service Module Shape](conventions.md#service-module-shape) for the pattern that keeps
it clean.

## One-time setup

### 1. Create the Roblox places

Create an experience in Roblox with **two places**:

- a **Test** place (CI uploads here and runs tests against it — never seen by players)
- a **Production** place (what players actually join)

For each, note its **Universe ID** (a.k.a. Experience ID) and **Place ID**. You can find
both on the Creator Dashboard, or the Place ID via *File → Game Settings* in Studio.

> A test and production place in the *same* universe is fine. If you'd rather fully
> isolate them, use two separate experiences — just use the matching universe/place IDs
> in the variables below.

### 2. Create ONE Open Cloud API key (test)

Creator Dashboard → *Open Cloud → API Keys → Create API Key*. CI only needs the **test** key —
there is no automated production publish, so no production key lives in CI at all (removing the
single largest secret-exposure risk a compromised PR could reach).

**Test key** (add the **test** experience only):
- `universe.places:write` — upload place versions for the test run
- `universe.place.luau-execution-session:write` — run the test task

**IP allowlist** `0.0.0.0/0` (GitHub runners have no fixed IP), or restrict if you use
self-hosted runners. Copy the key once — you can't view it again.

> For **manual** production deploys you publish from Studio (see [Manual deployment](#manual-deployment)),
> which uses your own Studio auth — no Open Cloud production key required. Only create one if you
> later adopt a fully-managed CD pipeline.

### 3. Add GitHub secrets & variables

Repo → *Settings → Secrets and variables → Actions*.

**Secret (repository-level):**
| Name | Value |
|------|-------|
| `ROBLOX_API_KEY` | the **test** key from step 2 |

**Variables:**
| Name | Value |
|------|-------|
| `ROBLOX_TEST_UNIVERSE_ID` | test universe id |
| `ROBLOX_TEST_PLACE_ID` | test place id |

(IDs are non-secret, so they're variables; the key is a secret. The production universe/place IDs
are no longer needed by CI — the deploy job that used them was removed.)

### 4. Protect `main`

Repo → *Settings → Branches → Add branch ruleset* (or classic branch protection) for `main`:

- Require a pull request before merging (+ at least 1 approval)
- Require status checks to pass: **Lint (Selene)**, **Format (StyLua)**, **Type Check (luau-lsp analyze)**, **Lint (Ruff, Open Cloud scripts)**, **Tests (Open Cloud Luau Execution)**
- Block force pushes and deletions

The status-check names appear in the checks list after the workflow runs once.

## Local usage

All tools are managed by [rokit](https://github.com/rojo-rbx/rokit) (`rokit install`):

```sh
selene src           # lint
stylua src           # auto-format (use --check to verify only)
./scripts/check.sh   # lint + format-check + type-check, exactly like CI (one command)
rojo build default.project.json --output dist.rbxlx   # what CI builds
```

`luau-lsp analyze` needs a sourcemap, package type exports, and the Roblox global defs first;
`scripts/check.sh` performs that setup and runs all three CI checks (lint, format, type) locally.
Only the **Tests** job genuinely needs the cloud — the other three jobs reproduce 1:1 on your machine.

Run the test suite in Studio via `ServerScriptService/TestRunner.server.luau` (this runs the exact
same TestEZ specs the cloud job runs — a green Studio run is a valid local confirmation). The CI
cloud entry point is [`tasks/runTests.luau`](../tasks/runTests.luau) — it runs the same
TestEZ locations and `error()`s on failure so the Open Cloud task (and the CI job) fails.

## Manual deployment

Production is published by hand so artist-owned place content is never overwritten by a code-only
build (see the CD note under [Pipeline overview](#pipeline-overview)). The **partially-managed**
workflow:

1. Open the published production place in Studio (via Team Create so builders are in-session).
2. Run `rojo serve` locally and connect the Rojo Studio plugin — your code syncs into the open place
   live. The project mounts **only code containers**, never `Workspace`/`Terrain`/`Lighting`, so a
   sync can never touch the artists' content.
3. Playtest, then **publish from Studio** (*File → Publish to Roblox*). Art (native to the place) and
   code (synced in) ship together.

Keep test code out of the production build the same way the old deploy job did: build from
[`production.project.json`](../production.project.json) (it omits `DevPackages`/TestEZ) if you build
a place file, or simply don't sync the `*.spec.luau` files and `TestRunner` when serving into prod.

> **Future — automated CD that preserves art.** If you want hands-off deploys back, adopt a
> *fully-managed* pipeline: a Lune `download-place` step pulls the artists' map out of a builder
> place into the repo, CI builds a *complete* place (art + code) from git, and publishes it. The
> `production.project.json` build/strip recipe and `scripts/python/publish_place.py` are preserved
> for exactly this. Until then, deploy manually as above.

## Notes & future refinements

- **Line endings** (resolved). The repo is normalized to LF end to end: `.gitattributes`
  (`* text=auto eol=lf`) checks every text file out as LF on every platform, and `stylua.toml`
  is set to `Unix` to match. This matters because `stylua --check` fails on ending-only
  differences — before the attributes file, a Linux checkout (LF, which is what the index
  always stored) run against the old `Windows` setting failed the Format gate with zero code
  changes. If your clone predates `.gitattributes`, re-run `stylua src` once (or re-checkout
  on a clean tree) to bring your working files to LF.
- **Open Cloud Luau Execution** is limited to 2 concurrent tasks per universe, so the test
  job uses a `luau-execution` concurrency group to serialize runs.
- **Wally on CI** installs from the public registry unauthenticated; if you hit GitHub rate
  limits, configure a token for Wally.
