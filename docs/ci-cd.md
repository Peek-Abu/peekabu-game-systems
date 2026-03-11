# CI/CD

Continuous integration and deployment for peekabu-game-systems, built on GitHub
Actions + Roblox Open Cloud. Defined in [`.github/workflows/ci-cd.yml`](../.github/workflows/ci-cd.yml).

## Pipeline overview

On every pull request to `main` and every push to `main`:

| Job | What it does | Needs setup? |
|-----|--------------|--------------|
| **Lint** | `selene src` | No |
| **Format** | `stylua --check src` | No |
| **Type Check** | `luau-lsp analyze` over `src` — a **blocking** gate; any type error fails the pipeline | No (the job fetches the sourcemap, package types, and Roblox globals itself) |
| **Tests** | Build place → upload to the **test** place → run TestEZ on Roblox's servers via the Open Cloud **Luau Execution API** | API key + test place |
| **Deploy** | Build place → publish to the **production** place (only on push to `main`, gated by manual approval) | API key + prod place + environment |

The tests run on real Roblox servers — no Studio and no self-hosted runner required.
This mirrors Roblox's official [place-ci-cd-demo](https://github.com/Roblox/place-ci-cd-demo).

Tests do **not** run again during deploy: the `deploy` job `needs` the `test` job, so it
only runs after tests have already passed, then just builds and publishes.

**Type checking gates everything downstream.** The `test` job `needs` `typecheck` (alongside
`lint` and `format`), and `deploy` `needs` `test` — so a type error blocks tests, merges, and
deploys. Spec files are excluded from analysis (they rely on TestEZ globals); everything else in
`src` must be type-clean. See [conventions: Service Module Shape](conventions.md#service-module-shape)
for the pattern that keeps it clean.

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

### 2. Create an Open Cloud API key

Creator Dashboard → *Open Cloud → API Keys → Create API Key*:

- **Scopes** (add the **test and production** experiences):
  - `universe.places:write` — upload/publish place versions
  - `universe.place.luau-execution-session:write` — run the test task
- **IP allowlist**: `0.0.0.0/0` (GitHub runners have no fixed IP), or restrict if you
  use self-hosted runners.

Copy the key once — you can't view it again.

### 3. Add GitHub secrets & variables

Repo → *Settings → Secrets and variables → Actions*.

**Secret:**
| Name | Value |
|------|-------|
| `ROBLOX_API_KEY` | the Open Cloud API key from step 2 |

**Variables:**
| Name | Value |
|------|-------|
| `ROBLOX_TEST_UNIVERSE_ID` | test universe id |
| `ROBLOX_TEST_PLACE_ID` | test place id |
| `ROBLOX_PRODUCTION_UNIVERSE_ID` | production universe id |
| `ROBLOX_PRODUCTION_PLACE_ID` | production place id |

(IDs are non-secret, so they're variables; the key is a secret.)

### 4. Create the `production` environment (the approval gate)

Repo → *Settings → Environments → New environment → `production`*. Under
**Deployment protection rules**, enable **Required reviewers** and add yourself.

> This is what makes deploys wait for a click. Until you configure required reviewers,
> the `deploy` job will publish automatically on every push to `main`.

### 5. Protect `main`

Repo → *Settings → Branches → Add branch ruleset* (or classic branch protection) for `main`:

- Require a pull request before merging (+ at least 1 approval)
- Require status checks to pass: **Lint (Selene)**, **Format (StyLua)**, **Type Check (luau-lsp analyze)**, **Tests (Open Cloud Luau Execution)**
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

## Notes & future refinements

- **Tests ship to production.** The built place currently includes `DevPackages` (TestEZ)
  and `*.spec.luau` files. They never run in-game (just dead `ModuleScript`s), but to keep
  them out of the published place you can add a separate prod project file that omits
  `DevPackages` and point the deploy build at it.
- **Line endings.** `stylua.toml` is set to `Windows` (CRLF) to match the checked-in files.
  If you adopt a `.gitattributes` that normalizes to LF, switch it to `Unix` and re-run
  `stylua src`.
- **Open Cloud Luau Execution** is limited to 2 concurrent tasks per universe, so the test
  job uses a `luau-execution` concurrency group to serialize runs.
- **Wally on CI** installs from the public registry unauthenticated; if you hit GitHub rate
  limits, configure a token for Wally.
