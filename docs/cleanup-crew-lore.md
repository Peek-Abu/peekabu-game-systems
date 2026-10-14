# Cleanup Crew — Lore, Asset Economy, and Cleanup Rationale

> **Canonical reference.** Copied from the developer's `cleanup_crew_lore_economy_foundation.md` on
> 2026-10-13; edit it here. Approved project decisions on top of the text below:
>
> - The demo pays in plain **dollars** ("$45", "+$40", "EARNED $240"), not "Recovery Credits" (2026-10-14; the
>   short-lived company "Scrip" was dropped). Lore: Morrow & Morrow pays its associates a hazard-pay bonus in
>   dollars, **Recovery pay**, on the assessed value of every Recoverable Asset they bring back. The look of an
>   amount lives in one place, `ShiftCurrencyUtils`. It is display-only for now: no saved balance yet.
> - The monster is **the Manager** in every player-facing string; code internals keep the `harlow` NPC kind.
> - Overtime is opt-in: a crew member signs the overtime sheet beside the time clock at the truck
>   (`docs/superpowers/specs/2026-10-10-cleanup-crew-design.md` §4 "Pacing").

## Status
Working narrative/economy foundation for Cleanup Crew. This is a consistency guide for design, UI, environments, contracts, threats, currencies, and future content. It is not a requirement for players to read lore before playing.

## Core premise
Morrow & Morrow Clearance is a property-recovery contractor that takes jobs nobody else can finish.

It enters closed offices, warehouses, malls, laboratories, and other commercial buildings affected by **Residual activity**. The company sends Clearance Associates to clear site material, recover assets, stabilize dangerous locations, and certify properties for handoff, demolition, resale, or sealing.

Publicly, Morrow & Morrow is a boring, upbeat facilities contractor.

Internally, it understands that certain abandoned workplaces accumulate Residuals: hostile, repeating manifestations of a building’s interrupted purpose, discarded systems, unresolved routines, contaminated materials, and retained records.

The company does not call them monsters. Its paperwork calls them **noncompliant site activity**.

## The player fantasy
> You are an underpaid but optimistic Clearance Associate doing a real job in a building that should be empty—but is not.

The player’s goals are intentionally simple:

1. Clear the site.
2. Recover what the company tells them to recover.
3. Bank cargo in the Mobile Recovery Unit.
4. Meet contract quota.
5. Decide whether overtime recovery is worth the increased danger.
6. Leave alive.

Pippa and later employees are cheerful, expressive contractors—not soldiers, superheroes, or monster hunters. The contrast between cute workers, sterile company language, and genuinely dangerous workplaces is the tone.

## Why cleaning is valuable
Cleaning is not decorative housekeeping. It is the first phase of **site stabilization**.

Residual activity feeds on unattended material, repetition, accumulation, and physical traces left behind by a building’s former purpose. Clutter, dust, rubbish, leaked supplies, abandoned records, and unprocessed objects form a contaminated layer called **site buildup**.

Removing buildup does four things:

| Cleanup action | Practical company reason | Residual reason | Gameplay purpose |
|---|---|---|---|
| Vacuum loose buildup | Makes rooms safe/accessible for asset recovery | Breaks up contaminated accumulations and removes small Residual growth | Fast, satisfying action; can create noise/risk |
| Bag rubbish | Separates disposable material for off-site processing | Removes nesting/feeding material for nuisance Residuals | Creates carry/bank loop |
| Clear blocked paths | Restores access to rooms, exits, and loading routes | Interrupts repeated spatial patterns that support a site | Creates route choices and progression through a map |
| Recover Anchor Assets | Preserves high-value objects for analysis or resale | Removes objects that stabilize, attract, or contain Residual activity | Creates optional high-risk salvage |
| Bank cargo in truck | Verifies chain of custody and site removal | Takes material beyond the building’s influence | Makes progress safe and visible |

The company’s official phrase is:

> “A clean site is a compliant site.”

That slogan is corporate shorthand for a real in-world rule: clearing material weakens a building’s ability to sustain abnormal activity.

## The important tension: cleaning can also create danger
Cleaning helps in the long term, but creates immediate disturbance.

Vacuuming, moving furniture, opening storage, and removing clutter produce sound, vibration, light changes, and broken routines. Residuals interpret this as unauthorized activity.

This supports the core gameplay loop:

> Work stabilizes the building, but doing the work wakes up what is inside it.

For example:
- The Manager investigates vacuum noise because it interprets work as unauthorized staff activity.
- Dust Bunnies breed from neglected buildup; vacuuming removes them.
- Unit-7 sees dropped items as unprocessed site debris and returns them to its dock.
- A later blackout contract can make restoring power both a safety action and a source of new disturbance.

Do not make cleaning universally dangerous. It must remain useful, fast, and satisfying. The player should understand the tradeoff: clean now to gain access/remove nuisance problems, but make enough noise that the site may investigate.

