# Design records (historical)

These are the design specs, carried over from `venture-game-systems`, behind the systems this base
kept: the player-data layer and its (dormant) slots, the item and inventory model, the animation
system, the UI framework, titles, observability, and the module layout. Source comments cite them by
decision number ("spec Decision 3"), which is why they live here.

They are **records of how a decision was reached, not current documentation.** They were written
while porting the RPG "Venture", so they mention systems this base deliberately left behind (bank,
equipment, stats, customization, custom character replication) and Venture's own content (its
currency, items and art). Where a record and the code disagree, the code and `docs/` win.

New design work for this base goes in `docs/superpowers/specs/` as a new dated file.
