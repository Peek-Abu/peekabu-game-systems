# CI/CD

Continuous integration and deployment for peekabu-game-systems, built on GitHub
Actions + Roblox Open Cloud. Defined in [`.github/workflows/ci-cd.yml`](../.github/workflows/ci-cd.yml).

## Pipeline overview

**Lint, Format, and Type Check run on every push to every branch** (fast feedback before a PR).
**Tests** run on pull requests into `main` and on pushes to `main`; **Deploy** runs only on a push
to `main`. The "When" column below is the actual trigger for each job.

| Job | What it does | When | Needs setup? |
|-----|--------------|------|--------------|
| **Lint** | `selene src` | Every push | No |
| **Format** | `stylua --check src` | Every push | No |
| **Type Check** | `luau-lsp analyze` over `src` and `tasks/` — a **blocking** gate; any type error fails the pipeline | Every push | No (the job fetches the sourcemap, package types, and Roblox globals itself) |
| **Scripts Lint** | `ruff check scripts/python` — gates the Open Cloud upload/publish scripts that the Tests and Deploy jobs execute | Every push | No |
| **Tests** | Build place → upload to the **test** place → run TestEZ on Roblox's servers via the Open Cloud **Luau Execution API** | PR into `main` + push to `main` | API key + test place |
| **Deploy** | Build place → publish to the **production** place, gated by manual approval | Push to `main` | API key + prod place + environment |

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

### 2. Create TWO Open Cloud API keys

Creator Dashboard → *Open Cloud → API Keys → Create API Key*. Two keys, so the
production-publish capability never crosses into the non-approval-gated test job — a
compromised PR or test run holding the test key physically cannot publish to production.

**Test key** (add the **test** experience only):
- `universe.places:write` — upload place versions for the test run
- `universe.place.luau-execution-session:write` — run the test task

**Production key** (add the **production** experience only):
- `universe.places:write` — publish the production place

For both: **IP allowlist** `0.0.0.0/0` (GitHub runners have no fixed IP), or restrict if
you use self-hosted runners. Copy each key once — you can't view it again.

### 3. Add GitHub secrets & variables

Repo → *Settings → Secrets and variables → Actions*.

**Secret (repository-level):**
| Name | Value |
|------|-------|
| `ROBLOX_API_KEY` | the **test** key from step 2 |

The **production** key is NOT a repository secret — it goes on the `production`
environment in step 4, so only the approval-gated deploy job can read it.

**Variables:**
| Name | Value |
|------|-------|
| `ROBLOX_TEST_UNIVERSE_ID` | test universe id |
| `ROBLOX_TEST_PLACE_ID` | test place id |
| `ROBLOX_PRODUCTION_UNIVERSE_ID` | production universe id |
| `ROBLOX_PRODUCTION_PLACE_ID` | production place id |

(IDs are non-secret, so they're variables; the key is a secret.)

### 4. Create the `production` environment (the approval gate + the prod key)

Repo → *Settings → Environments → New environment → `production`*:

1. Under **Deployment protection rules**, enable **Required reviewers** and add yourself.
2. Under **Environment secrets**, add `ROBLOX_PROD_API_KEY` = the **production** key from
   step 2. Environment secrets are only exposed to jobs that declare
   `environment: production` — i.e. the deploy job, after approval.

> Required reviewers is what makes deploys wait for a click. Until you configure them,
> the `deploy` job will publish automatically on every push to `main`.

### 5. Protect `main`

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

## Notes & future refinements

- **Tests do NOT ship to production** (resolved). The deploy job builds
  [`production.project.json`](../production.project.json), which omits `DevPackages` (TestEZ), and
  deletes `*.spec.luau` files plus the Studio `TestRunner` from its workspace before building. The
  dev/test place still uses `default.project.json` with everything included.
- **Line endings** (resolved). The repo is normalized to LF end to end: `.gitattributes`
  (`* text=auto eol=lf`) checks every text file out as LF on every platform, and `stylua.toml`
  is set to `Unix` to match. This matters because `stylua --check` fails on ending-only
  differences — before the attributes file, a Linux checkout (LF, which is what the index
  always stored) run against the old `Windows` setting failed the Format gate with zero code
  changes. If your clone predates `.gitattributes`, re-run `stylua src` once (or re-checkout
  on a clean tree) to bring your working files to LF.
- **Open Cloud Luau Execution** is limited to 2 concurrent tasks per universe, so the test
  job uses a `luau-execution` concurrency group to serialize runs.
- **Serialized deploys.** The deploy job uses a `production-deploy` concurrency group
  (`cancel-in-progress: false`) so two rapid pushes to `main` can't publish out of order —
  without it, an older run approved later could overwrite a newer build — while an in-flight
  publish is never killed halfway.
- **Wally on CI** installs from the public registry unauthenticated; if you hit GitHub rate
  limits, configure a token for Wally.