## Why every object can be valuable
Not every object is valuable because of ordinary resale value.

Any object recovered from an affected property may have one or more kinds of value:

| Asset category | What it is | Why Morrow & Morrow values it |
|---|---|---|
| Recoverable Asset | Normal equipment, electronics, furniture, stock, tools | Resale, reuse, contractual recovery, insurance value |
| Data Asset | Files, employee records, server hardware, access cards, archived media | Legal ownership, internal data, liability management, client records |
| Anchor Asset | Ordinary object bound to Residual activity | Stabilizes, attracts, documents, or can safely relocate a site anomaly |
| Contaminated Material | Rubbish, buildup, dust, liquids, damaged goods | Must be removed/processed to certify site clearance |
| Prototype Asset | Old company equipment, autonomous units, lab devices | Company wants it recovered before outsiders find it |
| Misclassified Asset | Object that appears worthless but scans unusually | Potential research, resale, containment, or evidence value |

This is why a printer, vending machine, filing cabinet, office plant, server rack, mirror, broken vacuum, or seemingly useless box may all matter.

The player does not need to know the classification during the first 30 seconds. The scan value, weight, behavior, and contract context should make the decision readable.

## Currencies and rewards
Use a small economy with distinct roles. Do not add every currency at MVP.

### MVP currency: Recovery Credits
**Recovery Credits** are the core earned currency.

- Earned from banked cargo and completed contracts.
- Represents company-assessed recovery value, not literal cash found in the building.
- Pays for early non-power progression and cosmetic unlocks after the core loop is validated.
- Banked cargo is safe; unbanked cargo only matters for the current shift.

The company can say:

> “Recovery Credit issued. Thank you for improving site profitability.”

### Later currency: Employee Vouchers
**Employee Vouchers** are a slower earned reward for attendance, assignments, seasonal contracts, and employee records.

- Used for earned cosmetics, employee-card items, non-power tool looks, and company credential flair.
- Supports long-term goals without making every object drop a premium-looking currency.
- Not required for MVP.

### Later progress value: Clearance Level
**Clearance Level** is rank/reputation, not spendable currency.

- Increases through completed contracts, reliable extraction, and company assignments.
- Unlocks access to harder contracts and rank credentials such as badge frames, lanyards, patches, titles, or tool decals.
- Must not force a full uniform override or erase purchased/earned character skins.
- Must not increase sprint, vacuum power, stealth, survival chance, or other direct paid/earned combat advantage.

### Premium monetization
If and only if the core demo and public retention test work, premium purchases should be cosmetic:

- Character skins.
- Uniform/outfit layers.
- Ear accessories and employee-card frames.
- Tool skins.
- Truck/loading-bay decor.
- Emotes and end-of-shift poses.
- Seasonal cosmetic packs.

Avoid paid recovery, paid survival, paid stamina, paid threat counters, paid character power, or paid contract success.

## Contract economy
A contract has two values:

1. **Clearance quota:** minimum site material/cargo that must be banked to complete the company obligation.
2. **Optional recovery:** additional valuable cargo that can be extracted after quota for more Recovery Credits, catalog discoveries, or cosmetic progress.

The quota makes cleanup matter. Optional recovery creates the greed decision.

### Contract sequence
1. Company assigns a building and minimum clearance quota.
2. Crew enters; basic cleanup exposes routes, rubbish, and assets.
3. Crew banks cargo in the Mobile Recovery Unit.
4. Quota is met.
5. Company announces that standard clearance is complete.
6. Crew chooses to leave or begin optional overtime recovery.
7. Overtime has clearer/higher risk, not hidden punishment.

Suggested company message:

> “Clearance threshold reached. Optional recovery remains available. Extended-site coverage is not guaranteed.”

Do not instantly flood the map with unavoidable threats at quota completion. Signal the risk, provide a chance to bank/regroup, and make staying a deliberate choice.

## The Mobile Recovery Unit
The truck/loading bay is a **Mobile Recovery Unit**.

It is a company vehicle and field processing station. It:

- Scans and classifies cargo.
- Gives the crew immediate banked progress.
- Removes material from the building’s local influence.
- Maintains contract chain of custody.
- Serves as the obvious extraction/safe checkpoint.

It should feel safe enough to create relief but not necessarily invulnerable in every future high-tier contract. For the MVP, keep it safe and simple.

## Residuals
Residuals are the in-world category for hostile site activity.

They form where a building’s purpose was repeated, interrupted, abandoned, or contaminated intensely enough to persist after people leave. Each Residual should reflect its location and mechanic rather than exist as a generic monster.

