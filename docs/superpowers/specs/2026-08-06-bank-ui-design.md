# Design — Bank UI (Refactor Phase 7, second screen)

**Status:** draft · **Date:** 2026-08-06 · **Phase:** 7 (UI framework), following the Inventory panel

## Purpose

The client half of the bank. Phase 4 built the entire server-authoritative bank — slice, validator,
capacity policy, atomic deposit/withdraw for items and currency — and shipped it with **no way for a
player to reach it**: the only callers are Cmdr admin commands. This phase adds the network contract,
the client write path, and the two-sided screen.

It is also the phase that makes the UI framework's central claim true. `SceneRegistry`'s own header
names the bank as the reason scenes exist ("`Bank` is one scene showing two co-visible container
panels, which a flat screen stack cannot express"), and `ItemGrid` was written container-agnostic
against a bank that did not yet exist. Either those seams work here or they were speculative.

## Governing principle — the authored bank is evidence, not a specification

Per project memory (`[[authored-code-is-suspect-not-a-spec]]`, and the same warning this phase's
Phase 4 sibling opens with): Venture's old code is evidence of **intent**, never of **shape**. A
pattern matching `BankUIController` is a reason for more scrutiny, not less.

That is not abstract here. Reading the authored `ServerStorage.Banker` tree alongside its controller
turned up two structures that exist as art and are wired to nothing:

- **`TransferItemMenu`** — a stage-then-commit basket (`DepositItemMenu` / `WithdrawItemMenu` scroll
  frames, with `DepositButton` / `WithdrawButton` beneath) with **zero code references** anywhere in
  `Modules`. The live behaviour is immediate transfer through `bankActionHandler`.
- **Three identical `ItemInfo` frames** (`BankItemInfo`, `BankerItemInfo`, `InventoryItemInfo`), same
  rects, same children, at the same fixed position — one card duplicated per surface.

Both were found by grepping for consumers rather than by trusting the instance tree. Building either
faithfully would have produced a screen the game never had. Authored **art** is still the visual
target (subject to the populate-script caveat in `[[authored-ui-templates-are-not-the-shipped-look]]`);
authored **logic and structure** is presumed wrong until argued otherwise.

## What already exists

| Piece | Where | State |
|---|---|---|
| `bank` profile slice, validator, flat capacity | `BankServiceServer` | shipped (PR #9) |
| Atomic deposit/withdraw, items + currency | `BankServiceServer` | shipped |
| Shared container rules with injectable room check | `ContainerValidation`, `ContainerPlacement` | shipped |
| Replication to `ClientStore.bank` | `SliceManifest` | shipped |
| Container-agnostic grid, `DisplayItem`, `Slot`, `DropTargets` | Phase 7 inventory work | shipped |
| Network contract (`BankEvents`) | — | **missing** |
| Server request handlers | — | **missing** |
| Client write methods | `BankServiceClient` is read-only | **missing** |
| `BankPanel`, `BankScene` | — | **missing** |
| `containerId` on grid callbacks | documented, no consumer | **missing** |

No server change is required by anything below.

## Decision 1 — One `ContainerPanel`, rendered per side

**Chosen:** extract the browsing surface — the plate art, search well, sort control, category tabs and
item grid — into a `ContainerPanel`, fully controlled and owning no state. `InventoryPanel` becomes
`ContainerPanel` plus the equipment paperdoll; `BankPanel` becomes two `ContainerPanel`s.

Each side gets its **own** filter state (category, search, sort) held by its owner. Two sides sharing
one filter state would mean typing in one search box refiltered the other.

**The detail card and the drag deliberately stay at SCREEN level, above `ContainerPanel`.** Both cross
container boundaries: the card is fed by the equipment paperdoll as well as the grid, so a card owned
by one container could never show an equipped item; and a drag has two ends, so its ghost and drop
targets belong to whatever contains both. One card per screen also settles by construction something
the authored bank does not — it ships three identical `ItemInfo` frames, one per surface, which can
disagree with each other.

The panel is controlled rather than stateful for a concrete reason: the owner has to resolve the
pinned/hovered/dragged keys against the built list, so the owner has to be what builds it. Clicking an
equipment cell also drives the category from outside, so the filter cannot be private either.

This is the one place the authored structure and the right answer agree, and it is worth stating why
rather than pointing at the old tree: `InventoryFrame` and `BankFrame` are clones because a container
browser is genuinely the same problem twice. The authored version reaches that result by
instantiating the same managers twice over duplicated instances, which is the part not worth copying.

**Rejected — build `BankPanel` standalone and dedupe later.** It leaves two copies of the filtering,
selection and drag wiring in the interim, and this project's whole premise is that the divergence
between two such copies is what rots.

## Decision 2 — Transfers are immediate, with no staging basket

**Chosen:** acting on an item transfers it there and then, as the live authored behaviour does and as
the server is already built for. Each transfer is its own atomic transaction.

**Rejected — the authored `TransferItemMenu` basket.** Dead art (see the governing principle), and it
would fight the server: a basket implies "apply N moves together," which is either N transactions
pretending to be one, or a batch verb that does not exist and whose failure semantics (does move 4 of
7 failing roll back the first three?) nothing needs.

## Decision 3 — Items move as whole holdings; only currency takes an amount

**Chosen:** no quantity control for items. `depositItem`/`withdrawItem` move a whole holding — every
stack of that `itemType`, or one `uid` — per Phase 4's Decision 4, which was an explicit call, not an
oversight. The currency strip does take an amount, plus an "all" verb, because
`depositCurrency`/`withdrawCurrency` already carry one.

The authored UI agrees (`DepositItem(clickedItem)` takes no amount; `CoinAmount` exists only in
`TransferCoinMenu`), but the binding reason is that a partial-stack transfer raises a question Phase 4
declined to answer — whether a mid-split stack counts as one entry or two against the cap, and at
what point in the transaction. Deferred, not foreclosed: nothing here blocks adding a quantity
parameter later.

## Decision 4 — `containerId` is carried by every action callback

**Chosen:** the grid's documented-but-unused `containerId` becomes real. Selection, right-click and
drop callbacks all report which container they came from, so `BankPanel` can route an action to the
correct verb without inferring it from position.

Without it, a drag between two visually identical sides has no way to say which side it started on.

## Decision 5 — The packet set makes a malformed request inexpressible

**Chosen:** four item packets — `DepositUnique`, `DepositStack`, `WithdrawUnique`, `WithdrawStack` —
each carrying one string, plus four currency packets carrying a currency type and an amount. The
server constructs the `{ uid } | { itemType }` spec union itself.

Mirrors `EquipmentEvents`, where `EquipItem` deliberately carries no slot so that asking for a helmet
in a weapon slot is not expressible rather than expressible-and-rejected. A single packet with a
discriminator field would reintroduce exactly the malformed case the split avoids.

Fire-and-forget, like equipment: no packet answers. The result arrives through charm-sync into
`ClientStore.bank` / `ClientStore.inventory`, which both panels already read reactively. A response
would create a second source of truth for the same state.

## Decision 6 — The bank opens on a debug keybind and a Cmdr command

**Chosen (developer's call):** a keybind plus a Cmdr command for now.

The real trigger is a banker NPC or a proximity prompt, which is world content — placement, model,
and interaction all belong with the world pass, not with a UI phase. Nothing about the scene changes
when that lands; it pushes the same scene.

## Capacity asymmetry — a real constraint, not an oversight

The two sides cannot show the same meter:

- **Inventory:** per-kind caps — `weapon 30, armour 30, consumable 40, misc 40` (`ItemConstants`)
- **Bank:** one flat total-entry cap — `90` (`BankConstants.CAPACITY`)

So a deposit can be refused because the bank is full overall, while a withdraw can be refused because
one *kind* of the inventory is full even though the bag has room. The UI must be able to say which,
and the bank side's meter is a single bar where the inventory side's is per-kind.

## Plan

1. **Extract `ContainerPanel`.** No behaviour change; `InventoryPanel` re-verified before moving on.
   `containerId` threaded through the action callbacks.
2. **`BankEvents` + write path.** Namespace, server listeners via `RequestHandler.wrap` with a rate
   limit, `Guard`-validated amounts, and write methods on `BankServiceClient`.
3. **`BankPanel` + `BankScene`.** Two sides on the authored frames; click, right-click and drag all
   transfer, with each side a drop target via `DropTargets`. Keybind + Cmdr entry.
4. **Currency strip.** `TransferCoinMenu`: amount box, Deposit / Deposit All / Withdraw / Withdraw All.

## Decision 7 — Both sides get the full category tabs

**Chosen (developer's call):** the bank side carries the same tabs as the inventory side.

The bank stores `InventoryEntry` — the *same* type the inventory holds, with no restriction on kind —
so a bank is full of weapons and armour, and is in fact where gear goes when it is not in the bag. A
90-entry flat cap makes filtering more useful there than in the bag, not less. (An earlier draft of
this doc asserted the bank "holds no equipment"; that was simply wrong, and nothing in the schema or
`BankServiceServer` supports it.)

## Decision 8 — The bank card does NOT compare across containers

**Chosen (developer's call):** the detail card shows the item, with no "you already hold N of this on
the other side" line.

The inventory card compares against **equipped** gear because that comparison answers a decision the
player is making at that moment — is this an upgrade. Where a copy happens to sit is not that; it is a
number the player did not ask for, on a card that already carries the item's whole stat block. The
grid's own search answers "do I have another one" better than a card line would.
