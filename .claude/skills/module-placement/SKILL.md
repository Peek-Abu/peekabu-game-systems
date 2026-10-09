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