| Residual / threat | Building origin | Gameplay rule | Company phrasing |
|---|---|---|---|
| The Manager | Overtime, surveillance, status meetings, closed offices | Investigates work noise; chases on sight | Site Supervisor Proxy |
| Dust Bunnies | Neglected piles and unattended buildup | Accumulate near clutter; vacuum removes them | Particulate accumulation |
| Unit-7 | Obsolete company cleaning automation | Collects dropped cargo and returns it to dock | Unauthorized autonomous unit |
| Lights Out threat | Failed emergency systems / abandoned evacuation routine | Dark spaces become unsafe; restore power | Non-standard electrical event |

The company knows enough to label the risk, but gives employees incomplete guidance. This is horror and satire, not a need for exposition dumps.

## Pippa’s place in the world
Pippa is a feminine, cheerful, coral-orange bunny-like **Standard Issue Cleanup Associate**.

She genuinely believes the company is helping restore dangerous, abandoned places. She is capable and enthusiastic, but does not yet understand how much Morrow & Morrow knows about the sites.

Her personal motivation can remain simple in MVP:

> “No mess is too big! Probably!”

Her optimism should appear in movement and animation: upbeat idle, eager working posture, alert ears, determined sprint, and visible relief after extraction.

No character-specific lore is required to understand the core loop. Pippa provides an emotional viewpoint, not a tutorial burden.

## Future employee roster logic
Cute, original employee characters are normal in this world. The company recruits a broad range of workers and contractors. Do not prematurely explain species biology or dimensions.

Future employees can have distinct behavior/personality and one fair sidegrade after core validation, but no party composition should be required.

Examples:
- A fast worker with better sprint recovery.
- A hauler with an easier bulky-cargo posture.
- A technician with faster maintenance interactions.

All employees must still clean, carry, bank cargo, hide, escape, and complete basic contracts.

## Company mystery: optional long-term arc
The company may be doing more than removing danger.

Morrow & Morrow profits from clearance contracts and from the recovery of Anchor Assets. Its internal systems may relocate, classify, or exploit these assets in ways that create new affected sites.

This is a future mystery, not a launch reveal. Seed it through optional evidence:

- Redacted memos.
- Conflicting contract reports.
- Old staff badges.
- Scanned item classifications.
- Truck-radio messages.
- Safety posters.
- Results-screen fine print.

Potential later revelation:

> The company does not merely respond to Residual sites. It has incentives to preserve, move, and perhaps create the conditions that make them profitable.

Do not make the company secretly magical or explain everything early. Let the game’s mechanics remain legible first.

## Lore delivery rules
The player must never need lore to understand an interaction.

| Surface | Purpose | Example |
|---|---|---|
| Contract screen | Explain objective clearly | “Bank 12 Recovery Value” |
| Interaction prompt | Explain action plainly | “Vacuum buildup”, “Bank cargo”, “Extract” |
| Hazard hint | Explain counterplay | “Noise detected nearby” |
| Optional scan/file | Reward curiosity | “Anchor Asset: Do not leave unattended” |
| Environmental sign | Build tone | “If a former employee recognizes you, remain courteous.” |
| Results screen | Corporate satire/summary | “Hazard pay adjusted due to preventable incident.” |

Keep functional labels functional. Humor must not conceal controls.

## MVP canon: only what is required
For the first playable demo, only implement or imply this:

- Morrow & Morrow Clearance has contracted Pippa’s crew to clear a closed office.
- The company needs clutter/rubbish removed and recoverable assets banked in its Mobile Recovery Unit.
- The office contains the Manager, a Residual that reacts to work noise.
- Cargo banked at the truck is safe and counts toward clearance quota.
- Optional recovery after quota is riskier but more valuable.

No cutscene, lore menu, alternate dimensions, character roster, elaborate company history, or mystery reveal is required.

## Naming glossary
| Term | Use |
|---|---|
| Morrow & Morrow Clearance | Company |
| Clearance Associate | Employee/player job title |
| Site Clearance | A contract/mission |
| Residual | General hostile site activity / monster category |
| Site buildup | Contaminated clutter/rubbish/dust layer |
| Anchor Asset | Special object tied to Residual activity |
| Recoverable Asset | Normal valuable/company-relevant object |
| Recovery Credits | Core earned currency |
| Employee Vouchers | Later earned cosmetic currency |
| Clearance Level | Rank/reputation |
| Mobile Recovery Unit | Truck/loading-bay banking/extraction station |

## Design guardrails
- Do not make every object magical. Most cargo should remain mundane recoverable property or waste.
- Do not turn cleaning into a lore excuse for slow chores. It must be quick and mechanically useful.
- Do not rely on dimensions as a universal explanation. This premise works through property recovery and Residual activity.
- Do not force players to read files or know company history before they can play.
- Do not let rank or currencies become paid power.
- Do not make company satire so comedic that threat encounters stop feeling scary.
- Do not add lore elements that fail to explain a gameplay system, create a character hook, or support future content.

## One-sentence elevator lore
> Morrow & Morrow sends cheerful Clearance Associates into contaminated commercial properties to remove site buildup and recover valuable Anchor Assets before the Residuals inside notice the work being done.
