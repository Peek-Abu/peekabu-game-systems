# Contributing

This is a reusable, server-authoritative game-systems base for Roblox, written in Luau
`--!strict` end to end. Contributions are expected to keep it that way: strongly typed, tested
first, and clean through the full lint → format → type-check → test pipeline.

This file is the entry point. It links out to the deeper docs rather than restating them — read
the ones relevant to what you're changing.

---

## Before you start

Install [Rokit](https://github.com/rojo-rbx/rokit) (the toolchain manager), then set up the
project. Rokit pins exact versions of every tool from [rokit.toml](rokit.toml), so your local
tools match CI byte-for-byte.

```bash
rokit install            # install the pinned toolchain
wally install            # install Wally packages
rojo sourcemap default.project.json --output sourcemap.json

# Package type exports for EVERY realm (ProfileStore lives in ServerPackages/ — skipping its
# pass leaves the whole data layer typed as `Unknown`). Mirrors install.sh / check.sh / CI.
wally-package-types -s sourcemap.json Packages/
wally-package-types -s sourcemap.json ServerPackages/
wally-package-types -s sourcemap.json DevPackages/
```

[install.sh](install.sh) runs the above and produces a build in one go. Then `rojo serve` and
connect via the Rojo Studio plugin to work in Studio.

---

## The workflow

This is a **test-driven** codebase. The short version:

1. **Write the spec first.** Create `<Name>.spec.luau` next to the module and describe the
   behavior — including the failure modes — before implementing. See [docs/testing.md](docs/testing.md).
2. **Implement** until the spec passes.
3. **Run the checks locally** (below) before you push.
4. **Open a PR into `main`.** CI runs the full suite as the merge gate.

New modules are not optional-to-test: `SpecRoots.assertAllModulesSpecced` (run by both test
runners before the suite) **fails the build** if a first-party module under a scanned root has no
`.spec` sibling and isn't on the explicit exempt list. So a new service or util either ships with a
spec or records — in `SpecRoots.EXEMPT_MODULES`, with a reason — why a unit test would be
tautological. See [Test Coverage](docs/testing.md#test-coverage--whats-enforced).

### Adding a new service

1. Create the module at `src/ServerScriptService/Services/<Name>/<Name>ServiceServer.luau` (or the
   client path). The `*ServiceServer` / `*ServiceClient` suffix is how the boot loaders
   auto-discover it.
2. Declare dependencies: `MyService.dependencies = { "PlayerDataServiceServer" } :: { string }`.
3. Implement the lifecycle methods you need (`init` / `start` / `stop`) as fields on the annotated
   literal — only the ones you need.
4. Write the spec alongside it.

`ServerHandler` / `ClientHandler` register, init, and start it automatically. The full template and
the rationale for the "lean annotated-literal" pattern are in
[docs/conventions.md](docs/conventions.md#service-module-shape).

---

## Running the checks locally

[scripts/check.sh](scripts/check.sh) reproduces the three non-test CI jobs (lint, format,
type-check) 1:1, so you can catch every non-test failure before pushing:

```bash
bash scripts/check.sh                 # lint + format-check + type-check (runs `wally install`)
bash scripts/check.sh --skip-install  # skip `wally install` when link files are fresh
```

On Windows, run it via Git Bash.

| Task | Command |
|------|---------|
| Lint | `selene src` |
| Check formatting | `stylua --check src` |
| Auto-format | `stylua src` |
| Type-check | see `scripts/check.sh` (needs sourcemap + package types + Roblox globals first) |
| Run tests | In Studio: `rojo serve`, connect, run `TestRunner.server.luau`, read the Output window |

The test suite runs inside a real Roblox runtime — locally via the Studio `TestRunner`, and in CI
via Open Cloud Luau Execution. There is no way to run TestEZ headlessly outside those, so run the
Studio runner before opening a PR that touches testable code.

---

## What CI enforces

[.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml) — see [docs/ci-cd.md](docs/ci-cd.md) for
the full picture:

- **Lint** (`selene src`) and **Format** (`stylua --check src`) on every push.
- **Type-check** (`luau-lsp analyze` over `src` and `tasks/`) — a **blocking** gate that must pass
  with zero errors. It also gates the test job, so a type error transitively blocks merges and deploys.
- **Scripts lint** (`ruff check scripts/python`) — the Open Cloud upload/publish scripts are gated
  like first-party code, since the test and deploy jobs execute them.
- **Test** (TestEZ on Open Cloud) — gates merges into `main`.
- **Deploy** — on push to `main`, behind a manual-approval GitHub Environment.

Your PR must be green on lint, format, type-check, and test. Zero type errors is a hard requirement,
not a target.

---

## Code expectations

Read [docs/conventions.md](docs/conventions.md) in full before your first substantial change. The
load-bearing rules:

- **`--!strict` everywhere, and no casts.** `any` / `:: ` casts need genuine justification and are
  confined to real dynamic boundaries (untyped vendored packages, runtime-replicated glue), each
  documented at the site. Don't reach for a cast to silence the type-checker — fix the type.
- **Services follow the lean annotated-literal shape**: an explicit `export type MyService = { ... }`
  interface plus `local MyService: MyService = { ... }` with methods as fields. This declares types
  once and flows them into method bodies. Don't reintroduce `function MyService:method()` statements
  or `typeof(self)` intersections — see the ServiceController header for why.
- **Assertions vs. returns vs. pcall** follow a decision table — assert on developer/input error,
  return `false`/`nil` on expected runtime conditions, `pcall` only around external calls
  (DataStore, HTTP). See [docs/error-strategy.md](docs/error-strategy.md) and
  [docs/pcall-guide.md](docs/pcall-guide.md). No silent failures; log then return.
- **Shared runtime validators live in `Guard`** — use `Guard.userId` / `positiveAmount` /
  `nonNegativeAmount` rather than hand-rolling the same asserts, and validate once (at the boundary),
  not at every layer.
- **Server-authoritative always.** Clients never write authoritative state; they read the reactive
  charm-sync atoms. New player state flows through `PlayerDataService` `mutate()`/`transaction()`,
  which mirrors into the reactive spine — see [docs/architecture.md](docs/architecture.md).
- **Match the surrounding code.** Formatting is StyLua (`stylua src`); don't fight it.

---

## Commits and pull requests

- Keep commits focused; write a clear subject line and a body explaining *why* when the change isn't
  obvious.
- Rebase/tidy local history before pushing rather than pushing fixup noise.
- In the PR description, say what changed and how you verified it (which specs, whether you ran the
  Studio test runner). If you added or moved a spec location, mention it — `SpecRoots.get()` is the
  one edit site for test roots.
- Update the relevant doc in `docs/` when you change behavior it describes. The docs are kept
  accurate to the code on purpose; a behavior change with stale docs is an incomplete change.

---

## Where things live

| Doc | What it covers |
|-----|----------------|
| [docs/architecture.md](docs/architecture.md) | Boot flow, ServiceController, data/transactions, networking, the reactive spine |
| [docs/conventions.md](docs/conventions.md) | Method syntax, assertions, error handling, naming, file templates |
| [docs/testing.md](docs/testing.md) | Writing/running tests, the TDD workflow, enforced coverage |
| [docs/error-strategy.md](docs/error-strategy.md) | When to assert vs. return vs. pcall |
| [docs/pcall-guide.md](docs/pcall-guide.md) | Targeted error-handling patterns |
| [docs/limitations.md](docs/limitations.md) | Known trade-offs and future considerations |
| [docs/ci-cd.md](docs/ci-cd.md) | Pipeline setup and required secrets |

---

## License

This project is proprietary — see [LICENSE](LICENSE). By contributing you agree your contributions
are made under those terms.
